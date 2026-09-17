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
 * 逐波段给出**日间 / 夜间**传播条件，以及 SFI / Kp / A 三个汇总指数。
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

        /** 汇总指数个数（SFI / Kp / A） */
        private const val SUM_CELLS = 3

        /** ← 与 lib/hf_widget.dart 的 kHfWidgetSnapshotVersion 必须一致 */
        private const val SNAPSHOT_VERSION = 1

        /** 汇总格：每格是 (label, value) */
        private val SUM_LABEL = intArrayOf(
            R.id.aw_sum0_label, R.id.aw_sum1_label, R.id.aw_sum2_label,
        )
        private val SUM_VALUE = intArrayOf(
            R.id.aw_sum0_value, R.id.aw_sum1_value, R.id.aw_sum2_value,
        )

        /** 波段行：每行是 (name, dayDot, dayLabel, nightDot, nightLabel) */
        private val BAND_IDS = arrayOf(
            intArrayOf(R.id.aw_band0_name, R.id.aw_band0_day_dot,
                R.id.aw_band0_day, R.id.aw_band0_night_dot, R.id.aw_band0_night),
            intArrayOf(R.id.aw_band1_name, R.id.aw_band1_day_dot,
                R.id.aw_band1_day, R.id.aw_band1_night_dot, R.id.aw_band1_night),
            intArrayOf(R.id.aw_band2_name, R.id.aw_band2_day_dot,
                R.id.aw_band2_day, R.id.aw_band2_night_dot, R.id.aw_band2_night),
            intArrayOf(R.id.aw_band3_name, R.id.aw_band3_day_dot,
                R.id.aw_band3_day, R.id.aw_band3_night_dot, R.id.aw_band3_night),
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
            // 白底版把「日 ｜ 夜」图例并进了汇总行右端（单独开一行表头要 13.3dp，
            // 而可用高度只有 130dp），所以这里没有表头要填。
            views.setTextViewText(R.id.aw_legend, snap.read("legend"))

            // 汇总：SFI / Kp / A。颜色由 Dart 侧按阈值算好（Kp/A 越大越差）
            val sum = snap.optJSONArray("summary")
            for (i in 0 until SUM_CELLS) {
                val cell = sum?.optJSONObject(i)
                views.setTextViewText(SUM_LABEL[i], cell.read("label"))
                views.setTextViewText(SUM_VALUE[i], cell.read("value"))
                // `cell` 是 JSONObject?：`optInt` 不像我那个 read 扩展那样
                // 能挂在可空接收者上，必须写 `cell?.optInt(...) ?: 0`
                val color = cell?.optInt("color", 0) ?: 0
                if (color != 0) views.setTextColor(SUM_VALUE[i], color)
            }

            // 逐波段：日间 / 夜间
            val bands = snap.optJSONArray("bands")
            for (i in 0 until BAND_ROWS) {
                val row = bands?.optJSONObject(i)
                val vis = if (row != null) View.VISIBLE else View.GONE
                views.setViewVisibility(BAND_ROWS_ID[i], vis)
                if (row == null) continue
                fillBand(views, BAND_IDS[i], row)
            }

            manager.updateAppWidget(id, views)
        }

        /** 填一行波段：圆点与文字都按条件色着色 */
        private fun fillBand(views: RemoteViews, ids: IntArray, band: JSONObject) {
            views.setTextViewText(ids[0], band.read("name"))
            paint(views, ids[1], ids[2], band, "day")
            paint(views, ids[3], ids[4], band, "night")
        }

        /** 圆点换色（ImageView → setColorFilter）+ 条件文字同色 */
        private fun paint(
            views: RemoteViews,
            dot: Int,
            label: Int,
            band: JSONObject,
            prefix: String,
        ) {
            views.setTextViewText(label, band.read("${prefix}Label"))
            val color = band.optInt("${prefix}Color", 0)
            if (color != 0) {
                views.setInt(dot, "setColorFilter", color)
                views.setTextColor(label, color)
            }
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
