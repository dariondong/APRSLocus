#!/usr/bin/env python3
"""生成 Android 桌面小组件的背景 / 卡片 / 圆点 drawable。

**为什么要用脚本生成而不是手写**：组件背景渐变必须和天气面板
（``lib/weather.dart`` 的 ``_fxGradient()``）**逐色一致**，否则会出现
「面板是深蓝雨夜、桌面组件是浅灰」这种一眼就能看出来的割裂。
调色板写在这里一份，改动时改这里 + 面板即可，不要两头手抄。

产物：
    android/app/src/main/res/drawable/aw_bg_*.xml          天气背景（大圆角）
    android/app/src/main/res/drawable/aw_bgs_*.xml         天气背景（小圆角，2×2 / 4×1 档用）
    android/app/src/main/res/drawable-night/aw_bg*.xml     深色版（系统夜间模式）
    android/app/src/main/res/drawable/aw_pill.xml          AQI 胶囊底
    android/app/src/main/res/drawable/aw_dot.xml           提示行圆点（纯白，运行时 setColorFilter 染级别色）
    android/app/src/main/res/drawable/aw_sep.xml           单行档的竖分隔线

**为什么要 4 张记色圆点，而不是运行时染色**（这是踩过的坑，记下来免得重犯）：

最初写的是 ``setInt(dot, "setColorFilter", color)``。``setColorFilter`` **只存在于
ImageView** —— ``View`` 和 ``TextView`` 都没有（已对 AOSP 源码核实：View 0 处、
TextView 0 处、ImageView 3 处）。而圆点**只能**是 TextView（RemoteViews 不允许
原生 ``<View>``，会抛 "android.view.View is not allowed"）。于是那次调用抛
``NoSuchMethodException`` → ``RemoteViews.apply()`` 抛 ``ActionException`` →
启动器直接显示「小组件加载失败」。**整个组件报废**，不是「颜色不生效」那种小毛病。

「换 drawable」是 RemoteViews 里唯一可靠的换色手段（与危险行换红底同一招）。

用法：
    python3 tool/gen_app_widget_drawables.py
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

# 圆角：主档尺寸较大（约 320×160dp），20dp 合适；2×2 / 4×1 更小，用 16dp
# 才不会显得「圆得只剩个球」。与面板 Container 的 circular(24) 是同一种取向。
RADIUS_LARGE = 20
RADIUS_SMALL = 16
RADIUS_TILE = 11
RADIUS_PILL = 999

HEADER = '<?xml version="1.0" encoding="utf-8"?>\n'
NS = '<shape xmlns:android="http://schemas.android.com/apk/res/android"'


def bg_xml(comment: str, start: str, end: str, radius: int) -> str:
    """竖向线性渐变 + 大圆角。"""
    return (
        f'{HEADER}{NS} android:shape="rectangle">\n'
        f"    <!-- {comment} -->\n"
        f'    <corners android:radius="{radius}dp" />\n'
        f"    <!-- angle=270：从上到下。Android 角度里 0=左→右、90=下→上、270=上→下 -->\n"
        f"    <gradient\n"
        f'        android:angle="270"\n'
        f'        android:type="linear"\n'
        f'        android:startColor="{start}"\n'
        f'        android:endColor="{end}" />\n'
        f"</shape>\n"
    )


def solid_xml(comment: str, color: str, radius: int) -> str:
    """圆角矩形纯色底。radius>=999 时输出 999dp（等效胶囊）。"""
    r = "999dp" if radius >= 999 else f"{radius}dp"
    return (
        f'{HEADER}{NS} android:shape="rectangle">\n'
        f"    <!-- {comment} -->\n"
        f'    <corners android:radius="{r}" />\n'
        f'    <solid android:color="{color}" />\n'
        f"</shape>\n"
    )


def dot_xml(comment: str, color: str) -> str:
    """圆点（oval）。

    [color] 必须显式传入。曾经这里把 #FFFFFF 写死过 —— 结果 aw_dot_danger.xml
    的注释写着 #EC6C88、实际渲染是白色。注释与产物不一致比没有注释更坏：
    看代码的人会以为颜色已经对了，于是不去查。下面的 self_check 专门盯这一点。
    """
    return (
        f'{HEADER}{NS} android:shape="oval">\n'
        f"    <!-- {comment} -->\n"
        f'    <solid android:color="{color}" />\n'
        f"</shape>\n"
    )


def build_all() -> dict:
    """返回 {相对路径: 内容}。"""
    files: dict[str, str] = {}

    for qualifier, table in (("drawable", LIGHT), ("drawable-night", DARK)):
        for name, (start, end) in table.items():
            files[f"{qualifier}/aw_bg_{name}.xml"] = bg_xml(
                f"天气档位：{name}（与 lib/weather.dart 的 _fxGradient 逐色对应）",
                start, end, RADIUS_LARGE)
            files[f"{qualifier}/aw_bgs_{name}.xml"] = bg_xml(
                f"天气档位：{name}（小尺寸版，圆角 {RADIUS_SMALL}dp；"
                f"2×2 / 4×1 档用）",
                start, end, RADIUS_SMALL)

    files["drawable/aw_pill.xml"] = solid_xml(
        "AQI 胶囊底（白 16%）", "#29FFFFFF", RADIUS_PILL)
    files["drawable/aw_bg_white.xml"] = solid_xml(
        "短波组件的白底（不透明纯白 + 圆角）", "#FFFFFFFF", RADIUS_LARGE)
    files["drawable/aw_sep.xml"] = solid_xml(
        "单行档的竖分隔线（白 20%，1dp 宽）", "#33FFFFFF", 0)
    files["drawable/aw_dot.xml"] = dot_xml(
        "提示行圆点（纯白）。运行时由 WeatherWidgetProvider 用 "
        "setColorFilter 染成建议级别色 —— 圆点是 ImageView，而 "
        "setColorFilter 只存在于 ImageView（View/TextView 都没有），"
        "这正是 v1.6.114 线上事故的成因：当时圆点是 TextView。",
        "#FFFFFF")

    return files


def self_check(files: dict) -> list:
    """产物自检：必需的零件都在，且背景真是一张渐变。"""
    problems = []
    # 单行档的竖分隔、AQI 胶囊底、圆点：这三个是布局会引用的，缺了就是运行时
    # ResourceNotFound（组件白块），所以生成时就得确认在产物里。
    for need in ("drawable/aw_sep.xml", "drawable/aw_pill.xml",
                 "drawable/aw_dot.xml"):
        if need not in files:
            problems.append(f"{need} 缺失")
    # **天气档位**的背景必须真是两色渐变。
    # 注意这里按「是不是档位名」判断，而不是 `"aw_bg" in key` —— 后者会把
    # aw_bg_white 也算进去（那是纯色底，本来就该没有 gradient），
    # 于是一加白底就误报。判据要贴着语义写，别贴名字前缀写。
    for qualifier in ("drawable", "drawable-night"):
        for kind in LIGHT:
            key = f"{qualifier}/aw_bg_{kind}.xml"
            if key not in files:
                problems.append(f"{key} 缺失")
            elif "gradient" not in files[key]:
                problems.append(f"{key} 没有 gradient 节点")
            skey = f"{qualifier}/aw_bgs_{kind}.xml"
            if skey in files and "gradient" not in files[skey]:
                problems.append(f"{skey} 没有 gradient 节点")
    return problems


def main() -> int:
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    res = os.path.join(root, "android", "app", "src", "main", "res")
    if not os.path.isdir(res):
        print(f"找不到 res 目录：{res}", file=sys.stderr)
        return 1

    files = build_all()

    problems = self_check(files)
    if problems:
        print("自检未通过，未写入任何文件：", file=sys.stderr)
        for p in problems:
            print(f"  ✗ {p}", file=sys.stderr)
        return 1

    for rel, content in files.items():
        path = os.path.join(res, *rel.split("/"))
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8") as f:
            f.write(content)

    for rel in sorted(files):
        print(f"res/{rel}")
    print(f"\n共生成 {len(files)} 个文件")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
