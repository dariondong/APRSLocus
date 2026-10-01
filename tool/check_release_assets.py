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
PACKAGES = 'lib/update_packages.dart'
DEVICE_ABI = 'lib/device_abi_io.dart'

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

    # ── ④ 挑包必须**按本机架构自动完成**，且不让用户选、不跳浏览器 ──
    #
    # ⚠ 判据的粒度很关键：安装包要贴架构标签（`arm64-v8a · 30.3 MB`），那是对的东西
    #   —— 对全文搜 `arm64-v8a` 会把正确的标签当成「挑包看 ABI」误报。所以只看
    #   挑包那一小段代码，并且先剥掉注释（本仓库「注释命中」的老坑）。
    pkg = read(PACKAGES)

    def _code_only_lines(src):
        return '\n'.join(l for l in src.split('\n')
                         if not l.lstrip().startswith('//'))

    i0, i1 = pkg.find('bool isApkAsset'), pkg.find('String abiLabelOfAssetName')
    if i0 < 0 or i1 < 0 or i1 < i0:
        errors.append('%s 里找不到 isApkAsset / abiLabelOfAssetName —— '
                      '检查器自己失效了（结构变了？）' % PACKAGES)
        pick_region = ''
    else:
        pick_region = _code_only_lines(pkg[i0:i1])
        if "endsWith('.apk')" not in pick_region:
            errors.append('%s 里没有「第一个 .apk」的判据 —— 认不出架构时会挑不到包'
                          % PACKAGES)
        # 兜底本身不许看 ABI：认不出来的平台/架构必须退回「第一个 .apk」。
        for bad in ('armeabi', 'arm64', 'x86_64', 'SUPPORTED_ABIS'):
            if bad in pick_region:
                errors.append('%s 的挑包部分（isApkAsset / pickUpdateAsset）出现了 `%s` '
                              '—— 兜底逻辑不该看 ABI（它必须在认不出架构时仍能用）'
                              % (PACKAGES, bad))
    if 'return pickUpdateAsset(assets);' not in pkg:
        errors.append('%s 的 pickUpdateAssetFor 没有回退到 pickUpdateAsset() —— '
                      '认不出架构（桌面端 / Web / 没见过的 ABI）时会挑不到包' % PACKAGES)

    # 页面：挑包要按**本机架构**，且不许自己解析文件名。
    m = re.search(r'Map<String, dynamic>\? assetFor\(bool isWindows\) \{(.*?)\n  \}', upd, re.S)
    if not m:
        errors.append('%s 里找不到 assetFor 的实现 —— 检查器自己失效了（函数被改名/搬走？）'
                      % UPDATE_PAGE)
    else:
        body = _code_only_lines(m.group(1))
        if 'pickUpdateAssetFor(assets' not in body:
            errors.append('%s 的 assetFor 不再走 pickUpdateAssetFor() —— '
                          '安卓会挑到架构不对的包（装上会报 ABI 不匹配）' % UPDATE_PAGE)
        for bad in ('armeabi', 'arm64', 'x86_64', 'SUPPORTED_ABIS'):
            if bad in body:
                errors.append('%s 的 assetFor 里出现了 `%s` —— 架构判断该在 '
                              'device_abi.dart / update_packages.dart 里做' % (UPDATE_PAGE, bad))

    # 本机架构标签必须与 update_packages.dart 的标签表**逐字一致**：
    # 一个是 dart:ffi 报出来的，一个是从文件名读出来的，对不上就静默挑不到包
    # （回退成 64 位包 → 32 位老机型装了会报 ABI 不匹配）。
    #
    # ⚠ 判据必须从 device_abi_io 里**通用地**抠出 `return '...'`，而不是拿预期标签
    #   去匹配 —— 后者遇到拼错（`armeabi-v7`）会「不匹配 ⇒ 什么都没抓到」，
    #   于是检查静默通过（负向自测当场抓到这条漏洞）。
    abi_io = read(DEVICE_ABI)
    labels_pkg = set(re.findall(r"'(arm64-v8a|armeabi-v7a|x86_64)'", pkg))
    io_labels = set(re.findall(r"return '([^']+)';", _code_only_lines(abi_io)))
    if not io_labels:
        errors.append('%s 一个架构标签都没返回 —— 本机架构永远认不出来，'
                      '32 位老机型会下到装不上的包' % DEVICE_ABI)
    missing = io_labels - labels_pkg
    if missing:
        errors.append('%s 返回的架构标签 %s 在 %s 的标签表里找不到 —— '
                      '两边必须逐字一致，否则静默挑不到包（会退回 64 位包）'
                      % (DEVICE_ABI, sorted(missing), PACKAGES))

    # 用户明确要求：**别让用户自己选**（「搞那么多用户都不知道怎么选」），
    # 也别用浏览器跳转解决下载。这条页面里不许出现启动外部浏览器的入口。
    if 'launchUrl' in _code_only_lines(upd):
        errors.append('%s 里出现了 `launchUrl` —— 分架构之后包要由应用按本机架构'
                      '自己挑着下（不让用户选、也不跳浏览器）' % UPDATE_PAGE)

    # ── ⑤ 把「64 位排第一」算一遍（这是**兜底**那条路的不变量）──
    #
    # 认不出本机架构时（桌面端 / Web / 没见过的 ABI）会回退到「列表里第一个 .apk」，
    # 那时希望它是 64 位包 —— 命名约定 + 名字升序保证了这一点。
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
          '更新页按**本机架构**自动挑包、在应用内下载，不让用户选也不跳浏览器；'
          '认不出架构时回退到名字升序的第一个 = 64 位包）')
    return 0


if __name__ == '__main__':
    sys.exit(main())
