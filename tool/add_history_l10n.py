#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""一次性脚本：为「历史轨迹」与「传感器辅助定位」补 l10n 键（6 语言）。

同时更新：
  * lib/l10n/app_*.arb                （真源）
  * lib/l10n/app_localizations.dart   （抽象类成员）
  * lib/l10n/app_localizations_*.dart （各语言实现）

产物按 gen-l10n 的形状手写（仓库把产物提交进了 git，本机不能跑 gen-l10n），
写完由 tool/check_l10n_sync.py 校验 arb ↔ 产物一一对应。
"""
import io
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

LANGS = ['zh', 'zh_TW', 'en', 'ja', 'es', 'id']
IDX = {lg: i for i, lg in enumerate(LANGS)}

# key → (zh, zh_TW, en, ja, es, id)
KEYS = {
    'historyTracks': (
        '历史轨迹', '歷史軌跡', 'Track history', '走行履歴',
        'Historial de rutas', 'Riwayat lintasan'),
    'historyTracksDesc': (
        '按天记录自己的速度与里程，保存在本机',
        '按天記錄自己的速度與里程，儲存在本機',
        'Records your own speed and distance by day, saved on this device',
        '自分の速度と距離を日別に記録し、端末に保存します',
        'Registra tu velocidad y distancia por día, guardadas en este dispositivo',
        'Mencatat kecepatan dan jarak Anda per hari, disimpan di perangkat ini'),
    'historyEmpty': (
        '还没有历史轨迹。开始定位并移动后会自动记录。',
        '還沒有歷史軌跡。開始定位並移動後會自動記錄。',
        'No track history yet. It is recorded automatically once you start '
        'positioning and move.',
        '走行履歴はまだありません。測位を開始して移動すると自動で記録されます。',
        'Aún no hay historial de rutas. Se registrará automáticamente al '
        'posicionarte y moverte.',
        'Belum ada riwayat lintasan. Akan terekam otomatis setelah penentuan '
        'posisi dan bergerak.'),
    'historyTotalDistance': (
        '总里程', '總里程', 'Total distance', '総距離',
        'Distancia total', 'Total jarak'),
    'historyMaxSpeed': (
        '最高速度', '最高速度', 'Max speed', '最高速度',
        'Velocidad máx.', 'Kecepatan maks.'),
    'historyMovingTime': (
        '移动时长', '移動時長', 'Moving time', '移動時間',
        'Tiempo en movimiento', 'Waktu bergerak'),
    'historyPoints': (
        '轨迹点', '軌跡點', 'Points', '軌跡点', 'Puntos', 'Titik'),
    'historyClearDay': (
        '删除这一天的记录', '刪除這一天的記錄', 'Delete this day',
        'この日の記録を削除', 'Eliminar este día', 'Hapus hari ini'),
    'historyCleared': (
        '已删除该天记录', '已刪除該天記錄', 'Day deleted',
        '記録を削除しました', 'Día eliminado', 'Hari dihapus'),
    'historyClearAll': (
        '清空全部历史轨迹', '清空全部歷史軌跡', 'Clear all track history',
        '走行履歴をすべて消去', 'Borrar todo el historial',
        'Hapus semua riwayat'),
    'historyClearAllConfirm': (
        '确定要清空全部历史轨迹吗？此操作无法撤销。',
        '確定要清空全部歷史軌跡嗎？此操作無法復原。',
        'Clear all track history? This cannot be undone.',
        '走行履歴をすべて消去しますか？この操作は取り消せません。',
        '¿Borrar todo el historial de rutas? No se puede deshacer.',
        'Hapus semua riwayat lintasan? Tindakan ini tidak dapat dibatalkan.'),
    'historyClearedAll': (
        '已清空全部历史轨迹', '已清空全部歷史軌跡', 'All track history cleared',
        '走行履歴をすべて消去しました', 'Historial borrado por completo',
        'Semua riwayat dihapus'),
    'sensorAssist': (
        '传感器辅助定位', '感測器輔助定位', 'Sensor-assisted positioning',
        'センサー支援測位', 'Posicionamiento con sensores',
        'Penentuan posisi dengan sensor'),
    'sensorAssistDesc': (
        '用加速度计判断是否真的在移动、用指南针补正低速航向，让轨迹打点更准'
        '（仅 Android 生效）。',
        '用加速度計判斷是否真的在移動、用指南針補正低速航向，讓軌跡打點更準'
        '（僅 Android 生效）。',
        'Uses the accelerometer to tell whether you are really moving and the '
        'compass to correct the heading at low speed, for more accurate track '
        'points (Android only).',
        '加速度センサーで実際に移動しているかを判定し、コンパスで低速時の方位を'
        '補正して軌跡をより正確に記録します（Android のみ）。',
        'Usa el acelerómetro para saber si te mueves de verdad y la brújula para '
        'corregir el rumbo a baja velocidad, para puntos de ruta más precisos '
        '(solo Android).',
        'Menggunakan akselerometer untuk mengetahui apakah benar-benar bergerak '
        'dan kompas untuk memperbaiki arah saat kecepatan rendah, agar titik '
        'lintasan lebih akurat (hanya Android).'),
}

# 生成类名（顺序与 LANGS 对应）
CLASSES = {
    'zh': 'AppLocalizationsZh',
    'zh_TW': 'AppLocalizationsZhTw',
    'en': 'AppLocalizationsEn',
    'ja': 'AppLocalizationsJa',
    'es': 'AppLocalizationsEs',
    'id': 'AppLocalizationsId',
}


def class_body(src, name):
    """返回 (类体起始, 类体结束) 两个索引。"""
    m = re.search(r'(?m)^(?:abstract )?class ' + re.escape(name) + r'\b', src)
    if not m:
        raise SystemExit(f'找不到类 {name}')
    j = src.find('\n}\n', m.end())
    if j < 0:
        j = src.rfind('\n}')
    return m.end(), j


def main() -> int:
    root = ROOT
    arb_dir = os.path.join(root, 'lib', 'l10n')

    # ① ARB
    for lg in LANGS:
        p = os.path.join(arb_dir, f'app_{lg}.arb')
        src = io.open(p, encoding='utf-8', newline='').read()
        add = []
        for key, vals in KEYS.items():
            if re.search(r'^\s*"' + re.escape(key) + r'":', src, re.M):
                print(f'  {lg}/{key}: 已存在，跳过')
                continue
            add.append(f'  {json.dumps(key, ensure_ascii=False)}: '
                       f'{json.dumps(vals[IDX[lg]], ensure_ascii=False)},')
        if not add:
            continue
        i = src.rstrip().rfind('}')
        head = src[:i].rstrip()
        if not head.endswith(','):
            head += ','
        src = head + '\n' + '\n'.join(add).rstrip(',') + '\n' + src[i:]
        io.open(p, 'w', encoding='utf-8', newline='').write(src)
        print(f'{lg}: ARB 追加 {len(add)} 键')

    # ② 抽象类（app_localizations.dart）
    p = os.path.join(arb_dir, 'app_localizations.dart')
    src = io.open(p, encoding='utf-8', newline='').read()
    code = []
    for key in KEYS:
        if f'String get {key};' in src:
            continue
        code.append(f'  /// No description provided for @{key}.')
        code.append('  ///')
        code.append('  /// In zh, this message translates to:')
        code.append(f"  /// **'{KEYS[key][0]}'**")
        code.append(f'  String get {key};')
        code.append('')
    if code:
        _s, j = class_body(src, 'AppLocalizations')
        src = src[:j] + '\n' + '\n'.join(code)[:-1] + src[j:]
        io.open(p, 'w', encoding='utf-8', newline='').write(src)
        print(f'抽象类追加 {len(code) // 6} 键')

    # ③ 各语言实现
    for lg in LANGS:
        name = CLASSES[lg]
        fn = ('app_localizations_zh.dart' if lg in ('zh', 'zh_TW')
              else f'app_localizations_{lg}.dart')
        p = os.path.join(arb_dir, fn)
        src = io.open(p, encoding='utf-8', newline='').read()
        b0, b1 = class_body(src, name)
        body = src[b0:b1]
        code = []
        for key, vals in KEYS.items():
            if re.search(r'String get ' + re.escape(key) + r'\s*[=;]', body):
                continue
            code.append('  @override')
            code.append(f"  String get {key} => "
                        f'{json.dumps(vals[IDX[lg]], ensure_ascii=False)};')
            code.append('')
        if not code:
            continue
        src = src[:b1] + '\n' + '\n'.join(code)[:-1] + src[b1:]
        io.open(p, 'w', encoding='utf-8', newline='').write(src)
        print(f'{name}: 实现追加 {len(code) // 3} 键')

    print('done')
    return 0


if __name__ == '__main__':
    sys.exit(main())
