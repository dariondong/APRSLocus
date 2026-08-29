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
                preferredSize: const Size.fromHeight(30),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16, bottom: 10),
                    child: Text(subtitle,
                        style: ts(11, c: C.grey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
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
            style: ts(12, w: FontWeight.w500),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
        Text(value, style: ts(12, w: FontWeight.w600, c: valueColor)),
      ]),
    );
  }
}

/// 可折叠分区卡片
class SettingsFold extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final bool open;
  final VoidCallback onToggle;
  final List<Widget> children;
  const SettingsFold({
    super.key,
    required this.title,
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
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Icon(icon, color: color, size: 18),
              SizedBox(width: 8),
              Text(title, style: ts(12, c: color, w: FontWeight.w700, ls: 1)),
              Spacer(),
              Icon(open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  color: C.grey, size: 20),
            ]),
          ),
        ),
        if (open) Divider(height: 1, color: C.border),
        if (open) ...children,
      ]),
    );
  }
}

/// 卡片分区（非折叠）
class SettingsSectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<Widget> children;
  const SettingsSectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return SectionCard(title: title, icon: icon, color: color, children: children);
  }
}
