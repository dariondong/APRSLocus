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
            tip_icon="11dp", dot="6dp", tips=3, tip_lines=1)
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
          margin_top=None, gravity=None, layout_gravity=None, width=None,
          height=None, visibility=None, scale_type="fitCenter", bg=None):
    a = [f'android:id="@+id/{iid}"',
         f'android:layout_width="{width or size}"',
         f'android:layout_height="{height or size}"']
    for k, v in (("layout_marginEnd", margin_end),
                 ("layout_marginStart", margin_start),
                 ("layout_marginTop", margin_top), ("gravity", gravity),
                 # layout_gravity 是「在父容器里靠哪边」——FrameLayout 里
                 # 摆位只能靠它（没有绝对定位，也没有百分比布局）
                 ("layout_gravity", layout_gravity)):
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
FRAME_CLOSE = "    </FrameLayout>\n"


def frame(fid, *, width="match_parent", height="wrap_content", weight=None,
          bg=None, margin_start=None, margin_end=None, margin_top=None):
    """FrameLayout 容器：用来「在一个色块上叠图标/白点」。

    进度条段需要「底色 + 段内图标 + 顶部白点」三层。LinearLayout 只能横向/纵向
    排队，没法把白点摆到正中上方 —— 只有 FrameLayout 能用 layout_gravity 定位子元素。
    """
    a = [f'android:id="@+id/{fid}"',
         f'android:layout_width="{width}"',
         f'android:layout_height="{height}"']
    for k, v in (("layout_weight", weight), ("layout_marginStart", margin_start),
                 ("layout_marginEnd", margin_end),
                 ("layout_marginTop", margin_top)):
        if v:
            a.append(f'android:{k}="{v}"')
    if bg:
        a.append(f'android:background="@drawable/{bg}"')
    return f"    <FrameLayout\n        " + "\n        ".join(a) + ">\n"


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
    """天气主区：图标 + 大温度（左）…… 天气现象 / 高低温（右）。

    **「现象/高低温」靠右，而不是紧跟在温度后面**：主区独占一行后，如果它们
    还贴着温度站，右侧会空掉一半（原来并排时看不出来，因为那一半被指标占着）。
    这与 App 内面板的写法（温度与现象相邻）有意不同 —— 面板是**窄而高**的一列，
    组件是**宽而扁**的一条，同一条规则套过来只会留空。
    """
    out = linear("aw_hero", orientation="horizontal",
                 gravity="center_vertical", baseline=True)
    out += image("aw_hero_icon", "aw_ic_big_thunderstorm", sz["icon"])
    out += text("aw_temp", size=sz["temp"], bold=True, margin_start="5dp",
                spacing="-0.02")
    out += text("aw_hero_spacer", size="1sp", width="0dp", height="1dp",
                weight="1")
    out += linear("aw_cond_box", orientation="vertical", width="wrap_content",
                  gravity="end", baseline=True)
    out += text("aw_cond", size=sz["cond"], bold=True, alpha=0.90,
                gravity="end")
    out += text("aw_range", size=sz["range"], alpha=0.74, margin_top="1dp",
                gravity="end")
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
        "  底部    ：3 条**单行**建议（圆点 + 级别图标 + 级别 + 正文同行）",
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
    # 天气主区**独占一行**，指标另起一行。
    #
    # 原来是并排：hero 占左列 42%、3 格指标占右列 58%。后果是 30sp 的大温度
    # 只剩约 110dp、湿度/风力/气压被挤在同一行，而上半个卡片其余地方全空 ——
    # 也就是用户说的「上面挤、下面空」。拆开后大温度拿回整行、指标也有了自己的
    # 一行，两处都松了。
    #
    # 顺带一提：这不增加「信息的条数」，只改变排布 —— 所以底部补的是第 3 条
    # 建议（见 tips=3），而不是再塞一个指标。
    s += linear("aw_main", orientation="vertical", margin_top="6dp")
    s += hero(sz)
    s += linear("aw_metrics_row", orientation="horizontal", baseline=True,
                margin_top="6dp")
    s += kv_row3(sz)
    s += CLOSE
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
# ── 短波组件的两档尺寸 ─────────────────────────────────────────────
# 为什么是「两档」而不是流体缩放：RemoteViews 没有百分比布局，能按比例设高的
# `setViewLayoutHeight` 又要 API 31+（本项目 minSdk=24），所以只能分档 ——
# 与天气组件（4 档）同一套机制。
#
# **两档共用同一套 id**（只有 dp 值不同）：这样 Provider 只需按高度换一个
# layout 资源，不必维护第二张 IdS 表 —— 少一处「改了一档忘了改另一档」的地方。
HF_BASE = dict(
    seg_h="18dp", seg_icon="10dp", icon_pad="7dp", pip_w="6dp", pip_h="3dp",
    seg_gap="2dp", now_w="48dp",
    title="12sp", tag="8.5sp", idx_label="8.5sp", idx_value="11sp",
    six="8.5sp", band="9sp", now="8.5sp",
    tip_level="8.5sp", tip="9sp", tip_lines=1,
    head_icon="14dp", head_logo="15dp", app="10sp", six_h="13dp", six_w="48dp",
    pad="12dp", pad_top="8dp", pad_bottom="9dp",
    # 波段名列宽。**56dp 是算出来的**：最长的「12m/10m」在 9sp 加粗下实测
    # 约 42dp；Android 字体缩放上限 1.3 倍 → 42 × 1.3 ≈ 55dp。
    band_w="56dp",
    idx_gap="2dp", rule_gap="3dp", row_gap="2dp", tip_gap="3dp",
)

# 高出 1~2 格（4×3 / 4×4）时用这一档：条更粗、字更大、提示给两行。
# 不是把所有间距乘 1.5 —— 那样只会显得松散；改成「条变粗 + 字号上一档
# + 提示多一行」，多出来的高度都用在**信息量**上。
HF_TALL = dict(HF_BASE, **dict(
    # 24dp 而不是 26dp：26dp 时四行加起来把总高顶到 240dp，超出 4×3 的
    # 内容预算（≈234dp）；24dp 刚好落在 230dp 以内。
    seg_h="24dp", seg_icon="15dp", icon_pad="10dp", pip_w="10dp", pip_h="4dp",
    seg_gap="3dp", now_w="62dp",
    title="13.5sp", tag="10sp", idx_label="10sp", idx_value="13sp",
    six="10sp", band="10.5sp", now="10.5sp",
    tip_level="10sp", tip="10.5sp", tip_lines=2,
    head_icon="16dp", head_logo="17dp", app="11.5sp", six_h="17dp", six_w="56dp",
    pad="14dp", pad_top="11dp", pad_bottom="12dp",
    # 字号上到 10.5sp，列宽必须跟着加到 68dp：10.5sp 加粗 ≈ 49dp，
    # 再乘字体缩放 1.3 ≈ 64dp —— 沿用 56dp 会当场把波段名截掉。
    band_w="68dp",
    idx_gap="4dp", rule_gap="5dp", row_gap="4dp", tip_gap="5dp",
))

def build_hf(tall=False):
    """短波/电离层传播：每个波段一条「日 → 夜」进度条 + 当前时段游标。

    **这一版是「M1 · 双段 + 游标」**（用户在三个方向里选定的）。上一版
    （F2 · 条件色带）虽然在结构上比「八个药丸」清楚了，但仍有两个硬伤：
      ① 波段名被挤掉（列宽 46dp 放不下 9.5sp 加粗的 "12m/10m"，字体一放大
         更甚）——「这是哪个波段」是整块的前置信息，它没了其余都白搭；
      ② 两列表把「白天」与「夜间」并列成两列，用户还得自己心算现在该看哪列。

    这一版直接把「现在」摆到台面上：
      · 每个波段一条横贯的两段条：**左=日间、右=夜间**（顺序即时间顺序）；
      · 两段各有自己的条件色 —— 一眼看出两个时段各自的通联程度；
      · **当前时段那一段是实色 + 顶部一颗小白点**（小白点烘焙在 drawable 里，
        见 gen_app_widget_drawables.segnow_xml），另一段是淡底 → 「现在」
        不需要读字就看得出来；
      · 两端各一个小图标作语义标注：日端 = 太阳（琥珀），夜端 = 星光（次要色）；
      · 每行右端仍给一个档位块（好/一般/差），它是**当前时段**的档位 ——
        颜色之外再给一个词，满足「不靠颜色也能读」。
      · 指数行右端写「现在 夜间」，把「现在」这件事说清楚。

    **当前时段由原生按本机时钟判断**（阈值由 Dart 随快照下发 dayFrom/dayTo）：
    组件每 30 分钟自刷新时只重绘已存的快照，若在 Dart 侧把时段算死，用户
    一整天不开 App 就会出现「19:00 之后还指着日间」—— 判错时段比不显示更糟。

    尺寸（实测累计，见 tool/preview_app_widget.py 的 _hf_m1_geometry）：
      pad 8/9 + 顶栏 17.7 + 指数行 13 + 细线 5 + 4 行 × (15 + 4) − 4 ≈ 128dp，
      比上一版（158.7dp）更矮 —— 4×2 表类组件能拿到多少高度取决于启动器，
      矮一点只会更安全。

    设计稿见 tool/preview_app_widget.py 的 render_hf_M1（同一套尺寸）。
    """
    rows = 4
    sz = HF_TALL if tall else HF_BASE
    tier = "4×3+ 加高" if tall else "4×2 标准"
    s = header_comment(f"桌面小组件 · 短波/电离层传播（{tier} · M1 日/夜进度条）", [
        "顶栏    ：[电波图标·墨色] 短波传播  现在 夜间    [logo] APRSlocus",
        "指数行  ：SFI 100 · Kp 3 · A 9                        6m [档位]",
        "细线    ：C.border（#E5E9F0）",
        "4 行波段：80m/40m / 30m/20m / 17m/15m / 12m/10m",
        "          每行 = [波段名 56dp][太阳][日间段][夜间段][星光][档位块]",
        "          两段① aw_segday_*（亮 = 日）/ aw_segnight_*（暗 = 夜），",
        "             段内放太阳/月亮图标；② 顶部白点（aw_dot）标出「现在」在哪段",
        "",
        "提示行  ：[圆点][级别图][级别] 一句话 —— 与 App 内面板的「业余无线电建议」",
        "          同源（Dart 复用 hfTips，取排序后的第一条）；此刻没有值得说的",
        "          时整行收起，不留空行。",
        "          当前时段那一段用实色 + 小白点，另一段淡底",
        "          档位块显示**当前时段**的档位（文字 + 条件色）",
        "",
        "数据来自 hamqsl.com 的 calculatedconditions（业余界标准 HF 传播源），",
        "由 Dart 侧 lib/hf.dart 拉取、解析、本地化后推过来 —— 组件不联网。",
        "当前时段由原生按本机时钟判断，日间区间由 Dart 随快照下发。",
        "",
        "⚠ 硬约束同天气组件：只用白名单控件（不用原生 <View>）、不用 <selector>、",
        "不用 styles.xml 主题样式（字号颜色就地写死）。",
    ])
    s += open_layout("aw_root", "aw_bg_white")
    s += linear("aw_pad", orientation="vertical", height="match_parent",
                pad_start=sz["pad"], pad_end=sz["pad"], pad_top=sz["pad_top"],
                pad_bottom=sz["pad_bottom"])
    # ① 顶栏
    s += linear("aw_hf_header", orientation="horizontal",
                gravity="center_vertical", baseline=True)
    s += image("aw_hf_icon", "aw_ic_waves", sz["head_icon"])
    s += text("aw_hf_title", size=sz["title"], bold=True, color=INK,
              margin_start="4dp")
    # 「现在 夜间」放在**顶栏**而不是指数行：它是表头级的「这份数据对应当前哪个时段」，
    # 且指数行已经被 SFI/Kp/A + 6m 占满 —— 实测西班牙语的「Ahora Noche」52.3dp、
    # 印尼语的「Sekarang Malam」67.7dp，留在指数行会把 6m 格挤出去。
    # 顶栏标题与品牌之间有大片空位，长度再长也放得下。
    s += text("aw_now_tag", size=sz["tag"], color=SLATE, margin_start="7dp")
    s += text("aw_spacer", size="1sp", width="0dp", height="1dp", weight="1")
    s += image("aw_logo", "aw_logo", sz["head_logo"])
    s += text("aw_app_name", size=sz["app"], bold=True, color=INK,
              margin_start="4dp", android_text="APRSlocus")
    s += CLOSE
    # ② 指数行 + 右端「现在 夜间」（文案由 Dart 拼好下发 —— 原生不本地化）
    s += linear("aw_idx", orientation="horizontal", gravity="bottom",
                baseline=True, margin_top=sz["idx_gap"])
    for i in range(3):
        s += text(f"aw_idx{i}_label", size=sz["idx_label"], color=SLATE)
        s += text(f"aw_idx{i}_value", size=sz["idx_value"], bold=True, color=INK,
                  margin_start="3dp", margin_end="10dp")
    s += text("aw_idx_spacer", size="1sp", width="0dp", height="1dp",
              weight="1")
    # 6m 格：它是**另一件东西**（Es / 极光 / F2 三条通路，没有日/夜之分），
    # 所以不进上面那张「日/夜进度条」的表，留在指数行右端当一个独立指标 ——
    # 上一版（v1.6.128）刚把它做成常驻，这版不能因为改了表就把它挤掉。
    # 无条件时显示灰色占位符（Dart 给 HfNow.none），开通时才变色。
    s += text("aw_six_tag", size=sz["six"], color=SLATE, android_text="6m",
              margin_start="8dp", margin_end="3dp")
    s += text("aw_six", size=sz["six"], bold=True, color="#FFFFFF",
              width=sz["six_w"], height=sz["six_h"], gravity="center",
              bg="aw_segnight_closed", pad_start="3dp", pad_end="3dp",
              ellipsize=True)
    s += CLOSE
    # ③ 细线
    s += linear("aw_rule1_box", orientation="vertical", margin_top=sz["rule_gap"])
    s += hairline("aw_rule1", LINE)
    s += CLOSE
    # ④ 4 行波段：名字 + [白天段] + [夜晚段] + 当前档位块
    #
    # 每一段 = 一个 FrameLayout（底色 drawable + 段内图标 + 顶部白点）：
    #   · 底色：白天 = aw_segday_*（亮）/ 夜晚 = aw_segnight_*（暗）——
    #     **亮度表达时段**，这是用户点名的语义（「亮的是白天、暗的是晚上」）。
    #     上一版是「当前时段实色、另一段淡底」，于是夜里那一段反而最亮。
    #   · 段内图标：太阳/月亮**放进条里**（原来是条外的两个小图），
    #     一眼就知道哪段是白天；宽度也让给条本身。
    #   · 顶部白点：标出「现在」在哪一段。独立 ImageView（可见性由 Kotlin 控），
    #     不做进 drawable —— 否则「档位 × 昼夜 × 是否当前」要 16 张图/主题。
    for i in range(rows):
        s += linear(f"aw_band{i}", orientation="horizontal",
                    gravity="center_vertical", baseline=True,
                    margin_top=sz["row_gap"])
        s += text(f"aw_band{i}_name", size=sz["band"], bold=True, color=INK,
                  width=sz["band_w"], ellipsize=True)
        # ── 白天段 ──
        s += frame(f"aw_band{i}_day", width="0dp", weight="1", height=sz["seg_h"],
                   bg="aw_segday_closed")
        s += image(f"aw_band{i}_dayicon", "aw_ic_wb_sunny", sz["seg_icon"],
                   layout_gravity="left|center_vertical",
                   margin_start=sz["icon_pad"])
        s += image(f"aw_band{i}_daypip", "aw_dot", sz["pip_w"],
                   width=sz["pip_w"], height=sz["pip_h"],
                   layout_gravity="top|center_horizontal", margin_top="2dp")
        s += FRAME_CLOSE
        # ── 夜晚段 ──
        # 夜端用**月亮**（nights_stay）而不是「星光簇」（auto_awesome）：
        # 后者是几颗大小不一的三角闪光，10dp 下糊成一团，看上去像渲染毛刺。
        s += frame(f"aw_band{i}_night", width="0dp", weight="1", height=sz["seg_h"],
                   bg="aw_segnight_closed", margin_start=sz["seg_gap"])
        s += image(f"aw_band{i}_nighticon", "aw_ic_nights_stay", sz["seg_icon"],
                   layout_gravity="left|center_vertical",
                   margin_start=sz["icon_pad"])
        s += image(f"aw_band{i}_nightpip", "aw_dot", sz["pip_w"],
                   width=sz["pip_w"], height=sz["pip_h"],
                   layout_gravity="top|center_horizontal", margin_top="2dp")
        s += FRAME_CLOSE
        # 当前档位块：底色跟**当前时段**的明暗走（白天段=亮底 / 夜晚段=暗底），
        # 文字由 Kotlin 设成白色 —— 与段内图标的处理一致。
        s += text(f"aw_band{i}_now", size=sz["now"], bold=True, color="#FFFFFF",
                  width=sz["now_w"], height=sz["seg_h"], gravity="center",
                  bg="aw_segday_closed", margin_start="3dp", ellipsize=True)
        s += CLOSE

    # ⑤ 通联提示（一行）：读完「哪个波段好」之后的下一步是「那我该干什么」。
    #
    # 文案在 Dart 侧就取好了（hfTips 与面板同源），这里只摆位置 ——
    # 原生不做任何判定，也不拼句子（组件进程没有 App 的上下文）。
    #
    # 圆点与级别图标都是**白图 + 运行时染色**（setColorFilter 只存在于
    # ImageView —— v1.6.114 的线上事故正源于把它用在 TextView 上）。
    s += linear("aw_tip_box", orientation="vertical", margin_top=sz["tip_gap"])
    s += hairline("aw_tip_rule", LINE)
    s += CLOSE
    s += linear("aw_tip", orientation="horizontal", gravity="center_vertical",
                baseline=True, margin_top=sz["tip_gap"])
    s += image("aw_tip_dot", "aw_dot", "6dp")
    s += image("aw_tip_icon", "aw_ic_rss_feed", "11dp", margin_start="5dp")
    s += text("aw_tip_level", size=sz["tip_level"], bold=True, spacing="0.04",
              margin_start="4dp")
    s += text("aw_tip_text", size=sz["tip"], color=INK, alpha=0.93,
              max_lines=sz["tip_lines"],
              ellipsize=True, margin_start="5dp", width="0dp", weight="1")
    s += CLOSE

    s += CLOSE
    s += empty_label(color="@color/aw_ink_dim")
    s += "</FrameLayout>\n"
    return s


# ── 系统状态组件（4×2）──────────────────────────────────────────────
# ── 系统状态组件的两档尺寸（同短波：两档共用同一套 id）────────────
SYS_BASE = dict(
    pad="13dp", pad_top="8dp", pad_bottom="9dp",
    title="13sp", app="10sp", icon="14dp", logo="15dp",
    call="11sp", id_sep="9sp", id_val="9.5sp",
    dot="7dp", link_name="9.5sp", link_state="9sp",
    cnt="9.5sp", recent_label="8.5sp", recent_call="9.5sp",
    g_id="3dp", g_rule1="3dp", g_links="4dp", g_lrow="5dp", g_rule2="4dp",
    g_cnt="4dp", g_recent="4dp",
)

# 加高档（4×3+）：字号上一档、状态点变大、各区块之间拉开。
# 这里**没有多加内容**（不像短波多给一行提示）—— 系统状态的四段本来就
# 各自独立，硬塞新内容会变成另一张表；把间距拉开、字放大反而是它需要的。
SYS_TALL = dict(SYS_BASE, **dict(
    pad="16dp", pad_top="13dp", pad_bottom="16dp",
    title="15sp", app="11.5sp", icon="17dp", logo="17dp",
    call="13sp", id_sep="10sp", id_val="11sp",
    dot="9dp", link_name="11sp", link_state="10.5sp",
    cnt="11sp", recent_label="10sp", recent_call="11sp",
    g_id="7dp", g_rule1="8dp", g_links="12dp", g_lrow="14dp", g_rule2="12dp",
    g_cnt="12dp", g_recent="12dp",
))

def build_sys(tall=False):
    """APRS 台站的「一眼健康检查」：定位 / 四条链路 / 收发计数 / 信标与台站数。

    为什么值得单独做一个组件：APRS 是**后台长期运行**的应用，用户最常问的
    三个问题是「还在收吗」「我的位置有没有上报」「为什么没地图台站」。
    这三件事分别由「链路是否 up」「信标是否在走」「台站数有没有涨」回答 ——
    都要打开 App 才能看到，而它们恰恰是**放在桌面上更有用**的那类信息。

    设计沿用短波组件的语言（白/深底 + 墨色字 + tonal 状态点），
    这样三个组件摆在一起是同一套设计，而不是三种风格。
    """
    sz = SYS_TALL if tall else SYS_BASE
    tier = "4×3+ 加高" if tall else "4×2 标准"
    s = header_comment(f"桌面小组件 · 系统状态（{tier}）", [
        "顶栏    ：[齿轮] 系统状态                          [logo] APRSlocus",
        "身份行  ：呼号 · 定位状态 · 网格",
        "细线",
        "链路区  ：2×2 四格 —— APRS-IS / TNC / 音频 / PKWDWPL",
        "          每格「状态点 + 链路名 + 状态文字」；点色 = 已连接绿 / 未启用灰",
        "细线",
        "计数行  ：收 N · 发 N（左）    信标 Ns · 台站 N（右）",
        "最近行  ：最近收到 <呼号>（左）…… 多久前（右）—— 比「收 N」更直接地",
        "          回答「还在收吗」；没有台站时整行收起",
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
                pad_start=sz["pad"], pad_end=sz["pad"], pad_top=sz["pad_top"],
                pad_bottom=sz["pad_bottom"])
    # 顶栏
    s += linear("aw_sys_header", orientation="horizontal",
                gravity="center_vertical", baseline=True)
    s += image("aw_sys_icon", "aw_ic_settings", sz["icon"])
    s += text("aw_sys_title", size=sz["title"], bold=True, color=INK,
              margin_start="4dp")
    s += text("aw_spacer", size="1sp", width="0dp", height="1dp", weight="1")
    s += image("aw_logo", "aw_logo", sz["logo"])
    s += text("aw_app_name", size=sz["app"], bold=True, color=INK,
              margin_start="4dp", android_text="APRSlocus")
    s += CLOSE
    # 身份行：呼号 · 定位 · 网格
    s += linear("aw_identity", orientation="horizontal", baseline=True,
                margin_top=sz["g_id"])
    s += text("aw_my_call", size=sz["call"], bold=True, color=INK)
    s += text("aw_id_sep1", size=sz["id_sep"], color=SLATE, margin_start="6dp",
              margin_end="6dp", android_text="·")
    s += text("aw_fix_state", size=sz["id_val"], color=SLATE)
    s += text("aw_id_sep2", size=sz["id_sep"], color=SLATE, margin_start="6dp",
              margin_end="6dp", android_text="·")
    s += text("aw_my_grid", size=sz["id_val"], color=SLATE)
    s += CLOSE
    s += linear("aw_rule1_box", orientation="vertical", margin_top=sz["g_rule1"])
    s += hairline("aw_rule1", LINE)
    s += CLOSE
    # 链路 2×2
    s += linear("aw_links", orientation="vertical", margin_top=sz["g_links"])
    for r in range(2):
        s += linear(f"aw_lrow{r}", orientation="horizontal", baseline=True,
                    margin_top=None if r == 0 else sz["g_lrow"])
        for c in range(2):
            i = r * 2 + c
            s += linear(f"aw_link{i}", orientation="horizontal", width="0dp",
                        weight="1", gravity="center_vertical", baseline=True,
                        margin_end="10dp" if c == 0 else None)
            s += image(f"aw_link{i}_dot", "aw_dot", sz["dot"])
            s += text(f"aw_link{i}_name", size=sz["link_name"], color=INK,
                      margin_start="6dp", bold=True)
            s += text(f"aw_link{i}_state", size=sz["link_state"], color=SLATE,
                      margin_start="5dp", width="0dp", weight="1",
                      ellipsize=True)
            s += CLOSE
        s += CLOSE
    s += CLOSE
    s += linear("aw_rule2_box", orientation="vertical", margin_top=sz["g_rule2"])
    s += hairline("aw_rule2", LINE)
    s += CLOSE
    # 计数行
    s += linear("aw_counters", orientation="horizontal", baseline=True,
                margin_top=sz["g_cnt"])
    s += text("aw_rx", size=sz["cnt"], color=SLATE)
    s += text("aw_tx", size=sz["cnt"], color=SLATE, margin_start="12dp")
    s += text("aw_cnt_spacer", size="1sp", width="0dp", height="1dp",
              weight="1")
    s += text("aw_beacon", size=sz["cnt"], color=SLATE)
    s += text("aw_stations", size=sz["cnt"], color=SLATE, margin_start="12dp")
    s += CLOSE
    # 最近收到的台站（左：标签 + 呼号；右：多久前）
    #
    # 为什么加这一行：它比「收 N」更直接地回答「**还在收吗**」—— 计数只说明
    # 「一共收过多少」，卡住时计数是不动的，用户从计数上看不出来；而
    # 「最近收到谁、多久前」说明此刻还在不在收。
    #
    # 没有台站时整行收起（Kotlin 侧按 recentCall 是否为空决定），
    # 而不是留一个「最近收到  · 」的空壳。
    s += linear("aw_recent", orientation="horizontal", baseline=True,
                margin_top=sz["g_recent"])
    s += text("aw_recent_label", size=sz["recent_label"], color=SLATE)
    s += text("aw_recent_call", size=sz["recent_call"], bold=True, color=INK,
              margin_start="5dp", ellipsize=True)
    s += text("aw_recent_spacer", size="1sp", width="0dp", height="1dp",
              weight="1")
    s += text("aw_recent_ago", size=sz["recent_label"], color=SLATE)
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
        # 加高档（4×3+）：与标准档**同一套 id**，只有 dp 值不同 ——
        # Provider 按高度选一个 layout 资源即可，不必维护第二张 IdS 表。
        "aw_widget_hf_tall.xml": build_hf(tall=True),
        "aw_widget_sys.xml": build_sys(),
        # 加高档（4×3+）：与标准档同一套 id，只有 dp 值不同
        "aw_widget_sys_tall.xml": build_sys(tall=True),
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
