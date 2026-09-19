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
    """扫 res/ 收集各类资源名 → 定义位置列表。

    ⚠ drawable 目录要按**任意扩展名**扫，不能只 glob `*.xml`：
    组件的图标全是烘焙出来的 PNG，只扫 xml 的话每个图标引用都会被判成
    「不存在」—— 一屏假失败会把真正的错埋掉（而且很容易让人干脆放宽规则）。
    """
    found: dict[str, list[str]] = {}

    def add(kind: str, name: str, where: str):
        found.setdefault(f"{kind}/{name}", []).append(where)

    for path in glob.glob(os.path.join(res_dir, "**", "*"), recursive=True):
        if not os.path.isfile(path):
            continue
        rel = os.path.relpath(path, res_dir)
        qualifier = os.path.basename(os.path.dirname(rel))
        base = qualifier.split("-")[0]
        stem, ext = os.path.splitext(os.path.basename(rel))

        if base in ("layout", "drawable", "xml", "mipmap"):
            add(base, stem, rel)
        if ext != ".xml":
            continue

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
    """布局里引用的 @drawable/@string/@mipmap 是否都存在。"""
    problems = []
    for path in glob.glob(os.path.join(res_dir, "layout", "*.xml")):
        text = open(path, encoding="utf-8").read()
        for m in re.finditer(r"@(drawable|string|xml|mipmap)/(\w+)", text):
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


# ── 资源 XML 的属性名白名单 ──
#
# 为什么需要：aapt2 对**未知属性名**是硬错误（`attribute X not found`），
# 会让整个 Android 构建失败 —— 而本机没有 Android SDK，编不了，只能等 CI。
# 一个真实教训：`<usb-device interface-class="2"/>` 里的 `interface-class`
# 根本不存在（那是 UsbInterface 的概念，`<usb-device>` 只认 class/subclass/
# protocol），aapt2 直接报错；而它看起来「很像对的」。
XML_RES_TAGS = {
    "appwidget-provider": {
        "minWidth", "minHeight", "minResizeWidth", "minResizeHeight",
        "targetCellWidth", "targetCellHeight", "maxResizeWidth", "maxResizeHeight",
        "updatePeriodMillis", "initialLayout", "initialKeyguardLayout",
        "configure", "previewImage", "previewLayout", "description",
        "resizeMode", "widgetCategory", "updatePeriodMillis",
    },
    "usb-device": {"vendor-id", "product-id", "class", "subclass", "protocol"},
}


def check_xml_res_attributes(res_dir: str) -> list:
    """res/xml/*.xml 里的属性名必须在白名单里

    ⚠️ 必须容忍**带命名空间的属性**（`android:minWidth`）—— 直接把
    `android:` 前缀剥掉再比。反过来，若忘剥前缀，每个属性都会被判成
    非法（假失败比真失败更坏：修它的人会去删说明或放宽规则）。
    """
    problems = []
    for path in sorted(glob.glob(os.path.join(res_dir, "xml", "*.xml"))):
        try:
            tree = ET.parse(path)
        except Exception as e:  # 语法错误交给别的检查
            problems.append(f"  ✗ {os.path.basename(path)} 解析失败：{e}")
            continue
        base = os.path.basename(path)
        for el in tree.iter():
            tag = el.tag.split("}")[-1]
            allowed = XML_RES_TAGS.get(tag)
            if allowed is None:
                continue
            for raw in el.attrib:
                attr = raw.split("}")[-1] if "}" in raw else raw
                if attr not in allowed:
                    problems.append(
                        f"  ✗ {base}: <{tag}> 上的属性 '{attr}' 不是合法属性"
                        f"（aapt2 会直接报错、Android 构建失败）"
                    )
    return problems


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
    # 被引用的 id 取**全局**（所有 Kotlin 文件），不是只看天气组件的 IDS 表 ——
    # 否则短波组件（HfWidgetProvider，用的是 SUM_LABEL/BAND_IDS 这类数组而不是
    # Ids 表）填的 id 会被当成「没人填」，一屏假失败。
    referenced_anywhere = set()
    for kt in glob.glob(os.path.join(kotlin_dir, "**", "*.kt"), recursive=True):
        referenced_anywhere |= set(ID_IN_BLOCK.findall(read_kotlin(kt)))

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


# ── 短波组件这类「单布局 Provider」的核对 ─────────────────────────
# WeatherWidgetProvider 用 `RemoteViews(pkg, ids.layout)`（布局是变量），
# 由上面的档位表逐档核对；而 HfWidgetProvider 直接写
# `RemoteViews(context.packageName, R.layout.aw_widget_hf)` —— 布局是字面量，
# 于是可以读出来，把这个文件里出现的每个 R.id.* 都对照那份布局核一遍。
LAYOUT_LITERAL = re.compile(r"RemoteViews\([^,]+,\s*R\.layout\.(\w+)\)")


def check_layout_literal_providers(kotlin_dir, res_dir):
    problems = []
    for path in glob.glob(os.path.join(kotlin_dir, "**", "*.kt"), recursive=True):
        text = read_kotlin(path)
        for layout in set(LAYOUT_LITERAL.findall(text)):
            layout_file = os.path.join(res_dir, "layout", f"{layout}.xml")
            if not os.path.exists(layout_file):
                problems.append(f"  ✗ {os.path.basename(path)} 引用的布局不存在："
                                f"{layout}.xml")
                continue
            with open(layout_file, encoding="utf-8") as f:
                layout_ids = set(re.findall(r"@\+id/(\w+)", f.read()))
            for name in sorted(set(ID_IN_BLOCK.findall(text))):
                if name not in layout_ids:
                    problems.append(
                        f"  ✗ {os.path.basename(path)} 用了 R.id.{name}，但 "
                        f"{layout}.xml 里没有这个 id（运行时该字段会静默不显示）")
    return problems


# ── Kotlin 具名实参 vs 类声明 ──────────────────────────────────────
# 这一条是为 v1.6.116 的一次 CI 失败加的：
#   ID_TILE / ID_TALL 已经写了 `tipShort = true`，render 里也读了
#   `ids.tipShort`，但 `Ids` 类里**从没声明过这个字段** —— 属于一个没写完的
#   改动。Kotlin 编译报 3 处「No parameter with name 'tipShort' found /
#   Unresolved reference」，而我的静态检查器全绿（它只查资源引用）。
#
# 本机没有 Android SDK、编不了 Kotlin，所以只能靠这种「形状级」核对兜住最容易
# 犯的一类：**具名实参在类声明里不存在**。这不是类型检查（做不到），
# 但恰好覆盖「加了用法忘了加字段」这种最常见的半成品状态。
CLASS_DECL = re.compile(r"(?:private\s+)?class\s+(\w+)\s*\(([^)]*)\)", re.S)
VAL_NAME = re.compile(r"\bval\s+(\w+)\s*:")
NAMED_ARG = re.compile(r"\b(\w+)\s*=(?!=)")



def _balanced(text, open_idx):
    """返回从 text[open_idx]（应为 '('）到配对 ')' 之间的内容。"""
    depth, i = 0, open_idx
    while i < len(text):
        if text[i] == "(":
            depth += 1
        elif text[i] == ")":
            depth -= 1
            if depth == 0:
                return text[open_idx + 1:i]
        i += 1
    return text[open_idx + 1:]

def check_named_args(kotlin_dir):
    problems = []
    for path in glob.glob(os.path.join(kotlin_dir, "**", "*.kt"), recursive=True):
        text = read_kotlin(path)
        # 收集本工程内的类声明 → 其构造参数名（用配对括号取参数串）
        decls = {}
        for m in re.finditer(r"(?:private\s+)?class\s+(\w+)\s*\(", text):
            params = _balanced(text, m.end() - 1)
            decls.setdefault(m.group(1), set()).update(VAL_NAME.findall(params))
        if not decls:
            continue
        # 找 `Xxx(` 调用点里的具名实参，核对是否在该类声明里
        for cls, params in decls.items():
            if not params:
                continue
            # 跳过声明自身
            decl_end = max((m.end() for m in CLASS_DECL.finditer(text)
                            if m.group(1) == cls), default=0)
            for m in re.finditer(rf"\b{cls}\(", text[decl_end:]):
                body = _balanced(text, decl_end + m.end() - 1)
                for am in NAMED_ARG.finditer(body):
                    aname = am.group(1)
                    # 只核「看起来像构造参数」的具名实参，跳过 lambda / 比较等
                    if aname in ("if", "when", "return", "true", "false", "null"):
                        continue
                    if aname not in params:
                        problems.append(
                            f"  ✗ {os.path.basename(path)}: {cls}(...) 传了具名实参 "
                            f"`{aname} =`，但 {cls} 类里没有这个字段"
                            f"（这类「加了用法忘了加字段」的改动，Kotlin 编译会直接失败）")
    return problems

def check_widget_sizes(res_dir: str) -> list:
    """小组件尺寸声明的不变量。

    **这条是拿一次真实事故换来的**（v1.6.133）：当时给短波/系统状态打开了缩放，
    顺手把 `minResizeHeight` 写成 150dp / 125dp —— 而它们的 `minHeight`（默认
    尺寸）是 110dp。`minResize*` 的语义是「用户**最少**能拖到多小」，比默认尺寸
    还大的话，等于宣告「默认的 4×2 低于下限」，启动器于是拒绝落到 4×2、或强行
    撑到那个下限。用户装完的反应就是「4×2 怎么不支持了」。

    约束就一句话：**minResize* ≤ min***。写在代码里看着显然，但要到装机才发作，
    所以放进检查器。

    顺带查 `resizeMode` 的取值：写错了同样只在装机时才看得出来。
    """
    problems = []
    xml_dir = os.path.join(res_dir, "xml")
    if not os.path.isdir(xml_dir):
        return problems
    allowed_modes = {"none", "horizontal", "vertical", "horizontal|vertical",
                     "vertical|horizontal"}
    for name in sorted(os.listdir(xml_dir)):
        if not (name.startswith("aprslocus_") and name.endswith("_widget_info.xml")):
            continue
        path = os.path.join(xml_dir, name)
        try:
            root = ET.parse(path).getroot()
        except ET.ParseError as e:
            problems.append(f"  ✗ {name}: XML 解析失败（AAPT 会拒）：{e}")
            continue

        def dim(attr: str) -> int:
            """取 dp 属性；缺失返回 -1（不参与比较）。"""
            v = root.get("{http://schemas.android.com/apk/res/android}" + attr)
            if v is None or not v.endswith("dp"):
                return -1
            return int(v[:-2])

        mode = root.get("{http://schemas.android.com/apk/res/android}resizeMode")
        if mode is not None and mode not in allowed_modes:
            problems.append(f"  ✗ {name}: resizeMode={mode!r} 不是合法取值")

        for axis, mn, rs in (("宽", "minWidth", "minResizeWidth"),
                             ("高", "minHeight", "minResizeHeight")):
            a, b = dim(mn), dim(rs)
            if a > 0 and b > 0 and b > a:
                problems.append(
                    f"  ✗ {name}: {rs}={b}dp 大于 {mn}={a}dp —— "
                    f"「最少能拖到多小」不能比默认{axis}度还大，"
                    f"否则默认尺寸（如 4×2）会落不下来（v1.6.133 的真实事故）")
    return problems


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
        ("单布局 Provider 的 ResId 与布局不匹配",
         check_layout_literal_providers(kotlin_dir, res_dir)),
        ("Kotlin 具名实参在类声明里不存在",
         check_named_args(kotlin_dir)),
        ("小组件尺寸声明不合法", check_widget_sizes(res_dir)),
        ("资源 XML 属性名不合法", check_xml_res_attributes(res_dir)),
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
