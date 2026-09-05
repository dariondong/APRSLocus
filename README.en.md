<div align="center">

<img src="docs/assets/logo.png" alt="APRSlocus" width="200" height="200" style="border-radius:20px;"/>

# APRSlocus

**APRS Tracking & Mapping**

A lightweight APRS client built for amateur radio enthusiasts — real-time positioning, station tracking, messaging, and map display, all in one place to keep you in touch with the airwaves.

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20Windows%20%7C%20iOS%20%7C%20Linux%20%7C%20macOS%20%7C%20Web-lightgrey.svg)]()
[![Version](https://img.shields.io/badge/Version-1.6.18-green.svg)]()
[![Flutter](https://img.shields.io/badge/Flutter-3.x-blueviolet.svg)](https://flutter.dev)

Author: [BG7LZQ (Darion)](https://theez.top) · Latest release: [GitHub Releases](https://github.com/dariondong/APRSLocus/releases)

**🌐 Language:** [简体中文](README.md) · [English](README.en.md) · [繁體中文](README.zh-TW.md)

</div>

---

## 📖 Table of Contents

- [✨ Features](#-features)
- [🖥️ Supported Platforms](#-supported-platforms)
- [📥 Download & Install](#-download--install)
- [🚀 Quick Start](#-quick-start)
- [📚 User Guide](#-user-guide)
- [📡 Beacons & Symbols](#-beacons--symbols)
- [⚙️ Tech Stack](#-tech-stack)
- [🗂️ Project Structure](#-project-structure)
- [🔨 Build from Source](#-build-from-source)
- [❓ FAQ](#-faq)
- [🙏 Thanks & Contributing](#-thanks--contributing)
- [💬 Community & Feedback](#-community--feedback)
- [📄 License](#-license)

---

## ✨ Features

### 🗺️ Real-Time Map Tracking
- **Multiple map types**: AMap (Standard / Satellite) / Vector map / Carto (Light · Dark · Voyager) / OSM (Standard · Humanitarian) / OpenTopo terrain / Esri (Streets · Imagery), switchable in Settings with one tap
- **Vector map**: rendered on-device with `flutter_map` + `vector_map_tiles`, low data usage and crisp zooming, **no API key required**, WGS-84 coordinates; supports my track and selected station track
- **AMap tiles (GCJ-02)**: aligns seamlessly for domestic positioning in China, with built-in WGS-84 ↔ GCJ-02 conversion
- **Live station display**: every station at a glance; online / moving / stationary / offline distinguished by green / blue / yellow / grey, active stations pulse-animated
- **Clustering**: stations are grouped into cluster balls (count shown, tap to zoom in) when dense, greatly reducing lag; can be toggled anytime
- **My track**: your own movement trail drawn on the map (blue polyline, up to 200 points)
- **Station track**: selected station's history drawn as colored polyline
- **Callsign labels**: station callsign shown directly on map markers
- **Focus & locate**: jump from station list / detail to the map centered on a station, with smooth zoom animation and "fit all stations"

### 📡 Position Beacons
- One-tap position reporting with customizable comment
- Full APRS 1.0 standard format, compatible with mainstream APRS software
- Automatically attaches altitude, speed, course, battery, etc. (configurable)
- Adjustable reporting interval; home screen shows live countdown and beacon count
- **Demo mode** lets you try all features even without a GPS fix

### 💬 Messaging
- Unified conversation list for **private chat + group chat**, chat like any IM app
- Full message acknowledgment (ACK) with auto-reply support and Chinese messages
- Group broadcast uses no-ack format to avoid ack flooding between members
- Full group lifecycle: create, invite, confirm join, member manage, leave
- Group invite popups, member join / leave system notifications
- New-message top bubble hint + unread badges
- Chat history auto-saved, survives restart
- Compatible with Chinese APRS messages (UTF-8 / GBK auto-detected)

### 🚒 Station Identification
- Auto-detects **FMO (mobile fire) ** stations
- Marks fellow **APRSlocus** stations (comment contains `APRSlocus`), showing version / battery / altitude etc.
- **Official APRS device identification**: uses the aprs.org device database `aprsorg/aprs-deviceid` (tocalls); recognizes each station's vendor + model + device class (rig / HT / tracker / app / software / iGate / digipeater / weather …) from the packet destination callsign, with a bundled offline snapshot + online auto-update
- Full **37 official symbol tables, 3571 standard icons**, official PNG preferred with Material fallback

### 🛰️ Station List & Details
- **Multi-dimension filter**: status (Online / Moving / Stationary), APRS type (Vehicle / Fixed / Digipeater / Weather), software (APRSlocus), device class & specific model (from official tocalls), country/region receive filter, favorites — single-row chips, tap to filter
- **Smart search**: real-time search by callsign / type / comment / grid / device name (debounced, smooth with many stations)
- **Sorting**: callsign / last heard / distance / status
- **Details page**: lat/lng, Maidenhead grid, speed, altitude, course, distance & bearing to me, weather, track, forwarding-path visualization (hop chain with tappable digis), recent raw packets
- **Quick actions**: copy coords / grid, show on map, navigate, and **online lookup (QRZ callsign DB / aprs.fi position & track)**

### 📦 Packets & Logs
- **Raw packet view**: monospace + timestamps, long-press to copy
- **Parsed list mode**: position / message / weather / status / object categorized with type filter & full-text search
- **Debug log page**: leveled logs (debug / info / warn / error), one-tap copy / clear

### ⚡ Connection & Background
- **Auto-connects to APRS-IS public servers**, stays online in background
- TCP socket (desktop / mobile) and WebSocket (web) implementations
- Default server `rotate.aprs2.net:14580`; parses `# logresp` for login verification; yellow banner on home if Passcode unverified
- **Progressive reconnect** (8 → 16 → 32 → 60 s)
- **Android foreground location service**: continuous GPS reporting + system notification; notification bar can connect / disconnect the server or exit the app in one tap
- Push notifications for received messages / group events
- Country/region receive filter and lat/lng + radius range filter (50 / 100 / 200 / 500 / 1000 / 2000 km presets)

### 🎨 Personalization & UX
- **Multi-language**: Simplified Chinese / Traditional Chinese / English / follow system, selectable on first launch
- **Dark mode** + custom accent color, applied instantly
- **UI scale** (85%–130%, slider + presets), one-tap UI reload
- **Six-step OOBE wizard**: language → welcome → callsign / SSID → symbol → receive filter → server, zero barrier to start
- Fun easter eggs on details / settings pages

### 🚀 Auto Update
- In-app update check with **GitHub / GitCode** channel switching
- Smart version compare, auto platform routing (APK on Android, EXE on Windows)
- Independent download progress, version history list, one-tap install / run installer
- Guides Android "install from unknown sources" permission

---

## 🖥️ Supported Platforms

| Platform | Status | Notes |
|------|------|------|
| **Android** | ✅ Full | Android 5.0+, direct APK install |
| **Windows** | ✅ Full | Portable single EXE + Inno Setup installer |
| **iOS** | 🧪 Buildable | CI builds (unsigned); sign & deploy yourself |
| **Linux** | 🔧 Ready | Flutter Linux runner configured |
| **macOS** | 🔧 Ready | Flutter macOS runner configured |
| **Web** | 🔧 Ready | WebSocket to APRS-IS; auto-location not yet (manual coords supported) |

> Grab the latest test builds from [GitHub Releases](https://github.com/dariondong/APRSLocus/releases).

---

## 📥 Download & Install

### Android
1. Download `APRSLocus_<version>.apk`
2. Allow "install from unknown sources" and install
3. Android 5.0+

### Windows
1. Download `APRSlocus-<version>-setup.exe` (Inno Setup) or the portable single EXE
2. Double-click to run, no extra dependencies

---

## 🚀 Quick Start

First launch enters a **6-step OOBE wizard**, fully visual:

| Step | What |
|------|------|
| 1️⃣ | Choose interface language (Simplified Chinese / Traditional Chinese / English / follow system) |
| 2️⃣ | Welcome: learn core features, try **Demo Mode** first |
| 3️⃣ | Enter your amateur radio **callsign** (e.g. `BG7LZQ-3`) and pick an **SSID suffix** (mobile recommended `3`, HT recommended `7`) |
| 4️⃣ | Pick the **symbol** representing your station type (car / house / person / truck / bike / RV / weather station / police) |
| 5️⃣ | Choose which **stations to receive** by country/region (China by default); toggle "other stations" to receive digipeaters / weather / FMO / APRSlocus |
| 6️⃣ | Configure server & **Passcode**; done — auto-connects to APRS-IS and starts beaconing |

> **About Passcode**: entering `-1` lets you connect, but an **unverified Passcode cannot send/receive messages properly**. Generate your own at [APRS Passcode lookup](https://aprs.cool/AprsPG) and fill it in.

After the wizard the app connects to APRS-IS, starts reporting position, and receives nearby stations.

---

## 📚 User Guide

### 🗺️ Map Page
- Switch map type: Settings → Display → Map type (AMap / AMap Satellite / Vector / Carto series / OSM series / OpenTopo / Esri)
- Toggle clustering from the map control bar
- Show / hide my track and selected station track
- Search box on top to jump to a station by callsign; tap a marker for details

### 🛰️ Station Page
- Filter chips on top: All / Online / Moving / Stationary / Offline, Vehicle / Fixed / Digipeater / Weather, APRSlocus, device class & model
- Tap a station for the details sheet: full info, track, forwarding path
- Favorite stations for quick access

### 💬 Message Page
- Conversation list mixes group chats (orange group icon + "Group" tag) and private chats
- Private chat: type & send, auto message ACK
- Group chat: two-step create wizard (name first → members / members first → content)
- Invitations pop up automatically — accept or decline

### 📦 Packet Page
- Raw mode: full APRS frames, long-press to copy
- Parsed mode: filter by type + search to understand protocol fields
- History auto-saved, per-platform clearing

### ⚙️ Settings Page
| Section | Main options |
|------|----------|
| **Radio** | Callsign, SSID, symbol, comment, display info, grid, current position |
| **Location / Beacon** | GPS source, beacon on/off, interval, content (speed / course / battery), manual position, pick on map |
| **Connection** | Server, port, Passcode, WebSocket URL, receive range filter (lat/lng + radius), max stations |
| **Display** | Dark mode, accent color, language, UI scale, reload UI, map type |
| **Data** | Packet / station / message history management |
| **Advanced** | Developer mode, rerun setup wizard, debug log, check update |

---

## 📡 Beacons & Symbols

### Example Beacon

APRSlocus position beacons follow the APRS 1.0 standard:

```
BG7LZQ-3>APALOC,TCPIP*:!2148.90N/11049.14E/> /A=000328 090/050 Bat:70% APRSlocus v1.6.18
```

- `APALOC` in the path marks this station as using APRSlocus
- Comment auto-attaches altitude (`/A=000328`), course/speed (`090/050`), battery (`Bat:70%`)

### Symbol Reference

| Symbol | Meaning | Symbol | Meaning |
|------|------|------|------|
| `>` | Car | `-` | House |
| `[` | Person | `k` | Truck |
| `b` | Bike | `R` | RV |
| `W` | Weather station | `!` | Police |
| `i` | FMO station | `'` | Small aircraft |

Full **37 official symbol tables, 3571 standard icons**, all rendered from bundled official PNGs.

---

## ⚙️ Tech Stack

| Category | Tech |
|------|------|
| **Framework** | [Flutter](https://flutter.dev) (Dart 3.x) |
| **Maps** | [AMap](https://lbs.amap.com) (tiles), [flutter_map](https://pub.dev/packages/flutter_map), [vector_map_tiles](https://pub.dev/packages/vector_map_tiles), Carto, OpenStreetMap, OpenTopoMap, Esri ArcGIS |
| **Network** | APRS-IS (TCP Socket / WebSocket) |
| **Protocol** | APRS 1.0 (position / message / weather / status / object / Mic-E …) |
| **Location** | Android FusedLocationProvider + foreground service |
| **i18n** | flutter_localizations + ARB (Simplified Chinese / Traditional Chinese / English) |
| **CI / Release** | GitHub Actions (Windows / Android / iOS builds + auto release) |

---

## 🗂️ Project Structure

```
APRSLocus/
├── lib/                      # Flutter app source
│   ├── main.dart             # Entry point
│   ├── app.dart              # App root (theme / locale / scale)
│   ├── home_page.dart        # Main shell (5 tabs: map / stations / messages / packets / settings)
│   ├── map_page.dart         # Map page
│   ├── vector_map.dart       # Vector map (flutter_map)
│   ├── tile_map.dart         # Tile maps (AMap / Carto / OSM / OpenTopo / Esri)
│   ├── stations_page.dart    # Station list
│   ├── station_detail.dart   # Station detail
│   ├── messages_page.dart    # Messages (private + group)
│   ├── packets_page.dart     # Raw packets
│   ├── log_page.dart         # Debug log
│   ├── oobe_page.dart        # First-run wizard
│   ├── settings_page.dart    # Settings home
│   ├── settings_pages.dart   # Setting subpages
│   ├── check_update_page.dart# Update check
│   ├── about_page.dart       # About
│   ├── sponsor_page.dart     # Sponsor & credits
│   ├── state.dart            # Global state (connection / beacon / messages / settings)
│   ├── models.dart           # Data models (station / message / group / symbol)
│   ├── services.dart         # Location service + APRS packet formatting
│   ├── aprs_parse.dart       # APRS parsing
│   ├── coord.dart            # WGS-84 / GCJ-02 conversion
│   ├── theme.dart            # Theme & styles
│   ├── l10n/                 # i18n resources (zh / en / zh-TW)
│   └── net/                  # APRS-IS connectors (TCP / WebSocket)
├── android/                  # Android project
├── ios/                      # iOS project
├── linux/                    # Linux project
├── macos/                    # macOS project
├── windows/                  # Windows project
├── web/                      # Web project
├── assets/                   # Assets (symbols / maps / logo etc.)
├── APRSicon/                 # Official APRS symbol library (37 tables, 3571 icons)
├── tool/                     # Build / version sync scripts
├── .github/workflows/        # CI: build, release, test
├── installer.iss             # Inno Setup script
├── pubspec.yaml              # Dependencies & assets
└── CHANGELOG.md              # Changelog
```

---

## 🔨 Build from Source

### Requirements
- Flutter 3.x (stable)
- Dart SDK ^3.13.1
- Android: JDK 17, Android SDK
- Windows: Visual Studio (C++ desktop), [Inno Setup](https://jrsoftware.org/isinfo.php) for installer

### Common Steps
```bash
git clone https://github.com/dariondong/APRSLocus.git
cd APRSLocus
flutter pub get
```

### Build Windows Installer
```bash
flutter build windows --release
# Package with Inno Setup (version follows pubspec.yaml)
ISCC /DMyAppVersion=1.6.18 installer.iss
```

### Build Android APK
```bash
flutter build apk --release
# Artifact: build/app/outputs/flutter-apk/app-release.apk
```

### One-Click Package (Windows PowerShell)
```bash
# Sync version + build APK / installer + Inno Setup
./tool/build_all.ps1
```

### iOS (unsigned)
```bash
flutter build ios --release --no-codesign
```

### Versioning
- App version lives in `pubspec.yaml` (`version: 1.6.18+10618`)
- Pushing a `v*` tag triggers [GitHub Actions](.github/workflows/build-release.yml) to build Windows / Android / iOS and publish a Release; changelog auto-extracted from `CHANGELOG.md`

---

## ❓ FAQ

<details>
<summary><b>Q: Can't receive / send messages?</b></summary>

In most cases your **Passcode is unverified**. Using `-1` connects but cannot send/receive messages. Generate your own at [APRS Passcode lookup](https://aprs.cool/AprsPG) and set it under "Connection". If the server returns `unverified` after login, a yellow banner appears at the top of Home — tap "Go to settings" to fix it.
</details>

<details>
<summary><b>Q: How do I set the Passcode?</b></summary>

In OOBE step 6 or "Settings → Connection", generate a Passcode from your **full callsign (with SSID, e.g. BG7LZQ-3)** and enter it.
</details>

<details>
<summary><b>Q: Connection fails / keeps dropping?</b></summary>

The app retries progressively (8 → 16 → 32 → 60 s). If it keeps failing, check your network, confirm the server (`rotate.aprs2.net:14580`) and that the port isn't blocked; switch servers in "Connection" then tap "Reconnect".
</details>

<details>
<summary><b>Q: No nearby stations on my phone?</b></summary>

Check whether the target country/region is ticked under "Receive filter" and that your range (lat/lng + radius) covers your location. Only China (prefix B) stations are received by default.
</details>

<details>
<summary><b>Q: Does background location drain battery?</b></summary>

Android keeps APRS online with a foreground location service. Adjust the beacon interval under "Location / Beacon", or disable beaconing and report manually to save power. The notification bar can exit the app in one tap.
</details>

<details>
<summary><b>Q: Map looks wrong on Windows?</b></summary>

Switch to **Vector map** under "Display → Map type" (no API key, best compatibility), or try Carto / OSM / Esri international sources.
</details>

<details>
<summary><b>Q: Install says signature conflict / downgrade?</b></summary>

Since 1.5.2 Android uses the official release signature, identical between CI and local builds — install over the existing version directly. From much older versions, uninstall first then reinstall.
</details>

---

## 🙏 Thanks & Contributing

- [AMap](https://lbs.amap.com) — map tiles / JS API
- [APRS-IS](https://aprs-is.net) — global APRS network
- [flutter_map](https://pub.dev/packages/flutter_map) / [vector_map_tiles](https://pub.dev/packages/vector_map_tiles) — vector rendering
- [OpenFreeMap](https://openfreemap.org) — free vector tiles
- **BD3QID** — i18n contributions
- **清零 (BG2HCB)** — settings code optimization
- **Testers**: BG7PGW, BG7LMW, BG7OSL, BD3QID
- **AI compute support**: BA3RZL 养生
- Every amateur radio enthusiast's support & feedback

If you find this useful, give us a **Star** ⭐; contributions via Issues / PRs welcome. Sponsors can use the in-app "About → Sponsor" (WeChat reward code).

---

## 💬 Community & Feedback

| Channel | Link |
|------|------|
| **GitHub** | https://github.com/dariondong/APRSLocus |
| **GitCode** | https://gitcode.com/DarionDong/APRSLocus |
| **Author site** | https://theez.top |
| **QQ group** | https://qm.qq.com/q/8pL6vc5YA0 |

---

> **Disclaimer**: This software is for amateur radio enthusiasts to learn and exchange. Please follow your local radio regulations and operate with a valid license.

---

## 📄 License

This project is licensed under the [GNU General Public License v3.0](LICENSE).

Copyright (C) BG7LZQ (Darion)

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
