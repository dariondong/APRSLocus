import 'dart:typed_data';

/// Web 兜底：浏览器里没有「应用可写目录」，拿不到稳定的瓦片缓存目录
/// （IndexedDB 能存，但需要另一套异步存储与容量配额管理，收益与复杂度不成正比）。
///
/// 因此 Web 上缓存整条链路都安全降级为「不缓存、不提供离线下载」：
/// 下载入口在界面上隐藏，读取一律未命中并回落到网络瓦片。
/// 关键是不能抛错 —— 否则一次 build 就会让地图整块白屏。
class TileCacheImpl {
  TileCacheImpl._();

  static Future<void> ensureInit() async {}

  static bool get available => false;

  static Future<Uint8List?> get(String source, int z, int x, int y) async =>
      null;

  static Future<bool> put(
          String source, int z, int x, int y, Uint8List bytes) async =>
      false;

  static Future<void> remove(String source, int z, int x, int y) async {}

  static Future<(int, int)> stats() async => (0, 0);

  static Future<void> clear() async {}
}

/// 供离线下载引擎复用（Web 上不会被调用，但保持与 io 实现同一份逻辑）
bool looksLikeImage(Uint8List b) {
  if (b.length < 12) return false;
  if (b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) return true;
  if (b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) return true;
  if (b[0] == 0x47 && b[1] == 0x49 && b[2] == 0x46 && b[3] == 0x38) return true;
  return false;
}
