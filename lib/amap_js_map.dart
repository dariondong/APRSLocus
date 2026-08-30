import 'dart:convert';

import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_windows/webview_windows.dart' as wvw;

import 'theme.dart';
import 'models.dart';
import 'coord.dart';
import 'l10n/app_localizations.dart';

/// 高德 JS API 地图（WebView 承载）
/// - Android: webview_flutter
/// - Windows: webview_windows (WebView2)
/// 高德坐标 GCJ-02，传入/回调均做 WGS-84 ↔ GCJ-02 转换。
class AmapJsMapView extends StatefulWidget {
  final List<Station> stations;
  // 台站数据版本：未变化时跳过 _syncAll（避免每秒把全部台站 JSON 推给 JS）
  final int stationsVersion;
  final String myCall;
  final bool myHasFix;
  final double? myLat, myLng;
  final void Function(double lat, double lng)? onTap;
  final void Function(Station s)? onStationTap;
  final void Function()? onMyLocationTap;
  // 焦点跳转：focusSeq 变化 → 平移到目标
  final int focusSeq;
  final double? focusLat, focusLng;
  // 外部动作：actionSeq 变化 → 执行 action（zoomIn/zoomOut/myLoc）
  final int actionSeq;
  final String action;
  final bool showTracks;

  const AmapJsMapView({
    super.key,
    required this.stations,
    this.stationsVersion = 0,
    required this.myCall,
    required this.myHasFix,
    this.myLat,
    this.myLng,
    this.onTap,
    this.onStationTap,
    this.onMyLocationTap,
    this.focusSeq = 0,
    this.focusLat,
    this.focusLng,
    this.actionSeq = 0,
    this.action = '',
    this.showTracks = true,
  });

  @override
  State<AmapJsMapView> createState() => _AmapJsMapViewState();
}

class _AmapJsMapViewState extends State<AmapJsMapView> {
  WebViewController? _webCtrl; // Android/iOS
  wvw.WebviewController? _winCtrl; // Windows
  bool _winInitError = false;
  bool _mapReady = false;
  int _lastFocusSeq = -1;
  int _lastActionSeq = -1;
  Size? _viewSize;

  bool get _isWindows =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    if (_isWindows) {
      final c = wvw.WebviewController();
      try {
        await c.initialize();
        await c.setPopupWindowPolicy(wvw.WebviewPopupWindowPolicy.deny);
        final html = await _loadHtml();
        await c.loadStringContent(html);
        c.webMessage.listen(_onWebMessage);
        if (mounted) setState(() => _winCtrl = c);
      } catch (_) {
        if (mounted) setState(() => _winInitError = true);
      }
    } else {
      final c = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..addJavaScriptChannel(
          'AmapBridge',
          onMessageReceived: (m) {
            _onWebMessage(m.message);
          },
        );
      await c.loadFlutterAsset('assets/amap_map.html');
      if (mounted) setState(() => _webCtrl = c);
    }
  }

  static String? _htmlCache;
  static Future<String> _loadHtml() async {
    if (_htmlCache != null) return _htmlCache!;
    final html = await rootBundle.loadString('assets/amap_map.html');
    _htmlCache = html;
    return html;
  }

  void _onWebMessage(dynamic raw) {
    try {
      final msg = jsonDecode(raw.toString()) as Map<String, dynamic>;
      switch (msg['type']) {
        case 'ready':
          if (!_mapReady) {
            _mapReady = true;
            if (_viewSize != null) {
              _eval(
                '__setSize(${_viewSize!.width.round()},${_viewSize!.height.round()})',
              );
            }
            if (widget.myHasFix &&
                widget.myLat != null &&
                widget.myLng != null) {
              final g = Gcj.wgsToGcj(widget.myLat!, widget.myLng!);
              _eval("setInitCenter(${g.$2},${g.$1},13)");
            }
            _syncAll();
            _applyFocusIfAny();
          }
          break;
        case 'marker':
          final call = msg['call'] as String?;
          if (call == null) return;
          for (final s in widget.stations) {
            if (s.call == call) {
              widget.onStationTap?.call(s);
              break;
            }
          }
          break;
        case 'map':
          final lat = (msg['lat'] as num).toDouble();
          final lng = (msg['lng'] as num).toDouble();
          final w = Gcj.gcjToWgs(lat, lng);
          widget.onTap?.call(w.$1, w.$2);
          break;
        case 'myloc':
          widget.onMyLocationTap?.call();
          break;
        case 'diag':
          setState(() {
            _diag =
                'px=${msg['px']},py=${msg['py']}\n'
                'size=${msg['sizeW']}x${msg['sizeH']} dpr=${msg['dpr']}\n'
                'anchor=(${msg['anchorLat']},${msg['anchorLng']})\n'
                'after=${msg['after']} zoom=${msg['zoom']}';
          });
          break;
      }
    } catch (_) {}
  }

  Future<void> _eval(String js) async {
    try {
      if (_webCtrl != null) {
        await _webCtrl!.runJavaScript(js);
      } else if (_winCtrl != null) {
        await _winCtrl!.executeScript(js);
      }
    } catch (_) {}
  }

  @override
  void didUpdateWidget(covariant AmapJsMapView old) {
    super.didUpdateWidget(old);
    if (widget.focusSeq != old.focusSeq) _applyFocusIfAny();
    if (widget.actionSeq != old.actionSeq) _handleAction();
    // 仅当台站/轨迹/我的位置实际变化时才把数据推给 JS，
    // 避免每秒 tick 重建时反复 setStations/setTracks（高德 JS 全量更新开销大）
    final dataChanged =
        widget.stationsVersion != old.stationsVersion ||
        widget.showTracks != old.showTracks ||
        widget.myHasFix != old.myHasFix ||
        widget.myLat != old.myLat ||
        widget.myLng != old.myLng;
    if (_mapReady && dataChanged) _syncAll();
  }

  void _handleAction() {
    _lastActionSeq = widget.actionSeq;
    switch (widget.action) {
      case 'zoomIn':
        _eval('zoomBy(1)');
        break;
      case 'zoomOut':
        _eval('zoomBy(-1)');
        break;
      case 'myLoc':
        _eval('myLocFocus()');
        break;
    }
  }

  void _applyFocusIfAny() {
    if (_lastFocusSeq == widget.focusSeq) return;
    if (widget.focusLat == null || widget.focusLng == null) return;
    _lastFocusSeq = widget.focusSeq;
    _eval('focusOn(${widget.focusLng},${widget.focusLat},14)');
  }

  String _colorHex(Color c) {
    String h(int v) => v.toRadixString(16).padLeft(2, '0');
    return '#${h(c.red)}${h(c.green)}${h(c.blue)}';
  }

  void _syncAll() {
    // 台站标记（WGS → GCJ）
    final stations = <Map<String, dynamic>>[];
    for (final s in widget.stations) {
      if (s.call == widget.myCall || (s.lat == 0 && s.lng == 0)) continue;
      final g = Gcj.wgsToGcj(s.lat, s.lng);
      final col = _colorHex(s.color);
      final label = const HtmlEscape().convert(s.call);
      stations.add({
        'call': s.call,
        'lng': g.$2,
        'lat': g.$1,
        'content':
            '<div class="stn-wrap">'
            '<div class="stn-icon" style="background:$col">•</div>'
            '<div class="stn-label" style="color:$col">$label</div>'
            '</div>',
      });
    }
    _eval('setStations(${jsonEncode(stations)})');

    // 轨迹（WGS → GCJ，lng,lat）
    final tracks = <Map<String, dynamic>>[];
    if (widget.showTracks) {
      for (final s in widget.stations) {
        if (s.track.length < 2) continue;
        final col = _colorHex(s.color);
        tracks.add({
          'color': col,
          'points': s.track.map((p) {
            final g = Gcj.wgsToGcj(p.lat, p.lng);
            return [g.$2, g.$1];
          }).toList(),
        });
      }
    }
    _eval('setTracks(${jsonEncode(tracks)})');

    // 我的位置
    if (widget.myHasFix && widget.myLat != null && widget.myLng != null) {
      final g = Gcj.wgsToGcj(widget.myLat!, widget.myLng!);
      _eval('setMyLocation(${jsonEncode({'lng': g.$2, 'lat': g.$1})})');
    }
  }

  // 诊断信息（显示在地图角落，方便排查缩放问题）
  String _diag = '';

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final s = Size(constraints.maxWidth, constraints.maxHeight);
        if (s.width > 0 && s.height > 0 && s != _viewSize) {
          _viewSize = s;
          if (_mapReady) {
            _eval('__setSize(${s.width.round()},${s.height.round()})');
          }
        }
        Widget map;
        if (kIsWeb) {
          map = Center(
            child: Text(
              AppLocalizations.of(context).webAmapUnsupported,
              style: TextStyle(color: C.grey, fontSize: 12),
            ),
          );
        } else if (_isWindows) {
          if (_winInitError) {
            map = Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline_rounded, color: C.red, size: 36),
                  SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context).webview2InitFailed,
                    textAlign: TextAlign.center,
                    style: ts(12, c: C.red, w: FontWeight.w600),
                  ),
                ],
              ),
            );
          } else {
            final c = _winCtrl;
            map = c == null ? _loading() : _wrapScroll(wvw.Webview(c));
          }
        } else {
          final c = _webCtrl;
          map = c == null
              ? _loading()
              : _wrapScroll(WebViewWidget(controller: c));
        }
        // 叠加诊断浮层
        return Stack(
          children: [
            Positioned.fill(child: map),
            if (_diag.isNotEmpty)
              Positioned(
                left: 8,
                bottom: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _diag,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      height: 1.3,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  /// 捕获滚轮事件，用 Flutter 层的精确坐标传给 JS 做锚点缩放。
  /// （WebView2 给页面的鼠标坐标恒为 0，必须从 Flutter 侧获取位置）
  Widget _wrapScroll(Widget child) {
    if (!_mapReady) return child;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerSignal: (e) {
        if (e is PointerScrollEvent && _mapReady) {
          final px = e.localPosition.dx;
          final py = e.localPosition.dy;
          final delta = e.scrollDelta.dy > 0 ? 1 : -1;
          _eval(
            'zoomAt(${px.toStringAsFixed(1)},${py.toStringAsFixed(1)},$delta)',
          );
        }
      },
      child: child,
    );
  }

  Widget _loading() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(strokeWidth: 2.5),
          SizedBox(height: 10),
          Text(
            AppLocalizations.of(context).loadingAmap,
            style: TextStyle(color: C.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
