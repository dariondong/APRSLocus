import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:flutter/services.dart' show rootBundle;

import 'models.dart';

/// APRS 官方符号图标的**画布版**缓存。
///
/// 台站标记平时是 Widget（`AprsSymbolImage`），但沉浸地图整层是一个
/// `CustomPainter`（要跟着航向整体旋转），那里拿不到 Widget，只能把 PNG
/// 解码成 `ui.Image` 后自己 `drawImageRect`。
///
/// 规则很简单：
/// - [get] **同步**返回已缓存的图；没有就顺手开始解码并返回 null，
///   解码完调用一次 [onReady]，由调用方重绘；
/// - 同一张图只解码一次（_loading 挡住并发重复请求）；
/// - 资源缺失或解码失败一律静默（画布层回退成圆点），不影响地图本身。
class AprsSymbolImages {
  AprsSymbolImages._();

  static final Map<String, ui.Image> _cache = <String, ui.Image>{};
  static final Set<String> _loading = <String>{};

  /// 缓存里已有的图（不触发加载）
  static ui.Image? peek(String table, String symbol) {
    final path = AprsSym.iconAsset(table.isEmpty ? '/' : table, symbol);
    return path == null ? null : _cache[path];
  }

  /// 取图；没有则开始异步解码，完成后回调 [onReady]
  static ui.Image? get(
    String table,
    String symbol, {
    VoidCallback? onReady,
  }) {
    final path = AprsSym.iconAsset(table.isEmpty ? '/' : table, symbol);
    if (path == null) return null;
    final hit = _cache[path];
    if (hit != null) return hit;
    if (_loading.add(path)) {
      rootBundle.load(path).then((data) async {
        final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        codec.dispose();
        _cache[path] = frame.image;
        _loading.remove(path);
        onReady?.call();
      }).catchError((Object _) {
        _loading.remove(path);
        return null;
      });
    }
    return null;
  }

  /// 预热一组符号（页面打开时先解码，第一帧就不是圆点）
  static void warm(Iterable<(String, String)> symbols, {VoidCallback? onReady}) {
    for (final (table, sym) in symbols) {
      get(table, sym, onReady: onReady);
    }
  }
}
