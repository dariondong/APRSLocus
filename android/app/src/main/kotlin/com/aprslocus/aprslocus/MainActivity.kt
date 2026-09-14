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
import java.io.File

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.aprslocus/location"
    private val EVENT_CHANNEL = "com.aprslocus/location_events"
    private var permCompleter: MethodChannel.Result? = null

    // 蓝牙 TNC（经典蓝牙 SPP）：只搬字节，KISS/AX.25 在 Dart 侧
    private var tnc: TncManager? = null

    // 声卡 TNC（AFSK 1200）：同样只搬 PCM 采样，调制解调在 Dart 侧
    private var audio: AudioManager? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

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

        // 蓝牙 TNC 通道：列出已配对设备 / 连接 / 收发字节
        val tncManager = TncManager(this)
        tnc = tncManager
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TncManager.METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isSupported" -> result.success(tncManager.isSupported())
                    "listBondedDevices" -> {
                        try {
                            result.success(tncManager.listBondedDevices())
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
                                tncManager.connect(address)
                                result.success(true)
                            } catch (e: Exception) {
                                result.error("BT_CONNECT_FAILED", e.message ?: "连接失败", null)
                            }
                        }
                    }
                    "disconnect" -> {
                        try {
                            tncManager.disconnect()
                        } catch (_: Exception) {
                        }
                        result.success(true)
                    }
                    "send" -> {
                        val data = call.argument<ByteArray>("data")
                        if (data == null) {
                            result.error("NO_DATA", "缺少数据", null)
                        } else {
                            try {
                                tncManager.send(data)
                                result.success(true)
                            } catch (e: Exception) {
                                result.error("BT_SEND_FAILED", e.message ?: "发送失败", null)
                            }
                        }
                    }
                    "requestPermissions" -> tncManager.requestPermissions(result)
                    else -> result.notImplemented()
                }
            }
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, TncManager.EVENT_CHANNEL)
            .setStreamHandler(
                object : EventChannel.StreamHandler {
                    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                        tncManager.setEventSink(events)
                    }

                    override fun onCancel(arguments: Any?) {
                        tncManager.setEventSink(null)
                    }
                }
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

        // 导出通道：把文本文件写入「下载」目录（供 ADIF 导出使用）
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.aprslocus/export").setMethodCallHandler { call, result ->
            when (call.method) {
                "saveToDownloads" -> {
                    val filename = call.argument<String>("filename") ?: "export.adi"
                    val content = call.argument<String>("content") ?: ""
                    val path = saveToDownloads(filename, content)
                    if (path == null) {
                        result.error("SAVE_FAILED", "保存失败", null)
                    } else {
                        result.success(path)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    /// 把文本写入「下载」目录，返回用户可见的路径；失败返回 null。
    ///
    /// - Android 10（API 29）及以上：走 MediaStore，**无需任何存储权限**
    ///   （应用向 Downloads 集合插入自己的内容不需要 WRITE_EXTERNAL_STORAGE）。
    /// - Android 9 及以下：写入应用的外部私有目录（同样无需权限；
    ///   在那些系统版本上该目录可被文件管理器直接浏览）。
    private fun saveToDownloads(filename: String, content: String): String? {
        // 文件名来自 Dart，做一次净化，避免路径穿越
        val safe = filename.replace('/', '_').replace('\\', '_')
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val values = ContentValues().apply {
                    put(MediaStore.MediaColumns.DISPLAY_NAME, safe)
                    put(MediaStore.MediaColumns.MIME_TYPE, "text/plain")
                    put(
                        MediaStore.MediaColumns.RELATIVE_PATH,
                        Environment.DIRECTORY_DOWNLOADS
                    )
                }
                val resolver = contentResolver
                // 音频 WAV 属于音乐/音频类型：放进 Downloads 的 Audio 子目录更整齐，
                // 也让系统文件管理器的分类视图能直接找到。
                val isAudio = safe.lowercase().endsWith(".wav")
                if (isAudio) {
                    values.put(
                        MediaStore.MediaColumns.RELATIVE_PATH,
                        Environment.DIRECTORY_DOWNLOADS + "/APRSlocusAudio"
                    )
                }
                val uri = resolver.insert(
                    MediaStore.Downloads.EXTERNAL_CONTENT_URI, values
                ) ?: return null
                resolver.openOutputStream(uri)?.use { out ->
                    out.write(content.toByteArray(Charsets.UTF_8))
                    out.flush()
                } ?: return null
                // 部分实现会根据 MIME（text/plain）给文件名**追加 .txt**，
                // 使 APRSlocus_….adi 变成 APRSlocus_….adi.txt。
                // 这里读回实际名字，不一致就改回原名（.adi 是 ADIF 的惯用扩展名）。
                val actual = displayNameOf(uri)
                // 媒体类型下部分系统会给音频文件补 .wav/.mp3 之类的后缀，
                // 与文本同理：写回原名，保证与自检/日志里报告的路径一致。
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
                "Download/$safe"
            } else {
                val dir = getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS) ?: filesDir
                val f = File(dir, safe)
                f.writeText(content, Charsets.UTF_8)
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
        try {
            tnc?.dispose()
        } catch (_: Exception) {
        }
        tnc = null
        try {
            audio?.dispose()
        } catch (_: Exception) {
        }
        audio = null
        LocationBus.sink = null
        super.onDestroy()
    }
}
