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
// 但只挂 afterEvaluate 也不够 —— 若某子项目已被提前评估，再注册就会抛
// "Cannot run Project.afterEvaluate(Action) when the project is already evaluated."
// （实测 8a06cd3 就是这样整票失败的）。因此统一走下面的 applyAndroidPatch：
// 未评估就挂 afterEvaluate，已评估就立即执行。
// 在项目评估完成后统一打补丁（NDK 版本 + 缺失的 namespace）。
// 抽出成普通函数而不是 Project 扩展函数：plugins.withId 的 lambda 里 receiver 不确定，
// 写成 extension 会出现 "Unresolved reference. None of the following candidates is applicable
// because of receiver type mismatch"，进而连 logger / extensions / path 全部解析失败。
fun applyAndroidPatch(proj: Project) {
    val action = {
        val androidExt = proj.extensions.findByName("android")
        if (androidExt == null) {
            proj.logger.lifecycle("[android-patch] ${proj.path} 没有 android 扩展，跳过")
        } else {
            // ---- 1) 统一 NDK 版本（反射，避免 root classpath 缺 AGP 类型）----
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
                val existing = runCatching {
                    androidExt.javaClass.getMethod("getNamespace").invoke(androidExt) as? String
                }.getOrNull()
                if (existing.isNullOrBlank()) {
                    val manifestFile = proj.file("src/main/AndroidManifest.xml")
                    val fromManifest = if (manifestFile.exists()) {
                        Regex("<manifest[^>]*package=\"([^\"]+)\"").find(manifestFile.readText())?.groupValues?.get(1)
                    } else {
                        null
                    }
                    val ns = fromManifest?.takeIf { it.isNotBlank() }
                        ?: ("com.melodyflow.compat." + proj.name.replace(Regex("[^A-Za-z0-9_]"), "_"))
                    androidExt.javaClass.getMethod("setNamespace", String::class.java).invoke(androidExt, ns)
                    proj.logger.lifecycle("[namespace-fix] ${proj.path} -> $ns")
                }
            }.onFailure { e ->
                proj.logger.lifecycle("[namespace-fix] ${proj.path} skipped: ${e.message}")
            }
        }
    }
    // 已评估就立即执行，否则挂到 afterEvaluate —— 这样即使别处提前评估了子项目也不会抛
    // "Cannot run Project.afterEvaluate(Action) when the project is already evaluated."
    if (proj.state.executed) action() else proj.afterEvaluate { action() }
}

subprojects {
    plugins.withId("com.android.library") {
        applyAndroidPatch(project)
    }
    plugins.withId("com.android.application") {
        applyAndroidPatch(project)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// 兜底：把每个子工程真正生效的 ndkVersion 读回来写进日志
//
// 背景：:jni（media_kit 传递进来的内置 Gradle 子工程）会把自己的 ndkVersion 写死成
//   "NDK not configured. Download it with SDK manager. Preferred NDK version is '27.0.12077973'."
// 而 CI 选中 SDK 上真实可用的 30.0.16248370，AGP 在配置 :jni 阶段就抛错，跟 :app 无关。
//
// 踩过的两个坑（都实测失败了，留档）：
//   · 在 subprojects{plugins.withId(...)} 的 afterEvaluate 里改 android.ndkVersion ——
//     补丁确实跑了，但 AGP 在同一个 afterEvaluate 阶段就创建 CXX 任务并解析 NDK，
//     顺序不可控，:jni 依旧报错。
//   · 改用 gradle.lifecycle.beforeProject{} —— root 脚本求值发生在 settings 之后，
//     直接抛 "GradleLifecycle#beforeProject cannot be called after settings have been
//     evaluated."（run 40854401300）。
// 所以真正的解法只能是改源头：CI 里把 MELODYFLOW_NDK_VERSION 选成 :jni 要求的版本
// （由 android/settings.gradle.kts 从 Gradle 属性 melodyflow.jniNdkVersion 读出），
// 并让 build.yml 把 sdkmanager 安装好的那些版本统一软链到该版本号。这里只负责把
// 每个子工程最终生效的值打出来，方便 CI 排错。
// ─────────────────────────────────────────────────────────────────────────────
subprojects {
    afterEvaluate {
        runCatching {
            val ext = extensions.findByName("android") ?: return@afterEvaluate
            val v = ext.javaClass.getMethod("getNdkVersion").invoke(ext) as? String
            logger.lifecycle("[ndk-effective] ${path} -> $v")
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