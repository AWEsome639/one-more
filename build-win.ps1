# One More 构建（Windows 版，对应 Mac 的 build.sh）
# 用法：powershell -File build-win.ps1 [-Task assembleHap] [-Release]
param(
  [string]$Task = 'assembleHap',
  [switch]$Release
)
$ErrorActionPreference = 'Stop'
$D = 'C:\Program Files\Huawei\DevEco Studio'
$env:DEVECO_CLI_CLT_PATH = $D
$env:DEVECO_SDK_HOME = "$D\sdk"
$env:JAVA_HOME = "$D\jbr"
$env:Path = "$D\bin;$D\jbr\bin;$D\tools\ohpm\bin;$D\tools\hvigor\bin;$D\tools\node;$D\sdk\default\openharmony\toolchains;$env:Path"
Set-Location $PSScriptRoot

# 僵尸锁：上次崩了遗留的 .hvigor\.build-lock
if (Test-Path '.hvigor\.build-lock') {
  $running = Get-Process | Where-Object { $_.ProcessName -match 'node' -and $_.Path -like '*hvigor*' }
  if (-not $running) { Remove-Item -Recurse -Force '.hvigor\.build-lock' -ErrorAction SilentlyContinue }
}

$hvigorArgs = @('--no-daemon', $Task)
if ($Release) { $hvigorArgs += @('-p', 'buildMode=release') }

Write-Host "── 构建任务: $Task 模式: $(if ($Release) {'release'} else {'debug'}) ──"
& "$D\tools\hvigor\bin\hvigorw.bat" @hvigorArgs
$rc = $LASTEXITCODE
if ($rc -ne 0) { Write-Error "hvigor 退出码 $rc"; exit $rc }

$hap = Get-ChildItem 'entry\build\default\outputs\default' -Filter '*-signed.hap' -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($hap) { Write-Host ("✅ {0}  {1:N1} MB" -f $hap.Name, ($hap.Length / 1MB)) } else { Write-Host '⚠️ 未找到签名 HAP' }
