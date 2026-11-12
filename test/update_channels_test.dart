/// 官网下发的更新渠道清单：解析与兜底的回归测试。
///
/// 这条路上错了**不会报错**，只会表现成「更新页少一条渠道」「选了镜像却连不上」
/// 或者「官网配置写坏以后再也没有更新」—— 所以把解析规则钉在这里，
/// 顺带把官网那份 `docs/assets/update_channels.json` 与客户端内置兜底对齐：
/// 两者不一致时，拉不到官网的用户就没有可用的默认渠道。
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:aprslocus/update_channels.dart';

void main() {
  group('解析', () {
    test('空 / 坏数据一律退回内置清单', () {
      for (final bad in [
        null,
        '',
        '   ',
        'not json',
        '[]',
        '{"channels": []}',
        '{"channels": [{"id": "x", "base": "ftp://nope"}]}',
      ]) {
        final cfg = UpdateChannelConfig.parse(bad);
        expect(cfg.channels.length, kFallbackChannels.length, reason: '$bad');
        expect(cfg.resolvedDefault, kFallbackChannelId);
      }
    });

    test('顺序、默认与地址都按官网那份来', () {
      const text = '''
{"default":"b","channels":[
  {"id":"a","name":"A","base":"https://a.example/api/"},
  {"id":"b","name":"B","base":"https://b.example"}
]}''';
      final cfg = UpdateChannelConfig.parse(text);
      expect(cfg.channels.map((c) => c.id).toList(), ['a', 'b']);
      expect(cfg.resolvedDefault, 'b');
      // 末尾斜杠去掉，否则拼出来是 //DarionDong
      expect(cfg.channels.first.base, 'https://a.example/api');
      // 没给 host 就取 URL 的主机名
      expect(cfg.channels.first.displayHost, 'a.example');
      expect(cfg.byId('b')?.name, 'B');
      expect(cfg.byId('nope'), isNull);
    });

    test('默认写错时用第一条，不至于没有默认', () {
      const text = '''
{"default":"ghost","channels":[{"id":"a","base":"https://a.example"}]}''';
      final cfg = UpdateChannelConfig.parse(text);
      expect(cfg.resolvedDefault, 'a');
    });

    test('不合法的条目跳过，name 缺省用 id', () {
      final list = parseChannelList(jsonDecode('''
{"channels":[
  {"id":"","base":"https://a.example"},
  {"id":"nobase"},
  {"id":"bad","base":"javascript:alert(1)"},
  {"id":"ok","base":"https://ok.example"},
  {"id":"ok","base":"https://dup.example"}
]}'''));
      expect(list, isNotNull);
      expect(list!.map((c) => c.id).toList(), ['ok']);
      expect(list.first.name, 'ok');
    });

    test('最多收八条，官网刷满也不至于糊满屏', () {
      final many = {
        'channels': [
          for (var i = 0; i < 20; i++)
            {'id': 'c$i', 'base': 'https://c$i.example'},
        ],
      };
      final list = parseChannelList(many);
      expect(list!.length, kMaxChannels);
    });
  });

  group('内置兜底与官网那份一致', () {
    test('docs/assets/update_channels.json', () {
      final f = File('docs/assets/update_channels.json');
      expect(f.existsSync(), isTrue,
          reason: '官网那份渠道清单不在仓库里（docs/assets/）');
      final cfg = UpdateChannelConfig.parse(f.readAsStringSync());
      // 数量与顺序
      expect(cfg.channels.map((c) => c.id).toList(),
          kFallbackChannels.map((c) => c.id).toList());
      // 每条的主机名一致：地址改了却忘了改兜底，拉不到官网的用户就连不上
      for (final c in cfg.channels) {
        final fb = kFallbackChannels.firstWhere((x) => x.id == c.id);
        expect(c.base, fb.base, reason: '${c.id} 的地址与内置兜底不一致');
      }
      expect(cfg.resolvedDefault, kFallbackChannelId);
    });
  });
}
