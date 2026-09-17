#!/usr/bin/env python3
"""查 APRSLocus 的 GitHub Actions 运行状态（不依赖 gh CLI，只用 REST API）。

用法：
    python3 tool/ci_status.py                 # 最近 6 次运行摘要
    python3 tool/ci_status.py 167da32         # 只看某个 commit 前缀
    python3 tool/ci_status.py --watch 35178547536   # 等某个 run 跑完并打印各 job

为什么单独写成脚本：之前用 `echo "$JSON" | python3 -c ...` 一行流时，GitHub
返回的大 JSON 里含控制字符（job 日志摘要里的换行），`json.load` 严格模式会抛
"Invalid control character"，于是把真正的状态信息淹没在一屏 traceback 里。
这里改成写临时文件 + strict=False 解析，并把网络错误和 JSON 错误分开报告。
"""
import io
import json
import os
import re
import subprocess
import sys
import time

REPO = "dariondong/APRSLocus"


def token() -> str:
    """从 ~/.git-credentials 取 PAT（与项目其它脚本一致，不引入新依赖）。"""
    path = os.path.expanduser("~/.git-credentials")
    with io.open(path, encoding="utf-8") as f:
        m = re.search(r"://[^:]*:([^@]*)@", f.read())
    if not m:
        sys.exit("无法从 ~/.git-credentials 解析出 token")
    return m.group(1)


def api(path: str):
    out = subprocess.run(
        ["curl", "-sS", "-H", f"Authorization: Bearer {token()}",
         "-H", "Accept: application/vnd.github+json",
         f"https://api.github.com/repos/{REPO}/{path}"],
        capture_output=True, text=True, check=True,
    ).stdout
    try:
        # strict=False：容忍控制字符
        return json.loads(out, strict=False)
    except json.JSONDecodeError as e:
        sys.exit(f"JSON 解析失败（{e}）。原始响应前 300 字：\n{out[:300]}")


def summarize(runs):
    for r in runs:
        conc = r.get("conclusion") or "-"
        mark = {"success": "✅", "failure": "❌", "cancelled": "⚪"}.get(conc, "⏳")
        print(f"{mark} {r['name']:20} {r['head_branch']:6} {r['head_sha'][:8]} "
              f"{r['status']:12} {conc}")
        print(f"     {r['html_url']}")


def show_jobs(run_id: int):
    data = api(f"actions/runs/{run_id}/jobs")
    worst = "success"
    for j in data.get("jobs", []):
        conc = j.get("conclusion")
        print(f"  {j['name']:22} {j['status']:12} {conc}")
        for s in j.get("steps", []):
            if s.get("conclusion") not in (None, "success", "skipped"):
                print(f"      ✗ {s['name']}: {s['conclusion']}")
        if conc == "failure":
            worst = "failure"
        elif conc not in ("success", "skipped") and worst != "failure":
            worst = "in_progress"
    return worst


def main():
    args = sys.argv[1:]
    if args and args[0] == "--watch":
        run_id = int(args[1])
        for _ in range(80):
            r = api(f"actions/runs/{run_id}")
            st = f"{r['status']} {r.get('conclusion')}"
            print(f"[{time.strftime('%H:%M:%S')}] {r['name']}: {st}")
            if r["status"] == "completed":
                break
            time.sleep(30)
        print("--- jobs ---")
        sys.exit(0 if show_jobs(run_id) == "success" else 1)

    sha_filter = args[0] if args else None
    runs = api("actions/runs?per_page=12").get("workflow_runs", [])
    if sha_filter:
        runs = [r for r in runs if r["head_sha"].startswith(sha_filter)]
    summarize(runs)
    running = [r for r in runs if r["status"] != "completed"]
    for r in running:
        print(f"--- jobs of {r['id']} (running) ---")
        show_jobs(r["id"])
    return 0


if __name__ == "__main__":
    sys.exit(main())
