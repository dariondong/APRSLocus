import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:aprslocus/garmin.dart';

/// 佳明 LiveTrack 链接识别 + 解析的回归。
///
/// ── 为什么国区（中国大陆）必须单独钉住 ──
/// 佳明的账号体系分**国际区**与**国区**两套服务器：国际区的分享页在
/// `livetrack.garmin.com`，国区在 `livetrack.garmin.cn`。只认 `.com` 的老代码，
/// 对国区用户是**静默无效**：点完分享，界面上只是「没有找到 LiveTrack 链接」，
/// 完全看不出是「链接的域名不在白名单里」这件事。
///
/// 这里同时钉住三条容易被改回去的路：
///   * `.cn` 长链（国区 App 分享出来的正牌形态）；
///   * **没有 scheme** 的国区链接（聊天窗口里复制出来常常没有 `https://`）；
///   * 「整篇文档找 trackPoints」的兜底（国区/老版分享页不是 Next.js 的
///     `self.__next_f.push` 形态 —— 只有那条路的话就会「页面上有点、应用里一个都没有」）。
void main() {
  const uuid = '1debb03f-2acd-48b0-a8c9-2ba613bfcb3c';
  const token = '5B72E4867D3AE6EB4B3D11F612044D8';

  group('extractLiveTrackUrl', () {
    test('国际区长链', () {
      final u = 'https://livetrack.garmin.com/session/$uuid/token/$token';
      expect(extractLiveTrackUrl(u), u);
    });

    test('国区长链（livetrack.garmin.cn）', () {
      final u = 'https://livetrack.garmin.cn/session/$uuid/token/$token';
      expect(extractLiveTrackUrl(u), u);
    });

    test('国区长链：混在整段分享文案里也能抠出来', () {
      final u = 'https://livetrack.garmin.cn/session/$uuid/token/$token';
      final text = '我正在用 Garmin 分享实时位置，点击查看：$u 快来围观～';
      expect(extractLiveTrackUrl(text), u);
    });

    test('国区长链：只差 scheme 也要认（补 https://）', () {
      expect(
        extractLiveTrackUrl('livetrack.garmin.cn/session/$uuid/token/$token'),
        'https://livetrack.garmin.cn/session/$uuid/token/$token',
      );
    });

    test('带 scheme 的链接不会被再套一层 https://（负向断言）', () {
      final u = 'https://livetrack.garmin.cn/session/$uuid/token/$token';
      final got = extractLiveTrackUrl(u);
      expect(got, u);
      expect(got!.startsWith('https://https://'), isFalse);
    });

    test('其它国区佳明页面（兜底收下，失败要可见）', () {
      expect(
        extractLiveTrackUrl('https://www.garmin.com.cn/products/apps/Garmin_Connect_Mobile'),
        'https://www.garmin.com.cn/products/apps/Garmin_Connect_Mobile',
      );
      expect(
        extractLiveTrackUrl('https://connect.garmin.cn/modern/activity/123'),
        'https://connect.garmin.cn/modern/activity/123',
      );
    });

    test('佳明 App 的短链 gar.mn（含无 scheme 形态）', () {
      expect(extractLiveTrackUrl('https://gar.mn/3nN1LAZebB'),
          'https://gar.mn/3nN1LAZebB');
      expect(extractLiveTrackUrl('gar.mn/3nN1LAZebB'), 'https://gar.mn/3nN1LAZebB');
    });

    test('无关文本返回 null', () {
      expect(extractLiveTrackUrl('今天天气不错'), isNull);
      expect(extractLiveTrackUrl('https://example.com/session/x/token/y'), isNull);
    });
  });

  group('parseTrackPoints', () {
    const point =
        '{"position":{"lat":23.05,"lon":113.39},"dateTime":"2026-01-02T03:04:05.000Z",'
        '"altitude":32.8,"speedMetersPerSec":3.5,"heartRateBeatsPerMin":128}';

    test('Next.js 流式块（国际区现有形态，防回归）', () {
      // 流式块里的负载是**再转义一层**的 JSON 字符串，手工拼很容易少转义一层
      // （jsonDecode 失败 → 一个点都解析不出来）。这里用 jsonEncode 拼，保证合法。
      final inner = '{"trackPoints":[$point]}';
      final doc = '<script>self.__next_f.push([1,${jsonEncode(inner)}])</script>';
      final pts = parseTrackPoints(doc);
      expect(pts.length, 1);
      expect(pts.first.lat, closeTo(23.05, 1e-9));
      expect(pts.first.hr, 128);
    });

    test('整篇文档兜底（国区/老版页面不是 Next.js 形态）', () {
      final doc = '<html><body><script>window.__DATA__ = {"trackPoints":[$point]};'
          '</script></body></html>';
      final pts = parseTrackPoints(doc);
      expect(pts.length, 1);
      expect(pts.first.lng, closeTo(113.39, 1e-9));
      expect(pts.first.altM, closeTo(32.8, 1e-9));
    });

    test('没有点时不抛异常，返回空列表', () {
      expect(parseTrackPoints('<html>什么都没有</html>'), isEmpty);
      expect(parseTrackPoints('<script>self.__next_f.push([1,"{}"])</script>'),
          isEmpty);
    });
  });

  group('maskLiveTrackUrl', () {
    test('token 打码（分享链接本身就是位置凭据）', () {
      final m = maskLiveTrackUrl(
          'https://livetrack.garmin.cn/session/$uuid/token/$token');
      expect(m.contains(token), isFalse);
      expect(m.contains('/token/5B72E486…'), isTrue);
    });
  });
}
