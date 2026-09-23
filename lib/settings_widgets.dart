import 'package:flutter/material.dart';
import 'theme.dart';
import 'widgets.dart';
import 'state.dart';
import 'material.dart';
import 'guide.dart';

/// 设置子页面外壳：标题 + 返回 + 可滚动内容
class SettingsPageShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Widget body;
  final AppState? state; // 传入后自动监听刷新（body 需引用 state 的 getter 以实时更新）

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
        padding: const EdgeInsets.all(16),
        child: Column(
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

  const SettingsInput(this.label, this.controller,
      {super.key,
      this.onChanged,
      this.onEditingComplete,
      this.focusNode,
      this.tip,
      this.hint});

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
            ),
          ),
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
  const SettingsSwitch(this.label,
      {super.key, required this.value, required this.onChanged, this.color});

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
            style: ts(12, c: C.slate),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Switch(
          value: value,
          onChanged: onChanged,
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

/// 可点击的设置行（进入子页面）
///
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
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: color),
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
  final List<Widget> children;
  const SettingsFold({
    super.key,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.color,
    required this.open,
    required this.onToggle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          onTap: onToggle,
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
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: open
              ? Column(children: [
                  Divider(height: 1, color: C.border),
                  ...children,
                ])
              : const SizedBox(width: double.infinity),
        ),
      ]),
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
