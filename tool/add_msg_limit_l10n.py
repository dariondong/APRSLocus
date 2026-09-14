#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""注入「APRS-IS 聊天文本过长可能无法解析」相关文案（6 语言）。

背景：射频侧一直有 67 字符上限提示；APRS-IS 侧完全没有长度预检，
于是长文本看起来发出去了、对方却解析不出来（或被服务器整包丢弃）。
这里补齐：规范上限提示、APRS-IS 行上限拦截、以及「仍要发送」的确认。
"""
import io
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

DATA = {
    'msgLenCounter': {
        'zh': '{chars}/67 字符 · 整包 {bytes}/512 字节',
        'zh_TW': '{chars}/67 字元 · 整包 {bytes}/512 位元組',
        'en': '{chars}/67 chars · {bytes}/512 bytes total',
        'ja': '{chars}/67 文字 · パケット {bytes}/512 バイト',
        'id': '{chars}/67 karakter · total {bytes}/512 byte',
        'es': '{chars}/67 caracteres · {bytes}/512 bytes en total',
    },
    'msgOverSpecAsk': {
        'zh': '这条消息 {chars} 个字符，超过 APRS 规范的 67 字符上限。多数客户端仍能读出，但部分客户端/网关会截断或拒收，对方可能解析不出来。仍要发送吗？',
        'zh_TW': '這則訊息 {chars} 個字元，超過 APRS 規範的 67 字元上限。多數用戶端仍能讀出，但部分用戶端/閘道會截斷或拒收，對方可能解析不出來。仍要傳送嗎？',
        'en': 'This message is {chars} characters, over the APRS spec limit of 67. Most clients will still show it, but some clients/gateways truncate or reject it, so the other station may not be able to parse it. Send anyway?',
        'ja': 'このメッセージは {chars} 文字で、APRS 規格の上限 67 文字を超えています。多くのクライアントは表示できますが、一部のクライアント／ゲートウェイは切り捨てまたは拒否するため、相手が解釈できない可能性があります。送信しますか？',
        'id': 'Pesan ini {chars} karakter, melebihi batas spesifikasi APRS yaitu 67. Sebagian besar klien masih bisa menampilkannya, tetapi sebagian klien/gateway memotong atau menolaknya, sehingga stasiun lawan mungkin tidak dapat mengurainya. Tetap kirim?',
        'es': 'Este mensaje tiene {chars} caracteres y supera el límite de 67 de la especificación APRS. La mayoría de los clientes aún lo mostrará, pero algunos clientes/pasarelas lo truncan o rechazan, así que la otra estación podría no poder interpretarlo. ¿Enviar igualmente?',
    },
    'msgOverServerLimit': {
        'zh': '整包 {bytes} 字节，超过 APRS-IS 单行上限 512 字节，服务器可能直接丢弃整包（连报头都送不到）。请缩短约 {over} 字节。',
        'zh_TW': '整包 {bytes} 位元組，超過 APRS-IS 單行上限 512 位元組，伺服器可能直接丟棄整包（連標頭都送不到）。請縮短約 {over} 位元組。',
        'en': 'The packet is {bytes} bytes, over the 512-byte APRS-IS line limit. The server may drop it entirely (not even the header arrives). Please shorten by about {over} bytes.',
        'ja': 'パケットが {bytes} バイトで、APRS-IS の 1 行上限 512 バイトを超えています。サーバーがパケットごと破棄する可能性があります（ヘッダーも届きません）。約 {over} バイト短くしてください。',
        'id': 'Paket berukuran {bytes} byte, melebihi batas 512 byte per baris APRS-IS. Server mungkin membuang seluruh paket (bahkan header tidak sampai). Mohon perpendek sekitar {over} byte.',
        'es': 'El paquete tiene {bytes} bytes y supera el límite de 512 bytes por línea de APRS-IS. El servidor podría descartarlo por completo (ni siquiera llegaría la cabecera). Acorta unos {over} bytes.',
    },
    'msgSendAnyway': {
        'zh': '仍要发送', 'zh_TW': '仍要傳送', 'en': 'Send anyway',
        'ja': 'それでも送信', 'id': 'Tetap kirim', 'es': 'Enviar igualmente',
    },
    'msgSpecLimitHint': {
        'zh': 'APRS 规范建议单条消息不超过 67 字符：超长文本在部分客户端上会显示不全或解析失败。',
        'zh_TW': 'APRS 規範建議單則訊息不超過 67 字元：過長文字在部分用戶端上會顯示不全或解析失敗。',
        'en': 'The APRS spec recommends keeping a message under 67 characters: longer text may be truncated or fail to parse in some clients.',
        'ja': 'APRS 規格では 1 通のメッセージは 67 文字以内が推奨です。長すぎる文本は一部のクライアントで欠けたり解析に失敗します。',
        'id': 'Spesifikasi APRS menyarankan pesan di bawah 67 karakter: teks yang lebih panjang dapat terpotong atau gagal diurai di sebagian klien.',
        'es': 'La especificación APRS recomienda mensajes de menos de 67 caracteres: el texto más largo puede truncarse o no interpretarse en algunos clientes.',
    },
    'msgBlockedTooLong': {
        'zh': '已阻止发送：整包超出 APRS-IS 上限',
        'zh_TW': '已阻止傳送：整包超出 APRS-IS 上限',
        'en': 'Send blocked: packet exceeds the APRS-IS limit',
        'ja': '送信を中止：パケットが APRS-IS の上限を超えています',
        'id': 'Pengiriman diblokir: paket melebihi batas APRS-IS',
        'es': 'Envío bloqueado: el paquete supera el límite de APRS-IS',
    },
}

PLACEHOLDERS = {
    'msgLenCounter': {'chars': 'int', 'bytes': 'int'},
    'msgOverSpecAsk': {'chars': 'int'},
    'msgOverServerLimit': {'bytes': 'int', 'over': 'int'},
}

LANGS = ['zh', 'zh_TW', 'en', 'ja', 'id', 'es']
ANCHOR = '"codeContributionTranslation"'


def main():
    for lang in LANGS:
        path = os.path.join(ROOT, 'lib/l10n/app_%s.arb' % lang)
        lines = io.open(path, encoding='utf-8').read().split('\n')
        out = []
        for ln in lines:
            st = ln.strip()
            if any(st.startswith('"%s"' % k) for k in DATA):
                continue
            if any(st.startswith('"@%s"' % k) for k in PLACEHOLDERS):
                continue
            out.append(ln)
        lines = out
        idx = None
        for i, ln in enumerate(lines):
            if ln.strip().startswith(ANCHOR):
                idx = i
                break
        assert idx is not None, 'anchor not found in %s' % path
        block = ['  "%s": %s,' % (k, json.dumps(v[lang], ensure_ascii=False))
                 for k, v in DATA.items()]
        for k, ph in PLACEHOLDERS.items():
            block.append('  "@%s": %s,' % (
                k,
                json.dumps({'placeholders': {a: {'type': b} for a, b in ph.items()}},
                           ensure_ascii=False)))
        lines[idx + 1:idx + 1] = block
        io.open(path, 'w', encoding='utf-8').write('\n'.join(lines))
        d = json.loads(io.open(path, encoding='utf-8').read())
        n = len([k for k in d if not k.startswith('@')])
        print('%s ok, %d keys (+%d)' % (path, n, len(DATA)))


if __name__ == '__main__':
    main()
