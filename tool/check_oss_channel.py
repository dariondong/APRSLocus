#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""阿里云 OSS 更新渠道的接线检查。

## 为什么需要它

OSS 渠道由**四处**约定拼成，任何一处漏了都**不会报错**，只会表现成
「更新页少了这个渠道」或「选了这个渠道却 403 —— 看起来像客户端 bug」：

  1. 客户端登记了渠道地址     —— `lib/state.dart` 的 `updateChannelBases['aliyun']`
  2. 客户端选择器里有这个渠道 —— `lib/check_update_page.dart` 的 `setUpdateChannel('aliyun')`
  3. 发版流水线真的上传了     —— `.github/workflows/build-release.yml` 的 `publish-oss`
     ① 把三个平台的安装包都传上去；② 生成并上传 GitHub 同格式的 releases 索引
  4. 索引生成器的形状对       —— `tool/oss_index.py`（跑它的 selftest）

外加一条**安全**约定：访问密钥只能来自 GitHub Secrets，
**绝不能**出现在仓库任何文件里（本仓库是公开的）。

用法：python3 tool/check_oss_channel.py
退出码 0 = 接线正确；1 = 有问题（并说明哪一条）。
"""
import io
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

STATE = 'lib/state.dart'
UPDATE_PAGE = 'lib/check_update_page.dart'
WORKFLOW = '.github/workflows/build-release.yml'
OSS_TOOL = 'tool/oss_index.py'
ARB_FILES = ['lib/l10n/app_%s.arb' % l for l in
             ('zh', 'zh_TW', 'en', 'ja', 'es', 'id')]

CHANNEL = 'aliyun'
BUCKET = 'aprslocus'
ENDPOINT = 'oss-cn-guangzhou.aliyuncs.com'
INDEX_KEY = 'DarionDong/APRSLocus/releases'

# 访问密钥绝不能落到仓库里（公开仓库 = 泄露）。**注意本文件自己也不能写密钥
# 原文**（那等于亲手把密钥提交上去），所以这里只匹配**通用前缀特征**：
# 阿里云 AccessKey ID 一律以 `LTAI` 开头，后接一串大小写字母/数字。
AK_ID_RE = re.compile(r'LTAI[0-9A-Za-z]{12,}')
# 明文写进 workflow 的凭据参数（`-i 值` / `-k 值`；值必须是**字面量**）。
# 判据：紧跟 `-i`/`-k` 的 token 以**字母/数字**开头且长度 ≥12 ——
# `-i "$VAR"`（以引号/`$` 开头）与 `-i 5`（太短）都不算。
INLINE_CRED_RE = re.compile(r'(?m)^.*\s-[ik]\s+[A-Za-z0-9]\S{11,}')


def read(rel):
    return io.open(os.path.join(ROOT, rel), encoding='utf-8').read()


def main() -> int:
    errors = []
    state = read(STATE)
    page = read(UPDATE_PAGE)
    yml = read(WORKFLOW)

    # ── ① 客户端登记了渠道地址，且 host 与流水线一致 ──
    m = None
    for line in state.split('\n'):
        if "'%s':" % CHANNEL in line and 'https://' in line:
            m = line
            break
    if not m:
        errors.append('%s 的 updateChannelBases 里没有 `%s` 渠道' % (STATE, CHANNEL))
    else:
        if BUCKET not in m or ENDPOINT not in m:
            errors.append('%s 里 %s 的地址不是 %s.%s（与流水线的 bucket/endpoint 对不上）'
                          % (STATE, CHANNEL, BUCKET, ENDPOINT))
    if "'%s':" % CHANNEL not in state or 'updateChannelLabels' not in state:
        errors.append('%s 缺少 %s 的渠道显示名' % (STATE, CHANNEL))
    else:
        lbl = state[state.find('updateChannelLabels'):]
        if "'%s':" % CHANNEL not in lbl[:lbl.find('}')]:
            errors.append('%s 的 updateChannelLabels 里没有 `%s`（提示/无障碍标签会回退成裸 id）'
                          % (STATE, CHANNEL))

    # ── ② 选择器里有这个渠道 + 费用提示条 ──
    if "setUpdateChannel('%s')" % CHANNEL not in page:
        errors.append('%s 的渠道选择器里没有 `%s` 选项' % (UPDATE_PAGE, CHANNEL))
    if 'updateChannelAliyunHint' not in page:
        errors.append('%s 没有用到「开发团队付费、请少量使用」的费用提示文案 '
                      '（updateChannelAliyunHint）' % UPDATE_PAGE)
    if 'connectingAliyun' not in page:
        errors.append('%s 的加载状态行没处理 `%s`（会退回 Qingling 的文案）'
                      % (UPDATE_PAGE, CHANNEL))

    # ── ③ 流水线真的把安装包与索引传到 OSS ──
    if 'publish-oss:' not in yml:
        errors.append('%s 里没有 `publish-oss` job —— OSS 渠道永远不会有新包' % WORKFLOW)
    else:
        job = yml[yml.find('publish-oss:'):]
        for glob in ('APRSLocus-Windows/*.exe', 'APRSLocus-Android/*.apk',
                     'APRSLocus-iOS/*.ipa'):
            if glob not in job:
                errors.append('%s 的 publish-oss 没有上传 `%s`' % (WORKFLOW, glob))
        if INDEX_KEY not in job:
            errors.append('%s 的 publish-oss 没有用约定的索引 key `%s` —— '
                          '客户端会请求到不存在的对象' % (WORKFLOW, INDEX_KEY))
        if 'oss_index.py' not in job:
            errors.append('%s 的 publish-oss 没有调用 tool/oss_index.py 生成索引' % WORKFLOW)
        if '--acl public-read' not in job:
            errors.append('%s 的 publish-oss 没把对象设为 public-read —— '
                          '客户端（匿名）会拿到 403' % WORKFLOW)
        # OSS 默认域名（*.aliyuncs.com）对 `.apk` / `.ipa` 下载返回 400
        # （ApkDownloadForbidden）。索引 url 与上传目标都必须走
        # tool/oss_index.py 的 delivery_name()（加 `.bin` 后缀）。这里钉住
        # 「上传用了同一套规则」与「验证步真去下资产」。
        if '--delivery-name' not in job:
            errors.append('%s 的 publish-oss 上传安装包时没有用 '
                          '`tool/oss_index.py --delivery-name` 算目标对象名 —— '
                          'OSS 会对 `.apk`/`.ipa` 返回 400（ApkDownloadForbidden）' % WORKFLOW)
        if 'Content-Type:application/octet-stream' not in job:
            errors.append('%s 的 publish-oss 上传时没显式设 Content-Type='
                          'application/octet-stream' % WORKFLOW)
        if 'browser_download_url' not in job:
            errors.append('%s 的 publish-oss 的自检没有真去下索引里的资产 —— '
                          '`.apk`/`.ipa` 的 400 会被漏掉' % WORKFLOW)

        # 凭据必须来自 secrets
        for need in ('secrets.OSS_ACCESS_KEY_ID', 'secrets.OSS_ACCESS_KEY_SECRET'):
            if need not in job:
                errors.append('%s 的 publish-oss 没有用 `%s`（凭据应来自 Secrets）'
                              % (WORKFLOW, need))

    # ── ④ 索引生成器自带 selftest，且真能跑过 ──
    if not os.path.exists(os.path.join(ROOT, OSS_TOOL)):
        errors.append('缺少 %s' % OSS_TOOL)
    else:
        r = subprocess.run([sys.executable, os.path.join(ROOT, OSS_TOOL), '--selftest'],
                           capture_output=True, text=True)
        if r.returncode != 0:
            errors.append('%s --selftest 失败：%s' % (OSS_TOOL, (r.stderr or r.stdout).strip()))

    # ── ⑤ l10n 键齐全 ──
    for rel in ARB_FILES:
        t = read(rel)
        for k in ('updateChannelAliyunHint', 'connectingAliyun'):
            if '"%s"' % k not in t:
                errors.append('%s 缺 l10n 键 `%s`' % (rel, k))

    # ── ⑥ 安全：访问密钥不得出现在仓库任何文件里 ──
    for dirpath, dirnames, filenames in os.walk(ROOT):
        dirnames[:] = [d for d in dirnames if d not in ('.git', 'build', '.dart_tool')]
        for fn in filenames:
            fp = os.path.join(dirpath, fn)
            try:
                t = io.open(fp, encoding='utf-8', errors='ignore').read()
            except Exception:
                continue
            rel = os.path.relpath(fp, ROOT)
            if AK_ID_RE.search(t):
                errors.append('!! %s 里出现了阿里云 AccessKey ID 明文 —— 本仓库是公开的，'
                              '密钥必须放在 GitHub Secrets 里' % rel)
            if fn.endswith(('.yml', '.yaml')):
                for ln in t.split('\n'):
                    if INLINE_CRED_RE.match(ln) and 'secrets.' not in ln:
                        errors.append('!! %s 里把凭据写成了明文参数：`%s`'
                                      % (rel, ln.strip()[:60]))

    if errors:
        print('OSS 渠道接线检查：发现 %d 个问题' % len(errors))
        for e in errors:
            print('  -', e)
        return 1
    print('OSS 渠道接线检查：OK')
    return 0


if __name__ == '__main__':
    sys.exit(main())
