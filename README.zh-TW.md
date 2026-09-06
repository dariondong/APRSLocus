<div align="center">

<img src="docs/assets/logo.png" alt="APRSlocus" width="200" height="200" style="border-radius:20px;"/>

# APRSlocus

**APRS 定位追蹤與地圖 · APRS Tracking & Mapping**

專為業餘無線電愛好者打造的輕量級 APRS 客戶端 —— 實時定位、臺站追蹤、消息收發、地圖顯示，一站式掌握電波世界的一舉一動。

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20Windows%20%7C%20iOS%20%7C%20Linux%20%7C%20macOS%20%7C%20Web-lightgrey.svg)]()
[![Version](https://img.shields.io/badge/Version-1.6.18-green.svg)]()
[![Flutter](https://img.shields.io/badge/Flutter-3.x-blueviolet.svg)](https://flutter.dev)

作者：[BG7LZQ (Darion)](https://theez.top) · 官網：[aprslocus.theez.top](https://aprslocus.theez.top/) · 最新版發布：[GitHub Releases](https://github.com/dariondong/APRSLocus/releases)

**🌐 語言 / Language：** [簡體中文](README.md) · [English](README.en.md) · [繁體中文](README.zh-TW.md)

</div>

---

## 📖 目錄

- [✨ 核心特性](#-核心特性)
- [🖥️ 支持平臺](#️-支持平臺)
- [📥 下載安裝](#-下載安裝)
- [🚀 快速上手](#-快速上手)
- [📚 使用指南](#-使用指南)
- [📡 信標與符號](#-信標與符號)
- [⚙️ 技術棧](#️-技術棧)
- [🗂️ 項目結構](#️-項目結構)
- [🔨 從源碼構建](#-從源碼構建)
- [❓ 常見問題](#-常見問題)
- [🙏 致謝與貢獻](#-致謝與貢獻)
- [💬 社區與反饋](#-社區與反饋)
- [📄 許可證](#-許可證)

---

## ✨ 核心特性

### 🗺️ 實時地圖追蹤
- **多地圖類型**：高德普通 / 高德衛星 / 矢量地圖 / Carto（淺色·深色·航行者）/ OSM（標準·人道）/ OpenTopo 地形 / Esri（街道·影像），設置頁一鍵切換
- **矢量地圖**：基於 `flutter_map` + `vector_map_tiles` 客戶端實時渲染，數據量小、縮放清晰、**無需 API Key**，坐標為 WGS-84，支持顯示我的軌跡與選中臺站軌跡
- **高德瓦片（GCJ-02）**：國內定位無縫對齊，內置 WGS-84 ↔ GCJ-02 坐標轉換
- **實時臺站顯示**：所有臺站位置一目了然，在線 / 移動 / 靜止 / 離線狀態以綠 / 藍 / 黃 / 灰區分，活躍臺站帶脈衝動畫
- **臺站聚合（Clustering）**：臺站較多時按網格聚合成聚合球（顯示數量，點擊放大展開），顯著降低渲染卡頓，可隨時開關
- **自身軌跡**：地圖顯示我的位置移動軌跡（藍色軌跡線，最多 200 個點）
- **臺站軌跡**：選中臺站的歷史移動軌跡以彩色折線繪製
- **呼號標籤**：地圖 Marker 直接顯示臺站呼號
- **聚焦定位**：從臺站列表 / 詳情一鍵跳轉地圖並居中定位該臺站，支持平滑縮放動畫與"覆蓋全部臺站"

### 📡 位置信標
- 一鍵上報位置，支持自定義信標備註內容
- 完整 APRS 1.0 標準格式，兼容主流 APRS 軟體
- 自動附帶高度、速度、航向、手機電量等信息（可配置）
- 可調上報間隔，首頁實時顯示下次上報倒計時與已發信標數
- 未定位時也可使用**演示模式**體驗完整功能

### 💬 消息通信
- **單聊 + 群聊統一會話列表**，像聊天一樣收發消息
- 完整消息確認（ACK）機制，支持自動應答與中文消息
- 群聊廣播使用 no-ack 格式，避免成員自動 ack 刷屏
- 群聊完整生命周期：建群、邀請、確認加入、成員管理、離開
- 群聊邀請彈窗、成員加入 / 離開系統通知
- 新消息頂部氣泡提示 + 未讀角標
- 消息歷史自動保存，重啟不丟失
- 兼容中文 APRS 消息（UTF-8 / GBK 自動解碼）

### 🚒 臺站識別
- 自動識別 **FMO（機動消防）** 臺站
- 同款 **APRSlocus** 臺站自動標記（備註含 `APRSlocus`），顯示版本 / 電量 / 高度等專屬信息
- **官方 APRS 設備識別**：接入 aprs.org 官方設備庫 `aprsorg/aprs-deviceid`（tocalls），通過數據包目的呼號識別臺站所用 廠商 + 型號 + 設備類別（車臺 / 手臺 / 跟蹤器 / App / 軟體 / iGate / 中繼 / 氣象站…），內置設備庫快照 + 聯網自動更新
- 支持 **37 個官方符號表、3571 個標準圖標**，官方 PNG 圖標優先、Material 圖標兜底

### 🛰️ 臺站列表與詳情
- **多維篩選**：狀態（在線 / 移動 / 靜止）、APRS 類型（車載 / 固定 / 中繼 / 氣象）、軟體（APRSlocus）、設備類別與具體設備型號（官方 tocalls 識別）、國家 / 地區接收篩選、收藏；單行 chips 即點即篩
- **智能搜索**：按呼號 / 類型 / 備註 / 網格 / 設備名實時搜索（防抖，臺站多也不卡）
- **多種排序**：呼號 / 最近聽到 / 距離 / 狀態
- **詳情頁**：經緯度、Maidenhead 網格、速度、高度、航向、與我距離與方位角、天氣數據、移動軌跡、轉發路徑可視化（箭頭串聯各跳段，中繼臺可點擊跳轉）、最近原始數據包
- **快捷操作**：複製坐標 / 網格、在地圖顯示、導航到該臺站、在線查看（QRZ 呼號庫 / aprs.fi 位置軌跡）

### 📦 數據包與日誌
- **原始數據包查看**：等寬字體展示 + 時間戳，長按複製
- **解析列表模式**：位置 / 消息 / 氣象 / 狀態 / 物體分類展示，支持類型篩選與全文搜索
- **調試日誌頁**：分級日誌（調試 / 信息 / 警告 / 錯誤），一鍵複製 / 清空，便於排查

### ⚡ 連接與後臺
- **APRS-IS 公共伺服器自動連接**，後臺保持在線
- TCP 直連（桌面 / 移動）與 WebSocket（Web 平臺）雙實現
- 默認伺服器 `rotate.aprs2.net:14580`，解析 `# logresp` 驗證登錄，Passcode 未驗證時主頁黃色警告橫幅
- **漸進式重連**（8 → 16 → 32 → 60 秒）
- **Android 前臺定位服務**：GPS 持續上報 + 系統通知，通知欄可直接"連接 / 斷開"伺服器、一鍵"退出"應用
- 收到消息 / 群聊事件推送系統通知
- 按國家 / 地區接收臺站篩選，按經緯度 + 半徑過濾接收範圍（50 / 100 / 200 / 500 / 1000 / 2000 km 快捷預設）

### 🎨 個性化與體驗
- **多語言**：簡體中文 / 繁體中文 / English / 跟隨系統，首次啟動可選
- **深色模式** + 自定義主題色，即時生效
- **界面縮放**（85% ~ 130%，滑塊 + 預設快捷），一鍵重新加載界面
- **六步引導嚮導（OOBE）**：語言 → 歡迎 → 呼號 / SSID → 符號 → 接收篩選 → 伺服器連接，上手零門檻
- 詳情頁 / 設置頁豐富的交互彩蛋

### 🚀 自動更新
- 應用內檢查更新，支持 **GitHub / GitCode** 雙渠道切換
- 智能版本比較，自動按平臺分流（Android 下載 APK、Windows 下載 EXE）
- 獨立下載進度、歷史版本列表、一鍵安裝 / 運行安裝程序
- Android 自動引導開啟"安裝未知來源"權限

---

## 🖥️ 支持平臺

| 平臺 | 狀態 | 說明 |
|------|------|------|
| **Android** | ✅ 完整支持 | 最低 Android 5.0，APK 直裝 |
| **Windows** | ✅ 完整支持 | 綠色單文件 EXE + Inno Setup 安裝包 |
| **iOS** | 🧪 可構建 | CI 已支持編譯（無籤名驗證），需自行籤名部署 |
| **Linux** | 🔧 工程就緒 | Flutter Linux runner 已配置 |
| **macOS** | 🔧 工程就緒 | Flutter macOS runner 已配置 |
| **Web** | 🔧 工程就緒 | WebSocket 連接 APRS-IS，自動定位暫未支持（可手動輸入坐標） |

> 最新測試版安裝包請在 [GitHub Releases](https://github.com/dariondong/APRSLocus/releases) 頁面獲取。

---

## 📥 下載安裝

### Android
1. 下載 `APRSLocus_<版本號>.apk`
2. 允許"安裝未知來源"後安裝
3. 最低支持 Android 5.0

### Windows
1. 下載 `APRSlocus-<版本號>-setup.exe`（Inno Setup 安裝包）或綠色單文件 EXE
2. 雙擊即用，無需額外依賴

---

## 🚀 快速上手

首次啟動會進入 **6 步引導嚮導**，全程可視化：

| 步驟 | 內容 |
|------|------|
| 1️⃣ | 選擇界面語言（簡體中文 / 繁體中文 / English / 跟隨系統） |
| 2️⃣ | 歡迎頁：了解核心功能，建議先試用**演示模式** |
| 3️⃣ | 輸入你的業餘無線電**呼號**（如 `BG7LZQ-3`）並選擇 **SSID 後綴**（移動端建議 `3`，手持臺建議 `7`） |
| 4️⃣ | 選擇代表臺站類型的**符號**（汽車 / 房屋 / 人 / 卡車 / 自行車 / 房車 / 氣象站 / 警局） |
| 5️⃣ | 按國家 / 地區選擇**接收臺站**（默認中國），可開啟"其他臺站"接收中繼 / 氣象 / FMO / APRSlocus |
| 6️⃣ | 配置伺服器與 **Passcode**，完成即自動連接 APRS-IS 並開始上報位置 |

> **關於 Passcode**：密碼填 `-1` 即可連接，但**未驗證的 Passcode 無法正常收發消息**。建議到 [APRS Passcode 查詢](https://aprs.cool/AprsPG) 生成你的專屬 Passcode 並填入。

完成引導後，應用會自動連接 APRS-IS 伺服器並開始上報位置、接收周邊臺站。

---

## 📚 使用指南

### 🗺️ 地圖頁
- 切換地圖類型：設置 → 顯示 → 地圖類型（高德 / 高德衛星 / 矢量 / Carto 系列 / OSM 系列 / OpenTopo / Esri）
- 開啟臺站聚合：地圖控制欄聚合開關
- 顯示 / 隱藏自身軌跡與選中臺站軌跡
- 頂部搜索框按呼號快速定位臺站，點擊臺站 Marker 查看詳情

### 🛰️ 臺站頁
- 頂部篩選晶片：全部 / 在線 / 移動 / 靜止 / 離線、移動 / 固定 / 中繼 / 氣象 / FMO / APRSlocus
- 點擊臺站進入詳情頁，查看完整信息、軌跡與轉發路徑
- 收藏常用臺站，快速訪問

### 💬 消息頁
- 會話列表：群聊（橙色群圖標 +「群」標籤）與單聊合併展示
- 單聊：直接輸入發送，自動帶消息確認
- 群聊：兩步嚮導建群（先填名稱 → 再選成員 / 先選人 → 再填內容）
- 收到群聊邀請時自動彈窗，可接受 / 拒絕

### 📦 數據包頁
- 原始模式：查看完整 APRS 報文，長按複製
- 解析模式：按類型篩選 + 搜索，直觀理解協議欄位
- 數據包歷史自動保存，支持分平臺刪除管理

### ⚙️ 設置頁
| 分區 | 主要選項 |
|------|----------|
| **電臺** | 呼號、SSID、符號、備註、顯示信息、網格、當前位置 |
| **定位 / 信標** | GPS 來源、信標開關、上報間隔、上報內容（速度 / 航向 / 電量）、手動定位、地圖選點 |
| **連接** | 伺服器地址、埠、Passcode、WebSocket URL、接收範圍過濾（經緯度 + 半徑）、最大臺站數 |
| **顯示** | 深色模式、自定義主題色、語言切換、界面縮放、重新加載界面、地圖類型 |
| **數據** | 數據包 / 臺站 / 消息歷史管理 |
| **高級** | 開發者模式、重新運行設置嚮導、調試日誌、檢查更新 |

---

## 📡 信標與符號

### 信標示例

APRSlocus 發送的位置信標遵循 APRS 1.0 標準：

```
BG7LZQ-3>APALOC,TCPIP*:!2148.90N/11049.14E/> /A=000328 090/050 Bat:70% APRSlocus v1.6.18
```

- 路徑中的 `APALOC` 標識本臺站使用 APRSlocus 軟體
- 備註自動附帶高度（`/A=000328`）、航向 / 速度（`090/050`）、電量（`Bat:70%`）

### 符號說明

| 符號 | 含義 | 符號 | 含義 |
|------|------|------|------|
| `>` | 汽車 | `-` | 房屋 |
| `[` | 人 | `k` | 卡車 |
| `b` | 自行車 | `R` | 房車 |
| `W` | 氣象站 | `!` | 警局 |
| `i` | FMO 臺站 | `'` | 小型飛機 |

完整支持 **37 個官方符號表、3571 個標準圖標**，均以內置官方 PNG 展示。

---

## ⚙️ 技術棧

| 類別 | 技術 |
|------|------|
| **框架** | [Flutter](https://flutter.dev)（Dart 3.x） |
| **地圖** | [高德地圖](https://lbs.amap.com)（瓦片）、[flutter_map](https://pub.dev/packages/flutter_map)、[vector_map_tiles](https://pub.dev/packages/vector_map_tiles)、Carto、OpenStreetMap、OpenTopoMap、Esri ArcGIS |
| **網絡** | APRS-IS（TCP Socket / WebSocket） |
| **協議** | APRS 1.0（位置 / 消息 / 氣象 / 狀態 / 物體 / Mic-E 等） |
| **定位** | Android FusedLocationProvider + 前臺服務 |
| **國際化** | flutter_localizations + ARB（簡體中文 / 繁體中文 / English） |
| **CI / 發版** | GitHub Actions（Windows / Android / iOS 構建 + Release 自動發版） |

---

## 🗂️ 項目結構

```
APRSLocus/
├── lib/                      # Flutter 應用源碼
│   ├── main.dart             # 入口
│   ├── app.dart              # 應用根組件（主題 / 語言 / 縮放）
│   ├── home_page.dart        # 主界面（5 Tab：地圖 / 臺站 / 消息 / 數據包 / 設置）
│   ├── map_page.dart         # 地圖頁
│   ├── vector_map.dart       # 矢量地圖（flutter_map）
│   ├── tile_map.dart         # 瓦片地圖（高德 / Carto / OSM / OpenTopo / Esri）
│   ├── stations_page.dart    # 臺站列表
│   ├── station_detail.dart   # 臺站詳情
│   ├── messages_page.dart    # 消息頁（單聊 + 群聊）
│   ├── packets_page.dart     # 原始數據包頁
│   ├── log_page.dart         # 調試日誌頁
│   ├── oobe_page.dart        # 首次啟動引導嚮導
│   ├── settings_page.dart    # 設置首頁
│   ├── settings_pages.dart   # 各設置子頁
│   ├── check_update_page.dart# 檢查更新頁
│   ├── about_page.dart       # 關於頁
│   ├── sponsor_page.dart     # 贊助與鳴謝頁
│   ├── state.dart            # 全局狀態（連接 / 信標 / 消息 / 設置）
│   ├── models.dart           # 數據模型（臺站 / 消息 / 群聊 / 符號）
│   ├── services.dart         # 定位服務 + APRS 包格式化
│   ├── aprs_parse.dart       # APRS 報文解析
│   ├── coord.dart            # WGS-84 / GCJ-02 坐標轉換
│   ├── theme.dart            # 主題與樣式
│   ├── l10n/                 # 國際化資源（中 / 英）
│   └── net/                  # APRS-IS 連接器（TCP / WebSocket）
├── android/                  # Android 工程
├── ios/                      # iOS 工程
├── linux/                    # Linux 工程
├── macos/                    # macOS 工程
├── windows/                  # Windows 工程
├── web/                      # Web 工程
├── assets/                   # 資源（符號圖標 / 地圖頁 / Logo 等）
├── APRSicon/                 # APRS 官方符號圖標庫（37 表 3571 圖標）
├── tool/                     # 構建 / 版本同步腳本
├── .github/workflows/        # CI：構建發版 + 測試
├── installer.iss             # Inno Setup 安裝腳本
├── pubspec.yaml              # 依賴與資源聲明
└── CHANGELOG.md              # 更新日誌
```

---

## 🔨 從源碼構建

### 環境要求
- Flutter 3.x（stable 通道）
- Dart SDK ^3.13.1
- Android：JDK 17、Android SDK
- Windows：Visual Studio（C++ 桌面開發）、[Inno Setup](https://jrsoftware.org/isinfo.php)（打包安裝程序）

### 通用步驟
```bash
git clone https://github.com/dariondong/APRSLocus.git
cd APRSLocus
flutter pub get
```

### 構建 Windows 安裝包
```bash
flutter build windows --release
# 使用 Inno Setup 打包（版本號自動跟隨 pubspec.yaml）
ISCC /DMyAppVersion=1.6.18 installer.iss
```

### 構建 Android APK
```bash
flutter build apk --release
# 產物：build/app/outputs/flutter-apk/app-release.apk
```

### 一鍵打包（Windows PowerShell）
```bash
# 自動同步版本 + 構建 APK / 安裝包 + Inno Setup 打包
./tool/build_all.ps1
```

### iOS（無籤名編譯）
```bash
flutter build ios --release --no-codesign
```

### 版本號
- 應用版本統一維護於 `pubspec.yaml`（`version: 1.6.18+10618`）
- 打 `v*` tag 推送後，[GitHub Actions](.github/workflows/build-release.yml) 自動構建 Windows / Android / iOS 並發布 Release，更新日誌自動從 `CHANGELOG.md` 提取

---

## ❓ 常見問題

<details>
<summary><b>Q：為什麼收不到消息 / 無法收發消息？</b></summary>

絕大多數情況是 **Passcode 未驗證**。密碼填 `-1` 只能連接，不能正常收發消息。請到 [APRS Passcode 查詢](https://aprs.cool/AprsPG) 生成自己的 Passcode 並填入"連接設置"。登錄後若伺服器返回 `unverified`，主頁頂部會出現黃色警告橫幅，點擊"去設置"即可直達修改。
</details>

<details>
<summary><b>Q：Passcode 該怎麼設置？</b></summary>

在 OOBE 第 6 步或"設置 → 連接"中，用你的**完整呼號（含 SSID 後綴，如 BG7LZQ-3）**查詢生成 Passcode 後填入即可。
</details>

<details>
<summary><b>Q：連接失敗 / 頻繁掉線？</b></summary>

應用內置漸進式重連（8 → 16 → 32 → 60 秒）。若持續失敗，請檢查網絡、確認伺服器地址（默認 `rotate.aprs2.net:14580`）與埠是否被攔截，或在"連接設置"中更換伺服器後點擊"重新連接"。
</details>

<details>
<summary><b>Q：手機上收不到周邊臺站？</b></summary>

檢查"接收篩選"是否勾選了目標國家 / 地區，並確認接收範圍（經緯度 + 半徑）覆蓋你的位置。默認只接收中國（B 開頭）臺站。
</details>

<details>
<summary><b>Q：後臺定位會一直耗電嗎？</b></summary>

Android 端使用前臺服務持續定位以保持 APRS 在線，可在"定位 / 信標"設置中調整上報間隔，或關閉信標上報、按需手動上報來降低耗電。通知欄可一鍵"退出"應用。
</details>

<details>
<summary><b>Q：Windows 上地圖顯示異常？</b></summary>

建議在"顯示 → 地圖類型"中切換為**矢量地圖**（無需 API Key，兼容性最好）；或切換到 Carto / OSM / Esri 等國際圖源。
</details>

<details>
<summary><b>Q：覆蓋安裝提示籤名衝突 / 版本降級？</b></summary>

自 1.5.2 起 Android 使用正式 release 籤名，CI 與本地籤名一致，直接覆蓋安裝即可。若從更老版本升級，請卸載後重裝。
</details>

---

## 🙏 致謝與貢獻

- [高德地圖](https://lbs.amap.com) — 地圖瓦片 / JS API 服務
- [APRS-IS](https://aprs-is.net) — 全球 APRS 數據網絡
- [flutter_map](https://pub.dev/packages/flutter_map) / [vector_map_tiles](https://pub.dev/packages/vector_map_tiles) — 矢量地圖渲染
- [OpenFreeMap](https://openfreemap.org) — 免費矢量瓦片底圖
- **BD3QID** — 國際化（i18n）貢獻
- **BA4UAX** — 繁體中文翻譯
- **清零（BG2HCB）** — 設置頁代碼優化
- **測試成員**：BG7PGW、BG7LMW、BG7OSL、BD3QID
- **AI 算力支持**：BA3RZL 養生
- 所有業餘無線電愛好者的支持與反饋

如果你覺得本項目有幫助，歡迎 **Star** 支持；也歡迎通過 Issue / PR 參與貢獻。贊助支持請見應用內"關於 → 贊助與鳴謝"（微信讚賞碼）。

---

## 💬 社區與反饋

| 渠道 | 地址 |
|------|------|
| **GitHub 倉庫** | https://github.com/dariondong/APRSLocus |
| **官網** | https://aprslocus.theez.top/ |
| **GitCode 倉庫** | https://gitcode.com/DarionDong/APRSLocus |
| **作者網站** | https://theez.top |
| **QQ 交流群** | https://qm.qq.com/q/8pL6vc5YA0 |

---

> **免責聲明**：本軟體僅供業餘無線電愛好者學習交流使用，請遵守當地無線電管理法規，取得合法操作資格後使用。

---

## 📄 許可證

本項目採用 [GNU General Public License v3.0](LICENSE) 開源協議。

Copyright (C) BG7LZQ (Darion)

本程序為自由軟體：你可以依據自由軟體基金會發布的 GNU 通用公共許可證第 3 版或（依你的選擇）任何更新版本重新分發和/或修改本程序。

本程序以希望其有用的方式分發，但不帶任何保證；甚至沒有隱含的適銷性或特定用途適用性保證。詳見 [GNU 通用公共許可證](LICENSE)。
