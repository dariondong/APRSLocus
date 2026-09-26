# AGENT.md · 给智能体 / 贡献者的协作约定

> 面向**智能体（AI Agent）**与**二次开发 / fork 的人**。
> 人类贡献流程见 [`CONTRIBUTING.md`](CONTRIBUTING.md)；荣誉授予见 [`HONORS.md`](HONORS.md)。
>
> 最要紧的两条：**⛔ fork 不得迭代主仓库的版本号**（第一节，铁律）·
> **📋 历史 PR 的贡献要点与登记点**（第四节）。其余是版本号流转与提交前自查。

---

## 一、铁律：fork 不得迭代主仓库的版本号

> **Forks must not iterate or reserve this project's version numbers.**
> Pick your own scheme (e.g. `2.0.3-<你的名字>`) — anything you like, as long as it
> cannot be mistaken for an upstream release and does not move the upstream version line.

**允许**：`2.0.3-BH7GZB`、`2.0.3-bh7gzb.1`、`2.0.4-BH7GZB`、`2.1.0-你的名字`、`3.0.0-fork` … 随你喜欢。
**禁止**：

| 禁止的事 | 为什么 |
|---|---|
| 把你的改动按上游号段递增（如抢用 `2.1.0`、`3.0.0`） | 上游下一版本来要发那个号，撞号后**无法分辨谁是官方包** |
| 把 fork 的版本号合回上游 / 向上游发 `v*` tag | 会直接触发上游的自动发版流水线（自己仓库的 tag 无妨） |
| 认为「改了版本号没关系，反正编译得过」 | 版本号**会发到空中**（见下），全网都看得到 |
| 同号但改内容（如自称 `2.0.3` 却带了别的改动） | 出问题时无法定位到底是哪个 `2.0.3` 在发信标 |

### 为什么这条特别重要（三个后果，都有据可查）

1. **版本号会被发射到射频 / APRS-IS，全网可见。**
   `lib/state.dart` 的 `appVersion` 会进身份 / 状态帧，共四处：

   ```
   $myFullCall>APALOC,TCPIP*:>APRSlocus CONNECT v$appVersion $platformTag
   ```

   | 位置 | 是什么 | 走哪条路 |
   |---|---|---|
   | `lib/state.dart:2731` | APRS-IS **保活帧**（距上次发射 < 25 秒则不发） | 仅 APRS-IS |
   | `lib/state.dart:3367` | **连接成功**时发的身份状态帧 | 仅 APRS-IS |
   | `lib/state.dart:3578` | **链路自检** `LinkDiag.testFrame(…, appVersion)` | **当前发射来源** |
   | `lib/state.dart:3628` | `sendStatus()` 文本留空时的内置在线帧 | **当前发射来源** |

   后两处会被 `_sendRaw` / `tnc.sendTnc2` 发出去 —— 也就是说**发射来源选的是射频时，
   版本号真的会上天**，任何人都能收到。
   所以两个都自称 `2.0.3` 的包，在 aprs.fi 上**看起来完全一样** —— 这是这一条最主要的理由。

2. **官网版本号是「取最新 Release」的。**
   `docs/js/main.js` 拉 GitHub `releases/latest`，再用 `/v?(\d+\.\d+\.\d+)/` 解析 ——
   即 `v2.0.3-fork` 仍会被读成 `2.0.3`。

3. **`versionCode` 必须自行单调递增，且不能与上游混淆。**
   本仓库规则：`versionCode = major×10000 + minor×100 + patch`（`2.0.3 → 20003`）。
   Android 只认**同一个 applicationId 下**递增；改了 applicationId 的 fork 另起一套即可。

### fork 的正确做法

```bash
# 以下都在你自己的仓库里做，不要把版本号提交回上游

# 1) 版本号用「上游版本 + 你的标识」，别动上游号段
#    pubspec.yaml      :  version: 2.0.3-BH7GZB+20003
#    lib/state.dart    :  static const appVersion = '2.0.3-BH7GZB';
#    （android/local.properties 存在时，flutter.versionName 同步改掉）
#
#    ⚠️ tool/sync_version.py 只接受纯 X.Y.Z：
#       $ python3 tool/sync_version.py 2.0.3-BH7GZB
#       ERROR: invalid version '2.0.3-BH7GZB' (expect 1.2.3)   # 退出码 1
#    所以带后缀的版本号要**手改上面两处**（这是有意的：防止 fork 的版本号
#    被发版流水线当成正式版本参与迭代）。
#
# 2) 改包标识，否则官方包与你的包互相装不上
#    Android : android/app/build.gradle.kts 的 applicationId = "com.aprslocus.aprslocus"
#              （namespace 同值，也建议一起改）
#    iOS     : ios/Runner.xcodeproj/project.pbxproj 里 6 处 PRODUCT_BUNDLE_IDENTIFIER
#              （含 RunnerTests 的 …RunnerTests）
#    Windows : installer.iss 的 AppId GUID —— 不改会与官方安装包互相当成同一个程序
#
# 3) 只在**自己的**仓库打标签发布；自己的标签用别的前缀更稳，例如 bh7gzb-v1
#    （向上游仓库推 v* 会触发官方发版，别做）
```

> 同 applicationId、不同签名 → Android 直接拒装（`INSTALL_FAILED_UPDATE_INCOMPATIBLE`），
> 所以想与官方版共存，必须改 applicationId。

---

## 二、版本号的唯一真源与流转

| 位置 | 形式 | 谁在写 |
|---|---|---|
| `pubspec.yaml` | `version: 2.0.3+20003` | `tool/sync_version.py`（发版时由工作流调用） |
| `lib/state.dart` | `static const appVersion = '2.0.3';` | 同上；**会被发射到空中**，也用于「关于页 / 更新页 / 备份」 |
| `android/local.properties` | `flutter.versionName` / `flutter.versionCode` | 同上；**文件不存在就跳过**（CI 上由 flutter 自行生成） |
| `CHANGELOG.md` 顶部标题 | `## [2.0.3] - 2026-09-27` | 人工；**Release 页正文就是从这儿抽的** |
| `docs/js/main.js` | 运行时取 GitHub `releases/latest` | 自动，无需手改 |

**只有维护者改版本号**，且只在**准备发版时**改一次：

```bash
python3 tool/sync_version.py 2.0.4      # 三处一起同步；只接受 X.Y.Z
```

---

## 三、发版流程（维护者）

**本仓库发版只由打 tag 触发**，`.github/workflows/build-release.yml`：

```
push tag v*  ──►  build-windows ┐
                 build-android ├─►  release job（needs 三者 + if refs/tags/）
                 build-ios     ┘      · 抽出 CHANGELOG 该版本的中英双语正文
                                      · 挂 windows/.exe · android/.apk · ios/.ipa
```

- Release 正文由工作流里的 `awk` 从 `CHANGELOG.md` 抽 ——
  所以**每个版本条目必须是「中文条目 + 紧随其后的 `(English)` 条目」**，
  缺了英文或混入相邻版本都会被 `tool/check_release_notes.py` 在 CI 里拦住。
- 资产名带版本号：`APRSLocus_Setup_2.0.3.exe` / `APRSLocus_2.0.3.apk` / `APRSLocus_2.0.3_unsigned.ipa`。

**推荐顺序（踩过的坑：先打 tag 才发现编译错误，只能删 tag / 删 Release 重打）**：

1. 先把代码推到 `main` → 等 **CI Test Build** 全绿
2. 再打 tag → 触发 **Build Release**

`ci-test.yml`（推 `main` / PR / 手动触发）4 个 job：
`Analyze`（17 条 python 静态检查 + 2 条算法回归 `sim_*` + 3 个 `flutter test` + `flutter analyze`）、
`Build Windows`、`Build Android APK`、`Build iOS (IPA)`。

---

## 四、PR 贡献要点

> 只记**要点**，不展开实现内容。按合并时间排序。
> ⚠️ 本表按 **GitHub 账号**列（已核对）；仓库内**不保存**账号 ↔ 呼号的对应关系
> （`docs/members.json` 只存呼号），需要对应时**问维护者，不要自行推断**。

| PR | 作者（GitHub） | 要点 | 合并 |
|---|---|---|---|
| [#1](https://github.com/dariondong/APRSLocus/pull/1) | `nimenhagg` | 补齐**英文国际化**（界面文案整套英文化） | 2026-08-30 |
| [#2](https://github.com/dariondong/APRSLocus/pull/2) | `xaxovo` | **设置页 UI 一致性**打磨 | 2026-08-30 |
| [#3](https://github.com/dariondong/APRSLocus/pull/3) | `dariondong`（维护者） | #2 的收尾修复：折叠档位、开关点按区 | 2026-08-30 |
| [#4](https://github.com/dariondong/APRSLocus/pull/4) | `xaxovo` | **BG2HCB 彩蛋**（猫 / 心形 emoji 粒子） | 2026-08-30 |
| [#5](https://github.com/dariondong/APRSLocus/pull/5) | `xaxovo` | 彩蛋打磨：触发位置 + 全屏粒子 | 2026-08-31 |
| [#7](https://github.com/dariondong/APRSLocus/pull/7) | `Liyuchen0118` | **繁体中文**翻译润色 + 群聊术语统一 | 2026-09-06 |
| [#10](https://github.com/dariondong/APRSLocus/pull/10) | `ju1c3rSH` | **协议页支持繁體中文**（原先只打包简 / 英两份） | 2026-09-12 |
| [#11](https://github.com/dariondong/APRSLocus/pull/11) | `FengziLeo` | **位置报文数据扩展**（`/A=` 高度、PHG 功率 / 天线高度 / 增益）+ **独立状态报文**及其显示；同批把版本号提到 `2.0.3`（versionCode 20003） | 2026-09-26 |

### 这些贡献被记在哪（登记点）

授予徽章 / 记录贡献请**照 [`HONORS.md`](HONORS.md) 走**，别只改一处。
`docs/members.json` 是**权限真源**，当前 `developers` 为
**BG7LZQ · BG2HCB · BA4UAX · BD3QID · BA7KSM · BH7GZB**（改完推送即生效，通常无需发版）。

| 要改的东西 | 位置 |
|---|---|
| 谁拥有哪个徽章 | `docs/members.json`（真源） |
| App 离线兜底 | `lib/early_member.dart` 的 `_seedDefaults`（两处：honors + primary） |
| 官网荣誉墙离线兜底 | `docs/member-card.html` 的 `PEOPLE`（**`honors` 必须显式写**） |
| App「关于页 → 代码贡献」那一行 | `lib/about_page.dart` |
| 官网三语首页「贡献者」区 | `docs/index.html` · `docs/zh-TW/index.html` · `docs/en/index.html` |

> `lib/` 下的改动**要发版才生效**；`docs/` 下的推送后约 1 分钟生效。
> 也就是说：**只给某人追加已有徽章**，改 `members.json` 就够；
> 但要在 App 里看到新的一行，得等下一版。

---

## 五、提交前自查（智能体请逐条走）

```bash
# 1) 静态检查：CI 跑的那 17 条 + 2 条算法回归
for s in android_res_ids backup_keys beacon_track const_colors cross_imports \
         frame_cost hr_garmin ipa_packaging l10n_sync landscape_layout \
         material_coverage notice pos_quality release_notes transition_backdrop \
         ui_wiring widget_members; do python3 tool/check_$s.py || echo "❌ $s"; done
python3 tool/sim_selffix.py --check && python3 tool/sim_turn_dot.py --check

# 2) CI **不跑**、但改到就得自己跑的（官网 / 引导 / 教程页）
python3 tool/check_site.py      # 官网三语：结构 / 链接 / 版本号是否出现在首页
python3 tool/check_guides.py    # 功能引导表 ↔ 6 语言 ↔ 产物 ↔ 页面接入点

# 3) 改了 arb 或 CHANGELOG 时
python3 tool/check_l10n_sync.py       # arb ↔ 提交进 git 的 gen-l10n 产物
python3 tool/check_release_notes.py   # Release 正文能否抽全（中英双语）

# 4) 本机不跑 flutter test / 大构建（机器内存吃紧，会把同机服务搞崩）——
#    编译与 analyze 一律交给 CI
```

**易错点（都是真实踩过的）**

- 改了 `.arb` 忘了同步 `lib/l10n/app_localizations*.dart`：**CI 全绿**（`pub get` 会重新生成
  产物把问题盖住），只有本机 `check_l10n_sync.py` 报红。加键请用
  `tool/add_l10n_keys.py`（同时写 arb + 抽象类 + 6 个产物），别手写产物。
- 在 HTML 文案里写 `<platform>` 这类尖括号：`check_site.py` 会当场报
  `mismatch </div> vs <platform>`（生成器把文案插进了 DOM）。
- 生成器里英文文案的引号嵌套（`page's "X"`）会让 Python 报
  `unterminated string literal`。
- 版本号只在**发版时**动，且只动 `tool/sync_version.py` 管的那几处。

---

## 六、相关文档

| 文档 | 内容 |
|---|---|
| [`CONTRIBUTING.md`](CONTRIBUTING.md) | 人类贡献流程、翻译 / 本地化指南、术语对照 |
| [`HONORS.md`](HONORS.md) | 授予荣誉、新增称号的完整流程（7 处登记点 + 校验清单） |
| [`HONORS-TECH.md`](HONORS-TECH.md) | 荣誉数据的解析 / 查询 / 缓存链路 |
| [`HONORS-GUIDE.md`](HONORS-GUIDE.md) | **面向用户**：荣誉怎么获得 |
| [`CHANGELOG.md`](CHANGELOG.md) | 更新日志（**中英双语**，Release 正文来源） |
