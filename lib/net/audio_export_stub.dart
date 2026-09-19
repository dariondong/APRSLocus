/// 音频（WAV）导出/导入的 Web 占位实现：浏览器里没有文件系统，
/// 需要 JS 互操作才能下载/上传，本版本不实现。
///
/// 一律返回「不支持」，由上层给出提示，而不是静默失败。
library;

import 'audio_export_base.dart';

Future<AudioExportResult> saveAudioBytes(
        String filename, List<int> bytes) async =>
    const AudioExportResult.fail('unsupported');

Future<String> defaultAudioPath(String filename) async => filename;

Future<(String, List<int>)?> pickAudioBytes() async => null;
