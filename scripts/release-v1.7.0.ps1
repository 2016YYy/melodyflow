# MelodyFlow v1.7.0 发布脚本（爸爸本地执行，GCM 可弹窗）
# 用法：在仓库根目录运行
#   powershell -ExecutionPolicy Bypass -File scripts/release-v1.7.0.ps1
# 安全：仓库内不保存任何签名口令；口令来自环境变量或 android/local.properties（已忽略）
param(
  [string]$Remote = "origin",
  [string]$Branch = "main",
  [string]$Tag = "v1.7.0",
  [switch]$SkipSecretScan
)
$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent $PSScriptRoot
Set-Location $repo

# 0) 发版前强制敏感信息扫描（仓库不通过扫描则禁止发布）
if (-not $SkipSecretScan) {
  Write-Host "=== 0) 敏感信息扫描（gitleaks）===" -ForegroundColor Cyan
  $scan = Join-Path $PSScriptRoot "secret-scan.ps1"
  if (Test-Path $scan) {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $scan -Mode all
    if ($LASTEXITCODE -ne 0) {
      Write-Host "[release] 敏感信息扫描未通过，已中止发布。" -ForegroundColor Red
      exit 1
    }
  } else {
    Write-Host "[release] 未找到 secret-scan.ps1，跳过扫描（不建议）。" -ForegroundColor Yellow
  }
} else {
  Write-Host "[release] 已按参数跳过敏感信息扫描（--SkipSecretScan）。" -ForegroundColor Yellow
}

Write-Host "=== 1) 推送 v1.7.0 提交到 $Remote/$Branch ===" -ForegroundColor Cyan
git push $Remote "HEAD:refs/heads/$Branch"

Write-Host "=== 2) 创建并推送 tag $Tag ===" -ForegroundColor Cyan
git tag -a $Tag -m "release: v1.7.0 - 接入 audio_service 后台播放与通知栏控制"
git push $Remote $Tag

Write-Host "=== 3) 配置 GitHub Actions 签名 Secret（只需一次）===" -ForegroundColor Cyan
$jks = Join-Path $repo "android/app/melodyflow-release.jks"
if (Test-Path $jks) {
  # 口令来源：环境变量优先，其次 android/local.properties（本地文件，不入库）
  $storePwd = $env:KEYSTORE_PASSWORD
  $keyPwd = $env:KEY_PASSWORD
  $alias = $env:KEY_ALIAS
  $localProps = Join-Path $repo "android/local.properties"
  if ((-not $storePwd -or -not $keyPwd) -and (Test-Path $localProps)) {
    $kv = @{}
    Get-Content $localProps | ForEach-Object {
      if ($_ -match '^([^#=]+)=(.*)$') { $kv[$matches[1].Trim()] = $matches[2].Trim() }
    }
    if (-not $storePwd) { $storePwd = $kv['keystore.storePassword'] }
    if (-not $keyPwd) { $keyPwd = $kv['keystore.keyPassword'] }
    if (-not $alias) { $alias = $kv['keystore.keyAlias'] }
  }
  if (-not $alias) { $alias = 'melodyflow' }

  $b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($jks))
  Write-Host "请把以下值填入 GitHub -> Settings -> Secrets and variables -> Actions：" -ForegroundColor Yellow
  Write-Host ("  KEYSTORE_BASE64 = " + $b64) -ForegroundColor White
  if ($storePwd) {
    Write-Host ("  KEYSTORE_PASSWORD = " + $storePwd) -ForegroundColor White
  } else {
    Write-Host "  KEYSTORE_PASSWORD = <未配置：请设置环境变量 KEYSTORE_PASSWORD 或在 android/local.properties 填 keystore.storePassword>" -ForegroundColor Red
  }
  Write-Host ("  KEY_ALIAS = " + $alias) -ForegroundColor White
  if ($keyPwd) {
    Write-Host ("  KEY_PASSWORD = " + $keyPwd) -ForegroundColor White
  } else {
    Write-Host "  KEY_PASSWORD = <未配置：请设置环境变量 KEY_PASSWORD 或在 android/local.properties 填 keystore.keyPassword>" -ForegroundColor Red
  }
  Write-Host "（口令仅在本机终端显示，不会写入仓库文件）" -ForegroundColor DarkGray
} else {
  Write-Host "未找到本地 keystore，CI 将用 debug 签名出包（可安装，非正式签名）。" -ForegroundColor Yellow
}

Write-Host "=== 完成，云端构建已触发 ===" -ForegroundColor Green
Write-Host "Actions: https://github.com/2016YYy/melodyflow/actions" -ForegroundColor Yellow
Write-Host "Releases: https://github.com/2016YYy/melodyflow/releases" -ForegroundColor Yellow
