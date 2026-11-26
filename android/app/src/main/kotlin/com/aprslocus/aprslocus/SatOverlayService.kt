package com.aprslocus.aprslocus

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.ServiceInfo
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import android.util.TypedValue
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import kotlin.math.abs

/**
 * 卫星悬浮小窗的原生桥。
 *
 * Dart 侧：`lib/sat_overlay.dart`。
 * 小窗本身的界面由 [SatOverlayService] 画；这里只做权限 / 数据 / 发信标转发。
 */
object SatOverlayBridge {
    const val CHANNEL = "com.aprslocus/sat_overlay"

    private var appContext: Context? = null
    private var channel: MethodChannel? = null

    fun attach(context: Context, messenger: BinaryMessenger) {
        appContext = context.applicationContext
        if (channel != null) return
        val ch = MethodChannel(messenger, CHANNEL)
        ch.setMethodCallHandler { call, result ->
            val ctx = appContext
            when (call.method) {
                "canDraw" -> result.success(canDraw(ctx))
                "openPermissionSettings" -> {
                    result.success(openPermissionSettings(ctx))
                }
                "show" -> {
                    val map = call.arguments as? Map<*, *>
                    val ok = ctx != null && canDraw(ctx) && map != null
                    if (ok && ctx != null && map != null) {
                        SatOverlayService.start(ctx, JSONObject(map).toString())
                    }
                    result.success(ok)
                }
                "update" -> {
                    val map = call.arguments as? Map<*, *>
                    if (map != null) {
                        SatOverlayService.update(JSONObject(map).toString())
                    }
                    result.success(null)
                }
                "hide" -> {
                    SatOverlayService.stopNow()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        channel = ch
    }

    /** Activity 要销毁了：引擎一走，发信标就没人处理了，小窗必须一起收掉。 */
    fun detach() {
        channel?.setMethodCallHandler(null)
        channel = null
        appContext = null
        SatOverlayService.stopNow()
    }

    /** 小窗被用户点 × / 通知里关掉时，让 Dart 把按钮状态一起复位。 */
    fun notifyClosed() {
        try {
            channel?.invokeMethod("closed", null)
        } catch (_: Exception) {
        }
    }

    /**
     * 原生小窗点「发信标」→ Dart 的 `beacon` 方法。
     * 回调返回要显示在小窗里的结果文案（已发送 / 无射频链路 …）。
     */
    fun requestBeacon(cb: (String?) -> Unit) {
        val ch = channel
        if (ch == null) {
            cb(null)
            return
        }
        try {
            ch.invokeMethod("beacon", null, object : MethodChannel.Result {
                override fun success(result: Any?) {
                    cb(result as? String)
                }

                override fun error(code: String, msg: String?, details: Any?) {
                    cb(msg)
                }

                override fun notImplemented() {
                    cb(null)
                }
            })
        } catch (_: Exception) {
            cb(null)
        }
    }

    private fun canDraw(ctx: Context?): Boolean {
        if (ctx == null) return false
        return try {
            Settings.canDrawOverlays(ctx)
        } catch (_: Exception) {
            false
        }
    }

    private fun openPermissionSettings(ctx: Context?): Boolean {
        if (ctx == null) return false
        return try {
            val i = Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:${ctx.packageName}")
            ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            ctx.startActivity(i)
            true
        } catch (_: Exception) {
            false
        }
    }
}

/**
 * 悬浮小窗服务：一个可拖动的小卡片，浮在其他应用上。
 *
 * 展示：卫星名、过境倒计时/进度、AZ/EL、多普勒修正后的上/下行、亚音；
 * 操作：一键发信标（转给 Dart）、点标题回应用、× 关闭。
 */
class SatOverlayService : Service() {

    companion object {
        private const val ACTION_SHOW = "com.aprslocus.action.SAT_OVERLAY_SHOW"
        private const val ACTION_STOP = "com.aprslocus.action.SAT_OVERLAY_STOP"
        private const val EXTRA_JSON = "sat_overlay_json"
        private const val CHANNEL_ID = "aprslocus_sat_window"
        private const val NOTIFICATION_ID = 1002
        private const val PREFS = "sat_overlay_window"

        private var instance: SatOverlayService? = null

        fun start(ctx: Context, json: String) {
            val i = Intent(ctx, SatOverlayService::class.java).apply {
                action = ACTION_SHOW
                putExtra(EXTRA_JSON, json)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                ctx.startForegroundService(i)
            } else {
                ctx.startService(i)
            }
        }

        fun update(json: String) {
            instance?.applyJson(json)
        }

        fun stopNow() {
            instance?.stopSelf()
        }
    }

    private var wm: WindowManager? = null
    private var root: View? = null
    private var params: WindowManager.LayoutParams? = null
    private lateinit var prefs: SharedPreferences

    private var nameView: TextView? = null
    private var statusView: TextView? = null
    private var lookView: TextView? = null
    private var freqView: TextView? = null
    private var hintView: TextView? = null
    private var txView: TextView? = null
    private var dot: View? = null

    private var linkOk = true
    private var noLink = ""
    private var transientText = ""
    private var transientUntil = 0L
    private var beaconBusy = false
    private var currentName = "APRS"
    private var currentStatus = ""
    private var lastNotifAt = 0L

    private val main = Handler(Looper.getMainLooper())

    private val cardBg = 0xE6161C24.toInt()
    private val textMain = 0xFFFFFFFF.toInt()
    private val textDim = 0xFFB8C2CF.toInt()
    private val green = 0xFF3DBE6A.toInt()
    private val orange = 0xFFFFA726.toInt()

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        instance = this
        prefs = getSharedPreferences(PREFS, MODE_PRIVATE)
        createChannel()
        startForegroundCompat(buildNotification())
        addOverlay()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopSelf()
            return START_NOT_STICKY
        }
        val json = intent?.getStringExtra(EXTRA_JSON)
        if (json == null) {
            // 进程被重建但没有数据：小窗没有意义，别留个空壳。
            stopSelf()
            return START_NOT_STICKY
        }
        applyJson(json)
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        root?.let {
            try {
                wm?.removeView(it)
            } catch (_: Exception) {
            }
        }
        root = null
        instance = null
        SatOverlayBridge.notifyClosed()
        try {
            stopForeground(true)
        } catch (_: Exception) {
        }
        super.onDestroy()
    }

    // ─── 悬浮窗 ───

    private fun addOverlay() {
        if (root != null) return
        if (!Settings.canDrawOverlays(this)) {
            stopSelf()
            return
        }
        val manager = getSystemService(WINDOW_SERVICE) as WindowManager
        wm = manager
        val card = buildCard()
        val p = WindowManager.LayoutParams(
            dp(198),
            WindowManager.LayoutParams.WRAP_CONTENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = prefs.getInt("x", dp(12))
            y = prefs.getInt("y", dp(120))
        }
        try {
            manager.addView(card, p)
            root = card
            params = p
        } catch (_: Exception) {
            stopSelf()
        }
    }

    private fun buildCard(): View {
        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(12), dp(9), dp(10), dp(11))
            background = rounded(cardBg, dp(14), 0x26FFFFFF, dp(1))
        }

        // 标题行：状态点 + 卫星名 + ×（拖动只在这行，按钮区不受影响）
        val title = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        val d = View(this).apply {
            background = circle(green)
            layoutParams = LinearLayout.LayoutParams(dp(7), dp(7)).apply {
                marginEnd = dp(6)
            }
        }
        dot = d
        val name = text(12.5f, textMain, true).apply {
            maxLines = 1
            ellipsize = android.text.TextUtils.TruncateAt.END
            text = "APRS"
            layoutParams = LinearLayout.LayoutParams(0, dp(20), 1f)
        }
        nameView = name
        val close = text(16f, textDim, false).apply {
            text = "×"
            gravity = Gravity.CENTER
            setPadding(dp(6), 0, dp(2), 0)
            isClickable = true
            setOnClickListener { stopSelf() }
        }
        title.addView(d)
        title.addView(name)
        title.addView(close)
        card.addView(title)

        val status = text(11f, textDim, false).apply {
            maxLines = 1
            ellipsize = android.text.TextUtils.TruncateAt.END
            setPadding(0, dp(3), 0, 0)
        }
        statusView = status
        card.addView(status)

        val look = text(10.5f, textDim, false).apply {
            setPadding(0, dp(3), 0, 0)
        }
        lookView = look
        card.addView(look)

        val freq = text(10.5f, textDim, false).apply {
            setPadding(0, dp(2), 0, 0)
        }
        freqView = freq
        card.addView(freq)

        val tx = text(12.5f, textMain, true).apply {
            text = "TX"
            gravity = Gravity.CENTER
            setPadding(0, dp(8), 0, dp(8))
            background = rounded(green, dp(10), 0, 0)
            isClickable = true
            setOnClickListener { requestBeacon() }
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { topMargin = dp(9) }
        }
        txView = tx
        card.addView(tx)

        val hint = text(9.5f, orange, false).apply {
            maxLines = 2
            setPadding(0, dp(4), 0, 0)
            visibility = View.GONE
        }
        hintView = hint
        card.addView(hint)

        // 拖动 + 点标题打开应用
        title.setOnTouchListener { _, e ->
            val p = params ?: return@setOnTouchListener false
            when (e.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    dragX = e.rawX
                    dragY = e.rawY
                    startX = p.x
                    startY = p.y
                    dragged = false
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    val dx = (e.rawX - dragX).toInt()
                    val dy = (e.rawY - dragY).toInt()
                    if (abs(dx) > dp(3) || abs(dy) > dp(3)) dragged = true
                    p.x = startX + dx
                    p.y = startY + dy
                    try {
                        wm?.updateViewLayout(root, p)
                    } catch (_: Exception) {
                    }
                    true
                }
                MotionEvent.ACTION_UP -> {
                    prefs.edit().putInt("x", p.x).putInt("y", p.y).apply()
                    if (!dragged) openApp()
                    true
                }
                else -> false
            }
        }
        return card
    }

    private var dragX = 0f
    private var dragY = 0f
    private var startX = 0
    private var startY = 0
    private var dragged = false

    private fun openApp() {
        try {
            startActivity(
                Intent(this, MainActivity::class.java).addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                )
            )
        } catch (_: Exception) {
        }
    }

    // ─── 数据 ───

    private fun applyJson(json: String) {
        val o = try {
            JSONObject(json)
        } catch (_: Exception) {
            return
        }
        val active = o.optBoolean("active", false)
        currentName = o.optString("name", "APRS")
        currentStatus = o.optString("status", "")
        nameView?.text = currentName
        statusView?.text = currentStatus
        statusView?.setTextColor(if (active) green else textDim)
        dot?.background = circle(if (active) green else textDim)

        val az = o.optString("az", "--")
        val el = o.optString("el", "--")
        lookView?.text = "AZ $az   EL $el"

        val tone = o.optString("tone", "")
        freqView?.text = buildString {
            append("↑ ").append(o.optString("up", "--"))
            append("   ↓ ").append(o.optString("down", "--"))
            if (tone.isNotEmpty()) append("   T ").append(tone)
        }

        txView?.text = o.optString("tx", txView?.text?.toString() ?: "TX")
        linkOk = o.optBoolean("link", true)
        noLink = o.optString("noLink", "")
        txView?.isEnabled = linkOk && !beaconBusy
        txView?.alpha = if (linkOk) 1f else 0.55f
        renderHint()
        refreshNotification()
    }

    private fun renderHint() {
        val h = hintView ?: return
        val now = System.currentTimeMillis()
        if (now < transientUntil && transientText.isNotEmpty()) {
            h.text = transientText
            h.setTextColor(green)
            h.visibility = View.VISIBLE
            return
        }
        if (!linkOk && noLink.isNotEmpty()) {
            h.text = noLink
            h.setTextColor(orange)
            h.visibility = View.VISIBLE
            return
        }
        h.visibility = View.GONE
    }

    private fun requestBeacon() {
        if (beaconBusy || !linkOk) return
        beaconBusy = true
        txView?.isEnabled = false
        txView?.alpha = 0.6f
        SatOverlayBridge.requestBeacon { msg ->
            main.post {
                beaconBusy = false
                txView?.isEnabled = linkOk
                txView?.alpha = if (linkOk) 1f else 0.55f
                if (msg != null) {
                    transientText = msg
                    transientUntil = System.currentTimeMillis() + 4000
                    renderHint()
                }
            }
        }
        // 通道没响应（引擎被系统冻结）时别永远卡住按钮。
        main.postDelayed({
            if (beaconBusy) {
                beaconBusy = false
                txView?.isEnabled = linkOk
                txView?.alpha = if (linkOk) 1f else 0.55f
            }
        }, 6000)
    }

    // ─── 通知 ───

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = getSystemService(NotificationManager::class.java) ?: return
        val ch = NotificationChannel(
            CHANNEL_ID,
            "APRSlocus 卫星小窗",
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = "在其他应用上显示卫星过境与发信标按钮"
            setShowBadge(false)
            setSound(null, null)
        }
        nm.createNotificationChannel(ch)
    }

    private fun buildNotification(): Notification {
        val open = Intent(this, MainActivity::class.java).addFlags(
            Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_NEW_TASK
        )
        val openPi = PendingIntent.getActivity(
            this,
            1,
            open,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val stopPi = PendingIntent.getService(
            this,
            2,
            Intent(this, SatOverlayService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_aprs)
            .setContentTitle("APRSlocus · $currentName")
            .setContentText(currentStatus)
            .setOngoing(true)
            .setSilent(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setContentIntent(openPi)
            .addAction(0, "✕", stopPi)
            .build()
    }

    private fun refreshNotification() {
        val now = System.currentTimeMillis()
        if (now - lastNotifAt < 5000) return
        lastNotifAt = now
        try {
            NotificationManagerCompat.from(this)
                .notify(NOTIFICATION_ID, buildNotification())
        } catch (_: Exception) {
        }
    }

    private fun startForegroundCompat(n: Notification) {
        try {
            if (Build.VERSION.SDK_INT >= 34) {
                startForeground(
                    NOTIFICATION_ID,
                    n,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
                )
            } else {
                startForeground(NOTIFICATION_ID, n)
            }
        } catch (_: Exception) {
            // 个别 ROM 不认 specialUse，退回普通前台通知；小窗继续可用。
            try {
                startForeground(NOTIFICATION_ID, n)
            } catch (_: Exception) {
            }
        }
    }

    // ─── 小工具 ───

    private fun text(sp: Float, color: Int, bold: Boolean): TextView =
        TextView(this).apply {
            setTextSize(TypedValue.COMPLEX_UNIT_SP, sp)
            setTextColor(color)
            if (bold) typeface = Typeface.DEFAULT_BOLD
        }

    private fun dp(v: Int): Int =
        (v * resources.displayMetrics.density).toInt()

    private fun rounded(color: Int, radius: Int, stroke: Int, strokeW: Int):
        GradientDrawable = GradientDrawable().apply {
        shape = GradientDrawable.RECTANGLE
        cornerRadius = radius.toFloat()
        setColor(color)
        if (strokeW > 0) setStroke(strokeW, stroke)
    }

    private fun circle(color: Int): GradientDrawable =
        GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            setColor(color)
        }
}
