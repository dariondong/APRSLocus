#!/usr/bin/env python3
"""同步 GitHub Actions 构建的发行包到 GitCode Releases。

用法：GITCODE_TOKEN=xxx GITCODE_VERSION=v1.5.3 python3 sync_gitcode.py
在 APRSLocus 仓库根目录运行（含 APRSLocus-Windows/*.exe 和 APRSLocus-Android/*.apk）。

设计原则：
- 每个文件上传前独立重新获取 upload_url（不缓存，避免会话失效）
- 大文件使用长超时（APK 30 分钟、EXE 10 分钟），支持自动重试
- 失败不阻塞：附件传不上仍保留源码包，输出提示手动上传
"""
import os
import sys
import json
import glob
import time
import urllib.request
import urllib.parse
import urllib.error

TOKEN = os.environ.get("GITCODE_TOKEN", "")
OWNER = "DarionDong"
REPO = "APRSLocus"
# 优先用显式版本（GITCODE_VERSION），回退 GITHUB_REF_NAME
VERSION = os.environ.get("GITCODE_VERSION", "") or os.environ.get("GITHUB_REF_NAME", "")
SHA = os.environ.get("GITHUB_SHA", "")
API = f"https://api.gitcode.com/api/v5/repos/{OWNER}/{REPO}"
AUTH = {"private-token": TOKEN}

# 每个文件的上传超时（秒）。GitHub Runner → GitCode OBS 跨网慢，需足够长。
EXE_TIMEOUT = 600
APK_TIMEOUT = 1800
# 单个文件最大重试次数（含重新获取 upload_url）
MAX_RETRY = 3


def call(url, data=None, method="GET", headers=None, timeout=300):
    req = urllib.request.Request(url, data=data, method=method, headers=headers or {})
    try:
        resp = urllib.request.urlopen(req, timeout=timeout)
        return resp.status, resp.read()
    except urllib.error.HTTPError as e:
        return e.code, e.read()
    except Exception as e:
        return -1, str(e).encode()


def create_release():
    print(f"创建 GitCode Release {VERSION} ...")
    st, resp = call(f"{API}/releases/tags/{VERSION}", headers=AUTH)
    if st == 200:
        print("GitCode Release 已存在")
        return
    payload = json.dumps({
        "tag_name": VERSION,
        "name": VERSION,
        "body": f"APRSLocus {VERSION}",
        "target_commitish": SHA,
        "prerelease": False,
    }).encode()
    st, resp = call(f"{API}/releases", payload, "POST", {
        "Content-Type": "application/json;charset=UTF-8",
        "private-token": TOKEN,
    })
    print("创建结果:", st)
    if st not in (200, 201):
        print(resp[:500])
        raise SystemExit("创建 GitCode Release 失败")


def upload(path):
    """上传单个文件：每个文件独立获取 upload_url，失败重试。"""
    filename = os.path.basename(path)
    size = os.path.getsize(path)
    timeout = APK_TIMEOUT if filename.lower().endswith(".apk") else EXE_TIMEOUT

    for attempt in range(1, MAX_RETRY + 1):
        print(f"[尝试 {attempt}/{MAX_RETRY}] 获取上传地址: {filename} ({size} bytes) ...")
        q = urllib.parse.urlencode({"file_name": filename, "file_size": size})
        st, resp = call(f"{API}/releases/{VERSION}/upload_url?{q}", headers=AUTH, timeout=60)
        if st != 200:
            print(f"获取上传地址失败 HTTP {st}: {resp[:300]}")
            if attempt < MAX_RETRY:
                time.sleep(5)
                continue
            return False
        info = json.loads(resp)
        with open(path, "rb") as f:
            data = f.read()
        print(f"上传: {filename} (超时 {timeout}s) ...")
        st, resp = call(info["url"], data, "PUT", info.get("headers", {}), timeout=timeout)
        print(f"上传结果: {filename} HTTP {st}")
        if st in (200, 201):
            return True
        print(f"上传失败: {resp[:300]}")
        if attempt < MAX_RETRY:
            print("等待 10s 后重试 ...")
            time.sleep(10)
    return False


def main():
    if not TOKEN:
        print("GITCODE_TOKEN 未配置，跳过 GitCode 同步")
        return
    if not VERSION:
        print("GITCODE_VERSION / GITHUB_REF_NAME 为空，跳过")
        return
    create_release()
    failed = []
    # 尽力上传 apk/exe；失败不阻塞（保留源码包，用户可手动上传）
    for pat in ("APRSLocus-Windows/*.exe", "APRSLocus-Android/*.apk"):
        for p in sorted(glob.glob(pat)):
            if not upload(p):
                failed.append(os.path.basename(p))
    if failed:
        print(f"上传失败，请手动上传: {', '.join(failed)}")
    print("GitCode Release 同步完成（附件如失败可手动上传）")


if __name__ == "__main__":
    sys.exit(main())
