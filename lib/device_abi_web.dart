/// Web（io 变体的替身）：没有 `dart:ffi`，也没有「按 CPU 架构挑包」这回事。
///
/// 返回 null ⇒ 调用方走「列表里第一个 `.apk`」的原有行为。
String? deviceAbi() => null;
