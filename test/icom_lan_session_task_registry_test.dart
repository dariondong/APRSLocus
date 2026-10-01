// 会话任务注册表回归（对应 mod 的 Ic705SessionTaskRegistryTest）
import 'package:flutter_test/flutter_test.dart';
import 'package:aprslocus/net/icom_lan_session_task_registry.dart';

/// 只记录取消行为的假任务（对齐 Kotlin 侧 RecordingFuture 的断言点）。
class _RecordingTask implements IcomLanCancellable {
  int cancelCalls = 0;
  bool cancelled = false;

  @override
  bool get isCancelled => cancelled;

  @override
  void cancel() {
    cancelCalls += 1;
    cancelled = true;
  }
}

void main() {
  test('同 key 替换只取消旧任务，不影响新任务', () {
    final registry = IcomLanSessionTaskRegistry();
    final first = _RecordingTask();
    final second = _RecordingTask();

    registry.replace('watchdog', first);
    registry.replace('watchdog', second);

    expect(first.isCancelled, isTrue);
    expect(first.cancelCalls, 1);
    expect(second.isCancelled, isFalse);
    expect(registry.length, 1);
  });

  test('cancel 会移除任务，因此第二次 cancel 不做任何事', () {
    final registry = IcomLanSessionTaskRegistry();
    final task = _RecordingTask();

    registry.replace('retry', task);
    registry.cancel('retry');
    registry.cancel('retry');

    expect(task.isCancelled, isTrue);
    expect(task.cancelCalls, 1);
  });

  test('cancelAll 取消每一个已登记任务', () {
    final registry = IcomLanSessionTaskRegistry();
    final first = _RecordingTask();
    final second = _RecordingTask();

    registry.replace('ping', first);
    registry.replace('idle', second);
    registry.cancelAll();

    expect(first.isCancelled, isTrue);
    expect(second.isCancelled, isTrue);
    expect(registry.length, 0);
  });
}
