/// ─── 返回键路由：让「外壳」与「内层页面」商量好这次返回谁处理 ───
///
/// ## 为什么需要它
///
/// Flutter 的 `ModalRoute.popDisposition` 是**遍历**所有注册的 `PopScope`：
/// 只要有一个 `canPop == false` 就整体返回 `doNotPop`；而
/// `onPopInvokedWithResult` 是对**每一个** popEntry 逐个调用 —— 也就是说
/// **同一个 route 上的多个 PopScope 回调会全部触发**，它们之间没有先后优先关系。
///
/// 2.0 的外壳（[HomeShell2]，非地图页时返回 → 回地图）与消息页（窄屏聊天详情
/// 非地图页时返回 → 回会话列表）各有一个 PopScope，于是从会话详情按返回会
/// **同时**发生「回到会话列表」和「跳到地图」—— 后者把前者的结果盖掉了。
///
/// ## 怎么用
///
/// * 内层页面在**需要接手返回**时把自己的意愿登记进来（返回 true = 我处理了）；
/// * 外壳的 PopScope 先问 [consume]：有人接手就什么都不做，没人接手才回地图。
///
/// 用登记而不是「让外壳去猜内层状态」：内层最清楚自己现在拦不拦，
/// 外壳去推演（哪个 tab、窄屏还是宽屏、是否在详情里）必然会在某处漏一种情况。
class BackRouter {
  BackRouter._();

  static final BackRouter instance = BackRouter._();

  /// 内层登记的处理器：返回 `true` 表示这次返回由它处理，外壳不要插手。
  ///
  /// 由内层在 build 里按当前状态登记/清除（`null` = 不拦返回）。
  bool Function()? _inner;

  /// 外壳询问：这次返回被内层接手了吗？
  ///
  /// 注意外壳的 `canPop` **不需要**看这里：内层要接手的那些情况，
  /// 内层自己那个 PopScope 已经把 `canPop` 置假，route 整体就已经是 `doNotPop`。
  bool consume() {
    final h = _inner;
    if (h == null) return false;
    return h();
  }

  /// 内层登记（`null` = 让出返回键）
  void setInner(bool Function()? h) => _inner = h;

  /// 内层离开时清掉自己的登记（只清自己的，避免把后一个页面的登记抹掉）
  void clearInner(bool Function()? h) {
    if (identical(_inner, h)) _inner = null;
  }
}
