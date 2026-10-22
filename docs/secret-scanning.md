# 敏感信息扫描（gitleaks）

> 本仓库已接入 gitleaks，用于在提交、构建、发版、CI 各环节拦截密码 / Token / API Key / 私钥等敏感信息泄露。

## 已安装内容

| 组件 | 位置 | 作用 |
|------|------|------|
| gitleaks 8.30.1 | `../tools/gitleaks/gitleaks.exe`（工作区工具目录） | 扫描引擎 |
| 规则配置 | [`.gitleaks.toml`](../.gitleaks.toml) | 官方默认规则 + 本项目自定义规则 |
| 提交钩子 | [`.githooks/pre-commit`](../.githooks/pre-commit) | 提交前扫描暂存区，发现泄露即阻止提交 |
| 扫描脚本 | [`scripts/secret-scan.ps1`](../scripts/secret-scan.ps1) | staged / history / dir / all 四种模式 |
| 安装脚本 | [`scripts/setup-gitleaks.ps1`](../scripts/setup-gitleaks.ps1) | 一键安装并启用钩子 |
| CI 扫描 | [`.github/workflows/secret-scan.yml`](../.github/workflows/secret-scan.yml) | 推送 / PR / 打标签自动全历史扫描 |

## 四层防护

1. **提交前**（`git commit`）— `.githooks/pre-commit` 自动扫描暂存区，命中即中断提交
2. **构建 / 发版前** — `scripts/release-v1.7.0.ps1` 第一步强制跑 `secret-scan.ps1 -Mode all`，不通过则中止发版
3. **CI** — 每次 push / PR / tag 自动扫描全历史与工作区，报告作为 artifact 上传
4. **手动** — 随时可执行下面的命令自查

## 常用命令

```powershell
# 全量检查（历史 + 工作区）——发版前必跑
pwsh -File scripts/secret-scan.ps1 -Mode all

# 只查暂存区（钩子做的事）
pwsh -File scripts/secret-scan.ps1 -Mode staged

# 只查全部历史（相当于"云端所有版本"）
pwsh -File scripts/secret-scan.ps1 -Mode history

# 新环境安装 / 重新启用钩子
pwsh -File scripts/setup-gitleaks.ps1
```

## 处理扫描结果

| 情况 | 做法 |
|------|------|
| 确实泄露 | 立即从代码移除，并**更换该凭据**（已推送过就必须视为已泄露） |
| 误报 | 在该行末尾加 `# gitleaks:allow` |
| 需长期忽略（保留审计） | 把 fingerprint 追加到 `.gitleaksignore` |
| 二进制/构建产物 | 在 `.gitleaks.toml` 的 `allowlist.paths` 增加路径 |

## 签名口令的正确存放方式

仓库内**不保存任何签名口令**：

- CI：通过 GitHub Actions Secrets 注入 `KEYSTORE_PASSWORD` / `KEY_PASSWORD` / `KEY_ALIAS`
- 本地：在 `android/local.properties`（已被 `.gitignore` 忽略）配置
  ```properties
  keystore.storePassword=***
  keystore.keyPassword=***
  keystore.keyAlias=melodyflow
  ```
- `android/app/build.gradle.kts` 读取顺序：环境变量 → `local.properties` → 未配置时使用 debug 签名并告警

## 2026-10-22 历史审计结论（摘要）

- 扫描范围：全部 refs 共 41 个提交（含 main、v1.6.0、各 tag）
- 命中 **14 条**泄露记录，分布在 4 个历史提交、4 个文件：
  - `android/app/build.gradle.kts`（签名口令作为默认值，最早提交起）
  - `scripts/release-v1.7.0.ps1`（脚本打印口令）
  - `docs/signing-verification.md`、`docs/ci-diagnosis.md`（文档中含明文口令）
- 当前工作区 / HEAD：**0 条**（已针对上述文件脱敏）
- 历史提交中的记录无法通过新增提交消除，处置建议见下节

## 历史泄露的处置建议

1. **必须**：更换密钥库口令（口令曾出现在提交历史中，应视为已泄露）。
   更换口令**不影响**已发布 APK 的签名证书与用户升级兼容性。
2. **建议**：将脱敏后的提交推送到 `main`，保证远端最新代码不再包含明文。
3. 如需彻底清除历史记录：使用 `git filter-repo` 重写历史并强推 —— 破坏性操作，需评估对其他 clone / tag 的影响后再执行。
