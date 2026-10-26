import 'dart:io';

/// 桌面平台（dart:io 可用）的整机负载读数实现 —— 对外只经 `desktop_metrics.dart`。
///
/// 用途只有一个：随位置报文一起发出去（`CPU=42% MEM=63%`），让别人知道
/// 这台「挂在电脑上的台站」现在还扛不扛得住。手机上不存在这个需求，调用方
/// 只在桌面平台问它。
///
/// 做法是**不引第三方插件**：Linux 读 `/proc`，Windows 走 wmic（新系统上回退
/// 到 PowerShell 的 CIM），macOS 走 `ps` 与 `vm_stat`。任何一步失败都返回
/// null，报文里就少这两个字段 —— 宁可少发，也不发一个编出来的数字。
class DesktopMetrics {
  DesktopMetrics._();

  /// 本进程最近一次采样
  static ({int? cpu, int? mem})? latest;

  /// 上次采样时间（节流用：信标间隔再密，也不该每次去开一个进程）
  static DateTime? latestAt;

  /// 桌面平台才有意义；Web / 手机一律返回 false
  static bool get supported =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  /// 采样一次。[minGap] 之内的重复调用直接返回缓存，不再真的去读。
  static Future<({int? cpu, int? mem})?> refresh({
    Duration minGap = const Duration(seconds: 15),
  }) async {
    if (!supported) return null;
    final at = latestAt;
    if (at != null &&
        latest != null &&
        DateTime.now().difference(at) < minGap) {
      return latest;
    }
    ({int? cpu, int? mem})? r;
    try {
      if (Platform.isLinux) {
        r = await _linux();
      } else if (Platform.isWindows) {
        r = await _windows();
      } else {
        r = await _macos();
      }
    } catch (_) {
      r = null;
    }
    if (r != null) {
      latest = r;
      latestAt = DateTime.now();
    }
    return r;
  }

  // ─── Linux ───
  //
  // `/proc/stat` 第一行是整机累计的 CPU 时间片，必须两次相减才有「使用率」；
  // 所以第一次读不到比率（cpu 为 null），再等一小会儿读第二次。
  static ({int? cpu, int? mem})? _prevStat;

  static Future<({int? cpu, int? mem})?> _linux() async {
    final cpu = await _linuxCpu();
    final mem = await _linuxMem();
    return (cpu: cpu, mem: mem);
  }

  static Future<int?> _linuxCpu() async {
    Future<({int total, int idle})?> read() async {
      try {
        final text = await File('/proc/stat').readAsString();
        final line = text.split('\n').firstWhere(
              (l) => l.startsWith('cpu '),
              orElse: () => '',
            );
        if (line.isEmpty) return null;
        final f = line
            .split(RegExp(r'\s+'))
            .skip(1)
            .where((e) => e.isNotEmpty)
            .map(int.parse)
            .toList();
        if (f.length < 4) return null;
        final idle = f[3] + (f.length > 4 ? f[4] : 0); // idle + iowait
        return (total: f.fold<int>(0, (a, b) => a + b), idle: idle);
      } catch (_) {
        return null;
      }
    }

    var prev = _prevStat;
    if (prev == null) {
      prev = await read();
      if (prev == null) return null;
      await Future<void>.delayed(const Duration(milliseconds: 180));
    }
    final now = await read();
    if (now == null) return null;
    _prevStat = now;
    final dTotal = now.total - prev.total;
    final dIdle = now.idle - prev.idle;
    if (dTotal <= 0) return null;
    final used = (1 - dIdle / dTotal) * 100;
    return used.round().clamp(0, 100);
  }

  static Future<int?> _linuxMem() async {
    try {
      final text = await File('/proc/meminfo').readAsString();
      int? read(String key) {
        final m = RegExp('^$key:\\s+(\\d+)', multiLine: true).firstMatch(text);
        return m == null ? null : int.parse(m.group(1)!);
      }

      final total = read('MemTotal');
      final avail = read('MemAvailable');
      if (total == null || avail == null || total <= 0) return null;
      return ((1 - avail / total) * 100).round().clamp(0, 100);
    } catch (_) {
      return null;
    }
  }

  // ─── Windows ───
  static Future<({int? cpu, int? mem})?> _windows() async {
    var cpu = await _wmicValue(['cpu', 'get', 'LoadPercentage', '/value'],
        'LoadPercentage');
    int? mem;
    final os = await _wmicValues(
        ['OS', 'get', 'FreePhysicalMemory,TotalVisibleMemorySize', '/value'],
        ['FreePhysicalMemory', 'TotalVisibleMemorySize']);
    if (os != null) {
      final free = os['FreePhysicalMemory'];
      final total = os['TotalVisibleMemorySize'];
      if (free != null && total != null && total > 0) {
        mem = ((1 - free / total) * 100).round().clamp(0, 100);
      }
    }
    // wmic 在 Windows 11 24H2 之后默认不再安装：退回 PowerShell 的 CIM
    if (cpu == null && mem == null) {
      final ps = await _powershell(
          r'$o=Get-CimInstance Win32_OperatingSystem;'
          r'$c=(Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average;'
          r'"$([math]::Round($c)) $([math]::Round(100-($o.FreePhysicalMemory/$o.TotalVisibleMemorySize*100)))"');
      if (ps != null) {
        final parts = ps.trim().split(RegExp(r'\s+'));
        if (parts.length >= 2) {
          cpu = int.tryParse(parts[0])?.clamp(0, 100);
          mem = int.tryParse(parts[1])?.clamp(0, 100);
        }
      }
    }
    if (cpu == null && mem == null) return null;
    return (cpu: cpu, mem: mem);
  }

  static Future<int?> _wmicValue(List<String> args, String key) async {
    final m = await _wmicValues(args, [key]);
    return m?[key];
  }

  static Future<Map<String, int>?> _wmicValues(
      List<String> args, List<String> keys) async {
    try {
      final r = await Process.run(
        'wmic',
        args,
        stdoutEncoding: systemEncoding,
      ).timeout(const Duration(seconds: 4));
      if (r.exitCode != 0) return null;
      final out = '${r.stdout}';
      final map = <String, int>{};
      for (final k in keys) {
        final m = RegExp('$k=(\\d+)').firstMatch(out);
        if (m != null) map[k] = int.parse(m.group(1)!);
      }
      return map.isEmpty ? null : map;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _powershell(String script) async {
    try {
      final r = await Process.run(
        'powershell',
        ['-NoProfile', '-NonInteractive', '-Command', script],
        stdoutEncoding: systemEncoding,
      ).timeout(const Duration(seconds: 6));
      if (r.exitCode != 0) return null;
      final out = '${r.stdout}'.trim();
      return out.isEmpty ? null : out;
    } catch (_) {
      return null;
    }
  }

  // ─── macOS ───
  static Future<({int? cpu, int? mem})?> _macos() async {
    int? cpu;
    int? mem;
    try {
      // ps 的 %cpu 是「相对一个核」的占用，除以核数才是整机利用率
      final ps = await Process.run(
        'sh',
        ['-c', "ps -A -o %cpu= | awk '{s+=\$1} END {printf \"%.0f\", s}'"],
      ).timeout(const Duration(seconds: 6));
      final sum = double.tryParse('${ps.stdout}'.trim());
      final cores = Platform.numberOfProcessors;
      if (sum != null && cores > 0) {
        cpu = (sum / cores).round().clamp(0, 100);
      }
      final size = await Process.run('sysctl', ['-n', 'hw.memsize'])
          .timeout(const Duration(seconds: 4));
      final total = int.tryParse('${size.stdout}'.trim());
      final vm = await Process.run('vm_stat').timeout(const Duration(seconds: 4));
      if (total != null && total > 0) {
        final text = '${vm.stdout}';
        int pages(String key) {
          final m = RegExp('$key:\\s+(\\d+)').firstMatch(text);
          return m == null ? 0 : int.parse(m.group(1)!);
        }

        // 空闲 + 可回收（inactive）算「没在用」，与活动监视器的口径接近
        final free = pages('Pages free') + pages('Pages inactive');
        final pageSize = RegExp(r'page size of (\d+) bytes').firstMatch(text);
        final ps2 = pageSize == null ? 4096 : int.parse(pageSize.group(1)!);
        final used = total - free * ps2;
        if (used > 0) mem = (used / total * 100).round().clamp(0, 100);
      }
    } catch (_) {
      // 一项失败就用另一项，全失败返回 null
    }
    if (cpu == null && mem == null) return null;
    return (cpu: cpu, mem: mem);
  }
}

