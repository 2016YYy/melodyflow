# 更新日志

本项目遵循 [语义化版本](https://semver.org/lang/zh-CN/) 规范。

---

## [1.7.2] - 2026-10-30

### 🐛 修复 CI 构建与发布（Android 正式打通）

这一版把 GitHub Actions 的 Android 构建从"从未成功过"推到**产出正式签名 APK 并自动发布 Release**。

- **NDK 版本取错，导致 runner 装错 NDK**：`Install Android NDK` 步骤此前 `grep ... | head -1` 扫整个
  `flutter_tools/gradle/src`，命中了 `FlutterPluginUtils.kt` 里的历史兜底常量 `21.1.6352462`。
  现改为只在 `src/main/kotlin/FlutterPluginUtils.kt` 取最大版本号，与 Flutter 实际生效值一致。
- **AGP / Kotlin 与 Flutter 3.44.9 不配套（NDK 问题的真正根因）**：`settings.gradle.kts` 原为
  AGP 8.9.1 + Kotlin 2.1.20，而 Flutter 3.44.9 的 `flutter_tools/gradle` 依赖 AGP 8.11.1 + Kotlin 2.2.20。
  AGP 8.9 自带默认 NDK `27.0.12077973`，于是无论 SDK 里装了什么版本都报
  `NDK not configured. Preferred NDK version is '27.0.12077973'`。升到 **8.11.1 / 2.2.20** 后该错误消失。
- **`local.properties` 被写成残缺的 `ndk.dir`**：安装步骤引用了上一步的局部变量，导致：
  `[CXX1101] NDK at .../sdk/ndk did not have a source.properties file`。
  现只写 `sdk.dir` 与 `flutter.sdk`，让 AGP 自己扫已注册的 NDK 版本。
- **`on_audio_query_android` 缺 namespace（AGP 8 起必填）**：该包 1.1.0 是 2022 年停更的版本，
  `android/build.gradle` 里只有 `group`，没有 `android { namespace }`。pub-cache 只读、每次
  `pub get` 会重建，只能在 root 侧补。实测 **`afterEvaluate` 太晚**（AGP 在
  `CrashReporting$afterEvaluate` 里就创建 `VariantBuilder`，并打印 `ns=null`），
  必须落在 `plugins.withId("com.android.library")` 回调内 —— 它早于 AGP 注册的 afterEvaluate。
- **老包 JVM Target 不一致**：`compileReleaseKotlin` 报
  `Inconsistent JVM-target compatibility ... 'compileReleaseJavaWithJavac' (1.8) and 'compileReleaseKotlin' (17)`。
  反射 `compilerOptions` 与任务级 `doFirst` 均无效（校验发生在 eager 阶段），最终在 root 把该子项目的
  `JavaCompile` 拉到 17，并用 `kotlin.jvm.target.validation.mode=warning` 兜底。
- **`AudioServiceConfig` 断言冲突**：`androidNotificationOngoing=true` 必须搭配
  `androidStopForegroundOnPause=true`，原写法触发 const 求值断言失败，`kernel_snapshot_program` 直接中断。
- **Release 资产缺失导致发布失败**：`action-gh-release` 的 `files` 仍列着早已 `if: false` 的
  `windows-zip/*` 与 `ios-ipa/*`，上传时找不到文件即失败。现只收 `android-apk/*`。
- **Release 只在 tag 触发**：手动 `workflow_dispatch` 仅验证构建，不会误发半成品。
- **补建历史版本时找不到补丁脚本**：`workflow_dispatch` 填 `build_ref` 重建老版本时，checkout 出的是老 tag
  的树，里面没有本轮才新增的 `scripts/patch_legacy_tag.py`，报
  `python3: can't open file '.../scripts/patch_legacy_tag.py'`。现改为从 `origin/main` 取该脚本再执行，
  并新增 `--root "$GITHUB_WORKSPACE"` 参数（脚本原先靠 `__file__` 推断项目根，复制到临时目录后推断错误）。
- **老版本 AGP / KGP 版本在 Google Maven 上不存在**：`v1.6.0` 写的是 AGP 9.1.0 + Kotlin 2.4.0，
  `v1.7.0` 是 9.0.1 + 2.3.20，而 9.x 从未发布过，报 `Plugin [id: 'com.android.application', version: '9.0.1'] was not found`。
  这正是这两个版本当年没能产出 Release 的根因之一。现由补丁脚本统一下调到 **8.11.1 / 2.2.20**。
- **老版本 gradle.properties 写死了本机代理**：`v1.7.0` / `v1.7.1` 的 `org.gradle.jvmargs` 带着
  `-Dhttp.proxyHost=127.0.0.1 -Dhttp.proxyPort=18080` 等参数，runner 上该代理不存在，Maven 全部连不上，
  Gradle 却报成"插件版本不存在"——极难辨认。现由补丁脚本只针对 `org.gradle.jvmargs` 这一行剥离代理参数
  （不能全局替换，注释里的示例文本会被误伤）。
- **老版本 Gradle wrapper 版本与 AGP 不兼容**：`v1.7.0` 用 gradle 9.8.1，AGP 依赖的
  `org.gradle.api.problems.internal.InternalProblems` 在 Gradle 9.6.0 已被移除，报
  `... a Gradle internal API that was removed in Gradle 9.6.0 ... or use Gradle 9.5`。现统一到 **8.14.3**。
- **老版本 `app/build.gradle.kts` 里 `java.util.Properties()` 解析失败**：kts 脚本中 `java` 会被当作
  Gradle 的 JavaPluginExtension 扩展而非包名，报 `Unresolved reference: util`。现补 `import java.util.Properties`
  并改用短名（仅改代码行，不碰注释里的旧写法）。
- **`on_audio_query_android` 写死 `compileSdkVersion 33`**：runner 只预装 Flutter 需要的平台（36），
  报 `Failed to find target with hash string 'android-33'`。root 侧反射兜底（`plugins.withId` 与
  `gradle.projectsEvaluated` 两条路径）实测都赶不上——该值在更早的 DSL 求值阶段就固化了。
  最终改为在 CI 里直接 `sdkmanager --install platforms;android-33`，确定性最强。
- **缺少 CMake 3.22.1**：android-33 就位后新暴露 `[CXX1300] CMake '3.22.1' was not found`，
  同为 GitHub 镜像未预装，一并由 `sdkmanager --install cmake;3.22.1` 补上。
- **补建 Release 的正文版本号张冠李戴**：`release_template.md` 跟随 tag 提交，旧 tag 里写的是当年版本号，
  `body_path` 直接引用会让 `v1.7.0` 的正文标题与下载表都写成 `v1.7.1`。现新增
  `Render release body` 步骤，用 `sed` 把模板里的版本号统一替换为本次发布目标版本。

### 📄 文档与发布模板对齐真实产物

- **`.github/release_template.md` 重写**：不再列出从未产出过的 Windows `.zip` / iOS `.ipa`，
  下载表只留 Android APK 与 `.sha256`，并补上 `### 🔒 完整性校验` 与 v1.5.0 签名断裂的升级提示。
- **README 修正平台声明**：删除「支持 Android / iOS / Windows 三端」的表述与对应徽章，
  改为明确「当前官方发布 Android 版本」，源码构建命令里 iOS / Windows 两行标注为未启用。

---

本](https://semver.org/lang/zh-CN/) 规范。

版本格式：`主版本号.次版本号.修订号`

## [1.7.1] - 2026-10-22

### 🔒 安全：清除历史中泄露的签名密钥口令

- **重写 Git 历史**（git-filter-repo），彻底移除散落在历史提交中的发布签名密钥库明文口令（即原主线密钥库口令与 v1.5.0 误用密钥口令）。该口令曾出现于 `docs/signing-verification.md`、`scripts/release-v1.7.0.ps1`、`android/app/build.gradle.kts` 等多处历史提交，任何克隆仓库者均可读取。
- **修复 CI 密钥扫描失效**：`secret-scan.yml` 此前依赖 `.gitleaksignore` 压制历史命中，导致流水线"永远绿"，形成假阴性安全错觉。现已移除该掩盖文件，并锁定 gitleaks 版本、`gitleaks git`/`gitleaks dir` 任一命中即阻断合并与发布。
- **增强检测规则**：`.gitleaks.toml` 的 `plaintext-password-in-doc` 规则扩展为兼容 `密码 x`、`密码:x`、`密码|x`、`密码：x` 多种分隔写法，补上空格分隔口令的漏检缺口。
- **修复发布流水线**：`build.yml` 的 Release 阶段此前依赖已禁用的 windows/ios 产物，会导致新版本发布失败；现已仅依赖实际构建产物 `android-apk/*`。
- **⚠️ 仍须人工处置**：密钥库口令已暴露，请在本地将 `melodyflow-release.jks` 的 store/key 口令更换为新值，并同步更新 GitHub Actions Secret `KEYSTORE_PASSWORD` / `KEY_PASSWORD`（及必要时重新生成签名密钥）。

## [1.7.0] - 2026-10-17

### 🔧 后台播放与通知栏控制（补齐缺失功能）

- **接入 audio_service**：将 `AudioPlayerService` 的播放状态同步到系统通知栏、锁屏媒体控制中心与耳机 / 蓝牙线控（此前 `pubspec.yaml` 已声明 `audio_service` / `audio_session` 依赖，但 `lib/` 下从未接线，功能实际缺失）
- **双向同步**：播放 / 暂停 / 上一首 / 下一首 / 拖动进度，通知栏与 APP 内播放页完全互通
- **音频会话**：通过 `audio_session` 配置音乐音频类别，正确处理音频焦点、来电/耳机拔出自动暂停等系统行为
- **iOS 后台音频**：在 `Info.plist` 增加 `UIBackgroundModes: audio`，修复 iOS 锁屏后音乐必停的问题
- **Android 通知图标**：新增单色矢量图标 `ic_stat_music_note.xml`，并显式声明 `AudioService` 的 `foregroundServiceType="mediaPlayback"`（Android 14+ 前台媒体服务必需）

### 🧰 工程与发布

- **修复 CI 发布缺陷**：补充缺失的 `.github/release_template.md`，此前 `action-gh-release` 会因 `body_path` 指向不存在的文件而失败，导致三个平台构建成功后仍无法创建 Release
- **完善发布流程**：新增 `scripts/release-v1.7.0.ps1` 一键发布脚本（推送 tag 自动触发云端构建，并输出签名 Secret 配置项）
- **校正文档**：README 技术栈补充 `audio_session`，项目结构补充 `audio_handler.dart`，下载表版本号更新为 `v1.7.0`


## [1.6.0] - 2026-10-17

### 🎛️ 音频效果

- **16 段参数均衡器**：覆盖 20Hz ~ 16kHz 标准 ISO 频段，每段独立调节 ±12dB
- **11 种内置预设**：平直、流行、摇滚、爵士、古典、人声、低音、高音、电子、舞曲、原声，一键切换
- **响度归一化**：ReplayGain 风格的 loudnorm 处理，统一不同歌曲音量
- **交叉淡入淡出**：播放/暂停与切歌时音量平滑过渡
- **变速不变调**：0.25x ~ 4.0x 倍速，基于 scaletempo 保持原始音高
- 播放页新增「音效」入口，设置页新增「均衡器与音效」入口

### 📊 歌曲详情

- 播放页新增「信息」按钮，展示标题、艺术家、专辑、音轨、时长、格式、比特率、采样率、文件大小、添加/修改时间与文件路径
- 本地扫描时自动记录格式、比特率（按文件大小与时长估算）、采样率、音轨号与时间戳

### 🚀 应用更新加速

- 内置多个 GitHub 下载镜像源（ghProxy、GH-ACC、KKGitHub 等），解决更新下载卡顿/缓慢问题
- 设置页支持手动选择镜像源；下载失败时自动尝试其他可用镜像

### 🧩 与 v1.5.0 功能整合

- 完整保留 v1.5.0 的睡眠定时、播放队列、最近播放、歌曲排序与首页快捷区
- 统一睡眠定时入口（播放页 / 音频效果页共享同一状态）

### 🛠️ 构建与验证

- `flutter analyze` 零告警
- release 构建通过，签名与历史版本一致，可直接覆盖升级

---

## [1.5.0] - 2026-10-17

### ✨ 新增功能（对标主流播放器）

- **睡眠定时器**：播放页底部工具条可设置 15/30/45/60 分钟倒计时或「播完当前歌曲」自动暂停
- **播放队列页**：查看当前队列、点击跳转播放、左滑移除、一键清空
- **倍速播放**：支持 0.5x / 0.75x / 1.0x / 1.25x / 1.5x / 2.0x
- **最近播放**：自动记录播放历史（上限 100 首），支持清空与一键播放全部
- **歌曲排序**：支持默认 / 按标题 / 按艺术家 / 按时长排序

### 🎨 UI 改版

- 首页新增快捷功能区：播放全部、随机播放、最近播放、我喜爱（带数量角标）
- 分类标签栏右侧新增排序入口
- 播放页新增底部工具条（队列 / 倍速 / 定时），激活状态高亮显示

---

## [1.4.0] - 2026-10-16

### 🎵 播放器皮肤差异化

- **经典皮肤**：唱片从方形纸袋封套右侧露出，营造复古唱片质感
- **现代皮肤**：大圆角方块封面 + 玻璃高光 + 柔和投影
- **极简皮肤**：细描边、内缩留白、无阴影的扁平风格
- **黑胶皮肤**：保留黑胶唱片旋转动画
- 四种皮肤现在拥有**明显不同的视觉形态**，设置页图标与之一一对应

### 🎨 设计系统收敛

- 新增 `AppColors` 语义色（喜爱红、危险红），替换散落的硬编码颜色
- 迷你播放器 / 底部导航栏背景统一取自 `cardColor`
- 滑动删除条统一为可复用的 `SwipeDismissBackground` 组件
- 播放页沉浸式背景底色改为跟随主题 `scaffoldBackgroundColor`

### 🧹 代码清理

- 播放页移除无实现的「更多」占位按钮
- 音源页移除无效的 `onMore` 参数传递
- 合并重复的音源图标 / 类型名映射为统一函数，设置页与播放页共用皮肤图标

### 🛠️ 构建与验证

- 新增设计规范、语义色与皮肤配置的一致性测试
- `flutter analyze` 零告警，`flutter test` 全绿
- release 构建跳过非必需的 lint 检查，提升打包稳定性

---

## [1.3.0] - 2026-10-16

### 🎨 全界面视觉重构

- **统一设计系统**：新增 `AppRadius`（圆角）与 `AppSpace`（间距）规范，以 Material You 种子色驱动整套配色
- **组件主题统一**：按钮、输入框、对话框、底部弹窗、标签栏、开关、弹出菜单、FAB 等全部统一风格
- **深色 / 浅色基色统一**：深浅两套表面基色更加协调

### 🧭 底部导航与迷你播放器

- 底部导航栏改为**浮动胶囊式**：文字图标一体，选中时图标由描边过渡为填充、文字同步变色加粗
- 迷你播放器改为**浮动圆角卡片**，底部带播放进度线，封面带柔和阴影

### 🎵 播放页沉浸式重设计

- **模糊专辑封面**作为沉浸式背景，并渐隐到主题底色
- 封面改为圆角卡片（黑胶皮肤保留旋转动画），**长按可全屏放大**
- 进度条、时间、控制按钮全部适配深色 / 浅色主题，播放按钮改为渐变填充
- 歌词视图：当前行高亮并自动居中，适配深浅主题

### 📚 音乐库与详情页

- 歌曲行统一圆角与内边距，**正在播放行浅色高亮 + 跳动竖线标识**
- 收藏页 / 专辑 / 艺术家 / 歌单详情页使用**统一封面头图**，支持「播放全部」「随机播放」
- 收藏页新增空状态引导，支持滑动移除

### ☁️ 音源与 WebDAV

- 音源改为**卡片化展示**，新增连接状态指示与测试连接
- WebDAV 文件夹浏览升级为**胶囊面包屑导航**

### 🛠️ 修复

- 修复 `size: double.infinity` 场景下封面占位图标尺寸为无穷大的问题
- 清理进度条组件中冗余的配色逻辑，统一走主题色

### ⚡ 优化

- 新增主题与组件渲染测试，`flutter analyze` 警告全部清零
- 统一 FAB 与弹出菜单主题，交互反馈更一致

---

## [1.2.0] - 2026-10-16

### 🧭 底部菜单栏重构

- 文字与图标一体设计，点击时图标（描边→填充）与文字（颜色/字重）同步变化
- 音乐 / 音源 / 设置 以标签页形式切换，选中状态带高亮胶囊动效

### 🔍 扫描歌曲

- 音乐库右上角新增「扫描歌曲」功能入口，一键扫描本地音乐

### ❤️ 「我喜爱」歌单

- 播放页爱心按钮带弹跳动画，点击即加入「我喜爱」系统歌单
- 歌单页置顶「我喜爱」入口，展示数量；收藏详情页支持播放全部 / 随机播放 / 滑动移除

### ⚙️ 设置页与关于页重构

- 设置页改为分组列表样式（外观 / 应用更新 / 关于）
- 关于页新增系统信息、应用更新、外部链接分组，居中品牌展示

### 🔄 更新体验重构

- 更新弹窗改为圆角居中卡片，支持「跳过此版本 / 下载并安装」
- 下载进度弹窗支持「隐藏」后台继续下载

---

## [1.1.0] - 2026-10-16

### 🎨 界面与主题

- 全新视觉设计，统一排版与交互风格
- **6 套主题配色**：梦幻紫、海洋蓝、翡翠绿、日落橙、玫瑰粉、琥珀金；**深浅模式**一键切换

### 📱 首页重构

- 增加 **歌曲 / 专辑 / 艺术家 / 歌单** 四个分类标签，专辑与艺术家以卡片网格展示

### 📋 歌单管理

- 创建、重命名、删除歌单；从曲库添加歌曲；滑动移除歌单内歌曲

### 🌐 WebDAV 文件夹浏览

- 面包屑导航，支持逐级浏览；选择文件夹扫描音乐并播放

### 🎵 播放器增强

- **4 种播放器皮肤**：经典、现代、极简、黑胶；黑胶皮肤带唱片旋转动画
- **长按专辑封面**全屏放大；**渐变动画进度条**支持拖动跳转

---

## [1.0.0] - 2025-10-16

### 🎉 首个正式版本发布

#### ✨ 新功能
- **跨平台支持**：Android / iOS / Windows 三端统一
- **本地音乐扫描**：自动扫描设备本地音乐文件
- **多格式播放**：基于 media_kit 引擎，支持 MP3、FLAC、WAV、AAC、OGG、M4A、WMA、ALAC、APE 等
- **第三方音源**：
  - WebDAV 网盘接入
  - HTTP API 自定义服务器
  - SMB 局域网共享
- **在线歌词**：自动匹配 LRC 歌词，逐行滚动显示，支持点击跳转
- **专辑封面**：自动提取内嵌封面，缺失时从网络获取
- **播放控制**：
  - 单曲循环 / 列表循环 / 随机播放
  - 倍速播放（0.5x ~ 2.0x）
  - 后台播放与通知栏控制
- **应用内更新**：
  - 检查 GitHub Release 最新版本
  - 下载进度条实时显示
  - 支持后台下载与取消
  - SHA-256 完整性校验
- **统一签名**：所有版本使用同一签名密钥，确保可无缝升级
- **主题**：深色/浅色模式切换，紫蓝渐变设计

#### 🔧 技术实现
- Flutter 3.x + Dart 3
- media_kit 高性能音频引擎
- on_audio_query 本地媒体扫描
- dio 网络请求
- provider 状态管理

#### 📝 备注
- 本版本为初始版本，功能持续迭代中
- 在线歌词与封面数据来源为公开 API，仅供学习交流
