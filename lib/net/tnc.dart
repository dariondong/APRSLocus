// TNC 传输层工厂（条件导入）
//   - Android / iOS：原生蓝牙 SPP（MethodChannel + EventChannel）
//   - Windows / Linux / macOS：串口（dart:io 直接读写设备节点）
//   - Web：占位（不支持）
import 'tnc_base.dart';
export 'tnc_base.dart';
import 'tnc_stub.dart'
    if (dart.library.io) 'tnc_io.dart'
    if (dart.library.html) 'tnc_web.dart' as impl;

TncTransport createTncTransport() => impl.createTncTransport();

/// PKWDWPL 链路（Kenwood 航点语句）的传输层工厂。
///
/// 与 TNC 共用字节搬运实现，但走**独立通道** → 原生侧独立实例、独立 socket，
/// 因此两条链路可以同时开着互不干扰。
TncTransport createPkwdwplTransport() => impl.createPkwdwplTransport();

/// APRSlocusBOX（APRS 小盒子）的传输层工厂。
///
/// 盒子的线上协议是**明文命令行**（`CFG k=v` / `POS …` / `BEACON`），既不是
/// KISS 也不是 NMEA —— 但字节搬运与 TNC/PKWDWPL 完全一样：蓝牙 SPP / USB-OTG
/// 串口 / 桌面串口。这里只多一条**独立通道**：原生 `TncManager` 一次只维护
/// 一个 socket，共用通道会让「管盒子」把正在工作的 TNC 顶掉。
TncTransport createBoxTransport() => impl.createBoxTransport();
