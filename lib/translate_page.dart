import 'dart:async';

import 'package:flutter/material.dart';

import 'l10n/app_localizations.dart';
import 'settings_widgets.dart';
import 'state.dart';
import 'theme.dart';
import 'translate.dart';
import 'widgets.dart';

/// ─── 翻译设置页 ───
///
/// 覆盖三家接口：Google / 百度 / 自定义。
/// 之所以把「测试翻译」放在同一页：三家接口都需要用户自己去申请凭据，
/// 配完立刻能验证，比发一条消息试要快得多。
class TranslateSettingsPage extends StatefulWidget {
  final AppState state;
  const TranslateSettingsPage({super.key, required this.state});

  @override
  State<TranslateSettingsPage> createState() => _TranslateSettingsPageState();
}

class _TranslateSettingsPageState extends State<TranslateSettingsPage> {
  late final TextEditingController _googleKey;
  late final TextEditingController _baiduId;
  late final TextEditingController _baiduKey;
  late final TextEditingController _customUrl;
  late final TextEditingController _customHeaders;
  late final TextEditingController _customBody;
  late final TextEditingController _customPath;

  bool _testing = false;
  String _testResult = '';
  bool _testOk = false;

  TranslateService get svc => TranslateService.instance;
  TranslateConfig get cfg => svc.config;

  @override
  void initState() {
    super.initState();
    _googleKey = TextEditingController(text: cfg.googleApiKey);
    _baiduId = TextEditingController(text: cfg.baiduAppId);
    _baiduKey = TextEditingController(text: cfg.baiduKey);
    _customUrl = TextEditingController(text: cfg.customUrl);
    _customHeaders = TextEditingController(text: cfg.customHeaders);
    _customBody = TextEditingController(text: cfg.customBody);
    _customPath = TextEditingController(text: cfg.customResultPath);
  }

  @override
  void dispose() {
    for (final c in [
      _googleKey, _baiduId, _baiduKey,
      _customUrl, _customHeaders, _customBody, _customPath,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _collect() async {
    cfg
      ..googleApiKey = _googleKey.text.trim()
      ..baiduAppId = _baiduId.text.trim()
      ..baiduKey = _baiduKey.text.trim()
      ..customUrl = _customUrl.text.trim()
      ..customHeaders = _customHeaders.text.trim()
      ..customBody = _customBody.text.trim()
      ..customResultPath = _customPath.text.trim();
    await svc.saveConfig();
  }

  void _toast(String msg, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: color ?? C.ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _test() async {
    await _collect();
    final s = S.of(context);
    if (!cfg.ready) {
      _toast(s.translateNeedConfig, color: C.orange);
      return;
    }
    setState(() {
      _testing = true;
      _testResult = '';
    });
    try {
      final r = await svc.translate(
        'Hello, this is APRSlocus.',
        to: cfg.targetLang,
      );
      // 顺手把识别结果显示出来：用户能据此确认接口真的在回传语言信息，
      // 而「对方的语言」正是靠这个字段自动学出来的
      final out = r.detected == null
          ? r.text
          : '${r.text}  [${TransLang.labelOf(r.detected!)}]';
      if (mounted) {
        setState(() {
          _testOk = true;
          _testResult = s.translateTestOk(out);
        });
      }
    } on TranslateException catch (e) {
      if (mounted) {
        setState(() {
          _testOk = false;
          _testResult = s.translateFailed(e.message);
        });
      }
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) => SettingsPageShell(
        title: s.translateSettings,
        subtitle: s.translateSettingsSubtitle,
        icon: Icons.translate_rounded,
        color: C.cyan,
        body: Column(children: [
          _defaultCard(s),
          const SizedBox(height: 16),
          _providerCard(s),
          const SizedBox(height: 16),
          _credentialsCard(s),
          const SizedBox(height: 16),
          _testCard(s),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  /// 默认目标语言 + 隐私说明
  Widget _defaultCard(S s) {
    return SettingsSectionCard(
      title: s.translateTargetLang,
      subtitle: s.translateSettingsSubtitle,
      icon: Icons.language_rounded,
      color: C.blue,
      children: [
        SettingsRow2(s.translateTargetLang, TransLang.labelOf(cfg.targetLang)),
        SettingsRow2(
          s.translateProvider,
          cfg.provider == 'free'
              ? s.translateProviderFree
              : (cfg.provider == 'google'
                  ? s.translateProviderGoogle
                  : (cfg.provider == 'baidu'
                      ? s.translateProviderBaidu
                      : s.translateProviderCustom)),
          valueColor: cfg.ready ? C.green : C.orange,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final l in TransLang.all.where((l) => l.code != 'auto'))
                _chip(
                  label: l.label,
                  selected: cfg.targetLang == l.code,
                  onTap: () async {
                    cfg.targetLang = l.code;
                    await svc.saveConfig();
                    if (mounted) setState(() {});
                  },
                ),
            ],
          ),
        ),
        SettingsHint(s.translatePrivacyNote, color: C.orange,
            icon: Icons.privacy_tip_rounded),
      ],
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? C.blueBg : C.bgSoft,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? C.blue : C.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: ts(11,
              c: selected ? C.blue : C.slate,
              w: selected ? FontWeight.w700 : FontWeight.w500),
        ),
      ),
    );
  }

  /// 接口选择
  Widget _providerCard(S s) {
    // 免费接口放首位：它是默认值，也让「不想申请密钥」的用户第一眼就看到
    final items = [
      ('free', s.translateProviderFree, Icons.bolt_rounded),
      ('google', s.translateProviderGoogle, Icons.g_mobiledata_rounded),
      ('baidu', s.translateProviderBaidu, Icons.translate_rounded),
      ('custom', s.translateProviderCustom, Icons.settings_ethernet_rounded),
    ];
    return SettingsSectionCard(
      title: s.translateProvider,
      icon: Icons.cloud_sync_rounded,
      color: C.cyan,
      children: [
        for (final (key, label, icon) in items)
          InkWell(
            onTap: () async {
              cfg.provider = key;
              await svc.saveConfig();
              if (mounted) setState(() => _testResult = '');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: C.border, width: 0.4),
                ),
              ),
              child: Row(children: [
                Icon(icon,
                    size: 18,
                    color: cfg.provider == key ? C.cyan : C.grey),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: ts(13,
                        w: cfg.provider == key ? FontWeight.w700 : FontWeight.w500,
                        c: cfg.provider == key ? C.cyan : C.ink),
                  ),
                ),
                if (cfg.provider == key)
                  Icon(Icons.check_circle_rounded, size: 18, color: C.cyan)
                else
                  Icon(Icons.radio_button_unchecked_rounded,
                      size: 18, color: C.greyLight),
              ]),
            ),
          ),
      ],
    );
  }

  /// 凭据：按接口只显示相关字段，避免一屏无关输入框
  Widget _credentialsCard(S s) {
    return SettingsSectionCard(
      title: cfg.provider == 'free'
          ? s.translateProviderFree
          : s.translateProvider,
      icon: Icons.key_rounded,
      color: C.slate,
      children: [
        if (cfg.provider == 'free') ...[
          // 免密钥：这里不放任何输入框，只说明它的性质与取舍
          SettingsHint(s.translateProviderFreeDesc, color: C.green,
              icon: Icons.bolt_rounded),
        ] else if (cfg.provider == 'google') ...[
          SettingsInput(s.translateGoogleKey, _googleKey,
              tip: s.translateGoogleKeyTip, onChanged: (_) => unawaited(_collect())),
          SettingsHint(s.translateGoogleKeyTip),
        ] else if (cfg.provider == 'baidu') ...[
          SettingsInput(s.translateBaiduAppId, _baiduId,
              onChanged: (_) => unawaited(_collect())),
          SettingsInput(s.translateBaiduKey, _baiduKey,
              onChanged: (_) => unawaited(_collect())),
          SettingsHint(s.translateBaiduTip),
        ] else ...[
          SettingsInput(s.translateCustomUrl, _customUrl,
              onChanged: (_) => unawaited(_collect())),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 2),
            child: Row(children: [
              Text(s.translateCustomMethod, style: ts(12, c: C.slate)),
              const Spacer(),
              for (final m in ['GET', 'POST'])
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: _chip(
                    label: m,
                    selected: cfg.customMethod == m,
                    onTap: () async {
                      cfg.customMethod = m;
                      await svc.saveConfig();
                      if (mounted) setState(() {});
                    },
                  ),
                ),
            ]),
          ),
          SettingsInput(s.translateCustomHeaders, _customHeaders,
              onChanged: (_) => unawaited(_collect())),
          SettingsInput(s.translateCustomBody, _customBody,
              tip: s.translateCustomBodyTip('{text}', '{from}', '{to}'),
              onChanged: (_) => unawaited(_collect())),
          SettingsHint(
              s.translateCustomBodyTip('{text}', '{from}', '{to}')),
          SettingsInput(s.translateCustomResultPath, _customPath,
              tip: s.translateCustomResultPathTip,
              onChanged: (_) => unawaited(_collect())),
          SettingsHint(s.translateCustomResultPathTip),
        ],
      ],
    );
  }

  /// 测试
  Widget _testCard(S s) {
    return SettingsSectionCard(
      title: s.translateTest,
      icon: Icons.science_rounded,
      color: C.green,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          child: SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton.icon(
              onPressed: _testing ? null : _test,
              icon: _testing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow_rounded, size: 18),
              label: Text(s.translateTest,
                  style: ts(13, c: Colors.white, w: FontWeight.w700)),
              style: FilledButton.styleFrom(
                backgroundColor: C.green,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ),
        if (_testResult.isNotEmpty)
          SettingsHint(_testResult, color: _testOk ? C.green : C.red,
              icon: _testOk
                  ? Icons.check_circle_rounded
                  : Icons.error_outline_rounded),
        SettingsRow2(s.translate, '${svc.requestCount} / ${svc.failureCount}'),
      ],
    );
  }
}
