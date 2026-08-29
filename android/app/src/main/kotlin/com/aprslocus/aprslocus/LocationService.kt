package com.aprslocus.aprslocus

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import io.flutter.plugin.common.EventChannel

/// 服务 → Flutter 事件通道的直连中转（同进程单例，不依赖广播）
object LocationBus {
    var sink: EventChannel.EventSink? = null
    fun emit(map: Map<String, Any?>) {
        sink?.success(map)
    }
}

/// 通知工具：消息通知 + 前台服务通知
object NotifHelper {
    const val MSG_CHANNEL_ID = "aprslocus_messages"
    const val MSG_NOTIF_BASE = 2000

    fun ensureMsgChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (nm.getNotificationChannel(MSG_CHANNEL_ID) == null) {
                val ch = NotificationChannel(
                    MSG_CHANNEL_ID, "APRS 消息", NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "收到 APRS 消息时提醒"
                    enableVibration(true)
                }
                nm.createNotificationChannel(ch)
            }
        }
    }

    /// 收到 APRS 消息时弹通知，点击打开应用
    fun showMessage(context: Context, from: String, text: String) {
        ensureMsgChannel(context)
        val pi = PendingIntent.getActivity(
            context, from.hashCode() and 0xff,
            Intent(context, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val notif = NotificationCompat.Builder(context, MSG_CHANNEL_ID)
            .setContentTitle("📻 $from")
            .setContentText(text)
            .setStyle(NotificationCompat.BigTextStyle().bigText(text))
            .setSmallIcon(android.R.drawable.ic_dialog_email)
            .setContentIntent(pi)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .build()
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(MSG_NOTIF_BASE + (from.hashCode() and 0xffff), notif)
    }
}

/**
 * 前台定位服务 —— 使用 Android 原生 LocationManager，
 * 不依赖 Google Play Services（国内手机无 GMS 也能用）。
 */
class LocationService : Service() {
    companion object {
        const val CHANNEL_ID = "aprslocus_channel"
        const val NOTIFICATION_ID = 1001
        const val ACTION_TOGGLE_CONNECT = "com.aprslocus.action.TOGGLE_CONNECT"
        const val ACTION_EXIT = "com.aprslocus.action.EXIT"
        private var instance: LocationService? = null

        /// 更新前台服务通知（同进程直连，MainActivity 调用）
        fun updateNotificationStatic(text: String) {
            instance?.updateNotification(text)
        }
    }

    private var locationManager: LocationManager? = null
    private var locationListener: LocationListener? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private val lastKnownPoll = Handler(Looper.getMainLooper())
    private val lastKnownRunnable = object : Runnable {
        override fun run() {
            reportLastKnown()
            lastKnownPoll.postDelayed(this, 10000L)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        instance = this
        createNotificationChannel()
        locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // 通知栏退出按钮：停止服务并退出应用
        if (intent?.action == ACTION_EXIT) {
            LocationBus.emit(mapOf("type" to "exit"))
            stopSelf()
            // 退出应用：关闭 activity 和进程
            val launchIntent = Intent(Intent.ACTION_MAIN).apply {
                addCategory(Intent.CATEGORY_HOME)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
            }
            startActivity(launchIntent)
            android.os.Process.killProcess(android.os.Process.myPid())
            return START_STICKY
        }
        // 通知栏按钮：切换连接/断开
        if (intent?.action == ACTION_TOGGLE_CONNECT) {
            LocationBus.emit(mapOf("type" to "toggleConnect"))
            return START_STICKY
        }
        val notification = buildNotification("APRSlocus 运行中")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        // 持锁防止 Doze 冻结 Dart 隔离区（保证保活/重连定时器运行）
        try {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "aprslocus:loc").apply {
                setReferenceCounted(false)
                acquire()
            }
        } catch (_: Exception) {}
        // 通知 Flutter 链路已通（证明服务活着）
        LocationBus.emit(mapOf("status" to "定位服务已启动，等待定位…"))
        startLocationUpdates()
        // 定期用"最后已知位置"兜底，网络定位可用时也能出位置
        lastKnownPoll.postDelayed(lastKnownRunnable, 10000L)
        return START_STICKY
    }

    override fun onDestroy() {
        instance = null
        stopLocationUpdates()
        lastKnownPoll.removeCallbacks(lastKnownRunnable)
        try {
            wakeLock?.let { if (it.isHeld) it.release() }
        } catch (_: Exception) {}
        wakeLock = null
        super.onDestroy()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "APRSlocus 定位服务",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "保持后台定位和 APRS 连接"
                setShowBadge(false)
            }
            val nm = getSystemService(NotificationManager::class.java)
            nm.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(text: String): Notification {
        val pendingIntent = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        // 连接/断开按钮
        val toggleIntent = Intent(this, LocationService::class.java).apply {
            action = ACTION_TOGGLE_CONNECT
        }
        val togglePi = PendingIntent.getService(
            this, 1, toggleIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val toggleAction = NotificationCompat.Action.Builder(
            android.R.drawable.ic_media_play,
            "连接/断开",
            togglePi
        ).build()
        // 退出按钮
        val exitIntent = Intent(this, LocationService::class.java).apply {
            action = ACTION_EXIT
        }
        val exitPi = PendingIntent.getService(
            this, 2, exitIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val exitAction = NotificationCompat.Action.Builder(
            android.R.drawable.ic_menu_close_clear_cancel,
            "退出",
            exitPi
        ).build()
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("APRSlocus")
            .setContentText(text)
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setSilent(true)
            .addAction(toggleAction)
            .addAction(exitAction)
            .build()
    }

    fun updateNotification(text: String) {
        val nm = getSystemService(NotificationManager::class.java)
        nm.notify(NOTIFICATION_ID, buildNotification(text))
    }

    @Suppress("MissingPermission")
    private fun startLocationUpdates() {
        val lm = locationManager ?: return
        // 先报告定位服务是否可用
        val gpsOn = try { lm.isProviderEnabled(LocationManager.GPS_PROVIDER) } catch (_: Exception) { false }
        val netOn = try { lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER) } catch (_: Exception) { false }
        if (!gpsOn && !netOn) {
            LocationBus.emit(mapOf("status" to "定位服务未开启，请在系统设置中开启定位"))
        } else if (!gpsOn) {
            LocationBus.emit(mapOf("status" to "GPS 未开启，使用网络定位"))
        }
        // 先用上次已知位置快速出图
        reportLastKnown()

        val listener = object : LocationListener {
            override fun onLocationChanged(location: Location) {
                broadcastLocation(location)
            }
            override fun onProviderEnabled(provider: String) {
                LocationBus.emit(mapOf("status" to "$provider 定位已开启"))
            }
            override fun onProviderDisabled(provider: String) {
                LocationBus.emit(mapOf("status" to "$provider 定位已关闭"))
            }
            @Deprecated("Deprecated in Java")
            override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
        }
        locationListener = listener
        // GPS 高精度 + 网络辅助，两者都可触发
        var gpsRequested = false
        try {
            lm.requestLocationUpdates(
                LocationManager.GPS_PROVIDER, 10000L, 5f, listener, Looper.getMainLooper())
            gpsRequested = true
        } catch (_: Exception) {}
        try {
            lm.requestLocationUpdates(
                LocationManager.NETWORK_PROVIDER, 10000L, 5f, listener, Looper.getMainLooper())
        } catch (_: Exception) {}
        if (!gpsRequested) {
            LocationBus.emit(mapOf("status" to "GPS 监听注册失败，请检查定位权限"))
        }
    }

    @Suppress("MissingPermission")
    private fun reportLastKnown() {
        val lm = locationManager ?: return
        try {
            val gps = lm.getLastKnownLocation(LocationManager.GPS_PROVIDER)
            if (gps != null && gps.latitude != 0.0 && gps.longitude != 0.0) { broadcastLocation(gps); return }
        } catch (_: Exception) {}
        try {
            val net = lm.getLastKnownLocation(LocationManager.NETWORK_PROVIDER)
            if (net != null && net.latitude != 0.0 && net.longitude != 0.0) broadcastLocation(net)
        } catch (_: Exception) {}
    }

    private fun broadcastLocation(location: Location) {
        LocationBus.emit(mapOf(
            "lat" to location.latitude,
            "lng" to location.longitude,
            "alt" to location.altitude,
            "speed" to location.speed,      // m/s
            "bearing" to location.bearing,  // 度
            "status" to "GPS 定位中"))
    }

    private fun stopLocationUpdates() {
        locationListener?.let { listener ->
            try { locationManager?.removeUpdates(listener) } catch (_: Exception) {}
        }
        locationListener = null
    }
}
