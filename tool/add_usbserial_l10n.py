#!/usr/bin/env python3
"""一次性脚本：为「硬件串口（Android USB-OTG / 桌面串口线速）」补 l10n 键（6 语言）。

写法沿用仓库里 tool/add_*_l10n.py 的既有做法：直接改 ARB 的 `"key": "值"`
行，随后 `flutter gen-l10n` 重新生成。

为什么单独写脚本而不是手改 6 个 ARB：手改要动 6×4=24 处，漏一处就是
「某个语言下显示空字符串」—— 而 gen-l10n 生成的是抽象 getter，Dart 侧不会
报错，只有用户看得到。机械操作 + 生成后核对才靠得住。
"""
import io
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ARB_DIR = os.path.join(ROOT, 'lib', 'l10n')

LANGS = ['zh', 'zh_TW', 'en', 'ja', 'id', 'es']
IDX = {lg: i for i, lg in enumerate(LANGS)}

# key -> [zh, zh_TW, en, ja, id, es]
KEYS = {
    'tncSerialBaud': [
        '串口线速 (bd)',
        '串列埠線速 (bd)',
        'Serial baud rate (bd)',
        'シリアル通信速度 (bd)',
        'Kecepatan baud serial (bd)',
        'Velocidad en baudios (bd)',
    ],
    'tncSerialBaudTip': [
        'USB 串口线与电台数据口必须同速，否则一个字节都收不到。'
        '常见值：9600 / 19200 / 38400 / 57600 / 115200。'
        '蓝牙 SPP 没有波特率概念，绑蓝牙设备时此项不生效。',
        'USB 串列線與電台資料埠必須同速，否則一個位元組都收不到。'
        '常見值：9600 / 19200 / 38400 / 57600 / 115200。'
        '藍牙 SPP 沒有線速概念，綁藍牙裝置時此項不生效。',
        'A USB serial cable and the radio data port must agree on the speed, '
        'otherwise not a single byte gets through. Common values: '
        '9600 / 19200 / 38400 / 57600 / 115200. Bluetooth SPP has no baud '
        'rate, so this is ignored for Bluetooth devices.',
        'USB シリアルケーブルと無線機のデータ端子は同じ速度にする必要があり、'
        '違うと 1 バイトも通りません。よく使う値：9600 / 19200 / 38400 / '
        '57600 / 115200。Bluetooth SPP には速度の概念がなく、Bluetooth '
        '機器ではこの設定は無効です。',
        'Kabel serial USB dan port data radio harus sama kecepatannya, '
        'kalau tidak satu byte pun tidak akan lewat. Nilai umum: '
        '9600 / 19200 / 38400 / 57600 / 115200. Bluetooth SPP tidak punya '
        'konsep baud, jadi ini diabaikan untuk perangkat Bluetooth.',
        'El cable serie USB y el puerto de datos de la radio deben usar la '
        'misma velocidad; si no, no pasa ni un byte. Valores habituales: '
        '9600 / 19200 / 38400 / 57600 / 115200. Bluetooth SPP no tiene '
        'velocidad en baudios, así que se ignora en dispositivos Bluetooth.',
    ],
    'tncSerialBaudHint': [
        '改完线速后需要重新连接才会生效（点「下发参数」会自动重连一次）',
        '改完線速後需要重新連線才會生效（點「下發參數」會自動重連一次）',
        'The new speed takes effect after reconnecting (sending the parameters '
        'reconnects once automatically)',
        '変更した速度は再接続後に有効になります（「パラメータ送信」で'
        '1 回自動的に再接続します）',
        'Kecepatan baru berlaku setelah menghubungkan ulang (mengirim '
        'parameter akan menyambung ulang sekali secara otomatis)',
        'La nueva velocidad se aplica al reconectar (al enviar los '
        'parámetros se reconecta una vez automáticamente)',
    ],
    'tncSerialBaudBluetooth': [
        '当前绑的是蓝牙设备：蓝牙 SPP 没有波特率概念，此项不生效',
        '目前綁的是藍牙裝置：藍牙 SPP 沒有線速概念，此項不生效',
        'A Bluetooth device is bound: Bluetooth SPP has no baud rate, so this '
        'setting has no effect',
        '現在バインドされているのは Bluetooth 機器です。Bluetooth SPP には'
        '速度の概念がないため、この設定は無効です',
        'Perangkat yang tertaut adalah Bluetooth: Bluetooth SPP tidak punya '
        'konsep baud, jadi pengaturan ini tidak berpengaruh',
        'El dispositivo vinculado es Bluetooth: Bluetooth SPP no tiene '
        'velocidad en baudios, así que este ajuste no surte efecto',
    ],
}

PLACEHOLDERS = {}


def main():
    total = 0
    for lg in LANGS:
        p = os.path.join(ARB_DIR, 'app_%s.arb' % lg)
        src = io.open(p, encoding='utf-8').read()
        add = []
        for key, vals in KEYS.items():
            if re.search(r'^\s*"' + re.escape(key) + r'":', src, re.M):
                print(f'  {lg}/{key}: 已存在，跳过')
                continue
            val = vals[IDX[lg]]
            add.append(f'  {json.dumps(key, ensure_ascii=False)}: '
                       f'{json.dumps(val, ensure_ascii=False)},')
            if key in PLACEHOLDERS:
                ph = ', '.join(
                    f'"{x}": {{"type": "String"}}' for x in PLACEHOLDERS[key])
                add.append(f'  "@{key}": {{')
                add.append(f'    "placeholders": {{{ph}}}')
                add.append('  },')
        if not add:
            continue
        # 插到最后一个顶层键之前。ARB 是 JSON 对象 ——
        # **末尾不能有逗号**，而最后一个原有键自带一个逗号，必须一并处理：
        #   原：... "last": "x"\n}
        #   错：... "last": "x",\n  新键\n}      ← 第一版就是这么写坏的，
        #                                          6 个 ARB 全成了非法 JSON
        #   对：... "last": "x",\n  新键\n}
        i = src.rstrip().rfind('}')
        head = src[:i].rstrip()
        if not head.endswith(','):
            head += ','
        src = head + '\n' + '\n'.join(add).rstrip(',') + '\n' + src[i:]
        io.open(p, 'w', encoding='utf-8').write(src)
        total += len(add)
        print(f'{lg}: 追加 {len(add)} 行')

    # 立刻校验：写坏 JSON 的话 gen-l10n 会报「不是合法 JSON」，
    # 但那时已经分不清是哪个语言、哪一行 —— 在这里当场验最省事。
    bad = 0
    for lg in LANGS:
        p = os.path.join(ARB_DIR, 'app_%s.arb' % lg)
        try:
            json.load(io.open(p, encoding='utf-8'))
        except Exception as e:
            bad += 1
            print(f'❌ {lg} 不是合法 JSON：{e}')
    print(f'\n共写入 {total} 行，非法 JSON {bad} 个')
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
