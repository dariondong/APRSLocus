import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'garmin.dart';
import 'material.dart';
import 'state.dart';
import 'theme.dart';
import 'widgets.dart';

/// 佳明 LiveTrack 设置页：粘贴分享链接 / 从剪贴板取 / 开关追踪 / 看状态。
///
/// ── 为什么要有这一页（而不是只有分享入口）──
/// 分享入口（Android 分享面板里的 APRSlocus）只能覆盖「用户主动分享」这一条路。
/// 还有两条同样常见的路：链接是别人给的、链接在电脑上。所以页面里必须能**手贴**，
/// 并且把「怎么从佳明 App 拿到链接」写清楚（用户第一次用不知道去哪找）。
class GarminTrackPage extends StatefulWidget {
  /// 与其它设置子页同一口径：状态由外壳传进来（本仓库没有全局单例）。
  final AppState state;
  const GarminTrackPage({super.key, required this.state});

  @override
  State<GarminTrackPage> createState() => _GarminTrackPageState();
}

class _GarminTrackPageState extends State<GarminTrackPage> {
  late final TextEditingController _url;
  /// 链接格式不对时的提示（提交后才显示，输入过程中不打断）。
  bool _badUrl = false;

  @override
  void initState() {
    super.initState();
    _url = TextEditingController(text: widget.state.garminUrl);
  }

  @override
  void dispose() {
    _url.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    if (text.isEmpty) return;
    // 整段分享文案可能很长（带一堆说明文字），只取链接那段 —— 与
    // AppState._onSharedIncoming 用同一个抽取函数，两处口径不会漂。
    final url = extractLiveTrackUrl(text) ?? text.trim();
    _url.text = url;
    setState(() => _badUrl = false);
  }

  Future<void> _toggle(AppState st, bool on) async {
    st.garminUrl = _url.text.trim();
    final ok = await st.setGarminOn(on);
    if (!mounted) return;
    setState(() => _badUrl = on && !ok);
    if (!ok && on) return; // 链接不合法：就地提示，不弹多余的东西
    if (on) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(S.of(context).garminRunning),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      backgroundColor: C.pageFill,
      // MaterialAppBar 不能省：材质开启时顶栏是**半透明壳表面**，必须套材质壳，
      // 否则会半透明但不模糊、底下的内容直接透出来（见 material.dart 的说明）。
      appBar: MaterialAppBar(
        AppBar(
        backgroundColor: C.surfaceFillStrong,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: C.ink, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
          title: Text(s.garminCardTitle, style: ts(16, w: FontWeight.w700)),
          centerTitle: true,
        ),
      ),
      body: ListenableBuilder(
        listenable: widget.state,
        builder: (context, _) {
          final st = widget.state;
          final g = st.garmin;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
            children: [
              SoftCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _switchRow(
                      title: s.garminRunning,
                      value: g.on,
                      onChanged: (v) => _toggle(st, v),
                    ),
                    if (g.on) ...[
                      _kv(
                        s.garminStats(
                          '${g.forwarded}',
                          g.lastFetchAt == null
                              ? '--'
                              : '${g.lastFetchAt!.hour.toString().padLeft(2, '0')}:'
                                  '${g.lastFetchAt!.minute.toString().padLeft(2, '0')}',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(s.garminUrlLabel, style: ts(12, c: C.grey, w: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: _url,
                style: ts(13),
                decoration: InputDecoration(
                  hintText: s.garminUrlHint,
                  hintStyle: ts(12, c: C.greyLight),
                  filled: true,
                  fillColor: C.bgSoft,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: IconButton(
                    tooltip: s.garminPaste,
                    icon: Icon(Icons.content_paste_rounded, size: 18, color: C.blue),
                    onPressed: _pasteFromClipboard,
                  ),
                ),
                onChanged: (_) {
                  if (_badUrl) setState(() => _badUrl = false);
                },
              ),
              if (_badUrl) ...[
                const SizedBox(height: 8),
                _hint(s.garminBadUrl, C.red, Icons.error_outline_rounded),
              ],
              const SizedBox(height: 10),
              // 状态：出错 / 还没取到点 / 正常（正常时上面那行已给出计数）
              if (g.on && g.lastError.isNotEmpty && g.lastError != 'badurl')
                _hint(s.garminError(g.lastError), C.orange, Icons.warning_amber_rounded)
              else if (g.on && g.forwarded == 0)
                _hint(s.garminNoPoints, C.grey, Icons.hourglass_empty_rounded),
              const SizedBox(height: 6),
              // Web 版抓不了（浏览器跨域），这里直说，别让用户以为是自己配错了。
              if (!garminFetchSupported)
                _hint(s.garminWebUnsupported, C.orange, Icons.public_off_rounded),
              const SizedBox(height: 18),
              Text(s.garminHowTo, style: ts(11.5, c: C.slate, h: 1.7)),
            ],
          );
        },
      ),
    );
  }

  Widget _switchRow({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      child: Row(
        children: [
          Expanded(child: Text(title, style: ts(13, w: FontWeight.w600))),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _kv(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(text, style: ts(11, c: C.grey)),
        ),
      );

  Widget _hint(String text, Color c, IconData icon) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: c),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text, style: ts(11, c: c, h: 1.5)),
          ),
        ],
      );
}
