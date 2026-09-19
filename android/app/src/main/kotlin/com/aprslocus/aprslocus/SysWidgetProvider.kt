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
 * ─── 桌面小组件：系统状态（4×2）───
 *
 * 回答三个问题：**还在收吗 / 我的位置有没有上报 / 为什么地图没台站**。
 * 数据由 Dart 侧（lib/sys_widget.dart）算好、本地化后推过来 ——
 * 本类不持有任何业务判断，也不联网。
 *
 * **链路三态**（`未启用` / `已连接` / `已启用未连上`）：这是本组件唯一比
 * 「连上/没连上」多出来的信息，而它很关键 —— 「未启用」用户不用管，
 * 「连不上」要去查。原生侧只按 Dart 给的颜色设色点，不自己判态。
 *
 * ⚠ 与其它组件同一套 RemoteViews 约束：
 *   ① 只用白名单控件（FrameLayout / LinearLayout / TextView / ImageView）——
 *      **不能用原生 `<View>`**。
 *   ② 不能用 `<selector>` / ripple 当背景。
 *   ③ 不能用 styles.xml 主题样式；颜色引用 `@color/aw_*`，
 *      夜间由 `values-night/` 自动切换（这是暗黑模式的关键）。
 *   ④ 状态点是 `ImageView`，所以 `setColorFilter` 可用（它只存在于 ImageView）。
 */
class SysWidgetProvider : AppWidgetProvider() {

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
        private const val TAG = "APRSSysWidget"

        /** ← 与 lib/sys_widget.dart 的 kSysWidgetSnapshotVersion 必须一致 */
        private const val SNAPSHOT_VERSION = 1

        /**
         * 够用「加高档」布局的最小高度（dp）。
         *
         * **为什么用 dp 而不是「几格」**：格子数是按 (74 × n − 16) 的**标称**公式
         * 反推的，而实际每格多高随启动器与屏幕差很多 —— 用它判档时，4×2 在部分
         * 启动器上被算成 3 格，直接套上了加高布局而溢出，表现就是「4×2 坏了」。
         * 而加高布局放不放得下本来就是个 **dp 事实**（本组件内容 215dp），
         * 所以直接比 dp 才成立。
         *
         * 240dp：给加高布局的 215dp 留足余量，也正好与短波组件同一个门槛
         * （两处取同一个数，是为了「拉一样高、都换档」这种行为一致）。
         * 3 格标称约 206dp → 仍用标准档（内容 138dp，放得下）。
         * 4 格标称约 280dp → 换加高档。
         */
        private const val TALL_MIN_HEIGHT_DP = 240

        /**
         * 高度是否够用「加高档」布局。
         *
         * 用 OPTION_APPWIDGET_MIN_HEIGHT：用户拖动后系统会把它更新为当前尺寸，
         * 所以它既表示「现在多高」，也正好是我们要判的那个量。
         */
        private fun isTall(manager: AppWidgetManager, id: Int): Boolean {
            val opt = manager.getAppWidgetOptions(id) ?: Bundle()
            val dp = opt.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0)
            return dp >= TALL_MIN_HEIGHT_DP
        }

        /** 链路格数（与 aw_widget_sys.xml 一致） */
        private const val LINK_CELLS = 4

        /** 每格链路：(容器, 状态点, 名称, 状态文字) */
        private val LINK_IDS = arrayOf(
            intArrayOf(R.id.aw_link0, R.id.aw_link0_dot, R.id.aw_link0_name,
                R.id.aw_link0_state),
            intArrayOf(R.id.aw_link1, R.id.aw_link1_dot, R.id.aw_link1_name,
                R.id.aw_link1_state),
            intArrayOf(R.id.aw_link2, R.id.aw_link2_dot, R.id.aw_link2_name,
                R.id.aw_link2_state),
            intArrayOf(R.id.aw_link3, R.id.aw_link3_dot, R.id.aw_link3_name,
                R.id.aw_link3_state),
        )

        fun refreshAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context) ?: return
            val ids = manager.getAppWidgetIds(
                ComponentName(context, SysWidgetProvider::class.java)
            )
            ids.forEach { render(context, manager, it) }
        }

        fun render(context: Context, manager: AppWidgetManager, id: Int) {
            // 两档布局**共用同一套 id**，只有 dp 值不同 —— 所以这里
            // 只换 layout 资源，下面的 ResId 表两档通用。
            val layout = if (isTall(manager, id)) {
                R.layout.aw_widget_sys_tall
            } else {
                R.layout.aw_widget_sys
            }
            val views = RemoteViews(context.packageName, layout)
            views.setOnClickPendingIntent(R.id.aw_root, openApp(context))

            val snap = parseSnapshot(context)
            if (snap == null) {
                views.setViewVisibility(R.id.aw_pad, View.GONE)
                views.setViewVisibility(R.id.aw_empty, View.VISIBLE)
                views.setTextViewText(
                    R.id.aw_empty, context.getString(R.string.app_widget_sys_empty),
                )
                manager.updateAppWidget(id, views)
                return
            }

            views.setViewVisibility(R.id.aw_pad, View.VISIBLE)
            views.setViewVisibility(R.id.aw_empty, View.GONE)
            views.setTextViewText(R.id.aw_sys_title, snap.read("title"))
            views.setTextViewText(R.id.aw_my_call, snap.read("call"))
            views.setTextViewText(R.id.aw_fix_state, snap.read("fixState"))
            views.setTextViewText(R.id.aw_my_grid, snap.read("grid"))
            views.setTextViewText(R.id.aw_rx, snap.read("rx"))
            views.setTextViewText(R.id.aw_tx, snap.read("tx"))
            views.setTextViewText(R.id.aw_beacon, snap.read("beacon"))
            views.setTextViewText(R.id.aw_stations, snap.read("stations"))

            // 最近收到的台站：比「收 N」更直接地回答「还在收吗」。
            // 没有台站时整行收起，而不是留一个「最近收到 · 」的空壳 ——
            // 空壳会让人以为组件坏了，而真相只是「确实还没收到」。
            val recentCall = snap.read("recentCall")
            val hasRecent = recentCall.isNotEmpty()
            views.setViewVisibility(
                R.id.aw_recent,
                if (hasRecent) View.VISIBLE else View.GONE,
            )
            if (hasRecent) {
                views.setTextViewText(R.id.aw_recent_label, snap.read("recentLabel"))
                views.setTextViewText(R.id.aw_recent_call, recentCall)
                views.setTextViewText(R.id.aw_recent_ago, snap.read("recentAgo"))
            }

            // 四条链路：点色由 Dart 给（三态三色），文字是已本地化的状态
            val links = snap.optJSONArray("links")
            for (i in 0 until LINK_CELLS) {
                val cell = links?.optJSONObject(i)
                val v = if (cell == null) View.GONE else View.VISIBLE
                views.setViewVisibility(LINK_IDS[i][0], v)
                if (cell == null) continue
                views.setTextViewText(LINK_IDS[i][2], cell.read("name"))
                views.setTextViewText(LINK_IDS[i][3], cell.read("state"))
                val color = cell.optInt("color", 0)
                if (color != 0) {
                    // 状态点是 ImageView → setColorFilter 可用
                    views.setInt(LINK_IDS[i][1], "setColorFilter", color)
                }
            }

            manager.updateAppWidget(id, views)
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
            val raw = SysWidgetStore.load(context) ?: return null
            val obj = try {
                JSONObject(raw)
            } catch (e: JSONException) {
                Log.w(TAG, "快照 JSON 解析失败，按无数据处理", e)
                return null
            }
            if (obj.optInt("v", -1) != SNAPSHOT_VERSION) {
                Log.w(TAG, "快照版本不匹配，按无数据处理")
                return null
            }
            return obj
        }
    }
}
