import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aprslocus/backup.dart';

/// 备份/恢复的回归测试。
///
/// 这套逻辑没有 UI 兜底：导出错了、导入丢了一项，界面上都不会报错，
/// 只会在用户换机那天发现「少了东西」。所以这里把几件关键约定钉死：
/// - **只搬白名单里的键**（否则一份伪造的 JSON 能改任意偏好）；
/// - **值带类型标签**（int/double 在 JSON 里分不清，写回去类型错会让
///   `getDouble` 直接抛错）；
/// - **schema 更高要拒绝**（而不是猜着解析）。
void main() {
  group('类型标签编解码', () {
    test('五种偏好类型都能原样往返', () {
      expect(decodeBackupValue(encodeBackupValue('BV2AAA')), 'BV2AAA');
      expect(decodeBackupValue(encodeBackupValue(true)), true);
      expect(decodeBackupValue(encodeBackupValue(7)), 7);
      expect(decodeBackupValue(encodeBackupValue(1.5)), 1.5);
      expect(
        decodeBackupValue(encodeBackupValue(['zh', 'en'])),
        ['zh', 'en'],
      );
    });

    test('double 0.0 不会被退化成 int', () {
      // jsonEncode(0.0) → "0.0"，但如果把值当 num 存成 int，
      // SharedPreferences.getDouble 会抛类型错误。
      final v = decodeBackupValue(encodeBackupValue(0.0));
      expect(v, isA<double>());
      expect(v, 0.0);
    });

    test('不认识/被改坏的值解码为 null', () {
      expect(decodeBackupValue({'x': 1}), isNull);
      expect(decodeBackupValue({'i': 1, 's': 'a'}), isNull);
      expect(decodeBackupValue({'l': ['ok', 3]}), isNull);
      expect(decodeBackupValue('raw'), isNull);
      expect(encodeBackupValue(Object()), isNull);
    });
  });

  group('导出', () {
    final snapshot = <String, Object?>{
      'myCall': 'BV2AAA',
      'filterLat': 25.0,
      'uiScale': 1.0,
      'receiveCountries': ['TW', 'JP'],
      'stations': '[{"call":"BV2AAA"}]',
      'transPref_BV2BBB': '{"targetLang":"en"}',
      'honorPrimary_BV2AAA': 'early',
      'someCacheFromAnotherFeature': 'x',
    };

    test('只导出所选分组，且分组内外的键不越界', () {
      final json = buildBackupJson(
        snapshot: snapshot,
        categories: {BackupCategory.settings},
        appVersion: '1.6.123',
        platform: 'android',
        now: DateTime.utc(2026, 9, 18, 5, 0, 0),
      );
      final d = jsonDecode(json) as Map<String, dynamic>;
      expect(d['kind'], kBackupKind);
      expect(d['schema'], 1);
      expect(d['appVersion'], '1.6.123');
      expect(d['exportedAt'], '2026-09-18T05:00:00.000Z');
      final groups = d['groups'] as Map<String, dynamic>;
      expect(groups.keys, ['settings']);
      final settings = groups['settings'] as Map<String, dynamic>;
      expect(settings['myCall'], {'s': 'BV2AAA'});
      expect(settings['filterLat'], {'d': 25.0});
      expect(settings['receiveCountries'], {
        'l': ['TW', 'JP'],
      });
      // 缓存类键既不在白名单里，也不该出现在任何分组
      expect(settings.containsKey('someCacheFromAnotherFeature'), isFalse);
      expect(settings.containsKey('stations'), isFalse);
      expect(settings.containsKey('transPref_BV2BBB'), isFalse);
    });

    test('前缀键归到对应分组（会话翻译偏好 / 用户默认徽章）', () {
      final json = buildBackupJson(
        snapshot: snapshot,
        categories: {BackupCategory.translate, BackupCategory.honors},
        appVersion: '1.6.123',
        platform: 'windows',
      );
      final groups = (jsonDecode(json) as Map)['groups'] as Map;
      expect((groups['translate'] as Map).keys, ['transPref_BV2BBB']);
      expect(
        (groups['honors'] as Map).keys,
        ['honorPrimary_BV2AAA'],
      );
    });

    test('选中的分组没有数据时不写空组', () {
      final json = buildBackupJson(
        snapshot: {'myCall': 'BV2AAA'},
        categories: {BackupCategory.settings, BackupCategory.messages},
        appVersion: '1.6.123',
        platform: 'android',
      );
      final groups = (jsonDecode(json) as Map)['groups'] as Map;
      expect(groups.keys, ['settings']);
    });

    test('分组条目数统计与导出内容一致', () {
      final counts = backupCounts(snapshot, {BackupCategory.settings});
      expect(counts[BackupCategory.settings], 4); // myCall/filterLat/uiScale/receiveCountries
    });
  });

  group('解析', () {
    String jsonOf(Map<String, Object?> groups, {int schema = 1, Object? kind}) {
      return jsonEncode({
        'kind': kind ?? kBackupKind,
        'schema': schema,
        'appVersion': '1.6.123',
        'exportedAt': '2026-09-18T05:00:00.000Z',
        'platform': 'android',
        'groups': groups,
      });
    }

    test('正常的备份能读出分组、来源与条数', () {
      final d = parseBackupJson(jsonOf({
        'settings': {
          'myCall': {'s': 'BV2AAA'},
          'mySsid': {'i': 3},
        },
        'messages': {
          'messages': {'s': '[]'},
        },
      }));
      expect(d.appVersion, '1.6.123');
      expect(d.exportedAt, DateTime.utc(2026, 9, 18, 5));
      expect(d.totalKeys, 3);
      expect(d.categories, [BackupCategory.settings, BackupCategory.messages]);
      expect(d.countOf(BackupCategory.settings), 2);
      expect(d.skippedKeys, 0);
    });

    test('白名单外的键被跳过并计数，而不是静默应用', () {
      final d = parseBackupJson(jsonOf({
        'settings': {
          'myCall': {'s': 'BV2AAA'},
          'definitelyNotAKey': {'s': 'evil'},
        },
      }));
      expect(d.totalKeys, 1);
      expect(d.groups[BackupCategory.settings]!.containsKey('definitelyNotAKey'),
          isFalse);
      expect(d.skippedKeys, 1);
    });

    test('不认识的整组被忽略（兼容更新版本导出的备份）', () {
      final d = parseBackupJson(jsonOf({
        'settings': {
          'myCall': {'s': 'BV2AAA'},
        },
        'brandNewGroup': {
          'whatever': {'s': 'x'},
        },
      }));
      expect(d.categories, [BackupCategory.settings]);
      expect(d.skippedKeys, 1);
    });

    test('非 JSON / 非备份 / schema 过高 / 空内容 分别报对应错误', () {
      expect(
        () => parseBackupJson('这不是 JSON'),
        throwsA(isA<BackupException>()
            .having((e) => e.code, 'code', BackupErrorCode.notJson)),
      );
      expect(
        () => parseBackupJson(jsonEncode({'hello': 1})),
        throwsA(isA<BackupException>()
            .having((e) => e.code, 'code', BackupErrorCode.notBackup)),
      );
      expect(
        () => parseBackupJson(jsonOf({
          'settings': {
            'myCall': {'s': 'BV2AAA'},
          },
        }, schema: kBackupSchema + 1)),
        throwsA(isA<BackupException>()
            .having((e) => e.code, 'code', BackupErrorCode.schemaNewer)),
      );
      expect(
        () => parseBackupJson(jsonOf({})),
        throwsA(isA<BackupException>()
            .having((e) => e.code, 'code', BackupErrorCode.empty)),
      );
    });

    test('低版本 schema 仍然接受（只增不减）', () {
      final d = parseBackupJson(jsonOf({
        'settings': {
          'myCall': {'s': 'BV2AAA'},
        },
      }, schema: 1));
      expect(d.totalKeys, 1);
    });
  });

  group('导入写回', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('按分组覆盖，未选中的分组保持原样', () async {
      SharedPreferences.setMockInitialValues({
        'myCall': 'OLD',
        'mySsid': 9,
        'stations': '[{"call":"OLD"}]',
      });
      final p = await SharedPreferences.getInstance();
      final data = parseBackupJson(jsonEncode({
        'kind': kBackupKind,
        'schema': 1,
        'appVersion': '1.6.123',
        'groups': {
          'settings': {
            'myCall': {'s': 'NEW'},
            'mySsid': {'i': 1},
            'filterLat': {'d': 0.0},
          },
          'stations': {
            'stations': {'s': '[{"call":"NEW"}]'},
          },
        },
      }));

      final res = await applyBackup(
        data,
        {BackupCategory.settings},
        prefs: p,
      );

      expect(res.applied, 3);
      expect(res.skipped, 0);
      expect(p.getString('myCall'), 'NEW');
      expect(p.getInt('mySsid'), 1);
      // 关键：写回的是 double，getDouble 才读得出来
      expect(p.getDouble('filterLat'), 0.0);
      // 未选中的分组不能被碰
      expect(p.getString('stations'), '[{"call":"OLD"}]');
    });

    test('写回后的偏好能重新导出成同样的内容（往返一致）', () async {
      final snapshot = <String, Object?>{
        'myCall': 'BV2AAA',
        'mySsid': 0,
        'uiScale': 1.0,
        'receiveCountries': ['TW'],
        'smartTiers': '[]',
      };
      SharedPreferences.setMockInitialValues({});
      final p = await SharedPreferences.getInstance();
      final json = buildBackupJson(
        snapshot: snapshot,
        categories: {BackupCategory.settings},
        appVersion: '1.6.123',
        platform: 'android',
      );
      await applyBackup(
        parseBackupJson(json),
        {BackupCategory.settings},
        prefs: p,
      );
      final again = buildBackupJson(
        snapshot: snapshotFromPrefs(p),
        categories: {BackupCategory.settings},
        appVersion: '1.6.123',
        platform: 'android',
      );
      expect(
        (jsonDecode(again) as Map)['groups'],
        (jsonDecode(json) as Map)['groups'],
      );
    });
  });

  test('备份文件名可读且带时间戳', () {
    final name = backupFileName(DateTime(2026, 9, 18, 5, 6, 7));
    expect(name, 'APRSlocus_backup_20260918_050607.json');
  });
}
