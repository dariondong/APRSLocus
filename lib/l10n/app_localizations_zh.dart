// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appName => 'APRSlocus';

  @override
  String get ok => '确定';

  @override
  String get cancel => '取消';

  @override
  String get save => '保存';

  @override
  String get delete => '删除';

  @override
  String get confirm => '确认';

  @override
  String get back => '返回';

  @override
  String get next => '下一步';

  @override
  String get finish => '完成并连接';

  @override
  String get previous => '上一步';

  @override
  String get search => '搜索';

  @override
  String get settings => '设置';

  @override
  String get about => '关于';

  @override
  String get logout => '退出';

  @override
  String get retry => '重试';

  @override
  String get all => '全部';

  @override
  String get online => '在线';

  @override
  String get offline => '离线';

  @override
  String get moving => '移动';

  @override
  String get emergency => '紧急';

  @override
  String get fixed => '固定';

  @override
  String get infrastructure => '中继';

  @override
  String get weather => '气象';

  @override
  String get fmo => 'FMO';

  @override
  String get mobile => '车载';

  @override
  String get favorite => '收藏';

  @override
  String get grid => '网格';

  @override
  String get callsign => '呼号';

  @override
  String get speed => '速度';

  @override
  String get altitude => '高度';

  @override
  String get course => '航向';

  @override
  String get distance => '距离';

  @override
  String get bearing => '方位角';

  @override
  String get lastSeen => '最近活跃';

  @override
  String get latitude => '纬度';

  @override
  String get longitude => '经度';

  @override
  String get station => '台站';

  @override
  String get stations => '台站';

  @override
  String get messages => '消息';

  @override
  String get packets => '数据包';

  @override
  String get map => '地图';

  @override
  String get home => '首页';

  @override
  String get connection => '连接';

  @override
  String get connected => '已连接';

  @override
  String get disconnected => '未连接';

  @override
  String get connecting => '连接中';

  @override
  String get reconnect => '重新连接';

  @override
  String get server => '服务器';

  @override
  String get port => '端口';

  @override
  String get passcode => 'Passcode';

  @override
  String get beacon => '位置信标';

  @override
  String get beaconInterval => '上报间隔(秒)';

  @override
  String get nextBeacon => '下次上报';

  @override
  String get beaconsSent => '信标发送次数';

  @override
  String get filter => '接收范围过滤';

  @override
  String get filterRadius => '过滤半径(km)';

  @override
  String get maxStations => '最大台站数';

  @override
  String get receiveFilter => '接收呼号筛选';

  @override
  String get receiveCountries => '国家/地区';

  @override
  String get receiveOthers => '其他台站';

  @override
  String get darkMode => '深色模式';

  @override
  String get themeColor => '主题颜色';

  @override
  String get language => '语言';

  @override
  String get languageSystem => '跟随系统';

  @override
  String get languageZh => '中文';

  @override
  String get languageEn => 'English';

  @override
  String get displaySettings => '显示设置';

  @override
  String get mapType => '地图类型';

  @override
  String get unit => '单位';

  @override
  String get coordDatum => '坐标基准';

  @override
  String get stationSettings => '电台设置';

  @override
  String get connectionSettings => '连接设置';

  @override
  String get chatSettings => '聊天设置';

  @override
  String get dataSettings => '数据设置';

  @override
  String get advancedSettings => '高级设置';

  @override
  String get sponsors => '赞助与鸣谢';

  @override
  String get sponsorsThanks => '感谢每一位支持者';

  @override
  String get send => '发送';

  @override
  String get receive => '接收';

  @override
  String get clear => '清除';

  @override
  String get copy => '复制';

  @override
  String get copied => '已复制';

  @override
  String get version => '版本';

  @override
  String get location => '定位';

  @override
  String get gpsStatus => 'GPS 状态';

  @override
  String get myLocation => '我的位置';

  @override
  String get track => '轨迹';

  @override
  String get forwardingPath => '转发路径';

  @override
  String get relatedStations => '相关台站';

  @override
  String get openInMap => '在地图查看';

  @override
  String get navigate => '导航';

  @override
  String get messageSent => '消息已发送';

  @override
  String get enterMessage => '输入消息';

  @override
  String get noData => '暂无数据';

  @override
  String get searchHint => '搜索呼号 / 类型 / 网格 / 备注…';

  @override
  String get notFound => '未找到台站';

  @override
  String get totalStations => '总数';

  @override
  String get sortBy => '排序';

  @override
  String get sortCall => '呼号';

  @override
  String get sortRecent => '最近';

  @override
  String get sortDistance => '距离';

  @override
  String get sortStatus => '状态';

  @override
  String get typeFilter => '类型筛选';

  @override
  String get aprslocusOnly => 'APRSlocus';

  @override
  String get confirmDelete => '确定要删除吗？';

  @override
  String get confirmRestartOobe =>
      '将重新进入首次启动向导，可重新设置呼号、接收地区等。\n当前设置不会丢失，完成向导后继续使用。';

  @override
  String get restartWizard => '重新运行设置向导';

  @override
  String get restartWizardTitle => '重新运行设置向导？';

  @override
  String get oobeFilterTitle => '选择接收地区';

  @override
  String get oobeFilterDesc => '默认只接收中国呼号台站，可按需添加其他国家/地区';

  @override
  String get oobeWelcomeTitle => '欢迎使用 APRSlocus';

  @override
  String get oobeWelcomeRealMap => '实时地图';

  @override
  String get oobeWelcomeGps => 'GPS 定位上报';

  @override
  String get oobeWelcomeMsg => 'APRS 消息';

  @override
  String get oobeWelcomeIs => '接入 APRS-IS';

  @override
  String get oobeCallTitle => '你的呼号';

  @override
  String get oobeSymbolTitle => '选择台站符号';

  @override
  String get oobeServerTitle => '连接 APRS-IS 服务器';

  @override
  String get weatherData => '气象数据';

  @override
  String get fmoInfo => 'FMO 台站信息';

  @override
  String get aprslocusInfo => 'APRSlocus 信息';

  @override
  String get locationInfo => '位置信息';

  @override
  String get recentPackets => '最近数据包';

  @override
  String get quickActions => '快捷操作';

  @override
  String get copyCoords => '复制坐标';

  @override
  String get copyGrid => '复制网格';

  @override
  String get sender => '发送方';

  @override
  String get time => '时间';

  @override
  String get message => '消息';

  @override
  String get groupChat => '群聊';

  @override
  String get newGroup => '新建群聊';

  @override
  String get sendTo => '发送至';

  @override
  String get filterRule => '过滤规则';

  @override
  String get saveAndApply => '保存并应用过滤';

  @override
  String get useMyLocation => '用我的位置作为过滤中心';

  @override
  String get noFixYet => '尚未定位，无法获取当前位置';

  @override
  String get invalidCoords => '请输入有效的经纬度和半径';

  @override
  String get filterSaved => '过滤已保存并应用';

  @override
  String get stationsShown => '台站';

  @override
  String get settingsDesc => '配置电台、定位与连接';

  @override
  String get radioCat => '电台';

  @override
  String get radioCatDesc => '呼号 · SSID · 符号';

  @override
  String get beaconCat => '定位上报';

  @override
  String get beaconCatDesc => 'GPS · 信标 · 手动定位';

  @override
  String get connectionCat => '连接';

  @override
  String get connectionCatDesc => '服务器 · 过滤范围';

  @override
  String get displayCat => '显示';

  @override
  String get displayCatDesc => '坐标 · 主题';

  @override
  String get chatCat => '聊天';

  @override
  String get chatCatDesc => '记录 · 联系人';

  @override
  String get dataCat => '数据';

  @override
  String get dataCatDesc => '清除本地数据';

  @override
  String get advancedCat => '高级';

  @override
  String get advancedCatDesc => '实验室 · 开发者';

  @override
  String get updateCat => '更新';

  @override
  String get updateCatDesc => '检查新版本';

  @override
  String get checkUpdate => '检查更新';

  @override
  String get myStationSettings => '我的电台';

  @override
  String get myStationSettingsDesc => '呼号 · SSID · 符号 · 信标';

  @override
  String get oobeWelcomeDesc => '开始配置你的 APRS 电台';

  @override
  String get oobeCallDesc => '输入你的呼号';

  @override
  String get oobeSymbolDesc => '符号代表台站类型，会随位置信标一起发送';

  @override
  String get oobeServerDesc => '连接后接收全球 APRS 台站数据，可保持默认配置直接使用';

  @override
  String get wizard => '设置向导';

  @override
  String get setStep => '步骤';

  @override
  String get chooseSymbol => '选择台站符号';

  @override
  String get settingsSubtitle => '地图坐标与显示偏好';

  @override
  String get stationSettingsSubtitle => '呼号、符号与信标';

  @override
  String get connectionSettingsSubtitle => 'APRS-IS 服务器与接收范围';

  @override
  String get chatSettingsSubtitle => '消息记录与联系人';

  @override
  String get dataSettingsSubtitle => '本地数据管理';

  @override
  String get advancedSettingsSubtitle => '实验室与开发者工具';

  @override
  String get stationListTitle => '台站列表';

  @override
  String get filters => '筛选';

  @override
  String get clearAll => '全部清除';

  @override
  String get statusFilter => '状态';

  @override
  String get typeGroup => '类型';

  @override
  String get appFilter => '软件';

  @override
  String get mapMenu => '地图菜单';

  @override
  String get mapTypeTitle => '地图类型';

  @override
  String get selectMapType => '选择地图类型';

  @override
  String get showTrails => '显示轨迹';

  @override
  String get showStations => '显示台站';

  @override
  String get aboutTitle => '关于';

  @override
  String get aboutSubtitle => 'APRS 定位追踪与地图';

  @override
  String get author => '作者';

  @override
  String get features => '功能特性';

  @override
  String get openSource => '开源致谢';

  @override
  String get feedback => '用户反馈';

  @override
  String get qqGroup => 'QQ 交流群';

  @override
  String get projectRepo => '项目仓库';

  @override
  String get testMembers => '测试成员';

  @override
  String get aiSupport => 'AI 算力支持';

  @override
  String get copyAppInfo => '复制应用信息';

  @override
  String get appInfoCopied => '已复制应用信息';

  @override
  String get enterCallsign => '请输入你的呼号';

  @override
  String get enterValidCall => '请输入有效呼号';

  @override
  String get stationSettings2 => '电台设置';

  @override
  String get beaconSettings => '定位上报';

  @override
  String get displaySettings2 => '显示设置';

  @override
  String get chatSettings2 => '聊天设置';

  @override
  String get dataSettings2 => '数据设置';

  @override
  String get advancedSettings2 => '高级设置';

  @override
  String get connectionSettings2 => '连接设置';

  @override
  String get myCallsign => '我的呼号';

  @override
  String get beaconEnabled => '启用位置信标';

  @override
  String get smartBeacon => '智能信标(移动加速)';

  @override
  String get packetConsole => '数据包控制台';

  @override
  String get rawMode => '原始模式';

  @override
  String get parsedMode => '解析模式';

  @override
  String get position => '位置';

  @override
  String get statusType => '状态';

  @override
  String get objectType => '对象';

  @override
  String packetStats(Object ppm, Object rx, Object tx) {
    return '收 $rx · 发 $tx · $ppm/分';
  }

  @override
  String get searchPacket => '搜索呼号、目的地或原始内容…';

  @override
  String get noMatchingPackets => '没有匹配的数据包';

  @override
  String get inject => '注入';

  @override
  String get manualInject => '手动注入 APRS 数据包';

  @override
  String get injected => '已注入数据包';

  @override
  String get clearedPackets => '已清除数据包';

  @override
  String get clearPackets => '清除数据包';

  @override
  String noPositionInfo(Object call) {
    return '$call 暂无位置信息（数据包未含位置）';
  }

  @override
  String get copiedPacket => '已复制数据包';

  @override
  String get mapPickMode => '地图选点模式';

  @override
  String get mapPickDesc => '点击地图选择我的位置';

  @override
  String foundStations(Object count, Object q) {
    return '找到 $count 台匹配「$q」';
  }

  @override
  String get tapMapHint => '点击地图查看台站 · 双指缩放';

  @override
  String myLocationPanel(Object call) {
    return '我的位置 · $call';
  }

  @override
  String get speedLabel => '速度';

  @override
  String get courseLabel => '航向';

  @override
  String get beaconIntervalLabel => '上报间隔';

  @override
  String get beaconsSentLabel => '已上报';

  @override
  String get nextBeaconLabel => '下次上报';

  @override
  String positionBeacon(Object grid) {
    return '位置信标 · 网格 $grid';
  }

  @override
  String get manualBeacon => '手动上报';

  @override
  String get mapPickNow => '地图选点';

  @override
  String pickedCoord(Object grid, Object lat, Object lng) {
    return '已在地图选点 · $lat, $lng · 网格 $grid';
  }

  @override
  String onlineCount(Object count) {
    return '$count 在线';
  }

  @override
  String movingCount(Object count) {
    return '$count 移动';
  }

  @override
  String stationCount(Object count) {
    return '$count 台站';
  }

  @override
  String get locateMe => '定位';

  @override
  String get layerFilter => '图层筛选';

  @override
  String get showAll => '全部显示';

  @override
  String get otherType => '其他';

  @override
  String zoomLevel(Object z) {
    return '缩放 $z';
  }

  @override
  String get datumGcj => '高德火星';

  @override
  String get datumWgs => 'WGS-84';

  @override
  String distKm(Object d) {
    return '距离 ${d}km';
  }

  @override
  String get noStationInView => '该区域暂无台站 · 点击显示全部';

  @override
  String get tapToView => '点击查看';

  @override
  String get beaconNow => '手动上报';

  @override
  String get meLabel => '我';

  @override
  String get mapZoomIn => '放大';

  @override
  String get mapZoomOut => '缩小';

  @override
  String get mapHome => '回到中心';

  @override
  String get mapLocate => '定位';

  @override
  String get mapLayers => '图层';

  @override
  String get featureLiveMap => '高德地图';

  @override
  String get featureLiveMapDesc => 'GCJ-02 坐标，流畅的缩放与拖拽体验';

  @override
  String get featureGps => 'GPS 定位';

  @override
  String get featureGpsDesc => '原生 Android 定位，无需 Google 服务';

  @override
  String get featureBeacon => '信标发送';

  @override
  String get featureBeaconDesc => '自定义内容、频率、符号，支持 APRS 标准格式';

  @override
  String get featureMsg => '消息收发';

  @override
  String get featureMsgDesc => '瀑布流 + 会话模式，支持中文和自动应答';

  @override
  String get featureAutoConnect => '自动连接';

  @override
  String get featureAutoConnectDesc => '公共服务器自动连接，后台保持在线';

  @override
  String get featureLayerFilter => '图层筛选';

  @override
  String get featureLayerFilterDesc => '按类型筛选：移动、固定、中继、气象、FMO';

  @override
  String get featureFmo => 'FMO 台站';

  @override
  String get featureFmoDesc => '自动识别 FMO 数据，显示结构化信息';

  @override
  String get osFlutter => 'Flutter';

  @override
  String get osFlutterDesc => 'Google 跨平台 UI 框架';

  @override
  String get osAmap => '高德地图';

  @override
  String get osAmapDesc => '地图瓦片服务';

  @override
  String get osAprs => 'APRS-IS';

  @override
  String get osAprsDesc => '全球 APRS 数据网络';

  @override
  String get osHam => '业余无线电';

  @override
  String get osHamDesc => '所有 APRS 爱好者的贡献';

  @override
  String get authorName => 'Darion';

  @override
  String get authorCall => '呼号';

  @override
  String get website => '网站';

  @override
  String get sponsorAuthor => '作者 BG7LZQ';

  @override
  String get sponsorAuthorItems => '利用课余时间开发维护本项目';

  @override
  String get sponsorGroup => 'STUDENT HAMS 群组';

  @override
  String get sponsorGroupItems => '感谢群组的资金赞助支持';

  @override
  String get sponsorBgp => 'BG7PGW';

  @override
  String get sponsorBgpItems => '感谢赞助的蜜雪冰城一杯 🧋';

  @override
  String get sponsorEvery => '每一位支持者';

  @override
  String get sponsorEveryItems => '你们的每一份支持都是动力';

  @override
  String get donateWechat => '微信赞赏';

  @override
  String get donateWechatDesc => '长按保存赞赏码 · 点击放大';

  @override
  String get donateAlipay => '支付宝赞赏';

  @override
  String get donateAlipayDesc => '联系作者获取赞赏码';

  @override
  String get nonprofitNote => '本项目为非盈利学习交流项目\n赞助仅用于服务器与开发成本';

  @override
  String get myStation => '我的电台';

  @override
  String get callSsid => '呼号 · SSID';

  @override
  String get ssid => 'SSID';

  @override
  String get ssidDesc => 'SSID 是呼号后缀用于标识设备，如 BG7ABC-9 中的 -9';

  @override
  String get callComment => '台站备注';

  @override
  String get callCommentHint => '信标发送时的备注内容';

  @override
  String get callSymbol => '台站符号';

  @override
  String get callSymbolDesc => '符号随位置信标一起发送';

  @override
  String get autoReply => '自动应答';

  @override
  String get sendBeacon => '发送信标';

  @override
  String get mapTypeDesc => '「地图 2.0（矢量）」使用客户端实时矢量渲染，数据量小、缩放清晰；高德矢量/卫星为在线栅格瓦片。';

  @override
  String get msgHistory => '消息记录';

  @override
  String get statistics => '统计';

  @override
  String get clearData => '清除数据';

  @override
  String get favorites => '收藏/手动';

  @override
  String get favoriteStations => '收藏台站';

  @override
  String get manualStations => '手动台站';

  @override
  String get wgs84 => 'WGS-84';

  @override
  String get gcj02 => '高德火星';

  @override
  String get onlyWgs84 => '仅标准 WGS-84';

  @override
  String get contactList => '联系人';

  @override
  String get contactDesc => '消息/联系人相关的过滤规则';

  @override
  String get dataClearDesc => '清除消息、数据包、台站等本地数据';

  @override
  String get advancedDesc => '实验室与开发者工具';

  @override
  String get labDesc => '实验室功能仍在测试中，可能影响使用体验。默认锁定竖屏，开启后支持横屏。';

  @override
  String get systemLog => '系统日志';

  @override
  String get devDesc => '开发者调试工具';

  @override
  String get simData => '启用模拟数据（演示台站/数据包）';

  @override
  String get rxTx => '收包 / 发包';

  @override
  String get stationCount2 => '台站数量';

  @override
  String get appInfo => '应用信息';

  @override
  String get clearMessages => '清空全部聊天记录';

  @override
  String get clearPackets2 => '清除数据包';

  @override
  String get clearStations => '清除台站列表';

  @override
  String get clearCache => '清除缓存';

  @override
  String get resetAll => '重置全部设置';

  @override
  String get resetAllDesc => '恢复出厂设置';

  @override
  String get dataPersistence => '台站持久化';

  @override
  String get autoSaveStations => '自动保存台站数据';

  @override
  String get gridFormat => '网格格式';

  @override
  String get coordsFormat => '坐标格式';

  @override
  String get appVersion => '版本';

  @override
  String get appVersionDesc => '当前应用版本';

  @override
  String get stationDetail => '台站详情';

  @override
  String get backToTop => '回到顶部';

  @override
  String get installApk => '安装 APRSlocus';

  @override
  String get install => '安装';

  @override
  String get cancelInstall => '取消';

  @override
  String get openFolder => '打开目录';

  @override
  String get browse => '浏览';

  @override
  String get downloadUpdate => '下载更新';

  @override
  String get downloadNow => '立即下载';

  @override
  String get downloading => '下载中';

  @override
  String downloadProgress(Object p) {
    return '下载中 $p%';
  }

  @override
  String get downloadComplete => '下载完成';

  @override
  String get downloadFailed => '下载失败';

  @override
  String get installNow => '立即安装';

  @override
  String get installComplete => '安装完成';

  @override
  String get openInstallDir => '打开安装目录';

  @override
  String get deletePackage => '删除安装包';

  @override
  String get historyVersions => '历史版本';

  @override
  String get current => '当前';

  @override
  String get newVersion => '新版本';

  @override
  String get latestVersion => '当前已是最新版本';

  @override
  String get currentVersion => 'APRSlocus 当前版本';

  @override
  String get checking => '正在检查新版本…';

  @override
  String get checkingGitCode => '检查 GitCode 仓库';

  @override
  String get updateFailed => '检查更新失败';

  @override
  String get noUpdateFound => '当前已是最新版本';

  @override
  String get newVersionFound => '发现新版本';

  @override
  String get downloadAgain => '重新下载安装包';

  @override
  String get openDownloads => '打开下载目录';

  @override
  String get releaseNotes => '更新日志';

  @override
  String currentVsRepo(Object local, Object remote) {
    return '本地 v$local · 仓库最新 v$remote';
  }

  @override
  String installSize(Object os, Object size) {
    return '$os 安装包大小：$size';
  }

  @override
  String get alreadyDownloaded => '安装包已下载';

  @override
  String get downloadReady => '下载一份安装包';

  @override
  String get appInstallDir => '安装目录';

  @override
  String get runInstaller => '运行安装程序';

  @override
  String get downloadUpdateTip => '下载更新并自动打开';

  @override
  String get openDownloadFolder => '打开下载目录';

  @override
  String groupBubble(String name) {
    return '群·$name';
  }

  @override
  String get groupInviteTitle => '群聊邀请';

  @override
  String groupInviteFrom(String from) {
    return '$from 邀请你加入群聊';
  }

  @override
  String groupNameValue(String name) {
    return '群名：$name';
  }

  @override
  String groupCallsignValue(String call) {
    return '群呼号：$call';
  }

  @override
  String groupInviteAccepted(String name) {
    return '已接受邀请，加入 $name';
  }

  @override
  String get accept => '接受';

  @override
  String groupInviteRejected(String name) {
    return '已拒绝 $name 的邀请';
  }

  @override
  String get reject => '拒绝';

  @override
  String get appTagline => 'APRS 定位追踪';

  @override
  String gridValue(String grid) {
    return '网格 $grid';
  }

  @override
  String packetsPerMinute(int count) {
    return '$count/分';
  }

  @override
  String get demo => '演示';

  @override
  String nextBeaconIn(String time) {
    return '下次上报 $time';
  }

  @override
  String beaconCount(int count) {
    return '信标 $count 次';
  }

  @override
  String beaconSentAprsIs(String grid) {
    return '位置已上报 · 网格 $grid · 已发往 APRS-IS';
  }

  @override
  String beaconSentDemo(String grid) {
    return '位置已上报 · 网格 $grid · 演示';
  }

  @override
  String get getLocation => '获取定位';

  @override
  String get disconnect => '断开连接';

  @override
  String get connectAprsIs => '连接 APRS-IS';

  @override
  String get packetsReceived => '收包';

  @override
  String get passcodeUnverified => 'Passcode 未验证';

  @override
  String get passcodeWarning => '登录密码可能错误，无法正常收发消息';

  @override
  String get goSettings => '去设置';

  @override
  String get connectingServer => '正在连接服务器…';

  @override
  String get notConnectedAprsServer => '未连接 APRS-IS 服务器';

  @override
  String connectingToServer(String server, int port) {
    return '正在连接 $server:$port…';
  }

  @override
  String get connectNearbyDesc => '连接后可接收附近台站定位与消息';

  @override
  String get connectAction => '连接';

  @override
  String get backgroundRunTip =>
      '后台运行提示：为保证后台持续定位上报，请到系统设置中允许 APRSlocus 后台运行、关闭省电优化，并允许自启动。';

  @override
  String get connectedAprsIs => '已连接 APRS-IS';

  @override
  String get qqGroupDesc => 'APRSlocus 软件 · 反馈问题/交流使用';

  @override
  String get reselectPoint => '重新选点';

  @override
  String get disableClustering => '关闭聚合';

  @override
  String get enableClustering => '开启聚合';

  @override
  String get noPackets => '暂无数据包';

  @override
  String secondsAgo(int count) {
    return '$count秒前';
  }

  @override
  String minutesAgo(int count) {
    return '$count分前';
  }

  @override
  String hoursAgo(int count) {
    return '$count小时前';
  }

  @override
  String daysAgo(int count) {
    return '$count天前';
  }

  @override
  String copiedCoordsValue(String coords) {
    return '已复制坐标：$coords';
  }

  @override
  String copiedGridValue(String grid) {
    return '已复制网格：$grid';
  }

  @override
  String distanceBearing(String distance, String bearing) {
    return '距我 ${distance}km · 方位 $bearing°';
  }

  @override
  String weatherDataValue(String data) {
    return '气象数据 · $data';
  }

  @override
  String get symbolLabel => '符号';

  @override
  String get digipeaterTapHint => '点击中继台跳转到对应台站';

  @override
  String get copiedFmoInfo => '已复制 FMO 信息';

  @override
  String get copiedAprslocusInfo => '已复制 APRSlocus 信息';

  @override
  String trackPoints(int count) {
    return '轨迹 ($count 点)';
  }

  @override
  String sendMessageTo(String call) {
    return '发消息给 $call…';
  }

  @override
  String get navigationUnavailable => '未安装高德地图，且无法打开其他地图应用';

  @override
  String stationNoData(String call) {
    return '台站 $call 尚未收到数据';
  }

  @override
  String get software => '软件';

  @override
  String get close => '关闭';

  @override
  String get nameLabel => '名称';

  @override
  String get viewSponsorDetails => '查看作者与赞助详情 →';

  @override
  String get thanks => '感谢';

  @override
  String get qqSoftwareName => 'APRSlocus 软件';

  @override
  String get usageNotice => '本软件仅供业余无线电爱好者学习交流使用\n请遵守当地无线电管理法规';

  @override
  String get licenseNotice => 'GNU GPL v3 开源协议 · Copyright © BG7LZQ';

  @override
  String appInfoText(String version) {
    return 'APRSlocus v$version\n作者: BG7LZQ (Darion)\n网站: Theez.top';
  }

  @override
  String get eggBg7lzq => '哎呦你干嘛~';

  @override
  String get eggBg7pgw => '闹呢？';

  @override
  String get eggBg7lmw => '默不作声...';

  @override
  String get eggBg7osl => '你的胆子肥嘟嘟的';

  @override
  String get manualCallsignHint => '手动输入呼号添加';

  @override
  String get noPacketReceived => '未收到数据包';

  @override
  String get feedMode => '瀑布流';

  @override
  String get conversationMode => '会话';

  @override
  String get messageFeed => '消息瀑布流';

  @override
  String messageTotal(int count) {
    return '共 $count 条';
  }

  @override
  String get noMessages => '暂无消息';

  @override
  String get copiedClipboard => '已复制到剪贴板';

  @override
  String get groupShortLabel => '群';

  @override
  String get conversations => '会话';

  @override
  String get noConversations => '暂无会话';

  @override
  String get groupNotFound => '群聊不存在';

  @override
  String get invite => '邀请';

  @override
  String get manage => '管理';

  @override
  String get noGroupMessages => '群聊暂无消息';

  @override
  String get selectConversation => '选择会话开始聊天';

  @override
  String get newConversation => '新建会话';

  @override
  String get newConversationDesc => '输入呼号开始新的会话';

  @override
  String get callsignExample => '呼号，如 BG7ABC';

  @override
  String get start => '开始';

  @override
  String get broadcastMessage => '群发消息';

  @override
  String get noStations => '暂无台站';

  @override
  String get broadcastHint => '提示：每条消息会单独发送给每个接收人';

  @override
  String broadcastSent(int count) {
    return '已群发给 $count 人';
  }

  @override
  String get searchCallsign => '搜索呼号…';

  @override
  String get broadcastContentHint => '输入要群发的内容…';

  @override
  String get groupNameHint => '输入群聊名称';

  @override
  String get create => '创建';

  @override
  String groupCallsignLine(String call) {
    return '群呼号: $call';
  }

  @override
  String get noMembers => '暂无成员';

  @override
  String get inviteMembersHint => '点击下方「邀请成员」添加';

  @override
  String get remove => '移除';

  @override
  String get inviteMembers => '邀请成员';

  @override
  String get deleteGroup => '删除群组';

  @override
  String deleteGroupConfirm(String name) {
    return '确定删除「$name」？此操作不可撤销。';
  }

  @override
  String memberOnlineCount(int members, int online) {
    return '$members 名成员 · $online 在线';
  }

  @override
  String get leaveGroup => '退出群组';

  @override
  String leaveGroupConfirm(String name) {
    return '确定退出「$name」？你将不再收到该群的消息。';
  }

  @override
  String leftGroup(String name) {
    return '已退出 $name';
  }

  @override
  String get leave => '退出';

  @override
  String inviteMembersTo(String name) {
    return '邀请成员到 $name';
  }

  @override
  String get manualCallsign => '手动输入呼号';

  @override
  String inviteSent(String call) {
    return '已发送邀请给 $call';
  }

  @override
  String get noMoreOnlineStations => '暂无更多在线台站';

  @override
  String get invited => '已邀请';

  @override
  String get tapToInvite => '点击邀请';

  @override
  String get done => '完成';

  @override
  String get addContact => '添加联系人';

  @override
  String get addContactDesc => '输入呼号手动添加到联系人列表';

  @override
  String contactAdded(String call) {
    return '已添加联系人 $call';
  }
}
