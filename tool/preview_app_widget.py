#!/usr/bin/env python3
"""桌面小组件 + App 天气面板的**设计预览**：写代码之前先看效果。

为什么要这个脚本（血泪史）：组件要装到真机才能看效果，一轮反馈 = CI + 装 APK。
前几轮都是装上去才发现「挤 / 不像面板 / logo 错了 / 溢出」，每次重走一遍。
这里用**真实素材**把设计渲染成 PNG：

- 真实 Material 图标（直接用 `res/drawable-xxhdpi/aw_ic_*.png`，即运行时那几张）
- 真实 logo（`aw_logo.png`）
- 真实天气渐变（与 `lib/weather.dart::_fxGradient()` 同一组色）
- 真实字号/字重/透明度（照抄面板 `ts(12.5, w: w700, c: white 0.68)` 那一套）
- 按 3x 渲染（与 xxhdpi 一致）

**并且硬性报「内容放不下」**（退出码 1）——这条是它最值钱的地方。

⚠ 一个必须记住的坑：**文本高度要按字体行盒算，不是按墨迹算。**
Android 的 TextView 行高 ≈ 字体 (ascent + descent)，即使设了
`includeFontPadding="false"`（那只是去掉上下额外留白）。
Noto Sans SC 的这个值是 **1.45em**，而中文墨迹只有约 1.0em。
我第一版按墨迹算，每行少算约 4dp，十几行下来少算 50dp ——
于是「预览说余 5.5dp、真机却溢出」。见 line_h()。

用法：
    python3 tool/preview_app_widget.py               # 全部档位
    python3 tool/preview_app_widget.py --out /tmp/a.png
"""

import argparse
import os
import sys

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:
    print("需要 Pillow：pip install Pillow", file=sys.stderr)
    raise SystemExit(2)

SCALE = 3

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ICON_DIR = os.path.join(ROOT, "android", "app", "src", "main", "res",
                        "drawable-xxhdpi")

# 天气渐变（照抄 weather.dart::_fxGradient 的 light 表）
LIGHT = {
    "clear":    ("#2E86D6", "#79C4F2"),
    "cloudy":   ("#4A6E93", "#87AACB"),
    "overcast": ("#56677A", "#8C9BAB"),
    "rain":     ("#36506B", "#63809B"),
    "storm":    ("#232F3E", "#4A5B70"),
    "snow":     ("#5C7FA8", "#A8C6E2"),
    "fog":      ("#6C7A87", "#A3AEB9"),
}
# 深色（照抄 darkc 表）
DARK = {
    "clear":    ("#26374A", "#141F2E"),
    "cloudy":   ("#2A3444", "#161D28"),
    "overcast": ("#313B49", "#1A212B"),
    "rain":     ("#1F3143", "#0F1924"),
    "storm":    ("#232E3A", "#0D131B"),
    "snow":     ("#2C3642", "#171E27"),
    "fog":      ("#2B3138", "#171B21"),
}

# 建议级别提亮色（与 Dart widgetTipTextArgb 逐值一致，整数字面量）
LEVEL_LIT = {
    "danger": "#EC6C88", "warn": "#E6A75D",
    "good": "#68C389", "tip": "#719AF2",
}
TIP_LINE_MULT = 1.3   # 布局里提示正文的 lineSpacingMultiplier
LEVEL_LABEL = {
    "danger": "安全警示", "warn": "注意", "good": "通联机会", "tip": "操作提示",
}

# 传播质量 → 颜色（绿=好 黄=一般 橙=差 红=很差）
def _lit(base_hex):
    """把基准色往白提亮 35% —— **必须**与 Dart 的 widgetTipTextArgb 用同一套
    整数运算（c*0.65 + 255*0.35，逐通道 round）。

    这里刻意**算**而不是手抄：原来 "Band Closed" 手写了 #B9C4D4，而同一公式
    算出的是 #B9C3D1 —— 预览与真机差一点点颜色，就违背了「预览不能骗人」
    这条契约（而且测试会按精确值断言 Dart 侧，根本发现不了预览这边抄错）。
    """
    # 自己解析而不调 hex2rgb：hex2rgb 定义在本文件靠后的「工具」区，
    # 而这段常量在文件更上面 —— 依赖定义顺序是那种「换个顺序就炸」的坑，
    # 就地解析三行更稳。
    h = base_hex.lstrip("#")
    r, g, b = int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)
    m = lambda c: round(c * 0.65 + 255 * 0.35)  # noqa: E731
    return "#%02X%02X%02X" % (m(r), m(g), m(b))


# 传播条件 → 颜色。基准色与 lib/hf.dart 的 hfQualityColor 一致，提亮后即
# 组件上圆点/文字的实际颜色（Dart 侧调 widgetTipTextArgb 得到同一个值）。
QUALITY_COLORS = {
    "Good": _lit("#16A34A"),
    "Fair": _lit("#D97706"),
    "Poor": _lit("#E11D48"),
    "Band Closed": _lit("#94A3B8"),
}

# ── 示例数据 ────────────────────────────────────────────────────────
WEATHER = {
    "city": "北京", "aqi": "42", "aqi_label": "优", "aqi_color": "#22C55E",
    "observed": "观测 14:30", "temp": "31°", "cond": "雷阵雨", "range": "12°/25°",
    "weather_icon": "thunderstorm",
    "metrics": [("湿度", "45%"), ("风力", "3 级"),
                ("气压", "1013 hPa"), ("能见度", "25 km")],
    "tips": [
        ("danger", "flash_on",
         "雷雨天气：请勿在室外架设/操作天线！断开天线馈线，谨防雷击感应损坏设备",
         "雷雨天气：请勿在室外架设/操作天线！"),
        ("good", "nightlight",
         "夜间 D 层消失：80/40m 吸收减小、噪声较低，适合本土与夜间远程通信",
         "夜间 D 层消失：80/40m 吸收减小…"),
    ],
    "tips_title": "业余无线电建议",
    "app_name": "APRSlocus",
}

# 短波/电离层数据（字段与 hamqsl.com/solarxml.php 对应）
HF = {
    "sfi": "100", "kp": "3", "a": "9", "sunspots": "23", "xray": "B2.2",
    "solarwind": "508.8", "geomag": "UNSETTLD", "noise": "S2-S3",
    "muf": "NoRpt", "updated": "05:13 GMT",
    # 逐波段日/夜传播条件 —— 「各个波段的传播信息」
    "bands": [
        ("80m/40m", "Poor", "Fair"),
        ("30m/20m", "Good", "Good"),
        ("17m/15m", "Fair", "Fair"),
        ("12m/10m", "Poor", "Poor"),
    ],
    "hf_title": "短波传播",
}

FALLBACK_FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"


def font(size_dp, bold=False):
    name = "NotoSansSC-Bold.otf" if bold else "NotoSansSC-Regular.otf"
    p = os.path.expanduser(os.path.join("~/.fonts", name))
    if not os.path.exists(p):
        p = FALLBACK_FONT
    return ImageFont.truetype(p, max(1, round(size_dp * SCALE)))


_METRICS = {}


def line_h(size_dp, bold=False):
    """一行文本在 Android 里占的高度（dp）。

    这是本脚本最关键的一处「真相」：TextView 的行高 ≈ 字体 (ascent + descent)，
    **不是**字符墨迹高度。Noto Sans SC 是 1.45em，中文墨迹约 1.0em ——
    按墨迹算会每行少 4dp 左右，十几行就少 50dp，于是「预览说放得下、真机溢出」。
    """
    key = (size_dp, bold)
    if key not in _METRICS:
        asc, desc = font(size_dp, bold).getmetrics()
        _METRICS[key] = (asc + desc) / SCALE
    return _METRICS[key]


def stack_h(*sizes):
    """若干**上下堆叠**的文本行总高度。"""
    return sum(line_h(s) for s in sizes)


def block_lines_h(size_dp, n, mult=1.0):
    """n 行文本块的高度。**必须**把 lineSpacingMultiplier 算进来：
    布局里提示正文写的是 lineSpacingMultiplier="1.3"，Android 会按倍数拉开
    后续行的间距，忽略它又是一处「预览偏乐观」。"""
    if n <= 0:
        return 0.0
    lh = line_h(size_dp)
    return lh + (n - 1) * lh * mult


def hex2rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def rgba(h, a):
    return hex2rgb(h) + (int(round(a * 255)),)


class Canvas:
    def __init__(self, w_dp, h_dp, kind="clear", radius_dp=20, dark=False):
        w, h = round(w_dp * SCALE), round(h_dp * SCALE)
        table = DARK if dark else LIGHT
        top, bot = hex2rgb(table[kind][0]), hex2rgb(table[kind][1])
        img = Image.new("RGB", (w, h))
        for y in range(h):
            t = y / max(1, h - 1)
            img.paste(tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)),
                      (0, y, w, y + 1))
        mask = Image.new("L", (w, h), 0)
        ImageDraw.Draw(mask).rounded_rectangle(
            [0, 0, w - 1, h - 1], round(radius_dp * SCALE), fill=255)
        self.base = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        self.base.paste(img, (0, 0), mask)
        self.layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.layer)
        self.size = (w_dp, h_dp)

    # ── 基础绘制 ──
    def text(self, x, y, s, size, alpha=1.0, bold=False, color="#FFFFFF",
             anchor="la", spacing=None):
        f = font(size, bold)
        if not spacing:
            self.d.text((round(x * SCALE), round(y * SCALE)), s, font=f,
                        fill=rgba(color, alpha), anchor=anchor)
            return
        # 字距：逐字绘制并多推进 spacing*size 像素。
        # PIL 没有字母间距参数，只能自己排；anchor 只按左对齐起画，
        # 需要居中/右对齐时先量总宽再换算起始 x。
        extra = spacing * size * SCALE
        total = (sum(self.d.textlength(ch, font=f) for ch in s)
                 + extra * max(0, len(s) - 1))
        sx = round(x * SCALE)
        if anchor[0] == 'm':
            sx -= round(total / 2)
        elif anchor[0] == 'r':
            sx -= round(total)
        yy = round(y * SCALE)
        cx = sx
        for ch in s:
            self.d.text((cx, yy), ch, font=f, fill=rgba(color, alpha),
                        anchor='l' + anchor[1])
            cx += self.d.textlength(ch, font=f) + extra

    def measure(self, s, size, bold=False):
        return self.d.textbbox((0, 0), s, font=font(size, bold))[2] / SCALE

    def icon(self, name, x, y, size, big=False, color=None):
        fn = f"aw_ic_big_{name}.png" if big else f"aw_ic_{name}.png"
        im = Image.open(os.path.join(ICON_DIR, fn)).convert("RGBA")
        side = round(size * SCALE)
        im = im.resize((side, side), Image.LANCZOS)
        if color:
            tint = Image.new("RGBA", im.size, hex2rgb(color) + (255,))
            tint.putalpha(im.getchannel("A"))
            im = tint
        self.layer.alpha_composite(im, (round(x * SCALE), round(y * SCALE)))

    def logo(self, x, y, size):
        im = Image.open(os.path.join(ICON_DIR, "aw_logo.png")).convert("RGBA")
        side = round(size * SCALE)
        sc = side / max(im.size)
        im = im.resize((max(1, round(im.width * sc)), max(1, round(im.height * sc))),
                       Image.LANCZOS)
        self.layer.alpha_composite(im, (round(x * SCALE), round(y * SCALE)))

    def paste(self, img, x, y):
        self.layer.alpha_composite(img, (round(x * SCALE), round(y * SCALE)))

    def rounded(self, w, h, r, color, alpha, border_alpha=None):
        im = Image.new("RGBA", (round(w * SCALE), round(h * SCALE)), (0, 0, 0, 0))
        d = ImageDraw.Draw(im)
        d.rounded_rectangle([0, 0, im.width - 1, im.height - 1], round(r * SCALE),
                            fill=rgba(color, alpha),
                            outline=rgba(color, border_alpha) if border_alpha else None,
                            width=max(1, round(0.7 * SCALE)))
        return im

    def circle(self, d_dp, color):
        d = max(2, round(d_dp * SCALE))
        im = Image.new("RGBA", (d, d), (0, 0, 0, 0))
        ImageDraw.Draw(im).ellipse([0, 0, d - 1, d - 1], fill=hex2rgb(color) + (255,))
        return im

    def hairline(self, x, y, w, alpha=0.10):
        self.d.rectangle([round(x * SCALE), round(y * SCALE),
                          round((x + w) * SCALE), round(y * SCALE) + SCALE - 1],
                         fill=rgba("#FFFFFF", alpha))

    def out(self):
        o = self.base.copy()
        o.alpha_composite(self.layer)
        return o

    def out_clipped(self, radius_dp):
        """按圆角裁切输出：内容排不下时要**看得见**被切掉，而不是漫出卡片外。"""
        o = self.out()
        mask = Image.new("L", o.size, 0)
        ImageDraw.Draw(mask).rounded_rectangle(
            [0, 0, o.width - 1, o.height - 1], round(radius_dp * SCALE), fill=255)
        o.putalpha(Image.composite(o.getchannel("A"),
                                   Image.new("L", o.size, 0), mask))
        return o


def wrap(c, text, size, max_w, max_lines):
    """按实测字宽折行，超出时末行加省略号。用实测而非估算：预览要诚实回答
    「放不放得下」，估算会让预览比真机好看。"""
    f = font(size)
    lines, cur = [], ""
    for ch in text:
        if c.d.textbbox((0, 0), cur + ch, font=f)[2] / SCALE <= max_w:
            cur += ch
        else:
            lines.append(cur)
            cur = ch
            if len(lines) == max_lines:
                break
    if cur and len(lines) < max_lines:
        lines.append(cur)
    if sum(len(l) for l in lines) < len(text) and lines:
        last = lines[-1]
        while last and c.d.textbbox((0, 0), last + "…", font=f)[2] / SCALE > max_w:
            last = last[:-1]
        lines[-1] = last + "…"
    return lines


# ── 通用区块 ────────────────────────────────────────────────────────
CITY_SIZE, APP_SIZE, OBS_SIZE, AQI_SIZE, TITLE_SIZE = 10.5, 11, 8.5, 8.5, 9.5


def header(c, x, y, w, s, *, narrow=False, glass=False):
    """顶栏。宽档一行放下（城市+AQI 在左、logo+名称在右）；
    窄档（2×4 / 2×2）一行放不下，拆两行 —— 否则 logo 会压住名称。"""
    brand_w = 21 + c.measure(s["app_name"], APP_SIZE, bold=True)
    c.icon("place", x, y - 0.5, 11)
    c.text(x + 13, y + CITY_SIZE * 0.65, s["city"], CITY_SIZE, alpha=0.94,
           bold=True, anchor="lm")
    c.logo(x + w - brand_w, y - 2, 17)
    c.text(x + w - brand_w + 21, y + APP_SIZE * 0.65, s["app_name"], APP_SIZE,
           bold=True, anchor="lm")
    y += line_h(CITY_SIZE, True)

    pill = f"AQI {s['aqi']} {s['aqi_label']}"
    mw = c.measure(pill, AQI_SIZE, bold=True)
    pw = mw + 19
    if narrow:
        c.paste(c.rounded(pw, 15, 7.5, "#000000" if glass else "#FFFFFF",
                          0.20 if glass else 0.16), x, y - 1)
        c.paste(c.circle(6, s["aqi_color"]), x + 6, y + 2.5)
        c.text(x + 13 + mw / 2, y + 6.5, pill, AQI_SIZE, bold=True, anchor="mm")
        c.text(x + w, y + 6.5, s["observed"], OBS_SIZE, alpha=0.62, anchor="rm")
        return y + line_h(OBS_SIZE) + 2
    # 宽档：AQI 紧跟城市，中间是观测时刻，右端仍是品牌
    px = x + 13 + c.measure(s["city"], CITY_SIZE, bold=True) + 7
    c.paste(c.rounded(pw, 15, 7.5, "#000000" if glass else "#FFFFFF",
                      0.20 if glass else 0.16), px, y - 8.5)
    c.paste(c.circle(6, s["aqi_color"]), px + 6, y - 5)
    c.text(px + 13 + mw / 2, y - 1, pill, AQI_SIZE, bold=True, anchor="mm")
    c.text(x + w - brand_w - 10 - c.measure(s["observed"], OBS_SIZE), y - 1,
           s["observed"], OBS_SIZE, alpha=0.60, anchor="lm")
    return y


def hero(c, x, y, w, s, *, temp=30, icon=25):
    """天气主区：图标 + 大温度 + 天气现象 / 高低温。返回块的底边 y。"""
    c.icon(s["weather_icon"], x, y, icon, big=True)
    tx = x + icon + 5
    th = line_h(temp)
    c.text(tx, y + th / 2 - 1, s["temp"], temp, bold=True, anchor="lm")
    tw = c.measure(s["temp"], temp, bold=True)
    c.text(tx + tw + 4, y + 1, s["cond"], 9.5, alpha=0.90, bold=True)
    c.text(tx + tw + 4, y + line_h(9.5) + 1, s["range"], 9, alpha=0.74)
    return y + max(icon, th)


def kv(c, x, y, w, label, value):
    """面板 _kvPair 的复刻：标签左（白 0.58）/ 值右（加粗纯白）。返回底边 y。"""
    lh = line_h(9)
    c.text(x, y + lh / 2, label, 9, alpha=0.58, anchor="lm")
    c.text(x + w, y + lh / 2, value, 10, bold=True, anchor="rm")
    return y + lh + 1


def tip(c, x, y, w, level, icon, text, *, lines=2, size=9):
    """一条通栏建议，与面板 _tipRow 同构：圆点 + 图标 + 级别 / 正文另起一行。"""
    c.paste(c.circle(6, LEVEL_LIT[level]), x, y + 3)
    bx = x + 11
    c.icon(icon, bx, y, 11, color=LEVEL_LIT[level])
    c.text(bx + 14, y + 5.5, LEVEL_LABEL[level], 8.5, bold=True,
           color=LEVEL_LIT[level], anchor="lm")
    fy = y + line_h(8.5)
    wrapped = wrap(c, text, size, w - 11, lines)
    for ln in wrapped:
        c.text(bx, fy, ln, size, alpha=0.93)
        fy += line_h(size) * TIP_LINE_MULT   # 布局里是 1.3
    return y + line_h(8.5) + block_lines_h(size, len(wrapped), TIP_LINE_MULT)


def tip_inline(c, x, y, w, level, icon, text, *, size=9):
    """一条**单行**建议：圆点 + 图标 + 级别 + 正文都在同一行。

    与 tip()（级别一行、正文另起一行）的区别就是省掉那一行。
    4×2 主档高度不够，必须用这个版本；2×4 竖长档空间富余，仍用两行版
    （级别单独一行更醒目）。正文用 Dart 侧切好的 shortText。
    """
    c.paste(c.circle(6, LEVEL_LIT[level]), x, y + line_h(size) / 2 - 3)
    bx = x + 11
    c.icon(icon, bx, y + 1, 11, color=LEVEL_LIT[level])
    lx = bx + 14
    c.text(lx, y + line_h(size) / 2, LEVEL_LABEL[level], size - 0.5,
           bold=True, color=LEVEL_LIT[level], anchor="lm")
    tx = lx + c.measure(LEVEL_LABEL[level], size - 0.5, bold=True) + 6
    c.text(tx, y + line_h(size) / 2, text, size, alpha=0.93, anchor="lm")
    return y + line_h(size) + 2


def section_title(c, x, y, w, title, count=None, icon="rss_feed"):
    c.icon(icon, x, y, 11)
    c.text(x + 14, y + TITLE_SIZE * 0.6, title, TITLE_SIZE, alpha=0.80,
           bold=True, anchor="lm")
    if count:
        c.text(x + w, y + TITLE_SIZE * 0.6, count, 9, alpha=0.55, anchor="rm")
    return y + line_h(TITLE_SIZE) + 2


# ── 天气组件四档 ────────────────────────────────────────────────────
def render_tile(w=296, h=140, kind="clear", dark=False):
    c = Canvas(w, h, kind, dark=dark)
    x, iw = 12, w - 24
    y = header(c, x, 8, iw, WEATHER)
    c.hairline(x, y, iw)
    y += 6
    y_hero = hero(c, x, y, iw, WEATHER, temp=30, icon=25)
    # 指标 **3 格单行**（原来 4 格两行）。
    # 主档只有 140dp，却要装「顶栏两行 + 天气主区 + 指标 + 2 条建议」；
    # 4 格要两行，扣掉圆角净空后放不下最后一行文字。少给一格、省下 14dp，
    # 比把最后一行切一半好。与竖长档（2×4，也是 3 项指标）保持一致。
    rx = x + iw * 0.42
    rw = x + iw - rx
    y_kv = y
    for i, (lab, val) in enumerate(WEATHER["metrics"][:3]):
        yy = kv(c, rx + i * (rw / 3), y + 1, rw / 3 - 8, lab, val)
        y_kv = max(y_kv, yy)
    y = max(y_hero, y_kv)
    c.hairline(x, y + 1, iw)
    y += 7
    # 条建议各 **1 行**：140dp 装不下「2 行 + 1 行」的组合（实测超 17dp）。
    # 用 Dart 侧预切好的完整短句（shortText），一行仍是一句完整的话，
    # 而不是从句子中间被省略号切掉。
    # 用**单行**建议（级别与正文同行）：主档 140dp 放不下「级别一行 +
    # 正文一行」×2 条（实测每条要 28.6dp）。正文仍用 Dart 侧切好的完整短句。
    for level, icon, _text, short in WEATHER["tips"]:
        y = tip_inline(c, x, y, iw, level, icon, short)
    return c.out_clipped(20), y


def render_tall(w=150, h=300, kind="clear", dark=False):
    c = Canvas(w, h, kind, dark=dark)
    x, iw = 12, w - 24
    y = header(c, x, 8, iw, WEATHER, narrow=True)
    c.hairline(x, y, iw)
    y += 6
    c.icon(WEATHER["weather_icon"], x, y, 26, big=True)
    y += 30
    c.text(x, y + line_h(32) / 2, WEATHER["temp"], 32, bold=True, anchor="lm")
    y += line_h(32)
    c.text(x, y + 3, WEATHER["cond"], 10, alpha=0.90, bold=True)
    c.text(x + iw, y + 3, WEATHER["range"], 9, alpha=0.74, anchor="ra")
    y += line_h(10) + 2
    c.hairline(x, y, iw)
    y += 6
    # 指标 2 行（原 3 行）：3 行 + 两行建议实测超 12.7dp。
    # 竖长档的重点是「多给两条建议」，所以砍指标而不是砍建议。
    for lab, val in WEATHER["metrics"][:2]:
        y = kv(c, x, y, iw, lab, val)
    y += 2
    c.hairline(x, y, iw)
    y += 5
    y = section_title(c, x, y, iw, WEATHER["tips_title"],
                      count=str(len(WEATHER["tips"])))
    # 行距 4→2：2×4 扣掉圆角净空后只剩 290dp，原来 294.3dp 超出 4.3dp。
    # 建议行本来就靠「圆点 + 级别」分隔，行距缩 2dp 不影响可读性。
    for level, icon, text, short in WEATHER["tips"]:
        y = tip(c, x, y, iw, level, icon, text, lines=2) + 2
    return c.out_clipped(20), y


def render_compact(w=150, h=150, kind="clear", dark=False):
    c = Canvas(w, h, kind, dark=dark, radius_dp=16)
    x, iw = 11, w - 22
    y = header(c, x, 9, iw, WEATHER, narrow=True)
    c.hairline(x, y, iw)
    y += 7
    y = hero(c, x, y, iw, WEATHER, temp=25, icon=21)
    y += 3
    c.hairline(x, y, iw)
    y += 5
    level, icon, _full, text = WEATHER["tips"][0]
    # 2 行（原 3 行）：超 1.1dp。这条建议是紧凑档唯一的内容点，所以不是砍它，
    # 而是让它少折一行 —— 配合 Dart 侧的 shortText，一行到两行都是完整句子。
    y = tip(c, x, y, iw, level, icon, text, lines=2, size=8.5)
    return c.out_clipped(16), y


def render_row(w=296, h=72, kind="clear", dark=False):
    c = Canvas(w, h, kind, dark=dark, radius_dp=16)
    x = 12
    y = (h - 22) / 2
    c.icon(WEATHER["weather_icon"], x, y, 22, big=True)
    x += 26
    c.text(x, y + line_h(20) / 2 - 1, WEATHER["temp"], 20, bold=True, anchor="lm")
    x += c.measure(WEATHER["temp"], 20, bold=True) + 5
    c.text(x, y + 1, WEATHER["cond"], 9.5, alpha=0.90, bold=True)
    c.text(x, y + line_h(9.5) + 1, WEATHER["range"], 9, alpha=0.74)
    x += max(c.measure(WEATHER["cond"], 9.5, bold=True),
             c.measure(WEATHER["range"], 9)) + 11
    c.d.rectangle([round((x - 6) * SCALE), round((y + 2) * SCALE),
                   round((x - 6) * SCALE) + SCALE - 1, round((y + 20) * SCALE)],
                  fill=rgba("#FFFFFF", 0.22))
    level, icon, _full, text = WEATHER["tips"][0]
    c.paste(c.circle(6, LEVEL_LIT[level]), x + 4, y + 9)
    c.icon(icon, x + 15, y + 6, 11, color=LEVEL_LIT[level])
    avail = w - 12 - (x + 30) - 25
    lines = wrap(c, text, 9, avail - 11, 1)
    c.text(x + 30, y + line_h(9) / 2 + 1, lines[0] if lines else text, 9,
           alpha=0.93, anchor="lm")
    c.logo(w - 12 - 17, y + 5.5, 17)
    return c.out_clipped(16), h


# ── 短波传播组件（4×2）──────────────────────────────────────────────
def render_hf(w=296, h=140, dark=False):
    """短波/电离层传播组件。逐波段给出日间/夜间条件 —— 「各个波段的传播信息」。"""
    c = Canvas(w, h, "storm", dark=dark)
    x, iw = 12, w - 24
    # 顶栏：左标题 / 右品牌（复用天气组件的顶栏风格）
    brand_w = 21 + c.measure(WEATHER["app_name"], APP_SIZE, bold=True)
    c.icon("waves", x, 8, 14)
    c.text(x + 18, 8 + APP_SIZE * 0.65, HF["hf_title"], 12, bold=True, anchor="lm")
    c.logo(x + iw - brand_w, 7, 17)
    c.text(x + iw - brand_w + 21, 8 + APP_SIZE * 0.65, WEATHER["app_name"],
           APP_SIZE, bold=True, anchor="lm")
    y = 8 + line_h(12, True) + 2
    # 汇总指标行：SFI / Kp / A —— 与天气组件的「label 左 / value 右」同一套
    # （面板 _kvPair 的复刻）。Kp 与 A 越小时传播越稳，用级别色提示。
    cells = [("SFI", HF["sfi"], None),
             ("Kp", HF["kp"], "good" if int(HF["kp"]) <= 3 else "warn"),
             ("A", HF["a"], "good" if int(HF["a"]) <= 15 else "warn")]
    cw = iw / len(cells)
    for i, (lab, val, tone) in enumerate(cells):
        cx = x + i * cw
        c.text(cx, y + 1, lab, 9, alpha=0.58)
        c.text(cx + cw - 10, y + 1, val, 10, bold=True,
               color=LEVEL_LIT[tone] if tone else "#FFFFFF", anchor="ra")
    y += line_h(9) + 4
    c.hairline(x, y, iw)
    y += 6
    # 逐波段：左波段名 / 中「日间」/ 右「夜间」，条件用颜色区分
    c.text(x, y + 1, "波段", 8.5, alpha=0.5)
    c.text(x + iw * 0.52, y + 1, "日间", 8.5, alpha=0.5)
    c.text(x + iw, y + 1, "夜间", 8.5, alpha=0.5, anchor="ra")
    y += line_h(8.5)
    for name, day, night in HF["bands"]:
        c.text(x, y + 2, name, 9.5, bold=True)
        c.paste(c.circle(6, QUALITY_COLORS[day]), x + iw * 0.52 - 10, y + 5)
        c.text(x + iw * 0.52, y + 2, day, 9, color=QUALITY_COLORS[day], bold=True)
        c.paste(c.circle(6, QUALITY_COLORS[night]), x + iw - 42, y + 5)
        c.text(x + iw, y + 2, night, 9, color=QUALITY_COLORS[night], bold=True,
               anchor="ra")
        y += line_h(9.5) + 1
    return c.out_clipped(20), y



# ── 短波组件的**白底**方案 ─────────────────────────────────────────
#
# 为什么白底要用**基准色**而不是提亮色：`widgetTipTextArgb` 提亮 35% 是为了
# 「压在天气渐变上还能看清」；白底上提亮色会太淡（#68C389 在白底上几乎看不见）。
# 面板本身就是浅色 UI，用的就是基准色 —— 白底组件跟着用基准色才一致。
QUALITY_COLORS_BASE = {
    "Good": "#16A34A", "Fair": "#D97706",
    "Poor": "#E11D48", "Band Closed": "#94A3B8",
}

# 白底组件的前景层级（取自 theme.dart 的 C.* 浅色值）
HF3_DAY, HF3_NIGHT = "日间", "夜间"
INK = "#253044"      # C.ink    主文字
SLATE = "#637083"    # C.slate  次要文字
LINE = "#E5E9F0"     # C.border 细分隔线


# ── 短波组件的三个重做方案 ─────────────────────────────────────────
#
# 旧版（单稿调参）的问题，逐条：
#   ① 「日 ｜ 夜」图例挤在汇总行右端，**和下面两列并不对齐** → 等于没起作用
#   ② 夜间列右对齐、日间列左对齐 → 两列内容 zigzag，扫视对不齐
#   ③ 圆点的 x 随条件文字宽度浮动 → 点不在一条竖线上
#   ④ 圆点只占 6dp，颜色信号很弱，条件其实靠读字
#   ⑤ 波段名与条件之间一大片空白，横向扫视要跨很远
#   ⑥ 4 行一模一样、没有结构线，像把表格直接倒上去
#
# 三个方案分别针对这些问题的不同解法，不是换个颜色。

# 方案 A/B 共用的数据
def _hf_cells():
    return [(name, day, night) for name, day, night in HF["bands"]]


def render_hf_A(w=296, h=140, dark=False):
    """**方案 A · 彩色 chip 矩阵**（推荐）

    解法：
      · 用**彩色圆角 chip**（条件色填充 + 白字加粗）代替「圆点 + 深色文字」——
        颜色面积从 6dp 变成整块 chip，一眼扫过去就是红黄绿；
      · chip **固定宽度**，两列各在自己的固定 x 上，列头「日间 / 夜间」与
        chip 列**严格对齐**（旧版图例浮在右端，等于没标）；
      · 波段名与 chip 之间不留空档：把三列收成「窄名 + 两列 chip」，
        横向扫视距离缩短；
      · 行间用 1dp 极淡分隔线给结构（面板 _hairline 的语言），
        不再靠「一片白」堆行。
    """
    c = Canvas(w, h, "clear", dark=dark)
    c.base = Image.new("RGBA", c.base.size, (255, 255, 255, 255))
    c.layer = Image.new("RGBA", c.base.size, (0, 0, 0, 0))
    c.d = ImageDraw.Draw(c.layer)

    px, pw = 12, w - 24           # 内边距与可用宽
    # ① 顶栏
    c.icon("waves", px, 8, 14, color=INK)
    c.text(px + 18, 8 + line_h(12, True) / 2, HF["hf_title"], 12, bold=True,
           color=INK, anchor="lm")
    bw = 18 + c.measure(WEATHER["app_name"], 10, bold=True)
    c.logo(px + pw - bw, 7, 15)
    c.text(px + pw - bw + 18, 8 + line_h(10, True) / 2, WEATHER["app_name"],
           10, bold=True, color=INK, anchor="lm")
    y = 8 + line_h(12, True)
    # ② 指数一行（次要信息，不再抢大字号；波段条件才是主角）
    y += 2
    ic = [("SFI", HF["sfi"], None),
          ("Kp", HF["kp"], "good" if int(HF["kp"]) <= 3 else "warn"),
          ("A", HF["a"], "good" if int(HF["a"]) <= 15 else "warn")]
    ix = px
    for lab, val, tone in ic:
        c.text(ix, y + line_h(11) / 2, lab, 8.5, color=SLATE, anchor="lm")
        ix += c.measure(lab, 8.5) + 3
        col = (QUALITY_COLORS_BASE["Good"] if tone == "good"
               else QUALITY_COLORS_BASE["Fair"] if tone == "warn" else INK)
        c.text(ix, y + line_h(11) / 2, val, 11, bold=True, color=col,
               anchor="lm")
        ix += c.measure(val, 11, bold=True) + 14
    y += line_h(11)
    y += 3
    c.d.rectangle([round(px * SCALE), round(y * SCALE),
                   round((px + pw) * SCALE), round(y * SCALE) + SCALE - 1],
                  fill=rgba(LINE, 1.0))
    y += 4
    # ③ 列头：与下面 chip 列**严格对齐**
    BAND_W = 52
    COL_W = (pw - BAND_W) / 2
    CHIP_W, CHIP_H = 44, 13
    c.text(px + BAND_W, y + line_h(8.5) / 2, HF3_DAY, 8.5, color=SLATE,
           anchor="lm")
    c.text(px + BAND_W + COL_W, y + line_h(8.5) / 2, HF3_NIGHT, 8.5,
           color=SLATE, anchor="lm")
    y += line_h(8.5) + 1
    # ④ 4 行波段
    for i, (name, day, night) in enumerate(_hf_cells()):
        if i:
            c.d.rectangle([round(px * SCALE),
                           round((y - 1) * SCALE),
                           round((px + pw) * SCALE),
                           round((y - 1) * SCALE) + SCALE - 1],
                          fill=rgba(LINE, 1.0))
        cy = y + 1
        c.text(px, cy + CHIP_H / 2, name, 9.5, bold=True, color=INK,
               anchor="lm")
        for k, q in ((0, day), (1, night)):
            cx = px + BAND_W + k * COL_W
            c.paste(c.rounded(CHIP_W, CHIP_H, 4, QUALITY_COLORS_BASE[q], 1.0),
                    cx, cy)
            c.text(cx + CHIP_W / 2, cy + CHIP_H / 2, q, 8.5, bold=True,
                   color="#FFFFFF", anchor="mm")
        y = cy + CHIP_H + 1.5
    return c.out_clipped(20), y



def render_hf_A2(w=296, h=140, dark=False):
    """**方案 A2 · 淡底 chip**（与面板标签同一语言）

    面板里的标签用「色 15% 底 + 彩字」（见 weather.dart 的 `_tipRow`：
    danger 时 `tip.color.withValues(alpha: 0.15)` 底 + 彩色文字）。
    这里把 A 的实心 chip 换成同一套写法，整体更轻、更贴面板；
    代价是白底上「淡色底」的色块面积视觉上比实心弱一些。
    """
    c = Canvas(w, h, "clear", dark=dark)
    c.base = Image.new("RGBA", c.base.size, (255, 255, 255, 255))
    c.layer = Image.new("RGBA", c.base.size, (0, 0, 0, 0))
    c.d = ImageDraw.Draw(c.layer)

    px, pw = 12, w - 24
    c.icon("waves", px, 8, 14, color=INK)
    c.text(px + 18, 8 + line_h(12, True) / 2, HF["hf_title"], 12, bold=True,
           color=INK, anchor="lm")
    bw = 18 + c.measure(WEATHER["app_name"], 10, bold=True)
    c.logo(px + pw - bw, 7, 15)
    c.text(px + pw - bw + 18, 8 + line_h(10, True) / 2, WEATHER["app_name"],
           10, bold=True, color=INK, anchor="lm")
    y = 8 + line_h(12, True) + 2
    ic = [("SFI", HF["sfi"], None),
          ("Kp", HF["kp"], "good" if int(HF["kp"]) <= 3 else "warn"),
          ("A", HF["a"], "good" if int(HF["a"]) <= 15 else "warn")]
    ix = px
    for lab, val, tone in ic:
        c.text(ix, y + line_h(11) / 2, lab, 8.5, color=SLATE, anchor="lm")
        ix += c.measure(lab, 8.5) + 3
        col = (QUALITY_COLORS_BASE["Good"] if tone == "good"
               else QUALITY_COLORS_BASE["Fair"] if tone == "warn" else INK)
        c.text(ix, y + line_h(11) / 2, val, 11, bold=True, color=col,
               anchor="lm")
        ix += c.measure(val, 11, bold=True) + 14
    y += line_h(11) + 3
    c.d.rectangle([round(px * SCALE), round(y * SCALE),
                   round((px + pw) * SCALE), round(y * SCALE) + SCALE - 1],
                  fill=rgba(LINE, 1.0))
    y += 4
    BAND_W = 52
    COL_W = (pw - BAND_W) / 2
    CHIP_W, CHIP_H = 44, 13
    c.text(px + BAND_W, y + line_h(8.5) / 2, HF3_DAY, 8.5, color=SLATE,
           anchor="lm")
    c.text(px + BAND_W + COL_W, y + line_h(8.5) / 2, HF3_NIGHT, 8.5,
           color=SLATE, anchor="lm")
    y += line_h(8.5) + 1
    for i, (name, day, night) in enumerate(_hf_cells()):
        if i:
            c.d.rectangle([round(px * SCALE), round((y - 1) * SCALE),
                           round((px + pw) * SCALE),
                           round((y - 1) * SCALE) + SCALE - 1],
                          fill=rgba(LINE, 1.0))
        cy = y + 1
        c.text(px, cy + CHIP_H / 2, name, 9.5, bold=True, color=INK,
               anchor="lm")
        for k, q in ((0, day), (1, night)):
            cx = px + BAND_W + k * COL_W
            base = QUALITY_COLORS_BASE[q]
            c.paste(c.rounded(CHIP_W, CHIP_H, 4, base, 0.16), cx, cy)
            c.text(cx + CHIP_W / 2, cy + CHIP_H / 2, q, 8.5, bold=True,
                   color=base, anchor="mm")
        y = cy + CHIP_H + 1.5
    return c.out_clipped(20), y


# ═══ 认真设计的一版（D）═══
# 诊断（3x 放大后逐条看出来的）：
#   ① 8 个饱和色块 = 红绿灯墙。颜色用量与信息量不匹配 —— 条件只是「4 档之一」，
#      不值得给整块饱和色。
#   ② 指数行的 Kp/A 也染色（绿），与表格的颜色抢注意力 → 干扰。
#   ③ 字号只有 12/11/9.5/8.5 四级，层级几乎压平 → 看着「平」。
#   ④ 内边距全是 2~5dp 的「省出来」值 → 没有呼吸感。
#
# 设计决策（不是调参）：
#   · **tonal chip**（Material 3 的状态 chip 做法）：淡色底 10% + 条件色文字，
#     而不是实心饱和块。对齐的好处（固定宽度、落在同一竖线）保留，颜色用量降到 1/10。
#   · **指数行去色**：Kp/A 用墨色，颜色只留给「波段条件」这一件事。
#   · **建立层级**：标题 13/w800 > 指数值 11/w600 > 波段名 10/w600 > 条件 9/w700
#     > 列头 8/w600 + 字距。
#   · **呼吸**：行高 14dp、表头与表格之间留 3dp、内边距 8/8。
def _hf_shell(w, h, dark):
    c = Canvas(w, h, "clear", dark=dark)
    c.base = Image.new("RGBA", c.base.size, (255, 255, 255, 255))
    c.layer = Image.new("RGBA", c.base.size, (0, 0, 0, 0))
    c.d = ImageDraw.Draw(c.layer)
    return c


def _hf_head(c, px, pw, title_size=13):
    """顶栏 + 指数行。指数**不染色** —— 颜色只留给波段条件。"""
    c.icon("waves", px, 8, 14, color=INK)
    c.text(px + 18, 8 + line_h(title_size, True) / 2, HF["hf_title"],
           title_size, bold=True, color=INK, anchor="lm")
    bw = 18 + c.measure(WEATHER["app_name"], 10, bold=True)
    c.logo(px + pw - bw, 7, 15)
    c.text(px + pw - bw + 18, 8 + line_h(10, True) / 2, WEATHER["app_name"],
           10, bold=True, color=INK, anchor="lm")
    y = 8 + line_h(title_size, True)
    # 指数：gray 标签 + 墨色值，用「·」分隔（比留白更紧凑也更像一句注脚）
    y += 2
    items = [("SFI", HF["sfi"]), ("Kp", HF["kp"]), ("A", HF["a"])]
    x = px
    base = y + line_h(11, True) / 2
    for i, (lab, val) in enumerate(items):
        if i:
            c.text(x, base, "·", 9, color="#C3CCD9", anchor="lm")
            x += c.measure("·", 9) + 7
        c.text(x, base, lab, 9, color=SLATE, anchor="lm")
        x += c.measure(lab, 9) + 4
        c.text(x, base, val, 11, bold=True, color=INK, anchor="lm")
        x += c.measure(val, 11, bold=True) + 7
    return y + line_h(11, True)


def render_hf_D(w=296, h=140, dark=False, tonal=True):
    """**D · 认真设计版**：tonal chip（淡色底 + 条件色文字）。

    [tonal] False 时改为「小圆点 + 条件色文字」（最克制的一档），用于对比取优。
    """
    c = _hf_shell(w, h, dark)
    px, pw = 13, w - 26
    y = _hf_head(c, px, pw)
    y += 4
    c.d.rectangle([round(px * SCALE), round(y * SCALE),
                   round((px + pw) * SCALE), round(y * SCALE) + SCALE - 1],
                  fill=rgba(LINE, 1.0))
    y += 5
    # 列头：与下面 chip 的左边缘**同一 x**（这是上一版最明显的问题）
    BAND_W = 54
    COL_W = (pw - BAND_W) / 2
    CHIP_W, CHIP_H = 46, 14
    base = y + line_h(8, True) / 2
    c.text(px + BAND_W, base, HF3_DAY, 8, bold=True, color="#98A3B3",
           anchor="lm", spacing=0.06)
    c.text(px + BAND_W + COL_W, base, HF3_NIGHT, 8, bold=True, color="#98A3B3",
           anchor="lm", spacing=0.06)
    y += line_h(8, True) + 2
    for i, (name, day, night) in enumerate(_hf_cells()):
        if i:
            c.d.rectangle([round(px * SCALE), round((y - 0.5) * SCALE),
                           round((px + pw) * SCALE),
                           round((y - 0.5) * SCALE) + SCALE - 1],
                          fill=rgba(LINE, 0.75))
        cy = y + 0.5
        c.text(px, cy + CHIP_H / 2, name, 10, bold=True, color=INK,
               anchor="lm")
        for k, q in ((0, day), (1, night)):
            cx = px + BAND_W + k * COL_W
            col = QUALITY_COLORS_BASE[q]
            if tonal:
                c.paste(c.rounded(CHIP_W, CHIP_H, 5, col, 0.11), cx, cy)
                c.text(cx + CHIP_W / 2, cy + CHIP_H / 2, q, 9, bold=True,
                       color=col, anchor="mm")
            else:
                c.paste(c.circle(6, col), cx + 2, cy + CHIP_H / 2 - 3)
                c.text(cx + 12, cy + CHIP_H / 2, q, 9, bold=True, color=col,
                       anchor="lm")
        y = cy + CHIP_H
    return c.out_clipped(20), y

def render_hf_B(w=296, h=140, dark=False):
    """**方案 B · 信号条**（业余无线电仪器感）

    解法：把「质量」画成**长度**而不是文字 + 圆点 —— 4 段小方块，
    好=4 格、一般=2 格、差=1 格、关闭=0 格，颜色随质量。
    好处：不依赖读字（对多语言更友好），强弱是**长短**一眼可比；
    代价：不给文字标签，需要列头 + 一点直觉。
    """
    c = Canvas(w, h, "clear", dark=dark)
    c.base = Image.new("RGBA", c.base.size, (255, 255, 255, 255))
    c.layer = Image.new("RGBA", c.base.size, (0, 0, 0, 0))
    c.d = ImageDraw.Draw(c.layer)

    px, pw = 12, w - 24
    c.icon("waves", px, 8, 14, color=INK)
    c.text(px + 18, 8 + line_h(12, True) / 2, HF["hf_title"], 12, bold=True,
           color=INK, anchor="lm")
    bw = 18 + c.measure(WEATHER["app_name"], 10, bold=True)
    c.logo(px + pw - bw, 7, 15)
    c.text(px + pw - bw + 18, 8 + line_h(10, True) / 2, WEATHER["app_name"],
           10, bold=True, color=INK, anchor="lm")
    y = 8 + line_h(12, True) + 2
    ic = [("SFI", HF["sfi"], None),
          ("Kp", HF["kp"], "good" if int(HF["kp"]) <= 3 else "warn"),
          ("A", HF["a"], "good" if int(HF["a"]) <= 15 else "warn")]
    ix = px
    for lab, val, tone in ic:
        c.text(ix, y + line_h(11) / 2, lab, 8.5, color=SLATE, anchor="lm")
        ix += c.measure(lab, 8.5) + 3
        col = (QUALITY_COLORS_BASE["Good"] if tone == "good"
               else QUALITY_COLORS_BASE["Fair"] if tone == "warn" else INK)
        c.text(ix, y + line_h(11) / 2, val, 11, bold=True, color=col,
               anchor="lm")
        ix += c.measure(val, 11, bold=True) + 14
    y += line_h(11) + 3
    c.d.rectangle([round(px * SCALE), round(y * SCALE),
                   round((px + pw) * SCALE), round(y * SCALE) + SCALE - 1],
                  fill=rgba(LINE, 1.0))
    y += 4
    BAND_W = 52
    COL_W = (pw - BAND_W) / 2
    SEG, SEG_GAP, SEG_H = 9, 2, 9
    c.text(px + BAND_W, y + line_h(8.5) / 2, HF3_DAY, 8.5, color=SLATE,
           anchor="lm")
    c.text(px + BAND_W + COL_W, y + line_h(8.5) / 2, HF3_NIGHT, 8.5,
           color=SLATE, anchor="lm")
    y += line_h(8.5) + 1
    for i, (name, day, night) in enumerate(_hf_cells()):
        if i:
            c.d.rectangle([round(px * SCALE), round((y - 1) * SCALE),
                           round((px + pw) * SCALE),
                           round((y - 1) * SCALE) + SCALE - 1],
                          fill=rgba(LINE, 1.0))
        cy = y + 1
        c.text(px, cy + SEG_H / 2, name, 9.5, bold=True, color=INK,
               anchor="lm")
        for k, q in ((0, day), (1, night)):
            cx = px + BAND_W + k * COL_W
            filled = {"Good": 4, "Fair": 2, "Poor": 1}.get(q, 0)
            for s in range(4):
                col = QUALITY_COLORS_BASE[q] if s < filled else "#DFE4EC"
                c.paste(c.rounded(SEG, SEG_H, 2, col, 1.0),
                        cx + s * (SEG + SEG_GAP), cy)
        y = cy + SEG_H + 2
    return c.out_clipped(20), y


def render_hf_C(w=296, h=140, dark=False):
    """**方案 C · 每波段一张小卡片**（2×2 网格）

    解法：把「波段」当成一张卡，卡里「日间 / 夜间」两个 chip。
    好处：分组最清楚、留白最多，看着最「设计感」；
    代价：卡边框占掉一些空间，4 张卡的信息密度比矩阵低。
    """
    c = Canvas(w, h, "clear", dark=dark)
    c.base = Image.new("RGBA", c.base.size, (255, 255, 255, 255))
    c.layer = Image.new("RGBA", c.base.size, (0, 0, 0, 0))
    c.d = ImageDraw.Draw(c.layer)

    px, pw = 12, w - 24
    c.icon("waves", px, 8, 14, color=INK)
    c.text(px + 18, 8 + line_h(12, True) / 2, HF["hf_title"], 12, bold=True,
           color=INK, anchor="lm")
    bw = 18 + c.measure(WEATHER["app_name"], 10, bold=True)
    c.logo(px + pw - bw, 7, 15)
    c.text(px + pw - bw + 18, 8 + line_h(10, True) / 2, WEATHER["app_name"],
           10, bold=True, color=INK, anchor="lm")
    y = 8 + line_h(12, True) + 2
    ic = [("SFI", HF["sfi"], None),
          ("Kp", HF["kp"], "good" if int(HF["kp"]) <= 3 else "warn"),
          ("A", HF["a"], "good" if int(HF["a"]) <= 15 else "warn")]
    ix = px
    for lab, val, tone in ic:
        c.text(ix, y + line_h(11) / 2, lab, 8.5, color=SLATE, anchor="lm")
        ix += c.measure(lab, 8.5) + 3
        col = (QUALITY_COLORS_BASE["Good"] if tone == "good"
               else QUALITY_COLORS_BASE["Fair"] if tone == "warn" else INK)
        c.text(ix, y + line_h(11) / 2, val, 11, bold=True, color=col,
               anchor="lm")
        ix += c.measure(val, 11, bold=True) + 14
    y += line_h(11) + 3
    c.d.rectangle([round(px * SCALE), round(y * SCALE),
                   round((px + pw) * SCALE), round(y * SCALE) + SCALE - 1],
                  fill=rgba(LINE, 1.0))
    y += 5
    cells = _hf_cells()
    CW = (pw - 6) / 2
    CH = (h - y - 10 - 5) / 2
    for i, (name, day, night) in enumerate(cells):
        r, k = divmod(i, 2)
        cx = px + k * (CW + 6)
        cy = y + r * (CH + 5)
        c.paste(c.rounded(CW, CH, 6, "#F5F7FA", 1.0, 0.0), cx, cy)
        c.text(cx + 7, cy + 4, name, 9.5, bold=True, color=INK)
        chip_w = (CW - 14 - 5) / 2
        for j, (lab, q) in enumerate(((HF3_DAY, day), (HF3_NIGHT, night))):
            gx = cx + 7 + j * (chip_w + 5)
            # 卡里必须自带「日/夜」标注：不然两个 chip 一样大，
            # 根本不知道哪个是日间 —— 这是方案 C 原先的真缺陷。
            c.text(gx + chip_w / 2, cy + 4 + line_h(9.5) + 2, lab, 7.5,
                   color=SLATE, anchor="mm")
            gy = cy + 4 + line_h(9.5) + line_h(7.5) + 1
            c.paste(c.rounded(chip_w, 13, 4, QUALITY_COLORS_BASE[q], 1.0),
                    gx, gy)
            c.text(gx + chip_w / 2, gy + 6.5, q, 8, bold=True, color="#FFFFFF",
                   anchor="mm")
    return c.out_clipped(20), y + 2 * CH + 5



def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="/tmp/widget_preview.png")
    args = ap.parse_args()

    # (名称, 渲染函数, 宽dp, 高dp, 内容是否垂直居中)
    # 居中的档位（4×1 单行）不受底部圆角影响，所以不扣净空 —— 不加区分地
    # 一律扣会误报，而误报会让人干脆放宽规则。
    specs = [
        ("天气组件 4×2 主档", render_tile, 296, 140, False),
        ("天气组件 4×2（雷雨）", lambda **k: render_tile(kind="storm"),
         296, 140, False),
        ("天气组件 2×4 小面板", render_tall, 150, 300, False),
        ("天气组件 2×2 紧凑档", render_compact, 150, 150, False),
        ("天气组件 4×1 单行档", render_row, 296, 72, True),
        # 短波组件：定稿 = 方案 A（实心彩 chip）。探索用的 A2/B/C 仍在本文件里，
        # 用 --variants 时才输出，默认不打进图里（免得每次都要从一堆方案里找）。
        ("短波传播组件 4×2（定稿 · tonal chip）", render_hf_D, 296, 140, False),
    ]
    # 圆角净空：卡片圆角越大，底部两侧收得越早。20dp 圆角下，距底边约
    # 10dp 之内的左右两边已经被切掉，所以内容必须停在 h-10dp 以上。
    #
    # **这条是补上的漏洞**：原来只比「内容 vs 卡片高度」，于是 4×2 显示
    # 「137.3/140，余 2.7dp 放得下」，而真机上最后一行被圆角切了一半 ——
    # 用户看到的「溢出」就是这么来的。
    CORNER_CLEARANCE = 10.0

    tiles, overflows = [], []
    print(f"内容高度 vs 卡片可用高度（已扣掉圆角净空 {CORNER_CLEARANCE:.0f}dp）：")
    for label, fn, w_dp, h_dp, centered in specs:
        img, used = fn()
        usable = h_dp if centered else h_dp - CORNER_CLEARANCE
        over = used - usable
        if over > 1:
            overflows.append(f"{label} 超出可用高度 {over:.1f}dp")
            print(f"  ✗ {label:22} 内容 {used:5.1f}dp / 可用 {usable:5.1f}dp  溢出！")
        else:
            print(f"  ✓ {label:22} 内容 {used:5.1f}dp / 可用 {usable:5.1f}dp"
                  f"（余 {usable - used:.1f}dp）")
        tiles.append((label, img))


    PAD, GAP, LH = 24, 20, 28
    row1 = tiles[:3]
    row2 = tiles[3:5]
    row3 = tiles[5:]
    W = PAD * 2 + sum(im.width for _, im in row1) + GAP * (len(row1) - 1)
    row1h = max(im.height for _, im in row1)
    row2h = max(im.height for _, im in row2)
    row3h = max((im.height for _, im in row3), default=0)
    H = (PAD + LH + row1h + GAP + LH + row2h
         + (GAP + LH + row3h if row3 else 0) + PAD)
    sheet = Image.new("RGB", (W, H), (22, 26, 33))
    d = ImageDraw.Draw(sheet)

    def blit(items, y0):
        xx = PAD
        for name, im in items:
            d.text((xx, y0), name, font=font(10, True), fill=(214, 223, 238))
            sheet.paste(im, (xx, y0 + LH), im)
            xx += im.width + GAP
    blit(row1, PAD)
    y2 = PAD + LH + row1h + GAP
    blit(row2, y2)
    if row3:
        blit(row3, y2 + LH + row2h + GAP)

    sheet.save(args.out)
    print("预览:", args.out, sheet.size)
    if overflows:
        print("\n❌ 有档位内容排不下：", file=sys.stderr)
        for o in overflows:
            print(f"  - {o}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
