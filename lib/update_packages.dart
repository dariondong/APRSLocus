/// 更新包（Release 资产）的**挑选与命名约定**。
///
/// ── 为什么单独一份 ──
/// 同一套约定跨三处必须一致，而它们分散在完全不同的地方：
///
///   1. **发版流水线**（`.github/workflows/build-release.yml`，由
///      `tool/check_release_assets.py` 盯着）：安卓按 ABI 出三个包，
///      **64 位沿用原来的名字** `APRSLocus_<版本>.apk`，另外两个带
///      `_armeabi-v7a` / `_x86_64` 后缀；
///   2. **应用内更新**（本文件的 [pickUpdateAsset]）：取资产列表里**第一个** `.apk`
///      —— 平台按名字升序返回，于是 `.`（0x2E）比 `_`（0x5F）小的那个（64 位）
///      永远排第一。**这条逻辑一个字节都不该动**（用户明确要求）；
///   3. **更新页的「选择安装包」列表**（[apkAssetsOf] + [abiLabelOfAssetName]）：
///      按同一个顺序展示，并把第一个标成「推荐」。
///
/// 抽成纯函数还有一个实际好处：更新页要 AppState + 网络才挂得起来，测不动；
/// 而这三条规则正是「错了不会有任何东西失败、只会有人下到装不上的包」的那类
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

/// 「选择安装包」列表：该版本的全部 APK，按**文件名升序**排。
///
/// 与 Release 页上 GitHub 的展示顺序一致 —— 于是第一个就是 [pickUpdateAsset]
/// 会挑中的那个包，标签「推荐」也就名副其实。
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
