/// ─── 群聊协议（APRS 上的自订应用层）───
///
/// APRS 本身没有「群聊」概念，只有**消息**（`:` 开头的 addressee 字段）。
/// 因此群聊是在 APRS 消息之上自订的一层协议：
///   * 群呼号 = `{群主呼号}-G{序号}`，成员把它当收件人广播，所有成员都能收到；
///   * 成员管理（邀请 / 确认 / 拒绝 / 退出 / 申请）用**私信**发给群主。
///
/// ## 为什么要单独成文件并重写成状态机
///
/// 原实现把协议判定散在 `state.dart` 的四个函数里，每个函数各自判断一遍
/// `upper.startsWith(...)`，并且用 `substring(13)` 这种**按长度切**的方式取值。
/// 这类写法的问题不是「不好看」，而是会实实在在产生 bug：
///
///   1. **同一句话被两处解析，结果不一致** —— 群内的 `【JOIN】` 与私信的
///      `JOIN_CONFIRM`/`JOIN_REQ` 是同一个语义，却写在两个分支里；
///      只补一处就会漏掉另一处（历史上正是如此）。
///   2. **按固定长度 substring 太脆** —— `upper.substring(13)` 依赖
///      `'JOIN_CONFIRM '` 恰好 13 字符；一旦命令名改动或前后有空格，
///      取到的就是半个呼号，而且**不会报错**，只会静默把成员记错。
///   3. **命令字大小写/前后缀组合爆炸** —— `[JOIN]`/`【JOIN】`/`JOIN_REQ`…
///      每加一种写法就要在每处判断里各加一次。
///
/// 现在统一收口：**解析只做一次**（[GroupProto.parse]），产出结构化的
/// [GroupMsg]，调用方只按 `kind` 分派，取值一律走「切词」而不是「数字符」。
library;

/// 群里会用到的协议命令
enum GroupKind {
  /// 群主 → 成员：邀请入群（私信）
  invite,

  /// 成员 → 群主：同意加入（私信）
  joinConfirm,

  /// 成员 → 群主：拒绝加入（私信）
  decline,

  /// 成员 → 群主：主动申请加入（私信）
  joinRequest,

  /// 成员 → 群主：退出（私信）
  leave,

  /// 群内广播：某人加入了（兼容旧版的 `[JOIN]`）
  memberJoined,

  /// 群内广播：某人离开了
  memberLeft,
}

/// 解析后的一条协议消息（**结构化**，调用方不再需要碰字符串）
class GroupMsg {
  final GroupKind kind;

  /// 群呼号（邀请/确认/拒绝/退出/申请都带）
  final String groupCall;

  /// 群名（仅 [GroupKind.invite] 有）或成员呼号（[memberJoined]/[memberLeft]）
  final String name;

  const GroupMsg(this.kind, {this.groupCall = '', this.name = ''});

  @override
  String toString() => 'GroupMsg($kind, group=$groupCall, name=$name)';
}

/// 群聊协议编解码 + 校验
class GroupProto {
  GroupProto._();

  /// 协议版本号。
  ///
  /// **刻意不塞进每条消息**：群聊消息本身就是 APRS 报文，射频上每字节都
  /// 要占用信道；而协议本身是「命令 + 参数」的自描述形式，新旧版本天然
  /// 可以并存（[parse] 同时接受旧写法）。版本号只用于本地日志与排查。
  static const String version = 'G2';

  /// 群呼号最大长度（AX.25 呼号字段 6 字符 + `-G{序号}`，总长不超过 9）。
  /// 超长会在编 AX.25 帧时被截断，对方就收不到 —— 必须在源头拦住。
  static const int maxGroupCallLen = 9;

  /// 群名最大长度（字符）。按 UTF-8 计不能超过消息文本上限的三分之一，
  /// 否则一条邀请都发不出去。
  static const int maxGroupNameLen = 24;

  // ─── 编码 ───

  static String invite(String groupCall, String name) =>
      'INVITE ${groupCall.trim().toUpperCase()} ${name.trim()}';

  static String joinConfirm(String groupCall) =>
      'JOIN_CONFIRM ${groupCall.trim().toUpperCase()}';

  static String decline(String groupCall) =>
      'DECLINE ${groupCall.trim().toUpperCase()}';

  static String joinRequest(String groupCall) =>
      'JOIN_REQ ${groupCall.trim().toUpperCase()}';

  static String leave(String groupCall) =>
      'LEFT ${groupCall.trim().toUpperCase()}';

  /// 群内广播的「我已加入」（新旧写法都发一遍会刷屏，只发一种）
  static String memberJoined(String call) => '【JOIN】${call.trim().toUpperCase()}';

  static String memberLeft(String call) => '【LEAVE】${call.trim().toUpperCase()}';

  // ─── 校验 ───

  /// 群名是否可用。返回错误码（null = 可用），由 UI 本地化。
  static String? validateName(String name) {
    final n = name.trim();
    if (n.isEmpty) return 'empty';
    // 换行/`:`会破坏 APRS 消息体结构（消息体以 `:` 分段）
    if (n.contains('\n') || n.contains('\r') || n.contains(':')) return 'invalid';
    if (n.runes.length > maxGroupNameLen) return 'too-long';
    return null;
  }

  /// 群呼号是否可用。
  ///
  /// 必须满足 APRS 呼号规则：字母数字 + 可选 `-SSID`，且总长 ≤ 9，
  /// 否则编出来的 AX.25 地址字段会被静默截断。
  static String? validateGroupCall(String call) {
    final c = call.trim().toUpperCase();
    if (c.isEmpty) return 'empty';
    if (c.length > maxGroupCallLen) return 'too-long';
    if (!RegExp(r'^[A-Z0-9]+(-[A-Z0-9]{1,2})?$').hasMatch(c)) return 'invalid';
    return null;
  }

  // ─── 解析 ───

  /// 把一条 APRS 消息文本解析成协议消息；不是协议消息时返回 null。
  ///
  /// **这是协议判定的唯一入口**：无论它是私信还是群内广播，都走这里，
  /// 因此不存在「只补了一处判断」的可能。
  static GroupMsg? parse(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    final upper = text.toUpperCase();

    // ── 群内广播写法：兼容 【JOIN】/【LEAVE】/&#91;JOIN&#93;/&#91;LEAVE&#93; ──
    for (final tag in const ['JOIN', 'LEAVE']) {
      for (final pair in const [('【', '】'), ('[', ']')]) {
        final prefix = '${pair.$1}$tag${pair.$2}';
        if (upper.startsWith(prefix)) {
          final who = text.substring(prefix.length).trim().toUpperCase();
          if (who.isEmpty) return null;
          return GroupMsg(
            tag == 'JOIN' ? GroupKind.memberJoined : GroupKind.memberLeft,
            name: who,
          );
        }
      }
    }

    // ── 命令式写法：按空格切词，**不做数字符 substring** ──
    final parts = text.split(RegExp(r'\s+'));
    if (parts.isEmpty) return null;
    final cmd = parts.first.toUpperCase();
    final rest = parts.skip(1).toList();

    String arg(int i) => i < rest.length ? rest[i].trim().toUpperCase() : '';

    switch (cmd) {
      case 'INVITE':
        // INVITE <群呼号> <群名...>（群名可能含空格，全部拼回）
        if (rest.length < 2) return null;
        final gc = arg(0);
        final name = rest.skip(1).join(' ').trim();
        if (gc.isEmpty || name.isEmpty) return null;
        return GroupMsg(GroupKind.invite, groupCall: gc, name: name);
      case 'JOIN_CONFIRM':
      case 'JACK': // 结构化别名（新版本发这个，更短）
        final gc = arg(0);
        return gc.isEmpty ? null : GroupMsg(GroupKind.joinConfirm, groupCall: gc);
      case 'DECLINE':
        final gc = arg(0);
        return gc.isEmpty ? null : GroupMsg(GroupKind.decline, groupCall: gc);
      case 'JOIN_REQ':
      case 'JREQ':
        final gc = arg(0);
        return gc.isEmpty
            ? null
            : GroupMsg(GroupKind.joinRequest, groupCall: gc);
      case 'LEFT':
      case 'LACK':
        final gc = arg(0);
        return gc.isEmpty ? null : GroupMsg(GroupKind.leave, groupCall: gc);
      default:
        return null;
    }
  }

  /// 该协议消息是否是「发往群主」的私信类命令（需要群主身份才处理）。
  static bool isAddressedToOwner(GroupKind k) =>
      k == GroupKind.joinConfirm ||
      k == GroupKind.decline ||
      k == GroupKind.joinRequest ||
      k == GroupKind.leave;
}
