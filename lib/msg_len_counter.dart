import 'package:flutter/material.dart';

import 'msg_limit.dart';
import 'theme.dart';
import 'widgets.dart';

/// 聊天输入栏上方的「长度 / 整包字节」计数器（APRS 报文可解析性预检）。
///
/// ── 为什么单独一个 widget，而且必须**自己监听输入控制器** ──
/// 这个数字要跟着打字实时变。两种写法各有一个坑：
///
///   * 在 `TextField.onChanged` 里 `setState`：每敲一个键都会重建**整个消息页**
///     （会话列表 + 全部气泡），大页面上会掉帧；
///   * 只在页面 build 时读一次 `controller.text`：那就只在**别的原因触发重建**时
///     才更新 —— 用户看到的现象正是「数字不跟着打字变，要等输入框失去焦点才变」
///     （用户实测上报）。
///
/// 所以这里用 `ListenableBuilder(listenable: controller)`：控制器一变只重建这一行，
/// 既实时又不牵连整页。单独抽出来还有一个好处 —— 能被 widget 测试直接盯住，
/// 不必把整个 MessagesPage 挂起来（那需要一整套平台通道）。
class MsgLenCounter extends StatelessWidget {
  /// 输入框的控制器（本 widget 监听它，所以打字时实时刷新）。
  final TextEditingController controller;

  /// 我的呼号（整包字节数要算上报头）。
  final String from;

  /// 发送路径（同上）。
  final String path;

  /// 收件人；群聊时是群的呼号。
  final String to;

  /// 「译发」预览：已经译好的待发文本，以及它对应的**原文**。
  ///
  /// 只有当 [previewSrc] 与当前输入一致时 [preview] 才算数 —— 否则会出现
  /// 「改了字，计数器还按旧译文算」，与「改了字却发出去旧译文」是同一类错。
  final String? preview;
  final String? previewSrc;

  const MsgLenCounter({
    super.key,
    required this.controller,
    required this.from,
    required this.path,
    required this.to,
    this.preview,
    this.previewSrc,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final typed = controller.text.trim();
        final wired =
            (preview != null && previewSrc == typed) ? preview! : typed;
        final fit = MsgLimit.check(
          from: from,
          path: path,
          to: to,
          text: wired,
        );
        // 三档配色：规范内（灰）/ 超 67 字符（橙，可能解析不出来）/
        // 整包超 512 字节（红，服务器可能整包丢弃）。
        final tone = fit.fit == MsgFit.ok
            ? C.grey
            : fit.fit == MsgFit.overSpec
                ? C.orange
                : C.red;
        final icon = fit.fit == MsgFit.ok
            ? Icons.check_circle_outline_rounded
            : fit.fit == MsgFit.overSpec
                ? Icons.warning_amber_rounded
                : Icons.error_rounded;
        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
          child: Row(children: [
            Icon(icon, size: 12, color: tone),
            const SizedBox(width: 5),
            Text(
              S.of(context).msgLenCounter(fit.textChars, fit.packetBytes),
              style: ts(9, c: tone),
            ),
          ]),
        );
      },
    );
  }
}
