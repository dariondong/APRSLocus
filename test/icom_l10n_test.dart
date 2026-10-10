import 'package:aprslocus/l10n/app_localizations.dart';
import 'package:aprslocus/net/icom_lan_settings.dart';
import 'package:aprslocus/settings_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// WLAN 电台文案本地化的回归测试。
///
/// 背景：`net/icom_lan_io.dart` 的 `phaseLabel` 与 `WlanRadioModel.description`
/// 都是**写死的中文**，界面直接把它们贴出来 —— 只要界面语言不是中文，用户就会
/// 看到中文夹在英/日/西文里。修法是界面层用下面这几个 helper 把「中文基准值」
/// 映射回 l10n 键。
///
/// 这几条错了不会编译失败、analyze 也全绿，只会在切到非中文界面时才暴露。
void main() {
  final zh = lookupAppLocalizations(const Locale('zh'));
  final en = lookupAppLocalizations(const Locale('en'));
  final ja = lookupAppLocalizations(const Locale('ja'));

  group('icomPhaseLabel：把 net 层的中文阶段翻成当前语言', () {
    test('11 个已知阶段在英文下都不再含中文', () {
      const known = [
        '未连接',
        '正在打开端口…',
        '正在发现电台…',
        '正在登录电台…',
        '正在协商音频流…',
        '正在打开数据流…',
        '已连接（等待音频）',
        '已连接（接收中）',
        '连接中断，正在重连…',
        '连接失败',
        '当前平台不支持 IC-705 局域网直连',
      ];
      for (final raw in known) {
        final out = icomPhaseLabel(en, raw);
        expect(out, isNotEmpty, reason: raw);
        expect(RegExp(r'[\u4e00-\u9fff]').hasMatch(out), isFalse,
            reason: '$raw → $out 仍含中文');
      }
    });

    test('中文界面下把「未连接」翻成与 disconnected 一致', () {
      expect(icomPhaseLabel(zh, '未连接'), zh.disconnected);
      expect(icomPhaseLabel(zh, '连接失败'), zh.icomPhaseFailed);
      expect(icomPhaseLabel(zh, '已连接（接收中）'), zh.icomPhaseReceiving);
    });

    test('日语界面确实换了一门语言（与中文不同且非空）', () {
      final jp = icomPhaseLabel(ja, '正在登录电台…');
      expect(jp, isNotEmpty);
      expect(jp, isNot(zh.icomPhaseAuthenticating));
    });

    test('认不出的阶段原样返回（将来新增阶段不会变空白）', () {
      expect(icomPhaseLabel(en, 'some-future-phase'), 'some-future-phase');
      expect(icomPhaseLabel(en, ''), '');
    });

    test('对已本地化的字符串是恒等映射（调用点会先取 connected/disconnected）', () {
      // settings_pages / device_page 会在 link 为空时先取 s.connected / s.disconnected，
      // 若这两个值恰好等于某个已知中文（中文界面下就是），也必须原样返回。
      expect(icomPhaseLabel(zh, zh.connected), zh.connected);
      expect(icomPhaseLabel(zh, zh.disconnected), zh.disconnected);
    });
  });

  group('型号文案：descKey / nameKey 都被真正消费', () {
    test('每个型号的描述都用本地化键，且与写死的中文 description 不同', () {
      for (final m in WlanRadioModel.values) {
        final localized = icomModelDesc(en, m);
        expect(localized, isNotEmpty, reason: m.id);
        expect(RegExp(r'[\u4e00-\u9fff]').hasMatch(localized), isFalse,
            reason: '${m.id} 英文描述仍含中文: $localized');
      }
    });

    test('自定义型号的名称走本地化（其余型号沿用官方 displayName）', () {
      expect(icomModelName(en, WlanRadioModel.custom), en.modelCustomName);
      expect(icomModelName(en, WlanRadioModel.custom),
          isNot(WlanRadioModel.custom.displayName));
      // IC-705 官方型号名跨语言一致，直接沿用。
      expect(icomModelName(en, WlanRadioModel.ic705),
          WlanRadioModel.ic705.displayName);
    });

    test('型号选择芯片：官方型号用 id，自定义项用本地化名', () {
      expect(icomModelTab(en, WlanRadioModel.ic705), 'IC-705');
      expect(icomModelTab(en, WlanRadioModel.custom), en.modelCustomName);
    });

    test('descKey 覆盖所有型号且互不重复（新增型号必须补映射）', () {
      final keys =
          WlanRadioModel.values.map((m) => m.descKey).toList();
      expect(keys.toSet().length, keys.length);
    });
  });
}
