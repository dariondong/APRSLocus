#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""往 6 个语言加 l10n 键（arb 真源 + 抽象类 + gen-l10n 产物），**幂等**。

## 为什么固化成工具

我（AI）在 1.6.165/166 这两轮里手写了 4 次「往 arb 追加键」的临时脚本，
每次都错在**同一个地方**：追加多个键时只在最后一个处理了逗号 ——

  * 追加 2~3 个键 → 第 1 个键行尾少逗号 → 整个 arb **JSON 语法坏掉**
    （`Expecting ',' delimiter`），而 `check_l10n_sync` 会以「解析失败」报出来。

手写这种「字符串拼 JSON」的活**必然**漂。所以做成工具：以后加键只改下面的 KEYS。

## 用法

    python3 tool/add_l10n_keys.py

改 KEYS 里的内容再跑即可；已存在的键会跳过（幂等），所以可以反复跑。
带占位符的键在 META 里声明（gen-l10n 需要 `@key.placeholders`）。
"""
import io
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LANGS = ['zh', 'zh_TW', 'en', 'ja', 'es', 'id']
IDX = {l: i for i, l in enumerate(LANGS)}
CLASSES = {
    'zh': 'AppLocalizationsZh', 'zh_TW': 'AppLocalizationsZhTw',
    'en': 'AppLocalizationsEn', 'ja': 'AppLocalizationsJa',
    'es': 'AppLocalizationsEs', 'id': 'AppLocalizationsId',
}

# ── 要加的键：key → (zh, zh_TW, en, ja, es, id) ──
KEYS = {
    # 佳明页的**状态显示**与**确定按钮**（用户反馈：「它也不会自动填充」「我也不知道
    # 他生效了没有，都没有一个确定按钮和状态显示」）。
    'garminNotStarted': ('未开启追踪', '未開啟追蹤', 'Not tracking', '追跡していません',
                         'Sin seguimiento', 'Tidak melacak'),
    'garminAutoFilled': ('已自动填入分享链接', '已自動填入分享連結',
                         'Share link filled in automatically', '共有リンクを自動入力しました',
                         'Enlace rellenado automáticamente', 'Tautan terisi otomatis'),
    'garminLinkOk': ('链接有效', '連結有效', 'Link is valid', 'リンクは有効',
                     'Enlace válido', 'Tautan valid'),

    # 位置来源的**优先级**（用户问「听谁的？」）——两处设置都显示这一句，
    # 避免「定位上报页一个来源、设备页另一个来源」看着像打架。
    'posSourcePrecedence': (
        '同时可用时的优先级：模拟/手动位置 › 佳明（手表有实时数据时）› 手机 GPS',
        '同時可用時的優先順序：模擬/手動位置 › 佳明（手錶有即時資料時）› 手機 GPS',
        'Priority when several are available: simulated/manual › Garmin (while the watch has live '
        'data) › phone GPS',
        '同時に使える場合の優先順位：シミュレート/手動 › Garmin（ウォッチに实时データがある間）'
        '› スマホ GPS',
        'Prioridad cuando hay varias fuentes: simulada/manual › Garmin (mientras el reloj tenga '
        'datos en vivo) › GPS del teléfono',
        'Prioritas bila beberapa tersedia: simulasi/manual › Garmin (selama jam punya data '
        'langsung) › GPS ponsel',
    ),
    'posSourceUsing': (
        '当前使用：{src}', '目前使用：{src}', 'In use now: {src}',
        '現在使用中：{src}', 'En uso ahora: {src}', 'Sedang dipakai: {src}',
    ),
    'posSrcSim': ('模拟/手动位置', '模擬/手動位置', 'simulated/manual', 'シミュレート/手動',
                  'simulada/manual', 'simulasi/manual'),
    'posSrcGarmin': ('佳明 LiveTrack', '佳明 LiveTrack', 'Garmin LiveTrack',
                     'Garmin LiveTrack', 'Garmin LiveTrack', 'Garmin LiveTrack'),
    'posSrcPhone': ('手机 GPS', '手機 GPS', 'phone GPS', 'スマホ GPS',
                    'GPS del teléfono', 'GPS ponsel'),
    'posSrcNone': ('未定位', '未定位', 'no fix', '未測位', 'sin posición', 'belum ada posisi'),

    # 「数据来源」卡收敛到「设置 → 设备」后，连接页与音频页顶部的指路文案。
    # 为什么要有：这两页原来各挂一张「数据来源」卡（三处重复 = 用户说的「乱套」），
    # 删掉之后必须**告诉用户去哪儿**启用/切换链路，否则会以为功能消失了。
    'sourceMovedHint': (
        '要启用 / 切换数据来源（链路），请到「设置 → 设备」',
        '要啟用 / 切換資料來源（鏈路），請到「設定 → 裝置」',
        'To enable or switch data sources (links), go to Settings → Devices',
        'データソース（リンク）の有効化・切り替えは「設定 → デバイス」で行います',
        'Para activar o cambiar fuentes de datos (enlaces), ve a Ajustes → Dispositivos',
        'Untuk mengaktifkan/mengganti sumber data (tautan), buka Setelan → Perangkat',
    ),

    # 心率来源是**佳明 LiveTrack**（手表）时的说明。
    # 用户要求：「如果链接了佳明就提示从佳明追踪获取」。心率有两个来源
    # （BLE 胸带 / 佳明点里的 heartRateBeatsPerMin），不写清楚用户不知道
    # 这个数字是从哪来的 —— 尤其没插胸带时他会以为设置坏了。
    'hrFromGarmin': (
        '心率来自佳明 LiveTrack（手表）', '心率來自佳明 LiveTrack（手錶）',
        'Heart rate from Garmin LiveTrack (watch)',
        '心拍は Garmin LiveTrack（ウォッチ）から',
        'Pulso desde Garmin LiveTrack (reloj)',
        'Detak jantung dari Garmin LiveTrack (jam)',
    ),

    # 分享进来的内容里**没有**佳明链接时的提示。
    # 为什么必须给：以前解析失败是**静默 return** —— 用户分享后什么都没发生、
    # 也没有任何解释，只能来问「为什么没识别」。失败必须可见。
    'garminShareNoLink': (
        '分享的内容里没有找到佳明 LiveTrack 链接',
        '分享的內容裡沒有找到佳明 LiveTrack 連結',
        'No Garmin LiveTrack link found in what was shared',
        '共有された内容に Garmin LiveTrack のリンクが見つかりません',
        'No se encontró ningún enlace de Garmin LiveTrack',
        'Tidak ada tautan Garmin LiveTrack di konten yang dibagikan',
    ),

    # 位置来源：**如实的状态行**（不是二选一的开关）。
    # 佳明与手机 GPS 本来就不是二选一：手表在直播时优先用手表，超过 120s 没新点
    # 自动交回手机 —— 所以这里只显示「现在是谁在供位置」，不假装是用户选的。
    'posSourceIdle': (
        '未追踪（未启动定位）', '未追蹤（未啟動定位）', 'Not tracking (location off)',
        '未追跡（位置情報オフ）', 'Sin seguimiento (ubicación desactivada)',
        'Tidak melacak (lokasi nonaktif)',
    ),
    'ownSourceGarminLive': (
        '追踪中（手机 GPS 已让位）', '追蹤中（手機 GPS 已讓位）',
        'Tracking (phone GPS stepped aside)', '追跡中（スマホ GPS は待機）',
        'Siguiendo (el GPS del teléfono cedió)', 'Melacak (GPS ponsel menyingkir)',
    ),
    'ownSourceGarminStale': (
        '链接有效，但佳明没有新点（暂时用不到）', '連結有效，但佳明沒有新點（暫時用不到）',
        'Link set, but Garmin has no fresh points', 'リンクは有効だが新しい点がありません',
        'Enlace configurado, pero Garmin no tiene puntos nuevos',
        'Tautan ada, tapi Garmin belum punya titik baru',
    ),
    'ownSourceHrIdle': (
        '未连接（点一下连接心率带）', '未連線（點一下連線心率帶）',
        'Not connected (tap to connect a strap)', '未接続（タップして接続）',
        'Sin conectar (toca para conectar)', 'Belum tersambung (ketuk untuk menyambung)',
    ),
    'hrLineHr': ('心率 {hr}', '心率 {hr}', 'HR {hr}', '心拍 {hr}',
                 'pulso {hr}', 'HR {hr}'),
    # 手动上报后的提示：把**实际附带的内容**列出来，用户才不用猜
    # （用户问「手动上报…没有附带心率？」—— 之前提示只说网格，看不出带了什么）
    'positionBeaconDetail': (
        '位置信标 · 网格 {grid} · {detail}',
        '位置信標 · 網格 {grid} · {detail}',
        'Position beacon · Grid {grid} · {detail}',
        '位置ビーコン · グリッド {grid} · {detail}',
        'Baliza de posición · Cuadrícula {grid} · {detail}',
        'Beacon posisi · Grid {grid} · {detail}',
    ),
    'beaconAttachedHr': ('心率 {hr}', '心率 {hr}', 'HR {hr}',
                         '心拍 {hr}', 'pulso {hr}', 'HR {hr}'),
    'beaconAttachedNone': ('未附带心率', '未附帶心率', 'no heart rate',
                           '心拍なし', 'sin pulso', 'tanpa detak jantung'),
    # 「位置来源 / 心率来源」——数据来源卡里的两个小标题（用户要求：
    # 佳明应当作为「数据来源」的一种选择）
    'posSourceLabel': (
        '位置来源', '位置來源', 'Position source', '位置ソース',
        'Fuente de posición', 'Sumber posisi',
    ),
    'hrSourceLabel': (
        '心率来源', '心率來源', 'Heart-rate source', '心拍ソース',
        'Fuente de pulso', 'Sumber detak jantung',
    ),
    'ownSourcePhoneGps': (
        '手机 GPS', '手機 GPS', 'Phone GPS', 'スマホ GPS',
        'GPS del teléfono', 'GPS ponsel',
    ),
    'beaconGarminSource': (
        '佳明 LiveTrack 上报中', '佳明 LiveTrack 上報中',
        'Beaconing from Garmin LiveTrack', 'Garmin LiveTrack から送信',
        'Balizando desde Garmin LiveTrack', 'Memancarkan dari Garmin LiveTrack',
    ),
    # 横杠上的佳明档：来源 + 倒计时 + 心率一起给（用户要「主屏能看到心率」）
    'beaconGarminNext': (
        '佳明上报 · {s} · ❤{hr}', '佳明上報 · {s} · ❤{hr}',
        'Garmin · {s} · ❤{hr}', 'Garmin · {s} · ❤{hr}',
        'Garmin · {s} · ❤{hr}', 'Garmin · {s} · ❤{hr}',
    ),
}

# ── 占位符声明（可空）──
META = {
    'posSourceUsing': '{"placeholders": {"src": {"type": "String"}}}',
    'hrLineHr': '{"placeholders": {"hr": {"type": "String"}}}',
    'positionBeaconDetail': '{"placeholders": {"grid": {"type": "String"}, '
                            '"detail": {"type": "String"}}}',
    'beaconAttachedHr': '{"placeholders": {"hr": {"type": "String"}}}',
    'beaconGarminNext': '{"placeholders": {"s": {"type": "String"}, '
                        '"hr": {"type": "String"}}}',
}


def class_body(src, name):
    m = re.search(r'(?m)^(?:abstract )?class ' + re.escape(name) + r'\b', src)
    if not m:
        raise SystemExit('找不到类 ' + name)
    j = src.find('\n}\n', m.end())
    if j < 0:
        j = src.rfind('\n}')
    return m.end(), j


def add_lines(text, lines):
    """把若干 `  "key": value` 行插到顶层 } 之前。

    ⚠ 逗号规则是这里唯一的坑：插入的每一行**之间**都要有逗号，
    而**最后一行后面不能有**（紧接着就是 }）。
    """
    if not lines:
        return text
    i = text.rstrip().rfind('}')
    head = text[:i].rstrip()
    if head.endswith(','):
        head = head[:-1]          # 去掉原末尾逗号，最后统一按需补
    body = ',\n'.join(l.rstrip().rstrip(',') for l in lines)
    return head + ',\n' + body + '\n' + text[i:]


def main() -> int:
    if not KEYS:
        print('KEYS 是空的 —— 请先在脚本里填要加的键')
        return 0
    for lg in LANGS:
        p = os.path.join(ROOT, 'lib', 'l10n', 'app_%s.arb' % lg)
        t = io.open(p, encoding='utf-8', newline='').read()
        add = []
        for k, v in KEYS.items():
            if '"%s":' % k in t:
                continue
            add.append('  %s: %s' % (json.dumps(k, ensure_ascii=False),
                                     json.dumps(v[IDX[lg]], ensure_ascii=False)))
        for k, m in META.items():
            if '"@%s":' % k in t:
                continue
            add.append('  %s: %s' % (json.dumps('@' + k, ensure_ascii=False), m))
        if add:
            t = add_lines(t, add)
            io.open(p, 'w', encoding='utf-8', newline='').write(t)
        # 立刻验 JSON：拼错了就在这里炸，不要留到 check 脚本里才发现
        try:
            json.load(io.open(p, encoding='utf-8'))
        except Exception as e:
            print('%s arb 拼坏了: %s' % (lg, e))
            return 1
        print('%s arb ok（新增 %d 行）' % (lg, len(add)))

    # 抽象类
    p = os.path.join(ROOT, 'lib', 'l10n', 'app_localizations.dart')
    s = io.open(p, encoding='utf-8').read()
    code = []
    for k, v in KEYS.items():
        if re.search(r'String get %s\b' % k, s):
            continue
        code.append("  /// No description provided for @%s.\n  ///\n"
                    "  /// In zh, this message translates to:\n  /// **'%s'**\n"
                    "  String get %s;\n" % (k, v[0], k))
    if code:
        _, j = class_body(s, 'AppLocalizations')
        s = s[:j] + '\n' + '\n'.join(code) + s[j:]
        io.open(p, 'w', encoding='utf-8').write(s)
    print('抽象类 +%d' % len(code))

    # 各语言实现
    for lg in LANGS:
        fn = ('app_localizations_zh.dart' if lg in ('zh', 'zh_TW')
              else 'app_localizations_%s.dart' % lg)
        p = os.path.join(ROOT, 'lib', 'l10n', fn)
        s = io.open(p, encoding='utf-8').read()
        b0, b1 = class_body(s, CLASSES[lg])
        code = []
        for k, v in KEYS.items():
            if re.search(r'String get %s\b' % k, s[b0:b1]):
                continue
            code.append('  @override\n  String get %s => %s;\n'
                        % (k, json.dumps(v[IDX[lg]], ensure_ascii=False)))
        if code:
            s = s[:b1] + '\n' + '\n'.join(code) + s[b1:]
            io.open(p, 'w', encoding='utf-8').write(s)
        print('%s +%d' % (CLASSES[lg], len(code)))
    return 0


if __name__ == '__main__':
    sys.exit(main())
