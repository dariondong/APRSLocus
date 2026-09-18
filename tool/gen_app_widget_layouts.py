#!/usr/bin/env python3
"""生成 4 个尺寸档的桌面小组件布局 XML。

**结构照抄 App 内天气面板**（这是用户反复强调的点）：
  顶栏：左上 [城市点+城市] · 右上 [logo + APRSlocus] · 次行 [AQI 胶囊 | 观测时刻]
  主区：天气图标 + 大温度 + 天气现象/高低温（细度数符号靠 App 侧给）
  指标：label 左 / value 右（面板 `_kvPair` 的复刻），无底框，直接压渐变
  提示：圆点 + 级别图标 + 级别文字 / 正文另起一行（面板 `_tipRow` 的复刻）
  分隔：1dp 半透明白细线（面板 `_hairline`），不用 Divider（列方向宽度会塔成 0）

**图标全部是 ImageView + 已烘焙的 PNG**（tool/gen_app_widget_icons.py）：
组件进程里没有 Material 图标字体，RemoteViews 也不认字体图标/矢量图，
所以字体图标必须预渲染成位图。这样组件上的图标与面板 `Icons.xxx` 是同一套字形。

用法：
    python3 tool/gen_app_widget_layouts.py

产物（android/app/src/main/res/layout/）：
    aw_widget_tile.xml      3~4×2 「主档」
    aw_widget_tall.xml      2×4   「小面板」
    aw_widget_compact.xml   2×2 / 2×3
    aw_widget_row.xml       3~4×1 单行

⚠ 四条 RemoteViews 硬约束（违反其一都是**运行时**白块，编译期全绿）：
  ① 只用白名单控件（FrameLayout / LinearLayout / TextView / ImageView）
     —— 尤其是**不能用原生 `<View>`**；撑宽度用 0dp 的 TextView。
  ② 不能用 `<selector>` / ripple 当背景。
  ③ 不能用 styles.xml 的主题样式，字号颜色全部就地写死。
  ④ `setInt(viewId, "方法名", …)` 的方法名是字符串，只在运行时才炸。
     所有字符串方法名集中写在 WeatherWidgetProvider，由
     tool/check_android_res_ids.py 按「控件类型」核对。

设计稿见 tool/preview_app_widget.py（会渲染成 PNG，并硬性报「内容放不下」）。
"""

import os
import re
import sys
import xml.etree.ElementTree as ET

# ── 尺寸令牌：四档共用，改字号只改这里 ──────────────────────────────
# 参照面板（正文 12.5sp / 温度 58sp / 度数 24sp）按可用空间等比缩小。
# 4×2：两条建议各 **1 行**（用 Dart 预切好的 shortText 完整短句）。
# 原来 2 行 + 1 行实测超 16.7dp（预览修好计量后量出来的）。
TILE = dict(temp="30sp", icon="25dp", cond="9.5sp", range="9sp",
            kv_label="9sp", kv_value="10sp", tip="9.5sp", tip_level="8.5sp",
            tip_icon="11dp", dot="6dp", tips=2, tip_lines=1)
TALL = dict(temp="32sp", icon="26dp", cond="10sp", range="9sp",
            kv_label="9sp", kv_value="10sp", tip="9.5sp", tip_level="8.5sp",
            tip_icon="11dp", dot="6dp", tips=2, tip_lines=2)
# 2×2：建议 2 行（原 3 行，超 1.1dp）。这条建议是紧凑档唯一的内容点，
# 所以不是砍它，而是让它少折一行。
COMPACT = dict(temp="25sp", icon="21dp", cond="9sp", range="8.5sp",
               kv_label="8.5sp", kv_value="9.5sp", tip="8.5sp", tip_level="8sp",
               tip_icon="11dp", dot="6dp", tips=1, tip_lines=2)


# ── 短波组件（白底）用的前景色。取自 theme.dart 的 C.* 浅色值，
#    与面板本身的浅色 UI 一致。
# 为什么是 @color 而不是字面色值：RemoteViews 的布局是**静态引用**
# （initialLayout / RemoteViews(pkg, id)），没法按主题换布局文件 ——
# 所以颜色必须写成可解析的资源，夜间模式才能自动切到 values-night 的值。
# 对应 theme.dart 的 C.ink / C.slate / C.border。
INK = "@color/aw_ink"  # 主文字
# 色带格左内边距：把档位文字推离左端 2.5dp 色标（色标贴在格子的最左边）
TRACK_PAD_START = "8dp"
TRACK_PAD_END = "5dp"
# 色带格高度。20dp 是量出来的：4 行 × 20 + 列头 13 + 指数行 18 + 细线 10
# + 顶栏 21 + 上下内边距 17 ≈ 159dp，正好填满 4×2 的可用高度（130dp 是
# 卡片高度减去圆角净空，实际内容区约 160dp）而不溢出。
TRACK_H = "20dp"
# 波段名列宽：46dp 够放 "12m/10m"（9.5sp 加粗），比旧版 54dp 窄 ——
# 省下的横向空间给色带，免得色带右端离卡片边缘太远、显得内容偏左。
BAND_W = "46dp"
SLATE = "@color/aw_slate"  # 次要文字
LINE = "@color/aw_line"  # 细分隔线

CITY = "10.5sp"
APP_NAME = "11sp"
OBSERVED = "8.5sp"
AQI = "8.5sp"
TITLE = "9.5sp"
HAIRLINE = "#1AFFFFFF"     # 白 10%

ALLOWED_TAGS = {"FrameLayout", "LinearLayout", "TextView", "ImageView"}


def header_comment(title, lines):
    body = "\n".join(f"  {l}" for l in lines)
    return f"<!--\n  {title}\n\n{body}\n-->\n"


def open_layout(root_id, bg):
    return (
        '<FrameLayout xmlns:android="http://schemas.android.com/apk/res/android"\n'
        f'    android:id="@+id/{root_id}"\n'
        '    android:layout_width="match_parent"\n'
        '    android:layout_height="match_parent"\n'
        f'    android:background="@drawable/{bg}">\n'
    )


def text(tid, *, size, color=INK, bold=False, max_lines=None,
         ellipsize=False, gravity=None, spacing=None, pad_h=None, pad_v=None,
         pad_start=None, pad_end=None,
         min_width=None,
         width="wrap_content", height="wrap_content", weight=None,
         margin_end=None, margin_start=None, margin_top=None,
         max_width=None, visibility=None, line_mult=None, alpha=None,
         bg=None, android_text=None):
    a = [f'android:id="@+id/{tid}"',
         f'android:layout_width="{width}"',
         f'android:layout_height="{height}"']
    for k, v in (("layout_weight", weight), ("layout_marginEnd", margin_end),
                 ("layout_marginStart", margin_start),
                 ("layout_marginTop", margin_top), ("gravity", gravity)):
        if v:
            a.append(f'android:{k}="{v}"')
    if bg:
        a.append(f'android:background="@drawable/{bg}"')
    a.append(f'android:textColor="{color}"')
    if alpha is not None and not color.startswith('@'):
        # RemoteViews 不能给单个 view 设 alpha；用带 alpha 的 #AARRGGBB 文字色
        # 表达「弱化」层级（面板也是靠白色 + 低 alpha，不是灰色）。
        #
        # 但 `@color/xxx` 引用**拼不了** alpha —— 上一版就是漏了这个判断，
        # 生成出 `#E6@COLOR/AW_INK_DIM` 这种畸形值（不报错、颜色全错）。
        # 需要「@color + alpha」时，请另建一个已含 alpha 的颜色资源
        # （如 aw_ink_dim）。
        a[-1] = f'android:textColor="{_with_alpha(color, alpha)}"'
    a.append(f'android:textSize="{size}"')
    if android_text is not None:
        a.append(f'android:text="{android_text}"')
    if bold:
        a.append('android:textStyle="bold"')
    if spacing:
        a.append(f'android:letterSpacing="{spacing}"')
    if max_width:
        a.append(f'android:maxWidth="{max_width}"')
    if min_width:
        a.append(f'android:minWidth="{min_width}"')
    if max_lines is not None:
        a.append(f'android:maxLines="{max_lines}"')
    else:
        a.append('android:singleLine="true"')
    if ellipsize:
        a.append('android:ellipsize="end"')
    if line_mult:
        a.append(f'android:lineSpacingMultiplier="{line_mult}"')
    if pad_h:
        a.append(f'android:paddingStart="{pad_h}"')
        a.append(f'android:paddingEnd="{pad_h}"')
    if pad_v:
        a.append(f'android:paddingTop="{pad_v}"')
        a.append(f'android:paddingBottom="{pad_v}"')
    if pad_start:
        a.append(f'android:paddingStart="{pad_start}"')
    if pad_end:
        a.append(f'android:paddingEnd="{pad_end}"')
    if visibility:
        a.append(f'android:visibility="{visibility}"')
    a.append('android:includeFontPadding="false"')
    return f"    <TextView\n        " + "\n        ".join(a) + " />\n"


def image(iid, src, size, *, margin_end=None, margin_start=None,
          margin_top=None, gravity=None, width=None, height=None,
          visibility=None, scale_type="fitCenter", bg=None):
    a = [f'android:id="@+id/{iid}"',
         f'android:layout_width="{width or size}"',
         f'android:layout_height="{height or size}"']
    for k, v in (("layout_marginEnd", margin_end),
                 ("layout_marginStart", margin_start),
                 ("layout_marginTop", margin_top), ("gravity", gravity)):
        if v:
            a.append(f'android:{k}="{v}"')
    if bg:
        a.append(f'android:background="@drawable/{bg}"')
    a.append(f'android:scaleType="{scale_type}"')
    a.append(f'android:src="@drawable/{src}"')
    if visibility:
        a.append(f'android:visibility="{visibility}"')
    return f"    <ImageView\n        " + "\n        ".join(a) + " />\n"


def linear(lid, *, orientation, width="match_parent", height="wrap_content",
           weight=None, gravity=None, margin_end=None, margin_top=None,
           margin_start=None, bg=None, pad=None, pad_start=None, pad_end=None,
           pad_v=None, baseline=False, visibility=None, min_width=None,
           pad_top=None, pad_bottom=None):
    a = [f'android:id="@+id/{lid}"',
         f'android:layout_width="{width}"',
         f'android:layout_height="{height}"']
    for k, v in (("layout_weight", weight), ("layout_marginEnd", margin_end),
                 ("layout_marginStart", margin_start),
                 ("layout_marginTop", margin_top), ("gravity", gravity),
                 ("minWidth", min_width)):
        if v:
            a.append(f'android:{k}="{v}"')
    a.append(f'android:orientation="{orientation}"')
    if bg:
        a.append(f'android:background="@drawable/{bg}"')
    if pad:
        a.append(f'android:padding="{pad}"')
    if pad_start:
        a.append(f'android:paddingStart="{pad_start}"')
    if pad_end:
        a.append(f'android:paddingEnd="{pad_end}"')
    if pad_v:
        a.append(f'android:paddingTop="{pad_v}"')
        a.append(f'android:paddingBottom="{pad_v}"')
    if pad_top:
        a.append(f'android:paddingTop="{pad_top}"')
    if pad_bottom:
        a.append(f'android:paddingBottom="{pad_bottom}"')
    if baseline:
        a.append('android:baselineAligned="false"')
    if visibility:
        a.append(f'android:visibility="{visibility}"')
    return f"    <LinearLayout\n        " + "\n        ".join(a) + ">\n"


CLOSE = "    </LinearLayout>\n"


def _with_alpha(color, alpha):
    """把 #RRGGBB 与 alpha 合成 #AARRGGBB。"""
    c = color.lstrip("#")
    return f"#{int(round(alpha * 255)):02X}{c.upper()}"


def hairline(hid, color=None):
    """1dp 细分隔线。默认白色 10%（压天气渐变用）；白底组件传 C.border。"""
    return (
        f'    <TextView\n        android:id="@+id/{hid}"\n'
        '        android:layout_width="match_parent"\n'
        '        android:layout_height="1dp"\n'
        f'        android:background="{color or HAIRLINE}" />\n'
    )


# ── 复合片段 ──────────────────────────────────────────────────────

def brand(x_align_right=True):
    """品牌区：logo（圆弧）+ APRSlocus。放在顶栏右侧。"""
    out = image("aw_logo", "aw_logo", "17dp")
    out += text("aw_app_name", size=APP_NAME, bold=True, margin_start="4dp",
                android_text="APRSlocus")
    return out


def city_group():
    out = image("aw_city_icon", "aw_ic_place", "11dp")
    out += text("aw_city", size=CITY, bold=True, margin_start="3dp",
                ellipsize=True, alpha=0.94)
    return out


def aqi_pill(aqi_size, dot, margin_start=None):
    """AQI 胶囊：底色 aw_pill（白 16%），内含级别色圆点 + 文字。"""
    out = linear("aw_aqi_pill", orientation="horizontal", width="wrap_content",
                 gravity="center_vertical", bg="aw_pill",
                 margin_start=margin_start,
                 pad_start="7dp", pad_end="8dp", pad_v="2dp")
    out += image("aw_aqi_dot", "aw_dot", dot)
    out += text("aw_aqi_text", size=aqi_size, bold=True, margin_start="5dp")
    out += CLOSE
    return out


def hero(sz, *, observed_inline=False):
    """天气主区：图标 + 大温度 + 天气现象 / 高低温。"""
    out = linear("aw_hero", orientation="horizontal",
                 gravity="center_vertical", baseline=True)
    out += image("aw_hero_icon", "aw_ic_big_thunderstorm", sz["icon"])
    out += text("aw_temp", size=sz["temp"], bold=True, margin_start="5dp",
                spacing="-0.02")
    out += linear("aw_cond_box", orientation="vertical", width="wrap_content",
                  margin_start="4dp")
    out += text("aw_cond", size=sz["cond"], bold=True, alpha=0.90)
    out += text("aw_range", size=sz["range"], alpha=0.74, margin_top="1dp")
    out += CLOSE
    out += CLOSE
    return out


def kv(i, sz, *, margin_end=None, margin_top=None):
    """一格指标：label 左 / value 右（面板 `_kvPair` 的复刻）。无底框。"""
    out = linear(f"aw_m{i}", orientation="horizontal", width="0dp", weight="1",
                 gravity="center_vertical", baseline=True,
                 margin_end=margin_end, margin_top=margin_top)
    out += text(f"aw_m{i}_label", size=sz["kv_label"], alpha=0.58)
    out += text(f"aw_m{i}_value", size=sz["kv_value"], bold=True, width="0dp",
                weight="1", gravity="end", ellipsize=True)
    out += CLOSE
    return out



def kv_row3(sz):
    """3 格指标、单行：label 左 / value 右（面板 `_kvPair` 的复刻）。

    与 kv_grid_2x2 的区别是只占一行。主档高度由天气主区决定，指标多一行
    只是白占 14dp（预览量化确认过），所以砍到 3 格单行。
    """
    out = linear("aw_metrics", orientation="horizontal", width="0dp", weight="1",
                 baseline=True)
    for i in range(3):
        out += kv(i, sz, margin_end="10dp" if i < 2 else None)
    out += CLOSE
    return out


def tips_block_inline(sz):
    """单行建议块：圆点 + 图标 + 级别 + 正文**同一行**。

    4×2 只有 140dp，「级别一行 + 正文一行」两条要 57dp 放不下。
    正文用 Dart 侧切好的完整短句（shortText）—— 靠缩短措辞，而不是让
    系统把句子从中间截断（「请勿在室…」那种读不出信息）。
    """
    out = linear("aw_tips", orientation="vertical", margin_top="5dp")
    for i in range(sz["tips"]):
        out += linear(f"aw_tip{i}", orientation="horizontal", gravity="center_vertical",
                      baseline=True, margin_top=None if i == 0 else "2dp")
        out += image(f"aw_tip{i}_dot", "aw_dot", sz["dot"])
        out += image(f"aw_tip{i}_icon", "aw_ic_rss_feed", sz["tip_icon"],
                     margin_start="5dp")
        out += text(f"aw_tip{i}_level", size=sz["tip_level"], bold=True,
                    margin_start="4dp", spacing="0.04")
        out += text(f"aw_tip{i}_text", size=sz["tip"], alpha=0.93,
                    margin_start="6dp", width="0dp", weight="1", ellipsize=True)
        out += CLOSE
    out += CLOSE
    return out


def kv_grid_2x2(sz):
    out = linear("aw_metrics", orientation="vertical", width="0dp", weight="1")
    out += linear("aw_mrow0", orientation="horizontal", baseline=True)
    out += kv(0, sz, margin_end="10dp")
    out += kv(1, sz)
    out += CLOSE
    out += linear("aw_mrow1", orientation="horizontal", baseline=True,
                  margin_top="5dp")
    out += kv(2, sz, margin_end="10dp")
    out += kv(3, sz)
    out += CLOSE
    out += CLOSE
    return out


def kv_rows(sz, count):
    out = linear("aw_metrics", orientation="vertical")
    for i in range(count):
        out += kv(i, sz, margin_top=None if i == 0 else "5dp")
    out += CLOSE
    return out


def tip_row(i, sz):
    """一条通栏建议 —— 与面板 `_tipRow` 同构。

    圆点是 ImageView + 白色圆图，运行时用 setColorFilter 染成级别色。
    （setColorFilter 只存在于 ImageView —— 这正是 v1.6.114 线上事故的根源：
     当时圆点是 TextView，调用它抛 NoSuchMethodException，整个组件报废。
     现在圆点是 ImageView，用法正确，且检查器会核对目标控件类型。）
    """
    out = linear(f"aw_tip{i}", orientation="horizontal", gravity="top",
                 baseline=True, margin_top=None if i == 0 else "4dp")
    out += image(f"aw_tip{i}_dot", "aw_dot", sz["dot"], margin_top="4dp")
    out += linear(f"aw_tip{i}_body", orientation="vertical", width="0dp",
                  weight="1", margin_start="8dp")
    out += linear(f"aw_tip{i}_head", orientation="horizontal", baseline=True)
    out += image(f"aw_tip{i}_icon", "aw_ic_rss_feed", sz["tip_icon"])
    out += text(f"aw_tip{i}_level", size=sz["tip_level"], bold=True,
                margin_start="4dp", spacing="0.04")
    out += CLOSE
    out += text(f"aw_tip{i}_text", size=sz["tip"], alpha=0.93,
                max_lines=sz["tip_lines"], ellipsize=True, line_mult="1.3",
                margin_top="2dp")
    out += CLOSE
    out += CLOSE
    return out


def tips_block(sz):
    out = linear("aw_tips", orientation="vertical", margin_top="5dp")
    for i in range(sz["tips"]):
        out += tip_row(i, sz)
    out += CLOSE
    return out


def section_title():
    out = linear("aw_tips_header", orientation="horizontal",
                 gravity="center_vertical", baseline=True, margin_top="8dp")
    out += image("aw_tips_icon", "aw_ic_rss_feed", "11dp")
    out += text("aw_tips_title", size=TITLE, bold=True, alpha=0.80,
                margin_start="4dp", spacing="0.06")
    out += text("aw_tips_spacer", size="1sp", width="0dp", height="1dp",
                weight="1")
    out += text("aw_tips_count", size="9sp", alpha=0.55)
    out += CLOSE
    return out


def empty_label(color=INK, alpha=0.90):
    """空状态：无定位 / 还没同步过数据。放在 aw_pad 之外，直接盖住整块。

    [color] 必须是**不带 alpha 的 #RRGGBB**，透明度走 [alpha] ——
    给成 "#E6FFFFFF" 这种含 alpha 的值会被 _with_alpha() 再拼一层，
    变成 9 位的畸形色值（不报错，但颜色不对）。

    底色不同要用不同色：天气组件是彩色渐变 → 白色；
    短波组件是白底 → 墨色。**给错就是一行看不见的字**。
    """
    return text("aw_empty", size="10sp", color=color, alpha=alpha, max_lines=4,
                ellipsize=True, line_mult="1.35", gravity="center",
                height="match_parent", visibility="gone")


# ── 四个档位 ──────────────────────────────────────────────────────

def build_tile():
    sz = TILE
    s = header_comment("桌面小组件 · 主档（3~4×2）", [
        "排布对齐 App 内天气面板的「顶部区」：",
        "  顶栏    ：[城市点+城市] [AQI 胶囊] …… [观测 HH:mm] [logo + APRSlocus]",
        "  主区    ：天气图标 + 大温度 + 天气现象 / 高低温",
        "  指标    ：3 格单行「label 左 / value 右」（面板 _kvPair 的复刻，无底框）",
        "  底部    ：2 条**单行**建议（圆点 + 级别图标 + 级别 + 正文同行）",
        "",
        "**这一档的每个取舍都是被 140dp 逼出来的**（都经过 tool/preview_app_widget.py",
        "的量化核对，不是拍脑袋）：",
        "  · 顶栏只留一行：两行要多吃 13.4dp，而一行里 城市+AQI+观测+品牌 ≈ 260dp",
        "    在 272dp 内放得下；",
        "  · 指标 3 格而不是 4 格：4 格要两行，而主档高度由天气主区决定，",
        "    多一行指标并不省主区的高度，只白占 14dp；",
        "  · 建议「级别与正文同行」：级别单独一行时每条要 28.6dp，两条 57dp 放不下；",
        "    同行后每条 15.3dp。正文用 Dart 侧切好的完整短句（shortText），",
        "    所以缩短的是措辞而不是把句子从中间截断。",
        "",
        "⚠ 硬约束：只用 RemoteViews 白名单控件（不用原生 <View>）、不用",
        "<selector>、不用 styles.xml 主题样式（字号颜色就地写死）。",
    ])
    s += open_layout("aw_root", "aw_bg_cloudy")
    s += linear("aw_pad", orientation="vertical", height="match_parent",
                pad_start="12dp", pad_end="12dp", pad_v="8dp")
    # 顶栏**一行**：城市 · AQI · 观测时刻 · 品牌
    s += linear("aw_header", orientation="horizontal",
                gravity="center_vertical", baseline=True)
    s += city_group()
    s += aqi_pill(AQI, sz["dot"], margin_start="6dp")
    s += text("aw_spacer", size="1sp", width="0dp", height="1dp", weight="1")
    s += text("aw_observed", size=OBSERVED, alpha=0.60, margin_end="8dp")
    s += brand()
    s += CLOSE
    s += linear("aw_rule1_box", orientation="vertical", margin_top="6dp")
    s += hairline("aw_rule1")
    s += CLOSE
    s += linear("aw_main", orientation="horizontal", gravity="center_vertical",
                baseline=True, margin_top="6dp")
    s += linear("aw_left", orientation="vertical", width="0dp", weight="1.12",
                gravity="center_vertical", margin_end="10dp")
    s += hero(sz)
    s += CLOSE
    s += kv_row3(sz)
    s += CLOSE
    s += linear("aw_rule2_box", orientation="vertical", margin_top="6dp")
    s += hairline("aw_rule2")
    s += CLOSE
    s += tips_block_inline(sz)
    s += CLOSE
    s += empty_label()
    s += "</FrameLayout>\n"
    return s


def build_tall():
    sz = TALL
    s = header_comment("桌面小组件 · 小面板（2×4）", [
        "四个档位里最像 App 内天气面板的一个：",
        "  顶栏两行（城市 | 品牌 / AQI | 观测）",
        "  天气图标 + 大温度 + 天气现象 + 高低温",
        "  3 行指标（label 左 / value 右）",
        "  「业余无线电建议」分组标题 + 2 条通栏建议",
        "",
        "2×4 宽度只有约 126dp，顶栏一行放不下「城市+AQI」与「logo+名称」，",
        "所以拆成两行（预览里发现 logo 会压住 APRSlocus）。",
        "指标只放 2 项、每条建议 2 行：3 项 + 两行建议实测超 12.7dp（预览量出来的）。竖长档的重点是「多给两条建议」，所以砍指标而不是砍建议。",
        "",
        "⚠ 硬约束同主档。",
    ])
    s += open_layout("aw_root", "aw_bg_cloudy")
    s += linear("aw_pad", orientation="vertical", height="match_parent",
                pad_start="12dp", pad_end="12dp", pad_v="9dp")
    s += linear("aw_header1", orientation="horizontal",
                gravity="center_vertical", baseline=True)
    s += city_group()
    s += text("aw_spacer1", size="1sp", width="0dp", height="1dp", weight="1")
    s += brand()
    s += CLOSE
    s += linear("aw_header2", orientation="horizontal",
                gravity="center_vertical", baseline=True, margin_top="5dp")
    s += aqi_pill(AQI, sz["dot"])
    s += text("aw_spacer2", size="1sp", width="0dp", height="1dp", weight="1")
    s += text("aw_observed", size=OBSERVED, alpha=0.60)
    s += CLOSE
    s += linear("aw_rule1_box", orientation="vertical", margin_top="8dp")
    s += hairline("aw_rule1")
    s += CLOSE
    s += linear("aw_hero_wrap", orientation="horizontal",
                gravity="center_vertical", baseline=True, margin_top="8dp")
    s += image("aw_hero_icon", "aw_ic_big_thunderstorm", sz["icon"])
    s += text("aw_temp", size=sz["temp"], bold=True, margin_start="6dp",
              spacing="-0.02")
    s += text("aw_range", size=sz["range"], alpha=0.74, width="0dp",
              weight="1", gravity="end")
    s += CLOSE
    s += text("aw_cond", size=sz["cond"], bold=True, alpha=0.90,
              margin_top="3dp")
    s += linear("aw_rule2_box", orientation="vertical", margin_top="9dp")
    s += hairline("aw_rule2")
    s += CLOSE
    s += linear("aw_metrics_wrap", orientation="vertical", margin_top="7dp")
    s += kv_rows(sz, 2)
    s += CLOSE
    s += linear("aw_rule3_box", orientation="vertical", margin_top="7dp")
    s += hairline("aw_rule3")
    s += CLOSE
    s += section_title()
    s += tips_block(sz)
    s += CLOSE
    s += empty_label()
    s += "</FrameLayout>\n"
    return s


def build_compact():
    sz = COMPACT
    s = header_comment("桌面小组件 · 紧凑档（2×2 / 2×3）", [
        "温度 + 天气现象 + 高低温，下面一条「最要紧」的建议。",
        "",
        "提示只给一条：小尺寸下把 4 条并列等于每条都看不清，所以只显示排序后的",
        "第 1 条（危险 → 注意 → 通联机会 → 操作提示）。",
        "",
        "⚠ 硬约束同主档。",
    ])
    s += open_layout("aw_root", "aw_bgs_cloudy")
    s += linear("aw_pad", orientation="vertical", height="match_parent",
                pad_start="11dp", pad_end="11dp", pad_v="8dp")
    s += linear("aw_header1", orientation="horizontal",
                gravity="center_vertical", baseline=True)
    s += city_group()
    s += text("aw_spacer1", size="1sp", width="0dp", height="1dp", weight="1")
    s += brand()
    s += CLOSE
    s += linear("aw_header2", orientation="horizontal",
                gravity="center_vertical", baseline=True, margin_top="5dp")
    s += aqi_pill("8sp", sz["dot"])
    s += text("aw_spacer2", size="1sp", width="0dp", height="1dp", weight="1")
    s += text("aw_observed", size="8sp", alpha=0.60)
    s += CLOSE
    s += linear("aw_rule1_box", orientation="vertical", margin_top="7dp")
    s += hairline("aw_rule1")
    s += CLOSE
    s += linear("aw_hero_wrap", orientation="horizontal",
                gravity="center_vertical", baseline=True, margin_top="7dp")
    s += image("aw_hero_icon", "aw_ic_big_thunderstorm", sz["icon"])
    s += text("aw_temp", size=sz["temp"], bold=True, margin_start="5dp",
              spacing="-0.02")
    s += linear("aw_cond_box", orientation="vertical", width="0dp", weight="1",
                gravity="end")
    s += text("aw_cond", size=sz["cond"], bold=True, alpha=0.90)
    s += text("aw_range", size=sz["range"], alpha=0.74, margin_top="1dp")
    s += CLOSE
    s += CLOSE
    s += linear("aw_rule2_box", orientation="vertical", margin_top="7dp")
    s += hairline("aw_rule2")
    s += CLOSE
    s += tips_block(sz)
    s += CLOSE
    s += empty_label()
    s += "</FrameLayout>\n"
    return s


def build_row():
    s = header_comment("桌面小组件 · 单行档（3~4×1）", [
        "一条通栏：天气图标 + 温度 + 天气现象 / 高低温 ｜ 一条建议 ｜ 右端 logo。",
        "",
        "高度只有 1 格（约 72dp），所以一切必须单行。建议用 Dart 侧预先切好的",
        "短版本（compactRows[0].singles），由 Kotlin 按可用宽度从长到短挑第一个",
        "放得下的 —— 切分规则（全角冒号 / 句末标点）属于本地化范畴，不在 Kotlin 做。",
        "",
        "右端**只放 logo 不放名称**：一行里要挤下 温度/天气/高低温 再加一条建议，",
        "再写「APRSlocus」会把建议截成「雷雨天气…」等于没给信息（预览里就是）。",
        "",
        "⚠ 硬约束同主档。",
    ])
    s += open_layout("aw_root", "aw_bgs_cloudy")
    s += linear("aw_pad", orientation="horizontal", height="match_parent",
                gravity="center_vertical", baseline=True,
                pad_start="12dp", pad_end="12dp", pad_v="8dp")
    s += image("aw_hero_icon", "aw_ic_big_thunderstorm", "22dp")
    s += text("aw_temp", size="20sp", bold=True, margin_start="5dp",
              spacing="-0.02")
    s += linear("aw_cond_box", orientation="vertical", width="wrap_content",
                margin_start="5dp")
    s += text("aw_cond", size="9.5sp", bold=True, alpha=0.90)
    s += text("aw_range", size="9sp", alpha=0.74)
    s += CLOSE
    s += text("aw_sep", size="1sp", width="1dp", height="22dp",
              margin_start="11dp", margin_end="10dp", bg="aw_sep")
    s += image("aw_tip0_dot", "aw_dot", "6dp")
    s += image("aw_tip0_icon", "aw_ic_rss_feed", "11dp", margin_start="5dp")
    s += text("aw_tip0_level", size="8.5sp", bold=True, margin_start="4dp",
              spacing="0.04")
    s += text("aw_tip0_text", size="9sp", alpha=0.93, margin_start="6dp",
              width="0dp", weight="1", ellipsize=True)
    s += image("aw_logo", "aw_logo", "17dp", margin_start="8dp")
    s += CLOSE
    s += empty_label()
    s += "</FrameLayout>\n"
    return s



# ── 短波/电离层传播组件（4×2，固定尺寸 · 白底 · 彩色 chip）────────────
def build_hf():
    """逐波段给出日间/夜间传播条件 —— 「各个波段的传播信息」。

    **这一版是「F2 · 条件色带」**（用户在 4 个方向里选定的）。
    上一版（D · tonal chip）被判定「还是好难看」，逐条诊断：
      ① **8 个同形状的淡色药丸**：色块面积与信息量不匹配 —— 「一般」一行内
         出现 3 次、「差」4 次；重复的图形不承载额外信息，只堆噪声；
      ② **4 行完全同构**，没有层次，像把表格直接倒上去；
      ③ 波段名与第一个 chip 之间约 40dp 空档，横向扫视要跨很远；
      ④ 淡底 11% 远看是一片浅灰粉，颜色信号几乎无效。
    F2 的解法（不是调参，是换结构）：
      · 每行一条**色带**横贯整个日/夜列 —— 行的宽度即列宽，空档消失；
      · 颜色集中到色带**左端一道 2.5dp 色标**：4 行扫下来是一条竖线，
        像仪表的指示列，而不是 8 个孤立色块；
      · 档位文字就在色带内**左端**（紧挨色标），颜色与文字同源、不用跨空档读；
      · 「日间 / 夜间」列头与色带左边缘**同一 x**（旧版图例浮在右端，等于没标）。

    **色带为什么是一张 layer-list、而不是「淡底容器 + 2.5dp 子 View」**：
    RemoteViews 不允许原生 `<View>`；色标只能用 TextView/ImageView 冒充，那就要
    多一个控件、多一个 id、多一行 setBackgroundResource —— 每个都是只在运行期
    才爆的地方。一张 layer-list 把「淡底 + 色标」合成一个背景，于是每格仍然只是
    **一个 TextView**：setBackgroundResource 换色带、setTextColor 换字色，这两个
    方法在 View/TextView 上确实存在（对照 setColorFilter 只存在于 ImageView 那个
    线上事故）。

    **为什么必须预生成 4 张色带 drawable**：同上的 setColorFilter 限制 ——
    TextView 换底只能用 setBackgroundResource，所以四个条件各一张
    （aw_track_{good,fair,poor,closed}，由 tool/gen_app_widget_drawables.py 生成）。

    **6m 段**在指数行右端（不在表里）：6m 没有「日间/夜间」之分，传播机理
    （Es / 极光 / F2）与 HF 波段完全不同，并进那张表会让「6m 日间 Poor」读起来
    像同一机理。它与指数同高、同一种色带外观 —— 无开通常态下只显示一个「--」，
    不抢注意力；一旦开通就变色，是本组件里最「可行动」的一条。

    **为什么固定 4×2**（resizeMode=none）：内容是一张表（波段 × 昼夜）。
    表不能优雅降级 —— 挤到 2×2 只剩波段名、没有条件，等于砍掉最有用的信息。

    设计稿见 tool/preview_app_widget.py 的 render_hf_F2（同一套尺寸）。
    """
    rows = 4
    s = header_comment("桌面小组件 · 短波/电离层传播（4×2 · F2 条件色带）", [
        "顶栏    ：[电波图标·墨色] 短波传播                [logo] APRSlocus",
        "指数行  ：SFI 100 · Kp 3 · A 9                  [6m 色带]",
        "细线    ：C.border（#E5E9F0）",
        "列头    ：          日间              夜间   ← 与色带左边缘**同一条竖线**",
        "4 行波段：80m/40m / 30m/20m / 17m/15m / 12m/10m",
        "          每格 = 条件色带（aw_track_*：淡底 14% + 左端 2.5dp 色标）",
        "                 档位文字在色带内左端，颜色 = 该档基本色",
        "6m      ：无开通时显示灰色占位符（与 Dart 的 HfNow.none 一致）—— 不抢注意力；",
        "          开通时显示档位并变色",
        "",
        "数据来自 hamqsl.com 的 calculatedconditions（业余界标准 HF 传播源），",
        "由 Dart 侧 lib/hf.dart 拉取、解析、本地化后推过来 —— 组件不联网。",
        "",
        "⚠ 硬约束同天气组件：只用白名单控件（不用原生 <View>）、不用 <selector>、",
        "不用 styles.xml 主题样式（字号颜色就地写死）。",
    ])
    s += open_layout("aw_root", "aw_bg_white")
    s += linear("aw_pad", orientation="vertical", height="match_parent",
                pad_start="12dp", pad_end="12dp", pad_top="8dp", pad_bottom="9dp")
    # ① 顶栏
    s += linear("aw_hf_header", orientation="horizontal",
                gravity="center_vertical", baseline=True)
    s += image("aw_hf_icon", "aw_ic_waves", "14dp")
    s += text("aw_hf_title", size="12sp", bold=True, color=INK, margin_start="4dp")
    s += text("aw_spacer", size="1sp", width="0dp", height="1dp", weight="1")
    s += image("aw_logo", "aw_logo", "15dp")
    s += text("aw_app_name", size="10sp", bold=True, color=INK,
              margin_start="4dp", android_text="APRSlocus")
    s += CLOSE
    # ② 指数行 + 右端 6m 色带。
    #    6m 与指数同高、同一种色带外观：它是最「可行动」的一条（开通即值得上机），
    #    但无开通是常态，所以此时只显示一个「--」，不用颜色抢注意力。
    s += linear("aw_idx", orientation="horizontal", gravity="bottom",
                baseline=True, margin_top="3dp")
    for i in range(3):
        s += text(f"aw_idx{i}_label", size="8.5sp", color=SLATE)
        s += text(f"aw_idx{i}_value", size="11sp", bold=True, color=INK,
                  margin_start="3dp", margin_end="10dp")
    s += text("aw_idx_spacer", size="1sp", width="0dp", height="1dp",
              weight="1")
    # 「6m」这个说明文字**不能省**：一个带颜色的格子如果不标出处，用户只会看到
    # 一个孤立的色块，不知道它在说什么。6m 是波段代号（和表里的 80m/40m 同性质），
    # 不随语言变化，所以就地写死，不用本地化键。
    #
    # ⚠ 名字**不能**叫 aw_six_label：check_android_res_ids.py 把以 `_label` 结尾的
    # id 一律当成「必须由某个档位填充的数据字段」，静态文案用这个名字会被判成
    # 「布局加了控件却忘了配 IdS 表」。这条规则本身是对的（它拦的是真丢字段），
    # 所以正确的做法是把名字改对，而不是去放宽规则。
    s += text("aw_six_tag", size="8.5sp", color=SLATE,
              android_text="6m", margin_end="3dp")
    # 46dp：容得下最长的档位词（id 的 "Tertutup" ≈ 38dp + 左右 6dp 内边距）。
    s += text("aw_six", size="8.5sp", bold=True, color=SLATE,
              width="46dp", height="13dp", gravity="center",
              bg="aw_track_closed", pad_start="3dp", pad_end="3dp",
              ellipsize=True)
    s += CLOSE
    # ③ 细线
    s += linear("aw_rule1_box", orientation="vertical", margin_top="4dp")
    s += hairline("aw_rule1", LINE)
    s += CLOSE
    # ④ 列头：波段列固定宽，两条色带列等分 ——
    #    列头左边缘与色带左边缘**同一条竖线**（靠等分列实现，不靠调 margin）。
    s += linear("aw_colhead", orientation="horizontal", baseline=True,
                margin_top="3dp")
    s += text("aw_ch_band", size="8.5sp", color=SLATE, width=BAND_W)
    s += text("aw_ch_day", size="8sp", color=SLATE, bold=True, spacing="0.06",
              width="0dp", weight="1")
    s += text("aw_ch_night", size="8sp", color=SLATE, bold=True, spacing="0.06",
              width="0dp", weight="1")
    s += CLOSE
    # ⑤ 4 行波段
    s += linear("aw_bands", orientation="vertical", margin_top="2dp")
    for i in range(rows):
        s += linear(f"aw_band{i}", orientation="horizontal",
                    gravity="center_vertical", baseline=True,
                    margin_top=None if i == 0 else "1dp")
        s += text(f"aw_band{i}_name", size="9.5sp", bold=True, color=INK,
                  width=BAND_W, ellipsize=True)
        # 色带格：外层等分容器决定列宽，色带铺满它（所以行的宽度 = 列宽）
        s += linear(f"aw_band{i}_day_box", orientation="horizontal",
                    width="0dp", weight="1", gravity="center_vertical")
        s += text(f"aw_band{i}_day", size="9.5sp", bold=True, color=INK,
                  gravity="center_vertical", bg="aw_track_good",
                  height=TRACK_H, pad_start=TRACK_PAD_START,
                  pad_end=TRACK_PAD_END)
        s += CLOSE
        s += linear(f"aw_band{i}_night_box", orientation="horizontal",
                    width="0dp", weight="1", gravity="center_vertical")
        s += text(f"aw_band{i}_night", size="9.5sp", bold=True, color=INK,
                  gravity="center_vertical", bg="aw_track_good",
                  height=TRACK_H, pad_start=TRACK_PAD_START,
                  pad_end=TRACK_PAD_END)
        s += CLOSE
        s += CLOSE

    s += CLOSE
    s += CLOSE
    s += empty_label(color="@color/aw_ink_dim")
    s += "</FrameLayout>\n"
    return s


# ── 系统状态组件（4×2）──────────────────────────────────────────────
def build_sys():
    """APRS 台站的「一眼健康检查」：定位 / 四条链路 / 收发计数 / 信标与台站数。

    为什么值得单独做一个组件：APRS 是**后台长期运行**的应用，用户最常问的
    三个问题是「还在收吗」「我的位置有没有上报」「为什么没地图台站」。
    这三件事分别由「链路是否 up」「信标是否在走」「台站数有没有涨」回答 ——
    都要打开 App 才能看到，而它们恰恰是**放在桌面上更有用**的那类信息。

    设计沿用短波组件的语言（白/深底 + 墨色字 + tonal 状态点），
    这样三个组件摆在一起是同一套设计，而不是三种风格。
    """
    s = header_comment("桌面小组件 · 系统状态（4×2）", [
        "顶栏    ：[齿轮] 系统状态                          [logo] APRSlocus",
        "身份行  ：呼号 · 定位状态 · 网格",
        "细线",
        "链路区  ：2×2 四格 —— APRS-IS / TNC / 音频 / PKWDWPL",
        "          每格「状态点 + 链路名 + 状态文字」；点色 = 已连接绿 / 未启用灰",
        "细线",
        "计数行  ：收 N · 发 N（左）    信标 Ns · 台站 N（右）",
        "",
        "想回答的三个问题（按优先级排布）：",
        "  · 还在收吗               → 链路区的绿点 + 「收 N」",
        "  · 我的位置有没有上报      → 身份行的定位状态 + 「信标 Ns」",
        "  · 为什么地图没台站        → 「台站 N」",
        "",
        "⚠ 硬约束同其它组件：只用白名单控件（不用原生 <View>）、不用 <selector>、",
        "不用 styles.xml 主题样式（字号颜色就地写死，颜色引用 @color/aw_* 以支持夜间）。",
    ])
    s += open_layout("aw_root", "aw_bg_white")
    s += linear("aw_pad", orientation="vertical", height="match_parent",
                pad_start="13dp", pad_end="13dp", pad_top="8dp", pad_bottom="9dp")
    # 顶栏
    s += linear("aw_sys_header", orientation="horizontal",
                gravity="center_vertical", baseline=True)
    s += image("aw_sys_icon", "aw_ic_settings", "14dp")
    s += text("aw_sys_title", size="13sp", bold=True, color=INK,
              margin_start="4dp")
    s += text("aw_spacer", size="1sp", width="0dp", height="1dp", weight="1")
    s += image("aw_logo", "aw_logo", "15dp")
    s += text("aw_app_name", size="10sp", bold=True, color=INK,
              margin_start="4dp", android_text="APRSlocus")
    s += CLOSE
    # 身份行：呼号 · 定位 · 网格
    s += linear("aw_identity", orientation="horizontal", baseline=True,
                margin_top="3dp")
    s += text("aw_my_call", size="11sp", bold=True, color=INK)
    s += text("aw_id_sep1", size="9sp", color=SLATE, margin_start="6dp",
              margin_end="6dp", android_text="·")
    s += text("aw_fix_state", size="9.5sp", color=SLATE)
    s += text("aw_id_sep2", size="9sp", color=SLATE, margin_start="6dp",
              margin_end="6dp", android_text="·")
    s += text("aw_my_grid", size="9.5sp", color=SLATE)
    s += CLOSE
    s += linear("aw_rule1_box", orientation="vertical", margin_top="4dp")
    s += hairline("aw_rule1", LINE)
    s += CLOSE
    # 链路 2×2
    s += linear("aw_links", orientation="vertical", margin_top="5dp")
    for r in range(2):
        s += linear(f"aw_lrow{r}", orientation="horizontal", baseline=True,
                    margin_top=None if r == 0 else "6dp")
        for c in range(2):
            i = r * 2 + c
            s += linear(f"aw_link{i}", orientation="horizontal", width="0dp",
                        weight="1", gravity="center_vertical", baseline=True,
                        margin_end="10dp" if c == 0 else None)
            s += image(f"aw_link{i}_dot", "aw_dot", "7dp")
            s += text(f"aw_link{i}_name", size="9.5sp", color=INK,
                      margin_start="6dp", bold=True)
            s += text(f"aw_link{i}_state", size="9sp", color=SLATE,
                      margin_start="5dp", width="0dp", weight="1",
                      ellipsize=True)
            s += CLOSE
        s += CLOSE
    s += CLOSE
    s += linear("aw_rule2_box", orientation="vertical", margin_top="5dp")
    s += hairline("aw_rule2", LINE)
    s += CLOSE
    # 计数行
    s += linear("aw_counters", orientation="horizontal", baseline=True,
                margin_top="5dp")
    s += text("aw_rx", size="9.5sp", color=SLATE)
    s += text("aw_tx", size="9.5sp", color=SLATE, margin_start="12dp")
    s += text("aw_cnt_spacer", size="1sp", width="0dp", height="1dp",
              weight="1")
    s += text("aw_beacon", size="9.5sp", color=SLATE)
    s += text("aw_stations", size="9.5sp", color=SLATE, margin_start="12dp")
    s += CLOSE
    s += CLOSE
    s += empty_label(color=INK, alpha=0.85)
    s += "</FrameLayout>\n"
    return s


def self_check(name, xml):
    """产物自检：XML 良构 + 注释合法 + 标签闭合 + 只用白名单控件。

    这些问题都只在**编译期或运行时**才炸，本地生成时全是绿的，必须在这里挡住。
    关键：**先剥掉注释再扫控件** —— 注释里为了说明约束会写到 `<View>`、`<selector>`
    这些字面量，不剥就会把自己的说明文档当成违规（而且修它的人通常会去删说明，
    约束就又没人记得了）。

    ⚠ 两条是踩过的坑，别再删：
      · **XML 注释里不能出现 `--`**。我在注释里写占位符 `「--」`，AAPT 直接
        `The string "--" is not permitted within comments` → Android 构建失败。
        而这**本该在本地就发现**（见下一条）。
      · **必须真的用 XML 解析器解析一遍**。只做字符串匹配（上面那些规则）看不出
        良构问题，于是「本地全绿、CI 才炸」。ElementTree 一解析就报，代价为零。
    """
    problems = []
    # ① XML 良构：任何解析错误都是硬错（AAPT 也会拒）
    try:
        ET.fromstring(xml)
    except ET.ParseError as e:
        problems.append(f"{name}: XML 良构校验失败（AAPT 会拒绝）：{e}")
    # ② 注释内容不得含 `--`（XML 规范禁止；AAPT 直接报错）
    for m in re.finditer(r"<!--(.*?)-->", xml, flags=re.S):
        if "--" in m.group(1):
            bad = next((l.strip() for l in m.group(1).splitlines()
                        if "--" in l), "")
            problems.append(
                f"{name}: XML 注释里出现 `--`（规范禁止，AAPT 会报 "
                f"`not permitted within comments`）：{bad[:80]}")

    body = re.sub(r"<!--.*?-->", "", xml, flags=re.S)
    for tag in re.findall(r"<([A-Za-z][\w.]*)", body):
        if tag not in ALLOWED_TAGS:
            problems.append(f"{name}: 出现了非白名单控件 <{tag}>"
                            f"（RemoteViews 会抛异常，组件变白块）")
    for tag in ("FrameLayout", "LinearLayout"):
        o = len(re.findall(rf"<{tag}\b", body))
        c = body.count(f"</{tag}>")
        if o != c:
            problems.append(f"{name}: <{tag}> 开 {o} 个、闭 {c} 个，标签不闭合")
    if "aw_bg" not in body and "aw_bgs" not in body:
        problems.append(f"{name}: 根布局缺少天气背景占位")
    if "<selector" in body or "<ripple" in body:
        problems.append(f"{name}: 用了 <selector>/<ripple>，RemoteViews 不支持")
    return problems


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out_dir = os.path.join(root, "android", "app", "src", "main", "res", "layout")
    if not os.path.isdir(out_dir):
        print(f"找不到 layout 目录：{out_dir}", file=sys.stderr)
        return 1

    files = {
        "aw_widget_tile.xml": build_tile(),
        "aw_widget_tall.xml": build_tall(),
        "aw_widget_compact.xml": build_compact(),
        "aw_widget_row.xml": build_row(),
        "aw_widget_hf.xml": build_hf(),
        "aw_widget_sys.xml": build_sys(),
    }

    problems = []
    for name, xml in files.items():
        problems += self_check(name, xml)
    if problems:
        print("自检未通过，未写入任何文件：", file=sys.stderr)
        for p in problems:
            print(f"  ✗ {p}", file=sys.stderr)
        return 1

    for name, xml in files.items():
        with open(os.path.join(out_dir, name), "w", encoding="utf-8") as f:
            f.write(xml)
        print(f"layout/{name}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
