#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""公告横幅的静态检查。

背景（用户需求）：「在设置里添加一个公告横幅用户可以打开，公告内容从官网文件夹
拉取，md 应用内支持渲染 MD 和超链接」。

这几条**全都能正常编译、也能通过 analyze**，却会在真机上表现成各种「怪」：

  1. **官网那侧的文件**：应用按 `notice/<语言>.md` 取，所以要检查官网目录里
     真有这些文件、且都非空。少一个语言的表现是「那个语言的用户永远看不到公告」，
     而中文用户一切正常 —— 很难被发现。
  2. **开关关掉必须真的不联网**：用户关它多半就是不想让它联网。若把关掉只做成
     「隐藏」（照旧 `load()`），表现是「关了还在偷偷请求」—— 这类问题不会报错，
     只能靠读代码或抓包发现。
  3. **链接必须交给系统浏览器**：公告里的链接若被当成普通文字，用户会以为
     「链接坏了」；若在应用内 `Navigator.push` 一个网址，则会白屏。
  4. **相对链接要补全**：`[手册](/manual/)` 这种相对地址 `launchUrl` 直接失败 ——
     用户看到的还是「点了没反应」。所以渲染器必须带 baseUrl 补全逻辑。

另外钉住依赖与「MD 真的被解析」这两件事：
  * `pubspec.yaml` 里有 `markdown`（否则 `markdown_view.dart` 编译不过，
    但那只在 CI 才报）；
  * 渲染器用的是 `ExtensionSet.gitHubFlavored`（表格/任务列表/自动链接都在这个
    set 里；换成 `commonMark` 会**静默**丢掉表格）。

用法：python3 tool/check_notice.py
退出码 0 = 全在；1 = 有缺失（并说明缺什么）。
"""
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# 应用支持的语言（与 lib/notice.dart 的构造规则一致）
LANGS = ['zh', 'zh_TW', 'en', 'ja', 'es', 'id']


def read(rel):
    return io.open(os.path.join(ROOT, rel), encoding='utf-8').read()


def exists(rel):
    return os.path.exists(os.path.join(ROOT, rel))


def code_only(rel):
    """剔掉整行注释，只留代码。

    为什么必需（回归样本当场验出来的）：`markdown_view.dart` 顶部的文档注释里
    就写着「用 `ExtensionSet.gitHubFlavored`」来解释为什么选它 —— 拿全文搜
    会把**说明文字**当成实现，于是把代码换成 commonMark 仍然报绿。
    本仓库其它检查器（check_frame_cost / check_material_coverage）都踩过同一个坑。
    """
    return '\n'.join(l for l in read(rel).split('\n')
                     if not l.lstrip().startswith('//'))


def main() -> int:
    errors = []

    def need(rel, needle, why):
        if needle not in read(rel):
            errors.append(f'{rel} 里找不到 `{needle}` —— {why}')

    # ── ① 公告 Markdown（**手写源**）──
    #
    # 历史：公告 md 曾由官网首页公告区生成（tool/sync_notice_md.py），
    # 但公告内容越来越长（多级标题、内嵌视频等），固定字段的生成式表达不了。
    # 现在改为**手写 Markdown**：`docs/notice/<lang>.md` 就是唯一来源。
    # 这里只做「别被写空/写坏」的底线校验，不再与官网 HTML 逐字节比对。
    for lang in ('zh', 'zh_TW', 'en'):
        rel = f'docs/notice/{lang}.md'
        if not exists(rel):
            errors.append(f'缺 {rel} —— 应用公告的来源（手写 Markdown）')
            continue
        body = read(rel).strip()
        if len(body) < 40:
            errors.append(f'{rel} 太短（<40 字符）—— 多半被写空了')
        if not body.startswith('# '):
            errors.append(f'{rel} 没有以一级标题 `# ` 开头 —— 横幅摘要取不到标题')
    # 其余语言（可选）：应用会退回 en.md；但若存在就不能是空壳
    for lg in ('ja', 'es', 'id'):
        rel = f'docs/notice/{lg}.md'
        if exists(rel) and len(read(rel).strip()) < 20:
            errors.append(f'{rel} 太短（<20 字符）—— 要么写完整，要么删掉'
                          '（删掉后该语言会退回 en.md）')
    # 公告里的内嵌视频标记必须真的被渲染（否则会露出一行 `@video ...` 文字）
    need('lib/markdown_view.dart', '@video',
         '公告的内嵌视频标记（`@video <url>`）没有被 markdown_view 渲染')

    # ── ①b 官网公告区必须与 app 公告（docs/notice/*.md）逐字节一致 ──
    #
    # 唯一手写处是 md（app 读它）；官网首页那条公告由
    # `tool/sync_notice_site.py` 生成。两边各写一份必然漂移，所以这里按
    # 「脚本会生成什么」与页面现内容比对：改了 md 忘了跑脚本 → CI 直接报红。
    try:
        sys.path.insert(0, os.path.join(ROOT, 'tool'))
        import sync_notice_site as NS  # noqa: E402
    except Exception as e:  # pragma: no cover
        NS = None
        errors.append(f'导入 tool/sync_notice_site.py 失败：{e}')
    if NS is not None:
        for lang, page_rel, md_rel in NS.PAGES:
            if not exists(page_rel) or not exists(md_rel):
                errors.append(f'缺 {page_rel} 或 {md_rel} —— 公告同步的输入/输出')
                continue
            page = read(page_rel)
            want_head = NS.render_head(lang)
            want_body = ('<div class="announce-body">\n'
                         + NS.render_body(read(md_rel)) + '\n    </div>')
            if want_head not in page:
                errors.append(f'{page_rel} 公告头部与 {md_rel} 不一致 —— '
                              '跑 `python3 tool/sync_notice_site.py`')
            if want_body not in page:
                errors.append(f'{page_rel} 公告正文与 {md_rel} 不一致 —— '
                              '跑 `python3 tool/sync_notice_site.py`')

    # ── ② 开关关掉必须真的不发请求 ──
    nb = read('lib/notice_banner.dart')
    if 'if (!widget.state.noticeBanner) return; // 关掉 → 一次请求都不发' \
            not in nb:
        errors.append('lib/notice_banner.dart 的 _boot() 没有在开头拦掉'
                      '「开关已关」—— 用户关了它却还会联网拉公告')
    if 'if (!widget.state.noticeBanner) return const SizedBox.shrink();' \
            not in nb:
        errors.append('lib/notice_banner.dart 的 build() 没有在开关关闭时返回空'
                      '—— 关掉后横幅还在')

    # ── ③④ 渲染器：链接、相对地址、GFM ──
    mv = read('lib/markdown_view.dart')
    mv_code = code_only('lib/markdown_view.dart')
    if 'ExtensionSet.gitHubFlavored' not in mv_code:
        errors.append('Markdown 解析没用 GFM 扩展集（`ExtensionSet.gitHubFlavored`）'
                      '—— 表格/任务列表/自动链接会**静默**消失')
    need('lib/markdown_view.dart', 'launchUrl(',
         '公告里的链接没有交给系统浏览器打开 —— 用户会以为链接坏了')
    need('lib/markdown_view.dart', 'LaunchMode.externalApplication',
         '打开链接的方式与应用其它地方不一致（统一用 externalApplication）')
    need('lib/markdown_view.dart', 'WidgetSpan',
         '链接没有用 WidgetSpan 实现（用 TapGestureRecognizer 需要 dispose，'
         '公告会因刷新而重建 → 每次重建泄漏一批）')
    # ⚠ 必须断言**定义那一行**：只断言 `_abs(` 出现过是无效的 —— 把定义改名后
    #   调用点仍然写着 `_abs(...)`，检查照样绿（回归样本当场验出来的）。
    if 'baseUrl' not in mv_code or 'String _abs(String url) {' not in mv_code:
        errors.append('lib/markdown_view.dart 没有相对地址补全'
                      '（缺 `String _abs(String url) {`）—— '
                      '`[手册](/manual/)` 这类链接点了会直接失败')
    # 表格 / 代码块 / 图片三个块级类型都要有分支，否则「支持 MD」是半截的
    for tag, why in (("case 'table':", '表格'), ("case 'pre':", '代码块'),
                     ("case 'img':", '图片')):
        if tag not in mv_code:
            errors.append(f'lib/markdown_view.dart 缺 {why} 的渲染分支（`{tag}`）')

    # ── 依赖 ──
    need('pubspec.yaml', 'markdown:',
         'pubspec 没有 markdown 依赖 —— markdown_view.dart 编译不过（只在 CI 报）')

    # ── 设置页接线：开关 + 公告入口 ──
    sp = read('lib/settings_pages.dart')
    need('lib/settings_pages.dart', 'st.setNoticeBanner(',
         '设置页没有公告开关的写回 —— 开关点了不生效')
    # 横幅要放**两处**：主页（1.0）与地图页（2.0）
    need('lib/home_page.dart', 'NoticeBanner(',
         '1.0 主页没有公告横幅 —— 用户要求「在主页显示横幅」')
    need('lib/shell2.dart', 'NoticeBanner(',
         '2.0 地图页没有公告横幅 —— 用户要求「在主页显示横幅」')
    # ── 设置子页**不许**再放横幅 ──
    #
    # 用户：「不要在子页留了」。
    # ⚠ 必须先把 `setNoticeBanner(`（开关的写回）剔掉再搜：它**含有** `NoticeBanner(`
    #   这个子串 —— 只带左括号是不够的，回归样本当场就验出来了（那条断言第一次跑
    #   直接报红，而子页里其实已经没有横幅了）。假失败比真失败更坏，所以这里
    #   先把开关名字整个删掉，剩下的才是「真的用了横幅组件」。
    sp_no_switch = re.sub(r'setNoticeBanner\s*\(', '', sp)
    if 'NoticeBanner(' in sp_no_switch:
        errors.append('lib/settings_pages.dart 里又出现了 `NoticeBanner(` —— '
                      '用户明确要求「不要在子页留」（设置子页里只留开关）')
    # ── 设置**主页**底部要有公告入口（用户：「在设置主页底下添加一个公告进入按钮」）──
    hsp = read('lib/settings_page.dart')
    # 也带左括号：同样是为了不被 `setNoticeBanner(` 骗到
    if 'showNoticeSheet(' not in hsp:
        errors.append('lib/settings_page.dart 里没有 `showNoticeSheet(` —— '
                      '设置主页那个公告入口没有打开全文（点了没反应）')
    if 'NoticeStore.instance.load(' not in hsp:
        errors.append('lib/settings_page.dart 里没有 `NoticeStore.instance.load(` —— '
                      '设置主页那个公告入口不会去取公告（得先拿内容才能弹层）')
    # 全文用**底部弹层**而不是整页（用户：「打开就不能以弹窗的形式？」）
    need('lib/notice_banner.dart', 'showNoticeSheet(',
         '公告全文没有用底部弹层 —— 用户明确要求不要整页')
    need('lib/notice_banner.dart', 'showModalBottomSheet',
         '全文不是「底部弹层」（showModalBottomSheet）')
    if 'class NoticeSheet' not in read('lib/notice_banner.dart'):
        errors.append('没有 NoticeSheet（弹层内容）—— 全文又退回整页了')
    # 横幅自带关闭按钮，且关闭 = 把**开关**置 off（一个来源、两种入口）
    need('lib/notice_banner.dart', 'widget.state.setNoticeBanner(false)',
         '横幅的关闭按钮没有把开关置为 off —— 那样关掉后下次打开又回来（「我明明关了」）')
    # 2.0 那边要把横幅高度算进地图让位量，否则会压住地图自己的浮层
    need('lib/shell2.dart', 'NoticeBanner.stripHeight',
         '2.0 外壳没把公告横幅的高度算进顶部让位量 —— 横幅会压住地图浮层')
    # 高度必须是常量（组件里声明），外壳才能安全地引用
    need('lib/notice_banner.dart', 'static const double stripHeight',
         '横幅高度不是常量 —— 让位量会随内容抖动')
    # 开关要落盘 + 进备份（换机后不该被静默打开）
    need('lib/state.dart', "setBool('noticeBanner'", '公告开关没有落盘')
    need('lib/state.dart', "getBool('noticeBanner')", '公告开关没有读回')
    need('lib/backup.dart', "'noticeBanner'",
         '公告开关没进备份分组 —— 换机后会被静默打开（表现为「又开始联网拉公告」）')

    # ── 语言码要与官网文件名对得上（对不上就是「只显示兜底英文」） ──
    if 'notice/${' not in read('lib/notice.dart'):
        errors.append('lib/notice.dart 的取址规则变了 —— 本检查按 '
                      '`notice/<语言>.md` 校验官网文件，请同步更新')

    if errors:
        print('公告横幅检查失败：')
        for e in errors:
            print('  -', e)
        return 1
    print('公告横幅 ok（docs/notice/*.md 手写源齐备、开关关闭不联网、'
          'MD 走 GFM 且链接交给系统浏览器、相对地址补全、@video 内嵌、开关落盘+进备份）')
    return 0


if __name__ == '__main__':
    sys.exit(main())
