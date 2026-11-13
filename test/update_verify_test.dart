import 'package:flutter_test/flutter_test.dart';

import 'package:aprslocus/update_notes.dart';
import 'package:aprslocus/update_verify.dart';

/// 一版 release 的正文（`tool/release_notes.py` 生成的样子）。
const _body = '''
> 这是预发布，用来先装上试试。装过 2.2.2 或更早的可以直接覆盖。

## [2.2.3] - 2026-11-12

### 更新

- 更新页会显示这个安装包的签名到底校没校。
- **更新渠道**的那份清单改由官网下发，地址变了不用等新版。
- 装完问一句 `安装包` 还要不要留。

## [2.2.3] - 2026-11-12 (English)

### Update

- The signature row now says whether it was checked.
''';

void main() {
  group('更新日志摘要', () {
    test('只取这一版的条目', () {
      final lines = updateNotesSummary(_body);
      expect(lines.length, 3);
      expect(lines.first, '更新页会显示这个安装包的签名到底校没校。');
      // 英文那一份是下一个 ## 标题，不能混进来
      expect(lines.any((l) => l.contains('signature row')), isFalse);
    });

    test('去掉行内的粗体与代码符号', () {
      final lines = updateNotesSummary(_body);
      expect(lines[1], '更新渠道的那份清单改由官网下发，地址变了不用等新版。');
      expect(lines[2], '装完问一句 安装包 还要不要留。');
    });

    test('条数有上限，空正文给空表', () {
      expect(updateNotesSummary(_body, max: 1).length, 1);
      expect(updateNotesSummary(''), isEmpty);
      expect(updateNotesSummary('   \n\n'), isEmpty);
    });

    test('没有 ## 标题的日志也能挑出条目，重复句只留一条', () {
      final lines = updateNotesSummary('- 一条\n- 一条\n- 两条');
      expect(lines, ['一条', '两条']);
    });
  });

  group('安装包联网校验', () {
    Map<String, dynamic> local({
      String version = '2.2.3',
      String sha = 'abc123',
      String sig = 'SIG',
      String pkg = 'com.aprslocus.aprslocus',
    }) =>
        {
          'package': pkg,
          'versionName': version,
          'sig': sig,
          'sha256': sha,
        };

    UpdateVerifyReport judge({
      Map<String, dynamic>? pkg,
      String own = 'SIG',
      String tag = '2.2.3',
      String digest = 'sha256:abc123',
    }) =>
        judgeUpdatePackage(
          local: pkg ?? local(),
          ownSignature: own,
          packageName: 'com.aprslocus.aprslocus',
          tag: tag,
          assetDigest: digest,
        );

    test('版本号、摘要、签名都对才通过', () {
      expect(judge().state, UpdateVerifyState.ok);
      // tag 带不带 v 是同一版
      expect(judge(tag: 'v2.2.3').state, UpdateVerifyState.ok);
    });

    test('版本号不一致', () {
      final r = judge(pkg: local(version: '2.2.2'));
      expect(r.state, UpdateVerifyState.versionMismatch);
      expect(r.detail, '2.2.2 / 2.2.3');
    });

    test('摘要不一致（文件被换过）', () {
      expect(judge(pkg: local(sha: 'deadbeef')).state,
          UpdateVerifyState.shaMismatch);
    });

    test('签名与本机不一致', () {
      expect(judge(pkg: local(sig: 'OTHER')).state, UpdateVerifyState.sigMismatch);
    });

    test('读不出签名算 unknown，不算签名不对', () {
      expect(judge(pkg: local(sig: '')).state, UpdateVerifyState.unknown);
      expect(judge(own: '').state, UpdateVerifyState.unknown);
    });

    test('仓库没给摘要：说查不到，不冒充通过', () {
      expect(judge(digest: '').state, UpdateVerifyState.notFound);
      expect(judge(digest: 'sha256:').state, UpdateVerifyState.notFound);
    });

    test('摘要有大小写与前缀差异也能对上', () {
      expect(judge(digest: 'SHA256:ABC123').state, UpdateVerifyState.ok);
    });

    test('从资产列表里挑对号的那一份', () {
      final release = <String, dynamic>{
        'tag_name': 'v2.2.3',
        'assets': [
          {'name': 'APRSLocus_2.2.3_armeabi-v7a.apk', 'digest': 'sha256:aaa'},
          {'name': 'APRSLocus_2.2.3.apk', 'digest': 'sha256:bbb'},
          {'name': 'APRSLocus_Setup_2.2.3.exe', 'digest': 'sha256:ccc'},
        ],
      };
      expect(assetDigestOf(release, 'APRSLocus_2.2.3.apk'), 'sha256:bbb');
      expect(assetDigestOf(release, 'APRSLocus_2.2.3_armeabi-v7a.apk'),
          'sha256:aaa');
      // 名字对不上（改名了）：退到第一个 .apk，摘要照样能判真假
      expect(assetDigestOf(release, 'APRSLocus_9.9.9.apk'), 'sha256:aaa');
      // 文件名的目录部分不算数
      expect(assetDigestOf(release, '/tmp/APRSLocus_2.2.3.apk'), 'sha256:bbb');
    });

    test('连不上仓库时如实说没联网（这里连一个不存在的端口）', () async {
      final report = await verifyUpdatePackageOnline(
        apiBase: 'http://127.0.0.1:1/repos',
        owner: 'dariondong',
        repo: 'APRSLocus',
        tag: '2.2.3',
        assetName: 'APRSLocus_2.2.3.apk',
        local: local(),
        ownSignature: 'SIG',
        packageName: 'com.aprslocus.aprslocus',
        userAgent: 'APRSlocus/test',
        timeout: const Duration(milliseconds: 300),
      );
      expect(report.state, UpdateVerifyState.offline);
    });

    test('读不出包时直接 unknown，不去联网', () async {
      final report = await verifyUpdatePackageOnline(
        apiBase: 'http://127.0.0.1:1/repos',
        owner: 'dariondong',
        repo: 'APRSLocus',
        tag: '2.2.3',
        assetName: 'x.apk',
        local: null,
        ownSignature: 'SIG',
        packageName: 'com.aprslocus.aprslocus',
        userAgent: 'APRSLocus/test',
        timeout: const Duration(milliseconds: 300),
      );
      expect(report.state, UpdateVerifyState.unknown);
    });
  });

  test('版本号归一', () {
    expect(normalizeVersionTag('v2.2.3'), '2.2.3');
    expect(normalizeVersionTag(' 2.2.3 '), '2.2.3');
  });
}
