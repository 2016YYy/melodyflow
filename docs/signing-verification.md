# MelodyFlow 签名密钥统一性验证报告

> 验证日期：2026-10-18 · 方法：下载 GitHub Releases 全部 7 个版本的 APK，解析各包 APK Signing Block (v2/v3)，提取签名证书 SHA-256 指纹逐一比对

## 结论

**v1.5.0 是唯一签名不一致的版本。**

| 版本 | 证书 SHA-256 | 密钥归属 | 状态 |
|------|-------------|---------|------|
| v1.0.0 | `20A59CCB00EA3740C132C1B9D89F851A55887E62057AA015A4C86C3C274287AE` | 主线密钥 | ✅ |
| v1.1.0 | `20A59CCB...287AE` | 主线密钥 | ✅ |
| v1.2.0 | `20A59CCB...287AE` | 主线密钥 | ✅ |
| v1.3.0 | `20A59CCB...287AE` | 主线密钥 | ✅ |
| v1.4.0 | `20A59CCB...287AE` | 主线密钥 | ✅ |
| **v1.5.0** | **`FB260B62F3B7ED4F15F30212DF44BE3E93549E5307606CB3A044873EA0CD3E06`** | **错误密钥（非主线密钥）** | ❌ |
| v1.6.0 | `20A59CCB...287AE` | 主线密钥（已纠正） | ✅ |

## 主线密钥信息（今后所有版本统一使用）

| 项目 | 值 |
|------|-----|
| 文件 | `melodyflow-keystore-backup.zip` 内 `melodyflow-release.jks` |
| 密码 | 见本地密钥库说明文件（**不记录于仓库**） |
| 别名 | `melodyflow` |
| 证书 SHA-1 | `EC:7B:6D:41:4E:A3:8D:8A:6B:DB:EB:22:8A:54:E2:41:6F:4E:F7:22` |
| 证书 SHA-256 | `20:A5:9C:CB:00:EA:37:40:C1:32:C1:B9:D8:9F:85:1A:55:88:7E:62:05:7A:A0:15:A4:C8:6C:3C:27:42:87:AE` |
| Owner | CN=MelodyFlow, OU=Dev, O=MelodyFlow, L=Global, ST=Global, C=CN |

错误密钥（仅 v1.5.0 误用）：`melodyflow-keystore\\` 目录那把，口令见本地密钥库说明，证书 SHA-256 `FB260B62...D3E06`，Owner L=Beijing。

## v1.5.0 的实际影响

- 已安装 v1.0.0 ~ v1.4.0 的用户**无法覆盖升级到 v1.5.0**（Android 签名校验失败），需卸载后安装
- 已安装 v1.5.0 的用户**无法直接升级到 v1.6.0 及以后**，需卸载 v1.5.0 后安装
- v1.4.0 之前 ↔ v1.6.0 及以后之间签名连续，可正常覆盖升级

## 已采取的措施

1. `android/app/melodyflow-release.jks` 已替换为**主线密钥**（原误放文件已备份至 `_backup/2026-10-18-045500/`）
2. `scripts/release-v1.7.0.ps1` 不再打印口令明文，改从环境变量或 `android/local.properties`（已忽略）读取；仓库不保存任何签名口令
3. GitHub Actions Secrets（`KEYSTORE_BASE64` / `KEYSTORE_PASSWORD` / `KEY_ALIAS` / `KEY_PASSWORD`）请按上表配置

## 关于 v1.5.0 的处理建议（二选一）

- **推荐**：保留 Release 但在其说明中置顶警告“此版本签名有误，安装后将无法升级后续版本，请跳过本版本”
- 或直接删除 v1.5.0 Release，让用户从 v1.4.0 直接升级 v1.6.0（签名连续）
- 注：已发布 APK 的签名无法事后修改，重新签名替换会改变包哈希且无法解决已装用户的升级问题

## 安全加固（2026-10-22）

- 仓库内**不再保存任何签名口令**：`build.gradle.kts` 从环境变量或 `android/local.properties`（已 gitignore）读取
- 已安装 gitleaks 并启用提交前扫描，历史/工作区/暂存区泄露都会被拦截
- 本文档早期版本曾包含明文口令并已推送到远端，**建议更换密钥库口令**（更换口令不影响已发布 APK 的签名证书与升级兼容性）

## 验证方法复现

```bash
# 单个 APK 提取签名证书指纹（v2/v3 签名）
keytool -printcert -jarfile melodyflow-v1.6.0-android.apk
# 注意：JDK 17 的 keytool -jarfile 对仅 v2 签名（无 META-INF/*.RSA）的包会误报"未签名"，
# 应使用 apksigner verify --print-certs 或解析 APK Signing Block
```
