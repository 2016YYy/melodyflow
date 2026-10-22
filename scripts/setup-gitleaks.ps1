<#
.SYNOPSIS
  安装 gitleaks（敏感信息扫描）并启用提交前钩子

.DESCRIPTION
  安装顺序：PATH 已存在 -> winget -> 下载官方 Windows 二进制到工作区 tools/gitleaks
  随后设置 core.hooksPath 指向 .githooks，使提交前自动扫描。

.PARAMETER Force
  已安装时也重新执行钩子配置
#>
param([switch]$Force)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
Set-Location $repo
$toolsDir = Join-Path (Split-Path -Parent $repo) 'tools/gitleaks'
$exe = Join-Path $toolsDir 'gitleaks.exe'

function Test-Gitleaks([string]$p) {
  if (-not (Test-Path $p)) { return $false }
  try { $v = & $p version 2>$null; return ($LASTEXITCODE -eq 0 -and $v) } catch { return $false }
}

# 1) 已安装？
$existing = (Get-Command gitleaks -ErrorAction SilentlyContinue).Source
if ($existing -and (Test-Gitleaks $existing)) {
  Write-Host ("[setup] 已检测到 gitleaks: " + $existing)
} elseif (Test-Gitleaks $exe) {
  Write-Host ("[setup] 已检测到工作区 gitleaks: " + $exe)
} else {
  # 2) winget
  $winget = (Get-Command winget -ErrorAction SilentlyContinue).Source
  if ($winget) {
    Write-Host '[setup] 尝试通过 winget 安装 Gitleaks.Gitleaks ...'
    & $winget install --id Gitleaks.Gitleaks -e --accept-source-agreements --accept-package-agreements --disable-interactivity 2>&1 | Write-Host
    $existing = (Get-Command gitleaks -ErrorAction SilentlyContinue).Source
  }

  # 3) 下载官方二进制
  if (-not $existing -and -not (Test-Gitleaks $exe)) {
    Write-Host '[setup] winget 不可用，下载官方 Windows 二进制 ...'
    New-Item -ItemType Directory -Force -Path $toolsDir | Out-Null
    $api = 'https://api.github.com/repos/gitleaks/gitleaks/releases/latest'
    $rel = Invoke-RestMethod -Uri $api -Headers @{ 'User-Agent' = 'melodyflow-setup' }
    $asset = $rel.assets | Where-Object { $_.name -like '*windows_x64.zip' } | Select-Object -First 1
    if (-not $asset) { throw '未找到 Windows x64 发行包' }
    $zip = Join-Path $toolsDir $asset.name
    Write-Host ("[setup] 下载 " + $asset.name + " (" + [math]::Round($asset.size/1MB,1) + " MB)")
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zip -UseBasicParsing
    Expand-Archive -LiteralPath $zip -DestinationPath $toolsDir -Force
    Remove-Item -LiteralPath $zip -Force
  }
}

if (-not (Test-Gitleaks $exe) -and -not $existing) {
  throw '[setup] gitleaks 安装失败，请手动安装后重试（见本文档第五节）'
}

# 4) 启用提交钩子
git config core.hooksPath .githooks
Write-Host '[setup] 已启用提交钩子：core.hooksPath = .githooks'

# 5) 自检
$bin = if (Test-Gitleaks $exe) { $exe } else { (Get-Command gitleaks).Source }
Write-Host ("[setup] gitleaks 版本: " + (& $bin version))
Write-Host '[setup] 完成。之后每次 git commit 会自动扫描暂存区。'
Write-Host '[setup] 发版前请执行：pwsh -File scripts/secret-scan.ps1 -Mode all'
