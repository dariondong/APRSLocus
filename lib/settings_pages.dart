import 'package:flutter/material.dart';
import 'theme.dart';
import 'state.dart';
import 'models.dart';
import 'widgets.dart';
import 'settings_widgets.dart';
import 'log_page.dart';
import 'tile_map.dart';

/// ─── 电台设置 ───
class StationSettingsPage extends StatefulWidget {
  final AppState state;
  const StationSettingsPage({super.key, required this.state});
  @override
  State<StationSettingsPage> createState() => _StationSettingsPageState();
}

class _StationSettingsPageState extends State<StationSettingsPage> {
  late final TextEditingController _call;
  late final TextEditingController _comment;

  AppState get st => widget.state;

  @override
  void initState() {
    super.initState();
    _call = TextEditingController(text: st.myCall);
    _comment = TextEditingController(text: st.myComment);
  }

  @override
  void dispose() {
    _call.dispose();
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: st,
      builder: (context, _) => SettingsPageShell(
        title: S.of(context).stationSettings2,
        subtitle: '呼号、SSID、符号与备注',
        icon: Icons.person_rounded,
        color: C.blue,
        body: Column(children: [
        SettingsSectionCard(
          title: '电台身份',
          subtitle: S.of(context).settingsStationIdentitySubtitle,
          icon: Icons.badge_rounded,
          color: C.blue,
          children: [
            SettingsInput(S.of(context).callsign, _call,
                tip: 'APRS 呼号，如 BV2AAA',
                onChanged: (v) {
              if (v.trim().isNotEmpty) {
                st.myCall = v.trim().toUpperCase();
                st.persist();
              }
            }),
            _ssidRow(),
            SettingsInput(S.of(context).callComment, _comment,
                tip: S.of(context).callCommentHint,
                onChanged: (v) {
              st.myComment = v.trim();
              st.persist();
            }),
          ],
        ),
        SizedBox(height: 16),
        SettingsSectionCard(
          title: '显示信息',
          subtitle: S.of(context).settingsDisplayInfoSubtitle,
          icon: Icons.info_outline_rounded,
          color: C.purple,
          children: [
            _symbolPicker(),
            SettingsRow2(S.of(context).grid, st.myGrid),
            SettingsRow2(S.of(context).myLocation, st.myPosStr),
          ],
        ),
      ]),
      ),
    );
  }

  Widget _ssidRow() {
    return GestureDetector(
      onTap: () => _pickSsid(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: C.border, width: 0.4))),
        child: Row(children: [
          Icon(Icons.tag_rounded, size: 16, color: C.blue),
          SizedBox(width: 8),
          Text('SSID 后缀', style: ts(12, c: C.slate)),
          Spacer(),
          Text(
            st.mySsid == 0 ? '无' : '-${st.mySsid}',
            style: ts(13, c: C.blue, w: FontWeight.w700),
          ),
          SizedBox(width: 4),
          Text('· ${st.myFullCall}', style: ts(10, c: C.grey)),
          SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, size: 18, color: C.grey),
        ]),
      ),
    );
  }

  void _pickSsid(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          decoration: BoxDecoration(
            color: C.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 36, height: 4, decoration: BoxDecoration(
                color: C.greyLight, borderRadius: BorderRadius.circular(2))),
            SizedBox(height: 14),
            Text('选择 SSID 后缀', style: ts(16, w: FontWeight.w700)),
            SizedBox(height: 4),
            Text(S.of(context).ssidDesc,
                style: ts(11, c: C.grey), textAlign: TextAlign.center),
            SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final val in [0, ...List.generate(15, (i) => i + 1)])
                  GestureDetector(
                    onTap: () {
                      setState(() => st.mySsid = val);
                      st.persist();
                      setModalState(() {});
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 64,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: st.mySsid == val ? C.blue : C.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: st.mySsid == val ? C.blue : C.border),
                      ),
                      child: Text(val == 0 ? '无' : '-$val',
                          textAlign: TextAlign.center,
                          style: ts(13,
                              c: st.mySsid == val ? Colors.white : C.slate,
                              w: st.mySsid == val
                                  ? FontWeight.w700
                                  : FontWeight.w500)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
          ]),
        ),
      ),
    );
  }

  Widget _symbolPicker() {
    const syms = [
      ('>', '汽车', Icons.directions_car_rounded),
      ('-', '房屋', Icons.home_rounded),
      ('[', '人', Icons.man_rounded),
      ('k', '卡车', Icons.local_shipping_rounded),
      ('b', '自行车', Icons.directions_bike_rounded),
      ('R', '房车', Icons.airport_shuttle_rounded),
      ('W', '气象站', Icons.cloud_rounded),
      ('!', '警局', Icons.local_police_rounded),
    ];
    (String, String, IconData)? found;
    for (final cat in _symCategories) {
      for (final s in cat.$2) {
        if (s.$1 == st.mySymbol) { found = s; break; }
      }
      if (found != null) break;
    }
    final cur = found ?? syms.firstWhere((s) => s.$1 == st.mySymbol,
        orElse: () => syms.first);
    return GestureDetector(
      onTap: () => _showSymbolPicker(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: C.border, width: 0.4))),
        child: Row(children: [
          Text('我的符号', style: ts(12, c: C.slate)),
          Spacer(),
          Row(mainAxisSize: MainAxisSize.min, children: [
            _symIcon(cur.$1, cur.$3, active: true),
            SizedBox(width: 6),
            Text(cur.$2, style: ts(12, w: FontWeight.w600)),
            SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, size: 18, color: C.grey),
          ]),
        ]),
      ),
    );
  }

  void _showSymbolPicker() {
    const syms = [
      ('>', '汽车', Icons.directions_car_rounded),
      ('-', '房屋', Icons.home_rounded),
      ('[', '人', Icons.man_rounded),
      ('k', '卡车', Icons.local_shipping_rounded),
      ('b', '自行车', Icons.directions_bike_rounded),
      ('R', '房车', Icons.airport_shuttle_rounded),
      ('W', '气象站', Icons.cloud_rounded),
      ('!', '警局', Icons.local_police_rounded),
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.48,
        decoration: BoxDecoration(
          color: C.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 36, height: 4,
            decoration: BoxDecoration(
                color: C.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Row(children: [
              Text(S.of(context).chooseSymbol, style: ts(15, w: FontWeight.w700)),
              Spacer(),
              IconButton(
                icon: Icon(Icons.close_rounded, size: 20, color: C.grey),
                onPressed: () => Navigator.pop(ctx),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(S.of(context).callSymbolDesc, style: ts(11, c: C.slate)),
          ),
          SizedBox(height: 12),
          Expanded(
            child: GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              childAspectRatio: 0.85,
              children: [
                for (final s in syms)
                  _symTile(ctx, s),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
                border: Border(top: BorderSide(color: C.border, width: 0.4))),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
            child: GestureDetector(
              onTap: () {
                Navigator.pop(ctx);
                _showAllSymbols();
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: C.bgSoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: C.border),
                ),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.grid_view_rounded, size: 15, color: C.blue),
                  SizedBox(width: 6),
                  Text('更多符号', style: ts(12, c: C.blue, w: FontWeight.w600)),
                  SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded, size: 16, color: C.blue),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _symTile(BuildContext ctx, (String, String, IconData) s) {
    final sel = st.mySymbol == s.$1;
    return GestureDetector(
      onTap: () {
        st.mySymbol = s.$1;
        st.persist();
        Navigator.pop(ctx);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: sel ? C.blueBg : C.bgSoft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: sel ? C.blue : C.border,
              width: sel ? 1.5 : 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _symIcon(s.$1, s.$3, active: sel),
            SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(s.$2,
                  style: ts(10,
                      c: sel ? C.blue : C.ink,
                      w: sel ? FontWeight.w700 : FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center),
            ),
          ],
        ),
      ),
    );
  }

  Widget _symIcon(String sym, IconData fallback, {required bool active}) {
    final png = AprsSym.iconAsset('/', sym);
    final color = active ? C.blue : C.slate;
    if (png != null) {
      return Image.asset(
        png,
        width: 28,
        height: 28,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Icon(fallback, color: color, size: 24),
      );
    }
    return Icon(fallback, color: color, size: 24);
  }

  void _showAllSymbols() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: C.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 36, height: 4,
            decoration: BoxDecoration(
                color: C.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: Row(children: [
              Text('全部 APRS 符号', style: ts(15, w: FontWeight.w700)),
              Spacer(),
              IconButton(
                icon: Icon(Icons.close_rounded, size: 20, color: C.grey),
                onPressed: () => Navigator.pop(ctx),
              ),
            ]),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final cat in _symCategories) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
                    child: Row(children: [
                      Container(
                        width: 3, height: 14,
                        decoration: BoxDecoration(
                          color: C.blue,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      SizedBox(width: 6),
                      Text(cat.$1,
                          style: ts(13, c: C.blue, w: FontWeight.w700)),
                    ]),
                  ),
                  GridView.count(
                    crossAxisCount: 4,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 0.85,
                    children: [
                      for (final s in cat.$2)
                        _symTile(ctx, s),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
              ],
            ),
          ),
        ]),
      ),
    );
  }

  static const _symCategories = <(String, List<(String, String, IconData)>)>[
    ('车辆 / 交通', [
      ('>', '汽车', Icons.directions_car_rounded),
      ('<', '摩托', Icons.two_wheeler_rounded),
      ('k', '卡车', Icons.local_shipping_rounded),
      ('u', '半挂车', Icons.local_shipping_rounded),
      ('v', '面包车', Icons.airport_shuttle_rounded),
      ('j', '吉普', Icons.directions_car_rounded),
      ('b', '自行车', Icons.directions_bike_rounded),
      ('R', '房车', Icons.airport_shuttle_rounded),
      ('U', '公交', Icons.directions_bus_rounded),
      ('t', '卡车停靠', Icons.local_shipping_rounded),
      ('=', '火车', Icons.train_rounded),
      ('f', '消防车', Icons.fire_truck_rounded),
      ('P', '警车', Icons.local_police_rounded),
      ('*', '雪地摩托', Icons.snowshoeing_rounded),
    ]),
    ('建筑 / 设施', [
      ('-', '房屋', Icons.home_rounded),
      ('!', '警局', Icons.local_police_rounded),
      ('y', '八木屋', Icons.cell_tower_rounded),
      ('h', '医院', Icons.local_hospital_rounded),
      ('a', '救护车', Icons.local_hospital_rounded),
      ('d', '消防站', Icons.local_fire_department_rounded),
      ('K', '学校', Icons.school_rounded),
      ('H', '旅馆', Icons.hotel_rounded),
      ('J', '酒店', Icons.local_hotel_rounded),
      ('[', '人', Icons.man_rounded),
      ('l', '笔记本', Icons.laptop_rounded),
      (']', '邮局', Icons.local_post_office_rounded),
    ]),
    ('气象 / 自然', [
      ('W', '气象站', Icons.cloud_rounded),
      ('_', '气象', Icons.cloud_rounded),
      ('w', '供水站', Icons.water_drop_rounded),
      ('@', '飓风', Icons.cyclone_rounded),
      ('=', '火车', Icons.train_rounded),
      ('e', '骑马', Icons.pets_rounded),
      ('p', '狗', Icons.pets_rounded),
      (';', '露营', Icons.park_rounded),
      ('z', '避难所', Icons.emergency_rounded),
    ]),
    ('应急救援', [
      ('!', '警局', Icons.local_police_rounded),
      ('+', '红十字', Icons.medical_services_rounded),
      ('a', '救护车', Icons.local_hospital_rounded),
      ('d', '消防站', Icons.local_fire_department_rounded),
      (':', '火警', Icons.local_fire_department_rounded),
      ('o', '应急中心', Icons.apartment_rounded),
      ('c', '指挥中心', Icons.sports_esports_rounded),
      (')', '残障', Icons.accessible_rounded),
    ]),
    ('飞行 / 水域', [
      ("'", '小型飞机', Icons.airplanemode_active_rounded),
      ('^', '大型飞机', Icons.flight_rounded),
      ('g', '滑翔机', Icons.flight_rounded),
      ('O', '气球', Icons.radio_rounded),
      ('s', '船', Icons.directions_boat_rounded),
      ('Y', '帆船', Icons.sailing_rounded),
      ('(', '移动卫星', Icons.satellite_alt_rounded),
      ('`', '卫星天线', Icons.satellite_alt_rounded),
    ]),
    ('通信 / 其他', [
      ('#', '数字中继', Icons.cast_connected_rounded),
      ('r', '中继塔', Icons.cell_tower_rounded),
      ('m', 'Mic-E 中继', Icons.cell_tower_rounded),
      ('n', '节点', Icons.track_changes_rounded),
      ('%', 'DX 集群', Icons.router_rounded),
      ('&', 'HF 网关', Icons.satellite_alt_rounded),
      ('?', '文件服务器', Icons.dns_rounded),
      ('\$', '电话', Icons.call_rounded),
      ('q', '网格', Icons.grid_4x4_rounded),
      ('x', 'X/Unix', Icons.terminal_rounded),
      ('i', 'FMO 台站', Icons.radio_rounded),
    ]),
  ];
}

/// ─── 定位上报设置 ───
class BeaconSettingsPage extends StatefulWidget {
  final AppState state;
  const BeaconSettingsPage({super.key, required this.state});
  @override
  State<BeaconSettingsPage> createState() => _BeaconSettingsPageState();
}

class _BeaconSettingsPageState extends State<BeaconSettingsPage> {
  late final TextEditingController _interval;
  late final TextEditingController _myLat;
  late final TextEditingController _myLng;
  bool _manualOpen = false;
  bool _smartBeacon = true;

  AppState get st => widget.state;

  @override
  void initState() {
    super.initState();
    _interval = TextEditingController(text: '${st.beaconInterval}');
    _myLat = TextEditingController(text: st.myLat?.toString() ?? '');
    _myLng = TextEditingController(text: st.myLng?.toString() ?? '');
  }

  @override
  void dispose() {
    _interval.dispose();
    _myLat.dispose();
    _myLng.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: st,
      builder: (context, _) => SettingsPageShell(
        title: S.of(context).beaconSettings,
        subtitle: 'GPS 来源、信标与手动定位',
        icon: Icons.my_location_rounded,
        color: C.green,
        body: Column(children: [
          SettingsSectionCard(
          title: '定位来源',
          subtitle: S.of(context).settingsLocSourceSubtitle,
          icon: Icons.gps_fixed_rounded,
          color: C.green,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
              child: Row(children: [
                Expanded(
                  child: _locSourceCard(
                    title: S.of(context).location,
                    icon: Icons.gps_fixed_rounded,
                    desc: '使用设备定位',
                    selected: !st.useSimLocation,
                    onTap: () => st.setUseSimLocation(false),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: _locSourceCard(
                    title: '模拟位置',
                    icon: Icons.gps_off_rounded,
                    desc: '手动输入坐标',
                    selected: st.useSimLocation,
                    onTap: () => st.setUseSimLocation(true),
                  ),
                ),
              ]),
            ),
            SizedBox(height: 10),
          ],
        ),
        SizedBox(height: 16),
        SettingsSectionCard(
          title: S.of(context).locationMode,
          subtitle: S.of(context).settingsLocModeSubtitle,
          icon: Icons.satellite_alt_rounded,
          color: C.cyan,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
              child: Row(children: [
                Expanded(
                  child: _locSourceCard(
                    title: S.of(context).locModeGps,
                    icon: Icons.gps_fixed_rounded,
                    desc: S.of(context).locModeGpsDesc,
                    selected: st.locationMode == 'gps',
                    onTap: () => st.setLocationMode('gps'),
                    color: C.cyan,
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: _locSourceCard(
                    title: S.of(context).locModeGpsNetwork,
                    icon: Icons.wifi_tethering_rounded,
                    desc: S.of(context).locModeGpsNetworkDesc,
                    selected: st.locationMode == 'gps_network',
                    onTap: () => st.setLocationMode('gps_network'),
                    color: C.cyan,
                  ),
                ),
              ]),
            ),
            SizedBox(height: 10),
          ],
        ),
        SizedBox(height: 16),
        SettingsSectionCard(
          title: '信标上报',
          subtitle: S.of(context).settingsBeaconSubtitle,
          icon: Icons.radio_rounded,
          color: C.blue,
          children: [
            SettingsSwitch(S.of(context).beaconEnabled, value: st.beaconEnabled,
                onChanged: st.setBeaconEnabled),
            SettingsInput(S.of(context).beaconInterval, _interval,
                tip: '位置信标的发送间隔，至少 5 秒',
                onChanged: (v) {
              final n = int.tryParse(v);
              if (n != null && n >= 5) st.setBeaconInterval(n);
            }),
            SettingsSwitch(S.of(context).smartBeacon, value: _smartBeacon,
                onChanged: (v) => setState(() => _smartBeacon = v)),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.tune_rounded, size: 15, color: C.green),
                    SizedBox(width: 6),
                    Text('信标上报内容', style: ts(12, c: C.green, w: FontWeight.w700)),
                  ]),
                  SizedBox(height: 2),
                  Text('随位置信标一起发送', style: ts(10, c: C.slate)),
                  SizedBox(height: 4),
                  SettingsMiniSwitch(S.of(context).speed, value: st.beaconIncludeSpeed,
                      onChanged: st.setBeaconIncludeSpeed),
                  SettingsMiniSwitch(S.of(context).bearing, value: st.beaconIncludeCourse,
                      onChanged: st.setBeaconIncludeCourse),
                  SettingsMiniSwitch('手机电量', value: st.beaconIncludeBattery,
                      onChanged: st.setBeaconIncludeBattery),
                ],
              ),
            ),
            SettingsRow2('定位状态', st.locStatus),
            SettingsRow2(S.of(context).beaconsSent, '${st.beaconsSent} 次'),
            SettingsRow2(S.of(context).nextBeacon, st.nextBeaconIn),
            if (!st.loc.running)
              Padding(
                padding: const EdgeInsets.all(14),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: st.startTracking,
                    icon: Icon(Icons.gps_fixed_rounded, size: 16),
                    label: Text(st.myHasFix ? '重新定位' : '开启 GPS 定位'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: C.blue,
                      side: BorderSide(color: C.blue.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      textStyle: ts(12, w: FontWeight.w600),
                    ),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Icon(Icons.gps_fixed_rounded, color: C.green, size: 16),
                  SizedBox(width: 8),
                  Text('定位运行中，正在持续上报位置',
                      style: ts(12, c: C.green, w: FontWeight.w600)),
                ]),
              ),
          ],
        ),
        SizedBox(height: 16),
        // 手动定位
        SettingsFold(
          title: '手动定位',
          subtitle: S.of(context).settingsManualLocSubtitle,
          icon: Icons.gps_off_rounded,
          color: C.orange,
          open: _manualOpen,
          onToggle: () => setState(() => _manualOpen = !_manualOpen),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _myLat,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: ts(12),
                    decoration: InputDecoration(
                      hintText: '纬度 39.9042',
                      hintStyle: ts(12, c: C.grey),
                      isDense: true,
                      filled: true,
                      fillColor: C.bgSoft,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _myLng,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: ts(12),
                    decoration: InputDecoration(
                      hintText: '经度 116.4074',
                      hintStyle: ts(12, c: C.grey),
                      isDense: true,
                      filled: true,
                      fillColor: C.bgSoft,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final lat = double.tryParse(_myLat.text.trim());
                      final lng = double.tryParse(_myLng.text.trim());
                      if (lat == null || lng == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('请输入有效经纬度')),
                        );
                        return;
                      }
                      st.setMyPosition(lat, lng);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('已设置我的位置，网格 ${st.myGrid}')),
                      );
                    },
                    icon: Icon(Icons.my_location_rounded, size: 15),
                    label: Text('应用坐标'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: C.blue,
                      side: BorderSide(color: C.blue.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      textStyle: ts(11, w: FontWeight.w600),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // 先关闭设置子页面，再进入地图选点
                      Navigator.of(context).pop();
                      st.startPick();
                    },
                    icon: Icon(Icons.edit_location_alt_rounded, size: 15),
                    label: Text('在地图选点'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: C.orange,
                      side: BorderSide(color: C.orange.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      textStyle: ts(11, w: FontWeight.w600),
                    ),
                  ),
                ),
              ]),
            ),
            SettingsHint(
                S.of(context).settingsManualLocHint),
          ],
        ),
      ]),
      ),
    );
  }

  Widget _locSourceCard({
    required String title,
    required IconData icon,
    required String desc,
    required bool selected,
    required VoidCallback onTap,
    Color? color,
    Color? bg,
  }) {
    // C.green 是 static 变量（非 const），不能作为默认参数值，方法内回退
    final accent = color ?? C.green;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? (bg ?? accent.withValues(alpha: 0.10)) : C.bgSoft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? accent : C.border,
              width: selected ? 1.5 : 1),
        ),
        child: Row(children: [
          Icon(icon, size: 18, color: selected ? accent : C.slate),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: ts(12,
                        c: selected ? accent : C.ink,
                        w: FontWeight.w700)),
                SizedBox(height: 1),
                Text(desc, style: ts(9, c: C.slate)),
              ],
            ),
          ),
          if (selected)
            Icon(Icons.check_circle_rounded, size: 16, color: accent),
        ]),
      ),
    );
  }
}

/// ─── 连接设置 ───
class ConnectionSettingsPage extends StatefulWidget {
  final AppState state;
  const ConnectionSettingsPage({super.key, required this.state});
  @override
  State<ConnectionSettingsPage> createState() => _ConnectionSettingsPageState();
}

class _ConnectionSettingsPageState extends State<ConnectionSettingsPage> {
  late final TextEditingController _server;
  late final TextEditingController _port;
  late final TextEditingController _ws;
  late final TextEditingController _pass;
  late final TextEditingController _filterLat;
  late final TextEditingController _filterLng;
  late final TextEditingController _filterRadius;
  late final TextEditingController _maxStations;

  bool _configDirty = false;
  String _origServer = '';
  int _origPort = 14580;
  String _origPass = '';
  String? _origWs;
  int _origFilterRadius = 300;
  bool _origFilterFollow = false;
  double _origFilterLat = 39.90;
  double _origFilterLng = 116.40;

  AppState get st => widget.state;

  @override
  void initState() {
    super.initState();
    _server = TextEditingController(text: st.aprs.server);
    _port = TextEditingController(text: '${st.aprs.port}');
    _ws = TextEditingController(text: st.aprs.wsUrl ?? '');
    _pass = TextEditingController(text: st.aprs.passcode);
    _filterLat = TextEditingController(text: st.filterLat.toStringAsFixed(2));
    _filterLng = TextEditingController(text: st.filterLng.toStringAsFixed(2));
    _filterRadius = TextEditingController(text: '${st.filterRadius}');
    _maxStations = TextEditingController(text: '${st.maxStations}');
    _origServer = st.aprs.server;
    _origPort = st.aprs.port;
    _origPass = st.aprs.passcode;
    _origWs = st.aprs.wsUrl;
    _origFilterRadius = st.filterRadius;
    _origFilterFollow = st.filterFollow;
    _origFilterLat = st.filterLat;
    _origFilterLng = st.filterLng;
  }

  @override
  void dispose() {
    _server.dispose();
    _port.dispose();
    _ws.dispose();
    _pass.dispose();
    _filterLat.dispose();
    _filterLng.dispose();
    _filterRadius.dispose();
    _maxStations.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: st,
      builder: (context, _) {
        // 同步过滤器数值（filterFollow 等模式下可能外部变化）
        _syncFilterControllers(st);
        return SettingsPageShell(
          title: S.of(context).connectionSettings2,
          subtitle: S.of(context).connectionSettingsSubtitle,
          icon: Icons.wifi_rounded,
          color: C.purple,
          body: Column(children: [
            // 连接状态卡片
            _connStatusCard(),
            const SizedBox(height: 16),
            // 服务器配置卡片
            _serverCard(),
            const SizedBox(height: 16),
            _filterCard(),
            const SizedBox(height: 16),
            _receivePrefCard(),
          ]),
      );
    });
  }

  /// 连接状态卡片（独立简洁）
  Widget _connStatusCard() {
    return SettingsSectionCard(
      title: S.of(context).server,
      subtitle: S.of(context).settingsConnStatusSubtitle,
      icon: Icons.dns_rounded,
      color: C.purple,
      children: [
        _connBanner(),
        Divider(height: 1, color: C.border),
        SettingsRow2(S.of(context).connection, st.connInfo),
      ],
    );
  }

  /// 服务器配置卡片（含重连）
  Widget _serverCard() {
    return SettingsSectionCard(
      title: '服务器配置',
      subtitle: S.of(context).settingsServerSubtitle,
      icon: Icons.settings_ethernet_rounded,
      color: C.purple,
      children: [
        SettingsInput(S.of(context).server, _server,
            onChanged: (v) {
          st.aprs.server = v.trim();
          _checkConfigDirty();
        }),
        SettingsInput(S.of(context).port, _port,
            onChanged: (v) {
          final n = int.tryParse(v);
          if (n != null) st.aprs.port = n;
          _checkConfigDirty();
        }),
        _passcodeInput(),
        SettingsInput('WebSocket URL(可选)', _ws,
            onChanged: (v) {
          st.aprs.wsUrl = v.trim().isEmpty ? null : v.trim();
          _checkConfigDirty();
        }),
        if (_configDirty) ...[
          Divider(height: 1, color: C.border),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Icon(Icons.info_outline_rounded,
                  color: C.orange, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('配置已修改',
                          style: ts(13, c: C.orange, w: FontWeight.w700)),
                      Text('重新连接后生效',
                          style: ts(11,
                              c: C.orange.withValues(alpha: 0.8))),
                    ]),
              ),
              SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.refresh_rounded,
                    color: C.orange, size: 22),
                tooltip: S.of(context).reconnect,
                onPressed: () async {
                  setState(() => _configDirty = false);
                  await st.reconnect();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(st.connected
                            ? '已重新连接'
                            : '连接失败，请检查配置'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
              ),
            ]),
          ),
        ],
      ],
    );
  }

  /// Passcode 输入（未验证时醒目提示）
  Widget _passcodeInput() {
    final isDefault = _pass.text.trim().isEmpty || _pass.text.trim() == '-1';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: C.border, width: 0.4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(S.of(context).passcode, style: ts(12, c: C.slate)),
          if (isDefault) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: C.orangeBg,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('未验证',
                  style: ts(9, c: C.orange, w: FontWeight.w700)),
            ),
          ],
        ]),
        const SizedBox(height: 6),
        TextField(
          controller: _pass,
          style: ts(13, w: FontWeight.w600),
          onChanged: (v) {
            st.aprs.passcode = v.trim().isEmpty ? '-1' : v.trim();
            _checkConfigDirty();
          },
          decoration: InputDecoration(
            hintText: '-1 未验证',
            hintStyle: ts(13, c: C.greyLight),
            isDense: true,
            filled: true,
            fillColor: C.bgSoft,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text('APRS-IS 登录验证码，填 -1 无法正常收发消息',
            style: ts(10, c: C.grey)),
      ]),
    );
  }

  Widget _connBanner() {
    final col = st.connected
        ? C.green
        : st.connecting
            ? C.blue
            : C.red;
    final bg = st.connected
        ? C.greenBg
        : st.connecting
            ? C.blueBg
            : C.redBg;
    final icon = st.connected
        ? Icons.check_circle_rounded
        : st.connecting
            ? Icons.sync_rounded
            : Icons.cloud_off_rounded;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Icon(icon, color: col, size: 20),
        SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              st.connected
                  ? '${S.of(context).connected} APRS-IS'
                  : st.connecting
                      ? S.of(context).connecting
                      : S.of(context).disconnected,
              style: ts(13, c: col, w: FontWeight.w700),
            ),
            Text(st.connInfo, style: ts(11, c: col.withValues(alpha: 0.8))),
          ]),
        ),
        SizedBox(width: 8),
        IconButton(
          icon: Icon(
            st.connected
                ? Icons.stop_circle_outlined
                : Icons.play_circle_outline,
            color: st.connected ? C.red : C.green,
          ),
          onPressed: st.toggleConnect,
        ),
      ]),
    );
  }

  Widget _filterCard() {
    return SettingsSectionCard(
      title: S.of(context).filter,
      subtitle: S.of(context).settingsFilterSubtitle,
      icon: Icons.filter_alt_rounded,
      color: C.cyan,
      children: [
        SettingsHint(S.of(context).settingsFilterHint),
        SettingsSwitch('过滤中心跟随我的位置', value: st.filterFollow, color: C.cyan,
            onChanged: (v) {
          st.filterFollow = v;
          _checkConfigDirty();
        }),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _filterLat,
                enabled: !st.filterFollow,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: ts(12),
                onChanged: (v) {
                  // 只改输入框，点"保存并应用"才生效
                  setState(() {});
                },
                decoration: InputDecoration(
                  hintText: S.of(context).latitude,
                  hintStyle: ts(12, c: C.grey),
                  isDense: true,
                  filled: true,
                  fillColor: C.bgSoft,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _filterLng,
                enabled: !st.filterFollow,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: ts(12),
                onChanged: (v) {
                  // 只改输入框，点"保存并应用"才生效
                  setState(() {});
                },
                decoration: InputDecoration(
                  hintText: S.of(context).longitude,
                  hintStyle: ts(12, c: C.grey),
                  isDense: true,
                  filled: true,
                  fillColor: C.bgSoft,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ]),
        ),
        SettingsInput(S.of(context).filterRadius, _filterRadius,
            tip: '接收半径（km），点"保存并应用"生效',
            onChanged: (v) {
          // 只改输入框，点"保存并应用"才生效
          setState(() {});
        }),
        // 快捷半径预设（写入输入框，待保存应用）
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final r in [50, 100, 200, 500, 1000, 2000])
                GestureDetector(
                  onTap: () {
                    _filterRadius.text = '$r';
                    setState(() {});
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _filterRadius.text == '$r' ? C.cyanBg : C.bgSoft,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _filterRadius.text == '$r' ? C.cyan : C.border,
                        width: _filterRadius.text == '$r' ? 1.5 : 1,
                      ),
                    ),
                    child: Text('$r km',
                        style: ts(11,
                            c: _filterRadius.text == '$r' ? C.cyan : C.slate,
                            w: _filterRadius.text == '$r'
                                ? FontWeight.w700
                                : FontWeight.w500)),
                  ),
                ),
            ],
          ),
        ),
        SettingsInput(S.of(context).maxStations, _maxStations,
            tip: '内存中保留的最大台站数量（默认不限制，可设更大值）',
            onChanged: (v) {
          final n = int.tryParse(v);
          if (n != null) st.setMaxStations(n);
        }),
        Padding(
          padding: const EdgeInsets.all(14),
          child: OutlinedButton.icon(
            onPressed: () {
              if (st.myLat != null && st.myLng != null) {
                // 只填入经纬度输入框，点"保存并应用"才生效
                setState(() {
                  _filterLat.text = st.myLat!.toStringAsFixed(4);
                  _filterLng.text = st.myLng!.toStringAsFixed(4);
                });
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(S.of(context).noFixYet)),
                );
              }
            },
            icon: Icon(Icons.my_location_rounded, size: 15),
            label: Text(S.of(context).useMyLocation),
            style: OutlinedButton.styleFrom(
              foregroundColor: C.blue,
              side: BorderSide(color: C.blue.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(vertical: 8),
              textStyle: ts(11, w: FontWeight.w600),
            ),
          ),
        ),
        // 保存并应用过滤（显式保存当前经纬度/半径）
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
          child: SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: C.cyan,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                // 读取输入框的值并统一保存生效（半径始终读输入框）
                final r = int.tryParse(_filterRadius.text);
                if (r == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(S.of(context).invalidCoords)),
                  );
                  return;
                }
                if (st.filterFollow) {
                  // 跟随我的位置：应用当前位置 + 输入框半径
                  st.setFilter(st.filterLat, st.filterLng, r);
                } else {
                  final lat = double.tryParse(_filterLat.text);
                  final lng = double.tryParse(_filterLng.text);
                  if (lat == null || lng == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(S.of(context).invalidCoords)),
                    );
                    return;
                  }
                  st.setFilter(lat, lng, r);
                  _filterLat.text = st.filterLat.toStringAsFixed(4);
                  _filterLng.text = st.filterLng.toStringAsFixed(4);
                }
                _filterRadius.text = '${st.filterRadius}';
                _checkConfigDirty();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        '${S.of(context).filterSaved} · 半径 ${st.filterRadius}km'),
                    backgroundColor: C.green,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              icon: const Icon(Icons.save_rounded, size: 16),
              label: Text(S.of(context).saveAndApply,
                  style: ts(13, c: Colors.white, w: FontWeight.w700)),
            ),
          ),
        ),
        SettingsHint('${S.of(context).filterRule}: ${st.filterString}'),
      ],
    );
  }

  /// 接收呼号筛选卡片：按国家/地区分组 + 精确呼号接收
  Widget _receivePrefCard() {
    return SettingsSectionCard(
      title: S.of(context).receiveFilter,
      subtitle: S.of(context).settingsReceivePrefSubtitle,
      icon: Icons.public_rounded,
      color: C.cyan,
      children: [
        SettingsHint(S.of(context).settingsReceivePrefHint),
        // ── 国家/地区分组 ──
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
          child: Row(children: [
            Icon(Icons.public_rounded, size: 15, color: C.cyan),
            SizedBox(width: 6),
            Text('${S.of(context).receiveCountries} (${st.receiveCountries.length})',
                style: ts(12, c: C.cyan, w: FontWeight.w700)),
            Spacer(),
            GestureDetector(
              onTap: () => _showCountryDialog(st),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: C.cyanBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.add_rounded, size: 13, color: C.cyan),
                  SizedBox(width: 3),
                  Text('添加', style: ts(11, c: C.cyan, w: FontWeight.w700)),
                ]),
              ),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('按呼号前缀批量接收某国家/地区全部台站',
                style: ts(10, c: C.grey)),
            SizedBox(height: 8),
            if (st.receiveCountries.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: C.bgSoft,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: C.border, width: 0.6),
                ),
                child: Column(children: [
                  Icon(Icons.public_off_rounded, size: 20, color: C.greyLight),
                  SizedBox(height: 6),
                  Text('未选择国家/地区', style: ts(11, c: C.grey)),
                ]),
              )
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final code in List.of(st.receiveCountries))
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: C.cyanBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: C.cyan.withValues(alpha: 0.3)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(
                            AppState.countryNames[code] ?? code,
                            style: ts(11, c: C.cyan, w: FontWeight.w700)),
                        SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => st.removeReceiveCountry(code),
                          child: Icon(Icons.close_rounded,
                              size: 12, color: C.cyan),
                        ),
                      ]),
                    ),
                ],
              ),
          ]),
        ),
        Divider(height: 16, color: C.border),
        // ── 其他台站 ──
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: C.purpleBg,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(Icons.blur_circular_rounded,
                    size: 16, color: C.purple),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(S.of(context).receiveOthers, style: ts(13, w: FontWeight.w700)),
                      SizedBox(height: 2),
                      Text('接收不匹配所选国家的特殊呼号台站',
                          style: ts(11, c: C.grey)),
                    ]),
              ),
              Switch(
                value: st.receiveOthers,
                activeColor: C.purple,
                onChanged: (v) => st.setReceiveOthers(v),
              ),
            ]),
          ]),
        ),
      ],
    );
  }

  /// 国家/地区选择对话框
  void _showCountryDialog(AppState st) {
    final entries = AppState.countryNames.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('添加国家/地区', style: ts(16, w: FontWeight.w700)),
        content: SizedBox(
          width: 340,
          height: MediaQuery.of(context).size.height * 0.55,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final e in entries)
                GestureDetector(
                  onTap: () {
                    st.addReceiveCountry(e.key);
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: st.receiveCountries.contains(e.key)
                          ? C.cyanBg
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    margin: EdgeInsets.only(bottom: 6),
                    child: Row(children: [
                      Icon(Icons.public_rounded, size: 16, color: C.cyan),
                      SizedBox(width: 10),
                      Text(e.value, style: ts(13, w: FontWeight.w600)),
                      Spacer(),
                      if (st.receiveCountries.contains(e.key))
                        Icon(Icons.check_circle_rounded,
                            size: 16, color: C.cyan),
                      Text(' ${e.key}',
                          style: ts(10, c: C.grey)),
                    ]),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(S.of(context).cancel, style: ts(13, c: C.grey)),
          ),
        ],
      ),
    );
  }

  /// 同步过滤器控制器文本（仅在 filterFollow 模式下外部更新 state 时同步；
  /// 同步过滤器控制器文本（仅在 filterFollow 模式下同步经纬度；
  /// 半径始终由用户输入控制，避免被重置）
  void _syncFilterControllers(AppState st) {
    if (!st.filterFollow) return;
    final latText = st.filterLat.toStringAsFixed(4);
    final lngText = st.filterLng.toStringAsFixed(4);
    if (_filterLat.text != latText) _filterLat.text = latText;
    if (_filterLng.text != lngText) _filterLng.text = lngText;
  }

  void _checkConfigDirty() {
    // 仅服务器相关配置变化才显示顶部"重新连接"横幅；
    // 过滤范围修改通过卡片内的"保存并应用过滤"按钮应用（见 _filterCard）
    final dirty = st.aprs.server != _origServer ||
        st.aprs.port != _origPort ||
        st.aprs.passcode != _origPass ||
        st.aprs.wsUrl != _origWs;
    if (dirty != _configDirty) {
      setState(() => _configDirty = dirty);
    }
  }
}

/// ─── 显示设置 ───
class DisplaySettingsPage extends StatefulWidget {
  final AppState state;
  const DisplaySettingsPage({super.key, required this.state});
  @override
  State<DisplaySettingsPage> createState() => _DisplaySettingsPageState();
}

class _DisplaySettingsPageState extends State<DisplaySettingsPage> {
  AppState get st => widget.state;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: st,
      builder: (context, _) => SettingsPageShell(
        title: S.of(context).displaySettings2,
        subtitle: S.of(context).settingsSubtitle,
        icon: Icons.palette_rounded,
        color: C.cyan,
        body: Column(children: [
          SettingsSectionCard(
            title: S.of(context).all,
            subtitle: S.of(context).settingsGeneralSubtitle,
            icon: Icons.display_settings_rounded,
            color: C.cyan,
            children: [
              SettingsSwitch(S.of(context).darkMode, value: st.darkMode,
                  color: C.slate, onChanged: (v) => st.setDarkMode(v)),
              _themeColorSelector(st),
              _languageSelector(st),
              _uiScaleSelector(st),
              SettingsRow2(S.of(context).unit, '公制 (km/h, m)'),
              SettingsRow2(S.of(context).grid, 'Maidenhead'),
              _datumSelector(),
            ],
          ),
          SizedBox(height: 16),
          SettingsSectionCard(
            title: S.of(context).map,
            subtitle: S.of(context).settingsMapSubtitle,
            icon: Icons.map_rounded,
            color: C.blue,
            children: [
              _mapTypeSelector(),
              SettingsHint(S.of(context).mapTypeDesc),
            ],
          ),
        ]),
      ),
    );
  }

  /// 自定义主题色选择
  Widget _themeColorSelector(AppState st) {
    const presetColors = [
      '2563EB', '16A34A', 'E11D48', 'EA580C',
      '7C3AED', '0E7490', '0EA5A4', 'DB2777',
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: C.border, width: 0.4))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(S.of(context).themeColor, style: ts(12, c: C.slate)),
          SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final hex in presetColors)
                GestureDetector(
                  onTap: () => st.setThemeColor(hex),
                  child: Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      color: Color(0xFF000000 | int.parse(hex, radix: 16)),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: st.themeColor == hex ? C.ink : C.border,
                        width: st.themeColor == hex ? 2.5 : 1,
                      ),
                    ),
                    child: st.themeColor == hex
                        ? const Icon(Icons.check_rounded,
                            color: Colors.white, size: 18)
                        : null,
                  ),
                ),
              // 默认色（清除自定义）
              GestureDetector(
                onTap: () => st.setThemeColor(''),
                child: Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    color: C.bgSoft,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: st.themeColor.isEmpty ? C.ink : C.border,
                      width: st.themeColor.isEmpty ? 2.5 : 1,
                    ),
                  ),
                  child: Icon(Icons.restart_alt_rounded,
                      size: 16, color: st.themeColor.isEmpty ? C.ink : C.grey),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 语言选择
  Widget _languageSelector(AppState st) {
    final options = <(String, String)>[
      ('', S.of(context).languageSystem),
      ('zh', S.of(context).languageZh),
      ('en', S.of(context).languageEn),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: C.border, width: 0.4))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(S.of(context).language, style: ts(12, c: C.slate)),
          SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (code, name) in options)
                GestureDetector(
                  onTap: () => st.setLocale(code),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: st.locale == code ? C.cyanBg : C.bgSoft,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: st.locale == code ? C.cyan : C.border,
                        width: st.locale == code ? 1.5 : 1,
                      ),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      if (st.locale == code) ...[
                        Icon(Icons.check_rounded, size: 13, color: C.cyan),
                        SizedBox(width: 4),
                      ],
                      Text(name,
                          style: ts(12,
                              c: st.locale == code ? C.cyan : C.slate,
                              w: st.locale == code
                                  ? FontWeight.w700
                                  : FontWeight.w500)),
                    ]),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// 界面缩放选择
  Widget _uiScaleSelector(AppState st) {
    const presets = <double>[0.9, 1.0, 1.15, 1.3];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: C.border, width: 0.4))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(S.of(context).uiScale, style: ts(12, c: C.slate)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: C.cyanBg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('${(st.uiScale * 100).round()}%',
                  style: ts(12, c: C.cyan, w: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 10),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: C.cyan,
              thumbColor: C.cyan,
              inactiveTrackColor: C.border,
              overlayColor: C.cyan.withValues(alpha: 0.12),
              trackHeight: 3,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: Slider(
              value: st.uiScale,
              min: 0.85,
              max: 1.3,
              divisions: 18,
              label: '${(st.uiScale * 100).round()}%',
              onChanged: (v) => st.setUiScale(v),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in presets)
                GestureDetector(
                  onTap: () => st.setUiScale(s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: st.uiScale == s ? C.cyanBg : C.bgSoft,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: st.uiScale == s ? C.cyan : C.border,
                        width: st.uiScale == s ? 1.5 : 1,
                      ),
                    ),
                    child: Text('${(s * 100).round()}%',
                        style: ts(12,
                            c: st.uiScale == s ? C.cyan : C.slate,
                            w: st.uiScale == s
                                ? FontWeight.w700
                                : FontWeight.w500)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: C.border),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: C.cyan,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(S.of(context).reloadUi,
                  style: ts(13, w: FontWeight.w600)),
              onPressed: () {
                st.reloadUi();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(S.of(context).reloadDone),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 地图类型选择
  Widget _mapTypeSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: C.border, width: 0.4))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(S.of(context).mapType, style: ts(12, c: C.slate)),
          SizedBox(height: 8),
          for (final group in ['高德', '其他']) ...[
            if (MapType.values.any((t) => t.group == group)) ...[
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 4),
                child: Text(
                  group == '高德' ? '国内地图' : '国际地图',
                  style: ts(10, c: C.grey, w: FontWeight.w700),
                ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in MapType.values.where((t) => t.group == group))
                    GestureDetector(
                      onTap: () => st.setMapType(t.name),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: st.mapType == t.name
                              ? C.blue
                              : C.bgSoft,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: st.mapType == t.name
                                ? C.blue
                                : C.border,
                          ),
                        ),
                        child: Text(t.label,
                            style: ts(11,
                                c: st.mapType == t.name
                                    ? Colors.white
                                    : C.slate,
                                w: FontWeight.w600)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
            ],
          ],
        ],
      ),
    );
  }

  Widget _datumSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: C.border, width: 0.4))),
      child: Row(children: [
        Text('坐标显示', style: ts(12, c: C.slate)),
        SizedBox(width: 12),
        Expanded(
          child: SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'wgs84', label: Text(S.of(context).wgs84)),
              ButtonSegment(value: 'gcj', label: Text(S.of(context).gcj02)),
            ],
            selected: {st.coordDatum},
            onSelectionChanged: (s) {
              st.coordDatum = s.first;
              st.persist();
            },
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              textStyle: WidgetStatePropertyAll(ts(11, w: FontWeight.w600)),
              foregroundColor: WidgetStateProperty.resolveWith(
                  (s) => s.contains(WidgetState.selected)
                      ? Colors.white
                      : C.blue),
              backgroundColor: WidgetStateProperty.resolveWith(
                  (s) => s.contains(WidgetState.selected)
                      ? C.blue
                      : Colors.transparent),
            ),
          ),
        ),
      ]),
    );
  }
}

/// ─── 聊天记录设置 ───
class ChatSettingsPage extends StatefulWidget {
  final AppState state;
  const ChatSettingsPage({super.key, required this.state});
  @override
  State<ChatSettingsPage> createState() => _ChatSettingsPageState();
}

class _ChatSettingsPageState extends State<ChatSettingsPage> {
  AppState get st => widget.state;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: st,
      builder: (context, _) => SettingsPageShell(
        title: S.of(context).msgHistory,
        subtitle: '消息、联系人与聊天数据',
        icon: Icons.forum_rounded,
        color: C.purple,
        body: Column(children: [
          SettingsSectionCard(
          title: S.of(context).statistics,
          subtitle: S.of(context).settingsChatStatsSubtitle,
          icon: Icons.analytics_rounded,
          color: C.purple,
          children: [
            SettingsRow2('消息条数', '${st.messages.length} 条'),
            SettingsRow2(S.of(context).contactList,
                '${st.stations.where((s) => s.favorite || s.manual).length} 个'),
          ],
        ),
        SizedBox(height: 16),
        SettingsSectionCard(
          title: '管理',
          subtitle: S.of(context).settingsChatManageSubtitle,
          icon: Icons.manage_search_rounded,
          color: C.blue,
          children: [
            _navRow(
              icon: Icons.people_alt_rounded,
              iconColor: C.purple,
              title: '管理联系人',
              onTap: () => _showContactManager(),
            ),
            _navRow(
              icon: Icons.delete_sweep_rounded,
              iconColor: C.red,
              title: S.of(context).clearMessages,
              titleColor: C.red,
              borderColor: C.red.withValues(alpha: 0.3),
              onTap: () => _confirmClearMessages(),
            ),
          ],
        ),
      ]),
      ),
    );
  }

  Widget _navRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required VoidCallback onTap,
    Color? titleColor,
    Color? borderColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        margin: const EdgeInsets.fromLTRB(14, 4, 14, 4),
        decoration: BoxDecoration(
          color: C.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor ?? C.border),
        ),
        child: Row(children: [
          Icon(icon, size: 16, color: iconColor),
          SizedBox(width: 8),
          Text(title, style: ts(12, c: titleColor ?? C.slate)),
          Spacer(),
          Icon(Icons.chevron_right_rounded, size: 18, color: C.grey),
        ]),
      ),
    );
  }

  void _confirmClearMessages() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(S.of(context).clearMessages, style: ts(16, w: FontWeight.w700)),
        content: Text('确定要删除全部 ${st.messages.length} 条聊天记录吗？此操作不可恢复。',
            style: ts(13, c: C.slate)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(S.of(context).cancel, style: ts(13, c: C.grey)),
          ),
          FilledButton(
            onPressed: () {
              st.clearMessages();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('聊天记录已清空')),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: C.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(S.of(context).clear, style: ts(13, c: Colors.white, w: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showContactManager() {
    final searchCtrl = TextEditingController();
    String filter = 'all';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          var contacts = st.stations
              .where((s) => s.favorite || s.manual)
              .toList();
          final q = searchCtrl.text.trim().toUpperCase();
          if (q.isNotEmpty) {
            contacts =
                contacts.where((s) => s.call.toUpperCase().contains(q)).toList();
          }
          if (filter == 'fav') {
            contacts = contacts.where((s) => s.favorite).toList();
          } else if (filter == 'online') {
            contacts = contacts.where((s) => s.status != St.offline).toList();
          }
          contacts.sort((a, b) {
            final aOn = a.status != St.offline;
            final bOn = b.status != St.offline;
            if (aOn != bOn) return aOn ? -1 : 1;
            if (a.favorite != b.favorite) return a.favorite ? -1 : 1;
            return a.call.compareTo(b.call);
          });
          return Container(
            height: MediaQuery.of(context).size.height * 0.72,
            decoration: BoxDecoration(
              color: C.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(children: [
              Container(width: 36, height: 4, decoration: BoxDecoration(
                  color: C.greyLight, borderRadius: BorderRadius.circular(2))),
              SizedBox(height: 12),
              Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: C.purple.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.people_alt_rounded, size: 18, color: C.purple),
                ),
                SizedBox(width: 10),
                Expanded(child: Text('管理联系人', style: ts(16, w: FontWeight.w700))),
                Text('${contacts.length} 个', style: ts(12, c: C.purple, w: FontWeight.w700)),
                SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _addContactDialog(setModalState),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: C.blue,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.person_add_rounded, size: 14, color: Colors.white),
                      SizedBox(width: 4),
                      Text('添加', style: ts(12, c: Colors.white, w: FontWeight.w700)),
                    ]),
                  ),
                ),
              ]),
              SizedBox(height: 12),
              TextField(
                controller: searchCtrl,
                onChanged: (_) => setModalState(() {}),
                style: ts(13),
                decoration: InputDecoration(
                  hintText: '搜索呼号…',
                  hintStyle: ts(12, c: C.greyLight),
                  prefixIcon:
                      Icon(Icons.search_rounded, size: 18, color: C.grey),
                  isDense: true,
                  filled: true,
                  fillColor: C.bgSoft,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              SizedBox(height: 10),
              Row(children: [
                _contactFilterChip(S.of(context).all, filter == 'all',
                    () => setModalState(() => filter = 'all')),
                SizedBox(width: 6),
                _contactFilterChip(S.of(context).favorite, filter == 'fav',
                    () => setModalState(() => filter = 'fav')),
                SizedBox(width: 6),
                _contactFilterChip(S.of(context).online, filter == 'online',
                    () => setModalState(() => filter = 'online')),
              ]),
              SizedBox(height: 10),
              Expanded(
                child: contacts.isEmpty
                    ? Center(child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.person_off_outlined, size: 44, color: C.greyLight),
                          SizedBox(height: 8),
                          Text('暂无联系人', style: ts(13, c: C.grey)),
                          SizedBox(height: 4),
                          Text('点击右上角「添加」或在地图上收藏台站',
                              style: ts(11, c: C.greyLight)),
                        ],
                      ))
                    : ListView.separated(
                        itemCount: contacts.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, indent: 52),
                        itemBuilder: (_, i) {
                          final s = contacts[i];
                          final online = s.status != St.offline;
                          return ListTile(
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 6),
                            leading: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  width: 38, height: 38,
                                  decoration: BoxDecoration(
                                    color: online
                                        ? C.green.withValues(alpha: 0.12)
                                        : C.purple.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(11),
                                  ),
                                  child: Center(
                                    child: Text(
                                      s.call.length >= 2
                                          ? s.call.substring(s.call.length - 2)
                                          : s.call,
                                      style: ts(11,
                                          c: online ? C.green : C.purple,
                                          w: FontWeight.w700),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: -2, bottom: -2,
                                  child: Container(
                                    width: 12, height: 12,
                                    decoration: BoxDecoration(
                                      color: online ? C.green : C.greyLight,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: C.white, width: 2),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            title: Row(children: [
                              Flexible(
                                child: Text(s.call,
                                    style: ts(13, w: FontWeight.w700),
                                    overflow: TextOverflow.ellipsis),
                              ),
                              if (s.favorite) ...[
                                SizedBox(width: 4),
                                Icon(Icons.star_rounded,
                                    size: 15, color: C.orange),
                              ],
                              if (s.manual) ...[
                                SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: C.blueBg,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text('手动',
                                      style: ts(8, c: C.blue, w: FontWeight.w600)),
                                ),
                              ],
                            ]),
                            subtitle: Text(
                              online
                                  ? (s.status == St.moving
                                      ? '移动中 · ${s.speedStr}'
                                      : S.of(context).online)
                                  : '${S.of(context).offline}${s.lastSeen}',
                              style: ts(11,
                                  c: online ? C.green : C.grey,
                                  w: FontWeight.w500),
                            ),
                            trailing: Row(
                                mainAxisSize: MainAxisSize.min, children: [
                              GestureDetector(
                                onTap: () {
                                  st.toggleFavorite(s.call);
                                  setModalState(() {});
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: s.favorite
                                        ? C.orange.withValues(alpha: 0.12)
                                        : C.bgSoft,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    s.favorite
                                        ? Icons.star_rounded
                                        : Icons.star_border_rounded,
                                    size: 18,
                                    color: s.favorite ? C.orange : C.grey,
                                  ),
                                ),
                              ),
                              SizedBox(width: 6),
                              GestureDetector(
                                onTap: () =>
                                    _confirmRemoveContact(s.call, () {
                                  setModalState(() {});
                                }),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: C.red.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                      Icons.delete_outline_rounded,
                                      size: 18, color: C.red),
                                ),
                              ),
                            ]),
                          );
                        },
                      ),
              ),
            ]),
          );
        },
      ),
    );
  }

  Widget _contactFilterChip(String label, bool sel, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? C.purple : C.bgSoft,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label,
            style: ts(11,
                c: sel ? Colors.white : C.slate,
                w: FontWeight.w600)),
      ),
    );
  }

  void _addContactDialog(void Function(VoidCallback) setModalState) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('添加联系人', style: ts(16, w: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('输入呼号手动添加到联系人列表', style: ts(12, c: C.grey)),
            SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              style: ts(14),
              onSubmitted: (_) => _addContactSubmit(ctrl, setModalState),
              decoration: InputDecoration(
                hintText: '呼号，如 BG7ABC',
                hintStyle: ts(13, c: C.greyLight),
                filled: true,
                fillColor: C.bgSoft,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(S.of(context).cancel, style: ts(13, c: C.grey)),
          ),
          FilledButton(
            onPressed: () => _addContactSubmit(ctrl, setModalState),
            style: FilledButton.styleFrom(
              backgroundColor: C.blue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('添加', style: ts(13, c: Colors.white, w: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _addContactSubmit(TextEditingController ctrl,
      void Function(VoidCallback) setModalState) {
    final call = ctrl.text.trim().toUpperCase();
    if (call.isEmpty) return;
    if (call.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('呼号至少 3 个字符')),
      );
      return;
    }
    st.addManualStation(call);
    Navigator.pop(context);
    setModalState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已添加联系人 $call'), duration: const Duration(seconds: 2)),
    );
  }

  void _confirmRemoveContact(String call, VoidCallback onDone) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('删除联系人', style: ts(16, w: FontWeight.w700)),
        content: Text('确定删除联系人 $call ？', style: ts(13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(S.of(context).cancel, style: ts(13, c: C.grey)),
          ),
          FilledButton(
            onPressed: () {
              st.removeContact(call);
              Navigator.pop(context);
              onDone();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('已删除 $call'), duration: const Duration(seconds: 2)),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: C.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(S.of(context).delete, style: ts(13, c: Colors.white, w: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

/// ─── 数据维护 ───
class DataSettingsPage extends StatefulWidget {
  final AppState state;
  const DataSettingsPage({super.key, required this.state});
  @override
  State<DataSettingsPage> createState() => _DataSettingsPageState();
}

class _DataSettingsPageState extends State<DataSettingsPage> {
  AppState get st => widget.state;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: st,
      builder: (context, _) => SettingsPageShell(
        title: '数据维护',
        subtitle: '清除本地数据',
        icon: Icons.storage_rounded,
        color: C.red,
        body: Column(children: [
        SettingsSectionCard(
          title: '清除所有数据',
          subtitle: S.of(context).settingsClearDataSubtitle,
          icon: Icons.delete_forever_rounded,
          color: C.red,
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('此操作将删除以下所有本地数据：', style: ts(13)),
                SizedBox(height: 8),
                _clearDataItem('台站列表', '${st.stations.length} 个'),
                _clearDataItem('聊天记录', '${st.messages.length} 条'),
                _clearDataItem('群聊', '${st.chatGroups.length} 个'),
                _clearDataItem('日志', '${st.logs.length} 条'),
                _clearDataItem('数据包', '${st.packets.length} 个'),
                SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: C.yellowBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(children: [
                    Icon(Icons.info_outline_rounded, size: 14, color: C.yellow),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text('此操作不可恢复，连接设置和呼号不会被删除。',
                          style: ts(11, c: C.yellow, w: FontWeight.w500)),
                    ),
                  ]),
                ),
                SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _confirmClearAll(),
                    icon: Icon(Icons.delete_forever_rounded, size: 18),
                    label: Text('确认清除所有数据'),
                    style: FilledButton.styleFrom(
                      backgroundColor: C.red,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ]),
      ),
    );
  }

  Widget _clearDataItem(String label, String count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Icon(Icons.circle, size: 6, color: C.grey),
        SizedBox(width: 8),
        Text(label, style: ts(12, c: C.slate)),
        Spacer(),
        Text(count, style: ts(11, c: C.grey, w: FontWeight.w600)),
      ]),
    );
  }

  void _confirmClearAll() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(Icons.warning_amber_rounded, color: C.red, size: 22),
          SizedBox(width: 8),
          Text('清除所有数据', style: ts(16, w: FontWeight.w700)),
        ]),
        content: Text('确定要清除全部本地数据吗？此操作不可恢复。', style: ts(13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(S.of(context).cancel, style: ts(13, c: C.grey)),
          ),
          FilledButton(
            onPressed: () {
              st.clearAllData();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('所有数据已清除'),
                  backgroundColor: C.green,
                ),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: C.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('确认清除', style: ts(13, c: Colors.white, w: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

/// ─── 高级设置 ───
class AdvancedSettingsPage extends StatefulWidget {
  final AppState state;
  const AdvancedSettingsPage({super.key, required this.state});
  @override
  State<AdvancedSettingsPage> createState() => _AdvancedSettingsPageState();
}

class _AdvancedSettingsPageState extends State<AdvancedSettingsPage> {
  bool _labOpen = false;
  bool _devOpen = false;
  final _devInput = TextEditingController();
  String? _devResult;

  AppState get st => widget.state;

  @override
  void dispose() {
    _devInput.dispose();
    super.dispose();
  }

  /// 确认后重新运行设置向导
  void _confirmRestartOobe() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('重新运行设置向导？', style: ts(16, w: FontWeight.w700)),
        content: Text('将重新进入首次启动向导，可重新设置呼号、接收地区等。\n当前设置不会丢失，完成向导后继续使用。',
            style: ts(13, c: C.slate, h: 1.6)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(S.of(context).cancel, style: ts(13, c: C.grey)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: C.orange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              st.restartOobe();
              // 弹出所有子路由，回到根路由（home 已切换为设置向导）
              Navigator.of(ctx).popUntil((r) => r.isFirst);
            },
            child: Text('重新运行', style: ts(13, c: Colors.white, w: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: st,
      builder: (context, _) => SettingsPageShell(
        title: S.of(context).advancedSettings2,
        subtitle: S.of(context).advancedDesc,
        icon: Icons.tune_rounded,
        color: C.slate,
        body: Column(children: [
        SettingsFold(
          title: S.of(context).advancedCat,
          subtitle: S.of(context).settingsLabSubtitle,
          icon: Icons.science_rounded,
          color: C.cyan,
          open: _labOpen,
          onToggle: () => setState(() => _labOpen = !_labOpen),
          children: [
            SettingsSwitch('允许手机横屏显示', value: st.labLandscape, color: C.cyan,
                onChanged: st.setLabLandscape),
            SettingsHint(S.of(context).labDesc),
          ],
        ),
        SizedBox(height: 16),
        SettingsFold(
          title: S.of(context).devDesc,
          subtitle: S.of(context).settingsDevSubtitle,
          icon: Icons.bug_report_rounded,
          color: C.purple,
          open: _devOpen,
          onToggle: () => setState(() => _devOpen = !_devOpen),
          children: [
            SettingsSwitch('启用模拟数据（演示台站/数据包）', value: st.devMode,
                onChanged: st.setDevMode),
            SettingsRow2('收包 / 发包', '${st.packetsRx} / ${st.packetsTx}'),
            SettingsRow2('台站数量', '${st.stations.length}'),
            SettingsRow2(S.of(context).connection, st.connInfo),
            Divider(height: 1, color: C.border),
            InkWell(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => LogPage(state: st)),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(children: [
                  Icon(Icons.receipt_long_rounded, size: 16, color: C.purple),
                  SizedBox(width: 8),
                  Text(S.of(context).systemLog, style: ts(12, c: C.slate, w: FontWeight.w600)),
                  Spacer(),
                  Text('${st.logs.length} 条', style: ts(11, c: C.grey)),
                  SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded, size: 18, color: C.grey),
                ]),
              ),
            ),
            Divider(height: 1, color: C.border),
            InkWell(
              onTap: () => _confirmRestartOobe(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(children: [
                  Icon(Icons.restart_alt_rounded, size: 16, color: C.orange),
                  SizedBox(width: 8),
                  Text(S.of(context).restartWizard, style: ts(12, c: C.slate, w: FontWeight.w600)),
                  Spacer(),
                  Icon(Icons.chevron_right_rounded, size: 18, color: C.grey),
                ]),
              ),
            ),
            Divider(height: 1, color: C.border),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('数据包解析测试',
                      style: ts(11, c: C.slate, w: FontWeight.w700)),
                  SizedBox(height: 6),
                  TextField(
                    controller: _devInput,
                    style: mono(11, c: C.ink),
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: '粘贴原始 APRS 包，如：\nBV2XYZ>APRS,TCPIP*:!3904.25N/11624.44E>测试台',
                      hintStyle: ts(11, c: C.grey),
                      filled: true,
                      fillColor: C.bgSoft,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          final r = st.injectRawPacket(_devInput.text.trim());
                          setState(() => _devResult = r);
                        },
                        icon: Icon(Icons.play_arrow_rounded, size: 16),
                        label: Text('解析并应用'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: C.purple,
                          side: BorderSide(color: C.purple.withValues(alpha: 0.5)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          textStyle: ts(11, w: FontWeight.w600),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          st.clearPackets();
                          setState(() => _devResult = '已清除数据包');
                        },
                        icon: Icon(Icons.delete_sweep_rounded, size: 16),
                        label: Text('清除数据包'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: C.slate,
                          side: BorderSide(color: C.borderStrong),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          textStyle: ts(11, w: FontWeight.w600),
                        ),
                      ),
                    ),
                  ]),
                  if (_devResult != null) ...[
                    SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: C.greenBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(_devResult!,
                          style: ts(11, c: C.green, w: FontWeight.w600)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ]),
      ),
    );
  }
}

