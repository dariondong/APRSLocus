#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""一次性脚本：更新「定位模式」文案（6 语言）+ 新增兜底说明键。

改动的不只是措辞 —— 原来写的是「网络辅助，定位更快」，而 v1.6.150 起
网络定位**不再用于加速出图**，只在 GPS 停更 2 分钟后作兜底，且粗定位点
不写轨迹/不进防抖。文案不改就会继续误导用户去勾它。

同时更新：
  * lib/l10n/app_*.arb                （真源）
  * lib/l10n/app_localizations.dart   （抽象类成员）
  * lib/l10n/app_localizations_*.dart （各语言实现）
"""
import io
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

LANGS = ['zh', 'zh_TW', 'en', 'ja', 'es', 'id']
IDX = {lg: i for i, lg in enumerate(LANGS)}

# 要**改写**的既有键（key → 新值 6 语言）
REWRITE = {
    'locModeGpsNetworkDesc': (
        '网络仅作兜底（GPS 停更时），粗定位不写轨迹',
        '網路僅作兜底（GPS 停更時），粗定位不寫軌跡',
        'Network is a fallback only (when GPS goes stale); coarse fixes are '
        'never written to the track',
        'ネットワークは補助のみ（GPS が途切れたとき）。粗い測位は軌跡に記録しません',
        'La red es solo un respaldo (si el GPS se corta); las posiciones '
        'aproximadas no se guardan en la ruta',
        'Jaringan hanya cadangan (saat GPS terputus); lokasi kasar tidak '
        'dicatat ke lintasan'),
}

# 新增键（key → 6 语言）
KEYS = {
    'locModeNetHint': (
        '网络/基站定位误差常在几百米。为免地图上的「我」来回跳，'
        '只有 GPS 停更 2 分钟后才用它兜底，且粗定位点不写进轨迹与历史。',
        '網路/基地台定位誤差常在幾百公尺。為免地圖上的「我」來回跳，'
        '只有 GPS 停更 2 分鐘後才用它兜底，且粗定位點不寫進軌跡與歷史。',
        'Cell and Wi-Fi fixes can be hundreds of metres off. So that the "me" '
        'marker does not jump around, they are used only after GPS has been '
        'stale for 2 minutes, and are never written to the track or history.',
        '基地局・Wi-Fi 測位は数百メートルずれることがあります。地図上の「自分」が'
        '飛び回らないよう、GPS が 2 分途切れたときだけ補助に使い、軌跡と履歴には'
        '記録しません。',
        'Las posiciones por red pueden desviarse cientos de metros. Para que el '
        'marcador no salte, solo se usan si el GPS lleva 2 minutos sin '
        'actualizarse, y nunca se guardan en la ruta ni el historial.',
        'Lokasi seluler/Wi-Fi bisa meleset ratusan meter. Agar penanda tidak '
        'meloncat, hanya dipakai setelah GPS putus 2 menit, dan tidak pernah '
        'dicatat ke lintasan atau riwayat.'),
}

CLASSES = {
    'zh': 'AppLocalizationsZh',
    'zh_TW': 'AppLocalizationsZhTw',
    'en': 'AppLocalizationsEn',
    'ja': 'AppLocalizationsJa',
    'es': 'AppLocalizationsEs',
    'id': 'AppLocalizationsId',
}


def class_body(src, name):
    m = re.search(r'(?m)^(?:abstract )?class ' + re.escape(name) + r'\b', src)
    if not m:
        raise SystemExit(f'找不到类 {name}')
    j = src.find('\n}\n', m.end())
    if j < 0:
        j = src.rfind('\n}')
    return m.end(), j


def main() -> int:
    arb_dir = os.path.join(ROOT, 'lib', 'l10n')

    # ① ARB：改写既有键 + 追加新键
    for lg in LANGS:
        p = os.path.join(arb_dir, f'app_{lg}.arb')
        src = io.open(p, encoding='utf-8', newline='').read()
        n_rew = 0
        for key, vals in REWRITE.items():
            pat = re.compile(r'^(\s*)"' + re.escape(key) + r'":\s*"(?:[^"\\]|\\.)*"',
                             re.M)
            new = f'  {json.dumps(key, ensure_ascii=False)}: ' \
                  f'{json.dumps(vals[IDX[lg]], ensure_ascii=False)}'
            src, k = pat.subn(lambda m: new, src, count=1)
            if k == 0:
                raise SystemExit(f'{lg}: 找不到要改写的键 {key}')
            n_rew += k
        add = []
        for key, vals in KEYS.items():
            if re.search(r'^\s*"' + re.escape(key) + r'":', src, re.M):
                continue
            add.append(f'  {json.dumps(key, ensure_ascii=False)}: '
                       f'{json.dumps(vals[IDX[lg]], ensure_ascii=False)},')
        if add:
            i = src.rstrip().rfind('}')
            head = src[:i].rstrip()
            if not head.endswith(','):
                head += ','
            src = head + '\n' + '\n'.join(add).rstrip(',') + '\n' + src[i:]
        io.open(p, 'w', encoding='utf-8', newline='').write(src)
        print(f'{lg}: 改写 {n_rew} 键，新增 {len(add)} 键')

    # ② 抽象类
    p = os.path.join(arb_dir, 'app_localizations.dart')
    src = io.open(p, encoding='utf-8', newline='').read()
    code = []
    for key in KEYS:
        if f'String get {key};' in src:
            continue
        code.append(f'  /// No description provided for @{key}.')
        code.append('  ///')
        code.append('  /// In zh, this message translates to:')
        code.append(f"  /// **'{KEYS[key][0]}'**")
        code.append(f'  String get {key};')
        code.append('')
    if code:
        _s, j = class_body(src, 'AppLocalizations')
        src = src[:j] + '\n' + '\n'.join(code)[:-1] + src[j:]
        io.open(p, 'w', encoding='utf-8', newline='').write(src)
        print(f'抽象类追加 {len(code) // 6} 键')

    # ③ 各语言实现：改写既有 + 追加新
    for lg in LANGS:
        name = CLASSES[lg]
        fn = ('app_localizations_zh.dart' if lg in ('zh', 'zh_TW')
              else f'app_localizations_{lg}.dart')
        p = os.path.join(arb_dir, fn)
        src = io.open(p, encoding='utf-8', newline='').read()
        b0, b1 = class_body(src, name)
        body, tail = src[b0:b1], src[b1:]
        n_rew = 0
        for key, vals in REWRITE.items():
            # 生成产物的字符串可能是单引号也可能是双引号（gen-l10n 用的是
            # 单引号，但历史上手写过双引号），两种都要认。
            pat = re.compile(
                r'String get ' + re.escape(key) + r'\s*=>\s*'
                r"(?:'(?:[^'\\]|\\.)*'|\"(?:[^\"\\]|\\.)*\")\s*;")
            new = f'String get {key} => ' \
                  f'{json.dumps(vals[IDX[lg]], ensure_ascii=False)};'
            body, k = pat.subn(lambda m: new, body, count=1)
            if k == 0:
                raise SystemExit(f'{lg}: 实现里找不到要改写的 {key}')
            n_rew += k
        code = []
        for key, vals in KEYS.items():
            if re.search(r'String get ' + re.escape(key) + r'\s*[=;]', body):
                continue
            code.append('  @override')
            code.append(f"  String get {key} => "
                        f'{json.dumps(vals[IDX[lg]], ensure_ascii=False)};')
            code.append('')
        src = src[:b0] + body
        if code:
            src += '\n' + '\n'.join(code)[:-1]
        src += tail
        io.open(p, 'w', encoding='utf-8', newline='').write(src)
        print(f'{name}: 改写 {n_rew} 键，新增 {len(code) // 3} 键')

    print('done')
    return 0


if __name__ == '__main__':
    sys.exit(main())
