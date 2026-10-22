<#
.SYNOPSIS
  推送本地提交到 origin/main（带自动重试）

.DESCRIPTION
  - 从 Windows 凭据管理器读取 GitHub 凭据（不落盘、不回显）
  - 对当前环境需要关闭 TLS 校验（schannel 在此机器上不可用），仅用于推送本人仓库
  - 网络不通时每 60 秒重试，默认最多 20 次

.PARAMETER Retries
  重试次数，默认 20
.PARAMETER IntervalSeconds
  重试间隔秒数，默认 60
#>
param(
  [int]$Retries = 20,
  [int]$IntervalSeconds = 60
)

$ErrorActionPreference = 'Continue'
$repo = Split-Path -Parent $PSScriptRoot
Set-Location $repo
$env:GIT_TERMINAL_PROMPT = '0'

function Get-CredentialUrl {
  $winc = 'C:/Program Files/Git/mingw64/libexec/git-core/git-credential-wincred.exe'
  if (-not (Test-Path $winc)) { throw '未找到 git-credential-wincred.exe' }
  $nl = [Environment]::NewLine
  $inp = 'protocol=https' + $nl + 'host=github.com' + $nl + $nl
  $out = ($inp | & $winc get 2>&1) | Out-String
  $user = $null; $pass = $null
  foreach ($line in ($out -split "`n")) {
    if ($line -like 'username=*') { $user = $line.Substring(9).Trim() }
    if ($line -like 'password=*') { $pass = $line.Substring(9).Trim() }
  }
  if (-not $pass) { throw '未能从凭据管理器读取 GitHub 凭据' }
  return 'https://' + $user + ':' + $pass + '@github.com/2016YYy/melodyflow.git'
}

$url = Get-CredentialUrl
Write-Host ("[push] 本地 HEAD: " + (git rev-parse HEAD))
Write-Host ("[push] 目标: origin/main，最多重试 " + $Retries + " 次，间隔 " + $IntervalSeconds + " 秒")

for ($i = 1; $i -le $Retries; $i++) {
  Write-Host ("[push] 第 " + $i + " 次尝试 " + (Get-Date -Format 'HH:mm:ss'))
  $out = & git -c http.sslVerify=false push $url HEAD:refs/heads/main 2>&1 | Out-String
  $masked = $out -replace '://[^@\s]+@', '://***@'
  if ($out -match 'main -> main|up-to-date|Everything up-to-date') {
    Write-Host $masked
    Write-Host '[push] 推送成功。'
    exit 0
  }
  Write-Host ($masked.Trim())
  if ($i -lt $Retries) { Start-Sleep -Seconds $IntervalSeconds }
}

Write-Host '[push] 重试次数用尽，仍未推送成功。请检查网络后重试。'
exit 1
