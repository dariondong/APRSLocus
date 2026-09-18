import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// 地图瓦片磁盘缓存（io 平台实现）。
///
/// 目录结构：`<应用支持目录>/tilecache/<图源>/<z>/<x>/<y>.tile`
///
/// 设计要点（每条都是「换个写法就会真出问题」）：
///
/// 1. **缓存键必须含图源**。同一个 z/x/y 在不同图源下是不同内容的图，
///    共用一份缓存会让「切图源」这种操作静默显示上一个图源的瓦片。
///
/// 2. **缓存命中也要认字节**。有些图源（某些国内服务）会对不存在的瓦片
///    返回一个很小的「空白占位图」；把它当有效结果存下来，之后这块区域
///    在**在线**时也会一直显示空白，比不缓存更坏。所以只接受已知图片
///    魔数的字节（见 [looksLikeImage]）。
///
/// 3. **内存里保留同一份 Uint8List 实例**。Flutter 的 `MemoryImage` 相等性
///    比较的是 `bytes` 的**同一性**（identity），每次读盘都 new 一份数组的话，
///    ImageCache 无法命中，平移一下同一块瓦片会被解码 N 次。所以这里做一层
///    小 LRU 并返回**同一个实例**。
///
/// 4. **不缓存 HTML/JSON 错误页**，理由同上（status 200 + text/html 很常见）。
class TileCacheImpl {
  TileCacheImpl._();

  /// 初始化并返回真正的缓存目录（Web 无此概念）
  static Future<void> ensureInit() async {
    if (_dir != null) return;
    final base = await getApplicationSupportDirectory();
    final d = Directory('${base.path}${Platform.pathSeparator}tilecache');
    if (!await d.exists()) {
      await d.create(recursive: true);
    }
    _dir = d;
  }

  static Directory? _dir;

  /// 缓存可用（目录已就绪）
  static bool get available => _dir != null;

  /// 缓存根目录（未初始化时抛错，调用方应先 ensureInit）
  static Directory get root {
    final d = _dir;
    if (d == null) throw StateError('tilecache-not-initialized');
    return d;
  }

  static final Map<String, File> _fileCache = {};
  static final Map<String, Uint8List> _mem = {};
  static final List<String> _memOrder = [];
  static const int _memMax = 320;

  static String _key(String source, int z, int x, int y) =>
      '$source/$z/$x/$y';

  static File _file(String source, int z, int x, int y) {
    final k = _key(source, z, x, y);
    final cached = _fileCache[k];
    if (cached != null) return cached;
    final f = File('${root.path}${Platform.pathSeparator}'
        '${source.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_')}'
        '${Platform.pathSeparator}$z${Platform.pathSeparator}$x'
        '${Platform.pathSeparator}$y.tile');
    if (_fileCache.length > 4000) _fileCache.clear();
    _fileCache[k] = f;
    return f;
  }

  static void _remember(String k, Uint8List bytes) {
    _mem[k] = bytes;
    _memOrder.remove(k);
    _memOrder.add(k);
    while (_memOrder.length > _memMax) {
      final old = _memOrder.removeAt(0);
      _mem.remove(old);
    }
  }

  /// 读缓存。命中返回字节，未命中返回 null。
  static Future<Uint8List?> get(String source, int z, int x, int y) async {
    if (!available) return null;
    final k = _key(source, z, x, y);
    final hit = _mem[k];
    if (hit != null) return hit;
    try {
      final f = _file(source, z, x, y);
      if (!await f.exists()) return null;
      final bytes = await f.readAsBytes();
      // 目录里可能残留旧版本写入的坏数据（例如早期误存的 HTML/占位图）
      if (!looksLikeImage(bytes)) return null;
      _remember(k, bytes);
      return bytes;
    } catch (_) {
      return null;
    }
  }

  /// 写缓存（只写合法图片字节）。返回是否真的写入。
  static Future<bool> put(
      String source, int z, int x, int y, Uint8List bytes) async {
    if (!available) return false;
    if (!looksLikeImage(bytes)) return false;
    try {
      final f = _file(source, z, x, y);
      final dir = f.parent;
      if (!await dir.exists()) await dir.create(recursive: true);
      // 先写临时文件再改名：下载途中断电/被杀不会留下半张图
      // （半张图能被 Image 解码出一半内容，但看起来像「这块地图坏了」）
      final tmp = File('${f.path}.part');
      await tmp.writeAsBytes(bytes, flush: true);
      await tmp.rename(f.path);
      _remember(_key(source, z, x, y), bytes);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 删除单个瓦片（删除离线区域时用；不存在也算成功）
  ///
  /// 删除区域必须这样**逐张删**，不能图省事按 `图源/z` 整目录删 —— 那会顺带
  /// 删掉邻居区域已下载的瓦片，属于「删一个区域，坏另一个区域」的隐形破坏。
  static Future<void> remove(String source, int z, int x, int y) async {
    if (!available) return;
    final k = _key(source, z, x, y);
    _mem.remove(k);
    _memOrder.remove(k);
    try {
      final f = _file(source, z, x, y);
      if (await f.exists()) await f.delete();
      // 临时文件也要清（上次写入中途退出留下的）
      final tmp = File('${f.path}.part');
      if (await tmp.exists()) await tmp.delete();
    } catch (_) {}
  }

  /// 统计：瓦片张数与总字节数
  static Future<(int, int)> stats() async {
    if (!available) return (0, 0);
    var count = 0;
    var bytes = 0;
    try {
      await for (final e in root.list(recursive: true, followLinks: false)) {
        if (e is File && e.path.endsWith('.tile')) {
          count++;
          try {
            bytes += await e.length();
          } catch (_) {}
        }
      }
    } catch (_) {}
    return (count, bytes);
  }

  /// 清空全部缓存（连同遗留的临时文件）
  static Future<void> clear() async {
    if (!available) return;
    _mem.clear();
    _memOrder.clear();
    _fileCache.clear();
    try {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    } catch (_) {}
    try {
      await root.create(recursive: true);
    } catch (_) {}
  }
}

/// 字节是否是已知图片格式（PNG / JPEG / GIF / WebP / BMP）。
///
/// 只看魔数，不解码 —— 目的是把「服务器返回的 HTML 错误页 / 空白占位 PNG」
/// 挡在缓存之外。注意：空白占位 PNG **也是**合法 PNG，这里挡不住；
/// 那种情况由下载引擎按「体积过小」另行判定。
bool looksLikeImage(Uint8List b) {
  if (b.length < 12) return false;
  // PNG: 89 50 4E 47
  if (b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) return true;
  // JPEG: FF D8 FF
  if (b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) return true;
  // GIF: GIF8
  if (b[0] == 0x47 && b[1] == 0x49 && b[2] == 0x46 && b[3] == 0x38) return true;
  // WebP: RIFF....WEBP
  if (b[0] == 0x52 &&
      b[1] == 0x49 &&
      b[2] == 0x46 &&
      b[3] == 0x46 &&
      b[8] == 0x57 &&
      b[9] == 0x45 &&
      b[10] == 0x42 &&
      b[11] == 0x50) {
    return true;
  }
  // BMP: BM
  if (b[0] == 0x42 && b[1] == 0x4D) return true;
  return false;
}
