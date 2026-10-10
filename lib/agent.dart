/// ─── 智能体模式（AI Agent）───
///
/// 实验功能：用户自行配置一个 **OpenAI 兼容** 的接口（Base URL + Key + 模型），
/// 打开后屏幕上出现一个 AI 聊天框；智能体可以**调用工具**帮用户改设置、发消息、
/// 查台站。
///
/// ## 分层（为什么这样切）
///
/// * 本文件（`agent.dart`）：配置、对话历史、LLM 调用与**工具调用循环**。
///   它**不 import `state.dart`** —— 否则 `state.dart` 要引用本文件的配置时就会
///   循环导入。工具由上层通过回调注入：`send()` 只认「工具表 + 执行器 + 确认器」
///   三个回调，不知道 AppState 的存在。
/// * [agent_tools.dart]：把 AppState 包装成上面那三个回调（真正的工具实现）。
/// * [agent_ui.dart]：浮动聊天框 + 设置页。
///
/// ## 安全
///
/// Key 只存在本机 `SharedPreferences`，**不写日志、不进任何网络请求之外的用途**。
/// 改动设置 / 发送消息这类有副作用且不可撤销的操作，走 [AgentService.send] 的
/// `confirm` 回调 → 由界面弹确认框，用户点了「允许」才真正执行。
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'net/http_send.dart';

/// 一条工具调用（来自模型的 tool_calls）
class AgentToolCall {
  final String id;
  final String name;
  final Map<String, dynamic> arguments;

  const AgentToolCall({
    required this.id,
    required this.name,
    required this.arguments,
  });

  static AgentToolCall fromJson(Map j) {
    final fn = (j['function'] as Map?) ?? const {};
    Map<String, dynamic> args = const {};
    final raw = fn['arguments'];
    if (raw is Map) {
      args = raw.map((k, v) => MapEntry('$k', v));
    } else if (raw is String && raw.trim().isNotEmpty) {
      // 不少兼容接口把 arguments 作为 JSON 字符串返回
      try {
        final d = jsonDecode(raw);
        if (d is Map) args = d.map((k, v) => MapEntry('$k', v));
      } catch (_) {}
    }
    return AgentToolCall(
      id: '${j['id'] ?? ''}',
      name: '${fn['name'] ?? ''}',
      arguments: args,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': 'function',
        'function': {
          'name': name,
          'arguments': jsonEncode(arguments),
        },
      };
}

/// 聊天消息（role 直接用 OpenAI 的写法，便于序列化）
class AgentMessage {
  final String role; // system / user / assistant / tool
  String content;
  List<AgentToolCall> toolCalls;
  String? toolCallId; // role=tool 时对应哪次调用
  String? name; // role=tool 时的工具名

  AgentMessage({
    required this.role,
    this.content = '',
    this.toolCalls = const [],
    this.toolCallId,
    this.name,
  });

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';
  bool get isTool => role == 'tool';

  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
        if (toolCalls.isNotEmpty)
          'tool_calls': toolCalls.map((c) => c.toJson()).toList(),
        if (toolCallId != null) 'tool_call_id': toolCallId,
        if (name != null) 'name': name,
      };

  static AgentMessage fromJson(Map j) => AgentMessage(
        role: '${j['role'] ?? 'assistant'}',
        content: '${j['content'] ?? ''}',
        toolCalls: [
          for (final c in (j['tool_calls'] as List? ?? const []))
            if (c is Map) AgentToolCall.fromJson(c),
        ],
        toolCallId: j['tool_call_id']?.toString(),
        name: j['name']?.toString(),
      );
}

/// 智能体配置（全部由用户填写）
class AgentConfig {
  bool enabled;
  String baseUrl;
  String apiKey;
  String model;
  String systemPrompt;

  /// 允许智能体发送消息（私信 / 群消息 / 信标）
  bool allowSend;

  /// 允许智能体修改设置（关闭后只能查看）
  bool allowSettings;

  AgentConfig({
    this.enabled = false,
    this.baseUrl = 'https://api.openai.com/v1',
    this.apiKey = '',
    this.model = 'gpt-4o-mini',
    this.systemPrompt = '',
    this.allowSend = false,
    this.allowSettings = false,
  });

  /// 配置是否已填写到「可发起请求」的程度
  bool get ready =>
      baseUrl.trim().isNotEmpty &&
      apiKey.trim().isNotEmpty &&
      model.trim().isNotEmpty;

  /// 实际的 chat/completions 地址：用户既可填到 `/v1`，也可直接填带
  /// `/chat/completions` 的完整地址。
  String get endpoint {
    var u = baseUrl.trim();
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    if (u.endsWith('/chat/completions')) return u;
    return '$u/chat/completions';
  }

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'baseUrl': baseUrl,
        'apiKey': apiKey,
        'model': model,
        'systemPrompt': systemPrompt,
        'allowSend': allowSend,
        'allowSettings': allowSettings,
      };

  static AgentConfig fromJson(Object? j) {
    final c = AgentConfig();
    if (j is! Map) return c;
    String s(String k, String fb) => j[k]?.toString() ?? fb;
    return AgentConfig(
      enabled: j['enabled'] == true,
      baseUrl: s('baseUrl', c.baseUrl),
      apiKey: s('apiKey', c.apiKey),
      model: s('model', c.model),
      systemPrompt: s('systemPrompt', c.systemPrompt),
      allowSend: j['allowSend'] == true,
      allowSettings: j['allowSettings'] == true,
    );
  }
}

/// 用户没自定义系统提示时用的默认提示。
///
/// 用英文写：各家用模型对英文系统提示的遵循度最稳；但明确要求它**用用户的语言
/// 回复**，否则中文用户会收到英文回答。提醒它只依据工具返回值作答、不要编造
/// 台站/消息数据，也不要夸大自己的能力。
const String kDefaultSystemPrompt = '''
You are the in-app assistant of APRSLocus, an APRS client. Help the user
understand and operate the app: answer questions and, when needed, call the
provided tools to read state, change settings, send messages or jump to a
screen.

Rules:
- Always reply in the SAME language the user writes in.
- Before changing settings or sending anything, call `get_app_state` first to
  see the current values. Respect the allowed value ranges it returns.
- Never invent stations, messages or settings. Only state facts that came from
  a tool result; if you did not read it, say you do not know.
- Tools that change settings or send messages require the user's confirmation;
  explain briefly what you are about to do before calling them.
- Keep answers short and concrete.
''';

/// 智能体调用失败（消息已是可读文本）
class AgentException implements Exception {
  final String message;
  AgentException(this.message);
  @override
  String toString() => message;
}

/// 工具执行结果
class AgentToolOutcome {
  /// 回给模型的文本（成功或失败的说明）
  final String text;

  /// 界面上展示的一行摘要（可空）
  final String? note;

  const AgentToolOutcome(this.text, {this.note});
}

/// 执行一次工具调用。上层（[agent_tools.dart]）负责实现。
typedef AgentToolExecutor = Future<AgentToolOutcome> Function(
    String name, Map<String, dynamic> args);

/// 有副作用的工具执行前的确认。返回 false 表示用户拒绝。
typedef AgentToolConfirmer = Future<bool> Function(
    String name, Map<String, dynamic> args);

/// 智能体服务：配置、历史与 LLM 调用循环（单例）
class AgentService extends ChangeNotifier {
  AgentService._();
  static final AgentService instance = AgentService._();

  static const _kConfig = 'agentConfigJson';
  static const _kHistory = 'agentChatHistoryJson';

  /// 单轮对话里工具调用的最大往返次数（防止模型死循环）
  static const int maxToolRounds = 6;

  final AgentConfig config = AgentConfig();
  final List<AgentMessage> messages = [];

  bool loaded = false;
  bool busy = false;

  /// 取消令牌：自增即让进行中的 [send] 在下一个检查点退出
  int _epoch = 0;

  Future<void> load() async {
    if (loaded) return;
    loaded = true;
    try {
      final p = await SharedPreferences.getInstance();
      final c = p.getString(_kConfig);
      if (c != null && c.isNotEmpty) {
        _copy(AgentConfig.fromJson(jsonDecode(c)), config);
      }
      final h = p.getString(_kHistory);
      if (h != null && h.isNotEmpty) {
        final list = jsonDecode(h);
        if (list is List) {
          for (final m in list) {
            if (m is Map) messages.add(AgentMessage.fromJson(m));
          }
        }
      }
    } catch (_) {}
    notifyListeners();
  }

  static void _copy(AgentConfig from, AgentConfig to) {
    to
      ..enabled = from.enabled
      ..baseUrl = from.baseUrl
      ..apiKey = from.apiKey
      ..model = from.model
      ..systemPrompt = from.systemPrompt
      ..allowSend = from.allowSend
      ..allowSettings = from.allowSettings;
  }

  Future<void> saveConfig() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_kConfig, jsonEncode(config.toJson()));
    } catch (_) {}
    notifyListeners();
  }

  Future<void> saveHistory() async {
    try {
      final p = await SharedPreferences.getInstance();
      // 只留最近 60 条。**必须从一个 user 消息开始**：OpenAI 要求 assistant 的
      // 每个 tool_calls 都紧跟对应的 tool 回复；若裁剪边界正好落在中间，留下
      // 一条孤立的 tool 消息，下一次请求会整段报错（而且是很难查的 400）。
      var start = messages.length > 60 ? messages.length - 60 : 0;
      while (start < messages.length && messages[start].role != 'user') {
        start++;
      }
      final recent = messages.sublist(start);
      await p.setString(
          _kHistory, jsonEncode(recent.map((m) => m.toJson()).toList()));
    } catch (_) {}
  }

  Future<void> clearHistory() async {
    messages.clear();
    await saveHistory();
    notifyListeners();
  }

  /// 恢复出厂：清配置与历史（只动内存，磁盘由 AppState.factoryReset 统一清）
  void resetToDefaults() {
    _copy(AgentConfig(), config);
    messages.clear();
    busy = false;
  }

  /// 中止进行中的对话
  void cancel() {
    _epoch++;
    busy = false;
    notifyListeners();
  }

  /// 发一条用户消息并跑完整个「模型 ↔ 工具」循环。
  ///
  /// [tools] 是给模型的工具 schema（OpenAI tools 格式）；
  /// [execute] 真正执行某个工具；[confirm] 在「有副作用」的工具执行前询问用户，
  /// 返回 false 则不执行（并把「被拒绝」作为工具结果回给模型）。
  Future<void> send(
    String text, {
    required List<Map<String, dynamic>> tools,
    required AgentToolExecutor execute,
    required AgentToolConfirmer confirm,
    required String needConfigText,
    required String Function(String raw) formatError,
  }) async {
    final t = text.trim();
    if (t.isEmpty || busy) return;
    if (!config.ready) {
      throw AgentException(needConfigText);
    }
    final my = ++_epoch;
    busy = true;
    messages.add(AgentMessage(role: 'user', content: t));
    notifyListeners();

    try {
      for (var round = 0; round < maxToolRounds; round++) {
        if (_epoch != my) return; // 被取消
        final reply = await _chat(tools);
        if (_epoch != my) return;
        messages.add(reply);
        notifyListeners();

        final calls = reply.toolCalls;
        if (calls.isEmpty) break;

        for (final call in calls) {
          // 取消后不再执行，但**仍要**为每个 tool_call 补一条 tool 消息：
          // OpenAI 要求 assistant 里的每个 tool_calls 都有对应回复，缺一条
          // 会让下一次请求整段历史上报错。
          if (_epoch != my) {
            messages.add(AgentMessage(
              role: 'tool',
              content: 'Canceled by user.',
              toolCallId: call.id,
              name: call.name,
            ));
            continue;
          }
          var result = '';
          final needsConfirm = _needsConfirm(call.name);
          if (needsConfirm && !await confirm(call.name, call.arguments)) {
            result = 'User denied this action.';
          } else {
            final outcome = await execute(call.name, call.arguments);
            result = outcome.text;
          }
          messages.add(AgentMessage(
            role: 'tool',
            content: result,
            toolCallId: call.id,
            name: call.name,
          ));
          notifyListeners();
        }
        if (_epoch != my) return;
      }
    } catch (e) {
      messages.add(AgentMessage(
        role: 'assistant',
        content: formatError('$e'),
      ));
    } finally {
      if (_epoch == my) busy = false;
      notifyListeners();
      unawaited(saveHistory());
    }
  }

  /// 这些工具会改设置 / 发消息 → 执行前必须用户确认
  static bool _needsConfirm(String name) => name != 'get_app_state' &&
      name != 'search_stations' &&
      name != 'list_groups';

  /// 组装发给模型的消息数组
  List<Map<String, dynamic>> _wireMessages() {
    final out = <Map<String, dynamic>>[];
    // 用户没写系统提示时用内置默认：否则模型没有任何角色设定，工具用了也不解释、
    // 甚至可能编造台站数据。用户填了就以用户的为准。
    final sp = config.systemPrompt.trim().isEmpty
        ? kDefaultSystemPrompt
        : config.systemPrompt.trim();
    out.add({'role': 'system', 'content': sp});
    for (final m in messages) {
      out.add(m.toJson());
    }
    return out;
  }

  /// 调一次 chat/completions，返回助手消息（可能带 tool_calls）
  Future<AgentMessage> _chat(List<Map<String, dynamic>> tools) async {
    final body = <String, dynamic>{
      'model': config.model.trim(),
      'messages': _wireMessages(),
      if (tools.isNotEmpty) 'tools': tools,
      if (tools.isNotEmpty) 'tool_choice': 'auto',
      'temperature': 0.3,
    };
    String resp;
    try {
      resp = await httpSend(
        'POST',
        Uri.parse(config.endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${config.apiKey.trim()}',
        },
        body: jsonEncode(body),
        timeout: const Duration(seconds: 60),
      );
    } on HttpStatusError catch (e) {
      throw AgentException('HTTP ${e.status}: ${_brief(e.body)}');
    } on UnsupportedError {
      // Web 构建里 httpSend 明确不支持（CORS），给一句人话而不是裸的异常名。
      throw AgentException(
          'Network requests are not supported on this platform.');
    } catch (e) {
      throw AgentException('$e');
    }
    final data = jsonDecode(resp);
    if (data is! Map) throw AgentException('Unexpected response');
    final err = data['error'];
    if (err != null) {
      final msg = err is Map ? (err['message'] ?? err) : err;
      throw AgentException('$msg');
    }
    final choices = data['choices'];
    if (choices is! List || choices.isEmpty) {
      throw AgentException('Empty response');
    }
    final msg = (choices.first as Map)['message'];
    if (msg is! Map) throw AgentException('Empty message');
    return AgentMessage(
      role: 'assistant',
      content: '${msg['content'] ?? ''}',
      toolCalls: [
        for (final c in (msg['tool_calls'] as List? ?? const []))
          if (c is Map) AgentToolCall.fromJson(c),
      ],
    );
  }

  /// 「测试连接」：发一条最短的对话，成功返回模型返回的文本片段。
  Future<String> testConnection() async {
    if (!config.ready) {
      throw AgentException('Incomplete configuration');
    }
    final old = _epoch;
    final body = {
      'model': config.model.trim(),
      'messages': const [
        {'role': 'user', 'content': 'ping'},
      ],
      'max_tokens': 8,
    };
    String resp;
    try {
      resp = await httpSend(
        'POST',
        Uri.parse(config.endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${config.apiKey.trim()}',
        },
        body: jsonEncode(body),
        timeout: const Duration(seconds: 30),
      );
    } on HttpStatusError catch (e) {
      // 把服务端的报错正文带出来（Key 错 / 模型名错都能一眼看出）
      throw AgentException('HTTP ${e.status}: ${_brief(e.body)}');
    } catch (e) {
      throw AgentException('$e');
    }
    if (_epoch != old) return config.model;
    final data = jsonDecode(resp);
    if (data is Map) {
      final choices = data['choices'];
      if (choices is List && choices.isNotEmpty) {
        final msg = (choices.first as Map)['message'];
        if (msg is Map && '${msg['content']}'.trim().isNotEmpty) {
          return '${msg['content']}'.trim();
        }
      }
    }
    return config.model;
  }

  static String _brief(String s) {
    final t = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return t.length > 160 ? '${t.substring(0, 160)}…' : t;
  }
}
