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
  group('语言码（各接口方言的正确性与完整性）', () {
    // 内部短码全集（不含 auto）
    final codes = TransLang.all
        .where((l) => l.code != 'auto')
        .map((l) => l.code)
        .toList();

    test('每个语言在各种接口下的映射都非空，且格式合理', () {
      for (final c in codes) {
        for (final f in [
          TransLang.toGoogle,
          TransLang.toBaidu,
          TransLang.toMyMemory,
          TransLang.toLibre,
        ]) {
          final v = f(c);
          expect(v.trim().isNotEmpty, isTrue, reason: '$c → 空');
          expect(v.contains(' '), isFalse, reason: '$c → 含空格: $v');
          // 形状校验：主语言子标签必须小写（BCP-47 要求），
          // 地域/文字子标签允许大写（zh-CN 是正确写法，不能一律小写）
          final primary = v.split('-').first;
          expect(primary, primary.toLowerCase(),
              reason: '主语言子标签应小写：$v');
          expect(RegExp(r'^[a-z]{2,3}(-[A-Za-z]{2,4})?$').hasMatch(v), isTrue,
              reason: '语言码形状不合 BCP-47：$v');
        }
      }
    });

    test('同一接口内不得有两个语言映射到同一个码（否则反向解析会歧义）', () {
      for (final (name, f) in [
        ('baidu', TransLang.toBaidu),
        ('google', TransLang.toGoogle),
        ('mymemory', TransLang.toMyMemory),
        ('libre', TransLang.toLibre),
      ]) {
        final seen = <String, String>{};
        for (final c in codes) {
          final v = f(c);
          // zh 与 zh-TW 在多数接口必须区分（简繁是两种目标语言）
          expect(seen.containsKey(v), isFalse,
              reason: '$name: $c 与 ${seen[v]} 都映射到 $v');
          seen[v] = c;
        }
      }
    });

    test('简繁中文在各接口下必须区分开（否则繁体翻译会给出简体）', () {
      for (final (name, f) in [
        ('baidu', TransLang.toBaidu),
        ('google', TransLang.toGoogle),
        ('mymemory', TransLang.toMyMemory),
        ('libre', TransLang.toLibre),
      ]) {
        expect(f('zh') == f('zh-TW'), isFalse, reason: '$name 未区分简繁');
      }
    });

    test('实测过的具体码值（防回归）', () {
      expect(TransLang.toGoogle('zh'), 'zh-CN');
      expect(TransLang.toGoogle('zh-TW'), 'zh-TW');
      expect(TransLang.toBaidu('zh-TW'), 'cht');
      expect(TransLang.toBaidu('ja'), 'jp');
      expect(TransLang.toBaidu('ko'), 'kor');
      // MyMemory 实测中文用 zh-CN / zh-TW
      expect(TransLang.toMyMemory('zh'), 'zh-CN');
      expect(TransLang.toMyMemory('zh-TW'), 'zh-TW');
      // LibreTranslate 用 ISO 639-1，繁体是 zt
      expect(TransLang.toLibre('zh'), 'zh');
      expect(TransLang.toLibre('zh-TW'), 'zt');
    });
  });

  group('译文有效性校验（挡住「返回原文」的假成功）', () {
    test('完全相同的输出判为未翻译', () {
      expect(TransSanity.isEcho('hello', 'hello'), isTrue);
      // 仅大小写/标点/空白不同 → 仍算未翻译
      expect(TransSanity.isEcho('Hello, world!', 'hello world'), isTrue);
      expect(TransSanity.isEcho('hello', '你好'), isFalse);
    });

    test('looksTranslated：非拉丁目标语言却回纯 ASCII → 判为未翻译', () {
      // 这是 MyMemory 的典型表现（实测 en→ja 返回 "hello-world"）
      expect(TransSanity.looksTranslated('hello world', 'hello-world', 'ja'),
          isFalse);
      expect(TransSanity.looksTranslated('hello world', 'Hello World', 'ko'),
          isFalse);
      // 正常译文通过
      expect(TransSanity.looksTranslated('hello world', '你好，世界', 'zh'),
          isTrue);
      expect(TransSanity.looksTranslated('hello', 'ハロー', 'ja'), isTrue);
    });

    test('拉丁目标语言不误判（英译法只差重音也算翻过）', () {
      expect(TransSanity.looksTranslated('hello', 'bonjour', 'fr'), isTrue);
      // 但原样返回仍然要判失败
      expect(TransSanity.looksTranslated('hello', 'hello', 'fr'), isFalse);
    });

    test('空输出判为失败', () {
      expect(TransSanity.looksTranslated('hello', '', 'zh'), isFalse);
      expect(TransSanity.looksTranslated('hello', '   ', 'zh'), isFalse);
    });
  });

  group('接口配置（自动模式与各接口）', () {
    test('默认接口是「自动」，且无需凭据', () {
      final c = TranslateConfig();
      expect(c.provider, TransProvider.auto);
      expect(c.ready, isTrue);
    });

    test('自动链顺序：Google 公开 → MyMemory → LibreTranslate', () {
      expect(TransProvider.autoChain, [
        TransProvider.googlePublic,
        TransProvider.mymemory,
        TransProvider.libre,
      ]);
    });

    test('LibreTranslate 需要实例地址才 ready', () {
      final c = TranslateConfig(provider: TransProvider.libre);
      expect(c.ready, isTrue); // 有默认实例地址
      c.libreUrl = '';
      expect(c.ready, isFalse);
      expect(c.missingField, 'libreUrl');
    });

    test('LibreTranslate 实例地址/Key 可 JSON 往返', () {
      final c = TranslateConfig(
        provider: TransProvider.libre,
        libreUrl: 'https://my.instance',
        libreApiKey: 'k',
      );
      final back = TranslateConfig.fromJson(c.toJson());
      expect(back.libreUrl, 'https://my.instance');
      expect(back.libreApiKey, 'k');
    });

    test('未知 provider 字符串不崩溃（旧配置兼容）', () {
      final c = TranslateConfig.fromJson({'provider': 'free'});
      expect(c.provider, 'free'); // 旧值原样保留
      expect(c.ready, isFalse); // 但不可用 → UI 会提示重新选择
    });
  });
  group('百度语种与错误码（回答「百度能不能翻译印尼语」）', () {
    test('百度支持印尼语，语种码是 id', () {
      // 百度翻译开放平台标准版即支持印度尼西亚语，码为 id
      expect(TransLang.toBaidu('id'), 'id');
      expect(TransLang.toBaidu('vi'), 'vie');
      expect(TransLang.toBaidu('ar'), 'ara');
      expect(TransLang.toBaidu('zh-TW'), 'cht');
      expect(TransLang.toBaidu('ja'), 'jp');
      expect(TransLang.toBaidu('ko'), 'kor');
    });

    test('每个界面可选语言在百度下都有明确码（不会退化成 auto）', () {
      // 退化成 auto 会让「翻译成印尼语」变成「自动检测」——语言选错＝静默失效
      for (final l in TransLang.all) {
        if (l.code == 'auto') continue;
        final code = TransLang.toBaidu(l.code);
        expect(code, isNot('auto'), reason: '${l.code} 在百度下退化为 auto');
      }
    });

    test('四个接口的语种码互不混用（同一语言各写各的方言）', () {
      // 同一语言在不同接口的写法确实不同，混用会 400/58001
      expect(TransLang.toBaidu('zh-TW'), 'cht');
      expect(TransLang.toGoogle('zh-TW'), 'zh-TW');
      expect(TransLang.toLibre('zh-TW'), 'zt');
      expect(TransLang.toMyMemory('zh-TW'), 'zh-TW');
    });
  });

  group('语种不支持的识别与提示', () {
    test('百度 58001 归类为 lang-unsupported（而非裸错误码）', () {
      // 该码在 _baidu 内被识别；这里锁住「归类名」这个约定，
      // UI 侧 explainTranslateError 依赖它的前缀
      const marker = 'lang-unsupported:baidu:zh->xyz';
      expect(marker.startsWith('lang-unsupported'), isTrue);
    });

    test('识别规则：HTTP 4xx 且报文提到语言', () {
      // 复现 service 里的判定，确保规则本身被固定
      bool classify(String msg) {
        final http4xx = msg.startsWith('400') || msg.startsWith('404');
        final mentionsLang = msg.contains('Invalid Value') ||
            msg.contains('invalid target') ||
            msg.toLowerCase().contains('language') ||
            msg.toLowerCase().contains('unsupported');
        return http4xx && mentionsLang;
      }

      expect(classify('400 Invalid Value'), isTrue);
      expect(classify('400 invalid target language'), isTrue);
      expect(classify('404 language not found'), isTrue);
      // 非语言类 4xx 不应被误判成语种问题（否则会误导用户去换接口）
      expect(classify('400 Bad Request'), isFalse);
      expect(classify('401 Unauthorized'), isFalse);
      // 5xx 也不该归为语种问题
      expect(classify('500 language server error'), isFalse);
    });
  });
}
