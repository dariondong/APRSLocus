import 'package:flutter/material.dart';
import 'app.dart';
import 'tile_cache.dart';
import 'track_log.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 瓦片缓存目录就绪后再起界面：地图第一帧就能命中缓存、拿到离线瓦片
  await TileCache.ensureInit();
  // 个人历史轨迹（按天台账）目录：与瓦片缓存同理，就绪后再起界面
  await TrackLogStore.instance.ensureInit();
  runApp(const App());
}
