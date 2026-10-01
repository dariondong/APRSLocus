import 'device_abi_io.dart' if (dart.library.html) 'device_abi_web.dart' as impl;

/// 本机（运行这个进程的）CPU 架构标签：`arm64-v8a` / `armeabi-v7a` / `x86_64`；
/// 认不出来时 `null`。
///
/// 更新页用它**自动挑好**要下的安装包 —— 用户不需要知道什么是 ABI：
/// 安卓从 v2.0.12 起按架构分三个包发布，而架构不对的包**装不上**，
/// 所以这一步必须应用自己做，不能摆一排让用户选。
///
/// 实现分两套（`dart:ffi` 在 Web 上不存在）：见 `device_abi_io.dart` /
/// `device_abi_web.dart`，与 `garmin_fetch_*` 同一个模式。
String? deviceAbi() => impl.deviceAbi();
