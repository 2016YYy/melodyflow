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
subprojects {
    project.evaluationDependsOn(":app")
}

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
subprojects {
    afterEvaluate {
        ndkVersionOverride?.let { v ->
            extensions.findByName("android")?.let { ext ->
                runCatching {
                    ext.javaClass.getMethod("setNdkVersion", String::class.java).invoke(ext, v)
                }.onSuccess {
                    logger.lifecycle("[ndk-override] ${project.path} -> $v")
                }.onFailure { e ->
                    logger.lifecycle("[ndk-override] ${project.path} failed: ${e.message}")
                }
            }
        }
    }
}

// 为缺失 namespace 的老插件自动补全。
//
// AGP 8.x 起 namespace 成为必填项，而一些长期未更新的插件（例如 on_audio_query_android
// 1.1.0，pub.dev 上已是最后一版）仍然只在 AndroidManifest.xml 里写 package 属性，
// 直接导致："Namespace not specified. Specify a namespace in the module's build file"。
// 这里在子项目评估完成、AGP 校验之前，用反射把 namespace 补上：
//   1. 优先取模块源码 AndroidManifest.xml 里的 package 值（与原插件行为一致）
//   2. 取不到时退回 com.melodyflow.compat.<模块名>
subprojects {
    afterEvaluate {
        runCatching {
            val ext = extensions.findByName("android") ?: return@afterEvaluate
            val existing = runCatching {
                ext.javaClass.getMethod("getNamespace").invoke(ext) as? String
            }.getOrNull()
            if (!existing.isNullOrBlank()) return@afterEvaluate
            val manifestFile = file("src/main/AndroidManifest.xml")
            val fromManifest = if (manifestFile.exists()) {
                Regex("<manifest[^>]*package=\"([^\"]+)\"").find(manifestFile.readText())?.groupValues?.get(1)
            } else null
            val ns = fromManifest?.takeIf { it.isNotBlank() }
                ?: "com.melodyflow.compat." + project.name.replace(Regex("[^A-Za-z0-9_]"), "_")
            ext.javaClass.getMethod("setNamespace", String::class.java).invoke(ext, ns)
            logger.lifecycle("[namespace-fix] ${project.path} -> $ns")
        }.onFailure { e ->
            logger.lifecycle("[namespace-fix] ${project.path} skipped: ${e.message}")
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
