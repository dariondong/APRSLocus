import 'package:flutter_test/flutter_test.dart';

import 'package:aprslocus/models.dart';
import 'package:aprslocus/state.dart';

Station _mk(
  String call, {
  St status = St.online,
  TypeGroup? tg,
  String? comment,
  String? toCall,
  Map<String, String>? aprslocus,
  double? speed,
  DateTime? heard,
}) {
  final s = Station(
    call: call,
    symbol: '>',
    lat: 39.9,
    lng: 116.4,
    speed: speed,
    comment: comment,
    toCall: toCall,
    aprslocus: aprslocus,
    lastHeard: heard ?? DateTime.now(),
    status: status,
  );
  // typeGroup 由 symbol 推导（见 Station.typeGroup），按需覆盖符号
  switch (tg) {
    case TypeGroup.mobile:
      s.symbol = '>';
      break;
    case TypeGroup.fixed:
      s.symbol = '_';
      break;
    case TypeGroup.infra:
      s.symbol = 'R';
      break;
    case TypeGroup.wx:
      s.symbol = 'W';
      break;
    default:
      break;
  }
  return s;
}

void main() {
  group('接收范围（未选国家 = 不限制）', () {
    test('未选择任何国家时，所有台站可见', () {
      final st = AppState();
      expect(st.receiveCountries, isEmpty);
      for (final c in ['BG7PGW-9', 'RS0ISS', 'N0CALL-7', 'JA1XXX', 'VK2ABC']) {
        expect(st.stationAllowedFor(_mk(c)), isTrue,
            reason: '$c 在未选择国家时应可见');
      }
    });

    test('选择了国家时，仅匹配前缀的台站可见（+ 收藏/手动始终可见）', () {
      final st = AppState();
      // 直接写入列表，避免 persist()/prefs 依赖
      st.receiveCountries.add('CN'); // 中国前缀 'B'
      expect(st.stationAllowedFor(_mk('BG7PGW-9')), isTrue);
      expect(st.stationAllowedFor(_mk('N0CALL-7')), isFalse);
      // 收藏台站不受接收范围限制
      final fav = _mk('N0CALL-7')..favorite = true;
      expect(st.stationAllowedFor(fav), isTrue);
    });
  });

  group('StationFilter.matches', () {
    test('空筛选命中所有台站', () {
      const f = StationFilter();
      expect(f.isEmpty, isTrue);
      expect(f.matches(_mk('BG7PGW-9')), isTrue);
      expect(f.matches(_mk('RS0ISS')), isTrue);
    });

    test('ISS 筛选命中空间站呼号', () {
      const f = StationFilter(status: 'iss');
      expect(f.matches(_mk('RS0ISS')), isTrue);
      expect(f.matches(_mk('NA1SS')), isTrue);
      expect(f.matches(_mk('OR4ISS')), isTrue);
      expect(f.matches(_mk('BG7PGW-9')), isFalse);
      // ARISS 字样对象台也算
      expect(f.matches(_mk('XX1YY', comment: 'ARISS contact')), isTrue);
    });

    test('状态筛选：离线不计入 online', () {
      const f = StationFilter(status: 'online');
      expect(f.matches(_mk('A1AAA', status: St.online)), isTrue);
      // 6 分钟前上报 → 有效状态离线
      expect(
        f.matches(_mk('A1AAA',
            status: St.online,
            heard: DateTime.now().subtract(const Duration(minutes: 6)))),
        isFalse,
      );
    });

    test('类型 / 同款软件 / 型号筛选', () {
      expect(const StationFilter(type: 'wx').matches(_mk('A1AAA', tg: TypeGroup.wx)),
          isTrue);
      expect(const StationFilter(type: 'wx').matches(_mk('A1AAA')), isFalse);

      const app = StationFilter(app: 'aprslocus');
      expect(app.matches(_mk('A1AAA', comment: 'APRSlocus v1.6.61')), isTrue);
      expect(app.matches(_mk('A1AAA', comment: 'hello')), isFalse);

      // 型号：需与识别出的设备显示名一致（此处无设备库 → 不命中）
      expect(const StationFilter(model: 'APRSdroid').matches(_mk('A1AAA')),
          isFalse);
    });

    test('key 随条件变化', () {
      expect(const StationFilter().key, 'all|all|all|all|all');
      expect(const StationFilter(status: 'iss').key, 'iss|all|all|all|all');
      expect(
        const StationFilter(status: 'iss').copyWith(type: 'mobile').key,
        'iss|mobile|all|all|all',
      );
    });
  });


  _moreTests();
}

// ─────────────────────────────────────────────────────────────────────────────
// 「筛选把台站全挡掉」的回归保护。
// 背景：App 刚启动时从磁盘恢复的台站 lastHeard 都是旧的，有效状态即为离线，
// 此时点「在线」筛选会一个都不剩 —— 这是**正确**行为（不该误报成 bug），
// 但界面必须能说明原因并可一键清除，所以这里固定住 List/Filter 的契约。
void main2() {}

void _moreTests() {
  group('筛选空结果语义（空状态提示依据）', () {
    Station stale(String c) => Station(
          call: c,
          symbol: '>',
          lat: 39.9,
          lng: 116.4,
          lastHeard: DateTime.now().subtract(const Duration(hours: 3)),
          status: St.online, // 原始状态是在线，但 effectiveStatus 已离线
        );

    test('过期台站的有效状态为离线 → 「在线」筛选应得空结果', () {
      final list = [stale('BG7PGW-9'), stale('BA1AAA-1')];
      const online = StationFilter(status: 'online');
      expect(list.where(online.matches), isEmpty);
      // 清空筛选后应恢复全部
      const none = StationFilter();
      expect(list.where(none.matches).length, 2);
      // 且「已启用筛选」判定为真（空状态据此切到筛选提示）
      expect(online.isEmpty, isFalse);
      expect(none.isEmpty, isTrue);
    });

    test('类型 + 状态叠加同样只做收窄，不会凭空造出结果', () {
      final list = [stale('BG7PGW-9')];
      const f = StationFilter(status: 'online', type: 'mobile');
      expect(list.where(f.matches), isEmpty);
      expect(f.key, 'online|mobile|all|all|all');
    });
  });

  // ────────────────────────────────────────────────────────────────────────
  // 「APRSlocus 同款软件」识别的回归保护。
  //
  // 背景（v1.6.80 引入的真实回归）：位置包的备注里不再包含 "APRSlocus"
  // （版本号已移到状态包、备注默认留空），而当时的判定**只看备注/呼号**，
  // 于是：筛选命中 0、统计计数恒为 0、receiveOthers 下台站还会被误过滤。
  // 修复后判定改用 toCall（官方 APALOC 标识）/ aprslocus 字段，备注仅作兼容。
  group('APRSlocus 同款软件识别', () {
    const f = StationFilter(app: 'aprslocus');

    test('toCall=APALOC 应命中（备注为空，模拟 v1.6.80 后的真实报文）', () {
      final s = _mk('BA1AAA-7', toCall: 'APALOC');
      expect(s.isAprslocusStation, isTrue);
      expect(f.matches(s), isTrue);
    });

    test('aprslocus 字段存在应命中（toCall 丢失时兜底）', () {
      final s = _mk('BA1AAA-7', aprslocus: {'软件': 'APRSlocus'});
      expect(s.isAprslocusStation, isTrue);
      expect(f.matches(s), isTrue);
    });

    test('旧版备注关键字仍兼容', () {
      final s = _mk('BA1AAA-7', comment: 'APRSlocus v1.6.57');
      expect(s.isAprslocusStation, isTrue);
    });

    test('普通台站不应被误命中', () {
      final s = _mk('BG7PGW-9', toCall: 'APRS', comment: '在路上');
      expect(s.isAprslocusStation, isFalse);
      expect(f.matches(s), isFalse);
    });

    test('筛选与 Station 判定同源（不会再各自漂移）', () {
      // 空备注 + 仅靠 toCall：这是唯一能区分「两套逻辑是否一致」的组合
      final ok = _mk('BA1AAA-7', toCall: 'APALOC');
      final no = _mk('BG7PGW-9', toCall: 'APRS');
      for (final s in [ok, no]) {
        expect(f.matches(s), s.isAprslocusStation,
            reason: '${s.call}: 筛选判定须与 Station 判定一致');
      }
    });
  });
}
