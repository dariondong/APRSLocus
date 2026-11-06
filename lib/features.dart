/// ─── 自选模块 ───
///
/// 应用一开始是个 APRS 收发工具。后来长出来的排行榜、荣誉墙、赞助、翻译、
/// 轨迹、ADIF 这些模块，对一部分人是加分项，对只想收发的另一部分人只是噪声。
/// 所以每个模块都能单独关掉，关掉之后设置页里不再出现那个入口。
///
/// **偏好里存的是「关掉的」而不是「打开的」**。默认全开 —— 第一次装上这一版的
/// 用户什么都不用做；将来新增模块也是默认打开，不会因为旧偏好里没有那个键就
/// 悄悄消失。写成「打开的集合」正好相反：老用户的偏好里没有新模块的 id，
/// 新功能装完就不见了，而这种 bug 只有被人问「入口哪去了」时才会暴露。
library;

/// 一个可自选的模块。
///
/// [id] 是写进偏好的字符串，**不能改** —— 改了等于把所有用户的这个开关重置，
/// 而重置之后他们看到的只是「怎么又冒出来了」，不会知道是改名的关系。
enum AppFeature {
  rank('rank'),
  honor('honor'),
  sponsor('sponsor'),
  lifeGuard('lifeGuard'),
  translate('translate'),
  tracks('tracks'),
  adif('adif'),
  cloudSync('cloudSync');

  const AppFeature(this.id);
  final String id;
}

/// 认不出的 id 返回 null（偏好里可能留着已经删掉的模块）。
AppFeature? appFeatureById(String id) {
  for (final f in AppFeature.values) {
    if (f.id == id) return f;
  }
  return null;
}
