#!/usr/bin/env python3
"""生成 Android 桌面小组件的背景/卡片 drawable。

**为什么要用脚本生成而不是手写**：组件背景渐变必须和天气面板
（``lib/weather.dart`` 的 ``_fxGradient()``）**逐色一致**，否则会出现
「面板是深蓝雨夜、桌面组件是浅灰」这种一眼就能看出来的割裂。
调色板写在这里一份，改动时改这里 + 面板即可，不要两头手抄。

用法：
    python3 tool/gen_app_widget_drawables.py

产物：
    android/app/src/main/res/drawable/aw_bg_*.xml        浅色（默认）
    android/app/src/main/res/drawable-night/aw_bg_*.xml  深色（系统夜间模式）
    android/app/src/main/res/drawable/aw_tile.xml        指标格玻璃底
    android/app/src/main/res/drawable/aw_tile_danger.xml 危险提示格底
    android/app/src/main/res/drawable/aw_pill.xml        AQI 胶囊底
"""

import os
import re
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

# 圆角半径：与面板 Container 的 BorderRadius.circular(24) 同量级，
# 但组件自身尺寸小（约 250×110dp），24dp 会显得过于圆润，取 20dp。
RADIUS_BG = 20
RADIUS_TILE = 11
RADIUS_PILL = 999

HEADER = '<?xml version="1.0" encoding="utf-8"?>\n'
SHAPE_NS = '<shape xmlns:android="http://schemas.android.com/apk/res/android"'


def bg(name: str, start: str, end: str) -> str:
    """天气背景：竖向线性渐变 + 大圆角。"""
    return (
        f"{HEADER}"
        f"{SHAPE_NS} android:shape=\"rectangle\">\n"
        f"    <!-- 天气档位：{name}（与 lib/weather.dart 的 _fxGradient 对应） -->\n"
        f"    <corners android:radius=\"{RADIUS_BG}dp\" />\n"
        f"    <!-- angle=270：从上到下。Android 的角度里 0=左→右、90=下→上、270=上→下 -->\n"
        f"    <gradient\n"
        f"        android:angle=\"270\"\n"
        f"        android:type=\"linear\"\n"
        f"        android:startColor=\"{start}\"\n"
        f"        android:endColor=\"{end}\" />\n"
        f"</shape>\n"
    )


def solid(color: str, radius: int, comment: str) -> str:
    return (
        f"{HEADER}"
        f"{SHAPE_NS} android:shape=\"rectangle\">\n"
        f"    <!-- {comment} -->\n"
        f"    <corners android:radius=\"{radius}dp\" />\n"
        f"    <solid android:color=\"{color}\" />\n"
        f"</shape>\n"
    )


def main() -> int:
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    res = os.path.join(root, "android", "app", "src", "main", "res")
    if not os.path.isdir(res):
        print(f"找不到 res 目录：{res}", file=sys.stderr)
        return 1

    written = []

    for qualifier, table in (("drawable", LIGHT), ("drawable-night", DARK)):
        out = os.path.join(res, qualifier)
        os.makedirs(out, exist_ok=True)
        for name, (start, end) in table.items():
            path = os.path.join(out, f"aw_bg_{name}.xml")
            with open(path, "w", encoding="utf-8") as f:
                f.write(bg(name, start, end))
            written.append(path)

    plain = os.path.join(res, "drawable")
    os.makedirs(plain, exist_ok=True)

    # 玻璃质感的格子底：白色低透明度（深色/浅色都成立，因为底下永远是渐变）
    path = os.path.join(plain, "aw_tile.xml")
    with open(path, "w", encoding="utf-8") as f:
        f.write(solid("#14FFFFFF", RADIUS_TILE, "指标格 / 提示格的玻璃底（白 8%）"))
    written.append(path)

    path = os.path.join(plain, "aw_tile_danger.xml")
    with open(path, "w", encoding="utf-8") as f:
        f.write(solid("#3DE11D48", RADIUS_TILE, "危险级提示格底（红 24%，与面板 _tipRow 同色）"))
    written.append(path)

    path = os.path.join(plain, "aw_pill.xml")
    with open(path, "w", encoding="utf-8") as f:
        f.write(solid("#29FFFFFF", RADIUS_PILL, "AQI 胶囊底（白 16%）"))
    written.append(path)

    for p in written:
        print(os.path.relpath(p, root))
    print(f"\n共生成 {len(written)} 个文件")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
