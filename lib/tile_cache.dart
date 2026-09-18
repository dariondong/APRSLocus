// 瓦片缓存工厂（条件导入）
//   - io 平台：文件系统缓存（Android / Windows / iOS / macOS / Linux）
//   - Web：不可用（不缓存、不提供离线下载），接口降级为 no-op
import 'dart:typed_data';

import 'tile_cache_io.dart' if (dart.library.html) 'tile_cache_web.dart' as impl;

/// 磁盘瓦片缓存。所有平台安全可调用（Web 上是 no-op）。
class TileCache {
  TileCache._();

  /// 初始化缓存目录；在 `main()` 里调用一次即可，重复调用无副作用。
  /// 失败（拿不到目录）不抛错：地图必须能在没有缓存的机器上正常工作。
  static Future<void> ensureInit() async {
    try {
      await impl.TileCacheImpl.ensureInit();
    } catch (_) {}
  }

  /// 缓存是否可用（Web 上恒为 false）
  static bool get available => impl.TileCacheImpl.available;

  /// 读缓存字节；未命中返回 null
  static Future<Uint8List?> get(String source, int z, int x, int y) =>
      impl.TileCacheImpl.get(source, z, x, y);

  /// 写缓存字节（只接受合法图片字节）
  static Future<bool> put(
          String source, int z, int x, int y, Uint8List bytes) =>
      impl.TileCacheImpl.put(source, z, x, y, bytes);

  /// 删除单个瓦片
  static Future<void> remove(String source, int z, int x, int y) =>
      impl.TileCacheImpl.remove(source, z, x, y);

  /// (瓦片张数, 总字节数)
  static Future<(int, int)> stats() => impl.TileCacheImpl.stats();

  /// 清空全部缓存
  static Future<void> clear() => impl.TileCacheImpl.clear();
}

/// 字节是否为已知图片格式（挡掉 HTML/JSON 错误页与占位图）
bool looksLikeImage(Uint8List b) => impl.looksLikeImage(b);
