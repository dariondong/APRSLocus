import 'package:flutter/material.dart';
import 'theme.dart';
import 'widgets.dart';
import 'state.dart';

/// 设置子页面外壳：标题 + 返回 + 可滚动内容
class SettingsPageShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Widget body;
  final AppState? state; // 传入后自动监听刷新（body 需引用 state 的 getter 以实时更新）
  const SettingsPageShell({
    super.key,
    required this.title,
    this.subtitle = '',
    required this.icon,
    required this.color,
    required this.body,
    this.state,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: C.slate),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          SizedBox(width: 10),
          Text(title, style: ts(16, w: FontWeight.w700)),
        ]),
        bottom: subtitle.isEmpty
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(32),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Row(children: [
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
                      child: Text(subtitle,
                          style: ts(11, c: C.grey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ]),
                ),
              ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: body,
      ),
    );
  }
}

/// 设置输入行
class SettingsInput extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final String? tip;
  const SettingsInput(this.label, this.controller,
      {super.key, this.onChanged, this.tip});

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
            onChanged: onChanged,
            textAlign: TextAlign.right,
            style: ts(13, w: FontWeight.w600),
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 6),
              border: InputBorder.none,
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
      child: Row(children: [
        Text(label, style: ts(12, c: C.slate)),
        Spacer(),
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
      Text(label, style: ts(11, c: C.slate)),
      Spacer(),
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
      child: Row(children: [
        Text(label, style: ts(12, c: C.slate)),
        const Spacer(),
        Text(value, style: ts(13, w: FontWeight.w600, c: valueColor)),
      ]),
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
                  borderRadius: BorderRadius.circular(10),
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
