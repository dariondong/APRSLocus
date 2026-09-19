#!/usr/bin/env python3
"""一次性脚本：为「音频导出/发射体检 + 数据包控制台反馈」补 l10n 键（6 语言）。

写法沿用仓库里 tool/add_*_l10n.py 的既有做法：直接改 ARB 的 `"key": "值"`
行，随后 `flutter gen-l10n` 重新生成。

为什么单独写脚本而不是手改 6 个 ARB：手改要动 6×21=126 处，漏一处就是
「某个语言下显示空字符串」—— 而 gen-l10n 生成的是抽象 getter，Dart 侧不会
报错，只有用户看得到。机械操作 + 生成后核对才靠得住。
"""
import io
import json
import os
import re
import sys

# key → (zh, zh_TW, en, ja, es, id)
KEYS = {
    # ─── 音频 WAV：导入/导出（导出路径问题的修复配套）───
    'audioWavImportAction': (
        '选择 WAV 文件', '選擇 WAV 檔案', 'Choose WAV file', 'WAV ファイルを選択',
        'Elegir archivo WAV', 'Pilih berkas WAV'),
    'audioWavExportToDownloads': (
        '导出到下载目录', '匯出到下載目錄', 'Export to Downloads',
        'ダウンロードへ書き出し', 'Exportar a Descargas', 'Ekspor ke Unduhan'),
    'audioWavSavedTo': (
        '已保存到 {path}', '已儲存到 {path}', 'Saved to {path}',
        '保存先: {path}', 'Guardado en {path}', 'Disimpan ke {path}'),
    'audioWavCopyPath': (
        '复制路径', '複製路徑', 'Copy path', 'パスをコピー',
        'Copiar ruta', 'Salin jalur'),
    'audioWavPathCopied': (
        '路径已复制', '路徑已複製', 'Path copied', 'パスをコピーしました',
        'Ruta copiada', 'Jalur disalin'),
    'audioWavCanceled': (
        '已取消（未选择文件）', '已取消（未選擇檔案）', 'Cancelled',
        'キャンセルしました', 'Cancelado', 'Dibatalkan'),
    'audioWavVerifyFailed': (
        '导出前的自检失败：生成的音频解不出本报文（请反馈）',
        '匯出前的自檢失敗：生成的音訊解不出本報文（請回報）',
        'Self-check failed: the generated audio does not decode back',
        '書き出し前の自己検査に失敗：生成した音声を復調できません',
        'Falló la autocomprobación: el audio generado no se puede decodificar',
        'Pemeriksaan gagal: audio yang dibuat tidak dapat didekode'),
    'audioWavMobileHint': (
        'Android 不能写任意目录：导出会保存到「下载/APRSlocusAudio」，无需填路径；'
        '拷到电脑后即可喂给 Direwolf 或电台',
        'Android 不能寫任意目錄：匯出會存到「下載/APRSlocusAudio」，無需填路徑；'
        '複製到電腦後即可餵給 Direwolf 或電台',
        'Android cannot write arbitrary paths: the file goes to '
        'Downloads/APRSlocusAudio — copy it to a PC for Direwolf or a radio',
        'Android では任意のパスに書けません：ダウンロード/APRSlocusAudio に'
        '保存されます（PC にコピーして Direwolf や無線機へ）',
        'Android no permite rutas arbitrarias: se guarda en '
        'Descargas/APRSlocusAudio — cópialo al PC para Direwolf o la radio',
        'Android tidak bisa menulis jalur bebas: berkas disimpan di '
        'Unduhan/APRSlocusAudio — salin ke PC untuk Direwolf atau radio'),
    'audioWavPickHint': (
        '桌面端请在下方填写 WAV 路径', '桌面端請在下方填寫 WAV 路徑',
        'On desktop, enter the WAV path below',
        'デスクトップでは下に WAV パスを入力してください',
        'En escritorio, escribe la ruta del WAV abajo',
        'Di desktop, isi jalur WAV di bawah'),

    # ─── 音频发射体检 ───
    'audioTxLevel': (
        '发射电平', '發射電平', 'TX level', '送信レベル', 'Nivel de TX',
        'Level TX'),
    'audioTxLevelTip': (
        '发射前系统会把媒体音量拉到最大、并暂停麦克风采集；峰值太低或削顶都会让'
        '对端解不出',
        '發射前系統會把媒體音量拉到最大、並暫停麥克風擷取；峰值太低或削頂都會讓'
        '對端解不出',
        'Before transmitting the media volume is raised to maximum and the mic is '
        'paused; a peak that is too low or clipped means the other side cannot decode',
        '送信前にメディア音量を最大にし、マイク入力を一時停止します。'
        'ピークが低すぎてもクリップしても相手は復調できません',
        'Antes de transmitir se sube el volumen al máximo y se pausa el micrófono; '
        'un pico demasiado bajo o recortado impide decodificar al otro lado',
        'Sebelum mengirim, volume media dinaikkan maksimum dan mikrofon dijeda; '
        'puncak terlalu rendah atau terpotong membuat lawan tidak bisa mendekode'),
    'audioTxPeak': (
        '峰值 {p}% · {sec}s · 前导 {flags} flag', '峰值 {p}% · {sec}s · 前導 {flags} flag',
        'Peak {p}% · {sec}s · preamble {flags} flags',
        'ピーク {p}% · {sec}s · プリアンブル {flags} フラグ',
        'Pico {p}% · {sec}s · preámbulo {flags} flags',
        'Puncak {p}% · {sec}s · preamble {flags} flag'),
    'audioTxLevelClip': (
        '波形削顶：请把「输出幅度」调到 0.8 以下（削顶会产生谐波）',
        '波形削頂：請把「輸出幅度」調到 0.8 以下（削頂會產生諧波）',
        'Clipped: lower the output amplitude below 0.8 (clipping adds harmonics)',
        'クリップしています：出力振幅を 0.8 未満に下げてください（高調波が出ます）',
        'Recortado: baja la amplitud por debajo de 0.8 (genera armónicos)',
        'Terpotong: turunkan amplitudo di bawah 0.8 (menimbulkan harmonisa)'),
    'audioTxLevelLow': (
        '电平偏低：对方可能解不出，请调高「输出幅度」与设备音量',
        '電平偏低：對方可能解不出，請調高「輸出幅度」與裝置音量',
        'Low level: the other side may not decode — raise amplitude and device volume',
        'レベルが低い：相手が復調できない可能性があります。振幅と音量を上げてください',
        'Nivel bajo: puede que no lo decodifiquen — sube amplitud y volumen',
        'Level rendah: lawan mungkin tidak bisa mendekode — naikkan amplitudo dan volume'),
    'audioWiringHint': (
        '接电台请用音频线（耳机口 → 电台数据口/话筒）；手机扬声器在 2200Hz 衰减'
        '很大，对着麦克风很难解出。对端是电脑上的 Direwolf 时，先用「导出」出的 '
        'WAV 验证一遍，能解出就说明问题在音频通路而不是协议',
        '接電台請用音訊線（耳機孔 → 電台資料孔/麥克風）；手機喇叭在 2200Hz 衰減'
        '很大，對著麥克風很難解出。對端是電腦上的 Direwolf 時，先用「匯出」出的 '
        'WAV 驗證一遍，能解出就說明問題在音訊通路而不是協定',
        'Use an audio cable to the radio (headphone out → data/mic jack). Phone '
        'speakers roll off badly at 2200 Hz, so acoustic coupling rarely decodes. If '
        'the far end is Direwolf, first verify with the exported WAV: if that decodes, '
        'the problem is the audio path, not the protocol',
        '無線機へはオーディオケーブルで（イヤホン出力 → データ/マイク端子）。'
        'スマホのスピーカーは 2200Hz が大きく減衰し、音響結合ではまず復調できません。'
        '相手が Direwolf なら、まず書き出した WAV で確認を：それで復調できれば'
        '問題は音声経路であってプロトコルではありません',
        'Usa un cable de audio hacia la radio (salida de auriculares → conector de '
        'datos/micrófono). El altavoz del móvil atenúa mucho a 2200 Hz, así que por '
        'aire casi nunca decodifica. Si el otro extremo es Direwolf, verifica primero '
        'con el WAV exportado: si eso decodifica, el problema es el audio, no el protocolo',
        'Gunakan kabel audio ke radio (keluaran headphone → konektor data/mikrofon). '
        'Speaker ponsel meredam 2200 Hz dengan buruk, jadi kopling akustik hampir tidak '
        'pernah bisa didekode. Jika lawan adalah Direwolf, uji dulu dengan WAV hasil '
        'ekspor: kalau itu bisa, masalahnya di jalur audio, bukan protokol'),

    # ─── 数据包控制台：手动注入的反馈 ───
    'packetLimitRf': (
        '整包 {bytes} 字节 · 射频单帧上限 {max} 字节',
        '整包 {bytes} 位元組 · 射頻單幀上限 {max} 位元組',
        'Packet {bytes} B · RF frame limit {max} B',
        'パケット {bytes} バイト · 無線フレーム上限 {max} バイト',
        'Paquete {bytes} B · límite de trama RF {max} B',
        'Paket {bytes} B · batas bingkai RF {max} B'),
    'packetLimitIs': (
        '整包 {bytes} 字节 · APRS-IS 单行上限 512 字节',
        '整包 {bytes} 位元組 · APRS-IS 單行上限 512 位元組',
        'Packet {bytes} B · APRS-IS line limit 512 B',
        'パケット {bytes} バイト · APRS-IS 1 行上限 512 バイト',
        'Paquete {bytes} B · límite de línea APRS-IS 512 B',
        'Paket {bytes} B · batas baris APRS-IS 512 B'),
    'packetTcpipWarning': (
        '含 TCPIP*：射频上会被自动剔除（那是 APRS-IS 的路径）',
        '含 TCPIP*：射頻上會被自動剔除（那是 APRS-IS 的路徑）',
        'Contains TCPIP*: it is stripped on RF (that path belongs to APRS-IS)',
        'TCPIP* を含みます：無線では自動的に除去されます（APRS-IS のパス）',
        'Contiene TCPIP*: se elimina en RF (esa ruta es de APRS-IS)',
        'Mengandung TCPIP*: akan dihapus di RF (jalur itu milik APRS-IS)'),
    'packetSent': (
        '已交给链路发送：{line}', '已交給鏈路發送：{line}',
        'Handed to the link: {line}', 'リンクへ送信しました：{line}',
        'Entregado al enlace: {line}', 'Diteruskan ke tautan: {line}'),
    'packetSendFailed': (
        '未发送：{err}', '未發送：{err}', 'Not sent: {err}',
        '送信していません：{err}', 'No enviado: {err}', 'Tidak terkirim: {err}'),
}

PLACEHOLDERS = {
    'audioWavSavedTo': {'path': 'String'},
    'audioTxPeak': {'p': 'int', 'sec': 'String', 'flags': 'int'},
    'packetLimitRf': {'bytes': 'int', 'max': 'int'},
    'packetLimitIs': {'bytes': 'int'},
    'packetSent': {'line': 'String'},
    'packetSendFailed': {'err': 'String'},
}

# 已经存在但要改文案的键（zh, zh_TW, en, ja, es, id）
UPDATES = {
    # Android 侧发射时会真的暂停采集，旧文案「发射期间丢弃」不再准确
    'audioLoopbackHint': (
        '自检会真的做一次调制→解调；Android 发射时会暂停麦克风采集（半双工）',
        '自檢會真的做一次調變→解調；Android 發射時會暫停麥克風擷取（半雙工）',
        'The self-test really does a modulate→demodulate round trip; on Android the '
        'microphone is paused while transmitting (half duplex)',
        '自己検査は実際に変調→復調を行います。Android では送信中マイクを'
        '一時停止します（半二重）',
        'La autocomprobación hace una ida y vuelta real de modulación→demodulación; '
        'en Android el micrófono se pausa al transmitir (semidúplex)',
        'Pemeriksaan benar-benar melakukan modulasi→demodulasi; di Android mikrofon '
        'dijeda saat mengirim (half duplex)'),
}

LANGS = ['zh', 'zh_TW', 'en', 'ja', 'es', 'id']
IDX = {lg: i for i, lg in enumerate(LANGS)}


def _entry(key: str, val: str) -> list[str]:
    out = [f'  {json.dumps(key, ensure_ascii=False)}: '
           f'{json.dumps(val, ensure_ascii=False)},']
    if key in PLACEHOLDERS:
        ph = ', '.join(
            f'"{x}": {{"type": "{t}"}}' for x, t in PLACEHOLDERS[key].items())
        out.append(f'  "@{key}": {{')
        out.append(f'    "placeholders": {{{ph}}}')
        out.append('  },')
    return out


def main() -> int:
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    arb_dir = os.path.join(root, 'lib', 'l10n')
    total = 0
    for lg in LANGS:
        p = os.path.join(arb_dir, f'app_{lg}.arb')
        src = io.open(p, encoding='utf-8').read()

        # ① 改既有键的文案（整行替换）
        for key, vals in UPDATES.items():
            val = vals[IDX[lg]]
            pat = re.compile(r'^(\s*)"' + re.escape(key) + r'":.*$', re.M)
            if not pat.search(src):
                print(f'  {lg}/{key}: 不存在，跳过更新')
                continue
            src = pat.sub(
                lambda m: f'{m.group(1)}{json.dumps(key, ensure_ascii=False)}: '
                          f'{json.dumps(val, ensure_ascii=False)},',
                src, count=1)
            total += 1

        # ② 追加新键
        add = []
        for key, vals in KEYS.items():
            if re.search(r'^\s*"' + re.escape(key) + r'":', src, re.M):
                print(f'  {lg}/{key}: 已存在，跳过')
                continue
            add.extend(_entry(key, vals[IDX[lg]]))
        if add:
            # 插到最后一个顶层键之前。ARB 是 JSON 对象 —— 末尾不能有逗号，
            # 而最后一个原有键自带一个逗号，必须一并处理：
            #   做法：先在末尾键后**确保**有逗号，再追加新键，最后去掉新键后的逗号。
            i = src.rstrip().rfind('}')
            head = src[:i].rstrip()
            if not head.endswith(','):
                head += ','
            src = head + '\n' + '\n'.join(add).rstrip(',') + '\n' + src[i:]
            total += len(add)
            print(f'{lg}: 追加 {len(add)} 行')

        # ③ 落盘前先验证仍是合法 JSON（这一步曾救过 6 个 ARB）
        try:
            json.loads(src)
        except Exception as e:  # noqa: BLE001
            print(f'ERROR: {lg} 改完不是合法 JSON: {e}')
            return 1
        io.open(p, 'w', encoding='utf-8').write(src)
    print(f'\n共写入 {total} 行')
    return 0


if __name__ == '__main__':
    sys.exit(main())
