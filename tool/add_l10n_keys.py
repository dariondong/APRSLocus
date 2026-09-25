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
    # ── 强制接受网络定位自动上报（v1.6.177 用户要求：「在信标上报页面留一个按钮，
    # 可开启强制接受网络定位自动上报」）──
    #
    # 背景：v1.6.163 起粗定位（网络/基站/被动）**不自动上报**（粗点常偏几百米，
    # 发出去的是错坐标）。但「手里这台设备没有 GPS」的用户（平板/只有网络定位的
    # 机器/长期室内）就变成「永远不会自动上报」，而界面上只写着「网络定位中」
    # —— 他们没有任何办法打开它。这组文案就是那个开关。
    'beaconForceCoarse': (
        '强制接受网络定位自动上报', '強制接受網路定位自動上報',
        'Beacon network (coarse) fixes anyway',
        'ネットワーク測位でも自動送信する',
        'Balizar también con posición de red (gruesa)',
        'Tetap pancarkan posisi jaringan (kasar)',
    ),
    # 取舍要写清：这个开关换来的是「能发」，代价是「发的是粗坐标」。
    'beaconForceCoarseHint': (
        '默认不开启：网络定位（基站 / Wi-Fi）常偏几百米，自动发出去等于向全网宣告一个错坐标。'
        '只有设备没有 GPS（平板 / 只有网络定位）时才建议打开 —— 打开后粗定位也会自动发射；'
        '地图与轨迹仍按原样过滤粗点，不会因此变乱。手动「立即上报」不受这个开关影响。',
        '預設不開啟：網路定位（基地台 / Wi-Fi）常偏幾百公尺，自動發出去等於向全網宣告一個錯座標。'
        '只有裝置沒有 GPS（平板 / 只有網路定位）時才建議打開 —— 打開後粗定位也會自動發射；'
        '地圖與軌跡仍照原樣過濾粗點，不會因此變亂。手動「立即上報」不受這個開關影響。',
        'Off by default: network fixes (cell / Wi-Fi) are often hundreds of metres off, so beaconing '
        'them announces a wrong coordinate to everyone. Turn this on only when the device has no GPS '
        '(tablet, network-only). Coarse points are still filtered the usual way for the map and '
        'track, so those do not get jumpy. Manual "beacon now" is unaffected.',
        '既定ではオフ：ネットワーク測位（基地局 / Wi-Fi）は数百メートルずれることが多く、'
        '自動送信すると誤った座標を全員に知らせることになります。GPS の無い端末（タブレットなど）'
        'でのみオンにしてください。地図と軌跡は従来どおり粗い点を除外するので乱れません。'
        '手動の「今すぐ送信」はこのスイッチの影響を受けません。',
        'Desactivado por defecto: la posición de red (celda / Wi-Fi) suele fallar cientos de metros, '
        'así que balizarla anuncia una coordenada errónea a todos. Actívalo solo si el dispositivo no '
        'tiene GPS (tableta, solo red). El mapa y la traza siguen filtrando los puntos gruesos como '
        'siempre, así que no se vuelven inestables. El "balizar ahora" manual no se ve afectado.',
        'Mati secara bawaan: posisi jaringan (sel / Wi-Fi) sering meleset ratusan meter, jadi '
        'memancarkannya berarti mengumumkan koordinat yang salah ke semua orang. Nyalakan hanya bila '
        'perangkat tidak punya GPS (tablet, hanya jaringan). Peta dan jejak tetap menyaring titik '
        'kasar seperti biasa, jadi tidak ikut kacau. "Pancarkan sekarang" manual tidak terpengaruh.',
    ),
    # 强制档下的横杠文案：会发射，所以给真实倒计时；要点明「发的是网络定位」。
    'beaconCoarseForced': (
        '网络定位（粗）· {s}', '網路定位（粗）· {s}',
        'Network fix (coarse) · {s}', 'ネットワーク測位（粗）· {s}',
        'Posición de red (gruesa) · {s}', 'Posisi jaringan (kasar) · {s}',
    ),
    # 不带倒计时的短句（沉浸页 / 我的位置面板 / 设置页提示条）。
    'beaconCoarseForcedNote': (
        '正在用网络定位（粗）上报', '正在用網路定位（粗）上報',
        'Beaconing a network (coarse) fix',
        'ネットワーク測位（粗）で送信中',
        'Balizando con posición de red (gruesa)',
        'Memancarkan posisi jaringan (kasar)',
    ),
}

# ── 占位符声明（可空）──
META = {
    'beaconCoarseForced': '{"placeholders": {"s": {"type": "String"}}}',
}


def _params(key):
    """从 META 里抠出这个键的占位符名字。"""
    raw = META.get(key)
    if not raw:
        return []
    try:
        return list(json.loads(raw).get('placeholders', {}).keys())
    except Exception:
        return []


def member(key):
    """产出的成员签名：无占位符 → `get key`；有 → `key(String a, String b)`。

    ⚠ 这是一处真实缺陷的修法（v1.6.177）：本函数以前一律写 getter，于是带占位符
    的键被写成 `String get x => "... {s}";` —— **本机** `S.of(context).x(y)` 报
    not_a_function，而 CI 的 `pub get` 会按 arb 重新生成产物，于是 CI 全绿、
    问题被盖住（正是本仓库最熟悉的「我这儿有错、CI 却是绿的」）。
    产物必须与 gen-l10n 同形：带占位符就是**带参数的方法**。
    """
    ps = _params(key)
    if not ps:
        return 'get %s' % key
    return '%s(%s)' % (key, ', '.join('String ' + x for x in ps))


def interp(key, text):
    """把 `{x}` 换成 Dart 插值 `$x`（与 gen-l10n 的产物一致）。"""
    for x in _params(key):
        text = text.replace('{%s}' % x, '$%s' % x)
    return text


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
        if re.search(r'String (?:get )?%s\b' % k, s):
            continue
        code.append("  /// No description provided for @%s.\n  ///\n"
                    "  /// In zh, this message translates to:\n  /// **'%s'**\n"
                    "  String %s;\n" % (k, v[0], member(k)))
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
            if re.search(r'String (?:get )?%s\b' % k, s[b0:b1]):
                continue
            code.append('  @override\n  String %s => %s;\n'
                        % (member(k),
                           json.dumps(interp(k, v[IDX[lg]]), ensure_ascii=False)))
        if code:
            s = s[:b1] + '\n' + '\n'.join(code) + s[b1:]
            io.open(p, 'w', encoding='utf-8').write(s)
        print('%s +%d' % (CLASSES[lg], len(code)))
    return 0


if __name__ == '__main__':
    sys.exit(main())
