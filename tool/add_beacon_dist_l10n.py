#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""为「智能信标 · 距离打点」补 l10n 键（6 语言）。

背景：智能信标原来只有「按速度分档 → 每档一个时间间隔」。用户要求「同时支持
间隔距打点」—— 也就是「走得够远也补一个点」。需要三个键：

  * `tierMinDist`      —— 编辑弹窗里的字段标题（移动距离/米）
  * `tierMinDistHint`  —— 那一行说明（0 = 关闭，只用间隔）
  * `orMoveM`          —— 档位行上的展示（`每 60 秒 · 或移动 400 m`）

写入约定与 tool/add_glass_full_l10n.py 一致：幂等、追加到 ARB 末尾。
**同时更新 gen-l10n 产物**（本机没有 flutter，跑不了 gen-l10n；而产物是提交进
git 的，见 tool/check_l10n_sync.py 的说明）—— 产物按生成器的排版手写：
抽象类里一条声明、每个语言类里一条实现。check_l10n_sync 会校验两边对应。
"""
import io
import json
import os
import re
import sys

# 键 → (zh, zh_TW, en, ja, es, id)
KEYS = {
    'tierMinDist': ('移动距离 (米)', '移動距離 (公尺)', 'Distance (m)',
                    '移動距離 (m)', 'Distancia (m)', 'Jarak (m)'),
    'tierMinDistHint': (
        '自上次上报以来移动超过这个距离，就补报一次；0 = 关闭（只按间隔）',
        '自上次上報以來移動超過這個距離，就補報一次；0 = 關閉（只按間隔）',
        'Also beacon after moving this far since the last report; '
        '0 = off (interval only)',
        '前回の報告からこの距離を移動したら追加で報告します。'
        '0 = オフ（間隔のみ）',
        'También reporta tras desplazarse esta distancia desde el último '
        'envío; 0 = desactivado (solo intervalo)',
        'Juga lapor setelah berpindah sejauh ini sejak laporan terakhir; '
        '0 = nonaktif (hanya interval)'),
    'orMoveM': ('或移动 {dist} m', '或移動 {dist} m', 'or {dist} m',
                'または {dist} m', 'o {dist} m', 'atau {dist} m'),
    # v1.6.156：智能信标的第三路判据 —— 转弯打点
    'tierMinTurn': ('航向变化 (度)', '航向變化 (度)', 'Turn (degrees)',
                    '方位変化 (度)', 'Giro (grados)', 'Belokan (derajat)'),
    'tierMinTurnHint': (
        '转过这个角度就补报一次（可填 10~180）；0 = 关闭。只在行驶中生效（停着不动时航向是噪声）',
        '轉過這個角度就補報一次（可填 10~180）；0 = 關閉。只在行駛中生效（停著不動時航向是雜訊）',
        'Beacon once after turning this far (10–180); 0 = off. Only while moving '
        '(heading is noise when parked)',
        'この角度を曲がったら追加で報告します。0 = オフ。'
        '走行中のみ有効（停車中は方位がノイズ）',
        'Reporta tras girar este ángulo; 0 = desactivado. Solo en movimiento '
        '(parado, el rumbo es ruido)',
        'Lapor setelah berbelok sejauh ini; 0 = nonaktif. Hanya saat bergerak '
        '(saat berhenti, arah hanya derau)'),
    'orTurnDeg': ('或转 {deg}°', '或轉 {deg}°', 'or {deg}°',
                  'または {deg}°', 'o {deg}°', 'atau {deg}°'),
}

# 带占位符的键（生成产物要用函数签名而不是 getter）
PLACEHOLDER_KEYS = {'orMoveM': ['dist'], 'orTurnDeg': ['deg']}

LANGS = ['zh', 'zh_TW', 'en', 'ja', 'es', 'id']
IDX = {lg: i for i, lg in enumerate(LANGS)}

# 语言 → (产物文件, 类名)——zh_TW 与 zh 同文件不同类
TARGETS = [
    ('zh', 'app_localizations_zh.dart', 'AppLocalizationsZh'),
    ('zh_TW', 'app_localizations_zh.dart', 'AppLocalizationsZhTw'),
    ('en', 'app_localizations_en.dart', 'AppLocalizationsEn'),
    ('ja', 'app_localizations_ja.dart', 'AppLocalizationsJa'),
    ('es', 'app_localizations_es.dart', 'AppLocalizationsEs'),
    ('id', 'app_localizations_id.dart', 'AppLocalizationsId'),
]


def add_to_arb(arb_dir):
    total = 0
    for lg in LANGS:
        p = os.path.join(arb_dir, f'app_{lg}.arb')
        src = io.open(p, encoding='utf-8').read()
        add = []
        for key, vals in KEYS.items():
            if re.search(r'^\s*"' + re.escape(key) + r'":', src, re.M):
                continue
            add.append(f'  {json.dumps(key, ensure_ascii=False)}: '
                       f'{json.dumps(vals[IDX[lg]], ensure_ascii=False)},')
            if key in PLACEHOLDER_KEYS:
                holders = ', '.join(
                    f'"{h}": {{"type": "String"}}' for h in PLACEHOLDER_KEYS[key])
                add.append(f'  "@{key}": {{"placeholders": {{{holders}}}}},')
        if not add:
            continue
        i = src.rstrip().rfind('}')
        head = src[:i].rstrip()
        if not head.endswith(','):
            head += ','
        src = head + '\n' + '\n'.join(add).rstrip(',') + '\n' + src[i:]
        io.open(p, 'w', encoding='utf-8').write(src)
        total += len(add)
        print(f'  arb {lg}: 追加 {len(add)} 行')
    return total


def sig(key):
    """生成产物里的成员签名（带占位符的用函数，其余用 getter）。"""
    args = PLACEHOLDER_KEYS.get(key)
    return f'String {key}({"String " + ", String ".join(args)})' if args \
        else f'String get {key}'


def add_to_generated(l10n_dir, langs_used):
    """往每个语言类里追加实现（抽象类里追加声明）。"""
    # 1) 抽象类
    p = os.path.join(l10n_dir, 'app_localizations.dart')
    src = io.open(p, encoding='utf-8').read()
    missing = [k for k in KEYS if not re.search(
        r'String (?:get )?' + re.escape(k) + r'\s*[;(<={]', src)]
    if missing:
        blocks = []
        for k in missing:
            zh = KEYS[k][0]
            if k in PLACEHOLDER_KEYS:
                body = f'String {k}(String dist);'
            else:
                body = f'String get {k};'
            blocks.append(
                f'  /// No description provided for @{k}.\n'
                f'  ///\n'
                f'  /// In zh, this message translates to:\n'
                f'  /// **{json.dumps(zh, ensure_ascii=False)}**\n'
                f'  {body}')
        anchor = '  /// No description provided for @tierIdleTitle.'
        assert anchor in src, '抽象类锚点缺失'
        src = src.replace(anchor, '\n\n'.join(blocks) + '\n\n' + anchor, 1)
        io.open(p, 'w', encoding='utf-8').write(src)
        print(f'  抽象类: 追加 {len(missing)} 条声明')

    # 2) 各语言类
    for lg, fname, cls in TARGETS:
        p = os.path.join(l10n_dir, fname)
        src = io.open(p, encoding='utf-8').read()
        body = class_body(src, cls)
        if body is None:
            print(f'  !! 找不到类 {cls}（{fname}）')
            return False
        missing = [k for k in KEYS if not re.search(
            r'String (?:get )?' + re.escape(k) + r'\s*[;(<={]', body)]
        if not missing:
            continue
        blocks = []
        for k in missing:
            raw = KEYS[k][IDX[lg]]
            lit = raw.replace('$', r'\$')
            if k in PLACEHOLDER_KEYS:
                n = PLACEHOLDER_KEYS[k][0]
                blocks.append(
                    f'  @override\n'
                    f'  String {k}(String {n}) {{\n'
                    f'    return {dart_string(lit, {n: n})};\n'
                    f'  }}')
            else:
                blocks.append(
                    f'  @override\n'
                    f'  String get {k} => {dart_string(lit)};')
        # 锚点：该语言类里 everyNSeconds 的实现块之后
        m = re.search(
            r'(?m)^  @override\n  String everyNSeconds\(String sec\) \{\n'
            r'.*?\n  \}\n', src[src.find(f'class {cls}'):], re.S)
        if not m:
            print(f'  !! {cls} 里找不到 everyNSeconds 锚点')
            return False
        off = src.find(f'class {cls}') + m.end()
        src = src[:off] + '\n' + '\n\n'.join(blocks) + '\n' + src[off:]
        io.open(p, 'w', encoding='utf-8').write(src)
        print(f'  产物 {fname}/{cls}: 追加 {len(missing)} 条')
    return True


def dart_string(lit, holders=None):
    """把带 {ph} 的文案转成 Dart 字符串字面量（占位符换成插值）。"""
    out = lit
    if holders:
        for h in holders:
            out = out.replace('{' + h + '}', '${' + h + '}')
    return "'" + out.replace("'", r"\'") + "'"


def class_body(src, name):
    m = re.search(r'(?m)^(?:abstract )?class ' + re.escape(name) + r'\b', src)
    if not m:
        return None
    end = src.find('\n}', m.end())
    return src[m.end():end] if end > 0 else None


def main() -> int:
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    l10n = os.path.join(root, 'lib', 'l10n')
    n = add_to_arb(l10n)
    ok = add_to_generated(l10n, LANGS)
    print(f'\narb 共写入 {n} 行；产物更新{"成功" if ok else "失败"}')
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
