#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""一次性脚本：为「粗定位（网络）不自动上报」补/改 l10n 键（6 语言）。

同时更新：
  * lib/l10n/app_*.arb                （真源）
  * lib/l10n/app_localizations.dart   （抽象类成员）
  * lib/l10n/app_localizations_*.dart （各语言实现）

还负责**改写已有键的文案**：`locModeNetHint` 里写着「GPS 停更 2 分钟」，而
v1.6.163 把策略层的等待提到了 5 分钟 —— 文案不跟着改就成了假话，而这种假话
没有任何编译期检查会拦（arb 是纯 JSON，改文案不会让任何测试变红）。

产物按 gen-l10n 的形状手写（仓库把产物提交进了 git，本机不能跑 gen-l10n），
写完由 tool/check_l10n_sync.py 校验 arb ↔ 产物一一对应。
"""
import io
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

LANGS = ['zh', 'zh_TW', 'en', 'ja', 'es', 'id']
IDX = {lg: i for i, lg in enumerate(LANGS)}

# key → (zh, zh_TW, en, ja, es, id)
KEYS = {
    'beaconCoarseFix': (
        '网络定位中 · 暂不自动上报',
        '網路定位中 · 暫不自動上報',
        'Network fix · auto beacon paused',
        'ネットワーク測位中 · 自動送信を停止',
        'Posición de red · baliza automática en pausa',
        'Lokasi jaringan · beacon otomatis dijeda',
    ),
    'beaconCoarseHint': (
        '当前定位来自网络（粗，误差常达几百米）—— 自动上报已暂停，GPS 恢复后自动继续；'
        '期间仍可手动上报。',
        '目前定位來自網路（粗，誤差常達幾百公尺）—— 自動上報已暫停，GPS 恢復後自動繼續；'
        '期間仍可手動上報。',
        'The current fix comes from the network (coarse, often hundreds of metres off) — '
        'automatic reports are paused and resume once GPS is back. You can still beacon '
        'manually.',
        '現在の測位はネットワーク由来です（粗く、数百メートルずれることも）。'
        '自動送信は停止し、GPS が戻れば再開します。手動送信は可能です。',
        'La posición actual viene de la red (aproximada, a menudo cientos de metros) — '
        'los informes automáticos están en pausa y se reanudan al volver el GPS. '
        'Aún puedes balizar manualmente.',
        'Posisi saat ini berasal dari jaringan (kasar, bisa meleset ratusan meter) — '
        'laporan otomatis dijeda dan lanjut setelah GPS kembali. Anda masih bisa '
        'memancarkan beacon secara manual.',
    ),
}

# 改写已有键（必须与策略层的常数一致 —— 见 lib/state.dart 的 _kCoarseHoldSec）
UPDATES = {
    'locModeNetHint': (
        '网络/基站定位误差常在几百米。为免地图上的「我」来回跳，只有 GPS 停更 5 分钟后'
        '才用它兜底；粗定位点不写进轨迹与历史，也不会触发自动上报。',
        '網路/基地台定位誤差常在幾百公尺。為免地圖上的「我」來回跳，只有 GPS 停更 '
        '5 分鐘後才用它兜底；粗定位點不寫進軌跡與歷史，也不會觸發自動上報。',
        'Cell and Wi-Fi fixes can be hundreds of metres off. So that the "me" marker does '
        'not jump around, they are used only after GPS has been stale for 5 minutes; '
        'coarse fixes are never written to the track or history, and never trigger an '
        'automatic report.',
        '基地局・Wi-Fi 測位は数百メートルずれることがあります。地図上の「自分」が'
        '飛び回らないよう、GPS が 5 分途切れたときだけ補助に使い、軌跡と履歴には'
        '記録せず、自動送信も行いません。',
        'Las posiciones por red pueden desviarse cientos de metros. Para que el marcador '
        'no salte, solo se usan si el GPS lleva 5 minutos sin actualizarse; nunca se '
        'guardan en la ruta ni el historial, y nunca provocan un informe automático.',
        'Lokasi seluler/Wi-Fi bisa meleset ratusan meter. Agar penanda tidak meloncat, '
        'hanya dipakai setelah GPS putus 5 menit; tidak pernah dicatat ke lintasan atau '
        'riwayat, dan tidak memicu laporan otomatis.',
    ),
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
    """返回 (类体起始, 类体结束) 两个索引。"""
    m = re.search(r'(?m)^(?:abstract )?class ' + re.escape(name) + r'\b', src)
    if not m:
        raise SystemExit(f'找不到类 {name}')
    j = src.find('\n}\n', m.end())
    if j < 0:
        j = src.rfind('\n}')
    return m.end(), j


def line_str(value):
    """arb 里的一行字符串值（转义、引号由 json 负责）。"""
    return json.dumps(value, ensure_ascii=False)


def main() -> int:
    root = ROOT
    arb_dir = os.path.join(root, 'lib', 'l10n')

    # ① ARB：新增键
    for lg in LANGS:
        p = os.path.join(arb_dir, f'app_{lg}.arb')
        src = io.open(p, encoding='utf-8', newline='').read()
        add = []
        for key, vals in KEYS.items():
            if re.search(r'^\s*"' + re.escape(key) + r'":', src, re.M):
                print(f'  {lg}/{key}: 已存在，跳过')
                continue
            add.append(f'  {line_str(key)}: {line_str(vals[IDX[lg]])},')
        if not add:
            continue
        i = src.rstrip().rfind('}')
        head = src[:i].rstrip()
        if not head.endswith(','):
            head += ','
        src = head + '\n' + '\n'.join(add).rstrip(',') + '\n' + src[i:]
        io.open(p, 'w', encoding='utf-8', newline='').write(src)
        print(f'{lg}: ARB 追加 {len(add)} 键')

    # ② ARB：改写已有键（整行替换，保留行首缩进与行尾逗号）
    for lg in LANGS:
        p = os.path.join(arb_dir, f'app_{lg}.arb')
        src = io.open(p, encoding='utf-8', newline='').read()
        n = 0
        for key, vals in UPDATES.items():
            pat = re.compile(r'(?m)^(\s*)"' + re.escape(key) + r'":\s*".*?"(,?)$')
            new_line = f'\\g<1>{line_str(key)}: {line_str(vals[IDX[lg]])}\\g<2>'
            src, k = pat.subn(new_line, src)
            if k != 1:
                raise SystemExit(f'{lg}/{key}: 期望替换 1 处，实际 {k} 处')
            n += k
        io.open(p, 'w', encoding='utf-8', newline='').write(src)
        print(f'{lg}: ARB 改写 {n} 键')

    # ③ 抽象类（app_localizations.dart）
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

    # ④ 各语言实现：新增 + 改写
    for lg in LANGS:
        name = CLASSES[lg]
        fn = ('app_localizations_zh.dart' if lg in ('zh', 'zh_TW')
              else f'app_localizations_{lg}.dart')
        p = os.path.join(arb_dir, fn)
        src = io.open(p, encoding='utf-8', newline='').read()
        b0, b1 = class_body(src, name)
        body = src[b0:b1]
        code = []
        for key, vals in KEYS.items():
            if re.search(r'String get ' + re.escape(key) + r'\s*[=;]', body):
                continue
            code.append('  @override')
            code.append(f'  String get {key} => {line_str(vals[IDX[lg]])};')
            code.append('')
        if code:
            src = src[:b1] + '\n' + '\n'.join(code)[:-1] + src[b1:]
            b0, b1 = class_body(src, name)
        # 改写已有实现（只在该类体内找，类名不同故不会串语言）
        body = src[b0:b1]
        for key, vals in UPDATES.items():
            pat = re.compile(r'(?m)^(  )String get ' + re.escape(key) +
                             r' => .*?;( *)$')
            new_line = (f'\\g<1>String get {key} => '
                        f'{line_str(vals[IDX[lg]])};\\g<2>')
            body, k = pat.subn(new_line, body)
            if k != 1:
                raise SystemExit(f'{name}.{key}: 期望替换 1 处，实际 {k} 处')
        src = src[:b0] + body + src[b1:]
        io.open(p, 'w', encoding='utf-8', newline='').write(src)
        print(f'{name}: 实现更新（新增 {len(code) // 3} 键，改写 {len(UPDATES)} 键）')

    return 0


if __name__ == '__main__':
    sys.exit(main())
