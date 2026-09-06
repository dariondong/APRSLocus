import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme.dart';
import 'models.dart';
import 'mock_data.dart';
import 'services.dart';
import 'aprs_parse.dart';
import 'aprs_device.dart';
import 'net/aprs.dart';

class AppState extends ChangeNotifier {
  /// 应用版本（用于信标备注、APRSlocus 识别）
  static const appVersion = '1.6.22';
  // 我的电台
  String myCall = 'BV2AAA';
  int mySsid = 0; // 0 = 无后缀, 1-15 = -1 到 -15
  String mySymbol = '>';
  String myComment = 'APRSlocus 移动台';

  /// 完整呼号（含 SSID 后缀）
  String get myFullCall => mySsid == 0 ? myCall : '$myCall-$mySsid';

  /// 收到新消息时回调（src, text, groupId），用于顶部气泡通知
  void Function(String src, String text, String? groupId)? onNewMessage;

  /// 收到群聊邀请时回调（from, groupCall, groupName），用于弹窗确认
  void Function(String from, String groupCall, String groupName)?
  onInviteReceived;

  /// 收到群聊事件时回调（groupCall, event），用于通知群主
  void Function(String groupCall, String event)? onGroupEvent;

  // 我的位置
  bool myHasFix = false;
  double? myLat, myLng, myAlt;
  double? mySpeed, myCourse;
  String locStatus = '未定位';

  /// 手动设置我的位置（模拟位置 / Windows 无定位服务时的备用）
  void setMyPosition(double lat, double lng, {double? alt}) {
    myLat = lat;
    myLng = lng;
    myAlt = alt;
    myHasFix = true;
    useSimLocation = true;
    loc.stop();
    locStatus = '模拟位置';
    persist();
    _notify();
  }

  // 信标
  bool beaconEnabled = true;
  int beaconInterval = 60; // 秒（APRS-IS 建议移动站不低于 60 秒）
  DateTime _lastBeacon = DateTime.now();
  int beaconsSent = 0;

  /// 是否已询问过“连接后是否自动上报位置”（只问一次，记住选择）
  bool beaconAutoAsked = false;

  /// 连接成功后首次询问“自动上报位置”的回调（由首页绑定并弹出选择）
  void Function()? onAskBeaconAuto;

  // 信标上报内容选项
  bool beaconIncludeSpeed = true; // 速度
  bool beaconIncludeCourse = true; // 方位角
  bool beaconIncludeBattery = true; // 手机电量
  int _battery = -1; // 电量百分比（-1 未知）

  void setBeaconEnabled(bool v) {
    beaconEnabled = v;
    persist();
    _notify();
  }

  void setBeaconInterval(int seconds) {
    beaconInterval = seconds < 5 ? 5 : seconds;
    persist();
    _notify();
  }

  void setBeaconIncludeSpeed(bool v) {
    beaconIncludeSpeed = v;
    persist();
    _notify();
  }

  void setBeaconIncludeCourse(bool v) {
    beaconIncludeCourse = v;
    persist();
    _notify();
  }

  void setBeaconIncludeBattery(bool v) {
    beaconIncludeBattery = v;
    persist();
    _notify();
  }

  /// 更新 APRS-IS 接收范围过滤
  void setFilter(double lat, double lng, int radiusKm) {
    filterLat = lat;
    filterLng = lng;
    filterRadius = radiusKm < 10 ? 10 : radiusKm;
    persist();
    _notify();
    // 重新连接以应用新过滤器
    _refreshFilter();
  }

  /// 应用过滤变更：重连以使 APRS-IS 服务器使用新过滤器
  void _refreshFilter() {
    if (!connected) return;
    final newFilter = filterString;
    if (_lastFilter != newFilter) {
      aprs.filter = newFilter;
      _log(LogLevel.info, '连接', '过滤规则变更，重连: $newFilter');
      reconnect();
    }
  }

  /// 公开：手动触发 APRS 过滤器刷新（设置面板调用）
  void refreshAprsFilter() => _refreshFilter();

  /// 生成 APRS-IS 过滤字符串（服务器只收范围 + 群呼号，国家过滤在本地做）
  String get filterString {
    var f =
        'r/${filterLat.toStringAsFixed(2)}/${filterLng.toStringAsFixed(2)}/$filterRadius';
    // 追加所有群呼号（~ 前缀精确匹配）
    for (final g in chatGroups) {
      f += ' ~${g.groupCall}';
    }
    return f;
  }

  /// 业余无线电呼号国家/地区前缀表（呼号首位前缀 → 国家）
  static const Map<String, List<String>> countryCallPrefixes = {
    'CN': ['B'],
    'KR': ['HL', 'DS', 'D7', '6K', '6L', '6M'],
    'JP': [
      'JA',
      'JB',
      'JC',
      'JD',
      'JE',
      'JF',
      'JG',
      'JH',
      'JI',
      'JJ',
      'JK',
      'JL',
      'JM',
      'JN',
      'JO',
      'JP',
      'JQ',
      'JR',
      'JS',
    ],
    'US': ['K', 'W', 'N', 'A'],
    'CA': ['VE', 'VA', 'VY'],
    'GB': ['G', 'M', '2', 'M6', '2E'],
    'DE': ['D', 'DL'],
    'FR': ['F'],
    'IT': ['I'],
    'ES': ['EA', 'EB', 'EC'],
    'RU': ['R', 'UA', 'UB', 'UC'],
    'AU': ['VK'],
    'NZ': ['ZL', 'ZM'],
    'BR': ['PY'],
    'AR': ['LU'],
    'MX': ['XE'],
    'ZA': ['ZS'],
    'IN': ['VU'],
    'TH': ['HS', 'E2'],
    'SG': ['9V'],
    'MY': ['9M', '9W'],
    'ID': ['YB', 'YC', 'YE'],
    'PH': ['DU', 'DV', '4F', '4G'],
    'TW': ['BV', 'BM', 'BN', 'BO'],
    'HK': ['VR'],
    'MO': ['XX'],
    'CN-UNKNOWN': [], // 占位避免空匹配
  };

  /// 国家/地区的中文名
  static const Map<String, String> countryNames = {
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
  };

  /// 按国家接收列表（国家代码）
  final List<String> receiveCountries = [];

  /// 是否接收其他台站（不匹配所选国家的特殊呼号台站也接收）
  bool receiveOthers = false;

  /// 添加按国家接收
  void addReceiveCountry(String code) {
    if (receiveCountries.contains(code)) return;
    receiveCountries.add(code);
    _matchCache.clear();
    persist();
    _refreshFilter();
    _bumpStationsVersion(); // 可见台站集合变化
    _notify();
  }

  /// 移除按国家接收
  void removeReceiveCountry(String code) {
    receiveCountries.remove(code);
    _matchCache.clear();
    persist();
    _refreshFilter();
    _bumpStationsVersion(); // 可见台站集合变化
    _notify();
  }

  /// 设置是否接收其他台站
  void setReceiveOthers(bool v) {
    receiveOthers = v;
    _matchCache.clear();
    persist();
    _refreshFilter();
    _bumpStationsVersion(); // 可见台站集合变化
    _notify();
  }

  /// 判断呼号是否匹配当前选择的国家/地区前缀（用于本地台站过滤）
  /// 空列表表示不匹配任何国家（普通台站隐藏，仅保留收藏/手动与「其他台站」特殊类型）
  final Map<String, bool> _matchCache = {};
  bool _matchReceiveFilter(String call) {
    final up = call.toUpperCase();
    final cached = _matchCache[up];
    if (cached != null) return cached;
    var ok = false;
    if (receiveCountries.isNotEmpty) {
      for (final code in receiveCountries) {
        final prefixes = countryCallPrefixes[code];
        if (prefixes == null) continue;
        for (final p in prefixes) {
          if (up.startsWith(p)) {
            ok = true;
            break;
          }
        }
        if (ok) break;
      }
    }
    _matchCache[up] = ok;
    return ok;
  }

  /// 清除匹配缓存（国家筛选变化时调用）
  void clearMatchCache() => _matchCache.clear();

  /// 校验是否标准业余无线电呼号（排除 WIDE/TCPIP/APRS/纯数字等非台站呼号）
  /// 支持带 SSID：BG7LZQ-9；中国：B[GHDIYZ][1-9]...；国际：前缀+数字+后缀
  static final RegExp _callRe = RegExp(
    r'^(?:\d{1}[A-Z]{1,2}|[A-Z]{1,2}\d{1,2})[A-Z]{1,3}$',
  );
  static final RegExp _hasLetter = RegExp(r'[A-Z]');
  static final RegExp _hasDigit = RegExp(r'\d');
  static final Map<String, bool> _callCache = {};
  static bool isValidCallsign(String raw) {
    final key = raw.toUpperCase();
    final cached = _callCache[key];
    if (cached != null) return cached;
    final base = key.split('-').first.trim();
    if (base.isEmpty || base.length < 3 || base.length > 7) {
      _callCache[key] = false;
      return false;
    }
    // 常见非呼号协议标识
    const bad = {
      'WIDE',
      'TCPIP',
      'APRS',
      'TRACE',
      'RELAY',
      'BEACON',
      'SAT',
      'CQ',
      'QST',
      'NOCALL',
      'UNKNOWN',
    };
    for (final b in bad) {
      if (base.startsWith(b)) {
        _callCache[key] = false;
        return false;
      }
    }
    // 国际格式：字母前缀1-2位 + 数字1-2位 + 字母后缀1-3位，如 BG7LZQ / JA1AA / DL1ABC / 9M2XYZ / 9W3FM
    if (!_callRe.hasMatch(base)) {
      _callCache[key] = false;
      return false;
    }
    // 必须包含至少一个字母和一个数字
    final ok = _hasLetter.hasMatch(base) && _hasDigit.hasMatch(base);
    _callCache[key] = ok;
    return ok;
  }

  /// 公开：当前台站是否应显示（国家筛选 + 其他台站[特殊类型] + 收藏/手动例外 + 呼号格式校验）
  bool stationAllowed(String call) {
    final idx = stations.indexWhere((s) => s.call == call);
    if (idx < 0) return _matchReceiveFilter(call) || receiveOthers;
    return stationAllowedFor(stations[idx]);
  }

  /// 高性能版本：直接传 Station 对象，避免 indexWhere 线性查找（列表遍历时使用）
  bool stationAllowedFor(Station s) {
    if (s.favorite || s.manual) return true;
    if (_matchReceiveFilter(s.call)) return true;
    // 其他台站：接收特殊类型（中继/气象/FMO/APRSlocus 同款）台站
    if (receiveOthers) {
      final tg = s.typeGroup;
      return tg == TypeGroup.infra ||
          tg == TypeGroup.wx ||
          tg == TypeGroup.fmo ||
          s.isAprslocusStation;
    }
    return false;
  }

  void setMaxStations(int n) {
    maxStations = n < 50 ? 50 : n;
    // 立即裁剪超量台站（优先保留收藏/手动台站）
    if (stations.length > maxStations) {
      stations.sort((a, b) {
        final aKeep = a.favorite || a.manual;
        final bKeep = b.favorite || b.manual;
        if (aKeep != bKeep) return aKeep ? -1 : 1; // 收藏/手动排前
        return b.lastHeard.compareTo(a.lastHeard); // 新的在前
      });
      final keepers = stations.where((s) => s.favorite || s.manual).length;
      final needRemove = stations.length - maxStations;
      final canRemove = stations.length - keepers;
      if (needRemove > 0 && canRemove > 0) {
        final doRemove = needRemove < canRemove ? needRemove : canRemove;
        stations.removeRange(stations.length - doRemove, stations.length);
      }
      _bumpStationsVersion();
      _saveStations();
    }
    persist();
    _notify();
  }

  // 连接
  bool connected = false;
  bool connecting = false;
  String connInfo = '未连接 · 点击播放按钮连接 APRS-IS';
  // Passcode 是否被服务器判定无效（logresp unverified）
  bool passcodeInvalid = false;

  // 坐标显示：'wgs84' 标准 / 'gcj' 高德火星坐标
  String coordDatum = 'wgs84';

  // 深色模式
  bool darkMode = false;

  // 界面语言：'' = 跟随系统；'zh' 中文；'en' English
  String locale = '';

  /// 切换界面语言
  void setLocale(String lang) {
    locale = lang;
    persist();
    _notify();
  }

  // 界面缩放系数：1.0 = 标准；范围 0.85 ~ 1.3
  double uiScale = 1.0;

  /// 设置界面缩放
  void setUiScale(double v) {
    uiScale = v.clamp(0.85, 1.3);
    persist();
    _notify();
  }

  // 界面重建计数：缩放等全局变化后强制重建导航栈
  int reloadTick = 0;

  /// 重新加载整个界面（重建导航栈）
  void reloadUi() {
    reloadTick++;
    persist();
    _notify();
  }

  // 自定义主题色（十六进制字符串，如 '2563EB'；空 = 默认蓝）
  String themeColor = '';

  /// 切换深色模式
  void setDarkMode(bool v) {
    darkMode = v;
    C.applyTheme(isDark: v, primary: themeColorValue);
    persist();
    _notify();
  }

  /// 设置自定义主题色
  void setThemeColor(String hex) {
    themeColor = hex.trim().replaceAll('#', '');
    C.applyTheme(isDark: darkMode, primary: themeColorValue);
    persist();
    _notify();
  }

  /// 解析自定义主题色为 Color
  Color? get themeColorValue {
    final h = themeColor.trim().replaceAll('#', '');
    if (h.length != 6) return null;
    final v = int.tryParse(h, radix: 16);
    if (v == null) return null;
    return Color(0xFF000000 | v);
  }

  /// 应用已保存的主题（App 启动时调用）
  void applySavedTheme() {
    C.applyTheme(isDark: darkMode, primary: themeColorValue);
  }

  // 定位来源：false = 系统 GPS；true = 模拟位置（手动坐标）
  bool useSimLocation = false;

  void setUseSimLocation(bool v) {
    useSimLocation = v;
    if (v) {
      // 切换到模拟：停止 GPS
      loc.stop();
      if (myLat == null || myLng == null) {
        // 无手动坐标时用默认演示坐标
        setMyPosition(39.9042, 116.4074);
      } else {
        myHasFix = true;
        locStatus = '模拟位置';
      }
    } else {
      // 切换到 GPS：自动启动
      locStatus = '未定位';
      startTracking();
    }
    persist();
    _notify();
  }

  // 定位模式：'gps' = 纯 GPS；'gps_network' = GPS + 网络辅助
  String locationMode = 'gps_network';

  void setLocationMode(String v) {
    if (v != 'gps' && v != 'gps_network') return;
    locationMode = v;
    loc.setMode(v); // 运行中立即生效
    persist();
    _notify();
  }

  // 地图类型：gaode / carto / osm
  String mapType = 'gaode';

  void setMapType(String t) {
    mapType = t;
    persist();
    _notify();
  }

  // 更新渠道：'gitcode' / 'github'
  String updateChannel = 'gitcode';

  void setUpdateChannel(String c) {
    updateChannel = c;
    persist();
    _notify();
  }

  // 接收范围过滤（APRS-IS filter: r/lat/lng/radius_km）
  double filterLat = 39.9042;
  double filterLng = 116.4074;
  int filterRadius = 300; // km
  int maxStations = 100000; // 台站上限（默认无限制，可下调）
  bool filterFollow = true; // 过滤中心跟随我的位置

  /// 未连接时的待发送队列（重连成功后补发）
  final List<String> _pendingTx = [];

  // 连接保活
  DateTime _lastTx = DateTime.now();
  Timer? _keepaliveTimer;
  Timer? _reconnectTimer;
  bool _userDisconnected = false;

  // 开发者模式：开启后显示模拟台站/模拟数据
  bool devMode = false;
  final Set<String> _demoCalls = {};

  // 实验室：允许手机横屏显示
  bool labLandscape = false;

  void setLabLandscape(bool v) {
    labLandscape = v;
    persist();
    _applyOrientation();
    _notify();
  }

  Future<void> _applyOrientation() async {
    if (kIsWeb) return;
    try {
      await SystemChrome.setPreferredOrientations(
        labLandscape
            ? [
                DeviceOrientation.portraitUp,
                DeviceOrientation.landscapeLeft,
                DeviceOrientation.landscapeRight,
              ]
            : [DeviceOrientation.portraitUp],
      );
    } catch (_) {}
  }

  /// 临时解锁横屏（群组跟踪等全屏场景用）；退出时调用 [_restoreOrientation]
  Future<void> unlockLandscape() async {
    if (kIsWeb) return;
    try {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } catch (_) {}
  }

  /// 按用户设置恢复屏幕方向（横屏偏好关闭时回到竖屏锁定）
  Future<void> restoreOrientation() => _applyOrientation();

  // 首次引导（OOBE）是否已完成
  bool oobeDone = false;

  void completeOobe() {
    oobeDone = true;
    persist();
    _notify();
    // OOBE 完成：此时再引导请求定位权限并启动定位（避免向导中途弹权限）
    unawaited(_requestLocationAfterOobe());
  }

  /// 重新运行首次引导（OOBE）：标记未完成，App 层会切换到向导
  void restartOobe() {
    oobeDone = false;
    persist();
    _notify();
  }

  // 持久化数据加载完成（用于启动画面）
  bool initialized = false;

  // 数据
  final List<Station> stations;
  final List<Packet> packets = [];
  final List<AprsMsg> messages;
  final List<ChatGroup> chatGroups = [];
  bool _stationsDirty = false; // 台站列表有变更，待节流保存
  final List<LogEntry> logs = [];
  int unreadMessages = 0; // 未读消息数（侧边栏/底部导航角标）
  final Map<String, DateTime> _readAt = {}; // 会话已读时间点（呼号 → 时间）
  final Map<String, DateTime> _groupReadAt = {}; // 群聊已读时间点（groupId → 时间）
  static const int _maxLogs = 500;
  int packetsRx = 0;
  int packetsTx = 0;
  final List<DateTime> _rxTimes = [];

  /// 记录一条日志（最新在前，超出上限丢弃最旧）
  void _log(LogLevel level, String source, String message) {
    logs.insert(0, LogEntry(DateTime.now(), level, source, message));
    if (logs.length > _maxLogs) logs.removeLast();
  }

  void clearLogs() {
    logs.clear();
    _notify();
  }

  /// 每分钟收包速率
  int get packetsPerMin {
    final now = DateTime.now();
    _rxTimes.removeWhere((t) => now.difference(t).inSeconds > 60);
    return _rxTimes.length;
  }

  /// 我的位置对应的台站对象（供列表/详情复用）
  /// 我的位置轨迹（最近 N 个定位点）
  final List<TrackPt> myTrack = [];

  Station? get myStation => myHasFix
      ? Station(
          call: myCall,
          symbol: mySymbol,
          alias: '我的位置',
          lat: myLat!,
          lng: myLng!,
          alt: myAlt,
          speed: mySpeed,
          course: myCourse,
          comment: myComment,
          lastHeard: DateTime.now(),
          status: St.moving,
        )
      : null;

  final LocService loc = LocService();
  final AprsConnector aprs = createAprs();

  Timer? _simTimer;
  Timer? _tickTimer;

  /// 每秒刷新通知（信标倒计时/收包速率等秒级 UI 专用）。
  /// 与 AppState.notifyListeners 分离：避免每秒 _notify() 触发整个页面树
  /// （含 IndexedStack 内所有页面）重建、反复重算几百个台站的数据。
  final ValueNotifier<int> tick = ValueNotifier<int>(0);

  // ─── 设置持久化 ───
  Future<void> _loadPrefs() async {
    try {
      final p = await SharedPreferences.getInstance();
      myCall = p.getString('myCall') ?? myCall;
      mySsid = p.getInt('mySsid') ?? mySsid;
      mySymbol = p.getString('mySymbol') ?? mySymbol;
      myComment = p.getString('myComment') ?? myComment;
      beaconEnabled = p.getBool('beacon') ?? beaconEnabled;
      beaconAutoAsked = p.getBool('beaconAutoAsked') ?? beaconAutoAsked;
      beaconInterval = p.getInt('beaconInterval') ?? beaconInterval;
      beaconIncludeSpeed =
          p.getBool('beaconIncludeSpeed') ?? beaconIncludeSpeed;
      beaconIncludeCourse =
          p.getBool('beaconIncludeCourse') ?? beaconIncludeCourse;
      beaconIncludeBattery =
          p.getBool('beaconIncludeBattery') ?? beaconIncludeBattery;
      coordDatum = p.getString('coordDatum') ?? coordDatum;
      darkMode = p.getBool('darkMode') ?? darkMode;
      locale = p.getString('locale') ?? locale;
      themeColor = p.getString('themeColor') ?? themeColor;
      uiScale = p.getDouble('uiScale') ?? uiScale;      mapType = p.getString('mapType') ?? mapType;
      updateChannel = p.getString('updateChannel') ?? updateChannel;
      locationMode = p.getString('locationMode') ?? locationMode;
      loc.mode = locationMode;
      useSimLocation = p.getBool('useSimLocation') ?? useSimLocation;
      filterLat = p.getDouble('filterLat') ?? filterLat;
      filterLng = p.getDouble('filterLng') ?? filterLng;
      filterRadius = p.getInt('filterRadius') ?? filterRadius;
      maxStations = p.getInt('maxStations') ?? maxStations;
      filterFollow = p.getBool('filterFollow') ?? filterFollow;
      // 按国家接收
      try {
        final ctr = p.getStringList('receiveCountries');
        if (ctr != null)
          receiveCountries
            ..clear()
            ..addAll(ctr);
      } catch (_) {}
      receiveOthers = p.getBool('receiveOthers') ?? receiveOthers;
      labLandscape = p.getBool('labLandscape') ?? labLandscape;
      oobeDone = p.getBool('oobeDone') ?? oobeDone;
      aprs.server = p.getString('server') ?? aprs.server;
      aprs.port = p.getInt('port') ?? aprs.port;
      aprs.passcode = p.getString('passcode') ?? aprs.passcode;
      final savedLat = p.getDouble('myLat');
      final savedLng = p.getDouble('myLng');
      if (savedLat != null && savedLng != null) {
        myLat = savedLat;
        myLng = savedLng;
        myHasFix = true;
        locStatus = '已保存位置';
      }
      // 注意：devMode 不持久化，启动始终为干净的演示关闭状态
      // 加载消息
      final msgsJson = p.getString('messages');
      if (msgsJson != null && msgsJson.isNotEmpty) {
        try {
          final list = jsonDecode(msgsJson) as List;
          messages.clear();
          messages.addAll(
            list.map((j) => AprsMsg.fromJson(j as Map<String, dynamic>)),
          );
        } catch (_) {}
      }
      // 加载群聊
      final groupsJson = p.getString('chatGroups');
      if (groupsJson != null && groupsJson.isNotEmpty) {
        try {
          final list = jsonDecode(groupsJson) as List;
          chatGroups.clear();
          chatGroups.addAll(
            list.map((j) => ChatGroup.fromJson(j as Map<String, dynamic>)),
          );
        } catch (_) {}
      }
      // 加载会话已读时间点
      final readJson = p.getString('readAt');
      if (readJson != null && readJson.isNotEmpty) {
        try {
          final map = jsonDecode(readJson) as Map<String, dynamic>;
          _readAt.clear();
          map.forEach((k, v) {
            _readAt[k] = DateTime.fromMillisecondsSinceEpoch(v as int);
          });
        } catch (_) {}
      }
      // 加载群聊已读时间点
      final groupReadJson = p.getString('groupReadAt');
      if (groupReadJson != null && groupReadJson.isNotEmpty) {
        try {
          final map = jsonDecode(groupReadJson) as Map<String, dynamic>;
          _groupReadAt.clear();
          map.forEach((k, v) {
            _groupReadAt[k] = DateTime.fromMillisecondsSinceEpoch(v as int);
          });
        } catch (_) {}
      }
      _recalcUnread();
      // 加载收藏/手动联系人
      _loadStations(p);
      // 应用保存的主题（深色/自定义色）——必须在 initialized 前，避免先渲染默认皮肤
      applySavedTheme();
      initialized = true;
      _applyOrientation();
      _notify();
    } catch (_) {
      applySavedTheme();
      initialized = true;
      _applyOrientation();
      _notify();
    }
  }

  /// 保存当前设置到本地（重启后保留）
  void persist() {
    SharedPreferences.getInstance()
        .then((p) {
          p.setString('myCall', myCall);
          p.setInt('mySsid', mySsid);
          p.setString('mySymbol', mySymbol);
          p.setString('myComment', myComment);
          p.setBool('beacon', beaconEnabled);
          p.setBool('beaconAutoAsked', beaconAutoAsked);
          p.setInt('beaconInterval', beaconInterval);
          p.setBool('beaconIncludeSpeed', beaconIncludeSpeed);
          p.setBool('beaconIncludeCourse', beaconIncludeCourse);
          p.setBool('beaconIncludeBattery', beaconIncludeBattery);
          p.setString('coordDatum', coordDatum);
          p.setBool('darkMode', darkMode);
          p.setString('locale', locale);
          p.setString('themeColor', themeColor);
          p.setDouble('uiScale', uiScale);
          p.setString('mapType', mapType);
          p.setString('updateChannel', updateChannel);
          p.setString('locationMode', locationMode);
          p.setBool('useSimLocation', useSimLocation);
          p.setDouble('filterLat', filterLat);
          p.setDouble('filterLng', filterLng);
          p.setInt('filterRadius', filterRadius);
          p.setInt('maxStations', maxStations);
          p.setBool('filterFollow', filterFollow);
          p.setStringList('receiveCountries', receiveCountries);
          p.setBool('receiveOthers', receiveOthers);
          p.setBool('labLandscape', labLandscape);
          p.setBool('oobeDone', oobeDone);
          p.setString('server', aprs.server);
          p.setInt('port', aprs.port);
          p.setString('passcode', aprs.passcode);
          if (myHasFix && myLat != null && myLng != null) {
            p.setDouble('myLat', myLat!);
            p.setDouble('myLng', myLng!);
          }
          // 保存消息
          final msgsJson = jsonEncode(messages.map((m) => m.toJson()).toList());
          p.setString('messages', msgsJson);
          // 保存群聊
          final groupsJson = jsonEncode(
            chatGroups.map((g) => g.toJson()).toList(),
          );
          p.setString('chatGroups', groupsJson);
        })
        .catchError((_) {});
    _notify();
  }

  /// 仅保存消息列表到本地
  void _saveMessages() {
    SharedPreferences.getInstance()
        .then((p) {
          final json = jsonEncode(messages.map((m) => m.toJson()).toList());
          p.setString('messages', json);
          final readJson = jsonEncode(
            _readAt.map((k, v) => MapEntry(k, v.millisecondsSinceEpoch)),
          );
          p.setString('readAt', readJson);
          final groupReadJson = jsonEncode(
            _groupReadAt.map((k, v) => MapEntry(k, v.millisecondsSinceEpoch)),
          );
          p.setString('groupReadAt', groupReadJson);
        })
        .catchError((_) {});
  }

  /// 初始化官方 APRS 设备识别库：内置快照/本地缓存先行，随后静默拉取官方更新。
  /// 就绪/更新完成后刷新台站版本，让列表设备标签与设备类别筛选生效。
  void _initDeviceDb() {
    AprsDevice.instance.onReady = () {
      if (_disposed) return;
      _bumpStationsVersion();
      _notify();
    };
    unawaited(AprsDevice.instance.ensureLoaded());
  }

  AppState() : stations = <Station>[], messages = <AprsMsg>[] {
    _initDeviceDb();
    _loadPrefs();
    loc.onFix = _onFix;
    loc.onStatus = (s) {
      if (_disposed) return;
      locStatus = s;
      _notify();
    };
    // 通知栏"连接/断开"按钮 → 切换服务器连接
    loc.onToggleConnect = () {
      if (_disposed) return;
      toggleConnect();
    };
    aprs.onLine = _onAprsLine;
    aprs.onDisconnected = () {
      if (_disposed) return;
      connected = false;
      final manual = _userDisconnected;
      connInfo = manual ? '未连接 · 已手动断开' : '连接已断开 · 8秒后自动重连…';
      _log(
        manual ? LogLevel.info : LogLevel.warn,
        '连接',
        manual ? '已手动断开连接' : '连接意外断开，8 秒后自动重连',
      );
      _notify();
      _updateNotification();
      // 意外断开自动重连
      if (!_userDisconnected) _scheduleReconnect();
    };
    _simTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (devMode) _simTick();
    });
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_disposed) return;
      // 自动定时上报仅在已连接 APRS-IS 时进行；未连接不发送（避免误以为在上报）
      if (connected &&
          beaconEnabled &&
          myHasFix &&
          DateTime.now().difference(_lastBeacon).inSeconds >= beaconInterval) {
        _sendBeaconNow();
      }
      // 台站“有效状态”翻转（如超 5 分钟变离线、移动→静止）时才推进版本并通知，
      // 否则不触发任何页面重建；无翻转只刷新秒级 UI（tick）。
      if (_bumpStatusVersionIfChanged()) _notify();
      // 每秒刷新：只通知“秒级 UI”（信标倒计时/收包速率），
      // 不再全量 _notify() 重建整个页面树
      tick.value++;
    });
    // 连接保活：APRS-IS 空闲超时约 30s，无发送时发状态帧防止被踢
    _keepaliveTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!connected || _userDisconnected) return;
      if (DateTime.now().difference(_lastTx).inSeconds < 25) return;
      // 保活：发送身份/在线状态帧。tocall=APALOC（本应用官方注册标识），
      // body=APRSLocus CONNECT（区分于位置信标；不再用非标 “保持连接”）
      final raw = '$myFullCall>APALOC,TCPIP*:>APRSLocus CONNECT';
      aprs.send(raw);
      _lastTx = DateTime.now();
      _updateNotification(); // 定期刷新通知内容（台站数/收包数）
    });
    // 启动后自动获取定位：仅在 OOBE 已完成（非首次）且非模拟位置时进行；
    // 首次启动的权限请求移到 OOBE 完成后由 _requestLocationAfterOobe 触发。
    Future.delayed(const Duration(milliseconds: 900), () async {
      if (_disposed || !initialized) return;
      if (!oobeDone || useSimLocation) return;
      for (int i = 0; i < 15; i++) {
        final ok = await startTracking();
        if (ok) break;
        await Future.delayed(const Duration(seconds: 1));
      }
      _updateNotification();
    });
  }

  /// OOBE 完成后的定位引导：请求定位权限并启动定位，失败不阻塞（可手动再开）
  Future<void> _requestLocationAfterOobe() async {
    if (_disposed || useSimLocation) return;
    for (int i = 0; i < 6; i++) {
      final ok = await startTracking();
      if (ok) break;
      await Future.delayed(const Duration(seconds: 1));
    }
  }


  /// 判断并触发“是否自动上报位置”的首次询问。
  /// 由主界面在挂载后调用（防连接成功早于界面绑定的竞态漏弹）。
  /// 用户做出选择前不会置位，避免“弹不出来但已标记问过”的永久丢失。
  void maybeAskBeaconAuto() {
    if (_disposed) return;
    if (beaconAutoAsked) return;
    if (!connected) return;
    if (!beaconEnabled) return; // 用户已主动关过自动上报则不打扰
    onAskBeaconAuto?.call();
  }

  /// 用户已在询问弹窗中做出选择后调用（UI 层在选完时调用）
  void beaconAutoAnswered() {
    beaconAutoAsked = true;
    persist();
  }

  /// 切换开发者模式：开启后加载并模拟演示台站/数据包
  void setDevMode(bool v) {
    devMode = v;
    if (v) {
      final demo = makeStations();
      for (final s in demo) {
        if (!stations.any((x) => x.call == s.call)) {
          stations.add(s);
        }
        _demoCalls.add(s.call);
      }
      if (messages.isEmpty) {
        messages.addAll(makeMessages());
      }
    } else {
      stations.removeWhere((s) => _demoCalls.contains(s.call));
      _demoCalls.clear();
    }
    _bumpStationsVersion();
    persist();
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _simTimer?.cancel();
    _tickTimer?.cancel();
    _keepaliveTimer?.cancel();
    _reconnectTimer?.cancel();
    _rxNotifyTimer?.cancel();
    tick.dispose();
    _stationsCtrl.close();
    loc.stop();
    aprs.disconnect();
    // 退出前保存台站列表
    if (_stationsDirty) _saveStations();
    super.dispose();
  }

  int _reconnectAttempt = 0; // 连续失败次数（用于渐进重试）

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    // 渐进式重试：8s → 16s → 32s → 60s 封顶
    final backoff = [8, 16, 32, 60][_reconnectAttempt.clamp(0, 3)];
    _reconnectAttempt++;
    _reconnectTimer = Timer(Duration(seconds: backoff), () {
      if (_disposed || connected || _userDisconnected) return;
      _connect();
    });
  }

  Future<void> _connect() async {
    connecting = true;
    connInfo = '正在连接 ${aprs.server}:${aprs.port}…';
    _log(LogLevel.info, '连接', '正在连接 ${aprs.server}:${aprs.port}…');
    _notify();
    _updateNotification();
    aprs.callsign = myFullCall;
    aprs.filter = filterString;
    final ok = await aprs.connect();
    connecting = false;
    if (ok) {
      connected = true;
      _userDisconnected = false;
      _reconnectAttempt = 0; // 连接成功，重置重试计数
      passcodeInvalid = false; // 连接成功后重置，等待服务器验证
      _lastTx = DateTime.now();
      _lastFilter = aprs.filter; // 记录本次连接的过滤器
      connInfo = '已连接 · $myCall 在线';
      _log(LogLevel.info, '连接', '已连接 · $myCall 在线 (过滤: $filterString)');
      _flushPendingTx();
      // 连接成功即发一次身份状态帧（APRS 惯例：上报在线/客户端标识）
      aprs.send('$myFullCall>APALOC,TCPIP*:>APRSLocus CONNECT');
      // 连接成功：若主界面已就绪且尚未问过“是否自动上报”，延迟触发询问。
      // 不在此置位 beaconAutoAsked —— 用户做出选择后才记位，避免漏弹后永久丢失。
      if (!beaconAutoAsked && beaconEnabled) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (_disposed) return;
          maybeAskBeaconAuto();
        });
      }
    } else {
      connected = false;
      final backoff = [8, 16, 32, 60][_reconnectAttempt.clamp(0, 3)];
      connInfo = '连接失败 · ${backoff}s 后重试…';
      _log(LogLevel.error, '连接', '连接失败，${backoff} 秒后自动重试');
    }
    _notify();
    _updateNotification();
    // 失败继续自动重连
    if (!connected && !_userDisconnected) _scheduleReconnect();
  }

  bool _disposed = false;

  bool get isDisposed => _disposed;

  /// 安全通知：dispose 后不再触发
  void _notify() {
    if (_disposed) return;
    super.notifyListeners();
  }

  // 收包路径节流通知：APRS-IS 数据洪峰时每秒可能几十个包，
  // 每包一次全 UI 重建会卡顿 → 250ms 内合并成一次重建（台站多时降频保流畅）
  bool _rxNotifyPending = false;
  Timer? _rxNotifyTimer;

  void _notifyRx() {
    if (_disposed) return;
    if (_rxNotifyPending) return;
    _rxNotifyPending = true;
    _rxNotifyTimer?.cancel();
    _rxNotifyTimer = Timer(const Duration(milliseconds: 250), () {
      _rxNotifyPending = false;
      if (!_disposed) super.notifyListeners();
    });
  }

  /// 台站数据版本：位置新增/变化时自增，地图据此立即刷新标记
  int stationsVersion = 0;

  /// 台站数据流：每次台站版本推进时推送新版本号。
  /// 台站列表页等只关心台站数据的页面订阅此流，避免被全量 AppState 通知反复重建。
  /// 异步投递（非 sync）：add() 不会在调用栈中同步触发监听者，杜绝重入类异常。
  final StreamController<int> _stationsCtrl = StreamController<int>.broadcast();
  Stream<int> get stationsStream => _stationsCtrl.stream;

  /// 台站版本推进的唯一出口：自增版本并向流推送（台站列表/地图据此刷新）
  /// 只有存在监听者（台站页已挂载）时才 add，且异常不外抛，
  /// 避免 OOBE 等无监听场景下 add() 的任何重入/异常导致界面卡死。
  void _bumpStationsVersion() {
    stationsVersion++;
    try {
      if (!_stationsCtrl.isClosed && _stationsCtrl.hasListener) {
        _stationsCtrl.add(stationsVersion);
      }
    } catch (_) {}
  }

  int _statusSig = 0;
  bool _statusSigInit = false;

  /// 台站“有效状态”签名：仅当某个台站状态翻转（在线/离线/移动/静止）时变化，
  /// 用于每秒 tick 低成本地发现状态变化并推进 stationsVersion。
  int _computeStatusSig() {
    var h = 0;
    for (final s in stations) {
      h = h * 31 + s.effectiveStatus.index;
    }
    return h;
  }

  /// 若台站在线/离线/移动/静止状态发生变化，推进 stationsVersion（触发地图/列表刷新）
  /// 返回是否发生变化（变化时调用方应 _notify()）
  bool _bumpStatusVersionIfChanged() {
    final sig = _computeStatusSig();
    if (!_statusSigInit) {
      _statusSigInit = true;
      _statusSig = sig;
      return false;
    }
    if (sig != _statusSig) {
      _statusSig = sig;
      _bumpStationsVersion();
      return true;
    }
    return false;
  }

  // 台站统计缓存：按 stationsVersion 惰性重建，
  // 避免每次重建/每秒 tick 对几百个台站做多次全量扫描
  int _statVersion = -1;
  int _onlineCount = 0, _movingCount = 0, _stoppedCount = 0;
  void _refreshStats() {
    if (_statVersion == stationsVersion) return;
    _statVersion = stationsVersion;
    var o = 0, m = 0, s = 0;
    for (final x in stations) {
      switch (x.effectiveStatus) {
        case St.moving:
          m++;
          o++;
          break;
        case St.stopped:
          s++;
          o++;
          break;
        case St.online:
          o++;
          break;
        default:
          break; // offline 不计入在线
      }
    }
    _onlineCount = o;
    _movingCount = m;
    _stoppedCount = s;
  }

  // 信标定时器（每秒检查）
  int get online {
    _refreshStats();
    return _onlineCount;
  }

  int get moving {
    _refreshStats();
    return _movingCount;
  }

  int get stoppedCount {
    _refreshStats();
    return _stoppedCount;
  }

  // ─── 定位 ───
  Future<bool> startTracking() async {
    if (useSimLocation) {
      locStatus = '模拟位置';
      _notify();
      return true;
    }
    final ok = await loc.start();
    if (!ok) {
      locStatus = '定位失败';
      _log(LogLevel.error, '定位', '定位启动失败');
      _notify();
    } else {
      _log(LogLevel.info, '定位', '定位服务已启动');
    }
    return ok;
  }

  void stopTracking() {
    loc.stop();
    myHasFix = false;
    locStatus = '定位已停止';
    _log(LogLevel.info, '定位', '定位已停止');
    _notify();
  }

  void _onFix(
    double lat,
    double lng,
    double alt,
    double speed,
    double bearing,
  ) {
    if (_disposed) return;
    if (useSimLocation) return; // 模拟位置模式下忽略 GPS 数据
    final first = !myHasFix;
    myLat = lat;
    myLng = lng;
    myAlt = alt;
    myHasFix = true;
    // 速度 m/s → km/h；方位角度。
    // 静止时 GPS 也返回 speed=0/bearing=0，正常上报（000/000 表示静止）
    mySpeed = speed * 3.6;
    if (bearing >= 0) myCourse = bearing;
    locStatus = '已定位';
    // 记录我的轨迹（限最近 200 点，间隔>20m 才记录避免冗余）
    final last = myTrack.isEmpty ? null : myTrack.last;
    if (last == null || haversine(last.lat, last.lng, lat, lng) > 0.02) {
      myTrack.add(TrackPt(lat, lng, DateTime.now()));
      if (myTrack.length > 200) {
        myTrack.removeRange(0, myTrack.length - 200);
      }
    }
    // 过滤中心跟随我的位置
    if (filterFollow) {
      filterLat = lat;
      filterLng = lng;
    }
    if (first) {
      _log(
        LogLevel.info,
        '定位',
        '首次定位 ${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)} 网格 $myGrid',
      );
    }
    _notify();
    _updateNotification();
    // 定期刷新电量（每次定位都取一次，便于上报）
    if (beaconIncludeBattery) {
      loc.getBatteryLevel().then((v) {
        if (v >= 0) _battery = v;
      });
    }
  }

  // ─── 信标（定位上传） ───
  /// 手动“立即上报”：无论自动信标是否开启都会发送一次
  void sendBeacon() {
    _sendBeaconNow(force: true);
  }

  /// [force] 为 true 时忽略信标总开关（仅手动上报用）；
  /// 自动定时上报调用时不带 force，受 beaconEnabled 门控。
  void _sendBeaconNow({bool force = false}) {
    if (!myHasFix) return;
    if (!force && !beaconEnabled) return;
    final lat = myLat!;
    final lng = myLng!;
    final raw = AprsFmt.position(
      myFullCall,
      lat,
      lng,
      mySymbol,
      comment: _beaconComment(),
      path: 'APALOC,TCPIP*',
    );
    _pushPacket(
      Packet(
        raw,
        myFullCall,
        'APRS',
        'position',
        DateTime.now(),
        info: '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)} · 手动上报',
      ),
    );
    if (connected) {
      aprs.send(raw);
      _lastTx = DateTime.now();
      connInfo = '已连接 · 位置已上传 ($myCall)';
    } else {
      connInfo = '未连接 · 位置已上报(模拟)';
    }
    beaconsSent++;
    _lastBeacon = DateTime.now();
    _log(
      LogLevel.info,
      '信标',
      '已上报位置 网格 $myGrid'
          '${mySpeed != null && mySpeed! > 0 ? ' ${mySpeed!.toStringAsFixed(0)}km/h' : ''}'
          '${connected ? ' · 已发送' : ' · 未连接，仅本地记录'}',
    );
    _notify();
    _updateNotification();
  }

  /// 组装信标备注：高度(/A=英尺) + 速度/方位角 + 电量 + 自定义备注 + 版本号
  String _beaconComment() {
    final parts = <String>[];
    // 高度：APRS 标准 /A=ffffff（英尺）
    if (myAlt != null && myAlt! >= 0) {
      final ft = (myAlt! / 0.3048).round().clamp(0, 999999);
      parts.add('/A=${ft.toString().padLeft(6, '0')}');
    }
    // 标准 course/speed 格式：ddd/sss（度/节，各3位）
    if (beaconIncludeSpeed &&
        beaconIncludeCourse &&
        myCourse != null &&
        mySpeed != null) {
      final crs = myCourse!.round().clamp(0, 359).toString().padLeft(3, '0');
      final kt = (mySpeed! * 0.539957)
          .round()
          .clamp(0, 999)
          .toString()
          .padLeft(3, '0');
      parts.add('$crs/$kt');
    }
    if (beaconIncludeBattery && _battery >= 0) {
      parts.add('Bat:$_battery%');
    }
    if (myComment.trim().isNotEmpty) {
      parts.add(myComment.trim());
    }
    // 版本号始终追加在末尾
    parts.add('APRSlocus v$appVersion');
    return parts.join(' ');
  }

  // ─── 连接 ───
  Future<void> reconnect() async {
    _userDisconnected = false;
    _reconnectTimer?.cancel();
    _lastFilter = ''; // 重置，确保下次连接后更新
    aprs.disconnect();
    connected = false;
    _notify();
    _updateNotification();
    await _connect();
  }

  Future<void> toggleConnect() async {
    if (connected) {
      _userDisconnected = true;
      _reconnectAttempt = 0; // 手动断开，重置重试计数
      _reconnectTimer?.cancel();
      aprs.disconnect();
      connected = false;
      connInfo = '未连接 · 已手动断开';
      _notify();
      _updateNotification();
      return;
    }
    _userDisconnected = false;
    await _connect();
  }

  void _onAprsLine(String line) {
    // 简单解析收到的 APRS 帧
    try {
      if (line.startsWith('#')) {
        // 服务器握手响应：# logresp {call} verified / unverified
        final lm = RegExp(
          r'#\s*logresp[:\s]*(\S+)\s+(unverified|verified)',
          caseSensitive: false,
        ).firstMatch(line);
        if (lm != null) {
          final status = lm.group(2)!.toLowerCase();
          if (status == 'unverified') {
            passcodeInvalid = true;
            _log(LogLevel.warn, '连接', '登录未验证：passcode 可能错误（unverified）');
            if (connected) {
              connInfo = '已连接 · 未验证（passcode 可能错误）';
              _notify();
              _updateNotification();
            }
          } else {
            passcodeInvalid = false;
            _log(LogLevel.info, '连接', '登录已通过服务器验证');
          }
        }
        return; // 注释/服务器消息
      }
      final sep = line.indexOf('>');
      final bodySep = line.indexOf(':');
      if (sep < 0 || bodySep < 0) return;
      final src = line.substring(0, sep).trim();
      final body = line.substring(bodySep + 1);
      // 提取路径（src>dest,digi1,digi2:body），识别多跳转发链路
      String path = '';
      String toCall = ''; // 目的呼号（路径首段，APxxxx），设备识别依据
      if (bodySep > sep + 1) {
        path = line.substring(sep + 1, bodySep).trim();
        final first = path.split(RegExp(r'[, ]')).first.trim().toUpperCase();
        // APRS/TCPIP*/BEACON 等通用目的呼号无设备识别价值，不入库
        if (first.isNotEmpty &&
            first != 'APRS' &&
            first != 'TCPIP*' &&
            first != 'BEACON' &&
            first != 'MAIL') {
          toCall = first;
        }
      }
      var type = 'position';
      var info = body;
      if (body.startsWith(':')) type = 'message';
      if (body.startsWith('@') || body.startsWith('=')) type = 'position';
      if (body.startsWith('_')) type = 'weather';
      if (body.startsWith('>')) type = 'status';
      // 多跳转发识别：记录转发路径（如 WIDE1-1,WIDE2-1 或数字中继）
      if (path.isNotEmpty &&
          path.toUpperCase() != 'APRS' &&
          path.toUpperCase() != 'TCPIP*') {
        // 转发路径作为附加信息展示，不覆盖原 info
        info = '$info  ·  [via $path]';
      }

      // FMO 状态包：>地区,状态,在线/峰值,描述（路径含 APFMO）
      if (body.startsWith('>') && line.contains('APFMO')) {
        final fmo = _parseFmoStatus(body);
        if (fmo != null) {
          _upsertFmoStatus(src, fmo);
          info = fmo.entries.map((e) => '${e.key}:${e.value}').join(' · ');
        }
      }

      // 收到的 APRS 消息 → 仅处理发给本机的 + 自动回 ack
      if (body.startsWith(':')) {
        final parsed = _parseIncomingMessage(src, body);
        if (parsed != null) {
          info = parsed.$1;
          _log(LogLevel.info, '消息', '收到 $src：${_trunc(parsed.$1)}');
          // 应用在后台时发系统通知提醒；前台由消息页展示
          final state = WidgetsBinding.instance.lifecycleState;
          if (state == AppLifecycleState.paused ||
              state == AppLifecycleState.inactive) {
            // 判断是否是群聊消息（addressee 是群呼号）
            String? groupName;
            final colon = body.indexOf(':');
            if (colon > 1) {
              final addressee = body.substring(1, colon).trim();
              for (final g in chatGroups) {
                if (g.groupCall.toUpperCase() == addressee.toUpperCase()) {
                  groupName = g.name;
                  break;
                }
              }
            }
            if (groupName != null) {
              loc.showMessageNotification('群·$groupName', parsed.$1);
            } else {
              loc.showMessageNotification(src, parsed.$1);
            }
          }
          // 自动 ack（标准：{id 需要 ack，{id_ 不需要 ack）
          final ackId = parsed.$2;
          if (ackId != null && connected) {
            // ack 包不带消息 ID，防止对方无限 ack 我们的 ack
            final ack = '$myFullCall>APRS,TCPIP*::${src.padRight(9)}:ack$ackId';
            aprs.send(ack);
            _pushPacket(
              Packet(
                ack,
                myFullCall,
                'APRS',
                'message',
                DateTime.now(),
                info: '自动 ack → $src ($ackId)',
              ),
            );
          }
        }
      }

      // 解码位置数据包 → 更新/添加台站到地图
      // 注意：呼号可带 ssid 后缀（如 BV2AAA-9），必须解析
      if (body.startsWith('!') ||
          body.startsWith('=') ||
          body.startsWith('@')) {
        final p = parseAprsPosition(body);
        if (p != null) {
          _upsertStation(
            src,
            p,
            raw: line,
            path: path.isEmpty ? null : path,
            toCall: toCall,
          );
          info =
              '${p.lat.toStringAsFixed(4)}, ${p.lng.toStringAsFixed(4)}'
              '${p.speed != null ? ' · ${p.speed!.toStringAsFixed(0)}km/h' : ''}'
              '${path.isNotEmpty ? ' · [via $path]' : ''}';
        } else {
          info = '位置包(未解析: 压缩格式或异常)';
          _log(LogLevel.debug, '解析', '位置包解析失败: $src ${_trunc(body)}');
        }
      }

      _pushPacket(
        Packet(
          line.trim(),
          src,
          'APRS',
          type,
          DateTime.now(),
          info: info.length > 80 ? info.substring(0, 80) : info,
        ),
      );
    } catch (e) {
      _log(LogLevel.debug, '解析', '数据包处理异常: $e');
    }
  }

  /// 解析收到的 APRS 消息体 `:TO  :text{id_`
  /// 返回 (消息文本, 需要 ack 的消息编号)；ack 回复返回 null（不加入会话）
  (String, String?)? _parseIncomingMessage(String src, String body) {
    final rest = body.substring(1); // 去掉开头的 ':'
    final colon = rest.indexOf(':');
    if (colon < 0) return null;
    // 提取收件人（9 字符填充）：`:TO  :text{id`
    final addressee = rest.substring(0, colon).trim();
    var text = rest.substring(colon + 1);
    // 判断消息类型：私信 or 群聊
    String? groupId;
    bool isGroupMsg = false;
    if (addressee == myFullCall) {
      // 私信：发给我的
      isGroupMsg = false;
    } else {
      // 检查是否是某个群聊的群呼号
      for (final g in chatGroups) {
        if (g.groupCall.toUpperCase() == addressee.toUpperCase()) {
          groupId = g.id;
          isGroupMsg = true;
          _log(LogLevel.debug, '消息', '匹配群聊: $addressee → ${g.name}');
          break;
        }
      }
      if (!isGroupMsg) return null; // 不是发给我的，也不是群呼号，忽略
    }
    // 提取消息编号与 ack 标记：`{NNNN` 或 `{NNNN_`
    String? ackId;
    final brace = text.indexOf('{');
    if (brace >= 0) {
      final suffix = text.substring(brace + 1);
      text = text.substring(0, brace).trim();
      final id = suffix.length >= 4 ? suffix.substring(0, 4) : suffix;
      final needAck = !(suffix.length >= 5 && suffix[4] == '_');
      if (needAck) ackId = id;
    }
    text = text.trim();
    if (text.isEmpty) return null;
    // 对方回复的 ack
    if (text.startsWith('ack')) {
      final ackedId = text.substring(3).trim();
      for (final m in messages) {
        if (m.sent && m.id == ackedId) m.acked = true;
      }
      _saveMessages();
      _notify();
      return null;
    }
    // ─── 协议消息处理 ───
    if (isGroupMsg && groupId != null) {
      final handled = _handleGroupProtocol(src, groupId, text);
      if (handled) return null; // 协议消息不进入聊天列表
    }
    // 处理私信协议（INVITE/JOIN_CONFIRM 等）
    if (!isGroupMsg) {
      final handled = _handlePrivateProtocol(src, text);
      if (handled) return null;
    }
    // ─── 加入会话列表 ───
    final msg = AprsMsg(
      src,
      isGroupMsg ? addressee : myFullCall,
      text,
      DateTime.now(),
      groupId: groupId,
    );
    messages.insert(0, msg);
    if (messages.length > 500) messages.removeLast();
    // 群聊：记录活跃成员
    if (isGroupMsg && groupId != null) {
      final g = chatGroups.where((g) => g.id == groupId).firstOrNull;
      if (g != null && !g.isOwner(src)) {
        g.activeMembers.add(src.toUpperCase());
        _saveChatGroups();
      }
    }
    if (!isGroupMsg) {
      unreadMessages++;
    }
    _saveMessages();
    onNewMessage?.call(src, text, groupId);
    return (text, ackId);
  }

  // ─── 群聊协议消息处理 ───
  /// 向群聊插入一条系统消息（不发送网络包，仅本地展示）
  void _addGroupSystemMsg(String groupId, String text) {
    final g = chatGroups.where((g) => g.id == groupId).firstOrNull;
    if (g == null) return;
    messages.insert(
      0,
      AprsMsg(
        '系统',
        g.groupCall,
        text,
        DateTime.now(),
        groupId: groupId,
        system: true,
      ),
    );
    if (messages.length > 500) messages.removeLast();
    _saveMessages();
    _notify();
  }

  bool _handleGroupProtocol(String src, String groupId, String text) {
    final g = chatGroups.where((g) => g.id == groupId).firstOrNull;
    if (g == null) return false;
    final upper = text.toUpperCase().trim();
    // 成员发送的 JOIN 声明
    if (upper.startsWith('【JOIN】') || upper.startsWith('[JOIN]')) {
      final joiner = text.substring(text.indexOf('】') + 1).trim();
      if (joiner.isNotEmpty) {
        g.activeMembers.add(joiner.toUpperCase());
        _saveChatGroups();
        _log(LogLevel.info, '群聊', '${g.name}：${joiner} 加入');
        _addGroupSystemMsg(groupId, '$joiner 加入了群聊');
      }
      return true;
    }
    // 成员发送的 LEAVE 声明
    if (upper.startsWith('【LEAVE】') || upper.startsWith('[LEAVE]')) {
      final leaver = text.substring(text.indexOf('】') + 1).trim();
      if (leaver.isNotEmpty) {
        g.activeMembers.remove(leaver.toUpperCase());
        _saveChatGroups();
        _log(LogLevel.info, '群聊', '${g.name}：${leaver} 离开');
        _addGroupSystemMsg(groupId, '$leaver 离开了群聊');
      }
      return true;
    }
    // 普通群聊消息：不是协议消息，不拦截
    return false;
  }

  // ─── 私信协议消息处理 ───
  bool _handlePrivateProtocol(String src, String text) {
    final upper = text.toUpperCase().trim();
    // INVITE {群呼号} {群名}
    if (upper.startsWith('INVITE ')) {
      final parts = text.substring(7).trim().split(RegExp(r'\s+'));
      if (parts.length >= 2) {
        final groupCall = parts[0].toUpperCase();
        final name = parts.sublist(1).join(' ');
        _processInvite(src, groupCall, name);
      }
      return true;
    }
    // JOIN_CONFIRM {群呼号}
    if (upper.startsWith('JOIN_CONFIRM ')) {
      final groupCall = upper.substring(13).trim();
      _processJoinConfirm(src, groupCall);
      return true;
    }
    // DECLINE {群呼号}
    if (upper.startsWith('DECLINE ')) {
      final groupCall = upper.substring(8).trim();
      _processDecline(src, groupCall);
      return true;
    }
    // LEFT {群呼号}
    if (upper.startsWith('LEFT ')) {
      final groupCall = upper.substring(5).trim();
      _processMemberLeft(src, groupCall);
      return true;
    }
    // JOIN_REQ {群呼号}（成员主动申请）
    if (upper.startsWith('JOIN_REQ ')) {
      final groupCall = upper.substring(9).trim();
      _processJoinReq(src, groupCall);
      return true;
    }
    // REMIND / REINVITE — 收到后不做特殊处理，只是普通消息
    // JOINED_ACK / LEAVE_ACK — 确认消息，不做特殊处理
    return false;
  }

  /// 处理邀请（我是成员，收到群主的邀请）
  void _processInvite(String from, String groupCall, String name) {
    // 查找是否已有此群
    var g = chatGroups
        .where((g) => g.groupCall.toUpperCase() == groupCall.toUpperCase())
        .firstOrNull;
    if (g == null) {
      // 创建本地群组记录（我是成员，不是群主）
      g = createGroup(
        name,
        {from, myCall}, // 群主 + 自己作为初始成员
        groupCall: groupCall,
        owner: from,
      );
      // 邀请者是群主，标记为已加入；自己视为已加入
      g.memberStatus[from.toUpperCase()] = GroupMemberStatus.joined;
      g.memberStatus[myCall.toUpperCase()] = GroupMemberStatus.joined;
      _saveChatGroups();
    }
    _log(LogLevel.info, '群聊', '收到 ${from} 的邀请：${g.name}');
    // 系统通知（前后台都提示邀请）
    loc.showGroupNotification('群聊邀请', '$from 邀请你加入「$name」');
    // 触发 UI 弹窗
    onInviteReceived?.call(from, groupCall, name);
    _notify();
  }

  /// 处理加入确认（我是群主，收到成员的确认）
  void _processJoinConfirm(String from, String groupCall) {
    final g = chatGroups
        .where((g) => g.groupCall.toUpperCase() == groupCall.toUpperCase())
        .firstOrNull;
    if (g != null && g.isOwner(myCall)) {
      g.memberStatus[from.toUpperCase()] = GroupMemberStatus.joined;
      g.activeMembers.add(from.toUpperCase());
      _saveChatGroups();
      _log(LogLevel.info, '群聊', '${g.name}：${from} 确认加入');
      _addGroupSystemMsg(g.id, '$from 加入了群聊');
      onGroupEvent?.call(groupCall, '${from} 已加入群组');
      loc.showGroupNotification('群聊·${g.name}', '$from 加入了群组');
      _notify();
    }
  }

  /// 处理拒绝（我是群主，收到成员的拒绝）
  void _processDecline(String from, String groupCall) {
    final g = chatGroups
        .where((g) => g.groupCall.toUpperCase() == groupCall.toUpperCase())
        .firstOrNull;
    if (g != null && g.isOwner(myCall)) {
      g.memberStatus[from.toUpperCase()] = GroupMemberStatus.declined;
      _saveChatGroups();
      _log(LogLevel.info, '群聊', '${g.name}：${from} 拒绝加入');
      _addGroupSystemMsg(g.id, '$from 拒绝了邀请');
      onGroupEvent?.call(groupCall, '${from} 拒绝了邀请');
      loc.showGroupNotification('群聊·${g.name}', '$from 拒绝了邀请');
      _notify();
    }
  }

  /// 处理成员离开（我是群主，收到成员的离开声明）
  void _processMemberLeft(String from, String groupCall) {
    final g = chatGroups
        .where((g) => g.groupCall.toUpperCase() == groupCall.toUpperCase())
        .firstOrNull;
    if (g != null && g.isOwner(myCall)) {
      g.memberStatus[from.toUpperCase()] = GroupMemberStatus.left;
      g.activeMembers.remove(from.toUpperCase());
      _saveChatGroups();
      _log(LogLevel.info, '群聊', '${g.name}：${from} 离开');
      _addGroupSystemMsg(g.id, '$from 离开了群聊');
      onGroupEvent?.call(groupCall, '${from} 已退出群组');
      loc.showGroupNotification('群聊·${g.name}', '$from 已退出群组');
      _notify();
    }
  }

  /// 处理主动申请（我是群主，收到成员的加入申请）
  void _processJoinReq(String from, String groupCall) {
    final g = chatGroups
        .where((g) => g.groupCall.toUpperCase() == groupCall.toUpperCase())
        .firstOrNull;
    if (g != null && g.isOwner(myCall)) {
      // 自动加入期望列表，状态设为 pending
      g.memberStatus.putIfAbsent(
        from.toUpperCase(),
        () => GroupMemberStatus.pending,
      );
      _saveChatGroups();
      _log(LogLevel.info, '群聊', '${g.name}：${from} 申请加入');
      _addGroupSystemMsg(g.id, '$from 申请加入群聊');
      _notify();
    }
  }

  /// 待合并的 FMO 状态信息（位置包到达前先缓存）
  final Map<String, Map<String, String>> _pendingFmo = {};

  /// 解析 FMO 状态包体 `>地区,状态,在线/峰值:29/54,描述`
  Map<String, String>? _parseFmoStatus(String body) {
    final text = body.substring(1).trim();
    if (text.isEmpty) return null;
    final parts = text.split(',').map((e) => e.trim()).toList();
    final info = <String, String>{};
    if (parts.isNotEmpty && parts[0].isNotEmpty) info['地区'] = parts[0];
    if (parts.length > 1 && parts[1].isNotEmpty) info['状态'] = parts[1];
    if (parts.length > 2 && parts[2].isNotEmpty) {
      final m = RegExp(r'(\d+)/(\d+)').firstMatch(parts[2]);
      if (m != null) {
        info['在线'] = m.group(1)!;
        info['峰值'] = m.group(2)!;
      }
    }
    if (parts.length > 3 && parts[3].isNotEmpty) info['描述'] = parts[3];
    return info;
  }

  /// 从 FMO 位置包备注提取结构化字段
  void _parseFmoPosInfo(String comment, Map<String, String> info) {
    final vm = RegExp(r'FMO-V(\d)').firstMatch(comment);
    if (vm != null) info['版本'] = 'FMO-V${vm.group(1)}';
    final cn = RegExp(r',CN,([^,]+)').firstMatch(comment);
    if (cn != null) info['地区'] = cn.group(1)!.trim();
    final ip = RegExp(r'\d{1,3}(?:\.\d{1,3}){3}').firstMatch(comment);
    if (ip != null) {
      final pm = RegExp(r'P(\d+)').firstMatch(comment);
      info['服务器'] = pm != null ? '${ip.group(0)}:${pm.group(1)}' : ip.group(0)!;
    }
    // 接收范围：F500KM / R500 / 覆盖范围500 等常见格式
    final rng =
        RegExp(
          r'[FR](\d{2,4})\s*KM',
          caseSensitive: false,
        ).firstMatch(comment) ??
        RegExp(r'接收范围[：:]\s*(\d{2,4})').firstMatch(comment);
    if (rng != null) info['接收范围'] = '${rng.group(1)}km';
    final um = RegExp(r'U(\d+)/(\d+)').firstMatch(comment);
    if (um != null) info['用户'] = '${um.group(1)}/${um.group(2)}';
  }

  /// 记录 FMO 状态信息（台站不存在时暂存，等位置包到达再合并）
  void _upsertFmoStatus(String call, Map<String, String> info) {
    final idx = stations.indexWhere((s) => s.call == call);
    if (idx < 0) {
      _pendingFmo[call] = info;
      return;
    }
    final s = stations[idx];
    s.lastHeard = DateTime.now();
    s.fmo = {...?s.fmo, ...info};
    if (info['地区'] != null) s.comment = info['地区'];
    stations[idx] = s;
    _bumpStationsVersion();
    _notifyRx();
  }

  /// 将解码后的位置更新/添加到台站列表（地图/列表实时可见）
  /// raw 为原始数据包（用于识别 FMO 等特殊台站字段）
  void _upsertStation(String call, ParsedPos p,
      {String? raw, String? path, String? toCall}) {
    // 国家/地区接收筛选：未选择国家时不限制；
    // 开启「其他台站」时放行特殊类型（中继/气象/FMO/APRSlocus）；
    // 否则仅保留匹配国家前缀的台站（收藏/手动台站除外）
    if (receiveCountries.isNotEmpty) {
      final matched = _matchReceiveFilter(call);
      final special =
          receiveOthers &&
          ((raw?.toUpperCase().contains('APFMO') ?? false) ||
              (raw?.toUpperCase().contains('APRSLOCUS') ?? false) ||
              (raw?.toUpperCase().contains('APALOC') ?? false) ||
              p.symbol == 'i' ||
              p.symbol == 'R' ||
              p.symbol == '#' ||
              p.symbol == 'W' ||
              p.symbol == 'w');
      if (!matched && !special) {
        final existing = stations.indexWhere((s) => s.call == call);
        if (existing >= 0 &&
            (stations[existing].favorite || stations[existing].manual)) {
          // 收藏/手动台站保留更新
        } else {
          return;
        }
      }
    }
    // FMO 台站识别：看数据包字段（路径 APFMO / 备注 FMO-V4、STATION、CERT: / 符号 i）
    final isFmo =
        (raw?.contains('APFMO') ?? false) ||
        p.symbol == 'i' ||
        (p.comment?.contains('FMO') ?? false) ||
        (p.comment?.contains('CERT:') ?? false) ||
        (p.comment?.contains('STATION') ?? false);
    // APRSlocus 台站识别：路径 APALOC（专用标识）优先，兼容备注含 APRSLOCUS/APOLOCUS
    final rawUp = raw?.toUpperCase() ?? '';
    final isAprslocus =
        rawUp.contains('APALOC') ||
        rawUp.contains('APOLOCUS') ||
        rawUp.contains('APRSLOCUS') ||
        (p.comment?.toUpperCase().contains('APRSLOCUS') ?? false) ||
        (p.comment?.toUpperCase().contains('APOLOCUS') ?? false);
    // 保留台站原始上报符号/符号表（不因识别为 FMO 而改写），
    // 使图标与其它 APRS 地图一致；FMO 分类由 fmo 结构化字段决定
    final symbol = p.symbol;
    final symbolTable = p.symbolTable;
    final comment = isFmo ? _cleanFmoComment(p.comment) : _trunc(p.comment);
    // APRSlocus 专属信息（版本等）
    Map<String, String>? apInfo;
    if (isAprslocus && p.comment != null) {
      apInfo = <String, String>{};
      // 版本：APRSlocus v1.2.6
      final vm = RegExp(
        r'APRSLOCUS\s*v?(\d[\d.]*)',
        caseSensitive: false,
      ).firstMatch(p.comment!);
      if (vm != null) apInfo['版本'] = 'v${vm.group(1)}';
      apInfo['软件'] = 'APRSlocus';
      // 是否有高度/速度等
      if (p.alt != null) apInfo['高度'] = '${p.alt!.toStringAsFixed(0)}m';
      if (p.speed != null) apInfo['速度'] = '${p.speed!.toStringAsFixed(0)}km/h';
      // 手机电量：Bat:XX%
      final bm = RegExp(
        r'Bat:(\d+)%',
        caseSensitive: false,
      ).firstMatch(p.comment!);
      if (bm != null) apInfo['电量'] = '${bm.group(1)}%';
    }
    // FMO 位置包结构化字段 + 合并此前缓存的状态信息
    Map<String, String>? fmoInfo;
    if (isFmo && p.comment != null) {
      fmoInfo = <String, String>{};
      _parseFmoPosInfo(p.comment!, fmoInfo);
      final pending = _pendingFmo.remove(call);
      if (pending != null) fmoInfo.addAll(pending);
      // 无任何 FMO 信息也至少保留标记，供 FMO 分类/过滤识别
      if (fmoInfo.isEmpty) fmoInfo['类型'] = 'FMO';
    } else if (_pendingFmo.containsKey(call)) {
      fmoInfo = _pendingFmo.remove(call);
    } else if (isFmo) {
      fmoInfo = <String, String>{'类型': 'FMO'};
    }
    final idx = stations.indexWhere((s) => s.call == call);
    final now = DateTime.now();
    if (idx >= 0) {
      final s = stations[idx];
      final moved =
          (s.lat - p.lat).abs() > 1e-6 || (s.lng - p.lng).abs() > 1e-6;
      // 记录修改前的“地图相关”字段，用于判断是否推进台站版本
      final oldStatus = s.status;
      final oldSym = s.symbol;
      final oldSymT = s.symbolTable;
      s.lat = p.lat;
      s.lng = p.lng;
      s.lastHeard = now;
      s.symbolTable = symbolTable;
      s.symbol = symbol;
      if (path != null) s.path = path;
      if (toCall != null && toCall.isNotEmpty) s.toCall = toCall;
      if (fmoInfo != null) s.fmo = {...?s.fmo, ...fmoInfo};
      if (apInfo != null) s.aprslocus = {...?s.aprslocus, ...apInfo};
      if (comment != null) s.comment = comment;
      if (p.speed != null) s.speed = p.speed;
      if (p.course != null) s.course = p.course;
      if (p.alt != null) s.alt = p.alt;
      // 根据速度自动判断移动/停止状态
      if (s.status == St.offline) s.status = St.online;
      if (p.speed != null) {
        s.status = p.speed! > 1.0 ? St.moving : St.stopped;
      }
      if (s.track.isEmpty ||
          haversine(s.track.last.lat, s.track.last.lng, p.lat, p.lng) > 0.02) {
        s.track = [...s.track, TrackPt(p.lat, p.lng, now)];
        if (s.track.length > 60) s.track = s.track.sublist(s.track.length - 60);
      }
      // 记录速度/高度遥测采样（每次位置包都记，供详情页变化图表）
      s.telemetry = [
        ...s.telemetry,
        TelemetryPt(now, speed: p.speed, alt: p.alt),
      ];
      if (s.telemetry.length > 200) {
        s.telemetry = s.telemetry.sublist(s.telemetry.length - 200);
      }
      stations[idx] = s;
      // 地图相关字段变化（位置/状态/符号）才推进版本，触发地图标记重建；
      // 仅 lastHeard/速度/备注变化不会触发整片标记重建
      if (moved ||
          s.status != oldStatus ||
          s.symbol != oldSym ||
          s.symbolTable != oldSymT) {
        _bumpStationsVersion();
      }
      _stationsDirty = true;
    } else {
      // 新台站：容量满时移除最旧的（优先保留收藏/手动台站）
      if (stations.length >= maxStations) {
        // 排序：收藏/手动台站排前面，普通台站按最近活跃（新）在前
        // 删除时跳过所有收藏台站，从尾部删除最旧的普通台站
        stations.sort((a, b) {
          final aKeep = a.favorite || a.manual;
          final bKeep = b.favorite || b.manual;
          if (aKeep != bKeep) return aKeep ? -1 : 1; // 收藏/手动排前
          return b.lastHeard.compareTo(a.lastHeard); // 新的在前
        });
        final keepers = stations.where((s) => s.favorite || s.manual).length;
        final needRemove = stations.length - (maxStations - 1);
        // 仅删除可删的普通台站（不删收藏）
        final canRemove = stations.length - keepers;
        if (needRemove > 0 && canRemove > 0) {
          final doRemove = needRemove < canRemove ? needRemove : canRemove;
          stations.removeRange(stations.length - doRemove, stations.length);
        }
      }
      _bumpStationsVersion();
      stations.add(
        Station(
          call: call,
          symbol: symbol,
          symbolTable: symbolTable,
          lat: p.lat,
          lng: p.lng,
          alt: p.alt,
          speed: p.speed,
          course: p.course,
          comment: comment ?? '在线',
          lastHeard: now,
          status: St.online,
          track: [TrackPt(p.lat, p.lng, now)],
          telemetry: [TelemetryPt(now, speed: p.speed, alt: p.alt)],
          fmo: fmoInfo,
          aprslocus: apInfo,
          path: path,
          toCall: toCall,
        ),
      );
      _stationsDirty = true;
    }
    _notifyRx();
    // 台站有变更：节流保存（最多每 10 秒写一次磁盘）
    if (_stationsDirty) {
      _stationsDirty = false;
      _scheduleStationsSave();
    }
  }

  DateTime? _lastStationsSave;
  bool _saveQueued = false;

  /// 节流保存台站列表：避免高频收包时频繁写磁盘
  void _scheduleStationsSave() {
    final now = DateTime.now();
    if (_lastStationsSave == null ||
        now.difference(_lastStationsSave!).inSeconds >= 10) {
      _lastStationsSave = now;
      _saveStations();
    } else if (!_saveQueued) {
      _saveQueued = true;
      Future.delayed(const Duration(seconds: 10), () {
        _saveQueued = false;
        if (!_disposed) _saveStations();
      });
    }
  }

  /// 备注截断（避免超长 FMO 证书数据撑爆界面）
  String? _trunc(String? c) {
    if (c == null) return null;
    return c.length > 60 ? '${c.substring(0, 57)}…' : c;
  }

  /// 提取 FMO 台站可读备注：优先 ,CN,地区；否则简化为 FMO 台站
  String? _cleanFmoComment(String? c) {
    if (c == null) return null;
    final cn = RegExp(r',CN,([^,]+)').firstMatch(c);
    if (cn != null) {
      final region = cn.group(1)!.trim();
      if (region.isNotEmpty) return region;
    }
    return 'FMO 台站';
  }

  void _pushPacket(Packet p) {
    packets.insert(0, p);
    packetsRx++;
    _rxTimes.add(DateTime.now());
    // 顺带清理超过 60 秒的记录，防止 _rxTimes 无界增长
    final now = DateTime.now();
    _rxTimes.removeWhere((t) => now.difference(t).inSeconds > 60);
    if (packets.length > 200) packets.removeLast();
    _notifyRx();
  }

  // ─── 联系人/收藏 ───
  /// 切换收藏状态
  void toggleFavorite(String call) {
    final idx = stations.indexWhere((s) => s.call == call);
    if (idx >= 0) {
      stations[idx].favorite = !stations[idx].favorite;
      _bumpStationsVersion();
      _notify();
      _saveStations();
    }
  }

  /// 手动添加联系人（无需等待 APRS 数据包）
  bool addManualStation(String call) {
    final c = call.trim().toUpperCase();
    if (c.isEmpty) return false;
    // 已存在则仅标记收藏
    final idx = stations.indexWhere((s) => s.call == c);
    if (idx >= 0) {
      stations[idx].favorite = true;
      _bumpStationsVersion();
      _notify();
      _saveStations();
      return true;
    }
    stations.add(
      Station(
        call: c,
        symbol: '/',
        lat: 0,
        lng: 0,
        lastHeard: DateTime.now(),
        status: St.offline,
        comment: '手动添加',
        manual: true,
        favorite: true,
      ),
    );
    _bumpStationsVersion();
    _notify();
    _saveStations();
    return true;
  }

  /// 保存台站列表到本地
  void _saveStations() {
    SharedPreferences.getInstance()
        .then((p) {
          final json = stations
              .map(
                (s) => {
                  'call': s.call,
                  'symbol': s.symbol,
                  'lat': s.lat,
                  'lng': s.lng,
                  'lastHeard': s.lastHeard.millisecondsSinceEpoch,
                  'status': s.status.index,
                  'comment': s.comment,
                  'favorite': s.favorite,
                  'manual': s.manual,
                  if (s.path != null) 'path': s.path,
                  if (s.toCall != null && s.toCall!.isNotEmpty)
                    'toCall': s.toCall,
                  if (s.fmo != null) 'fmo': s.fmo,
                  if (s.aprslocus != null) 'aprslocus': s.aprslocus,
                },
              )
              .toList();
          p.setString('stations', jsonEncode(json));
        })
        .catchError((_) {});
  }

  /// 加载台站列表（含收藏和手动添加的）
  void _loadStations(SharedPreferences p) {
    final json = p.getString('stations');
    if (json == null || json.isEmpty) return;
    try {
      final list = jsonDecode(json) as List;
      for (final j in list) {
        final m = j as Map<String, dynamic>;
        final call = m['call'] as String;
        // 如果台站已从 APRS 收到，只恢复收藏/手动标记
        final idx = stations.indexWhere((s) => s.call == call);
        if (idx >= 0) {
          stations[idx].favorite = m['favorite'] as bool? ?? false;
          stations[idx].manual = m['manual'] as bool? ?? false;
          stations[idx].path = m['path'] as String?;
          final savedToCall = m['toCall'] as String?;
          if (savedToCall != null && savedToCall.isNotEmpty) {
            stations[idx].toCall = savedToCall;
          }
          final apMap = m['aprslocus'];
          if (apMap is Map) {
            stations[idx].aprslocus = apMap.map(
              (k, v) => MapEntry(k.toString(), v.toString()),
            );
          }
        } else {
          final apMap = m['aprslocus'];
          final favorite = m['favorite'] as bool? ?? false;
          final manual = m['manual'] as bool? ?? false;
          final sym = m['symbol'] as String? ?? '/';
          // 国家筛选：非收藏/手动且不匹配所选国家的历史台站不加载
          // 开启「其他台站」时放行特殊类型（中继 R/#、气象 W/w、FMO i）
          final special =
              receiveOthers &&
              (sym == 'R' ||
                  sym == '#' ||
                  sym == 'W' ||
                  sym == 'w' ||
                  sym == 'i');
          if (!favorite && !manual && !_matchReceiveFilter(call) && !special)
            continue;
          stations.add(
            Station(
              call: call,
              symbol: sym,
              lat: (m['lat'] as num?)?.toDouble() ?? 0,
              lng: (m['lng'] as num?)?.toDouble() ?? 0,
              lastHeard: DateTime.fromMillisecondsSinceEpoch(
                m['lastHeard'] as int? ?? 0,
              ),
              status: St.values[m['status'] as int? ?? 0],
              comment: m['comment'] as String?,
              favorite: favorite,
              manual: manual,
              path: m['path'] as String?,
              toCall: (m['toCall'] as String?)?.isNotEmpty == true
                  ? m['toCall'] as String?
                  : null,
              aprslocus: apMap is Map
                  ? apMap.map((k, v) => MapEntry(k.toString(), v.toString()))
                  : null,
            ),
          );
        }
      }
    } catch (_) {}
  }

  // ─── 消息 ───
  /// 清空全部聊天记录
  void clearMessages() {
    messages.clear();
    unreadMessages = 0;
    _readAt.clear();
    _saveMessages();
    _notify();
  }

  /// 某会话的未读数（该呼号收到的、晚于已读时间点的消息数）
  int conversationUnread(String call) {
    final readAt = _readAt[call];
    int n = 0;
    for (final m in messages) {
      if (!m.sent && m.from == call) {
        if (readAt == null || m.time.isAfter(readAt)) n++;
      }
    }
    return n;
  }

  /// 标记某会话已读
  void markConversationRead(String call) {
    _readAt[call] = DateTime.now();
    _recalcUnread();
    _saveMessages();
  }

  /// 某群聊的未读数（该群收到的、晚于已读时间点的消息数）
  int groupUnreadCount(String groupId) {
    final readAt = _groupReadAt[groupId];
    int n = 0;
    for (final m in messages) {
      if (!m.sent && !m.system && m.groupId == groupId) {
        if (readAt == null || m.time.isAfter(readAt)) n++;
      }
    }
    return n;
  }

  /// 标记某群聊已读
  void markGroupRead(String groupId) {
    _groupReadAt[groupId] = DateTime.now();
    _saveMessages();
  }

  /// 重新计算全局未读数
  void _recalcUnread() {
    int n = 0;
    for (final m in messages) {
      if (m.sent || m.system) continue;
      if (m.groupId != null) {
        // 群聊消息：按群已读时间点
        final readAt = _groupReadAt[m.groupId];
        if (readAt == null || m.time.isAfter(readAt)) n++;
      } else {
        final readAt = _readAt[m.from];
        if (readAt == null || m.time.isAfter(readAt)) n++;
      }
    }
    if (n != unreadMessages) {
      unreadMessages = n;
      _notify();
    }
  }

  /// 清零全部未读消息（进入消息页时调用）
  void clearUnread() {
    if (unreadMessages == 0) return;
    unreadMessages = 0;
    final now = DateTime.now();
    for (final m in messages) {
      if (!m.sent) {
        if (m.groupId != null) {
          _groupReadAt[m.groupId!] = now;
        } else {
          _readAt[m.from] = now;
        }
      }
    }
    _notify();
  }

  /// 删除联系人（收藏/手动台站）
  void removeContact(String call) {
    stations.removeWhere((s) => s.call == call);
    _bumpStationsVersion();
    _saveStations();
    _notify();
  }

  void sendMessage(String to, String text) {
    if (text.trim().isEmpty) return;
    // 防止误发给群呼号：重定向到对应群聊
    for (final g in chatGroups) {
      if (g.groupCall.toUpperCase() == to.toUpperCase()) {
        sendGroupMessage(g.groupCall, text, groupId: g.id);
        return;
      }
    }
    final id = AprsFmt.randId();
    final raw = AprsFmt.message(myFullCall, to, text.trim(), id);
    messages.insert(
      0,
      AprsMsg(myFullCall, to, text.trim(), DateTime.now(), sent: true, id: id),
    );
    _saveMessages();
    packetsTx++;
    if (connected) {
      aprs.send(raw);
      _lastTx = DateTime.now();
    }
    _log(LogLevel.info, '消息', '发送给 $to：$text');
    _pushPacket(
      Packet(
        raw,
        myFullCall,
        'APRS',
        'message',
        DateTime.now(),
        info: '发给 $to：$text',
      ),
    );
    _notify();
  }

  /// 群发：向群呼号广播消息（所有监听该群呼号的人都能收到）
  /// 使用 no-ack 格式 `{id_`，避免每个成员自动回 ack 造成噪声
  int sendGroupMessage(String groupCall, String text, {String? groupId}) {
    if (text.trim().isEmpty || groupCall.isEmpty) return 0;
    final id = AprsFmt.randId();
    final raw = AprsFmt.messageNoAck(myFullCall, groupCall, text.trim(), id);
    messages.insert(
      0,
      AprsMsg(
        myFullCall,
        groupCall,
        text.trim(),
        DateTime.now(),
        sent: true,
        id: id,
        groupId: groupId,
      ),
    );
    _saveMessages();
    packetsTx++;
    if (connected) {
      aprs.send(raw);
      _lastTx = DateTime.now();
    }
    _log(LogLevel.info, '群发', '发送到 $groupCall：$text');
    _pushPacket(
      Packet(
        raw,
        myFullCall,
        'APRS',
        'message',
        DateTime.now(),
        info: '群发到 $groupCall：$text',
      ),
    );
    _notify();
    return 1;
  }

  // ─── 群聊管理 ───
  ChatGroup createGroup(
    String name,
    Set<String> members, {
    String? groupCall,
    String? owner,
  }) {
    // 生成群呼号：{群主呼号}-G{序号}
    final gc = groupCall ?? _generateGroupCall(owner ?? myCall);
    final g = ChatGroup(
      id: 'grp_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      groupCall: gc,
      owner: owner ?? myCall,
    );
    // 初始化成员状态
    for (final m in members) {
      g.memberStatus[m.toUpperCase()] = GroupMemberStatus.pending;
    }
    chatGroups.add(g);
    _saveChatGroups();
    _log(LogLevel.info, '群聊', '创建群组 ${g.name} ($gc)');
    _notify();
    return g;
  }

  /// 生成群呼号：{呼号}-G{序号}（不超过9字符）
  String _generateGroupCall(String ownerCall) {
    final base = ownerCall.replaceAll(RegExp(r'-\w+$'), ''); // 去掉 SSID
    // 找到此群主最大的序号
    int maxIdx = 0;
    for (final g in chatGroups) {
      if (g.owner.toUpperCase() == ownerCall.toUpperCase()) {
        final m = RegExp(r'-G(\d+)$').firstMatch(g.groupCall);
        if (m != null) {
          final idx = int.tryParse(m.group(1)!) ?? 0;
          if (idx > maxIdx) maxIdx = idx;
        }
      }
    }
    final nextIdx = maxIdx + 1;
    final call = '$base-G$nextIdx';
    return call.length > 9 ? call.substring(0, 9) : call;
  }

  /// 群主发送邀请给成员
  /// 无论当前是否连接都尝试发送（若刚建群触发重连，connected 可能短暂为 false）
  void sendInvite(String groupCall, String memberCall, String groupName) {
    final raw = AprsFmt.message(
      myFullCall,
      memberCall,
      'INVITE $groupCall $groupName',
      AprsFmt.randId(),
    );
    _trySend(raw);
    _log(LogLevel.info, '群聊', '发送邀请给 $memberCall：$groupCall $groupName');
  }

  /// 成员确认加入（发给群主）
  void sendJoinConfirm(String ownerCall, String groupCall) {
    final raw = AprsFmt.message(
      myFullCall,
      ownerCall,
      'JOIN_CONFIRM $groupCall',
      AprsFmt.randId(),
    );
    _trySend(raw);
    _log(LogLevel.info, '群聊', '确认加入 $groupCall');
  }

  /// 成员离开（发给群主）
  void sendLeave(String ownerCall, String groupCall) {
    final raw = AprsFmt.message(
      myFullCall,
      ownerCall,
      'LEFT $groupCall',
      AprsFmt.randId(),
    );
    _trySend(raw);
    _log(LogLevel.info, '群聊', '离开 $groupCall');
  }

  /// 尽力发送：连接就发，未连接只记录（等待重连后由定时器补发待发队列）
  void _trySend(String raw) {
    if (connected) {
      aprs.send(raw);
      _lastTx = DateTime.now();
      packetsTx++;
    } else {
      _pendingTx.add(raw);
      _log(LogLevel.debug, '消息', '未连接，加入待发队列');
    }
  }

  /// 连接成功后补发待发队列
  void _flushPendingTx() {
    if (_pendingTx.isEmpty) return;
    final list = List<String>.from(_pendingTx);
    _pendingTx.clear();
    for (final raw in list) {
      aprs.send(raw);
      _lastTx = DateTime.now();
      packetsTx++;
    }
    _log(LogLevel.info, '消息', '补发 ${list.length} 条待发消息');
    _notify();
  }

  /// 更新群聊
  void updateGroup(String groupId, {String? name, Set<String>? members}) {
    final g = chatGroups.where((g) => g.id == groupId).firstOrNull;
    if (g == null) return;
    if (name != null) g.name = name;
    if (members != null) {
      // 添加新成员为 pending，不在列表中的保持不变
      for (final m in members) {
        g.memberStatus.putIfAbsent(
          m.toUpperCase(),
          () => GroupMemberStatus.pending,
        );
      }
    }
    _saveChatGroups();
    _notify();
  }

  void deleteGroup(String groupId) {
    chatGroups.removeWhere((g) => g.id == groupId);
    _saveChatGroups();
    _notify();
  }

  String _lastFilter = ''; // 上次连接使用的过滤器，避免无效重连

  void _saveChatGroups() {
    SharedPreferences.getInstance().then((p) {
      final json = jsonEncode(chatGroups.map((g) => g.toJson()).toList());
      p.setString('chatGroups', json);
    });
    // 群组变更 → 仅在过滤器实际变化时更新并重连
    if (connected) {
      final newFilter = filterString;
      if (_lastFilter != newFilter) {
        aprs.filter = newFilter;
        _log(LogLevel.info, '连接', '群组变更，更新过滤器: $newFilter');
        reconnect();
      }
    }
  }

  /// 立即持久化群聊并通知刷新（群管理面板操作后调用）
  void saveGroupNow() {
    _saveChatGroups();
    _notify();
  }

  void sendPacket(String raw) {
    if (raw.trim().isEmpty) return;
    final src = raw.contains('>') ? raw.split('>').first : myCall;
    _pushPacket(Packet(raw, src, 'APRS', 'message', DateTime.now(), info: raw));
    packetsTx++;
    if (connected) {
      aprs.send(raw);
      _lastTx = DateTime.now();
    }
    _notify();
  }

  // ─── 开发者工具 ───

  /// 注入一条原始 APRS 数据包（用于解析测试 / 手动模拟接收）
  /// 返回解析结果描述，供界面提示
  String injectRawPacket(String raw) {
    if (raw.trim().isEmpty) return '输入为空';
    try {
      final sep = raw.indexOf('>');
      final bodySep = raw.indexOf(':');
      if (sep < 0 || bodySep < 0) {
        _pushPacket(
          Packet(
            raw.trim(),
            '?',
            'APRS',
            'unknown',
            DateTime.now(),
            info: raw.trim(),
          ),
        );
        _notify();
        return '格式异常：缺少 > 或 :';
      }
      final src = raw.substring(0, sep).trim();
      final body = raw.substring(bodySep + 1);
      String toCall = '';
      if (bodySep > sep + 1) {
        final pathSeg = raw.substring(sep + 1, bodySep).trim();
        final first = pathSeg.split(RegExp(r'[, ]')).first.trim().toUpperCase();
        if (first.isNotEmpty &&
            first != 'APRS' &&
            first != 'TCPIP*' &&
            first != 'BEACON' &&
            first != 'MAIL') {
          toCall = first;
        }
      }
      if (body.startsWith('!') ||
          body.startsWith('=') ||
          body.startsWith('@')) {
        final p = parseAprsPosition(body);
        if (p != null) {
          _upsertStation(src, p, raw: raw, toCall: toCall);
          _pushPacket(
            Packet(
              raw.trim(),
              src,
              'APRS',
              'position',
              DateTime.now(),
              info:
                  '${p.lat.toStringAsFixed(4)}, ${p.lng.toStringAsFixed(4)}'
                  ' · ${maidenhead(p.lat, p.lng)}',
            ),
          );
          _notify();
          return '已解析台站 $src：'
              '${p.lat.toStringAsFixed(5)}, ${p.lng.toStringAsFixed(5)}'
              ' 网格 ${maidenhead(p.lat, p.lng)}';
        }
      }
      _pushPacket(
        Packet(raw.trim(), src, 'APRS', 'unknown', DateTime.now(), info: body),
      );
      _notify();
      return '已加入数据包，但未识别为位置（$src）';
    } catch (e) {
      return '解析异常：$e';
    }
  }

  /// 清除收到的数据包（保留台站）
  void clearPackets() {
    packets.clear();
    packetsRx = 0;
    _notify();
  }

  /// 清除所有本地数据
  void clearAllData() {
    stations.clear();
    _bumpStationsVersion();
    messages.clear();
    chatGroups.clear();
    logs.clear();
    packets.clear();
    _readAt.clear();
    _groupReadAt.clear();
    packetsTx = 0;
    packetsRx = 0;
    unreadMessages = 0;
    _saveStations();
    _saveMessages();
    _saveChatGroups();
    clearLogs();
    _notify();
  }

  // ─── 演示模拟（未连接时让地图活起来） ───
  void _simTick() {
    final moving = stations.where((s) => s.status == St.moving).toList();
    if (moving.isNotEmpty) {
      final s = moving[math.Random().nextInt(moving.length)];
      s.lat += (math.Random().nextDouble() - 0.5) * 0.004;
      s.lng += (math.Random().nextDouble() - 0.5) * 0.004;
      s.lastHeard = DateTime.now();
      s.track = [...s.track, TrackPt(s.lat, s.lng, DateTime.now())];
      if (s.track.length > 60) s.track = s.track.sublist(s.track.length - 60);
    }
    _bumpStationsVersion();
    _notify();
  }

  // ─── 地图焦点（台站列表 → 地图定位） ───
  Station? mapFocus;
  int mapFocusSeq = 0;

  void focusOnMap(Station s) {
    mapFocus = s;
    mapFocusSeq++;
    _notify();
  }

  // ─── 地图选点定位 ───
  bool pickMode = false;
  int pickSeq = 0;

  /// 进入地图选点模式（设置 → 在地图选点）
  void startPick() {
    pickMode = true;
    pickSeq++;
    _notify();
  }

  /// 结束选点
  void finishPick() {
    pickMode = false;
    _notify();
  }

  String get myPosStr => myHasFix
      ? '${myLat!.toStringAsFixed(4)}, ${myLng!.toStringAsFixed(4)}'
      : '--';

  String get myGrid => myHasFix ? maidenhead(myLat!, myLng!) : '--';

  String get nextBeaconIn {
    if (!beaconEnabled) return '已关闭';
    if (!connected) return '未连接';
    if (!myHasFix) return '等待定位';
    final remain =
        beaconInterval - DateTime.now().difference(_lastBeacon).inSeconds;
    return remain > 0 ? '${remain}s' : '即将';
  }

  /// 更新状态栏通知（前台服务常驻通知）
  void _updateNotification() {
    final parts = <String>[];
    if (connected) {
      parts.add('已连接');
    } else if (connecting) {
      parts.add('连接中');
    } else {
      parts.add('未连接');
    }
    if (myHasFix) {
      parts.add('GPS·$myGrid');
    }
    parts.add('$online在线');
    parts.add('收$packetsRx');
    if (beaconEnabled) {
      parts.add('信标$nextBeaconIn');
    }
    loc.updateNotification(parts.join(' · '));
  }
}
