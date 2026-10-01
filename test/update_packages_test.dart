import 'package:aprslocus/update_packages.dart';
import 'package:flutter_test/flutter_test.dart';

/// 更新包挑选与架构命名的回归（v2.0.11 起安卓按 ABI 分三个包发布）。
///
/// ── 这里钉的是什么 ──
/// 一条跨三处的约定：发版流水线给 64 位包沿用原来的文件名
/// （`APRSLocus_<版本>.apk`），另外两个带 `_armeabi-v7a` / `_x86_64` 后缀；
/// 而**更新页按本机架构自动挑**（用户不选、也不跳浏览器）。
///
/// 错了会怎样：**不会有任何东西失败** —— 只是 32 位老机型下到 64 位包、
/// 装不上（Android 报 ABI 不匹配），而用户完全不知道为什么。
/// 所以这段必须是单测，而不是注释。
void main() {
  /// 与真实 Release 一致（GitHub 按名字升序返回资产）。
  List<Map<String, dynamic>> githubOrder(String ver) => [
        {'name': 'APRSLocus_$ver.apk', 'size': 30 * 1024 * 1024},
        {'name': 'APRSLocus_${ver}_armeabi-v7a.apk', 'size': 29 * 1024 * 1024},
        {'name': 'APRSLocus_${ver}_x86_64.apk', 'size': 31 * 1024 * 1024},
        {'name': 'APRSLocus_${ver}_unsigned.ipa', 'size': 15 * 1024 * 1024},
        {'name': 'APRSLocus_Setup_$ver.exe', 'size': 16 * 1024 * 1024},
      ];

  group('按本机架构自动挑包（用户不需要知道什么是 ABI）', () {
    test('三种架构各拿到自己的那个包', () {
      final assets = githubOrder('2.0.11');
      expect(pickUpdateAssetFor(assets, 'arm64-v8a')!['name'],
          'APRSLocus_2.0.11.apk');
      // ⚠ 这条是本次要修的 bug：32 位机器上绝不能拿到 64 位包（装了会报 ABI 不匹配）
      expect(pickUpdateAssetFor(assets, 'armeabi-v7a')!['name'],
          'APRSLocus_2.0.11_armeabi-v7a.apk');
      expect(pickUpdateAssetFor(assets, 'x86_64')!['name'],
          'APRSLocus_2.0.11_x86_64.apk');
    });

    test('认不出架构（桌面端 / Web / 没见过的 ABI）→ 回退到第一个 .apk', () {
      final assets = githubOrder('2.0.11');
      expect(pickUpdateAssetFor(assets, null)!['name'],
          'APRSLocus_2.0.11.apk');
      expect(pickUpdateAssetFor(assets, 'armeabi')!['name'],
          'APRSLocus_2.0.11.apk',
          reason: '没见过的标签不能让「挑不到包」，必须回退');
    });

    test('没有 apk 时返回 null（拿不到安装包的版本）', () {
      final exeOnly = [
        {'name': 'APRSLocus_Setup_2.0.11.exe'},
        {'name': 'APRSLocus_2.0.11_unsigned.ipa'},
      ];
      expect(pickUpdateAssetFor(exeOnly, 'arm64-v8a'), isNull);
    });

    test('旧版本只有单包时，任何架构都回退到那个包（没有更好的选择）', () {
      final old = [
        {'name': 'APRSLocus_2.0.9.apk'},
        {'name': 'APRSLocus_2.0.9_unsigned.ipa'},
      ];
      for (final abi in ['arm64-v8a', 'armeabi-v7a', 'x86_64', null]) {
        expect(pickUpdateAssetFor(old, abi)!['name'], 'APRSLocus_2.0.9.apk',
            reason: 'abi=$abi');
      }
    });
  });

  group('兜底挑选（认不出架构时用；这条逻辑刻意不看 ABI）', () {
    test('取列表里第一个 .apk，不排序', () {
      expect(pickUpdateAsset(githubOrder('2.0.11'))!['name'],
          'APRSLocus_2.0.11.apk');
      // 顺序反过来就挑到别的包 —— 所以「发布顺序按名字升序」是这条兜底的前提
      final reversed = githubOrder('2.0.11').reversed.toList();
      expect(pickUpdateAsset(reversed)!['name'],
          'APRSLocus_2.0.11_x86_64.apk');
    });
  });

  group('架构标签与命名', () {
    test('三种后缀 + 「无后缀 ⇒ 64 位」兜底', () {
      expect(abiLabelOfAssetName('APRSLocus_2.0.11.apk'), 'arm64-v8a');
      expect(abiLabelOfAssetName('APRSLocus_2.0.11_armeabi-v7a.apk'),
          'armeabi-v7a');
      expect(abiLabelOfAssetName('APRSLocus_2.0.11_x86_64.apk'), 'x86_64');
      // 大小写不敏感（服务端给的名字不保证大小写）
      expect(abiLabelOfAssetName('APRSlocus_2.0.11_ARM64-V8A.APK'),
          'arm64-v8a');
      // 不认识的名字按最保守的 64 位算（绝大多数手机）
      expect(abiLabelOfAssetName('weird.apk'), 'arm64-v8a');
    });

    test('列表顺序 = 名字升序（兜底那条路依赖它）', () {
      final names =
          apkAssetsOf(githubOrder('2.0.11')).map((a) => a['name']).toList();
      expect(names, [
        'APRSLocus_2.0.11.apk',
        'APRSLocus_2.0.11_armeabi-v7a.apk',
        'APRSLocus_2.0.11_x86_64.apk',
      ]);
      // 而且第一个必须就是「认不出架构」时的兜底结果
      expect(names.first,
          pickUpdateAsset(githubOrder('2.0.11'))!['name']);
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
