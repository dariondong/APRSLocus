import 'package:flutter/material.dart';

import 'state.dart';
import 'theme.dart';
import 'widgets.dart';

/// ─── 「我的位置」面板 ───
///
/// 用途：1.0 的侧栏底部、2.0 横屏的竖条底部，**共用同一份**。
///
/// 为什么提取而不是各写一份：2.0 横屏重做时横屏竖条也要这块面板，而「复制一份」
/// 的代价本项目刚付过一次 —— 同一个 APRS 包在「手动注入」里显示「未知」、
/// 在真机上显示「消息」，就是这么来的（v1.6.175）。布局复制更隐蔽：
/// 两边会慢慢长出不同的字段与文案，最后没人知道哪个是对的。
///
/// 自刷新：面板里的倒计时/速率是秒级的，走 [AppState.tick]；
/// 连接、定位这类真实状态变化由外层重建覆盖（与 1.0 侧栏同一个口径）。
class MyPanel extends StatelessWidget {
  final AppState state;
  const MyPanel({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: state.tick,
      builder: (context, _, _) => _body(context),
    );
  }

  Widget _body(BuildContext context) {
    final fix = state.myHasFix;
    final locColor = fix
        ? C.green
        : state.loc.running
        ? C.blue
        : C.yellow;
    final connColor = state.connected
        ? C.green
        : state.connecting
        ? C.blue
        : C.slate;
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: C.bgSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // 我的电台
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: C.blueBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.my_location_rounded, color: C.blue, size: 20),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.myCall,
                      style: ts(13, w: FontWeight.w700),
                    ),
                    Text(state.myPosStr, style: ts(9, c: C.grey)),
                  ],
                ),
              ),
              if (fix) Icon(Icons.gps_fixed_rounded, color: C.green, size: 18),
            ],
          ),
          SizedBox(height: 8),
          // 网格 + 速率
          // 两端的文案都是「按当前状态拼出来的」：网格值与速率数字一变长
          // （例如速率到 4 位数），不限制宽度就会把这一段撑出横幅外。
          Row(
            children: [
              Icon(Icons.grid_4x4_rounded, size: 12, color: C.grey),
              SizedBox(width: 4),
              Flexible(
                child: Text(
                  S.of(context).gridValue(state.myGrid),
                  style: ts(10, c: C.slate),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Spacer(),
              Icon(Icons.speed_rounded, size: 12, color: C.grey),
              SizedBox(width: 4),
              Flexible(
                child: Text(
                  S.of(context).packetsPerMinute(state.packetsPerMin),
                  style: ts(10, c: C.slate),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          // 状态行
          Row(
            children: [
              _dot(locColor),
              SizedBox(width: 6),
              Text(
                localizedLocationStatus(context, state.locStatus),
                style: ts(11, c: locColor, w: FontWeight.w600),
              ),
              Spacer(),
              _dot(connColor),
              SizedBox(width: 6),
              Text(
                state.connected
                    ? S.of(context).connected
                    : S.of(context).demo,
                style: ts(
                  11,
                  c: state.connected ? C.green : C.slate,
                  w: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.timer_rounded, size: 12, color: C.grey),
              SizedBox(width: 4),
              // 注意：AppState.nextBeaconIn 已经本地化（内部按 locale 取 l10n），
              // 不要再包一层 localizedNextBeaconValue —— 那个助手是按「中文
              // 状态串」做映射的旧模式，传入已本地化文案会匹配不上。
              Text(
                // 射频未开信标 / 当前是**粗定位（网络）**时给出原因，而不是显示
                // 一个不会生效的倒计时 —— 判据用结构化的 beaconPhase（与
                // AppState.canAutoBeacon 同源，两处漂移就是「倒计时走着不发」）。
                switch (state.beaconPhase) {
                  BeaconPhase.rfDisabled => S.of(context).beaconRfBeaconOff,
                  BeaconPhase.coarseFix => S.of(context).beaconCoarseFix,
                  // 强制接受网络定位时它**会发射**，所以不再是「不报」而是
                  // 「报的是网络定位」—— 这一档也不能退回普通倒计时。
                  BeaconPhase.coarseForced =>
                    S.of(context).beaconCoarseForcedNote,
                  _ => S.of(context).nextBeaconIn(state.nextBeaconIn),
                },
                style: ts(10,
                    c: (state.beaconNeedsRfEnable ||
                            state.beaconPhase == BeaconPhase.coarseFix ||
                            state.beaconPhase == BeaconPhase.coarseForced)
                        ? C.orange
                        : C.slate),
              ),
              Spacer(),
              Icon(Icons.sync_rounded, size: 12, color: C.grey),
              SizedBox(width: 4),
              Text(
                S.of(context).beaconCount(state.beaconsSent),
                style: ts(10, c: C.slate),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 位置上报状态行：连接后可见。
          //
          // 这里用 [AppState.txSourceUp] 而不是 `connected`：只读模式（只开
          // PKWDWPL）下没有发射链路，但仍要让用户看到「正在收航点」——
          // 否则主页会把一个正在正常工作的应用显示成完全没连上。
          if (state.txSourceUp || state.pkwdwplOn) ...[
            // 只读模式（只启用 PKWDWPL）：位置上报那套开关对它没有任何意义，
            // 所以换行「只读接收」+ 已收航点数，而不是摆一个按了不会发射的
            // 「开启自动上报」。
            if (!state.txSourceUp)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: C.orangeBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.download_rounded, size: 13, color: C.orange),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        S.of(context).pkwdwplReadOnly,
                        style: ts(10, c: C.orange, w: FontWeight.w600),
                      ),
                    ),
                    Text(
                      S.of(context)
                          .beaconCount(state.pkwdwpl.rxFrames),
                      style: ts(10, c: C.slate, w: FontWeight.w600),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: state.beaconEnabled ? C.greenBg : C.greyBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      state.beaconEnabled
                          ? Icons.send_rounded
                          : Icons.notifications_off_rounded,
                      size: 13,
                      color: state.beaconEnabled ? C.green : C.grey,
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        state.beaconEnabled
                            ? (state.smartBeaconEnabled
                                ? '自动上报中 · 智能分档(每 ${state.beaconIntervalNow}s)'
                                : '自动上报中 · 每 ${state.beaconInterval}s')
                            : '位置未上报 · 仅接收',
                        style: ts(
                          10.5,
                          c: state.beaconEnabled ? C.green : C.slate,
                          w: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (!state.beaconEnabled)
                      GestureDetector(
                        onTap: () {
                          state.setBeaconEnabled(true);
                          if (state.myHasFix) {
                            state.sendBeacon();
                          }
                        },
                        child: Text(
                          '开启自动上报',
                          style: ts(10, c: C.blue, w: FontWeight.w700),
                        ),
                      ),
                  ],
                ),
              ),
            SizedBox(height: 10),
          ],
          // 操作按钮
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  // 只读模式（只启用 PKWDWPL）下没有发射链路，按钮**置灰**
                  // 并在文案里说明原因。不隐藏它：位置突然少一个按钮会让人
                  // 找不到，而置灰 + 说明反而能直接回答「为什么发不出去」。
                  onPressed: state.readOnlyMode
                      ? null
                      : () {
                          if (state.myHasFix) {
                            state.sendBeacon();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  state.connected
                                      ? S
                                            .of(context)
                                            .beaconSentAprsIs(
                                                state.myGrid)
                                      : S
                                            .of(context)
                                            .beaconSentDemo(
                                                state.myGrid),
                                ),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          } else {
                            state.startTracking();
                          }
                        },
                  icon: Icon(
                    state.myHasFix
                        ? Icons.send_rounded
                        : Icons.my_location_rounded,
                    size: 18,
                  ),
                  label: Text(
                    state.readOnlyMode
                        ? S.of(context).pkwdwplRxOnly
                        : (state.myHasFix
                            ? S.of(context).beaconNow
                            : S.of(context).getLocation),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: state.readOnlyMode
                        ? C.grey
                        : (state.myHasFix ? C.green : C.blue),
                    side: BorderSide(
                      color: (state.readOnlyMode
                              ? C.greyLight
                              : (state.myHasFix ? C.green : C.blue))
                          .withValues(alpha: 0.5),
                    ),
                    // 手动上报是主页最高频的动作，给足触摸目标
                    // （44 高 ≈ Material 的最小可点区域，原 8 内边距只有 34）
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    textStyle: ts(13, w: FontWeight.w700),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: state.toggleConnect,
                  icon: Icon(
                    state.connected
                        ? Icons.stop_circle_outlined
                        : Icons.wifi_rounded,
                    size: 15,
                  ),
                  label: Text(
                    state.connected
                        ? S.of(context).disconnect
                        : state.connecting
                        ? S.of(context).connecting
                        : state.usingAudio
                        ? S.of(context).audioCaptureStart
                        : state.usingTnc
                        ? S.of(context).tncConnectAction
                        : S.of(context).connectAprsIs,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: state.connected ? C.red : C.blue,
                    side: BorderSide(
                      color: (state.connected ? C.red : C.blue)
                          .withValues(alpha: 0.5),
                    ),
                    // 与「手动上报」对齐：两个按钮并排，一大一小会显得很怪
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    textStyle: ts(13, w: FontWeight.w700),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dot(Color c) => Container(
    width: 7,
    height: 7,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: c,
      boxShadow: [BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 4)],
    ),
  );
}
