import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'theme.dart';
import 'widgets.dart';

/// 本平台是否支持**应用内**嵌网页（B 站播放器这类 iframe 内容）。
///
/// Android / iOS / macOS 走 `webview_flutter`（Android WebView / WKWebView）。
/// Web / Linux / **Windows** 没有可用的内嵌后端 → [WebEmbed] 回退成
/// 「在浏览器打开」的卡片。
///
/// 为什么 Windows 不接 `webview_windows`：它的 WebView2 实现与当前
/// Flutter / Visual Studio 工具链不兼容（CI 的 Windows 构建直接失败）。
/// 为不拖垮 Windows 出包，这里只用官方 `webview_flutter`（它不支持 Windows）。
///
/// 旧版兼容：公告里的 `@video` 标记在不认识它的旧版本 app 里只会显示成一行
/// 普通文字（还会被 GFM 自动识别为链接），不会白屏、也不影响其它内容。
bool get webEmbedSupported =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS);

/// 内嵌网页（公告里的 `@video <url>` 用它）。
///
/// 不支持内嵌的平台**不显示空白**：给一张「在浏览器打开」的卡片兜底，
/// 与项目其它「拿不到就如实说」的做法一致。
class WebEmbed extends StatelessWidget {
  final String url;
  final double height;

  const WebEmbed({super.key, required this.url, this.height = 220});

  @override
  Widget build(BuildContext context) {
    if (!webEmbedSupported) return _FallbackCard(url: url, height: height);
    return _MobileEmbed(url: url, height: height);
  }
}

/// 统一的圆角外壳（内嵌内容不允许溢出圆角）
class _EmbedFrame extends StatelessWidget {
  final Widget child;
  final double height;
  const _EmbedFrame({required this.child, required this.height});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(width: double.infinity, height: height, child: child),
    );
  }
}

/// Android / iOS / macOS：webview_flutter
class _MobileEmbed extends StatefulWidget {
  final String url;
  final double height;
  const _MobileEmbed({required this.url, required this.height});

  @override
  State<_MobileEmbed> createState() => _MobileEmbedState();
}

class _MobileEmbedState extends State<_MobileEmbed> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(C.bgSoft);
    _controller.loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return _EmbedFrame(
      height: widget.height,
      child: WebViewWidget(controller: _controller),
    );
  }
}

/// 不支持内嵌 / 初始化失败时的兜底：说明 + 在浏览器打开
class _FallbackCard extends StatelessWidget {
  final String url;
  final double height;
  const _FallbackCard({required this.url, required this.height});

  Future<void> _open() async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: C.bgSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.ondemand_video_rounded, size: 34, color: C.grey),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              S.of(context).openInBrowser,
              textAlign: TextAlign.center,
              style: ts(11, c: C.grey),
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: C.blue,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            ),
            onPressed: _open,
            icon: const Icon(Icons.open_in_new_rounded, size: 16),
            label: Text(S.of(context).openInBrowser, style: ts(12, w: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
