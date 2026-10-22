<#
.SYNOPSIS
  MelodyFlow 敏感信息扫描（gitleaks）

.DESCRIPTION
  在提交/构建/发布前扫描代码与 Git 历史中的密码、Token、API Key、私钥等敏感信息。
  发现疑似泄露时以非 0 退出码结束，可用于阻断构建流水线。

.PARAMETER Mode
  staged   仅扫描暂存区（等价于提交钩子做的事）
  history  扫描 Git 全部历史（默认，对应"云端所有版本"）
  dir      扫描当前工作区文件
  all      history + dir（构建/发版前推荐）

.PARAMETER ReportPath
  报告输出路径（默认 gitleaks-report.sarif 于仓库根目录）

.EXAMPLE
  pwsh -File scripts/secret-scan.ps1 -Mode all
#>
param(
  [ValidateSet('staged','history','dir','all')]
  [string]$Mode = 'all',
  [string]$ReportPath = '',
  [switch]$Redact  # 输出中脱敏显示，适合公开日志
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
Set-Location $repo

function Find-Gitleaks {
  # 1) PATH
  $cmd = Get-Command gitleaks -ErrorAction SilentlyContinue
  if ($cmd) { return $cmd.Source }
  # 2) 环境变量
  if ($env:GITLEAKS_BIN -and (Test-Path $env:GITLEAKS_BIN)) { return $env:GITLEAKS_BIN }
  # 3) 仓库内 tools/gitleaks
  $candidates = @(
    (Join-Path $repo 'tools/gitleaks/gitleaks.exe'),
    (Join-Path (Split-Path -Parent $repo) 'tools/gitleaks/gitleaks.exe')
  )
  foreach ($c in $candidates) { if (Test-Path $c) { return $c } }
  return $null
}

$gl = Find-Gitleaks
if (-not $gl) {
  Write-Host '[secret-scan] 未找到 gitleaks。' -ForegroundColor Yellow
  Write-Host '[secret-scan] 安装：pwsh -File scripts/setup-gitleaks.ps1' -ForegroundColor Yellow
  exit 2
}

Write-Host ("[secret-scan] gitleaks: " + $gl)
$ver = & $gl version
Write-Host ("[secret-scan] version: " + $ver)
Write-Host ("[secret-scan] 模式: " + $Mode)

$config = Join-Path $repo '.gitleaks.toml'
$cfgArgs = @()
if (Test-Path $config) { $cfgArgs = @('-c', $config) }

$verboseArgs = @('-v', '--no-banner')
if ($Redact) { $verboseArgs += '--redact' }

$failed = $false

function Invoke-Scan([string]$label, [string[]]$extraArgs) {
  $report = $ReportPath
  if (-not $report) { $report = Join-Path $repo ("gitleaks-report-" + $label + ".sarif") }
  Write-Host ''
  Write-Host ("=== 扫描: " + $label + " ===") -ForegroundColor Cyan
  $args = @() + $extraArgs + $cfgArgs + $verboseArgs + @('--report-format', 'sarif', '--report-path', $report)
  & $gl @args
  $code = $LASTEXITCODE
  if ($code -ne 0) {
    Write-Host ("[secret-scan] " + $label + ": 发现疑似敏感信息，报告 -> " + $report) -ForegroundColor Red
    $script:failed = $true
  } else {
    Write-Host ("[secret-scan] " + $label + ": 未发现敏感信息") -ForegroundColor Green
  }
}

switch ($Mode) {
  'staged'  { Invoke-Scan 'staged' @('git','--staged','--pre-commit') }
  'history' { Invoke-Scan 'history' @('git') }
  'dir'     { Invoke-Scan 'dir' @('dir','.') }
  'all' {
    Invoke-Scan 'history' @('git')
    Invoke-Scan 'dir' @('dir','.')
  }
}

if ($script:failed) {
  Write-Host ''
  Write-Host '[secret-scan] 结果: 失败 —— 请先处理敏感信息再提交/构建。' -ForegroundColor Red
  Write-Host '[secret-scan] 误报可在该行加  # gitleaks:allow，或在 .gitleaksignore 追加指纹。' -ForegroundColor Yellow
  exit 1
}

Write-Host ''
Write-Host '[secret-scan] 结果: 通过。' -ForegroundColor Green
exit 0
