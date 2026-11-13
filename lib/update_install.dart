import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 更新包在本机上的几件事：**校签名**、放进系统「下载」、删掉、交给安装器。
///
/// ── 为什么要单独一份 ──
/// 这几件事以前散在更新页里：下载写到 `getExternalStorageDirectory()`
/// （也就是 `Android/data/.../files`，用户在文件管理器里根本翻不到），
/// 装之前也不看这个包到底是谁签的。现在统一走这里：
///
///   * 下载完成后先 [verify]：签名与本机不一致的包**直接删掉**，
///     不弹安装、也不留在「下载」里；
///   * 校验通过再 [publish] 复制一份到系统「下载」，用户随时能自己找到；
///   * 用户在更新页点安装时，原生侧会**再校验一次**（[installFromDownloads]），
///     因为它可能是上次装到一半、这次又从列表里点的。
///
/// 桌面端没有可校验的签名（Windows 的 exe 本来也没签），
/// [isAndroid] 为假时这里的方法都退化成「不做任何事」，由调用方按平台走原来的路。
enum ApkTrust {
  /// 签名与本机一致，可以装。
  ok,

  /// 包名或签名对不上：这个包不是我们发的（或被改过），不能装。
  mismatch,

  /// 读不出签名（文件坏了 / 系统接口失败），当作不可信。
  unknown,

  /// 这个平台没有可校验的签名（桌面 / Web）。
  skip,
}

class UpdateInstaller {
  UpdateInstaller._();

  static const MethodChannel _ch = MethodChannel('com.aprslocus/installer');

  static bool get isAndroid => defaultTargetPlatform == TargetPlatform.android;

  /// 系统「下载」目录里安装包的文件名前缀（下载时就按这个命名）。
  static const String prefix = 'APRSLocus_';

  /// 读一个 apk 的包名 / 版本号 / 签名摘要。读不出返回 null。
  static Future<Map<String, dynamic>?> info(String path) async {
    if (!isAndroid) return null;
    try {
      final r = await _ch.invokeMethod<Map>('apkInfo', {'path': path});
      if (r == null) return null;
      return r.map((k, v) => MapEntry(k.toString(), v));
    } catch (_) {
      return null;
    }
  }

  /// 校验 [path] 这个安装包是不是我们自己签的。
  static Future<String?> ownSignature() async {
    if (!isAndroid) return null;
    try {
      final r = await _ch.invokeMethod<Map>('ownSignature');
      if (r == null) return null;
      final sig = r['sig'];
      return sig is String && sig.isNotEmpty ? sig : null;
    } catch (_) {
      return null;
    }
  }

  /// 校验 [path] 这个安装包是不是我们自己签的。
  ///
  /// 比的是**签名证书的 SHA-256**，不是版本号：版本号谁都能改，
  /// 证书改不了 —— 换一个证书签的包，系统也装不上（签名冲突）。
  static Future<ApkTrust> verify(String path) async {
    if (!isAndroid) return ApkTrust.skip;
    try {
      final mine = await _ch.invokeMethod<Map>('ownSignature');
      if (mine == null) return ApkTrust.unknown;
      final mySig = (mine['sig'] ?? '').toString();
      final myPkg = (mine['package'] ?? '').toString();
      if (mySig.isEmpty) return ApkTrust.unknown;
      final got = await info(path);
      if (got == null) return ApkTrust.unknown;
      if (myPkg.isNotEmpty && (got['package'] ?? '').toString() != myPkg) {
        return ApkTrust.mismatch;
      }
      final sig = (got['sig'] ?? '').toString();
      if (sig.isEmpty) return ApkTrust.unknown;
      return sig == mySig ? ApkTrust.ok : ApkTrust.mismatch;
    } catch (_) {
      return ApkTrust.unknown;
    }
  }

  /// 把一个下载好的包复制进系统「下载」目录，返回用户可见的路径
  /// （形如 `Download/APRSLocus_2.2.2.apk`）。失败返回 null。
  static Future<String?> publish(String path, String fileName) async {
    if (!isAndroid) return null;
    try {
      final r = await _ch.invokeMethod<String>('copyToDownloads', {
        'path': path,
        'filename': fileName,
      });
      return (r == null || r.isEmpty) ? null : r;
    } catch (_) {
      return null;
    }
  }

  /// 系统「下载」里已经有的安装包：[{'name','size'}]，按系统顺序（新的在前）。
  static Future<List<MapEntry<String, int>>> packages() async {
    if (!isAndroid) return const [];
    try {
      final list = await _ch.invokeMethod<List>('listDownloads', {
        'prefix': prefix,
      });
      if (list == null) return const [];
      final out = <MapEntry<String, int>>[];
      for (final e in list) {
        if (e is Map) {
          final n = (e['name'] ?? '').toString();
          if (n.toLowerCase().endsWith('.apk')) {
            out.add(MapEntry(n, ((e['size'] as num?) ?? 0).toInt()));
          }
        }
      }
      return out;
    } catch (_) {
      return const [];
    }
  }

  /// 删掉系统「下载」里的一个安装包。
  static Future<bool> remove(String fileName) async {
    if (!isAndroid) return false;
    try {
      final ok = await _ch.invokeMethod<bool>('deleteDownloads', {
        'name': fileName,
      });
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 从「下载」里取包去装：原生侧会复制一份到缓存、再校一次签名，然后交给安装器。
  ///
  /// 返回 `ok` / `no-file` / `sig-mismatch` / `failed`。
  static Future<String> installFromDownloads(String fileName) async {
    if (!isAndroid) return 'failed';
    try {
      final r = await _ch.invokeMethod<String>('installApkFromDownloads', {
        'name': fileName,
      });
      return r ?? 'failed';
    } catch (_) {
      return 'failed';
    }
  }

  /// 校一下「下载」里那个包的签名（不安装、不留副本）。
  ///
  /// 返回 `ok` / `sig-mismatch` / `no-file` / `failed`。
  static Future<String> verifyDownloads(String fileName) async {
    if (!isAndroid) return 'failed';
    try {
      final r = await _ch.invokeMethod<String>('verifyDownloads', {
        'name': fileName,
      });
      return r ?? 'failed';
    } catch (_) {
      return 'failed';
    }
  }

  /// 能不能安装未知来源的应用（Android 8 起是每应用一个开关）。
  static Future<bool> canRequestInstall() async {
    if (!isAndroid) return false;
    try {
      return await _ch.invokeMethod<bool>('canRequestInstall') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 跳到「安装未知应用」设置页。
  static Future<void> openInstallSettings() async {
    if (!isAndroid) return;
    try {
      await _ch.invokeMethod('openInstallSettings');
    } catch (_) {}
  }

  /// 清掉安装时复制到缓存的那份副本（装完重启后不再需要）。
  static Future<void> cleanCache() async {
    if (!isAndroid) return;
    try {
      await _ch.invokeMethod('cleanUpdateCache');
    } catch (_) {}
  }

  /// 桌面 / 老路径用：直接交给系统打开一个本地文件。
  static Future<bool> installPath(String path) async {
    if (!isAndroid) return false;
    try {
      return await _ch.invokeMethod<bool>('installApk', {'path': path}) ?? false;
    } catch (_) {
      return false;
    }
  }
}
