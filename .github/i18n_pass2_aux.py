from pathlib import Path

root = Path(__file__).resolve().parents[1]

def patch(path, pairs):
    p = root / path
    text = p.read_text(encoding='utf-8')
    for old, new in pairs:
        n = text.count(old)
        if n == 0:
            print(f'WARN missing {path}: {old[:100]!r}')
        else:
            print(f'{path}: {n} x {old[:60]!r}')
            text = text.replace(old, new)
    p.write_text(text, encoding='utf-8')

patch('lib/log_page.dart', [
    ("import 'theme.dart';", "import 'theme.dart';\nimport 'widgets.dart';"),
    ("title: const Text('系统日志')", 'title: Text(S.of(context).systemLog)'),
    ("tooltip: '复制全部日志'", 'tooltip: S.of(context).copyAllLogs'),
    ("'${_fmt(l.time)} [${logLevelName(l.level)}] ${l.source} ${l.message}'", "'${_fmt(l.time)} [${localizedLogLevelName(context, l.level)}] ${l.source} ${l.message}'"),
    ("content: Text('已复制 ${state.logs.length} 条日志')", 'content: Text(S.of(context).copiedLogs(state.logs.length))'),
    ("tooltip: '清空日志'", 'tooltip: S.of(context).clearLogs'),
    ("child: Text('暂无日志'", 'child: Text(S.of(context).noLogs'),
    ('child: Text(logLevelName(e.level),', 'child: Text(localizedLogLevelName(context, e.level),'),
])

patch('lib/splash_page.dart', [
    ("Text('APRS 定位追踪',", 'Text(S.of(context).appTagline,'),
])

patch('lib/sponsor_page.dart', [
    ("Text('你们的支持让项目走得更远'", 'Text(S.of(context).supportProject'),
    ("_feature(Icons.person_rounded, 'BG7LZQ', '利用课余时间开发维护本项目')", '_feature(Icons.person_rounded, \'BG7LZQ\', S.of(context).sponsorAuthorItems)'),
    ("_feature(Icons.rocket_launch_rounded, '持续迭代', '不断改进 APRSlocus 功能与体验')", '_feature(Icons.rocket_launch_rounded, S.of(context).continuousIteration, S.of(context).continuousIterationDesc)'),
    ("_sectionHeader('赞助支持'", '_sectionHeader(S.of(context).sponsorSupport'),
    ("_feature(Icons.group_rounded, S.of(context).sponsorGroup, '感谢群组的资金赞助支持')", '_feature(Icons.group_rounded, S.of(context).sponsorGroup, S.of(context).sponsorGroupItems)'),
    ("_feature(Icons.local_cafe_rounded, 'BG7PGW', '感谢赞助的蜜雪冰城一杯 🧋')", "_feature(Icons.local_cafe_rounded, 'BG7PGW', S.of(context).sponsorBgpItems)"),
    ("_feature(Icons.favorite_rounded, '每一位支持者', '你们的每一份支持都是动力')", '_feature(Icons.favorite_rounded, S.of(context).sponsorEvery, S.of(context).sponsorEveryItems)'),
    ("_sectionHeader('赞助方式'", '_sectionHeader(S.of(context).sponsorMethods'),
    ("Text('$title 赞赏码'", 'Text(S.of(context).qrCodeTitle(title)'),
    ("child: Text('赞赏码图片加载失败')", 'child: Text(S.of(context).qrLoadFailed)'),
    ("Text('长按图片可保存 · 微信扫一扫赞赏'", 'Text(S.of(context).qrSaveWechat'),
    ("Text('点击任意处关闭'", 'Text(S.of(context).tapAnywhereClose'),
])

patch('lib/amap_js_map.dart', [
    ("import 'coord.dart';", "import 'coord.dart';\nimport 'l10n/app_localizations.dart';"),
    ("Text('Web 平台暂不支持高德 JS 地图'", 'Text(AppLocalizations.of(context).webAmapUnsupported'),
    ("Text('WebView2 初始化失败\\n请安装 Microsoft Edge WebView2 运行时'", 'Text(AppLocalizations.of(context).webview2InitFailed'),
    ("Text('加载高德地图…'", 'Text(AppLocalizations.of(context).loadingAmap'),
])

patch('lib/vector_map.dart', [
    ("import 'theme.dart';", "import 'theme.dart';\nimport 'l10n/app_localizations.dart';"),
    ("Text('矢量地图加载失败\\n$_styleError'", "Text(AppLocalizations.of(context).vectorMapLoadFailed(_styleError ?? '')"),
    ("Text('加载矢量地图…'", 'Text(AppLocalizations.of(context).loadingVectorMap'),
])

patch('lib/check_update_page.dart', [
    ("Text('更新渠道'", 'Text(S.of(context).updateChannel'),
    ("throw Exception('服务器返回 ${resp.statusCode}')", 'throw Exception(S.of(context).serverReturned(resp.statusCode))'),
    ("throw Exception('返回数据格式错误')", 'throw Exception(S.of(context).invalidResponseData)'),
    ("throw Exception('没有找到任何版本')", 'throw Exception(S.of(context).noVersionsFound)'),
    ("isWin ? '该版本没有 Windows 安装包' : '该版本没有 APK 安装包'", 'isWin ? S.of(context).noWindowsInstaller : S.of(context).noApkInstaller'),
    ("_dlStatus = '正在连接…'", '_dlStatus = S.of(context).connectingEllipsis'),
    ("throw Exception('下载失败：HTTP ${resp.statusCode}')", 'throw Exception(S.of(context).downloadHttpError(resp.statusCode))'),
    ("_dlStatus = '已下载 ${_fmtSize(received)} / ${_fmtSize(total)}'", '_dlStatus = S.of(context).downloadedBytes(_fmtSize(received), _fmtSize(total))'),
    ("_dlStatus = '下载完成'", '_dlStatus = S.of(context).downloadComplete'),
    ("_dlStatus = '下载失败：${e.toString().replaceFirst('Exception: ', '')}'", "_dlStatus = '${S.of(context).downloadFailed}: ${e.toString().replaceFirst('Exception: ', '')}'"),
    ("'安装包已下载到：\\n$path\\n\\n点击\"安装\"后，系统会弹出安装确认框。\\n\\n若提示\"不允许安装未知来源应用\"，请到系统设置中允许本应用安装未知应用。'", 'S.of(context).androidInstallHelp(path)'),
    ("'安装包已保存到：\\n$path\\n\\n点击\"立即运行\"直接启动安装程序；也可以打开所在目录查看文件。'", 'S.of(context).windowsInstallHelp(path)'),
    ("child: const Text('打开所在目录')", 'child: Text(S.of(context).openContainingFolder)'),
    ("child: const Text('立即运行')", 'child: Text(S.of(context).runNow)'),
    ("_showSnack('无法启动安装程序，请到所在目录手动打开')", '_showSnack(S.of(context).cannotRunInstaller)'),
    ("_showSnack('无法启动安装器，请手动打开安装包')", '_showSnack(S.of(context).cannotLaunchInstaller)'),
    ("_showSnack('请在文件管理器中打开安装包')", '_showSnack(S.of(context).openPackageManually)'),
    ("_showSnack('无法打开安装包：$e')", '_showSnack(S.of(context).cannotOpenPackage(e.toString()))'),
    ("title: Text('需要允许安装应用')", 'title: Text(S.of(context).installPermissionTitle)'),
    ("'检测到系统未允许 APRSlocus 安装应用。\\n\\n请点击\"去设置\"，在\"安装未知应用\"中允许本应用安装应用，然后返回重新安装。'", 'S.of(context).installPermissionDesc'),
    ("child: const Text('去设置')", 'child: Text(S.of(context).goSettings)'),
    ("tooltip: '重新检查'", 'tooltip: S.of(context).recheck'),
    ("Text('签名已更换 · 需卸载重装'", 'Text(S.of(context).signatureChangedTitle'),
    ("'本次更新更换了正式签名（1.4.8 起）。旧版本无法直接覆盖安装，'\n                        '请先卸载手机上的 APRSlocus 再安装新版，否则会提示签名冲突。'", 'S.of(context).signatureChangedDesc'),
    ("? '发现新版本 v${_latest!.tagName}'\n                          : '仓库最新版本 v${_latest!.tagName}'", '? S.of(context).newVersionTitle(_latest!.tagName)\n                          : S.of(context).repoLatestTitle(_latest!.tagName)'),
    ("Text('正在检查最新版本…'", 'Text(S.of(context).checkingLatest'),
    ("Text('连接 GitCode 服务器'", 'Text(S.of(context).connectingGitCode'),
    ("label: const Text('重新检查')", 'label: Text(S.of(context).recheck)'),
    (": '暂无更新说明'", ': S.of(context).noReleaseNotes'),
    ("'该版本暂无${isWin ? ' Windows' : ' APK'} 安装包，请到历史版本中选择可下载的版本'", "S.of(context).noInstallerHistoryHint(isWin ? 'Windows' : 'APK')"),
    ("Text('最新版本'", 'Text(S.of(context).latestVersionLabel'),
    ("Text('${isWin ? 'Windows' : 'APK'} 安装包大小：${_fmtSize(release.assetSizeFor(isWin))}'", "Text(S.of(context).packageSize(isWin ? 'Windows' : 'APK', _fmtSize(release.assetSizeFor(isWin)))"),
    ("Text('更新内容'", 'Text(S.of(context).updateContents'),
    ("label: Text('重新下载'", 'label: Text(S.of(context).redownload'),
    ("label: Text(isWin ? '下载安装包' : '下载并安装'", 'label: Text(isWin ? S.of(context).downloadInstaller : S.of(context).downloadAndInstall'),
    ("child: Text('本地已有一份安装包'", 'child: Text(S.of(context).localPackageExists'),
    ("label: const Text('打开所在目录')", 'label: Text(S.of(context).openContainingFolder)'),
    ("_showSnack('安装包已删除')", '_showSnack(S.of(context).packageDeleted)'),
    ("Text('${history.length} 个'", 'Text(S.of(context).versionCount(history.length)'),
    ("Text(_dlStatus.isNotEmpty ? _dlStatus : '正在连接…'", 'Text(_dlStatus.isNotEmpty ? _dlStatus : S.of(context).connectingEllipsis'),
    ("Text('无安装包'", 'Text(S.of(context).noInstaller'),
    ("label: Text('下载'", 'label: Text(S.of(context).download'),
    ("tooltip: '查看更新日志'", 'tooltip: S.of(context).viewChangelog'),
    ("Text('v${rel.tagName} 更新日志'", 'Text(S.of(context).versionChangelog(rel.tagName)'),
    ("rel.body.trim().isNotEmpty ? rel.body.trim() : '暂无更新说明'", 'rel.body.trim().isNotEmpty ? rel.body.trim() : S.of(context).noReleaseNotes'),
    ("child: const Text('知道了')", 'child: Text(S.of(context).gotIt)'),
])
