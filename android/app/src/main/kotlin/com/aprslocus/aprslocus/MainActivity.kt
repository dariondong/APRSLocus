package com.aprslocus.aprslocus

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
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
    private var _permRequested = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 方法通道：控制定位服务 + 权限
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startService" -> {
                    if (!hasPermissions()) {
                        result.error("NO_PERMISSION", "缺少定位权限", null)
                    } else {
                        startLocationService()
                        result.success(true)
                    }
                }
                "stopService" -> {
                    stopLocationService()
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
    }

    override fun onPostResume() {
        super.onPostResume()
        // Activity 恢复后才请求权限，时机可靠
        if (!_permRequested) {
            _permRequested = true
            requestPermissionsNow()
        }
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

    private fun startLocationService() {
        val intent = Intent(this, LocationService::class.java)
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
        LocationBus.sink = null
        super.onDestroy()
    }
}
