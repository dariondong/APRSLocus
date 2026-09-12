import 'package:flutter/material.dart';
import 'theme.dart';
import 'state.dart';
import 'models.dart';
import 'widgets.dart';
import 'settings_widgets.dart';
import 'log_page.dart';
import 'tile_map.dart';
import 'early_member.dart';
import 'weather.dart';

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
        subtitle: S.of(context).stationSettingsDetail,
        icon: Icons.person_rounded,
        color: C.blue,
        body: Column(children: [
        SettingsSectionCard(
          title: S.of(context).stationIdentity,
          subtitle: S.of(context).settingsStationIdentitySubtitle,
          icon: Icons.badge_rounded,
          color: C.blue,
          children: [
            SettingsInput(S.of(context).callsign, _call,
                tip: S.of(context).aprsCallsignHint,
                onChanged: (v) {
              if (v.trim().isNotEmpty) {
                st.myCall = v.trim().toUpperCase();
                st.persist();
              }
            }),
            _ssidRow(),
            _defaultBadgeRow(),
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
          title: S.of(context).displayInfo,
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
          Text(S.of(context).ssidSuffix, style: ts(12, c: C.slate)),
          Spacer(),
          Text(
            st.mySsid == 0 ? S.of(context).none : '-${st.mySsid}',
            style: ts(13, c: C.blue, w: FontWeight.w700),
          ),
          SizedBox(width: 4),
          Text('· ${st.myFullCall}', style: ts(10, c: C.grey)),
          SizedBox(width: 6),
          HonorBadge(st.myFullCall, symbol: st.mySymbol),
          SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, size: 18, color: C.grey),
        ]),
      ),
    );
  }

  /// 「默认展示徽章」行：选择呼号在主页/设置页展示的那枚徽章
  Widget _defaultBadgeRow() {
    return ListenableBuilder(
      listenable: memberListVersion,
      builder: (context, _) {
        final owns = ownedHonorsOf(st.myFullCall);
        if (owns.isEmpty) return const SizedBox.shrink();
        final cur = primaryHonorOf(st.myFullCall);
        return GestureDetector(
          onTap: () => _pickDefaultBadge(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: C.border, width: 0.4))),
            child: Row(children: [
              Icon(Icons.star_rounded, size: 16, color: C.yellow),
              SizedBox(width: 8),
              Text(S.of(context).homeBadgeLabel, style: ts(12, c: C.slate)),
              Spacer(),
              if (cur != null)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(cur.icon, size: 15, color: cur.color),
                  SizedBox(width: 4),
                  Text(cur.label,
                      style: ts(12, c: cur.color, w: FontWeight.w700)),
                ]),
              SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, size: 18, color: C.grey),
            ]),
          ),
        );
      },
    );
  }

  /// 选择默认展示徽章（底部弹层列出已获得徽章）
  void _pickDefaultBadge(BuildContext context) {
    final owns = ownedHonorsOf(st.myFullCall);
    if (owns.isEmpty) return;
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final cur = primaryHonorOf(st.myFullCall)?.key;
        return AlertDialog(
          title: Row(children: [
            Icon(Icons.star_rounded, size: 20, color: C.yellow),
            const SizedBox(width: 8),
            Text(S.of(context).homeBadgePickTitle, style: ts(16, w: FontWeight.w700)),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(S.of(context).homeBadgePickDesc,
                style: ts(12, c: C.slate)),
            const SizedBox(height: 14),
            for (final h in owns)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      setUserPrimary(st.myFullCall, h.key);
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: C.bgSoft,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: cur == h.key ? h.color : C.border,
                            width: cur == h.key ? 1.5 : 1),
                      ),
                      child: Row(children: [
                        Icon(h.icon, size: 20, color: h.color),
                        const SizedBox(width: 12),
                        Text(h.labelOf(honorLangOf(context)),
                            style: ts(14, w: FontWeight.w700)),
                        const Spacer(),
                        if (cur == h.key)
                          Icon(Icons.check_circle_rounded, size: 20, color: h.color),
                      ]),
                    ),
                  ),
                ),
              ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(S.of(context).cancel, style: ts(13, c: C.slate))),
          ],
        );
      },
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
            Text(S.of(context).chooseSsidSuffix, style: ts(16, w: FontWeight.w700)),
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
                      child: Text(val == 0 ? S.of(context).none : '-$val',
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
    // 名称已改走 l10n（见 symName），这里只做 符号码 → 图标 的查表
    final cats = _symCategories(S.of(context));
    (String, IconData)? cur;
    for (final cat in cats) {
      for (final s in cat.$2) {
        if (s.$1 == st.mySymbol) { cur = s; break; }
      }
      if (cur != null) break;
    }
    // 兜底：当前符号不在表内时退回第一项
    cur ??= cats.first.$2.first;
    return GestureDetector(
      onTap: () => _showSymbolPicker(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: C.border, width: 0.4))),
        child: Row(children: [
          Text(S.of(context).mySymbol, style: ts(12, c: C.slate)),
          Spacer(),
          Row(mainAxisSize: MainAxisSize.min, children: [
            _symIcon(cur.$1, cur.$2, active: true),
            SizedBox(width: 6),
            Text(symName(S.of(context), cur.$1),
                style: ts(12, w: FontWeight.w600)),
            SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, size: 18, color: C.grey),
          ]),
        ]),
      ),
    );
  }

  void _showSymbolPicker() {
    const syms = [
      ('>', Icons.directions_car_rounded),
      ('-', Icons.home_rounded),
      ('[', Icons.man_rounded),
      ('k', Icons.local_shipping_rounded),
      ('b', Icons.directions_bike_rounded),
      ('R', Icons.airport_shuttle_rounded),
      ('W', Icons.cloud_rounded),
      ('!', Icons.local_police_rounded),
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
                  Text(S.of(context).moreSymbols,
                      style: ts(12, c: C.blue, w: FontWeight.w600)),
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

  Widget _symTile(BuildContext ctx, (String, IconData) s) {
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
            _symIcon(s.$1, s.$2, active: sel),
            SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(symName(S.of(ctx), s.$1),
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
              Text(S.of(context).allAprsSymbols, style: ts(15, w: FontWeight.w700)),
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
                for (final cat in _symCategories(S.of(context))) ...[
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

}
/// 符号码 → 本地化名称（供符号表/信标图标等处复用）。
/// 名称统一走 l10n，避免再出现硬编码中文。
String symName(S s, String code) {
  switch (code) {
    case '>': return s.symCar;
    case '-': return s.symHouse;
    case '[': return s.symPerson;
    case 'k': return s.symTruck;
    case 'b': return s.symBicycle;
    case 'R': return s.symRv;
    case 'W': return s.symWxStation;
    case '!': return s.symPolice;
    case '<': return s.symMotorcycle;
    case 'u': return s.symSemi;
    case 'v': return s.symVan;
    case 'j': return s.symJeep;
    case 'U': return s.symBus;
    case 't': return s.symTruckStop;
    case '=': return s.symTrain;
    case 'f': return s.symFireTruck;
    case 'P': return s.symPoliceCar;
    case '*': return s.symSnowmobile;
    case 'y': return s.symYagi;
    case 'h': return s.symHospital;
    case 'a': return s.symAmbulance;
    case 'd': return s.symFireStation;
    case 'K': return s.symSchool;
    case 'H': return s.symMotel;
    case 'J': return s.symHotel;
    case 'l': return s.symLaptop;
    case ']': return s.symPostOffice;
    case '_': return s.symWeather;
    case 'w': return s.symWater;
    case '@': return s.symHurricane;
    case 'e': return s.symHorse;
    case 'p': return s.symDog;
    case ';': return s.symCamping;
    case 'z': return s.symShelter;
    case '+': return s.symRedCross;
    case ':': return s.symFireAlarm;
    case 'o': return s.symEmergCenter;
    case 'c': return s.symCmdCenter;
    case ')': return s.symHandicap;
    case '^': return s.symBigAircraft;
    case 'g': return s.symGlider;
    case 'O': return s.symBalloon;
    case 's': return s.symShip;
    case 'Y': return s.symSailboat;
    case '(': return s.symMobileSat;
    case '`': return s.symSatAntenna;
    case '#': return s.symDigi;
    case 'r': return s.symDigiTower;
    case 'm': return s.symMicE;
    case 'n': return s.symNode;
    case '%': return s.symDxCluster;
    case '&': return s.symHfGateway;
    case '?': return s.symFileServer;
    case r'$': return s.symTelephone;
    case 'q': return s.symGrid;
    case 'x': return s.symXUnix;
    case 'i': return s.symFmoStation;
    default: return code;
  }
}

/// APRS 符号表：只保留 符号码 + 图标，名称改走 l10n。
/// 原先名称是硬编码中文，且整表是**顶层 const**——顶层没有 context，
/// 因此改成接收 [S] 的函数，由调用方（State 内）传入。
List<(String, List<(String, IconData)>)> _symCategories(S s) => [
    (s.symCatVehicles, [
      ('>', Icons.directions_car_rounded),
      ('<', Icons.two_wheeler_rounded),
      ('k', Icons.local_shipping_rounded),
      ('u', Icons.local_shipping_rounded),
      ('v', Icons.airport_shuttle_rounded),
      ('j', Icons.directions_car_rounded),
      ('b', Icons.directions_bike_rounded),
      ('R', Icons.airport_shuttle_rounded),
      ('U', Icons.directions_bus_rounded),
      ('t', Icons.local_shipping_rounded),
      ('=', Icons.train_rounded),
      ('f', Icons.fire_truck_rounded),
      ('P', Icons.local_police_rounded),
      ('*', Icons.snowshoeing_rounded),
    ]),
    (s.symCatBuildings, [
      ('-', Icons.home_rounded),
      ('!', Icons.local_police_rounded),
      ('y', Icons.cell_tower_rounded),
      ('h', Icons.local_hospital_rounded),
      ('a', Icons.local_hospital_rounded),
      ('d', Icons.local_fire_department_rounded),
      ('K', Icons.school_rounded),
      ('H', Icons.hotel_rounded),
      ('J', Icons.local_hotel_rounded),
      ('[', Icons.man_rounded),
      ('l', Icons.laptop_rounded),
      (']', Icons.local_post_office_rounded),
    ]),
    (s.symCatNature, [
      ('W', Icons.cloud_rounded),
      ('_', Icons.cloud_rounded),
      ('w', Icons.water_drop_rounded),
      ('@', Icons.cyclone_rounded),
      ('=', Icons.train_rounded),
      ('e', Icons.pets_rounded),
      ('p', Icons.pets_rounded),
      (';', Icons.park_rounded),
      ('z', Icons.emergency_rounded),
    ]),
    (s.symCatEmergency, [
      ('!', Icons.local_police_rounded),
      ('+', Icons.medical_services_rounded),
      ('a', Icons.local_hospital_rounded),
      ('d', Icons.local_fire_department_rounded),
      (':', Icons.local_fire_department_rounded),
      ('o', Icons.apartment_rounded),
      ('c', Icons.sports_esports_rounded),
      (')', Icons.accessible_rounded),
    ]),
    (s.symCatAirWater, [
      ('\'', Icons.airplanemode_active_rounded),
      ('^', Icons.flight_rounded),
      ('g', Icons.flight_rounded),
      ('O', Icons.radio_rounded),
      ('s', Icons.directions_boat_rounded),
      ('Y', Icons.sailing_rounded),
      ('(', Icons.satellite_alt_rounded),
      ('`', Icons.satellite_alt_rounded),
    ]),
    (s.symCatComms, [
      ('#', Icons.cast_connected_rounded),
      ('r', Icons.cell_tower_rounded),
      ('m', Icons.cell_tower_rounded),
      ('n', Icons.track_changes_rounded),
      ('%', Icons.router_rounded),
      ('&', Icons.satellite_alt_rounded),
      ('?', Icons.dns_rounded),
      ('\$', Icons.call_rounded),
      ('q', Icons.grid_4x4_rounded),
      ('x', Icons.terminal_rounded),
      ('i', Icons.radio_rounded),
    ]),
  ];
List<(String, IconData)> _smartQuickSymbols(S s) => [
  ('>', Icons.directions_car_rounded),
  ('<', Icons.two_wheeler_rounded),
  ('k', Icons.local_shipping_rounded),
  ('v', Icons.airport_shuttle_rounded),
  ('j', Icons.directions_car_rounded),
  ('b', Icons.directions_bike_rounded),
  ('[', Icons.man_rounded),
  ('R', Icons.airport_shuttle_rounded),
  ('U', Icons.directions_bus_rounded),
  ('f', Icons.fire_truck_rounded),
  ('P', Icons.local_police_rounded),
  ('-', Icons.home_rounded),
];



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
  final _intervalFocus = FocusNode();
  bool _manualOpen = false;
  int? _fastApproved; // 已确认的低间隔值（避免同值重复弹窗）

  AppState get st => widget.state;

  @override
  void initState() {
    super.initState();
    _interval = TextEditingController(text: '${st.beaconInterval}');
    _myLat = TextEditingController(text: st.myLat?.toString() ?? '');
    _myLng = TextEditingController(text: st.myLng?.toString() ?? '');
    // 失焦时统一校验（避免逐字符输入就弹窗）
    _intervalFocus.addListener(() {
      if (!_intervalFocus.hasFocus) _applyIntervalInput();
    });
  }

  @override
  void dispose() {
    _intervalFocus.dispose();
    _interval.dispose();
    _myLat.dispose();
    _myLng.dispose();
    super.dispose();
  }

  /// 读取间隔输入并应用（仅提交/失焦时调用，不再逐字符触发弹窗）
  void _applyIntervalInput() {
    final n = int.tryParse(_interval.text.trim());
    if (n == null || n < 5) {
      // 非法输入回退到当前生效值
      _interval.text = '${st.beaconInterval}';
      return;
    }
    if (n < 60) {
      _confirmFastInterval(n);
    } else {
      st.setBeaconInterval(n);
    }
  }

  /// 信标间隔 < 60 秒 → 强提示（APRS-IS 建议移动站不低于 60 秒）
  Future<void> _confirmFastInterval(int n) async {
    if (_fastApproved == n) {
      st.setBeaconInterval(n);
      return;
    }
    final keep = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(children: [
          Icon(Icons.warning_amber_rounded, color: C.orange, size: 22),
          SizedBox(width: 8),
          Expanded(
            child: Text(S.of(context).beaconWarnTitle,
                style: ts(15, w: FontWeight.w700)),
          ),
        ]),
        content: Text(S.of(context).beaconWarnBody,
            style: ts(13, h: 1.7)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(S.of(context).beaconWarnFix,
                style: ts(13, c: C.blue)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(S.of(context).beaconWarnKeep, style: ts(13)),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (keep == true) {
      _fastApproved = n;
      st.setBeaconInterval(n);
    } else if (keep == false) {
      st.setBeaconInterval(60);
      setState(() => _interval.text = '60');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: st,
      builder: (context, _) => SettingsPageShell(
        title: S.of(context).beaconSettings,
        subtitle: S.of(context).beaconSettingsDetail,
        icon: Icons.my_location_rounded,
        color: C.green,
        body: Column(children: [
          SettingsSectionCard(
          title: S.of(context).locationSource,
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
                    desc: S.of(context).useDeviceLocation,
                    selected: !st.useSimLocation,
                    onTap: () => st.setUseSimLocation(false),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: _locSourceCard(
                    title: S.of(context).simulatedLocation,
                    icon: Icons.gps_off_rounded,
                    desc: S.of(context).manualCoordinates,
                    selected: st.useSimLocation,
                    onTap: () => st.setUseSimLocation(true),
                  ),
                ),
              ]),
            ),
            SizedBox(height: 10),
          ],
        ),
        // 模拟位置模式：手动定位坐标设置前置显示
        if (st.useSimLocation) ...[
          SizedBox(height: 16),
          // 手动定位
          SettingsFold(
            title: S.of(context).manualLocation,
            subtitle: S.of(context).settingsManualLocSubtitle,
            icon: Icons.gps_off_rounded,
            color: C.orange,
            open: _manualOpen || st.useSimLocation,
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
                        hintText: S.of(context).latitudeHint,
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
                        hintText: S.of(context).longitudeHint,
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
                            SnackBar(
                                content: Text(S.of(context).invalidLatLng)),
                          );
                          return;
                        }
                        st.setMyPosition(lat, lng);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(S.of(context)
                                .myPositionSet(st.myGrid)),
                          ),
                        );
                      },
                      icon: Icon(Icons.my_location_rounded, size: 15),
                      label: Text(S.of(context).applyCoordinates),
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
                      label: Text(S.of(context).pickOnMap),
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
        ],
        // 模拟位置模式下 GPS 定位模式无意义，隐藏
        if (!st.useSimLocation) ...[
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
        ],
        SizedBox(height: 16),
        SettingsSectionCard(
          title: S.of(context).beaconingSection,
          subtitle: S.of(context).settingsBeaconSubtitle,
          icon: Icons.radio_rounded,
          color: C.blue,
          children: [
            SettingsSwitch(S.of(context).beaconEnabled, value: st.beaconEnabled,
                onChanged: st.setBeaconEnabled),
            // 固定间隔：仅在关闭智能信标时作为兜底使用
            if (!st.smartBeaconEnabled)
              SettingsInput(S.of(context).beaconInterval, _interval,
                  tip: S.of(context).beaconIntervalTip,
                  focusNode: _intervalFocus,
                  onEditingComplete: () {
                    // 回车=确认：立即收起键盘并校验
                    _intervalFocus.unfocus();
                    _applyIntervalInput();
                  }),
            SettingsSwitch(S.of(context).smartBeacon,
                value: st.smartBeaconEnabled, onChanged: st.setSmartBeaconOn),
            if (st.smartBeaconEnabled) _smartTierArea(),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.tune_rounded, size: 15, color: C.green),
                    SizedBox(width: 6),
                    Text(S.of(context).beaconContent, style: ts(12, c: C.green, w: FontWeight.w700)),
                  ]),
                  SizedBox(height: 2),
                  Text(S.of(context).beaconContentDesc, style: ts(10, c: C.slate)),
                  SizedBox(height: 4),
                  SettingsMiniSwitch(S.of(context).speed, value: st.beaconIncludeSpeed,
                      onChanged: st.setBeaconIncludeSpeed),
                  SettingsMiniSwitch(S.of(context).bearing, value: st.beaconIncludeCourse,
                      onChanged: st.setBeaconIncludeCourse),
                  SettingsMiniSwitch(S.of(context).phoneBattery, value: st.beaconIncludeBattery,
                      onChanged: st.setBeaconIncludeBattery),
                ],
              ),
            ),
            SettingsRow2(S.of(context).locationStatus,
                localizedLocationStatus(context, st.locStatus)),
            SettingsRow2(S.of(context).beaconsSent,
            S.of(context).beaconsSentCount('${st.beaconsSent}')),
            SettingsRow2(S.of(context).nextBeacon, st.nextBeaconIn),
            // 模拟位置模式：不显示 GPS 启动按钮，改为提示
            if (st.useSimLocation)
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Icon(Icons.gps_off_rounded, color: C.orange, size: 16),
                  SizedBox(width: 8),
                  Text(S.of(context).simLocationHint,
                      style: ts(12, c: C.orange, w: FontWeight.w600)),
                ]),
              )
            else if (!st.loc.running)
              Padding(
                padding: const EdgeInsets.all(14),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: st.startTracking,
                    icon: Icon(Icons.gps_fixed_rounded, size: 16),
                    label: Text(st.myHasFix ? S.of(context).relocate : S.of(context).startGps),
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
                  Text(S.of(context).trackingBeaconing,
                      style: ts(12, c: C.green, w: FontWeight.w600)),
                ]),
              ),
          ],
        ),

      ]),
      ),
    );
  }

  // ─── 智能信标 · 按速度分档编辑区 ───

  /// 速度档范围文案：静止/低速 / X–Y / ≥X
  String _tierRange(int index) {
    final tiers = st.smartTiers;
    if (index >= tiers.length) return '';
    final t = tiers[index];
    if (t.minSpeed <= 0) {
      final next = _nextMin(index);
      final seg = next == null ? '' : ' · < $next km/h';
      return '${S.of(context).tierIdleShort}$seg';
    }
    final next = _nextMin(index);
    return next == null
        ? '≥ ${t.minSpeed} km/h'
        : '${t.minSpeed}–${next - 1} km/h';
  }

  int? _nextMin(int index) {
    final tiers = st.smartTiers;
    if (index + 1 >= tiers.length) return null;
    return tiers[index + 1].minSpeed;
  }

  /// 显示 APRS 符号（空串 = 我的符号，带图标）
  Widget _symCharIcon(String symbol, {double size = 30}) {
    final sym = symbol.isNotEmpty ? symbol : st.mySymbol;
    final png = AprsSym.iconAsset('/', sym);
    final Widget icon = Icon(AprsSym.icon(sym),
        size: size - 6, color: symbol.isEmpty ? C.slate : C.blue);
    if (png == null) return icon;
    return Image.asset(png,
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => icon);
  }

  /// 智能信标开启后的分档配置区
  Widget _smartTierArea() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      decoration: BoxDecoration(
        color: C.bgSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.speed_rounded, size: 15, color: C.blue),
          SizedBox(width: 6),
          Text(S.of(context).speedTierRules,
              style: ts(11, c: C.blue, w: FontWeight.w700)),
          Spacer(),
          GestureDetector(
            onTap: () => st.resetSmartTiers(),
            child: Row(children: [
              Icon(Icons.restart_alt_rounded, size: 13, color: C.slate),
              SizedBox(width: 3),
              Text(S.of(context).restoreDefaults, style: ts(10, c: C.slate)),
            ]),
          ),
        ]),
        SizedBox(height: 2),
        // 原文案是两个相邻字符串拼接成的一段话，这里保持「一段」语义
        Text('${S.of(context).speedTierDesc}'
            '${S.of(context).speedTierShortIntervalWarn}',
            style: ts(9, c: C.slate)),
        SizedBox(height: 6),
        for (int i = 0; i < st.smartTiers.length; i++) _tierRow(i),
        SizedBox(height: 2),
        if (st.smartTiers.length < 5)
          Align(
            alignment: Alignment.center,
            child: TextButton.icon(
              onPressed: st.addSmartTier,
              icon: Icon(Icons.add_rounded, size: 15, color: C.blue),
              label: Text(S.of(context).addSpeedTier, style: ts(11, c: C.blue)),
              style: TextButton.styleFrom(
                foregroundColor: C.blue,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4),
            child: Center(child: Text(S.of(context).maxSpeedTiers, style: ts(9, c: C.grey))),
          ),
      ]),
    );
  }

  Widget _tierRow(int index) {
    final t = st.smartTiers[index];
    return GestureDetector(
      onTap: () => _editTierSheet(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
        decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: C.border, width: 0.3))),
        child: Row(children: [
          _symCharIcon(t.symbol, size: 26),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_tierRange(index),
                    style: ts(11,
                        w: FontWeight.w700, c: index == 0 ? C.slate : C.ink)),
                SizedBox(height: 1),
                Text(t.symbol.isEmpty
                    ? S.of(context).iconDefaultMySymbol
                    : S.of(context).iconNamed(symName(S.of(context), t.symbol)),
                    style: ts(9, c: C.slate)),
              ],
            ),
          ),
          Text(S.of(context).everyNSeconds('${t.intervalSec}'),
              style: ts(11, c: C.blue, w: FontWeight.w700)),
          SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, size: 16, color: C.grey),
        ]),
      ),
    );
  }

  InputDecoration _tierFieldDeco(String label) => InputDecoration(
        labelText: label,
        labelStyle: ts(11, c: C.slate),
        isDense: true,
        border: UnderlineInputBorder(borderSide: BorderSide(color: C.border)),
        focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: C.blue, width: 1.5)),
      );

  /// 编辑某一档：index==0 为静止档（阈值锁定 0，仅可改间隔/图标）
  Future<void> _editTierSheet(int index) async {
    final tiers = st.smartTiers;
    if (index < 0 || index >= tiers.length) return;
    final isIdle = index == 0;
    final thCtrl = TextEditingController(text: '${tiers[index].minSpeed}');
    final ivCtrl = TextEditingController(text: '${tiers[index].intervalSec}');
    final symNotifier = ValueNotifier<String>(tiers[index].symbol);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        void close() => Navigator.pop(ctx);
        return Container(
          decoration: BoxDecoration(
            color: C.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.fromLTRB(20, 10, 20,
              MediaQuery.of(ctx).viewInsets.bottom + 10),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                        color: C.grey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                SizedBox(height: 12),
                Row(children: [
                  Icon(Icons.speed_rounded, size: 18, color: C.blue),
                  SizedBox(width: 8),
                  Text(isIdle
              ? S.of(context).tierIdleTitle
              : S.of(context).tierSpeedTitle,
                      style: ts(15, w: FontWeight.w700)),
                  Spacer(),
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 20, color: C.grey),
                    onPressed: close,
                  ),
                ]),
                if (!isIdle)
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: thCtrl,
                        keyboardType: TextInputType.number,
                        style: ts(13, w: FontWeight.w600),
                        decoration: _tierFieldDeco(S.of(context).minSpeedKmh),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: ivCtrl,
                        keyboardType: TextInputType.number,
                        style: ts(13, w: FontWeight.w600),
                        decoration: _tierFieldDeco(S.of(context).intervalSeconds),
                      ),
                    ),
                  ])
                else
                  Row(children: [
                    Text(S.of(context).idleTierDesc,
                        style: ts(11, c: C.slate)),
                    Spacer(),
                    Text(S.of(context).intervalLabel, style: ts(11, c: C.slate)),
                    SizedBox(width: 8),
                    SizedBox(
                      width: 84,
                      child: TextField(
                        controller: ivCtrl,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.right,
                        style: ts(13, w: FontWeight.w700),
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 8),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    Text(S.of(context).unitSeconds, style: ts(11, c: C.slate)),
                  ]),
                SizedBox(height: 14),
                Text(S.of(context).pickBeaconIconDesc,
                    style: ts(10, c: C.slate)),
                SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  _symbolOpt(ctx, symNotifier, '', S.of(context).defaultLabel),
                  for (final q in _smartQuickSymbols(S.of(context)))
                    _symbolOpt(ctx, symNotifier, q.$1,
                        symName(S.of(context), q.$1)),
                ]),
                SizedBox(height: 16),
                Row(children: [
                  if (!isIdle)
                    TextButton.icon(
                      onPressed: () {
                        st.removeSmartTier(index);
                        close();
                      },
                      icon: Icon(Icons.delete_outline_rounded,
                          size: 16, color: C.red),
                      label: Text(S.of(context).deleteThisTier, style: ts(11, c: C.red)),
                    )
                  else
                    Text(S.of(context).idleTierNotDeletable, style: ts(10, c: C.grey)),
                  Spacer(),
                  OutlinedButton(
                    onPressed: close,
                    child: Text(S.of(context).cancel, style: ts(12)),
                  ),
                  SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      int? th = isIdle ? 0 : int.tryParse(thCtrl.text.trim());
                      int? iv = int.tryParse(ivCtrl.text.trim());
                      String? err;
                      if (!isIdle && (th == null || th < 1)) {
                        err = S.of(context).errMinSpeedInt;
                      } else if (iv == null || iv < 5) {
                        err = S.of(context).errIntervalInt;
                      } else if (!isIdle && th != null) {
                        for (var i = 0; i < tiers.length; i++) {
                          if (i != index && tiers[i].minSpeed == th) {
                            err = S.of(context).errTierDuplicate;
                            break;
                          }
                        }
                      }
                      if (err != null) {
                        ScaffoldMessenger.of(ctx)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(SnackBar(
                            content: Text(err, style: ts(12)),
                            duration: const Duration(seconds: 2),
                          ));
                        return;
                      }
                      st.updateSmartTier(
                        index,
                        SmartBeaconTier(
                          minSpeed: th!,
                          intervalSec: iv!,
                          symbol: symNotifier.value,
                        ),
                      );
                      close();
                    },
                    child: Text(S.of(context).save, style: ts(12)),
                  ),
                ]),
              ],
            ),
            ),
          );
        },
      );
    thCtrl.dispose();
    ivCtrl.dispose();
    symNotifier.dispose();
  }

  Widget _symbolOpt(BuildContext ctx, ValueNotifier<String> sym,
      String symbol, String label) {
    return ValueListenableBuilder<String>(
      valueListenable: sym,
      builder: (ctx, cur, _) {
        final sel = cur == symbol;
        return GestureDetector(
          onTap: () => sym.value = symbol,
          child: Container(
            width: 76,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: sel ? C.blueBg : C.bgSoft,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: sel ? C.blue : C.border, width: sel ? 1.5 : 1),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              _symCharIcon(symbol, size: 26),
              SizedBox(height: 2),
              Text(label,
                  style: ts(9,
                      c: sel ? C.blue : C.slate,
                      w: sel ? FontWeight.w700 : FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ]),
          ),
        );
      },
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
  late final TextEditingController _maxPackets;
  late final TextEditingController _maxTrackPts;
  // 在线判定时长（分钟）——原先写死 5 分钟，现改为用户可配置
  late final TextEditingController _onlineWindow;

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
    _maxPackets = TextEditingController(text: '${st.maxPackets}');
    _maxTrackPts = TextEditingController(text: '${st.maxTrackPts}');
    _onlineWindow = TextEditingController(text: '${st.onlineWindowMin}');
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
    _maxPackets.dispose();
    _maxTrackPts.dispose();
    _onlineWindow.dispose();
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
            // ① APRS-IS 连接（连接状态 + 服务器参数，原为两张重复卡）
            _connectionCard(),
            const SizedBox(height: 16),
            // ② 过滤中心：只管「取哪些台站」
            _filterCard(),
            const SizedBox(height: 16),
            // ③ 存储上限：只管「保留多少数据」（原误放在过滤卡片内）
            _storageCard(),
            const SizedBox(height: 16),
            // ④ 接收筛选：按国家/地区
            _receivePrefCard(),
          ]),
      );
    });
  }

  /// APRS-IS 连接卡片。
  /// 原先拆成「服务器（连接状态）」+「服务器配置」两张卡，标题都指向服务器、
  /// 语义重复；现合并为一张：连接状态 → 服务器参数 → 配置变更提示。
  Widget _connectionCard() {
    return SettingsSectionCard(
      title: S.of(context).connectionCard2,
      subtitle: S.of(context).settingsConnStatusSubtitle,
      icon: Icons.dns_rounded,
      color: C.purple,
      children: [
        _connBanner(),
        Divider(height: 1, color: C.border),
        SettingsRow2(S.of(context).connection,
            localizedConnectionInfo(context, st.connInfo)),
        Divider(height: 1, color: C.border),
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
        SettingsInput(S.of(context).wsUrlOptional, _ws,
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
                      Text(S.of(context).configChanged,
                          style: ts(13, c: C.orange, w: FontWeight.w700)),
                      Text(S.of(context).reconnectToApply,
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
                            ? S.of(context).reconnected
                            : S.of(context).connectFailedCheckConfig),
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
              child: Text(S.of(context).unverified,
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
            hintText: S.of(context).passcodeUnverifiedHint,
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
        Text(S.of(context).passcodeMessageWarning,
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
            Text(localizedConnectionInfo(context, st.connInfo),
                style: ts(11, c: col.withValues(alpha: 0.8))),
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
        SettingsSwitch(S.of(context).filterCenterFollows, value: st.filterFollow, color: C.cyan,
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
            tip: S.of(context).radiusTip,
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
                    content: Text(S.of(context)
                        .filterSavedRadius(S.of(context).filterSaved, st.filterRadius)),
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

  /// 存储上限卡片。
  /// 原先这三项被放在「过滤」卡片里 —— 它们与「取哪些台站」无关，
  /// 而是「本地保留多少数据」，故按职责独立成卡。
  Widget _storageCard() {
    return SettingsSectionCard(
      title: S.of(context).storageLimit,
      subtitle: S.of(context).storageLimitSubtitle,
      icon: Icons.sd_storage_rounded,
      color: C.slate,
      children: [
        SettingsInput(S.of(context).maxStations, _maxStations,
            tip: S.of(context).maxStationsTip,
            onChanged: (v) {
          final n = int.tryParse(v);
          if (n != null) st.setMaxStations(n);
        }),
        // 数据包保留条数（原先硬编码 200，偏少）
        SettingsInput(S.of(context).maxPackets, _maxPackets,
            tip: S.of(context).maxPacketsTip, onChanged: (v) {
          final n = int.tryParse(v);
          if (n != null) st.setMaxPackets(n);
        }),
        // 单台站轨迹点数上限（原先硬编码 60，导致轨迹很短）
        SettingsInput(S.of(context).maxTrackPts, _maxTrackPts,
            tip: S.of(context).maxTrackPtsTip, onChanged: (v) {
          final n = int.tryParse(v);
          if (n != null) st.setMaxTrackPts(n);
        }),
        // 在线判定时长（原先写死 5 分钟）
        SettingsInput(S.of(context).onlineWindow, _onlineWindow,
            tip: S.of(context).onlineWindowTip, onChanged: (v) {
          final n = int.tryParse(v);
          if (n != null) st.setOnlineWindowMin(n);
        }),
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
                  Text(S.of(context).add, style: ts(11, c: C.cyan, w: FontWeight.w700)),
                ]),
              ),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(S.of(context).receiveCountryDesc,
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
                  Text(S.of(context).countryUnrestricted,
                      style: ts(11, c: C.grey)),
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
                      Text(S.of(context).receiveOthersDesc,
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
        title: Text(S.of(context).addCountry, style: ts(16, w: FontWeight.w700)),
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
              SettingsSwitch(S.of(context).weatherWidget, value: st.weatherEnabled,
                  color: C.cyan, onChanged: (v) => st.setWeatherEnabled(v)),
              _themeColorSelector(st),
              _languageSelector(st),
              _uiScaleSelector(st),
              SettingsRow2(S.of(context).unit, S.of(context).metricUnits),
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
      ('zh_TW', S.of(context).languageZhTw),
      ('en', S.of(context).languageEn),
      ('ja', S.of(context).languageJa),
      ('id', S.of(context).languageId),
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
          // 注意：这里用 MapType.group 的原始判别值（'高德'/'其他'）做分组，
          // 它们同时是数据实参——不能替换成 l10n 文案，否则分组会失效；
          // 展示用的标题改走 domesticMaps / internationalMaps。
          for (final group in const ['高德', '其他']) ...[
            if (MapType.values.any((t) => t.group == group)) ...[
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 4),
                child: Text(
                  group == '高德'
                      ? S.of(context).domesticMaps
                      : S.of(context).internationalMaps,
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
        Text(S.of(context).coordDisplay, style: ts(12, c: C.slate)),
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
/// ─── 设备设置（占位：尚未开放）───
class DeviceSettingsPage extends StatelessWidget {
  final AppState state;
  const DeviceSettingsPage({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return SettingsPageShell(
      title: s.deviceSettings2,
      subtitle: s.deviceSettingsSubtitle,
      icon: Icons.radio_rounded,
      color: C.indigo,
      body: Column(children: [
        SettingsSectionCard(
          title: s.deviceSettings2,
          subtitle: s.deviceSettingsSubtitle,
          icon: Icons.construction_rounded,
          color: C.orange,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
              child: Column(children: [
                Icon(Icons.construction_rounded,
                    size: 54, color: C.orange.withValues(alpha: 0.6)),
                const SizedBox(height: 16),
                Text(s.underConstruction,
                    style: ts(15, w: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(s.underConstructionHint,
                    textAlign: TextAlign.center,
                    style: ts(12, c: C.grey, h: 1.7)),
              ]),
            ),
          ],
        ),
      ]),
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
        title: S.of(context).dataMaintenance,
        subtitle: S.of(context).dataCatDesc,
        icon: Icons.storage_rounded,
        color: C.red,
        body: Column(children: [
        // 单项：聊天记录（由原「聊天设置」页合并而来）
        SettingsSectionCard(
          title: S.of(context).chatRecords,
          subtitle: S.of(context).settingsChatManageSubtitle,
          icon: Icons.forum_rounded,
          color: C.purple,
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                _clearDataItem(S.of(context).chatHistory,
                    S.of(context).nMessages('${st.messages.length}')),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _confirmClearMessages,
                    icon: const Icon(Icons.delete_sweep_rounded, size: 16),
                    label: Text(S.of(context).clearMessages),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: C.red,
                      side: BorderSide(color: C.red.withValues(alpha: 0.4)),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      textStyle: ts(12, w: FontWeight.w700),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ]),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SettingsSectionCard(
          title: S.of(context).clearAllData,
          subtitle: S.of(context).settingsClearDataSubtitle,
          icon: Icons.delete_forever_rounded,
          color: C.red,
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(S.of(context).clearAllDataIntro, style: ts(13)),
                SizedBox(height: 8),
                _clearDataItem(S.of(context).stationList,
                    S.of(context).nItems('${st.stations.length}')),
                _clearDataItem(S.of(context).chatHistory,
                    S.of(context).nMessages('${st.messages.length}')),
                _clearDataItem(S.of(context).groupChatLabel,
                    S.of(context).nItems('${st.chatGroups.length}')),
                _clearDataItem(S.of(context).logs,
                    S.of(context).nMessages('${st.logs.length}')),
                _clearDataItem(S.of(context).packets,
                    S.of(context).nItems('${st.packets.length}')),
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
                      child: Text(S.of(context).irreversibleKeepSettings,
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
                    label: Text(S.of(context).confirmClearAllData),
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

  /// 清空全部聊天记录（由原「聊天设置」页迁入）
  void _confirmClearMessages() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(S.of(context).clearMessages, style: ts(16, w: FontWeight.w700)),
        content: Text(S.of(context).confirmDeleteMessages('${st.messages.length}'),
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
                SnackBar(content: Text(S.of(context).chatRecordsCleared)),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: C.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(S.of(context).clear,
                style: ts(13, c: Colors.white, w: FontWeight.w600)),
          ),
        ],
      ),
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
          Text(S.of(context).clearAllData, style: ts(16, w: FontWeight.w700)),
        ]),
        content: Text(S.of(context).clearAllDataConfirm, style: ts(13)),
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
                  content: Text(S.of(context).allDataCleared),
                  backgroundColor: C.green,
                ),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: C.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(S.of(context).confirmClear, style: ts(13, c: Colors.white, w: FontWeight.w700)),
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
  /// 天气模拟选择（开发者调试：预览不同天气的面板背景/粒子/火腿建议）
  Widget _buildWeatherSim() {
    final wc = WeatherCenter.instance;
    // 名称走 l10n：这里只保留 天气码 + 温度 + 降水量
    final s = S.of(context);
    final options = <(String?, String, String, String)>[
      (null, s.weatherSimFollowLive, '--', '--'),      // 恢复真实
      ('100', s.wxClear, '26', '0'),
      ('101', s.wxCloudy, '24', '0'),
      ('104', s.wxOvercast, '22', '0'),
      ('305', s.wxLightRain, '20', '1.2'),
      ('306', s.wxModerateRain, '19', '6.5'),
      ('307', s.wxHeavyRain, '18', '14'),
      ('310', s.wxStormRain, '17', '32'),
      ('302', s.wxThunder, '22', '8'),
      ('400', s.wxSnow, '-2', '2'),
      ('501', s.wxFog, '16', '0'),
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.ac_unit_rounded, size: 16, color: C.cyan),
          const SizedBox(width: 8),
          Text(S.of(context).weatherSimTitle,
              style: ts(11, c: C.slate, w: FontWeight.w700)),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final (code, label, temp, precip) in options)
            GestureDetector(
              onTap: () {
                wc.setSimulation(code,
                    text: label, temp: temp, precip: precip);
                setState(() {});
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: (wc.simIcon == code) ? C.cyanBg : C.bgSoft,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (wc.simIcon == code) ? C.cyan : C.border,
                  ),
                ),
                child: Text(label,
                    style: ts(11,
                        c: (wc.simIcon == code) ? C.cyan : C.slate,
                        w: (wc.simIcon == code)
                            ? FontWeight.w700
                            : FontWeight.w500)),
              ),
            ),
        ]),
        const SizedBox(height: 6),
        Text(S.of(context).weatherSimDesc,
            style: ts(9.5, c: C.grey)),
      ]),
    );
  }

  void _confirmRestartOobe() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(S.of(context).restartWizardTitle, style: ts(16, w: FontWeight.w700)),
        content: Text(S.of(context).restartWizardConfirm,
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
            child: Text(S.of(context).restartWizardButton,
              style: ts(13, c: Colors.white, w: FontWeight.w700)),
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
            SettingsSwitch(S.of(context).allowLandscape, value: st.labLandscape, color: C.cyan,
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
            SettingsSwitch(S.of(context).simData, value: st.devMode,
                onChanged: st.setDevMode),
            Divider(height: 1, color: C.border),
            _buildWeatherSim(),
            SettingsRow2(S.of(context).rxTx, '${st.packetsRx} / ${st.packetsTx}'),
            SettingsRow2(S.of(context).stationCount2, '${st.stations.length}'),
            SettingsRow2(S.of(context).connection,
            localizedConnectionInfo(context, st.connInfo)),
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
                  Text(S.of(context).nMessages('${st.logs.length}'),
                  style: ts(11, c: C.grey)),
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
                  Text(S.of(context).packetParseTest,
                      style: ts(11, c: C.slate, w: FontWeight.w700)),
                  SizedBox(height: 6),
                  TextField(
                    controller: _devInput,
                    style: mono(11, c: C.ink),
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: S.of(context).pasteAprsPacketHint,
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
                        label: Text(S.of(context).parseAndApply),
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
                          setState(() => _devResult = S.of(context).clearedPackets);
                        },
                        icon: Icon(Icons.delete_sweep_rounded, size: 16),
                        label: Text(S.of(context).clearPackets),
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

