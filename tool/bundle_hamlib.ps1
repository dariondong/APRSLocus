# 把 Hamlib 的 rigctld 放进 Windows 的 Release 目录（安装包从那儿收）。
#
# 为什么只要 rigctld：应用不链接 libhamlib，它跟 rigctld 说 TCP 上的文本协议
# （见 lib/net/rig_daemon_io.dart）。所以安装包里只需带这个程序与它要的 DLL，
# rigctl / rotctl / rigmem 那些工具、库与头文件都不带。
#
# 为什么先校验再解包：这个二进制会随安装包发到用户机器上。压缩包取自 Hamlib
# 官方 release，同页还有 SHA256SUM-w64，对不上就让整条构建失败 —— 宁可红一次，
# 也不要把来路不明的东西打进包里。
#
# 下载用 curl.exe（GitHub 的 Windows 镜像自带），不用 Invoke-WebRequest：
# 后者在 pwsh 里对纯文本响应有时交出字节数组，取首段会得到一串乱值，校验就
# 永远对不上（第一次跑 CI 就是这么红的）。
#
# 用法（两个 workflow 共用，别各写一份）：pwsh tool/bundle_hamlib.ps1 [-Version 4.7.2]
param([string]$Version = "4.7.2")

$ErrorActionPreference = "Stop"
$zip = "hamlib-w64-$Version.zip"
$sumfile = "hamlib-w64-$Version.sha256.txt"
$base = "https://github.com/Hamlib/Hamlib/releases/download/$Version"

curl.exe -sSL --fail -o $zip "$base/$zip"
if ($LASTEXITCODE -ne 0) { throw "download failed: $base/$zip" }
curl.exe -sSL --fail -o $sumfile "$base/SHA256SUM-w64-$Version"
if ($LASTEXITCODE -ne 0) { throw "download failed: $base/SHA256SUM-w64-$Version" }

$want = ((Get-Content -Raw -Path $sumfile).Trim() -split "\s+")[0].ToLower()
$got = (Get-FileHash $zip -Algorithm SHA256).Hash.ToLower()
if ($got -ne $want) { throw "hamlib sha256 mismatch: $got != $want" }

Expand-Archive -Path $zip -DestinationPath hamlib-tmp -Force
$src = "hamlib-tmp/hamlib-w64-$Version"
$dst = "build/windows/x64/runner/Release/hamlib"
New-Item -ItemType Directory -Force -Path $dst | Out-Null
Copy-Item "$src/bin/rigctld.exe" $dst
Copy-Item "$src/bin/*.dll" $dst
# 许可与说明随附（GPL / LGPL 的要求）
Copy-Item "$src/COPYING.txt" $dst
Copy-Item "$src/COPYING.LIB.txt" $dst
Copy-Item "$src/README.w64-bin.txt" $dst
Get-ChildItem $dst | Select-Object Name, Length | Format-Table
