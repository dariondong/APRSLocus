import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/services.dart';

/// 定位服务
/// - Android/iOS: 通过平台通道调用原生定位 + 前台服务
/// - Windows/Linux/macOS 桌面: 无系统 GPS，用 IP 网络定位（获取所在城市坐标）
/// - Web: 浏览器 Geolocation API (TODO)，降级提示手动输入坐标
class LocService {
  bool _running = false;
  static const _channel = MethodChannel('com.aprslocus/location');
  static const _eventChannel = EventChannel('com.aprslocus/location_events');
  StreamSubscription? _sub;
  Duration interval = const Duration(seconds: 10);
  /// 定位模式：'gps' = 纯 GPS；'gps_network' = GPS + 网络辅助；
  /// 'network' = 纯网络（只用基站 / Wi-Fi，不注册 GPS）
  String mode = 'gps_network';
  /// GPS 采样间隔（毫秒）：用户在设置页可以调（默认 1000）。
  ///
  /// 原来是原生侧写死的 1 秒 / 5 米；现在由这里带上，服务启动时随
  /// `startService` 一起传，运行中改动走 [setSampling]。只作用于 GPS provider ——
  /// 网络定位固定 10 秒（基站/Wi-Fi 本来也不会更新得更频）。
  int samplingMs = 1000;
  /// 定位回调。
  ///
  /// [lastKnown] 为真表示这**不是**实时定位，而是系统缓存的「上次已知位置」
  /// （Android 侧用于启动时快速出图）。它可以更新地图上的「我」，但**不能**写进
  /// 轨迹 —— 缓存点可能几小时前、甚至在另一个城市，写进轨迹就是「线跳回起点再画
  /// 一次、反复横画」。
  /// 定位回调。最后几个参数：
  ///   * [lastKnown] —— 见上（缓存位置标记）；
  ///   * [accuracyM] —— 水平精度（米，`1σ`）；**<= 0 表示平台没给**；
  ///   * [source] —— 定位来源（`'gps'` / `'network'` / `'passive'` / `''`）。
  ///
  /// 精度这个值原生两边一直在算并发出来（Android `LocationService.kt` 的
  /// `"accuracy"`、iOS `LocationPlugin.swift` 的 `horizontalAccuracy`），
  /// 但这里解析事件时**从来没读过**，于是上层既无法按精度加权、也无法告诉你
  /// 「这个点其实 ±40m」—— 白白算了一个最关键的字段。
  ///
  /// [source] 同理：Android 侧一直在事件里发 `"provider"`，这里**从来没读过**。
  /// 代价是「基站/Wi-Fi 粗定位」与「GPS」在上层长得一模一样 —— 而前者会一次偏
  /// 几百米到几公里，这就是用户报的「网络让定位飞来飞去」。空串表示平台没给
  /// （iOS/桌面），按「未知」处理，不当作粗定位（保持旧行为，不制造回归）。
  ///
  /// [satellites] —— 参与定位的卫星数（null = 平台/机型不提供）。
  /// 只有 Android 侧会填（`Location.extras["satellites"]`，机型缺失时回退到
  /// `GnssStatus` 里 usedInFix 的颗数）；iOS / 桌面 / IP 网络定位都是 null。
  /// 它**不参与任何定位取舍**，只用来：① 信标里可选地带上 `SAT=nn`；
  /// ② 设置页如实显示「现在几颗星」。所以 null（不知道）与 0（已知一颗都没有）
  /// 必须区分开，别把 null 当 0。
  void Function(double lat, double lng, double alt, double speed, double bearing,
      bool lastKnown, double accuracyM, String source, int? satellites)? onFix;
  void Function(String status)? onStatus;
  /// 通知栏"连接/断开"按钮点击回调
  void Function()? onToggleConnect;

  bool get running => _running;

  /// 仅保活模式：不采集定位，只维持前台服务（Android）让连接与定时器存活。
  /// 非 Android 平台无此服务，返回 false 表示调用方无需处理。
  bool _keepAliveMode = false;

  /// 上一次真正交给系统的常驻通知文字，用于去重。
  ///
  /// 为什么必须去重：[updateNotification] 的调用点很密（每个定位回调、台次/收包
  /// 统计变化、15 秒保活 tick、链路翻转…），而**文字没变的重发没有任何信息量**。
  /// 代价是实实在在的：同一条文字反复 `notify()`，很多 ROM 会把常驻通知当成
  /// 「又来一条」再弹一次（用户报的「反复弹出待确认上报」就是这个）。
  String _lastNotifText = '';

  /// 通知需要重发：服务刚 startForeground 过，原生手上只有占位文字
  /// （`LocationService.onStartCommand` 会先写「APRSlocus 运行中」）。
  /// 缺了这个标记，去重会把服务重启后的第一次刷新当成「没变」而跳过，
  /// 通知就永远停在占位文字上。
  bool _notifDirty = true;

  /// 启动「仅保活」：**不需要定位权限**，只为让应用在后台不被冻结。
  ///
  /// 用于用户的「模拟位置」模式：位置来自手动坐标/演示数据，不读 GPS，
  /// 但 APRS-IS 连接、信标定时器仍需在后台运行。
  Future<bool> startKeepAlive() async {
    if (_keepAliveMode) return true;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      _listenEvents();
      await _channel.invokeMethod('startService', {'mode': 'keepalive'});
      _keepAliveMode = true;
      _notifDirty = true; // 服务刚起：原生通知是占位文字，下一次刷新必须真发
      onStatus?.call('模拟位置 · 后台保活已启动');
      return true;
    } catch (e) {
      onStatus?.call('后台保活启动失败: $e');
      return false;
    }
  }

  /// 手机侧采样是否正被外置 GPS「待机」（见 [pauseForExternal]）。
  bool _pausedForExternal = false;
  bool get pausedForExternal => _pausedForExternal;

  /// 外置 GPS 供位期间把**手机侧采样**停掉，但保留前台服务。
  ///
  /// ⚠ 这里必须是「切模式」而不是 [stop]：`stop()` 会把前台服务、WakeLock 与
  /// 定位事件订阅一起拆掉，应用退到后台随即被系统冻结 —— APRS-IS 连接静默死掉、
  /// 信标定时器停摆，而界面上的「已连接」还亮着。用户报的「断开外置 GPS 后
  /// 自动上报停了、手动上报只有报文没有位置」就是这条路径（`state.dart` 的
  /// `_syncPhoneGps` 原来在这里调的是 `loc.stop()`）。
  ///
  /// 原生侧 `LocationService.setModeStatic` 收到 `keepalive` 会注销 provider
  /// 监听与「最后已知位置」轮询，前台服务与 WakeLock 原样保留。
  ///
  /// 返回值：采样真的停下来了吗（false = 手机定位本来就没在跑）。
  Future<bool> pauseForExternal() async {
    if (!_running) return false;
    try {
      await _channel.invokeMethod('setLocationMode', {'mode': 'keepalive'});
      _pausedForExternal = true;
      return true;
    } catch (e) {
      onStatus?.call('手机定位待机失败: $e');
      return false;
    }
  }

  /// 外置 GPS 失效：把手机侧采样接回来（服务一直在，不用重启）。
  ///
  /// 返回 false 有两种情况：本来就没停过，或者服务已经不在了 ——
  /// 后者调用方必须改用 [start]（`state.dart` 的 `_resumePhoneGps` 就这么分）。
  Future<bool> resumeFromExternal() async {
    if (!_pausedForExternal) return false;
    _pausedForExternal = false;
    if (!_running) return false;
    try {
      await _channel.invokeMethod('setLocationMode', {'mode': mode});
      return true;
    } catch (e) {
      onStatus?.call('恢复手机定位失败: $e');
      return false;
    }
  }

  /// 测试用：把服务标记成「已在跑」，省掉在主机上真的启动一套定位。
  void debugMarkRunning() {
    _running = true;
  }

  /// 订阅原生事件通道（保活/定位共用）
  void _listenEvents() {
    _sub ??= _eventChannel.receiveBroadcastStream().listen((event) {
      if (event is Map) {
        final type = event['type'] as String?;
        if (type == 'toggleConnect') {
          onToggleConnect?.call();
          return;
        }
        final status = event['status'] as String?;
        if (status != null) onStatus?.call(status);
        final lat = event['lat'];
        if (lat is num && event['lng'] is num) {
          onFix?.call(
            lat.toDouble(),
            (event['lng'] as num).toDouble(),
            (event['alt'] as num?)?.toDouble() ?? 0,
            (event['speed'] as num?)?.toDouble() ?? 0,
            (event['bearing'] as num?)?.toDouble() ?? -1,
            // 缓存位置标记：原生在「快速出图」时置真，上层据此不写轨迹
            event['lastKnown'] == true,
            // 水平精度（米）；原生没给或为 NaN 时按 0（未知）传给上层
            (event['accuracy'] as num?)?.toDouble() ?? 0,
            // 定位来源：原生发 "provider"（gps/network/passive）。上层据此
            // 区分「GPS 实测」与「基站/Wi-Fi 粗定位」—— 后者精度字段常常
            // 报得很乐观（20~40m）却实际偏几百米，只看 accuracy 拦不住。
            (event['provider'] as String?) ?? '',
            // 参与定位的卫星数：只有 Android 侧会带（机型不给时是 null）。
            // 与精度/来源同一类 —— 解析层不读的话，上层永远拿不到它。
            (event['satellites'] as num?)?.toInt(),
          );
        }
      }
    }, onError: (e) {
      onStatus?.call('定位流异常: $e');
    });
  }

  /// 启动持续定位，返回是否成功
  Future<bool> start() async {
    // 从「仅保活」切回真正定位时，必须先停掉保活服务，
    // 否则前台服务仍在运行，下面 _running 判定会失效。
    if (_keepAliveMode) stop();
    if (_running) return true;
    // Windows/Linux 无系统定位能力：直接用 IP 网络定位（纯 Dart，不走原生通道）
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux)) {
      return _startIpLocate();
    }
    try {
      if (kIsWeb) {
        // Web 平台暂未实现
        onStatus?.call('Web 平台暂不支持自动定位，请手动输入坐标');
        return false;
      }
      // iOS / macOS：优先走原生定位（GPS / 系统定位服务）。
      // 若原生通道缺席（未注册或未编译进包），必须回退到 IP 网络定位：
      // 否则 checkPermissions 会抛 MissingPluginException 并被当作「未授权」，
      // 表现为永远停在「请授予定位权限…」而实际永远不可能授权。
      // 仅在这两个平台探测：Android 的 checkPermissions 返回真实权限状态且
      // 不抛异常，在 Android 上做无谓探测只会增加噪。
      if (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS) {
        if (!await _channelAvailable()) {
          onStatus?.call('系统定位不可用，改用网络定位…');
          return _startIpLocate();
        }
      }
      // 检查权限；若未授予，触发权限弹窗（AppState 会每秒重试）
      var hasPerm = await _checkPerm();
      if (!hasPerm) {
        onStatus?.call('请授予定位权限…');
        await _channel.invokeMethod('requestPermissions').catchError((_) {});
        return false;
      }
      // 先订阅事件通道，避免漏掉服务启动后的初始定位
      _listenEvents();
      // 启动前台定位服务（携带定位模式与采样间隔）
      await _channel.invokeMethod('startService',
          {'mode': mode, 'intervalMs': samplingMs});
      _running = true;
      _notifDirty = true; // 同上：服务刚起，去重不能把首次刷新吃掉
      onStatus?.call('GPS 定位中…');
      return true;
    } catch (e) {
      onStatus?.call('定位初始化失败: $e');
      return false;
    }
  }

  /// 动态切换定位模式（服务运行中立即生效）
  Future<void> setMode(String m) async {
    if (m != 'gps' && m != 'gps_network' && m != 'network') return;
    mode = m;
    try {
      await _channel.invokeMethod('setLocationMode', {'mode': m});
    } catch (_) {}
  }

  /// 调 GPS 采样间隔（毫秒）。服务在跑时立即生效，没在跑只记下来 ——
  /// 下一次 [start] 会把它随 `startService` 一起带过去。
  Future<void> setSampling(int ms) async {
    if (ms <= 0) return;
    samplingMs = ms;
    // 仅保活时没有 provider 监听，没必要惊动原生
    if (!_running || _keepAliveMode) return;
    try {
      await _channel.invokeMethod('setSampling', {'intervalMs': ms});
    } catch (_) {}
  }

  /// 桌面 IP 网络定位：通过免费定位 API 获取外网 IP 所在城市坐标。
  /// 精度为城市级，适合业余电台定位/信标参考；首次成功后 onStatus 报告城市。
  Future<bool> _startIpLocate() async {
    _running = true;
    onStatus?.call('网络定位中…');
    // 依次尝试多个免费 IP 定位服务，提高可用性
    const apis = [
      'https://ipwho.is/', // 免费，返回 latitude/longitude/city/region
      'https://ipapi.co/json/', // 备用
      'http://ip-api.com/json/', // 备用（http）
    ];
    for (final url in apis) {
      try {
        final client = HttpClient()
          ..connectionTimeout = const Duration(seconds: 6);
        try {
          final req = await client
              .getUrl(Uri.parse(url))
              .timeout(const Duration(seconds: 6));
          req.headers.set(HttpHeaders.userAgentHeader, 'APRSlocus');
          final resp = await req.close().timeout(const Duration(seconds: 8));
          if (resp.statusCode != 200) continue;
          final body = await resp
              .transform(utf8.decoder)
              .join()
              .timeout(const Duration(seconds: 8));
          final d = jsonDecode(body);
          if (d is! Map) continue;
          // ipwho.is: latitude/longitude/city；ipapi.co: latitude/longitude/city
          final lat = (d['latitude'] as num?)?.toDouble();
          final lng = (d['longitude'] as num?)?.toDouble();
          if (lat == null || lng == null) continue;
          final city = (d['city'] as String?) ?? '';
          final region = (d['region'] as String?) ?? '';
          final place =
              [region, city].where((s) => s.isNotEmpty).join(' · ');
          onStatus?.call(place.isEmpty ? '已定位' : '已定位 · $place');
          // IP 网络定位：一次性的粗略位置，不是轨迹点。
          //
          // 精度按**城市级**如实上报（50km）：以前这个值是「未知」，于是它和
          // 手机 GPS 点在界面上长得一模一样 —— 用户无从知道眼前这个点差了多远。
          // 这个数字参与判断：非 lastKnown 的抖动判定、轨迹写入门限，
          // 而 50km 远超过那些门限，所以 IP 点天然不会写轨迹、也不会被当成
          // 「静止」的可靠依据。
          // source 传 'network'：IP 定位是城市级粗点，与 Wi-Fi 粗定位同类。
          // satellites 传 null：IP 定位没有卫星一说（0 会被误读成「一颗星都没有」）。
          onFix?.call(lat, lng, 0, 0, -1, true, 50000, 'network', null);
          return true;
        } finally {
          client.close(force: true);
        }
      } catch (e) {
        // 尝试下一个服务
      }
    }
    _running = false;
    onStatus?.call('网络定位失败，请在地图上选点');
    return false;
  }

  Future<bool> _checkPerm() async {
    try {
      return await _channel.invokeMethod<bool>('checkPermissions') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 探测原生定位通道是否可用（**仅在 iOS 调用**）。
  /// 返回 false 仅当通道本身未注册（MissingPluginException）；
  /// 通道存在但方法未实现时仍视为可用，避免误降级。
  Future<bool> _channelAvailable() async {
    try {
      await _channel.invokeMethod<bool>('isAvailable');
      return true;
    } on MissingPluginException {
      return false;
    } catch (_) {
      return true;
    }
  }

  void stop() {
    _running = false;
    _keepAliveMode = false;
    _pausedForExternal = false;
    _notifDirty = true; // 服务停了，通知也没了：下次重发不能被去重挡住
    _sub?.cancel();
    _sub = null;
    _channel.invokeMethod('stopService').catchError((_) {});
  }

  /// 更新状态栏通知文字
  ///
  /// **文字没变就不重发**（服务刚重启过时会强制重发一次，见 [_notifDirty]）。
  /// 去重的理由见 [_lastNotifText]：调用点太密，而同一条文字反复 `notify()`
  /// 在部分 ROM 上会被当成新通知再弹一次 —— 用户报的「反复弹出待确认上报」。
  ///
  /// [live]：用户开了实时更新（Android 16 的 Live Updates），[short] 是状态栏
  /// 药丸里那行超短文本（≤7 字符）。两者都算进去重键 —— 改了开关或胶囊文字
  /// 不重发，用户看不到变化。
  Future<void> updateNotification(String text,
      {bool live = false, String short = '', int countdown = 0}) async {
    final key = '$live|$short|$countdown|$text';
    if (!_notifDirty && key == _lastNotifText) return;
    _lastNotifText = key;
    _notifDirty = false;
    try {
      await _channel.invokeMethod('updateNotification', {
        'text': text,
        'short': short,
        'live': live,
        'countdown': countdown
      });
    } catch (_) {}
  }

  /// 常驻通知要不要申请 Android 16 的提升（实时更新）。
  ///
  /// 独立的通道方法，不蹭 [updateNotification]：那是「通知文字变了」，
  /// 而这是「换一条策略」，跟着文字走会在没刷新文字时丢掉。
  void setLiveUpdates(bool on) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      _channel.invokeMethod('setLiveUpdates', {'on': on}).catchError((_) {});
    } catch (_) {}
  }

  /// 通知能力自查（Android 专有）：这台机器支不支持实时更新 / 焦点通知，
  /// 到底缺哪一环。没这个平台就返回空串。
  Future<String> notifDiag(
      {String liveText = '', bool dartRunning = false, String dartStatus = ''}) async {
    try {
      final v = await _channel.invokeMethod<String>('notifDiag', {
        'liveText': liveText,
        'dartRunning': dartRunning,
        'dartStatus': dartStatus,
      });
      return v ?? '';
    } catch (_) {
      return '';
    }
  }

  /// 原生那边前台服务真的在跑吗。
  ///
  /// [running] 只代表「启动调用发出去了」，服务被系统挡下或崩掉时它依然是
  /// true。界面要的是这个问题的答案，所以单独问一次。
  Future<bool> serviceAlive() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      final v = await _channel.invokeMethod<bool>('serviceAlive');
      return v ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 收到 APRS 消息时发系统通知
  Future<void> showMessageNotification(String from, String text) async {
    try {
      await _channel.invokeMethod('showMessage', {'from': from, 'text': text});
    } catch (_) {}
  }

  /// 生命守护强提醒（issue #32）：高优先级 + 震动 + 抬头横幅。
  ///
  /// 与 [showMessageNotification] 的区别是**打扰级别** —— 碰撞/摔倒与心率异常
  /// 不能只是安静地挂在通知栏里（用户没看屏幕时等于没提醒）。
  Future<void> showAlarmNotification(String title, String text) async {
    try {
      await _channel.invokeMethod('showAlarm', {'title': title, 'text': text});
    } catch (_) {}
  }

  /// 群聊事件系统通知（邀请/加入/离开等）
  Future<void> showGroupNotification(String title, String text) async {
    try {
      await _channel.invokeMethod('showMessage', {'from': title, 'text': text});
    } catch (_) {}
  }

  /// 获取手机电量百分比（0-100）
  Future<int> getBatteryLevel() async {
    try {
      return await _channel.invokeMethod<int>('getBattery') ?? -1;
    } catch (_) {
      return -1;
    }
  }
}

/// APRS 数据包格式化工具
class AprsFmt {
  /// 纬度转 APRS ddmm.mm 格式（含方向）
  static String lat(double v) {
    final a = v.abs();
    final deg = a.floor();
    final min = (a - deg) * 60;
    final d = deg.toString().padLeft(2, '0');
    final mStr = min.toStringAsFixed(2);
    final m = mStr.padLeft(5, '0'); // 保证 mm.mm 格式（如 02.51）
    return '$d$m${v >= 0 ? 'N' : 'S'}';
  }

  /// 经度转 APRS dddmm.mm 格式（含方向）
  static String lng(double v) {
    final a = v.abs();
    final deg = a.floor();
    final min = (a - deg) * 60;
    final d = deg.toString().padLeft(3, '0');
    final mStr = min.toStringAsFixed(2);
    final m = mStr.padLeft(5, '0'); // 保证 mm.mm 格式
    return '$d$m${v >= 0 ? 'E' : 'W'}';
  }

  /// 位置模糊：把经纬度**最低位的数字换成空格**（APRS101 第 8 章）。
  ///
  /// 一个空位 = 一格，接收方据此画出一片区域而不是一个点：1 位约 0.1 分
  /// （约 200 米），2 位约 1 分（约 2 公里），3 位约 10 分（约 20 公里）。
  ///
  /// 只换**数字位**：小数点与 N/S/E/W 一律留在原地。有的解析器按字符位切分
  /// 位置字段，少一个字符就整包解析不出位置。
  static String blur(String field, int digits) {
    if (digits <= 0) return field;
    final dir = field.substring(field.length - 1);
    final chars = field.substring(0, field.length - 1).split('');
    var left = digits;
    for (var i = chars.length - 1; i >= 0 && left > 0; i--) {
      if (chars[i] == '.') continue;
      chars[i] = ' ';
      left--;
    }
    return '${chars.join()}$dir';
  }

  /// 位置数据包：CALL>APALOC,TCPIP*:!DDMM.HHN/DDDMM.HHW符号表+符号码+注释
  ///
  /// symbol 参数为符号码（如 '>'）；符号表使用默认主表 '/'
  ///
  /// [path] 默认 `APALOC,TCPIP*` —— 报头目的呼号固定用本应用的 toCall
  /// `APALOC`，第三方（aprs.fi 过滤、统计站）才能凭 tocall 精确筛出
  /// APRSLocus 台站。射频（TNC）模式由 [AppState.txPath] 传入不含
  /// `TCPIP*` 的实际中继路径。
  ///
  /// ⚠️ 默认值勿改回 `APRS`：那会让本应用的报文与其它 APRS 软件
  /// 混为一谈，按 `u/APALOC` 订阅的统计站会全部收不到（v1.6.103 事故）。
  ///
  /// **注释字段必须紧跟符号，中间不能加空格**。APRS101 规定注释数据
  /// （含 CsT：`ddd/sss` 航向/速度）紧接位置字段，没有分隔符；
  /// 一旦插入空格，第三方解析器（aprs.fi 等，普遍用 `^(\d{3})/(\d{3})`
  /// 锚定注释行首）就匹配不上，会把 `ddd/sss` 当成普通备注文字显示，
  /// 即「速度与方位角出现在备注里」。
  /// 实测：带空格 → course/speed 解析为 None；无空格 → 正常解析。
  /// [ambiguity] 是位置模糊位数（0 关，见 [blur]）：把发出去的那个点换成一片
  /// 区域。传 0 时与不带这个参数逐字节相同。
  static String position(
      String call, double latitude, double longitude, String symbol,
      {String? comment, String path = 'APALOC,TCPIP*', int ambiguity = 0}) {
    final body = '!${blur(lat(latitude), ambiguity)}'
        '/${blur(lng(longitude), ambiguity)}$symbol';
    final c = comment?.trim() ?? '';
    return '$call>$path:$body$c';
  }

  /// 消息数据包：CALL>APALOC,TCPIP*::DEST  :text{id
  ///
  /// [path] 为报头路径段（目的呼号 + 中继列表）。APRS-IS 用默认值
  /// （目的呼号 = 本应用 toCall `APALOC`）；射频（TNC）模式传
  /// `APALOC,WIDE1-1` 之类的实际中继路径 —— 射频上不能带 `TCPIP*`
  /// （IP 网关才有的路径，中继不识别）。
  static String message(String call, String dest, String text, String id,
      {String path = 'APALOC,TCPIP*'}) {
    return '$call>$path::${dest.padRight(9)}:$text{$id';
  }

  /// 无需 ack 的消息数据包（群聊广播用）：`{id_` 结尾
  static String messageNoAck(String call, String dest, String text, String id,
      {String path = 'APALOC,TCPIP*'}) {
    return '$call>$path::${dest.padRight(9)}:$text{${id}_';
  }
  static String randId() {
    final r = DateTime.now().millisecondsSinceEpoch;
    return '${r % 10000}'.padLeft(4, '0');
  }
}

/// ─── PHG 数据扩展编码（APRS101 第 9 章）───
///
/// `PHGphgd` 是**固定 7 字节**的数据扩展，四个码位各有自己的量化表：
///
/// | 码位 | 含义 | 取值 |
/// |---|---|---|
/// | p | 发射功率 | 0/1/4/9/16/25/36/49/64/81 W（10 档，**必须取不超过实际值的最大档**）|
/// | h | 天线有效高度（高于当地平均地面）| 10/20/40/…/5120 英尺（10×2ⁿ）|
/// | g | 天线增益 | 0–9 dB（整数）|
/// | d | 天线方向性 | 0=全向，1=东北…8=北 |
///
/// 两个必须照规范做、做错就静默出错的地方：
///
///  1. **功率只能取「不超过实际值的最大档」**。规范说 25 W 的台站写 5 —— 因为
///     写大了会让 aprs.fi 上的通信范围圈画得比实际更远，是在虚报覆盖能力。
///     所以 30 W 只能报 25 W（取 5），不能四舍五入到 36 W。
///  2. **高度是「高于当地平均地面」而不是海拔**。它回答的是「天线在地面上多高」，
///     与 `/A=` 那个海拔是两个完全不同的量，不能互相替代 —— 规范原文特意强调
///     "not above ground or sea level"。
class AprsPhg {
  AprsPhg._();

  /// 功率档（瓦）→ 码位就是下标
  static const List<int> powerSteps = [0, 1, 4, 9, 16, 25, 36, 49, 64, 81];

  /// 天线高度：档位 n（0–9）= 10 × 2ⁿ 英尺
  static int heightStepFeet(int code) => 10 * (1 << code);

  /// 功率（瓦）→ 码位字符。取**不超过**实际值的最大档（见类注释）。
  static int powerCode(num watts) {
    final w = watts.toDouble();
    if (!w.isFinite || w <= 0) return 0;
    var best = 0;
    for (var i = 0; i < powerSteps.length; i++) {
      if (powerSteps[i] <= w) best = i;
    }
    return best;
  }

  /// 天线高度（英尺，高于当地平均地面）→ 码位字符。同样取不超过实际值的最大档。
  static int heightCode(num feet) {
    final f = feet.toDouble();
    if (!f.isFinite || f <= 0) return 0;
    var best = 0;
    for (var i = 0; i < 10; i++) {
      if (heightStepFeet(i) <= f) best = i;
    }
    return best;
  }

  /// 天线增益（dB）→ 码位字符：规范只定义 0–9 的整数档，超出封顶。
  static int gainCode(num db) {
    final d = db.toDouble();
    if (!d.isFinite || d <= 0) return 0;
    final r = d.round();
    return r > 9 ? 9 : r;
  }

  /// 方向性（度）→ 码位字符；[isOmni] 或 0 度表示全向。
  static int directivityCode(int deg, {bool isOmni = true}) {
    if (isOmni) return 0;
    const table = [0, 45, 90, 135, 180, 225, 270, 315, 360];
    var best = 0;
    var bestDiff = 1 << 30;
    for (var i = 1; i < table.length; i++) {
      final diff = (table[i] - deg).abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        best = i;
      }
    }
    return best;
  }

  /// 组装 `PHGphgd`。四个码位一次给全 —— 规范里它就是**一个** 7 字节字段，
  /// 不存在「只报功率不报高度」的写法。
  static String encode({
    required num watts,
    required num heightFeet,
    required num gainDb,
    int directivityDeg = 0,
    bool isOmni = true,
  }) {
    return 'PHG'
        '${powerCode(watts)}'
        '${heightCode(heightFeet)}'
        '${gainCode(gainDb)}'
        '${directivityCode(directivityDeg, isOmni: isOmni)}';
  }

  /// 高度码位 → 展示用米数（设置页回显「这一档实际是多高」）
  static int heightStepMeters(int code) =>
      (heightStepFeet(code) * 0.3048).round();

  /// 解析报文注释里的 PHG 数据扩展（`PHGphgd`）。
  ///
  /// 与 [encode] **严格对称**：功率查 [powerStepWatts]、高度查 [heightStepMeters]、
  /// 增益就是那一位（dB）、方向 0 = 全向（写 360°，不为四个方位引入六语文案）、
  /// 1…8 依次 N / NE / E / SE / S / SW / W / NW。
  ///
  /// 找不到、或位数不够就返回 null —— **不猜**（宁可没有，也不显示一个假的功率）。
  static ({int watts, int heightM, int gainDb, String dir})? decode(String text) {
    final m = RegExp(r'PHG([0-9])([0-9])([0-9])([0-9])').firstMatch(text);
    if (m == null) return null;
    const dirs = ['360°', 'N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final d = int.parse(m.group(4)!);
    return (
      watts: powerStepWatts(int.parse(m.group(1)!)),
      heightM: heightStepMeters(int.parse(m.group(2)!)),
      gainDb: int.parse(m.group(3)!),
      dir: d < dirs.length ? dirs[d] : '?',
    );
  }


  /// 功率码位 → 展示用瓦数
  static int powerStepWatts(int code) => powerSteps[code.clamp(0, 9)];
}
