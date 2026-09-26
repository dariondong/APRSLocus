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
        const val EXTRA_MODE = "location_mode"
        const val MODE_GPS = "gps"
        const val MODE_GPS_NETWORK = "gps_network"
        /**
         * 纯网络：只用基站 / Wi-Fi 粗定位，**不注册 GPS**。
         * 给「没有 GPS 的设备」用，也用于极端省电；粗点在 Dart 侧按 coarse 处理
         * （不写轨迹、默认不自动上报）。
         */
        const val MODE_NETWORK = "network"
        /**
         * 仅保活：不采集任何定位（用户在「模拟位置」模式下使用），
         * 但保留前台服务 + WakeLock，使 APRS-IS 连接与信标定时器能在后台存活。
         */
        const val MODE_KEEPALIVE = "keepalive"
        /** 是否处于仅保活模式（不启动任何 provider 监听） */
        val keepAliveOnly: Boolean get() = mode == MODE_KEEPALIVE
        /** 定位模式：gps = 纯 GPS；gps_network = GPS + 网络辅助；network = 纯网络 */
        @Volatile var mode: String = "gps_network"
        /** 接受定位的精度上限（米）。超过则丢弃，避免基站/Wi-Fi 粗点引起漂移 */
        const val MAX_ACCURACY_M = 150f
        /** 网络定位仅在 GPS 停更超过该时长时作为兜底（毫秒） */
        const val NET_FALLBACK_GAP_MS = 20000L
        /** 「上次已知位置」的最大年龄（毫秒）。超过它的缓存点比没有更糟：
         *  会把标记与轨迹拉到一个早已离开的地方。 */
        const val LAST_KNOWN_MAX_AGE_MS = 5 * 60 * 1000L
        private var instance: LocationService? = null

        /**
         * 音频（声卡 TNC）是否在采集。
         *
         * Android 14（API 34）起，应用在前台服务中访问麦克风时该服务必须声明
         * microphone 类型，否则系统会**掐断麦克风**（表现：切到后台就再也收不到
         * 报文）。因此音频采集开关变化时要用新的类型重新 startForeground。
         */
        @Volatile private var audioActive = false

        fun setAudioActiveStatic(active: Boolean) {
            if (audioActive == active) return
            audioActive = active
            instance?.refreshForegroundType()
        }

        /**
         * 蓝牙 SPP（TNC / PKWDWPL）是否在使用。
         *
         * 与音频同一个坑，但当初只修了音频：Android 14（API 34）起，应用在前台
         * 服务中访问**蓝牙设备**时该服务必须声明 connectedDevice 类型，否则系统
         * 会限制蓝牙访问（表现：退到后台就收不到报文，或只能发不能收）。
         * 因此 TNC / PKWDWPL 连接状态变化时要用新的类型重新 startForeground。
         *
         * 注意 connectedDevice 是 API 34 才引入的类型，只有 34+ 才声明。
         */
        @Volatile private var btActive = false

        fun setBtActiveStatic(active: Boolean) {
            if (btActive == active) return
            btActive = active
            instance?.refreshForegroundType()
        }

        /// 更新前台服务通知（同进程直连，MainActivity 调用）
        fun updateNotificationStatic(text: String) {
            instance?.updateNotification(text)
        }

        /// 动态切换定位模式（服务运行中立即生效：重建 provider 监听）
        fun setModeStatic(newMode: String) {
            if (mode == newMode) return
            mode = newMode
            instance?.let {
                if (newMode == MODE_KEEPALIVE) {
                    // 切到仅保活：注销 provider 监听并停掉兜底轮询
                    // （前台服务与 WakeLock 保留，供 APRS 连接保活）
                    it.stopLocationUpdates()
                    it.lastKnownPoll.removeCallbacks(it.lastKnownRunnable)
                } else {
                    it.restartLocationUpdates()
                }
            }
        }
    }

    /// 最近一次通知文本：刷新前台服务类型时要复用同一通知（不能凭空造一条）
    private var lastNotificationText = "APRSlocus 运行中"
    private var locationManager: LocationManager? = null
    private var locationListener: LocationListener? = null
    private var wakeLock: PowerManager.WakeLock? = null
    /** 最近一次优质 GPS fix 时间戳（用于网络定位兜底判断） */
    private var lastGpsFixMs: Long = 0L
    /** 本次运行是否已收到过**实时**定位（收到后，缓存位置不再上报，见 considerLocation） */
    private var hasLiveFix = false
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
        // 读取定位模式（Flutter 启动服务时传入）
        intent?.getStringExtra(EXTRA_MODE)?.let {
            if (it == MODE_GPS || it == MODE_GPS_NETWORK || it == MODE_NETWORK || it == MODE_KEEPALIVE) mode = it
        }
        val notification = buildNotification("APRSlocus 运行中")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // 把当前已激活的能力一并声明：服务可能在蓝牙/音频已经在用之后才启动，
            // 只声明 location 会让系统立刻限制蓝牙/麦克风访问。
            var t = ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION
            if (audioActive) t = t or ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
            // connectedDevice 是 API 34 才引入的类型：旧系统不认识这个位，
            // 不能无条件传（有些 ROM 会直接抛异常导致服务起不来）。
            if (btActive && Build.VERSION.SDK_INT >= 34) {
                t = t or ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE
            }
            startForeground(NOTIFICATION_ID, notification, t)
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
        LocationBus.emit(
            mapOf(
                "status" to if (keepAliveOnly) "模拟位置 · 后台保活已启动"
                else "定位服务已启动，等待定位…"
            )
        )
        if (keepAliveOnly) {
            // 仅保活：不注册任何 provider 监听（无谓耗电），也不启动
            // "最后已知位置"轮询——位置完全由 Dart 侧的模拟坐标决定。
            stopLocationUpdates()
            lastKnownPoll.removeCallbacks(lastKnownRunnable)
        } else {
            startLocationUpdates()
            // 定期用"最后已知位置"兜底，网络定位可用时也能出位置
            lastKnownPoll.postDelayed(lastKnownRunnable, 10000L)
        }
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

    /**
     * 按当前是否需要麦克风重新声明前台服务类型。
     *
     * 单纯在清单里写 `location|microphone` 是不够的：startForeground 时若声明了
     * microphone 类型，系统会要求此刻确实持有麦克风权限；反过来，只声明 location
     * 时后台录音会被拦截。所以按实际状态切换。
     */
    private fun refreshForegroundType() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return
        try {
            var type = ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION
            if (audioActive) type = type or ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
            // 同上：connectedDevice 仅 API 34+ 声明
            if (btActive && Build.VERSION.SDK_INT >= 34) {
                type = type or ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE
            }
            startForeground(NOTIFICATION_ID, buildNotification(lastNotificationText), type)
        } catch (_: Exception) {
            // 个别 ROM 不允许运行中重复声明类型；失败时保持原类型即可 ——
            // 前台服务与 APRS 连接不受影响，最坏情况是后台录音被系统限制。
        }
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
        // 记下来：刷新前台服务类型（音频采集开关）时要用同一份文本重新 startForeground
        lastNotificationText = text
        val nm = getSystemService(NotificationManager::class.java)
        nm.notify(NOTIFICATION_ID, buildNotification(text))
    }

    /// 按当前模式重建 provider 监听（模式切换时调用）
    private fun restartLocationUpdates() {
        stopLocationUpdates()
        startLocationUpdates()
        reportLastKnown()
    }

    @Suppress("MissingPermission")
    private fun startLocationUpdates() {
        val lm = locationManager ?: return
        val useNetwork = mode == MODE_GPS_NETWORK || mode == MODE_NETWORK
        val useGps = mode != MODE_NETWORK
        // 先报告定位服务是否可用
        val gpsOn = try { lm.isProviderEnabled(LocationManager.GPS_PROVIDER) } catch (_: Exception) { false }
        val netOn = try { lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER) } catch (_: Exception) { false }
        if (useGps && !gpsOn && !(useNetwork && netOn)) {
            LocationBus.emit(mapOf("status" to (if (useNetwork) "定位服务未开启，请在系统设置中开启定位" else "GPS 未开启，请开启系统定位")))
        } else if (useGps && !gpsOn) {
            LocationBus.emit(mapOf("status" to "GPS 未开启，使用网络定位"))
        } else if (!useGps && !netOn) {
            // 纯网络模式：GPS 开关与它无关，只看网络定位是否可用
            LocationBus.emit(mapOf("status" to "网络定位未开启，请在系统设置中开启定位"))
        }
        // 先用上次已知位置快速出图
        reportLastKnown()

        val listener = object : LocationListener {
            override fun onLocationChanged(location: Location) {
                considerLocation(location)
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
        // GPS 高精度（gps / gps_network 注册；纯网络模式不注册 GPS）
        var gpsRequested = false
        if (useGps) {
            try {
                // minTime 10s → 1s（用户反馈「实时轨迹采样率低」）：
                // 10s 是「省电优先」的取值，代价是轨迹每 10 秒才一个点 —— 骑车/开车时
                // 一个拐弯正好落在两个点之间，画出来就是一条切角的斜线。
                // 1s 是导航类应用的常规取样率；下方 minDistance 仍是 5m，静止时 GPS 不给
                // 回调，所以待机功耗并不跟着涨。
                lm.requestLocationUpdates(
                    LocationManager.GPS_PROVIDER, 1000L, 5f, listener, Looper.getMainLooper())
                gpsRequested = true
            } catch (_: Exception) {}
        }
        // GPS + 网络 / 纯网络模式：额外注册网络定位。
        //
        // 网络定位**保持 10s**：gps_network 下它只做 GPS 停更时的兜底
        // （见 considerLocation），按 1s 轮询基站/Wi-Fi 毫无收益；
        // 纯网络模式下基站/Wi-Fi 本身也不会更频繁地更新。
        if (useNetwork) {
            try {
                lm.requestLocationUpdates(
                    LocationManager.NETWORK_PROVIDER, 10000L, 5f, listener, Looper.getMainLooper())
            } catch (_: Exception) {}
        }
        if (useGps && !gpsRequested) {
            LocationBus.emit(mapOf("status" to "GPS 监听注册失败，请检查定位权限"))
        }
    }

    /** 定位决策：GPS 优先，网络仅在 GPS 长时间停更时兜底；
     *  精度超过阈值（基站/Wi-Fi 粗点）一律丢弃，抑制漂移。 */
    private fun considerLocation(location: Location, fromLastKnown: Boolean = false) {
        val acc = try { location.accuracy } catch (_: Exception) { Float.MAX_VALUE }
        val isGps = location.provider == LocationManager.GPS_PROVIDER
        val now = System.currentTimeMillis()

        // 0) 缓存位置（getLastKnownLocation）：**只在还没有实时定位时**用于「快速出图」。
        //
        //    ── 这是「轨迹横跳：回到起点再画一次、反复横画」的根因 ──
        //    外面有个 10 秒轮询（lastKnownRunnable）会调用 reportLastKnown()，而它把
        //    getLastKnownLocation() 的结果送进本函数 —— 于是那个**可能几小时前、甚至
        //    在另一个城市**的缓存点，被当成一次正常定位上报给上层；上层按距离判断
        //    「移动了」就把它写进轨迹，下一拍真实定位又写一次 → 线在旧点与新点之间来回。
        //    收到实时定位之后，缓存点纯属噪声，必须一律丢掉。
        if (fromLastKnown) {
            if (hasLiveFix) return
            if (location.time > 0 && now - location.time > LAST_KNOWN_MAX_AGE_MS) return
        }

        // 1) 精度超限：直接丢弃（粗点比不准还伤——会拖走标记）
        if (!acc.isNaN() && acc > MAX_ACCURACY_M) return

        // 2) 网络定位点
        if (!isGps) {
            if (mode == MODE_NETWORK) {
                // 纯网络：网络点就是唯一来源，不需要「等 GPS 停更」。
                // 精度闸仍由上面的 MAX_ACCURACY_M 把关；发到 Dart 侧后按 coarse
                // 处理（不写轨迹、默认不自动上报）。
            } else {
                // GPS + 网络：仅当 GPS 长期无更新时才允许兜底，避免与 GPS 交替跳动
                if (mode != MODE_GPS_NETWORK) return
                if (lastGpsFixMs != 0L && now - lastGpsFixMs < NET_FALLBACK_GAP_MS) return
                // 网络兜底点精度门槛更严，避免明显劣化
                if (!acc.isNaN() && acc > 80f) return
            }
        }

        // 3) 通过：记录时间并上报
        //    注意 lastGpsFixMs 只由**实时**定位推进：缓存位置不是「GPS 刚更新过」，
        //    拿它去推进会把真正的网络兜底误压 20 秒（原实现就有这个连带 bug）。
        if (!fromLastKnown) {
            hasLiveFix = true
            if (isGps) lastGpsFixMs = now
        }
        val provider = location.provider
        val status = if (isGps) "GPS 定位中" else "网络定位中"
        LocationBus.emit(mapOf(
            "lat" to location.latitude,
            "lng" to location.longitude,
            "alt" to location.altitude,
            "speed" to location.speed,      // m/s
            "bearing" to location.bearing,  // 度
            "accuracy" to (if (acc.isNaN()) null else acc.toDouble()),
            "provider" to provider,
            // 让上层知道这只是「缓存位置、仅供快速出图」：可以更新标记，
            // 但**不能**写进轨迹（见 state.dart 的 _onFix）
            "lastKnown" to fromLastKnown,
            "status" to status))
    }

    @Suppress("MissingPermission")
    private fun reportLastKnown() {
        val lm = locationManager ?: return
        // 纯网络模式不看 GPS 缓存：GPS 根本没在跑，缓存可能是几小时前、甚至在别的城市
        if (mode != MODE_NETWORK) {
            try {
                val gps = lm.getLastKnownLocation(LocationManager.GPS_PROVIDER)
                if (gps != null && gps.latitude != 0.0 && gps.longitude != 0.0) {
                    considerLocation(gps, fromLastKnown = true); return
                }
            } catch (_: Exception) {}
        }
        // 纯 GPS 模式不查询网络位置
        if (mode == "gps") return
        try {
            val net = lm.getLastKnownLocation(LocationManager.NETWORK_PROVIDER)
            if (net != null && net.latitude != 0.0 && net.longitude != 0.0) {
                considerLocation(net, fromLastKnown = true)
            }
        } catch (_: Exception) {}
    }

    private fun stopLocationUpdates() {
        locationListener?.let { listener ->
            try { locationManager?.removeUpdates(listener) } catch (_: Exception) {}
        }
        locationListener = null
    }
}
