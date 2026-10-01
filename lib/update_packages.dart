/// 更新包（Release 资产）的**挑选与命名约定**。
///
/// ── 为什么单独一份 ──
/// 同一套约定跨三处必须一致，而它们分散在完全不同的地方：
///
///   1. **发版流水线**（`.github/workflows/build-release.yml`，由
///      `tool/check_release_assets.py` 盯着）：安卓按 ABI 出三个包，
///      **64 位沿用原来的名字** `APRSLocus_<版本>.apk`，另外两个带
///      `_armeabi-v7a` / `_x86_64` 后缀；
///   2. **应用内更新**（[pickUpdateAssetFor]）：**按本机 CPU 架构挑对应的包**
///      （架构不对的包装不上），认不出来时回退到「列表里第一个 `.apk`」
///      （[pickUpdateAsset]）—— 也就是分架构之前的行为。这一步**由应用自己做**，
///      不摆一排让用户选：绝大多数人只知道「我要更新」；
///   3. **更新页**只把「这次会下哪个包」如实写出来（文件名 · 架构 · 大小），
///      不需要用户做任何选择。
///
/// 抽成纯函数还有一个实际好处：更新页要 AppState + 网络才挂得起来，测不动；
/// 而这些规则正是「错了不会有任何东西失败、只会有人下到装不上的包」的那类
/// 约定，必须有单测盯着（见 `test/update_packages_test.dart`）。
library;

/// 资产名是否是一个 APK（大小写不敏感；服务端给的名字大小写不保证）。
bool isApkAsset(String name) => name.toLowerCase().endsWith('.apk');

/// 更新逻辑要下的那个包：**列表顺序里的第一个 `.apk`**。
///
/// 刻意**不排序、不看 ABI**：顺序由平台 API 决定（GitHub 按名字升序），
/// 而命名约定保证那个位置就是 64 位包。在这里加排序或 ABI 判断，就等于
/// 把「更新逻辑保持原样」这条要求改掉了一半。
Map<String, dynamic>? pickUpdateAsset(List<Map<String, dynamic>> assets) {
  for (final a in assets) {
    if (isApkAsset((a['name'] ?? '').toString())) return a;
  }
  return null;
}

/// 更新要下的那个包：**优先挑与本机架构一致的那个**。
///
/// ── 为什么必须由应用自己挑 ──
/// 安卓从 v2.0.12 起按 ABI 分三个包，而**架构不对的包装不上**
/// （Android 会报 ABI 不匹配）。让用户在一排文件名里自己选「该下哪个」是错的：
/// 绝大多数人只知道「我要更新」，不该被迫了解 `armeabi-v7a` 是什么。
/// 所以更新页把本机架构（[deviceAbi]）传进来，这里替他挑好 ——
/// 32 位老机型自动拿到 32 位包，模拟器自动拿到 x86_64，谁都只需要按一次「下载」。
///
/// [deviceAbi] 为 null（桌面端 / Web / 没见过的架构）或找不到匹配时，
/// 回退到 [pickUpdateAsset]（列表里第一个 `.apk`）—— 也就是**分架构之前的行为**，
/// 于是认不出来也不会变成「挑不到包」。
Map<String, dynamic>? pickUpdateAssetFor(
  List<Map<String, dynamic>> assets,
  String? deviceAbi,
) {
  if (deviceAbi != null) {
    for (final a in assets) {
      final n = (a['name'] ?? '').toString();
      if (isApkAsset(n) && abiLabelOfAssetName(n) == deviceAbi) return a;
    }
  }
  return pickUpdateAsset(assets);
}

/// 「选择安装包」列表：该版本的全部 APK，按**文件名升序**排。
///
/// ⚠ 现在**只有测试与守卫用它**：更新页在 v2.0.12 起不再把包列给用户选，
/// 而是按本机架构自动挑好（[pickUpdateAssetFor]）。保留它是为了能对
/// 「列表顺序」这条命名约定写断言（谁先谁后是发版流水线定的）。
List<Map<String, dynamic>> apkAssetsOf(List<Map<String, dynamic>> assets) {
  final out = assets
      .where((a) => isApkAsset((a['name'] ?? '').toString()))
      .toList()
    ..sort((a, b) => (a['name'] ?? '').toString().compareTo(
          (b['name'] ?? '').toString(),
        ));
  return out;
}

/// 从文件名读架构标签：`..._armeabi-v7a.apk` → `armeabi-v7a`。
///
/// **没有后缀的一律按 `arm64-v8a` 算** —— 那是发版约定（64 位沿用原来的名字，
/// 好让应用内更新取到的还是它）。认错的话用户会下到装不上的包。
String abiLabelOfAssetName(String name) {
  final n = name.toLowerCase();
  for (final abi in const ['armeabi-v7a', 'x86_64', 'arm64-v8a']) {
    if (n.contains('_$abi.apk')) return abi;
  }
  return 'arm64-v8a';
}
