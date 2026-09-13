import 'package:aprslocus/translate.dart';
import 'package:flutter_test/flutter_test.dart';

/// MD5 与语言码映射回归测试
///
/// MD5 是自研实现的（仓库无 crypto 依赖），而它只服务于百度接口的
/// `sign = MD5(appid+q+salt+key)`：算错的话签名校验必然失败，
/// 表现为「百度接口永远返回 54001 签名错误」—— 所以必须用标准向量锁住。
void main() {
  group('MD5', () {
    test('标准测试向量（RFC 1321）', () {
      expect(md5Hex(''), 'd41d8cd98f00b204e9800998ecf8427e');
      expect(md5Hex('a'), '0cc175b9c0f1b6a831c399e269772661');
      expect(md5Hex('abc'), '900150983cd24fb0d6963f7d28e17f72');
      expect(md5Hex('message digest'),
          'f96b697d7cb7938d525a2f31aaf161d0');
      expect(
        md5Hex('abcdefghijklmnopqrstuvwxyz'),
        'c3fcd3d76192e4007dfb496cca67e13b',
      );
      expect(
        md5Hex('ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'),
        'd174ab98d277d9f5a5611c2c9f419d9f',
      );
      expect(
        md5Hex('1234567890123456789012345678901234567890'
            '1234567890123456789012345678901234567890'),
        '57edf4a22be3c955ac49da2e2107b67a',
      );
    });

    test('跨 64 字节分块边界（padding 逻辑）', () {
      // 55 / 56 / 57 / 64 / 119 / 120 字节分别落在 padding 的各个分支上，
      // 期望值用独立实现（Python hashlib）生成以确保不是「自证自明」
      const vectors = {
        1: '9dd4e461268c8034f5c8564e155c67a6',
        54: '61ea0974c662328da964d977a8253873',
        55: '04364420e25c512fd958a70738aa8f72',
        56: '668a72d5ba17f08e62dabcafad6db14b',
        57: '693037871c4a9d3d8685018905cb530a',
        63: '7dc2ca208106a2f703567bdff99d8981',
        64: 'c1bb4f81d892b2d57947682aeb252456',
        65: '1bc932052302d074bdec39795fe00cf6',
        119: 'ab347a5f68c8a443cfcddc633f12c24f',
        120: 'fb98667f98096de92620b64f46e1c5b5',
        128: 'd69cb61a6ee87200676eb0d4b90edbcb',
      };
      vectors.forEach((n, want) {
        expect(md5Hex('x' * n), want, reason: '$n 字节输入');
      });
    });

    test('UTF-8 多字节输入按字节计算', () {
      // '中文' 的 UTF-8 为 e4b8ad e69687（与 hashlib 结果一致）
      expect(md5Hex('中文'), 'a7bac2239fcdcb3a067903d8077c4a07');
      expect(md5Hex('中文').length, 32);
      expect(md5Hex('中文') == md5Hex('中'), isFalse);
    });

    test('百度签名形式（appid+q+salt+key）稳定且小写十六进制', () {
      // 期望值取自 hashlib；签名算错会表现为百度恒返回 54001
      expect(
        md5Hex('2024010100hello1712345678mysecretkey'),
        '3ea0b86d0aa37a0ecc59dd272b5f6225',
      );
    });
  });

  group('语言码映射', () {
    test('Google 用 zh-CN / zh-TW', () {
      expect(TransLang.toGoogle('zh'), 'zh-CN');
      expect(TransLang.toGoogle('zh-TW'), 'zh-TW');
      expect(TransLang.toGoogle('en'), 'en');
    });

    test('百度用 zh / cht / jp / kor 等方言', () {
      expect(TransLang.toBaidu('zh'), 'zh');
      expect(TransLang.toBaidu('zh-TW'), 'cht');
      expect(TransLang.toBaidu('ja'), 'jp');
      expect(TransLang.toBaidu('ko'), 'kor');
      expect(TransLang.toBaidu('es'), 'spa');
    });

    test('未知语言码回落到 auto 而不是抛出', () {
      expect(TransLang.toBaidu('xx'), 'auto');
      expect(TransLang.toGoogle('xx'), 'xx');
    });

    test('byCode / labelOf', () {
      expect(TransLang.byCode('zh-TW')?.label, '繁體中文');
      expect(TransLang.labelOf('nope'), 'nope');
    });

    test('界面语言 → 默认目标语言（不与界面语言相同）', () {
      expect(TransLang.defaultTargetFor('zh'), 'en');
      expect(TransLang.defaultTargetFor('zh_TW'), 'en');
      expect(TransLang.defaultTargetFor('en'), 'zh');
      expect(TransLang.defaultTargetFor('ja'), 'zh');
      // 目标语言不能等于当前界面语言，否则「翻译」等于没翻
      for (final ui in ['zh', 'zh_TW', 'en', 'ja', 'id', 'es']) {
        expect(TransLang.defaultTargetFor(ui) == ui, isFalse);
      }
    });
  });

  group('配置校验', () {
    test('ready 按接口判断必填项', () {
      final c = TranslateConfig(provider: 'google');
      expect(c.ready, isFalse);
      c.googleApiKey = 'k';
      expect(c.ready, isTrue);

      final b = TranslateConfig(provider: 'baidu', baiduAppId: 'a');
      expect(b.ready, isFalse);
      b.baiduKey = 'k';
      expect(b.ready, isTrue);

      final u = TranslateConfig(provider: 'custom');
      expect(u.ready, isFalse);
      u.customUrl = 'https://x';
      expect(u.ready, isTrue);
    });

    test('missingField 指出缺哪一项（供界面精确提示）', () {
      expect(TranslateConfig(provider: 'google').missingField, 'googleApiKey');
      expect(
        TranslateConfig(provider: 'baidu', baiduAppId: 'a').missingField,
        'baiduKey',
      );
      expect(TranslateConfig(provider: 'custom').missingField, 'customUrl');
    });

    test('配置可 JSON 往返', () {
      final c = TranslateConfig(
        provider: 'custom',
        targetLang: 'ja',
        customUrl: 'https://t.example/api',
        customMethod: 'GET',
        customResultPath: 'data.translations.0.translatedText',
        customPlainText: true,
      );
      final back = TranslateConfig.fromJson(c.toJson());
      expect(back.provider, 'custom');
      expect(back.targetLang, 'ja');
      expect(back.customUrl, 'https://t.example/api');
      expect(back.customMethod, 'GET');
      expect(back.customResultPath, 'data.translations.0.translatedText');
      expect(back.customPlainText, isTrue);
    });

    test('会话偏好可 JSON 往返，缺失时回落到默认目标语言', () {
      final p = ConvTranslatePref(targetLang: 'zh-TW', auto: true);
      final back = ConvTranslatePref.fromJson(p.toJson(), 'zh');
      expect(back.targetLang, 'zh-TW');
      expect(back.auto, isTrue);
      expect(ConvTranslatePref.fromJson(null, 'ja').targetLang, 'ja');
      expect(ConvTranslatePref.fromJson(null, 'ja').auto, isFalse);
    });
  });

  group('会话隔离', () {
    test('每个会话有独立的偏好（互不影响）', () {
      final svc = TranslateService.instance;
      final a = svc.prefFor('BG7LZQ');
      final b = svc.prefFor('group_1');
      a.targetLang = 'ja';
      b.auto = true;
      expect(svc.prefFor('BG7LZQ').targetLang, 'ja');
      expect(svc.prefFor('group_1').targetLang, isNot('ja'));
      expect(svc.prefFor('BG7LZQ').auto, isFalse);
      expect(svc.prefFor('group_1').auto, isTrue);
    });
  });
}
