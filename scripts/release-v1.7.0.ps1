#!/usr/bin/env pwsh
# MelodyFlow v1.7.0 发布脚本
# 把本地已完成的 v1.7.0 提交推送到 GitHub 并打 tag，触发 GitHub Actions 云端构建
# 前置：本机已登录 GitHub（Git Credential Manager 凭据可用）
param(
  [string]$Remote = "origin",
  [string]$Branch = "main",
  [string]$Tag = "v1.7.0"
)
$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot
Write-Host "=== 1) 推送 v1.7.0 提交到 $Remote/$Branch ===" -ForegroundColor Cyan
git push $Remote "HEAD:refs/heads/$Branch"
Write-Host "=== 2) 创建并推送 tag $Tag ===" -ForegroundColor Cyan
git tag -a $Tag -m "release: v1.7.0 - 接入 audio_service 后台播放与通知栏控制"
git push $Remote $Tag
Write-Host "=== 完成，云端构建已触发 ===" -ForegroundColor Green
Write-Host "Actions: https://github.com/2016YYy/melodyflow/actions" -ForegroundColor Yellow
