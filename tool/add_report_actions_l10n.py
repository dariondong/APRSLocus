#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""上报动作文案（6 语言）：把「自动上报开关 / 立即上报」两个按钮的文案统一。

背景：地图页上报状态栏、我的位置面板、沉浸页三处各写了一套「立即上报」语义，
「信标开关 / 射频信标 / 智能信标」几个开关也散在设置页 —— 用户反馈「很乱、
不知道点哪个」。整改后三处共用同一个 BeaconActions（见 lib/widgets.dart），
本文案即它用到的键。
"""
import io
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
L10N = os.path.join(ROOT, 'lib', 'l10n')

KEYS = {
    'reportActions': {
        'zh': '上报', 'zh_TW': '上報',
        'en': 'Report', 'ja': 'レポート', 'id': 'Lapor', 'es': 'Reportar',
    },
    'reportNow': {
        'zh': '立即上报', 'zh_TW': '立即上報',
        'en': 'Report now', 'ja': '今すぐ送信', 'id': 'Lapor sekarang',
        'es': 'Reportar ahora',
    },
    'reportAutoStart': {
        'zh': '开启自动上报', 'zh_TW': '開啟自動上報',
        'en': 'Start auto', 'ja': '自動送信を開始', 'id': 'Mulai otomatis',
        'es': 'Iniciar auto',
    },
    'reportAutoStop': {
        'zh': '停止自动上报', 'zh_TW': '停止自動上報',
        'en': 'Stop auto', 'ja': '自動送信を停止', 'id': 'Hentikan otomatis',
        'es': 'Detener auto',
    },
    'reportTagAuto': {
        'zh': '自动', 'zh_TW': '自動',
        'en': 'AUTO', 'ja': '自動', 'id': 'AUTO', 'es': 'AUTO',
    },
    'reportTagOnce': {
        'zh': '单次', 'zh_TW': '單次',
        'en': 'ONCE', 'ja': '単発', 'id': 'SEKALI', 'es': 'ÚNICA',
    },
    'reportStatusAuto': {
        'zh': '自动上报中', 'zh_TW': '自動上報中',
        'en': 'Auto-reporting', 'ja': '自動送信中', 'id': 'Lapor otomatis',
        'es': 'Reporte automático',
    },
    'reportStatusOnce': {
        'zh': '单次上报', 'zh_TW': '單次上報',
        'en': 'Single report', 'ja': '単発送信', 'id': 'Lapor sekali',
        'es': 'Reporte único',
    },
    'reportToggleHint': {
        'zh': '点一下切换：自动上报＝按间隔 / 距离 / 转弯自动发射；单次上报＝只有点「立即上报」才发射（两者都可以随时手动发一次）。',
        'zh_TW': '點一下切換：自動上報＝按間隔 / 距離 / 轉彎自動發射；單次上報＝只有點「立即上報」才發射（兩者都可以隨時手動發一次）。',
        'en': 'Tap to switch: Auto = transmit on interval / distance / turn; Single = only when you tap “Report now”. Either way you can always send one manually.',
        'ja': 'タップで切替：自動＝間隔 / 距離 / ターンで自動送信、単発＝「今すぐ送信」を押したときだけ送信（どちらも手動送信は可能）。',
        'id': 'Ketuk untuk beralih: Otomatis = kirim sesuai interval / jarak / belokan; Sekali = hanya saat Anda menekan "Lapor sekarang". Keduanya tetap bisa dikirim manual.',
        'es': 'Toca para cambiar: Auto = transmite por intervalo / distancia / giro; Única = solo al pulsar «Reportar ahora». En ambos puedes enviar una manual.',
    },
    'reportRfEnabledToast': {
        'zh': '已开启射频信标并开始自动上报',
        'zh_TW': '已開啟射頻信標並開始自動上報',
        'en': 'RF beacon enabled — auto-reporting started',
        'ja': 'RF ビーコンを有効化し、自動送信を開始しました',
        'id': 'Beacon RF aktif — lapor otomatis dimulai',
        'es': 'Baliza RF activada: reporte automático iniciado',
    },
    'reportEnabledToast': {
        'zh': '已开启自动上报', 'zh_TW': '已開啟自動上報',
        'en': 'Auto-report turned on', 'ja': '自動送信を開始しました',
        'id': 'Lapor otomatis diaktifkan', 'es': 'Reporte automático activado',
    },
    'reportDisabledToast': {
        'zh': '已停止自动上报，改为仅单次上报',
        'zh_TW': '已停止自動上報，改為僅單次上報',
        'en': 'Auto-report off — single report only',
        'ja': '自動送信を停止しました（単発のみ）',
        'id': 'Lapor otomatis dimatikan — hanya sekali',
        'es': 'Reporte automático desactivado: solo única',
    },
    'autoReportEntryHint': {
        'zh': '开关随时可在主界面改：地图左下/底部的「自动 / 单次」按钮点一下即切换，旁边「立即上报」立即发一次。',
        'zh_TW': '開關隨時可在主介面改：地圖左下/底部的「自動 / 單次」按鈕點一下即切換，旁邊「立即上報」立即發一次。',
        'en': 'You can change this anytime from the main screen: tap the “AUTO / ONCE” button on the map (bottom-left / bottom bar) to switch, and “Report now” beside it to send immediately.',
        'ja': 'このスイッチはメイン画面でいつでも変更できます：地図左下/下部の「自動 / 単発」ボタンをタップで切替、隣の「今すぐ送信」で即時送信します。',
        'id': 'Sakelar ini bisa diubah kapan saja di layar utama: ketuk tombol "AUTO / SEKALI" di peta (kiri-bawah / bilah bawah) untuk beralih, dan "Lapor sekarang" di sampingnya untuk kirim segera.',
        'es': 'Puedes cambiarlo en cualquier momento desde la pantalla principal: toca el botón «AUTO / ÚNICA» del mapa (abajo-izquierda / barra inferior) para alternar, y «Reportar ahora» para enviar ya.',
    },
}

LANGS = ['zh', 'zh_TW', 'en', 'ja', 'id', 'es']
IDX = {lg: i for i, lg in enumerate(LANGS)}

# 已有键的**文案统一**：设置页原来叫「启用位置信标」，与状态栏新按钮的
# 「自动上报」是同一个开关却两个名字 —— 用户说的「乱」一半来自这里。
# 只改文案、不改键名（键名在代码里被引用，改名风险大且没必要）。
OVERRIDES = {
    'beaconEnabled': {
        'zh': '自动上报', 'zh_TW': '自動上報', 'en': 'Auto-report',
        'ja': '自動送信', 'id': 'Lapor otomatis', 'es': 'Reporte automático',
    },
    'settingsBeaconSubtitle': {
        'zh': '上报开关、间隔与内容', 'zh_TW': '上報開關、間隔與內容',
        'en': 'Report switch, interval & content',
        'ja': '送信スイッチ・間隔・内容',
        'id': 'Sakelar, interval & isi laporan',
        'es': 'Interruptor, intervalo y contenido',
    },
    'beaconingSection': {
        'zh': '自动上报', 'zh_TW': '自動上報', 'en': 'Auto-report',
        'ja': '自動送信', 'id': 'Lapor otomatis', 'es': 'Reporte automático',
    },
}

TARGETS = [
    ('zh', 'app_localizations_zh.dart', 'AppLocalizationsZh'),
    ('zh_TW', 'app_localizations_zh.dart', 'AppLocalizationsZhTw'),
    ('en', 'app_localizations_en.dart', 'AppLocalizationsEn'),
    ('ja', 'app_localizations_ja.dart', 'AppLocalizationsJa'),
    ('es', 'app_localizations_es.dart', 'AppLocalizationsEs'),
    ('id', 'app_localizations_id.dart', 'AppLocalizationsId'),
]
ANCHOR_GETTER = 'beaconBarDetailedOption'


def dart_literal(s, holders=()):
    out = s
    for h in holders:
        out = out.replace('{' + h + '}', '${' + h + '}')
    return "'" + out.replace("'", r"\'") + "'"


def main() -> int:
    # ⓪ 已有键的文案统一（只改值，不动键名）
    for lg in LANGS:
        p = os.path.join(L10N, f'app_{lg}.arb')
        src = io.open(p, encoding='utf-8').read()
        for key, vals in OVERRIDES.items():
            pat = r'("' + re.escape(key) + r'"\s*:\s*)"(?:[^"\\]|\\.)*"'
            new = src
            def _sub(m, _v=vals[lg]):
                return m.group(1) + json.dumps(_v, ensure_ascii=False)
            new = re.sub(pat, _sub, src, count=1)
            if new != src:
                src = new
        io.open(p, 'w', encoding='utf-8').write(src)
    # 同步生成产物里的对应 getter（zh 与 zh_TW 在同一个文件里，必须按类体定位，
    # 否则第二遍会把第一遍写好的简体值覆盖成繁体）。
    for lg, fname, cls in TARGETS:
        p = os.path.join(L10N, fname)
        src = io.open(p, encoding='utf-8').read()
        i = src.find(f'class {cls}')
        assert i > 0, f'{fname}: 找不到 {cls}'
        end = src.find('\n}', i)
        body = src[i:end]
        for key, vals in OVERRIDES.items():
            pat = (r"(?m)^  String (?:get )?" + re.escape(key) +
                   r" => '(?:[^'\\]|\\.)*';")
            body = re.sub(pat, lambda m, _v=vals[lg]: m.group(0).split(' => ')[0]
                          + ' => ' + dart_literal(_v) + ';', body)
        src = src[:i] + body + src[end:]
        io.open(p, 'w', encoding='utf-8', newline='').write(src)
    print('  文案统一：beaconEnabled / settingsBeaconSubtitle')

    # ① arb：追加到文件末尾（保持 JSON 合法）
    total = 0
    for lg in LANGS:
        p = os.path.join(L10N, f'app_{lg}.arb')
        src = io.open(p, encoding='utf-8').read()
        add = []
        for key, vals in KEYS.items():
            if re.search(r'^\s*"' + re.escape(key) + r'":', src, re.M):
                continue
            add.append(f'  {json.dumps(key, ensure_ascii=False)}: '
                       f'{json.dumps(vals[lg], ensure_ascii=False)},')
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

    # ② 抽象类
    p = os.path.join(L10N, 'app_localizations.dart')
    src = io.open(p, encoding='utf-8').read()
    missing = [k for k in KEYS if not re.search(
        r'String (?:get )?' + re.escape(k) + r'\s*[;(<={]', src)]
    if missing:
        blocks = []
        for k in missing:
            blocks.append(
                f'  /// No description provided for @{k}.\n'
                f'  ///\n'
                f'  /// In zh, this message translates to:\n'
                f'  /// **{json.dumps(KEYS[k]["zh"], ensure_ascii=False)}**\n'
                f'  String get {k};')
        anchor = '  /// No description provided for @tierIdleTitle.'
        assert anchor in src, '抽象类锚点缺失'
        src = src.replace(anchor, '\n\n'.join(blocks) + '\n\n' + anchor, 1)
        io.open(p, 'w', encoding='utf-8').write(src)
        print(f'  抽象类: 追加 {len(missing)} 条声明')

    # ③ 各语言类：插在 ANCHOR_GETTER 之后
    for lg, fname, cls in TARGETS:
        p = os.path.join(L10N, fname)
        src = io.open(p, encoding='utf-8').read()
        i = src.find(f'class {cls}')
        assert i > 0, f'{fname}: 找不到 {cls}'
        body = src[i:src.find('\n}', i)]
        need = [k for k in KEYS if not re.search(
            r'String (?:get )?' + re.escape(k) + r'\s*[;(<={]', body)]
        if not need:
            continue
        m = re.compile(
            r"(?m)^  String (?:get )?" + ANCHOR_GETTER + r" => '[^']*';\n").search(src, i)
        assert m, f'{cls}: 找不到 {ANCHOR_GETTER} 锚点'
        blocks = []
        for k in need:
            blocks.append(f'  @override\n  String get {k} => {dart_literal(KEYS[k][lg])};')
        src = src[:m.end()] + '\n' + '\n\n'.join(blocks) + '\n' + src[m.end():]
        io.open(p, 'w', encoding='utf-8', newline='').write(src)
        print(f'  产物 {fname}/{cls}: 追加 {len(need)} 条')

    print(f'\narb 共写入 {total} 行')
    return 0


if __name__ == '__main__':
    sys.exit(main())
