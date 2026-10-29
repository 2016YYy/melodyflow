## 🎵 MelodyFlow v1.7.1 - 后台播放落地，系统媒体控制打通

> 本次更新的核心：**真正把后台播放做完了**。此前 `audio_service` / `audio_session` 虽在依赖中声明，但代码里从未接线，属于声明了却未实现的缺失功能，这一版补齐并打通了通知栏、锁屏与线控的双向控制。

---

### ✨ 新功能

- **通知栏 / 锁屏媒体控制**：播放、暂停、上一首、下一首、拖动进度，全部与 APP 内播放页实时双向同步
- **耳机与蓝牙线控**：支持耳机按键、蓝牙设备媒体键控制播放
- **锁屏封面与信息**：通知栏与锁屏显示歌曲标题、歌手、专辑封面与播放进度
- **后台持续播放**：切到后台或锁屏后音乐不再中断

### 🐛 修复

- **iOS 锁屏后音乐必停**：`Info.plist` 增加 `UIBackgroundModes: audio`
- **Android 通知缺失**：新增单色矢量通知图标 `ic_stat_music_note.xml`
- **Android 14+ 前台服务**：显式声明 `foregroundServiceType="mediaPlayback"`
- **CI 无法创建 Release**：补齐缺失的 `release_template.md`，此前三端构建成功仍会因 `body_path` 不存在而失败

### 📦 下载

| 平台 | 文件 | 说明 |
|------|------|------|
| Android | `melodyflow-v1.7.1-android.apk` | Android 7.0+，正式签名，可覆盖升级 |
| Android 校验 | `melodyflow-v1.7.1-android.apk.sha256` | SHA-256 校验文件 |

> iOS 与 Windows 构建当前未启用，本版本不产出对应安装包。

### 🔒 完整性校验

```bash
sha256sum -c melodyflow-v1.7.1-android.apk.sha256
```

### 📌 升级提示

- 从 v1.6.0 及更早版本升级：签名一致，可直接覆盖安装，播放列表与设置不会丢失
- **例外**：v1.5.0 使用了另一把签名密钥，从该版本升级需先卸载（详见 v1.5.0 说明）
- 若通知栏未出现播放控制，请到系统设置中确认已授予 MelodyFlow **通知权限**

### 🔗 完整变更

详见 [CHANGELOG.md](https://github.com/2016YYy/melodyflow/blob/main/CHANGELOG.md)
