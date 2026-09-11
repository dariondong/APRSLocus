# 荣誉 / 称号维护指南 Honors Guide

> 面向维护者：**授予荣誉**、**新增称号**的完整流程与校验清单。
> 数据源：`docs/members.json`（App 与官网运行时拉取，改完推送即生效，通常无需发版）。

---

## 📋 总览

| 场景 | 改动文件数 | 是否需发版 |
|---|---|---|
| **① 授予已有称号**（最常见） | 1（`docs/members.json`） | ❌ 不需要 |
| **② 新增一个称号** | 7（`docs/` + `lib/`） | ✅ **需要**（`lib/` 那 3 处） |
| **③ 上赞助墙**（见文末，独立于称号） | 5 | ❌ 不需要 |

**称号（honor）** 与 **成员（member）** 是两层概念：

- `honors`：称号的**定义**（叫什么、什么颜色、什么图标、诗意描述）
- `developers` / `earlyMembers`：**谁**拥有**哪些**称号（`honors` 数组 + `primary` 主展示）

---

## ① 授予已有称号

只改 `docs/members.json` 一个文件。

### 步骤

1. 在 `developers`（默认称号 `kaishan`）或 `earlyMembers`（默认称号 `earlyMember`）里找到该呼号
2. 往它的 `honors` 数组**追加**称号 key
3. `primary` 按惯例处理（见下）
4. `version` +1、`updated` 改成当天（仅人工追溯，见「易错点」）
5. `git commit` → `git push` → 等 Pages 部署（约 1 分钟）后线上即生效

### 示例

```jsonc
{
  "call": "BD1FEH",
  "who": { "zh": "BD1FEH", "zh-TW": "BD1FEH", "en": "BD1FEH" },
  "role": { "zh": "早期成员", "zh-TW": "早期成員", "en": "Early member" },
  "brief": { "zh": "…", "zh-TW": "…", "en": "…" },
  "honors": ["earlyMember", "jadeGift"],   // ← 追加在这里
  "primary": "earlyMember",                 // ← 主展示称号
  "grp": "test",
  "c": "#B08A34"
}
```

### `primary` 怎么定

`primary` 是**呼号旁默认展示的那一枚**。App 的取值优先级是：

> 用户手动选择 > `members.json` 的 `primary` > `honors` 里的第一个

惯例（以现有数据为准）：**追加称号时一般保持原 `primary` 不变**，不抢原主展示。

> 参考：`[earlyMember, jadeGift]` 组合共 5 人，其中 4 人保持 `primary = earlyMember`
> （BA4JLD / BG7ORC / BG9KAG / BA4IUD），仅 BA3MDC 用 `jadeGift`。

### `role` 要不要跟着改

**不要。** `role` 是独立的人类可读描述字段（如「功能测试 · 赞助」「AI 算力支持」），
**不镜像 `honors`**。对照证据：上表 4 位同组合持有者的 `role.zh` 全是「早期成员」。

### `brief`（寄语）

一句诗意化文案，三语。**每人应各不相同**——历史上出现过大批成员共用同一句模板文案的情况，
新增/整理时请顺手检查。

### 推荐用脚本改（避免手改 44 条 JSON 出错）

```python
import json, io, collections
p = 'docs/members.json'
d = json.loads(io.open(p, encoding='utf-8').read(),
               object_pairs_hook=collections.OrderedDict)

m = [x for x in d['earlyMembers'] if x['call'] == 'BD1FEH'][0]
assert 'jadeGift' not in m['honors']          # 防重复授予
m['honors'] = ['earlyMember', 'jadeGift']

d['version'] += 1
d['updated'] = '2026-09-10'
io.open(p, 'w', encoding='utf-8').write(
    json.dumps(d, ensure_ascii=False, indent=2) + '\n')
json.loads(io.open(p, encoding='utf-8').read())   # 语法自检
```

---

## ② 新增一个称号（7 处登记点）

⚠️ **这是最容易漏的地方**：称号需要同时在各端「登记」，漏一处就会出现
「App 里看得到但没图标」「官网排序不对」「离线不显示」等局部失灵。

以最近新增的 `sower`（播种）为**完整范例**，逐处对照：

### 定义与展示

| # | 文件 | 位置 | 作用 |
|---|---|---|---|
| 1 | `docs/members.json` | `honors.<key>` | **唯一真源**：名称 / 描述 / 颜色 / 图标名 |
| 2 | `lib/early_member.dart` | `Honor.iconMap` | 图标名 → Material 图标 |
| 3 | `lib/early_member.dart` | `kHonorOrder` | App 离线兜底**排序** |
| 4 | `lib/early_member.dart` | `_defaultHonorDefs` | App 离线兜底**定义** |
| 5 | `docs/member-card.html` | `HONOR_DEFS` | 官网会员卡兜底 |
| 6 | `docs/member-card.html` | `honorOrder` | 官网荣誉墙排序 |
| 7 | `docs/badge.html` | `ICONS` | 徽章专属页的 SVG 图标 |

### 1. `docs/members.json` → `honors`

```jsonc
"iSelfReliant": {
  "zh": "i力更生",
  "zh-TW": "i力更生",
  "en": "iSelf-Reliant",
  "desc": {
    "zh": "不求现成的果实，亲手编译一粒种子，让它在苹果的园子里长成一座信标。",
    "zh-TW": "不求現成的果實，親手編譯一粒種子，讓它在蘋果的園子裡長成一座信標。",
    "en": "Rather than wait for ripened fruit, they compiled the seed themselves — and let it grow into a beacon in Apple’s orchard."
  },
  "color": "#8E8E93",
  "icon": "iSelfReliant"     // 可选；与 lib 的 iconMap key 同一命名空间
}
```

> **App 只读 `zh` 和 `desc.zh`**；`zh-TW` / `en` 仅供**官网**使用。
> 也就是说：只填 `zh` 时 App 正常、官网繁体/英文会回落——但请务必三语齐全。

### 2. `lib/early_member.dart` → `iconMap`

```dart
static const Map<String, IconData> iconMap = {
  // …
  'sower': Icons.eco_rounded,
  'iSelfReliant': Icons.terminal_rounded,   // 新增
};
```

### 3. `lib/early_member.dart` → `kHonorOrder`

```dart
const List<String> kHonorOrder = [
  // …
  'sower',
  'iSelfReliant',   // 新增
];
```

### 4. `lib/early_member.dart` → `_defaultHonorDefs` ⚠️ **最容易漏**

```dart
'iSelfReliant': const Honor('iSelfReliant', 'i力更生',
    '不求现成的果实，亲手编译一粒种子，让它在苹果的园子里长成一座信标。',
    Color(0xFF8E8E93), Icons.terminal_rounded),
```

**为什么不能漏**：取用处 `honorsOf()` / `primaryHonorOf()` 都带空判断
（`_honorDefs[k] != null` / `.whereType<Honor>()`），缺条目时该称号会被**整条跳过** ——
表现为「`members.json` 还没拉到之前（**离线则永久**）徽章完全不显示」，
而不只是少个图标。在线定义与本地兜底是 `putIfAbsent` 合并（**在线优先**），
所以本地这条只在离线/加载前生效，但必须有。

### 5. `docs/member-card.html` → `HONOR_DEFS`

```js
iSelfReliant:{zh:"i力更生","zh-TW":"i力更生",en:"iSelf-Reliant",color:"#8E8E93"}
```

### 6. `docs/member-card.html` → `honorOrder`

```js
const honorOrder=["kaishan","developer","earlyMember","mostBrain","firstFix",
                  "jadeGift","sower","iSelfReliant"];
```

### 7. `docs/badge.html` → `ICONS`

```js
iSelfReliant:'<path d="M4.5 5h15v14h-15zM8 9.5l3 3-3 3M13.5 15.5h3"/>'
```

> 24×24 viewBox，只写 `<path>`，外层 `<svg>` 与描边样式由页面统一提供。

### 已占用配色（新增时避免撞色）

| key | 名称 | 颜色 |
|---|---|---|
| `kaishan` | 开山 | `#E67E22` |
| `developer` | 开发人员 | `#1D6FF2` |
| `earlyMember` | 早期成员 | `#B08A34` |
| `mostBrain` | 最强大脑 | `#0EA5C4` |
| `firstFix` | FIRST FIX · 至高荣誉 | `#C9A227` |
| `jadeGift` | 赠我以琼琚 | `#0EA5B7` |
| `sower` | 播种 | `#2E9E5B` |
| `iSelfReliant` | i力更生 | `#8E8E93` |

---

## ③ 上赞助墙（与称号**相互独立**）

> ⚠️ **授予 `jadeGift`（赠我以琼琚）称号 ≠ 上赞助墙。**
> 两者是**完全独立的数据**：称号在 `members.json`，赞助墙在 `sponsors.json`
> ＋ 官网 HTML 里**写死**。只改一个会出现「有称号但赞助墙看不到」。

需要同步 **5 处**：

| # | 文件 | 位置 |
|---|---|---|
| 1 | `docs/sponsors.json` | `sponsors[]` 追加 `{kind, name, desc}`（App 数据源） |
| 2 | `docs/index.html` | 「赞助」段落里追加 contributor 块 |
| 3 | `docs/en/index.html` | 「Sponsors」段落 |
| 4 | `docs/zh-TW/index.html` | 「贊助」段落 |
| 5 | `lib/sponsor_page.dart` | 内置**兜底名单**（离线时用） |

`kind` 取值与图标（App 端 `_kindIcon`）：

| kind | 图标 | 图标 |
|---|---|---|
| `group` | 群组 | `Icons.group_rounded` |
| `coffee` | 赞助/咖啡 | `Icons.local_cafe_rounded` |
| `jade` | 赠我以琼琚 | `Icons.card_giftcard_rounded` |
| `school` | 学校/社团 | `Icons.school_rounded` |
| 其他 | 兜底 | `Icons.favorite_rounded` |

官网 contributor 块模板（注意各语言 `c-role` 文案不同）：

```html
<span class="contributor">
  <span class="avatar" style="background:linear-gradient(135deg,#0ea5b7,#0b7285)">F</span>
  <span><span class="c-name">BD1FEH</span><span class="c-role">赠我以琼琚</span></span>
</span>
```

- `avatar` 字母惯例：**呼号数字段之后的首字母**（`BA4IUD→I`、`BA4JLD→J`、`BG7ORC→O`）
  —— 少数历史条目不一致（如 `BG4LZY→I`）、作者用名字首字母（`BG7LZQ (Darion)→D`），
  但新人按上述惯例即可
- `sponsors.json` 请把「每一位支持者 / everyone」这类总结条目**始终放在末位**

---

## ✅ 提交前校验清单

```bash
# 1) JSON 合法性
python3 -c "import json;json.load(open('docs/members.json',encoding='utf-8'));print('json ok')"

# 2) HTML 内嵌 JS 括号平衡（有字符串内的括号，只看基线是否与改动前一致）
python3 - <<'PY'
for f in ['docs/member-card.html','docs/badge.html','lib/early_member.dart']:
    s=open(f,encoding='utf-8').read()
    print(f, 'braces', s.count('{')-s.count('}'),
             'parens', s.count('(')-s.count(')'),
             'brackets', s.count('[')-s.count(']'))
PY

# 3) 与既有称号逐处对照计数（新增称号时用；数字应一致）
#    仅 members.json 允许 +1，因为 primary 也指向新称号
for f in docs/members.json lib/early_member.dart docs/member-card.html docs/badge.html; do
  printf '%s  sower=%s  <新key>=%s\n' "$f" "$(grep -c sower $f)" "$(grep -c <新key> $f)"
done

# 4) 全仓兜底搜索，确认没有第 8 处登记点
grep -rn "sower" . | grep -v '^./build/' | grep -v '^./.git/' | grep -v CHANGELOG.md
```

另外，改 `lib/` 下的 Dart 后记得：

```bash
flutter analyze   # 或交给 CI
```

---

## 🕐 生效时机（重要）

| 改动 | 生效方式 |
|---|---|
| `docs/members.json`、两个 `.html` | **运行时拉取 → 推送后约 1 分钟线上生效，无需发版** |
| `lib/early_member.dart`（第 2/3/4 处） | **编译进 App → 必须发版** |

所以**只改 `members.json` 给某人追加称号**是立刻可用的；
但**新增称号**如果不同时改 `lib/` 并**发版**，会出现：

- 徽章**能看到**（走在线定义）
- 但 App 里**图标回退成通用奖杯** ⚠️
- 且**离线时不显示** ⚠️

这不是 bug，是本地兜底未登记的表现。要体验完整效果请发版
（发版流程见 `CONTRIBUTING.md` 与 `.github/workflows/build-release.yml`）。

---

## ⚠️ 易错点

1. **`members.json` 是纯 JSON，不能写注释**（`//` 会让解析直接失败）
2. **`version` / `updated` 不参与任何逻辑** —— App 与官网都**不读**这两个字段，
   纯人工追溯用。但按仓库惯例每次改动 `version` +1，并写进 commit 标题（如 `members.json v41`）
3. **`honors` 顺序有意义**：App 优先用 `members.json` 里 `honors` 的**键序**做展示顺序，
   本地 `kHonorOrder` 只是兜底
4. **`icon` 命名空间共用**：`members.json` 的 `icon` 与 `lib` 的 `iconMap` key 必须一致；
   未命中时按 key 再映射一次，仍未有则用通用奖杯图标
5. **别漏第 4 处 `_defaultHonorDefs`** —— 该处为空判断而非默认值，漏了就整条不显示
6. **`brief` 请勿复制模板** —— 历史上多位成员共用同一句文案，容易看出是漏改

---

## 📎 相关文件

| 文件 | 说明 |
|---|---|
| `docs/members.json` | 成员与称号数据（唯一真源） |
| `docs/sponsors.json` | 赞助名单（App 赞助页数据源；官网赞助墙另在 HTML 写死） |
| `docs/member-card.html` | 官网会员卡（个人页） |
| `docs/badge.html` | 徽章专属页 `badge.html?honor=<key>` |
| `docs/firstfix.json` | FIRST FIX 至高荣誉的授勋名单（独立文件） |
| `lib/early_member.dart` | App 侧：称号定义、兜底、在线拉取与解析 |
| `lib/honor_wall_page.dart` | App 内荣誉墙页面 |
| `docs/index.html` | 官网首页（含荣誉墙入口） |
