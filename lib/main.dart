import 'package:flutter/material.dart';
import 'app.dart';
import 'tile_cache.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 瓦片缓存目录就绪后再起界面：地图第一帧就能命中缓存、拿到离线瓦片
  await TileCache.ensureInit();
  runApp(const App());
}
