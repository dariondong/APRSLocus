# 贡献指南 Contributing Guide

感谢你对 **APRSlocus** 的关注！本项目是业余无线电 APRS 客户端，代码、文档、官网与多语言都欢迎贡献。

> 🌐 你主要想帮忙**翻译 / 本地化**？直接跳到 → [📝 翻译 / 本地化贡献指南](#-翻译--本地化贡献指南)

---

## 📋 总览

| 内容 | 位置 | 说明 |
|------|------|------|
| Flutter 应用源码 | `lib/` | Dart |
| 本地化字符串 | `lib/l10n/*.arb` | 简体中文为模板（`app_zh.arb`），另含 `app_en.arb`、`app_zh_TW.arb` |
| 生成/维护的 l10n Dart | `lib/l10n/app_localizations*.dart` | 由 arb 生成（模板 `app_zh.arb`），一般**不需要手改** |
| README | `README.md` / `README.en.md` / `README.zh-TW.md` | 三语 |
| 官网 | `docs/` | GitHub Pages：`docs/index.html`(简中)、`docs/en/`、`docs/zh-TW/` |
| 更新日志 | `CHANGELOG.md` | 顶部为最新版 |

---

## 🚀 快速开始（代码 PR）

1. Fork 仓库，切新分支：`git checkout -b feat/你的改动`
2. 提交前先 `flutter analyze` 通过
3. PR 描述清楚改动目的；若涉及 UI 最好附带截图
4. 提交信息用约定式（`feat:` / `fix:` / `docs:` / `chore:` / `refactor:`）

CI 会在 push 后自动跑：`flutter analyze` + Windows / Android 构建。

---

## 📝 翻译 / 本地化贡献指南

### 一、语言文件放在哪

所有界面文案在 **ARB 文件**中，路径 `lib/l10n/`：

```
lib/l10n/
├── app_zh.arb        # 简体中文 —— 模板语言（基准，新增键先加这里）
├── app_zh_TW.arb     # 繁體中文
├── app_en.arb        # English
└── （未来新语言：app_xx.arb）
```

- **模板是简体中文**：所有键以 `app_zh.arb` 为准。新增一个界面文案时，先在 `app_zh.arb` 加键，再同步到其它语言。
- **键名规范**：小驼峰，按功能前缀（如 `beaconInterval`、`oobeWelcomeTitle`）；描述性命名，不用缩写。
- **带参数文案**用 `{占位符}`，例如：
  ```json
  "nextBeaconIn": "下次上报：{time}"
  ```
  对应 Dart 里为方法 `nextBeaconIn(String time)`，不要当普通字符串用。

### 二、改一个已有文案

以「把英文 OK 改成别的」为例 —— 不要只改某个语言，三个语言文件都应存在同键：

1. 打开 `lib/l10n/app_en.arb`，找到对应键改值
2. 确认 `app_zh.arb` / `app_zh_TW.arb` 同样有该键（若模板缺，先补模板）
3. 生成/同步：
   ```bash
   flutter gen-l10n
   ```
   会基于 `l10n.yaml` 重新生成 `lib/l10n/app_localizations*.dart`
4. `flutter analyze` 验证无报错

> ⚠️ 若你不会本地生成：**只提交改好的 `.arb` 文件即可**，维护者合并后会统一跑 `flutter gen-l10n`。**不要手动去改 `app_localizations*.dart`**，避免与生成结果冲突。

### 三、新增一个界面文案（新键）

1. 在 `app_zh.arb`（模板）加键 + 中文值（可按需加 `@key` 描述注释）
2. 在 `app_en.arb`、`app_zh_TW.arb` 加入**同键**翻译
3. 若只是 UI 用，生成后即可在代码里 `S.of(context).yourKey` 使用
4. 若键带占位符 → 生成后是方法（带参数），用法见上

### 四、新增一种语言（例如 日本語 / Deutsch）

1. 新建 `lib/l10n/app_ja.arb`（以 `app_zh.arb` 为蓝本，把所有 value 翻译成日语，保留键名与 `{占位符}`）
2. 跑 `flutter gen-l10n` 生成 `app_localizations_ja.dart` 与分派逻辑
3. 在 `lib/app.dart` 的 `supportedLocales` 与语言选择器加入该语言
4. `lib/l10n/app_localizations.dart` 的 `lookupAppLocalizations` 增加 case
5. README 三语 + 官网语言切换补该语言入口（可选）
6. PR 里**说明语言代码与主要使用地区**（如 `ja`/`de`…）；若是区域变体（如繁体中文用 `zh_TW`）请附带确认

> 💡 新语言工作量参考：当前模板约 920+ 个键。**强烈建议 fork 后对照 `app_zh.arb` 一行行翻译**，用机器翻译初稿也可以，但请人工检查术语。

### 五、术语对照（务必一致）

翻译时保持一致，避免同一功能多个叫法。常用词：

| 简体 | 繁體 | English | 说明 |
|------|------|---------|------|
| 台站 | 臺站 | station | APRS 中的“电台/节点” |
| 信标 | 信標 | beacon | 定时位置上报 |
| 上报 | 上報 | report / beacon | 发送位置 |
| 移动 | 移動 | moving | 移动中 |
| 静止 | 靜止 | stationary | 已停 |
| 车载 | 車載 | mobile | 车载台（符号 `>`） |
| 固定 | 固定 | fixed | 固定台 |
| 中继 | 中繼 | digipeater | 数字中继 |
| 气象站 | 氣象站 | weather station | |
| 接收筛选 | 接收篩選 | receive filter | 按国家/范围收台 |
| 目的呼号 | 目的呼號 | to-call | 设备识别用 |
| 群聊 | 群聊 | group chat | |
| 位置未上报 | 位置未上報 | position not reported | 连接后未自动上报 |

> APRS 术语若拿不准，可在 PR 讨论里 @ 维护者；或先看英文 `app_en.arb` 的对应写法保持一致。

### 六、翻译 PR 检查清单

- [ ] 所有改动只涉及 `.arb`（或合理附带语言选择器）
- [ ] 键名 / `{占位符}` 未变，只翻译了 value
- [ ] 模板 `app_zh.arb` 与目标语言键数量一致（可用脚本对比）
- [ ] 没有把品牌/呼号/URL/代码块翻译掉
- [ ] 提交信息示例：`docs(i18n): add Japanese (ja) translation` / `docs(i18n): refine zh_TW wording`

---

## 🌍 README / 官网翻译

- README：三语文件（`README.md` 简中 / `README.en.md` 英 / `README.zh-TW.md` 繁），改内容时三份尽量同步
- 官网 `docs/`：`index.html`(简中根)、`en/index.html`、`zh-TW/index.html` 以及各自 `terms.html`；页面顶部有语言切换组。新增语言需在三个现有页面加切换入口 + `docs/<lang>/`
- 协议文本：`docs/assets/terms_zh.txt`、`terms_en.txt`、`terms_zh_TW.txt`（繁体）——官网与 App 共用

---

## 🙏 致谢

翻译贡献者会列入应用内「关于 → 赞助与鸣谢」与 README 致谢区。感谢让 APRSlocus 走向更多语言社区的你！
