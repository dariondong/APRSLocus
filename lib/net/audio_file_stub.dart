/// Web：无文件系统（浏览器下载/上传需 JS 互操作，本版本不实现）
library;

Future<List<int>?> readAudioFile(String path) async => null;

Future<String?> writeAudioFile(String path, List<int> bytes) async =>
    'unsupported';
