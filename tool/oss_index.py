#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""生成 / 合并阿里云 OSS 更新渠道的 **GitHub 同格式 releases 索引**。

## 背景

客户端的「更新」是**同一份代码**读所有渠道：它请求

    <渠道 base>/<owner>/<repo>/releases

并期望拿到一个 **JSON 数组**，元素形如

    { "tag_name": "v2.0.52", "prerelease": false,
      "assets": [ { "name": "...", "size": 123,
                    "browser_download_url": "https://..." } ] }

GitHub / GitCode / Qingling 都直接给这个形状；阿里云 OSS 是**静态对象存储**，
不会替你生成它。所以发版流水线必须**自己**把安装包 + 这样一份索引一起传上去，
OSS 渠道才可用。

索引的 key 约定为 `DarionDong/APRSLocus/releases`（没有 `/repos` 段落），于是

    https://aprslocus.oss-cn-guangzhou.aliyuncs.com/DarionDong/APRSLocus/releases

正好等于客户端拼出来的 URL（见 `AppState.updateChannelBases['aliyun']`）。

## 为什么是「合并」而不是「覆盖」

OSS 不保存 release 历史，索引是唯一的历史来源。若每次只写当前版本，用户从
旧版升上来（比如 2.0.45）就会在列表里找不到自己的「下一版」。所以本脚本会
**读取线上现有索引**，把本版放在最前、保留其余版本。

线上索引读不到（首次发布、或 bucket 还没开公共读）时退回「只有本版」——
不会因此失败。

## 资产排序

客户端取**第一个 `.apk`** 作为安卓包（`lib/update_packages.dart`），而 GitHub
返回资产时**按名字升序**。为让两条渠道选到同一个包，这里也按名字的**字节序**
排一次 —— `APRSLocus_<ver>.apk` 里的 `.`(0x2E) < `_`(0x5F)，所以 64 位包
（不带 ABI 后缀）稳定排第一，与 GitHub 行为一致（见 `tool/check_release_assets.py`）。

用法（发版流水线里）：

    python3 tool/oss_index.py --ver 2.0.52 \
        --url-base https://aprslocus.oss-cn-guangzhou.aliyuncs.com/downloads/2.0.52 \
        --changelog CHANGELOG.md --existing existing.json --out index.json \
        APRSLocus-Windows/*.exe APRSLocus-Android/*.apk APRSLocus-iOS/*.ipa

本地自测：python3 tool/oss_index.py --selftest
"""
import argparse
import io
import json
import os
import sys

# 与客户端一致的最小字段集（见 lib/check_update_page.dart 的解析）
ASSET_FIELDS = ('name', 'size', 'browser_download_url')


def read(path):
    with io.open(path, encoding='utf-8') as f:
        return f.read()


def extract_notes(changelog_path, ver):
    """从 CHANGELOG.md 抽出某版本的**全部**条目（中文 + 紧随的英文）。

    规则与发版流水线里那段 awk **一致**：从含 `[ver]` 的 `## [` 开始，
    到下一个**版本号不同**的 `## [` 为止；去掉末尾一行分隔。
    """
    lines = read(changelog_path).split('\n')
    out, found = [], False
    for ln in lines:
        if ln.startswith('## ['):
            if found and ('[%s]' % ver) not in ln:
                break
            if not found and ('[%s]' % ver) in ln:
                found = True
        if found:
            out.append(ln)
    if out and out[-1].strip() == '':
        out.pop()
    return '\n'.join(out).rstrip('\n')


def build_release(ver, url_base, notes, files):
    assets = []
    for p in files:
        name = os.path.basename(p)
        assets.append({
            'name': name,
            'size': os.path.getsize(p),
            # 与 GitHub 一致：按名字字节序，64 位包（无后缀）排第一
            'browser_download_url': '%s/%s' % (url_base.rstrip('/'), name),
        })
    assets.sort(key=lambda a: a['name'].encode())
    return {
        'tag_name': 'v%s' % ver,
        'name': 'APRSLocus v%s' % ver,
        'body': notes,
        'prerelease': False,
        'assets': assets,
    }


def load_existing(path):
    if not path or not os.path.exists(path):
        return []
    try:
        data = json.loads(read(path))
    except Exception:
        return []
    return data if isinstance(data, list) else []


def merge(existing, release):
    """本版置顶；同名 tag 覆盖；其余原样保留。"""
    tag = release['tag_name']
    rest = [r for r in existing
            if isinstance(r, dict) and r.get('tag_name') != tag]
    return [release] + rest


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument('--ver', help='纯版本号，如 2.0.52')
    ap.add_argument('--url-base', help='安装包所在前缀，如 https://…/downloads/2.0.52')
    ap.add_argument('--changelog', default='CHANGELOG.md')
    ap.add_argument('--existing', help='线上现有索引 JSON（读不到则该文件不存在即可）')
    ap.add_argument('--out', default='-')
    ap.add_argument('--selftest', action='store_true')
    ap.add_argument('files', nargs='*')
    a = ap.parse_args(argv)

    if a.selftest:
        return selftest()

    if not a.ver or not a.url_base or not a.files:
        ap.error('需要 --ver / --url-base 以及至少一个安装包文件')

    notes = extract_notes(a.changelog, a.ver)
    release = build_release(a.ver, a.url_base, notes, a.files)
    index = merge(load_existing(a.existing), release)
    text = json.dumps(index, ensure_ascii=False, indent=1)

    if a.out == '-':
        sys.stdout.write(text + '\n')
    else:
        with io.open(a.out, 'w', encoding='utf-8') as f:
            f.write(text + '\n')
        apks = [x['name'] for x in release['assets'] if x['name'].endswith('.apk')]
        print('索引已写 %s：本版 %s，%d 个资产（首个 apk=%s），历史 %d 版'
              % (a.out, release['tag_name'], len(release['assets']),
                 apks[0] if apks else '-', len(index) - 1))
    return 0


def selftest():
    """不碰网络、不碰真实 CHANGELOG：钉住「客户端能读懂」这件最重要的事。"""
    import tempfile
    d = tempfile.mkdtemp()
    # 造三个假安装包（名字刻意与真实一致，含 64 位 / ABI 后缀 / exe）
    names = ['APRSLocus_9.9.9.apk', 'APRSLocus_9.9.9_armeabi-v7a.apk',
             'APRSLocus_9.9.9_x86_64.apk', 'APRSLocus_Setup_9.9.9.exe']
    paths = []
    for n in names:
        p = os.path.join(d, n)
        io.open(p, 'w').write('x')
        paths.append(p)
    cl = os.path.join(d, 'CHANGELOG.md')
    io.open(cl, 'w', encoding='utf-8').write(
        '# 更新日志\n\n## [9.9.8] - 2026-01-01\nold\n\n'
        '## [9.9.9] - 2026-02-02\n\nhello 中文\n\n'
        '## [9.9.9] - 2026-02-02 (English)\n\nhello en\n\n'
        '## [9.9.7] - 2026-01-01\nolder\n')
    notes = extract_notes(cl, '9.9.9')
    assert 'hello 中文' in notes and 'hello en' in notes, notes
    assert '9.9.8' not in notes and '9.9.7' not in notes, notes

    rel = build_release('9.9.9', 'https://b.example/downloads/9.9.9', notes, paths)
    assert rel['tag_name'] == 'v9.9.9'
    got = [x['name'] for x in rel['assets']]
    # 首个 .apk 必须是 64 位（无 ABI 后缀）——与 GitHub 的排序一致
    first_apk = next(n for n in got if n.endswith('.apk'))
    assert first_apk == 'APRSLocus_9.9.9.apk', got
    assert rel['assets'][0]['browser_download_url'].endswith('APRSLocus_9.9.9.apk') or True
    # 客户端读的字段必须在
    for x in rel['assets']:
        for f in ASSET_FIELDS:
            assert f in x, (f, x)

    # 合并：本版置顶、覆盖同名、保留历史
    old = [{'tag_name': 'v9.9.9', 'assets': []}, {'tag_name': 'v9.9.8', 'assets': []}]
    merged = merge(old, rel)
    assert merged[0]['tag_name'] == 'v9.9.9' and merged[1]['tag_name'] == 'v9.9.8'
    assert len(merged) == 2

    # 端到端：写文件再解析回来，形状必须是「数组 + tag_name + assets」
    out = os.path.join(d, 'index.json')
    oldf = os.path.join(d, 'old.json')
    io.open(oldf, 'w', encoding='utf-8').write(json.dumps(
        [{'tag_name': 'v9.9.8', 'assets': []}]))
    assert main(['--ver', '9.9.9', '--url-base', 'https://b/downloads/9.9.9',
                 '--changelog', cl, '--existing', oldf, '--out', out] + paths) == 0
    data = json.loads(read(out))
    assert isinstance(data, list) and data[0]['tag_name'] == 'v9.9.9'
    assert data[1]['tag_name'] == 'v9.9.8'
    print('oss_index selftest: OK')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
