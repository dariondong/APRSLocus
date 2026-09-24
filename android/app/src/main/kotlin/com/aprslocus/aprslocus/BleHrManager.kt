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
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.ParcelUuid
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.UUID

/**
 * 蓝牙**心率广播**设备（BLE GATT，标准心率服务 0x180D）。
 *
 * ── 为什么单独一个类，而不是塞进 TncManager ──
 * TNC / PKWDWPL 走的是**经典蓝牙 SPP**（RFCOMM、面向已配对设备），而心率走
 * **BLE GATT**（扫描广播 + 连接 + 订阅通知）。两套栈的 API、生命周期、权限
 * 时机都不同；塞进同一个类只会让「TNC 的 socket 状态」与「GATT 连接」互相
 * 污染。分开之后天然就互不干扰 —— 用户要求「不要跟 TNC 的蓝牙通道起冲突」，
 * 真正的风险只有下面两条，都避开了：
 *
 *   1. **绝不做经典蓝牙发现**（`BluetoothAdapter.startDiscovery()`）：发现过程
 *      会占住蓝牙控制通道，正在通话/正在跑的 SPP 连接会被打断。这里只用
 *      `BluetoothLeScanner`，它对经典链路是安全的。
 *   2. **同一台设备不能同时当两者**：Android 给双模设备的经典地址与 BLE 地址
 *      是同一个 MAC，把正在给 TNC 用的电台选成心率设备会两边都坏。`connect()`
 *      会拿 MainActivity 传进来的「正被 SPP 占用的地址」比对并拒绝（ADDR_IN_USE）。
 *
 * 另外：绝不调用 `adapter.disable()`/`enable()`（那会把别的链路一起弄断），
 * 也不去读写 TncManager 的任何状态。
 *
 * 权限：API 31+ 要 BLUETOOTH_SCAN + BLUETOOTH_CONNECT（运行时）；API 30 及以下
 * 扫描需要 ACCESS_FINE_LOCATION（老系统的蓝牙扫描被归到定位权限下）。
 */
class BleHrManager(
    private val activity: Activity,
    /** 当前正被 SPP（TNC / PKWDWPL）占用的地址集合，由 MainActivity 汇总。 */
    private val busySppAddresses: () -> Set<String>,
    /**
     * 链路状态变化（连上/断开）→ MainActivity 重算「蓝牙是否在用」。
     *
     * 为什么管理器要回调出去：GATT 的连接/断开是**异步**发生的（回调在 binder
     * 线程），Dart 的调用点根本覆盖不到 —— 不回调的话前台服务会在心率带断开后
     * 仍然声称 connectedDevice（费电），或者连上后不声明（退到后台就被限制）。
     */
    private val onLinkChanged: () -> Unit,
) {
    companion object {
        const val METHOD_CHANNEL = "com.aprslocus/blehr"
        const val EVENT_CHANNEL = "com.aprslocus/blehr_events"

        /**
         * 权限请求码：**必须与其它所有请求码都不同**，否则
         * `onRequestPermissionsResult` 会把结果同时派发给两边，把对方尚未完成的
         * Result 误 resolve（TNC 与 PKWDWPL 当初就是为这个各用了一个码）。
         * 已占用：定位 100、TNC / PKWDWPL 各自一个（见 TncManager）、本类 4919。
         */
        const val PERM_REQUEST = 4919

        /** 标准心率服务（Heart Rate Service）。 */
        private val HR_SERVICE: UUID =
            UUID.fromString("0000180d-0000-1000-8000-00805f9b34fb")
        /** 心率测量特征（Heart Rate Measurement）。 */
        private val HR_MEASUREMENT: UUID =
            UUID.fromString("00002a37-0000-1000-8000-00805f9b34fb")
        /** 标准电池服务（有些心率带也报电量）。 */
        private val BATTERY_SERVICE: UUID =
            UUID.fromString("0000180f-0000-1000-8000-00805f9b34fb")
        private val BATTERY_LEVEL: UUID =
            UUID.fromString("00002a19-0000-1000-8000-00805f9b34fb")
        /** 客户端特征配置描述符：**不写它就收不到通知**（最常见的坑）。 */
        private val CCCD: UUID =
            UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")

        /** 扫描最长 15 秒就自动停：省电，也少与工作中的链路争天线。 */
        private const val SCAN_MS = 15000L
    }

    private var sink: EventChannel.EventSink? = null
    private var scanner: BluetoothLeScanner? = null
    private var scanning = false
    private var scanStop: Runnable? = null
    private var gatt: BluetoothGatt? = null
    private var pendingPermResult: MethodChannel.Result? = null

    /**
     * 事件必须先切回主线程再发：GATT 回调跑在 binder 线程上，而 Flutter 的
     * EventSink 只能在创建它的线程（主线程）用 —— 直接发会在某些机型上
     * 静默丢事件，表现是「心率一直是空的」。
     */
    private val main = Handler(Looper.getMainLooper())

    private val adapter: BluetoothAdapter?
        get() = (activity.getSystemService(Activity.BLUETOOTH_SERVICE) as? BluetoothManager)?.adapter

    // ─── 生命周期 / 事件 ───

    fun setEventSink(s: EventChannel.EventSink?) {
        sink = s
    }

    fun isSupported(): Boolean = try {
        adapter != null
    } catch (_: Exception) {
        false
    }

    fun isConnected(): Boolean = gatt != null

    fun dispose() {
        stopScanSilently()
        try {
            gatt?.disconnect()
            gatt?.close()
        } catch (_: Exception) {
        }
        gatt = null
        sink = null
        pendingPermResult = null
    }

    private fun emit(map: Map<String, Any?>) {
        main.post { sink?.success(map) }
    }

    // ─── 权限 ───

    private fun neededPermissions(): List<String> {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            listOf(Manifest.permission.BLUETOOTH_SCAN, Manifest.permission.BLUETOOTH_CONNECT)
        } else {
            listOf(Manifest.permission.ACCESS_FINE_LOCATION)
        }
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
        pendingPermResult = result
        ActivityCompat.requestPermissions(activity, missing.toTypedArray(), PERM_REQUEST)
    }

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
            }
            emit(
                mapOf(
                    "type" to "device",
                    "id" to dev.address,
                    "name" to name,
                    "rssi" to result.rssi,
                )
            )
        }

        override fun onScanFailed(errorCode: Int) {
            scanning = false
            emit(mapOf("type" to "scan", "scanning" to false))
            emit(mapOf("type" to "state", "state" to "scanFailed", "reason" to "扫描失败（$errorCode）"))
        }
    }

    fun startScan(): Boolean {
        val a = adapter ?: return false
        if (!hasPermission()) return false
        if (scanning) return true
        val sc = a.bluetoothLeScanner ?: return false
        scanner = sc

        // 只过滤出广播心率服务的设备：不过滤的话列表里会混进一堆手环/耳机/电视，
        // 用户根本不知道该选哪个（而且每个都要连一次才知道是不是心率带）。
        val filter = ScanFilter.Builder()
            .setServiceUuid(ParcelUuid(HR_SERVICE))
            .build()
        val settings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .build()
        return try {
            sc.startScan(listOf(filter), settings, scanCallback)
            scanning = true
            emit(mapOf("type" to "scan", "scanning" to true))
            scanStop?.let { main.removeCallbacks(it) }
            val stop = Runnable { stopScanSilently() }
            scanStop = stop
            main.postDelayed(stop, SCAN_MS)
            true
        } catch (_: SecurityException) {
            false
        }
    }

    /** 停扫描（不发事件）：连接前、dispose 时用。 */
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

    fun stopScan() {
        stopScanSilently()
        emit(mapOf("type" to "scan", "scanning" to false))
    }

    // ─── 连接 ───

    private val gattCallback = object : BluetoothGattCallback() {
        override fun onConnectionStateChange(g: BluetoothGatt?, status: Int, newState: Int) {
            if (newState == BluetoothProfile.STATE_CONNECTED) {
                emit(mapOf("type" to "state", "state" to "connected", "id" to g?.device?.address,
                    "name" to try { g?.device?.name } catch (_: SecurityException) { null },
                    "bonded" to (try { g?.device?.bondState == BluetoothDevice.BOND_BONDED } catch (_: SecurityException) { false })))
                try {
                    g?.discoverServices()
                } catch (_: SecurityException) {
                }
                onLinkChanged()
            } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                val reason = if (status == BluetoothGatt.GATT_SUCCESS) "连接已断开" else "连接中断（$status）"
                try {
                    g?.close()
                } catch (_: Exception) {
                }
                if (gatt === g) gatt = null
                emit(mapOf("type" to "state", "state" to "disconnected", "reason" to reason))
                onLinkChanged()
            }
        }

        override fun onServicesDiscovered(g: BluetoothGatt?, status: Int) {
            val svc = g?.getService(HR_SERVICE)
            val ch = svc?.getCharacteristic(HR_MEASUREMENT)
            if (ch == null) {
                emit(mapOf("type" to "state", "state" to "disconnected", "reason" to "该设备没有心率服务"))
                try {
                    g?.disconnect()
                } catch (_: Exception) {
                }
                return
            }
            try {
                g?.setCharacteristicNotification(ch, true)
                // CCCD **必须**写：setCharacteristicNotification 只是本地开关，
                // 不写描述符的话外设根本不会推通知（收不到任何心率）。
                val cccd = ch.getDescriptor(CCCD)
                if (cccd != null) {
                    cccd.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
                    g?.writeDescriptor(cccd)
                }
                // 顺手读一次电量（设备报了才读；读不到不影响心率）
                g?.getService(BATTERY_SERVICE)?.getCharacteristic(BATTERY_LEVEL)?.let {
                    g?.readCharacteristic(it)
                }
            } catch (_: SecurityException) {
            }
        }

        override fun onCharacteristicRead(
            g: BluetoothGatt?,
            ch: BluetoothGattCharacteristic?,
            status: Int,
        ) {
            if (ch?.uuid != BATTERY_LEVEL) return
            val v = ch.value ?: return
            if (v.isEmpty()) return
            emit(mapOf("type" to "battery", "level" to (v[0].toInt() and 0xFF)))
        }

        @Suppress("DEPRECATION")
        override fun onCharacteristicChanged(
            g: BluetoothGatt?,
            ch: BluetoothGattCharacteristic?,
        ) {
            if (ch?.uuid != HR_MEASUREMENT) return
            val d = ch.value ?: return
            if (d.isEmpty()) return
            val flags = d[0].toInt() and 0xFF
            var i = 1
            // flags 的**每一位都决定后面的字段存不存在**，所以偏移必须按位算：
            // 漏掉 energy（bit3）会把 RR 或后面的字节当成心率读出来（垃圾值），
            // 这类错误在真机上表现为「心率偶尔是 3000」。
            val bpm: Int = if (flags and 0x01 != 0) {
                if (i + 1 >= d.size) return
                val v = (d[i].toInt() and 0xFF) or ((d[i + 1].toInt() and 0xFF) shl 8)
                i += 2
                v
            } else {
                if (i >= d.size) return
                val v = d[i].toInt() and 0xFF
                i += 1
                v
            }
            val contactSupported = flags and 0x04 != 0
            val contact = if (contactSupported) (flags and 0x02 != 0) else true
            var energy: Int? = null
            if (flags and 0x08 != 0) {
                if (i + 1 < d.size) {
                    energy = (d[i].toInt() and 0xFF) or ((d[i + 1].toInt() and 0xFF) shl 8)
                }
                i += 2
            }
            val rr = ArrayList<Int>()
            if (flags and 0x10 != 0) {
                while (i + 1 < d.size) {
                    rr.add((d[i].toInt() and 0xFF) or ((d[i + 1].toInt() and 0xFF) shl 8))
                    i += 2
                }
            }
            if (bpm <= 0) return
            emit(
                mapOf(
                    "type" to "hr",
                    "bpm" to bpm,
                    "contact" to contact,
                    "energy" to energy,
                    "rr" to rr,
                    "at" to System.currentTimeMillis(),
                )
            )
        }
    }

    /**
     * 连接指定地址。
     *
     * 结果由**这里** resolve（而不是回一个布尔再让 MainActivity 包一层）：
     * 失败原因有三种且要给不同的人话提示（没权限 / 地址被 SPP 占着 / 地址非法），
     * 拆成两层就必然会出现「先 success 再 error」或者错误码被覆盖的写法。
     */
    fun connect(address: String, result: MethodChannel.Result) {
        if (!hasPermission()) {
            result.error("NO_PERMISSION", "缺少蓝牙权限", null)
            return
        }
        val a = adapter ?: run {
            result.error("NOT_SUPPORTED", "本机没有蓝牙适配器", null)
            return
        }
        // 与 TNC 的显式防冲突：双模设备的经典地址与 BLE 地址是同一个 MAC，
        // 同一台设备被两条链路同时使用时两边都会坏。
        if (busySppAddresses().map { it.uppercase() }.contains(address.uppercase())) {
            result.error(
                "ADDR_IN_USE",
                "该地址正被 TNC / PKWDWPL 的蓝牙链路使用，不能同时当心率带",
                null
            )
            return
        }
        // 扫描与连接不能同时进行（同一套射频资源，且会拖慢建链）。
        stopScanSilently()
        try {
            gatt?.close()
        } catch (_: Exception) {
        }
        gatt = null
        val dev = try {
            a.getRemoteDevice(address)
        } catch (_: Exception) {
            result.error("BAD_ADDRESS", "设备地址无效", null)
            return
        }
        emit(mapOf("type" to "state", "state" to "connecting"))
        gatt = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            dev.connectGatt(activity, false, gattCallback, BluetoothDevice.TRANSPORT_LE)
        } else {
            // API 23 以下没有 TRANSPORT_LE 重载；BLE 设备仍会以默认传输连接
            dev.connectGatt(activity, false, gattCallback)
        }
        // 建链是异步的：这里只能说「请求发出去了」，成不成看 onConnectionStateChange
        // （失败会走 state=disconnected 事件，Dart 侧显示原因）。
        if (gatt == null) {
            result.error("GATT_FAILED", "无法发起连接", null)
        } else {
            result.success(true)
        }
    }

    /** 当前状态快照（Dart 侧进设置页时问一次，免得只依赖事件）。 */
    fun status(): Map<String, Any?> = mapOf(
        "connected" to isConnected(),
        "scanning" to scanning,
    )

    fun disconnect() {
        try {
            gatt?.disconnect()
            gatt?.close()
        } catch (_: Exception) {
        }
        gatt = null
        emit(mapOf("type" to "state", "state" to "disconnected", "reason" to "已断开"))
        onLinkChanged()
    }
}
