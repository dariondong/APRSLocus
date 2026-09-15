#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""注入「两条链路绑定同一台设备」的提示文案（6 语言）。

背景：TNC 与 PKWDWPL 都走 SPP / 串口。两条链路连同一台设备时接收字节流会被
瓜分（串口两个句柄各读一部分 / 蓝牙第二条 RFCOMM 顶掉第一条），症状是
「发送正常、收不到报文」——从界面上完全看不出原因。所以在设备页就要拦住。

幂等可重复执行。
"""
import io
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

DATA = {
    'deviceConflictTitle': {
        'zh': '两条链路绑定了同一台设备',
        'zh_TW': '兩條鏈路綁定了同一臺裝置',
        'en': 'Two links are bound to the same device',
        'ja': '2 つのリンクが同じデバイスに割り当てられています',
        'id': 'Dua tautan terikat ke perangkat yang sama',
        'es': 'Dos enlaces están vinculados al mismo dispositivo',
    },
    'deviceConflictDesc': {
        'zh': 'TNC 与 PKWDWPL 指向同一台设备时，接收到的数据会被两条链路瓜分 —— '
              '表现是「能发不能收」（发送正常、收不到报文）。请给其中一条换一台设备。'
              'TNC 优先：PKWDWPL 会拒绝连接。',
        'zh_TW': 'TNC 與 PKWDWPL 指向同一臺裝置時，接收到的資料會被兩條鏈路瓜分 —— '
                 '表現是「能發不能收」（發送正常、收不到報文）。請給其中一條換一臺裝置。'
                 'TNC 優先：PKWDWPL 會拒絕連線。',
        'en': 'When TNC and PKWDWPL point at the same device, the received data is split '
              'between them — the symptom is "transmits fine but receives nothing". Give '
              'one of them a different device. TNC takes priority: PKWDWPL will refuse '
              'to connect.',
        'ja': 'TNC と PKWDWPL が同じデバイスを指すと、受信データが 2 つのリンクで'
              '分け合われます（送信はできるのに受信できない状態）。どちらかを別の'
              'デバイスに変更してください。TNC が優先され、PKWDWPL は接続を拒否します。',
        'id': 'Bila TNC dan PKWDWPL menunjuk perangkat yang sama, data terima dibagi '
              'antara keduanya — gejalanya "bisa kirim tetapi tidak bisa terima". '
              'Gantilah salah satunya ke perangkat lain. TNC diprioritaskan: PKWDWPL '
              'akan menolak terhubung.',
        'es': 'Cuando TNC y PKWDWPL apuntan al mismo dispositivo, los datos recibidos se '
              'reparten entre ambos — el síntoma es «transmite bien pero no recibe». '
              'Asigne otro dispositivo a uno de ellos. TNC tiene prioridad: PKWDWPL se '
              'negará a conectar.',
    },
    'deviceInUseByTnc': {
        'zh': '已被 TNC 使用，不能重复绑定',
        'zh_TW': '已被 TNC 使用，不能重複綁定',
        'en': 'In use by TNC — cannot bind again',
        'ja': 'TNC が使用中 — 重複して割り当てられません',
        'id': 'Sedang dipakai TNC — tidak bisa diikat lagi',
        'es': 'En uso por TNC — no se puede vincular de nuevo',
    },
    'deviceInUseByPkwdwpl': {
        'zh': '已被 PKWDWPL 使用，不能重复绑定',
        'zh_TW': '已被 PKWDWPL 使用，不能重複綁定',
        'en': 'In use by PKWDWPL — cannot bind again',
        'ja': 'PKWDWPL が使用中 — 重複して割り当てられません',
        'id': 'Sedang dipakai PKWDWPL — tidak bisa diikat lagi',
        'es': 'En uso por PKWDWPL — no se puede vincular de nuevo',
    },
    # 横幅：有链路在收、但它不是发射来源。
    # 不说清楚的话横幅会显示「未连接 APRS-IS 服务器」—— 而用户明明刚
    # 在设备页连上了 TNC / PKWDWPL，界面与事实相反。
    'rxOnlyBanner': {
        'zh': '{arg} 已连接 · 仅接收（当前发射来源未连接）',
        'zh_TW': '{arg} 已連線 · 僅接收（目前發射來源未連線）',
        'en': '{arg} connected · receive-only (the transmit source is offline)',
        'ja': '{arg} 接続済み · 受信のみ（送信元が未接続）',
        'id': '{arg} terhubung · hanya terima (sumber kirim belum aktif)',
        'es': '{arg} conectado · solo recepción (la fuente de transmisión está desconectada)',
    },
}

# 带占位符的键（gen-l10n 要求声明类型）
PLACEHOLDERS = {
    'rxOnlyBanner': {'arg': 'String'},
}

LANGS = ['zh', 'zh_TW', 'en', 'ja', 'id', 'es']
ANCHOR = '"pkwdwplReadOnly"'


def main():
    for lang in LANGS:
        path = os.path.join(ROOT, 'lib/l10n/app_%s.arb' % lang)
        lines = io.open(path, encoding='utf-8').read().split('\n')
        keep = [ln for ln in lines
                if not any(ln.strip().startswith('"%s"' % k) for k in DATA)
                and not any(ln.strip().startswith('"@%s"' % k)
                            for k in PLACEHOLDERS)]
        idx = next(i for i, ln in enumerate(keep)
                   if ln.strip().startswith(ANCHOR))
        block = ['  "%s": %s,' % (k, json.dumps(tr[lang], ensure_ascii=False))
                 for k, tr in DATA.items()]
        block += [
            '  "@%s": %s,' % (
                k,
                json.dumps({'placeholders': {p: {'type': t} for p, t in ph.items()}},
                           ensure_ascii=False))
            for k, ph in PLACEHOLDERS.items()
        ]
        keep[idx + 1:idx + 1] = block
        io.open(path, 'w', encoding='utf-8', newline='').write('\n'.join(keep))
        d = json.loads(io.open(path, encoding='utf-8').read())
        print('%s ok, %d keys' % (os.path.basename(path),
                                  len([k for k in d if not k.startswith('@')])))


if __name__ == '__main__':
    main()
