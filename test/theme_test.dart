import 'dart:convert';

import 'package:flutter/material.dart' show Color;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aprslocus/theme_model.dart';
import 'package:aprslocus/theme_store.dart';
import 'package:aprslocus/l10n/app_localizations_zh.dart';
import 'package:aprslocus/theme.dart';
import 'package:aprslocus/theme_icons.dart';
import 'package:aprslocus/theme_text.dart';

/// 主题功能的回归测试。
///
/// 重点不在「改颜色能不能生效」（那是肉眼可见的），而在这三件**看不见**的事：
/// - 白名单：主题文件是用户可见可编辑的文本，越界的项必须被丢弃而不是应用；
/// - 回退：图标名不认识、颜色解析失败、schema 更高，都不能让界面坏掉；
/// - 内置标记不可由文件授予（否则一份文件就能造出「不可删除」的主题）。
void main() {
  group('颜色解析', () {
    test('接受 6 位与 8 位十六进制，带不带 # 都行', () {
      expect(parseHexColor('2563EB'), const Color(0xFF2563EB));
      expect(parseHexColor('#2563EB'), const Color(0xFF2563EB));
      expect(parseHexColor('FF2563EB'), const Color(0xFF2563EB));
      expect(parseHexColor('  2563eb  '), const Color(0xFF2563EB));
    });

    test('长度不对 / 非十六进制一律返回 null（宁可回退默认，也不能猜）', () {
      expect(parseHexColor(null), isNull);
      expect(parseHexColor(''), isNull);
      expect(parseHexColor('#12345'), isNull);
      expect(parseHexColor('ZZZZZZ'), isNull);
      expect(parseHexColor('red'), isNull);
    });

    test('hexOfColor 与 parseHexColor 互逆（丢掉 alpha）', () {
      final h = hexOfColor(const Color(0xFF2563EB));
      expect(h, '2563EB');
      expect(hexOfColor(const Color(0x002563EB)), '2563EB');
    });
  });

  group('主题 JSON 往返', () {
    test('颜色 / 圆角 / 文字 / 图标 都能量化还原', () {
      final t = AppTheme(
        id: 'u1',
        name: '我的主题',
        dark: true,
        colors: {'primary': '0E7490'},
        radius: 9.0,
        texts: {'map': '地图页'},
        icons: {'navMap': 'lib:public'},
      );
      final back = AppTheme.fromJson(jsonDecode(jsonEncode(t.toJson())));
      expect(back, isNotNull);
      expect(back!.id, 'u1');
      expect(back.name, '我的主题');
      expect(back.dark, true);
      expect(back.colors['primary'], '0E7490');
      expect(back.radius, 9.0);
      expect(back.textOf('map'), '地图页');
      expect(back.iconOf('navMap'), 'lib:public');
    });

    test('空项不写入 JSON（主题文件要短、可读）', () {
      final t = AppTheme(id: 'x', name: 'x');
      expect(t.isEmpty, isTrue);
      final j = t.toJson();
      expect(j.containsKey('colors'), isFalse);
      expect(j.containsKey('texts'), isFalse);
      expect(j.containsKey('icons'), isFalse);
      expect(j.containsKey('radius'), isFalse);
    });

    test('没有 id 的主题无法解析（无法归属就无法管理）', () {
      expect(AppTheme.fromJson({'name': 'x'}), isNull);
      expect(AppTheme.fromJson('not a map'), isNull);
    });
  });

  group('白名单校验（导入的主题文件不可信）', () {
    test('越界的颜色令牌 / 文字键 / 图标插槽 都被丢弃并计数', () {
      final warns = <String>[];
      final t = AppTheme.fromJson({
        'id': 'u',
        'name': 'u',
        'colors': {'primary': 'FF0000', 'notAToken': '00FF00'},
        'texts': {'map': 'OK', 'copy': '删除', 'notAKey': 'x'},
        'icons': {'navMap': 'lib:public', 'notASlot': 'lib:home'},
      }, warnings: warns);
      expect(t, isNotNull);
      expect(t!.colors.keys, ['primary']);
      expect(t.texts.keys, ['map']);
      expect(t.icons.keys, ['navMap']);
      expect(warns.length, 4);
    });

    test('颜色值非法时该项被丢弃（而不是存下一个读不出来的值）', () {
      final t = AppTheme.fromJson({
        'id': 'u',
        'colors': {'primary': 'not-a-color', 'background': 'F3F5F9'},
      });
      expect(t!.colors.containsKey('primary'), isFalse);
      expect(t.colors['background'], 'F3F5F9');
    });

    test('空文字视为「删掉这条覆写」，而不是把标题改成空白', () {
      final t = AppTheme.fromJson({
        'id': 'u',
        'texts': {'map': '   ', 'stations': '台站'},
      });
      expect(t!.texts.containsKey('map'), isFalse);
      expect(t.textOf('map'), isNull);
      expect(t.textOf('stations'), '台站');
    });

    test('圆角被夹到合法区间（越界值不能让卡片变成球或尖角）', () {
      expect(AppTheme.fromJson({'id': 'u', 'radius': 9999})!.radius,
          kThemeMaxRadius);
      expect(AppTheme.fromJson({'id': 'u', 'radius': -5})!.radius,
          kThemeMinRadius);
    });
  });

  group('图标引用形状', () {
    test('接受 lib:名字 与 file:文件名', () {
      expect(isValidIconRef('lib:map_rounded'), isTrue);
      expect(isValidIconRef('file:ab12cd34.png'), isTrue);
      expect(isValidIconRef('file:icon-1.svg'), isTrue);
    });

    test('拒绝路径穿越与未知前缀（主题文件能指向磁盘就危险了）', () {
      expect(isValidIconRef('file:../../etc/passwd'), isFalse);
      expect(isValidIconRef('file:sub/dir.png'), isFalse);
      expect(isValidIconRef('file:sub\\dir.png'), isFalse);
      expect(isValidIconRef('http://x/y.png'), isFalse);
      expect(isValidIconRef('lib:'), isFalse);
      expect(isValidIconRef('lib:1abc'), isFalse);
      expect(isValidIconRef('file:noext'), isFalse);
    });
  });

  group('主题包解析', () {
    String bundleJson({int schema = kThemeSchema, Object? kind}) => jsonEncode({
          'kind': kind ?? kThemeKind,
          'schema': schema,
          'active': 'u2',
          'themes': [
            {'id': 'u1', 'name': 'A'},
            {'id': 'u2', 'name': 'B', 'colors': {'primary': '16A34A'}},
          ],
        });

    test('整包可解析，active 落在存在的主题上', () {
      final b = parseThemeJson(bundleJson());
      expect(b.themes.length, 2);
      expect(b.activeId, 'u2');
      expect(b.active!.colors['primary'], '16A34A');
    });

    test('active 指向不存在的主题时回落到第一个（而不是留空）', () {
      final b = parseThemeJson(jsonEncode({
        'kind': kThemeKind,
        'schema': 1,
        'active': 'ghost',
        'themes': [
          {'id': 'u1', 'name': 'A'},
        ],
      }));
      expect(b.activeId, 'u1');
    });

    test('也接受「单个主题」形态（分享一个主题时用）', () {
      final b = parseThemeJson(jsonEncode({
        'kind': kThemeKind,
        'schema': 1,
        'theme': {'id': 'solo', 'name': 'Solo'},
      }));
      expect(b.themes.length, 1);
      expect(b.activeId, 'solo');
    });

    test('文件里的 builtin 标记一律被清掉（否则可伪造「不可删除」的主题）', () {
      final b = parseThemeJson(jsonEncode({
        'kind': kThemeKind,
        'schema': 1,
        'themes': [
          {'id': 'evil', 'name': 'evil', 'builtin': true},
        ],
      }));
      expect(b.themes.first.builtin, isFalse);
    });

    test('非 JSON / 非主题文件 / schema 过高 / 空主题 各自报对应错误', () {
      expect(
        () => parseThemeJson('这不是 JSON'),
        throwsA(isA<ThemeException>()
            .having((e) => e.code, 'code', ThemeErrorCode.notJson)),
      );
      expect(
        () => parseThemeJson(jsonEncode({'hello': 1})),
        throwsA(isA<ThemeException>()
            .having((e) => e.code, 'code', ThemeErrorCode.notTheme)),
      );
      expect(
        () => parseThemeJson(bundleJson(schema: kThemeSchema + 1)),
        throwsA(isA<ThemeException>()
            .having((e) => e.code, 'code', ThemeErrorCode.schemaNewer)),
      );
      expect(
        () => parseThemeJson(jsonEncode(
            {'kind': kThemeKind, 'schema': 1, 'themes': []})),
        throwsA(isA<ThemeException>()
            .having((e) => e.code, 'code', ThemeErrorCode.noThemes)),
      );
    });
  });

  group('内置图标库', () {
    test('每个插槽的默认图标都在库里（否则默认主题会显示问号图标）', () {
      for (final slot in kThemeIconSlots) {
        expect(themeIconByName(slot.defaultIcon), isNotNull,
            reason: '插槽 ${slot.id} 的默认图标 ${slot.defaultIcon} 不在图标库');
        final a = slot.defaultIconActive;
        if (a != null) {
          expect(themeIconByName(a), isNotNull,
              reason: '插槽 ${slot.id} 的选中图标 $a 不在图标库');
        }
      }
    });

    test('不认识的名字返回 null（调用方负责回退）', () {
      expect(themeIconByName('definitely_not_an_icon'), isNull);
      expect(kThemeIconNames, isNotEmpty);
    });

    test('库里的名字都能反查到图标（名字与值是同一套命名）', () {
      for (final n in kThemeIconNames) {
        expect(themeIconByName(n), isNotNull);
      }
    });
  });

  group('ThemeController', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      // 每个用例先把控制器恢复成「只有内置预设」的状态，避免用例互相影响
      ThemeController.instance.load(await SharedPreferences.getInstance());
      for (final t in ThemeController.instance.userThemes.toList()) {
        ThemeController.instance.remove(t.id);
      }
      ThemeController.instance
          .setActive(ThemeController.builtinPresets.first.id);
    });

    test('默认激活内置的「默认」主题，且它不带任何覆写', () {
      final tc = ThemeController.instance;
      expect(tc.active.id, 'builtin:default');
      expect(tc.isDefault, isTrue);
    });

    test('用户主题的增删改查 + 激活', () {
      final tc = ThemeController.instance;
      final t = AppTheme(id: 'u9', name: '自定义');
      tc.upsert(t);
      expect(tc.userThemes.length, 1);
      tc.setActive('u9');
      expect(tc.active.id, 'u9');

      t.colors['primary'] = 'FF0000';
      tc.upsert(t);
      expect(tc.byId('u9')!.colors['primary'], 'FF0000');

      // 删掉正在用的主题 → 回到默认，不留「指向空气」的激活项
      tc.remove('u9');
      expect(tc.userThemes, isEmpty);
      expect(tc.active.id, 'builtin:default');
    });

    test('内置预设不可删、不可改（想改只能另存为）', () {
      final tc = ThemeController.instance;
      final n0 = tc.all.length;
      final preset = ThemeController.builtinPresets.first;

      tc.remove(preset.id);
      expect(tc.all.length, n0, reason: '内置预设不该被删除');

      // 把预设对象直接交给 upsert：它既不会改到预设本身（预设仍然内置），
      // 也不会因为 id 撞车而被遮蔽 —— 而是变成一个新 id 的用户主题。
      final copy = preset.copy()..name = '副本';
      tc.upsert(copy);
      expect(copy.id == preset.id, isFalse);
      expect(tc.byId(preset.id)!.builtin, isTrue, reason: '预设本身必须原样保留');
      expect(tc.byId(copy.id)!.name, '副本');
    });

    test('重名时自动加序号（两个同名主题在列表里分不清）', () {
      final tc = ThemeController.instance;
      final a = tc.duplicateOf(ThemeController.builtinPresets.first);
      tc.upsert(a);
      final b = tc.duplicateOf(ThemeController.builtinPresets.first);
      tc.upsert(b);
      expect(a.name != b.name, isTrue);
    });

    test('图标名不认识时回退到该插槽的默认图标', () {
      final tc = ThemeController.instance;
      tc.upsert(AppTheme(
        id: 'u10',
        name: 't',
        icons: {'navMap': 'lib:definitely_not_an_icon'},
      ));
      tc.setActive('u10');
      expect(tc.iconFor('navMap'), themeIconByName('map_rounded'));
    });

    test('越界的颜色令牌进不了调色板（applyColors 只认白名单令牌）', () {
      final tc = ThemeController.instance;
      tc.upsert(AppTheme(
        id: 'u13',
        name: 't',
        // 绕过 fromJson 直接塞进来（模拟「别处构造了 AppTheme」）
        colors: {'notAToken': 'FF0000'},
      ));
      tc.setActive('u13');
      // 不抛异常，且不因为一个不存在的令牌就改动任何真实配色
      tc.applyColors(isDark: false, legacyPrimary: null);
      final before = C.bg;
      tc.applyColors(isDark: false, legacyPrimary: null);
      expect(C.bg, before);
    });

    test('id 与内置预设撞车时自动换 id（否则新主题会被内置项遮蔽）', () {
      final tc = ThemeController.instance;
      final t = AppTheme(id: 'builtin:ocean', name: '我的海洋');
      tc.upsert(t);
      expect(t.id == 'builtin:ocean', isFalse);
      expect(tc.byId(t.id)!.name, '我的海洋');
    });

    test('导出/导入整包可往返（主题分享与备份就靠它）', () async {
      final tc = ThemeController.instance;
      tc.upsert(AppTheme(
        id: 'u11',
        name: '分享用',
        colors: {'primary': 'DB2777'},
        texts: {'map': '地图'},
        radius: 20,
      ));
      final json = tc.exportBundleJson();
      final back = parseThemeJson(json);
      final t = back.byId('u11');
      expect(t, isNotNull);
      expect(t!.colors['primary'], 'DB2777');
      expect(t.textOf('map'), '地图');
      expect(t.radius, 20);
      // 包**不含**内置预设：否则对方导入一次就平白多出 6 个重复主题
      expect(back.themes.length, 1);
      expect(back.byId('builtin:default'), isNull);
    });

    test('导出单个主题的 JSON 也能被导入（同一入口两种形态）', () {
      final tc = ThemeController.instance;
      final one = tc.exportOneJson(ThemeController.builtinPresets[1]);
      final back = parseThemeJson(one);
      expect(back.themes.length, 1);
      expect(back.themes.first.builtin, isFalse);
    });

    test('写入偏好后能重新读回（重启不丢主题）', () async {
      final p = await SharedPreferences.getInstance();
      final tc = ThemeController.instance;
      tc.upsert(AppTheme(id: 'u12', name: '持久化'));
      tc.setActive('u12');
      await tc.saveTo(p);

      // 模拟重启：清掉内存里的用户主题再 load
      tc.remove('u12');
      tc.setActive('builtin:default');
      await tc.load(p);
      expect(tc.byId('u12'), isNotNull);
      expect(tc.activeId, 'u12');
    });

    test('偏好里的主题 JSON 坏掉时退回默认（主题是锦上添花，不能拖垮启动）', () async {
      SharedPreferences.setMockInitialValues({});
      final p = await SharedPreferences.getInstance();
      await p.setString(ThemeController.kPrefsKey, '{ 这不是 JSON');
      final tc = ThemeController.instance;
      await tc.load(p);
      expect(tc.userThemes, isEmpty);
      expect(tc.active.id, 'builtin:default');
    });
  });

  group('文案覆写口（Tx）', () {
    test('白名单里每个键在 Tx.byKey 里都有分支（漏了会直接显示键名）', () {
      // 这是很容易漏、且**不会报错**的一处：byKey 的 switch 少一个分支时，
      // 界面不会崩，只会把 'radioCat' 这种内部键名当成文案显示出来。
      final tx = Tx(AppLocalizationsZh());
      for (final k in kThemeTextKeys) {
        expect(tx.byKey(k), isNot(k), reason: 'Tx.byKey 缺少分支：$k');
      }
    });

    test('主题覆写后取到的是覆写值，没覆写时等于 l10n', () {
      final zh = AppLocalizationsZh();
      final tx0 = Tx(zh);
      expect(tx0.byKey('map'), zh.map);
      ThemeController.instance.upsert(AppTheme(
        id: 'u20',
        name: 't',
        texts: {'map': '我的地图'},
      ));
      ThemeController.instance.setActive('u20');
      expect(Tx(zh).byKey('map'), '我的地图');
      // 没覆写的那些仍然回退 l10n
      expect(Tx(zh).byKey('stations'), zh.stations);
    });
  });
}
