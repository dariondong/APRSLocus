import 'package:flutter_test/flutter_test.dart';

import 'package:aprslocus/aprs_parse.dart';
import 'package:aprslocus/services.dart';
import 'package:aprslocus/state.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 发送侧报文格式的回归测试。
///
/// 背景（真实踩过的坑）：`AprsFmt.position()` 曾在注释前拼了一个空格：
///   `...E> 123/045/A=000100 ...`
/// APRS101 规定注释（含 CsT `ddd/sss`）必须**紧跟**位置字段、无分隔符。
/// 第三方解析器（aprs.fi / aprslib）普遍用 `^(\d{3})/(\d{3})` 锚定注释行首，
/// 前导空格会让它匹配失败 —— 结果速度与方位角被当成普通备注文字显示，
/// 即用户反馈的「第三方地图里速度与方位角出现在备注里」。
///
/// 期望值经参考实现 aprslib 实测：带空格 → course/speed 为 None；
/// 无空格 → course=123、speed=83.34 km/h、comment 中不含 `ddd/sss`。
///
/// 还踩过一个更隐蔽的坑（v1.6.103，见下面「发射路径的目的呼号」一组）：
/// 加入 TNC 数据来源时，把写死的 `path: 'APALOC,TCPIP*'` 换成了
/// `path: txPath`，而 `txPath` 在 APRS-IS 模式下返回了通用的
/// `'APRS,TCPIP*'` —— 于是位置包/消息的 tocall 变成 `APRS`，
/// 第三方统计站按 `u/APALOC` 订阅时只能收到状态包、收不到位置包。
void main() {
  // 本文件多处分组要构造 AppState（读设置 / persist），所以 binding 与
  // SharedPreferences 的 mock 在这里统一备好 —— 与 beacon_coarse_force_test
  // 同一写法。分组内再设一遍无妨（幂等）。
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('信标报文格式（第三方兼容性）', () {
    test('注释必须紧跟符号，中间不得有空格', () {
      final raw = AprsFmt.position(
        'BG7LZG-9',
        39.070833,
        116.407333,
        '>',
        comment: '123/045/A=000100 Bat:88% APRSlocus v1.6.67',
        path: 'APALOC,TCPIP*',
      );

      // 精确钉死格式（含注释位置）
      expect(
        raw,
        'BG7LZG-9>APALOC,TCPIP*:!3904.25N/11624.44E>'
        '123/045/A=000100 Bat:88% APRSlocus v1.6.67',
      );

      // 核心断言：符号 '>' 之后不得紧跟空格
      final info = raw.substring(raw.indexOf(':') + 1);
      final symIdx = info.indexOf('>');
      expect(symIdx, greaterThan(0));
      expect(info[symIdx + 1], isNot(' '),
          reason: '符号后出现空格会让第三方把 CsT 当备注文字（本 bug 曾出现）');
    });

    test('无注释时不应残留尾部空格', () {
      final raw = AprsFmt.position('BG7LZG-9', 39.070833, 116.407333, '>');
      expect(raw, 'BG7LZG-9>APALOC,TCPIP*:!3904.25N/11624.44E>');
      expect(raw.endsWith(' '), isFalse);
    });

    test('空/纯空白注释不产生多余分隔', () {
      final a = AprsFmt.position('BG7LZG-9', 39.070833, 116.407333, '>',
          comment: '');
      final b = AprsFmt.position('BG7LZG-9', 39.070833, 116.407333, '>',
          comment: '   ');
      expect(a, 'BG7LZG-9>APALOC,TCPIP*:!3904.25N/11624.44E>');
      expect(b, 'BG7LZG-9>APALOC,TCPIP*:!3904.25N/11624.44E>');
    });

    test('自产报文能被自家解析器正确解出速度/方位角，且备注不残留 CsT', () {
      final raw = AprsFmt.position(
        'BG7LZG-9',
        39.070833,
        116.407333,
        '>',
        comment: '123/045/A=000100 Bat:88% APRSlocus v1.6.67',
        path: 'APALOC,TCPIP*',
      );
      // 从完整报文里取出信息字段（: 之后）作为位置帧体
      final body = raw.substring(raw.indexOf(':') + 1);
      final p = parseAprsPosition(body, dest: 'APALOC');
      expect(p, isNotNull, reason: '自产报文应可被解析');
      expect(p!.course, closeTo(123, 0.5));
      expect(p.speed, closeTo(83.34, 0.5)); // 45 节
      expect(p.alt, closeTo(30.48, 0.5)); // 100 ft
      expect(p.comment, 'Bat:88% APRSlocus v1.6.67');
      expect(RegExp(r'\d{3}/\d{3}').hasMatch(p.comment ?? ''), isFalse,
          reason: '备注中不应残留 ddd/sss');
    });
  });

  /// 发射路径的目的呼号回归测试
  ///
  /// 事故经过（v1.6.103）：加入蓝牙 TNC 数据来源时，把原本写死的
  /// `path: 'APALOC,TCPIP*'` 改成 `path: txPath`；而 txPath 在
  /// APRS-IS 模式下返回 `'APRS,TCPIP*'`。后果是：
  ///   * 状态包（保活帧，写死 APALOC）照常发出 → 统计站能收到
  ///   * 位置包 / 消息 / ack 的 tocall 变成通用的 `APRS` → 收不到
  /// 外部表现：按 `u/APALOC` 订阅的统计站里这些台站全都「没有位置」。
  /// 下面把「两种数据来源的目的呼号都必须是 APALOC」钉死。
  group('发射路径的目的呼号（必须始终是 APALOC）', () {
    test('APRS-IS 模式：APALOC,TCPIP*', () {
      final st = AppState();
      expect(st.dataSource, AppState.srcAprsIs, reason: '默认数据来源应为 APRS-IS');
      expect(st.usingTnc, isFalse);
      expect(st.txPath, 'APALOC,TCPIP*',
          reason: 'APRS-IS 的报头目的呼号必须是 APALOC，不能是通用的 APRS');
    });

    test('TNC（射频）模式：目的呼号同样是 APALOC，且不带 TCPIP*', () {
      final st = AppState()..dataSource = AppState.srcTnc;
      expect(st.usingTnc, isTrue);
      expect(st.txPath, startsWith('APALOC'));
      expect(st.txPath, isNot(contains('APRS')));
      expect(st.txPath, isNot(contains('TCPIP*')),
          reason: '射频路径不能带 IP 网关才有的 TCPIP*');
    });

    // ─── 「倒计时走了但没发射」回归（v1.6.105）───────────────────────────
    //
    // 事故：射频来源（TNC / 音频）的自动发射被 canAutoBeacon 门控在
    // 「射频信标」开关之后（默认关）；但倒计时 UI 只判断 beaconEnabled/
    // connected/myHasFix —— 于是倒计时一路走到 0，什么也不发射，
    // 界面也从不说原因。用户报的「音频 APRS 倒计时结束没有发射」即此。
    //
    // 修法是把「是否会发射」收敛成一个条件 rfBeaconEnabled，倒计时与
    // 自动发射都用它。下面把这条不变量钉死：只要不会发射，就绝不能
    // 报告 counting/imminent。
    test('射频信标未开启时：不得报告倒计时（必须报 rfDisabled）', () {
      final st = AppState()..dataSource = AppState.srcAudio;
      st.beaconEnabled = true;
      st.connected = true;
      st.audio.config.rfBeacon = false;
      // 模拟「定位已就绪、间隔已到」——最容易骗过旧逻辑的状态
      st.beaconSecondsLeft; // 触发 getter（无副作用，仅确保可调用）
      expect(st.rfBeaconEnabled, isFalse);
      expect(st.beaconNeedsRfEnable, isTrue);
      expect(st.canAutoBeacon, isFalse, reason: '未开射频信标就不能自动发射');
      expect(st.beaconPhase, BeaconPhase.rfDisabled,
          reason: '不能发射时不得显示倒计时，否则用户会以为马上要发');
    });

    test('打开射频信标后：同一状态才开始倒计时', () async {
      final st = AppState()..dataSource = AppState.srcAudio;
      st.beaconEnabled = true;
      st.connected = true;
      expect(st.beaconPhase, BeaconPhase.rfDisabled);
      await st.enableRfBeacon();
      expect(st.audio.config.rfBeacon, isTrue, reason: '一键开启要落到当前来源的配置');
      expect(st.rfBeaconEnabled, isTrue);
      expect(st.beaconNeedsRfEnable, isFalse);
      expect(st.canAutoBeacon, isTrue);
      expect(st.beaconPhase, isNot(BeaconPhase.rfDisabled));
    });

    test('TNC 与音频的射频信标开关互相独立', () async {
      final st = AppState()..dataSource = AppState.srcTnc;
      st.beaconEnabled = true;
      st.connected = true;
      await st.enableRfBeacon();
      expect(st.tnc.config.rfBeacon, isTrue);
      expect(st.audio.config.rfBeacon, isFalse,
          reason: '两种射频链路的中继/许可不同，开关不能互相影响');
      // 切到音频后应立刻回到「未开启」状态
      st.dataSource = AppState.srcAudio;
      expect(st.beaconNeedsRfEnable, isTrue);
      expect(st.beaconPhase, BeaconPhase.rfDisabled);
    });

    test('APRS-IS 不受射频信标开关影响（无此概念）', () {
      final st = AppState();
      st.beaconEnabled = true;
      st.connected = true;
      expect(st.usingRf, isFalse);
      expect(st.rfBeaconEnabled, isTrue);
      expect(st.beaconNeedsRfEnable, isFalse);
      expect(st.beaconPhase, isNot(BeaconPhase.rfDisabled));
    });

    test('位置信标报头用 APALOC（不得出现通用的 APRS）', () {
      final st = AppState();
      final raw = AprsFmt.position('BG7LZG-9', 39.070833, 116.407333, '>',
          comment: 'Bat:88% APRSlocus v1.6.104', path: st.txPath);
      expect(raw, startsWith('BG7LZG-9>APALOC,TCPIP*:'));
      expect(raw.contains('>APRS,'), isFalse,
          reason: '出现 >APRS, 说明目的呼号退回了通用的 APRS');
    });

    test('消息报头也用 APALOC', () {
      final st = AppState();
      expect(AprsFmt.message('BG7LZG-9', 'BG7LZQ', 'hello', '1234',
              path: st.txPath),
          startsWith('BG7LZG-9>APALOC,TCPIP*::BG7LZQ   :'));
    });

    test('默认 path 也是 APALOC（防止漏传 path 又退回通用 APRS）', () {
      expect(AprsFmt.position('BG7LZG-9', 39.070833, 116.407333, '>'),
          startsWith('BG7LZG-9>APALOC,TCPIP*:'));
      expect(AprsFmt.message('BG7LZG-9', 'BG7LZQ', 'hi', '1'),
          startsWith('BG7LZG-9>APALOC,TCPIP*:'));
      expect(AprsFmt.messageNoAck('BG7LZG-9', 'BG7LZQ', 'hi', '1'),
          startsWith('BG7LZG-9>APALOC,TCPIP*:'));
    });
  });

  /// ─── PHG 数据扩展的格式（对齐用户给的标准报文）───
  ///
  /// 标准报文（用户提供，终端侧抓包）：
  ///   BI7KZM-13>APAVT7,WIDE1-1,qAS,BI7KZM-10:!2216.45N/11113.90ErPHG5950
  ///
  /// 两个要害，都用测试钉死：
  ///   1. `PHGphgd` **紧跟符号**（备注的最前面），前面不能有 `/A=` 或备注文字
  ///      —— 第三方解析器按「注释开头的数据扩展」识别 PHG，插在前面就读不出来；
  ///   2. 码位量化照规范：p=5 → 25 W、h=9 → 5120 ft、g=5 → 5 dB、d=0 → 全向。
  group('PHG 数据扩展格式（对齐标准报文）', () {
    // 下面两条要构造 AppState（读设置 / persist），所以自己把 binding 与
    // SharedPreferences 的 mock 备好 —— 不依赖本文件 main() 里有没有初始化。
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
    });

    test('码位量化：25 W / 5120 ft / 5 dB / 全向 → PHG5950', () {
      expect(AprsPhg.encode(watts: 25, heightFeet: 5120, gainDb: 5), 'PHG5950');
    });

    test('功率取「不超过实际值的最大档」（30 W 只能报 25 W）', () {
      expect(AprsPhg.encode(watts: 30, heightFeet: 5120, gainDb: 5),
          startsWith('PHG5'));
      expect(AprsPhg.encode(watts: 36, heightFeet: 5120, gainDb: 5),
          startsWith('PHG6'));
    });

    test('标准报文逐字节一致（PHG 紧贴符号，中间无空格）', () {
      final raw = AprsFmt.position(
        'BI7KZM-13',
        22 + 16.45 / 60,
        111 + 13.90 / 60,
        'r',
        comment: AprsPhg.encode(watts: 25, heightFeet: 5120, gainDb: 5),
        path: 'APAVT7,WIDE1-1,qAS,BI7KZM-10',
      );
      expect(raw,
          'BI7KZM-13>APAVT7,WIDE1-1,qAS,BI7KZM-10:!2216.45N/11113.90ErPHG5950');
    });

    test('只填功率 / 天线高度 / 增益里的任一项，都要带 PHG', () {
      final st = AppState();
      expect(st.hasPhg, isFalse);
      st.beaconAntennaHeightFt = 5120; // 只填天线高度
      expect(st.hasPhg, isTrue,
          reason: '说明里写的是「填任一项即附上固定 7 字节的 PHGphgd」');
      expect(st.phgPreview, startsWith('PHG'));

      st.dispose();
    });

    test('实际发出的位置报文：PHG 紧跟符号，且排在 /A= 之前', () {
      final st = AppState()
        ..smartBeaconEnabled = false
        ..myCall = 'BI7KZM'
        ..mySsid = 13
        ..mySymbol = 'r'
        ..myLat = 22 + 16.45 / 60
        ..myLng = 111 + 13.90 / 60
        ..myHasFix = true
        ..beaconPowerW = 25
        ..beaconAntennaHeightFt = 5120
        ..beaconGainDb = 5
        ..beaconAltOverrideM = 12; // 让 /A= 也出现，验证两者的先后
      st.sendBeacon();
      final raw = st.packets.map((p) => p.raw).firstWhere(
            (r) => r.contains('PHG'),
            orElse: () => '',
          );
      expect(raw, isNotEmpty, reason: '填了 PHG 却没带 PHG');
      expect(
        raw,
        'BI7KZM-13>APALOC,TCPIP*:!2216.45N/11113.90ErPHG5950/A=000039',
        reason: 'PHG 必须在符号之后、/A= 之前（标准报文就是这样）',
      );

      st.dispose();
    });
  });

  /// ─── 「发射」按钮的两条回执口径 ───
  ///
  /// 两个真实问题（都在 PR #11 的「发射」按钮上）：
  ///   1. 填了 PHG 却没有定位时，位置包被 `!myHasFix` 挡回，只发出状态帧 ——
  ///      界面原来一声不吭，用户以为 PHG 上天了；
  ///   2. `sendStatus()` 复用「位置已上报」那三档连接状态文案，于是只发状态帧
  ///      时主横幅写着「位置已上报」。状态帧与位置帧是两种报文，文案必须分开。
  group('发射回执：状态帧不能写成「位置已上报」', () {
    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
    });

    test('发状态报文 → 文案说「状态报文」，不再说「位置已上报」', () {
      final st = AppState()
        ..setLocale('zh')
        ..myCall = 'BG7LZG'
        ..debugSetLinkUp(AppState.srcAprsIs, true);
      st.sendStatus();
      expect(st.connInfo, contains('状态报文'));
      expect(st.connInfo, isNot(contains('位置已上报')),
          reason: '状态帧不含坐标，不能显示成位置已上报');

      st.dispose();
    });

    test('发位置报文 → 仍然说「位置已上报」（两档没混）', () {
      final st = AppState()
        ..setLocale('zh')
        ..myCall = 'BG7LZG'
        ..mySymbol = '>'
        ..myLat = 39.1
        ..myLng = 116.4
        ..myHasFix = true
        ..debugSetLinkUp(AppState.srcAprsIs, true);
      st.sendBeacon();
      expect(st.connInfo, contains('位置'));
      expect(st.connInfo, isNot(contains('状态报文')));

      st.dispose();
    });

    test('TNC 发射时状态文案也分档（TNC + 状态报文）', () {
      final st = AppState()
        ..setLocale('zh')
        ..myCall = 'BG7LZG'
        ..debugSetLinkUp(AppState.srcAprsIs, false)
        ..dataSource = AppState.srcTnc
        ..debugSetLinkUp(AppState.srcTnc, true);
      st.sendStatus();
      expect(st.connInfo, contains('TNC'));
      expect(st.connInfo, contains('状态报文'));

      st.dispose();
    });

    test('填了 PHG 但没定位：位置包不发，状态帧照发（这就是界面要提示的情形）', () {
      final st = AppState()
        ..myCall = 'BG7LZG'
        ..beaconPowerW = 25; // 有 PHG，但 myHasFix 仍为 false
      st.sendBeacon(); // 内部被 !myHasFix 挡回
      st.sendStatus();
      expect(st.packets.where((p) => p.type == 'position'), isEmpty,
          reason: '没有定位不能发位置包');
      expect(st.packets.where((p) => p.type == 'status'), isNotEmpty,
          reason: '状态帧不含坐标，无定位也能发');

      st.dispose();
    });
  });

  /// ─── 数据扩展必须**整块紧贴**（第三方解析器的前提）───
  ///
  /// 实测事故：v2.0.4 发出的备注是
  ///   `000/000 PHG2130 /A=000033 Bat:22% E4[中国人能飞]`
  /// —— 扩展之间被空格分隔。用参考实现 aprslib 解这条报文，结果是
  /// `phg` **完全缺失**、`PHG2130` 落进 comment 当普通文字：
  ///
  ///   aprslib.parse(… 'b000/000 PHG2130 /A=000033 …')
  ///   → {'altitude': 10.0584}   comment='PHG2130  Bat:22% …'
  ///
  /// 而 APRS101 第 9 章把这些字段定义为**固定长度的数据扩展**，直接拼在符号
  /// 之后、彼此之间**不用空格分隔**。6 万余条现网报文里「扩展内部带空格」的
  /// 样本是 **0 条**；真实台站长这样：
  ///   `!3155.21N/12016.69ErPHG1460/A=000071`
  ///   `!2155.17N/11052.40Eb000/000/A=000033`
  ///
  /// 所以这一组把「整块紧贴」钉死：**注释的第一段只能是 CsT / PHG / `/A=`
  /// 的紧贴拼接**，不允许出现空格。
  group('数据扩展必须整块紧贴（否则第三方读不出 PHG）', () {
    /// 用户实测那份配置的复现：4 W / 20 ft / 3 dB（→ `PHG2130`）、
    /// 手填海拔 10.0584 m（→ `/A=000033`）。
    AppState userSetup() => AppState()
      ..myCall = 'BG7LZQ'
      ..mySsid = 2
      ..mySymbol = 'b'
      ..myLat = 21 + 55.17 / 60
      ..myLng = 110 + 52.40 / 60
      ..myHasFix = true
      ..beaconPowerW = 4
      ..beaconAntennaHeightFt = 20
      ..beaconGainDb = 3
      ..beaconAltOverrideM = 10.0584
      ..beaconIncludeBattery = false
      ..myComment = 'E4[中国人能飞]';

    String sentRaw(AppState st) => st.packets
        .map((p) => p.raw)
        .firstWhere((r) => r.contains('PHG'), orElse: () => '');

    /// 注释（`:` 之后）的第一段 —— 也就是「数据扩展块」该在的位置。
    String firstToken(String raw) {
      final body = raw.substring(raw.indexOf(':') + 1);
      return body.split(' ').first;
    }

    /// ⚠ 这一条说的是**第二个**独立的坑：就算整块紧贴了，只要 CsT 排在 PHG
    /// 前面，PHG 一样读不出来 —— 参考实现 aprslib 的 `parse_data_extentions()`
    /// 先匹配 `^\d{3}/\d{3}`，命中后**只**再看 DF report，根本不再找 PHG。
    /// 实测（0.7.2）：`…Eb000/000PHG2130/A=000033` → `phg` 缺失、
    /// `PHG2130` 落进 comment；`…EbPHG2130/A=000033` → `phg=2130` ✓
    /// 所以**扩展块的首位让给 PHG，CsT 不发**（取舍见 state.dart 的注释）。
    test('速度/方位角开着 + 有 PHG：PHG 仍占首位，CsT 让位', () {
      final st = userSetup()
        ..beaconIncludeSpeed = true
        ..beaconIncludeCourse = true
        ..myCourse = 0
        ..mySpeed = 0;
      st.sendBeacon();
      final raw = sentRaw(st);
      expect(
        raw,
        'BG7LZQ-2>APALOC,TCPIP*:!2155.17N/11052.40EbPHG2130/A=000033 '
        'E4[中国人能飞]',
        reason: 'CsT 排在 PHG 前面时第三方读不出 PHG（两个都要求「最前」）',
      );
      expect(raw.contains('000/000'), isFalse,
          reason: 'PHG 在场时 CsT 必须整段不发，而不是挪到后面当备注文字');
      expect(raw.contains(' PHG'), isFalse, reason: '扩展之间不能有空格');
      expect(raw.contains('/A=000033 '), isTrue, reason: '空格应在扩展块与备注之间');

      st.dispose();
    });

    test('没有 PHG 时：CsT 照旧占首位（既有行为不变）', () {
      final st = userSetup()
        ..beaconPowerW = null
        ..beaconAntennaHeightFt = null
        ..beaconGainDb = null
        ..beaconIncludeSpeed = true
        ..beaconIncludeCourse = true
        ..myCourse = 0
        ..mySpeed = 0;
      st.sendBeacon();
      final raw = st.packets
          .map((p) => p.raw)
          .firstWhere((r) => r.contains('/A='), orElse: () => '');
      expect(
        raw,
        'BG7LZQ-2>APALOC,TCPIP*:!2155.17N/11052.40Eb000/000/A=000033 '
        'E4[中国人能飞]',
        reason: '没开 PHG 的台站，CsT//A= 的紧贴顺序与 v2.0.4 之前完全一致',
      );

      st.dispose();
    });

    test('关掉速度/方位角时：PHG 紧跟符号（= 标准报文形状）', () {
      final st = userSetup()
        ..beaconIncludeSpeed = false
        ..beaconIncludeCourse = false;
      st.sendBeacon();
      final raw = sentRaw(st);
      expect(
        raw,
        'BG7LZQ-2>APALOC,TCPIP*:!2155.17N/11052.40EbPHG2130/A=000033 '
        'E4[中国人能飞]',
        reason: '这是标准报文的形状（PHG 紧贴符号、/A= 紧贴 PHG）',
      );

      st.dispose();
    });

    test('不变量：注释第一段只由 CsT / PHG / /A= 紧贴拼成', () {
      final extOnly = RegExp(r'^(?:\d{3}/\d{3})?(?:PHG\d{4})?(?:/A=\d{6})?$');
      // 三种典型组合都要满足（含「一个都没有」时的空串）
      for (final (cse, phg, alt) in [
        (true, true, true),
        (false, true, true),
        (true, false, true),
        (false, false, true),
        (true, false, false),
        (false, false, false),
      ]) {
        final st = userSetup()
          ..beaconIncludeSpeed = cse
          ..beaconIncludeCourse = cse
          ..myCourse = cse ? 123.0 : null
          ..mySpeed = cse ? 20.0 : null
          ..beaconPowerW = phg ? 25 : null
          ..beaconAntennaHeightFt = phg ? 5120 : null
          ..beaconGainDb = phg ? 5 : null
          ..beaconAltOverrideM = alt ? 10.0584 : null;
        st.sendBeacon();
        final raw = sentRaw(st);
        final tok = raw.isEmpty ? '' : firstToken(raw);
        expect(extOnly.hasMatch(tok), isTrue,
            reason: 'cse=$cse phg=$phg alt=$alt 的首段是「$tok」，'
                '只能由紧贴的 CsT/PHG//A= 组成');
        expect(tok.contains(' '), isFalse);
        st.dispose();
      }
    });
  });
}

