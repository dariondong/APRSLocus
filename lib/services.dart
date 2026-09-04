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
  /// 定位模式：'gps' = 纯 GPS；'gps_network' = GPS + 网络辅助
  String mode = 'gps_network';
  void Function(double lat, double lng, double alt, double speed, double bearing)?
      onFix;
  void Function(String status)? onStatus;
  /// 通知栏"连接/断开"按钮点击回调
  void Function()? onToggleConnect;

  bool get running => _running;

  /// 启动持续定位，返回是否成功
  Future<bool> start() async {
    if (_running) return true;
    // 桌面平台：无系统 GPS，改用 IP 网络定位（纯 Dart，不依赖原生通道）
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      return _startIpLocate();
    }
    try {
      if (kIsWeb) {
        // Web 平台暂未实现
        onStatus?.call('Web 平台暂不支持自动定位，请手动输入坐标');
        return false;
      }
      // 检查权限；若未授予，触发权限弹窗（AppState 会每秒重试）
      var hasPerm = await _checkPerm();
      if (!hasPerm) {
        onStatus?.call('请授予定位权限…');
        await _channel.invokeMethod('requestPermissions').catchError((_) {});
        return false;
      }
      // 先订阅事件通道，避免漏掉服务启动后的初始定位
      _sub = _eventChannel.receiveBroadcastStream().listen((event) {
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
            );
          }
        }
      }, onError: (e) {
        onStatus?.call('定位流异常: $e');
      });
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
    if (m != 'gps' && m != 'gps_network') return;
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
          onFix?.call(lat, lng, 0, 0, -1);
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

  void stop() {
    _running = false;
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

  /// 位置数据包：CALL>APRS,TCPIP*:!DDMM.HHN/DDDMM.HHW/符号表+符号码
  /// symbol 参数为符号码（如 '>'）；符号表使用默认主表 '/'
  /// path 可自定义（如 APALOC 标识 APRSlocus 台站）
  static String position(
      String call, double latitude, double longitude, String symbol,
      {String? comment, String path = 'APRS,TCPIP*'}) {
    final body = '!${lat(latitude)}/${lng(longitude)}$symbol';
    return '$call>$path:$body${comment != null ? ' $comment' : ''}';
  }

  /// 消息数据包：CALL>APRS,TCPIP*::DEST  :text{id
  static String message(String call, String dest, String text, String id) {
    return '$call>APRS,TCPIP*::${dest.padRight(9)}:$text{$id';
  }

  /// 无需 ack 的消息数据包（群聊广播用）：`{id_` 结尾
  static String messageNoAck(String call, String dest, String text, String id) {
    return '$call>APRS,TCPIP*::${dest.padRight(9)}:$text{${id}_';
  }
  static String randId() {
    final r = DateTime.now().millisecondsSinceEpoch;
    return '${r % 10000}'.padLeft(4, '0');
  }
}
