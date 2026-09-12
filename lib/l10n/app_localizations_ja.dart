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
  String get oobeFilterDesc => '既定では中国のコールサインのみ受信します。必要に応じて他の国・地域を追加できます';

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
  String get datumGcj => 'GCJ-02（AMAP）';

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
  String get featureLiveMap => 'AMAP 地図';

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
      '「マップ 2.0（ベクター）」は端末側でベクターを描画するため通信量が少なく、拡大しても鮮明です。AMAP のベクター／衛星はオンラインのラスタータイルです。';

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
  String get navigationUnavailable => 'AMAP がインストールされておらず、他の地図アプリも開けませんでした';

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
    return '$call とのチャット履歴を削除しますか？この操作は取り消せません。';
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
  String get amapGroup => 'AMAP';

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
  String get oobeMapFeatureDesc => 'AMAP タイルで、近くの APRS 局と軌跡を表示';

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
}
