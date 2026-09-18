/// 主题「导入的图片」的平台实现（io 变体：Android / Windows / Linux / macOS）。
///
/// 为什么单独一个文件、还要有 web 变体：这里的每一件事（读磁盘、写应用目录、
/// 渲染 `Image.file` / `SvgPicture.file`）都依赖 `dart:io`。把它们隔离在本文件里，
/// 共享代码（theme_store.dart / theme_page.dart）就不必碰 `dart:io`，
/// Web 构建也就不会因为一个 import 而失败。
///
/// 存储位置：`<应用支持目录>/<子目录>/<内容哈希>.<扩展名>`。用**内容哈希**而不是
/// 时间戳命名，有两个实际好处：
/// 1. 同一张图重复导入不会攒出一堆副本，磁盘占用不随操作次数增长；
/// 2. 主题文件里存的是 `file:ab12cd34.png` 这种稳定名字，分享给别人时
///    不会因为「在他机器上是另一个时间戳」而失效（当然对方仍需自备图片）。
///
/// 图标与背景图共用这套机制，只是**子目录与大小上限不同**：
/// 图标要塞进 22~40dp，2MB 足够；背景图是整屏的，给到 8MB。
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show MethodChannel, PlatformException;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path_provider/path_provider.dart';

/// 当前平台是否支持「导入图片」
bool get supportsFileIcons => !kIsWeb;

enum IconImportError { cancelled, unsupportedPlatform, badFormat, tooLarge, failed }

class IconImportResult {
  final String? ref; // `file:xxx.png`
  final String? name; // 原文件名（给用户确认用）
  final IconImportError? error;

  const IconImportResult.ok(String this.ref, this.name) : error = null;
  const IconImportResult.fail(IconImportError this.error)
      : ref = null,
        name = null;

  bool get isOk => ref != null;
}

/// 图标文件上限：要塞进 22~40dp 的位置，2MB 已经极其宽松；
/// 不设上限的话，一张手机原图（8MB）就会变成主题里一个巨大的资源。
const int kIconMaxBytes = 2 * 1024 * 1024;

/// 背景图上限：整屏图，8MB 允许常见的手机照片直接使用。
const int kBackgroundMaxBytes = 8 * 1024 * 1024;

const String kIconDirName = 'theme_icons';
const String kBackgroundDirName = 'theme_backgrounds';

const _exportChannel = MethodChannel('com.aprslocus/export');

final Map<String, Directory?> _dirs = {};
final Map<String, String> _dirErrors = {};

Future<Directory?> _ensureDir(String name) async {
  if (_dirs.containsKey(name)) return _dirs[name];
  if (_dirErrors.containsKey(name)) return null;
  try {
    final base = await getApplicationSupportDirectory();
    final d = Directory('${base.path}${Platform.pathSeparator}$name');
    if (!await d.exists()) await d.create(recursive: true);
    _dirs[name] = d;
    return d;
  } catch (e) {
    // 记下失败原因，避免每次渲染都重试一遍（失败是持久的，重试只会白耗 IO）
    _dirErrors[name] = '$e';
    return null;
  }
}

/// 只接受「纯文件名」：主题文件是用户可编辑的，`../../foo` 这种必须挡住
bool _isSafeName(String name) =>
    name.isNotEmpty &&
    !name.contains('/') &&
    !name.contains('\\') &&
    !name.contains('..') &&
    RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(name);

/// 把 `file:xxx.png` 解析成绝对路径；文件不存在返回 null。
///
/// 两个子目录都查：主题里只存文件名，不存目录 —— 这样主题文件更干净，
/// 用户换图时也不会留下一堆指向旧目录的死引用。
Future<String?> resolveImageRef(String ref) async {
  if (!ref.startsWith('file:')) return null;
  final name = ref.substring(5);
  if (!_isSafeName(name)) return null;
  for (final dir in const [kIconDirName, kBackgroundDirName]) {
    final d = await _ensureDir(dir);
    if (d == null) continue;
    final p = '${d.path}${Platform.pathSeparator}$name';
    if (await File(p).exists()) return p;
  }
  return null;
}

/// 兼容旧调用点：图标的路径查询
Future<String?> iconFilePath(String storedName) async =>
    resolveImageRef('file:$storedName');

/// 拉起选择器 → 校验 → 落盘 → 返回 `file:xxx` 引用。
///
/// [maxBytes] / [dirName] / [prefix] 让它同时服务图标与背景图：
/// 两条路径唯一不同的就是这三个参数，没必要把「读字节、判魔数、算哈希、
/// 写盘」这四步写两遍（复制两份的结果通常是其中一份忘了同步修）。
Future<IconImportResult> importPickedImage({
  required int maxBytes,
  required String dirName,
  required String prefix,
}) async {
  try {
    final picked = await _pickBytes(maxBytes);
    if (picked == null) {
      return const IconImportResult.fail(IconImportError.cancelled);
    }
    final bytes = picked.bytes;
    if (bytes.length > maxBytes) {
      return const IconImportResult.fail(IconImportError.tooLarge);
    }
    final ext = _detectFormat(bytes);
    if (ext == null) {
      return const IconImportResult.fail(IconImportError.badFormat);
    }
    final d = await _ensureDir(dirName);
    if (d == null) {
      return const IconImportResult.fail(IconImportError.failed);
    }
    final stored = '${prefix}_${_fnv1a(bytes)}.$ext';
    final f = File('${d.path}${Platform.pathSeparator}$stored');
    if (!await f.exists()) {
      await f.writeAsBytes(bytes, flush: true);
    }
    return IconImportResult.ok('file:$stored', picked.name);
  } on _TooLarge {
    // 必须排在 catch-all 之前：否则「图太大」会被归成泛指失败，
    // 用户得到的提示就从「图超过 N MB」变成「导入失败」，无从下手。
    return const IconImportResult.fail(IconImportError.tooLarge);
  } on FileSystemException {
    return const IconImportResult.fail(IconImportError.failed);
  } catch (_) {
    return const IconImportResult.fail(IconImportError.failed);
  }
}

/// 导入一个图标
Future<IconImportResult> importIconFromPicker() => importPickedImage(
      maxBytes: kIconMaxBytes,
      dirName: kIconDirName,
      prefix: 'icon',
    );

/// 导入一张背景图
Future<IconImportResult> importBackgroundFromPicker() => importPickedImage(
      maxBytes: kBackgroundMaxBytes,
      dirName: kBackgroundDirName,
      prefix: 'bg',
    );

class _Picked {
  final String name;
  final Uint8List bytes;

  const _Picked(this.name, this.bytes);
}

Future<_Picked?> _pickBytes(int maxBytes) async {
  if (defaultTargetPlatform == TargetPlatform.android) {
    // Android：没有可用的文件路径（content:// URI），必须由原生侧读字节回来。
    // 上限也要传过去：原生侧得在**读之前**就知道该停在哪，否则大文件照样把内存吃爆。
    try {
      final r = await _exportChannel.invokeMapMethod<String, dynamic>(
        'pickBinaryFile',
        {'maxBytes': maxBytes},
      ).timeout(const Duration(minutes: 5));
      if (r == null) return null;
      final b64 = '${r['data'] ?? ''}';
      if (b64.isEmpty) return null;
      return _Picked('${r['name'] ?? 'image.png'}', base64Decode(b64));
    } on PlatformException catch (e) {
      // 原生侧区分「太大」与其它失败，好让提示更准确
      throw e.code == 'TOO_LARGE' ? const _TooLarge() : Exception(e.message);
    }
  }
  final path = await _pickPathOnDesktop();
  if (path == null || path.trim().isEmpty) return null;
  final f = File(path.trim());
  if (!await f.exists()) return null;
  if (await f.length() > maxBytes) throw const _TooLarge();
  return _Picked(path.trim().split(Platform.pathSeparator).last,
      await f.readAsBytes());
}

class _TooLarge implements Exception {
  const _TooLarge();
}

Future<String?> _pickPathOnDesktop() async {
  switch (defaultTargetPlatform) {
    case TargetPlatform.windows:
      return _run('powershell', [
        '-NoProfile',
        '-Sta',
        '-Command',
        _winScript,
      ]);
    case TargetPlatform.linux:
      return _run('zenity', [
        '--file-selection',
        '--title=APRSlocus',
        '--file-filter=Images (png/jpg/webp/svg) | *.png *.jpg *.jpeg *.webp *.gif *.bmp *.svg',
        '--file-filter=All files | *',
      ]);
    case TargetPlatform.macOS:
      return _run('osascript', [
        '-e',
        'try',
        '-e',
        'POSIX path of (choose file with prompt "APRSlocus")',
        '-e',
        'end try',
      ]);
    default:
      return null;
  }
}

Future<String?> _run(String exe, List<String> args) async {
  final r = await Process.run(exe, args, stdoutEncoding: utf8);
  return '${r.stdout}';
}

const String _winScript = r'''
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Add-Type -AssemblyName System.Windows.Forms | Out-Null
$d = New-Object System.Windows.Forms.OpenFileDialog
$d.Title = 'APRSlocus'
$d.Filter = 'Images (png/jpg/webp/svg)|*.png;*.jpg;*.jpeg;*.webp;*.gif;*.bmp;*.svg|All files (*.*)|*.*'
$d.CheckFileExists = $true
if ($d.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
  [Console]::Out.Write($d.FileName)
}
''';

/// 按**魔数**判断格式，而不是看扩展名。
///
/// 用户把 logo.jpg 改名成 logo.png 是常事；按扩展名判断的话，我们会对着一堆
/// JPEG 字节调用 PNG 解码器，结果是「导入成功但显示不出来」——
/// 这种「成功却没用」最难排查。按内容判断则当场给出「格式不支持」。
String? _detectFormat(Uint8List b) {
  bool at(int i, List<int> sig) {
    if (b.length < i + sig.length) return false;
    for (var k = 0; k < sig.length; k++) {
      if (b[i + k] != sig[k]) return false;
    }
    return true;
  }

  if (at(0, [0x89, 0x50, 0x4E, 0x47])) return 'png';
  if (at(0, [0xFF, 0xD8, 0xFF])) return 'jpg';
  if (at(0, [0x47, 0x49, 0x46, 0x38])) return 'gif';
  if (at(0, [0x42, 0x4D])) return 'bmp';
  // WebP: "RIFF" .... "WEBP"
  if (at(0, [0x52, 0x49, 0x46, 0x46]) && at(8, [0x57, 0x45, 0x42, 0x50])) {
    return 'webp';
  }
  // SVG 没有魔数：只能看是不是 XML/SVG 文本
  final head = String.fromCharCodes(
    b.length > 512 ? b.sublist(0, 512) : b,
  ).trimLeft();
  if (head.startsWith('<svg') ||
      (head.startsWith('<?xml') && head.contains('<svg'))) {
    return 'svg';
  }
  return null;
}

/// FNV-1a 32 位：这里只需要「内容变则名字变、内容同则名字同」，
/// 不涉及安全性，因而不引 crypto 依赖（少一个依赖少一处构建风险）。
String _fnv1a(List<int> bytes) {
  var h = 0x811C9DC5;
  for (final b in bytes) {
    h ^= b & 0xFF;
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  return h.toRadixString(16).padLeft(8, '0');
}

/// 渲染一个已导入的图片文件（图标与背景通用）。
///
/// 路径解析是**同步**的（用已缓存好的目录），这样渲染路径上不用 await。
/// 文件不在 / 目录未就绪 / 渲染失败一律返回 null，由调用方回退 ——
/// **图片坏掉不该让界面跟着坏**。
Widget? buildFileImage(
  String ref, {
  double? size,
  BoxFit fit = BoxFit.contain,
  Widget Function()? fallback,
}) {
  if (!ref.startsWith('file:')) return null;
  final name = ref.substring(5);
  if (!_isSafeName(name)) return null;
  final path = _pathFor(name);
  if (path == null) return null;
  if (name.toLowerCase().endsWith('.svg')) {
    return SvgPicture.file(
      File(path),
      width: size,
      height: size,
      fit: fit,
      // SVG 失败（文件损坏/被删）不能变红屏
      errorBuilder: (_, _, _) => fallback?.call() ?? const SizedBox.shrink(),
    );
  }
  return Image.file(
    File(path),
    width: size,
    height: size,
    fit: fit,
    // 不 tint：用户导入的是成品图（常为彩色 logo 或照片），
    // 强行染色会把图变成单色块。内置图标则会跟随主题色。
    errorBuilder: (_, _, _) => fallback?.call() ?? const SizedBox.shrink(),
  );
}

/// 在已解析的目录里找这个文件名；两个目录都查（图标 / 背景）
String? _pathFor(String name) {
  for (final dir in const [kIconDirName, kBackgroundDirName]) {
    final d = _dirs[dir];
    if (d == null) continue;
    final p = '${d.path}${Platform.pathSeparator}$name';
    if (File(p).existsSync()) return p;
  }
  return null;
}

/// 渲染一个已导入的**图标**
Widget? buildFileIcon(
  String storedName, {
  required double size,
  required Widget Function() fallback,
}) =>
    buildFileImage('file:$storedName', size: size, fallback: fallback);

/// 背景层绘制。
///
/// 单独一个入口是因为**平铺**没法用 Image 组件表达（它只有 BoxFit）——
/// 要平铺必须走 DecorationImage 的 ImageRepeat。SVG 不支持平铺，
/// 回退成铺满，而不是给用户一个空白的背景。
Widget? buildBackgroundLayer(
  String ref, {
  required BoxFit fit,
  required bool tile,
  required Widget Function() fallback,
}) {
  if (tile) {
    if (!ref.startsWith('file:')) return null;
    final name = ref.substring(5);
    if (!_isSafeName(name)) return null;
    final path = _pathFor(name);
    if (path == null) return null;
    if (!name.toLowerCase().endsWith('.svg')) {
      return Image.file(
        File(path),
        fit: BoxFit.none,
        repeat: ImageRepeat.repeat,
        errorBuilder: (_, _, _) => fallback(),
      );
    }
  }
  return buildFileImage(ref, fit: fit, fallback: fallback);
}

/// 是否已就绪（至少一个目录可用）。store 用它决定要不要 bump 版本重渲染。
bool get iconStoreReady => _dirs.isNotEmpty;

/// 预热：把两个目录都建好。store 在启动时调用一次。
Future<void> warmImageStore() async {
  await _ensureDir(kIconDirName);
  await _ensureDir(kBackgroundDirName);
}
