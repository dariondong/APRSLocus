// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appName => 'APRSlocus';

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'キャンセル';

  @override
  String get save => '保存';

  @override
  String get delete => '削除';

  @override
  String get confirm => '確認';

  @override
  String get back => '戻る';

  @override
  String get next => '次へ';

  @override
  String get finish => '完了して接続';

  @override
  String get previous => '前へ';

  @override
  String get search => '検索';

  @override
  String get settings => '設定';

  @override
  String get greetMorning => 'おはようございます、';

  @override
  String get greetNoon => 'こんにちは、';

  @override
  String get greetAfternoon => 'こんにちは、';

  @override
  String get greetEvening => 'こんばんは、';

  @override
  String get greetNight => '夜分遅くに、';

  @override
  String get about => 'アプリについて';

  @override
  String get logout => '終了';

  @override
  String get retry => '再試行';

  @override
  String get all => 'すべて';

  @override
  String get online => 'オンライン';

  @override
  String get offline => 'オフライン';

  @override
  String get moving => '移動中';

  @override
  String get emergency => '緊急';

  @override
  String get fixed => '固定';

  @override
  String get infrastructure => 'デジピーター';

  @override
  String get weather => '気象';

  @override
  String get fmo => 'FMO';

  @override
  String get mobile => '車載';

  @override
  String get favorite => 'お気に入り';

  @override
  String get grid => 'グリッド';

  @override
  String get callsign => 'コールサイン';

  @override
  String get speed => '速度';

  @override
  String get altitude => '高度';

  @override
  String get course => 'コース';

  @override
  String get distance => '距離';

  @override
  String get bearing => '方位角';

  @override
  String get lastSeen => '最終受信';

  @override
  String get latitude => '緯度';

  @override
  String get longitude => '経度';

  @override
  String get station => '局';

  @override
  String get stations => '局';

  @override
  String get messages => 'メッセージ';

  @override
  String get packets => 'パケット';

  @override
  String get map => '地図';

  @override
  String get home => 'ホーム';

  @override
  String get connection => '接続';

  @override
  String get connected => '接続済み';

  @override
  String get disconnected => '未接続';

  @override
  String get connecting => '接続中';

  @override
  String get reconnect => '再接続';

  @override
  String get server => 'サーバー';

  @override
  String get port => 'ポート';

  @override
  String get passcode => 'Passcode';

  @override
  String get beacon => '位置ビーコン';

  @override
  String get beaconInterval => '送信間隔(秒)';

  @override
  String get nextBeacon => '次回送信';

  @override
  String get beaconsSent => 'ビーコン送信回数';

  @override
  String get symCatVehicles => '車両 / 交通';

  @override
  String get symCatBuildings => '建物 / 施設';

  @override
  String get symCatNature => '気象 / 自然';

  @override
  String get symCatAirWater => '航空 / 水上';

  @override
  String get symCatComms => '通信 / その他';

  @override
  String get homeBadgeLabel => 'ホーム表示バッジ';

  @override
  String get homeBadgePickTitle => 'ホーム表示バッジを選択';

  @override
  String get homeBadgePickDesc => '獲得済みのバッジから 1 つ選び、ホームに常時表示します';

  @override
  String get simLocationHint => 'シミュレーション位置を使用（GPS 不要）';

  @override
  String get speedTierRules => '速度別ルール';

  @override
  String get restoreDefaults => '既定に戻す';

  @override
  String get speedTierDesc =>
      '速度が上がるほど送信頻度も上がります。各段ごとに間隔とアイコンを設定できます（空欄＝マイシンボル）。';

  @override
  String get speedTierShortIntervalWarn =>
      '間隔を 60 秒未満にするとサーバー負荷が大きく増えます。60 秒以上を推奨します。';

  @override
  String get addSpeedTier => '速度段を追加';

  @override
  String get maxSpeedTiers => '速度段は最大 5 個まで';

  @override
  String get iconDefaultMySymbol => 'アイコン · 既定（マイシンボル）';

  @override
  String iconNamed(String name) {
    return 'アイコン · $name';
  }

  @override
  String everyNSeconds(String sec) {
    return '$sec 秒ごと';
  }

  @override
  String get tierIdleTitle => '編集 · 停止/低速段';

  @override
  String get tierSpeedTitle => '編集 · 速度段';

  @override
  String get minSpeedKmh => '最低速度 (km/h)';

  @override
  String get intervalSeconds => '送信間隔 (秒)';

  @override
  String get idleTierDesc => '最初の移動段未満の速度はすべてこの段で送信します';

  @override
  String get intervalLabel => '間隔';

  @override
  String get unitSeconds => '秒';

  @override
  String get pickBeaconIconDesc => 'ビーコンアイコンを選択 · 「既定」＝マイシンボルを使用';

  @override
  String get defaultLabel => '既定';

  @override
  String get deleteThisTier => 'この段を削除';

  @override
  String get idleTierNotDeletable => '停止段は削除できません';

  @override
  String get errMinSpeedInt => '最低速度は 1 以上の整数で入力してください';

  @override
  String get errIntervalInt => '送信間隔は 5 秒以上の整数で入力してください';

  @override
  String get errTierDuplicate => 'この速度段は既に存在します。速度値は重複しないようにしてください';

  @override
  String get wsUrlOptional => 'WebSocket URL（任意）';

  @override
  String get countryUnrestricted => '国/地域を未選択 · 制限なし（すべての局を受信）';

  @override
  String get weatherWidget => '天気ウィジェット';

  @override
  String get groupChatLabel => 'グループチャット';

  @override
  String nItems(String n) {
    return '$n 件';
  }

  @override
  String nMessages(String n) {
    return '$n 件';
  }

  @override
  String confirmDeleteMessages(String n) {
    return 'チャット履歴 $n 件をすべて削除しますか？この操作は取り消せません。';
  }

  @override
  String get weatherSimFollowLive => 'リアルタイムに追従';

  @override
  String get wxClear => '晴れ';

  @override
  String get wxCloudy => '曇り';

  @override
  String get wxOvercast => '本曇り';

  @override
  String get wxLightRain => '小雨';

  @override
  String get wxModerateRain => '雨';

  @override
  String get wxHeavyRain => '大雨';

  @override
  String get wxStormRain => '豪雨';

  @override
  String get wxThunder => '雷雨';

  @override
  String get wxSnow => '雪';

  @override
  String get wxFog => '霧';

  @override
  String get weatherSimTitle => '天気シミュレーション（背景/演出/アドバイスのプレビュー）';

  @override
  String get weatherSimDesc =>
      '選択後、上部バーの天気カプセルをタップするとプレビューできます。「リアルタイムに追従」で実際の天気に戻ります';

  @override
  String get restartWizardConfirm =>
      '初回起動ウィザードを再開します。コールサインや受信地域などを再設定できます。\n現在の設定は失われません。ウィザード完了後もそのままご利用いただけます。';

  @override
  String get restartWizardButton => '再実行';

  @override
  String get pasteAprsPacketHint =>
      '生の APRS パケットを貼り付けてください。例：\nBV2XYZ>APRS,TCPIP*:!3904.25N/11624.44E>テスト局';

  @override
  String beaconsSentCount(String n) {
    return '$n 回';
  }

  @override
  String get myBadgesAndAchievements => 'マイバッジと実績';

  @override
  String get quitApp => 'アプリを終了';

  @override
  String get quitAppDesc => '終了すると APRSlocus は位置送信とバックグラウンド受信を停止し、プロセスを終了します。';

  @override
  String get symCar => '自動車';

  @override
  String get openInBrowser => 'ブラウザで開く';

  @override
  String get badgeWall => 'バッジ一覧';

  @override
  String get achievementWall => '実績一覧';

  @override
  String get mapTypeCartoPositron => 'Carto Positron（軽量ベクター）';

  @override
  String get mapTypeCarto => 'Carto ライト';

  @override
  String get mapTypeCartoDark => 'Carto ダーク';

  @override
  String get mapTypeCartoVoyager => 'Carto Voyager';

  @override
  String get mapTypeOsm => 'OSM 標準';

  @override
  String get mapTypeOsmHot => 'OSM 人道';

  @override
  String get mapTypeOpenTopo => 'OpenTopo 地形';

  @override
  String get mapTypeEsriStreet => 'Esri ストリート';

  @override
  String get mapTypeEsriSat => 'Esri 航空写真';

  @override
  String get simulatedKeepAlive => 'シミュレーション位置 · バックグラウンド維持';

  @override
  String get symCatEmergency => '緊急対応';

  @override
  String get symSmallAircraft => '小型機';

  @override
  String myPositionSet(String grid) {
    return '現在地を設定しました。グリッド $grid';
  }

  @override
  String get tierIdleShort => '停止/低速';

  @override
  String get symHouse => '住宅';

  @override
  String get symPerson => '人物';

  @override
  String get symTruck => 'トラック';

  @override
  String get symBicycle => '自転車';

  @override
  String get symRv => 'キャンピングカー';

  @override
  String get symWxStation => '気象観測局';

  @override
  String get symPolice => '警察署';

  @override
  String get symMotorcycle => 'オートバイ';

  @override
  String get symSemi => 'セミトレーラー';

  @override
  String get symVan => 'バン';

  @override
  String get symJeep => 'ジープ';

  @override
  String get symBus => 'バス';

  @override
  String get symTruckStop => 'トラックステーション';

  @override
  String get symTrain => '列車';

  @override
  String get symFireTruck => '消防車';

  @override
  String get symPoliceCar => 'パトカー';

  @override
  String get symSnowmobile => 'スノーモービル';

  @override
  String get symYagi => '八木アンテナ';

  @override
  String get symHospital => '病院';

  @override
  String get symAmbulance => '救急車';

  @override
  String get symFireStation => '消防署';

  @override
  String get symSchool => '学校';

  @override
  String get symMotel => 'モーテル';

  @override
  String get symHotel => 'ホテル';

  @override
  String get symLaptop => 'ノートPC';

  @override
  String get symPostOffice => '郵便局';

  @override
  String get symWeather => '気象';

  @override
  String get symWater => '給水所';

  @override
  String get symHurricane => 'ハリケーン';

  @override
  String get symHorse => '乗馬';

  @override
  String get symDog => '犬';

  @override
  String get symCamping => 'キャンプ';

  @override
  String get symShelter => '避難所';

  @override
  String get symRedCross => '赤十字';

  @override
  String get symFireAlarm => '火災報知';

  @override
  String get symEmergCenter => '緊急対策本部';

  @override
  String get symCmdCenter => '指揮所';

  @override
  String get symHandicap => '身体障害者';

  @override
  String get symBigAircraft => '大型機';

  @override
  String get symGlider => 'グライダー';

  @override
  String get symBalloon => '気球';

  @override
  String get symShip => '船舶';

  @override
  String get symSailboat => 'ヨット';

  @override
  String get symMobileSat => '移動衛星';

  @override
  String get symSatAntenna => '衛星アンテナ';

  @override
  String get symDigi => 'デジピーター';

  @override
  String get symDigiTower => '中継タワー';

  @override
  String get symMicE => 'Mic-E 中継';

  @override
  String get symNode => 'ノード';

  @override
  String get symDxCluster => 'DX クラスタ';

  @override
  String get symHfGateway => 'HF ゲートウェイ';

  @override
  String get symFileServer => 'ファイルサーバー';

  @override
  String get symTelephone => '電話';

  @override
  String get symGrid => 'グリッド';

  @override
  String get symXUnix => 'X/Unix';

  @override
  String get symFmoStation => 'FMO 局';

  @override
  String get filter => '受信範囲フィルター';

  @override
  String get filterRadius => 'フィルター半径 (km)';

  @override
  String get maxStations => '最大局数';

  @override
  String get receiveFilter => '受信コールサイン絞り込み';

  @override
  String get receiveCountries => '国・地域';

  @override
  String get receiveOthers => 'その他の局';

  @override
  String get darkMode => 'ダークモード';

  @override
  String get themeColor => 'テーマカラー';

  @override
  String get language => '言語';

  @override
  String get languageSystem => 'システムに従う';

  @override
  String get languageZh => '中文';

  @override
  String get languageEn => 'English';

  @override
  String get languageZhTw => '繁體中文';

  @override
  String get languageJa => '日本語';

  @override
  String get languageId => 'Bahasa Indonesia';

  @override
  String get languageEs => 'スペイン語';

  @override
  String get displaySettings => '表示設定';

  @override
  String get uiScale => 'UI 拡大率';

  @override
  String get reloadUi => 'UI を再読み込み';

  @override
  String get reloadDone => '再読み込みしました';

  @override
  String get mapType => '地図の種類';

  @override
  String get unit => '単位';

  @override
  String get coordDatum => '測地系';

  @override
  String get stationSettings => '無線局設定';

  @override
  String get connectionSettings => '接続設定';

  @override
  String get chatSettings => 'チャット設定';

  @override
  String get dataSettings => 'データ設定';

  @override
  String get advancedSettings => '詳細設定';

  @override
  String get sponsors => 'スポンサー・謝辞';

  @override
  String get sponsorsThanks => 'すべての支援者に感謝します';

  @override
  String get send => '送信';

  @override
  String get receive => '受信';

  @override
  String get clear => 'クリア';

  @override
  String get copy => 'コピー';

  @override
  String get copied => 'コピーしました';

  @override
  String get version => 'バージョン';

  @override
  String get location => '位置情報';

  @override
  String get gpsStatus => 'GPS 状態';

  @override
  String get myLocation => '自分の位置';

  @override
  String get track => '軌跡';

  @override
  String get forwardingPath => '転送経路';

  @override
  String get relatedStations => '関連局';

  @override
  String get openInMap => '地図で見る';

  @override
  String get navigate => 'ナビ';

  @override
  String get messageSent => 'メッセージを送信しました';

  @override
  String get enterMessage => 'メッセージを入力';

  @override
  String get noData => 'データなし';

  @override
  String get searchHint => 'コールサイン / 種類 / グリッド / メモ…';

  @override
  String get notFound => '局が見つかりません';

  @override
  String get totalStations => '合計';

  @override
  String get sortBy => '並べ替え';

  @override
  String get sortCall => 'コールサイン';

  @override
  String get sortRecent => '最近';

  @override
  String get sortDistance => '距離';

  @override
  String get sortStatus => '状態';

  @override
  String get typeFilter => '種類フィルター';

  @override
  String get aprslocusOnly => 'APRSlocus';

  @override
  String get confirmDelete => '削除しますか？';

  @override
  String get confirmRestartOobe =>
      '初回起動ウィザードを再度開きます。コールサインや受信地域などを再設定できます。\n現在の設定は失われません。ウィザード完了後もそのままご利用いただけます。';

  @override
  String get restartWizard => 'セットアップウィザードを再実行';

  @override
  String get restartWizardTitle => 'セットアップウィザードを再実行しますか？';

  @override
  String get oobeFilterTitle => '受信地域を選択';

  @override
  String get oobeFilterDesc => '受信する国・地域を選択してください。未選択の場合はすべての局を受信します（制限なし）';

  @override
  String get oobeWelcomeTitle => 'APRSlocus へようこそ';

  @override
  String get oobeWelcomeRealMap => 'リアルタイム地図';

  @override
  String get oobeWelcomeGps => 'GPS 位置送信';

  @override
  String get oobeWelcomeMsg => 'APRS メッセージ';

  @override
  String get oobeWelcomeIs => 'APRS-IS 接続';

  @override
  String get oobeCallTitle => 'あなたのコールサイン';

  @override
  String get oobeSymbolTitle => '局のシンボルを選択';

  @override
  String get oobeServerTitle => 'APRS-IS サーバーに接続';

  @override
  String get weatherData => '気象データ';

  @override
  String get fmoInfo => 'FMO 局情報';

  @override
  String get aprslocusInfo => 'APRSlocus 情報';

  @override
  String get locationInfo => '位置情報';

  @override
  String get recentPackets => '最近のパケット';

  @override
  String get quickActions => 'クイック操作';

  @override
  String get copyCoords => '座標をコピー';

  @override
  String get copyGrid => 'グリッドをコピー';

  @override
  String get sender => '送信元';

  @override
  String get time => '時刻';

  @override
  String get message => 'メッセージ';

  @override
  String get groupChat => 'グループ';

  @override
  String get newGroup => 'グループを作成';

  @override
  String get sendTo => '送信先';

  @override
  String get filterRule => 'フィルター規則';

  @override
  String get saveAndApply => 'フィルターを保存して適用';

  @override
  String get useMyLocation => '自分の位置をフィルター中心にする';

  @override
  String get noFixYet => 'まだ測位していないため、現在地を取得できません';

  @override
  String get invalidCoords => '有効な緯度・経度・半径を入力してください';

  @override
  String get filterSaved => 'フィルターを保存して適用しました';

  @override
  String get stationsShown => '局';

  @override
  String get settingsDesc => '無線局・位置情報・接続を設定';

  @override
  String get radioCat => '無線局';

  @override
  String get radioCatDesc => 'コールサイン · SSID · シンボル';

  @override
  String get beaconCat => '位置ビーコン送信';

  @override
  String get beaconCatDesc => 'GPS · ビーコン · 手動位置';

  @override
  String get connectionCat => '接続';

  @override
  String get connectionCatDesc => 'サーバー · フィルター範囲';

  @override
  String get displayCat => '表示';

  @override
  String get displayCatDesc => '座標 · テーマ';

  @override
  String get chatCat => 'チャット';

  @override
  String get chatCatDesc => '履歴 · 連絡先';

  @override
  String get dataCat => 'データ';

  @override
  String get dataCatDesc => 'ローカルデータの消去';

  @override
  String get advancedCat => '詳細';

  @override
  String get advancedCatDesc => 'ラボ · 開発者';

  @override
  String get updateCat => '更新';

  @override
  String get updateCatDesc => '新しいバージョンを確認';

  @override
  String get checkUpdate => '更新を確認';

  @override
  String get myStationSettings => 'マイ無線局';

  @override
  String get myStationSettingsDesc => 'コールサイン · SSID · シンボル · ビーコン';

  @override
  String get oobeWelcomeDesc => 'APRS 無線局の設定を始めましょう';

  @override
  String get oobeCallDesc => 'コールサインを入力してください';

  @override
  String get oobeSymbolDesc => 'シンボルは局の種類を表し、位置ビーコンと一緒に送信されます';

  @override
  String get oobeServerDesc => '接続すると世界中の APRS 局のデータを受信できます。既定の設定のままでも使えます';

  @override
  String get wizard => 'セットアップウィザード';

  @override
  String get setStep => 'ステップ';

  @override
  String get chooseSymbol => '局のシンボルを選択';

  @override
  String get settingsSubtitle => '地図座標と表示の好み';

  @override
  String get stationSettingsSubtitle => 'コールサイン・シンボル・ビーコン';

  @override
  String get connectionSettingsSubtitle => 'APRS-IS サーバーと受信範囲';

  @override
  String get chatSettingsSubtitle => 'メッセージ履歴と連絡先';

  @override
  String get dataSettingsSubtitle => 'ローカルデータの管理';

  @override
  String get advancedSettingsSubtitle => 'ラボと開発者ツール';

  @override
  String get stationListTitle => '局リスト';

  @override
  String get filters => 'フィルター';

  @override
  String get clearAll => 'すべてクリア';

  @override
  String get statusFilter => '状態';

  @override
  String get typeGroup => '種類';

  @override
  String get appFilter => 'ソフトウェア';

  @override
  String get mapMenu => '地図メニュー';

  @override
  String get mapTypeTitle => '地図の種類';

  @override
  String get selectMapType => '地図の種類を選択';

  @override
  String get showTrails => '軌跡を表示';

  @override
  String get showStations => '局を表示';

  @override
  String get aboutTitle => 'このアプリについて';

  @override
  String get aboutSubtitle => 'APRS 追跡と地図';

  @override
  String get author => '作者';

  @override
  String get codeContributions => 'コード貢献';

  @override
  String get codeContributionI18n => '国際化 / 英語 UI';

  @override
  String get codeContributionZhTw => '繁体字中国語 UI';

  @override
  String get codeContributionTranslation => '翻訳';

  @override
  String get dataSourceTxHint =>
      '複数のリンクを同時に有効にして受信できますが、**送信は 1 つだけ**です（右側のドット）。同じコールサインを 2 つのリンクから送ると重複パケットになります。';

  @override
  String get dataSourceTxBadge => '送信';

  @override
  String get dataSourceIgateHint =>
      'ゲートウェイとして使う（RF のパケットをインターネットへ中継する）には、APRS-IS と TNC／オーディオの両方を有効にして、下の「ゲートウェイ」をオンにします。';

  @override
  String get igateTitle => 'ゲートウェイ（iGate）';

  @override
  String get igateSubtitle => 'RF で受信したパケットを APRS-IS へ中継';

  @override
  String get igateEnable => 'ゲートウェイを有効化';

  @override
  String get igateHint =>
      'RF で受信したパケットを APRS-IS へ転送します（qAr/qAR とあなたのコールサインで経路を明示）。APRS-IS と RF ソース（TNC／オーディオ）の両方が必要です。';

  @override
  String get igateNeedRf => 'RF ソースがありません。上の「データソース」で TNC かオーディオを有効にしてください。';

  @override
  String get igateNeedIs => 'APRS-IS が有効になっていません。上で有効にしてください。';

  @override
  String get igateTwoWay => '双方向ゲートウェイ（メッセージを RF へ転送）';

  @override
  String get igateTwoWayHint =>
      'オンにすると**実際に RF で送信**します。「最近 RF で受信した局」宛のメッセージのみ転送（位置・気象などのブロードキャストは転送しません）。オフのときは RF→IS のみ。';

  @override
  String get igateStatToIs => '転送済み → APRS-IS';

  @override
  String get igateStatToRf => '転送済み → RF';

  @override
  String get igateStatDup => '重複として破棄';

  @override
  String get igateResetStats => 'カウンタをリセット';

  @override
  String get igateStatRfSeen => 'RF 受信（件）';

  @override
  String get igateStatBlocked => 'ループ防止で拒否';

  @override
  String get igateRfDown =>
      'RF リンクが未接続のため、ゲートウェイは何も中継できません。「RF 受信」が 0 のままならパケットがそもそも届いていません。TNC／オーディオの状態（シリアル速度・電源）を確認してください。';

  @override
  String get igateIsDown =>
      'APRS-IS が未接続のため、転送先がありません。接続が確立するとカウンタが動き始めます（リンク状態カードを参照）。';

  @override
  String get igateNoRfTraffic =>
      'RF でパケットを 1 件も受信していません。ゲートウェイの条件は揃っていますが**中継するものがありません**。ゲートウェイの問題ではなく、パケットがアプリに届いていません。上流を確認してください：無線機の音量とスケルチ、アンテナ、相手が実際に送信しているか、ログページに RF パケットがあるか。';

  @override
  String get igateAllRejected =>
      'RF パケットは届いていますが、すべてループ防止で拒否されました。TCPIP*/TCPXX* や q 構文を含む＝インターネット由来のため、APRS-IS に戻すと同一パケットが無限増殖します。**正常動作**です。';

  @override
  String grpSysJoined(String call) {
    return '$call がグループに参加しました';
  }

  @override
  String grpSysLeft(String call) {
    return '$call がグループを退出しました';
  }

  @override
  String grpSysJoinReq(String call) {
    return '$call が参加を希望しています';
  }

  @override
  String grpSysDeclined(String call) {
    return '$call が招待を辞退しました';
  }

  @override
  String get grpInviteTitle => 'グループへの招待';

  @override
  String grpInviteBody(String from, String name) {
    return '$from が「$name」に招待しました';
  }

  @override
  String get grpNameInvalid => 'グループ名は空にできず、コロンや改行も使えません';

  @override
  String grpNameTooLong(int max) {
    return 'グループ名は最大 $max 文字です（長すぎると招待が APRS メッセージ上限を超えます）';
  }

  @override
  String grpInviteSent(int n) {
    return '$n 名に招待を送信しました';
  }

  @override
  String get grpSelfPending => '管理者の確認待ち';

  @override
  String get deviceOverviewTitle => 'デバイス';

  @override
  String get deviceOverviewSubtitle => 'データソース・リンク状態・自己診断';

  @override
  String get deviceCurrentLink => '現在のリンク';

  @override
  String get deviceCurrentLinkDesc => '読み取り専用の要約。パラメータ変更は各サブページで';

  @override
  String get deviceEntries => 'デバイスとパラメータ';

  @override
  String get deviceEntriesDesc => 'リンクごとに 1 ページ、設定もそれぞれ独立';

  @override
  String get tncDeviceTitle => 'TNC デバイスとパラメータ';

  @override
  String get tncDeviceDesc => 'Bluetooth／シリアル接続、初期化文字列、KISS パラメータ、送信自己診断';

  @override
  String get deviceLogTitle => 'リンクログ';

  @override
  String get deviceLogDesc => '現在のソースのログを表示（TNC／オーディオで自動切替）';

  @override
  String get tncInitTitle => 'TNC 初期化文字列';

  @override
  String get tncInitSubtitle => '接続後に 1 行ずつ送信（APRSdroid の kiss.init 相当）';

  @override
  String get tncInitTip =>
      'TNC が「受信できるのに送信できない」場合はまずここを試してください。多くの Bluetooth／シリアル TNC は起動時にコマンドモードのままで、KISS ON／RESTART などを受け取って初めて KISS 転送に入ります。1 行 1 コマンド（CRLF は自動付加）。';

  @override
  String get tncInitDelay => '行ごとの間隔 (ms)';

  @override
  String get tncInitDelayTip => '行間の待ち時間。モジュールがコマンドを処理する時間が必要で、短すぎると取りこぼします';

  @override
  String get tncInitSendAction => '初期化文字列を今すぐ送信';

  @override
  String tncInitSent(int n) {
    return '初期化文字列を $n 行送信しました';
  }

  @override
  String get tncInitEmpty => '初期化文字列が未入力です';

  @override
  String get tncPushParams => '接続時に KISS パラメータを送信';

  @override
  String get tncPushParamsTip =>
      '既定はオフ（APRSdroid と同じ）。オンにすると接続時に上記の値を TNC へ送り、TNC 自身の設定を上書きします。値が不適切だと送信せず待ち続けることがあるため、一元管理したいときだけ有効にしてください。';

  @override
  String get tncTxTestTitle => '送信自己診断';

  @override
  String get tncTxTestSubtitle =>
      'テストフレームを 1 つ TNC に書き込み、問題がリンク側か TNC 側かを切り分けます';

  @override
  String get tncTxTestHint =>
      '送るのはステータスフレーム（位置情報なし）なので、aprs.fi 上で局を移動させません。ここで「書き込み済み」と出るのに送信されない場合、問題は TNC 側です。まず初期化文字列（KISS ON／RESTART）を試し、次に TxDelay とチャネルの混雑を確認してください。';

  @override
  String get tncTxTestAction => 'テストフレームを書き込む';

  @override
  String get tncTxTestOkPrefix => '書き込み済み';

  @override
  String tncTxTestOk(String n) {
    return 'TNC に書き込みました（累計 $n フレーム）。無線機が送信しない場合は TNC 側の問題です。初期化文字列を試すか TxDelay を確認してください。';
  }

  @override
  String tncTxTestFail(String err) {
    return '書き込み失敗：$err';
  }

  @override
  String get tncNeedConnected => '先に TNC へ接続してください';

  @override
  String msgLenCounter(int chars, int bytes) {
    return '$chars/67 文字 · パケット $bytes/512 バイト';
  }

  @override
  String msgOverSpecAsk(int chars) {
    return 'このメッセージは $chars 文字で、APRS 規格の上限 67 文字を超えています。多くのクライアントは表示できますが、一部のクライアント／ゲートウェイは切り捨てまたは拒否するため、相手が解釈できない可能性があります。送信しますか？';
  }

  @override
  String msgOverServerLimit(int bytes, int over) {
    return 'パケットが $bytes バイトで、APRS-IS の 1 行上限 512 バイトを超えています。サーバーがパケットごと破棄する可能性があります（ヘッダーも届きません）。約 $over バイト短くしてください。';
  }

  @override
  String get msgSendAnyway => 'それでも送信';

  @override
  String get msgSpecLimitHint =>
      'APRS 規格では 1 通のメッセージは 67 文字以内が推奨です。長すぎる文本は一部のクライアントで欠けたり解析に失敗します。';

  @override
  String get msgBlockedTooLong => '送信を中止：パケットが APRS-IS の上限を超えています';

  @override
  String get beaconRfBeaconOff => 'RF ビーコンがオフ';

  @override
  String get beaconRfEnableHint =>
      'RF ソースでの自動送信には「RF ビーコン」を明示的に有効にする必要があります。それまでは位置を自動送信しません（カウントダウンも進みません）。';

  @override
  String get beaconRfEnableAction => 'RF ビーコンを有効化';

  @override
  String get beaconRfEnabled => 'RF ビーコンを有効化しました（間隔どおり自動送信します）';

  @override
  String get beaconRfEnableWarn => '送信はあなたのコールサインで行われます。免許の範囲内で運用してください';

  @override
  String get diagTitle => 'リンク自己診断';

  @override
  String get diagSubtitle => 'プロトコル・権限・デバイスのどこに問題があるか順に確認します';

  @override
  String get diagRun => '自己診断を実行';

  @override
  String get diagRunning => '診断中…';

  @override
  String diagPassed(int n) {
    return '$n 項目合格';
  }

  @override
  String diagFailed(int n) {
    return '$n 項目失敗';
  }

  @override
  String get diagHint => 'プロトコル回路は無線機なしでも実行できます。まずソフト側を切り分け、次にデバイスと配線を確認';

  @override
  String get diagTncSection => 'TNC（KISS / AX.25）';

  @override
  String get diagAudioSection => 'オーディオ（AFSK 1200）';

  @override
  String get diagKissEscape => 'KISS エスケープ';

  @override
  String get diagKissEscapeFail => 'KISS エスケープの復元に失敗（ソフト側の問題。デバイスを替えても解決しません）';

  @override
  String get diagAx25 => 'AX.25 フレーム';

  @override
  String get diagAx25Fail => 'AX.25 符号化に失敗（パケット形式が不正）';

  @override
  String diagAx25Mismatch(String got) {
    return 'AX.25 の往復が不一致。復号結果：$got';
  }

  @override
  String get diagFcs => 'FCS 検査';

  @override
  String get diagFcsFail => 'FCS 検査が異常（1 バイト変更は拒否されるべきです）';

  @override
  String get diagTncLoopback => 'TNC プロトコル回路';

  @override
  String diagTncLoopbackOk(int len) {
    return 'KISS/AX.25 の往復が一致（$len バイト）';
  }

  @override
  String get diagAfskLoopback => 'AFSK 変復調回路';

  @override
  String diagAfskLoopbackOk(int samples, int rate) {
    return '変調→復調が一致（$samples サンプル @${rate}Hz）';
  }

  @override
  String diagAfskLoopbackFail(int n) {
    return '$n フレームを復調（期待値は 1）';
  }

  @override
  String get diagAfskLevelFail => '波形の振幅が低すぎます（ほぼ無音）';

  @override
  String get diagPlatform => 'プラットフォーム対応';

  @override
  String diagPlatformOk(String name) {
    return '利用可能 · バックエンド $name';
  }

  @override
  String get diagTncPlatformNo => 'このプラットフォームは TNC リンクに未対応です';

  @override
  String get diagAudioPlatformWarn => 'リアルタイム音声は非対応 · WAV ファイル方式は利用できます';

  @override
  String get diagNoRealtime => '非リアルタイム';

  @override
  String get diagPermission => '録音権限';

  @override
  String get diagPermissionOk => '許可済み';

  @override
  String get diagSkipped => 'スキップ（未対応プラットフォーム）';

  @override
  String get diagCapture => 'オーディオ入力';

  @override
  String diagCaptureOk(int bytes, int rate) {
    return '$bytes バイト受信 @${rate}Hz';
  }

  @override
  String get diagCaptureNoData => '音声データが届きません。入力デバイスと権限を確認してください';

  @override
  String diagCaptureFailed(String err) {
    return '入力を開始できません：$err';
  }

  @override
  String get diagSpeaker => 'スピーカー出力';

  @override
  String get diagSpeakerOk => 'テスト音を再生しました';

  @override
  String diagSpeakerFail(String err) {
    return '再生に失敗：$err';
  }

  @override
  String get diagFileIo => 'WAV ファイル入出力';

  @override
  String diagFileIoOk(int rate) {
    return '書き込み→読み出し→復調が一致 @${rate}Hz';
  }

  @override
  String diagFileWriteFail(String err) {
    return 'ファイル書き込みに失敗：$err';
  }

  @override
  String get diagFileReadFail => 'ファイル読み出しに失敗';

  @override
  String get diagFileDecodeFail =>
      'ファイル内の音声からパケットを復調できません（AFSK 1200 の録音ではない可能性）';

  @override
  String get connAudioSourceHint => 'オーディオモードではサーバー・フィルタ・KISS 設定は使いません';

  @override
  String get testTxTitle => 'テスト送信';

  @override
  String get testTxDesc => 'ステータスパケットを送信し、実際に電波に出るか確認します';

  @override
  String get testTxAction => 'テストフレームを送信';

  @override
  String get testTxSent => 'テストフレームをリンクに渡しました';

  @override
  String testTxFail(String err) {
    return 'テストフレーム送信に失敗：$err';
  }

  @override
  String get testTxNeedsConnect => '先にリンクを接続してください';

  @override
  String get testTxHint =>
      'これは**実際の送信**です（ステータスパケット、位置情報なし）。自分のコールサインと免許の範囲内で運用してください';

  @override
  String get audioStatsTitle => 'オーディオ統計';

  @override
  String audioStatRx(int n) {
    return '受信 $n フレーム';
  }

  @override
  String audioStatTx(int n) {
    return '送信 $n フレーム';
  }

  @override
  String audioStatDrop(int n) {
    return '送信中に $n バイト破棄';
  }

  @override
  String get audioRestart => 'オーディオリンクを再起動';

  @override
  String get audioTxDisabled => '「送信を許可」がオフ — 受信のみ';

  @override
  String get audioLoopbackHint =>
      '自己検査は実際に変調→復調を行います。Android では送信中マイクを一時停止します（半二重）';

  @override
  String get notifAudioConnected => 'オーディオリンク接続中';

  @override
  String get notifAudioDisconnected => 'オーディオリンク切断';

  @override
  String connConnectingAudio(String name) {
    return 'オーディオを開いています（$name）…';
  }

  @override
  String connAudioConnected(String rate) {
    return 'オーディオリンク接続 · $rate';
  }

  @override
  String connRetryAudio(int seconds) {
    return 'オーディオを開けません · $seconds秒後に再試行…';
  }

  @override
  String connRetryAudioDetail(String detail, int seconds) {
    return 'オーディオ失敗（$detail）· $seconds秒後に再試行…';
  }

  @override
  String connAudioLinkLost(int seconds) {
    return 'オーディオリンク切断 · $seconds秒後に再接続…';
  }

  @override
  String connAudioPositionSent(String call) {
    return 'オーディオ送信 · 位置を送信しました ($call)';
  }

  @override
  String get dataSourceAudio => 'オーディオ（サウンドカード）';

  @override
  String get dataSourceAudioDesc => 'マイク／スピーカーまたはサウンドカード接続で AFSK 1200 を送受信';

  @override
  String get audioSettings => 'オーディオ（サウンドカード TNC）';

  @override
  String get audioSettingsSubtitle => 'サウンドカードで AFSK 1200 パケットを送受信';

  @override
  String get audioBackend => 'オーディオバックエンド';

  @override
  String get audioUnsupported => 'このプラットフォームはリアルタイム音声に未対応です（WAV ファイル方式は利用可）';

  @override
  String get audioNeedPermission => '録音権限（RECORD_AUDIO）が必要です。許可して再試行してください';

  @override
  String get audioCaptureTitle => 'オーディオ入力';

  @override
  String get audioCaptureDesc => 'マイク／ライン入力から AFSK 1200 を復調';

  @override
  String get audioCaptureStart => '入力を開始';

  @override
  String get audioCaptureStop => '入力を停止';

  @override
  String get audioSampleRate => 'サンプルレート';

  @override
  String get audioSampleRateTip =>
      '22050Hz はサウンドカード TNC の一般的な値です。非対応なら 44100/48000 を使用。変更すると入力が再起動します';

  @override
  String get audioLevel => '入力レベル';

  @override
  String get audioLevelTip => '信号があるとメーターが上がり、AFSK を受信すると「復調ロック」が点灯します';

  @override
  String get audioSynced => '復調ロック';

  @override
  String get audioUnlocked => '未ロック';

  @override
  String audioBadFrames(int n) {
    return '復調中断 $n 回（ノイズ／同期外れ）';
  }

  @override
  String get audioBaud => 'ビットレート';

  @override
  String get audioTones => 'トーン（マーク／スペース）';

  @override
  String get audioTxTitle => 'オーディオ送信';

  @override
  String get audioTxDesc => '送信前にチャネルを監視して衝突を避けます';

  @override
  String get audioTxEnabled => '送信を許可';

  @override
  String get audioTxEnabledTip => 'オフにすると受信のみ。ビーコンを聞くだけのときに便利です';

  @override
  String get audioTxDelayTip => '送信前のプリアンブル長。相手の復調ロックと無線機 PTT 立ち上げに必要です';

  @override
  String get audioToneMark => 'マーク周波数 (Hz)';

  @override
  String get audioToneSpace => 'スペース周波数 (Hz)';

  @override
  String get audioMarkTip => 'Bell 202 はマーク 1200Hz／スペース 2200Hz。許容は数 Hz のみです';

  @override
  String get audioSpaceTip => 'スペース音。マークと合わせて FSK シフト（標準 1000Hz）を決めます';

  @override
  String get audioBaudTip => 'VHF の APRS は常に 1200 bd（Bell 202）。300 は HF 用です';

  @override
  String get audioTxDelayLabel => '送信プリアンブル (ms)';

  @override
  String get audioTnc2Tip => '形式 SRC>DEST,PATH:info（例：BG7LZQ-9>APALOC:>TEST）';

  @override
  String get audioCsmaWait => 'チャネル空き待ち (ms)';

  @override
  String get audioCsmaWaitTip => 'チャネル使用中に待つ最大時間。0 で即時送信';

  @override
  String get audioStopTx => '送信を停止';

  @override
  String get audioWavTitle => 'WAV ファイル方式';

  @override
  String get audioWavDesc => '録音をオフライン復調、またはパケットを音声ファイルに書き出し';

  @override
  String get audioWavPath => 'ファイルパス';

  @override
  String get audioWavDecodeAction => 'この WAV を復調';

  @override
  String get audioWavExportAction => 'このパケットを書き出し';

  @override
  String get audioWavTnC2 => '書き出すパケット (TNC2)';

  @override
  String get audioWavNone => 'パケットを復調できません（AFSK 1200 の録音ではない可能性）';

  @override
  String audioWavFound(int n) {
    return '$n 件のパケットを復調';
  }

  @override
  String audioWavWritten(String path) {
    return '$path に書き出しました';
  }

  @override
  String audioWavFailed(String err) {
    return 'ファイル入出力に失敗：$err';
  }

  @override
  String connTncConnected(String arg) {
    return 'TNC 接続済み · $arg';
  }

  @override
  String connTncPositionSent(String arg) {
    return 'TNC 接続済み · 位置を送信しました ($arg)';
  }

  @override
  String connRetryTnc(int n) {
    return 'TNC 接続失敗 · $n 秒後に再試行…';
  }

  @override
  String connRetryTncDetail(String e, int n) {
    return 'TNC 接続失敗（$e）· $n 秒後に再試行…';
  }

  @override
  String connTncLinkLost(int n) {
    return 'TNC リンク切断 · $n 秒後に自動再接続…';
  }

  @override
  String get tncErrNoDevice => 'TNC デバイスが未登録';

  @override
  String get tncErrUnsupported => 'このプラットフォームは未対応';

  @override
  String get tncErrNotConnected => 'リンク未接続';

  @override
  String get tncErrOpenRead => 'デバイスを読み取り用に開けません';

  @override
  String get tncErrOpenWrite =>
      'デバイスを書き込み用に開けません。Windows の COM ポートは占有型です。他のソフトが使用していないか確認してください';

  @override
  String get tncErrBadFormat => 'パケット形式が不正';

  @override
  String get tncErrFrameTooLong => 'フレーム長が上限を超えています';

  @override
  String get tncErrTimeout => 'タイムアウト';

  @override
  String get translateMyLang => '自分の言語';

  @override
  String get translateMyLangHint => '相手からのメッセージはこれを訳先にします';

  @override
  String get translatePeerLang => '相手の言語';

  @override
  String get translatePeerUnknownHint => '相手のメッセージから自動判定します';

  @override
  String get translateLearned => '自動判定済み';

  @override
  String get translatePeerUnknown =>
      '相手の言語が不明です。翻訳設定で指定するか、相手のメッセージを数件受信すると自動判定されます';

  @override
  String get translateSideIncoming => '受信';

  @override
  String get translateSideOutgoing => '送信';

  @override
  String get translateToMeTag => '自分向け';

  @override
  String get translateToPeerTag => '相手が読む文';

  @override
  String get translateContrast => '原文と訳文を並べて表示';

  @override
  String get translateContrastTip => 'オフにすると訳文のみ表示（原文は長押しで確認できます）';

  @override
  String get translateProviderFree => '無料（キー不要）';

  @override
  String get translateProviderFreeDesc => 'すぐ使えます · 公開エンドポイントのため制限や不安定さがあります';

  @override
  String translateFreeFailed(String e) {
    return '無料エンドポイントが利用できません（$e）· 設定で Google / Baidu / カスタムに切り替えられます';
  }

  @override
  String get translateProviderAuto => '自動（推奨）';

  @override
  String get translateProviderAutoDesc =>
      '複数のキー不要エンドポイントを順に試し、実際に翻訳できた結果を採用します';

  @override
  String get translateProviderGooglePublic => 'Google 公開エンドポイント（キー不要）';

  @override
  String get translateProviderGooglePublicDesc =>
      '品質は良好ですが、レート制限（429）を受けることがあります';

  @override
  String get translateProviderMyMemory => 'MyMemory（キー不要）';

  @override
  String get translateProviderMyMemoryDesc =>
      '公式の無料 API ですが翻訳メモリであり、一致がないと原文をそのまま返します';

  @override
  String get translateProviderLibre => 'LibreTranslate（自前ホスト可）';

  @override
  String get translateProviderLibreDesc =>
      'オープンソースで自前ホストが最も確実。公共インスタンスはキーが必要で中国語非対応のことも多い';

  @override
  String get translateLibreUrl => 'インスタンス URL';

  @override
  String get translateLibreKey => 'インスタンス API キー（公共は必要、自前ホストは空で可）';

  @override
  String get translateUsedProvider => '今回の使用先';

  @override
  String get translateUntranslated =>
      'エンドポイントが実際には翻訳していません（原文を返しました）。次の候補を試しました';

  @override
  String translateAutoAllFailed(String e) {
    return 'キー不要のエンドポイントがすべて失敗しました（$e）· 設定で Google / Baidu のキーか自前インスタンスに切り替えてください';
  }

  @override
  String get translateLangUnsupported =>
      'このプロバイダはその言語への翻訳に対応していません · 「自動」か別のプロバイダをお試しください';

  @override
  String get translateLangScopeNote =>
      'プロバイダごとに対応語種が異なります（例：Baidu 標準版はインドネシア語 id に対応。ただし全方向ではありません）。非対応の場合は自動か別プロバイダを案内します';

  @override
  String get langNameZh => '中国語（簡体）';

  @override
  String get langNameZhTw => '中国語（繁体）';

  @override
  String get langNameEn => '英語';

  @override
  String get langNameJa => '日本語';

  @override
  String get langNameKo => '韓国語';

  @override
  String get langNameEs => 'スペイン語';

  @override
  String get langNameFr => 'フランス語';

  @override
  String get langNameDe => 'ドイツ語';

  @override
  String get langNameRu => 'ロシア語';

  @override
  String get langNamePt => 'ポルトガル語';

  @override
  String get langNameIt => 'イタリア語';

  @override
  String get langNameId => 'インドネシア語';

  @override
  String get langNameTh => 'タイ語';

  @override
  String get langNameVi => 'ベトナム語';

  @override
  String get langNameAr => 'アラビア語';

  @override
  String get translateOutgoing => '送信前に相手の言語へ翻訳';

  @override
  String get translateOutgoingTip =>
      'オンにすると送信時に相手の言語へ翻訳してから送信します。相手が読める言語か確認してください';

  @override
  String get translateInput => '入力を翻訳';

  @override
  String translateOutPreview(String text) {
    return '送信内容：$text';
  }

  @override
  String translateOutPreviewHint(String lang) {
    return '$lang に翻訳済み · 送信でこの内容を発信します';
  }

  @override
  String get translateOutCancel => '翻訳を取消';

  @override
  String get translateOutNeedPeer => '相手の言語が不明です。会話の翻訳設定で指定してください';

  @override
  String translateSentAs(String text) {
    return '相手の言語で送信：$text';
  }

  @override
  String translateTooLongAfter(int n) {
    return '訳文が長さ上限（$n 文字）を超えたため送信しません';
  }

  @override
  String get dateToday => '今日';

  @override
  String get dateYesterday => '昨日';

  @override
  String dateDividerFull(int y, int m, int d, String w) {
    return '$y年$m月$d日 $w';
  }

  @override
  String dateWeekday(String d) {
    String _temp0 = intl.Intl.selectLogic(d, {
      '1': '月',
      '2': '火',
      '3': '水',
      '4': '木',
      '5': '金',
      '6': '土',
      '7': '日',
      'other': '—',
    });
    return '$_temp0';
  }

  @override
  String get translate => '翻訳';

  @override
  String get translateText => 'テキストを翻訳';

  @override
  String get translateSettings => '翻訳設定';

  @override
  String get translateSettingsSubtitle => '翻訳プロバイダ、言語、自動翻訳';

  @override
  String get translateProvider => '翻訳プロバイダ';

  @override
  String get translateProviderGoogle => 'Google 翻訳';

  @override
  String get translateProviderBaidu => 'Baidu 翻訳';

  @override
  String get translateProviderCustom => 'カスタム';

  @override
  String get translateGoogleKey => 'Google API キー';

  @override
  String get translateGoogleKeyTip =>
      'Google Cloud Translation v2 の API キー。Google Cloud コンソールで取得してください';

  @override
  String get translateBaiduAppId => 'Baidu App ID';

  @override
  String get translateBaiduKey => 'Baidu シークレットキー';

  @override
  String get translateBaiduTip =>
      'Baidu 翻訳オープンプラットフォームで「汎用テキスト翻訳」を申請してください。キーは端末内のみに保存されます';

  @override
  String get translateCustomUrl => 'エンドポイント URL';

  @override
  String get translateCustomMethod => 'HTTP メソッド';

  @override
  String get translateCustomHeaders => 'ヘッダー (JSON)';

  @override
  String get translateCustomBody => 'ボディテンプレート';

  @override
  String translateCustomBodyTip(String text, String from, String to) {
    return '使用可能なプレースホルダ：$text 原文、$from 元の言語、$to 翻訳先の言語。GET の場合は無視されます';
  }

  @override
  String get translateCustomResultPath => '結果の JSON パス';

  @override
  String get translateCustomResultPathTip =>
      'ドット区切りのパス、配列は番号。例 data.translations.0.translatedText';

  @override
  String get translateTest => '翻訳をテスト';

  @override
  String translateTestOk(String text) {
    return 'プロバイダは利用可能：$text';
  }

  @override
  String get translateNeedConfig => '先に翻訳プロバイダを設定してください';

  @override
  String translateFailed(String e) {
    return '翻訳に失敗：$e';
  }

  @override
  String get translateTargetLang => '翻訳先';

  @override
  String get translateSourceLang => '原文の言語';

  @override
  String get translateAuto => '受信メッセージを自動翻訳';

  @override
  String get translateAutoTip => 'この会話のみに適用されます。受信メッセージだけを翻訳します';

  @override
  String get translateShowOriginal => '原文を表示';

  @override
  String get translateShowTranslation => '訳文を表示';

  @override
  String get translateRetry => '再翻訳';

  @override
  String get translateTranslating => '翻訳中…';

  @override
  String get translateCopyOriginal => '原文をコピー';

  @override
  String get translateCopyResult => '訳文をコピー';

  @override
  String get translateLangAuto => '自動検出';

  @override
  String get translateSameLang => '訳文が原文と同じです · 翻訳不要か、プロバイダが翻訳できなかった可能性があります';

  @override
  String get translateNotNeeded => '翻訳の必要がない内容です（数字 / 記号 / コールサイン）';

  @override
  String translateBubbleCount(int n) {
    return '$n 件を翻訳';
  }

  @override
  String get translatePrivacyNote =>
      '翻訳はメッセージ本文を選択した第三者のサービスへ送信します。プライバシーはご自身でご判断ください';

  @override
  String get notifTncConnected => 'TNC 接続済み';

  @override
  String get notifTncDisconnected => 'TNC 未接続';

  @override
  String get dataSourceTitle => 'データソース';

  @override
  String get dataSourceSubtitle => 'パケットの取得元';

  @override
  String get dataSourceAprsIs => 'APRS-IS';

  @override
  String get dataSourceAprsIsDesc => 'インターネット経由で世界の APRS 網に接続';

  @override
  String get dataSourceTnc => 'TNC';

  @override
  String get dataSourceTncDesc => 'Bluetooth／シリアルの TNC 経由で無線機から直接送受信';

  @override
  String get dataSourceSwitchHint => 'データソースを切り替えると現在の接続は切断されます';

  @override
  String get dataSourcePkwdwpl => 'PKWDWPL（ケンウッド航点）';

  @override
  String get dataSourcePkwdwplDesc =>
      'Bluetooth/シリアルで無線機が出力する Kenwood \$PKWDWPL 航点文を読み取ります（受信のみ）';

  @override
  String get dataSourcePkwdwplHint =>
      'PKWDWPL は**受信専用**リンクです。局を受信しますが送信には使われません（送信は APRS-IS / TNC / オーディオを使用）';

  @override
  String connConnectingPkwdwpl(String arg) {
    return 'PKWDWPL に接続中（$arg）…';
  }

  @override
  String connPkwdwplConnected(String arg) {
    return 'PKWDWPL 接続済み · $arg';
  }

  @override
  String get pkwdwplDeviceTitle => 'PKWDWPL デバイス';

  @override
  String get pkwdwplDeviceDesc => '無線機のポートを登録し、航点の受信状態を確認します';

  @override
  String get pkwdwplBindTitle => 'デバイス登録と状態';

  @override
  String get pkwdwplBindSubtitle =>
      '\$PKWDWPL 文を出力するシリアル / Bluetooth ポートを選択します';

  @override
  String get pkwdwplRxOnly => '受信のみ';

  @override
  String get pkwdwplReadOnly => '受信専用 · 本機は一切送信しません';

  @override
  String get deviceConflictTitle => '2 つのリンクが同じデバイスに割り当てられています';

  @override
  String get deviceConflictDesc =>
      'TNC と PKWDWPL が同じデバイスを指すと、受信データが 2 つのリンクで分け合われます（送信はできるのに受信できない状態）。どちらかを別のデバイスに変更してください。TNC が優先され、PKWDWPL は接続を拒否します。';

  @override
  String get deviceInUseByTnc => 'TNC が使用中 — 重複して割り当てられません';

  @override
  String get deviceInUseByPkwdwpl => 'PKWDWPL が使用中 — 重複して割り当てられません';

  @override
  String rxOnlyBanner(String arg) {
    return '$arg 接続済み · 受信のみ（送信元が未接続）';
  }

  @override
  String get pkwdwplTip =>
      '無線機のメニューで PC / GPS ポートの出力形式を \"\$PKWDWPL\" に設定してください（通常 4800 8N1）。このリンクは受信専用で、一切送信しません。';

  @override
  String get pkwdwplStrictChecksum => '厳格なチェックサム（不一致は破棄）';

  @override
  String get pkwdwplStrictChecksumTip =>
      '既定ではオフ。不一致は破棄せず記録とログのみ行います。ローカル接続での不一致はファームウェアの書式差であることが多く、すべて破棄すると画面が空になり、かえって原因を追いにくくなります。';

  @override
  String get pkwdwplErrReadOnly => '受信専用リンクのため送信できません';

  @override
  String get pkwdwplStatTitle => '航点の受信';

  @override
  String pkwdwplStats(String rx) {
    return '航点を $rx 件受信';
  }

  @override
  String get pkwdwplStatRejected => '破棄/無効な文';

  @override
  String get pkwdwplStatMismatch => 'チェックサム不一致';

  @override
  String get pkwdwplStatIgnored => 'その他の NMEA 文（無視）';

  @override
  String get pkwdwplLogEmpty => 'PKWDWPL のログはまだありません';

  @override
  String get tncBindTitle => 'Bluetooth TNC';

  @override
  String get tncBindSubtitle => '無線機側の TNC を登録して接続します';

  @override
  String get tncBoundDevice => '登録済みデバイス';

  @override
  String get tncNotBound => '未登録';

  @override
  String get tncScanPaired => 'デバイスをスキャン（Bluetooth ペアリング済み + USB シリアル）';

  @override
  String get tncNoPaired =>
      'デバイスが見つかりません — システムの Bluetooth 設定で TNC をペアリングするか、USB シリアルケーブル（OTG）を接続してください';

  @override
  String get tncUnbind => '登録解除';

  @override
  String get tncConnectAction => 'TNC に接続';

  @override
  String get tncRestart => 'リンクを再起動';

  @override
  String get tncSupportedNo => 'このプラットフォームは TNC リンクに未対応です';

  @override
  String get tncNeedPermission =>
      'Bluetooth 機器のスキャンには Bluetooth 権限が必要です（USB シリアルのみの場合は不要。ケーブル接続時にシステムが別途確認します）';

  @override
  String get tncOpenFailedHint =>
      'デバイスを開けません。Windows の COM ポートは占有型です。他のソフトが使用していないか確認してください';

  @override
  String tncStats(String rx, String tx) {
    return '受信 $rx フレーム · 送信 $tx フレーム';
  }

  @override
  String get tncLog => 'リンクログ';

  @override
  String get tncLogEmpty => 'ログはまだありません';

  @override
  String get kissParamsTitle => 'KISS パラメータ';

  @override
  String get kissParamsSubtitle => 'TNC に直接送るリンク層パラメータ';

  @override
  String get kissTxDelay => '送信遅延 (ms)';

  @override
  String get kissTxDelayTip =>
      'KISS TXDELAY（10ms 単位）。データ送出前に PTT が立ち上がるまでの待ち時間';

  @override
  String get kissTxTail => '送信テール (ms)';

  @override
  String get kissTxTailTip => 'KISS TXTAIL（10ms 単位）。無線機によっては末尾の保持が必要';

  @override
  String get kissPersistence => 'パーシステンス P';

  @override
  String get kissPersistenceTip =>
      'KISS PERSISTENCE（0〜255）。小さいほど譲り合い、共有チャネルの衝突を減らせます';

  @override
  String get kissSlotTime => 'スロットタイム (ms)';

  @override
  String get kissSlotTimeTip =>
      'KISS SLOTTIME（10ms 単位）。パーシステンスと共にチャネルアクセスを調整します';

  @override
  String get kissFullDuplex => '全二重';

  @override
  String get kissFullDuplexTip => 'KISS FULLDUPLEX。通常の無線機では必ずオフ（同時送受信は干渉します）';

  @override
  String get kissChannel => 'チャネル / KISS ポート';

  @override
  String get kissChannelTip => 'マルチチャネル TNC のみ複数ポート。単一チャネルの無線機は 0 のまま';

  @override
  String get kissMaxFrame => '最大フレーム長 (バイト)';

  @override
  String get kissMaxFrameTip =>
      'これを超えるパケットは送信しません（1200bd で AX.25 フレームは約 330 バイト）';

  @override
  String get kissHardwareCmd => 'ベンダーコマンド';

  @override
  String get kissHardwareVal => '値';

  @override
  String get kissHardwareTip => 'KISS SETHARDWARE (0x06)。ベンダー固有。-1 で送信しません';

  @override
  String get kissApplyParams => 'パラメータを送信';

  @override
  String get kissParamsSent => 'KISS パラメータを送信しました';

  @override
  String get kissBackToCommand => 'TNC コマンドモードへ戻る';

  @override
  String get kissBackToCommandTip =>
      'RETURN (0x0F) を送ります。多くの KISS TNC は転送を停止し、リンク再起動が必要です';

  @override
  String get kissRfPath => 'RF デジピータパス';

  @override
  String get kissRfPathTip => 'オンエアで使うデジピータ（例 WIDE1-1,WIDE2-1）。空欄なら指定しません';

  @override
  String get kissRfBeacon => 'RF ビーコンを許可';

  @override
  String get kissRfBeaconTip => 'オンにすると位置を定期的に送信します。送信はご自身の免許とコールサインで行ってください';

  @override
  String get kissAutoAck => '自動 ACK';

  @override
  String get kissAutoAckTip => 'オフにすると受信メッセージに ACK を返さず、チャネルの占有を減らせます';

  @override
  String get kissAutoReconnect => '切断後に自動再接続';

  @override
  String get kissNeedConnected => '先に TNC に接続してください';

  @override
  String get tncSwitchOn => 'オン';

  @override
  String get tncSwitchOff => 'オフ';

  @override
  String get connTncSourceHint => 'TNC モードではサーバーとフィルタを使わないため、該当設定は無効です';

  @override
  String get connectTncBar => '「接続」で TNC リンクを開きます';

  @override
  String connectingToTnc(String name) {
    return 'TNC に接続中 · $name';
  }

  @override
  String get tncMsgTitle => 'RF（TNC）モード';

  @override
  String get tncMsgDesc => 'RF チャネルは共有資源のため、メッセージ機能は制限されます';

  @override
  String get tncGroupDisabled => 'RF モードではグループ配信は利用できません';

  @override
  String tncMsgLimitHint(String n) {
    return '1 通あたり $n 文字（APRS 仕様）';
  }

  @override
  String get tncMsgTooLong => 'RF モードの 1 通あたりの文字数上限を超えています';

  @override
  String get licenseSection => 'ライセンス';

  @override
  String get licenseName => 'GNU GPL v3';

  @override
  String get licenseStatement =>
      '本ソフトウェアは GNU GPL v3 に基づいて公開されています。ライセンス条項を守る限り、実行・調査・改変・再配布が可能です。改変・再配布の際は GPL v3 の該当義務を守る必要があります。本ソフトウェアはいかなる保証も伴いません。';

  @override
  String get licenseText => 'ライセンスを表示';

  @override
  String get oobeAgreeTitle => '利用規約とライセンス';

  @override
  String get oobeAgreeBody =>
      'APRSlocus へようこそ！ご利用前に以下の条項をお読みいただき、同意してください。APRS データは公開情報です。送信した時点で、世界中の APRS ネットワークに受信・保存・転送される可能性があります。';

  @override
  String get oobeAgreeCheck => '「利用規約」および GPL-3.0 ライセンスを読み、同意します';

  @override
  String get oobeAgreeNeed => '先に「利用規約」をお読みいただき、同意にチェックを入れてください';

  @override
  String get oobeDeclineExit => '同意せず終了';

  @override
  String get userAgreement => '利用規約';

  @override
  String get beaconWarnTitle => 'ビーコン間隔が短すぎます';

  @override
  String get beaconWarnBody =>
      'APRS-IS では移動局のビーコン間隔を 60 秒以上にすることが推奨されています。短すぎる送信は濫用と見なされ、サーバーから切断される場合があります。この間隔のまま使用しますか？';

  @override
  String get beaconWarnKeep => 'このまま使用';

  @override
  String get beaconWarnFix => '60 秒に戻す';

  @override
  String get features => '機能';

  @override
  String get openSource => 'オープンソース謝辞';

  @override
  String get feedback => 'フィードバック';

  @override
  String get officialWebsite => '公式サイト';

  @override
  String get qqGroup => 'QQ グループ';

  @override
  String get projectRepo => 'リポジトリ';

  @override
  String get testMembers => 'テストメンバー';

  @override
  String get aiSupport => 'AI 計算リソース提供';

  @override
  String get copyAppInfo => 'アプリ情報をコピー';

  @override
  String get appInfoCopied => 'アプリ情報をコピーしました';

  @override
  String get shareApp => 'APRSlocus を共有';

  @override
  String get shareToSystem => 'システムへ共有';

  @override
  String get shareToSystemDesc => 'WeChat / QQ / SMS など';

  @override
  String get copyShareText => '共有テキストをコピー';

  @override
  String get openDownload => 'ダウンロードページを開く';

  @override
  String get shareTextCopied => '共有テキストをコピーしました。友達に貼り付けて送信できます';

  @override
  String get shareText =>
      'APRSlocus — アマチュア無線 APRS 追跡・地図アプリ 📡\nリアルタイムな局の追跡、メッセージの送受信、ビーコン送信。Android / Windows に対応。\n公式サイト：https://aprslocus.theez.top/\nダウンロード：https://github.com/dariondong/APRSLocus/releases';

  @override
  String get enterCallsign => 'コールサインを入力してください';

  @override
  String get enterValidCall => '有効なコールサインを入力してください';

  @override
  String get stationSettings2 => '無線局設定';

  @override
  String get beaconSettings => '位置ビーコン送信';

  @override
  String get displaySettings2 => '表示設定';

  @override
  String get chatSettings2 => 'チャット設定';

  @override
  String get dataSettings2 => 'データ設定';

  @override
  String get advancedSettings2 => '詳細設定';

  @override
  String get connectionSettings2 => '接続設定';

  @override
  String get myCallsign => 'マイコールサイン';

  @override
  String get beaconEnabled => '位置ビーコンを有効化';

  @override
  String get smartBeacon => 'スマートビーコン（速度別）';

  @override
  String get packetConsole => 'パケットコンソール';

  @override
  String get rawMode => '生データ';

  @override
  String get parsedMode => '解析済み';

  @override
  String get position => '位置';

  @override
  String get statusType => '状態';

  @override
  String get objectType => 'オブジェクト';

  @override
  String packetStats(Object ppm, Object rx, Object tx) {
    return '受信 $rx · 送信 $tx · $ppm/分';
  }

  @override
  String get searchPacket => 'コールサイン・宛先・生データを検索…';

  @override
  String get noMatchingPackets => '一致するパケットがありません';

  @override
  String get inject => '注入';

  @override
  String get manualInject => 'APRS パケットを手動注入';

  @override
  String get injected => 'パケットを注入しました';

  @override
  String get clearedPackets => 'パケットを消去しました';

  @override
  String get clearPackets => 'パケットを消去';

  @override
  String noPositionInfo(Object call) {
    return '$call の位置情報がありません（パケットに位置が含まれていません）';
  }

  @override
  String get copiedPacket => 'パケットをコピーしました';

  @override
  String get mapPickMode => '地図で位置を選択';

  @override
  String get mapPickDesc => '地図をタップして位置を設定';

  @override
  String foundStations(Object count, Object q) {
    return '「$q」に一致する局が $count 件';
  }

  @override
  String get tapMapHint => '地図をタップで局表示 · ピンチでズーム';

  @override
  String myLocationPanel(Object call) {
    return '自分の位置 · $call';
  }

  @override
  String get speedLabel => '速度';

  @override
  String get courseLabel => 'コース';

  @override
  String get telemetryTitle => '速度 / 高度の推移';

  @override
  String get range10m => '10 分';

  @override
  String get range30m => '30 分';

  @override
  String get range1h => '1 時間';

  @override
  String get range3h => '3 時間';

  @override
  String get rangeAll => 'すべて';

  @override
  String get beaconIntervalLabel => '送信間隔';

  @override
  String get beaconsSentLabel => '送信済み';

  @override
  String get nextBeaconLabel => '次回送信';

  @override
  String positionBeacon(Object grid) {
    return '位置ビーコン · グリッド $grid';
  }

  @override
  String get manualBeacon => '今すぐ送信';

  @override
  String get mapPickNow => '地図で選択';

  @override
  String pickedCoord(Object grid, Object lat, Object lng) {
    return '地図で位置を設定 · $lat, $lng · グリッド $grid';
  }

  @override
  String onlineCount(Object count) {
    return '$count オンライン';
  }

  @override
  String movingCount(Object count) {
    return '$count 移動';
  }

  @override
  String stationCount(Object count) {
    return '$count 局';
  }

  @override
  String get locateMe => '現在地';

  @override
  String get layerFilter => 'レイヤー';

  @override
  String get showAll => 'すべて表示';

  @override
  String get otherType => 'その他';

  @override
  String zoomLevel(Object z) {
    return 'ズーム $z';
  }

  @override
  String get datumGcj => 'GCJ-02';

  @override
  String get datumWgs => 'WGS-84';

  @override
  String distKm(Object d) {
    return '$d km';
  }

  @override
  String get noStationInView => 'この地域に局がありません · タップで全表示';

  @override
  String get noStationHelp => 'この地域に局がありません · タップでヘルプ';

  @override
  String get mapHelpTitle => '地図のヘルプ';

  @override
  String get mapHelpIntro =>
      '現在の表示範囲に局がありません。考えられる原因：APRS-IS に未接続、受信範囲が狭い、近くに活動中の局がない。';

  @override
  String get mapHelpMove => '移動 / ズーム：1 本指でドラッグ、ピンチまたはホイールでズーム';

  @override
  String get mapHelpStation => '局の表示：マーカーをタップで選択・中央寄せ、ダブルタップで詳細';

  @override
  String get mapHelpLayer => 'レイヤーと地図：右上のボタンで局の種類を絞り込み、地図スタイルを切り替え';

  @override
  String get mapHelpLocate => '現在地：右下の「現在地」をタップすると自分の位置に戻ります';

  @override
  String get mapHelpSearch => '検索：上部の検索欄にコールサインを入力すると、その局へ素早く移動できます';

  @override
  String get allChangelog => 'すべての更新履歴';

  @override
  String get tapToView => 'タップで表示';

  @override
  String get beaconNow => '今すぐ送信';

  @override
  String get meLabel => '自分';

  @override
  String get mapZoomIn => '拡大';

  @override
  String get mapZoomOut => '縮小';

  @override
  String get mapHome => '中心に戻る';

  @override
  String get mapLocate => '現在地';

  @override
  String get mapLayers => 'レイヤー';

  @override
  String get featureLiveMap => 'オンライン地図';

  @override
  String get featureLiveMapDesc => 'GCJ-02 座標。スムーズなズームとドラッグ';

  @override
  String get featureGps => 'GPS 測位';

  @override
  String get featureGpsDesc => 'Android ネイティブ測位。Google サービス不要';

  @override
  String get featureBeacon => 'ビーコン送信';

  @override
  String get featureBeaconDesc => '内容・頻度・シンボルをカスタマイズ可能。APRS 標準形式に対応';

  @override
  String get featureMsg => 'メッセージ送受信';

  @override
  String get featureMsgDesc => 'フィード＋会話ビュー。Unicode テキストと自動応答に対応';

  @override
  String get featureAutoConnect => '自動接続';

  @override
  String get featureAutoConnectDesc => '公共サーバーへ自動接続し、バックグラウンドでもオンラインを維持';

  @override
  String get featureLayerFilter => 'レイヤーフィルター';

  @override
  String get featureLayerFilterDesc => '種類で絞り込み：移動・固定・デジピーター・気象・FMO';

  @override
  String get featureFmo => 'FMO 局';

  @override
  String get featureFmoDesc => 'FMO データを自動認識し、構造化して表示';

  @override
  String get osFlutter => 'Flutter';

  @override
  String get osFlutterDesc => 'Google のクロスプラットフォーム UI フレームワーク';

  @override
  String get osAmap => 'AMAP';

  @override
  String get osAmapDesc => '地図タイルサービス';

  @override
  String get osAprs => 'APRS-IS';

  @override
  String get osAprsDesc => '世界的な APRS データネットワーク';

  @override
  String get osHam => 'アマチュア無線';

  @override
  String get osHamDesc => 'APRS 愛好家の皆さんの貢献';

  @override
  String get authorName => 'Darion';

  @override
  String get authorCall => 'コールサイン';

  @override
  String get website => 'ウェブサイト';

  @override
  String get sponsorAuthor => '作者 BG7LZQ';

  @override
  String get sponsorAuthorItems => '授業の合間を縫って本プロジェクトを開発・維持';

  @override
  String get sponsorGroup => 'STUDENT HAMS';

  @override
  String get sponsorGroupItems => 'グループからの資金支援に感謝します';

  @override
  String get sponsorBgp => 'BG7PGW';

  @override
  String get sponsorBgpItems => 'ミーシュエビンチャン（MIXUE）1 杯のご馳走に感謝 🧋';

  @override
  String get sponsorEvery => 'すべての支援者の皆さま';

  @override
  String get sponsorEveryItems => '皆さまの支援のひとつひとつが力になります';

  @override
  String get donateWechat => 'WeChat での支援';

  @override
  String get donateWechatDesc => '長押しで QR を保存 · タップで拡大';

  @override
  String get donateAlipay => 'Alipay での支援';

  @override
  String get donateAlipayDesc => '作者に連絡して QR コードを取得してください';

  @override
  String get nonprofitNote => '本プロジェクトは非営利の学習・交流プロジェクトです。\n支援はサーバーと開発費にのみ使用します';

  @override
  String get myStation => 'マイ無線局';

  @override
  String get callSsid => 'コールサイン · SSID';

  @override
  String get ssid => 'SSID';

  @override
  String get ssidDesc => 'SSID は機器を識別するコールサインの接尾辞です（例：BG7ABC-9 の -9）';

  @override
  String get callComment => '局のメモ';

  @override
  String get callCommentHint => 'ビーコン送信時に付けるメモ';

  @override
  String get callSymbol => '局のシンボル';

  @override
  String get callSymbolDesc => 'シンボルは位置ビーコンと一緒に送信されます';

  @override
  String get autoReply => '自動応答';

  @override
  String get sendBeacon => 'ビーコンを送信';

  @override
  String get mapTypeDesc =>
      '「マップ 2.0（ベクター）」は端末側でベクターを描画するため通信量が少なく、拡大しても鮮明です。ラスター図源はオンラインタイルのため、画質は回線に依存します。';

  @override
  String get offlineLoading => '読み込み中…';

  @override
  String get offlineMap => 'オフラインマップ';

  @override
  String get offlineMapDesc => '地図タイルを事前に保存し、ネットワークなしでも地図を表示します';

  @override
  String get offlineMapFooter => 'タイルは端末内のみに保存され、送信されません。図源ごとに別々にキャッシュされます';

  @override
  String get offlineRegions => 'オフラインエリア';

  @override
  String get offlineRegionsDesc => 'ダウンロード済みの範囲はオフラインで地図表示できます';

  @override
  String get offlineNew => '新規エリア';

  @override
  String get offlineNoRegions => 'オフラインエリアがありません';

  @override
  String get offlineNoRegionsHint => '右上の「新規エリア」からよく行く場所を保存できます';

  @override
  String get offlineCacheUsage => 'タイルキャッシュ';

  @override
  String get offlineCacheUsageDesc => '地図閲覧時に自動保存。エリアを手動でダウンロードも可能';

  @override
  String get offlineClearCache => 'タイルキャッシュを全消去';

  @override
  String get offlineClearCacheConfirm => 'ダウンロード済みの地図タイルをすべて削除しますか？';

  @override
  String get offlineClearCacheConfirmBody =>
      'ダウンロード済みタイルは削除されます。エリア記録は残るため、再ダウンロードが必要です。';

  @override
  String get offlineAreaHint => '現在の表示範囲がダウンロード範囲です';

  @override
  String get offlineSource => '図源';

  @override
  String get offlineName => '名前';

  @override
  String get offlineNameHint => '例：自宅周辺';

  @override
  String get offlineStartDownload => 'ダウンロード開始';

  @override
  String get offlineStatusPending => '待機中';

  @override
  String get offlineStatusRunning => 'ダウンロード中';

  @override
  String get offlineStatusPaused => '一時停止';

  @override
  String get offlineStatusDone => '完了';

  @override
  String get offlineStatusCanceled => 'キャンセル済み';

  @override
  String get offlineStatusFailed => '失敗';

  @override
  String get offlinePause => '一時停止';

  @override
  String get offlineResume => '再開';

  @override
  String get offlineCancelDownload => 'キャンセル';

  @override
  String get offlineDeleteKeepTiles => '記録のみ削除（タイルは保持）';

  @override
  String get offlineDeleteWithTiles => '記録とタイルを削除';

  @override
  String get offlineDownloadBusy => '別のダウンロードが進行中です。完了かキャンセルを待ってください';

  @override
  String get offlineCacheSwitch => '地図タイルをキャッシュ';

  @override
  String get offlineCacheSwitchDesc => '地図閲覧時にタイルを端末へ保存し、後でオフライン表示できます';

  @override
  String get offlineOnlySwitch => 'オフラインタイルのみ';

  @override
  String get offlineOnlySwitchDesc =>
      'ネットワークからタイルを読み込みません。保存済み/キャッシュのみ使用（通信量節約）';

  @override
  String get offlineCacheDisabled => 'このプラットフォームではタイルキャッシュを利用できません';

  @override
  String get offlineSwitchFirst => '先に「地図タイルをキャッシュ」をオンにしてください';

  @override
  String get offlineOnlyWarn => '「オフラインタイルのみ」がオンです。地図が一部表示されない場合があります';

  @override
  String offlineTilesDownloaded(String n) {
    return '$n タイルを保存済み';
  }

  @override
  String offlineZoomLevels(String min, String max) {
    return 'ズーム $min–$max';
  }

  @override
  String offlineEstimate(String tiles, String size) {
    return '約 $tiles タイル · 約 $size';
  }

  @override
  String offlineTooManyTiles(String tiles) {
    return '範囲が広すぎます（約 $tiles タイル）。範囲を狭めるか最大ズームを下げてください';
  }

  @override
  String offlineDeleteRegionConfirm(String name) {
    return 'オフラインエリア「$name」を削除しますか？';
  }

  @override
  String offlineDeleteTileCount(String n) {
    return '約 $n タイルを削除します';
  }

  @override
  String offlineDeletingTiles(String done, String total) {
    return '削除中 $done/$total';
  }

  @override
  String offlineFailedCount(String n) {
    return '$n 件失敗';
  }

  @override
  String offlineTileProgress(String done, String total) {
    return '$done/$total タイル';
  }

  @override
  String get msgHistory => 'メッセージ履歴';

  @override
  String get statistics => '統計';

  @override
  String get clearData => 'データを消去';

  @override
  String get favorites => 'お気に入り / 手動';

  @override
  String get favoriteStations => 'お気に入りの局';

  @override
  String get manualStations => '手動追加した局';

  @override
  String get wgs84 => 'WGS-84';

  @override
  String get gcj02 => 'GCJ-02';

  @override
  String get onlyWgs84 => 'WGS-84 のみ';

  @override
  String get contactList => '連絡先';

  @override
  String get contactDesc => 'メッセージ・連絡先のフィルター規則';

  @override
  String get dataClearDesc => 'メッセージ・パケット・局などのローカルデータを消去';

  @override
  String get advancedDesc => 'ラボと開発者ツール';

  @override
  String get labDesc =>
      'ラボ機能はテスト中で、使用感に影響する場合があります。既定では縦向きに固定され、有効にすると横向きが使えます。';

  @override
  String get systemLog => 'システムログ';

  @override
  String get devDesc => '開発者向けデバッグツール';

  @override
  String get simData => 'デモデータを有効化（サンプル局／パケット）';

  @override
  String get rxTx => '受信 / 送信';

  @override
  String get stationCount2 => '局数';

  @override
  String get appInfo => 'アプリ情報';

  @override
  String get clearMessages => 'チャット履歴をすべて消去';

  @override
  String get clearPackets2 => 'パケットを消去';

  @override
  String get clearStations => '局リストを消去';

  @override
  String get clearCache => 'キャッシュを消去';

  @override
  String get resetAll => 'すべての設定をリセット';

  @override
  String get resetAllDesc => '初期状態に戻す';

  @override
  String get dataPersistence => '局データの保存';

  @override
  String get autoSaveStations => '局データを自動保存';

  @override
  String get gridFormat => 'グリッド形式';

  @override
  String get coordsFormat => '座標形式';

  @override
  String get appVersion => 'バージョン';

  @override
  String get appVersionDesc => '現在のアプリバージョン';

  @override
  String get stationDetail => '局の詳細';

  @override
  String get backToTop => 'トップへ戻る';

  @override
  String get installApk => 'APRSlocus をインストール';

  @override
  String get install => 'インストール';

  @override
  String get cancelInstall => 'キャンセル';

  @override
  String get openFolder => 'フォルダを開く';

  @override
  String get browse => '参照';

  @override
  String get downloadUpdate => '更新をダウンロード';

  @override
  String get downloadNow => '今すぐダウンロード';

  @override
  String get downloading => 'ダウンロード中';

  @override
  String downloadProgress(Object p) {
    return 'ダウンロード中 $p%';
  }

  @override
  String get downloadComplete => 'ダウンロード完了';

  @override
  String get downloadFailed => 'ダウンロード失敗';

  @override
  String get installNow => '今すぐインストール';

  @override
  String get installComplete => 'インストール完了';

  @override
  String get openInstallDir => 'インストール先を開く';

  @override
  String get deletePackage => 'インストーラーを削除';

  @override
  String deletePackageConfirm(Object file) {
    return 'インストーラー $file を削除しますか？';
  }

  @override
  String get deleteAllPackages => 'すべてのインストーラーを削除';

  @override
  String deleteAllPackagesWithCount(Object count) {
    return 'すべてのインストーラーを削除（$count 件）';
  }

  @override
  String deleteAllPackagesConfirm(Object count, Object size) {
    return 'ダウンロード済みの $count 件のインストーラー（合計 $size）を削除します。よろしいですか？';
  }

  @override
  String get historyVersions => '過去のバージョン';

  @override
  String get current => '現在';

  @override
  String get newVersion => '新しいバージョン';

  @override
  String get latestVersion => '最新バージョンです';

  @override
  String get currentVersion => 'APRSlocus の現在のバージョン';

  @override
  String get checking => '新しいバージョンを確認中…';

  @override
  String get checkingGitCode => 'GitCode リポジトリを確認';

  @override
  String get updateFailed => '更新の確認に失敗しました';

  @override
  String get noUpdateFound => '最新バージョンです';

  @override
  String get newVersionFound => '新しいバージョンがあります';

  @override
  String get downloadAgain => 'インストーラーを再ダウンロード';

  @override
  String get openDownloads => 'ダウンロード先を開く';

  @override
  String get releaseNotes => '更新履歴';

  @override
  String currentVsRepo(Object local, Object remote) {
    return 'インストール済み v$local · 最新 v$remote';
  }

  @override
  String installSize(Object os, Object size) {
    return '$os インストーラーのサイズ：$size';
  }

  @override
  String get alreadyDownloaded => 'インストーラーはダウンロード済み';

  @override
  String get downloadReady => 'インストーラーをダウンロード';

  @override
  String get appInstallDir => 'インストール先';

  @override
  String get runInstaller => 'インストーラーを実行';

  @override
  String get downloadUpdateTip => '更新をダウンロードして自動的に開く';

  @override
  String get openDownloadFolder => 'ダウンロード先を開く';

  @override
  String groupBubble(String name) {
    return 'グループ · $name';
  }

  @override
  String get groupInviteTitle => 'グループ招待';

  @override
  String groupInviteFrom(String from) {
    return '$from さんがグループに招待しました';
  }

  @override
  String groupNameValue(String name) {
    return 'グループ名：$name';
  }

  @override
  String groupCallsignValue(String call) {
    return 'グループのコールサイン：$call';
  }

  @override
  String groupInviteAccepted(String name) {
    return '招待を承諾し、$name に参加しました';
  }

  @override
  String get accept => '承認';

  @override
  String groupInviteRejected(String name) {
    return '$name の招待を拒否しました';
  }

  @override
  String get reject => '拒否';

  @override
  String get appTagline => 'APRS 位置追跡';

  @override
  String gridValue(String grid) {
    return 'グリッド $grid';
  }

  @override
  String packetsPerMinute(int count) {
    return '$count/分';
  }

  @override
  String get demo => 'デモ';

  @override
  String nextBeaconIn(String time) {
    return '次回送信 $time';
  }

  @override
  String beaconCount(int count) {
    return 'ビーコン $count 回';
  }

  @override
  String beaconSentAprsIs(String grid) {
    return '位置を送信しました · グリッド $grid · APRS-IS へ送信済み';
  }

  @override
  String beaconSentDemo(String grid) {
    return '位置を送信しました · グリッド $grid · デモ';
  }

  @override
  String get getLocation => '位置情報を取得';

  @override
  String get disconnect => '切断';

  @override
  String get connectAprsIs => 'APRS-IS に接続';

  @override
  String get packetsReceived => '受信';

  @override
  String get passcodeUnverified => 'Passcode 未検証';

  @override
  String get passcodeWarning =>
      'ログイン用 Passcode が誤っている可能性があり、メッセージの送受信が正常に行えない場合があります';

  @override
  String get goSettings => '設定へ';

  @override
  String get connectingServer => 'サーバーに接続中…';

  @override
  String get notConnectedAprsServer => 'APRS-IS サーバーに未接続';

  @override
  String connectingToServer(String server, int port) {
    return '$server:$port に接続中…';
  }

  @override
  String get connectNearbyDesc => '接続すると、近くの局の位置情報とメッセージを受信できます';

  @override
  String get connectAction => '接続';

  @override
  String get backgroundRunTip =>
      'バックグラウンド動作のヒント：バックグラウンドでの位置送信を維持するため、システム設定で APRSlocus のバックグラウンド動作を許可し、省電力最適化を無効にし、自動起動を許可してください。';

  @override
  String get connectedAprsIs => 'APRS-IS に接続しました';

  @override
  String get qqGroupDesc => 'APRSlocus · 不具合報告・情報交換';

  @override
  String get reselectPoint => '選び直す';

  @override
  String get disableClustering => 'クラスタリングを無効化';

  @override
  String get enableClustering => 'クラスタリングを有効化';

  @override
  String get heatmap => '局のヒートマップ';

  @override
  String get heatmapHint => '地図を縮小すると局の密度ヒートマップを表示';

  @override
  String get groupTracking => 'グループ追跡';

  @override
  String get groupTrackingHint =>
      '気になるコールサインをグループにして、大きな地図で継続的に追跡できます（車列・仲間との同行）。横向きにも対応。';

  @override
  String get newTrackGroup => '追跡グループを作成';

  @override
  String get trackGroupNameHint => 'グループ名（例：週末サイクリング）';

  @override
  String get editTrackGroup => '追跡グループを編集';

  @override
  String get deleteTrackGroup => '追跡グループを削除';

  @override
  String deleteTrackGroupConfirm(Object name) {
    return '追跡グループ「$name」を削除しますか？';
  }

  @override
  String get pickTrackMembers => 'メンバーを選択（追跡するコールサインにチェック）';

  @override
  String get saveAndTrack => '保存して追跡';

  @override
  String get trackGroupsEmptyHint =>
      '追跡グループがまだありません。「追跡グループを作成」から追跡したいコールサインのグループを作成してください。';

  @override
  String trackMemberSub(Object seen, Object type) {
    return '$type · $seen';
  }

  @override
  String get trackGroupEmpty =>
      'グループのメンバーの位置データがまだありません（未受信または未送信）。下をタップするとメンバーを編集できます。';

  @override
  String get trackActive => 'オンライン';

  @override
  String get trackWaitingPos => '位置を待機中…';

  @override
  String get offlineShort => 'オフライン';

  @override
  String get stoppedShort => '停止';

  @override
  String trackHeader(Object fixed, Object online, Object total) {
    return '$total 名 · $online オンライン · $fixed 測位済み';
  }

  @override
  String get groupChatShort => 'チャット';

  @override
  String groupChatTitle(Object name) {
    return 'グループ · $name';
  }

  @override
  String chatWithTitle(Object call) {
    return '$call とのチャット';
  }

  @override
  String get chatToGroupHint => 'グループ全体にメッセージ…';

  @override
  String chatToHint(Object call) {
    return '$call に送信…';
  }

  @override
  String get noMessagesHint => 'メッセージがありません。送ってみましょう';

  @override
  String trackModeFollow(Object call) {
    return '$call を追跡';
  }

  @override
  String get trackModeMe => '自分を追跡';

  @override
  String get trackModeFitAll => '全体表示を維持';

  @override
  String get fitAll => '全体表示';

  @override
  String get noStationsYet => '局データがありません。APRS-IS に接続すると選択できます。';

  @override
  String get noPackets => 'パケットがありません';

  @override
  String secondsAgo(int count) {
    return '$count 秒前';
  }

  @override
  String minutesAgo(int count) {
    return '$count 分前';
  }

  @override
  String hoursAgo(int count) {
    return '$count 時間前';
  }

  @override
  String daysAgo(int count) {
    return '$count 日前';
  }

  @override
  String copiedCoordsValue(String coords) {
    return '座標をコピーしました：$coords';
  }

  @override
  String copiedGridValue(String grid) {
    return 'グリッドをコピーしました：$grid';
  }

  @override
  String distanceBearing(String distance, String bearing) {
    return '自分から ${distance}km · 方位 $bearing°';
  }

  @override
  String weatherDataValue(String data) {
    return '気象データ · $data';
  }

  @override
  String get symbolLabel => 'シンボル';

  @override
  String get digipeaterTapHint => 'デジピーターをタップするとその局の詳細を開きます';

  @override
  String get copiedFmoInfo => 'FMO 情報をコピーしました';

  @override
  String get copiedAprslocusInfo => 'APRSlocus 情報をコピーしました';

  @override
  String trackPoints(int count) {
    return '軌跡（$count 点）';
  }

  @override
  String sendMessageTo(String call) {
    return '$call にメッセージ…';
  }

  @override
  String get navigationUnavailable => '地図アプリがインストールされておらず、他の地図アプリも開けませんでした';

  @override
  String stationNoData(String call) {
    return '局 $call のデータはまだ受信していません';
  }

  @override
  String get software => 'ソフトウェア';

  @override
  String get close => '閉じる';

  @override
  String get nameLabel => '名前';

  @override
  String get viewSponsorDetails => '作者とスポンサーの詳細を見る →';

  @override
  String get thanks => 'ありがとう';

  @override
  String get qqSoftwareName => 'APRSlocus';

  @override
  String get usageNotice =>
      '本ソフトウェアはアマチュア無線家の学習・交流目的のみに使用してください。\n現地の無線関連法規を遵守してください';

  @override
  String get licenseNotice => 'GNU GPL v3 · Copyright © BG7LZQ';

  @override
  String appInfoText(String version) {
    return 'APRSlocus v$version\n作者：BG7LZQ (Darion)\nサイト：Theez.top';
  }

  @override
  String get eggBg7lzq => 'おっと、何してるの〜';

  @override
  String get eggBg7pgw => '本気？';

  @override
  String get eggBg7lmw => '黙ったまま…';

  @override
  String get eggBg7osl => '度胸あるね';

  @override
  String get manualCallsignHint => 'コールサインを手動で入力して追加';

  @override
  String get noPacketReceived => 'パケットを受信していません';

  @override
  String get feedMode => 'フィード';

  @override
  String get conversationMode => 'チャット';

  @override
  String get messageFeed => 'メッセージフィード';

  @override
  String messageTotal(int count) {
    return '全 $count 件';
  }

  @override
  String get noMessages => 'メッセージがありません';

  @override
  String get copiedClipboard => 'クリップボードにコピーしました';

  @override
  String get groupShortLabel => 'グループ';

  @override
  String get conversations => 'チャット';

  @override
  String get noConversations => 'チャットがありません';

  @override
  String get groupNotFound => 'グループが存在しません';

  @override
  String get invite => '招待';

  @override
  String get manage => '管理';

  @override
  String get noGroupMessages => 'グループにメッセージがありません';

  @override
  String get selectConversation => 'チャットを選択して開始';

  @override
  String get newConversation => '新しいチャット';

  @override
  String get newConversationDesc => 'コールサインを入力して新しいチャットを開始';

  @override
  String get callsignExample => 'コールサイン（例：BG7ABC）';

  @override
  String get start => '開始';

  @override
  String get broadcastMessage => '一斉送信';

  @override
  String get noStations => '局がありません';

  @override
  String get broadcastHint => 'ヒント：各メッセージは受信者ごとに個別に送信されます';

  @override
  String broadcastSent(int count) {
    return '$count 人に一斉送信しました';
  }

  @override
  String get searchCallsign => 'コールサインを検索…';

  @override
  String get broadcastContentHint => '一斉送信する内容を入力…';

  @override
  String get groupNameHint => 'グループ名を入力';

  @override
  String get create => '作成';

  @override
  String groupCallsignLine(String call) {
    return 'グループのコールサイン：$call';
  }

  @override
  String get noMembers => 'メンバーがいません';

  @override
  String get inviteMembersHint => '下の「メンバーを招待」から追加してください';

  @override
  String get remove => '削除';

  @override
  String get inviteMembers => 'メンバーを招待';

  @override
  String get deleteGroup => 'グループを削除';

  @override
  String deleteGroupConfirm(String name) {
    return '「$name」を削除しますか？この操作は取り消せません。';
  }

  @override
  String get deleteConversation => 'チャットを削除';

  @override
  String deleteConversationConfirm(Object call) {
    return '$call とのチャット履歴を削除しますか？会話はリストからも削除されます。この操作は取り消せません。';
  }

  @override
  String clearGroupChatConfirm(Object name) {
    return '「$name」のチャット履歴を消去しますか？この操作は取り消せません。';
  }

  @override
  String memberOnlineCount(int members, int online) {
    return '$members 名 · $online オンライン';
  }

  @override
  String get leaveGroup => 'グループを退出';

  @override
  String leaveGroupConfirm(String name) {
    return '「$name」を退出しますか？このグループからのメッセージは届かなくなります。';
  }

  @override
  String leftGroup(String name) {
    return '$name を退出しました';
  }

  @override
  String get leave => '退出';

  @override
  String inviteMembersTo(String name) {
    return '$name にメンバーを招待';
  }

  @override
  String get manualCallsign => 'コールサインを手動入力';

  @override
  String inviteSent(String call) {
    return '$call に招待を送信しました';
  }

  @override
  String get noMoreOnlineStations => 'これ以上オンラインの局はありません';

  @override
  String get invited => '招待済み';

  @override
  String get tapToInvite => 'タップで招待';

  @override
  String get done => '完了';

  @override
  String get addContact => '連絡先を追加';

  @override
  String get addContactDesc => 'コールサインを入力して連絡先に追加';

  @override
  String contactAdded(String call) {
    return '連絡先 $call を追加しました';
  }

  @override
  String get add => '追加';

  @override
  String get stationary => '停止';

  @override
  String get unknown => '不明';

  @override
  String get none => 'なし';

  @override
  String get manual => '手動';

  @override
  String get management => '管理';

  @override
  String get debugLabel => 'デバッグ';

  @override
  String get information => '情報';

  @override
  String get warning => '警告';

  @override
  String get errorLabel => 'エラー';

  @override
  String countTimes(int count) {
    return '$count 回';
  }

  @override
  String countItems(int count) {
    return '$count 個';
  }

  @override
  String countEntries(int count) {
    return '$count 件';
  }

  @override
  String aprsSymbolName(String symbol) {
    String _temp0 = intl.Intl.selectLogic(symbol, {
      'car': '自動車',
      'police': '警察',
      'person': '人物',
      'digitalRepeater': 'デジピーター',
      'telephone': '電話',
      'dxCluster': 'DX クラスタ',
      'hfGateway': 'HF ゲートウェイ',
      'smallAircraft': '小型機',
      'mobileSatellite': '移動衛星',
      'disabled': '身体障害者',
      'snowmobile': 'スノーモービル',
      'redCross': '赤十字',
      'scouts': 'ボーイスカウト',
      'house': '住宅',
      'redX': '赤い ×',
      'redDot': '赤い点',
      'fire': '火災',
      'campground': 'キャンプ場',
      'motorcycle': 'オートバイ',
      'train': '列車',
      'fileServer': 'ファイルサーバー',
      'hurricane': 'ハリケーン',
      'dfTriangle': 'DF 三角',
      'postOffice': '郵便局',
      'largeAircraft': '大型機',
      'weatherStation': '気象観測局',
      'satelliteDish': '衛星アンテナ',
      'ambulance': '救急車',
      'bicycle': '自転車',
      'commandPost': '指揮所',
      'fireStation': '消防署',
      'horse': '乗馬',
      'fireTruck': '消防車',
      'glider': 'グライダー',
      'hospital': '病院',
      'fmoStation': 'FMO 局',
      'jeep': 'ジープ',
      'truck': 'トラック',
      'laptop': 'ノートPC',
      'micERepeater': 'Mic-E 中継',
      'node': 'ノード',
      'emergencyOps': '緊急対策本部',
      'dog': '犬',
      'gridSquare': 'グリッド',
      'repeaterTower': '中継タワー',
      'boat': '船舶',
      'truckStop': 'トラックステーション',
      'semiTrailer': 'セミトレーラー',
      'van': 'バン',
      'waterStation': '給水所',
      'yagi': '八木アンテナ',
      'shelter': '避難所',
      'rv': 'キャンピングカー',
      'weatherSymbol': '気象台',
      'balloon': '気球',
      'bus': 'バス',
      'shuttle': 'スペースシャトル',
      'policeCar': 'パトカー',
      'sailboat': 'ヨット',
      'school': '学校',
      'lodging': 'モーテル',
      'hotel': 'ホテル',
      'other': '不明',
    });
    return '$_temp0';
  }

  @override
  String symbolCategoryName(String category) {
    String _temp0 = intl.Intl.selectLogic(category, {
      'vehicles': '車両 / 交通',
      'facilities': '建物 / 施設',
      'weatherNature': '気象 / 自然',
      'emergencyRescue': '緊急対応',
      'airWater': '航空 / 水上',
      'communications': '通信 / その他',
      'other': 'その他',
    });
    return '$_temp0';
  }

  @override
  String countryName(String code) {
    String _temp0 = intl.Intl.selectLogic(code, {
      'CN': '中国',
      'KR': '韓国',
      'JP': '日本',
      'US': 'アメリカ',
      'CA': 'カナダ',
      'GB': 'イギリス',
      'DE': 'ドイツ',
      'FR': 'フランス',
      'IT': 'イタリア',
      'ES': 'スペイン',
      'RU': 'ロシア',
      'AU': 'オーストラリア',
      'NZ': 'ニュージーランド',
      'BR': 'ブラジル',
      'AR': 'アルゼンチン',
      'MX': 'メキシコ',
      'ZA': '南アフリカ',
      'IN': 'インド',
      'TH': 'タイ',
      'SG': 'シンガポール',
      'MY': 'マレーシア',
      'ID': 'インドネシア',
      'PH': 'フィリピン',
      'TW': '台湾',
      'HK': '香港',
      'MO': 'マカオ',
      'other': '不明',
    });
    return '$_temp0';
  }

  @override
  String get locationNotFixed => '未測位';

  @override
  String get simulatedLocation => 'シミュレーション位置';

  @override
  String get savedLocation => '保存された位置';

  @override
  String get locationFailed => '測位失敗';

  @override
  String get locationStopped => '測位を停止しました';

  @override
  String get locationFixed => '測位済み';

  @override
  String get locationPermission => '位置情報の権限を許可してください…';

  @override
  String get gpsLocating => 'GPS 測位中…';

  @override
  String get webLocationUnsupported => 'Web では自動測位に対応していません。座標を手動で入力してください';

  @override
  String locationStreamError(String error) {
    return '位置情報ストリームの異常：$error';
  }

  @override
  String locationInitError(String error) {
    return '位置情報の初期化に失敗しました：$error';
  }

  @override
  String get beaconDisabled => 'オフ';

  @override
  String get waitingForLocation => '測位を待機中';

  @override
  String get imminent => 'まもなく';

  @override
  String get connTapToConnect => '未接続 · 接続ボタンで APRS-IS に接続';

  @override
  String get connManuallyDisconnected => '未接続 · 手動で切断';

  @override
  String connAutoReconnect(int seconds) {
    return '接続が切れました · $seconds 秒後に再接続…';
  }

  @override
  String connConnectingTarget(String target) {
    return '$target に接続中…';
  }

  @override
  String connOnline(String call) {
    return '接続中 · $call オンライン';
  }

  @override
  String connRetry(int seconds) {
    return '接続失敗 · $seconds 秒後に再試行…';
  }

  @override
  String connPositionSent(String call) {
    return '接続中 · 位置を送信しました（$call）';
  }

  @override
  String get connDemoBeacon => '未接続 · 位置を送信しました（シミュレーション）';

  @override
  String get connPasscodeInvalid => '接続中 · 未検証（Passcode が誤っている可能性）';

  @override
  String get mapTypeAmap => 'AMAP';

  @override
  String get mapTypeAmapSatellite => 'AMAP 衛星';

  @override
  String get mapTypeVector => 'ベクター地図';

  @override
  String get amapGroup => '国内';

  @override
  String get domesticMaps => '中国の地図';

  @override
  String get internationalMaps => '海外の地図';

  @override
  String get metricUnits => 'メートル法 (km/h, m)';

  @override
  String get coordDisplay => '座標表示';

  @override
  String mapDefaultCoord(int level) {
    return '北京 · ズーム $level';
  }

  @override
  String secondsValue(int count) {
    return '$count 秒';
  }

  @override
  String get stationSettingsDetail => 'コールサイン・SSID・シンボル・メモ';

  @override
  String get stationIdentity => '無線局の識別';

  @override
  String get aprsCallsignHint => 'APRS コールサイン（例：BV2AAA）';

  @override
  String get displayInfo => '表示情報';

  @override
  String get ssidSuffix => 'SSID 接尾辞';

  @override
  String get chooseSsidSuffix => 'SSID 接尾辞を選択';

  @override
  String get mySymbol => 'マイシンボル';

  @override
  String get moreSymbols => 'その他のシンボル';

  @override
  String get allAprsSymbols => 'APRS シンボル一覧';

  @override
  String get beaconSettingsDetail => 'GPS ソース・ビーコン・手動位置';

  @override
  String get locationSource => '位置情報のソース';

  @override
  String get useDeviceLocation => '端末の位置情報を使用';

  @override
  String get manualCoordinates => '座標を手動入力';

  @override
  String get locationMode => '測位モード';

  @override
  String get settingsLocModeSubtitle => '測位方法を選択';

  @override
  String get locModeGps => 'GPS のみ';

  @override
  String get locModeGpsDesc => '衛星のみ。省電力';

  @override
  String get locModeGpsNetwork => 'GPS ＋ ネットワーク';

  @override
  String get locModeGpsNetworkDesc => 'ネットワーク補助で測位が速い';

  @override
  String get beaconingSection => 'ビーコン送信';

  @override
  String get beaconIntervalTip => '位置ビーコンの送信間隔（最短 5 秒）';

  @override
  String get beaconContent => 'ビーコンの内容';

  @override
  String get beaconContentDesc => '位置ビーコンと一緒に送信';

  @override
  String get phoneBattery => '端末のバッテリー';

  @override
  String get locationStatus => '測位状態';

  @override
  String get relocate => '再測位';

  @override
  String get startGps => 'GPS 測位を開始';

  @override
  String get trackingBeaconing => '測位中で、位置を継続的に送信しています';

  @override
  String get manualLocation => '手動位置';

  @override
  String get latitudeHint => '緯度 39.9042';

  @override
  String get longitudeHint => '経度 116.4074';

  @override
  String get invalidLatLng => '有効な緯度・経度を入力してください';

  @override
  String myLocationSetGrid(String grid) {
    return '位置を設定しました · グリッド $grid';
  }

  @override
  String get applyCoordinates => '座標を適用';

  @override
  String get pickOnMap => '地図で選択';

  @override
  String get manualLocationHelp =>
      '自動測位できない場合は、緯度・経度を手動入力するか地図で地点を選べます。ビーコン送信と局との距離計算に使われます。';

  @override
  String get passcodeTip => 'APRS-IS のログイン用 Passcode（オンラインで生成可能）。-1 は未検証を意味します';

  @override
  String get websocketOptional => 'WebSocket URL（任意）';

  @override
  String get configChanged => '設定を変更しました';

  @override
  String get reconnectToApply => '再接続後に反映されます';

  @override
  String get reconnected => '再接続しました';

  @override
  String get connectFailedCheckConfig => '接続に失敗しました。設定を確認してください';

  @override
  String get rangeFilterDesc => '設定した範囲内の局のパケットのみ受信します';

  @override
  String get filterCenterFollows => 'フィルター中心を自分の位置に追従';

  @override
  String get radiusTip => '受信半径（km）。「保存して適用」で反映されます';

  @override
  String get maxStationsTip => 'メモリに保持する最大局数（既定は無制限。より大きな値も設定可）';

  @override
  String filterSavedRadius(String saved, int radius) {
    return '$saved · 半径 $radius km';
  }

  @override
  String get receiveFilterDesc2 => '範囲フィルターに加えて、国・地域ごと、または正確なコールサインで局を受信します';

  @override
  String get receiveCountryDesc => 'コールサインの接頭辞で、ある国・地域の局をまとめて受信';

  @override
  String get noCountriesSelected => '国・地域が未選択';

  @override
  String get receiveOthersDesc => '選択した国に一致しない特殊なコールサインの局も受信';

  @override
  String get addCountry => '国・地域を追加';

  @override
  String get chatSettingsDetail => 'メッセージ・連絡先・チャットデータ';

  @override
  String get messageCountLabel => 'メッセージ件数';

  @override
  String get manageContacts => '連絡先の管理';

  @override
  String deleteAllChatsConfirm(int count) {
    return 'チャット履歴 $count 件をすべて削除しますか？この操作は取り消せません。';
  }

  @override
  String get chatCleared => 'チャット履歴を消去しました';

  @override
  String get noContacts => '連絡先がありません';

  @override
  String get addOrFavoriteContact => '右上の「追加」をタップするか、地図で局をお気に入りに登録してください';

  @override
  String movingWithSpeed(String speed) {
    return '移動中 · $speed';
  }

  @override
  String get callsignMin3 => 'コールサインは 3 文字以上必要です';

  @override
  String get deleteContact => '連絡先を削除';

  @override
  String deleteContactConfirm(String call) {
    return '連絡先 $call を削除しますか？';
  }

  @override
  String contactDeleted(String call) {
    return '$call を削除しました';
  }

  @override
  String get dataMaintenance => 'データ管理';

  @override
  String get clearAllData => 'すべてのデータを消去';

  @override
  String get clearAllDataIntro => '以下のローカルデータをすべて削除します：';

  @override
  String get chatHistory => 'チャット履歴';

  @override
  String get logs => 'ログ';

  @override
  String get irreversibleKeepSettings => 'この操作は取り消せません。接続設定とコールサインは削除されません。';

  @override
  String get confirmClearAllData => 'すべてのデータを消去';

  @override
  String get clearAllDataConfirm => 'すべてのローカルデータを消去しますか？この操作は取り消せません。';

  @override
  String get allDataCleared => 'すべてのデータを消去しました';

  @override
  String get confirmClear => '消去する';

  @override
  String get allowLandscape => '横向き表示を許可';

  @override
  String get packetParseTest => 'パケット解析テスト';

  @override
  String get packetParseHint =>
      '生の APRS パケットを貼り付け（例：\nBV2XYZ>APRS,TCPIP*:!3904.25N/11624.44E>テスト局）';

  @override
  String get parseAndApply => '解析して適用';

  @override
  String get oobePasscodeMissing => 'Passcode が未入力';

  @override
  String get oobePasscodeMissingDesc =>
      'Passcode は APRS-IS のログイン用検証コードで、あなたのコールサインを識別するために使われます。\n\n既定値の -1（未検証）でも接続はできますが、メッセージやグループの送受信が正常に行えません。\n\nhttps://aprs.cool/AprsPG でコールサインを入力して正しい Passcode を調べてから入力してください。';

  @override
  String get continueAnyway => 'このまま続行';

  @override
  String get fillPasscode => '入力する';

  @override
  String get oobeMapFeatureDesc => 'オンライン地図タイルで、近くの APRS 局と軌跡を表示';

  @override
  String get oobeGpsFeatureDesc => '位置を自動取得し、APRS-IS へビーコンを送信';

  @override
  String get oobeMsgFeatureDesc => '局とメッセージを送受信。自動応答に対応';

  @override
  String get oobeIsFeatureDesc => '公共サーバーに接続し、世界中の局のデータを受信';

  @override
  String get oobeBackgroundTip =>
      'ヒント：バックグラウンドでの位置送信を維持するため、システム設定で APRSlocus のバックグラウンド動作を許可し、省電力最適化を無効にし、自動起動を許可してください。';

  @override
  String get oobeNextSteps => '次の数ステップで基本設定を完了します。後から設定で変更できます。';

  @override
  String get ssidDescShort => 'SSID はコールサインの後ろに付く数字の識別子です（例：BG7ABC-9 の -9）';

  @override
  String get ssidOptional => 'SSID 接尾辞（任意）';

  @override
  String get noSsid => '接尾辞なし（基本コールサイン）';

  @override
  String fullCallsign(String call) {
    return '完全なコールサイン：$call';
  }

  @override
  String get passcodeImportant => 'Passcode は非常に重要です';

  @override
  String get passcodeImportantDesc =>
      '正しい Passcode は、グループメッセージの受信と確認応答の送信に必要です。-1 でも接続はできますが、メッセージの送受信が正常に行えません。';

  @override
  String get lookupPasscode => 'あなたの Passcode を調べる →';

  @override
  String get passcodeLookupHint => 'コールサインを入力すると取得できます（例：BV2AAA）';

  @override
  String sendToGroupHint(String group) {
    return '$group に送信…';
  }

  @override
  String sendToCallHint(String call) {
    return '$call に送信…';
  }

  @override
  String get selectMessageReply => 'メッセージを選んで返信…';

  @override
  String get broadcastShort => '一斉送信';

  @override
  String memberCount(int count) {
    return 'メンバー $count 名';
  }

  @override
  String memberCountTap(int count) {
    return '$count 名 · タップで表示';
  }

  @override
  String get stepRecipients => '宛先';

  @override
  String get stepContent => '内容';

  @override
  String get selectAllOnline => 'オンラインをすべて選択';

  @override
  String get clearSelection => '選択を解除';

  @override
  String get onlineOnly => 'オンラインのみ';

  @override
  String get noRecipients => '宛先が未選択';

  @override
  String selectedRecipients(int count) {
    return '$count 人を選択';
  }

  @override
  String sendRecipientsList(int count, String calls) {
    return '$count 人に送信します：$calls';
  }

  @override
  String get stepName => '名前';

  @override
  String get stepMembers => 'メンバー';

  @override
  String get groupChatExplain =>
      'グループはグループ用コールサインでメッセージを同報し、全メンバーが受信できます。作成するとグループ用コールサインが自動生成され、選択したメンバーに招待が送られます。';

  @override
  String get noMembersSelected => 'メンバーが未選択';

  @override
  String get memberBlocked => 'ブロック済み';

  @override
  String get memberJoined => '参加済み';

  @override
  String get memberPending => '確認待ち';

  @override
  String get memberDeclined => '拒否済み';

  @override
  String get memberLeft => '退出済み';

  @override
  String get memberTimeout => 'タイムアウト';

  @override
  String get unblock => 'ブロック解除';

  @override
  String get block => 'ブロック';

  @override
  String get groupOwner => 'グループ作成者';

  @override
  String systemMemberJoined(String call) {
    return '$call がグループに参加しました';
  }

  @override
  String systemMemberLeft(String call) {
    return '$call がグループから退出しました';
  }

  @override
  String systemInviteDeclined(String call) {
    return '$call が招待を拒否しました';
  }

  @override
  String get copyAllLogs => 'すべてのログをコピー';

  @override
  String copiedLogs(int count) {
    return 'ログ $count 件をコピーしました';
  }

  @override
  String get clearLogs => 'ログを消去';

  @override
  String get noLogs => 'ログがありません';

  @override
  String get supportProject => '皆さまの支援がプロジェクトを前へ進めます';

  @override
  String get continuousIteration => '継続的な改善';

  @override
  String get continuousIterationDesc => 'APRSlocus の機能と体験を不断に改善';

  @override
  String get sponsorSupport => 'スポンサー';

  @override
  String get sponsorMethods => '支援方法';

  @override
  String qrCodeTitle(String title) {
    return '$title の QR コード';
  }

  @override
  String get qrLoadFailed => 'QR コード画像の読み込みに失敗しました';

  @override
  String get qrSaveWechat => '画像を長押しで保存 · WeChat でスキャンして支援';

  @override
  String get tapAnywhereClose => 'どこかをタップして閉じる';

  @override
  String vectorMapLoadFailed(String error) {
    return 'ベクター地図の読み込みに失敗しました\n$error';
  }

  @override
  String get loadingVectorMap => 'ベクター地図を読み込み中…';

  @override
  String get updateChannel => '更新チャネル';

  @override
  String serverReturned(int code) {
    return 'サーバーの応答：$code';
  }

  @override
  String get invalidResponseData => '応答データの形式が不正です';

  @override
  String get noVersionsFound => 'バージョンが見つかりません';

  @override
  String get noWindowsInstaller => 'このバージョンには Windows インストーラーがありません';

  @override
  String get noApkInstaller => 'このバージョンには APK がありません';

  @override
  String get connectingEllipsis => '接続中…';

  @override
  String downloadHttpError(int code) {
    return 'ダウンロード失敗：HTTP $code';
  }

  @override
  String downloadedBytes(String received, String total) {
    return 'ダウンロード済み $received / $total';
  }

  @override
  String androidInstallHelp(String path) {
    return 'インストーラーの保存先：\n$path\n\n「インストール」をタップすると、システムのインストール確認が表示されます。\n\n「提供元不明のアプリのインストールが許可されていません」と表示された場合は、システム設定で本アプリに不明なアプリのインストールを許可してください。';
  }

  @override
  String windowsInstallHelp(String path) {
    return 'インストーラーの保存先：\n$path\n\n「今すぐ実行」をタップすると起動します。保存先フォルダを開くこともできます。';
  }

  @override
  String get openContainingFolder => '保存先フォルダを開く';

  @override
  String get runNow => '今すぐ実行';

  @override
  String get cannotRunInstaller => 'インストーラーを起動できませんでした。保存先フォルダから手動で開いてください';

  @override
  String get cannotLaunchInstaller => 'インストーラーを起動できませんでした。パッケージを手動で開いてください';

  @override
  String get openPackageManually => 'ファイルマネージャーでパッケージを開いてください';

  @override
  String cannotOpenPackage(String error) {
    return 'パッケージを開けません：$error';
  }

  @override
  String get installPermissionTitle => 'アプリのインストール許可が必要です';

  @override
  String get installPermissionDesc =>
      'APRSlocus にアプリのインストールが許可されていないようです。\n\n「設定へ」をタップし、「提供元不明のアプリ」で本アプリにインストールを許可してから、戻って再試行してください。';

  @override
  String get recheck => '再確認';

  @override
  String newVersionTitle(String version) {
    return '新しいバージョン v$version があります';
  }

  @override
  String repoLatestTitle(String version) {
    return 'リポジトリの最新 v$version';
  }

  @override
  String get checkingLatest => '最新バージョンを確認中…';

  @override
  String get connectingGitCode => 'GitCode サーバーに接続中';

  @override
  String get noReleaseNotes => '更新内容がありません';

  @override
  String noInstallerHistoryHint(String platform) {
    return 'このバージョンには $platform のインストーラーがありません。過去のバージョンからダウンロード可能なものを選んでください';
  }

  @override
  String get latestVersionLabel => '最新バージョン';

  @override
  String packageSize(String platform, String size) {
    return '$platform インストーラーのサイズ：$size';
  }

  @override
  String get updateContents => '更新内容';

  @override
  String get redownload => '再ダウンロード';

  @override
  String get downloadInstaller => 'インストーラーをダウンロード';

  @override
  String get downloadAndInstall => 'ダウンロードしてインストール';

  @override
  String get localPackageExists => 'ローカルにインストーラーがあります';

  @override
  String get packageDeleted => 'インストーラーを削除しました';

  @override
  String versionCount(int count) {
    return '$count 件';
  }

  @override
  String get noInstaller => 'インストーラーなし';

  @override
  String get download => 'ダウンロード';

  @override
  String get viewChangelog => '更新履歴を表示';

  @override
  String versionChangelog(String version) {
    return 'v$version の更新履歴';
  }

  @override
  String get gotIt => '了解';

  @override
  String get leaveAction => '退出';

  @override
  String localRepoVersion(Object latest, Object local) {
    return 'ローカル v$local · リポジトリ最新 v$latest';
  }

  @override
  String get unverified => '未検証';

  @override
  String get passcodeUnverifiedHint => '-1（未検証）';

  @override
  String get passcodeMessageWarning =>
      'APRS-IS のログイン用 Passcode。-1 ではメッセージの送受信が正常に行えません。';

  @override
  String get settingsStationIdentitySubtitle => 'コールサイン・SSID・メモ';

  @override
  String get settingsDisplayInfoSubtitle => 'マイシンボルと現在の位置';

  @override
  String get settingsLocSourceSubtitle => '座標のソースを選択';

  @override
  String get settingsBeaconSubtitle => '送信間隔と送信内容';

  @override
  String get settingsManualLocSubtitle => '測位できない場合は手動入力または地図で選択';

  @override
  String get settingsManualLocHint =>
      '自動測位できない場合は、緯度・経度を手動入力するか地図で地点を選べます。ビーコン送信と局との距離計算に使われます。';

  @override
  String get settingsConnStatusSubtitle => '接続状態と情報';

  @override
  String get settingsServerSubtitle => 'APRS-IS サーバーと Passcode';

  @override
  String get settingsFilterSubtitle => 'フィルター中心と受信半径';

  @override
  String get settingsReceivePrefSubtitle => '国・地域またはコールサインで受信';

  @override
  String get settingsGeneralSubtitle => 'テーマ・言語・座標表示';

  @override
  String get settingsMapSubtitle => '地図の種類と表示';

  @override
  String get settingsChatStatsSubtitle => 'メッセージと連絡先の統計';

  @override
  String get settingsChatManageSubtitle => '連絡先とチャットデータ';

  @override
  String get settingsClearDataSubtitle => 'ローカル記録の削除';

  @override
  String get settingsLabSubtitle => '実験的機能';

  @override
  String get settingsDevSubtitle => 'デバッグとテスト';

  @override
  String get settingsFilterHint => '設定した範囲内の局のパケットのみ受信します';

  @override
  String get settingsReceivePrefHint =>
      '範囲フィルターに加えて、国・地域ごと、または正確なコールサインで局を受信します';

  @override
  String get settingsContribCodeOptimization => 'コード最適化';

  @override
  String get eggBg2hcb => '人生ってほんとにニャンニャンだね';

  @override
  String get deviceInfoTitle => 'デバイス識別';

  @override
  String get deviceToCall => '宛先コールサイン';

  @override
  String get deviceModel => '機種';

  @override
  String get deviceClass => 'デバイス分類';

  @override
  String get deviceFilter => 'デバイスフィルター';

  @override
  String get lookupQrz => 'QRZ コールサイン';

  @override
  String get lookupAprsFi => 'aprs.fi の位置';

  @override
  String get aprsTv => 'APRS.tv';

  @override
  String get aprsTvInfo => '詳細ページ';

  @override
  String get aprsTvMap => '地図で表示';

  @override
  String get linkOpenFailed => 'リンクを開けません';

  @override
  String get beaconAutoAskTitle => '接続しました。位置を自動送信しますか？';

  @override
  String get beaconAutoAskDesc =>
      '接続後、APRSlocus が定期的に位置（ビーコン）を自動送信しますか？移動局では有効化を推奨します。メッセージ受信と周辺局の表示だけなら無効でも構いません（いつでも手動で 1 回送信できます）。';

  @override
  String get beaconAutoYes => '自動送信';

  @override
  String get beaconAutoNo => '今はしない（受信のみ）';

  @override
  String get beaconOffChip => '自動送信はオフ';

  @override
  String get quickTrackCreate => '追跡グループを作成';

  @override
  String get quickTrackHint =>
      '受信済みの局からメンバーを選ぶか、コールサインを手入力して追加できます。チャットグループを作らなくても、そのまま地図で追跡できます。';

  @override
  String get quickTrackName => 'グループ名（任意）';

  @override
  String get quickTrackPickLabel => '追跡する局を選択';

  @override
  String get quickTrackNoStations => '受信済みの局がありません。コールサインを直接入力できます（複数はカンマ区切り）';

  @override
  String get quickTrackManualHint => 'コールサインを入力（例：BG7PGW,BG7LMW）';

  @override
  String get quickTrackStart => '追跡を開始';

  @override
  String get quickTrackNeedMembers => 'コールサインを 1 つ以上選択または入力してください';

  @override
  String get weatherPanelTitle => '天気 · ハムのヒント';

  @override
  String get weatherPanelSub => '和風天気（QWeather）· 現在地';

  @override
  String get weatherRefresh => '更新';

  @override
  String get weatherPowered => 'データ提供：和風天気（QWeather）· APRSlocus';

  @override
  String get hfTitle => 'HF 伝搬';

  @override
  String get hfSixMeter => '6m バンド';

  @override
  String get hfEs => 'Es（スポラディック E）';

  @override
  String get hfAurora => 'オーロラ';

  @override
  String get hfF2 => 'F2 層';

  @override
  String get hfBand => 'バンド';

  @override
  String get hfDay => '昼';

  @override
  String get hfNight => '夜';

  @override
  String get hfNow => '現在';

  @override
  String get hfSfi => '太陽フラックス';

  @override
  String get hfKp => 'Kp 指数';

  @override
  String get hfAIndex => 'A 指数';

  @override
  String get hfSunspots => '黒点数';

  @override
  String get hfXray => 'X 線';

  @override
  String get hfSolarWind => '太陽風';

  @override
  String get hfGeomag => '地磁気';

  @override
  String get hfNoise => 'ノイズ';

  @override
  String get hfMuf => 'MUF';

  @override
  String get hfNoData => 'HF 伝搬データがありません（オンライン時に自動取得します）';

  @override
  String get hfUnavailable => 'HF 伝搬サービスを利用できません';

  @override
  String get hfQGood => '良好';

  @override
  String get hfQFair => '普通';

  @override
  String get hfQPoor => '不良';

  @override
  String get hfQClosed => '伝搬なし';

  @override
  String get hfPowered => '伝搬データ: hamqsl.com（N0NBH）· 全球平均であり現地実測ではありません';

  @override
  String get hfTipStorm =>
      '地磁気嵐（Kp≥5）：極域の HF 伝搬は大きく減衰し、極横断 DX はほぼ途絶えます。低緯度経路かローカル VHF/UHF へ';

  @override
  String get hfTipGeomagActive =>
      '地磁気がやや乱れています：高緯度の HF 伝搬は普段より不安定です。DX は呼び出し時間を多めに';

  @override
  String get hfTipLowSfi => '太陽活動が低調（SFI<100）：昼間の 15/12/10m は期待薄。40/30/20m を優先';

  @override
  String get hfTipHighSfi => '太陽活動が活発（SFI≥150）：昼間の 15/12/10m で遠距離 DX の見込み';

  @override
  String get hfTipHighNoise =>
      'ノイズフロアが高い：弱い信号は取りにくいです。帯域を狭め、RF ゲインを下げ、必要なら狭帯域モードで';

  @override
  String hfTipBandGood(String b) {
    return '$b の伝搬が良好：今はこのバンドを優先';
  }

  @override
  String hfTipBandPoor(String b) {
    return '$b の伝搬が不良：別のバンドへ、または日の出・日の入りのグレーライン待ち';
  }

  @override
  String get weatherCurLoc => '現在地';

  @override
  String get weatherNoLoc => '位置情報がありません。「マイ無線局」で位置情報を有効にしてから天気をご覧ください';

  @override
  String get weatherUnavail => '天気サービスは一時的に利用できません';

  @override
  String get weatherDataFail => '天気データの取得に失敗しました';

  @override
  String get weatherConnFail => '天気サービスへの接続に失敗しました';

  @override
  String get weatherCloud => '雲量';

  @override
  String get weatherDew => '露点';

  @override
  String get weatherHumidity => '湿度';

  @override
  String get weatherWindDir => '風向';

  @override
  String get weatherWindScale => '風力';

  @override
  String get weatherWindSpeed => '風速';

  @override
  String get weatherPressure => '気圧';

  @override
  String get weatherVis => '視程';

  @override
  String get weatherPrecip => '降水量';

  @override
  String weatherFeels(String v) {
    return '体感 $v°';
  }

  @override
  String weatherObserved(String t) {
    return '観測 $t';
  }

  @override
  String get hamTitle => 'アマチュア無線のアドバイス';

  @override
  String get hamNoData => '天気を取得すると、アンテナ設営・交信・落雷対策の安全アドバイスを表示します';

  @override
  String get hamStorm1 =>
      '雷雨時：屋外でのアンテナ設営・操作は絶対に避けてください！落雷の誘導による機器破損を防ぐため、アンテナのフィーダーを外してください';

  @override
  String get hamStorm2 => 'すでに設営済みなら速やかに撤収・倒してください。屋内での中継・短波の受信に切り替え、機器の防湿に注意';

  @override
  String get hamRain =>
      '降水あり：屋外設営時はレインカバー／防水ボックスを用意し、コネクタはテープや熱収縮チューブで密封、フィーダーに水が溜まらないように';

  @override
  String get hamCold =>
      '低温・降雪：リチウム電池の容量が大きく低下します。予備電池を多めに持参し、体で温めてください。アンテナの着氷時は SWR の変化に注意';

  @override
  String hamWind(String w) {
    return '風力 $w：アンテナには必ず支線を張って補強し、撤収時は八木・ロングワイヤを倒してください';
  }

  @override
  String hamHot(String t) {
    return '高温 $t°C：熱中症対策と水分補給を。機器は長時間のフルパワー送信による過熱を避けてください';
  }

  @override
  String hamHumid(String h) {
    return '湿度 $h%：湿気は絶縁とアンテナ効率を下げ、VHF/UHF の減衰が大きくなります。コネクタの防錆に注意';
  }

  @override
  String hamFog(String v) {
    return '視程不良（${v}km）：移動と設営は安全に。霧は大気ダクトを生みやすく、遠距離の V/U 交信のチャンスです';
  }

  @override
  String get hamGood => '天気良好、設営日和です！V/U 帯はローカル中継と直接波を試し、短波は夜間の電離層変化に注目';

  @override
  String hamWindExtra(String w) {
    return '$w の風があります。アンテナの支線補強を推奨します。野外での設営は安全に';
  }

  @override
  String get hamStorm3 =>
      '落雷が接近：アンテナのフィーダーを無線機から外し、屋外の接地端子へ移して放電させてください。電源を切りプラグを抜き、商用電源や LAN 経由のサージ侵入を防ぎます。屋外アンテナと固定電話は使用しないでください';

  @override
  String get hamStorm4 =>
      '雷雨の前後は静電ノイズ（QRN）が急増し、短波のノイズフロアが上がります。雷活動が止まってから約 30 分後に設営と送信を再開してください';

  @override
  String get hamExtreme =>
      '豪雨・極端な降水：鉄砲水・浸水・落石に注意し、河岸や低地での設営は避けてください。フィーダーの壁面取入口にはドリップループを作り、雨水が屋内に流れ込まないように';

  @override
  String hamGale(String w) {
    return '風力 $w：タワーやマストへの登攀作業は禁止です！八木・ロングワイヤは必ず倒すか下ろし、支線・アンカー・ステーを点検してください';
  }

  @override
  String get hamIce =>
      'アンテナとフィーダーの着氷は SWR を上げ、着氷荷重を増やします。フルパワーで無理に送信せず、まず支線の張力を確認し、氷が解けてから通常運用してください';

  @override
  String get hamFrost =>
      '気温 0℃ 未満：リチウム電池の容量が急減します。予備電池はポケットで保温してください。手足と顔の凍傷に注意し、カイロを持参';

  @override
  String get hamHeat2 =>
      '高温時は PA と電源が過熱でデレーティングしやすくなります。出力を下げ、連続送信時間を短くし、通風・放熱を確保してください';

  @override
  String get hamDust =>
      '砂塵時：細かい砂がコネクタやがいしに入ると漏れとノイズの原因になります。防塵キャップを使用してください。乾燥摩擦で静電気が溜まりやすいため、接地による放電に注意';

  @override
  String get hamAir =>
      '大気質不良：屋外設営時はマスクを着用し、激しい作業を控えてください。汚染物質がアンテナがいしに付着すると漏れノイズの原因になるため、撤収後に清掃を';

  @override
  String hamDew(String d) {
    return '露点差が $d℃ しかなく、空気が飽和に近い状態です：機器とフィーダーが結露しやすくなります。撤収後は温度を戻して除湿してから通電し、短絡を避けてください';
  }

  @override
  String hamUV(String u) {
    return 'UV 指数 $u と高めです：野外設営時は日焼け対策を。長時間の直射は同軸ケーブルの外被やタイラップの劣化を早めます';
  }

  @override
  String hamLowPressure(String p) {
    return '気圧が低め（$p hPa）：天気が崩れやすくなっています。長時間の野外設営では退路を確保し、最新の警報・注意報に注意してください';
  }

  @override
  String hamHighPressure(String p) {
    return '気圧が高く（$p hPa）安定：逆転層ができやすく、VHF/UHF で大気ダクトが発生する可能性があります。見通し外の遠距離直接波や中継交信を試してみてください';
  }

  @override
  String get hamGrayLine =>
      '日出・日没のグレーライン時間帯です：20/40m の短波伝搬が最良で、大陸間の DX 交信の黄金時間です';

  @override
  String get hamNight =>
      '夜間は D 層が消滅：80/40m の吸収が減りノイズも低いため、国内および夜間の長距離通信に適しています';

  @override
  String get hamRainFade =>
      '強い降水は 1.2GHz 以上の周波数帯にレインフェードの影響を与えます。マイクロ波や EME の交信は、より低いバンドに変更するか雨が弱まるのを待つことをおすすめします';

  @override
  String get hamShower =>
      'にわか雨は急に来て去ります：レインカバーを用意し、雲の動きに注意してください。撤収前に送信を止めてからフィーダーを外してください';

  @override
  String get hamLevelDanger => '安全警告';

  @override
  String get hamLevelWarn => '注意';

  @override
  String get hamLevelGood => '交信チャンス';

  @override
  String get hamLevelTip => '運用のヒント';

  @override
  String hamMore(String n) {
    return 'アドバイス $n 件をすべて表示';
  }

  @override
  String get hamLess => '折りたたむ';

  @override
  String get weatherForecast3 => '3 日間予報';

  @override
  String get weatherDaily15 => '15 日間の天気を見る';

  @override
  String get weatherDaily15Title => '15 日間の天気傾向';

  @override
  String get weatherToday => '今日';

  @override
  String get weatherTomorrow => '明日';

  @override
  String get weatherDayAfter => '明後日';

  @override
  String weatherWeekday(String d) {
    String _temp0 = intl.Intl.selectLogic(d, {
      '1': '月',
      '2': '火',
      '3': '水',
      '4': '木',
      '5': '金',
      '6': '土',
      '7': '日',
      'other': '—',
    });
    return '$_temp0';
  }

  @override
  String get weatherSunrise => '日の出';

  @override
  String get weatherSunset => '日の入り';

  @override
  String get weatherUV => '紫外線';

  @override
  String get weatherDetails => '詳細データ';

  @override
  String get weatherAQIPrimary => '主要汚染物質';

  @override
  String get airExcellent => '優';

  @override
  String get airGood => '良';

  @override
  String get airModerate => '軽度汚染';

  @override
  String get airUnhealthy => '中度汚染';

  @override
  String get airVeryUnhealthy => '重度汚染';

  @override
  String get airHazardous => '深刻な汚染';

  @override
  String get weatherAir => '大気質';

  @override
  String get issStation => 'ISS';

  @override
  String get applyStationFilter => '局フィルターを地図に適用';

  @override
  String get stationFilterOn => '局パネルのフィルターで表示中';

  @override
  String get stationList => '局リスト';

  @override
  String get statsPanel => '統計パネル';

  @override
  String get statsOverview => 'システム概要';

  @override
  String get statsTotalRx => '総受信数';

  @override
  String get statsTotalTx => '総送信数';

  @override
  String get statsRate => '受信レート';

  @override
  String statsPerMin(String n) {
    return '$n/分';
  }

  @override
  String get statsStationsTotal => '局の総数';

  @override
  String get statsCap => '容量上限';

  @override
  String get statsConn => '接続状態';

  @override
  String get statsConnected => '接続済み';

  @override
  String get statsDisconnected => '未接続';

  @override
  String get statsMyGrid => 'マイ大グリッド';

  @override
  String get statsAprslocusUsers => 'APRSlocus ユーザー';

  @override
  String get statsFarthest => '最遠の局';

  @override
  String get statsStatusDist => '局の状態分布';

  @override
  String get statsTypeDist => 'APRS 種類分布';

  @override
  String get statsGridDist => '大グリッド別の局分布';

  @override
  String get statsGridHint => 'Maidenhead 大グリッド（4 文字）別に局数を集計して並べ替え';

  @override
  String statsGridCount(String n) {
    return '$n グリッド';
  }

  @override
  String get statsGridEmpty => '局の位置データがありません';

  @override
  String get statsDeviceDist => 'デバイス分類分布';

  @override
  String get statsOther => 'その他の指標';

  @override
  String get statsAvgSpeed => '平均速度';

  @override
  String get statsLastHeard => '最近の受信';

  @override
  String get statsPackets => 'パケット（直近）';

  @override
  String get statsNoData => 'データなし';

  @override
  String get noStationsFiltered => '現在のフィルター条件に一致する局がありません';

  @override
  String get noStationsFilteredHint =>
      'フィルターまたは受信範囲が狭すぎます。フィルターを解除して再試行してください。受信範囲は「設定 → 受信範囲」にあります。';

  @override
  String get clearStationFilter => 'フィルターを解除';

  @override
  String get clearSearch => '検索を解除';

  @override
  String get activeConditions => '適用中の条件';

  @override
  String get statsMovingCount => '移動中の局';

  @override
  String get statsOnlineRate => 'オンライン率';

  @override
  String get statsGridCountLabel => '大グリッド数';

  @override
  String get maxPackets => 'パケット保持件数';

  @override
  String get maxPacketsTip => 'パケットページに保持する履歴件数（既定 2000。増やすとメモリを多く消費します）';

  @override
  String get maxTrackPts => '軌跡点数の上限';

  @override
  String get maxTrackPtsTip =>
      '局ごとに保持する軌跡点数（既定 300。移動軌跡をどこまで遡れるかを決めます。20m 以上の移動時のみ記録）';

  @override
  String get onlineWindow => 'オンライン判定時間（分）';

  @override
  String get onlineWindowTip => '局の最終送信からこの時間を超えるとオフラインとみなします（既定 5 分）';

  @override
  String get chatRecords => 'チャット履歴';

  @override
  String get chatRecordsCleared => 'チャット履歴を消去しました';

  @override
  String get deviceCat => 'デバイス';

  @override
  String get deviceCatDesc => '無線機 · 準備中';

  @override
  String get deviceSettings2 => 'デバイス設定';

  @override
  String get deviceSettingsSubtitle => '無線機を接続';

  @override
  String get underConstruction => '工事中・未公開';

  @override
  String get underConstructionHint => 'この機能は開発中です。もうしばらくお待ちください';

  @override
  String get storageLimit => 'データ上限';

  @override
  String get storageLimitSubtitle => 'ローカルに保持するデータ量';

  @override
  String get connectionCard2 => 'APRS-IS 接続';

  @override
  String get immersiveMap => 'イマーシブマップ';

  @override
  String get immersiveMapTip => 'ナビスタイル：自分中心・進行方向を上・四隅 HUD';

  @override
  String get headingUp => '進行方向を上';

  @override
  String get northUp => '北を上';

  @override
  String get followMe => '自分を追従';

  @override
  String get beaconCountdown => '送信カウントダウン';

  @override
  String get beaconOff => 'オフ';

  @override
  String get unlocated => '未測位';

  @override
  String get platform => 'プラットフォーム';

  @override
  String get nearbyStations => '近くの局';

  @override
  String get honorWall => '栄誉ウォール';

  @override
  String get accountHonors => 'アカウントの栄誉';

  @override
  String get achievementsSection => '実績';

  @override
  String get notLit => '未点灯';

  @override
  String honorCriteriaLine(String c) {
    return '獲得条件：$c';
  }

  @override
  String get badgeFallback => 'バッジ';

  @override
  String honoredBadges(String n, String m) {
    return 'バッジ $n/$m 点灯';
  }

  @override
  String achievementsProgress(String n, String m) {
    return '実績 $n/$m';
  }

  @override
  String get beaconNotConnected => '未接続';

  @override
  String get beaconWaitingFix => '測位を待機中';

  @override
  String get beaconSoon => 'まもなく';

  @override
  String beaconNextIn(String s) {
    return '次回送信まで $s';
  }

  @override
  String get beaconImminent => 'まもなく送信…';

  @override
  String get notifConnected => '接続済み';

  @override
  String get notifConnecting => '接続中';

  @override
  String get notifDisconnected => '未接続';

  @override
  String notifOnline(String n) {
    return '$n オンライン';
  }

  @override
  String notifRx(String n) {
    return '受信 $n';
  }

  @override
  String notifBeacon(String v) {
    return 'ビーコン $v';
  }

  @override
  String get selectAll => 'すべて選択';

  @override
  String get deselectAll => 'すべて解除';

  @override
  String selectedCount(int n) {
    return '$n 件選択中';
  }

  @override
  String deleteSelected(int n) {
    return '削除 ($n)';
  }

  @override
  String deleteSelectedConfirm(int n) {
    return '選択した $n 件のチャットを削除しますか？この操作は取り消せません。';
  }

  @override
  String get chatManageHint => 'チャットをタップして選択（長押しでも選択可）';

  @override
  String conversationsDeleted(int n) {
    return '$n 件のチャットを削除しました';
  }

  @override
  String get stationActions => '局の操作';

  @override
  String get deleteStation => '局を削除';

  @override
  String deleteStationConfirm(String name) {
    return '局 $name を削除しますか？リストから削除されます。再度そのパケットを受信すると再表示されます。';
  }

  @override
  String get unfavorite => 'お気に入りを解除';

  @override
  String get copyCallsign => 'コールサインをコピー';

  @override
  String get callsignCopied => 'コールサインをコピーしました';

  @override
  String get stationDeleted => '局を削除しました';

  @override
  String get exportAdif => 'ADIF をエクスポート';

  @override
  String get exportAdifDesc =>
      '会話を ADIF ログファイルとしてエクスポートします。Log4OM や N3FJP などのログソフトに読み込めます';

  @override
  String get export => 'エクスポート';

  @override
  String get adifHint => '各レコードにはコールサインと最初のメッセージ時刻（UTC）のみを含みます。モードとバンドは含みません';

  @override
  String get adifNoSelection => 'エクスポートする会話を選択してください';

  @override
  String adifExported(int n) {
    return '$n 件のレコードをエクスポートしました';
  }

  @override
  String get adifExportDone => 'エクスポート完了';

  @override
  String get adifExportFailed => 'エクスポートに失敗しました。ストレージの権限や空き容量を確認してください';

  @override
  String adifSavedTo(String path) {
    return '保存先：$path';
  }

  @override
  String get adifCopyPath => 'パスをコピー';

  @override
  String get adifPathCopied => 'パスをコピーしました';

  @override
  String get chatShortLabel => '個別';

  @override
  String get adifLogFile => '会話をログファイルに保存';

  @override
  String get adifOptions => 'エクスポート設定';

  @override
  String get adifMode => 'モード（MODE）';

  @override
  String get adifNotWritten => '書き込まない';

  @override
  String get adifModePkt => 'PKT（パケット、推奨）';

  @override
  String get adifModeFm => 'FM（音声）';

  @override
  String get adifModeData => 'DATA（データ）';

  @override
  String get adifSubModeAprs => 'SUBMODE=APRS を追加';

  @override
  String get adifBand => 'バンド（BAND）';

  @override
  String get adifStripSsid => '基本コールサインのみ（-SSID を除去）';

  @override
  String get adifPreview => 'プレビュー（書き出されるレコード）';

  @override
  String get adifModeRequiredHint => '多くのログソフト（QRZ 含む）は MODE が必須で、無いと拒否されます';

  @override
  String get adifFreq => '周波数（FREQ）';

  @override
  String get adifFreqHint => '単位 MHz、空欄なら書き込みません';

  @override
  String get adifFreqInvalid => 'MHz の数値を入力してください（例 144.640）';

  @override
  String get sysTitle => 'システム状態';

  @override
  String get sysLinkOff => '未使用';

  @override
  String sysRx(String n) {
    return '受信 $n';
  }

  @override
  String sysTx(String n) {
    return '送信 $n';
  }

  @override
  String sysBeacon(String t) {
    return 'ビーコン $t';
  }

  @override
  String sysStations(String n) {
    return '局数 $n';
  }

  @override
  String get sysFixOk => '測位済み';

  @override
  String get sysLinkAudio => 'オーディオ';

  @override
  String get sysEmpty => 'APRSlocus を開いて接続すると、ここに運用状況が表示されます';

  @override
  String get backupTitle => 'バックアップと復元';

  @override
  String get backupSubtitle => '設定とデータの書き出し・読み込み';

  @override
  String get backupEntryDesc => '設定とデータを JSON にまとめる';

  @override
  String get backupDesc =>
      'バックアップは JSON ファイルで、機種変更や再インストール後に復元できます。読み込みはグループ単位で上書きされ、元に戻せません。';

  @override
  String get backupExport => 'バックアップを書き出す';

  @override
  String get backupExportDesc => '含める内容を選び、ファイル保存またはクリップボードへコピー';

  @override
  String get backupExportToFile => 'ファイルに保存';

  @override
  String get backupCopyJson => 'クリップボードにコピー';

  @override
  String get backupExportDone => 'バックアップを書き出しました';

  @override
  String get backupExportFailed => '書き出しに失敗しました。ストレージの権限や空き容量を確認してください';

  @override
  String get backupCopyDone => 'バックアップをクリップボードにコピーしました';

  @override
  String backupSavedTo(String path) {
    return '保存先：$path';
  }

  @override
  String get backupCatSettings => '設定';

  @override
  String get backupCatSettingsDesc => '局、ビーコン、地図、フィルター、接続先、サーバー';

  @override
  String get backupCatStations => '局とコンタクト';

  @override
  String get backupCatStationsDesc => 'お気に入り・手動追加した局とメモ';

  @override
  String get backupCatMessages => 'メッセージ履歴';

  @override
  String get backupCatMessagesDesc => '個別メッセージと既読位置';

  @override
  String get backupCatChats => 'グループチャット';

  @override
  String get backupCatChatsDesc => 'グループ、メンバー、既読状態';

  @override
  String get backupCatTranslate => '翻訳設定';

  @override
  String get backupCatTranslateDesc => '翻訳サービス、API キー、言語設定';

  @override
  String get backupCatHonors => '実績と栄誉';

  @override
  String get backupCatHonorsDesc => '解除記録、カウント、既定バッジ';

  @override
  String backupItems(int n) {
    return '$n 件';
  }

  @override
  String get backupSelectAll => 'すべて選択';

  @override
  String get backupNoSelection => 'グループを 1 つ以上選んでください';

  @override
  String get backupImport => 'バックアップを読み込む';

  @override
  String get backupImportDesc => '以前書き出した JSON バックアップを選択';

  @override
  String get backupPickFile => 'バックアップを選択';

  @override
  String get backupPaste => 'クリップボードから貼り付け';

  @override
  String get backupPasteEmpty => 'クリップボードにテキストがありません';

  @override
  String get backupPreview => 'バックアップの内容';

  @override
  String backupFromVersion(String v) {
    return '書き出し元 $v';
  }

  @override
  String backupExportedAt(String t) {
    return '書き出し日時 $t';
  }

  @override
  String get backupImportSelected => '選択した項目を読み込む';

  @override
  String get backupImportConfirmTitle => '読み込みますか？';

  @override
  String get backupImportConfirm =>
      '選択したグループは上書きされ、元に戻せません。先に現在のデータを書き出すことをおすすめします。';

  @override
  String backupImported(int n) {
    return '$n 件を読み込みました';
  }

  @override
  String backupSkipped(int n) {
    return '不明な $n 件をスキップしました';
  }

  @override
  String get backupImportNothing => '選択したグループのデータがバックアップにありません';

  @override
  String get backupRestartTitle => '読み込み完了';

  @override
  String get backupRestartHint =>
      'データは保存されました。完全に反映するにはアプリを再起動してください（実績・翻訳・サーバー接続など）。';

  @override
  String get backupRestartNow => 'アプリを終了';

  @override
  String get backupLater => 'あとで';

  @override
  String get backupSecurityTip =>
      'バックアップにはコールサイン、サーバーのパスコード、API キーが含まれます。大切に保管してください。';

  @override
  String get backupWebHint => 'Web 版では「クリップボードにコピー / 貼り付け」を使ってください。';

  @override
  String get backupErrNotJson => 'ファイルが有効な JSON ではありません';

  @override
  String get backupErrNotBackup => 'APRSlocus のバックアップではありません';

  @override
  String get backupErrSchemaNewer =>
      '新しいバージョンの APRSlocus のバックアップです。アプリを更新してください';

  @override
  String get backupErrEmpty => '読み込める内容がありません';

  @override
  String get backupErrTooLarge => 'バックアップが 32 MB を超えているため読み込めません';

  @override
  String get backupErrRead => 'バックアップを読み込めませんでした';

  @override
  String get backupErrUnsupported => 'この環境ではファイル選択が使えません。クリップボードから貼り付けてください';

  @override
  String get themeTitle => 'テーマ';

  @override
  String get themeEntryDesc => '色・アイコン・文字をカスタマイズ';

  @override
  String get themeSubtitle => '配色・アイコン・よく使う文言を自分好みに';

  @override
  String get themePresets => 'プリセットと自分のテーマ';

  @override
  String get themePresetTag => 'プリセット';

  @override
  String get themeActive => '使用中';

  @override
  String get themePresetDefault => '既定';

  @override
  String get themePresetOcean => 'オーシャン';

  @override
  String get themePresetForest => 'フォレスト';

  @override
  String get themePresetMidnight => 'ミッドナイト';

  @override
  String get themePresetSunset => 'サンセット';

  @override
  String get themePresetContrast => 'ハイコントラスト';

  @override
  String get themeBuiltinHint => 'プリセットは編集できません。自分のテーマに複製してください';

  @override
  String get themeColors => '色';

  @override
  String get themeColorsDesc => '項目ごとに上書き（未変更は既定のまま）';

  @override
  String get themeRadius => 'カードの角丸';

  @override
  String get themeRadiusDesc => 'カードと入力欄に適用（小さなバッジは対象外）';

  @override
  String get themeIcons => 'アイコン';

  @override
  String get themeIconsDesc => 'タブバーと設定入口のアイコンを変更';

  @override
  String get themeTexts => '文字';

  @override
  String get themeTextsDesc => 'よく使う文言を上書き（ボタンとエラー表示は対象外。操作不能になるのを防ぐため）';

  @override
  String get themeNew => '新しいテーマ';

  @override
  String get themeDuplicate => '自分のテーマに複製';

  @override
  String get themeRename => '名前を変更';

  @override
  String get themeDelete => 'テーマを削除';

  @override
  String themeDeleteConfirm(String name) {
    return 'テーマ「$name」を削除しますか？元に戻せません。';
  }

  @override
  String get themeReset => '既定に戻す';

  @override
  String get themeResetAll => 'このテーマをリセット';

  @override
  String get themeSaved => 'テーマを保存しました';

  @override
  String get themeNameHint => 'テーマ名';

  @override
  String get themePickColor => '色を選ぶ';

  @override
  String get themePickIcon => 'アイコンを選ぶ';

  @override
  String get themePickIconSearch => 'アイコン名で検索';

  @override
  String get themeEditText => '文字を編集';

  @override
  String get themeTextHint => '空欄で既定に戻す';

  @override
  String get themeIconImport => '画像から読み込む';

  @override
  String get themeIconImportHint => 'PNG/JPG/WebP/GIF/BMP/SVG、2MB まで';

  @override
  String themeIconImportDone(String name) {
    return 'アイコンを読み込みました：$name';
  }

  @override
  String get themeIconWebHint => 'Web 版では画像を読み込めません。内蔵アイコンを使ってください';

  @override
  String get themeIconErrFormat => '未対応の画像形式です（PNG/JPG/WebP/GIF/BMP/SVG）';

  @override
  String get themeIconErrTooLarge => '画像が 2MB を超えています。圧縮してください';

  @override
  String get themeIconErrFailed => 'アイコンの読み込みに失敗しました';

  @override
  String get themeIconErrUnsupported => 'この環境では画像の読み込みに対応していません';

  @override
  String get themeIo => '読み込みと書き出し';

  @override
  String get themeIoDesc => 'テーマは JSON テキスト。共有も手編集もできます';

  @override
  String get themeExport => 'このテーマを書き出す';

  @override
  String get themeExportAll => 'すべてのテーマを書き出す';

  @override
  String get themeImport => 'テーマを読み込む';

  @override
  String get themeImportPaste => 'クリップボードから読み込む';

  @override
  String themeImportDone(int n) {
    return '$n 件のテーマを読み込みました';
  }

  @override
  String get themeErrNotJson => 'ファイルが有効な JSON ではありません';

  @override
  String get themeErrNotTheme => 'APRSlocus のテーマファイルではありません';

  @override
  String get themeErrSchemaNewer => '新しいバージョンの APRSlocus のテーマです。アプリを更新してください';

  @override
  String get themeErrEmpty => '読み込めるテーマがありません';

  @override
  String get themeFixedPrimary => '現在のテーマがメインカラーを固定しています。「テーマ」ページで変更してください';

  @override
  String get themeTokenPrimary => 'メインカラー';

  @override
  String get themeTokenSurface => 'カード表面';

  @override
  String get themeTokenBackground => 'ページ背景';

  @override
  String get themeTokenBackgroundSoft => '副次的な背景';

  @override
  String get themeTokenTextPrimary => '本文';

  @override
  String get themeTokenTextSecondary => '副次的な文字';

  @override
  String get themeTokenTextMuted => '補助文字';

  @override
  String get themeTokenDivider => '区切り線';

  @override
  String get themeTokenSuccess => '成功・オンライン';

  @override
  String get themeTokenWarning => '警告';

  @override
  String get themeTokenDanger => '危険・オフライン';

  @override
  String get themeTokenInfo => '情報・強調';

  @override
  String get themeBg => '背景画像';

  @override
  String get themeBgDesc => '画像をアプリ全体の背景に。カードは自動的に半透明になります';

  @override
  String get themeBgPick => '画像を選ぶ';

  @override
  String get themeBgReplace => '画像を変更';

  @override
  String get themeBgRemove => '背景を削除';

  @override
  String get themeBgOpacity => '不透明度';

  @override
  String get themeBgOpacityDesc => 'マスクの濃さも兼ねます。上げるほど画像が見え、文字が読みにくくなります';

  @override
  String get themeBgBlur => 'ぼかし';

  @override
  String get themeBgBlurDesc => 'ぼかすと写真の細部が消え、上の文字が読みやすくなります';

  @override
  String get themeBgFit => '表示方法';

  @override
  String get themeBgFitCover => '全面';

  @override
  String get themeBgFitContain => '全体表示';

  @override
  String get themeBgFitStretch => '引き伸ばし';

  @override
  String get themeBgFitTile => 'タイル';

  @override
  String get themeBgNone => '未設定';

  @override
  String get themeBgErrTooLarge => '背景画像が 8MB を超えています。圧縮してください（アイコンは 2MB まで）';

  @override
  String get themeBgLocalOnly =>
      '背景画像はこの端末にのみ保存されます。テーマファイルには参照だけが記録され、画像自体は含まれないため、共有した相手には背景なしのテーマが表示されます。';

  @override
  String get themeBgDisabledHint => 'このテーマに背景画像はありません。背景は単色です';

  @override
  String get themeExportWithImages => '書き出しに画像を含める';

  @override
  String themeExportWithImagesHint(String size) {
    return '書き出しファイルに画像本体（約 $size）が含まれ、受け取った側でも同じ背景とアイコンが表示されます。その代わり手編集には向かなくなります。';
  }

  @override
  String get themeExportNoImages => 'このテーマは画像を参照していません。書き出しには色と文字だけが含まれます';

  @override
  String get themeExportClipboardTooBig =>
      '画像が大きいためクリップボードでは渡せません。「すべてのテーマを書き出す」でファイルに保存してください';

  @override
  String themeImportImagesSkipped(int n) {
    return '$n 件の画像を読み込めませんでした（大きすぎるか未対応形式）';
  }

  @override
  String get backupThemeImagesHint =>
      'バックアップにテーマが参照する画像本体を含めます。含めない場合、復元後にテーマは内蔵アイコンに戻ります。';

  @override
  String get backupThemeImagesOff =>
      '画像を含めません。バックアップは小さくなりますが、復元したテーマでは背景とカスタムアイコンが欠けます';

  @override
  String get themeSurface => 'カード表面';

  @override
  String get themeSurfaceDesc => '背景画像があるときのカードの透過度';

  @override
  String get themeSurfaceAlpha => '不透明度（低いほど透ける）';

  @override
  String get themeSurfaceAlphaDesc =>
      '0.85 前後なら下地を透かしつつ読めます。0.6 未満は文字がにじみやすくなります';

  @override
  String get themeSurfaceNoBg => '背景画像がないため、今は効果が見えません';

  @override
  String get themeLayout => '余白とフォント';

  @override
  String get themeLayoutDesc => 'カードと入力欄の余白のみ。細かな間隔は変わりません';

  @override
  String get themeDensity => '余白';

  @override
  String get themeDensityCompact => '詰める';

  @override
  String get themeDensityNormal => '標準';

  @override
  String get themeDensityComfortable => 'ゆったり';

  @override
  String get themeDensityHint => 'カードの余白を変えます。変わらない箇所は個別に固定されています';

  @override
  String get themeFont => 'フォント';

  @override
  String get themeFontDefault => 'システム既定';

  @override
  String get themeFontSystem => 'システム UI フォント';

  @override
  String get themeFontMono => '等幅';

  @override
  String get themeFontHint =>
      'システムにインストール済みのフォントのみ使用します。無い場合は自動的に代替され、豆腐にはなりません';

  @override
  String get themeTabs => 'アクセントカラー';

  @override
  String get themeTabsDesc => '入口カードのグラデーションと、タブごとのアクセントカラー';

  @override
  String get themeUniformAccent => '入口カードの配色を統一';

  @override
  String get themeAccentFrom => 'グラデ開始';

  @override
  String get themeAccentTo => 'グラデ終了';

  @override
  String get themeOverridden => 'カスタム';

  @override
  String get themeFollowsPrimary => 'メインカラーに追従';

  @override
  String get themeBgAlign => '位置';

  @override
  String get themeAlignCenter => '中央';

  @override
  String get themeAlignTop => '上';

  @override
  String get themeAlignBottom => '下';

  @override
  String get themeAlignLeft => '左';

  @override
  String get themeAlignRight => '右';

  @override
  String get themeAlignTopLeft => '左上';

  @override
  String get themeAlignTopRight => '右上';

  @override
  String get themeAlignBottomLeft => '左下';

  @override
  String get themeAlignBottomRight => '右下';

  @override
  String get themeBgScale => '拡大縮小';

  @override
  String get themeBgScaleDesc => '1.0 = 元のサイズ。拡大すると一部だけを見せられます';

  @override
  String get themeAuthor => '作者';

  @override
  String get themeDescription => '説明';

  @override
  String get themeSkinInfo => 'スキン情報';

  @override
  String get themeSkinInfoDesc => '共有すると、この 2 項も一緒に渡ります';

  @override
  String get themeAuthorHint => 'コールサインかニックネーム';

  @override
  String get themeDescHint => 'このスキンの一言説明';

  @override
  String get themePreviewSwatches => 'プレビュー色';

  @override
  String get themePresetGraphite => 'グラファイト';

  @override
  String get themePresetSakura => '桜';

  @override
  String get themePresetTerminal => 'ターミナル';

  @override
  String get themePresetAmber => 'アンバー';

  @override
  String get sysRecentLabel => '直近受信';

  @override
  String get audioWavImportAction => 'WAV ファイルを選択';

  @override
  String get audioWavExportToDownloads => 'ダウンロードへ書き出し';

  @override
  String audioWavSavedTo(String path) {
    return '保存先: $path';
  }

  @override
  String get audioWavCopyPath => 'パスをコピー';

  @override
  String get audioWavPathCopied => 'パスをコピーしました';

  @override
  String get audioWavCanceled => 'キャンセルしました';

  @override
  String get audioWavVerifyFailed => '書き出し前の自己検査に失敗：生成した音声を復調できません';

  @override
  String get audioWavMobileHint =>
      'Android では任意のパスに書けません：ダウンロード/APRSlocusAudio に保存されます（PC にコピーして Direwolf や無線機へ）';

  @override
  String get audioWavPickHint => 'デスクトップでは下に WAV パスを入力してください';

  @override
  String get audioTxLevel => '送信レベル';

  @override
  String get audioTxLevelTip =>
      '送信前にメディア音量を最大にし、マイク入力を一時停止します。ピークが低すぎてもクリップしても相手は復調できません';

  @override
  String audioTxPeak(int p, String sec, int flags) {
    return 'ピーク $p% · ${sec}s · プリアンブル $flags フラグ';
  }

  @override
  String get audioTxLevelClip => 'クリップしています：出力振幅を 0.8 未満に下げてください（高調波が出ます）';

  @override
  String get audioTxLevelLow => 'レベルが低い：相手が復調できない可能性があります。振幅と音量を上げてください';

  @override
  String get audioWiringHint =>
      '無線機へはオーディオケーブルで（イヤホン出力 → データ/マイク端子）。スマホのスピーカーは 2200Hz が大きく減衰し、音響結合ではまず復調できません。相手が Direwolf なら、まず書き出した WAV で確認を：それで復調できれば問題は音声経路であってプロトコルではありません';

  @override
  String packetLimitRf(int bytes, int max) {
    return 'パケット $bytes バイト · 無線フレーム上限 $max バイト';
  }

  @override
  String packetLimitIs(int bytes) {
    return 'パケット $bytes バイト · APRS-IS 1 行上限 512 バイト';
  }

  @override
  String get packetTcpipWarning => 'TCPIP* を含みます：無線では自動的に除去されます（APRS-IS のパス）';

  @override
  String packetSent(String line) {
    return 'リンクへ送信しました：$line';
  }

  @override
  String packetSendFailed(String err) {
    return '送信していません：$err';
  }

  @override
  String get tncSerialBaud => 'シリアル通信速度 (bd)';

  @override
  String get tncSerialBaudTip =>
      'USB シリアルケーブルと無線機のデータ端子は同じ速度にする必要があり、違うと 1 バイトも通りません。よく使う値：9600 / 19200 / 38400 / 57600 / 115200。Bluetooth SPP には速度の概念がなく、Bluetooth 機器ではこの設定は無効です。';

  @override
  String get tncSerialBaudHint =>
      '変更した速度は再接続後に有効になります（「パラメータ送信」で1 回自動的に再接続します）';

  @override
  String get tncSerialBaudBluetooth =>
      '現在バインドされているのは Bluetooth 機器です。Bluetooth SPP には速度の概念がないため、この設定は無効です';

  @override
  String get uiMaterial => '画面マテリアル';

  @override
  String get uiMaterialDesc => 'カード・バー・ダイアログを半透明にし、その背後を実際にぼかします';

  @override
  String get uiMaterialOff => 'オフ（不透明）';

  @override
  String get uiMaterialOffDesc => '表面は不透明で、従来どおりです';

  @override
  String get uiMaterialGlass => 'すりガラス';

  @override
  String get uiMaterialGlassDesc => 'より透明でぼかしが強め。Windows 11 のアクリルに近い見た目です';

  @override
  String get uiMaterialMica => 'マイカ';

  @override
  String get uiMaterialMicaDesc =>
      'より不透明でぼかしは控えめ、アクセント色がうっすら乗ります。Windows 11 のマイカに近い見た目です';

  @override
  String get uiMaterialHint =>
      'マテリアルはアプリ内の表面（カード・バー・ダイアログ・地図の重なり）だけにかかります。ウィンドウ自体の透明化ではありません。ぼかしは GPU を使うため、古い端末ではオフより動作が重くなることがあります。';

  @override
  String get uiMaterialBgHint =>
      'このテーマは背景画像を使っているため、マテリアルは独自の背景を描かず、バーと重なりだけをぼかします。';

  @override
  String get uiMaterialPreview => 'プレビュー';

  @override
  String get uiLayout => '画面レイアウト';

  @override
  String get uiLayoutDesc => '2.0 では地図を画面全体の土台にし、他のページは下部のドラッグできるカードに収めます';

  @override
  String get uiLayoutClassic => 'クラシック（1.0）';

  @override
  String get uiLayoutClassicDesc => '広い画面は左サイドバー、狭い画面は下部ナビ。従来どおりです';

  @override
  String get uiLayoutSheet => '地図ベース（2.0）';

  @override
  String get uiLayoutSheetDesc =>
      '地図は常に全画面。台站 / メッセージ / パケット / 設定は下部のドラッグできるカードに入り、上スワイプかハンドルのタップで開きます';

  @override
  String get uiLayoutHint =>
      'すぐに反映されます。両レイアウトの設定は別々に保持されます。カードを畳むと地図上のボタンが自動で上に移動します';
}
