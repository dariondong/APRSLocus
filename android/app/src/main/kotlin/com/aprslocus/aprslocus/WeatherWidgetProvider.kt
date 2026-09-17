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
 * ─── APRSLocus 桌面小组件（4 个尺寸档）───
 *
 * 只做三件事：**选布局 → 填字段 → 按可用空间决定显示多少**。
 *
 * | 档位 | 格子 | 布局 | 内容 |
 * |---|---|---|---|
 * | compact | 2×2 / 2×3 | aw_widget_compact | 温度 + 天气 + 1 条最要紧的提示 |
 * | row | 3~4×1 | aw_widget_row | 单行：温度 + 天气 + 高低温 + 提示 |
 * | tall | 2×4 | aw_widget_tall | 「小面板」：温度 + 指标 + 堆叠提示（最像 App 面板）|
 * | tile | 3~4×2 | aw_widget_tile | 「主面板」：左温度 / 右指标 / 底 2 条提示 |
 *
 * **为什么这里一条业务判断都没有**：
 * 和风密钥在 Dart（构建期 `--dart-define` 注入）、火腿建议的判定规则在 Dart、
 * 文案本地化在 Dart（`AppLocalizations`）。一旦在 Kotlin 写下 `if (temp > 35)`，
 * 就会出现「App 面板说注意、桌面组件说良好」的分叉 —— 这种 bug 极难发现，
 * 因为两处各自看都"对"。所以这里只做渲染与**排版层**的取舍。
 *
 * 「排版层的取舍」具体指：显示几条提示、用哪一档长度的文案 —— 这些取决于
 * 用户把组件拉成多大，只有原生侧知道尺寸，所以在这里决定。但**每条选什么
 * 内容**（哪条提示、哪种说法）已经在 Dart 侧算好并按优先级排好，这里只是
 * 「从前往后取 n 条」「从长到短挑第一个放得下的」。
 *
 * **不联网、不持有密钥**：数据来自 WeatherWidgetStore（App 侧推送时写入），
 * 顶栏显示「观测 HH:mm」让用户自行判断数据新鲜度。
 *
 * ⚠ 三条 RemoteViews 铁律（违反其一就是运行时白块，而编译期全绿）：
 *   ① 只能用白名单控件 —— 尤其是**不能用原生 `<View>`**（撑宽度要用 0dp 的
 *      TextView）。布局由 tool/gen_app_widget_layouts.py 生成并自检。
 *   ② 不能用 `<selector>` / ripple 当背景，要用「换 drawable」代替状态选择。
 *   ③ `setInt(viewId, "方法名", …)` 的方法是**字符串**，写错编译不报错、
 *      运行时才在系统进程里抛。所以字符串方法名全部集中在本文件，
 *      并由 tool/check_android_res_ids.py 按白名单核对。
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
     * 一条堆叠提示要填的 5 个 ResId。
     * [row] / [dot] / [level] 为 0 表示该档布局里没有这个控件，跳过即可
     * （单行档没有独立圆点级别行；紧凑档没有圆点级别行）。
     */
    private class TipRow(
        val row: Int,
        val dot: Int,
        val emoji: Int,
        val level: Int,
        val text: Int,
    )

    /** 一个尺寸档要用到的全部 ResId */
    private class Ids(
        val layout: Int,
        val content: Int,
        val empty: Int,
        val city: Int = 0,
        val aqi: Int = 0,
        val observed: Int = 0,
        val emoji: Int = 0,
        val temp: Int = 0,
        val cond: Int = 0,
        val range: Int = 0,
        val metricValues: IntArray = IntArray(0),
        val metricLabels: IntArray = IntArray(0),
        /** 指标格的容器（aw_m0…aw_m3）。指标不足 4 项时要把多出来的格子藏掉，
         *  否则会在网格里留下空白块 —— 看起来像渲染出错。 */
        val metricBoxes: IntArray = IntArray(0),
        val tipRows: Array<TipRow> = emptyArray(),
        val tipsBlock: Int = 0,
        val tipsHeader: Int = 0,
        val tipsCount: Int = 0,
        val tipCompact: TipRow? = null,
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
            content = R.id.aw_pad,
            empty = R.id.aw_empty,
            city = R.id.aw_city,
            aqi = R.id.aw_aqi,
            observed = R.id.aw_observed,
            emoji = R.id.aw_b_emoji,
            temp = R.id.aw_b_temp,
            cond = R.id.aw_b_cond,
            range = R.id.aw_b_range,
            metricValues = intArrayOf(
                R.id.aw_m0_value, R.id.aw_m1_value,
                R.id.aw_m2_value, R.id.aw_m3_value,
            ),
            metricLabels = intArrayOf(
                R.id.aw_m0_label, R.id.aw_m1_label,
                R.id.aw_m2_label, R.id.aw_m3_label,
            ),
            metricBoxes = intArrayOf(
                R.id.aw_m0, R.id.aw_m1, R.id.aw_m2, R.id.aw_m3,
            ),
            tipRows = arrayOf(
                TipRow(R.id.aw_tip0, R.id.aw_tip0_dot, R.id.aw_tip0_emoji,
                    R.id.aw_tip0_level, R.id.aw_tip0_text),
                TipRow(R.id.aw_tip1, R.id.aw_tip1_dot, R.id.aw_tip1_emoji,
                    R.id.aw_tip1_level, R.id.aw_tip1_text),
            ),
            tipsBlock = R.id.aw_tips,
            tipCompact = TipRow(R.id.aw_tip_compact, 0, R.id.aw_tipc_emoji, 0,
                R.id.aw_tipc_text),
        )

        private val ID_TALL = Ids(
            layout = R.layout.aw_widget_tall,
            content = R.id.aw_pad,
            empty = R.id.aw_empty,
            city = R.id.aw_city,
            aqi = R.id.aw_aqi,
            observed = R.id.aw_observed,
            emoji = R.id.aw_t_emoji,
            temp = R.id.aw_t_temp,
            cond = R.id.aw_cond,
            range = R.id.aw_range,
            metricValues = intArrayOf(
                R.id.aw_m0_value, R.id.aw_m1_value,
                R.id.aw_m2_value, R.id.aw_m3_value,
            ),
            metricLabels = intArrayOf(
                R.id.aw_m0_label, R.id.aw_m1_label,
                R.id.aw_m2_label, R.id.aw_m3_label,
            ),
            metricBoxes = intArrayOf(
                R.id.aw_m0, R.id.aw_m1, R.id.aw_m2, R.id.aw_m3,
            ),
            tipRows = arrayOf(
                TipRow(R.id.aw_tip0, R.id.aw_tip0_dot, R.id.aw_tip0_emoji,
                    R.id.aw_tip0_level, R.id.aw_tip0_text),
                TipRow(R.id.aw_tip1, R.id.aw_tip1_dot, R.id.aw_tip1_emoji,
                    R.id.aw_tip1_level, R.id.aw_tip1_text),
                TipRow(R.id.aw_tip2, R.id.aw_tip2_dot, R.id.aw_tip2_emoji,
                    R.id.aw_tip2_level, R.id.aw_tip2_text),
                TipRow(R.id.aw_tip3, R.id.aw_tip3_dot, R.id.aw_tip3_emoji,
                    R.id.aw_tip3_level, R.id.aw_tip3_text),
                TipRow(R.id.aw_tip4, R.id.aw_tip4_dot, R.id.aw_tip4_emoji,
                    R.id.aw_tip4_level, R.id.aw_tip4_text),
            ),
            tipsBlock = R.id.aw_tips,
            tipsHeader = R.id.aw_tips_header,
            tipsCount = R.id.aw_tips_count,
            tipCompact = TipRow(R.id.aw_tip_compact, 0, R.id.aw_tipc_emoji, 0,
                R.id.aw_tipc_text),
        )

        private val ID_COMPACT = Ids(
            layout = R.layout.aw_widget_compact,
            content = R.id.aw_pad,
            empty = R.id.aw_empty,
            city = R.id.aw_city,
            aqi = R.id.aw_aqi,
            observed = R.id.aw_observed,
            emoji = R.id.aw_c_emoji,
            temp = R.id.aw_c_temp,
            cond = R.id.aw_cond,
            range = R.id.aw_range,
            // 紧凑档没有指标格：2×2 里再塞 4 格指标，温度和提示就没地方了，
            // 那正是上一版「挤」的做法。
            tipRows = arrayOf(
                TipRow(R.id.aw_tips, R.id.aw_tip0_dot, 0, 0, R.id.aw_tip0_text),
            ),
        )

        private val ID_ROW = Ids(
            layout = R.layout.aw_widget_row,
            content = R.id.aw_pad,
            empty = R.id.aw_empty,
            emoji = R.id.aw_emoji,
            temp = R.id.aw_temp,
            cond = R.id.aw_cond,
            range = R.id.aw_range,
            // 单行档的提示直接挂在 aw_pad 下，没有行容器（row = 0）
            tipRows = arrayOf(
                TipRow(0, R.id.aw_tip0_dot, 0, 0, R.id.aw_tip0_text),
            ),
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
         *  - 宽度 ≥ 3 且高度 ≥ 2 → 主面板（tile），只有它放得下「左温度右指标」
         *  - 高度 ≥ 3 → 竖长档（tall），提示能堆叠
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

            showContent(views, ids)
            showHeader(views, ids, snap)
            showHero(views, ids, snap)
            showMetrics(views, ids, snap)
            showTips(views, ids, manager, id, snap, tier)

            manager.updateAppWidget(id, views)
        }

        // ── 各区块填充 ────────────────────────────────────────────

        private fun showContent(views: RemoteViews, ids: Ids) {
            views.setViewVisibility(ids.content, View.VISIBLE)
            views.setViewVisibility(ids.empty, View.GONE)
        }

        private fun showHeader(views: RemoteViews, ids: Ids, snap: JSONObject) {
            val header = snap.optJSONObject("header")
            if (ids.city != 0) {
                views.setTextViewText(ids.city, header.read("city"))
            }
            if (ids.observed != 0) {
                views.setTextViewText(ids.observed, header.read("observed"))
            }
            if (ids.aqi == 0) return

            val aqi = header.read("aqi")
            if (aqi.isEmpty()) {
                views.setViewVisibility(ids.aqi, View.GONE)
                return
            }
            views.setViewVisibility(ids.aqi, View.VISIBLE)
            val aqiLabel = header.read("aqiLabel")
            views.setTextViewText(
                ids.aqi,
                if (aqiLabel.isEmpty()) "AQI $aqi" else "AQI $aqi $aqiLabel",
            )
            // 国标等级色（优→绿 … 严重污染→褐红），色值由 Dart 侧算好
            val color = header.optInt("aqiColor", 0)
            if (color != 0) views.setTextColor(ids.aqi, color)
        }

        private fun showHero(views: RemoteViews, ids: Ids, snap: JSONObject) {
            val hero = snap.optJSONObject("hero")
            if (ids.emoji != 0) {
                views.setTextViewText(ids.emoji, hero.read("emoji"))
            }
            if (ids.temp != 0) {
                views.setTextViewText(ids.temp, hero.read("temp"))
            }
            if (ids.cond != 0) {
                views.setTextViewText(ids.cond, hero.read("sub"))
            }
        }

        private fun showMetrics(views: RemoteViews, ids: Ids, snap: JSONObject) {
            val metrics: JSONArray? = snap.optJSONArray("metrics")
            val count = metrics?.length() ?: 0
            for (i in ids.metricValues.indices) {
                // 指标项数少于布局格子数时，把多余的格子整块藏掉，
                // 否则网格里会留一个空白块，看起来像渲染出错
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
         * 提示区。三档策略，按「空间够不够」逐级降级：
         *
         *  ① 单行档（row）→ 唯一的选择就是单行形态。
         *  ② 其余档位但可用高度 < 2 格 → 单行形态（宁可少显示两条，
         *     也不要把 4 条压成 4 行 8sp —— 上一版就是那么挤的）。
         *  ③ 空间够 → 堆叠行（圆点 + 图标级别 + 正文），条数按布局里有的行裁剪。
         *
         * 注意判断依据是**可用空间**而不是「建议条数」：条数由天气决定，
         * 空间由用户拖动决定，二者互不相关。
         */
        private fun showTips(
            views: RemoteViews,
            ids: Ids,
            manager: AppWidgetManager,
            id: Int,
            snap: JSONObject,
            tier: String,
        ) {
            val opt = manager.getAppWidgetOptions(id) ?: Bundle()
            val rows = cells(opt, "appWidgetHeightCells",
                AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT)

            val tips = snap.optJSONArray("tips")
            val compactAvailable = ids.tipCompact != null
            val useCompact = tier == "row" || (compactAvailable && rows < 2)

            // ── 单行形态 ──
            if (useCompact) {
                val cell = ids.tipCompact
                if (cell != null) {
                    fillCompactTip(views, cell, manager, id, snap)
                } else {
                    // 单行档的提示内联在 aw_pad 里，直接用第 1 条的长版本
                    val row = ids.tipRows.firstOrNull()
                    if (row != null) {
                        fillInlineRow(views, row, tips, 0)
                    }
                }
                hideStack(views, ids)
                return
            }

            // ── 堆叠形态 ──
            if (ids.tipCompact != null) {
                views.setViewVisibility(ids.tipCompact.row, View.GONE)
            }
            if (ids.tipsHeader != 0) {
                views.setViewVisibility(ids.tipsHeader, View.VISIBLE)
                views.setTextViewText(ids.tipsHeader, snap.read("tipsLabel"))
                if (ids.tipsCount != 0) {
                    val total = snap.optInt("tipTotal", 0)
                    views.setTextViewText(ids.tipsCount,
                        if (total > 0) "$total" else "")
                }
            }
            if (ids.tipsBlock != 0) {
                views.setViewVisibility(ids.tipsBlock, View.VISIBLE)
            }

            for (i in ids.tipRows.indices) {
                fillStackRow(views, ids.tipRows[i], tips?.optJSONObject(i))
            }
        }

        /** 填一条堆叠提示行；tip 为 null 时整行收起（而不是留个空行） */
        private fun fillStackRow(views: RemoteViews, cell: TipRow, tip: JSONObject?) {
            setRowVisible(views, cell, tip != null)
            if (tip == null) return

            if (cell.emoji != 0) {
                views.setTextViewText(cell.emoji, tip.read("emoji"))
            }
            if (cell.level != 0) {
                views.setTextViewText(cell.level, tip.read("levelLabel"))
            }
            views.setTextViewText(cell.text, tip.read("text"))

            val color = tip.optInt("color", 0)
            if (color != 0 && cell.level != 0) {
                views.setTextColor(cell.level, color)
            }
            // 圆点染成级别色（drawable 是纯白圆形，靠 setColorFilter 上色）
            if (color != 0 && cell.dot != 0) {
                views.setInt(cell.dot, "setColorFilter", color)
            }
            // 危险级：整行底换成红底。RemoteViews 不支持 <selector>，
            // 所以「状态」是靠换 drawable 表达的，不是状态列表。
            val danger = tip.optString("level") == "danger"
            setRowBackground(views, cell,
                if (danger) R.drawable.aw_tile_danger else R.drawable.aw_tile)
        }

        /** 单行档内联提示：直接用第 [i] 条的长版本 */
        private fun fillInlineRow(views: RemoteViews, cell: TipRow,
                                  tips: JSONArray?, i: Int) {
            val tip = tips?.optJSONObject(i)
            setRowVisible(views, cell, tip != null)
            if (tip == null) return
            views.setTextViewText(cell.text, tip.read("text"))
            val color = tip.optInt("color", 0)
            if (color != 0 && cell.dot != 0) {
                views.setInt(cell.dot, "setColorFilter", color)
            }
        }

        /**
         * 单行形态：从 Dart 预先切好的多种长度里挑第一个放得下的。
         *
         * `compactRows[0].singles` 是「长 → 短」排列的同一句话，例如
         *   雷雨天气：请勿在室外架设/操作天线！断开天线馈线… →
         *   雷雨天气：请勿在室外架设/操作天线！ →
         *   请勿在室外架设/操作天线！ → 雷雨天气…
         * 切分规则（全角冒号 / 句末标点）是中英文文案的事，属于本地化范畴，
         * 所以切分在 Dart 做、这里只挑选。
         */
        private fun fillCompactTip(
            views: RemoteViews,
            cell: TipRow,
            manager: AppWidgetManager,
            id: Int,
            snap: JSONObject,
        ) {
            val row = snap.optJSONArray("compactRows")?.optJSONObject(0)
            if (row == null) {
                views.setViewVisibility(cell.row, View.GONE)
                return
            }
            views.setViewVisibility(cell.row, View.VISIBLE)
            if (cell.emoji != 0) {
                views.setTextViewText(cell.emoji, row.read("emoji"))
            }
            val color = row.optInt("color", 0)
            if (color != 0) {
                if (cell.level != 0) views.setTextColor(cell.level, color)
                if (cell.dot != 0) views.setInt(cell.dot, "setColorFilter", color)
            }

            val singles = row.optJSONArray("singles")
            val n = singles?.length() ?: 0
            if (n == 0) {
                views.setTextViewText(cell.text, "")
                return
            }
            // 可用宽度 → 估算能放几个字（1 汉字 ≈ 1 个字号 pt，正文 9.5sp）
            val opt = manager.getAppWidgetOptions(id) ?: Bundle()
            val cols = cells(opt, "appWidgetWidthCells",
                AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH)
            val widthDp = if (cols > 0) cols * 74 else 250
            // 减去左侧 emoji / 温度 / 天气现象占位，剩下的才是提示可用宽度
            val budget = ((widthDp - 150) / 9.5).toInt()

            var chosen = singles!!.optJSONObject(n - 1).read("text") // 兜底：最短那条
            for (i in 0 until n) {
                val cand = singles.optJSONObject(i).read("text")
                if (cand.length <= budget) {
                    chosen = cand
                    break
                }
            }
            views.setTextViewText(cell.text, chosen)
        }

        private fun hideStack(views: RemoteViews, ids: Ids) {
            if (ids.tipsBlock != 0) {
                views.setViewVisibility(ids.tipsBlock, View.GONE)
            }
            if (ids.tipsHeader != 0) {
                views.setViewVisibility(ids.tipsHeader, View.GONE)
            }
        }

        /**
         * 整行显示/隐藏。
         * 有的档位没有行容器（单行档的提示直接挂在 aw_pad 下），此时对
         * 组成该行的圆点与正文分别设可见性 —— 两者都藏掉，视觉上就是整行没了。
         */
        private fun setRowVisible(views: RemoteViews, cell: TipRow, visible: Boolean) {
            val v = if (visible) View.VISIBLE else View.GONE
            if (cell.row != 0) {
                views.setViewVisibility(cell.row, v)
                return
            }
            if (cell.dot != 0) views.setViewVisibility(cell.dot, v)
            views.setViewVisibility(cell.text, v)
        }

        private fun setRowBackground(views: RemoteViews, cell: TipRow, res: Int) {
            views.setInt(cell.row, "setBackgroundResource", res)
        }

        // ── 空状态与工具 ──────────────────────────────────────────

        private fun showEmpty(views: RemoteViews, ids: Ids, label: String) {
            // 直接整块换掉：隐藏内容区、只留一句占位。
            // 逐字段清空的写法看着更「温和」，但漏清一个字段就会在空状态里
            // 露出上一轮的残留数据 —— 那种界面错误比空白更容易误导人。
            views.setViewVisibility(ids.content, View.GONE)
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

/**
 * 从 JSONObject 安全取字符串。
 *
 * 组件宁可少显示一个字段，也不能因为某个 key 缺失/类型不符就抛异常 ——
 * AppWidgetProvider 里未捕获的异常会直接让组件变成白块，
 * 而用户没有任何自救途径（只能删掉重加）。
 */
private fun JSONObject?.read(key: String): String {
    if (this == null || !has(key) || isNull(key)) return ""
    return optString(key, "")
}
