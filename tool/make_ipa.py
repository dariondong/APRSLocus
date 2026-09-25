"""把 iOS 的 .app 封成未签名 .ipa（不签名，也不用 Xcode 的 exportArchive）。

用法：
  python3 tool/make_ipa.py                       # 自动找 build/ios/iphoneos/*.app
  python3 tool/make_ipa.py <某个 .app 或它的父目录>
  python3 tool/make_ipa.py build/ios/iphoneos -o build/ios/ipa/APRSLocus_1.6.178.ipa

为什么是「自己封」而不是 `flutter build ipa`
------------------------------------------
`flutter build ipa` 的导出那一步要签名（要 Apple 开发者账号 + 证书 + 描述文件），
本仓库两个都没有；`--no-codesign` 只到 .xcarchive 为止，不产 .ipa。
而未签名 .ipa 恰恰是 TrollStore / sideloadly / AltStore 这类自签工具的入口
（它们拿到包之后用**用户自己的**证书重签），所以这一步我们自己来做。

为什么是 Python 而不是 `zip` 命令
--------------------------------
本机（开发容器）没有 zip/unzip 二进制，只有 Python；CI 的 macOS runner 两样都有。
写成 Python 之后，**本机、CI 检查、发版 job 跑的是同一份代码** ——
否则「检查通过」只证明那段检查代码对，证明不了发版时真正跑的那条命令对。

一个合法 IPA 的判据（官方产物也就是这样一个 zip）
-----------------------------------------------
1. 顶层目录叫 `Payload`；
2. `Payload/` 里恰好一个 `<名字>.app`；
3. 该 .app 里有 Info.plist，且 CFBundleExecutable 指向的文件存在且**有执行位**
   （少了执行位，装上去点开就闪退，而这在 CI 里完全看不出来）。

顺带把执行位与符号链接原样保住：.app 里全是 Mach-O 二进制（Flutter.framework 等），
执行位丢了就是「装得上、打不开」。
"""
import argparse
import os
import plistlib
import stat
import sys
import zipfile

PAYLOAD_DIR = "Payload"
DEFAULT_APP_ROOT = os.path.join("build", "ios", "iphoneos")


def fail(msg):
    print("ERROR: %s" % msg)
    sys.exit(1)


def find_app(root):
    """在 root 下找唯一一个 .app 目录（只看一层）。"""
    if not os.path.isdir(root):
        fail("找不到目录：%s" % root)
    apps = sorted(
        d
        for d in os.listdir(root)
        if d.endswith(".app") and os.path.isdir(os.path.join(root, d))
    )
    if not apps:
        fail("%s 下没有 .app（iOS 构建产物通常叫 Runner.app）" % root)
    if len(apps) > 1:
        fail("%s 下有多个 .app，无法判断封哪个：%s" % (root, ", ".join(apps)))
    return os.path.join(root, apps[0])


def add_path(zf, src, arcname):
    """把一个文件/目录写进 zip；保留执行位，符号链接按符号链接存。

    用 os.lstat 而不是 os.path.islink，是为了只 stat 一次、且对符号链接不跟随。
    """
    st = os.lstat(src)

    if stat.S_ISLNK(st.st_mode):
        info = zipfile.ZipInfo(arcname)
        info.create_system = 3  # 3 = Unix，读的人才会去看 external_attr
        info.external_attr = (stat.S_IFLNK | 0o777) << 16
        info.compress_type = zipfile.ZIP_STORED
        zf.writestr(info, os.readlink(src))
        return

    if stat.S_ISDIR(st.st_mode):
        info = zipfile.ZipInfo(arcname + "/")
        info.create_system = 3
        info.external_attr = (stat.S_IFDIR | 0o755) << 16
        info.compress_type = zipfile.ZIP_STORED
        zf.writestr(info, b"")
        for name in sorted(os.listdir(src)):
            add_path(zf, os.path.join(src, name), arcname + "/" + name)
        return

    # 普通文件：zf.write 会把 st_mode 写进 external_attr，执行位自然保住
    zf.write(src, arcname, zipfile.ZIP_DEFLATED)


def read_plist(app_dir, name):
    path = os.path.join(app_dir, name)
    if not os.path.isfile(path):
        fail("%s 里没有 %s，不像一个 .app" % (app_dir, name))
    try:
        with open(path, "rb") as f:
            return plistlib.load(f)
    except Exception as exc:  # noqa: BLE001 - 报清楚是哪个文件坏了就够了
        fail("%s 解析失败：%s" % (path, exc))


def build_ipa(app_dir, out_path):
    app_name = os.path.basename(app_dir)
    plist = read_plist(app_dir, "Info.plist")

    exe = plist.get("CFBundleExecutable")
    if not exe:
        fail("%s/Info.plist 没有 CFBundleExecutable" % app_dir)
    exe_path = os.path.join(app_dir, exe)
    if not os.path.isfile(exe_path):
        fail("Info.plist 指向的可执行文件不存在：%s" % exe_path)
    if not os.access(exe_path, os.X_OK):
        fail("可执行文件没有执行位（装上去会闪退）：%s" % exe_path)

    version = plist.get("CFBundleShortVersionString") or "unknown"
    build = plist.get("CFBundleVersion") or "?"
    bundle_id = plist.get("CFBundleIdentifier") or "?"

    # 用临时文件 + os.replace：中途失败时不会留下一个「像成品」的半包
    tmp_path = out_path + ".tmp"
    os.makedirs(os.path.dirname(os.path.abspath(out_path)), exist_ok=True)
    try:
        with zipfile.ZipFile(tmp_path, "w", zipfile.ZIP_DEFLATED) as zf:
            add_path(zf, app_dir, "%s/%s" % (PAYLOAD_DIR, app_name))

        # 封完立刻读回来自检：结构不对就不许把它当成品交出去
        with zipfile.ZipFile(tmp_path) as zf:
            names = zf.namelist()
            info_entry = "%s/%s/Info.plist" % (PAYLOAD_DIR, app_name)
            if info_entry not in names:
                fail("封出来的 IPA 里缺 %s" % info_entry)
            for n in names:
                if n.startswith("/") or ".." in n.split("/"):
                    fail("IPA 里有不安全的条目名：%s" % n)
            if len(names) < 2:
                fail("封出来的 IPA 只有 %d 个条目，明显不对" % len(names))

        os.replace(tmp_path, out_path)
    finally:
        if os.path.exists(tmp_path):
            os.remove(tmp_path)

    size = os.path.getsize(out_path)
    if size <= 0:
        fail("产物是空的：%s" % out_path)

    print("IPA 已生成：%s" % out_path)
    print("  app        : %s" % app_name)
    print("  bundle id  : %s" % bundle_id)
    print("  version    : %s (%s)" % (version, build))
    print("  大小       : %.1f MB" % (size / 1024.0 / 1024.0))
    print("  签名       : 无（用 TrollStore / sideloadly / AltStore 自签安装）")
    return out_path


def main():
    parser = argparse.ArgumentParser(
        description="把 iOS .app 封成未签名 .ipa（不依赖 zip 命令）"
    )
    parser.add_argument(
        "app",
        nargs="?",
        default=DEFAULT_APP_ROOT,
        help=".app 路径，或放着 .app 的目录（默认 %s）" % DEFAULT_APP_ROOT,
    )
    parser.add_argument(
        "-o", "--out", default=None, help="输出 .ipa 路径（默认放在 .app 旁边）"
    )
    args = parser.parse_args()

    if os.path.isdir(args.app) and args.app.endswith(".app"):
        app_dir = args.app
    elif os.path.isdir(args.app):
        app_dir = find_app(args.app)
    else:
        fail("路径不存在：%s" % args.app)

    out_path = args.out
    if not out_path:
        plist = read_plist(app_dir, "Info.plist")
        version = plist.get("CFBundleShortVersionString") or "unknown"
        out_path = os.path.join(
            os.path.dirname(os.path.abspath(app_dir)),
            "APRSLocus_%s_unsigned.ipa" % version,
        )

    build_ipa(app_dir, out_path)


if __name__ == "__main__":
    main()
