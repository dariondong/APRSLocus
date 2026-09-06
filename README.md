<div align="center">

<img src="docs/assets/logo.png" alt="APRSlocus" width="200" height="200" style="border-radius:20px;"/>

# APRSlocus

**APRS 定位追踪与地图 · APRS Tracking & Mapping**

专为业余无线电爱好者打造的轻量级 APRS 客户端 —— 实时定位、台站追踪、消息收发、地图显示，一站式掌握电波世界的一举一动。

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20Windows%20%7C%20iOS%20%7C%20Linux%20%7C%20macOS%20%7C%20Web-lightgrey.svg)]()
[![Version](https://img.shields.io/badge/Version-1.6.18-green.svg)]()
[![Flutter](https://img.shields.io/badge/Flutter-3.x-blueviolet.svg)](https://flutter.dev)

作者：[BG7LZQ (Darion)](https://theez.top) · 官网：[aprslocus.theez.top](https://aprslocus.theez.top/) · 最新版发布：[GitHub Releases](https://github.com/dariondong/APRSLocus/releases)

**🌐 语言 / Language：** [简体中文](README.md) · [English](README.en.md) · [繁體中文](README.zh-TW.md)

</div>

---

## 📖 目录

- [✨ 核心特性](#-核心特性)
- [🖥️ 支持平台](#️-支持平台)
- [📥 下载安装](#-下载安装)
- [🚀 快速上手](#-快速上手)
- [📚 使用指南](#-使用指南)
- [📡 信标与符号](#-信标与符号)
- [⚙️ 技术栈](#️-技术栈)
- [🗂️ 项目结构](#️-项目结构)
- [🔨 从源码构建](#-从源码构建)
- [❓ 常见问题](#-常见问题)
- [🙏 致谢与贡献](#-致谢与贡献)
- [💬 社区与反馈](#-社区与反馈)
- [📄 许可证](#-许可证)

---

## ✨ 核心特性

### 🗺️ 实时地图追踪
- **多地图类型**：高德普通 / 高德卫星 / 矢量地图 / Carto（浅色·深色·航行者）/ OSM（标准·人道）/ OpenTopo 地形 / Esri（街道·影像），设置页一键切换
- **矢量地图**：基于 `flutter_map` + `vector_map_tiles` 客户端实时渲染，数据量小、缩放清晰、**无需 API Key**，坐标为 WGS-84，支持显示我的轨迹与选中台站轨迹
- **高德瓦片（GCJ-02）**：国内定位无缝对齐，内置 WGS-84 ↔ GCJ-02 坐标转换
- **实时台站显示**：所有台站位置一目了然，在线 / 移动 / 静止 / 离线状态以绿 / 蓝 / 黄 / 灰区分，活跃台站带脉冲动画
- **台站聚合（Clustering）**：台站较多时按网格聚合成聚合球（显示数量，点击放大展开），显著降低渲染卡顿，可随时开关
- **自身轨迹**：地图显示我的位置移动轨迹（蓝色轨迹线，最多 200 个点）
- **台站轨迹**：选中台站的历史移动轨迹以彩色折线绘制
- **呼号标签**：地图 Marker 直接显示台站呼号
- **聚焦定位**：从台站列表 / 详情一键跳转地图并居中定位该台站，支持平滑缩放动画与"覆盖全部台站"

### 📡 位置信标
- 一键上报位置，支持自定义信标备注内容
- 完整 APRS 1.0 标准格式，兼容主流 APRS 软件
- 自动附带高度、速度、航向、手机电量等信息（可配置）
- 可调上报间隔，首页实时显示下次上报倒计时与已发信标数
- 未定位时也可使用**演示模式**体验完整功能

### 💬 消息通信
- **单聊 + 群聊统一会话列表**，像聊天一样收发消息
- 完整消息确认（ACK）机制，支持自动应答与中文消息
- 群聊广播使用 no-ack 格式，避免成员自动 ack 刷屏
- 群聊完整生命周期：建群、邀请、确认加入、成员管理、离开
- 群聊邀请弹窗、成员加入 / 离开系统通知
- 新消息顶部气泡提示 + 未读角标
- 消息历史自动保存，重启不丢失
- 兼容中文 APRS 消息（UTF-8 / GBK 自动解码）

### 🚒 台站识别
- 自动识别 **FMO（机动消防）** 台站
- 同款 **APRSlocus** 台站自动标记（备注含 `APRSlocus`），显示版本 / 电量 / 高度等专属信息
- **官方 APRS 设备识别**：接入 aprs.org 官方设备库 `aprsorg/aprs-deviceid`（tocalls），通过数据包目的呼号识别台站所用 厂商 + 型号 + 设备类别（车台 / 手台 / 跟踪器 / App / 软件 / iGate / 中继 / 气象站…），内置设备库快照 + 联网自动更新
- 支持 **37 个官方符号表、3571 个标准图标**，官方 PNG 图标优先、Material 图标兜底

### 🛰️ 台站列表与详情
- **多维筛选**：状态（在线 / 移动 / 静止）、APRS 类型（车载 / 固定 / 中继 / 气象）、软件（APRSlocus）、设备类别与具体设备型号（官方 tocalls 识别）、国家 / 地区接收筛选、收藏；单行 chips 即点即筛
- **智能搜索**：按呼号 / 类型 / 备注 / 网格 / 设备名实时搜索（防抖，台站多也不卡）
- **多种排序**：呼号 / 最近听到 / 距离 / 状态
- **详情页**：经纬度、Maidenhead 网格、速度、高度、航向、与我距离与方位角、天气数据、移动轨迹、转发路径可视化（箭头串联各跳段，中继台可点击跳转）、最近原始数据包
- **快捷操作**：复制坐标 / 网格、在地图显示、导航到该台站、在线查看（QRZ 呼号库 / aprs.fi 位置轨迹）

### 📦 数据包与日志
- **原始数据包查看**：等宽字体展示 + 时间戳，长按复制
- **解析列表模式**：位置 / 消息 / 气象 / 状态 / 物体分类展示，支持类型筛选与全文搜索
- **调试日志页**：分级日志（调试 / 信息 / 警告 / 错误），一键复制 / 清空，便于排查

### ⚡ 连接与后台
- **APRS-IS 公共服务器自动连接**，后台保持在线
- TCP 直连（桌面 / 移动）与 WebSocket（Web 平台）双实现
- 默认服务器 `rotate.aprs2.net:14580`，解析 `# logresp` 验证登录，Passcode 未验证时主页黄色警告横幅
- **渐进式重连**（8 → 16 → 32 → 60 秒）
- **Android 前台定位服务**：GPS 持续上报 + 系统通知，通知栏可直接"连接 / 断开"服务器、一键"退出"应用
- 收到消息 / 群聊事件推送系统通知
- 按国家 / 地区接收台站筛选，按经纬度 + 半径过滤接收范围（50 / 100 / 200 / 500 / 1000 / 2000 km 快捷预设）

### 🎨 个性化与体验
- **多语言**：简体中文 / 繁體中文 / English / 跟随系统，首次启动可选
- **深色模式** + 自定义主题色，即时生效
- **界面缩放**（85% ~ 130%，滑块 + 预设快捷），一键重新加载界面
- **六步引导向导（OOBE）**：语言 → 欢迎 → 呼号 / SSID → 符号 → 接收筛选 → 服务器连接，上手零门槛
- 详情页 / 设置页丰富的交互彩蛋

### 🚀 自动更新
- 应用内检查更新，支持 **GitHub / GitCode** 双渠道切换
- 智能版本比较，自动按平台分流（Android 下载 APK、Windows 下载 EXE）
- 独立下载进度、历史版本列表、一键安装 / 运行安装程序
- Android 自动引导开启"安装未知来源"权限

---

## 🖥️ 支持平台

| 平台 | 状态 | 说明 |
|------|------|------|
| **Android** | ✅ 完整支持 | 最低 Android 5.0，APK 直装 |
| **Windows** | ✅ 完整支持 | 绿色单文件 EXE + Inno Setup 安装包 |
| **iOS** | 🧪 可构建 | CI 已支持编译（无签名验证），需自行签名部署 |
| **Linux** | 🔧 工程就绪 | Flutter Linux runner 已配置 |
| **macOS** | 🔧 工程就绪 | Flutter macOS runner 已配置 |
| **Web** | 🔧 工程就绪 | WebSocket 连接 APRS-IS，自动定位暂未支持（可手动输入坐标） |

> 最新测试版安装包请在 [GitHub Releases](https://github.com/dariondong/APRSLocus/releases) 页面获取。

---

## 📥 下载安装

### Android
1. 下载 `APRSLocus_<版本号>.apk`
2. 允许"安装未知来源"后安装
3. 最低支持 Android 5.0

### Windows
1. 下载 `APRSlocus-<版本号>-setup.exe`（Inno Setup 安装包）或绿色单文件 EXE
2. 双击即用，无需额外依赖

---

## 🚀 快速上手

首次启动会进入 **6 步引导向导**，全程可视化：

| 步骤 | 内容 |
|------|------|
| 1️⃣ | 选择界面语言（简体中文 / 繁體中文 / English / 跟随系统） |
| 2️⃣ | 欢迎页：了解核心功能，建议先试用**演示模式** |
| 3️⃣ | 输入你的业余无线电**呼号**（如 `BG7LZQ-3`）并选择 **SSID 后缀**（移动端建议 `3`，手持台建议 `7`） |
| 4️⃣ | 选择代表台站类型的**符号**（汽车 / 房屋 / 人 / 卡车 / 自行车 / 房车 / 气象站 / 警局） |
| 5️⃣ | 按国家 / 地区选择**接收台站**（默认中国），可开启"其他台站"接收中继 / 气象 / FMO / APRSlocus |
| 6️⃣ | 配置服务器与 **Passcode**，完成即自动连接 APRS-IS 并开始上报位置 |

> **关于 Passcode**：密码填 `-1` 即可连接，但**未验证的 Passcode 无法正常收发消息**。建议到 [APRS Passcode 查询](https://aprs.cool/AprsPG) 生成你的专属 Passcode 并填入。

完成引导后，应用会自动连接 APRS-IS 服务器并开始上报位置、接收周边台站。

---

## 📚 使用指南

### 🗺️ 地图页
- 切换地图类型：设置 → 显示 → 地图类型（高德 / 高德卫星 / 矢量 / Carto 系列 / OSM 系列 / OpenTopo / Esri）
- 开启台站聚合：地图控制栏聚合开关
- 显示 / 隐藏自身轨迹与选中台站轨迹
- 顶部搜索框按呼号快速定位台站，点击台站 Marker 查看详情

### 🛰️ 台站页
- 顶部筛选芯片：全部 / 在线 / 移动 / 静止 / 离线、移动 / 固定 / 中继 / 气象 / FMO / APRSlocus
- 点击台站进入详情页，查看完整信息、轨迹与转发路径
- 收藏常用台站，快速访问

### 💬 消息页
- 会话列表：群聊（橙色群图标 +「群」标签）与单聊合并展示
- 单聊：直接输入发送，自动带消息确认
- 群聊：两步向导建群（先填名称 → 再选成员 / 先选人 → 再填内容）
- 收到群聊邀请时自动弹窗，可接受 / 拒绝

### 📦 数据包页
- 原始模式：查看完整 APRS 报文，长按复制
- 解析模式：按类型筛选 + 搜索，直观理解协议字段
- 数据包历史自动保存，支持分平台删除管理

### ⚙️ 设置页
| 分区 | 主要选项 |
|------|----------|
| **电台** | 呼号、SSID、符号、备注、显示信息、网格、当前位置 |
| **定位 / 信标** | GPS 来源、信标开关、上报间隔、上报内容（速度 / 航向 / 电量）、手动定位、地图选点 |
| **连接** | 服务器地址、端口、Passcode、WebSocket URL、接收范围过滤（经纬度 + 半径）、最大台站数 |
| **显示** | 深色模式、自定义主题色、语言切换、界面缩放、重新加载界面、地图类型 |
| **数据** | 数据包 / 台站 / 消息历史管理 |
| **高级** | 开发者模式、重新运行设置向导、调试日志、检查更新 |

---

## 📡 信标与符号

### 信标示例

APRSlocus 发送的位置信标遵循 APRS 1.0 标准：

```
BG7LZQ-3>APALOC,TCPIP*:!2148.90N/11049.14E/> /A=000328 090/050 Bat:70% APRSlocus v1.6.18
```

- 路径中的 `APALOC` 标识本台站使用 APRSlocus 软件
- 备注自动附带高度（`/A=000328`）、航向 / 速度（`090/050`）、电量（`Bat:70%`）

### 符号说明

| 符号 | 含义 | 符号 | 含义 |
|------|------|------|------|
| `>` | 汽车 | `-` | 房屋 |
| `[` | 人 | `k` | 卡车 |
| `b` | 自行车 | `R` | 房车 |
| `W` | 气象站 | `!` | 警局 |
| `i` | FMO 台站 | `'` | 小型飞机 |

完整支持 **37 个官方符号表、3571 个标准图标**，均以内置官方 PNG 展示。

---

## ⚙️ 技术栈

| 类别 | 技术 |
|------|------|
| **框架** | [Flutter](https://flutter.dev)（Dart 3.x） |
| **地图** | [高德地图](https://lbs.amap.com)（瓦片）、[flutter_map](https://pub.dev/packages/flutter_map)、[vector_map_tiles](https://pub.dev/packages/vector_map_tiles)、Carto、OpenStreetMap、OpenTopoMap、Esri ArcGIS |
| **网络** | APRS-IS（TCP Socket / WebSocket） |
| **协议** | APRS 1.0（位置 / 消息 / 气象 / 状态 / 物体 / Mic-E 等） |
| **定位** | Android FusedLocationProvider + 前台服务 |
| **国际化** | flutter_localizations + ARB（简体中文 / 繁體中文 / English） |
| **CI / 发版** | GitHub Actions（Windows / Android / iOS 构建 + Release 自动发版） |

---

## 🗂️ 项目结构

```
APRSLocus/
├── lib/                      # Flutter 应用源码
│   ├── main.dart             # 入口
│   ├── app.dart              # 应用根组件（主题 / 语言 / 缩放）
│   ├── home_page.dart        # 主界面（5 Tab：地图 / 台站 / 消息 / 数据包 / 设置）
│   ├── map_page.dart         # 地图页
│   ├── vector_map.dart       # 矢量地图（flutter_map）
│   ├── tile_map.dart         # 瓦片地图（高德 / Carto / OSM / OpenTopo / Esri）
│   ├── stations_page.dart    # 台站列表
│   ├── station_detail.dart   # 台站详情
│   ├── messages_page.dart    # 消息页（单聊 + 群聊）
│   ├── packets_page.dart     # 原始数据包页
│   ├── log_page.dart         # 调试日志页
│   ├── oobe_page.dart        # 首次启动引导向导
│   ├── settings_page.dart    # 设置首页
│   ├── settings_pages.dart   # 各设置子页
│   ├── check_update_page.dart# 检查更新页
│   ├── about_page.dart       # 关于页
│   ├── sponsor_page.dart     # 赞助与鸣谢页
│   ├── state.dart            # 全局状态（连接 / 信标 / 消息 / 设置）
│   ├── models.dart           # 数据模型（台站 / 消息 / 群聊 / 符号）
│   ├── services.dart         # 定位服务 + APRS 包格式化
│   ├── aprs_parse.dart       # APRS 报文解析
│   ├── coord.dart            # WGS-84 / GCJ-02 坐标转换
│   ├── theme.dart            # 主题与样式
│   ├── l10n/                 # 国际化资源（中 / 英）
│   └── net/                  # APRS-IS 连接器（TCP / WebSocket）
├── android/                  # Android 工程
├── ios/                      # iOS 工程
├── linux/                    # Linux 工程
├── macos/                    # macOS 工程
├── windows/                  # Windows 工程
├── web/                      # Web 工程
├── assets/                   # 资源（符号图标 / 地图页 / Logo 等）
├── APRSicon/                 # APRS 官方符号图标库（37 表 3571 图标）
├── tool/                     # 构建 / 版本同步脚本
├── .github/workflows/        # CI：构建发版 + 测试
├── installer.iss             # Inno Setup 安装脚本
├── pubspec.yaml              # 依赖与资源声明
└── CHANGELOG.md              # 更新日志
```

---

## 🔨 从源码构建

### 环境要求
- Flutter 3.x（stable 通道）
- Dart SDK ^3.13.1
- Android：JDK 17、Android SDK
- Windows：Visual Studio（C++ 桌面开发）、[Inno Setup](https://jrsoftware.org/isinfo.php)（打包安装程序）

### 通用步骤
```bash
git clone https://github.com/dariondong/APRSLocus.git
cd APRSLocus
flutter pub get
```

### 构建 Windows 安装包
```bash
flutter build windows --release
# 使用 Inno Setup 打包（版本号自动跟随 pubspec.yaml）
ISCC /DMyAppVersion=1.6.18 installer.iss
```

### 构建 Android APK
```bash
flutter build apk --release
# 产物：build/app/outputs/flutter-apk/app-release.apk
```

### 一键打包（Windows PowerShell）
```bash
# 自动同步版本 + 构建 APK / 安装包 + Inno Setup 打包
./tool/build_all.ps1
```

### iOS（无签名编译）
```bash
flutter build ios --release --no-codesign
```

### 版本号
- 应用版本统一维护于 `pubspec.yaml`（`version: 1.6.18+10618`）
- 打 `v*` tag 推送后，[GitHub Actions](.github/workflows/build-release.yml) 自动构建 Windows / Android / iOS 并发布 Release，更新日志自动从 `CHANGELOG.md` 提取

---

## ❓ 常见问题

<details>
<summary><b>Q：为什么收不到消息 / 无法收发消息？</b></summary>

绝大多数情况是 **Passcode 未验证**。密码填 `-1` 只能连接，不能正常收发消息。请到 [APRS Passcode 查询](https://aprs.cool/AprsPG) 生成自己的 Passcode 并填入"连接设置"。登录后若服务器返回 `unverified`，主页顶部会出现黄色警告横幅，点击"去设置"即可直达修改。
</details>

<details>
<summary><b>Q：Passcode 该怎么设置？</b></summary>

在 OOBE 第 6 步或"设置 → 连接"中，用你的**完整呼号（含 SSID 后缀，如 BG7LZQ-3）**查询生成 Passcode 后填入即可。
</details>

<details>
<summary><b>Q：连接失败 / 频繁掉线？</b></summary>

应用内置渐进式重连（8 → 16 → 32 → 60 秒）。若持续失败，请检查网络、确认服务器地址（默认 `rotate.aprs2.net:14580`）与端口是否被拦截，或在"连接设置"中更换服务器后点击"重新连接"。
</details>

<details>
<summary><b>Q：手机上收不到周边台站？</b></summary>

检查"接收筛选"是否勾选了目标国家 / 地区，并确认接收范围（经纬度 + 半径）覆盖你的位置。默认只接收中国（B 开头）台站。
</details>

<details>
<summary><b>Q：后台定位会一直耗电吗？</b></summary>

Android 端使用前台服务持续定位以保持 APRS 在线，可在"定位 / 信标"设置中调整上报间隔，或关闭信标上报、按需手动上报来降低耗电。通知栏可一键"退出"应用。
</details>

<details>
<summary><b>Q：Windows 上地图显示异常？</b></summary>

建议在"显示 → 地图类型"中切换为**矢量地图**（无需 API Key，兼容性最好）；或切换到 Carto / OSM / Esri 等国际图源。
</details>

<details>
<summary><b>Q：覆盖安装提示签名冲突 / 版本降级？</b></summary>

自 1.5.2 起 Android 使用正式 release 签名，CI 与本地签名一致，直接覆盖安装即可。若从更老版本升级，请卸载后重装。
</details>

---

## 🙏 致谢与贡献

- [高德地图](https://lbs.amap.com) — 地图瓦片 / JS API 服务
- [APRS-IS](https://aprs-is.net) — 全球 APRS 数据网络
- [flutter_map](https://pub.dev/packages/flutter_map) / [vector_map_tiles](https://pub.dev/packages/vector_map_tiles) — 矢量地图渲染
- [OpenFreeMap](https://openfreemap.org) — 免费矢量瓦片底图
- **BD3QID** — 国际化（i18n）贡献
- **BA4UAX** — 繁体中文翻译
- **清零（BG2HCB）** — 设置页代码优化
- **测试成员**：BG7PGW、BG7LMW、BG7OSL、BD3QID
- **AI 算力支持**：BA3RZL 养生
- 所有业余无线电爱好者的支持与反馈

如果你觉得本项目有帮助，欢迎 **Star** 支持；也欢迎通过 Issue / PR 参与贡献。赞助支持请见应用内"关于 → 赞助与鸣谢"（微信赞赏码）。

---

## 💬 社区与反馈

| 渠道 | 地址 |
|------|------|
| **GitHub 仓库** | https://github.com/dariondong/APRSLocus |
| **官网** | https://aprslocus.theez.top/ |
| **GitCode 仓库** | https://gitcode.com/DarionDong/APRSLocus |
| **作者网站** | https://theez.top |
| **QQ 交流群** | https://qm.qq.com/q/8pL6vc5YA0 |

---

> **免责声明**：本软件仅供业余无线电爱好者学习交流使用，请遵守当地无线电管理法规，取得合法操作资格后使用。

---

## 📄 许可证

本项目采用 [GNU General Public License v3.0](LICENSE) 开源协议。

Copyright (C) BG7LZQ (Darion)

本程序为自由软件：你可以依据自由软件基金会发布的 GNU 通用公共许可证第 3 版或（依你的选择）任何更新版本重新分发和/或修改本程序。

本程序以希望其有用的方式分发，但不带任何保证；甚至没有隐含的适销性或特定用途适用性保证。详见 [GNU 通用公共许可证](LICENSE)。
