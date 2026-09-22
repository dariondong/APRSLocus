import 'dart:math' as math;

import 'models.dart';

/// ─── 位置处理（v1.6.147 起：**只服务「我自己的位置」**）───
///
/// 这份文件原来是「接收台站的位置质量层」：报文去重、位置时间戳判旧帧、速度门控、
/// 模糊位置的不确定圈、轨迹自适应抽稀、绘制平滑、推测定位（coasting）。
///
/// v1.6.147 按用户反馈**把接收侧那一整套全部撤掉**（原话：「不要给别人加防抖，浪费」）。
/// 理由是可量化的：那些判据里真正改善“别人的点准不准”的部分要付出绘制期的代价 ——
/// 轨迹平滑每次重绘都要重建整条列表、推测定位每秒对**每个可见台站**算三角函数、
/// 那一层还每秒强制重绘，而它叠在磨砂面板的离屏模糊上（面板一展开就每帧重算）。
/// 收台站回到「收到就更新、位移超过 20m 记一个点」的朴素行为即可。
///
/// 留下的是**自己**这一侧（每天看得见的东西）：
///   * [SelfFixFilter] —— 静止防抖（站着不动时标记不再原地哆嗦）
///   * [PosQuality.trackMinDistM] —— 自己轨迹的抽稀门限（按速度自适应）
///   * [fmtUncertaintyM] —— 精度/不确定半径的统一展示格式
///
/// 若将来想给接收侧重做质量层，请先回答「它能省下多少帧」再动手。
class PosQuality {
  PosQuality._();

  /// 自己轨迹的抽稀门限（米）：按一个采样周期内走过距离的 35% 取。
  ///
  /// 固定 20m 的问题：步行时点太稀（丢细节），高速时又太密（GPS 抖动
  /// 变成锯齿，还白占 maxTrackPts）。步行 → 下限 15m（低于 GPS 噪声没意义），
  /// 汽车 60km/h → ≈58m，飞机 → 上限 250m（这个尺度上逐点画没有意义）。
  static double trackMinDistM({double? speedKmh, double dtSec = 10}) {
    final v = (speedKmh ?? 0).clamp(0.0, 400.0);
    final dt = dtSec.clamp(1.0, 300.0);
    final travel = v * 1000 / 3600 * dt;
    return (travel * 0.35).clamp(15.0, 250.0);
  }
}

/// 不确定半径的展示格式：米 / 千米（≥10km 不再给小数 —— 这个尺度上小数是假精度）
///
/// 放在这里而不是各页面，是为了**只有一套格式化**：台站详情页、我的位置面板、
/// 地图标签都要用它，各写一份必然漂移（A 处改了 B 处忘）。
String fmtUncertaintyM(double m) {
  if (m >= 10000) return '${(m / 1000).round()} km';
  if (m >= 1000) return '${(m / 1000).toStringAsFixed(1)} km';
  return '${m.round()} m';
}

/// ─── 自己位置的防抖滤波器（A+B）───
///
/// 为什么需要：静止时 GPS 仍会飘 —— 精度 30m 的手机在 ±30m 内抖是常态。
/// 而自己的轨迹门限只看「位移 > 20m」，于是这些飘点全被当成新轨迹点（画出一小团
/// 毛线球），信标上报的坐标也跟着一起抖（aprs.fi 上看自己的点会原地哆嗦）。
///
/// 算法：**滑动窗口中位数 + 两半漂移判据 + 时间滞回 + 输出死区/限速**。
/// 参数不是拍脑袋的，是用 `tool/sim_selffix.py` 的场景仿真定的（脚本里可复现）：
///
/// | 场景 | 反向跳（稳态） | 跳变>20m | 输出游走总长 |
/// |---|---|---|---|
/// | 静止 σ30m | 106 → 10 | 206 → 10 | 11691m → 2311m |
/// | 静止 σ60m | — | 233 → 11 | 23382m → ~4000m |
/// | 静止 + 200m 单点漂移 | 108 → 11 | 207 → 10 | 12103m → 2358m |
/// | 步行 4.5km/h | 75 → 75 | 156 → 156 | 不变（**不加滞后**）|
/// | 开车 60km/h | 0 → 0 | 239 → 239 | 不变 |
///
/// 四个关键决定（每条都是先写错、被仿真打回来才改对的）：
///
/// ① **判据用「窗口前后两半的中位数之差」，不是「离当前点的最大距离」。**
///    后者是第一版：5 个 σ=30m 的噪声点离当前点最远常到 60~90m，于是
///    「进入静止」**永远不成立** —— 仿真里静止场景 `still=0%`，功能等于没上
///    （两条曲线一模一样）。两半中位数之差则对噪声不敏感（各半中位数各有
///    ≈0.7σ 误差），而对真实位移敏感（人一动两半立刻分开）。
///
/// ② **静止时取中位数，不是均值。** 均值会被一个漂出去很远的点拉偏，而
///    「漂出去很远」恰恰是 GPS 最常见的失效模式（隧道口、出地库、多路径反射）。
///    仿真里那个 200m 单点漂移，中位数完全不受影响（1/5 的离群点动不了中位数）。
///
/// ③ **两个方向都要时间滞回**：进入要连续 [enterNeed] 次成立；退出要连续
///    [exitNeed] 次不成立 —— 但速度达到 [moveSpeedKmh]（明显在动）**当帧退出**。
///    只做阈值滞回不做时间滞回的话，阈值边缘会反复切换，位置就会忽跳
///    （这正是「反复横跳」）。
///
/// ④ **输出死区 + 限速**：中位数没漂出 [deadbandM] 就**完全不动输出**（挡住
///    中位数自身的 ±10m 游走）；要动也每帧最多 [stillMaxStepM] 米。于是
///    「进静止」「出静止」都不出现突兀一跳。
///
/// 移动时**不做任何平滑**：移动中 GPS 本身准，平滑只会引入滞后（轨迹甩到弯道
/// 外侧）—— 仿真里步行/开车场景的输出与未滤波**逐帧完全相同**，就是这条的证明。
/// 这是「宁可不平滑，也不要让位置追不上车」的取舍。
///
/// 已知局限（如实写在这里，免得以后被当成 bug）：如果设备上报的**速度不可信**
/// （仿真里的 `edge` 场景：速度在 0~4km/h 之间乱跳），本滤波器基本不会生效
/// （still 只有 20%）。那种情况下至少不会变差 —— 输出与改动前一致。
class SelfFixFilter {
  /// 静止判定窗口（点数）：5 点 × 10 秒采样 ≈ 50 秒
  static const int window = 5;
  /// 进入静止需要的连续判定次数（滞回要严）
  static const int enterNeed = 3;
  /// 退出静止需要的连续判定次数（滞回的另一半）
  static const int exitNeed = 3;
  /// **明显在动**的速度（km/h）：达到它当帧退出静止，不等确认 ——
  /// 位置正确性优先，绝不粘住。
  static const double moveSpeedKmh = 5.0;
  /// 进入静止的速度上限（km/h）：GPS 速度来自多普勒，静止时实测 0~1
  static const double stillSpeedKmh = 1.5;
  /// 保持静止的速度上限（km/h）：比进入松一档，但**必须低于步行 4~5**。
  ///
  /// 第一版写的是 `2 × stillSpeedKmh` = 4，正好落在步行区间里：走路时也能
  /// 「保持静止」，输出变成 25 秒前的中位数 —— 人往前走、点被拖在后面，
  /// 直到漂移超限才跳出去，然后再被拖住 = **反复横跳**。
  /// 现在降到 2.5：于是「被粘住」时的滞后上限 = v × 窗口一半 ≈ 17m，
  /// 小于 APRS 本身的定位精度量级，可接受。
  static const double keepSpeedKmh = 2.5;
  /// 静止时的容忍下限（米）：精度再好也要允许 GPS 有几十米抖动
  static const double stillSlackM = 30.0;
  /// 进入静止：两半漂移 < 1.7 × 容忍
  static const double driftEnter = 1.7;
  /// 保持静止：两半漂移 < 3.0 × 容忍（比进入松，形成滞回）
  static const double driftKeep = 3.0;
  /// 精度差到这个程度就不写轨迹点（弱信号下的点会污染轨迹，且没信息量）
  static const double trackAccuracyLimitM = 100.0;
  /// 输出**死区**（米）：中位数没漂出这个距离就完全不动输出 ——
  /// 挡住中位数自身的 ±10m 游走（实测把稳态反向跳从 30 次降到 10 次）。
  static const double deadbandM = 12.0;
  /// 静止状态下**每帧输出最多挪多少米**：防止从原始点直接跳到中位数时「跳一下」
  static const double stillMaxStepM = 15.0;

  final List<(double, double)> _win = [];
  int _stillRun = 0;
  int _exitRun = 0;
  bool _still = false;
  (double, double)? _lastOut;

  /// 当前是否判定为静止（界面可用来显示「静止」）
  bool get still => _still;

  /// 喂入一个实时定位点，返回 `(输出纬度, 输出经度, 是否静止)`。
  ///
  /// [accuracyM] <= 0 表示平台没给精度，按 [stillSlackM] 处理。
  /// **缓存位置（lastKnown）与 IP 定位不得喂进来** —— 它们不是实时定位，
  /// 会把窗口污染（调用方负责，见 `AppState._onFix`）。
  /// [sensorMoving]：加速度计判断「设备真的在动」。**只用来提前退出静止** ——
  /// 传感器说在动就立刻按移动输出原始点，绝不因为 GPS 速度偶尔为 0 而把
  /// 人粘在旧位置上；反过来（传感器没信号/说静止）**不**阻止进入静止判定，
  /// 免得一个坏传感器把防抖整个废掉。
  (double, double, bool) feed(
    double lat,
    double lng,
    double speedKmh,
    double accuracyM, {
    bool? sensorMoving,
  }) {
    final acc = accuracyM > 0 ? accuracyM : stillSlackM;
    _win.add((lat, lng));
    if (_win.length > window) _win.removeAt(0);
    final tol = math.max(acc, stillSlackM);

    final full = _win.length >= window;
    final drift = full ? _driftM() : double.infinity;
    final enterOk = drift < tol * driftEnter && speedKmh < stillSpeedKmh;
    final keepOk = drift < tol * driftKeep && speedKmh < keepSpeedKmh;

    if (_still) {
      // 明显在动 → 当帧退出；否则要连续 exitNeed 次不成立才退出（挡阈值边缘的抖）。
      // 注意**退出时不清空窗口**：清空后要 5 帧才重填，那 5 帧只能输出原始噪声
      // —— 仿真里那就是残留反向跳的主要来源（清空时稳态 30 次，不清空后 10 次）。
      //
      // 加速度计说在动也当帧退出：GPS 速度在多路径/隧道口会短时为 0，
      // 而「设备在动」这个事实比 GPS 速度可靠。
      if (speedKmh >= moveSpeedKmh || sensorMoving == true) {
        _still = false;
        _stillRun = 0;
        _exitRun = 0;
      } else if (!keepOk) {
        _exitRun++;
        if (_exitRun >= exitNeed) {
          _still = false;
          _stillRun = 0;
          _exitRun = 0;
        }
      } else {
        _exitRun = 0;
      }
    } else {
      _exitRun = 0;
      if (enterOk) {
        _stillRun++;
        if (_stillRun >= enterNeed) _still = true;
      } else {
        _stillRun = 0;
      }
    }

    // 非静止：输出原始点，并记下它 —— 下次进静止时从它开始逐步靠向中位数
    if (!_still) {
      _lastOut = (lat, lng);
      return (lat, lng, false);
    }

    final mLat = _median(_win.map((p) => p.$1).toList());
    final mLng = _median(_win.map((p) => p.$2).toList());
    final prev = _lastOut;
    if (prev == null) {
      _lastOut = (mLat, mLng);
      return (mLat, mLng, true);
    }
    final dM = haversine(prev.$1, prev.$2, mLat, mLng) * 1000;
    // 死区：宁可不动，也别跟着噪声挪
    if (dM <= deadbandM) return (prev.$1, prev.$2, true);
    if (dM <= stillMaxStepM) {
      _lastOut = (mLat, mLng);
      return (mLat, mLng, true);
    }
    final t = stillMaxStepM / dM;
    final oLat = prev.$1 + (mLat - prev.$1) * t;
    final oLng = prev.$2 + (mLng - prev.$2) * t;
    _lastOut = (oLat, oLng);
    return (oLat, oLng, true);
  }

  /// 窗口「漂移量」：前一半与后一半各自的中位数之间的距离（米）。
  /// 见类注释 ① —— 这个统计量才分得开「噪声」与「真的在动」。
  double _driftM() {
    final h = _win.length ~/ 2;
    if (h == 0) return 0;
    final a = _win.sublist(0, h);
    final b = _win.sublist(_win.length - h);
    return haversine(
          _median(a.map((p) => p.$1).toList()),
          _median(a.map((p) => p.$2).toList()),
          _median(b.map((p) => p.$1).toList()),
          _median(b.map((p) => p.$2).toList()),
        ) *
        1000;
  }

  static double _median(List<double> v) {
    v.sort();
    final n = v.length;
    if (n == 0) return 0;
    return n.isOdd ? v[n ~/ 2] : (v[n ~/ 2 - 1] + v[n ~/ 2]) / 2;
  }

  void reset() {
    _win.clear();
    _stillRun = 0;
    _exitRun = 0;
    _still = false;
    _lastOut = null;
  }
}
