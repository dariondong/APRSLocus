import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models.dart';
import 'state.dart';
import 'theme.dart';

/// 日志查看页：分级筛选、清空、复制导出
class LogPage extends StatelessWidget {
  final AppState state;
  const LogPage({super.key, required this.state});

  String _fmt(DateTime t) =>
      '${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')} '
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:'
      '${t.second.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.white,
        title: const Text('系统日志'),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: '复制全部日志',
            icon: const Icon(Icons.copy_rounded, size: 20),
            onPressed: () {
              final sb = StringBuffer();
              for (final l in state.logs) {
                sb.writeln(
                    '${_fmt(l.time)} [${logLevelName(l.level)}] ${l.source} ${l.message}');
              }
              Clipboard.setData(ClipboardData(text: sb.toString()));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('已复制 ${state.logs.length} 条日志'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          IconButton(
            tooltip: '清空日志',
            icon: const Icon(Icons.delete_sweep_rounded, size: 20),
            onPressed: () => state.clearLogs(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: ListenableBuilder(
        listenable: state,
        builder: (context, _) {
          final logs = state.logs;
          if (logs.isEmpty) {
            return Center(
              child: Text('暂无日志', style: TextStyle(color: C.grey, fontSize: 14)),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: logs.length,
            separatorBuilder: (_, _) => SizedBox(height: 6),
            itemBuilder: (_, i) {
              final e = logs[i];
              final c = logLevelColor(e.level);
              return Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: C.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: C.border),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: c.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(logLevelName(e.level),
                        style: ts(9, c: c, w: FontWeight.w700)),
                  ),
                  SizedBox(width: 8),
                  Text(_fmt(e.time),
                      style: mono(9, c: C.grey)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('[${e.source}]',
                              style: ts(10, c: c, w: FontWeight.w700)),
                          SizedBox(height: 2),
                          Text(e.message,
                              style: ts(12, c: C.ink, h: 1.3)),
                        ]),
                  ),
                ]),
              );
            },
          );
        },
      ),
    );
  }
}
