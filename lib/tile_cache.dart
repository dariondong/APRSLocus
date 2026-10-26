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

/// 内存里的瓦片字节缓存（所有平台都有，包括 Web）。
///
/// 为什么需要：缩放每跨一级，整片瓦片会全部重建 —— 磁盘缓存也算一次异步往返，
/// 于是缩放的每一档都能看到「整片闪一下、重新长出来」。而这一级的图往往刚画过：
/// 缩放会来回跨层级，走的就是刚才那些瓦片。同步命中内存就不会闪。
///
/// 只存**原始字节**（不解码，Flutter 自己的 ImageCache 管解码），
/// 条数封顶，按插入顺序做 LRU，不占多少内存。
class TileMem {
  TileMem._();

  /// 封顶条数：256² 的 PNG 一般 10–40 KB，320 张大约 4–12 MB。
  ///
  /// 为什么不是 160：手机一块屏在 dpr 2~3 下就有 60~80 张瓦片，两层就把
  /// 160 条顶满 —— 子瓦片/父瓦片被挤掉，缩小或放大就只剩白屏。
  static const int maxEntries = 320;

  static final Map<String, Uint8List> _m = <String, Uint8List>{};

  static String _key(String src, int z, int x, int y) => '$src/$z/$x/$y';

  /// 同步取字节；命中时把它挪到最新（LRU）
  static Uint8List? get(String src, int z, int x, int y) {
    final k = _key(src, z, x, y);
    final v = _m.remove(k);
    if (v == null) return null;
    _m[k] = v;
    return v;
  }

  static void put(String src, int z, int x, int y, Uint8List bytes) {
    if (bytes.isEmpty) return;
    final k = _key(src, z, x, y);
    _m.remove(k);
    _m[k] = bytes;
    while (_m.length > maxEntries) {
      _m.remove(_m.keys.first);
    }
  }

  static void clear() => _m.clear();
}
