/// 主题「导入的图标文件」的 Web 变体：浏览器里既没有可写的应用目录，
/// 也没有可用的文件系统路径，所以一律「不支持」，由 UI 引导用户改用内置图标库。
///
/// 说明：本文件与 io 变体保持**完全一致的 API**（同名同签名），
/// 这样 theme_store.dart 只关心「能不能用」，不需要写平台分支。
library;

import 'package:flutter/material.dart';

bool get supportsFileIcons => false;

enum IconImportError { cancelled, unsupportedPlatform, badFormat, tooLarge, failed }

class IconImportResult {
  final String? ref;
  final String? name;
  final IconImportError? error;

  const IconImportResult.ok(String this.ref, this.name) : error = null;
  const IconImportResult.fail(IconImportError this.error)
      : ref = null,
        name = null;

  bool get isOk => ref != null;
}

const int kIconMaxBytes = 2 * 1024 * 1024;

Future<IconImportResult> importIconFromPicker() async =>
    const IconImportResult.fail(IconImportError.unsupportedPlatform);

Future<String?> iconFilePath(String storedName) async => null;

Widget? buildFileIcon(
  String storedName, {
  required double size,
  required Widget Function() fallback,
}) =>
    null;

bool get iconStoreReady => true;
