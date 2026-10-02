/// 一次会话 generation 内、按 key 管理的定时任务（对应 mod 的
/// `session/Ic705SessionTaskRegistry.kt`）。
///
/// 「按 key 替换 / 取消」是这套状态机的关键：同一语义的定时器（心跳、空闲、
/// 重连、连接信息 settle/retry）必须**至多存在一个**，否则重连后会同时跑两套。
library;

import 'dart:async';

/// 可取消的定时任务（便于测试注入假实现）。
abstract class IcomLanCancellable {
  /// 取消（幂等；与 Kotlin 侧一致：**不**中断正在执行的 block）。
  void cancel();

  bool get isCancelled;
}

/// [Timer] 的 [IcomLanCancellable] 适配。
class IcomLanTimerTask implements IcomLanCancellable {
  IcomLanTimerTask(this._timer);

  final Timer _timer;
  bool _cancelled = false;

  @override
  bool get isCancelled => _cancelled;

  @override
  void cancel() {
    _cancelled = true;
    _timer.cancel();
  }
}

/// 会话内定时任务注册表。
class IcomLanSessionTaskRegistry {
  final Map<String, IcomLanCancellable> _tasks = {};

  /// 注册（同 key 的旧任务被取消）。
  void replace(String key, IcomLanCancellable task) {
    _tasks.remove(key)?.cancel();
    _tasks[key] = task;
  }

  /// 取消并移除（再调一次不会重复取消 —— 与 Kotlin 语义一致）。
  void cancel(String key) {
    _tasks.remove(key)?.cancel();
  }

  /// 取消全部。
  void cancelAll() {
    for (final task in _tasks.values) {
      task.cancel();
    }
    _tasks.clear();
  }

  /// 当前登记的任务数（诊断/测试用）。
  int get length => _tasks.length;
}
