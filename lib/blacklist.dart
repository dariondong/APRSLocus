import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// ─── 远程限制名单（黑名单）───
///
/// 从官网读一份 JSON（`assets/blacklist.json`）；命中则不允许继续使用本软件
/// （用户协议第 8.2 条：违反协议的，我们有权限制、暂停或终止其使用）。
///
/// ── 三条设计原则（都是"别把自己坑了"）──
///
///  1. **失败放行**：第一次拉取失败（离线 / 接口挂了 / JSON 坏了）**不拦人**。
///     否则一次网络抖动就把所有用户挡在门外 —— 那比没有这个功能更糟。
///  2. **命中后离线也拦**：一旦**成功**拉到过名单（有缓存），命中就继续拦。
///     否则被限制的人只要关掉网络就能接着用。
///  3. **这只是"客户端礼貌拦截"**：本软件是 GPL-3.0 开源，任何人都能自己编译一份
///     去掉这段检查的版本。它挡的是"用官方安装包的人"，不是有心人 —— 真正的约束在
///     APRS-IS 侧（passcode 失效）。把这条写在代码里，免得以后有人以为它很硬。
///
/// ── 名单文件格式（官网 `docs/assets/blacklist.json`）──
/// ```json
/// { "updated": "2026-10-02",
///   "entries": [ { "call": "BG7LZQ-9",  "reason": "…", "at": "2026-10-02" },
///                { "call": "BG7LZQ-*", "reason": "…" },   // 该呼号的任意 SSID
///                { "device": "9f2c…", "reason": "…" } ] }
/// ```
/// `call` 支持 `*` 通配符（大小写不敏感），规则见 [BlacklistEntry.hitsCall]。
/// 一句话：**写裸呼号 = 封这个人**（含他的所有 SSID）；写 `CALL-N` = 只封那一台。
///
/// 两条"防止自己把自己坑了"的作废规则：一条里 `call` / `device` 都空 → 永不命中；
/// `call` 里**一个非通配符字符都没有**（比如只写 `*` 或 `-*`）→ 同样作废 ——
/// 否则手滑一个星号就把所有用户挡在门外。
class BlacklistEntry {
  final String? call;    // 呼号模式（大写；可含 `*` 通配符，大小写不敏感）
  final String? device;  // 安装标识（见 [Blacklist.deviceId]）
  final String reason;   // 给用户看的原因（可空）
  final String at;       // 列入日期（可空）

  /// **硬封**（默认）：命中后不能用长按安装标识的本地白名单豁免。
  /// 写 `"hard": false` 变软封（长按可解）。缺省是硬封 —— 名单是"封人"的，
  /// 默认就该封得住；想让对方能自救再显式放宽。
  final bool hard;

  const BlacklistEntry({
    this.call,
    this.device,
    this.reason = '',
    this.at = '',
    this.hard = true,
  });

  /// 这条到底能不能用来拦人。
  ///
  /// 呼号侧要求**至少有一个非通配符字符**：只写 `*`（或 `-*`）等于"拦所有人"，
  /// 一律作废 —— 名单是手写的，手滑一个星号不能把整个用户群挡在门外。
  bool get usable =>
      (call != null &&
          call!.replaceAll('*', '').replaceAll('-', '').isNotEmpty) ||
      (device != null && device!.isNotEmpty);

  /// 该呼号是否命中本条目（大小写不敏感）。四条规则：
  ///
  ///   1. `CALL`（不带 SSID、也不带 `*`）→ **封这个呼号**：`CALL` 本身与它的**任意 SSID**
  ///      （0–15）都算 —— 写 `BG7LZQ` 就命中 `BG7LZQ`、`BG7LZQ-9`、`BG7LZQ-7`、`BG7LZQ-15`。
  ///      这是最常用的一条：封人，不封某一台设备。
  ///   2. `CALL-N`（带 SSID）→ 只封**那一台**（精确相等，`BG7LZQ-7` 不命中 `BG7LZQ-9`）；
  ///   3. `CALL-*` → 与规则 1 等价（老写法，保留兼容）；
  ///   4. 其他位置的 `*` → 任意串（`BH7*`、`*LZQ-9`）。
  bool hitsCall(String call) {
    final c = call.trim().toUpperCase();
    final p = this.call;
    if (p == null || p.isEmpty || c.isEmpty) return false;
    if (!p.contains('-') && !p.contains('*')) {
      return _withSsids(p, c);                                  // 规则 1
    }
    if (!p.contains('*')) return p == c;                        // 规则 2
    final head = p.endsWith('-*') ? p.substring(0, p.length - 2) : null;
    if (head != null && head.isNotEmpty && !head.contains('*')) {
      return _withSsids(head, c);                               // 规则 3
    }
    // 规则 4：`*` → `.*`，其余字符转义后整体锚定
    return RegExp('^${p.split('*').map(RegExp.escape).join('.*')}\$')
        .hasMatch(c);
  }

  /// [base] 本身，或它的任意 SSID（APRS 的 SSID 是 1–2 位数字 —— 限数字是为了
  /// 不让 `BG7LZQ-1A` 这种无效写法被误伤）。
  static bool _withSsids(String base, String call) =>
      call == base ||
      RegExp('^${RegExp.escape(base)}-[0-9]{1,2}\$').hasMatch(call);

  static BlacklistEntry? fromJson(Object? j) {
    if (j is! Map) return null;
    String? s(Object? v) {
      final t = v?.toString().trim() ?? '';
      return t.isEmpty ? null : t;
    }

    return BlacklistEntry(
      call: s(j['call'])?.toUpperCase(),
      device: s(j['device'])?.toLowerCase(),
      reason: j['reason']?.toString() ?? '',
      at: j['at']?.toString() ?? '',
      // 只有**显式**写 false 才是软封；写成别的（字符串 "false" 之类）一律按硬封处理 ——
      // 手写的 JSON，宁可封得紧一点，也别因为写错类型而悄悄放开。
      hard: j['hard'] is bool ? (j['hard'] as bool) : true,
    );
  }
}

/// 命中的结果（界面拿它显示原因）
class BlacklistHit {
  final String reason;
  final String matched;   // 命中的是哪一项（呼号 / 安装标识），用于如实显示

  /// 硬封（条目里 `hard`，**默认就是硬封**）：命中后**不能**用长按安装标识的
  /// 本地白名单豁免。写 `"hard": false` 才是软封（长按能解）。
  final bool hard;

  const BlacklistHit(this.reason, this.matched, {this.hard = true});
}

class Blacklist {
  /// 官网基址（与用户协议、公告同一个站点）
  static const String kBase = 'https://aprslocus.theez.top/';
  static const String kPath = 'assets/blacklist.json';

  static const String _kCache = 'blacklistCacheJson';
  static const String _kCheckedAt = 'blacklistCheckedAt';
  static const String _kDeviceId = 'blacklistDeviceId';
  static const String _kLocalExempt = 'blacklistLocalExempt';

  /// 拉到新名单后多久再拉一次
  static const Duration kRefresh = Duration(hours: 6);

  final List<BlacklistEntry> entries;
  final String updated;

  const Blacklist(this.entries, {this.updated = ''});

  /// 解析名单。**坏 JSON / 结构不对一律返回 null**（调用方按"失败放行"处理）。
  static Blacklist? parse(String text) {
    try {
      final j = jsonDecode(text);
      if (j is! Map) return null;
      final raw = j['entries'];
      if (raw is! List) return null;
      final out = <BlacklistEntry>[];
      for (final it in raw) {
        final e = BlacklistEntry.fromJson(it);
        if (e != null && e.usable) out.add(e);   // 空条目不进表（见类注释）
      }
      return Blacklist(out, updated: j['updated']?.toString() ?? '');
    } catch (_) {
      return null;
    }
  }

  /// 命中判断：呼号（支持 `*` 通配符，见 [BlacklistEntry.hitsCall]）或安装标识
  /// （精确、小写）任一命中即命中。
  ///
  /// [exemptSoft] = 本机白名单已开（长按安装标识）：此时**软封**条目被跳过，
  /// **硬封**条目照样命中 —— 这正是"硬封 = 不能长按豁免"的落点。两项都命中时，
  /// 硬的那条一定赢（软的被 continue 掉，硬的一定会被返回）。
  BlacklistHit? match(String call, String deviceId, {bool exemptSoft = false}) {
    final d = deviceId.trim().toLowerCase();
    for (final e in entries) {
      if (exemptSoft && !e.hard) continue;              // 软封：本机可豁免
      if (e.hitsCall(call)) {
        return BlacklistHit(e.reason, e.call!, hard: e.hard);
      }
      if (e.device != null && e.device == d && d.isNotEmpty) {
        return BlacklistHit(e.reason, e.device!, hard: e.hard);
      }
    }
    return null;
  }

  /// 本机是否已被**本地豁免**（本地白名单）。
  ///
  /// 在拦截页 / 「设置 → 关于」**长按本机安装标识**可切换。为什么留这个口子：
  /// 这本来就是客户端礼貌拦截（GPL 开源，自己编译一份就能绕），与其逼人去改源码，
  /// 不如给一个明确的、**只留在本机**的出口。
  ///
  /// ⚠ 代价要说清楚：被限制的人长按一下就能自己解封 —— 它挡的是"不想折腾的人"，
  /// 不是有心人。真要硬封，得去掉这个开关。
  static Future<bool> localExempt() async {
    try {
      final p = await SharedPreferences.getInstance();
      return p.getBool(_kLocalExempt) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// 切换/设置本地白名单（见 [localExempt]）。
  static Future<void> setLocalExempt(bool v) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(_kLocalExempt, v);
    } catch (_) {}
  }

  /// 稳定的安装标识：**随机生成一次**存在本地。
  ///
  /// 为什么不用硬件号：Android 早就限制读取（要特权），而且那属于设备隐私 ——
  /// 我们只需要一个"能被列进名单、也能在误判时对得上"的名字。
  /// ⚠ 它**只存在于本机**：应用只**下载**名单，从不上传这个标识（重装/清数据会换新的）。
  static Future<String> deviceId() async {
    try {
      final p = await SharedPreferences.getInstance();
      final cur = p.getString(_kDeviceId);
      if (cur != null && cur.isNotEmpty) return cur;
      final r = Random.secure();
      final id = List.generate(32, (_) => r.nextInt(16).toRadixString(16)).join();
      await p.setString(_kDeviceId, id);
      return id;
    } catch (_) {
      return '';
    }
  }

  /// 读本地缓存的名单（没有 / 坏了 → null）
  static Future<Blacklist?> cached() async {
    try {
      final p = await SharedPreferences.getInstance();
      final s = p.getString(_kCache);
      if (s == null || s.isEmpty) return null;
      return parse(s);
    } catch (_) {
      return null;
    }
  }

  /// 上次成功拉取的时间（给节流用）
  static Future<DateTime?> lastChecked() async {
    try {
      final p = await SharedPreferences.getInstance();
      final ms = p.getInt(_kCheckedAt);
      return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
    } catch (_) {
      return null;
    }
  }

  /// 拉一份新名单并写缓存。**失败返回 null**（调用方据此沿用缓存 / 放行）。
  static Future<Blacklist?> fetch(
      {Duration timeout = const Duration(seconds: 8)}) async {
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = timeout;
      final url = Uri.parse(kBase).resolve(kPath).toString();
      final req = await client.getUrl(Uri.parse(url));
      req.headers.set(HttpHeaders.userAgentHeader, 'APRSlocus');
      final res = await req.close();
      if (res.statusCode != 200) return null;
      final text = await res.transform(utf8.decoder).join().timeout(timeout);
      final bl = parse(text);
      if (bl == null) return null;
      final p = await SharedPreferences.getInstance();
      await p.setString(_kCache, text);
      await p.setInt(_kCheckedAt, DateTime.now().millisecondsSinceEpoch);
      return bl;
    } catch (_) {
      return null;      // 失败放行（见类注释第 1 条）
    } finally {
      client?.close(force: true);
    }
  }
}
