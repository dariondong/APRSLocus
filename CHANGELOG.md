# 更新日志

## [1.6.115] - 2026-09-17

### 🔴 修「小组件加载失败」：一个方法名写在了不支持的控件上，整个组件报废
### Fixed "widget failed to load": one method name called on a view that doesn't have it

**现象**：桌面小组件显示「小组件加载失败」（启动器的 problem-loading-widget 占位），
4 档全部失效，整个组件不可用。**这是我上一版引入的回归。**

**根因（已对 AOSP 源码核实）**：

```kotlin
views.setInt(cell.dot, "setColorFilter", color)   // ← 这一行
```

`setColorFilter` **只存在于 `ImageView`**：

| 类 | `setColorFilter` 声明数 |
|---|---|
| `android.view.View` | **0** |
| `android.widget.TextView` | **0** |
| `android.widget.ImageView` | 3 |

而那个级别圆点**只能是 `TextView`** —— RemoteViews 不允许原生 `<View>`
（会抛 `android.view.View is not allowed`），所以我上一版把圆点做成了 `TextView`。
于是这行在运行时抛 `NoSuchMethodException` → `RemoteViews.apply()` 抛
`ActionException` → 启动器渲染自己的失败占位。

**我错在哪**：我以为「`setInt` 方法名写错最多是那一处不生效、会优雅降级」。
**不会** —— `RemoteViews` 的失败是**整块**的，一处 `ActionException` 就让
整个组件报废。这也是为什么上一版（v1.6.113 那个「挤」的版本）能正常显示：
它没用 `setColorFilter`，只用了 `setTextColor` / `setBackgroundResource`
（这两个分别存在于 `TextView` 和 `View`，是安全的）。

**修法**：改成**换 drawable** —— 生成 4 张记色圆点
`aw_dot_{danger,warn,good,tip}.xml`，运行时按级别
`setInt(dot, "setBackgroundResource", DOT_BY_LEVEL[level])`。
「换 drawable」是 RemoteViews 里唯一可靠的换色手段，和危险行换红底是同一招。
认不出的 level 退回中性白圆点（`?: R.drawable.aw_dot`），不把 0 传给
`setBackgroundResource` —— 那样会把背景清掉、圆点整个消失。

圆点颜色 = 面板级别原色往白提亮 35%，与级别文字**同一个值**
（`widgetTipTextArgb` 与生成脚本的 `SEVERITY_DOTS` 对齐，由测试精确断言）。
顺带把提亮算法从 `Color.lerp` 改成**整数分量运算**：浮点通道会让 235.5
这类边界值差 1（实测 danger 得 `#EB6C88`，Python 侧算出 `#EC6C88`），
整数运算两边结果确定一致，于是这个跨语言契约可以精确断言而不留容差。

**为什么原来的检查没拦住它（这才是更该记的部分）**

我上一版写了 `tool/check_android_res_ids.py` 专门核对 `setInt` 的字符串方法名，
而且它当时是**通过**的。原因：那张方法名白名单是**我自己手写的**，我把
`setColorFilter` 也写了进去 —— 名字对得上就放行。**名字级别的白名单根本管不了
「这个方法在 `这个控件类型` 上存不存在」，而那才是关键。**

现在改成**按控件类型校验**：从布局里读出每个 `@+id` 的控件类型，
再把 `setInt` 的目标 id 解析成类型（包括把 `cell.dot` 这种字段名按
`TipRow(row, dot, emoji, level, text)` 的实参顺序还原成具体 id），
最后对照「方法 → 定义它的类」的表：

- `setBackgroundResource` / `setBackgroundColor` → `View`（任何控件都行）
- `setTextColor` → `TextView`
- `setColorFilter` → `ImageView`（**只有它**）

**并且我验证了这个检查真的能拦住这次的事故**：把有 bug 的那一版
（`git show 5bedb2e:...WeatherWidgetProvider.kt`）喂给新检查器，
它在 3 个调用点、共 15 条上全部报红。一个从不开火的检查等于没有检查，
所以这一步必须做。

**同一轮测试还抓出另一个静默 bug**：`compactRows` 的外层对象漏了 `level` 字段，
于是 Kotlin 的 `optString("level")` 取到空串 → 圆点退回中性白 →
小尺寸档的级别颜色**静默丢失**（不报错、只是不好看）。已补上，
并加了一条「快照里出现的 level 只有 Kotlin 认识的那 4 个」的测试 ——
将来 `weather.dart` 新增级别时它会红，而不是静默少个颜色。

**另外修了生成脚本自身的一个错**：`dot()` 把颜色写死成 `#FFFFFF`，
导致 `aw_dot_danger.xml` 的**注释写着 `#EC6C88`、实际渲染是白色**。
注释与产物不一致比没有注释更坏（看代码的人会以为颜色已经对了，于是不去查），
所以生成器现在自检「注释里的颜色必须真出现在产物里、记色圆点不能还是白色」。

**测试**：`test/app_widget_test.dart` 34 项（+2：跨语言颜色契约、level 集合护栏）。

**诚实说明**：本机没有 Android SDK，Android 侧**仍未本地编译验证**。
这次的根因是查 AOSP 源码 + 对照你设备上的现象定位的，修复方式（换 drawable
+ `setBackgroundResource`）正是上一版在真机上**确实渲染出来过**的那条路径。
但**我无法在本机复现或验证「装到手机上能显示」**，所以这次修复**必须在你
的设备上确认**；CI 只能保证它编译得过。

---

**What happened**: the home-screen widget showed the launcher's
problem-loading-widget placeholder ("小组件加载失败"); all four tiers were dead.
**This was a regression I introduced in the previous version.**

**Root cause** (verified against the AOSP sources): `views.setInt(cell.dot,
"setColorFilter", color)`. `setColorFilter` exists **only on `ImageView`** —
`android.view.View` declares it 0 times, `android.widget.TextView` 0 times,
`android.widget.ImageView` 3 times. And that severity dot can **only** be a
`TextView`, because RemoteViews rejects a plain `<View>` outright
(`android.view.View is not allowed`). So the call threw `NoSuchMethodException`,
`RemoteViews.apply()` wrapped it in an `ActionException`, and the launcher drew its
failure placeholder.

**Where I went wrong**: I assumed a bad `setInt` method name would degrade gracefully —
that only that one bit of styling would be lost. **It does not.** A `RemoteViews`
failure is all-or-nothing: a single `ActionException` kills the whole widget. That is
also why the earlier revision (the cramped one) displayed fine — it never called
`setColorFilter`, only `setTextColor` and `setBackgroundResource`, which do exist on
`TextView` and `View` respectively.

**The fix**: swap drawables instead of tinting. Four per-severity dots
(`aw_dot_{danger,warn,good,tip}.xml`) are generated, and at runtime the provider does
`setInt(dot, "setBackgroundResource", DOT_BY_LEVEL[level])` — the only reliable way to
change colour in RemoteViews, the same trick already used for the danger row's red
background. An unrecognised level falls back to the neutral dot rather than passing 0
to `setBackgroundResource` (which would clear the background and make the dot vanish).

**Why my own checker didn't catch it** — the more important lesson. The previous
version shipped `tool/check_android_res_ids.py` specifically to validate `setInt`
method names, and it **passed**. The reason: that whitelist was **hand-written by me**,
and I put `setColorFilter` in it — a name-level whitelist simply cannot express
"does this method exist on *this view type*", which was the actual question.

It now validates **by view type**: it reads each `@+id`'s class from the layouts,
resolves each `setInt` target to a type (including reconstructing `cell.dot`-style
field references from the `TipRow(row, dot, emoji, level, text)` argument order), and
checks against a "method → defining class" table (`setBackgroundResource`/`setBackgroundColor`
→ `View`; `setTextColor` → `TextView`; `setColorFilter` → `ImageView` only).

**And I verified the check actually catches this incident**: feeding the buggy revision
(`git show 5bedb2e:...`) to the new checker reports all 15 violations across the 3 call
sites. A check that never fires is no check at all, so that step is not optional.

**The same test round caught a second silent bug**: `compactRows` omitted the `level`
field on its outer object, so Kotlin's `optString("level")` returned empty, the dot fell
back to neutral white, and severity colours were **silently lost** on the small tiers (no
error, just less informative). Fixed, plus a test asserting that every `level` the
snapshot can emit is one Kotlin knows — so a new severity in `weather.dart` turns the test
red instead of quietly losing a colour.

**Also fixed a bug in the generator itself**: `dot()` hard-coded `#FFFFFF`, so
`aw_dot_danger.xml`'s **comment said `#EC6C88` while the file rendered white**. A comment
that disagrees with the artifact is worse than no comment — the reader assumes the colour
is already right and doesn't look. The generator now self-checks that the colour named in
the comment actually appears in the output, and that per-severity dots are not still white.

**Tests**: `test/app_widget_test.dart` now has 34 cases (+2: the cross-language colour
contract, and the level-set guard).

**Honest caveat**: there is still **no Android SDK on this machine**, so the Android side
remains **not compile-verified locally**. This diagnosis came from the AOSP sources plus
the behaviour on your device, and the fix uses the very path (drawable swap +
`setBackgroundResource`) that the previous revision **did** successfully render on real
hardware. But **I cannot reproduce or verify "it displays on a phone" from here** — this
fix **needs confirmation on your device**; CI can only prove it compiles.


## [1.6.114] - 2026-09-17

### 📱 新增 Android 桌面小组件：可自由缩放，4 档尺寸自适应（天气 + 业余无线电提示）
### New resizable Android home-screen widget with 4 adaptive size tiers (weather + amateur-radio tips)

在手机主屏上放一块组件，一眼看到当前天气和**此刻该注意什么**，并可按主屏空间自由缩放：

```
 4×2 主面板    📍北京 [AQI 42 优]                       观测 14:30
              ┌──────────────┐  ┌──────┐ ┌──────┐
              │ 🌤 31° 晴     │  │💧45% │ │🌬3级 │
              │ 12°/25°      │  ├──────┤ ├──────┤
              └──────────────┘  │🌡1013│ │👁25km│
              ● 安全警示 ⚡ 雷雨天气：请勿在室外架设/操作天线！断开天线馈线…
              ● 通联机会 🌙 夜间 D 层消失：80/40m 吸收减小、噪声较低…

 2×4 小面板    竖长布局，提示可堆叠 3~5 条（最接近 App 内天气面板）
 2×2 紧凑档    温度 + 天气 + 只给「最要紧」的那一条
 4×1 单行档    一整条通栏：温度 + 天气 + 高低温 + 一条提示
```

**四个档位不是四套文案，而是同一份数据的四种排布**。缩放时自动换布局
（`WeatherWidgetProvider.tierFor`，优先用 `appWidgetWidthCells/HeightCells`）：

| 档位 | 格子 | 内容 |
|---|---|---|
| `tile` | 3~4×2 | 左温度 / 右 2×2 指标 / 底 2 条提示 |
| `tall` | 2×4 | 温度 + 指标 + 堆叠提示（**最像 App 面板**）|
| `compact` | 2×2~2×3 | 温度 + 天气 + 1 条最要紧的提示 |
| `row` | 3~4×1 | 单行：温度 + 天气 + 高低温 + 提示 |

**为什么第一版「又挤又不像面板」（记录教训）**

第一版把 4 条提示塞进 4 个窄列、每格约 60dp 宽，正文压到 8sp 还折三行。
根因是**照抄了「4 列 × 2 行」的字面意思，没有照抄面板的结构**：面板里
每条建议是**一整行通栏**（级别色圆点 + 图标级别 + 正文，正文 12sp），
把它拆成窄列就必然挤。这一版改成通栏堆叠行，与面板 `_tipRow` 同构。

另一个原因是**档位选错了**：4×2 只有 2 格高，塞完温度与指标后剩给提示的
高度只够 2 行。所以这一版**宁可少给两条**（只显示 2 条），也要让给出的两条
读得舒服 —— 完整列表点进 App 看。要 4 条提示就把组件拉到 2×4。

**组件不自己联网取天气**（这是最关键的设计决定，未变）

最直觉的做法是让 `AppWidgetProvider` 自己请求和风 API。**没这么做**，因为：

1. 和风密钥是**构建期**用 `--dart-define=QWEATHER_KEY` 注入 Dart 侧的，原生侧拿不到。
   为一个桌面组件把密钥再抄一份进 Kotlin（还得进 `local.properties`/Gradle 配置），
   等于凭空多出一个泄漏面，而且两处密钥一旦不同步就是「App 有天气、组件没有」。
2. 更要命的是**判定规则**：雷电/大风/低温/高湿/沙尘/波导/灰线这一整套火腿建议的
   逻辑、AQI 的本地化分级、3 日预报的解析，全都实现在 `lib/weather.dart` 里。
   在 Kotlin 重写一遍**必然**会与面板分叉 —— 同一份天气，面板说「注意」、
   桌面组件说「天气良好，适合架台」，这种 bug 极难发现，因为两边各自看都「对」。

所以数据是**单向推**的：Flutter 侧（`lib/app_widget.dart::AppWidgetBridge`）把一份
**已经算好、已经本地化**的快照 JSON 推给原生。Kotlin 侧**一条业务判断都没有**。

**那「自适应」是谁在决定？**——是**排版**在原生、**内容**在 Dart，二者分工明确：

- 原生侧只知道尺寸，所以由它决定「显示几条」「用哪一档长度的文案」；
- 但「哪几条」「每种长度具体是什么字」已经在 Dart 侧算好并排好序，
  原生只是「从前往后取 n 条」「从长到短挑第一个放得下的」。

小尺寸档放不下一整句建议，所以在 Dart 侧把每条建议**切成逐级变短的若干版本**
（`compactTipVariants`），例如：

```
雷雨天气：请勿在室外架设/操作天线！断开天线馈线，谨防雷击感应损坏设备
  → 雷雨天气：请勿在室外架设/操作天线！
  → 请勿在室外架设/操作天线！
  → 雷雨天气…
```

切分规则（全角冒号 `：` / 半角 `:` / 句末标点）是**中英文文案**的事，
属于本地化范畴，所以切分在 Dart 做、Kotlin 只挑选。短的版本带省略号收尾，
让人看出「还有下文」，而不是以为组件漏字了。

**指标格按天气切换名次**

面板里指标是平铺的通用清单（湿度·风向·气压·能见度·降水·露点…），
组件格子少（2×2 = 4 格），必须分主次：

| 天气 | 排在第一格 | 理由 |
|---|---|---|
| 雾 / 能见度 < 5km | 能见度 | 能不能出门架台，先看能见度 |
| 雨 / 雪 | 降水量 | 馈线防水与 1.2GHz 以上雨衰判断 |
| 低温 ≤5° | 露点 | 露点差小 → 结露短路，比体感更实用 |
| 高温 ≥30° | 湿度 | 对流天气与设备散热降额 |
| 常规 | 气压 | 大气波导与天气转折 |

**背景渐变与天气面板同源**：7 档背景（晴/多云/阴/雨/雷/雪/雾 × 浅色/深色）
由 `tool/gen_app_widget_drawables.py` 从**同一张调色板**生成，色值和
`lib/weather.dart::_fxGradient()` 逐色一致，避免「面板是深蓝雨夜、桌面组件是大晴天」。
改配色要改脚本，别手改 XML。

**踩到的 Android 坑（都写进注释了，以免日后重犯）**

1. **`<View>` 不能用在 RemoteViews 里** —— 原生 `View` 不在允许的 View 列表内，
   inflate 时抛 `android.view.View is not allowed`，整个组件变白块。
   撑宽度用的占位改成了 0dp 的 `TextView`。
2. **不能用 `<selector>` / ripple 当背景** —— RemoteViews 由系统进程 inflate，
   状态选择器会直接抛异常。所以「危险级提示行」是换一张 drawable
   （`aw_tile_danger`），不是加 selector。
3. **不能用 `styles.xml` 里的主题样式** —— 同理，未知属性直接崩。字号颜色只能就地写死。
4. **`match_parent` 高度在 `wrap_content` 的横向 LinearLayout 里不可靠** ——
   第一版提示行左边想放「竖色条」，靠 `height=match_parent` 跟满两行文字，
   一旦被测量成 0 高就整根消失。改成与面板一致的 **6dp 圆点**（`aw_dot` +
   `setColorFilter` 染色），没有这个风险。
5. **`IconData` 不能当 `const` map 的键** —— 它覆写了 `==`/`hashCode`，而常量 map
   的键要在编译期规范化，analyzer 报 `const_map_key_not_primitive_equality`。改 `final`。
6. **组件上不能用 Material 图标**（那是 App 的字体资源，组件进程里没有），
   所以所有图标在 Dart 侧映射成 emoji 随数据下发；这也和 `NotifHelper` 里
   `"📻 $from"` 的做法一致。

**顺带修掉一个自激隐患**

`WeatherCenter.load()` 失败时**不会更新 `updated`**（TTL 判据），但**仍会** `version.value++`。
如果同步器无条件跟着 `version` 再调 `load()`，就会转成「通知 → 加载 → 失败 → 通知」
的无限重试，把用户流量烧在「没定位 / 服务器宕了」这类必然失败的场景上。
现在：(a) 同步器只在**完全没有数据**时兜底加载；(b) 兜底带 2 分钟时间戳防自激；
(c) 数据过期的刷新交给顶栏胶囊 `WeatherBadge`，用户点组件打开 App 时它自然会拉，
拉完驱动同步器把新快照推给组件。

**新增工具（都不依赖 Android SDK）**

- `tool/gen_app_widget_layouts.py`：生成 4 档布局，并在**生成时自检**
  （白名单控件 / 标签闭合 / 不用 selector）。第一次写就漏了一个 `</LinearLayout>`，
  是 XML 解析器才告诉我的 —— 这种低级错误该由脚本挡住。
  自检还必须**先剥掉注释再扫**：注释里为了说明约束会写到 `<View>`、`<selector>`
  这些字面量，不剥就会把自己的说明文档判成违规。
- `tool/gen_app_widget_drawables.py`：从与面板同一张调色板生成 7 档×2 主题背景。
- `tool/check_android_res_ids.py`：机械核对 Kotlin 的资源引用，含两类
  **编译期全绿、运行时才炸**的问题：① `setInt(viewId, "setBackgroundResource", …)`
  这类**字符串方法名**；② **ResId 与布局配错** —— 把 `aw_t5_temp` 填进 tile 档的
  ResId 表，那个 id 在 `aw_widget_tile.xml` 里不存在，编译通过、运行时静默不显示。
  四档布局 × 各自约 30 个 id，人眼核对必然出错。现在 82 个引用逐一对照所属布局。
- `tool/ci_status.py`：查 Actions 运行状态。之前用一行流 `echo "$JSON" | python3 -c`
  时，GitHub 返回的大 JSON 里含控制字符，`json.load` 抛
  "Invalid control character"，把真正的状态信息淹没在一屏 traceback 里。

**测试**：`test/app_widget_test.dart` 从 21 项扩到 **32 项**。新增的 11 项盯住这次
改动最容易错的地方：指标格数量必须等于布局格子数（2×2 → 4）、指标名次随天气变化、
以及文案压缩的**排序契约**（必须从长到短，否则 Kotlin 会挑到放不下的长句）和
「每一版都是原文子串」（防止凭空造词）。这两个契约正是我在写的时候搞错的地方 ——
顺序按生成顺序而非长度排，测试当场就红了。

**诚实说明两点**

- 本机**没有 Android SDK**（只有 Flutter SDK），所以 Android 侧**未经本地编译验证**：
  Kotlin 语法、`RemoteViews` 白名单控件用法、资源引用是逐条按文档核对 + 用
  `check_android_res_ids.py` 机械对账的。**v1.6.113 的组件版本已由 CI 的
  Build Android APK 验证通过**（analyze / Windows / Android 三 job 全绿），
  本次重构沿用同一套约束与校验方式，但**最终仍以 CI 编译为准**。
- 组件**不会**在 App 关闭时自行更新天气（它没有密钥，见上）。打开 App（或点组件）
  就会刷新，顶栏的「观测 HH:mm」让这一点是可见的，而不是假装数据总是最新的。
- 时钟：`updatePeriodMillis` 取系统允许的最小值 30 分钟，它**不联网**，
  只是重渲染已有快照，顺带让组件在存储/数据异常后能自愈。

---

**What it is**: a home-screen widget showing current weather plus *what to watch out for
right now*, freely resizable, with four adaptive layouts:

```
 4×2 main    📍Beijing [AQI 42 Good]                   Observed 14:30
             ┌──────────────┐  ┌──────┐ ┌──────┐
             │ 🌤 31° Clear │  │💧45% │ │🌬3bft│
             │ 12°/25°      │  ├──────┤ ├──────┤
             └──────────────┘  │🌡1013│ │👁25km│
             ● Safety alert ⚡ Thunderstorms: do not erect antennas outdoors…
             ● Opening 🌙 D-layer gone: 80/40m absorption drops, low noise…

 2×4 tall    vertical; stacks 3–5 tips (closest to the in-app weather panel)
 2×2 compact temperature + conditions + only the single most important tip
 4×1 row     one full-width line: temperature + conditions + high/low + one tip
```

The four tiers are **not four sets of copy** — they are four arrangements of the same
data. The layout switches automatically as you resize (`WeatherWidgetProvider.tierFor`,
preferring `appWidgetWidthCells/HeightCells`).

**Why the first version was cramped and unlike the panel** (lesson recorded): it packed
4 tips into 4 narrow columns of ~60dp each, squeezing body text to 8sp over 3 lines. The
root cause was **copying the literal meaning of "4 columns × 2 rows" without copying the
panel's structure** — in the panel each tip is a **full-width row** (severity dot + icon
label + body, 12sp). Splitting that into narrow columns is guaranteed to be cramped. This
version uses full-width stacked rows, structurally the same as the panel's `_tipRow`. The
second cause was **picking the wrong tier**: a 4×2 widget is only 2 cells tall, and after
the temperature and metrics there is room for just 2 tip rows — so this version
**deliberately shows fewer tips** (2) and lets those two breathe. Want 4? Resize to 2×4.

**The widget does not fetch weather itself** (the key decision, unchanged): the QWeather
key is injected into Dart at build time via `--dart-define=QWEATHER_KEY` and is simply not
available to native code — copying it into Kotlin (and into `local.properties`/Gradle) adds
a whole new leak surface, and the copies drifting apart means "app has weather, widget
doesn't". More importantly, **every rule lives in Dart** — the storm/gale/cold/humidity/
dust/ducting/gray-line ham-advice logic, localised AQI grading, 3-day forecast parsing.
Reimplementing it in Kotlin **would** drift from the panel: same weather, panel says
"caution", widget says "great conditions" — the kind of bug that is very hard to find,
because each side looks correct alone. So data flows **one way**, and the native side
contains **not a single business decision**.

**So who decides "adaptive"?** Layout on the native side, content in Dart:

- Native is the only side that knows the size, so it decides *how many* tips and *which
  length variant* fits;
- but *which* tips and *what each variant says* is already computed and ordered in Dart;
  native merely takes "the first n" and "the first variant that fits, longest first".

Small tiers cannot fit a whole sentence, so each tip is **pre-sliced into progressively
shorter variants** in Dart (`compactTipVariants`): the takeaway sentence first, then the
part after the colon, then the part before it. The splitting rules (full-width `：` vs
half-width `:`, sentence-ending punctuation) are a matter of **Chinese/English copy**,
i.e. localisation, so splitting happens in Dart and native only picks. Shorter variants end
in an ellipsis so it reads as "there's more" rather than "the widget dropped words".

**Metric cells are ranked by weather**: a 2×2 grid has room for 4, so the first cell is
whatever matters most (fog → visibility; rain/snow → precipitation; ≤5°C → dew point;
≥30°C → humidity; otherwise pressure).

**Gradients share the panel's palette**: the 7 backgrounds × 2 themes are generated by
`tool/gen_app_widget_drawables.py` from the *same* palette as
`lib/weather.dart::_fxGradient()`, so you never get "dark blue rainy night in the panel,
sunny day in the widget".

**Android pitfalls hit** (all documented in comments): a plain `<View>` is **not** allowed
in RemoteViews (the whole widget goes blank); `<selector>`/ripple drawables throw during
RemoteViews inflation (so the danger row swaps to a different drawable); `styles.xml` theme
styles are unreadable by the system process; `match_parent` height inside a `wrap_content`
horizontal LinearLayout is unreliable — the first version's vertical accent bars could
measure to zero height and vanish, replaced by the panel's own 6dp coloured dot;
`IconData` cannot be a `const` map key because it overrides `==`/`hashCode`; and Material
icons are unavailable in the widget process, so icons ship as emoji from Dart (matching the
existing `"📻 $from"` convention in `NotifHelper`).

**A latent self-oscillation was fixed**: `WeatherCenter.load()` does **not** update
`updated` when the fetch fails (that is the TTL criterion) yet **still** bumps `version` —
an unconditional reload would spin in a "notify → load → fail → notify" loop, burning
mobile data on cases that cannot succeed. Now it only loads as a fallback when there is
**no data at all**, guarded by a 2-minute timestamp, and staleness refreshing is left to
the top-bar `WeatherBadge`.

**New tooling** (none of it needs an Android SDK): a layout generator that self-checks
(allowed views / tag balance / no selectors — it caught a missing `</LinearLayout>` I had
just written, and it must strip comments first, since the comments deliberately quote
`<View>` and `<selector>` to document the constraints); a drawable generator sharing the
panel palette; `check_android_res_ids.py`, which verifies Kotlin's resource references
including the two classes of bug that are **green at compile time and explode at runtime**
(string method names in `setInt`, and ResId/layout mismatches across the four tiers — 82
references cross-checked against their own layout); and `ci_status.py`, because the earlier
one-liner JSON pipeline choked on control characters and buried the status in a traceback.

**Tests**: `test/app_widget_test.dart` grew from 21 to **32** cases. The new ones target
exactly what this change was most likely to get wrong: metric count must equal the layout's
grid (2×2 → 4), metric ranking must follow the weather, and the copy-compression **ordering
contract** (longest first, or native picks an overflowing string) plus "every variant is a
substring of the original" (no invented words). Both contracts were things I got wrong while
writing it — the test went red immediately.

**Two honest caveats**: there is **no Android SDK on this machine**, so the Android side was
**not compile-verified locally** — Kotlin syntax, RemoteViews-allowed views and resource
references were checked against the docs and reconciled mechanically by the script above.
The previous widget revision **was** validated by CI's Build Android APK (analyze / Windows
/ Android all green); this refactor keeps the same constraints and validation, but **CI's
build remains the real gate**. And the widget **does not** update weather on its own while
the app is closed; opening the app (or tapping the widget) refreshes it, and the
"Observed HH:mm" in the header makes that visible rather than pretending the data is always
current.

## [1.6.113] - 2026-09-15

### ⚡ 修一个会「越用越卡」的累积性缺陷：APRS-IS 被反复重建 + socket 泄漏
### Fixed an accumulating defect that made the app get slower the longer it ran

**结论：有，而且是可以累积到很严重的卡顿。已经修掉。**

**机制**（三处凑在一起才发作）：

`lib/net/aprs_io.dart` 的 `connect()` 里：

```dart
final sock = await Socket.connect(...);
_sock = sock;             // ← 旧 _sock 引用被覆盖，从未 destroy()
_sub = sock.listen(...);  // ← 旧 _sub 被覆盖，从未 cancel()
```

而 `_connect()` 会**无条件**调用 `_connectAprsIs()`，后者**没有「已连接」检查**。
于是：

1. 只要有一条**已启用但连不上**的链路（未绑定设备、设备没开机、被设备冲突拦下…），
   重连定时器就会一直按 8→16→32→60 秒重试；
2. 每次重试都走一遍 `_connect()` → `_connectAprsIs()` → **新建一个 TCP 连接**，
   旧 socket 失去引用变成**孤儿**，但**它仍在继续把数据喂给解析管线**；
3. 于是同一条报文被重复处理 N 次，而 **N 随时间增长** —— 跑十分钟就有十几个
   孤儿连接。表现就是**越用越卡**（而且连接数不会自己降下来）。

**触发条件很常见**：数据来源是多选的，用户勾了 TNC 但还没绑设备（或设备没开），
就已经满足条件了。

**修复（四道）**

1. **`AprsIo.connect()` 先静默收掉旧连接再建新的** —— 从源头杜绝孤儿 socket。
   刻意用「静默」（不触发 `onDisconnected`），否则会误报一次断开、再排一次重连。
2. **`_connectAprsIs()` 增加「已经连着就别重建」守卫** —— 重连 tick 不该拆掉
   一条好好的 TCP 连接（那还会重发过滤器与身份帧）。
3. **`_connect()` 只连「当前没连着」的链路** —— 要重试的只是那条掉线的链路。
4. **新增 `_permanentlyDown()`**：把「重试也没用」的链路（未绑定设备 / 平台不支持 /
   被设备冲突拦下）算作「不必再重试」，让重连定时器不再空转。**「没权限」不算** ——
   用户授权后就能连上。

**诚实说明两点**

- 这三处缺陷**在 v1.6.107 就已存在**（我用 `git show v1.6.107:` 核对过 `_sock = sock`
  与 `_connectAprsIs` 的原文），**不是新引入的**；
- 但**我上一版（1.6.112）的修改把暴露面放宽了** —— 修好「断开后永不重连」之后，
  重连不再被任何条件跳过，于是走到这个泄漏路径的机会比以前多。这一版把它堵上了。

**还有一处我在修的过程中自己踩到的坑**（记录在此以免日后重犯）：我先给 `_connect()`
的三条链路都加了 `&& !_permanentlyDown(...)`，结果**一条已有测试立刻失败** ——
`_connectPkwdwpl()` 里那段「记录 `device-in-use` 错误」的代码**再也到不了**，
用户点连接会完全没有反馈。已改成：`_permanentlyDown` **只用于决定要不要再排重连**，
不用来决定要不要尝试连接（它的代价只是几个提前 return，不会空转）。

新增 1 项源码级护栏（`test/tnc_reconnect_guard_test.dart` → 3 项）：断言
`connect()` 必须先收旧连接再赋值、`_connectAprsIs` 必须有「已连着」守卫、
`_connect()` 必须用「未连上」条件包住每条链路、以及 `_allExpectedLinksUp` 必须
把永久失败的链路算作「不用再试」。

---

**Yes — there was, and it could accumulate into serious lag. Fixed.**

`AprsIo.connect()` overwrites `_sock` and `_sub` without releasing the previous values, and
`_connect()`/`_connectAprsIs()` had no "already connected" check. So any enabled link that
stays down (no device bound, radio off, blocked by a device conflict…) made the retry timer
fire every 8→16→32→60 seconds, and **each tick rebuilt the APRS-IS connection**: a new socket
was created while the old one became an orphan that *still fed the parser*. Every packet was
then processed N times, with N growing over time — the app got slower the longer it ran, and
nothing brought the connection count back down.

Four fixes: silently tear down the previous connection before reconnecting (at the source);
skip rebuilding APRS-IS when it is already up; only connect links that are actually down; and
treat "retrying cannot help" links (no device bound / unsupported / device conflict) as
nothing-left-to-do so the retry timer stops spinning. "No permission" is deliberately *not*
treated that way, since the user can fix it.

Two honest notes: these defects are **pre-existing** (verified against v1.6.107, not
introduced now) — but my previous release **widened the exposure** by making reconnection
never skippable, so this release closes the path it opened.

I also hit a real interaction while fixing it and documented it: adding `_permanentlyDown` to
the link-skip condition made an existing test fail, because `_connectPkwdwpl()`'s code that
records the `device-in-use` error became unreachable — leaving the user with no feedback.
`_permanentlyDown` now only decides whether to *schedule another retry*.

---

## [1.6.112] - 2026-09-15

### 🚨 找到「TNC 能发不能收」的真正原因（与 PKWDWPL 无关）
### The actual cause of "TNC transmits but receives nothing" (nothing to do with PKWDWPL)

**先纠正我上一版的判断。** 我把「能发不能收」归因为「TNC 与 PKWDWPL 绑定了同一台
设备、接收字节流被瓜分」。但用户提供的现象推翻了它：**在从未绑定过 PKWDWPL 设备
的情况下，TNC 同样收不到**。那个冲突是真实存在的缺陷（已修），但它**不是**这个
问题的原因。

我用 `git diff v1.6.107 HEAD` 逐文件核对，确认 `lib/tnc.dart`、`lib/kiss.dart`
**一行未改**，`state.dart` 的接收路径（`onLine` / `_wireTnc` / `_onAprsLine`）
也**完全没动** —— 所以问题不在协议层，而在**接收线程死亡之后**的处理。真正的
原因有两处，两者叠加正好构成「能发不能收」：

**① 原生侧：reader 线程死了，socket 引用却没清（`TncManager.kt`）**

reader 线程在只读循环里发现链路断了之后，会推进代次、清空写队列、广播 `closed`
—— 但**没有把 `socket` 置空**。而 `send()` 的校验是：

```kotlin
if (gen <= 0 || socket?.isConnected != true) throw IllegalStateException("链路未连接")
```

`socket` 还在、`isConnected` 还是 true → **校验通过，字节成功入队**。可是写线程
已经在同一时刻因代次不匹配退出了，**队列再也不会有人消费**。

表现就是：每次发射界面都显示成功，实际**一个字节都没出去**；而接收线程早已死掉。
两端都没有任何报错可查。

**② Dart 侧：断开后永不重连（`state.dart` 的 `_wireTnc`）**

```dart
if (!usingTnc && !multiSource) return;   // ← 本意只是「非发射来源断了不必改横幅」
...
if (!_userDisconnected && tnc.config.autoReconnect) _scheduleReconnect();  // 永远到不了
```

这句 `return` 把后面的 `_scheduleReconnect()` 一起跳过了。而**默认配置正好命中
这个条件**（只启用 APRS-IS，`dataSource = aprsis`）—— 于是 TNC 链路一旦断开就
**静默地永不重连**：不写日志（因为日志也在 return 之后）、不改连接状态、不重连。

**为什么这个 bug 这么难查**：症状是「发送正常、接收没了」，且没有任何提示；
排查时最容易怀疑电台、线缆、TNC 参数，而真正的原因是**两个静默失败叠在一起**
（发送假成功 + 重连被跳过）。

**修复**

- reader 线程死亡时**清掉 `socket` / `reader` / `writer` 引用** —— 之后 `send()`
  会如实抛「链路未连接」，而不是假装成功（CAS 成功即证明仍是当前代次，不会误伤
  新建链路）。
- `startReader` / `startWriter` 拿不到输入/输出流时改为 `teardown()`，而不是只广播
  `closed`（否则同样会留下「能发不能收」的假象）。
- `connect()` 里改为**只有链路真的活着才广播 `connected`** —— 否则会显示「已连接」
  而链路是废的。
- `onClosed` 里把「要不要改横幅」与「要不要重连」彻底分开：重连不再被任何条件
  挡住；非发射来源断开时也留一条日志（这是唯一能回溯的证据）。

**回归护栏**：新增 `test/tnc_reconnect_guard_test.dart`，断言 `_wireTnc` 的
`onClosed` 里不得在安排重连之前 `return`（只看代码行、排除注释 —— 注释里会引用
旧写法做说明），以及退出/销毁时必须释放三条射频链路。

---

**First, a correction.** I attributed "transmits but receives nothing" to TNC and PKWDWPL
being bound to the same device. The user's report disproved it: TNC fails to receive **even
when a PKWDWPL device was never bound**. That conflict was a real defect (and is fixed), but
it was not the cause of this.

`git diff v1.6.107 HEAD` confirms `lib/tnc.dart` and `lib/kiss.dart` are **unchanged**, and
the receive path in `state.dart` (`onLine` / `_wireTnc` / `_onAprsLine`) was never touched —
so the fault lies *after* the receive thread dies. Two bugs combine to produce the symptom:

**Android side:** when the reader thread exits after a read error, it advances the generation
and broadcasts `closed` but **leaves `socket` non-null**. `send()` validates
`socket?.isConnected != true`, which still passes — so bytes are enqueued successfully into a
queue whose writer thread has just exited. Every transmit reports success; not a single byte
leaves the device. Nothing errors anywhere.

**Dart side:** `onClosed` contained `if (!usingTnc && !multiSource) return;` — intended only to
skip a banner update for a non-transmit source, but the `return` also skipped
`_scheduleReconnect()`. The default configuration matches that condition exactly, so the TNC
link, once dropped, **silently never reconnects** — no log line (it sits after the return), no
status change, no retry.

The fixes clear the socket references when the reader dies (so `send()` honestly reports
"not connected"), tear down properly when streams cannot be obtained, only broadcast
`connected` when the link is genuinely alive, and separate "should the banner change" from
"should we reconnect" so reconnection can never be skipped — while still logging a dropped
non-transmit link, since that log is the only trace available afterwards.

---

## [1.6.111] - 2026-09-15

### 🔍 全面复查设备机制：又找到 4 个「界面与事实不符」的问题
### Full audit of the device layer: four more cases where the UI contradicted reality

上一版修了「两条链路绑同一台设备」后我做了彻底复查，又发现四处
**同一类根因**的问题 —— 症状都是「界面说的和实际情况不一样」：

**① 设备页手动连接会绕过 AppState，连上却不被记账**

两个设备页都是**直接**调链路对象的 `connect()`（不走 AppState 的自动连接路径），
于是：

- 手动连上后 `_linkUp` 表没更新，而 `connected` 是从它推导的
  （任何 `_setLinkUp` 都会重算）→ 界面**又变回「未连接」**；
- 我上一版加的**设备冲突守卫对设备页完全无效** —— 它只挂在那条不经过设备页的
  路径上。

现在设备页的连接/断开统一回落到 AppState：`guardDeviceConnect()`（连之前问）
+ `adoptDeviceLink()`（连之后记账并启用来源）。TNC 与 PKWDWPL 走同一条路。

**② 横幅会说「未连接 APRS-IS 服务器」，而用户刚连上了别的链路**

横幅原先只能表达「发射来源通不通」。设备页刚连上 TNC、而发射仍走未连接的
APRS-IS 时，界面硬说「未连接」—— 与事实相反。现在有链路在收时显示
「**XX 已连接 · 仅接收（当前发射来源未连接）**」。

**③ 冲突会导致无限重连**

重连判据是「所有已启用的链路都 up」，而被冲突拦下的 PKWDWPL 永远不可能 up
→ 定时器 8→16→32→60 秒无休止重试。现在这类链路被判定为「不可能连上」而跳过
（`blockedByConflict`），两个判断点收口到同一个 `_allExpectedLinksUp`，
避免只改一处又漏。

**④ 退出应用时射频链路没被释放**

`shutdownForExit()` 与 `dispose()` 原先只断 APRS-IS。蓝牙 socket / 串口句柄
不释放会占住电台，**下次打开应用可能连不上**。现在 TNC / 音频 / PKWDWPL
一并断开。

**另外：权限 requestCode 冲突（隔离漏洞）**

`MainActivity` 把 `onRequestPermissionsResult` 转发给**两个** TncManager，
而两边靠 requestCode 认领回调 —— 原先**共用同一个值**，于是在 A 链路请求权限
会把 B 链路尚未完成的请求一并 resolve（用不属于它的结果）。现在两个实例
各有自己的 code（`0x7A31` / `0x7A32`）。

这是我上一版说「参数化通道名就能安全复用」时漏掉的**隐式共享状态**。
隔离真正干净的只有三步：**通道名、socket、requestCode** —— 缺一不可。

**顺带清掉一处死代码**：`syncPkwdwplLink()` 被 `adoptDeviceLink()` 取代后
没有调用者，删掉而不是留着（留着的死代码会让下一个人以为设备页还在用它）。

新增 4 项回归测试（pkwdwpl_test 38 → 41）。

---

**After fixing the shared-device problem, I audited the whole device layer and found four
more issues with one shared root cause: the UI disagreeing with reality.**

Both device pages call the link object's `connect()` **directly**, bypassing AppState's own
connect path. As a result the `_linkUp` ledger was never updated (so `connected` — which is
derived from it — flipped back to false, showing "not connected" again), and the device
conflict guard added in the previous release **did not apply to the device pages at all**,
since it only lived on the path they don't use. Device-page connects now route back through
AppState via `guardDeviceConnect()` and `adoptDeviceLink()`.

The connection banner could only express "is the transmit source up", so connecting a TNC
while APRS-IS remained the transmit source produced "not connected to APRS-IS" — the
opposite of the truth. It now says "**X connected · receive-only (the transmit source is
offline)**" whenever a link is receiving.

A conflict also caused an infinite reconnect loop: the criterion was "every enabled link is
up", and the blocked PKWDWPL could never come up, so the backoff timer retried forever. Such
links are now recognised as un-connectable and skipped, with both decision points funnelled
through one `_allExpectedLinksUp` so a future edit cannot miss one.

Finally, exiting the app only disconnected APRS-IS, leaving Bluetooth sockets and serial
handles open — which holds the radio and can make the *next* launch fail to connect. TNC,
audio and PKWDWPL are now released too.

**Isolation hole:** `MainActivity` forwards `onRequestPermissionsResult` to *both* TncManager
instances, and they claimed their callbacks by request code — which was **shared**. A
permission request from one link would resolve the other's pending request with results that
were not its own. Each instance now has its own code. This is precisely the kind of **implicit
shared state** I missed when claiming that parameterising the channel name made reuse safe:
isolation actually requires the channel name, the socket **and** the request code.

---

## [1.6.110] - 2026-09-15

### 🚨 修复：TNC 与 PKWDWPL 绑定同一台设备，会把接收数据「瓜分」——表现为 TNC 能发不能收
### Fix: TNC and PKWDWPL bound to the same device split the received data — TNC transmits but receives nothing

**这是我上一版（1.6.108）引入的问题，责任在我。**

1.6.108 新增 PKWDWPL 时，我特意给两条链路做了**独立通道**，理由是「共用一个 socket
会互相拆连接」。这个判断本身没错，但**我漏掉了另一半**：既然两条链路能各自独立地
连，它们就能各自连到**同一台设备**上 —— 而这时：

| 连接方式 | 会发生什么 |
| --- | --- |
| 串口（Windows / Linux） | 两个句柄都能打开（共享模式），读到的字节**各拿一部分** |
| 蓝牙 SPP（Android） | 第二条 RFCOMM 连接**顶掉**第一条 |

两者的症状完全一样：**发送正常，接收没了**（或收得残缺）。而且因为发送走得通，
从界面上根本看不出原因 —— 只会看到「台站不上图了」。你自己去查的话，最容易怀疑的
是电台、线缆、TNC 参数，恰恰不会想到是另一条链路在抢字节。

**新增三道防护：**

1. **设备列表里禁止重复绑定**：TNC 与 PKWDWPL 的设备页会把「已被另一条链路占用」
   的设备标灰并写明原因，点不动。
2. **连接时的守卫**（防止旧配置绕过上一条）：
   - **TNC 优先** —— 两条链路指向同一台设备时，TNC 连接会先把 PKWDWPL 断开让出
     设备（TNC 是发射链路，不能让它失效），并写进日志说明原因；
   - PKWDWPL 连接时遇到冲突则**拒绝连接**，错误码 `device-in-use`。
3. **两处设备页顶部显示红色冲突警告**，把「能发不能收」的成因直接写在界面上。

**如果你已经踩到了**（1.6.108 / 1.6.109 上 TNC 收不到报文）：升级到本版即可；急于恢复
也可以先取消勾选「数据来源 → PKWDWPL」，或在设备页解绑 PKWDWPL 的设备。

新增 3 项回归测试：冲突识别、非冲突不误报、冲突时 PKWDWPL 必须被拦在「发起连接之前」
（断言错误码是 `device-in-use` 而不是底层的连接失败，否则说明守卫没生效）。

---

**This was introduced by my own change in 1.6.108, and it is on me.**

When PKWDWPL was added, I deliberately gave the two links **separate platform channels**,
reasoning that sharing one socket would make them tear down each other's connection. That
reasoning was right, but **I missed the other half**: if the links connect independently,
they can also independently connect to the *same device* — and then:

| Connection | What happens |
| --- | --- |
| Serial (Windows / Linux) | Both handles open (shared mode) and the incoming bytes are **split between them** |
| Bluetooth SPP (Android) | The second RFCOMM connection **displaces** the first |

Both produce the same symptom: **transmit works, receive is gone** (or only partial). And
because transmitting still works, nothing in the UI points at the cause — you just see
stations stop appearing. When investigating, the obvious suspects are the radio, the cable
and the TNC parameters, not another link quietly taking the bytes.

**Three layers of protection were added:** the device list now refuses to bind a device that
another link already holds (greyed out, with the reason stated); a connection-time guard
backs that up (TNC takes priority and disconnects PKWDWPL first, while a conflicting PKWDWPL
connection is refused with `device-in-use`); and both device pages show a red conflict warning
at the top, so the cause is written on the screen rather than left to guesswork.

---

## [1.6.109] - 2026-09-15

### 🔘 主页按钮加大 + 允许「只收不发」的纯接收配置 / Bigger home buttons + receive-only setups allowed

**1. 主页「手动上报」按钮加大**

这是主页最高频的动作，原来只有 34px 高、11 号字，在手机上偏小。

- 高度 **34 → 44**（44 是 Material 的最小可点区域，手指不容易点偏）
- 字号 **11 → 13**、图标 15 → 18、字重加粗
- 「连接」按钮同步调整 —— 两个按钮并排，一大一小会显得很怪
- 加回归测试 `test/home_buttons_layout_test.dart`：在 320dp 窄屏下断言**不溢出**
  且高度 ≥ 44，并锁住 13 号字（改小会让测试失败，避免被无意改回去）

**2. 可以只留 PKWDWPL 一条来源了（纯接收）**

上一个版本（1.6.108）把「只剩只读来源」当成配置错误**挡掉了** —— 理由是怕
信标/消息/网关空转而界面看不出来。**这个判断是错的，本次放开**：拿电台当
纯接收机用（挂机收台站、记台账）完全合理，那时应用依然完整可用（地图、
台账、距离方位都在），只是不发射。

放开后必须处理一个真问题：`connected` 的真实含义一直是「**发射链路**可用」
（全应用的 `if (connected)` 守卫都只服务于发射：信标、消息、ack、保活），
所以只读模式下它必须是 `false` —— 否则会直接引发误发射。但界面又不能因此
显示「未连接」（报文其实一直在收）。因此新增两个明确的 getter 把这个区别
写进类型里：

| getter | 含义 | 只读模式下的值 |
| --- | --- | --- |
| `connected` / `txSourceUp` | 发射链路可用（能不能发） | **false** |
| `rxActive` | 任一已启用链路在收（有没有在工作） | **true** |
| `readOnlyMode` | 没有任何可发射的已启用来源 | **true** |

界面据此显示「**只读接收中 · 本机不会发射任何报文**」+ 已收航点数，而不是
「未连接」；「手动上报」按钮**置灰**并把文案改成「只收不发」（不隐藏：位置
突然少一个按钮会让人找不到，置灰+说明反而直接回答了「为什么发不出去」）；
系统通知栏同样显示「只读接收」而不是「未连接」。

顺带修掉一个多来源下的计数漏报：通知栏原来用 if/else 二选一显示链路计数，
同时开 APRS-IS 与 PKWDWPL 时会漏掉一条，现在改为分别追加。

新增 5 项测试，其中「只读模式下依然拒绝发射」与「`connected=false` 但
`rxActive=true`」两条是这次改动最要紧的护栏。

The manual-beacon button is the most used action on the home page, yet it was only
34px tall with an 11px label. It is now 44px tall (Material's minimum touch
target) with a 13px bold label, and the adjacent connect button matches so the
pair stays visually even. A layout regression test asserts no overflow on a 320dp
screen and locks the 13px size.

**Receive-only setups are now allowed.** The previous release treated "only a
read-only source remains" as a misconfiguration and blocked it. That was wrong
and has been reverted: using a radio purely as a receiver (logging stations
without ever transmitting) is entirely reasonable, and the app stays fully
functional for it. The subtlety is that `connected` has always meant "the
*transmit* link is up" — every `if (connected)` guard serves transmitting only —
so under a receive-only config it must stay `false`, or the app would try to
transmit. The UI therefore distinguishes the two states through `txSourceUp`,
`rxActive` and `readOnlyMode`, showing "receive-only · this device transmits
nothing" plus the waypoint count instead of "disconnected", greying out the
beacon button with a matching label, and passing the same wording to the system
notification. A multi-source counting bug in the notification (an if/else that
dropped one link's stats) was fixed in passing.

---

## [1.6.108] - 2026-09-15

### 🔗 新增「PKWDWPL」数据来源（Kenwood 航点语句，只收不发）/ New data source: PKWDWPL (Kenwood waypoints, receive-only)

数据来源从 3 条变 4 条：**APRS-IS / TNC / 音频 / PKWDWPL**。前三条都要求
报文是 APRS（KISS 帧里的 AX.25），而 Kenwood 电台还能把**收到的台站**从
PC / GPS 端口以 NMEA 明文吐出来（`$PKWDWPL,...`，共 14 个字段）。这类输出
以前在本应用里完全没有入口 —— 现在把它接成一条独立链路，台站直接上图。

**刻意做成「只读」**（这是与其余三条最大的区别，代码里有两道防线）：

- Kenwood 的航点语句是**电台单向输出**的，链路上没有任何可发的报文，
  因此 `dataSource`（发射来源）永远不会是 `pkwdwpl`；界面上也不给它发射圆点，
  即使旧配置里把它存成了发射来源，加载时也会回落到 APRS-IS。
- 它单独开一条**独立通道**（蓝牙 SPP / 串口，与 TNC 各连各的设备），
  两条链路可以同时开着互不干扰 —— 共用通道会互相拆掉对方的连接
  （原生 `TncManager` 只维护一个 socket，所以那是必然的）。
- 最后一条来源不允许取消勾选，且**不能只剩只读来源**：否则信标 / 消息 / 网关
  全部成了空转，而界面上看不出异常（想单用它记台账请用同作者的 PKWDWPL Lite）。

**解析**（`lib/pkwdwpl.dart`，纯 Dart）：

- NMEA XOR 校验和（用 NMEA 0183 权威示例 `$GPGGA` 交叉验证算法本身）。
- 度分 → 十进制：`3954.98` = 39°54.98′ = **39.9163°**；分值 ≥ 60 判为语句损坏。
- 字段数有 **10 / 11 / 12** 三种（第 8 / 9 / 11 字段常为空），所以按固定下标硬取
  是错的 —— 那会把字段少的**整条丢掉**，而里面就有校验和正确的正常语句。
  改为左锚定 + 正则定位日期 + 右锚定呼号/图标。
- 呼号格式校验（补 XOR 查不出字符换位：`BI4PGN1-1` 与 `BI4PGN-11` 校验和相同）。
- 默认**不丢**校验不符的句子（只标注 + 记日志），可在设备页打开严格模式。
  本地线缆上的不符多半是固件格式与手册有出入，整条丢弃会让界面「什么都不显示」，
  反而更难排查。

**分帧**（蓝牙回调不按行对齐）：一条语句可能被切成两三块、一次回调也可能挤进好几条。
写测试时抓到一个真 bug：超长垃圾行溢出缓冲后，只清缓冲**不够** ——
那条行的剩余字节会继续累积，于是下一条正常语句被拼上垃圾尾巴
（收到 `A$PKWDWPL,X`，校验和必然不符，而线路其实是好的）。现在溢出后进入
「重新同步」状态，丢掉字节直到看见 `$`（NMEA 语句只可能以 `$` 开头）。

新增 31 项测试（`test/pkwdwpl_test.dart`），期望值取自 BI7NOR 采集的**真实语句**。

The data sources went from three to four: **APRS-IS / TNC / audio / PKWDWPL**. The
first three all carry APRS inside AX.25 frames, while Kenwood radios can also
print the stations they hear as plain NMEA on the PC/GPS port
(`$PKWDWPL,...`, 14 fields) — output this app previously had no way to read.

It is deliberately **receive-only**, enforced in two places: the radio only ever
writes those sentences, so `dataSource` is never `pkwdwpl` (the UI shows no
transmit dot, and an old config storing it as the transmit source falls back to
APRS-IS on load). It gets its **own platform channel** so TNC and PKWDWPL can both
stay connected to different radios — sharing one channel would make them tear down
each other's socket. The last enabled source can never be a receive-only one.

Parsing lives in `lib/pkwdwpl.dart`: NMEA XOR checksum (cross-checked against the
authoritative `$GPGGA` example), degrees-and-minutes conversion
(`3954.98` → **39.9163°**, minutes ≥ 60 treated as corrupt), tolerance for the
10/11/12-field variants that real captures show (hard-coded indices would drop
whole valid sentences), callsign format validation (XOR cannot catch character
transpositions), and a configurable strict mode. The line splitter — which the
test suite caught a real bug in — now resynchronises on `$` after an oversized
garbage run instead of gluing its tail onto the next valid sentence.

---

## [1.6.107] - 2026-09-15

### 🌐 新增网关（iGate）+ 数据来源改为**多选** / New: gateway (iGate) + multi-select data sources

**数据来源可以同时开几条了。** 这是一个刻意的语义分工，写在代码注释里以免日后
被改坏：

- `enabledSources` = **同时连接哪几条链路**（多选）。几条链路一起收报文，
  收到的都进同一条解析管线。
- `dataSource` = **发射走哪一条**（仍然单选）。所有与发射有关的判断
  （txPath / 67 字符限长 / 群聊禁用 / 射频信标 / 保活帧）都还用它，
  因此这部分逻辑在多选改造中一行未改。
- 为什么发射不能也多选：同一个呼号从两条链路发出去会造成重复报文
  （射频上还白占一次时隙），ack 也会回两次。
- 界面上每条来源是一行复选框 + **实时连通状态点**，右侧圆点指定「发射来源」。
  最后一条来源不允许取消勾选（全关掉应用就什么都不收，而界面不会有任何提示）。
- 单选的旧配置会自动迁移（把旧值当成唯一启用项），升级后不会「什么都没启用」。

**网关**（把射频收到的报文送上 APRS-IS，需要同时启用 APRS-IS 与一个射频来源）：

- **RF→IS**：自动加上 `qAr`（单向）/ `qAR`（双向）与你的呼号标识来路，
  去掉中继上的 `*`（那是本机听到的本地观察，不属于报文本身）。
- **防环**（这一段最容易出错、也最致命）：含 `TCPIP*`/`TCPXX*` 的报文说明
  它本来就来自互联网；含 **q 构造**的说明已被别的网关注入过 —— 两种都绝不
  再送回 IS，否则同一条报文会在互联网上无限增殖。
- **去重**：同一帧会经不同中继路径多次到达，30 秒窗口内只注入一次，
  否则 IS 上会出现多条一模一样的报文（看起来像网关在刷屏）。
- **IS→RF**（可选，默认关，**会真实发射**）：只转「发给最近在射频上听到过的
  台站」的点对点消息；位置/天气这类广播不转（转了只会占满信道，这也是多数
  网关被投诉的原因）。用到射频时按配置剥掉所有互联网专有路径项再接上本机中继。
- 网关逻辑全部是**纯函数**（`lib/igate.dart`），26 项测试覆盖环路防护、
  q 构造、去重窗口、「听到过」列表过期等。写测试时当场抓出两个真 bug：
  ① 只丢 q 构造本身、**漏掉了它后面的网关呼号**（会被当成中继留在报文里，
  凭空多出一个不存在的 digipeater）；② `A>:x` 这种没有目的呼号的畸形报文
  会被放行灌进 IS。

The data sources are now **multi-select**. `enabledSources` decides which links are
connected at once (all their packets feed one pipeline); `dataSource` still decides
which one **transmits**, so every transmit-related rule (txPath, the 67-character
limit, group chat, RF beacon, keepalive) was left untouched. Transmit cannot be
multi-select because sending one callsign over two links duplicates packets (and
wastes an RF slot). The gateway relays RF→IS with proper `qAr`/`qAR` tagging,
**loop protection** (packets carrying `TCPIP*`/`TCPXX*` or a q-construct are never
sent back to IS), 30-second de-duplication of the same frame arriving via different
digipeaters, and optional IS→RF message gating limited to stations recently heard
on RF. All of it lives in pure functions with 26 tests — which immediately caught
two real bugs: the gateway callsign following a q-construct was being kept as a
digipeater, and malformed packets with no destination were passed through.

### 🧹 设备页再收拾：默认一屏只看三件事 / Device page tidied further

上一版拆成三页后，概览页仍然平铺了 6 张卡片，其中「自检结果」与「日志」又高又
不常看，把最常看的「通不通」顶到了需要滚动的位置。现在：

- **默认可见**：① 数据来源（多选 + 发射来源）② 网关 ③ 每条链路的状态行
  ④ 两个子页入口
- **折叠**：链路自检、链路日志（点标题展开）
- 链路状态卡里每条来源一行（名称 · 发射标记 · 地址/设备 · 收帧数），
  多选时不会混淆是哪条在收
- 日志按来源**分段显示**（APRS-IS / TNC / 音频各一段并各自可复制），
  多选时混在一起会把「收不到」的排查彻底变成猜谜

After splitting into three pages, the overview still stacked six cards, and the
tall-but-rarely-needed self-test and log pushed “is my link up?” below the fold.
Now only the data source, gateway, per-link status and the two entries are visible
by default; self-test and logs are collapsible folds. Link status has one row per
enabled source, and logs are grouped per source (each copyable) so a multi-source
setup stays debuggable.


## [1.6.106] - 2026-09-14

### 🔴 真正修好「蓝牙 TNC 只能接收、不能发射」（Android）/ The actual fix for “Bluetooth TNC receives but will not transmit” (Android)

上一版（1.6.105）我只做了兼容性对齐和几个新能力，**没有修好这个问题** —— 因为
真正的根因在 Dart → 原生的**字节数组类型**上，而且它把错误吞得一点痕迹都没有。

**根因**：发送路径是 `Dart → MethodChannel → Kotlin → BluetoothSocket`。
Flutter 的 `StandardMessageCodec` 对字节数组有**两条不同的编码分支**：

| Dart 侧类型 | 编码标记 | Kotlin 侧拿到的 |
|---|---|---|
| `Uint8List` | `_valueUint8List` | **`byte[]`** ✅ |
| `List<int>` | `_valueList` | `ArrayList` ❌ |

我们的 `Kiss.escape()/dataFrame()/paramFrame()/commandFrame()` 全部返回
`List<int>`（`final out = <int>[]`），于是 Kotlin 侧
`call.argument<ByteArray>("data")` 拿到 **null** → 抛 `NO_DATA`。而
`invokeMethod` 的失败是**异步**抛出的，被包在同步 `try/catch (_) {}` 里 ——
**完全静默**。所以表现就是：收得到（接收方向我们写了
`raw is Uint8List` / `raw is List` 双容错）、发不出去、而且毫无提示。
桌面串口走 `dart:io` 的 `writeFrom(List<int>)`，不做类型转换，所以只有
Android 蓝牙中招 —— 这也是它一直没被发现的原因。APRSdroid 是 Kotlin 直接
持有 `OutputStream`，**根本没有跨语言编解码这一层**，不可能踩这个坑。

**修法（用类型钉死，不靠「记得转换」）**：
- `Kiss` 四个组帧函数改为返回 `Uint8List`；初始化串的字节同样处理；
- `TncTransport.send` 签名改为 `Uint8List` —— 以后任何地方再传 `List<int>`
  会**编译失败**；
- 发送失败不再吞掉：原生失败经 `onTxFailed` 上报，写入链路日志
  （设备页可见），Kotlin 侧的错误信息也带上「期望 ByteArray，实际收到 X」；
- **修正上一版「发射自检」的误报**：它此前直接看 `txFrames++`（发送后
  无条件自增），字节全丢了也报「已写入」。现在改为等链路层回话
  （`Future` + 400ms），有错就如实报失败。

**回归测试**（`test/tnc_send_type_test.dart`、`test/tnc_tx_selftest_test.dart`）：
用**真实的 `StandardMessageCodec`** 复现两条编码分支的差异，并断言
`Kiss.*` 的返回类型必须是 `Uint8List`；另一个用假传输层断言「字节没出去时
自检必须报失败」。这样这条坑再被踩到会立刻测试失败。

Last release only added compatibility tweaks and new capabilities — it did
**not** fix this, because the real cause is the *byte-array type* crossing
Dart → platform, and it swallowed every error silently. `StandardMessageCodec`
encodes `Uint8List` as `byte[]` but `List<int>` as `ArrayList`; our KISS
builders returned `List<int>`, so Kotlin's `call.argument<ByteArray>("data")`
got `null` → `NO_DATA` — and since `invokeMethod` fails **asynchronously**,
the synchronous `try/catch (_) {}` hid it completely. Hence: receives fine
(the receive path tolerates both types), transmits nothing, no error shown.
Desktop serial uses `writeFrom(List<int>)` with no such conversion, which is
why only Bluetooth was affected. APRSdroid holds the `OutputStream` directly in
Kotlin and has no cross-language codec layer at all. The fix pins the type at
compile time (`Kiss` returns `Uint8List`, `send(Uint8List)`), surfaces write
failures through `onTxFailed` into the link log, and corrects the previous
release's TX self-test, which had been reporting “written” even when every byte
was dropped.


## [1.6.105] - 2026-09-14

### 🎛 设备设置页重构：一个「什么都有」的页面 → 按问题分层的三页 / Device settings refactor: one catch-all page → three pages organised by the question you are asking

原来一页里堆了：数据来源、TNC 绑定、9 项 KISS 参数、射频行为、链路自检、
音频入口、链路日志 —— 最常做的事（看当前链路通不通）要划过一屏参数才能看到，
调参时又要来回滚。现在按「使用者的问题」拆开：

- **设备（概览）**：数据来源 + 当前链路只读摘要 + 链路自检 + 按来源自动切换的日志
- **TNC 设备与参数**：绑定/扫描/连接/重启、初始化串、KISS 参数、发射自检、射频行为
- **音频**：声卡链路的参数与 WAV 文件模式
- 连接页与设置首页的入口不变（`DeviceSettingsPage` 仍指向概览页），因此用户
  习惯的路径没有被改动；变的只是「进去以后不再迷路」。
- 顺带修掉：概览页此前**只显示 TNC 日志**，音频模式下看不到任何链路日志。

The old page mixed the data source, TNC binding, nine KISS parameters, RF
behaviour, self-test, the audio entry and the link log, so the most common task
— “is my link up?” — required scrolling past a screenful of parameters. It is
now split by the question you are asking: **Devices (overview)**, **TNC device &
parameters** and **Audio**, with the log following the active source (previously
the audio link had no visible log at all).

### 💬 群聊重构：协议层收口成一个状态机 / Group chat refactor: the protocol now goes through a single parser

群聊是 APRS 之上的自订协议（群呼号广播 + 发往群主的私信命令）。原实现把协议
判定散在四个函数里，各自 `startsWith` + **按固定长度 `substring`** 取值。这类
写法会实实在在产生 bug，本次修掉的四处：

- **同一语义两处判断**：群内 `【JOIN】` 与私信 `JOIN_CONFIRM` 是同一件事，却写在
  两个分支里 —— 只补一处就漏另一处。现在统一由 `GroupProto.parse` 解析一次，
  按 `GroupKind` 分派。
- **建群后群主自己不在群成员里**：`createGroup` 把**所有人（含群主）**都置为
  `pending`，而收件人只取 `joined` —— 于是群主自己都收不到群消息。现在群主立即
  `joined`。
- **点了「同意加入」却没进群**：`sendJoinConfirm`/`sendLeave` 只发包、不更新本地
  状态，成员表里自己一直停在 `pending`。现在本地状态与发包同时更新。
- **重复送达导致重复提示**：同一帧可能经多路径送达（同时连 APRS-IS 与射频、或经
  iGate 回环），同一次「确认加入」会反复插系统消息、反复弹通知；而邀请每次收到
  都弹一次确认框。现在协议消息 2 分钟内去重，邀请只对首次弹窗，成员状态不变时
  不再重复提示。
- 另外：群名/群呼号在源头校验（空、含冒号/换行、超长会破坏 APRS 报文结构或让
  AX.25 地址被截断）；建群后会明确回执邀请发给了几人。
- 新增 `lib/group_chat.dart`（纯协议，12 项回归测试），并把上面每个 bug 都钉住。

The group chat is a custom protocol on top of APRS messages. Its parsing was
spread across four functions using `startsWith` and **fixed-length `substring`**
slicing, which produced four real bugs — all fixed and covered by tests: the same
semantic was parsed in two places (`【JOIN】` vs `JOIN_CONFIRM`); `createGroup`
marked **everyone including the owner** as `pending` while recipients only
include `joined`, so the owner missed their own group's messages;
`sendJoinConfirm`/`sendLeave` sent the packet but never updated local state, so
“I accepted but I am not in the group”; and duplicate delivery (multi-path or
iGate loop-back) re-inserted system messages and re-opened the invite dialog.
Protocol messages are now de-duplicated for two minutes, invites only prompt on
first receipt, and group names/callsigns are validated at the source.

### 📡 蓝牙 TNC「能收不能发」：逐字节比对参考实现 + 补齐 APRSdroid 的能力 / Bluetooth TNC “receives but will not transmit”: byte-level comparison and the missing APRSdroid capability

拿 APRSdroid 与 direwolf 的源码逐项核对后，**先排除**了几处常见嫌疑：KISS 帧
格式、写后 `flush`、以及「KISS 载荷是否含 FCS」（`kiss.c` 明确写“not including
the FCS”，我们本来就不含，空中 HDLC 才加）。随后做了三件有实际意义的事：

- **地址 C 位对齐参考实现**：direwolf 组帧时目的地址 SSID 字节为
  `0x80|0x60 = 0xE0`（C 位 = 1），源地址为 `0x60`（C 位 = 0）；我们此前对所有
  地址都写 `0x60`。现已按角色区分。**说明**：direwolf 自己的注释也说「APRS 里
  四种组合都有人用、大家都忽略它」，所以这是兼容性对齐，不敢保证就是根因。
- **新增「TNC 初始化串」**（等价 APRSdroid 的 `kiss.init`，支持多行 + 行间延时）
  —— 这是我们此前**完全没有**的能力，也是「能收不能发」最值得先试的一招：
  不少蓝牙/串口 TNC 模块上电停在命令模式，要先收到 `KISS ON`/`RESTART` 才会
  进入 KISS 转发。
- **KISS 参数改为默认不下发**：APRSdroid 默认一个参数帧都不发，而我们连上就强推
  TxDelay/P/SlotTime/TxTail/FullDuplex —— 推错值会让 TNC 在共享信道上一直退避
  而不发射。现在默认不推（可在设备页显式打开），需要时仍可手动下发一次。
- **新增「发射自检」**：向 TNC 写一帧状态包（不含坐标，不会挪动 aprs.fi 上的
  位置），把「没连上 / 帧超限 / 格式错 / 写失败 / 写成功但电台不发射」区分开，
  并直接给出下一步（试初始化串、查 TxDelay）。

Byte-level comparison against APRSdroid and direwolf ruled out the usual
suspects first (KISS framing, `flush` after write, and whether the KISS payload
carries the FCS — `kiss.c` says “not including the FCS”, which is what we do).
Three substantive changes followed: the destination address C bit now matches the
reference (`0xE0` for destination, `0x60` for source — though direwolf's own
comment notes APRS ignores it, so this is compatibility, not a proven root
cause); a **TNC init string** (the `kiss.init` equivalent we were missing) is now
supported with per-line delays; KISS parameters are **no longer pushed by
default** (pushing wrong TxDelay/Persistence can make a TNC back off forever);
and a **TX self-test** now separates “not connected / frame too long / bad format
/ write failed / written but not transmitted”.

### ⏱ 修复「倒计时结束没有发射」（音频 / TNC）/ Fixed: the countdown finished but nothing was transmitted (audio / TNC)

射频来源的自动发射被 `canAutoBeacon` 门控在「射频信标」开关之后（默认关），
但倒计时 UI 只判断 `beaconEnabled/connected/myHasFix` —— 于是**倒计时一路走到 0
却什么也不发射，界面也从不说原因**。现在把「是否会发射」收敛成一个条件
`rfBeaconEnabled`，倒计时与自动发射共用它：不会发射时显示「射频信标未开启」
并在设置页给出「一键开启」（仍保持显式授权，不会偷偷开始发射）。四个界面
（设置页/地图胶囊/沉浸页/首页）全部一致。附 4 项回归测试。

Automatic transmission on an RF source is gated behind the “RF beacon” switch
(off by default), but the countdown only looked at `beaconEnabled/connected/
myHasFix` — so it ran to zero and nothing happened, with no explanation. Whether
we will transmit is now a single condition (`rfBeaconEnabled`) shared by the
countdown and the transmitter: when it cannot transmit, the UI says “RF beacon is
off” and offers a one-tap enable (still an explicit user action). All four
surfaces (settings, map chip, immersive page, home) agree.

### 🔤 APRS-IS 聊天文本过长提示 / Long-message warnings for APRS-IS chat

射频侧一直有 67 字符上限提示，APRS-IS 侧**完全没有**长度预检 —— 长文本看起来
发出去了，对方却解析不出来（或服务器整包丢弃）。现在把「太长」按后果分成两种：

- **超 67 字符（规范上限）**：多数客户端仍能读，属于「可能解析不出来」→ 发送前
  弹窗确认，而不是硬拦；
- **整包超 512 字节（APRS-IS 单行上限）**：服务器可能整包丢弃、连报头都送不到
  → 直接拦下并说明还差多少字节。
- 输入框旁新增实时计数器（字符 / 整包字节），打字过程中就能看到自己在逼近哪条线；
- 校验用的是**实际发出的正文**（译发时是译文），避免「拿原文校验放过超长译文」。
- 新增 `lib/msg_limit.dart`（7 项回归测试）。

The RF side had a 67-character limit; APRS-IS had **no** length check at all, so
long text appeared to send but could not be parsed (or was dropped by the
server). Oversize is now split by consequence: over the 67-character spec limit
warns and asks for confirmation; a packet over the 512-byte APRS-IS line limit is
blocked outright with the exact number of bytes to trim. A live counter next to
the input shows characters and packet bytes while typing, and validation uses the
text that will actually be sent (the translation, when translating).


## [1.6.104] - 2026-09-14

### 📻 新增数据来源「音频（声卡 TNC）」：用麦克风/扬声器收发 AFSK 1200 / New data source: Audio (soundcard TNC) — AFSK 1200 over mic/speaker

数据来源从两个变成三个：APRS-IS（互联网）、TNC（KISS over 蓝牙/串口）、
**音频（AFSK 1200 / Bell 202）**。音频链路与 TNC 一样是「经电台上空」的射频
来源，因此共用同一套约束：目的呼号 `APALOC`（不加 `TCPIP*`）、单条消息 67 字符
上限、禁用群聊广播、自动周期发射需显式打开「射频信标」（默认关），并且
**发射前先听信道（CSMA）**，不与其它台站抢时隙。

- **协议层是纯 Dart 的**（`lib/afsk.dart`）：Bell 202 调制（1200/2200Hz、
  相位连续）、NRZI、HDLC 位填充、CRC-16/X.25（FCS）、一比特窗复数相关解调 +
  数字锁相（DPLL）。收发数据都走**与另两个来源完全相同的解析管线**，
  所以台站上图、消息收发、过滤、成就不会出现「音频模式下不工作」的分叉。
- **音频 I/O 零新增依赖**：Android 用原生 `AudioRecord`/`AudioTrack`
  （优先 UNPROCESSED 音源绕开 AGC/降噪）；Windows 用 `dart:ffi` 直调系统
  自带的 winmm（`waveIn`/`waveOut`）；Linux/macOS 暂无实时后端，改用 WAV 文件模式。
- **WAV 文件模式**：导入一段录音离线解码（现场没接上音频线也能事后分析），
  或把报文导出成 WAV 再由外部设备播放发射。Android 导出到「下载/APRSlocusAudio」。
- **半双工**：发射期间不喂解调器（否则会把自己的报文当外来报文收一遍，
  还会打乱 DPLL 锁定），丢弃的字节数在音频页可见。
- **Android 后台采集**：前台服务按需声明 `microphone` 类型（Android 14+ 必须，
  否则切后台就被系统掐断麦克风），并新增 `RECORD_AUDIO` 等权限。
- i18n：新增 100+ 键 × 6 种语言（简体/繁体/英/日/印尼/西）。

The data source list grows from two to three: APRS-IS, TNC (KISS over
Bluetooth/serial) and **Audio (AFSK 1200 / Bell 202)**. Audio is an on-air
source like TNC, so it shares the same rules: `APALOC` destination (no
`TCPIP*`), the 67-character message limit, no group broadcast, automatic
beaconing behind an explicit “RF beacon” switch (off by default) and
**listen-before-transmit (CSMA)** so it never grabs a slot from another station.

- The protocol layer is **pure Dart** (`lib/afsk.dart`): Bell 202 modulation
  (1200/2200 Hz, phase-continuous), NRZI, HDLC bit stuffing, CRC-16/X.25 and a
  one-bit-window complex-correlation demodulator with a digital PLL. Decoded
  packets enter **exactly the same pipeline** as the other two sources, so
  stations, messages, filters and achievements cannot silently break in audio mode.
- **No new dependencies for audio I/O**: Android uses native `AudioRecord` /
  `AudioTrack` (UNPROCESSED source first, to bypass AGC/noise suppression);
  Windows calls the built-in winmm (`waveIn`/`waveOut`) through `dart:ffi`.
  Linux/macOS fall back to the WAV file mode.
- **WAV file mode**: decode a recording offline, or export a packet as audio to
  be played by an external device. On Android it lands in Downloads/APRSlocusAudio.
- **Half duplex**: the demodulator is fed nothing while transmitting, otherwise
  the app would receive its own packet and disturb the PLL lock.
- **Android background capture**: the foreground service declares the
  `microphone` type on demand (required from Android 14), plus `RECORD_AUDIO`.

### 🔍 新增「链路自检」：TNC 与音频都能一键分层排查 / New “Link self-test” for both TNC and audio

射频链路出问题时，用户看到的只有「连不上 / 收不到」，原因却横跨协议、平台、
权限、设备、接线好几层。自检把每一层变成一条**可独立判断**的结论：

- **协议回路**（不需要接电台）：KISS 转义 + AX.25 编解码 + FCS 校验；
  音频侧还会真的做一次「调制 → 解调」端到端比对。
- **平台与权限**：后端是否可用（winmm / native）、录音权限是否已授予。
- **实时收发**：采集是否真的有 PCM 数据上来；扬声器能否播出测试音（1200Hz，
  **不发射报文**）；WAV 写入→读出→解调回路。
- **测试发射**：发一条**状态**报文（`>` 开头，不含坐标）—— 不会把台站在
  aprs.fi 上挪到某个坐标，但足以在对方/网关的原始报文里确认链路真的通了。
  这是真实发射，界面上有醒目提示。

When an RF link fails, all the user sees is “cannot connect / nothing
received”, while the cause may sit in the protocol, the platform, permissions,
the device or the wiring. The self-test turns each layer into an independently
judgeable result: protocol loops that run **without a radio** (KISS escaping,
AX.25 framing, FCS, and a real modulate→demodulate round trip for audio),
platform/permission probes, a live capture probe, a speaker test tone
(1200 Hz, **no packet transmitted**) and a WAV write→read→decode loop. The
“test transmit” action sends a **status** packet (no coordinates), so it proves
the link without moving your station on aprs.fi.

### ✅ 交叉验证：用一份独立实现校验调制解调 / Cross-verified against an independent implementation

「自己编、自己解」最容易把同一个理解错误两头都掩盖掉，所以另写了一份独立的
Python 参考实现（`tool/afsk_reference.py`，暴力时钟搜索 + FCS 裁决）互相校验，
并把它生成的录音（含噪声、直流偏置、+25Hz 频偏、静音）固化为回归测试
（`test/reference/afsk1200_reference.wav`）。**这套校验当场抓出一个真 bug**：
NRZI 变号被写在了逐采样循环里（应为每比特一次），等效于在 0 比特期间发出
近奈奎斯特的噪声 —— 两边都解不出任何帧。修正后双向校验通过。

A pure-Dart modem is easy to “self-verify” wrongly, so a completely separate
Python reference implementation (`tool/afsk_reference.py`) cross-checks both
directions, and its generated recording (with noise, DC offset, +25 Hz offset
and silence) is committed as a regression fixture. **It caught a real bug
immediately**: the NRZI toggle was applied per sample instead of per bit, which
emits near-Nyquist noise during 0 bits and made the signal undecodable.


## [1.6.103] - 2026-09-13

### 🔴 修复：消息小红点有时候不会消除 / Fixed: the unread badge sometimes would not clear

这是一组相互关联的缺陷，根因是**未读数靠手动 `++` 维护**，
与「已读时间点」是两套状态，必然脱节。已改为**派生值**（单一真源）。

- **读完群聊不消**：`markGroupRead` 只写已读时间点、**漏了重算未读**
- **群消息根本不加角标**：收消息时是 `if (!isGroupMsg) unreadMessages++` ——
  于是群消息要等别的操作触发重算才**突然冒出**，而读了又消不掉
- **正看着的会话来消息**：私聊只在**点开时**标一次已读（群聊是每次重建都标），
  所以开着会话时收到的消息会一直计为未读，必须退出再进
- **大小写**：APRS 呼号大小写不敏感，但已读键与统计键来源不一致，
  会出现「已读写在 A 键、统计时看 B 键」—— 永不消除
- 现在的行为（每一条都有回归测试，且验证过「测试能真的抓出对应 bug」）：
  - 未读数**统一由一次重算得出**，收消息/标已读/切会话都会重算
  - **正在看的会话不计未读**；离开后重新计入
  - 呼号统一归一化比对；已读之后到达的消息仍计未读，旧消息不再一直红着
- This is a cluster of related defects with one root cause: the unread count was kept
  by hand (`unreadMessages++`) alongside a separate “last read” timestamp, so the two
  drifted apart. It is now a **derived value** with a single source of truth: reading a
  group never recalculated the badge; incoming group messages never incremented it (so
  the badge appeared late and then would not clear); a private chat was only marked read
  **once on open** (groups were marked on every rebuild), so messages arriving while you
  were looking at the chat stayed unread until you left and re-entered; and callsigns were
  compared case-sensitively even though APRS callsigns are case-insensitive, so the read
  mark could be written under one key and looked up under another. Now one recalculation
  produces the count, the **currently open conversation is excluded**, and callsigns are
  normalised. Every rule has a regression test, and each test was verified to actually
  fail when the corresponding bug is reintroduced.

## [1.6.102] - 2026-09-13

### 🐛 群聊翻译不可用（与「数字被误判」同根） / Group chat translation was broken — same root cause as numbers being misjudged

- **现象**：群里翻译任何消息都失败，最后提示「所有免密钥接口都不可用」
- **根因**：中文界面下目标语言就是中文，而群聊消息本来就是中文 →
  接口返回的内容与原文相同 → 而上一版把「译文＝原文」**当成失败并自动跳到
  下一个接口** → 三个候选都「失败」→ 报错。**数字、呼号、坐标同理**。
- **修法**（也就是你说得对的那件事）：
  - 「译文与原文相同」**不再算失败、不再跳接口**，只作为一个标记
  - 界面不再把原文再抄一遍，而是如实说明：
    「译文与原文相同 · 可能无需翻译，或该接口未能翻译」
- **不在群聊里加「发送前翻译」**：群里多位成员、对方语言不唯一，强做会发错（仍然只有私聊有该开关）
- Symptom: translating any message in a group chat failed with “all keyless endpoints
  failed”. Root cause: with a Chinese UI the target language is Chinese and the group
  messages are already Chinese, so the provider echoed the source — and the previous build
  **treated “translation == original” as a failure and jumped to the next provider**, so all
  three candidates “failed”. **Numbers, callsigns and coordinates hit the same path.**
  Fixed as it should have been: an echoed result is **no longer a failure and no longer
  switches providers**; it becomes a flag, and the UI says so honestly (“Translation is
  identical to the original · may need no translation, or the provider failed to
  translate”) instead of repeating the original text. “Translate before sending” stays
  **off for group chats** (several members, no single other language).

### 🔢 无需翻译的内容不再请求接口 / No pointless requests for content that needs no translation

- 新增**预检**：纯数字 / 坐标 / 标点符号 / emoji / 纯呼号（如 `BG7LZQ-9`）
  **直接使用原文，连请求都不发** —— 省额度，也不再拿到无意义的 echo
- 自动翻译在预检阶段就跳过这类消息
- 你主动长按点「翻译」时，若内容无需翻译，会明确提示
  「该内容无需翻译（数字 / 符号 / 呼号）」，而不是没反应
- Adds a **pre-check**: pure numbers, coordinates, punctuation, emoji and bare callsigns
  (`BG7LZQ-9`) **use the original text without any request at all**, saving quota and
  avoiding meaningless echoes. Auto-translate skips such messages at the pre-check, and if
  you explicitly long-press → translate on them, the app says “Nothing to translate here
  (numbers / symbols / callsigns)” instead of silently doing nothing.

### 🔧 顺带修正 / Also fixed

- 翻译**我发出的**内容时会把源语言（我的语言）明确传给接口，
  使 MyMemory 这类「要求指定源语言」的接口也能用上
- 提示文案不再断言「原文已是目标语言」——同样相同的结果也可能是接口没翻，
  现在的措辞两种可能都包含
- When translating **your own** content the source language (yours) is now passed
  explicitly, so providers that require it (MyMemory) become usable; and the hint no
  longer asserts “already in the target language”, since an identical result may equally
  mean the provider did not translate.

## [1.6.101] - 2026-09-13

> 📌 本版专注把**翻译真正做得可用**：免密钥接口从 1 个变成一整套候选链，
> 并堵住「接口返回原文却被当成翻译成功」这个会让人误以为功能坏掉的漏洞。
>
> This release focuses on making translation **actually work**: a single keyless
> endpoint becomes a whole candidate chain, and an endpoint echoing the source text back
> is no longer accepted as a successful translation.

### 🔍 实测结论：没有单一可靠的免密钥接口 / Measured reality: no single keyless endpoint is reliable

本版首先是把各接口**实测**了一遍（结论已写进代码注释）：

- **Google 公开端点**：质量好，但会被限流（实测 429 / 拦截页）
- **MyMemory**：官方免密钥，但本质是**翻译记忆库** —— 实测 `en→ja` 返回
  `hello-world`、`en→ko` 返回 `Hello World`，即**原文照抄**
- **LibreTranslate 公共实例**：已要求 API Key，且语言列表里**没有中文**
- **Lingva 公共实例**：三个全 403/500，已停服
- **百度**：可达、语种码正确，标准版即支持印尼语（`id`）

因此本版不再找「更可靠的免费接口」（不存在），而是靠工程手段提高可靠性。

- This version starts by **measuring** each endpoint (findings are recorded in code
  comments): Google's public endpoint is rate-limited (observed 429), MyMemory is a
  **translation memory** that echoes the source back (`en→ja` → `hello-world`), public
  LibreTranslate instances now demand an API key and often lack Chinese, and the Lingva
  instances are all dead (403/500). Baidu is reachable with correct language codes and
  supports Indonesian (`id`) even on the standard tier. So instead of hunting for a
  “more reliable free endpoint” (there isn't one), reliability is engineered in.

### 🔀 接口从 4 个增到 7 个，默认改为「自动」 / 7 providers now, with Automatic as the default

- 可选：**自动**（默认）/ Google 公开端点 / MyMemory /
  **LibreTranslate（可自建）** / Google Cloud / 百度 / 自定义
- **「自动」按 Google 公开 → MyMemory → LibreTranslate 依次尝试**，
  取第一个真正翻译成功的结果 —— 这是可靠性的主要来源
- **LibreTranslate 支持自建**（填实例地址 + 可选密钥），并会读 `/languages`
  **探测该实例的真实语种范围**，避免发出注定 400 的请求
- 每个接口在设置里都标出**已知限制**（如「Google 公开端点可能被限流」、
  「MyMemory 无匹配语料时返回原文」）—— 不写清楚的话，用户只会以为应用坏了
- 自动模式下显示**本次实际使用的接口**

- Choices are now: **Automatic** (default), Google's public endpoint, MyMemory,
  **LibreTranslate (self-hostable)**, Google Cloud, Baidu and Custom. **Automatic tries
  Google-public → MyMemory → LibreTranslate** and keeps the first real translation, which
  is where the reliability comes from. LibreTranslate can be **self-hosted** (instance URL
  plus optional key) and its `/languages` endpoint is queried to **detect the instance's
  actual language coverage**, avoiding requests bound to fail with 400. Every provider
  shows its **known limits** in settings (e.g. “Google's public endpoint may be
  rate-limited”, “MyMemory echoes the source when it has no match”) — without that, users
  just assume the app is broken. In Automatic mode the provider that was **actually used**
  is shown.

### ✅ 译文有效性校验：裆住「返回原文」的假成功 / Rejecting the “echoed source” fake success

- 完全相同的输出（忽略大小写/标点/空白）**判为未翻译**
- 目标是非拉丁文字（中/日/韩/泰/阿/俄）却只回 ASCII 字母 → **判为未翻译**
- **指定单一接口时同样校验**：否则用户看到「翻译＝原文」还以为成功了
- 判定失败时**自动尝试下一个接口**，而不是把假结果展示出去
- 已用真实 MyMemory 响应验证：`hello-world` 被正确识破
- To make this concrete: identical output (ignoring case, punctuation and whitespace) is
  **treated as untranslated**; a non-Latin target (Chinese/Japanese/Korean/Thai/Arabic/
  Russian) that comes back as pure ASCII letters is **treated as untranslated**; and the
  same validation applies **even when a single provider is selected**, otherwise
  “translation == original” would look like success. On rejection the next candidate is
  tried instead of showing a fake result. Verified against a live MyMemory response.

### 🌐 语言名称国际化与语言码正确性 / Localized language names and correct language codes

- 语言名现在**跟随界面语言**：中文界面显示「日语」，英文界面显示 “Japanese”
  （15 种语言 × 6 个界面语言）—— 之前永远显示各语言的自称
- **阿拉伯语等 RTL 名称单独包 Directionality**：不处理的话标点在混排时会跳到错误一侧
- 语言码**按接口分别映射**（`zh-TW` 在百度是 `cht`、Google 是 `zh-TW`、
  LibreTranslate 是 `zt`、MyMemory 是 `zh-TW`），并用单测锁住三点：
  同一接口内**无冲突**（否则反向解析歧义）、**简繁必须区分**、形状合 BCP-47
- **百度错误码 → 人话**（58001 语种不支持、54001 签名错误、54003 频率限制、
  54004 余额不足等）—— 原来只招数字码，用户无从下手
- **语种不支持 → 可行动提示**：百度 58001 / Google 400 Invalid Value /
  LibreTranslate 不支持语种统一归类，提示「可改用自动或其它接口」，
  而不是用一条 400 把问题搪塞过去
- Language names now **follow the UI language** (a Chinese UI shows 「日语」, an English
  UI shows “Japanese”; 15 languages × 6 UI languages) instead of always showing
  endonyms, and **RTL names such as Arabic are wrapped in a Directionality** so punctuation
  does not jump sides when mixed. Language codes are **mapped per provider** (`zh-TW` is
  `cht` on Baidu, `zh-TW` on Google, `zt` on LibreTranslate), pinned by tests for no
  collisions within a provider, Simplified/Traditional being distinct, and BCP-47 shape.
  **Baidu error codes are translated into plain language** (58001 unsupported direction,
  54001 bad signature, 54003 rate limit, 54004 no balance) because raw numbers give users
  nothing to act on, and **an unsupported language becomes an actionable hint** (“try
  Automatic or another provider”) rather than a bare 400.

## [1.6.100] - 2026-09-13

> 📌 本版包含：蓝牙 TNC 数据来源（含完整 KISS 控制）、聊天翻译（**默认免密钥免费接口**）、
> 发送前把输入译成对方语言、双向翻译与对照显示、聊天日期分界线，
> 以及「中文外泄」与「译文不显示」两个修复。
>
> This release covers the Bluetooth TNC data source (with full KISS control), chat
> translation (**free keyless endpoint by default**), translating your own input into the
> other party's language before sending, two-way translation with contrast display, chat
> date dividers, and two fixes: leaked Chinese text and translations not showing up.

### 📻 新增数据来源：蓝牙 TNC（含完整 KISS 控制） / New data source: Bluetooth TNC with full KISS control

- 此前只能从 **APRS-IS（互联网）** 收发报文。现在「连接」页与「设备」页都能在
  **APRS-IS / TNC** 之间切换数据来源，TNC 模式下报文直接经蓝牙 TNC 与电台收发
- **设备绑定**：Android 走原生经典蓝牙 SPP（RFCOMM）——列出已配对设备、绑定、连接、
  解除绑定、重启链路；Windows / Linux / macOS 走串口 TNC（COM 口 / `/dev/ttyUSB*`）。
  绑定结果会记住，下次启动直接带出
- **完整 KISS 控制**：TXDELAY、TXTAIL、PERSISTENCE、SLOTTIME、FULLDUPLEX、
  信道（KISS 端口）、SETHARDWARE 厂商命令、帧长上限、射频中继路径、
  RETURN 回到命令模式、重启链路；单位换算（ms ↔ 10ms）在数据层完成，界面上直接写 ms
- **安全开关**：射频发射需持照操作，所以 **TNC 模式下默认不会自动发射位置信标**，
  必须在设备页手动打开「允许射频信标」；自动回复 ACK 也可关闭
- **射频适配**（不是把 APRS-IS 的写法换个通道）：
  - 不再发送 `>APRSlocus CONNECT` 保活帧（射频上播客户端版本号毫无意义、只占信道）
  - 不再带 `TCPIP*` 路径（那是 IP 网关的路径项，射频中继不识别）
  - 位置/消息报头改用 `APALOC,<中继路径>`，中继路径可配置
- **消息限制**：射频信道是共享资源，TNC 模式下——
  - 单条消息限 **67 字符**（APRS101），输入提示与说明条会直接写明，超长在源头拦下
  - **群聊广播不可用**（一次邀请就占大量时隙，且群呼号在射频上收不到回应），
    入口保留但会解释原因
- **协议实现全部在 Dart 侧**（`lib/kiss.dart`）：KISS 转义/组帧、AX.25 UI 帧编解码。
  原生层只搬字节 —— 协议只有一份实现、可单元测试，将来加串口或 KISS-over-TCP
  无需重写，也无需为了协议改动而发版
- **单元测试**：新增 `test/kiss_test.dart`（30 例）—— 转义边界、半帧/跨块拼接、
  地址字段位移与 SSID、UI 帧字节序、中继过滤、中文 UTF-8 往返、单位换算

- Until now packets could only flow over **APRS-IS**. Both the Connection and Device
  pages can now switch the data source between **APRS-IS and TNC**, where packets go
  straight through a Bluetooth TNC to your radio. Android uses native classic Bluetooth
  SPP (RFCOMM) — list paired devices, bind, connect, unbind, restart the link — while
  Windows / Linux / macOS use a serial TNC (COM port / `/dev/ttyUSB*`). The bound device
  is remembered across launches. **Full KISS control** covers TXDELAY, TXTAIL,
  PERSISTENCE, SLOTTIME, FULLDUPLEX, channel (KISS port), vendor SETHARDWARE command,
  frame-size limit, RF digipeater path, RETURN-to-command-mode and link restart; unit
  conversion (ms ↔ 10 ms) happens in the data layer, so the UI speaks milliseconds.
  Because transmitting requires a licence, **RF beaconing is off by default in TNC mode**
  and must be enabled on the Device page; auto-ACK can likewise be turned off. The radio
  path is genuinely adapted rather than re-routed: no `>APRSlocus CONNECT` keep-alive
  frames (a client version string on air is pure channel occupancy), no `TCPIP*` path
  entry (that is an IP-gateway token digipeaters ignore), and headers become
  `APALOC,<digi path>` with a configurable path. Messaging is limited accordingly —
  **67 characters** per message (APRS101), shown up front and enforced at the source,
  and **group broadcasts are unavailable** (one invite burns a lot of slots and group
  callsigns get no answers on air); the entry point stays visible and explains why.
  The whole protocol lives on the Dart side (`lib/kiss.dart`) — KISS framing/escaping
  and AX.25 UI encoding — while the native layer only moves bytes, so there is one
  implementation, it is unit-tested, and future serial or KISS-over-TCP transports need
  no protocol rewrite or release. Adds `test/kiss_test.dart` (30 cases) covering escape
  boundaries, split/partial frames, address shifting and SSID, UI byte order, digipeater
  filtering, UTF-8 round-trips for Chinese text and unit conversion.
---

---

### 🌐 修掉 TNC 功能里的中文外泄 / Fixed Chinese leaking through in the TNC features

- 根因：`connInfo` 以前存的是**中文字符串**，界面侧靠
  `localizedConnectionInfo()` 把中文当哨兵再映射回 l10n —— TNC 新增的一批
  状态串没登记进那张映射表，于是**所有语言下都漏出中文**
- 现改为**结构化连接状态**（`ConnPhase` + `ConnStatus`），文案在状态层按当前
  语言直接生成，不再有任何哨兵映射；与先前 `beaconPhase` 的做法一致
- 同时把 TNC 的**机器错误码**（`open-write-failed` 等）换成可读文案，
  而不是把内部串抛给用户（例如 Windows COM 口被占用会明确提示）
- 新增 14 个连接状态/错误文案键 × 6 语言

- Root cause: `connInfo` used to hold a **Chinese string**, and the UI mapped it
  back to l10n with `localizedConnectionInfo()` using Chinese text as a sentinel. The
  batch of TNC status strings was never registered in that table, so **Chinese showed
  up in every language**. It is now a **structured connection state** (`ConnPhase` +
  `ConnStatus`) that renders in the current language directly, with no sentinel mapping
  left — matching the existing `beaconPhase` approach. TNC **machine error codes**
  (`open-write-failed`, …) are also turned into readable text instead of being thrown
  at the user raw (e.g. an occupied Windows COM port now says so). Adds 14 connection
  status/error keys × 6 languages.

---

### 🔤 聊天翻译 / Chat translation

- **长按任意消息** → 弹出操作面板：翻译 / 显示原文 / 复制原文 / 复制译文
  （原来是长按直接复制，没有翻译入口）
- **会话右上角新增翻译入口**（带已翻译条数角标）：面板内选该会话的
  **目标语言**、开关**自动翻译**、一键清除本会话译文；也能直接跳到翻译设置
- **设置页新增「翻译设置」**，支持三家接口：
  - **Google** Cloud Translation v2（API Key）
  - **百度**翻译开放平台（App ID + 密钥，`sign = MD5(appid+q+salt+key)`）
  - **自定义**接口：URL / GET 或 POST / 请求头 JSON / 请求体模板
    （`{text}` `{from}` `{to}` 占位符）/ 结果字段路径（如
    `data.translations.0.translatedText`）
- 页面内提供**测试翻译**按钮：三家接口都要用户自己申请凭据，配完立刻能验证
- 细节考虑：
  - 译文**不落盘**（翻译是查看时的加工，不是消息本身），但结果缓存落盘 ——
    同一句话不会重复计费
  - 语言码**按接口分别映射**（Google 用 `zh-CN`、百度用 `cht`/`jp`），
    避免把接口方言散落到 UI
  - 自动翻译只翻**对方发来的**消息，且**按会话**独立开关
  - 翻译会把文本发往第三方，设置页有隐私提示
- 仓库无 `crypto` 依赖，`MD5` 为自研实现，已用 **RFC 1321 标准向量**与
  11 组独立生成的跨块边界向量锁住（`test/translate_test.dart`，14 例全过）

- **Long-press any message** to get an action sheet: translate / show original /
  copy original / copy translation (previously long-press just copied). A **new
  translate entry sits in the conversation header** with a badge showing how many
  messages are translated; its sheet sets the conversation's **target language**,
  toggles **auto-translate**, clears this conversation's translations and links to the
  settings. **Settings gains a “Translation settings” page** covering three providers:
  **Google** Cloud Translation v2 (API key), **Baidu** Translate (App ID + secret,
  `sign = MD5(appid+q+salt+key)`) and a **custom** endpoint (URL, GET/POST, JSON
  headers, body template with `{text}`/`{from}`/`{to}`, and a result path such as
  `data.translations.0.translatedText`). A **test translation** button is included
  because all three providers need credentials the user must obtain themselves.
  Translations are deliberately **not persisted** (translating is a view-time
  operation, not part of the message) while the result cache is, so the same sentence
  is never billed twice; language codes are **mapped per provider** (Google `zh-CN` vs
  Baidu `cht`/`jp`) instead of leaking provider dialects into the UI; auto-translate only
  handles **received** messages and is toggled **per conversation**; and the settings
  page warns that text is sent to a third party. With no `crypto` dependency in the
  repo, MD5 is implemented here and pinned by the **RFC 1321 vectors** plus 11
  independently generated block-boundary vectors in `test/translate_test.dart`
  (14 cases, all passing).

> 📌 该条目位于 `tnc` 分支，**尚未发版**。发版时请把标题改为版本号并与主分支合并。
>
> This entry lives on the `tnc` branch and is **not released yet**. Rename it to a version
> number and merge into `main` when you ship it.

---

### ⚡ 翻译默认走免费接口（无需任何密钥）/ Translation works out of the box on a free endpoint

- 新增 **免费接口** 并设为**默认**：使用 Google 翻译网页端同款公开端点，**不需要
  API Key**，装好即可翻译 —— 不必先去申请 Google / 百度的凭据
- 该端点支持自动识别源语言，**识别结果同样用于学习「对方的语言」**
- 长文本会被拆成多段返回，已按段**全部拼接**（只取第一段会得到半截译文，已用单测锁住）
- 免费端点可能被限流、被墙或随时变动，因此：失败时**自动回退** MyMemory
  （同样免密钥，但它要求明确源语言，故仅在源语言已知时使用），
  仍失败则给出「可改用 Google / 百度 / 自定义」的明确提示，而不是静默输出空译文
- 需要更高配额或稳定性时，仍可在设置里换成自带密钥的 Google / 百度，或自定义接口

- A **free endpoint** was added and made the **default**: it uses the same public endpoint
  as Google's web translator, so **no API key is required** and translation works right
  after install — you no longer have to apply for Google/Baidu credentials first. It
  supports auto-detection, and the detection result is used to learn “their language”
  too. Long text comes back split into segments and is now **fully joined** (taking only
  the first segment yields a truncated translation — pinned by a unit test). Because free
  endpoints can be rate-limited, blocked or changed at any time, a failure **falls back to
  MyMemory** (also keyless, but it requires an explicit source language, so it is only
  used when the source is known) and otherwise tells you to switch to Google/Baidu/custom
  rather than silently returning an empty translation. If you need more quota or
  stability, you can still switch to Google/Baidu with your own key or a custom endpoint.

### ✉️ 发送前翻译：把自己的输入译成对方的语言再发出 / Translate your own input before sending

- 输入栏新增**译发按钮**：把当前输入译成**对方的语言**，并显示**发送前预览**
  （「将发送：…」+ 译成什么语言），确认后再按发送
- 会话翻译设置里可开**「发送前翻译成对方的语言」**（默认关）：开启后直接按发送
  会先翻译再发出 —— **默认关闭是有意的**，因为它改变了真正发到空中的内容
- 发送会**如实记录实际发出的译文**（`AprsMsg.sentAs`），气泡里以「已按对方语言发出：…」
  标出。与「对照翻译」不同：那是查看时的加工（可重复、可换语言），
  这是**已经发生的事实**，所以独立保存、不随目标语言变化而消失
- 两处防误发：
  - **改字即让旧译文失效** —— 否则会出现「改了内容却发出去旧译文」，射频上不可撤销
  - **译文超长不发送**：射频 67 字符上限按**译文**判定（原文 60 字符通过、
    译文 80 字符被对端丢弃是最典型的静默失败）；译完即提示，不让用户白打一遍字
- 翻译失败时**不发原文**：否则会把对方看不懂的内容发出去
- 仅私聊提供该开关：群聊有多个成员，对方的语言不唯一

- The input bar gains a **translate button** that renders your text in **their language**
  with a **pre-send preview** (“Will send: …” plus the target language) for confirmation
  before you tap send. A **“translate into their language before sending”** switch (off by
  default) lives in the conversation's translation settings; it is **off on purpose**
  because it changes what actually goes on air. The text that was really transmitted is
  recorded verbatim (`AprsMsg.sentAs`) and shown in the bubble as “Sent in their language:
  …”. Unlike the contrast translation — a view-time operation you can redo or re-target —
  this is **a fact that already happened**, so it is stored separately and never disappears
  when the target language changes. Two safeguards against sending the wrong thing:
  **editing the text invalidates the old translation** (otherwise you would change your
  text and transmit the previous translation, which is irreversible on air), and **an
  over-long translation is not sent** — the radio's 67-character limit is checked against
  the **translation** (a 60-character original passing while an 80-character translation
  gets dropped is the classic silent failure), reported right after translating. If
  translation fails, the original is **not** sent, so the other side never receives text
  they cannot read. The switch is offered for one-to-one chats only, since a group has
  several members with no single “their language”.

### 🔄 翻译改为双向：可翻成「对方的语言」 / Two-way translation: translate into the other party's language

- 会话翻译设置从单一「目标语言」改为**两个方向**：
  - **我的语言** —— 对方发来的消息翻成它（读别人的话）
  - **对方的语言** —— 我发出的消息翻成它（预览「对方会读到什么」）
- **对方的语言会自动学出来**，不用用户手填：接口在 `from=auto` 时都会回传识别结果
  （Google 的 `detectedSourceLanguage`、百度的 `from`），翻译过对方几条消息后
  自动回填并落盘；也仍可手动指定
- 长按面板会标明方向（「对方发来」/「我发出」）与目标语言；
  对方语言未知时，对自己发的消息会明确提示而不是硬翻（翻了往往是同一种语言）

- The conversation translate sheet now has **two directions** instead of one target
  language: **My language** (messages from the other side are translated into it) and
  **Their language** (your own messages are translated into it — a preview of what they
  will read). **Their language is learned automatically**: every provider returns the
  detection result when `from=auto` (Google's `detectedSourceLanguage`, Baidu's `from`),
  so after a few incoming messages it is filled in and persisted; manual override still
  works. The long-press sheet shows the direction (“received”/“sent”) and the target
  language, and when their language is still unknown your outgoing messages say so
  instead of being translated blindly (which usually means translating into the same
  language).

---

### 📖 对照翻译 / Side-by-side contrast display

- 译文不再只是替换原文，而是**与原文同屏对照**：气泡里原文在下、分隔线以上标注
  「译给我看 / 对方将读到 + 语言名」、下方是译文
- 会话设置里可关掉「对照显示」，改为只显示译文（原文仍可长按查看）
- 分隔线上的语言标签让「这段是译文、且翻成了什么语言」一眼可辨

- Translations are no longer a replacement but shown **alongside the original**: the
  bubble keeps the original text, a divider labels the direction and language name
  (“for me” / “what they read”, plus the language), and the translation follows below.
  Contrast display can be turned off per conversation to show only the translation
  (long-press still reveals the original). The language tag on the divider makes it
  obvious that the lower block is a translation and into which language.

---

### 📅 聊天日期分界线 / Date dividers in conversations

- 会话、群聊与消息瀑布流的前面均按天插入**日期分界线**：今天 / 昨天 /
  「2026年9月11日 周五」（各语言各自的日期与星期格式）
- 分组按**视觉顺序**而非数组下标判断：「该天最早一条」的上方才是日期真正变换处；
  按下标递增比较会把分界线插错位置。此逻辑已用 12 例单测锁住
  （含跳月、跳年、闰日号相同等边界）

- One-to-one chats, group chats and the message feed now insert a **date divider** per
  day: Today / Yesterday / “2026-09-11 Fri”, formatted per language. Grouping is decided
  by **visual order**, not array index — the divider belongs above the earliest message
  of each day, and comparing indices in order would place it wrongly. The logic is
  pinned by 12 unit tests covering month/year rollovers and same-day-of-month cases.
---

---

### 🐛 修复：翻译成功后界面不显示 / Fixed: translation succeeded but nothing showed

- **根因**：只有**消息瀑布流**的气泡渲染了译文块，**会话/群聊气泡漏了** ——
  状态里确实拿到了译文（长按面板也会变成「重新翻译」），但气泡里永远不显示，
  看上去像「翻译功能没反应」
- 现两个气泡都渲染译文块；并加了一条**源码级防回归测试**
  （断言 `_bubble` 与 `_feedBubble` 都调用 `translationBlock`）——
  这类「编译通过、无异常、界面静默少一块」的漏接只能靠测试挡住。
  该测试已验证「删掉译文块时会精确失败」
- 另修两个会造成「看起来没翻译」的问题：
  - **默认「我的语言」现在跟随界面语言**（以前固定回落 zh，中文界面下把中文译成中文
    = 原文照抄，看起来像没翻译）
  - **接口未配置时给出可操作引导**：长按面板会显示提示，且「翻译」按钮直接变成
    「翻译设置」带你过去，而不是发一次注定失败的请求
- 新增 `test/chat_translate_ui_test.dart`（16 例）：译文块的对照/隐藏/翻译中/失败/无译文
  与方向标签、两个气泡的接续、会话键与消息指纹、双向目标语言解析

- **Root cause**: only the **message feed** bubble rendered the translation block; the
  **conversation/group bubble did not**. The state really held the translation (the
  long-press sheet even switched to “Translate again”), but nothing ever appeared in the
  bubble, making the feature look dead. Both bubbles now render it, and a
  **source-level regression test** asserts that `_bubble` and `_feedBubble` both call
  `translationBlock` — this class of “compiles, no exception, silently missing UI” can only
  be caught by a test. The test was verified to fail precisely when the block is removed.
  Also fixed two issues that made translation look broken: **“my language” now defaults to
  the UI language** (it used to fall back to zh, so a Chinese UI translated Chinese into
  Chinese — verbatim, looking like nothing happened), and **an unconfigured provider is
  now actionable**: the long-press sheet explains it and turns the translate action into
  “Translation settings”, instead of firing a request that is bound to fail. Adds
  `test/chat_translate_ui_test.dart` (16 cases) covering the contrast/hidden/pending/
  failed/absent states, the direction tag, both bubbles, conversation keys and message
  fingerprints, and two-way target resolution.
---

## [1.6.98] - 2026-09-13

### 🏅 授予 BA7KSM「开发人员」/ BA7KSM granted the Developer badge
- `members.json` v45：BA7KSM 以**开发人员**（`developer`）身份加入 `developers` 名单，
  官网会员卡 / 荣誉墙推送后即可见（**无需发版**）
- App 侧同步登记**离线兜底**（`_seedDefaults`），断网时徽章同样显示 ——
  否则未拉到 `members.json` 前该徽章会被整条跳过
- 关于页「代码贡献」新增 **翻译 · BA7KSM** 一行；同时补齐官网三语贡献者块与
  README 三语致谢名单
- 新增 1 个文案键 × 6 语言（`codeContributionTranslation`）

- `members.json` v45: BA7KSM joins the `developers` list with the **Developer** badge
  (`developer`); the website member card and honor wall pick it up right after the push
  (**no release needed**). The app also registers an **offline fallback** so the badge shows
  without network — otherwise the whole badge is skipped until `members.json` arrives. The
  About page's “Code contributions” card gains a **Translation · BA7KSM** row, and the
  website contributor blocks plus the three README thanks-lists are updated. Adds 1 message
  key × 6 languages (`codeContributionTranslation`).

## [1.6.97] - 2026-09-13

> 📌 本版**包含 v1.6.96 的全部改动**（该版本未单独发版），以下一并列出。
>
> This release also **includes everything from v1.6.96**, which was never published on its own.

### 🏅 荣誉墙：显示每枚徽章的「获得条件」 / Honor wall: how to earn each badge
- 荣誉墙的每一枚徽章新增一行 **「获得条件」**（**未点亮的也显示**）——
  此前只显示诗意描述，想知道「怎么拿到」只能去官网
- 条件来自 `members.json` 的 `honors[].criteria`，与官网 `badge.html` **同一数据源**，
  所以官网改了条件、App 下次启动即同步（**无需发版**）
- 回退链与徽章名 / 描述一致：**该语言 → 英文 → 中文基准**；
  **三者都没有时整行隐藏**（不留空白行）
- **离线可用**：8 枚徽章的三语条件已内置为兜底，与官网口径一致
- 已点亮徽章同样显示（与官网一致，便于回顾自己的来路）
- 新增 1 个文案键 × 6 语言（zh / zh-TW / en / ja / id / es）

- Every badge on the honor wall now shows a **“How to earn”** line — **including locked
  badges**, which previously showed only a poetic description and left you to visit the
  website to find out how to get one. Criteria come from `honors[].criteria` in
  `members.json`, the **same source as the website's `badge.html`**, so edits there reach the
  app on next launch **without a release**. The fallback chain matches the badge
  name/description (**this language → English → Chinese baseline**), and the whole line is
  hidden when none is available rather than leaving a blank row. The eight badges' criteria
  ship as an offline fallback, and unlocked badges show them too.

### 📡 台站面板：新增「APRS.tv」查看 / Station panel: APRS.tv lookup
- 快捷操作区新增 **APRS.tv** 按钮，点击**弹出底部面板**选择入口：
  - **详情页** → `aprs.tv/info/<呼号>`
  - **在地图上查看** → `aprs.tv/?call=<呼号>`
- 两个入口不是同一件事（一个是台站资料页、一个是地图定位），所以**不直接跳转**，
  先让用户选；面板每行还显示实际链接（去掉 `https://` 前缀），便于核对
- 呼号用**完整呼号（含 SSID）**，与 aprs.fi 查询一致 —— APRS 服务靠 SSID 区分同一
  操作员的多个设备（如 `BG7ABC-9` 车载台 / `BG7ABC-7` 手持）
- 新增 3 个文案键 × 6 语言（zh / zh-TW / en / ja / id / es）

- The quick-actions row now has an **APRS.tv** button that opens a **bottom sheet** with two
  entry points: **Station page** (`aprs.tv/info/<call>`) and **View on map**
  (`aprs.tv/?call=<call>`). They are not the same destination, so the app asks rather than
  guessing; each row also shows the actual URL (with the `https://` prefix stripped) for
  verification. The **full callsign including SSID** is used, matching the aprs.fi lookup —
  APRS services rely on the SSID to tell an operator's devices apart
  (e.g. `BG7ABC-9` mobile vs `BG7ABC-7` handheld).

## [1.6.95] - 2026-09-13

### 🌏 首次启动向导：不再默认勾选「中国」 / Setup wizard: no longer pre-selects China
- **接收范围**改为**默认不勾选任何国家/地区**。不勾选 = **不做限制、接收全部台站**
  —— 原先默认 `['CN']` 会让**海外用户开箱只见中国台站**，得自己找到设置去改
- 向导里的**说明文案**相应改写，明确「勾选要接收的国家/地区；不勾选则接收全部台站」

- The **receive range** now starts with **no country/region selected**. Nothing selected means
  **no restriction — all stations are received**. The previous default `['CN']` meant
  **users outside China saw only Chinese stations** out of the box. The wizard's explanatory
  text was rewritten accordingly.

### 🔀 「其他台站」开关前移到国家列表之前 / “Other stations” moved above the country list
- 该开关是「**是否也接收未勾选国家的台站**」的总开关，而国家列表有 **25 项** ——
  原位置在列表**底部**，要滑很久才看得到
- **向导与设置页两处**都把它移到了国家列表**上方**

- This switch controls whether stations from **unselected** countries are also received, yet it
  sat **below** a **25-item** country list. It now appears **above** the list, in **both** the
  setup wizard and Settings.

### 🗑️ 删除会话：同时移出会话列表 / Deleting a chat now also removes it from the list
- 修正「删除后行仍在列表里」：**收藏 / 手动联系人**即使一条消息都没有也会出现在会话列表里，
  只删消息它们会继续留着，看起来像没删掉
- 现在删除会话会**一并撤下这两个标记**（`_clearContactFlags`），行确实消失
  - 只清标记、**不删台站本身** —— 台站仍可能通过 APRS 报文收到；把它从台站列表抹掉是
    台站面板「删除台站」的事，两者语义不同
  - 同时推进 `stationsVersion`（会话列表缓存键的一部分），否则列表不会刷新
- **批量删除**同样处理；确认框文案也补充了「该会话将从列表中移除」

- Fixed rows lingering after deletion: **favourites / manual contacts** show up in the chat list
  even with zero messages, so deleting only the messages left them visible. Deleting a chat now
  **also clears those two flags**, so the row really disappears. Only the flags are cleared —
  **the station itself is kept** (it may still be heard over APRS; removing it from the station
  list is a separate action in the station panel). `stationsVersion` is bumped so the list
  actually refreshes. Batch delete behaves the same, and the confirmation text now says the chat
  will be removed from the list.

### 📤 ADIF 导出：完成后弹出选择提示 / ADIF export: action dialog on completion
- 导出成功后不再只弹一条 SnackBar，改为**选择对话框**：
  **复制路径** / **打开所在目录** / **完成**，并显示已保存的完整路径
- 「打开所在目录」**仅在 Windows 提供** —— 那里拿到的是真实文件路径，可用资源管理器定位；
  Android 存的是 MediaStore 相对路径（`Download/xxx.adi`），**不是可定位的真实路径**，
  显示该按钮会点了没反应

- A successful export now shows an **action dialog** (copy path / open containing folder / done)
  with the full saved path, instead of a transient SnackBar. **Open containing folder is
  Windows-only**: there we have a real path that Explorer can reveal, whereas Android stores a
  MediaStore relative path (`Download/xxx.adi`) where the button would do nothing.

## [1.6.94] - 2026-09-13

> 📌 本版**包含 v1.6.93 的全部改动**（该版本未单独发版），以下一并列出。
>
> This release also **includes everything from v1.6.93**, which was never published on its own.

### 🇪🇸 新增西班牙语 / Spanish
- 新增 **西班牙语（es）** 界面，**1187 个文案键全部翻译完成**（无回落英文的遗漏项）
- 设置页与首次启动向导（OOBE）的语言选项新增「**Español**」
- 4 个 ICU select 逐语言补齐：**APRS 符号名 62 例**、符号分类 7 例、
  **国家/地区 27 例**、星期 7 例
- 语言选项在**两处入口**都已加（设置页 + OOBE）

- Added a **Spanish (es)** interface with **all 1,187 message keys translated** (nothing left
  falling back to English). The language picker in Settings and in the first-run wizard now
  offers **Español**, and all four ICU selects were expanded per locale (62 APRS symbol names,
  7 symbol categories, 27 countries/regions, 7 weekdays).

### 🌐 荣誉墙 / 赞助墙：西班牙语回落英文 / Honors & sponsors fall back to English
荣誉、成就与赞助文案由 `members.json` / `sponsors.json` 下发，**只维护 zh / zh-TW / en 三套**，
所以西班牙语界面下这些内容会**显示英文**（而非中文）—— 与日语/印尼语的处理一致。

Honor, achievement and sponsor copy ships in **zh / zh-TW / en only**, so under Spanish those
sections display **English** rather than Chinese — the same behaviour as Japanese and Indonesian.

### 🔧 顺带修复：版本号不一致 / Fix: inconsistent version string
- 开发过程中曾出现 **`lib/state.dart` 的 `appVersion` 漏提交**，导致代码里是 `1.6.92`
  而 `pubspec.yaml` 已是 `1.6.93`（两处不一致；**未影响任何已发布版本**）。现已同步
- 影响面很小（`appVersion` 用于信标/识别时的版本上报），但属真实疏忽，已改正

- During development the **`appVersion` constant in `lib/state.dart` was left out of a commit**,
  so the code reported 1.6.92 while `pubspec.yaml` said 1.6.93 (**no released build was
  affected**). Now synchronised.

> ⚠️ **译文质量说明**：西语译文为**机器翻译质量的首版**，术语按统一口径处理
> （indicativo / baliza / cuadrícula / digipeater 等），但**我无法自评其地道程度**。
> 如发现不自然的表述，请告知具体键或句子，修正很快。
>
> **Translation quality**: this first Spanish pass is machine-translation quality with consistent
> terminology (indicativo, baliza, cuadrícula, digipeater…), but **I cannot judge how natural it
> sounds to a native speaker**. Report any awkward wording and it is quick to fix.

### 🏫 赞助页：合作院校改用全称 / Sponsor page: partner university full name
- 青岛科技大学业余无线电俱乐部（BA4JLD）的名称由「青科大学业余无线电爱好者俱乐部」
  更正为「**青岛科技大学业余无线电俱乐部**」
  - 「青科大学」实为**笔误**：同一条目的英文一直写作
    `Qingdao University of Science and Technology Amateur Radio Club`（官网缩写 QUST），
    中文却少了「岛」字
  - 官网页三处（简体 / 繁體 / English）+ App 数据源 + App 内置兜底，**共 5 处已统一**
  - 官网与 App 的排版都会**自动换行**（无 `nowrap`、无省略号截断），故按需求采用**全称**
    而不是简称
- 顺带统一「爱好者」的不一致：App/JSON 原写「业余无线电**爱好者**俱乐部」，但同一条目的
  英文写 `Amateur Radio Club`、官网两处也写「俱乐部」——现统一为「俱乐部」

- The partner club for BA4JLD was corrected to its **full name,
  青岛科技大学业余无线电俱乐部** (Qingdao University of Science and Technology Amateur
  Radio Club). The previous Chinese text was missing a character — the English in the very
  same entry always spelled the university out in full. All five places (three website pages,
  the app data source, and the app's built-in fallback) are now consistent. Both the website
  and the app wrap this text rather than truncating it, so the full name is used as requested.

### 🌐 修复赞助名单的多语言缺失（真 bug）/ Fixed missing translations in sponsors.json
- `sponsors.json` 原先每条**只有中文字段 `desc`**，而 App 在线加载成功后会**整体替换**
  内置兜底 → 于是**所有非中文语言都显示中文**；也就是说，之前「日语 / 印尼语赞助页
  改用英文」的修复**对在线数据实际并未生效**（只对离线兜底有效）
- 现为全部 **7 条**补齐 `descs` 与 `names`（均含 zh / zh-TW / en）
- 关键细节：`descs` **必须包含 `zh`**。App 的取值链是 `m[lang] ?? m['en'] ?? base`，
  若只给 `en` / `zh-TW`，则 `lang='zh'` 时会直接落到**英文**，反而把中文用户变成英文

- Every entry in `sponsors.json` previously carried **only a Chinese `desc`**. Because the
  app **replaces** its built-in fallback once the online list loads, every non-Chinese
  language showed Chinese — so the earlier "ja/id sponsors in English" fix was in fact
  **not in effect for the live data** (offline only). All **7 entries** now carry `descs` and
  `names` in zh / zh-TW / en. Note that `descs` **must include `zh`**: the lookup chain is
  `m[lang] ?? m['en'] ?? base`, so providing only `en`/`zh-TW` would send Chinese users to
  English instead.

> 官网与 `sponsors.json` **推送后约 1 分钟即生效**；App 的**内置兜底**需随本版本更新。
>
> The website and `sponsors.json` take effect about a minute after push; the app's **built-in
> fallback** ships with this release.

## [1.6.92] - 2026-09-13

### 📶 导出 ADIF：新增「频率（FREQ）」，可自定义 / ADIF export: custom FREQ
- 导出页新增 **频率（FREQ）** 输入框（单位 **MHz**），由你自己填写（各地 APRS 频率不同，App 无从得知）
- 提供**常用频率快选**：**144.640 / 144.800 / 144.390 / 145.825**（中国 / 欧洲 / 北美 / 国际空间站）
  —— 点一下填入，**仍可手改任意值**（只做快捷方式，不做固定下拉：写死列表一定会漏地区）
- **宽容规范化**：自动去首尾空白、去掉误粘的单位后缀 `MHz`、把欧式逗号小数自动改正
- **小数分隔符一律用 `.`**：ADIF 规定与操作系统语言环境无关；若原样写 `<FREQ:7>144,640`，
  欧/法语区的日志软件会解析错位
- **格式非法时禁用导出并就地提示**（如填了 `abc`），而不是静默丢掉你填的值
- **与 BAND 相互独立**，可同时写入（很多日志软件两者都要）；选项会被记住

- The export page now has a **Frequency (FREQ)** field in **MHz**, which you fill in yourself
  (APRS frequencies vary by region and the app cannot know yours).
- **Quick presets**: **144.640 / 144.800 / 144.390 / 145.825** (China / Europe / North America / ISS)
  — one tap to fill, and you can still type any value. Presets only, no fixed dropdown, because a
  hard-coded list will always miss some region.
- **Lenient normalisation**: trims whitespace, drops a pasted `MHz` suffix, and fixes
  comma decimals.
- **The decimal separator is always `.`**: ADIF is locale-independent; writing
  `<FREQ:7>144,640` would misparse in European/French logbooks.
- **Invalid input disables the export button with an inline hint** instead of silently dropping
  what you typed.
- **Independent of BAND** — both can be written at once, and your choices are remembered.

### 🧪 回归测试 / Regression tests
- `test/adif_test.dart` 扩到 **34 项**：新增 7 项 FREQ 用例，包括「**逗号必须被转成点**」
  （语言环境陷阱）与「**非法输入一律拒绝**」；仍在 UTC 与 Asia/Shanghai 两时区下各验一遍

- `test/adif_test.dart` grew to **34 tests**, adding 7 FREQ cases including
  "**commas must become dots**" (the locale trap) and "**invalid input is always rejected**";
  still verified under both UTC and Asia/Shanghai.

## [1.6.91] - 2026-09-12

### 📤 导出 ADIF：新增可选导出选项（修好导入被拒） / ADIF export: selectable options (fixes import rejection)
- **修好上一版导不进去的问题**：上一版只写 `CALL` / `QSO_DATE` / `TIME_ON`，**不写 `MODE`**；
  而 `MODE` 是多数日志软件的**必需**字段，QRZ Logbook 会因为「缺少 MODE」**拒收全部记录**
- 导出页新增**「导出选项」**，可自行选择：
  - **MODE**：`PKT`（数据包，**默认**，QRZ 推荐）/ `FM`（语音）/ `DATA`（数据）/ 不写
  - **附加 SUBMODE=APRS**：开关，默认开（未选 MODE 时自动置灰 —— ADIF 规定 SUBMODE 不能脱离 MODE）
  - **BAND**：不写（默认）/ 2m / 70cm / 1.25m / 23cm / 6m
  - **只写基础呼号（去掉 -SSID）**：默认关；开启后 `BG7PGW-2` → `BG7PGW`
    （部分日志软件的呼号校验只认基础呼号）
- 选项会被**记住**，下次进入仍是上次的选择
- 新增**预览**：直接显示即将写出的那条记录，可先核对再导出
- 字段长度仍按 **UTF-8 字节数**、时间仍写 **UTC**（未变）

- **Fixed the previous version being un-importable**: it wrote only `CALL` / `QSO_DATE` /
  `TIME_ON` and **omitted `MODE`** — but `MODE` is **required** by most logbooks, so QRZ
  Logbook rejected every record with “missing MODE”.
- The export page now has **Export options**:
  - **MODE**: `PKT` (packet, **default**, recommended for QRZ) / `FM` / `DATA` / omit
  - **Add SUBMODE=APRS**: default on (greyed out when no MODE is chosen, since ADIF forbids
    SUBMODE without MODE)
  - **BAND**: omit (default) / 2m / 70cm / 1.25m / 23cm / 6m
  - **Base callsign only (drop -SSID)**: default off; when on, `BG7PGW-2` → `BG7PGW`
- Your choices are **remembered** for next time, and a **preview** shows the exact record
  that will be written.

### 🔧 顺带修复：导出文件名被追加 `.txt` / Fix: exported filename gained a `.txt` suffix
- Android 导出到「下载」时，部分系统会按 MIME 类型给文件名**追加 `.txt`**，
  使 `APRSlocus_….adi` 变成 `APRSlocus_….adi.txt`；现在写入后核对实际文件名并改回

- On Android, some systems **appended `.txt`** to the exported file (because of its
  `text/plain` MIME type), turning `APRSlocus_….adi` into `APRSlocus_….adi.txt`. The actual
  display name is now read back and corrected.

### 🧪 回归测试 / Regression tests
- `test/adif_test.dart` 扩到 **27 项**：新增 MODE/SUBMODE/BAND/去SSID 的用例，
  其中两条专门钉住「**默认必写 MODE**」与「**SUBMODE 不得脱离 MODE**」，
  另有一条断言**预览与实际写出内容同源**（预览若另走一套拼接就会骗人）

- `test/adif_test.dart` grew to **27 tests**, adding MODE / SUBMODE / BAND / SSID cases —
  including “**MODE is written by default**”, “**SUBMODE never appears without MODE**”, and
  an assertion that the **preview and the real output share one code path**.

## [1.6.90] - 2026-09-12

### 📤 新增「导出 ADIF」（设置页 → 在「关于」上方） / ADIF export (Settings → above About)
- 设置页新增 **「导出 ADIF」** 入口，位于 **「关于」上方**
- 进入后可**勾选会话**（群聊 + 单聊），支持**全选 / 取消全选**，点「导出」生成 `.adi` 文件
- 每条记录只写 **呼号 + 时间**（CALL / QSO_DATE / TIME_ON），**不写模式与频段** ——
  APRS 的频段 App 无从得知，写入错误信息比留空更麻烦；导入后自行补即可
- 时间取该会话**首条消息**时刻，且按 ADIF 规范写作 **UTC**
- 只列出**有消息的会话**：ADIF 每条记录都要求通联时间，从未通联过的收藏联系人拿不到时间，
  列出来只会导出一条时间错误的日志，所以直接不列
- 兼容 ADIF 3.x（`<名称:长度>值`，长度为 **UTF-8 字节数**），可直接导入 Log4OM、N3FJP 等日志软件

- **Settings → Export ADIF**, placed **above About**. Tick conversations (group + 1:1), use
  **select all / deselect all**, then export a `.adi` file. Each record contains **only the
  callsign and time** (CALL / QSO_DATE / TIME_ON) — **no mode or band**, because the band is
  not knowable from APRS and wrong data is worse than none. The time is the conversation's
  **first message**, written in **UTC** per the ADIF spec. Only conversations **with
  messages** are listed, since ADIF requires a contact time. Compliant with ADIF 3.x
  (`<NAME:len>value`, len = **UTF-8 byte count**) and importable into Log4OM, N3FJP, etc.

### 💾 文件保存位置 / Where the file is saved
- **Android**：「下载」目录。Android 10 及以上走 MediaStore，**无需任何存储权限**；
  Android 9 及以下写入应用外部目录（同样免权限，且该系统版本下可被文件管理器直接看到）
- **Windows / 桌面**：写入「文档」目录
- 保存后在页内显示完整路径，并提供「**复制路径**」

- **Android**: the **Downloads** folder. On Android 10+ this uses MediaStore and needs
  **no storage permission at all**; on Android 9 and below it writes to the app's external
  folder (also permission-free, and browsable by file managers on those versions).
- **Windows / desktop**: the **Documents** folder. The full path is shown afterwards,
  with a **Copy path** button.

### 🧪 回归测试 / Regression tests
- 新增 `test/adif_test.dart`（14 项）：钉住 ADIF 最易错且**不会报错、只会静默解析错乱**的两点 ——
  **字段长度是 UTF-8 字节数（非字符数）**、**日期时间必须是 UTC**；并在 UTC 与
  非 UTC 时区下各跑一遍验证

- Added `test/adif_test.dart` (14 tests) pinning ADIF's two silent-failure traps:
  **field lengths are UTF-8 byte counts (not character counts)** and **timestamps must be
  UTC**; verified under both UTC and a non-UTC timezone.

## [1.6.89] - 2026-09-12

### 💬 会话管理：对齐与布局修正 / Chat management: alignment & layout fixes
- **修正「管理」按钮错位（垂直）**：计数徽章与「管理」按钮此前用了**不同的内边距**（3 / 4），
  两个高度不同的胶囊并排 → 文字基线不齐。现统一为**固定高度 26 + 垂直居中**，
  并统一圆角，「管理」/「完成」与计数徽章严格对齐
- **修正「管理」按钮偏移（水平）**：标题此前用 `Flexible` 且其后跟 `Spacer`，两者 flex
  都是 1 → 各分走一半空白；而 `Flexible` 用不完的那份会被留到最右侧，导致尾部的
  计数/管理按钮**离右边缘有 37.5px 空隙**（中文短标题「会话」实测；英文标题够长
  会占满份额，碰巧掩盖了这个 bug）。现改用 `Expanded` 吃掉全部剩余宽度，
  按钮**严格贴右**（实测空隙 0）；并新增布局回归测试钉住该不变量
- **修正切换管理时的列表跳动**：管理模式标题原为 16px、普通模式为 20px，
  两种模式行高不同 → 切换时下方列表上下跳。现统一标题字号
- **重做管理工具栏**：管理模式**整行切换**为「已选 N 项 + 全选 + 删除 + 完成」，
  不再与标题挤在同一行；按钮改为等高图标按钮，窄屏（横屏列表栏仅 280 宽）也不挤
- **新增左滑删除**：会话列表项**左滑即出现删除**，与「管理」多选互补——
  既能快速单删，也能批量删（管理模式下自动禁用左滑，避免勾选时误删）
- 选中标记统一为红色，与选中行的红底/红边构成同一个「待删除」信号

- **Fixed the misaligned Manage button (vertical)**: the count badge and the Manage button
  used **different vertical padding** (3 vs 4), so two unequal-height pills sat side by
  side with mismatched baselines. Both are now a **fixed height of 26, vertically
  centred**, with matching corner radii — the badge, Manage and Done line up exactly.
- **Fixed the offset Manage button (horizontal)**: the title used `Flexible` followed by a
  `Spacer`, both with flex 1, so they split the free space in half — and the title’s unused
  share was left at the far right, pushing the count/Manage buttons **37.5px away from the
  right edge** (measured with the short Chinese title 「会话」; the longer English title only
  hid the bug by filling its share). The title is now an `Expanded` that consumes all
  remaining width, so the buttons sit **flush right** (measured gap 0), with a layout
  regression test pinning the invariant.
- **Fixed the list jumping when entering manage mode**: the manage title was 16px while the
  normal title was 20px, so the header changed height and the list below shifted. Both
  modes now use the same title size.
- **Rebuilt the manage toolbar**: manage mode swaps the **whole row** for
  “N selected + select all + delete + done” instead of cramming controls beside the title;
  controls are equal-height icon buttons that fit even at 280px wide.
- **Added swipe-to-delete**: swiping a conversation left reveals **Delete**, complementing
  multi-select — quick single deletes and batch deletes both work. Swipe is disabled in
  manage mode so ticking rows can’t be deleted by accident.
- Selection ticks are now red, matching the red row tint for one consistent
  “to be deleted” signal.

## [1.6.88] - 2026-09-12

### 📡 台站面板：新增台站操作菜单（收藏 / 复制呼号 / 删除台站） / Station panel: actions menu
- 台站详情面板右上角新增**可见的「⋮」菜单**，不再把操作藏在手势里
- **收藏 / 取消收藏**：一键标记常看的台站
- **复制呼号**：复制到剪贴板，方便粘贴到日志或消息
- **删除台站**：二次确认后从台站列表移除；若再次收到其报文会重新出现
  （若该台站是收藏 / 手动联系人，删除会一并移除）

- The station detail sheet now has a **visible “⋮” menu** instead of hiding actions
  behind gestures: **favourite / unfavourite**, **copy callsign**, and **delete station**
  (with a confirmation). A deleted station reappears if its packets are heard again;
  deleting also removes it from favourites / manual contacts.

### 💬 会话管理：不再只有长按删除 / Conversation management: no more long-press-only delete
- 会话列表右上角新增**可见的「管理」按钮**（此前只能长按删除，界面没有任何提示，很难发现）
- 进入管理后可**多选**会话：点按选中 / 取消，并支持**全选 / 取消全选**
- 工具栏显示**已选数量**与**删除**按钮，可一次删除多个会话（带二次确认）
- **长按**会话现在 = 进入管理并选中该项（保留快捷操作，但不再直接删除，避免误触）
- 单聊删除全部消息；群聊只清消息、**保留群组本身**
- 已读时间点一并清理；若正停留在被删除的会话上会自动退回会话列表

- The conversation list header now has a **visible Manage button** (previously deletion
  was long-press-only with no affordance at all). Manage mode supports **multi-select**,
  **select all / deselect all**, and a toolbar showing the **selected count** plus a
  **delete** action with confirmation. **Long-press** now enters manage mode and selects
  that row — still quick, but no longer a destructive surprise. 1:1 chats delete all
  messages; groups clear messages but **keep the group itself**.

### 🌐 新增 14 条界面文案（中 / 繁 / 英 / 日 / 印尼） / 14 new UI strings (zh / zh-TW / en / ja / id)
- 覆盖「管理、全选 / 取消全选、已选数量、删除确认、台站操作、复制呼号、删除台站」等
- 新文案已补齐全部 5 种语言，与既有键集保持一致（每语 1160 键）

- Covers manage / select-all / selected-count / delete confirmation / station actions /
  copy callsign / delete station. All five locales are complete and consistent
  (1160 keys each).

## [1.6.87] - 2026-09-12

### 🗑️ 消息会话列表：新增删除聊天 / Delete a chat from the conversation list
- **长按**会话列表项即可删除该会话的聊天记录
- **单聊**：删除与该呼号的全部消息，会话从列表消失（收藏 / 手动联系人仍保留）
- **群聊**：只清空该群的消息，**群组本身保留**（解散群组仍在群详情里，是更重的操作，不混在此处）
- 若当前正停留在被删除的会话上，自动退回会话列表（否则会停在一个已不存在的会话里，
  头部还挂着已删除的呼号）

- **Long-press** a conversation to delete its chat history.
- **1:1 chats**: every message with that callsign is removed and the row disappears
  (favourites / manual contacts stay listed).
- **Group chats**: only the messages are cleared — the **group itself is kept**
  (dissolving a group still lives in group details and is a heavier action).
- If you were viewing the deleted conversation, you are returned to the list.

### 🌐 荣誉墙 / 赞助墙：日语、印尼语改用英文 / Honors & sponsors use English for ja/id
- 荣誉、成就、赞助墙的文案由 `members.json` / `sponsors.json` 下发，目前只维护
  **zh / zh-TW / en 三套**；此前日语、印尼语界面会**回落成中文**
- 现改为**统一回落英文**（`honorLangOf` 只认 en），并给 `Honor` / `Achievement` /
  赞助条目加上「该语言 → **英文** → 中文基准」的逐级回落
- 内置的赞助兜底名单补齐 zh-TW / en 文案（并支持 sponsors.json 下发多语言字段）

- Honor, achievement and sponsor copy ships in **zh / zh-TW / en** only; Japanese and
  Indonesian used to **fall back to Chinese**. They now fall back to **English**
  instead, via a per-language → English → Chinese chain in `Honor` / `Achievement` /
  sponsor entries. The built-in sponsor fallback list gained zh-TW / en copy and can
  now take multilingual fields from `sponsors.json`.

### 🏅 荣誉授予 / Honors granted
- **BI4BNF** 授予「早期成员」（`members.json` v43）
- **BH6RIZ** 追加「开山」（`primary` 取「开山」，与最初三位创始人一致）
- 两者均为纯数据改动，App 与官网**运行时拉取，即时生效，无需发版**

- **BI4BNF** granted *Early member*; **BH6RIZ** additionally granted *Founding pioneer*
  (`members.json` v43). Pure data changes — fetched at runtime, effective immediately.

## [1.6.86] - 2026-09-12

> 自 v1.6.82 起的改动合并为此版发布（v1.6.82~v1.6.85 未单独发版）。
> Changes since v1.6.82 are all released together in this version
> (v1.6.82~v1.6.85 were not released on their own).

### 🌐 新增日语与印尼语（译文已全部完成）

新增 **日本語** 与 **Bahasa Indonesia** 两种界面语言，共 1143 个文案键。

**译文已 1143 / 1143 条全部完成**（日、印尼各一套）。
配套的语言选项、解析链路、生成类、校验全部就绪。

改动内容：

- 新增 `app_ja.arb` / `app_id.arb`（键集与 zh/en/zh_TW 完全一致）
- 新增 `app_localizations_ja.dart` / `app_localizations_id.dart`
  （**由 `flutter gen-l10n` 生成**，非手写——我用它重新生成现有三种语言，
  产物与仓库里手工维护的文件**键集完全一致零差异**，确认工具可靠）
- `supportedLocales` / `isSupported` / `lookupAppLocalizations` 接入 ja、id
- 语言选项：**设置页 + OOBE 两处**都加上（原先只有 中/繁/英）
- `AppState.l10n`（无 BuildContext 场合）加 ja/id 分支
- `terms_page`：非中文语言的协议正文回落到**英文**（原先会回落中文；
  目前只有中英两套协议正文，日语/印尼语协议待补）

流程保障（避免再让 CI 挂）：译文逐条做 **JSON 转义往返校验**，
并断言**占位符集合与中文原文完全一致**（`{name}` 少一个就会输出错乱）。

- Added **Japanese** and **Indonesian** UI locales (1143 keys each).
- **This commit lands the plumbing**: both locales are selectable, resolve
  correctly and verified end-to-end. **Translation is complete: 1143 / 1143 keys**
  for both Japanese and Indonesian, along with the language pickers, resolution
  chain and generated classes.
- New ARBs + generated Dart classes (`flutter gen-l10n` — verified by regenerating
  the three existing locales and diffing: identical key sets, zero drift).
- Wired into `supportedLocales` / `isSupported` / `lookupAppLocalizations`, both
  language pickers (settings + OOBE) and `AppState.l10n`.
- `terms_page` now falls back to the **English** terms text for non-Chinese locales
  (ja/id terms documents are still to be written).


### 🐛 修复「APRSlocus 同款软件」识别失效（v1.6.80 引入的回归）

你反馈「分类标签好像不起效了」——查证属实，而且**根因是我自己在 v1.6.80 造成的**。

当时的判定是「备注或呼号含 `APRSlocus`」，但同一个版本里我又把**版本号从位置包
备注移到了状态包**、且**备注默认留空** ——于是 APRSlocus 台站的备注里再也不可能出现
「APRSlocus」→ 判定全部落空。

受害面比筛选更大（同一个判定被复制成两处）：

| 使用处 | 症状 |
|---|---|
| 台站筛选「APRSlocus」chip | 命中 **0** |
| 统计面板的 APRSlocus 计数 | 恒为 **0** |
| `stationAllowedFor`（开启「接收其他台站」时） | APRSlocus 台站被**误过滤掉** |
| 台站详情「APRSlocus 信息」区块 | 不显示 |

数据本身没丢（入库时的判定认 `APALOC`，一直是对的），只是**没人去用它**。

**修法**：改成多信号判定并按可靠性排序，同时把两份重复逻辑**收敛为一处**（这是它
会漂移的根因）：

1. `toCall == APALOC/APRSLOCUS/APOLOCUS` —— 报文路径首段的官方标识，最可靠，已持久化
2. `aprslocus` 字段存在 —— 解析出的专属信息兜底（已持久化）
3. 备注/呼号关键字 —— 兼容旧版本报文

另外：因为 `toCall` 与 `aprslocus` **都已持久化**，这个修复对**已缓存的历史台站同样生效**，
不需要等重新收包。

新增 5 项回归测试（含「筛选判定须与 Station 判定一致」，专门防止两套逻辑再漂移）。

- Fixed the broken "APRSlocus same software" detection — a regression I introduced in
  v1.6.80. The check looked for `APRSlocus` in the comment/callsign, but that same
  release moved the version tag from the position-packet comment into the status
  packet and made the comment empty by default — so the text could never match again.
  It affected the station filter (0 hits), the stats counter (always 0),
  `stationAllowedFor` (APRSlocus stations wrongly filtered out when "receive other
  stations" is on) and the station-detail info block.
- The detection now uses several signals in order of reliability (`toCall`, the parsed
  `aprslocus` field, then comment/callsign for legacy packets) and the duplicated logic
  has been collapsed into a single place — that duplication is why it drifted.
- Because `toCall` and `aprslocus` are both persisted, the fix also applies to already
  cached stations without waiting for new packets. 5 regression tests added.


### 🌐 中文硬编码清理 · 第五批：补上一批我漏掉的 

审计时发现一个**验证方式的缺陷**：我用「字面量是否等于某个 ARB 值」判断是否已本地化，
但有些键的值**恰好等于字面量本身**（如 `moreSymbols` 的值就是 `更多符号`），
于是这些「本就该替换却没替换」的位置被当成「已有本地化」跳过了。本批把这 11 处补齐：

| 位置 | 情况 |
|---|---|
| `early_member.dart` 徒章墙 / 成就墙 | 这两处**连键都没有**（新增 `badgeWall` / `achievementWall`），且原本是 `const Text` → 去 `const` 才能用 l10n |
| `terms_page.dart` 刷新 / 在浏览器打开 / 重试 | 自写 `_en ? 'Refresh' : '刷新'` **二元式**，**繁體用户只能看到简体** → 改走 l10n（新增 `openInBrowser`） |
| `settings_pages.dart` 更多符号 / 请输入有效经纬度 | 键（`moreSymbols` / `invalidLatLng`）早已存在，只是没用 |
| `settings_page.dart` 取消 / 退出 | 同上（`cancel` / `logout`） |
| `vector_map.dart` 加载失败 / 加载中 | 同上（`vectorMapLoadFailed` / `loadingVectorMap`） |

提交前自检**当场拓到一个真实错误**：我凭印象写的 `openInBrowser` 键名**并不存在**
（这正是那次“一次就过”的反例，也是自检价值的体现）。

- **Fifth batch**: my audit had a flaw — it treated a literal as "already localized"
  whenever its text equalled some ARB value, but for keys like `moreSymbols` the
  *value is the literal itself*, so genuinely-untranslated sites were skipped.
  This batch fixes those 11 sites (incl. `terms_page`'s hand-rolled
  `_en ? 'Refresh' : '刷新'` binary that left Traditional-Chinese users with
  Simplified text) and adds the missing `badgeWall` / `achievementWall` /
  `openInBrowser` keys. Two sites were `const Text` and needed the `const` removed.


### 🌐 中文硬编码清理 · 第四批：修好「有本地化包但没用上」的地方

查证后发现，剩余中文里有很大一部分**并非缺翻译，而是 UI 没用现成的本地化包** ——
`widgets.dart` 早就提供了 `localizedLocationStatus` / `localizedConnectionInfo` /
`localizedAprsSymbolName` / `localizedMapTypeLabel`，但多处界面直接渲染了原始中文：

- **定位状态**（2 处）：地图「我的位置」面板、沉浸地图四角信息 —— 原先只在地图首页
  经过了本地化，其余位置直接输出 `未定位` / `已定位` 等中文
- **连接状态**（3 处）：连接页信息行、连接横幅、开发者页状态 —— 已从 1 处扩到全部
  4 处（均走 `localizedConnectionInfo`）
- **符号/设备名**（4 处）：消息页台站行（3）与台站详情副标题（1）原先用
  `s.typeName`（直接输出中文符号名）
- **地图类型标签**（9 处）：`localizedMapTypeLabel` 里 `Carto 浅色` / `OSM 标准` /
  `Esri 影像` 等 9 个名称是硬编码中文 → 新增 9 个 l10n 键
- **地图分组标题**（2 处）：设置页地图选择器的「国内地图 / 国际地图」走 l10n
  > 注：分组判别符 `'高德' / '其他'` **保留不动** —— 它是 `MapType.group` 的
  > 数据实参，直接换成 l10n 文案会让分组失效（这是项目里「中文字符串当键」
  > 的典型坑），已加注释说明。

### 🐛 顺带补一个我自己上一版留下的漏

v1.6.80 新增的定位状态串 `模拟位置 · 后台保活` **不在映射表里** → 会直接把中文
漏到界面（选择「模拟位置」后地图状态就显示中文）。已补 l10n 键 + 映射。

### 📝 说明

本批所在文件里其余中文属于**有意保留**：
- `state.dart` 的国家/地区表与 `_log()` 日志（帮助，非必须）
- `mock_data.dart` 演示数据、`tile_map.dart` 城市标签（北京城区/海淀…）
- `aprs_device.dart` 的设备类别名已走 `deviceClassLabel(context)`
- 台站列表/地图的**搜索匹配**仍用中文名（因为它是被搜索的**数据**本身）

- **Fourth batch**: a large part of the remaining Chinese wasn't missing
  translation at all — the UI simply wasn't using the localization helpers that
  already existed (`localizedLocationStatus` / `localizedConnectionInfo` /
  `localizedAprsSymbolName` / `localizedMapTypeLabel`).
- **Location status** (2), **connection status** (3, now all 4 call sites),
  **symbol/device names** (4), **map type labels** (9, nine new keys) and the
  **map group headings** (2) now all go through l10n.
- The group discriminator `'高德' / '其他'` is deliberately left alone: it is the
  *data* value of `MapType.group`, so translating it would break the grouping
  (a textbook case of this project's "Chinese string used as a key" pitfall).
- **Also fixed a leak I introduced in v1.6.80**: the new location-status string
  `模拟位置 · 后台保活` had no mapping, so it showed Chinese in the UI.
- Chinese that remains in these files is intentional: the country table and
  `_log()` messages in `state.dart`, demo data in `mock_data.dart`, city labels
  in `tile_map.dart`, and the station-search **matching data** itself.

## [1.6.81] - 2026-09-12

### 🌐 设置页中文硬编码清完（第三批，收尾）/ Settings page fully localized (batch 3)
- 设置页剩余中文全部改走 l10n，共 **142 处**（新增 121 个文案键，三语齐全）
- **符号名表**是本次的大头（共 162 行、57 个符号）：原先是**顶层 `const` 表**，
  顶层没有 `context`，所以把表改成接收 `S` 的函数（`_symCategories(s)` /
  `_smartQuickSymbols(s)`），名称统一由新增的顶层 `symName(s, code)` 解析；
  符号码—图标数据不变，只是不再内嵌中文
- 其余覆盖：主页徽章选择、速度分档规则编辑器（13 处）、天气模拟 11 项、
  数据清理条目、重新运行向导、WebSocket 提示、退出应用弹窗等
- 顺带清掉一处重复文案：本次新增的 `radiusSaveHint` 与项目**已有的**
  `radiusTip` 含义完全相同，已改用既有键（避免两套同义文案）
- 结果：`settings_pages.dart` + `settings_page.dart` 的可本地化中文字面量 **归零**

- Every remaining hardcoded Chinese string in the settings pages now goes through
  l10n: **142 sites**, 121 new keys (all three languages).
- The bulk was the **APRS symbol table** (162 rows / 57 symbols). It was a
  top-level `const` list, and a top-level constant has no `context`, so the tables
  became functions taking `S` (`_symCategories(s)` / `_smartQuickSymbols(s)`) with
  names resolved by a new top-level `symName(s, code)`. The symbol-code/icon data
  is unchanged — it simply no longer embeds Chinese text.
- Also covered: home badge picker, the speed-tier editor (13 sites), the 11 weather
  simulation entries, data-cleanup rows, the wizard-restart dialog, the WebSocket
  hint and the quit dialog.
- Removed one duplicate: the newly added `radiusSaveHint` said exactly the same
  thing as the pre-existing `radiusTip`, so the existing key is used instead.
- Net result: **zero** localizable Chinese literals left in `settings_pages.dart`
  and `settings_page.dart`.

## [1.6.80] - 2026-09-12

### 🌐 中文硬编码清理 · 第二批 / Hardcoded-Chinese cleanup, batch 2
- 补齐 v1.6.79 遗漏的三处：设置页符号表中 `const` 上下文内的字面量已还原
  （顶层 `const` 符号表里根本没有 `context` 可用，需先做结构性改造）
- **Fixed the three spots v1.6.79 missed**: literals inside the top-level `const`
  symbol tables were restored — those tables have no `context` in scope at all, so
  they need a structural change before they can be localized.

### 💬 聊天输入栏：元素分隔 / Chat composer spacing
- 输入栏原先内边距 12、输入框与发送键间距仅 8，且底部没有安全区，
  在手势导航机型上与系统导航条贴死
- 现在：包一层 `SafeArea`、内边距 14/10、间距 10、输入框加描边、
  发送键 42→44 —— 输入框与发送键成为两个可分辨的独立控件
- **Composer spacing**: wrapped in a `SafeArea`, larger padding (14/10), a 10 px
  gap, an outline on the field, and a 42→44 px send button so the field and the
  button read as two distinct controls.

### 🔔 模拟位置模式的后台保活 / Keep-alive in simulated-location mode
- 原先选「模拟位置」会 `loc.stop()` 停掉 **前台服务**，切到后台后进程被冻结：
  APRS-IS 连接断开、信标定时器停摆、通知也没有了
- 新增 Android 前台服务 `keepalive` 模式：**不需要定位权限**、不注册任何
  provider 监听（不额外耗电），仅保留前台服务 + WakeLock，让连接与定时器存活
- **Simulated location used to kill the foreground service**, so the process got
  frozen in the background: the APRS-IS link dropped, beacon timers stopped and
  the notification disappeared. A new `keepalive` foreground-service mode needs
  **no location permission** and registers no provider listeners (no extra drain)
  while keeping the service and wake-lock alive.

### 📝 站台备注默认清空 / Empty default station comment
- 默认备注由 `'APRSlocus 移动台'` 改为**空**；老用户若从未改过该值，
  升级后自动视为空（其余自定义备注不受影响）
- **The default comment is now empty** (was `'APRSlocus 移动台'`). Existing users
  who never changed it are migrated to empty; custom comments are untouched.

### 🏷️ 版本号改由状态数据包上报 / Version tag moved to the status packet
- 版本号/平台原先追加在**位置数据包**的备注末尾，会污染第三方地图上的备注显示
- 现改由**状态数据包**上报：`>APRSlocus CONNECT vX.Y.Z 平台`
- 解析端同时容忍新旧两种格式（可选 `CONNECT`），所以台站详情里的
  「版本 / 平台」照旧显示；旧版客户端报的台站也不会读不到
- **The version/platform tag used to be appended to the position packet comment**,
  which polluted the comment shown on third-party maps. It is now reported in the
  **status packet** (`>APRSlocus CONNECT vX.Y.Z platform`). The parser accepts both
  new and old forms (optional `CONNECT`), so station-detail version/platform still
  shows, including for stations running older builds.

### ⏱️ 在线判定时长可自定义 / Configurable online window
- 原先写死「5 分钟内上报为在线」。现新增设置项「在线判定时长（分钟）」，
  范围 1–240，默认仍为 5
- 实现上由 `Station.effectiveStatus` 读取统一的静态窗口，因此台站列表、
  地图圆点、统计面板口径完全一致（不会出现「列表离线、地图在线」）
- **Configurable online window**: previously hard-coded at 5 minutes; there is now
  an "Online window (minutes)" setting (1–240, default 5). A single shared window
  feeds `Station.effectiveStatus`, so the station list, map dots and stats panel
  agree — no more "offline in the list, online on the map".

## [1.6.79] - 2026-09-12

### 🌐 中文硬编码清理 · 第一批：设置页 / Hardcoded-Chinese cleanup, batch 1: settings

- 设置页 **70 处**界面文案改为走 l10n，覆盖「电台身份 / 显示信息 / 定位来源 /
  信标上报 / 数据维护 / 高级设置」等区块的标题、按钮、提示与开关说明
- 这批**只替换「ARB 里已存在同名键」的字面量**，因此**零新增翻译**、无回归风险
- 该文件仍有 **93 处**待处理：符号名表（约 150 项，位于顶层 `const` 表中，
  需先改结构才能取到 `context`）、带插值的模板文案、无现成键的文案，
  以及 3 处 `const` 上下文，将在后续版本分批处理
- 做法：逐行定点替换 + 自动校验（比较语境检测 / 键存在性 / 括号配平 /
  残留检测），避免误改「中文串当键/当状态」的写法

- **70** hardcoded UI strings in the settings pages now go through l10n
  (section titles, buttons, hints and switch captions in the station, display,
  beacon, data-maintenance and advanced pages).
- Only literals whose text already had a matching ARB key were swapped, so this
  batch adds **zero new translations** and carries no regression risk.
- **93** sites in this file remain: the symbol-name tables (which live in
  top-level `const` lists and therefore have no `context` in scope, so they need a
  structural change first), interpolated strings, and 3 literals inside `const`
  contexts; they will ship in follow-up releases.
- Done with per-line targeted replacement plus automated checks
  (comparison-context detection, key existence, bracket balance, leftover
  detection) so that "Chinese string used as a key/state" patterns are never
  touched by accident.

## [1.6.78] - 2026-09-12

> 说明：自本版起更新日志采用**中英双语**。
> Note: from this release onward the changelog is bilingual (Chinese + English).

### 🚚 台站详情：发送消息入口提前 / Move the message box to the top
- 「发送消息」原先沉在页面**最底部**（数据包列表之后），几乎找不到；
  现移到**头部之后**（呼号/状态下方），进入详情即可直接发消息
- The "send message" input used to sit at the very **bottom** of the station
  detail panel (below the packet list) and was hard to find. It now sits
  directly **under the header**, so it is visible as soon as the panel opens.

### 📐 消息页：英文标签溢出修复 / Fix overflowing English labels
- **标题行**：`Messages` 与 `Feed/Chats` 切换器同处一行，英文下挤爆窄屏
  → 标题改为 `Expanded` + ellipsis，剩余宽度让给切换器
- **快捷操作按钮**：`New conversation` / `Broadcast` / `New group` 明显长于中文，
  按钮内 `Text` 无省略 → 加 `Flexible` + `maxLines:1` + ellipsis；切换器内边距收紧
- **Title row**: `Messages` plus the `Feed`/`Chats` toggle overflowed narrow
  screens in English → title is now `Expanded` + ellipsis.
- **Quick-action buttons**: the English labels are much longer; their `Text`
  had no ellipsis → wrapped in `Flexible` with `maxLines: 1` + ellipsis.

### 🏗️ 信标倒计时：状态结构化（i18n 架构修复）
### / Beacon countdown: structured state (i18n refactor)
- `AppState.nextBeaconIn` 原先**返回中文字符串**（`'已关闭'`/`'未连接'`/
  `'等待定位'`/`'45s'`/`'即将'`），UI 还得用 `== '即将'` 去比较 —— 既无法
  本地化、又极易出错
- 新增结构化的 `BeaconPhase`（off / disconnected / waitingFix / counting /
  imminent）与 `beaconSecondsLeft`；UI 改为按 phase 判断 + l10n 渲染
- `nextBeaconIn` 保留但改为按 `AppState.locale` 自行本地化；
  通知栏文案（已连接/连接中/在线/收包/信标）一并本地化
- 移除 `widgets.dart` 里按中文串映射的旧助手 `localizedNextBeaconValue()`
- 修正繁體中文（`zh_TW`）取本地化实例的判断：本应用语言码用**下划线**
  （`zh_TW`），此前误写成 `zh-TW`，会让繁體用户回落成简体文案
- `AppState.nextBeaconIn` used to **return Chinese strings** and the UI even
  compared with `== '即将'` — unlocalizable and error-prone. Added a structured
  `BeaconPhase` enum + `beaconSecondsLeft`; the UI now switches on the phase and
  renders via l10n. Notification-bar texts are localized too, and the legacy
  Chinese-string-mapping helper was removed.
- Fixed the `zh_TW` locale lookup: the app stores language codes with an
  underscore (`zh_TW`, not `zh-TW`), so Traditional Chinese no longer fell back
  to Simplified.

## [1.6.77] - 2026-09-11

### 🌐 荣誉墙多语言（此前只有中文）
两处成因，都已修：
- **页面文案硬编码**：`honor_wall_page.dart` 原本 **0 处** `S.of(context)`，
  标题/分区/统计全写死中文；`early_member.dart` 的徽章面板同样如此
  → 新增 7 个 l10n 键（荣誉墙 / 账号荣誉 / 成就 / 未点亮 / 徽章 +
  「已点亮 n/m 徽章」「n/m 成就」带参），三语齐全
- **徽章与成就文案只有中文**：`Honor` 与 `Achievement` 原本只存单个
  中文串；`members.json` 解析时也**只取 `zh`**（丢掉了 zh-TW/en）
  → 两个模型都新增可选的三语 `labels`/`descs`（**向后兼容**：未提供时
  回落中文，旧调用与旧缓存不受影响），并提供 `labelOf/descOf`、
  `titleOf/descOf`
  → 解析、持久化（`_serializeDefs` 与反序列化）、离线兜底定义
    （8 个徽章，文案取自 members.json）全部带三语
  → 新增 `honorLangOf(context)` 判定 zh / zh-TW / en（按 languageCode +
    countryCode/scriptCode）
- 台站详情、设置页里的徽章名也改为语言感知

### 🔧 修正上一版引入的编译错误（CI 报错）
- `HonorWallPage` 与 `_HonorWallSheet` 都是 **StatelessWidget**，自身**没有**
  `context` getter；顶层函数 `_badgeTile` 同样无 context。
  上一版在这些位置直接写了 `honorLangOf(context)` / `S.of(context)`，
  导致 analyze 报 6 处 `undefined_identifier`
- 已把 `context` 改为**显式参数**传入（`_honorTile` / `_achTile` /
  `_badgeTile`），调用处同步传参

### 🐛 沉浸地图：右侧按钮与速度卡重叠（结构性修复）
- **根因**：右侧按钮列（贴顶）与速度卡（贴底）各自 `Positioned`，
  按钮 6 个共约 280px ⇒ 矮屏（尤其横屏 360~450）必然重叠
- **改为合成同一个 `Column`**（按钮在上、速度卡在下），
  外面再包 `FittedBox(scaleDown)` 兜底：总高超出时整体等比缩小，
  **既不重叠也不溢出**（仅在极矮屏生效）
- 左侧「附近台站」面板在 `height < 380` 时自动隐藏，避免与左侧上下
  两组 HUD 争位置

## [1.6.76] - 2026-09-11

### 🗺️ 沉浸地图：其它台站仍看不到（放宽视野 + 提高可见性）
实测定位到根因，**之前两轮修的方向对但力度不够**：
- **可见范围远比预期紧**：该页画布取屏幕对角线（旋转不露白），
  但**可见屏窗口只占对角画布的约 45%**，实际可见跨度
  ≈ `屏幕px / 256 · 360° / 2^zoom`。实测（400×800 屏）：
  **zoom 15 ≈ ±1km、12 ≈ ±6km、10 ≈ ±47km、9 ≈ ±90km**
  —— 之前取 12 仍太紧，现改为 **10**（覆盖典型 APRS 覆盖范围）
- **圆点太不显眼**：此前 `C.slate @0.55`、半径 3.2，在花哨底图上几乎看不见。
  现改为**深色描边 + 亮青实心**（在线）/ 偏灰（离线），半径 4.0/3.0，
  浅街道图与深卫星图上都醒目

### 🐛 地图页右侧按钮重叠（结构性修复）
- **根因**：右侧原本是 **4 个各自 `Positioned` 的硬编码 `top`**
  （14 / 58 / 102 / 146），而 `_zoomCtrl()` **实际含 6 个按钮**
  （放大/缩小/轨迹/聚合/热力图/定位，一直排到 404）——
  硬编码坐标一旦与实际高度不符，矮屏上必然重叠
- 改为**合并为单个 `Column` 顺序排布**：结构上不可能再相互重叠
- 抽出 `_toolBtn()` 统一 38×38 按钮样式，消除三处重复的 Container 样板

### ✅ 新增回归测试
- `test/immersive_geo_test.dart`（4 项）：
  以二分法求各 zoom 的**可见跨度**并断言单调递减、zoom 10 ≥ ±22km、
  zoom 15 < ±6km；并固定「我自己落在画布正中心」、
  「接收范围为空不过滤台站」、「(0,0) 空岛必须排除」
  —— 避免后续再调缩放时把台站挤出视野

## [1.6.75] - 2026-09-11

### 🗺️ 沉浸地图：左侧「附近台站」面板
- 左侧中部新增**附近台站**窄面板（按距离升序，呼号 + 距离 + 在线/离线色点），
  作为地理参照
- **刻意不干扰主体**：整块包 `IgnorePointer`（**不拦截任何地图手势**）、
  宽仅 116px、半透明黑 46%，并随可用高度**自适应行数**
  （≥700px 显示 7 行 / ≥520px 5 行 / 矮横屏 3 行），不会与四角 HUD 打架
- 右上操作列新增开关（列表图标），可一键隐藏

### 🐛 地图页：沉浸地图入口按钮遮挡其它按钮
- **根因**：入口原本放在 `right:14, top:236`，但右侧 `_zoomCtrl()` **实际含 6 个按钮**
  （放大/缩小/轨迹/聚合/热力图/定位），占用 `146 → 404` —— 入口被**完全压在中间**
- 改为 `left:14, top:58`：左上只有 `_infoChip`（占 14~50），其下直到屏幕底部通栏
  之间均为空白，**任何朝向下都不会碰撞**

### 🏷️ APRSlocus 不再归为「手机 App」（多平台）
- 此前内置映射把 `APALOC` 归入 `app` 类别 → 界面显示「手机 App」，
  但 APRSlocus 同时跑 Android / iOS / Windows / macOS，归类不准确
- 新增设备类别 **`multiplatform`（多平台软件 / Multi-platform）**，
  并把 `APALOC` / `APRSLOCUS` / `APOLOCUS` 三条内置映射改到该类
- （未复用 `software`，因其标签是「桌面软件」，对 Android/iOS 同样不准确）

### 🔖 APRSlocus 软件信息新增「平台」识别
- 信标备注末尾由 `APRSlocus v1.6.75` 改为 **`APRSlocus v1.6.75 Win`**
  （平台短名：Win / Mac / iOS / Android / Linux / Web）
- 台站详情的「APRSlocus 信息」新增**平台**字段，可区分端侧
- 解析在 `state.dart`（实时入库）与 `station_detail.dart`（备注兜底）两处同步实现，
  且大小写归一（`win` → `Win`、`ios` → `iOS`）
- l10n 三语新增 2 键（平台、附近台站）

## [1.6.74] - 2026-09-11

### 🏅 BD1FEH 上「赞助墙」（此前遗漏）
- **根因**：`sponsors.json`（赞助名单）与 `members.json`（称号/成员）是**两套独立数据**。
  之前只把 BD1FEH 加进 `members.json` 授予「赠我以琼琚」称号，
  **从未加进赞助名单**，所以赞助墙上看不到 —— 两者不是一回事
- 已补 **5 处**（赞助墙在官网是写死在 HTML 里的，不在 JSON 中）：
  `docs/sponsors.json`（v2）/ `docs/index.html` / `docs/en/index.html` /
  `docs/zh-TW/index.html` / `lib/sponsor_page.dart`（App 离线兜底名单）
- 顺带把这条写进 `HONORS.md`：新增「③ 上赞助墙」章节，
  明确「**授予 jadeGift 称号 ≠ 上赞助墙**」并列出 5 处同步点、
  `kind` 图标映射、官网 contributor 块模板、avatar 字母惯例

### 🛰️ CONNECT 在线帧带上运行平台
- `>APRSLocus CONNECT` 后追加平台字段，便于在 APRS-IS 上区分端侧：
  `>APRSLocus CONNECT Win` / `iOS` / `Mac` / `Android` / `Linux` / `Web`
- 新增 `AppState.platformTag`（`kIsWeb` 优先，其余按 `defaultTargetPlatform` 映射；
  Windows 简写 `Win`、macOS 简写 `Mac`）

### 🗺️ 沉浸地图：修「其它台站一个都不显示」
- **根因**：`_otherStations()` 里我多加了 `effectiveStatus != St.offline` 过滤，
  而**主地图并不过滤离线台站**（只灰显）。台站数据较旧时全部处于离线，
  结果地图上一个点都不画
- 现在与主地图口径一致：**只按接收范围过滤**（`stationAllowedFor`），
  离线台站由绘制层用**更暗更小**的点表示（保留层级，但不会整片消失）
- 上限 300 → 400
- **初始缩放 15（街道级）→ 12（区域级）**：本页以我为中心，用 15 时
  只有 ~1km 内的台站会进画面，而「其它台站」正是这里的背景参照；
  取 12 可看到数十公里的台站分布（典型 APRS 覆盖范围），需要街道级细节自行放大


## [1.6.73] - 2026-09-11

### 🧭 新增「沉浸地图」页（导航风格）
入口：地图页右侧按钮列（罗盘图标），或从地图直接进入。

**与追踪页的区别：不做左侧大面板**，全部信息压缩到**四角 HUD**，把地图还给用户。

| 角落 | 内容 |
|---|---|
| 左上 | 返回按钮 + 定位状态（来源 / 网格） |
| 右上 | 竖向操作列：航向朝上开关、跟随我、图源切换、放大、缩小 |
| 左下 | **信标发送倒计时**（大字）+ 连接状态 + 累计发送次数 |
| 右下 | **速度大字**（km/h）+ 航向箭头/角度 + 海拔 + 坐标 |

- **只以自己为中心**：地图始终跟随我的位置；其它台站仅作淡色小点参照（不可交互），
  避免干扰导航视线。拖动地图会自动脱离跟随，点「跟随我」回到中心
- **地图跟随航行方向（Heading-Up）**：地图层整体旋转 `-航向`，
  使前进方向恒朝屏幕上方；**停止移动（速度 <0.5）或关闭开关时平滑回到正北朝上**
- 竖屏 / 横屏均支持：四角定位 + 安全区内边距，横屏只是视野更宽
  （进入时临时解锁横屏，退出恢复）

### 🔧 实现要点（避免常见坑）
- **旋转不露白边**：地图层包在 `OverflowBox` 里按**屏幕对角线**尺寸布局，
  再整体旋转 —— 任意角度下其内接矩形仍覆盖全屏，无需放大导致缩放失真
- **旋转不抖动**：GPS 每秒一帧，直接套用航向会跳变；用常驻 `Ticker`
  把展示角度以 16% 系数平滑逼近目标角，并做**跨 0°/360° 就近取角**
  （否则 359°→1° 会反向绕一整圈）
- **HUD 不随地图旋转**：四角信息固定在屏幕坐标系，任何角度都保持水平可读
- **深色半透明 HUD**：底色 `black 52%` + 白色文字，浅色/深色底图上都可读
- 首帧尺寸为 0 时跳过地图层，避免把 0 尺寸传给地图与投影

### 🔧 其他
- l10n 三语新增 8 键（沉浸地图、航向朝上、正北朝上、跟随我、发送倒计时等）

## [1.6.72] - 2026-09-10

### 🗂️ 设置页整理

**① 删除「聊天」设置页，内容并入「数据」页**
- 原「聊天」页实际只剩两件事：清空聊天记录、管理联系人；前者与「数据」页职责重叠
- **清空聊天记录 → 并入「数据维护」页**：新增独立卡片（显示当前条数 +
  清空按钮 + 二次确认弹窗）
- **原「聊天」入口替换为「设备」**：新增 `DeviceSettingsPage`，点开显示
  「前方施工，尚未开放」占位（图标 + 提示文案），为后续电台设备接入预留
- 按你的确认，**「管理联系人」一并移除**（消息页仍可添加/收藏联系人，
  但不再有删除入口）

**② 整理「连接」设置页**（原先 4 张卡片职责混乱）
- **「服务器（连接状态）」+「服务器配置」→ 合并为「APRS-IS 连接」**
  —— 原先两张卡标题都指向服务器、语义重复；现为一张：
  连接横幅 → 连接信息 → 服务器/端口/Passcode/WebSocket → 配置变更提示与重连
- **「存储上限」从「过滤」卡片中拆出**，独立为「数据上限」卡片
  —— 最大台站数 / 数据包条数 / 轨迹点数三项与「取哪些台站」无关，
  而是「本地保留多少数据」，混在过滤卡里语义错位
- 过滤卡片副标题同步修正：`接收范围与台站上限` → `过滤中心与接收半径`
- 整理后顺序：**APRS-IS 连接 → 过滤中心 → 数据上限 → 接收筛选**

### 🔧 其他
- l10n 三语新增 11 键（设备设置、前方施工、数据上限、APRS-IS 连接、聊天记录等）

## [1.6.71] - 2026-09-10

### 📈 轨迹与数据包上限改为可配置（原先硬编码，明显偏小）
排查发现「轨迹显示不全」不是单一原因，而是 **4 处独立上限/条件**叠加，
且数据包另有 1 处硬编码：

| 项 | 原值 | 现值 |
|---|---|---|
| 数据包保留条数 | 硬编码 **200** | **2000**（可配置，下限 100） |
| 台站轨迹点数 | 硬编码 **60** | **300**（可配置，下限 20） |
| 演示模式加点上限 | 硬编码 60 | 同上 |
| 我的轨迹点数 | 硬编码 200 | 同上 |

- 抽出 `AppState.maxPackets` / `maxTrackPts` 两个字段并**持久化**
  （原先散落 4 处魔法数字：`state.dart` 的 2324 / 2208 / 2916 / 1452 行）
- 新增 setter：`setMaxPackets()` / `setMaxTrackPts()`
  —— 改小会**立即裁剪**已超量数据，不会等下次才生效
- 设置页「接收范围」区新增两个输入项（复用既有 `SettingsInput` 模式，
  与 `maxStations` 一致）：**数据包保留条数**、**轨迹点数上限**
- l10n 三语新增 4 键

### ⚠️ 仍存在、需你决定的一项：轨迹不持久化
- `_saveStations()` 的 JSON 里**没有 `track` 字段**，所以**重启 App 后所有轨迹清零**
- 未擅自修改的原因：轨迹一旦落盘，体积会随「台站数 × 轨迹点数」增长
  （如 500 台站 × 300 点约数 MB），而 `SharedPreferences` 是全量 XML 加载，
  可能拖慢启动。需先确定策略（只持久化收藏/跟踪台站？限制总点数？）
- 另：记录条件为**位移超过 20m 才记点**，因此**慢速移动或原地微动时点会稀疏**，
  这是刻意避免静止堆积重复点，但也会让轨迹显得不连续

## [1.6.70] - 2026-09-10

### 🐛 天气面板：点击面板外的空白处无法关闭
- 根因在 `DraggableScrollableSheet` 的 `expand` 参数。Flutter 源码里：
  `widget.expand ? SizedBox.expand(child: sheet) : sheet` ——
  我此前设了 `expand: true`（也是默认值），sheet 被 `SizedBox.expand`
  **撑满整个屏幕**，面板的渲染树因此盖住全屏；点击「面板外」的空白处
  落到的是面板自己的树，**永远到不了下层遮罩**，所以点空白退不出去
- 改为 `expand: false`：sheet 只占 58%，上方空白归还给遮罩，点击即关闭。
  `snap` 吸附不受影响（吸附位置按 `constraints.biggest.height` 计算）
- 另显式声明 `isDismissible: true` / `enableDrag: true`，并给出可见遮罩
  （黑色 28%），让「点外部可关闭」这件事可被感知

### 🐛 台站列表不显示自己台站的设备信息
- 本机信标的 `path` 首段是 `APALOC`（本应用专用标识），而**官方 tocalls
  设备库里没有该条目** → `toCall` 查不到设备 → `deviceName` 为 null
  → 台站列表里自己（以及其他 APRSlocus 用户）**不渲染设备标签**
- 在设备库里内置一份补充映射（`APALOC` / `APRSLOCUS` / `APOLOCUS`
  → APRSlocus，类别 `app`），每次解析库后追加，
  **远端刷新（会整体覆盖 `_devices`）不会把它冲掉**
- 效果：自己的台站在列表/详情里显示「APRSlocus」设备标签，
  并出现在「设备类别」筛选中（手机 App）

## [1.6.69] - 2026-09-10

### 📍 修复 iOS / macOS 无法定位（两个平台各自不同的根因）

**macOS：缺少沙箱出网权限，整个网络是死的**
- `DebugProfile.entitlements` 与 `Release.entitlements` 均开启了
  `com.apple.security.app-sandbox`，但**都没有 `com.apple.security.network.client`**。
  沙箱下缺少该键会阻断**一切对外连接** —— 所以不只是定位：
  APRS-IS 连不上服务器、天气、检查更新全部失败
- 已补 `com.apple.security.network.client`（两个 entitlements）
- 另补 `com.apple.security.personal-information.location` + `NSLocationUsageDescription`

**iOS：定位通道从未实现**
- `ios/Runner/` 里**没有 `com.aprslocus/location` 通道的任何实现**，
  `Info.plist` 也**没有 `NSLocationWhenInUseUsageDescription`**
- 而 Dart 端 iOS 走原生分支 → `checkPermissions` 抛 `MissingPluginException`
  被 catch 当作「未授权」→ 永远停在「请授予定位权限…」，实际永远不可能授权
- 已补：`NSLocationWhenInUseUsageDescription` / `NSLocationAlwaysAndWhenInUseUsageDescription`
  / `UIBackgroundModes: [location]`

### ✨ macOS 改为原生系统定位（原先只有城市级 IP 定位）
- 原先 macOS 被归入「桌面 → IP 网络定位」，误差常在数百公里，对 APRS 上报无意义
- 新增 `macos/Runner/LocationPlugin.swift`（CLLocationManager，含 Wi-Fi 定位），
  由 `MainFlutterWindow.awakeFromNib` 用引擎 messenger 注册
- 现在 macOS 与 iOS 共用同一套通道契约与单位（alt 米 / speed 米每秒 / bearing 度、无效 -1）

### ✨ iOS 新增原生定位实现
- 新增 `ios/Runner/LocationPlugin.swift`：
  `isAvailable` / `checkPermissions` / `requestPermissions` / `startService` /
  `stopService` / `setLocationMode` + 事件通道上报定位
- 由 `AppDelegate.didInitializeImplicitFlutterEngine` 通过
  `engineBridge.applicationRegistrar.messenger()` 注册（引擎头文件中该属性即
  面向「应用级方法通道」的入口），不改动会被重新生成的 `GeneratedPluginRegistrant`
- 丢弃系统首次回调的过期缓存定位（>15s），避免定位瞬间跳到很久以前的位置

### 🛟 兜底：原生通道缺席时自动回退 IP 定位
- `LocService.start()` 在 iOS / macOS 先探测通道是否存在
  （仅这两端探测：Android 的 `checkPermissions` 返回真实权限状态且不抛异常）
- 通道缺席时回退 IP 网络定位并提示「系统定位不可用，改用网络定位…」，
  不再出现「永远等待授权」的死状态
- 两个 Swift 文件已加入各自 Xcode 工程的 Sources 编译阶段

## [1.6.68] - 2026-09-10

### 📊 统计面板：「最近上报」「最远距离」不够精准
- **最近上报**（两个原因）
  1. 台站页**没有秒级 tick**（注释里写的「页内秒级 tick」实际已不存在），
     `_ago()` 只在台站版本变化时才重算 → 「5 秒前」会一直停在「5 秒前」。
     现已为统计面板内置 **1 秒 tick**（仅面板挂载时计时，开销可忽略）
  2. 只给一个无法核对的时间。现同时**显示该台站呼号**
- **最远台站**（三个原因）
  1. **不过滤无效坐标**：`(0,0)` 空岛或解码异常的离谱坐标会直接变成「20000 km」。
     现排除越界与空岛坐标
  2. **不过滤过期/离线台站**：磁盘恢复的历史台站、早已离线的台站也会被计入。
     现**只统计当前仍在线的台站**（5 分钟内上报，与列表口径一致）
  3. **`farCall` 算了却从不显示**：只给「1200 km」没法核对。
     现**显示最远台站呼号**
- 顺带修掉一处自造重复：「最近上报」原先在总览区与「其他指标」卡各出现一次，
  后者改为「大网格数」

### 🐛 接收侧：CsT 匹配收紧为「锚定备注开头」
- 上一版为兼容带前导空格的报文，把 `ddd/sss`（CsT）放宽成**任意位置**匹配，
  反而引入误判。真实语料（1088 条位置包）实测：
  - `'APRS iGate 438.650/144.640MHz'` → 把 `650/144` 当成 **144 节 = 266 km/h**，
    并从备注里删掉原文
  - DF 报告的 `'/031/000'` → 误判为方位角 31
  - FMO 证书 base64 里偶然的 `'298/436'` → 误判
- 现改为锚定 `^\s*(\d{3})/(\d{2,3})(?![0-9])`：既符合 APRS101（CsT 位于备注最前），
  又容忍 1 个前导空格（兼容本应用 v1.6.68 以前及同类缺陷固件发出的报文）
- 复核结果：**消除 3 处误判、0 处真实数据丢失**（命中 261 vs 旧 264，差的正是 3 条假阳性）
- 回归测试补 4 个真实报文用例（iGate 频率 / DF 报告 / 规范格式 / 旧版缺陷格式）

### 🎨 雨丝观感：由「粗而杂乱」改为轻薄雨幕
参数实测收敛（雨、雪、雾、雷闪共用同一套粒子框架）：

| 参数 | 之前 | 现在 |
|---|---|---|
| 近景雨丝数量 | 30–48 | **20–34** |
| 远景雨幕数量 | 24–38 | **14–26** |
| 近景线宽 | 1.0–2.8 px | **0.75–1.5 px** |
| 近景透明度 | 0.20–0.68 | **0.05–0.30** |
| 雨丝长度 | 14–42 px | **9–17 px**（×强度系数 0.35） |
| 远景线宽 | 0.7 px | **0.5 px** |
| 远景透明度 | 0.04–0.26 | **0.03–0.14** |

- **线宽**几乎砍半（上限 2.8 → 1.5；手机 DPR 3 下原先约 8 物理像素，确实过粗）
- **透明度**整体压低，且近景拆成「实 / 虚」两档（虚档为实档的 45% 透明度），
  用**纵深**代替单纯堆叠，观感更有层次而不显乱
- **长度收敛**：原先 14–42px 随机跳变是「杂乱」的主因，现收敛到 9–17px
- 横向摆幅与倾角一并收敛（4→3、2.0+2.0i→1.2+1.1i），减少左右飘忽感

### 🎨 组件的透明度
- 新增**背景纱层**：给动态背景统一叠一层极淡的黑色渐变
  （浅色 5%→9% / 深色 10%→16%，仅一次 fill，开销可忽略），
  让云雨稳定处于「背景」地位、不抢主体文字，同时柔化云团边缘
- **卡片底色略提高**（浅色 0.15→0.19 / 深色 0.10→0.14，
  建议卡 0.07→0.10），保证雨丝飘过时文字依然压得住

## [1.6.67] - 2026-09-10

### ✨ 天气面板
- **可向上滑动展开**：改为 `DraggableScrollableSheet` —— 仍以**半屏（58%）**弹出，
  向上拖动可展开到 94% 覆盖更多内容，向下拖动收起；吸附档位「半屏 / 近满屏」。
  整页内容绑定 sheet 的 scrollController，因此**在任意位置**都能拖动展开
- **业余无线电建议移到三天预报之前**：建议是「要不要架台/怎么通联」的即时决策依据，
  比三天预报更该先看到；顺序调整为 建议 → 三天预报 → 近 15 日 → 详细数据
- 顶部暗角渐变改为随内容滚动（底部淡出到全透明），配合展开后不再出现
  「滚动时固定黑块压住卡片」的观感

### 📊 统计面板
- **移除「平均速度」**：该指标把不同时段、不同运动状态（含静止/离线）的台站速度
  混在一起求平均，数值无法解释、也不可行动，属无意义聚合。已删除
- 补上两个可解释的指标：总览区第三项改为**移动台站数**，
  「其他指标」改为 **在线率**（在线 / 接收范围内台站总数）

### 🏅 荣誉墙
- 授予 **BG7ODE「早期成员」** 荣誉（`docs/members.json` v38）
- 说明：App 与官网均为**运行时拉取** members.json，故该名单更新**无需发版**即时生效

## [1.6.66] - 2026-09-10

### 🎨 统计面板 UI 优化（建立视觉层级）
- **系统总览改为「大数字」层级**：总接收数 / 台站总数以 26px 特粗字呈现，
  次要与第三层指标（总发送 / 接收速率 / 连接状态 / 容量 / APRSlocus 用户 /
  最远台站 / 我的大网格 / 最近上报 / 平均速度）分两行小号列出，
  一眼能看出主次；不再是一排 6 个等重小方框
- **去掉内层「描边小方框」**：原先 6–9 个带底色圆角小格子（仪表盘感）改为
  「值在上、标签在下」的无框排布，靠间距与字号分层，更透气
- **分布列表减列**：原来一行挤 5 列（排名 / 名称 / 条形 / 数量 / 百分比），
  现去掉冗余的百分比列（**条形本身已表达占比**），改为
  「色点或排名 + 名称 + 条形 + 数量」，数字并加千分位
- **大网格前三名高亮**：排名徽章加淡蓝底与蓝色序号，第 4 名起条形降透明度，
  排名感更强
- **卡片统一**：圆角 14、去掉描边（靠底色分层）、内边距收紧；区块标题与
  天气面板同一套字号
- **清掉硬编码深色值**：原先写死 `0xFF1B2230` / `0xFF222A39`，改为使用
  主题 token（`C.white` / `C.greyBg` / `C.border`，本身已随深浅色切换），
  深色/自定义主题下不会再出现色偏

## [1.6.65] - 2026-09-10

### 🐛 修复：使用台站筛选时列表只剩一句「未找到台站」
- 现象：应用台站筛选（或在有搜索词 / 接收范围）后，若没有台站符合条件，
  列表区只显示「未找到台站」，**看不出是被什么条件挡掉的，也无法一键清除**
- 说明：筛选逻辑本身是正确的。典型触发场景是——**App 刚启动时从磁盘恢复的
  台站 `lastHeard` 都是旧的，有效状态即为离线**，此时点「在线」筛选自然一个
  都不剩（这是正确结果，不是筛选算错），但界面缺上下文
- 现在改为**筛选感知的空状态**：
  - 无任何条件时：仍显示「未找到台站」
  - 有筛选/搜索/接收范围时：改显示「当前筛选条件下没有台站」+ 原因说明
  - 列出**全部生效条件**（状态 / 类型 / 同款软件 / 设备类别 / 设备型号 /
    搜索词 / 接收范围×N），一眼看清是什么把台站挡掉了
  - 提供一键**「清除筛选」**（清空台站筛选）与**「清除搜索」**
  - 空状态区域可滚动，窄屏/横屏不会被挤掉
- 新增回归测试：过期台站的有效状态为离线 → 「在线」筛选应得空结果、
  清空筛选后恢复全部、`isEmpty` 判定正确（固定住空状态切换所依赖的契约）

## [1.6.64] - 2026-09-10

### 🎨 天气面板：默认半屏 + 上半部分信息加密
- **弹出高度改为「优先半屏」**：由 88% 屏幕高降到 **58%**，不再一上来就占满屏幕；
  底部卡片区域可滚动，**顶部温度与关键指标固定可见**
- **上半部分信息密度提升**：新增一行「今日 18° ~ 26° · 体感 25° · 观测 14:30」，
  并把原先沉在底部的**关键指标上移到顶部**（湿度 / 风向风力 / 气压 / 能见度 /
  露点 / 云量，两列紧凑清单）
- **消除重复**：指标总表统一由 `_metricPairs()` 提供，前 6 项在顶部、
  其余（风速 / 降水 / PM2.5 / PM10 / 首要污染物 / 日出 / 日落 / 紫外线）
  留在底部卡片，两处**互不重复**
- 中部留白由 84px 收窄到 34px（顶部已承载信息，留白改为纯粹的背景展示区）

## [1.6.63] - 2026-09-10

### 🐛 修复：雨丝/雨幕「消失」（v1.6.57 起存在）
- 根因：v1.6.56 做性能优化时把雨丝由逐滴 `canvas.drawLine()` 改为批量
  `canvas.drawPath()`，但**漏了 `..style = PaintingStyle.stroke`**。
  `drawLine` 不受 `Paint.style` 影响，而 `drawPath` 默认是
  `PaintingStyle.fill` —— 只有两个点的开放路径按填充处理时面积为 0，
  **完全不渲染**。因此自 v1.6.57 起雨丝（近景）与雨幕（远景）其实一直画不出来，
  v1.6.57「雨丝密度提升」也因此看不出效果
- 已为近景雨丝、远景雨幕显式加上 `PaintingStyle.stroke`；
  并复查全部 `drawPath` 调用点（雨丝/雨幕/闪电均已 stroke，
  雪/太阳/雾为 `drawCircle`·`drawRect` 填充，无需改动）

### ⚡ 性能：动态背景不再「卡」、不再像纯 CPU 画界面
经实测量化（400×680 画布，软件光栅化基准）：

| 方案 | 每帧耗时 |
|---|---|
| 原实现：每帧 12 次 `MaskFilter.blur` 云团 | 2.61 ms |
| 仅雨丝（不含云） | 0.39 ms |
| **新实现：云朵烘焙成图片后 blit** | **1.08 ms（2.4×）** |

- 卡顿根因：`MaskFilter.blur` 会强制**离屏渲染 + 多次采样**，而原实现每帧
  对 4 朵云做了 12 次模糊，占特效层约 **84%** 开销；Windows 桌面还会因此
  退化到 CPU 光栅化（观感即「纯 CPU 计算界面」）
- 现在把云朵**离线烘焙成一张 `ui.Image`**（模糊只做一次），
  每帧仅 `drawImageRect` 贴图 + `ColorFilter` 调色
- 特效层抽出 `_FxLayer` 并在内部包 `RepaintBoundary`
  （`isComplex` + `willChange`）：**每帧只重绘背景这一层**，
  不再连带面板上的全部文字与卡片一起重光栅化
- 画笔/着色器按需缓存（含云朵贴图着色），不再每帧重建 `Paint` 与 `Gradient`

### 🎨 特效观感重做
- **云**：由「单个椭圆 + 两个圆鼓包 + 一个点」改为 1 个偏平底盘 + 5 个大小不一的
  团块叠成，轮廓更蓬松自然；强度仍驱动数量(2–4)/明暗/漂移速度
- **雨**：明显加长（14–28px）、下落加快（约 0.7–1.1s 穿屏，原先太慢像在飘雪）、
  倾角更大、近景远景分层对比更强
- **雷雨**：整屏瞬闪改为双频叠加（3Hz+7Hz）形成不规则节奏，另加闪电支干
- **晴**：新增柔和日晕（径向渐变）+ 极缓慢细卷云，不再只是几个亮点
- **雾**：改为几条横向雾带（线性渐变）缓慢漂移，替代原先的实心椭圆
- **雪**：下落速度调慢（约 5–9s 落到底），不再像雨

### 🎨 面板 UI 重做（统一设计规范）
- **顶部暗角**：从「一块黑色圆角方块」改为**全幅渐变**（black .36 → .10 → 0，
  280px 高、无圆角无边界），不再像一块污渍
- **去掉逐字阴影**：原先城市名/温度/状况/分组标题/建议正文全部套 `_kTextShadow`，
  文字发糊；现改为由顶部渐变 + 卡片半透明底承担可读性，字形干净
- **温度排版**：由「52px 里塞一个同样巨大的 °」改为**大数字 58 + 小度数 22 且抬高**，
  字距收紧（-2），并让天气图标与状况文字并入同一基线组
- **统一圆角/层次**：面板 28 → 卡片 24 → 内层 16/14/12，替代原先 20/16/11/10
  的随意取值；**去掉卡片黑色投影**（叠在彩色渐变上会发灰变脏），
  仅靠白色半透明面 + 1px 描边分层
- **空气质量胶囊**：由高饱和实色块＋投影，改为**深色半透明底 + 等级色圆点 + 文字**，
  在任意背景上都耐看且不抢主体
- **三天预报行**：列宽对齐、字号统一，行间用**细分隔线**替代 9px 空隙；
  日期列改为「今天 / M·d」两行，最低温降为 70% 白、最高温加重，层级更清楚
- **详细数据**：把原先 **12 个描边小方格**（3 列 × 4 行，低对比度、仪表盘感）
  换成**两列「标签 —— 数值」+ 细分隔线**的清单式排布，可读性显著提升
- **建议条目**：去掉「3px 竖条 + 描边级别胶囊 + 图标」三重装饰，
  改为**色点 + 小号彩色级别文字 + 正文**；危险项仅用淡色底，
  不再堆边框
- **「查看近 15 日天气」**：由 `OutlinedButton` 改为自定义按钮
  （固定 44 高、可内容居中、字重可控、右侧 chevron），与卡片风格统一
- 15 日弹层同步采用同一套排版（细分隔线、列宽与字号统一）
- 修复：`Divider` 在 `CrossAxisAlignment.start` 的 Column 中会**塌成 0 宽而不可见**，
  改用显式 `width: double.infinity` 的细分隔线

## [1.6.62] - 2026-09-10

### 🐛 修复
- **未选择国家/地区时台站全部不可见**（存量逻辑不一致）：
  上报入口一直按「未选择国家时不限制」接收并入库，但 `stationAllowedFor()`
  在未选国家时对**所有**台站返回 false，导致台站虽已收到却在
  **台站列表 / 地图 / 统计面板 / 跟踪成员** 上全部不可见（表现为「什么都没有」）。
  现统一为 **未选择 = 不做限制（接收全部台站）**，与「接收其他台站」及上报入口语义一致；
  设置页提示同步改为「未选择国家/地区 · 不做限制（接收全部台站）」
- 新增回归测试 `test/station_filter_test.dart`：覆盖「未选国家=不限制」、
  「已选国家按前缀过滤 + 收藏始终可见」、以及 `StationFilter` 各维度命中判定


## [1.6.61] - 2026-09-10

### 📊 新增统计面板（台站面板内切换）
- 台站面板新增「台站列表 / 统计面板」切换，样式与消息页的「瀑布流 / 会话」一致；
  **刻意不做持久化**，每次进入都默认回到台站列表，不记忆上次选择
- 统计面板内容（全方位了解 APRS 接收概况）：
  - **系统总览**：总接收数 / 总发送数 / 接收速率（包/分）、台站总数与容量上限、
    连接状态、我的大网格、APRSlocus 用户数、最远台站距离
  - **台站状态分布**：在线 / 移动 / 静止 / 离线（含占比条）
  - **APRS 类型分布**：移动 / 固定 / 基础设施 / 气象 / FMO / 其他
  - **大网格台站分布**：按 Maidenhead 大网格（4 位 Field+Square）统计数量并
    降序排序，带排名、占比；另附网格总数
  - **设备类别分布**（按识别出的 tocalls 类别）
  - **其他指标**：平均速度、最近上报时间、近期数据包数
- 统计结果按「台站版本 + 收包数」缓存，避免每秒 tick 重建时对数百台站反复全量扫描

### 🔗 台站筛选可应用到地图
- 台站面板的筛选（状态 / 类型 / 同款软件 / 设备类别 / 具体型号）抽成共享的
  `StationFilter`，台站列表与地图**共用同一套判定**（`StationFilter.matches`），
  避免两处筛选行为不一致
- 地图「图层筛选」弹层新增开关「台站筛选应用到地图」（默认关闭，避免误隐藏台站）；
  开启后地图仅显示符合台站面板筛选条件的台站，并提示已生效


## [1.6.60] - 2026-09-10

### 🗺️ 台站筛选与国内图源
- **新增腾讯地图 / 腾讯卫星图层**（归入「国内地图」分组，与高德并列）：
  - 腾讯瓦片为 GCJ-02 且 **y 轴为 TMS**（与 XYZ 相反），已做 2^z-1-y 翻转
  - 引入统一的 `isGcjMapType()` 判断，地图页与跟踪页的坐标纠偏同步生效
    （此前仅高德参与 GCJ-02 纠偏，新增图源会自动对齐）
- **新增 ISS 空间站筛选**：一键筛出国际空间站台站（RS0ISS / NA1SS / OR4ISS，
  含 ARISS 相关对象台），位于台站面板筛选行

### ⚠️ 说明
- **百度地图未加入**：其公开瓦片接口（maponline*.bdimg.com）现返回空白占位图
  （需申请 AK 密钥+签名）且需 BD-09 与其自有缩放体系，待确认密钥方案后再接入


## [1.6.59] - 2026-09-10

### 🛰️ APRS 位置解析修正（对齐 APRS101 / aprslib 参考实现，实测 1172 条真实报文）
- **压缩格式（LoRa APRS 等第三方设备）解析全面修正**——此前速度/方位角无法正确解析、
  且相关字符会残留在备注里：
  - Base91 解码改为 `ASCII − 33`（此前误用自定义字符表，导致经纬度整体偏移）
  - 修正字段偏移：符号表 `c[0]`、纬度 `c[1:5]`、经度 `c[5:9]`、符号 `c[9]`、航向/速度 `c[10:13]`
  - **航向改为 4° 步进**（`c1×4`，此前直接取原始值导致方位角偏小 4 倍）
  - **速度改为指数公式** `(1.08^s1 − 1)×1.852`（此前误用线性换算）
  - 支持 csT 中的海拔字段；备注从固定段之后 13 字符起算（此前早 2 字符，
    导致航向/速度/类型字节**泄漏进备注**）
- **新增 Mic-E 解码**（第三方移动台最常用格式，此前完全无法解析）：
  纬度数字与南北、东西由目的呼号编码，经度与航向/速度在信息字段中
- **新增 `/` 前缀（带时间戳、无消息能力）位置包**，此前仅支持 `@`
- **航向/速度 ddd/sss 兼容任意位置**：部分第三方固件把 `/A=` 放在前面，
  此类报文此前会把 `255/003` 留在备注里；现在统一剥离（`000/000` 亦剥离）
- 高度 `/A=` 改为固定 5-6 位数字匹配，不再贪婪吞掉后续数字（如 `70cm`）
- 位置模糊（空格位）按模糊格中心取值；非法/越界坐标直接拒绝，不再乱解析

### 🔧 其他
- **本应用信标备注顺序修正**：把 `ddd/sss`（航向/速度）移到备注最前（APRS101 规定），
  否则 aprs.fi 等第三方地图不会解析，会把速度/方位角当普通备注文字显示
- **台站详情面板在线标签修正**：改用 `effectiveStatus`（超过 5 分钟未上报即显示离线），
  此前一直显示「在线」
- 新增解析回归测试 `test/aprs_parse_test.dart`（11 条真实报文，期望值取自 aprslib）


## [1.6.58] - 2026-09-10

### ✨ 天气组件重构
- **面板 UI 按新设计重排**：顶部为城市名 + 大号当前温度 + 天气状况 + 空气质量胶囊；中部留白作为动态背景展示区；底部改为半透明圆角卡片（不使用 BackdropFilter，避免每帧模糊开销）
- **三天预报列表**：日期（今天/明天/后天/星期）、天气图标、最低温、温度进度条（CustomPainter 绘制，颜色随温度由冷蓝到暖红）、最高温
- **新增「查看近 15 日天气」按钮**：底部弹层展示 15 日趋势（懒加载 `/v7/weather/15d`，同样含温度进度条与降水量）
- **新增空气质量**：`/v7/air/now` 取 AQI，顶部胶囊按国标等级配色（优→严重污染），详细数据区补充 PM2.5 / PM10 / 首要污染物
- **详细数据补全**：湿度/露点/云量、风向/风力/风速、气压/能见度/降水、日出/日落/紫外线
- **文字统一纯白 + 投影**：背景渐变整体加深，保证明亮背景下依然清晰

### 🎨 动态背景按强度驱动
- 新增 `weatherIntensity`（0.0–1.0）：小雨/中雨/大雨/暴雨按现象代码递增并用降水量微调，雪/雾/阴/多云为较小值
- **云层**：强度越高 → 数量越多（2–4 朵）、颜色越暗（向深灰蓝插值）、漂移越快（循环无缝缓动）
- **雨滴**：强度越高 → 下落越快、雨线越密（近景 34–56 / 远景 30–48）、透明度与长度增加、倾角变大
- 雪/雾同样随强度调整密度与速度；天气或强度切换时背景渐变以 `AnimatedContainer` 平滑过渡
- 画家改为 `CustomPainter(repaint: animation)`，粒子参数缓存跨帧复用，重绘不再重建粒子数组

### 📡 业余无线电建议大幅扩充
- 建议分级：**安全警示 / 注意 / 通联机会 / 操作提示**，按级别配色并排序展示，超过 4 条可展开
- 新增规则：雷击浪涌防护（拔馈线/断电）、雷暴前后 QRN、暴雨极端降水撤离、6 级大风禁止上塔、天线结冰驻波与冰载、0℃ 以下低温电池与冻伤、高温功放降额、沙尘与霾污染防护、露点结露、紫外线、低气压预警、高气压大气波导、日出日落灰线 DX、夜间低波段


## [1.6.57] - 2026-09-09

### ✨ 调整
- **雨丝更密集**：近景雨丝 44~52（雷雨 52 / 普通雨 44，原 26~30）、远景雨幕 42~34，保持批量 Path 绘制不增卡顿
- **成员荣誉**：荣誉墙 imThree 改为呼号 BG4LZY（members.json v33 + 官网/App 同步）


## [1.6.56] - 2026-09-09


### ⚡ 性能优化
- **天气动画大幅优化，修复雨/雷雨场景卡顿**：
  - 雨丝改为批量 `Path` 一次绘制（原先每滴逐条 drawLine + 逐条改 paint/掩膜，现近/远景各 1 次 drawPath）
  - 云朵由每朵 6-7 个模糊圆改为 1 模糊椭圆 + 2 顶部圆（mask 绘制次数降约 75%）
  - 粒子参数（位置/相位/速度/外形）首帧缓存复用，不再每帧重建随机数组
  - 削减雨/雪粒子总数上限、去掉雪粒子逐点模糊、雾纹去掉重型 blur
- 视觉基本不变，显著降低 GPU 开销，中低端机下雨也流畅


## [1.6.55] - 2026-09-09


### 🔧 调整
- **天气自动刷新改为 15 分钟**：缓存有效期由 30 分钟缩短为 15 分钟；刷新仅在 App 前台（天气组件渲染/可见时）自然触发，后台不轮询
- **移除天气面板手动「刷新」按钮**：不再需要手动更新，数据按 15 分钟自动保持新鲜


## [1.6.54] - 2026-09-09


### 🎨 优化
- **天气动画柔和化**：雨/雪粒子改为「生命周期 + 正弦淡入淡出」无缝循环（粒子在屏幕边缘渐进显现/消失，不再整屏跳变）；云与雾改为正弦往复游走（无取模 wrap）；雨丝增加轻模糊柔边、角度微抖动，近远两层次更通透
- **API Key 环境化**：和风天气 Key 不再硬编码源码，改为构建时注入（GitHub Actions Secrets: `QWEATHER_KEY` / `QWEATHER_HOST`），工作流已接 `--dart-define`


## [1.6.53] - 2026-09-09


### 🎨 优化
- **天气特效柔和化**：云改为模糊圆蓬松云团（不再是硬边椭圆），缓慢横漂有远近层次；雨丝分远近两层（远细淡/近粗亮）+ 斜向摆动 + 朦胧雨幕；雷雨云低沉并偶尔闪电动画；雪粒子近大远小、雾团柔化缓慢漂移


## [1.6.52] - 2026-09-09


### ✨ 新增 / 优化
- **天气面板多语言**：面板全部文案接入 l10n（简中/繁中/英文随 App 语言切换），包括火腿建议、天气详情项、错误提示等
- **雨量/强度影响视觉**：按降雨量级与强度动态调整背景色深浅与雨丝粒子密度/粗细/长度（小雨→阵雨→中雨→大雨→暴雨逐级增强）
- **开发者选项·天气模拟**：高级设置→开发者选项新增「天气模拟」，可一键切换 晴/多云/阴/小雨/中雨/大雨/暴雨/雷阵雨/雪/雾/跟随实时，用于预览不同天气的渐变背景、粒子特效与火腿建议
- 火腿建议/天气错误等文案本地化重构（错误改用 errorCode 便于翻译）


## [1.6.51] - 2026-09-09


### ✨ 新增 / 优化
- **天气面板增强**：新增「业余无线电建议」卡片（根据天气/风力/温湿度/能见度自动给出架台/通联/防雷/出行建议，雷雨置顶红色警示）
- **天气面板视觉升级**：按天气类型显示渐变背景（晴/阴/雨/雪/雷/雾各配色）+ 对应物理粒子特效（飘雨、落雪、雾气、晴空光点循环动画，明暗主题自适应）
- **天气更多信息**：新增 云量、露点，连同 湿度/风向/风力/风速/气压/能见度/降水/体感 三行小格展示；面板高度自适应可滚动


## [1.6.50] - 2026-09-09


### 🐛 修复
- **顶栏布局**：标题改为占满剩余空间（Expanded），修复天气/在线统计组悬在中间、右侧留白问题——天气胶囊与在线标签现在恒定贴右缘


## [1.6.49] - 2026-09-09

### ✨ 新增
- **顶栏天气组件**：在「在线」统计左侧显示当前位置天气与温度（和风天气 QWeather，图标随天气变化），点击弹出浮动面板查看体感/湿度/风向/风力/风速/气压/能见度/降水与城市名，可手动刷新
- **设置-显示 →「天气组件」开关**：可关闭顶栏天气（默认开，持久化）

### 🔧 说明
- 天气数据由和风天气 API 提供（独立开发版 Host；城市定位路径 /geo/v2/city/lookup），随我的位置自动查询并缓存（30 分钟/3km TTL）


## [1.6.48] - 2026-09-09

### ✨ 新增
- **新荣誉「播种」**：在旷野埋下种子，等待遍地开花（sower 徽章：图标/文案/配色随 members.json 在线下发）
- **荣誉墙在线化**：徽章展示顺序与图标由官网 members.json 驱动（本地兜底），此后新增徽章仅需更新官网 JSON，无需发版即可在 App 荣誉墙上呈现


## [1.6.47] - 2026-09-09

### 🚀 性能
- **地图多台站卡顿优化**：台站聚合由 O(n²)（逐对投影+线性查重）重构为 **O(n) 网格哈希**（一次性投影→radius 网格→3×3 邻域合并→桶收集）；屏幕外台站预过滤不再创建 widget；移动台站过多时自动停用脉冲动画，多台站场景显著降低 CPU/重绘压力


## [1.6.46] - 2026-09-09

### ✨ 新增 / 优化
- **台站详情显示荣誉徽章**：命中荣誉墙名单的呼号，详情面板展示其徽章并点击进入荣誉墙
- **赞助页在线更新**：sponsors.json 名单拉取（离线内置兜底）
- **地图性能优化**：脉冲圈隔离重绘 + 台站更快聚合
- **荣誉墙改名 + 按徽章分类展示**（官网）
- **首页贡献者新增赞助组**（三语）
- **官网首页新增荣誉墙入口**

## [1.6.45] - 2026-09-08

### ⚡ 调整
- **成就难度上调**：坐标 500 次、收/发短信各 50 条、数据包 5 万、台站 1500、群组 5、接收范围 5000km
- **官网页面改名「荣誉墙」主题**：成员荣誉墙 · 勋章与成就（标题/描述/hero）
- **会员卡渲染 FIRST FIX**：拉取 firstfix.json 授勋名单命中即显示；荣誉改在姓名下方胶囊

## [1.6.44] - 2026-09-08

### ✨ 新增
- **新荣誉「赠我以琼琚」**：承君厚赠，藏之于心；唯有砥砺，以报清音（授予 BG7ORC / BA3MDC）
- **大量新成员授予**：23 位早期成员批量（BA4JLD/BA4RAB/BA8AFU/…/BG7ORC 等）；BG7ORC 追加 开山/琼琚；BG9KAG 早期成员；BA3MDC 琼琚+早期成员
- **赞助与鸣谢页新增 BG7ORC**

## [1.6.43] - 2026-09-08

### ✨ 新增 / 优化
- **设置首页新增「荣誉墙」入口**（所有用户可进）：我的徽章与成就 / 成就墙 / FIRST FIX；移除电台身份卡片内占位
- **FIRST FIX 徽章**：并入账号荣誉区；文案改为「APRSlocus 1.7.0 开放」；在线授勋 firstfix.json（BG7LZQ 已授）

## [1.6.42] - 2026-09-08

### 🐛 修复
- **修复编译错误（v1.6.41 构建失败）**：荣誉墙头像 errorBuilder 返回 null 非法 → 改为占位图标；FIRST FIX 徽章定义并入 members.json 在线更新

## [1.6.41] - 2026-09-08

### ✨ 新增
- **FIRST FIX 升级为账号荣誉徽章**：并入徽章墙「账号荣誉」区（第 5 枚金色至高荣誉），在线授勋点亮；可选为「主页展示徽章」显示在呼号旁；荣誉墙与入口实时刷新
- **荣誉墙头像显示用户当前 APRS 符号**；**FIRST FIX 在线授勋**（官网 firstfix.json）

## [1.6.40] - 2026-09-08

### ✨ 新增
- **荣誉墙头像显示用户当前 APRS 符号**（设置所选符号 PNG）
- **FIRST FIX · 至高荣誉在线授勋**：官网 firstfix.json 维护授予名单，App 联网拉取命中即点亮；未授勋但全成就=可申请态

## [1.6.39] - 2026-09-08

### ✨ 新增 / 调整
- **成就难度调整**：坐标发送·请求打击 150 次、听没听到/我发出去了吗 各 20 条、Big? Big! 3000km、世界聆听者 3 万数据包、花花世界 800 台站、紧急集合 2 群组；改为累计计数解锁（支持进度）
- **FIRST FIX · 至高荣誉**：荣誉墙新增金色条目——完成 APRSlocus 1.0 全部成就后可向开发团队申请

## [1.6.38] - 2026-09-08

### ✨ 新增
- **荣誉墙专属页（App）**：呼号旁徽章入口点击进入 App 内「荣誉墙」页面（呼号卡 + 账号荣誉徽章 + 成就墙）；点任意已点亮徽章 → 浏览器打开官网徽章专属页 badge.html?honor=xxx（大图/诗意描述/持有者名单）
- **成就墙（本地解锁）**：荣誉墙在「账号荣誉」下方新增成就区，共 7 项成就随使用自动解锁并本地保存（SharedPreferences）：
  - 坐标发送·请求打击（发送一次坐标）、听没听到（收到一次 APRS 短信）、我发出去了吗？（发送一次 APRS 短信）、Big? Big!（接收范围 ≥2000km）、世界聆听者（接收超 10000 数据包）、花花世界（接收超 500 台站）、紧急集合！（组建一个群组）
  - 未解锁成就灰显锁定，解锁后点亮显示图标/名称/说明
- **优先徽章文字化**：主页/设置呼号旁优先徽章显示为「图标 + 徽章名」，多枚附 +N

## [1.6.37] - 2026-09-08

### 🐛 修复
- **「主页展示徽章」选择改为 Dialog**：设置 → 电台身份 → 主页展示徽章行点击后弹居中选择框（更稳定），已获徽章列表当前项高亮，选中即设为主页常驻徽章

## [1.6.36] - 2026-09-08

### ✨ 新增
- **设置页可自选「主页展示徽章」**：电台身份卡片新增「主页展示徽章」行（仅获得徽章者可见），点击可从已获徽章中选择常驻展示的那一枚，本地保存并优先于服务器默认；选择器列出全部已获徽章，当前项带 ✓
- **徽章专属页**：官网新增 badge.html（?honor= 展示徽章大图/诗意描述/持有者名单），会员卡资料区徽章可点直达

## [1.6.35] - 2026-09-08

### ✨ 新增 / 优化
- **徽章墙系统优化**：呼号入口显示「优先徽章」（可配置 primary，多枚才带 ×N）；徽章墙面板头部靠左大呼号、徽章行统一尺寸、已点亮徽章可点击打开官网专属卡
- **最强大脑改授 BA3RZL**：描述改为隐藏成就（为项目提供超 50% 算力支持）；移除「AI 算力支持」徽章，徽章全集收敛为 开山 / 开发人员 / 早期成员 / 最强大脑
- **徽章描述诗意化**：四枚徽章三语文案焕新（电波情怀）
- 官网会员卡资料区版式优化（大头像 + 称号色点徽章行）

## [1.6.34] - 2026-09-08

### ✨ 新增 / 优化
- **徽章墙系统**：呼号旁以「奖牌入口 🏅×N」替代拥挤的多徽章；点击弹出徽章墙面板（右上大呼号 + 逐行展示全部徽章 + 未点亮灰显锁），全集徽章：开山 / 开发人员 / 早期成员 / AI 算力支持 / 最强大脑（BG7LZQ），每枚带三语说明
- **仅 1 枚徽章时不显示数量**：奖牌入口更简洁
- 徽章定义/授予由官网 members.json 统一维护，改动即时生效无需发版

## [1.6.33] - 2026-09-08

### ✨ 新增
- **徽章墙系统**：呼号旁以「奖牌入口 🏅×N」替代拥挤的多徽章；点击弹出底部徽章墙面板（右上角大呼号 + 逐行展示全部徽章 + 未点亮灰显锁）。全集徽章：开山（极早期内测）/ 开发人员（代码·翻译·PR）/ 早期成员（早期公测）/ AI 算力支持 / 最强大脑；每枚带三语说明，点亮状态一目了然
- **BG7LZQ 授予「最强大脑」**：member.json 徽章定义与授予均从官网拉取，改动即时生效无需发版

## [1.6.32] - 2026-09-08

### ✨ 新增
- **荣誉称号体系升级**：一个呼号可拥有多个称号（如 开山 / 开发人员 / 早期成员 / AI 算力支持），App 设置页徽标与官网会员页均支持多徽章展示；名单/称号由官网 members.json 统一维护，改动即时生效无需发版
  - 开发者（BG7LZQ/BG2HCB/BA4UAX/BD3QID）：开山 + 开发人员 + 早期成员
  - BG7PGW / BG7OSL / BG7LMW：开山 + 早期成员
  - BA3RZL：早期成员 + AI 算力支持；imThree：早期成员

## [1.6.31] - 2026-09-08

### ✨ 新增
- **荣誉徽章分「开发人员」/「早期成员」两类**：设置页按呼号命中类型显示蓝色「开发人员」或金色「早期成员」徽章（翻译并入开发人员），点击打开该呼号专属 FIRST MEMBER 会员卡网页
- **名单放官网 members.json 实时更新**：徽章名单 / 会员卡页均改为从官网 members.json 拉取（含 姓名/角色/贡献/寄语/分组），改动后无需发版即可生效；内置名单仅作离线兜底
- **官网会员页翻译并入开发组**：页面收敛为 核心·开发（代码+翻译）/ 测试·反馈 / 支持与赞助 三组

## [1.6.30] - 2026-09-08

### ✨ 新增
- **设置页显示「早期成员」徽标**：当我的呼号命中 APRSlocus 早期成员名单时，设置页问候语与电台设置 SSID 行会显示金色徽标；点击在浏览器打开该呼号的专属 FIRST MEMBER 会员卡网页（官网 member-card.html）
- **地图台站标记改为真实 APRS 官方符号图标**：瓦片 / 矢量地图台站标记不再套“状态色圆点 + Material 图标”，直接显示官方 APRS 符号 PNG（按符号表+符号码匹配、更大更清晰、离线置灰），保留移动/选中脉冲圈与呼号标签
- **瓦片地图台站常驻显示呼号标签**：瓦片底图（高德等）台站图标下方常驻白底圆角呼号小标签，与矢量地图一致；选中时自动切换为详情信息条避免重叠
- **小屏设备横屏显示优化**：大屏手机横屏改用窄侧栏（阈值 920→1024pt）、顶栏/横幅更紧凑；矮横屏自动隐藏右上图例，让地图铺开更全
- **官网新增纪念页与会员卡页**：「电波无限 · 感谢同行」早期成员纪念页（memorial.html）+ FIRST MEMBER 会员卡页（member-card.html，可导出高清 PNG），三语（简/繁/EN）、`?call=` 深链直达成员

## [1.6.29] - 2026-09-08

### ✨ 新增
- **地图台站标记改为真实 APRS 官方符号图标**：主地图（瓦片/自绘）与矢量地图上的台站标记，由“状态色圆点 + Material 图标”改为“白底圆 + 状态色描边 + 官方 APRS 符号表 PNG”（3571 个符号全量支持，按 符号表+符号码 自动匹配，透明底彩色、离线自动置灰弱化），车辆 / 摩托 / 飞机 / 气象站等一眼可辨；资源缺失自动回退原 Material 图标

## [1.6.28] - 2026-09-08

### ✨ 新增
- **地图新增「Carto Positron（浅色矢量）」底图**：设置 → 显示 → 地图类型新增 CARTO Positron 观感的矢量底图（WGS-84），与现有矢量地图（OpenFreeMap Liberty）并存可随时切换；矢量底图 style 按图源分别缓存，切换风格时热重载、不重复下载

## [1.6.27] - 2026-09-07

### 🐛 修复
- **手动指定“我的位置”时接收范围过滤中心未跟随（#8）**：此前 GPS 定位会同步过滤中心，但手动输入坐标（模拟位置）路径漏同步，且会停掉 GPS，导致过滤中心永远停留在旧位置、服务器仍按旧中心推送（“附近暂无电台”）；现在手动设坐标 / 切到模拟位置时会同步过滤中心并在已连接时自动重连应用新范围

### ✨ 新增
- **设置页新增「退出应用」按钮（#9）**：Android / 桌面（Windows / Linux / macOS）在设置页底部可手动退出——确认后先保存设置、停止定位与后台服务、断开 APRS-IS，再按平台结束进程（Android 结束前台服务并移除任务、桌面直接退出），避免强杀进程导致设置未保存

### 📝 文档
- FMO 台站描述去掉“（机动消防）”括号说明（README / 官网）；
- 致谢/贡献者名单新增 **imThree**（Bug 提交与反馈）：README、官网贡献者网页（中/英/繁）、App 关于页同步更新

## [1.6.26] - 2026-09-07

### ✨ 新增
- **智能信标按速度分档**：开启后不再使用固定上报间隔，而是按当前速度自动匹配档位——每档可自定义「触发速度、上报间隔、信标图标」（图标留空则沿用“我的符号”，静止与不同速度段可显示不同图标），支持添加/删除速度档与一键恢复默认；速度越快上报越频繁，适合驾车 / 骑行 / 步行混合使用（设置 → 定位上报 → 智能信标）

## [1.6.25] - 2026-09-06

### ⚡ 性能优化
- **地图页仅在激活 Tab 时构建**：首页底部导航中，地图在后台（其它页面）时不再随数据通知反复重建全部台站标记。台站数量上千时，显著降低其它页面操作 / 切换 Tab 的卡顿与 CPU 占用

### 🐛 修复
- **修复快速创建跟踪组无法创建**：重构新建跟踪组弹层路由时序（不再用已失效的 context 操作导航栈）

## [1.6.24] - 2026-09-06

### ✨ 新增
- **群组跟踪支持快速创建**：跟踪面板新增「新建跟踪组」，从已接收台站勾选成员 + 手输呼号（逗号分隔）即可直接开始整屏跟踪，无需先建聊天群；临时跟踪组不发邀请、不入聊天列表、用完即走

### 🙏 致谢
- 关于页 / README 新增 BA4UAX（繁体中文翻译）

## [1.6.23] - 2026-09-06

### ✨ 新增 / 优化
- **竖屏地图上报状态改为底部通栏横杠**：连接后在地图底部（比例尺上方）显示一条细横条：左侧自动上报状态/倒计时，右侧「立即上报」；不再用悬浮胶囊
- **官网自动显示最新版本号**：官网首页下载按钮与 Hero 徽章通过 GitHub API 拉取最新 Release 版本动态显示，失败自动回退静态版本（免手动更新）
- **文案统一**：简体“群聊”全部归一为“群组”，繁体归一为“群組”（群聊邀请/消息/退出等 17 处），保留“群/群主/群名/群呼号”等合理短称

### 🐛 修复
- **未连接服务器不再自动定时上报位置**：此前只要开启信标+有定位，到间隔就会“模拟上报”（未连接也倒计时）；现自动定时上报仅在已连接 APRS-IS 时进行，未连接时倒计时显示「未连接」

## [1.6.22] - 2026-09-06

### ✨ 新增
- **竖屏地图左下角新增信标/上报状态胶囊**：首页地图竖屏时常驻显示「距下次上报 Xs」倒计时（绿色）或「自动上报已关闭」（灰色），胶囊内含「手动上报」按钮（无定位时变「获取定位」）；点胶囊主体打开我的位置面板（横屏/桌面由侧边栏承担，不重复）

### 🐛 修复
- **连接后“是否自动上报位置”询问在部分手机上不弹出**：原实现连接成功即标记已询问再去弹窗，若主界面尚未就绪会漏弹且永久不再询问；现改为用户做出选择后才记录，并双保险触发（连接成功延时 + 主界面首帧补查），覆盖从设置页等其它入口连接成功的场景

## [1.6.21] - 2026-09-06

### ✨ 新增
- **连接后可选自动上报位置**：连接成功后首次会弹一次「自动上报位置？」选择（自动上报 / 仅接收，记住选择不再重复打扰）；首页连接卡片新增状态条显示 自动上报中/位置未上报，未上报时可一键开启，随时可手动「立即上报」一次
- **连接/保活帧规范为 tocall=APALOC**（正申请 aprs.org 官方登记）：连接成功即发 `>APALOC:>APRSlocus CONNECT` 身份帧，15s 保活帧同步改为标准状态帧，替代原 tocall=APRS + 中文“保持连接”的非标包

### ⚙️ 优化
- **信标间隔不再逐字符弹窗**：改为失焦 / 回车时才校验提示（<60s 的强提示），同值不会重复弹
- **连接后不再自动广播位置信标**：把发射主动权交给用户（自动开关 / 手动按钮）

### 🐛 修复
- **OOBE 权限体验**：启动不再立即弹系统权限框（此前向导未完成就请求定位/通知权限）；改为 OOBE 完成后由应用引导请求并启动定位

## [1.6.20] - 2026-09-05

### 🐛 修复
- **修复定位漂移**：Android 定位服务此前 GPS 与网络（基站/Wi-Fi）定位点无差别直接上报，粗点/缓存位置会频繁覆盖准点导致标记漂移跳动。现在改为 GPS 优先、网络仅在 GPS 停更超 20 秒才兜底；精度超 150m 的粗点一律丢弃（网络兜底点限 80m）；「最后已知位置」兜底同样过滤，不再把旧缓存劣化到当前位置

## [1.6.19] - 2026-09-05

### ✨ 新增
- **繁體中文（zh_TW）界面**：设置页 / OOBE 语言新增「繁體中文」，全量界面文案转繁体（基于官方简繁转换工具，台湾习惯用词），可随时与简体中文 / English / 跟随系统切换
- **README 三语化**：仓库 README 提供 简体中文 / English / 繁體中文 三份（顶部可切换）
- **官网新增繁體中文站**：aprslocus.theez.top/zh-TW/ 上线，导航语言切换升级为 简中 / 繁中 / EN 三入口；更新日志补录至 v1.6.18

## [1.6.18] - 2026-09-05

### ✨ 新增
- **台站详情页「在线查看」**：快捷操作新增「QRZ 呼号」「aprs.fi 位置」两个按钮，一键用系统浏览器查看该台站信息
  - **QRZ 呼号**：QRZ.com 业余电台呼号数据库（QRZ 只收录无 SSID 的基础呼号，如 BG7LZQ-9 → 查 BG7LZQ）
  - **aprs.fi 位置**：aprs.fi 实时台站位置/轨迹页（使用含 SSID 完整呼号）
  - 打开失败会 Toast 提示

## [1.6.17] - 2026-09-05

### ✨ 优化
- **台站页筛选改为单行常驻 chips，即点即筛**：状态(全部/在线/移动/静止)、APRS 类型(车载/固定/中继/气象)、APRSlocus 同款、设备筛选 直接平铺为一行横向滚动 chips，点击即生效不再需要弹面板；点已选中 chip 或「全部」可取消
- **移除 FMO 筛选项**：APRS 类型中不再提供 FMO 分类筛选（FMO 台站仍正常显示）
- **设备筛选抽屉（类别⇄型号联动）**：点「设备筛选」chip 弹出底部面板，设备类别与具体设备型号两组联动——选了类别后型号列表自动收窄为该类别；已选设备时入口 chip 直接显示当前类别/型号并高亮

## [1.6.16] - 2026-09-05

### ✨ 优化
- **台站页分类筛选重做，不再平铺一排长 chip**：常驻行只保留 状态(全部/在线/移动/静止) + 一个「筛选」按钮；其余分类统一收进底部筛选面板
- **分类筛选弹层（分组选择）**：点「筛选」弹出底部面板，按  APRS 类型（车载/固定/中继/气象/FMO）／ 软件（APRSlocus）／ 设备类别 ／ 设备型号 分组；组内单选、跨组可叠加（如“在线 + 车载 + 车台 + Yaesu FTM-400D”）；有选中时面板按钮高亮，随时可“全部清除”
- **筛选结果 tag 行**：选中的类型/软件/设备类别/具体设备在筛选区下方以可单独删除的 tag 展示（点 × 即取消该维度），并提供“全部清除”
- **可精确到具体设备筛选**：设备型号分组列出当前接收范围内识别到的具体厂商+型号（如 Kenwood TH-D74、Yaesu FTM-400D、APRSdroid），出现台站多的排前，可单独或叠加筛选

## [1.6.15] - 2026-09-05

### ✨ 新增
- **台站设备识别（官方 APRS 设备仓库）**：接入 aprs.org 官方设备识别库 `aprsorg/aprs-deviceid` 的 tocalls 索引（维护者 OH7LZB/hessu，CC BY-SA 2.0），通过数据包目的呼号（to-call，如 APDR16）识别出每台 APRS 台站所用的 厂商 + 型号 + 设备类别（车载电台 / 手持电台 / 跟踪器 / 手机 App / 桌面软件 / iGate / 数字中继 / 气象站 / D-Star / 卫星台站等）
- **内置 + 联网自动更新设备库**：App 内置官方 tocalls 精简快照（389 条设备）保证离线可用；联网时后台自动拉取仓库最新 tocalls.yaml 并缓存本地，设备更新无需发版（失败静默回退内置）
- **台站列表新增「设备类别」筛选**：筛选区在原有状态 / 类型 / APRSlocus 同款之外，新增按设备类别过滤的 chips（仅出现过的类别动态显示，点按切换 / 再点取消）
- **台站行内设备标签与详情页设备卡片**：列表行识别到设备时显示「📟 厂商 型号」标签；详情页新增「设备识别」信息卡（目的呼号 / 设备型号 / 设备类别，双语）
- **搜索支持设备名**：台站列表与地图页搜索框可输入设备名 / 厂商型号快速定位（如输入 Kenwood、APRSdroid）

### 🔧 说明
- 识别范围：仅位置类数据包（`!`/`=`/`@` 起始）的目的呼号入库；通用目的呼号（APRS / TCPIP* / BEACON / MAIL）不参与识别；目的呼号随台站持久化，重启后仍可识别

## [1.6.14] - 2026-09-05

### ✨ 优化
- **设置页标题改为问候语**：顶部栏已显示「设置」标题，页内原重复的「设置」大标题改为按时段问候（早上好 / 中午好 / 下午好 / 晚上好 / 夜深了）+ 我的呼号，如「早上好，BG7LZQ」
- **用户协议页改为从官网在线加载并优化排版**：优先拉取官网最新协议全文（改协议无需发版、即时生效），失败/超时自动回退本地缓存并标注「离线缓存」；标题栏新增刷新与「在浏览器打开」；正文按 大标题 / 版本信息 / 章节标题 / 条款正文 / 分隔线 分层排版，行距更舒适；协议语言默认跟随 App 语言，仍可手动切换中英；网络与本地均失败时提供重试

## [1.6.13] - 2026-09-05

### ✨ 新增
- **OOBE 首次启动新增「用户协议」确认步骤**（语言选择之后）：需勾选「我已阅读并同意《用户协议》与 GPL-3.0 开源许可证」才能继续；提供《用户协议》（App 内全文）与 GPL-3.0 查看入口；不同意可退出向导

### 🔧 调整
- **默认信标间隔 30 秒 → 60 秒**：新用户默认按 APRS-IS 移动站建议值 60 秒，减少误用风险（已有用户保留原设置）

## [1.6.12] - 2026-09-05

### ✨ 新增
- **用户协议（使用条款与免责声明 V1.0，中英双语）**：关于页「许可证」区新增「用户协议」入口（点击进入 App 内双语协议页，可切换中文/English）；协议正文存放于 assets/terms_zh.txt 与 terms_en.txt
- **官网新增协议页**：`/terms.html`（中文）与 `/en/terms.html`（英文），首页页脚增加「用户协议」链接；正文与 App 共用同一份文本资产

### ⚠️ 安全提示
- **信标间隔低于 60 秒强提示**：在信标设置中将上报间隔设为 5~59 秒时会弹出强警告（APRS-IS 建议移动站信标不低于 60 秒，过快上报可能被视为滥用），需明确选择「仍然使用」或「改回 60 秒」后才生效

## [1.6.11] - 2026-09-04

### ✨ 优化
- **跟踪页「我」的信息精简**：不再显示自己的速度、相对时间与距离（对自己无意义），改为紧凑展示 航向°速度 · 海拔 · 网格；自己不再显示距离胶囊
- **跟踪页成员显示范围扩大**：横屏左成员栏加宽至 272、竖屏底部成员条加高至 116 且单卡加宽至 244；成员副标题最多显示 2 行，信息更完整不拥挤
- **横屏会话信息条放回地图底部**：聊天预览条从左侧栏移回地图区底部悬浮（完整样式），更符合看地图 + 消息的习惯

## [1.6.10] - 2026-09-04

### 🐛 修复
- **FMO 台站图标与其它 APRS 地图不一致**：收包识别 FMO 后不再强制改写符号为 /i，保留台站原始上报符号（如 /F、\F），图标与其它 APRS 地图一致；FMO 分类靠 fmo 结构化字段判定（无备注时补占位），不依赖图标
- **APRSlocus 台站混入 FMO 过滤**：typeGroup 移除 isAprrslocus→FMO 归并，FMO 过滤只含真 FMO；APRSlocus 走独立过滤
- **跟踪页成员行距离重复显示**：副标题移除距离拼接（仅保留行尾距离胶囊），并增强副标题信息（速度/航向/海拔/网格/相对时间）
- **编译错误**：`const SizedBox` 使用运行时变量导致三平台构建失败，去除 const

## [1.6.9] - 2026-09-04

### ✨ 新增
- **桌面（Windows / Linux / macOS）网络定位**：无系统 GPS 时改用 IP 网络定位（多服务自动切换），获取所在城市坐标作为“我的位置”，可直接上报信标 / 在跟踪组中定位；失败时提示在地图选点

### 🐛 修复 / 优化
- **聊天框回车后保持焦点**：消息页与跟踪页快捷聊天面板回车 / 发送后输入框保持焦点，可连续快速聊天
- **跟踪页底部会话条（横竖屏）**：实时显示最近收到的群/成员消息预览（带头像/未读数/角标），点击直接打开对应聊天回复，不遮挡地图
- **跟踪页体验优化**：
  - 进入跟踪页自动全览所有成员（首屏即见全部）
  - 直接点地图上的成员标记 = 跟随该成员（像素命中），空白处点击才取消跟随
  - 快捷聊天面板自动聚焦输入框

## [1.6.8] - 2026-09-03

### 🐛 修复
- **跟踪页跟随模式无限动画循环导致卡死**：build 中每次重建无条件重启动画导致死循环，改用防循环守护（动画中不重启、位置显著变化才启动）

### ✨ 新增
- **跟踪页「全览」自动保持**：点全览后成员跑出视野自动重新适配（带余量+防抖），始终全员可见；手动拖动/缩放/点成员自动退出
- **跟踪页模式徽章**：地图上显示当前状态（跟随 XX / 跟随我 / 全览保持中）
- **跟踪页成员行卡片化**：状态头像（移动导航图标/离线灰/等待沙漏）、移动中标签、距离胶囊、跟随指示、私聊快捷，视觉更接近导航风格
- **竖屏成员条改横向滑动**：一屏展示更多成员卡片
- **全览按钮状态化**：保持模式开启时高亮，再次点击退出保持

## [1.6.7] - 2026-09-03

### ✨ 新增
- **地图群组跟踪（直接引用聊天群）**：点地图页右上角👥按钮 → 选择已有聊天群，即把群成员放到整屏地图持续跟踪，支持横屏导航风格（左成员栏 + 大地图）
  - 消息页群聊会话顶部新增「群跟踪」入口，一键把当前群成员放到地图跟踪
  - 进入跟踪页临时解锁横屏，退出后恢复用户设置；横屏左成员栏 / 竖屏底部成员条
  - 跟踪列表 = 群成员 ∪ 我自己（高亮“我”）；无位置成员显示灰色“等待位置…”占位不消失
  - 成员状态（在线/移动/离线）、速度、航向、最后上报时间、距离一览
  - 点击成员平滑居中跟随其移动；一键全览；覆盖层自绘无第三方依赖

## [1.6.6] - 2026-09-02

### ✨ 新增
- **地图低缩放热力图**：缩小地图到一定级别（且台站较多）时，自动以热力图展示台站密度（蓝 → 青 → 黄 → 红色阶），替代密集标记 / 聚合球；地图控制栏新增🔥热力图开关

### 🐛 修复
- **Carto 底图水印**：Carto 浅色 / 深色 / 航行者 raster 底图 URL 增加 API key 参数，消除「API key required」水印

## [1.6.5] - 2026-09-02

### ✨ 新增
- **更新页「全部更新日志」**：更新页标题栏新增「全部更新日志」入口，底部面板按版本新→旧展示所有 Release 更新日志，当前版本带绿色「当前」标记
- **地图无台站时弹出帮助面板**：视野内无台站时底部提示点击改为弹出「地图帮助」面板，说明可能原因与基本操作（拖动/缩放、查看台站、图层、定位、搜索）并提供「连接 APRS-IS」快捷按钮；不再提供一键显示全部台站

### 🗑 移除
- **地图「覆盖全部台站」逻辑**：移除 `_fitAll` 自适应缩放（含 `_mercY`）及对应的「点击显示全部」提示

### 🐛 修复
- **国际图源（Carto / OSM / Esri / OpenTopo）地图偏移**：此前所有瓦片底图都按高德 GCJ-02 投影，国际图源为 WGS-84 底图，导致台站标记整体偏移数百米至数公里。现按底图坐标系区分：高德瓦片保留 WGS→GCJ 转换，国际图源直接使用 WGS-84 投影（含自绘兜底底图、坐标反解与悬停 datum 显示）

## [1.6.4] - 2026-09-02

### ✨ 新增
- **台站详情速度 / 高度变化图表**：每次收到位置包记录速度与高度遥测采样，详情页轨迹下方新增「速度 / 高度变化」自绘折线图（速度蓝色、高度紫色，含渐变填充与最新值强调点）
- **可自定义时间范围**：图表支持 10 分钟 / 30 分钟 / 1 小时 / 3 小时 / 全部 切换，点选即时重绘

## [1.6.3] - 2026-09-02

### ✨ 新增
- **关于页分享功能**：新增「分享 APRSlocus」入口，底部面板提供三种方式：分享到系统（Android 调系统分享面板，可分享到微信 / QQ / 短信等）、复制分享文案（含官网与下载链接）、打开下载页（GitHub Releases）

### 🎨 优化
- **模拟位置模式隐藏 GPS 相关设置**：定位来源选择「模拟位置」时，隐藏无意义的「定位模式」（纯 GPS / GPS+网络）卡片；信标上报卡片的「开启 GPS 定位」按钮改为「使用模拟位置，无需 GPS」提示
- **瓦片地图支持更小倍率缩小**：最小缩放级别由 8 级扩展至 3 级（全球概览），缩放按钮 / 双指缩合 / 滚轮 / 覆盖全部台站均生效
- **定位来源与手动定位联动**：选择「模拟位置」时，手动定位坐标设置前置显示并默认展开（便于设置模拟坐标）；选择「使用设备定位（GPS）」时，隐藏手动定位坐标设置（仅显示定位模式选择）

## [1.6.2] - 2026-09-02

### ✨ 新增
- **关于页增加官方网站入口**：用户反馈区块新增「官方网站」链接（aprslocus.theez.top），点击直接跳转

### 🐛 修复
- **v1.6.1 三平台编译失败**：定位模式设置卡片 `_locSourceCard` 的 `color` 参数把 `C.green`（static 变量，非 const）用作默认参数值，触发 `Constant evaluation error`，Windows / iOS / Android 均编译失败；改为可空参数 + 方法内回退

## [1.6.1] - 2026-09-02

### ✨ 新增
- **定位模式选择**：定位 / 信标设置新增「定位模式」选项，支持 **纯 GPS**（仅卫星定位，更省电）与 **GPS + 网络**（网络辅助定位，定位更快）两种模式，切换即时生效并自动持久化
- **原生定位按模式注册**：Android 纯 GPS 模式只监听 `GPS_PROVIDER`，GPS+网络模式额外监听 `NETWORK_PROVIDER`；最后已知位置兜底也按模式过滤，纯 GPS 不查网络位置

## [1.6.0] - 2026-09-02

### ✨ 新增
- **更多地图图层**：新增 Carto 深色 / Carto 航行者 / OSM 人道（自动子域名轮询）/ OpenTopo 地形 / Esri 街道 / Esri 影像，共 11 种底图（全部免 API Key），设置页与地图左上角菜单一键切换
- **矢量地图路径显示**：矢量图层新增「我的轨迹」（蓝色）与「选中台站轨迹」（台站颜色）折线显示，与自绘瓦片地图一致
- **矢量地图选中高亮**：选中台站 Marker 放大为实心圆 + 白色粗描边 + 阴影，选中变化即时刷新
- **地图类型菜单滚动**：图层较多时菜单自动限高可滚动，避免超出屏幕

### 🗑 移除
- **高德 JS 地图**：移除 WebView 承载的高德 JS API 2.0 实现（`amap_js_map.dart` + `amap_map.html`）及相关 `webview_flutter` / `webview_windows` 依赖，一并消除硬编码的明文高德 API Key 泄漏隐患
- **Windows 高德 JS 回退逻辑**：随高德 JS 移除，Windows 不再需要 WebView2 兼容回退与 `_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS` 编译宏

### 🎨 优化
- **瓦片降级链重构**：由高德 → Carto → OSM 三级硬编码改为通用候选列表（当前图源 → Carto 浅色 → OSM → 空白），任一图源失败自动逐级降级，矢量地图不再进入瓦片渲染
- **图源地址统一分发**：所有瓦片 URL 由 `_url(MapType)` 统一分发，新增图源只需在枚举与分发处各加一行

## [1.5.8] - 2026-08-30

### 🐛 修复
- **台站列表「在地图显示」按钮无反应**：按钮空 `onPressed` 抢占了点击手势导致 `focusOnMap` 不触发，现点击可直接跳转地图并定位该台站
- **Passcode 错误通知的「去设置」跳转无效**：原来只切到设置页首页，现直接打开「连接设置」页（passcode 输入所在位置）

### ✨ 新增
- **测试用 CI**：新增 `ci-test` 工作流（手动 / push / PR 触发），自动运行 `flutter analyze`（忽略已知误报）并构建 Windows / Android 产物，不发版、不推送任何远端

### 🎨 优化
- **设置页 UI 统一优化**：样式一致性、折叠分区收起后更紧凑、恢复开关的点击区域等（来自上游 PR）

## [1.5.6] - 2026-08-30

### 🐛 修复
- **长时间运行后 UI 卡顿（键盘输入/键盘动画明显掉帧）**：APRS 运行越久、台站越多越卡，且停止收包后卡顿仍然存在。根因是每秒 tick 对全局 AppState 全量 `_notify()`，导致 IndexedStack 内全部页面每秒重建并反复重算几百个台站数据，地图 Marker 每秒全量重建；收包越多、运行越久，GC 与主线程压力越大
- **更新页每次误弹「签名已更换 · 需卸载重装」提醒**：release 签名自 1.5.2 起已固定，旧提示残留未删干净，现彻底移除
- **OOBE 引导页切换偶发卡死**：快速连点「下一步/上一步」时 PageView 与步骤号失步；动画 Future 异常时状态卡死导致界面无响应。已改为以步骤号为唯一依据、动画带异常回退与兜底定时器，消除卡死

### 🎨 优化
- **渲染与数据隔离**：地图可见台站列表 / Marker 缓存按台站数据版本隔离——台站没变化时每秒 tick 不再重建任何 Marker；台站位置/状态/符号真正变化时仍即时刷新
- **秒级刷新解耦**：每秒 tick 改为独立通知器，只刷新信标倒计时、收包速率等秒级 UI，不再重建整个页面树
- **台站页流式加载**：台站列表改为只订阅台站数据流（`stationsStream`），连接/消息/GPS/设置等无关变化不再触发整页重建
- **页面子树记忆化**：主页重建不再连带重建全部 5 个页面，键盘动画期间不再每帧全量重建
- **台站统计缓存**：在线/移动/静止计数按台站版本惰性计算，避免每次重建全量扫描
- **台站列表 key 抖动修复**：移除每 5 秒整行重播入场动画的问题，「X秒前」改为独立秒级刷新
- **地图标记渲染**：矢量 / 高德 JS 地图按台站版本复用 Marker，不再每秒把全部台站 JSON 全量推给 JS
- **删除安装包支持多版本**：本地按版本会累积多个安装包，现支持删除前确认、列出全部本地安装包并一键「删除全部安装包」（显示数量与占用空间）

### 🛠 CI / 发布
- **移除 GitHub Actions 同步 GitCode**：发行版仅发布到 GitHub，不再自动同步 GitCode Release，也不再推送 tag 到 GitCode

## [1.5.5] - 2026-08-30

### ✨ 新增
- **界面缩放选项**：显示设置可调节界面文字缩放（85%~130%，滑块+预设快捷），实时预览
- **重新加载界面按钮**：缩放等显示调整后可一键重建整个应用，立即生效

### 🐛 修复
- **Windows 字体发虚**：改用系统字体（Segoe UI / 微软雅黑回退），替换未预装的 Roboto
- **重新加载不生效**：改为重建整个 MaterialApp（含导航栈），确保所有页面刷新

## [1.5.4] - 2026-08-30

### ✨ 新增
- **更完善的英文界面**：主页 / 消息 / 站台 / 数据包 / 地图 / 设置 / OOBE 等页面补齐英文翻译，英文环境下所有界面完整显示

### 🐛 修复
- **移除更新签名提示**：签名已固定，检查更新页不再提示"签名已更换 · 需卸载重装"
- **GitCode 附件上传优化**：每个文件独立获取上传地址，加长超时（APK 30 分钟）并自动重试，失败不阻塞构建
- **GitCode tag 同步**：tag 构建自动推送 tag 到 GitCode，Release 关联对应 tag
- **手动同步工作流**：新增 GitHub Actions 手动触发同步发行包到 GitCode

## [1.5.3] - 2026-08-29

### ✨ 新增
- **连接页重构**：连接状态并入服务器卡片，Passcode 未验证时醒目标记 + 提示
- **GitHub Actions 签名一致**：CI 使用正式 release keystore 签名，与本地一致，覆盖安装不再报签名冲突
- **GitCode Releases 同步**：GitHub Actions 构建的发行包自动推送 GitCode 发行版
- **iOS 构建支持**：CI 新增 iOS 编译 job（无签名验证编译）

### 🐛 修复
- **英文界面地图类型菜单选项消失**：分组过滤改用实际值，标题本地化
- **群聊被邀请显示 0 成员**：创建群时自动加入群主与自己
- **过滤范围保存体验**：输入/预设只改输入框，点"保存并应用"统一生效

### 🎨 优化
- **状态标签**：在线改为 5 分钟超时离线，去除"紧急"标签，保留移动/静止
- **APRSlocus 分类**：同款台站划入与 FMO 同等分类层
- **去掉屏蔽功能**：移除群成员屏蔽操作
- **键盘卡顿**：主页/站台列表搜索加防抖，台站多时不卡

## [1.5.2] - 2026-08-29

### ✨ 新增
- **地图台站聚合**：自绘地图与矢量地图均支持，台站较多时按网格聚合成聚合球（显示数量，点击放大展开），显著降低渲染卡顿
- **聚合开关按钮**：地图控制栏新增聚合开关，可随时开启或关闭台站聚合
- **自身轨迹显示**：地图显示我的位置移动轨迹（蓝色轨迹线，最多 200 点）
- **过滤半径快捷预设**：50/100/200/500/1000/2000 km 一键选择，取消最大值限制
- **Passcode 错误提示**：服务器返回 unverified 时，主页显示黄色警告横幅"Passcode 未验证 · 去设置"
- **服务器连接检测优化**：解析 `# logresp` 验证登录；渐进式重连（8→16→32→60s）
- **iOS 构建支持**：GitHub Actions 新增 iOS 编译 job（macos-latest，无签名验证编译）

### 🐛 修复
- **安装提示降级**：versionCode 改为基于版本号单调递增（1.5.2=10502），彻底解决覆盖安装报降级
- **群聊被邀请显示 0 成员**：创建群时未初始化成员，被邀请群成员列表为空；现自动加入群主与自己
- **更新提示两个 v**：tag 解析统一去掉前导 v，不再显示 vv1.4.9
- **取消呼号规范识别**：移除 WIDE/TCPIP 等呼号格式过滤，全部台站正常显示
- **测试成员补充**：关于页新增 BD3QID
- **聚合开关不生效**：自绘地图聚合未受开关控制，现已统一受 `_clusterEnabled` 控制

### 🎨 优化
- **过滤保存统一**：经纬度/半径输入与预设只改输入框，点"保存并应用"统一生效（解决上下矛盾）
- **OOBE 精简**：移除呼号页底部提示小字

## [1.4.9] - 2026-08-29

### ✨ 新增
- **GitHub Actions 自动发版**：打 tag 自动构建 Windows 安装包 + Android APK，并发布 GitHub Release（备注自动从 CHANGELOG 提取）
- **Android release 签名**：配置 keystore 正式签名，覆盖安装签名一致
- **本地一键打包**：`tool/build_all.ps1` 自动同步版本 + 构建 APK/安装包 + Inno Setup 打包
- **更新渠道切换**：检查更新页支持在 GitCode / GitHub 之间切换更新源
- **GitHub 更新支持**：从 GitHub Releases 拉取版本并下载安装包
- **GPL-3.0 开源协议**：添加 LICENSE、README 徽章、关于页许可证声明
- **多语言支持**：完整国际化框架（flutter_localizations），支持中文/English/跟随系统
- **语言选择器**：显示设置 → 通用新增语言切换；OOBE 向导首步可选语言
- **接收呼号筛选（按国家/地区）**：OOBE 新增筛选步骤（默认中国），设置页可多选国家批量接收台站
- **本地台站过滤**：不再依赖 APRS-IS 服务器 `b/` 过滤，全部本地按国家前缀过滤
- **「其他台站」开关**：接收中继/气象/FMO/APRSlocus 等特殊类型台站
- **呼号格式校验**：过滤 WIDE/TCPIP/T2 节点等非台站标识与不规范呼号
- **重新运行设置向导**：高级设置 → 开发者模式新增入口
- **转发路径可视化**：站台详情独立区块，箭头串联各跳段，中继台可点击跳转
- **关于页 Hero 封面**：logobg 背景圆角卡片 + 柔和遮罩 + 中央 Logo
- **赞助与鸣谢独立页面**：SoftCard 简洁风格 + 微信赞赏码集成

### 🐛 修复
- **CI 构建失败**：GitHub Actions 上阿里云 maven 镜像返回 502；改为 CI 自动使用官方仓库，本地继续用镜像加速
- **kotlin 版本对齐**：kotlin 插件版本对齐到 2.2.21，匹配 Flutter 工具链
- **OOBE 呼号输入无效**：增加语言步骤后 switch case 错位导致呼号未正确校验/保存，已对齐步骤编号并增加呼号格式校验
- **台站多时卡顿**：`stationAllowed` 线性查找 O(n²) → 改为传对象 + 匹配缓存 O(n)；tile 动画按稳定 key 只播一次；通知节流提升至 250ms
- **INSTALL_FAILED_UPDATE_INCOMPATIBLE**：配置正式 release 签名解决
- **重启后皮肤不生效**：`_loadPrefs` 完成后立即应用保存的主题（深色/自定义色）
- **深色模式路由过渡闪白**：MaterialApp 补全 canvasColor/surface，SplashPage 改固定深色背景
- **台站列表不按筛选过滤**：历史缓存台站仍显示，改为本地实时过滤
- **特殊台站被误杀/无法归类台站误显**：中继/气象/FMO 台站保留，普通外国台站隐藏
- **空国家列表误放行全部台站**：改为空列表时不匹配任何国家，严格按勾选显示
- **T2CS 等中继节点被当作台站**：T2 系列/IGate 确认符不再可点击
- **首页上报倒计时不更新**：每秒 tick 触发重建，下次上报秒级实时刷新
- **黑夜模式不生效**：C 颜色改为运行时可变，深浅色切换即时刷新
- **CI 构建失败**：`sync_version.py` 在 GitHub Actions 上 `android/local.properties` 不存在时报错，改为存在才更新

### 🎨 优化
- **转发路径展示**：独立区块 + 箭头串联，中继橙色 chip、协议标识灰色，视觉协调
- **连接设置重构**：拆分为接收范围过滤 + 接收呼号筛选两个独立卡片

## [1.4.2] - 2026-08-29

### ✨ 新增
- **接收呼号筛选（按国家/地区）**：OOBE 新增筛选步骤（默认中国），设置页可多选国家批量接收台站
- **本地台站过滤**：不再依赖 APRS-IS 服务器 `b/` 过滤，全部本地按国家前缀过滤，台站列表/地图实时生效
- **「其他台站」开关**：接收中继/气象/FMO/APRSlocus 等特殊类型台站（即使不匹配所选国家）
- **呼号格式校验**：过滤 WIDE/TCPIP/T2 节点等非台站标识与不规范呼号
- **重新运行设置向导**：高级设置 → 开发者模式新增入口
- **转发路径可视化**：站台详情独立区块，箭头串联各跳段，中继台可点击跳转
- **关于页 Hero 封面**：logobg 背景圆角卡片 + 柔和遮罩 + 中央 Logo
- **赞助与鸣谢独立页面**：SoftCard 简洁风格 + 微信赞赏码集成

### 🐛 修复
- **台站列表不按筛选过滤**：历史缓存台站仍显示，改为本地实时过滤（默认只显示中国 B 开头）
- **特殊台站被误杀/无法归类台站误显**：中继/气象/FMO 台站保留，普通外国台站隐藏
- **空国家列表误放行全部台站**：改为空列表时不匹配任何国家，严格按勾选显示
- **T2CS 等中继节点被当作台站**：T2 系列/IGate 确认符不再可点击
- **首页上报倒计时不更新**：每秒 tick 触发重建，下次上报秒级实时刷新
- **黑夜模式不生效**：C 颜色改为运行时可变，深浅色切换即时刷新

### 🎨 优化
- **转发路径展示**：独立区块 + 箭头串联，中继橙色 chip、协议标识灰色，视觉协调
- **连接设置重构**：拆分为接收范围过滤 + 接收呼号筛选两个独立卡片

## [1.4.0] - 2026-08-29

### ✨ 新增
- **赞助与鸣谢独立页面**：关于页留入口，新增 Hero 横幅、统计卡片、徽章标注与赞助方式卡片
- **关于页 Hero 封面**：logobg 背景横幅 + 半透明遮罩 + 中央 Logo，横屏自动铺满
- **接收地区呼号偏好**：连接设置可添加/删除指定呼号，加入过滤规则（~ 精确匹配），自动持久化
- **保存并应用过滤按钮**：一键保存当前经纬度/半径并重连生效，带绿色确认反馈
- **黑夜模式支持**：`C` 颜色改为运行时可变，深色模式 + 自定义主题色立即生效

### 🐛 修复
- **receivePrefs 未持久化**：添加/删除接收偏好后重启丢失，现已随 persist 保存
- **黑夜模式不生效**：硬编码 const 颜色改为动态读取，深浅色切换即时刷新
- **首页上报倒计时不更新**：`_onStateChanged` 仅在跳转/选点变化时刷新，改为每秒 tick 触发重建，下次上报秒级实时刷新
- **台站列表不按筛选过滤**：国家筛选仅服务器端生效，历史缓存台站仍显示；新增本地过滤，台站列表/地图实时按所选国家显示
- **特殊呼号台站被误杀**：中继/气象/FMO/APRSlocus 台站不匹配国家前缀时被过滤；新增「其他台站」开关放行特殊类型台站

### 🎨 优化
- **半径保存交互**：过滤卡片增加醒目的「保存并应用过滤」青色按钮
- **赞助界面重做**：改为与全局一致的 SoftCard 简洁风格，去除非协调的渐变 hero 与统计卡
- **微信赞赏码**：集成 WechatPay 赞赏码缩略图，点击弹出大图
- **关于页 hero**：改为带外边距的圆角卡片，柔和遮罩 + 阴影，视觉更协调

## [1.3.9] - 2026-08-28

### ✨ 新增
- **高德 JS 地图**：WebView 承载高德 JS API 2.0，客户端矢量渲染，Key 已内置
- **通知栏退出按钮**：前台服务通知新增「退出」按钮，一键退出应用
- **OSL 彩蛋图片**：关于页点击 BG7OSL 显示袋鼠彩蛋
- **接收范围无上限**：过滤半径不再限制最大值（仅保留 ≥10km 下限）

### 🐛 修复
- **过滤范围不可修改**：onChanged 每次触发 refreshAprsFilter 导致反复重连，输入被重置；改为仅在显式操作时重连
- **过滤器控制器不同步**：filterFollow 模式下经纬度/半径值外部变化后 UI 不更新；添加 build 时同步控制器
- **群聊 ACK 标识**：群聊消息不再显示发送确认图标（done/done_all）
- **高德 JS 滚轮缩放**：WebView2 给页面的鼠标坐标恒为 0 导致中心偏移；改用 Flutter Listener 从 Flutter 层捕获精确坐标
- **地图类型回退**：Windows 上高德 JS 回退为高德瓦片（避免 WebView2 兼容问题）

## [1.3.5] - 2026-08-28

### ✨ 新增
- **矢量地图（地图 2.0）**：flutter_map 客户端实时矢量渲染，数据量小、缩放清晰，无需 API key
- **地图类型选择**：设置 → 显示新增地图类型选择（高德矢量/高德卫星/矢量/Carto/OSM）
- **系统通知**：群聊邀请、成员加入/离开等群事件推送系统通知
- **通知栏连接按钮**：前台服务通知新增「连接/断开服务器」按钮，后台直接切换 APRS-IS 连接
- **台站标记呼号**：矢量地图每个台站显示呼号标签

### 🐛 修复
- **台站数据丢失**：收包台站列表满员时误删收藏/手动台站，改为优先保留；收包台站定期持久化，重启不再丢失
- **筛选规则不生效**：修改过滤半径/经纬度/跟随位置后未重连服务器，现已自动重连生效
- **两步向导"下一步"不亮**：群发/建群输入框缺少刷新触发，输入后按钮仍灰色
- **地图焦点不跳转**：矢量地图未接收焦点参数，从台站列表/详情跳转无法定位
- **群管理移除失效**：移除/屏蔽成员后未正确持久化与刷新
- **群消息 ack 噪声**：群聊广播改用 no-ack 格式，避免成员自动回 ack 刷屏
- **地图选点不返回**：设置中「在地图选点」先关闭子页面再进入选点模式
- **关于页精简**：移除技术信息区块

### 🎨 优化
- **会话列表统一**：群聊与单聊合并为一个列表，群聊带橙色群图标与「群」标签
- **群发/建群两步向导**：先选人→再填内容 / 先填名称→再选成员，带步骤指示条
- **设置页重构**：拆分为电台/定位/连接/显示/聊天/数据/高级多个子页面，卡片等高对齐
- **联系人管理重做**：搜索、筛选、在线状态、确认删除、手动添加
- **矢量地图轨迹渲染**：台站移动轨迹以彩色折线显示
- **矢量地图加载优化**：style 进程级缓存，切换页面不再重复下载

## [1.2.7] - 2026-08-27

### ✨ 新增
- **检查更新**：设置页新增入口，自动获取 GitCode 仓库最新版本
- **版本对比**：智能比较本地与仓库版本，支持 `1.2.5.b` 字母后缀
- **更新日志**：已是最新时展示最新版本发布说明
- **按平台下载**：Android 下载 APK、Windows 下载 EXE，自动分流；某版本无当前平台安装包时自动提示
- **历史版本**：折叠列表展示全部历史版本，支持任意版本下载
- **历史版本下载进度**：每个版本独立显示实时进度条 + 百分比 + 已下载大小
- **安装引导**：Android 自动引导开启「安装未知来源」权限
- **Windows 运行安装**：下载完成可直接运行 EXE 安装程序

### 🐛 修复
- 版本比较逻辑：`1.2.5` 不再被误判为比 `1.2.5.b` 新
- 版本号显示不统一：所有页面统一引用单一变量源
- 已下载卡片版本显示：改为显示实际下载的版本号，而非写死最新版本

### 🎨 优化
- 检查更新页全新 UI：渐变版本卡片、状态图标、更新内容面板
- 下载完成支持「立即安装」/「运行安装程序」/「打开所在目录」
- 支持「重新下载安装包」，本地文件按版本号区分不覆盖
- 历史版本中当前版本自动标记「当前」，无安装包版本显示「无安装包」
