// SPDX-License-Identifier: GPL-2.0-or-later
// See LICENSING.md: this file is additionally available under GPL-2.0-or-later.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:aprslocus/net/icom_lan_backend_controller.dart';
import 'package:aprslocus/net/icom_lan_radio_session.dart';
import 'package:aprslocus/net/icom_lan_reconnect_scheduler.dart';
import 'package:aprslocus/net/icom_lan_rx_session.dart';
import 'package:aprslocus/net/icom_lan_rx_session_engine.dart';
import 'package:aprslocus/net/icom_lan_settings.dart';

class FakeService implements IcomLanBackendService {
  int linkOnCalls = 0;
  int linkOffCalls = 0;
  final List<String> aborts = [];

  @override
  void postLinkOn() => linkOnCalls++;

  @override
  void postLinkOff() => linkOffCalls++;

  @override
  void postAbort(String message) => aborts.add(message);
}

class FakeScheduledTask {
  FakeScheduledTask(this.delayMillis, this.action);
  final int delayMillis;
  final void Function() action;
  bool cancelled = false;
}

class _SimpleRetryHandle implements IcomLanRetryHandle {
  _SimpleRetryHandle(this.onCancel);
  final void Function() onCancel;
  @override
  void cancel() => onCancel();
}

class FakeReconnectScheduler implements IcomLanReconnectScheduler {
  final List<FakeScheduledTask> tasks = [];
  int closeCalls = 0;

  @override
  IcomLanRetryHandle schedule(int delayMillis, void Function() action) {
    final task = FakeScheduledTask(delayMillis, action);
    tasks.add(task);
    return _SimpleRetryHandle(() => task.cancelled = true);
  }

  @override
  void close() => closeCalls++;

  void runNext() {
    final task = tasks.firstWhere(
      (t) => !t.cancelled,
      orElse: () => throw StateError('No pending retry'),
    );
    task.cancelled = true;
    task.action();
  }
}

class FakeRadioSession implements IcomLanRadioSession {
  FakeRadioSession({
    required this.config,
    required this.callbacks,
  });

  final IcomLanConfig config;
  final IcomLanCallbacks callbacks;

  int startCalls = 0;
  int stopCalls = 0;
  int closeCalls = 0;
  final List<Uint8List> transmitted = [];
  bool transmitResult = true;
  void Function(void Function()? onClosed) closeHandler =
      (onClosed) => onClosed?.call();

  @override
  IcomLanSessionState state = const IcomLanSessionState();

  @override
  bool isTransmitting = false;

  @override
  void start() => startCalls++;

  @override
  void stop() => stopCalls++;

  @override
  bool transmitAudio(Uint8List pcm) {
    transmitted.add(pcm);
    return transmitResult;
  }

  @override
  void close([void Function()? onClosed]) {
    closeCalls++;
    closeHandler(onClosed);
  }

  void emitPhase(IcomLanPhase phase) {
    state = state.copyWith(phase: phase);
    callbacks.onStateChanged?.call(state);
  }
}

void main() {
  late FakeService service;
  late FakeReconnectScheduler scheduler;
  late List<FakeRadioSession> sessions;
  late IcomLanConfig config;
  late IcomLanBackendController controller;

  setUp(() {
    service = FakeService();
    scheduler = FakeReconnectScheduler();
    sessions = [];
    config = const IcomLanConfig(
      host: '192.168.1.143',
      controlPort: 50001,
      username: 'ic705',
      password: 'password',
    );
    controller = IcomLanBackendController(
      service: service,
      config: config,
      sessionFactory: ({required config, required callbacks}) {
        final session = FakeRadioSession(config: config, callbacks: callbacks);
        sessions.add(session);
        return session;
      },
      reconnectScheduler: scheduler,
    );
  });

  tearDown(() {
    controller.stop();
  });

  test('启动时校验非法配置并中止', () {
    final badController = IcomLanBackendController(
      service: service,
      config: const IcomLanConfig(host: '', username: '', password: ''),
      reconnectScheduler: scheduler,
    );
    final started = badController.start();
    expect(started, isFalse);
    expect(service.aborts, isNotEmpty);
    expect(service.aborts.first, contains('Invalid settings'));
  });

  test('启动创建初始会话并调用 start', () {
    final started = controller.start();
    expect(started, isTrue);
    expect(sessions.length, 1);
    expect(sessions.first.startCalls, 1);
    expect(controller.activeGeneration, 1);
    expect(controller.isLinkUp, isFalse);
  });

  test('进入 RECEIVING 时触发 postLinkOn，离开触发 postLinkOff', () {
    controller.start();
    final session = sessions.first;

    session.emitPhase(IcomLanPhase.controlDiscovery);
    expect(controller.isLinkUp, isFalse);
    expect(service.linkOnCalls, 0);

    session.emitPhase(IcomLanPhase.receiving);
    expect(controller.isLinkUp, isTrue);
    expect(service.linkOnCalls, 1);

    // 再次触发 RECEIVING 不会重复发 linkOn
    session.emitPhase(IcomLanPhase.receiving);
    expect(service.linkOnCalls, 1);

    session.emitPhase(IcomLanPhase.reconnectWait);
    expect(controller.isLinkUp, isFalse);
    expect(service.linkOffCalls, 1);
  });

  test('经历 reconnectWait 后的失败触发可恢复重连流程', () {
    controller.start();
    final session1 = sessions.first;

    session1.emitPhase(IcomLanPhase.receiving);
    expect(controller.isLinkUp, isTrue);

    // 会话进入重连等待，随后失败
    session1.emitPhase(IcomLanPhase.reconnectWait);
    expect(controller.isLinkUp, isFalse);

    session1.emitPhase(IcomLanPhase.failed);
    expect(session1.closeCalls, 1);
    expect(scheduler.tasks.length, 1);
    expect(service.aborts, isEmpty);

    // 运行调度器下一次重试，应产生第 2 代会话
    scheduler.runNext();
    expect(sessions.length, 2);
    final session2 = sessions[1];
    expect(controller.activeGeneration, 2);
    expect(session2.startCalls, 1);
  });

  test('未经历 reconnectWait 的硬失败直接中止服务', () {
    controller.start();
    final session = sessions.first;

    // 直接认证失败/硬失败
    session.emitPhase(IcomLanPhase.failed);
    expect(session.closeCalls, 1);
    expect(scheduler.tasks, isEmpty);
    expect(service.aborts, isNotEmpty);
  });

  test('音频发射仅在 RECEIVING 态且非发射中时转发', () {
    controller.start();
    final session = sessions.first;
    final pcm = Uint8List(240);

    // 未进入 RECEIVING 时拒绝发射
    expect(controller.transmitAudio(pcm), isFalse);
    expect(session.transmitted, isEmpty);

    // 进入 RECEIVING 后允许发射
    session.emitPhase(IcomLanPhase.receiving);
    expect(controller.transmitAudio(pcm), isTrue);
    expect(session.transmitted.length, 1);

    // 发射中禁止重入
    session.isTransmitting = true;
    expect(controller.transmitAudio(pcm), isFalse);
  });

  test('控制器 stop 关闭会话与调度器', () {
    controller.start();
    final session = sessions.first;

    controller.stop();
    expect(controller.isStopped, isTrue);
    expect(session.closeCalls, 1);
    expect(scheduler.closeCalls, 1);
  });
}
