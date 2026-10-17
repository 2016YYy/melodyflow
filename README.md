# 🎵 MelodyFlow

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Windows-green)]()
[![Release](https://img.shields.io/github/v/release/2016YYy/melodyflow)](https://github.com/2016YYy/melodyflow/releases)

> 开源跨平台音乐播放器 — 让音乐如流水般顺畅播放

MelodyFlow 是一款基于 **Flutter** 开发的开源跨平台音乐播放器，支持 **Android / iOS / Windows** 三端。采用最新的 `media_kit` 音频引擎，支持本地音乐扫描、第三方音源接入、在线歌词与封面获取，并内置应用内更新能力。

---

## ✨ 核心特性

### 🎧 本地音乐
- 📂 **自动扫描**本地音乐文件，支持多级目录
- 🎼 **多格式支持**：MP3, FLAC, WAV, AAC, OGG, M4A, WMA, ALAC, APE, Opus 等
- 💿 **专辑封面**：自动提取内嵌封面，缺失时在线获取
- 📝 **歌词**：支持内嵌 LRC 歌词，自动在线匹配并逐行滚动

### ☁️ 第三方音源
- 🔌 **WebDAV**：连接群晖、Nextcloud、阿里云盘等网盘
- 🌐 **HTTP API**：接入自定义音乐服务器
- 📁 **SMB**：局域网共享文件夹
- 🔐 支持用户名密码 / Token / 自定义请求头认证

### 🎛️ 播放体验
- ⚡ 基于 [media_kit](https://github.com/media-kit/media-kit) 的高性能音频引擎
- 🔁 单曲循环 / 列表循环 / 随机播放
- ⏩ 倍速播放（0.5x ~ 2.0x）
- 📱 后台播放与通知栏控制
- 🎨 根据封面自动取色的沉浸式界面
- 🕒 睡眠定时器（15/30/45/60 分钟 / 播完当前歌曲自动暂停）
- 🎶 播放队列管理（跳转 / 移除 / 清空）

### 📚 音乐库
- 📻 歌曲 / 专辑 / 艺术家 / 歌单分类浏览
- 🏠 首页快捷区：播放全部、随机播放、最近播放、我喜爱
- 🕘 最近播放记录（自动记录，可一键续播）
- ⇅ 歌曲排序（默认 / 标题 / 艺术家 / 时长）

### 🔄 应用内更新
- 🔍 启动时自动检查 GitHub Release 新版本
- 📊 **下载进度条**实时显示
- ⏸️ 支持后台下载，可取消
- 🔒 **SHA-256 签名校验**，确保更新包完整未篡改
- 🔑 统一安装签名，后续版本无缝升级

---

## 🚀 快速开始

### 下载安装

前往 [Releases](https://github.com/2016YYy/melodyflow/releases) 页面下载对应平台安装包：

| 平台 | 文件 | 说明 |
|------|------|------|
| Android | `melodyflow-vX.X.X-android.apk` | Android 7.0+ |
| iOS | `melodyflow-vX.X.X-ios.ipa` | iOS 13.0+（需自签） |
| Windows | `melodyflow-vX.X.X-windows.exe` | Windows 10+ |

### 从源码构建

```bash
# 克隆仓库
git clone https://github.com/2016YYy/melodyflow.git
cd melodyflow

# 安装依赖
flutter pub get

# 生成应用图标
flutter pub run flutter_launcher_icons

# 构建 Android APK
flutter build apk --release

# 构建 Windows 安装包
flutter build windows --release

# 构建 iOS
flutter build ios --release
```

---

## 🛠️ 技术栈

| 模块 | 技术 |
|------|------|
| 跨平台框架 | [Flutter](https://flutter.dev) / Dart |
| 音频引擎 | [media_kit](https://github.com/media-kit/media-kit) |
| 后台播放 | [audio_service](https://pub.dev/packages/audio_service) |
| 本地扫描 | [on_audio_query](https://pub.dev/packages/on_audio_query) |
| 网络请求 | [dio](https://pub.dev/packages/dio) |
| 状态管理 | [provider](https://pub.dev/packages/provider) |
| 图片缓存 | [cached_network_image](https://pub.dev/packages/cached_network_image) |
| 版本更新 | GitHub Release API |

---

## 📁 项目结构

```
melodyflow/
├── lib/
│   ├── main.dart                  # 应用入口
│   ├── models/                    # 数据模型
│   │   ├── song.dart              # 歌曲
│   │   ├── playlist.dart          # 歌单
│   │   ├── music_source.dart      # 音源配置
│   │   └── lyric.dart             # 歌词
│   ├── services/                  # 业务服务
│   │   ├── music_scanner_service.dart   # 本地音乐扫描
│   │   ├── audio_player_service.dart    # 音频播放引擎
│   │   ├── lyrics_service.dart          # 在线歌词
│   │   ├── album_art_service.dart       # 专辑封面
│   │   ├── remote_source_service.dart   # 第三方音源
│   │   ├── update_service.dart          # 应用内更新
│   │   └── storage_service.dart         # 本地存储
│   ├── providers/                 # 状态管理
│   │   └── music_provider.dart
│   ├── screens/                   # 界面
│   │   ├── home_screen.dart       # 首页（本地音乐）
│   │   ├── player_screen.dart     # 播放器
│   │   ├── sources_screen.dart    # 音源管理
│   │   └── settings_screen.dart   # 设置/更新
│   ├── widgets/                   # 复用组件
│   │   ├── song_tile.dart
│   │   ├── mini_player.dart
│   │   └── lyrics_view.dart
│   └── theme/                     # 主题
│       └── app_theme.dart
├── assets/icons/                  # 应用图标
└── .github/workflows/             # CI/CD
```

---

## ⚠️ 免责声明

1. MelodyFlow 是**开源免费**软件，仅供个人学习研究使用。
2. 本软件**不提供任何音乐资源**，所有音乐均来自用户本地或用户自行配置的第三方服务器。
3. 用户应确保其使用的音乐资源已获得合法授权，因版权问题产生的法律责任由**用户自行承担**。
4. 在线歌词与封面数据来源于公开 API，仅供学习交流，**请勿用于商业用途**。
5. 本软件不对第三方音源的内容、可用性、安全性做任何保证。
6. 使用本软件即表示您已阅读并同意以上条款。

---

## 📜 更新日志

详见 [CHANGELOG.md](CHANGELOG.md)

---

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

---

## 📄 许可证

[MIT License](LICENSE)

---

## 🔗 致谢

- [BloomeeTunes](https://github.com/HemantKArya/BloomeeTunes) - 跨平台音乐播放器参考
- [MusicFree](https://github.com/maotoumao/MusicFree) - 多音源架构参考
- [media_kit](https://github.com/media-kit/media-kit) - 高性能跨平台音频引擎
