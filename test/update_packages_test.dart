import 'package:aprslocus/update_packages.dart';
import 'package:flutter_test/flutter_test.dart';

/// 更新包挑选与「选择安装包」列表的回归（v2.0.11 起安卓按 ABI 分三个包发布）。
///
/// 这里钉的是**一条跨三处的约定**：发版流水线给 64 位包沿用原来的文件名
/// （`APRSLocus_<版本>.apk`），应用内更新取资产列表里第一个 `.apk`，
/// 而新版「选择安装包」列表把这个顺序显示出来并把第一个标成「推荐」。
///
/// 错了会怎样：**不会有任何东西失败** —— 只有 32 位老机型用户按提示下了
/// 64 位包、装不上（或者反过来）。所以这段必须是单测，而不是注释。
void main() {
  /// 与真实 Release 一致（GitHub 按名字升序返回资产）。
  List<Map<String, dynamic>> githubOrder(String ver) => [
        {'name': 'APRSLocus_$ver.apk', 'size': 30 * 1024 * 1024},
        {'name': 'APRSLocus_${ver}_armeabi-v7a.apk', 'size': 29 * 1024 * 1024},
        {'name': 'APRSLocus_${ver}_x86_64.apk', 'size': 31 * 1024 * 1024},
        {'name': 'APRSLocus_${ver}_unsigned.ipa', 'size': 15 * 1024 * 1024},
        {'name': 'APRSLocus_Setup_$ver.exe', 'size': 16 * 1024 * 1024},
      ];

  group('挑包（应用内更新用；这条逻辑要求「不要动」）', () {
    test('取列表里第一个 .apk —— 不看 ABI、不排序', () {
      final a = pickUpdateAsset(githubOrder('2.0.11'))!;
      expect(a['name'], 'APRSLocus_2.0.11.apk');

      // 顺序变了就挑到别的包：所以「命名 + 平台排序」必须成立，
      // 这里把这个前提显式写出来（谁要是想加排序/ABI 判断，先看这条）。
      final reversed = githubOrder('2.0.11').reversed.toList();
      expect(pickUpdateAsset(reversed)!['name'], 'APRSLocus_2.0.11_x86_64.apk');
    });

    test('没有 apk 时返回 null（Windows 版本 / 平台页）', () {
      expect(
        pickUpdateAsset([
          {'name': 'APRSLocus_Setup_2.0.11.exe'},
          {'name': 'APRSLocus_2.0.11_unsigned.ipa'},
        ]),
        isNull,
      );
    });
  });

  group('选择安装包列表', () {
    test('只列 apk，按文件名升序 ⇒ 64 位（无后缀）排第一', () {
      final list = apkAssetsOf(githubOrder('2.0.11'));
      expect(list.length, 3);
      expect(list.map((a) => a['name']).toList(), [
        'APRSLocus_2.0.11.apk',
        'APRSLocus_2.0.11_armeabi-v7a.apk',
        'APRSLocus_2.0.11_x86_64.apk',
      ]);
    });

    test('标「推荐」的那个 == 应用内更新会挑的那个（跨三处的那条不变量）', () {
      for (final ver in ['1.0.0', '2.0.11', '10.0.0']) {
        final assets = githubOrder(ver);
        expect(
          apkAssetsOf(assets).first['name'],
          pickUpdateAsset(assets)!['name'],
          reason: 'v$ver：列表里标推荐的和更新下到的不是同一个包',
        );
      }
    });

    test('架构标签：三种后缀 + 「无后缀 ⇒ 64 位」兜底', () {
      expect(abiLabelOfAssetName('APRSLocus_2.0.11.apk'), 'arm64-v8a');
      expect(abiLabelOfAssetName('APRSLocus_2.0.11_armeabi-v7a.apk'),
          'armeabi-v7a');
      expect(abiLabelOfAssetName('APRSLocus_2.0.11_x86_64.apk'), 'x86_64');
      // 大小写不敏感（服务端给的名字不保证大小写）
      expect(abiLabelOfAssetName('APRSlocus_2.0.11_ARM64-V8A.APK'), 'arm64-v8a');
      // 不认识的名字按最保守的 64 位算（绝大多数手机）
      expect(abiLabelOfAssetName('weird.apk'), 'arm64-v8a');
    });

    test('isApkAsset 只认 .apk 结尾', () {
      expect(isApkAsset('a.APK'), isTrue);
      expect(isApkAsset('a.apk'), isTrue);
      expect(isApkAsset('a.apks'), isFalse);
      expect(isApkAsset('a.ipa'), isFalse);
      expect(isApkAsset(''), isFalse);
    });
  });
}
