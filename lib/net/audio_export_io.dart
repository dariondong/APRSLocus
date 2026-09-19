/// 音频（WAV）导出与导入的平台实现（io 变体：Android / Windows / Linux / macOS）
///
/// 与 `backup_io.dart` 同一套思路，但这里处理的是**二进制**：
///   * 导出：Android 走原生通道写「下载/APRSlocusAudio」（MediaStore，免存储权限），
///     桌面写系统「下载」目录（取不到就退到文档目录）；
///   * 导入：Android 复用已有的 `pickBinaryFile`（系统文件选择器，base64 回传），
///     桌面返回 null，由上层用路径输入框（桌面用户本来就习惯填路径）。
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/services.dart' show MethodChannel, PlatformException;
import 'package:path_provider/path_provider.dart';

import 'audio_export_base.dart';

const _exportChannel = MethodChannel('com.aprslocus/export');

/// 把一段 WAV 字节保存到用户能找到的位置。
///
/// 为什么不让用户手打路径：Android 上「手打路径」本身就不可行 ——
/// 应用没有写任意路径的权限，能写的只有 MediaStore（下载目录）或应用私有
/// 目录，而私有目录用户根本看不见。所以移动端一律走系统「保存到下载目录」，
/// 由系统决定最终落点，再把真实路径显示出来。
Future<AudioExportResult> saveAudioBytes(
  String filename,
  List<int> bytes,
) async {
  if (defaultTargetPlatform == TargetPlatform.android) {
    try {
      final path = await _exportChannel.invokeMethod<String>(
        'saveBytesToDownloads',
        {
          'filename': filename,
          'base64': base64Encode(bytes),
          'mimeType': 'audio/wav',
        },
      );
      if (path == null || path.isEmpty) {
        return const AudioExportResult.fail('save-failed');
      }
      return AudioExportResult.ok(path);
    } on PlatformException catch (e) {
      return AudioExportResult.fail(e.code);
    } catch (e) {
      return AudioExportResult.fail('$e');
    }
  }
  try {
    final dir = await _desktopDir();
    final f = File('${dir.path}${Platform.pathSeparator}$filename');
    await f.writeAsBytes(bytes, flush: true);
    return AudioExportResult.ok(f.path);
  } catch (e) {
    return AudioExportResult.fail('$e');
  }
}

/// 桌面端的默认保存目录：优先系统「下载」，取不到再退到文档目录。
Future<Directory> _desktopDir() async {
  try {
    final d = await getDownloadsDirectory();
    if (d != null) return d;
  } catch (_) {}
  return getApplicationDocumentsDirectory();
}

/// 默认 WAV 路径（供桌面输入框预填）；Android 只返回文件名
Future<String> defaultAudioPath(String filename) async {
  if (defaultTargetPlatform == TargetPlatform.android) return filename;
  try {
    final dir = await _desktopDir();
    return '${dir.path}${Platform.pathSeparator}$filename';
  } catch (_) {
    return filename;
  }
}

/// 让用户挑一个 WAV 文件，返回 (文件名, 字节)。取消 / 平台不支持返回 null。
///
/// Android 走系统文件选择器（复用主题图标那条 pickBinaryFile 通道）；
/// 桌面返回 null，由上层提示「请填路径」。
Future<(String, List<int>)?> pickAudioBytes() async {
  if (defaultTargetPlatform != TargetPlatform.android) return null;
  try {
    final r = await _exportChannel
        .invokeMapMethod<String, dynamic>('pickBinaryFile', {
      'maxBytes': kAudioImportMaxBytes,
    }).timeout(const Duration(minutes: 5));
    if (r == null) return null; // 用户取消
    final b64 = '${r['data'] ?? ''}';
    if (b64.isEmpty) return null;
    return ('${r['name'] ?? 'audio.wav'}', base64Decode(b64));
  } on PlatformException {
    return null;
  } catch (_) {
    return null;
  }
}
