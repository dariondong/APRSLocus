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
    android/app/src/main/res/drawable/aw_segday_*.xml      短波组件的**白天段**（亮：满色，4 档）
    android/app/src/main/res/drawable/aw_segnight_*.xml    短波组件的**夜晚段**（暗：压暗，4 档）

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
# 进度条段的圆角 4dp（与 chip 同量级）
RADIUS_SEG = 4
# 「现在」段顶部那颗小白点：标出当前时段落在哪一段

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


def lit(hex6: str) -> str:
    """把基准色向白提亮 35%（夜间档用）。

    与 Dart 的 widgetTipTextArgb / 生成 values-night 时用的公式**同一套整数运算**。
    夜间深底上基准色偏暗，大面积填充也一样 —— 所以段与文字在夜间都走提亮色。

    公式只此一份：下面 values-night 的 aw_q_* 也调它，免得两处各写一遍再漂移。
    """
    r, g, b = (int(hex6[i:i + 2], 16) for i in (1, 3, 5))
    m = lambda c: round(c * 0.65 + 255 * 0.35)   # noqa: E731
    return "#%02X%02X%02X" % (m(r), m(g), m(b))


def mix(hex6: str, target: str, t: float) -> str:
    """把 [hex6] 向 [target] 混合 t（0~1）。用来做「压暗」与「压暗到卡片底色」。

    为什么不用 HSL 调亮度：这里的语义是「向某个底色靠拢」——
    浅色卡片上要靠向深色（变暗），深色卡片上要靠向卡片底色（变闷）。
    直接按通道线性混合，两个方向都是同一段代码、结果可预期。
    """
    a = [int(hex6[i:i + 2], 16) for i in (1, 3, 5)]
    b = [int(target[i:i + 2], 16) for i in (1, 3, 5)]
    return "#%02X%02X%02X" % tuple(
        round(a[k] * (1 - t) + b[k] * t) for k in range(3))


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
    # ── 短波组件的「日/夜进度条」（定稿 M1，2026-09-18）──────────────
    #
    # 每个波段两段：左=日间、右=夜间；**当前时段那一段用实色 + 顶部小白点**，
    # 另一段用淡底。颜色只表达「该时段这个波段的通联程度」。
    #
    # 为什么必须预生成、而不是运行时染色：段是 **TextView**，而
    # `setColorFilter` **只存在于 ImageView**（View/TextView 都没有）——
    # v1.6.114 的线上事故正是把 setColorFilter 用在 TextView 上，抛异常后
    # **整个组件报废**。TextView 换底只能用 `setBackgroundResource`（View 的方法），
    # 所以每个条件各给两张（实色 / 淡底）。
    #
    # 颜色用**基准色**（白底上提亮色几乎看不见）；夜间档用提亮版（深底上基准色偏暗）。
    # 文字色不写在 drawable 里（drawable 只管底），由 Kotlin setTextColor 设成
    # 条件色 —— 这样一份色板（Dart 的 hfQualityColor）管到底。
    QUALITY = {"good": "#16A34A", "fair": "#D97706",
               "poor": "#E11D48", "closed": "#94A3B8"}
    #
    # **亮度表达「时段」而不是「现在」**（2026-09-18 改）：原来是「当前时段实色、
    # 另一段淡底」，于是夜里那一段反而最亮 —— 用户反馈「反直觉：亮的应该是白天、
    # 暗的应该是晚上」。现在改成：**白天段=满色（亮）/ 夜晚段=压暗（暗）**，
    # 「现在」改由段内顶部的小白点（独立 ImageView，Kotlin 控可见性）表示。
    for name, col in QUALITY.items():
        # 白天：满色 —— 在白底上就是「亮」
        files[f"drawable/aw_segday_{name}.xml"] = solid_xml(
            f"白天段（{name}）：{col} 满色（亮）", col, RADIUS_SEG)
        # 夜晚：向深色压暗 52% —— 同一个色相、明显更暗，一眼分得出是「晚上」
        files[f"drawable/aw_segnight_{name}.xml"] = solid_xml(
            f"夜晚段（{name}）：{col} 压暗 52%（向 #0B1220 混）",
            mix(col, "#0B1220", 0.52), RADIUS_SEG)

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
    # 注：曾经有 aw_sun / aw_moon 两个色值给「条外的太阳/月亮图标」染色。
    # 图标挪进条内之后改为**不染色**（白天段满色、夜晚段压暗，白图够清楚），
    # 于是这两个色连同两处 setColorFilter 一起删了 —— 少两个死资源、少两处
    # 只在运行期才爆的调用。
    for qualifier, (c_ink, c_slate, c_line, c_surf) in (
            ("values", (ink, slate, line, surf)),
            ("values-night", (ink_night, slate_night, line_night, surf_night))):
        # chip 的文字色：浅色底上用**基准色**（够深、在白底上清晰）；
        # 夜间深底上基准色偏暗，改用提亮版（lit()，与段的实色同源）。
        q_src = {"aw_q_good": "#16A34A", "aw_q_fair": "#D97706",
                 "aw_q_poor": "#E11D48", "aw_q_closed": "#94A3B8"}
        rows = [
            f'    <color name="{k}">'
            f'{v if qualifier == "values" else lit(v)}</color>'
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

    # 夜间：淡底要更浓（30% 在近白底上够看，但 #1E2530 深底上几乎不可见，提到 45%）；
    # 实色段改用**提亮版**（深底上基准色偏暗，见 lit()）。
    # 提亮值与 values-night/widget_colors.xml 的 aw_q_* 同源（都由 lit() 算）。
    #
    # 深色卡片上「压暗」会直接看不见，所以夜间的对比改成**闷**：
    # 白天段用提亮色（在深底上才够亮），夜晚段向卡片底色压 62%（变闷、明显更暗）。
    for name, col in QUALITY.items():
        files[f"drawable-night/aw_segday_{name}.xml"] = solid_xml(
            f"白天段（夜间档，{name}）：提亮色 {lit(col)}（深底上基准色偏暗）",
            lit(col), RADIUS_SEG)
        files[f"drawable-night/aw_segnight_{name}.xml"] = solid_xml(
            f"夜晚段（夜间档，{name}）：向卡片底色压 62%（变闷，与白天段拉开）",
            mix(lit(col), "#243040", 0.62), RADIUS_SEG)

    return files


def _luma(xml: str) -> float:
    """取产物里第一个 <solid> 的感知亮度（0-255）。

    权重用 ITU-R BT.601（0.299/0.587/0.114）—— 只用来比较「谁更亮」，
    不需要精确的感知模型。
    """
    for ln in xml.splitlines():
        ln = ln.strip()
        if ln.startswith("<solid") and "#" in ln:
            hexs = ln.split("#")[1].split('"')[0]
            if len(hexs) == 8:      # #AARRGGBB → 只看颜色部分
                hexs = hexs[2:]
            if len(hexs) != 6:
                return -1.0
            r, g, b = (int(hexs[i:i + 2], 16) for i in (0, 2, 4))
            return 0.299 * r + 0.587 * g + 0.114 * b
    return -1.0


def self_check(files: dict) -> list:
    """产物自检：必需的零件都在，且背景真是一张渐变。"""
    problems = []
    # 单行档的竖分隔、AQI 胶囊底、圆点：这三个是布局会引用的，缺了就是运行时
    # ResourceNotFound（组件白块），所以生成时就得确认在产物里。
    for need in ("drawable/aw_sep.xml", "drawable/aw_pill.xml",
                 "drawable/aw_dot.xml"):
        if need not in files:
            problems.append(f"{need} 缺失")
    # 短波组件的日/夜段：布局与 Kotlin 都静态引用它们，缺一张就是运行时
    # ResourceNotFound（组件变白块）。同时盯住两条**语义**约束 —— 抄错一个
    # 十六进制值不会报错，只会在夜间档上变成隐形或看不清：
    #   ① **白天段必须比夜晚段亮**（用户明确要求「亮的是白天、暗的是晚上」）——
    #      这条抄错颜色不会报错，只会让语义反过来，所以必须算亮度来判；
    #   ② 两段都必须存在（布局静态引用它们，缺一张就是运行时白块）。
    for name in ("good", "fair", "poor", "closed"):
        for qualifier, tag in (("drawable", "浅色"), ("drawable-night", "夜间")):
            dkey = f"{qualifier}/aw_segday_{name}.xml"
            nkey = f"{qualifier}/aw_segnight_{name}.xml"
            for key in (dkey, nkey):
                if key not in files:
                    problems.append(f"{key} 缺失（布局引用了它）")
            if dkey not in files or nkey not in files:
                continue
            l_day, l_night = _luma(files[dkey]), _luma(files[nkey])
            if l_day <= l_night + 24:
                problems.append(
                    f"aw_seg*_{name}（{tag}）白天段亮度 {l_day:.0f} 必须明显高于"
                    f"夜晚段 {l_night:.0f} —— 「亮的是白天、暗的是晚上」")

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
