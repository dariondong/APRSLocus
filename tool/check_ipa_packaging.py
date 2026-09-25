"""CI 检查：IPA 封包真的能用，且真的接进了 Release。

为什么要有这一条
----------------
「iOS 会出一个 .ipa」这件事**不会让任何编译或测试失败**。它失败起来的样子是：
发版 job 全绿、Release 正常创建，但 Release 页上**一个 iOS 资产都没有**。

这不是假设：v1.6.175 / v1.6.176 / v1.6.177 的 Release 就**只有 .apk 与 .exe**
（`files:` 里写的 `APRSLocus-iOS/*.app` 是个**目录**，action-gh-release 对目录是
静默跳过，而整条流水线全绿）。同类坑还有第二个：upload-artifact 对**多路径**
会取公共祖先当根目录，于是包内多一层 `ipa/`，Release 那边写的 `*.ipa` 同样匹配不到。

所以这里钉两件事：

  A. 真跑一遍 tool/make_ipa.py（造一个忠实的最小 Runner.app），断言封出来的 IPA
     结构对：Payload 顶层、Info.plist、执行位、符号链接、可读回；并断言坏输入会报错；
  B. 断言 build-release.yml 里 IPA 的 artifact 名 + 包内形状 + Release glob
     三者对得上，且不再依赖裸 `*.app`。

用法：python3 tool/check_ipa_packaging.py
"""
import os
import plistlib
import re
import shutil
import stat
import subprocess
import sys
import tempfile
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MAKE_IPA = os.path.join(ROOT, "tool", "make_ipa.py")
BUILD_RELEASE = os.path.join(ROOT, ".github", "workflows", "build-release.yml")

failures = []


def ok(msg):
    print("  ok  %s" % msg)


def bad(msg):
    failures.append(msg)
    print("  FAIL %s" % msg)


def check(cond, msg):
    if cond:
        ok(msg)
    else:
        bad(msg)
    return cond


# --------------------------------------------------------------------------
# 造样本：一个忠实的最小 Runner.app
# --------------------------------------------------------------------------
def make_app(app_dir, exe="Runner", extra_app=False):
    os.makedirs(os.path.join(app_dir, "Frameworks", "App.framework"), exist_ok=True)
    os.makedirs(os.path.join(app_dir, "Frameworks", "Flutter.framework", "Headers"))
    os.makedirs(os.path.join(app_dir, "Base.lproj", "Main.storyboardc"))
    os.makedirs(os.path.join(app_dir, "_CodeSignature"))
    os.makedirs(os.path.join(app_dir, "empty_dir"))

    plist = {
        "CFBundleExecutable": exe,
        "CFBundleIdentifier": "com.aprslocus.aprslocus",
        "CFBundleShortVersionString": "9.9.9",
        "CFBundleVersion": "90909",
        "CFBundlePackageType": "APPL",
    }
    # 二进制 plist：Xcode 编出来的就是二进制，顺带验了 plistlib 的读法
    with open(os.path.join(app_dir, "Info.plist"), "wb") as f:
        plistlib.dump(plist, f, fmt=plistlib.FMT_BINARY)

    def exe_file(path):
        with open(path, "wb") as f:
            f.write(b"\xcf\xfa\xed\xfe" + b"\x00" * 64)
        os.chmod(path, 0o755)

    def plain(path, data=b"x"):
        with open(path, "wb") as f:
            f.write(data)

    exe_file(os.path.join(app_dir, exe))
    exe_file(os.path.join(app_dir, "Frameworks", "App.framework", "App"))
    exe_file(os.path.join(app_dir, "Frameworks", "Flutter.framework", "Flutter"))
    plain(os.path.join(app_dir, "Frameworks", "App.framework", "Info.plist"), b"plist")
    plain(os.path.join(app_dir, "Frameworks", "Flutter.framework", "Headers", "Flutter.h"))
    plain(os.path.join(app_dir, "Base.lproj", "Main.storyboardc", "Main.nib"))
    plain(os.path.join(app_dir, "_CodeSignature", "CodeResources"))
    plain(os.path.join(app_dir, "PkgInfo"), b"APPL????")

    # 符号链接：真 .app 里可能出现，丢了会变成「多塞一份内容」或装不上
    os.symlink("App", os.path.join(app_dir, "Frameworks", "App.framework", "App_alias"))

    if extra_app:
        other = os.path.join(os.path.dirname(app_dir), "Other.app")
        os.makedirs(other, exist_ok=True)
        plain(os.path.join(other, "Info.plist"), b"x")


def run_make_ipa(app_root, out, expect_ok=True):
    proc = subprocess.run(
        [sys.executable, MAKE_IPA, app_root, "-o", out],
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
    )
    if expect_ok:
        check(
            proc.returncode == 0,
            "make_ipa.py 正常退出"
            if proc.returncode == 0
            else "make_ipa.py 本该成功却 rc=%d：\n%s" % (proc.returncode, proc.stdout),
        )
    else:
        check(
            proc.returncode != 0,
            "坏输入下 make_ipa.py 报错退出"
            if proc.returncode != 0
            else "坏输入下 make_ipa.py 却返回了 0（检查不会开火）",
        )
    return proc


def entry_mode(info):
    """取 zip 条目的 Unix 权限位（external_attr 高 16 位）。"""
    return (info.external_attr >> 16) & 0xFFFF


def check_ipa_structure(ipa, app_name="Runner.app"):
    with zipfile.ZipFile(ipa) as zf:
        infos = {i.filename: i for i in zf.infolist()}
        names = list(infos)

        check(
            "Payload/%s/Info.plist" % app_name in names,
            "IPA 里有 Payload/%s/Info.plist" % app_name,
        )
        check(
            "Payload/%s/Frameworks/Flutter.framework/Flutter" % app_name in names,
            "IPA 里保留了 Flutter.framework 内的二进制",
        )
        check("Payload/Runner.app/empty_dir/" in names, "空目录没有被丢掉")

        tops = {n.split("/")[0] for n in names}
        check(tops == {"Payload"}, "顶层目录只有 Payload（实际 %s）" % sorted(tops))

        unsafe = [n for n in names if n.startswith("/") or ".." in n.split("/")]
        check(not unsafe, "没有绝对路径/上跳条目（zip-slip）")
        check(not [n for n in names if n.startswith("__MACOSX")], "没混进 __MACOSX")

        exe_name = "Payload/%s/Runner" % app_name
        if check(exe_name in names, "主可执行文件在包里"):
            mode = entry_mode(infos[exe_name])
            check(
                (mode & stat.S_IXUSR) == stat.S_IXUSR,
                "主可执行文件保住了执行位（mode=%o）" % mode,
            )

        alias = "Payload/%s/Frameworks/App.framework/App_alias" % app_name
        if check(alias in names, "符号链接条目在包里"):
            check(
                stat.S_ISLNK(entry_mode(infos[alias])),
                "符号链接按符号链接存（不是复制一份内容）",
            )

        # 内容能读回来 = 没损坏
        with zf.open("Payload/%s/Info.plist" % app_name) as f:
            got = plistlib.load(f)
        check(
            got.get("CFBundleShortVersionString") == "9.9.9",
            "包里的 Info.plist 能解析且版本号对",
        )


def check_workflow():
    """B. build-release.yml 的接线。"""
    if not os.path.isfile(BUILD_RELEASE):
        bad("找不到 %s" % BUILD_RELEASE)
        return
    with open(BUILD_RELEASE, encoding="utf-8") as f:
        text = f.read()

    check("tool/make_ipa.py" in text, "发版流程真的调用了 tool/make_ipa.py")
    check(
        "if-no-files-found: error" in text,
        "上传步骤带 if-no-files-found: error（否则「没产出」也算成功）",
    )

    # artifact 的包内形状：upload-artifact 对**多路径**会取公共祖先当根目录，
    # 于是包内变成 `ipa/x.ipa`，Release 的 `APRSLocus-iOS/*.ipa` 就匹配不到。
    # 所以钉死：装 .ipa 的那个 artifact 必须是单路径 `build/ios/ipa/*.ipa`。
    check(
        re.search(r"(?m)^\s*path: build/ios/ipa/\*\.ipa\s*$", text) is not None,
        "IPA 以单路径 build/ios/ipa/*.ipa 上传（多路径会让包内多一层 ipa/，Release 就取不到）",
    )

    m = re.search(r"\n(\s*)files: \|\n((?:\1\s+\S.*\n)+)", text)
    if check(m is not None, "能找到 Create Release 的 files: 段"):
        block = m.group(2)
        check(
            "APRSLocus-iOS/*.ipa" in block,
            "Release 的 files: 写的是 APRSLocus-iOS/*.ipa（与 artifact 名 + 包内形状对得上）",
        )
        check(
            re.search(r"\*\.app\b", block) is None,
            "Release 的 files: 里不再有裸 *.app（目录 attach 不上去，是静默失效）",
        )


def main():
    print("== A. IPA 封包（真跑 tool/make_ipa.py） ==")
    tmp = tempfile.mkdtemp(prefix="ipa_check_")
    try:
        root = os.path.join(tmp, "iphoneos")
        make_app(os.path.join(root, "Runner.app"))
        ipa = os.path.join(tmp, "out.ipa")
        run_make_ipa(root, ipa)
        if os.path.isfile(ipa):
            check_ipa_structure(ipa)
        else:
            bad("make_ipa.py 没有产出文件")

        print("")
        print("== A2. 坏输入必须报错（证明它会开火） ==")

        # 正向对照：同一套造样本 + 调用写法，好输入必须能过。
        # 少了它，下面即便全报错也可能只是 harness 坏了，证明不了检查会开火。
        control = os.path.join(tmp, "control")
        os.makedirs(control)
        make_app(os.path.join(control, "Runner.app"))
        run_make_ipa(control, os.path.join(control, "o.ipa"))

        # 没有 .app
        d = os.path.join(tmp, "neg_no_app")
        os.makedirs(d)
        run_make_ipa(d, os.path.join(d, "o.ipa"), expect_ok=False)

        # 多个 .app
        d = os.path.join(tmp, "neg_two_apps")
        os.makedirs(d)
        make_app(os.path.join(d, "Runner.app"), extra_app=True)
        run_make_ipa(d, os.path.join(d, "o.ipa"), expect_ok=False)

        # 缺 Info.plist
        d = os.path.join(tmp, "neg_no_plist")
        os.makedirs(d)
        make_app(os.path.join(d, "Runner.app"))
        os.remove(os.path.join(d, "Runner.app", "Info.plist"))
        run_make_ipa(d, os.path.join(d, "o.ipa"), expect_ok=False)

        # CFBundleExecutable 指向不存在的文件
        d = os.path.join(tmp, "neg_exe_missing")
        os.makedirs(d)
        make_app(os.path.join(d, "Runner.app"), exe="Nope")
        os.remove(os.path.join(d, "Runner.app", "Nope"))
        run_make_ipa(d, os.path.join(d, "o.ipa"), expect_ok=False)

        # 可执行文件没有执行位
        d = os.path.join(tmp, "neg_not_exec")
        os.makedirs(d)
        make_app(os.path.join(d, "Runner.app"))
        os.chmod(os.path.join(d, "Runner.app", "Runner"), 0o644)
        run_make_ipa(d, os.path.join(d, "o.ipa"), expect_ok=False)

        # Info.plist 是垃圾字节
        d = os.path.join(tmp, "neg_garbage_plist")
        os.makedirs(d)
        make_app(os.path.join(d, "Runner.app"))
        with open(os.path.join(d, "Runner.app", "Info.plist"), "wb") as f:
            f.write(b"not a plist at all")
        run_make_ipa(d, os.path.join(d, "o.ipa"), expect_ok=False)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    print("")
    print("== B. build-release.yml 的接线 ==")
    check_workflow()

    print("")
    if failures:
        print("IPA 打包检查失败 %d 项：" % len(failures))
        for f in failures:
            print("  - %s" % f)
        return 1
    print("IPA 打包检查全部通过")
    return 0


if __name__ == "__main__":
    sys.exit(main())
