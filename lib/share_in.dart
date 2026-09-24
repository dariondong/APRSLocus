import 'dart:async';

import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/services.dart';

/// 「别的 App 分享内容给 APRSlocus」的入口。
///
/// 为什么需要它（用户需求）：佳明 Connect / Garmin 系列 App 里的 LiveTrack 有
/// 「分享」按钮，但分享目标里本来没有我们 —— 用户只能自己复制链接、再切到
/// APRSlocus 里粘贴。注册一个 `ACTION_SEND`（text/plain）的 intent-filter 之后，
/// 佳明的分享面板里就会出现 APRSlocus，点一下就落到设置页，省掉复制粘贴。
///
/// 两条路径都要接：
///   * **冷启动**：应用没在运行时被分享唤起 → 原生把文本存起来，Dart 起来后
///     `takePending()` 取走；
///   * **热启动**：应用在后台时分享 → Activity 是 `singleTop`，只会走
///     `onNewIntent`，原生通过事件通道推过来（**不重写 onNewIntent 就会丢**）。
class ShareInService {
  ShareInService._();
  static final ShareInService instance = ShareInService._();

  static const MethodChannel _ch = MethodChannel('com.aprslocus/share_in');
  static const EventChannel _ev = EventChannel('com.aprslocus/share_in_events');

  bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  StreamSubscription? _sub;
  bool _init = false;

  /// 收到分享文本（已由原生过滤过：只有含 `livetrack.garmin.com` 的才会到这里）。
  void Function(String text)? onShared;

  Future<void> ensureInit() async {
    if (_init) return;
    _init = true;
    if (!isAndroid) return;
    _sub ??= _ev.receiveBroadcastStream().listen((event) {
      if (event is Map && event['type'] == 'shared') {
        final text = event['text'] as String?;
        if (text != null && text.isNotEmpty) onShared?.call(text);
      }
    });
    // 冷启动路径：把启动时那一次分享取走（取完即清，不会重复触发）。
    try {
      final text = await _ch.invokeMethod<String>('takePendingSharedText');
      if (text != null && text.isNotEmpty) onShared?.call(text);
    } catch (_) {
      // 桌面/Web 或原生未实现：静默
    }
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
    onShared = null;
  }
}
