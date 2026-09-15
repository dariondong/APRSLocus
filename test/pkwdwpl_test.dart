import 'dart:typed_data';

import 'package:aprslocus/net/tnc.dart';
import 'package:aprslocus/pkwdwpl.dart';
import 'package:aprslocus/state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// PKWDWPL 链路（Kenwood 航点语句）回归测试。
///
/// 期望值取自 **BI7NOR 采集的真实语句**与 PKWDWPL Lite 的既有测试，
/// 不是自己算一遍自己验一遍。三条关键约定：
///   1. 度分 → 十进制（`3954.98` = 39°54.98′ = 39.9163°），分值 ≥ 60 判损坏；
///   2. 字段数有 10/11/12 三种（第 8/9/11 字段常为空），**不能按固定下标硬取**
///      —— 硬取会把字段少的整条丢掉，而其中就有校验和正确的正常语句；
///   3. 这条链路**只收不发**：[AppState.dataSource] 永远不会是 pkwdwpl。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('NMEA XOR 校验和', () {
    test(r'业界权威示例 $GPGGA 能算对', () {
      // 这条是 NMEA 0183 文档里的标准示例，用它证明 XOR 实现本身没写错
      // （否则「算不对」既可能是实现错、也可能是被校验的语句错）
      const body =
          'GPGGA,123519,4807.038,N,01131.000,E,1,08,0.9,545.4,M,46.9,M,,';
      expect(PkwdwplChecksum.format(PkwdwplChecksum.compute(body)), '47');
    });

    test('真实 PKWDWPL 语句（校验和正确）', () {
      const line = r'$PKWDWPL,102339,V,3958.55,N,11625.70,E,,,290625,,BI4PGN-11,/i*22';
      final r = PkwdwplParser.parse(line);
      expect(r.isOk, isTrue);
      expect(r.fix!.checksumValid, isTrue, reason: 'BI7NOR 采集的真机语句');
      expect(r.fix!.checksumComputed, '22');
    });
  });

  group('度分 → 十进制', () {
    test('3954.98 → 39.9163（纬度）', () {
      final v = PkwdwplParser.dmToDecimal('3954.98', 'N')!;
      expect(v, closeTo(39 + 54.98 / 60, 1e-9));
    });

    test('11616.63 → 116.2771…（经度）；西经取负', () {
      expect(PkwdwplParser.dmToDecimal('11616.63', 'E')!,
          closeTo(116 + 16.63 / 60, 1e-9));
      expect(PkwdwplParser.dmToDecimal('11616.63', 'W')!,
          closeTo(-(116 + 16.63 / 60), 1e-9));
      expect(PkwdwplParser.dmToDecimal('3958.55', 'S')!, lessThan(0));
    });

    test('分 ≥ 60 视为语句损坏', () {
      expect(PkwdwplParser.dmToDecimal('3960.00', 'N'), isNull);
      expect(PkwdwplParser.dmToDecimal('', 'N'), isNull);
      expect(PkwdwplParser.dmToDecimal('12.34', 'N'), isNull);
    });

    test('decimalToDm 与 dmToDecimal 互逆，且「分」补足两位', () {
      // 这条用例的由来：PKWDWPL Lite 里 39.13° 曾被写成 397.80（分没补零），
      // 端到端测试报 badLatitude 才发现
      expect(PkwdwplParser.decimalToDm(39.9163, isLatitude: true),
          startsWith('3954.9'));
      expect(PkwdwplParser.decimalToDm(39.13, isLatitude: true), '3907.80');
      final round = PkwdwplParser.dmToDecimal('3907.80', 'N')!;
      expect(round, closeTo(39.13, 1e-6));
    });
  });

  group('字段容错（真实报文里有 10/11/12 三种字段数）', () {
    test('标准 12 字段：全字段都出来', () {
      const line = r'$PKWDWPL,102202,M,3954.98,N,11616.63,E,7,83,290625,000052,BG1UBU-9,/j*2E';
      final f = PkwdwplParser.parse(line).fix!;
      expect(f.callsign, 'BG1UBU-9');
      expect(f.statusRaw, 'M');
      expect(f.altitudeMeters, 7);
      expect(f.courseDegrees, 83);
      expect(f.utcDate, '290625');
      expect(f.distanceRaw, '000052', reason: '前导零必须保留，详情页要显示原文');
      expect(f.icon, '/j');
      expect(f.symbolTable, '/');
      expect(f.symbolCode, 'j');
      expect(f.latitude, closeTo(39 + 54.98 / 60, 1e-9));
      expect(f.longitude, closeTo(116 + 16.63 / 60, 1e-9));
      expect(f.utcTime, '102202');
      expect(f.fieldCountAnomaly, isFalse);
      expect(f.parsedFieldCount, 12);
    });

    test('10 字段（高度/航向/距离全空）仍能解析出坐标与呼号', () {
      // 真机语句：第 8/9/11 字段为空，逗号仍占位
      const line = r'$PKWDWPL,102537,V,3958.46,N,11618.95,E,290625,,BI1AR-1,/&*1C';
      final f = PkwdwplParser.parse(line).fix!;
      expect(f.callsign, 'BI1AR-1');
      expect(f.checksumValid, isTrue);
      expect(f.latitude, closeTo(39 + 58.46 / 60, 1e-9));
      expect(f.altitudeMeters, isNull, reason: '第 8 字段为空');
      expect(f.courseDegrees, isNull);
      expect(f.utcDate, '290625');
      expect(f.fieldCountAnomaly, isTrue, reason: '字段数少于标准，打标记但不丢');
    });

    test('高度/航向为空但是 12 个字段（`E,,,290625`）', () {
      const line = r'$PKWDWPL,102339,V,3958.55,N,11625.70,E,,,290625,,BI4PGN-11,/i*22';
      final f = PkwdwplParser.parse(line).fix!;
      expect(f.altitudeMeters, isNull);
      expect(f.courseDegrees, isNull);
      expect(f.utcDate, '290625');
      expect(f.callsign, 'BI4PGN-11');
    });
  });

  group('三层兜底（XOR 查不出字符换位）', () {
    test('呼号格式可疑会被标记（BG1UB9 这种数字跑到字母后的写法）', () {
      // XOR 与字符顺序无关，所以 BI4PGN1-1 与 BI4PGN-11 校验和相同 ——
      // 只能靠呼号格式检查兜住
      const bad = r'$PKWDWPL,102353,V,3955.09,N,11616.91,E,4,103,290625,000050,BG1UB9,/j*0C';
      final f = PkwdwplParser.parse(bad).fix!;
      expect(f.callsign, 'BG1UB9');
      expect(f.callsignSuspicious, isTrue);
    });

    test('正常呼号不误报', () {
      for (final c in ['BG7LZQ', 'BG1UBU-9', 'BI4PGN-11', 'BH3BBJ-1']) {
        final line = '\$PKWDWPL,102202,M,3954.98,N,11616.63,E,7,83,290625,'
            '000052,$c,/j*00';
        final f = PkwdwplParser.parse(line).fix!;
        expect(f.callsignSuspicious, isFalse, reason: c);
      }
    });

    test('校验和不符：宽松模式保留（标注）、严格模式丢弃', () {
      // 把真机语句的呼号抄错一位 → 校验和必然不符（这正是采集时发生过的事）
      const typo = r'$PKWDWPL,102353,V,3955.09,N,11616.91,E,4,103,290625,000050,BG1UB9,/j*C0';
      final loose = PkwdwplParser.parse(typo);
      expect(loose.isOk, isTrue, reason: '默认宽松：不丢句子，只标注');
      expect(loose.fix!.checksumValid, isFalse);
      expect(loose.fix!.checksumClaimed, 'C0');
      expect(loose.fix!.checksumComputed.isNotEmpty, isTrue);

      final strict = PkwdwplParser.parse(typo, strictChecksum: true);
      expect(strict.isOk, isFalse);
      expect(strict.error, PkwdwplErrorCode.checksumMismatch);
      expect(strict.detail, contains('C0'));
    });

    test('非 PKWDWPL 语句被识别为 notPkwdwpl（电台还会吐 GGA/RMC）', () {
      final r = PkwdwplParser.parse(r'$GPGGA,123519,4807.038,N,01131.000,E*47');
      expect(r.isOk, isFalse);
      expect(r.error, PkwdwplErrorCode.notPkwdwpl);
    });

    test('坐标非法 → badCoordinate（分值 ≥ 60）', () {
      final r = PkwdwplParser.parse(
          r'$PKWDWPL,102202,M,3960.00,N,11616.63,E,7,83,290625,000052,BG7LZQ,/j*00');
      expect(r.isOk, isFalse);
      expect(r.error, PkwdwplErrorCode.badCoordinate);
    });
  });

  group('UTC 时间组合', () {
    test('ddmmyy + hhmmss → UTC（两位年份 <= 79 归 20xx）', () {
      final dt = combineUtc('290625', '102202');
      expect(dt, isNotNull);
      expect(dt!.year, 2025);
      expect(dt.month, 6);
      expect(dt.day, 29);
      expect(dt.hour, 10);
      expect(dt.minute, 22);
      expect(dt.second, 2);
      expect(dt.isUtc, isTrue);
    });

    test('非法日期/时间返回 null（而不是猜一个）', () {
      expect(combineUtc('', '102202'), isNull);
      expect(combineUtc('321325', '102202'), isNull);
      expect(combineUtc('290625', '999999'), isNull);
    });
  });

  group('NMEA 分帧（蓝牙回调不按行对齐）', () {
    test('一条语句被切成三块也能拼回', () {
      final sp = NmeaLineSplitter();
      expect(sp.feed(r'$PKWDWPL,102202,M,3954'.codeUnits), isEmpty);
      expect(sp.feed('.98,N,11616.63,E,7,83'.codeUnits), isEmpty);
      final out = sp.feed(',290625,,BG7LZQ,/j*00\r\n'.codeUnits);
      expect(out.length, 1);
      expect(out.first.startsWith(r'$PKWDWPL'), isTrue);
      expect(out.first.endsWith('*00'), isTrue);
    });

    test('一次回调里挤进多条语句能全部切出', () {
      final sp = NmeaLineSplitter();
      final out = sp.feed(
          'A1\r\nA2\nA3\r\n\r\nA4\r'.codeUnits);
      expect(out, ['A1', 'A2', 'A3', 'A4']);
    });

    test('超长行被丢弃并计数（线路噪声不能吃光内存）', () {
      final sp = NmeaLineSplitter(maxBuffer: 32);
      final out = sp.feed(List<int>.filled(100, 0x41));
      expect(out, isEmpty);
      expect(sp.overflows, greaterThan(0));
      // 溢出后缓冲被清空，后续正常语句不受影响
      expect(sp.feed('\$PKWDWPL,X\r'.codeUnits), [r'$PKWDWPL,X']);
    });

    test('reset 丢弃半条语句（重连时避免跨链路拼出乱码）', () {
      final sp = NmeaLineSplitter();
      sp.feed(r'$PKWDWPL,102'.codeUnits);
      sp.reset();
      expect(sp.feed(r'202,M'.codeUnits), isEmpty);
    });
  });

  group('链路：只读 + 计数', () {
    test('send 一律返回 read-only（电台只单向输出航点）', () {
      final link = PkwdwplLink(transport: _FakeTransport());
      expect(link.send(r'BG7LZQ>APALOC:>test'), 'read-only');
    });

    test('分帧 + 解析 + 校验计数（真实语句逐条喂入）', () {
      // 喂**字节**而不是直接调解析：这样 NmeaLineSplitter 的真实分帧路径
      // （\r\n 切分、空白丢弃）也在被验证，而不是被绕过。
      final t = _FakeTransport();
      final link = PkwdwplLink(transport: t);
      final got = <PkwdwplFix>[];
      link.onFix = got.add;
      t.onBytes!((
        r'$PKWDWPL,102339,V,3958.55,N,11625.70,E,,,290625,,BI4PGN-11,/i*22' '\r\n'
        r'$GPGGA,123519,4807.038,N,01131.000,E*47' '\r\n'
        r'$PKWDWPL,102537,V,3958.46,N,11618.95,E,290625,,BI1AR-1,/&*1C' '\r\n'
      ).codeUnits);
      expect(got.length, 2, reason: 'GGA 那句要被忽略');
      expect(got[0].callsign, 'BI4PGN-11');
      expect(got[1].callsign, 'BI1AR-1');
      expect(link.rxFrames, 2);
      expect(link.ignoredLines, 1, reason: '非 PKWDWPL 的 NMEA 语句计数但不报错');
      expect(link.checksumMismatches, 0);
      expect(link.lastRxAt, isNotNull);
    });

    test('校验不符的句子在宽松模式下仍然入库，但计数可见', () {
      final t = _FakeTransport();
      final link = PkwdwplLink(transport: t);
      final got = <PkwdwplFix>[];
      link.onFix = got.add;
      t.onBytes!((
        r'$PKWDWPL,102353,V,3955.09,N,11616.91,E,4,103,290625,000050,BG1UB9,/j*C0'
        '\r\n'
      ).codeUnits);
      expect(got.length, 1);
      expect(link.checksumMismatches, 1);
      expect(link.rxFrames, 1);
    });

    test('严格模式打开后同样的句子被丢弃并计入 rejected', () {
      final t = _FakeTransport();
      final link = PkwdwplLink(transport: t);
      link.config.strictChecksum = true;
      final got = <PkwdwplFix>[];
      link.onFix = got.add;
      t.onBytes!((
        r'$PKWDWPL,102353,V,3955.09,N,11616.91,E,4,103,290625,000050,BG1UB9,/j*C0'
        '\r\n'
      ).codeUnits);
      expect(got, isEmpty);
      expect(link.rejected, 1);
      expect(link.rxFrames, 0);
    });

    test('配置可持久化（严格校验 / 自动重连）', () async {
      SharedPreferences.setMockInitialValues({});
      final link = PkwdwplLink(transport: _FakeTransport());
      link.config
        ..strictChecksum = true
        ..autoReconnect = false;
      await link.persistConfig();

      final link2 = PkwdwplLink(transport: _FakeTransport());
      await link2.load();
      expect(link2.config.strictChecksum, isTrue);
      expect(link2.config.autoReconnect, isFalse);
    });
  });

  group('AppState 集成（与 TNC 并列的第四条来源）', () {
    Future<AppState> fresh() async {
      final st = AppState();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return st;
    }

    test('默认不启用；可以与 TNC 一起启用（并列）', () async {
      final st = await fresh();
      expect(st.pkwdwplOn, isFalse);
      await st.toggleSource(AppState.srcPkwdwpl, true);
      expect(st.pkwdwplOn, isTrue);
      expect(st.tncOn, isFalse);
      await st.toggleSource(AppState.srcTnc, true);
      expect(st.pkwdwplOn && st.tncOn, isTrue, reason: '两条链路可同时开');
      expect(st.multiSource, isTrue);
    });

    test('永远不会成为发射来源（只读）', () async {
      final st = await fresh();
      await st.toggleSource(AppState.srcPkwdwpl, true);
      st.setTxSource(AppState.srcPkwdwpl);
      expect(st.dataSource, AppState.srcAprsIs,
          reason: '只读链路不能当发射来源');
      expect(AppState.canTransmit(AppState.srcPkwdwpl), isFalse);
      expect(st.usingRf, isFalse, reason: '射频判断不该把只读链路算进去');
    });

    test('可以只启用只读链路（离线记台账是合理用法）', () async {
      final st = await fresh();
      await st.toggleSource(AppState.srcPkwdwpl, true);
      await st.toggleSource(AppState.srcAprsIs, false);
      // 早期版本把它当配置错误挡掉了，那是过度的家长式判断：
      // 挂机收台站 / 记台账完全合理，只是不会发射。
      expect(st.enabledSources, {AppState.srcPkwdwpl});
      expect(st.pkwdwplOn, isTrue);
    });

    test('只读模式下 connected=false 但 rxActive=true（关键区分）', () async {
      final st = await fresh();
      await st.toggleSource(AppState.srcPkwdwpl, true);
      await st.toggleSource(AppState.srcAprsIs, false);
      st.debugSetLinkUp(AppState.srcPkwdwpl, true);

      expect(st.readOnlyMode, isTrue);
      // connected 的真实含义是「发射链路可用」，它必须仍为 false ——
      // 所有 `if (connected)` 守卫都只服务于**发射**（信标/消息/ack/保活），
      // 让它在只读模式下变 true 会直接引发误发射。
      expect(st.connected, isFalse, reason: '只读模式绝不能声称能发射');
      expect(st.txSourceUp, isFalse);
      // 但报文确实在收，界面必须据此显示「只读接收」而不是「未连接」
      expect(st.rxActive, isTrue);
      expect(st.isUp(AppState.srcPkwdwpl), isTrue);
    });

    test('只读模式下依然拒绝发射（三道防线都不需要界面配合）', () async {
      final st = await fresh();
      await st.toggleSource(AppState.srcPkwdwpl, true);
      await st.toggleSource(AppState.srcAprsIs, false);
      st.debugSetLinkUp(AppState.srcPkwdwpl, true);
      final before = st.packetsTx;
      st.sendTestFrame();
      st.sendBeacon();
      expect(st.packetsTx, before, reason: '只读模式下不应产生任何发射');
    });

    test('只读模式：重新启用可发射来源后正常恢复', () async {
      final st = await fresh();
      await st.toggleSource(AppState.srcPkwdwpl, true);
      await st.toggleSource(AppState.srcAprsIs, false);
      expect(st.readOnlyMode, isTrue);
      await st.toggleSource(AppState.srcAprsIs, true);
      expect(st.readOnlyMode, isFalse, reason: '有可发射来源就退出只读模式');
      st.debugSetLinkUp(AppState.srcAprsIs, true);
      expect(st.connected, isTrue);
      expect(st.txSourceUp, isTrue);
    });

    test('保留「最后一条来源不可取消」的守卫（这个是对的）', () async {
      final st = await fresh();
      // 只剩一条时不允许关掉：全关掉应用什么都不收，而界面没有任何提示
      await st.toggleSource(AppState.srcAprsIs, false);
      expect(st.aprsIsOn, isTrue);
      expect(st.enabledSources.length, 1);
    });

    // ── 设备占用检测 ──
    //
    // 这两条是 v1.6.110 的回归护栏：TNC 与 PKWDWPL 都走 SPP / 串口，
    // **两条链路连同一台设备时接收字节流会被瓜分** —— 串口两个句柄各读一部分、
    // 蓝牙第二条 RFCOMM 顶掉第一条。症状是「发送正常、收不到报文」，
    // 从界面上完全看不出原因。

    test('设备占用检测：同一设备被两条链路绑定 → 识别为冲突', () async {
      final st = await fresh();
      const dev = TncDevice(id: 'AA:BB:CC:DD:EE:FF', name: 'Shared');
      st.tnc.bind(dev);
      st.pkwdwpl.bind(dev);
      expect(st.tncPkwdwplConflict, isTrue);
      // TNC 是发射链路，优先
      expect(st.deviceBoundBy(dev.id), AppState.srcTnc);
    });

    test('设备占用检测：不同设备不算冲突', () async {
      final st = await fresh();
      st.tnc.bind(const TncDevice(id: 'AAA'));
      st.pkwdwpl.bind(const TncDevice(id: 'BBB'));
      expect(st.tncPkwdwplConflict, isFalse);
      expect(st.deviceBoundBy('AAA'), AppState.srcTnc);
      expect(st.deviceBoundBy('BBB'), AppState.srcPkwdwpl);
      expect(st.deviceBoundBy('CCC'), isNull);
      expect(st.deviceBoundBy(null), isNull);
    });

    test('冲突时 PKWDWPL 拒绝连接（否则会瓜分 TNC 的接收字节流）', () async {
      final st = await fresh();
      const dev = TncDevice(id: 'AA:BB:CC:DD:EE:FF', name: 'Shared');
      st.tnc.bind(dev);
      st.pkwdwpl.bind(dev);
      // 只留 PKWDWPL 一条来源，避免测试去打真实 APRS-IS
      await st.toggleSource(AppState.srcPkwdwpl, true);
      await st.toggleSource(AppState.srcAprsIs, false);
      await st.toggleConnect();
      // 守卫必须拦在「发起连接之前」，并留下专属错误码 ——
      // 若变成底层连接失败（no-device / open-failed），说明守卫没生效
      expect(st.pkwdwpl.lastError, 'device-in-use');
      expect(st.isUp(AppState.srcPkwdwpl), isFalse);
    });

    // ── 「连上却显示未连接」的修复（v1.6.110）──
    //
    // 设备页手动连接是不会走 toggleSource 的，所以来源仍是「未启用」。
    // 而界面三处都只认 enabledSources / 发射链路：
    //   * 主页横幅只能表达「发射来源通不通」→ 显示「未连接 APRS-IS 服务器」
    //   * 设备页「当前链路」仅遍历 enabledSources → PKWDWPL 那行不渲染
    //   * anyLinkUp 也只数已启用的链路
    // 结果就是「链路在工作（台站能收到）但界面永远说未连接」。

    test('设备页连上后自动启用来源（否则一直显示未连接）', () async {
      final st = await fresh();
      expect(st.pkwdwplOn, isFalse, reason: '默认不启用');
      st.ensureSourceEnabled(AppState.srcPkwdwpl);
      expect(st.pkwdwplOn, isTrue);
      expect(st.enabledSources, contains(AppState.srcPkwdwpl));
    });

    test('ensureSourceEnabled 幂等，且不改发射来源', () async {
      final st = await fresh();
      st.ensureSourceEnabled(AppState.srcPkwdwpl);
      st.ensureSourceEnabled(AppState.srcPkwdwpl);
      expect(st.enabledSources.where((s) => s == AppState.srcPkwdwpl).length, 1);
      expect(st.dataSource, AppState.srcAprsIs, reason: '只读链路不能变成发射来源');
      expect(st.readOnlyMode, isFalse, reason: 'APRS-IS 还在，不是只读模式');
    });


    test('冲突链路被重连逻辑跳过（否则会无限重连）', () async {
      final st = await fresh();
      const dev = TncDevice(id: 'AA:BB:CC:DD:EE:FF', name: 'Shared');
      st.tnc.bind(dev);
      st.pkwdwpl.bind(dev);
      await st.toggleSource(AppState.srcPkwdwpl, true);
      // 冲突的 PKWDWPL 永远不可能 up，必须被判定为「不可能连上」，
      // 否则 _scheduleReconnectIfNeeded 的 `every(isUp)` 永远不成立 →
      // 定时器会 8→16→32→60 秒无休止重试。
      expect(st.blockedByConflict(AppState.srcPkwdwpl), isTrue);
      expect(st.blockedByConflict(AppState.srcTnc), isFalse);
    });

    test('关掉不发射的 pkwdwpl 不影响发射来源', () async {
      final st = await fresh();
      await st.toggleSource(AppState.srcPkwdwpl, true);
      await st.toggleSource(AppState.srcPkwdwpl, false);
      expect(st.pkwdwplOn, isFalse);
      expect(st.dataSource, AppState.srcAprsIs);
    });

    test('只读链路同步状态：不改变「发射来源是否可用」', () async {
      final st = await fresh();
      await st.toggleSource(AppState.srcPkwdwpl, true);
      st.adoptDeviceLink(AppState.srcPkwdwpl, st.isUp(AppState.srcPkwdwpl));
      expect(st.isUp(AppState.srcPkwdwpl), isFalse);
      expect(st.connected, isFalse, reason: 'connected 仍只表达发射来源');
      // 让「发射来源」连上，再验证 pkwdwpl 的状态不干扰它
      st.debugSetLinkUp(AppState.srcAprsIs, true);
      expect(st.connected, isTrue);
      expect(st.isUp(AppState.srcPkwdwpl), isFalse);
    });

    test('旧配置里若把 dataSource 存成 pkwdwpl，加载时回落 APRS-IS', () async {
      SharedPreferences.setMockInitialValues({
        'dataSource': 'pkwdwpl',
        'enabledSources': ['pkwdwpl', 'aprsis'],
      });
      final st = AppState();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(AppState.canTransmit(st.dataSource), isTrue,
          reason: '只读来源不能成为发射来源');
      expect(st.enabledSources, contains(AppState.srcPkwdwpl));
    });
  });
}

/// 最小传输层桩：只为把 onBytes 交给测试调用，不做任何平台操作。
///
/// 为什么用桩而不是真实现：真实现会去连蓝牙/串口（测试机上没有），
/// 而这条链路要验证的是**分帧、校验、解析、计数** —— 与传输层无关。
class _FakeTransport implements TncTransport {
  @override
  bool connected = false;

  @override
  void Function(List<int> bytes)? onBytes;

  @override
  void Function(String status)? onStatus;

  @override
  void Function()? onClosed;

  @override
  void Function(String reason)? onTxFailed;

  @override
  void Function(int size)? onTxAck;

  @override
  Future<bool> get supported async => true;

  @override
  Future<List<TncDevice>> listDevices() async => const [];

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<String?> connect(TncDevice device) async {
    connected = true;
    return null;
  }

  @override
  Future<void> disconnect() async => connected = false;

  @override
  void send(Uint8List bytes) {}
}
