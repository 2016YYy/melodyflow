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

// gradle.properties 可覆盖 NDK 版本。
//
// 背景（CI 实测的完整因果链）：
//   · :app 的 ndkVersion 由 dev.flutter.flutter-gradle-plugin 在 apply 时写成
//     flutter.ndkVersion（Flutter 3.44.9 = 28.2.13676358）；
//   · AGP 的 NdkLocator 在【它自己的 afterEvaluate】阶段就解析定型 NDK
//     （CrashReporting$afterEvaluate$1 -> BasePlugin.createAndroidTasks ->
//      NdkLocatorKt.findNdkPathImpl）。root 侧任何事后覆盖都抢不到这个时点：
//      subprojects 直接赋值会被子工程脚本改回去、反射 setNdkVersion 与 AGP 同阶段、
//      gradle.lifecycle.beforeProject 在 settings 求值后直接抛异常；
//   · 所以【不覆盖】，而是让 SDK 里真的存在 Flutter 要求的那个版本（见 build.yml
//     的 Install Android NDK 步骤），这里只保留 flutter 的 defaults。
//
// 唯一还需要的干预是插件级替换：
//   · media_kit -> :jni（pub 包 jni 的 android/build.gradle）写的是
//     ndkVersion = flutter.ndkVersion，:app 用同一个值，冲突的旧版本只可能来自
//     plugins.withId("com.android.library") 引入的其它插件。对它们用
//     android.ndkVersion 兜底即可（AGP 在 library 插件里没有 CXX 任务，解析时点更晚）。
val ndkVersionOverride: String? = System.getenv("MELODYFLOW_NDK_VERSION")?.takeIf { it.isNotBlank() }

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
                        Regex("<manifest[^>]*package=\"([^\"]+)\"")
                            .find(manifestFile.readText())?.groupValues?.get(1)
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
    // 已评估就立即执行，否则挂到 afterEvaluate —— 避免
    // "Cannot run Project.afterEvaluate(Action) when the project is already evaluated."
    if (proj.state.executed) action() else proj.afterEvaluate { action() }
}

// ─────────────────────────────────────────────────────────────────────────────
// 老 pub 包的 namespace 修补（AGP 8.x 起 namespace 必填）
//
// 现象：升到 AGP 8.11.1 后，配置阶段直接失败：
//   A problem occurred configuring project ':on_audio_query_android'.
//   > Could not create an instance of type com.android.build.api.variant.impl.LibraryVariantBuilderImpl.
//      > Namespace not specified. Specify a namespace in the module's build file:
//        ~/.pub-cache/hosted/pub.dev/on_audio_query_android-1.1.0/android/build.gradle
//
// 根因：on_audio_query_android 1.1.0 是 2022 年的包，android/build.gradle 里只有
//   group 'com.lucasjosino.on_audio_query'
// 没有 android { namespace ... }，已在 pub.dev 上停止维护（对应 on_audio_query 2.9.0）。
// AGP 4.x~7.x 允许从 AndroidManifest 的 package 属性推导 namespace，8.x 起强制要求
// 构建脚本里显式声明。pub-cache 里的源码不能改（每次 pub get 都会被覆盖），
// 只能在 root 侧于【配置阶段之前】把 namespace 写进它的 android 扩展。
//
// 时间点非常关键：必须在 AGP 创建 VariantBuilder 之前生效。plugins.withId 回调
// 发生在插件 apply 的瞬间（早于 AGP 的 afterEvaluate），此时直接 setNamespace 最可靠；
// 若已经错过（项目已评估），退回到 afterEvaluate。
fun ensureNamespace(proj: Project, fixedNamespace: String?) {
    val apply = {
        runCatching {
            val ext = proj.extensions.findByName("android") ?: return@runCatching
            val existing = runCatching {
                ext.javaClass.getMethod("getNamespace").invoke(ext) as? String
            }.getOrNull()
            if (existing.isNullOrBlank()) {
                val ns = fixedNamespace?.takeIf { it.isNotBlank() }
                    ?: runCatching {
                        val f = proj.file("src/main/AndroidManifest.xml")
                        if (f.exists()) {
                            Regex("<manifest[^>]*package=\"([^\"]+)\"")
                                .find(f.readText())?.groupValues?.get(1)?.takeIf { it.isNotBlank() }
                        } else null
                    }.getOrNull()
                    ?: ("com.melodyflow.compat." + proj.name.replace(Regex("[^A-Za-z0-9_]"), "_"))
                ext.javaClass.getMethod("setNamespace", String::class.java).invoke(ext, ns)
                proj.logger.lifecycle("[namespace-fix] ${proj.path} -> $ns")
            } else {
                proj.logger.lifecycle("[namespace-fix] ${proj.path} already = $existing")
            }
        }.onFailure { e ->
            proj.logger.lifecycle("[namespace-fix] ${proj.path} skipped: ${e.message}")
        }
    }
    if (proj.state.executed) apply() else proj.afterEvaluate { apply() }
}

// 已知缺 namespace 的第三方包：显式写死，避免依赖 manifest 推导（AGP 8 不再推导）。
val legacyNamespaceFixes = mapOf(
    "on_audio_query_android" to "com.lucasjosino.on_audio_query",
)

subprojects {
    if (legacyNamespaceFixes.containsKey(name)) {
        // AGP 8.11.1 把 namespace 解析下移到了 VariantDslInfoImpl.getNamespace()（见配置失败堆栈
        // VariantDslInfoImpl.getNamespace(VariantDslInfoImpl.kt:92)），而 VariantBuilder 在
        // CrashReporting$afterEvaluate（AGP 自己注册的那个）里创建。因此在 afterEvaluate 阶段才
        // 反射设置 LibraryExtension.namespace 时已经太晚 —— 打印结果就是 ns=null。
        // 可靠做法是在插件 apply 回调里立刻写：plugins.withId("com.android.library") {} 的回调
        // 早于 AGP 注册的 afterEvaluate 执行，此时 LibraryExtension 已由 AGP 创建好。
        project.afterEvaluate {
            val ext = project.extensions.findByName("android")
            val ns = runCatching { ext?.javaClass?.getMethod("getNamespace")?.invoke(ext) }.getOrNull()
            println("[namespace-fix] ${project.path} ns=$ns")
            if (ns == null || (ns as? String).isNullOrBlank()) {
                runCatching {
                    ext?.javaClass?.getMethod("setNamespace", String::class.java)
                        ?.invoke(ext, legacyNamespaceFixes[name])
                    println("[namespace-fix] ${project.path} late-set -> ${legacyNamespaceFixes[name]}")
                }.onFailure { e -> println("[namespace-fix] ${project.path} late-set failed: ${e.message}") }
            }
        }
        plugins.withId("com.android.library") {
            ensureNamespace(project, legacyNamespaceFixes[name])
        }
        plugins.withId("com.android.application") {
            ensureNamespace(project, legacyNamespaceFixes[name])
        }
    }
}

// 用 plugins.withId 保证插件一被 apply 就能挂钩到 afterEvaluate。
// 注意：这里也不会真正改到 :app 的 ndkVersion —— AGP 解析 NDK 的时点更早，
// 覆盖无效，所以 :app 直接跟随 flutter.ndkVersion，环境侧保证该版本存在。
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
// 历史上 NDK 报错的文案是
//   "NDK not configured. Download it with SDK manager. Preferred NDK version is '27.0.12077973'."
// 那个 27.0.12077973 来自 AGP 8.9.x 自己的默认值，不是 Flutter 声明的版本，
// 追着它装 NDK 只会一直失败。真正的 Required 版本是 flutter.ndkVersion。
//
// 踩过的两个坑（都实测失败了，留档）：
//   · 在 subprojects{plugins.withId(...)} 的 afterEvaluate 里改 android.ndkVersion ——
//     补丁确实跑了，但 AGP 在同一个 afterEvaluate 阶段就创建 CXX 任务并解析 NDK，
//     顺序不可控，:jni 依旧报错。
//   · 改用 gradle.lifecycle.beforeProject{} —— root 脚本求值发生在 settings 之后，
//     直接抛 "GradleLifecycle#beforeProject cannot be called after settings have been
//     evaluated."（run 40854401300）。
// 所以真正的解法是环境侧：CI 的 Install Android NDK 步骤直接安装
// flutter.ndkVersion 对应的版本（28.2.13676358），保证 NdkLocator 一解析就能命中。
// 这里只负责把每个子工程最终生效的值打出来，方便 CI 排错。
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