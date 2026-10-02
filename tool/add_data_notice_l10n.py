#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""注入「数据与网络使用告知」的文案（连接服务器前必须签署那一页）。

文本级插入，幂等可重复执行 —— 同 tool/add_*_l10n.py 的既有约定。
⚠ ICU：译文里不要出现落单的半角单引号。
"""
import io
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

DATA = {
    'dataNoticeTitle': {
        'zh': '数据与网络使用告知',
        'zh_TW': '資料與網路使用告知',
        'en': 'Data & Network Notice',
        'ja': 'データとネットワークの告知',
        'id': 'Pemberitahuan Data & Jaringan',
        'es': 'Aviso de datos y red',
    },
    'dataNoticeBody': {
        'zh': '连接第三方 APRS 服务器是您自己的选择。本软件不提供、不运营、也不推荐任何'
              '服务器地址。\n\n连接后，您的呼号、位置、消息等内容会经该服务器与 APRS-IS '
              '网络传输，可能被他人接收、存储或公开存档；APRS 是明文的，请勿发送国家秘密、'
              '商业秘密、个人隐私或敏感位置信息。\n\n请自行确认所连接的服务器以及您的使用'
              '行为合法合规，并自行承担因数据出境、个人信息处理、无线电管理等产生的责任。'
              '我们不运营任何服务器，与任何第三方服务器之间也不存在隶属、代理或合作关系。\n\n'
              '点击「同意并连接」表示您已阅读、理解并接受上述内容（详见《用户协议》第 2.4、'
              '2.5、4.8 条）。',
        'zh_TW': '連接第三方 APRS 伺服器是您自己的選擇。本軟體不提供、不營運、也不推薦任何'
                 '伺服器位址。\n\n連接後，您的呼號、位置、訊息等內容會經該伺服器與 APRS-IS '
                 '網路傳輸，可能被他人接收、存儲或公開存檔；APRS 是明文的，請勿發送國家秘密、'
                 '商業秘密、個人隱私或敏感位置資訊。\n\n請自行確認所連接的伺服器以及您的使用'
                 '行為合法合規，並自行承擔因資料出境、個人資料處理、無線電管理等產生的責任。'
                 '我們不營運任何伺服器，與任何第三方伺服器之間也不存在隸屬、代理或合作關係。\n\n'
                 '點擊「同意並連線」表示您已閱讀、理解並接受上述內容（詳見《使用者條款》第 2.4、'
                 '2.5、4.8 條）。',
        'en': 'Connecting to a third-party APRS server is your own choice. This software does '
              'not provide, operate, or recommend any server address.\n\nOnce connected, your '
              'callsign, position, messages and other content travel through that server and the '
              'APRS-IS network, and may be received, stored, or publicly archived by others. '
              'APRS is plain text: never send state secrets, trade secrets, personal data, or '
              'sensitive location information.\n\nYou must confirm that the server you connect to '
              'and your use of it are lawful, and you bear the responsibility arising from '
              'cross-border data transfer, personal-data processing, and radio regulation. We '
              'operate no server and have no affiliation, agency, or cooperation with any '
              'third-party server.\n\nBy tapping "Agree and connect" you confirm that you have '
              'read, understood, and accepted the above (see clauses 2.4, 2.5 and 4.8 of the '
              'Terms of Use).',
        'ja': 'サードパーティの APRS サーバーに接続するかどうかは、ご自身の判断です。本ソフトは'
              'サーバーアドレスの提供・運営・推奨を一切行いません。\n\n接続すると、コールサイン・'
              '位置・メッセージなどが当該サーバーと APRS-IS 網を通じて送信され、第三者が受信・'
              '保存・公開アーカイブする可能性があります。APRS は平文です。国家機密・営業秘密・'
              '個人情報・機微な位置情報を送らないでください。\n\n接続するサーバーとご自身の利用が'
              '法令に適合していることをご自身で確認し、国外移転・個人情報の処理・無線管理などに'
              '伴う責任を負っていただきます。当方はいかなるサーバーも運営しておらず、第三者'
              'サーバーとの提携・代理関係もありません。\n\n「同意して接続」を押すと、上記を読み・'
              '理解し・受け入れたものとみなします（利用規約 2.4／2.5／4.8 参照）。',
        'id': 'Menyambung ke server APRS pihak ketiga adalah pilihan Anda sendiri. Perangkat '
              'lunak ini tidak menyediakan, mengoperasikan, maupun merekomendasikan alamat server '
              'apa pun.\n\nSetelah tersambung, callsign, posisi, pesan, dan konten lain Anda '
              'mengalir melalui server tersebut dan jaringan APRS-IS, dan dapat diterima, '
              'disimpan, atau diarsipkan secara publik oleh pihak lain. APRS bersifat terbuka: '
              'jangan kirim rahasia negara, rahasia dagang, data pribadi, atau informasi lokasi '
              'yang sensitif.\n\nAnda harus memastikan server yang Anda sambungi dan penggunaan '
              'Anda sah, dan Anda menanggung tanggung jawab atas transfer data lintas negara, '
              'pemrosesan data pribadi, dan regulasi radio. Kami tidak mengoperasikan server apa '
              'pun dan tidak memiliki afiliasi, agensi, atau kerja sama dengan server pihak '
              'ketiga mana pun.\n\nDengan menekan "Setuju dan sambung", Anda menyatakan telah '
              'membaca, memahami, dan menerima hal di atas (lihat Pasal 2.4, 2.5, dan 4.8 '
              'Ketentuan Penggunaan).',
        'es': 'Conectarte a un servidor APRS de terceros es tu propia decisión. Este software no '
              'proporciona, opera ni recomienda ninguna dirección de servidor.\n\nUna vez '
              'conectado, tu indicativo, posición, mensajes y otros contenidos viajan por ese '
              'servidor y la red APRS-IS, y pueden ser recibidos, almacenados o archivados '
              'públicamente por terceros. APRS es texto plano: no envíes secretos de Estado, '
              'secretos comerciales, datos personales ni información de ubicación sensible.\n\n'
              'Debes confirmar que el servidor al que te conectas y tu uso del mismo son lícitos, '
              'y asumes la responsabilidad derivada de la transferencia transfronteriza de datos, '
              'el tratamiento de datos personales y la normativa de radio. No operamos ningún '
              'servidor ni tenemos afiliación, agencia o cooperación con servidores de terceros.'
              '\n\nAl pulsar "Aceptar y conectar" confirmas que has leído, entendido y aceptado lo '
              'anterior (véanse las cláusulas 2.4, 2.5 y 4.8 de los Términos de uso).',
    },
    'dataNoticeAccept': {
        'zh': '同意并连接', 'zh_TW': '同意並連線', 'en': 'Agree and connect',
        'ja': '同意して接続', 'id': 'Setuju dan sambung', 'es': 'Aceptar y conectar',
    },
    'dataNoticeDecline': {
        'zh': '暂不连接', 'zh_TW': '暫不連線', 'en': 'Not now',
        'ja': '今はしない', 'id': 'Jangan dulu', 'es': 'Ahora no',
    },
}

LANGS = ['zh', 'zh_TW', 'en', 'ja', 'id', 'es']
ANCHOR = '"dataSourceSwitchHint"'


def main():
    for lang in LANGS:
        path = os.path.join(ROOT, 'lib/l10n/app_%s.arb' % lang)
        lines = io.open(path, encoding='utf-8').read().split('\n')
        keep = [ln for ln in lines
                if not any(ln.strip().startswith('"%s"' % k) for k in DATA)]
        idx = next(i for i, ln in enumerate(keep) if ln.strip().startswith(ANCHOR))
        block = ['  "%s": %s,' % (k, json.dumps(tr[lang], ensure_ascii=False))
                 for k, tr in DATA.items()]
        keep[idx + 1:idx + 1] = block
        io.open(path, 'w', encoding='utf-8').write('\n'.join(keep))
        d = json.loads(io.open(path, encoding='utf-8').read())
        print('%s ok, %d keys' % (os.path.basename(path),
                                  len([k for k in d if not k.startswith('@')])))


if __name__ == '__main__':
    main()
