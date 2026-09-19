#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""向 6 个 ARB 注入「网关（iGate）统计为什么是 0」的文案键。

背景：网关的统计原先只有三个数字（已转递→IS / →射频 / 重复丢弃）。
只要前置条件没齐（射频链路没连上、APRS-IS 掉线、报文全被环路防护拒收），
三个数字就恒为 0，而界面上与「正常工作」完全一样 —— 用户只能猜。
本脚本补齐「射频收到多少条」「环路拒收多少条」两个数字，
以及四条「缺什么」的说明文案。

幂等可重复执行。
"""
import io
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

DATA = {
    'igateStatRfSeen': {
        'zh': '射频收到（条）',
        'zh_TW': '射頻收到（條）',
        'en': 'Heard on RF',
        'ja': 'RF 受信（件）',
        'id': 'Diterima di RF',
        'es': 'Oídos por RF',
    },
    'igateStatBlocked': {
        'zh': '环路拒收（条）',
        'zh_TW': '迴路拒收（條）',
        'en': 'Loop-protection rejects',
        'ja': 'ループ防止で拒否',
        'id': 'Ditolak proteksi loop',
        'es': 'Rechazados por anti-bucle',
    },
    'igateRfDown': {
        'zh': '射频链路没连上：网关现在什么都转不了。上面的「射频收到」如果一直是 0，'
              '说明报文根本没进来 —— 先查设备页里的 TNC / 音频状态（串口线速、'
              '设备是否开机），而不是怀疑网关。',
        'zh_TW': '射頻鏈路沒連上：閘道現在什麼都轉不了。上面的「射頻收到」如果一直是 0，'
                 '說明報文根本沒進來 —— 先查裝置頁裡的 TNC / 音訊狀態（串列埠線速、'
                 '裝置是否開機），而不是懷疑閘道。',
        'en': 'The RF link is down, so the gateway cannot relay anything right now. '
              'If “Heard on RF” stays 0, no packets are arriving at all — check the '
              'TNC/audio status on the device page (serial baud, device powered on) '
              'before suspecting the gateway.',
        'ja': 'RF リンクが未接続のため、ゲートウェイは何も中継できません。'
              '「RF 受信」が 0 のままならパケットがそもそも届いていません。'
              'TNC／オーディオの状態（シリアル速度・電源）を確認してください。',
        'id': 'Tautan RF terputus, gateway tidak dapat meneruskan apa pun. '
              'Jika “Diterima di RF” tetap 0, paket tidak sampai — periksa status '
              'TNC/audio (baud serial, perangkat menyala), bukan gateway-nya.',
        'es': 'El enlace de RF está caído: la pasarela no puede reenviar nada. '
              'Si «Oídos por RF» sigue en 0, no llega ningún paquete — revisa el '
              'estado del TNC/audio (velocidad serie, equipo encendido), no la pasarela.',
    },
    'igateIsDown': {
        'zh': 'APRS-IS 没连上：网关没有可转递的目标网络。等它连上（链路状态卡里能看到）'
              '后数字才会开始涨。',
        'zh_TW': 'APRS-IS 沒連上：閘道沒有可轉遞的目標網路。等它連上'
                 '（鏈路狀態卡裡能看到）後數字才會開始漲。',
        'en': 'APRS-IS is not connected, so the gateway has nowhere to relay to. '
              'The counters will only start moving once it is up (see the link '
              'status card).',
        'ja': 'APRS-IS が未接続のため、転送先がありません。接続が確立すると'
              'カウンタが動き始めます（リンク状態カードを参照）。',
        'id': 'APRS-IS belum terhubung, gateway tidak punya tujuan penerusan. '
              'Penghitung baru bergerak setelah tersambung (lihat kartu status tautan).',
        'es': 'APRS-IS no está conectado: la pasarela no tiene a dónde reenviar. '
              'Los contadores empezarán a subir cuando se conecte (ver la tarjeta '
              'de estado del enlace).',
    },
    'igateNoRfTraffic': {
        'zh': '射频上一条报文都没收到：网关的条件已经全齐，但它**无报文可转**。'
              '这不是网关的问题 —— 报文根本没进到应用里。查上游：电台音量与静噪、'
              '天线、对方是否真的在发射，也可以在日志页确认有没有任何射频报文。',
        'zh_TW': '射頻上一條報文都沒收到：閘道的條件已經全齊，但它**無報文可轉**。'
                 '這不是閘道的問題 —— 報文根本沒進到應用程式裡。查上游：'
                 '電台音量與靜噪、天線、對方是否真的在發射，也可以在日誌頁確認有沒有任何射頻報文。',
        'en': 'No packets heard on RF at all: the gateway is fully armed but has '
              'nothing to relay. This is not a gateway problem — nothing is '
              'reaching the app. Check upstream: radio volume and squelch, antenna, '
              'whether anyone is actually transmitting, and the log page for any RF '
              'traffic at all.',
        'ja': 'RF でパケットを 1 件も受信していません。ゲートウェイの条件は揃っていますが'
              '**中継するものがありません**。ゲートウェイの問題ではなく、'
              'パケットがアプリに届いていません。上流を確認してください：'
              '無線機の音量とスケルチ、アンテナ、相手が実際に送信しているか、'
              'ログページに RF パケットがあるか。',
        'id': 'Tidak ada paket yang terdengar di RF: kondisi gateway sudah lengkap '
              'tetapi **tidak ada yang diteruskan**. Ini bukan masalah gateway — '
              'paket tidak sampai ke aplikasi. Periksa hulu: volume dan squelch '
              'radio, antena, apakah ada yang benar-benar memancar, dan halaman log '
              'untuk lalu lintas RF apa pun.',
        'es': 'No se ha oído ningún paquete por RF: la pasarela está lista pero '
              '**no tiene nada que reenviar**. No es un problema de la pasarela: '
              'nada llega a la aplicación. Revisa el origen: volumen y silenciador '
              'del equipo, antena, si alguien está transmitiendo y el registro por '
              'si hay tráfico de RF.',
    },
    'igateAllRejected': {
        'zh': '收到了射频报文，但全被环路防护拒收：报文里带 TCPIP*/TCPXX* 或 q 构造，'
              '说明它本来就从互联网来，再送回 APRS-IS 会让同一条报文无限增殖。'
              '这是**在正确工作**，不是故障。',
        'zh_TW': '收到了射頻報文，但全被迴路防護拒收：報文裡帶 TCPIP*/TCPXX* 或 q 構造，'
                 '說明它本來就從網際網路來，再送回 APRS-IS 會讓同一條報文無限增殖。'
                 '這是**在正確工作**，不是故障。',
        'en': 'RF packets are arriving but all of them were rejected by loop '
              'protection: they carry TCPIP*/TCPXX* or a q-construct, meaning they '
              'came from the internet, and sending them back would multiply the same '
              'packet forever. This is the gateway **working correctly**, not a fault.',
        'ja': 'RF パケットは届いていますが、すべてループ防止で拒否されました。'
              'TCPIP*/TCPXX* や q 構文を含む＝インターネット由来のため、'
              'APRS-IS に戻すと同一パケットが無限増殖します。**正常動作**です。',
        'id': 'Paket RF diterima tetapi semuanya ditolak proteksi loop: membawa '
              'TCPIP*/TCPXX* atau q-construct, artinya berasal dari internet, dan '
              'mengirimnya kembali akan memperbanyak paket yang sama. Ini '
              '**bekerja dengan benar**, bukan kerusakan.',
        'es': 'Llegan paquetes de RF pero todos fueron rechazados por la protección '
              'anti-bucle: llevan TCPIP*/TCPXX* o una construcción q, es decir, '
              'vienen de internet y reenviarlos multiplicaría el mismo paquete. '
              'Esto es **funcionar correctamente**, no una avería.',
    },
}

LANGS = ['zh', 'zh_TW', 'en', 'ja', 'id', 'es']
ANCHOR = '"igateResetStats"'


def main():
    for lang in LANGS:
        path = os.path.join(ROOT, 'lib/l10n/app_%s.arb' % lang)
        lines = io.open(path, encoding='utf-8').read().split('\n')
        keep = []
        for ln in lines:
            st = ln.strip()
            if any(st.startswith('"%s"' % k) for k in DATA):
                continue
            keep.append(ln)
        lines = keep
        # 锚点必须存在，否则说明 ARB 结构变了 —— 早点炸掉比静默插错位置好
        idx = next(i for i, ln in enumerate(lines)
                   if ln.strip().startswith(ANCHOR))
        block = ['  "%s": %s,' % (k, json.dumps(tr[lang], ensure_ascii=False))
                 for k, tr in DATA.items()]
        lines[idx + 1:idx + 1] = block
        io.open(path, 'w', encoding='utf-8', newline='').write('\n'.join(lines))
        d = json.loads(io.open(path, encoding='utf-8').read())
        n = len([k for k in d if not k.startswith('@')])
        print('%s ok, %d keys' % (os.path.basename(path), n))


if __name__ == '__main__':
    main()
