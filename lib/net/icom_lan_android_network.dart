// SPDX-License-Identifier: GPL-2.0-or-later
// See LICENSING.md: this file is additionally available under GPL-2.0-or-later.

library;

import 'dart:io';
import 'package:flutter/services.dart';

/// Android 平台 IC-705 Wi-Fi 网络状态快照。
class IcomLanAndroidNetworkInfo {
  const IcomLanAndroidNetworkInfo({
    required this.status,
    this.networkHandle,
    this.ipv4Address,
  });

  final String status;
  final int? networkHandle;
  final String? ipv4Address;

  bool get isAvailable => status == 'AVAILABLE';

  @override
  String toString() =>
      'IcomLanAndroidNetworkInfo(status=$status, networkHandle=$networkHandle, ipv4=$ipv4Address)';
}

/// Android 专属网络选择与适配工具（对应 mod 的 `android/Ic705AndroidNetwork.kt`）。
///
/// 当 IC-705 作为热点时，由于其无法访问互联网，Android 往往会将默认网络保持为
/// 移动数据蜂窝网络。本类通过原生平台通道查找附着的 Wi-Fi 网络及其分配到的 IPv4 地址，
/// 从而使 UDP 套接字能够精准绑定到电台所在的局域网接口。
class IcomLanAndroidNetwork {
  IcomLanAndroidNetwork._();

  static const MethodChannel channel =
      MethodChannel('com.aprslocus/ic705_network');

  /// 查找当前附着的 Wi-Fi 网络。非 Android 平台返回 null。
  static Future<IcomLanAndroidNetworkInfo?> findRadioNetwork({
    MethodChannel? overrideChannel,
  }) async {
    final activeChannel = overrideChannel ?? channel;
    if (!Platform.isAndroid && overrideChannel == null) return null;
    try {
      final res =
          await activeChannel.invokeMapMethod<String, dynamic>('findRadioNetwork');
      if (res == null) return null;
      return IcomLanAndroidNetworkInfo(
        status: res['status'] as String? ?? 'UNKNOWN',
        networkHandle: (res['networkHandle'] as num?)?.toInt(),
        ipv4Address: res['ipv4Address'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}
