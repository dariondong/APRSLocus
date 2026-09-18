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
import java.util.Calendar

/**
 * ─── 桌面小组件：短波 / 电离层传播（4×2）───
 *
 * 每个波段一条**日 → 夜**进度条：左段 = 日间、右段 = 夜间，各按该时段的
 * 传播条件着色；**当前时段那一段用实色 + 顶部一颗小白点**（另一段淡底），
 * 两端另有太阳 / 星光作语义标注，每行右端给出**当前时段**的档位。
 * 另有 SFI / Kp / A 三个汇总指数，指数行右端是「现在 夜间」与一个 6m 格。
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
 * **本组件的换色机制**（分两种控件，别照抄混用）：
 *   进度条段与档位块都是 **TextView** → 换底只能走 `setBackgroundResource`
 *   （View 的方法）；在这里用 `setColorFilter` 会直接抛。每个条件两张
 *   drawable：aw_seg_*（淡底）与 aw_segnow_*（实色 + 顶部小白点），
 *   由 tool/gen_app_widget_drawables.py 生成。文字色走 `setTextColor`
 *   （TextView 的成员方法，可用），取 @color/aw_q_*，夜间由资源系统给提亮版。
 *
 *   两端的太阳 / 星光图标是 **ImageView** → 它们是白色 PNG，在白底卡片上会
 *   隐形，**必须** `setColorFilter` 染色（这正是 ImageView 独有的那个方法；
 *   白天用它不算错，用在 TextView 上才是 v1.6.114 那次事故）。
 *
 * **当前时段按本机时钟现算，不读快照里烘焙的值** —— 见 render() 里的说明。
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
        /**
         * v2（2026-09-18）：从「日/夜两列文字」改为「日/夜进度条 + 当前时段游标」。
         * 必须与 lib/hf_widget.dart 的 kHfWidgetSnapshotVersion 同步升。
         */
        private const val SNAPSHOT_VERSION = 2

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

        // 波段行的 6 组 id。**按用途分行列出**，而不是「每行一个数组」——
        // 后者要靠数下标才能知道第 3 项是什么，而这里下标错了不会报错，
        // 只会把颜色填到别的控件上（还很像对的）。
        private val BAND_NAME = intArrayOf(
            R.id.aw_band0_name, R.id.aw_band1_name,
            R.id.aw_band2_name, R.id.aw_band3_name,
        )

        /** 日间段（进度条左半） */
        private val BAND_DAY = intArrayOf(
            R.id.aw_band0_day, R.id.aw_band1_day,
            R.id.aw_band2_day, R.id.aw_band3_day,
        )

        /** 夜间段（进度条右半） */
        private val BAND_NIGHT = intArrayOf(
            R.id.aw_band0_night, R.id.aw_band1_night,
            R.id.aw_band2_night, R.id.aw_band3_night,
        )

        /** 右端的「当前时段档位」块 */
        private val BAND_NOW = intArrayOf(
            R.id.aw_band0_now, R.id.aw_band1_now,
            R.id.aw_band2_now, R.id.aw_band3_now,
        )

        /** 两端的语义标注图标：日端太阳 / 夜端星光（白色 PNG，须染色） */
        private val BAND_DAY_ICON = intArrayOf(
            R.id.aw_band0_dayicon, R.id.aw_band1_dayicon,
            R.id.aw_band2_dayicon, R.id.aw_band3_dayicon,
        )
        private val BAND_NIGHT_ICON = intArrayOf(
            R.id.aw_band0_nighticon, R.id.aw_band1_nighticon,
            R.id.aw_band2_nighticon, R.id.aw_band3_nighticon,
        )

        /**
         * 条件等级 → **非当前时段**的段底 / 档位块底（aw_seg_*：淡色圆角块）。
         *
         * **为什么必须预生成、而不是运行时染色**：段是 TextView，而
         * `setColorFilter` **只存在于 ImageView**（View / TextView 都没有）——
         * v1.6.114 的线上事故正是把 setColorFilter 用在 TextView 上，
         * 抛 NoSuchMethodException → `RemoteViews.apply()` 抛 ActionException →
         * **整个组件报废**。TextView 换底只能用 `setBackgroundResource`（View 方法），
         * 所以每个条件各给一张。
         *
         * 未知等级回退到 closed（灰）而不是 0 —— 传 0 会把背景清掉，
         * 段消失、只剩一行无处可归的色块。
         */
        private val SEG_BY_LEVEL = mapOf(
            "good" to R.drawable.aw_seg_good,
            "fair" to R.drawable.aw_seg_fair,
            "poor" to R.drawable.aw_seg_poor,
            "closed" to R.drawable.aw_seg_closed,
        )

        /**
         * 条件等级 → **当前时段**那一段的底（aw_segnow_*：实色圆角块 + 顶部小白点）。
         *
         * 与 SEG_BY_LEVEL 的区别只有「实色 / 淡底」，但那正是「现在在哪一段」的
         * 主要视觉信号 —— 所以是两张表而不是加一个布尔参数表：
         * 表名本身就说明了用途，调用处不用再想「这个 true 是什么意思」。
         *
         * 小白点是烘焙在 drawable 里的（见 segnow_xml）：RemoteViews 没有绝对
         * 定位，加一个独立指示器控件既摆不到段的正中，又多一处运行期才爆的地方。
         */
        private val SEGNOW_BY_LEVEL = mapOf(
            "good" to R.drawable.aw_segnow_good,
            "fair" to R.drawable.aw_segnow_fair,
            "poor" to R.drawable.aw_segnow_poor,
            "closed" to R.drawable.aw_segnow_closed,
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

            // 标题文案由 Dart 侧本地化好（6 种语言）
            views.setTextViewText(R.id.aw_hf_title, snap.read("title"))

            // ── 当前时段：按本机时钟**现算** ──
            //
            // 组件每 30 分钟会自刷新一次，但那只是重绘**已存的快照**；用户一整天
            // 不开 App，快照里烘焙的时段就是旧的（19:00 之后还指着日间）。
            // 「一眼看出当前时段」正是这个组件要解决的问题 —— 判错时段比不显示
            // 更糟，所以这里用本机时钟实时判断。
            //
            // 阈值不写死在本类：dayFrom / dayTo 由 Dart 随快照下发，规则仍只在
            // lib/hf.dart 一处定义（本类只用不猜）。
            val hour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
            val dayFrom = snap.optInt("dayFrom", 7)
            val dayTo = snap.optInt("dayTo", 19)
            val isDay = hour >= dayFrom && hour < dayTo
            // 「现在 夜间」：前缀与时段名都由 Dart 本地化好，这里只拼接
            views.setTextViewText(
                R.id.aw_now_tag,
                "${snap.read("nowPrefix")} " +
                    snap.read(if (isDay) "dayLabel" else "nightLabel"),
            )

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
                    SEG_BY_LEVEL[key] ?: R.drawable.aw_seg_closed,
                )
                views.setTextColor(
                    R.id.aw_six,
                    context.getColor(QUALITY_COLOR[key] ?: R.color.aw_q_closed),
                )
            }

            // 逐波段：日/夜进度条 + 当前时段游标
            val bands = snap.optJSONArray("bands")
            for (i in 0 until BAND_ROWS) {
                val row = bands?.optJSONObject(i)
                val vis = if (row != null) View.VISIBLE else View.GONE
                views.setViewVisibility(BAND_ROWS_ID[i], vis)
                if (row == null) continue
                fillBand(context, views, i, row, isDay)
            }

            manager.updateAppWidget(id, views)
        }

        /**
         * 填一行波段：名字 + 两端的太阳 / 星光 + 两段进度条 + 当前档位块。
         *
         * [isDay] 决定哪一段是「现在」：那一段用实色（带小白点），另一段淡底。
         */
        private fun fillBand(
            context: Context,
            views: RemoteViews,
            row: Int,
            band: JSONObject,
            isDay: Boolean,
        ) {
            views.setTextViewText(BAND_NAME[row], band.read("name"))
            val dayLv = band.read("dayLevel")
            val nightLv = band.read("nightLevel")
            bandSeg(views, BAND_DAY[row], dayLv, isNow = isDay)
            bandSeg(views, BAND_NIGHT[row], nightLv, isNow = !isDay)

            // 两端的语义标注：太阳标日间段、星光标夜间段。
            // 它们不表达好坏，只表达「这一段是日 / 是夜」—— 所以用固定色，
            // 不跟条件色走（否则会与段的颜色抢注意力）。
            views.setInt(
                BAND_DAY_ICON[row], "setColorFilter",
                context.getColor(R.color.aw_sun),
            )
            views.setInt(
                BAND_NIGHT_ICON[row], "setColorFilter",
                context.getColor(R.color.aw_moon),
            )

            // 右端的档位块：**当前时段**的档位（文字 + 条件色）。
            // 颜色之外再给一个词 —— 不靠颜色也能读出来。
            val lv = if (isDay) dayLv else nightLv
            views.setTextViewText(
                BAND_NOW[row],
                band.read(if (isDay) "dayLabel" else "nightLabel"),
            )
            views.setInt(
                BAND_NOW[row], "setBackgroundResource",
                SEG_BY_LEVEL[lv] ?: R.drawable.aw_seg_closed,
            )
            // 文字色走**资源**而不是写死常量：夜间由资源系统自动取
            // values-night 里的提亮版本（深底上基准色偏暗），不判断 uiMode。
            views.setTextColor(
                BAND_NOW[row],
                context.getColor(QUALITY_COLOR[lv] ?: R.color.aw_q_closed),
            )
        }

        /**
         * 填一段进度条（纯色块，不显示文字）。
         *
         * [isNow] 为 true 用实色版 aw_segnow_*（drawable 里带顶部小白点），
         * 否则用淡底版 aw_seg_*。
         *
         * 换底走 `setBackgroundResource`（View 的方法，TextView 可用）；
         * **不能**用 `setColorFilter` —— 那是 ImageView 独有的（见 SEG_BY_LEVEL）。
         */
        private fun bandSeg(
            views: RemoteViews,
            target: Int,
            level: String,
            isNow: Boolean,
        ) {
            val table = if (isNow) SEGNOW_BY_LEVEL else SEG_BY_LEVEL
            val fallback =
                if (isNow) R.drawable.aw_segnow_closed else R.drawable.aw_seg_closed
            views.setInt(
                target, "setBackgroundResource",
                table[level] ?: fallback,
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
