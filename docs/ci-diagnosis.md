# CI 构建故障诊断记录（2026-10-18）

## 现状
- v1.7.0 代码与签名就绪（主线签名 `` 已验证与 v1.0.0~v1.4.0、v1.6.0 一致）
- CI 在 `flutter build` 的 Gradle 阶段失败：flutter_tools included build 的插件解析全部 404

## 已排除的原因（均有实证）
1. ~~Flutter 版本过低~~（3.24 Dart 3.5 不满足 ^3.12.0）→ 已升 3.47.7，pub get 通过
2. ~~release_template.md 缺失~~ → 已补
3. ~~阿里云镜像拦截~~ → 已移除
4. ~~网络不可达~~ → runner 上 curl 直连 Portal 返回 HTTP 200
5. ~~wrapper jar/gradlew 缺失~~ → 已恢复入库并补可执行位
6. ~~Gradle 版本~~ → 8.14.3 / 9.1.0 / 9.3.1 / 9.8.1 全部复现
7. ~~flutter_tools settings 缺 pluginManagement~~ → patch 后三仓库仍 404
8. ~~kotlin-dsl 插件声明~~ → 已 sed 删除（removed OK），错误推进到 kotlin(jvm)

## 关键证据
- runner 上 `curl -sSI https://plugins.gradle.org/.../kotlin.jvm.gradle.plugin/2.1.20/....pom` 返回 HTTP 200
- 同一 runner 上 Gradle daemon 解析同 URL 报 404（"could not resolve plugin artifact"）
- wrapper 下载（services.gradle.org）成功 → 进程级网络正常
- 结论：**Gradle daemon 在 CI 环境的 included build 插件解析请求未真正到达网络**
  （疑似 Gradle 9.x daemon 的 DNS/网络栈问题，或 included build 插件解析走了
  与依赖解析不同的传输路径）

## 关联上游
- gradle/gradle#23884（open）：kotlin-dsl 插件解析行为异常
- flutter/flutter#177233（closed-dup）：同报错，环境相关

## 建议的下一步（按优先级）
1. 在 TRAE CN / 本地跑 `flutter build apk --release` 验证代码本身可构建（本地 gradle 缓存完整，历史上成功过）
2. 本地成功后手动上传 APK 到 Release（或配置 self-hosted runner）
3. CI 后续可在有网络调试能力时继续：给 gradle 传 `--info` 抓取解析请求的真实 URL 与响应码
4. 或将 CI 的 Flutter 降到 3.35.x 系列验证是否为 3.4x 工具链回归
