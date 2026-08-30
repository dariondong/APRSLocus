"""同步版本号到 state.dart / pubspec.yaml / android/local.properties

用法：
  python tool/sync_version.py 1.4.5
  python tool/sync_version.py            # 从 pubspec.yaml 读取现有版本并同步到其余两处
"""
import io
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def read(path):
    with io.open(path, encoding="utf-8") as f:
        return f.read()


def write(path, text):
    with io.open(path, "w", encoding="utf-8", newline="") as f:
        f.write(text)


def main():
    pubspec = read(os.path.join(ROOT, "pubspec.yaml"))
    m = re.search(r"^version:\s*([0-9]+\.[0-9]+\.[0-9]+)(?:\+(\d+))?", pubspec, re.M)
    if not m:
        print("ERROR: cannot find version in pubspec.yaml")
        sys.exit(1)

    current, build = m.group(1), m.group(2) or "1"

    explicit = len(sys.argv) > 1
    if explicit:
        new = sys.argv[1].strip()
        if new.startswith("v"):
            new = new[1:]
        if not re.match(r"^\d+\.\d+\.\d+$", new):
            print("ERROR: invalid version '%s' (expect 1.2.3)" % new)
            sys.exit(1)
    else:
        new = current

    # 显式传版本（如打 tag 时）→ build 从 1 开始；无参（沿用当前）→ build 自增
    build = "1" if explicit else str(int(build) + 1)

    # versionCode 基于版本号计算，保证随版本单调递增（避免同版本或旧版本降级问题）
    # 例：1.4.9 → 10409，1.5.1 → 10501，1.15.3 → 11503
    parts = new.split(".")
    vc = int(parts[0]) * 10000 + int(parts[1]) * 100 + int(parts[2])
    version_code = str(vc)

    # 1) lib/state.dart
    state_path = os.path.join(ROOT, "lib", "state.dart")
    text = read(state_path)
    text = re.sub(
        r"static const appVersion = '[^']*';",
        "static const appVersion = '%s';" % new,
        text,
    )
    write(state_path, text)

    # 2) pubspec.yaml：build 号用 versionCode（Flutter 构建 APK 时用它作为 versionCode）
    text = read(os.path.join(ROOT, "pubspec.yaml"))
    text = re.sub(
        r"^version:.*$",
        "version: %s+%s" % (new, version_code),
        text,
        count=1,
        flags=re.M,
    )
    write(os.path.join(ROOT, "pubspec.yaml"), text)

    # 3) android/local.properties（CI 上可能不存在，flutter 会自动生成，跳过即可）
    lp_path = os.path.join(ROOT, "android", "local.properties")
    if os.path.exists(lp_path):
        text = read(lp_path)
        text = re.sub(
            r"flutter\.versionName=.*",
            "flutter.versionName=%s" % new,
            text,
        )
        text = re.sub(
            r"flutter\.versionCode=.*",
            "flutter.versionCode=%s" % version_code,
            text,
        )
        write(lp_path, text)

    print("version synced: %s+%s (versionCode %s)" % (new, build, version_code))


if __name__ == "__main__":
    main()
