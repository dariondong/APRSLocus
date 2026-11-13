import 'package:flutter_test/flutter_test.dart';

import 'package:aprslocus/install_mark.dart';
import 'package:aprslocus/state.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 安装标识的空中宣告（用户 2026-11-13 的要求）。
///
/// 要钉住四件事，任何一件破了都会让这条宣告变成「要么没报、要么每 15 秒报」：
///   * 标记只取前 12 位十六进制，前面带 `ID:`（取不到标识就不报，不留空壳）；
///   * 正文不超过状态信息字段 60 个字符的上限，超长先砍基础文本、标记留着；
///   * 装好后只报**一次**：第二次上线返回 null；
///   * 恢复出厂（等于一次新的安装）之后会重新报。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('安装标识的空中宣告', () {
    test('标记只取前 12 位十六进制，取不到就不报', () {
      expect(InstallMark.of('0123456789abcdef0123456789abcdef'),
          'ID:0123456789ab');
      expect(InstallMark.of(' 0123456789ABCDEF '), 'ID:0123456789ab');
      expect(InstallMark.of('abc'), 'ID:abc', reason: '短标识原样留着，不补零');
      expect(InstallMark.of(''), isNull);
      expect(InstallMark.of('   '), isNull);
      expect(InstallMark.of('zz-zz'), isNull, reason: '没有十六进制字符就不要报');
    });

    test('正文不超上限，超长时先砍基础文本、标记整段留着', () {
      final mark = InstallMark.of('0123456789abcdef0123456789abcdef')!;
      final text =
          InstallMark.text('APRSlocus CONNECT v2.2.9 Android', mark, max: 60);
      expect(text.length <= 60, isTrue);
      expect(text.endsWith(mark), isTrue);
      expect(text.startsWith('APRSlocus CONNECT'), isTrue);

      final long = InstallMark.text('x' * 200, mark, max: 60);
      expect(long.length <= 60, isTrue);
      expect(long.endsWith(mark), isTrue);

      // 基础文本一点都放不下时，正文就是标记本身（不能切出半截标记）
      final tight = InstallMark.text('abcdefghij', mark, max: mark.length);
      expect(tight, mark);
    });

    test('只报一次；恢复出厂后再报一次', () async {
      final st = AppState();
      final first = await st.debugInstallMarkText();
      expect(first, isNotNull);
      expect(first!.contains('ID:'), isTrue);
      expect(first.length <= AppState.statusMaxLen, isTrue,
          reason: '状态信息字段按 APRS101 限 60 个字符');
      expect(st.installAnnounced, isTrue);

      expect(await st.debugInstallMarkText(), isNull,
          reason: '之后的每次上线只报在线，不再带标识');

      // 恢复出厂 = 这台机器上的一次新安装：标识也该重新报一遍
      await st.factoryReset();
      expect(st.installAnnounced, isFalse);
      expect(await st.debugInstallMarkText(), isNotNull);
      st.dispose();
    });
  });
}
