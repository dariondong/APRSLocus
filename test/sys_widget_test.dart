import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:aprslocus/l10n/app_localizations.dart';
import 'package:aprslocus/state.dart';
import 'package:aprslocus/sys_widget.dart';

/// 系统状态组件快照的测试。
///
/// 与其它两个组件同样的理由：**组件不会自己纠错** —— 快照里键名写错、
/// 少一条链路，Kotlin 侧只会安静地留空（`read()` 刻意容错），
/// 错误全部落在「界面上少了一块」而不报错。
void main() {
  final zh = lookupAppLocalizations(const Locale('zh'));
  final en = lookupAppLocalizations(const Locale('en'));

  /// 造一个确定的状态：不依赖真实网络 / 定位，只改要断言的那几个字段。
  AppState fresh() => AppState();

  group('系统状态快照', () {
    test('字段齐全且可 JSON 编码', () {
      final st = fresh();
      final snap = buildSysWidgetSnapshot(st: st, s: zh);
      for (final k in ['v', 'ts', 'title', 'call', 'fixState', 'grid',
        'links', 'rx', 'tx', 'beacon', 'stations', 'emptyLabel']) {
        expect(snap.containsKey(k), isTrue, reason: '快照缺 $k');
      }
      expect(() => jsonEncode(snap), returnsNormally);
    });

    test('键名与 Kotlin 侧读的一致（跨语言契约）', () {
      // SysWidgetProvider 用 `snap.read("call")` / `cell.read("state")` 这类
      // **字面量**取值。键名改了而 Kotlin 没跟上，组件上是**安静的空白**，
      // 所以把键名固定成契约。
      final snap = buildSysWidgetSnapshot(st: fresh(), s: zh);
      final links = snap['links'] as List;
      expect(links.length, kSysWidgetLinkCount);
      for (final l in links) {
        expect((l as Map).keys.toSet(), {'name', 'state', 'color'},
            reason: '链路格的键名必须与 Kotlin 读取的一致');
      }
      expect((snap['links'] as List).length, 4);
      expect(kSysWidgetLinkCount, 4, reason: '与 aw_widget_sys.xml 的格子数一致');
    });

    test('四条链路顺序固定（不按状态排序）', () {
      // 顺序固定用户才能「一眼扫到那条我想看的」；按状态排序会让每次刷新后
      // 位置都变，反而更难读。
      final names = (buildSysWidgetSnapshot(st: fresh(), s: zh)['links'] as List)
          .map((e) => (e as Map)['name'])
          .toList();
      expect(names, ['APRS-IS', 'TNC', '音频', 'PKWDWPL']);
    });

    test('链路是**三态**：已连接 / 未启用 / 已启用未连上，三色不同', () {
      // 这是本组件唯一比「连上/没连上」多出来的信息，也是它最该被看清的地方。
      // 「未启用」用户不用管，「连不上」要去查 —— 混成一个「未连接」会让人
      // 对着没启用的链路白折腾。
      final snap = buildSysWidgetSnapshot(st: fresh(), s: zh);
      final colors = <int>{};
      for (final l in snap['links'] as List) {
        colors.add((l as Map)['color'] as int);
      }
      // 默认状态：APRS-IS 已启用，其余未启用 → 至少两种颜色
      expect(colors.length, greaterThanOrEqualTo(2),
          reason: '三态必须用不同颜色，否则「未启用」与「未连上」看不出区别');
    });

    test('定位状态：未定位时用「等待定位」而不是空串', () {
      final st = fresh();
      st.myHasFix = false;
      final snap = buildSysWidgetSnapshot(st: st, s: zh);
      expect(snap['fixState'], zh.beaconWaitingFix);
      expect(snap['fixState'], isNotEmpty);
    });

    test('已定位时用「已定位」，且网格不是 --', () {
      final st = fresh();
      st.myHasFix = true;
      st.myLat = 22.5;
      st.myLng = 114.0;
      final snap = buildSysWidgetSnapshot(st: st, s: zh);
      expect(snap['fixState'], zh.sysFixOk);
      expect(snap['grid'], isNot('--'));
    });

    test('计数与台站数都带上了', () {
      final st = fresh();
      st.packetsRx = 1284;
      st.packetsTx = 37;
      final snap = buildSysWidgetSnapshot(st: st, s: zh);
      expect(snap['rx'], zh.sysRx('1284'));
      expect(snap['tx'], zh.sysTx('37'));
      expect(snap['stations'], zh.sysStations('${st.stations.length}'));
    });

    test('信标用的是状态层已本地化的倒计时（不在这里再判一次）', () {
      // 「已关闭 / 未连接 / 等待定位 / 45s / 即将」这些分支判断在 state.dart 的
      // beaconPhase 里。组件侧再判一次就会两处漂移 —— 所以这里只做包装。
      final st = fresh();
      final snap = buildSysWidgetSnapshot(st: st, s: zh);
      expect(snap['beacon'], zh.sysBeacon(st.nextBeaconIn));
      expect(snap['beacon'], contains(st.nextBeaconIn));
    });

    test('跟随语言：标题与状态文字在中英下不同', () {
      final st = fresh();
      final zhSnap = buildSysWidgetSnapshot(st: st, s: zh);
      final enSnap = buildSysWidgetSnapshot(st: st, s: en);
      expect(zhSnap['title'], zh.sysTitle);
      expect(enSnap['title'], en.sysTitle);
      expect(zhSnap['title'], isNot(enSnap['title']));
      // 「未启用」这条也要跟着变
      expect(zhSnap['links'], isNot(enSnap['links']));
    });
  });
}
