param(
  [string]$Version = 'v2.0.1',
  [string]$Repo = 'AWEsome639/one-more-builds',
  [string]$AppDir = 'D:\work\one-more\release',
  [int]$Keep = 5,
  [switch]$DryRun
)
$ErrorActionPreference = 'Stop'
# version whitelist per master instruction
if (@('v2.0.1','v2.1.0','v3.0.0') -notcontains $Version) { throw "version not allowed: $Version" }
$cred = "$env:USERPROFILE\.dsh\.credentials.yaml"
$tok = $null
foreach ($l in (Get-Content $cred -Encoding UTF8)) { if ($l -match '^\s*GITHUB_TOKEN:\s*(\S+)') { $tok = $Matches[1] } }
if (-not $tok) { throw 'GITHUB_TOKEN not found in credentials refs' }
$h = @{ Authorization = "Bearer $tok"; Accept = 'application/vnd.github+json'; 'User-Agent' = 'dsh-hp' }
$app = Get-ChildItem $AppDir -Filter '*-release-signed-*.app' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $app) { throw 'no signed .app found' }
$assetName = $app.BaseName + '-app.zip'
Write-Output "app: $($app.Name) ($([math]::Round($app.Length/1MB,2)) MB)"
Write-Output "asset: $assetName"
# ★ 2026-11-25：上传前先验签（.app 必须带 HAP Signing Block，否则 AGC/装机都会拒）
$java = 'C:\Program Files\Huawei\DevEco Studio\jbr\bin\java.exe'
$jar  = 'C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\lib\hap-sign-tool.jar'
if ((Test-Path $java) -and (Test-Path $jar)) {
  $ErrorActionPreference = 'Continue'   # java 往 stderr 打日志，Stop 会把它当异常
  $vlog = & $java -jar $jar verify-app -inFile $app.FullName -outCertChain (Join-Path $env:TEMP 'v.cer') -outProfile (Join-Path $env:TEMP 'v.p7b') 2>&1
  $ErrorActionPreference = 'Stop'
  $vtext = ($vlog | Out-String)
  if ($vtext -notmatch 'Find Hap Signing Block success') { throw "signature verify failed for $($app.Name)" }
  $blk = ($vtext -split "`n" | Where-Object { $_ -match 'Find Hap Signing Block' } | Select-Object -First 1).Trim()
  Write-Output "sign: $blk"
} else { Write-Output 'sign: verify tool missing, skipped' }
# release for version
$rel = $null
$rels = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases" -Headers $h -TimeoutSec 60
$rel = $rels | Where-Object { $_.tag_name -eq $Version } | Select-Object -First 1
if (-not $rel) {
  if ($DryRun) { Write-Output "dry: would create release $Version" } else {
    $body = @{ tag_name=$Version; target_commitish='main'; name=$Version; body="signed builds archive for $Version"; draft=$false; prerelease=$false } | ConvertTo-Json
    $rel = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases" -Method Post -Headers $h -ContentType 'application/json' -Body $body -TimeoutSec 60
    Write-Output "release created: $($rel.tag_name) id=$($rel.id)"
  }
}
if ($DryRun) { Write-Output 'dry run: stop before upload'; return }
$zip = Join-Path $env:TEMP $assetName
Compress-Archive -LiteralPath $app.FullName -DestinationPath $zip -Force
$url = "https://uploads.github.com/repos/$Repo/releases/$($rel.id)/assets?name=$assetName"
$code = ''
for ($attempt = 1; $attempt -le 4; $attempt++) {
  $code = & curl.exe -sS -o (Join-Path $env:TEMP 'gh_asset.json') -w "%{http_code}" --http1.1 --max-time 900 -X POST -H "Authorization: Bearer $tok" -H "Content-Type: application/octet-stream" -H "User-Agent: dsh-hp" -H "Expect:" --data-binary "@$zip" $url
  if ($code -eq '201') { break }
  Write-Output "upload attempt $attempt -> http=$code, retrying in 10s"
  Start-Sleep 10
}
if ($code -ne '201') { throw "upload failed http=$code" }
$j = Get-Content (Join-Path $env:TEMP 'gh_asset.json') -Raw | ConvertFrom-Json
Write-Output "uploaded: $($j.name) $([math]::Round($j.size/1MB,2)) MB"
# retention: keep newest N assets in this release
$assets = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/$($rel.id)/assets" -Headers $h -TimeoutSec 60
$sorted = $assets | Sort-Object created_at -Descending
if (@($sorted).Count -gt $Keep) {
  $sorted | Select-Object -Skip $Keep | ForEach-Object {
    Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/assets/$($_.id)" -Method Delete -Headers $h -TimeoutSec 60 | Out-Null
    Write-Output "pruned: $($_.name)"
  }
}
Write-Output "done. release: https://github.com/$Repo/releases/tag/$Version"