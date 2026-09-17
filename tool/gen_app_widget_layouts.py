#!/usr/bin/env python3
"""生成 4 个尺寸档的桌面小组件布局 XML。

**为什么要生成而不是手写四份**：四个布局共用同一套 id 命名约定
（`aw_<档位>_*`）和同一套硬约束（RemoteViews 白名单控件、不用 selector、
不用主题样式、不用原生 View）。手写四份意味着任何一条约束改动要改四处，
而漏掉的那一处只会在真机上表现为白块 —— 所以集中在这里生成，
并在脚本末尾自检「每个产物的标签是否闭合」（第一次写就漏了一个，
XML 解析器才告诉我；这种低级错误应该由脚本自己挡住）。

用法：
    python3 tool/gen_app_widget_layouts.py

产物（android/app/src/main/res/layout/）：
    aw_widget_compact.xml   2×2 / 2×3   温度 + 天气 + 1 条最要紧的提示
    aw_widget_row.xml       4×1         一条通栏：天气 + 提示
    aw_widget_tall.xml      2×4         「小面板」：堆叠式，与面板最接近
    aw_widget_tile.xml      4×2         「主面板」：海报式

设计取向（对齐 App 内天气面板，而不是自创一套）：
- **提示是通栏行，不是窄列**。面板里每条建议占一整行（圆点 + 图标级别 + 正文），
  窄列会把 12sp 的正文压成 8sp 还折三行，那就是上一版「挤」的根因。
- **温度是主角**：数字大、度数符号抬高缩小（面板用 58/24sp，组件按尺寸等比缩）。
- **弱化层级靠「字距 + 透明度」**：面板的小标题用 w700 + ls 0.8 + 白色 80%，
  做出「小但不弱」的效果，这里照做，而不是靠换颜色。
- **提示按级别排序、危险级换红底**：与面板 `_hamTips` 排序、`_tipRow` 危险底色一致。
- 堆叠/单行两套提示布局都放进同一份 XML，运行时由 Kotlin 按可用高度择一显示。
"""

import os
import re
import sys

# ── 尺寸令牌：四个档位共用，改字号只改这里 ────────────────────────
# 面板基准（58/24/12.5sp）→ 组件各档按可用空间等比缩小，
# 但「温度:副文本」的比例保持一致（约 2.4:1），这样四档观感是同一套设计。
T = {
    "tile":    dict(temp="34sp", deg="15sp", emoji="21sp", cond="9.5sp",
                    range="9sp", metric="11sp", metric_label="7.5sp",
                    tip="9.5sp", tip_level="8.5sp", tips=2, tip_lines=3),
    "tall":    dict(temp="38sp", deg="17sp", emoji="24sp", cond="10sp",
                    range="9.5sp", metric="12.5sp", metric_label="8sp",
                    tip="9.5sp", tip_level="8.5sp", tips=5, tip_lines=4),
    "compact": dict(temp="26sp", deg="12sp", emoji="17sp", cond="9sp",
                    range="9sp", metric="10sp", metric_label="7.5sp",
                    tip="8.5sp", tip_level="8sp", tips=1, tip_lines=3),
}


def header_comment(title: str, lines: list[str]) -> str:
    body = "\n".join(f"  {l}" for l in lines)
    return f"<!--\n  {title}\n\n{body}\n-->\n"


def open_layout(root_id: str, bg: str) -> str:
    return (
        '<FrameLayout xmlns:android="http://schemas.android.com/apk/res/android"\n'
        f'    android:id="@+id/{root_id}"\n'
        '    android:layout_width="match_parent"\n'
        '    android:layout_height="match_parent"\n'
        f'    android:background="@drawable/{bg}">\n'
    )


def text(tid: str, *, size: str, color: str = "#FFFFFF", bold: bool = False,
         max_lines: int = None, ellipsize: bool = False, gravity: str = None,
         spacing: str = None, pad_h: str = None, width: str = "wrap_content",
         height: str = "wrap_content", weight: str = None,
         margin_end: str = None, margin_start: str = None,
         margin_top: str = None, max_width: str = None, min_width: str = None,
         visibility: str = None, line_mult: str = None,
         bg: str = None, android_text: str = None) -> str:
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
    if visibility:
        a.append(f'android:visibility="{visibility}"')
    a.append('android:includeFontPadding="false"')
    inner = "\n        ".join(a)
    return f"    <TextView\n        {inner} />\n"


def linear(lid: str, *, orientation: str, width="match_parent",
           height="wrap_content", weight=None, gravity=None, margin_end=None,
           margin_top=None, margin_start=None, bg=None, pad=None,
           pad_start=None, pad_end=None, pad_v=None, baseline=False,
           visibility=None, min_height=None) -> str:
    a = [f'android:id="@+id/{lid}"',
         f'android:layout_width="{width}"',
         f'android:layout_height="{height}"']
    for k, v in (("layout_weight", weight), ("layout_marginEnd", margin_end),
                 ("layout_marginStart", margin_start),
                 ("layout_marginTop", margin_top), ("gravity", gravity),
                 ("minHeight", min_height)):
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
    inner = "\n        ".join(a)
    return f"    <LinearLayout\n        {inner}>\n"


CLOSE = "    </LinearLayout>\n"


# ── 复合片段 ──────────────────────────────────────────────────────

def hero_block(p: str, sz: dict) -> str:
    """温度块：emoji + 大字号温度（度数符号抬高缩小）+ 可选副标题。

    面板的做法是「大数字 + 小度数符号」而不是一个 58sp 的 `23°` 字符串 ——
    后者会让 ° 跟数字一样大，观感很业余。这里用嵌套 Row 复刻。
    """
    return (
        linear(f"aw_{p}_hero", orientation="horizontal",
               gravity="center_vertical", baseline=True)
        + text(f"aw_{p}_emoji", size=sz["emoji"])
        + linear(f"aw_{p}_temp_box", orientation="horizontal",
                 width="wrap_content", gravity="bottom", baseline=True,
                 margin_start="5dp")
        + text(f"aw_{p}_temp", size=sz["temp"], bold=True, spacing="-0.02")
        + text(f"aw_{p}_deg", size=sz["deg"], android_text="°")
        + CLOSE
        + CLOSE
    )


def metric_tile(i: int, sz: dict, margin_end: str | None) -> str:
    """一个指标格：值（大字）+ 标签（小字弱化），玻璃底。"""
    return (
        linear(f"aw_m{i}", orientation="vertical", width="0dp", weight="1",
               gravity="center", bg="aw_tile", pad_v="5dp",
               margin_end=margin_end)
        + text(f"aw_m{i}_value", size=sz["metric"], bold=True)
        + text(f"aw_m{i}_label", size=sz["metric_label"], color="#C4FFFFFF",
               gravity="center", ellipsize=True)
        + CLOSE
    )


def metric_grid(p: str, sz: dict) -> str:
    """2×2 指标网格。"""
    out = linear(f"aw_{p}_metrics", orientation="vertical", margin_top="8dp")
    for r in range(2):
        out += linear(f"aw_mrow{r}", orientation="horizontal", baseline=True,
                      margin_top=None if r == 0 else "4dp")
        for c in range(2):
            out += metric_tile(r * 2 + c, sz, "4dp" if c == 0 else None)
        out += CLOSE
    out += CLOSE
    return out


def tip_stack_row(i: int, sz: dict, first: bool) -> str:
    """一条通栏建议行 —— 与面板 `_tipRow` 同构。

    面板的结构是：[6dp 级别色圆点] [图标 + 级别小标签] / [正文]。
    这里照搬：圆点用 aw_dot + setColorFilter 染色，不用竖色条 ——
    竖色条要 `height=match_parent` 才能跟满两行文字，而 match_parent 高度
    在 wrap_content 的横向 LinearLayout 里测量不可靠，一旦测成 0 高
    色条就整根消失（圆点没有这个风险）。
    """
    out = linear(f"aw_tip{i}", orientation="horizontal", baseline=True,
                 gravity="top", margin_top=None if first else "4dp")
    out += text(f"aw_tip{i}_dot", size="1sp", width="6dp", height="6dp",
                margin_top="4dp", bg="aw_dot")
    out += linear(f"aw_tip{i}_body", orientation="vertical", width="0dp",
                  weight="1", margin_start="8dp")
    out += linear(f"aw_tip{i}_head", orientation="horizontal", baseline=True)
    out += text(f"aw_tip{i}_emoji", size="10sp")
    out += text(f"aw_tip{i}_level", size=sz["tip_level"], bold=True,
                margin_start="4dp", spacing="0.04")
    out += CLOSE
    out += text(f"aw_tip{i}_text", size=sz["tip"], color="#EDFFFFFF",
                max_lines=sz["tip_lines"], ellipsize=True, line_mult="1.3",
                margin_top="2dp")
    out += CLOSE
    out += CLOSE
    return out


def tips_header(sz: dict) -> str:
    """「业余无线电建议」小标题：小号 + 字距 + 80% 白，弱化但不弱智。"""
    return (
        linear("aw_tips_header", orientation="horizontal",
               gravity="center_vertical", margin_top="9dp", baseline=True)
        + text("aw_tips_title", size="9.5sp", color="#E6FFFFFF", bold=True,
               spacing="0.06")
        + text("aw_tips_spacer", size="1sp", width="0dp", height="1dp",
               weight="1")
        + text("aw_tips_count", size="9sp", color="#8CFFFFFF")
        + CLOSE
    )


def tip_compact_row(margin_top: str) -> str:
    """单行形态：放不下堆叠提示时用的降级版（默认隐藏）。"""
    return (
        linear("aw_tip_compact", orientation="horizontal", baseline=True,
               gravity="center_vertical", margin_top=margin_top,
               visibility="gone")
        + text("aw_tipc_emoji", size="10sp")
        + text("aw_tipc_text", size="9.5sp", color="#EDFFFFFF", margin_start="5dp",
               width="0dp", weight="1", ellipsize=True)
        + CLOSE
    )


def empty_label() -> str:
    """空状态：无定位 / 还没同步过天气。

    刻意放在 aw_pad **外面**（作为根 FrameLayout 的兄弟节点）：无数据时
    直接隐藏整块内容区、只显示这一句，不必逐个把字段清空 —— 后者写漏一个
    就会在空状态里露出残留的旧字段。
    """
    return text("aw_empty", size="10sp", color="#E6FFFFFF", max_lines=4,
                ellipsize=True, line_mult="1.35", gravity="center",
                height="match_parent", visibility="gone")


def aqi_pill(sz: dict) -> str:
    return text("aw_aqi", size=sz.get("aqi", "8.5sp"), bold=True,
                margin_start="5dp", pad_h="6dp", bg="aw_pill")


# ── 四个档位 ──────────────────────────────────────────────────────

def build_compact() -> str:
    sz = T["compact"]
    s = header_comment("桌面小组件 · 紧凑档（2×2 / 2×3）", [
        "温度 + 天气现象 + 今日高低温，下面一条「最要紧」的提示。",
        "",
        "提示只给一条：小尺寸下把 4 条并列等于每条都看不清，",
        "所以这里只显示排序后的第 1 条（危险 → 注意 → 通联机会 → 操作提示）。",
        "",
        "⚠ 硬约束：只用 RemoteViews 白名单控件（FrameLayout / LinearLayout /",
        "TextView）；不用 <selector>；不用 styles.xml 主题样式；不用原生 <View>",
        "（会抛 android.view.View is not allowed，整块变白）。",
        "背景由 Kotlin 按天气档位换成 aw_bgs_*（小圆角版本）。",
    ])
    s += open_layout("aw_root", "aw_bgs_cloudy")
    s += linear("aw_pad", orientation="vertical", height="match_parent",
                pad_start="10dp", pad_end="10dp", pad_v="7dp")
    s += linear("aw_header", orientation="horizontal",
                gravity="center_vertical", baseline=True)
    s += text("aw_city", size="10sp", color="#F2FFFFFF", bold=True,
              max_width="72dp", ellipsize=True)
    s += aqi_pill({})
    s += text("aw_spacer", size="1sp", width="0dp", height="1dp", weight="1")
    s += text("aw_observed", size="8sp", color="#B8FFFFFF")
    s += CLOSE
    s += hero_block("c", sz)
    s += text("aw_cond", size=sz["cond"], color="#D9FFFFFF", margin_top="3dp",
              ellipsize=True)
    s += text("aw_range", size=sz["range"], color="#C4FFFFFF", margin_top="1dp")
    s += linear("aw_tips", orientation="horizontal", gravity="top",
                baseline=True, margin_top="6dp")
    s += text("aw_tip0_dot", size="1sp", width="6dp", height="6dp",
              margin_top="4dp", bg="aw_dot")
    s += text("aw_tip0_text", size=sz["tip"], color="#EDFFFFFF", max_lines=3,
              ellipsize=True, line_mult="1.25", margin_start="7dp",
              width="0dp", weight="1")
    s += CLOSE
    s += CLOSE
    s += empty_label()
    s += "</FrameLayout>\n"
    return s


def build_row() -> str:
    s = header_comment("桌面小组件 · 单行档（4×1）", [
        "一条通栏：温度 + 天气现象 + 高低温 + 一条提示。",
        "",
        "高度只有 1 格（约 60dp），所以**一切都必须单行**。提示用 Dart 侧",
        "预先切好的短版本（compactRows[0].singles），由 Kotlin 按可用宽度",
        "从长到短挑第一个放得下的那个 —— 切分规则属于本地化范畴，不在 Kotlin 做。",
        "",
        "⚠ 硬约束同 compact 档。",
    ])
    s += open_layout("aw_root", "aw_bgs_cloudy")
    s += linear("aw_pad", orientation="horizontal", height="match_parent",
                gravity="center_vertical", baseline=True,
                pad_start="11dp", pad_end="11dp", pad_v="6dp")
    s += text("aw_emoji", size="16sp")
    s += text("aw_temp", size="21sp", bold=True, margin_start="4dp",
              spacing="-0.02")
    s += text("aw_deg", size="12sp", android_text="°")
    s += text("aw_cond", size="9.5sp", color="#D9FFFFFF", margin_start="6dp",
              ellipsize=True, max_width="92dp")
    s += text("aw_range", size="9.5sp", color="#C4FFFFFF", margin_start="5dp")
    s += text("aw_sep", size="9.5sp", color="#59FFFFFF", margin_start="8dp")
    s += text("aw_tip0_dot", size="1sp", width="6dp", height="6dp",
              margin_start="8dp", bg="aw_dot")
    s += text("aw_tip0_text", size="9sp", color="#EDFFFFFF", margin_start="6dp",
              width="0dp", weight="1", ellipsize=True)
    s += CLOSE
    s += empty_label()
    s += "</FrameLayout>\n"
    return s


def build_tall() -> str:
    sz = T["tall"]
    s = header_comment("桌面小组件 · 竖长档（2×4）—— 「小面板」", [
        "四个档位里**最像 App 内天气面板**的一个：",
        "  顶栏（城市 · AQI · 观测时刻）",
        "  大温度 + 天气现象 + 今日高低温",
        "  4 个指标格（2×2 网格）",
        "  业余无线电建议（通栏堆叠行，按级别排序，危险级红底）",
        "",
        "提示行与面板 _tipRow 同构：左侧 6dp 级别色圆点 + emoji 级别 + 正文。",
        "圆点用 aw_dot + setColorFilter 染色（RemoteViews 不能给单个 view",
        "设背景色，只能换 drawable 或染色）。",
        "",
        "⚠ 硬约束同 compact 档。",
    ])
    s += open_layout("aw_root", "aw_bg_cloudy")
    s += linear("aw_pad", orientation="vertical", height="match_parent",
                pad_start="11dp", pad_end="11dp", pad_v="9dp")
    s += linear("aw_header", orientation="horizontal",
                gravity="center_vertical", baseline=True)
    s += text("aw_city", size="11sp", color="#F2FFFFFF", bold=True,
              ellipsize=True, width="0dp", weight="1")
    s += aqi_pill(sz)
    s += CLOSE
    s += text("aw_observed", size="8.5sp", color="#B8FFFFFF", margin_top="3dp")
    s += hero_block("t", sz)
    s += text("aw_cond", size=sz["cond"], color="#D9FFFFFF", margin_top="2dp")
    s += text("aw_range", size=sz["range"], color="#C4FFFFFF", margin_top="1dp")
    s += metric_grid("t", sz)
    s += tips_header(sz)
    s += linear("aw_tips", orientation="vertical", margin_top="3dp")
    for i in range(sz["tips"]):
        s += tip_stack_row(i, sz, first=(i == 0))
    s += CLOSE
    s += tip_compact_row("5dp")
    s += CLOSE
    s += empty_label()
    s += "</FrameLayout>\n"
    return s


def build_tile() -> str:
    sz = T["tile"]
    s = header_comment("桌面小组件 · 主档（4×2）—— 「主面板」", [
        "3~4 格宽 × 2 格高的主力档位，排布对齐 App 内天气面板的「顶部区」：",
        "  顶栏（城市 · AQI · 观测时刻）",
        "  左：大温度 + 天气现象 + 今日高低温    右：2×2 指标格",
        "  底：2 条通栏提示行（危险优先，级别色圆点 + 正文）",
        "",
        "为什么提示只放 2 条而不是 4 条：面板里每条建议占一整行、正文 12sp；",
        "组件高度只有 2 格，塞 4 行会把每条压成 1 行 8sp —— 那正是上一版的「挤」。",
        "宁可少给两条，也要让给出的两条读得舒服（完整列表点进 App 看）。",
        "",
        "⚠ 硬约束同 compact 档。",
    ])
    s += open_layout("aw_root", "aw_bg_cloudy")
    s += linear("aw_pad", orientation="vertical", height="match_parent",
                pad_start="11dp", pad_end="11dp", pad_v="8dp")
    s += linear("aw_header", orientation="horizontal",
                gravity="center_vertical", baseline=True)
    s += text("aw_city", size="11sp", color="#F2FFFFFF", bold=True,
              max_width="120dp", ellipsize=True)
    s += aqi_pill(sz)
    s += text("aw_spacer", size="1sp", width="0dp", height="1dp", weight="1")
    s += text("aw_observed", size="8.5sp", color="#B8FFFFFF")
    s += CLOSE
    s += linear("aw_main", orientation="horizontal", weight="1",
                gravity="center_vertical", baseline=True, margin_top="2dp")
    s += linear("aw_left", orientation="vertical", width="0dp", weight="1.12",
                gravity="center_vertical", margin_end="10dp")
    s += hero_block("b", sz)
    s += text("aw_b_cond", size=sz["cond"], color="#E0FFFFFF", margin_top="2dp")
    s += text("aw_b_range", size=sz["range"], color="#C4FFFFFF", margin_top="1dp")
    s += CLOSE
    s += metric_grid("b", sz)
    s += CLOSE
    s += linear("aw_tips", orientation="vertical", margin_top="7dp")
    for i in range(sz["tips"]):
        s += tip_stack_row(i, sz, first=(i == 0))
    s += CLOSE
    s += tip_compact_row("6dp")
    s += CLOSE
    s += empty_label()
    s += "</FrameLayout>\n"
    return s


ALLOWED_TAGS = {"FrameLayout", "LinearLayout", "TextView"}


def self_check(name: str, xml: str) -> list[str]:
    """产物自检：标签闭合 + 只用白名单控件。

    这两个问题都只在**运行时**才炸（组件白块），编译期全是绿的，
    所以必须在生成时就挡住。

    关键：**先把注释剥掉再扫**。注释里为了说明约束会写到 `<View>`、
    `<selector>` 这些字面量，不剥的话检查器会把自己的说明文档当成违规 ——
    这不是假警报那么简单：一旦为绕开它而把说明删掉，约束就又没人记得了。
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
    # 背景占位：大档用 aw_bg_*，小档（2×2 / 4×1）用圆角更小的 aw_bgs_*
    if not re.search(r'android:background="@drawable/aw_bg s? _', body) and \
            '@drawable/aw_bg_' not in body and '@drawable/aw_bgs_' not in body:
        problems.append(f"{name}: 根布局缺少天气背景占位")
    if "<selector" in body or "<ripple" in body:
        problems.append(f"{name}: 用了 <selector>/<ripple>，RemoteViews 不支持")
    return problems


def main() -> int:
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out_dir = os.path.join(root, "android", "app", "src", "main", "res", "layout")
    if not os.path.isdir(out_dir):
        print(f"找不到 layout 目录：{out_dir}", file=sys.stderr)
        return 1

    files = {
        "aw_widget_compact.xml": build_compact(),
        "aw_widget_row.xml": build_row(),
        "aw_widget_tall.xml": build_tall(),
        "aw_widget_tile.xml": build_tile(),
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

    legacy = os.path.join(out_dir, "aprslocus_weather_widget.xml")
    if os.path.exists(legacy):
        os.remove(legacy)
        print("已删除旧的 aprslocus_weather_widget.xml（被 4 个尺寸档取代）")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
