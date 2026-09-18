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
  String get greetMorning => '早上好，';

  @override
  String get greetNoon => '中午好，';

  @override
  String get greetAfternoon => '下午好，';

  @override
  String get greetEvening => '晚上好，';

  @override
  String get greetNight => '夜深了，';

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
  String get symCatVehicles => '车辆 / 交通';

  @override
  String get symCatBuildings => '建筑 / 设施';

  @override
  String get symCatNature => '气象 / 自然';

  @override
  String get symCatAirWater => '飞行 / 水域';

  @override
  String get symCatComms => '通信 / 其他';

  @override
  String get homeBadgeLabel => '主页展示徽章';

  @override
  String get homeBadgePickTitle => '选择主页展示徽章';

  @override
  String get homeBadgePickDesc => '在以下已获得的徽章中选一个，作为主页常驻展示';

  @override
  String get simLocationHint => '使用模拟位置，无需 GPS';

  @override
  String get speedTierRules => '速度分档规则';

  @override
  String get restoreDefaults => '恢复默认';

  @override
  String get speedTierDesc => '速度越快上报越频繁；每档可自定义间隔与图标（留空=我的符号）。';

  @override
  String get speedTierShortIntervalWarn => '间隔低于 60 秒会显著增加服务器负载，建议 ≥60 秒。';

  @override
  String get addSpeedTier => '添加速度档';

  @override
  String get maxSpeedTiers => '最多 5 个速度档';

  @override
  String get iconDefaultMySymbol => '图标 · 默认(我的符号)';

  @override
  String iconNamed(String name) {
    return '图标 · $name';
  }

  @override
  String everyNSeconds(String sec) {
    return '每 $sec 秒';
  }

  @override
  String get tierIdleTitle => '编辑 · 静止/低速档';

  @override
  String get tierSpeedTitle => '编辑 · 速度档';

  @override
  String get minSpeedKmh => '最低速度 (km/h)';

  @override
  String get intervalSeconds => '上报间隔 (秒)';

  @override
  String get idleTierDesc => '低于第一移动档的速度都按此档上报';

  @override
  String get intervalLabel => '间隔';

  @override
  String get unitSeconds => '秒';

  @override
  String get pickBeaconIconDesc => '选择信标图标 ·「默认」= 沿用我的符号';

  @override
  String get defaultLabel => '默认';

  @override
  String get deleteThisTier => '删除此档';

  @override
  String get idleTierNotDeletable => '静止档不可删除';

  @override
  String get errMinSpeedInt => '最低速度需为 ≥1 的整数';

  @override
  String get errIntervalInt => '上报间隔需为 ≥5 秒的整数';

  @override
  String get errTierDuplicate => '该速度档已存在，速度值需互不相同';

  @override
  String get wsUrlOptional => 'WebSocket URL(可选)';

  @override
  String get countryUnrestricted => '未选择国家/地区 · 不做限制（接收全部台站）';

  @override
  String get weatherWidget => '天气组件';

  @override
  String get groupChatLabel => '群聊';

  @override
  String nItems(String n) {
    return '$n 个';
  }

  @override
  String nMessages(String n) {
    return '$n 条';
  }

  @override
  String confirmDeleteMessages(String n) {
    return '确定要删除全部 $n 条聊天记录吗？此操作不可恢复。';
  }

  @override
  String get weatherSimFollowLive => '跟随实时';

  @override
  String get wxClear => '晴';

  @override
  String get wxCloudy => '多云';

  @override
  String get wxOvercast => '阴';

  @override
  String get wxLightRain => '小雨';

  @override
  String get wxModerateRain => '中雨';

  @override
  String get wxHeavyRain => '大雨';

  @override
  String get wxStormRain => '暴雨';

  @override
  String get wxThunder => '雷阵雨';

  @override
  String get wxSnow => '雪';

  @override
  String get wxFog => '雾';

  @override
  String get weatherSimTitle => '天气模拟（预览背景/特效/建议）';

  @override
  String get weatherSimDesc => '选择后点顶栏天气胶囊预览；「跟随实时」恢复真实天气';

  @override
  String get restartWizardConfirm =>
      '将重新进入首次启动向导，可重新设置呼号、接收地区等。\\n当前设置不会丢失，完成向导后继续使用。';

  @override
  String get restartWizardButton => '重新运行';

  @override
  String get pasteAprsPacketHint =>
      '粘贴原始 APRS 包，如：\\nBV2XYZ>APRS,TCPIP*:!3904.25N/11624.44E>测试台';

  @override
  String beaconsSentCount(String n) {
    return '$n 次';
  }

  @override
  String get myBadgesAndAchievements => '我的徽章与成就';

  @override
  String get quitApp => '退出应用';

  @override
  String get quitAppDesc => '退出后 APRSlocus 将停止定位上报与后台接收，并结束进程。';

  @override
  String get symCar => '汽车';

  @override
  String get openInBrowser => '在浏览器打开';

  @override
  String get badgeWall => '徽章墙';

  @override
  String get achievementWall => '成就墙';

  @override
  String get mapTypeCartoPositron => 'Carto Positron(浅色矢量)';

  @override
  String get mapTypeCarto => 'Carto 浅色';

  @override
  String get mapTypeCartoDark => 'Carto 深色';

  @override
  String get mapTypeCartoVoyager => 'Carto 航行者';

  @override
  String get mapTypeOsm => 'OSM 标准';

  @override
  String get mapTypeOsmHot => 'OSM 人道';

  @override
  String get mapTypeOpenTopo => 'OpenTopo 地形';

  @override
  String get mapTypeEsriStreet => 'Esri 街道';

  @override
  String get mapTypeEsriSat => 'Esri 影像';

  @override
  String get simulatedKeepAlive => '模拟位置 · 后台保活';

  @override
  String get symCatEmergency => '应急救援';

  @override
  String get symSmallAircraft => '小型飞机';

  @override
  String myPositionSet(String grid) {
    return '已设置我的位置，网格 $grid';
  }

  @override
  String get tierIdleShort => '静止/低速';

  @override
  String get symHouse => '房屋';

  @override
  String get symPerson => '人';

  @override
  String get symTruck => '卡车';

  @override
  String get symBicycle => '自行车';

  @override
  String get symRv => '房车';

  @override
  String get symWxStation => '气象站';

  @override
  String get symPolice => '警局';

  @override
  String get symMotorcycle => '摩托';

  @override
  String get symSemi => '半挂车';

  @override
  String get symVan => '面包车';

  @override
  String get symJeep => '吉普';

  @override
  String get symBus => '公交';

  @override
  String get symTruckStop => '卡车停靠';

  @override
  String get symTrain => '火车';

  @override
  String get symFireTruck => '消防车';

  @override
  String get symPoliceCar => '警车';

  @override
  String get symSnowmobile => '雪地摩托';

  @override
  String get symYagi => '八木屋';

  @override
  String get symHospital => '医院';

  @override
  String get symAmbulance => '救护车';

  @override
  String get symFireStation => '消防站';

  @override
  String get symSchool => '学校';

  @override
  String get symMotel => '旅馆';

  @override
  String get symHotel => '酒店';

  @override
  String get symLaptop => '笔记本';

  @override
  String get symPostOffice => '邮局';

  @override
  String get symWeather => '气象';

  @override
  String get symWater => '供水站';

  @override
  String get symHurricane => '飓风';

  @override
  String get symHorse => '骑马';

  @override
  String get symDog => '狗';

  @override
  String get symCamping => '露营';

  @override
  String get symShelter => '避难所';

  @override
  String get symRedCross => '红十字';

  @override
  String get symFireAlarm => '火警';

  @override
  String get symEmergCenter => '应急中心';

  @override
  String get symCmdCenter => '指挥中心';

  @override
  String get symHandicap => '残障';

  @override
  String get symBigAircraft => '大型飞机';

  @override
  String get symGlider => '滑翔机';

  @override
  String get symBalloon => '气球';

  @override
  String get symShip => '船';

  @override
  String get symSailboat => '帆船';

  @override
  String get symMobileSat => '移动卫星';

  @override
  String get symSatAntenna => '卫星天线';

  @override
  String get symDigi => '数字中继';

  @override
  String get symDigiTower => '中继塔';

  @override
  String get symMicE => 'Mic-E 中继';

  @override
  String get symNode => '节点';

  @override
  String get symDxCluster => 'DX 集群';

  @override
  String get symHfGateway => 'HF 网关';

  @override
  String get symFileServer => '文件服务器';

  @override
  String get symTelephone => '电话';

  @override
  String get symGrid => '网格';

  @override
  String get symXUnix => 'X/Unix';

  @override
  String get symFmoStation => 'FMO 台站';

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
  String get languageZhTw => '繁體中文';

  @override
  String get languageJa => '日本語';

  @override
  String get languageId => 'Bahasa Indonesia';

  @override
  String get languageEs => '西班牙语';

  @override
  String get displaySettings => '显示设置';

  @override
  String get uiScale => '界面缩放';

  @override
  String get reloadUi => '重新加载界面';

  @override
  String get reloadDone => '已重新加载';

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
  String get oobeFilterDesc => '勾选要接收的国家/地区；不勾选则接收全部台站，不做限制';

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
  String get groupChat => '群组';

  @override
  String get newGroup => '新建群组';

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
  String get codeContributions => '代码贡献';

  @override
  String get codeContributionI18n => '国际化 / 英文界面';

  @override
  String get codeContributionZhTw => '繁体中文界面';

  @override
  String get codeContributionTranslation => '翻译';

  @override
  String get dataSourceTxHint =>
      '可以同时勾选多条链路一起收报文，但**发射只有一条**（右侧圆点为发射来源）——同一个呼号从两条链路发出去会造成重复报文。';

  @override
  String get dataSourceTxBadge => '发射';

  @override
  String get dataSourceIgateHint =>
      '想当网关（把射频收到的报文转到互联网）就同时勾选 APRS-IS 与 TNC/音频，然后在下面打开「网关」。';

  @override
  String get igateTitle => '网关（iGate）';

  @override
  String get igateSubtitle => '把射频收到的报文送上 APRS-IS';

  @override
  String get igateEnable => '启用网关';

  @override
  String get igateHint =>
      '射频上收到的报文会被送上 APRS-IS（自动加上 qAr/qAR 与你的呼号标识来路）。需要同时启用 APRS-IS 和一个射频来源（TNC / 音频）。';

  @override
  String get igateNeedRf => '还差一个射频来源：请在上面的「数据来源」里勾选 TNC 或音频，否则网关没有可转递的射频链路。';

  @override
  String get igateNeedIs => '还没启用 APRS-IS：请在上面勾选 APRS-IS，否则网关没有可转递的目标网络。';

  @override
  String get igateTwoWay => '双向网关（向射频转递消息）';

  @override
  String get igateTwoWayHint =>
      '打开后会**在射频上真实发射**：只转「发给最近在射频上听到过的台站」的点对点消息（位置/天气等广播不转，避免占满信道）。关闭时只做 RF→IS。';

  @override
  String get igateStatToIs => '已转递 → APRS-IS（条）';

  @override
  String get igateStatToRf => '已转递 → 射频（条）';

  @override
  String get igateStatDup => '重复丢弃（条）';

  @override
  String get igateResetStats => '清空统计';

  @override
  String grpSysJoined(String call) {
    return '$call 加入了群聊';
  }

  @override
  String grpSysLeft(String call) {
    return '$call 离开了群聊';
  }

  @override
  String grpSysJoinReq(String call) {
    return '$call 申请加入群聊';
  }

  @override
  String grpSysDeclined(String call) {
    return '$call 拒绝了邀请';
  }

  @override
  String get grpInviteTitle => '群聊邀请';

  @override
  String grpInviteBody(String from, String name) {
    return '$from 邀请你加入「$name」';
  }

  @override
  String get grpNameInvalid => '群名不能为空、不能包含冒号或换行';

  @override
  String grpNameTooLong(int max) {
    return '群名最长 $max 个字符（过长会让邀请报文超出 APRS 消息上限）';
  }

  @override
  String grpInviteSent(int n) {
    return '已向 $n 位成员发出邀请';
  }

  @override
  String get grpSelfPending => '等待群主确认';

  @override
  String get deviceOverviewTitle => '设备';

  @override
  String get deviceOverviewSubtitle => '数据来源、链路状态与自检';

  @override
  String get deviceCurrentLink => '当前链路';

  @override
  String get deviceCurrentLinkDesc => '只读摘要 · 改参数请进对应子页';

  @override
  String get deviceEntries => '设备与参数';

  @override
  String get deviceEntriesDesc => '每条链路一个子页，各管各的参数';

  @override
  String get tncDeviceTitle => 'TNC 设备与参数';

  @override
  String get tncDeviceDesc => '蓝牙/串口绑定、初始化串、KISS 参数与发射自检';

  @override
  String get deviceLogTitle => '链路日志';

  @override
  String get deviceLogDesc => '显示当前来源的日志（TNC / 音频自动切换）';

  @override
  String get tncInitTitle => 'TNC 初始化串';

  @override
  String get tncInitSubtitle => '连接后逐行发送（等价 APRSdroid 的 kiss.init）';

  @override
  String get tncInitTip =>
      '若 TNC「能收不能发」，先在这里试：很多蓝牙/串口 TNC 模块上电停在命令模式，必须先收到 KISS ON、RESTART 等指令才进入 KISS 转发状态。每行一条命令（发送时自动补 CRLF）。';

  @override
  String get tncInitDelay => '行间隔 (ms)';

  @override
  String get tncInitDelayTip => '每行命令之间的等待时间。模块处理命令需要时间，太短会丢命令';

  @override
  String get tncInitSendAction => '立即发送初始化串';

  @override
  String tncInitSent(int n) {
    return '已发送 $n 行初始化串';
  }

  @override
  String get tncInitEmpty => '未填写初始化串';

  @override
  String get tncPushParams => '连接后下发 KISS 参数';

  @override
  String get tncPushParamsTip =>
      '默认关闭（与 APRSdroid 一致）。打开后连接时会把上面的参数推给 TNC，覆盖它自己的配置 —— 参数不合适可能让它一直退避而不发射，所以只在需要统一管理时打开。';

  @override
  String get tncTxTestTitle => '发射自检';

  @override
  String get tncTxTestSubtitle => '向 TNC 写一帧测试包，判断问题在链路还是 TNC';

  @override
  String get tncTxTestHint =>
      '发的是一帧状态包（不含坐标），不会把台站在 aprs.fi 上挪位置。若这里显示「已写入」却仍然不发射，问题在 TNC 侧：先试初始化串（KISS ON / RESTART），再检查 TxDelay 与信道占用。';

  @override
  String get tncTxTestAction => '写入测试帧';

  @override
  String get tncTxTestOkPrefix => '已写入';

  @override
  String tncTxTestOk(String n) {
    return '已写入 TNC（累计 $n 帧）。若电台仍不发射，问题在 TNC 侧：试初始化串或检查 TxDelay。';
  }

  @override
  String tncTxTestFail(String err) {
    return '未写入：$err';
  }

  @override
  String get tncNeedConnected => '请先连接 TNC';

  @override
  String msgLenCounter(int chars, int bytes) {
    return '$chars/67 字符 · 整包 $bytes/512 字节';
  }

  @override
  String msgOverSpecAsk(int chars) {
    return '这条消息 $chars 个字符，超过 APRS 规范的 67 字符上限。多数客户端仍能读出，但部分客户端/网关会截断或拒收，对方可能解析不出来。仍要发送吗？';
  }

  @override
  String msgOverServerLimit(int bytes, int over) {
    return '整包 $bytes 字节，超过 APRS-IS 单行上限 512 字节，服务器可能直接丢弃整包（连报头都送不到）。请缩短约 $over 字节。';
  }

  @override
  String get msgSendAnyway => '仍要发送';

  @override
  String get msgSpecLimitHint =>
      'APRS 规范建议单条消息不超过 67 字符：超长文本在部分客户端上会显示不全或解析失败。';

  @override
  String get msgBlockedTooLong => '已阻止发送：整包超出 APRS-IS 上限';

  @override
  String get beaconRfBeaconOff => '射频信标未开启';

  @override
  String get beaconRfEnableHint =>
      '射频来源的自动发射需要显式打开「射频信标」。在此之前不会自动发射位置（倒计时也不会走动）。';

  @override
  String get beaconRfEnableAction => '开启射频信标';

  @override
  String get beaconRfEnabled => '已开启射频信标，将按间隔自动发射';

  @override
  String get beaconRfEnableWarn => '发射将使用你的呼号，请在执照范围内操作';

  @override
  String get diagTitle => '链路自检';

  @override
  String get diagSubtitle => '逐层确认协议、权限、设备到底哪一环有问题';

  @override
  String get diagRun => '开始自检';

  @override
  String get diagRunning => '自检中…';

  @override
  String diagPassed(int n) {
    return '通过 $n 项';
  }

  @override
  String diagFailed(int n) {
    return '失败 $n 项';
  }

  @override
  String get diagHint => '协议回路不接电台也能跑：先确认软件层没问题，再去查设备与接线';

  @override
  String get diagTncSection => 'TNC（KISS / AX.25）';

  @override
  String get diagAudioSection => '音频（AFSK 1200）';

  @override
  String get diagKissEscape => 'KISS 转义';

  @override
  String get diagKissEscapeFail => 'KISS 转义还原失败（软件层问题，换设备也没用）';

  @override
  String get diagAx25 => 'AX.25 帧编解码';

  @override
  String get diagAx25Fail => 'AX.25 编码失败（报文格式不合法）';

  @override
  String diagAx25Mismatch(String got) {
    return 'AX.25 回路不一致，解回：$got';
  }

  @override
  String get diagFcs => 'FCS 校验';

  @override
  String get diagFcsFail => 'FCS 校验异常（改动一个字节本应被拒收）';

  @override
  String get diagTncLoopback => 'TNC 协议回路';

  @override
  String diagTncLoopbackOk(int len) {
    return 'KISS/AX.25 编解码往返一致（$len 字节）';
  }

  @override
  String get diagAfskLoopback => 'AFSK 调制解调回路';

  @override
  String diagAfskLoopbackOk(int samples, int rate) {
    return '调制→解调一致（$samples 采样 @${rate}Hz）';
  }

  @override
  String diagAfskLoopbackFail(int n) {
    return '解出 $n 帧（应为 1 帧）';
  }

  @override
  String get diagAfskLevelFail => '波形幅度过低（调制结果接近静音）';

  @override
  String get diagPlatform => '平台能力';

  @override
  String diagPlatformOk(String name) {
    return '可用 · 后端 $name';
  }

  @override
  String get diagTncPlatformNo => '当前平台不支持 TNC 链路';

  @override
  String get diagAudioPlatformWarn => '不支持实时音频 · 仍可用 WAV 文件模式';

  @override
  String get diagNoRealtime => '非实时';

  @override
  String get diagPermission => '录音权限';

  @override
  String get diagPermissionOk => '已授权';

  @override
  String get diagSkipped => '已跳过（平台不支持）';

  @override
  String get diagCapture => '音频采集';

  @override
  String diagCaptureOk(int bytes, int rate) {
    return '收到 $bytes 字节 @${rate}Hz';
  }

  @override
  String get diagCaptureNoData => '没有收到任何音频数据 · 检查输入设备与权限';

  @override
  String diagCaptureFailed(String err) {
    return '打开采集失败：$err';
  }

  @override
  String get diagSpeaker => '扬声器输出';

  @override
  String get diagSpeakerOk => '测试音已播放';

  @override
  String diagSpeakerFail(String err) {
    return '播放失败：$err';
  }

  @override
  String get diagFileIo => 'WAV 文件读写';

  @override
  String diagFileIoOk(int rate) {
    return '写入→读出→解调一致 @${rate}Hz';
  }

  @override
  String diagFileWriteFail(String err) {
    return '文件写入失败：$err';
  }

  @override
  String get diagFileReadFail => '文件读取失败';

  @override
  String get diagFileDecodeFail => '文件里的音频解不出报文（可能不是 AFSK 1200 录音）';

  @override
  String get connAudioSourceHint => '音频模式下不使用服务器、过滤器与 KISS 参数';

  @override
  String get testTxTitle => '测试发射';

  @override
  String get testTxDesc => '发一条状态报文，验证链路真的通到空中';

  @override
  String get testTxAction => '发射测试帧';

  @override
  String get testTxSent => '测试帧已交给链路';

  @override
  String testTxFail(String err) {
    return '测试帧发送失败：$err';
  }

  @override
  String get testTxNeedsConnect => '请先连接链路';

  @override
  String get testTxHint => '这是**真实发射**（状态报文，不含坐标）。射频发射请确认在自己的呼号与执照范围内';

  @override
  String get audioStatsTitle => '音频统计';

  @override
  String audioStatRx(int n) {
    return '收 $n 帧';
  }

  @override
  String audioStatTx(int n) {
    return '发 $n 帧';
  }

  @override
  String audioStatDrop(int n) {
    return '发射期间丢弃 $n 字节';
  }

  @override
  String get audioRestart => '重启音频链路';

  @override
  String get audioTxDisabled => '「允许发射」已关闭，仅接收';

  @override
  String get audioLoopbackHint => '自检会真的做一次调制→解调；提示「发射期间丢弃」属正常半双工行为';

  @override
  String get notifAudioConnected => '音频链路在线';

  @override
  String get notifAudioDisconnected => '音频链路已断开';

  @override
  String connConnectingAudio(String name) {
    return '正在打开音频（$name）…';
  }

  @override
  String connAudioConnected(String rate) {
    return '音频链路在线 · $rate';
  }

  @override
  String connRetryAudio(int seconds) {
    return '音频链路打开失败 · ${seconds}s 后重试…';
  }

  @override
  String connRetryAudioDetail(String detail, int seconds) {
    return '音频打开失败（$detail）· ${seconds}s 后重试…';
  }

  @override
  String connAudioLinkLost(int seconds) {
    return '音频链路中断 · $seconds秒后自动重连…';
  }

  @override
  String connAudioPositionSent(String call) {
    return '音频已发射 · 位置已发送 ($call)';
  }

  @override
  String get dataSourceAudio => '音频（声卡）';

  @override
  String get dataSourceAudioDesc => '用麦克风/扬声器或声卡线接电台，收发 AFSK 1200';

  @override
  String get audioSettings => '音频（声卡 TNC）';

  @override
  String get audioSettingsSubtitle => '用声卡收发 AFSK 1200 报文';

  @override
  String get audioBackend => '音频后端';

  @override
  String get audioUnsupported => '当前平台不支持实时音频（可用 WAV 文件模式）';

  @override
  String get audioNeedPermission => '需要录音权限（RECORD_AUDIO），请授权后重试';

  @override
  String get audioCaptureTitle => '音频采集';

  @override
  String get audioCaptureDesc => '从麦克风/线路输入解调 AFSK 1200';

  @override
  String get audioCaptureStart => '打开采集';

  @override
  String get audioCaptureStop => '停止采集';

  @override
  String get audioSampleRate => '采样率';

  @override
  String get audioSampleRateTip =>
      '22050Hz 是声卡 TNC 常用值；设备不支持时改用 44100/48000。修改会重启采集';

  @override
  String get audioLevel => '输入电平';

  @override
  String get audioLevelTip => '有信号时电平条会抬起；收到 AFSK 时「解调锁定」会点亮';

  @override
  String get audioSynced => '解调锁定';

  @override
  String get audioUnlocked => '未锁定';

  @override
  String audioBadFrames(int n) {
    return '解码中止 $n 次（噪声/失步）';
  }

  @override
  String get audioBaud => '比特率';

  @override
  String get audioTones => '音调（标/空）';

  @override
  String get audioTxTitle => '音频发射';

  @override
  String get audioTxDesc => '发射前先听信道，避免与其它台站碰撞';

  @override
  String get audioTxEnabled => '允许发射';

  @override
  String get audioTxEnabledTip => '关闭后只接收不发射（只想听信标时最省心）';

  @override
  String get audioTxDelayTip => '发射前导时长：给对端解调器锁定时间、给电台 PTT 建立时间';

  @override
  String get audioToneMark => '标号频率 (Hz)';

  @override
  String get audioToneSpace => '空号频率 (Hz)';

  @override
  String get audioMarkTip =>
      'Bell 202 规定标号 1200Hz、空号 2200Hz；只有 ±几 Hz 的容差，不要随意改';

  @override
  String get audioSpaceTip => '空号音调。与标号音调一起决定 FSK 频偏（标准为 1000Hz）';

  @override
  String get audioBaudTip => 'APRS 在 VHF 上固定 1200 bd（Bell 202），HF 才用 300';

  @override
  String get audioTxDelayLabel => '发射前导 (ms)';

  @override
  String get audioTnc2Tip => '格式 SRC>DEST,PATH:info，例如 BG7LZQ-9>APALOC:>TEST';

  @override
  String get audioCsmaWait => '发射前等待信道空闲 (ms)';

  @override
  String get audioCsmaWaitTip => '检测到信道占用时最多等待多久；0 = 不等待直接发射';

  @override
  String get audioStopTx => '停止发射';

  @override
  String get audioWavTitle => 'WAV 文件模式';

  @override
  String get audioWavDesc => '离线解码一段录音，或把报文导出成音频文件';

  @override
  String get audioWavPath => '文件路径';

  @override
  String get audioWavDecodeAction => '解码此 WAV';

  @override
  String get audioWavExportAction => '导出此报文';

  @override
  String get audioWavTnC2 => '待导出报文 (TNC2)';

  @override
  String get audioWavNone => '未解出报文（可能不是 AFSK 1200 录音）';

  @override
  String audioWavFound(int n) {
    return '解出 $n 条报文';
  }

  @override
  String audioWavWritten(String path) {
    return '已写入 $path';
  }

  @override
  String audioWavFailed(String err) {
    return '文件读写失败：$err';
  }

  @override
  String connTncConnected(String arg) {
    return 'TNC 已连接 · $arg';
  }

  @override
  String connTncPositionSent(String arg) {
    return 'TNC 已连接 · 位置已发送 ($arg)';
  }

  @override
  String connRetryTnc(int n) {
    return 'TNC 连接失败 · ${n}s 后重试…';
  }

  @override
  String connRetryTncDetail(String e, int n) {
    return 'TNC 连接失败（$e）· ${n}s 后重试…';
  }

  @override
  String connTncLinkLost(int n) {
    return 'TNC 链路断开 · $n秒后自动重连…';
  }

  @override
  String get tncErrNoDevice => '未绑定 TNC 设备';

  @override
  String get tncErrUnsupported => '当前平台不支持';

  @override
  String get tncErrNotConnected => '链路未连接';

  @override
  String get tncErrOpenRead => '无法打开设备（读）';

  @override
  String get tncErrOpenWrite => '无法打开设备（写）—— Windows 的 COM 口是独占设备，检查是否被其他软件占用';

  @override
  String get tncErrBadFormat => '报文格式不合法';

  @override
  String get tncErrFrameTooLong => '帧长超出上限';

  @override
  String get tncErrTimeout => '连接超时';

  @override
  String get translateMyLang => '我的语言';

  @override
  String get translateMyLangHint => '对方发来的消息翻成它';

  @override
  String get translatePeerLang => '对方的语言';

  @override
  String get translatePeerUnknownHint => '收到对方消息后由翻译接口自动识别';

  @override
  String get translateLearned => '已自动识别';

  @override
  String get translatePeerUnknown => '还不知道对方使用什么语言 · 先在翻译设置里指定，或收几条对方消息后会自动识别';

  @override
  String get translateSideIncoming => '对方发来';

  @override
  String get translateSideOutgoing => '我发出';

  @override
  String get translateToMeTag => '译给我看';

  @override
  String get translateToPeerTag => '对方将读到';

  @override
  String get translateContrast => '对照显示原文与译文';

  @override
  String get translateContrastTip => '关闭后只显示译文（原文仍可通过长按查看）';

  @override
  String get translateProviderFree => '免费接口（无需密钥）';

  @override
  String get translateProviderFreeDesc => '开箱即用 · 使用公开端点，可能被限流或不稳定';

  @override
  String translateFreeFailed(String e) {
    return '免费接口暂时不可用（$e）· 可在设置里改用 Google / 百度 / 自定义接口';
  }

  @override
  String get translateProviderAuto => '自动（推荐）';

  @override
  String get translateProviderAutoDesc => '依次尝试多个免密钥接口，取第一个真正翻译成功的结果';

  @override
  String get translateProviderGooglePublic => 'Google 公开端点（免密钥）';

  @override
  String get translateProviderGooglePublicDesc => '质量较好，但可能被限流（实测会返回 429）';

  @override
  String get translateProviderMyMemory => 'MyMemory（免密钥）';

  @override
  String get translateProviderMyMemoryDesc => '官方免费接口，但本质是翻译记忆库：无匹配语料时会返回原文';

  @override
  String get translateProviderLibre => 'LibreTranslate（可自建）';

  @override
  String get translateProviderLibreDesc => '开源、可自建最可靠；公共实例现已要求密钥且常不支持中文';

  @override
  String get translateLibreUrl => '实例地址';

  @override
  String get translateLibreKey => '实例 API Key（公共实例需要，自建可留空）';

  @override
  String get translateUsedProvider => '本次实际使用';

  @override
  String get translateUntranslated => '接口没有真正翻译（返回了原文）· 已自动尝试下一个接口';

  @override
  String translateAutoAllFailed(String e) {
    return '所有免密钥接口都不可用（$e）· 建议在设置里改用 Google / 百度密钥或自建实例';
  }

  @override
  String get translateLangUnsupported => '该接口不支持翻译成这一语言 · 可改用「自动」或其它接口';

  @override
  String get translateLangScopeNote =>
      '各接口支持的语种范围不同（例如百度标准版支持印尼语 id，但并非所有方向都支持）· 遇到不支持时会提示改用自动或其它接口';

  @override
  String get langNameZh => '简体中文';

  @override
  String get langNameZhTw => '繁体中文';

  @override
  String get langNameEn => '英语';

  @override
  String get langNameJa => '日语';

  @override
  String get langNameKo => '韩语';

  @override
  String get langNameEs => '西班牙语';

  @override
  String get langNameFr => '法语';

  @override
  String get langNameDe => '德语';

  @override
  String get langNameRu => '俄语';

  @override
  String get langNamePt => '葡萄牙语';

  @override
  String get langNameIt => '意大利语';

  @override
  String get langNameId => '印尼语';

  @override
  String get langNameTh => '泰语';

  @override
  String get langNameVi => '越南语';

  @override
  String get langNameAr => '阿拉伯语';

  @override
  String get translateOutgoing => '发送前翻译成对方的语言';

  @override
  String get translateOutgoingTip => '开启后按发送会先把内容译成对方的语言再发出；请确认对方能读懂该语言';

  @override
  String get translateInput => '翻译输入内容';

  @override
  String translateOutPreview(String text) {
    return '将发送：$text';
  }

  @override
  String translateOutPreviewHint(String lang) {
    return '已译为 $lang · 点发送即按此发出';
  }

  @override
  String get translateOutCancel => '取消翻译';

  @override
  String get translateOutNeedPeer => '还不知道对方使用什么语言 · 先在会话翻译设置里指定';

  @override
  String translateSentAs(String text) {
    return '已按对方语言发出：$text';
  }

  @override
  String translateTooLongAfter(int n) {
    return '译文超出长度上限（$n 字符），未发送';
  }

  @override
  String get dateToday => '今天';

  @override
  String get dateYesterday => '昨天';

  @override
  String dateDividerFull(int y, int m, int d, String w) {
    return '$y年$m月$d日 $w';
  }

  @override
  String dateWeekday(String d) {
    String _temp0 = intl.Intl.selectLogic(d, {
      '1': '周一',
      '2': '周二',
      '3': '周三',
      '4': '周四',
      '5': '周五',
      '6': '周六',
      '7': '周日',
      'other': '—',
    });
    return '$_temp0';
  }

  @override
  String get translate => '翻译';

  @override
  String get translateText => '翻译文本';

  @override
  String get translateSettings => '翻译设置';

  @override
  String get translateSettingsSubtitle => '翻译接口、语言与自动翻译';

  @override
  String get translateProvider => '翻译接口';

  @override
  String get translateProviderGoogle => 'Google 翻译';

  @override
  String get translateProviderBaidu => '百度翻译';

  @override
  String get translateProviderCustom => '自定义';

  @override
  String get translateGoogleKey => 'Google API Key';

  @override
  String get translateGoogleKeyTip =>
      'Google Cloud Translation v2 的 API Key，需要自行到 Google Cloud 控制台申请';

  @override
  String get translateBaiduAppId => '百度 App ID';

  @override
  String get translateBaiduKey => '百度密钥';

  @override
  String get translateBaiduTip => '在百度翻译开放平台申请「通用文本翻译」，密钥只保存在本机';

  @override
  String get translateCustomUrl => '接口地址';

  @override
  String get translateCustomMethod => '请求方式';

  @override
  String get translateCustomHeaders => '请求头 (JSON)';

  @override
  String get translateCustomBody => '请求体模板';

  @override
  String translateCustomBodyTip(String text, String from, String to) {
    return '可用占位符：$text 原文、$from 源语言、$to 目标语言。选择 GET 时忽略此项';
  }

  @override
  String get translateCustomResultPath => '结果字段路径';

  @override
  String get translateCustomResultPathTip =>
      '用点号表示层级，数组用序号，如 data.translations.0.translatedText';

  @override
  String get translateTest => '测试翻译';

  @override
  String translateTestOk(String text) {
    return '接口可用：$text';
  }

  @override
  String get translateNeedConfig => '请先填写翻译接口配置';

  @override
  String translateFailed(String e) {
    return '翻译失败：$e';
  }

  @override
  String get translateTargetLang => '翻译为';

  @override
  String get translateSourceLang => '原文语言';

  @override
  String get translateAuto => '自动翻译收到的消息';

  @override
  String get translateAutoTip => '仅对本会话生效；只翻译对方发来的消息';

  @override
  String get translateShowOriginal => '显示原文';

  @override
  String get translateShowTranslation => '显示译文';

  @override
  String get translateRetry => '重新翻译';

  @override
  String get translateTranslating => '正在翻译…';

  @override
  String get translateCopyOriginal => '复制原文';

  @override
  String get translateCopyResult => '复制译文';

  @override
  String get translateLangAuto => '自动检测';

  @override
  String get translateSameLang => '译文与原文相同 · 可能无需翻译，或该接口未能翻译';

  @override
  String get translateNotNeeded => '该内容无需翻译（数字 / 符号 / 呼号）';

  @override
  String translateBubbleCount(int n) {
    return '已翻译 $n 条';
  }

  @override
  String get translatePrivacyNote => '翻译会把消息文本发送到你选择的第三方接口，请自行评估隐私';

  @override
  String get notifTncConnected => 'TNC 已连接';

  @override
  String get notifTncDisconnected => 'TNC 未连接';

  @override
  String get dataSourceTitle => '数据来源';

  @override
  String get dataSourceSubtitle => '报文从哪里来';

  @override
  String get dataSourceAprsIs => 'APRS-IS';

  @override
  String get dataSourceAprsIsDesc => '通过互联网接入全球 APRS 网络';

  @override
  String get dataSourceTnc => 'TNC';

  @override
  String get dataSourceTncDesc => '通过蓝牙或串口的 TNC 与电台直接收发';

  @override
  String get dataSourceSwitchHint => '切换数据来源会断开当前连接';

  @override
  String get dataSourcePkwdwpl => 'PKWDWPL（Kenwood 航点）';

  @override
  String get dataSourcePkwdwplDesc =>
      '用蓝牙/串口读取电台输出的 Kenwood \$PKWDWPL 航点语句（只收不发）';

  @override
  String get dataSourcePkwdwplHint =>
      'PKWDWPL 是**只读**链路：能收台站、不参与发射（发射请用 APRS-IS / TNC / 音频）';

  @override
  String connConnectingPkwdwpl(String arg) {
    return '正在连接 PKWDWPL（$arg）…';
  }

  @override
  String connPkwdwplConnected(String arg) {
    return 'PKWDWPL 已连接 · $arg';
  }

  @override
  String get pkwdwplDeviceTitle => 'PKWDWPL 设备';

  @override
  String get pkwdwplDeviceDesc => '绑定电台端口 · 查看航点接收状态';

  @override
  String get pkwdwplBindTitle => '设备绑定与状态';

  @override
  String get pkwdwplBindSubtitle => '选择输出 \$PKWDWPL 语句的那个串口 / 蓝牙端口';

  @override
  String get pkwdwplRxOnly => '只收不发';

  @override
  String get pkwdwplReadOnly => '只读接收中 · 本机不会发射任何报文';

  @override
  String get deviceConflictTitle => '两条链路绑定了同一台设备';

  @override
  String get deviceConflictDesc =>
      'TNC 与 PKWDWPL 指向同一台设备时，接收到的数据会被两条链路瓜分 —— 表现是「能发不能收」（发送正常、收不到报文）。请给其中一条换一台设备。TNC 优先：PKWDWPL 会拒绝连接。';

  @override
  String get deviceInUseByTnc => '已被 TNC 使用，不能重复绑定';

  @override
  String get deviceInUseByPkwdwpl => '已被 PKWDWPL 使用，不能重复绑定';

  @override
  String rxOnlyBanner(String arg) {
    return '$arg 已连接 · 仅接收（当前发射来源未连接）';
  }

  @override
  String get pkwdwplTip =>
      '在电台菜单里把 PC / GPS 端口的输出格式设为 \"\$PKWDWPL\"（一般 4800 8N1）；这条链路只读，不会发射任何报文';

  @override
  String get pkwdwplStrictChecksum => '严格校验和（不符即丢弃）';

  @override
  String get pkwdwplStrictChecksumTip =>
      '默认关闭：验证不符时只标注并记日志，不丢句子 —— 本地线缆上的不符多半是固件格式与手册有出入，整条丢弃会让界面「什么都不显示」，反而更难排查';

  @override
  String get pkwdwplErrReadOnly => '只读链路，不能发射';

  @override
  String get pkwdwplStatTitle => '航点接收';

  @override
  String pkwdwplStats(String rx) {
    return '已收航点 $rx 条';
  }

  @override
  String get pkwdwplStatRejected => '丢弃/无效语句';

  @override
  String get pkwdwplStatMismatch => '校验和不符';

  @override
  String get pkwdwplStatIgnored => '其它 NMEA 语句（已忽略）';

  @override
  String get pkwdwplLogEmpty => '暂无 PKWDWPL 日志';

  @override
  String get tncBindTitle => '蓝牙 TNC';

  @override
  String get tncBindSubtitle => '绑定并连接电台侧的 TNC';

  @override
  String get tncBoundDevice => '已绑定设备';

  @override
  String get tncNotBound => '未绑定设备';

  @override
  String get tncScanPaired => '扫描已配对设备';

  @override
  String get tncNoPaired => '未找到设备 · 请先在系统蓝牙设置里配对 TNC';

  @override
  String get tncUnbind => '解除绑定';

  @override
  String get tncConnectAction => '连接 TNC';

  @override
  String get tncRestart => '重启链路';

  @override
  String get tncSupportedNo => '当前平台暂不支持 TNC 链路';

  @override
  String get tncNeedPermission => '需要蓝牙权限，请授权后重试';

  @override
  String get tncOpenFailedHint => '打开设备失败 · Windows 的 COM 口是独占设备，请确认没有被其他软件占用';

  @override
  String tncStats(String rx, String tx) {
    return '收 $rx 帧 · 发 $tx 帧';
  }

  @override
  String get tncLog => '链路日志';

  @override
  String get tncLogEmpty => '暂无日志';

  @override
  String get kissParamsTitle => 'KISS 参数';

  @override
  String get kissParamsSubtitle => '直接下发到 TNC 的链路层参数';

  @override
  String get kissTxDelay => '发射延时 (ms)';

  @override
  String get kissTxDelayTip => 'KISS TXDELAY，单位 10ms。发射前留给自己 PTT 建立的时间';

  @override
  String get kissTxTail => '发射尾音 (ms)';

  @override
  String get kissTxTailTip => 'KISS TXTAIL，单位 10ms。某些电台需要尾部保持才能收全';

  @override
  String get kissPersistence => '持续度 P';

  @override
  String get kissPersistenceTip => 'KISS PERSISTENCE，0-255。越小越礼让，共用信道时能减少碰撞';

  @override
  String get kissSlotTime => '时隙 (ms)';

  @override
  String get kissSlotTimeTip => 'KISS SLOTTIME，单位 10ms。与持续度共同决定信道竞争节奏';

  @override
  String get kissFullDuplex => '全双工';

  @override
  String get kissFullDuplexTip => 'KISS FULLDUPLEX，普通电台必须关闭（同时收发会互相干扰）';

  @override
  String get kissChannel => '信道 / KISS 端口';

  @override
  String get kissChannelTip => '多信道 TNC 才有多端口，单信道电台保持 0';

  @override
  String get kissMaxFrame => '帧长上限 (字节)';

  @override
  String get kissMaxFrameTip => '超过此长度的报文不会发出（1200bd 下 AX.25 单帧约 330 字节）';

  @override
  String get kissHardwareCmd => '厂商命令码';

  @override
  String get kissHardwareVal => '参数值';

  @override
  String get kissHardwareTip => 'KISS SETHARDWARE (0x06)，厂商自定义；-1 表示不下发';

  @override
  String get kissApplyParams => '下发参数';

  @override
  String get kissParamsSent => 'KISS 参数已下发';

  @override
  String get kissBackToCommand => '回到 TNC 命令模式';

  @override
  String get kissBackToCommandTip =>
      '发送 RETURN (0x0F)。多数 KISS TNC 会就此停止转发，需重启链路才恢复';

  @override
  String get kissRfPath => '射频中继路径';

  @override
  String get kissRfPathTip => '射频上使用的中继，如 WIDE1-1,WIDE2-1；留空则不指定';

  @override
  String get kissRfBeacon => '允许射频信标';

  @override
  String get kissRfBeaconTip => '打开后才会在射频上定时发射位置。发射需以自己的呼号并在执照范围内操作';

  @override
  String get kissAutoAck => '自动回复 ACK';

  @override
  String get kissAutoAckTip => '关闭后不回应收到的消息回执，可减少射频占用';

  @override
  String get kissAutoReconnect => '断开后自动重连';

  @override
  String get kissNeedConnected => '请先连接 TNC';

  @override
  String get tncSwitchOn => '已开启';

  @override
  String get tncSwitchOff => '已关闭';

  @override
  String get connTncSourceHint => 'TNC 模式下不使用服务器与过滤器，相关设置已停用';

  @override
  String get connectTncBar => '点「连接」建立 TNC 链路';

  @override
  String connectingToTnc(String name) {
    return '正在连接 TNC · $name';
  }

  @override
  String get tncMsgTitle => '射频（TNC）模式';

  @override
  String get tncMsgDesc => '射频信道是共享资源，消息能力相应受限';

  @override
  String get tncGroupDisabled => '射频模式不支持群聊广播';

  @override
  String tncMsgLimitHint(String n) {
    return '单条限 $n 字符（APRS 消息规范）';
  }

  @override
  String get tncMsgTooLong => '超出射频模式单条消息长度上限';

  @override
  String get licenseSection => '许可证声明';

  @override
  String get licenseName => 'GNU GPL v3';

  @override
  String get licenseStatement =>
      '本软件依据 GNU GPL v3 开源许可证发布。你可以在遵守许可证条款的前提下运行、研究、修改和再分发本软件；修改和再分发时须遵守 GPL v3 的相应义务。本软件不附带任何担保。';

  @override
  String get licenseText => '查看许可证';

  @override
  String get oobeAgreeTitle => '用户协议与许可';

  @override
  String get oobeAgreeBody =>
      '欢迎使用 APRSlocus！在使用前，请阅读并同意以下条款。请注意：APRS 数据是公开信息，一旦发送即代表其可能被全球 APRS 网络接收、存储与转发。';

  @override
  String get oobeAgreeCheck => '我已阅读并同意《用户协议》与 GPL-3.0 开源许可证';

  @override
  String get oobeAgreeNeed => '请先阅读并勾选同意《用户协议》';

  @override
  String get oobeDeclineExit => '不同意并退出';

  @override
  String get userAgreement => '用户协议';

  @override
  String get beaconWarnTitle => '信标间隔过短';

  @override
  String get beaconWarnBody =>
      'APRS-IS 建议移动站信标间隔不低于 60 秒。过快的上报可能被视为滥用并导致服务器断开连接。是否仍要使用该间隔？';

  @override
  String get beaconWarnKeep => '仍然使用';

  @override
  String get beaconWarnFix => '改回 60 秒';

  @override
  String get features => '功能特性';

  @override
  String get openSource => '开源致谢';

  @override
  String get feedback => '用户反馈';

  @override
  String get officialWebsite => '官方网站';

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
  String get shareApp => '分享 APRSlocus';

  @override
  String get shareToSystem => '分享到系统';

  @override
  String get shareToSystemDesc => '微信 / QQ / 短信等';

  @override
  String get copyShareText => '复制分享文案';

  @override
  String get openDownload => '打开下载页';

  @override
  String get shareTextCopied => '分享文案已复制，可粘贴发送给好友';

  @override
  String get shareText =>
      'APRSlocus —— 业余无线电 APRS 定位追踪与地图 📡\n实时台站追踪、消息收发、信标上报，Android / Windows 全平台可用。\n官网：https://aprslocus.theez.top/\n下载：https://github.com/dariondong/APRSLocus/releases';

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
  String get smartBeacon => '智能信标(按速度分档)';

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
  String get telemetryTitle => '速度 / 高度变化';

  @override
  String get range10m => '10 分钟';

  @override
  String get range30m => '30 分钟';

  @override
  String get range1h => '1 小时';

  @override
  String get range3h => '3 小时';

  @override
  String get rangeAll => '全部';

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
  String get datumGcj => 'GCJ-02';

  @override
  String get datumWgs => 'WGS-84';

  @override
  String distKm(Object d) {
    return '距离 ${d}km';
  }

  @override
  String get noStationInView => '该区域暂无台站 · 点击显示全部';

  @override
  String get noStationHelp => '该区域暂无台站 · 点击查看帮助';

  @override
  String get mapHelpTitle => '地图帮助';

  @override
  String get mapHelpIntro => '当前视野内没有台站。可能原因：未连接 APRS-IS、接收范围较小或附近暂无活跃台站。';

  @override
  String get mapHelpMove => '拖动 / 缩放：单指拖动地图，双指或滚轮缩放';

  @override
  String get mapHelpStation => '查看台站：点击标记选中并居中，双击打开详情';

  @override
  String get mapHelpLayer => '图层与底图：右上角按钮筛选台站类型、切换地图样式';

  @override
  String get mapHelpLocate => '定位：点击右下角「定位到我」回到当前位置';

  @override
  String get mapHelpSearch => '搜索：顶部搜索框输入呼号可快速定位台站';

  @override
  String get allChangelog => '全部更新日志';

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
  String get featureLiveMap => '在线地图';

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
  String get mapTypeDesc =>
      '「地图 2.0（矢量）」使用客户端实时矢量渲染，数据量小、缩放清晰；栅格图源为在线瓦片，画质取决于网络。';

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
  String get gcj02 => 'GCJ-02';

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
  String deletePackageConfirm(Object file) {
    return '确定删除安装包 $file？';
  }

  @override
  String get deleteAllPackages => '删除全部安装包';

  @override
  String deleteAllPackagesWithCount(Object count) {
    return '删除全部安装包（$count 个）';
  }

  @override
  String deleteAllPackagesConfirm(Object count, Object size) {
    return '将删除本地已下载的 $count 个安装包（共 $size），确定？';
  }

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
  String get groupInviteTitle => '群组邀请';

  @override
  String groupInviteFrom(String from) {
    return '$from 邀请你加入群组';
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
  String get heatmap => '台站热力图';

  @override
  String get heatmapHint => '缩小地图后显示台站密度热力图';

  @override
  String get groupTracking => '群组跟踪';

  @override
  String get groupTrackingHint => '把关心的呼号编成组，在大地图上持续跟踪（车队 / 好友结伴），支持横屏。';

  @override
  String get newTrackGroup => '新建跟踪组';

  @override
  String get trackGroupNameHint => '组名，如：周末骑行';

  @override
  String get editTrackGroup => '编辑跟踪组';

  @override
  String get deleteTrackGroup => '删除跟踪组';

  @override
  String deleteTrackGroupConfirm(Object name) {
    return '确定删除跟踪组「$name」吗？';
  }

  @override
  String get pickTrackMembers => '选择成员（勾选要跟踪的呼号）';

  @override
  String get saveAndTrack => '保存并跟踪';

  @override
  String get trackGroupsEmptyHint => '还没有跟踪组，点「新建跟踪组」创建一组要跟踪的呼号。';

  @override
  String trackMemberSub(Object seen, Object type) {
    return '$type · $seen';
  }

  @override
  String get trackGroupEmpty => '组内成员暂无位置数据（未收到或未上报），点击下方可编辑成员。';

  @override
  String get trackActive => '在线';

  @override
  String get trackWaitingPos => '等待位置…';

  @override
  String get offlineShort => '离线';

  @override
  String get stoppedShort => '静止';

  @override
  String trackHeader(Object fixed, Object online, Object total) {
    return '$total 人 · $online 在线 · $fixed 已定位';
  }

  @override
  String get groupChatShort => '群组';

  @override
  String groupChatTitle(Object name) {
    return '群组 · $name';
  }

  @override
  String chatWithTitle(Object call) {
    return '与 $call 聊天';
  }

  @override
  String get chatToGroupHint => '发消息给全群…';

  @override
  String chatToHint(Object call) {
    return '发给 $call…';
  }

  @override
  String get noMessagesHint => '暂无消息，发一条吧';

  @override
  String trackModeFollow(Object call) {
    return '跟随 $call';
  }

  @override
  String get trackModeMe => '跟随我';

  @override
  String get trackModeFitAll => '全览保持中';

  @override
  String get fitAll => '全览';

  @override
  String get noStationsYet => '暂无台站数据，连接 APRS-IS 后即可选择。';

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
  String get navigationUnavailable => '未安装地图应用，且无法打开其他地图应用';

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
  String get groupNotFound => '群组不存在';

  @override
  String get invite => '邀请';

  @override
  String get manage => '管理';

  @override
  String get noGroupMessages => '群组暂无消息';

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
  String get groupNameHint => '输入群组名称';

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
  String get deleteConversation => '删除会话';

  @override
  String deleteConversationConfirm(Object call) {
    return '确定删除与 $call 的聊天记录吗？该会话将从列表中移除，此操作不可恢复。';
  }

  @override
  String clearGroupChatConfirm(Object name) {
    return '确定清空「$name」的聊天记录吗？此操作不可恢复。';
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

  @override
  String get add => '添加';

  @override
  String get stationary => '静止';

  @override
  String get unknown => '未知';

  @override
  String get none => '无';

  @override
  String get manual => '手动';

  @override
  String get management => '管理';

  @override
  String get debugLabel => '调试';

  @override
  String get information => '信息';

  @override
  String get warning => '警告';

  @override
  String get errorLabel => '错误';

  @override
  String countTimes(int count) {
    return '$count 次';
  }

  @override
  String countItems(int count) {
    return '$count 个';
  }

  @override
  String countEntries(int count) {
    return '$count 条';
  }

  @override
  String aprsSymbolName(String symbol) {
    String _temp0 = intl.Intl.selectLogic(symbol, {
      'car': '汽车',
      'police': '警局',
      'person': '人',
      'digitalRepeater': '数字中继',
      'telephone': '电话',
      'dxCluster': 'DX 集群',
      'hfGateway': 'HF 网关',
      'smallAircraft': '小型飞机',
      'mobileSatellite': '移动卫星',
      'disabled': '残障',
      'snowmobile': '雪地摩托',
      'redCross': '红十字',
      'scouts': '童子军',
      'house': '房屋',
      'redX': '红叉',
      'redDot': '红点',
      'fire': '火警',
      'campground': '露营',
      'motorcycle': '摩托',
      'train': '火车',
      'fileServer': '文件服务器',
      'hurricane': '飓风',
      'dfTriangle': 'DF 三角',
      'postOffice': '邮局',
      'largeAircraft': '大型飞机',
      'weatherStation': '气象站',
      'satelliteDish': '卫星天线',
      'ambulance': '救护车',
      'bicycle': '自行车',
      'commandPost': '指挥中心',
      'fireStation': '消防站',
      'horse': '骑马',
      'fireTruck': '消防车',
      'glider': '滑翔机',
      'hospital': '医院',
      'fmoStation': 'FMO 台站',
      'jeep': '吉普',
      'truck': '卡车',
      'laptop': '笔记本',
      'micERepeater': 'Mic-E 中继',
      'node': '节点',
      'emergencyOps': '应急中心',
      'dog': '狗',
      'gridSquare': '网格',
      'repeaterTower': '中继塔',
      'boat': '船',
      'truckStop': '卡车停靠站',
      'semiTrailer': '半挂车',
      'van': '面包车',
      'waterStation': '供水站',
      'yagi': '八木天线屋',
      'shelter': '避难所',
      'rv': '房车',
      'weatherSymbol': '气象台',
      'balloon': '气球',
      'bus': '公交',
      'shuttle': '航天飞机',
      'policeCar': '警车',
      'sailboat': '帆船',
      'school': '学校',
      'lodging': '旅馆',
      'hotel': '酒店',
      'other': '未知',
    });
    return '$_temp0';
  }

  @override
  String symbolCategoryName(String category) {
    String _temp0 = intl.Intl.selectLogic(category, {
      'vehicles': '车辆 / 交通',
      'facilities': '建筑 / 设施',
      'weatherNature': '气象 / 自然',
      'emergencyRescue': '应急救援',
      'airWater': '飞行 / 水域',
      'communications': '通信 / 其他',
      'other': '其他',
    });
    return '$_temp0';
  }

  @override
  String countryName(String code) {
    String _temp0 = intl.Intl.selectLogic(code, {
      'CN': '中国',
      'KR': '韩国',
      'JP': '日本',
      'US': '美国',
      'CA': '加拿大',
      'GB': '英国',
      'DE': '德国',
      'FR': '法国',
      'IT': '意大利',
      'ES': '西班牙',
      'RU': '俄罗斯',
      'AU': '澳大利亚',
      'NZ': '新西兰',
      'BR': '巴西',
      'AR': '阿根廷',
      'MX': '墨西哥',
      'ZA': '南非',
      'IN': '印度',
      'TH': '泰国',
      'SG': '新加坡',
      'MY': '马来西亚',
      'ID': '印度尼西亚',
      'PH': '菲律宾',
      'TW': '台湾',
      'HK': '香港',
      'MO': '澳门',
      'other': '未知',
    });
    return '$_temp0';
  }

  @override
  String get locationNotFixed => '未定位';

  @override
  String get simulatedLocation => '模拟位置';

  @override
  String get savedLocation => '已保存位置';

  @override
  String get locationFailed => '定位失败';

  @override
  String get locationStopped => '定位已停止';

  @override
  String get locationFixed => '已定位';

  @override
  String get locationPermission => '请授予定位权限…';

  @override
  String get gpsLocating => 'GPS 定位中…';

  @override
  String get webLocationUnsupported => 'Web 平台暂不支持自动定位，请手动输入坐标';

  @override
  String locationStreamError(String error) {
    return '定位流异常：$error';
  }

  @override
  String locationInitError(String error) {
    return '定位初始化失败：$error';
  }

  @override
  String get beaconDisabled => '已关闭';

  @override
  String get waitingForLocation => '等待定位';

  @override
  String get imminent => '即将';

  @override
  String get connTapToConnect => '未连接 · 点击播放按钮连接 APRS-IS';

  @override
  String get connManuallyDisconnected => '未连接 · 已手动断开';

  @override
  String connAutoReconnect(int seconds) {
    return '连接已断开 · $seconds秒后自动重连…';
  }

  @override
  String connConnectingTarget(String target) {
    return '正在连接 $target…';
  }

  @override
  String connOnline(String call) {
    return '已连接 · $call 在线';
  }

  @override
  String connRetry(int seconds) {
    return '连接失败 · ${seconds}s 后重试…';
  }

  @override
  String connPositionSent(String call) {
    return '已连接 · 位置已上报 ($call)';
  }

  @override
  String get connDemoBeacon => '未连接 · 位置已上报（模拟）';

  @override
  String get connPasscodeInvalid => '已连接 · 未验证（Passcode 可能错误）';

  @override
  String get mapTypeAmap => '高德地图';

  @override
  String get mapTypeAmapSatellite => '高德卫星';

  @override
  String get mapTypeVector => '矢量地图';

  @override
  String get amapGroup => '国内地图';

  @override
  String get domesticMaps => '国内地图';

  @override
  String get internationalMaps => '国际地图';

  @override
  String get metricUnits => '公制 (km/h, m)';

  @override
  String get coordDisplay => '坐标显示';

  @override
  String mapDefaultCoord(int level) {
    return '北京 · $level级';
  }

  @override
  String secondsValue(int count) {
    return '$count 秒';
  }

  @override
  String get stationSettingsDetail => '呼号、SSID、符号与备注';

  @override
  String get stationIdentity => '电台身份';

  @override
  String get aprsCallsignHint => 'APRS 呼号，如 BV2AAA';

  @override
  String get displayInfo => '显示信息';

  @override
  String get ssidSuffix => 'SSID 后缀';

  @override
  String get chooseSsidSuffix => '选择 SSID 后缀';

  @override
  String get mySymbol => '我的符号';

  @override
  String get moreSymbols => '更多符号';

  @override
  String get allAprsSymbols => '全部 APRS 符号';

  @override
  String get beaconSettingsDetail => 'GPS 来源、信标与手动定位';

  @override
  String get locationSource => '定位来源';

  @override
  String get useDeviceLocation => '使用设备定位';

  @override
  String get manualCoordinates => '手动输入坐标';

  @override
  String get locationMode => '定位模式';

  @override
  String get settingsLocModeSubtitle => '选择定位方式';

  @override
  String get locModeGps => '纯 GPS';

  @override
  String get locModeGpsDesc => '仅卫星定位，更省电';

  @override
  String get locModeGpsNetwork => 'GPS + 网络';

  @override
  String get locModeGpsNetworkDesc => '网络辅助，定位更快';

  @override
  String get beaconingSection => '信标上报';

  @override
  String get beaconIntervalTip => '位置信标的发送间隔，至少 5 秒';

  @override
  String get beaconContent => '信标上报内容';

  @override
  String get beaconContentDesc => '随位置信标一起发送';

  @override
  String get phoneBattery => '手机电量';

  @override
  String get locationStatus => '定位状态';

  @override
  String get relocate => '重新定位';

  @override
  String get startGps => '开启 GPS 定位';

  @override
  String get trackingBeaconing => '定位运行中，正在持续上报位置';

  @override
  String get manualLocation => '手动定位';

  @override
  String get latitudeHint => '纬度 39.9042';

  @override
  String get longitudeHint => '经度 116.4074';

  @override
  String get invalidLatLng => '请输入有效经纬度';

  @override
  String myLocationSetGrid(String grid) {
    return '已设置我的位置，网格 $grid';
  }

  @override
  String get applyCoordinates => '应用坐标';

  @override
  String get pickOnMap => '在地图选点';

  @override
  String get manualLocationHelp => '无法自动定位时，可手动输入经纬度或用地图选点，用于信标上报与台站距离计算。';

  @override
  String get passcodeTip => 'APRS-IS 登录验证码，可在线生成；填 -1 表示未验证';

  @override
  String get websocketOptional => 'WebSocket URL（可选）';

  @override
  String get configChanged => '配置已修改';

  @override
  String get reconnectToApply => '重新连接后生效';

  @override
  String get reconnected => '已重新连接';

  @override
  String get connectFailedCheckConfig => '连接失败，请检查配置';

  @override
  String get rangeFilterDesc => '只接收设定范围内的台站数据包';

  @override
  String get filterCenterFollows => '过滤中心跟随我的位置';

  @override
  String get radiusTip => '接收半径（km），点“保存并应用”生效';

  @override
  String get maxStationsTip => '内存中保留的最大台站数量（默认不限制，可设更大值）';

  @override
  String filterSavedRadius(String saved, int radius) {
    return '$saved · 半径 ${radius}km';
  }

  @override
  String get receiveFilterDesc2 => '除范围过滤外，按国家/地区分组或精确呼号接收台站';

  @override
  String get receiveCountryDesc => '按呼号前缀批量接收某国家/地区全部台站';

  @override
  String get noCountriesSelected => '未选择国家/地区';

  @override
  String get receiveOthersDesc => '接收不匹配所选国家的特殊呼号台站';

  @override
  String get addCountry => '添加国家/地区';

  @override
  String get chatSettingsDetail => '消息、联系人与聊天数据';

  @override
  String get messageCountLabel => '消息条数';

  @override
  String get manageContacts => '管理联系人';

  @override
  String deleteAllChatsConfirm(int count) {
    return '确定要删除全部 $count 条聊天记录吗？此操作不可恢复。';
  }

  @override
  String get chatCleared => '聊天记录已清空';

  @override
  String get noContacts => '暂无联系人';

  @override
  String get addOrFavoriteContact => '点击右上角“添加”或在地图上收藏台站';

  @override
  String movingWithSpeed(String speed) {
    return '移动中 · $speed';
  }

  @override
  String get callsignMin3 => '呼号至少 3 个字符';

  @override
  String get deleteContact => '删除联系人';

  @override
  String deleteContactConfirm(String call) {
    return '确定删除联系人 $call？';
  }

  @override
  String contactDeleted(String call) {
    return '已删除 $call';
  }

  @override
  String get dataMaintenance => '数据维护';

  @override
  String get clearAllData => '清除所有数据';

  @override
  String get clearAllDataIntro => '此操作将删除以下所有本地数据：';

  @override
  String get chatHistory => '聊天记录';

  @override
  String get logs => '日志';

  @override
  String get irreversibleKeepSettings => '此操作不可恢复，连接设置和呼号不会被删除。';

  @override
  String get confirmClearAllData => '确认清除所有数据';

  @override
  String get clearAllDataConfirm => '确定要清除全部本地数据吗？此操作不可恢复。';

  @override
  String get allDataCleared => '所有数据已清除';

  @override
  String get confirmClear => '确认清除';

  @override
  String get allowLandscape => '允许手机横屏显示';

  @override
  String get packetParseTest => '数据包解析测试';

  @override
  String get packetParseHint =>
      '粘贴原始 APRS 包，如：\nBV2XYZ>APRS,TCPIP*:!3904.25N/11624.44E>Test station';

  @override
  String get parseAndApply => '解析并应用';

  @override
  String get oobePasscodeMissing => 'Passcode 未填写';

  @override
  String get oobePasscodeMissingDesc =>
      'Passcode 是 APRS-IS 登录验证码，用于识别你的呼号。\n\n使用默认值 -1（未验证）虽然可以连接，但将无法正常收发消息与群组。\n\n建议在 https://aprs.cool/AprsPG 输入呼号查询正确 Passcode 后填写。';

  @override
  String get continueAnyway => '仍然继续';

  @override
  String get fillPasscode => '去填写';

  @override
  String get oobeMapFeatureDesc => '在线地图瓦片，查看附近 APRS 台站与轨迹';

  @override
  String get oobeGpsFeatureDesc => '自动获取位置并发送信标到 APRS-IS';

  @override
  String get oobeMsgFeatureDesc => '与台站收发消息，支持自动应答';

  @override
  String get oobeIsFeatureDesc => '连接公共服务器，接收全球台站数据';

  @override
  String get oobeBackgroundTip =>
      '提示：为保证后台持续定位上报，请到系统设置中允许 APRSlocus 后台运行、关闭省电优化，并允许自启动。';

  @override
  String get oobeNextSteps => '接下来几步完成基础配置，随时可在设置中修改。';

  @override
  String get ssidDescShort => 'SSID 是呼号后面的数字标识，如 BG7ABC-9 中的 -9';

  @override
  String get ssidOptional => 'SSID 后缀（可选）';

  @override
  String get noSsid => '无后缀（基本呼号）';

  @override
  String fullCallsign(String call) {
    return '完整呼号：$call';
  }

  @override
  String get passcodeImportant => 'Passcode 非常重要';

  @override
  String get passcodeImportantDesc =>
      '正确的 Passcode 是接收群组消息和发送确认消息的前提。填 -1 虽然可以连接，但无法正常收发消息。';

  @override
  String get lookupPasscode => '点击查询你的 Passcode →';

  @override
  String get passcodeLookupHint => '输入你的呼号即可获取，例如 BV2AAA';

  @override
  String sendToGroupHint(String group) {
    return '发到 $group…';
  }

  @override
  String sendToCallHint(String call) {
    return '发给 $call…';
  }

  @override
  String get selectMessageReply => '点选消息以回复…';

  @override
  String get broadcastShort => '群发';

  @override
  String memberCount(int count) {
    return '$count 个成员';
  }

  @override
  String memberCountTap(int count) {
    return '$count 名成员 · 点击查看';
  }

  @override
  String get stepRecipients => '选人';

  @override
  String get stepContent => '内容';

  @override
  String get selectAllOnline => '全选在线';

  @override
  String get clearSelection => '取消全选';

  @override
  String get onlineOnly => '仅在线';

  @override
  String get noRecipients => '未选择接收人';

  @override
  String selectedRecipients(int count) {
    return '已选 $count 人';
  }

  @override
  String sendRecipientsList(int count, String calls) {
    return '将发送给 $count 人：$calls';
  }

  @override
  String get stepName => '名称';

  @override
  String get stepMembers => '成员';

  @override
  String get groupChatExplain => '群组使用群呼号广播消息，所有成员都能收到。创建后系统会自动生成群呼号并邀请你选择的成员。';

  @override
  String get noMembersSelected => '未选择成员';

  @override
  String get memberBlocked => '已屏蔽';

  @override
  String get memberJoined => '已加入';

  @override
  String get memberPending => '待确认';

  @override
  String get memberDeclined => '已拒绝';

  @override
  String get memberLeft => '已退出';

  @override
  String get memberTimeout => '超时';

  @override
  String get unblock => '解除屏蔽';

  @override
  String get block => '屏蔽';

  @override
  String get groupOwner => '群主';

  @override
  String systemMemberJoined(String call) {
    return '$call 加入了群组';
  }

  @override
  String systemMemberLeft(String call) {
    return '$call 离开了群组';
  }

  @override
  String systemInviteDeclined(String call) {
    return '$call 拒绝了邀请';
  }

  @override
  String get copyAllLogs => '复制全部日志';

  @override
  String copiedLogs(int count) {
    return '已复制 $count 条日志';
  }

  @override
  String get clearLogs => '清空日志';

  @override
  String get noLogs => '暂无日志';

  @override
  String get supportProject => '你们的支持让项目走得更远';

  @override
  String get continuousIteration => '持续迭代';

  @override
  String get continuousIterationDesc => '不断改进 APRSlocus 功能与体验';

  @override
  String get sponsorSupport => '赞助支持';

  @override
  String get sponsorMethods => '赞助方式';

  @override
  String qrCodeTitle(String title) {
    return '$title 赞赏码';
  }

  @override
  String get qrLoadFailed => '赞赏码图片加载失败';

  @override
  String get qrSaveWechat => '长按图片可保存 · 微信扫一扫赞赏';

  @override
  String get tapAnywhereClose => '点击任意处关闭';

  @override
  String vectorMapLoadFailed(String error) {
    return '矢量地图加载失败\n$error';
  }

  @override
  String get loadingVectorMap => '加载矢量地图…';

  @override
  String get updateChannel => '更新渠道';

  @override
  String serverReturned(int code) {
    return '服务器返回 $code';
  }

  @override
  String get invalidResponseData => '返回数据格式错误';

  @override
  String get noVersionsFound => '没有找到任何版本';

  @override
  String get noWindowsInstaller => '该版本没有 Windows 安装包';

  @override
  String get noApkInstaller => '该版本没有 APK 安装包';

  @override
  String get connectingEllipsis => '正在连接…';

  @override
  String downloadHttpError(int code) {
    return '下载失败：HTTP $code';
  }

  @override
  String downloadedBytes(String received, String total) {
    return '已下载 $received / $total';
  }

  @override
  String androidInstallHelp(String path) {
    return '安装包已下载到：\n$path\n\n点击“安装”后，系统会弹出安装确认框。\n\n若提示“不允许安装未知来源应用”，请到系统设置中允许本应用安装未知应用。';
  }

  @override
  String windowsInstallHelp(String path) {
    return '安装包已保存到：\n$path\n\n点击“立即运行”直接启动安装程序；也可以打开所在目录查看文件。';
  }

  @override
  String get openContainingFolder => '打开所在目录';

  @override
  String get runNow => '立即运行';

  @override
  String get cannotRunInstaller => '无法启动安装程序，请到所在目录手动打开';

  @override
  String get cannotLaunchInstaller => '无法启动安装器，请手动打开安装包';

  @override
  String get openPackageManually => '请在文件管理器中打开安装包';

  @override
  String cannotOpenPackage(String error) {
    return '无法打开安装包：$error';
  }

  @override
  String get installPermissionTitle => '需要允许安装应用';

  @override
  String get installPermissionDesc =>
      '检测到系统未允许 APRSlocus 安装应用。\n\n请点击“去设置”，在“安装未知应用”中允许本应用安装应用，然后返回重新安装。';

  @override
  String get recheck => '重新检查';

  @override
  String newVersionTitle(String version) {
    return '发现新版本 v$version';
  }

  @override
  String repoLatestTitle(String version) {
    return '仓库最新版本 v$version';
  }

  @override
  String get checkingLatest => '正在检查最新版本…';

  @override
  String get connectingGitCode => '连接 GitCode 服务器';

  @override
  String get noReleaseNotes => '暂无更新说明';

  @override
  String noInstallerHistoryHint(String platform) {
    return '该版本暂无 $platform 安装包，请到历史版本中选择可下载的版本';
  }

  @override
  String get latestVersionLabel => '最新版本';

  @override
  String packageSize(String platform, String size) {
    return '$platform 安装包大小：$size';
  }

  @override
  String get updateContents => '更新内容';

  @override
  String get redownload => '重新下载';

  @override
  String get downloadInstaller => '下载安装包';

  @override
  String get downloadAndInstall => '下载并安装';

  @override
  String get localPackageExists => '本地已有一份安装包';

  @override
  String get packageDeleted => '安装包已删除';

  @override
  String versionCount(int count) {
    return '$count 个';
  }

  @override
  String get noInstaller => '无安装包';

  @override
  String get download => '下载';

  @override
  String get viewChangelog => '查看更新日志';

  @override
  String versionChangelog(String version) {
    return 'v$version 更新日志';
  }

  @override
  String get gotIt => '知道了';

  @override
  String get leaveAction => '退出';

  @override
  String localRepoVersion(Object latest, Object local) {
    return '本地 v$local · 仓库最新 v$latest';
  }

  @override
  String get unverified => '未验证';

  @override
  String get passcodeUnverifiedHint => '-1 未验证';

  @override
  String get passcodeMessageWarning => 'APRS-IS 登录验证码，填 -1 无法正常收发消息';

  @override
  String get settingsStationIdentitySubtitle => '呼号、SSID 与备注';

  @override
  String get settingsDisplayInfoSubtitle => '我的符号与当前定位';

  @override
  String get settingsLocSourceSubtitle => '选择坐标来源';

  @override
  String get settingsBeaconSubtitle => '发送间隔与上报内容';

  @override
  String get settingsManualLocSubtitle => '无定位时可手动输入或选点';

  @override
  String get settingsManualLocHint => '无法自动定位时，可手动输入经纬度或用地图选点，用于信标上报与台站距离计算。';

  @override
  String get settingsConnStatusSubtitle => '连接状态与信息';

  @override
  String get settingsServerSubtitle => 'APRS-IS 服务器与验证码';

  @override
  String get settingsFilterSubtitle => '过滤中心与接收半径';

  @override
  String get settingsReceivePrefSubtitle => '按国家/地区或呼号接收';

  @override
  String get settingsGeneralSubtitle => '主题、语言与坐标显示';

  @override
  String get settingsMapSubtitle => '地图类型与显示';

  @override
  String get settingsChatStatsSubtitle => '消息与联系人统计';

  @override
  String get settingsChatManageSubtitle => '联系人与聊天数据';

  @override
  String get settingsClearDataSubtitle => '删除本地记录';

  @override
  String get settingsLabSubtitle => '实验性功能';

  @override
  String get settingsDevSubtitle => '调试与测试';

  @override
  String get settingsFilterHint => '只接收设定范围内的台站数据包';

  @override
  String get settingsReceivePrefHint => '除范围过滤外，按国家/地区分组或精确呼号接收台站';

  @override
  String get settingsContribCodeOptimization => '代码优化';

  @override
  String get eggBg2hcb => '人生真是喵喵又咪咪啊';

  @override
  String get deviceInfoTitle => '设备识别';

  @override
  String get deviceToCall => '目的呼号';

  @override
  String get deviceModel => '设备型号';

  @override
  String get deviceClass => '设备类别';

  @override
  String get deviceFilter => '设备筛选';

  @override
  String get lookupQrz => 'QRZ 呼号';

  @override
  String get lookupAprsFi => 'aprs.fi 位置';

  @override
  String get aprsTv => 'APRS.tv';

  @override
  String get aprsTvInfo => '详情页';

  @override
  String get aprsTvMap => '在地图上查看';

  @override
  String get linkOpenFailed => '无法打开链接';

  @override
  String get beaconAutoAskTitle => '连接成功，自动上报位置？';

  @override
  String get beaconAutoAskDesc =>
      '是否让 APRSlocus 在连接后自动定时上报你的位置（信标）？移动台建议开启；若只想接收消息与看周边台站，可关闭（随时可手动上报一次）。';

  @override
  String get beaconAutoYes => '自动上报';

  @override
  String get beaconAutoNo => '暂不，仅接收';

  @override
  String get beaconOffChip => '自动上报已关闭';

  @override
  String get quickTrackCreate => '新建跟踪组';

  @override
  String get quickTrackHint => '从已接收台站勾选成员，也可手输呼号补充；直接在地图上跟踪这些人，不需要先建聊天群。';

  @override
  String get quickTrackName => '组名（可选）';

  @override
  String get quickTrackPickLabel => '选择要跟踪的台站';

  @override
  String get quickTrackNoStations => '暂无已接收台站，可直接手输呼号（多个用逗号分隔）';

  @override
  String get quickTrackManualHint => '手输呼号，如 BG7PGW,BG7LMW';

  @override
  String get quickTrackStart => '开始跟踪';

  @override
  String get quickTrackNeedMembers => '请至少选择或输入一个呼号';

  @override
  String get weatherPanelTitle => '天气 · 火腿建议';

  @override
  String get weatherPanelSub => '和风天气 · 当前位置';

  @override
  String get weatherRefresh => '刷新';

  @override
  String get weatherPowered => '数据由和风天气提供 · APRSlocus';

  @override
  String get hfTitle => '短波传播';

  @override
  String get hfSixMeter => '6m 波段';

  @override
  String get hfEs => 'Es 偶发 E 层';

  @override
  String get hfAurora => '极光';

  @override
  String get hfF2 => 'F2 层';

  @override
  String get hfBand => '波段';

  @override
  String get hfDay => '日间';

  @override
  String get hfNight => '夜间';

  @override
  String get hfSfi => '太阳通量';

  @override
  String get hfKp => '地磁 Kp';

  @override
  String get hfAIndex => 'A 指数';

  @override
  String get hfSunspots => '太阳黑子';

  @override
  String get hfXray => 'X 射线';

  @override
  String get hfSolarWind => '太阳风速';

  @override
  String get hfGeomag => '地磁';

  @override
  String get hfNoise => '底噪';

  @override
  String get hfMuf => '最高可用频率';

  @override
  String get hfNoData => '暂无短波传播数据：联网后自动获取';

  @override
  String get hfUnavailable => '短波传播服务暂时不可用';

  @override
  String get hfQGood => '好';

  @override
  String get hfQFair => '一般';

  @override
  String get hfQPoor => '差';

  @override
  String get hfQClosed => '未开通';

  @override
  String get hfPowered => '传播数据由 hamqsl.com（N0NBH）提供 · 全球平均，非本地实测';

  @override
  String get hfTipStorm =>
      '地磁暴（Kp≥5）：极区短波路径衰减明显，跨极地 DX 基本中断；改走低纬度路径或转本地 VHF/UHF';

  @override
  String get hfTipGeomagActive => '地磁较活跃：短波高纬度路径不如平时稳定，DX 通联建议留出更多呼叫时间';

  @override
  String get hfTipLowSfi =>
      '太阳活动偏低（SFI<100）：白天高波段（15m/12m/10m）机会少，优先 40m/30m/20m';

  @override
  String get hfTipHighSfi => '太阳活动活跃（SFI≥150）：白天高波段（15m/12m/10m）有机会远距离 DX';

  @override
  String get hfTipHighNoise => '底噪偏高：弱信号接收困难，建议收窄带宽、降低前置增益，必要时用窄带模式';

  @override
  String hfTipBandGood(String b) {
    return '$b 传播条件好：本时段优先用这一段呼叫';
  }

  @override
  String hfTipBandPoor(String b) {
    return '$b 条件偏差：换到其它波段，或等日落/日出灰线再试';
  }

  @override
  String get weatherCurLoc => '当前位置';

  @override
  String get weatherNoLoc => '暂无定位：请在“我的电台”开启位置服务后查看天气';

  @override
  String get weatherUnavail => '天气服务暂时不可用';

  @override
  String get weatherDataFail => '天气数据获取失败';

  @override
  String get weatherConnFail => '天气服务连接失败';

  @override
  String get weatherCloud => '云量';

  @override
  String get weatherDew => '露点';

  @override
  String get weatherHumidity => '湿度';

  @override
  String get weatherWindDir => '风向';

  @override
  String get weatherWindScale => '风力';

  @override
  String get weatherWindSpeed => '风速';

  @override
  String get weatherPressure => '气压';

  @override
  String get weatherVis => '能见度';

  @override
  String get weatherPrecip => '降水';

  @override
  String weatherFeels(String v) {
    return '体感 $v°';
  }

  @override
  String weatherObserved(String t) {
    return '观测 $t';
  }

  @override
  String get hamTitle => '业余无线电建议';

  @override
  String get hamNoData => '获取天气后，将给出适合架台/通联/防雷的安全建议';

  @override
  String get hamStorm1 => '雷雨天气：请勿在室外架设/操作天线！断开天线馈线，谨防雷击感应损坏设备';

  @override
  String get hamStorm2 => '如已架设，尽快收纳拉倒；转为室内收听中继与短波，注意设备防潮';

  @override
  String get hamRain => '有降水：户外架台请备防雨罩/防水箱，接口用胶带或热缩管密封，馈线避免积水';

  @override
  String get hamCold => '低温/降雪：锂电池容量明显下降，多备电池并贴身保暖；天线结冰注意驻波变化';

  @override
  String hamWind(String w) {
    return '风力 $w 级：架设天线务必拉好风绳加固，八木/长线收工时放倒，避免倾倒';
  }

  @override
  String hamHot(String t) {
    return '高温 $t°C：注意防暑补水，设备避免长时间满功率发射导致过热';
  }

  @override
  String hamHumid(String h) {
    return '湿度 $h%：潮湿会降低绝缘与天线效率，VHF/UHF 信号衰减偏大，注意接口防锈';
  }

  @override
  String hamFog(String v) {
    return '能见度低（${v}km）：出行架台注意安全；雾天易形成大气波导，可尝试远地 V/U 通联';
  }

  @override
  String get hamGood => '天气良好，适合架台！UV 段可尝试本地中继与直频；短波留意晚间电离层变化';

  @override
  String hamWindExtra(String w) {
    return '虽有 $w 级风，仍建议为天线加固风绳，野外架台注意安全';
  }

  @override
  String get hamStorm3 =>
      '雷电临近：把天线馈线从设备上拔下并移至室外接地端泄放，关闭电源并拔掉插头，避免浪涌经市电、网线窜入；不要使用室外天线与有线电话';

  @override
  String get hamStorm4 => '雷暴前后静电噪声（QRN）骤增、短波底噪抬升；雷电活动结束后约 30 分钟再恢复架台与发射';

  @override
  String get hamExtreme => '暴雨/极端降水：注意山洪、积水与落石，勿在河岸、低洼处架台；馈线入墙处做滴水弯，防止雨水顺线灌入室内';

  @override
  String hamGale(String w) {
    return '风力 $w 级：禁止上塔、爬杆作业！八木与长线天线务必放倒或降下，检查风绳、地锚与桅杆拉线';
  }

  @override
  String get hamIce => '天线与馈线结冰会升高驻波（SWR）并增加冰载：切勿满功率硬发，先检查拉线受力，待化冰后再正常通联';

  @override
  String get hamFrost => '气温低于 0℃：锂电池容量骤降，备用电池请贴身保温；注意手部与面部冻伤，带上暖手宝';

  @override
  String get hamHeat2 => '高温易使功放与电源过热降额：适当降低功率、缩短连续发射时间，并保证通风散热';

  @override
  String get hamDust => '沙尘天气：细沙渗入接头与绝缘子会造成泄漏和噪声，请加防尘罩；干燥摩擦易积累静电，注意接地泄放';

  @override
  String get hamAir => '空气质量差：户外架台请佩戴口罩并减少剧烈活动；污染物附着天线绝缘子会引入泄漏噪声，收工后清洁';

  @override
  String hamDew(String d) {
    return '露点差仅 $d℃，空气接近饱和：设备与馈线易结露，收工后先缓温除湿再通电，避免短路';
  }

  @override
  String hamUV(String u) {
    return '紫外线指数 $u，强度偏高：野外架台注意防晒；长期暴晒会加速同轴电缆外皮与扎带老化';
  }

  @override
  String hamLowPressure(String p) {
    return '气压偏低（$p hPa）：天气趋于不稳，长时间野外架台请留好退路并留意临近预警';
  }

  @override
  String hamHighPressure(String p) {
    return '气压较高（$p hPa）且稳定：易形成逆温层，VHF/UHF 可能出现大气波导，可尝试超视距远地直频或中继通联';
  }

  @override
  String get hamGrayLine => '正值日出/日落灰线时段：20/40m 短波传播最佳，是跨洲远程（DX）通联的黄金窗口';

  @override
  String get hamNight => '夜间 D 层消失：80/40m 吸收减小、噪声较低，适合本土与夜间远程通信';

  @override
  String get hamRainFade => '较强降水对 1.2GHz 以上频段有雨衰影响：微波与 EME 通联建议改用较低频段或等雨势减弱';

  @override
  String get hamShower => '阵雨来去突然：架台请备好防雨罩并留意云团移动，收工前先断开发射再拆馈线';

  @override
  String get hamLevelDanger => '安全警示';

  @override
  String get hamLevelWarn => '注意';

  @override
  String get hamLevelGood => '通联机会';

  @override
  String get hamLevelTip => '操作提示';

  @override
  String hamMore(String n) {
    return '展开全部 $n 条建议';
  }

  @override
  String get hamLess => '收起';

  @override
  String get weatherForecast3 => '三天预报';

  @override
  String get weatherDaily15 => '查看近 15 日天气';

  @override
  String get weatherDaily15Title => '近 15 日天气趋势';

  @override
  String get weatherToday => '今天';

  @override
  String get weatherTomorrow => '明天';

  @override
  String get weatherDayAfter => '后天';

  @override
  String weatherWeekday(String d) {
    String _temp0 = intl.Intl.selectLogic(d, {
      '1': '周一',
      '2': '周二',
      '3': '周三',
      '4': '周四',
      '5': '周五',
      '6': '周六',
      '7': '周日',
      'other': '—',
    });
    return '$_temp0';
  }

  @override
  String get weatherSunrise => '日出';

  @override
  String get weatherSunset => '日落';

  @override
  String get weatherUV => '紫外线';

  @override
  String get weatherDetails => '详细数据';

  @override
  String get weatherAQIPrimary => '首要污染物';

  @override
  String get airExcellent => '优';

  @override
  String get airGood => '良';

  @override
  String get airModerate => '轻度污染';

  @override
  String get airUnhealthy => '中度污染';

  @override
  String get airVeryUnhealthy => '重度污染';

  @override
  String get airHazardous => '严重污染';

  @override
  String get weatherAir => '空气质量';

  @override
  String get issStation => 'ISS 空间站';

  @override
  String get applyStationFilter => '台站筛选应用到地图';

  @override
  String get stationFilterOn => '已按台站面板筛选显示';

  @override
  String get stationList => '台站列表';

  @override
  String get statsPanel => '统计面板';

  @override
  String get statsOverview => '系统总览';

  @override
  String get statsTotalRx => '总接收数';

  @override
  String get statsTotalTx => '总发送数';

  @override
  String get statsRate => '接收速率';

  @override
  String statsPerMin(String n) {
    return '$n/分';
  }

  @override
  String get statsStationsTotal => '台站总数';

  @override
  String get statsCap => '容量上限';

  @override
  String get statsConn => '连接状态';

  @override
  String get statsConnected => '已连接';

  @override
  String get statsDisconnected => '未连接';

  @override
  String get statsMyGrid => '我的大网格';

  @override
  String get statsAprslocusUsers => 'APRSlocus 用户';

  @override
  String get statsFarthest => '最远台站';

  @override
  String get statsStatusDist => '台站状态分布';

  @override
  String get statsTypeDist => 'APRS 类型分布';

  @override
  String get statsGridDist => '大网格台站分布';

  @override
  String get statsGridHint => '按 Maidenhead 大网格（4 位）统计台站数量并排序';

  @override
  String statsGridCount(String n) {
    return '$n 个网格';
  }

  @override
  String get statsGridEmpty => '暂无台站位置数据';

  @override
  String get statsDeviceDist => '设备类别分布';

  @override
  String get statsOther => '其他指标';

  @override
  String get statsAvgSpeed => '平均速度';

  @override
  String get statsLastHeard => '最近上报';

  @override
  String get statsPackets => '数据包(近期)';

  @override
  String get statsNoData => '暂无数据';

  @override
  String get noStationsFiltered => '当前筛选条件下没有台站';

  @override
  String get noStationsFilteredHint => '筛选或接收范围过窄。可清除筛选后重试，接收范围见「设置 → 接收范围」。';

  @override
  String get clearStationFilter => '清除筛选';

  @override
  String get clearSearch => '清除搜索';

  @override
  String get activeConditions => '生效条件';

  @override
  String get statsMovingCount => '移动台站';

  @override
  String get statsOnlineRate => '在线率';

  @override
  String get statsGridCountLabel => '大网格数';

  @override
  String get maxPackets => '数据包保留条数';

  @override
  String get maxPacketsTip => '数据包页面保留的历史条数（默认 2000，提高会占用更多内存）';

  @override
  String get maxTrackPts => '轨迹点数上限';

  @override
  String get maxTrackPtsTip => '每个台站保留的轨迹点数（默认 300，决定运动轨迹能回溯多长；仅位移超过 20m 才记点）';

  @override
  String get onlineWindow => '在线判定时长（分钟）';

  @override
  String get onlineWindowTip => '台站最后上报超过该时长即视为离线（默认 5 分钟）';

  @override
  String get chatRecords => '聊天记录';

  @override
  String get chatRecordsCleared => '聊天记录已清空';

  @override
  String get deviceCat => '设备';

  @override
  String get deviceCatDesc => '电台设备 · 待开放';

  @override
  String get deviceSettings2 => '设备设置';

  @override
  String get deviceSettingsSubtitle => '连接你的电台设备';

  @override
  String get underConstruction => '前方施工，尚未开放';

  @override
  String get underConstructionHint => '该功能正在开发中，敬请期待';

  @override
  String get storageLimit => '数据上限';

  @override
  String get storageLimitSubtitle => '本地保留的数据量';

  @override
  String get connectionCard2 => 'APRS-IS 连接';

  @override
  String get immersiveMap => '沉浸地图';

  @override
  String get immersiveMapTip => '导航风格：以我为中心、航向朝上、四角 HUD';

  @override
  String get headingUp => '航向朝上';

  @override
  String get northUp => '正北朝上';

  @override
  String get followMe => '跟随我';

  @override
  String get beaconCountdown => '发送倒计时';

  @override
  String get beaconOff => '未开启';

  @override
  String get unlocated => '未定位';

  @override
  String get platform => '平台';

  @override
  String get nearbyStations => '附近台站';

  @override
  String get honorWall => '荣誉墙';

  @override
  String get accountHonors => '账号荣誉';

  @override
  String get achievementsSection => '成就';

  @override
  String get notLit => '未点亮';

  @override
  String honorCriteriaLine(String c) {
    return '获得条件：$c';
  }

  @override
  String get badgeFallback => '徽章';

  @override
  String honoredBadges(String n, String m) {
    return '已点亮 $n/$m 徽章';
  }

  @override
  String achievementsProgress(String n, String m) {
    return '$n/$m 成就';
  }

  @override
  String get beaconNotConnected => '未连接';

  @override
  String get beaconWaitingFix => '等待定位';

  @override
  String get beaconSoon => '即将';

  @override
  String beaconNextIn(String s) {
    return '距下次上报 $s';
  }

  @override
  String get beaconImminent => '即将上报…';

  @override
  String get notifConnected => '已连接';

  @override
  String get notifConnecting => '连接中';

  @override
  String get notifDisconnected => '未连接';

  @override
  String notifOnline(String n) {
    return '$n 在线';
  }

  @override
  String notifRx(String n) {
    return '收 $n';
  }

  @override
  String notifBeacon(String v) {
    return '信标 $v';
  }

  @override
  String get selectAll => '全选';

  @override
  String get deselectAll => '取消全选';

  @override
  String selectedCount(int n) {
    return '已选 $n 项';
  }

  @override
  String deleteSelected(int n) {
    return '删除 ($n)';
  }

  @override
  String deleteSelectedConfirm(int n) {
    return '确定删除选中的 $n 个会话？此操作不可恢复。';
  }

  @override
  String get chatManageHint => '点击会话进行选择，长按也可选中';

  @override
  String conversationsDeleted(int n) {
    return '已删除 $n 个会话';
  }

  @override
  String get stationActions => '台站操作';

  @override
  String get deleteStation => '删除台站';

  @override
  String deleteStationConfirm(String name) {
    return '确定删除台站 $name 吗？删除后将从台站列表移除；若再次收到其报文会重新出现。';
  }

  @override
  String get unfavorite => '取消收藏';

  @override
  String get copyCallsign => '复制呼号';

  @override
  String get callsignCopied => '呼号已复制';

  @override
  String get stationDeleted => '已删除台站';

  @override
  String get exportAdif => '导出 ADIF';

  @override
  String get exportAdifDesc => '把会话导出为 ADIF 日志文件，可导入 Log4OM、N3FJP 等日志软件';

  @override
  String get export => '导出';

  @override
  String get adifHint => '每条记录只含呼号与首条消息时间（UTC），不含模式与频段';

  @override
  String get adifNoSelection => '请先选择要导出的会话';

  @override
  String adifExported(int n) {
    return '已导出 $n 条记录';
  }

  @override
  String get adifExportDone => '导出完成';

  @override
  String get adifExportFailed => '导出失败，请检查存储权限或剩余空间';

  @override
  String adifSavedTo(String path) {
    return '已保存到：$path';
  }

  @override
  String get adifCopyPath => '复制路径';

  @override
  String get adifPathCopied => '路径已复制';

  @override
  String get chatShortLabel => '单聊';

  @override
  String get adifLogFile => '会话导出为日志文件';

  @override
  String get adifOptions => '导出选项';

  @override
  String get adifMode => '模式（MODE）';

  @override
  String get adifNotWritten => '不写';

  @override
  String get adifModePkt => 'PKT（数据包，推荐）';

  @override
  String get adifModeFm => 'FM（语音）';

  @override
  String get adifModeData => 'DATA（数据）';

  @override
  String get adifSubModeAprs => '附加 SUBMODE=APRS';

  @override
  String get adifBand => '频段（BAND）';

  @override
  String get adifStripSsid => '只写基础呼号（去掉 -SSID）';

  @override
  String get adifPreview => '预览（将写出的记录）';

  @override
  String get adifModeRequiredHint => '多数日志软件（含 QRZ）要求 MODE，缺少会被拒收';

  @override
  String get adifFreq => '频率（FREQ）';

  @override
  String get adifFreqHint => '单位 MHz，留空则不写';

  @override
  String get adifFreqInvalid => '请输入 MHz 数字，如 144.640';

  @override
  String get sysTitle => '系统状态';

  @override
  String get sysLinkOff => '未启用';

  @override
  String sysRx(String n) {
    return '收 $n';
  }

  @override
  String sysTx(String n) {
    return '发 $n';
  }

  @override
  String sysBeacon(String t) {
    return '信标 $t';
  }

  @override
  String sysStations(String n) {
    return '台站 $n';
  }

  @override
  String get sysFixOk => '已定位';

  @override
  String get sysLinkAudio => '音频';

  @override
  String get sysEmpty => '打开 APRSlocus 并连接后，这里会显示台站运行状态';

  @override
  String get backupTitle => '备份与恢复';

  @override
  String get backupSubtitle => '导出或导入配置与数据';

  @override
  String get backupEntryDesc => '打包配置与数据为 JSON 文件';

  @override
  String get backupDesc => '备份文件是 JSON 文本，换机或重装后可恢复；导入按分组覆盖，无法撤销。';

  @override
  String get backupExport => '导出备份';

  @override
  String get backupExportDesc => '选择要包含的内容，然后保存为文件或复制到剪贴板';

  @override
  String get backupExportToFile => '保存为文件';

  @override
  String get backupCopyJson => '复制到剪贴板';

  @override
  String get backupExportDone => '备份已导出';

  @override
  String get backupExportFailed => '导出失败，请检查存储权限或剩余空间';

  @override
  String get backupCopyDone => '备份内容已复制到剪贴板';

  @override
  String backupSavedTo(String path) {
    return '已保存到：$path';
  }

  @override
  String get backupCatSettings => '设置配置';

  @override
  String get backupCatSettingsDesc => '电台、信标、地图、筛选、数据来源、服务器';

  @override
  String get backupCatStations => '台站与联系人';

  @override
  String get backupCatStationsDesc => '收藏、手动添加的联系人及其备注';

  @override
  String get backupCatMessages => '消息记录';

  @override
  String get backupCatMessagesDesc => '单聊消息与已读位置';

  @override
  String get backupCatChats => '群聊';

  @override
  String get backupCatChatsDesc => '群组、成员与已读状态';

  @override
  String get backupCatTranslate => '翻译设置';

  @override
  String get backupCatTranslateDesc => '翻译接口、密钥与语言偏好';

  @override
  String get backupCatHonors => '成就与荣誉';

  @override
  String get backupCatHonorsDesc => '解锁记录、计数与默认徽章';

  @override
  String backupItems(int n) {
    return '$n 项';
  }

  @override
  String get backupSelectAll => '全选';

  @override
  String get backupNoSelection => '请至少选择一个分组';

  @override
  String get backupImport => '导入备份';

  @override
  String get backupImportDesc => '选择之前导出的 JSON 备份文件';

  @override
  String get backupPickFile => '选择备份文件';

  @override
  String get backupPaste => '从剪贴板粘贴';

  @override
  String get backupPasteEmpty => '剪贴板里没有文本';

  @override
  String get backupPreview => '备份内容';

  @override
  String backupFromVersion(String v) {
    return '来源版本 $v';
  }

  @override
  String backupExportedAt(String t) {
    return '导出时间 $t';
  }

  @override
  String get backupImportSelected => '导入所选';

  @override
  String get backupImportConfirmTitle => '确认导入？';

  @override
  String get backupImportConfirm => '所选分组会被备份里的内容覆盖，且无法撤销。建议先导出一次当前数据。';

  @override
  String backupImported(int n) {
    return '已导入 $n 项';
  }

  @override
  String backupSkipped(int n) {
    return '跳过 $n 项（本版本不认识的内容）';
  }

  @override
  String get backupImportNothing => '备份里不包含所选分组的数据';

  @override
  String get backupRestartTitle => '导入完成';

  @override
  String get backupRestartHint => '数据已写入，重启应用后完全生效（成就、翻译、服务器连接等）。';

  @override
  String get backupRestartNow => '退出应用';

  @override
  String get backupLater => '稍后';

  @override
  String get backupSecurityTip => '备份文件包含呼号、服务器口令与 API 密钥，请妥善保管。';

  @override
  String get backupWebHint => 'Web 版请用「复制到剪贴板 / 从剪贴板粘贴」导入导出。';

  @override
  String get backupErrNotJson => '文件不是有效的 JSON';

  @override
  String get backupErrNotBackup => '这不是 APRSlocus 的备份文件';

  @override
  String get backupErrSchemaNewer => '备份来自更新版本的 APRSlocus，请先升级应用';

  @override
  String get backupErrEmpty => '备份里没有可导入的内容';

  @override
  String get backupErrTooLarge => '备份文件超过 32 MB，无法读取';

  @override
  String get backupErrRead => '读取备份文件失败';

  @override
  String get backupErrUnsupported => '当前平台暂不支持选择文件，请改用剪贴板粘贴';

  @override
  String get themeTitle => '主题';

  @override
  String get themeEntryDesc => '自定义颜色、图标与文字';

  @override
  String get themeSubtitle => '把界面配色、图标与常用文案改成你自己的';

  @override
  String get themePresets => '预设与我的主题';

  @override
  String get themePresetTag => '预设';

  @override
  String get themeActive => '使用中';

  @override
  String get themePresetDefault => '默认';

  @override
  String get themePresetOcean => '海洋';

  @override
  String get themePresetForest => '森林';

  @override
  String get themePresetMidnight => '暗夜';

  @override
  String get themePresetSunset => '日落';

  @override
  String get themePresetContrast => '高对比';

  @override
  String get themeBuiltinHint => '预设主题不可修改，复制为我的主题后即可自由编辑';

  @override
  String get themeColors => '颜色';

  @override
  String get themeColorsDesc => '逐项覆写配色；未修改的项跟随默认';

  @override
  String get themeRadius => '卡片圆角';

  @override
  String get themeRadiusDesc => '作用于卡片与输入框（小徽标等不受影响）';

  @override
  String get themeIcons => '图标';

  @override
  String get themeIconsDesc => '为底部页签与设置入口换图标';

  @override
  String get themeTexts => '文字';

  @override
  String get themeTextsDesc => '覆写常用文案（按钮与错误提示不开放，避免界面变得不可操作）';

  @override
  String get themeNew => '新建主题';

  @override
  String get themeDuplicate => '复制为我的主题';

  @override
  String get themeRename => '重命名';

  @override
  String get themeDelete => '删除主题';

  @override
  String themeDeleteConfirm(String name) {
    return '删除主题「$name」？此操作无法撤销。';
  }

  @override
  String get themeReset => '恢复默认';

  @override
  String get themeResetAll => '重置本主题';

  @override
  String get themeSaved => '主题已保存';

  @override
  String get themeNameHint => '主题名称';

  @override
  String get themePickColor => '选择颜色';

  @override
  String get themePickIcon => '选择图标';

  @override
  String get themePickIconSearch => '搜索图标名（英文）';

  @override
  String get themeEditText => '修改文字';

  @override
  String get themeTextHint => '留空即恢复默认';

  @override
  String get themeIconImport => '从图片导入';

  @override
  String get themeIconImportHint => 'PNG/JPG/WebP/GIF/BMP/SVG，≤2MB';

  @override
  String themeIconImportDone(String name) {
    return '已导入图标：$name';
  }

  @override
  String get themeIconWebHint => 'Web 版不支持导入图片，请使用内置图标库';

  @override
  String get themeIconErrFormat => '不支持的图片格式（支持 PNG/JPG/WebP/GIF/BMP/SVG）';

  @override
  String get themeIconErrTooLarge => '图片超过 2MB，请先压缩';

  @override
  String get themeIconErrFailed => '导入图标失败';

  @override
  String get themeIconErrUnsupported => '当前平台不支持导入图片';

  @override
  String get themeIo => '导入与导出';

  @override
  String get themeIoDesc => '主题是 JSON 文本，可以分享给别人，也可以手工编辑';

  @override
  String get themeExport => '导出此主题';

  @override
  String get themeExportAll => '导出全部主题';

  @override
  String get themeImport => '导入主题';

  @override
  String get themeImportPaste => '从剪贴板导入';

  @override
  String themeImportDone(int n) {
    return '已导入 $n 个主题';
  }

  @override
  String get themeErrNotJson => '文件不是有效的 JSON';

  @override
  String get themeErrNotTheme => '这不是 APRSlocus 主题文件';

  @override
  String get themeErrSchemaNewer => '主题来自更新版本的 APRSlocus，请先升级应用';

  @override
  String get themeErrEmpty => '文件里没有可用的主题';

  @override
  String get themeFixedPrimary => '当前主题已固定主色，请到「主题」页修改';

  @override
  String get themeTokenPrimary => '主色';

  @override
  String get themeTokenSurface => '卡片表面';

  @override
  String get themeTokenBackground => '页面背景';

  @override
  String get themeTokenBackgroundSoft => '次层背景';

  @override
  String get themeTokenTextPrimary => '主文字';

  @override
  String get themeTokenTextSecondary => '次要文字';

  @override
  String get themeTokenTextMuted => '弱化文字';

  @override
  String get themeTokenDivider => '分隔线';

  @override
  String get themeTokenSuccess => '成功/在线';

  @override
  String get themeTokenWarning => '警告';

  @override
  String get themeTokenDanger => '危险/离线';

  @override
  String get themeTokenInfo => '信息/强调';
}

/// The translations for Chinese, as used in Taiwan (`zh_TW`).
class AppLocalizationsZhTw extends AppLocalizationsZh {
  AppLocalizationsZhTw() : super('zh_TW');

  @override
  String get appName => 'APRSlocus';

  @override
  String get ok => '確定';

  @override
  String get cancel => '取消';

  @override
  String get save => '儲存';

  @override
  String get delete => '刪除';

  @override
  String get confirm => '確認';

  @override
  String get back => '返回';

  @override
  String get next => '下一步';

  @override
  String get finish => '完成並連線';

  @override
  String get previous => '上一步';

  @override
  String get search => '搜尋';

  @override
  String get settings => '設定';

  @override
  String get greetMorning => '早上好，';

  @override
  String get greetNoon => '中午好，';

  @override
  String get greetAfternoon => '下午好，';

  @override
  String get greetEvening => '晚上好，';

  @override
  String get greetNight => '夜深了，';

  @override
  String get about => '關於';

  @override
  String get logout => '登出';

  @override
  String get retry => '重試';

  @override
  String get all => '全部';

  @override
  String get online => '線上';

  @override
  String get offline => '離線';

  @override
  String get moving => '移動';

  @override
  String get emergency => '緊急';

  @override
  String get fixed => '固定';

  @override
  String get infrastructure => '中繼';

  @override
  String get weather => '氣象';

  @override
  String get fmo => 'FMO';

  @override
  String get mobile => '車載';

  @override
  String get favorite => '收藏';

  @override
  String get grid => '網格';

  @override
  String get callsign => '呼號';

  @override
  String get speed => '速度';

  @override
  String get altitude => '高度';

  @override
  String get course => '航向';

  @override
  String get distance => '距離';

  @override
  String get bearing => '方位角';

  @override
  String get lastSeen => '最近活躍';

  @override
  String get latitude => '緯度';

  @override
  String get longitude => '經度';

  @override
  String get station => '臺站';

  @override
  String get stations => '臺站';

  @override
  String get messages => '訊息';

  @override
  String get packets => '資料包';

  @override
  String get map => '地圖';

  @override
  String get home => '首頁';

  @override
  String get connection => '連線';

  @override
  String get connected => '已連線';

  @override
  String get disconnected => '未連線';

  @override
  String get connecting => '連線中';

  @override
  String get reconnect => '重新連線';

  @override
  String get server => '伺服器';

  @override
  String get port => '埠';

  @override
  String get passcode => 'Passcode';

  @override
  String get beacon => '位置信標';

  @override
  String get beaconInterval => '上報間隔(秒)';

  @override
  String get nextBeacon => '下次上報';

  @override
  String get beaconsSent => '信標傳送次數';

  @override
  String get symCatVehicles => '車輛 / 交通';

  @override
  String get symCatBuildings => '建築 / 設施';

  @override
  String get symCatNature => '氣象 / 自然';

  @override
  String get symCatAirWater => '飛行 / 水域';

  @override
  String get symCatComms => '通訊 / 其他';

  @override
  String get homeBadgeLabel => '首頁展示徽章';

  @override
  String get homeBadgePickTitle => '選擇首頁展示徽章';

  @override
  String get homeBadgePickDesc => '在以下已獲得的徽章中選一個，作為首頁常駐展示';

  @override
  String get simLocationHint => '使用模擬位置，無需 GPS';

  @override
  String get speedTierRules => '速度分檔規則';

  @override
  String get restoreDefaults => '恢復預設';

  @override
  String get speedTierDesc => '速度越快上報越頻繁；每檔可自訂間隔與圖示（留空=我的符號）。';

  @override
  String get speedTierShortIntervalWarn => '間隔低於 60 秒會顯著增加伺服器負載，建議 ≥60 秒。';

  @override
  String get addSpeedTier => '新增速度檔';

  @override
  String get maxSpeedTiers => '最多 5 個速度檔';

  @override
  String get iconDefaultMySymbol => '圖示 · 預設(我的符號)';

  @override
  String iconNamed(String name) {
    return '圖示 · $name';
  }

  @override
  String everyNSeconds(String sec) {
    return '每 $sec 秒';
  }

  @override
  String get tierIdleTitle => '編輯 · 靜止/低速檔';

  @override
  String get tierSpeedTitle => '編輯 · 速度檔';

  @override
  String get minSpeedKmh => '最低速度 (km/h)';

  @override
  String get intervalSeconds => '上報間隔 (秒)';

  @override
  String get idleTierDesc => '低於第一移動檔的速度都按此檔上報';

  @override
  String get intervalLabel => '間隔';

  @override
  String get unitSeconds => '秒';

  @override
  String get pickBeaconIconDesc => '選擇信標圖示 ·「預設」= 沿用我的符號';

  @override
  String get defaultLabel => '預設';

  @override
  String get deleteThisTier => '刪除此檔';

  @override
  String get idleTierNotDeletable => '靜止檔不可刪除';

  @override
  String get errMinSpeedInt => '最低速度需為 ≥1 的整數';

  @override
  String get errIntervalInt => '上報間隔需為 ≥5 秒的整數';

  @override
  String get errTierDuplicate => '該速度檔已存在，速度值需互不相同';

  @override
  String get wsUrlOptional => 'WebSocket URL(可選)';

  @override
  String get countryUnrestricted => '未選擇國家/地區 · 不做限制（接收全部台站）';

  @override
  String get weatherWidget => '天氣元件';

  @override
  String get groupChatLabel => '群組聊天';

  @override
  String nItems(String n) {
    return '$n 個';
  }

  @override
  String nMessages(String n) {
    return '$n 條';
  }

  @override
  String confirmDeleteMessages(String n) {
    return '確定要刪除全部 $n 條聊天記錄嗎？此操作不可恢復。';
  }

  @override
  String get weatherSimFollowLive => '跟隨即時';

  @override
  String get wxClear => '晴';

  @override
  String get wxCloudy => '多雲';

  @override
  String get wxOvercast => '陰';

  @override
  String get wxLightRain => '小雨';

  @override
  String get wxModerateRain => '中雨';

  @override
  String get wxHeavyRain => '大雨';

  @override
  String get wxStormRain => '暴雨';

  @override
  String get wxThunder => '雷陣雨';

  @override
  String get wxSnow => '雪';

  @override
  String get wxFog => '霧';

  @override
  String get weatherSimTitle => '天氣模擬（預覽背景/特效/建議）';

  @override
  String get weatherSimDesc => '選擇後點頂欄天氣膠囊預覽；「跟隨即時」恢復真實天氣';

  @override
  String get restartWizardConfirm =>
      '將重新進入首次啟動精靈，可重新設定呼號、接收地區等。\\n目前設定不會遺失，完成精靈後繼續使用。';

  @override
  String get restartWizardButton => '重新執行';

  @override
  String get pasteAprsPacketHint =>
      '貼上原始 APRS 封包，如：\\nBV2XYZ>APRS,TCPIP*:!3904.25N/11624.44E>測試台';

  @override
  String beaconsSentCount(String n) {
    return '$n 次';
  }

  @override
  String get myBadgesAndAchievements => '我的徽章與成就';

  @override
  String get quitApp => '結束應用程式';

  @override
  String get quitAppDesc => '結束後 APRSlocus 將停止定位上報與背景接收，並結束行程。';

  @override
  String get symCar => '汽車';

  @override
  String get openInBrowser => '在瀏覽器開啟';

  @override
  String get badgeWall => '徽章牆';

  @override
  String get achievementWall => '成就牆';

  @override
  String get mapTypeCartoPositron => 'Carto Positron(淺色向量)';

  @override
  String get mapTypeCarto => 'Carto 淺色';

  @override
  String get mapTypeCartoDark => 'Carto 深色';

  @override
  String get mapTypeCartoVoyager => 'Carto 航行者';

  @override
  String get mapTypeOsm => 'OSM 標準';

  @override
  String get mapTypeOsmHot => 'OSM 人道';

  @override
  String get mapTypeOpenTopo => 'OpenTopo 地形';

  @override
  String get mapTypeEsriStreet => 'Esri 街道';

  @override
  String get mapTypeEsriSat => 'Esri 影像';

  @override
  String get simulatedKeepAlive => '模擬位置 · 背景保活';

  @override
  String get symCatEmergency => '應急救援';

  @override
  String get symSmallAircraft => '小型飛機';

  @override
  String myPositionSet(String grid) {
    return '已設定我的位置，網格 $grid';
  }

  @override
  String get tierIdleShort => '靜止/低速';

  @override
  String get symHouse => '房屋';

  @override
  String get symPerson => '人';

  @override
  String get symTruck => '卡車';

  @override
  String get symBicycle => '自行車';

  @override
  String get symRv => '房車';

  @override
  String get symWxStation => '氣象站';

  @override
  String get symPolice => '警局';

  @override
  String get symMotorcycle => '摩托';

  @override
  String get symSemi => '半掛車';

  @override
  String get symVan => '麵包車';

  @override
  String get symJeep => '吉普';

  @override
  String get symBus => '公車';

  @override
  String get symTruckStop => '卡車停靠';

  @override
  String get symTrain => '火車';

  @override
  String get symFireTruck => '消防車';

  @override
  String get symPoliceCar => '警車';

  @override
  String get symSnowmobile => '雪地摩托';

  @override
  String get symYagi => '八木屋';

  @override
  String get symHospital => '醫院';

  @override
  String get symAmbulance => '救護車';

  @override
  String get symFireStation => '消防站';

  @override
  String get symSchool => '學校';

  @override
  String get symMotel => '旅館';

  @override
  String get symHotel => '酒店';

  @override
  String get symLaptop => '筆記型電腦';

  @override
  String get symPostOffice => '郵局';

  @override
  String get symWeather => '氣象';

  @override
  String get symWater => '供水站';

  @override
  String get symHurricane => '颶風';

  @override
  String get symHorse => '騎馬';

  @override
  String get symDog => '狗';

  @override
  String get symCamping => '露營';

  @override
  String get symShelter => '避難所';

  @override
  String get symRedCross => '紅十字';

  @override
  String get symFireAlarm => '火警';

  @override
  String get symEmergCenter => '應急中心';

  @override
  String get symCmdCenter => '指揮中心';

  @override
  String get symHandicap => '殘障';

  @override
  String get symBigAircraft => '大型飛機';

  @override
  String get symGlider => '滑翔機';

  @override
  String get symBalloon => '氣球';

  @override
  String get symShip => '船';

  @override
  String get symSailboat => '帆船';

  @override
  String get symMobileSat => '移動衛星';

  @override
  String get symSatAntenna => '衛星天線';

  @override
  String get symDigi => '數位中繼';

  @override
  String get symDigiTower => '中繼塔';

  @override
  String get symMicE => 'Mic-E 中繼';

  @override
  String get symNode => '節點';

  @override
  String get symDxCluster => 'DX 叢集';

  @override
  String get symHfGateway => 'HF 閘道';

  @override
  String get symFileServer => '檔案伺服器';

  @override
  String get symTelephone => '電話';

  @override
  String get symGrid => '網格';

  @override
  String get symXUnix => 'X/Unix';

  @override
  String get symFmoStation => 'FMO 台站';

  @override
  String get filter => '接收範圍篩選';

  @override
  String get filterRadius => '篩選半徑(km)';

  @override
  String get maxStations => '最大臺站數';

  @override
  String get receiveFilter => '接收呼號篩選';

  @override
  String get receiveCountries => '國家/地區';

  @override
  String get receiveOthers => '其他臺站';

  @override
  String get darkMode => '深色模式';

  @override
  String get themeColor => '主題顏色';

  @override
  String get language => '語言';

  @override
  String get languageSystem => '跟隨系統';

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
  String get languageEs => '西班牙語';

  @override
  String get displaySettings => '顯示設定';

  @override
  String get uiScale => '介面縮放';

  @override
  String get reloadUi => '重新載入介面';

  @override
  String get reloadDone => '已重新載入';

  @override
  String get mapType => '地圖類型';

  @override
  String get unit => '單位';

  @override
  String get coordDatum => '座標基準';

  @override
  String get stationSettings => '電臺設定';

  @override
  String get connectionSettings => '連線設定';

  @override
  String get chatSettings => '聊天設定';

  @override
  String get dataSettings => '資料設定';

  @override
  String get advancedSettings => '高階設定';

  @override
  String get sponsors => '贊助與鳴謝';

  @override
  String get sponsorsThanks => '感謝每一位支持者';

  @override
  String get send => '傳送';

  @override
  String get receive => '接收';

  @override
  String get clear => '清除';

  @override
  String get copy => '複製';

  @override
  String get copied => '已複製';

  @override
  String get version => '版本';

  @override
  String get location => '定位';

  @override
  String get gpsStatus => 'GPS 狀態';

  @override
  String get myLocation => '我的位置';

  @override
  String get track => '軌跡';

  @override
  String get forwardingPath => '轉發路徑';

  @override
  String get relatedStations => '相關臺站';

  @override
  String get openInMap => '在地圖檢視';

  @override
  String get navigate => '導航';

  @override
  String get messageSent => '訊息已傳送';

  @override
  String get enterMessage => '輸入訊息';

  @override
  String get noData => '暫無資料';

  @override
  String get searchHint => '搜尋呼號 / 類型 / 網格 / 備註…';

  @override
  String get notFound => '未找到臺站';

  @override
  String get totalStations => '總數';

  @override
  String get sortBy => '排序';

  @override
  String get sortCall => '呼號';

  @override
  String get sortRecent => '最近';

  @override
  String get sortDistance => '距離';

  @override
  String get sortStatus => '狀態';

  @override
  String get typeFilter => '類型篩選';

  @override
  String get aprslocusOnly => 'APRSlocus';

  @override
  String get confirmDelete => '確定要刪除嗎？';

  @override
  String get confirmRestartOobe =>
      '將重新進入首次啟動精靈，可重新設定呼號、接收地區等。\n目前設定不會遺失，完成精靈後繼續使用。';

  @override
  String get restartWizard => '重新執行設定精靈';

  @override
  String get restartWizardTitle => '重新執行設定精靈？';

  @override
  String get oobeFilterTitle => '選擇接收地區';

  @override
  String get oobeFilterDesc => '勾選要接收的國家/地區；不勾選則接收全部臺站，不做限制';

  @override
  String get oobeWelcomeTitle => '歡迎使用 APRSlocus';

  @override
  String get oobeWelcomeRealMap => '即時地圖';

  @override
  String get oobeWelcomeGps => 'GPS 定位上報';

  @override
  String get oobeWelcomeMsg => 'APRS 訊息';

  @override
  String get oobeWelcomeIs => '連線至 APRS-IS';

  @override
  String get oobeCallTitle => '你的呼號';

  @override
  String get oobeSymbolTitle => '選擇臺站符號';

  @override
  String get oobeServerTitle => '連線 APRS-IS 伺服器';

  @override
  String get weatherData => '氣象資料';

  @override
  String get fmoInfo => 'FMO 臺站資訊';

  @override
  String get aprslocusInfo => 'APRSlocus 資訊';

  @override
  String get locationInfo => '位置資訊';

  @override
  String get recentPackets => '最近資料包';

  @override
  String get quickActions => '快速操作';

  @override
  String get copyCoords => '複製座標';

  @override
  String get copyGrid => '複製網格';

  @override
  String get sender => '傳送方';

  @override
  String get time => '時間';

  @override
  String get message => '訊息';

  @override
  String get groupChat => '群組';

  @override
  String get newGroup => '建立新群組';

  @override
  String get sendTo => '傳送至';

  @override
  String get filterRule => '篩選規則';

  @override
  String get saveAndApply => '儲存並套用篩選';

  @override
  String get useMyLocation => '用我的位置作為篩選中心';

  @override
  String get noFixYet => '尚未定位，無法獲取目前位置';

  @override
  String get invalidCoords => '請輸入有效的經緯度和半徑';

  @override
  String get filterSaved => '篩選已儲存並套用';

  @override
  String get stationsShown => '臺站';

  @override
  String get settingsDesc => '設定電臺、定位與連線';

  @override
  String get radioCat => '電臺';

  @override
  String get radioCatDesc => '呼號 · SSID · 符號';

  @override
  String get beaconCat => '定位上報';

  @override
  String get beaconCatDesc => 'GPS · 信標 · 手動定位';

  @override
  String get connectionCat => '連線';

  @override
  String get connectionCatDesc => '伺服器 · 篩選範圍';

  @override
  String get displayCat => '顯示';

  @override
  String get displayCatDesc => '座標 · 主題';

  @override
  String get chatCat => '聊天';

  @override
  String get chatCatDesc => '記錄 · 聯絡人';

  @override
  String get dataCat => '資料';

  @override
  String get dataCatDesc => '清除本機資料';

  @override
  String get advancedCat => '高階';

  @override
  String get advancedCatDesc => '實驗室 · 開發者';

  @override
  String get updateCat => '更新';

  @override
  String get updateCatDesc => '檢查新版本';

  @override
  String get checkUpdate => '檢查更新';

  @override
  String get myStationSettings => '我的電臺';

  @override
  String get myStationSettingsDesc => '呼號 · SSID · 符號 · 信標';

  @override
  String get oobeWelcomeDesc => '開始設定你的 APRS 電臺';

  @override
  String get oobeCallDesc => '輸入你的呼號';

  @override
  String get oobeSymbolDesc => '符號代表臺站類型，會隨位置信標一起傳送';

  @override
  String get oobeServerDesc => '連線後接收全球 APRS 臺站資料，可保持預設設定直接使用';

  @override
  String get wizard => '設定精靈';

  @override
  String get setStep => '步驟';

  @override
  String get chooseSymbol => '選擇臺站符號';

  @override
  String get settingsSubtitle => '地圖座標與顯示偏好';

  @override
  String get stationSettingsSubtitle => '呼號、符號與信標';

  @override
  String get connectionSettingsSubtitle => 'APRS-IS 伺服器與接收範圍';

  @override
  String get chatSettingsSubtitle => '訊息記錄與聯絡人';

  @override
  String get dataSettingsSubtitle => '本機資料管理';

  @override
  String get advancedSettingsSubtitle => '實驗室與開發者工具';

  @override
  String get stationListTitle => '臺站清單';

  @override
  String get filters => '篩選';

  @override
  String get clearAll => '全部清除';

  @override
  String get statusFilter => '狀態';

  @override
  String get typeGroup => '類型';

  @override
  String get appFilter => '軟體';

  @override
  String get mapMenu => '地圖選單';

  @override
  String get mapTypeTitle => '地圖類型';

  @override
  String get selectMapType => '選擇地圖類型';

  @override
  String get showTrails => '顯示軌跡';

  @override
  String get showStations => '顯示臺站';

  @override
  String get aboutTitle => '關於';

  @override
  String get aboutSubtitle => 'APRS 定位追蹤與地圖';

  @override
  String get author => '作者';

  @override
  String get codeContributions => '程式碼貢獻';

  @override
  String get codeContributionI18n => '國際化 / 英文介面';

  @override
  String get codeContributionZhTw => '繁體中文介面';

  @override
  String get codeContributionTranslation => '翻譯';

  @override
  String get dataSourceTxHint =>
      '可以同時勾選多條鏈路一起收報文，但**發射只有一條**（右側圓點為發射來源）——同一個呼號從兩條鏈路發出去會造成重複報文。';

  @override
  String get dataSourceTxBadge => '發射';

  @override
  String get dataSourceIgateHint =>
      '想當閘道（把射頻收到的報文轉到網際網路）就同時勾選 APRS-IS 與 TNC/音訊，然後在下面打開「閘道」。';

  @override
  String get igateTitle => '閘道（iGate）';

  @override
  String get igateSubtitle => '把射頻收到的報文送上 APRS-IS';

  @override
  String get igateEnable => '啟用閘道';

  @override
  String get igateHint =>
      '射頻上收到的報文會被送上 APRS-IS（自動加上 qAr/qAR 與你的呼號標識來路）。需要同時啟用 APRS-IS 和一個射頻來源（TNC / 音訊）。';

  @override
  String get igateNeedRf => '還差一個射頻來源：請在上面的「資料來源」裡勾選 TNC 或音訊，否則閘道沒有可轉遞的射頻鏈路。';

  @override
  String get igateNeedIs => '還沒啟用 APRS-IS：請在上面勾選 APRS-IS，否則閘道沒有可轉遞的目標網路。';

  @override
  String get igateTwoWay => '雙向閘道（向射頻轉遞訊息）';

  @override
  String get igateTwoWayHint =>
      '打開後會**在射頻上真實發射**：只轉「發給最近在射頻上聽到過的台站」的點對點訊息（位置/天氣等廣播不轉，避免佔滿通道）。關閉時只做 RF→IS。';

  @override
  String get igateStatToIs => '已轉遞 → APRS-IS（條）';

  @override
  String get igateStatToRf => '已轉遞 → 射頻（條）';

  @override
  String get igateStatDup => '重複丟棄（條）';

  @override
  String get igateResetStats => '清空統計';

  @override
  String grpSysJoined(String call) {
    return '$call 加入了群聊';
  }

  @override
  String grpSysLeft(String call) {
    return '$call 離開了群聊';
  }

  @override
  String grpSysJoinReq(String call) {
    return '$call 申請加入群聊';
  }

  @override
  String grpSysDeclined(String call) {
    return '$call 拒絕了邀請';
  }

  @override
  String get grpInviteTitle => '群聊邀請';

  @override
  String grpInviteBody(String from, String name) {
    return '$from 邀請你加入「$name」';
  }

  @override
  String get grpNameInvalid => '群名不能為空、不能包含冒號或換行';

  @override
  String grpNameTooLong(int max) {
    return '群名最長 $max 個字元（過長會讓邀請報文超出 APRS 訊息上限）';
  }

  @override
  String grpInviteSent(int n) {
    return '已向 $n 位成員發出邀請';
  }

  @override
  String get grpSelfPending => '等待群主確認';

  @override
  String get deviceOverviewTitle => '裝置';

  @override
  String get deviceOverviewSubtitle => '資料來源、鏈路狀態與自檢';

  @override
  String get deviceCurrentLink => '目前鏈路';

  @override
  String get deviceCurrentLinkDesc => '唯讀摘要 · 改參數請進對應子頁';

  @override
  String get deviceEntries => '裝置與參數';

  @override
  String get deviceEntriesDesc => '每條鏈路一個子頁，各管各的參數';

  @override
  String get tncDeviceTitle => 'TNC 裝置與參數';

  @override
  String get tncDeviceDesc => '藍牙/序列綁定、初始化串、KISS 參數與發射自檢';

  @override
  String get deviceLogTitle => '鏈路日誌';

  @override
  String get deviceLogDesc => '顯示目前來源的日誌（TNC / 音訊自動切換）';

  @override
  String get tncInitTitle => 'TNC 初始化字串';

  @override
  String get tncInitSubtitle => '連線後逐行傳送（等價 APRSdroid 的 kiss.init）';

  @override
  String get tncInitTip =>
      '若 TNC「能收不能發」，先在這裡試：很多藍牙/序列 TNC 模組上電停在命令模式，必須先收到 KISS ON、RESTART 等指令才進入 KISS 轉發狀態。每行一條命令（傳送時自動補 CRLF）。';

  @override
  String get tncInitDelay => '行間隔 (ms)';

  @override
  String get tncInitDelayTip => '每行命令之間的等待時間。模組處理命令需要時間，太短會丟命令';

  @override
  String get tncInitSendAction => '立即傳送初始化字串';

  @override
  String tncInitSent(int n) {
    return '已傳送 $n 行初始化字串';
  }

  @override
  String get tncInitEmpty => '未填寫初始化字串';

  @override
  String get tncPushParams => '連線後下發 KISS 參數';

  @override
  String get tncPushParamsTip =>
      '預設關閉（與 APRSdroid 一致）。打開後連線時會把上面的參數推給 TNC，覆蓋它自己的設定 —— 參數不合適可能讓它一直退避而不發射，所以只在需要統一管理時打開。';

  @override
  String get tncTxTestTitle => '發射自檢';

  @override
  String get tncTxTestSubtitle => '向 TNC 寫一幀測試包，判斷問題在鏈路還是 TNC';

  @override
  String get tncTxTestHint =>
      '發的是一幀狀態包（不含座標），不會把台站在 aprs.fi 上挪位置。若這裡顯示「已寫入」卻仍然不發射，問題在 TNC 側：先試初始化字串（KISS ON / RESTART），再檢查 TxDelay 與通道佔用。';

  @override
  String get tncTxTestAction => '寫入測試幀';

  @override
  String get tncTxTestOkPrefix => '已寫入';

  @override
  String tncTxTestOk(String n) {
    return '已寫入 TNC（累計 $n 幀）。若電台仍不發射，問題在 TNC 側：試初始化字串或檢查 TxDelay。';
  }

  @override
  String tncTxTestFail(String err) {
    return '未寫入：$err';
  }

  @override
  String get tncNeedConnected => '請先連接 TNC';

  @override
  String msgLenCounter(int chars, int bytes) {
    return '$chars/67 字元 · 整包 $bytes/512 位元組';
  }

  @override
  String msgOverSpecAsk(int chars) {
    return '這則訊息 $chars 個字元，超過 APRS 規範的 67 字元上限。多數用戶端仍能讀出，但部分用戶端/閘道會截斷或拒收，對方可能解析不出來。仍要傳送嗎？';
  }

  @override
  String msgOverServerLimit(int bytes, int over) {
    return '整包 $bytes 位元組，超過 APRS-IS 單行上限 512 位元組，伺服器可能直接丟棄整包（連標頭都送不到）。請縮短約 $over 位元組。';
  }

  @override
  String get msgSendAnyway => '仍要傳送';

  @override
  String get msgSpecLimitHint =>
      'APRS 規範建議單則訊息不超過 67 字元：過長文字在部分用戶端上會顯示不全或解析失敗。';

  @override
  String get msgBlockedTooLong => '已阻止傳送：整包超出 APRS-IS 上限';

  @override
  String get beaconRfBeaconOff => '射頻信標未開啟';

  @override
  String get beaconRfEnableHint =>
      '射頻來源的自動發射需要明確開啟「射頻信標」。在此之前不會自動發射位置（倒數也不會走動）。';

  @override
  String get beaconRfEnableAction => '開啟射頻信標';

  @override
  String get beaconRfEnabled => '已開啟射頻信標，將按間隔自動發射';

  @override
  String get beaconRfEnableWarn => '發射將使用你的呼號，請在執照範圍內操作';

  @override
  String get diagTitle => '鏈路自檢';

  @override
  String get diagSubtitle => '逐層確認協定、權限、裝置到底哪一環有問題';

  @override
  String get diagRun => '開始自檢';

  @override
  String get diagRunning => '自檢中…';

  @override
  String diagPassed(int n) {
    return '通過 $n 項';
  }

  @override
  String diagFailed(int n) {
    return '失敗 $n 項';
  }

  @override
  String get diagHint => '協定迴路不接電台也能跑：先確認軟體層沒問題，再去查裝置與接線';

  @override
  String get diagTncSection => 'TNC（KISS / AX.25）';

  @override
  String get diagAudioSection => '音訊（AFSK 1200）';

  @override
  String get diagKissEscape => 'KISS 跳脫';

  @override
  String get diagKissEscapeFail => 'KISS 跳脫還原失敗（軟體層問題，換裝置也沒用）';

  @override
  String get diagAx25 => 'AX.25 幀編解碼';

  @override
  String get diagAx25Fail => 'AX.25 編碼失敗（報文格式不合法）';

  @override
  String diagAx25Mismatch(String got) {
    return 'AX.25 迴路不一致，解回：$got';
  }

  @override
  String get diagFcs => 'FCS 校驗';

  @override
  String get diagFcsFail => 'FCS 校驗異常（改動一個位元組本應被拒收）';

  @override
  String get diagTncLoopback => 'TNC 協定迴路';

  @override
  String diagTncLoopbackOk(int len) {
    return 'KISS/AX.25 編解碼往返一致（$len 位元組）';
  }

  @override
  String get diagAfskLoopback => 'AFSK 調變解調迴路';

  @override
  String diagAfskLoopbackOk(int samples, int rate) {
    return '調變→解調一致（$samples 取樣 @${rate}Hz）';
  }

  @override
  String diagAfskLoopbackFail(int n) {
    return '解出 $n 幀（應為 1 幀）';
  }

  @override
  String get diagAfskLevelFail => '波形幅度過低（調變結果接近靜音）';

  @override
  String get diagPlatform => '平台能力';

  @override
  String diagPlatformOk(String name) {
    return '可用 · 後端 $name';
  }

  @override
  String get diagTncPlatformNo => '目前平台不支援 TNC 鏈路';

  @override
  String get diagAudioPlatformWarn => '不支援即時音訊 · 仍可用 WAV 檔案模式';

  @override
  String get diagNoRealtime => '非即時';

  @override
  String get diagPermission => '錄音權限';

  @override
  String get diagPermissionOk => '已授權';

  @override
  String get diagSkipped => '已跳過（平台不支援）';

  @override
  String get diagCapture => '音訊擷取';

  @override
  String diagCaptureOk(int bytes, int rate) {
    return '收到 $bytes 位元組 @${rate}Hz';
  }

  @override
  String get diagCaptureNoData => '沒有收到任何音訊資料 · 檢查輸入裝置與權限';

  @override
  String diagCaptureFailed(String err) {
    return '開啟擷取失敗：$err';
  }

  @override
  String get diagSpeaker => '揚聲器輸出';

  @override
  String get diagSpeakerOk => '測試音已播放';

  @override
  String diagSpeakerFail(String err) {
    return '播放失敗：$err';
  }

  @override
  String get diagFileIo => 'WAV 檔案讀寫';

  @override
  String diagFileIoOk(int rate) {
    return '寫入→讀出→解調一致 @${rate}Hz';
  }

  @override
  String diagFileWriteFail(String err) {
    return '檔案寫入失敗：$err';
  }

  @override
  String get diagFileReadFail => '檔案讀取失敗';

  @override
  String get diagFileDecodeFail => '檔案裡的音訊解不出報文（可能不是 AFSK 1200 錄音）';

  @override
  String get connAudioSourceHint => '音訊模式下不使用伺服器、過濾器與 KISS 參數';

  @override
  String get testTxTitle => '測試發射';

  @override
  String get testTxDesc => '發一條狀態報文，驗證鏈路真的通到空中';

  @override
  String get testTxAction => '發射測試幀';

  @override
  String get testTxSent => '測試幀已交給鏈路';

  @override
  String testTxFail(String err) {
    return '測試幀發送失敗：$err';
  }

  @override
  String get testTxNeedsConnect => '請先連接鏈路';

  @override
  String get testTxHint => '這是**真實發射**（狀態報文，不含座標）。射頻發射請確認在自己的呼號與執照範圍內';

  @override
  String get audioStatsTitle => '音訊統計';

  @override
  String audioStatRx(int n) {
    return '收 $n 幀';
  }

  @override
  String audioStatTx(int n) {
    return '發 $n 幀';
  }

  @override
  String audioStatDrop(int n) {
    return '發射期間丟棄 $n 位元組';
  }

  @override
  String get audioRestart => '重啟音訊鏈路';

  @override
  String get audioTxDisabled => '「允許發射」已關閉，僅接收';

  @override
  String get audioLoopbackHint => '自檢會真的做一次調變→解調；提示「發射期間丟棄」屬正常半雙工行為';

  @override
  String get notifAudioConnected => '音訊鏈路線上';

  @override
  String get notifAudioDisconnected => '音訊鏈路已中斷';

  @override
  String connConnectingAudio(String name) {
    return '正在開啟音訊（$name）…';
  }

  @override
  String connAudioConnected(String rate) {
    return '音訊鏈路線上 · $rate';
  }

  @override
  String connRetryAudio(int seconds) {
    return '音訊鏈路開啟失敗 · ${seconds}s 後重試…';
  }

  @override
  String connRetryAudioDetail(String detail, int seconds) {
    return '音訊開啟失敗（$detail）· ${seconds}s 後重試…';
  }

  @override
  String connAudioLinkLost(int seconds) {
    return '音訊鏈路中斷 · $seconds秒後自動重連…';
  }

  @override
  String connAudioPositionSent(String call) {
    return '音訊已發射 · 位置已傳送 ($call)';
  }

  @override
  String get dataSourceAudio => '音訊（音效卡）';

  @override
  String get dataSourceAudioDesc => '用麥克風/揚聲器或音效卡線接電台，收發 AFSK 1200';

  @override
  String get audioSettings => '音訊（音效卡 TNC）';

  @override
  String get audioSettingsSubtitle => '用音效卡收發 AFSK 1200 報文';

  @override
  String get audioBackend => '音訊後端';

  @override
  String get audioUnsupported => '目前平台不支援即時音訊（可用 WAV 檔案模式）';

  @override
  String get audioNeedPermission => '需要錄音權限（RECORD_AUDIO），請授權後重試';

  @override
  String get audioCaptureTitle => '音訊擷取';

  @override
  String get audioCaptureDesc => '從麥克風/線路輸入解調 AFSK 1200';

  @override
  String get audioCaptureStart => '開啟擷取';

  @override
  String get audioCaptureStop => '停止擷取';

  @override
  String get audioSampleRate => '取樣率';

  @override
  String get audioSampleRateTip =>
      '22050Hz 是音效卡 TNC 常用值；裝置不支援時改用 44100/48000。修改會重啟擷取';

  @override
  String get audioLevel => '輸入電平';

  @override
  String get audioLevelTip => '有訊號時電平條會抬起；收到 AFSK 時「解調鎖定」會點亮';

  @override
  String get audioSynced => '解調鎖定';

  @override
  String get audioUnlocked => '未鎖定';

  @override
  String audioBadFrames(int n) {
    return '解碼中止 $n 次（雜訊/失步）';
  }

  @override
  String get audioBaud => '位元率';

  @override
  String get audioTones => '音調（標/空）';

  @override
  String get audioTxTitle => '音訊發射';

  @override
  String get audioTxDesc => '發射前先聽通道，避免與其他台站碰撞';

  @override
  String get audioTxEnabled => '允許發射';

  @override
  String get audioTxEnabledTip => '關閉後只接收不發射（只想聽信標時最省心）';

  @override
  String get audioTxDelayTip => '發射前導時長：給對端解調器鎖定時間、給電台 PTT 建立時間';

  @override
  String get audioToneMark => '標號頻率 (Hz)';

  @override
  String get audioToneSpace => '空號頻率 (Hz)';

  @override
  String get audioMarkTip =>
      'Bell 202 規定標號 1200Hz、空號 2200Hz；只有 ±幾 Hz 的容差，不要隨意改';

  @override
  String get audioSpaceTip => '空號音調。與標號音調一起決定 FSK 頻偏（標準為 1000Hz）';

  @override
  String get audioBaudTip => 'APRS 在 VHF 上固定 1200 bd（Bell 202），HF 才用 300';

  @override
  String get audioTxDelayLabel => '發射前導 (ms)';

  @override
  String get audioTnc2Tip => '格式 SRC>DEST,PATH:info，例如 BG7LZQ-9>APALOC:>TEST';

  @override
  String get audioCsmaWait => '發射前等待通道空閒 (ms)';

  @override
  String get audioCsmaWaitTip => '偵測到通道佔用時最多等待多久；0 = 不等待直接發射';

  @override
  String get audioStopTx => '停止發射';

  @override
  String get audioWavTitle => 'WAV 檔案模式';

  @override
  String get audioWavDesc => '離線解碼一段錄音，或把報文匯出成音訊檔案';

  @override
  String get audioWavPath => '檔案路徑';

  @override
  String get audioWavDecodeAction => '解碼此 WAV';

  @override
  String get audioWavExportAction => '匯出此報文';

  @override
  String get audioWavTnC2 => '待匯出報文 (TNC2)';

  @override
  String get audioWavNone => '未解出報文（可能不是 AFSK 1200 錄音）';

  @override
  String audioWavFound(int n) {
    return '解出 $n 條報文';
  }

  @override
  String audioWavWritten(String path) {
    return '已寫入 $path';
  }

  @override
  String audioWavFailed(String err) {
    return '檔案讀寫失敗：$err';
  }

  @override
  String connTncConnected(String arg) {
    return 'TNC 已連線 · $arg';
  }

  @override
  String connTncPositionSent(String arg) {
    return 'TNC 已連線 · 位置已傳送 ($arg)';
  }

  @override
  String connRetryTnc(int n) {
    return 'TNC 連線失敗 · ${n}s 後重試…';
  }

  @override
  String connRetryTncDetail(String e, int n) {
    return 'TNC 連線失敗（$e）· ${n}s 後重試…';
  }

  @override
  String connTncLinkLost(int n) {
    return 'TNC 鏈路中斷 · $n秒後自動重連…';
  }

  @override
  String get tncErrNoDevice => '未綁定 TNC 裝置';

  @override
  String get tncErrUnsupported => '目前平台不支援';

  @override
  String get tncErrNotConnected => '鏈路未連線';

  @override
  String get tncErrOpenRead => '無法開啟裝置（讀）';

  @override
  String get tncErrOpenWrite => '無法開啟裝置（寫）—— Windows 的 COM 埠是獨佔裝置，檢查是否被其他軟體佔用';

  @override
  String get tncErrBadFormat => '報文格式不合法';

  @override
  String get tncErrFrameTooLong => '幀長超出上限';

  @override
  String get tncErrTimeout => '連線逾時';

  @override
  String get translateMyLang => '我的語言';

  @override
  String get translateMyLangHint => '對方傳來的訊息翻成它';

  @override
  String get translatePeerLang => '對方的語言';

  @override
  String get translatePeerUnknownHint => '收到對方訊息後由翻譯介面自動識別';

  @override
  String get translateLearned => '已自動識別';

  @override
  String get translatePeerUnknown => '還不知道對方使用什麼語言 · 先在翻譯設定裡指定，或收幾條對方訊息後會自動識別';

  @override
  String get translateSideIncoming => '對方傳來';

  @override
  String get translateSideOutgoing => '我發出';

  @override
  String get translateToMeTag => '譯給我看';

  @override
  String get translateToPeerTag => '對方將讀到';

  @override
  String get translateContrast => '對照顯示原文與譯文';

  @override
  String get translateContrastTip => '關閉後只顯示譯文（原文仍可透過長按查看）';

  @override
  String get translateProviderFree => '免費介面（無需密鑰）';

  @override
  String get translateProviderFreeDesc => '開箱即用 · 使用公開端點，可能被限流或不穩定';

  @override
  String translateFreeFailed(String e) {
    return '免費介面暫時無法使用（$e）· 可在設定裡改用 Google / 百度 / 自訂介面';
  }

  @override
  String get translateProviderAuto => '自動（推薦）';

  @override
  String get translateProviderAutoDesc => '依次嘗試多個免密鑰介面，取第一個真正翻譯成功的結果';

  @override
  String get translateProviderGooglePublic => 'Google 公開端點（免密鑰）';

  @override
  String get translateProviderGooglePublicDesc => '品質較好，但可能被限流（實測會回傳 429）';

  @override
  String get translateProviderMyMemory => 'MyMemory（免密鑰）';

  @override
  String get translateProviderMyMemoryDesc => '官方免費介面，但本質是翻譯記憶庫：無匹配語料時會回傳原文';

  @override
  String get translateProviderLibre => 'LibreTranslate（可自建）';

  @override
  String get translateProviderLibreDesc => '開源、可自建最可靠；公共實例現已要求密鑰且常不支援中文';

  @override
  String get translateLibreUrl => '實例網址';

  @override
  String get translateLibreKey => '實例 API Key（公共實例需要，自建可留空）';

  @override
  String get translateUsedProvider => '本次實際使用';

  @override
  String get translateUntranslated => '介面沒有真正翻譯（回傳了原文）· 已自動嘗試下一個介面';

  @override
  String translateAutoAllFailed(String e) {
    return '所有免密鑰介面都無法使用（$e）· 建議在設定裡改用 Google / 百度密鑰或自建實例';
  }

  @override
  String get translateLangUnsupported => '該介面不支援翻譯成這一語言 · 可改用「自動」或其它介面';

  @override
  String get translateLangScopeNote =>
      '各介面支援的語種範圍不同（例如百度標準版支援印尼語 id，但並非所有方向都支援）· 遇到不支援時會提示改用自動或其它介面';

  @override
  String get langNameZh => '簡體中文';

  @override
  String get langNameZhTw => '繁體中文';

  @override
  String get langNameEn => '英語';

  @override
  String get langNameJa => '日語';

  @override
  String get langNameKo => '韓語';

  @override
  String get langNameEs => '西班牙語';

  @override
  String get langNameFr => '法語';

  @override
  String get langNameDe => '德語';

  @override
  String get langNameRu => '俄語';

  @override
  String get langNamePt => '葡萄牙語';

  @override
  String get langNameIt => '義大利語';

  @override
  String get langNameId => '印尼語';

  @override
  String get langNameTh => '泰語';

  @override
  String get langNameVi => '越南語';

  @override
  String get langNameAr => '阿拉伯語';

  @override
  String get translateOutgoing => '傳送前翻譯成對方的語言';

  @override
  String get translateOutgoingTip => '開啟後按傳送會先把內容譯成對方的語言再發出；請確認對方能讀懂該語言';

  @override
  String get translateInput => '翻譯輸入內容';

  @override
  String translateOutPreview(String text) {
    return '將傳送：$text';
  }

  @override
  String translateOutPreviewHint(String lang) {
    return '已譯為 $lang · 點傳送即按此發出';
  }

  @override
  String get translateOutCancel => '取消翻譯';

  @override
  String get translateOutNeedPeer => '還不知道對方使用什麼語言 · 先在對話翻譯設定裡指定';

  @override
  String translateSentAs(String text) {
    return '已按對方語言發出：$text';
  }

  @override
  String translateTooLongAfter(int n) {
    return '譯文超出長度上限（$n 字元），未傳送';
  }

  @override
  String get dateToday => '今天';

  @override
  String get dateYesterday => '昨天';

  @override
  String dateDividerFull(int y, int m, int d, String w) {
    return '$y年$m月$d日 $w';
  }

  @override
  String dateWeekday(String d) {
    String _temp0 = intl.Intl.selectLogic(d, {
      '1': '週一',
      '2': '週二',
      '3': '週三',
      '4': '週四',
      '5': '週五',
      '6': '週六',
      '7': '週日',
      'other': '—',
    });
    return '$_temp0';
  }

  @override
  String get translate => '翻譯';

  @override
  String get translateText => '翻譯文字';

  @override
  String get translateSettings => '翻譯設定';

  @override
  String get translateSettingsSubtitle => '翻譯介面、語言與自動翻譯';

  @override
  String get translateProvider => '翻譯介面';

  @override
  String get translateProviderGoogle => 'Google 翻譯';

  @override
  String get translateProviderBaidu => '百度翻譯';

  @override
  String get translateProviderCustom => '自訂';

  @override
  String get translateGoogleKey => 'Google API Key';

  @override
  String get translateGoogleKeyTip =>
      'Google Cloud Translation v2 的 API Key，需自行到 Google Cloud 主控台申請';

  @override
  String get translateBaiduAppId => '百度 App ID';

  @override
  String get translateBaiduKey => '百度密鑰';

  @override
  String get translateBaiduTip => '在百度翻譯開放平台申請「通用文本翻譯」，密鑰只保存在本機';

  @override
  String get translateCustomUrl => '介面網址';

  @override
  String get translateCustomMethod => '請求方式';

  @override
  String get translateCustomHeaders => '請求標頭 (JSON)';

  @override
  String get translateCustomBody => '請求主體範本';

  @override
  String translateCustomBodyTip(String text, String from, String to) {
    return '可用佔位符：$text 原文、$from 來源語言、$to 目標語言。選擇 GET 時忽略此項';
  }

  @override
  String get translateCustomResultPath => '結果欄位路徑';

  @override
  String get translateCustomResultPathTip =>
      '用點號表示層級，陣列用序號，如 data.translations.0.translatedText';

  @override
  String get translateTest => '測試翻譯';

  @override
  String translateTestOk(String text) {
    return '介面可用：$text';
  }

  @override
  String get translateNeedConfig => '請先填寫翻譯介面設定';

  @override
  String translateFailed(String e) {
    return '翻譯失敗：$e';
  }

  @override
  String get translateTargetLang => '翻譯為';

  @override
  String get translateSourceLang => '原文語言';

  @override
  String get translateAuto => '自動翻譯收到的訊息';

  @override
  String get translateAutoTip => '僅對本對話生效；只翻譯對方傳來的訊息';

  @override
  String get translateShowOriginal => '顯示原文';

  @override
  String get translateShowTranslation => '顯示譯文';

  @override
  String get translateRetry => '重新翻譯';

  @override
  String get translateTranslating => '正在翻譯…';

  @override
  String get translateCopyOriginal => '複製原文';

  @override
  String get translateCopyResult => '複製譯文';

  @override
  String get translateLangAuto => '自動偵測';

  @override
  String get translateSameLang => '譯文與原文相同 · 可能無需翻譯，或該介面未能翻譯';

  @override
  String get translateNotNeeded => '該內容無需翻譯（數字 / 符號 / 呼號）';

  @override
  String translateBubbleCount(int n) {
    return '已翻譯 $n 條';
  }

  @override
  String get translatePrivacyNote => '翻譯會把訊息文字傳送到你選擇的第三方介面，請自行評估隱私';

  @override
  String get notifTncConnected => 'TNC 已連線';

  @override
  String get notifTncDisconnected => 'TNC 未連線';

  @override
  String get dataSourceTitle => '資料來源';

  @override
  String get dataSourceSubtitle => '報文從哪裡來';

  @override
  String get dataSourceAprsIs => 'APRS-IS';

  @override
  String get dataSourceAprsIsDesc => '透過網際網路接入全球 APRS 網路';

  @override
  String get dataSourceTnc => 'TNC';

  @override
  String get dataSourceTncDesc => '透過藍牙或串列的 TNC 與電台直接收發';

  @override
  String get dataSourceSwitchHint => '切換資料來源會中斷目前連線';

  @override
  String get dataSourcePkwdwpl => 'PKWDWPL（Kenwood 航點）';

  @override
  String get dataSourcePkwdwplDesc =>
      '用藍牙/串列埠讀取電台輸出的 Kenwood \$PKWDWPL 航點語句（只收不發）';

  @override
  String get dataSourcePkwdwplHint =>
      'PKWDWPL 是**唯讀**鏈路：能收台站、不參與發射（發射請用 APRS-IS / TNC / 音訊）';

  @override
  String connConnectingPkwdwpl(String arg) {
    return '正在連線 PKWDWPL（$arg）…';
  }

  @override
  String connPkwdwplConnected(String arg) {
    return 'PKWDWPL 已連線 · $arg';
  }

  @override
  String get pkwdwplDeviceTitle => 'PKWDWPL 裝置';

  @override
  String get pkwdwplDeviceDesc => '綁定電台連接埠 · 檢視航點接收狀態';

  @override
  String get pkwdwplBindTitle => '裝置綁定與狀態';

  @override
  String get pkwdwplBindSubtitle => '選擇輸出 \$PKWDWPL 語句的那個串列埠 / 藍牙埠';

  @override
  String get pkwdwplRxOnly => '只收不發';

  @override
  String get pkwdwplReadOnly => '唯讀接收中 · 本機不會發射任何報文';

  @override
  String get deviceConflictTitle => '兩條鏈路綁定了同一臺裝置';

  @override
  String get deviceConflictDesc =>
      'TNC 與 PKWDWPL 指向同一臺裝置時，接收到的資料會被兩條鏈路瓜分 —— 表現是「能發不能收」（發送正常、收不到報文）。請給其中一條換一臺裝置。TNC 優先：PKWDWPL 會拒絕連線。';

  @override
  String get deviceInUseByTnc => '已被 TNC 使用，不能重複綁定';

  @override
  String get deviceInUseByPkwdwpl => '已被 PKWDWPL 使用，不能重複綁定';

  @override
  String rxOnlyBanner(String arg) {
    return '$arg 已連線 · 僅接收（目前發射來源未連線）';
  }

  @override
  String get pkwdwplTip =>
      '在電台選單裡把 PC / GPS 埠的輸出格式設為 \"\$PKWDWPL\"（一般 4800 8N1）；這條鏈路唯讀，不會發射任何報文';

  @override
  String get pkwdwplStrictChecksum => '嚴格校驗和（不符即丟棄）';

  @override
  String get pkwdwplStrictChecksumTip =>
      '預設關閉：驗證不符時只標註並記日誌，不丟句子 —— 本機線纜上的不符多半是韌體格式與手冊有出入，整條丟棄會讓介面「什麼都不顯示」，反而更難排查';

  @override
  String get pkwdwplErrReadOnly => '唯讀鏈路，不能發射';

  @override
  String get pkwdwplStatTitle => '航點接收';

  @override
  String pkwdwplStats(String rx) {
    return '已收航點 $rx 條';
  }

  @override
  String get pkwdwplStatRejected => '丟棄/無效語句';

  @override
  String get pkwdwplStatMismatch => '校驗和不符';

  @override
  String get pkwdwplStatIgnored => '其它 NMEA 語句（已忽略）';

  @override
  String get pkwdwplLogEmpty => '暫無 PKWDWPL 日誌';

  @override
  String get tncBindTitle => '藍牙 TNC';

  @override
  String get tncBindSubtitle => '綁定並連接電台端的 TNC';

  @override
  String get tncBoundDevice => '已綁定裝置';

  @override
  String get tncNotBound => '未綁定裝置';

  @override
  String get tncScanPaired => '掃描已配對裝置';

  @override
  String get tncNoPaired => '未找到裝置 · 請先在系統藍牙設定裡配對 TNC';

  @override
  String get tncUnbind => '解除綁定';

  @override
  String get tncConnectAction => '連接 TNC';

  @override
  String get tncRestart => '重啟鏈路';

  @override
  String get tncSupportedNo => '目前平台暫不支援 TNC 鏈路';

  @override
  String get tncNeedPermission => '需要藍牙權限，請授權後重試';

  @override
  String get tncOpenFailedHint => '開啟裝置失敗 · Windows 的 COM 埠是獨佔裝置，請確認沒有被其他軟體佔用';

  @override
  String tncStats(String rx, String tx) {
    return '收 $rx 幀 · 發 $tx 幀';
  }

  @override
  String get tncLog => '鏈路日誌';

  @override
  String get tncLogEmpty => '暫無日誌';

  @override
  String get kissParamsTitle => 'KISS 參數';

  @override
  String get kissParamsSubtitle => '直接下發到 TNC 的鏈路層參數';

  @override
  String get kissTxDelay => '發射延時 (ms)';

  @override
  String get kissTxDelayTip => 'KISS TXDELAY，單位 10ms。發射前留給自己 PTT 建立的時間';

  @override
  String get kissTxTail => '發射尾音 (ms)';

  @override
  String get kissTxTailTip => 'KISS TXTAIL，單位 10ms。某些電台需要尾部保持才能收全';

  @override
  String get kissPersistence => '持續度 P';

  @override
  String get kissPersistenceTip => 'KISS PERSISTENCE，0-255。越小越禮讓，共用信道時能減少碰撞';

  @override
  String get kissSlotTime => '時隙 (ms)';

  @override
  String get kissSlotTimeTip => 'KISS SLOTTIME，單位 10ms。與持續度共同決定信道競爭節奏';

  @override
  String get kissFullDuplex => '全雙工';

  @override
  String get kissFullDuplexTip => 'KISS FULLDUPLEX，一般電台必須關閉（同時收發會互相干擾）';

  @override
  String get kissChannel => '信道 / KISS 埠';

  @override
  String get kissChannelTip => '多信道 TNC 才有多埠，單信道電台保持 0';

  @override
  String get kissMaxFrame => '幀長上限 (位元組)';

  @override
  String get kissMaxFrameTip => '超過此長度的報文不會發出（1200bd 下 AX.25 單幀約 330 位元組）';

  @override
  String get kissHardwareCmd => '廠商命令碼';

  @override
  String get kissHardwareVal => '參數值';

  @override
  String get kissHardwareTip => 'KISS SETHARDWARE (0x06)，廠商自訂；-1 表示不下發';

  @override
  String get kissApplyParams => '下發參數';

  @override
  String get kissParamsSent => 'KISS 參數已下發';

  @override
  String get kissBackToCommand => '回到 TNC 命令模式';

  @override
  String get kissBackToCommandTip =>
      '發送 RETURN (0x0F)。多數 KISS TNC 會就此停止轉發，需重啟鏈路才恢復';

  @override
  String get kissRfPath => '射頻中繼路徑';

  @override
  String get kissRfPathTip => '射頻上使用的中繼，如 WIDE1-1,WIDE2-1；留空則不指定';

  @override
  String get kissRfBeacon => '允許射頻信標';

  @override
  String get kissRfBeaconTip => '打開後才會在射頻上定時發射位置。發射需以自己的呼號並在執照範圍內操作';

  @override
  String get kissAutoAck => '自動回覆 ACK';

  @override
  String get kissAutoAckTip => '關閉後不回覆收到的訊息回執，可減少射頻佔用';

  @override
  String get kissAutoReconnect => '斷開後自動重連';

  @override
  String get kissNeedConnected => '請先連接 TNC';

  @override
  String get tncSwitchOn => '已開啟';

  @override
  String get tncSwitchOff => '已關閉';

  @override
  String get connTncSourceHint => 'TNC 模式下不使用伺服器與過濾器，相關設定已停用';

  @override
  String get connectTncBar => '點「連接」建立 TNC 鏈路';

  @override
  String connectingToTnc(String name) {
    return '正在連接 TNC · $name';
  }

  @override
  String get tncMsgTitle => '射頻（TNC）模式';

  @override
  String get tncMsgDesc => '射頻信道是共享資源，訊息能力相應受限';

  @override
  String get tncGroupDisabled => '射頻模式不支援群聊廣播';

  @override
  String tncMsgLimitHint(String n) {
    return '單條限 $n 字元（APRS 訊息規範）';
  }

  @override
  String get tncMsgTooLong => '超出射頻模式單條訊息長度上限';

  @override
  String get licenseSection => '許可證宣告';

  @override
  String get licenseName => 'GNU GPL v3';

  @override
  String get licenseStatement =>
      '本軟體依據 GNU GPL v3 開源許可證釋出。你可以在遵守許可證條款的前提下執行、研究、修改和再分發本軟體；修改和再分發時須遵守 GPL v3 的相應義務。本軟體不附帶任何擔保。';

  @override
  String get licenseText => '檢視許可證';

  @override
  String get oobeAgreeTitle => '使用者協議與許可';

  @override
  String get oobeAgreeBody =>
      '歡迎使用 APRSlocus！在使用前，請閱讀並同意以下條款。請注意：APRS 資料是公開資訊，一旦傳送即代表其可能被全球 APRS 網路接收、儲存與轉發。';

  @override
  String get oobeAgreeCheck => '我已閱讀並同意《使用者協議》與 GPL-3.0 開源許可證';

  @override
  String get oobeAgreeNeed => '請先閱讀並勾選同意《使用者協議》';

  @override
  String get oobeDeclineExit => '不同意並離開';

  @override
  String get userAgreement => '使用者協議';

  @override
  String get beaconWarnTitle => '信標間隔過短';

  @override
  String get beaconWarnBody =>
      'APRS-IS 建議移動站信標間隔不低於 60 秒。過快的上報可能被視為濫用並導致伺服器斷開連線。是否仍要使用該間隔？';

  @override
  String get beaconWarnKeep => '仍然使用';

  @override
  String get beaconWarnFix => '改回 60 秒';

  @override
  String get features => '功能特性';

  @override
  String get openSource => '開源致謝';

  @override
  String get feedback => '使用者反饋';

  @override
  String get officialWebsite => '官方網站';

  @override
  String get qqGroup => 'QQ 群組';

  @override
  String get projectRepo => '專案倉庫';

  @override
  String get testMembers => '測試成員';

  @override
  String get aiSupport => 'AI 算力支援';

  @override
  String get copyAppInfo => '複製應用程式資訊';

  @override
  String get appInfoCopied => '已複製應用程式資訊';

  @override
  String get shareApp => '分享 APRSlocus';

  @override
  String get shareToSystem => '分享到系統';

  @override
  String get shareToSystemDesc => 'WeChat / QQ / 簡訊等';

  @override
  String get copyShareText => '複製分享文案';

  @override
  String get openDownload => '開啟下載頁';

  @override
  String get shareTextCopied => '分享文案已複製，可貼上傳送給好友';

  @override
  String get shareText =>
      'APRSlocus —— 業餘無線電 APRS 定位追蹤與地圖 📡\n即時臺站追蹤、訊息收發、信標上報，Android / Windows 全平台可用。\n官網：https://aprslocus.theez.top/\n下載：https://github.com/dariondong/APRSLocus/releases';

  @override
  String get enterCallsign => '請輸入你的呼號';

  @override
  String get enterValidCall => '請輸入有效呼號';

  @override
  String get stationSettings2 => '電臺設定';

  @override
  String get beaconSettings => '定位上報';

  @override
  String get displaySettings2 => '顯示設定';

  @override
  String get chatSettings2 => '聊天設定';

  @override
  String get dataSettings2 => '資料設定';

  @override
  String get advancedSettings2 => '高階設定';

  @override
  String get connectionSettings2 => '連線設定';

  @override
  String get myCallsign => '我的呼號';

  @override
  String get beaconEnabled => '啟用位置信標';

  @override
  String get smartBeacon => '智慧信標(依速度分檔)';

  @override
  String get packetConsole => '資料包控制檯';

  @override
  String get rawMode => '原始模式';

  @override
  String get parsedMode => '解析模式';

  @override
  String get position => '位置';

  @override
  String get statusType => '狀態';

  @override
  String get objectType => '物件';

  @override
  String packetStats(Object ppm, Object rx, Object tx) {
    return '收 $rx · 發 $tx · $ppm/分';
  }

  @override
  String get searchPacket => '搜尋呼號、目的地或原始內容…';

  @override
  String get noMatchingPackets => '沒有符合的資料包';

  @override
  String get inject => '注入';

  @override
  String get manualInject => '手動注入 APRS 資料包';

  @override
  String get injected => '已注入資料包';

  @override
  String get clearedPackets => '已清除資料包';

  @override
  String get clearPackets => '清除資料包';

  @override
  String noPositionInfo(Object call) {
    return '$call 暫無位置資訊（資料包未含位置）';
  }

  @override
  String get copiedPacket => '已複製資料包';

  @override
  String get mapPickMode => '地圖選點模式';

  @override
  String get mapPickDesc => '點選地圖選擇我的位置';

  @override
  String foundStations(Object count, Object q) {
    return '找到 $count 臺符合「$q」';
  }

  @override
  String get tapMapHint => '點選地圖檢視臺站 · 雙指縮放';

  @override
  String myLocationPanel(Object call) {
    return '我的位置 · $call';
  }

  @override
  String get speedLabel => '速度';

  @override
  String get courseLabel => '航向';

  @override
  String get telemetryTitle => '速度 / 高度變化';

  @override
  String get range10m => '10 分鐘';

  @override
  String get range30m => '30 分鐘';

  @override
  String get range1h => '1 小時';

  @override
  String get range3h => '3 小時';

  @override
  String get rangeAll => '全部';

  @override
  String get beaconIntervalLabel => '上報間隔';

  @override
  String get beaconsSentLabel => '已上報';

  @override
  String get nextBeaconLabel => '下次上報';

  @override
  String positionBeacon(Object grid) {
    return '位置信標 · 網格 $grid';
  }

  @override
  String get manualBeacon => '手動上報';

  @override
  String get mapPickNow => '地圖選點';

  @override
  String pickedCoord(Object grid, Object lat, Object lng) {
    return '已在地圖選點 · $lat, $lng · 網格 $grid';
  }

  @override
  String onlineCount(Object count) {
    return '$count 線上';
  }

  @override
  String movingCount(Object count) {
    return '$count 移動';
  }

  @override
  String stationCount(Object count) {
    return '$count 臺站';
  }

  @override
  String get locateMe => '定位';

  @override
  String get layerFilter => '圖層篩選';

  @override
  String get showAll => '全部顯示';

  @override
  String get otherType => '其他';

  @override
  String zoomLevel(Object z) {
    return '縮放 $z';
  }

  @override
  String get datumGcj => 'GCJ-02';

  @override
  String get datumWgs => 'WGS-84';

  @override
  String distKm(Object d) {
    return '距離 ${d}km';
  }

  @override
  String get noStationInView => '該區域暫無臺站 · 點選顯示全部';

  @override
  String get noStationHelp => '該區域暫無臺站 · 點選檢視幫助';

  @override
  String get mapHelpTitle => '地圖幫助';

  @override
  String get mapHelpIntro => '目前視野內沒有臺站。可能原因：未連線 APRS-IS、接收範圍較小或附近暫無活躍臺站。';

  @override
  String get mapHelpMove => '拖動 / 縮放：單指拖動地圖，雙指或滾輪縮放';

  @override
  String get mapHelpStation => '檢視臺站：點選標記選中並居中，雙擊開啟詳情';

  @override
  String get mapHelpLayer => '圖層與底圖：右上角按鈕篩選臺站類型、切換地圖樣式';

  @override
  String get mapHelpLocate => '定位：點選右下角「定位到我」回到目前位置';

  @override
  String get mapHelpSearch => '搜尋：頂部搜尋框輸入呼號可快速定位臺站';

  @override
  String get allChangelog => '全部更新日誌';

  @override
  String get tapToView => '點選檢視';

  @override
  String get beaconNow => '手動上報';

  @override
  String get meLabel => '我';

  @override
  String get mapZoomIn => '放大';

  @override
  String get mapZoomOut => '縮小';

  @override
  String get mapHome => '回到中心';

  @override
  String get mapLocate => '定位';

  @override
  String get mapLayers => '圖層';

  @override
  String get featureLiveMap => '線上地圖';

  @override
  String get featureLiveMapDesc => 'GCJ-02 座標，流暢的縮放與拖拽體驗';

  @override
  String get featureGps => 'GPS 定位';

  @override
  String get featureGpsDesc => '原生 Android 定位，無需 Google 服務';

  @override
  String get featureBeacon => '信標傳送';

  @override
  String get featureBeaconDesc => '自定義內容、頻率、符號，支援 APRS 標準格式';

  @override
  String get featureMsg => '訊息收發';

  @override
  String get featureMsgDesc => '瀑布流 + 會話模式，支援中文和自動應答';

  @override
  String get featureAutoConnect => '自動連線';

  @override
  String get featureAutoConnectDesc => '公共伺服器自動連線，背景執行時保持線上';

  @override
  String get featureLayerFilter => '圖層篩選';

  @override
  String get featureLayerFilterDesc => '按類型篩選：移動、固定、中繼、氣象、FMO';

  @override
  String get featureFmo => 'FMO 臺站';

  @override
  String get featureFmoDesc => '自動識別 FMO 資料，顯示結構化資訊';

  @override
  String get osFlutter => 'Flutter';

  @override
  String get osFlutterDesc => 'Google 跨平台 UI 框架';

  @override
  String get osAmap => '高德地圖';

  @override
  String get osAmapDesc => '地圖瓦片服務';

  @override
  String get osAprs => 'APRS-IS';

  @override
  String get osAprsDesc => '全球 APRS 資料網路';

  @override
  String get osHam => '業餘無線電';

  @override
  String get osHamDesc => '所有 APRS 愛好者的貢獻';

  @override
  String get authorName => 'Darion';

  @override
  String get authorCall => '呼號';

  @override
  String get website => '網站';

  @override
  String get sponsorAuthor => '作者 BG7LZQ';

  @override
  String get sponsorAuthorItems => '利用課餘時間開發維護本專案';

  @override
  String get sponsorGroup => 'STUDENT HAMS 群組';

  @override
  String get sponsorGroupItems => '感謝群組的資金贊助支援';

  @override
  String get sponsorBgp => 'BG7PGW';

  @override
  String get sponsorBgpItems => '感謝贊助的蜜雪冰城一杯 🧋';

  @override
  String get sponsorEvery => '每一位支持者';

  @override
  String get sponsorEveryItems => '你們的每一份支援都是動力';

  @override
  String get donateWechat => 'WeChat 讚賞';

  @override
  String get donateWechatDesc => '長按儲存讚賞碼 · 點選放大';

  @override
  String get donateAlipay => 'Alipay 讚賞';

  @override
  String get donateAlipayDesc => '聯絡作者獲取讚賞碼';

  @override
  String get nonprofitNote => '本專案為非盈利學習交流專案\n贊助僅用於伺服器與開發成本';

  @override
  String get myStation => '我的電臺';

  @override
  String get callSsid => '呼號 · SSID';

  @override
  String get ssid => 'SSID';

  @override
  String get ssidDesc => 'SSID 是呼號字尾用於標識裝置，如 BG7ABC-9 中的 -9';

  @override
  String get callComment => '臺站備註';

  @override
  String get callCommentHint => '信標傳送時的備註內容';

  @override
  String get callSymbol => '臺站符號';

  @override
  String get callSymbolDesc => '符號隨位置信標一起傳送';

  @override
  String get autoReply => '自動應答';

  @override
  String get sendBeacon => '傳送信標';

  @override
  String get mapTypeDesc =>
      '「地圖 2.0（向量）」使用客戶端即時向量渲染，資料量小、縮放清晰；柵格圖源為線上圖磚，畫質取決於網路。';

  @override
  String get msgHistory => '訊息記錄';

  @override
  String get statistics => '統計';

  @override
  String get clearData => '清除資料';

  @override
  String get favorites => '收藏/手動';

  @override
  String get favoriteStations => '收藏臺站';

  @override
  String get manualStations => '手動臺站';

  @override
  String get wgs84 => 'WGS-84';

  @override
  String get gcj02 => 'GCJ-02';

  @override
  String get onlyWgs84 => '僅標準 WGS-84';

  @override
  String get contactList => '聯絡人';

  @override
  String get contactDesc => '訊息/聯絡人相關的篩選規則';

  @override
  String get dataClearDesc => '清除訊息、資料包、臺站等本機資料';

  @override
  String get advancedDesc => '實驗室與開發者工具';

  @override
  String get labDesc => '實驗室功能仍在測試中，可能影響使用體驗。預設鎖定直向顯示，開啟後支援橫向顯示。';

  @override
  String get systemLog => '系統日誌';

  @override
  String get devDesc => '開發者除錯工具';

  @override
  String get simData => '啟用模擬資料（示範臺站/資料包）';

  @override
  String get rxTx => '收包 / 發包';

  @override
  String get stationCount2 => '臺站數量';

  @override
  String get appInfo => '應用程式資訊';

  @override
  String get clearMessages => '清空全部聊天記錄';

  @override
  String get clearPackets2 => '清除資料包';

  @override
  String get clearStations => '清除臺站清單';

  @override
  String get clearCache => '清除快取';

  @override
  String get resetAll => '重置全部設定';

  @override
  String get resetAllDesc => '還原出廠設定';

  @override
  String get dataPersistence => '臺站持久化';

  @override
  String get autoSaveStations => '自動儲存臺站資料';

  @override
  String get gridFormat => '網格格式';

  @override
  String get coordsFormat => '座標格式';

  @override
  String get appVersion => '版本';

  @override
  String get appVersionDesc => '目前應用程式版本';

  @override
  String get stationDetail => '臺站詳情';

  @override
  String get backToTop => '回到頂部';

  @override
  String get installApk => '安裝 APRSlocus';

  @override
  String get install => '安裝';

  @override
  String get cancelInstall => '取消';

  @override
  String get openFolder => '開啟目錄';

  @override
  String get browse => '瀏覽';

  @override
  String get downloadUpdate => '下載更新';

  @override
  String get downloadNow => '立即下載';

  @override
  String get downloading => '下載中';

  @override
  String downloadProgress(Object p) {
    return '下載中 $p%';
  }

  @override
  String get downloadComplete => '下載完成';

  @override
  String get downloadFailed => '下載失敗';

  @override
  String get installNow => '立即安裝';

  @override
  String get installComplete => '安裝完成';

  @override
  String get openInstallDir => '開啟安裝目錄';

  @override
  String get deletePackage => '刪除安裝檔';

  @override
  String deletePackageConfirm(Object file) {
    return '確定刪除安裝檔 $file？';
  }

  @override
  String get deleteAllPackages => '刪除全部安裝檔';

  @override
  String deleteAllPackagesWithCount(Object count) {
    return '刪除全部安裝檔（$count 個）';
  }

  @override
  String deleteAllPackagesConfirm(Object count, Object size) {
    return '將刪除本機已下載的 $count 個安裝檔（共 $size），確定？';
  }

  @override
  String get historyVersions => '歷史版本';

  @override
  String get current => '目前';

  @override
  String get newVersion => '新版本';

  @override
  String get latestVersion => '目前已是最新版本';

  @override
  String get currentVersion => 'APRSlocus 目前版本';

  @override
  String get checking => '正在檢查新版本…';

  @override
  String get checkingGitCode => '檢查 GitCode 倉庫';

  @override
  String get updateFailed => '檢查更新失敗';

  @override
  String get noUpdateFound => '目前已是最新版本';

  @override
  String get newVersionFound => '發現新版本';

  @override
  String get downloadAgain => '重新下載安裝檔';

  @override
  String get openDownloads => '開啟下載目錄';

  @override
  String get releaseNotes => '更新日誌';

  @override
  String currentVsRepo(Object local, Object remote) {
    return '本機 v$local · 倉庫最新 v$remote';
  }

  @override
  String installSize(Object os, Object size) {
    return '$os 安裝檔大小：$size';
  }

  @override
  String get alreadyDownloaded => '安裝檔已下載';

  @override
  String get downloadReady => '下載一份安裝檔';

  @override
  String get appInstallDir => '安裝目錄';

  @override
  String get runInstaller => '執行安裝程式';

  @override
  String get downloadUpdateTip => '下載更新並自動開啟';

  @override
  String get openDownloadFolder => '開啟下載目錄';

  @override
  String groupBubble(String name) {
    return '群組 · $name';
  }

  @override
  String get groupInviteTitle => '群組邀請';

  @override
  String groupInviteFrom(String from) {
    return '$from 邀請你加入群組';
  }

  @override
  String groupNameValue(String name) {
    return '群組名稱：$name';
  }

  @override
  String groupCallsignValue(String call) {
    return '群組呼號：$call';
  }

  @override
  String groupInviteAccepted(String name) {
    return '已接受邀請，加入 $name';
  }

  @override
  String get accept => '接受';

  @override
  String groupInviteRejected(String name) {
    return '已拒絕 $name 的邀請';
  }

  @override
  String get reject => '拒絕';

  @override
  String get appTagline => 'APRS 定位追蹤';

  @override
  String gridValue(String grid) {
    return '網格 $grid';
  }

  @override
  String packetsPerMinute(int count) {
    return '$count/分';
  }

  @override
  String get demo => '演示';

  @override
  String nextBeaconIn(String time) {
    return '下次上報 $time';
  }

  @override
  String beaconCount(int count) {
    return '信標 $count 次';
  }

  @override
  String beaconSentAprsIs(String grid) {
    return '位置已上報 · 網格 $grid · 已發往 APRS-IS';
  }

  @override
  String beaconSentDemo(String grid) {
    return '位置已上報 · 網格 $grid · 演示';
  }

  @override
  String get getLocation => '獲取定位';

  @override
  String get disconnect => '斷開連線';

  @override
  String get connectAprsIs => '連線 APRS-IS';

  @override
  String get packetsReceived => '收包';

  @override
  String get passcodeUnverified => 'Passcode 未驗證';

  @override
  String get passcodeWarning => '登入密碼可能錯誤，無法正常收發訊息';

  @override
  String get goSettings => '去設定';

  @override
  String get connectingServer => '正在連線伺服器…';

  @override
  String get notConnectedAprsServer => '未連線 APRS-IS 伺服器';

  @override
  String connectingToServer(String server, int port) {
    return '正在連線 $server:$port…';
  }

  @override
  String get connectNearbyDesc => '連線後可接收附近臺站定位與訊息';

  @override
  String get connectAction => '連線';

  @override
  String get backgroundRunTip =>
      '背景執行提示：為保證背景執行時持續定位上報，請到系統設定中允許 APRSlocus 背景執行、關閉省電最佳化，並允許自啟動。';

  @override
  String get connectedAprsIs => '已連線 APRS-IS';

  @override
  String get qqGroupDesc => 'APRSlocus 軟體 · 反饋問題/交流使用';

  @override
  String get reselectPoint => '重新選點';

  @override
  String get disableClustering => '關閉聚合';

  @override
  String get enableClustering => '開啟聚合';

  @override
  String get heatmap => '臺站熱力圖';

  @override
  String get heatmapHint => '縮小地圖後顯示臺站密度熱力圖';

  @override
  String get groupTracking => '群組追蹤';

  @override
  String get groupTrackingHint => '把關心的呼號編成群組，在大地圖上持續追蹤（車隊 / 好友結伴），支援橫向顯示。';

  @override
  String get newTrackGroup => '建立新追蹤組';

  @override
  String get trackGroupNameHint => '群組名稱，例如：週末騎乘';

  @override
  String get editTrackGroup => '編輯追蹤組';

  @override
  String get deleteTrackGroup => '刪除追蹤組';

  @override
  String deleteTrackGroupConfirm(Object name) {
    return '確定刪除追蹤組「$name」嗎？';
  }

  @override
  String get pickTrackMembers => '選擇成員（勾選要追蹤的呼號）';

  @override
  String get saveAndTrack => '儲存並追蹤';

  @override
  String get trackGroupsEmptyHint => '還沒有追蹤組，點「建立新追蹤組」建立一組要追蹤的呼號。';

  @override
  String trackMemberSub(Object seen, Object type) {
    return '$type · $seen';
  }

  @override
  String get trackGroupEmpty => '群組內成員暫無位置資料（未收到或未上報），點選下方可編輯成員。';

  @override
  String get trackActive => '線上';

  @override
  String get trackWaitingPos => '等待位置…';

  @override
  String get offlineShort => '離線';

  @override
  String get stoppedShort => '靜止';

  @override
  String trackHeader(Object fixed, Object online, Object total) {
    return '$total 人 · $online 線上 · $fixed 已定位';
  }

  @override
  String get groupChatShort => '群組';

  @override
  String groupChatTitle(Object name) {
    return '群組 · $name';
  }

  @override
  String chatWithTitle(Object call) {
    return '與 $call 聊天';
  }

  @override
  String get chatToGroupHint => '傳送訊息給整個群組…';

  @override
  String chatToHint(Object call) {
    return '傳送給 $call…';
  }

  @override
  String get noMessagesHint => '暫無訊息，發一條吧';

  @override
  String trackModeFollow(Object call) {
    return '跟隨 $call';
  }

  @override
  String get trackModeMe => '跟隨我';

  @override
  String get trackModeFitAll => '全覽保持中';

  @override
  String get fitAll => '全覽';

  @override
  String get noStationsYet => '暫無臺站資料，連線 APRS-IS 後即可選擇。';

  @override
  String get noPackets => '暫無資料包';

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
    return '$count小時前';
  }

  @override
  String daysAgo(int count) {
    return '$count天前';
  }

  @override
  String copiedCoordsValue(String coords) {
    return '已複製座標：$coords';
  }

  @override
  String copiedGridValue(String grid) {
    return '已複製網格：$grid';
  }

  @override
  String distanceBearing(String distance, String bearing) {
    return '距我 ${distance}km · 方位 $bearing°';
  }

  @override
  String weatherDataValue(String data) {
    return '氣象資料 · $data';
  }

  @override
  String get symbolLabel => '符號';

  @override
  String get digipeaterTapHint => '點選中繼臺跳轉到對應臺站';

  @override
  String get copiedFmoInfo => '已複製 FMO 資訊';

  @override
  String get copiedAprslocusInfo => '已複製 APRSlocus 資訊';

  @override
  String trackPoints(int count) {
    return '軌跡 ($count 點)';
  }

  @override
  String sendMessageTo(String call) {
    return '發訊息給 $call…';
  }

  @override
  String get navigationUnavailable => '未安裝地圖應用程式，且無法開啟其他地圖應用程式';

  @override
  String stationNoData(String call) {
    return '臺站 $call 尚未收到資料';
  }

  @override
  String get software => '軟體';

  @override
  String get close => '關閉';

  @override
  String get nameLabel => '名稱';

  @override
  String get viewSponsorDetails => '檢視作者與贊助詳情 →';

  @override
  String get thanks => '感謝';

  @override
  String get qqSoftwareName => 'APRSlocus 軟體';

  @override
  String get usageNotice => '本軟體僅供業餘無線電愛好者學習交流使用\n請遵守當地無線電管理法規';

  @override
  String get licenseNotice => 'GNU GPL v3 開源協議 · Copyright © BG7LZQ';

  @override
  String appInfoText(String version) {
    return 'APRSlocus v$version\n作者: BG7LZQ (Darion)\n網站: Theez.top';
  }

  @override
  String get eggBg7lzq => '哎呦你幹嘛~';

  @override
  String get eggBg7pgw => '鬧呢？';

  @override
  String get eggBg7lmw => '默不作聲...';

  @override
  String get eggBg7osl => '你的膽子肥嘟嘟的';

  @override
  String get manualCallsignHint => '手動輸入呼號新增';

  @override
  String get noPacketReceived => '未收到資料包';

  @override
  String get feedMode => '瀑布流';

  @override
  String get conversationMode => '會話';

  @override
  String get messageFeed => '訊息瀑布流';

  @override
  String messageTotal(int count) {
    return '共 $count 條';
  }

  @override
  String get noMessages => '暫無訊息';

  @override
  String get copiedClipboard => '已複製到剪貼簿';

  @override
  String get groupShortLabel => '群組';

  @override
  String get conversations => '會話';

  @override
  String get noConversations => '暫無會話';

  @override
  String get groupNotFound => '找不到群組';

  @override
  String get invite => '邀請';

  @override
  String get manage => '管理';

  @override
  String get noGroupMessages => '群組暫無訊息';

  @override
  String get selectConversation => '選擇會話開始聊天';

  @override
  String get newConversation => '新建會話';

  @override
  String get newConversationDesc => '輸入呼號開始新的會話';

  @override
  String get callsignExample => '呼號，如 BG7ABC';

  @override
  String get start => '開始';

  @override
  String get broadcastMessage => '群組廣播訊息';

  @override
  String get noStations => '暫無臺站';

  @override
  String get broadcastHint => '提示：每條訊息會單獨傳送給每個接收人';

  @override
  String broadcastSent(int count) {
    return '已廣播給 $count 人';
  }

  @override
  String get searchCallsign => '搜尋呼號…';

  @override
  String get broadcastContentHint => '輸入要廣播的內容…';

  @override
  String get groupNameHint => '輸入群組名稱';

  @override
  String get create => '建立';

  @override
  String groupCallsignLine(String call) {
    return '群組呼號：$call';
  }

  @override
  String get noMembers => '暫無成員';

  @override
  String get inviteMembersHint => '點選下方「邀請成員」新增';

  @override
  String get remove => '移除';

  @override
  String get inviteMembers => '邀請成員';

  @override
  String get deleteGroup => '刪除群組';

  @override
  String deleteGroupConfirm(String name) {
    return '確定刪除「$name」？此操作無法復原。';
  }

  @override
  String get deleteConversation => '刪除會話';

  @override
  String deleteConversationConfirm(Object call) {
    return '確定刪除與 $call 的聊天記錄嗎？該會話將從列表中移除，此操作不可恢復。';
  }

  @override
  String clearGroupChatConfirm(Object name) {
    return '確定清空「$name」的聊天記錄嗎？此操作不可恢復。';
  }

  @override
  String memberOnlineCount(int members, int online) {
    return '$members 名成員 · $online 線上';
  }

  @override
  String get leaveGroup => '離開群組';

  @override
  String leaveGroupConfirm(String name) {
    return '確定離開「$name」？你將不再收到該群組的訊息。';
  }

  @override
  String leftGroup(String name) {
    return '已離開 $name';
  }

  @override
  String get leave => '離開';

  @override
  String inviteMembersTo(String name) {
    return '邀請成員到 $name';
  }

  @override
  String get manualCallsign => '手動輸入呼號';

  @override
  String inviteSent(String call) {
    return '已傳送邀請給 $call';
  }

  @override
  String get noMoreOnlineStations => '暫無更多線上臺站';

  @override
  String get invited => '已邀請';

  @override
  String get tapToInvite => '點選邀請';

  @override
  String get done => '完成';

  @override
  String get addContact => '新增聯絡人';

  @override
  String get addContactDesc => '輸入呼號手動新增到聯絡人清單';

  @override
  String contactAdded(String call) {
    return '已新增聯絡人 $call';
  }

  @override
  String get add => '新增';

  @override
  String get stationary => '靜止';

  @override
  String get unknown => '未知';

  @override
  String get none => '無';

  @override
  String get manual => '手動';

  @override
  String get management => '管理';

  @override
  String get debugLabel => '除錯';

  @override
  String get information => '資訊';

  @override
  String get warning => '警告';

  @override
  String get errorLabel => '錯誤';

  @override
  String countTimes(int count) {
    return '$count 次';
  }

  @override
  String countItems(int count) {
    return '$count 個';
  }

  @override
  String countEntries(int count) {
    return '$count 條';
  }

  @override
  String aprsSymbolName(String symbol) {
    String _temp0 = intl.Intl.selectLogic(symbol, {
      'car': '汽車',
      'police': '警局',
      'person': '人',
      'digitalRepeater': '數字中繼',
      'telephone': '電話',
      'dxCluster': 'DX 叢集',
      'hfGateway': 'HF 閘道器',
      'smallAircraft': '小型飛機',
      'mobileSatellite': '移動衛星',
      'disabled': '殘障',
      'snowmobile': '雪地摩托',
      'redCross': '紅十字',
      'scouts': '童子軍',
      'house': '房屋',
      'redX': '紅叉',
      'redDot': '紅點',
      'fire': '火警',
      'campground': '露營',
      'motorcycle': '摩托',
      'train': '火車',
      'fileServer': '檔案伺服器',
      'hurricane': '颶風',
      'dfTriangle': 'DF 三角',
      'postOffice': '郵局',
      'largeAircraft': '大型飛機',
      'weatherStation': '氣象站',
      'satelliteDish': '衛星天線',
      'ambulance': '救護車',
      'bicycle': '腳踏車',
      'commandPost': '指揮中心',
      'fireStation': '消防站',
      'horse': '騎馬',
      'fireTruck': '消防車',
      'glider': '滑翔機',
      'hospital': '醫院',
      'fmoStation': 'FMO 臺站',
      'jeep': '吉普',
      'truck': '卡車',
      'laptop': '筆記本',
      'micERepeater': 'Mic-E 中繼',
      'node': '節點',
      'emergencyOps': '應急中心',
      'dog': '狗',
      'gridSquare': '網格',
      'repeaterTower': '中繼塔',
      'boat': '船',
      'truckStop': '卡車停靠站',
      'semiTrailer': '半掛車',
      'van': '麵包車',
      'waterStation': '供水站',
      'yagi': '八木天線屋',
      'shelter': '避難所',
      'rv': '房車',
      'weatherSymbol': '氣象臺',
      'balloon': '氣球',
      'bus': '公交',
      'shuttle': '太空梭',
      'policeCar': '警車',
      'sailboat': '帆船',
      'school': '學校',
      'lodging': '旅館',
      'hotel': '酒店',
      'other': '未知',
    });
    return '$_temp0';
  }

  @override
  String symbolCategoryName(String category) {
    String _temp0 = intl.Intl.selectLogic(category, {
      'vehicles': '車輛 / 交通',
      'facilities': '建築 / 設施',
      'weatherNature': '氣象 / 自然',
      'emergencyRescue': '應急救援',
      'airWater': '飛行 / 水域',
      'communications': '通訊 / 其他',
      'other': '其他',
    });
    return '$_temp0';
  }

  @override
  String countryName(String code) {
    String _temp0 = intl.Intl.selectLogic(code, {
      'CN': '中國',
      'KR': '韓國',
      'JP': '日本',
      'US': '美國',
      'CA': '加拿大',
      'GB': '英國',
      'DE': '德國',
      'FR': '法國',
      'IT': '義大利',
      'ES': '西班牙',
      'RU': '俄羅斯',
      'AU': '澳大利亞',
      'NZ': '紐西蘭',
      'BR': '巴西',
      'AR': '阿根廷',
      'MX': '墨西哥',
      'ZA': '南非',
      'IN': '印度',
      'TH': '泰國',
      'SG': '新加坡',
      'MY': '馬來西亞',
      'ID': '印度尼西亞',
      'PH': '菲律賓',
      'TW': '臺灣',
      'HK': '香港',
      'MO': '澳門',
      'other': '未知',
    });
    return '$_temp0';
  }

  @override
  String get locationNotFixed => '未定位';

  @override
  String get simulatedLocation => '模擬位置';

  @override
  String get savedLocation => '已儲存位置';

  @override
  String get locationFailed => '定位失敗';

  @override
  String get locationStopped => '定位已停止';

  @override
  String get locationFixed => '已定位';

  @override
  String get locationPermission => '請授予定位許可權…';

  @override
  String get gpsLocating => 'GPS 定位中…';

  @override
  String get webLocationUnsupported => 'Web 平台暫不支援自動定位，請手動輸入座標';

  @override
  String locationStreamError(String error) {
    return '定位流異常：$error';
  }

  @override
  String locationInitError(String error) {
    return '定位初始化失敗：$error';
  }

  @override
  String get beaconDisabled => '已關閉';

  @override
  String get waitingForLocation => '等待定位';

  @override
  String get imminent => '即將';

  @override
  String get connTapToConnect => '未連線 · 點選播放按鈕連線 APRS-IS';

  @override
  String get connManuallyDisconnected => '未連線 · 已手動斷開';

  @override
  String connAutoReconnect(int seconds) {
    return '連線已斷開 · $seconds秒後自動重連…';
  }

  @override
  String connConnectingTarget(String target) {
    return '正在連線 $target…';
  }

  @override
  String connOnline(String call) {
    return '已連線 · $call 線上';
  }

  @override
  String connRetry(int seconds) {
    return '連線失敗 · ${seconds}s 後重試…';
  }

  @override
  String connPositionSent(String call) {
    return '已連線 · 位置已上報 ($call)';
  }

  @override
  String get connDemoBeacon => '未連線 · 位置已上報（模擬）';

  @override
  String get connPasscodeInvalid => '已連線 · 未驗證（Passcode 可能錯誤）';

  @override
  String get mapTypeAmap => '高德地圖';

  @override
  String get mapTypeAmapSatellite => '高德衛星';

  @override
  String get mapTypeVector => '向量地圖';

  @override
  String get amapGroup => '國內地圖';

  @override
  String get domesticMaps => '國內地圖';

  @override
  String get internationalMaps => '國際地圖';

  @override
  String get metricUnits => '公制 (km/h, m)';

  @override
  String get coordDisplay => '座標顯示';

  @override
  String mapDefaultCoord(int level) {
    return '北京 · $level級';
  }

  @override
  String secondsValue(int count) {
    return '$count 秒';
  }

  @override
  String get stationSettingsDetail => '呼號、SSID、符號與備註';

  @override
  String get stationIdentity => '電臺身份';

  @override
  String get aprsCallsignHint => 'APRS 呼號，如 BV2AAA';

  @override
  String get displayInfo => '顯示資訊';

  @override
  String get ssidSuffix => 'SSID 字尾';

  @override
  String get chooseSsidSuffix => '選擇 SSID 字尾';

  @override
  String get mySymbol => '我的符號';

  @override
  String get moreSymbols => '更多符號';

  @override
  String get allAprsSymbols => '全部 APRS 符號';

  @override
  String get beaconSettingsDetail => 'GPS 來源、信標與手動定位';

  @override
  String get locationSource => '定位來源';

  @override
  String get useDeviceLocation => '使用裝置定位';

  @override
  String get manualCoordinates => '手動輸入座標';

  @override
  String get locationMode => '定位模式';

  @override
  String get settingsLocModeSubtitle => '選擇定位方式';

  @override
  String get locModeGps => '純 GPS';

  @override
  String get locModeGpsDesc => '僅衛星定位，更省電';

  @override
  String get locModeGpsNetwork => 'GPS + 網路';

  @override
  String get locModeGpsNetworkDesc => '網路輔助，定位更快';

  @override
  String get beaconingSection => '信標上報';

  @override
  String get beaconIntervalTip => '位置信標的傳送間隔，至少 5 秒';

  @override
  String get beaconContent => '信標上報內容';

  @override
  String get beaconContentDesc => '隨位置信標一起傳送';

  @override
  String get phoneBattery => '手機電量';

  @override
  String get locationStatus => '定位狀態';

  @override
  String get relocate => '重新定位';

  @override
  String get startGps => '開啟 GPS 定位';

  @override
  String get trackingBeaconing => '定位執行中，正在持續上報位置';

  @override
  String get manualLocation => '手動定位';

  @override
  String get latitudeHint => '緯度 39.9042';

  @override
  String get longitudeHint => '經度 116.4074';

  @override
  String get invalidLatLng => '請輸入有效經緯度';

  @override
  String myLocationSetGrid(String grid) {
    return '已設定我的位置，網格 $grid';
  }

  @override
  String get applyCoordinates => '套用座標';

  @override
  String get pickOnMap => '在地圖選點';

  @override
  String get manualLocationHelp => '無法自動定位時，可手動輸入經緯度或用地圖選點，用於信標上報與臺站距離計算。';

  @override
  String get passcodeTip => 'APRS-IS 登入驗證碼，可線上產生；填 -1 表示未驗證';

  @override
  String get websocketOptional => 'WebSocket URL（可選）';

  @override
  String get configChanged => '設定已修改';

  @override
  String get reconnectToApply => '重新連線後生效';

  @override
  String get reconnected => '已重新連線';

  @override
  String get connectFailedCheckConfig => '連線失敗，請檢查設定';

  @override
  String get rangeFilterDesc => '只接收設定範圍內的臺站資料包';

  @override
  String get filterCenterFollows => '篩選中心跟隨我的位置';

  @override
  String get radiusTip => '接收半徑（km），點「儲存並套用」生效';

  @override
  String get maxStationsTip => '記憶體中保留的最大臺站數量（預設不限制，可設更大值）';

  @override
  String filterSavedRadius(String saved, int radius) {
    return '$saved · 半徑 ${radius}km';
  }

  @override
  String get receiveFilterDesc2 => '除範圍篩選外，按國家/地區分組或精確呼號接收臺站';

  @override
  String get receiveCountryDesc => '按呼號字首批次接收某國家/地區全部臺站';

  @override
  String get noCountriesSelected => '未選擇國家/地區';

  @override
  String get receiveOthersDesc => '接收不符合所選國家的特殊呼號臺站';

  @override
  String get addCountry => '新增國家/地區';

  @override
  String get chatSettingsDetail => '訊息、聯絡人與聊天資料';

  @override
  String get messageCountLabel => '訊息條數';

  @override
  String get manageContacts => '管理聯絡人';

  @override
  String deleteAllChatsConfirm(int count) {
    return '確定要刪除全部 $count 條聊天記錄嗎？此操作無法復原。';
  }

  @override
  String get chatCleared => '聊天記錄已清空';

  @override
  String get noContacts => '暫無聯絡人';

  @override
  String get addOrFavoriteContact => '點選右上角「新增」或在地圖上收藏臺站';

  @override
  String movingWithSpeed(String speed) {
    return '移動中 · $speed';
  }

  @override
  String get callsignMin3 => '呼號至少 3 個字元';

  @override
  String get deleteContact => '刪除聯絡人';

  @override
  String deleteContactConfirm(String call) {
    return '確定刪除聯絡人 $call？';
  }

  @override
  String contactDeleted(String call) {
    return '已刪除 $call';
  }

  @override
  String get dataMaintenance => '資料維護';

  @override
  String get clearAllData => '清除所有資料';

  @override
  String get clearAllDataIntro => '此操作將刪除以下所有本機資料：';

  @override
  String get chatHistory => '聊天記錄';

  @override
  String get logs => '日誌';

  @override
  String get irreversibleKeepSettings => '此操作無法復原，連線設定和呼號不會被刪除。';

  @override
  String get confirmClearAllData => '確認清除所有資料';

  @override
  String get clearAllDataConfirm => '確定要清除全部本機資料嗎？此操作無法復原。';

  @override
  String get allDataCleared => '所有資料已清除';

  @override
  String get confirmClear => '確認清除';

  @override
  String get allowLandscape => '允許手機橫屏顯示';

  @override
  String get packetParseTest => '資料包解析測試';

  @override
  String get packetParseHint =>
      '貼上原始 APRS 包，如：\nBV2XYZ>APRS,TCPIP*:!3904.25N/11624.44E>Test station';

  @override
  String get parseAndApply => '解析並套用';

  @override
  String get oobePasscodeMissing => 'Passcode 未填寫';

  @override
  String get oobePasscodeMissingDesc =>
      'Passcode 是 APRS-IS 登入驗證碼，用於識別你的呼號。\n\n使用預設值 -1（未驗證）雖然可以連線，但將無法正常收發訊息與群組。\n\n建議在 https://aprs.cool/AprsPG 輸入呼號查詢正確 Passcode 後填寫。';

  @override
  String get continueAnyway => '仍然繼續';

  @override
  String get fillPasscode => '去填寫';

  @override
  String get oobeMapFeatureDesc => '線上地圖圖磚，檢視附近 APRS 臺站與軌跡';

  @override
  String get oobeGpsFeatureDesc => '自動取得位置並傳送信標到 APRS-IS';

  @override
  String get oobeMsgFeatureDesc => '與臺站收發訊息，支援自動應答';

  @override
  String get oobeIsFeatureDesc => '連線公共伺服器，接收全球 APRS 臺站資料';

  @override
  String get oobeBackgroundTip =>
      '提示：為保證背景執行時持續定位上報，請到系統設定中允許 APRSlocus 背景執行、關閉省電最佳化，並允許自啟動。';

  @override
  String get oobeNextSteps => '接下來幾步完成基礎設定，隨時可在設定中修改。';

  @override
  String get ssidDescShort => 'SSID 是呼號後面的數字標識，如 BG7ABC-9 中的 -9';

  @override
  String get ssidOptional => 'SSID 字尾（可選）';

  @override
  String get noSsid => '無字尾（基本呼號）';

  @override
  String fullCallsign(String call) {
    return '完整呼號：$call';
  }

  @override
  String get passcodeImportant => 'Passcode 非常重要';

  @override
  String get passcodeImportantDesc =>
      '正確的 Passcode 是接收群組訊息和傳送確認訊息的前提。填 -1 雖然可以連線，但無法正常收發訊息。';

  @override
  String get lookupPasscode => '點選查詢你的 Passcode →';

  @override
  String get passcodeLookupHint => '輸入你的呼號即可取得，例如 BV2AAA';

  @override
  String sendToGroupHint(String group) {
    return '傳送至 $group…';
  }

  @override
  String sendToCallHint(String call) {
    return '傳送給 $call…';
  }

  @override
  String get selectMessageReply => '點選訊息以回覆…';

  @override
  String get broadcastShort => '廣播';

  @override
  String memberCount(int count) {
    return '$count 個成員';
  }

  @override
  String memberCountTap(int count) {
    return '$count 名成員 · 點選檢視';
  }

  @override
  String get stepRecipients => '選人';

  @override
  String get stepContent => '內容';

  @override
  String get selectAllOnline => '全選線上';

  @override
  String get clearSelection => '取消全選';

  @override
  String get onlineOnly => '僅線上';

  @override
  String get noRecipients => '未選擇接收人';

  @override
  String selectedRecipients(int count) {
    return '已選 $count 人';
  }

  @override
  String sendRecipientsList(int count, String calls) {
    return '將傳送給 $count 人：$calls';
  }

  @override
  String get stepName => '名稱';

  @override
  String get stepMembers => '成員';

  @override
  String get groupChatExplain =>
      '群組使用群組呼號廣播訊息，所有成員都能收到。建立後系統會自動產生群組呼號，並向你選擇的成員傳送邀請。';

  @override
  String get noMembersSelected => '未選擇成員';

  @override
  String get memberBlocked => '已遮蔽';

  @override
  String get memberJoined => '已加入';

  @override
  String get memberPending => '待確認';

  @override
  String get memberDeclined => '已拒絕';

  @override
  String get memberLeft => '已離開';

  @override
  String get memberTimeout => '超時';

  @override
  String get unblock => '解除遮蔽';

  @override
  String get block => '遮蔽';

  @override
  String get groupOwner => '群組管理員';

  @override
  String systemMemberJoined(String call) {
    return '$call 加入了群組';
  }

  @override
  String systemMemberLeft(String call) {
    return '$call 離開了群組';
  }

  @override
  String systemInviteDeclined(String call) {
    return '$call 拒絕了邀請';
  }

  @override
  String get copyAllLogs => '複製全部日誌';

  @override
  String copiedLogs(int count) {
    return '已複製 $count 條日誌';
  }

  @override
  String get clearLogs => '清空日誌';

  @override
  String get noLogs => '暫無日誌';

  @override
  String get supportProject => '你們的支援讓專案走得更遠';

  @override
  String get continuousIteration => '持續迭代';

  @override
  String get continuousIterationDesc => '不斷改進 APRSlocus 功能與體驗';

  @override
  String get sponsorSupport => '贊助支援';

  @override
  String get sponsorMethods => '贊助方式';

  @override
  String qrCodeTitle(String title) {
    return '$title 讚賞碼';
  }

  @override
  String get qrLoadFailed => '讚賞碼圖片載入失敗';

  @override
  String get qrSaveWechat => '長按圖片可儲存 · 使用 WeChat 掃一掃讚賞';

  @override
  String get tapAnywhereClose => '點選任意處關閉';

  @override
  String vectorMapLoadFailed(String error) {
    return '向量地圖載入失敗\n$error';
  }

  @override
  String get loadingVectorMap => '載入向量地圖…';

  @override
  String get updateChannel => '更新管道';

  @override
  String serverReturned(int code) {
    return '伺服器回傳 $code';
  }

  @override
  String get invalidResponseData => '回傳資料格式錯誤';

  @override
  String get noVersionsFound => '找不到任何版本';

  @override
  String get noWindowsInstaller => '該版本沒有 Windows 安裝檔';

  @override
  String get noApkInstaller => '該版本沒有 APK 安裝檔';

  @override
  String get connectingEllipsis => '正在連線…';

  @override
  String downloadHttpError(int code) {
    return '下載失敗：HTTP $code';
  }

  @override
  String downloadedBytes(String received, String total) {
    return '已下載 $received / $total';
  }

  @override
  String androidInstallHelp(String path) {
    return '安裝檔已下載到：\n$path\n\n點選「安裝」後，系統會彈出安裝確認框。\n\n若提示「不允許安裝未知來源應用程式」，請到系統設定中允許本應用程式安裝未知來源應用程式。';
  }

  @override
  String windowsInstallHelp(String path) {
    return '安裝包已儲存到：\n$path\n\n點選「立即執行」直接啟動安裝程式；也可以開啟所在目錄檢視檔案。';
  }

  @override
  String get openContainingFolder => '開啟所在目錄';

  @override
  String get runNow => '立即執行';

  @override
  String get cannotRunInstaller => '無法啟動安裝程式，請到所在目錄手動開啟';

  @override
  String get cannotLaunchInstaller => '無法啟動安裝程式，請手動開啟安裝檔';

  @override
  String get openPackageManually => '請在檔案管理程式中開啟安裝檔';

  @override
  String cannotOpenPackage(String error) {
    return '無法開啟安裝檔：$error';
  }

  @override
  String get installPermissionTitle => '需要允許安裝應用程式';

  @override
  String get installPermissionDesc =>
      '偵測到系統未允許 APRSlocus 安裝應用程式。\n\n請點選「去設定」，在「安裝未知應用程式」中允許本應用程式安裝未知來源應用程式，然後返回重新安裝。';

  @override
  String get recheck => '重新檢查';

  @override
  String newVersionTitle(String version) {
    return '發現新版本 v$version';
  }

  @override
  String repoLatestTitle(String version) {
    return '倉庫最新版本 v$version';
  }

  @override
  String get checkingLatest => '正在檢查最新版本…';

  @override
  String get connectingGitCode => '連線 GitCode 伺服器';

  @override
  String get noReleaseNotes => '暫無更新說明';

  @override
  String noInstallerHistoryHint(String platform) {
    return '該版本暫無 $platform 安裝檔，請到歷史版本中選擇可下載的版本';
  }

  @override
  String get latestVersionLabel => '最新版本';

  @override
  String packageSize(String platform, String size) {
    return '$platform 安裝檔大小：$size';
  }

  @override
  String get updateContents => '更新內容';

  @override
  String get redownload => '重新下載';

  @override
  String get downloadInstaller => '下載安裝檔';

  @override
  String get downloadAndInstall => '下載並安裝';

  @override
  String get localPackageExists => '本機已有一份安裝檔';

  @override
  String get packageDeleted => '安裝檔已刪除';

  @override
  String versionCount(int count) {
    return '$count 個';
  }

  @override
  String get noInstaller => '無安裝檔';

  @override
  String get download => '下載';

  @override
  String get viewChangelog => '檢視更新日誌';

  @override
  String versionChangelog(String version) {
    return 'v$version 更新日誌';
  }

  @override
  String get gotIt => '知道了';

  @override
  String get leaveAction => '離開';

  @override
  String localRepoVersion(Object latest, Object local) {
    return '本機 v$local · 倉庫最新 v$latest';
  }

  @override
  String get unverified => '未驗證';

  @override
  String get passcodeUnverifiedHint => '-1 未驗證';

  @override
  String get passcodeMessageWarning => 'APRS-IS 登入驗證碼，填 -1 無法正常收發訊息';

  @override
  String get settingsStationIdentitySubtitle => '呼號、SSID 與備註';

  @override
  String get settingsDisplayInfoSubtitle => '我的符號與目前定位';

  @override
  String get settingsLocSourceSubtitle => '選擇座標來源';

  @override
  String get settingsBeaconSubtitle => '傳送間隔與上報內容';

  @override
  String get settingsManualLocSubtitle => '無定位時可手動輸入或選點';

  @override
  String get settingsManualLocHint => '無法自動定位時，可手動輸入經緯度或用地圖選點，用於信標上報與臺站距離計算。';

  @override
  String get settingsConnStatusSubtitle => '連線狀態與資訊';

  @override
  String get settingsServerSubtitle => 'APRS-IS 伺服器與驗證碼';

  @override
  String get settingsFilterSubtitle => '過濾中心與接收半徑';

  @override
  String get settingsReceivePrefSubtitle => '按國家/地區或呼號接收';

  @override
  String get settingsGeneralSubtitle => '主題、語言與座標顯示';

  @override
  String get settingsMapSubtitle => '地圖類型與顯示';

  @override
  String get settingsChatStatsSubtitle => '訊息與聯絡人統計';

  @override
  String get settingsChatManageSubtitle => '聯絡人與聊天資料';

  @override
  String get settingsClearDataSubtitle => '刪除本機記錄';

  @override
  String get settingsLabSubtitle => '實驗性功能';

  @override
  String get settingsDevSubtitle => '除錯與測試';

  @override
  String get settingsFilterHint => '只接收設定範圍內的臺站資料包';

  @override
  String get settingsReceivePrefHint => '除範圍篩選外，按國家/地區分組或精確呼號接收臺站';

  @override
  String get settingsContribCodeOptimization => '程式碼最佳化';

  @override
  String get eggBg2hcb => '人生真是喵喵又咪咪啊';

  @override
  String get deviceInfoTitle => '裝置識別';

  @override
  String get deviceToCall => '目的呼號';

  @override
  String get deviceModel => '裝置型號';

  @override
  String get deviceClass => '裝置類別';

  @override
  String get deviceFilter => '裝置篩選';

  @override
  String get lookupQrz => 'QRZ 呼號';

  @override
  String get lookupAprsFi => 'aprs.fi 位置';

  @override
  String get aprsTv => 'APRS.tv';

  @override
  String get aprsTvInfo => '詳細頁';

  @override
  String get aprsTvMap => '在地圖上查看';

  @override
  String get linkOpenFailed => '無法開啟連結';

  @override
  String get beaconAutoAskTitle => '連線成功，自動上報位置？';

  @override
  String get beaconAutoAskDesc =>
      '是否讓 APRSlocus 在連線後自動定時上報你的位置（信標）？行動臺建議開啟；若只想接收訊息與檢視周邊臺站，可關閉（隨時可手動上報一次）。';

  @override
  String get beaconAutoYes => '自動上報';

  @override
  String get beaconAutoNo => '暫不，僅接收';

  @override
  String get beaconOffChip => '自動上報已關閉';

  @override
  String get quickTrackCreate => '新建跟蹤組';

  @override
  String get quickTrackHint => '從已接收臺站勾選成員，也可手輸呼號補充；直接在地圖上跟蹤這些人，不需要先建聊天群。';

  @override
  String get quickTrackName => '組名（可選）';

  @override
  String get quickTrackPickLabel => '選擇要跟蹤的臺站';

  @override
  String get quickTrackNoStations => '暫無已接收臺站，可直接手輸呼號（多個用逗號分隔）';

  @override
  String get quickTrackManualHint => '手輸呼號，如 BG7PGW,BG7LMW';

  @override
  String get quickTrackStart => '開始跟蹤';

  @override
  String get quickTrackNeedMembers => '請至少選擇或輸入一個呼號';

  @override
  String get weatherPanelTitle => '天氣 · 火腿建議';

  @override
  String get weatherPanelSub => '和風天氣 · 當前位置';

  @override
  String get weatherRefresh => '重新整理';

  @override
  String get weatherPowered => '資料由和風天氣提供 · APRSlocus';

  @override
  String get hfTitle => '短波傳播';

  @override
  String get hfSixMeter => '6m 波段';

  @override
  String get hfEs => 'Es 偶發 E 層';

  @override
  String get hfAurora => '極光';

  @override
  String get hfF2 => 'F2 層';

  @override
  String get hfBand => '波段';

  @override
  String get hfDay => '日間';

  @override
  String get hfNight => '夜間';

  @override
  String get hfSfi => '太陽通量';

  @override
  String get hfKp => '地磁 Kp';

  @override
  String get hfAIndex => 'A 指數';

  @override
  String get hfSunspots => '太陽黑子';

  @override
  String get hfXray => 'X 射線';

  @override
  String get hfSolarWind => '太陽風速';

  @override
  String get hfGeomag => '地磁';

  @override
  String get hfNoise => '底噪';

  @override
  String get hfMuf => '最高可用頻率';

  @override
  String get hfNoData => '暫無短波傳播資料：連網後自動取得';

  @override
  String get hfUnavailable => '短波傳播服務暫時無法使用';

  @override
  String get hfQGood => '好';

  @override
  String get hfQFair => '一般';

  @override
  String get hfQPoor => '差';

  @override
  String get hfQClosed => '未開通';

  @override
  String get hfPowered => '傳播資料由 hamqsl.com（N0NBH）提供 · 全球平均，非本地實測';

  @override
  String get hfTipStorm =>
      '地磁暴（Kp≥5）：極區短波路徑衰減明顯，跨極地 DX 幾乎中斷；改走低緯度路徑或轉本地 VHF/UHF';

  @override
  String get hfTipGeomagActive => '地磁較活躍：短波高緯度路徑不如平時穩定，DX 通聯建議留出更多呼叫時間';

  @override
  String get hfTipLowSfi =>
      '太陽活動偏低（SFI<100）：白天高頻段（15m/12m/10m）機會少，優先 40m/30m/20m';

  @override
  String get hfTipHighSfi => '太陽活動活躍（SFI≥150）：白天高頻段（15m/12m/10m）有機會遠距離 DX';

  @override
  String get hfTipHighNoise => '底噪偏高：弱信號接收困難，建議收窄頻寬、降低前置增益，必要時用窄帶模式';

  @override
  String hfTipBandGood(String b) {
    return '$b 傳播條件好：本時段優先使用這一段呼叫';
  }

  @override
  String hfTipBandPoor(String b) {
    return '$b 條件偏差：換到其他波段，或等日落/日出灰線再試';
  }

  @override
  String get weatherCurLoc => '當前位置';

  @override
  String get weatherNoLoc => '暫無定位：請在「我的電台」開啟位置服務後查看天氣';

  @override
  String get weatherUnavail => '天氣服務暫時不可用';

  @override
  String get weatherDataFail => '天氣資料獲取失敗';

  @override
  String get weatherConnFail => '天氣服務連線失敗';

  @override
  String get weatherCloud => '雲量';

  @override
  String get weatherDew => '露點';

  @override
  String get weatherHumidity => '濕度';

  @override
  String get weatherWindDir => '風向';

  @override
  String get weatherWindScale => '風力';

  @override
  String get weatherWindSpeed => '風速';

  @override
  String get weatherPressure => '氣壓';

  @override
  String get weatherVis => '能見度';

  @override
  String get weatherPrecip => '降水';

  @override
  String weatherFeels(String v) {
    return '體感 $v°';
  }

  @override
  String weatherObserved(String t) {
    return '觀測 $t';
  }

  @override
  String get hamTitle => '業餘無線電建議';

  @override
  String get hamNoData => '獲取天氣後，將給出適合架台/通聯/防雷的安全建議';

  @override
  String get hamStorm1 => '雷雨天氣：請勿在室外架設/操作天線！斷開天線饋線，謹防雷擊感應損壞設備';

  @override
  String get hamStorm2 => '如已架設，盡快收納拉倒；轉為室內收聽中繼與短波，注意設備防潮';

  @override
  String get hamRain => '有降水：戶外架台請備防雨罩/防水箱，接頭用膠帶或熱縮管密封，饋線避免積水';

  @override
  String get hamCold => '低溫/降雪：鋰電池容量明顯下降，多備電池並貼身保暖；天線結冰注意駐波變化';

  @override
  String hamWind(String w) {
    return '風力 $w 級：架設天線務必拉好風繩加固，八木/長線收工時放倒，避免傾倒';
  }

  @override
  String hamHot(String t) {
    return '高溫 $t°C：注意防暑補水，設備避免長時間滿功率發射導致過熱';
  }

  @override
  String hamHumid(String h) {
    return '濕度 $h%：潮濕會降低絕緣與天線效率，VHF/UHF 訊號衰減偏大，注意接頭防鏽';
  }

  @override
  String hamFog(String v) {
    return '能見度低（${v}km）：出行架台注意安全；霧天易形成大氣波導，可嘗試遠地 V/U 通聯';
  }

  @override
  String get hamGood => '天氣良好，適合架台！UV 段可嘗試本地中繼與直頻；短波留意晚間電離層變化';

  @override
  String hamWindExtra(String w) {
    return '雖有 $w 級風，仍建議為天線加固風繩，野外架台注意安全';
  }

  @override
  String get hamStorm3 =>
      '雷電臨近：把天線饋線從設備上拔下並移至室外接地端洩放，關閉電源並拔掉插頭，避免突波經市電、網路線竄入；不要使用室外天線與有線電話';

  @override
  String get hamStorm4 => '雷暴前後靜電雜訊（QRN）驟增、短波底噪抬升；雷電活動結束後約 30 分鐘再恢復架台與發射';

  @override
  String get hamExtreme => '暴雨/極端降水：注意山洪、積水與落石，勿在河岸、低窪處架台；饋線入牆處做滴水彎，防止雨水順線灌入室內';

  @override
  String hamGale(String w) {
    return '風力 $w 級：禁止上塔、爬桿作業！八木與長線天線務必放倒或降下，檢查風繩、地錨與桅杆拉線';
  }

  @override
  String get hamIce => '天線與饋線結冰會升高駐波（SWR）並增加冰載：切勿滿功率硬發，先檢查拉線受力，待化冰後再正常通聯';

  @override
  String get hamFrost => '氣溫低於 0℃：鋰電池容量驟降，備用電池請貼身保溫；注意手部與面部凍傷，帶上暖手寶';

  @override
  String get hamHeat2 => '高溫易使功放與電源過熱降額：適度降低功率、縮短連續發射時間，並確保通風散熱';

  @override
  String get hamDust => '沙塵天氣：細沙滲入接頭與絕緣子會造成洩漏和雜訊，請加防塵罩；乾燥摩擦易累積靜電，注意接地洩放';

  @override
  String get hamAir => '空氣品質差：戶外架台請戴口罩並減少劇烈活動；污染物附著天線絕緣子會引入洩漏雜訊，收工後清潔';

  @override
  String hamDew(String d) {
    return '露點差僅 $d℃，空氣接近飽和：設備與饋線易結露，收工後先緩溫除濕再通電，避免短路';
  }

  @override
  String hamUV(String u) {
    return '紫外線指數 $u，強度偏高：野外架台注意防曬；長期曝曬會加速同軸電纜外皮與束帶老化';
  }

  @override
  String hamLowPressure(String p) {
    return '氣壓偏低（$p hPa）：天氣趨於不穩，長時間野外架台請留好退路並留意臨近警報';
  }

  @override
  String hamHighPressure(String p) {
    return '氣壓較高（$p hPa）且穩定：易形成逆溫層，VHF/UHF 可能出現大氣波導，可嘗試超視距遠地直頻或中繼通聯';
  }

  @override
  String get hamGrayLine => '正值日出/日落灰線時段：20/40m 短波傳播最佳，是跨洲遠程（DX）通聯的黃金窗口';

  @override
  String get hamNight => '夜間 D 層消失：80/40m 吸收減小、雜訊較低，適合本土與夜間遠程通信';

  @override
  String get hamRainFade => '較強降水對 1.2GHz 以上頻段有雨衰影響：微波與 EME 通聯建議改用較低頻段或等雨勢減弱';

  @override
  String get hamShower => '陣雨來去突然：架台請備好防雨罩並留意雲團移動，收工前先斷開發射再拆饋線';

  @override
  String get hamLevelDanger => '安全警示';

  @override
  String get hamLevelWarn => '注意';

  @override
  String get hamLevelGood => '通聯機會';

  @override
  String get hamLevelTip => '操作提示';

  @override
  String hamMore(String n) {
    return '展開全部 $n 條建議';
  }

  @override
  String get hamLess => '收合';

  @override
  String get weatherForecast3 => '三日預報';

  @override
  String get weatherDaily15 => '查看近 15 日天氣';

  @override
  String get weatherDaily15Title => '近 15 日天氣趨勢';

  @override
  String get weatherToday => '今天';

  @override
  String get weatherTomorrow => '明天';

  @override
  String get weatherDayAfter => '後天';

  @override
  String weatherWeekday(String d) {
    String _temp0 = intl.Intl.selectLogic(d, {
      '1': '週一',
      '2': '週二',
      '3': '週三',
      '4': '週四',
      '5': '週五',
      '6': '週六',
      '7': '週日',
      'other': '—',
    });
    return '$_temp0';
  }

  @override
  String get weatherSunrise => '日出';

  @override
  String get weatherSunset => '日落';

  @override
  String get weatherUV => '紫外線';

  @override
  String get weatherDetails => '詳細資料';

  @override
  String get weatherAQIPrimary => '首要污染物';

  @override
  String get airExcellent => '優';

  @override
  String get airGood => '良';

  @override
  String get airModerate => '輕度污染';

  @override
  String get airUnhealthy => '中度污染';

  @override
  String get airVeryUnhealthy => '重度污染';

  @override
  String get airHazardous => '嚴重污染';

  @override
  String get weatherAir => '空氣品質';

  @override
  String get issStation => 'ISS 太空站';

  @override
  String get applyStationFilter => '台站篩選套用到地圖';

  @override
  String get stationFilterOn => '已依台站面板篩選顯示';

  @override
  String get stationList => '台站列表';

  @override
  String get statsPanel => '統計面板';

  @override
  String get statsOverview => '系統總覽';

  @override
  String get statsTotalRx => '總接收數';

  @override
  String get statsTotalTx => '總發送數';

  @override
  String get statsRate => '接收速率';

  @override
  String statsPerMin(String n) {
    return '$n/分';
  }

  @override
  String get statsStationsTotal => '台站總數';

  @override
  String get statsCap => '容量上限';

  @override
  String get statsConn => '連線狀態';

  @override
  String get statsConnected => '已連線';

  @override
  String get statsDisconnected => '未連線';

  @override
  String get statsMyGrid => '我的大網格';

  @override
  String get statsAprslocusUsers => 'APRSlocus 使用者';

  @override
  String get statsFarthest => '最遠台站';

  @override
  String get statsStatusDist => '台站狀態分佈';

  @override
  String get statsTypeDist => 'APRS 類型分佈';

  @override
  String get statsGridDist => '大網格台站分佈';

  @override
  String get statsGridHint => '依 Maidenhead 大網格（4 位）統計台站數量並排序';

  @override
  String statsGridCount(String n) {
    return '$n 個網格';
  }

  @override
  String get statsGridEmpty => '暫無台站位置資料';

  @override
  String get statsDeviceDist => '裝置類別分佈';

  @override
  String get statsOther => '其他指標';

  @override
  String get statsAvgSpeed => '平均速度';

  @override
  String get statsLastHeard => '最近上報';

  @override
  String get statsPackets => '資料包(近期)';

  @override
  String get statsNoData => '暫無資料';

  @override
  String get noStationsFiltered => '目前篩選條件下沒有台站';

  @override
  String get noStationsFilteredHint => '篩選或接收範圍過窄。可清除篩選後重試，接收範圍見「設定 → 接收範圍」。';

  @override
  String get clearStationFilter => '清除篩選';

  @override
  String get clearSearch => '清除搜尋';

  @override
  String get activeConditions => '生效條件';

  @override
  String get statsMovingCount => '移動台站';

  @override
  String get statsOnlineRate => '在線率';

  @override
  String get statsGridCountLabel => '大網格數';

  @override
  String get maxPackets => '資料包保留條數';

  @override
  String get maxPacketsTip => '資料包頁面保留的歷史條數（預設 2000，提高會佔用更多記憶體）';

  @override
  String get maxTrackPts => '軌跡點數上限';

  @override
  String get maxTrackPtsTip => '每個台站保留的軌跡點數（預設 300，決定運動軌跡能回溯多長；僅位移超過 20m 才記點）';

  @override
  String get onlineWindow => '在線判定時長（分鐘）';

  @override
  String get onlineWindowTip => '台站最後上報超過該時長即視為離線（預設 5 分鐘）';

  @override
  String get chatRecords => '聊天記錄';

  @override
  String get chatRecordsCleared => '聊天記錄已清空';

  @override
  String get deviceCat => '裝置';

  @override
  String get deviceCatDesc => '電台裝置 · 待開放';

  @override
  String get deviceSettings2 => '裝置設定';

  @override
  String get deviceSettingsSubtitle => '連接你的電台裝置';

  @override
  String get underConstruction => '前方施工，尚未開放';

  @override
  String get underConstructionHint => '該功能正在開發中，敬請期待';

  @override
  String get storageLimit => '資料上限';

  @override
  String get storageLimitSubtitle => '本機保留的資料量';

  @override
  String get connectionCard2 => 'APRS-IS 連線';

  @override
  String get immersiveMap => '沉浸地圖';

  @override
  String get immersiveMapTip => '導航風格：以我為中心、航向朝上、四角 HUD';

  @override
  String get headingUp => '航向朝上';

  @override
  String get northUp => '正北朝上';

  @override
  String get followMe => '跟隨我';

  @override
  String get beaconCountdown => '發送倒數';

  @override
  String get beaconOff => '未開啟';

  @override
  String get unlocated => '未定位';

  @override
  String get platform => '平台';

  @override
  String get nearbyStations => '附近台站';

  @override
  String get honorWall => '榮譽牆';

  @override
  String get accountHonors => '帳號榮譽';

  @override
  String get achievementsSection => '成就';

  @override
  String get notLit => '未點亮';

  @override
  String honorCriteriaLine(String c) {
    return '獲得條件：$c';
  }

  @override
  String get badgeFallback => '徽章';

  @override
  String honoredBadges(String n, String m) {
    return '已點亮 $n/$m 徽章';
  }

  @override
  String achievementsProgress(String n, String m) {
    return '$n/$m 成就';
  }

  @override
  String get beaconNotConnected => '未連線';

  @override
  String get beaconWaitingFix => '等待定位';

  @override
  String get beaconSoon => '即將';

  @override
  String beaconNextIn(String s) {
    return '距下次上報 $s';
  }

  @override
  String get beaconImminent => '即將上報…';

  @override
  String get notifConnected => '已連線';

  @override
  String get notifConnecting => '連線中';

  @override
  String get notifDisconnected => '未連線';

  @override
  String notifOnline(String n) {
    return '$n 在線';
  }

  @override
  String notifRx(String n) {
    return '收 $n';
  }

  @override
  String notifBeacon(String v) {
    return '信標 $v';
  }

  @override
  String get selectAll => '全選';

  @override
  String get deselectAll => '取消全選';

  @override
  String selectedCount(int n) {
    return '已選 $n 項';
  }

  @override
  String deleteSelected(int n) {
    return '刪除 ($n)';
  }

  @override
  String deleteSelectedConfirm(int n) {
    return '確定刪除選中的 $n 個會話？此操作不可恢復。';
  }

  @override
  String get chatManageHint => '點擊會話進行選擇，長按也可選中';

  @override
  String conversationsDeleted(int n) {
    return '已刪除 $n 個會話';
  }

  @override
  String get stationActions => '台站操作';

  @override
  String get deleteStation => '刪除台站';

  @override
  String deleteStationConfirm(String name) {
    return '確定刪除台站 $name 嗎？刪除後將從台站列表移除；若再次收到其報文會重新出現。';
  }

  @override
  String get unfavorite => '取消收藏';

  @override
  String get copyCallsign => '複製呼號';

  @override
  String get callsignCopied => '呼號已複製';

  @override
  String get stationDeleted => '已刪除台站';

  @override
  String get exportAdif => '匯出 ADIF';

  @override
  String get exportAdifDesc => '把會話匯出為 ADIF 日誌檔案，可匯入 Log4OM、N3FJP 等日誌軟體';

  @override
  String get export => '匯出';

  @override
  String get adifHint => '每筆記錄只含呼號與首則訊息時間（UTC），不含模式與頻段';

  @override
  String get adifNoSelection => '請先選擇要匯出的會話';

  @override
  String adifExported(int n) {
    return '已匯出 $n 筆記錄';
  }

  @override
  String get adifExportDone => '匯出完成';

  @override
  String get adifExportFailed => '匯出失敗，請檢查儲存權限或剩餘空間';

  @override
  String adifSavedTo(String path) {
    return '已儲存至：$path';
  }

  @override
  String get adifCopyPath => '複製路徑';

  @override
  String get adifPathCopied => '路徑已複製';

  @override
  String get chatShortLabel => '單聊';

  @override
  String get adifLogFile => '會話匯出為日誌檔案';

  @override
  String get adifOptions => '匯出選項';

  @override
  String get adifMode => '模式（MODE）';

  @override
  String get adifNotWritten => '不寫';

  @override
  String get adifModePkt => 'PKT（資料包，推薦）';

  @override
  String get adifModeFm => 'FM（語音）';

  @override
  String get adifModeData => 'DATA（資料）';

  @override
  String get adifSubModeAprs => '附加 SUBMODE=APRS';

  @override
  String get adifBand => '頻段（BAND）';

  @override
  String get adifStripSsid => '只寫基礎呼號（去掉 -SSID）';

  @override
  String get adifPreview => '預覽（將寫出的記錄）';

  @override
  String get adifModeRequiredHint => '多數日誌軟體（含 QRZ）要求 MODE，缺少會被拒收';

  @override
  String get adifFreq => '頻率（FREQ）';

  @override
  String get adifFreqHint => '單位 MHz，留空則不寫';

  @override
  String get adifFreqInvalid => '請輸入 MHz 數字，如 144.640';

  @override
  String get sysTitle => '系統狀態';

  @override
  String get sysLinkOff => '未啟用';

  @override
  String sysRx(String n) {
    return '收 $n';
  }

  @override
  String sysTx(String n) {
    return '發 $n';
  }

  @override
  String sysBeacon(String t) {
    return '信標 $t';
  }

  @override
  String sysStations(String n) {
    return '臺站 $n';
  }

  @override
  String get sysFixOk => '已定位';

  @override
  String get sysLinkAudio => '音訊';

  @override
  String get sysEmpty => '開啟 APRSlocus 並連線後，這裡會顯示臺站執行狀態';

  @override
  String get backupTitle => '備份與還原';

  @override
  String get backupSubtitle => '匯出或匯入設定與資料';

  @override
  String get backupEntryDesc => '打包設定與資料為 JSON 檔';

  @override
  String get backupDesc => '備份檔是 JSON 文字，換機或重裝後可還原；匯入會依分組覆蓋，無法復原。';

  @override
  String get backupExport => '匯出備份';

  @override
  String get backupExportDesc => '選擇要包含的內容，再存成檔案或複製到剪貼簿';

  @override
  String get backupExportToFile => '存成檔案';

  @override
  String get backupCopyJson => '複製到剪貼簿';

  @override
  String get backupExportDone => '備份已匯出';

  @override
  String get backupExportFailed => '匯出失敗，請檢查儲存權限或剩餘空間';

  @override
  String get backupCopyDone => '備份內容已複製到剪貼簿';

  @override
  String backupSavedTo(String path) {
    return '已儲存到：$path';
  }

  @override
  String get backupCatSettings => '設定';

  @override
  String get backupCatSettingsDesc => '電台、信標、地圖、篩選、資料來源、伺服器';

  @override
  String get backupCatStations => '臺站與聯絡人';

  @override
  String get backupCatStationsDesc => '我的最愛、手動新增的聯絡人與備註';

  @override
  String get backupCatMessages => '訊息記錄';

  @override
  String get backupCatMessagesDesc => '單聊訊息與已讀位置';

  @override
  String get backupCatChats => '群組聊天';

  @override
  String get backupCatChatsDesc => '群組、成員與已讀狀態';

  @override
  String get backupCatTranslate => '翻譯設定';

  @override
  String get backupCatTranslateDesc => '翻譯介面、金鑰與語言偏好';

  @override
  String get backupCatHonors => '成就與榮譽';

  @override
  String get backupCatHonorsDesc => '解鎖記錄、計數與預設徽章';

  @override
  String backupItems(int n) {
    return '$n 項';
  }

  @override
  String get backupSelectAll => '全選';

  @override
  String get backupNoSelection => '請至少選擇一個分組';

  @override
  String get backupImport => '匯入備份';

  @override
  String get backupImportDesc => '選擇先前匯出的 JSON 備份檔';

  @override
  String get backupPickFile => '選擇備份檔';

  @override
  String get backupPaste => '從剪貼簿貼上';

  @override
  String get backupPasteEmpty => '剪貼簿裡沒有文字';

  @override
  String get backupPreview => '備份內容';

  @override
  String backupFromVersion(String v) {
    return '來源版本 $v';
  }

  @override
  String backupExportedAt(String t) {
    return '匯出時間 $t';
  }

  @override
  String get backupImportSelected => '匯入所選';

  @override
  String get backupImportConfirmTitle => '確認匯入？';

  @override
  String get backupImportConfirm => '所選分組會被備份內容覆蓋，且無法復原。建議先匯出一次目前的資料。';

  @override
  String backupImported(int n) {
    return '已匯入 $n 項';
  }

  @override
  String backupSkipped(int n) {
    return '略過 $n 項（本版本不認識的內容）';
  }

  @override
  String get backupImportNothing => '備份裡不包含所選分組的資料';

  @override
  String get backupRestartTitle => '匯入完成';

  @override
  String get backupRestartHint => '資料已寫入，重新啟動後才會完全生效（成就、翻譯、伺服器連線等）。';

  @override
  String get backupRestartNow => '結束應用程式';

  @override
  String get backupLater => '稍後';

  @override
  String get backupSecurityTip => '備份檔包含呼號、伺服器密碼與 API 金鑰，請妥善保管。';

  @override
  String get backupWebHint => 'Web 版請用「複製到剪貼簿 / 從剪貼簿貼上」匯入匯出。';

  @override
  String get backupErrNotJson => '檔案不是有效的 JSON';

  @override
  String get backupErrNotBackup => '這不是 APRSlocus 的備份檔';

  @override
  String get backupErrSchemaNewer => '備份來自較新版本的 APRSlocus，請先更新應用程式';

  @override
  String get backupErrEmpty => '備份裡沒有可匯入的內容';

  @override
  String get backupErrTooLarge => '備份檔超過 32 MB，無法讀取';

  @override
  String get backupErrRead => '讀取備份檔失敗';

  @override
  String get backupErrUnsupported => '目前平台不支援選擇檔案，請改用剪貼簿貼上';

  @override
  String get themeTitle => '主題';

  @override
  String get themeEntryDesc => '自訂顏色、圖示與文字';

  @override
  String get themeSubtitle => '把介面配色、圖示與常用文案改成你自己的';

  @override
  String get themePresets => '預設與我的主題';

  @override
  String get themePresetTag => '預設';

  @override
  String get themeActive => '使用中';

  @override
  String get themePresetDefault => '預設';

  @override
  String get themePresetOcean => '海洋';

  @override
  String get themePresetForest => '森林';

  @override
  String get themePresetMidnight => '暗夜';

  @override
  String get themePresetSunset => '日落';

  @override
  String get themePresetContrast => '高對比';

  @override
  String get themeBuiltinHint => '預設主題不可修改，複製為我的主題後即可自由編輯';

  @override
  String get themeColors => '顏色';

  @override
  String get themeColorsDesc => '逐項覆寫配色；未修改的項跟隨預設';

  @override
  String get themeRadius => '卡片圓角';

  @override
  String get themeRadiusDesc => '作用於卡片與輸入框（小徽標等不受影響）';

  @override
  String get themeIcons => '圖示';

  @override
  String get themeIconsDesc => '為底部頁籤與設定入口換圖示';

  @override
  String get themeTexts => '文字';

  @override
  String get themeTextsDesc => '覆寫常用文案（按鈕與錯誤提示不開放，避免介面變得不可操作）';

  @override
  String get themeNew => '新增主題';

  @override
  String get themeDuplicate => '複製為我的主題';

  @override
  String get themeRename => '重新命名';

  @override
  String get themeDelete => '刪除主題';

  @override
  String themeDeleteConfirm(String name) {
    return '刪除主題「$name」？此操作無法復原。';
  }

  @override
  String get themeReset => '恢復預設';

  @override
  String get themeResetAll => '重設本主題';

  @override
  String get themeSaved => '主題已儲存';

  @override
  String get themeNameHint => '主題名稱';

  @override
  String get themePickColor => '選擇顏色';

  @override
  String get themePickIcon => '選擇圖示';

  @override
  String get themePickIconSearch => '搜尋圖示名稱（英文）';

  @override
  String get themeEditText => '修改文字';

  @override
  String get themeTextHint => '留空即恢復預設';

  @override
  String get themeIconImport => '從圖片匯入';

  @override
  String get themeIconImportHint => 'PNG/JPG/WebP/GIF/BMP/SVG，≤2MB';

  @override
  String themeIconImportDone(String name) {
    return '已匯入圖示：$name';
  }

  @override
  String get themeIconWebHint => 'Web 版不支援匯入圖片，請使用內建圖示庫';

  @override
  String get themeIconErrFormat => '不支援的圖片格式（支援 PNG/JPG/WebP/GIF/BMP/SVG）';

  @override
  String get themeIconErrTooLarge => '圖片超過 2MB，請先壓縮';

  @override
  String get themeIconErrFailed => '匯入圖示失敗';

  @override
  String get themeIconErrUnsupported => '目前平台不支援匯入圖片';

  @override
  String get themeIo => '匯入與匯出';

  @override
  String get themeIoDesc => '主題是 JSON 文字，可以分享給別人，也可以手動編輯';

  @override
  String get themeExport => '匯出此主題';

  @override
  String get themeExportAll => '匯出全部主題';

  @override
  String get themeImport => '匯入主題';

  @override
  String get themeImportPaste => '從剪貼簿匯入';

  @override
  String themeImportDone(int n) {
    return '已匯入 $n 個主題';
  }

  @override
  String get themeErrNotJson => '檔案不是有效的 JSON';

  @override
  String get themeErrNotTheme => '這不是 APRSlocus 主題檔';

  @override
  String get themeErrSchemaNewer => '主題來自較新版本的 APRSlocus，請先更新應用程式';

  @override
  String get themeErrEmpty => '檔案裡沒有可用的主題';

  @override
  String get themeFixedPrimary => '目前主題已固定主色，請到「主題」頁修改';

  @override
  String get themeTokenPrimary => '主色';

  @override
  String get themeTokenSurface => '卡片表面';

  @override
  String get themeTokenBackground => '頁面背景';

  @override
  String get themeTokenBackgroundSoft => '次層背景';

  @override
  String get themeTokenTextPrimary => '主文字';

  @override
  String get themeTokenTextSecondary => '次要文字';

  @override
  String get themeTokenTextMuted => '弱化文字';

  @override
  String get themeTokenDivider => '分隔線';

  @override
  String get themeTokenSuccess => '成功/上線';

  @override
  String get themeTokenWarning => '警告';

  @override
  String get themeTokenDanger => '危險/離線';

  @override
  String get themeTokenInfo => '資訊/強調';
}
