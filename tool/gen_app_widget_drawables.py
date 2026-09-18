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
    android/app/src/main/res/drawable/aw_track_*.xml       短波组件的条件色带（淡底 + 左端色标，4 色）

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
# chip 圆角 4dp：比胶囊方、比直角柔，与面板的小标签同量级
RADIUS_CHIP = 4
# 色带圆角 3dp：它是一条长条而不是小块，圆角大了会把左端色标挤变形
RADIUS_TRACK = 3
# 色带左端色标的宽高（色标比色带矮且居中 → 四角不会被色带的圆角切到）
TRACK_BAR_W = "2.5dp"
TRACK_BAR_H = "9dp"

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


def track_xml(comment: str, color: str, fill_alpha: int) -> str:
    """传播条件「色带」：淡色圆角底 + 左端一道实色竖标。

    为什么是**一张 layer-list**、而不是「一个底 + 一个 2.5dp 的子 View」：
    RemoteViews 不允许原生 `<View>`，色标只能用 TextView 或 ImageView 冒充 ——
    那就要多一个控件、多一个 id、多一行 setBackgroundResource，每个都是只在
    运行期才爆的地方。一张 layer-list 把两层合成一个背景，于是每格仍然只是
    **一个 TextView**：setBackgroundResource 换色带、setTextColor 换字色，
    这两个方法在 View/TextView 上**确实存在** —— 对照 setColorFilter 只存在于
    ImageView 那个坑（v1.6.114 线上事故）。

    [color] 为 #RRGGBB；[fill_alpha] 是淡底的不透明度（0-255）—— 浅色底上要淡
    （14%），深色底上要浓（22%），否则 #1E2530 这种近黑底上几乎看不见。
    """
    return (
        f'{HEADER}<layer-list '
        f'xmlns:android="http://schemas.android.com/apk/res/android">\n'
        f"    <!-- {comment} -->\n"
        f"    <!-- ① 淡色圆角底（色带本体） -->\n"
        f"    <item>\n"
        f'        <shape android:shape="rectangle">\n'
        f'            <corners android:radius="{RADIUS_TRACK}dp" />\n'
        f'            <solid android:color="#{fill_alpha:02X}{color[1:]}" />\n'
        f"        </shape>\n"
        f"    </item>\n"
        f"    <!-- ② 左端实色竖标：颜色集中在这 2.5dp 上，四行扫下来是一条竖线 -->\n"
        f"    <item\n"
        f'        android:width="{TRACK_BAR_W}"\n'
        f'        android:height="{TRACK_BAR_H}"\n'
        f'        android:gravity="left|center_vertical">\n'
        f'        <shape android:shape="rectangle">\n'
        f'            <corners android:radius="1.5dp" />\n'
        f'            <solid android:color="{color}" />\n'
        f"        </shape>\n"
        f"    </item>\n"
        f"</layer-list>\n"
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
    # ── 短波组件的「条件色带」（定稿 F2，2026-09-18 重做）──────────────
    #
    # 为什么必须预生成 4 张、而不是运行时染色：色带是 **TextView**，而
    # `setColorFilter` **只存在于 ImageView**（View/TextView 都没有）——
    # v1.6.114 的线上事故正是把 setColorFilter 用在 TextView 上，抛异常后
    # **整个组件报废**。TextView 换底只能用 `setBackgroundResource`（View 的方法），
    # 所以四个条件各给一张 drawable。
    #
    # 颜色用**基准色**：白底上提亮色（提亮 35%）几乎看不见。
    # 文字色不写在 drawable 里（drawable 只管底），由 Kotlin setTextColor 设成
    # 条件基本色 —— 这样一份色板（Dart 的 hfQualityColor）管到底。
    QUALITY = {"good": "#16A34A", "fair": "#D97706",
               "poor": "#E11D48", "closed": "#94A3B8"}
    for name, col in QUALITY.items():
        files[f"drawable/aw_track_{name}.xml"] = track_xml(
            f"传播条件色带：{name}（{col} 淡色 14% + 左端 {TRACK_BAR_W} 色标）；"
            f"文字色由 Kotlin 设为同色系基本色",
            col, 0x24)

    # 底走 @color/aw_surface：浅色白、夜间 #1E2530 ——
    # drawable 里引 @color 是允许的，于是**不用两套布局**就拿到暗黑底。
    files["drawable/aw_bg_white.xml"] = (
        f'{HEADER}<shape xmlns:android="http://schemas.android.com/apk/res/android"'
        f' android:shape="rectangle">\n'
        f'    <!-- 短波组件底：@color/aw_surface（浅色白 / 夜间深底） -->\n'
        f'    <corners android:radius="{RADIUS_LARGE}dp" />\n'
        f'    <solid android:color="@color/aw_surface" />\n</shape>\n')
    _unused_bg_white = solid_xml(
        "短波组件的白底（不透明纯白 + 圆角）", "#FFFFFFFF", RADIUS_LARGE)
    # 夜间也要有一份 —— 否则夜间档下 drawable-night/aw_bg_white.xml 不存在，
    # 只有 initialLayout 的第一帧会退回落日主题底色（约 200ms，随后被 Dart 推
    # 的渐变盖住）。既然发现了就补上，别留一个「night 目录里没有它」的特例。
    files["drawable-night/aw_bg_white.xml"] = (
        f'{HEADER}<shape xmlns:android="http://schemas.android.com/apk/res/android"'
        f' android:shape="rectangle">\n'
        f'    <!-- 短波组件底（夜间）：@color/aw_surface 会自动取到夜间值 -->\n'
        f'    <corners android:radius="{RADIUS_LARGE}dp" />\n'
        f'    <solid android:color="@color/aw_surface" />\n</shape>\n')
    files["drawable/aw_sep.xml"] = solid_xml(
        "单行档的竖分隔线（白 20%，1dp 宽）", "#33FFFFFF", 0)
    files["drawable/aw_dot.xml"] = dot_xml(
        "提示行圆点（纯白）。运行时由 WeatherWidgetProvider 用 "
        "setColorFilter 染成建议级别色 —— 圆点是 ImageView，而 "
        "setColorFilter 只存在于 ImageView（View/TextView 都没有），"
        "这正是 v1.6.114 线上事故的成因：当时圆点是 TextView。",
        "#FFFFFF")

    # ─── 暗黑模式 ────────────────────────────────────────────────────
    #
    # 做法：**颜色走 @color 引用**，values/ 与 values-night/ 各一份 ——
    # RemoteViews 由系统进程按当前配置解析资源，夜间模式会自动取到夜间值，
    # 代码里不需要判断。
    #
    # 为什么不把颜色写死在布局里：那样夜间模式只能靠「再来一套夜间布局」，
    # 而 RemoteViews 的布局是静态引用（initialLayout、RemoteViews(pkg, id)），
    # 无法按主题换布局文件。这是这次改造要解决的问题。
    # 三级前景与 theme.dart 的 C.* 对应。
    ink, ink_night = "#253044", "#E6EAF2"
    slate, slate_night = "#637083", "#AAB4C5"
    line, line_night = "#E5E9F0", "#2A3344"
    surf, surf_night = "#FFFFFF", "#1E2530"
    for qualifier, (c_ink, c_slate, c_line, c_surf) in (
            ("values", (ink, slate, line, surf)),
            ("values-night", (ink_night, slate_night, line_night, surf_night))):
        # chip 的文字色：浅色底上用**基准色**（够深、在白底上清晰）；
        # 夜间深底上基准色偏暗，改用**向白提亮 35%** 的版本。
        # 提亮公式与 Dart 的 widgetTipTextArgb 同一套整数运算。
        def _lit(hex6: str) -> str:
            r, g, b = (int(hex6[i:i + 2], 16) for i in (1, 3, 5))
            m = lambda c: round(c * 0.65 + 255 * 0.35)  # noqa: E731
            return "#%02X%02X%02X" % (m(r), m(g), m(b))

        q_src = {"aw_q_good": "#16A34A", "aw_q_fair": "#D97706",
                 "aw_q_poor": "#E11D48", "aw_q_closed": "#94A3B8"}
        rows = [
            f'    <color name="{k}">'
            f'{v if qualifier == "values" else _lit(v)}</color>'
            for k, v in q_src.items()
        ]
        rows += [
            f'    <color name="aw_ink">{c_ink}</color>',
            f'    <color name="aw_slate">{c_slate}</color>',
            f'    <color name="aw_line">{c_line}</color>',
            f'    <color name="aw_surface">{c_surf}</color>',
            # 空状态文字：主文字色 + 85% alpha（分开一个键，便于整体调）
            f'    <color name="aw_ink_dim">#D9{c_ink[1:]}</color>',
        ]
        files[f"{qualifier}/widget_colors.xml"] = (
            HEADER
            + "<!-- 小组件前景色。夜间变体在 values-night/，由系统按当前配置选择 -->\n"
            + "<resources>\n" + "\n".join(rows) + "\n</resources>\n")

    # 夜间色带的淡底要更浓：14% 压在近白底上够看，但 #1E2530 这种深底上
    # 几乎不可见，提到 22%。左端色标本就够浓，两档同一个值。
    for name, col in QUALITY.items():
        files[f"drawable-night/aw_track_{name}.xml"] = track_xml(
            f"传播条件色带（夜间）：{name}，淡色 22%"
            f"（深底上 14% 几乎不可见）", col, 0x38)

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
    # 短波组件的色带：布局静态引用它们，缺一张就是运行时 ResourceNotFound
    # （组件变白块）。同时盯住「夜间淡底必须比白天浓」—— 这条是**语义**约束，
    # 抄错一个十六进制值不会报错，只会在夜间档上变成隐形。
    for name in ("good", "fair", "poor", "closed"):
        for qualifier in ("drawable", "drawable-night"):
            key = f"{qualifier}/aw_track_{name}.xml"
            if key not in files:
                problems.append(f"{key} 缺失（布局引用了它）")
                continue
            if "layer-list" not in files[key]:
                problems.append(f"{key} 不是 layer-list（色带需要「底 + 色标」两层）")
            # 两层 item：淡底 + 左端色标
            if files[key].count("<item") < 2:
                problems.append(f"{key} 只有一层，缺少左端色标")
    for name in ("good", "fair", "poor", "closed"):
        day = files.get(f"drawable/aw_track_{name}.xml", "")
        night = files.get(f"drawable-night/aw_track_{name}.xml", "")
        # 取淡底那一行的 alpha（#AARRGGBB 的前两位）
        def _fill_alpha(x: str) -> int:
            for ln in x.splitlines():
                ln = ln.strip()
                if ln.startswith("<solid") and "#" in ln:
                    return int(ln.split("#")[1][:2], 16)
            return -1

        a_day, a_night = _fill_alpha(day), _fill_alpha(night)
        if not (0 <= a_day < a_night <= 255):
            problems.append(
                f"aw_track_{name} 夜间淡底（{a_night:#04x}）必须比白天"
                f"（{a_day:#04x}）浓 —— 否则夜间档上色带隐形")
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
