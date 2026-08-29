import 'package:flutter/material.dart';

import 'theme.dart';
import 'widgets.dart';

/// 赞助与鸣谢页面
class SponsorPage extends StatelessWidget {
  const SponsorPage({super.key});

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
          // ── 赞助支持 ──
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
                _feature(
                  Icons.group_rounded,
                  S.of(context).sponsorGroup,
                  S.of(context).sponsorGroupItems,
                ),
                _feature(
                  Icons.local_cafe_rounded,
                  'BG7PGW',
                  S.of(context).sponsorBgpItems,
                ),
                _feature(
                  Icons.favorite_rounded,
                  S.of(context).sponsorEvery,
                  S.of(context).sponsorEveryItems,
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
                      child: const Center(
                        child: Text(S.of(context).qrLoadFailed),
                      ),
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
