#!/usr/bin/env python3
"""把 Material 图标烘焙成 PNG —— 让桌面小组件用上**真正的图标**。

**为什么必须烘焙**（这是前三版难看与失败的根源）：

1. 组件进程里**没有 Flutter 的 Material 图标字体**（那是 app 的资源），所以
   最初只能用 emoji 凑 —— 而 emoji 根本不是面板的设计语言，一眼就不像。
2. RemoteViews **只认位图/XML drawable**，不认字体图标，也不认矢量图
   （`.svg` 与 VectorDrawable 都在白名单外）。
3. 但 RemoteViews 认 `ImageView` + PNG。所以正解是：**把字体图标预渲染成 PNG**。

于是图标与面板**同源**：都用 Flutter 自带的 `MaterialIcons-Regular.otf`，
码位直接取自 `packages/flutter/lib/src/material/icons.dart`，
因此组件上的图标与面板里的 `Icons.xxx` 是**同一个字形**。

**为什么顺带把码位硬编码在脚本里而不是每次去解析 icons.dart**：
解析需要 Flutter SDK 路径，CI/其他机器上不一定有。脚本只在**改图标时**才跑，
产物 PNG 提交进仓库；把码位写死可以让这个脚本在任何机器上离线可跑，
而且改哪个图标一眼可见（对照注释里的 Flutter 常量名）。
下面的码位已与 Flutter 3.47.3 的 icons.dart 逐一核对。

用法：
    python3 tool/gen_app_widget_icons.py

产物：
    android/app/src/main/res/drawable-xxhdpi/aw_ic_<name>.png       13dp 图标
    android/app/src/main/res/drawable-xxhdpi/aw_ic_big_<name>.png   26dp 图标（天气主图标）
    android/app/src/main/res/drawable-xxhdpi/aw_logo.png            顶栏 App logo
"""

import json
import os
import re
import sys

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    print("需要 Pillow：pip install Pillow", file=sys.stderr)
    raise SystemExit(2)

# Flutter 自带的图标字体（与面板里 Icons.* 同一套字形）
FLUTTER_FONT_CANDIDATES = [
    "/tmp/sdk/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf",
    os.path.expanduser("~/flutter/bin/cache/artifacts/material_fonts/"
                       "MaterialIcons-Regular.otf"),
]

# 密度：图标按 xxhdpi 出图，低密度由系统下采样。
#
# ⚠ 这里**必须写死目录名**，不能拼 `'x' * n + 'hdpi'`：
#   xxhdpi = 3x，xxxhdpi = 4x —— 拼字符串很容易把 3x 的图放进 4x 的目录，
#   那样所有图标都会**静默缩小 25%**（不报错、只是看着小，最难查的那种错）。
# 只出一档是刻意的取舍：这些是纯平小图标，下采样看不出差别，
# 而出三档要让文件数×3（~35 图标 → 100+ 文件），收益不抵维护成本。
DENSITY_DIR = "xxhdpi"
DENSITY_SCALE = 3

# 图标尺寸（dp）。面板里的实际用法：提示行图标 13、指标图标 12、
# 分组标题 13、天气主图标 26。这里归并成两档：
#   SMALL = 13dp（提示 / 指标 / 标题共用，12 与 13 差 1dp 看不出来）
#   BIG   = 26dp（天气主图标，与面板 _top 里的大温度配重）
SMALL_DP = 13
BIG_DP = 26

# ── 码位表：资源名 → (Flutter 常量名, 码位) ─────────────────────────
#
# 码位取自 packages/flutter/lib/src/material/icons.dart。
#
# ⚠ **为什么不「每次去解析 icons.dart」而是写在这里**：解析需要 Flutter SDK
#   路径，脚本得能在任何机器上离线跑；而且把码位写在表里，改哪个图标一眼可见。
#
# ⚠ **但手抄就会抄错**（真的错了两处）：最初我用「取定义首行第一个 0x」的
#   办法刮码位，而 icons.dart 里有些定义是**折行**的：
#       static const IconData x_rounded = IconData(
#         0xf009e,
#         fontFamily: 'MaterialIcons',
#       );
#   首行没有码位，于是刮到了别的东西 —— `place` 抄成 0xF761（实际是刷新箭头）、
#   `history` 抄成 0xF62D。两者都**不报错**，只是组件上出现一个完全无关的图标。
#   是「渲染出来看一眼」才发现的。
#
#   所以下面 [verify_with_flutter] 会在能找到 icons.dart 时**逐个核对**本表，
#   对不上就直接报错退出。找不到 SDK 时跳过（但仍会在产物里比对是否渲染为空）。
ICONS_WITH_CONST = {
    # 界面通用
    "place":          ("place_rounded",          0xF009E),
    "tune":           ("tune_rounded",           0xF0258),
    "rss_feed":       ("rss_feed_rounded",       0xF0119),
    "history":        ("history_rounded",        0xF7EF),
    # 系统状态组件（标题齿轮）。与天气/短波组件的标题图标一样，
    # 是构建期烘焙的 PNG —— 组件进程没有图标字体。
    "settings":       ("settings_rounded",        0xF0164),
    "calendar_month": ("calendar_month_rounded", 0xF06C8),
    # 指标用图标（与面板 _metricPairs 的语义对应）
    "water_drop":       ("water_drop_rounded",       0xF03B4),
    "thermostat":       ("thermostat_rounded",       0xF022C),
    "device_thermostat": ("device_thermostat_rounded", 0xF6A5),
    "air":              ("air_rounded",              0xF542),
    "visibility":       ("visibility_rounded",       0xF0293),
    # 火腿建议用图标（与 lib/weather.dart 里 HamTip 的图标一一对应）
    "flash_on":              ("flash_on_rounded",              0xF76D),
    "power_off":             ("power_off_rounded",             0xF00B6),
    "warning_amber":         ("warning_amber_rounded",         0xF02A0),
    "graphic_eq":            ("graphic_eq_rounded",            0xF7BD),
    "water":                 ("water_rounded",                 0xF02A6),
    "umbrella":              ("umbrella_rounded",              0xF025F),
    "wifi_tethering":        ("wifi_tethering_rounded",        0xF02C2),
    "ac_unit":               ("ac_unit_rounded",               0xF516),
    "icecream":              ("icecream_rounded",              0xF80A),
    "flag":                  ("flag_rounded",                  0xF768),
    "local_fire_department": ("local_fire_department_rounded",  0xF86B),
    "blur_on":               ("blur_on_rounded",               0xF5C9),
    "grain":                 ("grain_rounded",                 0xF7BC),
    "masks":                 ("masks_rounded",                 0xF8AB),
    "opacity":               ("opacity_rounded",               0xF0030),
    "wb_sunny":              ("wb_sunny_rounded",              0xF02AE),
    "trending_down":         ("trending_down_rounded",         0xF0252),
    "waves":                 ("waves_rounded",                 0xF02A8),
    "wb_twilight":           ("wb_twilight_rounded",           0xF02AF),
    "nightlight":            ("nightlight_round",              0xE42F),
    # 短波 / 电离层（hf.dart 的建议会用到）
    "public_off":       ("public_off_rounded",       0xF00C5),
    "public":           ("public_rounded",           0xF00C6),
    "auto_awesome":     ("auto_awesome_rounded",     0xF596),
    "hearing_disabled": ("hearing_disabled_rounded", 0xF7E0),
    "cell_tower":       ("cell_tower_rounded",       0xF02E6),
    # 天气主图标（会额外出一份 26dp 的大图）
    "nights_stay":  ("nights_stay_rounded",  0xF0008),
    "wb_cloudy":    ("wb_cloudy_rounded",    0xF02AA),
    "cloud":        ("cloud_rounded",        0xF650),
    "thunderstorm": ("thunderstorm_rounded", 0xF0823),
}
ICONS = {k: v[1] for k, v in ICONS_WITH_CONST.items()}

# 天气主图标需要的大尺寸版本（天气档位会用到的那几个）
BIG_ICONS = {
    "wb_sunny", "nights_stay", "wb_cloudy", "cloud", "thunderstorm",
    "grain", "water_drop", "ac_unit", "blur_on",
}


def find_font() -> str:
    for p in FLUTTER_FONT_CANDIDATES:
        if os.path.exists(p):
            return p
    print("找不到 MaterialIcons 字体。请修改脚本里的 FLUTTER_FONT_CANDIDATES。",
          file=sys.stderr)
    raise SystemExit(2)


def render_icon(font_path: str, codepoint: int, target_px: int) -> Image.Image:
    """把字形渲染成 target_px 见方的白色 PNG，四周留极小边距。

    关于「视觉大小」的校准：Flutter 的 `Icon(size: S)` 是把字形以字号 S 画在
    S×S 的框里，字形本身（Material 图标的设计网格是 24dp，墨迹约占 20dp）
    并不会填满整框。这里改为**按墨迹裁切**再把画布缩到 target_px，
    于是 PNG 的视觉大小 = target_px 对应的 dp 数，布局里给多少 dp 就是多大，
    比复刻 Flutter 的隐含留白更容易推理。边距留 6%，避免抗锯齿边缘被切掉。
    """
    # 先用足够大的字号渲染，再按墨迹裁切 + 缩放，保证任何尺寸都清晰
    src = max(target_px * 4, 96)
    font = ImageFont.truetype(font_path, src)
    canvas = Image.new("RGBA", (src * 2, src * 2), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas)
    # 居中绘制：先在临时图里量墨迹，再贴到最终画布
    tmp = Image.new("RGBA", (src * 3, src * 3), (0, 0, 0, 0))
    ImageDraw.Draw(tmp).text((src, src), chr(codepoint), font=font,
                             fill=(255, 255, 255, 255))
    bbox = tmp.getbbox()
    if bbox is None:
        # 码位在该字体里没有字形 —— 必须报出来，否则会静默产出全透明图，
        # 组件上就是「图标莫名其妙不见了」
        raise ValueError(f"码位 U+{codepoint:04X} 在该字体里渲染为空")
    glyph = tmp.crop(bbox)

    # 6% 边距 → 内容占 88%
    inner = int(target_px * 0.88)
    scale = inner / max(glyph.width, glyph.height)
    new_size = (max(1, round(glyph.width * scale)),
                max(1, round(glyph.height * scale)))
    glyph = glyph.resize(new_size, Image.LANCZOS)

    out = Image.new("RGBA", (target_px, target_px), (0, 0, 0, 0))
    out.paste(glyph, ((target_px - new_size[0]) // 2,
                      (target_px - new_size[1]) // 2), glyph)
    return out


# ── 圆弧 logo 的尺寸（dp）。17dp 与顶栏 11sp 的 App 名称视觉高度相当 ──
LOGO_DP = 17


def render_logo(target_px: int) -> Image.Image:
    """画出 App logo 的**圆弧（圆形）**版本。

    为什么不直接缩小启动器图标（踩过的坑，按顺序）：
      ① 启动器图标的圆角**外面**不是全透明，而是 alpha≈166 的半透明黑
         （实测四角 (0,0,0,166)、中心 (89,89,89,255)）。缩到 17dp 压在天气
         渐变上就是**一圈暗斑**，像 logo 外套了个脏方框。
      ② 把那圈光晕二值化丢掉后，源图只到圆角方块的边 → 裁成圆形要在
         192px 上做一次硬边蒙版，缩到 17dp 后边缘**阶梯状**（放大看得见）。
      ③ 源图只有 192px，缩到 51px 后细环会糊成一团橄榄色。

    所以改成按源图**实测的几何与颜色重画**，任意尺寸都干净：
    源图 192px、中心 (96,96)，竖向/水平扫描得到的环半径、环宽、颜色如下。

    配色与几何全部来自源图扫描：
      navy 底色上 #031F55 → 下 #011840（竖向微渐变，取自四角采样）
      中心实心圆 #595959 半径 18/96
      第 1 环 #595959 半径 29/96 宽 6/96
      第 2 环 #595959 半径 44.5/96 宽 5/96
      外环 #A8C2F2（浅蓝）半径 59/96 宽 4/96
      左右两颗白点位于半径 54/96，直径 8/96
    """
    SS = 4  # 超采样：先 4 倍画再缩，边缘不会有阶梯
    S = target_px * SS
    c = S / 2

    def f(v: float) -> float:
        """源图半宽 = 96px，把源图坐标换算到当前画布"""
        return v / 96.0

    navy_top, navy_bot = (3, 31, 85), (1, 24, 64)
    gray, lightblue, white = (89, 89, 89), (168, 194, 242), (255, 255, 255)

    img = Image.new("RGB", (S, S))
    for y in range(S):
        t = y / max(1, S - 1)
        img.paste(tuple(int(navy_top[i] + (navy_bot[i] - navy_top[i]) * t)
                        for i in range(3)), (0, y, S, y + 1))

    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)

    r = f(18) * c
    d.ellipse([c - r, c - r, c + r, c + r], fill=gray + (255,))

    def ring(radius_src: float, width_src: float, color) -> None:
        rr = f(radius_src) * c
        w = max(1, round(f(width_src) * c))
        d.ellipse([c - rr, c - rr, c + rr, c + rr],
                  outline=color + (255,), width=w)

    ring(29, 6, gray)
    ring(44.5, 5, gray)
    ring(59, 4, lightblue)

    dr = f(8) * c / 2
    for sign in (-1, 1):
        x = c + sign * f(54) * c
        d.ellipse([x - dr, c - dr, x + dr, c + dr], fill=white + (255,))

    out = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    mask = Image.new("L", (S, S), 0)
    ImageDraw.Draw(mask).ellipse([0, 0, S - 1, S - 1], fill=255)
    out.paste(img, (0, 0), mask)
    out.alpha_composite(layer)
    return out.resize((target_px, target_px), Image.LANCZOS)


def verify_with_flutter() -> int:

    """如果本机能找到 Flutter 的 icons.dart，就逐个核对上面的码位表。

    这是为「手抄码位抄错」那个错误加的（place / history 各错一次，都不报错、
    只在界面上显示一个完全无关的图标）。找不到 SDK 时跳过 —— 脚本要能离线跑。
    """
    candidates = [
        "/tmp/sdk/flutter/packages/flutter/lib/src/material/icons.dart",
        os.path.expanduser(
            "~/flutter/packages/flutter/lib/src/material/icons.dart"),
    ]
    path = next((p for p in candidates if os.path.exists(p)), None)
    if not path:
        print("（未找到 icons.dart，跳过码位核对）")
        return 0
    with open(path, encoding="utf-8") as f:
        src = f.read()
    # 必须在 "= IconData(" 之后找码位：定义可能折行，取首行会刮到别的数字
    pat = re.compile(r"static const IconData (\w+)\s*=\s*IconData\(\s*(0x[0-9a-fA-F]+)")
    table = {m.group(1): int(m.group(2), 16) for m in pat.finditer(src)}

    bad = []
    for name, (const, cp) in ICONS_WITH_CONST.items():
        real = table.get(const)
        if real is None:
            bad.append(f"  ✗ {name}: icons.dart 里找不到常量 {const}")
        elif real != cp:
            bad.append(f"  ✗ {name}: 表里是 0x{cp:04X}，icons.dart 里是 0x{real:04X}"
                       f"（Icons.{const}）")
    if bad:
        print("码位核对失败：", file=sys.stderr)
        print("\n".join(bad), file=sys.stderr)
        return 1
    print(f"码位核对通过：{len(ICONS_WITH_CONST)} 个图标与 icons.dart 一致")
    return 0


def main() -> int:
    if verify_with_flutter() != 0:
        return 1
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    res = os.path.join(root, "android", "app", "src", "main", "res")
    out_dir = os.path.join(res, f"drawable-{DENSITY_DIR}")
    if not os.path.isdir(res):
        print(f"找不到 res 目录：{res}", file=sys.stderr)
        return 1
    os.makedirs(out_dir, exist_ok=True)

    font_path = find_font()
    print(f"图标字体：{font_path}")

    written = []
    for name, cp in sorted(ICONS.items()):
        img = render_icon(font_path, cp, SMALL_DP * DENSITY_SCALE)
        p = os.path.join(out_dir, f"aw_ic_{name}.png")
        img.save(p)
        written.append(p)
        if name in BIG_ICONS:
            img = render_icon(font_path, cp, BIG_DP * DENSITY_SCALE)
            p = os.path.join(out_dir, f"aw_ic_big_{name}.png")
            img.save(p)
            written.append(p)

    # App logo。
    #
    # ⚠ **不要用 `assets/osl.png`**：那个文件不是 logo，是贡献者 BG7OSL 的头像
    #   （一张黄色袋鼠表情包，在 lib/about_page.dart 里当贡献者照片用）。
    #   我第一版当成 logo 烘进了组件，结果组件右上角出现一只袋鼠。
    #   真正的品牌标识是启动器图标（navy 圆角方击 + 同心电波），
    #   它和 docs/assets/logo.png（官网 logo）是同一个图形。
    #   这里刻意用**启动器图标源图**（xxxhdpi 192px），保证与用户桌面上看到的
    #   App 图标是同一张图；同时保持 aw_* 命名，便于统一维护。
    logo_src = os.path.join(root, "android", "app", "src", "main", "res",
                            "mipmap-xxxhdpi", "ic_launcher.png")

    LOGO_DP = 17
    if not os.path.exists(logo_src):
        print(f"找不到 logo 源：{logo_src}", file=sys.stderr)
        return 1
    if os.path.basename(logo_src) == "osl.png":
        print("logo 源指向了 assets/osl.png —— 那是贡献者头像，不是 logo",
              file=sys.stderr)
        return 1
    logo = render_logo(LOGO_DP * DENSITY_SCALE)

    # 完整性自检：logo 必须真是一张有内容的图。
    # 「拿错图」这类错不会报错、也不会崩，只是界面上多个莫名其妙的东西 ——
    # 所以必须机器核。下面两条：非全透明、颜色有变化（不是纯色块）。
    alpha = logo.getchannel("A")
    if alpha.getbbox() is None:
        print("logo 全透明 —— 源图可能损坏或选错了文件", file=sys.stderr)
        return 1
    colors = logo.convert("RGB").getcolors(maxcolors=1 << 16)
    if colors is not None and len(colors) < 4:
        print(f"logo 颜色数只有 {len(colors)} —— 像是纯色块，可能选错了文件",
              file=sys.stderr)
        return 1

    p = os.path.join(out_dir, "aw_logo.png")
    logo.save(p)
    written.append(p)

    for p in written:
        print(f"  {os.path.relpath(p, root)}  ({os.path.getsize(p)} B)")

    # ── 顺带产出 Kotlin 的「图标名 → 资源」映射表 ────────────────────
    #
    # 为什么让**生成器**写这个文件：图标名是 Dart 侧发过来的字符串，Kotlin 拿它
    # 查 R.drawable。两边名字一旦对不上，Kotlin 查不到就回退默认图标 ——
    # 不报错、只是显示错图标（这类错最难发现）。让本脚本同时产出 PNG 与映射表，
    # 两边就**不可能**漂移。
    kt = os.path.join(root, "android", "app", "src", "main", "kotlin",
                      "com", "aprslocus", "aprslocus", "WidgetIcons.kt")
    L = [
        "package com.aprslocus.aprslocus",
        "",
        "// 本文件由 tool/gen_app_widget_icons.py **自动生成**，不要手改。",
        "//",
        "// 把 Dart 传来的图标名映射到已烘焙的 PNG。图标名与 PNG、与",
        "// lib/weather.dart 里的 Icons.xxx 一一对应（同一套 MaterialIcons 字形）。",
        "//",
        "// 生成器同时产出 PNG 与这张表，所以两边不会漂移；名字对不上时",
        "// 宁可用兵底图标（rss_feed / cloud）也不要崩。",
        "internal object WidgetIcons {",
        "    /** 13dp 图标（提示行 / 指标 / 标题 / 城市点） */",
        "    private val SMALL = mapOf(",
    ]
    L += [f'        "{n}" to R.drawable.aw_ic_{n},' for n in sorted(ICONS)]
    L += [
        "    )",
        "",
        "    /** 26dp 天气主图标（只给天气档位会用到的几个出一份大图） */",
        "    private val BIG = mapOf(",
    ]
    L += [f'        "{n}" to R.drawable.aw_ic_big_{n},' for n in sorted(BIG_ICONS)]
    L += [
        "    )",
        "",
        "    fun small(name: String): Int =",
        "        SMALL[name] ?: R.drawable.aw_ic_rss_feed",
        "",
        "    fun big(name: String): Int =",
        "        BIG[name] ?: R.drawable.aw_ic_big_cloud",
        "}",
        "",
    ]
    with open(kt, "w", encoding="utf-8") as f:
        f.write("\n".join(L))
    print(f"  {os.path.relpath(kt, root)}  ({os.path.getsize(kt)} B)")

    # 再产出「图标名清单」给 Dart 测试读。
    #
    # 为什么要有这个文件：测试原本把图标名清单**手抄**在 test 里，于是每加一个
    # 图标都要记得改测试 —— 我这轮加 5 个图标时就忘了，测试立刻红。
    # 让生成器产出清单、测试读文件，两边就不可能再漂移。
    names = os.path.join(root, "test", "reference", "widget_icon_names.json")
    os.makedirs(os.path.dirname(names), exist_ok=True)
    with open(names, "w", encoding="utf-8") as f:
        json.dump({
            "small": sorted(ICONS),
            "big": sorted(BIG_ICONS),
        }, f, ensure_ascii=False, indent=2, sort_keys=True)
        f.write("\n")
    print(f"  {os.path.relpath(names, root)}  ({os.path.getsize(names)} B)")
    print(f"\n共生成 {len(written)} 个 PNG + 1 个 Kotlin 映射表")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
