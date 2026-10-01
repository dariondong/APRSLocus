#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""向 6 个 ARB 注入「远程限制名单」拦截页的文案（用户协议 8.2 的落地界面）。

文本级插入，幂等可重复执行 —— 同 tool/add_*_l10n.py 的既有约定。
⚠ ICU：译文里不要出现落单的半角单引号。
"""
import io
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

DATA = {
    'blTitle': {
        'zh': '本设备已被限制使用', 'zh_TW': '本裝置已被限制使用',
        'en': 'This device has been blocked',
        'ja': 'この端末は利用を制限されています',
        'id': 'Perangkat ini telah dibatasi',
        'es': 'Este dispositivo ha sido bloqueado',
    },
    'blBody': {
        'zh': '依据《用户协议》第 8.2 条，我们有权限制、暂停或终止违反协议者的使用。'
              '本设备（呼号或安装标识）已被列入限制名单，因此无法继续使用本软件。',
        'zh_TW': '依《使用者條款》第 8.2 條，我們有權限制、暫停或終止違反條款者的使用。'
                 '本裝置（呼號或安裝識別碼）已被列入限制名單，因此無法繼續使用本軟體。',
        'en': 'Under section 8.2 of the Terms of Use we may restrict, suspend, or terminate '
              'use by anyone who violates the agreement. This device (callsign or install ID) '
              'is on the restriction list, so the app can no longer be used.',
        'ja': '利用規約 8.2 に基づき、規約に違反する方の利用を制限・停止・終了できるものと'
              'します。この端末（コールサインまたはインストール識別子）は制限リストに'
              '含まれているため、本ソフトは利用できません。',
        'id': 'Menurut Pasal 8.2 Ketentuan Penggunaan, kami dapat membatasi, menangguhkan, '
              'atau menghentikan penggunaan oleh pihak yang melanggar. Perangkat ini '
              '(callsign atau ID instalasi) ada dalam daftar pembatasan, sehingga aplikasi '
              'tidak dapat digunakan lagi.',
        'es': 'Según la sección 8.2 de los Términos de uso, podemos restringir, suspender o '
              'terminar el uso de quien incumpla el acuerdo. Este dispositivo (indicativo o '
              'ID de instalación) figura en la lista de restricción, por lo que la app ya no '
              'puede utilizarse.',
    },
    'blReason': {
        'zh': '原因', 'zh_TW': '原因', 'en': 'Reason',
        'ja': '理由', 'id': 'Alasan', 'es': 'Motivo',
    },
    'blMatched': {
        'zh': '命中项', 'zh_TW': '命中項', 'en': 'Matched entry',
        'ja': '一致した項目', 'id': 'Entri yang cocok', 'es': 'Entrada coincidente',
    },
    'blId': {
        'zh': '本机安装标识', 'zh_TW': '本機安裝識別碼', 'en': 'Install ID',
        'ja': 'インストール識別子', 'id': 'ID instalasi', 'es': 'ID de instalación',
    },
    'blContact': {
        'zh': '如果你认为这是误判，请通过 GitHub 仓库提交 Issue，并附上上面的安装标识 —— '
              '那是我们核对时的唯一依据。',
        'zh_TW': '如果你認為這是誤判，請透過 GitHub 倉庫提交 Issue，並附上上面的安裝識別碼 '
                 '—— 那是我們核對時的唯㇐依據。',
        'en': 'If you believe this is a mistake, open an Issue in the GitHub repository and '
              'include the install ID above - it is the only thing we can match against.',
        'ja': '誤りだと思われる場合は、GitHub リポジトリで Issue を作成し、上のインストール'
              '識別子を添えてください。照合できるのはそれだけです。',
        'id': 'Jika menurut Anda ini keliru, buka Issue di repositori GitHub dan sertakan ID '
              'instalasi di atas - hanya itu yang bisa kami cocokkan.',
        'es': 'Si crees que es un error, abre un Issue en el repositorio de GitHub e incluye '
              'el ID de instalación de arriba: es lo único con lo que podemos comparar.',
    },
    'blRetry': {
        'zh': '重新检查', 'zh_TW': '重新檢查', 'en': 'Check again',
        'ja': '再確認', 'id': 'Periksa lagi', 'es': 'Comprobar de nuevo',
    },
    'blChecking': {
        'zh': '正在检查…', 'zh_TW': '檢查中…', 'en': 'Checking…',
        'ja': '確認中…', 'id': 'Memeriksa…', 'es': 'Comprobando…',
    },
    'blExemptOn': {
        'zh': '已加入本机白名单：本机不再受远程限制（再长按可恢复）',
        'zh_TW': '已加入本機白名單：本機不再受遠端限制（再長按可恢復）',
        'en': 'Added to the local whitelist: this device is no longer restricted '
              '(long-press again to restore)',
        'ja': '本機の許可リストに追加しました：この端末は制限されません'
              '（もう一度長押しで元に戻せます）',
        'id': 'Ditambahkan ke daftar putih lokal: perangkat ini tidak lagi dibatasi '
              '(tekan lama lagi untuk memulihkan)',
        'es': 'Añadido a la lista blanca local: este dispositivo ya no está restringido '
              '(mantén pulsado de nuevo para restaurar)',
    },
    'blExemptOff': {
        'zh': '已恢复远程限制（本机不再豁免）',
        'zh_TW': '已恢復遠端限制（本機不再豁免）',
        'en': 'Remote restriction restored (no longer exempt)',
        'ja': 'リモート制限を再び有効にしました（免除は解除）',
        'id': 'Pembatasan jarak jauh diaktifkan kembali (tidak lagi dikecualikan)',
        'es': 'Restricción remota restaurada (ya no exento)',
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
        idx = next(i for i, ln in enumerate(keep)
                   if ln.strip().startswith(ANCHOR))
        block = ['  "%s": %s,' % (k, json.dumps(tr[lang], ensure_ascii=False))
                 for k, tr in DATA.items()]
        keep[idx + 1:idx + 1] = block
        io.open(path, 'w', encoding='utf-8').write('\n'.join(keep))
        d = json.loads(io.open(path, encoding='utf-8').read())
        print('%s ok, %d keys' % (os.path.basename(path),
                                  len([k for k in d if not k.startswith('@')])))


if __name__ == '__main__':
    main()
