import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'garmin.dart';
import 'material.dart';
import 'state.dart';
import 'theme.dart';
import 'widgets.dart';

/// 佳明 LiveTrack 设置页：粘贴分享链接 / 从剪贴板取 / **开始追踪** / 看状态。
///
/// ── 为什么要有这一页（而不是只有分享入口）──
/// 分享入口（Android 分享面板里的 APRSLocus）只能覆盖「用户主动分享」这一条路。
/// 还有两条同样常见的路：链接是别人给的、链接在电脑上。所以页面里必须能**手贴**，
/// 并且把「怎么从佳明 App 拿到链接」写清楚（用户第一次用不知道去哪找）。
///
/// ── v1.6.173 重做（用户实测反馈的三点）──
/// 「佳明的跳转还是有问题的，它也不会自动填充」「我也不知道他生效了没有，
/// 都没有一个确定按钮，和状态显示」。三条都是真的，逐条改：
///
///   1. **自动填充**：`_url` 原来只在 `initState` 读一次 `state.garminUrl` ——
///      而分享进来时页面**已经开着**（或顺序反过来），文本框就永远停在旧内容。
///      现在监听 state，外部改了就同步进文本框（正在手动编辑时不覆盖），
///      并显示一行「已自动填入分享链接」让用户知道**发生了**。
///   2. **确定按钮**：原来只有一个 `Switch`，而它的标签写的是「追踪中」——
///      那是**状态**不是**动作**，用户根本不知道点了会不会生效、生效了没有。
///      现在换成明确的 `[开始追踪]` / `[停止追踪]` 主按钮。
///   3. **状态显示**：新增状态卡，一眼能看出 未开启 / 追踪中（含已转发点数、
///      最后更新时间）/ 抓取失败（含原因）/ 链接无效。
class GarminTrackPage extends StatefulWidget {
  /// 与其它设置子页同一口径：状态由外壳传进来（本仓库没有全局单例）。
  final AppState state;
  const GarminTrackPage({super.key, required this.state});

  @override
  State<GarminTrackPage> createState() => _GarminTrackPageState();
}

class _GarminTrackPageState extends State<GarminTrackPage> {
  late final TextEditingController _url;
  final FocusNode _urlFocus = FocusNode();

  /// 链接格式不对时的提示（提交后才显示，输入过程中不打断）。
  bool _badUrl = false;

  /// 本次填入是「分享自动填的」（用来显示那一行确认提示）。
  bool _autoFilled = false;

  /// 上一次从 state 读到的链接：只在**外部真的改了**时同步文本框。
  String _lastStateUrl = '';

  @override
  void initState() {
    super.initState();
    _url = TextEditingController(text: widget.state.garminUrl);
    _lastStateUrl = widget.state.garminUrl;
    // 分享进来时 state.garminUrl 会变 —— 必须跟着同步，否则页面开着时文本框不动
    // （用户报的「它也不会自动填充」）。
    widget.state.addListener(_syncFromState);
  }

  @override
  void dispose() {
    widget.state.removeListener(_syncFromState);
    _urlFocus.dispose();
    _url.dispose();
    super.dispose();
  }

  /// state 里的链接变了（多半是刚分享进来）→ 同步进文本框并给出确认。
  void _syncFromState() {
    if (!mounted) return;
    final u = widget.state.garminUrl;
    if (u == _lastStateUrl) return;
    _lastStateUrl = u;
    if (u.isEmpty) return;
    // 用户正在手动改：不覆盖他（否则会把正在输入的内容顶掉）。
    if (_urlFocus.hasFocus) return;
    setState(() {
      _url.text = u;
      _badUrl = false;
      _autoFilled = true;
    });
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    if (text.isEmpty) return;
    // 整段分享文案可能很长（带一堆说明文字），只取链接那段 —— 与
    // AppState._onSharedIncoming 用同一个抽取函数，两处口径不会漂。
    final url = extractLiveTrackUrl(text) ?? text.trim();
    setState(() {
      _url.text = url;
      _badUrl = false;
      _autoFilled = false;
    });
  }

  /// **确定按钮**：开始追踪。
  Future<void> _start() async {
    final st = widget.state;
    final typed = _url.text.trim();
    st.garminUrl = typed;
    if (typed.isEmpty) {
      setState(() => _badUrl = true);
      return;
    }
    final ok = await st.setGarminOn(true);
    if (!mounted) return;
    setState(() {
      _badUrl = !ok;
      if (ok) _autoFilled = false;
    });
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(S.of(context).garminRunning),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _stop() async {
    await widget.state.setGarminOn(false);
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
          final linkOk = extractLiveTrackUrl(_url.text) != null;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
            children: [
              // ① 状态卡：一眼看出「生效了没有」
              SoftCard(
                padding: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _statusRow(st),
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
                      if (g.lastError.isNotEmpty && g.lastError != 'badurl')
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                          child: _hint(
                            s.garminError(g.lastError),
                            C.orange,
                            Icons.warning_amber_rounded,
                          ),
                        )
                      else if (g.forwarded == 0)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                          child: _hint(
                            s.garminNoPoints,
                            C.grey,
                            Icons.hourglass_empty_rounded,
                          ),
                        ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
              // ② 链接
              Text(s.garminUrlLabel, style: ts(12, c: C.grey, w: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: _url,
                focusNode: _urlFocus,
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
              // 自动填入的确认（用户报「不知道它生效了没有」）
              if (_autoFilled) ...[
                const SizedBox(height: 8),
                _hint(s.garminAutoFilled, C.green, Icons.check_circle_outline_rounded),
              ],
              if (_badUrl) ...[
                const SizedBox(height: 8),
                _hint(s.garminBadUrl, C.red, Icons.error_outline_rounded),
              ],
              // 链接有效性（输入时实时判断，比等报错友好）
              if (!_badUrl && _url.text.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                _hint(
                  linkOk ? s.garminLinkOk : s.garminBadUrl,
                  linkOk ? C.grey : C.red,
                  linkOk
                      ? Icons.check_circle_outline_rounded
                      : Icons.error_outline_rounded,
                ),
              ],
              const SizedBox(height: 14),
              // ③ **确定按钮**：明确的动作，而不是一个含义模糊的开关
              SizedBox(
                width: double.infinity,
                height: 46,
                child: FilledButton.icon(
                  onPressed: g.on ? null : _start,
                  icon: const Icon(Icons.play_arrow_rounded, size: 20),
                  label: Text(
                    g.on ? s.garminRunning : s.garminStart,
                    style: ts(13.5, c: Colors.white, w: FontWeight.w700),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: C.green,
                    disabledBackgroundColor: C.greyBg,
                    disabledForegroundColor: C.grey,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              if (g.on) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton.icon(
                    onPressed: _stop,
                    icon: const Icon(Icons.stop_rounded, size: 18),
                    label: Text(s.garminStop,
                        style: ts(13, c: C.red, w: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: C.red,
                      side: BorderSide(color: C.red.withValues(alpha: 0.4)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 10),
              // Web 版抓不了（浏览器跨域），这里直说，别让用户以为是自己配错了。
              if (!garminFetchSupported)
                _hint(s.garminWebUnsupported, C.orange, Icons.public_off_rounded),
              const SizedBox(height: 20),
              Text(s.garminHowTo, style: ts(11.5, c: C.slate, h: 1.7)),
            ],
          );
        },
      ),
    );
  }

  /// 状态行：未开启 / 追踪中（绿）/ 抓取失败（橙）。
  Widget _statusRow(AppState st) {
    final s = S.of(context);
    final g = st.garmin;
    final Color c;
    final IconData icon;
    final String label;
    if (!g.on) {
      c = C.grey;
      icon = Icons.pause_circle_outline_rounded;
      label = s.garminNotStarted;
    } else if (g.lastError.isNotEmpty && g.lastError != 'badurl' && g.forwarded == 0) {
      c = C.orange;
      icon = Icons.warning_amber_rounded;
      label = s.garminError(g.lastError);
    } else {
      c = C.green;
      icon = Icons.play_circle_outline_rounded;
      label = s.garminRunning;
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: c),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: ts(12.5, c: c, w: FontWeight.w700)),
          ),
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
