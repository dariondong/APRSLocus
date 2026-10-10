/// ─── 智能体界面（浮动聊天框 + 设置页）───
///
/// 聊天框挂在 `MaterialApp.builder` 的 child 之上（见 app.dart），因此**任何
/// 页面**上都能看到它；设置页则从「实验功能」里推入。
library;

import 'dart:async';

import 'package:flutter/material.dart';

import 'agent.dart';
import 'agent_tools.dart';
import 'material.dart';
import 'settings_widgets.dart';
import 'state.dart';
import 'theme.dart';
import 'widgets.dart';

/// ─────────────── 智能体设置页 ───────────────

/// 常用接口预设：填一个「最省事」的默认，用户仍可逐项改。
class _Preset {
  final String label;
  final String baseUrl;
  final String model;
  const _Preset(this.label, this.baseUrl, this.model);
}

const List<_Preset> _presets = [
  _Preset('OpenAI', 'https://api.openai.com/v1', 'gpt-4o-mini'),
  _Preset('DeepSeek', 'https://api.deepseek.com/v1', 'deepseek-chat'),
  _Preset('Moonshot', 'https://api.moonshot.cn/v1', 'moonshot-v1-8k'),
  _Preset('智谱 GLM', 'https://open.bigmodel.cn/api/paas/v4', 'glm-4-flash'),
  _Preset('通义千问', 'https://dashscope.aliyuncs.com/compatible-mode/v1',
      'qwen-plus'),
  _Preset('Ollama', 'http://localhost:11434/v1', 'llama3.1'),
  _Preset('LM Studio', 'http://localhost:1234/v1', 'local-model'),
];

class AgentSettingsPage extends StatefulWidget {
  final AppState state;
  const AgentSettingsPage({super.key, required this.state});

  @override
  State<AgentSettingsPage> createState() => _AgentSettingsPageState();
}

class _AgentSettingsPageState extends State<AgentSettingsPage> {
  late final TextEditingController _baseUrl;
  late final TextEditingController _apiKey;
  late final TextEditingController _model;
  late final TextEditingController _systemPrompt;

  bool _testing = false;
  String _testResult = '';
  bool _testOk = false;

  AgentConfig get cfg => AgentService.instance.config;

  @override
  void initState() {
    super.initState();
    _baseUrl = TextEditingController(text: cfg.baseUrl);
    _apiKey = TextEditingController(text: cfg.apiKey);
    _model = TextEditingController(text: cfg.model);
    _systemPrompt = TextEditingController(text: cfg.systemPrompt);
  }

  @override
  void dispose() {
    for (final c in [_baseUrl, _apiKey, _model, _systemPrompt]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _collect() async {
    cfg
      ..baseUrl = _baseUrl.text.trim()
      ..apiKey = _apiKey.text.trim()
      ..model = _model.text.trim()
      ..systemPrompt = _systemPrompt.text.trim();
    await AgentService.instance.saveConfig();
  }

  void _toast(String msg, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: color ?? C.ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _test() async {
    await _collect();
    // await 之后必须重新确认 mounted，再碰 context（lint: 跨 await 用 context）。
    if (!mounted) return;
    final s = S.of(context);
    if (!cfg.ready) {
      _toast(s.agentNeedConfig, color: C.orange);
      return;
    }
    setState(() {
      _testing = true;
      _testResult = '';
    });
    try {
      final r = await AgentService.instance.testConnection();
      if (mounted) {
        setState(() {
          _testOk = true;
          _testResult = s.agentTestOk(r);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _testOk = false;
          _testResult = s.agentError('$e');
        });
      }
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return ListenableBuilder(
      listenable: AgentService.instance,
      builder: (context, _) => SettingsPageShell(
        title: s.agentSettings,
        subtitle: s.agentSettingsDesc,
        icon: Icons.smart_toy_rounded,
        color: C.purple,
        body: Column(children: [
          SettingsFold(
            title: s.agentMode,
            subtitle: s.agentModeDesc,
            icon: Icons.smart_toy_rounded,
            color: C.purple,
            open: true,
            onToggle: () {},
            children: [
              SettingsSwitch(s.agentEnabled, value: cfg.enabled, color: C.purple,
                  onChanged: (v) async {
                cfg.enabled = v;
                await AgentService.instance.saveConfig();
                if (mounted) setState(() {});
              }),
              SettingsHint(s.agentApiKeyTip),
            ],
          ),
          const SizedBox(height: 16),
          SettingsFold(
            title: s.agentInterfaceSection,
            subtitle: '',
            icon: Icons.key_rounded,
            color: C.blue,
            open: true,
            onToggle: () {},
            children: [
              // 预设：一键把 Base URL / 模型填成常见值
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                child: Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final p in _presets)
                    GestureDetector(
                      onTap: () {
                        _baseUrl.text = p.baseUrl;
                        _model.text = p.model;
                        _collect();
                        setState(() {});
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: C.bgSoft,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: C.border),
                        ),
                        child: Text(p.label,
                            style: ts(11, c: C.slate, w: FontWeight.w600)),
                      ),
                    ),
                ]),
              ),
              SettingsInput(s.agentBaseUrl, _baseUrl,
                  hint: 'https://api.openai.com/v1'),
              SettingsInput(s.agentApiKey, _apiKey,
                  hint: 'sk-...'),
              SettingsInput(s.agentModel, _model, hint: 'gpt-4o-mini'),
              SettingsInput(s.agentSystemPrompt, _systemPrompt),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _testing ? null : _test,
                      icon: Icon(Icons.wifi_tethering_rounded, size: 16),
                      label: Text(_testing ? s.agentTesting : s.agentTest),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: C.blue,
                        side: BorderSide(color: C.blue.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        textStyle: ts(12, w: FontWeight.w600),
                      ),
                    ),
                  ),
                ]),
              ),
              if (_testResult.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _testOk ? C.greenBg : C.redBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_testResult,
                        style: ts(11,
                            c: _testOk ? C.green : C.red,
                            w: FontWeight.w600)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          SettingsFold(
            title: s.agentPermissions,
            subtitle: '',
            icon: Icons.published_with_changes_rounded,
            color: C.orange,
            open: true,
            onToggle: () {},
            children: [
              SettingsSwitch(s.agentAllowSend, value: cfg.allowSend,
                  color: C.orange, onChanged: (v) async {
                cfg.allowSend = v;
                await AgentService.instance.saveConfig();
                if (mounted) setState(() {});
              }),
              SettingsHint(s.agentAllowSendDesc),
              SettingsSwitch(s.agentAllowSettings, value: cfg.allowSettings,
                  color: C.orange, onChanged: (v) async {
                cfg.allowSettings = v;
                await AgentService.instance.saveConfig();
                if (mounted) setState(() {});
              }),
              SettingsHint(s.agentAllowSettingsDesc),
            ],
          ),
        ]),
      ),
    );
  }
}

/// ─────────────── 浮动聊天框 ───────────────

/// 覆盖在所有页面之上的智能体聊天框容器。
///
/// 由 `MaterialApp.builder` 负责挂载/卸载：只有「实验功能」开启了智能体模式时
/// 才实例化，因此关闭时零开销。
class AgentOverlay extends StatefulWidget {
  final AppState state;
  const AgentOverlay({super.key, required this.state});

  @override
  State<AgentOverlay> createState() => _AgentOverlayState();
}

class _AgentOverlayState extends State<AgentOverlay> {
  bool _minimized = false;
  Offset _drag = Offset.zero;

  /// 待确认的工具调用（有副作用的操作执行前，面板内联询问用户）
  AgentToolCall? _pendingCall;
  Completer<bool>? _pendingCompleter;

  /// 待确认的「清空对话」
  bool _clearPending = false;

  AgentService get svc => AgentService.instance;
  AgentConfig get cfg => svc.config;

  @override
  void initState() {
    super.initState();
    if (!svc.loaded) svc.load();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: svc,
      builder: (context, _) {
        // 未开启智能体模式：这一层不显示、也不吃手势（SizedBox 无子节点不吸收点击）。
        if (!cfg.enabled) return const SizedBox.shrink();
        if (_minimized) {
          return Stack(children: [
            Positioned(right: 16, bottom: 96, child: _bubble()),
          ]);
        }
        return Stack(children: [
          Positioned(
            right: 12,
            bottom: 88,
            child: Transform.translate(offset: _drag, child: _panel(context)),
          ),
        ]);
      },
    );
  }

  Widget _bubble() {
    return GestureDetector(
      onTap: () => setState(() => _minimized = false),
      child: MaterialSurface(
        radius: 999,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: C.purple,
            shape: BoxShape.circle,
            boxShadow: elev2(),
          ),
          child: Stack(children: [
            const Center(
              child: Icon(Icons.smart_toy_rounded,
                  color: Colors.white, size: 24),
            ),
            if (svc.busy)
              Positioned(
                right: 6,
                top: 6,
                child: SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _panel(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final w = size.width < 480 ? size.width - 24 : 380.0;
    final h = (size.height * 0.62).clamp(320.0, 560.0);
    final s = S.of(context);
    return GestureDetector(
      onPanUpdate: (d) => setState(() => _drag += d.delta),
      onPanEnd: (_) => setState(() {}),
      child: MaterialSurface(
        radius: 20,
        child: Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: C.sheetFill,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: C.border),
            boxShadow: elev2(),
          ),
          child: Column(children: [
            _header(s),
            Divider(height: 1, color: C.border),
            if (!cfg.ready) _notReady(s),
            Expanded(child: _messageList(s)),
            if (svc.busy && _pendingCall == null) _thinking(s),
            if (_clearPending) _clearBar(s),
            if (_pendingCall != null) _confirmBar(s, _pendingCall!),
            Divider(height: 1, color: C.border),
            _input(s),
          ]),
        ),
      ),
    );
  }

  Widget _header(S s) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      child: Row(children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: C.purpleBg,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(Icons.smart_toy_rounded, size: 16, color: C.purple),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(s.agentChatTitle,
              style: ts(13, w: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ),
        IconButton(
          tooltip: s.agentClear,
          onPressed: () => setState(() => _clearPending = true),
          icon: Icon(Icons.delete_outline_rounded, size: 18, color: C.grey),
          visualDensity: VisualDensity.compact,
        ),
        IconButton(
          tooltip: s.agentOpenSettings,
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
                builder: (_) => AgentSettingsPage(state: widget.state)),
          ),
          icon: Icon(Icons.settings_rounded, size: 18, color: C.grey),
          visualDensity: VisualDensity.compact,
        ),
        IconButton(
          tooltip: s.agentMinimize,
          onPressed: () {
            // 收起前把待确认的操作按「拒绝」结掉，否则对话会一直卡在等待里。
            if (_pendingCompleter != null) _resolveConfirm(false);
            setState(() => _minimized = true);
          },
          icon: Icon(Icons.close_fullscreen_rounded, size: 18, color: C.grey),
          visualDensity: VisualDensity.compact,
        ),
      ]),
    );
  }

  Widget _notReady(S s) {
    return Container(
      width: double.infinity,
      color: C.orangeBg,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(children: [
        Icon(Icons.info_outline_rounded, size: 14, color: C.orange),
        const SizedBox(width: 6),
        Expanded(
          child: Text(s.agentWelcome,
              style: ts(10, c: C.orange, h: 1.3),
              maxLines: 3,
              overflow: TextOverflow.ellipsis),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
                builder: (_) => AgentSettingsPage(state: widget.state)),
          ),
          child: Text(s.agentOpenSettings,
              style: ts(11, c: C.orange, w: FontWeight.w700)),
        ),
      ]),
    );
  }

  Widget _messageList(S s) {
    final msgs = svc.messages
        .where((m) => m.role == 'user' || m.role == 'assistant' || m.role == 'tool')
        .toList();
    final items = <Widget>[
      _welcomeBubble(s),
      for (final m in msgs) _bubbleFor(m, s),
    ];
    if (items.isEmpty) return const SizedBox.shrink();
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      children: items,
    );
  }

  Widget _welcomeBubble(S s) => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          constraints: const BoxConstraints(maxWidth: 280),
          decoration: BoxDecoration(
            color: C.bgSoft,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(s.agentWelcome, style: ts(11, c: C.slate, h: 1.4)),
        ),
      );

  Widget _bubbleFor(AgentMessage m, S s) {
    if (m.role == 'tool') {
      final name = m.name ?? '';
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Icon(Icons.check_circle_outline_rounded, size: 13, color: C.green),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '${s.agentExecuted} · $name',
              style: ts(10, c: C.grey),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ]),
      );
    }
    // assistant 消息可能只带 tool_calls、没有正文
    if (m.role == 'assistant' && m.content.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    final isUser = m.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: isUser ? C.blue : C.bgSoft,
          borderRadius: BorderRadius.circular(14),
        ),
        child: SelectableText(
          m.content,
          style: ts(12, c: isUser ? Colors.white : C.ink, h: 1.4),
        ),
      ),
    );
  }

  Widget _thinking(S s) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
        child: Row(children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 2, color: C.purple),
          ),
          const SizedBox(width: 8),
          Text(s.agentThinking, style: ts(10, c: C.grey)),
        ]),
      );

  Widget _input(S s) {
    return Padding(
      padding: EdgeInsets.fromLTRB(10, 8, 10, 8 + MediaQuery.of(context).viewPadding.bottom),
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: _controller,
            enabled: !svc.busy,
            minLines: 1,
            maxLines: 4,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _send(),
            style: ts(12),
            decoration: InputDecoration(
              isDense: true,
              hintText: s.agentInputHint,
              hintStyle: ts(11, c: C.greyLight),
              filled: true,
              fillColor: C.bgSoft,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: C.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: C.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: C.purple, width: 1.4),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 44,
          height: 44,
          child: svc.busy
              ? OutlinedButton(
                  onPressed: () {
                    // 若正卡在「等待确认」，先按拒绝结掉，再取消本轮对话。
                    if (_pendingCompleter != null) _resolveConfirm(false);
                    svc.cancel();
                  },
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    side: BorderSide(color: C.red),
                  ),
                  child: Icon(Icons.stop_rounded, size: 20, color: C.red),
                )
              : FilledButton(
                  onPressed: _send,
                  style: FilledButton.styleFrom(
                    padding: EdgeInsets.zero,
                    backgroundColor: C.purple,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Icon(Icons.send_rounded, size: 18, color: Colors.white),
                ),
        ),
      ]),
    );
  }

  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 清空对话的确认条（内联，避免对话框被置顶面板遮挡）
  Widget _clearBar(S s) {
    return Container(
      width: double.infinity,
      color: C.redBg,
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      child: Row(children: [
        Expanded(
          child: Text(s.agentClearConfirm,
              style: ts(11, c: C.red, w: FontWeight.w600)),
        ),
        TextButton(
          onPressed: () => setState(() => _clearPending = false),
          child: Text(s.cancel, style: ts(12, c: C.grey)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: C.red,
            visualDensity: VisualDensity.compact,
          ),
          onPressed: () {
            svc.clearHistory();
            setState(() => _clearPending = false);
          },
          child: Text(s.agentClear,
              style: ts(12, c: Colors.white, w: FontWeight.w700)),
        ),
      ]),
    );
  }

  /// 工具确认条：模型请求执行有副作用的操作时，内联问用户「允许 / 拒绝」。
  ///
  /// 用内联条而不是 `showDialog`：本面板挂在 `MaterialApp.builder` 之上，
  /// 而对话框挂在 Navigator 的 Overlay 里 —— 面板永远盖在对话框上面，
  /// 用户会看不到确认框。内联则万无一失，也少一次跨层。
  Widget _confirmBar(S s, AgentToolCall call) {
    final detail = const _ArgsFormat().convert(call.arguments);
    return Container(
      width: double.infinity,
      color: C.purpleBg,
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(s.agentConfirmTitle,
            style: ts(11, c: C.purple, w: FontWeight.w700)),
        const SizedBox(height: 4),
        Row(children: [
          Expanded(
            child: Text(
              detail.isEmpty ? call.name : '${call.name}  $detail',
              style: mono(10, c: C.slate),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: () => _resolveConfirm(false),
            child: Text(s.agentConfirmDeny, style: ts(12, c: C.grey)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: C.purple,
              visualDensity: VisualDensity.compact,
            ),
            onPressed: () => _resolveConfirm(true),
            child: Text(s.agentConfirmRun,
                style: ts(12, c: Colors.white, w: FontWeight.w700)),
          ),
        ]),
      ]),
    );
  }

  /// 回填确认结果（由 [AgentService.send] 的 confirm 回调 await）
  void _resolveConfirm(bool ok) {
    final c = _pendingCompleter;
    setState(() {
      _pendingCall = null;
      _pendingCompleter = null;
    });
    if (c != null && !c.isCompleted) c.complete(ok);
  }

  /// 有副作用的工具执行前，内联弹确认条并等待用户选择
  Future<bool> _confirm(String name, Map<String, dynamic> args) async {
    if (!mounted) return false;
    final completer = Completer<bool>();
    setState(() {
      _pendingCall = AgentToolCall(id: '', name: name, arguments: args);
      _pendingCompleter = completer;
    });
    return completer.future;
  }

  Future<void> _send() async {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    final s = S.of(context);
    _controller.clear();
    setState(() {});
    try {
      await svc.send(
        text,
        tools: agentToolSchemas(allowSend: cfg.allowSend),
        execute: (name, args) => executeAgentTool(
          widget.state,
          name,
          args,
          allowedSend: cfg.allowSend,
          allowedSettings: cfg.allowSettings,
        ),
        confirm: _confirm,
        needConfigText: s.agentNeedConfig,
        formatError: (raw) => s.agentError(raw),
      );
    } on AgentException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: C.orange,
        ));
      }
    }
  }
}

/// args → 可读文本（用于确认框里的参数展示）
class _ArgsFormat {
  const _ArgsFormat();
  String convert(Object? v) {
    if (v == null) return 'null';
    if (v is Map) {
      return v.entries
          .map((e) => '${e.key}: ${convert(e.value)}')
          .join('\n');
    }
    if (v is List) return v.map(convert).join(', ');
    return '$v';
  }
}
