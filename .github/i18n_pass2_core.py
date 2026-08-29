from pathlib import Path

root = Path(__file__).resolve().parents[1]

def patch(path, pairs):
    p = root / path
    text = p.read_text(encoding='utf-8')
    for old, new in pairs:
        count = text.count(old)
        if count == 0:
            print(f'WARN missing {path}: {old[:100]!r}')
        else:
            print(f'{path}: {count} x {old[:60]!r}')
            text = text.replace(old, new)
    p.write_text(text, encoding='utf-8')

# Display-only localization helpers. These do not alter protocol/state values.
p = root / 'lib/widgets.dart'
text = p.read_text(encoding='utf-8')
marker = 'typedef S = AppLocalizations;\n'
helper = r'''

String _aprsSymbolKey(String symbol) => switch (symbol) {
  '>' => 'car',
  '!' => 'police',
  '"' => 'person',
  '#' => 'digitalRepeater',
  r'$' => 'telephone',
  '%' => 'dxCluster',
  '&' => 'hfGateway',
  "'" => 'smallAircraft',
  '(' => 'mobileSatellite',
  ')' => 'disabled',
  '*' => 'snowmobile',
  '+' => 'redCross',
  ',' => 'scouts',
  '-' => 'house',
  '.' => 'redX',
  '/' => 'redDot',
  ':' => 'fire',
  ';' => 'campground',
  '<' => 'motorcycle',
  '=' => 'train',
  '?' => 'fileServer',
  '@' => 'hurricane',
  '[' => 'person',
  '\\' => 'dfTriangle',
  ']' => 'postOffice',
  '^' => 'largeAircraft',
  '_' => 'weatherStation',
  '`' => 'satelliteDish',
  'a' => 'ambulance',
  'b' => 'bicycle',
  'c' => 'commandPost',
  'd' => 'fireStation',
  'e' => 'horse',
  'f' => 'fireTruck',
  'g' => 'glider',
  'h' => 'hospital',
  'i' => 'fmoStation',
  'j' => 'jeep',
  'k' => 'truck',
  'l' => 'laptop',
  'm' => 'micERepeater',
  'n' => 'node',
  'o' => 'emergencyOps',
  'p' => 'dog',
  'q' => 'gridSquare',
  'r' => 'repeaterTower',
  's' => 'boat',
  't' => 'truckStop',
  'u' => 'semiTrailer',
  'v' => 'van',
  'w' => 'waterStation',
  'y' => 'yagi',
  'z' => 'shelter',
  'R' => 'rv',
  'W' => 'weatherSymbol',
  'O' => 'balloon',
  'U' => 'bus',
  'S' => 'shuttle',
  'P' => 'policeCar',
  'Y' => 'sailboat',
  'K' => 'school',
  'H' => 'lodging',
  'J' => 'hotel',
  _ => 'other',
};

String localizedAprsSymbolName(BuildContext context, String symbol) =>
    S.of(context).aprsSymbolName(_aprsSymbolKey(symbol));

String localizedSymbolCategory(BuildContext context, String category) {
  final key = switch (category) {
    '车辆 / 交通' => 'vehicles',
    '建筑 / 设施' => 'facilities',
    '气象 / 自然' => 'weatherNature',
    '应急救援' => 'emergencyRescue',
    '飞行 / 水域' => 'airWater',
    '通信 / 其他' => 'communications',
    _ => 'other',
  };
  return S.of(context).symbolCategoryName(key);
}

String localizedStatusLabel(BuildContext context, St status) => switch (status) {
  St.online => S.of(context).online,
  St.moving => S.of(context).moving,
  St.stopped => S.of(context).stationary,
  St.emergency => S.of(context).emergency,
  St.offline => S.of(context).offline,
};

String localizedLastSeen(BuildContext context, Station station) {
  final d = DateTime.now().difference(station.lastHeard);
  if (d.inSeconds < 60) return S.of(context).secondsAgo(d.inSeconds);
  if (d.inMinutes < 60) return S.of(context).minutesAgo(d.inMinutes);
  if (d.inHours < 24) return S.of(context).hoursAgo(d.inHours);
  if (d.inDays < 7) return S.of(context).daysAgo(d.inDays);
  return '${station.lastHeard.year}-${station.lastHeard.month.toString().padLeft(2, '0')}';
}

String localizedLocationStatus(BuildContext context, String value) {
  final s = S.of(context);
  if (value == '未定位') return s.locationNotFixed;
  if (value == '模拟位置') return s.simulatedLocation;
  if (value == '已保存位置') return s.savedLocation;
  if (value == '定位失败') return s.locationFailed;
  if (value == '定位已停止') return s.locationStopped;
  if (value == '已定位') return s.locationFixed;
  if (value == '请授予定位权限…') return s.locationPermission;
  if (value == 'GPS 定位中…') return s.gpsLocating;
  if (value == 'Web 平台暂不支持自动定位，请手动输入坐标') {
    return s.webLocationUnsupported;
  }
  final stream = RegExp(r'^定位流异常:\s*(.*)$').firstMatch(value);
  if (stream != null) return s.locationStreamError(stream.group(1)!);
  final init = RegExp(r'^定位初始化失败:\s*(.*)$').firstMatch(value);
  if (init != null) return s.locationInitError(init.group(1)!);
  return value;
}

String localizedNextBeaconValue(BuildContext context, String value) {
  if (value == '已关闭') return S.of(context).beaconDisabled;
  if (value == '等待定位') return S.of(context).waitingForLocation;
  if (value == '即将') return S.of(context).imminent;
  return value;
}

String localizedConnectionInfo(BuildContext context, String value) {
  final s = S.of(context);
  if (value == '未连接 · 点击播放按钮连接 APRS-IS') return s.connTapToConnect;
  if (value == '未连接 · 已手动断开') return s.connManuallyDisconnected;
  if (value == '未连接 · 位置已上报(模拟)') return s.connDemoBeacon;
  if (value == '已连接 · 未验证（passcode 可能错误）') {
    return s.connPasscodeInvalid;
  }
  var m = RegExp(r'^连接已断开 · (\d+)秒后自动重连…$').firstMatch(value);
  if (m != null) return s.connAutoReconnect(int.parse(m.group(1)!));
  m = RegExp(r'^正在连接 (.+)…$').firstMatch(value);
  if (m != null) return s.connConnectingTarget(m.group(1)!);
  m = RegExp(r'^已连接 · (.+) 在线$').firstMatch(value);
  if (m != null) return s.connOnline(m.group(1)!);
  m = RegExp(r'^连接失败 · (\d+)s 后重试…$').firstMatch(value);
  if (m != null) return s.connRetry(int.parse(m.group(1)!));
  m = RegExp(r'^已连接 · 位置已上传 \((.+)\)$').firstMatch(value);
  if (m != null) return s.connPositionSent(m.group(1)!);
  return value;
}

String localizedMapTypeLabel(BuildContext context, String name) => switch (name) {
  'gaode' => S.of(context).mapTypeAmap,
  'gaode_sat' => S.of(context).mapTypeAmapSatellite,
  'amap_js' => S.of(context).mapTypeAmapJs,
  'vector' => S.of(context).mapTypeVector,
  'carto' => 'Carto',
  'osm' => 'OSM',
  _ => name,
};

String localizedLogLevelName(BuildContext context, LogLevel level) => switch (level) {
  LogLevel.debug => S.of(context).debugLabel,
  LogLevel.info => S.of(context).information,
  LogLevel.warn => S.of(context).warning,
  LogLevel.error => S.of(context).errorLabel,
};

String localizedSystemMessage(BuildContext context, String value) {
  var m = RegExp(r'^(.+) 加入了群聊$').firstMatch(value);
  if (m != null) return S.of(context).systemMemberJoined(m.group(1)!);
  m = RegExp(r'^(.+) 离开了群聊$').firstMatch(value);
  if (m != null) return S.of(context).systemMemberLeft(m.group(1)!);
  m = RegExp(r'^(.+) 拒绝了邀请$').firstMatch(value);
  if (m != null) return S.of(context).systemInviteDeclined(m.group(1)!);
  return value;
}
'''
if 'localizedAprsSymbolName' not in text:
    text = text.replace(marker, marker + helper)
text = text.replace('child: Text(statusLabel(status),', 'child: Text(localizedStatusLabel(context, status),')
p.write_text(text, encoding='utf-8')

patch('lib/home_page.dart', [
    ('Text(widget.state.locStatus,', 'Text(localizedLocationStatus(context, widget.state.locStatus),'),
    ('S.of(context).nextBeaconIn(widget.state.nextBeaconIn)', 'S.of(context).nextBeaconIn(localizedNextBeaconValue(context, widget.state.nextBeaconIn))'),
])

patch('lib/settings_page.dart', [
    ('Text(st.connInfo,', 'Text(localizedConnectionInfo(context, st.connInfo),'),
])

patch('lib/stations_page.dart', [
    ("Text('${s.typeName} · ${s.comment ?? ''}',", "Text('${localizedAprsSymbolName(context, s.symbol)} · ${s.comment ?? ''}',"),
    ('_mini(Icons.access_time_rounded, s.lastSeen)', '_mini(Icons.access_time_rounded, localizedLastSeen(context, s))'),
])

patch('lib/station_detail.dart', [
    ('s.lastSeen,', 'localizedLastSeen(context, s),'),
    ("'${s.symbol}  ${s.typeName}'", "'${s.symbol}  ${localizedAprsSymbolName(context, s.symbol)}'"),
    ("if (vm != null) map['版本'] = 'v${vm.group(1)}';", "if (vm != null) map[S.of(context).version] = 'v${vm.group(1)}';"),
    ("if (bm != null) map['电量'] = '${bm.group(1)}%';", "if (bm != null) map[S.of(context).phoneBattery] = '${bm.group(1)}%';"),
    ("map['高度'] = '${s.alt!.toStringAsFixed(0)}m';", "map[S.of(context).altitude] = '${s.alt!.toStringAsFixed(0)}m';"),
    ("map['速度'] = '${s.speed!.toStringAsFixed(0)}km/h';", "map[S.of(context).speed] = '${s.speed!.toStringAsFixed(0)}km/h';"),
])

patch('lib/map_page.dart', [
    ("'${st.beaconInterval} 秒'", 'S.of(context).secondsValue(st.beaconInterval)'),
    ("'${st.beaconsSent} 次'", 'S.of(context).countTimes(st.beaconsSent)'),
    ("Text(\n                group,", "Text(\n                group == '高德' ? S.of(context).amapGroup : S.of(context).otherType,"),
    ('t.label,', 'localizedMapTypeLabel(context, t.name),'),
    ("String coord = '北京 · ${_zoom.round()}级';", 'String coord = S.of(context).mapDefaultCoord(_zoom.round());'),
])

patch('lib/oobe_page.dart', [
    ("child: Text('Passcode 未填写'", 'child: Text(S.of(context).oobePasscodeMissing'),
    ("'Passcode 是 APRS-IS 登录验证码，用于识别你的呼号。\\n\\n'\n                        '使用默认值 -1（未验证）虽然可以连接，但将无法正常收发消息与群聊。\\n\\n'\n                        '建议在 https://aprs.cool/AprsPG 输入呼号查询正确 Passcode 后填写。'", 'S.of(context).oobePasscodeMissingDesc'),
    ("child: Text('仍然继续'", 'child: Text(S.of(context).continueAnyway'),
    ("child: Text('去填写'", 'child: Text(S.of(context).fillPasscode'),
    ("'高德地图瓦片，查看附近 APRS 台站与轨迹'", 'S.of(context).oobeMapFeatureDesc'),
    ("'自动获取位置并发送信标到 APRS-IS'", 'S.of(context).oobeGpsFeatureDesc'),
    ("'与台站收发消息，支持自动应答'", 'S.of(context).oobeMsgFeatureDesc'),
    ("'连接公共服务器，接收全球台站数据'", 'S.of(context).oobeIsFeatureDesc'),
    ("'提示：为保证后台持续定位上报，请到系统设置中允许 APRSlocus 后台运行、关闭省电优化，并允许自启动。'", 'S.of(context).oobeBackgroundTip'),
    ("Text('接下来几步完成基础配置，随时可在设置中修改。'", 'Text(S.of(context).oobeNextSteps'),
    ("Text('选择 SSID 后缀'", 'Text(S.of(context).chooseSsidSuffix'),
    ("Text('SSID 是呼号后面的数字标识，如 BG7ABC-9 中的 -9'", 'Text(S.of(context).ssidDescShort'),
    ("_ssidOption('无', 0)", '_ssidOption(S.of(context).none, 0)'),
    ("Text('SSID 后缀（可选）'", 'Text(S.of(context).ssidOptional'),
    ("_ssid == 0 ? '无后缀（基本呼号）' : '-$_ssid'", "_ssid == 0 ? S.of(context).noSsid : '-$_ssid'"),
    ("'完整呼号: ${_call.text.trim().toUpperCase()}${_ssid == 0 ? '' : '-$_ssid'}'", "S.of(context).fullCallsign('${_call.text.trim().toUpperCase()}${_ssid == 0 ? '' : '-$_ssid'}')"),
    ('Text(s.$2,', 'Text(localizedAprsSymbolName(context, s.$1),'),
    ('child: Text(e.value,', 'child: Text(S.of(context).countryName(e.key),'),
    ("Text('其他台站'", 'Text(S.of(context).receiveOthers'),
    ("Text('接收不匹配所选国家的特殊呼号台站'", 'Text(S.of(context).receiveOthersDesc'),
    ("Text('Passcode 非常重要'", 'Text(S.of(context).passcodeImportant'),
    ("'正确的 Passcode 是接收群聊消息和发送确认消息的前提。'\n              '填 -1 虽然可以连接，但无法正常收发消息。'", 'S.of(context).passcodeImportantDesc'),
    ("Text('点击查询你的 Passcode →'", 'Text(S.of(context).lookupPasscode'),
    ("Text('输入你的呼号即可获取，例如 BV2AAA'", 'Text(S.of(context).passcodeLookupHint'),
])

patch('lib/messages_page.dart', [
    ("? '发到 ${group?.name ?? S.of(context).groupChat}…'", '? S.of(context).sendToGroupHint(group?.name ?? S.of(context).groupChat)'),
    ("? '发给 $_selected…'", '? S.of(context).sendToCallHint(_selected)'),
    (": '点选消息以回复…'", ': S.of(context).selectMessageReply'),
    ("'新建会话',\n                C.blue", 'S.of(context).newConversation,\n                C.blue'),
    ("_convActionBtn(Icons.campaign_rounded, '群发'", '_convActionBtn(Icons.campaign_rounded, S.of(context).broadcastShort'),
    ("'${g.confirmedMembers.length} 个成员'", 'S.of(context).memberCount(g.confirmedMembers.length)'),
    ("'群呼号: ${group.groupCall}'", 'S.of(context).groupCallsignLine(group.groupCall)'),
    ("'${group.confirmedMembers.length} 名成员 · 点击查看'", 'S.of(context).memberCountTap(group.confirmedMembers.length)'),
    ("'退出',\n                              C.red", 'S.of(context).leave,\n                              C.red'),
    ("onSenderTap: sender == '我'", 'onSenderTap: sender == S.of(context).meLabel'),
    ("_stepDot(1, step, '选人')", '_stepDot(1, step, S.of(context).stepRecipients)'),
    ("_stepDot(2, step, '内容')", '_stepDot(2, step, S.of(context).stepContent)'),
    ("'全选在线'", 'S.of(context).selectAllOnline'),
    ("_pickerActionBtn('取消全选'", '_pickerActionBtn(S.of(context).clearSelection'),
    ("onlyOnline ? '仅在线' : S.of(context).all", 'onlyOnline ? S.of(context).onlineOnly : S.of(context).all'),
    ("selected.isEmpty ? '未选择接收人' : '已选 ${selected.length} 人'", 'selected.isEmpty ? S.of(context).noRecipients : S.of(context).selectedRecipients(selected.length)'),
    ("'将发送给 ${selected.length} 人：${selected.join('、')}'", "S.of(context).sendRecipientsList(selected.length, selected.join(', '))"),
    ("_stepDot(1, step, '名称')", '_stepDot(1, step, S.of(context).stepName)'),
    ("_stepDot(2, step, '成员')", '_stepDot(2, step, S.of(context).stepMembers)'),
    ("'群聊使用群呼号广播消息，所有成员都能收到。创建后系统会自动生成群呼号并邀请你选择的成员。'", 'S.of(context).groupChatExplain'),
    ("selected.isEmpty ? '未选择成员' : '已选 ${selected.length} 人'", 'selected.isEmpty ? S.of(context).noMembersSelected : S.of(context).selectedRecipients(selected.length)'),
    ("child: Text('暂无台站'", 'child: Text(S.of(context).noStations'),
    ("statusText = '已屏蔽'", 'statusText = S.of(context).memberBlocked'),
    ("? '已加入'", '? S.of(context).memberJoined'),
    ("statusText = '待确认'", 'statusText = S.of(context).memberPending'),
    ("statusText = '已拒绝'", 'statusText = S.of(context).memberDeclined'),
    ("statusText = '已退出'", 'statusText = S.of(context).memberLeft'),
    ("statusText = '超时'", 'statusText = S.of(context).memberTimeout'),
    ("isBlocked ? '解除屏蔽' : '屏蔽'", 'isBlocked ? S.of(context).unblock : S.of(context).block'),
    ("group.isOwner(st.myCall) ? '+ 邀请' : '完成'", "group.isOwner(st.myCall) ? '+ ${S.of(context).invite}' : S.of(context).done"),
    ("'群主',", 'S.of(context).groupOwner,'),
])

# Only system-generated messages are localized. User message text is never translated.
p = root / 'lib/messages_page.dart'
text = p.read_text(encoding='utf-8')
text = text.replace(
    "child: Text(m.text, style: ts(10, c: C.grey, w: FontWeight.w500))",
    "child: Text(localizedSystemMessage(context, m.text), style: ts(10, c: C.grey, w: FontWeight.w500))",
)
p.write_text(text, encoding='utf-8')
