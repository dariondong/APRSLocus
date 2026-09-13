import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models.dart';
import 'state.dart';
import 'theme.dart';
import 'translate.dart';
import 'l10n/app_localizations.dart';
import 'widgets.dart';

/// ─── 会话翻译的 UI 部分 ───
///
/// 与消息页解耦成独立文件的原因：翻译是一整套「状态 + 弹层 + 气泡装饰」，
/// 塞进已经 3600 行的 messages_page.dart 会让它更难维护。
///
/// 设计要点：
///   - **双向翻译**：收到对方消息 → 翻成「我的语言」；自己发的消息 →
///     翻成「对方的语言」。后者是「我这样发出去，对方会读到什么」的预演。
///   - **对方的语言会自动学出来**：接口在 `from=auto` 时回传识别结果
///     （Google 的 `detectedSourceLanguage` / 百度的 `from`），
///     用它回填 [ConvTranslatePref.peerLang]，无需用户手填。
///   - **对照显示**：原文与译文同屏，各自带语言标签，便于核对；
///     可关掉改成「译文替换原文」。
///   - **译文不落盘**（`AprsMsg` 不动）：翻译是查看时的一次加工，不是消息本身。
///     落盘会导致换语言后旧译文残留。代价是重启后需重新翻 ——
///     但结果缓存（[TranslateService]）是落盘的，同一句话不会再调接口。

/// 消息指纹：呼号 + 方向 + 时间 + 文本，足够稳定地区分同一条消息
String msgKey(AprsMsg m) =>
    '${m.from}|${m.to}|${m.time.millisecondsSinceEpoch}|${m.text}';

/// 会话键：群聊用 groupId、私聊用对方呼号（用于 per-会话 偏好与统计）
String convKeyOf({String? groupId, String? call}) =>
    groupId != null ? 'g:$groupId' : 'c:${(call ?? '').toUpperCase()}';

/// 翻译方向
enum TransSide {
  /// 对方发来的消息 → 翻成我的语言
  incoming,

  /// 我发出的消息 → 翻成对方的语言
  outgoing,
}

/// 翻译状态（每个会话一份）
class ConvTransState extends ChangeNotifier {
  /// 消息指纹 → 译文
  final Map<String, String> translations = {};

  /// 消息指纹 → 该译文对应的目标语言（对照显示时标注用）
  final Map<String, String> targets = {};

  /// 消息指纹 → 正在翻译中
  final Set<String> pending = {};

  /// 消息指纹 → 失败原因（可读文本）
  final Map<String, String> errors = {};

  /// 正在显示原文（用户点了「显示原文」，即暂时隐藏译文）
  final Set<String> showingOriginal = {};

  bool has(String key) => translations.containsKey(key);

  int get count => translations.length;

  void setTranslated(String key, String text, String target) {
    translations[key] = text;
    targets[key] = target;
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

  /// 指定语言下是否已有译文（用户「翻译成另一种语言」时用来判断要不要重翻）
  bool hasFor(String key, String lang) =>
      translations.containsKey(key) && targets[key] == lang;

  void clear() {
    translations.clear();
    targets.clear();
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

/// 翻译一条消息，结果写入 [st]。
///
/// 统一入口，保证「长按翻译」「自动翻译」「重新翻译」走同一条路径。
/// [side] 决定方向 —— 这是双向翻译的分叉点：
///   incoming → 目标 = 我的语言；outgoing → 目标 = 对方的语言。
/// 翻译对方消息时若接口回传了识别语言，会**顺手回填** pref.peerLang，
/// 于是「对方的语言」用过几次就自动知道了。
Future<void> translateMessage({
  required BuildContext context,
  required AprsMsg m,
  required TransSide side,
  required ConvTranslatePref pref,
  required ConvTransState st,
  required String convKey,
  bool persistLearned = true,
  void Function()? onPeerLangLearned,
}) async {
  final key = msgKey(m);
  final svc = TranslateService.instance;
  final s = S.of(context);
  final fallback = svc.config.targetLang;
  final target = side == TransSide.incoming
      ? TransDirection.targetForIncoming(pref, fallback)
      : TransDirection.targetForOutgoing(pref, fallback);

  if (side == TransSide.outgoing && pref.peerLang.isEmpty) {
    // 还不知道对方说什么：不硬翻（翻了可能是同一种语言），
    // 提示用户去会话翻译设置里指定 —— 但用起来后接口会自动学会。
    st.setError(key, s.translatePeerUnknown);
    return;
  }
  if (st.pending.contains(key)) return;

  // 命中缓存直接出结果，不显示「翻译中」（否则会闪一下）
  final cached = svc.cached(m.text, 'auto', target);
  if (cached != null) {
    st.setTranslated(key, cached, target);
    return;
  }
  st.setPending(key);
  try {
    final r = await svc.translate(m.text, to: target);
    st.setTranslated(key, r.text, target);
    // 学习对方的语言：仅在翻译「对方消息」时回填，且只在确实识别出
    // 且与已知值不同时才写盘（避免每翻一条就写一次 SharedPreferences）
    final det = r.detected;
    if (persistLearned &&
        side == TransSide.incoming &&
        det != null &&
        det.isNotEmpty &&
        det != pref.peerLang &&
        pref.targetLang != det) {
      pref.peerLang = det;
      await svc.savePref(convKey);
      onPeerLangLearned?.call();
    }
  } on TranslateException catch (e) {
    st.setError(key, explainTranslateError(s, e));
  } catch (e) {
    st.setError(key, s.translateFailed('$e'));
  }
}

/// 把接口错误翻译成用户能理解的说法（原始错误码对用户没有意义）
String explainTranslateError(S s, TranslateException e) {
  final msg = e.message;
  if (msg.startsWith('not-configured')) return s.translateNeedConfig;
  // 免费接口被限流/被墙时，最有用的信息是「可以换接口」，而不是原始报文
  if (msg.startsWith('free-unavailable')) return s.translateFreeFailed(msg);
  return s.translateFailed(msg);
}

/// 长按消息弹出的操作面板
Future<void> showMessageActions({
  required BuildContext context,
  required AprsMsg m,
  required ConvTranslatePref pref,
  required ConvTransState st,
  required String convKey,
  void Function()? onChanged,
  VoidCallback? onOpenSettings,
}) async {
  final key = msgKey(m);
  final s = S.of(context);
  final svc = TranslateService.instance;
  final fallback = svc.config.targetLang;
  // 方向由「这条消息是谁发的」决定，而不是由用户选 —— 用户选
  // 「翻译成对方语言」时其实是想看自己发出去的那句在对面是什么样。
  final side = m.sent ? TransSide.outgoing : TransSide.incoming;
  final targetLabel = TransLang.labelOf(
    side == TransSide.incoming
        ? TransDirection.targetForIncoming(pref, fallback)
        : TransDirection.targetForOutgoing(pref, fallback),
  );
  final translated = st.has(key);
  final showingOriginal = st.showingOriginal.contains(key);
  final peerLabel = pref.peerLang.isEmpty
      ? s.translateLangAuto
      : TransLang.labelOf(pref.peerLang);
  // 接口未配置时，翻译必然失败。与其让用户点一下只得到一句报错，
  // 不如在面板上就给出「去配置」的入口。
  final configured = svc.config.ready;

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
            Row(children: [
              Icon(Icons.translate_rounded, size: 16, color: C.cyan),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${side == TransSide.incoming ? s.translateMyLang : s.translatePeerLang}'
                  ' → $targetLabel',
                  style: ts(13, w: FontWeight.w700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: C.cyanBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  side == TransSide.incoming
                      ? s.translateSideIncoming
                      : s.translateSideOutgoing,
                  style: ts(9, c: C.cyan, w: FontWeight.w700),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            if (!configured) ...[
              // 未配置：翻译按钮变成「去配置」，并说明原因
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: C.orangeBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(children: [
                  Icon(Icons.info_outline_rounded, size: 15, color: C.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(s.translateNeedConfig,
                        style: ts(11, c: C.orange, h: 1.4)),
                  ),
                ]),
              ),
              const SizedBox(height: 8),
            ],
            _action(
              icon: configured
                  ? Icons.translate_rounded
                  : Icons.settings_rounded,
              color: configured ? C.cyan : C.orange,
              title: translated && configured
                  ? s.translateRetry
                  : (configured ? s.translateText : s.translateSettings),
              subtitle: configured ? targetLabel : null,
              onTap: () {
                Navigator.pop(ctx);
                if (!configured) {
                  // 直接带用户去配置，而不是发一次注定失败的请求
                  onOpenSettings?.call();
                  return;
                }
                unawaited(translateMessage(
                  context: context,
                  m: m,
                  side: side,
                  pref: pref,
                  st: st,
                  convKey: convKey,
                  onPeerLangLearned: onChanged,
                ));
              },
            ),
            // 对照显示开关：一次点击即可在「原文+译文」与「只看译文」之间切换
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
                  onChanged?.call();
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
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                '${s.translatePeerLang}: $peerLabel'
                '${pref.peerLang.isEmpty ? '（${s.translatePeerUnknownHint}）' : ''}',
                style: ts(10, c: C.grey),
              ),
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

/// 会话右上角的翻译设置面板
///
/// 两块语言设置是核心：
///   - 「我的语言」= 收到对方消息翻成什么
///   - 「对方的语言」= 我发的消息翻成什么；留「自动」则由接口识别结果回填
Future<void> showConvTranslateSheet({
  required BuildContext context,
  required String convKey,
  required String title,
  required IconData icon,
  required Color color,
  required String myUiLocale,
  required VoidCallback onChanged,
  VoidCallback? onOpenSettings,
  /// 是否允许「发送前翻译」：群聊有多位成员、对方语言不唯一，故不提供
  bool allowOutgoing = false,
}) async {
  final svc = TranslateService.instance;
  final pref = svc.prefFor(convKey);
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) {
        final s = S.of(ctx);
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.78,
          ),
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
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, size: 17, color: color),
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

                  // 我的语言
                  _langHeader(s.translateMyLang, s.translateMyLangHint),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final l in _langOptions)
                        _langChip(
                          label: l.label,
                          selected: pref.targetLang == l.code,
                          onTap: () async {
                            pref.targetLang = l.code;
                            await svc.savePref(convKey);
                            setSheet(() {});
                            onChanged();
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 对方的语言
                  _langHeader(
                    s.translatePeerLang,
                    pref.peerLang.isEmpty
                        ? s.translatePeerUnknownHint
                        : s.translateLearned,
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _langChip(
                        label: s.translateLangAuto,
                        selected: pref.peerLang.isEmpty,
                        onTap: () async {
                          pref.peerLang = '';
                          await svc.savePref(convKey);
                          setSheet(() {});
                          onChanged();
                        },
                      ),
                      for (final l in _langOptions)
                        _langChip(
                          label: l.label,
                          selected: pref.peerLang == l.code,
                          onTap: () async {
                            pref.peerLang = l.code;
                            await svc.savePref(convKey);
                            setSheet(() {});
                            onChanged();
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // 开关
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: C.bgSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: pref.auto,
                        activeThumbColor: C.green,
                        title: Text(s.translateAuto,
                            style: ts(13, w: FontWeight.w700)),
                        subtitle:
                            Text(s.translateAutoTip, style: ts(10, c: C.grey)),
                        onChanged: (v) async {
                          pref.auto = v;
                          await svc.savePref(convKey);
                          setSheet(() {});
                          onChanged();
                        },
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: pref.contrast,
                        activeThumbColor: C.cyan,
                        title: Text(s.translateContrast,
                            style: ts(13, w: FontWeight.w700)),
                        subtitle: Text(s.translateContrastTip,
                            style: ts(10, c: C.grey)),
                        onChanged: (v) async {
                          pref.contrast = v;
                          await svc.savePref(convKey);
                          setSheet(() {});
                          onChanged();
                        },
                      ),
                      if (allowOutgoing)
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: pref.translateOutgoing,
                          activeThumbColor: C.green,
                          title: Text(s.translateOutgoing,
                              style: ts(13, w: FontWeight.w700)),
                          subtitle: Text(s.translateOutgoingTip,
                              style: ts(10, c: C.grey)),
                          onChanged: (v) async {
                            pref.translateOutgoing = v;
                            await svc.savePref(convKey);
                            setSheet(() {});
                            onChanged();
                          },
                        ),
                    ]),
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
                    if (ConvTransRegistry.instance.of(convKey).count > 0) ...[
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

List<TransLang> get _langOptions =>
    TransLang.all.where((l) => l.code != 'auto').toList();

Widget _langHeader(String title, String hint) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Text(title, style: ts(12, c: C.cyan, w: FontWeight.w700)),
        const SizedBox(width: 6),
        Flexible(
          child: Text(hint,
              style: ts(10, c: C.grey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ),
      ]),
    );

Widget _langChip({
  required String label,
  required bool selected,
  required VoidCallback onTap,
}) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? C.cyanBg : C.bgSoft,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? C.cyan : C.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: ts(11,
              c: selected ? C.cyan : C.slate,
              w: selected ? FontWeight.w700 : FontWeight.w500),
        ),
      ),
    );

/// 译文展示块（对照翻译）
///
/// 对照模式：原文（气泡内）+ 分隔线 + 译文（带语言标签）—— 二者同屏便于核对。
/// 非对照模式：只显示译文，原文隐藏（气泡里的原文会被替换掉，见调用方）。
Widget translationBlock({
  required BuildContext context,
  required AprsMsg m,
  required ConvTransState st,
  required ConvTranslatePref pref,
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
  if (!pref.contrast || st.showingOriginal.contains(key)) {
    return const SizedBox.shrink();
  }
  final target = st.targets[key] ?? '';
  return Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 分隔线 + 语言标签：让「下半段是译文」一眼可辨，且知道译成了什么语言
        Row(children: [
          Expanded(child: Container(height: 1, color: C.border)),
          const SizedBox(width: 6),
          if (target.isNotEmpty)
            Text(
              '${m.sent ? s.translateToPeerTag : s.translateToMeTag}'
              ' · ${TransLang.labelOf(target)}',
              style: ts(9, c: C.grey),
            ),
        ]),
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

/// 「已译发」标记：这条消息当时按对方语言发出，这里如实显示发出去的文本。
///
/// 与翻译块的区别：翻译块是**本地查看时**的加工（可重复、可换语言），
/// 而这里是**已经发生的事实**（报文真的那样发出去了），所以不复用翻译块，
/// 也不随目标语言变化而消失 —— 否则用户再也无法核对当时到底发了什么。
Widget sentAsBlock({
  required BuildContext context,
  required AprsMsg m,
}) {
  final text = m.sentAs;
  if (text == null || !m.translated) return const SizedBox.shrink();
  final s = S.of(context);
  return Padding(
    padding: const EdgeInsets.only(top: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.outbox_rounded, size: 11, color: C.green),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            s.translateSentAs(text),
            style: ts(10, c: C.green, h: 1.35),
          ),
        ),
      ],
    ),
  );
}

/// 非对照模式：译文替换原文时用于渲染正文
String? displayTranslationOf({
  required AprsMsg m,
  required ConvTransState st,
  required ConvTranslatePref pref,
}) {
  if (pref.contrast) return null;
  final key = msgKey(m);
  if (st.showingOriginal.contains(key)) return null;
  return st.translations[key];
}

/// 会话列表/头部的翻译按钮，带已翻译条数角标
Widget translateChip({
  required BuildContext context,
  required int count,
  required VoidCallback onTap,
  Color? color,
}) {
  final c = color ?? C.cyan;
  return GestureDetector(
    onTap: onTap,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.translate_rounded, size: 15, color: c),
        ),
        if (count > 0)
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: c,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text('$count',
                  style: ts(8, c: Colors.white, w: FontWeight.w700)),
            ),
          ),
      ],
    ),
  );
}
