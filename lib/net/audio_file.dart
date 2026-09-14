// WAV 文件读写（「音频」数据来源的文件模式）
//
// 与 `net/aprs*.dart` / `net/exit_app*.dart` 同一套条件导入约定：
//   - io 平台：dart:io 读写真实文件
//   - Web：没有文件系统，返回不支持（UI 会给出提示）
import 'audio_file_stub.dart'
    if (dart.library.io) 'audio_file_io.dart' as impl;

/// 读取整个 WAV 文件的字节；失败返回 null
Future<List<int>?> readAudioFile(String path) => impl.readAudioFile(path);

/// 写出 WAV 文件；成功返回 null，否则返回错误描述
Future<String?> writeAudioFile(String path, List<int> bytes) =>
    impl.writeAudioFile(path, bytes);
