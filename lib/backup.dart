import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'translate.dart';

/// ─── 备份与恢复（纯逻辑，不依赖 Widget）───
///
/// 设计要点（三条都是「不这么写就会出真问题」的教训）：
///
/// 1. **按分组导出/导入**：用户可能只想搬设置，也可能想连消息一起搬。
///    所以内容切成若干组，导出与导入都可勾选；导入以**组**为单位整组覆盖，
///    不存在「导入一半」的中间状态。
///
/// 2. **只回写白名单里的键**：备份文件是用户可见、可手工编辑、也可能来自
///    别人分享的文本。若无脑回写「文件里出现的任意键」，一份伪造的文件就能
///    改写应用里任何偏好（包括未来新增的内部状态键，例如各种缓存标志）。
///    所以键必须落在分组白名单内；白名单外的键**跳过并计数**，而不是静默应用。
///    同理，导入时按分组过滤，不认识的组直接忽略。
///
/// 3. **值带类型标签**：JSON 分不清 `int 1` 与 `double 1.0`，而
///    SharedPreferences 的 `getDouble` 读到 int 值会抛类型错误。故每个值写成
///    `{"s": …} / {"b": …} / {"i": …} / {"d": …} / {"l": […]}`，
///    导入时按标签调用对应的 setter —— 即使文件被手工改过类型也不会把应用写坏。

/// 备份文件的身份标识。导入时先认这个字段，避免把任意 JSON 当备份解析。
const String kBackupKind = 'aprslocus-backup';

/// 备份格式版本。只增不减；导入时遇到**更高**的 schema 会拒绝而不是猜。
/// v1：分组 + 带类型标签的值。
const int kBackupSchema = 1;

/// 备份内容分组。新增分组时同时补 [kBackupGroups] 与 l10n 文案。
enum BackupCategory { settings, stations, messages, chats, translate, honors, theme }

/// 一个分组包含哪些 SharedPreferences 键。
///
/// [keys] 是精确键；[prefixes] 是动态键前缀（会话级/按呼号的键，数量不定）。
/// 白名单必须与 state.dart / translate.dart / achievements.dart /
/// early_member.dart 里真正读写的键保持一致 —— 漏一个键的表现是
/// 「备份导出成功，但恢复后那项设置没回来」，非常隐蔽，所以新增偏好键时
/// 要顺手加到这里（tool/check_backup_keys.py 会把它揪出来）。
class BackupGroupSpec {
  final BackupCategory id;
  final List<String> keys;
  final List<String> prefixes;

  const BackupGroupSpec(this.id, this.keys, {this.prefixes = const []});
}

const List<BackupGroupSpec> kBackupGroups = [
  // 设置配置：电台身份、信标、地图/主题、筛选、数据来源、服务器、ADIF 选项、位置
  BackupGroupSpec(BackupCategory.settings, [
    'myCall', 'mySsid', 'mySymbol', 'myComment',
    'beacon', 'beaconAutoAsked', 'beaconInterval',
    // 纯网络模式的专用上报间隔：属于「信标内容/节奏偏好」，换机后应保留
    'beaconNetInterval',
    'smartBeaconOn', 'smartTiers',
    'beaconIncludeSpeed', 'beaconIncludeCourse', 'beaconIncludeBattery',
    // 手填的位置报文数据扩展（高度 / 功率 / 天线高度 / 增益）：属于「信标内容偏好」，
    // 是用户照着自己电台手打的，换机后必须保留 —— 丢了会表现为
    // 「信标里那几项悄悄没了」，而用户不知道要重新填。
    // beaconAltOverrideM 只在用户手填过海拔时才存在；没填过就是「跟随定位」，
    // 键缺失正好回到那个默认，不需要迁移。
    'beaconPowerW', 'beaconAntennaHeightFt', 'beaconGainDb', 'beaconAltOverrideM',
    // 独立状态报文的文本：同上，是用户手打的，换机后应保留。
    'aprsStatusText',
    // 心率（BLE 心率带 / 佳明 LiveTrack 都会用到）：属于**信标内容偏好**，
    // 换机后当然希望还按自己调的那样上报。
    'beaconIncludeHr',
    // 里程附带（TRV/ODO）与累计总里程：属于「信标内容 + 累计数据」，
    // 换机后当然希望继续累计、按自己调的那样上报。
    'beaconIncludeTripMileage', 'beaconIncludeTotalMileage', 'totalMileageKm',
    // 强制接受网络定位自动上报：同上 —— 这是用户对**上报行为**的知情选择，
    // 而且他的设备很可能正是因为**没有 GPS** 才需要它。丢了它换机后自动上报
    // 会静默变回「一直不报」，而用户不知道为什么（界面只显示「网络定位中」）。
    'beaconForceCoarse',
    // 记住的心率带与佳明 LiveTrack 链接：都是「用户自己配的外部设备」，
    // 不该在换机后丢（重新找一遍设备/再问一次链接很烦）。
    'bleHrId', 'bleHrName', 'garminUrl',
    'coordDatum', 'darkMode', 'weatherEnabled', 'locale', 'themeColor',
    // 公告横幅：与深色模式同类的**显示偏好** —— 用户关掉了它，
    // 换机后不该被静默打开（那会表现为「怎么又开始联网拉公告了」）。
    'noticeBanner',
    // 已提醒过的更新版本：与公告开关同属「显示/打扰偏好」——换机后不该
    // 因为丢了它而对已经提醒过的版本再弹一次（也不该阻止新版本提醒）。
    'updatePromptedVersion',
    // 界面材质（磨砂玻璃 / 云母）：与深色模式、界面缩放同类的**显示偏好**，
    // 用户换机后当然希望屏幕还是他调好的那副样子。
    'uiMaterial',
    // 界面布局（1.0 经典 / 2.0 地图为基底）：同上 —— 换机后不该被静默换回 1.0，
    // 那会让用户以为「新机上的应用长得不一样」。
    'uiLayout',
    'uiScale', 'mapType', 'updateChannel',
    // 离线地图：缓存开关、仅离线模式，以及**区域记录**（只有范围与进度，
    // 瓦片本体是文件不随备份走 —— 换机后区域记录还在，重新点「继续」即可）
    'tileCacheOn', 'offlineOnly', 'offlineRegions',
    'adifMode', 'adifSubMode', 'adifBand', 'adifFreq', 'adifStripSsid',
    'locationMode', 'useSimLocation',
    'filterLat', 'filterLng', 'filterRadius', 'maxStations', 'maxPackets',
    'onlineWindowMin', 'maxTrackPts', 'filterFollow',
    'receiveCountries', 'receiveOthers', 'labLandscape', 'oobeDone',
    // 功能引导的「已看过」集合：与 oobeDone 同类（都是「新手引导走没走过」）。
    // 换机后不该把用户已经看过的提示卡再弹一遍 —— 那正是引导最烦人的地方。
    'guideSeen',
    'sensorAssist',
    'server', 'port', 'passcode', 'dataSource', 'enabledSources',
    'igateEnabled', 'igateTwoWay',
    'myLat', 'myLng',
    // 链路配置（TNC / 声卡 TNC / PKWDWPL）与各自上次选的设备。
    //
    // 这 5 个键是 tool/check_backup_keys.py 补强后「查」出来的：原先只扫
    // 字面量键，而这几个是通过 `static const _kConfig` 这类常量读写的，
    // 于是整套链路配置在备份里**静默缺失** —— 用户换机后要重新配蓝牙
    // 设备与串口。备份功能里这种缺失最致命：以为备了，直到恢复那天才发现。
    'tncConfigJson', 'tncDeviceJson',
    'audioConfigJson',
    'pkwdwplConfigJson', 'pkwdwplDeviceJson',
  ]),
  // 台站与联系人：整份 stations JSON（收藏/手动添加/备注）
  BackupGroupSpec(BackupCategory.stations, ['stations']),
  // 消息记录：单聊消息 + 两套已读时间点
  BackupGroupSpec(BackupCategory.messages, ['messages', 'readAt', 'groupReadAt']),
  // 群聊：群组、成员状态
  BackupGroupSpec(BackupCategory.chats, ['chatGroups']),
  // 翻译设置：接口/密钥/语言；缓存（translateCacheJson）是可直接再生成的，
  // 不放进备份（导入旧缓存反而会把新翻译顶掉）
  BackupGroupSpec(
    BackupCategory.translate,
    ['translateConfigJson'],
    prefixes: ['transPref_'],
  ),
  // 成就与荣誉：解锁记录、计数、FIRST FIX 名单、荣誉定义缓存与用户选择的展示徽章
  BackupGroupSpec(
    BackupCategory.honors,
    [
      'achievements', 'achCounts', 'firstFixHolders',
      'honorDefsJson', 'honorsCacheJson', 'primariesJson',
    ],
    prefixes: ['honorPrimary_'],
  ),
  // 主题：用户自建的全部主题 + 当前激活项（一份 JSON）。
  //
  // 注意**不含**导入的图标图片文件本身：那些是二进制，塞进 JSON 会把备份
  // 从几十 KB 撑到几 MB，而字符串化的 base64 也无法人工编辑。所以主题里
  // 的 `file:` 引用在异机恢复后会回退成内置图标（界面不会坏，只是图标变默认）。
  //
  // 键名通过 ThemeController.kPrefsKey 常量读写，因此静态检查器看不到字面量；
  // 它已被登记在 tool/check_backup_keys.py 的说明里。
  BackupGroupSpec(BackupCategory.theme, ['themeBundle']),
];

BackupGroupSpec backupGroupSpec(BackupCategory id) =>
    kBackupGroups.firstWhere((g) => g.id == id);

/// 该键是否允许出现在某分组的备份里
bool backupKeyAllowed(BackupCategory id, String key) {
  final spec = backupGroupSpec(id);
  if (spec.keys.contains(key)) return true;
  for (final p in spec.prefixes) {
    if (key.startsWith(p)) return true;
  }
  return false;
}

/// 已解析的备份内容
class BackupData {
  final int schema;
  final String appVersion;
  final DateTime? exportedAt;
  final String platform;

  /// 分组 → （键 → 已解码的值）。只含白名单内的键。
  final Map<BackupCategory, Map<String, Object?>> groups;

  /// 解析时被跳过的键数（白名单外/值类型不可识别）——用于向用户如实汇报
  final int skippedKeys;

  const BackupData({
    required this.schema,
    required this.appVersion,
    required this.exportedAt,
    required this.platform,
    required this.groups,
    this.skippedKeys = 0,
  });

  int get totalKeys =>
      groups.values.fold(0, (sum, g) => sum + g.length);

  List<BackupCategory> get categories {
    // 按 kBackupGroups 的固定顺序输出，UI 才不会每次点开都换顺序
    return kBackupGroups
        .map((g) => g.id)
        .where(groups.containsKey)
        .toList();
  }

  int countOf(BackupCategory id) => groups[id]?.length ?? 0;
}

/// 解析失败的原因（由 UI 翻译成用户的提示语）
enum BackupErrorCode { notJson, notBackup, schemaNewer, empty }

class BackupException implements Exception {
  final BackupErrorCode code;

  /// 供排查用的细节，不直接展示给用户
  final String? detail;

  const BackupException(this.code, [this.detail]);

  @override
  String toString() => 'BackupException($code${detail == null ? '' : ': $detail'})';
}

/// 把一份偏好快照编码成备份 JSON 文本。
///
/// [snapshot] 来自 [snapshotFromPrefs]；[categories] 是要包含的分组。
String buildBackupJson({
  required Map<String, Object?> snapshot,
  required Set<BackupCategory> categories,
  required String appVersion,
  required String platform,
  DateTime? now,
}) {
  final groups = <String, Map<String, Object?>>{};
  for (final spec in kBackupGroups) {
    if (!categories.contains(spec.id)) continue;
    final values = backupGroupValues(spec.id, snapshot);
    if (values.isEmpty) continue;
    // 翻译缓存（translateCacheJson）有意不进备份：它随时能由接口再生成，
    // 而导入一份旧缓存反而会把用户已有的新翻译顶掉。
    // 显式排除优于「不写进白名单」——后者会让白名单检查工具把它当成
    // 「新增偏好忘了归组」，从而逼着后来人加回一个错误的东西。
    final encoded = <String, Object?>{};
    values.forEach((k, v) {
      if (k == TranslateService.kCachePrefKey) return;
      final enc = encodeBackupValue(v);
      // backupGroupValues 只吐出偏好支持的类型，这里必然可编码；
      // 万一不是（未来新增了未支持的类型），跳过比写坏文件好。
      if (enc != null) encoded[k] = enc;
    });
    if (encoded.isEmpty) continue;
    groups[spec.id.name] = encoded;
  }
  final out = <String, Object?>{
    'kind': kBackupKind,
    'schema': kBackupSchema,
    'appVersion': appVersion,
    'exportedAt': (now ?? DateTime.now()).toUtc().toIso8601String(),
    'platform': platform,
    'groups': groups,
  };
  return const JsonEncoder.withIndent('  ').convert(out);
}

/// 从偏好快照里挑出某分组的内容（原值，未编码）。
Map<String, Object?> backupGroupValues(
  BackupCategory id,
  Map<String, Object?> snapshot,
) {
  final spec = backupGroupSpec(id);
  final out = <String, Object?>{};
  for (final k in spec.keys) {
    final v = snapshot[k];
    if (v != null) out[k] = v;
  }
  for (final k in snapshot.keys) {
    if (out.containsKey(k)) continue;
    var hit = false;
    for (final p in spec.prefixes) {
      if (k.startsWith(p)) {
        hit = true;
        break;
      }
    }
    if (hit && snapshot[k] != null) out[k] = snapshot[k];
  }
  return out;
}

/// 分组 → 条目数（导出前给用户看「这组有多少项」）
Map<BackupCategory, int> backupCounts(
  Map<String, Object?> snapshot,
  Set<BackupCategory> categories,
) {
  final out = <BackupCategory, int>{};
  for (final spec in kBackupGroups) {
    if (!categories.contains(spec.id)) continue;
    out[spec.id] = backupGroupValues(spec.id, snapshot).length;
  }
  return out;
}

/// 带类型标签地编码一个偏好值；不支持的返回 null
Object? encodeBackupValue(Object? v) {
  if (v is String) return {'s': v};
  if (v is bool) return {'b': v};
  if (v is int) return {'i': v};
  if (v is double) return {'d': v};
  if (v is List) {
    final out = <String>[];
    for (final e in v) {
      if (e is! String) return null;
      out.add(e);
    }
    return {'l': out};
  }
  return null;
}

/// 解码一个带类型标签的值；不识别返回 null
Object? decodeBackupValue(Object? raw) {
  if (raw is! Map || raw.length != 1) return null;
  final e = raw.entries.first;
  final v = e.value;
  switch (e.key) {
    case 's':
      return v is String ? v : null;
    case 'b':
      return v is bool ? v : null;
    case 'i':
      return v is int ? v : null;
    case 'd':
      return v is num ? v.toDouble() : null;
    case 'l':
      if (v is! List) return null;
      final out = <String>[];
      for (final x in v) {
        if (x is! String) return null;
        out.add(x);
      }
      return out;
  }
  return null;
}

/// SharedPreferences 全量快照（键 → 原值）
Map<String, Object?> snapshotFromPrefs(SharedPreferences p) {
  final out = <String, Object?>{};
  for (final k in p.getKeys()) {
    final v = p.get(k);
    if (v != null) out[k] = v;
  }
  return out;
}

/// 解析备份 JSON。任何不合法都抛 [BackupException]，绝不「尽量猜」。
BackupData parseBackupJson(String text) {
  Object? raw;
  try {
    raw = jsonDecode(text);
  } catch (e) {
    throw BackupException(BackupErrorCode.notJson, '$e');
  }
  if (raw is! Map) {
    throw const BackupException(BackupErrorCode.notBackup);
  }
  if (raw['kind'] != kBackupKind) {
    throw const BackupException(BackupErrorCode.notBackup);
  }
  final schema = raw['schema'];
  if (schema is! int) {
    throw const BackupException(BackupErrorCode.notBackup);
  }
  if (schema > kBackupSchema) {
    throw BackupException(BackupErrorCode.schemaNewer, 'schema=$schema');
  }
  final rawGroups = raw['groups'];
  if (rawGroups is! Map) {
    throw const BackupException(BackupErrorCode.notBackup);
  }

  final byName = {for (final g in kBackupGroups) g.id.name: g.id};
  final groups = <BackupCategory, Map<String, Object?>>{};
  var skipped = 0;
  for (final entry in rawGroups.entries) {
    final id = byName['${entry.key}'];
    if (id == null) {
      // 不认识的组：可能是更新版本新增的 —— 跳过（拒绝整份文件更不友好）
      skipped++;
      continue;
    }
    final m = entry.value;
    if (m is! Map) {
      skipped++;
      continue;
    }
    final values = <String, Object?>{};
    for (final kv in m.entries) {
      final key = '${kv.key}';
      final val = decodeBackupValue(kv.value);
      if (val == null || !backupKeyAllowed(id, key)) {
        skipped++;
        continue;
      }
      values[key] = val;
    }
    if (values.isNotEmpty) groups[id] = values;
  }
  if (groups.isEmpty) {
    throw const BackupException(BackupErrorCode.empty);
  }

  final at = raw['exportedAt'];
  return BackupData(
    schema: schema,
    appVersion: '${raw['appVersion'] ?? ''}',
    exportedAt: at is String ? DateTime.tryParse(at) : null,
    platform: '${raw['platform'] ?? ''}',
    groups: groups,
    skippedKeys: skipped,
  );
}

class BackupApplyResult {
  final int applied;
  final int skipped;
  final Set<BackupCategory> groups;

  const BackupApplyResult({
    required this.applied,
    required this.skipped,
    required this.groups,
  });
}

/// 把备份里的指定分组写入偏好。逐组整组覆盖（组内键直接覆盖，不做合并）。
Future<BackupApplyResult> applyBackup(
  BackupData data,
  Set<BackupCategory> categories, {
  SharedPreferences? prefs,
}) async {
  final p = prefs ?? await SharedPreferences.getInstance();
  var applied = 0;
  var skipped = 0;
  final done = <BackupCategory>{};
  for (final entry in data.groups.entries) {
    if (!categories.contains(entry.key)) continue;
    for (final kv in entry.value.entries) {
      // 解析时已过滤过白名单，这里再查一次是防御（BackupData 可能被别处构造）
      if (!backupKeyAllowed(entry.key, kv.key)) {
        skipped++;
        continue;
      }
      final v = kv.value;
      try {
        if (v is String) {
          await p.setString(kv.key, v);
        } else if (v is bool) {
          await p.setBool(kv.key, v);
        } else if (v is int) {
          await p.setInt(kv.key, v);
        } else if (v is double) {
          await p.setDouble(kv.key, v);
        } else if (v is List<String>) {
          await p.setStringList(kv.key, v);
        } else {
          skipped++;
          continue;
        }
        applied++;
      } catch (_) {
        skipped++;
      }
    }
    done.add(entry.key);
  }
  return BackupApplyResult(applied: applied, skipped: skipped, groups: done);
}

/// 备份文件名（本地时间，便于用户在人堆里认出哪份）
String backupFileName(DateTime now) {
  String two(int v) => v.toString().padLeft(2, '0');
  return 'APRSlocus_backup_${now.year}${two(now.month)}${two(now.day)}'
      '_${two(now.hour)}${two(now.minute)}${two(now.second)}.json';
}
