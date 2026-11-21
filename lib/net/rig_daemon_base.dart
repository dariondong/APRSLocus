/// 在本机起停 hamlib 的 `rigctld`（平台无关部分）。
///
/// 为什么要有这一层：`rigctld` 是 hamlib 自己的常驻进程，我们跟它说 TCP 上的
/// 文本协议（见 `rig_link_io.dart`）。以前用户得自己在终端里起一份，Windows
/// 上还得先找 hamlib 的 w64 包；现在安装包带了一份（<安装目录>\hamlib\），
/// 这一层负责找到它、按型号与串口起起来、用完停掉。
///
/// Linux / macOS 的安装包里没有 hamlib 的官方二进制，所以那边退回系统的
/// `rigctld`（`brew install hamlib` / `apt install hamlib-utils`），找不到就
/// 如实说一句「没找到」，不假装能连。
library;

/// 起一份 rigctld 的参数。
class RigDaemonConfig {
  /// `-m`：hamlib 的型号编号。写法是「后端号 × 1000 + 型号号」
  /// （`include/hamlib/riglist.h` 的 `RIG_MAKE_MODEL`）：IC-705 = 3085、
  /// IC-7300 = 3073、FT-891 = 1036；1 是虚拟电台（没有真机也能试协议）。
  final int model;

  /// `-r`：串口。Windows 写 `COM3` 这种，Linux / macOS 写 `/dev/ttyUSB0`。
  /// 型号 1（虚拟电台）可以空着。
  final String device;

  /// `-s`：波特率。0 = 不指定，交给 hamlib 自己的默认值。
  final int baud;

  /// `-t`：监听端口。
  final int port;

  /// `-T`：监听地址。只给本机用，所以固定回环。
  final String host;

  const RigDaemonConfig({
    required this.model,
    this.device = '',
    this.baud = 0,
    required this.port,
    this.host = '127.0.0.1',
  });
}

/// 拼 `rigctld` 的命令行。
///
/// 单独抽成纯函数，是因为测试不该去起一个真进程：参数对不对，比对字符串就够。
List<String> rigctldArgs(RigDaemonConfig c) {
  final args = <String>['-m', '${c.model}'];
  final dev = c.device.trim();
  if (dev.isNotEmpty) args.addAll(['-r', dev]);
  if (c.baud > 0) args.addAll(['-s', '${c.baud}']);
  args.addAll(['-t', '${c.port}', '-T', c.host]);
  return args;
}

/// 起不来的原因。界面按这个换成一句人话，不直接铺英文原话。
enum RigDaemonError {
  /// 还没试过，或者上次是成功的。
  none,

  /// 这个平台根本起不了子进程（Web）。
  unsupported,

  /// 找不到 rigctld：安装包里没有、系统也没装。
  noBinary,

  /// 型号编号没填。
  noModel,

  /// 端口已经被别的进程占了（常见：上一次的 rigctld 还在跑）。
  inUse,

  /// rigctld 起来了又退出（型号不认识、串口被占、串口不存在都走这条）。
  exited,

  /// 进程还在，但端口一直连不上。
  timeout,

  /// 进程根本没起来。
  startFailed,
}

/// 本机 rigctld 的起停接口。
abstract class RigDaemon {
  /// 这个平台能不能起子进程。
  bool get supported;

  /// 现在是不是有一份 rigctld 由我们管着。
  bool get running;

  /// 找到的 rigctld 全路径，空串 = 没找到。
  String get exe;

  /// 上一次失败的原因。
  RigDaemonError get error;

  /// rigctld 自己吐出来的最后几行（诊断用，可能是空串）。
  String get log;

  /// 找 rigctld：先看安装包自带那份，再看系统 PATH。
  Future<String> locate();

  /// 起一份。返回 true 只代表「端口能连上」，不代表电台那边通了。
  Future<bool> start(RigDaemonConfig cfg);

  /// 停掉。停机失败也当停掉了：我们要的是不再占着串口。
  Future<void> stop();
}
