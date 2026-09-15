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
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger

/**
 * 蓝牙 TNC（经典蓝牙 SPP / RFCOMM）链路管理。
 *
 * 设计取舍：原生侧**只搬字节**，不理解 APRS —— KISS 组帧与 AX.25 编解码
 * 全在 Dart 侧（lib/kiss.dart）完成。
 *
 * ── 并发模型（这里曾经出过「有概率发射后断开连接」的故障）──
 *
 * 用**代次（generation）**隔离每一条链路：每次 `connect()` 成功后代次 +1，
 * reader / writer 线程都只处理自己那一代的套接字，并且在退出时**只允许
 * 当前代次**宣布「链路断开」。为什么必须这样：
 *
 *   旧实现里 reader 退出时无条件 `running.set(false)`。而 `connect()` 是
 *   「关旧 socket → 阻塞 connect 新 socket → 置 running=true」的顺序，
 *   于是旧 reader 只要**醒得慢一点**（在新连接已建立之后才从已关闭的
 *   socket 上抛错），就会把新链路的 running 翻成 false 并广播 "closed"：
 *   新 reader 随即因 running=false 直接退出 —— 表现就是「刚连上/刚发射完
 *   就断开，而且之后再也连不稳」。是否发生完全取决于线程调度时机，
 *   所以症状是**有概率**的。
 *
 * 写入也放在**单独的 writer 线程**上串行执行，原因有二：
 *   ① `BluetoothSocket.write` 在模块忙（正在发射）时可能阻塞数秒，
 *      放在主线程会卡住界面与平台通道（Dart 侧 `txSelfTest` 也依赖
 *      主线程回调，会被一起拖住）；
 *   ② 两帧并发写会让 KISS 字节流**交错**（FEND 出现在帧中间），
 *      部分 TNC 会把这当成非法帧甚至复位链路。
 */
class TncManager(
    private val activity: Activity,
    /**
     * 平台通道名。参数化而不是写死，是为了让 **PKWDWPL 链路**
     * （Kenwood `$PKWDWPL` 航点语句）复用同一套字节搬运实现。
     *
     * 为什么不能共用通道：本类只维护**一个** socket，两条链路共用会出现
     * 「开了 TNC 之后 PKWDWPL 断、来回争抢」—— 各自一个实例、一个通道才对，
     * 而 SPP 的并发坑（代次隔离、写队列串行、权限回调）已经在这里踩完了，
     * 复制一份必然漏掉其中某个修复。
     */
    private val methodChannelName: String = METHOD_CHANNEL,
    private val eventChannelName: String = EVENT_CHANNEL,
) {

    companion object {
        const val METHOD_CHANNEL = "com.aprslocus/tnc"
        const val EVENT_CHANNEL = "com.aprslocus/tnc_events"

        /** PKWDWPL 链路（Kenwood 航点语句，只收不发）的独立通道 */
        const val METHOD_CHANNEL_PKWDWPL = "com.aprslocus/pkwdwpl"
        const val EVENT_CHANNEL_PKWDWPL = "com.aprslocus/pkwdwpl_events"

        /** 蓝牙串口服务（SPP）标准 UUID */
        private val SPP_UUID: UUID =
            UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")

        /** Android 12+ 需要的运行时蓝牙权限 */
        private val BT_PERMISSIONS = arrayOf(
            Manifest.permission.BLUETOOTH_CONNECT,
            Manifest.permission.BLUETOOTH_SCAN
        )
        private const val PERM_REQUEST = 0x7A31

        /** 待写队列上限。APRS 突发很小，几十帧足够；满了说明模块已经不消费了。 */
        private const val WRITE_QUEUE_MAX = 64
    }

    private val main = Handler(Looper.getMainLooper())

    /**
     * 当前链路代次。0 或负数表示没有有效链路。
     * 每次 connect 成功 +1；断开时也 +1（让在飞的线程立刻失效）。
     */
    private val generation = AtomicInteger(0)

    /** 连接过程互斥：避免两次 connect 同时跑（第二次会把第一次的 socket 关掉）。 */
    private val connecting = AtomicBoolean(false)

    @Volatile
    private var socket: BluetoothSocket? = null
    private var reader: Thread? = null
    private var writer: Thread? = null

    /** 待写队列：send() 只入队，实际写出在 writer 线程串行执行 */
    private val writeQueue = LinkedBlockingQueue<ByteArray>(WRITE_QUEUE_MAX)

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
        // 并发保护：两次 connect 同时跑时，后一次会把前一次刚建好的 socket 关掉，
        // 表现为「刚连上就断」。宁可让调用方收到明确错误、稍后重试。
        if (!connecting.compareAndSet(false, true)) {
            throw IllegalStateException("正在连接中，请稍后重试")
        }
        try {
            val a = adapter() ?: throw IllegalStateException("蓝牙不可用或未开启")
            // 关掉旧链路并把代次推进，使旧的 reader/writer 立刻失效
            teardown()

            val device = a.getRemoteDevice(address)
            // 发现附近设备会严重拖慢甚至导致 RFCOMM 连接失败，必须先取消
            try {
                if (a.isDiscovering) a.cancelDiscovery()
            } catch (_: SecurityException) {
            }

            val sock = device.createRfcommSocketToServiceRecord(SPP_UUID)
            sock.connect() // 阻塞；失败抛 IOException

            val gen = generation.incrementAndGet()
            socket = sock
            startWriter(sock, gen)
            startReader(sock, gen)
            emitState("connected")
        } finally {
            connecting.set(false)
        }
    }

    /**
     * reader：把模块吐回的字节送上 Flutter。
     *
     * [gen] 是本线程所属代次；一旦代次不再匹配（重连或断开），线程立刻退出，
     * 且**不允许**宣布链路断开 —— 那是新代次的事。
     */
    private fun startReader(sock: BluetoothSocket, gen: Int) {
        val inp: InputStream = try {
            sock.inputStream
        } catch (e: Exception) {
            emitState("closed")
            return
        }
        reader = Thread {
            val buf = ByteArray(1024)
            var reason: String? = null
            try {
                while (generation.get() == gen) {
                    val n = try {
                        inp.read(buf)
                    } catch (e: Exception) {
                        reason = e.message ?: "read-error"
                        break
                    }
                    if (n < 0) {
                        reason = "eof"
                        break
                    }
                    if (n > 0) emitBytes(buf.copyOf(n), gen)
                }
            } finally {
                // 只有「仍然是当前代次」的 reader 才有资格宣布断开；
                // 若已经是新代次，说明这是一次正常重连，不能误报断开
                // （旧实现正是在这里把新链路误判为断开）。
                if (reason != null && generation.compareAndSet(gen, gen + 1)) {
                    writeQueue.clear()
                    main.post { emitState("closed") }
                }
            }
        }.also {
            it.isDaemon = true
            it.name = "tnc-reader-$gen"
            it.start()
        }
    }

    /**
     * writer：串行写出待发字节。
     *
     * 串行化的意义不只是「不阻塞主线程」：两帧并发写会让 KISS 字节流交错
     * （FEND 落到帧中间），部分 TNC 会当作非法帧甚至复位链路 ——
     * 表现为「有概率发射后断开」。
     */
    private fun startWriter(sock: BluetoothSocket, gen: Int) {
        val out: OutputStream = try {
            sock.outputStream
        } catch (e: Exception) {
            emitState("closed")
            return
        }
        writer = Thread {
            while (generation.get() == gen) {
                val data = try {
                    writeQueue.poll(200, TimeUnit.MILLISECONDS)
                } catch (_: InterruptedException) {
                    break
                } ?: continue
                try {
                    out.write(data)
                    out.flush()
                    // 实际写出后才回报，供 Dart 侧区分「入队」与「真的发出去了」
                    emitTxOk(gen, data.size)
                } catch (e: Exception) {
                    val msg = e.message ?: e.javaClass.simpleName
                    main.post { if (generation.get() == gen) events?.success(
                        mapOf("type" to "txfail", "message" to msg)) }
                    // 写失败通常意味着链路已经死了（对端关闭/模块复位）。
                    // 主动关掉 socket，让 reader 报错退出 → Dart 侧触发重连；
                    // 否则会「显示已连接，但既发不出也收不到」。
                    try {
                        sock.close()
                    } catch (_: Exception) {
                    }
                    break
                }
            }
        }.also {
            it.isDaemon = true
            it.name = "tnc-writer-$gen"
            it.start()
        }
    }

    /** 入队发送（实际写出在 writer 线程，串行执行） */
    fun send(data: ByteArray) {
        val gen = generation.get()
        if (gen <= 0 || socket?.isConnected != true) {
            throw IllegalStateException("链路未连接")
        }
        // 队列满说明模块长时间不消费（多半已经卡死），明确报错而不是无限堆积
        if (!writeQueue.offer(data)) {
            throw IllegalStateException(
                "发送队列已满（${writeQueue.size}/$WRITE_QUEUE_MAX），TNC 可能已停止响应"
            )
        }
    }

    fun disconnect() {
        // 推进代次 + 拆链路：在飞的 reader/writer 会在下一轮循环退出，
        // 且不会误报 "closed"（只有当前代次的 reader 才有资格报）
        teardown()
        emitState("closed")
    }

    /** 推进代次并释放套接字（幂等，不广播状态） */
    private fun teardown() {
        generation.incrementAndGet()
        writeQueue.clear()
        try {
            socket?.inputStream?.close()
        } catch (_: Exception) {
        }
        try {
            socket?.outputStream?.close()
        } catch (_: Exception) {
        }
        try {
            socket?.close()
        } catch (_: Exception) {
        }
        socket = null
        reader = null
        writer = null
    }

    // ─── 事件通道 ───

    fun setEventSink(sink: EventChannel.EventSink?) {
        events = sink
    }

    /** 只上报当前代次的数据，旧链路的残留字节直接丢弃 */
    private fun emitBytes(data: ByteArray, gen: Int) {
        if (generation.get() != gen) return
        main.post {
            if (generation.get() == gen) {
                events?.success(mapOf("type" to "bytes", "data" to data))
            }
        }
    }

    private fun emitTxOk(gen: Int, size: Int) {
        if (generation.get() != gen) return
        main.post {
            if (generation.get() == gen) {
                events?.success(mapOf("type" to "txok", "size" to size))
            }
        }
    }

    private fun emitState(state: String) {
        main.post { events?.success(mapOf("type" to "state", "state" to state)) }
    }

    fun dispose() {
        try {
            disconnect()
        } catch (_: Exception) {
        }
        events = null
    }
}
