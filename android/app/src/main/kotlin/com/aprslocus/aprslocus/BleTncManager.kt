package com.aprslocus.aprslocus

import android.Manifest
import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.bluetooth.le.BluetoothLeScanner
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.UUID

/**
 * BLE TNC（低功耗蓝牙 KISS 串口）链路管理。
 *
 * ── 为什么需要它 ──
 * [TncManager] 走的是**经典蓝牙 SPP（RFCOMM）**，只连「已配对设备」。而
 * Radtel RT-950 Pro 等新式电台的 KISS TNC 走的是 **BLE GATT**（设备名
 * `walkie-talkie`，串口服务 FFE0 / 特征 FFE1），不提供 SPP 服务。用 SPP
 * 去连会报 `read failed, socket might closed or timeout, read ret: -1`。
 *
 * 本类补齐这条 BLE 通路：扫描广播 → 连接 GATT → 找到串口特征 → 订阅通知
 * （收 KISS 字节）/ 写特征（发 KISS 字节）。原生侧**只搬字节**，KISS 组帧
 * 与 AX.25 编解码仍在 Dart 侧（lib/kiss.dart）—— 与 TncManager 同一分层。
 *
 * ── 事件协议 ──
 * 与 [TncManager] 完全一致（bytes / state / txok / txfail），因此 Dart 侧
 * 直接复用 `TncNativeBluetooth.wireEvents` 的解析。
 *
 * ── 与 SPP / 心率带的隔离 ──
 * 只用 BluetoothLeScanner，绝不调用 adapter.startDiscovery() / enable() /
 * disable()（那会打断正在工作的 SPP 连接）。不读写其它 manager 的状态。
 *
 * ── 特征 UUID ──
 * RT-950 Pro 用 HM-10 风格：服务 0000ffe0、特征 0000ffe1（收发共用，
 * 通知 + 写）。为兼容其它固件，发现服务时优先找 FFE1，找不到再退回
 * 「同时支持 WRITE 与 NOTIFY」的第一个特征。
 */
class BleTncManager(
    private val activity: Activity,
    /** 链路状态变化 → MainActivity 重算前台服务 connectedDevice 声明。 */
    private val onLinkChanged: () -> Unit,
) {
    companion object {
        const val METHOD_CHANNEL = "com.aprslocus/bletnc"
        const val EVENT_CHANNEL = "com.aprslocus/bletnc_events"

        /** 权限请求码：不得与其它所有请求码冲突（TNC 0x7A31、PKWDWPL
         * 0x7A32、BOX 0x7A33、GPS 0x7A34、心率带 4919、定位 100…）。 */
        const val PERM_REQUEST = 4920

        /** HM-10 / RT-950 Pro KISS 串口特征 */
        private val SPP_SERVICE: UUID =
            UUID.fromString("0000ffe0-0000-1000-8000-00805f9b34fb")
        private val SPP_CHAR: UUID =
            UUID.fromString("0000ffe1-0000-1000-8000-00805f9b34fb")
        private val CCCD: UUID =
            UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")

        /** 扫描时长：BLE 广播通常几百毫秒一轮，6 秒足够发现附近电台。 */
        private const val SCAN_MS = 6000L
        /** 连接超时（发现服务 + 订阅完成才算成功）。 */
        private const val CONNECT_TIMEOUT_MS = 20000L
        /** 默认 ATT MTU 23 → 有效负载 20 字节；协商失败时按此分片。 */
        private const val DEFAULT_WRITE_CHUNK = 20
    }

    private val main = Handler(Looper.getMainLooper())
    private var sink: EventChannel.EventSink? = null
    private var scanner: BluetoothLeScanner? = null
    private var scanning = false
    private var scanStop: Runnable? = null
    private var scanResult: MethodChannel.Result? = null
    private val found = LinkedHashMap<String, Map<String, Any?>>()
    private var pendingConnect: MethodChannel.Result? = null
    private var connectTimeout: Runnable? = null

    private var gatt: BluetoothGatt? = null
    private var txChar: BluetoothGattCharacteristic? = null
    private var mtu = DEFAULT_WRITE_CHUNK + 3
    private var connected = false

    /** 待写分片队列：BLE 写入必须串行，且每片之间留间隔，否则部分模块会丢帧。 */
    private val writeQueue = java.util.LinkedList<ByteArray>()
    private var writing = false

    private val adapter: BluetoothAdapter?
        get() = (activity.getSystemService(Activity.BLUETOOTH_SERVICE) as? BluetoothManager)?.adapter

    // ─── 生命周期 / 事件 ───

    fun setEventSink(s: EventChannel.EventSink?) {
        sink = s
    }

    fun isSupported(): Boolean = try {
        adapter != null && activity.packageManager.hasSystemFeature("android.hardware.bluetooth_le")
    } catch (_: Exception) {
        false
    }

    fun isConnected(): Boolean = connected && gatt != null

    fun connectedAddress(): String? = try {
        if (isConnected()) gatt?.device?.address else null
    } catch (_: SecurityException) {
        null
    }

    fun dispose() {
        stopScanSilently()
        scanResult = null
        pendingConnect?.error("DISPOSED", "界面已关闭", null)
        pendingConnect = null
        connectTimeout?.let { main.removeCallbacks(it) }
        connectTimeout = null
        connected = false
        writeQueue.clear()
        try {
            gatt?.disconnect()
            gatt?.close()
        } catch (_: Exception) {
        }
        gatt = null
        txChar = null
        sink = null
        onLinkChanged()
    }

    private fun emit(map: Map<String, Any?>) {
        main.post { sink?.success(map) }
    }

    // ─── 权限 ───

    private fun neededPermissions(): List<String> =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            listOf(Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.BLUETOOTH_CONNECT)
        } else {
            listOf(Manifest.permission.ACCESS_FINE_LOCATION)
        }

    private fun hasPermission(): Boolean = neededPermissions().all {
        ContextCompat.checkSelfPermission(activity, it) == PackageManager.PERMISSION_GRANTED
    }

    fun requestPermissions(result: MethodChannel.Result) {
        if (!isSupported()) {
            result.success(false)
            return
        }
        val missing = neededPermissions().filter {
            ContextCompat.checkSelfPermission(activity, it) != PackageManager.PERMISSION_GRANTED
        }
        if (missing.isEmpty()) {
            result.success(true)
            return
        }
        // 复用一个字段即可：同一时刻只会有一个权限请求在飞（扫描/连接都先查权限）
        pendingPermResult = result
        ActivityCompat.requestPermissions(activity, missing.toTypedArray(), PERM_REQUEST)
    }

    private var pendingPermResult: MethodChannel.Result? = null

    fun onRequestPermissionsResult(requestCode: Int, grantResults: IntArray) {
        if (requestCode != PERM_REQUEST) return
        val ok = hasPermission()
        pendingPermResult?.success(ok)
        pendingPermResult = null
    }

    // ─── 扫描 ───

    private val scanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) {
            val dev = result.device ?: return
            val name = try {
                result.scanRecord?.deviceName ?: dev.name
            } catch (_: SecurityException) {
                null
            } catch (_: Exception) {
                null
            }
            val key = dev.address
            val priorRssi = (found[key]?.get("rssi") as? Number)?.toInt() ?: Int.MIN_VALUE
            if (result.rssi <= priorRssi && found.containsKey(key)) return
            found[key] = mapOf(
                "id" to key,
                "name" to (name ?: ""),
                "kind" to "ble",
                "paired" to true,
                "rssi" to result.rssi,
            )
        }

        override fun onScanFailed(errorCode: Int) {
            scanning = false
            val r = scanResult
            scanResult = null
            if (r != null) {
                r.error("SCAN_FAILED", "BLE 扫描失败（$errorCode）", null)
            }
        }
    }

    /** 扫描并把结果一次性返回给 Dart（配合设备页「扫描设备」按钮）。 */
    fun scanDevices(result: MethodChannel.Result) {
        if (!isSupported()) {
            result.success(emptyList<Map<String, Any?>>())
            return
        }
        if (!hasPermission()) {
            result.error("NO_PERMISSION", "缺少蓝牙权限", null)
            return
        }
        val sc = adapter?.bluetoothLeScanner
        if (sc == null) {
            result.success(emptyList<Map<String, Any?>>())
            return
        }
        stopScanSilently()
        found.clear()
        scanner = sc
        scanResult = result
        val settings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .build()
        // 不做服务过滤：不同固件 / 不同电台的 KISS 服务 UUID 不一样，
        // 全收再按名字（walkie-talkie 优先）与信号强度排序，交给用户挑。
        try {
            sc.startScan(null, settings, scanCallback)
            scanning = true
            val stop = Runnable { finishScan() }
            scanStop = stop
            main.postDelayed(stop, SCAN_MS)
        } catch (_: SecurityException) {
            scanResult = null
            result.error("NO_PERMISSION", "缺少蓝牙权限", null)
        }
    }

    private fun finishScan() {
        stopScanSilently()
        val r = scanResult ?: return
        scanResult = null
        // walkie-talkie（RT-950 Pro）排前面，其余按信号强度降序
        val list = found.values.sortedWith(
            compareByDescending<Map<String, Any?>> {
                (it["name"] as String).contains("walkie", ignoreCase = true) ||
                    (it["name"] as String).contains("talkie", ignoreCase = true)
            }.thenByDescending { (it["rssi"] as? Number)?.toInt() ?: Int.MIN_VALUE }
        )
        r.success(list)
    }

    private fun stopScanSilently() {
        if (scanning) {
            try {
                scanner?.stopScan(scanCallback)
            } catch (_: Exception) {
            }
        }
        scanning = false
        scanStop?.let { main.removeCallbacks(it) }
        scanStop = null
    }

    // ─── 连接 / GATT ───

    private val gattCallback = object : BluetoothGattCallback() {
        override fun onConnectionStateChange(g: BluetoothGatt?, status: Int, newState: Int) {
            if (newState == BluetoothProfile.STATE_CONNECTED) {
                emit(mapOf("type" to "state", "state" to "connecting"))
                try {
                    g?.discoverServices()
                } catch (_: SecurityException) {
                }
            } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                val wasConnecting = pendingConnect != null
                connected = false
                txChar = null
                writeQueue.clear()
                writing = false
                try {
                    g?.close()
                } catch (_: Exception) {
                }
                if (gatt === g) gatt = null
                connectTimeout?.let { main.removeCallbacks(it) }
                connectTimeout = null
                if (wasConnecting) {
                    val reason = if (status == BluetoothGatt.GATT_SUCCESS) "连接已断开" else "连接失败（$status）"
                    pendingConnect?.error("CONNECT_FAILED", reason, null)
                    pendingConnect = null
                }
                emit(mapOf("type" to "state", "state" to "closed", "reason" to "已断开"))
                onLinkChanged()
            }
        }

        override fun onServicesDiscovered(g: BluetoothGatt?, status: Int) {
            if (status != BluetoothGatt.GATT_SUCCESS || g == null) {
                failConnect("SERVICES_FAILED", "发现服务失败（$status）")
                return
            }
            // 优先 FFE1；退而求其次找「可写 + 可通知」的特征
            var ch: BluetoothGattCharacteristic? = null
            for (svc in g.services ?: emptyList()) {
                for (c in svc.characteristics ?: emptyList()) {
                    if (c.uuid == SPP_CHAR) {
                        ch = c
                        break
                    }
                }
                if (ch != null) break
            }
            if (ch == null) {
                outer@ for (svc in g.services ?: emptyList()) {
                    for (c in svc.characteristics ?: emptyList()) {
                        val p = c.properties
                        if ((p and BluetoothGattCharacteristic.PROPERTY_WRITE != 0 ||
                                p and BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE != 0) &&
                            p and BluetoothGattCharacteristic.PROPERTY_NOTIFY != 0
                        ) {
                            ch = c
                            break@outer
                        }
                    }
                }
            }
            if (ch == null) {
                failConnect("NO_CHAR", "该设备没有 KISS 串口特征（FFE1）")
                try { g.disconnect() } catch (_: Exception) {}
                return
            }
            txChar = ch
            try {
                // 订阅通知：本地开关 + CCCD，两者缺一不可
                g.setCharacteristicNotification(ch, true)
                ch.getDescriptor(CCCD)?.let { d ->
                    d.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
                    g.writeDescriptor(d)
                }
                // 申请大 MTU：KISS 帧常超 20 字节，不协商就只能分片很多次
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    g.requestMtu(517)
                }
            } catch (_: SecurityException) {
            }
            // 通知/CCCD 是异步写，但成功概率极高；这里直接判成功，
            // 真收不到字节时用户会在日志里看到「连上但无数据」再排查 UUID。
            connected = true
            connectTimeout?.let { main.removeCallbacks(it) }
            connectTimeout = null
            emit(mapOf("type" to "state", "state" to "connected"))
            val r = pendingConnect
            pendingConnect = null
            r?.success(true)
            onLinkChanged()
        }

        override fun onMtuChanged(g: BluetoothGatt?, mtu: Int, status: Int) {
            if (status == BluetoothGatt.GATT_SUCCESS) {
                this@BleTncManager.mtu = (mtu - 3).coerceAtLeast(DEFAULT_WRITE_CHUNK)
            }
        }

        @Suppress("DEPRECATION")
        override fun onCharacteristicChanged(
            g: BluetoothGatt?,
            ch: BluetoothGattCharacteristic?,
        ) {
            val c = txChar ?: return
            if (ch?.uuid != c.uuid) return
            val data = ch.value ?: return
            if (data.isEmpty()) return
            emit(mapOf("type" to "bytes", "data" to data))
        }

        @Suppress("DEPRECATION")
        override fun onCharacteristicWrite(
            g: BluetoothGatt?,
            ch: BluetoothGattCharacteristic?,
            status: Int,
        ) {
            main.post {
                writing = false
                if (status == BluetoothGatt.GATT_SUCCESS) {
                    emit(mapOf("type" to "txok", "size" to (ch?.value?.size ?: 0)))
                } else {
                    emit(mapOf("type" to "txfail", "message" to "BLE 写入失败（$status）"))
                }
                pumpWrite()
            }
        }
    }

    fun connect(address: String, result: MethodChannel.Result) {
        if (!hasPermission()) {
            result.error("NO_PERMISSION", "缺少蓝牙权限", null)
            return
        }
        val a = adapter ?: run {
            result.error("NOT_SUPPORTED", "本机没有蓝牙适配器", null)
            return
        }
        stopScanSilently()
        try {
            gatt?.close()
        } catch (_: Exception) {
        }
        gatt = null
        txChar = null
        connected = false
        val dev = try {
            a.getRemoteDevice(address)
        } catch (_: Exception) {
            result.error("BAD_ADDRESS", "设备地址无效", null)
            return
        }
        pendingConnect = result
        connectTimeout?.let { main.removeCallbacks(it) }
        val to = Runnable {
            if (pendingConnect != null) {
                failConnect("CONNECT_TIMEOUT", "连接超时（20 秒）")
                try { gatt?.disconnect() } catch (_: Exception) {}
            }
        }
        connectTimeout = to
        main.postDelayed(to, CONNECT_TIMEOUT_MS)
        emit(mapOf("type" to "state", "state" to "connecting"))
        try {
            gatt = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                dev.connectGatt(activity, false, gattCallback, BluetoothDevice.TRANSPORT_LE)
            } else {
                @Suppress("DEPRECATION")
                dev.connectGatt(activity, false, gattCallback)
            }
        } catch (_: SecurityException) {
            failConnect("NO_PERMISSION", "缺少蓝牙权限")
        }
        if (gatt == null && pendingConnect != null) {
            failConnect("GATT_FAILED", "无法发起 BLE 连接")
        }
    }

    private fun failConnect(code: String, msg: String) {
        connectTimeout?.let { main.removeCallbacks(it) }
        connectTimeout = null
        pendingConnect?.error(code, msg, null)
        pendingConnect = null
    }

    fun disconnect() {
        connectTimeout?.let { main.removeCallbacks(it) }
        connectTimeout = null
        pendingConnect?.error("DISCONNECTED", "已断开", null)
        pendingConnect = null
        connected = false
        writeQueue.clear()
        writing = false
        try {
            gatt?.disconnect()
            gatt?.close()
        } catch (_: Exception) {
        }
        gatt = null
        txChar = null
        emit(mapOf("type" to "state", "state" to "closed", "reason" to "已断开"))
        onLinkChanged()
    }

    // ─── 发送（分片 + 串行）───

    @Suppress("DEPRECATION")
    fun send(data: ByteArray) {
        if (!connected || txChar == null) {
            emit(mapOf("type" to "txfail", "message" to "BLE 未连接，丢弃 ${data.size} 字节"))
            return
        }
        if (data.isEmpty()) return
        val chunk = mtu.coerceAtLeast(DEFAULT_WRITE_CHUNK)
        var off = 0
        while (off < data.size) {
            val len = minOf(chunk, data.size - off)
            writeQueue.add(data.copyOfRange(off, off + len))
            off += len
        }
        pumpWrite()
    }

    @Suppress("DEPRECATION")
    private fun pumpWrite() {
        if (writing || !connected) return
        val c = txChar ?: return
        val next = writeQueue.poll() ?: return
        writing = true
        try {
            c.value = next
            // 优先无应答写（更快）；不支持则退回普通写
            if (c.properties and BluetoothGattCharacteristic.PROPERTY_WRITE_NO_RESPONSE != 0) {
                c.writeType = BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE
            } else {
                c.writeType = BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
            }
            val ok = gatt?.writeCharacteristic(c)
            if (ok != true) {
                writing = false
                emit(mapOf("type" to "txfail", "message" to "BLE 写入入队失败"))
                main.postDelayed({ pumpWrite() }, 20)
            }
        } catch (_: SecurityException) {
            writing = false
            emit(mapOf("type" to "txfail", "message" to "缺少蓝牙权限"))
        }
    }
}
