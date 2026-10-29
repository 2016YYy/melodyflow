allprojects {
    repositories {
        maven { url = uri("https://maven.aliyun.com/repository/google") }
        maven { url = uri("https://maven.aliyun.com/repository/public") }
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
// 注意：这里【不能】用 subprojects { evaluationDependsOn(":app") }。
// root 脚本执行时 :app 往往已经被评估过，Gradle 会直接报
//   Cannot run Project.afterEvaluate(Action) when the project is already evaluated.
// 也就是说 evaluationDependsOn 一旦对已评估项目生效，就会让"后续 afterEvaluate 注册"变成非法操作，
// 连带把下面两段 afterEvaluate 补丁全部搞挂（历史上就是这样连续失败的）。
// Flutter 插件模块本来就会通过自身的 apply 逻辑依赖 :app 的输出目录，
// 真正需要的是 buildDir 重定向，上面的 subprojects {} 已经处理，无需强制评估顺序。

// 统一所有 Android 子项目的 NDK 版本。
//
// 背景：Flutter 插件（这里是通过 media_kit 相关依赖传递进来的 jni / jni_flutter）
// 会带入自己的 Android Gradle 工程（项目名 :jni），其中硬编码了自己的 ndkVersion。
//   · :app 用 flutter.ndkVersion（Flutter 3.44.9 声明 27.0.12077973）
//   · :jni 用插件自己的版本
// 只要某个版本对应的 NDK 目录在 CI 的 SDK 里不可用，AGP 就会在 configure 阶段直接
// 抛 "NDK not configured"，跟具体是哪个模块无关。
//
// 因此在 root 统一覆盖：用 MELODYFLOW_NDK_VERSION（CI 里按 SDK 中真实可用的 NDK 选定），
// 通过反射调用 setNdkVersion，避免在 root 脚本里直接引用 AGP 类型
// （root 的 classpath 未必包含 AGP）。
val ndkVersionOverride: String? = System.getenv("MELODYFLOW_NDK_VERSION")?.takeIf { it.isNotBlank() }
// 必须在 afterEvaluate 里覆盖，不能在 subprojects {} 里直接设。
// root 的 subprojects 块执行时，子项目自身的构建脚本还没跑；:jni（由 media_kit 相关
// 插件传递引入）会在自己的 android {} 里把 ndkVersion 设成插件作者的版本，
// 于是 root 早先的设置被覆盖回去，AGP 在配置 :jni 阶段报
// "NDK not configured. Preferred NDK version is ..."，与 :app 无关。
// 但只挂 afterEvaluate 也不够 —— 回调触发那一刻项目可能已经是 evaluated 状态，
// 再调 afterEvaluate 会抛 "Cannot run Project.afterEvaluate(Action) when the project
// is already evaluated."（实测 8a06cd3 就是这样整票失败的）。因此统一走 helper：
// 未评估就挂 afterEvaluate（保证插件自身的 android {} 已经执行完），已评估就立即执行。
// 注意：helper 不能定义成 Gradle 的扩展函数，否则在 plugins.withId 的 Project 接收者
// 里调用会撞 receiver 不匹配（Unresolved reference 一箩筐）。
fun applyAfterProjectEvaluated(proj: Project, action: () -> Unit) {
    if (proj.state.executed) {
        action()
    } else {
        proj.afterEvaluate { action() }
    }
}

listOf("com.android.library", "com.android.application").forEach { androidPluginId ->
    subprojects {
        plugins.withId(androidPluginId) {
            val proj = this
            applyAfterProjectEvaluated(proj) {
                val androidExt = proj.extensions.findByName("android")
                if (androidExt == null) {
                    proj.logger.lifecycle("[android-patch] ${proj.path} no android extension, skip")
                    return@applyAfterProjectEvaluated
                }

                // ---- 1) 统一 NDK 版本 ----
                val v = ndkVersionOverride
                if (v != null) {
                    runCatching {
                        androidExt.javaClass.getMethod("setNdkVersion", String::class.java).invoke(androidExt, v)
                        proj.logger.lifecycle("[ndk-override] ${proj.path} -> $v")
                    }.onFailure { e ->
                        proj.logger.lifecycle("[ndk-override] ${proj.path} failed: ${e.message}")
                    }
                }

                // ---- 2) 补齐缺失的 namespace ----
                runCatching {
                    val existing =
                        runCatching {
                            androidExt.javaClass.getMethod("getNamespace").invoke(androidExt) as? String
                        }.getOrNull()
                    if (existing.isNullOrBlank()) {
                        val manifestFile = proj.file("src/main/AndroidManifest.xml")
                        val fromManifest =
                            if (manifestFile.exists()) {
                                Regex("<manifest[^>]*package=\"([^\"]+)\"").find(manifestFile.readText())?.groupValues?.get(1)
                            } else {
                                null
                            }
                        val ns =
                            fromManifest?.takeIf { it.isNotBlank() }
                                ?: ("com.melodyflow.compat." + proj.name.replace(Regex("[^A-Za-z0-9_]"), "_"))
                        androidExt.javaClass.getMethod("setNamespace", String::class.java).invoke(androidExt, ns)
                        proj.logger.lifecycle("[namespace-fix] ${proj.path} -> $ns")
                    }
                }.onFailure { e ->
                    proj.logger.lifecycle("[namespace-fix] ${proj.path} skipped: ${e.message}")
                }
            }
        }
    }
}
// AGP 的 release lint 任务（lintVital*）在部分容器化构建环境中会因
// JDK cgroup 探测失败（CgroupInfo.getMountPoint() 空指针）而中断打包。
// 该检查不影响 APK 产物本身，这里统一跳过以保证 release 构建稳定。
subprojects {
    tasks.matching { it.name.startsWith("lintVital") }.configureEach {
        enabled = false
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}