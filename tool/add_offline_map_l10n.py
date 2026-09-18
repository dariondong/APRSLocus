#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""注入「离线地图」相关文案（6 语言）。

背景：新增离线地图下载（瓦片磁盘缓存 + 区域下载 + 仅离线模式），
界面文案集中在这里注入。

约定与 tool/add_hf_l10n.py 一致：按锚点键插入、六语言同批写。
差别是**占位符元数据由脚本按 zh 文案里的 `{name}` 自动生成**，
而不是像 add_hf_l10n.py 那样手写 —— 手写一次漏一个占位符，
`flutter gen-l10n` 就会直接报错；自动生成不会漏也不会多。
"""
import io
import json
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# 无占位符的键
DATA = {
    'offlineLoading': {
        'zh': '加载中…', 'zh_TW': '載入中…', 'en': 'Loading…',
        'ja': '読み込み中…', 'id': 'Memuat…', 'es': 'Cargando…',
    },
    'offlineMap': {
        'zh': '离线地图', 'zh_TW': '離線地圖', 'en': 'Offline maps',
        'ja': 'オフラインマップ', 'id': 'Peta offline', 'es': 'Mapas sin conexión',
    },
    'offlineMapDesc': {
        'zh': '把地图瓦片预先下载到本机，没有网络时也能看地图',
        'zh_TW': '先把地圖圖磚下載到本機，沒有網路時也能看地圖',
        'en': 'Download map tiles ahead of time so the map works without a network',
        'ja': '地図タイルを事前に保存し、ネットワークなしでも地図を表示します',
        'id': 'Unduh ubin peta lebih dulu agar peta tetap tampil tanpa jaringan',
        'es': 'Descargue teselas de mapa con antelación para ver el mapa sin red',
    },
    'offlineMapFooter': {
        'zh': '瓦片只保存在本机，不会上传；不同图源的瓦片分开缓存',
        'zh_TW': '圖磚只保存在本機，不會上傳；不同圖源的圖磚分開快取',
        'en': 'Tiles stay on this device and are never uploaded; each source keeps its own cache',
        'ja': 'タイルは端末内のみに保存され、送信されません。図源ごとに別々にキャッシュされます',
        'id': 'Ubin hanya tersimpan di perangkat ini dan tidak diunggah; tiap sumber punya cache sendiri',
        'es': 'Las teselas solo se guardan en este dispositivo; cada fuente tiene su propia caché',
    },
    'offlineRegions': {
        'zh': '离线区域', 'zh_TW': '離線區域', 'en': 'Offline areas',
        'ja': 'オフラインエリア', 'id': 'Area offline', 'es': 'Zonas sin conexión',
    },
    'offlineRegionsDesc': {
        'zh': '已下载的区域可在地图上离线查看',
        'zh_TW': '已下載的區域可在地圖上離線檢視',
        'en': 'Downloaded areas can be viewed on the map offline',
        'ja': 'ダウンロード済みの範囲はオフラインで地図表示できます',
        'id': 'Area yang diunduh dapat dilihat di peta secara offline',
        'es': 'Las zonas descargadas se pueden ver en el mapa sin conexión',
    },
    'offlineNew': {
        'zh': '新建区域', 'zh_TW': '新建區域', 'en': 'New area',
        'ja': '新規エリア', 'id': 'Area baru', 'es': 'Zona nueva',
    },
    'offlineNoRegions': {
        'zh': '还没有离线区域', 'zh_TW': '還沒有離線區域',
        'en': 'No offline areas yet', 'ja': 'オフラインエリアがありません',
        'id': 'Belum ada area offline', 'es': 'Aún no hay zonas sin conexión',
    },
    'offlineNoRegionsHint': {
        'zh': '点右上角「新建区域」，把常去的地方下载下来',
        'zh_TW': '點右上角「新建區域」，把常去的地方下載下來',
        'en': 'Tap "New area" to download the places you visit often',
        'ja': '右上の「新規エリア」からよく行く場所を保存できます',
        'id': 'Ketuk "Area baru" untuk mengunduh tempat yang sering Anda kunjungi',
        'es': 'Toque "Zona nueva" para descargar los lugares que frecuenta',
    },
    'offlineCacheUsage': {
        'zh': '瓦片缓存', 'zh_TW': '圖磚快取', 'en': 'Tile cache',
        'ja': 'タイルキャッシュ', 'id': 'Cache ubin', 'es': 'Caché de teselas',
    },
    'offlineCacheUsageDesc': {
        'zh': '浏览地图时自动缓存，也可手动下载区域',
        'zh_TW': '瀏覽地圖時自動快取，也可手動下載區域',
        'en': 'Cached automatically while browsing; areas can also be downloaded manually',
        'ja': '地図閲覧時に自動保存。エリアを手動でダウンロードも可能',
        'id': 'Otomatis di-cache saat menjelajah; area juga bisa diunduh manual',
        'es': 'Se almacena al navegar; también puede descargar zonas manualmente',
    },
    'offlineClearCache': {
        'zh': '清除全部瓦片缓存', 'zh_TW': '清除全部圖磚快取',
        'en': 'Clear all tile cache', 'ja': 'タイルキャッシュを全消去',
        'id': 'Hapus semua cache ubin', 'es': 'Borrar toda la caché de teselas',
    },
    'offlineClearCacheConfirm': {
        'zh': '清除全部已下载的地图瓦片？',
        'zh_TW': '清除全部已下載的地圖圖磚？',
        'en': 'Clear all downloaded map tiles?',
        'ja': 'ダウンロード済みの地図タイルをすべて削除しますか？',
        'id': 'Hapus semua ubin peta yang diunduh?',
        'es': '¿Borrar todas las teselas descargadas?',
    },
    'offlineClearCacheConfirmBody': {
        'zh': '已下载的瓦片会被删除，区域记录会保留（需要重新下载才能离线查看）。',
        'zh_TW': '已下載的圖磚會被刪除，區域記錄會保留（需要重新下載才能離線檢視）。',
        'en': 'Downloaded tiles will be deleted; area records stay and must be downloaded again for offline use.',
        'ja': 'ダウンロード済みタイルは削除されます。エリア記録は残るため、再ダウンロードが必要です。',
        'id': 'Ubin yang diunduh akan dihapus; catatan area tetap dan perlu diunduh ulang untuk offline.',
        'es': 'Se eliminarán las teselas descargadas; las zonas se conservan y habrá que descargarlas de nuevo.',
    },
    'offlineAreaHint': {
        'zh': '当前画面范围就是下载范围',
        'zh_TW': '目前畫面範圍就是下載範圍',
        'en': 'The current view is the area to download',
        'ja': '現在の表示範囲がダウンロード範囲です',
        'id': 'Tampilan saat ini adalah area yang diunduh',
        'es': 'La vista actual es la zona que se descargará',
    },
    'offlineSource': {
        'zh': '图源', 'zh_TW': '圖源', 'en': 'Map source',
        'ja': '図源', 'id': 'Sumber peta', 'es': 'Fuente del mapa',
    },
    'offlineName': {
        'zh': '名称', 'zh_TW': '名稱', 'en': 'Name',
        'ja': '名前', 'id': 'Nama', 'es': 'Nombre',
    },
    'offlineNameHint': {
        'zh': '例如：家附近', 'zh_TW': '例如：家附近', 'en': 'e.g. Around home',
        'ja': '例：自宅周辺', 'id': 'mis. Sekitar rumah', 'es': 'p. ej. Cerca de casa',
    },
    'offlineStartDownload': {
        'zh': '开始下载', 'zh_TW': '開始下載', 'en': 'Start download',
        'ja': 'ダウンロード開始', 'id': 'Mulai unduh', 'es': 'Empezar descarga',
    },
    'offlineStatusPending': {
        'zh': '等待下载', 'zh_TW': '等待下載', 'en': 'Waiting',
        'ja': '待機中', 'id': 'Menunggu', 'es': 'En espera',
    },
    'offlineStatusRunning': {
        'zh': '下载中', 'zh_TW': '下載中', 'en': 'Downloading',
        'ja': 'ダウンロード中', 'id': 'Mengunduh', 'es': 'Descargando',
    },
    'offlineStatusPaused': {
        'zh': '已暂停', 'zh_TW': '已暫停', 'en': 'Paused',
        'ja': '一時停止', 'id': 'Dijeda', 'es': 'En pausa',
    },
    'offlineStatusDone': {
        'zh': '已完成', 'zh_TW': '已完成', 'en': 'Done',
        'ja': '完了', 'id': 'Selesai', 'es': 'Completado',
    },
    'offlineStatusCanceled': {
        'zh': '已取消', 'zh_TW': '已取消', 'en': 'Canceled',
        'ja': 'キャンセル済み', 'id': 'Dibatalkan', 'es': 'Cancelado',
    },
    'offlineStatusFailed': {
        'zh': '下载失败', 'zh_TW': '下載失敗', 'en': 'Failed',
        'ja': '失敗', 'id': 'Gagal', 'es': 'Falló',
    },
    'offlinePause': {
        'zh': '暂停', 'zh_TW': '暫停', 'en': 'Pause',
        'ja': '一時停止', 'id': 'Jeda', 'es': 'Pausar',
    },
    'offlineResume': {
        'zh': '继续', 'zh_TW': '繼續', 'en': 'Resume',
        'ja': '再開', 'id': 'Lanjutkan', 'es': 'Reanudar',
    },
    'offlineCancelDownload': {
        'zh': '取消', 'zh_TW': '取消', 'en': 'Cancel',
        'ja': 'キャンセル', 'id': 'Batal', 'es': 'Cancelar',
    },
    'offlineDeleteKeepTiles': {
        'zh': '仅删除记录（保留已下载瓦片）',
        'zh_TW': '僅刪除記錄（保留已下載圖磚）',
        'en': 'Delete the record only (keep tiles)',
        'ja': '記録のみ削除（タイルは保持）',
        'id': 'Hapus catatan saja (ubin tetap ada)',
        'es': 'Eliminar solo el registro (conservar teselas)',
    },
    'offlineDeleteWithTiles': {
        'zh': '删除记录并删除瓦片',
        'zh_TW': '刪除記錄並刪除圖磚',
        'en': 'Delete the record and its tiles',
        'ja': '記録とタイルを削除',
        'id': 'Hapus catatan dan ubinnya',
        'es': 'Eliminar el registro y sus teselas',
    },
    'offlineDownloadBusy': {
        'zh': '已有下载任务在进行，请先等待或取消',
        'zh_TW': '已有下載任務在進行，請先等待或取消',
        'en': 'Another download is running — wait or cancel it first',
        'ja': '別のダウンロードが進行中です。完了かキャンセルを待ってください',
        'id': 'Ada unduhan lain yang berjalan — tunggu atau batalkan dulu',
        'es': 'Hay otra descarga en curso: espere o cancélela',
    },
    'offlineCacheSwitch': {
        'zh': '缓存地图瓦片', 'zh_TW': '快取地圖圖磚', 'en': 'Cache map tiles',
        'ja': '地図タイルをキャッシュ', 'id': 'Cache ubin peta',
        'es': 'Guardar teselas en caché',
    },
    'offlineCacheSwitchDesc': {
        'zh': '浏览地图时把瓦片存到本机，之后可离线查看',
        'zh_TW': '瀏覽地圖時把圖磚存到本機，之後可離線檢視',
        'en': 'Saves tiles while you browse, so they can be viewed offline later',
        'ja': '地図閲覧時にタイルを端末へ保存し、後でオフライン表示できます',
        'id': 'Simpan ubin saat menjelajah agar bisa dilihat offline nanti',
        'es': 'Guarda las teselas al navegar para verlas luego sin conexión',
    },
    'offlineOnlySwitch': {
        'zh': '仅使用离线瓦片', 'zh_TW': '僅使用離線圖磚',
        'en': 'Offline tiles only', 'ja': 'オフラインタイルのみ',
        'id': 'Hanya ubin offline', 'es': 'Solo teselas sin conexión',
    },
    'offlineOnlySwitchDesc': {
        'zh': '不再从网络加载瓦片，只用已下载/已缓存的图（省流量）',
        'zh_TW': '不再從網路載入圖磚，只用已下載/已快取的圖（省流量）',
        'en': 'Never load tiles from the network — only downloaded/cached ones (saves data)',
        'ja': 'ネットワークからタイルを読み込みません。保存済み/キャッシュのみ使用（通信量節約）',
        'id': 'Tidak memuat ubin dari jaringan — hanya yang terunduh/ter-cache (hemat kuota)',
        'es': 'No carga teselas de la red: solo las descargadas o en caché (ahorra datos)',
    },
    'offlineCacheDisabled': {
        'zh': '瓦片缓存不可用（当前平台不支持）',
        'zh_TW': '圖磚快取無法使用（目前平台不支援）',
        'en': 'Tile cache unavailable on this platform',
        'ja': 'このプラットフォームではタイルキャッシュを利用できません',
        'id': 'Cache ubin tidak tersedia di platform ini',
        'es': 'La caché de teselas no está disponible en esta plataforma',
    },
    'offlineSwitchFirst': {
        'zh': '请先打开「缓存地图瓦片」',
        'zh_TW': '請先開啟「快取地圖圖磚」',
        'en': 'Turn on "Cache map tiles" first',
        'ja': '先に「地図タイルをキャッシュ」をオンにしてください',
        'id': 'Aktifkan "Cache ubin peta" dulu',
        'es': 'Active primero "Guardar teselas en caché"',
    },
    'offlineOnlyWarn': {
        'zh': '已开启「仅使用离线瓦片」，地图可能显示不全',
        'zh_TW': '已開啟「僅使用離線圖磚」，地圖可能顯示不全',
        'en': '"Offline tiles only" is on — parts of the map may be missing',
        'ja': '「オフラインタイルのみ」がオンです。地図が一部表示されない場合があります',
        'id': '"Hanya ubin offline" aktif — sebagian peta mungkin tidak tampil',
        'es': '"Solo teselas sin conexión" está activo: puede que falten partes del mapa',
    },
}

# 带占位符的键（元数据由脚本按 zh 文案自动生成）
DATA_PARAM = {
    'offlineTilesDownloaded': {
        'zh': '已下载 {n} 张瓦片', 'zh_TW': '已下載 {n} 張圖磚',
        'en': '{n} tiles downloaded', 'ja': '{n} タイルを保存済み',
        'id': '{n} ubin terunduh', 'es': '{n} teselas descargadas',
    },
    'offlineZoomLevels': {
        'zh': '{min}–{max} 级', 'zh_TW': '{min}–{max} 級',
        'en': 'zoom {min}–{max}', 'ja': 'ズーム {min}–{max}',
        'id': 'zoom {min}–{max}', 'es': 'zoom {min}–{max}',
    },
    'offlineEstimate': {
        'zh': '约 {tiles} 张瓦片 · 约 {size}',
        'zh_TW': '約 {tiles} 張圖磚 · 約 {size}',
        'en': 'about {tiles} tiles · about {size}',
        'ja': '約 {tiles} タイル · 約 {size}',
        'id': 'sekitar {tiles} ubin · sekitar {size}',
        'es': 'unas {tiles} teselas · unos {size}',
    },
    'offlineTooManyTiles': {
        'zh': '范围太大（约 {tiles} 张瓦片），请缩小范围或降低最大层级',
        'zh_TW': '範圍太大（約 {tiles} 張圖磚），請縮小範圍或降低最大層級',
        'en': 'Area too large (about {tiles} tiles) — narrow it or lower the max zoom',
        'ja': '範囲が広すぎます（約 {tiles} タイル）。範囲を狭めるか最大ズームを下げてください',
        'id': 'Area terlalu besar (sekitar {tiles} ubin) — perkecil area atau turunkan zoom maksimum',
        'es': 'Zona demasiado grande (unas {tiles} teselas): reduzca el área o el zoom máximo',
    },
    'offlineDeleteRegionConfirm': {
        'zh': '删除离线区域「{name}」？',
        'zh_TW': '刪除離線區域「{name}」？',
        'en': 'Delete offline area "{name}"?',
        'ja': 'オフラインエリア「{name}」を削除しますか？',
        'id': 'Hapus area offline "{name}"?',
        'es': '¿Eliminar la zona sin conexión "{name}"?',
    },
    'offlineDeleteTileCount': {
        'zh': '将删除约 {n} 张瓦片',
        'zh_TW': '將刪除約 {n} 張圖磚',
        'en': 'About {n} tiles will be deleted',
        'ja': '約 {n} タイルを削除します',
        'id': 'Sekitar {n} ubin akan dihapus',
        'es': 'Se eliminarán unas {n} teselas',
    },
    'offlineDeletingTiles': {
        'zh': '正在删除 {done}/{total}',
        'zh_TW': '正在刪除 {done}/{total}',
        'en': 'Deleting {done}/{total}',
        'ja': '削除中 {done}/{total}',
        'id': 'Menghapus {done}/{total}',
        'es': 'Eliminando {done}/{total}',
    },
    'offlineFailedCount': {
        'zh': '{n} 张失败', 'zh_TW': '{n} 張失敗', 'en': '{n} failed',
        'ja': '{n} 件失敗', 'id': '{n} gagal', 'es': '{n} fallidas',
    },
    'offlineTileProgress': {
        'zh': '{done}/{total} 张', 'zh_TW': '{done}/{total} 張',
        'en': '{done}/{total} tiles', 'ja': '{done}/{total} タイル',
        'id': '{done}/{total} ubin', 'es': '{done}/{total} teselas',
    },
}

LANGS = ['zh', 'zh_TW', 'en', 'ja', 'id', 'es']
ANCHOR = '"mapTypeDesc"'


def placeholders(text):
    """按出现顺序取 zh 文案里的 {name}（去重）"""
    out = []
    for m in re.finditer(r'\{([A-Za-z_][A-Za-z0-9_]*)\}', text):
        if m.group(1) not in out:
            out.append(m.group(1))
    return out


def main():
    allkeys = list(DATA) + list(DATA_PARAM)
    for lang in LANGS:
        path = os.path.join(ROOT, 'lib/l10n/app_%s.arb' % lang)
        text = io.open(path, encoding='utf-8').read()
        lines = text.split('\n')

        # 先删掉旧版本（脚本可重复执行）
        # 注意：元数据的键名是 `"@key"`，只匹配 `"key"` 会漏掉它 ——
        # 于是重跑脚本会留下“孤儿元数据”，ARB 直接变成非法 JSON 结构。
        prefixes = []
        for k in allkeys:
            prefixes.append('"%s"' % k)
            prefixes.append('"@%s"' % k)
        out = []
        skip = None
        for ln in lines:
            st = ln.strip()
            if skip is not None:
                if st == '},' or st == '}':
                    skip = None
                continue
            if any(st.startswith(p) for p in prefixes):
                if st.endswith(': {'):
                    skip = True
                continue
            out.append(ln)
        lines = out

        idx = None
        for i, ln in enumerate(lines):
            if ln.strip().startswith(ANCHOR):
                idx = i
                break
        assert idx is not None, 'anchor not found in %s' % path

        block = []
        for k, v in DATA.items():
            block.append('  "%s": %s,' % (k, json.dumps(v[lang], ensure_ascii=False)))
        for k, v in DATA_PARAM.items():
            block.append('  "%s": %s,' % (k, json.dumps(v[lang], ensure_ascii=False)))
            ph = placeholders(v['zh'])
            assert ph, 'no placeholder in %s' % k
            block.append('  "@%s": {' % k)
            block.append('    "placeholders": {')
            for j, p in enumerate(ph):
                block.append('      "%s": {' % p)
                block.append('        "type": "String"')
                block.append('      }%s' % (',' if j < len(ph) - 1 else ''))
            block.append('    }')
            block.append('  },')
        lines[idx + 1:idx + 1] = block
        io.open(path, 'w', encoding='utf-8').write('\n'.join(lines))

        d = json.loads(io.open(path, encoding='utf-8').read())
        n = len([k for k in d if not k.startswith('@')])
        print('%s ok, %d keys (+%d)' % (path, n, len(allkeys)))


if __name__ == '__main__':
    main()
