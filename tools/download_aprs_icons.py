# -*- coding: utf-8 -*-
"""下载完整 APRS 官方符号图标集（37 个符号表）到 assets/aprs_syms（多线程）"""
import os
import sys
import threading
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed

BASE = "https://aprs.tv/img"
DST = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "aprs_syms"))
THREADS = 16

# 官方 37 个符号表字符的 ASCII 码
TABLES = [0x2f] + [0x5c] + list(range(0x30, 0x3a)) + list(range(0x41, 0x5b))
# 符号码范围 0x21('!') ~ 0x7e('~')
CODES = list(range(0x21, 0x7f))

_lock = threading.Lock()
ok = skip = fail = 0


def fetch(name):
    global ok, skip, fail
    path = os.path.join(DST, name)
    if os.path.exists(path):
        with _lock:
            skip += 1
        return
    url = "%s/%s" % (BASE, name)
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        data = urllib.request.urlopen(req, timeout=10).read()
        if not data.startswith(b"\x89PNG\r\n\x1a\n"):
            with _lock:
                fail += 1
            print("SKIP bad magic: %s" % name)
            return
        with open(path, "wb") as f:
            f.write(data)
        with _lock:
            ok += 1
        print("OK  %s  (%d bytes)" % (name, len(data)))
    except Exception as e:
        with _lock:
            fail += 1
        print("FAIL %s  %s" % (name, e))


def main():
    os.makedirs(DST, exist_ok=True)
    tasks = []
    for table in TABLES:
        for code in CODES:
            tasks.append("%02x%02x.png" % (table, code))
    with ThreadPoolExecutor(max_workers=THREADS) as ex:
        for _ in as_completed([ex.submit(fetch, t) for t in tasks]):
            pass
    print("done: ok=%d skip=%d fail=%d  dst=%s" % (ok, skip, fail, DST))


if __name__ == "__main__":
    sys.exit(main())
