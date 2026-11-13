import 'package:flutter_test/flutter_test.dart';

import 'package:aprslocus/markdown_view.dart';

/// 公告里的 `@video` 内嵌块按 URL 形状定尺寸（见 `embedSize`）。
///
/// 三件事钉住：视频按 16:9、网易云外链是 330×86、OA 活动小件是 148 高的横条。
/// 最后一档是这次的改动 —— 公告里嵌进 OA 倒计时小件，它的设计高度是 148，
/// 套进 16:9 会变成一块带黑边的空屏。
void main() {
  test('视频按 16:9', () {
    final s = embedSize('https://player.bilibili.com/player.html?bvid=BV1', 560);
    expect(s.width, 560);
    expect(s.height, closeTo(315, 0.01));
  });

  test('窄屏下视频也不低于 72 高', () {
    final s = embedSize('https://player.bilibili.com/player.html?bvid=BV1', 60);
    expect(s.width, 60);
    expect(s.height, 72);
  });

  test('网易云外链是 330×86 的一条', () {
    final s = embedSize(
        'https://music.163.com/outchain/player?type=2&id=1', 560);
    expect(s.width, 560);
    // 560 × 86 / 330 ≈ 146
    expect(s.height, closeTo(560 * 86 / 330, 0.01));
  });

  test('OA 活动小件是 148 高的横条，不吃 16:9', () {
    final s = embedSize('https://aprsnet.cn/oa/embed.html', 560);
    expect(s.width, 560);
    expect(s.height, kEmbedOaH);
    expect(s.height, 148);
  });

  test('窄屏下 OA 小件仍按 148', () {
    final s = embedSize('https://aprsnet.cn/oa/embed.html', 360);
    expect(s.width, 360);
    expect(s.height, 148);
  });

  test('最宽不超过 560', () {
    for (final url in <String>[
      'https://player.bilibili.com/player.html?bvid=BV1',
      'https://aprsnet.cn/oa/embed.html',
    ]) {
      expect(embedSize(url, 1200).width, kEmbedMaxW);
    }
  });
}
