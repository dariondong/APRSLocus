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
    # ── 翻译接口：B 站 Index-Translate ──
    #
    # OpenAI 规范的公共接口，免密钥。中文语料上比网页端点稳，但不保证可用性。
    'translateProviderBili': (
        'B站 Index-Translate', 'B 站 Index-Translate', 'Bilibili Index-Translate',
        'Bilibili Index-Translate', 'Bilibili Index-Translate',
        'Bilibili Index-Translate'),
    'translateProviderBiliDesc': (
        '免密钥，免费。B 站公开的翻译模型，公共接口不保证一直可用。',
        '免金鑰，免費。B 站公開的翻譯模型，公共介面不保證一直可用。',
        "No key, no cost. Bilibili's public translation model; a free endpoint with no guarantee.",
        'キー不要で無料。Bilibili が公開している翻訳モデル。公共の窓口なので可用性は保証されません。',
        'Sin clave y gratis. Modelo público de traducción de Bilibili; sin garantía de disponibilidad.',
        'Tanpa kunci, gratis. Model terjemahan publik Bilibili; ketersediaannya tidak dijamin.'),
    'translateBiliUrl': (
        '接口地址', '介面位址', 'Endpoint', 'エンドポイント', 'Endpoint', 'Endpoint'),
    'translateBiliModel': (
        '模型', '模型', 'Model', 'モデル', 'Modelo', 'Model'),
    # ── 两条互联网链路：每张卡上一个「用这条链路发送」 ──
    'acnPasscodeHint': (
        '留空就用 APRS-IS 那条链路的 passcode',
        '留空就用 APRS-IS 那條鏈路的 passcode',
        "Leave it empty to use the APRS-IS link's passcode",
        '空欄なら APRS-IS 側の passcode を使います',
        'Déjalo vacío para usar el passcode del enlace APRS-IS',
        'Kosongkan untuk memakai passcode tautan APRS-IS'),
    'txSourcePick': (
        '用这条链路发送', '用這條鏈路發送', 'Send on this link',
        'この回線で送信', 'Enviar por este enlace', 'Kirim lewat tautan ini'),
    'translateBiliTip': (
        '公共接口可能限流。自己部署时把地址和模型换成自己的。',
        '公共介面可能限流。自己部署時把位址和模型換成自己的。',
        'The public endpoint may rate-limit. Point the address and model at your own deployment if you run one.',
        '公共の窓口は制限がかかる場合があります。自前で立てる場合はアドレスとモデルを差し替えてください。',
        'El punto público puede limitar el uso. Si tienes tu propio despliegue, pon ahí la dirección y el modelo.',
        'Endpoint publik bisa membatasi permintaan. Kalau kamu punya deployment sendiri, isi alamat dan model itu.'),
    # ── 实时更新胶囊里可选的读数（多出来的那几档） ──
    #
    # 胶囊只有一行 ≤7 字符，所以标签只写「显示的是什么数」，单位写在下面对。
    'notifLiveTextMsgs': (
        '未读消息', '未讀訊息', 'Unread messages', '未読メッセージ',
        'Mensajes sin leer', 'Pesan belum dibaca'),
    'notifLiveTextNear': (
        '附近台站', '附近臺站', 'Nearby stations', '近くの局',
        'Estaciones cercanas', 'Stasiun sekitar'),
    'notifLiveTextSpeed': (
        '速度', '速度', 'Speed', '速度', 'Velocidad', 'Kecepatan'),
    'notifLiveTextAlt': (
        '高度', '高度', 'Altitude', '高度', 'Altitud', 'Ketinggian'),
    'notifLiveTextHr': (
        '心率', '心率', 'Heart rate', '心拍数', 'Frecuencia cardíaca', 'Detak jantung'),
    'notifLiveTextBatt': (
        '电量', '電量', 'Battery', 'バッテリー', 'Batería', 'Baterai'),
    'notifLiveTextTrip': (
        '本次里程', '本次里程', 'Trip distance', '今回の走行距離',
        'Distancia del viaje', 'Jarak perjalanan'),
    # 附近台站那个数是**带单位**的（台/局/est…），单位只能跟着语言走
    'notifLiveNearShort': (
        '{n} 台', '{n} 臺', '{n} stn', '{n} 局', '{n} est', '{n} stn'),
    # ── 历史轨迹：记录开关（默认关）──
    'historyRecord': (
        '记录历史轨迹', '記錄歷史軌跡', 'Track history', '履歴を記録',
        'Registrar historial', 'Rekam riwayat'),
    'historyEmptyOff': (
        '记录没开。打开上面的开关才会记。',
        '記錄沒開。打開上面的開關才會記。',
        'Recording is off. Turn it on above to start.',
        '記録は切っています。上のスイッチを入れると記録します。',
        'La grabación está desactivada. Actívala arriba para empezar.',
        'Perekaman mati. Nyalakan sakelar di atas untuk mulai.'),
    # 开发人员里那一行操作证书查询的标签：功能先关着，位置留着
    'cracCertClosed': (
        '暂不开放', '暫不開放', 'Not open yet', '未公開',
        'Aún no disponible', 'Belum dibuka'),
    # 电台页的入口 + 那一页的三条说明
    'cracCertEntry': (
        '操作证验证', '操作證驗證', 'Licence check', '操作資格の確認',
        'Verificación de licencia', 'Pemeriksaan lisensi'),
    'cracCertVoluntary': (
        '验证自愿，不验证也能照常用。',
        '驗證自願，不驗證也能照常用。',
        'Verification is voluntary. The app works the same without it.',
        '認証は任意です。しなくても同じように使えます。',
        'La verificación es voluntaria. La app funciona igual sin ella.',
        'Verifikasi bersifat sukarela. Aplikasi tetap berjalan sama tanpanya.'),
    'cracCertLocal': (
        '查询由程序直接完成，没有人工审核。结果只回本机，只保留是否通过和证书类别。',
        '查詢由程式直接完成，沒有任何人工作業。結果只回本機，只保留是否通過和證書類別。',
        'The check runs by program, with no human review. The result comes back to this device only, '
        'and keeps just the pass and the licence class.',
        '照合はプログラムが行い、人手の審査はありません。結果はこの端末にだけ戻り、通過と資格クラスだけを残します。',
        'La comprobación la hace el programa, sin revisión humana. El resultado vuelve solo a este '
        'dispositivo y guarda únicamente si pasó y la clase.',
        'Pemeriksaan dijalankan oleh program, tanpa tinjauan manusia. Hasilnya kembali hanya ke '
        'perangkat ini, berisi lulus dan kelas lisensi saja.'),
    # 认证页面里那句「为什么要有这一步」—— 用户给的原话
    'cracCertWhyRequired': (
        'APRS-IS 协议 软件开发者有责任与义务验证软件使用者为业余无线电爱好者',
        'APRS-IS 協議 軟體開發者有責任與義務驗證軟體使用者為業餘無線電愛好者',
        'The APRS-IS protocol puts the duty on the software developer to verify that users are amateur radio operators.',
        'APRS-IS プロトコルでは、利用者がアマチュア無線家であることを確認する責任と義務がソフトウェア開発者にあります。',
        'El protocolo APRS-IS pone en el desarrollador del software el deber de verificar que los usuarios sean radioaficionados.',
        'Protokol APRS-IS menetapkan kewajiban pengembang perangkat lunak untuk memastikan pengguna adalah penggemar radio amatir.'),
    # ── 首次引导：没填地址时最后一步不叫「完成并连接」 ──
    'oobeFinishLocal': (
        '完成', '完成', 'Finish', '完了', 'Terminar', 'Selesai'),
    # ── 首次引导：呼号形状校验 ──
    'oobeCallInvalid': (
        '呼号格式不对。常见的写法是 BG7LZQ 或 JA1AA。',
        '呼號格式不對。常見的寫法是 BG7LZQ 或 JA1AA。',
        'That callsign does not look right. Common forms are BG7LZQ or JA1AA.',
        'コールサインの形式が正しくありません。例：BG7LZQ、JA1AA。',
        'Ese indicativo no parece correcto. Formatos habituales: BG7LZQ o JA1AA.',
        'Tanda panggil itu sepertinya tidak tepat. Bentuk umum: BG7LZQ atau JA1AA.'),
    'oobeSsidInvalid': (
        '后缀只能是一位或两位数字、字母。',
        '後綴只能是一位或兩位數字、字母。',
        'The SSID can be one or two letters or digits.',
        'SSID は数字か英字の 1〜2 文字です。',
        'El SSID puede ser una o dos letras o cifras.',
        'SSID hanya boleh satu atau dua huruf atau angka.'),
}

META = {
    'notifLiveNearShort': '{"placeholders": {"n": {"type": "String"}}}',
    'acnServerRetention': '{"placeholders": {"hours": {"type": "String"}}}',
    'acnSyncDone': '{"placeholders": {"total": {"type": "String"}, "added": {"type": "String"}}}',
    'gpxExported': '{"placeholders": {"days": {"type": "String"}, "points": {"type": "String"}}}',
    'gpxSavedTo': '{"placeholders": {"path": {"type": "String"}}}',
    'audioTxNotSourceWarn': '{"placeholders": {"src": {"type": "String"}}}',
    'prunePreview': '{"placeholders": {"n": {"type": "String"}}}',
    'pruneConfirm': '{"placeholders": {"n": {"type": "String"}, "m": {"type": "String"}}}',
    'pruneDone': '{"placeholders": {"n": {"type": "String"}}}',
    'beaconCoarseForced': '{"placeholders": {"s": {"type": "String"}}}',
    'txNoFixKeptStatus': '{"placeholders": {"parts": {"type": "String"}}}',
    'connStatusSent': '{"placeholders": {"call": {"type": "String"}}}',
    'connTncStatusSent': '{"placeholders": {"arg": {"type": "String"}}}',
    'connAudioStatusSent': '{"placeholders": {"call": {"type": "String"}}}',
    'nDays': '{"placeholders": {"n": {"type": "String"}}}',
    'strategyTeammateOf': '{"placeholders": {"call": {"type": "String"}}}',
    'strategyUpdatedItem':
        '{"placeholders": {"call": {"type": "String"}, "kind": {"type": "String"}}}',
    'strategyDeletedItem':
        '{"placeholders": {"call": {"type": "String"}, "kind": {"type": "String"}}}',
    'strategyClearedMsg': '{"placeholders": {"call": {"type": "String"}}}',
    'strategySharedItem':
        '{"placeholders": {"call": {"type": "String"}, "kind": {"type": "String"}}}',
    'strategyAckPending': '{"placeholders": {"n": {"type": "int"}}}',
    'locationSendTo': '{"placeholders": {"call": {"type": "String"}}}',
    'locationPageInfo':
        '{"placeholders": {"n": {"type": "String"}, "m": {"type": "String"}}}',
    'shareStationSent': '{"placeholders": {"call": {"type": "String"}}}',
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
