import 'dart:io';

/// io 平台：直接读写文件（桌面/Android 的 WAV 导入导出）
Future<List<int>?> readAudioFile(String path) async {
  try {
    final f = File(path);
    if (!await f.exists()) return null;
    return await f.readAsBytes();
  } catch (_) {
    return null;
  }
}

Future<String?> writeAudioFile(String path, List<int> bytes) async {
  try {
    await File(path).writeAsBytes(bytes, flush: true);
    return null;
  } catch (e) {
    return '$e';
  }
}
