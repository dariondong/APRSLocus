# AGENTS.md — APRSLocus

Flutter/Dart APRS app (`github.com/dariondong/APRSLocus`, default branch `main`).

## 本机环境（重要）

- 本机**不能跑 Android 构建**（无 Android SDK）；`flutter build apk/bundle` 会
  在 `build_hooks` 阶段报 `Android SDK could not be found`。要验证编译，用
  `flutter test` / `flutter build web`，别指望 APK。
- Flutter SDK 在 `/tmp/flutter/bin/flutter`（不在默认 PATH）。
- `flutter analyze` 有一条**已知可容忍**的假阳性：
  `lib/vector_map.dart:295` `argument_type_not_assignable`。CI 用脚本过滤它，
  本地判断「有没有新 error」时同样忽略这一条即可。

## 提交前必跑（与 CI 对齐）

```bash
export PATH=/tmp/flutter/bin:$PATH
python3 tool/check_*.py            # 全部静态检查；注意 check_site / check_apk_resources
                                   # 需要额外参数或联网，属预期「失败」
flutter analyze                    # 除 vector_map 外不应有 error
flutter test $(grep -oE 'flutter test [^ ]+\.dart' .github/workflows/ci-test.yml | awk '{print $3}')
```

`tool/check_*.py` 是本仓库的核心防线：这些检查覆盖的都是「能编译、能过 analyze、
只在真机/特定语言/深色模式下才暴露」的坑（跨层漏 import、写死颜色、l10n 不同步、
未用成员……）。**新增 UI 代码后务必跑一遍。**

## 文案本地化（l10n）铁律

- 真源 arb：`lib/l10n/app_zh.arb`（模板），6 语言：zh / zh_TW / en / ja / es / id。
  输出物 `lib/l10n/app_localizations*.dart` **已入库**，改 arb 后必须
  `flutter gen-l10n` 重生成并一起提交；`tool/check_l10n_sync.py` 会拦不同步。
- 同页文案若某处已本地化、某处仍写死中文，就是 bug。net 层（`net/icom_lan_io.dart`
  的 `phaseLabel`、枚举 `WlanRadioModel.description`）的中文基准值，一律经
  `lib/settings_widgets.dart` 的 `icomPhaseLabel / icomModelName / icomModelTab /
  icomModelDesc` 转成当前语言再外显，不要直接贴。
- 判颜色/逻辑用**原始中文串**（如 `_phaseColor` 按中文关键字匹配），展示才用译文。

## 暗色模式（dark mode）铁律

- 表面底色走主题 token（`C.white` / `C.surfaceFillStrong` / `C.bg` / `C.mapBg`…），
  不要 `Colors.white`；`Colors.white.withValues(alpha: …)` 用于彩色横幅上的按钮，
  不算表面。
- `surfaceTint(Colors.white)` / `surfaceTint(const Color(0xFF…))` 在材质关闭时
  **原样返回常量**，深色下就是一块白板 —— 已由 `tool/check_dark_mode.py` 拦。

## 测试与 CI

- CI 只跑 `ci-test.yml` 里显式列出的测试文件（见上面那条 `grep`）。**新增测试后
  要手动把 `flutter test test/xxx_test.dart` 加进该文件**，否则永远不会跑。
- `main` 上存在若干**与本仓库特性无关的历史失败测试**
  （`widget_test.dart`/`unread_badge_test.dart`/`station_filter_test.dart` 等，
  部分因生成物不同步或测试落后于实现）。判断回归时，先 `git stash` 对比基线，
  别把这些算到自己的改动头上。
