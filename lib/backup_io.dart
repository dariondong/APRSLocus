import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/services.dart' show MethodChannel, PlatformException;
import 'package:path_provider/path_provider.dart';

/// 备份文件读写的平台实现（io 变体：Android / Windows / Linux / macOS）。
///
/// 为什么不引第三方 file_picker：那要新增依赖与各平台插件配置，而本项目
/// 已经有了一个「导出文本到下载目录」的原生通道（com.aprslocus/export），
/// 顺路加一个「选文件读回文本」即可；桌面侧本来就有 powershell 调用先例
/// （见 lib/net/tnc_io.dart 取 COM 口）。
class PickedBackup {
  final String name;
  final String content;

  const PickedBackup(this.name, this.content);
}

enum BackupPickError {
  /// 用户自己取消了 —— 不是错误，UI 不该弹「失败」
  cancelled,

  /// 当前平台没有可用的文件选择方式（请改用剪贴板）
  unsupported,

  /// 文件超过大小上限
  tooLarge,

  /// 读文件本身失败（权限、编码、文件被删…）
  readFailed,
}

class BackupPickResult {
  final PickedBackup? file;
  final BackupPickError? error;

  const BackupPickResult.ok(PickedBackup this.file) : error = null;
  const BackupPickResult.fail(BackupPickError this.error) : file = null;

  bool get isOk => file != null;
}

/// 备份文本大小上限，与 Android 侧 [MAX_BACKUP_BYTES] 保持一致。
const int kBackupMaxBytes = 32 * 1024 * 1024;

const _exportChannel = MethodChannel('com.aprslocus/export');

/// 让用户挑一个备份文件并读回文本。
Future<BackupPickResult> pickBackupFile() async {
  if (defaultTargetPlatform == TargetPlatform.android) {
    try {
      // 加超时：Android 在文件选择器打开时若进程被回收/重建，
      // 原生侧的 Result 会丢，Dart 这边将永远等不到回调（按钮会一直禁用）。
      final r = await _exportChannel
          .invokeMapMethod<String, dynamic>('pickTextFile')
          .timeout(const Duration(minutes: 5));
      if (r == null) {
        return const BackupPickResult.fail(BackupPickError.cancelled);
      }
      return BackupPickResult.ok(
        PickedBackup('${r['name'] ?? 'backup.json'}', '${r['content'] ?? ''}'),
      );
    } on PlatformException catch (e) {
      return BackupPickResult.fail(
        e.code == 'TOO_LARGE'
            ? BackupPickError.tooLarge
            : BackupPickError.readFailed,
      );
    } catch (_) {
      return const BackupPickResult.fail(BackupPickError.readFailed);
    }
  }
  return _pickOnDesktop();
}

/// 桌面：借助系统自带的对话框工具拿路径，再用 dart:io 读文件。
/// 拿不到工具（例如精简版 Linux 没装 zenity）就回 unsupported，让 UI 引导
/// 用户去用剪贴板，而不是装作读失败。
Future<BackupPickResult> _pickOnDesktop() async {
  String? path;
  try {
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
        path = await _runPicker('powershell', [
          '-NoProfile',
          '-Sta',
          '-Command',
          _winPickScript,
        ]);
      case TargetPlatform.linux:
        path = await _runPicker('zenity', [
          '--file-selection',
          '--title=APRSlocus',
          '--file-filter=APRSlocus backup (*.json) | *.json',
          '--file-filter=All files | *',
        ]);
      case TargetPlatform.macOS:
        path = await _runPicker('osascript', [
          '-e',
          'try',
          '-e',
          'POSIX path of (choose file with prompt "APRSlocus")',
          '-e',
          'end try',
        ]);
      default:
        return const BackupPickResult.fail(BackupPickError.unsupported);
    }
  } on ProcessException {
    return const BackupPickResult.fail(BackupPickError.unsupported);
  }
  final p = (path ?? '').trim();
  if (p.isEmpty) {
    return const BackupPickResult.fail(BackupPickError.cancelled);
  }
  try {
    final f = File(p);
    if (!await f.exists()) {
      return const BackupPickResult.fail(BackupPickError.cancelled);
    }
    if (await f.length() > kBackupMaxBytes) {
      return const BackupPickResult.fail(BackupPickError.tooLarge);
    }
    return BackupPickResult.ok(
      PickedBackup(p.split(Platform.pathSeparator).last, await f.readAsString()),
    );
  } catch (_) {
    return const BackupPickResult.fail(BackupPickError.readFailed);
  }
}

/// 跑一个「选文件」命令；用户取消时它不输出内容（stdout 为空），
/// 于是调用方按「取消」处理。命令不存在会抛 ProcessException。
Future<String?> _runPicker(String exe, List<String> args) async {
  final r = await Process.run(exe, args, stdoutEncoding: utf8);
  return '${r.stdout}';
}

/// PowerShell 的 WinForms 打开文件对话框。
///
/// 两处细节：`-Sta` 必须加（WinForms 对话框要求单线程单元，否则直接抛）；
/// 显式把输出编码设成 UTF-8，否则中文/非 ASCII 路径经管道回来会变问号。
const String _winPickScript = r'''
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Add-Type -AssemblyName System.Windows.Forms | Out-Null
$d = New-Object System.Windows.Forms.OpenFileDialog
$d.Title = 'APRSlocus'
$d.Filter = 'APRSlocus backup (*.json)|*.json|All files (*.*)|*.*'
$d.CheckFileExists = $true
if ($d.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
  [Console]::Out.Write($d.FileName)
}
''';

/// 保存备份文本：
/// - Android：走原生通道写「下载」目录（10+ 走 MediaStore，免存储权限）
/// - 桌面：写「文档」目录
/// 返回用户可见的路径；失败返回 null。
Future<String?> saveBackupFile(
  String filename,
  String content, {
  String mimeType = 'application/json',
}) async {
  if (defaultTargetPlatform == TargetPlatform.android) {
    try {
      return await _exportChannel.invokeMethod<String>('saveToDownloads', {
        'filename': filename,
        'content': content,
        'mimeType': mimeType,
      });
    } catch (_) {
      return null;
    }
  }
  try {
    final dir = await getApplicationDocumentsDirectory();
    final f = File('${dir.path}${Platform.pathSeparator}$filename');
    await f.writeAsString(content, flush: true);
    return f.path;
  } catch (_) {
    return null;
  }
}
