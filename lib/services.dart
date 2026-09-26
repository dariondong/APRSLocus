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
  void Function(double lat, double lng, double alt, double speed, double bearing,
      bool lastKnown, double accuracyM, String source)? onFix;
  void Function(String status)? onStatus;
  /// 通知栏"连接/断开"按钮点击回调
  void Function()? onToggleConnect;

  bool get running => _running;

  /// 仅保活模式：不采集定位，只维持前台服务（Android）让连接与定时器存活。
  /// 非 Android 平台无此服务，返回 false 表示调用方无需处理。
  bool _keepAliveMode = false;

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
      onStatus?.call('模拟位置 · 后台保活已启动');
      return true;
    } catch (e) {
      onStatus?.call('后台保活启动失败: $e');
      return false;
    }
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
      // 启动前台定位服务（携带定位模式）
      await _channel.invokeMethod('startService', {'mode': mode});
      _running = true;
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
          onFix?.call(lat, lng, 0, 0, -1, true, 50000, 'network');
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
    _sub?.cancel();
    _sub = null;
    _channel.invokeMethod('stopService').catchError((_) {});
  }

  /// 更新状态栏通知文字
  Future<void> updateNotification(String text) async {
    try {
      await _channel.invokeMethod('updateNotification', {'text': text});
    } catch (_) {}
  }

  /// 收到 APRS 消息时发系统通知
  Future<void> showMessageNotification(String from, String text) async {
    try {
      await _channel.invokeMethod('showMessage', {'from': from, 'text': text});
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
  static String position(
      String call, double latitude, double longitude, String symbol,
      {String? comment, String path = 'APALOC,TCPIP*'}) {
    final body = '!${lat(latitude)}/${lng(longitude)}$symbol';
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
