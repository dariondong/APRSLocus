#!/usr/bin/env python3
"""生成 Android 桌面小组件的背景/卡片 drawable（4 个尺寸档 + 共用零件）。

**为什么要用脚本生成而不是手写**：组件背景渐变必须和天气面板
（``lib/weather.dart`` 的 ``_fxGradient()``）**逐色一致**，否则会出现
「面板是深蓝雨夜、桌面组件是浅灰」这种一眼就能看出来的割裂。
调色板写在这里一份，改动时改这里 + 面板即可，不要两头手抄。

4 个尺寸档（与 WeatherWidgetProvider 的 LAYOUT_BY_TIER 对应）：
    compact  2×2 / 2×3   温度 + 天气 + 1 条最要紧的提示
    row      4×1         一条通栏：天气 + 提示
    tall     2×4         「小面板」：温度 + 天气 + 指标 + 3~5 条提示堆叠
    tile     4×2         「主面板」：与 App 内天气面板同构的海报式排布

用法：
    python3 tool/gen_app_widget_drawables.py

产物：
    android/app/src/main/res/drawable/aw_bg_*.xml          浅色（默认）
    android/app/src/main/res/drawable-night/aw_bg_*.xml    深色（系统夜间模式）
    android/app/src/main/res/drawable/aw_tile.xml          指标格玻璃底
    android/app/src/main/res/drawable/aw_tile_danger.xml   危险提示行底
    android/app/src/main/res/drawable/aw_pill.xml          AQI 胶囊底
    android/app/src/main/res/drawable/aw_dot.xml            提示行旁的级别色圆点（染成建议级别色）
"""

import os
import sys

# ── 调色板：与 lib/weather.dart::_fxGradient() 的 light / darkc 两张表一字不差 ──
LIGHT = {
    "clear":    ("#2E86D6", "#79C4F2"),
    "cloudy":   ("#4A6E93", "#87AACB"),
    "overcast": ("#56677A", "#8C9BAB"),
    "rain":     ("#36506B", "#63809B"),
    "storm":    ("#232F3E", "#4A5B70"),
    "snow":     ("#5C7FA8", "#A8C6E2"),
    "fog":      ("#6C7A87", "#A3AEB9"),
}
DARK = {
    "clear":    ("#26374A", "#141F2E"),
    "cloudy":   ("#2A3444", "#161D28"),
    "overcast": ("#313B49", "#1A212B"),
    "rain":     ("#1F3143", "#0F1924"),
    "storm":    ("#232E3A", "#0D131B"),
    "snow":     ("#2C3642", "#171E27"),
    "fog":      ("#2B3138", "#171B21"),
}

# 圆角：主面板尺寸较大（约 320×160dp），20dp 合适；2×2 / 4×1 更小，用 16dp
# 才不会显得「圆得只剩个球」。这与面板 Container 的 circular(24) 是同一种观感取向。
RADIUS_LARGE = 20
RADIUS_SMALL = 16
RADIUS_TILE = 11
RADIUS_PILL = 999

HEADER = '<?xml version="1.0" encoding="utf-8"?>\n'
NS = '<shape xmlns:android="http://schemas.android.com/apk/res/android"'


def bg(name: str, start: str, end: str) -> str:
    """天气背景：竖向线性渐变 + 大圆角。"""
    return (
        f"{HEADER}{NS} android:shape=\"rectangle\">\n"
        f"    <!-- 天气档位：{name}（与 lib/weather.dart 的 _fxGradient 逐色对应） -->\n"
        f"    <corners android:radius=\"{RADIUS_LARGE}dp\" />\n"
        f"    <!-- angle=270：从上到下。Android 角度里 0=左→右、90=下→上、270=上→下 -->\n"
        f"    <gradient\n"
        f"        android:angle=\"270\"\n"
        f"        android:type=\"linear\"\n"
        f"        android:startColor=\"{start}\"\n"
        f"        android:endColor=\"{end}\" />\n"
        f"</shape>\n"
    )


def solid(color: str, radius: int, comment: str) -> str:
    r = "999dp" if radius >= 999 else f"{radius}dp"
    return (
        f"{HEADER}{NS} android:shape=\"rectangle\">\n"
        f"    <!-- {comment} -->\n"
        f"    <corners android:radius=\"{r}\" />\n"
        f"    <solid android:color=\"{color}\" />\n"
        f"</shape>\n"
    )


def dot(comment: str) -> str:
    """提示行左侧的级别色圆点（底色纯白，运行时染色）。"""
    return (
        f"{HEADER}{NS} android:shape=\"oval\">\n"
        f"    <!-- {comment} -->\n"
        f"    <solid android:color=\"#FFFFFF\" />\n"
        f"</shape>\n"
    )


def main() -> int:
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    res = os.path.join(root, "android", "app", "src", "main", "res")
    if not os.path.isdir(res):
        print(f"找不到 res 目录：{res}", file=sys.stderr)
        return 1

    written = []

    # 浅色 + 深色各一套天气渐变
    for qualifier, table in (("drawable", LIGHT), ("drawable-night", DARK)):
        out = os.path.join(res, qualifier)
        os.makedirs(out, exist_ok=True)
        for name, (start, end) in table.items():
            p = os.path.join(out, f"aw_bg_{name}.xml")
            with open(p, "w", encoding="utf-8") as f:
                f.write(bg(name, start, end))
            written.append(p)

    plain = os.path.join(res, "drawable")
    os.makedirs(plain, exist_ok=True)

    # 小的两个尺寸档（2×2 / 4×1）用更小的圆角版本，避免在矮组件上显得过圆
    for name, (start, end) in LIGHT.items():
        p = os.path.join(plain, f"aw_bgs_{name}.xml")
        with open(p, "w", encoding="utf-8") as f:
            f.write(
                f"{HEADER}{NS} android:shape=\"rectangle\">\n"
                f"    <!-- 天气档位：{name}（小尺寸版，圆角 {RADIUS_SMALL}dp） -->\n"
                f"    <corners android:radius=\"{RADIUS_SMALL}dp\" />\n"
                f"    <gradient\n"
                f"        android:angle=\"270\"\n"
                f"        android:type=\"linear\"\n"
                f"        android:startColor=\"{start}\"\n"
                f"        android:endColor=\"{end}\" />\n"
                f"</shape>\n"
            )
        written.append(p)

    night = os.path.join(res, "drawable-night")
    for name, (start, end) in DARK.items():
        p = os.path.join(night, f"aw_bgs_{name}.xml")
        with open(p, "w", encoding="utf-8") as f:
            f.write(
                f"{HEADER}{NS} android:shape=\"rectangle\">\n"
                f"    <!-- 天气档位：{name}（小尺寸版，圆角 {RADIUS_SMALL}dp） -->\n"
                f"    <corners android:radius=\"{RADIUS_SMALL}dp\" />\n"
                f"    <gradient\n"
                f"        android:angle=\"270\"\n"
                f"        android:type=\"linear\"\n"
                f"        android:startColor=\"{start}\"\n"
                f"        android:endColor=\"{end}\" />\n"
                f"</shape>\n"
            )
        written.append(p)

    parts = [
        ("aw_tile.xml", solid("#14FFFFFF", RADIUS_TILE,
                              "指标格玻璃底（白 8%）")),
        ("aw_tile_danger.xml", solid("#3DE11D48", RADIUS_TILE,
                                     "危险级提示行底（红 24%，与面板 _tipRow 同色）")),
        ("aw_pill.xml", solid("#29FFFFFF", RADIUS_PILL, "AQI 胶囊底（白 16%）")),
        ("aw_dot.xml", dot(
            "提示行左侧的级别色小圆点。与面板 _tipRow 的 6dp 圆点同尺寸；"
            "底色纯白，运行时用 setColorFilter 染成建议级别色。"
            "为什么不用「竖色条」：竖条要 height=match_parent 才能跟满两行文字，"
            "而 match_parent 高度在 wrap_content 的横向 LinearLayout 里测量不可靠"
            "（RemoteViews 里一旦测成 0 高，色条就整根消失）。圆点没这个风险。")),
    ]
    for fname, content in parts:
        p = os.path.join(plain, fname)
        with open(p, "w", encoding="utf-8") as f:
            f.write(content)
        written.append(p)

    for p in written:
        print(os.path.relpath(p, root))
    print(f"\n共生成 {len(written)} 个文件")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
