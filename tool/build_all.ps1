# APRSlocus 一键打包脚本
# 用法：
#   .\tool\build_all.ps1                 # 沿用当前版本，build 号自增
#   .\tool\build_all.ps1 -Version 1.5.0  # 指定版本（build 从 1 开始）
#   .\tool\build_all.ps1 -SkipAndroid    # 跳过 Android 构建
#   .\tool\build_all.ps1 -SkipWindows    # 跳过 Windows 构建

param(
    [string]$Version = '',
    [switch]$SkipAndroid,
    [switch]$SkipWindows
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path (Split-Path $MyInvocation.MyCommand.Path -Parent) -Parent
Set-Location $Root

# Flutter 可执行文件路径（脚本内用完整路径，避免 PATH 问题）
$Flutter = 'E:\fluttersdk\flutter\bin\flutter.bat'
if (-not (Test-Path $Flutter)) {
    $cmd = Get-Command flutter -ErrorAction SilentlyContinue
    if ($cmd) { $Flutter = $cmd.Source }
}
if (-not (Test-Path $Flutter)) {
    Write-Error "未找到 flutter，请在脚本顶部 Flutter 变量配置路径"
    exit 1
}

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "  APRSlocus 一键打包" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan

# 1. 同步版本号
Write-Host "`n[1/4] 同步版本号..." -ForegroundColor Yellow
if ($Version) {
    python tool/sync_version.py $Version
} else {
    python tool/sync_version.py
}
if ($LASTEXITCODE -ne 0) { Write-Error "版本同步失败"; exit 1 }

# 读取版本
$pubspec = Get-Content pubspec.yaml -Raw
$ver = [regex]::Match($pubspec, '(?m)^version:\s*([0-9.]+)').Groups[1].Value
Write-Host "  当前版本: $ver" -ForegroundColor Green

# 2. 构建 Android APK
if (-not $SkipAndroid) {
    Write-Host "`n[2/4] 构建 Android APK..." -ForegroundColor Yellow
    & $Flutter build apk --release
    if ($LASTEXITCODE -ne 0) { Write-Error "Android 构建失败"; exit 1 }
    $apkSrc = "build\app\outputs\flutter-apk\app-release.apk"
    if (Test-Path $apkSrc) {
        Copy-Item -Force $apkSrc "D:\APRSLocus_$ver.apk"
        Write-Host "  APK -> D:\APRSLocus_$ver.apk" -ForegroundColor Green
    }
} else {
    Write-Host "`n[2/4] 跳过 Android 构建" -ForegroundColor DarkGray
}

# 3. 构建 Windows + Inno 打包
if (-not $SkipWindows) {
    Write-Host "`n[3/4] 构建 Windows..." -ForegroundColor Yellow
    & $Flutter build windows --release
    if ($LASTEXITCODE -ne 0) { Write-Error "Windows 构建失败"; exit 1 }

    Write-Host "`n[4/4] Inno Setup 打包..." -ForegroundColor Yellow
    $iscc = "C:\Program Files (x86)\Inno Setup 6\ISCC.exe"
    if (-not (Test-Path $iscc)) {
        Write-Error "未找到 Inno Setup: $iscc"
        exit 1
    }
    & $iscc "/DMyAppVersion=$ver" installer.iss
    if ($LASTEXITCODE -ne 0) { Write-Error "Inno 打包失败"; exit 1 }

    $setup = "output\APRSLocus_Setup_$ver.exe"
    if (Test-Path $setup) {
        Copy-Item -Force $setup "D:\APRSLocus_Setup_$ver.exe"
        Write-Host "  安装包 -> D:\APRSLocus_Setup_$ver.exe" -ForegroundColor Green
    }
} else {
    Write-Host "`n[3-4/4] 跳过 Windows 构建与打包" -ForegroundColor DarkGray
}

Write-Host "`n======================================" -ForegroundColor Cyan
Write-Host "  打包完成！版本 $ver" -ForegroundColor Green
Write-Host "======================================" -ForegroundColor Cyan
