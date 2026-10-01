import 'dart:ffi';

/// 本机（**运行这个进程的**）CPU 架构标签：`arm64-v8a` / `armeabi-v7a` / `x86_64`。
///
/// ── 为什么用 `dart:ffi` 的 `Abi.current()` ──
/// 它就是 Dart 自己报的「这个 VM 是以哪个 ABI 编出来的」，**一个平台往返都不需要**，
/// 也不用往原生加方法。
///
/// ── 为什么「运行态 ABI」正是我们要的语义 ──
/// 更新包必须与**已装的那个包**同架构才能覆盖安装。64 位手机如果装的是 32 位包
/// （用户手动装的 `_armeabi-v7a`），它就跑在 `androidArm` 上 —— 这时给他下 64 位包
/// 反而装不上。跟着运行态走，两种情况都对。
///
/// 认不出来的架构（`androidIA32`、桌面端……）返回 null，让调用方回退到
/// 「列表里第一个 .apk」的原有行为 —— 不要在这里瞎猜。
String? deviceAbi() {
  final a = Abi.current();
  if (a == Abi.androidArm64) return 'arm64-v8a';
  if (a == Abi.androidArm) return 'armeabi-v7a';
  if (a == Abi.androidX64) return 'x86_64';
  return null;
}
