// 音频（WAV）导出/导入的平台实现（条件导入）
//   - io 平台：Android 走 MediaStore（原生通道），桌面写「下载」目录
//   - Web：不支持（返回 unsupported，由 UI 提示）
//
// 与 `net/audio_file*.dart`（按路径读写 WAV 内容）分开：那个管「读写字节」，
// 这个管「在 Android 上拿到一个**用户能找到**的位置」—— 移动端这两件事
// 完全不同（后者不能按路径写）。
import 'audio_export_base.dart';
import 'audio_export_stub.dart'
    if (dart.library.io) 'audio_export_io.dart' as impl;

export 'audio_export_base.dart';

/// 保存 WAV 字节；返回用户可见的路径（失败时带错误描述）
Future<AudioExportResult> saveAudioBytes(String filename, List<int> bytes) =>
    impl.saveAudioBytes(filename, bytes);

/// 默认保存路径（供桌面输入框预填）；Android 只返回文件名
Future<String> defaultAudioPath(String filename) =>
    impl.defaultAudioPath(filename);

/// 让用户挑一个 WAV 并读回字节；取消 / 平台不支持返回 null
Future<(String, List<int>)?> pickAudioBytes() => impl.pickAudioBytes();
