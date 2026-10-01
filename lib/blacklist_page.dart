import 'package:flutter/material.dart';

import 'blacklist.dart';
import 'state.dart';
import 'theme.dart';
import 'widgets.dart';

/// ─── 被远程限制名单命中时的拦截页 ───
///
/// 用**整页**而不是弹窗 / 横幅：命中就意味着"不能用这个软件"，那么界面上就不该
/// 还留着一半能点的东西（那些按钮点下去只会报错）。
///
/// 页面要如实回答三件事，缺一个用户就会以为"软件坏了"：
///   * **为什么**（引到用户协议第 8.2 条 —— 我们有权限制违反协议者的使用）；
///   * **命中的是哪一项**（呼号 / 安装标识，一字不改地显示出来，便于核对是不是误判）；
///   * **怎么申诉**（GitHub Issue + 附上那个标识）。
class BlacklistPage extends StatefulWidget {
  final BlacklistHit hit;
  final AppState state;
  const BlacklistPage({super.key, required this.hit, required this.state});

  @override
  State<BlacklistPage> createState() => _BlacklistPageState();
}

class _BlacklistPageState extends State<BlacklistPage> {
  bool _busy = false;
  String _deviceId = '';

  @override
  void initState() {
    super.initState();
    Blacklist.deviceId().then((v) {
      if (mounted) setState(() => _deviceId = v);
    });
  }

  Future<void> _retry() async {
    setState(() => _busy = true);
    // 重新拉一次名单：解除了限制就能立刻放行（不用等 6 小时的节流）
    await widget.state.recheckBlacklist(force: true);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final hit = widget.hit;
    return Scaffold(
      backgroundColor: C.pageFill,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Container(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
              decoration: BoxDecoration(
                color: C.surfaceFill,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: C.border, width: 0.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: C.red.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(Icons.block_rounded, size: 20, color: C.red),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(s.blTitle,
                          style: ts(16, w: FontWeight.w800, c: C.ink)),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  Text(s.blBody, style: ts(13, c: C.slate, h: 1.7)),
                  const SizedBox(height: 14),
                  if (hit.reason.isNotEmpty) ...[
                    Text(s.blReason, style: ts(11, c: C.grey, w: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(hit.reason, style: ts(13, c: C.ink, h: 1.6)),
                    const SizedBox(height: 12),
                  ],
                  // 命中的是哪一项 + 本机安装标识：**一字不改地显示**，
                  // 误判时用户能直接把这一行贴给我们（否则只能来回问）
                  Text(s.blMatched, style: ts(11, c: C.grey, w: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(hit.matched,
                      style: ts(12, c: C.ink, h: 1.5)
                          .copyWith(fontFamily: 'monospace')),
                  if (_deviceId.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(s.blId, style: ts(11, c: C.grey, w: FontWeight.w700)),
                    const SizedBox(height: 3),
                    SelectableText(_deviceId,
                        style: ts(12, c: C.ink, h: 1.5)
                            .copyWith(fontFamily: 'monospace')),
                  ],
                  const SizedBox(height: 14),
                  Text(s.blContact, style: ts(12, c: C.slate, h: 1.6)),
                  const SizedBox(height: 16),
                  Row(children: [
                    FilledButton.icon(
                      onPressed: _busy ? null : _retry,
                      icon: _busy
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh_rounded, size: 16),
                      label: Text(_busy ? s.blChecking : s.blRetry),
                      style: FilledButton.styleFrom(
                        backgroundColor: C.blue,
                        textStyle: ts(12, c: Colors.white, w: FontWeight.w600),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
