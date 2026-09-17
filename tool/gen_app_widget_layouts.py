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

# ── 尺寸令牌：四档共用，改字号只改这里 ──────────────────────────────
# 参照面板（正文 12.5sp / 温度 58sp / 度数 24sp）按可用空间等比缩小。
TILE = dict(temp="30sp", icon="25dp", cond="9.5sp", range="9sp",
            kv_label="9sp", kv_value="10sp", tip="9.5sp", tip_level="8.5sp",
            tip_icon="11dp", dot="6dp", tips=2, tip_lines=2)
TALL = dict(temp="32sp", icon="26dp", cond="10sp", range="9sp",
            kv_label="9sp", kv_value="10sp", tip="9.5sp", tip_level="8.5sp",
            tip_icon="11dp", dot="6dp", tips=2, tip_lines=2)
COMPACT = dict(temp="25sp", icon="21dp", cond="9sp", range="8.5sp",
               kv_label="8.5sp", kv_value="9.5sp", tip="8.5sp", tip_level="8sp",
               tip_icon="11dp", dot="6dp", tips=1, tip_lines=3)

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


def text(tid, *, size, color="#FFFFFF", bold=False, max_lines=None,
         ellipsize=False, gravity=None, spacing=None, pad_h=None,
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
    if alpha is not None:
        # RemoteViews 不能给单个 view 设 alpha；用带 alpha 的 #AARRGGBB 文字色
        # 表达「弱化」层级（面板也是靠白色 + 低 alpha，不是灰色）。
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
           pad_v=None, baseline=False, visibility=None, min_width=None):
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


def hairline(hid):
    return (
        f'    <TextView\n        android:id="@+id/{hid}"\n'
        '        android:layout_width="match_parent"\n'
        '        android:layout_height="1dp"\n'
        f'        android:background="{HAIRLINE}" />\n'
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


def aqi_pill(aqi_size, dot):
    """AQI 胶囊：底色 aw_pill（白 16%），内含级别色圆点 + 文字。"""
    out = linear("aw_aqi_pill", orientation="horizontal", width="wrap_content",
                 gravity="center_vertical", bg="aw_pill",
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


def empty_label():
    """空状态：无定位 / 还没同步过天气。放在 aw_pad 之外，直接盖住整块。"""
    return text("aw_empty", size="10sp", alpha=0.90, max_lines=4,
                ellipsize=True, line_mult="1.35", gravity="center",
                height="match_parent", visibility="gone")


# ── 四个档位 ──────────────────────────────────────────────────────

def build_tile():
    sz = TILE
    s = header_comment("桌面小组件 · 主档（3~4×2）", [
        "排布对齐 App 内天气面板的「顶部区」：",
        "  顶栏行 1：左上 [城市点+城市]          右上 [logo + APRSlocus]",
        "  顶栏行 2：左   [AQI 胶囊]             右   [观测 HH:mm]",
        "  主区    ：天气图标 + 大温度 + 天气现象 / 高低温",
        "  指标    ：2×2 个「label 左 / value 右」（面板 _kvPair 的复刻，无底框）",
        "  底部    ：2 条通栏建议（圆点 + 级别图标 + 级别 / 正文另起一行）",
        "",
        "只放 2 条建议是刻意的：面板每条建议占一整行、正文 12.5sp；组件高度只有",
        "2 格，塞 4 条会把每条压成 1 行 8sp —— 那正是第一版「挤」的根因。",
        "宁可少给两条，也要让给出的读得舒服；完整列表点进 App 看。",
        "",
        "⚠ 硬约束：只用 RemoteViews 白名单控件（不用原生 <View>）、不用",
        "<selector>、不用 styles.xml 主题样式（字号颜色就地写死）。",
    ])
    s += open_layout("aw_root", "aw_bg_cloudy")
    s += linear("aw_pad", orientation="vertical", height="match_parent",
                pad_start="12dp", pad_end="12dp", pad_v="9dp")
    # 顶栏行 1
    s += linear("aw_header1", orientation="horizontal",
                gravity="center_vertical", baseline=True)
    s += city_group()
    s += text("aw_spacer1", size="1sp", width="0dp", height="1dp", weight="1")
    s += brand()
    s += CLOSE
    # 顶栏行 2
    s += linear("aw_header2", orientation="horizontal",
                gravity="center_vertical", baseline=True, margin_top="4dp")
    s += aqi_pill(AQI, sz["dot"])
    s += text("aw_spacer2", size="1sp", width="0dp", height="1dp", weight="1")
    s += text("aw_observed", size=OBSERVED, alpha=0.60)
    s += CLOSE
    s += hairline("aw_rule1")
    s += linear("aw_main", orientation="horizontal", gravity="center_vertical",
                baseline=True, margin_top="7dp")
    s += linear("aw_left", orientation="vertical", width="0dp", weight="1.12",
                gravity="center_vertical", margin_end="10dp")
    s += hero(sz)
    s += CLOSE
    s += kv_grid_2x2(sz)
    s += CLOSE
    s += linear("aw_rule2_box", orientation="vertical", margin_top="7dp")
    s += hairline("aw_rule2")
    s += CLOSE
    s += tips_block(sz)
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
        "指标只放 3 项、每条建议 2 行：4 项 + 3 行实测超卡片高度 23dp。",
        "",
        "⚠ 硬约束同主档。",
    ])
    s += open_layout("aw_root", "aw_bg_cloudy")
    s += linear("aw_pad", orientation="vertical", height="match_parent",
                pad_start="12dp", pad_end="12dp", pad_v="10dp")
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
    s += kv_rows(sz, 3)
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
                pad_start="11dp", pad_end="11dp", pad_v="9dp")
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


def self_check(name, xml):
    """产物自检：标签闭合 + 只用白名单控件。

    这两个问题都只在**运行时**才炸（组件白块），编译期全是绿的，必须在生成时挡住。
    关键：**先剥掉注释再扫** —— 注释里为了说明约束会写到 `<View>`、`<selector>`
    这些字面量，不剥就会把自己的说明文档当成违规（而且修它的人通常会去删说明，
    约束就又没人记得了）。
    """
    body = re.sub(r"<!--.*?-->", "", xml, flags=re.S)
    problems = []
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
