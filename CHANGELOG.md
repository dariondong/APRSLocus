# 更新日志

## [1.6.148] - 2026-09-21

### 🐛 修面板「拖动卡 + 一拖就变白」；连接按钮改成带动词文字 / Fixing sheet drag jank and the white flash; a clearer connect button

两条用户反馈，而第一条是我上一版「治卡」的手法自己造出来的另一半问题。

**一、拖动卡 + 莫名其妙变白：根因是「面板高度每帧在变」**

`BackdropFilter` 的代价与它的**几何**直接相关。上一版为了让展开动画不卡，做法是
动画/拖动期间**关掉模糊**——而关掉模糊就**必须**同时把填色换成不透明的白
（半透明不糊会直接透出地图，比卡更难看）。于是每次拖动面板都会从
「58% alpha 的磨砂」跳成「纯白」：用户看到的就是「一拖就变白」，而那两步其实是
同一处设计的两个面 —— 它把「卡」换成了「白」。

**正确的解法在几何，不在开关**：让面板**自身固定为最高档高度**，只裁出可视区。
这样模糊层的几何在拖动/动画中**完全不变**，叠加地图那侧的冻结（底图不变 →
模糊结果可复用），就能**一直开着模糊**：既不变白，也不再每帧重做整屏模糊。

因此把 `MaterialSurface(blurWhen:)` 这个开关**删掉**了，并在它的位置留一段说明：
**谁要用模糊，谁就得保证自己的几何是稳定的** —— 不留这个开关，就不会有人再走
「关模糊 + 换实白」这条回头路。

**二、连接按钮：状态与动作彻底分开**

上一版把未连接做成**实心蓝**圆钮，本意是「看成主操作」。但它同时被读成了状态灯：
**实心**在图形界面的惯例里意味着「已开启」，于是看到的正好相反（填满时反而是断开）；
而连上之后同一位置又变成「断开」，来回换含义。

现在：**状态只由左边的胶囊表达**（● 来源 · 已连接 / 未连接 / 只收不发）；
**按钮只表达「点了会发生什么」** —— 一律带动词文字（连接 / 断开连接）、一律淡底。
顺手把来源名改短（`APRS-IS` / `TNC` / `音频` / `PKWDWPL`）：设置页那套完整说法
放进胶囊会把顶部那一行撑爆。

---

**Two reports from users — and the first one was the other half of a problem my own previous
“fix for jank” created.**

**1) Sheet dragging stuttered and flashed white. The root cause is that the sheet's height changed
every frame.** A `BackdropFilter`'s cost is tied directly to its **geometry**. The previous release
avoided animation jank by turning the blur **off** while animating/dragging — and turning a blur off
*forces* you to switch the fill to opaque white (translucent-but-unblurred shows the map straight
through, which looks worse than stutter). So every drag jumped from “58% alpha frosted” to “pure
white”: that is the white flash, and the two reports are two faces of one design that traded jank
for whiteness.

**The fix belongs in the geometry, not in a switch**: the sheet now lays itself out at its **maximum
height** and merely clips to the visible area. The blur layer's geometry therefore never changes
while dragging, and combined with the frozen map behind it (unchanged backdrop ⇒ reusable blur
result) the blur can simply **stay on** — no white flash, and no full-screen blur recomputed every
frame.

So `MaterialSurface(blurWhen:)` was **removed**, replaced by a note in its place: **whoever wants a
blur owns keeping their geometry stable.** With no switch to reach for, nobody can take the
“disable blur, swap in solid white” road again.

**2) The connect button: state and action are now cleanly separated.** The previous release drew the
disconnected state as a **solid blue** round button, intending it to read as “the primary action”.
But it also read as a status light: in GUI convention **solid** means *on*, so it said the opposite
(filled = disconnected). And once connected, the same spot turned into “disconnect”, changing
meaning back and forth. Now **the pill on the left carries the state** (● source · connected /
not connected / receive-only) and **the button carries only what tapping does** — always a verb
(Connect / Disconnect), always a light fill. Source names were also shortened (`APRS-IS` / `TNC` /
`Audio` / `PKWDWPL`), because the settings-page wording would burst that row on narrow screens.

---

## [1.6.147] - 2026-09-21

### 🧹 按反馈撤掉接收侧那套「防抖」；修浮动面板展开卡顿；横屏改成一整块工作区 / Dropping the receiver-side debounce; fixing sheet-open jank; a single landscape workspace

三条都来自使用反馈。第一条是**我上一版做错了方向**，先认这个。

## 一、接收台站的「位置质量层」全部撤掉（v1.6.145 加的）

原话是「不要给别人加防抖，浪费」—— 这个判断是对的，而且**浪费是能算出数的**。
那一整套里真正占资源的不是"每包算一次"的判据，而是**绘制期**的东西：

* 轨迹平滑（`smoothForDraw`）：**每次重绘都重新分配整条列表**，每个点还要算 1~2 次
  haversine；地图一拖动/缩放就是每帧一次；
* 推测位置（`coastOf`）：**每秒对每个可见台站**算 sin/cos/atan（上限 120 个），
  而绝大多数台站是静止或离线 —— 算了完全用不上；
* 那一层还**每秒强制重绘**，而它就叠在磨砂面板的离屏模糊之上（见第二条）。

于是接收侧**整体回到朴素行为**：收到就更新，位移超过 20m 记一个轨迹点。
一并删掉的：报文指纹去重、位置时间戳判旧帧、速度门控、模糊位置的不确定圈、
自适应抽稀。`Station` 上的 `fixTime` / `ambiguity` 与它们的持久化也删了。

**保留的是「自己」那一侧**（每天看得见的东西，且成本可忽略）：静止防抖（站着不动时
标记不再原地哆嗦）、按速度自适应的轨迹抽稀、定位精度显示与精度圈。

以后想给接收侧再加回来，`tool/check_pos_quality.py` 会拦住 ——
它现在对接收侧那些调用是「**必须不存在**」的断言。要加，先回答「它能省下多少帧」。

## 二、面板一动，地图就**冻住**（不再渲染新帧）

按「触发其他面板之后地图不再渲染？固定？」这条建议做的 —— 它是这一轮里最有效的一条。

关键是分清两种「不画」：

* `isActive = false` → 整块地图换成 `SizedBox.shrink()`，**真的不画了**；
* `frozen = true` → **继续画**，但不再产出新的帧。

后者才是对的：面板开着做磨砂时，`BackdropFilter` 要把**背后已经画好的内容**
离屏重绘一遍 —— 地图一旦不画，模糊背后只剩页面底色，那不叫优化，那叫把磨砂弄坏。

冻结做了三件事：

* 停掉脉冲动画（`_pulse.repeat()` 是地图这边**唯一的每帧**重绘来源，它驱动所有
  移动台站的扩散圈逐帧重建）；
* **数据**变化不再重建标记（面板开着期间收到的新台站/新位置先攒着）；
* 传给地图的 `bottomInset` 改用**吸附目标值**而不是逐帧中间值 —— 否则每帧一个新
  inset，地图就每帧重排重绘一次，正好把上面两条抵消掉。

**视图变化仍然跟随**：拖地图、缩放、点台站都会立即重建标记。这条不能省 ——
否则在那个状态下拖地图，标记会僵在原地，比卡更难接受。解冻时再补一次重建
（`didUpdateWidget`），避免短暂显示冻结前的旧标记。

效果：地图内容在面板开着期间不变 → 它自己那层 `RepaintBoundary` 的光栅化结果被
Flutter 复用 → 面板的模糊从「每帧把整张地图重新光栅化」变成**采样一张缓存纹理**。

## 三、浮动面板展开卡顿：另外三条一起改


根因是**叠加**出来的，不是单一原因：

1. **展开动画每帧都在做整屏离屏模糊。** 面板壳里的 `BackdropFilter` 每帧都要把
   「背后已经画好的地图」离屏重绘一遍（`material.dart` 里早就写明了这笔账），而
   展开动画 260ms 里外壳每帧 `setState`、面板高度每帧在变 —— 于是动画的十几帧
   里每一帧都在对整张地图做一次全屏模糊。
   → 新增 `MaterialSurface(blurWhen:)`：**动画/手拖期间不做模糊**，同时换成不透明
   合成色（半透明但不糊会直接透出地图，比卡更难看）。动画结束再 `setState` 一次
   把磨砂恢复 —— 少了这一下，面板会一直停在「没有磨砂」，用户会以为材质坏了。
2. **展开动画每帧重建四个页面。** `_content()` 每次都新建 `IndexedStack` 与
   台站/消息/数据包/设置四页 → 动画每帧把它们全重建一遍。改成**缓存 widget 实例**，
   只有页签变化才失效；Flutter 见到同一实例会跳过这棵子树的 rebuild。
3. **少一层模糊**：横屏原来「竖条 + 面板」是两张独立卡（两层 `BackdropFilter`），
   见第三条 —— 现在是一张。

## 四、横屏：一整块工作区

原来横屏是两张**独立的**圆角卡：竖条是 `MainAxisSize.min`（只有内容高、贴顶），
内容面板却占满整高 —— 两块并排**高度不齐**，上沿都从安全区起、下沿一个到屏幕底
一个不到，看着就是「没收拾过」。

现在合并成**一张卡**：左竖条 + 细分隔 + 右内容。高度天然一致、间距只有一处，
而且少一层离屏模糊。选「地图」页（内容为空）时只留竖条卡并**垂直居中** ——
贴顶会显得像掉在上面。竖条也套了 `SingleChildScrollView`：极矮横屏（手机横放常
不足 400dp）下 5 个导航项会溢出成黄条纹。

## 五、顺带修掉一个「检查器自己的 bug」

`tool/check_material_coverage.py` 里 `return 1` 写在了打印**之前**，于是它一旦
发现真问题就**报红但不说哪里红**（后面那段打印是死代码）。一个不告诉你问题在哪的
检查比没有检查更费时间 —— 这轮它真报红时才发现，已修好并把顺序写进注释。

---

**All three items come from user feedback. The first one is me having gone the wrong way in
the previous release, so that comes first.**

**1) The receiver-side "position quality layer" (added in v1.6.145) is gone.** The feedback was
"don't add debounce for other people, it's a waste" — and that judgement is right, with the waste
being **quantifiable**. What actually cost resources was never the once-per-packet checks but the
**per-frame** work: track smoothing (`smoothForDraw`) **reallocated the entire list on every
repaint** and ran one or two haversines per point, i.e. once per frame while the map is being
dragged or zoomed; estimated position (`coastOf`) computed sin/cos/atan **for every visible
station every second** (up to 120), even though most stations are stationary or offline, so the
result was almost never used; and that layer also **forced a repaint every second**, right on top
of the sheet's backdrop blur (see item 2). The receiver side is therefore back to plain behaviour:
update on receipt, append a track point when the station moved more than 20m. Also removed: packet
fingerprint dedupe, position-timestamp staleness rejection, kinematic gating, ambiguity circles,
and adaptive decimation — along with `Station.fixTime` / `Station.ambiguity` and their
persistence. **What stays is the "my own position" side** (the part you see every day, at
negligible cost): stationary debounce, speed-adaptive track decimation, and the accuracy display
and accuracy ring. If anyone wants the receiver side back, `tool/check_pos_quality.py` will stop
them — those calls are now asserted to be **absent**. To add them back, first answer "how many
frames does it save".

**2) While a panel is open the map is frozen — it keeps painting, but stops producing new
frames.** This came from the suggestion "after triggering another panel, can the map stop
rendering? fixed?" and it turned out to be the most effective change of the round. The key is
telling two kinds of "not painting" apart: `isActive = false` replaces the whole map with
`SizedBox.shrink()` — it really stops painting; `frozen = true` **keeps painting** but stops
producing new frames. The latter is the correct one, because with frosted material the
`BackdropFilter` re-renders everything already painted behind it — if the map stops painting, the
blur has nothing but the page background behind it, which is not an optimisation, it is breaking
the frosted effect. Freezing does three things: it stops the pulse animation (`_pulse.repeat()` is
the map's **only** per-frame repaint source, driving the expanding rings on every moving station),
it stops rebuilding markers on **data** changes (new stations and positions received while a panel
is open simply accumulate), and it passes the map a `bottomInset` based on the **snap target**
instead of the per-frame intermediate value — otherwise every frame brings a new inset, the map
re-lays-out and repaints every frame, and the first two wins are cancelled out. **View changes are
still followed**: panning, zooming and tapping a station rebuild markers immediately, and this
cannot be dropped — without it, dragging the map in that state leaves the markers stuck, which is
worse than jank. A final rebuild on unfreeze (`didUpdateWidget`) avoids briefly showing the
pre-freeze markers. The effect: the map's content does not change while a panel is open, so the
rasterised result of its own `RepaintBoundary` is reused by Flutter, and the panel's blur goes from
"re-rasterise the whole map every frame" to **sampling a cached texture**.

**3) Sheet-open jank: the other three fixes, at once.**
 The root cause was additive. First, the open
animation was doing a full-screen offscreen blur **every frame** — the `BackdropFilter` in the
sheet shell re-renders everything already painted behind it each frame (`material.dart` has
always documented that cost), while the open animation setState-s every frame with a changing
height, so a dozen-plus frames each blurred the entire map. `MaterialSurface` now takes
`blurWhen:`: **no blur during animation or finger-dragging**, with an opaque blended fill in the
meantime (translucent-but-unblurred would show the map straight through, which looks worse than
jank); a final `setState` when the animation completes restores the frosted look — without it the
sheet would stay blur-less forever and users would think the material broke. Second, the animation
rebuilt all four pages every frame: `_content()` built a fresh `IndexedStack` with the stations,
messages, packets and settings pages on each call. The widget instance is now cached and only
invalidated when the tab changes, so Flutter skips that subtree entirely. Third, one fewer blur
layer: landscape used to be two separate cards (two `BackdropFilter`s), now one.

**4) Landscape: a single workspace.** Previously landscape had two **independent** rounded cards —
the rail was `MainAxisSize.min` (content-height only, pinned to the top) while the content pane
filled the full height, so the two sat side by side with **mismatched heights** and different
bottom edges. It is now **one card**: rail, hairline divider, content. Heights match by
construction, spacing lives in one place, and there is one less offscreen blur. On the map tab
(no content) only the rail card remains, **vertically centred** — pinned to the top it looked like
it had fallen there. The rail is also wrapped in a `SingleChildScrollView`, because at very short
landscape heights (phones rotated are often under 400dp) five nav items overflowed into the
yellow-and-black stripes.

**5) Also fixed a bug in one of the checkers themselves.** `tool/check_material_coverage.py` had
its `return 1` **before** the printing block, so whenever it actually found a problem it went red
**without saying where** (the reporting code was dead). A check that does not tell you where the
problem is costs more time than no check at all; this round's first real failure exposed it.
Fixed, with the ordering requirement written into the comment.

## [1.6.146] - 2026-09-21

### 📍 自己的定位加「静止防抖」：站着不动时，标记不再原地哆嗦 / Stationary debounce for your own GPS

上一版治的是「接收到的台站」，自己这一侧其实只有**粗筛**：精度超过 150m 的点丢掉、
网络点只在 GPS 停更 20 秒后才兜底、系统缓存位置只在还没定位时用。这些都是「不合格就
扔掉」，而**「合格但抖」的点从来没管过** —— 静止时 GPS 在 ±30m 内飘是常态，于是轨迹被
画成一小团毛线球，信标上报的坐标也跟着一起哆嗦（aprs.fi 上看自己的点会在原地跳）。

## 一、精度这个值，原生算了却没人读

Android 侧 `LocationService.kt` 一直在发 `"accuracy"`、iOS 侧 `LocationPlugin.swift`
一直在发 `horizontalAccuracy` —— 但 Dart 侧解析事件时**从来没读过**，回调签名里也没这个
参数，等于白算。现在接回并落库，这是三件事的前提：如实显示「±40 m」、太差的点不写轨迹、
给自己画不确定圈。**IP 定位现在如实标 50km（城市级）** —— 以前它和手机 GPS 点在界面上
长得一模一样，用户无从知道眼前这个点差了多远。

## 二、静止防抖：滑动窗口中位数 + 四个关键决定

算法是 `lib/pos_quality.dart` 里的 `SelfFixFilter`，参数**不是拍脑袋定的**，是用
`tool/sim_selffix.py` 的场景仿真跑出来的（脚本已进仓库，注释里的数字都能复现）：

| 场景 | 反向跳（稳态） | 跳变 >20m | 输出游走总长 |
|---|---|---|---|
| 静止 σ30m | 106 → **10** | 206 → **10** | 11691m → **2311m** |
| 静止 σ60m（弱信号） | — | 233 → **11** | 23382m → ~4000m |
| 静止 + 一次 200m 漂移 | 108 → **11** | 207 → **10** | 12103m → **2358m** |
| 步行 4.5km/h | 75 → **75** | 156 → **156** | 不变 |
| 开车 60km/h | 0 → **0** | 239 → **239** | 不变 |

四个决定，每个都是先写错、被仿真打回来才改对的：

* **判据用「窗口前后两半中位数之差」，不是「离当前点的最大距离」。** 第一版就是后者：
  5 个 σ=30m 的噪声点离当前点最远常到 60~90m，于是「进入静止」**永远不成立** ——
  仿真里静止场景 `still=0%`，两条曲线完全一样，**功能等于没上**。两半中位数之差才对
  噪声不敏感（各半中位数各有 ≈0.7σ 误差）、对真实位移敏感。
* **静止时取中位数，不是均值。** 均值会被一个漂出去很远的点拉偏，而「漂出去很远」恰好是
  GPS 最常见的失效模式（隧道口、出地库、多路径反射）。仿真里那个 200m 单点漂移，
  中位数完全不受影响。
* **进出都要时间滞回**：进入要连续 3 次成立、退出要连续 3 次不成立，但速度达到 5km/h
  （明显在动）**当帧退出**。只做阈值滞回不做时间滞回，阈值边缘就会反复切换，位置忽跳 ——
  那正是「反复横跳」。
* **输出死区 12m + 每帧限速 15m**：中位数没漂出 12m 就**完全不动**（挡住中位数自身的
  ±10m 游走，实测把稳态反向跳从 30 次降到 10 次），要动也每帧最多 15m。于是「进静止」
  「出静止」都不会有突兀一跳。

**移动时不做任何平滑**：移动中 GPS 本身准，平滑只会引入滞后（轨迹甩到弯道外侧）。
仿真里步行与开车场景的输出与未滤波**逐帧完全相同**，就是这条的证明 —— 这是「宁可不平滑，
也不要让位置追不上车」的取舍。已知局限也如实写进了类的注释：若设备上报的**速度不可信**
（在 0~4km/h 之间乱跳），滤波器基本不生效（still 仅 20%）—— 那种情况下输出与改动前一致，
至少不会变差。

## 三、自己的轨迹与展示

* **静止不写轨迹点**、精度差于 100m 不写、抽稀门限按速度自适应（原来固定 20m）——
  毛线球的三个来源逐个堵掉。
* 定位状态多一个「**静止**」（6 语言 + 白名单登记，非中文界面不会漏出中文）。
* 「我的位置」面板新增「位置精度 ±40 m」；地图上给自己画不确定圈（蓝虚线），
  与台站的模糊圈同一种画法。
* 修掉一个本版引入的 bug：`filterLng` 误写成原始经度，会让 APRS-IS 过滤中心拿
  「平滑纬度 + 未平滑经度」去算，两轴不同步。

## 四、还会不会「跳回初始点」？—— 又查出两条路，都封死了

顺着「谁还能把标记拉回旧点」把整条链路重走了一遍，剩下两条：

* **缓存位置（`getLastKnownLocation`）在原生服务重启后会再次放行。** 原生侧在服务
  运行期间确实会挡缓存点（Android 的 `hasLiveFix`），但**前台服务被系统回收、切回
  前台重连之后那个标记会归零**，于是它可能再放行一个几分钟前的缓存位置 —— 而上层
  照收就会把标记拉回旧位置，症状正是用户报过的「轨迹跳回初始点」。现在 Dart 侧自己
  记住「已经有过实时定位」，此后的缓存点**连标记都不再改**（只保证有东西可显示）。
* **跳变守卫的参照点原本是「上一个轨迹点」——这条是我这版改动引入的回归。**
  因为静止时不再写轨迹点了，`myTrack.last` 可能已经是几小时前的点，于是
  `gapSec` 必然超窗、**守卫整个失效**；而 `myTrack` 为空时（刚启动、清空数据后、
  刚确认过一次跳变）原本完全没有守卫。参照点改成「**上一次被接受的实时定位**」，
  这两处一起解决 —— 顺带 `myTrack.clear()` 现在只在确认跳变时发生。

顺手补上：`clearAllData()` 以前不清自己的轨迹（`myTrack` 不在 `stations` 里），
点「清空数据」后地图上仍残留一条自己的线；现在一并清掉并复位定位状态。

## 五、绘制开销：不确定圈改成「算一次、缩放复用」

三层虚线圈都是新加的，顺手把它做便宜了。要点是**硬件加速不等于免费**：

* Android（`hardwareAccelerated="true"`，Impeller/Skia 走 GPU）、iOS（Metal）、
  Windows（ANGLE → D3D11）确实是 GPU 绘制 —— 但这只说明 `drawPath` 由 GPU 光栅化，
  **虚线本身是 CPU 算的**：Skia / Impeller 都不在 GPU 上做路径虚线。
* 原来的写法是「每个圈每帧跑 `Path.computeMetrics()` + `extractPath()` 逐段切」：
  半径 100px 的圈 ≈ 57 段、500px ≈ 285 段，而圈数上限 120 → 最坏一帧约 **6800 次**
  切段 + 绘制。而 `maxStations` 默认是**无上限**的，这个上限真的会被撞到。
* 现在改成预先只构造一个「单位虚线圆」（半径 1、48 段），画的时候 `canvas.scale(r)`
  复用（线宽除以 r 抵消缩放）—— 每个圈只剩 **1 次** `drawPath`，
  **与半径无关**，也不再有任何逐帧路径计算。
* 另外两条：接近整屏的圈（> 1.5 倍屏幕长边）直接不画（没有信息量却要光栅化一大片）；
  这一层套 `RepaintBoundary` 隔离，它每秒重绘一次时不会连累瓦片与其它浮层。

## 六、两条新增的 CI 检查（本机跑不了 analyze，只能靠它们）

* `tool/sim_selffix.py --check`：既是仿真也是回归 —— 校验 Dart 常量与仿真**逐项一致**
  （两处漂移就等于在验证另一个算法），并断言「静止不许反复横跳 / 单点漂移不许漏出去 /
  **步行开车不许被平滑**」。
* `tool/check_pos_quality.py` 增加五条断言：accuracy 是否真的从原生接回来、
  `locStatus` 的每个状态串是否都在白名单里登记过（漏登记会让英文界面漏出中文）、
  缓存位置闸门与「守卫参照点不是 myTrack.last」这两条不许回退、以及
  `clearAllData()` 必须清 myTrack。

回归样本都验证过**会报红**，其中两条正是上面这两条路径被改回去 ——
另外一条是「keep 阈值落在步行区间 → 走路被粘住」。

---

**The previous release fixed received stations; your own position only had coarse filters
(drop fixes worse than 150m, fall back to network only after GPS goes quiet for 20s, use the
cached last-known fix only before the first fix). Those are all "throw it away if it is bad" —
and a fix that is **good but noisy was never handled at all**. A stationary GPS wanders within
±30m as a matter of course, so the track was drawn as a little ball of wool and the beacon
coordinates jittered along with it (your own dot visibly hops around on aprs.fi).**

**1) The accuracy value was computed and then never read.** Android's `LocationService.kt` has
always sent `"accuracy"`, and iOS's `LocationPlugin.swift` has always sent `horizontalAccuracy`
— but the Dart side never parsed it and the callback signature had no such parameter. It is now
plumbed through and stored, which is the prerequisite for three things: showing "±40 m"
truthfully, refusing to write very poor fixes into the track, and drawing an uncertainty circle
around yourself. **IP geolocation is now honestly labelled 50km (city-level)** — previously it
looked exactly like a phone GPS fix, leaving users no way to tell how far off the dot was.

**2) Stationary debounce: a sliding-window median with four key decisions.** The algorithm is
`SelfFixFilter` in `lib/pos_quality.dart`, and its parameters are **not guesses** — they come
from scenario simulations in `tool/sim_selffix.py`, which is committed so every number in the
comments is reproducible:

| Scenario | Reversals (steady) | Jumps >20m | Output wandering |
|---|---|---|---|
| Stationary, σ30m | 106 → **10** | 206 → **10** | 11691m → **2311m** |
| Stationary, σ60m (weak signal) | — | 233 → **11** | 23382m → ~4000m |
| Stationary + one 200m outlier | 108 → **11** | 207 → **10** | 12103m → **2358m** |
| Walking, 4.5 km/h | 75 → **75** | 156 → **156** | unchanged |
| Driving, 60 km/h | 0 → **0** | 239 → **239** | unchanged |

Four decisions, each of which was wrong first and corrected after the simulation pushed back:

* **The criterion is the distance between the medians of the window's two halves, not the
  maximum distance from the current point.** The first version used the latter: five samples at
  σ=30m are routinely 60–90m from the current point, so "entering the stationary state" **never
  happened at all** — the simulation showed `still=0%`, the two curves were identical, and the
  feature was effectively not shipped. The half-to-half median distance is insensitive to noise
  (each half's median carries ~0.7σ of error) yet sensitive to real movement.
* **Stationary output is a median, not a mean.** A mean is dragged by one far-away sample, and
  "far away" is exactly how GPS most often fails (tunnel mouths, leaving a garage, multipath).
  In the simulation the single 200m outlier leaves the median completely undisturbed.
* **Time hysteresis in both directions**: three consecutive good samples to enter, three
  consecutive bad ones to leave — but a speed of 5 km/h (clearly moving) exits **on that frame**.
  Threshold hysteresis without time hysteresis makes the state flap at the boundary, and each
  flap moves the position; that *is* the "jumping back and forth" failure mode.
* **A 12m output deadband plus a 15m-per-frame slew limit**: if the median has not drifted beyond
  12m the output **does not move at all** (this suppresses the median's own ±10m wander and took
  steady-state reversals from 30 down to 10); when it does move, it moves at most 15m per frame.
  Neither entering nor leaving the stationary state produces a visible jump.

**No smoothing whatsoever while moving.** GPS is accurate when you are moving; smoothing there
only adds lag and swings the track onto the outside of corners. In the simulation the walking and
driving outputs are **frame-for-frame identical** to the unfiltered ones, which is the proof. It
is a deliberate trade: better to skip smoothing than to have the position unable to keep up with
the car. The known limitation is written into the class documentation as well: if a device
reports an **unreliable speed** (jumping around between 0 and 4 km/h), the filter largely does
not engage (still only 20%) — and in that case the output is identical to before, so it is never
worse.

**3) Your own track and its presentation.** Stationary fixes, fixes worse than 100m, and the
adaptive decimation threshold (formerly a fixed 20m) — the three sources of the ball of wool, each
plugged. A new "**stationary**" location status (in all six languages and registered in the
whitelist, so non-Chinese interfaces never leak Chinese). The "my location" panel now shows the
accuracy as "±40 m", and an uncertainty circle is drawn around your own dot on the map, in the
same style as the ambiguity circles for other stations. Also fixed a bug introduced in this
release: `filterLng` was assigned the raw, unsmoothed longitude, which made the APRS-IS filter
centre combine a smoothed latitude with an unsmoothed longitude.

**4) Can it still jump back to the initial point? Two more paths were found, both now
closed.** Walking the chain again asking "what can still drag the marker back to an old
position" turned up two:

* **The cached location (`getLastKnownLocation`) can be released again after a native service
  restart.** The native side does suppress cached fixes while the service runs (Android's
  `hasLiveFix`), but **that flag resets when the foreground service is reclaimed and reconnects**,
  so a cached position from a few minutes ago can be emitted again — and accepting it drags the
  marker back to the old position, which is exactly the "track jumps back to the initial point"
  symptom users reported. The Dart side now remembers that it has already had a live fix, and
  cached fixes after that **do not even move the marker** (they only guarantee something is
  displayed).
* **The jump guard's reference point used to be "the previous track point" — a regression
  introduced by this very release.** Since stationary fixes are no longer written to the track,
  `myTrack.last` can be hours old, so `gapSec` always exceeds the window and **the guard stops
  working entirely**; and when `myTrack` is empty (just started, after clearing data, right after
  a confirmed jump) there was no guard at all. The reference is now "**the last accepted live
  fix**", which fixes both cases at once.

Also fixed along the way: `clearAllData()` never cleared your own track (`myTrack` is not inside
`stations`), so a line of your own survived "clear all data"; it is now cleared along with the
location state.

**5) Drawing cost: the uncertainty rings now compute once and scale.** All three dashed-ring
overlays were new, so they were made cheap while we were there. The point is that **hardware
acceleration does not mean free**: Android (`hardwareAccelerated="true"`, with Impeller/Skia on
the GPU), iOS (Metal) and Windows (ANGLE → D3D11) do render on the GPU — but that only means
`drawPath` is rasterised by the GPU. **The dashes themselves are computed on the CPU**: neither
Skia nor Impeller dashes paths on the GPU. The original code ran `Path.computeMetrics()` plus
`extractPath()` per ring per frame — about 57 segments for a 100px ring and 285 for a 500px one,
with a 120-ring cap, so up to roughly **6800** segment-and-draw calls in the worst frame; and
`maxStations` is unlimited by default, so that cap really can be reached. Now a single
"unit dashed circle" (radius 1, 48 segments) is built once and reused via `canvas.scale(r)` (with
the stroke width divided by `r` to cancel the scale), leaving **one** `drawPath` per ring,
independent of radius, with no per-frame path work at all. Two more: rings approaching the size of
the screen (beyond 1.5× its longest side) are skipped entirely, since they carry no information
while forcing a large rasterisation; and the layer is wrapped in a `RepaintBoundary` so its
once-a-second repaint does not drag the tiles and other overlays into re-rasterising.

**6) Two new CI checks** (this machine cannot run analyze, so these are the only safety net):
`tool/sim_selffix.py --check` is both simulation and regression — it verifies that the Dart
constants match the simulation **term by term** (any drift means the simulation is validating a
different algorithm), and asserts that stationary output never jumps around, that a single-point
outlier never leaks out, and that **walking and driving are never smoothed**. `check_pos_quality.py`
gained five assertions: that accuracy is really plumbed back from the native side, that every
`locStatus` string is registered in the whitelist, that the cached-location gate and the "guard
reference is not myTrack.last" invariant cannot regress, and that `clearAllData()` clears `myTrack`.
Every regression sample was verified to go **red** — two of them are exactly the two paths above
being reverted, and another is "the keep threshold landed inside the walking range, so walking got
stuck".

## [1.6.145] - 2026-09-21

### 🎯 「打点算法」重做：旧帧、重复帧、错包与模糊位置都不再骗人 / A rebuilt position-quality layer for plotting stations

台站位置有三个来源（APRS-IS / TNC / 音频解码），共用同一条解析管线；而同一帧还会经多条
路径重复到达。在此之前 `_upsertStation` 是「收到就覆盖坐标、位移超过 20m 就记一笔」，
于是地图上会出现四类假东西。这一版加了 `lib/pos_quality.dart`（打点质量层）逐条处理，
并且**把不确定度如实画出来**—— 一个诚实标着 ±13km 的点，比一个假装精确的点有用得多。

## 一、迟到的旧帧 / 重复帧：不再回拉、不再重复打点

* **位置包的时间戳以前解析出来就丢掉了**，这是最直接的漏。APRS-IS 不保证有序，一个
  几十秒前、几百米外的旧帧会把台站「拉回去」，轨迹上出现折返。现在 `/`、`@` 包的
  7 字符时间戳（`DDHHMMz` / `HHMMSSh` / `DDHHMM/`，一律归一到 UTC）真正参与判断：
  比已知位置旧 60 秒以上的帧**不覆盖位置、不追加轨迹**，只刷新「听到」。发送方时钟
  超前 2 小时以上时忽略该时间戳（免得因为对方时钟错就整条丢掉）。
* **同一帧的往返重复**：同时开着 APRS-IS 与射频、或经多个 iGate 时，同一帧会到两次。
  现在按「呼号 + 正文」指纹去重（**不含转发路径** —— 两条副本只有路径不同），
  20 秒窗口内只刷新「听到」，不打点也不记轨迹。

## 二、错包：不再画出横跨城市的假线

以前只有「自己」的位置有跳变守卫，接收到的台站没有 —— 一个错包就能让台站瞬移几十公里，
轨迹上留一条假线。现在每个台站都有**速度门控**：

* 按 APRS 符号估一个这类台站不可能超过的地速（飞机/卫星 2000、步行 15、默认 250 km/h），
  用「距离 > 速度 × 时间 × 1.5 + 500m」判定物理上不可能；
* 单点可疑**只保留旧位置**（不动标记、不记轨迹，只刷新「听到」），**连续 3 次都物理
  不可能**才认账 —— 认账后清空轨迹从新位置重画，而不是画一条横跨两地的假线；
* 为什么不能一次就否决：**真实的飞机 / ISS 每一帧都「物理不可能」**，一次否决会把它们
  永久冻在地图角落。ISS 这类呼号直接豁免，报文自带速度时也会放宽上限。

## 三、模糊位置：不再假装精确

`posAmbiguity`（模糊位数）以前解析出来**全项目没有一处使用**。可它意味着真实误差是
±0.13km / ±1.3km / ±13km / ±78km（对应 1′ / 10′ / 1° 的方格）。这些点以前被画得和精确点
一模一样 ——「看着很准，其实差几十公里」，这是最伤专业用户信任的一种错。

现在地图上按方格半对角画**不确定圈**（虚线），台站详情页多一行「位置精度」，
写明 `±1.3 km（模糊 2 位）`。

## 四、轨迹：抽稀按速度自适应、绘制前限幅平滑

* 抽稀门限从「固定 20m」改成按速度自适应：步行 15m（下限，低于 GPS 噪声没有意义）、
  汽车约 60m、飞机封顶 250m。固定值在步行时太粗、在高速时又太细（抖动被画成锯齿）。
* 绘制前做一次三点加权平滑，但**每个点最多挪 25m** —— 抖动能抹掉，真实急弯抹不动。
  瓦片地图与矢量地图走同一条平滑路径，两种底图不会长得不一样。

## 五、推测位置：安静下来的移动台站，外推「现在大概在哪」

移动台站安静 60 秒以上后，按最后的速度/航向外推位置：地图上画虚线鬼影 + 随时间扩大的
不确定圈，详情页给出「± 不确定度 · x 分钟前最后定位」。只对**仍算在线**的台站外推 ——
给一个已经离线的台站画推测位置只会更误导。这一层跟着地图的「轨迹」开关一起显示。

## 六、顺带：两条本机查不了、只能进 CI 的检查

* `tool/check_l10n_sync.py`：arb（真源）↔ 提交进 git 的 gen-l10n 产物。CI 会按 arb
  重新生成产物，于是「产物没 regen」会被掩盖 —— 但本机开发时会报 undefined_getter，
  也就是「我这儿有错、CI 却是绿的」，最耗人。这条按未生成产物的视角校验。
* `tool/check_pos_quality.py`：打点质量层的**接线**检查。算法写好了但忘了在某条路径上
  调用，编译与 analyze 都不会报错，功能只是悄悄不生效 —— 这条把「哪个文件必须调用哪个
  入口」变成断言，含「固定 20m 门限不许回来」这条回归守卫。

两条检查都按「必须会报红」的规矩用回归样本验证过。

---

**Station positions arrive from three sources (APRS-IS, TNC, decoded audio) through one shared
pipeline, and the same frame often arrives over several paths. `_upsertStation` used to just
overwrite the coordinates and append a track point whenever the station moved more than 20m —
which put four kinds of fiction on the map. This release adds `lib/pos_quality.dart`, a position
quality layer that handles each of them and **draws the uncertainty honestly**: a point labelled
±13km is far more useful than one pretending to be exact.**

**1) Late and duplicate frames.** The position packet's timestamp was parsed and then thrown away.
APRS-IS does not guarantee ordering, so a frame from a minute ago, a few hundred metres away, could
drag a station backwards and leave a fold in its track. The 7-character timestamps of `/` and `@`
packets (`DDHHMMz` / `HHMMSSh` / `DDHHMM/`, normalised to UTC) now take part in the decision: a
frame more than 60 seconds older than the known fix does not move the station and does not append
to the track — it only refreshes "last heard". Timestamps more than two hours in the future are
ignored so a sender's broken clock does not throw the whole packet away. Duplicates — the same
frame seen via APRS-IS and RF, or via several iGates — are dropped by a callsign+payload
fingerprint that deliberately excludes the digipeater path, since that is the only part that
differs between copies.

**2) Bad packets no longer draw lines across the country.** Only your own position had a jump
guard; received stations had none, so a single corrupt packet could teleport a station tens of
kilometres and leave a fake line. Every station now has kinematic gating: a plausible top ground
speed chosen from its APRS symbol (2000 km/h for aircraft and satellites, 15 for pedestrians, 250
by default), with "distance > speed × time × 1.5 + 500m" as the impossibility test. A single
suspicious fix only keeps the old position (marker untouched, no track point, "last heard" still
refreshed); three consecutive impossible fixes are accepted, and the track is then cleared and
redrawn from the new position rather than connected across the gap. The reason not to reject on
the first strike: a real aircraft or the ISS looks "physically impossible" on every single frame,
and one-strike rejection would freeze them in a corner of the map forever. ISS callsigns are
exempt outright, and a declared speed relaxes the limit.

**3) Ambiguous positions stop pretending to be exact.** `posAmbiguity` was parsed but never used
anywhere. It means a real error of ±0.13km / ±1.3km / ±13km / ±78km (a 1′ / 10′ / 1° cell), yet
those points were drawn exactly like precise ones. The map now draws a dashed uncertainty circle
at the cell's half-diagonal, and the station detail page gained a "position accuracy" row reading
e.g. `±1.3 km (ambiguous to 2 digits)`.

**4) Tracks: speed-adaptive decimation and capped smoothing.** The decimation threshold is no
longer a fixed 20m — it scales with speed (15m floor, ~60m for a car, 250m cap for an aircraft),
because a fixed value is too coarse when walking and too fine at speed (jitter becomes a saw
tooth). Before drawing, a 1-2-1 weighted average is applied, but **each point may move at most
25m**: jitter is erased, real corners are not. Tile and vector maps share the same smoothed path
so they never look different.

**5) Estimated position.** Once a moving station has been quiet for 60 seconds, its last
speed/course is used to extrapolate where it probably is now: a dashed ghost marker with a growing
uncertainty circle on the map, and an "± uncertainty · last fix x minutes ago" row in the detail
page. Only stations still considered online are extrapolated — guessing for one that is known
offline is simply more misleading. This layer follows the map's existing track toggle.

**6) Two new CI-only checks.** `tool/check_l10n_sync.py` verifies the ARB files against the
committed gen-l10n output: CI regenerates that output from the ARB, which hides a stale copy, but
a local build then fails with undefined_getter — "my machine shows an error while CI is green",
the most expensive kind of mismatch. `tool/check_pos_quality.py` verifies the wiring of the quality
layer: an algorithm that compiles but is never called fails silently, so "which file must call
which entry point" is now an assertion, including a regression guard that the fixed 20m threshold
cannot come back. Both checks were verified to go red using regression samples.

## [1.6.144] - 2026-09-21

### ✨ 「满血磨砂玻璃」档；2.0 横屏改左侧竖条；修下拉/返回手势冲突 / A "full" frosted-glass tier; a new landscape layout; gesture fixes

四件用户反馈。其中两件是我上一版引入的 bug，先列出来。

## 一、修「消息页往下拉，面板就缩下去」（我上一版引入的）

消息页的会话/聊天列表是 `reverse: true`（最新消息在底部，往上滑看历史）。在反向列表里
用户「往下拉」是朝**最新消息**方向，却被我的 `OverscrollNotification` 监听当成了
「滚到顶还想再拉」→ 收面板。

现在加**方向门控**：只有正向竖向列表（`AxisDirection.down`）才允许「滚到顶继续下拉 →
收面板」；反向列表（消息页）与横向列表（筛选芯片那一行）一律不参与。

## 二、修「从会话详情按返回，一下跑到地图去了」（我上一版引入的）

根因是 Flutter 的语义：`ModalRoute.popDisposition` **遍历**所有 PopScope，只要有一个
`canPop == false` 就整体不弹；而 `onPopInvokedWithResult` 是对**每一个**逐个调用 ——
**同一个 route 上的多个 PopScope 回调会全部触发，没有优先级**。外壳（返回→回地图）与
消息页（返回→回会话列表）各有一个，于是两者同时发生，后者把前者盖掉。

新增 `lib/back_router.dart`：内层页面在需要接手返回时**登记意愿**，外壳先问一句，
有人接手就不插手。用登记而不是「让外壳去猜内层状态」——内层最清楚自己拦不拦，
外壳去推演（哪个 tab、窄屏还是宽屏、是否在详情里）必然漏一种。

顺带修正：给消息页传的 `isActive` 原先写死 `true`，而它是「页面是否在前台」的语义
（同时决定是否拦返回、以及「正在看的会话」要不要算未读）；写死 true 会让消息页在
别的页签上也拦返回。

## 三、「满血磨砂玻璃」——小浮层也有磨砂

原因很具体：原来的**磨砂玻璃**档给工具钮、图例这类**小浮层**只上 **12** 的轻磨砂
（半径给大反而会把 38px 的边缘糊成一团灰），所以小东西看着像「没开材质」。

新增第四档：透明度 **0.42**（最透）、模糊 **40**（最强），而且**小浮层用与大面板
同一档的强模糊**。代价照实说：这一档**不省显卡**（每个小浮层都按大半径重绘一次
离屏）—— 是明确要的重观感，所以做成**独立一档**，没有改掉原来的玻璃档。

## 四、2.0 横屏：左侧「导航竖条 + 内容面板」

横屏的**高度**很小（手机横放常不足 400dp），底部面板一展开就吃掉大半高度、地图基本
看不见——而这一版的前提是「地图是底」。所以横屏把导航与内容一起挪到**左侧**：宽绰的
那一维给内容，地图占满右侧，互不遮挡。

* 导航竖条与底部导航**同一个数据源、同一套选中色**，只是排成竖的。
* 内容面板宽 = min(屏宽 40%, 屏宽 − 竖条 − 260)，夹在 300~560，保证地图不被挤没。
* 横屏**刻意不做拖拽**：竖向空间本来就紧，拉高拉低没意义；点导航切换、选「地图」收起。
* 地图在横屏仍是**全尺寸**绘制（不是被压扁的窄条），只是左侧被面板遮住一部分。

---

**Four items of feedback; two of them are regressions I introduced in the previous release, so
those come first.**

**1) Fixed: pulling down on the messages page collapsed the sheet.** The conversation/chat
lists there are `reverse: true` (newest at the bottom, swipe up for history). In a reversed list,
pulling *down* moves toward the newest message — but my `OverscrollNotification` listener read it
as “already at the top and still pulling”, and collapsed the sheet. There is now an **axis
gate**: only a forward vertical list (`AxisDirection.down`) may collapse the sheet by
over-scrolling; reversed and horizontal lists never do.

**2) Fixed: pressing back from a chat jumped to the map.** This is Flutter's semantics, not a
guess: `ModalRoute.popDisposition` **iterates** every registered `PopScope` (any one with
`canPop == false` makes the whole route refuse to pop), while `onPopInvokedWithResult` is called
on **each** of them — so **multiple PopScopes on one route all fire, with no priority**. The shell
(back → map) and the messages page (back → conversation list) each had one, so both happened and
the latter overwrote the former. A shared `lib/back_router.dart` now lets an inner page *register*
that it wants the back gesture; the shell asks first and stands down if someone claims it.
Registering beats the shell trying to infer the inner state — the inner page is the only one that
knows, and any inference (which tab, narrow or wide, in a detail view or not) will miss a case.

**3) A “full frosted glass” tier, so small overlays are frosted too.** The reason small widgets
looked unfrosted is specific: the existing frosted-glass tier blurs small overlays (map tool
buttons, legend, hint pills) by only **12** — a large radius would smear a 38px button's edges to
grey. The new fourth tier uses opacity **0.42** and blur **40**, and gives small overlays the
**same strong blur as large panels**. Stated plainly: this tier does **not** save GPU time (every
small overlay is redrawn offscreen at a large radius). It is a separate tier rather than a change
to the existing one, precisely because that cost is a deliberate choice.

**4) A landscape layout for 2.0: side rail plus a left panel.** Landscape height is small (often
under 400dp), so a bottom sheet eats most of the map — and the premise of this design is that the
map is the base. So in landscape the navigation and content move to the **left**: the generous
dimension holds content, the map fills the right, and they no longer overlap. The side rail shares
the bottom navigation's data source and accent colours, just stacked vertically; the panel width is
`min(40% of width, width − rail − 260)` clamped to 300–560 so the map is never squeezed out;
landscape deliberately has **no dragging**; and the map is still drawn at **full size** (not a
squashed strip) with only its left part covered by the panel.

---

## [1.6.143] - 2026-09-21

### ✨ 小按钮恢复磨砂；连接提示重做；面板把手加大且「整页都能拖」 / Frosted small buttons restored; a clearer connection indicator; a bigger grab handle and full-page dragging

三件用户反馈。另外顺手修了一个一直存在的布局 bug。

## 一、小按钮恢复磨砂（轻档）

上一版为性能把小组件的磨砂关掉了，这次加回来 —— 但不是简单回退，而是做成**两档材质**：

| 档 | 元素 | 半径 | 填色 |
|---|---|---|---|
| 小浮层 | 工具钮 / 图例 / 提示胶囊 / 信标横杠 / 顶栏那一簇 | **12** | 半透明 0.72 |
| 大面板 | 底面板 / 侧栏 / 顶栏 / 导航胶囊 / AppBar | 材质默认（玻璃 24 / 云母 16） | 半透明 |

小浮层给 12 而不是默认半径：它们**面积本来就小**（38px 按钮 1.4k px²，底部面板 196k），
代价低；但半径给大反而把边缘糊成一团灰、像没画好。真正的性能问题不是半径，
而是**同时存在的层数**与**重建频率**——那条已在上一版修掉。

## 二、连接提示重做（原来确实不明确）

原胶囊显示「37 在线」—— 那是**台站数**，不是连接状态；而台站数在地图信息条里
已经显示了。最糟的是「离线」这个词：`connected` 的真实含义是**发射链路可用**，
与「有没有台站在线」完全是两件事，同一个词同时暗示两件事。

现在如实拆开成 **来源 · 状态**：`APRS-IS · 已连接`（绿）/ `TNC · 未连接`（灰）/
**`PKWDWPL · 只收不发`（青）**。最后那一档单列：只启用只读来源时「没有发射链路」
是正常的，画成「未连接」会让人白去点连接、白去查设置。点一下进连接设置
（原来只有 tooltip 提示，而 tooltip 在手机上根本看不到）；tooltip 里还给出
**具体连到哪儿**（服务器地址 / 设备名 / 采样率）。连接按钮也改成**未连接时实心蓝**
（主操作的样子），已连接仍是红色（断开语义）。

## 三、把手加大到 44px，并让「整页都能拖」

- **把手**：触摸区 22px → **44px**（药丸本身仍是 40×5）。22 是用户抱怨「很难活动」的直接原因。
- **整页拖动**：不能靠给内容加手势 —— Flutter 的手势竞技场里内层 `Scrollable`
  总是赢。所以换两条路：**内容滚到顶后继续下拉**（监听 `OverscrollNotification`）
  即可收起面板；**内容不可滚动时**外层手势接管，整页上下拖都成立。另外**底部导航条
  也能拖**（它紧贴面板下方、又高又宽，竖直拖动原本什么都不做）。
- **诚实的边界**：内容可滚动且已在中间时，向上拖仍然是滚动列表（与系统底部面板一致）。

## 四、顺手修一个一直存在的布局 bug

内容原来按**当前的**面板高度布局，而可视区只有「面板 − 把手高」：底部被裁掉
**一整个把手的高度**，而且因为滚动视图自身就那么高，那一条**永远滚不到**；
拖动时高度每帧都在变 → **内容逐帧重新布局**（正是这套设计要避免的事）。
现在固定按「展开到最大时的可视高度」布局：拖动期间不重排，展开到最大时不裁。

---

**Three pieces of feedback, plus one long-standing layout bug fixed along the way.**

**1) Frosted small buttons are back — as a lighter tier.** The previous release turned frosting
off for small widgets to save GPU time; that is reverted, but not as a plain rollback — there are
now two tiers: small overlays (map tool buttons, legend, hint pills, beacon bar, the top-right
cluster) get a **12px** radius with 0.72 opacity; large panels (bottom sheet, side rail, top bar,
navigation pill, app bars) keep the material default (glass 24 / mica 16). Small overlays keep 12
because they are *small* — a 38px button is 1.4k px² against a 196k px² panel — so they are cheap,
while a large radius would smear their edges into grey mush. The real cost was never the radius but
the **number of simultaneously live layers** and **rebuild frequency**, both addressed previously.

**2) The connection indicator was genuinely unclear.** It used to read “37 在线” — that is the
**station count**, not the connection state (and the map’s info chip already shows it). Worse was
the word “offline”: `connected` actually means **the transmit link is up**, which is a different
question from “are any stations being heard”, and one word implying both leaves the user unable to
tell which problem they have. It now reads **source · state** — `APRS-IS · Connected`,
`TNC · Not connected`, and **`PKWDWPL · Receive-only`** as its own state (having no transmit link
is normal for a read-only source; calling it “not connected” sends people hunting for a problem
that does not exist). Tapping opens connection settings, and the tooltip names what it is actually
connected to — server address, device name, or sample rate. The connect button is now **solid blue
when disconnected** (it looks like the primary action it is) and red when connected.

**3) The grab handle is 44px and the whole page drags.** The handle's touch target went 22px →
**44px** (the pill itself stays 40×5). Full-page dragging cannot be done by wrapping the content in
a gesture — in Flutter's gesture arena the inner `Scrollable` always wins — so it takes two routes:
**pull down past the top of the content** (`OverscrollNotification`) collapses the sheet, and when
the content **cannot scroll** the outer gesture takes over so the whole page drags. The bottom
navigation bar drags too (it sits right under the sheet, is large, and previously did nothing in
that direction). **Stated plainly**: when the content *can* scroll and is mid-list, dragging up
still scrolls the list — same as every system bottom sheet.

**4) A long-standing layout bug.** The content was laid out at the *current* sheet height while its
viewport was that height minus the handle: the bottom strip was cut off by a full handle height and
could never be scrolled to, and every drag frame re-laid out the content (exactly what the
fixed-height/clip-only design exists to avoid). It is now laid out at the maximum expanded viewport
height: no relayout while dragging, and nothing clipped when fully expanded.

---

## [1.6.142] - 2026-09-21

### 🐛 修「自身轨迹横跳」；磨砂玻璃性能优化 / Fixing the jumping self-track; frosted-glass performance

两个用户反馈，一个比一个难查。

## 一、自身轨迹横跳：跳回旧点再画一次，反复横画

现象：轨迹每隔一会儿跳回初始点、再画一次当前位置，来回横画，但**实际发出去的位置是对的**。

根因在 Android 原生侧，**不是算法**：`LocationService` 里有个 10 秒轮询会调
`reportLastKnown()`，而它取的是 `getLastKnownLocation()` —— **系统缓存的「上次已知位置」**
（可能几小时前、甚至在另一个城市）—— 它走的是**和实时定位完全相同**的判断函数，
于是每 10 秒被当成一次正常定位上报：旧点写进轨迹 → 真实点又写一次 → 反复。
这也解释了为什么**只有部分手机**出现（取决于缓存位置离当前位置多远）。

顺带一个连带 bug：那个缓存点会推进「最近 GPS 时间」，让代码误以为 GPS 刚更新过，
**反而把真正的网络兜底压掉 20 秒**。

**三层修法**：

- **原生（根因）**：缓存位置只在「还没有实时定位」时用于快速出图（且年龄 ≤ 5 分钟），
  收到实时定位后一律丢弃；GPS 时间戳只由实时定位推进。
- **不写轨迹**：定位回调新增 `lastKnown` 标记，缓存位置只更新地图上的「我」、不写轨迹；
  IP 网络定位也归入此类（一次性的粗点）。
- **跳变守卫（兜其它来源）**：**10 分钟内位移超过 30km** 才算可疑（只看距离会误伤
  「停车几小时后开出去」这种合法位移），可疑点先只更新标记、不写轨迹，连续 **3 次**
  落在同一处才认账 —— 认账后**清空轨迹从新位置重画**，而不是画一条横跨两地的
  假线（那比没有轨迹更误导）。

## 二、磨砂玻璃卡

`BackdropFilter` 每帧都要把背后的内容离屏重绘一遍，代价 ≈ 面积 × 半径，
且**每个实例各付一次**。量下来三个真凶：

1. **2.0 外壳每秒被重建数次** —— 状态每秒 tick、每次收包也 notify，而外壳原来无条件
   `setState`，那些模糊层跟着一起重建。现在只在「外壳真正显示的值」变化时重建。
2. **小浮层也在模糊** —— 全仓库 48 处 `MaterialSurface`，光地图页就 12 处，其中 8 个是
   **38px 的工具钮**；这类浮层根本看不出模糊（能看见的是填充色），却各自付一次整屏
   离屏重绘；「跟随鼠标的信息窗」更是每次悬停都重算。现在按「小浮层实心、大面板磨砂」
   分档（也是 iOS/Android 的做法）。
3. **半径**：玻璃 34→24、云母 22→16。

一个失败的设计也记在代码里：第一版想用 `LayoutBuilder` 按面积自动判断，但地图上的
小浮层**全是 `Positioned` 包着的**，约束是整个 Stack 的尺寸而不是自身尺寸 ——
38px 的按钮被量成整屏，自动规则恰好在最需要它的地方**静默失效**，所以改成显式。

---

**Two reports from users, the first one considerably harder to find.**

**1) The self-track jumped back to an old point and redrew the current position, over and over** —
while the positions actually being transmitted were correct. The cause was not the algorithm but a
wiring bug on the Android side: `LocationService` runs a 10-second poll calling
`reportLastKnown()`, which reads `getLastKnownLocation()` — the **system's cached last-known
position**, possibly hours old or in a different city — and feeds it through **the very same**
decision function as live fixes. So every ten seconds the stale point was reported as a normal fix:
written into the track, then the real fix written again, back and forth. It also explains why only
*some* phones show it: it depends on how far the cached position is from the current one. A related
bug: that cached point advanced the “last good GPS” timestamp, which **suppressed the legitimate
network fallback for 20 seconds**.

Fixed in three layers: **the native side** (cached positions are only used for a quick first draw
before any live fix, and only if under 5 minutes old; the GPS timestamp is advanced only by live
fixes); **no track entries** from cached fixes (the callback now carries a `lastKnown` flag, and IP
geolocation counts as one too); and a **jump guard** for any other source — a move of more than
**30 km within 10 minutes** is treated as suspect (distance alone would wrongly punish “parked for
hours, then drove off”), such points update the marker but not the track, and only after **3
consecutive** readings in the same place is it accepted — at which point the track is **cleared and
restarted from the new position** rather than drawing a fake line across the gap.

**2) Frosted glass felt sluggish.** A `BackdropFilter` re-renders what is behind it offscreen every
frame — cost ≈ area × radius, **paid per instance**. Three culprits: the 2.0 shell was rebuilt
several times a second (so its blur layers were too — now it only rebuilds when a value it actually
displays changes); **small overlays were being blurred at all** (48 `MaterialSurface` uses, twelve
on the map page alone, eight of them **38px tool buttons** — invisible blur, paid in full; a hover
info window recomputed a blur on every hover) — now “solid small overlays, frosted large panels”,
as iOS and Android do it; and the radii came down (glass 34→24, mica 22→16).

One failed design is documented in the code: the first attempt used `LayoutBuilder` to decide by
area — but the map's small overlays are all wrapped in **`Positioned`**, whose child receives the
*stack's* constraints rather than its own size, so a 38px button measured as full-screen and the
rule failed silently exactly where it mattered most. Hence: explicit.

---

## [1.6.141] - 2026-09-21

### 🔧 2.0 收尾：去掉顶部搜索框、返回键回地图、补回天气与一键连接 / 2.0 finishing touches: no more top search bar, back returns to the map, weather and connect restored

三条用户反馈 + 我自己审计出的一处功能缺失。

**一、2.0 顶栏不再有搜索框**

- **台站页自己就有搜索框** —— `StationsPage._query` 的优先级是「本页优先」，
  外壳那个只在它为空时才起作用，对台站页基本是重复的；
- 「一整条浮在地图上的浅色横条」本身就压视觉重量。

现在只留右上角一簇悬浮胶囊。**取舍说明**：2.0 的地图页不再有全局搜索
（1.0 经典布局的顶栏搜索**未动**），地图仍可用图层/类型筛选，搜索在台站页里。

**二、返回键在「其他页」时回到地图页**

`PopScope(canPop: _tab == 0)`：在地图页交给系统（正常退出），在其他页则回到地图
并收起内容面板。放在外壳而非各页（导航本来就是外壳的事），push 出来的子页
（设置子页、底部面板）各自是独立路由，不受影响。

**三、补回天气组件 —— 这是我漏的**

用户问「还有个天气组件在哪了」：`shell2.dart` 里**根本没有天气**，
`WeatherBadge` 从未被引进去。已补在那一簇的最左（与 1.0「在线数左侧」一致），
仍由「设置 → 显示 → 顶栏天气组件」控制。

顺便把 1.0 外壳的功能逐项对了一遍，又找出一处**功能**缺失：

| 功能 | 1.0 | 2.0（改前） |
|---|---|---|
| 天气组件 | 顶栏在线数左侧 | **无** |
| 一键连接/断开 | 侧栏 + 未连接横幅 | **无**（只能进设置页） |
| 未连接横幅 | 有 | 无 |

前两项已补。第三项**未擅自加**：那条横幅会给地图再添一块浮层，而用户刚反馈过
「嫌乱」；它的独有信息（当前是哪种来源、为什么没连上）已在状态胶囊与连接设置页里。

**四、又一个只有 analyze 能发现的错，以及为此新增的检查**

写连接按钮时写了 `const Padding(... color: C.blue)` —— `C.blue` 是 **static 字段
（非常量）**，`const` 构造里不能引用，报 `invalid_constant`。这是仓库里**早就踩过**
的坑（`station_detail.dart` 还留着注释记着它）。

这是同一类「本机语法解析放行、只有 analyze/编译能发现」的错误第四次漏到 CI。
但这一种的判据是**完全确定**的，所以新增 `tool/check_const_colors.py` 并接进 CI。
现在 CI 里有六个静态检查：备份键、Android 资源、材质覆盖、跨层导入、
`widget.X` 声明、`const` 颜色 —— 每一个都对应一类实际犯过的错。

默认仍是 1.0 经典布局；2.0 在「显示设置 → 界面布局」里切换。

---

**Three pieces of user feedback plus one feature gap I found while auditing my own work.**

**1) The 2.0 top bar no longer has a search field.** The stations page already has its own
search box, and `StationsPage._query` prefers the local one — the shell's only mattered when
that was empty. On top of that, a full-width translucent strip floating over the map carries a
lot of visual weight. What remains is a small cluster of pills at the top right. **Trade-off,
stated plainly**: in 2.0 the map page no longer offers a global search (the classic 1.0 layout's
search is **unchanged**); the map still has layer/type filters, and search lives on the
stations page.

**2) Back returns to the map** when you are on any other page: `PopScope(canPop: _tab == 0)` —
on the map page the system handles it (normal exit), everywhere else it goes back to the map and
collapses the content sheet. It lives in the shell rather than in each page, because navigation
is the shell's business; pushed child routes (settings sub-pages, bottom sheets) are separate
routes and are unaffected.

**3) The weather widget is back — that one was my omission.** A user asked where it went:
`shell2.dart` had **no weather at all**, `WeatherBadge` was never wired in. It is now the
leftmost item in that cluster (matching 1.0, where it sat left of the online count) and is still
controlled by Display settings → top-bar weather widget. While auditing, I compared the whole
1.0 shell feature by feature and found one more **functional** gap: 2.0 had **no one-tap
connect/disconnect** (you had to open connection settings), which is now restored. The
“not connected” banner was deliberately **not** re-added — it would put yet another overlay on
the map, and the user had just complained about clutter; its unique information already lives
in the status pill and the connection settings page.

**4) One more mistake only analyze could catch — and a new check for it.** While writing the
connect button I wrote `const Padding(... color: C.blue)`; `C.blue` is a **non-const static
field**, so that is `invalid_constant`. The repository had hit this before (there is a comment
in `station_detail.dart` about it). This was the fourth time a mistake of the class “dart format
is happy, only analyze/compile complains — and analyze cannot run on the maintainer's machine”
reached CI. This one, however, has a **fully deterministic** test, so `tool/check_const_colors.py`
is now the sixth static check in CI: backup keys, Android resources, material coverage,
cross-layer imports, `widget.X` declarations, and const colours — each one earned by a real
mistake.

The default is still the classic 1.0 layout; 2.0 is switchable under Display settings → UI
layout.

---

## [1.6.140] - 2026-09-21

### 🎨 重做 UI 2.0 的底部（导航固定、面板只装内容）；收拾全局「视觉杂」 / Redesigned the bottom of UI 2.0 (fixed navigation, content-only sheet); general visual clean-up

上一版（1.6.139）的 2.0 把 5 个页签放进了**可拖拽卡片的头部** —— 卡片一展开，
导航就升到屏幕中间，底部还叠了两套 chrome（把手 + 页签约 80px）。这次是**重新设计**：

**三层，职责单一**

- **地图整屏**：它才是底，不再是一个页签；切到任何页都不会销毁它。
- **底部悬浮导航**：5 个页签**永远在同一位置**，胶囊外形 + 背景模糊；选中态是
  **一个滑动的指示胶囊**，而不是 5 块固定色底。
- **内容面板**：只装内容、**不再包含导航**；头部只剩一根 22px 细把手。
  拖两个档位（半屏 / 近全屏），**向下拖过阈值即收起**回到地图 ——
  选「地图」就是地图真正全屏。

**顺手把三处几何算错改对**（都是按真实数值画出来对照后发现的）

- 面板展开时**以前会盖住顶栏**（搜索框、连接状态、定位按钮全被吞掉）：
  原先最大档写死 0.86，在小屏上正好重合；现在按「屏高 − 导航 − 面板下边距 −
  顶栏占位」算，两边各留 8px。
- 地图贴底的比例尺/坐标条**以前会漂出一段空隙**：`bottomInset` 的口径含糊，
  等于把「导航占用」与「安全区」重复算了一遍（实测差了 46px）。现在口径明确为
  「底部被占用的边界（不含安全区）」，贴底控件永远落在占用区上方 14px。
- 非搜索页的顶栏**不再重复导航的信息**：导航已高亮当前页，顶栏再写一遍标题是
  重复的；改成右上角一小簇胶囊（连接状态 + 定位），地图因此多露一截。

**全局「视觉杂」收拾**（1.0 与 2.0 都受益）

| 项 | 之前 | 之后 |
|---|---|---|
| 圆角取值 | **12 种**（10/11/12/13/14/15/16/18/20/22…） | **7 档**：2/6/8/12/16/24/999 |
| 字号取值 | **25 种**（含 8.5/9.5/10.5/11.5/12.5/13.5/14.5 等小数档） | **8 级**：9/10/11/12/13/16/20/26 |
| 阴影取值 | **19 种** (blur,y,alpha) 组合 | **3 级**：elev1/elev2/elev3 |
| 「框套框」 | 顶栏与圆形工具钮同时画描边 + 投影 | 只留投影 |

分档语义：6 小徽标、8 小控件、**12 按钮/输入/列表行/工具钮**、16 卡片面板、
24 底部面板、999 胶囊。同类元素现在长得一样，才有节奏。

**新增一个本机可跑的静态检查**（`tool/check_widget_members.py`，已进 CI）

「State 里用到的 `widget.X` 必须在同文件有声明」。起因是同一类错误撞了三次
（漏 import、字段重复声明、改文档时把中间的字段声明一起吞掉）—— 它们都只在
analyze/编译时报错，而本机唯一能跑的语法检查一律放行。这个守卫双向验证过：
仓库现状 0 报错，故意删掉一个字段能精确报出文件与行号。

默认仍是 1.0 经典布局；2.0 在「显示设置 → 界面布局」里切换，两套设置各自保留。

---

**In 1.6.139 the 2.0 layout put its five tabs inside the draggable card's header** — so the
navigation climbed into the middle of the screen whenever the card expanded, and the bottom
stacked two layers of chrome (handle + tabs, about 80px). This release **redesigns it**:

* **The map is full-screen and is the base** — no longer a tab, and it is never destroyed when
you switch pages.
* **A floating bottom navigation** whose five tabs **never move**, shaped as a pill with a
backdrop blur. The selection is **a single sliding indicator pill** instead of five tinted
blocks.
* **A content sheet that holds content only** — no navigation inside it, just a 22px handle.
Two detents (half / near-full); **drag down past the threshold to dismiss** back to the map.
Choosing “Map” gives you a genuinely full-screen map.

**Three geometry errors fixed along the way** (all found by drawing the layout to scale and
looking at it): the expanded sheet used to **cover the top bar** (search, connection state and
the locate button were swallowed — the old 0.86 hard-coded detent coincided with it on small
screens); the map's bottom controls **drifted away from the navigation** because `bottomInset`
was ambiguous and counted the safe area twice (46px off); and the top bar **no longer repeats
what the navigation already shows** — on non-search pages it collapses to a small cluster of
pills at the top right, letting the map show more.

**General visual clean-up** (benefits both layouts): corner radii went from **12 distinct
values** down to **7 steps** (2/6/8/12/16/24/999), font sizes from **25** down to **8 levels**
(9/10/11/12/13/16/20/26), shadows from **19** ad-hoc (blur, y, alpha) combinations down to
**3 elevations**, and surfaces that drew both a border and a shadow (the top bar, the round map
buttons) now rely on the shadow alone.

**A new local static check** (`tool/check_widget_members.py`, wired into CI) verifies that every
`widget.X` used by a State has a declaration in the same file. It exists because the same class
of mistake — invisible to `dart format`, only caught by analyze/compile, which cannot run on the
maintainer's machine — was hit three times.

The default is still the classic 1.0 layout; 2.0 is switchable under Display settings → UI
layout, and each layout keeps its own settings.

---

## [1.6.139] - 2026-09-21

### ✨ UI 2.0：以地图为基底的布局（显示设置里可切换）/ New map-first layout (switchable in Display settings)

显示设置新增「界面布局」两档：**经典布局（1.0，默认）/ 地图为基底（2.0）**。
它与「界面材质」（磨砂玻璃 / 云母）是**两个独立的开关**，可以任意组合（2.0 + 云母、
1.0 + 磨砂玻璃都成立），切完立即生效。

**2.0 长什么样**

- **地图常驻整屏**：它不再是一个页签，而是整个界面的底（所以在地图之外的页面
  也能一眼看到自己与台站的位置关系）；
- **底部可拖拽卡片**：台站 / 消息 / 数据包 / 设置装进来，卡片顶部就是导航行 ——
  「切页」和「这页在卡片里」是同一件事。上滑或点把手展开，收起只留导航行；
- **浮在地图上的顶栏**：搜索、在线数、连接状态、定位入口；点连接胶囊可直接进
  连接设置（2.0 没有侧栏，得给它一个入口）；
- **地图页签的卡片内容**：抬起卡片时看的是「我这台电台」—— 呼号、网格、速率、
  定位状态、信标会不会真的发出去（带手动上报）。收起卡片就是看地图。

**三个实现上的取舍（都写进了代码注释）**

- **卡片内容永远按「展开高度」布局，只裁显示区**（`OverflowBox + ClipRect`）。
  卡片收起到只剩导航行时可视高度只有几十像素，把页面直接塞进这么高的盒子会让
  页面内部的 `Column` 立刻溢出（黄黑斜纹），而且拖动时高度每帧都变、布局每帧重做。
  现在拖动零重算、不溢出，五页的滚动位置与状态全部保留。
- **拖动只认把手与导航行，不抢列表的手势**。`DraggableScrollableSheet` 要求把它的
  滚动控制器交给内部滚动体，那等于让外壳接管五个页面的列表（下拉刷新、横向列表
  都会变脆）。代价是「列表滑到顶再上滑展开卡片」这种联动没有 —— 换来五页滚动
  行为零改动。
- **最矮那档按头部高度算出来**，不是写死比例：窄屏 / 大字号下写死的比例会把
  导航行切掉一半（看起来像「导航行缺了一块」）。

**与地图的接口**：`MapPage` 新增 `bottomInset` —— 2.0 下地图要让开卡片的高度，
否则它贴底的比例尺/坐标条与上报横杠会被卡片压住（表现是「2.0 里这些控件不见了」）。

**兼容**：默认仍是 1.0，界面与以前逐像素一致；两套布局的设置各自保留，
随时可以切回去。

新增偏好键 `uiLayout`（空 = 1.0，认不出的值一律回落 1.0；布局选错比颜色错严重
得多），已归入备份的「设置」分组；新增 7 个文案键 × 6 语言。

---

**Display settings has a new “UI layout” entry with two options: Classic (1.0, default)
and Map-first (2.0).** It is an **independent switch** from “UI material” (frosted glass /
mica) — any combination works — and changes take effect immediately.

- **The map is always full-screen**: it is no longer a tab but the base of the whole UI,
  so the spatial relationship between you and the stations stays visible from every page.
- **A draggable card at the bottom** holds stations / messages / packets / settings, and the
  card's own header *is* the navigation — switching pages and “this page lives in the card”
  are the same gesture. Swipe up or tap the handle to expand; collapsing leaves just the nav row.
- **A floating top bar** carries search, the online count, connection state and a locate button;
  tapping the connection pill opens connection settings (2.0 has no side rail, so that entry
  point has to exist somewhere).
- **The map tab's card content** is “my station”: callsign, grid, rate, fix status, and whether
  the beacon will actually go out (with a manual-beacon button). Collapse the card to see the map.

**Three deliberate trade-offs** (documented in code): the card's content is always laid out at
its *expanded* height and merely clipped (`OverflowBox + ClipRect`) — otherwise a 50-pixel-tall
card would make inner `Column`s overflow and relayout on every drag frame; dragging is limited to
the handle and nav row instead of using `DraggableScrollableSheet`, whose scroll controller would
have to drive five pages' lists; and the lowest detent is computed from the header height rather
than hard-coded, which would clip the nav row on narrow screens or at large text sizes.

`MapPage` gained a `bottomInset` so the map can move its bottom controls (scale/coordinate bar,
beacon bar) out from under the card. The default stays 1.0 and is pixel-identical to before; both
layouts keep their own settings and you can switch back at any time.

New preference key `uiLayout` (empty = 1.0, unrecognised values fall back to 1.0 — picking the
wrong layout is far worse than the wrong colour), filed under the backup “settings” group, plus
7 new localised strings × 6 languages.

---

## [1.6.138] - 2026-09-20

### ✨ 界面材质：磨砂玻璃与云母，显示设置里可切换 / New UI materials — frosted glass and mica, switchable in Display settings

显示设置里新增一项「界面材质」，三档：**关闭（默认）／磨砂玻璃／云母**。

**这三档各自是什么**

- **磨砂玻璃**：更透（表面不透明度 0.55）、模糊更强，接近 Windows 11 的亚克力（Acrylic）；
- **云母**：更实（0.78）、模糊较轻，带一层从主色混出来的色，接近 Windows 11 的云母（Mica）；
- **关闭**：与旧版**逐像素一致** —— 这是默认值，也是兼容底线：老用户升级后界面不会被改掉。

**实现上的三处取舍（都写进了代码注释，因为下次改动会再碰到）**

- **底是一次性画好的**：材质开启（且主题没设背景图）时，应用在最底层画一张从主色混出来的
  柔和渐变当「壁纸」，页面底色随之透明 —— 半透明表面背后得有东西可透，否则磨砂玻璃看起来
  只是「变淡了」，用户只会以为开关没生效。
- **只有压在内容上的表面做真模糊**：顶栏、侧栏、底部导航、各页 AppBar、地图浮层、
  地图/站点/群组面板用 `BackdropFilter` 真模糊，因为背后是地图瓦片或正在滚动的列表，
  不模糊就会糊成一片。**卡片不套模糊** —— 它们背后只是那张已经画好的底，再模糊一次是纯浪费，
  而每个 `BackdropFilter` 都是一次整屏 `saveLayer`：一屏十几张卡片就是十几层，低端 Android 上直接掉帧。
- **材质与主题不打架**：表面不透明度 = 材质档位 × 用户自己调的 `surfaceAlpha`（相对默认 0.85 的比例），
  所以「玻璃永远比云母透」和「滑杆往哪边拉就真往哪边去」两件事同时成立。
  主题已设**背景图**时不再叠材质壁纸（在他自己挑的图上再叠一层渐变只会变成脏颜色），
  只把顶栏与浮层做成磨砂，设置页里也会说明这一点。

**设置页里每一档都配了小样**（渐变底 + 三条色带，再盖上该档的磨砂层）。
小样用的是与真实材质**同一对颜色、同一组数字**（`uiMaterialAlphaOf` / `uiMaterialBlurOf`），
预览和实际效果不会各走各的 —— 那种漂移只有截图对比才看得出来，也就是没人会发现。

**边界**：这是应用内的材质，不是系统窗口透明（Windows 的 Mica/Acrylic 窗口效果要额外插件，
而 Android 上没有对等物，那会变成「这档设置在手机上点了没反应」）。模糊要占显卡：旧机型上
可能不如「关闭」顺滑，设置页里也照实说了。

新增偏好键 `uiMaterial`（字符串，空 = 关闭，认不出的值一律回落关闭），已归入备份的「设置」分组，
换机后材质设置跟着走；新增 11 个文案键 × 6 语言。

---

**Display settings has a new “UI material” entry with three options: Off (default) / Frosted glass / Mica.**

- **Frosted glass** — more transparent (surfaces at 0.55) with a stronger blur, close to Windows 11 Acrylic.
- **Mica** — more solid (0.78) with a lighter blur and a tint mixed from your accent colour, close to Windows 11 Mica.
- **Off** — pixel-identical to previous versions. It is the default, and that is the compatibility promise: an
  existing user upgrading must not find their UI changed underneath them.

**Three deliberate trade-offs (documented in the code, because the next change will hit them again)**

- **The backdrop is painted once.** With a material on (and no background image in the theme), the app paints a
  soft gradient mixed from the accent colour as a wallpaper and makes page fills transparent — a translucent
  surface needs something worth showing through, otherwise “frosted glass” just looks slightly faded and users
  conclude the switch does nothing.
- **Only surfaces that sit *on top of content* get a real blur**: top bar, side rail, bottom navigation, page
  app bars, map overlays and the map/station/group panels. What is behind them is map tiles or a scrolling list,
  so without a blur the text would smear into them. **Cards are deliberately not blurred** — the only thing behind
  a card is that already-painted backdrop, so blurring again buys nothing while every `BackdropFilter` costs a
  full-screen `saveLayer`; a dozen cards on screen means a dozen layers and visible frame drops on low-end Android.
- **Materials and themes do not fight each other**: surface opacity = the material's base × the user's own
  `surfaceAlpha` (as a ratio against the 0.85 default), so “glass is always more transparent than mica” and
  “the slider really moves things” hold at the same time. When the theme already has a **background image**, the
  material wallpaper is skipped (stacking a gradient over a picture the user chose only makes mud) and only the
  bars and overlays get frosted — the settings page says so as well.

**Every option in settings comes with a small swatch** (gradient backdrop, three colour bars, then that
option's frosting). The swatch uses the very same colours and numbers as the real thing
(`uiMaterialAlphaOf` / `uiMaterialBlurOf`), so the preview cannot drift away from the result — that kind of drift
is only visible when someone compares screenshots, which means nobody ever finds it.

**Scope, stated honestly**: this is an in-app material, not window transparency. (Real Windows Mica/Acrylic
windows need an extra plugin, and Android has no equivalent — that would have turned this switch into “nothing
happens on my phone”.) Blur costs GPU time, so on older devices it may feel less smooth than Off; the settings
page says that too.

New preference key `uiMaterial` (string, empty = off, unrecognised values fall back to off), filed under the
backup “settings” group so it travels with a device change, plus 11 new localised strings × 6 languages.

---

## [1.6.137] - 2026-09-19

### 🛠 修「网关传递统计一直是 0」：先把 0 说清楚，也别自己制造 0 / Fixing “the iGate counters are always 0” — explain the zero, and stop creating one

用户报：网关传递统计一直是 0。逐层查下来，计数逻辑本身是好的（判据与改写都是
纯函数 `Igate`，有测试），真正的问题是这个 `0` **四个含义长得一模一样**：

① 射频根本没收到报文（TNC 没连上 / 线速不对）→ 链路问题；
② 收到了，但 APRS-IS 没连上（没有可转递的目标）→ 网络问题；
③ 收到了，但全被环路防护拒收（报文来自互联网）→ 其实**在正确工作**；
④ 真的什么都没转。

而界面上只有一串 0，四种情形的显示完全一样 —— 排查只能靠猜。这一版把它拆开。

**新增两个数，把「没流量」和「没转递」分开**

- **射频收到（条）**：**只要射频在收就计，与网关开不开、APRS-IS 通不通无关**。
  它是唯一能自证的数字 —— 有了它，「射频到底有没有东西进来」不再需要靠日志猜。
- **环路拒收（条）**：原先只在日志里且还按节流（20 条才打一行）。它一直涨，
  「已转递 = 0」就是有原因的，得让人直接看见。

**「不涨」时界面直接说缺哪一项**（这四种情形分开说，不合并成一句「不能用」）

- 没勾射频来源 → 去勾 TNC / 音频；
- 勾了但链路没连上（线速不对 / 设备没开机）→ 去查设备页，**而不是怀疑网关**；
- APRS-IS 没连上 → 没有可转递的目标网络，等它连上数字才会涨；
- 条件全齐、却一条都没收到 → 明说「这不是网关的问题，报文根本没进来」，
  并指出上游该查什么（音量/静噪、天线、对方是否真的在发射）。
- 全被环路防护拒收 → 说明这是**在正确工作**（那些报文本来就从互联网来，
  再送回去会让同一条报文无限增殖），不是故障。

**顺手修两个「由统计自己制造出来的 0」**

它们比缺字段更隐蔽，因为表现和「一切正常但没流量」一模一样：

- **开关一关一开就把统计清零**。而「数字不涨 → 关掉再打开」正是用户的第一反应，
  于是数字立刻归零、再开回来也永远看不到它曾经涨过 —— 诊断路径被自己的界面堵死。
  现在清空统计只认「清空统计」这个按钮（切换数据来源时也清，那是换了一套配置）。
- **射频链路已经断了还在计「射频收到」**。链路是断的却还在冒数，只能说明有别的链路
  在往同一条管线里灌（同时绑了同一台设备、APRS-IS 被当成射频…）。那时这个数就是假的 ——
  而**假的自证数字比没有数字更糟**：用户会拿它去证明「射频没问题」，然后往错的方向查。

**真正的功能 bug：串口线速被静默复位成 9600**

`TncConfig._copy()` 是一段**手写的逐字段拷贝**，而**真正读配置走的就是它**
（`TncLink.load()` → `_copy()`）。它漏抄了 `serialBaud` —— 于是串口 TNC 设了 38400，
重启后又按 9600 打开，**一个字节都收不到**，症状正是「台站不上图、网关统计恒为 0」，
而界面上任何地方都看不出线速变了。

`toJson` / `fromJson` 都带着 `serialBaud`，测试也只验了 JSON 往返，所以看起来「早就修好了」——
但那条路根本没人走。补上的同时还钉了一条**直接调 `load()`** 的回归测试，
并把同一段拷贝里其它射频参数（`path` / `initString`）一起盯住：**漏字段 = 静默复位，
与「没持久化」完全等价**。

**顺带**：切换射频来源（换设备 / 线速 / 频段）时清掉去重表与「听到过」列表 ——
旧表会把新链路上的**首包**当成重复丢弃，表现也是「网关统计一直是 0」（连「重复丢弃」
都不涨时最难查）；但**统计不清**，用户正需要它来对比换配置前后。

新增 6 条网关统计回归测试（`test/igate_state_test.dart`，含 `rf-down` 不计数、
开关不清统计、切来路清表不清数、以及「解码器产物不被判成畸形」的接缝测试），
新增 2 个文案键 ×6 语言。

---

**The iGate relay counters were always 0.** Layer by layer, the counting itself was fine
(`Igate` is a pure function with its own tests); the real problem was that a single `0` had
**four indistinguishable meanings**:

① nothing was ever heard on RF (TNC down / wrong baud) — a link problem;
② packets arrived but APRS-IS was down (nowhere to relay to) — a network problem;
③ packets arrived but all were rejected by loop protection (they came from the internet) —
the gateway **working correctly**;
④ genuinely nothing was relayed.

The UI showed the same row of zeros for all four, so troubleshooting was guesswork.

**Two new counters to separate “no traffic” from “no relaying”**

- **Heard on RF**: counted **whenever RF is receiving, regardless of whether the gateway is on
  or APRS-IS is up**. It is the one self-proving number: “is anything at all arriving on RF”
  no longer has to be inferred from the log.
- **Loop-protection rejects**: previously log-only and throttled (one line per 20 packets).
  If it keeps climbing, “relayed = 0” has a reason, and that reason should be visible.

**When nothing is moving, the UI now names the missing piece** (four separate cases, not one
vague “not available”)

- No RF source ticked → tick TNC / audio.
- Ticked but the link is not up (wrong baud, device off) → look at the device page,
  **not at the gateway**.
- APRS-IS not connected → there is nowhere to relay to; the numbers start moving once it is up.
- Everything ready but not a single packet heard → it says plainly that this is not a gateway
  problem and tells you what to check upstream (volume/squelch, antenna, whether anyone is
  actually transmitting).
- All rejected by loop protection → explained as **working correctly** (those packets came from
  the internet; sending them back would multiply the same packet forever), not a fault.

**Two “zeros the statistics created themselves”**

These are sneakier than a missing field, because they look exactly like “everything is fine,
just no traffic”:

- **Toggling the gateway off and on used to wipe the counters.** And “it isn’t moving → turn it
  off and on” is the user’s first reflex, so the numbers reset instantly and never show history
  again — the UI sabotaged its own diagnostic path. Clearing is now only done by the
  **“Clear statistics”** button (plus when switching data sources, i.e. a genuinely new setup).
- **The RF link being down no longer counts as “Heard on RF”.** If the RF link is down and the
  counter still climbs, something else is feeding the same pipeline (a shared device, APRS-IS
  mistaken for RF…), and the number is a lie — and **a lying self-proof is worse than none**:
  users use it to prove “RF is fine” and then search in the wrong direction.

**The real functional bug: serial baud silently reset to 9600**

`TncConfig._copy()` is a **hand-written field-by-field copy**, and it is exactly what the
config-loading path uses (`TncLink.load()` → `_copy()`). It never copied `serialBaud` — so a
serial TNC configured for 38400 was reopened at 9600 after a restart and **received not a
single byte**, whose symptoms are precisely “stations never appear on the map and the iGate
counters stay at 0”, with nothing in the UI to hint that the baud rate had changed.

`toJson` / `fromJson` both carry `serialBaud`, and the tests only covered the JSON round trip,
so it looked long fixed — but that path was never taken. Along with the fix, a regression test
now calls `load()` directly and pins the other RF parameters in the same copy block
(`path`, `initString`): **a missed field is a silent reset, exactly equivalent to never
persisting it at all**.

**Also**: switching the RF source (new device / baud / band) now clears the dedupe window and
the “heard” list, because a stale window makes the **first** packet on the new link look like a
duplicate — another way for the counters to sit at 0 (and the hardest to spot, since not even
“duplicates dropped” moves). The statistics, however, are **not** cleared: comparing before and
after the change is exactly what the user needs them for.

Six new regression tests for the gateway counters (`test/igate_state_test.dart`, covering
`rf-down` not counting, the switch not wiping stats, clearing tables but not numbers when the
source changes, and the seam test that decoder output is never judged malformed), plus two new
string keys ×6 languages.

## [1.6.136] - 2026-09-19

### 🔌 新增「硬件串口」：Android 支持 USB-OTG 串口线，桌面串口可设波特率 / New “hardware serial”: USB-OTG serial on Android, settable baud rate on desktop

Android 侧此前只有蓝牙 SPP —— 插一根 USB-OTG 转串口线（CH340 / CP2102 / FTDI）
或电台自带 USB 口时**完全用不了**，而这类线恰恰最便宜、延迟最低、最不会被系统
限流。桌面串口更早就存在，但**没有波特率设置**（代码注释写的是「由系统决定」），
Windows 上 COM 口还是独占设备、开两个句柄会失败 —— 等于那条路根本没通。

- **Android USB 串口**（新增 `UsbSerialManager.kt`，零新增依赖）：`UsbManager`
  枚举 + 批量传输搬字节，系统弹一次授权即可（无需存储权限）。
  - **芯片适配**：CDC-ACM（标准 SET_LINE_CODING，电台自带 USB 口与 Arduino 类）、
    CH34x（厂商私有初始化 + 分频写寄存器）、CP210x（含旧固件兼容路径）。
    FTDI / PL2303 的私有序列**本版未实现** —— 设备仍可打开收发（很多模块出厂就是
    9600/38400），但改不了它的线速，且会在日志里明确说明，不假装成功。
  - **热插拔**：支持 USB_DEVICE_ATTACHED 广播 + `usb_device_filter.xml` 过滤表，
    插上线时系统能直接列出本应用。
  - **枚举不按 VID 白名单**：USB 转串口线的 VID/PID 组合极多（还有大量白牌），
    按白名单会把能用的线判成「不支持」；这里按**端点形状**判断（有批量 IN+OUT
    即串口设备），展示名里带 VID:PID 供用户认线。
- **桌面串口补上波特率**：Linux `stty -F` / macOS `stty -f` / Windows `mode COMx:`，
  先设参数再开句柄（tty 参数留在设备节点上，两个句柄自然继承）。设不上会如实
  写进链路日志 —— 「没设上却以为设上了」比报错难查得多。
- **蓝牙 / USB 自动选路**（新增 `TncAutoTransport`）：绑定的设备是持久化的，
  用户下次启动直接点「连接」，那一刻没人会问「这是蓝牙还是 USB」—— 选路必须由
  传输层按设备类型完成。同一时刻只保持一条链路（两条同时开会把接收字节流瓜分，
  症状正是「能发不能收」）。
- **线速放在设备页**（`TncConfig.serialBaud`，默认 9600，随配置持久化）：
  USB 串口线与电台数据口必须同速，否则一个字节都收不到。蓝牙设备下这一项
  会明确提示「不生效」（SPP 没有波特率概念），而不是静默忽略。
- **顺手修掉一个真缺陷**：原生早就在发 `txok` / `txfail` 事件，但 **Dart 侧从未
  监听** —— 于是「发射自检」的写出确认从来收不到回应，每次都退化成
  「已入队但未收到写出确认」（看起来像没确认，实际是根本没人听）。现在蓝牙与
  USB 共用同一条事件解析，两条链路都真正拿得到写出确认。
- 界面文案随之更新（扫描按钮 / 空列表 / 权限提示不再只说蓝牙）。新增 16 条
  回归测试（选路、线速传递、切路、断开语义）。

Android previously had only Bluetooth SPP — plugging in a USB-OTG serial cable
(CH340 / CP2102 / FTDI) or a radio's own USB port **did nothing**, even though those
cables are the cheapest, lowest-latency and least-throttled option. Desktop serial
had existed for longer but with **no baud rate setting** (the code comment said “decided
by the system”), and a Windows COM port is exclusive so the second handle fails — in
practice that path was never usable.

- **USB serial on Android** (new `UsbSerialManager.kt`, no new dependencies):
  enumeration via `UsbManager` and byte-pumping with bulk transfers, plus a one-time
  system permission prompt (no storage permission).
  - **Chip support**: CDC-ACM (standard SET_LINE_CODING — radios with a built-in USB
    port and Arduino-class boards), CH34x (vendor init + divisor registers) and CP210x
    (with a legacy-firmware path). FTDI / PL2303 vendor sequences are **not implemented
    in this version** — those devices still open and transfer (many modules ship at
    9600/38400), but the baud rate cannot be changed, and that is stated plainly in the
    log instead of pretending it worked.
  - **Hot plug**: `USB_DEVICE_ATTACHED` plus a `usb_device_filter.xml` table, so the
    system can offer this app when the cable is plugged in.
  - **Enumeration is not a VID allow-list**: USB-serial VID/PID pairs are numerous
    (including many white-label cables), and an allow-list would call a working cable
    “unsupported”. Detection is by **endpoint shape** (bulk IN + OUT means a serial
    device), and the VID:PID is shown in the name so the user can identify the cable.
- **Baud rate for desktop serial**: Linux `stty -F`, macOS `stty -f`, Windows
  `mode COMx:` — parameters are applied before the handles are opened (tty settings
  live on the device node, so both handles inherit them). Failures go into the link
  log verbatim: “thought it was set but it wasn't” is far harder to diagnose than an
  error message.
- **Automatic routing between Bluetooth and USB** (new `TncAutoTransport`): the bound
  device is persisted, so the next launch just taps “connect” — at that moment nobody
  asks “Bluetooth or USB?”, and routing has to happen in the transport layer based on
  the device type. Only one link is kept at a time (two at once split the received byte
  stream, which shows up exactly as “transmits but receives nothing”).
- **The baud rate lives on the device page** (`TncConfig.serialBaud`, default 9600,
  persisted with the config): the USB cable and the radio data port must agree, or not a
  single byte gets through. With a Bluetooth device the field says plainly that it has
  no effect (SPP has no baud rate) instead of silently ignoring it.
- **A real defect fixed along the way**: the native side had been emitting `txok` /
  `txfail` events all along, but **nothing on the Dart side ever listened** — so the TX
  self-test's write acknowledgement never arrived, and every run degraded to “queued but
  no write confirmation” (which looks like “unconfirmed” when in fact nobody was
  listening). Bluetooth and USB now share one event parser, so both links really do get
  their write acknowledgements.
- UI wording follows (scan button / empty list / permission hint no longer say Bluetooth
  only). 16 new regression tests cover routing, baud propagation, switching and
  disconnect semantics.

## [1.6.135] - 2026-09-19

### 📻 修「音频发射对方解不出」：Android 发射期间拉满音量、暂停麦克风、并给出接线与电平提示 / Fixes “on-air audio cannot be decoded by other software”: full media volume, mic paused during TX, plus wiring and level hints

用户报告：**实时发射**（手机接电台 / 对着电脑上的 Direwolf）对方解不出。
先把软件层排除干净 —— 我用一份**独立实现**（非本项目代码）解调「音频」页真实发射
路径产出的音频，按规范（mark=1200Hz、NRZI 1=不变）能解出完整帧、FCS 正确。
**所以波形与协议没问题，问题在「音频怎么送到对方」这一段。** 这一段此前
完全没被照顾：

- **发射期间把媒体音量拉到最大**（结束后原样恢复），并申请瞬时音频焦点。
  手机媒体音量偏低时对端信噪比不够，整帧都解不出；而「别的应用正在放音乐」
  会和 FSK 混在一起 —— 混音等于加噪声，波形直接毁掉。
- **发射期间真正暂停麦克风采集**（半双工）。此前只是「收上来再丢掉」，
  AudioRecord 仍开着：一边录音一边播放时，部分机型会把播放路由到听筒、
  或叠加 AEC/降噪 —— 本机自检全过，电台却解不出，正是这个形状。
- **发射体检进日志**：峰值%、时长、前导 flag 数。削顶（≥99.9%）与电平偏低
  （<15%）都会明确报警 —— 这两种情况自检都「通过」，只有对方解不出，
  是最难查的一类。
- 音频页新增「接线提示」：接电台请走音频线；**手机扬声器在 2200Hz 衰减很大**，
  对着麦克风很难解出。对端是电脑上的 Direwolf 时，先用导出的 WAV 验证一遍 ——
  能解出就说明问题在音频通路，而不是协议。

Reported: **live TX** (phone into a radio, or aiming at Direwolf on a PC) could not be
decoded by the other end. I first ruled the software layer out — an **independent
implementation** (not this project's code) decodes audio captured from the real TX path
with correct FCS and legal addressing, so **the waveform and protocol are fine; the
problem is in how the audio reaches the other end.** That part had no handling at all:

- **Media volume is raised to maximum for the transmission** (restored afterwards) and
transient audio focus is requested. At low media volume the far end's SNR is too poor to
decode a whole frame, and music from another app mixes with the FSK — mixing is just
noise, and it destroys the waveform.
- **Microphone capture is actually paused during TX** (half duplex). Previously samples
were merely dropped after capture, with AudioRecord still running; when recording and
playback run together some devices route playback to the earpiece or stack AEC/noise
suppression on it — the app's self-test passes while the radio cannot decode.
- **TX diagnostics in the log**: peak %, duration, preamble flag count. Clipping (≥99.9%)
and low level (<15%) are called out explicitly — both pass the self-test and only fail at
 the far end, which is the hardest class of problem to find.
- The audio page now shows **wiring hints**: use an audio cable into the radio;
**a phone speaker rolls off badly at 2200 Hz**, so decoding it over the air from the
speaker is very hard. When the far end is Direwolf on a PC, first verify with an exported
WAV — if that decodes, the problem is the audio path, not the protocol.

### 💾 修「导出路径」：不再要求手打路径，导出前自解一遍 / Fixes the export path: no more typing paths, and the file is decoded before it is written

- **Android 导出改走系统「保存到下载目录」**（MediaStore，免存储权限）：
  落到 `下载/APRSlocusAudio`，弹窗直接给出**真实路径**并可一键复制 ——
  拷到电脑就能喂给 Direwolf。此前要用户手打路径，而 Android 应用**本来
  就写不了任意目录**，私有目录用户又看不见 —— 这个入口在语义上就是坏的。
- **导入改用系统文件选择器**（不再手打路径）；桌面端保留路径输入框
  （桌面用户本来就习惯填路径）。
- **导出前在内存里自己先解一遍**：解不出就直接报错，宁可不写，
  也不给用户一个拿到对端反复试的坏文件。
- **二进制走独立的原生通道**：文本导出按 UTF-8 写，WAV 是二进制 ——
  沿用同一条通道会把文件写坏，而「坏了却显示成功」是最难查的一种。
- 文件名带呼号与时间戳（`APRSlocus_<呼号>_<时间>.wav`）：下载目录会累积
  多个导出，同名只能被系统加 `(1)(2)`，之后谁也分不清哪个是哪个。

- **Android export now goes through the system “save to Downloads”** (MediaStore, no
storage permission needed): files land in `Downloads/APRSlocusAudio`, and the dialog
shows the **real path** with a one-tap copy — move it to a PC and feed it to Direwolf.
Previously the user had to type a path, but an Android app **cannot write arbitrary
directories** and its private directory is invisible — that entry point was broken by
design.
- **Import uses the system file picker** (no more typing paths); desktop keeps the path
field, since desktop users expect to type paths.
- **The WAV is decoded in memory before it is written**: if it does not decode the export
fails outright — better to write nothing than to hand the user a broken file to retry at
the far end.
- **Binary goes through its own native channel**: text export writes UTF-8, while a WAV is
binary — reusing that channel corrupts the file, and “corrupted but reported as success”
is the hardest kind to notice.
- Filenames carry the callsign and a timestamp (`APRSlocus_<call>_<time>.wav`): the
Downloads folder accumulates exports, and identical names only get `(1)(2)` suffixes,
after which nobody can tell which is which.

### 📦 修「数据包控制台」：手动注入在 TNC / 音频下点了没反应 / Fixes the packet console: manual inject did nothing under TNC / audio

射频（TNC / 音频）下手动注入一条报文，界面**既没有成功提示也没有失败提示** ——
实为静默失败，三件事叠在一起：

- **发送前先校验格式**：漏了 `>` 或 `:` 直接拦下并提示，不再「显示已发送、
  其实对端什么都没收到」。
- **未连接时如实返回 `not-connected`**，而不是照旧自增发包数 ——
  计数从此只在真的交给链路后才增加。
- **界面给出结果反馈**：成功弹绿条、失败弹红条（5s，够读完），
  且**失败时保留输入**，改一个字符就能重发。
- 输入框下方新增**上下文提示**：当前链路、整包字节数与上限
  （射频按 AX.25 单帧上限、APRS-IS 按 512 字节整行）、当前路径，
  含 `TCPIP*` 时提醒「射频上会被自动剔除」。

Under RF (TNC / audio), injecting a packet produced **neither a success nor a failure
message** — a silent failure, caused by three things stacking up:

- **Format is validated before sending**: a missing `>` or `:` is rejected with a message
instead of “shown as sent” while the far end receives nothing.
- **`not-connected` is returned honestly** instead of incrementing the TX counter anyway —
the counter now only advances once the packet is actually handed to a link.
- **The UI reports the result**: a green bar on success, a red one on failure (5 s, long
enough to read), and **the input is kept on failure** so one character can be fixed and
resent.
- A **context line** under the input shows the current link, the packet byte count and
limit (AX.25 single-frame limit on RF, the 512-byte APRS-IS line limit), the current path,
and a warning when `TCPIP*` is present.

## [1.6.134] - 2026-09-19

### 🔧 修 v1.6.133 把 4×2 弄没了：`minResizeHeight` 不能大于 `minHeight`

装了 v1.6.133 之后 4×2 落不下来、或被强行撑大。根因是我在 widget_info 里写了一组
**自相矛盾**的尺寸：

| | `minHeight`（默认尺寸） | `minResizeHeight`（我写的） |
|---|---|---|
| 短波 | 110dp | **150dp** |
| 系统状态 | 110dp | **125dp** |
| 天气（一直正常） | 110dp | 60dp |

`minResizeHeight` 的语义是「用户**最少**能拖到多小」。把它写成比组件自己的默认高度
还大，等于宣告「默认的 4×2 低于下限」—— 启动器只能拒绝落到 4×2、或强行撑到那个下限。
**约束是 `minResize* ≤ min*`，我把方向搞反了。**

现在两个组件都取 105dp（略低于默认 110dp），4×2 始终可达。宽度下限不变
（短波 200dp / 系统状态 170dp）—— 那是「再窄就先牺牲波段名」的位置。

**顺带修掉判档阈值。** 原来按「≥3 格」判加高布局，而格子数是按 `74 × n − 16` 这个
**标称**公式反推的 —— 实际每格多高随启动器与屏幕差很多，用它判档时 4×2 在部分启动器上
被算成 3 格，直接套上了 232dp 的加高布局而溢出（表现同样是「4×2 坏了」）。
现在改成**直接比 dp**：≥240dp 才换加高档。理由很直白 —— 加高布局放不放得下本来就是
个 dp 事实（内容 232dp / 215dp），而 3 格标称只有 206dp，它本来就装不下。

---

**Fixes the 4×2 regression from v1.6.133: `minResizeHeight` must not exceed `minHeight`.**

After v1.6.133 the 4×2 size could no longer be placed, or was forced larger. The cause was a
**self-contradictory** set of size declarations in the widget infos:

| | `minHeight` (default size) | `minResizeHeight` (what I wrote) |
|---|---|---|
| HF | 110dp | **150dp** |
| System status | 110dp | **125dp** |
| Weather (never broken) | 110dp | 60dp |

`minResizeHeight` means "the smallest size the user may drag to". Declaring it *larger* than the
widget's own default height announces that the default 4×2 sits below the floor — so the launcher
either refuses to place it at 4×2 or forces it up to that floor. The constraint is
**`minResize* ≤ min*`**, and I had it backwards.

Both widgets now use 105dp (just under the 110dp default), so 4×2 is always reachable. The width
floors are unchanged (200dp / 170dp) — the point where a narrower widget starts sacrificing the
band name.

**The tier threshold is fixed as well.** It used to switch to the tall layout at "3 cells or more",
where cells come from the **nominal** `74 × n − 16` formula. Real cell heights vary widely with
launcher and screen, so on some launchers a 4×2 was computed as 3 cells and received the 232dp tall
layout, which overflowed — and that reads as "4×2 is broken" too. It now compares **dp directly**:
the tall layout only applies at 240dp or more. The reasoning is plain — whether the tall layout fits
is a dp fact (its content is 232dp / 215dp), and a nominal 3 cells is only 206dp, so it never fit
in the first place.

## [1.6.133] - 2026-09-19

### ↔️ 短波与系统状态组件支持缩放了；拉高自动换「加高档」

三个桌面组件里，只有**天气**原来能拖拽缩放，**短波**与**系统状态**是
`resizeMode="none"`（固定尺寸）。这一版把它们也打开，并各多做一个
**「加高档」布局**。

**为什么是「分档」而不是真的按比例缩放**

RemoteViews 没有百分比布局，能按比例设高的 `setViewLayoutHeight` 又要 API 31+
（本项目 minSdk=24）—— 所以只能像天气组件那样分档。这不是偷懒，是平台限制。

**横向：本来就能自适应**

两条进度条用的是 `weight`（等分），所以拖宽时它们自己就跟着变宽，无需第二套
代码。真正要防的是「拖太窄」：波段名 56dp + 两段 + 档位块 48dp 一旦挤不下，
最先被牺牲的就是波段名 —— 所以最小宽度卡在内容放得下的地方：
短波 200dp、系统状态 170dp。

**纵向：高度够时换「加高档」**（判档见 v1.6.134 的修正）

| | 标准档（4×2） | 加高档（4×3+） |
|---|---|---|
| 短波 | 157dp，条高 18dp，提示 1 行 | 232dp，条高 24dp、字号上一档、提示 **2 行** |
| 系统状态 | 138dp | 215dp，字号上一档、状态点变大、各区块拉开 |

两档的差别不是「把所有间距乘个倍数」（那样只会显得松散）：
- **短波**把多出来的高度都用在**信息量**上 —— 条变粗、提示多一行；
- **系统状态**没有「可以多给的内容」（它四段各自独立，硬塞新内容会变成另一张表），
  所以把高度用在**可读性**上。

**最小尺寸**

> ⚠ 这里原来写的是「卡在内容放得下的下限」（短波 150dp / 系统 125dp）——
> **那是错的，而且直接把 4×2 弄没了**：`minResizeHeight`（用户最少能拖到多小）
> 被写成比组件自己的默认高度（`minHeight` 110dp）还大，等于宣告「默认的 4×2
> 低于下限」，启动器于是拒绝落位、或强行撑大。**已在 v1.6.134 修正**，见该条。

**实现上只改了一处**

两档布局**共用同一套 id**（只有 dp 值不同）—— 所以 Provider 只换一个 layout
资源，ResId 表两档通用。少一张表就少一处「改了一档忘了改另一档」。

顺带把「波段名放得下」的回归测试扩到**两档都查**：加高档字号 10.5sp、列宽 68dp，
只查标准档是不够的 —— 而它的表现同样是「波段名被截掉」。

---

**The HF and system-status widgets can now be resized, with a taller layout when you drag them bigger.**

Of the three widgets only **weather** could be dragged to a different size; **HF** and **system status**
were `resizeMode="none"` (fixed). This release opens them up and adds a **tall layout** to each.

**Why tiers rather than true proportional scaling**

RemoteViews has no percentage layout, and `setViewLayoutHeight` (which could scale a height
proportionally) requires API 31+ — this project's minSdk is 24. So tiers are the only option, exactly as
the weather widget already does it.

**Horizontal: it already adapts**

The two progress bars use `weight`, so they widen on their own when the widget does. What actually
needs guarding is dragging it *too narrow*: band name 56dp + two segments + a 48dp level block —
when that stops fitting, the band name is the first thing sacrificed. The minimum widths are therefore
pinned to what the content needs: 200dp (HF) and 170dp (system status).

**Vertical: switches to the tall layout when there is enough height** (threshold fixed in v1.6.134)

| | standard (4×2) | tall (4×3+) |
|---|---|---|
| HF | 157dp, 18dp bars, one tip line | 232dp, 24dp bars, type up a step, **two** tip lines |
| System status | 138dp | 215dp, type up a step, larger status dots, sections spread out |

The difference is not "multiply every gap by some factor" (that just looks loose): HF spends the extra
height on **information** (thicker bars, a second tip line), while system status has no extra content to
show — its four sections are already distinct, and forcing more in would make it a different widget —
so it spends the height on **legibility**.

**Minimum size**

> ⚠ This originally read "pinned to what the content needs" (150dp for HF, 125dp for system
> status) — **that was wrong, and it removed the 4×2 size entirely**: `minResizeHeight` (the
> smallest the user may drag to) was declared *larger* than the widget's own default height
> (`minHeight`, 110dp), announcing that the default 4×2 sits below the floor, so the launcher
> refused to place it there or forced it larger. **Fixed in v1.6.134** — see that entry.

**Only one thing changed in the implementation**

The two layouts **share the same set of ids** (only the dp values differ), so the provider just swaps one
layout resource and the ResId table serves both tiers. One less table means one less "updated one tier,
forgot the other".

The regression test for "band names fit" now checks **both tiers**: the tall one uses 10.5sp type and a
68dp column, and checking only the standard tier is not enough — it fails the same way (a truncated
band name).

## [1.6.132] - 2026-09-18

### 📊 短波组件：**亮的是白天、暗的是晚上**；图标进条、条加高

改三件事，都来自一个反馈：「亮暗反了，而且条看着太瘦」。

**① 亮度改回表达「时段」，不再表达「现在」**

上一版是「当前时段实色、另一段淡底」—— 于是**夜里那一段反而最亮**，
而白天段是淡的。这确实反直觉：人对亮暗的第一反应是「日/夜」，不是「现在」。

现在：**白天段恒亮（满色）、夜晚段恒暗（压暗）**。「现在」改由段内顶部
的小白点表出（每行两个点，只亮当前那一个）。

把「白点」与「明暗」拆开还有一个实际好处：以前的 drawable 要同时编码
「档位 × 昼夜 × 是否当前」（4×2×2 = 16 张/主题），现在只编码「档位 × 昼夜」
（4×2 = 8 张），白点交给一个独立 ImageView 控可见性。

**② 太阳 / 月亮搬进条里**

原来两个图标贴在条外侧，白占宽度、还要在运行时染色（`setColorFilter`）。
搬进条内之后：宽度让给了条本身，而底色是满色或压暗色，**白图在两者上都够清楚，
于是不再需要染色** —— 少两个颜色资源、少两处只在运行期才爆的 `setInt`。

**③ 条高 13 → 18dp**

原来四行加起来只有 52dp，整块显得空。提到 18dp（四行 72dp），
再把几处 4/3dp 的间隔各收 1dp —— 总高 157dp，仍在 4×2 的内容预算内。

**顺带**

- 右端的「当前档位」块与 6m 格改用**压暗底 + 白字**。它们在语义上是**读值**
  而不是「时段」，所以不跟昼夜明暗走；而亮底上的白字对比度不够
  （fair 的橙 #D97706 只有约 2.9:1），压暗底 + 白字对四个档位都稳。
- 生成器新增一条**语义自检**：按 BT.601 算亮度，**白天段必须比夜晚段亮 24 以上**。
  写反了会直接报错，而不是等装到真机才发现又反了（已反向验证过会报红）。
- 删除已死的 `aw_seg_*` / `aw_segnow_*` / `aw_sun` / `aw_moon`。

---

**HF widget: bright means day, dark means night; icons moved inside the bars; bars are taller.**

Three changes, all from one piece of feedback: "the bright/dark is backwards, and the bars look too thin."

**① Brightness now encodes the *time slot*, not *now***

The previous version made the *current* slot solid and the other one pale — which left the **night
segment as the brightest thing on the card** while the day segment was washed out. That is backwards:
peoples' first reading of light vs dark is day vs night, not "now".

Now the **day segment is always bright (full colour) and the night segment always dark (dimmed)**.
"Now" moved to a small white pip at the top of whichever segment applies (two pips per row, only one lit).

Separating the pip from the shading also pays off concretely: the drawables used to encode
*level × slot × is-now* (4×2×2 = 16 per theme) and now encode only *level × slot* (4×2 = 8), with the pip
handled by a separate ImageView whose visibility the widget controls.

**② Sun and moon moved inside the bars**

They used to sit outside, taking width and needing a runtime tint (`setColorFilter`). Inside the bar they
no longer consume outside width, and because the fill is either full colour or dimmed, **white glyphs are
legible on both — so the tint is gone**, along with two colour resources and two runtime-only `setInt` calls.

**③ Bars grew from 13dp to 18dp**

Four rows used to total only 52dp, which left the card looking empty. At 18dp they total 72dp, with a few
4/3dp gaps trimmed by 1dp each — 157dp overall, still inside the 4×2 content budget.

**Also**

- The right-hand "current level" block and the 6m cell now use a **dimmed fill with white text**. They are
  readings rather than time slots, so they deliberately do not follow the day/night shading; and white on a
  bright fill does not have enough contrast (fair's orange #D97706 is about 2.9:1), whereas a dimmed fill is
  safe across all four levels.
- The generator gained a **semantic check**: luminance (BT.601) of the day segment must exceed the night one
  by at least 24. Getting it backwards now fails the build instead of shipping and being noticed on the
  device (verified by deliberately inverting it — it does fail).
- Dead `aw_seg_*` / `aw_segnow_*` / `aw_sun` / `aw_moon` removed.

## [1.6.131] - 2026-09-18

### 🧩 三块桌面组件都不再「下面空空的」；天气主区不再挤

三块组件各自补上一行真正有用的信息，顺带把天气主区「上挤下空」的成因修掉。

**① 短波组件：底部加「通联提示」**

读完「哪个波段好」之后的下一步是「那我该干什么」，所以表下加一行提示：
圆点 + 级别图标 + 级别 + 一句话。文案**复用 `hfTips()`**（与 App 内面板的
「业余无线电建议」同一个来源）—— 组件上一眼看到的那句话，点进 App 也找得到；
两处各写一份文案，迟早会出现「组件说 A、面板说 B」。

取**排序后的第一条**（`hfTips` 内部已按「安全警示 > 注意 > 通联机会 > 操作提示」
排好）：4×2 只放得下一行，而再挤就要从波段表里拿地方，而波段表是这个组件的主语。

颜色用**基准色**而不是给天气组件用的提亮色 —— 提亮 35% 是「压在彩色渐变上」的
补偿，本组件是白底，提亮色会淡到看不清。此刻没有值得说的时候**整行收起**。

**② 天气组件：修「上部分挤、下部分空」**

根因是天气主区与 3 格指标**并排**：主区只拿到约一半宽，而 `hero()` 内部本来就是
按「占满整行」设计的（温度 + 弹性空隙 + 靠右的天气现象/高低温）—— 被压到一半宽
之后，现象与高低温紧贴在温度右边，右半边又竖着三格指标，整块看上去就是「上面挤」。

改成**主区独占一行、指标单独一行**后：温度与现象分列两端，指标三格摊平到
整行宽度，下半部分也不再空。代价是多花约 17.5dp，从几处 6dp 间隔里收回，
实测总高 148dp（预算 160dp）。

**③ 系统状态组件：底部加「最近收到」**

原来底部只有「收 N / 发 N / 信标 / 台站」这排计数，下面空一截。补的一行是
「最近收到 <呼号> …… 多久前」。

为什么是这一行而不是再堆一个计数：**它比「收 N」更直接地回答「还在收吗」**——
计数只说明「一共收过多少」，链路卡住时计数是不动的，用户从计数上看不出异常；
而「最近收到谁、多久前」说明此刻还在不在收。没有台站时**整行收起**，
不留一个「最近收到 · 」的空壳（空壳会让人以为组件坏了）。

「多久前」复用仓库既有的 `secondsAgo / minutesAgo / hoursAgo / daysAgo`，
**与 `packets_page.dart` 同一套分档** —— 同一个时间在两个界面上说法不同
（「45分前」与「0小时前」并存）是最容易被截图吐槽的。

**共同项**

- 「现在」时段仍由原生按本机时钟判断（阈值随快照下发），不受组件 30 分钟
  自刷新周期的限制；
- 圆点与级别图标都是 ImageView + `setColorFilter` 染色 —— 该方法**只存在于
  ImageView**（v1.6.114 的线上事故就是把 TextView 当圆点用）；
- 三块组件的内容高实测：天气 148dp、短波 153dp、系统状态 129dp，均在 160dp 预算内。

---

**All three desktop widgets now put something useful in the space they were wasting, and the weather widget's cramped top half is fixed.**

**① HF widget: a propagation tip under the band table**

After "which band is good", the next question is "so what do I do" — hence one line with a dot,
a level icon, the level, and a sentence. The text **reuses `hfTips()`**, the same source as the
in-app panel's "amateur radio advice", so the line you see on the widget is the same one you can
find inside the app. Two copies of that copy would eventually drift into "the widget says A, the
panel says B". The **first tip after sorting** is used (`hfTips` already orders them
safety warning > caution > opportunity > operating note): a 4×2 fits one line, and squeezing in more
would take space from the band table, which is this widget's subject.

Colours use the **base** values rather than the lightened ones used by the weather widget — that
+35% lightening compensates for sitting on a coloured gradient, and on this widget's white ground it
would be too pale to read. When there is nothing worth saying, the **row is hidden entirely**.

**② Weather widget: the cramped top half**

The cause was that the hero area and the three metrics sat **side by side**: the hero got only about
half the width, while `hero()` is internally designed to span the whole row (temperature, a flexible
spacer, then condition/high-low right-aligned). Squeezed into half a row, the condition and high/low
hugged the temperature while three stacked metrics occupied the right half — which reads as a
cramped top. Splitting them into **a hero row and a metrics row** puts the condition at the opposite
end of the temperature and spreads the metrics across the full width, so the bottom half is no longer
empty either. It costs about 17.5dp, clawed back from several 6dp gaps; the real content measures
148dp against a 160dp budget.

**③ System status widget: a "last heard" row**

Previously the bottom held only the counters (Rx / Tx / beacon / stations), leaving a stretch of
empty space. The added row reads "last heard <callsign> … <how long ago>".

Why this and not another counter: **it answers "am I still receiving?" far more directly than
"Rx N"**. A counter only says how many have arrived in total, and when a link stalls the counter
simply stops moving — you cannot tell from it. "Who was heard most recently, and how long ago"
does tell you. With no stations yet the **row hides entirely** rather than showing an empty
"last heard ·" shell, which would look like a broken widget.

The relative time reuses the existing `secondsAgo / minutesAgo / hoursAgo / daysAgo`, **the same
buckets as `packets_page.dart`** — the same interval described differently on two screens ("45 min
ago" next to "0 h ago") is the kind of thing that gets screenshotted.

**In common**

- The current day/night slot is still resolved natively from the device clock (thresholds downlinked
  in the snapshot), so it is not limited by the widget's 30-minute self-refresh.
- The dots and level icons are ImageViews tinted with `setColorFilter`, which **only exists on
  ImageView** (the v1.6.114 outage was a TextView used as a dot).
- Measured content heights: weather 148dp, HF 153dp, system status 129dp — all within the 160dp budget.

## [1.6.130] - 2026-09-18

### 📊 短波组件再重做：每个波段一条「日 → 夜」进度条，一眼看出**现在**该用哪段

上一版（条件色带）虽然解决了同形状药丸堆叠的问题，但还剩两件要用户自己做的事：
**① 波段名被挤掉** —— 列宽 46dp 放不下 9sp 加粗的 `12m/10m`（实测 42.0dp），平时
刚好、系统字体一放大（Android 上限 1.3 倍 → 需 55.3dp）就被截成 `12m/1…`；
而「这是哪个波段」是整块的**前置信息**，它没了其余都白搭。
**② 还得心算「现在该看日间那列还是夜间那列」** —— 而「现在」正是这个组件要回答的问题。

**新结构：每波段一条两段条，左 = 日间、右 = 夜间（顺序即时间顺序）**

`[波段名 56dp][☀][日间段][夜间段][☾][当前档位]`

- **当前时段那一段是实色 + 顶部一颗小白点**，另一段是淡底 —— 三重提示（色调 + 白点
  + 右端档位）都落在「现在」上，不靠用户读字；
- 两端用**太阳 / 月亮图标**标注时段语义（图标用 `setColorFilter` 染色 —— 那是
  ImageView 才有的方法，v1.6.114 的事故就是把 TextView 当圆点用）；
- 右端档位块给的是**当前时段**的档位（好 / 一般 / 差），不再需要横向对照两列；
- 顶栏标题右侧直接写「**现在 日间 / 现在 夜间**」。

**「当前时段」由原生按本机时钟判断**（阈值随快照下发：`dayFrom` / `dayTo`）

组件每 30 分钟自刷新时只重绘已存的快照。若把「现在算日间还是夜间」在 Dart 侧**算死**，
用户一整天不开 App 就会出现「19:00 之后组件还指着日间」。所以规则只在 Dart 定义一处
（`hfIsDaytime()` + `kHfDayFromHour/ToHour`），Kotlin 只用不猜。

这次顺带把它收成了**唯一判据**：此前 `07:00–19:00` 这个表达式在文件里抄了**两遍**
（`bestBandAt` 与建议生成各一份），多一个调用方就多一处漂移的地方 —— 而漂移的表现是
「面板说 20m 好、组件游标却指在日间」，最难解释的那种不一致。

**回归护栏**

- `波段名放得下，且留出系统字体放大（1.3 倍）的余量` —— 这条盯的正是上面那个 bug。
  预览工具画文字**不裁切**，所以那版预览看不出来，只能靠断言；
- `level 名落在 Kotlin 认识的集合里`：契约是**等级名**而不是色值，认不出会回退灰底；
- 跨语言契约测试新增 `nowPrefix` / `dayFrom` / `dayTo` —— 少了任一个，组件会渲染成
  「 夜间」（前缀空）或永远算作日间；
- 真布局内容高度 **135.00dp**，比上一版（158.67dp）还矮 23.67dp，不会溢出。

**顺带**：新增 `hfNow` 文案（6 种语言）；`aw_track_*` 等上一版的条件色带资源已随本版删除。

---

**The HF widget was rebuilt again: one 「day → night」 bar per band, so you can see at a glance which half applies *now*.**

The previous version (condition tracks) fixed the eight-identical-pills problem but left two things to the user:
**① band names were truncated** — the 46dp column could not hold `12m/10m` at 9sp bold (measured 42.0dp);
that fits at the default font size, but Android allows up to 1.3× scaling (→ 55.3dp needed), which clipped it
to `12m/1…`. "Which band is this" is the widget's *premise*, so losing it makes the rest useless.
**② you still had to work out whether to read the day or the night column** — and "now" is precisely the
question this widget exists to answer.

**New structure: one two-segment bar per band, left = day, right = night (the order is chronological)**

`[band name 56dp][☀][day segment][night segment][☾][current quality]`

- **The segment for the current part of the day is solid with a small white pip at its top**, the other is a
  pale fill — three cues (tint, pip, and the right-hand block) all point at "now", none of which requires
  reading text.
- **Sun / moon icons** at the two ends carry the time-of-day semantics (tinted via `setColorFilter`, which
  only exists on ImageView — the v1.6.114 outage was a TextView used as a dot).
- The right-hand block shows the quality of the **current** slot only, so there is no more scanning two
  columns against each other.
- The header states 「现在 日间 / 现在 夜间」 ("now: day/night") right next to the title.

**The current slot is resolved natively from the device clock** (thresholds downlinked in the snapshot as
`dayFrom` / `dayTo`). The widget redraws the stored snapshot every 30 minutes, so if Dart decided "day or
night" up front, a user who never opens the app would see the widget still pointing at daytime after 19:00.
The rule is therefore defined in exactly one place in Dart (`hfIsDaytime()` with
`kHfDayFromHour`/`kHfDayToHour`) and Kotlin only consumes it.

This change also collapses it into the **single predicate** it should always have been: the `07:00–19:00`
expression had been duplicated (once in `bestBandAt`, once in tip generation), and every extra caller is
another place to drift — drift that shows up as "the panel says 20m is good while the widget's pip points at
daytime", the least explicable kind of inconsistency.

**Regression guards**

- `band names fit, with headroom for 1.3× system font scaling` — this targets exactly the bug above. The
  preview tool does not clip text when drawing, so that version's preview could not reveal it; an assertion
  can.
- `level names fall inside the set Kotlin knows`: the contract is the *level name*, not a colour value, and
  an unknown level falls back to grey.
- The cross-language contract test now also covers `nowPrefix` / `dayFrom` / `dayTo` — missing any one of them
  makes the widget render " night" (empty prefix) or treat every hour as daytime.
- The real layout measures **135.00dp** tall, 23.67dp *shorter* than the previous version (158.67dp), so there
  is no overflow.

**Also**: new `hfNow` string in six languages; the previous version's `aw_track_*` resources are removed.

## [1.6.129] - 2026-09-18

### 🎛️ 短波桌面组件重做：从「八个药丸」改为「条件色带」

短波组件的逐波段表重新设计。上一版（淡色 tonal chip）的问题集中在一处：**8 个同形状、
同大小的淡色药丸**——而「一般」一行内出现 3 次、「差」4 次，重复的图形不承载额外信息，
只堆噪声；加上 4 行完全同构、没有层次，整块看起来像把一张表直接倒上去，
波段名与第一个色块之间还横着约 40dp 空档，横向扫视要跨很远。

**新结构：每行一条「条件色带」**

- 色带**横贯整个日/夜列**（行的宽度就是列宽）——中段空档消失，扫视距离降到最短；
- 颜色集中到色带**左端一道 2.5dp 色标**：四行扫下来是一条竖线，像仪表的指示列，
  而不是 8 个孤立色块；
- 档位文字就在色带内**左端**（紧挨色标），颜色与它说明的对象在同一处，不用跨空档去对；
- 「日间 / 夜间」列头与色带左边缘**同一条竖线**（靠等分列实现，不靠调 margin）。

**6m 段一起收拾**

原来 6m 在「没有开通」时整格隐藏。改成**常驻**：没有开通时显示一个灰色的 `--`，
并在前面补上「6m」这个说明文字。理由有两条：

1. 「6m 没开通」本身就是**常态且有信息量**（开通是例外），隐藏等于把这个信息也藏了；
2. 一个时有时无的格子在组件里会造成**宽度跳变**，反而更显眼。

格子同时从 44dp 放宽到 46dp —— 原来容不下最长的档位词（印尼语的 `Tertutup` 约 38dp），
会被省略号截掉。

**实现：色带是一张 layer-list，每格仍只是一个 TextView**

色带 = 淡色圆角底（14%）+ 左端实色竖标，两层合成一张 `layer-list` drawable
（`aw_track_{good,fair,poor,closed}`）。这样每格仍然只是**一个 TextView**，
靠 `setBackgroundResource` 换色带、`setTextColor` 换字色 —— 两个方法在
`View`/`TextView` 上都确实存在。

若改成「淡底容器 + 一个 2.5dp 的子 View」，就要多一个控件、多一个 id、多一行
`setBackgroundResource`，而 RemoteViews 不允许原生 `<View>`（色标只能用
TextView/ImageView 冒充）——每个都是**只在运行期才爆**的地方。

夜间档的淡底从 14% 提到 22%：深底上 14% 几乎看不见。这一条现在是**生成时自检**：
夜间不透明度必须大于白天，写反了会直接报错，而不是等你到夜间模式才发现色带隐形。

**顺带修掉一个只在夜间第一帧出现的问题**

`drawable-night/aw_bg_white.xml` 此前**不存在**（只有浅色版）。组件在夜间模式的
第一帧（`initialLayout`）会退落到默认主题底色，约 200ms 后才被推送的渐变盖住。
影响很小，但既已发现就补上，免得以后有人把它当「night 目录里都有一份」的前提去用。

**预览工具：这一档的高度数字此前并不对应真机**

短波组件按真布局逐项累加是 **162dp**，而预览工具一路报的是 **126.3dp** —— 它按自己
理想的尺寸算，既没算顶/底内边距，也把色块高度取成了 14dp（真布局是 13+3+3=19dp）。
也就是说这一档的「余 3.7dp」是个**看上去很安全、其实无从对应**的数字。

现在改为按真布局的几何累加，并把判据换成**相对基线**：内容不得高于已发布版本
（162.00dp）。因为 4×2 表类组件实际能拿到多少高度取决于启动器，拿固定值当阈值只会
产生误报，而误报会让人干脆放宽规则。新布局实测 **158.67dp**，比线上版本还矮 3.33dp。

---

**The HF desktop widget was rebuilt: eight pills became condition tracks.**

The previous version (pale tonal chips) had one dominant problem: **eight pills of identical
shape and size** — with 「一般」 appearing three times and 「差」 four times, the repeated shapes
carried no extra information, only noise. Combined with four identical rows and no hierarchy,
the whole thing read as a table dumped onto the widget, and there was a ~40dp gap between a band
name and its first chip, so scanning meant travelling a long way sideways.

**New structure: one condition track per row**

- The track spans **the full day/night column** (row width = column width), so the mid-row gap is
  gone and the scan distance is minimal.
- Colour is concentrated into a **2.5dp bar at the track's left edge**: across four rows that reads
  as a single vertical indicator line rather than eight isolated blocks.
- The condition text sits at the **left inside the track**, right next to the bar, so the colour and
  the thing it describes are in the same place.
- The day/night column headers share **the same x** as the track's left edge (via equal-weight
  columns, not by tuning margins).

**The 6m cell was reworked too**

It used to hide entirely when 6m was closed. It is now **always present**, showing a grey `--` when
closed, with a 「6m」 label in front. Two reasons: "6m is closed" is itself the common case *and*
informative (being open is the exception), so hiding it hides information; and a cell that comes and
goes makes the row width jump, which draws more attention, not less. The cell also grew from 44dp to
46dp — 44dp could not hold the longest condition word (Indonesian `Tertutup`, ~38dp) and truncated it.

**Implementation: the track is one layer-list; each cell is still a single TextView**

A track is a pale 14% rounded fill plus a solid bar at the left edge, combined into one
`layer-list` drawable (`aw_track_{good,fair,poor,closed}`). Each cell therefore remains **one
TextView**, recoloured with `setBackgroundResource` and `setTextColor` — both of which really do
exist on `View`/`TextView`. The alternative (a pale container plus a 2.5dp child View) would need
another control, another id and another call, and RemoteViews forbids a native `<View>` (the bar
could only be a TextView/ImageView stand-in) — each of those is a **runtime-only** failure mode.

The night variant's fill goes from 14% to 22%, since 14% is nearly invisible on the dark surface.
That is now a **generation-time check**: night opacity must exceed the day value, so getting it
backwards fails the build instead of only showing up when the user switches to dark mode.

**A bug that only appeared in night mode's first frame**

`drawable-night/aw_bg_white.xml` did not exist (only the light version did). In night mode the
widget's first frame (`initialLayout`) fell back to the default theme colour for ~200ms until the
pushed gradient replaced it. The impact is small, but since it was found it is fixed, rather than
leaving a "the night folder has a copy of everything" assumption for someone else to trip over.

**The preview tool's height figure for this size never matched the device**

Accumulating the real layout gives **162dp** for the HF widget, while the preview tool kept
reporting **126.3dp** — it summed its own ideal sizes, ignoring the top/bottom padding and taking
the chip height as 14dp (the real layout is 13+3+3=19dp). So this size's "3.7dp to spare" was a
number that **looked safe but corresponded to nothing**. The tool now accumulates the real layout's
geometry and judges against a **relative baseline** instead: the content may not exceed the
previously released version (162.00dp). How much height a 4×2 table widget actually receives
depends on the launcher, so a fixed threshold only produces false alarms — and false alarms are
what make people stop trusting the check. The new layout measures **158.67dp**, i.e. 3.33dp shorter
than the released one.

## [1.6.128] - 2026-09-18

### 🗺️ 离线地图：按区域下载瓦片，断网也能看

新增「离线地图」：**所见即所得地框选一片区域 → 一次把该区域的瓦片下到本机 → 之后断网、无信号也能看这片地图**。入口在「设置 → 显示 → 离线地图」（数据设置页也有入口）。

**下载**

- **下载范围 = 当前视图**：不画可拖拽的矩形框，而是把屏幕上看得见的那一屏当作下载范围（带边框提示）。
  这样就没有「框选坐标系」与「下载坐标系」两套真值，不会出现「框选范围和实际下到的范围差半屏」这种最难解释的错。
- 可调图源与层级范围（0–19 级），实时显示**张数与估算体积**；
- 单区域上限 **20 万张瓦片**（约 3 GB）。超限直接拒绝并提示缩小范围 —— 这不是防呆：
  再大一次要跑几小时，中途失败的概率比成功高；
- **断点续传**：已存在的瓦片直接跳过，任何时刻中断（含被系统杀掉）都能接着下；
- 并发 6 张、限速 20 张/秒；命中 429/503 时按失败次数**退避**（上限 30 秒）。
  限速是必需的：被限流之后的重试会让请求速率更高，这是个正反馈，必须从源头掐住；
- 暂停 / 取消在**每张瓦片之间**生效，点下去立刻停，不用等几百张；
- 同时只跑一个区域。瓦片下载的瓶颈是共享的图源与带宽，并行下多个区域只会每个都变慢，
  还会让「暂停」的语义变得含糊。

**离线显示的四级降级**

在线瓦片与离线瓦片走**同一份**图源定义与 URL 构造函数（`lib/map_math.dart`）。两处各写一份迟早会
漂移成「下载得到的和显示要的不是同一张图」——这是「下好了却离线看不到」最常见的成因。渲染时按
以下顺序取图：

1. **缓存**（下过离线区域，或之前浏览过）→ 断网也能看；
2. **在线**（顺带写缓存）；
3. **祖先瓦片放大**：只下到 z16、现场缩到 z17 时，用最近的祖先瓦片**按象限裁切**放大顶替。
  裁切是必须的：整张祖先图直接铺进本格会看到**邻居**的地图，位置全错，比空白更糟；
4. **其它同坐标系图源的缓存** → 再不行就透出内置自绘底图，地图仍可看可点。

在线降级候选（当前图源 → Carto → OSM）**只接受同坐标系的图源**：拿 WGS-84 的图去填 GCJ-02 的瓦片
会整整偏出 500 米，比留白更容易把人带错路。

**几个不写就会出事的地方**

- **缓存键含图源**。同一组 z/x/y 在不同图源下是不同内容的图；共用一份缓存会让「切换图源」静默显示
  上一个图源的瓦片；
- **命中也要认字节**：只接受已知图片魔数（PNG/JPEG/GIF/WebP/BMP），挡掉 status 200 的 HTML/JSON
  错误页；小于 300 B 的响应按「占位图」判失败不入库 —— 有的图源对不存在的瓦片返回一张很小的
  全透明 PNG，存下来会让这块区域**在线时也一直空白**，比不缓存更坏；
- **国内图源是 GCJ-02 瓦片**：下载范围必须先把 WGS-84 转成 GCJ-02 再算瓦片编号，否则整片偏移 500 米以上；
- **元数据与瓦片分家**：区域记录（KB 级）存偏好设置，瓦片（几十 MB 的二进制）只存文件系统。
  瓦片塞进偏好设置一开始能用，攒到几百 MB 时会以「读设置越来越慢」的形式表现出来，最后写不进去直接丢新记录；
- **进度落盘要节流**（2 秒 / 3 秒一次）。一张瓦片写一次等于在一次下载里做几万次磁盘写 + JSON 编码；
- 写盘走**临时文件 + 改名**，下载途中断电不会留下半张能被解码一半的坏图；
- 删除某个区域时**逐张删**它范围内的瓦片，不按「图源/层级」整目录删 —— 后者会顺手删掉邻居区域
  已下载的瓦片，属于「删一个区域、坏另一个区域」的隐形破坏。

**开关**

- **浏览时缓存瓦片**（默认开）：关掉后浏览完全不落盘；
- **仅离线模式**（默认关）：只用已缓存/已下载的瓦片，一个网络请求都不发（野外省流量），界面上会明确提示。
- 占用统计与「清空缓存」；区域可「删除记录但保留瓦片」或「连瓦片一起删」。
- **Web 版不提供离线下载**：浏览器没有稳定的应用可写目录，整条链路安全降级为不可用（入口隐藏、
  读取一律未命中回落到在线瓦片），而不是抛错让地图整块白屏。
- 区域记录随「设置」分组进备份；瓦片本体不随备份走（几十 MB 级），换机后记录还在，点「继续」即可重新下。

**顺带修复**

6m（六米波）在中文界面里露英文：短波面板的三条通路与桌面组件下发的是图源**原始串**
（`Band Closed` / `Good`…），漏了本地化这一步 —— 而 `Band Closed` 恰是 6m 最常见的取值，
等于长期露英文。现已统一过 `hfQualityLabel`。同时：**三条通路全为「未开通」时不再连列三行同一个词**
（开通是例外、不开通是常态），只在某条开通时才展开细节。

---

**Offline maps: download tiles by region and keep them when the network is gone**

A new "Offline map" screen (Settings → Display → Offline map; there is also an entry in Data settings) lets you
**download the tiles of an area once and keep viewing that map with no network at all**.

**Downloading**

- **The download area *is* the current view**: no draggable rectangle — whatever is visible on screen is what
  gets downloaded (with a border to say so). That removes the second source of truth for coordinates, and with it
  the "the box I drew and the area that was downloaded are half a screen apart" class of bug.
- Choose the tile source and the zoom range (0–19) with a live **tile count and size estimate**.
- A single region is capped at **200,000 tiles** (~3 GB). Over that it is refused with a hint to shrink the area:
  such a run takes hours, and failing partway is likelier than finishing.
- **Resumable**: tiles that already exist are skipped, so an interruption at any point (including the process
  being killed) can be resumed.
- 6 concurrent tiles, 20 tiles/second, with **backoff** on 429/503 (up to 30 s). The rate limit matters: retries
  after throttling only raise the request rate — a positive feedback loop that has to be capped at the source.
- Pause/cancel take effect **between tiles**, so they stop immediately instead of after a few hundred more.
- One region at a time. The bottleneck is the shared tile source and bandwidth, so parallel regions would only
  make each of them slower and blur what "pause" means.

**Four-step fallback when rendering**

Online and offline tiles share **one** tile-source definition and URL builder (`lib/map_math.dart`). Two copies
would eventually drift into "what was downloaded is not what is displayed", the most common cause of
"it downloaded but I still can't see it offline". Tiles are resolved as: **cache** (downloaded region, or seen
before) → **online** (also writing to cache) → **upscaled ancestor tile** → **cache of another source with the
same datum** → the built-in vector basemap.

The ancestor step is what makes "downloaded up to z16" usable while viewing z17: the nearest ancestor is
**cropped by quadrant** and upscaled. Cropping is not optional — pasting the whole ancestor into the cell would
show the *neighbour's* map, which is far worse than blank.

Online fallbacks (current source → Carto → OSM) only accept sources with the **same datum**: filling a GCJ-02
tile with a WGS-84 image shifts it by 500 m, which misleads more than a blank tile does.

**Details that break if done differently**

- The cache key **includes the source** (same z/x/y is a different image per source).
- A cache hit still validates the bytes: only known image magic numbers are accepted (PNG/JPEG/GIF/WebP/BMP),
  which rejects `200 OK` HTML/JSON error pages; responses under 300 B count as placeholder images and are not
  stored — some sources answer missing tiles with a tiny fully transparent PNG, and storing it would keep that
  area **blank even online**, worse than not caching at all.
- Chinese sources serve **GCJ-02** tiles, so the WGS-84 area is converted before tile numbering; otherwise the
  whole region is off by more than 500 m.
- **Metadata and tiles are kept apart**: region records (KB) live in preferences, tiles (tens of MB of binary)
  only on the filesystem. Tiles in preferences appear to work at first, then surface as "settings get slower"
  once a few hundred MB have accumulated, and finally fail to save, silently dropping new records.
- Progress saving is **throttled** (every 2–3 s); one write per tile means tens of thousands of disk writes and
  JSON encodings per download.
- Writes go through a **temp file + rename**, so a power loss mid-download cannot leave a half-decodable image.
- Deleting a region deletes **its own tiles one by one**, never the whole `source/zoom` directory, which would
  silently damage neighbouring regions.

**Switches**

- *Cache tiles while browsing* (on by default); when off, browsing writes nothing to disk.
- *Offline only* (off by default): use cached/downloaded tiles exclusively and send no requests at all
  (saves data in the field), clearly indicated in the UI.
- Usage statistics, "clear cache", and per-region *remove record but keep tiles* / *delete tiles too*.
- **No offline download on Web**: browsers have no stable writable app directory, so the whole chain degrades
  safely (entry hidden, lookups miss and fall back to online) instead of throwing and blanking the map.
- Region records travel with the *settings* backup group; the tiles themselves do not (tens of MB), so after
  switching devices the records are still there and "Resume" re-downloads them.

**Also fixed**

6 m band text leaked English into non-English UIs: the HF panel's three paths and the desktop widget shipped the
**raw** source strings (`Band Closed`, `Good`, …) without localisation — and `Band Closed` is by far the most
common 6 m value, so it leaked permanently. They now go through `hfQualityLabel`. In addition, when all three
paths are closed they are no longer listed as three rows of the same word (closed is the norm, open the
exception); the details expand only when something is open.

## [1.6.127] - 2026-09-18

### 🎛️ 更高自定义：更多令牌、界面松紧与字体、分页签强调色、背景对齐缩放

上一版把「颜色 / 图标 / 文字 / 背景图」都开放了，但界面里还有一批**写死**的东西：
次级面板底色、较重的描边、弹窗遮罩、8 张设置入口卡片各自的渐变、卡片表面
不透明度、每张卡片的留白 —— 改完主色后仍会看到「有些地方还是原来的样子」。
这一版把这些也交出来，并给皮肤补上身份信息。

**① 新增 5 个颜色令牌（共 17 个）**

`surfaceAlt`（次级面板底色）、`dividerStrong`（较重描边）、`scrim`（遮罩）、
`accentFrom` / `accentTo`（强调渐变）。

**② 8 张设置入口卡片的渐变不再写死**

原先每张卡片自带一组渐变（8 组互不相同）。现在皮肤可以打开「统一入口卡片配色」，
把它们换成同一套 from→to；**默认关闭**，所以不装皮肤的界面与旧版逐像素一致。

实现上只把 6 处写死渐变换成 `C.accentDeco(fallback: …)`：`fallback` 就是该卡片
原本的配色，未开启统一时原样使用。这样「默认零回归」是结构性保证，而不是靠人工核对。

开启统一但没给渐变时，强调色**跟随主色**推导 —— 否则用户刚把主色改成绿色，
卡片却仍是内置的蓝。

**③ 卡片表面不透明度可调（0.3 ~ 1.0）**

原来写死 0.85。下限卡在 0.3：再低就等于把内容交给背景图了。没有背景图时，
这一项下面会说明「暂时看不出效果」，而不是让用户以为坏了。

**④ 界面松紧与字体**

- **松紧**：紧凑 0.85 / 标准 1.0 / 宽松 1.2，作用于共用辅助函数算出来的留白
  （卡片内边距）；
- **字体**：跟随系统 / 系统界面字体 / Segoe UI / PingFang SC / Microsoft YaHei /
  Noto Sans / 等宽。

字体**只用系统已装的**：内置一款中文字体动辄 5~10MB，而本应用的包体已经因为
图标库与 SVG 涨过一轮。因此选项里标注了它依赖的字体名，并明确写了「缺失时自动回退」——
Flutter 找不到字体族会正常回退，不会出现方框或乱码。

两处都如实说明了作用范围：密度「只改卡片内边距，没变的说明那处是单独写死的」、
字体「某台设备没装就回退」。含糊其辞比范围小更糟 —— 用户会以为功能没生效。

**⑤ 每个页签可以有自己的强调色**

底部/侧栏 5 个页签的颜色可以逐个指定（未指定时显示「跟随主色」，而不是摆一个
假颜色让人以为已改过）。侧栏的选中底色也跟着走。

**⑥ 皮肤的身份信息**

新增「作者」「说明」两个字段，可编辑、随皮肤一起导出；列表里也能直接改名
（复制出来的皮肤默认叫「默认 2」，不改名列表全是一串后缀）。

**⑦ 内置皮肤从 6 套扩到 10 套**

新增**石墨**（深色 + 青强调）、**樱花**（粉、大圆角）、**终端**（深绿、方角）、
**琥珀**（暖棕）。新增的这套都开启了「统一强调」，作为皮肤的样板。

**⑧ 一个被测试抓到的真 bug**

`uniformAccent` 的序列化条件写反了（`if (!uniformAccent) 'uniformAccent': false`），
导致**打开统一强调后保存/导出会丢掉这个开关**——而且是静默的，重开界面就变回关闭。
是「新字段往返」这条测试把它揪出来的：这类「写入时条件写反」的错，靠肉眼看 JSON
很难发现，因为文件里确实**没有**那一行（看起来只是「用了默认值」）。

`test/theme_test.dart` 53 → 66 条，新增的 13 条覆盖：新字段往返、分页签色白名单、
未知密度/字体回退、表面不透明度与背景对齐缩放夹取、预览色板最多 5 个且滤非法色、
`copy()` 深拷贝、`isEmpty` 判定包含新字段、内置皮肤 id 不重复且令牌都在白名单内、
统一强调跟随主色、密度字体同步与复位、分页签色取值。

---

**Feature**: more customisation — extra colour tokens, UI density and font, per-tab accent
colours, background alignment and zoom.

The previous release opened up colours, icons, text and the background image, but a batch of
things in the UI were still **hard-coded**: the secondary panel fill, the heavier stroke, the
dialog scrim, the eight settings entry cards' individual gradients, the card surface opacity,
and each card's padding. After changing the primary colour you would still see "some corners
look unchanged". This release hands those over too, and gives skins an identity.

**① Five new colour tokens (17 total)**

`surfaceAlt` (secondary panel fill), `dividerStrong` (heavier stroke), `scrim` (dialog veil),
`accentFrom` / `accentTo` (accent gradient).

**② The eight settings entry cards' gradients are no longer hard-coded**

Each card used to carry its own gradient (eight different pairs). A skin can now enable
"unify entry-card colours" to replace them with one from→to pair; it is **off by default**, so
without a skin the UI is pixel-identical to before.

Only six hard-coded gradients changed, into `C.accentDeco(fallback: …)` where `fallback` is the
card's original pair. "Zero regression by default" is therefore structural rather than something
to verify by eye.

When unification is on but no gradient is given, the accent is derived from the **primary**
colour — otherwise a user who just turned the primary green would still see the built-in blue
cards.

**③ Card surface opacity is adjustable (0.3–1.0)**

Previously fixed at 0.85. The floor is 0.3: any lower hands the content over to the background.
With no background image the row explains that it has no visible effect yet, rather than looking
broken.

**④ UI density and font**

- **Density**: compact 0.85 / normal 1.0 / comfortable 1.2, applied to padding computed by the
  shared helpers (card padding);
- **Font**: system default / system UI / Segoe UI / PingFang SC / Microsoft YaHei / Noto Sans /
  monospace.

Fonts use **system-installed families only**: bundling a CJK font costs 5–10 MB, and this app's
bundle already grew once for the icon library and SVG. Each option therefore names the family it
depends on, and the hint states plainly that a missing family falls back automatically — Flutter
degrades gracefully here, no tofu boxes.

Both settings state their own scope: density "changes card padding only; if something looks
unchanged its spacing is fixed individually", font "falls back when not installed". Being vague
is worse than a narrow scope — users conclude the feature does not work.

**⑤ Per-tab accent colours**

The five bottom/sidebar tabs can each have their own accent (when unset the row reads "follows
primary" instead of showing a fake colour that implies it was already changed). The sidebar's
selected background follows along.

**⑥ Skins have an identity**

New "Author" and "Description" fields, editable and exported with the skin; the list also allows
renaming directly (a duplicated skin is called "Default 2" otherwise, leaving a list of suffixes).

**⑦ Built-in skins grew from 6 to 10**

Added **Graphite** (dark + cyan accent), **Sakura** (pink, large radii), **Terminal** (dark green,
square corners) and **Amber** (warm brown). The new ones all enable "unify accent", as templates
for what a skin can be.

**⑧ A real bug the tests caught**

`uniformAccent`'s serialisation condition was inverted
(`if (!uniformAccent) 'uniformAccent': false`), so **enabling unified accents was silently lost
on save/export** — reopening the UI showed it off again. The "new fields round-trip" test caught
it. This class of "condition inverted on write" mistake is nearly invisible by eye, because the
file genuinely does **not** contain the line (it just looks like a default).

`test/theme_test.dart` went from 53 to 66 tests; the 13 new ones cover new-field round-trips, the
per-tab colour whitelist, unknown density/font falling back, clamping of surface opacity and
background alignment/zoom, preview swatches capped at 5 with invalid colours filtered, `copy()`
deep-copying, `isEmpty` accounting for the new fields, built-in skins having unique ids and only
whitelisted tokens, unified accent following the primary, density/font application and reset, and
per-tab accent lookup.

## [1.6.126] - 2026-09-18

### 📦 主题导出可以带上图片了：换机/分享不再是一套「没有图」的主题

上一版的主题只存**引用**（`file:bg_xxx.png`），图本身在应用目录里。
于是换机恢复、或把主题发给别人，对方拿到的是一套缺背景、缺自定义图标的东西 ——
界面不会坏，但用户会以为主题做坏了。

这一版把图片本体（base64）也能打进 JSON 里。

**① 主题页：「导出时包含图片」开关（默认开）**

开关下面直接写着这次会多大（例如「约 3.2 MB」），并提示「文件因此不再适合手工编辑」。
用户导出主题的意图本来就是「把这套东西搬走」，所以默认带上；但代价必须说清楚，
不能替他默默决定。

没有引用任何图片时，这里显示的是另一句话（「导出文件只含配色与文字」），
而不是一个「约 0 B」的开关 —— 后者只会让人怀疑功能坏了。

**② 图片太大时，剪贴板导出的按钮会被禁用并说明原因**

base64 让文本膨胀 33%，几 MB 的图过剪贴板在多数平台上会被截断或直接失败。
与其让用户粘出一段坏 JSON（然后以为是主题文件坏了），不如禁用那个按钮、
并指向「导出全部主题」保存为文件。

**③ 「备份与恢复」也能带图片（默认开）**

只有主题页能带图是不够的：备份恢复是**换机**的主路径。不把图嵌进备份，
恢复后主题照样缺图。勾了「主题」分组时会出现同一个开关，
关掉时提示会明确说「换机恢复后主题会缺少背景与自定义图标」。

**④ 导入侧：先落盘、再重定向引用**

导入顺序不能颠倒：

```
解出嵌入的图片 → 逐张按内容哈希落盘 → 拿到「原文件名 → 本地文件名」映射
              → 解析主题时用该映射重写 background 与 icons 的引用
```

先解析的话，主题会短暂指向一批不存在的文件（用户会看到「图标变成问号」一闪）。

**⑤ 三道防线（嵌入内容是**不可信输入**）**

- **总预算 24MB**：超过就丢弃多余的那几张并计数。不设预算的话，一份损坏/伪造的
  文件能带几百 MB base64 进来，解码那一刻直接把内存吃爆 —— 而这只需要双击一个文件；
- **逐张魔数校验**：复用选择器那条路径的 `_detectFormat`，扩展名与实际格式不符的、
  或压根不是图片的，一律不落盘；
- **文件名形状校验**：`../../etc/passwd` 这类在解包前就被丢掉。

被跳过的张数会如实告诉用户（「有 N 张图片未导入（过大或格式不支持）」）——
用户据此才知道是要换个图、还是换台设备重导。

**⑥ 偏好里不会长期躺着 base64**

如果偏好里出现带嵌入图片的主题包（例如刚从备份恢复），`load()` 会把它解开落盘、
把引用改指本地文件、**再把 base64 剥掉写回**。

这一条容易漏：即使一张图都没落成（全部被跳过），也要剥掉 ——
否则那几 MB 会永远留在 SharedPreferences 里，而且每次保存主题都要整串搬一遍，
看起来「能用」，实际是在持续为一次失败的导入付存储与性能成本。

**⑦ 一个真实踩到的坑：store 必须保持平台中立**

我在 `theme_store.dart` 里用 `Platform.pathSeparator` 算本地文件名时，
忘了它必须能在 Web 上编译（`import 'dart:io'` 会直接废掉 Web 构建）。
改成由 IO 层算好映射再返回。这类错误 `flutter analyze` **发现不了** ——
它只解析非 Web 那一支，而 CI 不构建 Web。

`test/theme_test.dart` 43 → 53 条，新增的 10 条覆盖：attach/extract 往返、
无图片时不写空字段、奇怪输入不抛异常、非法条目（路径穿越等）被丢掉、
stripImages 保留其余内容、remapRef 只改 `file:` 引用、导入时背景与图标引用
被正确重定向、不传 remap 时引用不被改坏、以及预算上限的合理性。

---

**Feature**: theme export can now carry the images themselves, so moving to a new
device (or sharing a theme) no longer produces a theme with missing art.

The previous version stored only *references* (`file:bg_xxx.png`) while the images
lived in the app directory, so restoring on another machine or sending a theme to
someone else gave them one without the background or custom icons. Nothing broke —
it just looked like the theme had been built wrong.

**① "Include images in the export" switch on the Theme page (on by default)**

The hint below it states the resulting size (e.g. "about 3.2 MB") and warns the file
is no longer hand-editable. Exporting a theme means "move the whole thing", so images
are included by default — but the cost has to be visible rather than silently decided.

When no images are referenced, a different sentence appears ("only colours and text")
instead of a switch reading "about 0 B", which would just look broken.

**② When the images are large, the clipboard button is disabled with the reason**

base64 inflates text by 33%, and a few MB through the clipboard gets truncated or fails
on most platforms. Rather than let users paste a broken JSON (and conclude the theme file
is corrupt), the button is disabled and points at "Export all themes" for a file instead.

**③ "Backup & restore" can carry images too (on by default)**

Theme-page export alone is not enough: backup/restore is *the* device-migration path.
Without embedding, a restored theme still lacks its art. Selecting the "Theme" group now
reveals the same switch, and turning it off warns plainly that the restored theme will be
missing its background and custom icons.

**④ Import: store first, then redirect references**

The order cannot be swapped:

```
extract embedded images → write each by content hash → build "old name → local name" map
                        → parse themes, rewriting background and icons refs through it
```

Parsing first would leave the theme briefly pointing at files that do not exist (a visible
flicker of broken icons).

**⑤ Three guards (embedded content is untrusted input)**

- **24 MB total budget**: excess images are dropped and counted. Without it, a corrupt or
  forged file could carry hundreds of MB of base64 and blow up memory on decode — and all
  that takes is double-clicking a file;
- **Per-image magic-byte check**: reuses the picker path's `_detectFormat`, so anything whose
  extension does not match its bytes, or that is not an image at all, is never written;
- **Filename shape check**: `../../etc/passwd` and friends are dropped before unpacking.

Skipped images are reported honestly ("N image(s) were not imported (too large or
unsupported)") so the user knows whether to re-encode an image or re-export on another device.

**⑥ base64 does not linger in preferences**

If a theme bundle with embedded images ever lands in preferences (e.g. restored from a
backup), `load()` unpacks it, writes the images, repoints the references, and **strips the
base64 back out**.

This is easy to miss: even when *no* image could be written (all skipped), stripping still
has to happen — otherwise those megabytes sit in SharedPreferences forever and every theme
save copies the whole string, which looks "fine" while quietly charging storage and CPU for
a failed import.

**⑦ A trap actually hit: the store must stay platform-neutral**

Computing local filenames with `Platform.pathSeparator` inside `theme_store.dart` ignored
that the file must compile for the web (`import 'dart:io'` breaks a web build outright).
The mapping is now computed in the IO layer and returned. Note that `flutter analyze`
**cannot** catch this class of mistake — it only resolves the non-web branch, and CI does
not build for web.

`test/theme_test.dart` went from 43 to 53 tests; the 10 new ones cover attach/extract
round-trips, no empty `images` field when there is nothing to embed, odd input not throwing
on the export path, invalid entries (path traversal etc.) being dropped, `stripImages`
preserving everything else, `remapRef` only touching `file:` refs, import redirecting both
background and icon references, references staying intact when no remap is passed, and the
sanity of the pack budget.

## [1.6.125] - 2026-09-18

### 🖼️ 主题新增背景图：可以用自己的照片当界面底

**入口**：设置页 → 「主题」→ 「背景图」。

**① 一张图铺满整个界面，四个旋钮**

- **不透明度** 0.05 ~ 0.6；
- **模糊** 0 ~ 30；
- **填充方式**：铺满 / 完整显示 / 拉伸 / 平铺；
- **移除**（回到纯色底）。

支持 PNG / JPG / WebP / GIF / BMP / SVG，单个 ≤ 8MB（图标仍是 2MB —— 两者上限不同，
所以「图太大」的提示会说明是哪一种，否则用户会拿着「超过 2MB」的提示去压缩一张
本来只用到 8MB 的照片）。

**② 背景覆盖所有页面，而不是逐个页面去改**

插入点是 `MaterialApp.builder`：它位于 MaterialApp 之下、Navigator 之上，
所以主页面、设置子页、push 出来的页面全都被盖到。逐个页面改的结果必然是漏几个，
而那几页看起来就像「背景图有时候不生效」。

**③ 三层合成，顺序有讲究**

```
图（按填充方式绘制） → 模糊（ImageFiltered，作用在已画好的像素上）
                    → 遮罩（按深浅模式盖一层底色，浓度为不透明度）
```

模糊放在中间这层有个附带好处：**SVG 也能模糊**，因为它最终也是像素。
遮罩层不能省：没有它，一张中等亮度的照片会让深色/浅色文字之一失效。

**④ 有背景图时，卡片自动变半透明**

这是让背景图不毁掉可读性的关键：卡片表面从纯白变成 85% 白（顶栏/侧栏 93%）。
不这么做的话有两条路都走不通 —— 要么卡片不透明（背景图只从卡片缝隙里露出来，
等于换了个更花的底色），要么卡片透明（内容直接被照片盖住，更不可读）。

实现上只改了 `C.surfaceFill` / `C.pageFill` 两个取值点 + `cardDeco` 的默认色，
21 处 `cardDeco()` 调用与所有 `SoftCard` 一个都没动。页面底色同理由 `C.bg`
换成 `C.pageFill`（有背景时透明），共 10 个页面 —— 不换的话不透明底色会把
背景图整个盖住，用户只会看到「设了图但没变化」。

**⑤ 图只存在本机，主题文件里只有引用**

主题 JSON 里存的是 `file:bg_<内容哈希>.png`，不含图片本身。理由与图标一致：
二进制会把几十 KB 的主题文件撑到几 MB，base64 也没法人工编辑。
所以**把主题分享给别人，对方看到的是没有背景的版本** —— 页面上直接写明了这一点，
不写的话对方只会以为主题是坏的。

背景图与图标共用同一条导入通道（`importPickedImage`）：按魔数判格式、按内容哈希命名、
只接受纯文件名、渲染失败回退。只把「上限 / 目录 / 文件名前缀」做成参数 ——
把「读字节、判魔数、算哈希、写盘」这四步复制两份的结果，通常是其中一份忘了同步修。

**⑥ 顺带验证了一处 CI 覆盖不到的角落**

`dart.library.html` 的条件导入（`theme_icon_io.dart` / `_web.dart`）在
`flutter analyze` 里只解析 **非 Web** 那一支，而 CI 不构建 Web ——
也就是说 Web 分支的签名写错了要等真去构建 Web 才会发现。
这次用一个临时探针文件（以 `theme_store.dart` 里真实的调用形状去调用
**web 变体**）让分析器替我们验了一遍，确认两个分支的公共 API 完全一致；
顺带确认所谓「不一致」的几项其实是各文件内部的私有成员（`_isSafeName` 等），
本来就不需要一致。

`test/theme_test.dart` 从 33 条加到 43 条，新增的 10 条覆盖：背景参数往返、
无背景时不写那三个键、非法引用（路径穿越/未知前缀/`lib:` 前缀/空串）被丢掉、
不透明度与模糊夹取、未知填充方式回退 cover、`copy()` 深拷贝、
以及「有背景图 → 页面底色透明 + 卡片半透明」这条可读性保证。

---

**Feature**: themes gained a background image — use your own photo as the app backdrop.

**Entry point**: Settings → "Theme" → "Background image".

**① One image behind everything, four knobs**

- **Opacity** 0.05–0.6;
- **Blur** 0–30;
- **Fill mode**: cover / contain / stretch / tile;
- **Remove** (back to a solid backdrop).

PNG / JPG / WebP / GIF / BMP / SVG, up to 8 MB each (icons stay at 2 MB — the two limits
differ, so the "too large" message names which one applies; otherwise users would go
compress a photo against a 2 MB figure when only 8 MB was in play).

**② The background covers every page — without touching every page**

It is inserted in `MaterialApp.builder`, which sits below MaterialApp and above the
Navigator, so the home page, settings sub-pages and pushed routes are all covered.
Editing page by page guarantees missing a few, and those pages then look like
"the background sometimes doesn't apply".

**③ Three layers, and the order matters**

```
image (drawn per fill mode) → blur (ImageFiltered, on the already-painted pixels)
                            → veil (a tint per light/dark, strength = opacity)
```

Putting blur in the middle has a bonus: **SVG can be blurred too**, since by that point it
is pixels. The veil cannot be dropped: without it, a mid-brightness photo makes either
dark or light text unreadable.

**④ With a background, cards turn translucent automatically**

This is what keeps a background from destroying legibility: the card surface goes from
solid white to 85% white (bars/rails 93%). Both alternatives fail — opaque cards let the
image show only through the gaps (i.e. you just changed to a busier flat colour), and
fully transparent cards put content straight on top of the photo, which is worse.

The implementation touches only two value sites (`C.surfaceFill` / `C.pageFill`) plus
`cardDeco`'s default colour; none of the 21 `cardDeco()` call sites and no `SoftCard`
changed. Page backdrops likewise moved from `C.bg` to `C.pageFill` (transparent when a
background is set) across 10 pages — without that, an opaque backdrop hides the image
entirely and users just see "I set an image and nothing changed".

**⑤ The image lives on this device; the theme file keeps only a reference**

The theme JSON stores `file:bg_<contenthash>.png`, not the image. Same reasoning as icons:
binary would inflate a few-dozen-KB theme to several MB, and base64 stays uneditable by
hand. So **sharing a theme gives the other person the version without a background** — and
the page says so, because otherwise they would assume the theme is broken.

Backgrounds and icons share one import path (`importPickedImage`): magic-byte format
detection, content-hash naming, bare-filename-only references, fallback on render failure.
Only the size cap, directory and filename prefix are parameters — duplicating the
read/verify/hash/write steps in two places usually means one copy silently misses a later fix.

**⑥ Also verified a corner CI cannot reach**

The `dart.library.html` conditional import (`theme_icon_io.dart` / `_web.dart`) is resolved
by `flutter analyze` **only for the non-web branch**, and CI does not build for web — so a
signature mistake in the web branch would surface only when someone actually builds web.
A temporary probe file (calling the **web variant** with the exact call shapes used in
`theme_store.dart`) let the analyzer check it; the two branches' public APIs match. The
apparent mismatches the first pass reported were private per-file members (`_isSafeName`
and friends), which do not need to match at all.

`test/theme_test.dart` grew from 33 to 43 tests; the 10 new ones cover background parameter
round-trips, the three keys being omitted when there is no background, invalid references
(path traversal / unknown prefix / `lib:` prefix / empty) being dropped, opacity and blur
clamping, unknown fill mode falling back to cover, `copy()` deep-copying the background, and
the legibility guarantee ("background set → transparent page fill + translucent cards").

## [1.6.124] - 2026-09-18

### 🎨 主题：界面的颜色、图标、文字都能自己改，也能导出成 JSON 分享

**入口**：设置页 → 「主题」。

**① 6 套内置预设 + 可自建主题**

「默认 / 海洋 / 森林 / 暗夜 / 日落 / 高对比」。预设**不可直接编辑**，只能「复制为我的主题」
再改 —— 否则用户改了一套预设又想要回原样时，只能靠逐项猜着恢复。每套主题还能
「导出此主题」单独分享。

**② 12 个配色令牌，只覆写你改过的那些**

主色、卡片表面、页面背景、次层背景、主/次/弱化文字、分隔线、成功/警告/危险/信息色。

主题是**覆写**而不是全量快照：升级时应用内置的默认值可以继续演进，用户只锁住自己想改的部分，
导出的 JSON 也就短、可读、可手改。

旧版的「自定义主题色」（单个 hex）**原样保留**：主题没有覆写主色时仍然用它 ——
老用户升级后颜色不变，这是有意的兼容保证。反过来，主题已固定主色时，「显示」页的色板下面
会直接写明去哪儿改，而不是让用户点了没反应以为坏了。

配色刻意**不支持半透明**：半透明与背景叠加后对比度随主题变化，「看着还行」和「看不清」
之间没有可靠判据，与其让用户踩坑不如只给不透明色。也刻意不暴露按字面理解的 `white`
（它在深色模式下其实是深灰），要改表面色请用「卡片表面」。

**③ 卡片圆角**

一个滑杆。范围写清楚了：**只作用于卡片与输入框**，不改徽标那类小圆点 ——
它们用的 2~10px 半径是形状语言的一部分，统一乘系数会把圆点变成菱形。

**④ 13 个图标插槽 + 481 个内置图标**

底部 5 个页签 + 设置页 8 个分类入口，可从内置图标库里搜索改选（显示它所服务的那条文案，
比如「地图」「电台设置」，不必记插槽名）。

图标库是**生成的常量表**（`tool/gen_theme_icons.py`）：Flutter 的图标 tree-shaking 只认字面量，
运行时拼 `IconData` 要么编不过、要么把整套 MaterialIcons（约 1.6MB）打进包。
收录范围 = lib/ 里已在用的 465 个（这些 glyph 本来就在包里，收录零成本）+ 人工挑选的候选。

**⑤ 也能导入自己的图片当图标**

PNG / JPG / WebP / GIF / BMP / SVG，单个 ≤ 2MB（Android：系统图片选择器；
Windows：PowerShell 对话框；Linux：zenity；macOS：osascript）。

几处细节都是「不这么写就会出错」的：

- **按魔数判断格式，不看扩展名**：把 logo.jpg 改名成 logo.png 是常事，按扩展名判断就会
  对着 JPEG 字节调 PNG 解码器，结果是「导入成功但显示不出来」；
- **按内容哈希命名**（FNV-1a，不引 crypto 依赖）：同一张图重复导入不会攒出一堆副本，
  主题文件里引用的名字也稳定；
- **只接受纯文件名**：主题文件是用户可编辑的，`file:../../etc/passwd` 这类必须挡住；
- **渲染失败一律回退内置图标**：图被删了、文件坏了，界面都不会跟着坏。

Web 版不支持导入图片（浏览器里没有可写的应用目录），页面上直接说明并引导用内置图标库。

**⑥ 26 条高频文案可覆写**

页签名、设置分类名与说明、几个入口标题。**按钮动词与错误提示刻意不开放** ——
它们是用户的操作依据，被改成不认识的词会让应用变得不可操作。这也是「白名单」而不是
「全量覆写 1662 条」的根本原因。留空即恢复默认。

**⑦ 导入与导出**

JSON 文本，可导出整包（我的全部主题）或单个主题，也能从剪贴板导入。导入时：
白名单外的项**跳过并计数**（导入完成会如实显示「跳过 N 项」）；`schema` 比当前高直接拒绝
并提示升级应用；文件里的 `builtin` 标记一律清除 —— 否则一份文件就能造出「不可删除」的主题。
整包**不含内置预设**：预设每台设备本来就有，导出去再导回来只会让对方平白多出 6 个重复项。

**⑧ 主题并入备份（第 7 个分组）**

「备份与恢复」新增「主题」分组，可单独勾选。注意**不含导入的图标图片文件本身**：
那是二进制，塞进 JSON 会把备份从几十 KB 撑到几 MB，而 base64 也没法人工编辑。
所以主题里的图片引用在**换机恢复后**会回退成内置图标 —— 界面不会坏，只是图标变默认。

**⑨ 顺带修掉一个真实缺陷：TNC / 音频 / PKWDWPL 配置此前不在备份里**

为了让「主题」这项不重蹈覆辙，我把 `tool/check_backup_keys.py` 补强成了三个方向：
精确键、**常量键**、**动态前缀**。补强后它立刻报出 5 个键从未进过备份：

```
tncConfigJson / tncDeviceJson / audioConfigJson / pkwdwplConfigJson / pkwdwplDeviceJson
```

也就是说，v1.6.123 的备份**静默丢了整套链路配置**（蓝牙 TNC、声卡 TNC、Kenwood 航点），
用户换机后得重新配设备。已一并归入「设置配置」分组。

补强过程中还改掉两个检查器自身的毛病，都值得记下来：

- **常量要按文件作用域解析**：`static const _kConfig` 在 tnc.dart / audio.dart / pkwdwpl.dart
  里各有一份、值却不同；用一张全局表会让其中两个的键被算成第三个的值，
  于是真问题被报成「别的键缺失」，白跑一趟。
- **参数要用配对括号 + 顶层逗号切**，不能 `\(([^)]*)\)`：后者遇到 `jsonEncode(x, y)`
  会在第一个 `)` 截断，把普通字面量误判成动态前缀 → 一屏假失败。
  假失败比真失败更坏：修它的人通常会把规则放宽或删掉说明。

三个方向都单独验证过**会报红**（临时塞未归组键 / 拿掉常量键 / 拿掉前缀声明），
基线通过，并已接入 CI 的 Analyze 作业。

**⑩ 新增依赖 `flutter_svg ^2.3.0`**

只为 SVG 图标（纯 Dart、无平台通道，只多 3 个传递依赖）。若不需要 SVG 可以去掉：
调用点集中在 `lib/theme_icon_io.dart` 一处。

`test/theme_test.dart` 另钉 33 条：配色解析与互逆、白名单越界、空文字视为删覆写、
圆角夹取、图标引用形状（含路径穿越）、schema 拒绝、builtin 不可伪造、整包/单主题两种形态、
主题读写往返、偏好损坏时退回默认、图标名不认识时回退、id 撞车不遮蔽、
以及「白名单里每个文案键在 Tx 里都有分支」（漏了不会报错，只会把 `radioCat` 这种内部键名显示出来）。

---

**Feature**: themes — recolour the UI, swap icons and rewrite common labels, with the whole
thing exported as shareable, hand-editable JSON.

**Entry point**: Settings → "Theme".

**① Six built-in presets, plus your own themes**

Default / Ocean / Forest / Midnight / Sunset / High contrast. Presets **cannot be edited
directly** — you copy one into your themes first. Otherwise a user who tweaks a preset and
wants the original back has to guess their way through "reset". Any theme can be exported on
its own to share.

**② Twelve colour tokens, and only the ones you changed are stored**

Primary, card surface, page background, secondary background, primary/secondary/muted text,
divider, success/warning/danger/info.

A theme is an *overlay*, not a full snapshot: the built-in defaults can keep evolving on
upgrade while users pin only what they actually want. It also keeps the exported JSON short
and hand-editable.

The old single-hex "theme colour" is **kept as-is**: it is still used whenever the active theme
does not override the primary colour, so existing users see no change after upgrading — an
intentional compatibility guarantee. Conversely, when the theme does pin the primary colour,
the Display page now says where to change it instead of leaving users clicking a swatch that
does nothing.

Colours deliberately do **not** support alpha: over a background, semi-transparent colours make
contrast vary per theme and there is no reliable line between "looks fine" and "unreadable".
We also do not expose `white` by name (it is actually dark grey in dark mode) — use "card surface".

**③ Card corner radius**

One slider, with its scope stated honestly: **cards and inputs only**. Small radii (2–10px on
badges and chips) are part of the shape language; scaling them all would turn dots into diamonds.

**④ Thirteen icon slots + 481 built-in icons**

The five bottom tabs and eight settings entries, searchable in the icon library. Rows are
labelled with the text they serve ("Map", "Radio settings"), so you never have to know slot names.

The library is a **generated const table** (`tool/gen_theme_icons.py`): Flutter's icon
tree-shaking only understands literals, so a runtime-constructed `IconData` either fails to
compile or drags the whole MaterialIcons font (~1.6 MB) into the bundle. Scope = the 465 glyphs
already used somewhere in lib/ (zero marginal cost) plus a hand-picked selection.

**⑤ Import your own images as icons**

PNG / JPG / WebP / GIF / BMP / SVG, up to 2 MB each (Android: system image picker; Windows:
PowerShell dialog; Linux: zenity; macOS: osascript).

The details are all "got this wrong and it breaks in a way you cannot see":

- **Format is detected from magic bytes, not the extension**: renaming logo.jpg to logo.png is
  routine, and trusting the extension means decoding JPEG bytes with the PNG decoder — which
  presents as "import succeeded but nothing shows";
- **Files are named by content hash** (FNV-1a, no crypto dependency), so re-importing the same
  image leaves no duplicates and references stay stable;
- **Only bare filenames are accepted** — the theme file is user-editable, so `file:../../etc/passwd`
  must be rejected;
- **Any render failure falls back to the built-in icon**, so a deleted or corrupt file cannot
  break the UI.

Importing images is not available on the web (browsers have no writable app directory); the page
says so and points at the built-in library.

**⑥ Twenty-six common labels can be overridden**

Tab names, settings category names and descriptions, and a few entry titles. **Button verbs and
error messages are deliberately excluded** — they are what users act on, and replacing them with
unrecognisable words makes the app unusable. This is the real reason for a whitelist rather than
"override all 1662 strings". Clearing a field restores the default.

**⑦ Import and export**

JSON text: export the whole bundle or a single theme, or import from the clipboard. On import,
entries outside the whitelist are **skipped and counted** (reported honestly as "skipped N entries"),
a higher `schema` is rejected with an "update the app" message, and any `builtin` flag in the file
is stripped — otherwise a file could forge an undeletable theme. The bundle **excludes built-in
presets**: every install already has them, so round-tripping them would just add six duplicates.

**⑧ Themes joined the backup (7th group)**

"Backup & restore" gained a "Theme" group you can select independently. Note it **does not include
the imported image files themselves**: they are binary, and embedding them would inflate a
few-dozen-KB backup to several MB while base64 stays uneditable by hand. So after restoring on
another device, image references fall back to built-in icons — the UI is fine, the icons are
simply default.

**⑨ While at it: a real defect fixed — TNC / audio / PKWDWPL settings were never backed up**

So that "Theme" would not repeat that mistake, I extended `tool/check_backup_keys.py` to three
directions: exact keys, **constant keys**, and **dynamic prefixes**. It immediately reported five
keys that had never been in any backup group:

```
tncConfigJson / tncDeviceJson / audioConfigJson / pkwdwplConfigJson / pkwdwplDeviceJson
```

In other words, v1.6.123's backup **silently lost the entire link configuration** (Bluetooth TNC,
sound-card TNC, Kenwood waypoint), forcing users to re-configure devices after switching devices.
They are now part of the "Settings" group.

Two flaws in the checker itself were fixed along the way, and both are worth recording:

- **Constants must be resolved per file**: `static const _kConfig` exists in tnc.dart, audio.dart
  and pkwdwpl.dart with *different* values. A single global table attributes two of them to the
  third, so the real finding gets reported as "some other key is missing" — a wasted trip.
- **Arguments must be split with matched brackets and top-level commas**, not `\(([^)]*)\)`:
  the latter truncates at the first `)` in `jsonEncode(x, y)`, misclassifying ordinary literals as
  dynamic prefixes → a screenful of false failures. False failures are worse than real ones,
  because whoever fixes them usually loosens or deletes the rule.

All three directions were individually verified to **actually go red** (temporary ungrouped key /
removing a constant key / removing a prefix declaration), the baseline is green, and it runs in the
CI Analyze job.

**⑩ New dependency: `flutter_svg ^2.3.0`**

Only for SVG icons (pure Dart, no platform channels, three transitive dependencies). If SVG is not
wanted it can be dropped: the call site is a single place in `lib/theme_icon_io.dart`.

`test/theme_test.dart` adds 33 more regressions: colour parsing and round-trips, whitelist escapes,
empty text meaning "delete the override", radius clamping, icon-reference shape (including path
traversal), schema rejection, unforgeable `builtin`, both bundle and single-theme shapes, theme
read/write round-trips, falling back to default on corrupt preferences, unknown icon names falling
back, id collisions not shadowing, and "every whitelisted label key has a branch in `Tx`"
(missing one throws nothing — it just prints an internal name like `radioCat` on screen).

## [1.6.123] - 2026-09-18

### 💾 备份与恢复：把设置与数据导出成一个 JSON，换机/重装后导回来

**入口**：设置页 → 「备份与恢复」（与「导出 ADIF」并列）。

**① 分 6 组导出，导入时按组覆盖**

| 分组 | 内容 |
|---|---|
| 设置配置 | 电台身份、信标（含智能信标档位）、主题/语言/缩放、地图、筛选、数据来源、服务器、ADIF 选项、位置 |
| 台站与联系人 | 收藏、手动添加的联系人、备注 |
| 消息记录 | 单聊消息 + 两套已读位置 |
| 群聊 | 群组、成员状态 |
| 翻译设置 | 翻译接口、密钥、每会话语言偏好 |
| 成就与荣誉 | 解锁记录、计数、默认展示徽章 |

导出默认全选（备份的常见诉求是「整份搬走」）；导入时只列出备份里**真实存在**的组，
并默认勾选。选中哪几组，就只覆盖哪几组 —— 不想动消息的人不必动消息。

**② 值带类型标签：`{"s":…}` / `{"b":…}` / `{"i":…}` / `{"d":…}` / `{"l":[…]}`**

JSON 分不清 `int 1` 与 `double 1.0`，而 SharedPreferences 的 `getDouble`
读到 int 值会直接抛类型错误。所以导出时不写裸值，而是带上类型标签；
导入按标签调用对应的 setter。这样即使文件被手工编辑过（例如把 `0.0` 写成 `0`），
最坏也只是这一项被跳过，而不会把应用写坏。测试里专门钉了一条
「`0.0` 不会退化成 int」。

**③ 只回写白名单里的键**

备份文件是用户可见、可编辑、也可能来自别人分享的文本。如果无脑回写
「文件里出现的任意键」，一份伪造的 JSON 就能改写应用里**任何**偏好
（包括未来新增的内部状态键）。所以：

- 键必须落在该分组的白名单内，白名单外的键**跳过并计数**（导入完成后如实显示「跳过 N 项」）；
- 不认识的整组忽略 —— 更新版本导出的备份，在旧版本上不会整份崩掉；
- `schema` 比当前高则直接**拒绝**并提示先升级应用，而不是猜着解析。

**④ 导出前强制落盘（修掉一个静默丢数据的坑）**

`persist()` / `_saveMessages()` 原本是「调用即返回」的顺手保存。
用户「刚加完收藏就点导出」时，写入还排在队列里，导出的会是旧快照 ——
备份功能里这种静默缺失最致命：用户以为备份里有，直到恢复那天才发现没有。
现在新增 `persistNow()` / `flushForBackup()`，导出前逐项 await；
且它与顺手保存**共用同一份键列表**（`_writePrefs`），两处不会漂移。

**⑤ 导入后即时生效，并如实提示重启**

写回偏好后会清空并重载消息/群聊/台站（这些都是「追加」语义的读取函数，
不清空会产生重复数据）。但成就、翻译、服务器连接是在各自单例里只加载一次的，
所以完成后会明确提示「重启后完全生效」，并给一个「退出应用」按钮 ——
不假装一切已经生效。

**⑥ 平台支持**

| 平台 | 选文件 | 保存位置 |
|---|---|---|
| Android | 系统文件选择器（`ACTION_GET_CONTENT`，临时读权限） | 下载目录（MediaStore，免存储权限） |
| Windows | PowerShell + WinForms 打开文件对话框（`-Sta`，UTF-8 输出） | 文档目录 |
| Linux | zenity | 文档目录 |
| macOS | osascript | 文档目录 |
| Web | —（改用剪贴板） | 复制到剪贴板 |

读文件有 32MB 上限（分块读取，超限即拒），避免误选一个大文件把内存吃爆。

**⑦ 页面上的安全提示**

备份里含呼号、服务器口令、翻译 API 密钥 —— 页面上直接写明，不藏着。

**⑧ 新增静态检查并接入 CI：`tool/check_backup_keys.py`**

「新增偏好时忘了把它归入备份分组」不会让编译失败、不会让测试失败，
只会在用户换机那天少一项设置。所以加了一条**双向**静态检查：

- lib/ 里所有 `getX('key')`/`setX('key')` 的键都必须被某个分组覆盖；
- 白名单里的键必须在 lib/ 里仍然有人读写（防止删代码后留下死项）。

检查器自己验证过会报红（临时塞一个 `brandNewFlag` → `MISSING brandNewFlag`）；
解析白名单时用**配对括号**而不是 `\(([^)]*)\)`，避免嵌套括号截断造成假失败。
这条检查已加进 CI 的 Analyze 作业。

`test/backup_test.dart` 另钉了 15 条回归：类型标签往返、白名单越界、
未知分组、schema 拒绝、分组覆盖不碰未选组、导出→导入→再导出一致。

---

**Feature**: back up settings and data to a single JSON file, and restore it — for
switching devices or reinstalling.

**Entry point**: Settings → "Backup & restore" (next to "Export ADIF").

**① Six groups, imported group by group**

| Group | Contents |
|---|---|
| Settings | Station identity, beacon (incl. smart-beacon tiers), theme/locale/scale, map, filters, data sources, server, ADIF options, location |
| Stations & contacts | Favourites, manual contacts, notes |
| Messages | Direct messages + both read-position maps |
| Group chats | Groups and member state |
| Translation | Providers, API keys, per-conversation language prefs |
| Achievements & honours | Unlocks, counters, default badge |

Export selects everything by default (the common case is "move it all"); import lists
only the groups that are **actually present** in the file, pre-selected. Only the
selected groups are overwritten — nobody has to touch their messages to move their
settings.

**② Typed values: `{"s":…}` / `{"b":…}` / `{"i":…}` / `{"d":…}` / `{"l":[…]}`**

JSON cannot tell `int 1` from `double 1.0`, and SharedPreferences'
`getDouble` throws if the stored value is an int. So values are written with a type
tag and applied through the matching setter. If the file is hand-edited (say `0.0`
becomes `0`), the worst case is one skipped entry instead of a broken preference —
there is a dedicated test asserting `0.0` never degrades to an int.

**③ Only whitelisted keys are written back**

The backup is user-visible, editable text that may come from someone else. Blindly
writing back "whatever keys appear in the file" would let a forged JSON change
*any* preference, including internal keys added later. Therefore: keys must be in
that group's whitelist (anything else is skipped **and counted**, and the result
dialog reports "skipped N entries"); unknown groups are ignored (a backup from a
newer version does not break an older app); and a higher `schema` is **rejected** with
an "update the app first" message instead of being guessed at.

**④ Force-flush before export (fixes a silent data-loss trap)**

`persist()` and the `_save…()` helpers were fire-and-forget. If you added a
favourite and immediately hit export, the write could still be queued and the export
would capture the *old* snapshot — the worst kind of bug in a backup feature, since
you only find out on restore day. There are now `persistNow()` / `flushForBackup()`
which are awaited before export, sharing the very same key list (`_writePrefs`) with
the ordinary save path so the two cannot drift apart.

**⑤ Import takes effect immediately, and honestly says a restart is needed**

After writing preferences, messages/chats/stations are cleared and reloaded (those
loaders *append*, so not clearing them would duplicate data). Achievements,
translation and the server connection are loaded once by their own singletons, so
the dialog states plainly that a restart is required for everything to take effect —
and offers a "Quit app" button rather than pretending otherwise.

**⑥ Platforms**

| Platform | Picking a file | Saving |
|---|---|---|
| Android | system file picker (`ACTION_GET_CONTENT`, temporary read grant) | Downloads (MediaStore, no storage permission) |
| Windows | PowerShell + WinForms open dialog (`-Sta`, UTF-8 output) | Documents |
| Linux | zenity | Documents |
| macOS | osascript | Documents |
| Web | — (clipboard instead) | copy to clipboard |

Reading is capped at 32 MB (chunked, rejected above the cap) so a mis-picked huge
file cannot exhaust memory.

**⑦ Security note in the UI**

The file contains your callsign, server passcode and translation API keys; the page
says so instead of hiding it.

**⑧ New static check wired into CI: `tool/check_backup_keys.py`**

"Forgetting to put a new preference into a backup group" fails no build and no test;
it just loses a setting on restore day. So there is now a **two-way** check: every
`getX('key')`/`setX('key')` in lib/ must be covered by a group, and every whitelisted
key must still be read/written somewhere in lib/ (catching leftovers after a
deletion). The checker was verified to actually go red (temporary `brandNewFlag` →
`MISSING brandNewFlag`), and it parses the whitelist with **matched parentheses**
rather than `\(([^)]*)\)` so nested parentheses cannot truncate it into false
failures. It now runs in the CI Analyze job. `test/backup_test.dart` adds 15 more
regressions: type-tag round-trips, whitelist escapes, unknown groups, schema
rejection, group-scoped overwrite, and export→import→export consistency.

## [1.6.122] - 2026-09-17

### 🔤 短波条件「关闭」改「未开通」——它被误读成关闭按钮

**现象**：短波组件上有一颗看起来像「关闭」按钮的圆角块。

**原因**：那不是按钮，是 **「Band Closed」（波段未开通）这个条件标记**。
它是圆角色块（形状与按钮一样），而中文文案恰好是**「关闭」**——
「关闭」在中文里正是关闭弹窗的那个动词，于是它被读成了一颗关闭按钮。
（核实过：组件与面板都没有任何关闭控件，也没有 `Icons.close`。）

**修法**：按「该词在本语言里会不会被读成 UI 动作」逐个判断，而不是笼统全改：

| 语言 | 原 | 现 | 理由 |
|---|---|---|---|
| zh | 关闭 | **未开通** | 「关闭」就是关闭弹窗的动词 |
| zh_TW | 關閉 | **未開通** | 同上 |
| ja | クローズ | **伝搬なし** | カタカナ借词在 UI 里同样是「关闭」 |
| id | Tutup | **Tertutup** | `Tutup` 是祈使式（= 关闭按钮）；`Tertutup` 是状态形容词 |
| es | Cerrada | 保留 | 已是与 banda 性数一致的分词形容词（祈使式才是 `Cerrar`） |
| en | Closed | 保留 | 源数据 N0NBH 自己的分类就叫 *Band Closed*，是该领域惯用语 |

新词都表示**状态**（「无传播」），形状仍像按钮也不会被读成动作。

**同时修掉预览工具的一个保真度缺陷**：组件 chip 的**颜色**由质量 key 决定、
**文字**由本地化函数决定，而预览一直拿英文 key 当文字显示 ——
也就是说预览展示的是**英文界面**（Poor / Good / Fair / Band Closed）。
这不但不准，还导致一个更隐蔽的问题：**我此前是按英文长度做版式判断的**，
而中文 chip 文案短得多。现在预览区分这两件事，并补上中文文案映射。

`Band Closed` 在 46dp chip 里本来就会溢出（约 54dp）——中文改短后（未开通 ≈ 26dp）
反而更宽松。另加两条护栏测试：

- **质量文案必须放得进 46dp chip**（不靠省略号；截断成「未开…」等于没给信息）；
- **「Band Closed」的文案不得是该语言的 UI 关闭动词**（防它再被改回来）。

---

**Symptom**: the HF widget showed a rounded block that reads as a "Close" button.

**Cause**: it is not a button — it is the **"Band Closed" condition marker**. It is a
rounded colour block (the same shape as a button), and the Chinese label happened to be
**「关闭」**, which is exactly the verb used for "close" in dialogs, so it read as a close
button. (Verified: neither the widget nor the panel contains any close control, and there is
no `Icons.close` anywhere.)

**Fix**: decided per language by asking whether the word is read as a *UI action* in that
language, rather than changing all of them wholesale. Chinese/Traditional Chinese/Japanese/Indonesian
were changed (「关闭」→「未开通」, 「關閉」→「未開通」, クローズ→伝搬なし, Tutup→Tertutup — `Tutup`
is the imperative form used on close buttons, while `Tertutup` is a state adjective). Spanish
(`Cerrada`) and English (`Closed`) were **kept**: the Spanish word is already a participle
agreeing with *banda* (the imperative is `Cerrar`), and *Band Closed* is the source feed's
own category name, i.e. established terminology. The new words all denote a **state**
("no propagation"), so the button-like shape no longer invites a click.

**Also fixed a fidelity defect in the preview tool**: a chip's **colour** comes from the
quality key while its **text** comes from the localisation function, but the preview had been
drawing the English key as the label — meaning it was showing an **English interface**
(Poor / Good / Fair / Band Closed). Besides being inaccurate, this hid a subtler problem:
**earlier layout judgements had been made against English string lengths**, whereas the
Chinese labels are much shorter. The preview now separates the two and carries the Chinese
mapping.

`Band Closed` overflowed the 46dp chip anyway (about 54dp); the shorter Chinese label
(未开通 ≈ 26dp) fits comfortably. Two guards added: **quality labels must fit a 46dp chip**
without ellipsis (a truncated 「未开…」 conveys nothing), and **the "Band Closed" label must not
be the UI close verb in any language**, so it cannot be reverted to 「关闭」 by accident.


## [1.6.121] - 2026-09-17

### 📡 6m 波段预测 · 组件暗黑模式 · 系统状态组件

**① 6m（50MHz）波段预测**

6m 的传播机理与 HF 波段**完全不同**，所以没有沿用「日间/夜间」那套模型，而是按三条独立通路判断后再合成：

| 通路 | 成因 | 判据 |
|---|---|---|
| **Es**（偶发 E 层） | 夏季常见，单跳可跨 1000–2000km，是 6m 的主要开通方式 | 源数据按区域给（含 6m/4m 专门项） |
| **极光** | 地磁活跃时高纬出现，CW/SSB 有特征啸声 | Kp ≥ 4 且源数据报开通 |
| **F2** | 需 MUF ≥ 50MHz，太阳活动高年偶发 | `muf` 字段 ≥ 50 |

合成取三条中**最好**的一档而不是平均：三条是并列通路，任一开通就值得上机；
取平均会把「开了」抹平成「关着」。同理，Es 取各区域里最好的一档而不是平均 ——
Es 是局地现象，全球平均会把开通信号抹掉。

数据来源 hamqsl.com 的 `calculatedvhfconditions`。落点两处：
App 内的短波区块（独立成一段，不并进「日间/夜间」表 —— 硬并会让
「6m 日间 Poor」这种组合读起来像同一机理），以及短波组件。

`muf` 字段源数据常为 `NoRpt`，此时 F2 按「不成立」处理而不是猜 ——
猜错会让用户白等一晚。

**② 全部组件支持暗黑模式**

组件由系统进程渲染，读不到应用主题，所以深浅两套色必须走资源目录：

- 新增 `values/widget_colors.xml` 与 `values-night/widget_colors.xml`，
  前景色（主文字 / 次要文字 / 分隔线 / 表面 / 条件色）全部改为 `@color/aw_*`；
- 系统处于深色模式时自动取 `values-night/` 的值，无需任何运行时代码。

夜间不是把浅色简单反相，而是**重新取值**：

| token | 浅色 | 夜间 |
|---|---|---|
| 表面 `aw_surface` | `#FFFFFF` | `#1E2530` |
| 主文字 `aw_ink` | `#253044` | `#E6EAF2` |
| 条件色 good/fair/poor | `#16A34A` / `#D97706` / `#E11D48` | `#68C389` / `#E6A75D` / `#EC6C88` |

条件色在夜间要**提亮**（往白方向约 35%）—— 深底上原色对比不足。
天气组件的背景渐变另有 `drawable-night/` 的深色版本；其上的半透明白分隔线
（白 10%）在深浅两种底色上都成立，不需切换。

**③ 新增系统状态组件（4×2）**

回答台站运行的三个问题，按这个优先级排布：

```
 ⚙ 系统状态                                [logo] APRSlocus
 BG7LZQ-7 · 已定位 · OL62XC
 ──────────────────────────────────────────────────────
 ● APRS-IS 已连接        ● TNC      未启用
 ● 音频    连接中        ● PKWDWPL  未启用
 ──────────────────────────────────────────────────────
 收 1 284   发 37              信标 45s   台站 213
```

| 问题 | 由什么回答 |
|---|---|
| 还在收吗 | 链路区的状态点 + 「收 N」 |
| 我的位置有没有上报 | 身份行的定位状态 + 「信标 45s」 |
| 为什么地图没台站 | 「台站 213」 |

**链路是三态而非两态**：`未启用`（用户没开这条，不用管）/ `已连接` / `已启用未连上`
（开了、连不上，要去查）。混成一个「未连接」会让人对着根本没启用的链路白折腾。
三态三色，且**顺序固定**（APRS-IS / TNC / 音频 / PKWDWPL），不按状态排序 ——
位置固定才能一眼扫到要看的那条。

信标倒计时直接取状态层已本地化的 `nextBeaconIn`，不在组件侧再判一次
「已关闭/未连接/等待定位/即将」—— 那套分支判断属于状态层，两处各判一次必然漂移。

固定 4×2：内容分「身份 / 四条链路 / 计数」三段，压到 2×2 会把链路区挤掉，
而那正是本组件的主要价值。

**④ 组件快照的推送策略：重要变化立即、计数节流**

`AppState` 每个报文都会通知，而系统状态里有「收 N / 发 N」这种必然跟着变的计数。
照直推每秒要过十几次 MethodChannel。所以分两路：

- **重要字段**（链路状态 / 定位 / 网格 / 信标 / 台站数）变化 → 立即推；
- **只有计数变化** → 最多每 20 秒推一次。

判据是「距上次推送的时间」而不是定时器 —— 定时器不受 dispose 管辖，
会在 widget 测试里留下 pending timer 并造成假失败（此前踩过）。

**⑤ 新增工具**

- `tool/add_sys_widget_l10n.py`：为系统状态组件补 6 语言 l10n 键（9 个）。
  手改 6×9=54 处漏一处就是「某语言下组件显示空字符串」，而组件不报错，只能机械操作。
- 预览工具补**明暗两套取色**与**系统状态组件**，并修正：白底组件的底色此前硬写
  白色，导致 `--dark` 对它们完全无效、看不到夜间效果。

---

**① 6m (50 MHz) band prediction.** 6m propagation does not follow the HF day/night model at
all, so it is judged as three independent paths and then combined: **Es** (sporadic-E — the
main way 6m opens, single hop covering 1000–2000 km, reported per region including dedicated
6m/4m entries), **aurora** (appears at high latitudes when the field is active, with the
characteristic raspy CW/SSB sound; requires Kp ≥ 4 *and* the source reporting it open), and
**F2** (needs MUF ≥ 50 MHz, occasional in high solar years, from the `muf` field).

The combination takes the **best** of the three rather than an average: the three are parallel
paths and any one opening justifies getting on the air, while averaging would flatten "open"
into "closed". For the same reason Es takes the best region rather than an average — Es is a
local phenomenon and a global mean erases the opening. Source: hamqsl.com's
`calculatedvhfconditions`. It appears in two places: the in-app HF section (as its own block,
*not* merged into the day/night table, since merging would produce combinations like "6m daytime
Poor" that read as the same mechanism) and the HF widget. The `muf` field is often `NoRpt`, in
which case F2 is treated as *not* satisfied rather than guessed — a wrong guess means waiting up
all night for nothing.

**② Dark mode for every widget.** Widgets are rendered by the system process and cannot read the
app theme, so the two palettes must live in resource directories: `values/widget_colors.xml` and
`values-night/widget_colors.xml`, with all foreground colours (primary text, secondary text,
hairline, surface, condition colours) now referencing `@color/aw_*`. Android picks the night
values automatically with no runtime code. Night is not an inversion but a re-derived palette —
the condition colours are *lightened* (about 35% toward white) because the base colours lack
contrast on a dark surface. The weather widget's gradient backgrounds have their own
`drawable-night/` variants; the translucent white hairlines on top of them (white at 10%) work on
both palettes and need no switching.

**③ A new system-status widget (4×2)**, answering three questions in priority order: *is it still
receiving* (link status dots plus an Rx counter), *has my position been reported* (fix state plus
the beacon countdown), and *why is the map empty* (station count). **Links have three states, not
two** — `off`, `connected`, and `enabled but not connected` — because "you never turned this on"
and "it is on but will not connect" call for completely different actions; collapsing them into
one "not connected" sends people debugging a link they never enabled. The three states get three
colours, and the order is fixed (APRS-IS / TNC / audio / PKWDWPL) rather than sorted by state, so
a glance always finds the link you care about. The beacon countdown reuses the state layer's
already-localised `nextBeaconIn` instead of re-deciding "disabled / not connected / waiting for
fix / due now" on the widget side, since two copies of that branching will drift. Fixed at 4×2:
the content is identity / four links / counters, and squeezing to 2×2 drops the link block, which
is the widget's main value.

**④ Snapshot push policy: important changes immediately, counters throttled.** `AppState`
notifies on every packet, and the system widget shows Rx/Tx counters that necessarily change with
it — pushing straight through would cross the MethodChannel dozens of times a second for numbers
nobody reads that closely. So changes to important fields (link state, fix, grid, beacon, station
count) push immediately, while counter-only changes push at most every 20 seconds. The criterion
is elapsed time rather than a timer, because a timer outside `dispose`'s control leaves pending
timers in widget tests and produces false failures — a trap hit earlier in this work.

**⑤ New tooling.** `tool/add_sys_widget_l10n.py` adds the widget's nine strings across six
languages (hand-editing 6×9 = 54 places, where one miss means a blank string in one language and
the widget never reports an error). The preview tool gained light/dark palettes and the system
widget, and a bug was fixed: the white-background widgets had their surface hard-coded to white,
so `--dark` had no effect on them and their night appearance was invisible in previews.


## [1.6.120] - 2026-09-17

### 🎨 短波组件：条件标记改为 tonal chip（淡底 + 条件色字）

波段条件的呈现从**实心饱和色块**改为 **tonal chip**（条件色 11% 淡底 + 条件色文字）。
理由：条件只是「四档之一」这一个信息，实心色块的颜色用量远大于其承载的信息量，
八个并列时观感接近警示色堆叠；淡底 + 彩字把颜色用量降到约 1/10，同时保留
v1.6.119 建立的对齐关系（chip 固定宽度、两列各在一条竖线上、列头与 chip 列同一 x）。

同时调整：

- **汇总指数去色**：SFI / Kp / A 一律墨色。此前 Kp / A 按阈值着色，与下方表格
  争夺注意力，颜色出现在两处反而失去重点；现在颜色只用于表达波段条件。
- **重建字号层级**：标题 13sp/w800 › 指数值 11sp/w600 › 波段名 10sp/w600 ›
  条件 9sp/w700 › 列头 8sp/w600（带字距）。此前只有四级字号（12/11/9.5/8.5sp），
  层级不明显。

新增 `aw_chipsoft_{good,fair,poor,closed}.xml` 四张淡底 drawable；文字色由
`setTextColor` 设为条件基本色，与 `lib/hf.dart` 的 `hfQualityColor` 共用同一组色值。

> 实现注意：chip 是 `TextView`，**不能**用 `setColorFilter` 染色 —— 该方法只存在于
> `ImageView`（v1.6.114 的故障即由此而来）。底走 `setBackgroundResource`，字走
> `setTextColor`。

预览工具补充**字距**支持：PIL 无 `letterSpacing` 参数，改为逐字绘制并额外推进。
面板与组件均以「小字号 + 字距」弱化次级文字，预览若不模拟会失真。

---

**Condition markers changed from solid saturated blocks to tonal chips** (an 11% condition-colour
fill with condition-coloured text). A band condition is a single piece of information ("one of four
levels"), so a solid block used far more colour than that information warrants, and eight of them in a
column read as stacked alert colours. A pale fill with coloured text cuts colour usage to roughly a
tenth while preserving the alignment established in v1.6.119 (fixed chip width, each column on its own
vertical line, column headers sharing an x with the chip columns).

Also changed: the summary indices (SFI / Kp / A) are now ink-coloured rather than threshold-tinted —
previously Kp/A competed with the table below, so colour appeared in two places and therefore carried
no emphasis; colour now means band conditions and nothing else. And the type scale was rebuilt:
13sp/w800 title › 11sp/w600 index values › 10sp/w600 band names › 9sp/w700 conditions › 8sp/w600
letter-spaced column headers (previously only four steps, 12/11/9.5/8.5sp, so the hierarchy was flat).

Four new pale-fill drawables (`aw_chipsoft_{good,fair,poor,closed}.xml`); the text colour is applied via
`setTextColor` using the same base palette as `lib/hf.dart`'s `hfQualityColor`.

> Implementation note: a chip is a `TextView`, so `setColorFilter` cannot be used to tint it — that method
> exists only on `ImageView`, which is what caused the v1.6.114 failure. Background goes through
> `setBackgroundResource`, text through `setTextColor`.

The preview tool now supports letter spacing (PIL has no `letterSpacing`, so it draws character by
character and advances the extra amount); both the panel and the widget de-emphasise secondary text with
"small type + letter spacing", which a preview would otherwise misrepresent.

## [1.6.119] - 2026-09-17

### 🎨 短波组件重排版；消息页移除瀑布流；清理高德地图文案

**短波组件**：条件标记改为实心彩色 chip（固定宽度 44dp、圆角 4dp、白字加粗），
并修正上一版的四处排版问题：

| 问题 | 处理 |
|---|---|
| 「日 ｜ 夜」图例位于汇总行右端，与下方两列不对齐 | 改为独立列头，与 chip 列同一 x |
| 夜间列右对齐、日间列左对齐，两列参差 | 两列统一左对齐 |
| 条件圆点的 x 随文字宽度浮动 | chip 固定宽度，所有 chip 落在两条竖线上 |
| 波段名与条件之间空白过大 | 波段名列宽收到 52dp |

新增 `aw_chip_{good,fair,poor,closed}.xml` 四张实心 drawable。

**消息页**：移除瀑布流模式，只保留会话模式。删除 `_feedPane`、`_feedBubble`、模式切换器、
`_feedMode` 状态与其持久化、`_scrollFeed`（约 240 行）。切换器随功能一并移除，不留单边开关。
「消息气泡必须渲染译文块」的源码级断言保留（改为断言唯一的 `_bubble`），
它拦截的是「翻译成功但界面不显示」这类静默故障。

**地图文案**：清理 6 种语言共 7 个键中的第三方地图品牌描述 ——
功能列表标题改为「在线地图」、「高德火星」改为 `GCJ-02`、图源说明不再点名、
引导页文案改为「在线地图瓦片」、导航失败提示改为「未安装地图应用」（该提示与具体地图应用无关）、
地图分组标题改为「国内地图」。**保留**地图选项自身的名称与关于页的开源致谢
（该项目实际使用该瓦片服务）；代码中 `MapType.group == '高德'` 是分组数据实参而非文案，
界面显示走 `domesticMaps`，改动会导致分组失效。

---

**HF widget**: condition markers became solid colour chips (fixed 44dp width, 4dp radius, bold white
text), fixing four layout problems from the previous revision — the "day | night" legend sat at the right
end of the summary row and did not line up with the two columns below (now a proper column header sharing
an x with the chip columns); the night column was right-aligned while the day column was left-aligned (both
now left-aligned); the condition dots' x position drifted with text width (chips are fixed-width, so every
chip lands on one of two vertical lines); and the gap between band name and conditions was excessive (band
column narrowed to 52dp). Four solid drawables were added (`aw_chip_{good,fair,poor,closed}.xml`).

**Messages page**: the feed mode was removed, leaving conversation mode only. `_feedPane`, `_feedBubble`,
the mode toggle, the `_feedMode` state and its persistence, and `_scrollFeed` were deleted (about 240
lines); the toggle went with the feature rather than remaining as a one-sided switch. The source-level
assertion that "the message bubble must render the translation block" was kept (now asserting the single
`_bubble`), because it guards a silent failure mode — translation succeeding while nothing appears.

**Map copy**: third-party map branding was removed from 7 keys across 6 languages — the feature-list
headline is now "Online map", "高德火星" became `GCJ-02`, the map-source note no longer names a provider,
the onboarding line says "online map tiles", the navigation failure toast says "no map app is installed"
(that message was never specific to any provider), and the map group heading became "国内地图". The map
picker's own option names and the About page's open-source acknowledgements were **kept** (the project
does use that tile service); the internal `MapType.group == '高德'` value is a grouping argument rather
than copy — the UI displays `domesticMaps` for it — and changing it would break the grouping.

## [1.6.118] - 2026-09-17

### 📦 v1.6.114–118 合并发布；短波组件改白底；撤掉面板星空层

本版发布的 tag 覆盖 v1.6.114 至 v1.6.118 的全部改动（v1.6.113 是上一个发布 tag，
中间各版仅经 CI 验证、未单独打 tag）。

**短波组件改为白底**：与天气组件（彩色渐变）形成明确区分，同时白底配深色文字的可读性
优于彩色小字压深色底。相应调整：

- 新增 `aw_bg_white.xml`；分隔线改用 `C.border`（`#E5E9F0`），不再用白色低透明度
  （后者只适用于彩色渐变底）；空状态文字改墨色（白字在白底上不可见）。
- **色值改为基准色**：条件色原为「级别色提亮 35%」，那是为压在彩色渐变上做的补偿；
  白底上提亮色过淡，改用与面板浅色 UI 一致的基准色。
- 汇总行改为单行「小标签 + 大数字」（SFI/Kp/A 由 10sp 提到 15sp 加粗）；
  不设独立表头，「日 ｜ 夜」图例并入汇总行右端（130dp 可用高度下，
  独立表头会使内容超出 17.2dp）。

**撤掉面板的星空与大气层**：删除 `_StarLayer`、`_StarPainter`、`_atmosphere`
及其在面板背景 Stack 中的两层，预览工具中对应的示意图一并删除。

---

**This tag ships everything from v1.6.114 through v1.6.118** (v1.6.113 was the previous released tag;
the intervening versions were CI-verified only).

**The HF widget now uses a white background**, which distinguishes it clearly from the weather widget's
coloured gradient, and dark text on white is more legible than small coloured text on a dark ground.
Supporting changes: a new `aw_bg_white.xml`; hairlines switched to `C.border` (`#E5E9F0`) instead of
low-alpha white (which only works on the gradient); and the empty-state text became ink (white would be
invisible on white). **Colour values switched to the base palette** — condition colours had been
"base colour lightened 35%", a compensation for sitting on the coloured gradient, and that lightened
version is too pale on white, so the widget now uses the same base colours as the panel's light UI. The
summary became a single row of small labels with large numbers (SFI/Kp/A from 10sp to 15sp bold), and the
separate header row was dropped with the "day | night" legend folded into that row, because at 130dp of
usable height a separate header overflowed by 17.2dp.

**The panel's star field and atmosphere layer were removed**, along with the corresponding mockup in the
preview tool.

## [1.6.117] - 2026-09-17

### 📻 短波与电离层传播：面板区块、独立组件；修正天气组件在真机上的溢出

**新增短波/电离层传播数据**（`lib/hf.dart`）：数据源为 hamqsl.com 的 `solarxml.php`
（N0NBH 维护，业余无线电界通用的 HF 传播数据源），30 分钟缓存。解析字段：SFI、A 指数、
K 指数、X 射线通量、太阳黑子数、太阳风速、地磁状态、噪声底噪、MUF，以及
`calculatedconditions` 中的四个波段对（80m/40m、30m/20m、17m/15m、12m/10m）各自的
日间与夜间条件。注意该接口需使用 HTTPS（HTTP 会 301 重定向）。

**面板新增传播区块**：太阳与地磁指数（两列 label/value 布局），以及逐波段的
日间/夜间条件表（每格圆点 + 条件文字，按 Good/Fair/Poor/Closed 分色）。
无数据时整块不渲染。

**无线电建议纳入传播状态**：新增 `allHamTips` = 天气类建议 + 传播类建议，
**按级别归并**而非首尾相接 —— 后者会把传播类的「通联机会」插到天气类的
「操作提示」之前，破坏既定的「安全警示优先」排序。传播类建议覆盖地磁暴（K≥5）、
地磁活跃（K≥4）、SFI 偏低/偏高、底噪偏高、单波段条件好/差。

**新增短波传播桌面组件**（4×2，固定尺寸）：固定尺寸的原因是内容为「波段 × 昼夜」
二维表，无法像列表那样降级显示 —— 缩到 2×2 只剩波段名而无条件值。

**修正天气组件在真机上的溢出**。根因是预览工具的两处系统性低估：

1. 文本高度按「墨迹高度」估算，而 `TextView` 的行盒高度取决于字体
   `ascent + descent`（Noto Sans SC 为 1.45em，中文墨迹仅约 1.0em，
   `includeFontPadding="false"` 不改变行盒），每行低估约 4dp。
2. 未计算**圆角净空** —— 20dp 圆角下距底边 10dp 内的左右两侧已被裁掉，
   而判据此前只比较内容高度与卡片高度。

两处均已修正，并据此重排主档：顶栏合并为一行、指标由 4 格 2 行改为 3 格 1 行、
建议改为「级别与正文同行」（正文使用完整短句，缩短的是措辞而非截断句子）。

---

**New HF/ionospheric propagation data** (`lib/hf.dart`) sourced from hamqsl.com's `solarxml.php`
(maintained by N0NBH, the standard HF propagation feed in amateur radio), cached for 30 minutes. It parses
SFI, A/K indices, X-ray flux, sunspot number, solar wind speed, geomagnetic state, noise floor, MUF, and
the day/night condition for each of the four band pairs in `calculatedconditions` (80m/40m, 30m/20m,
17m/15m, 12m/10m). The endpoint requires HTTPS (HTTP returns a 301).

**New propagation section in the panel**: solar and geomagnetic indices in the existing two-column
label/value layout, plus a per-band day/night condition table (a dot and a condition label per cell,
coloured by Good/Fair/Poor/Closed). The whole block is omitted when there is no data.

**Radio advice now accounts for propagation**: `allHamTips` merges weather advice with propagation advice
**grouped by severity** rather than concatenated, because concatenating would place propagation "openings"
above weather "operating tips" and break the established "safety first" ordering. Propagation advice covers
geomagnetic storms (K≥5), active field (K≥4), low and high SFI, high noise, and per-band good/poor
conditions.

**New HF propagation home-screen widget** (4×2, fixed size). The size is fixed because the content is a
two-dimensional band-by-day/night table, which cannot degrade like a list — at 2×2 only band names would
remain, without any condition values.

**Fixed a real-device overflow in the weather widget.** The root cause was two systematic under-estimates
in the preview tool: text height was estimated from ink extent, whereas a `TextView`'s line box follows the
font's `ascent + descent` (1.45em for Noto Sans SC, against roughly 1.0em of Chinese ink, and
`includeFontPadding="false"` does not change the line box), under-counting about 4dp per line; and
**corner clearance was not accounted for** — with a 20dp radius the left and right edges within 10dp of the
bottom are already clipped, while the check compared content height against card height only. Both were
corrected and the main tier re-laid out accordingly: the header collapsed to one row, metrics went from four
cells in two rows to three cells in one row, and tips place the severity label and body on one line (with
bodies drawn from complete short clauses, shortening the wording rather than truncating the sentence).

## [1.6.116] - 2026-09-17

### 🎨 小组件改用真实图标与图形 logo；新增设计预览工具

**图标改为预烘焙的位图**：组件进程不具备应用内的 Material 图标字体，RemoteViews 也不支持字体图标与
矢量图。此前因此退化为使用 emoji，而 emoji 与面板的图标语言不一致。现于构建期用
`tool/gen_app_widget_icons.py` 将 Flutter 自带的 `MaterialIcons-Regular.otf` 渲染为 PNG
（13dp / 26dp 两档，共 39 个），组件图标因此与面板 `Icons.*` 为同一套字形。
「图标名 → 资源」映射表由同一脚本生成（`WidgetIcons.kt`），Dart 侧只传名称。

**logo 改为圆形**：源图取自 `mipmap-xxxhdpi/ic_launcher.png`。该图标的圆角外部并非全透明，
而是 alpha≈166 的半透明黑，直接缩放会在彩色渐变上形成暗边；且源图仅 192px，裁圆后边缘呈阶梯状。
现按其**实测几何与颜色**重绘（4× 超采样）：底色 `#031F55`→`#011840`、中心圆 `#595959` 半径 18/96、
两道灰环半径 29/96 与 44.5/96、外环 `#A8C2F2` 半径 59/96、左右白点半径 54/96。

**新增设计预览工具** `tool/preview_app_widget.py`：使用真实素材（同一批 PNG 图标、同一组渐变色值、
同一套字号）渲染全部档位，并将「内容是否放得下」作为**硬性失败**（退出码 1）。
该工具在编码前即发现 7 处排版问题（顶栏溢出、观测时刻与指标重叠、内容超出卡片高度等）。

**其它**：两个组件 Provider 各自的 `JSONObject.read` 扩展合并为 `WidgetJson.kt`。

---

**Icons are now pre-baked bitmaps**: the widget process has no access to the app's Material icon font, and
RemoteViews supports neither font icons nor vector drawables — which is why earlier revisions fell back to
emoji, whose visual language does not match the panel. `tool/gen_app_widget_icons.py` now renders Flutter's
bundled `MaterialIcons-Regular.otf` to PNGs at build time (13dp and 26dp, 39 icons), so widget icons and the
panel's `Icons.*` share the same glyphs. The name-to-resource map is emitted by the same script
(`WidgetIcons.kt`), and Dart sends names only.

**The logo is now circular.** The source (`mipmap-xxxhdpi/ic_launcher.png`) is not fully transparent outside
its rounded corners — those pixels are semi-transparent black at alpha≈166 — so scaling it down produces a
dark halo on the coloured gradient; and at 192px, cropping to a circle leaves a stair-stepped edge. It is now
redrawn from measured geometry and colours (4× supersampled): `#031F55`→`#011840` background, a `#595959`
centre circle at radius 18/96, two grey rings at 29/96 and 44.5/96, a `#A8C2F2` outer ring at 59/96, and white
dots at radius 54/96.

**New design preview tool** (`tool/preview_app_widget.py`) renders every tier from real assets (the same PNG
icons, the same gradient values, the same type scale) and treats "content does not fit" as a **hard failure**
(exit code 1). It surfaced seven layout problems before any code was written.

**Also**: the two providers' separate `JSONObject.read` extensions were merged into `WidgetJson.kt`.

## [1.6.115] - 2026-09-17

### 🔴 修复「小组件加载失败」：一个方法名用在了不支持该方法的控件上

**故障现象**：桌面组件显示启动器的「加载失败」占位，四档布局全部失效。

**根因**：条件圆点使用 `TextView` 实现，而代码对其调用
`setInt(viewId, "setColorFilter", color)`。该方法**仅存在于 `ImageView`**
（`android.view.View` 与 `android.widget.TextView` 均无此方法），因此运行时抛出
`NoSuchMethodException`，`RemoteViews.apply()` 随之抛出 `ActionException`，
启动器渲染失败占位。

需要强调的是：**RemoteViews 的失败是整块的**，并非「该处样式不生效」——
单个无效调用即导致整个组件不可用。这也是 v1.6.114 之前的版本能够正常显示的原因：
那些版本未使用 `setColorFilter`。

**修复**：改用**更换 drawable** 表达级别色 —— 新增
`aw_dot_{danger,warn,good,tip}.xml` 四张记色圆点，运行时以
`setInt(dot, "setBackgroundResource", …)` 切换。这是 RemoteViews 中唯一可靠的换色手段，
与危险级提示行更换红底同属一种做法。级别名无法识别时回退到中性圆点，
而不是传入 0（传 0 会清除背景，圆点消失）。

圆点颜色为级别原色向白色提亮 35%，与级别文字同值；提亮算法由 `Color.lerp` 改为
**整数分量运算**，以消除浮点表示在边界值上的 1 单位偏差，使 Dart 与 Python 两侧结果
可精确断言。

**同时补强静态检查**：`tool/check_android_res_ids.py` 增加**按目标控件类型**校验
`setInt` 字符串方法名的规则（方法名 → 定义该方法的类：`setTextColor`→`TextView`、
`setColorFilter`→`ImageView`、`setBackgroundResource`→`View`）。
此前该检查只有一份手写的**方法名白名单**，而 `setColorFilter` 恰在其中 ——
名字级别的白名单无法表达「该方法在该控件类型上是否存在」，因而未能拦住此故障。
新规则已用 v1.6.114 的代码验证会报错（3 个调用点、共 15 条）。

**另修**：`compactRows` 外层缺少 `level` 字段，导致 Kotlin 取到空串、小尺寸档的级别颜色
静默丢失；生成脚本 `dot()` 将颜色写死为 `#FFFFFF`，使 `aw_dot_danger.xml` 的注释与实际
渲染颜色不一致（已加自检：注释中声明的颜色必须出现在产物中）。

---

**Symptom**: the home-screen widget showed the launcher's failure placeholder and all four tiers were dead.

**Root cause**: the condition dot was a `TextView`, and the code called
`setInt(viewId, "setColorFilter", color)` on it. That method exists **only on `ImageView`** (neither
`android.view.View` nor `android.widget.TextView` has it), so it threw `NoSuchMethodException`,
`RemoteViews.apply()` threw `ActionException`, and the launcher rendered its failure placeholder.

It is worth stressing that **a RemoteViews failure is all-or-nothing** — not "that bit of styling is lost".
A single invalid call makes the entire widget unusable, which is also why the revisions before v1.6.114
displayed correctly: they never called `setColorFilter`.

**Fix**: severity colour is now expressed by **swapping drawables** — four tinted dots
(`aw_dot_{danger,warn,good,tip}.xml`) selected at runtime with
`setInt(dot, "setBackgroundResource", …)`. In RemoteViews this is the only reliable way to change colour, and
it is the same technique already used to give the danger row a red background. An unrecognised severity falls
back to the neutral dot rather than passing 0 (which clears the background and makes the dot vanish).

The dot colours are the severity colours lightened 35% toward white, matching the severity labels; the
lightening was also changed from `Color.lerp` to **integer component arithmetic** to remove a one-unit
floating-point discrepancy at boundary values, making the Dart and Python results exactly assertable.

**Static checks were strengthened**: `tool/check_android_res_ids.py` now validates `setInt` string method
names **by target view type** (method → defining class: `setTextColor`→`TextView`,
`setColorFilter`→`ImageView`, `setBackgroundResource`→`View`). The previous check used a hand-written
**method-name whitelist**, which happened to include `setColorFilter` — a name-level whitelist cannot express
"does this method exist on this view type", so it could not have caught this failure. The new rule was verified
against the v1.6.114 code, where it reports all 15 violations across three call sites.

**Also fixed**: `compactRows` omitted the outer `level` field, so Kotlin read an empty string and the small
tiers silently lost their severity colours; and the generator's `dot()` hard-coded `#FFFFFF`, leaving
`aw_dot_danger.xml`'s comment disagreeing with the colour it actually rendered (a self-check now ensures the
colour named in a comment appears in the output).

## [1.6.114] - 2026-09-17

### 📱 新增 Android 桌面小组件：天气 + 业余无线电提示（4 档自适应）

主屏组件，显示当前天气与**此刻需要注意的无线电操作事项**，按主屏可用空间自动切换四档布局：

| 档位 | 格子 | 内容 |
|---|---|---|
| 主档 | 3~4×2 | 天气主区（图标、温度、天气现象、今日高低温）+ 指标格 + 通栏建议 |
| 竖长档 | 2×4 | 温度 + 指标 + 堆叠式建议（最接近应用内面板的排布） |
| 紧凑档 | 2×2 | 温度 + 天气现象 + 单条最要紧的建议 |
| 单行档 | 3~4×1 | 一行显示温度、天气现象与一条建议 |

**架构：数据单向推送，组件不自行请求天气。** 和风天气密钥在构建期通过
`--dart-define=QWEATHER_KEY` 注入 Dart 侧，原生侧无法获取 —— 为一个组件在 Kotlin 中
再保存一份密钥会引入额外的泄漏面，且两份密钥不同步时会出现「应用有天气、组件没有」。
更关键的是判定规则：火腿建议的整套逻辑（雷电、大风、低温、高湿、沙尘、大气波导、
灰线）、空气质量分级、逐日预报解析均实现在 `lib/weather.dart`，
在 Kotlin 中重写必然与面板产生分歧，且两处分别看都成立，属难以排查的一类缺陷。
因此由 Flutter 侧（`lib/app_widget.dart`）组装一份**已计算、已本地化**的快照 JSON
推送给原生，原生仅负责渲染。

**字号与颜色层级对齐应用内面板**：提示行的级别色、分隔线透明度、文字弱化方式均取自
面板既有数值。小尺寸档放不下一整句建议，因此 Dart 侧将建议切为逐级变短的若干版本，
由原生按可用宽度选取 —— 切分规则涉及全角冒号与句末标点，属本地化范畴。

---

A home-screen widget showing current weather plus **what needs attention right now**, switching
automatically between four layouts based on available space: a 3–4×2 main tier (weather hero, metric cells,
full-width tips), a 2×4 tall tier (stacked tips, closest to the in-app panel), a 2×2 compact tier, and a
3–4×1 single-row tier.

**Architecture: one-way data push; the widget never fetches weather itself.** The QWeather key is injected
into Dart at build time via `--dart-define=QWEATHER_KEY` and is not available to native code — keeping a second
copy in Kotlin for the widget would add a leak surface, and drift between the two copies would produce
"app has weather, widget does not". More importantly, every rule lives in `lib/weather.dart` (the ham-advice
logic for storms, gales, cold, humidity, dust, ducting and gray-line; AQI grading; daily forecast parsing),
and reimplementing it in Kotlin would inevitably diverge from the panel — with each side looking correct on
its own, which makes such defects hard to diagnose. Flutter therefore composes an **already computed and
already localised** snapshot JSON and pushes it to the native side, which only renders it.

**Type and colour hierarchy follows the in-app panel** (severity colours, hairline opacity, and text
de-emphasis all reuse the panel's existing values). Because the smaller tiers cannot fit a full sentence, Dart
pre-slices each tip into progressively shorter variants and the native side selects by available width — the
splitting rules involve full-width colons and sentence punctuation, which is a localisation concern.

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
- **修法**：
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
- **「管理联系人」一并移除**（消息页仍可添加/收藏联系人，但不再有删除入口）

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
