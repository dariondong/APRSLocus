import 'package:aprslocus/nmea.dart';
import 'package:flutter_test/flutter_test.dart';

/// 外接 GPS 模块的 NMEA 解析回归测试。
///
/// 期望值取自 **NMEA 0183 文档里的标准示例**（`$GPRMC` / `$GPGGA` 那两条）与
/// 真机模块的常见写法（双模模块的 `$GN*` / `$BD*` 前缀），不是自己算一遍自己验
/// 一遍。四条关键约定：
///   1. 度分 → 十进制（`3956.12345` = 39°56.12345′ = 39.93539°），分值 ≥ 60 判损坏；
///   2. talker（`GP`/`GN`/`BD`/`GL`）**不区分** —— 只认 `GP` 会在模块切到北斗时
///      整条失联；
///   3. 状态/质量说不行的语句是 **noFix 不是解析失败**（冷启动时它一直这么发）；
///   4. 定位由多条语句**合并**而成（坐标在 RMC、海拔与精度在 GGA），
///      逐条产出会让同一秒的位置重复入轨迹。
void main() {
  /// NMEA 文档里的标准示例（这些校验和是权威值，用来证明 XOR 实现没写错）
  const rmc = r'$GPRMC,123519,A,4807.038,N,01131.000,E,022.4,084.4,230394,003.1,W*6A';
  const gga = r'$GPGGA,123519,4807.038,N,01131.000,E,1,08,0.9,545.4,M,46.9,M,,*47';

  group('XOR 校验和', () {
    test('标准示例算得出权威值 47', () {
      const body =
          'GPGGA,123519,4807.038,N,01131.000,E,1,08,0.9,545.4,M,46.9,M,,';
      expect(NmeaChecksum.format(NmeaChecksum.compute(body)), '47');
    });
  });

  group('度分 → 十进制', () {
    test('纬度两位度、经度三位度', () {
      expect(nmeaDegrees('4807.038', 'N')!, closeTo(48.1173, 1e-6));
      expect(nmeaDegrees('01131.000', 'E')!, closeTo(11.5166667, 1e-6));
      expect(nmeaDegrees('3956.12345', 'N')!, closeTo(39.9353908, 1e-6));
      expect(nmeaDegrees('11623.54321', 'E')!, closeTo(116.3923868, 1e-6));
    });

    test('S / W 是负值（照抄符号会把点扔到地球另一边）', () {
      expect(nmeaDegrees('4916.45', 'S')!, closeTo(-49.2741667, 1e-6));
      expect(nmeaDegrees('12311.12', 'W')!, closeTo(-123.1853333, 1e-6));
    });

    test('分值 ≥ 60 / 非数字 → null（坏语句不能变成坐标）', () {
      expect(nmeaDegrees('4860.000', 'N'), isNull);
      expect(nmeaDegrees('12', 'N'), isNull);
      expect(nmeaDegrees('48ab.038', 'N'), isNull);
      expect(nmeaDegrees('', 'N'), isNull);
    });
  });

  group('日期时间组合', () {
    test('ddmmyy + hhmmss', () {
      final t = nmeaCombineUtc('230394', '123519')!;
      expect(t.isUtc, isTrue);
      expect(t, DateTime.utc(1994, 3, 23, 12, 35, 19));
    });

    test('非法日期/时间返回 null（而不是猜一个）', () {
      expect(nmeaCombineUtc('', '123519'), isNull);
      expect(nmeaCombineUtc('321325', '123519'), isNull);
      expect(nmeaCombineUtc('230394', '999999'), isNull);
    });
  });

  group('RMC / GGA 解析', () {
    test('RMC：坐标、速度（节 → km/h）、航向、日期', () {
      final r = NmeaParser.parse(rmc);
      expect(r.isOk, isTrue);
      final s = r.sentence!;
      expect(s.kind, NmeaKind.rmc);
      expect(s.talker, 'GP');
      expect(s.checksumValid, isTrue);
      expect(s.positionValid, isTrue);
      expect(s.latitude!, closeTo(48.1173, 1e-6));
      expect(s.longitude!, closeTo(11.5166667, 1e-6));
      expect(s.speedKnots!, closeTo(22.4, 1e-6));
      expect(s.courseDegrees!, closeTo(84.4, 1e-6));
      expect(s.utc, DateTime.utc(1994, 3, 23, 12, 35, 19));
    });

    test('GGA：定位质量、卫星数、HDOP、海拔', () {
      final r = NmeaParser.parse(gga);
      expect(r.isOk, isTrue);
      final s = r.sentence!;
      expect(s.kind, NmeaKind.gga);
      expect(s.fixQuality, 1);
      expect(s.satellites, 8);
      expect(s.hdop!, closeTo(0.9, 1e-6));
      expect(s.altitudeM!, closeTo(545.4, 1e-6));
      expect(s.positionValid, isTrue);
    });

    test('talker 不区分：GN / BD 一样能解析（双模模块会切前缀）', () {
      const gn = r'$GNRMC,120044.00,A,3956.12345,N,11623.54321,E,0.023,,040924,,,A*69';
      const bd = r'$BDGGA,120045.00,3956.12345,N,11623.54321,E,1,12,0.8,52.3,M,-9.1,M,,*5B';
      expect(NmeaParser.parse(gn).sentence!.latitude!, closeTo(39.9353908, 1e-6));
      expect(NmeaParser.parse(bd).sentence!.satellites, 12);
    });

    test('GLL / ZDA / GSA / VTG 各取所需', () {
      const gll = r'$GPGLL,4916.45,N,12311.12,W,225444,A,A*5C';
      const zda = r'$GPZDA,201530.00,04,07,2002,00,00*60';
      const gsa = r'$GPGSA,A,3,04,05,,09,12,,,24,,,,,2.5,2.1,1.3*39';
      const vtg = r'$GPVTG,054.7,T,034.4,M,005.5,N,010.2,K,A*25';
      expect(NmeaParser.parse(gll).sentence!.longitude!, closeTo(-123.1853333, 1e-6));
      expect(NmeaParser.parse(zda).sentence!.utc, DateTime.utc(2002, 7, 4, 20, 15, 30));
      final g = NmeaParser.parse(gsa).sentence!;
      expect(g.fixType, '3');
      expect(g.hdop!, closeTo(2.1, 1e-6));
      final v = NmeaParser.parse(vtg).sentence!;
      expect(v.speedKmh!, closeTo(10.2, 1e-6));
      expect(v.courseDegrees!, closeTo(54.7, 1e-6));
    });
  });

  group('校验和与坏语句', () {
    test('严格模式：校验不符直接丢弃', () {
      // 把标准示例的最后一位改掉（6A → 6B）
      const bad = r'$GPRMC,123519,A,4807.038,N,01131.000,E,022.4,084.4,230394,003.1,W*6B';
      final r = NmeaParser.parse(bad, strictChecksum: true);
      expect(r.isOk, isFalse);
      expect(r.error, NmeaErrorCode.checksumMismatch);
      expect(r.detail, '6B != 6A');
    });

    test('宽松模式：仍解析，但如实标出校验不符', () {
      const bad = r'$GPRMC,123519,A,4807.038,N,01131.000,E,022.4,084.4,230394,003.1,W*6B';
      final r = NmeaParser.parse(bad);
      expect(r.isOk, isTrue);
      expect(r.sentence!.checksumValid, isFalse);
      expect(r.sentence!.checksumClaimed, '6B');
      expect(r.sentence!.checksumComputed, '6A');
    });

    test('不带校验和的语句：宽松模式可解析，但不标记为「校验通过」', () {
      const bare = r'$GPRMC,123519,A,4807.038,N,01131.000,E,022.4,084.4,230394,003.1,W';
      final r = NmeaParser.parse(bare);
      expect(r.isOk, isTrue);
      expect(r.sentence!.checksumValid, isFalse);
      expect(NmeaParser.parse(bare, strictChecksum: true).error,
          NmeaErrorCode.checksumMismatch);
    });

    test('噪声行 / 未知语句分得清（「协议不对」要让用户看得见）', () {
      expect(NmeaParser.parse('hello').error, NmeaErrorCode.notNmea);
      expect(NmeaParser.parse(r'$XXABC,1,2*43').error,
          NmeaErrorCode.unknownSentence);
      // GSV 是「认识但用不上」：绝不能算失败（一次定位会有好几条 GSV）
      final gsv = NmeaParser.parse(r'$GPGSV,3,1,11,01,05,000,00*4F');
      expect(gsv.isOk, isTrue);
      expect(gsv.sentence!.kind, NmeaKind.other);
      expect(gsv.sentence!.positionValid, isFalse);
    });

    test('字段太少 / 坐标坏掉 → 明确的错误码', () {
      expect(NmeaParser.parse(r'$GPRMC,123519,A*07').error,
          NmeaErrorCode.tooFewFields);
      expect(
        NmeaParser.parse(r'$GPGGA,123519,9999.9,N,01131.000,E,1,08,0.9,545.4,M,46.9,M,,')
            .error,
        NmeaErrorCode.badCoordinate,
      );
    });
  });

  group('状态位 / 质量位：noFix 不是解析失败', () {
    test('RMC 状态 V：解析成功，但这次没有定位', () {
      const v = r'$GPRMC,123520,V,4807.038,N,01131.000,E,,,230394,,*00';
      final r = NmeaParser.parse(v);
      expect(r.isOk, isTrue);
      expect(r.sentence!.positionValid, isFalse);
      final asm = NmeaAssembler();
      expect(asm.feed(v), isNull);
      expect(asm.lastError, NmeaErrorCode.noFix);
    });

    test('GGA 质量 0：同样只是「还没定上」', () {
      const q = r'$GPGGA,123521,,,,,0,00,,,M,,M,,*60';
      final asm = NmeaAssembler();
      expect(asm.feed(q), isNull);
      expect(asm.lastError, NmeaErrorCode.noFix);
    });
  });

  group('装配：多条语句合成一次定位', () {
    test('GGA 先到、RMC 后到：海拔/精度/卫星数都补齐', () {
      final asm = NmeaAssembler();
      // GGA 带坐标 → 本身就是一次定位（没有速度航向）
      final first = asm.feed(gga)!;
      expect(first.altM!, closeTo(545.4, 1e-6));
      expect(first.satellites, 8);
      expect(first.speedKmh, isNull);
      // 精度由 HDOP 估算（0.9 × 5 m）
      expect(first.accuracyM!, closeTo(4.5, 1e-6));
      // RMC 的坐标同一条、但带上了速度航向与日期
      final second = asm.feed(rmc)!;
      expect(second.speedKmh!, closeTo(22.4 * 1.852, 1e-6));
      expect(second.courseDeg!, closeTo(84.4, 1e-6));
      expect(second.utc, DateTime.utc(1994, 3, 23, 12, 35, 19));
      // 海拔这类「配角字段」也要跟着过来，否则界面上时有时无
      expect(second.altM!, closeTo(545.4, 1e-6));
      expect(second.source, 'GPRMC');
    });

    test('只发 GGA 的模块：照样有定位（日期拿不到就留 null）', () {
      final asm = NmeaAssembler();
      final f = asm.feed(gga)!;
      expect(f.lat, closeTo(48.1173, 1e-6));
      expect(f.utc, isNull);
    });

    test('ZDA 补上日期后，GGA 的定位就带完整时刻', () {
      final asm = NmeaAssembler();
      const zda = r'$GPZDA,201530.00,04,07,2002,00,00*60';
      const gga2 = r'$GPGGA,201531.00,4807.038,N,01131.000,E,1,08,0.9,545.4,M,46.9,M,,*60';
      expect(asm.feed(zda), isNull, reason: 'ZDA 不带定位');
      final f = asm.feed(gga2)!;
      expect(f.utc, DateTime.utc(2002, 7, 4, 20, 15, 30));
    });

    test('GSV 之类的「认识但用不上」不产出定位、也不报错', () {
      final asm = NmeaAssembler();
      expect(asm.feed(r'$GPGSV,3,1,11,01,05,000,00*4F'), isNull);
      expect(asm.lastError, isNull);
    });

    test('严格模式下坏校验和不会成为坐标；宽松模式下会（并计数）', () {
      const bad = r'$GPGGA,123519,4807.038,N,01131.000,E,1,08,0.9,545.4,M,46.9,M,,*00';
      final strict = NmeaAssembler();
      expect(strict.feed(bad), isNull);
      expect(strict.lastError, NmeaErrorCode.checksumMismatch);
      final loose = NmeaAssembler(strictChecksum: false);
      final f = loose.feed(bad);
      expect(f, isNotNull);
    });

    test('reset 清掉缓存（重连后不该拼出跨链路的怪数据）', () {
      final asm = NmeaAssembler();
      expect(asm.feed(rmc), isNotNull);
      asm.reset();
      const ggaOnly = r'$GPGGA,123519,4807.038,N,01131.000,E,1,08,0.9,545.4,M,46.9,M,,*47';
      final f = asm.feed(ggaOnly)!;
      expect(f.speedKmh, isNull, reason: '旧的 RMC 速度必须被清掉');
      expect(f.utc, isNull, reason: '旧的日期也必须被清掉');
    });
  });

  group('卫星数：双模模块的 GGA 按 talker 相加', () {
    // 真机写法：双模模块每轮各发一条 GGA，每条只报自己那个系统的颗数
    const gp = r'$GPGGA,120047.00,3956.12345,N,11623.54321,E,1,10,0.9,52.3,M,-9.1,M,,*4B';
    const bd = r'$BDGGA,120046.00,3956.12345,N,11623.54321,E,1,10,0.9,52.3,M,-9.1,M,,*5B';
    const gn = r'$GNGGA,120048.00,3956.12345,N,11623.54321,E,1,20,0.9,52.3,M,-9.1,M,,*59';

    test('GPS 10 + 北斗 10 → 20（只留最后一条时永远是 10）', () {
      final asm = NmeaAssembler();
      expect(asm.feed(bd)!.satellites, 10, reason: '只有北斗时如实是 10');
      expect(asm.feed(gp)!.satellites, 20, reason: '两个系统都在，合计 20');
      expect(asm.feed(bd)!.satellites, 20, reason: '次序反过来也是 20');
    });

    test('GN 联合解本身就是合计，不能再加一遍 (20 不是 40)', () {
      final asm = NmeaAssembler();
      expect(asm.feed(gp)!.satellites, 10);
      expect(asm.feed(gn)!.satellites, 20);
      expect(asm.feed(gp)!.satellites, 20, reason: 'GN 在就以 GN 为准');
    });

    test('单系统模块不受影响：8 颗还是 8 颗', () {
      final asm = NmeaAssembler();
      expect(asm.feed(gga)!.satellites, 8);
    });

    test('掉了一个系统就不再计入（15 秒不报即过期）', () {
      final asm = NmeaAssembler();
      final t0 = DateTime.utc(2026, 10, 24, 4, 0, 0);
      expect(asm.feed(bd, now: t0)!.satellites, 10);
      final later = t0.add(const Duration(seconds: 40));
      expect(asm.feed(gp, now: later)!.satellites, 10,
          reason: '北斗那条已经过期，只报 GPS 的 10');
    });

    test('reset 清掉各系统的颗数（重连不该继承上一条链路的数）', () {
      final asm = NmeaAssembler();
      expect(asm.feed(bd)!.satellites, 10);
      asm.reset();
      expect(asm.feed(gp)!.satellites, 10);
    });
  });

  group('分帧（蓝牙回调不按行对齐）', () {
    test('一条语句被切成三块也能拼回', () {
      final sp = NmeaLineSplitter();
      expect(sp.feed(r'$GPGGA,123519,4807.0'.codeUnits), isEmpty);
      expect(sp.feed('38,N,01131.000,E,1,08'.codeUnits), isEmpty);
      final out = sp.feed(',0.9,545.4,M*47\r\n'.codeUnits);
      expect(out.length, 1);
      expect(NmeaParser.parse(out.first).isOk, isTrue);
    });

    test('一次回调里挤进多条语句能全部切出', () {
      final sp = NmeaLineSplitter();
      expect(sp.feed('A1\r\nA2\nA3\r'.codeUnits), ['A1', 'A2', 'A3']);
    });
  });
}
