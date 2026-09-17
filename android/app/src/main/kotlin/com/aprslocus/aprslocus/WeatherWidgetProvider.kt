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
import org.json.JSONException
import org.json.JSONObject

/**
 * ─── APRSlocus 桌面小组件：4 列 × 2 行（天气 + 业余无线电提示）───
 *
 * 这个类只做一件事：把 Dart（lib/app_widget.dart）算好的快照 JSON
 * 「按字段放进对应的格子」。
 *
 * **为什么这里一条业务判断都没有**：
 * 和风密钥在 Dart（构建期 `--dart-define` 注入）、火腿建议的判定规则在 Dart、
 * 文案本地化在 Dart（`AppLocalizations`）。一旦在 Kotlin 写下
 * `if (temp > 35) …` 这类判断，就会出现「App 面板说注意、桌面组件说良好」的
 * 分叉 —— 这种 bug 极难发现，因为两处各自看都"对"。所以这里只做渲染。
 *
 * 数据来源：WeatherWidgetStore（由 WeatherWidgetBridge 在 App 侧推送时写入）。
 * 也就是说组件**不联网**、不持有密钥，只显示最后一次同步到的快照，
 * 并在顶栏显示「观测 HH:mm」让用户自行判断新鲜度。
 */
class WeatherWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        manager: AppWidgetManager,
        ids: IntArray,
    ) {
        ids.forEach { render(context, manager, it) }
    }

    /** 用户拉伸组件后重画：格子宽度变了，文字换行位置也要跟着变 */
    override fun onAppWidgetOptionsChanged(
        context: Context,
        manager: AppWidgetManager,
        id: Int,
        newOptions: Bundle?,
    ) {
        render(context, manager, id)
    }

    companion object {
        private const val TAG = "APRSWidget"

        /** ← 与 lib/app_widget.dart 的 kAppWidgetSnapshotVersion 必须一致 */
        private const val SNAPSHOT_VERSION = 1

        /**
         * 静态 id 表。
         * 不用 `resources.getIdentifier("aw_m${i}_value", ...)` —— 那样既是反射
         * （会被 R8 判定为动态引用、需要额外 keep 规则），拼错也只会在运行时
         * 静默拿到 0，属于自己给自己埋雷。
         */
        private val METRIC_EMOJI = intArrayOf(
            R.id.aw_m0_emoji, R.id.aw_m1_emoji, R.id.aw_m2_emoji,
        )
        private val METRIC_VALUE = intArrayOf(
            R.id.aw_m0_value, R.id.aw_m1_value, R.id.aw_m2_value,
        )
        private val METRIC_LABEL = intArrayOf(
            R.id.aw_m0_label, R.id.aw_m1_label, R.id.aw_m2_label,
        )
        private val TIP_BOX = intArrayOf(
            R.id.aw_tip0_box, R.id.aw_tip1_box, R.id.aw_tip2_box, R.id.aw_tip3_box,
        )
        private val TIP_EMOJI = intArrayOf(
            R.id.aw_tip0_emoji, R.id.aw_tip1_emoji, R.id.aw_tip2_emoji, R.id.aw_tip3_emoji,
        )
        private val TIP_LEVEL = intArrayOf(
            R.id.aw_tip0_level, R.id.aw_tip1_level, R.id.aw_tip2_level, R.id.aw_tip3_level,
        )
        private val TIP_TEXT = intArrayOf(
            R.id.aw_tip0_text, R.id.aw_tip1_text, R.id.aw_tip2_text, R.id.aw_tip3_text,
        )

        /** 天气档位 → 背景渐变（深色版本由 drawable-night/ 自动接管） */
        private val BG_BY_KIND = mapOf(
            "clear" to R.drawable.aw_bg_clear,
            "cloudy" to R.drawable.aw_bg_cloudy,
            "overcast" to R.drawable.aw_bg_overcast,
            "rain" to R.drawable.aw_bg_rain,
            "storm" to R.drawable.aw_bg_storm,
            "snow" to R.drawable.aw_bg_snow,
            "fog" to R.drawable.aw_bg_fog,
        )

        /**
         * 刷新所有已添加的组件实例。
         * App 侧推送新快照后由 WeatherWidgetBridge 调用；也用于 clear。
         */
        fun refreshAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context) ?: return
            val ids = manager.getAppWidgetIds(
                ComponentName(context, WeatherWidgetProvider::class.java)
            )
            ids.forEach { render(context, manager, it) }
        }

        /** 把一个组件实例按当前快照重画 */
        fun render(context: Context, manager: AppWidgetManager, id: Int) {
            val views = RemoteViews(context.packageName, R.layout.aprslocus_weather_widget)

            // 整块可点 → 打开 App。这是用户对桌面组件最自然的期望
            views.setOnClickPendingIntent(R.id.aw_root, openApp(context))

            val snap = parseSnapshot(context)
            if (snap == null) {
                // 从没同步过，或快照版本不认识（例如先装了新版组件、又回滚了 App）
                showEmpty(views, context.getString(R.string.app_widget_weather_empty))
                manager.updateAppWidget(id, views)
                return
            }

            views.setInt(
                R.id.aw_root,
                "setBackgroundResource",
                BG_BY_KIND[snap.optString("kind")] ?: R.drawable.aw_bg_cloudy,
            )

            if (!snap.optBoolean("hasData", false)) {
                showEmpty(views, snap.read("emptyLabel"))
                manager.updateAppWidget(id, views)
                return
            }

            views.setViewVisibility(R.id.aw_body, View.VISIBLE)
            views.setViewVisibility(R.id.aw_empty, View.GONE)

            // ── 顶栏：城市 · AQI 胶囊 · 观测时刻 ──
            val header = snap.optJSONObject("header")
            views.setTextViewText(R.id.aw_city, header.read("city"))

            val aqi = header.read("aqi")
            if (aqi.isEmpty()) {
                views.setViewVisibility(R.id.aw_aqi, View.GONE)
            } else {
                views.setViewVisibility(R.id.aw_aqi, View.VISIBLE)
                val aqiLabel = header.read("aqiLabel")
                views.setTextViewText(
                    R.id.aw_aqi,
                    if (aqiLabel.isEmpty()) "AQI $aqi" else "AQI $aqi $aqiLabel",
                )
                // 国标等级色（优→绿 … 严重污染→褐红），色值由 Dart 侧算好
                val aqiColor = header.optInt("aqiColor", 0)
                if (aqiColor != 0) views.setTextColor(R.id.aw_aqi, aqiColor)
            }
            views.setTextViewText(R.id.aw_observed, header.read("observed"))

            // ── 第 1 行：天气主格 + 3 个指标格 ──
            val hero = snap.optJSONObject("hero")
            views.setTextViewText(R.id.aw_hero_emoji, hero.read("emoji"))
            views.setTextViewText(R.id.aw_hero_temp, hero.read("temp"))
            views.setTextViewText(R.id.aw_hero_sub, hero.read("sub"))

            val metrics = snap.optJSONArray("metrics")
            for (i in METRIC_VALUE.indices) {
                val m = metrics?.optJSONObject(i)
                views.setTextViewText(METRIC_EMOJI[i], m.read("emoji"))
                views.setTextViewText(METRIC_VALUE[i], m.read("value"))
                views.setTextViewText(METRIC_LABEL[i], m.read("label"))
            }

            // ── 第 2 行：业余无线电提示 ×4 ──
            val tips = snap.optJSONArray("tips")
            for (i in TIP_BOX.indices) {
                val tip = tips?.optJSONObject(i)
                if (tip == null) {
                    // 当前天气没有那么多条建议：整格收起，而不是留一个空格子
                    views.setViewVisibility(TIP_BOX[i], View.GONE)
                    continue
                }
                views.setViewVisibility(TIP_BOX[i], View.VISIBLE)
                views.setTextViewText(TIP_EMOJI[i], tip.read("emoji"))
                views.setTextViewText(TIP_LEVEL[i], tip.read("levelLabel"))
                views.setTextViewText(TIP_TEXT[i], tip.read("text"))

                val color = tip.optInt("color", 0)
                if (color != 0) views.setTextColor(TIP_LEVEL[i], color)

                // 危险级换一张红底。RemoteViews 不支持 <selector>，
                // 所以这里换的是 drawable 而不是「状态」。
                val isDanger = tip.optString("level") == "danger"
                views.setInt(
                    TIP_BOX[i],
                    "setBackgroundResource",
                    if (isDanger) R.drawable.aw_tile_danger else R.drawable.aw_tile,
                )
            }

            manager.updateAppWidget(id, views)
        }

        // ── 内部工具 ────────────────────────────────────────────────

        private fun showEmpty(views: RemoteViews, label: String) {
            views.setViewVisibility(R.id.aw_body, View.GONE)
            views.setViewVisibility(R.id.aw_empty, View.VISIBLE)
            views.setViewVisibility(R.id.aw_aqi, View.GONE)
            views.setTextViewText(R.id.aw_city, "")
            views.setTextViewText(R.id.aw_observed, "")
            views.setTextViewText(R.id.aw_empty, label)
        }

        private fun openApp(context: Context): PendingIntent {
            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            return PendingIntent.getActivity(
                context,
                0,
                intent,
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
 * AppWidgetProvider 里未捕获的异常会直接让组件变成「加载中」白块，
 * 而且用户没有任何自救途径（不能重装、只能删掉重加）。
 */
private fun JSONObject?.read(key: String): String {
    if (this == null || !has(key) || isNull(key)) return ""
    return optString(key, "")
}
