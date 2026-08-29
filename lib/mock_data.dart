import 'dart:math';
import 'models.dart';

final _r = Random(42);

List<Station> makeStations() {
  const calls = [
    ('BV2AAM', '>', 'Person'), ('BV2BBB', '!', 'QTH'),
    ('BV2CCC', '>', 'Car'), ('BV2DDD', '-', 'Truck'),
    ('BV2EEE', 'k', 'ATV'), ('BV2FFF', '>', 'Hiker'),
    ('BV2GGG', '>', 'Portable'), ('BV2HHH', 'b', 'Bus'),
    ('BV2III', 'c', 'Bicycle'), ('JA1ABC', '>', 'JA Station'),
    ('JA1DEF', '-', 'Truck'), ('BV5AAA', '>', 'Yacht'),
    ('BV2RPT', 'R', 'Repeater'), ('BV2DIG', '#', 'Digi'),
    ('BV2WX', 'W', 'WX'),
  ];
  return List.generate(calls.length, (i) {
    final c = calls[i];
    final lat = 39.9042 + (_r.nextDouble() - 0.5) * 0.18;
    final lng = 116.4074 + (_r.nextDouble() - 0.5) * 0.22;
    return Station(
      call: c.$1, symbol: c.$2, alias: c.$3,
      lat: lat, lng: lng,
      alt: 30 + _r.nextDouble() * 600,
      speed: 10 + _r.nextDouble() * 70,
      course: _r.nextDouble() * 360,
      comment: _pick(c.$3),
      lastHeard: DateTime.now().subtract(Duration(seconds: _r.nextInt(7200))),
      status: St.values[_r.nextInt(St.values.length)],
      track: _track(lat, lng, i),
      wx: c.$2 == 'W' ? _weather() : null,
    );
  });
}

String _weather() {
  const sky = ['晴', '多云', '阴', '小雨', '雷阵雨'];
  final t = 18 + _r.nextDouble() * 12;
  final wind = 2 + _r.nextDouble() * 25;
  final hum = 30 + _r.nextDouble() * 55;
  return '${sky[_r.nextInt(sky.length)]} · ${t.toStringAsFixed(1)}°C'
      ' · 风${wind.toStringAsFixed(0)}km/h · 湿度${hum.toStringAsFixed(0)}%';
}

List<TrackPt> _track(double lat, double lng, int seed) {
  final r2 = Random(seed);
  double a = lat, b = lng;
  return List.generate(40, (i) {
    a += (r2.nextDouble() - 0.5) * 0.003;
    b += (r2.nextDouble() - 0.5) * 0.003;
    return TrackPt(a, b, DateTime.now().subtract(Duration(minutes: i * 3)));
  });
}

String _pick(String t) {
  const m = {
    'Person': ['徒步中', '便携台', 'QRP 通联'],
    'Car': ['驾车移动', '行驶中', '通勤'],
    'Truck': ['配送中', '货运'],
    'Bicycle': ['骑行中', '通勤'],
    'Bus': ['42 路', '运行中'],
    'Yacht': ['航行中', '锚泊'],
    'ATV': ['越野', '山道'],
    'QTH': ['家中', '基地'],
    'Repeater': ['145.160 MHz', '覆盖广'],
    'Digi': ['填充中继', '接收门限'],
    'WX': ['气象站', '自动站'],
    'Hiker': ['SOTA 登山', '徒步'],
    'Portable': ['野外架台', '便携'],
    'JA Station': ['东京地区'],
  };
  final l = m[t] ?? ['APRS'];
  return l[_r.nextInt(l.length)];
}

List<Packet> makePackets(List<Station> stations) {
  final types = ['position', 'message', 'weather', 'status', 'object'];
  return List.generate(60, (i) {
    final s = stations[_r.nextInt(stations.length)];
    final t = types[_r.nextInt(types.length)];
    return Packet(
      '${s.call}>APOLOCUS:/${s.lat.toStringAsFixed(4)}N/${s.lng.toStringAsFixed(4)}E${s.symbol}',
      s.call, 'APRS', t,
      DateTime.now().subtract(Duration(minutes: _r.nextInt(180))),
      info: t == 'weather'
          ? '${(15 + _r.nextDouble() * 20).toStringAsFixed(1)}°C  Wind ${(_r.nextDouble() * 30).toStringAsFixed(0)}kph'
          : t == 'message'
              ? 'QTH?'
              : '${s.lat.toStringAsFixed(4)}, ${s.lng.toStringAsFixed(4)}',
    );
  })..sort((a, b) => b.time.compareTo(a.time));
}

List<AprsMsg> makeMessages() {
  const data = [
    ('BV2AAA', 'BV2BBB', 'QTH?'), ('BV2BBB', 'BV2AAA', 'EM79qe'),
    ('BV2CCC', 'BV2DDD', 'QRZ?'), ('BV2DDD', 'BV2CCC', 'BK'),
    ('BV2EEE', 'BV2AAA', '73'), ('BV2AAA', 'BV2EEE', '73 dit'),
    ('JA1ABC', 'BV2AAA', 'SOTA?'), ('BV2AAA', 'JA1ABC', 'OM'),
    ('BV2GGG', 'BV2HHH', 'WX OK?'), ('BV2HHH', 'BV2GGG', 'SUNNY 25C'),
  ];
  return List.generate(data.length, (i) {
    final m = data[i];
    return AprsMsg(m.$1, m.$2, m.$3,
        DateTime.now().subtract(Duration(minutes: 5 * i)),
        sent: m.$2 == 'BV2AAA');
  });
}
