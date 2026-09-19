/// 音频（WAV）导出/导入的平台无关部分：结果类型与公共常量。
///
/// 与 `net/audio_base.dart` 同一套分层：本文件只有接口与数据类型，
/// 具体实现在 `audio_export_io.dart` / `audio_export_stub.dart` 里，
/// 由 `audio_export.dart` 条件导入。
library;

/// 导出结果：成功时带**用户可见的路径**（文件管理器里看到的那种）
class AudioExportResult {
  final String? path;
  final String? error;

  const AudioExportResult.ok(String this.path) : error = null;
  const AudioExportResult.fail(String this.error) : path = null;

  bool get isOk => path != null;
}

/// 导入 WAV 的大小上限（字节）。一段 1200bd 录音再长也就几 MB，
/// 32MB 已极宽松；上限必须在**读之前**就知道，否则误选大文件会 OOM。
const int kAudioImportMaxBytes = 32 * 1024 * 1024;
