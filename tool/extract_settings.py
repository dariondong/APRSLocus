#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""从代码里抽「设置」的完整清单 → JSON（供文档生成器 tool/gen_manual_pages.py 消费）。

覆盖：设置总览（8 分组卡 + 独立入口）+ 7 个分组子页 + 8 个独立设置页 = 16 页、130+ 控件。

v2.1 相对 v2 修正的坑（每条都曾真实漏抓/抓错）：
  1. `Tx.of(context).byKey('radioCat')` 这种标题写法 v2 不认 → 分组标题全变成键名。
  2. 字段只取两段：`st.tnc.config.rfBeacon` 被截成 `tnc.config` → 默认值查不到。
  3. onChanged 只有 setter（`st.setMaxStations(n)`）→ 当成字段名，查不到默认值；
     现在 setXxx → xxx 再查。
  4. 局部别名（audio_page 的 `c.afsk.sampleRate`、translate 的 `cfg.targetLang`）
     —— 改成**数据驱动**：把表达式里的所有点链/叶子名拿去 defaults 里探，命中即字段。
  5. 私有辅助控件 `_clearDataItem(文案, 计数)` 用位置参数 → label 抽不到被丢；
     现在优先 title:/label:，再位置参数，再正文第一个 arb 键。
  6. 按钮区（清空聊天记录等）整个分节显示「(空)」→ 现在抓 *Button 的
     label/child Text(文案)，标为 action。

数据来源（四处交叉）：
  1. 各页 dart 源码 —— 控件调用序列（= UI 真实顺序与分组）
  2. lib/l10n/app_{zh,zh_TW,en}.arb —— 三语标签与说明（app 官方翻译，非机翻）
  3. lib/state.dart —— 顶层字段默认值
  4. lib/{tnc,audio,translate,pkwdwpl,afsk,services}.dart —— 嵌套配置默认值

跑法：python3 tool/extract_settings.py --summary   可读摘要（人看）
      python3 tool/extract_settings.py            JSON → tool/_settings_extract.json
"""
import io
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LANGS = ('zh', 'zh_TW', 'en')


def load_arb(name):
    d = json.load(io.open(os.path.join(ROOT, 'lib/l10n', name), encoding='utf-8'))
    return {k: v for k, v in d.items() if not k.startswith('@')}


ZH, TW, EN = load_arb('app_zh.arb'), load_arb('app_zh_TW.arb'), load_arb('app_en.arb')


def txt(key, lang):
    """arb 键 → 文案；缺译时回落 zh（与 app 的 Tx.byKey 回落一致）。"""
    src = {'zh': ZH, 'zh_TW': TW, 'en': EN}[lang]
    return src.get(key) or ZH.get(key) or key


# ─────────────────────────── 扫描目标 ───────────────────────────
# settings_page.dart 的 8 张分组卡 → 对应子页 class（update 页无控件，仅进总览）
CAT_KEYS = {
    'StationSettingsPage': 'radioCat',
    'BeaconSettingsPage': 'beaconCat',
    'ConnectionSettingsPage': 'connectionCat',
    'DisplaySettingsPage': 'displayCat',
    'DeviceSettingsPage': 'deviceCat',
    'DataSettingsPage': 'dataCat',
    'AdvancedSettingsPage': 'advancedCat',
    'CheckUpdatePage': 'updateCat',
}

# 服务器一级页只收录它自己的三张卡（互联网链接 / 过滤 / 呼号筛选）。
# 页尾那几张电台卡只在对应链路开着时才出现，内容与「设备」页重复，跳过。
# 「数据上限」已搬到数据页（2026-11-12），所以这里不再列它。
KEEP_SECTION_KEYS = {
    'ConnectionSettingsPage': ('sourceGroupInternet', 'filter', 'receiveFilter'),
}

SINGLE_FILES = [
    'lib/device_page.dart',            # 设备总览（DeviceSettingsPage 转发到这里）
    'lib/tnc_device_page.dart',        # 设备 · TNC
    'lib/ic705_device_page.dart',      # 设备 · WLAN 电台直连
    'lib/audio_page.dart',             # 设备 · 音频
    'lib/pkwdwpl_device_page.dart',    # 设备 · PKWDWPL
    'lib/ext_gps_device_page.dart',    # 设备 · 外接 GPS（NMEA 蓝牙模块）
    'lib/aprs_is_cards.dart',          # 服务器 · APRS-IS
    'lib/acn_cards.dart',              # 服务器 · APRSNETCN（无 PageShell，标题取自 arb）
    'lib/feature_page.dart',           # 功能启用（自选模块 + 精简模式）
    'lib/translate_page.dart',         # 翻译设置
    'lib/theme_page.dart',             # 主题
    'lib/backup_page.dart',            # 备份与恢复
    'lib/offline_map_page.dart',       # 离线地图
    'lib/sync_cards.dart',             # 服务器 · 云同步（两张卡，没有自己的一页）
]

# 没有 SettingsPageShell 的卡片文件：标题 / 副标题直接给 arb 键
SHELL_FALLBACK = {
    'lib/acn_cards.dart': (('key', 'acnCardTitle'), ('key', 'acnCardSubtitle')),
    'lib/sync_cards.dart': (('key', 'syncTitle'), (None, None)),
}

# 单页插到哪个分组页之后：两条互联网链路紧跟「服务器」一级页
INSERT_AFTER = {
    'lib/aprs_is_cards.dart': 'ConnectionSettingsPage',
    'lib/acn_cards.dart': 'lib/aprs_is_cards.dart',
    'lib/sync_cards.dart': 'lib/acn_cards.dart',
}

# 只读常量所在的文件：表格里出现的 k 开头常量要换成真值
CONST_FILES = ['lib/aprsnetcn.dart', 'lib/net/aprs_base.dart']

CONFIG_FILES = [
    'lib/state.dart',
    'lib/tnc.dart',
    'lib/audio.dart',
    'lib/afsk.dart',
    'lib/translate.dart',
    'lib/pkwdwpl.dart',
    'lib/services.dart',
]

KNOWN = {
    'SettingsInput', 'SettingsSwitch', 'SettingsMiniSwitch', 'SettingsRow2',
    'SettingsNavRow', 'SettingsHint', 'SettingsFold', 'SettingsSectionCard',
    'SettingsPageShell', 'SettingsLinkEntry', 'SettingsChoice',
}
BUTTONS = ('FilledButton', 'TextButton', 'OutlinedButton', 'ElevatedButton')

# S.of(context).x / s.x（各页的 S 缩写一律是 s）/ Tx.of(context).byKey('x')
ARB = re.compile(r"""S\.of\(context\)\.(\w+)|\bs\.(\w+)""")
ARB_BYKEY = re.compile(r"""Tx\.of\(context\)\.byKey\('(\w+)'\)""")


def arb_key(fragment):
    """片段里的 arb 键（三种写法），无则 None。"""
    if not fragment:
        return None
    m = ARB_BYKEY.search(fragment)
    if m:
        return m.group(1)
    m = ARB.search(fragment)
    if m:
        return m.group(1) or m.group(2)
    return None
LIT = re.compile(r"^'((?:[^'\\]|\\.)*)'")
IDENT = re.compile(r'^([_A-Za-z]\w*)')
CHAIN = re.compile(r'\b[A-Za-z_]\w*(?:\.\w+)+')
SETTER = re.compile(r'\bset([A-Z]\w*)\s*\(')


def match_paren(s, i):
    """s[i] == '(' → 返回配对 ')' 的下标。"""
    depth, instr, q = 0, False, ''
    while i < len(s):
        c = s[i]
        if instr:
            if c == '\\':
                i += 2
                continue
            if c == q:
                instr = False
        elif c in '\'"':
            instr, q = True, c
        elif c == '(':
            depth += 1
        elif c == ')':
            depth -= 1
            if depth == 0:
                return i
        i += 1
    return -1


def split_top(s):
    """按顶层逗号切分（忽略括号/字符串内的逗号）。"""
    out, depth, instr, q, cur = [], 0, False, '', ''
    i = 0
    while i < len(s):
        c = s[i]
        if instr:
            cur += c
            if c == '\\':
                i += 1
                if i < len(s):
                    cur += s[i]
                i += 1
                continue
            if c == q:
                instr = False
            i += 1
            continue
        if c in '\'"':
            instr, q = True, c
            cur += c
        elif c in '([{':
            depth += 1
            cur += c
        elif c in ')]}':
            depth -= 1
            cur += c
        elif c == ',' and depth == 0:
            out.append(cur)
            cur = ''
        else:
            cur += c
        i += 1
    out.append(cur)
    return out


def arg_of(body, name):
    """取命名参数 name: 的值片段（到下一个顶层逗号或结尾）。"""
    m = re.search(r'\b%s\s*:' % re.escape(name), body)
    if not m:
        return None
    seg = body[m.end():]
    depth, instr, q = 0, False, ''
    for j, c in enumerate(seg):
        if instr:
            if c == '\\':
                continue
            if c == q:
                instr = False
        elif c in '\'"':
            instr, q = True, c
        elif c in '([{':
            depth += 1
        elif c in ')]}':
            if depth == 0:
                seg = seg[:j]
                break
            depth -= 1
        elif c == ',' and depth == 0:
            seg = seg[:j]
            break
    return seg.strip()


def label_of(fragment):
    """片段 → (kind, key/literal)。kind: 'key' | 'lit' | None"""
    if not fragment:
        return (None, None)
    key = arb_key(fragment)
    if key:
        return ('key', key)
    m = LIT.match(fragment.strip())
    if m:
        return ('lit', m.group(1))
    return (None, None)


def first_arb(fragment):
    """片段里第一个 arb 键（_clearDataItem 这类位置参数控件的 label 兜底）。"""
    key = arb_key(fragment)
    return ('key', key) if key else None


# ─────────────────────────── 默认值 ───────────────────────────
def defaults():
    """state.dart 顶层 + 各 Config 类构造/字段初始化 → (顶层dict, 嵌套dict)"""
    top, nested = {}, {}

    src = io.open(os.path.join(ROOT, 'lib/state.dart'), encoding='utf-8').read()
    for m in re.finditer(
            r'^\s{2}(?:final\s+)?(int|double|bool|String)(\?)?\s+(\w+)\s*=\s*([^;/]+);',
            src, re.M):
        typ, null, name, val = m.groups()
        top[name] = {'type': typ + ('?' if null else ''),
                     'default': val.strip().strip("'\"")}

    for rel in CONFIG_FILES:
        path = os.path.join(ROOT, rel)
        if not os.path.exists(path):
            continue
        s = io.open(path, encoding='utf-8').read()
        # 构造参数 this.x = <值>：值里可能带引号内逗号（JSON 模板、'WIDE1-1,WIDE2-1'），
        # 朴素正则会在第一个逗号截断 —— 用引号感知扫描。
        for m in re.finditer(r'\bthis\.(\w+)\s*=\s*', s):
            nested.setdefault(m.group(1), read_value(s, m.end()).strip().strip("'\""))
        for m in re.finditer(
                r'^\s{2}(?:final\s+)?(int|double|bool|String)\??\s+(\w+)\s*=\s*',
                s, re.M):
            val = read_value(s, m.end(), stop_semi=True)
            if val:
                nested.setdefault(m.group(2), val.strip().strip("'\""))

    nested.setdefault('server', '')   # 软件不预置服务器地址
    nested.setdefault('port', '14580')
    nested.setdefault('passcode', '-1')

    # 顶层常量（const int kAcnServerPort = 14580）：控制器初值写成常量名时
    # 直接显示数字，不然表格里会出现一个源码符号。
    for rel in CONST_FILES:
        path = os.path.join(ROOT, rel)
        if not os.path.exists(path):
            continue
        s = io.open(path, encoding='utf-8').read()
        for m in re.finditer(r'^const\s+(?:int|String)\s+(k\w+)\s*=\s*([^;]+);', s, re.M):
            nested.setdefault(m.group(1), m.group(2).strip().strip("'\""))
    return top, nested


def read_value(s, i, stop_semi=False):
    """从 i 开始读一个 Dart 字面量到顶层分隔符（引号内的逗号不算分隔）。"""
    depth, instr, q, out = 0, False, '', []
    while i < len(s):
        c = s[i]
        if instr:
            out.append(c)
            if c == '\\' and i + 1 < len(s):
                out.append(s[i + 1])
                i += 2
                continue
            if c == q:
                instr = False
            i += 1
            continue
        if c in "'\"":
            instr, q = True, c
            out.append(c)
        elif c in '([{':
            depth += 1
            out.append(c)
        elif c in ')]}':
            if depth == 0:
                break
            depth -= 1
            out.append(c)
        elif c == ',' and depth == 0:
            break
        elif c == ';' and depth == 0 and stop_semi:
            break
        elif c == '\n' and depth == 0:
            break
        else:
            out.append(c)
        i += 1
    return ''.join(out).strip()


TOP, NESTED = defaults()


def find_field(exprs):
    """表达式列表 → 命中 defaults 的字段名（数据驱动：整链 → 叶子 → setter → 裸标识）。"""
    if not exprs:
        return ''
    joined = ' '.join(e for e in exprs if e)
    # 1) 完整点链
    for ch in CHAIN.findall(joined):
        if ch in TOP or ch in NESTED:
            return ch
    # 2) 叶子名（局部别名 c.afsk.sampleRate → sampleRate）
    for ch in CHAIN.findall(joined):
        leaf = ch.split('.')[-1]
        if leaf in TOP or leaf in NESTED:
            return leaf
    # 3) setter：setMaxStations( → maxStations
    for sname in SETTER.findall(joined):
        cand = sname[0].lower() + sname[1:]
        if cand in TOP or cand in NESTED:
            return cand
    return ''


def lookup_default(field):
    """字段 → (default, type)"""
    if not field:
        return ('', '')
    if field in TOP:
        return (TOP[field].get('default', ''), TOP[field].get('type', ''))
    leaf = field.split('.')[-1]
    if leaf in TOP and isinstance(TOP[leaf], dict):
        return (TOP[leaf].get('default', ''), TOP[leaf].get('type', ''))
    if leaf in NESTED:
        return (NESTED[leaf], '')
    return ('', '')


def choice_opts(body):
    """SettingsChoice 的选项文案 → (arb 键列表, 选项字面量列表)。

    只认 `labelOf` 里那串 switch 分支；三元链与拿 $v 拼的文案不列选项 ——
    宁可不列，也不把 `{v} 秒` 这种模板印进文档。

    顺序按 `options` 里的字面量走（下拉里就是这个顺序）；`_ =>` 那一支通常
    对应第一个选项，排在前面。字面量认不出来（`CoordFormat.dec => …`）时
    退回源码顺序。
    """
    frag = arg_of(body, 'labelOf') or ''
    if 'switch' not in frag:
        return [], []
    # `(v) => switch (v) { … }`：只看花括号里的分支，否则开头那个 `(v) =>`
    # 会把整段吞掉，后面几个字面量就都认不出来了。
    a, b = frag.find('{'), frag.rfind('}')
    if 0 <= a < b:
        frag = frag[a + 1:b]
    keys, by_val, default_key = [], {}, None
    for m in re.finditer(r'([^,{}=]+?)\s*=>\s*([^,}]+)', frag):
        cond = m.group(1).strip()
        key = arb_key(m.group(2))
        if not key:
            continue
        mc = re.match(r"'([^']*)'$", cond)
        lit = mc.group(1) if mc else (
            cond if re.match(r'-?\d+$', cond) else None)
        if key not in keys:
            keys.append(key)
        if lit is None:
            default_key = key
        else:
            by_val[lit] = key
    lits = re.findall(r"'([^']*)'|(-?\d+)", arg_of(body, 'options') or '')
    values = [x or y for x, y in lits]
    if values and by_val:
        seq = [by_val[v] for v in values if v in by_val]
        order = ([default_key] if default_key and default_key not in seq else [])
        order += [k for k in seq if k not in order]
    else:
        head = [default_key] if default_key else []
        order = head + [k for k in keys if k not in head]
    ok = []
    for k in order:
        v = ZH.get(k) or ''
        if v and '{' not in v and '$' not in v:
            ok.append(k)
    return ok, values


# ─────────────────────────── 控件扫描 ───────────────────────────
def scan(src):
    """按出现顺序扫控件 → items（含 section / fold / hint / 按钮 action）。"""
    hits = []

    # 分节正文跨度：按钮/自定义控件必须落在某个 SettingsSectionCard 的括号内，
    # 否则会把对话框里的「取消/确认」按钮误收进上一个分节。
    card_spans = []
    for m in re.finditer(r'\bSettingsSectionCard\s*\(', src):
        i = src.index('(', m.end() - 1)
        j = match_paren(src, i)
        if j > 0:
            card_spans.append((m.start(), j))

    def in_card(pos):
        return any(a <= pos <= b for a, b in card_spans)

    # 私有方法的定义跨度：卡里调用的辅助方法（_accountInputs）里的裸 TextField
    # 也算这张卡的内容。
    defs = []
    for m in re.finditer(r'\b(?:Widget|Column|List<Widget>)\s+(_\w+)\s*\(', src):
        i = src.index('(', m.end() - 1)
        j = match_paren(src, i)
        if j <= 0:
            continue
        k = src.find('{', j)
        depth, e = 0, -1
        while 0 <= k < len(src):
            if src[k] == '{':
                depth += 1
            elif src[k] == '}':
                depth -= 1
                if depth == 0:
                    e = k
                    break
            k += 1
        if e > 0:
            defs.append((m.group(1), i, e))

    def in_card_helper(pos):
        for name, a, b in defs:
            if a <= pos <= b:
                for c in re.finditer(r'\b%s\s*\(' % re.escape(name), src):
                    if c.start() < a and in_card(c.start()):
                        return True
                return False
        return False

    for m in re.finditer(r'\b(Settings[A-Za-z0-9]+)\s*(?:<[^<>()]*>)?\s*\(', src):
        if m.group(1) not in KNOWN:
            continue
        i = src.index('(', m.end() - 1)
        j = match_paren(src, i)
        if j < 0:
            continue
        hits.append((m.start(), m.end(), m.group(1), src[i + 1:j]))

    # 功能页的模块开关是本地 row(AppFeature.x, 文案) 闭包，不是 SettingsSwitch
    for m in re.finditer(r'\brow\(\s*AppFeature\.(\w+)\s*,\s*([^)]*)\)', src):
        hits.append((m.start(), m.end(), '_feature', '%s|%s' % (m.group(2), m.group(1))))

    # 裸 TextField（账号 / 口令这类没有 SettingsInput 封装的格）：
    # 标签取同一格里的 tooltip，没有就用上面最近的一个 Text(s.xxx, …)
    labels = [(x.start(), x.group(1))
              for x in re.finditer(r'\bText\(s\.(\w+)', src)]
    labels += [(x.start(), x.group(1))
               for x in re.finditer(r'\bText\(S\.of\(context\)\.(\w+)', src)]
    labels.sort()
    for m in re.finditer(r'\bTextField\s*\(', src):
        if not (in_card(m.start()) or in_card_helper(m.start())):
            continue
        i = src.index('(', m.end() - 1)
        j = match_paren(src, i)
        if j < 0:
            continue
        body = src[i + 1:j]
        tip = arg_of(body, 'tooltip')
        lab_key = None
        mt = re.search(r'\bs\.(\w+)', tip or '')
        if mt:
            lab_key = 's.' + mt.group(1)
        else:
            # 在辅助方法里：方法内第一个 Text(…) 就是这格的标题（后面的
            # 可能是「未验证」之类的徽标）；否则用上面最近的标题。
            box = [(a, b) for _n, a, b in defs if a <= m.start() <= b]
            inside = [k for p, k in labels if box and box[0][0] <= p <= box[0][1]]
            if inside:
                lab_key = 's.' + inside[0]
            else:
                prev = [k for p, k in labels if p < m.start()]
                if prev:
                    lab_key = 's.' + prev[-1]
        if not lab_key:
            continue
        ctl = arg_of(body, 'controller') or ''
        hits.append((m.start(), j, '_field',
                     '%s\x01%s\x02%s' % (lab_key, ctl, body)))

    # 私有辅助控件（_locSourceCard / _clearDataItem / _entry …）
    for m in re.finditer(r'\b(_[A-Za-z]\w*)\s*\(', src):
        if m.group(1) == '_':
            continue
        if not in_card(m.start()):
            continue
        i = src.index('(', m.end() - 1)
        j = match_paren(src, i)
        if j < 0:
            continue
        body = src[i + 1:j]
        if len(body) > 2500:
            continue
        has_arb = ARB.search(body) or ARB_BYKEY.search(body)
        has_bind = (re.search(r'\b(?:st|state)\.\w+', body)
                    or re.search(r'\bpage\s*:', body)
                    or bool(CHAIN.search(body)))
        if has_arb and has_bind:
            hits.append((m.start(), m.end(), '_custom', body))

    # 按钮（清空聊天记录 / 保存并应用 …）
    for m in re.finditer(r'\b(' + '|'.join(BUTTONS) + r')\.?(?:icon)?\s*\(', src):
        if not (in_card(m.start()) or in_card_helper(m.start())):
            continue
        i = src.index('(', m.end() - 1)
        j = match_paren(src, i)
        if j < 0:
            continue
        body = src[i + 1:j]
        lab = None
        for fname in ('label', 'child'):
            f = arg_of(body, fname)
            lab = label_of(f)
            if lab and lab[0]:
                break
        if lab and lab[0]:
            hits.append((m.start(), m.end(), '_action', body))

    hits.sort()

    items, section, fold = [], None, None
    prev_item = None
    for pos, _e, kind, body in hits:
        if kind == 'SettingsSectionCard':
            section = {'title': label_of(arg_of(body, 'title')),
                       'subtitle': label_of(arg_of(body, 'subtitle')),
                       'note': None, 'items': []}
            fold = None
            items.append({'_section': section})
            prev_item = None
            continue
        if kind == 'SettingsFold':
            fold = {'title': label_of(arg_of(body, 'title')),
                    'subtitle': label_of(arg_of(body, 'subtitle'))}
            prev_item = None
            continue
        if kind == 'SettingsHint':
            k, v = label_of(body.split(',')[0])
            if prev_item is not None:
                prev_item['hint'] = (k, v)
            elif section is not None and section['note'] is None:
                section['note'] = (k, v)     # 分节首个元素就是说明（无归属控件）
            continue
        if kind in ('SettingsPageShell',):
            continue

        entry = {'kind': kind, 'section': section, 'fold': fold}

        if kind == 'SettingsInput':
            parts = split_top(body)
            entry['label'] = label_of(parts[0])
            entry['ctl'] = IDENT.match(parts[1].strip()).group(1) if len(parts) > 1 else ''
            entry['exprs'] = [body]           # onChanged / 校验里就有 st. 字段
            t = arg_of(body, 'tip')
            if t:
                entry['tip'] = label_of(t)
        elif kind in ('SettingsSwitch', 'SettingsMiniSwitch'):
            entry['label'] = label_of(split_top(body)[0])
            entry['exprs'] = [arg_of(body, 'value') or '', body]
        elif kind == 'SettingsRow2':
            parts = split_top(body)
            entry['label'] = label_of(parts[0])
            entry['exprs'] = [parts[1] if len(parts) > 1 else '']
        elif kind == 'SettingsChoice':
            parts = split_top(body)
            entry['label'] = label_of(parts[0])
            entry['exprs'] = [arg_of(body, 'value') or '',
                              arg_of(body, 'onChanged') or '']
            t = arg_of(body, 'tip')
            if t:
                entry['tip'] = label_of(t)
            entry['opts'], entry['opt_values'] = choice_opts(body)
        elif kind == 'SettingsNavRow':
            entry['label'] = label_of(arg_of(body, 'title'))
            entry['sub'] = label_of(arg_of(body, 'subtitle'))
            tr = arg_of(body, 'trailing')
            entry['trailing'] = label_of(tr) if tr else None
            tap = arg_of(body, 'onTap') or ''
            md = re.search(r'\b([A-Z]\w*Page)\s*\(', tap)
            entry['dest'] = md.group(1) if md else ''
            entry['exprs'] = []
        elif kind == 'SettingsLinkEntry':
            entry['label'] = label_of(arg_of(body, 'title'))
            entry['sub'] = label_of(arg_of(body, 'subtitle'))
            tap = arg_of(body, 'onTap') or ''
            md = re.search(r'\b([A-Z]\w*Page)\s*\(', tap)
            entry['dest'] = md.group(1) if md else ''
            entry['exprs'] = [arg_of(body, 'status') or '']
        elif kind == '_custom':
            lab = label_of(arg_of(body, 'title'))
            if not lab or not lab[0]:
                lab = label_of(arg_of(body, 'label'))
            if not lab or not lab[0]:
                parts = split_top(body)
                lab = label_of(parts[0])
            if not lab or not lab[0]:
                lab = first_arb(body)
            entry['label'] = lab
            d = arg_of(body, 'desc')
            entry['sub'] = label_of(d) if d else (None, None)
            ex = []
            for fname in ('selected', 'value', 'onTap', 'onChanged'):
                f = arg_of(body, fname)
                if f:
                    ex.append(f)
            entry['exprs'] = ex or [body]
            md = re.search(r'\b([A-Z]\w*Page)\s*\(', body)
            entry['dest'] = md.group(1) if md else ''
        elif kind == '_field':
            head, ctl_expr, real = (body.split('\x01') + ['', ''])[:3]
            if '\x02' in ctl_expr:
                ctl_expr, real = ctl_expr.split('\x02', 1)
            entry['label'] = label_of(head)
            entry['ctl'] = IDENT.match(ctl_expr.strip()).group(1) \
                if IDENT.match(ctl_expr.strip()) else ''
            entry['exprs'] = [ctl_expr, real]
        elif kind == '_feature':
            lab, fid = body.split('|', 1)
            entry['label'] = label_of(lab)
            entry['field_tag'] = 'feature.' + fid.strip()
            entry['exprs'] = []
        elif kind == '_action':
            entry['label'] = label_of(arg_of(body, 'label')) \
                if arg_of(body, 'label') else label_of(arg_of(body, 'child'))
            entry['exprs'] = [body]

        if entry.get('label') and entry['label'][0]:
            items.append(entry)
            prev_item = entry if kind != '_action' else prev_item
    return items


def scan_hub(src):
    """settings_page.dart：8 张分组卡 + 独立入口（手写 GestureDetector）→ 总览条目。"""
    out = []
    for m in re.finditer(r'\b_catCard\s*\(', src):
        i = src.index('(', m.end() - 1)
        j = match_paren(src, i)
        body = src[i + 1:j]
        tap = arg_of(body, 'onTap') or ''
        md = re.search(r'\b([A-Z]\w*Page)\s*\(', tap)
        if not md:
            continue      # _catCard 的定义（Widget _catCard({...})）不是调用，跳过
        out.append({'kind': 'cat',
                    'label': label_of(arg_of(body, 'title')),
                    'sub': label_of(arg_of(body, 'desc')),
                    'dest': md.group(1) if md else '',
                    'exprs': [tap]})
    for m in re.finditer(r'\bSettingsEntryTile\s*\(', src):
        i = src.index('(', m.end() - 1)
        j = match_paren(src, i)
        if j < 0:
            continue
        body = src[i + 1:j]
        tap = arg_of(body, 'onTap') or ''
        md = re.search(r'\b([A-Z]\w*Page)\s*\(', tap)
        if not md:
            continue
        lab = label_of(arg_of(body, 'title'))
        if not lab or lab[0] is None:
            continue
        out.append({'kind': 'entry', 'label': lab,
                    'sub': label_of(arg_of(body, 'desc')),
                    'dest': md.group(1), 'exprs': [tap]})
    for m in re.finditer(r'\bGestureDetector\s*\(', src):
        i = src.index('(', m.end() - 1)
        j = match_paren(src, i)
        if j < 0:
            continue
        body = src[i + 1:j]
        tap = arg_of(body, 'onTap') or ''
        md = re.search(r'\b([A-Z]\w*Page)\s*\(', tap)
        if not md:
            continue                      # 只收「跳到某页」的入口（QQ 群等不含页面，略）
        keys = ARB_BYKEY.findall(body) + \
            [x.group(1) for x in re.finditer(r'S\.of\(context\)\.(\w+)', body)]
        if not keys:
            continue
        out.append({'kind': 'entry',
                    'label': ('key', keys[0]),
                    'sub': ('key', keys[1]) if len(keys) > 1 else (None, None),
                    'dest': md.group(1),
                    'exprs': [tap]})
    return out


def shell_title(src):
    m = re.search(r'SettingsPageShell\s*\(', src)
    if not m:
        return (None, None)
    i = src.index('(', m.end() - 1)
    j = match_paren(src, i)
    body = src[i + 1:j]
    return (label_of(arg_of(body, 'title')), label_of(arg_of(body, 'subtitle')))


def controllers(src):
    """_name = TextEditingController(text: <expr>) → {_name: expr}"""
    out = {}
    for m in re.finditer(r'\b(\w+)\s*=\s*TextEditingController\s*\(', src):
        i = src.index('(', m.end() - 1)
        j = match_paren(src, i)
        if j < 0:
            continue
        t = arg_of(src[i + 1:j], 'text')
        if t:
            out[m.group(1)] = t
    return out


def assemble(raw_items, ctls):
    seq, cur = [], None
    for e in raw_items:
        if '_section' in e:
            cur = dict(e['_section'])
            seq.append(cur)
            continue
        if cur is None:
            cur = {'title': (None, None), 'subtitle': (None, None),
                   'note': None, 'items': []}
            seq.append(cur)
        it = dict(e)
        exprs = list(it.get('exprs') or [])
        if it.get('ctl') and it['ctl'] in ctls:
            # 控制器初值最精确（'${st.filterRadius}'），优先于 onChanged 正文里的噪声链
            exprs = [ctls[it['ctl']]] + exprs
        fld = it.pop('field_tag', None) or find_field(exprs)
        it['field'] = fld
        dft, typ = lookup_default(fld)
        if dft in NESTED:          # 常量名（kAcnServerPort）→ 真值
            dft = NESTED[dft]
        if fld.startswith('feature.'):
            dft, typ = 'true', ''      # 自选模块默认全开
        it['default'], it['type'] = dft, typ
        if it['kind'] == 'SettingsChoice' and it.get('opt_values'):
            # 默认那一档的文案（选项序号对得上就对，对不上就照原样印值）
            vals = it['opt_values']
            if it['default'] in vals and len(vals) == len(it.get('opts') or []):
                it['def_key'] = it['opts'][vals.index(it['default'])]
        lab = it.get('label') or (None, None)
        if lab[0] == 'lit' and '$' in (lab[1] or ''):
            continue   # 运行时拼接的标签（'$name$badge'）不进文档
        cur['items'].append(it)
    return seq


def build():
    pages = []

    # ── 设置总览（settings_page.dart）──
    hub_path = os.path.join(ROOT, 'lib/settings_page.dart')
    hub_src = io.open(hub_path, encoding='utf-8').read()
    hub_items = scan_hub(hub_src)
    pages.append({'file': 'lib/settings_page.dart', 'cls': 'SettingsPage',
                  'title': ('key', 'settings'), 'subtitle': ('key', 'settingsDesc'),
                  'sections': [{'title': (None, None),
                                'subtitle': (None, None), 'note': None,
                                'items': [dict(h, kind='hub_' + h['kind'])
                                          for h in hub_items]}]})

    # ── settings_pages.dart：按 class 切 7 页 ──
    rel = 'lib/settings_pages.dart'
    src = io.open(os.path.join(ROOT, rel), encoding='utf-8').read()
    lines = src.split('\n')
    starts = []
    for i, l in enumerate(lines):
        m = re.match(r'class\s+(\w*SettingsPage)\s+extends', l)
        if m:
            starts.append((m.group(1), i))
    bounds = {}
    for idx, (name, ln) in enumerate(starts):
        end = starts[idx + 1][1] if idx + 1 < len(starts) else len(lines)
        bounds[name] = (ln, end)
    ctls = controllers(src)
    for cls, catkey in CAT_KEYS.items():
        if cls not in bounds or cls == 'CheckUpdatePage':
            continue
        a, b = bounds[cls]
        body = '\n'.join(lines[a:b])
        seq = assemble(scan(body), ctls)
        if cls in KEEP_SECTION_KEYS:
            keep = KEEP_SECTION_KEYS[cls]
            seq = [s for s in seq if s['title'] and s['title'][1] in keep]
        if cls == 'DeviceSettingsPage' and not any(s['items'] for s in seq):
            continue   # 转发页：内容在 device_page.dart（单独收录）
        pages.append({'file': rel, 'cls': cls,
                      'title': ('key', catkey), 'subtitle': ('key', catkey + 'Desc'),
                      'sections': seq})

    # ── 单页文件 ──
    singles = []
    for rel in SINGLE_FILES:
        path = os.path.join(ROOT, rel)
        if not os.path.exists(path):
            continue
        src = io.open(path, encoding='utf-8').read()
        seq = assemble(scan(src), controllers(src))
        t, sub = shell_title(src)
        if not t:
            t, sub = SHELL_FALLBACK.get(rel, (None, None))
        singles.append({'file': rel, 'cls': rel.split('/')[-1],
                        'title': t, 'subtitle': sub, 'sections': seq})

    # 需要跟在某个分组页后面时先插队，其余按 SINGLE_FILES 顺序拼在后面
    late = []
    for sp in singles:
        anchor = INSERT_AFTER.get(sp['file'])
        pos = None
        if anchor:
            for i, p in enumerate(pages):
                if p['cls'] == anchor or p['file'] == anchor:
                    pos = i + 1
                    break
        if pos is None:
            late.append(sp)
        else:
            pages.insert(pos, sp)
    pages.extend(late)
    return pages


def clean(s):
    """arb 占位符（{n} / $name）在文档里没有意义，替换成省略号。

    只剩占位符、或者去掉占位符就剩一个量词的（`{n} 条`），干脆留空：
    印成「… 条」比不印更让人看不懂。
    """
    if not s:
        return ''
    filled = len(re.findall(r'\{[^}]*\}|\$[A-Za-z_]\w*', s))
    s = re.sub(r'\{[^}]*\}', '…', s)
    s = re.sub(r'\$[A-Za-z_]\w*', '', s).strip()
    if not re.search(r'[^\s…·/、，（）()\-—]', s):
        return ''
    if filled and len(re.findall(r'[\u4e00-\u9fffA-Za-z0-9]', s)) < 3:
        return ''
    return s


def render(pages, lang):
    def L(pair):
        if not pair or pair[0] is None:
            return ''
        return clean(txt(pair[1], lang)) if pair[0] == 'key' else clean(pair[1])

    out = []
    for p in pages:
        o = {'file': p['file'], 'cls': p['cls'], 'title': L(p['title']),
             'subtitle': L(p['subtitle']), 'sections': []}
        for s in p['sections']:
            so = {'title': L(s['title']), 'subtitle': L(s['subtitle']),
                  'note': L(s.get('note')), 'items': []}
            for it in s['items']:
                so['items'].append({
                    'kind': it['kind'],
                    'label': L(it.get('label')),
                    'sub': L(it.get('sub')),
                    'trailing': L(it.get('trailing')),
                    'hint': L(it.get('hint')),
                    'tip': L(it.get('tip')),
                    'dest': it.get('dest') or '',
                    'field': it.get('field') or '',
                    'default': it.get('default') or '',
                    'type': it.get('type') or '',
                    'fold': L(it.get('fold')['title']) if it.get('fold') else '',
                    'opts': [L(('key', k)) for k in (it.get('opts') or [])],
                    'def_key': L(('key', it['def_key'])) if it.get('def_key') else '',
                })
            o['sections'].append(so)
        out.append(o)
    return out


def main():
    pages = build()
    if '--summary' in sys.argv:
        total = 0
        for p in pages:
            n = sum(len(s['items']) for s in p['sections'])
            total += n
            print('%-28s %s · 分节 %d · 控件 %d' % (
                p['file'].split('/')[-1], txt(p['title'][1], 'zh')
                if p['title'][0] else p['cls'], len(p['sections']), n))
            for s in p['sections']:
                st = txt(s['title'][1], 'zh') if s['title'][0] else '(无标题)'
                subs = []
                for it in s['items']:
                    lab = clean(txt(it['label'][1], 'zh')) if it.get('label') else '?'
                    subs.append('%s[%s=%s]' % (
                        lab, it.get('field') or '-', clean(it.get('default') or '')))
                note = ' 📌' if s.get('note') else ''
                print('    · %s%s: %s' % (st, note,
                                          ' | '.join(subs) if subs else '(空)'))
        nod = [it for p in pages for s in p['sections'] for it in s['items']
               if it['kind'] not in ('hub_cat', 'hub_entry', 'SettingsNavRow',
                                     'SettingsRow2', '_action') and not it['default']]
        print('控件总数 %d | 顶层默认值 %d | 嵌套默认值 %d | 无默认值的设置项 %d'
              % (total, len(TOP), len(NESTED), len(nod)))
        return

    data = {
        'pages': {lang: render(pages, lang) for lang in LANGS},
        'counts': {'items': sum(
            sum(len(s['items']) for s in p['sections']) for p in pages),
            'pages': len(pages)},
    }
    out_path = os.path.join(ROOT, 'tool', '_settings_extract.json')
    json.dump(data, io.open(out_path, 'w', encoding='utf-8'),
              ensure_ascii=False, indent=1)
    print('wrote %s (%d pages, %d items)'
          % (out_path, data['counts']['pages'], data['counts']['items']))


if __name__ == '__main__':
    main()
