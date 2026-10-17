# MelodyFlow v1.7.0 发布脚本（爸爸本地执行，GCM 可弹窗）
# 用法：在仓库根目录运行
#   powershell -ExecutionPolicy Bypass -File scripts/release-v1.7.0.ps1
param(
  [string]$Remote = "origin",
  [string]$Branch = "main",
  [string]$Tag = "v1.7.0"
)
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

# 1) 本地 keystore 已就绪（android/app/melodyflow-release.jks），CI 用 secret 覆盖
Write-Host "=== 1) 推送 v1.7.0 提交到 $Remote/$Branch ===" -ForegroundColor Cyan
git push $Remote "HEAD:refs/heads/$Branch"

Write-Host "=== 2) 创建并推送 tag $Tag ===" -ForegroundColor Cyan
git tag -a $Tag -m "release: v1.7.0 - 接入 audio_service 后台播放与通知栏控制"
git push $Remote $Tag

Write-Host "=== 3) 配置 GitHub Actions 签名 Secret（只需一次）===" -ForegroundColor Cyan
$jks = Join-Path $PSScriptRoot "android/app/melodyflow-release.jks"
if (Test-Path $jks) {
  $b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($jks))
  Write-Host "请把以下值填入 GitHub -> Settings -> Secrets and variables -> Actions：" -ForegroundColor Yellow
  Write-Host ("  KEYSTORE_BASE64 = " + $b64) -ForegroundColor White
  Write-Host "  KEYSTORE_PASSWORD = " -ForegroundColor White
  Write-Host "  KEY_ALIAS = melodyflow" -ForegroundColor White
  Write-Host "  KEY_PASSWORD = " -ForegroundColor White
  Write-Host "（也可改用 gh cli: gh secret set KEYSTORE_BASE64 < android/app/melodyflow-release.jks.b64）" -ForegroundColor DarkGray
} else {
  Write-Host "未找到本地 keystore，CI 将用 debug 签名出包（可安装，非正式签名）。" -ForegroundColor Yellow
}

Write-Host "=== 完成，云端构建已触发 ===" -ForegroundColor Green
Write-Host "Actions: https://github.com/2016YYy/melodyflow/actions" -ForegroundColor Yellow
Write-Host "Releases: https://github.com/2016YYy/melodyflow/releases" -ForegroundColor Yellow
