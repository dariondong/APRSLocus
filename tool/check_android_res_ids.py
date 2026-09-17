#!/usr/bin/env python3
"""静态校验：Android 侧 ResId 引用是否都能落地。

**为什么需要这个脚本**：Kotlin 里写错一个 ResId 名字（`R.id.aw_tip4_box`、
`R.drawable.aw_bg_rainy`）是**编译期**错误，CI 能拦；但本机/改动者手上如果
没有 Android SDK，就只能等 CI 跑完才知道 —— 而这个项目的 CI 要构建
Windows + Android 两端，反馈周期很长。

真正危险的是 `RemoteViews.setInt(viewId, "setBackgroundResource", resId)`
这类**字符串方法名**调用：ResId 按构造是合法的，把 drawable 名写进字符串里
编译器不会检查，跑起来才在系统进程里抛
`ClassNotFoundException/NoSuchMethodException`，表现是组件变白块。

所以这里做一遍机械核对：Kotlin 中出现的每个 `R.<type>.<name>`，
以及 `setBackgroundResource` / `setBackgroundColor` / `setTextColor`
附近的 `R.drawable.*`，都必须能在 res/ 或 AndroidManifest.xml 里找到。

用法：
    python3 tool/check_android_res_ids.py

退出码：0 = 全部对得上；1 = 有对不上的引用（会逐条列出）
"""

import os
import re
import sys
import glob
import xml.etree.ElementTree as ET

ANDROID = "http://schemas.android.com/apk/res/android"


def collect_resources(res_dir: str) -> dict:
    """扫 res/ 收集各类资源名 → 定义位置列表。"""
    found: dict[str, list[str]] = {}

    def add(kind: str, name: str, where: str):
        found.setdefault(f"{kind}/{name}", []).append(where)

    for path in glob.glob(os.path.join(res_dir, "**", "*.xml"), recursive=True):
        rel = os.path.relpath(path, res_dir)
        qualifier = os.path.basename(os.path.dirname(rel))  # drawable-night 等
        base = qualifier.split("-")[0]
        stem = os.path.splitext(os.path.basename(rel))[0]

        if base == "layout":
            add("layout", stem, rel)
        elif base == "drawable":
            add("drawable", stem, rel)
        elif base == "xml":
            add("xml", stem, rel)

        # 文件内部的 @+id/xxx
        try:
            text = open(path, encoding="utf-8").read()
        except OSError:
            continue
        for m in re.finditer(r'@\+id/(\w+)', text):
            add("id", m.group(1), rel)

        # values*/strings.xml 里的 <string name="xxx">
        if base == "values" and stem == "strings":
            try:
                root = ET.parse(path).getroot()
            except ET.ParseError:
                continue
            for el in root.findall("string"):
                n = el.get("name")
                if n:
                    add("string", n, rel)

    return found


def collect_kotlin_refs(kotlin_dir: str) -> list[tuple[str, str, str]]:
    """扫 Kotlin 收集 (type, name, file:line)。"""
    refs = []
    # 负向后顾 (?<![.\w]) 是必需的：`android.R.drawable.ic_dialog_email` 里的
    # `R.drawable.…` 也会被裸正则匹配到，但那是指系统框架资源（android.R），
    # 不该拿去和本应用的 res/ 对账 —— 否则每次都会报 4 条假失败。
    pattern = re.compile(r"(?<![.\w])R\.(id|drawable|layout|string|xml)\.(\w+)")
    for path in glob.glob(os.path.join(kotlin_dir, "**", "*.kt"), recursive=True):
        with open(path, encoding="utf-8") as f:
            for lineno, line in enumerate(f, 1):
                # 跳过注释行，避免注释里的示例被当成真引用
                stripped = line.strip()
                if stripped.startswith("//") or stripped.startswith("*"):
                    continue
                for m in pattern.finditer(line):
                    refs.append(
                        (m.group(1), m.group(2), f"{os.path.basename(path)}:{lineno}")
                    )
    return refs


def check_remoteviews_string_methods(kotlin_dir: str) -> list[str]:
    """核对 setBackgroundResource/setTextColor 这类「字符串方法名」调用。

    RemoteViews.setInt(viewId, "setBackgroundResource", res) 里的方法名如果
    拼错，编译能过、运行时才在系统进程里炸。这里只用一张白名单挡住明显的笔误
    —— 真正的方法集合由 RemoteViews 反射决定，静态核不全，但能拦住拼写错误。
    """
    # RemoteViews 在 API 31 上真实支持、且本项目会用到的 @RemotableViewMethod
    allowed = {
        "setBackgroundResource",
        "setBackgroundColor",
        "setTextColor",
        "setTextSize",
        "setViewVisibility",
        "setImageViewResource",
        "setOnClickPendingIntent",
        "setContentDescription",
    }
    problems = []
    call = re.compile(r'setInt\([^,]+,\s*"(\w+)"')
    for path in glob.glob(os.path.join(kotlin_dir, "**", "*.kt"), recursive=True):
        with open(path, encoding="utf-8") as f:
            for lineno, line in enumerate(f, 1):
                if line.strip().startswith("//"):
                    continue
                for m in call.finditer(line):
                    if m.group(1) not in allowed:
                        problems.append(
                            f"{os.path.basename(path)}:{lineno} "
                            f"RemoteViews.setInt(\"{m.group(1)}\") 不在已知可用的方法白名单里"
                        )
    return problems


def main() -> int:
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    res_dir = os.path.join(root, "android", "app", "src", "main", "res")
    kotlin_dir = os.path.join(root, "android", "app", "src", "main", "kotlin")
    manifest = os.path.join(
        root, "android", "app", "src", "main", "AndroidManifest.xml"
    )

    if not os.path.isdir(res_dir):
        print(f"找不到 res 目录：{res_dir}", file=sys.stderr)
        return 2

    resources = collect_resources(res_dir)
    refs = collect_kotlin_refs(kotlin_dir)

    missing = []
    for kind, name, where in refs:
        if f"{kind}/{name}" not in resources:
            missing.append(f"  ✗ R.{kind}.{name}  （来自 {where}）")

    print(f"Kotlin 引用的资源：{len(refs)} 处（去重后 {len({(k, n) for k, n, _ in refs})} 个）")
    print(f"res/ 中可用的资源：{len(resources)} 个")

    # 布局里引用的 @drawable/@string 也要能落地（漏了就是运行时白块）
    layout_missing = []
    for path in glob.glob(os.path.join(res_dir, "layout", "*.xml")):
        text = open(path, encoding="utf-8").read()
        for m in re.finditer(r'@(drawable|string|xml)/(\w+)', text):
            if f"{m.group(1)}/{m.group(2)}" not in resources:
                layout_missing.append(
                    f"  ✗ @{m.group(1)}/{m.group(2)}  "
                    f"（来自 layout/{os.path.basename(path)}）"
                )

    # 清单里的组件类必须真的有对应 .kt
    manifest_missing = []
    if os.path.exists(manifest):
        mtext = open(manifest, encoding="utf-8").read()
        for m in re.finditer(r'android:name="\.(\w+)"', mtext):
            cls = m.group(1)
            if not os.path.exists(os.path.join(kotlin_dir, "com", "aprslocus",
                                               "aprslocus", f"{cls}.kt")):
                manifest_missing.append(f"  ✗ 清单里声明了 .{cls}，但找不到 {cls}.kt")

    remote_problems = check_remoteviews_string_methods(kotlin_dir)

    ok = True
    for title, items in (
        ("Kotlin 引用了不存在的资源", missing),
        ("布局里引用了不存在的资源", layout_missing),
        ("清单里的组件类找不到实现", manifest_missing),
        ("RemoteViews 字符串方法名可疑", remote_problems),
    ):
        if items:
            ok = False
            print(f"\n{title}：")
            print("\n".join(items))

    print()
    print("✅ 全部对得上" if ok else "❌ 有对不上的引用（见上）")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
