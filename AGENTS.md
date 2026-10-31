# MelodyFlow 开发约定（Agent 必读）

## 一、发布前必须扫描敏感信息（硬性闸门）

任何**提交、打 tag、构建发布包**之前，必须先通过 gitleaks 扫描，命中即停，不允许"先发再补"。

### 本地（提交前自动）
```bash
git config core.hooksPath .githooks   # 一次性启用
# 之后每次 git commit 都会自动扫描暂存区（.githooks/pre-commit）
```

首次安装 gitleaks：
```powershell
pwsh -File scripts/setup-gitleaks.ps1
```
手动全量扫描：
```powershell
pwsh -File scripts/secret-scan.ps1            # 工作树
pwsh -File scripts/secret-scan.ps1 -Mode all  # 工作树 + 全历史
```

### CI（发版闸门）
`.github/workflows/build.yml` 的 `secret-scan` job 是 `build-android` 的 `needs` 前置，
`.github/workflows/secret-scan.yml` 在 push / PR / tag 上独立跑一遍。
两处都是**命中即非零退出**，Release 不可能绕过。

### 判读规则
- 只有 **`.gitleaks.toml`（带前导点）** 会被自动加载。命名为 `gitleaks.toml` 会被忽略，
  gitleaks 静默回退到内置默认规则集，而默认规则**没有** Android 签名口令规则，会给出假阴性。
- 正则必须写成 TOML 字面量字符串 `'''...'''`；`"""..."""` 会把 `\.` 当非法转义直接报
  `toml: invalid escaped character` 并使整份配置加载失败。
- 误报：行尾加 `# gitleaks:allow`。
- 真实泄露：移除凭据 → **立刻轮换** → 必要时重写历史。删文件不等于消除，历史 blob 仍可取回。

## 二、版本与发布
- 版本号在 `pubspec.yaml` 的 `version: x.y.z+build`；升级时同步写 `CHANGELOG.md`。
- 发布用 tag 触发：`git tag vX.Y.Z && git push origin vX.Y.Z`。
- 补建历史版本用 `workflow_dispatch` + `build_ref`，补丁脚本 `scripts/patch_legacy_tag.py`
  会把老 tag 的 AGP/Kotlin/wrapper/compileSdk/CMake/audio_service 等问题统一拉到当前可构建状态。
- Release 正文由 `.github/release_template.md` 渲染，版本号在 `Render release body` 步骤里替换，
  不要在模板里写死版本号。

## 三、签名
- 密钥库 **绝不入库**。CI 用 `KEYSTORE_PASSWORD` 等 secrets；本地用 `android/key.properties`（已 gitignore）。
- 主线证书 SHA-256 `20A59CCB…87AE`，subject `CN=MelodyFlow, O=MelodyFlow, L=Global`。
  v1.5.0 曾误用另一把密钥（L=Beijing），是唯一签名断裂的版本。
