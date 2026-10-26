package com.aprslocus.aprslocus

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.location.GnssStatus
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

    /// 生命守护「强提醒」通道（issue #32）。
    ///
    /// 与常驻通知（`aprslocus_channel`，IMPORTANCE_LOW）**必须分开**：常驻通知的定位是
    /// 「安静地显示在状态栏」，系统不会为它震动、也不会弹横幅；而碰撞/摔倒与心率异常
    /// 是需要立刻看见的事 —— 用户把手机放在兜里时，只有一个 IMPORTANCE_HIGH、
    /// 带震动、走 ALARM 类别的通知才能真正把人叫醒。复用常驻通道等于「提醒不发声」，
    /// 那正是 issue #32 说的「强提醒」缺失。
    const val ALARM_CHANNEL_ID = "aprslocus_alarm"
    const val ALARM_NOTIF_ID = 1002

    fun ensureAlarmChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (nm.getNotificationChannel(ALARM_CHANNEL_ID) == null) {
                val ch = NotificationChannel(
                    ALARM_CHANNEL_ID, "生命守护强提醒", NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "碰撞 / 摔倒 / 心率异常时的强提醒（响铃 + 震动）"
                    enableVibration(true)
                    vibrationPattern = longArrayOf(0, 400, 200, 400, 200, 400)
                    // 锁屏上也显示内容：这是安全告警，不是隐私消息。
                    lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                }
                nm.createNotificationChannel(ch)
            }
        }
    }

    /// 生命守护强提醒（issue #32）：高优先级 + 震动 + 抬头横幅，点击打开应用。
    ///
    /// 与 [showMessage] 的区别是**打扰级别**：这个消息不该安静地躺在通知栏里。
    fun showAlarm(context: Context, title: String, text: String) {
        ensureAlarmChannel(context)
        val pi = PendingIntent.getActivity(
            context, 42,
            Intent(context, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val notif = NotificationCompat.Builder(context, ALARM_CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(text)
            .setStyle(NotificationCompat.BigTextStyle().bigText(text))
            .setSmallIcon(R.drawable.ic_stat_aprs)
            .setLargeIcon(notifLargeIcon(context))
            .setContentIntent(pi)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .setVibrate(longArrayOf(0, 400, 200, 400, 200, 400))
            .build()
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(ALARM_NOTIF_ID, notif)
    }

    /// 订阅命中通道。
    ///
    /// 与「APRS 消息」分开的理由与强提醒那条一样：两种提醒的**性质**不同。
    /// 消息是「有人对我说话了」，订阅是「我在盯的那件事发生了」—— 用户可能想
    /// 留着一头、静音另一头，共用一个通道就只能一刀切。
    const val SUBS_CHANNEL_ID = "aprslocus_subs"
    const val SUBS_NOTIF_BASE = 3000

    fun ensureSubsChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (nm.getNotificationChannel(SUBS_CHANNEL_ID) == null) {
                val ch = NotificationChannel(
                    SUBS_CHANNEL_ID, "订阅命中", NotificationManager.IMPORTANCE_DEFAULT
                ).apply {
                    description = "订阅规则命中时提醒"
                }
                nm.createNotificationChannel(ch)
            }
        }
    }

    /// 订阅命中：一条订阅固定占一个通知位（id 由订阅 id 派生）。
    ///
    /// 更新同一条而不是每条命中都新建，理由与常驻通知去重一样：同一个订阅占满
    /// 整屏通知栏只是吵，用户要的是「有新命中」这件事本身。
    fun showSubs(context: Context, title: String, text: String, id: String) {
        ensureSubsChannel(context)
        val pi = PendingIntent.getActivity(
            context, id.hashCode() and 0xff,
            Intent(context, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val notif = NotificationCompat.Builder(context, SUBS_CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(text)
            .setStyle(NotificationCompat.BigTextStyle().bigText(text))
            .setSmallIcon(R.drawable.ic_stat_aprs)
            .setLargeIcon(notifLargeIcon(context))
            .setContentIntent(pi)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .build()
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(SUBS_NOTIF_BASE + (id.hashCode() and 0xffff), notif)
    }

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
            .setSmallIcon(R.drawable.ic_stat_aprs)
            .setLargeIcon(notifLargeIcon(context))
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
        /** GPS 采样间隔（毫秒），由 Dart 侧随 startService 传入；0/缺省 = 用默认 1 秒 */
        const val EXTRA_INTERVAL = "intervalMs"
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

        /**
         * GPS 采样间隔（毫秒）。用户在设置页可以调（1/2/3/5/10/30 秒）。
         *
         * 原来写死 1000ms / 5m：1 秒是导航类应用的常规取样率，轨迹拐弯不被切角；
         * 嫌耗电的用户往大调，用同一套 provider 监听（minDistance 仍是 5m，
         * 所以静止时不会因为间隔小而白白亮 GPS）。
         */
        @Volatile var gpsIntervalMs: Long = 1000L

        /** 运行中调采样间隔：重建 provider 监听（服务没在跑就只记下来） */
        fun setSamplingStatic(ms: Int) {
            if (ms <= 0) return
            gpsIntervalMs = ms.toLong()
            instance?.restartLocationUpdates()
        }

        /** 接受定位的精度上限（米）。超过则丢弃，避免基站/Wi-Fi 粗点引起漂移 */
        const val MAX_ACCURACY_M = 150f
        /** 网络定位仅在 GPS 停更超过该时长时作为兜底（毫秒） */
        const val NET_FALLBACK_GAP_MS = 20000L
        /** 「上次已知位置」的最大年龄（毫秒）。超过它的缓存点比没有更糟：
         *  会把标记与轨迹拉到一个早已离开的地方。 */
        const val LAST_KNOWN_MAX_AGE_MS = 5 * 60 * 1000L
        /** GNSS 状态监听注册失败后的重试间隔（毫秒）。见 considerLocation。 */
        const val GNSS_RETRY_MS = 30000L
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

        /// 实时更新（Android 16 的 Live Updates）开关。
        ///
        /// 用户在设置里选，默认不开：提不提得上去还取决于系统设置与通知本身
        /// 的条件，不开就一直是今天这种普通常驻通知。
        @Volatile private var liveUpdates = false

        /// 提升过的通知在这台机器上被抹过：不再试提升（见 verifyStillPosted）。
        @Volatile private var promoBroken = false

        /// 给诊断用：这台机器是不是已经把提升关了。
        fun promoBrokenByRom(): Boolean = promoBroken

        fun setBtActiveStatic(active: Boolean) {
            if (btActive == active) return
            btActive = active
            instance?.refreshForegroundType()
        }

        /// 更新前台服务通知（同进程直连，MainActivity 调用）
        fun updateNotificationStatic(text: String, short: String = "", countdown: Long = 0) {
            instance?.updateNotification(text, short, countdown)
        }

        /// 实时更新（Android 16 的 Live Updates）开关：用户在设置里选的。
        /// 换开关时立刻重发一次通知，否则要等到下一次文字变化才生效。
        /// 给文件末尾的诊断函数读当前样式用（companion 里的私有字段外面看不见）。
        fun liveUpdatesOn(): Boolean = liveUpdates

        /// 前台服务现在在不在跑（诊断用：通知没了的第一个分岔点）。
        fun isRunning(): Boolean = instance != null

        /// 上次发通知的样子（诊断用；服务没在跑时没有可读的）。
        fun lastNotifReport(): List<String> = instance?.lastNotifLines()
            ?: listOf("上次刷新：没有（服务没在跑）")

        fun setLiveUpdatesStatic(on: Boolean) {
            if (liveUpdates == on) return
            liveUpdates = on
            // 用户重新打开时再给提升一次机会：上次可能是这台机器一时的状态。
            if (on) promoBroken = false
            instance?.let { it.republish() }
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

    /// 与 [lastNotificationText] 一起记：重发时要一模一样地重建，
    /// 只剩文字会把胶囊、倒计时弄丢。
    private var lastNotificationShort = ""
    private var lastCountdown = 0L

    /// 上一次发通知的结果。给诊断用：「更新很慢 / 不更新」到底是没发出，
    /// 还是发出去了但内容对，靠猜是分不出来的。
    @Volatile private var lastBuildOk = true
    @Volatile private var lastBuildError = ""
    @Volatile private var lastNotifyAt = 0L

    /// 给诊断拼的几行：上次发的是什么、成败、多久之前。
    fun lastNotifLines(): List<String> {
        val ago = if (lastNotifyAt == 0L) {
            "没有"
        } else {
            "${(System.currentTimeMillis() - lastNotifyAt) / 1000} 秒前"
        }
        return listOf(
            "上次刷新：$ago",
            "上次构建：" + if (lastBuildOk) "成功" else "失败（$lastBuildError）",
            "上次胶囊文字：" + (if (lastNotificationShort.isEmpty()) "（空）" else lastNotificationShort),
            "上次倒计时：${lastCountdown} 秒",
        )
    }
    private var locationManager: LocationManager? = null
    private var locationListener: LocationListener? = null
    private var wakeLock: PowerManager.WakeLock? = null
    /** 最近一次优质 GPS fix 时间戳（用于网络定位兜底判断） */
    private var lastGpsFixMs: Long = 0L
    /** 本次运行是否已收到过**实时**定位（收到后，缓存位置不再上报，见 considerLocation） */
    private var hasLiveFix = false

    /**
     * 最近一次 GNSS 状态里**参与定位**的卫星数（-1 = 还不知道）。
     *
     * 为什么要单独听 GNSS 状态、而不是只读 `Location.extras["satellites"]`：
     * 那个 extras 只有部分机型的 GPS provider 会填（很多机器上是空的），
     * 而 GnssStatus 是系统统一给的 —— 谁在上面、哪几颗真的参与了定轨都在里面。
     * 两者都试，谁有值用谁：extras 是**那颗星定出来的点**自带的，最准；
     * GNSS 状态是实时的，能补上 extras 缺失的机型。
     * 只用于「信标里带上卫星数」与界面显示 —— 不参与任何「这个点要不要」的判断。
     *
     * 为什么还要记一个 `gnssView`（在视颗数）：`usedInFix` 的位图**不是所有机型都填**
     * —— 部分华为 / 小米 ROM 与老基带的上层接口里它恒为 false，于是「参与定位数」
     * 永远是 0。这时在视颗数是唯一能拿到的数，而界面与信标要的正是「现在有几颗星」。
     */
    private var gnssUsed = -1
    private var gnssView = -1
    private var gnssCallback: GnssStatus.Callback? = null
    /** 上次尝试注册 GNSS 监听的时刻（注册失败要退避重试，见 considerLocation） */
    private var gnssAttemptMs = 0L
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
        // 看门狗从服务起来就开工：有服务就必须有通知。
        notifWatch.removeCallbacks(notifWatchRun)
        notifWatch.postDelayed(notifWatchRun, 10000L)
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
        intent?.getIntExtra(EXTRA_INTERVAL, 0)?.let {
            if (it > 0) gpsIntervalMs = it.toLong()
        }
        val notification = try {
            buildNotification("APRSlocus 运行中")
        } catch (_: Throwable) {
            // 兜底：建通知的任何一环出错（图标资源、提升请求、ROM 改过的
            // 方法）都不能让前台服务起不来 —— 通知没了就是服务没了。
            NotificationCompat.Builder(this, CHANNEL_ID)
                .setContentTitle("APRSlocus")
                .setContentText("APRSlocus 运行中")
                .setSmallIcon(R.drawable.ic_stat_aprs)
                .setOngoing(true)
                .build()
        }
        if (!declareForeground(notification)) {
            // 带提升的版本被系统挡下时，不能把它当成「定位权限被收回」：
            // 关掉提升再试一次，还不行才按权限处理。
            var ok = false
            if (currentPromoMode() != PROMO_PLAIN) {
                promoBroken = true
                val plain = try {
                    buildNotification("APRSlocus 运行中")
                } catch (_: Throwable) {
                    null
                }
                if (plain != null) ok = declareForeground(plain)
            }
            if (!ok) {
                // 权限被收回（用户在系统设置里把定位关掉）：带 location 类型的
                // 前台服务声明拿不到权限，服务无论如何也撑不起来。不崩溃、不装死：
                // 结束自己并把原因报给 Dart，由界面去提示「缺哪项权限」。
                LocationBus.emit(mapOf("status" to "定位权限已关闭，后台定位无法启动"))
                stopSelf()
                return START_NOT_STICKY
            }
        }
        // 持锁防止 Doze 冻结 Dart 隔离区（保证保活/重连定时器运行）
        // 提升版发出后也要回头确认一次（startForeground 这条路径与 notify 不同，
        // 但被抹掉的后果一样：前台服务没有通知就活不下去）。
        if (currentPromoMode() != PROMO_PLAIN) verifyStillPosted()
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
        notifWatch.removeCallbacks(notifWatchRun)
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
            startForeground(NOTIFICATION_ID,
                buildNotification(lastNotificationText, lastNotificationShort, lastCountdown), type)
        } catch (_: Exception) {
            // 个别 ROM 不允许运行中重复声明类型；失败时保持原类型即可 ——
            // 前台服务与 APRS 连接不受影响，最坏情况是后台录音被系统限制。
        }
    }

    /**
     * 声明前台服务：**失败不能把进程带走**。
     *
     * Android 9 及以上在这里要连「服务类型」一起声明；而带
     * `FOREGROUND_SERVICE_TYPE_LOCATION` 的声明要求定位权限**此刻还在手上**
     * （Android 14 起系统会真的来查）。用户在系统设置里把定位关掉之后，
     * 这个调用会抛 `SecurityException` —— 它在 `onStartCommand` 里没有人接，
     * 于是整个进程被系统干掉：用户看到的是「一打开应用就闪退」。
     *
     * 所以逐级退让：先按当前能力声明类型，失败再退回不带类型的旧写法
     * （旧写法在部分 ROM 上仍能起服务，只是拿不到后台定位/录音的豁免）。
     * 两级都失败才返回 false，由调用方停掉自己并如实上报。
     *
     * @return 服务是否已经进入前台
     */
    private fun declareForeground(notification: Notification): Boolean {
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
            try {
                startForeground(NOTIFICATION_ID, notification, t)
                return true
            } catch (_: Exception) {
                // 落到下面用不带类型的老写法再试一次
            }
        }
        return try {
            startForeground(NOTIFICATION_ID, notification)
            true
        } catch (_: Exception) {
            false
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

    private fun buildNotification(
        text: String,
        short: String = "",
        countdown: Long = 0
    ): Notification {
        // 提升姿势的判定本身也可能在这台机器上出错（反射、ROM 改过的方法）；
        // 出错就退回普通常驻通知。前台服务靠这条通知活着，它不能因为
        // 「想美一下」而消失。
        val mode = currentPromoMode()
        return ongoingNotification(this, text, short, mode, countdown)
    }

    /// 当前该用哪种提升姿势。
    ///
    /// `promoBroken` 是这台机器的实测结果：提升过的通知被系统抹掉过一次，
    /// 那就不再试了（见 [verifyStillPosted]）。宁可没有胶囊，不能没有通知。
    private fun currentPromoMode(): Int {
        // 提升曾经在 HyperOS 上让常驻通知从列表里消失过，后来查明是前台服务
        // 根本没起来（通知也就没人发），不是提升本身。现在服务有看门狗、
        // 发完还有 1.5 秒自检，所以重新开着；哪天真被系统抹掉，
        // verifyStillPosted 会把 promoBroken 置上并退回普通通知。
        if (!PROMO_ENABLED) return PROMO_PLAIN
        if (!liveUpdates || promoBroken) return PROMO_PLAIN
        return try {
            promoMode(this)
        } catch (_: Throwable) {
            PROMO_PLAIN
        }
    }

    /// 发完再看一眼：这条通知还在不在。
    ///
    /// Android 16 的「提升」不是纯装饰：部分 ROM（HyperOS）把提升过的通知
    /// 从通知列表里抽走却没把胶囊画出来，用户看到的就是「通知没了」。
    /// 前台服务不能赌这个，所以在发出提升版之后 1.5 秒回头确认；
    /// 不见了就关掉提升、立刻按普通通知重发一条。
    private fun verifyStillPosted() {
        Handler(Looper.getMainLooper()).postDelayed({
            if (promoBroken) return@postDelayed
            val nm = getSystemService(NotificationManager::class.java)
            val alive = try {
                nm.activeNotifications.any { it.id == NOTIFICATION_ID }
            } catch (_: Throwable) {
                true
            }
            if (!alive) {
                promoBroken = true
                republish()
            }
        }, 1500)
    }

    /// 通知看门狗：服务活着，那条通知就必须在。
    ///
    /// 不赌任何单一原因（提升、ROM 清理、系统回收、用户手滑划掉）。
    /// 十秒查一次通知列表，不在了就照上一次的内容重发一条。前台服务的
    /// 通知没了，等于后台在用户眼里也没了。
    private val notifWatch = Handler(Looper.getMainLooper())
    private val notifWatchRun = object : Runnable {
        override fun run() {
            try {
                val nm = getSystemService(NotificationManager::class.java)
                if (nm.activeNotifications.none { it.id == NOTIFICATION_ID }) republish()
            } catch (_: Throwable) {
                // 查不到就下次再查
            }
            notifWatch.postDelayed(this, 10000L)
        }
    }

    /// 用上一次的文本/胶囊/倒计时重建并发一次（换提升姿势、刷新前台服务类型时用）。
    private fun republish() {
        val nm = getSystemService(NotificationManager::class.java)
        val mode = currentPromoMode()
        try {
            nm.notify(
                NOTIFICATION_ID,
                ongoingNotification(this, lastNotificationText, lastNotificationShort, mode, lastCountdown)
            )
            markPosted()
            if (mode != PROMO_PLAIN) verifyStillPosted()
        } catch (e: Throwable) {
            markFailed(e)
        }
    }

    fun updateNotification(text: String, short: String = "", countdown: Long = 0) {
        // 记下来：刷新前台服务类型（音频采集开关）时要用同一份文本重新 startForeground
        lastNotificationText = text
        lastNotificationShort = short
        lastCountdown = countdown
        val nm = getSystemService(NotificationManager::class.java)
        val mode = currentPromoMode()
        try {
            nm.notify(NOTIFICATION_ID, ongoingNotification(this, text, short, mode, countdown))
            markPosted()
            if (mode != PROMO_PLAIN) verifyStillPosted()
        } catch (e: Throwable) {
            // 建不出来就保持上一条：宁可文字旧，不能没有通知
            markFailed(e)
        }
    }

    private fun markPosted() {
        lastBuildOk = true
        lastBuildError = ""
        lastNotifyAt = System.currentTimeMillis()
    }

    private fun markFailed(e: Throwable) {
        lastBuildOk = false
        lastBuildError = e.javaClass.simpleName + ": " + (e.message ?: "")
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
        // GNSS 卫星状态：与 provider 监听同生同死（切模式 / 停服务都要注销，
        // 否则回调会一直挂在系统上、拿着已死的 Service 引用）。
        startGnssStatusMonitor(useGps)
        // GPS 高精度（gps / gps_network 注册；纯网络模式不注册 GPS）
        var gpsRequested = false
        if (useGps) {
            try {
                // minTime 默认 10s → 用户可调（默认 1s，见 gpsIntervalMs）：
                // 10s 是「省电优先」的取值，代价是轨迹每 10 秒才一个点 —— 骑车/开车时
                // 一个拐弯正好落在两个点之间，画出来就是一条切角的斜线。
                // 1s 是导航类应用的常规取样率；下方 minDistance 仍是 5m，静止时 GPS 不给
                // 回调，所以待机功耗并不同着涨。嫌耗电的用户在设置里往大调。
                lm.requestLocationUpdates(
                    LocationManager.GPS_PROVIDER, gpsIntervalMs, 5f, listener, Looper.getMainLooper())
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

        // 0.5) GNSS 监听的**自愈重试**。注册会失败且不会自己好：权限刚授予（服务比
        //    授权早一步起来）、系统 GPS 引擎刚起、个别 ROM 直接拒绝。此时
        //    `gnssUsed/gnssView` 一直是 -1，上层永远显示「—」—— 用户报的
        //    「安卓取不到卫星数」就是这个状态。拿到实时 GPS 定位说明引擎在跑，
        //    就按 30 秒退避再注册一次（`gnssAttemptMs` 由 startGnssStatusMonitor 记）。
        if (isGps && !fromLastKnown && gnssUsed < 0 && gnssView < 0 &&
            now - gnssAttemptMs > GNSS_RETRY_MS
        ) {
            startGnssStatusMonitor(true)
        }

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
            // 参与定位的卫星数（null = 平台/机型没给）。
            // 缓存位置（fromLastKnown）一律不带：那是几小时前的颗数，报出去只会骗人。
            "satellites" to (if (fromLastKnown) null else satellitesOf(location, isGps)),
            // 让上层知道这只是「缓存位置、仅供快速出图」：可以更新标记，
            // 但**不能**写进轨迹（见 state.dart 的 _onFix）
            "lastKnown" to fromLastKnown,
            "status" to status))
    }

    /**
     * 这次定位里的卫星数：定位自带的 extras → GNSS 参与定轨数 → GNSS 在视数。
     *
     * 三级都试是为了**机型差异**：extras（部分机型的 GPS provider 会填）最准，
     * 它没有时用系统 GNSS 状态；status 里的 `usedInFix` 位图也有机型不填
     * （恒 false → 参与数恒 0），那时退回在视颗数 —— 有数总比装作「平台没提供」好。
     *
     * 网络定位（基站 / Wi-Fi）没有卫星可言，一律返回 null —— 返回 0 会让界面与信标
     * 把「这个来源不报卫星」说成「一颗星都没有」。
     */
    @Suppress("MissingPermission")
    private fun satellitesOf(location: Location, isGps: Boolean): Int? {
        try {
            val b = location.extras
            if (b != null && b.containsKey("satellites")) {
                val n = b.getInt("satellites", -1)
                if (n > 0) return n
            }
        } catch (_: Exception) {}
        if (!isGps) return null
        if (gnssUsed > 0) return gnssUsed
        if (gnssView > 0) return gnssView
        return null
    }

    /** 注册 / 注销 GNSS 卫星状态监听（只在需要 GPS 的模式下听）。 */
    @Suppress("MissingPermission")
    private fun startGnssStatusMonitor(useGps: Boolean) {
        stopGnssStatusMonitor()
        if (!useGps) return
        // 记下尝试时刻：失败时不会自己好，靠 considerLocation 的退避重试再来（见那里）。
        gnssAttemptMs = System.currentTimeMillis()
        val cb = object : GnssStatus.Callback() {
            override fun onSatelliteStatusChanged(status: GnssStatus) {
                var used = 0
                for (i in 0 until status.satelliteCount) {
                    if (status.usedInFix(i)) used++
                }
                gnssUsed = used
                gnssView = status.satelliteCount
            }
        }
        try {
            locationManager?.registerGnssStatusCallback(cb, Handler(Looper.getMainLooper()))
            gnssCallback = cb
        } catch (_: Exception) {
            gnssCallback = null
        }
    }

    private fun stopGnssStatusMonitor() {
        gnssCallback?.let {
            try { locationManager?.unregisterGnssStatusCallback(it) } catch (_: Exception) {}
        }
        gnssCallback = null
        gnssUsed = -1
        gnssView = -1
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
        stopGnssStatusMonitor()
    }
}

/// 通知的大图标：启动图标裁成圆形后的那份（drawable-nodpi/ic_notif_large.png）。
///
/// 为什么不直接用 `R.mipmap.ic_launcher`：它是整块深蓝底、四角还带半透明黑，
/// 当大图标贴进通知面板就是一个发脏的黑方块。裁圆后剩下的就是 APP 自己那张脸。
/// 解码结果缓存一份 —— 通知刷得很密，每 15 秒都要重建。
private var notifLargeCache: android.graphics.Bitmap? = null

private fun notifLargeIcon(ctx: Context): android.graphics.Bitmap {
    notifLargeCache?.let { return it }
    val b = try {
        android.graphics.BitmapFactory.decodeResource(
            ctx.resources, R.drawable.ic_notif_large)
    } catch (_: Throwable) {
        null
    } ?: android.graphics.Bitmap.createBitmap(1, 1, android.graphics.Bitmap.Config.ARGB_8888)
    notifLargeCache = b
    return b
}

/// 常驻通知的唯一构造点。
///
/// 服务发通知、诊断量能力都用它：诊断如果自己另拼一条，测的就不是真正出去的那条。
/// [mode] 见 [PROMO_REQUEST] / [PROMO_COLORIZED] / [PROMO_PLAIN]。
private fun ongoingNotification(
    ctx: Context,
    text: String,
    short: String,
    mode: Int,
    countdown: Long
): Notification {
    val pendingIntent = PendingIntent.getActivity(
        ctx, 0,
        Intent(ctx, MainActivity::class.java),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )
    // 连接/断开按钮
    val toggleIntent = Intent(ctx, LocationService::class.java).apply {
        action = LocationService.ACTION_TOGGLE_CONNECT
    }
    val togglePi = PendingIntent.getService(
        ctx, 1, toggleIntent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )
    val toggleAction = NotificationCompat.Action.Builder(
        android.R.drawable.ic_media_play,
        "连接/断开",
        togglePi
    ).build()
    // 退出按钮
    val exitIntent = Intent(ctx, LocationService::class.java).apply {
        action = LocationService.ACTION_EXIT
    }
    val exitPi = PendingIntent.getService(
        ctx, 2, exitIntent,
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    )
    val exitAction = NotificationCompat.Action.Builder(
        android.R.drawable.ic_menu_close_clear_cancel,
        "退出",
        exitPi
    ).build()
    val builder = NotificationCompat.Builder(ctx, LocationService.CHANNEL_ID)
        .setContentTitle("APRSlocus")
        .setContentText(text)
        // 小图标用单色剪影（状态栏与实时更新的胶囊只看它）；大图标用启动图标的圆形版
        // —— 启动图是整块深蓝底、四角还带半透明黑，原样贴进通知面板就是个发脏的方块。
        .setSmallIcon(R.drawable.ic_stat_aprs)
        .setLargeIcon(notifLargeIcon(ctx))
        .setContentIntent(pendingIntent)
        .setOngoing(true)
        .setSilent(true)
        // setOnlyAlertOnce：文字刷新（台站数/收包数/信标倒计时）不该再响一次。
        // setSilent 管的是「这条通知本身静音」，但部分 ROM 会在文字变化时把
        // 常驻通知当成新通知重新弹一遍；加上它才有「更新不打扰」的保证。
        .setOnlyAlertOnce(true)
        // 提升（实时更新）要求通知用 BigTextStyle / CallStyle / ProgressStyle /
        // MetricStyle 之一：展开式正文既符合要求，本身也比一行截断好看。
        .setStyle(NotificationCompat.BigTextStyle().bigText(text))
        .addAction(toggleAction)
        .addAction(exitAction)
    applyPromo(builder, mode, short, countdown)
    return builder.build()
}

/// 把提升请求加到通知上。
///
/// **整段包在 try/catch 里**：这些只是「请系统考虑提升」，其中任一项在本机
/// 不可用（老系统、ROM 改过、依赖被 R8 改写过）都只能让提升失效，
/// 不能让通知本身发不出去 —— 通知是前台服务的命，丢一次服务就死了。
private fun applyPromo(
    b: NotificationCompat.Builder,
    mode: Int,
    short: String,
    countdown: Long
) {
    try {
        when (mode) {
            PROMO_REQUEST -> {
                b.setRequestPromotedOngoing(true)
                if (short.isNotEmpty()) b.setShortCriticalText(short)
            }
            PROMO_COLORIZED -> {
                b.setColorized(true)
                if (short.isNotEmpty()) b.setShortCriticalText(short)
            }
        }
        // 倒计时用系统自己的计时器（chronometer）：它自己一秒一跳，
        // 我们不用为了「跳到下一秒」反复重发通知。部分 ROM 的胶囊不画它，
        // 那种情况下就是那行文字顶上。
        if (mode != PROMO_PLAIN && countdown > 0) {
            b.setWhen(System.currentTimeMillis() + countdown * 1000)
                .setUsesChronometer(true)
                .setChronometerCountDown(true)
        }
    } catch (_: Throwable) {
        // 放弃提升，通知照发
    }
}

/// 不提升：普通常驻通知（也是 [promoMode] 判不出来时的退路）。
private const val PROMO_PLAIN = -1

/// 提升总开关。
///
/// 开：Android 16 的「Live Updates」是这条通知该有的样子（胶囊/特殊通知）。
/// 出问题时的退路是 [promoBroken] 与 [verifyStillPosted]，不是这个开关。
private const val PROMO_ENABLED = true

/// 带 `requestPromotedOngoing` 请求：Android 16 QPR1（SDK 36.1）起才有这个接口。
private const val PROMO_REQUEST = 0

/// 带彩色标记：Android 16 首发版没有请求接口，只认「彩色 + 可提升样式」这条老规矩。
private const val PROMO_COLORIZED = 1

/// 两种都不认：这台机器的系统不会提升常驻通知，就是普通通知。
private const val PROMO_NONE = 2

@Volatile private var promoModeCache = Int.MIN_VALUE

/// 本机系统认哪种提升姿势。
///
/// 不用版本号猜：两个 Android 16 分支的门槛不一样（QPR1 要求请求标记且**不能**
/// 是彩色，首发版反过来只认彩色），ROM 还可能自己改。两种各造一条真通知，
/// 问系统 `hasPromotableCharacteristics()` 认哪条，认下就缓存。
/// 判断交给系统，比我们自己列举条件可靠。
private fun promoMode(ctx: Context): Int {
    val cached = promoModeCache
    if (cached != Int.MIN_VALUE) return cached
    var decided = PROMO_NONE
    for (m in intArrayOf(PROMO_REQUEST, PROMO_COLORIZED)) {
        val probe = try {
            ongoingNotification(ctx, "诊断", "9s", m, 0)
        } catch (_: Throwable) {
            null
        }
        if (probe != null && promotable(probe)) {
            decided = m
            break
        }
    }
    promoModeCache = decided
    return decided
}

/// 系统会不会把这条通知提上去（平台同一套判据，见 hasPromotableCharacteristics）。
private fun promotable(n: Notification): Boolean = try {
    Notification::class.java.getMethod("hasPromotableCharacteristics").invoke(n) == true
} catch (_: Throwable) {
    false
}

private fun promoModeName(m: Int): String = when (m) {
    PROMO_REQUEST -> "请求接口"
    PROMO_COLORIZED -> "彩色通知"
    PROMO_NONE -> "系统不认提升"
    else -> "未开"
}

/// 通知相关的自查结果：本机支持到什么程度。用户点了「通知诊断」才看。
///
/// 为什么做成一行行文字：这台机器上到底缺哪一环，只能由设备自己说 ——
/// 「支持实时更新」不是个是/否问题，是四五个方法的组合。
///
/// 前几行是「方法在不在」，最后两行是「真造一条通知，系统认不认」—— 后者才算数。
fun diag(
    context: Context,
    liveText: String = "",
    dartRunning: Boolean = false,
    dartStatus: String = ""
): String {
    val nm = context.getSystemService(NotificationManager::class.java)
    fun has(cls: Class<*>, name: String, vararg args: Class<*>): String =
        try {
            cls.getMethod(name, *args)
            "有"
        } catch (_: Throwable) {
            "没有"
        }
    fun bool(obj: Any?, name: String): String {
        if (obj == null) return "未知"
        return try {
            val v = obj.javaClass.getMethod(name).invoke(obj)
            if (v == true) "允许" else "不允许"
        } catch (_: Throwable) {
            "没有这个方法"
        }
    }
    val lines = mutableListOf<String>()
    lines.add("系统：Android ${Build.VERSION.RELEASE}（SDK ${Build.VERSION.SDK_INT}）")
    lines.add("机型：${Build.MANUFACTURER} ${Build.BRAND} ${Build.MODEL}")
    lines.add("canPostPromotedNotifications：" + bool(nm, "canPostPromotedNotifications"))
    // 参数类型必须与平台声明一致：boolean 用基本类型，shortCriticalText 收的是 String。
    // 以前这里写成 Boolean::class.javaObjectType / CharSequence，两个都永远查不到 ——
    // 诊断因此把「平台没这个方法」当成了结论，绕去用兼容层。
    lines.add("setRequestPromotedOngoing：" + has(Notification.Builder::class.java,
        "setRequestPromotedOngoing", Boolean::class.javaPrimitiveType!!))
    lines.add("setShortCriticalText：" + has(Notification.Builder::class.java,
        "setShortCriticalText", String::class.java))
    lines.add("hasPromotableCharacteristics：" + has(Notification::class.java,
        "hasPromotableCharacteristics"))
    lines.add("系统认的提升姿势：" + promoModeName(promoMode(context)))
    // 开关关着时，上面那行说「系统认」也没用：通知压根没带提升请求。
    lines.add("提升开关：" + (if (PROMO_ENABLED) "开" else "关"))
    lines.add("前台服务：" + (if (LocationService.isRunning()) "在跑" else "没在跑"))
    // Dart 那边的看法：它只知道自己发过启动请求，不知道原生有没有真的起来。
    // 两边不一致（Dart 说跑着、原生说没跑）就是服务崩了或被系统挡了。
    lines.add("Dart 侧认为在跑：" + (if (dartRunning) "是" else "否"))
    if (dartStatus.isNotEmpty()) lines.add("Dart 侧状态文案：$dartStatus")
    // 通知到底在不在：这是「已提升」唯一可信的证据 —— 已提升时部分系统会把
    // 通知从通知列表里抽走、只留状态栏那一条，用户看起来就是「通知没了」。
    val active = try {
        nm?.activeNotifications
    } catch (_: Throwable) {
        null
    }
    val mine = active?.firstOrNull { it.id == LocationService.NOTIFICATION_ID }
    lines.add("通知列表里这条：" + when {
        active == null -> "查不到"
        mine == null -> "没有"
        else -> "在"
    })
    if (mine != null) {
        val promoted = (mine.notification.flags and Notification.FLAG_PROMOTED_ONGOING) != 0
        lines.add("系统标记：" + if (promoted) "已提升（实时更新）" else "普通常驻通知")
    }
    lines.add("当前样式：" + (if (LocationService.liveUpdatesOn()) "实时更新" else "普通常驻通知"))
    lines.add("设置里的文字选项：" + when (liveText) {
        "counts" -> "收发数"
        "grid" -> "网格"
        "course" -> "朝向"
        "beacon" -> "发射倒计时"
        "default" -> "默认"
        else -> "未传来（$liveText）"
    })
    lines.add("提升被系统抹过：" + (if (LocationService.promoBrokenByRom()) "是（已退回普通通知）" else "否"))
    // 通知能不能发出去的第一道门：应用通知开关与通道重要性。
    // 被系统或用户关掉时 notify() 不报错，只是什么都没发生。
    lines.add("应用通知开关：" + (if (nm.areNotificationsEnabled()) "开" else "关"))
    val ch = try {
        nm.getNotificationChannel(LocationService.CHANNEL_ID)
    } catch (_: Throwable) {
        null
    }
    lines.add("通知通道重要性：" + when (ch?.importance) {
        0 -> "0（已关闭）"
        1 -> "1（最底）"
        2 -> "2（低）"
        3 -> "3（默认）"
        4 -> "4（高）"
        5 -> "5（最高）"
        null -> "查不到"
        else -> ch.importance.toString()
    })
    lines.addAll(LocationService.lastNotifReport())
    // 真发一条测试通知（不同 id，用同一套构造），马上看它在不在，然后撤掉。
    // 「到底能不能发出去」问系统最准：能发而用户看不到，与压根发不出去，
    // 是两个完全不同的毛病。
    val probeId = 9901
    lines.add("测试通知：" + try {
        nm.notify(probeId, ongoingNotification(context, "通知自检", "", PROMO_PLAIN, 0))
        val seen = nm.activeNotifications.any { it.id == probeId }
        nm.cancel(probeId)
        if (seen) "发出去了，系统里有" else "发出去但系统没有"
    } catch (e: Throwable) {
        "出错（" + e.javaClass.simpleName + "）"
    })
    return lines.joinToString("\n")
}
