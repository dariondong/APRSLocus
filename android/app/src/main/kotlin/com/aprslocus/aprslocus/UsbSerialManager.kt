package com.aprslocus.aprslocus

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.usb.UsbConstants
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbDeviceConnection
import android.hardware.usb.UsbEndpoint
import android.hardware.usb.UsbInterface
import android.hardware.usb.UsbManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.LinkedBlockingQueue
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger

/**
 * USB 串口（USB-OTG）链路管理：给 **Android** 补上「硬件串口」这一条路。
 *
 * 为什么需要它：Android 侧此前只有经典蓝牙 SPP（[TncManager]），
 * 插一根 USB-OTG 转串口线（CH340 / CP2102 / FTDI / PL2303）或电台自带 USB 口
 * （CDC-ACM）时完全用不了 —— 而这类线恰恰是最便宜、最稳、延迟最低的接法。
 *
 * ── 设计原则与蓝牙侧完全一致 ──
 *   ① 原生侧**只搬字节**，KISS / AX.25 / NMEA 全在 Dart 侧（lib/kiss.dart）；
 *   ② **代次（generation）**隔离每条链路：每次 connect 成功 +1，断开也 +1，
 *      reader/writer 只处理自己那一代，且只有当前代次有资格宣布「断开」
 *      （蓝牙侧曾有「刚连上就断」的事故，原因就是旧 reader 误报断开）；
 *   ③ 写入放在**独立 writer 线程**串行执行：并发写会让 KISS 字节流交错
 *      （FEND 落到帧中间），部分 TNC 会当成非法帧甚至复位链路。
 *
 * ── 与蓝牙的差别 ──
 *   * USB 是**独占**设备，且必须先拿到 UsbManager 的访问授权；
 *   * 需要按芯片设置波特率与线路参数（蓝牙 SPP 没有波特率概念）；
 *   * 设备可能在应用运行时**热插拔**（attach / detach 广播）。
 *
 * ── 关于各芯片的波特率控制（诚实说明）──
 * Android 没有公开的 USB 串口 API，`UsbDeviceConnection` 只提供原始控制/批量
 * 传输，所以「设置波特率」必须自己按厂商协议发控制请求。本文件里的序列
 * 按各厂商公开资料与 usb-serial-for-android 的既有实现转写：
 *   * **CDC-ACM**：标准协议（SET_LINE_CODING 0x20 / SET_CONTROL_LINE_STATE 0x22），
 *     电台自带 USB 口与 Arduino 类设备走这条，最可靠；
 *   * **CP210x**：标准协议 0x00 / 0x03（部分老版本用 0x1E / 0x1F，两种都发）；
 *   * **CH34x**：厂商私有序列（0xA1 初始化 + 0x9A 写寄存器）；
 *   * **FTDI / PL2303**：厂商私有，**暂未实现**（见 [setLineCoding] 的说明）。
 * 未实现的那两类设备仍可打开与收发（很多模块出厂波特率就是 APRS 常用的
 * 9600 / 38400），但应用无法改它的波特率 —— 这时会在日志里明确说明，
 * 而不是静默地「设了个其实没生效的值」。
 *
 * ⚠️ 除 CDC 之外的控制序列**无法在本机验证**（开发机没有 USB 串口硬件，
 * 也没有 Android SDK 可编译），首次接真实设备时应以「有没有数据上来」为准，
 * 万一不工作，优先试 CDC 类线缆，并把日志发回。
 */
class UsbSerialManager(private val activity: android.app.Activity) {

    companion object {
        const val METHOD_CHANNEL = "com.aprslocus/usbserial"
        const val EVENT_CHANNEL = "com.aprslocus/usbserial_events"

        private const val ACTION_USB_PERMISSION = "com.aprslocus.USB_PERMISSION"

        /** 待写队列上限（与蓝牙侧一致） */
        private const val WRITE_QUEUE_MAX = 64

        /** 批量读超时（ms）。取小值是为了让代次检查能及时生效 */
        private const val READ_TIMEOUT_MS = 200

        /** 控制传输超时（ms） */
        private const val CTRL_TIMEOUT_MS = 2000
    }

    private val main = Handler(Looper.getMainLooper())

    private val generation = AtomicInteger(0)
    private val connecting = AtomicBoolean(false)

    private var events: EventChannel.EventSink? = null
    private var permResult: MethodChannel.Result? = null

    @Volatile
    private var connection: UsbDeviceConnection? = null

    @Volatile
    private var device: UsbDevice? = null

    @Volatile
    private var epIn: UsbEndpoint? = null

    @Volatile
    private var epOut: UsbEndpoint? = null

    @Volatile
    private var iface: UsbInterface? = null

    private var reader: Thread? = null
    private var writer: Thread? = null
    private val writeQueue = LinkedBlockingQueue<ByteArray>(WRITE_QUEUE_MAX)

    /** 当前链路用的波特率（供 UI / 日志显示） */
    @Volatile
    private var baudRate = 0

    /** 芯片类型（供日志显示） */
    @Volatile
    private var chipName = ""

    /** 权限广播是否已注册（幂等） */
    private val receiverRegistered = AtomicBoolean(false)

    private val permReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action != ACTION_USB_PERMISSION) return
            val granted = intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)
            val d = intent.getParcelableExtra<UsbDevice>(UsbManager.EXTRA_DEVICE)
            val r = permResult
            permResult = null
            if (r == null) return
            if (granted && d != null) {
                try {
                    openAndStart(d, requestedBaud)
                    r.success(true)
                } catch (e: Exception) {
                    r.error("USB_OPEN_FAILED", e.message ?: "打开 USB 串口失败", null)
                }
            } else {
                r.error("USB_NO_PERMISSION", "用户拒绝了 USB 访问授权", null)
            }
        }
    }

    /** 待授权时记住用户选的波特率（授权回调里要用） */
    @Volatile
    private var requestedBaud = 9600

    // ─── 热插拔 ───

    fun attach() {
        registerReceiver()
    }

    private fun registerReceiver() {
        if (!receiverRegistered.compareAndSet(false, true)) return
        try {
            val f = IntentFilter(ACTION_USB_PERMISSION)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                activity.registerReceiver(permReceiver, f, Context.RECEIVER_NOT_EXPORTED)
            } else {
                @Suppress("UnspecifiedRegisterReceiverFlag")
                activity.registerReceiver(permReceiver, f)
            }
        } catch (_: Exception) {
            receiverRegistered.set(false)
        }
    }

    fun detach() {
        teardown()
        if (receiverRegistered.compareAndSet(true, false)) {
            try {
                activity.unregisterReceiver(permReceiver)
            } catch (_: Exception) {
            }
        }
        events = null
    }

    fun setEventSink(sink: EventChannel.EventSink?) {
        events = sink
    }

    private fun emitBytes(data: ByteArray, gen: Int) {
        val sink = events ?: return
        main.post { if (generation.get() == gen) sink.success(mapOf("type" to "bytes", "data" to data)) }
    }

    private fun emitState(state: String) {
        val sink = events ?: return
        main.post { sink.success(mapOf("type" to "state", "state" to state)) }
    }

    // ─── 能力 / 设备列表 ───

    private fun usbManager(): UsbManager? =
        activity.getSystemService(Context.USB_SERVICE) as? UsbManager

    fun isSupported(): Boolean = usbManager() != null

    /**
     * 枚举当前已连接的 USB 串口设备。
     *
     * 判据（宽松优先，宁可多列一个也不漏）：
     *   ① 有 bulk IN 且 bulk OUT 的接口 → 就是串口设备（CDC / 各厂商线都是这形状）；
     *   ② 接口类为 0x02（CDC 通信类）/ 0x0A（CDC 数据类）/ 0xFF（厂商自定义）。
     * 只要满足 ① 或 ② 就列出，并在名称里给出 VID:PID —— 用户能据此对上自己的线。
     *
     * 为什么不按 VID 白名单：USB 转串口线用的 VID/PID 组合极多（还有大量
     * 白牌），按白名单会把用户手上的线判成「不支持」，而它其实完全能用。
     */
    fun listDevices(): List<Map<String, Any?>> {
        val mgr = usbManager() ?: return emptyList()
        val out = ArrayList<Map<String, Any?>>()
        for (d in mgr.deviceList.values) {
            if (!looksLikeSerial(d)) continue
            val name = try {
                d.productName ?: d.deviceName
            } catch (_: Exception) {
                d.deviceName
            }
            out.add(
                mapOf(
                    "id" to usbId(d),
                    "name" to "$name · ${chipOf(d)}",
                    "kind" to "usb",
                    "paired" to true,
                )
            )
        }
        return out.sortedBy { (it["name"] as String) }
    }

    /** 设备标识：VID:PID:serial —— 同一根线重插后 ID 保持稳定 */
    private fun usbId(d: UsbDevice): String {
        val serial = try {
            d.serialNumber ?: ""
        } catch (_: Exception) {
            ""
        }
        return "%04x:%04x:%s".format(d.vendorId, d.productId, serial)
    }

    private fun looksLikeSerial(d: UsbDevice): Boolean {
        for (i in 0 until d.interfaceCount) {
            val it = d.getInterface(i)
            var hasIn = false
            var hasOut = false
            for (e in 0 until it.endpointCount) {
                when (it.getEndpoint(e).direction) {
                    UsbConstants.USB_DIR_IN -> hasIn = true
                    UsbConstants.USB_DIR_OUT -> hasOut = true
                }
            }
            if (hasIn && hasOut) return true
            val cls = it.interfaceClass
            if (cls == UsbConstants.USB_CLASS_COMM ||
                cls == UsbConstants.USB_CLASS_CDC_DATA ||
                cls == 0xFF
            ) return true
        }
        return false
    }

    /** 按 VID/PID 猜芯片名（只用于显示与选择波特率策略） */
    private fun chipOf(d: UsbDevice): String {
        return when (d.vendorId) {
            0x1A86 -> "CH34x"                     // 南京沁恒
            0x10C4 -> "CP210x"                    // Silicon Labs
            0x0403 -> "FTDI"                      // FTDI
            0x067B, 0x04A9 -> "PL2303"            // Prolific
            0x2341, 0x2A03, 0x1B4F, 0x239A -> "CDC-ACM" // Arduino / Adafruit
            else -> if (isCdc(d)) "CDC-ACM" else "USB 串口"
        }
    }

    private fun isCdc(d: UsbDevice): Boolean {
        for (i in 0 until d.interfaceCount) {
            val cls = d.getInterface(i).interfaceClass
            if (cls == UsbConstants.USB_CLASS_COMM) return true
        }
        return false
    }

    // ─── 连接 ───

    /**
     * 打开设备并开始收发。
     *
     * 首次访问需要用户授权（系统弹窗）—— 这条路径是**异步**的：先注册广播
     * 再 requestPermission，结果回到 [permReceiver]。
     */
    fun connect(id: String, baudRate: Int, result: MethodChannel.Result) {
        if (!connecting.compareAndSet(false, true)) {
            result.error("USB_BUSY", "正在连接中，请稍后重试", null)
            return
        }
        try {
            val mgr = usbManager()
            if (mgr == null) {
                result.error("USB_UNSUPPORTED", "本机不支持 USB Host", null)
                return
            }
            requestedBaud = baudRate
            val d = mgr.deviceList.values.firstOrNull { usbId(it) == id }
                ?: mgr.deviceList.values.firstOrNull {
                    // 序列号可能为空且不稳定：允许只按 VID:PID 前缀匹配
                    usbId(it).startsWith(id.substringBeforeLast(':'))
                }
            if (d == null) {
                result.error("USB_NOT_FOUND", "没有找到该 USB 设备（是否已拔出？）", null)
                return
            }
            if (mgr.hasPermission(d)) {
                try {
                    openAndStart(d, baudRate)
                    result.success(true)
                } catch (e: Exception) {
                    result.error("USB_OPEN_FAILED", e.message ?: "打开 USB 串口失败", null)
                }
            } else {
                // 授权是异步的：把 result 存起来，广播回来再回复
                permResult = result
                registerReceiver()
                val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S)
                    PendingIntent.FLAG_MUTABLE else 0
                val pi = PendingIntent.getBroadcast(
                    activity, 0,
                    Intent(ACTION_USB_PERMISSION).setPackage(activity.packageName),
                    flags
                )
                mgr.requestPermission(d, pi)
            }
        } catch (e: Exception) {
            result.error("USB_CONNECT_FAILED", e.message ?: "连接失败", null)
        } finally {
            // 注意：授权路径尚未完成，这里只释放「正在连接」标记；
            // openAndStart 之后的失败由异常路径处理。
            connecting.set(false)
        }
    }

    /** 真正打开接口 / 找端点 / 设线路参数 / 起线程 */
    private fun openAndStart(d: UsbDevice, baud: Int) {
        val mgr = usbManager() ?: throw IllegalStateException("USB 服务不可用")
        teardown()

        val (it, ein, eout) = pickInterface(d)
            ?: throw IllegalStateException("该设备没有可用的串口接口（需要批量 IN/OUT 端点）")

        val conn = mgr.openDevice(d)
            ?: throw IllegalStateException("打开设备失败（可能被其它应用占用）")

        if (!conn.claimInterface(it, true)) {
            try {
                conn.close()
            } catch (_: Exception) {
            }
            throw IllegalStateException("占用接口失败（可能有其它串口应用正在使用）")
        }

        chipName = chipOf(d)
        baudRate = baud
        connection = conn
        device = d
        iface = it
        epIn = ein
        epOut = eout

        // 波特率/线路参数：失败不阻断（有些模块出厂参数就能用），但要在日志里说清
        val ok = setLineCoding(conn, d, baud)
        emitState(
            "usbOpened:$chipName@${baud}baud" + if (ok) "" else " (波特率未生效，见日志)"
        )

        val gen = generation.incrementAndGet()
        startWriter(gen)
        startReader(gen)
        emitState("connected")
    }

    /** 选接口与端点：优先有批量 IN+OUT 的接口；IN 端点是批量最好，其次中断 */
    private fun pickInterface(d: UsbDevice): Triple<UsbInterface, UsbEndpoint, UsbEndpoint>? {
        var fallback: Triple<UsbInterface, UsbEndpoint, UsbEndpoint>? = null
        for (i in 0 until d.interfaceCount) {
            val it = d.getInterface(i)
            var inBulk: UsbEndpoint? = null
            var inInt: UsbEndpoint? = null
            var outBulk: UsbEndpoint? = null
            var outAny: UsbEndpoint? = null
            for (e in 0 until it.endpointCount) {
                val ep = it.getEndpoint(e)
                if (ep.direction == UsbConstants.USB_DIR_IN) {
                    if (ep.type == UsbConstants.USB_ENDPOINT_XFER_BULK) inBulk = inBulk ?: ep
                    else inInt = inInt ?: ep
                } else {
                    if (ep.type == UsbConstants.USB_ENDPOINT_XFER_BULK) outBulk = outBulk ?: ep
                    else outAny = outAny ?: ep
                }
            }
            val ein = inBulk ?: inInt
            val eout = outBulk ?: outAny
            if (ein != null && eout != null) {
                val t = Triple(it, ein, eout)
                // 批量两端齐全才算「理想接口」，否则记下来兜底
                if (inBulk != null && outBulk != null) return t
                if (fallback == null) fallback = t
            }
        }
        return fallback
    }

    /**
     * 按芯片类型设置波特率与线路参数。返回是否**确认生效**。
     *
     * 说明见文件头：Android 没有公开串口 API，这里全是按厂商协议手写的
     * 控制请求。CDC 类最可靠；厂商私有的按公开实现转写，需要用真机确认。
     */
    private fun setLineCoding(conn: UsbDeviceConnection, d: UsbDevice, baud: Int): Boolean {
        return try {
            when {
                d.vendorId == 0x1A86 -> setCh34xBaud(conn, baud)
                d.vendorId == 0x10C4 -> setCp210xBaud(conn, baud)
                d.vendorId == 0x0403 -> {
                    // FTDI 需要厂商私有序列（0x03 SET_BAUDRATE）与随波特率变化的
                    // 分频参数，本版本未实现 —— 如实说明，不假装成功。
                    emitState("usb-ftdi-baud-unsupported")
                    false
                }
                d.vendorId == 0x067B || d.vendorId == 0x04A9 -> {
                    emitState("usb-pl2303-baud-unsupported")
                    false
                }
                else -> setCdcLineCoding(conn, baud)
            }
        } catch (e: Exception) {
            emitState("usb-baud-error:${e.message}")
            false
        }
    }

    /** CDC-ACM 标准：SET_LINE_CODING(0x20) + SET_CONTROL_LINE_STATE(0x22, DTR|RTS) */
    private fun setCdcLineCoding(conn: UsbDeviceConnection, baud: Int): Boolean {
        val line = ByteArray(7)
        line[0] = (baud and 0xFF).toByte()
        line[1] = ((baud shr 8) and 0xFF).toByte()
        line[2] = ((baud shr 16) and 0xFF).toByte()
        line[3] = ((baud shr 24) and 0xFF).toByte()
        line[4] = 0 // 1 停止位
        line[5] = 0 // 无校验
        line[6] = 8 // 8 数据位
        val a = conn.controlTransfer(0x21, 0x20, 0, 0, line, line.size, CTRL_TIMEOUT_MS)
        // DTR=1 RTS=1：很多 USB 串口模块靠这两根线判断「主机已就绪」，
        // 不置位时表现为「打开了但一个字节都不吐」
        val b = conn.controlTransfer(0x21, 0x22, 0x03, 0, null, 0, CTRL_TIMEOUT_MS)
        return a >= 0 && b >= 0
    }

    /**
     * CP210x：0x00 IFC_ENABLE + 0x03 SET_BAUDRATE。
     * 老版本（CP2101/2 早期固件）用 0x1E / 0x1F，两种都发一遍更稳
     * （多发的那个旧固件会忽略，不会破坏状态）。
     */
    private fun setCp210xBaud(conn: UsbDeviceConnection, baud: Int): Boolean {
        conn.controlTransfer(0x41, 0x00, 0x0001, 0, null, 0, CTRL_TIMEOUT_MS)
        val b = ByteArray(4)
        b[0] = (baud and 0xFF).toByte()
        b[1] = ((baud shr 8) and 0xFF).toByte()
        b[2] = ((baud shr 16) and 0xFF).toByte()
        b[3] = ((baud shr 24) and 0xFF).toByte()
        var ok = conn.controlTransfer(0x41, 0x03, 0, 0, b, 4, CTRL_TIMEOUT_MS) >= 0
        // 旧固件兼容路径
        val b2 = ByteArray(2)
        b2[0] = (baud and 0xFF).toByte()
        b2[1] = ((baud shr 8) and 0xFF).toByte()
        ok = conn.controlTransfer(0x41, 0x1E, 0, 0, b2, 2, CTRL_TIMEOUT_MS) >= 0 || ok
        conn.controlTransfer(0x41, 0x1F, 0, 0, null, 0, CTRL_TIMEOUT_MS)
        // 8 数据位、无校验、1 停止位、无流控（0x0800 = 8N1）
        conn.controlTransfer(0x41, 0x04, 0x0800, 0, null, 0, CTRL_TIMEOUT_MS)
        return ok
    }

    /**
     * CH34x（CH340/CH341）：厂商私有序列，转写自公开的 usb-serial-for-android。
     *
     * 分频计算：CH341 基准 48MHz，厂商驱动用 1532620800 这个常数
     * （= 48MHz/2 * 64 之类的折算），再按 divisor 缩放后写入 0x1312。
     */
    private fun setCh34xBaud(conn: UsbDeviceConnection, baud: Int): Boolean {
        // 初始化序列（顺序不能变）
        conn.controlTransfer(0x40, 0xA1, 0, 0, null, 0, CTRL_TIMEOUT_MS)
        conn.controlTransfer(0x40, 0x9A, 0x1312, 0xD982, null, 0, CTRL_TIMEOUT_MS)
        conn.controlTransfer(0x40, 0x9A, 0x0F2C, 0x0004, null, 0, CTRL_TIMEOUT_MS)

        // 分频：与 usb-serial-for-android 的算法一致
        var factor = 1532620800 / baud
        var divisor = 3
        while (factor > 0xFF * divisor) divisor += 1
        val value = 0x10000 - (factor / divisor)
        val r1 = conn.controlTransfer(
            0x40, 0x9A, 0x1312, value and 0xFFFF, null, 0, CTRL_TIMEOUT_MS
        )
        // 0x0F2C / 0x0004：关流控；再写一次 0x1312 的镜像寄存器
        conn.controlTransfer(0x40, 0x9A, 0x0F2C, 0x0004, null, 0, CTRL_TIMEOUT_MS)
        val r2 = conn.controlTransfer(
            0x40, 0x9A, 0x2518, 0x0000, null, 0, CTRL_TIMEOUT_MS
        )
        return r1 >= 0 && r2 >= 0
    }

    // ─── 读 / 写 ───

    private fun startReader(gen: Int) {
        val ep = epIn ?: return
        val conn = connection ?: return
        reader = Thread {
            val buf = ByteArray(1024)
            var reason: String? = null
            try {
                while (generation.get() == gen) {
                    val n = try {
                        conn.bulkTransfer(ep, buf, buf.size, READ_TIMEOUT_MS)
                    } catch (e: Exception) {
                        reason = e.message ?: "read-error"
                        break
                    }
                    if (n < 0) continue // 超时：正常现象（空闲信道），继续等
                    if (n > 0) emitBytes(buf.copyOf(n), gen)
                }
            } finally {
                // 只有「仍是当前代次」的 reader 才有资格宣布断开，
                // 否则重连时旧线程会把新链路误报为断开（蓝牙侧的老事故）
                if (reason != null && generation.compareAndSet(gen, gen + 1)) {
                    writeQueue.clear()
                    connection = null
                    device = null
                    iface = null
                    epIn = null
                    epOut = null
                    reader = null
                    writer = null
                    main.post { emitState("closed") }
                }
            }
        }.also {
            it.isDaemon = true
            it.name = "usbserial-reader-$gen"
            it.start()
        }
    }

    private fun startWriter(gen: Int) {
        val ep = epOut ?: return
        val conn = connection ?: return
        writer = Thread {
            while (generation.get() == gen) {
                val data = try {
                    writeQueue.poll(200, TimeUnit.MILLISECONDS)
                } catch (_: InterruptedException) {
                    break
                } ?: continue
                try {
                    var off = 0
                    var guard = 0
                    while (off < data.size && guard < 100) {
                        val n = conn.bulkTransfer(ep, data.copyOfRange(off, data.size), data.size - off, 2000)
                        if (n <= 0) break
                        off += n
                        guard++
                    }
                    if (off == data.size) {
                        main.post { if (generation.get() == gen) events?.success(
                            mapOf("type" to "txack", "size" to data.size)
                        ) }
                    } else {
                        main.post { if (generation.get() == gen) events?.success(
                            mapOf("type" to "txfail", "message" to "写入不全（$off/${data.size}）")
                        ) }
                    }
                } catch (e: Exception) {
                    val msg = e.message ?: e.javaClass.simpleName
                    main.post { if (generation.get() == gen) events?.success(
                        mapOf("type" to "txfail", "message" to msg)
                    ) }
                    break
                }
            }
        }.also {
            it.isDaemon = true
            it.name = "usbserial-writer-$gen"
            it.start()
        }
    }

    fun send(data: ByteArray) {
        val gen = generation.get()
        if (gen <= 0 || connection == null) {
            throw IllegalStateException("USB 串口未连接")
        }
        if (!writeQueue.offer(data)) {
            throw IllegalStateException(
                "发送队列已满（${writeQueue.size}/$WRITE_QUEUE_MAX），设备可能已停止响应"
            )
        }
    }

    fun isConnected(): Boolean = generation.get() > 0 && connection != null

    /** 当前链路信息（供 UI 显示芯片与波特率） */
    fun info(): Map<String, Any?> = mapOf(
        "chip" to chipName,
        "baud" to baudRate
    )

    fun disconnect() {
        teardown()
        emitState("closed")
    }

    /** 推进代次并释放 USB 资源（幂等，不广播状态） */
    private fun teardown() {
        generation.incrementAndGet()
        writeQueue.clear()
        try {
            iface?.let { connection?.releaseInterface(it) }
        } catch (_: Exception) {
        }
        try {
            connection?.close()
        } catch (_: Exception) {
        }
        connection = null
        device = null
        iface = null
        epIn = null
        epOut = null
        reader = null
        writer = null
    }
}
