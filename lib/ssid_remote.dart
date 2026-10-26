/// ─── 「我的其他 SSID」远程指令 ───
///
/// 用户在设备快捷面板里能对**自己另一个 SSID 上的 APRSlocus** 做三件事：
/// 激活（让它把定位跑起来）、发一次信标、停止自动上报。走的还是 APRS 消息，
/// 所以对端必须已经连着链路、并且能收到发给那个 SSID 的报文。
///
/// 报文长这样（固定前缀 `!AL `，三个字母的指令）：
///
///     BG7LZQ-7>APRS::BG7LZQ-9 :!AL ACT{12
///
/// 安全边界只有一条，但它必须存在：**只接受同一「基础呼号」发来的指令**。
/// 别人拿你呼号以外的台站发 `!AL STP` 一律不认，否则谁都能把你关掉。
/// 这一条同时也排除了「自己发给自己」的回路（本机 ID 发的不会触发动作）。
library;

/// 指令前缀。带个 `!` 是为了跟日常聊天区分开：普通消息几乎不可能以它开头。
const String ssidCmdPrefix = '!AL ';

enum SsidCmd {
  /// 激活：把定位跑起来（并顺手发一次信标，见 AppState.applySsidCommand）
  activate,

  /// 发一次信标
  beacon,

  /// 停止自动上报
  stop,
}

/// 指令在报文里的字面写法
String ssidCmdCode(SsidCmd c) => switch (c) {
      SsidCmd.activate => 'ACT',
      SsidCmd.beacon => 'BCN',
      SsidCmd.stop => 'STP',
    };

/// 构造指令正文（不含 `{id_` 那一段，由发送路径自己补）
String ssidCmdText(SsidCmd c) => '$ssidCmdPrefix${ssidCmdCode(c)}';

/// 解析指令；不是指令就返回 null
SsidCmd? parseSsidCommand(String text) {
  final t = text.trim().toUpperCase();
  if (!t.startsWith(ssidCmdPrefix.trim().toUpperCase())) return null;
  final rest = t.substring(ssidCmdPrefix.trim().length).trim();
  // 允许后面跟一行说明（`!AL STP 电量低`），只认第一个词
  final word = rest.split(RegExp(r'\s+')).first;
  for (final c in SsidCmd.values) {
    if (ssidCmdCode(c) == word) return c;
  }
  return null;
}
