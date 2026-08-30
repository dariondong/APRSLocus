#!/usr/bin/env python3
"""同步 GitHub Actions 构建的发行包到 GitCode Releases。

用法：GITCODE_TOKEN=xxx GITHUB_REF_NAME=v1.5.3 python3 sync_gitcode.py
在 APRSLocus 仓库根目录运行（含 APRSLocus-Windows/*.exe 和 APRSLocus-Android/*.apk）。
"""
import os
import sys
import json
import glob
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
    filename = os.path.basename(path)
    size = os.path.getsize(path)
    print(f"获取上传地址: {filename} ({size} bytes) ...")
    q = urllib.parse.urlencode({"file_name": filename, "file_size": size})
    st, resp = call(f"{API}/releases/{VERSION}/upload_url?{q}", headers=AUTH, timeout=30)
    if st != 200:
        print(resp[:500])
        return False
    info = json.loads(resp)
    print(f"上传: {filename} ...")
    with open(path, "rb") as f:
        data = f.read()
    # OBS 上传慢：短超时 45s，失败跳过不阻塞（用户可手动上传）
    st, resp = call(info["url"], data, "PUT", info.get("headers", {}), timeout=45)
    print(f"上传结果: {filename} HTTP {st}")
    if st not in (200, 201):
        print(resp[:500])
        return False
    return True


def main():
    if not TOKEN:
        print("GITCODE_TOKEN 未配置，跳过 GitCode 同步")
        return
    if not VERSION:
        print("GITHUB_REF_NAME 为空，跳过")
        return
    create_release()
    # 尽力上传 apk/exe；GitCode OBS 上传慢，超时/失败不阻塞（保留源码包）
    for pat in ("APRSLocus-Windows/*.exe", "APRSLocus-Android/*.apk"):
        for p in sorted(glob.glob(pat)):
            if not upload(p):
                print(f"警告: {os.path.basename(p)} 上传失败，请手动上传")
    print("GitCode Release 同步完成（附件如失败可手动上传）")


if __name__ == "__main__":
    sys.exit(main())
