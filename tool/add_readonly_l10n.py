#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""向 6 个 ARB 注入「只读模式（仅 PKWDWPL）」的文案键。

背景：早期版本禁止只留只读来源，后来放开（离线记台账是合理用法），
界面因此必须把「不会发射」这件事说清楚。
幂等可重复执行。
"""
import io
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

DATA = {
    'pkwdwplReadOnly': {
        'zh': '只读接收中 · 本机不会发射任何报文',
        'zh_TW': '唯讀接收中 · 本機不會發射任何報文',
        'en': 'Receive-only · this device transmits nothing',
        'ja': '受信専用 · 本機は一切送信しません',
        'id': 'Hanya terima · perangkat ini tidak memancarkan apa pun',
        'es': 'Solo recepción · este equipo no transmite nada',
    },
}

LANGS = ['zh', 'zh_TW', 'en', 'ja', 'id', 'es']
ANCHOR = '"pkwdwplRxOnly"'


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
