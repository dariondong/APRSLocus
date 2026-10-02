import 'package:flutter/material.dart';

import 'state.dart';
import 'theme.dart';
import 'widgets.dart';

/// ─── 连接服务器前必须签署的「数据与网络使用告知」───
///
/// 为什么要有这一页：本软件不提供、不运营、也不推荐任何服务器地址
/// （用户协议 2.4 / 2.5）。既然"连不连、连到哪里"是用户自己的事，就不能由软件
/// 默认替他决定 —— 所以第一次启用服务器连接前，必须明确同意一次。
///
/// 用**整页**而不是小弹窗：这是要读的内容，不是"随手点掉"的提示。不签也完全可用
/// （软件本来就默认不连接任何服务器，本地功能都在）。
class DataNoticePage extends StatelessWidget {
  final AppState state;
  const DataNoticePage({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      backgroundColor: C.pageFill,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 24, 22, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: C.blue.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Icon(Icons.privacy_tip_rounded,
                              size: 20, color: C.blue),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            s.dataNoticeTitle,
                            style: ts(16, w: FontWeight.w800, c: C.ink),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(s.dataNoticeBody, style: ts(13, c: C.slate, h: 1.7)),
                  ],
                ),
              ),
            ),
            // 同意才连；暂不连接则保持本地（两个按钮都能离开这一页 —— 不签不是死路）
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: state.declineDataNotice,
                      child: Text(s.dataNoticeDecline),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: state.acceptDataNotice,
                      style: FilledButton.styleFrom(backgroundColor: C.blue),
                      child: Text(s.dataNoticeAccept),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
