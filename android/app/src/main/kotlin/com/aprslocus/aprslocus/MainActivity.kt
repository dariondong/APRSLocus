package com.aprslocus.aprslocus

import android.Manifest
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.aprslocus/location"
    private val EVENT_CHANNEL = "com.aprslocus/location_events"
    private var permCompleter: MethodChannel.Result? = null

    // 备份导入的文件选择：系统文件选择器是异步的（先 startActivityForResult，
    // 结果在 onActivityResult 里回来），所以这里要暂存 Dart 侧的 Result，
    // 等选完再回。同一时刻只允许一个选择在飞（否则两个 Result 会互相踩）。
    private var pickCompleter: MethodChannel.Result? = null

    // 当前这次选择要的是文本还是二进制。放在字段上而不是靠 requestCode 区分：
    // 两者用的是同一个 startActivityForResult，结果回调里分不出来。
    private var pickBinary = false

    // 这次要读的字节上限。由 Dart 传进来：图标 2MB、背景图 8MB ——
    // 上限必须**在读之前**就知道，否则大文件照样会把内存吃爆。
    private var pickMaxBytes = MAX_ICON_BYTES
    private companion object {
        const val REQ_PICK_BACKUP = 4711

        // 备份文本上限：读进来要整体转成 String 传给 Dart，
        // 不设上限的话一个误选的几个 G 的文件就能把应用 OOM 掉。
        // 32MB 对「设置+消息记录」来说已经极其宽松。
        const val MAX_BACKUP_BYTES = 32 * 1024 * 1024

        // 主题自定义图标的大小上限（与 Dart 侧 kIconMaxBytes 保持一致）
        const val MAX_ICON_BYTES = 2 * 1024 * 1024
    }

    // 蓝牙 TNC（经典蓝牙 SPP）：只搬字节，KISS/AX.25 在 Dart 侧
    private var tnc: TncManager? = null

    // PKWDWPL 链路（Kenwood `$PKWDWPL` 航点语句）：同样的字节搬运，
    // 但走**独立通道 + 独立 socket** —— 与 TNC 是并列的两条链路，
    // 可以同时开着（各连各的设备）。协议区别全在 Dart 侧
    // （lib/pkwdwpl.dart 按行解析 NMEA，而不是解 KISS 帧）。
    private var pkwdwpl: TncManager? = null

    // 声卡 TNC（AFSK 1200）：同样只搬 PCM 采样，调制解调在 Dart 侧
    private var audio: AudioManager? = null

    // USB 串口（USB-OTG）：Android 侧此前只有蓝牙 SPP，插 USB 转串口线
    // （CH340 / CP2102 / FTDI）或电台自带 USB 口时用不了。同样只搬字节，
    // KISS/AX.25 全在 Dart 侧 —— 与蓝牙侧同一套分层。
    private var usbSerial: UsbSerialManager? = null

    // 运动传感器（加速度计 + 指南针）：只服务「自己」的轨迹打点（低速航向
    // 补正 + 判断是否真的在动）。通道常挂，Dart 侧按需 start/stop/sample。
    private var motion: MotionManager? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 桌面小组件桥：Dart 把算好的天气快照推过来，这里落盘并刷新组件
        WeatherWidgetBridge(this, flutterEngine.dartExecutor.binaryMessenger).attach()

        // 运动传感器桥：拉取式（Dart 每次定位回调 sample 一次），
        // 避免持续的事件流；没有传感器的设备 start() 返回 false。
        val motionManager = MotionManager(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MotionManager.CHANNEL)
            .setMethodCallHandler { call, result -> motionManager.handle(call, result) }
        motion = motionManager

        // 方法通道：控制定位服务 + 权限
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startService" -> {
                    val mode = call.argument<String>("mode") ?: "gps_network"
                    if (mode == LocationService.MODE_KEEPALIVE) {
                        // 模拟位置模式：不需要定位权限，但**仍需前台服务**，
                        // 否则应用一切到后台就会被冻结/回收：
                        // APRS-IS 连接断开、信标定时器停摆、地图不再刷新。
                        startLocationService(mode)
                        result.success(true)
                    } else if (!hasPermissions()) {
                        result.error("NO_PERMISSION", "缺少定位权限", null)
                    } else {
                        startLocationService(mode)
                        result.success(true)
                    }
                }
                "stopService" -> {
                    stopLocationService()
                    result.success(true)
                }
                "setLocationMode" -> {
                    val mode = call.argument<String>("mode") ?: "gps_network"
                    LocationService.setModeStatic(mode)
                    result.success(true)
                }
                "updateNotification" -> {
                    val text = call.argument<String>("text") ?: "APRSlocus 运行中"
                    updateServiceNotification(text)
                    result.success(true)
                }
                "showMessage" -> {
                    val from = call.argument<String>("from") ?: ""
                    val text = call.argument<String>("text") ?: ""
                    NotifHelper.showMessage(this, from, text)
                    result.success(true)
                }
                "getBattery" -> {
                    val bm = getSystemService(BATTERY_SERVICE) as android.os.BatteryManager
                    val level = bm.getIntProperty(android.os.BatteryManager.BATTERY_PROPERTY_CAPACITY)
                    result.success(level)
                }
                "checkPermissions" -> result.success(hasPermissions())
                "requestPermissions" -> {
                    if (hasPermissions()) {
                        result.success(true)
                    } else {
                        permCompleter = result
                        requestPermissionsNow()
                    }
                }
                else -> result.notImplemented()
            }
        }

        // 事件通道：接收位置更新（服务通过 LocationBus 单例直连）
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    LocationBus.sink = events
                }
                override fun onCancel(arguments: Any?) {
                    LocationBus.sink = null
                }
            }
        )

        // 蓝牙 SPP 链路通道。
        //
        // TNC 与 PKWDWPL 用的**是同一套字节搬运**（本管理类只搬字节，
        // KISS/AX.25 与 NMEA 解析全在 Dart 侧）；差别只有通道名与套接字，
        // 所以把「挂通道」抽成一个局部函数挂两次。
        //
        // 为什么必须两条独立通道：TncManager 内部只维护**一个** socket，
        // 共用通道会让两条链路互抢同一条连接（开了 TNC，PKWDWPL 就断）。
        // 各自独立之后可以同时运行，例如 TNC 接电台做 KISS 收发、
        // PKWDWPL 接另一台电台只读航点。
        fun wireSppLink(manager: TncManager, methodName: String, eventName: String) {
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodName)
                .setMethodCallHandler { call, result ->
                    when (call.method) {
                        "isSupported" -> result.success(manager.isSupported())
                        "listBondedDevices" -> {
                            try {
                                result.success(manager.listBondedDevices())
                            } catch (e: Exception) {
                                result.error("BT_LIST_FAILED", e.message ?: "列出蓝牙设备失败", null)
                            }
                        }
                        "connect" -> {
                            val address = call.argument<String>("address")
                            if (address.isNullOrEmpty()) {
                                result.error("NO_ADDRESS", "缺少设备地址", null)
                            } else {
                                try {
                                    manager.connect(address)
                                    // 蓝牙已接入：让前台服务声明 connectedDevice 类型。
                                    // 与音频同一个坑 —— Android 14+ 不声明就会在退到
                                    // 后台后限制蓝牙访问（表现为「切后台收不到报文」）。
                                    setBtActive(true)
                                    result.success(true)
                                } catch (e: Exception) {
                                    result.error("BT_CONNECT_FAILED", e.message ?: "连接失败", null)
                                }
                            }
                        }
                        "disconnect" -> {
                            try {
                                manager.disconnect()
                            } catch (_: Exception) {
                            }
                            // 只有两条 SPP 链路都断开时才撤销 connectedDevice 声明。
                            // 判断用「另一个 manager 是否还连着」而不是各记各的状态 ——
                            // 否则先断开的那条会把仍在工作的那条的类型声明撤掉，
                            // 重新落回「后台被限制蓝牙」的坑里。
                            val other = if (manager === tnc) pkwdwpl else tnc
                            setBtActive(other?.isConnected() == true)
                            result.success(true)
                        }
                        "send" -> {
                            val data = call.argument<ByteArray>("data")
                            if (data == null) {
                                // 明确的诊断信息：Dart 侧若传 List<int>（而不是 Uint8List），
                                // StandardMessageCodec 会编成 ArrayList，这里必然取不到
                                // ByteArray —— 曾经因此「蓝牙能收不能发且毫无提示」。
                                val raw = call.argument<Any>("data")
                                result.error(
                                    "NO_DATA",
                                    "缺少数据：期望 ByteArray，实际收到 " +
                                        (raw?.javaClass?.name ?: "null") +
                                        "。Dart 侧必须传 Uint8List（见 Kiss.escape 注释）",
                                    null
                                )
                            } else {
                                try {
                                    manager.send(data)
                                    result.success(true)
                                } catch (e: Exception) {
                                    result.error("BT_SEND_FAILED", e.message ?: "发送失败", null)
                                }
                            }
                        }
                        "requestPermissions" -> manager.requestPermissions(result)
                        else -> result.notImplemented()
                    }
                }
            EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventName)
                .setStreamHandler(
                    object : EventChannel.StreamHandler {
                        override fun onListen(arguments: Any?, things: EventChannel.EventSink?) {
                            manager.setEventSink(things)
                        }

                        override fun onCancel(arguments: Any?) {
                            manager.setEventSink(null)
                        }
                    }
                )
        }

        // ① TNC（KISS 收发）
        val tncManager = TncManager(this)
        tnc = tncManager
        wireSppLink(tncManager, TncManager.METHOD_CHANNEL, TncManager.EVENT_CHANNEL)

        // ② PKWDWPL（Kenwood 航点语句，只读）
        val pkwdwplManager = TncManager(
            this,
            TncManager.METHOD_CHANNEL_PKWDWPL,
            TncManager.EVENT_CHANNEL_PKWDWPL,
            // 权限 requestCode 必须与 TNC 不同：下面 onRequestPermissionsResult
            // 会把结果转发给**两个**实例，共用同一个 code 会让两边同时命中，
            // 把对方尚未完成的 permResult 误 resolve。
            TncManager.PERM_REQUEST_PKWDWPL,
        )
        pkwdwpl = pkwdwplManager
        wireSppLink(
            pkwdwplManager,
            TncManager.METHOD_CHANNEL_PKWDWPL,
            TncManager.EVENT_CHANNEL_PKWDWPL,
        )

        // 音频通道（声卡 TNC）：采集 PCM16 上传 / 接收 PCM16 播放
        val audioManager = AudioManager(this)
        audio = audioManager
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AudioManager.METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isSupported" -> result.success(audioManager.isSupported())
                    "requestPermissions" -> audioManager.requestPermissions(result)
                    "startCapture" -> {
                        val rate = call.argument<Int>("sampleRate") ?: 22050
                        result.success(audioManager.startCapture(rate))
                    }
                    "stopCapture" -> {
                        audioManager.stopCapture()
                        result.success(true)
                    }
                    "play" -> {
                        val data = call.argument<ByteArray>("data")
                        val rate = call.argument<Int>("sampleRate") ?: 22050
                        if (data == null) {
                            result.error("NO_DATA", "缺少音频数据", null)
                        } else {
                            result.success(audioManager.play(data, rate))
                        }
                    }
                    "stopPlayback" -> {
                        audioManager.stopPlayback()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, AudioManager.EVENT_CHANNEL)
            .setStreamHandler(
                object : EventChannel.StreamHandler {
                    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                        audioManager.setEventSink(events)
                        setAudioCaptureActive(true)
                    }

                    override fun onCancel(arguments: Any?) {
                        audioManager.setEventSink(null)
                        setAudioCaptureActive(false)
                    }
                }
            )

        // USB 串口通道：枚举 / 授权 / 打开 / 收发（只搬字节）
        val usbManager = UsbSerialManager(this)
        usbSerial = usbManager
        usbManager.attach()
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, UsbSerialManager.METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isSupported" -> result.success(usbManager.isSupported())
                    "listDevices" -> {
                        try {
                            result.success(usbManager.listDevices())
                        } catch (e: Exception) {
                            result.error("USB_LIST_FAILED", e.message ?: "列出 USB 设备失败", null)
                        }
                    }
                    "connect" -> {
                        val id = call.argument<String>("id")
                        val baud = call.argument<Int>("baudRate") ?: 9600
                        if (id.isNullOrEmpty()) {
                            result.error("NO_ID", "缺少设备标识", null)
                        } else {
                            usbManager.connect(id, baud, result)
                            // USB 已接入：让前台服务声明 connectedDevice 类型。
                            // 与蓝牙/音频同一个坑 —— Android 14+ 不声明就会在退到
                            // 后台后限制 USB 访问（表现为「切后台收不到报文」）。
                            setBtActive(true)
                        }
                    }
                    "disconnect" -> {
                        try {
                            usbManager.disconnect()
                        } catch (_: Exception) {
                        }
                        val otherBt = if (tnc?.isConnected() == true || pkwdwpl?.isConnected() == true) true else false
                        setBtActive(otherBt)
                        result.success(true)
                    }
                    "send" -> {
                        val data = call.argument<ByteArray>("data")
                        if (data == null) {
                            // 与蓝牙侧同一条教训：List<int> 会编成 ArrayList，
                            // Kotlin 侧取 ByteArray 得 null（发送静默失败）
                            val raw = call.argument<Any>("data")
                            result.error(
                                "NO_DATA",
                                "缺少数据：期望 ByteArray，实际收到 " +
                                    (raw?.javaClass?.name ?: "null") +
                                    "。Dart 侧必须传 Uint8List（见 Kiss.escape 注释）",
                                null
                            )
                        } else {
                            try {
                                usbManager.send(data)
                                result.success(true)
                            } catch (e: Exception) {
                                result.error("USB_SEND_FAILED", e.message ?: "发送失败", null)
                            }
                        }
                    }
                    "requestPermissions" -> {
                        // USB 的授权是**按设备**、由系统弹窗完成的（见 connect），
                        // 没有可预先申请的运行时权限 —— 恒为 true，免得上层把
                        // 「还没插线」误判成「没有权限」。
                        result.success(true)
                    }
                    "info" -> result.success(usbManager.info())
                    else -> result.notImplemented()
                }
            }
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, UsbSerialManager.EVENT_CHANNEL)
            .setStreamHandler(
                object : EventChannel.StreamHandler {
                    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                        usbManager.setEventSink(events)
                    }

                    override fun onCancel(arguments: Any?) {
                        usbManager.setEventSink(null)
                    }
                }
            )

        // 安装器通道：安装 APK 更新包
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.aprslocus/installer").setMethodCallHandler { call, result ->
            when (call.method) {
                "installApk" -> {
                    val path = call.argument<String>("path")
                    if (path == null) {
                        result.error("NO_PATH", "缺少安装包路径", null)
                    } else {
                        val ok = installApk(path)
                        result.success(ok)
                    }
                }
                "canRequestInstall" -> result.success(canRequestPackageInstalls())
                "openInstallSettings" -> {
                    openInstallSettings()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // 退出通道：设置页"退出应用"→ 结束前台服务 + 移除任务 + 结束进程
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.aprslocus/exit").setMethodCallHandler { call, result ->
            when (call.method) {
                "exitApp" -> {
                    try {
                        stopLocationService()
                    } catch (_: Exception) {
                        // 定位服务未启动等场景忽略
                    }
                    finishAndRemoveTask()
                    // 给 Dart 侧回执留时间后彻底结束进程（避免仅回桌面但进程残留）
                    android.os.Handler(mainLooper).postDelayed({
                        android.os.Process.killProcess(android.os.Process.myPid())
                    }, 200)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // 分享通道：调用系统分享面板（微信 / QQ 等）
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.aprslocus/share").setMethodCallHandler { call, result ->
            when (call.method) {
                "shareText" -> {
                    val text = call.argument<String>("text") ?: ""
                    shareText(text)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // 导出通道：把文本文件写入「下载」目录（供 ADIF 导出 / 备份导出使用）
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.aprslocus/export").setMethodCallHandler { call, result ->
            when (call.method) {
                "saveToDownloads" -> {
                    val filename = call.argument<String>("filename") ?: "export.adi"
                    val content = call.argument<String>("content") ?: ""
                    // 备份是 application/json，ADIF/音频保持 text/plain。
                    // 不能都写 text/plain：部分系统会据此给文件名追加 .txt。
                    val mime = call.argument<String>("mimeType") ?: "text/plain"
                    val path = saveToDownloads(filename, content, mime)
                    if (path == null) {
                        result.error("SAVE_FAILED", "保存失败", null)
                    } else {
                        result.success(path)
                    }
                }
                // 音频 WAV 导出：二进制不能走 saveToDownloads（那条按 UTF-8 写文本）
                "saveBytesToDownloads" -> {
                    val filename = call.argument<String>("filename") ?: "audio.wav"
                    val b64 = call.argument<String>("base64")
                    val mime = call.argument<String>("mimeType") ?: "audio/wav"
                    if (b64 == null) {
                        result.error("NO_DATA", "缺少文件内容", null)
                    } else {
                        val bytes = try {
                            android.util.Base64.decode(b64, android.util.Base64.DEFAULT)
                        } catch (_: Exception) {
                            null
                        }
                        if (bytes == null) {
                            result.error("BAD_DATA", "文件内容解码失败", null)
                        } else {
                            val path = saveBytesToDownloads(filename, bytes, mime)
                            if (path == null) {
                                result.error("SAVE_FAILED", "保存失败", null)
                            } else {
                                result.success(path)
                            }
                        }
                    }
                }
                // 备份导入：拉起系统文件选择器，返回 {name, content}
                // 用户取消返回 null；文件过大 / 读失败走 error
                "pickTextFile" -> pickTextFile(result)
                // 主题自定义图标：同一条选择器，但要把**二进制**读回来。
                // 不能复用 pickTextFile：图片按 UTF-8 解码会被替换字符破坏，
                // 得到的是一堆「看起来像文本」的垃圾。这里改成 base64。
                "pickBinaryFile" -> pickBinaryFile(
                    result,
                    call.argument<Int>("maxBytes") ?: MAX_ICON_BYTES
                )
                else -> result.notImplemented()
            }
        }
    }

    /// 拉起系统文件选择器（ACTION_GET_CONTENT），把选中的文本文件读回 Dart。
    ///
    /// 用 GET_CONTENT 而不是 OPEN_DOCUMENT：前者任何文件管理器都支持，
    /// 且拿到的是临时读权限，够读一次备份；不需要持久化权限。
    private fun pickTextFile(result: MethodChannel.Result) {
        if (pickCompleter != null) {
            result.error("BUSY", "已有文件选择在进行中", null)
            return
        }
        pickCompleter = result
        pickBinary = false
        try {
            val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
                type = "*/*"
                addCategory(Intent.CATEGORY_OPENABLE)
                // 有些文件管理器对 .json 的 MIME 识别成 octet-stream，
                // 所以 type 用 */* 兜底，只把 json/plain 作为优先提示。
                putExtra(
                    Intent.EXTRA_MIME_TYPES,
                    arrayOf("application/json", "text/plain")
                )
            }
            startActivityForResult(
                Intent.createChooser(intent, "APRSlocus"),
                REQ_PICK_BACKUP
            )
        } catch (e: Exception) {
            pickCompleter = null
            result.error("NO_PICKER", e.message, null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQ_PICK_BACKUP) return
        val completer = pickCompleter ?: return
        pickCompleter = null
        val uri = data?.data
        if (resultCode != RESULT_OK || uri == null) {
            // 用户取消：不是错误，回 null（Dart 侧据此区分「取消」与「读失败」）
            completer.success(null)
            return
        }
        val binary = pickBinary
        pickBinary = false
        try {
            val name = displayNameOf(uri) ?: if (binary) "icon.png" else "backup.json"
            if (binary) {
                // 上限用 MAX_ICON_BYTES（2MB）：图标要塞进 22~40dp 的位置，
                // 2MB 已极宽松；不设限的话一张手机原图就能变成主题里的巨石。
                val bytes = readBytesCapped(uri, pickMaxBytes)
                if (bytes == null) {
                    completer.error("TOO_LARGE", "图片过大", null)
                    return
                }
                val b64 = android.util.Base64.encodeToString(
                    bytes, android.util.Base64.NO_WRAP
                )
                completer.success(mapOf("name" to name, "data" to b64))
            } else {
                val text = readTextCapped(uri, MAX_BACKUP_BYTES)
                if (text == null) {
                    completer.error("TOO_LARGE", "文件过大", null)
                    return
                }
                completer.success(mapOf("name" to name, "content" to text))
            }
        } catch (e: Exception) {
            completer.error("READ_FAILED", e.message, null)
        }
    }

    /// 读取二进制，超过 [max] 字节返回 null（与文本版同样的分块思路）
    private fun readBytesCapped(uri: Uri, max: Int): ByteArray? {
        val input = contentResolver.openInputStream(uri) ?: return null
        input.use { ins ->
            val buf = ByteArrayOutputStream()
            val chunk = ByteArray(64 * 1024)
            while (true) {
                val n = ins.read(chunk)
                if (n <= 0) break
                if (buf.size() + n > max) return null
                buf.write(chunk, 0, n)
            }
            return buf.toByteArray()
        }
    }

    /// 与 [pickTextFile] 同一条选择器，但以 base64 返回二进制（主题图标用）。
    private fun pickBinaryFile(result: MethodChannel.Result, maxBytes: Int) {
        if (pickCompleter != null) {
            result.error("BUSY", "已有文件选择在进行中", null)
            return
        }
        pickCompleter = result
        pickBinary = true
        pickMaxBytes = if (maxBytes > 0) maxBytes else MAX_ICON_BYTES
        try {
            val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
                type = "image/*"
                addCategory(Intent.CATEGORY_OPENABLE)
                // 部分机型把 svg/webp 识别成 octet-stream，所以只当提示用
                putExtra(
                    Intent.EXTRA_MIME_TYPES,
                    arrayOf("image/*", "application/octet-stream")
                )
            }
            startActivityForResult(
                Intent.createChooser(intent, "APRSlocus"),
                REQ_PICK_BACKUP
            )
        } catch (e: Exception) {
            pickCompleter = null
            result.error("NO_PICKER", e.message, null)
        }
    }

    /// 读取文本文件，超过 [max] 字节返回 null（继续读下去只会把内存吃爆）。
    /// 用分块读取而不是 readBytes()：后者会先按不限长度分配。
    private fun readTextCapped(uri: Uri, max: Int): String? {
        val input = contentResolver.openInputStream(uri) ?: return null
        input.use { ins ->
            val buf = ByteArrayOutputStream()
            val chunk = ByteArray(64 * 1024)
            while (true) {
                val n = ins.read(chunk)
                if (n <= 0) break
                if (buf.size() + n > max) return null
                buf.write(chunk, 0, n)
            }
            return buf.toString(Charsets.UTF_8.name())
        }
    }

    /// 把文本写入「下载」目录，返回用户可见的路径；失败返回 null。
    ///
    /// - Android 10（API 29）及以上：走 MediaStore，**无需任何存储权限**
    ///   （应用向 Downloads 集合插入自己的内容不需要 WRITE_EXTERNAL_STORAGE）。
    /// - Android 9 及以下：写入应用的外部私有目录（同样无需权限；
    ///   在那些系统版本上该目录可被文件管理器直接浏览）。
    private fun saveToDownloads(
        filename: String,
        content: String,
        mime: String = "text/plain"
    ): String? = saveToDownloads(filename, mime) {
        it.write(content.toByteArray(Charsets.UTF_8))
    }

    /// 二进制版本（音频 WAV 导出用）。
    ///
    /// 为什么必须单独一条：文本导出把内容按 UTF-8 写，WAV 是二进制 ——
    /// 用同一条通道会把文件写坏（而且「坏了但看着成功」最难查）。
    ///
    /// 路径与文本版**共用同一个 helper**：导出目的地只有一处定义，
    /// 免得出现「文本进 Downloads、音频进别处」这种不一致。
    private fun saveBytesToDownloads(
        filename: String,
        bytes: ByteArray,
        mime: String = "audio/wav"
    ): String? = saveToDownloads(filename, mime) { it.write(bytes) }

    /// 写入「下载」目录的公共实现：插入 MediaStore 条目（或落到应用外部目录）
    /// → 交给 [write] 写内容 → 把文件名改成我们要求的那个。
    ///
    /// 返回**用户可见的路径**（File 管理器里看到的那种）。
    private fun saveToDownloads(
        filename: String,
        mime: String,
        write: (java.io.OutputStream) -> Unit
    ): String? {
        // 文件名来自 Dart，做一次净化，避免路径穿越
        val safe = filename.replace('/', '_').replace('\\', '_')
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val values = ContentValues().apply {
                    put(MediaStore.MediaColumns.DISPLAY_NAME, safe)
                    put(MediaStore.MediaColumns.MIME_TYPE, mime)
                }
                val resolver = contentResolver
                // 音频 WAV 属于音乐/音频类型：放进 Downloads 的 Audio 子目录更整齐，
                // 也让系统文件管理器的分类视图能直接找到（导出后要能一眼找到，
                // 才能拿它去给 Direwolf / 电台解）。
                val isAudio = safe.lowercase().endsWith(".wav")
                values.put(
                    MediaStore.MediaColumns.RELATIVE_PATH,
                    if (isAudio) {
                        Environment.DIRECTORY_DOWNLOADS + "/APRSlocusAudio"
                    } else {
                        Environment.DIRECTORY_DOWNLOADS
                    }
                )
                val uri = resolver.insert(
                    MediaStore.Downloads.EXTERNAL_CONTENT_URI, values
                ) ?: return null
                resolver.openOutputStream(uri)?.use { out ->
                    write(out)
                    out.flush()
                } ?: return null
                // 部分实现会根据 MIME 给文件名**追加后缀**（text/plain → .txt、
                // 音频 → .wav/.mp3），使 APRSlocus_….adi 变成 APRSlocus_….adi.txt。
                // 这里读回实际名字，不一致就改回原名。
                val actual = displayNameOf(uri)
                if (actual != null && actual != safe) {
                    try {
                        resolver.update(
                            uri,
                            ContentValues().apply {
                                put(MediaStore.MediaColumns.DISPLAY_NAME, safe)
                            },
                            null,
                            null
                        )
                    } catch (_: Exception) {
                        // 改不回去也不影响导出成功（内容已写入）
                    }
                }
                // 报告**真实路径**：音频在 Download/APRSlocusAudio/ 下，
                // 之前一律回 "Download/$safe" 会让用户去错的目录里找。
                if (isAudio) {
                    "Download/APRSlocusAudio/$safe"
                } else {
                    "Download/$safe"
                }
            } else {
                val dir = getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS) ?: filesDir
                val f = File(dir, safe)
                f.outputStream().use { write(it) }
                f.absolutePath
            }
        } catch (_: Exception) {
            null
        }
    }

    /// 查询 MediaStore 条目的实际显示名
    private fun displayNameOf(uri: Uri): String? = try {
        contentResolver.query(
            uri,
            arrayOf(MediaStore.MediaColumns.DISPLAY_NAME),
            null,
            null,
            null
        )?.use { c -> if (c.moveToFirst()) c.getString(0) else null }
    } catch (_: Exception) {
        null
    }

    /// 系统分享面板：分享文本到其他 App（微信 / QQ / 短信等）
    private fun shareText(text: String) {
        try {
            val send = Intent(Intent.ACTION_SEND).apply {
                type = "text/plain"
                putExtra(Intent.EXTRA_TEXT, text)
            }
            startActivity(Intent.createChooser(send, "分享 APRSlocus"))
        } catch (_: Exception) {
            // 无可用分享目标时静默失败
        }
    }

    override fun onPostResume() {
        super.onPostResume()
        // 权限请求统一由 Dart 侧按业务时机触发（OOBE 完成后 / 用户主动开启定位），
        // 避免首次启动向导期间系统权限弹窗突兀打断。
        // 这里仅兜底：如果 Dart 尚未请求但用户已回到前台且已有权限，就绪无需操作。
    }

    private fun requestPermissionsNow() {
        val perms = mutableListOf<String>()
        if (checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
            perms.add(Manifest.permission.ACCESS_FINE_LOCATION)
        }
        if (Build.VERSION.SDK_INT >= 33) {
            if (checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                perms.add(Manifest.permission.POST_NOTIFICATIONS)
            }
        }
        if (perms.isNotEmpty()) {
            ActivityCompat.requestPermissions(this, perms.toTypedArray(), 100)
        } else if (permCompleter != null) {
            permCompleter?.success(true)
            permCompleter = null
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        // 蓝牙/录音权限请求走各自的 requestCode，勿与定位权限混淆
        tnc?.onRequestPermissionsResult(requestCode, grantResults)
        pkwdwpl?.onRequestPermissionsResult(requestCode, grantResults)
        audio?.onRequestPermissionsResult(requestCode, grantResults)
        if (requestCode != 100) return
        val ok = hasPermissions()
        permCompleter?.success(ok)
        permCompleter = null
        // 授权成功后自动启动定位服务
        if (ok) {
            startLocationService()
        }
    }

    private fun hasPermissions(): Boolean {
        val fine = checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
        val coarse = checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
        return fine || coarse
    }

    private fun startLocationService(mode: String = LocationService.MODE_GPS_NETWORK) {
        val intent = Intent(this, LocationService::class.java).apply {
            putExtra(LocationService.EXTRA_MODE, mode)
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
        } catch (_: Exception) {
            // 前台服务启动受限时静默失败，Dart 侧重试
        }
    }

    private fun stopLocationService() {
        stopService(Intent(this, LocationService::class.java))
    }

    /// 蓝牙是否在用 → 同步给前台服务（决定要不要声明 connectedDevice 类型）。
    ///
    /// 与音频的 setAudioCaptureActive 对应：Android 14（API 34）起，前台服务中
    /// 访问蓝牙设备必须声明 connectedDevice 类型，否则系统会限制蓝牙访问 ——
    /// 症状正是「能发不能收」或「退到后台就收不到」。当初只修了音频，漏了蓝牙。
    private fun setBtActive(active: Boolean) {
        try {
            LocationService.setBtActiveStatic(active)
            if (active) {
                // 服务可能尚未启动（纯 TNC 模式、未开定位）：确保前台服务存在，
                // 否则后台蓝牙读取没有前台服务兜底会被冻结。
                startLocationService()
            }
        } catch (_: Exception) {
        }
    }

    private fun updateServiceNotification(text: String) {
        LocationService.updateNotificationStatic(text)
    }

    /// 音频采集会把麦克风带进前台服务：Android 14+ 必须让服务声明 microphone
    /// 类型，否则切到后台后系统直接掐断录音（表现为「后台收不到报文」）。
    /// 这里跟随音频 EventChannel 的监听状态切换 —— 有监听者就意味着音频链路在使用。
    private fun setAudioCaptureActive(active: Boolean) {
        try {
            LocationService.setAudioActiveStatic(active)
            if (active) {
                // 服务可能尚未启动（纯音频模式、未开定位）：确保前台服务存在，
                // 否则后台采集没有前台服务兜底会被冻结。
                startLocationService()
            }
        } catch (_: Exception) {
        }
    }

    private fun openInstallSettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val intent = Intent(
                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                Uri.parse("package:$packageName")
            )
            try {
                startActivity(intent)
            } catch (_: Exception) {
                startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES))
            }
        }
    }

    private fun canRequestPackageInstalls(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            packageManager.canRequestPackageInstalls()
        } else true
    }

    private fun installApk(path: String): Boolean {
        return try {
            val file = File(path)
            if (!file.exists()) {
                return false
            }
            val uri: Uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                FileProvider.getUriForFile(this, "$packageName.fileprovider", file)
            } else {
                Uri.fromFile(file)
            }
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }

    override fun onDestroy() {
        // USB 串口的读线程与连接句柄要显式释放：
        //   * 不释放时 reader 线程会一直挂在长超时的 bulkTransfer 上；
        //   * 连接句柄不关，界面里选了一根线、退出应用后那根线仍显示占用。
        try {
            usbSerial?.detach()
        } catch (_: Exception) {
        }
        usbSerial = null
        try {
            tnc?.dispose()
        } catch (_: Exception) {
        }
        tnc = null
        try {
            pkwdwpl?.dispose()
        } catch (_: Exception) {
        }
        pkwdwpl = null
        // 传感器监听必须显式注销：否则 Activity 销毁后传感器仍在唤醒
        try {
            motion?.stop()
        } catch (_: Exception) {
        }
        motion = null
        try {
            audio?.dispose()
        } catch (_: Exception) {
        }
        audio = null
        // 撤销蓝牙/音频的前台服务类型声明：Activity 销毁后不该再声称在用这些设备，
        // 否则服务会带着 connectedDevice/microphone 类型继续跑（系统可能因此在
        // 下次启动时要求额外权限，也浪费电）。
        setBtActive(false)
        try {
            LocationService.setAudioActiveStatic(false)
        } catch (_: Exception) {
        }
        LocationBus.sink = null
        super.onDestroy()
    }
}
