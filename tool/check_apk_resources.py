#!/usr/bin/env python3
"""检查一个已构建 APK 的产物内容（本机没有 Android SDK 时的唯一验证手段）。

用法：
    python3 tool/check_apk_resources.py release.apk
    python3 tool/check_apk_resources.py release.apk --expect aw_widget_sys aw_chipsoft_good

为什么要单独写这个脚本：本机只有 Flutter SDK、没有 Android SDK，
`aapt2` / `apksigner` / `apkanalyzer` 都不可用，于是「资源到底有没有编进去」
只能靠拆 APK 自查。踩过的三个坑决定了它必须这么写：

① **release 构建会做资源路径混淆**：APK 里是 `res/0T.xml` 这种名字，
   所以按文件名找 `-night` 目录行不通（会误判成「没有夜间资源」）。
② **arsc 的字符串池会去重**：同一个资源名只存一份字符串，
   所以按「名字出现几次」判断有几套配置也不行。
③ **type chunk 嵌在 package chunk 内部**，不是最外层 ——
   在最外层扫 type chunk 会得到 0 个（我第一次就这么写的）。
   而且 `ResTable_type` 的 config 从 **+20** 开始（chunk_header 8 +
   id 1 + flags 1 + reserved 2 + entryCount 4 + entriesStart 4），
   算成 +16 会读出一堆垃圾 size（180/1608/…）。

所以：真解析 arsc，逐个 type chunk 读 `ResTable_config.uiMode`
（偏移 29，bit 5 = NIGHT_YES）。
"""
import argparse
import collections
import struct
import sys
import zipfile

TYPE_CHUNK = 0x0201
TYPE_SPEC = 0x0202
PKG_CHUNK = 0x0200
TABLE_CHUNK = 0x0002

# ResTable_config 内各字段的偏移（API 8+ 布局）
CFG_SIZE = 0
CFG_LANG = 8
CFG_DENSITY = 14
CFG_UIMODE = 29

# UI_MODE_NIGHT 掩码占 bit 4-5
NIGHT_YES = 0x20

# ResTable_type 的 config 起点
TYPE_CFG_OFF = 8 + 1 + 1 + 2 + 4 + 4


def iter_chunks(data, start, end):
    """遍历 [start,end) 内的同级 chunk：yield (offset, type, headerSize, size)"""
    off = start
    while off + 8 <= end:
        ctype, hsize, csize = struct.unpack_from("<HHI", data, off)
        if csize < 8 or off + csize > end:
            return
        yield off, ctype, hsize, csize
        off += csize


def read_configs(data):
    """返回每个 type chunk 的 (configSize, lang, density, uiMode)。"""
    rows = []
    for off, ctype, hsize, csize in iter_chunks(data, 0, len(data)):
        if ctype != TABLE_CHUNK:
            continue
        for poff, ptype, phsize, psize in iter_chunks(
                data, off + hsize, off + csize):
            if ptype != PKG_CHUNK:
                continue
            for toff, ttype, thsize, tsize in iter_chunks(
                    data, poff + phsize, poff + psize):
                if ttype != TYPE_CHUNK:
                    continue
                cfg = toff + TYPE_CFG_OFF
                if cfg + 32 > len(data):
                    continue
                csz = struct.unpack_from("<I", data, cfg)[CFG_SIZE]
                lang = data[cfg + CFG_LANG:cfg + CFG_LANG + 2]
                dens = struct.unpack_from("<H", data, cfg + CFG_DENSITY)[0]
                ui = data[cfg + CFG_UIMODE] if csz > CFG_UIMODE else 0
                rows.append((csz, lang, dens, ui))
    return rows


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("apk")
    ap.add_argument("--expect", nargs="*", default=[],
                    help="必须存在的资源名（如 aw_widget_sys）")
    args = ap.parse_args()

    z = zipfile.ZipFile(args.apk)
    names = z.namelist()
    try:
        arsc = z.read("resources.arsc")
    except KeyError:
        print("✗ APK 里没有 resources.arsc", file=sys.stderr)
        return 1

    print(f"=== {args.apk} ===")
    print(f"条目 {len(names)} 个，resources.arsc {len(arsc)/1024/1024:.1f} MB")

    # ── 签名：debug 密钥的证书里带 "Android Debug" ──
    blob = open(args.apk, "rb").read()
    is_debug = b"Android Debug" in blob
    print(f"签名: {'⚠ debug 签名（无法覆盖正式版安装）' if is_debug else '✅ 非 debug（release 签名）'}")

    # ── 清单里的组件 ──
    try:
        man = z.read("AndroidManifest.xml").decode("utf-16-le", "replace")
        recv = sorted({m for m in
                       ("WeatherWidgetProvider", "HfWidgetProvider",
                        "SysWidgetProvider") if m in man})
        print(f"清单里的组件: {recv if recv else '（未找到）'}")
    except KeyError:
        pass

    # ── 资源名是否存在 ──
    if args.expect:
        print("\n期望存在的资源:")
        bad = 0
        for n in args.expect:
            hit = n.encode("utf-16-le") in arsc or n.encode("utf-8") in arsc
            print(f"  {'✅' if hit else '❌'} {n}")
            bad += 0 if hit else 1
    else:
        bad = 0

    # ── 配置变体（夜间 / 语言 / 密度）──
    rows = read_configs(arsc)
    if not rows:
        print("\n⚠ 没解析出任何 type chunk —— 解析器可能不适配这个 arsc 版本")
        return 1
    sizes = collections.Counter(r[0] for r in rows)
    night = sum(1 for r in rows if r[3] & NIGHT_YES)
    langs = sum(1 for r in rows if r[1] != b"\x00\x00")
    dens = sum(1 for r in rows if r[2] != 0)
    print(f"\ntype chunk {len(rows)} 个（config.size 分布 {dict(sizes)}）")
    print(f"  locale 变体 {langs} 个 ｜ density 变体 {dens} 个 ｜ "
          f"**夜间变体 {night} 个**")
    # 自检：config.size 应当是个已知的合法值；全是同一个值说明解析对齐了
    if len(sizes) > 1 or min(sizes) < 28:
        print("  ⚠ config.size 异常，解析可能未对齐（先用 locale/density "
              "计数交叉验证）")
    if night == 0:
        print("  ⚠ 没有夜间配置 —— 检查 values-night/ 是否被正确编译")
        bad += 1
    else:
        print("  ✅ 夜间配置已编入（暗黑模式资源就位）")

    print()
    print("❌ 有缺失（见上）" if bad else "✅ 检查通过")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
