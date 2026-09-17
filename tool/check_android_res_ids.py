#!/usr/bin/env python3
"""静态校验：Android 侧的资源引用是否都能落地。

**为什么需要这个脚本**：Kotlin 里写错一个 ResId 名字（`R.id.aw_tip4_box`、
`R.drawable.aw_bg_rainy`）是**编译期**错误，CI 能拦；但改动者手上如果
没有 Android SDK，就只能等 CI 跑完才知道 —— 而 CI 要构建 Windows + Android
两端，反馈周期很长。

真正危险的是另外两类**编译期全绿、运行时才炸**的问题：

  ① `RemoteViews.setInt(viewId, "setBackgroundResource", resId)` 这类
     **字符串方法名**调用 —— 方法名写错编译不报错，运行时才在系统进程里抛
     `NoSuchMethodException`，表现是组件变白块。

  ② **ResId 与布局配错**：把 `aw_t5_temp` 填进 tile 档的 IdS 表，那个 id
     在 aw_widget_tile.xml 里根本不存在 —— 编译期合法、运行时无声无息什么都
     不显示。四档布局 × 各自的 IdS 表，靠人眼核对必然出错，所以这里做机械核对。

用法：
    python3 tool/check_android_res_ids.py

退出码：0 = 全部对得上；1 = 有问题（逐条列出）
"""

import glob
import os
import re
import sys
import xml.etree.ElementTree as ET


def strip_kotlin_comments(src: str) -> str:
    """把 Kotlin 注释置空（保留行号）。

    必需 —— 本项目的注释里会**故意**写出 `setInt(viewId, "方法名", …)` 这类
    示例来说明约束。不先剥注释，检查器就会把自己的说明文档当成违规。
    这种假失败比真失败更坏：修它的人通常会去把说明删掉，约束就又没人记得了。
    """
    # 块注释 → 等量换行，保持行号不变
    src = re.sub(r"/\*.*?\*/",
                 lambda m: "\n" * m.group(0).count("\n"),
                 src, flags=re.S)
    # 行注释
    return re.sub(r"//[^\n]*", "", src)


def read_kotlin(path: str) -> str:
    with open(path, encoding="utf-8") as f:
        return strip_kotlin_comments(f.read())


def collect_resources(res_dir: str) -> dict:
    """扫 res/ 收集各类资源名 → 定义位置列表。"""
    found: dict[str, list[str]] = {}

    def add(kind: str, name: str, where: str):
        found.setdefault(f"{kind}/{name}", []).append(where)

    for path in glob.glob(os.path.join(res_dir, "**", "*.xml"), recursive=True):
        rel = os.path.relpath(path, res_dir)
        qualifier = os.path.basename(os.path.dirname(rel))
        base = qualifier.split("-")[0]
        stem = os.path.splitext(os.path.basename(rel))[0]

        if base in ("layout", "drawable", "xml"):
            add(base, stem, rel)

        try:
            text = open(path, encoding="utf-8").read()
        except OSError:
            continue
        for m in re.finditer(r"@\+id/(\w+)", text):
            add("id", m.group(1), rel)

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


def collect_kotlin_refs(kotlin_dir: str) -> list:
    """扫 Kotlin 收集 (type, name, file:line)。

    负向后顾 `(?<![.\\w])` 是必需的：`android.R.drawable.ic_dialog_email` 里的
    `R.drawable.…` 也会被裸正则匹配到，但那是指系统框架资源（android.R），
    不该拿去和本应用的 res/ 对账 —— 否则每次都会报 4 条假失败。
    """
    refs = []
    pattern = re.compile(r"(?<![.\w])R\.(id|drawable|layout|string|xml)\.(\w+)")
    for path in glob.glob(os.path.join(kotlin_dir, "**", "*.kt"), recursive=True):
        for lineno, line in enumerate(read_kotlin(path).splitlines(), 1):
            for m in pattern.finditer(line):
                refs.append((m.group(1), m.group(2),
                             f"{os.path.basename(path)}:{lineno}"))
    return refs


def check_layout_refs(res_dir: str, resources: dict) -> list:
    """布局里引用的 @drawable/@string/@xml 是否都存在。"""
    problems = []
    for path in glob.glob(os.path.join(res_dir, "layout", "*.xml")):
        text = open(path, encoding="utf-8").read()
        for m in re.finditer(r"@(drawable|string|xml)/(\w+)", text):
            if f"{m.group(1)}/{m.group(2)}" not in resources:
                problems.append(
                    f"  ✗ @{m.group(1)}/{m.group(2)}  "
                    f"（来自 layout/{os.path.basename(path)}）")
    return problems


def check_manifest(kotlin_dir: str, manifest: str) -> list:
    """清单里声明的组件类必须真的有对应 .kt"""
    problems = []
    if not os.path.exists(manifest):
        return problems
    with open(manifest, encoding="utf-8") as f:
        mtext = f.read()
    for m in re.finditer(r'android:name="\.(\w+)"', mtext):
        cls = m.group(1)
        if not os.path.exists(os.path.join(kotlin_dir, "com", "aprslocus",
                                           "aprslocus", f"{cls}.kt")):
            problems.append(f"  ✗ 清单里声明了 .{cls}，但找不到 {cls}.kt")
    return problems


# RemoteViews 里通过字符串方法名调用、且本项目会用到的白名单。
# 真正的可用集合由 RemoteViews 注解决定，静态核不全，但能拦住拼写错误。
REMOTEVIEWS_METHODS = {
    "setBackgroundResource",
    "setBackgroundColor",
    "setColorFilter",
    "setTextColor",
    "setTextSize",
    "setTextViewText",
    "setViewVisibility",
    "setImageViewResource",
    "setOnClickPendingIntent",
    "setContentDescription",
}

SETINT_CALL = re.compile(r'setInt\([^,]+,\s*"(\w+)"')


def check_remoteviews_string_methods(kotlin_dir: str) -> list:
    """核对 setInt(viewId, "方法名", …) 里的字符串方法名。"""
    problems = []
    for path in glob.glob(os.path.join(kotlin_dir, "**", "*.kt"), recursive=True):
        for lineno, line in enumerate(read_kotlin(path).splitlines(), 1):
            for m in SETINT_CALL.finditer(line):
                if m.group(1) not in REMOTEVIEWS_METHODS:
                    problems.append(
                        f"  ✗ {os.path.basename(path)}:{lineno} "
                        f'RemoteViews.setInt("{m.group(1)}") 不在已知可用的方法白名单里')
    return problems


# ── 最要紧的一项：IdS 表里的 ResId 必须真的在那个档位的布局里 ──────────

TIER_BLOCK = re.compile(r"private val ID_(\w+)\s*=\s*Ids\((.*?)\n\s*\)\n", re.S)
LAYOUT_OF_TIER = re.compile(r"layout\s*=\s*R\.layout\.(\w+)")
ID_IN_BLOCK = re.compile(r"(?<![.\w])R\.id\.(\w+)")

# 「数据字段型」id 的后缀：布局里定义了却没人填，就是漏配。
# 结构型 id（容器、hero、temp_box、静态度数符号…）本来就该留空，
# 全量反查只会刷出一屏无害噪音，反而把真问题埋掉。
DATA_SUFFIXES = ("_value", "_label", "_text", "_emoji", "_level", "_dot")


def check_ids_against_layouts(kotlin_dir: str, res_dir: str) -> list:
    """每个档位的 IdS 表里出现的 R.id.*，必须存在于该档位自己的布局 XML 里。"""
    provider = os.path.join(kotlin_dir, "com", "aprslocus", "aprslocus",
                            "WeatherWidgetProvider.kt")
    if not os.path.exists(provider):
        return []
    with open(provider, encoding="utf-8") as f:
        src = f.read()

    problems = []
    referenced_anywhere = set()

    for block_name, block in TIER_BLOCK.findall(src):
        lm = LAYOUT_OF_TIER.search(block)
        if not lm:
            problems.append(f"  ✗ ID_{block_name} 里没有声明 layout")
            continue
        layout_file = os.path.join(res_dir, "layout", f"{lm.group(1)}.xml")
        if not os.path.exists(layout_file):
            problems.append(
                f"  ✗ ID_{block_name} 指向的布局不存在：{lm.group(1)}.xml")
            continue
        with open(layout_file, encoding="utf-8") as f:
            layout_ids = set(re.findall(r"@\+id/(\w+)", f.read()))

        used = sorted(set(ID_IN_BLOCK.findall(block)))
        referenced_anywhere |= set(used)
        for name in used:
            if name not in layout_ids:
                problems.append(
                    f"  ✗ ID_{block_name} 用了 R.id.{name}，但 {lm.group(1)}.xml "
                    f"里没有这个 id（运行时该字段会静默不显示）")

    for path in sorted(glob.glob(os.path.join(res_dir, "layout",
                                              "aw_widget_*.xml"))):
        name = os.path.basename(path)
        with open(path, encoding="utf-8") as f:
            ids = re.findall(r"@\+id/(\w+)", f.read())
        for i in ids:
            if i.endswith(DATA_SUFFIXES) and i not in referenced_anywhere:
                problems.append(
                    f"  ✗ {name} 定义了数据字段 id {i}，但没有任何档位去填它"
                    f"（布局里加了控件却忘了配 IdS 表）")
    return problems


# ── 最要紧的一项：setInt 的「字符串方法名」是否真的存在于目标控件上 ──────
#
# 这一项是 v1.6.114 线上事故（「小组件加载失败」）的直接产物。
#
# 事故经过：代码里写了 `views.setInt(dot, "setColorFilter", color)`，
# 而 `setColorFilter` **只存在于 ImageView** —— View 和 TextView 都没有
# （已对 AOSP 源码核实：View 0 处、TextView 0 处、ImageView 3 处）。
# 那个 dot 是 TextView（RemoteViews 不允许原生 <View>，所以只能用它），
# 于是抛 NoSuchMethodException → RemoteViews.apply() 抛 ActionException →
# 启动器直接显示「小组件加载失败」，**整个组件报废**。
#
# 当时为什么没被拦住：下面的 REMOTEVIEWS_METHODS 是**我手写的白名单**，
# 我把 setColorFilter 也写了进去 —— 名字对了就放行。名字级别的白名单
# 根本管不了「这个方法在**这个控件类型**上存不存在」，而那才是关键。
#
# 所以这里改成**按控件类型校验**：从布局里把每个 id 的控件类型读出来，
# 再把 setInt 的目标 id 解析成类型，最后对照下表。
# 这才能拦住「方法名合法、但目标控件上没这个方法」这类错。
#
# 顺带说明：为什么不能指望编译期拦住 —— setInt 的方法名是**字符串**，
# 与目标控件完全没有类型关系，编译器无从检查。

# 方法名 → 该方法的定义者（最宽松的那个类）。View 是所有控件的基类，
# 所以要求 View 的，任何控件都满足；要求 TextView / ImageView 的则否。
METHOD_OWNER = {
    "setBackgroundResource": "View",     # View.setBackgroundResource(int)
    "setBackgroundColor": "View",        # View.setBackgroundColor(int)
    "setTextColor": "TextView",          # TextView.setTextColor(int)
    "setColorFilter": "ImageView",       # 仅 ImageView 有（不是 View/TextView）
}

# 控件 → 它的类继承链（只列本项目会用到的）
VIEW_PARENTS = {
    "TextView": {"TextView", "View"},
    "ImageView": {"ImageView", "View"},
    "LinearLayout": {"LinearLayout", "View"},
    "FrameLayout": {"FrameLayout", "View"},
    "View": {"View"},
}

TIPROW_FIELDS = {"row": 0, "dot": 1, "emoji": 2, "level": 3, "text": 4}

SETINT_ANY = re.compile(r'setInt\(\s*([^,]+?)\s*,\s*"(\w+)"')

TIPROW_CTOR = re.compile(r"TipRow\(([^)]*)\)")
ID_LITERAL = re.compile(r"(?<![.\w])R\.id\.(\w+)")

# 事故教训：这个变量名一旦在 setInt 里出现就是待查项
HOT_METHODS = {"setColorFilter"}


def collect_layout_view_types(res_dir: str) -> dict:
    """把每个 @+id 映射到它的控件类型（如 aw_tip0_dot → TextView）。

    同一 id 在多个布局里类型一致时取任一；不一致则记为 None（表示不确定，
    调用方应跳过检查而不是报假失败）。
    """
    types: dict[str, set] = {}
    for path in glob.glob(os.path.join(res_dir, "layout", "*.xml")):
        try:
            root = ET.parse(path).getroot()
        except ET.ParseError:
            continue
        for el in root.iter():
            eid = el.get("{http://schemas.android.com/apk/res/android}id")
            if not eid or not eid.startswith("@+id/"):
                continue
            types.setdefault(eid[len("@+id/"):], set()).add(el.tag)
    return {k: (v.pop() if len(v) == 1 else None) for k, v in types.items()}


def _tiprow_arg_ids(src: str) -> dict:
    """解析所有 TipRow(...) 实参，返回 {字段名: {id,...}}（0 表示无控件）。"""
    result: dict[str, set] = {name: set() for name in TIPROW_FIELDS}
    for args in TIPROW_CTOR.findall(src):
        parts = [p.strip() for p in args.split(",")]
        for name, idx in TIPROW_FIELDS.items():
            if idx < len(parts):
                m = ID_LITERAL.search(parts[idx])
                if m:
                    result[name].add(m.group(1))
    return result


def check_setint_view_types(kotlin_dir: str, res_dir: str) -> list:
    """校验 setInt(id, "方法名", …) 里的方法是否存在于该 id 的控件类型上。"""
    id_types = collect_layout_view_types(res_dir)
    if not id_types:
        return []

    problems = []
    for path in glob.glob(os.path.join(kotlin_dir, "**", "*.kt"), recursive=True):
        src = strip_kotlin_comments(read_raw(path))
        tiprow = _tiprow_arg_ids(src)

        for lineno, line in enumerate(src.splitlines(), 1):
            for m in SETINT_ANY.finditer(line):
                target, method = m.group(1), m.group(2)

                # 解析目标 → 一组候选 id
                ids: set = set()
                if target.startswith("R.id."):
                    ids = {target[len("R.id."):]}
                else:
                    fm = re.search(r"(\w+)\.(\w+)$", target)
                    if fm and fm.group(2) in TIPROW_FIELDS:
                        ids = tiprow.get(fm.group(2), set())
                if not ids:
                    continue  # 解析不出来（例如 ids.xxx 字段）：不报假失败

                owner = METHOD_OWNER.get(method)
                for vid in sorted(ids):
                    tag = id_types.get(vid)
                    if tag is None:
                        continue  # 类型不确定，跳过
                    if owner is None:
                        continue  # 不在表里的方法交给名称白名单检查
                    if owner not in VIEW_PARENTS.get(tag, {tag}):
                        extra = ""
                        if method in HOT_METHODS:
                            extra = (f"。⚠ 这正是 v1.6.114 的线上事故："
                                     f"{method} 只存在于 ImageView，在 {tag} 上调用会抛 "
                                     f"NoSuchMethodException → 整个组件显示"
                                     f"「小组件加载失败」")
                        problems.append(
                            f"  ✗ {os.path.basename(path)}:{lineno} "
                            f'setInt("{method}") 需要 {owner}，'
                            f"但 {vid} 是 {tag}{extra}")
    return problems


def read_raw(path: str) -> str:
    with open(path, encoding="utf-8") as f:
        return f.read()

def main() -> int:
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    res_dir = os.path.join(root, "android", "app", "src", "main", "res")
    kotlin_dir = os.path.join(root, "android", "app", "src", "main", "kotlin")
    manifest = os.path.join(root, "android", "app", "src", "main",
                            "AndroidManifest.xml")

    if not os.path.isdir(res_dir):
        print(f"找不到 res 目录：{res_dir}", file=sys.stderr)
        return 2

    resources = collect_resources(res_dir)
    refs = collect_kotlin_refs(kotlin_dir)

    missing = [f"  ✗ R.{k}.{n}  （来自 {w}）"
               for k, n, w in refs if f"{k}/{n}" not in resources]

    print(f"Kotlin 引用的资源：{len(refs)} 处"
          f"（去重后 {len({(k, n) for k, n, _ in refs})} 个）")
    print(f"res/ 中可用的资源：{len(resources)} 个")

    checks = [
        ("Kotlin 引用了不存在的资源", missing),
        ("布局里引用了不存在的资源", check_layout_refs(res_dir, resources)),
        ("清单里的组件类找不到实现", check_manifest(kotlin_dir, manifest)),
        ("RemoteViews 字符串方法名可疑",
         check_remoteviews_string_methods(kotlin_dir)),
        ("档位 IdS 与布局不匹配",
         check_ids_against_layouts(kotlin_dir, res_dir)),
        ("setInt 方法在目标控件上不存在",
         check_setint_view_types(kotlin_dir, res_dir)),
    ]

    failed = False
    for title, items in checks:
        if not items:
            continue
        failed = True
        print(f"\n{title}：")
        print("\n".join(items))

    print()
    print("❌ 有对不上的引用（见上）" if failed else "✅ 全部对得上")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
