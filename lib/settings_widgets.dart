import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme.dart';
import 'entrance.dart';
import 'widgets.dart';
import 'state.dart';
import 'material.dart';
import 'guide.dart';
import 'theme_store.dart';
import 'net/icom_lan_settings.dart';

/// Icom WLAN 相关的文案助手。
///
/// 这几项的共同点：**字符串的真源在别处**（型号枚举、net 层写死的中文阶段），
/// 界面拿到的是「中文基准值」，而 l10n 键是另一套。判据放在这里，供
/// `ic705_device_page` / `settings_pages` / `device_page` 三处共用，避免各写一份
/// switch 而漏掉某个型号 / 阶段。

/// 型号预置的本地化显示名。[WlanRadioModel.nameKey] 返回 null 表示沿用
/// `displayName`（IC-705 等官方型号名跨语言一致），否则取本地化名（自定义项）。
String icomModelName(S s, WlanRadioModel m) =>
    m.nameKey == null ? m.displayName : s.modelCustomName;

/// 型号选择按钮上的短标签：官方型号用 `id`（IC-705 这种数字型号本就是
/// 国际通用写法），自定义项用本地化名，避免出现中英混排的 `custom`。
String icomModelTab(S s, WlanRadioModel m) =>
    m.nameKey == null ? m.id : s.modelCustomName;

/// 型号预置的本地化描述。用 [WlanRadioModel.descKey] 精确映射到 l10n 键。
String icomModelDesc(S s, WlanRadioModel m) => switch (m.descKey) {
      'modelIc705Desc' => s.modelIc705Desc,
      'modelIc9700Desc' => s.modelIc9700Desc,
      'modelIc7610Desc' => s.modelIc7610Desc,
      'modelIc905Desc' => s.modelIc905Desc,
      _ => s.modelCustomDesc,
    };

/// 把 Icom LAN 链路的 `phaseLabel`（中文，来自 `net/icom_lan_io.dart`）翻成当前语言。
///
/// 阶段文案在 net 层是写死的中文（它会经 `onStatus` 进日志），这里按阶段字符串
/// 精确匹配回本地化键；认不出就原样返回（未来新增阶段不会因此变成空白）。
/// 与 `iconForPhase` / `_phaseColor` 那套字符串匹配是同一约定。
///
/// ⚠ 判颜色时要用**原始**中文阶段（`_phaseColor` 按中文关键字匹配），别拿翻好的
/// 文案去判 —— 换成日语 / 西语后会全部落回灰色。
String icomPhaseLabel(S s, String raw) {
  switch (raw) {
    case '未连接':
      return s.disconnected;
    case '正在打开端口…':
      return s.icomPhaseOpeningSockets;
    case '正在发现电台…':
      return s.icomPhaseDiscovering;
    case '正在登录电台…':
      return s.icomPhaseAuthenticating;
    case '正在协商音频流…':
      return s.icomPhaseNegotiating;
    case '正在打开数据流…':
      return s.icomPhaseOpeningStreams;
    case '已连接（等待音频）':
      return s.icomPhaseReady;
    case '已连接（接收中）':
      return s.icomPhaseReceiving;
    case '连接中断，正在重连…':
      return s.icomPhaseReconnect;
    case '连接失败':
      return s.icomPhaseFailed;
    case '当前平台不支持 IC-705 局域网直连':
      return s.icomPhaseUnsupported;
    default:
      return raw;
  }
}

/// 设置子页面外壳：标题 + 返回 + 可滚动内容
class SettingsPageShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Widget body;
  /// **只服务于本页的引导卡**（见 build 里的 GuideTipCard）。
  ///
  /// ⚠ 它**不会**让本页跟着 state 实时刷新 —— 这里曾经写着「传入后自动监听刷新」，
  /// 于是新页面（生命守护）照字面理解只传了 state、没自己包 ListenableBuilder，
  /// 开关点了界面纹丝不动（issue #24）。要实时刷新请自己包：
  /// `ListenableBuilder(listenable: state, builder: ...)`。
  final AppState? state;

  /// 本页的功能引导 id（见 lib/guide.dart）。给上它，顶栏会出现「重看引导」按钮，
  /// 首次进入时正文顶部会多一张小提示卡。
  final String? guideId;
  const SettingsPageShell({
    super.key,
    required this.title,
    this.subtitle = '',
    required this.icon,
    required this.color,
    required this.body,
    this.state,
    this.guideId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.pageFill,
      appBar: MaterialAppBar(
        AppBar(
          backgroundColor: C.surfaceFillStrong,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: C.slate),
            onPressed: () => Navigator.of(context).pop(),
          ),
          // 「重看本页引导」：提示卡关掉之后，用户临时想再看一眼时不必去设置里重置
          actions: [
            if (guideId != null) GuideHelpButton(guideId: guideId!),
          ],
          title: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              SizedBox(width: 10),
              Text(title, style: ts(16, w: FontWeight.w700)),
            ],
          ),
          bottom: subtitle.isEmpty
              ? null
              : PreferredSize(
                  preferredSize: const Size.fromHeight(32),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Row(
                      children: [
                        Container(
                          width: 3,
                          height: 12,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            subtitle,
                            style: ts(11, c: C.grey),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
      body: SingleChildScrollView(
        // 底部额外让出系统导航栏的高度（三大金刚键 / 手势条）：
        // Android 15（targetSdk 35+）起强制 edge-to-edge，窗口不再自动
        // 让出导航栏占位，页面最底下那个按钮（如「保存并应用过滤」）会
        // 被导航栏压住、点不到 —— 用户报的正是这个（issue #12）。
        // 非 edge-to-edge（旧系统）下 viewPadding.bottom 本来就是 0，
        // 所以加上它不会重复留白。
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.of(context).viewPadding.bottom,
        ),
        child: StaggerColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (guideId != null && state != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GuideTipCard(
                  guideId: guideId!,
                  state: state!,
                  margin: EdgeInsets.zero,
                ),
              ),
            body,
          ],
        ),
      ),
    );
  }
}

/// 设置输入行
class SettingsInput extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onEditingComplete;
  final FocusNode? focusNode;
  final String? tip;

  /// 标签右侧的小徽标（例：「未验证」/「未配置」）。
  ///
  /// 与 Passcode 那一行的「未验证」一样：这一项没填会让**整条链路连不上**，
  /// 而输入框本身是看不出这件事的（空框和"还没轮到我填"长得一样）。
  final String? badge;

  /// 为空时显示的占位提示。默认用通用的「点击输入」。
  ///
  /// ── 为什么要加这个参数（用户反馈）──
  ///
  /// 原来的输入框是 `border: none`、无背景、**无占位符**，而几个自由文本字段
  /// （最典型的是「台站备注」）默认就是空的 —— 于是那一行右边**整片空白**，
  /// 和旁边的静态「标签 + 值」行长得一模一样。用户的反馈原话是
  /// 「台站备注，用户都不知道那里是可以输入的」。
  ///
  /// 所以这一版做三件事，让「这里能输入」变成看得见的事实：
  ///   1. 空值显示占位提示（默认「点击输入」，个别字段可以给更具体的）；
  ///   2. 输入区给一层浅底 + 圆角 —— 有「框」才像输入框；
  ///   3. 聚焦时描边变主题蓝，进一步确认「点这里就是在编辑」。
  final String? hint;

  /// 输入框右端的小控件（例：「最近用过的」历史按钮，见 lib/input_history.dart）。
  ///
  /// 做成一个 Widget 而不是几个回调参数：这一行只负责**摆**它，点开、删除、
  /// 历史从哪来都归调用方。设置里将来别的输入框要用同一个按钮，换一个实例即可。
  final Widget? trailing;

  const SettingsInput(this.label, this.controller,
      {super.key,
      this.onChanged,
      this.onEditingComplete,
      this.focusNode,
      this.tip,
      this.hint,
      this.badge,
      this.trailing});

  @override
  Widget build(BuildContext context) {
    final row = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: C.border, width: 0.4))),
      child: Row(children: [
        Flexible(
          child: Row(children: [
            Flexible(
              child: Text(label,
                  style: ts(12, c: C.slate), overflow: TextOverflow.ellipsis),
            ),
            if (tip != null) ...[
              SizedBox(width: 4),
              Tooltip(
                message: tip,
                child: Icon(Icons.help_outline_rounded,
                    size: 14, color: C.greyLight),
              ),
            ],
            if (badge != null) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: C.orangeBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(badge!,
                    style: ts(9, c: C.orange, w: FontWeight.w700)),
              ),
            ],
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            onChanged: onChanged,
            onEditingComplete: onEditingComplete,
            textInputAction: TextInputAction.done,
            textAlign: TextAlign.right,
            style: ts(13, w: FontWeight.w600),
            decoration: InputDecoration(
              isDense: true,
              // 内边距要对上外面那层浅底的圆角，否则光标贴边
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              // 空值时显示提示：这一行就再也不是「一片空白」了
              hintText: hint ?? S.of(context).inputTapHint,
              hintStyle: ts(12, c: C.greyLight, w: FontWeight.w400),
              // 有底 + 圆角 + 一圈淡描边：一眼能认出是输入区（静止态不抢眼）
              filled: true,
              fillColor: C.bgSoft,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: C.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: C.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: C.blue, width: 1.4),
              ),
              suffixIconConstraints:
                  const BoxConstraints(minWidth: 0, minHeight: 0),
              suffixIcon: trailing == null
                  ? null
                  : Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: trailing,
                    ),
            ),
          ),
        ),
      ]),
    );
    return tip != null ? Tooltip(message: tip!, child: row) : row;
  }
}

/// 设置下拉选择行：左标签 + 右侧下拉菜单。
///
/// 用于「值来自一组固定选项」的设置，且选项不适合/不需要平铺成一排按钮时 ——
/// 尤其当当前值可能落在一长串数字里（例如「清理多少天前的台站」）。与
/// [SettingsInput] 同款左标签右控件布局，视觉一致。
class SettingsChoice<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<T> options;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;
  final String? tip;

  const SettingsChoice(this.label,
      {super.key,
      required this.value,
      required this.options,
      required this.labelOf,
      required this.onChanged,
      this.tip});

  @override
  Widget build(BuildContext context) {
    final row = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: C.border, width: 0.4))),
      child: Row(children: [
        Flexible(
          child: Row(children: [
            Flexible(
              child: Text(label,
                  style: ts(12, c: C.slate), overflow: TextOverflow.ellipsis),
            ),
            if (tip != null) ...[
              const SizedBox(width: 4),
              Tooltip(
                message: tip,
                child: Icon(Icons.help_outline_rounded,
                    size: 14, color: C.greyLight),
              ),
            ],
          ]),
        ),
        const Spacer(),
        DropdownButton<T>(
          value: value,
          underline: const SizedBox.shrink(),
          borderRadius: BorderRadius.circular(12),
          isDense: true,
          style: ts(13, w: FontWeight.w600, c: C.blue),
          icon: Icon(Icons.expand_more_rounded, size: 18, color: C.blue),
          items: [
            for (final o in options)
              DropdownMenuItem<T>(
                value: o,
                child: Text(labelOf(o), style: ts(13, w: FontWeight.w600)),
              ),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ]),
    );
    return tip != null ? Tooltip(message: tip!, child: row) : row;
  }
}

/// 设置开关行
class SettingsSwitch extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color? color;

  /// 本平台是否支持该选项。为 false 时置灰并禁用开关（配合下方
  /// [SettingsHint] 说明原因），而不是让用户点一个没反应的开关。
  final bool enabled;

  const SettingsSwitch(this.label,
      {super.key,
      required this.value,
      required this.onChanged,
      this.color,
      this.enabled = true});

  @override
  Widget build(BuildContext context) {
    final c = color ?? C.blue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: C.border, width: 0.4))),
      // 标签走 Expanded + 省略号：标签也是 l10n 文案，德语/印尼语会明显更长，
      // 而右侧的 Switch 是固定宽 —— 不约束标签就会把开关挤出屏幕。
      child: Row(children: [
        Expanded(
          child: Text(
            label,
            style: ts(12, c: enabled ? C.slate : C.greyLight),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Switch(
          value: value,
          onChanged: enabled ? onChanged : null,
          activeThumbColor: c,
          activeTrackColor: c.withValues(alpha: 0.25),
          inactiveThumbColor: C.grey,
          inactiveTrackColor: C.greyBg,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ]),
    );
  }
}

/// 紧凑开关（信标内容等）
class SettingsMiniSwitch extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const SettingsMiniSwitch(this.label,
      {super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: Text(
          label,
          style: ts(11, c: C.slate),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      const SizedBox(width: 8),
      Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: C.green,
        activeTrackColor: C.green.withValues(alpha: 0.25),
        inactiveThumbColor: C.grey,
        inactiveTrackColor: C.greyBg,
      ),
    ]);
  }
}

/// 设置只读行
///
/// 用 [LabelValueRow] 而不是 `Text + Spacer + Text`：后者的两端都是**自然宽**，
/// 一旦值是长的用户数据（设备名如 `Serial /dev/ttyUSB0 @38400`、蓝牙 MAC、
/// 呼号、`host:port`）就整行溢出（黄黑斜纹）—— 这正是「设备名称会溢出」的原因。
class SettingsRow2 extends StatelessWidget {
  final String label, value;
  final Color? valueColor;
  const SettingsRow2(this.label, this.value, {super.key, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: C.border, width: 0.4))),
      child: LabelValueRow(
        label,
        value,
        labelStyle: ts(12, c: C.slate),
        valueStyle: ts(13, w: FontWeight.w600, c: valueColor),
      ),
    );
  }
}

/// 「用这条链路发送」单选行。
///
/// 两条互联网链路各一张卡，这一行让每张卡都能把发送切到自己：
/// 勾选就是这条链路发，不勾就是别人发。没连上的链路照样可以先选好，
/// 连上就按这个发出 —— 与射频链路那张卡的圆点同一套语义。
class SettingsTxPick extends StatelessWidget {
  final String label;
  final bool checked;
  final bool enabled;
  final VoidCallback onTap;

  /// 行首图标：一眼分出这一行是位置/状态还是消息。
  final IconData? icon;

  /// 多选：位置与状态报文可以选好几条链路（同时发）；消息只能选一条。
  final bool multi;
  const SettingsTxPick(
    this.label, {
    super.key,
    required this.checked,
    required this.onTap,
    this.enabled = true,
    this.icon,
    this.multi = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled && (!checked || multi) ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: C.border, width: 0.4))),
        child: Row(children: [
          Icon(
            multi
                ? (checked
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded)
                : (checked
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded),
            size: 18,
            color: !enabled ? C.greyLight : (checked ? C.orange : C.grey),
          ),
          if (icon != null) ...[
            const SizedBox(width: 8),
            Icon(icon,
                size: 14,
                color: !enabled ? C.greyLight : (checked ? C.orange : C.grey)),
          ],
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: ts(12, c: enabled ? C.slate : C.greyLight),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (checked)
            Text(S.of(context).dataSourceTxBadge,
                style: ts(10, c: C.orange, w: FontWeight.w700)),
        ]),
      ),
    );
  }
}

/// 可点击的设置行（进入子页面）
/// 与 [SettingsRow2] 的区别：这里带图标与副标题、且整行可点，
/// 用于「离线地图」这类需要交代清楚「点进去能干什么」的入口 ——
/// 只写一个名词的入口，用户得点进去才知道里面是什么。
class SettingsNavRow extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final String? trailing;
  final VoidCallback onTap;
  const SettingsNavRow({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.color,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: C.border, width: 0.4))),
        child: Row(children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: ts(12, c: C.slate, w: FontWeight.w600)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!,
                      style: ts(10, c: C.grey, h: 1.35),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            Text(trailing!, style: ts(11, c: C.grey)),
          ],
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, size: 18, color: C.greyLight),
        ]),
      ),
    );
  }
}

/// 一级页上的链路入口（一条链路 / 一台服务器一行）。
///
/// 与 [SettingsNavRow] 的区别：这一行自带开关与发射圆点，本身就能开关这条链路、
/// 指定由它来发，字与图标底座也更大 —— 用户在「设置 → 服务器」一级把它读作
/// 「一台服务器」，在设备页把它读作「一条链路」，而不是一条设置项。
///
/// 三段文字各说一件事：名称、状态行（通不通 + 地址，空字符串就整行不画）、
/// 副标题（这条链路是什么 / 在哪儿配置）。平台不支持时 [enabled] 为 false：
/// 开关换成一把锁，副标题把原因写出来。
class SettingsLinkEntry extends StatelessWidget {
  final String title;
  final String subtitle;

  /// 状态行：通不通 + 地址。空字符串表示这一行不需要状态（例如平台不支持）。
  final String status;
  final bool up;
  final bool on;
  final ValueChanged<bool> onToggle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  /// 平台不支持：整行置灰、开关换成锁，点不进去
  final bool enabled;

  /// 发射圆点：非 null 才画。两类报文各一颗，值表示「现在是不是它发」。
  ///
  /// 位置与状态报文（[txPos]）和消息（[txMsg]）分开选：常见用法是位置走
  /// 射频、消息走网络。两条选同一条也允许。
  final bool? txPos;
  final bool? txMsg;
  final VoidCallback? onTxPos;
  final VoidCallback? onTxMsg;

  const SettingsLinkEntry({
    super.key,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.up,
    required this.on,
    required this.onToggle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.enabled = true,
    this.txPos,
    this.txMsg,
    this.onTxPos,
    this.onTxMsg,
  });

  /// 一颗发射圆点：点一下让这条链路负责这一类报文。
  ///
  /// 圆点分不出两类报文，所以在前面加一个 12 px 的图形（位置 / 消息），
  /// 与链路自己那一页上那两行的图标是同一个；完整说法在 tooltip 里。
  Widget _txDot(IconData glyph, bool on, VoidCallback? onTap, String tip,
      {bool boxed = false}) {
    return Tooltip(
      message: tip,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(glyph, size: 12, color: on ? C.orange : C.greyLight),
            const SizedBox(width: 3),
            Icon(
              boxed
                  ? (on
                      ? Icons.check_box_rounded
                      : Icons.check_box_outline_blank_rounded)
                  : (on
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded),
              size: 16,
              color: on ? C.orange : C.greyLight,
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: C.border, width: 0.4))),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: !enabled ? 0.05 : (on ? 0.14 : 0.06)),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon,
                size: 20,
                color: !enabled ? C.greyLight : (on ? color : C.grey)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: ts(13,
                        c: !enabled
                            ? C.greyLight
                            : (on ? C.slate : C.grey),
                        w: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if (status.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: up ? C.green : C.greyLight,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(status,
                          style: ts(10.5, c: up ? C.green : C.grey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ]),
                ],
                const SizedBox(height: 2),
                Text(subtitle,
                    style: ts(10, c: enabled ? C.greyLight : C.orange),
                    maxLines: enabled ? 1 : 2,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (txPos != null || txMsg != null) ...[
            const SizedBox(width: 6),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (txPos != null)
                  _txDot(Icons.my_location_rounded, txPos!, onTxPos,
                      S.of(context).txKindPosition,
                      boxed: true),
                if (txMsg != null)
                  _txDot(Icons.forum_rounded, txMsg!, onTxMsg,
                      S.of(context).messages),
              ],
            ),
          ],
          const SizedBox(width: 6),
          if (!enabled)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Icon(Icons.lock_outline, size: 16, color: C.greyLight),
            )
          else
            Switch(
              value: on,
              onChanged: onToggle,
              activeThumbColor: color,
              activeTrackColor: color.withValues(alpha: 0.25),
              inactiveThumbColor: C.grey,
              inactiveTrackColor: C.greyBg,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          Icon(Icons.chevron_right_rounded, size: 18, color: C.greyLight),
        ]),
      ),
    );
  }
}

/// 分区内统一提示说明块
class SettingsHint extends StatelessWidget {
  final String text;
  final Color? color; // 可空：build 内回退到 C.slate（运行时可变，不能作 const 默认值）
  final IconData icon;
  const SettingsHint(this.text,
      {super.key, this.color, this.icon = Icons.info_outline_rounded});

  @override
  Widget build(BuildContext context) {
    final c = color ?? C.slate;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: c),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text, style: ts(11, c: c, h: 1.4)),
          ),
        ],
      ),
    );
  }
}

/// 可折叠分区卡片
class SettingsFold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final bool open;
  final VoidCallback onToggle;

  /// 长按标题行（开发人员那一块用它来输口令解锁，平时点不开）。
  final VoidCallback? onLongPress;
  final List<Widget> children;
  const SettingsFold({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.color,
    required this.open,
    required this.onToggle,
    this.onLongPress,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          onTap: onToggle,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 17),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: ts(13, c: color, w: FontWeight.w700)),
                    if (subtitle != null) ...[
                      SizedBox(height: 2),
                      Text(subtitle!,
                          style: ts(10, c: C.slate),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              ),
              Icon(
                  open
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  color: C.grey,
                  size: 20),
            ]),
          ),
        ),
        SettingsExpandable(
          open: open,
          children: [
            Divider(height: 1, color: C.border),
            ...children,
          ],
        ),
      ]),
    );
  }
}

/// 折叠面板的「展开内容」：高度与透明度**一起**做动画。
///
/// 为什么不是 `open ? Column(...) : SizedBox()` + [AnimatedSize]：
/// 那样只有外框在动，内容本身是**瞬间**出现、瞬间消失的 —— 收起时内容
/// 先凭空不见、再看着一块空白塌下去，展开时则是「啪」地一下填满。
/// 用户报的「面板退出/进入动画会突然闪一下，或者突然填充」正是这个
/// （issue #16）。
///
/// 实现用 [SizeTransition] + [FadeTransition]（同一个 controller 驱动）：
///   * 尺寸从 0 长到内容高度、内容同时淡入；收起反过来，先淡出、再塌高；
///   * 裁切交给 SizeTransition 自带的 ClipRect，动画中途内容不会溢出卡片
///     （溢出也会被看成「闪」）；
///   * **不用 [AnimatedCrossFade]**：它的 layoutBuilder 是「只有 Positioned
///     子项的 Stack」，而本控件嵌在 Column / 卡片里（竖向约束无界），
///     那种 Stack 的尺寸会取 constraints.biggest。这里用最普通的
///     「带高度因子的 Align（SizeTransition 内部就是这个）」 ——
///     子项拿到无界高度时 Column 会自己收缩，不会出无界尺寸问题。
///
/// 子控件始终在树上（只是被裁切/透明），所以**收起态下也能 `find` 到它们**；
/// 这是淡出动画必须的代价，没有 UI 测试依赖「收起时不存在」。
class SettingsExpandable extends StatefulWidget {
  final bool open;
  final List<Widget> children;

  /// 与 [SettingsFold] 原来的展开时长保持一致（200ms）。
  final Duration duration;

  const SettingsExpandable({
    super.key,
    required this.open,
    required this.children,
    this.duration = const Duration(milliseconds: 200),
  });

  @override
  State<SettingsExpandable> createState() => _SettingsExpandableState();
}

class _SettingsExpandableState extends State<SettingsExpandable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: widget.duration,
      // 初始就停在终态：页面刚进来时不应看到一段「展开动画」。
      value: widget.open ? 1 : 0,
    );
  }

  @override
  void didUpdateWidget(SettingsExpandable old) {
    super.didUpdateWidget(old);
    if (widget.open == old.open) return;
    // ⚠ 必须区分 forward / reverse 而不能统一 reverseFrom(1)：
    // forward() 在控制器已经是 1 时是空操作，反向同理。
    if (widget.open) {
      _c.forward();
    } else {
      _c.reverse();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: _c,
      axis: Axis.vertical,
      // 从顶部展开（与 [SettingsFold] 的 alignment: topCenter 一致）。
      axisAlignment: -1,
      child: FadeTransition(
        opacity: _c,
        // 保留 Column 的默认 crossAxisAlignment（center）：与改动前
        // 完全一致，避免无意中把某行子控件从居中改成拉伸。
        child: Column(children: widget.children),
      ),
    );
  }
}

/// 卡片分区（非折叠）
class SettingsSectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final Widget? trailing;
  final List<Widget> children;
  const SettingsSectionCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.color,
    this.trailing,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: title,
      subtitle: subtitle,
      icon: icon,
      color: color,
      trailing: trailing,
      children: children,
    );
  }
}

/// 设置主页整卡入口行（图标 + 标题 + 可选说明 + 右箭头）。
///
/// 主页原先有十来个入口各自手写这一段：图标底座在 32/40 间、图标在 17/20 间、
/// 箭头在 18/20 间各写各的；更乱的是标题与说明的排布 —— 有的用
/// `Text(标题) + Expanded(说明)`，说明紧跟标题（标题长短不同 → 说明起始位置
/// 参差不齐）；有的用 `Flexible(2) + Expanded(3)`（说明固定在 40% 处）。两种混用
/// 就是用户看到的「没对齐」。统一到这里：**底座 32、图标 17、箭头 18**，
/// 标题/说明按 **2:3** 固定份额，所有入口的说明左端对齐。
class SettingsEntryTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? desc;
  /// 图标底色渐变（主题可替换）。与主页其它入口一致的两色回退。
  final List<Color> fallback;
  /// 图标插槽 id。给了它图标可被主题替换。
  final String? slot;
  final VoidCallback onTap;

  const SettingsEntryTile({
    super.key,
    required this.icon,
    required this.title,
    this.desc,
    required this.fallback,
    this.slot,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconBox = Container(
      width: 32,
      height: 32,
      decoration: C.accentDeco(radius: 8, fallback: fallback),
      child: slot == null
          ? Icon(icon, color: Colors.white, size: 17)
          : ThemeController.instance.buildSlotIcon(
              slot!,
              size: 17,
              color: Colors.white,
              fallbackIcon: icon,
            ),
    );
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: cardDeco(),
        child: Row(
          children: [
            iconBox,
            const SizedBox(width: 10),
            // 标题用**紧**份额（Expanded 而非 Flexible）：松份额在文字较短时
            // 会留出一截剩余空间，箭头就不再贴右（标题越短越靠左飘）。
            // 紧份额把剩余宽度吃干净，箭头恒定贴右，且说明列起点固定 → 对齐。
            Expanded(
              flex: 2,
              child: Text(
                title,
                style: ts(13, w: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            if (desc != null)
              Expanded(
                flex: 3,
                child: Text(
                  desc!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: Color(0xFF98A2B8)),
                ),
              )
            else
              const Spacer(),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, color: C.grey, size: 18),
          ],
        ),
      ),
    );
  }
}


/// ─── 呼号后缀（SSID）选择弹层 ───
///
/// 0–15 是 APRS 主网的取值范围，做成格子是为了常用值一点就到。字母后缀
/// （`-B` 这种）只有我们自己的 APRSNETCN 服务器收，所以下面给一个输入框，
/// 想用的人自己填 1–2 位数字或字母。
///
/// 返回选中的后缀（`''` = 不要后缀）。用户点了外面、或按了返回键返回 `null`，
/// 调用方据此什么都不改 —— 「关掉」不能等于「清空后缀」。
Future<String?> showSsidPicker(
  BuildContext context, {
  required String current,
}) {
  final ctrl = TextEditingController(text: current);
  // 错误提示存在弹层外面：StatefulBuilder 的 builder 每重建一次就重跑一遍，
  // 写在里面的局部变量会被重置成 null，提示就永远显示不出来。
  String? errorText;
  final done = showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => StatefulBuilder(
      builder: (ctx, setModalState) {
        final s = S.of(ctx);

        void pick(String v) => Navigator.of(ctx).pop(v);

        void submit() {
          final v = AppState.normalizeSsid(ctrl.text);
          if (v == null) {
            setModalState(() => errorText = s.ssidInvalid);
            return;
          }
          pick(v);
        }

        Widget chip(String label, String value) {
          final sel = current == value;
          return GestureDetector(
            onTap: () => pick(value),
            child: Container(
              width: 64,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: sel ? C.blue : C.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: sel ? C.blue : C.border),
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: ts(
                  13,
                  c: sel ? Colors.white : C.slate,
                  w: sel ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          );
        }

        return Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: MaterialSurface(
            radius: 24,
            topOnly: true,
            child: Container(
              decoration: BoxDecoration(
                color: C.sheetFill,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: C.greyLight,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(s.chooseSsidSuffix, style: ts(16, w: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    s.ssidDescShort,
                    style: ts(11, c: C.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      chip(s.none, ''),
                      for (int i = 1; i <= 15; i++) chip('-$i', '$i'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: ctrl,
                          autofocus: false,
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp('[0-9A-Za-z]')),
                            LengthLimitingTextInputFormatter(2),
                          ],
                          style: ts(14, w: FontWeight.w700),
                          decoration: InputDecoration(
                            labelText: s.ssidCustom,
                            hintText: s.ssidCustomHint,
                            hintStyle: ts(11, c: C.greyLight),
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: C.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: C.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: C.blue, width: 1.5),
                            ),
                          ),
                          onChanged: (_) {
                            if (errorText != null) setModalState(() => errorText = null);
                          },
                          onSubmitted: (_) => submit(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: submit,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 13),
                          decoration: BoxDecoration(
                            color: C.blue,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            s.ssidUse,
                            style: ts(13, c: Colors.white, w: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        errorText!,
                        style: ts(11, c: C.red, h: 1.35),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
  return done.whenComplete(ctrl.dispose);
}
