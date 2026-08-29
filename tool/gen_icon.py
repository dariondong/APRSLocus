from PIL import Image, ImageDraw
import os

SIZES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}
OUT = "android/app/src/main/res"


def draw_icon(size):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # 渐变背景：左上 #0A5CFF → 右下 #003D99
    for y in range(size):
        for x in range(size):
            t = (x + y) / (2 * size)
            r = int(10 + (0 - 10) * t)
            g = int(92 + (61 - 92) * t)
            b = int(255 + (153 - 255) * t)
            img.putpixel((x, y), (r, g, b, 255))

    # 圆角矩形蒙版
    r_radius = int(size * 0.22)
    mask = Image.new("L", (size, size), 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.rounded_rectangle([(0, 0), (size - 1, size - 1)], radius=r_radius, fill=255)
    img.putalpha(mask)

    cx = size / 2
    cy = size / 2
    s = size / 512

    # 中心实心圆
    cr = int(46 * s)
    draw.ellipse([cx - cr, cy - cr, cx + cr, cy + cr], fill="white")

    # 三层同心圆环
    for (radius, width, alpha) in [(84, 16, 255), (124, 14, 255), (162, 12, 166)]:
        rr = int(radius * s)
        ww = int(width * s)
        color = (255, 255, 255, alpha)
        # PIL arc 不支持透明，先画在临时图层
        ring = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        ring_draw = ImageDraw.Draw(ring)
        ring_draw.ellipse(
            [cx - rr, cy - rr, cx + rr, cy + rr],
            outline="white", width=ww,
        )
        if alpha < 255:
            ring.putalpha(Image.new("L", (size, size), alpha))
        img = Image.alpha_composite(img, ring)

    # 左右信号点
    draw2 = ImageDraw.Draw(img)
    for dx in [-144, 144]:
        pr = int(12 * s)
        px = cx + dx * s
        draw2.ellipse([px - pr, cy - pr, px + pr, cy + pr], fill="white")

    return img


for folder, sz in SIZES.items():
    icon = draw_icon(sz)
    path = os.path.join(OUT, folder, "ic_launcher.png")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    icon.save(path, "PNG")
    print(f"  {folder}: {sz}x{sz}")

print("done")
