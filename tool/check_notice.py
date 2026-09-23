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
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# 应用支持的语言 → 官网公告文件名（与 lib/notice.dart 的构造规则一致）
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

    # ── ① 官网的公告文件 ──
    for lg in LANGS:
        rel = f'docs/notice/{lg}.md'
        if not exists(rel):
            errors.append(f'缺 {rel} —— 官网那侧没有这个语言的公告，'
                          f'「{lg}」用户永远看不到（其余语言正常，很难发现）')
        elif len(read(rel).strip()) < 20:
            errors.append(f'{rel} 太短（<20 字符）—— 多半是占位没写完，'
                          '用户会看到一行空的公告')
    # 英文是兜底：它必须存在（其它语言都缺时靠它）
    if not exists('docs/notice/en.md'):
        errors.append('缺 docs/notice/en.md —— 它是**兜底**语言，'
                      '其它语言取不到时全靠它')

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

    # ── 设置页接线：开关 + 横幅 ──
    sp = read('lib/settings_pages.dart')
    need('lib/settings_pages.dart', 'st.setNoticeBanner(',
         '设置页没有公告开关的写回 —— 开关点了不生效')
    need('lib/settings_pages.dart', 'NoticeBanner(',
         '设置页没有放公告横幅 —— 功能等于不存在')
    need('lib/settings_pages.dart', 'NoticePage(',
         '横幅点不开全文 —— 用户只能看到一行摘要')
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
    print(f'公告横幅 ok（官网 {len(LANGS)} 个语言文件齐、开关关闭不联网、'
          'MD 走 GFM 且链接交给系统浏览器、相对地址补全、开关落盘+进备份）')
    return 0


if __name__ == '__main__':
    sys.exit(main())
