#!/usr/bin/env python3
"""一次性脚本：为「系统状态组件」补 l10n 键（6 语言）。

写法沿用仓库里 tool/add_*_l10n.py 的既有做法：直接改 ARB 的 `"key": "值"`
行，随后 `flutter gen-l10n` 重新生成。

为什么单独写脚本而不是手改 6 个 ARB：手改要动 6×6=36 处，
漏一处就是「某个语言下组件显示空字符串」，而组件不会报错（`read()` 容错），
所以只能靠机械操作 + 生成后核对。
"""
import io
import json
import os
import re
import sys

# key → (zh, zh_TW, en, ja, es, id)
KEYS = {
    # 组件标题
    'sysTitle': ('系统状态', '系統狀態', 'System status', 'システム状態',
                 'Estado del sistema', 'Status sistem'),
    # 链路：该来源未被启用（与 disconnected 区分 —— 一个是「开了但没连上」，
    # 一个是「根本没开」，用户看到的应对措施完全不同）
    'sysLinkOff': ('未启用', '未啟用', 'Off', '未使用', 'Desactivado', 'Nonaktif'),
    # 计数行
    'sysRx': ('收 {n}', '收 {n}', 'Rx {n}', '受信 {n}', 'Rx {n}', 'Rx {n}'),
    'sysTx': ('发 {n}', '發 {n}', 'Tx {n}', '送信 {n}', 'Tx {n}', 'Tx {n}'),
    'sysBeacon': ('信标 {t}', '信標 {t}', 'Beacon {t}', 'ビーコン {t}',
                  'Baliza {t}', 'Beacon {t}'),
    'sysStations': ('台站 {n}', '臺站 {n}', 'Stations {n}', '局数 {n}',
                    'Estaciones {n}', 'Stasiun {n}'),
    # 链路短名：只翻译「音频」（APRS-IS/TNC/PKWDWPL 是品牌名与协议名，不译）。
    # 注意**不要**直接用 _sourceName 的说法（「音频（声卡）」）—— 那是
    # 设置页的长名，塞进 4 格链路区会把状态文字挤没。
    'sysLinkAudio': ('音频', '音訊', 'Audio', 'オーディオ', 'Audio', 'Audio'),
    # 空状态：还没拿到过任何状态时显示
    'sysEmpty': ('打开 APRSlocus 并连接后，这里会显示台站运行状态',
                 '開啟 APRSlocus 並連線後，這裡會顯示臺站執行狀態',
                 'Open APRSlocus and connect to see your station status here',
                 'APRSlocus を開いて接続すると、ここに運用状況が表示されます',
                 'Abre APRSlocus y conéctate para ver el estado aquí',
                 'Buka APRSlocus dan sambungkan untuk melihat status di sini'),
    # 最近收到的台站（「还在收吗」最直接的证据：最新那条 + 多久前）。
    # 用 APRS/业余界的行话「Last heard」，而不是逐字直译的「Recently received」。
    'sysRecentLabel': ('最近收到', '最近收到', 'Last heard', '直近受信',
                       'Última recepción', 'Terakhir diterima'),
    # 定位状态（「等待定位」复用了既有的 beaconWaitingFix，不重复造）
    'sysFixOk': ('已定位', '已定位', 'Located', '測位済み', 'Ubicado',
                 'Terlokasi'),
}

# 带占位符的键要写 @key 元数据，否则 gen-l10n 会把 {n} 当字面量
PLACEHOLDERS = {
    'sysRx': ['n'], 'sysTx': ['n'], 'sysBeacon': ['t'], 'sysStations': ['n'],
}

LANGS = ['zh', 'zh_TW', 'en', 'ja', 'es', 'id']
IDX = {lg: i for i, lg in enumerate(LANGS)}


def main() -> int:
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    arb_dir = os.path.join(root, 'lib', 'l10n')
    total = 0
    for lg in LANGS:
        p = os.path.join(arb_dir, f'app_{lg}.arb')
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
        #   错：... "last": "x",\n  新键\n}      ← 我第一版就是这么写坏的，
        #                                          6 个 ARB 全成了非法 JSON
        #   对：... "last": "x",\n  新键\n}
        # 做法：先在末尾键后**确保**有逗号，再追加新键，最后去掉新键后的逗号。
        i = src.rstrip().rfind('}')
        head = src[:i].rstrip()
        if not head.endswith(','):
            head += ','
        src = head + '\n' + '\n'.join(add).rstrip(',') + '\n' + src[i:]
        io.open(p, 'w', encoding='utf-8').write(src)
        total += len(add)
        print(f'{lg}: 追加 {len(add)} 行')
    print(f'\n共写入 {total} 行')
    return 0


if __name__ == '__main__':
    sys.exit(main())
