# MelodyFlow v1.7.0

> 本次更新的核心：**真正把后台播放做完了**。此前 `audio_service` / `audio_session` 虽在依赖中声明，但代码里从未接线，属于"声明了却未实现"的缺失功能，这一版补齐并打通了通知栏、锁屏与线控的双向控制。

---

## ✨ 新功能

### 📱 后台播放与系统媒体控制

- **通知栏 / 锁屏媒体控制**：播放、暂停、上一首、下一首、拖动进度，全部与 APP 内播放页**实时双向同步**
- **耳机与蓝牙线控**：支持耳机按键、蓝牙设备媒体键控制播放
- **锁屏封面与信息**：通知栏与锁屏显示歌曲标题、歌手、专辑封面与播放进度
- **后台持续播放**：切到后台或锁屏后音乐不再中断（iOS / Android 均已处理）

### 🛡️ 系统音频行为

- 通过 `audio_session` 配置音乐音频类别，正确处理**音频焦点**
- 来电、其他 App 抢占音频时自动暂停，让出焦点
- 耳机拔出时按系统行为暂停播放

---

## 🐛 修复

- **iOS 锁屏后音乐必停**：`Info.plist` 增加 `UIBackgroundModes: audio`
- **Android 通知缺失**：新增单色矢量通知图标 `ic_stat_music_note.xml`
- **Android 14+ 前台服务**：显式声明 `foregroundServiceType="mediaPlayback"`
- **CI 无法创建 Release**：补充缺失的 `release_template.md`（此前三个平台构建成功后，创建 Release 步骤仍会失败）

---

## 🧰 技术变更

| 模块 | 变更 |
|------|------|
| 新增 `lib/services/audio_handler.dart` | 基于 `audio_service` 的后台播放处理器，同步播放状态到系统媒体通道 |
| `lib/services/audio_player_service.dart` | 新增 `onSongChanged` / `onPlaybackChanged` 状态回调 |
| `lib/providers/music_provider.dart` | 装配音频处理器，双向转发控制指令与播放状态 |
| `lib/main.dart` | 启动时初始化 `audio_service` 与 `audio_session` |
| `.github/workflows/build.yml` 配套 | 补齐 Release 模板文件 |

---

## ⬇️ 下载与校验

| 平台 | 文件 | 说明 |
|------|------|------|
| Android | `melodyflow-v1.7.0-android.apk` | Android 7.0+，正式签名（统一签名，可覆盖升级） |
| Windows | `melodyflow-v1.7.0-windows.zip` | Windows 10+ |
| iOS | `melodyflow-v1.7.0-ios.ipa` | iOS 13.0+，需自签 |

每个 APK 均附带同名 `.sha256` 校验文件，可使用 `sha256sum -c` 验证下载完整性：

```bash
sha256sum -c melodyflow-v1.7.0-android.apk.sha256
```

---

## 📌 升级提示

- 从 v1.6.0 及更早版本升级：签名一致，可直接覆盖安装，播放列表与设置不会丢失
- 若通知栏未出现播放控制，请到系统设置中确认已授予 MelodyFlow **通知权限**

---

## 🔗 完整变更

详见 [CHANGELOG.md](https://github.com/2016YYy/melodyflow/blob/main/CHANGELOG.md)
