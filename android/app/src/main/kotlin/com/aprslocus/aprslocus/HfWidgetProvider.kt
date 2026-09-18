package com.aprslocus.aprslocus

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.util.Log
import android.view.View
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONException
import org.json.JSONObject

/**
 * ─── 桌面小组件：短波 / 电离层传播（4×2）───
 *
 * 逐波段给出**日间 / 夜间**传播条件（每格是一条条件色带：淡底 + 左端色标），
 * 以及 SFI / Kp / A 三个汇总指数，指数行右端另有一个 6m 格。
 * 数据来自 hamqsl.com 的 `calculatedconditions`（业余界标准 HF 传播源），
 * 由 Dart 侧 `lib/hf.dart` 拉取、解析、**本地化**后推过来 —— 本类不联网、
 * 也不做任何判定与文案拼接。
 *
 * **为什么固定 4×2**（`resizeMode="none"`，见 aprslocus_hf_widget_info.xml）：
 * 内容是一张**表**（波段 × 昼夜）。表不像列表那样能优雅降级 —— 挤到 2×2 就
 * 只剩波段名而没有条件值，等于砍掉最有用的信息。与其提供一个会被拖坏的组件，
 * 不如老实声明尺寸。（天气组件能自适应，因为它的内容可以少给几条。）
 *
 * ⚠ RemoteViews 铁律（同天气组件，违反其一都是**运行时**白块）：
 *   ① 只用白名单控件（FrameLayout / LinearLayout / TextView / ImageView）——
 *      **不能用原生 `<View>`**。
 *   ② 不能用 `<selector>` / ripple 当背景。
 *   ③ 不能用 styles.xml 主题样式，字号颜色就地写死。
 *   ④ `setInt(viewId, "方法名", …)` 的方法是**字符串**，只在运行时炸。
 *      圆点是 ImageView，所以 `setColorFilter` 可用 —— 它**只存在于 ImageView**
 *      （v1.6.114 的线上事故就是把 TextView 当圆点用，抛 NoSuchMethodException
 *      导致整个组件显示「小组件加载失败」）。
 *
 * **本组件的换色机制**（与天气组件的圆点**相反**，别照抄）：
 * 条件色带是 **TextView**，换底只能走 `setBackgroundResource`（View 的方法）——
 * `setColorFilter` 在这里用会直接抛。四个条件各一张 drawable
 * （aw_track_{good,fair,poor,closed}），由 tool/gen_app_widget_drawables.py 生成。
 * 文字色则走 `setTextColor`（TextView 的成员方法，可用），
 * 取 @color/aw_q_* —— 夜间由资源系统自动给提亮版本。
 */
class HfWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        manager: AppWidgetManager,
        ids: IntArray,
    ) {
        ids.forEach { render(context, manager, it) }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        manager: AppWidgetManager,
        id: Int,
        newOptions: Bundle?,
    ) {
        render(context, manager, id)
    }

    companion object {
        private const val TAG = "APRSHfWidget"

        /** 波段行数（与 aw_widget_hf.xml 里的行数必须一致） */
        private const val BAND_ROWS = 4

        /** 指数个数（SFI / Kp / A） */
        private const val IDX_CELLS = 3

        /** ← 与 lib/hf_widget.dart 的 kHfWidgetSnapshotVersion 必须一致 */
        private const val SNAPSHOT_VERSION = 1

        /**
         * 6m 无条件时格子里的占位文案 —— 与 Dart 侧的 `HfNow.none` 同一个值。
         *
         * 为什么是「显示 `--`」而不是旧的「整格隐藏」：隐藏会让这个格子时有时无，
         * 而「6m 没开通」本身就是**常态且有信息量**（开通是例外）；反过来，
         * 一个时隐时现的格子在组件里会造成宽度跳变。它跟 SFI/Kp/A 一行，
         * 占位而非变色，不抢注意力。
         */
        private const val SIX_NONE = "--"

        /** 指数行：每格是 (label, value)；值的颜色由 Dart 按阈值算好 */
        private val IDX_LABEL = intArrayOf(
            R.id.aw_idx0_label, R.id.aw_idx1_label, R.id.aw_idx2_label,
        )
        private val IDX_VALUE = intArrayOf(
            R.id.aw_idx0_value, R.id.aw_idx1_value, R.id.aw_idx2_value,
        )

        /** 波段行：每行是 (波段名, 日间 chip, 夜间 chip) */
        private val BAND_IDS = arrayOf(
            intArrayOf(R.id.aw_band0_name, R.id.aw_band0_day, R.id.aw_band0_night),
            intArrayOf(R.id.aw_band1_name, R.id.aw_band1_day, R.id.aw_band1_night),
            intArrayOf(R.id.aw_band2_name, R.id.aw_band2_day, R.id.aw_band2_night),
            intArrayOf(R.id.aw_band3_name, R.id.aw_band3_day, R.id.aw_band3_night),
        )

        /**
         * 条件等级 → 色带底色（aw_track_*：淡色圆角底 + 左端 2.5dp 色标）。
         *
         * **为什么是 4 张预生成 drawable、而不是运行时染色**：色带是 TextView，
         * 而 `setColorFilter` **只存在于 ImageView**（View / TextView 都没有）——
         * v1.6.114 的线上事故正是把 setColorFilter 用在 TextView 上，
         * 抛 NoSuchMethodException → `RemoteViews.apply()` 抛 ActionException →
         * **整个组件报废**。TextView 换底只能用 `setBackgroundResource`（View 方法），
         * 所以四个等级各给一张。
         *
         * 未知等级回退到 closed（灰）而不是 0 —— 传 0 会把背景清掉，
         * 色带消失、只剩一行无处可归的文字。
         */
        private val TRACK_BY_LEVEL = mapOf(
            "good" to R.drawable.aw_track_good,
            "fair" to R.drawable.aw_track_fair,
            "poor" to R.drawable.aw_track_poor,
            "closed" to R.drawable.aw_track_closed,
        )

        /**
         * 条件等级 → chip **文字**色（基本色）。
         *
         * 定稿是 tonal chip：淡色底 + 条件色文字。底色在 drawable 里（`#1C` 前缀
         * 的 11% 淡色），文字色只能代码设 —— 而 `setTextColor` 是 TextView 的
         * 成员方法，可以直接用（不像 `setColorFilter` 那样只存在于 ImageView）。
         *
         * 与 lib/hf.dart 的 `hfQualityColor` 是**同一组基准色** —— 那边负责面板，
         * 这边负责组件；改色要两处一起改，测试里有契约盯着。
         */
        private val QUALITY_COLOR = mapOf(
            "good" to R.color.aw_q_good,
            "fair" to R.color.aw_q_fair,
            "poor" to R.color.aw_q_poor,
            "closed" to R.color.aw_q_closed,
        )

        /** 波段行的容器（数据不足时整行收起，而不是留空行） */
        private val BAND_ROWS_ID = intArrayOf(
            R.id.aw_band0, R.id.aw_band1, R.id.aw_band2, R.id.aw_band3,
        )

        /** 刷新所有已添加的短波组件实例 */
        fun refreshAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context) ?: return
            val ids = manager.getAppWidgetIds(
                ComponentName(context, HfWidgetProvider::class.java)
            )
            ids.forEach { render(context, manager, it) }
        }

        fun render(context: Context, manager: AppWidgetManager, id: Int) {
            val views = RemoteViews(context.packageName, R.layout.aw_widget_hf)
            views.setOnClickPendingIntent(R.id.aw_root, openApp(context))

            val snap = parseSnapshot(context)
            if (snap == null || !snap.optBoolean("hasData", false)) {
                val label = snap?.read("emptyLabel")
                    ?: context.getString(R.string.app_widget_hf_empty)
                views.setViewVisibility(R.id.aw_pad, View.GONE)
                views.setViewVisibility(R.id.aw_empty, View.VISIBLE)
                views.setTextViewText(R.id.aw_empty, label)
                manager.updateAppWidget(id, views)
                return
            }

            views.setViewVisibility(R.id.aw_pad, View.VISIBLE)
            views.setViewVisibility(R.id.aw_empty, View.GONE)

            // 标题与表头文案都由 Dart 侧本地化好（6 种语言）
            views.setTextViewText(R.id.aw_hf_title, snap.read("title"))
            // 列头「日间 / 夜间」的文案也要本地化（6 种语言），所以由 Dart 给。
            // 它们的**位置**与下面 chip 的左边缘对齐，靠布局的等分列实现。
            views.setTextViewText(R.id.aw_ch_day, snap.read("dayLabel"))
            views.setTextViewText(R.id.aw_ch_night, snap.read("nightLabel"))

            // 指数行：SFI / Kp / A。颜色由 Dart 侧按阈值算好（Kp/A 越大越差）
            val idx = snap.optJSONArray("indices")
            for (i in 0 until IDX_CELLS) {
                val cell = idx?.optJSONObject(i)
                views.setTextViewText(IDX_LABEL[i], cell.read("label"))
                views.setTextViewText(IDX_VALUE[i], cell.read("value"))
                // `cell` 是 JSONObject?：`optInt` 不像我那个 read 扩展那样
                // 能挂在可空接收者上，必须写 `cell?.optInt(...) ?: 0`
                val color = cell?.optInt("color", 0) ?: 0
                if (color != 0) views.setTextColor(IDX_VALUE[i], color)
            }

            // 6m 展望（指数行右端、「6m」标签后面那一格）。
            //
            // 无条件**不隐藏**，而是显示灰色的 `--`：隐藏会让格子时有时无、
            // 行宽跳变，而「6m 没开通」本身是常态且有信息量（开通才是例外）。
            val six = snap.optJSONObject("six")
            if (six != null) {
                val lv = six.read("level")
                val known = lv.isNotEmpty() && lv != "unknown"
                views.setTextViewText(
                    R.id.aw_six,
                    if (known) six.read("label") else SIX_NONE,
                )
                val key = if (known) lv else "closed"
                views.setInt(
                    R.id.aw_six, "setBackgroundResource",
                    TRACK_BY_LEVEL[key] ?: R.drawable.aw_track_closed,
                )
                views.setTextColor(
                    R.id.aw_six,
                    context.getColor(QUALITY_COLOR[key] ?: R.color.aw_q_closed),
                )
            }

            // 逐波段：日间 / 夜间
            val bands = snap.optJSONArray("bands")
            for (i in 0 until BAND_ROWS) {
                val row = bands?.optJSONObject(i)
                val vis = if (row != null) View.VISIBLE else View.GONE
                views.setViewVisibility(BAND_ROWS_ID[i], vis)
                if (row == null) continue
                fillBand(context, views, BAND_IDS[i], row)
            }

            manager.updateAppWidget(id, views)
        }

        /** 填一行波段：波段名 + 两个条件 chip */
        private fun fillBand(
            context: Context,
            views: RemoteViews,
            ids: IntArray,
            band: JSONObject,
        ) {
            views.setTextViewText(ids[0], band.read("name"))
            chip(context, views, ids[1], band, "day")
            chip(context, views, ids[2], band, "night")
        }

        /**
         * 填一格条件色带：文字（已本地化）+ 按等级换底。
         *
         * 换底走 `setBackgroundResource`（View 的方法，TextView 可用）。
         * **不能**用 `setColorFilter` —— 那是 ImageView 独有的（见 TRACK_BY_LEVEL）。
         */
        private fun chip(
            context: Context,
            views: RemoteViews,
            target: Int,
            band: JSONObject,
            prefix: String,
        ) {
            val level = band.read("${prefix}Level")
            views.setTextViewText(target, band.read("${prefix}Label"))
            views.setInt(
                target,
                "setBackgroundResource",
                TRACK_BY_LEVEL[level] ?: R.drawable.aw_track_closed,
            )
            // 文字色 = 该等级的条件色。走**资源**而不是写死常量：
            // 夜间模式由资源系统自动取 values-night 里的提亮版本
            // （深底上基准色偏暗），组件里不需要判断 uiMode。
            views.setTextColor(
                target,
                context.getColor(
                    QUALITY_COLOR[level] ?: R.color.aw_q_closed
                ),
            )
        }

        private fun openApp(context: Context): PendingIntent {
            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            return PendingIntent.getActivity(
                context, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        /**
         * 读取并校验快照。版本不匹配时按「无数据」处理 —— 让老组件在 Dart 侧
         * 改了字段语义后安静退回占位态，而不是把错位的字段渲染出来。
         */
        private fun parseSnapshot(context: Context): JSONObject? {
            val raw = HfWidgetStore.load(context) ?: return null
            val obj = try {
                JSONObject(raw)
            } catch (e: JSONException) {
                Log.w(TAG, "快照 JSON 解析失败，按无数据处理", e)
                return null
            }
            val v = obj.optInt("v", -1)
            if (v != SNAPSHOT_VERSION) {
                Log.w(TAG, "快照版本不匹配（$v != $SNAPSHOT_VERSION），按无数据处理")
                return null
            }
            return obj
        }
    }
}
