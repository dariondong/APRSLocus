import 'dart:io';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'adif.dart';
import 'models.dart';
import 'state.dart';
import 'theme.dart';
import 'widgets.dart';

/// ADIF 导出页：勾选会话 → 生成 `.adi` 文件。
///
/// 只有**至少有一条消息**的会话才会列出 —— ADIF 的每条记录都要求 QSO_DATE /
/// TIME_ON，而没有消息的会话（例如仅收藏、从未通联过的台站）拿不到通联时间，
/// 硬导会产出时间错误的日志。所以这里直接不列，而不是列出来再失败。
class ExportAdifPage extends StatefulWidget {
  final AppState state;
  const ExportAdifPage({super.key, required this.state});
  @override
  State<ExportAdifPage> createState() => _ExportAdifPageState();
}

class _ExportAdifPageState extends State<ExportAdifPage> {
  static const _channel = MethodChannel('com.aprslocus/export');

  final Set<String> _selCalls = {};
  final Set<String> _selGroups = {};
  bool _busy = false;
  String? _lastPath;

  /// 导出选项（初值取用户上次的选择，改动即持久化）
  late AdifOptions _opts;

  AppState get st => widget.state;

  @override
  void initState() {
    super.initState();
    _opts = st.adifOptions;
  }

  /// 改动选项：本地刷新 + 写回（下次进入仍是这套设置）
  void _setOpts(AdifOptions o) {
    setState(() => _opts = o);
    st.setAdifOptions(o);
  }

  /// 预览用样本：优先取「已选中」的第一个，否则取列表第一条可导出会话。
  /// 复用 _firstTimeOf* 与 Adif.record() —— 保证预览与真正写出的内容**完全同源**。
  AdifRecord? _sampleRecord() {
    final (groups, calls) = _exportables();
    for (final g in groups) {
      if (!_selGroups.contains(g.id)) continue;
      final t = _firstTimeOfGroup(g.id);
      if (t != null) return AdifRecord(call: g.groupCall, timeOn: t);
    }
    for (final p in calls) {
      if (!_selCalls.contains(p)) continue;
      final t = _firstTimeOfCall(p);
      if (t != null) return AdifRecord(call: p, timeOn: t);
    }
    if (groups.isNotEmpty) {
      final t = _firstTimeOfGroup(groups.first.id);
      if (t != null) return AdifRecord(call: groups.first.groupCall, timeOn: t);
    }
    if (calls.isNotEmpty) {
      final t = _firstTimeOfCall(calls.first);
      if (t != null) return AdifRecord(call: calls.first, timeOn: t);
    }
    return null;
  }

  /// 该单聊会话的首条消息时间（无消息返回 null）
  DateTime? _firstTimeOfCall(String call) {
    final c = call.toUpperCase();
    DateTime? t;
    for (final m in st.messages) {
      if (m.groupId != null) continue;
      // 群呼号不算单聊
      final isGroup = st.chatGroups.any(
        (g) =>
            g.groupCall.toUpperCase() == m.to.toUpperCase() ||
            g.groupCall.toUpperCase() == m.from.toUpperCase(),
      );
      if (isGroup) continue;
      if (m.from.toUpperCase() != c && m.to.toUpperCase() != c) continue;
      if (t == null || m.time.isBefore(t)) t = m.time;
    }
    return t;
  }

  /// 该群聊的首条消息时间（无消息返回 null）
  DateTime? _firstTimeOfGroup(String groupId) {
    DateTime? t;
    for (final m in st.messages) {
      if (m.groupId != groupId) continue;
      if (t == null || m.time.isBefore(t)) t = m.time;
    }
    return t;
  }

  /// 该单聊会话的消息条数
  int _countOfCall(String call) {
    final c = call.toUpperCase();
    return st.messages.where((m) {
      if (m.groupId != null) return false;
      final isGroup = st.chatGroups.any(
        (g) =>
            g.groupCall.toUpperCase() == m.to.toUpperCase() ||
            g.groupCall.toUpperCase() == m.from.toUpperCase(),
      );
      if (isGroup) return false;
      return m.from.toUpperCase() == c || m.to.toUpperCase() == c;
    }).length;
  }

  int _countOfGroup(String groupId) =>
      st.messages.where((m) => m.groupId == groupId).length;

  /// 可导出的会话（有消息的）快照
  (List<ChatGroup>, List<String>) _exportables() {
    final groups = st.chatGroups
        .where((g) => _firstTimeOfGroup(g.id) != null)
        .toList();
    final calls = AppState.partnersOf(st.messages, st.chatGroups, st.stations)
        .where((p) => _firstTimeOfCall(p) != null)
        .toList();
    return (groups, calls);
  }

  int get _selCount => _selCalls.length + _selGroups.length;

  /// 保存文本到用户可见位置。
  /// - Android：原生通道写入「下载」目录（10+ 走 MediaStore，免存储权限）
  /// - Windows / 其它桌面：写入「文档」目录
  Future<String?> _save(String filename, String content) async {
    if (kIsWeb) return null;
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        return await _channel.invokeMethod<String>('saveToDownloads', {
          'filename': filename,
          'content': content,
        });
      } catch (_) {
        return null;
      }
    }
    try {
      final dir = await getApplicationDocumentsDirectory();
      final f = File('${dir.path}${Platform.pathSeparator}$filename');
      await f.writeAsString(content, flush: true);
      return f.path;
    } catch (_) {
      return null;
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _export() async {
    if (_busy) return;
    final (groups, calls) = _exportables();

    final records = <AdifRecord>[];
    for (final g in groups) {
      if (!_selGroups.contains(g.id)) continue;
      final t = _firstTimeOfGroup(g.id);
      if (t != null) records.add(AdifRecord(call: g.groupCall, timeOn: t));
    }
    for (final p in calls) {
      if (!_selCalls.contains(p)) continue;
      final t = _firstTimeOfCall(p);
      if (t != null) records.add(AdifRecord(call: p, timeOn: t));
    }
    if (records.isEmpty) {
      _toast(S.of(context).adifNoSelection);
      return;
    }

    // 先把文案取好，避免 await 之后再碰 context
    final loc = S.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    final text = Adif.encode(
      records,
      options: _opts,
      programVersion: AppState.appVersion,
    );
    final path = await _save(Adif.fileName(DateTime.now()), text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _lastPath = path;
    });

    if (path == null) {
      _toast(loc.adifExportFailed);
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(loc.adifExported(records.length)),
        backgroundColor: C.blue,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final (groups, calls) = _exportables();
    final total = groups.length + calls.length;
    final all = total > 0 && _selCount >= total;
    final sample = _sampleRecord();

    return Scaffold(
      backgroundColor: C.greyBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(s.exportAdif),
      ),
      body: total == 0
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  s.noConversations,
                  textAlign: TextAlign.center,
                  style: ts(13, c: C.grey),
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _hintCard(s),
                const SizedBox(height: 12),
                _toolbar(s, total, all),
                const SizedBox(height: 12),
                _optionsCard(s),
                const SizedBox(height: 12),
                if (sample != null) ...[
                  _previewCard(s, sample),
                  const SizedBox(height: 12),
                ],
                // 群聊在前、单聊在后，与消息页会话列表顺序一致
                for (final g in groups) _groupRow(s, g),
                for (final p in calls) _callRow(s, p),
                const SizedBox(height: 16),
                _exportButton(s),
                if (_lastPath != null) ...[
                  const SizedBox(height: 12),
                  _savedCard(s, _lastPath!),
                ],
              ],
            ),
    );
  }

  Widget _hintCard(S s) => Container(
    padding: const EdgeInsets.all(14),
    decoration: cardDeco(),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline_rounded, size: 16, color: C.blue),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.exportAdifDesc,
                style: ts(12, c: C.slate, w: FontWeight.w600, h: 1.4),
              ),
              const SizedBox(height: 4),
              Text(s.adifHint, style: ts(11, c: C.grey, h: 1.4)),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _toolbar(S s, int total, bool all) => Row(
    children: [
      Text(s.selectedCount(_selCount), style: T.h3),
      const Spacer(),
      TextButton(
        onPressed: () {
          setState(() {
            if (all) {
              _selCalls.clear();
              _selGroups.clear();
            } else {
              final (groups, calls) = _exportables();
              _selGroups
                ..clear()
                ..addAll(groups.map((g) => g.id));
              _selCalls
                ..clear()
                ..addAll(calls);
            }
          });
        },
        child: Text(
          all ? s.deselectAll : s.selectAll,
          style: ts(12, c: C.blue, w: FontWeight.w600),
        ),
      ),
    ],
  );

  Widget _tile({
    required IconData icon,
    required Color color,
    required Color bg,
    required String title,
    required String subtitle,
    required bool checked,
    required String chip,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(6, 10, 14, 10),
            decoration: cardDeco().copyWith(
              color: checked ? C.blueBg : C.white,
            ),
            child: Row(
              children: [
                Checkbox(
                  value: checked,
                  activeColor: C.blue,
                  onChanged: (_) => onTap(),
                ),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: ts(13, w: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: bg,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              chip,
                              style: ts(8, c: color, w: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 1),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ts(11, c: C.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 时间戳：`2026-09-12 13:15`
  String _fmt(DateTime t) {
    String p(int v) => v.toString().padLeft(2, '0');
    return '${t.year}-${p(t.month)}-${p(t.day)} ${p(t.hour)}:${p(t.minute)}';
  }

  Widget _groupRow(S s, ChatGroup g) {
    final checked = _selGroups.contains(g.id);
    final t = _firstTimeOfGroup(g.id)!;
    return _tile(
      icon: Icons.group_rounded,
      color: C.orange,
      bg: C.orangeBg,
      title: g.name,
      subtitle: '${s.messageTotal(_countOfGroup(g.id))} · ${_fmt(t)}',
      chip: s.groupShortLabel,
      checked: checked,
      onTap: () => setState(() {
        checked ? _selGroups.remove(g.id) : _selGroups.add(g.id);
      }),
    );
  }

  Widget _callRow(S s, String p) {
    final checked = _selCalls.contains(p);
    final t = _firstTimeOfCall(p)!;
    return _tile(
      icon: Icons.person_rounded,
      color: C.blue,
      bg: C.blueBg,
      title: p,
      subtitle: '${s.messageTotal(_countOfCall(p))} · ${_fmt(t)}',
      chip: s.chatShortLabel,
      checked: checked,
      onTap: () => setState(() {
        checked ? _selCalls.remove(p) : _selCalls.add(p);
      }),
    );
  }

  // ─── 导出选项 ───
  // 下拉框用空串当「不写」哨兵值：DropdownButton 规定 null 表示「未选择」，
  // 所以 null 不能作为一个可选项传进去。

  List<String> get _modeItems => [for (final v in Adif.modeChoices) v ?? ''];
  List<String> get _bandItems => [for (final v in Adif.bandChoices) v ?? ''];

  String _modeLabel(S s, String v) {
    switch (v) {
      case 'PKT':
        return s.adifModePkt;
      case 'FM':
        return s.adifModeFm;
      case 'DATA':
        return s.adifModeData;
      default:
        return v;
    }
  }

  Widget _dropRow({
    required String label,
    required String value,
    required List<String> items,
    required String Function(String) labelOf,
    required ValueChanged<String?> onChanged,
  }) {
    return Row(
      children: [
        Text(label, style: ts(12, c: C.slate, w: FontWeight.w600)),
        const Spacer(),
        DropdownButton<String>(
          value: value,
          underline: const SizedBox.shrink(),
          borderRadius: BorderRadius.circular(10),
          style: ts(12),
          items: [
            for (final it in items)
              DropdownMenuItem<String>(
                value: it,
                child: Text(labelOf(it), style: ts(12)),
              ),
          ],
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _rowSwitch({
    required String title,
    required bool value,
    required VoidCallback? onTap,
  }) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(title, style: ts(12, c: C.slate, w: FontWeight.w600))),
          Switch(
            value: value,
            activeThumbColor: C.blue,
            onChanged: onTap == null ? null : (_) => onTap(),
          ),
        ],
      ),
    ),
  );

  Widget _optionsCard(S s) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune_rounded, size: 16, color: C.blue),
              const SizedBox(width: 6),
              Text(s.adifOptions, style: ts(12, w: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 4),
          Text(s.adifModeRequiredHint, style: ts(10, c: C.grey, h: 1.4)),
          const SizedBox(height: 10),
          _dropRow(
            label: s.adifMode,
            value: _opts.mode ?? '',
            items: _modeItems,
            labelOf: (v) => v.isEmpty ? s.adifNotWritten : _modeLabel(s, v),
            onChanged: (v) => _setOpts(
              _opts.copyWith(mode: (v == null || v.isEmpty) ? null : v),
            ),
          ),
          // SUBMODE 依附于 MODE：没有 MODE 时置灰（ADIF 不允许单独出现）
          _rowSwitch(
            title: s.adifSubModeAprs,
            value: _opts.subModeAprs && _opts.mode != null,
            onTap: _opts.mode == null
                ? null
                : () => _setOpts(_opts.copyWith(subModeAprs: !_opts.subModeAprs)),
          ),
          _dropRow(
            label: s.adifBand,
            value: _opts.band ?? '',
            items: _bandItems,
            labelOf: (v) => v.isEmpty ? s.adifNotWritten : v,
            onChanged: (v) => _setOpts(
              _opts.copyWith(band: (v == null || v.isEmpty) ? null : v),
            ),
          ),
          _rowSwitch(
            title: s.adifStripSsid,
            value: _opts.stripSsid,
            onTap: () => _setOpts(_opts.copyWith(stripSsid: !_opts.stripSsid)),
          ),
        ],
      ),
    );
  }

  /// 预览：直接调用 Adif.record()，与真正写出的内容同源（不是另写一套拼接）
  Widget _previewCard(S s, AdifRecord r) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: cardDeco(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.visibility_rounded, size: 16, color: C.cyan),
              const SizedBox(width: 6),
              Text(s.adifPreview, style: ts(12, w: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: C.bgSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              Adif.record(r, _opts).trim(),
              style: mono(11, c: C.slate),
            ),
          ),
        ],
      ),
    );
  }

  Widget _exportButton(S s) {
    final enabled = _selCount > 0 && !_busy;
    return SizedBox(
      height: 46,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: enabled ? C.blue : C.greyLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: enabled ? _export : null,
        icon: _busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.file_download_rounded, size: 18),
        label: Text(
          s.export,
          style: ts(14, c: Colors.white, w: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _savedCard(S s, String path) => Container(
    padding: const EdgeInsets.all(14),
    decoration: cardDeco(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.check_circle_rounded, size: 16, color: C.green),
            const SizedBox(width: 6),
            Text(
              s.adifSavedTo(''),
              style: ts(12, c: C.green, w: FontWeight.w700),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: path));
                if (!mounted) return;
                _toast(s.adifPathCopied);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: C.blueBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  s.adifCopyPath,
                  style: ts(11, c: C.blue, w: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SelectableText(path, style: ts(11, c: C.slate, h: 1.4)),
      ],
    ),
  );
}
