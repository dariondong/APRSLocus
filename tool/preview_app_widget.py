#!/usr/bin/env python3
"""把桌面小组件的设计**渲染成 PNG 预览** —— 写代码之前先看效果。

**为什么要有这个脚本**（三次返工的教训）：

小组件要装到真机才能看效果，一轮反馈 = CI + 装 APK。前两版都是装上去才被
判定「挤」「不像面板」，每次都重走一遍。这个脚本把设计渲染成本地 PNG，
用的全是**真实素材**：

- 真实天气渐变（与 `lib/weather.dart::_fxGradient()` 同一组色）
- 真实 Material 图标（直接用 `res/drawable-xxhdpi/aw_ic_*.png`，
  即组件运行时用的那几张图，不是另画的示意图形）
- 真实 logo（`aw_logo.png`，源自启动器图标）
- 真实字号/字重/透明度（照抄面板 `ts(12.5, w: w700, c: white 0.68)` 那一套）
- 按 3x 渲染，与 xxhdpi 一致

**与真机的差距（诚实说明）**：字体度量。预览用 Noto Sans SC，设备上通常是
厂商字体，字宽会有几个百分点出入。文字**长度与折行**是按实测字宽算的，
所以「放不放得下」基本可信；但最终以真机为准。

用法：
    python3 tool/preview_app_widget.py                 # 出全部档位
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

SCALE = 3  # 与 drawable-xxhdpi 一致

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

# 建议级别的提亮色（与 Dart widgetTipTextArgb / SEVERITY_DOTS 逐值一致）
LEVEL_LIT = {
    "danger": "#EC6C88",
    "warn":   "#E6A75D",
    "good":   "#68C389",
    "tip":    "#719AF2",
}
LEVEL_LABEL = {
    "danger": "安全警示", "warn": "注意", "good": "通联机会", "tip": "操作提示",
}

# 示例数据：挑雷阵雨，能同时体现危险级（红）与通联机会（绿）
SAMPLE = {
    "city": "北京",
    "aqi": "42",
    "aqi_label": "优",
    "aqi_color": "#22C55E",
    "observed": "观测 14:30",
    "temp": "31°",
    "cond": "雷阵雨",
    "range": "12°/25°",
    "weather_icon": "thunderstorm",
    "metrics": [("湿度", "45%"), ("风力", "3 级"),
                ("气压", "1013 hPa"), ("能见度", "25 km")],
    "tips": [
        ("danger", "flash_on",
         "雷雨天气：请勿在室外架设/操作天线！断开天线馈线，谨防雷击感应损坏设备"),
        ("good", "nightlight",
         "夜间 D 层消失：80/40m 吸收减小、噪声较低，适合本土与夜间远程通信"),
    ],
    "tips_title": "业余无线电建议",
    "app_name": "APRSlocus",
}

HAIRLINE = 0.10
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES_ICON = os.path.join(ROOT, "android", "app", "src", "main", "res",
                        "drawable-xxhdpi")


def hex2rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def rgba(h, a):
    return hex2rgb(h) + (int(round(a * 255)),)


def font(size_dp, bold=False):
    name = "NotoSansSC-Bold.otf" if bold else "NotoSansSC-Regular.otf"
    p = os.path.expanduser(os.path.join("~/.fonts", name))
    if not os.path.exists(p):
        p = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
    return ImageFont.truetype(p, max(1, round(size_dp * SCALE)))


def tw(draw, s, f):
    return draw.textbbox((0, 0), s, font=f)[2]


class Canvas:
    def __init__(self, w_dp, h_dp, kind="clear", radius_dp=20):
        w, h = round(w_dp * SCALE), round(h_dp * SCALE)
        top, bot = hex2rgb(LIGHT[kind][0]), hex2rgb(LIGHT[kind][1])
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

    # ── 基础绘制 ────────────────────────────────────────────────
    def text(self, x, y, s, size, alpha=1.0, bold=False, color="#FFFFFF",
             anchor="la"):
        self.d.text((round(x * SCALE), round(y * SCALE)), s,
                    font=font(size, bold), fill=rgba(color, alpha), anchor=anchor)

    def measure(self, s, size, bold=False):
        return tw(self.d, s, font(size, bold)) / SCALE

    def icon(self, name, x, y, size, big=False, color=None):
        fn = f"aw_ic_big_{name}.png" if big else f"aw_ic_{name}.png"
        im = Image.open(os.path.join(RES_ICON, fn)).convert("RGBA")
        side = round(size * SCALE)
        im = im.resize((side, side), Image.LANCZOS)
        if color:
            tint = Image.new("RGBA", im.size, hex2rgb(color) + (255,))
            tint.putalpha(im.getchannel("A"))
            im = tint
        self.layer.alpha_composite(im, (round(x * SCALE), round(y * SCALE)))

    def logo(self, x, y, size):
        im = Image.open(os.path.join(RES_ICON, "aw_logo.png")).convert("RGBA")
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

    def hairline(self, x, y, w, alpha=HAIRLINE):
        self.d.rectangle([round(x * SCALE), round(y * SCALE),
                          round((x + w) * SCALE), round(y * SCALE) + SCALE - 1],
                         fill=rgba("#FFFFFF", alpha))

    def out(self):
        o = self.base.copy()
        o.alpha_composite(self.layer)
        return o

    def out_clipped(self, radius_dp):
        """按圆角形状裁切后输出。

        溢出必须**看得见**：内容排不下时就把超出部分切掉，而不是让它漫到
        卡片外面 —— 预览里漫出去是假的，真机上会被组件边界直接裁掉。
        """
        o = self.out()
        mask = Image.new("L", o.size, 0)
        ImageDraw.Draw(mask).rounded_rectangle(
            [0, 0, o.width - 1, o.height - 1], round(radius_dp * SCALE), fill=255)
        o.putalpha(Image.composite(o.getchannel("A"),
                                   Image.new("L", o.size, 0), mask))
        return o

    def content_bottom(self):
        """已绘制内容的实际底边（dp）—— 用来报「内容比卡片高多少」。"""
        bbox = self.layer.getbbox()
        return (bbox[3] / SCALE) if bbox else 0.0


def wrap(c: Canvas, text, size, max_w, max_lines):
    """按**实测字宽**折行，超出时末行加省略号。

    刻意不用估算：预览的价值就在于诚实回答「放不放得下」；
    估算会让预览比真机好看，那就白做了。
    """
    f = font(size)
    lines, cur = [], ""
    for ch in text:
        if tw(c.d, cur + ch, f) / SCALE <= max_w:
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
        while last and tw(c.d, last + "…", f) / SCALE > max_w:
            last = last[:-1]
        lines[-1] = last + "…"
    return lines


# ── 顶栏：左（城市 + AQI）· 右（logo + 名称）──────────────────────────
def header(c: Canvas, x, y, w, *, glass=False, narrow=False):
    """顶栏。宽档一行放下（城市 + AQI 在左、logo + 名称在右）；
    窄档（2×4 / 2×2）一行放不下 logo+名称 与 城市+AQI，拆成两行。

    这是预览里发现的一个真问题：v1 把城市+AQI 和 logo+名称 硬塞一行，
    2×4 档里 logo 直接压在名字上（图中可见「APRSlocus」与 logo 重叠）。
    窄档一行只有 ~126dp，而 logo+名称就要 69dp、城市+AQI 要 103dp。
    """
    name = SAMPLE["app_name"]
    brand_w = 21 + c.measure(name, 11, bold=True)
    # ── 行 1：左城市，右品牌 ──
    c.icon("place", x, y - 0.5, 11, color="#FFFFFF")
    c.text(x + 13, y + 6.5, SAMPLE["city"], 10.5, alpha=0.94, bold=True,
           anchor="lm")
    c.logo(x + w - brand_w, y - 2, 17)
    c.text(x + w - brand_w + 21, y + 6.5, name, 11, bold=True, anchor="lm")
    y += 17

    # ── 行 2：AQI 胶囊（宽档就并到行 1 的中间）──
    pill = f"AQI {SAMPLE['aqi']} {SAMPLE['aqi_label']}"
    pw = c.measure(pill, 8.5, bold=True) + 19
    if narrow:
        c.paste(c.rounded(pw, 15, 7.5, "#000000" if glass else "#FFFFFF",
                          0.20 if glass else 0.16), x, y - 3)
        c.paste(c.circle(6, SAMPLE["aqi_color"]), x + 6, y + 0.5)
        c.text(x + 13 + c.measure(pill, 8.5, bold=True) / 2, y + 4.5, pill, 8.5,
           bold=True, anchor="mm")
        obs = SAMPLE["observed"]
        c.text(x + w, y + 4.5, obs, 8.5, alpha=0.62, anchor="rm")
        return y + 12

    # 宽档：AQI 紧跟城市，中间放观测时刻，右侧品牌
    #
    # 观测时刻**必须**放这一行。最初放在天气主区（温度右侧），结果右半边
    # 是 2×2 指标格 —— 「观测 14:30」直接压在「气压」上还被截断成「观测 14:3」。
    # 顶栏这一行算下来：城市43 + AQI 60 + 观测 55 + 品牌 79 = 237 < 272，放得下。
    px = x + 13 + c.measure(SAMPLE["city"], 10.5, bold=True) + 7
    c.paste(c.rounded(pw, 15, 7.5, "#000000" if glass else "#FFFFFF",
                      0.20 if glass else 0.16), px, y - 8.5)
    c.paste(c.circle(6, SAMPLE["aqi_color"]), px + 6, y - 5)
    # 文字起点从 13 起（圆点占 6~12）：起点若早于 12，圆点会盖住首字
    # （预览里「AQI」被盖成了「AGI」）。
    c.text(px + 13 + c.measure(pill, 8.5, bold=True) / 2, y - 1, pill, 8.5,
           bold=True, anchor="mm")
    obs = SAMPLE["observed"]
    # 留出 ≥8dp 的间隔：胶囊右缘与「观测」贴在一起会读成一串
    ox = max(px + pw + 8, x + w - brand_w - 10 - c.measure(obs, 8.5))
    c.text(ox, y - 1, obs, 8.5, alpha=0.60, anchor="lm")
    return y


def hero(c: Canvas, x, y, w, *, temp=30, icon=25, observed=False):
    """天气主区：图标 + 大温度 + 现象 + 高低温。

    观测时刻**不再**放这里（默认 False）：4×2 档右边是 2×2 指标格，
    右对齐的观测时刻会直接压在「气压」上（预览里看得很清楚）。
    改由 header() 把它放进顶栏那一行。
    """
    c.icon(SAMPLE["weather_icon"], x, y, icon, big=True)
    tx = x + icon + 5
    c.text(tx, y + icon / 2, SAMPLE["temp"], temp, bold=True, anchor="lm")
    tw_ = c.measure(SAMPLE["temp"], temp, bold=True)
    c.text(tx + tw_ + 4, y + 1, SAMPLE["cond"], 9.5, alpha=0.9, bold=True)
    c.text(tx + tw_ + 4, y + 13, SAMPLE["range"], 9, alpha=0.74)
    if observed:
        sx = tx + tw_ + 4 + c.measure(SAMPLE["range"], 9) + 6
        c.text(sx, y + 13, SAMPLE["observed"], 8, alpha=0.55)
    return y + icon


def kv(c: Canvas, x, y, w, label, value):
    """面板 _kvPair 的复刻：标签左（白 0.58），值右（加粗纯白）。"""
    c.text(x, y + 6, label, 9, alpha=0.58, anchor="lm")
    c.text(x + w, y + 6, value, 10, bold=True, anchor="rm")


def tip(c: Canvas, x, y, w, level, icon, text, *, lines=2, size=9):
    """一条通栏建议 —— 与面板 _tipRow 同构：圆点 + 图标 + 级别 + 正文。"""
    c.paste(c.circle(6, LEVEL_LIT[level]), x, y + 3)
    bx = x + 11
    c.icon(icon, bx, y, 11, color=LEVEL_LIT[level])
    c.text(bx + 14, y + 5.5, LEVEL_LABEL[level], 8.5, bold=True,
           color=LEVEL_LIT[level], anchor="lm")
    fy = y + 12
    for ln in wrap(c, text, size, w - 11, lines):
        c.text(bx, fy, ln, size, alpha=0.93)
        fy += 12.5
    return fy


def section_title(c: Canvas, x, y, w, count=None):
    """面板 _sectionTitle 同款：小号 + 加粗 + 白 0.8，前面一个图标。"""
    c.icon("rss_feed", x, y, 11, color="#FFFFFF")
    c.text(x + 14, y + 5.5, SAMPLE["tips_title"], 9.5, alpha=0.8, bold=True,
           anchor="lm")
    if count:
        c.text(x + w, y + 5.5, count, 9, alpha=0.55, anchor="rm")
    return y + 14


# ── 4×2 主档（方案 A · 平铺海报式：用户选定）──────────────────────────
def render_tile(w=296, h=140, kind="clear", glass=False):
    c = Canvas(w, h, kind)
    pad = 12 if not glass else 18
    x, iw = pad, w - pad * 2
    if glass:
        c.paste(c.rounded(w - 14, h - 14, 22, "#FFFFFF", 0.19, 0.14), 7, 7)
    y = header(c, x, 9 if not glass else 12, iw, glass=glass)
    c.hairline(x, y, iw)
    y += 7
    hero(c, x, y, iw, temp=30, icon=25, observed=False)
    # 指标区从 42% 处起（原来 48%）：每格只有 ~60dp 时「气压」+「1013 hPa」
    # 会挤到貼在一起（预览里就是「气压1013 hPa」）。放宽到 ~75dp/格后
    # 标签与值之间才有余量；左栏仍有 ~99dp，放得下「图标 25 + 31° + 雷阵雨」。
    rx = x + iw * 0.42
    rw = x + iw - rx
    for i, (lab, val) in enumerate(SAMPLE["metrics"]):
        col, row = i % 2, i // 2
        kv(c, rx + col * rw / 2, y + row * 14 - 1, rw / 2 - 10, lab, val)
    y += 30
    c.hairline(x, y, iw)
    y += 6
    # 第一条完整两行；第二条一行（高度就这么多，宁可诚实地截断）
    for idx, (level, icon, text) in enumerate(SAMPLE["tips"]):
        y = tip(c, x, y, iw, level, icon, text,
                lines=2 if idx == 0 else 1) + 2
    return c.out_clipped(20), y


# ── 2×4 竖长档（小面板）────────────────────────────────────────────
def render_tall(w=150, h=300, kind="clear"):
    c = Canvas(w, h, kind)
    x, iw = 12, w - 24
    y = header(c, x, 10, iw, narrow=True)
    c.hairline(x, y, iw)
    y += 8
    c.icon(SAMPLE["weather_icon"], x, y, 26, big=True)
    y += 30
    c.text(x, y + 12, SAMPLE["temp"], 32, bold=True, anchor="lm")
    y += 26
    c.text(x, y + 3, SAMPLE["cond"], 10, alpha=0.9, bold=True)
    c.text(x + iw, y + 3, SAMPLE["range"], 9, alpha=0.74, anchor="ra")
    y += 14
    # 观测时刻已在 header 的窄档第二行里显示，这里**不再重复**。
    # （预览里发现 2×4 档出现了两个「观测 14:30」。）
    y += 1
    c.hairline(x, y, iw)
    y += 7
    # 指标只放 3 项、建议每条只给 2 行 —— 竖长档也不高，
    # 4 项指标 + 2×3 行建议实测超 23dp（预览的高度门禁会报出来）。
    # 宁可少一项，也不要让底部被裁掉半行字。
    for lab, val in SAMPLE["metrics"][:3]:
        kv(c, x, y, iw, lab, val)
        y += 14
    y += 3
    c.hairline(x, y, iw)
    y += 6
    y = section_title(c, x, y, iw, count=str(len(SAMPLE["tips"])))
    for level, icon, text in SAMPLE["tips"]:
        y = tip(c, x, y, iw, level, icon, text, lines=2) + 4
    return c.out_clipped(20), y


# ── 2×2 紧凑档 ──────────────────────────────────────────────────────
def render_compact(w=150, h=150, kind="clear"):
    c = Canvas(w, h, kind, radius_dp=16)
    x, iw = 11, w - 22
    y = header(c, x, 9, iw, narrow=True)
    c.hairline(x, y, iw)
    y += 7
    hero(c, x, y, iw, temp=25, icon=21, observed=False)
    y += 28
    c.hairline(x, y, iw)
    y += 5
    level, icon, text = SAMPLE["tips"][0]
    y = tip(c, x, y, iw, level, icon, text, lines=3, size=8.5)
    return c.out_clipped(16), y


# ── 4×1 单行档 ──────────────────────────────────────────────────────
def render_row(w=296, h=72, kind="clear"):
    c = Canvas(w, h, kind, radius_dp=16)
    x = 12
    y = (h - 22) / 2
    c.icon(SAMPLE["weather_icon"], x, y, 22, big=True)
    x += 26
    c.text(x, y + 12, SAMPLE["temp"], 20, bold=True, anchor="lm")
    x += c.measure(SAMPLE["temp"], 20, bold=True) + 5
    c.text(x, y + 7, SAMPLE["cond"], 9.5, alpha=0.9, bold=True, anchor="lm")
    c.text(x, y + 18, SAMPLE["range"], 9, alpha=0.74, anchor="lm")
    x += max(c.measure(SAMPLE["cond"], 9.5, bold=True),
             c.measure(SAMPLE["range"], 9)) + 11
    # 竖线分隔（宽度明显些，否则看不清）
    c.d.rectangle([round((x - 6) * SCALE), round((y + 2) * SCALE),
                   round((x - 6) * SCALE) + SCALE - 1, round((y + 20) * SCALE)],
                  fill=rgba("#FFFFFF", 0.22))
    # 右端只放 logo，**不放 App 名称**：
    # 4×1 只有 296dp 宽，一行里要挤下 温度/天气/高低温 再加一条建议。
    # 如果再把「APRSlocus」也写上去，建议会被截成「雷雨天气…」—— 等于没给信息。
    # logo 单独一个就足以表明这是谁的组件，把宽度还给建议。
    brand_w = 17 + 8
    avail = w - 12 - (x + 30) - brand_w - 6
    level, icon, text = SAMPLE["tips"][0]
    c.paste(c.circle(6, LEVEL_LIT[level]), x + 4, y + 9)
    c.icon(icon, x + 15, y + 6, 11, color=LEVEL_LIT[level])
    lines = wrap(c, text, 9, avail - 11, 1)
    c.text(x + 30, y + 12, lines[0] if lines else text, 9, alpha=0.93, anchor="lm")
    c.logo(w - 12 - 17, y + 5.5, 17)
    return c.out_clipped(16), h


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="/tmp/widget_preview.png")
    args = ap.parse_args()

    specs = [
        ("4×2 主档 · 平铺海报式（已选定）", render_tile, 296, 140),
        ("4×2 主档 · 同上（雷雨天气）", lambda **k: render_tile(kind="storm"), 296, 140),
        ("2×4 竖长档（小面板）", render_tall, 150, 300),
        ("2×2 紧凑档", render_compact, 150, 150),
        ("4×1 单行档", render_row, 296, 72),
    ]
    tiles = []
    print("内容高度 vs 卡片高度（溢出会被圆角裁掉，看到截断就是真排不下）：")
    overflows = []
    for label, fn, w_dp, h_dp in specs:
        img, used = fn()
        over = used - h_dp
        if over > 1:
            overflows.append(f"{label} 超出 {over:.1f}dp")
            print(f"  ✗ {label:26} 内容 {used:5.1f}dp / 卡片 {h_dp:3d}dp  溢出！")
        else:
            print(f"  ✓ {label:26} 内容 {used:5.1f}dp / 卡片 {h_dp:3d}dp  "
                  f"（余 {h_dp - used:.1f}dp）")
        tiles.append((label, img))

    PAD, GAP, LH = 26, 22, 30
    row1, row2 = tiles[:3], tiles[3:]
    W = PAD * 2 + sum(im.width for _, im in row1) + GAP * (len(row1) - 1)
    H = PAD + LH + max(im.height for _, im in row1) + GAP + LH + \
        max(im.height for _, im in row2) + PAD
    sheet = Image.new("RGBA", (W, H), (22, 26, 33, 255))
    d = ImageDraw.Draw(sheet)

    def blit(items, y0):
        x = PAD
        for name, im in items:
            d.text((x, y0), name, font=font(11, True), fill=(214, 223, 238, 255))
            sheet.alpha_composite(im, (x, y0 + LH))
            x += im.width + GAP
    blit(row1, PAD)
    blit(row2, PAD + LH + max(im.height for _, im in row1) + GAP)

    sheet.convert("RGB").save(args.out)
    print("预览:", args.out, sheet.size)
    if overflows:
        # 溢出必须让命令失败：否则「设计排不下」这件事会静静躺在输出里没人看，
        # 直到装到手机上才发现底部被裁。
        print("\n❌ 有档位内容排不下：", file=sys.stderr)
        for o in overflows:
            print(f"  - {o}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
