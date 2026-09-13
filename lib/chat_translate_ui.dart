import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models.dart';
import 'state.dart';
import 'theme.dart';
import 'translate.dart';
import 'widgets.dart';

/// ─── 会话翻译的 UI 部分 ───
///
/// 与消息页解耦成独立文件的原因：翻译是一整套「状态 + 弹层 + 气泡装饰」，
/// 塞进已经 3600 行的 messages_page.dart 会让它更难维护。
///
/// 设计取舍：
///   - **译文不落盘**（`AprsMsg` 不动）：翻译是「查看时的一次加工」，
///     不是消息本身。落盘会导致：换目标语言后旧译文仍显示、清缓存后仍残留。
///     代价是重启应用后需要重新翻译 —— 但结果缓存（TranslateService）
///     是落盘的，同一句话再翻一次不会再调接口，也就不再计费。
///   - 译文存本页 State 的 Map（key 用消息指纹），切会话不丢。

/// 消息指纹：呼号 + 方向 + 时间 + 文本，足够稳定地区分同一条消息
String msgKey(AprsMsg m) =>
    '${m.from}|${m.to}|${m.time.millisecondsSinceEpoch}|${m.text}';

/// 会话键：群聊用 groupId、私聊用对方呼号（用于 per-会话 偏好与统计）
String convKeyOf({String? groupId, String? call}) =>
    groupId != null ? 'g:$groupId' : 'c:${(call ?? '').toUpperCase()}';

/// 翻译状态（每个会话一份）
class ConvTransState extends ChangeNotifier {
  /// 消息指纹 → 译文
  final Map<String, String> translations = {};

  /// 消息指纹 → 正在翻译中
  final Set<String> pending = {};

  /// 消息指纹 → 失败原因（可读文本）
  final Map<String, String> errors = {};

  /// 正在显示原文（用户点了「显示原文」）
  final Set<String> showingOriginal = {};

  bool has(String key) => translations.containsKey(key);

  int get count => translations.length;

  void setTranslated(String key, String text) {
    translations[key] = text;
    pending.remove(key);
    errors.remove(key);
    notifyListeners();
  }

  void setPending(String key) {
    pending.add(key);
    notifyListeners();
  }

  void setError(String key, String message) {
    pending.remove(key);
    errors[key] = message;
    notifyListeners();
  }

  void toggleOriginal(String key) {
    showingOriginal.contains(key)
        ? showingOriginal.remove(key)
        : showingOriginal.add(key);
    notifyListeners();
  }

  void clear() {
    translations.clear();
    pending.clear();
    errors.clear();
    showingOriginal.clear();
    notifyListeners();
  }
}

/// 全局注册表：每个会话一个 [ConvTransState]，切回来时译文还在
class ConvTransRegistry {
  ConvTransRegistry._();
  static final ConvTransRegistry instance = ConvTransRegistry._();
  final Map<String, ConvTransState> _states = {};

  ConvTransState of(String convKey) =>
      _states.putIfAbsent(convKey, () => ConvTransState());

  void clearAll() {
    for (final s in _states.values) {
      s.clear();
    }
  }
}

/// 翻译一条消息；结果写入 [st]。
///
/// 统一入口，保证「长按翻译」「自动翻译」「重新翻译」走同一条路径
/// （否则很容易出现某一入口没有 pending/错误处理）。
Future<void> translateMessage({
  required BuildContext context,
  required AprsMsg m,
  required String to,
  required ConvTransState st,
  required String convKey,
}) async {
  final key = msgKey(m);
  final svc = TranslateService.instance;
  final s = S.of(context);
  if (st.pending.contains(key)) return;
  // 命中缓存则直接出结果，不显示「翻译中」（否则会闪一下）
  final cached = svc.cached(m.text, 'auto', to);
  if (cached != null) {
    st.setTranslated(key, cached);
    return;
  }
  st.setPending(key);
  try {
    final out = await svc.translate(m.text, to: to);
    st.setTranslated(key, out);
  } on TranslateException catch (e) {
    st.setError(key, _explain(s, e));
  } catch (e) {
    st.setError(key, s.translateFailed('$e'));
  }
}

/// 把接口错误翻译成用户能理解的说法。
///
/// 直接抛原始错误（如 `not-configured:googleApiKey`、`HTTP 403`）对用户
/// 没有意义，这里把最常见的几种情况换成「下一步该做什么」。
String _explain(S s, TranslateException e) {
  final msg = e.message;
  if (msg.startsWith('not-configured')) {
    return s.translateNeedConfig;
  }
  if (msg == 'timeout') {
    return s.translateFailed('timeout');
  }
  return s.translateFailed(msg);
}

/// 长按消息弹出的操作面板
Future<void> showMessageActions({
  required BuildContext context,
  required AprsMsg m,
  required String targetLang,
  required ConvTransState st,
  required String convKey,
  VoidCallback? onResend,
}) async {
  final key = msgKey(m);
  final s = S.of(context);
  final translated = st.has(key);
  final showingOriginal = st.showingOriginal.contains(key);

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 目标语言提示：让用户知道「翻译」会翻成什么
            Row(children: [
              Icon(Icons.translate_rounded, size: 16, color: C.cyan),
              const SizedBox(width: 8),
              Text('${s.translate} → ${TransLang.labelOf(targetLang)}',
                  style: ts(13, w: FontWeight.w700)),
            ]),
            const SizedBox(height: 10),
            _action(
              icon: Icons.translate_rounded,
              color: C.cyan,
              title: translated ? s.translateRetry : s.translateText,
              subtitle: TransLang.labelOf(targetLang),
              onTap: () {
                Navigator.pop(ctx);
                unawaited(translateMessage(
                  context: context,
                  m: m,
                  to: targetLang,
                  st: st,
                  convKey: convKey,
                ));
              },
            ),
            if (translated)
              _action(
                icon: showingOriginal
                    ? Icons.visibility_rounded
                    : Icons.visibility_off_rounded,
                color: C.slate,
                title: showingOriginal
                    ? s.translateShowTranslation
                    : s.translateShowOriginal,
                onTap: () {
                  Navigator.pop(ctx);
                  st.toggleOriginal(key);
                },
              ),
            _action(
              icon: Icons.copy_rounded,
              color: C.blue,
              title: s.translateCopyOriginal,
              onTap: () {
                Navigator.pop(ctx);
                _copy(context, m.text, s.copiedClipboard);
              },
            ),
            if (translated)
              _action(
                icon: Icons.copy_all_rounded,
                color: C.green,
                title: s.translateCopyResult,
                onTap: () {
                  Navigator.pop(ctx);
                  _copy(context, st.translations[key] ?? '', s.copiedClipboard);
                },
              ),
          ],
        ),
      ),
    ),
  );
}

void _copy(BuildContext context, String text, String toast) {
  Clipboard.setData(ClipboardData(text: text));
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(toast),
      backgroundColor: C.blue,
      duration: const Duration(seconds: 1),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
}

Widget _action({
  required IconData icon,
  required Color color,
  required String title,
  String? subtitle,
  required VoidCallback onTap,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
      child: Row(children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
        const SizedBox(width: 11),
        Expanded(child: Text(title, style: ts(13, w: FontWeight.w600))),
        if (subtitle != null) ...[
          Text(subtitle, style: ts(10, c: C.grey)),
          const SizedBox(width: 4),
        ],
        Icon(Icons.chevron_right_rounded, size: 16, color: C.greyLight),
      ]),
    ),
  );
}

/// 会话右上角的翻译设置面板（语言 + 自动翻译）
Future<void> showConvTranslateSheet({
  required BuildContext context,
  required AppState appState,
  required String convKey,
  required String title,
  required VoidCallback onChanged,
  VoidCallback? onOpenSettings,
}) async {
  final svc = TranslateService.instance;
  final pref = svc.prefFor(convKey);
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) {
        final s = S.of(ctx);
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: C.cyanBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.translate_rounded,
                          size: 17, color: C.cyan),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.translateSettings,
                              style: ts(14, w: FontWeight.w800)),
                          Text(title,
                              style: ts(11, c: C.grey),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  Text(s.translateTargetLang,
                      style: ts(12, c: C.cyan, w: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final l in TransLang.all.where((l) => l.code != 'auto'))
                        GestureDetector(
                          onTap: () async {
                            pref.targetLang = l.code;
                            await svc.savePref(convKey);
                            setSheet(() {});
                            onChanged();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: pref.targetLang == l.code
                                  ? C.cyanBg
                                  : C.bgSoft,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: pref.targetLang == l.code
                                    ? C.cyan
                                    : C.border,
                                width: pref.targetLang == l.code ? 1.5 : 1,
                              ),
                            ),
                            child: Text(
                              l.label,
                              style: ts(11,
                                  c: pref.targetLang == l.code
                                      ? C.cyan
                                      : C.slate,
                                  w: pref.targetLang == l.code
                                      ? FontWeight.w700
                                      : FontWeight.w500),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: C.bgSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: pref.auto,
                      activeThumbColor: C.green,
                      title: Text(s.translateAuto, style: ts(13, w: FontWeight.w700)),
                      subtitle: Text(s.translateAutoTip, style: ts(10, c: C.grey)),
                      onChanged: (v) async {
                        pref.auto = v;
                        await svc.savePref(convKey);
                        setSheet(() {});
                        onChanged();
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          onOpenSettings?.call();
                        },
                        icon: const Icon(Icons.settings_rounded, size: 15),
                        label: Text(s.translateSettings, style: ts(12)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: C.cyan,
                          side: BorderSide(color: C.cyan.withValues(alpha: 0.5)),
                        ),
                      ),
                    ),
                    if (st_translatedCount(convKey) > 0) ...[
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () {
                          ConvTransRegistry.instance.of(convKey).clear();
                          setSheet(() {});
                          onChanged();
                        },
                        child: Text(s.clearAll, style: ts(12, c: C.grey)),
                      ),
                    ],
                  ]),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

int st_translatedCount(String convKey) =>
    ConvTransRegistry.instance.of(convKey).count;

/// 译文展示块：附在气泡里（原文下方一条细分隔线 + 译文）
Widget translationBlock({
  required BuildContext context,
  required AprsMsg m,
  required ConvTransState st,
}) {
  final key = msgKey(m);
  final s = S.of(context);
  if (st.pending.contains(key)) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(children: [
        const SizedBox(
          width: 11,
          height: 11,
          child: CircularProgressIndicator(strokeWidth: 1.6),
        ),
        const SizedBox(width: 6),
        Text(s.translateTranslating, style: ts(10, c: C.grey)),
      ]),
    );
  }
  final err = st.errors[key];
  if (err != null) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(children: [
        Icon(Icons.error_outline_rounded, size: 12, color: C.red),
        const SizedBox(width: 5),
        Expanded(
          child: Text(err,
              style: ts(10, c: C.red, h: 1.35),
              maxLines: 3,
              overflow: TextOverflow.ellipsis),
        ),
      ]),
    );
  }
  final t = st.translations[key];
  if (t == null) return const SizedBox.shrink();
  if (st.showingOriginal.contains(key)) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(height: 1, color: C.border),
        const SizedBox(height: 5),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.translate_rounded, size: 11, color: C.cyan),
            const SizedBox(width: 4),
            Expanded(child: Text(t, style: ts(12, c: C.cyan, h: 1.4))),
          ],
        ),
      ],
    ),
  );
}
