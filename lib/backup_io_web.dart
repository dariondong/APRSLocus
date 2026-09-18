/// 备份文件读写的 Web 变体：浏览器里没有可用的文件系统路径与原生对话框，
/// 而且本应用在 Web 上也不写「下载目录」。所以这里一律回 unsupported，
/// 由 UI 提示改用「复制到剪贴板 / 从剪贴板粘贴」。
///
/// 说明：为了少维护一套类型，这里直接复用 io 变体里定义的数据类型
/// （它们本身不碰 dart:io），只把两个入口做成「不支持」。
class PickedBackup {
  final String name;
  final String content;

  const PickedBackup(this.name, this.content);
}

enum BackupPickError { cancelled, unsupported, tooLarge, readFailed }

class BackupPickResult {
  final PickedBackup? file;
  final BackupPickError? error;

  const BackupPickResult.ok(PickedBackup this.file) : error = null;
  const BackupPickResult.fail(BackupPickError this.error) : file = null;

  bool get isOk => file != null;
}

Future<BackupPickResult> pickBackupFile() async =>
    const BackupPickResult.fail(BackupPickError.unsupported);

Future<String?> saveBackupFile(
  String filename,
  String content, {
  String mimeType = 'application/json',
}) async =>
    null;
