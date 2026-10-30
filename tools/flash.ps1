# DAPLink / OpenOCD 烧录脚本（适用于任意 CubeMX Makefile 工程）
#
# 背景：这块 DAPLink 的固件（FW 0254）在连续会话之间容易把应答包弄乱，
# OpenOCD 会报 "CMSIS-DAP command mismatch"，现象是 DAPLink 红灯常闪、
# 烧录失败。实测只要：
#   1) 加 -c "cmsis-dap quirk enable"（打开兼容模式）
#   2) 每次失败后等 8 秒再重试（给固件状态机恢复时间）
# 就能稳定烧进去。这个脚本把这两点封装成自动重试。
#
# ELF 文件名自动从 Makefile 的 TARGET 推断，换工程后直接把 tools 文件夹
# 拷过去就能用，不需要改脚本。
#
# 用法：在工程根目录执行
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\flash.ps1
# 或在 VSCode 里运行任务 “flash (DAPLink)”。

param(
    [int]$Attempts = 5,
    [int]$WaitSeconds = 8
)

$ErrorActionPreference = 'Continue'  # 允许 openocd 往 stderr 写日志而不中断脚本

$ocd     = 'D:\STM32\arm\openocd\openocd12\xpack-openocd-0.12.0-7\bin\openocd.exe'
$scripts = 'D:\STM32\arm\openocd\openocd12\xpack-openocd-0.12.0-7\openocd\scripts'
$project = Split-Path -Parent $PSScriptRoot

if (-not (Test-Path -LiteralPath $ocd)) {
    throw "找不到 openocd.exe：$ocd"
}

# 从 Makefile 读取 TARGET，拼出 build\<TARGET>.elf
$makefile = Join-Path $project 'Makefile'
if (-not (Test-Path -LiteralPath $makefile)) {
    throw "找不到 Makefile：$makefile"
}
$match = Select-String -LiteralPath $makefile -Pattern '^\s*TARGET\s*=\s*(\S+)' | Select-Object -First 1
if (-not $match) {
    throw "Makefile 里没有找到 TARGET = ..."
}
$targetName = $match.Matches[0].Groups[1].Value

$elf = Join-Path $project ("build\" + $targetName + ".elf")
if (-not (Test-Path -LiteralPath $elf)) {
    throw "找不到 ELF：$elf（请先编译）"
}

# OpenOCD 跑的是 Tcl 解释器，路径里的反斜杠会被当成转义字符，必须用正斜杠
$elfTcl     = $elf.Replace('\', '/')
$scriptsTcl = $scripts.Replace('\', '/')

Write-Host "工程：$project" -ForegroundColor DarkGray
Write-Host "目标：$targetName.elf" -ForegroundColor DarkGray

for ($i = 1; $i -le $Attempts; $i++) {
    Write-Host "== 烧录尝试 $i / $Attempts ==" -ForegroundColor Cyan
    $log = & $ocd -s $scriptsTcl `
        -f interface/cmsis-dap.cfg `
        -f target/stm32f1x.cfg `
        -c "cmsis-dap quirk enable" `
        -c "adapter speed 500" `
        -c "program `"$elfTcl`" verify reset exit" 2>&1 | Out-String

    if ($log -match 'Verified OK') {
        Write-Host "烧录成功，芯片已复位并运行新固件。" -ForegroundColor Green
        exit 0
    }

    # 只打印关键错误，避免刷屏
    ($log -split "`r?`n" | Where-Object { $_ -match 'Error' } | Select-Object -Last 3) |
        ForEach-Object { Write-Host "   $_" -ForegroundColor DarkYellow }

    if ($i -lt $Attempts) {
        Write-Host "本次失败，$WaitSeconds 秒后重试（期间不要拔插、不要按复位键）..." -ForegroundColor Yellow
        Start-Sleep -Seconds $WaitSeconds
    }
}

Write-Host "连续 $Attempts 次失败：请把 DAPLink 从 USB 口拔下，等 2 秒再插回，然后重新运行本任务。" -ForegroundColor Red
exit 1
