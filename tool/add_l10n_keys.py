#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""往 6 个语言加 l10n 键（arb 真源 + 抽象类 + gen-l10n 产物），**幂等**。

## 为什么固化成工具

我（AI）在 1.6.165/166 这两轮里手写了 4 次「往 arb 追加键」的临时脚本，
每次都错在**同一个地方**：追加多个键时只在最后一个处理了逗号 ——

  * 追加 2~3 个键 → 第 1 个键行尾少逗号 → 整个 arb **JSON 语法坏掉**
    （`Expecting ',' delimiter`），而 `check_l10n_sync` 会以「解析失败」报出来。

手写这种「字符串拼 JSON」的活**必然**漂。所以做成工具：以后加键只改下面的 KEYS。

## 用法

    python3 tool/add_l10n_keys.py

改 KEYS 里的内容再跑即可；已存在的键会跳过（幂等），所以可以反复跑。
带占位符的键在 META 里声明（gen-l10n 需要 `@key.placeholders`）。
"""
import io
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LANGS = ['zh', 'zh_TW', 'en', 'ja', 'es', 'id']
IDX = {l: i for i, l in enumerate(LANGS)}
CLASSES = {
    'zh': 'AppLocalizationsZh', 'zh_TW': 'AppLocalizationsZhTw',
    'en': 'AppLocalizationsEn', 'ja': 'AppLocalizationsJa',
    'es': 'AppLocalizationsEs', 'id': 'AppLocalizationsId',
}

# ── 要加的键：key → (zh, zh_TW, en, ja, es, id) ──
KEYS = {
    # ── 云同步：服务器地址（空着用项目自带那台）──
    'syncServer': (
        '服务器', '伺服器', 'Server', 'サーバー', 'Servidor', 'Server'),
    'syncServerNow': (
        '当前地址', '目前位址', 'Address in use', '使用中のアドレス',
        'Dirección en uso', 'Alamat terpakai'),
    'syncServerHint': (
        '换地址要重新登录，旧地址上的数据不搬。',
        '換位址要重新登入，舊位址上的資料不搬。',
        'Changing it signs you out. Nothing moves over from the old server.',
        'アドレスを変えると再ログインになります。前のサーバーのデータは移りません。',
        'Cambiar la dirección cierra la sesión. Los datos del servidor anterior no se mueven.',
        'Ganti alamat berarti login ulang. Data di server lama tidak ikut pindah.'),
    'syncCloudData': (
        '云端数据', '雲端資料', 'On the server', 'サーバー上のデータ',
        'Datos en el servidor', 'Data di server'),
    'syncAccountHint': (
        '账号就是服务器接入名单里那条，与「APRSNETCN」链路页填的是同一个。',
        '帳號就是伺服器接入名單裡那條，與「APRSNETCN」鏈路頁填的是同一個。',
        "The account is the one on the server's access list, the same one the APRSNETCN link page uses.",
        'アカウントはサーバーの許可リストにあるもの。APRSNETCN リンクのページと同じです。',
        'La cuenta es la de la lista de acceso del servidor, la misma que usa la página de la conexión APRSNETCN.',
        'Akun adalah yang ada di daftar akses server, sama dengan yang dipakai halaman tautan APRSNETCN.'),
    # ── 云同步：消息 / 云端备份 / 历史轨迹（账号就是名单里那条）──
    'syncTitle': (
        '云同步', '雲端同步', 'Cloud sync', 'クラウド同期',
        'Sincronización', 'Sinkron awan'),
    'syncLead': (
        '消息与历史轨迹存到服务器上，换设备再拉回来。',
        '訊息與歷史軌跡存到伺服器上，換裝置再拉回來。',
        'Messages and track history live on the server, ready when you change devices.',
        'メッセージと履歴はサーバーに置かれ、端末を替えても戻せます。',
        'Los mensajes y el historial se guardan en el servidor y vuelven al cambiar de equipo.',
        'Pesan dan riwayat tersimpan di server dan kembali saat ganti perangkat.'),
    'syncAccount': (
        '账号', '帳號', 'Account', 'アカウント', 'Cuenta', 'Akun'),
    'syncPassword': (
        '口令', '口令', 'Password', 'パスワード', 'Contraseña', 'Kata sandi'),
    'syncLogin': (
        '登录', '登入', 'Sign in', 'ログイン', 'Entrar', 'Masuk'),
    'syncLogout': (
        '退出登录', '登出', 'Sign out', 'ログアウト', 'Salir', 'Keluar'),
    'syncLoggedIn': (
        '已登录 {call}', '已登入 {call}', 'Signed in as {call}',
        '{call} でログイン中', 'Sesión de {call}', 'Masuk sebagai {call}'),
    'syncNeedLogin': (
        '先登录', '請先登入', 'Sign in first', '先にログイン',
        'Inicia sesión primero', 'Masuk dulu'),
    'syncMode': (
        '同步方式', '同步方式', 'Mode', '同期方法', 'Modo', 'Mode'),
    'syncModeOff': (
        '关闭', '關閉', 'Off', 'オフ', 'Apagado', 'Mati'),
    'syncModeManual': (
        '手动', '手動', 'Manual', '手動', 'Manual', 'Manual'),
    'syncModeAuto': (
        '自动', '自動', 'Auto', '自動', 'Automático', 'Otomatis'),
    'syncModeAutoHint': (
        '自动：启动时拉一次，之后每 5 分钟一轮。',
        '自動：啟動時拉一次，之後每 5 分鐘一輪。',
        'Auto: once at startup, then every five minutes.',
        '自動：起動時に一度、その後 5 分ごと。',
        'Automático: una vez al arrancar y luego cada cinco minutos.',
        'Otomatis: sekali saat mulai, lalu tiap lima menit.'),
    'syncMessages': (
        '消息', '訊息', 'Messages', 'メッセージ', 'Mensajes', 'Pesan'),
    'syncTracks': (
        '历史轨迹', '歷史軌跡', 'Track history', '履歴', 'Historial', 'Riwayat'),
    'syncNow': (
        '立即同步', '立即同步', 'Sync now', '今すぐ同期', 'Sincronizar',
        'Sinkron sekarang'),
    'syncRunDone': (
        '同步完成', '同步完成', 'Synced', '同期しました', 'Sincronizado',
        'Tersinkron'),
    'syncClear': (
        '清空云端数据', '清空雲端資料', 'Clear cloud data', 'クラウドのデータを消す',
        'Borrar datos en la nube', 'Hapus data awan'),
    'syncClearHint': (
        '服务器上这个呼号的消息、轨迹、备份一起删掉，本机不动。',
        '伺服器上這個呼號的訊息、軌跡、備份一起刪掉，本機不動。',
        "Removes this callsign's messages, tracks and backups from the server. Nothing on this device changes.",
        'サーバー上のこのコールサインのメッセージ・履歴・バックアップを消します。端末側は変わりません。',
        'Borra del servidor los mensajes, el historial y las copias de este indicativo. En el equipo no cambia nada.',
        'Menghapus pesan, riwayat, dan cadangan callsign ini di server. Di perangkat tidak berubah.'),
    'syncClearAsk': (
        '确认清空云端数据？', '確認清空雲端資料？', 'Clear the cloud data?',
        'クラウドのデータを消しますか？', '¿Borrar los datos en la nube?',
        'Hapus data awan?'),
    'syncClearDone': (
        '云端数据已清空', '雲端資料已清空', 'Cloud data cleared',
        'クラウドのデータを消しました', 'Datos en la nube borrados',
        'Data awan dihapus'),
    'syncPlainHint': (
        '连接是明文 HTTP，口令与内容不加密。',
        '連線是明文 HTTP，口令與內容不加密。',
        'The connection is plain HTTP, so passwords and content are not encrypted.',
        '接続は平文 HTTP です。パスワードも内容も暗号化されません。',
        'La conexión es HTTP sin cifrar; la contraseña y el contenido no van cifrados.',
        'Koneksi memakai HTTP biasa, kata sandi dan isi tidak dienkripsi.'),
    'syncLastAt': (
        '上次同步', '上次同步', 'Last sync', '前回の同期', 'Última sincronización',
        'Sinkron terakhir'),
    'syncNever': (
        '还没同步过', '還沒同步過', 'Never synced', 'まだ同期していません',
        'Aún no se ha sincronizado', 'Belum pernah sinkron'),
    'syncFailed': (
        '同步失败', '同步失敗', 'Sync failed', '同期に失敗しました',
        'Error de sincronización', 'Gagal sinkron'),
    'syncTrackSummary': (
        '{days} 天 · {points} 个点', '{days} 天 · {points} 個點',
        '{days} days · {points} points', '{days} 日 · {points} 点',
        '{days} días · {points} puntos', '{days} hari · {points} titik'),
    'syncMsgSummary': (
        '{n} 条', '{n} 條', '{n} messages', '{n} 件', '{n} mensajes', '{n} pesan'),
    'syncBackupElsewhere': (
        '云端备份在「备份与恢复」页里上传与取回。',
        '雲端備份在「備份與還原」頁裡上傳與取回。',
        'Cloud backups are uploaded and restored from the backup page.',
        'クラウドバックアップは「バックアップと復元」ページで扱います。',
        'Las copias en la nube se suben y se recuperan en la página de copias.',
        'Cadangan awan diunggah dan dipulihkan dari halaman cadangan.'),
    'syncNoWeb': (
        '网页版不能用', '網頁版不能用', 'Not available on the web',
        'ウェブ版では使えません', 'No disponible en la web', 'Tidak tersedia di web'),
    'syncBusy': (
        '正在同步', '正在同步', 'Syncing', '同期中', 'Sincronizando', 'Sedang sinkron'),
    # ── 备份页的云端两格 ──
    'backupCloud': (
        '云端备份', '雲端備份', 'Cloud backup', 'クラウドバックアップ',
        'Copia en la nube', 'Cadangan awan'),
    'backupCloudUpload': (
        '存到云端', '存到雲端', 'Upload', 'クラウドに保存', 'Subir', 'Unggah'),
    'backupCloudRestore': (
        '从云端取回', '從雲端取回', 'Restore from cloud', 'クラウドから戻す',
        'Recuperar', 'Pulihkan'),
    'backupCloudHint': (
        '云端备份不带历史轨迹，轨迹在「云同步」里单独存。',
        '雲端備份不帶歷史軌跡，軌跡在「雲端同步」裡單獨存。',
        'Cloud backups leave out track history; tracks are kept by cloud sync.',
        'クラウドバックアップに履歴は含みません。履歴はクラウド同期が別に保存します。',
        'Las copias en la nube no incluyen el historial; la sincronización lo guarda aparte.',
        'Cadangan awan tanpa riwayat; riwayat disimpan terpisah oleh sinkron awan.'),
    'backupCloudDone': (
        '已存到云端', '已存到雲端', 'Uploaded', 'クラウドに保存しました',
        'Subido', 'Terunggah'),
    'backupCloudEmpty': (
        '云端还没有备份', '雲端還沒有備份', 'No backups in the cloud yet',
        'クラウドにまだバックアップがありません', 'Aún no hay copias en la nube',
        'Belum ada cadangan di awan'),
    'backupCloudFailed': (
        '云端操作失败', '雲端操作失敗', 'Cloud operation failed',
        'クラウド操作に失敗しました', 'Error en la operación en la nube',
        'Operasi awan gagal'),
    # ── 省电模式（GPS 采样拉长 + 地图动画停下）与低电量提醒 ──
    'powerSave': (
        '省电模式', '省電模式', 'Power saving', '省電力モード',
        'Ahorro de energía', 'Hemat daya'),
    'powerSaveTip': (
        'GPS 每 30 秒取一次位置，地图上的台站动画停下。',
        'GPS 每 30 秒取一次位置，地圖上的臺站動畫停下。',
        'GPS updates every 30 seconds and station animations stop.',
        'GPS は 30 秒ごと、地図上の局のアニメーションも停止します。',
        'El GPS toma una posición cada 30 s y las animaciones del mapa se detienen.',
        'GPS mengambil posisi tiap 30 detik dan animasi peta berhenti.'),
    'lowBatteryWarn': (
        '电量只剩 {level}%，开省电模式？', '電量只剩 {level}%，開省電模式？',
        'Battery at {level}%. Turn on power saving?',
        'バッテリー残量 {level}%。省電力モードにしますか？',
        'Batería al {level}%. ¿Activar el ahorro de energía?',
        'Baterai {level}%. Aktifkan hemat daya?'),
    # ── 历史轨迹叠层：所有天画在同一张图上，可导图 / 分享 ──
    'historyOverlay': (
        '历史叠层', '歷史疊層', 'Track overlay', '履歴の重ね表示',
        'Capas de rutas', 'Lapisan riwayat'),
    'historyOverlayShare': (
        '分享图片', '分享圖片', 'Share image', '画像を共有',
        'Compartir imagen', 'Bagikan gambar'),
    'historyOverlayExport': (
        '导出图片', '匯出圖片', 'Export image', '画像を書き出す',
        'Exportar imagen', 'Ekspor gambar'),
    'historyOverlayExportFailed': (
        '导出图片失败', '匯出圖片失敗', 'Could not export the image',
        '画像を書き出せませんでした', 'No se pudo exportar la imagen',
        'Gagal mengekspor gambar'),
    'historyOverlayEmpty': (
        '还没有可叠加的轨迹。', '還沒有可疊加的軌跡。', 'No tracks to overlay yet.',
        '重ねて表示できる履歴がまだありません。', 'Aún no hay rutas que superponer.',
        'Belum ada lintasan untuk dilapis.'),
    'historyOverlayAll': (
        '全部显示', '全部顯示', 'Show all', 'すべて表示', 'Mostrar todo',
        'Tampilkan semua'),
    'historyOverlaySummary': (
        '{days}/{total} 天 · {km}', '{days}/{total} 天 · {km}',
        '{days}/{total} days · {km}', '{days}/{total} 日 · {km}',
        '{days}/{total} días · {km}', '{days}/{total} hari · {km}'),
    # ── 设备面板：位置/消息逐条挑还是位置全发 ──
    'advChannels': (
        '高级连接通道设置', '高階連線通道設定', 'Per-link sending',
        '送信先の詳細設定', 'Envío por enlace', 'Pengaturan kirim lanjutan'),
    # ── 首次引导：服务器那一步给一个大按钮明说可以跳过 ──
    #
    # 留空 = 纯本地，规则早就有，但底部那颗「下一步」长得像「必须填完才
    # 能过」，重跑向导的人会卡在这里。
    'oobeServerSkip': (
        '跳过，稍后在设置里填', '跳過，稍後在設定裡填',
        'Skip, set it later in settings', 'スキップ（あとで設定に入力）',
        'Saltar, lo pongo luego en ajustes', 'Lewati, isi nanti di pengaturan'),
    # ── 经纬度显示格式：十进制度 / 度分 / 度分秒 ──
    #
    # 只换给人看的字符串（地图底部读数、「我的」面板、台站详情、沉浸页、
    # 选点提示）。报文与所有计算仍用十进制度。
    'coordFormat': (
        '经纬度格式', '經緯度格式', 'Coordinate format', '緯度経度の書式',
        'Formato de coordenadas', 'Format koordinat'),
    'coordFormatDec': (
        '十进制度', '十進制度', 'Decimal', '十進度', 'Decimal', 'Desimal'),
    'coordFormatDm': (
        '度分', '度分', 'Deg-min', '度分', 'Grados y min', 'Derajat-menit'),
    'coordFormatDms': (
        '度分秒', '度分秒', 'Deg-min-sec', '度分秒', 'Grados-min-seg',
        'Derajat-menit-detik'),
    # ── 屏幕正中的经纬度读数（设置 → 显示 → 地图）──
    'mapCenterCoord': (
        '中心经纬度', '中心經緯度', 'Centre coordinates', '中心の緯度経度',
        'Coordenadas del centro', 'Koordinat tengah'),
    # ── 翻译接口：B 站 Index-Translate ──
    #
    # OpenAI 规范的公共接口，免密钥。中文语料上比网页端点稳，但不保证可用性。
    'translateProviderBili': (
        'B站 Index-Translate', 'B 站 Index-Translate', 'Bilibili Index-Translate',
        'Bilibili Index-Translate', 'Bilibili Index-Translate',
        'Bilibili Index-Translate'),
    'translateProviderBiliDesc': (
        '免密钥，免费。B 站公开的翻译模型，公共接口不保证一直可用。',
        '免金鑰，免費。B 站公開的翻譯模型，公共介面不保證一直可用。',
        "No key, no cost. Bilibili's public translation model; a free endpoint with no guarantee.",
        'キー不要で無料。Bilibili が公開している翻訳モデル。公共の窓口なので可用性は保証されません。',
        'Sin clave y gratis. Modelo público de traducción de Bilibili; sin garantía de disponibilidad.',
        'Tanpa kunci, gratis. Model terjemahan publik Bilibili; ketersediaannya tidak dijamin.'),
    'translateBiliUrl': (
        '接口地址', '介面位址', 'Endpoint', 'エンドポイント', 'Endpoint', 'Endpoint'),
    'translateBiliModel': (
        '模型', '模型', 'Model', 'モデル', 'Modelo', 'Model'),
    # ── 两条互联网链路：每张卡上一个「用这条链路发送」 ──
    'acnPasscodeHint': (
        '留空就用 APRS-IS 那条链路的 passcode',
        '留空就用 APRS-IS 那條鏈路的 passcode',
        "Leave it empty to use the APRS-IS link's passcode",
        '空欄なら APRS-IS 側の passcode を使います',
        'Déjalo vacío para usar el passcode del enlace APRS-IS',
        'Kosongkan untuk memakai passcode tautan APRS-IS'),
    'txSourcePick': (
        '用这条链路发送', '用這條鏈路發送', 'Send on this link',
        'この回線で送信', 'Enviar por este enlace', 'Kirim lewat tautan ini'),
    'translateBiliTip': (
        '公共接口可能限流。自己部署时把地址和模型换成自己的。',
        '公共介面可能限流。自己部署時把位址和模型換成自己的。',
        'The public endpoint may rate-limit. Point the address and model at your own deployment if you run one.',
        '公共の窓口は制限がかかる場合があります。自前で立てる場合はアドレスとモデルを差し替えてください。',
        'El punto público puede limitar el uso. Si tienes tu propio despliegue, pon ahí la dirección y el modelo.',
        'Endpoint publik bisa membatasi permintaan. Kalau kamu punya deployment sendiri, isi alamat dan model itu.'),
    # ── 实时更新胶囊里可选的读数（多出来的那几档） ──
    #
    # 胶囊只有一行 ≤7 字符，所以标签只写「显示的是什么数」，单位写在下面对。
    'notifLiveTextMsgs': (
        '未读消息', '未讀訊息', 'Unread messages', '未読メッセージ',
        'Mensajes sin leer', 'Pesan belum dibaca'),
    'notifLiveTextNear': (
        '附近台站', '附近臺站', 'Nearby stations', '近くの局',
        'Estaciones cercanas', 'Stasiun sekitar'),
    'notifLiveTextSpeed': (
        '速度', '速度', 'Speed', '速度', 'Velocidad', 'Kecepatan'),
    'notifLiveTextAlt': (
        '高度', '高度', 'Altitude', '高度', 'Altitud', 'Ketinggian'),
    'notifLiveTextHr': (
        '心率', '心率', 'Heart rate', '心拍数', 'Frecuencia cardíaca', 'Detak jantung'),
    'notifLiveTextBatt': (
        '电量', '電量', 'Battery', 'バッテリー', 'Batería', 'Baterai'),
    'notifLiveTextTrip': (
        '本次里程', '本次里程', 'Trip distance', '今回の走行距離',
        'Distancia del viaje', 'Jarak perjalanan'),
    # 附近台站那个数是**带单位**的（台/局/est…），单位只能跟着语言走
    'notifLiveNearShort': (
        '{n} 台', '{n} 臺', '{n} stn', '{n} 局', '{n} est', '{n} stn'),
    # ── 历史轨迹：记录开关（默认关）──
    'historyRecord': (
        '记录历史轨迹', '記錄歷史軌跡', 'Track history', '履歴を記録',
        'Registrar historial', 'Rekam riwayat'),
    'historyEmptyOff': (
        '记录没开。打开上面的开关才会记。',
        '記錄沒開。打開上面的開關才會記。',
        'Recording is off. Turn it on above to start.',
        '記録は切っています。上のスイッチを入れると記録します。',
        'La grabación está desactivada. Actívala arriba para empezar.',
        'Perekaman mati. Nyalakan sakelar di atas untuk mulai.'),
    # 开发人员里那一行操作证书查询的标签：功能先关着，位置留着
    'cracCertClosed': (
        '暂不开放', '暫不開放', 'Not open yet', '未公開',
        'Aún no disponible', 'Belum dibuka'),
    # 电台页的入口 + 那一页的三条说明
    'cracCertEntry': (
        '操作证验证', '操作證驗證', 'Licence check', '操作資格の確認',
        'Verificación de licencia', 'Pemeriksaan lisensi'),
    'cracCertVoluntary': (
        '验证自愿，不验证也能照常用。',
        '驗證自願，不驗證也能照常用。',
        'Verification is voluntary. The app works the same without it.',
        '認証は任意です。しなくても同じように使えます。',
        'La verificación es voluntaria. La app funciona igual sin ella.',
        'Verifikasi bersifat sukarela. Aplikasi tetap berjalan sama tanpanya.'),
    'cracCertLocal': (
        '查询由程序直接完成，没有人工审核。结果只回本机，只保留是否通过和证书类别。',
        '查詢由程式直接完成，沒有任何人工作業。結果只回本機，只保留是否通過和證書類別。',
        'The check runs by program, with no human review. The result comes back to this device only, '
        'and keeps just the pass and the licence class.',
        '照合はプログラムが行い、人手の審査はありません。結果はこの端末にだけ戻り、通過と資格クラスだけを残します。',
        'La comprobación la hace el programa, sin revisión humana. El resultado vuelve solo a este '
        'dispositivo y guarda únicamente si pasó y la clase.',
        'Pemeriksaan dijalankan oleh program, tanpa tinjauan manusia. Hasilnya kembali hanya ke '
        'perangkat ini, berisi lulus dan kelas lisensi saja.'),
    # 认证页面里那句「为什么要有这一步」—— 用户给的原话
    'cracCertWhyRequired': (
        'APRS-IS 协议 软件开发者有责任与义务验证软件使用者为业余无线电爱好者',
        'APRS-IS 協議 軟體開發者有責任與義務驗證軟體使用者為業餘無線電愛好者',
        'The APRS-IS protocol puts the duty on the software developer to verify that users are amateur radio operators.',
        'APRS-IS プロトコルでは、利用者がアマチュア無線家であることを確認する責任と義務がソフトウェア開発者にあります。',
        'El protocolo APRS-IS pone en el desarrollador del software el deber de verificar que los usuarios sean radioaficionados.',
        'Protokol APRS-IS menetapkan kewajiban pengembang perangkat lunak untuk memastikan pengguna adalah penggemar radio amatir.'),
    # ── 首次引导：没填地址时最后一步不叫「完成并连接」 ──
    'oobeFinishLocal': (
        '完成', '完成', 'Finish', '完了', 'Terminar', 'Selesai'),
    # ── 首次引导：最后一步「配置完成」 ──
    'oobeDoneTitle': (
        '配置完成', '設定完成', 'All set', '設定できました',
        'Configuración lista', 'Pengaturan selesai'),
    'oobeDoneLocalNote': (
        '地址留空，现在是纯本地模式。要联网去设置里的服务器。',
        '位址留空，現在是純本機模式。要連網去設定裡的伺服器。',
        'No address, so the app stays local. Fill in a server in settings when you want to go online.',
        'アドレス未入力なので、いまはローカルだけで動きます。オンラインにするときは設定のサーバーに入力してください。',
        'Sin dirección, la app funciona solo en local. Para conectarte, pon un servidor en ajustes.',
        'Alamat masih kosong, jadi aplikasi jalan lokal saja. Isi server di pengaturan kalau mau online.'),
    'oobeDoneConnectNote': (
        '点完成后会连接 {link}。',
        '點完成後會連線 {link}。',
        'Finishing will connect to {link}.',
        '「完了」を押すと {link} に接続します。',
        'Al terminar se conectará a {link}.',
        'Setelah selesai, aplikasi menyambung ke {link}.'),
    'oobeDoneSymbolLabel': (
        '符号', '符號', 'Symbol', 'シンボル', 'Símbolo', 'Simbol'),
    'oobeDoneUnset': (
        '未填', '未填', 'Empty', '未入力', 'Sin rellenar', 'Kosong'),
    'oobeDoneMap': (
        '看台站', '看臺站', 'Stations', '局を見る', 'Estaciones', 'Stasiun'),
    'oobeDoneMapDesc': (
        '地图和台站两个页签里是附近的台站。',
        '地圖和臺站兩個頁籤裡是附近的臺站。',
        'Neighbouring stations are on the map and stations tabs.',
        '近くの局は地図と局のタブに出ます。',
        'Las estaciones cercanas están en las pestañas de mapa y estaciones.',
        'Stasiun sekitar ada di tab peta dan stasiun.'),
    'oobeDoneBeacon': (
        '发位置', '發位置', 'Send a beacon', '位置を送る', 'Enviar baliza',
        'Kirim posisi'),
    'oobeDoneBeaconDesc': (
        '连上之后，地图页底部有开始上报的按钮。',
        '連上之後，地圖頁底部有開始上報的按鈕。',
        'Once connected, the start button sits at the bottom of the map page.',
        '接続すると、地図ページの下に開始ボタンが出ます。',
        'Al conectar, el botón de inicio aparece abajo en la página del mapa.',
        'Setelah tersambung, tombol mulai ada di bawah halaman peta.'),
    'oobeDoneManualDesc': (
        '设置里有使用手册。设备怎么接、发不出去怎么查都写在里面。',
        '設定裡有使用手冊。裝置怎麼接、發不出去怎麼查都寫在裡面。',
        'Settings has the manual. It covers hooking up a radio and what to check when sending fails.',
        '設定にマニュアルがあります。無線機のつなぎ方や送れないときの調べ方が書いてあります。',
        'En ajustes está el manual. Explica cómo conectar un equipo y qué revisar cuando no se envía.',
        'Panduan ada di pengaturan. Isinya cara menyambung perangkat dan apa yang dicek saat gagal kirim.'),
    # ── 首次引导：呼号形状校验 ──
    'oobeCallInvalid': (
        '呼号格式不对。常见的写法是 BG7LZQ 或 JA1AA。',
        '呼號格式不對。常見的寫法是 BG7LZQ 或 JA1AA。',
        'That callsign does not look right. Common forms are BG7LZQ or JA1AA.',
        'コールサインの形式が正しくありません。例：BG7LZQ、JA1AA。',
        'Ese indicativo no parece correcto. Formatos habituales: BG7LZQ o JA1AA.',
        'Tanda panggil itu sepertinya tidak tepat. Bentuk umum: BG7LZQ atau JA1AA.'),
    'oobeSsidInvalid': (
        '后缀只能是一位或两位数字、字母。',
        '後綴只能是一位或兩位數字、字母。',
        'The SSID can be one or two letters or digits.',
        'SSID は数字か英字の 1〜2 文字です。',
        'El SSID puede ser una o dos letras o cifras.',
        'SSID hanya boleh satu atau dua huruf atau angka.'),
    # ── 首次引导：功能（自选模块）那一步 ──
    #
    # 用户在待办里说「OOBE 阶段增加功能设置，涵盖历史轨迹和其他功能」：
    # 装完就想把不要的模块关掉，不必先跑到设置里翻。
    'oobeFeatureTitle': (
        '要哪些功能', '要哪些功能', 'Which extras do you want',
        '使う機能', 'Qué extras quieres', 'Fitur mana yang dipakai'),
    'oobeFeatureDesc': (
        '关掉的模块不会出现在设置里。以后想改，设置 → 功能。',
        '關掉的模組不會出現在設定裡。以後想改，設定 → 功能。',
        'A module you turn off leaves the settings page. Change it later in Settings → Features.',
        'オフにしたモジュールは設定に出てきません。あとから「設定 → 機能」で変えられます。',
        'Un módulo apagado desaparece de los ajustes. Puedes cambiarlo en Ajustes → Funciones.',
        'Modul yang dimatikan hilang dari pengaturan. Ubah nanti di Pengaturan → Fitur'),
    # ── 关于页的代码贡献：BG7PFE 的 UTF-8 / GBK 自动识别（PR #38）──
    'codeContributionEncoding': (
        '中文编码兼容', '中文編碼相容', 'Chinese text encoding',
        '中国語エンコード', 'Codificación china', 'Encoding Tionghoa'),
    # ── 云同步：同步哪些东西、设备、云端备份 ──
    'syncContent': (
        '同步内容', '同步內容', 'What syncs', '同期する内容',
        'Qué se sincroniza', 'Yang disinkronkan'),
    'syncContentHint': (
        '两个都关掉就只登录，不传也不收。',
        '兩個都關掉就只登入，不傳也不收。',
        'Turn both off and sync only signs in. Nothing is sent or pulled.',
        '両方オフにするとログインだけになり、送受信しません。',
        'Con ambos apagados solo se inicia sesión, sin enviar ni traer nada.',
        'Kalau keduanya mati, sinkron hanya login, tanpa kirim atau tarik apa pun.'),
    'syncAutoEvery': (
        '自动同步间隔', '自動同步間隔', 'Auto sync every', '自動同期の間隔',
        'Sincronizar cada', 'Sinkron otomatis tiap'),
    'syncEveryMin': (
        '{n} 分钟', '{n} 分鐘', '{n} min', '{n} 分', '{n} min', '{n} menit'),
    'syncDevicesTitle': (
        '登录的设备', '登入的裝置', 'Signed-in devices', 'ログイン中の端末',
        'Dispositivos con sesión', 'Perangkat yang login'),
    'syncDeviceThis': (
        '本机', '本機', 'This device', 'この端末', 'Este dispositivo', 'Perangkat ini'),
    'syncDeviceRemove': (
        '移除', '移除', 'Remove', '削除', 'Quitar', 'Hapus'),
    'syncDeviceRemoved': (
        '这台设备已移除，它下次同步要重新登录。',
        '這台裝置已移除，它下次同步要重新登入。',
        'Removed. That device has to sign in again on its next sync.',
        '削除しました。次回の同期には再ログインが必要です。',
        'Eliminado. Ese dispositivo tendrá que iniciar sesión otra vez.',
        'Dihapus. Perangkat itu perlu login lagi saat sinkron berikutnya.'),
    'syncBackups': (
        '云端备份', '雲端備份', 'Cloud backups', 'クラウドのバックアップ',
        'Copias en la nube', 'Cadangan di awan'),
    'syncBackupsCount': (
        '共 {n} 份', '共 {n} 份', '{n} in total', '計 {n} 件', '{n} en total',
        '{n} total'),
    'syncDeviceHint': (
        '列表里是登录过这台服务器的设备。移除一台，它下次同步要重新登录。',
        '列表裡是登入過這台伺服器的裝置。移除一台，它下次同步要重新登入。',
        'These are the devices signed in to this server. Remove one and it has to sign in again on its next sync.',
        'このサーバーにログインした端末の一覧です。削除した端末は次回の同期で再ログインが必要です。',
        'Estos son los dispositivos con sesión en este servidor. Si quitas uno, tendrá que iniciar sesión otra vez.',
        'Ini perangkat yang login ke server ini. Kalau dihapus, perangkat itu perlu login lagi saat sinkron berikutnya.'),
}

META = {
    'syncEveryMin': '{"placeholders": {"n": {"type": "String"}}}',
    'syncBackupsCount': '{"placeholders": {"n": {"type": "String"}}}',
    'syncLoggedIn': '{"placeholders": {"call": {"type": "String"}}}',
    'syncTrackSummary':
        '{"placeholders": {"days": {"type": "String"}, "points": {"type": "String"}}}',
    'syncMsgSummary': '{"placeholders": {"n": {"type": "String"}}}',
    'lowBatteryWarn': '{"placeholders": {"level": {"type": "String"}}}',
    'historyOverlaySummary':
        '{"placeholders": {"days": {"type": "String"}, "total": {"type": "String"}, "km": {"type": "String"}}}',
    'oobeDoneConnectNote': '{"placeholders": {"link": {"type": "String"}}}',
    'notifLiveNearShort': '{"placeholders": {"n": {"type": "String"}}}',
    'acnServerRetention': '{"placeholders": {"hours": {"type": "String"}}}',
    'acnSyncDone': '{"placeholders": {"total": {"type": "String"}, "added": {"type": "String"}}}',
    'gpxExported': '{"placeholders": {"days": {"type": "String"}, "points": {"type": "String"}}}',
    'gpxSavedTo': '{"placeholders": {"path": {"type": "String"}}}',
    'audioTxNotSourceWarn': '{"placeholders": {"src": {"type": "String"}}}',
    'prunePreview': '{"placeholders": {"n": {"type": "String"}}}',
    'pruneConfirm': '{"placeholders": {"n": {"type": "String"}, "m": {"type": "String"}}}',
    'pruneDone': '{"placeholders": {"n": {"type": "String"}}}',
    'beaconCoarseForced': '{"placeholders": {"s": {"type": "String"}}}',
    'txNoFixKeptStatus': '{"placeholders": {"parts": {"type": "String"}}}',
    'connStatusSent': '{"placeholders": {"call": {"type": "String"}}}',
    'connTncStatusSent': '{"placeholders": {"arg": {"type": "String"}}}',
    'connAudioStatusSent': '{"placeholders": {"call": {"type": "String"}}}',
    'nDays': '{"placeholders": {"n": {"type": "String"}}}',
    'strategyTeammateOf': '{"placeholders": {"call": {"type": "String"}}}',
    'strategyUpdatedItem':
        '{"placeholders": {"call": {"type": "String"}, "kind": {"type": "String"}}}',
    'strategyDeletedItem':
        '{"placeholders": {"call": {"type": "String"}, "kind": {"type": "String"}}}',
    'strategyClearedMsg': '{"placeholders": {"call": {"type": "String"}}}',
    'strategySharedItem':
        '{"placeholders": {"call": {"type": "String"}, "kind": {"type": "String"}}}',
    'strategyAckPending': '{"placeholders": {"n": {"type": "int"}}}',
    'locationSendTo': '{"placeholders": {"call": {"type": "String"}}}',
    'locationPageInfo':
        '{"placeholders": {"n": {"type": "String"}, "m": {"type": "String"}}}',
    'shareStationSent': '{"placeholders": {"call": {"type": "String"}}}',
}


def _params(key):
    """从 META 里抠出这个键的占位符名字。"""
    raw = META.get(key)
    if not raw:
        return []
    try:
        return list(json.loads(raw).get('placeholders', {}).keys())
    except Exception:
        return []


def member(key):
    """产出的成员签名：无占位符 → `get key`；有 → `key(String a, String b)`。

    ⚠ 这是一处真实缺陷的修法（v1.6.177）：本函数以前一律写 getter，于是带占位符
    的键被写成 `String get x => "... {s}";` —— **本机** `S.of(context).x(y)` 报
    not_a_function，而 CI 的 `pub get` 会按 arb 重新生成产物，于是 CI 全绿、
    问题被盖住（正是本仓库最熟悉的「我这儿有错、CI 却是绿的」）。
    产物必须与 gen-l10n 同形：带占位符就是**带参数的方法**。
    """
    ps = _params(key)
    if not ps:
        return 'get %s' % key
    return '%s(%s)' % (key, ', '.join('String ' + x for x in ps))


def interp(key, text):
    """把 `{x}` 换成 Dart 插值 `$x`（与 gen-l10n 的产物一致）。"""
    for x in _params(key):
        text = text.replace('{%s}' % x, '$%s' % x)
    return text


def class_body(src, name):
    m = re.search(r'(?m)^(?:abstract )?class ' + re.escape(name) + r'\b', src)
    if not m:
        raise SystemExit('找不到类 ' + name)
    j = src.find('\n}\n', m.end())
    if j < 0:
        j = src.rfind('\n}')
    return m.end(), j


def add_lines(text, lines):
    """把若干 `  "key": value` 行插到顶层 } 之前。

    ⚠ 逗号规则是这里唯一的坑：插入的每一行**之间**都要有逗号，
    而**最后一行后面不能有**（紧接着就是 }）。
    """
    if not lines:
        return text
    i = text.rstrip().rfind('}')
    head = text[:i].rstrip()
    if head.endswith(','):
        head = head[:-1]          # 去掉原末尾逗号，最后统一按需补
    body = ',\n'.join(l.rstrip().rstrip(',') for l in lines)
    return head + ',\n' + body + '\n' + text[i:]


def main() -> int:
    if not KEYS:
        print('KEYS 是空的 —— 请先在脚本里填要加的键')
        return 0
    for lg in LANGS:
        p = os.path.join(ROOT, 'lib', 'l10n', 'app_%s.arb' % lg)
        t = io.open(p, encoding='utf-8', newline='').read()
        add = []
        for k, v in KEYS.items():
            if '"%s":' % k in t:
                continue
            add.append('  %s: %s' % (json.dumps(k, ensure_ascii=False),
                                     json.dumps(v[IDX[lg]], ensure_ascii=False)))
        for k, m in META.items():
            if '"@%s":' % k in t:
                continue
            add.append('  %s: %s' % (json.dumps('@' + k, ensure_ascii=False), m))
        if add:
            t = add_lines(t, add)
            io.open(p, 'w', encoding='utf-8', newline='').write(t)
        # 立刻验 JSON：拼错了就在这里炸，不要留到 check 脚本里才发现
        try:
            json.load(io.open(p, encoding='utf-8'))
        except Exception as e:
            print('%s arb 拼坏了: %s' % (lg, e))
            return 1
        print('%s arb ok（新增 %d 行）' % (lg, len(add)))

    # 抽象类
    p = os.path.join(ROOT, 'lib', 'l10n', 'app_localizations.dart')
    s = io.open(p, encoding='utf-8').read()
    code = []
    for k, v in KEYS.items():
        if re.search(r'String (?:get )?%s\b' % k, s):
            continue
        code.append("  /// No description provided for @%s.\n  ///\n"
                    "  /// In zh, this message translates to:\n  /// **'%s'**\n"
                    "  String %s;\n" % (k, v[0], member(k)))
    if code:
        _, j = class_body(s, 'AppLocalizations')
        s = s[:j] + '\n' + '\n'.join(code) + s[j:]
        io.open(p, 'w', encoding='utf-8').write(s)
    print('抽象类 +%d' % len(code))

    # 各语言实现
    for lg in LANGS:
        fn = ('app_localizations_zh.dart' if lg in ('zh', 'zh_TW')
              else 'app_localizations_%s.dart' % lg)
        p = os.path.join(ROOT, 'lib', 'l10n', fn)
        s = io.open(p, encoding='utf-8').read()
        b0, b1 = class_body(s, CLASSES[lg])
        code = []
        for k, v in KEYS.items():
            if re.search(r'String (?:get )?%s\b' % k, s[b0:b1]):
                continue
            code.append('  @override\n  String %s => %s;\n'
                        % (member(k),
                           json.dumps(interp(k, v[IDX[lg]]), ensure_ascii=False)))
        if code:
            s = s[:b1] + '\n' + '\n'.join(code) + s[b1:]
            io.open(p, 'w', encoding='utf-8').write(s)
        print('%s +%d' % (CLASSES[lg], len(code)))
    return 0


if __name__ == '__main__':
    sys.exit(main())
