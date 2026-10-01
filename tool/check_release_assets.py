#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""安卓分架构打包的接线检查（v2.0.11 起）。

## 为什么需要它

发版从「一个通用 APK」改成「按 ABI 三个包」，靠的是一条**看不见的约定**：

  应用内更新取的是 Release 资产列表里**第一个 `.apk`**
  （`lib/check_update_page.dart` 的 `assetFor`），
  而 GitHub 返回资产时**按名字升序**排（12 个历史版本逐个核对过）。

于是只要 64 位包仍然叫 `APRSLocus_2.0.11.apk`（不带 ABI 后缀），
它名字里那个 `.`（0x2E）比 `_`（0x5F）小，就**永远排在**
`APRSLocus_2.0.11_armeabi-v7a.apk` / `..._x86_64.apk` 前面 ——
64 位用户走的还是原来那条路，更新逻辑一行都不用改。

这条约定一旦被破坏，**不会有任何东西失败**：CI 全绿、Release 正常、
只有「应用内更新」默默下到 32 位包（装不上）或下错包。这正是本仓库
最该用检查挡住的那类错。所以这里钉住四件事：

  1. 发版流水线必须用 `--split-per-abi`（否则又变回 81MB 的通用包）；
  2. 三个包的命名必须与约定一致（64 位**不带**后缀、另外两个带自己的 ABI 后缀）；
  3. 更新逻辑必须还是「取第一个 `.apk`」，且**不许**出现按 ABI 挑包的代码
     （用户明确要求更新逻辑不动）；
  4. **把「64 位排第一」真的算一遍**（多个样例版本号，且按字节序与忽略大小写
     两种排法都成立）——而不是相信注释。

用法：python3 tool/check_release_assets.py
退出码 0 = 接线正确；1 = 有问题（并说明哪一条）。
"""
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

WORKFLOW = '.github/workflows/build-release.yml'
UPDATE_PAGE = 'lib/check_update_page.dart'

# 约定：ABI → 文件名的后缀（64 位是空后缀 = 沿用原来的名字）
ABI_SUFFIX = {
    'arm64-v8a': '',
    'armeabi-v7a': '_armeabi-v7a',
    'x86_64': '_x86_64',
}


def read(rel):
    return io.open(os.path.join(ROOT, rel), encoding='utf-8').read()


def apk_name(ver, abi):
    return 'APRSLocus_%s%s.apk' % (ver, ABI_SUFFIX[abi])


def main() -> int:
    errors = []
    yml = read(WORKFLOW)
    upd = read(UPDATE_PAGE)

    # ── ① 必须是分架构构建 ──
    # ⚠ 只看**那条命令本身**：`--split-per-abi` 在注释与错误提示里都会出现，
    #    按全文匹配就永远查不出来（负向自测当场抓到了这条漏洞）。
    m = re.search(r'(?m)^\s*run:\s*flutter build apk --release(.*)$', yml)
    if not m:
        errors.append('%s 里找不到 `flutter build apk --release` 那条命令 —— '
                      '检查器自己失效了（构建方式改了？）' % WORKFLOW)
    elif '--split-per-abi' not in m.group(1):
        errors.append('%s 里的安卓构建没有 `--split-per-abi` —— 又会打出 81MB 的'
                      '通用包（三份原生库叠在一起）' % WORKFLOW)

    # ── ② 三个包的命名必须与约定一致 ──
    #    判据写成「源文件名 → 目标文件名」的成对形式，避免只查半句就算过。
    for abi in ABI_SUFFIX:
        src = 'app-%s-release.apk' % abi
        dst = 'APRSLocus_${ver}%s.apk' % ABI_SUFFIX[abi]
        if src not in yml:
            errors.append('%s 里没有处理 `%s` —— 这个架构的包会被漏掉'
                          '（而 upload 用的是通配 `APRSLocus_*.apk`，漏了也不会报错）'
                          % (WORKFLOW, src))
        if dst not in yml:
            errors.append('%s 里没有把 `%s` 改名为 `%s` —— 命名约定被改动了'
                          % (WORKFLOW, src, dst))

    # 64 位**不许**带 ABI 后缀（带了更新就会挑错包 / 挑到不存在的包）
    if 'APRSLocus_${ver}_arm64-v8a.apk' in yml:
        errors.append('%s 里把 64 位包也加了 `_arm64-v8a` 后缀 —— 应用内更新会去下'
                      '`APRSLocus_<版本>.apk`（不存在）或挑到别的包' % WORKFLOW)

    # ── ③ 三个包都要真的进 Release ──
    if 'APRSLocus-Android/*.apk' not in yml:
        errors.append('%s 的 Release 步骤没有挂 `APRSLocus-Android/*.apk` —— '
                      '分架构的包发不出去' % WORKFLOW)
    if 'APRSLocus_*.apk' not in yml:
        errors.append('%s 的 upload-artifact 路径没覆盖 `APRSLocus_*.apk`' % WORKFLOW)

    # ── ④ 更新逻辑必须保持「取第一个 .apk」，且不许按 ABI 挑包 ──
    if "if (n.endsWith('.apk')) return a;" not in upd:
        errors.append('%s 的 assetFor 不再用「第一个 .apk」的规则 —— '
                      '本检查的前提（与命名约定）需要跟着重新设计' % UPDATE_PAGE)
    # 注意不要把裸 `abi` 当关键词：它太短，会命中无关的词（本仓库踩过「裸名误报」的坑）。
    for bad in ('armeabi-v7a', 'arm64-v8a', 'SUPPORTED_ABIS'):
        if bad in upd:
            errors.append('%s 里出现了 `%s` —— 应用内更新被改成按 ABI 挑包了；'
                          '用户要求「更新默认走 64 位、逻辑不要动」' % (UPDATE_PAGE, bad))

    # ── ⑤ 把「64 位排第一」算一遍（这才是让「不改逻辑」成立的那条性质）──
    for ver in ('1.0.0', '2.0.11', '9.9.99', '10.0.0'):
        names = [apk_name(ver, abi) for abi in ABI_SUFFIX]
        first = sorted(names)[0]
        first_ci = sorted(names, key=str.lower)[0]
        if first != apk_name(ver, 'arm64-v8a') or first_ci != apk_name(ver, 'arm64-v8a'):
            errors.append('版本 %s 的三个包里，按名字升序排第一的是 `%s` 而**不是** 64 位包 —— '
                          '应用内更新会下到它' % (ver, first))
        print('  %s → 资产顺序: %s   ⇒ 更新取到: %s'
              % (ver, ' | '.join(sorted(names)), first))

    if errors:
        print('安卓分架构打包检查失败：')
        for e in errors:
            print('  -', e)
        return 1
    print('安卓分架构打包 ok（--split-per-abi；三个包都命名/挂进 Release；'
          '64 位沿用原名 ⇒ 名字升序永远第一 ⇒ 应用内更新逻辑不用动）')
    return 0


if __name__ == '__main__':
    sys.exit(main())
