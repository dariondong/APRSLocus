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
 * ─── APRSlocus 桌面小组件（4 个尺寸档）───
 *
 * 只做三件事：**选布局 → 填字段 → 按可用空间决定显示多少**。
 *
 * | 档位 | 格子 | 布局 | 内容 |
 * |---|---|---|---|
 * | tile | 3~4×2 | aw_widget_tile | 顶栏两行 / 左温度右 2×2 指标 / 底 2 条建议 |
 * | tall | 2×4 | aw_widget_tall | 「小面板」：顶栏两行 / 温度 / 3 行指标 / 2 条建议 |
 * | compact | 2×2~2×3 | aw_widget_compact | 顶栏两行 / 温度 / 1 条最要紧的建议 |
 * | row | 3~4×1 | aw_widget_row | 单行：温度 + 高低温 ｜ 一条建议 ｜ logo |
 *
 * **为什么这里一条业务判断都没有**：
 * 和风密钥在 Dart（构建期 `--dart-define` 注入）、火腿建议的判定规则在 Dart、
 * 文案本地化在 Dart（`AppLocalizations`）。一旦在 Kotlin 写下 `if (temp > 35)`，
 * 就会出现「App 面板说注意、桌面组件说良好」的分叉 —— 这种 bug 极难发现，
 * 因为两处各自看都「对」。所以这里只做渲染与**排版层**的取舍。
 *
 * **图标**：组件进程里没有 Material 图标字体，RemoteViews 也不认字体图标与
 * 矢量图。所以图标是在构建期用 tool/gen_app_widget_icons.py 把 Flutter 自带的
 * `MaterialIcons-Regular.otf` **预渲染成 PNG** 的 —— 于是组件上的图标与面板里的
 * `Icons.xxx` 是同一套字形。「图标名 → R.drawable」的映射表由同一个脚本生成
 * （WidgetIcons.kt），两边不会漂移。
 *
 * ⚠ 四条 RemoteViews 铁律（违反其一都是**运行时**白块，而编译期全绿）：
 *   ① 只用白名单控件（FrameLayout / LinearLayout / TextView / ImageView）——
 *      尤其是**不能用原生 `<View>`**。布局由 gen_app_widget_layouts.py 生成并自检。
 *   ② 不能用 `<selector>` / ripple 当背景：RemoteViews 由系统进程 inflate，
 *      状态选择器会直接抛异常。要「换状态」就用换 drawable。
 *   ③ 不能用 styles.xml 的主题样式，字号颜色必须就地写死。
 *   ④ `setInt(viewId, "方法名", …)` 的方法是**字符串**，写错不报编译错、只在运行时
 *      在系统进程里抛。所以字符串方法名全部集中在本文件，由
 *      tool/check_android_res_ids.py 按「目标控件类型」核对。
 *
 *      ⚠ 特别注意 `setColorFilter`：它**只存在于 ImageView**（View / TextView 都没有）。
 *      v1.6.114 的事故就是把这个方法用在了 TextView 做的圆点上，
 *      抛 NoSuchMethodException → RemoteViews.apply() 抛 ActionException →
 *      启动器显示「小组件加载失败」，**整个组件报废**。
 *      现在圆点与提示图标都是 ImageView，用法正确，且检查器会核对控件类型。
 */
class WeatherWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        manager: AppWidgetManager,
        ids: IntArray,
    ) {
        ids.forEach { render(context, manager, it) }
    }

    /** 用户拉伸/改变组件尺寸后重画：可能整档布局都要换 */
    override fun onAppWidgetOptionsChanged(
        context: Context,
        manager: AppWidgetManager,
        id: Int,
        newOptions: Bundle?,
    ) {
        render(context, manager, id)
    }

    /**
     * 一条通栏建议要填的 ResId。
     *
     * [row] 为 0 表示该档的提示直接挂在 aw_pad 下、没有行容器（单行档），
     * 此时显隐要分别对 [dot] / [level] / [text] 做。
     */
    private class TipRow(
        val row: Int,
        val dot: Int,
        val icon: Int,
        val level: Int,
        val text: Int,
    )

    /** 一个尺寸档要用到的全部 ResId；0 表示该档没有这个控件 */
    private class Ids(
        val layout: Int,
        val pad: Int,
        val empty: Int,
        /** 顶栏：城市 / AQI 胶囊（含圆点与文字）/ 观测时刻 */
        val city: Int = 0,
        val aqiPill: Int = 0,
        val aqiDot: Int = 0,
        val aqiText: Int = 0,
        val observed: Int = 0,
        /** 天气主区 */
        val heroIcon: Int = 0,
        val temp: Int = 0,
        val cond: Int = 0,
        val range: Int = 0,
        /** 指标格：每格是 (容器, 标签, 值) */
        val metricBoxes: IntArray = IntArray(0),
        val metricLabels: IntArray = IntArray(0),
        val metricValues: IntArray = IntArray(0),
        /** 建议：行数组 + 分组标题（标题仅竖长档有） */
        val tipRows: Array<TipRow> = emptyArray(),
        val tipsHeader: Int = 0,
        val tipsTitle: Int = 0,
        val tipsCount: Int = 0,
    )

    companion object {
        private const val TAG = "APRSWidget"

        /** ← 与 lib/app_widget.dart 的 kAppWidgetSnapshotVersion 必须一致 */
        private const val SNAPSHOT_VERSION = 1

        /** 估算「1 格」的 dp。与 aprslocus_weather_widget_info.xml 的 minWidth
         *  口径一致；老系统只给 dp，需要它反推格子数。 */
        private const val DP_PER_CELL = 74.0

        // ── 各档位的 ResId ────────────────────────────────────────
        // 全部写成静态表，不用 resources.getIdentifier("aw_m${i}_value") 反射：
        // 反射会被 R8 判成动态引用、需要额外 keep 规则；而且拼错名字只在运行时
        // 静默拿到 0（setTextViewText(0, …) 无声无息什么都不做）。

        private val ID_TILE = Ids(
            layout = R.layout.aw_widget_tile,
            pad = R.id.aw_pad,
            empty = R.id.aw_empty,
            city = R.id.aw_city,
            aqiPill = R.id.aw_aqi_pill,
            aqiDot = R.id.aw_aqi_dot,
            aqiText = R.id.aw_aqi_text,
            observed = R.id.aw_observed,
            heroIcon = R.id.aw_hero_icon,
            temp = R.id.aw_temp,
            cond = R.id.aw_cond,
            range = R.id.aw_range,
            // 主档只有 **3 格指标、单行**（不是 4 格两行）：主档高度由天气主区
            // 决定，指标多一行不省主区高度、只白占 14dp；而扣掉底部圆角净空后
            // 4×2 只剩 130dp 可用。这是 tool/preview_app_widget.py 量化后砍的。
            metricBoxes = intArrayOf(R.id.aw_m0, R.id.aw_m1, R.id.aw_m2),
            metricLabels = intArrayOf(R.id.aw_m0_label, R.id.aw_m1_label,
                R.id.aw_m2_label),
            metricValues = intArrayOf(R.id.aw_m0_value, R.id.aw_m1_value,
                R.id.aw_m2_value),
            tipRows = arrayOf(
                TipRow(R.id.aw_tip0, R.id.aw_tip0_dot, R.id.aw_tip0_icon,
                    R.id.aw_tip0_level, R.id.aw_tip0_text),
                TipRow(R.id.aw_tip1, R.id.aw_tip1_dot, R.id.aw_tip1_icon,
                    R.id.aw_tip1_level, R.id.aw_tip1_text),
            ),
            // 主档的建议行都是 1 行 → 用短文案（完整短句）
            tipShort = true,
        )

        private val ID_TALL = Ids(
            layout = R.layout.aw_widget_tall,
            pad = R.id.aw_pad,
            empty = R.id.aw_empty,
            city = R.id.aw_city,
            aqiPill = R.id.aw_aqi_pill,
            aqiDot = R.id.aw_aqi_dot,
            aqiText = R.id.aw_aqi_text,
            observed = R.id.aw_observed,
            heroIcon = R.id.aw_hero_icon,
            temp = R.id.aw_temp,
            cond = R.id.aw_cond,
            range = R.id.aw_range,
            // 竖长档只放 2 行指标：2 项 + 两行建议实测超 12.7dp（由预览量出）。
            // 竖长档的重点是「多给两条建议」，所以砍指标而不是砍建议。
            metricBoxes = intArrayOf(R.id.aw_m0, R.id.aw_m1),
            metricLabels = intArrayOf(R.id.aw_m0_label, R.id.aw_m1_label),
            metricValues = intArrayOf(R.id.aw_m0_value, R.id.aw_m1_value),
            tipRows = arrayOf(
                TipRow(R.id.aw_tip0, R.id.aw_tip0_dot, R.id.aw_tip0_icon,
                    R.id.aw_tip0_level, R.id.aw_tip0_text),
                TipRow(R.id.aw_tip1, R.id.aw_tip1_dot, R.id.aw_tip1_icon,
                    R.id.aw_tip1_level, R.id.aw_tip1_text),
            ),
            tipsHeader = R.id.aw_tips_header,
            tipsTitle = R.id.aw_tips_title,
            tipsCount = R.id.aw_tips_count,
        )

        private val ID_COMPACT = Ids(
            layout = R.layout.aw_widget_compact,
            pad = R.id.aw_pad,
            empty = R.id.aw_empty,
            city = R.id.aw_city,
            aqiPill = R.id.aw_aqi_pill,
            aqiDot = R.id.aw_aqi_dot,
            aqiText = R.id.aw_aqi_text,
            observed = R.id.aw_observed,
            heroIcon = R.id.aw_hero_icon,
            temp = R.id.aw_temp,
            cond = R.id.aw_cond,
            range = R.id.aw_range,
            // 紧凑档没有指标格：2×2 里再塞 4 格指标，温度和建议就没地方了 ——
            // 那正是第一版「挤」的做法。
            tipRows = arrayOf(
                TipRow(R.id.aw_tip0, R.id.aw_tip0_dot, R.id.aw_tip0_icon,
                    R.id.aw_tip0_level, R.id.aw_tip0_text),
            ),
        )

        private val ID_ROW = Ids(
            layout = R.layout.aw_widget_row,
            pad = R.id.aw_pad,
            empty = R.id.aw_empty,
            heroIcon = R.id.aw_hero_icon,
            temp = R.id.aw_temp,
            cond = R.id.aw_cond,
            range = R.id.aw_range,
            // 单行档的提示直接挂在 aw_pad 下，没有行容器（row = 0）
            tipRows = arrayOf(
                TipRow(0, R.id.aw_tip0_dot, R.id.aw_tip0_icon,
                    R.id.aw_tip0_level, R.id.aw_tip0_text),
            ),
            // 单行档只有一行 → 必须用短文案
            tipShort = true,
        )

        /** 天气档位 → 背景渐变。大小尺寸各一套（小档圆角更小，免得显得过圆） */
        private val BG_BY_KIND = mapOf(
            "clear" to R.drawable.aw_bg_clear,
            "cloudy" to R.drawable.aw_bg_cloudy,
            "overcast" to R.drawable.aw_bg_overcast,
            "rain" to R.drawable.aw_bg_rain,
            "storm" to R.drawable.aw_bg_storm,
            "snow" to R.drawable.aw_bg_snow,
            "fog" to R.drawable.aw_bg_fog,
        )
        private val BG_SMALL_BY_KIND = mapOf(
            "clear" to R.drawable.aw_bgs_clear,
            "cloudy" to R.drawable.aw_bgs_cloudy,
            "overcast" to R.drawable.aw_bgs_overcast,
            "rain" to R.drawable.aw_bgs_rain,
            "storm" to R.drawable.aw_bgs_storm,
            "snow" to R.drawable.aw_bgs_snow,
            "fog" to R.drawable.aw_bgs_fog,
        )

        /**
         * 按格子数选档位。
         *
         * 优先用 `appWidgetWidthCells/HeightCells`（API 31+ 起由启动器写入 bundle，
         * 比 dp 更准，且不受各家启动器 dp 口径差异影响）；老系统用 dp ÷ 74 反推。
         *
         * 取舍规则：
         *  - 高度 ≤ 1 → 只能单行（row）
         *  - 宽度 ≥ 3 且高度 ≥ 2 → 主档（tile），只有它放得下「左温度右指标」
         *  - 高度 ≥ 3 → 竖长档（tall），建议能堆叠
         *  - 其余（典型是 2×2）→ 紧凑档
         */
        private fun tierFor(manager: AppWidgetManager, id: Int): String {
            val opt = manager.getAppWidgetOptions(id) ?: Bundle()
            val cols = cells(opt, "appWidgetWidthCells",
                AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
            val rows = cells(opt, "appWidgetHeightCells",
                AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT)
            return when {
                rows <= 1 -> "row"
                cols >= 3 && rows >= 2 -> "tile"
                rows >= 3 -> "tall"
                else -> "compact"
            }
        }

        /** 取格子数：优先 bundle 里的 cells 值，否则用 dp 反推 */
        private fun cells(opt: Bundle, cellsKey: String, dpKey: String): Int {
            val c = opt.getInt(cellsKey, 0)
            if (c > 0) return c
            val dp = opt.getInt(dpKey, 0)
            if (dp <= 0) return 0
            return Math.ceil(dp / DP_PER_CELL).toInt()
        }

        /** 刷新所有已添加的组件实例（App 侧推送新快照后调用；也用于 clear） */
        fun refreshAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context) ?: return
            val ids = manager.getAppWidgetIds(
                ComponentName(context, WeatherWidgetProvider::class.java)
            )
            ids.forEach { render(context, manager, it) }
        }

        /** 把一个组件实例按当前快照 + 当前尺寸重画 */
        fun render(context: Context, manager: AppWidgetManager, id: Int) {
            val tier = tierFor(manager, id)
            val ids = when (tier) {
                "tile" -> ID_TILE
                "tall" -> ID_TALL
                "compact" -> ID_COMPACT
                else -> ID_ROW
            }
            val views = RemoteViews(context.packageName, ids.layout)

            // 整块可点 → 打开 App（用户对桌面组件最自然的期望）
            views.setOnClickPendingIntent(R.id.aw_root, openApp(context))

            val snap = parseSnapshot(context)
            if (snap == null || !snap.optBoolean("hasData", false)) {
                val label = snap?.read("emptyLabel")
                    ?: context.getString(R.string.app_widget_weather_empty)
                showEmpty(views, ids, label)
                manager.updateAppWidget(id, views)
                return
            }

            val small = tier == "compact" || tier == "row"
            val bgTable = if (small) BG_SMALL_BY_KIND else BG_BY_KIND
            views.setInt(
                R.id.aw_root, "setBackgroundResource",
                bgTable[snap.optString("kind")] ?: R.drawable.aw_bg_cloudy,
            )

            views.setViewVisibility(ids.pad, View.VISIBLE)
            views.setViewVisibility(ids.empty, View.GONE)

            showHeader(views, ids, snap)
            showHero(views, ids, snap)
            showMetrics(views, ids, snap)
            showTips(views, ids, snap, tier)

            manager.updateAppWidget(id, views)
        }

        // ── 各区块填充 ────────────────────────────────────────────

        private fun showHeader(views: RemoteViews, ids: Ids, snap: JSONObject) {
            val header = snap.optJSONObject("header")
            if (ids.city != 0) {
                views.setTextViewText(ids.city, header.read("city"))
            }
            if (ids.observed != 0) {
                views.setTextViewText(ids.observed, header.read("observed"))
            }
            if (ids.aqiPill == 0) return

            val aqi = header.read("aqi")
            if (aqi.isEmpty()) {
                views.setViewVisibility(ids.aqiPill, View.GONE)
                return
            }
            views.setViewVisibility(ids.aqiPill, View.VISIBLE)
            val aqiLabel = header.read("aqiLabel")
            views.setTextViewText(
                ids.aqiText,
                if (aqiLabel.isEmpty()) "AQI $aqi" else "AQI $aqi $aqiLabel",
            )
            // 国标等级色（优→绿 … 严重污染→褐红），色值由 Dart 侧算好。
            // 圆点是 ImageView → setColorFilter 可用（这是 ImageView 独有的方法）。
            val color = header.optInt("aqiColor", 0)
            if (color != 0 && ids.aqiDot != 0) {
                views.setInt(ids.aqiDot, "setColorFilter", color)
            }
        }

        private fun showHero(views: RemoteViews, ids: Ids, snap: JSONObject) {
            val hero = snap.optJSONObject("hero")
            if (ids.heroIcon != 0) {
                // 天气主图标用 26dp 的大图；名字由 Dart 给（与面板 Icons 同源）
                views.setImageViewResource(
                    ids.heroIcon, WidgetIcons.big(hero.read("iconName")),
                )
            }
            if (ids.temp != 0) views.setTextViewText(ids.temp, hero.read("temp"))
            if (ids.cond != 0) views.setTextViewText(ids.cond, hero.read("cond"))
            if (ids.range != 0) views.setTextViewText(ids.range, hero.read("range"))
        }

        private fun showMetrics(views: RemoteViews, ids: Ids, snap: JSONObject) {
            val metrics: JSONArray? = snap.optJSONArray("metrics")
            val count = metrics?.length() ?: 0
            for (i in ids.metricValues.indices) {
                // 指标项数少于布局格子数时把多余的格子藏掉，否则会留空白
                if (i < ids.metricBoxes.size) {
                    views.setViewVisibility(
                        ids.metricBoxes[i],
                        if (i < count) View.VISIBLE else View.GONE,
                    )
                }
                val m = metrics?.optJSONObject(i)
                views.setTextViewText(ids.metricValues[i], m.read("value"))
                if (i < ids.metricLabels.size) {
                    views.setTextViewText(ids.metricLabels[i], m.read("label"))
                }
            }
        }

        /**
         * 建议区。
         *
         * 条数由**布局里声明的行数**决定（主档 2 行、竖长档 2 行、紧凑档 1 行、
         * 单行档内联 1 条）—— 也就是「写代码时就定好」；而「当前天气有哪几条、
         * 顺序如何」由 Dart 侧给好了。这样刻意的分工避免了在 Kotlin 里写业务判断。
         */
        private fun showTips(
            views: RemoteViews,
            ids: Ids,
            snap: JSONObject,
            tier: String,
        ) {
            val tips = snap.optJSONArray("tips")

            // 分组标题（仅竖长档有）
            if (ids.tipsHeader != 0) {
                views.setViewVisibility(ids.tipsHeader, View.VISIBLE)
                views.setTextViewText(ids.tipsTitle, snap.read("tipsLabel"))
                if (ids.tipsCount != 0) {
                    val total = snap.optInt("tipTotal", 0)
                    views.setTextViewText(ids.tipsCount,
                        if (total > 0) "$total" else "")
                }
            }

            for (i in ids.tipRows.indices) {
                val cell = ids.tipRows[i]
                val tip = tips?.optJSONObject(i)
                val vis = if (tip != null) View.VISIBLE else View.GONE
                if (cell.row != 0) views.setViewVisibility(cell.row, vis)
                if (tip == null) {
                    if (cell.row == 0) {
                        views.setViewVisibility(cell.dot, vis)
                        views.setViewVisibility(cell.level, vis)
                        views.setViewVisibility(cell.text, vis)
                    }
                    continue
                }

                // 提示图标与圆点都染成级别色（两者都是 ImageView）
                val color = tip.optInt("color", 0)
                if (color != 0) {
                    views.setInt(cell.dot, "setColorFilter", color)
                    views.setInt(cell.icon, "setColorFilter", color)
                    views.setTextColor(cell.level, color)
                }
                views.setImageViewResource(
                    cell.icon, WidgetIcons.small(tip.read("iconName")),
                )
                views.setTextViewText(cell.level, tip.read("levelLabel"))
                views.setTextViewText(
                    cell.text,
                    tip.read(if (ids.tipShort) "shortText" else "text"),
                )
            }
        }

        // ── 空状态与工具 ──────────────────────────────────────────

        private fun showEmpty(views: RemoteViews, ids: Ids, label: String) {
            // 直接整块换掉：隐藏内容区、只留一句占位。
            // 逐字段清空的写法看着更「温和」，但漏清一个字段就会在空状态里
            // 露出上一轮的残留数据 —— 那种界面错误比空白更容易误导人。
            views.setViewVisibility(ids.pad, View.GONE)
            views.setViewVisibility(ids.empty, View.VISIBLE)
            views.setTextViewText(ids.empty, label)
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
         * 读取并校验快照。
         *
         * 版本号不匹配时**故意**按「无数据」处理而不是硬解析：Dart 侧将来加字段
         * 或改语义时，老组件应该安静地退回占位态，而不是把错位的字段渲染出来。
         */
        private fun parseSnapshot(context: Context): JSONObject? {
            val raw = WeatherWidgetStore.load(context) ?: return null
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
