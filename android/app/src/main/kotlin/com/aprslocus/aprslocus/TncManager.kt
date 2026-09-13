package com.aprslocus.aprslocus

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothSocket
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.app.ActivityCompat
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.InputStream
import java.io.OutputStream
import java.util.UUID
import java.util.concurrent.atomic.AtomicBoolean

/**
 * 蓝牙 TNC（经典蓝牙 SPP / RFCOMM）链路管理。
 *
 * 设计取舍：原生侧**只搬字节**，不理解 APRS —— KISS 组帧与 AX.25 编解码
 * 全在 Dart 侧（lib/kiss.dart）完成。这样：
 *   ① 协议实现只有一份，可单元测试（test/kiss_test.dart）；
 *   ② 将来加串口 / KISS-over-TCP 等其他传输时无需再写一遍协议；
 *   ③ 原生侧不随协议变动而需要重新发版。
 *
 * SPP 使用蓝牙标准串口服务 UUID 0x1101，绝大多数 APRS TNC 蓝牙模块
 * （HC-05/06、Mobilinkd、Kenwood 内置蓝牙等）都支持。
 */
class TncManager(private val activity: Activity) {

    companion object {
        const val METHOD_CHANNEL = "com.aprslocus/tnc"
        const val EVENT_CHANNEL = "com.aprslocus/tnc_events"

        /** 蓝牙串口服务（SPP）标准 UUID */
        private val SPP_UUID: UUID =
            UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")

        /** Android 12+ 需要的运行时蓝牙权限 */
        private val BT_PERMISSIONS = arrayOf(
            Manifest.permission.BLUETOOTH_CONNECT,
            Manifest.permission.BLUETOOTH_SCAN
        )
        private const val PERM_REQUEST = 0x7A31
    }

    private val main = Handler(Looper.getMainLooper())
    private val running = AtomicBoolean(false)

    private var socket: BluetoothSocket? = null
    private var input: InputStream? = null
    private var output: OutputStream? = null
    private var reader: Thread? = null

    private var events: EventChannel.EventSink? = null
    private var permResult: MethodChannel.Result? = null

    // ─── 能力与权限 ───

    private fun adapter(): BluetoothAdapter? {
        val mgr = activity.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        return mgr?.adapter
    }

    private fun hasBtPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return true
        return BT_PERMISSIONS.all {
            ActivityCompat.checkSelfPermission(activity, it) == PackageManager.PERMISSION_GRANTED
        }
    }

    fun isSupported(): Boolean {
        val a = adapter()
        return a != null && a.isEnabled
    }

    fun requestPermissions(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S || hasBtPermission()) {
            result.success(true)
            return
        }
        permResult = result
        ActivityCompat.requestPermissions(activity, BT_PERMISSIONS, PERM_REQUEST)
    }

    fun onRequestPermissionsResult(requestCode: Int, grantResults: IntArray) {
        if (requestCode != PERM_REQUEST) return
        val ok = grantResults.isNotEmpty() &&
                grantResults.all { it == PackageManager.PERMISSION_GRANTED }
        permResult?.success(ok)
        permResult = null
    }

    // ─── 设备列表 ───

    @SuppressLint("MissingPermission")
    fun listBondedDevices(): List<Map<String, Any?>> {
        if (!hasBtPermission()) {
            throw SecurityException("缺少蓝牙权限（BLUETOOTH_CONNECT）")
        }
        val a = adapter() ?: return emptyList()
        val out = ArrayList<Map<String, Any?>>()
        for (d in a.bondedDevices ?: emptySet()) {
            val name = try {
                d.name ?: ""
            } catch (_: SecurityException) {
                ""
            }
            out.add(
                mapOf(
                    "id" to d.address,
                    "name" to name,
                    "kind" to "bluetooth",
                    "paired" to (d.bondState == BluetoothDevice.BOND_BONDED)
                )
            )
        }
        // 按名称排序，便于在长列表里找
        return out.sortedBy { (it["name"] as String).ifEmpty { it["id"] as String } }
    }

    // ─── 连接 / 断开 ───

    @SuppressLint("MissingPermission")
    fun connect(address: String) {
        if (!hasBtPermission()) {
            throw SecurityException("缺少蓝牙权限（BLUETOOTH_CONNECT）")
        }
        val a = adapter() ?: throw IllegalStateException("蓝牙不可用或未开启")
        closeQuietly()

        val device = a.getRemoteDevice(address)
        // 发现附近设备会严重拖慢甚至导致 RFCOMM 连接失败，必须先取消
        try {
            if (a.isDiscovering) a.cancelDiscovery()
        } catch (_: SecurityException) {
        }

        val sock = device.createRfcommSocketToServiceRecord(SPP_UUID)
        sock.connect() // 阻塞；失败抛 IOException

        socket = sock
        input = sock.inputStream
        output = sock.outputStream
        running.set(true)
        startReader()
        emitState("connected")
    }

    private fun startReader() {
        reader = Thread {
            val buf = ByteArray(1024)
            try {
                while (running.get()) {
                    val n = input?.read(buf) ?: -1
                    if (n < 0) break
                    if (n > 0) emitBytes(buf.copyOf(n))
                }
            } catch (_: Exception) {
                // 对端掉线 / 读写异常：统一走关闭流程
            } finally {
                if (running.getAndSet(false)) {
                    main.post { emitState("closed") }
                }
            }
        }.also {
            it.isDaemon = true
            it.start()
        }
    }

    fun send(data: ByteArray) {
        val out = output ?: throw IllegalStateException("链路未连接")
        out.write(data)
        out.flush()
    }

    fun disconnect() {
        running.set(false)
        closeQuietly()
        emitState("closed")
    }

    private fun closeQuietly() {
        running.set(false)
        try {
            input?.close()
        } catch (_: Exception) {
        }
        try {
            output?.close()
        } catch (_: Exception) {
        }
        try {
            socket?.close()
        } catch (_: Exception) {
        }
        input = null
        output = null
        socket = null
        reader = null
    }

    // ─── 事件通道 ───

    fun setEventSink(sink: EventChannel.EventSink?) {
        events = sink
    }

    private fun emitBytes(data: ByteArray) {
        main.post { events?.success(mapOf("type" to "bytes", "data" to data)) }
    }

    private fun emitState(state: String) {
        main.post { events?.success(mapOf("type" to "state", "state" to state)) }
    }

    fun dispose() {
        disconnect()
        events = null
    }
}
