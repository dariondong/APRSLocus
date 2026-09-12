import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import 'theme.dart';
import 'widgets.dart';
// honorLangOf：荣誉/成就/赞助共用同一套语言回落（ja/id → 英文）
import 'early_member.dart';

/// 赞助与鸣谢页面（赞助名单从官网 sponsors.json 在线更新，离线用内置兜底）
const String kSponsorsUrl = 'https://aprslocus.theez.top/sponsors.json';

/// 一条赞助记录。
///
/// [name] / [desc] 是**中文基准**（兼容旧 sponsors.json 与旧调用）；
/// [names] / [descs] 是可选的多语言覆盖（key: zh / zh-TW / en）。
/// 荣誉与成就同理：**只维护 zh / zh-TW / en**，日语、印尼语等统一取英文。
typedef SponsorItem = ({
  String kind,
  String name,
  Map<String, String> names,
  String desc,
  Map<String, String> descs,
});

/// 按语言取文案：该语言 → **英文** → 中文基准
String sponsorText(Map<String, String> m, String base, String lang) =>
    m[lang] ?? m['en'] ?? base;

/// 从 sponsors.json 的一项里取多语言字段（无则空表）
Map<String, String> _langMap(Object? v) {
  if (v is Map) {
    return {
      for (final e in v.entries)
        if (e.value is String) '${e.key}': e.value as String,
    };
  }
  return const {};
}

class SponsorPage extends StatefulWidget {
  const SponsorPage({super.key});
  @override
  State<SponsorPage> createState() => _SponsorPageState();
}

class _SponsorPageState extends State<SponsorPage> {
  /// 在线赞助名单，默认内置（中文基准 + 可选多语言覆盖）
  List<SponsorItem> _sponsors = [
    (
      kind: 'group',
      name: 'STUDENT HAMS 群组',
      names: const {
        'zh': 'STUDENT HAMS 群组',
        'zh-TW': 'STUDENT HAMS 群組',
        'en': 'STUDENT HAMS community',
      },
      desc: '感谢群组的资金赞助，支持 APRSlocus 持续开发与运营。',
      descs: const {
        'zh-TW': '感謝群組的資金贊助，支持 APRSlocus 持續開發與營運。',
        'en': 'Thanks to the group for funding APRSlocus development and operations.',
      },
    ),
    (
      kind: 'coffee',
      name: 'BG7PGW',
      names: const {},
      desc: '感谢赞助的蜜雪冰城一杯 🧋',
      descs: const {
        'zh-TW': '感謝贊助的蜜雪冰城一杯 🧋',
        'en': 'Thanks for sponsoring a Mixue drink 🧋',
      },
    ),
    (
      kind: 'jade',
      name: 'BG7ORC',
      names: const {},
      desc: '赠我以琼琚 · 承君厚赠，藏之于心；唯有砥砺，以报清音',
      descs: const {
        'zh-TW': '贈我以瓊琚 · 承君厚贈，藏之於心；唯有砥礪，以報清音',
        'en': 'Gifted with jade — your kindness is treasured in my heart; the only return I can offer is to strive, and answer with good work.',
      },
    ),
    (
      kind: 'school',
      name: 'BA4JLD',
      names: const {},
      desc: '青岛科技大学业余无线电俱乐部 · 赠我以琼琚',
      descs: const {
        'zh-TW': '青島科技大學業餘無線電俱樂部 · 贈我以瓊琚',
        'en': 'Qingdao University of Science and Technology Amateur Radio Club · Gifted with jade',
      },
    ),
    (
      kind: 'jade',
      name: 'BA4IUD',
      names: const {},
      desc: '赠我以琼琚 · 承君厚赠，藏之于心；唯有砥砺，以报清音',
      descs: const {
        'zh-TW': '贈我以瓊琚 · 承君厚贈，藏之於心；唯有砥礪，以報清音',
        'en': 'Gifted with jade — your kindness is treasured in my heart; the only return I can offer is to strive, and answer with good work.',
      },
    ),
    (
      kind: 'jade',
      name: 'BD1FEH',
      names: const {},
      desc: '赠我以琼琚 · 承君厚赠，藏之于心；唯有砥砺，以报清音',
      descs: const {
        'zh-TW': '贈我以瓊琚 · 承君厚贈，藏之於心；唯有砥礪，以報清音',
        'en': 'Gifted with jade — your kindness is treasured in my heart; the only return I can offer is to strive, and answer with good work.',
      },
    ),
    (
      kind: 'everyone',
      name: '每一位支持者',
      names: const {
        'zh': '每一位支持者',
        'zh-TW': '每一位支持者',
        'en': 'Every supporter',
      },
      desc: '你们的每一份支持，都是 APRSlocus 继续发光的动力。',
      descs: const {
        'zh-TW': '你們的每一份支持，都是 APRSlocus 繼續發光的動力。',
        'en': 'Every bit of your support keeps APRSlocus shining.',
      },
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadSponsors();
  }

  Future<void> _loadSponsors() async {
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 8);
      try {
        final req = await client
            .getUrl(Uri.parse(kSponsorsUrl))
            .timeout(const Duration(seconds: 8));
        req.headers.set(HttpHeaders.userAgentHeader, 'APRSlocus');
        final resp = await req.close().timeout(const Duration(seconds: 8));
        if (resp.statusCode != 200) return;
        final body = await resp.transform(utf8.decoder).join();
        final d = jsonDecode(body);
        if (d is! Map) return;
        final list = d['sponsors'];
        if (list is List && list.isNotEmpty) {
          final parsed = <SponsorItem>[];
          for (final it in list) {
            if (it is Map) {
              final name = it['name'];
              final desc = it['desc'];
              if (name is String && name.isNotEmpty) {
                parsed.add((
                  kind: (it['kind'] as String?) ?? 'fav',
                  name: name,
                  // 可选多语言字段（names / descs）；未提供则该语言走英文→中文基准
                  names: _langMap(it['names']),
                  desc: (desc as String?) ?? '',
                  descs: _langMap(it['descs']),
                ));
              }
            }
          }
          if (parsed.isNotEmpty) {
            if (mounted) setState(() => _sponsors = parsed);
          }
        }
      } finally {
        client.close(force: true);
      }
    } catch (_) {}
  }

  IconData _kindIcon(String kind) => switch (kind) {
        'group' => Icons.group_rounded,
        'coffee' => Icons.local_cafe_rounded,
        'jade' => Icons.card_giftcard_rounded,
        'school' => Icons.school_rounded,
        _ => Icons.favorite_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: C.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: C.ink, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(S.of(context).sponsors, style: ts(16, w: FontWeight.w700)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        children: [
          Center(child: AppLogo(size: 76)),
          const SizedBox(height: 12),
          Center(
            child: Text(
              S.of(context).sponsorsThanks,
              style: ts(18, w: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              S.of(context).supportProject,
              style: ts(12, c: C.slate),
            ),
          ),
          const SizedBox(height: 28),
          // ── 作者 ──
          _sectionHeader(S.of(context).author, Icons.school_rounded, C.blue),
          const SizedBox(height: 8),
          SoftCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _feature(
                  Icons.person_rounded,
                  'BG7LZQ',
                  S.of(context).sponsorAuthorItems,
                ),
                _feature(
                  Icons.rocket_launch_rounded,
                  S.of(context).continuousIteration,
                  S.of(context).continuousIterationDesc,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // ── 赞助支持（在线更新） ──
          _sectionHeader(
            S.of(context).sponsorSupport,
            Icons.volunteer_activism_rounded,
            C.purple,
          ),
          const SizedBox(height: 8),
          SoftCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final sp in _sponsors)
                  _feature(
                    _kindIcon(sp.kind),
                    sponsorText(sp.names, sp.name, honorLangOf(context)),
                    sponsorText(sp.descs, sp.desc, honorLangOf(context)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // ── 赞助方式 ──
          _sectionHeader(
            S.of(context).sponsorMethods,
            Icons.paid_rounded,
            C.green,
          ),
          const SizedBox(height: 8),
          SoftCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                // 微信赞赏码（点击放大）
                InkWell(
                  onTap: () => _showQr(
                    context,
                    'assets/WechatPay.jpg',
                    S.of(context).donateWechat,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: C.border, width: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFF07C160)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.wechat_rounded,
                            size: 18,
                            color: Color(0xFF07C160),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                S.of(context).donateWechat,
                                style: ts(13, w: FontWeight.w700),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                S.of(context).donateWechatDesc,
                                style: ts(11, c: C.grey),
                              ),
                            ],
                          ),
                        ),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.asset(
                            'assets/WechatPay.jpg',
                            width: 42,
                            height: 42,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 42,
                              height: 42,
                              color: C.greyBg,
                              child: const Icon(
                                Icons.wechat_rounded,
                                size: 20,
                                color: Color(0xFF07C160),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: C.grey,
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
                // 支付宝（占位说明）
                Container(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1677FF)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_rounded,
                          size: 18,
                          color: Color(0xFF1677FF),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              S.of(context).donateAlipay,
                              style: ts(13, w: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              S.of(context).donateAlipayDesc,
                              style: ts(11, c: C.grey),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: C.grey,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Center(
            child: Text(
              S.of(context).nonprofitNote,
              textAlign: TextAlign.center,
              style: ts(11, c: C.grey, h: 1.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon, Color c) {
    return Row(
      children: [
        Icon(icon, size: 16, color: c),
        const SizedBox(width: 6),
        Text(
          title,
          style: ts(13, w: FontWeight.w700, c: c),
        ),
      ],
    );
  }

  Widget _feature(IconData icon, String title, String desc) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: C.border, width: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: C.blueBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: C.blue),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: ts(13, w: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(desc, style: ts(11, c: C.slate, h: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 弹出赞赏码大图
  void _showQr(BuildContext context, String asset, String title) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: GestureDetector(
          onTap: () => Navigator.pop(ctx),
          child: Container(
            decoration: BoxDecoration(
              color: C.white,
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  S.of(context).qrCodeTitle(title),
                  style: ts(15, w: FontWeight.w800),
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    asset,
                    width: 260,
                    height: 260,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 260,
                      height: 260,
                      color: C.greyBg,
                      child: Center(child: Text(S.of(context).qrLoadFailed)),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(S.of(context).qrSaveWechat, style: ts(11, c: C.grey)),
                const SizedBox(height: 4),
                Text(
                  S.of(context).tapAnywhereClose,
                  style: ts(10, c: C.greyLight),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
