import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'mock_data.dart';
import 'services.dart';
import 'aprs_parse.dart';
import 'aprs_device.dart';
import 'pos_quality.dart';
import 'track_log.dart';
import 'motion.dart';
import 'adif.dart';
import 'l10n/app_localizations.dart';
// 说明：AppLocalizationsZh / AppLocalizationsZhTw / AppLocalizationsEn 是 gen-l10n
// 生成在 app_localizations_zh.dart / app_localizations_en.dart 里的**具体实现类**，
// app_localizations.dart 只导出抽象基类。状态层（无 BuildContext）需要直接构造
// 具体实例，故必须显式 import 这两个生成文件，否则报 undefined_method。
import 'l10n/app_localizations_en.dart';
import 'l10n/app_localizations_es.dart';
import 'l10n/app_localizations_id.dart';
import 'l10n/app_localizations_ja.dart';
import 'l10n/app_localizations_zh.dart';
import 'net/aprs.dart';
import 'audio.dart';
import 'pkwdwpl.dart';
import 'diag.dart';
import 'group_chat.dart';
import 'igate.dart';
import 'tnc.dart';
import 'translate.dart';
import 'early_member.dart';
import 'achievements.dart';
// 说明：状态层要用 theme.dart 里的 C（应用材质）与 uiMaterialOf / uiMaterialName。
// 以前它只经过 theme_store.dart 间接用到主题，改成直接用 theme.dart 之后
// 新增的这几个名字才能解析 —— CI 的 analyze 就是这么报出来的。
import 'theme.dart';
import 'theme_store.dart';
import 'ble_hr.dart';
import 'garmin.dart';
import 'share_in.dart';

/// 智能信标速度档：速度 ≥ [minSpeed] km/h 时启用。
/// 首档 minSpeed==0 为「静止/低速」档（兜底档，不可删除）；
/// symbol 为空串表示沿用「我的符号」（与发送时设备图标一致）。
class SmartBeaconTier {
  int minSpeed; // km/h，≥0，列表内升序，首档必须为 0
  int intervalSec; // 上报间隔（秒）
  String symbol; // APRS 符号码（空串 = 默认 mySymbol）

  /// **距离打点**：自上次上报以来移动超过该米数也上报一次（0 = 只用间隔）。
  ///
  /// 为什么要有它：定时上报有个先天缺口 —— 两点之间走了多远与「过了多久」无关。
  /// 堵车时 300s 一个点完全够（根本没动），而 60km/h 的国道上 60s 能走 1km，
  /// 中间那段路在 aprs.fi 上就是一条直线，拐弯全被抹平。
  /// 有了距离门限：**走得快就按距离补点**（拐弯不再被切角），
  /// **停下来就退回纯定时**（不白发报文，不占信道）。
  int minDistM;

  /// **转弯打点**：航向相对「上次上报时的航向」变化超过该角度（度）也上报一次。
  /// **逐档可自定义**（设置页里每一档都有这个输入框），0 = 关闭。
  ///
  /// 为什么还要它：距离与定时都答不了「这个弯该不该补一个点」。
  /// 盘山路上车速慢、距离门限很久才够，而连续发卡弯正是最该有轨迹的地方 ——
  /// 缺了转弯判据，地图上那一段就是一串被拉直的直线（看不出弯）。反过来，
  /// 直路巡航时航向不变，它一次都不会触发，不占信道。
  ///
  /// 取值范围 10°~180°（见 [_normalizeSmartTiers]）：小于 10° 落在 GPS 航向
  /// 自身的噪声里，会退化成「每个点都发」。
  int minTurnDeg;

  SmartBeaconTier({
    this.minSpeed = 0,
    this.intervalSec = 60,
    this.symbol = '',
    this.minDistM = 0,
    this.minTurnDeg = 0,
  });

  SmartBeaconTier copy() => SmartBeaconTier(
        minSpeed: minSpeed,
        intervalSec: intervalSec,
        symbol: symbol,
        minDistM: minDistM,
        minTurnDeg: minTurnDeg,
      );

  Map<String, dynamic> toJson() => {
        'minSpeed': minSpeed,
        'intervalSec': intervalSec,
        'symbol': symbol,
        'minDistM': minDistM,
        'minTurnDeg': minTurnDeg,
      };

  factory SmartBeaconTier.fromJson(Map<String, dynamic> j) => SmartBeaconTier(
        minSpeed: ((j['minSpeed'] as num?) ?? 0).toInt(),
        intervalSec: ((j['intervalSec'] as num?) ?? 60).toInt(),
        symbol: (j['symbol'] as String?) ?? '',
        minDistM: ((j['minDistM'] as num?) ?? 0).toInt(),
        minTurnDeg: ((j['minTurnDeg'] as num?) ?? 0).toInt(),
      );
}

class AppState extends ChangeNotifier {
  /// 应用版本（用于信标备注、APRSlocus 识别）
  static const appVersion = '1.6.168';
  // 我的电台
  String myCall = 'BV2AAA';
  int mySsid = 0; // 0 = 无后缀, 1-15 = -1 到 -15
  String mySymbol = '>';
  // 备注默认**为空**（用户要求）：新装用户不会再被塞一段默认文字。
  // 历史版本曾默认 'APRSlocus 移动台'，老用户升级后由 _loadPrefs 迁移清零。
  String myComment = '';

  /// 历史版本的内置默认备注。升级时若仍是这个值（用户从未改过）则视为空。
  static const _legacyDefaultComment = 'APRSlocus 移动台';

  /// 在线判定时长（分钟）：台站最后上报距今超过该值即视为离线。
  /// 原先是写死的 5 分钟，现改为用户可配置（步进见设置页）。
  int onlineWindowMin = 5;

  /// 把在线判定时长同步到模型层（`Station.effectiveStatus` 读它）。
  /// 加载设置与用户修改时都要调用，否则地图圆点等无上下文处仍按旧窗口判定。
  void _applyOnlineWindow() {
    Station.onlineWindowSec = onlineWindowMin * 60;
  }

  void setOnlineWindowMin(int v) {
    onlineWindowMin = v.clamp(1, 240);
    _applyOnlineWindow();
    persist();
    _notify();
  }

  /// 完整呼号（含 SSID 后缀）
  String get myFullCall => mySsid == 0 ? myCall : '$myCall-$mySsid';

  /// 运行平台短名：用于 CONNECT 在线状态帧，便于在 APRS-IS 上区分端侧。
  /// Android / iOS 用系统名，Windows 简写 Win、macOS 简写 Mac。
  static String get platformTag {
    if (kIsWeb) return 'Web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'Android';
      case TargetPlatform.iOS:
        return 'iOS';
      case TargetPlatform.windows:
        return 'Win';
      case TargetPlatform.macOS:
        return 'Mac';
      case TargetPlatform.linux:
        return 'Linux';
      case TargetPlatform.fuchsia:
        return 'Fuchsia';
    }
  }

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

  /// 最近一次实时定位的**水平精度**（米，1σ）；0 表示平台没给这个值。
  /// 用来：① 界面如实显示「±40 m」；② 太差的点不写轨迹；③ 给地图上的「我」
  /// 画不确定圈。以前这个值在 Dart 侧被丢掉（原生算了但没人读）。
  /// 自己位置的精度（米）。粗定位时不是系统原值，见 [_kCoarseAccuracyFloorM]
  double myAccuracy = 0;

  /// 当前这个定位是不是粗定位（网络/基站/被动）。
  ///
  /// 界面上要如实告知：粗点会把「我」放在几百米开外，不说清楚用户会以为
  /// GPS 坏了。切换/退出时靠 [_resetSelfFix] 复位。
  bool myFixCoarse = false;

  /// 蓝牙心率（bpm）：最近一次收到的读数（心率带通知 / 佳明点）。
  /// null = 还没有过读数（此时**不发** HR=，而不是发一个 0）。
  int? myHr;

  /// 蓝牙心率带服务（扫描/连接/订阅标准心率服务 0x180D）。
  final BleHrService bleHr = BleHrService.instance;

  /// 佳明 LiveTrack 轨迹服务（抓公开分享页，把新点转换成本地定位）。
  final GarminTrackService garmin = GarminTrackService.instance;

  /// 「分享给 APRSlocus」入口（佳明 App 分享 LiveTrack 链接进来）。
  final ShareInService shareIn = ShareInService.instance;

  /// 记住的心率带（地址 + 名字）：只用于「上次那台」的一键重连；
  /// 开机不自动连 —— 蓝牙权限/设备不在身边时静默失败反而更让人困惑。
  String bleHrId = '';
  String bleHrName = '';

  /// 上一个佳明点：只用来算航向（佳明的点没有航向字段，见 [bearingDeg]）。
  GarminPoint? _lastGarminPoint;

  /// 佳明 LiveTrack 的分享链接与开关状态。
  String garminUrl = '';
  bool garminOn = false;

  /// 收到「分享进来的佳明链接」时回调（外壳用来提示并把用户带到设置页）。
  void Function(String url)? onGarminShared;

  /// 分享内容里**没有**佳明链接时回调（外壳用来如实提示，而不是静默什么都不做）。
  void Function()? onGarminShareNoLink;

  /// 佳明 LiveTrack 的新点 → 当作「自己」的一次定位。
  ///
  /// 为什么不让它走 _onFix：那条路径围着**手机定位**的一堆特性转（粗定位闸、
  /// 静止防抖滑窗、缓存点闸门、精度门限），而佳明点自带「手表测出来的
  /// 经纬度/速度/心率」，是另一类东西 —— 硬塞进去反而要层层特判。
  /// 这里只做三件必须做的事：更新位置、写轨迹（同一套抽稀）、跟随过滤中心。
  void _onGarminPoint(GarminPoint p) {
    if (_disposed) return;
    final first = !myHasFix;
    myLat = p.lat;
    myLng = p.lng;
    myHasFix = true;
    myFixCoarse = false; // 手表 GPS，不是粗定位
    myAccuracy = 0; // 佳明页面不给精度 → 0 = 未知（不画精度圈）
    if (p.altM != null) myAlt = p.altM;
    if (p.speedMps != null) mySpeed = p.speedMps! * 3.6;
    if (p.hr != null && p.hr! > 0) myHr = p.hr;
    // 航向：佳明的点里没有这个字段，用**前后两点**算（见 bearingDeg 的注释）。
    // 没有上一个点（首个点）时不改 —— 保留手机 GPS 的最后已知航向，比瞎指北好。
    final prev = _lastGarminPoint;
    if (prev != null) {
      final b = bearingDeg(prev.lat, prev.lng, p.lat, p.lng);
      if (b != null) myCourse = b;
    }
    _lastGarminPoint = p;
    locStatus = '佳明 LiveTrack';
    // 跳变守卫的参照点也要跟着走：否则手机 GPS 接回来的那一刻会被误判成跳变
    _lastFixLat = p.lat;
    _lastFixLng = p.lng;
    _lastFixTime = DateTime.now();
    _hadLiveFix = true;
    // 轨迹：与 GPS 同一套「按速度自适应抽稀」，但不受静止防抖影响
    // （佳明的点本身就是干净的；静止时手表也会给点，画出来才对）。
    final last = myTrack.isEmpty ? null : myTrack.last;
    final minDistM =
        PosQuality.trackMinDistM(speedKmh: (p.speedMps ?? 0) * 3.6);
    final movedM = last == null
        ? double.infinity
        : haversine(last.lat, last.lng, p.lat, p.lng) * 1000;
    if (last == null || movedM > minDistM) {
      myTrack.add(TrackPt(p.lat, p.lng, DateTime.now()));
      if (myTrack.length > maxTrackPts) {
        myTrack.removeRange(0, myTrack.length - maxTrackPts);
      }
      // 历史台账（按天落盘）：GPS 那条路径写在同一个条件里，佳明这条也必须写 ——
      // 不写的话「佳明接管期间」在历史记录里是**一段空白**（而手机 GPS 正好被让位，
      // 两边都不记，用户回头看会觉得那一段路凭空消失）。
      TrackLogStore.instance.record(
        lat: p.lat,
        lng: p.lng,
        speedKmh: (p.speedMps ?? 0) * 3.6,
        course: myCourse,
        alt: p.altM,
        accuracyM: 0,
      );
    }
    if (filterFollow) {
      filterLat = p.lat;
      filterLng = p.lng;
    }
    if (first) {
      _log(
        LogLevel.info,
        '佳明',
        'LiveTrack 首个点 ${p.lat.toStringAsFixed(5)}, ${p.lng.toStringAsFixed(5)}',
      );
    }
    _notify();
    _updateNotification();
  }

  /// 收到分享进来的文本（佳明 App 的 LiveTrack 链接）。
  ///
  /// 不信任输入：整段分享文案里只有匹配 LiveTrack 链接的那部分才有意义
  /// （见 extractLiveTrackUrl），匹配不上就安静丢掉。
  void _onSharedIncoming(String text) {
    if (_disposed) return;
    final url = extractLiveTrackUrl(text);
    if (url == null) {
      // **失败必须可见**：以前这里直接 return —— 用户分享完什么都没发生、
      // 也没有任何解释，只能来问「为什么没识别」。
      // 日志里带上原文前 120 字（去掉换行），否则无从判断到底是佳明改了格式，
      // 还是分享过来的根本不是链接。
      final brief = text.replaceAll(RegExp(r'\s+'), ' ').trim();
      _log(
        LogLevel.warn,
        '佳明',
        '分享内容里没有找到 LiveTrack 链接（前 120 字）：'
            '${brief.length > 120 ? '${brief.substring(0, 120)}…' : brief}',
      );
      onGarminShareNoLink?.call();
      _notify();
      return;
    }
    garminUrl = url;
    _log(LogLevel.info, '佳明', '收到分享的 LiveTrack 链接，开始追踪');
    unawaited(garmin.start(url));
    garminOn = true;
    persist();
    onGarminShared?.call(url);
    _notify();
  }

  /// 手动设置我的位置（模拟位置 / Windows 无定位服务时的备用）
  void setMyPosition(double lat, double lng, {double? alt}) {
    myLat = lat;
    myLng = lng;
    myAlt = alt;
    myHasFix = true;
    useSimLocation = true;
    loc.stop();
    // 换到模拟位置：复位 GPS 侧的全部状态，免得切回真实定位时拿着手动坐标
    // 当历史、把位置粘在旧点上。
    _resetSelfFix();
    locStatus = '模拟位置';
    _syncFilterToPosition(); // 过滤中心跟随我的位置（filterFollow 时）
    persist();
    _notify();
  }

  /// 「过滤中心跟随我的位置」在手动设坐标 / 切到模拟位置时同步过滤中心。
  /// 已连接且过滤串实际变化才重连应用（未连接仅更新字段，下次连接生效）；
  /// GPS 实时定位的跟随在 _onFix 中处理（字段更新，避免每次定位都重连）。
  void _syncFilterToPosition() {
    if (!filterFollow) return;
    if (myLat == null || myLng == null) return;
    filterLat = myLat!;
    filterLng = myLng!;
    _refreshFilter();
  }

  // 信标
  bool beaconEnabled = true;
  int beaconInterval = 60; // 秒（APRS-IS 建议移动站不低于 60 秒）
  DateTime _lastBeacon = DateTime.now();

  /// 上一次信标发出的**位置**：智能信标的「距离打点」用它算「自上次上报以来
  /// 走了多远」（见 [beaconDistMovedM]）。与 [_lastBeacon]（时间）成对更新。
  double? _lastBeaconLat;
  double? _lastBeaconLng;

  /// 上一次信标发出时的**航向**（度）：智能信标的「转弯打点」用它算航向变化
  /// （见 [beaconTurnDeg]）。同样只在真的发出去之后才更新。
  double? _lastBeaconCourse;
  int beaconsSent = 0;

  /// 是否已询问过“连接后是否自动上报位置”（只问一次，记住选择）
  bool beaconAutoAsked = false;

  /// 连接成功后首次询问“自动上报位置”的回调（由首页绑定并弹出选择）
  void Function()? onAskBeaconAuto;

  // 信标上报内容选项
  bool beaconIncludeSpeed = true; // 速度
  bool beaconIncludeCourse = true; // 方位角
  bool beaconIncludeBattery = true; // 手机电量
  /// 信标备注里是否带上**心率**（HR=nn）。
  ///
  /// 心率可能来自两个地方，共用这一个开关：
  ///   * 蓝牙心率带（BLE 标准心率服务，见 lib/ble_hr.dart）；
  ///   * 佳明 LiveTrack 轨迹点里的 heartRateBeatsPerMin（见 lib/garmin.dart）。
  /// APRS 没有心率的正式字段，`HR=nn` 是业界通行写法（参考
  /// garmin-livetrack-aprs-openwrt 的报文示例），第三方地图会把它当备注显示。
  bool beaconIncludeHr = true;
  int _battery = -1; // 电量百分比（-1 未知）

  // ─── 智能信标（按速度分档：不同速度 → 不同上报间隔 + 信标图标）───
  bool smartBeaconEnabled = false;
  /// 速度档列表（升序，首档 minSpeed==0 为静止档）。空串 symbol 沿用 mySymbol。
  final List<SmartBeaconTier> smartTiers = [];

  /// 默认分档方案：
  /// 静止(<5km/h)→300s；步行(≥5)→120s 人形；城市(≥20)→60s 汽车；高速(≥70)→30s 汽车。
  /// 距离档的取值口径：约等于「这一档速度在一个上报间隔内走的路程」，
  /// 也就是「该发下一个点了」的自然位置 —— 比按面积/拍脑袋好解释，
  /// 用户看到「步行 120s / 250m 或」时直觉也对得上（1.4m/s × 120s ≈ 170m）。
  static List<SmartBeaconTier> defaultSmartTiers() => [
        // 静止/步行档的转弯阈值留 0（关闭）：低速时 GPS 航向本身就不稳
        // （见 _applySelfFix 里「低速用指南针补航向」那段），按角度判会乱触发。
        // 每一档都可以在设置页里自己改（0 = 关，10~180°）。
        SmartBeaconTier(minSpeed: 0, intervalSec: 300, symbol: '', minDistM: 200),
        SmartBeaconTier(minSpeed: 5, intervalSec: 120, symbol: '[', minDistM: 250),
        // 城市 45°：每个路口都是 90°，45° 只抓真正的转向，不会每个路口都发。
        SmartBeaconTier(
            minSpeed: 20, intervalSec: 60, symbol: '>', minDistM: 400, minTurnDeg: 45),
        // 高速 30°：出口匝道、大弯这类「航向连续变化」才是要补的点。
        SmartBeaconTier(
            minSpeed: 70, intervalSec: 30, symbol: '>', minDistM: 700, minTurnDeg: 30),
      ];

  void _ensureSmartTiers() {
    if (smartTiers.isEmpty) smartTiers.addAll(defaultSmartTiers());
  }

  void _normalizeSmartTiers() {
    if (smartTiers.isEmpty) {
      smartTiers.addAll(defaultSmartTiers());
      return;
    }
    // 首档恒为静止档（0）
    smartTiers.first.minSpeed = 0;
    // 移动档最低速度至少 1，间隔下限 5 秒
    for (int i = 1; i < smartTiers.length; i++) {
      final t = smartTiers[i];
      if (t.minSpeed < 1) t.minSpeed = 1;
      if (t.intervalSec < 5) t.intervalSec = 5;
    }
    // 距离打点：0 = 关闭；否则夹到 20m~20km（低于 20m 比 GPS 噪声还小，
    // 会退化成「每个点都发」，白占信道；上限只是防手输多打一个零）
    for (final t in smartTiers) {
      if (t.minDistM != 0) {
        t.minDistM = t.minDistM < 20 ? 20 : (t.minDistM > 20000 ? 20000 : t.minDistM);
      }
      // 转弯打点：0 = 关；否则 10°~180°（小于 10° 落在 GPS 航向噪声里，
      // 会退化成「每个点都发」；超过半圈没有意义）
      if (t.minTurnDeg != 0) {
        t.minTurnDeg =
            t.minTurnDeg < 10 ? 10 : (t.minTurnDeg > 180 ? 180 : t.minTurnDeg);
      }
    }
    smartTiers.sort((a, b) => a.minSpeed.compareTo(b.minSpeed));
  }

  void setSmartBeaconOn(bool v) {
    smartBeaconEnabled = v;
    _ensureSmartTiers();
    _normalizeSmartTiers();
    persist();
    _notify();
  }

  void resetSmartTiers() {
    smartTiers
      ..clear()
      ..addAll(defaultSmartTiers());
    persist();
    _notify();
  }

  /// 新增一个移动速度档（阈值自动取当前最大 +10，缺省从 ≥10 起步）
  void addSmartTier() {
    _ensureSmartTiers();
    var next = 10;
    for (final t in smartTiers) {
      if (t.minSpeed >= next) next = t.minSpeed + 10;
    }
    smartTiers.add(SmartBeaconTier(
        minSpeed: next, intervalSec: 60, symbol: '', minDistM: 400, minTurnDeg: 45));
    _normalizeSmartTiers();
    persist();
    _notify();
  }

  /// 更新某一档（index==0 为静止档，threshold 锁死为 0）
  void updateSmartTier(int index, SmartBeaconTier tier) {
    if (index < 0 || index >= smartTiers.length) return;
    smartTiers[index] = tier;
    _normalizeSmartTiers();
    persist();
    _notify();
  }

  /// 删除某一档（静止档 index==0 不可删）
  void removeSmartTier(int index) {
    if (index <= 0 || index >= smartTiers.length) return;
    smartTiers.removeAt(index);
    _normalizeSmartTiers();
    persist();
    _notify();
  }

  /// 智能信标开启时，按当前速度命中的档位；关闭或列表空返回 null
  SmartBeaconTier? get activeSmartTier {
    if (!smartBeaconEnabled || smartTiers.isEmpty) return null;
    final speed = mySpeed ?? 0; // 无速度按静止处理
    SmartBeaconTier? hit;
    for (final t in smartTiers) {
      if (t.minSpeed <= speed) {
        hit = t;
      } else {
        break; // 已升序排序，后续阈值更大
      }
    }
    return hit ?? smartTiers.first;
  }

  /// 实际生效的上报间隔：智能信标按速度取档，否则用固定间隔
  int get beaconIntervalNow => activeSmartTier?.intervalSec ?? beaconInterval;

  /// 实际生效的**距离打点**门限（米）：0 = 只用定时。
  /// 只有智能信标才有这一项 —— 固定间隔模式保持「纯定时」的老行为。
  int get beaconMinDistNow => activeSmartTier?.minDistM ?? 0;

  /// 实际生效的**转弯打点**阈值（度）：0 = 只用定时/距离。
  int get beaconMinTurnNow => activeSmartTier?.minTurnDeg ?? 0;

  /// 自上次**真的发出去**以来，航向变化了多少度（0~180，最小夹角）。
  ///
  /// 两个容易写错的地方，都在这里收口：
  ///  * **角度要环绕**：359° → 1° 是转了 2°，不是 358°。直接相减会让「几乎没转」
  ///    判成「转了大半圈」，于是每个点都触发。
  ///  * **没有航向/没发过 → 返回 0**（不触发）：宁可少补一个点，也不要在航向
  ///    未知时乱发。
  double get beaconTurnDeg {
    final prev = _lastBeaconCourse;
    final cur = myCourse;
    if (prev == null || cur == null) return 0;
    var d = (cur - prev).abs() % 360;
    if (d > 180) d = 360 - d;
    return d;
  }

  /// 自上次**真的发出去**以来移动了多远（米）。
  ///
  /// 与 `_lastBeacon`（时间）成对：两者都在发送成功后更新，所以这个距离
  /// 就是「本次要不要因为『走够了』再发一个」的判据。
  /// 还没发过（或没有定位）时返回 0 —— 此时时间判据会先行，不会漏报。
  double get beaconDistMovedM {
    final la = _lastBeaconLat;
    final ln = _lastBeaconLng;
    if (la == null || ln == null || !myHasFix) return 0;
    return haversine(la, ln, myLat!, myLng!) * 1000;
  }

  /// 实际生效的信标符号：智能档指定了符号则用之，否则用「我的符号」
  String get beaconSymbolNow {
    final tier = activeSmartTier;
    if (tier != null && tier.symbol.isNotEmpty) return tier.symbol;
    return mySymbol;
  }

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

  /// 信标是否带上心率（见 [beaconIncludeHr]）。
  void setBeaconIncludeHr(bool v) {
    beaconIncludeHr = v;
    persist();
    _notify();
  }

  /// 记住心率带（连接成功后调用）：换机/重启后能一键重连同一台。
  void setBleHrDevice(String id, String name) {
    bleHrId = id;
    bleHrName = name;
    persist();
    _notify();
  }

  /// 忘掉心率带。
  void clearBleHrDevice() {
    bleHrId = '';
    bleHrName = '';
    bleHr.forget();
    persist();
    _notify();
  }

  /// 开启/关闭佳明 LiveTrack 追踪（链接无效时返回 false，由 UI 提示）。
  Future<bool> setGarminOn(bool v) async {
    if (!v) {
      garmin.stop();
      garminOn = false;
      persist();
      _notify();
      return true;
    }
    final url = extractLiveTrackUrl(garminUrl);
    if (url == null) return false;
    final ok = await garmin.start(url);
    garminOn = ok;
    if (ok) garminUrl = url;
    persist();
    _notify();
    return ok;
  }

  /// 更新 APRS-IS 接收范围过滤
  void setFilter(double lat, double lng, int radiusKm) {
    filterLat = lat;
    filterLng = lng;
    filterRadius = radiusKm < 10 ? 10 : radiusKm;
    if (filterRadius >= 5000) AchievementCenter.instance.unlock('bigRadius'); // Big? Big!
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
    // 双向网关必须额外请求**全部消息**（t/m）。
    //
    // 这是「网关不转发网络→信道」的根因：`r/lat/lng/r` 这个范围过滤器
    // 只投递**源台站位置在范围内**的报文。而 IS→RF 要转的恰恰是
    // 「远处的台站发给本地手台」的消息 —— 源台站在范围外，报文**根本
    // 到不了本机**，客户端也就无从转发。
    //
    // APRS-IS 规范：多个过滤器是**并集**（官方示例 `filter r/33/-97/200 t/n`
    // = 达拉斯附近 **加上** 全部 NWS 公告）；类型过滤器 `t/poimqstunw` 中
    // `m = Message`，且按类型**全量**投递、不受地理位置限制。
    // 因此这里追加 `t/m` 才能收到全球发给本地台站的消息。
    if (igateEnabled && igateTwoWay) f += ' t/m';
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

  /// 台站数成就检测：达到 500 解锁
  void _checkStationAchievement() {
    if (stations.length >= 500) {
      AchievementCenter.instance.reach('flowerWorld', stations.length); // 花花世界
    }
  }

  /// 功能引导：**已看过**的引导 id 集合（见 lib/guide.dart）。
  ///
  /// 只记「看过」，文案与顺序都由代码给（l10n），所以这里不需要版本号：
  /// 改文案不会让用户重看一遍，改 id 才会。
  final Set<String> guideSeen = {};

  /// 这条引导是否已看过
  bool isGuideSeen(String id) => guideSeen.contains(id);

  /// 记下「已看过」（关闭提示卡时调）
  void markGuideSeen(String id) {
    if (!guideSeen.add(id)) return;
    persist();
  }

  /// 重置全部引导（设置里的「重新查看功能引导」）
  void resetGuides() {
    if (guideSeen.isEmpty) return;
    guideSeen.clear();
    persist();
  }

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
    // 未选择任何国家/地区 = 不做限制，全部接收。
    // （与「接收其他台站」及上报入口的语义保持一致；此前返回 false 会让
    //   台站虽已正常接收入库，却在台站列表/地图/统计上全部不可见。）
    // 提前返回且不写缓存，避免缓存与筛选状态不一致。
    if (receiveCountries.isEmpty) return true;
    final up = call.toUpperCase();
    final cached = _matchCache[up];
    if (cached != null) return cached;
    var ok = false;
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
    // 未选择国家/地区时不限制（_matchReceiveFilter 内部已处理）
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

  /// 台站筛选条件（由台站面板编辑）：状态 / 类型 / 同款软件 / 设备
  StationFilter stationFilter = const StationFilter();

  /// 是否把台站面板的筛选同时应用到地图（默认关闭，避免误隐藏台站）
  bool applyFilterToMap = false;

  /// 更新台站筛选；推进台站版本让台站页与地图（共用同一条台站流）同步刷新
  void setStationFilter(StationFilter f) {
    stationFilter = f;
    _bumpStationsVersion();
  }

  void setApplyFilterToMap(bool v) {
    applyFilterToMap = v;
    _bumpStationsVersion();
  }

  /// 数据包列表上限（下限 100，防止设成 0 把历史全清掉）
  void setMaxPackets(int n) {
    maxPackets = n < 100 ? 100 : n;
    if (packets.length > maxPackets) {
      packets.removeRange(maxPackets, packets.length);
    }
    persist();
    _notify();
  }

  /// 轨迹点数上限（下限 20，防止轨迹退化成一条直线）
  void setMaxTrackPts(int n) {
    maxTrackPts = n < 20 ? 20 : n;
    // 立即裁剪超量轨迹，避免旧数据继续占用内存
    for (final s in stations) {
      if (s.track.length > maxTrackPts) {
        s.track = s.track.sublist(s.track.length - maxTrackPts);
      }
    }
    if (myTrack.length > maxTrackPts) {
      myTrack.removeRange(0, myTrack.length - maxTrackPts);
    }
    _bumpStationsVersion();
    persist();
    _notify();
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
  /// 当前连接（数据来源）状态。TNC 模式下它表示「TNC 链路已建立」，
  /// 因此上层（连接卡片、状态栏、通知）无需分辨数据来源 —— 详见 [_syncConnFromLink]。
  bool connected = false;
  bool connecting = false;
  /// 连接状态（结构化）。
  ///
  /// **不要用中文字符串表示状态**：此前 `connInfo` 存中文，UI 侧靠
  /// `localizedConnectionInfo()` 拿中文当哨兵再映射回 l10n —— 一旦新增
  /// 状态忘了登记映射，界面在所有语言下都会漏出中文（这正是 TNC 状态
  /// 串当初的表现）。改为结构化枚举 + 参数，由本类的 [connInfo] 直接
  /// 用当前语言生成文案，与 `BeaconPhase` 同一套做法。
  ConnStatus _conn = const ConnStatus(ConnPhase.idle);

  /// 设置连接状态（自动通知刷新）
  void setConnStatus(ConnPhase phase, {String arg = '', int seconds = 0}) {
    _conn = ConnStatus(phase, arg: arg, seconds: seconds);
    _notify();
  }

  /// 当前连接状态说明（**已按当前界面语言本地化**）
  String get connInfo => _conn.localized(l10n);
  // Passcode 是否被服务器判定无效（logresp unverified）
  bool passcodeInvalid = false;

  // ─── 数据来源（可多选）+ 网关 ───
  //
  // 语义分工（改这里前务必看清，否则很容易把「多选」做成两套互相打架的状态）：
  //   * [enabledSources] —— **同时连接哪几条链路**（多选）。多条链路可以一起
  //     收包，收到的报文都进同一条解析管线。
  //   * [dataSource]     —— **发射走哪条**（单选）。所有与发射有关的判断
  //     （txPath / 消息限长 / 群聊禁用 / 射频信标 / 保活）都用它，因此这些
  //     逻辑在多选改造中**一行都不用改**。
  //   * 为什么发射不能也多选：同一个 myFullCall 从两条链路同时发出会造成
  //     重复报文（射频上还白占一次时隙），而且 ack 会回两次。
  /// 当前**发射**来源：'aprsis' | 'tnc' | 'audio'
  ///
  /// ⚠️ **不含 'pkwdwpl'**：那条链路是**只读**的（电台单向输出 Kenwood
  /// 航点语句），不可能发报。因此 [enabledSources] 里出现 pkwdwpl 时它
  /// 只能“收”，发射永远落在另外三条之一上。
  String dataSource = 'aprsis';

  /// 已启用的来源集合（至少一个；发射来源必须在此集合内）
  final Set<String> enabledSources = {srcAprsIs};

  /// 每条链路的实际连通状态。键为 'aprsis'|'tnc'|'audio'。
  ///
  /// 与 [connected] 的关系：[connected] 仍然表示「**发射来源**的链路是否可用」，
  /// 它的值由 [_refreshConnected] 从本表推导 —— 这样老代码（连接卡片、
  /// 状态栏、通知）无需分辨多选，行为也不变。
  final Map<String, bool> _linkUp = {};

  // ─── 网关（iGate）───
  /// 是否启用网关（把射频收到的报文送上 APRS-IS）
  bool igateEnabled = false;

  /// 双向网关：额外把 APRS-IS 上发往「刚在射频上听到过」的台站的消息
  /// 送到射频。**会真实发射**，所以默认关闭，需用户显式打开。
  bool igateTwoWay = false;

  /// 射频上收到的报文总数（无论网关开不开都计）。
  ///
  /// 为什么需要它：网关统计全是 0 时，用户无法区分下面两种完全不同的情况 ——
  ///   * 射频根本没收到报文（TNC 没连上 / 线速不对 / 静噪？）= 链路问题；
  ///   * 收到了但一条都没转递（被拒 / 去重）= 网关问题。
  /// 没有这个分子，界面上只有一连串 0，排查只能靠猜。
  int igateRfSeen = 0;

  /// 网关已转递到 APRS-IS 的报文数
  int igateGated = 0;

  /// 网关已转递到射频的报文数
  int igateToRf = 0;

  /// 因去重被丢弃的重复报文数（同一帧经多路径到达）
  int igateDupDropped = 0;

  final GateDedupe _igateDedupe = GateDedupe();

  /// 射频上近期听到过的台站（IS→RF 消息转递的依据）
  final HeardList _heard = HeardList();

  /// TNC 链路（KISS 参数、绑定设备、收发统计）
  final TncLink tnc = TncLink();

  /// 音频链路（AFSK 1200 声卡 TNC：采样/调制解调/收发统计）
  final AudioLink audio = AudioLink();

  /// PKWDWPL 链路（Kenwood `$PKWDWPL` 航点语句，**只收不发**）。
  ///
  /// 与 TNC 并列：同样走蓝牙 SPP / 串口，但线上是 NMEA 明文而行不是 KISS 帧，
  /// 且电台只单向输出。因此它参与「收」（台站上图/台账），不参与「发」。
  final PkwdwplLink pkwdwpl = PkwdwplLink();

  /// 发射是否走 TNC（射频）
  bool get usingTnc => dataSource == 'tnc';

  /// 发射是否走音频（声卡 TNC）
  bool get usingAudio => dataSource == 'audio';

  /// 各来源是否**已启用**（多选）
  bool get aprsIsOn => enabledSources.contains(srcAprsIs);
  bool get tncOn => enabledSources.contains(srcTnc);
  bool get audioOn => enabledSources.contains(srcAudio);
  bool get pkwdwplOn => enabledSources.contains(srcPkwdwpl);

  /// 是否有多条链路在同时工作（此时界面需要区分「发射来源」）
  bool get multiSource => enabledSources.length > 1;

  /// 某条链路的连通状态
  bool isUp(String src) => _linkUp[src] == true;

  /// **发射来源**那条链路是否可用。
  ///
  /// 这是 [connected] 的真实含义（`connected = isUp(dataSource)`）：
  /// 全应用的 `if (connected)` 守卫都只服务于**发射**（信标、消息、ack、
  /// 保活、连接状态文案），所以它表示「现在能不能发」才是对的。
  bool get txSourceUp => isUp(dataSource);

  /// 是否有任意一条**已启用**链路在收报文。
  ///
  /// 与 [connected] 的区别就是[只读模式]：只启用 PKWDWPL 时
  /// `connected` 为 false（没有发射链路），但报文照样在收 ——
  /// 通知栏、状态显示这类「有没有在工作」的判断必须用本 getter，
  /// 否则会显示成「未连接」，而实际台站已经在上图了。
  bool get rxActive => enabledSources.any(isUp);

  /// 只读模式：没有任何**可发射**的已启用来源（当前只可能是「只启用 PKWDWPL」）。
  ///
  /// 此时应用仍然完整可用（接收、地图、台账、距离方位），只是不会发射任何
  /// 报文。界面必须**明确说出来**，否则用户看到「位置未上报」「未连接」
  /// 会以为是坏了。
  /// 当前正在收报文的链路名（用于「仅接收」横幅）。
  ///
  /// 优先说出**非发射来源**的那条 —— 发射来源未连时，用户最需要知道的是
  /// 「那到底哪条在收」。
  String get rxSourceLabel {
    for (final s in [srcTnc, srcAudio, srcPkwdwpl, srcAprsIs]) {
      if (s != dataSource && isUp(s)) return _sourceName(s);
    }
    for (final s in [srcAprsIs, srcTnc, srcAudio, srcPkwdwpl]) {
      if (isUp(s)) return _sourceName(s);
    }
    return '—';
  }

  bool get readOnlyMode => !enabledSources.any(canTransmit);

  // ─── 设备占用检测（防止两条链路抢同一台设备）───
  //
  // 为什么必须有：TNC 与 PKWDWPL 都走 SPP / 串口，**两条链路连同一台设备时
  // 接收字节流会被瓜分** ——
  //   * 串口：两个句柄都能打开（共享模式），读到的字节各拿一部分；
  //   * 蓝牙：第二条 RFCOMM 连接会直接顶掉第一条。
  // 症状是「一条能发不能收」或两条都收不全，而**发送完全正常**，所以从界面上
  // 根本看不出原因（用户只会看到「收不到台站了」）。所以宁可在选择与连接时
  // 就拦住，而不是连上之后让人去猜。

  /// 某设备当前被哪条链路**绑定**（null = 没被绑定）
  String? deviceBoundBy(String? deviceId) {
    if (deviceId == null || deviceId.isEmpty) return null;
    if (tnc.device?.id == deviceId) return srcTnc;
    if (pkwdwpl.device?.id == deviceId) return srcPkwdwpl;
    return null;
  }

  /// TNC 与 PKWDWPL 是否绑定了同一台设备（冲突）
  bool get tncPkwdwplConflict {
    final a = tnc.device?.id;
    return a != null && a.isNotEmpty && a == pkwdwpl.device?.id;
  }

  /// 是否有任意一条链路可用
  bool get anyLinkUp => enabledSources.any(isUp);

  /// 已启用且连上的射频来源（优先发射来源，其次 TNC，最后音频）
  String? get activeRfSource {
    if (usingRf && isUp(dataSource)) return dataSource;
    if (tncOn && isUp(srcTnc)) return srcTnc;
    if (audioOn && isUp(srcAudio)) return srcAudio;
    return null;
  }

  /// 网关是否具备工作条件（**配置层面**）：勾了至少一个射频来源。
  ///
  /// 注意这是「配了没有」，不是「通不通」—— 真正能不能转递要看 [igateActive]。
  /// 两者必须分开：勾选状态用来提示「去勾 TNC/音频」，连通状态用来提示
  /// 「链路没连上」，两者混成一个判断会让提示指向错误的方向。
  bool get igateReady => tncOn || audioOn;

  /// 射频来源是否**真的有链路在收**（与 [_gateRfToIs] 的真条件一致）。
  bool get igateRfUp => (tncOn && isUp(srcTnc)) || (audioOn && isUp(srcAudio));

  /// 网关此刻是否真的在转递：开关开着 + 射频在收 + APRS-IS 连着。
  ///
  /// [_gateRfToIs] 的守卫就是这三个条件，界面用它来判断「统计该不该涨」。
  bool get igateActive => igateEnabled && igateRfUp && isUp(srcAprsIs);

  /// 网关开了、条件却没齐时，返回**没齐的那一项**（界面直接显示）。
  ///
  /// 空字符串 = 条件齐了（此时统计不涨只能是因为没有射频流量或被拒，
  /// 那由 igateRfSeen / igateBlocked 两个数说明）。
  String get igateIdleReason {
    if (!igateEnabled) return '';
    if (igateActive) {
      // 条件齐了还一条都没转出去，只可能是**全被环路防护拒收** ——
      // 那是「在正确工作」，但用户看到 0 仍然会以为坏了，所以照样要说。
      return (igateRfSeen > 0 && igateGated == 0 && igateBlocked > 0)
          ? 'all-rejected'
          : '';
    }
    if (!igateReady) return 'no-rf-source';
    if (!igateRfUp) return 'rf-down';
    return 'is-down';
  }

  /// 按来源取射频中继路径
  String rfPathOf(String src) =>
      src == srcAudio ? audio.config.path : tnc.config.path;

  /// 是否为「射频频段」来源（TNC / 音频）。
  ///
  /// 二者在协议与合规上完全同类：都经电台上空、都用 APALOC 目的呼号、
  /// 都受 67 字符消息上限、都禁用群聊广播、自动发射都要显式开关。
  /// 因此射频相关判断统一用本 getter，避免只改 TNC 漏改音频
  /// （那会导致音频模式下群聊被放行、限长失效这类静默错误）。
  bool get usingRf => usingTnc || usingAudio;

  /// 当前射频来源的中继路径配置
  String get _rfPath => rfPathOf(dataSource);

  /// 数据来源的中文名（日志用；界面文案一律走 l10n）
  String _sourceName(String s) => s == srcTnc
      ? 'TNC（电台）'
      : (s == srcAudio
          ? '音频（声卡）'
          : (s == srcPkwdwpl ? 'PKWDWPL（Kenwood）' : 'APRS-IS'));

  static const String srcAprsIs = 'aprsis';
  static const String srcTnc = 'tnc';
  static const String srcAudio = 'audio';

  /// PKWDWPL（Kenwood 航点语句）——**只收不发**的来源
  static const String srcPkwdwpl = 'pkwdwpl';

  /// 可发射的来源（用于「至少要保留一条能发射的链路」与各种发射守卫）。
  ///
  /// 写成集合而不是各处硬写三个比较，是因为以后再加只读来源时
  /// 漏改一处就会出现「发射走了只读链路」这类静默错误。
  static const Set<String> txCapableSources = {srcAprsIs, srcTnc, srcAudio};

  /// 某个来源能否发射
  static bool canTransmit(String src) => txCapableSources.contains(src);

  /// 发射路径 —— 报头目的呼号统一用本应用的 toCall `APALOC`。
  ///
  /// 两种数据来源都用 `APALOC`，这样第三方（aprs.fi 过滤、统计站、地图站
  /// 以及本应用的台站识别）都能凭 tocall 精确筛出 APRSLocus 台站，
  /// 不会与其它 APRS 软件（同样用 `APRS` 作目的呼号）混淆：
  ///   * APRS-IS：`APALOC,TCPIP*`
  ///   * TNC / 音频（射频）：`APALOC` 后接用户配置的中继（如 WIDE1-1,WIDE2-1）
  ///
  /// ⚠️ 勿改回 `APRS`：v1.6.103 曾误将 APRS-IS 模式写成 `APRS,TCPIP*`，
  /// 导致按 `u/APALOC` 订阅的第三方统计站只能收到状态包、收不到位置包
  /// （表现为这些台站在统计站上没有位置）。回归测试见
  /// test/beacon_format_test.dart「发射路径的目的呼号」。
  String get txPath {
    if (!usingRf) return 'APALOC,TCPIP*';
    final p = _rfPath.trim();
    // 去掉头部逗号/空格，避免出现 `APALOC,,WIDE1-1`
    final cleaned = p.replaceAll(RegExp(r'^[,\s]+'), '');
    return cleaned.isEmpty ? 'APALOC' : 'APALOC,$cleaned';
  }

  /// 启用/停用某条链路（多选）。
  ///
  /// 不能把最后一个来源关掉 —— 那样应用会变成「什么都不收」，
  /// 而界面上又没有任何东西提示，比报错更难排查。
  Future<void> toggleSource(String src, bool on) async {
    final s0 = _normalizeSrc(src);
    if (on) {
      if (enabledSources.contains(s0)) return;
      enabledSources.add(s0);
    } else {
      if (!enabledSources.contains(s0)) return;
      if (enabledSources.length <= 1) {
        _log(LogLevel.warn, '连接', '至少要保留一个数据来源');
        return;
      }
      enabledSources.remove(s0);
      // 关掉的正好是发射来源 → 换一个还在用的。
      //
      // 优先换**能发射**的来源；一个都没有时（例如只留了 PKWDWPL）就保持原值
      // 不动 —— 此时进入 [readOnlyMode]，台站照收、照上图，只是不再发射。
      //
      // ⚠️ 这里**刻意允许**只剩只读来源：拿电台当纯接收机用（挂机收台站/
      // 记台账）是完全合理的用法，早期版本把它当成配置错误挡掉了，是过度的
      // 家长式判断。只留只读来源带来的后果（不会发射）由界面明说，见
      // [readOnlyMode] 与主页横幅。
      if (dataSource == s0) {
        dataSource =
            enabledSources.firstWhere(canTransmit, orElse: () => dataSource);
      }
    }
    if (s0 == srcTnc || s0 == srcAudio) {
      // 射频链路的去重表与「听到过」列表都是**跨会话累积**的：换了设备、
      // 线速或频段之后，旧表会把新链路上的**首次**报文当成重复丢掉，
      // 表现正是「网关统计一直是 0」（连「重复丢弃」也不涨时最难查）。
      // 表该清；但**统计不该清** —— 用户正需要它来对比「换配置之前 / 之后」
      // 到底有没有好转，清了就再也比不出来。
      _igateDedupe.clear();
      _heard.clear();
    }
    _reconcileSources();
    persist();
    _notify();
    _updateNotification();
  }

  /// 确保某条链路处于「已启用」状态（幂等）。
  ///
  /// 给**设备页的手动连接**用：用户在那里点了「连接」，意图就是让这条链路上线
  /// 工作，那就必须同时把它算作已启用 —— 否则会进入一个**自相矛盾的状态**：
  /// 链路已连上、报文也在收，但界面上全部显示未连接。
  ///
  /// 为什么界面看不出来：「当前链路」卡遍历 [enabledSources]（未启用就整行不渲染）、
  /// 主页横幅只能表达「发射来源通不通」、[anyLinkUp] 也只数已启用的链路。
  /// 于是「PKWDWPL 已连上」这件事在主界面上没有任何地方能体现，
  /// 用户看到的就是「一直显示未连接」。
  ///
  /// 不调 [_reconcileSources]：调用方刚连上，不需要再去对齐一次链路。
  void ensureSourceEnabled(String src) {
    final s0 = _normalizeSrc(src);
    if (enabledSources.contains(s0)) return;
    enabledSources.add(s0);
    _log(LogLevel.info, '连接', '${_sourceName(s0)} 已加入数据来源（设备页手动连接）');
    persist();
    _notify();
    _updateNotification();
  }


  /// 设备页**手动**连接某条链路之后调用：把结果同步回 AppState。
  ///
  /// 为什么必须有它：两个设备页都是**直接**调链路对象的 `connect()` /
  /// `disconnect()` 的（不经过 [_connectTnc] / [_connectPkwdwpl] 那条自动连接
  /// 路径），于是有两件事不会自动发生，而它们各自都会让界面与事实不符：
  ///
  ///   ① [_linkUp] 表不会更新。[connected] 是从它推导的
  ///      （`connected = isUp(dataSource)`），而任何 _setLinkUp 都会重算一遍 ——
  ///      所以手动连接后写 `connected = true` 只能维持到下一次重算，
  ///      之后又变回 false，表现为「连上了却一直显示未连接」。
  ///   ② 来源没置为启用时，「当前链路」卡整行不渲染（它遍历 enabledSources），
  ///      主页横幅也只能说「未连接 APRS-IS 服务器」。
  ///
  /// 一句话：**设备页的连接事件必须回到 AppState 这台账本上**。
  void adoptDeviceLink(String src, bool up) {
    final s0 = _normalizeSrc(src);
    if (up) ensureSourceEnabled(s0);
    _setLinkUp(s0, up);
    _notify();
    _updateNotification();
  }

  /// 设备页连接**之前**的守卫：返回 null 表示可以连，否则返回不可连的原因。
  ///
  /// 为什么不能只把关卡放在 [_connectTnc] / [_connectPkwdwpl] 里：那两个方法
  /// 只在 AppState 自己的自动连接路径上跑，而**设备页是直接调链路对象的**，
  /// 不过那一关。所以设备页必须先问这个。
  ///
  /// 语义刻意不对称：
  ///   * **TNC** 是发射链路，优先 —— 冲突时先把 PKWDWPL 断开让出设备，返回 null；
  ///   * **PKWDWPL** 是只读链路 —— 冲突时直接拒绝，避免抢走 TNC 的接收字节流。
  Future<String?> guardDeviceConnect(String src) async {
    final s0 = _normalizeSrc(src);
    if (!tncPkwdwplConflict) return null;
    if (s0 == srcTnc) {
      _log(
        LogLevel.warn,
        '连接',
        'TNC 与 PKWDWPL 绑定了同一台设备（${tnc.device?.label}）：'
            '已先断开 PKWDWPL，把设备让给 TNC（两条链路同时连会瓜分接收数据，'
            '表现为「能发不能收」）。',
      );
      await pkwdwpl.disconnect(manual: false);
      _setLinkUp(srcPkwdwpl, false);
      return null;
    }
    if (s0 == srcPkwdwpl) {
      pkwdwpl.lastError = 'device-in-use';
      return 'device-in-use';
    }
    return null;
  }

  /// 指定**发射**来源（必须已启用）
  void setTxSource(String src) {
    final s0 = _normalizeSrc(src);
    if (!enabledSources.contains(s0) || dataSource == s0) return;
    // 只读来源永远不能成为发射来源（UI 也不给它圆点，这是第二道防线）
    if (!canTransmit(s0)) return;
    dataSource = s0;
    _log(LogLevel.info, '连接', '发射来源切换为 ${_sourceName(s0)}');
    persist();
    _refreshConnected();
    _notify();
    _updateNotification();
  }

  String _normalizeSrc(String src) => src == srcTnc
      ? srcTnc
      : (src == srcAudio
          ? srcAudio
          : (src == srcPkwdwpl ? srcPkwdwpl : srcAprsIs));

  /// 让「实际链路」与「已启用集合」对齐：新启用的连上，取消启用的断开。
  ///
  /// 只在「本来就在工作」时才顺手连上新勾选的来源（[wasActive]）：
  ///   * 用户已经连上在收报文时勾一条新链路 → 立刻连上，符合直觉；
  ///   * 用户还没点连接（或刚手动断开）时勾选 → 只做准备、不偷偷发起连接。
  ///     这一点很重要：否则「勾一下」会变成一次真实的网络/蓝牙操作，
  ///     既意外（用户只是想改配置），也让人无法先配好再连。
  Future<void> _reconcileSources() async {
    final wasActive = anyLinkUp || _connectingAll;
    // 断掉不再需要的
    if (!aprsIsOn && isUp(srcAprsIs)) {
      aprs.disconnect();
      _setLinkUp(srcAprsIs, false);
    }
    if (!tncOn && isUp(srcTnc)) await tnc.disconnect(manual: false);
    if (!audioOn && isUp(srcAudio)) await audio.disconnect(manual: false);
    if (!pkwdwplOn && isUp(srcPkwdwpl)) {
      await pkwdwpl.disconnect(manual: false);
    }
    _setLinkUp(srcTnc, tnc.connected);
    _setLinkUp(srcAudio, audio.connected);
    _setLinkUp(srcPkwdwpl, pkwdwpl.connected);
    // 连上新启用的（仅当本来就在工作）
    if (wasActive && !_userDisconnected) await _connect();
  }

  /// 由各链路状态推导「发射来源是否可用」。
  ///
  /// 统一从这里推导，而不是让各条连接逻辑各自去写 `connected = true/false`
  /// —— 多选之后那样写必然出现「IS 已断但界面显示已连接」这类错乱。
  void _refreshConnected() {
    connected = isUp(dataSource);
  }

  /// 仅测试用：直接设置某条链路的连通状态。
  ///
  /// 生产代码不要用它 —— 正常路径是各条链路的连接逻辑调用 [_setLinkUp]。
  @visibleForTesting
  void debugSetLinkUp(String src, bool up) => _setLinkUp(src, up);

  void _setLinkUp(String src, bool up) {
    _linkUp[src] = up;
    _refreshConnected();
  }

  /// 该链路是否因**设备冲突**而根本不可能连上。
  ///
  /// 用于让重连逻辑跳过它 —— 否则会变成**无限重连**：
  /// [_scheduleReconnectIfNeeded] 的判据是「全部 enabledSources 都 up」，
  /// 而被冲突拦下的 PKWDWPL 永远不可能 up，于是定时器会 8→16→32→60 秒
  /// 无休止地重试下去（用户看不到任何变化，只浪费电）。
  bool blockedByConflict(String src) =>
      _normalizeSrc(src) == srcPkwdwpl && tncPkwdwplConflict;

  /// 该链路是否处于「重试也没用」的失败状态。
  ///
  /// 为什么要单独判它：这类链路**永远不可能连上**，若照常排重连，定时器就
  /// 会一直空转。空转不只是耗电 —— 每次 tick 都会走一遍 [_connect]，
  /// 而旧实现里那会**反复重建 APRS-IS 连接并泄漏 socket**（见
  /// `net/aprs_io.dart` 的 connect 注释），于是报文被重复处理、越用越卡。
  ///
  /// 只把**确定性**的原因算作永久失败：未绑定设备 / 平台不支持 /
  /// 被设备冲突拦下。「没权限」不算 —— 用户授权后就能连上。
  bool _permanentlyDown(String src) {
    switch (_normalizeSrc(src)) {
      case srcTnc:
        return tnc.device == null ||
            tnc.lastError == TncStatus.noDevice ||
            tnc.lastError == TncStatus.unsupported;
      case srcAudio:
        // 音频没有「设备绑定」概念，只有「平台不支持」是永久性的
        return audio.lastError == 'unsupported';
      case srcPkwdwpl:
        return blockedByConflict(srcPkwdwpl) ||
            pkwdwpl.device == null ||
            pkwdwpl.lastError == 'no-device' ||
            pkwdwpl.lastError == 'unsupported' ||
            pkwdwpl.lastError == 'device-in-use';
      default:
        return false;
    }
  }

  /// 「该做的都做完了」：每条已启用链路要么通了、要么不可能通/重试也没用。
  ///
  /// 专门抽出来避免两处重连判断（排程时、定时器触发时）写得不一致 ——
  /// 只改一处就会漏成无限重连。
  bool get _allExpectedLinksUp => enabledSources.every(
      (s) => isUp(s) || blockedByConflict(s) || _permanentlyDown(s));

  /// 任一已启用来源掉线就安排重连（不是只看发射来源）
  void _scheduleReconnectIfNeeded() {
    if (_userDisconnected) return;
    if (_allExpectedLinksUp) return;
    _scheduleReconnect();
  }

  // 坐标显示：'wgs84' 标准 / 'gcj' 高德火星坐标
  String coordDatum = 'wgs84';

  // 深色模式
  bool darkMode = false;

  // 顶栏天气组件（和风天气：当前位置天气 + 温度）
  bool weatherEnabled = true;

  /// **公告横幅**（设置 → 显示）。默认**开**：用户要的是「用户可以打开」，
  /// 而默认关等于没人看得见 —— 公告的意义就在于被看到。不想要的人可以关掉，
  /// 关掉后**不再发起网络请求**（见 notice_banner.dart）。
  bool noticeBanner = true;

  /// 切换顶栏天气组件
  void setWeatherEnabled(bool v) {
    weatherEnabled = v;
    persist();
    _notify();
  }

  void setNoticeBanner(bool v) {
    noticeBanner = v;
    persist();
    _notify();
  }

  // 界面语言：'' = 跟随系统；'zh' 中文；'en' English
  String locale = '';

  // ─── 界面材质（磨砂玻璃 / 云母）───
  //
  // 存字符串（'' = 关闭）而不是 bool：材质是**多档**的，将来加一档
  // （例如「亚克力」或「跟随系统」）不需要改存储格式，也不会让旧值变成乱码。
  // 认不出的值一律回落「关闭」（见 uiMaterialOf）。
  String uiMaterial = '';

  /// 切换界面材质。
  ///
  /// 切完必须调 [applySavedTheme]：材质写在 C 这个全局调色板上，它不在
  /// ThemeData 里，所以除了重算没有别的生效路径（否则表现就是「点了没反应」，
  /// 要退出重进才生效）。
  void setUiMaterial(String v) {
    final n = uiMaterialOf(v);
    uiMaterial = uiMaterialName(n);
    applySavedTheme();
    persist();
    _notify();
  }

  /// 当前材质的枚举形式（界面直接读这个）
  UiMaterial get uiMaterialValue => uiMaterialOf(uiMaterial);

  // ─── 界面布局（v1.6.139 的「UI 2.0」）───
  //
  // 同为显示偏好，与材质独立可组合：'' = 1.0 经典布局，'sheet' = 2.0 地图为基底。
  // 认不出的值一律回落 1.0 —— 布局选错会让人找不到导航，比颜色错严重得多。
  String uiLayout = '';

  /// 切换界面布局。
  ///
  /// 切完同样要 [applySavedTheme]（布局写在 C 这个全局调色板上，除了重算没有
  /// 别的生效路径）；App 侧的 `_onThemeChange` 会发现 uiLayout 变了并重建。
  void setUiLayout(String v) {
    uiLayout = uiLayoutName(uiLayoutOf(v));
    applySavedTheme();
    persist();
    _notify();
  }

  UiLayout get uiLayoutValue => uiLayoutOf(uiLayout);

  /// 切换界面语言
  void setLocale(String lang) {
    locale = lang;
    // 界面语言变了，翻译的默认目标语言也要跟着变
    TranslateService.instance.setUiLocale(lang);
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
    applySavedTheme();
    persist();
    _notify();
  }

  /// 设置自定义主题色
  void setThemeColor(String hex) {
    final v = hex.trim().replaceAll('#', '').toUpperCase();
    themeColor = v;
    // 当前主题已经把主色固定下来时，同步改主题里的那一项 ——
    // 否则用户在「显示」里点颜色会毫无反应（被主题覆写盖住），像功能坏了。
    final tc = ThemeController.instance;
    final a = tc.active;
    if (a.overridesColor('primary') && !a.builtin) {
      a.colors['primary'] = v;
      tc.upsert(a);
    }
    applySavedTheme();
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

  /// 应用已保存的主题（App 启动时调用）。
  ///
  /// 颜色来源分两层：**主题的令牌覆写优先，其次才是旧版的单一 themeColor**。
  /// 保留第二层是有意的：老用户只存过 `themeColor`，升级后颜色必须原样不变。
  void applySavedTheme() {
    // 材质与布局要在 applyColors **之后**写：后者会重算整套调色板（并且自己也读
    // C.materialOn 来决定页面底色透不透），所以两者必须先落定，
    // 否则换主题那一下会用上一档材质算出一套错的 alpha。
    C.material = uiMaterialValue;
    C.layout = uiLayoutValue;
    ThemeController.instance.applyColors(
      isDark: darkMode,
      legacyPrimary: themeColorValue,
    );
  }

  /// 主题版本号：主题页改动后它 +1，App 据此重建 MaterialApp（不动导航栈）
  int get themeRevision => ThemeController.instance.revision;

  // 定位来源：false = 系统 GPS；true = 模拟位置（手动坐标）
  bool useSimLocation = false;

  void setUseSimLocation(bool v) {
    useSimLocation = v;
    if (v) {
      // 切到模拟位置：没有真实位移可判，传感器监听一并停掉（省电）
      unawaited(MotionService.instance.stop());
      // 切换到模拟：不再需要 GPS，但需要前台服务保活（见 startTracking）
      unawaited(startTracking());
      if (myLat == null || myLng == null) {
        // 无手动坐标时用默认演示坐标
        setMyPosition(39.9042, 116.4074);
      } else {
        myHasFix = true;
        locStatus = '模拟位置';
        _syncFilterToPosition(); // 已有坐标：切模拟时同样同步过滤中心
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

  // ─── 离线地图 ───
  /// 浏览地图时把瓦片写入本机磁盘缓存（默认开；关掉则完全不落盘）
  bool tileCacheOn = true;

  void setTileCacheOn(bool v) {
    tileCacheOn = v;
    persist();
    _notify();
  }

  /// 仅离线模式：只用已缓存/已下载的瓦片，一个网络请求都不发（野外省流量）
  bool offlineOnly = false;

  void setOfflineOnly(bool v) {
    offlineOnly = v;
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

  // ─── ADIF 导出选项 ───
  // 记忆用户上次的选择，避免每次导出台都要重设。
  // 空串（而非 null）表示「不写」—— SharedPreferences 没有 null 语义。
  /// MODE 值；空串 = 不写
  String adifMode = 'PKT';
  bool adifSubMode = true;
  /// BAND 值；空串 = 不写
  String adifBand = '';
  /// FREQ 值（MHz，已规范化）；空串 = 不写
  String adifFreq = '';
  bool adifStripSsid = false;

  /// 组装为编码器使用的选项
  AdifOptions get adifOptions => AdifOptions(
    mode: adifMode.isEmpty ? null : adifMode,
    subModeAprs: adifSubMode,
    band: adifBand.isEmpty ? null : adifBand,
    freq: adifFreq.isEmpty ? null : adifFreq,
    stripSsid: adifStripSsid,
  );

  void setAdifOptions(AdifOptions o) {
    adifMode = o.mode ?? '';
    adifSubMode = o.subModeAprs;
    adifBand = o.band ?? '';
    adifFreq = o.freq ?? '';
    adifStripSsid = o.stripSsid;
    persist();
    _notify();
  }

  // 接收范围过滤（APRS-IS filter: r/lat/lng/radius_km）
  double filterLat = 39.9042;
  double filterLng = 116.4074;
  int filterRadius = 300; // km
  int maxStations = 100000; // 台站上限（默认无限制，可下调）

  /// 数据包列表上限（历史记录条数）。原先硬编码 200，偏少。
  int maxPackets = 2000;

  /// 单个台站的轨迹点数上限。原先硬编码 60，导致运动轨迹显示很不完整。
  int maxTrackPts = 300;
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

  /// 传感器辅助定位：用加速度计判断是否真的在移动、用指南针补正低速航向。
  /// 仅 Android 生效（见 lib/motion.dart），其它平台上开关无效、不影响使用。
  bool sensorAssist = true;

  void setLabLandscape(bool v) {
    labLandscape = v;
    persist();
    _applyOrientation();
    _notify();
  }

  /// 传感器辅助开关：打开时若正在定位就立刻启动传感器监听，
  /// 关闭时立刻注销 —— 不能让传感器在用户关掉它之后还在后台采样耗电。
  void setSensorAssist(bool v) {
    if (sensorAssist == v) return;
    sensorAssist = v;
    if (v) {
      if (loc.running) unawaited(MotionService.instance.start());
    } else {
      unawaited(MotionService.instance.stop());
    }
    persist();
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
  final Map<String, DateTime> _groupReadAt = {};

  /// 群聊协议消息去重表：`呼号|原文` → 上次处理时间。
  ///
  /// 同一帧可能经多条路径重复送达（同时连 APRS-IS 与射频、或经 iGate 回环），
  /// 没有这层过滤时同一次「确认加入」会反复插系统消息、反复弹通知。
  final Map<String, DateTime> _seenProtoMsgs = {}; // 群聊已读时间点（groupId → 时间）
  static const int _maxLogs = 500;
  int packetsRx = 0;
  int packetsTx = 0;
  final List<DateTime> _rxTimes = [];

  /// 最近 60 秒内收到的数据包数（即当前接收速率，包/分）
  int get rxPerMin => _rxTimes.length;

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

  /// **真正发到服务器去的那些点**（信标点），画在地图上与轨迹区分开。
  ///
  /// 为什么不从 [myTrack] 里挑：轨迹点会被抽稀、封顶（[maxTrackPts]）、
  /// 确认跳变时还会整条清空 —— 那是「屏幕上这条线好看」的语义。而「这个点
  /// 我发出去了」是个**事实**，不该被抽稀或封顶吃掉，也不该因为随后跳变
  /// 确认而消失（aprs.fi 上确实已经收到了）。所以另存一份，且只在
  /// **真的发出去**（connected）时记。
  ///
  /// 上限 [maxBeaconMarks]：只用于地图标注，不需要全量历史 ——
  /// 全量在按天的台账里（见 TrackLogStore）。
  final List<TrackPt> beaconMarks = [];
  static const int maxBeaconMarks = 200;

  /// 「转弯打点」的最低速度（km/h）：低于它的航向变化一律不算转弯。
  /// 静止时 GPS 航向是噪声、指南针也会被身边铁器带偏，不设这道闸
  /// 就会出现「停着不动也一直上报」。
  static const double _kTurnMinSpeedKmh = 5;

  /// 「转弯打点」两次之间的最小间隔（秒）：防止连续弯道上把信道刷满。
  /// 30° 阈值在发卡弯上几秒就能满足一次，而 APRS 是共享信道。
  static const double _kTurnMinGapSec = 20;

  Station? get myStation => myHasFix
      ? Station(
          call: myCall,
          symbol: beaconSymbolNow,
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
      // 迁移：老版本会把 'APRSlocus 移动台' 当作默认备注存下来。
      // 用户从未改过它的话，现在视为「空」，以符合「备注默认清空」的预期。
      if (myComment == _legacyDefaultComment) myComment = '';
      beaconEnabled = p.getBool('beacon') ?? beaconEnabled;
      beaconAutoAsked = p.getBool('beaconAutoAsked') ?? beaconAutoAsked;
      beaconInterval = p.getInt('beaconInterval') ?? beaconInterval;
      smartBeaconEnabled =
          p.getBool('smartBeaconOn') ?? smartBeaconEnabled;
      final smartJson = p.getString('smartTiers');
      if (smartJson != null && smartJson.isNotEmpty) {
        try {
          final list = jsonDecode(smartJson) as List;
          smartTiers
            ..clear()
            ..addAll(list
                .map((j) => SmartBeaconTier.fromJson(j as Map<String, dynamic>)));
        } catch (_) {}
      }
      _ensureSmartTiers();
      _normalizeSmartTiers();
      beaconIncludeSpeed =
          p.getBool('beaconIncludeSpeed') ?? beaconIncludeSpeed;
      beaconIncludeCourse =
          p.getBool('beaconIncludeCourse') ?? beaconIncludeCourse;
      beaconIncludeBattery =
          p.getBool('beaconIncludeBattery') ?? beaconIncludeBattery;
      beaconIncludeHr = p.getBool('beaconIncludeHr') ?? beaconIncludeHr;
      bleHrId = p.getString('bleHrId') ?? bleHrId;
      bleHrName = p.getString('bleHrName') ?? bleHrName;
      // 只恢复「记住的是哪台」，不自动连（权限/设备不在身边时静默失败更困惑）
      if (bleHrId.isNotEmpty) {
        bleHr.deviceId = bleHrId;
        bleHr.deviceName = bleHrName;
      }
      // 佳明：恢复链接，但**不自动开跑** —— 分享链接是有时效的（活动结束后
      // 页面就没点了），开机自动去抓一个过期链接只会刷错误日志。
      garminUrl = p.getString('garminUrl') ?? garminUrl;
      garminOn = false;
      coordDatum = p.getString('coordDatum') ?? coordDatum;
      darkMode = p.getBool('darkMode') ?? darkMode;
      weatherEnabled = p.getBool('weatherEnabled') ?? weatherEnabled;
      noticeBanner = p.getBool('noticeBanner') ?? noticeBanner;
      locale = p.getString('locale') ?? locale;
      themeColor = p.getString('themeColor') ?? themeColor;
      uiScale = p.getDouble('uiScale') ?? uiScale;
      // 界面材质：认不出的值（改坏 / 将来新增档位）一律回落「关闭」
      uiMaterial = uiMaterialName(
        uiMaterialOf(p.getString('uiMaterial') ?? uiMaterial),
      );
      uiLayout = uiLayoutName(
        uiLayoutOf(p.getString('uiLayout') ?? uiLayout),
      );
      mapType = p.getString('mapType') ?? mapType;
      // 离线地图：缓存开关与「仅离线」模式
      tileCacheOn = p.getBool('tileCacheOn') ?? tileCacheOn;
      offlineOnly = p.getBool('offlineOnly') ?? offlineOnly;
      updateChannel = p.getString('updateChannel') ?? updateChannel;
      adifMode = p.getString('adifMode') ?? adifMode;
      adifSubMode = p.getBool('adifSubMode') ?? adifSubMode;
      adifBand = p.getString('adifBand') ?? adifBand;
      adifFreq = p.getString('adifFreq') ?? adifFreq;
      adifStripSsid = p.getBool('adifStripSsid') ?? adifStripSsid;
      locationMode = p.getString('locationMode') ?? locationMode;
      loc.mode = locationMode;
      useSimLocation = p.getBool('useSimLocation') ?? useSimLocation;
      filterLat = p.getDouble('filterLat') ?? filterLat;
      filterLng = p.getDouble('filterLng') ?? filterLng;
      filterRadius = p.getInt('filterRadius') ?? filterRadius;
      maxStations = p.getInt('maxStations') ?? maxStations;
      maxPackets = p.getInt('maxPackets') ?? maxPackets;
      onlineWindowMin = p.getInt('onlineWindowMin') ?? onlineWindowMin;
      // 同步到模型层，供 effectiveStatus / 地图绘制使用
      _applyOnlineWindow();
      maxTrackPts = p.getInt('maxTrackPts') ?? maxTrackPts;
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
      // 功能引导已读集合（见 lib/guide.dart）
      try {
        final gseen = p.getStringList('guideSeen');
        if (gseen != null) guideSeen..clear()..addAll(gseen);
      } catch (_) {}
      labLandscape = p.getBool('labLandscape') ?? labLandscape;
      sensorAssist = p.getBool('sensorAssist') ?? sensorAssist;
      oobeDone = p.getBool('oobeDone') ?? oobeDone;
      aprs.server = p.getString('server') ?? aprs.server;
      aprs.port = p.getInt('port') ?? aprs.port;
      aprs.passcode = p.getString('passcode') ?? aprs.passcode;
      dataSource = p.getString('dataSource') ?? dataSource;
      // 容错：非法/旧值一律回落 APRS-IS，避免多来源判断失配。
      // pkwdwpl 是**只读**来源，即使旧配置里存了它也不能当发射来源。
      if (!canTransmit(dataSource)) {
        dataSource = srcAprsIs;
      }
      // 多选来源：旧版本只存了单个 dataSource，这里做一次迁移
      // （把旧值当成唯一启用项），避免升级后「什么都没启用」。
      final savedSrcs = p.getStringList('enabledSources');
      enabledSources.clear();
      if (savedSrcs != null && savedSrcs.isNotEmpty) {
        for (final v in savedSrcs) {
          final n = _normalizeSrc(v);
          enabledSources.add(n);
        }
      } else {
        enabledSources.add(dataSource);
      }
      // 发射来源必须落在已启用集合里，否则启动后永远连不上。
      // 注意不能直接取 first：集合里可能只有 pkwdwpl（只读），那样发射就没有落点。
      if (!enabledSources.contains(dataSource)) {
        dataSource = enabledSources.firstWhere(
          canTransmit,
          orElse: () => srcAprsIs,
        );
      }
      igateEnabled = p.getBool('igateEnabled') ?? igateEnabled;
      igateTwoWay = p.getBool('igateTwoWay') ?? igateTwoWay;
      await tnc.load();
      await audio.load();
      await pkwdwpl.load();
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
      // 主题要在 applySavedTheme 之前加载：后者会读当前主题的令牌覆写
      await ThemeController.instance.load(p);
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
    unawaited(persistNow());
    _notify();
  }

  /// 保存当前设置并**等到写入调用完成**。
  ///
  /// 与 [persist] 的区别：那个是「调用即返回」的顺手保存，适合 UI 上的每次改动；
  /// 这个可以被 await —— 备份导出前必须用它。SharedPreferences 的 setX 会同步
  /// 更新内存缓存（磁盘写入才是异步的），所以 await 到这里，导出读到的就一定是新值。
  /// 少了这一步，刚改完设置就导出会**静默导出旧值**——比报错难发现得多。
  Future<void> persistNow() async {
    try {
      final p = await SharedPreferences.getInstance();
      await _writePrefs(p);
    } catch (_) {}
  }

  /// [persistNow] 的真正写入口（抽出来是为了让「导出前落盘」与「顺手保存」共用同一份键列表）
  Future<void> _writePrefs(SharedPreferences p) async {
    await p.setString('myCall', myCall);
    await p.setInt('mySsid', mySsid);
    await p.setString('mySymbol', mySymbol);
    await p.setString('myComment', myComment);
    await p.setBool('beacon', beaconEnabled);
    await p.setBool('beaconAutoAsked', beaconAutoAsked);
    await p.setInt('beaconInterval', beaconInterval);
    _ensureSmartTiers();
    await p.setBool('smartBeaconOn', smartBeaconEnabled);
    await p.setString(
        'smartTiers',
        jsonEncode(smartTiers.map((t) => t.toJson()).toList()));
    await p.setBool('beaconIncludeSpeed', beaconIncludeSpeed);
    await p.setBool('beaconIncludeCourse', beaconIncludeCourse);
    await p.setBool('beaconIncludeBattery', beaconIncludeBattery);
    await p.setBool('beaconIncludeHr', beaconIncludeHr);
    await p.setString('bleHrId', bleHrId);
    await p.setString('bleHrName', bleHrName);
    await p.setString('garminUrl', garminUrl);
    await p.setString('coordDatum', coordDatum);
    await p.setBool('darkMode', darkMode);
    await p.setBool('weatherEnabled', weatherEnabled);
    await p.setBool('noticeBanner', noticeBanner);
    await p.setString('locale', locale);
    await p.setString('themeColor', themeColor);
    await p.setDouble('uiScale', uiScale);
    await p.setString('uiMaterial', uiMaterial);
    await p.setString('uiLayout', uiLayout);
    await p.setString('mapType', mapType);
    await p.setBool('tileCacheOn', tileCacheOn);
    await p.setBool('offlineOnly', offlineOnly);
    await p.setString('updateChannel', updateChannel);
    await p.setString('adifMode', adifMode);
    await p.setBool('adifSubMode', adifSubMode);
    await p.setString('adifBand', adifBand);
    await p.setString('adifFreq', adifFreq);
    await p.setBool('adifStripSsid', adifStripSsid);
    await p.setString('locationMode', locationMode);
    await p.setBool('useSimLocation', useSimLocation);
    await p.setDouble('filterLat', filterLat);
    await p.setDouble('filterLng', filterLng);
    await p.setInt('filterRadius', filterRadius);
    await p.setInt('maxStations', maxStations);
    await p.setInt('maxPackets', maxPackets);
    await p.setInt('onlineWindowMin', onlineWindowMin);
    await p.setInt('maxTrackPts', maxTrackPts);
    await p.setBool('filterFollow', filterFollow);
    await p.setStringList('receiveCountries', receiveCountries);
    await p.setStringList('guideSeen', guideSeen.toList());
    await p.setBool('receiveOthers', receiveOthers);
    await p.setBool('labLandscape', labLandscape);
    await p.setBool('sensorAssist', sensorAssist);
    await p.setBool('oobeDone', oobeDone);
    await p.setString('server', aprs.server);
    await p.setInt('port', aprs.port);
    await p.setString('passcode', aprs.passcode);
    await p.setString('dataSource', dataSource);
    await p.setStringList('enabledSources', enabledSources.toList());
    await p.setBool('igateEnabled', igateEnabled);
    await p.setBool('igateTwoWay', igateTwoWay);
    if (myHasFix && myLat != null && myLng != null) {
      p.setDouble('myLat', myLat!);
      p.setDouble('myLng', myLng!);
    }
    // 保存消息
    final msgsJson = jsonEncode(messages.map((m) => m.toJson()).toList());
    await p.setString('messages', msgsJson);
    // 保存群聊
    final groupsJson = jsonEncode(
      chatGroups.map((g) => g.toJson()).toList(),
    );
    await p.setString('chatGroups', groupsJson);
    // 主题（含用户自建的全部主题与当前激活项）
    await ThemeController.instance.saveTo(p);
  }

  /// 仅保存消息列表到本地
  void _saveMessages() {
    unawaited(_saveMessagesNow());
  }

  /// 消息列表 + 两套已读时间点落盘（可 await，供备份导出前强制刷新）
  Future<void> _saveMessagesNow() async {
    try {
      final p = await SharedPreferences.getInstance();
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
    } catch (_) {}
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
    // 翻译配置（接口、密钥、语言、每会话偏好）在启动时载入：
    // 消息页可能在用户还没进设置前就要用它（自动翻译）。
    unawaited(TranslateService.instance.load());
    // 翻译的「我的语言」默认跟随界面语言（见 TranslateService.uiLocale）
    TranslateService.instance.setUiLocale(locale);
    unawaited(ensureMembersLoaded());
    unawaited(AchievementCenter.instance.ensureLoaded());
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
    aprs.onLine = (l) => _onAprsLine(l, rf: false);
    aprs.onDisconnected = () {
      if (_disposed) return;
      _setLinkUp(srcAprsIs, false);
      final manual = _userDisconnected;
      setConnStatus(manual ? ConnPhase.manual : ConnPhase.linkLostServer,
          seconds: 8);
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
    _wireTnc();
    _wireAudio();
    _wirePkwdwpl();
    // 蓝牙心率带：状态变化只影响 UI 与信标备注，通知一次即可。
    bleHr.onChanged = () {
      if (_disposed) return;
      // **必须把读数同步到 `myHr`**：地图上的心率胶囊、上报横杠上的 ❤、以及信标
      // 备注里的 `HR=` 读的都是 `myHr`；而设置页那张卡直接读 `bleHr.bpm`。
      // 这里如果只 `_notify()`，就会出现「设置页显示已连接、也有读数，**主屏幕却
      // 一直没有心率、信标也不带 HR**」—— 用户实测报的就是这个（同步漏了一处）。
      //
      // 优先级：胸带（BLE）比手表准，所以**它有读数时优先用它**；没有读数且已断开时，
      // 若佳明没在供数据就清空（避免主屏一直显示一个过期读数）。
      final b = bleHr.bpm;
      if (b != null && b > 0) {
        myHr = b;
      } else if (!bleHr.connected && !(garmin.on && garmin.fresh)) {
        myHr = null;
      }
      _notify();
    };
    // 佳明 LiveTrack：每个新点都当作一次「自己」的定位（见 _onGarminPoint）。
    garmin.onPoint = _onGarminPoint;
    garmin.onChanged = () {
      if (_disposed) return;
      _notify();
    };
    // 「分享给 APRSlocus」：佳明 App 把 LiveTrack 链接分享进来 → 存下并直接开跑。
    shareIn.onShared = _onSharedIncoming;
    unawaited(shareIn.ensureInit());
    _simTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (devMode) _simTick();
    });
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_disposed) return;
      // 自动定时上报仅在链路可用时进行；未连接不发送（避免误以为在上报）。
      // TNC 模式下还需用户显式开启「射频信标」（见 canAutoBeacon）。
      // 上报判据：**定时到了，或者走够了**（智能信标的距离打点）。
      //   * 定时那条是老行为，保证「哪怕原地不动也定期报个平安」；
      //   * 距离那条专治「走得快时两点之间被拉成直线、拐弯全被抹平」——
      //     走得快就按距离补点，停下来距离不动、自然退回纯定时。
      // 两条都不成立时什么都不做（不空转、不 notify）。
      if (canAutoBeacon && myHasFix) {
        final sinceSec =
            DateTime.now().difference(_lastBeacon).inSeconds.toDouble();
        final dueByTime = sinceSec >= beaconIntervalNow;
        final minDistM = beaconMinDistNow;
        final dueByDist = minDistM > 0 && beaconDistMovedM >= minDistM;
        final minTurn = beaconMinTurnNow;
        // 转弯那条额外两道闸（缺一个都会变成「每个点都发」）：
        //   * **行驶中才算**（≥5 km/h）：停着不动时航向本来就是噪声，
        //     而指南针/多普勒在低速下的抖动足以越过 45°；
        //   * **距上次至少 20 秒**：连续发卡弯上 30° 阈值可能几秒就满足一次，
        //     不设最小间隔会把信道刷满 —— 各家智能信标都带速率上限正是这个原因。
        final dueByTurn = minTurn > 0 &&
            sinceSec >= _kTurnMinGapSec &&
            (mySpeed ?? 0) >= _kTurnMinSpeedKmh &&
            beaconTurnDeg >= minTurn;
        if (dueByTime || dueByDist || dueByTurn) _sendBeaconNow();
      }
      // 台站“有效状态”翻转（如超 5 分钟变离线、移动→静止）时才推进版本并通知，
      // 否则不触发任何页面重建；无翻转只刷新秒级 UI（tick）。
      if (_bumpStatusVersionIfChanged()) _notify();
      _checkStationAchievement();
      // 每秒刷新：只通知“秒级 UI”（信标倒计时/收包速率），
      // 不再全量 _notify() 重建整个页面树
      tick.value++;
    });
    // 连接保活：APRS-IS 空闲超时约 30s，无发送时发状态帧防止被踢
    _keepaliveTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      // TNC（射频）模式下**不发保活帧**：射频频段是全共享资源，
      // 每 15 秒播一次客户端版本号纯属占用信道（且与「信标」语义不同，
      // 会被其他台站当成无意义报文），故仅在 APRS-IS 下生效。
      // 判据是「APRS-IS 是否启用」而不是「发射来源是否射频」：
      // 多选模式下可能是「APRS-IS + TNC」且发射走 TNC，此时 IS 链接
      // 仍然需要保活帧，否则会被服务器踢掉（网关也就跟着断了）。
      if (!aprsIsOn) return;
      if (!connected || _userDisconnected) return;
      if (DateTime.now().difference(_lastTx).inSeconds < 25) return;
      // 保活：发送身份/在线状态帧。tocall=APALOC（本应用官方注册标识），
      // body=APRSLocus CONNECT（区分于位置信标；不再用非标 “保持连接”）
      final raw =
          '$myFullCall>APALOC,TCPIP*:>APRSlocus CONNECT v$appVersion $platformTag';
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

  /// 手动「退出应用」前的清理：保存设置、停止定位服务、断开 APRS-IS。
  /// 与 dispose() 的区别：不销毁通知器/控制器（调用后立即退出进程，无需再重建）。
  Future<void> shutdownForExit() async {
    _simTimer?.cancel();
    _tickTimer?.cancel();
    loc.stop();
    aprs.disconnect();
    // 射频链路也要断开（原先只断 APRS-IS）：退出后蓝牙 socket / 串口句柄
    // 应当立即释放，不能等进程被杀 —— BluetoothSocket 不关会占住电台，
    // 下次打开应用重连会失败。
    unawaited(pkwdwpl.disconnect(manual: false));
    unawaited(tnc.disconnect(manual: false));
    unawaited(audio.disconnect(manual: false));
    if (_stationsDirty) _saveStations();
    persist();
    // 个人历史台账也要落盘：手动「退出应用」是原生直接结束进程，
    // dispose() **不会被调用** —— 台账的落盘节流是 8 秒，不在这里 flush，
    // 最后一段轨迹就丢了。
    await TrackLogStore.instance.flush();
    // 留出时间让 SharedPreferences / 台站文件写入落盘
    await Future.delayed(const Duration(milliseconds: 400));
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
    // 把内存里攒着、还没到节流时间的台账落盘（退出后不丢最后几个点）
    unawaited(TrackLogStore.instance.flush());
    aprs.disconnect();
    // 射频链路也要收尾（原先只释放了 APRS-IS）：
    // pkwdwpl 的传输层持有一个 EventChannel 订阅，不释放会一直挂在平台通道上；
    // TNC 同样有 reader/writer 线程与 socket。
    unawaited(pkwdwpl.disconnect(manual: false));
    unawaited(tnc.disconnect(manual: false));
    unawaited(audio.disconnect(manual: false));
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
      if (_disposed || _userDisconnected) return;
      // 全部连上（或因设备冲突不可能连上）才算不需要重连
      // —— 多选模式下只连上一半也要继续补；但被冲突拦下的链路要跳过，
      //    否则永远达不到「都连上」而变成无限重连。
      if (_allExpectedLinksUp) return;
      _connect();
    });
  }

  /// 把 TNC 链路接入既有报文管线。
  ///
  /// 关键点：TNC 收到的报文直接交给 [_onAprsLine] —— 与 APRS-IS 完全同一条
  /// 解析路径。这样台站上图、消息收发、过滤、成就等逻辑无需为 TNC 再写一套，
  /// 也不会出现两个来源行为不一致的分叉。
  void _wireTnc() {
    tnc.onLine = (l) => _onAprsLine(l, rf: true);
    tnc.onClosed = () {
      if (_disposed) return;
      _setLinkUp(srcTnc, false);
      final manual = _userDisconnected;
      // ⚠️ 重连绝不能被「要不要改横幅」的条件挡住。
      //
      // 原写法在这里 `if (!usingTnc && !multiSource) return;` 直接返回，把
      // 后面的 _scheduleReconnect() 一起跳过了 —— 而**默认配置正好命中这个
      // 条件**（只启用 APRS-IS，dataSource=aprsis）。后果是 TNC 链路一旦断开
      // 就**静默地永不重连**：不写日志、不改连接状态、不重连，用户只能看到
      // 「收不到报文了」，而界面上找不到任何线索。
      //
      // 那个条件的本意只是：横幅表达的是「发射来源通不通」，一条非发射来源
      // 断了不必去改横幅。所以它只应该影响日志/状态文案，而不是整个流程。
      final bannerRelevant = usingTnc || multiSource;
      if (bannerRelevant) {
        setConnStatus(manual ? ConnPhase.manual : ConnPhase.linkLostTnc,
            seconds: 8);
        _log(
          manual ? LogLevel.info : LogLevel.warn,
          '连接',
          manual ? '已手动断开 TNC' : 'TNC 链路断开，稍后自动重连',
        );
      } else if (!manual) {
        // 非发射来源也要留日志：这条链路静默死掉过，日志是唯一能回溯的证据。
        _log(LogLevel.warn, '连接', 'TNC 链路断开（当前不是发射来源），稍后自动重连');
      }
      // 诊断：链路是不是**刚发射完就断**。射频频段上这个相关性很关键 ——
      // 要么是模块在半双工切换时掉线（硬件/供电），要么是写失败后
      // socket 被关闭（此时 lastTxError 会写明原因）。把证据落到日志里，
      // 就不用靠猜「有概率」到底发生在哪一步。
      final ack = tnc.lastTxAckAt;
      if (!manual && ack != null) {
        final gap = DateTime.now().difference(ack);
        if (gap.inSeconds <= 5) {
          _log(LogLevel.warn, '连接',
              '链路在发射后 ${gap.inMilliseconds}ms 断开'
              '（累计发 ${tnc.txFrames} 帧 / 确认写出 ${tnc.txAckedBytes} 字节'
              '${tnc.txErrors > 0 ? ' / 写失败 ${tnc.txErrors} 次' : ''}'
              '${tnc.lastTxError.isEmpty ? '' : ' / 最后错误：${tnc.lastTxError}'}）');
        }
      }
      _notify();
      _updateNotification();
      if (!_userDisconnected && tnc.config.autoReconnect) _scheduleReconnect();
    };
    // TNC 的接收计数/状态由 TncLink 自行维护（rxFrames/txFrames），
    // 这里只做 UI 节流刷新，避免每个字节都全量重建页面。
    tnc.onStateChanged = () {
      if (_disposed) return;
      if (usingTnc) _notifyRx();
    };
  }

  // ─── 网关（iGate）───

  /// RF → IS：把射频上收到的报文送上 APRS-IS。
  ///
  /// 判据与改写都在 [Igate] 里（纯函数、有测试），这里只负责
  /// 「取条件 → 去重 → 发送 → 计账」。**去重是必须的**：同一帧会经不同
  /// 中继路径多次到达，不去重会让互联网上出现多条一模一样的报文。
  void _gateRfToIs(String line) {
    // 先记账再判条件：射频到底有没有收到报文，与网关开不开、IS 通不通无关。
    // 这是「统计恒为 0」时唯一能自证的数字（见 [igateRfSeen] 的注释）。
    //
    // 但「链路没连上」这一条必须排在记账之前：射频链路是断的却还在冒数，
    // 只能说明**有别的链路在往同一条管线里灌**（同时绑了同一台设备、
    // APRS-IS 被当成射频…）。那时这个数就是假的 —— 而“假的自证数字”
    // 比“没有数字”更糟：用户会拿它去证明「射频没问题」，然后往错的方向查。
    if (!igateRfUp) return;
    igateRfSeen++;
    if (!igateEnabled || !isUp(srcAprsIs)) return;
    final d = Igate.toIs(tnc2: line, myFullCall: myFullCall);
    if (!d.ok) {
      // 环路相关的拒绝要留痕：如果日志里频繁出现 from-is / has-q-construct，
      // 说明有人在射频上重放互联网报文，值得用户知道
      if (d.reason == 'from-is' || d.reason == 'has-q-construct') {
        if (igateBlocked++ % 20 == 1) {
          _log(LogLevel.debug, '网关', '拒绝转递（${d.reason}）：${_trunc(line)}');
        }
      } else if (_igateRejectLog++ % 50 == 1) {
        // 其余拒绝（own-packet / malformed / empty-body）原先完全不留痕：
        // 网关一条都没转，日志里却什么也看不到，只能靠猜。
        _log(LogLevel.debug, '网关',
            '未转递（${d.reason}）· 射频已收 $igateRfSeen 条：${_trunc(line)}');
      }
      return;
    }
    if (!_igateDedupe.accept(Igate.dedupeKey(line),
        window: Igate.dedupeWindow)) {
      igateDupDropped++;
      return;
    }
    final out = Igate.toIsLine(
      tnc2: line,
      myFullCall: myFullCall,
      twoWay: igateTwoWay,
    );
    if (out == null) return;
    aprs.send(out);
    igateGated++;
    _lastTx = DateTime.now();
    if (_packetsGatedLog++ % 10 == 1) {
      _log(LogLevel.info, '网关', '已转递 $igateGated 条 → APRS-IS');
    }
  }

  /// 累计被拒的 RF→IS 转递数（含环路拒收），仅用于日志节流与诊断
  int igateBlocked = 0;
  int _packetsGatedLog = 0;

  /// RF→IS 的「未转递」日志节流计数（与 IS→RF 的 [_gateRejectLog] 分开：
  /// 合用一个的话，两个方向的报文会互相抢节流额度）
  int _igateRejectLog = 0;

  /// IS → RF：把 APRS-IS 上发往「刚在射频上听到过」的台站的消息送到射频。
  ///
  /// **会真实发射**，所以需要 [igateTwoWay] 显式打开。只转点对点消息
  /// （位置/天气等广播报文转了只会占满信道，判据见 [Igate.toRf]）。
  /// 最近一次 IS→RF 未转递的原因（供界面显示，避免「静默不工作」）
  String igateLastReject = '';

  /// 「射频听到过」的台站数（界面用来判断 heard 列表是否为空）
  int get igateHeardCount => _heardCache.length;

  /// 「听到过」集合缓存。
  ///
  /// 追加 `t/m` 之后会收到**全球**消息，如果每来一条就重建一次
  /// 「听到过」集合（`HeardList.active()` 是 O(n)），流量大时纯属浪费。
  /// 这里按秒缓存：1 秒的滞后对「最近听到过」的语义毫无影响。
  Set<String> _heardCache = {};
  DateTime _heardCacheAt = DateTime.fromMillisecondsSinceEpoch(0);

  Set<String> _heardActive() {
    final now = DateTime.now();
    if (now.difference(_heardCacheAt).inMilliseconds > 1000) {
      _heardCache = _heard.active();
      _heardCacheAt = now;
    }
    return _heardCache;
  }

  void _gateIsToRf(String line) {
    if (!igateEnabled || !igateTwoWay) return;
    final rfSrc = activeRfSource;
    if (rfSrc == null) {
      igateLastReject = 'no-rf-link';
      return;
    }
    final d = Igate.toRf(
      tnc2: line,
      heardOnRf: _heardActive(),
      myFullCall: myFullCall,
      allowMessages: true,
    );
    if (!d.ok) {
      igateLastReject = d.reason;
      // 只对「本该转却没转」的情形留痕（not-a-message 是绝大多数广播包，
      // 全部记下来会把日志刷爆）
      if (d.reason != 'not-a-message') {
        if (_gateRejectLog++ % 20 == 1) {
          _log(LogLevel.debug, '网关', '未转递（${d.reason}）：${_trunc(line)}');
        }
      }
      return;
    }
    final out = Igate.toRfLine(tnc2: line, rfPath: rfPathOf(rfSrc));
    if (out == null) {
      igateLastReject = 'malformed';
      return;
    }
    // **只有真的交给链路才计数**。
    // 之前无论成败都 `igateToRf++`，于是「允许发射」关掉时界面照样显示
    // 「已转递 N 条」，而信道上一个字节都没出去 —— 这正是本次要修的
    // 那类「看起来在工作」的假象。
    final err = _sendVia(rfSrc, out);
    if (err != null) {
      igateLastReject = 'tx-refused: $err';
      _log(LogLevel.warn, '网关', '转递射频失败（$err）：${_trunc(out)}');
      return;
    }
    igateToRf++;
    igateLastReject = '';
    _log(LogLevel.info, '网关', '已转递 $igateToRf 条 → 射频（${
        rfSrc == srcTnc ? 'TNC' : '音频'}）');
  }

  int _gateRejectLog = 0;

  /// 记录射频上听到的台站（IS→RF 转递的依据）
  void _noteHeard(String line) {
    final gt = line.indexOf('>');
    if (gt <= 0) return;
    final call = line.substring(0, gt).trim();
    _heard.heard(call);
    // 立刻反映到缓存：否则「刚听到就有一条发给它的消息」会因为缓存
    // 还是旧的而被判成 addressee-not-heard
    _heardCache = {..._heardCache, call.toUpperCase()};
    _heardCacheAt = DateTime.now();
  }

  /// 开关网关
  void setIgateEnabled(bool v) {
    igateEnabled = v;
    if (!v) igateTwoWay = false; // 网关关了就不该还留着「往射频转」的开关
    if (v) {
      // 三种「开了也白开」的情形要分开说：只报「没勾选」是不够的 ——
      // 勾了但链路没连上（线速不对 / 设备没开机 / IS 掉线）同样转不了，
      // 而那时的界面与日志与「已正常工作」完全一样（统计一直是 0）。
      if (!igateReady) {
        _log(LogLevel.warn, '网关',
            '未启用射频来源（TNC / 音频），网关没有可转递的射频链路');
      } else if (!igateRfUp) {
        _log(LogLevel.warn, '网关',
            '射频来源已勾选但链路未连上（TNC / 音频），网关暂时转递不了任何报文');
      }
      if (!aprsIsOn) {
        _log(LogLevel.warn, '网关', '未启用 APRS-IS，网关没有可转递的目标网络');
      } else if (!isUp(srcAprsIs)) {
        _log(LogLevel.warn, '网关',
            'APRS-IS 未连上，网关暂时没有可转递的目标网络');
      }
      if (igateActive) {
        _log(LogLevel.info, '网关', '网关条件已齐：射频接收 → APRS-IS 开始转递');
      }
      // 这里**刻意不清空统计**。
      //
      // 清空统计是 [resetIgateStats] 的职责（按钮，以及切换数据来源时）。
      // 若这里也清一遍，「统计一直是 0」就会被这个开关本身制造出来：
      // 数字不涨 → 用户把网关关了再开（最自然的第一反应）→ 数字归零 →
      // 再开回来也永远看不到它曾经涨过。诊断路径被自己的界面堵死，
      // 而且看起来像是「网关重新开始工作但依然什么都不转」。
      _igateDedupe.clear();
      _heard.clear();
    }
    _log(LogLevel.info, '网关', v ? '已启用网关' : '已停用网关');
    persist();
    _notify();
    _updateNotification();
    _refreshFilter();
  }

  /// 开关双向网关（IS→RF，会真实发射）
  void setIgateTwoWay(bool v) {
    igateTwoWay = v;
    if (v && !igateEnabled) igateEnabled = true;
    _log(LogLevel.info, '网关',
        v ? '已启用双向网关（会向射频转递消息）' : '已关闭双向网关（仅 RF→IS）');
    persist();
    _notify();
    _updateNotification();
    // 过滤器跟着变了（双向网关会追加 t/m）→ 必须让服务器重新下发，
    // 否则用户得自己想到「手动重连一次」才能真正生效。
    _refreshFilter();
  }

  /// 清空网关统计
  void resetIgateStats() {
    igateGated = 0;
    igateToRf = 0;
    igateDupDropped = 0;
    igateRfSeen = 0;
    igateBlocked = 0;
    igateLastReject = '';
    _igateDedupe.clear();
    _notify();
  }

  /// 把音频链路接入既有报文管线（与 [_wireTnc] 同一套做法）。
  ///
  /// 关键点同 TNC：音频解出的报文直接交给 [_onAprsLine]，三个数据来源
  /// 共用同一条解析路径，因此不会出现「音频模式下台站不上图」这类分叉。
  void _wireAudio() {
    audio.onLine = (l) => _onAprsLine(l, rf: true);
    audio.onClosed = () {
      if (_disposed) return;
      _setLinkUp(srcAudio, false);
      if (!usingAudio && !multiSource) return;
      final manual = _userDisconnected;
      setConnStatus(manual ? ConnPhase.manual : ConnPhase.linkLostAudio,
          seconds: 8);
      _log(
        manual ? LogLevel.info : LogLevel.warn,
        '连接',
        manual ? '已手动断开音频链路' : '音频采集被中断，稍后自动重连',
      );
      _notify();
      _updateNotification();
      if (!_userDisconnected && audio.config.autoReconnect) _scheduleReconnect();
    };
    // 接收计数/电平由 AudioLink 自行维护，这里只做 UI 节流刷新
    audio.onStateChanged = () {
      if (_disposed) return;
      if (usingAudio) _notifyRx();
    };
  }

  /// 把 PKWDWPL 链路接入既有台站管线。
  ///
  /// 与 TNC/音频的**根本差别**：那些链路解出来的是 APRS 报文（TNC2 文本），
  /// 所以能直接丢给 `_onAprsLine` 共用整套解析；而 PKWDWPL 是 Kenwood 自己的
  /// NMEA 语句，字段与 APRS 报文不同构，所以这里把它**转成 `ParsedPos`** 后
  /// 走同一个 `_upsertStation` —— 台站上图、筛选、台账、成就全部共用，
  /// 不会出现「另一个来源的台站不上图」这类分叉。
  ///
  /// 只收不发：本函数里没有任何 `_sendVia` 调用，且 [AppState.dataSource]
  /// 永远不会是 pkwdwpl（见 [canTransmit]）。
  void _wirePkwdwpl() {
    pkwdwpl.onFix = (fix) {
      if (_disposed) return;
      _onPkwdwplFix(fix);
    };
    pkwdwpl.onClosed = () {
      if (_disposed) return;
      _setLinkUp(srcPkwdwpl, false);
      // PKWDWPL 从不参与发射，所以它断了不影响「发射来源」是否可用：
      // 不要在这里改 connStatus，否则会把 TNC/APRS-IS 的正常状态盖掉。
      final manual = _userDisconnected;
      _log(
        manual ? LogLevel.info : LogLevel.warn,
        '连接',
        manual ? '已手动断开 PKWDWPL 链路' : 'PKWDWPL 链路断开，稍后自动重连',
      );
      _notify();
      _updateNotification();
      if (!_userDisconnected && pkwdwpl.config.autoReconnect) {
        // 用 IfNeeded 而不是直接重连：因**设备冲突**被主动断开时不该再排程重连
        // —— 它永远连不上，只会反复写「稍后自动重连」的日志骗人。
        _scheduleReconnectIfNeeded();
      }
    };
    pkwdwpl.onStateChanged = () {
      if (_disposed) return;
      if (pkwdwplOn) _notifyRx();
    };
  }

  /// 一条 `$PKWDWPL` 语句 → 台站 + 报文记录。
  void _onPkwdwplFix(PkwdwplFix fix) {
    final p = ParsedPos(
      lat: fix.latitude,
      lng: fix.longitude,
      symbol: fix.symbolCode,
      symbolTable: fix.symbolTable,
      comment: fix.comment,
      course: fix.courseDegrees,
      alt: fix.altitudeMeters,
      format: 'pkwdwpl',
    );
    _upsertStation(
      fix.callsign,
      p,
      // raw 原样存：详情页要能看到原始 NMEA 语句（排查电台输出格式用）
      raw: fix.raw,
      path: 'PKWDWPL',
      toCall: 'PKWDWPL',
    );
    _pushPacket(Packet(
      fix.raw,
      fix.callsign,
      'PKWDWPL',
      'position',
      DateTime.now(),
      info: '${fix.latitude.toStringAsFixed(4)}, '
          '${fix.longitude.toStringAsFixed(4)}'
          '${fix.courseDegrees == null ? '' : ' · ${fix.courseDegrees!.toStringAsFixed(0)}°'}'
          '${fix.checksumValid ? '' : ' · 校验不符'}',
    ));
    if (!fix.statusValid) {
      _log(LogLevel.debug, 'PKWDWPL', '${fix.callsign} 状态为 V（GPS 未定位）');
    }
    _notify();
  }

  /// 当前来源是否已打开「射频信标」。
  ///
  /// APRS-IS 无此概念（恒为 true）；TNC / 音频各自独立配置 —— 声卡接手持台
  /// 与蓝牙接车台的中继策略、发射许可常常不同，共用一个开关会互相干扰。
  bool get rfBeaconEnabled =>
      !usingRf || (usingTnc ? tnc.config.rfBeacon : audio.config.rfBeacon);

  /// 射频来源下「信标开着、但射频信标没开」——即倒计时不会走动、也不会发射。
  ///
  /// 单独抽出来是因为三个界面（设置页/地图胶囊/沉浸页）都要用它来决定
  /// 「显示倒计时还是显示原因 + 开启入口」；各写一遍必然漂移。
  bool get beaconNeedsRfEnable => beaconEnabled && usingRf && !rfBeaconEnabled;

  /// 打开当前来源的「射频信标」。供「倒计时不动」的提示条一键修复用。
  ///
  /// 刻意做成**显式动作**而不是收到定位就自动打开：射频发射需要持照操作，
  /// 必须由用户点这一下才算知情同意（见 canAutoBeacon 的注释）。
  Future<void> enableRfBeacon() async {
    if (usingTnc) {
      tnc.config.rfBeacon = true;
      await tnc.persistConfig();
    } else if (usingAudio) {
      audio.config.rfBeacon = true;
      await audio.save();
    }
    _log(LogLevel.info, '信标', '已打开射频信标（${_sourceName(dataSource)}）');
    _notify();
    _updateNotification();
  }

  /// 是否允许**自动**周期上报。
  ///
  /// 「会不会真的自动发出去」只有这一个出口 —— 散在两处必然漂移（见
  /// [beaconPhase] 的注释）。四个条件缺一不可：
  ///
  ///   ① 链路可用（[connected]）；
  ///   ② 信标开着（[beaconEnabled]）；
  ///   ③ **当前定位不是粗定位**（[myFixCoarse]）；
  ///   ④ 射频来源（TNC/音频）还需用户显式开启「射频信标」。
  ///
  /// ── 为什么粗定位（网络/基站/被动）不自动上报（v1.6.163）──
  ///
  /// 自动上报是「我在这里」的公开宣告，而粗点常年偏几百米、还会原地漂 ——
  /// 报出去的是个错坐标，收端（igate / 其他台站）看到的是一条乱跳的轨迹。
  /// 网络定位从此只用来「在地图上给个大概位置」，不进入信道；GPS 一回来
  /// 就自动恢复（倒计时按 [_lastBeacon] 算，所以那一刻会立刻补报一次）。
  /// **手动「立即上报」不受影响**：那是用户的显式动作，知情且即时。
  bool get canAutoBeacon => connected &&
      beaconEnabled &&
      !myFixCoarse &&
      (!usingRf || (usingTnc ? tnc.config.rfBeacon : audio.config.rfBeacon));

  /// 连接**所有已启用**来源（多选）。
  ///
  /// 顺序 await 而不是并发：蓝牙与音频都会占用有限的系统资源，
  /// 并发发起时先成功的那条容易被后一条的初始化打断；
  /// 顺序连接虽然慢一点，但每条的成败都能单独判定与重试。
  Future<void> _connect() async {
    // 重入保护：重连定时器、手动点连接、切来源可能在同一瞬间发起，
    // 两次连接会互相拆掉对方刚建好的链路（表现为「刚连上就断」）。
    if (_connectingAll) return;
    _connectingAll = true;
    try {
      // 只连**当前没连着**的链路。
      //
      // 这一步是防「反复重建」的关键闸门：重连定时器按「还有链路没上」触发，
      // 但真正要重试的只是那条掉线的链路，已连上的不应当被拆掉重连。
      //
      // 注意这里**不**用 `_permanentlyDown` 做跳过 —— 那个只用来决定
      // 「要不要再排重连」（见 [_allExpectedLinksUp]）。若在这里也跳过，
      // _connectPkwdwpl 里那段「记录 device-in-use 错误」的代码就永远
      // 到不了，用户点连接会没任何反馈。它的代价只是几个提前 return，
      // 不会造成空转。
      if (aprsIsOn && !isUp(srcAprsIs)) await _connectAprsIs();
      if (tncOn && !isUp(srcTnc)) await _connectTnc();
      if (audioOn && !isUp(srcAudio)) await _connectAudio();
      if (pkwdwplOn && !isUp(srcPkwdwpl)) await _connectPkwdwpl();
    } finally {
      _connectingAll = false;
    }
  }

  bool _connectingAll = false;

  /// APRS-IS 连接（原来的 `_connect` 主体）
  Future<void> _connectAprsIs() async {
    // 已经连着就别重建。
    //
    // 重连定时器每次 tick 都会走 [_connect]，而它无条件调本方法 ——
    // 若一条**别的**链路始终连不上，定时器就会反复重建 APRS-IS：
    // 每次新建一个 TCP socket、丢掉当前连接、重发过滤器与身份帧。
    // 旧实现甚至会把旧 socket 变成孤儿（见 `net/aprs_io.dart` 的注释），
    // 导致报文被重复处理、越用越卡。
    if (isUp(srcAprsIs)) return;
    if (connecting) return;
    connecting = true;
    setConnStatus(ConnPhase.connectingServer,
        arg: '${aprs.server}:${aprs.port}');
    _log(LogLevel.info, '连接', '正在连接 ${aprs.server}:${aprs.port}…');
    _notify();
    _updateNotification();
    aprs.callsign = myFullCall;
    aprs.filter = filterString;
    final ok = await aprs.connect();
    connecting = false;
    _setLinkUp(srcAprsIs, ok);
    if (ok) {
      _userDisconnected = false;
      _reconnectAttempt = 0; // 连接成功，重置重试计数
      passcodeInvalid = false; // 连接成功后重置，等待服务器验证
      _lastTx = DateTime.now();
      _lastFilter = aprs.filter; // 记录本次连接的过滤器
      setConnStatus(ConnPhase.online, arg: myCall);
      _log(LogLevel.info, '连接', '已连接 · $myCall 在线 (过滤: $filterString)');
      _flushPendingTx();
      // 连接成功即发一次身份状态帧（APRS 惯例：上报在线/客户端标识）
      aprs.send('$myFullCall>APALOC,TCPIP*:>APRSLocus CONNECT v$appVersion $platformTag');
      // 连接成功：若主界面已就绪且尚未问过“是否自动上报”，延迟触发询问。
      // 不在此置位 beaconAutoAsked —— 用户做出选择后才记位，避免漏弹后永久丢失。
      if (!beaconAutoAsked && beaconEnabled) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (_disposed) return;
          maybeAskBeaconAuto();
        });
      }
    } else {
      final backoff = [8, 16, 32, 60][_reconnectAttempt.clamp(0, 3)];
      setConnStatus(ConnPhase.retryServer, seconds: backoff);
      _log(LogLevel.error, '连接', '连接失败，${backoff} 秒后自动重试');
    }
    _notify();
    _updateNotification();
    // 失败继续自动重连
    _scheduleReconnectIfNeeded();
  }

  /// TNC（射频）连接。与 APRS-IS 的关键差异：
  ///   - 不发送 `>APRSlocus CONNECT` 身份帧（射频上发客户端版本号毫无意义，
  ///     只占信道；且它不是位置也不是消息，其他台站无法利用）；
  ///   - 不注册过滤器（过滤是 APRS-IS 服务端能力，射频频段只能全收）；
  ///   - passcode 不适用（RF 不过 APRS-IS 登录）。
  Future<void> _connectTnc() async {
    // 设备冲突：TNC 是发射链路，**优先级更高**。
    //
    // 两条链路连同一台设备会把**接收**字节流瓜分（串口两个句柄各读一部分、
    // 蓝牙第二条 RFCOMM 顶掉第一条）——症状正是「能发不能收」：发送走得通，
    // 所以从界面上完全看不出原因。这里主动把 PKWDWPL 让出来，而不是连上去
    // 之后让用户面对「收不到报文」。
    if (tncPkwdwplConflict) {
      _log(
        LogLevel.warn,
        '连接',
        'TNC 与 PKWDWPL 绑定了同一台设备（${tnc.device?.label}）：'
            '已先断开 PKWDWPL，把设备让给 TNC（两条链路同时连会瓜分接收数据，'
            '表现为「能发不能收」）。',
      );
      await pkwdwpl.disconnect(manual: false);
      _setLinkUp(srcPkwdwpl, false);
    }
    connecting = true;
    final name = tnc.device?.label ?? '未绑定设备';
    setConnStatus(ConnPhase.connectingTnc, arg: name);
    _log(LogLevel.info, '连接', '正在连接 TNC：$name');
    _notify();
    _updateNotification();
    final ok = await tnc.connect();
    connecting = false;
    _setLinkUp(srcTnc, ok);
    if (ok) {
      _userDisconnected = false;
      _reconnectAttempt = 0;
      passcodeInvalid = false;
      _lastTx = DateTime.now();
      setConnStatus(ConnPhase.tncConnected, arg: name);
      _log(LogLevel.info, '连接', 'TNC 已连接 · $name（KISS 参数已下发）');
      _flushPendingTx();
      if (beaconEnabled && !tnc.config.rfBeacon) {
        _log(LogLevel.warn, '信标',
            'TNC 模式下射频信标开关未打开，不会自动发射位置（可在设备页开启）');
      }
    } else {
      final backoff = [8, 16, 32, 60][_reconnectAttempt.clamp(0, 3)];
      setConnStatus(ConnPhase.retryTnc,
          arg: tnc.lastError, seconds: backoff);
      _log(LogLevel.error, '连接',
          'TNC 连接失败（${tnc.lastError}），${backoff} 秒后自动重试');
    }
    _notify();
    _updateNotification();
    _scheduleReconnectIfNeeded();
  }

  /// 音频（声卡 TNC）连接。与 TNC 的差异：没有「绑定设备」，连上即开始采集；
  /// 相同点：不发 APRSlocus CONNECT 身份帧、不注册过滤器、passcode 不适用。
  Future<void> _connectAudio() async {
    connecting = true;
    setConnStatus(ConnPhase.connectingAudio, arg: audio.backendName);
    _log(LogLevel.info, '连接', '正在打开音频采集（${audio.backendName}）…');
    _notify();
    _updateNotification();
    final ok = await audio.connect();
    connecting = false;
    _setLinkUp(srcAudio, ok);
    if (ok) {
      _userDisconnected = false;
      _reconnectAttempt = 0;
      passcodeInvalid = false;
      _lastTx = DateTime.now();
      final rate = audio.config.afsk.sampleRate;
      setConnStatus(ConnPhase.audioConnected, arg: '${rate}Hz');
      _log(LogLevel.info, '连接',
          '音频链路已建立 · AFSK 1200 @${rate}Hz（${audio.backendName}）');
      _flushPendingTx();
      if (beaconEnabled && !audio.config.rfBeacon) {
        _log(LogLevel.warn, '信标',
            '音频模式下射频信标开关未打开，不会自动发射位置（可在音频页开启）');
      }
    } else {
      final backoff = [8, 16, 32, 60][_reconnectAttempt.clamp(0, 3)];
      setConnStatus(ConnPhase.retryAudio,
          arg: audio.lastError, seconds: backoff);
      _log(LogLevel.error, '连接',
          '音频链路打开失败（${audio.lastError}），${backoff} 秒后自动重试');
    }
    _notify();
    _updateNotification();
    _scheduleReconnectIfNeeded();
  }

  /// PKWDWPL（Kenwood 航点语句）连接。
  ///
  /// 与其他射频链路一样：不发身份帧、不注册过滤器、passcode 不适用。
  /// 差别是它连上后什么都不用下发 —— 电台自己会持续输出语句，
  /// 我们只需要静静地分帧、校验、解析。
  Future<void> _connectPkwdwpl() async {
    // 与 TNC 抢同一台设备时拒绝连接：TNC 是发射链路，让它先。
    // 两条链路同时连会瓜分接收字节流（症状：TNC 能发不能收）。
    if (tncPkwdwplConflict) {
      pkwdwpl.lastError = 'device-in-use';
      // lastDetail 也要写：设备页的错误提示读的是 lastDetail，
      // 只设 lastError 会让 Toast 变成「连接失败，请检查配置：」后面空白。
      pkwdwpl.lastDetail = 'device-in-use';
      _setLinkUp(srcPkwdwpl, false);
      _log(
        LogLevel.warn,
        '连接',
        'PKWDWPL 与 TNC 绑定了同一台设备（${tnc.device?.label}），已拒绝连接：'
            '两条链路同时连会互相抢走接收数据（发送正常、收不到报文）。'
            '请到设备页给 PKWDWPL 换一台设备。',
      );
      _notify();
      _updateNotification();
      return;
    }
    connecting = true;
    final name = pkwdwpl.device?.label ?? '未绑定设备';
    setConnStatus(ConnPhase.connectingPkwdwpl, arg: name);
    _log(LogLevel.info, '连接', '正在连接 PKWDWPL：$name');
    _notify();
    _updateNotification();
    final ok = await pkwdwpl.connect();
    connecting = false;
    _setLinkUp(srcPkwdwpl, ok);
    if (ok) {
      _userDisconnected = false;
      _reconnectAttempt = 0;
      setConnStatus(ConnPhase.pkwdwplConnected, arg: name);
      _log(LogLevel.info, '连接', 'PKWDWPL 链路已建立 · $name（只收不发）');
    } else {
      // 只读链路失败不应占用「发射来源」的连接状态文案：
      // 记日志 + 自己的状态码就够了（界面上链路那行会显示红点）。
      _log(LogLevel.error, '连接',
          'PKWDWPL 连接失败（${pkwdwpl.lastError}），稍后自动重试');
    }
    _notify();
    _updateNotification();
    _scheduleReconnectIfNeeded();
  }

  /// 统一发送入口：按当前数据来源路由到 APRS-IS / TNC / 音频。
  ///
  /// 所有发报路径都必须经过它 —— 否则 TNC 模式下会出现
  /// 「界面上报成功、实际报文走 APRS-IS 发出」这类静默错误。
  void _sendRaw(String raw) {
    _sendVia(dataSource, raw);
  }

  /// 按指定来源发送（网关向射频转递时需要指定，而不是走「发射来源」——
  /// 否则把消息转给射频时会错误地从 APRS-IS 发出去，等于没转）。
  ///
  /// 返回 null 表示已交给链路，否则是错误码。返回值专门为网关而加：
  /// 网关必须知道「到底发出去了没有」，否则会像以前那样把失败也计入
  /// 「已转递」。
  String? _sendVia(String src, String raw) {
    // 只读链路：明确拒绝并留日志，而不是静默丢弃 ——
    // 「以为发出去了其实没发」比报错难查得多。
    if (!canTransmit(src)) {
      _log(LogLevel.warn, _sourceName(src), '该链路为只读，已拒绝发送：${_trunc(raw)}');
      return 'read-only';
    }
    if (src == srcTnc) {
      final err = tnc.sendTnc2(raw);
      if (err != null) {
        _log(LogLevel.warn, 'TNC', '发送失败（$err）：${_trunc(raw)}');
      }
      return err;
    }
    if (src == srcAudio) {
      // 音频发射是异步的（先 CSMA 再播放整段音频），这里只做「能否接受」
      // 的同步校验；真正的失败由 AudioLink 记日志并通过 onStateChanged 通知
      final err = audio.sendTnc2(raw);
      if (err != null) {
        _log(LogLevel.warn, '音频', '发送失败（$err）：${_trunc(raw)}');
      }
      return err;
    }
    aprs.send(raw);
    return null;
  }

  /// 测试发射：发一条**状态**报文（`>` 开头，不含坐标）。
  ///
  /// 为什么用状态包而不是位置包：测试不该改变本台站在 aprs.fi 等地图上的
  /// 位置，但不影响验证 —— 对方/网关的原始报文里能看到它，足以确认链路通。
  /// 返回 null 表示已交给链路，否则返回错误码（供 UI 本地化）。
  String? sendTestFrame() {
    if (!connected) return 'not-connected';
    final raw = LinkDiag.testFrame(myFullCall, txPath, appVersion);
    if (usingTnc) {
      final err = tnc.sendTnc2(raw);
      if (err != null) return err;
    } else if (usingAudio) {
      final err = audio.sendTnc2(raw);
      if (err != null) return err;
    } else {
      aprs.send(raw);
    }
    _lastTx = DateTime.now();
    _log(LogLevel.info, '测试', '已发出测试帧：${_trunc(raw)}');
    _pushPacket(Packet(
      raw,
      myFullCall,
      'APRS',
      'status',
      DateTime.now(),
      info: '链路测试',
    ));
    _notify();
    return null;
  }

  /// 报头里的目的呼号（不含中继列表）。
  /// 消息/ack 包用它 —— 收件人写在信息字段，报头目的呼号仍应是 toCall。
  String get _destHeader {
    final p = txPath;
    final comma = p.indexOf(',');
    return comma < 0 ? p : p.substring(0, comma);
  }

  /// 是否自动回复 ack。TNC 模式下可由用户在设备页关闭 ——
  /// 射频信道上每个 ack 都是一次真实发射，共用信道时需要能关掉。
  bool get _autoAckEnabled =>
      !usingRf || (usingTnc ? tnc.config.autoAck : audio.config.autoAck);

  // ─── TNC（射频）模式的消息能力限制 ───

  /// APRS101 规定单条消息文本上限（字符）
  static const int tncMaxMsgLen = 67;

  /// 当前数据来源下单条消息的长度上限；0 表示不限
  int get msgLenLimit => usingRf ? tncMaxMsgLen : 0;

  /// 当前射频来源的 AX.25 单帧字节上限（TNC / 音频各自可配）。
  ///
  /// 手写报文（数据包控制台）也要按它提示 —— 超限在射频上是直接拒发，
  /// 而 APRS-IS 那边是按 512 字节整行算，两者的限制不是一回事。
  int get rfMaxFrame => usingTnc ? tnc.config.maxFrame : audio.config.maxFrame;

  /// 群聊是否可用。射频模式下禁用（见 [sendGroupMessage] 的说明）
  bool get groupChatAllowed => !usingRf;

  /// 当前是否处于「有实际发射能力」的状态（用于 UI 提示）
  bool get rfActive => usingRf && connected;

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
      // 模拟位置不读 GPS，但**仍要启动前台服务保活**：
      // 否则切到后台后 APRS-IS 连接会被冻结、信标定时器停摆。
      // 该调用不需要定位权限（Android 侧 keepalive 模式已豁免）。
      await loc.startKeepAlive();
      locStatus = '模拟位置 · 后台保活';
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
      // 传感器与定位同生共死：没有定位就不需要判「在不在动」
      if (sensorAssist) unawaited(MotionService.instance.start());
    }
    return ok;
  }

  void stopTracking() {
    loc.stop();
    unawaited(MotionService.instance.stop());
    myHasFix = false;
    _resetSelfFix();
    locStatus = '定位已停止';
    _log(LogLevel.info, '定位', '定位已停止');
    _notify();
  }

  Future<void> _onFix(
    double lat,
    double lng,
    double alt,
    double speed,
    double bearing,
    bool lastKnown,
    double accuracy,
    String source,
  ) async {
    if (_disposed) return;
    if (useSimLocation) return; // 模拟位置模式下忽略 GPS 数据
    // ── 佳明 LiveTrack 在跑且还新鲜时，**手机 GPS 让位** ──
    //
    // 两路同时在更新「我的位置」会互相打架：手表比手机准，而手机一侧随时可能
    // 给出隧道/城市峡谷里的漂移点，把标记从手表的位置上拽走又拽回来。
    // 只在「佳明还新鲜」（120 秒内有新点）时让位：活动结束、手机没网、
    // 分享链接过期等情况下手机会自动接回来，不至于彻底没有位置。
    if (garmin.on && garmin.fresh) return;

    // ── 第一道（也是最后一道）闸：粗定位点 ──
    //
    // 症状（用户报的）：开着「GPS + 网络辅助」时，地图上的「我」会**飞来飞去**。
    //
    // 为什么原有的两道闸都拦不住它：
    //   ① 精度门控（原生 150m / 网络 80m）看的是**系统自报的 accuracy**，而
    //      基站/Wi-Fi 定位的精度字段经常报得很乐观（自报 20~40m，实际偏 200m+）；
    //   ② 跳变守卫的阈值是 30km —— 那是给「缓存点跨城市」调的，而网络粗点的
    //      漂移是 200m~3km，**整个落在阈值以下**，等于完全没被拦。
    //
    // 所以要按**来源**判，而不是只看精度：
    //   * 非 GPS（网络/基站/被动）的点，在「GPS 刚更新过」时一律丢弃 ——
    //     这才是「飞来飞去」的真正成因：GPS 在城市峡谷里一闪一断，
    //     粗点就在缝里把标记拉走再拉回，来回横跳；
    //   * GPS 真的停了 [_kCoarseHoldSec] 秒以上（室内/隧道）才允许粗点推动标记
    //     —— 宁可把它当「最后的保底」，也不能让它参与每一次抖动；
    //   * 粗点绝不进入静止防抖的滑窗、绝不推参照点、绝不写轨迹与历史台账、
    //     **绝不自动上报**（见 canAutoBeacon）、也不推动 APRS-IS 过滤中心。
    //
    // 也就是说：粗点的全部作用就是「GPS 真的没了时，地图上还给个大概位置」。
    // 它不产生任何对外的影响（信道、链路、轨迹、历史）。
    //
    // 还有一条容易漏的：闸必须在**传感器采样之前** —— 被丢掉的点没必要
    // 多跑一次平台通道。
    final coarse = !lastKnown && (source == 'network' || source == 'passive');
    // ── 粗定位点绝不许覆盖「佳明给的位置」──
    //
    // ⚠ 这一条必须写在 `coarse` **声明之后**：第一版我把它插在 `_onFix` 开头
    // （紧挨着「佳明让位」那条），本机 `dart format` 看不出问题，CI 的 analyze
    // 直接报 `referenced_before_declaration` + `read_potentially_unassigned_final`
    // —— 用到的变量要先声明，这种错误只能靠编译发现，别凭印象插代码。
    //
    // 为什么要挡：佳明**不新鲜**（活动结束 / 链接过期）时手机 GPS 会接回来，这是对的；
    // 但**粗定位**不行 —— 它会拿一个偏几百米的基站质心去替换手表给的位置，而此刻
    // 上报横杠多半显示着正常的倒计时（beaconPhase = counting），
    // 用户完全看不出「正在发一个错坐标」。宁可保持上一个（手表的）位置，等真 GPS 接回来。
    if (coarse && garmin.on) return;
    if (coarse) {
      final gapSec = _lastFixTime == null
          ? 1 << 30
          : DateTime.now().difference(_lastFixTime!).inSeconds;
      final jumpKm = _lastFixLat == null
          ? 0.0
          : haversine(_lastFixLat!, _lastFixLng!, lat, lng);
      // ① GPS 仍新鲜 → 粗点是噪声（**这就是「飞来飞去」的主因**）
      // ② GPS 已停更很久，而粗点自己一口气跳出去 [_kCoarseJumpKm] 以上 →
      //    不是一个可信的「原地兜底」，而是换个 Wi-Fi 就跳到街对面基站去了
      if (gapSec < _kCoarseHoldSec || jumpKm > _kCoarseJumpKm) {
        _log(
          LogLevel.debug,
          '定位',
          '忽略粗定位点（来源 $source）：'
          '距上次 GPS ${gapSec}s / 位移 ${jumpKm.toStringAsFixed(2)}km',
        );
        _notify();
        return;
      }
    }

    // 传感器辅助：拉一次最新的加速度计/指南针状态。
    // 同一次定位只拉这一次 —— 后面的静止判定与航向补正共用它，
    // 不为「用两次」而做两次平台通道往返。
    final motion = sensorAssist
        ? await MotionService.instance.refresh()
        : MotionSample.unknown;

    // ── 位置跳变守卫：不要用「瞬移的点」污染轨迹 ──
    //
    // 症状（用户报的）：轨迹每隔一会儿跳回一个旧位置、再跳回当前位置，来回横画。
    // 根因在 Android 侧（系统缓存的位置被当成实时定位、每 10 秒上报一次），已在那里
    // 修掉；这里守的是同一类问题的**其它来源**（网络定位漂移、IP 定位、跨平台差异）。
    //
    // 判据是「**短时间内**跨很远」：距上一轨迹点不到 [_kFixJumpWindowSec]、位移又超过
    // [_kFixJumpKm] 才算可疑 —— 单看距离会误伤「停车几小时后开出去」这种合法位移。
    // 可疑点先**只更新标记、不写轨迹**，连续 [_kFixConfirmNeed] 次都落在同一处
    // （彼此相距 < [_kFixConfirmKm]）才认账。
    //
    // 为什么用「连续确认」而不是直接丢弃：真的换了地方也必须能恢复，否则轨迹会永远
    // 卡在旧位置。确认后**清空轨迹从新位置重画**，而不是画一条横跨两地的直线 ——
    // 那条线是假的，比没有轨迹更误导。
    // 参照点是**上一次被接受的实时定位**，不是 `myTrack.last`：
    //   * 静止时不再写轨迹点 → myTrack.last 可能已经是几小时前的点，那时
    //     gapSec 必然超窗、守卫**整个失效**（正是本次改动引入的回归）；
    //   * myTrack 为空时（刚启动、清空数据、刚确认过跳变）原本完全没有守卫。
    if (!lastKnown && !coarse && _lastFixLat != null) {
      final dKm = haversine(_lastFixLat!, _lastFixLng!, lat, lng);
      // 「短时间内」跨很远才算跳变：中间本来就隔了很久的话，多半是合法位移
      // （设备刚开、GPS 丢了一阵），那种情况宁可画一条跨越空档的线，也别把轨迹清掉。
      final gapSec = DateTime.now().difference(_lastFixTime!).inSeconds;
      if (dKm > _kFixJumpKm && gapSec < _kFixJumpWindowSec) {
        final nearPending = _pendingFixLat != null &&
            haversine(_pendingFixLat!, _pendingFixLng!, lat, lng) < _kFixConfirmKm;
        if (nearPending) {
          _pendingFixCount++;
        } else {
          _pendingFixLat = lat;
          _pendingFixLng = lng;
          _pendingFixCount = 1;
        }
        if (_pendingFixCount < _kFixConfirmNeed) {
          _log(
            LogLevel.info,
            '定位',
            '疑似跳变，暂不记录：距上次可信位置 ${dKm.toStringAsFixed(1)}km'
                '（第 $_pendingFixCount 次，连续 $_kFixConfirmNeed 次一致才接受）',
          );
          // 标记也不动：先按「上一次可信位置」显示，避免地图上的「我」乱跳
          _notify();
          return;
        }
        _log(
          LogLevel.info,
          '定位',
          '位置确认已变化（${_pendingFixCount} 次一致）：轨迹从新位置重新开始',
        );
        myTrack.clear();
        _pendingFixLat = null;
        _pendingFixLng = null;
        _pendingFixCount = 0;
      } else {
        // 正常位移：清掉疑似计数
        _pendingFixLat = null;
        _pendingFixLng = null;
        _pendingFixCount = 0;
      }
    }

    // ── 最后一道闸：缓存位置只在「还没有过实时定位」时用 ──
    //
    // 原生侧在服务运行期间也会挡缓存点（Android 的 hasLiveFix），但**前台服务
    // 重启后那个标记会归零**（比如系统回收、切回前台重连），于是它可能再次放行
    // 一个几分钟前的缓存位置；而上层如果照收，标记就会被拉回旧位置 ——
    // 症状正是用户报过的「轨迹跳回初始点」。这里记住「已经有过实时定位」，把这条
    // 路径彻底封掉：缓存点此后只用来保证「有东西可显示」，不再改标记。
    if (lastKnown && _hadLiveFix) {
      _log(LogLevel.debug, '定位', '已有实时定位，忽略系统缓存位置');
      return;
    }

    // ── 静止防抖（A+B）：见 lib/pos_quality.dart 的 [SelfFixFilter] ──
    //
    // 定位**源头**只负责「把明显不可信的点丢掉」（Android 侧 150m 精度门控、
    // 网络点只在 GPS 停更时兜底、缓存点只在无实时定位时用）；而「可信但抖」
    // 的点一直没人管 —— 静止时 GPS 在 20~150m 之间飘是常态，轨迹会被画成一小团
    // 毛线球，信标上报的坐标也跟着哆嗦。这里做的就是把「可信但抖」修平。
    //
    // 只对**实时定位**做防抖：缓存位置（lastKnown）不是实时点，IP 定位是城市级
    // 粗点 —— 两者都不该进滑动窗口（会把中位数拉跑），也不该影响静止判定。
    final out = (lastKnown || coarse)
        ? (lat, lng, false)
        : _selfFilter.feed(
            lat,
            lng,
            speed * 3.6,
            accuracy,
            sensorMoving: motion.moving,
          );
    final outLat = out.$1;
    final outLng = out.$2;
    final still = out.$3;

    final first = !myHasFix;
    myLat = outLat;
    myLng = outLng;
    myAlt = alt;
    myHasFix = true;
    myFixCoarse = coarse;
    // 粗定位的精度**不能照抄系统自报值**：它常报 20~40m 却实际偏几百米，
    // 于是精度圈画得像 GPS 一样小，反而更骗人。给一个诚实的下限。
    myAccuracy = coarse
        ? (accuracy > _kCoarseAccuracyFloorM ? accuracy : _kCoarseAccuracyFloorM)
        : (accuracy > 0 ? accuracy : 0);
    if (!lastKnown && !coarse) {
      // 只有实时 **GPS** 才推进参照点与「有过实时定位」标记；
      // 缓存位置与粗定位都不算数（否则粗点会成为后续跳变判断的基准，
      // 把「GPS 回来时归位」也误判成一次跳变）。
      _lastFixLat = outLat;
      _lastFixLng = outLng;
      _lastFixTime = DateTime.now();
      _hadLiveFix = true;
    }
    // 速度 m/s → km/h；方位角度。
    // 静止时 GPS 也返回 speed=0/bearing=0，正常上报（000/000 表示静止）
    //
    // 粗定位**不更新速度与航向**：基站/Wi-Fi 定位没有多普勒，speed 常为 0、
    // bearing 常为 0（或上一次的残值）。照收会让信标误报「静止/朝北」，
    // 也会把沉浸页的航向朝上判定带偏。宁可沿用上一次 GPS 的值。
    if (!coarse) {
      mySpeed = speed * 3.6;
      // 航向：低速时 GPS 的 course 不可信（多普勒解不出方向，常为 0 或不更新），
      // 用指南针补正；正常行驶时仍用 GPS —— 磁力计在城里靠近铁/电机时会被干扰，
      // 高速下反而是 GPS 更可靠。阈值 3km/h：步行/推车/慢骑覆盖，跑步以上交给 GPS。
      if (bearing >= 0) myCourse = bearing;
      if (motion.hasCompass &&
          motion.heading >= 0 &&
          motion.moving &&
          mySpeed! < 3.0) {
        myCourse = motion.heading;
      }
    }
    locStatus = coarse ? '网络定位（粗）' : (still ? '静止' : '已定位');
    // 记录我的轨迹
    //
    // 三道门（缺一道就会出问题）：
    //   ① `lastKnown` 不写 —— 缓存点可能几小时前、甚至在另一个城市；
    //   ② **静止不写** —— 否则 GPS 抖动会被画成一团毛线球（这正是本次要修的）；
    //   ③ 精度太差（> [SelfFixFilter.trackAccuracyLimitM]）不写 ——
    //      弱信号下的点没信息量，只会把轨迹拉得东倒西歪。
    // 抽稀门限**按速度自适应**（见 PosQuality.trackMinDistM）：固定 20m 在步行时
    // 太粗、在高速时又太细。注意这只管**自己**的轨迹 —— 接收台站回到固定 20m
    // 的朴素行为（见 _upsertStation 顶部说明）。
    //
    // 落点判据是**两条任一**（见 PosQuality 里那两个常量）：
    //   * 位移 > 速度门限  → 拐弯不会被切角；
    //   * 距上个点 ≥ 最大间隔且确实挪了  → 慢速也有稳定密度。
    // 只有前一条时，速度越低点越疏（步行 8m 要 5.8s），而慢速正是用户最想
    // 看清细节的时候 —— 那条「保底」就是为此加的。
    final last = myTrack.isEmpty ? null : myTrack.last;
    if (!lastKnown &&
        !coarse &&
        !still &&
        accuracy <= SelfFixFilter.trackAccuracyLimitM) {
      final minDistM = PosQuality.trackMinDistM(speedKmh: speed * 3.6);
      final movedM = last == null
          ? double.infinity
          : haversine(last.lat, last.lng, outLat, outLng) * 1000;
      final gapSec = last == null
          ? double.infinity
          : DateTime.now().difference(last.time).inSeconds.toDouble();
      final keepAlive = gapSec >= PosQuality.trackMaxGapSec &&
          movedM >= PosQuality.trackMinMoveM;
      if (last == null || movedM > minDistM || keepAlive) {
        myTrack.add(TrackPt(outLat, outLng, DateTime.now()));
        if (myTrack.length > maxTrackPts) {
          myTrack.removeRange(0, myTrack.length - maxTrackPts);
        }
        // 个人历史台账（按天落盘）与屏幕轨迹分开写：只在「确实在动」时
        // 记，并带上速度/航向/精度，供事后按天统计里程与速度。
        TrackLogStore.instance.record(
          lat: outLat,
          lng: outLng,
          speedKmh: speed * 3.6,
          course: myCourse,
          alt: alt,
          accuracyM: accuracy,
        );
      }
    }
    // 过滤中心跟随我的位置
    //
    // **粗定位不推动过滤中心**（v1.6.163）：过滤串按 0.01°（约 1.1km）取整，
    // 粗点漂移几百米到 1km 就可能越过一条边界，而过滤串一变就会触发
    // [reconnect]（见 [_refreshFilter]）—— 拿一个几百米精度的点去换一次整条
    // 链路的重连，代价与收益完全不成比例。
    if (filterFollow && !coarse) {
      // 必须用**防抖后**的坐标：写成 `lng`（原始值）会让 APRS-IS 过滤中心
      // 拿「平滑过的纬度 + 未平滑的经度」去算，两轴不同步 —— 过滤中心自己
      // 就会抖，而它会触发重连（见 _refreshFilter）。
      filterLat = outLat;
      filterLng = outLng;
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
  /// 手动上报提示里的「实际附带了什么」。
  ///
  /// 用户问过「手动上报…没有附带心率？」—— 而提示那时只说网格，看不出带了什么。
  /// 这里如实列出：心率（有读数且开关开）／未附带心率（开关关或没读数）。
  String get beaconAttachedDetail {
    final l = l10n;
    if (beaconIncludeHr && myHr != null && myHr! > 0) {
      return l.beaconAttachedHr('$myHr bpm');
    }
    return l.beaconAttachedNone;
  }

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
      beaconSymbolNow,
      comment: _beaconComment(),
      path: txPath,
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
      _sendRaw(raw);
      _lastTx = DateTime.now();
      // 记下「这个点真的发出去了」并交给地图标注（见 [beaconMarks]）。
      // 放在 connected 分支内：未连接时只是本地记录，不算「发送到服务器的点」。
      final mark = TrackPt(lat, lng, DateTime.now());
      final prev = beaconMarks.isEmpty ? null : beaconMarks.last;
      // 同一位置反复发（静止档 300s 一次）不必堆重叠标记，隔开才有信息量
      if (prev == null ||
          haversine(prev.lat, prev.lng, lat, lng) * 1000 >= 5) {
        beaconMarks.add(mark);
        if (beaconMarks.length > maxBeaconMarks) {
          beaconMarks.removeRange(0, beaconMarks.length - maxBeaconMarks);
        }
      } else if (beaconMarks.isNotEmpty) {
        // 位置没动：把旧标记的时间刷新成最近一次，避免它看起来「很旧」
        beaconMarks[beaconMarks.length - 1] = mark;
      }
      setConnStatus(
        usingTnc
            ? ConnPhase.positionSentTnc
            : (usingAudio
                ? ConnPhase.positionSentAudio
                : ConnPhase.positionSent),
        arg: myCall,
      );
    } else {
      setConnStatus(ConnPhase.demoBeacon);
    }
    beaconsSent++;
    _lastBeacon = DateTime.now();
    _lastBeaconLat = lat;
    _lastBeaconLng = lng;
    _lastBeaconCourse = myCourse;
    AchievementCenter.instance.bump('sendCoord'); // 坐标发送·请求打击
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
    // 标准 course/speed 格式：ddd/sss（度/节，各3位）
    // 必须位于备注最前（APRS101 规定），否则 aprs.fi 等第三方地图
    // 不会解析，会把速度/方位角当作普通备注文字显示。
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
    // 高度：APRS 标准 /A=ffffff（英尺）
    if (myAlt != null && myAlt! >= 0) {
      final ft = (myAlt! / 0.3048).round().clamp(0, 999999);
      parts.add('/A=${ft.toString().padLeft(6, '0')}');
    }
    if (beaconIncludeBattery && _battery >= 0) {
      parts.add('Bat:$_battery%');
    }
    // 心率：HR=nn。APRS 没有正式字段，`HR=` 是通行写法（第三方地图当备注显示）。
    // 只在**真有读数**时发：没读数时发 HR=0 会让收端以为「心率 0」而不是「没测」。
    if (beaconIncludeHr && myHr != null && myHr! > 0) {
      parts.add('HR=$myHr');
    }
    if (myComment.trim().isNotEmpty) {
      parts.add(myComment.trim());
    }
    // 版本号/平台**不再**放在位置数据包备注里（会污染第三方地图上的备注），
    // 改由状态数据包上报：`>APRSlocus CONNECT vX.Y.Z 平台`。
    return parts.join(' ');
  }

  // ─── 连接 ───
  Future<void> reconnect() async {
    _userDisconnected = false;
    _reconnectTimer?.cancel();
    _lastFilter = ''; // 重置，确保下次连接后更新
    // 多选：逐条重启，互不影响 —— 只重启「发射来源」会让另一条链路
    // 停在坏状态（用户看到「重连了但还是收不到」）
    if (audioOn) {
      // 音频：重开采集并重建解调器（采样率可能刚改过）
      await audio.restart();
      _setLinkUp(srcAudio, audio.connected);
      if (audio.connected) {
        setConnStatus(ConnPhase.audioConnected,
            arg: '${audio.config.afsk.sampleRate}Hz');
      }
    }
    if (tncOn) {
      // TNC：重启链路（断开重连并重下发 KISS 参数）而不是只重开套接字
      await tnc.restart();
      _setLinkUp(srcTnc, tnc.connected);
      if (tnc.connected) {
        setConnStatus(ConnPhase.tncConnected,
            arg: tnc.device?.label ?? '');
      }
    }
    if (pkwdwplOn) {
      // PKWDWPL：只要断连重连（没有参数需要重下发）
      await pkwdwpl.restart();
      _setLinkUp(srcPkwdwpl, pkwdwpl.connected);
    }
    if (!aprsIsOn) {
      _notify();
      _updateNotification();
      return;
    }
    aprs.disconnect();
    connected = false;
    _notify();
    _updateNotification();
    await _connect();
  }

  Future<void> toggleConnect() async {
    // 判据用 anyLinkUp：多选模式下「发射来源断了但别的还连着」时，
    // 用户点这个按钮的意图仍然是「全部断开」，而不是再连一次。
    if (anyLinkUp) {
      _userDisconnected = true;
      _reconnectAttempt = 0; // 手动断开，重置重试计数
      _reconnectTimer?.cancel();
      if (aprsIsOn) aprs.disconnect();
      if (tncOn || isUp(srcTnc)) await tnc.disconnect();
      if (audioOn || isUp(srcAudio)) await audio.disconnect();
      if (pkwdwplOn || isUp(srcPkwdwpl)) await pkwdwpl.disconnect();
      _linkUp.clear();
      _refreshConnected();
      setConnStatus(ConnPhase.manual);
      _notify();
      _updateNotification();
      return;
    }
    _userDisconnected = false;
    await _connect();
  }

  void _onAprsLine(String line, {required bool rf}) {
    // 网关转递必须在**解析之前**做：无论这条报文能否解析成台站/消息，
    // 只要它该被转递就得转递（很多报文类型本应用并不解析，但网关该转发）。
    if (rf) {
      _gateRfToIs(line);
    } else {
      _gateIsToRf(line);
    }
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
              setConnStatus(ConnPhase.unverified);
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
      // 射频上听到的台站记入「听到过」列表 —— 双向网关据此判断
      // 一条互联网消息值不值得占用射频时隙
      if (rf) _noteHeard(line);
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
      if (body.startsWith('@') ||
          body.startsWith('=') ||
          body.startsWith('/') ||
          body.startsWith("'") ||
          body.startsWith('`')) {
        type = 'position';
      }
      if (body.startsWith('_')) type = 'weather';
      if (body.startsWith('>')) type = 'status';
      // 多跳转发识别：记录转发路径（如 WIDE1-1,WIDE2-1 或数字中继）
      if (path.isNotEmpty &&
          path.toUpperCase() != 'APRS' &&
          path.toUpperCase() != 'TCPIP*') {
        // 转发路径作为附加信息展示，不覆盖原 info
        info = '$info  ·  [via $path]';
      }

      // APRSlocus 状态包：>APRSlocus CONNECT vX.Y.Z 平台
      // （版本号自 v1.6.80 起从位置包移到这里，见 _mergeApStatus）
      if (body.startsWith('>')) _mergeApStatus(src, body);

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
          if (ackId != null && connected && _autoAckEnabled) {
            // ack 包不带消息 ID，防止对方无限 ack 我们的 ack
            final ack = '$myFullCall>$_destHeader::${src.padRight(9)}:ack$ackId';
            _sendRaw(ack);
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
      // 位置包：!/=/（含压缩、非压缩）+ /@（带时间戳）+ '`（Mic-E，纬度编码在目的呼号）
      if (body.startsWith('!') ||
          body.startsWith('=') ||
          body.startsWith('/') ||
          body.startsWith('@') ||
          body.startsWith("'") ||
          body.startsWith('`')) {
        final p = parseAprsPosition(body, dest: toCall);
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
    // ─── 协议消息处理（唯一入口：lib/group_chat.dart 已解析一次）───
    final proto = GroupProto.parse(text);
    if (proto != null) {
      // 去重：同一帧可能被重复送达 —— 同时开着 APRS-IS 与射频、
      // 或经 iGate 回环时都会发生。没有这层去重，同一次「确认加入」会
      // 反复插入系统消息、反复弹通知，看起来就像「消息重复/乱序」。
      final key = '${src.toUpperCase()}|${text.toUpperCase()}';
      final now = DateTime.now();
      final seen = _seenProtoMsgs[key];
      if (seen != null && now.difference(seen).inSeconds < 120) {
        return null; // 2 分钟内的同一协议消息视为重发
      }
      _seenProtoMsgs[key] = now;
      if (_seenProtoMsgs.length > 200) {
        _seenProtoMsgs.remove(_seenProtoMsgs.keys.first);
      }
      final handled = _handleGroupProtocol(src, groupId, proto);
      if (handled) return null; // 协议消息不进入聊天列表
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
    // 未读数改为**派生重算**，而不是在这里手动 ++。
    //
    // 手动 ++ 与「已读时间点」是两套状态，必然脱节：曾经群消息完全不 ++，
    // 于是红点要等别的操作触发重算才突然冒出，而读了群又不消（表现为
    // 「小红点有时候不消」）。统一在 _recalcUnread 里算，就不会再有分歧。
    _recalcUnread();
    _saveMessages();
    AchievementCenter.instance.bump('receiveMsg'); // 听没听到
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

  /// 处理群聊协议消息（[proto] 已由 [GroupProto.parse] 解析好）。
  ///
  /// 旧实现把「群内【JOIN】/【LEAVE】」与「私信 JOIN_CONFIRM/DECLINE/…」
  /// 分成两个函数各自判断，同一语义写两遍 —— 结果只补一处就漏另一处。
  /// 现在两种来路都进这里，按 [GroupKind] 分派。
  ///
  /// 返回 true 表示「这是一条协议消息，不要进聊天列表」。
  bool _handleGroupProtocol(String src, String? groupId, GroupMsg proto) {
    final s = l10n;
    switch (proto.kind) {
      // ── 群内广播：某人加入/离开 ──
      case GroupKind.memberJoined:
      case GroupKind.memberLeft:
        if (groupId == null) return false;
        final g = chatGroups.where((g) => g.id == groupId).firstOrNull;
        if (g == null) return false;
        final who = proto.name;
        if (who.isEmpty) return true;
        final joined = proto.kind == GroupKind.memberJoined;
        if (joined) {
          g.activeMembers.add(who);
          g.memberStatus[who] = GroupMemberStatus.joined;
        } else {
          g.activeMembers.remove(who);
          g.memberStatus[who] = GroupMemberStatus.left;
        }
        _saveChatGroups();
        _log(LogLevel.info, '群聊',
            '${g.name}：$who ${joined ? '加入' : '离开'}');
        _addGroupSystemMsg(groupId,
            joined ? s.grpSysJoined(who) : s.grpSysLeft(who));
        _notify();
        return true;

      // ── 邀请（可能是私信，也可能直接发在群里）──
      case GroupKind.invite:
        _processInvite(src, proto.groupCall, proto.name);
        return true;

      // ── 以下是「发给群主」的私信命令，必须校验群主身份 ──
      case GroupKind.joinConfirm:
        _processJoinConfirm(src, proto.groupCall);
        return true;
      case GroupKind.decline:
        _processDecline(src, proto.groupCall);
        return true;
      case GroupKind.joinRequest:
        _processJoinReq(src, proto.groupCall);
        return true;
      case GroupKind.leave:
        _processMemberLeft(src, proto.groupCall);
        return true;
    }
  }

  /// 处理邀请（我是成员，收到群主的邀请）
  void _processInvite(String from, String groupCall, String name) {
    // 群名/群呼号非法时不要建群：会得到一个永远发不出去、也进不去的群
    if (GroupProto.validateGroupCall(groupCall) != null) {
      _log(LogLevel.warn, '群聊', '忽略非法邀请：群呼号 $groupCall');
      return;
    }
    var g = chatGroups
        .where((g) => g.groupCall.toUpperCase() == groupCall.toUpperCase())
        .firstOrNull;
    final isNew = g == null;
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
    // 只有**首次**收到邀请才弹通知与确认框。
    // 旧实现在每次收到 INVITE 时都弹一遍 —— 对方重发/多路径送达时
    // 会连弹多次，用户点完还会再弹，看起来像「弹窗死循环」。
    if (isNew) {
      loc.showGroupNotification(l10n.grpInviteTitle, l10n.grpInviteBody(from, g.name));
      onInviteReceived?.call(from, groupCall, name);
    }
    _notify();
  }

  /// 处理加入确认（我是群主，收到成员的确认）
  void _processJoinConfirm(String from, String groupCall) {
    final g = chatGroups
        .where((g) => g.groupCall.toUpperCase() == groupCall.toUpperCase())
        .firstOrNull;
    if (g != null && g.isOwner(myCall)) {
      final who = from.toUpperCase();
      final changed =
          g.memberStatus[who] != GroupMemberStatus.joined || !g.activeMembers.contains(who);
      g.memberStatus[who] = GroupMemberStatus.joined;
      g.activeMembers.add(who);
      if (!changed) return; // 重复的确认（重发/多路径）不再重复提示
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

  /// APRSlocus 状态包缓存：呼号 → {版本, 平台}。
  ///
  /// 自 v1.6.80 起版本号/平台由**状态包**上报
  /// （`>APRSlocus CONNECT vX.Y.Z 平台`），而不再是位置包的备注。
  /// 位置包里拿不到这些信息，所以这里缓存下来，在 `_upsertStation`
  /// 合并到台站的 aprslocus 字段，保证第三方台站的版本照样能显示。
  final Map<String, Map<String, String>> _apStatusCache = {};

  /// 解析 FMO 状态包体 `>地区,状态,在线/峰值:29/54,描述`
  /// 解析 APRSlocus 状态包（`>APRSlocus CONNECT vX.Y.Z 平台`），
  /// 缓存版本/平台并合入已有台站。
  ///
  /// 位置包旧格式 `APRSlocus v1.2.6 Win` 仍由 `_upsertStation` 解析，
  /// 两个正则都容忍可选的 `CONNECT`，因此新旧版本互通。
  void _mergeApStatus(String call, String body) {
    final up = body.toUpperCase();
    if (!up.contains('APRSLOCUS') && !up.contains('APOLOCUS')) return;
    final info = <String, String>{'软件': 'APRSlocus'};
    final vm = RegExp(r'APRSLOCUS(?:\s+CONNECT)?\s*v?(\d[\d.]*)',
            caseSensitive: false)
        .firstMatch(body);
    if (vm != null) info['版本'] = 'v${vm.group(1)}';
    final pm = RegExp(
            r'APRSLOCUS(?:\s+CONNECT)?\s*v?[\d.]+\s+(Win|Mac|iOS|Android|Linux|Web|Fuchsia)',
            caseSensitive: false)
        .firstMatch(body);
    if (pm != null) {
      final raw = pm.group(1)!;
      info['平台'] = raw.toLowerCase() == 'ios'
          ? 'iOS'
          : raw[0].toUpperCase() + raw.substring(1).toLowerCase();
    }
    _apStatusCache[call] = info;
    final idx = stations.indexWhere((s) => s.call == call);
    if (idx >= 0) {
      stations[idx].aprslocus = {...?stations[idx].aprslocus, ...info};
    }
  }

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
  /// ⚠ 这里**故意不做任何“位置质量/防抖”处理**（去重、时序判旧帧、速度门控、
  /// 自适应抽稀），也不画不确定圈/推测位置/平滑轨迹。
  ///
  /// v1.6.145 加过这一整套，v1.6.147 按用户反馈**全部撤掉**：接收侧那些判据每帧
  /// 都要跑（平滑每次重绘重建列表、推测定位每秒对每个可见台站算三角函数、
  /// 那一层还每秒强制重绘），而它们改善的是“别人的点准不准”—— 代价与收益不成比例。
  /// 用户的原话是「不要给别人加防抖，浪费」。
  ///
  /// 因此接收台站回到「收到就更新，位移超过 20m 记一个轨迹点」的朴素行为；
  /// **自己**的位置防抖（`SelfFixFilter`）与精度显示仍保留 —— 那才是每天看得见的东西。
  /// 若将来想重做这一层，请先回答“它能省下多少帧”再动手。
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
        r'APRSLOCUS(?:\s+CONNECT)?\s*v?(\d[\d.]*)',
        caseSensitive: false,
      ).firstMatch(p.comment!);
      if (vm != null) apInfo['版本'] = 'v${vm.group(1)}';
      apInfo['软件'] = 'APRSlocus';
      // 平台：APRSlocus v1.6.74 Win / iOS / Mac / Android / Linux / Web
      final pm = RegExp(
        r'APRSLOCUS(?:\s+CONNECT)?\s*v?[\d.]+\s+(Win|Mac|iOS|Android|Linux|Web|Fuchsia)',
        caseSensitive: false,
      ).firstMatch(p.comment!);
      if (pm != null) {
        final raw = pm.group(1)!;
        // 规范成统一写法（大小写不敏感匹配到的可能是 win / WINDOWS 等）
        apInfo['平台'] = raw.toLowerCase() == 'ios'
            ? 'iOS'
            : raw[0].toUpperCase() + raw.substring(1).toLowerCase();
      }
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
    // 合并此前由状态包缓存的版本/平台（自 v1.6.80 起版本号随状态包上报，
    // 见 _mergeApStatus），否则其它 APRSlocus 台站的版本会显示不出来。
    final cachedAp = _apStatusCache[call];
    if (cachedAp != null) apInfo = {...?apInfo, ...cachedAp};
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
      // 记录条件：位移超过 20m（避免静止时堆积重复点）。
      // 上限由 maxTrackPts 控制（原先硬编码 60，轨迹因此很短）。
      if (s.track.isEmpty ||
          haversine(s.track.last.lat, s.track.last.lng, p.lat, p.lng) > 0.02) {
        s.track = [...s.track, TrackPt(p.lat, p.lng, now)];
        if (s.track.length > maxTrackPts) {
          s.track = s.track.sublist(s.track.length - maxTrackPts);
        }
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
  /// ── 位置跳变守卫的状态（见 [_onFix]）──
  /// 单步位移超过这个公里数、**且**距上一轨迹点不到 [_kFixJumpWindowSec] 时才视为可疑。
  /// 30km 这个数的依据：正常的 TNC/GPS 采样间隔是 10 秒级，10 分钟内跨 30km 意味着
  /// 平均 180km/h 以上，而民用移动（含高铁 350km/h —— 10 分钟也有 58km）里只有
  /// 飞机能到这量级；反过来，缓存位置/网络漂移常跨几十上百公里。
  /// 阈值取大一点的好处：**不会误伤「停车几小时后开出去」这种合法位移**
  /// （那种情况距上一轨迹点已经很久，由时间窗排除）。
  static const double _kFixJumpKm = 30.0;

  /// 粗定位（网络/基站/被动）推动标记前，GPS 必须已经停更这么多秒。
  ///
  /// 为什么不用原生那个 20s：原生那个是**传输层**的「别刷屏」门槛，而这里是
  /// **策略层**的「什么时候才允许用粗点换掉 GPS」决定。城市峡谷里 GPS 断十几秒
  /// 是常事，一断就拿基站质心顶上，标记就会在 50m 与 800m 之间来回横跳 ——
  /// 用户看到的正是「飞来飞去」。
  ///
  /// v1.6.163 从 120s 提到 300s（用户要求「降低网络定位的权重」）：2 分钟的缝
  /// 在城市峡谷/高架/室内仍然太常见，GPS 一断一续粗点就顶上来；而粗点现在
  /// **不再触发自动上报**（见 [canAutoBeacon]），所以它唯一的作用就是「GPS
  /// 真的没了，至少给个大概位置」—— 那本来就是分钟级的兜底，等得起。
  static const int _kCoarseHoldSec = 300;

  /// 粗定位点自己一口气跳出去的公里数上限。
  ///
  /// GPS 停了很久（比如刚出隧道）时允许粗点兜底，但如果它一上来就离上一可信
  /// 位置十几公里，那多半不是「我们移动了」，而是换了个 Wi-Fi/基站质心 ——
  /// 这种点宁可不要（没有位置比错位置好，地图会退化成「未定位」但不会骗人）。
  ///
  /// v1.6.163 从 8.0 收到 3.0：基站/Wi-Fi 的单跳误差本来就在公里级，8km 相当于
  /// 不设防（那种「换个 Wi-Fi 就跳到街对面」的点会照收）。
  static const double _kCoarseJumpKm = 3.0;

  /// 粗定位的精度显示下限（米）。
  ///
  /// 系统自报的 accuracy 对 Wi-Fi/基站点常常过于乐观（报 20~40m，实际偏几百米）。
  /// 照抄会让精度圈画得跟 GPS 一样小 —— 比不画更骗人。
  /// v1.6.163 从 150 提到 300：基站质心实际常在几百米到公里级，150 仍然偏乐观。
  static const double _kCoarseAccuracyFloorM = 300.0;
  /// 「短时间内」的定义（秒）：超过它就认为中间本来就有空档，多大的位移都可能是真的
  static const int _kFixJumpWindowSec = 600;
  /// 两次可疑点相距小于这个公里数，视为「落在同一处」
  static const double _kFixConfirmKm = 1.0;
  /// 连续这么多次都落在同一处，才承认位置真的变了
  static const int _kFixConfirmNeed = 3;
  double? _pendingFixLat;
  double? _pendingFixLng;
  int _pendingFixCount = 0;

  /// 自己位置的静止防抖滤波器（见 lib/pos_quality.dart 的 [SelfFixFilter]）
  final SelfFixFilter _selfFilter = SelfFixFilter();

  /// 是否已经有过**实时**定位（系统缓存位置不算）。缓存点只在它为 false 时
  /// 允许更新标记 —— 原生前台服务重启会让它那边的 hasLiveFix 归零，这里再挡一道。
  bool _hadLiveFix = false;

  /// 上一次**被接受**的实时定位：跳变守卫的参照点。
  /// 不能用 `myTrack.last` —— 静止时不写轨迹点（可能已是几小时前的点），
  /// 且 myTrack 为空时原本完全没有守卫。
  double? _lastFixLat, _lastFixLng;
  DateTime? _lastFixTime;

  /// 复位「自己位置」的全部状态：防抖窗口、跳变守卫、缓存点闸门、精度。
  /// 停止定位 / 切到模拟位置 / 清空数据时调用 —— 否则切回真实定位时
  /// 会拿着旧状态（手动坐标、缓存的窗口）当历史。
  void _resetSelfFix() {
    _selfFilter.reset();
    _hadLiveFix = false;
    _lastFixLat = null;
    _lastFixLng = null;
    _lastFixTime = null;
    _pendingFixLat = null;
    _pendingFixLng = null;
    _pendingFixCount = 0;
    myAccuracy = 0;
    myFixCoarse = false;
  }

  // 接收侧不再有任何质量层状态（见 _upsertStation 顶部的说明）。

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
    AchievementCenter.instance.bump('worldListener'); // 世界聆听者(累计3万)
    _rxTimes.add(DateTime.now());
    // 顺带清理超过 60 秒的记录，防止 _rxTimes 无界增长
    final now = DateTime.now();
    _rxTimes.removeWhere((t) => now.difference(t).inSeconds > 60);
    if (packets.length > maxPackets) packets.removeLast();
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
    unawaited(_saveStationsNow());
  }

  /// 台站列表（收藏/手动联系人/备注）落盘（可 await，供备份导出前强制刷新）
  Future<void> _saveStationsNow() async {
    try {
      final p = await SharedPreferences.getInstance();
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
              if (s.toCall != null && s.toCall!.isNotEmpty) 'toCall': s.toCall,
              if (s.fmo != null) 'fmo': s.fmo,
              if (s.aprslocus != null) 'aprslocus': s.aprslocus,
            },
          )
          .toList();
      p.setString('stations', jsonEncode(json));
    } catch (_) {}
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

  // ─── 备份 / 恢复 ───

  /// 备份导出前的强制落盘：把只在内存里、还没写进偏好的东西先写下去。
  ///
  /// 不加这一步，用户「刚加完收藏就点导出」时导出的会是旧快照 —— 备份功能里
  /// 这种静默缺失最致命：用户以为备份里有，直到恢复那天才发现没有。
  Future<void> flushForBackup() async {
    await persistNow();
    await _saveMessagesNow();
    await _saveStationsNow();
    await _saveChatGroupsNow();
  }

  /// 导入备份并写回偏好之后，就地重载内存状态。
  ///
  /// 从偏好恢复的列表（消息/群聊/台站/已读点）必须先清空再 [_loadPrefs]：
  /// 那些读取函数是「追加」语义，直接重载会得到重复台站/重复消息。
  /// 注意：成就、翻译、服务器连接这些在各自单例里只加载一次，需重启才完全生效，
  /// 所以导入完成后仍要提示用户重启。
  Future<void> reloadFromPrefs() async {
    messages.clear();
    chatGroups.clear();
    stations.clear();
    _readAt.clear();
    _groupReadAt.clear();
    await _loadPrefs();
    _recalcUnread();
    _bumpStationsVersion();
    _notify();
  }

  // ─── 消息 ───
  /// 会话列表的「单聊」部分：消息中出现过的对方呼号 + 收藏/手动联系人。
  /// （群聊另见 [chatGroups]，群呼号不算单聊。）
  ///
  /// 抽成静态纯函数的目的是让**会话列表**与**ADIF 导出**共用同一套规则：
  /// 这类判定一旦被复制成两份就会漂移（APRSlocus 台站识别就这么翻过车）。
  static List<String> partnersOf(
    List<AprsMsg> messages,
    List<ChatGroup> groups,
    List<Station> stations,
  ) {
    final s = <String>{};
    for (final m in messages) {
      // 排除群聊消息（有 groupId 或收发件人是群呼号）
      if (m.groupId != null) continue;
      final isGroupCall = groups.any(
        (g) =>
            g.groupCall.toUpperCase() == m.to.toUpperCase() ||
            g.groupCall.toUpperCase() == m.from.toUpperCase(),
      );
      if (isGroupCall) continue;
      s.add(m.sent ? m.to : m.from);
    }
    // 收藏 / 手动联系人也显示在会话列表
    for (final st in stations) {
      if (st.favorite || st.manual) s.add(st.call);
    }
    return s.toList();
  }

  /// 清空全部聊天记录
  void clearMessages() {
    messages.clear();
    unreadMessages = 0;
    _readAt.clear();
    _saveMessages();
    _notify();
  }

  /// 把给定呼号从「收藏 / 手动联系人」中撤下。
  ///
  /// 这两类台站**即使一条消息都没有**也会出现在会话列表里（见 partnersOf），
  /// 所以「删除会话」若只删消息，它们会**继续留在列表里**，看起来像没删掉。
  ///
  /// 只清这两个标记、**不删台站本身** —— 台站仍可能通过 APRS 报文被收到，
  /// 把它从台站列表里抹掉是另一件事，由台站面板的「删除台站」负责。
  void _clearContactFlags(Set<String> targets) {
    if (targets.isEmpty) return;
    var touched = false;
    for (final s in stations) {
      if (targets.contains(s.call.toUpperCase()) && (s.favorite || s.manual)) {
        s.favorite = false;
        s.manual = false;
        touched = true;
      }
    }
    if (touched) {
      // stationsVersion 是会话列表缓存键的一部分（messages_page._partners），
      // 必须推进它，否则列表不刷新、行仍然在。
      _bumpStationsVersion();
      _saveStations();
    }
  }

  /// 删除与某呼号的单聊会话（删该会话消息 + **移出会话列表**，不影响群聊）。
  /// 呼号比较用大写（APRS 呼号大小写不敏感）。
  void deleteConversation(String call) {
    final target = call.trim().toUpperCase();
    if (target.isEmpty) return;
    messages.removeWhere((m) =>
        m.from.toUpperCase() == target || m.to.toUpperCase() == target);
    // 已读时间点一并清掉，否则重建同名会话时会沿用旧的已读位置
    _readAt.remove(call);
    _readAt.remove(target);
    // 收藏/手动联系人也要撤下，否则没有消息了却仍留在会话列表里
    _clearContactFlags({target});
    _recalcUnread();
    _saveMessages();
    _notify();
    _log(LogLevel.info, '消息', '已删除与 $target 的聊天记录');
  }

  /// 清空某群聊的聊天记录（**保留群组本身**，仅清消息）。
  void clearGroupConversation(String groupId) {
    if (groupId.isEmpty) return;
    messages.removeWhere((m) => m.groupId == groupId);
    _groupReadAt.remove(groupId);
    _recalcUnread();
    _saveMessages();
    _notify();
    _log(LogLevel.info, '消息', '已清空群聊聊天记录');
  }

  /// 批量删除会话（单聊呼号集合 + 群聊 ID 集合），一次性保存与通知。
  /// 单聊：删该呼号的全部消息 + 移出会话列表；群聊：只清消息，保留群组本身。
  /// 呼号一律按大写比对（APRS 呼号大小写不敏感）。
  void deleteConversations(Iterable<String> calls, Iterable<String> groupIds) {
    final cs = calls
        .map((e) => e.trim().toUpperCase())
        .where((e) => e.isNotEmpty)
        .toSet();
    final gs = groupIds.where((e) => e.isNotEmpty).toSet();
    if (cs.isEmpty && gs.isEmpty) return;
    messages.removeWhere((m) {
      if (m.groupId != null) return gs.contains(m.groupId);
      return cs.contains(m.from.toUpperCase()) ||
          cs.contains(m.to.toUpperCase());
    });
    // 已读时间点一并清掉；键的大小写未必统一，按大写比对
    _readAt.removeWhere((k, _) => cs.contains(k.toUpperCase()));
    for (final g in gs) {
      _groupReadAt.remove(g);
    }
    // 同上：收藏/手动联系人也撤下，保证选中的会话行确实从列表消失
    _clearContactFlags(cs);
    _recalcUnread();
    _saveMessages();
    _notify();
    _log(
      LogLevel.info,
      '消息',
      '已删除 ${cs.length} 个单聊、${gs.length} 个群聊的聊天记录',
    );
  }

  /// 呼号归一化。
  ///
  /// APRS 呼号大小写不敏感，而各处来源不一（手动添加会 toUpperCase、
  /// 报文里的可能原样小写）—— 不归一化就会出现「已读写在 A 键、
  /// 统计时看 B 键」这种红点永不消除的情况。
  static String normCall(String call) => call.trim().toUpperCase();

  /// 消息属于哪个会话（'c:呼号' 或 'g:群ID'）
  static String convKeyOfMsg(AprsMsg m) => m.groupId != null
      ? 'g:${m.groupId}'
      : 'c:${normCall(m.from)}';

  /// 当前正在查看的会话键（null = 不在任何会话里）。
  ///
  /// 由消息页设置。未读计算会**跳过它** —— 否则「正看着的会话来了一条新消息」
  /// 会产生一个必须退出再进才能消掉的红点。
  String? _activeConvKey;

  /// 设置当前查看的会话（消息页调用；传 null 表示回到列表/切走标签页）
  void setActiveConversation({String? call, String? groupId}) {
    final String? k;
    if (groupId != null) {
      k = 'g:$groupId';
    } else if (call != null && call.trim().isNotEmpty) {
      k = 'c:${normCall(call)}';
    } else {
      k = null;
    }
    if (k == _activeConvKey) return;
    _activeConvKey = k;
    _recalcUnread();
  }

  /// 某会话的未读数（该呼号收到的、晚于已读时间点的消息数）
  int conversationUnread(String call) {
    final key = normCall(call);
    final readAt = _readAt[key];
    int n = 0;
    for (final m in messages) {
      if (!m.sent && m.groupId == null && normCall(m.from) == key) {
        if (readAt == null || m.time.isAfter(readAt)) n++;
      }
    }
    return n;
  }

  /// 标记某会话已读
  void markConversationRead(String call) {
    _readAt[normCall(call)] = DateTime.now();
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
    // 原先这里**漏了重算**：只写已读时间点、不更新 unreadMessages，
    // 于是「读完群聊，底部红点不消失」。
    _recalcUnread();
    _saveMessages();
  }

  /// 供测试驱动未读重算（生产代码不要调用 —— 未读会在收消息/标记已读时自动重算）
  @visibleForTesting
  void recalcUnreadForTest() => _recalcUnread();

  /// 重新计算全局未读数（**未读数的唯一真源**）
  ///
  /// 两条规则：
  ///   ① 呼号归一化后比对，避免大小写导致「已读却仍算未读」
  ///   ② **跳过当前正在查看的会话** —— 用户正看着它，不该有红点
  void _recalcUnread() {
    int n = 0;
    for (final m in messages) {
      if (m.sent || m.system) continue;
      if (_activeConvKey != null && convKeyOfMsg(m) == _activeConvKey) continue;
      final readAt = m.groupId != null
          ? _groupReadAt[m.groupId]
          : _readAt[normCall(m.from)];
      if (readAt == null || m.time.isAfter(readAt)) n++;
    }
    if (n != unreadMessages) {
      unreadMessages = n;
      _notify();
    }
  }

  /// 清零全部未读消息（进入消息页时调用）
  void clearUnread() {
    if (unreadMessages == 0) return;
    final now = DateTime.now();
    for (final m in messages) {
      if (!m.sent) {
        if (m.groupId != null) {
          _groupReadAt[m.groupId!] = now;
        } else {
          // 归一化：与 _recalcUnread 用同一个键
          _readAt[normCall(m.from)] = now;
        }
      }
    }
    // 统一交给重算，而不是直接写 0 —— 否则可能与真实状态脱节
    unreadMessages = 0;
    _recalcUnread();
    _notify();
  }

  /// 删除联系人（收藏/手动台站）
  void removeContact(String call) {
    stations.removeWhere((s) => s.call == call);
    _bumpStationsVersion();
    _saveStations();
    _notify();
  }

  /// 发送私聊消息。
  ///
  /// [text] 是**用户写的原文**（聊天记录按它显示）；
  /// [sentAs] 是**实际发到空中的文本**（发送前翻译时传入译文）。
  /// 空中的报文用 `sentAs ?? text`，长度限制也按空中内容判定 ——
  /// 否则会出现「原文 60 字符通过、译文 80 字符被对端丢弃」这种静默失败。
  void sendMessage(String to, String text, {String? sentAs}) {
    if (text.trim().isEmpty) return;
    // 防止误发给群呼号：重定向到对应群聊
    for (final g in chatGroups) {
      if (g.groupCall.toUpperCase() == to.toUpperCase()) {
        sendGroupMessage(g.groupCall, text, groupId: g.id);
        return;
      }
    }
    final wire = (sentAs ?? text).trim();
    // TNC（射频）模式下的长度限制：APRS101 规定消息文本上限 67 字符。
    // 超长时报文会被对端 TNC/网关丢弃，与其静默失败不如在源头拦住。
    if (usingRf && wire.length > tncMaxMsgLen) {
      _log(LogLevel.warn, '消息',
          '射频模式下单条消息限 $tncMaxMsgLen 字符，已中止发送（${wire.length} 字符）');
      _notify();
      return;
    }
    final id = AprsFmt.randId();
    final raw = AprsFmt.message(myFullCall, to, wire, id, path: txPath);
    messages.insert(
      0,
      AprsMsg(myFullCall, to, text.trim(), DateTime.now(),
          sent: true, id: id, sentAs: sentAs == null ? null : wire),
    );
    _saveMessages();
    packetsTx++;
    AchievementCenter.instance.bump('sendMsg'); // 我发出去了吗？
    if (connected) {
      _sendRaw(raw);
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
    // TNC（射频）模式禁用群发：
    //   ① 群聊靠 no-ack 广播 + 批量邀请，在共享信道上一次邀请就占大量时隙；
    //   ② 群呼号不是真实台站，射频上无人能回答，实际是单向噪声。
    if (usingRf) {
      _log(LogLevel.warn, '群发', '射频（TNC/音频）模式不支持群聊广播，已中止发送');
      _notify();
      return 0;
    }
    final id = AprsFmt.randId();
    final raw =
        AprsFmt.messageNoAck(myFullCall, groupCall, text.trim(), id, path: txPath);
    AchievementCenter.instance.bump('sendMsg'); // 我发出去了吗？
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
      _sendRaw(raw);
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
    // 初始化成员状态。
    //
    // 旧实现把**所有人**（含群主自己）都置为 pending，于是成员列表里
    // 「群主」显示成「待确认」，而 recipients 只收 joined → 群主自己
    // 反而不在收件人里。现在：群主立即 joined，其余人 pending。
    g.memberStatus[g.owner.toUpperCase()] = GroupMemberStatus.joined;
    for (final m in members) {
      final who = m.toUpperCase();
      if (who == g.owner.toUpperCase()) continue;
      g.memberStatus[who] = GroupMemberStatus.pending;
    }
    chatGroups.add(g);
    _saveChatGroups();
    AchievementCenter.instance.bump('gather'); // 紧急集合！
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
      path: txPath,
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
      path: txPath,
    );
    _trySend(raw);
    // 同时更新本地状态：否则「我点了同意」但成员表里自己仍是 pending，
    // 群里也看不到自己加入 —— 表现为「确认了却没进群」。
    final g = chatGroups
        .where((x) => x.groupCall.toUpperCase() == groupCall.toUpperCase())
        .firstOrNull;
    if (g != null) {
      g.memberStatus[myCall.toUpperCase()] = GroupMemberStatus.joined;
      _saveChatGroups();
      _addGroupSystemMsg(g.id, l10n.grpSysJoined(myCall.toUpperCase()));
      _notify();
    }
    _log(LogLevel.info, '群聊', '确认加入 $groupCall');
  }

  /// 成员离开（发给群主）
  void sendLeave(String ownerCall, String groupCall) {
    final raw = AprsFmt.message(
      myFullCall,
      ownerCall,
      'LEFT $groupCall',
      AprsFmt.randId(),
      path: txPath,
    );
    _trySend(raw);
    final g = chatGroups
        .where((x) => x.groupCall.toUpperCase() == groupCall.toUpperCase())
        .firstOrNull;
    if (g != null) {
      g.memberStatus[myCall.toUpperCase()] = GroupMemberStatus.left;
      g.activeMembers.remove(myCall.toUpperCase());
      _saveChatGroups();
      _addGroupSystemMsg(g.id, l10n.grpSysLeft(myCall.toUpperCase()));
      _notify();
    }
    _log(LogLevel.info, '群聊', '离开 $groupCall');
  }

  /// 尽力发送：连接就发，未连接只记录（等待重连后由定时器补发待发队列）
  void _trySend(String raw) {
    if (connected) {
      _sendRaw(raw);
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
      _sendRaw(raw);
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
    unawaited(_saveChatGroupsNow());
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

  /// 群聊列表落盘（可 await，供备份导出前强制刷新）
  Future<void> _saveChatGroupsNow() async {
    try {
      final p = await SharedPreferences.getInstance();
      final json = jsonEncode(chatGroups.map((g) => g.toJson()).toList());
      p.setString('chatGroups', json);
    } catch (_) {}
  }

  /// 立即持久化群聊并通知刷新（群管理面板操作后调用）
  void saveGroupNow() {
    _saveChatGroups();
    _notify();
  }

  /// 校验一条手写 TNC2 报文能否发送；返回 null 表示格式可以。
  ///
  /// 判据与 `Ax25.encodeTnc2` 一致，但**在发送前**给出可本地化的错误码 ——
  /// 手写报文最常见的问题就是漏了 `>` 或 `:`，而这两种情况在旧实现里是
  /// 静默失败（界面照旧显示「已发送」）。
  String? validateTnc2(String raw) {
    final line = raw.trim();
    if (line.isEmpty) return 'bad-format';
    final gt = line.indexOf('>');
    if (gt <= 0) return 'bad-format';
    final rest = line.substring(gt + 1);
    final colon = rest.indexOf(':');
    if (colon < 0) return 'bad-format';
    if (rest.substring(0, colon).trim().isEmpty) return 'bad-format';
    return null;
  }

  /// 手动注入并发送一条原始报文（数据包控制台用）。
  ///
  /// 返回 null 表示已交给链路，否则是错误码（界面用 `linkErrorText` 本地化）。
  ///
  /// 与信标/消息/测试帧保持一致：**先校验 → 再计数 → 如实返回错误**。
  /// 旧实现不管发没发出去都自增发包计数、也没有任何返回 —— 射频（TNC/音频）
  /// 下格式写错或链路没连上时，界面显示如常，用户只能干等（实为静默失败）。
  String? sendPacket(String raw) {
    final line = raw.trim();
    final bad = validateTnc2(line);
    if (bad != null) {
      _log(LogLevel.warn, '发送',
          '手动注入被拒绝（格式应为 SRC>DEST,PATH:info）：${_trunc(line)}');
      return bad;
    }
    // 射频上不能带 TCPIP*/TCPXX*（那是 APRS-IS 的路径）：Ax25 会剔掉它们，
    // 但用户手写时多半是复制了 IS 上的报文，值得提醒一句
    if (usingRf && line.toUpperCase().contains('TCPIP')) {
      _log(LogLevel.warn, '发送', '报文含 TCPIP*：射频上会被自动剔除（那是 APRS-IS 的路径）');
    }
    if (!connected) {
      _log(LogLevel.warn, '发送',
          '未连接（${_sourceName(dataSource)}），未发送：${_trunc(line)}');
      return 'not-connected';
    }
    // 手动注入是我们**自己发出**的包：只进列表与发包计数。
    // 不能走 _pushPacket —— 那条路自增收包数、还会计入「世界聆听者」成就
    // （把「我发的」当成「我收到的」）。
    final src = line.substring(0, line.indexOf('>')).trim();
    packets.insert(
      0,
      Packet(line, src.isEmpty ? myCall : src, 'APRS', 'unknown',
          DateTime.now(), info: line),
    );
    if (packets.length > maxPackets) packets.removeLast();
    final err = _sendVia(dataSource, line);
    if (err == null) {
      packetsTx++;
      _lastTx = DateTime.now();
      _log(LogLevel.info, '发送', '手动注入已发出：${_trunc(line)}');
    } else {
      _log(LogLevel.warn, '发送', '手动注入发送失败（$err）：${_trunc(line)}');
    }
    _notify();
    return err;
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
          body.startsWith('/') ||
          body.startsWith('@') ||
          body.startsWith("'") ||
          body.startsWith('`')) {
        final p = parseAprsPosition(body, dest: toCall);
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
    // 自己的轨迹不在 stations 里，以前清空数据后会残留一条自己的线
    myTrack.clear();
    // 信标标记与轨迹同属「我的位置」这一组：清了轨迹却留着标记，
    // 地图上会剩下一串没有轨迹穿过的孤点。
    beaconMarks.clear();
    _resetSelfFix();
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
      if (s.track.length > maxTrackPts) {
        s.track = s.track.sublist(s.track.length - maxTrackPts);
      }
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

  /// 「把外壳的内容面板展开到最高档」的请求序号（见 [requestSheetExpand]）。
  int sheetExpandSeq = 0;

  /// 请求外壳把内容面板展开到最高档。
  ///
  /// 为什么需要它：2.0 的面板**按最高档高度布局、只裁出可视区**（治「拖动卡」
  /// 的设计，见 shell2），于是半屏档下页面只显示上半部分。而聊天页的输入框
  /// 在页面的最底部 —— 正好落在裁切线之下，**半屏时根本看不见它**，
  /// 用户必须先手动把面板拉到最高才能打字。
  ///
  /// 为什么走状态而不是回调：发起方是**面板里的页面**（消息页），执行方是
  /// **外壳**（它管面板高度），中间隔着两层 widget。逐个把回调透传下去要改
  /// 四层构造函数；而 `focusOnMap` / `pickSeq` 已经是「页面 → 外壳」的同一类
  /// 请求，这里沿用它 —— 一致性比「省一个字段」重要。
  void requestSheetExpand() {
    sheetExpandSeq++;
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

  /// 按当前 [locale] 取本地化实例。
  /// 状态层没有 BuildContext（ChangeNotifier），故这里直接按语言构造；
  /// 供通知栏等无法拿到 context 的场合使用。
  ///
  /// ⚠️ 本应用存储的语言码是**下划线**形式：'' / 'zh' / 'zh_TW' / 'en'
  /// （见 OOBE 与设置页的 options；app.dart 的 `_localeOf` 也是按 '_' 切分）。
  /// 不是 BCP-47 的 'zh-TW'——此处两种都认，避免繁體用户回落成简体。
  AppLocalizations get l10n {
    switch (locale) {
      case 'en':
        return AppLocalizationsEn();
      case 'es':
        return AppLocalizationsEs();
      case 'ja':
        return AppLocalizationsJa();
      case 'id':
        return AppLocalizationsId();
      case 'zh_TW':
      case 'zh-TW':
        return AppLocalizationsZhTw();
      default:
        return AppLocalizationsZh();
    }
  }

  /// 距下次自动上报剩余秒数（仅在 [BeaconPhase.counting] 时有意义）
  int get beaconSecondsLeft {
    final remain =
        beaconIntervalNow - DateTime.now().difference(_lastBeacon).inSeconds;
    return remain > 0 ? remain : 0;
  }

  /// 自动上报所处阶段。
  ///
  /// **不要用中文字符串表示状态**：此前 `nextBeaconIn` 直接返回
  /// '未连接'/'已关闭'/'等待定位'/'45s'/'即将'，UI 还得拿 `== '即将'` 比较，
  /// 既无法本地化又极易出错。现改为结构化枚举，由 UI 负责本地化。
  BeaconPhase get beaconPhase {
    if (!beaconEnabled) return BeaconPhase.off;
    if (!connected) return BeaconPhase.disconnected;
    // 射频来源没开「射频信标」时**绝不能显示倒计时**：tick 里的 canAutoBeacon
    // 会直接跳过发射，倒计时却照走 —— 用户看到的正是「倒计时结束什么也没发生」。
    // 这一类 bug 的根因是把「是否会发射」判断散落在两处，所以此处必须与
    // canAutoBeacon 用同一个条件（rfBeaconEnabled）。
    if (!rfBeaconEnabled) return BeaconPhase.rfDisabled;
    // **顺序有讲究**：佳明优先于粗定位 —— 位置来自手表时，粗定位那条已经不生效
    // （佳明新鲜时手机 GPS 整个让位，见 _onFix），显示「网络定位中」会是错的。
    if (garmin.on && garmin.fresh) return BeaconPhase.garmin;
    // 粗定位（网络/基站）**不自动上报**（见 [canAutoBeacon]），所以也不能显示一个
    // 照走的倒计时 —— 那正是「倒计时结束什么也没发生」的老症状。
    if (myFixCoarse) return BeaconPhase.coarseFix;
    if (!myHasFix) return BeaconPhase.waitingFix;
    return beaconSecondsLeft > 0 ? BeaconPhase.counting : BeaconPhase.imminent;
  }

  /// 信标倒计时文案（已本地化）。保留此 getter 供通知栏/设置页等直接使用。
  String get nextBeaconIn {
    final l = l10n;
    switch (beaconPhase) {
      case BeaconPhase.off:
        return l.beaconDisabled;
      case BeaconPhase.disconnected:
        return l.beaconNotConnected;
      case BeaconPhase.rfDisabled:
        return l.beaconRfBeaconOff;
      case BeaconPhase.coarseFix:
        return l.beaconCoarseFix;
      case BeaconPhase.garmin:
        return l.beaconGarminSource;
      case BeaconPhase.waitingFix:
        return l.beaconWaitingFix;
      case BeaconPhase.imminent:
        return l.beaconSoon;
      case BeaconPhase.counting:
        return '${beaconSecondsLeft}s';
    }
  }

  /// 更新状态栏通知（前台服务常驻通知）
  void _updateNotification() {
    final l = l10n;
    final parts = <String>[];
    if (connected) {
      // TNC 模式：明确标出「射频」，否则用户会以为走的是网络，
      // 从而忽略「发射要在自己呼号/执照下操作」这件事。
      parts.add(usingTnc
          ? l.notifTncConnected
          : (usingAudio ? l.notifAudioConnected : l.notifConnected));
    } else if (connecting) {
      parts.add(l.notifConnecting);
    } else if (readOnlyMode) {
      // 只读模式：没有发射链路，但报文在收。
      // 这里必须说「只读接收」而不是「未连接」—— 台站已经在图上，
      // 通知栏却写「未连接」会让人以为链路坏了。
      parts.add(l.pkwdwplReadOnly);
    } else {
      parts.add(usingTnc
          ? l.notifTncDisconnected
          : (usingAudio ? l.notifAudioDisconnected : l.notifDisconnected));
    }
    if (myHasFix) {
      parts.add('GPS·$myGrid');
    }
    // 各条链路的收/发计数**分别追加**（而不是 if/else 二选一）：
    // 多选下可能同时开着 APRS-IS 与 PKWDWPL，二选一会漏报一条。
    if (usingTnc) {
      parts.add('RF·${tnc.rxFrames}/${tnc.txFrames}');
    } else if (usingAudio) {
      parts.add('AFSK·${audio.rxFrames}/${audio.txFrames}');
    }
    if (aprsIsOn) {
      parts.add(l.notifOnline('$online'));
      parts.add(l.notifRx('$packetsRx'));
    }
    if (pkwdwplOn) {
      parts.add('PKWDWPL·${pkwdwpl.rxFrames}');
    }
    // 信标倒计时仅在真会发射时显示：TNC 模式下未开启射频信标时显示倒计时
    // 会让用户误以为正在发射；只读模式下同理（压根没有发射链路）。
    if (beaconEnabled &&
        !readOnlyMode &&
        (!usingRf || (usingTnc ? tnc.config.rfBeacon : audio.config.rfBeacon))) {
      parts.add(l.notifBeacon(nextBeaconIn));
    }
    loc.updateNotification(parts.join(' · '));
  }
}

/// 自动上报阶段（结构化，供 UI 本地化；见 [AppState.beaconPhase]）
enum BeaconPhase {
  off,
  disconnected,

  /// 射频来源（TNC / 音频）未打开「射频信标」——此时不会自动发射，
  /// UI 必须显示原因并提供一键开启，而不是继续倒计时。
  rfDisabled,
  /// 当前是**粗定位**（网络/基站/被动）——自动上报已暂停（见 [canAutoBeacon]），
  /// UI 必须说明原因，而不是继续倒计时。
  coarseFix,
  /// 位置来自**佳明 LiveTrack**（手表比手机准，手机 GPS 会让位）。
  /// 这一档不是「不能上报」，而是「要告诉用户**上报的是手表的位置**」——
  /// 否则用户看着倒计时会以为发的是手机定位，而两者可能差几十公里。
  garmin,
  waitingFix,
  counting,
  imminent,
}

/// 连接状态阶段（结构化，供 UI 本地化；见 [AppState.connInfo]）
enum ConnPhase {
  idle,
  connectingServer,
  connectingTnc,
  connectingAudio,

  /// PKWDWPL（Kenwood 航点语句，只收不发）。
  ///
  /// 只保留「连接中 / 已连接」两个阶段：失败与掉线**故意不占用主横幅**
  /// —— 多来源下横幅表达的是「发射链路通不通」，一条只读链路失败
  /// 却把横幅变红，会让人以为整个应用都连不上（而实际上只是收不到台账）。
  /// 它的连通状态在「设备 → 当前链路」那行与自己的卡片上显示。
  connectingPkwdwpl,
  online,
  tncConnected,
  audioConnected,
  pkwdwplConnected,
  unverified,
  retryServer,
  retryTnc,
  retryAudio,
  linkLostServer,
  linkLostTnc,
  linkLostAudio,
  manual,
  positionSent,
  positionSentTnc,
  positionSentAudio,
  demoBeacon,
}

/// 链路（TNC / 音频）错误码 → 可读文案。
///
/// 数据层只暴露稳定的**错误码**（`open-write-failed` 等），不是句子 ——
/// 这样错误文本不会散落在各平台实现里，也不会漏掉本地化。
String linkErrorText(AppLocalizations l, String code) {
  final c = code.toLowerCase();
  if (c.contains('no-device')) return l.tncErrNoDevice;
  if (c.contains('no-permission')) return l.audioNeedPermission;
  if (c.contains('tx-disabled')) return l.tncErrNotConnected;
  // 只读链路（PKWDWPL）被要求发射：明确告知原因，而不是报「未连接」
  if (c.contains('read-only')) return l.pkwdwplErrReadOnly;
  if (c.contains('unsupported')) return l.tncErrUnsupported;
  if (c.contains('not-connected')) return l.tncErrNotConnected;
  if (c.contains('open-read')) return l.tncErrOpenRead;
  if (c.contains('open-write')) return l.tncErrOpenWrite;
  if (c.contains('bad-format')) return l.tncErrBadFormat;
  if (c.contains('frame-too-long')) return l.tncErrFrameTooLong;
  if (c.contains('timeout')) return l.tncErrTimeout;
  // 未识别的（如系统原始异常）：保留原文，便于上报排查
  return code;
}

/// 连接状态 + 参数。文案在这里按语言生成，UI 不再需要任何哨兵映射。
class ConnStatus {
  final ConnPhase phase;

  /// 目标主机 / 呼号 / 设备名 / 错误详情
  final String arg;
  final int seconds;

  const ConnStatus(this.phase, {this.arg = '', this.seconds = 0});

  String localized(AppLocalizations l) {
    switch (phase) {
      case ConnPhase.idle:
        return l.connTapToConnect;
      case ConnPhase.connectingServer:
        return l.connConnectingTarget(arg);
      case ConnPhase.connectingTnc:
        return l.connectingToTnc(arg);
      case ConnPhase.connectingAudio:
        return l.connConnectingAudio(arg);
      case ConnPhase.connectingPkwdwpl:
        return l.connConnectingPkwdwpl(arg);
      case ConnPhase.online:
        return l.connOnline(arg);
      case ConnPhase.tncConnected:
        return l.connTncConnected(arg);
      case ConnPhase.audioConnected:
        return l.connAudioConnected(arg);
      case ConnPhase.pkwdwplConnected:
        return l.connPkwdwplConnected(arg);
      case ConnPhase.unverified:
        return l.connPasscodeInvalid;
      case ConnPhase.retryServer:
        return l.connRetry(seconds);
      case ConnPhase.retryAudio:
        // 与 retryTnc 同样：先把内部错误码换成「下一步该做什么」，再拼进句子
        return arg.isEmpty
            ? l.connRetryAudio(seconds)
            : l.connRetryAudioDetail(linkErrorText(l, arg), seconds);
      case ConnPhase.retryTnc:
        // 带错误详情：射频连接失败的常见原因各不相同（权限、设备被占用、
        // 平台不支持…），只写「失败」用户无从排查；但直接把
        // `open-write-failed: ...` 这种内部串抛给用户同样没用，
        // 所以先经 [linkErrorText] 换成「下一步该做什么」。
        return arg.isEmpty
            ? l.connRetryTnc(seconds)
            : l.connRetryTncDetail(linkErrorText(l, arg), seconds);
      case ConnPhase.linkLostServer:
        return l.connAutoReconnect(seconds);
      case ConnPhase.linkLostTnc:
        return l.connTncLinkLost(seconds);
      case ConnPhase.linkLostAudio:
        return l.connAudioLinkLost(seconds);
      case ConnPhase.manual:
        return l.connManuallyDisconnected;
      case ConnPhase.positionSent:
        return l.connPositionSent(arg);
      case ConnPhase.positionSentTnc:
        return l.connTncPositionSent(arg);
      case ConnPhase.positionSentAudio:
        return l.connAudioPositionSent(arg);
      case ConnPhase.demoBeacon:
        return l.connDemoBeacon;
    }
  }
}
