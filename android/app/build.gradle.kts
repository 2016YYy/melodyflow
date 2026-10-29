import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.melodyflow.melodyflow"
    compileSdk = 36
    // NDK 版本统一交给 root android/build.gradle.kts 的 applyAndroidPatch 处理：
    // 那里在子项目 afterEvaluate（AGP 自己的 afterEvaluate 之前）用反射给每个 Android
    // 子项目（:app、:jni、各插件）写入同一个 MELODYFLOW_NDK_VERSION。
    // 这里【不要再设 ndkVersion】—— 实测在 :app 里写 ndkVersion 会在 AGP 配置 :app 的
    // afterEvaluate 阶段就把 NDK 解析定型，此时若所选版本在 SDK 里没有注册目录，
    // 会直接抛 "NDK not configured. Preferred NDK version is '27.0.12077973'"
    // （NdkLocatorKt.findNdkPathImpl -> NdkHandler.getNdkStatus），
    // 也就是 flutter.ndkVersion 的默认值抢先生效，root 的统一覆盖来不及介入。

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // 统一签名配置 - 后续所有版本使用同一签名，确保更新可用
    // 安全要求：仓库内不保存任何签名口令。口令来源优先级：
    //   1) 环境变量（CI Secrets：KEYSTORE_PASSWORD / KEY_PASSWORD / KEY_ALIAS）
    //   2) android/local.properties（本地开发，已被 .gitignore 忽略）
    signingConfigs {
        create("release") {
            val keystorePath = System.getenv("KEYSTORE_PATH") ?: "melodyflow-release.jks"
            val keystoreFile = file(keystorePath)

            // 注意：此处用 Properties() 而非 java.util.Properties()。
            // 在 .gradle.kts 脚本中，`java` 会被解析为 Gradle 的 java 扩展
            // （JavaPluginExtension）而非 java 包名，导致
            // "Unresolved reference: util"，并连带使 load()/isNotBlank() 无法解析。
            // 顶部已通过 import java.util.Properties 显式引入。
            val localProps = Properties().apply {
                val f = rootProject.file("local.properties")
                if (f.exists()) f.inputStream().use { load(it) }
            }
            fun secret(envKey: String, propKey: String): String? =
                System.getenv(envKey)?.takeIf { it.isNotBlank() }
                    ?: localProps.getProperty(propKey)?.takeIf { it.isNotBlank() }

            if (keystoreFile.exists()) {
                val storePwd = secret("KEYSTORE_PASSWORD", "keystore.storePassword")
                val keyPwd = secret("KEY_PASSWORD", "keystore.keyPassword")
                if (storePwd != null && keyPwd != null) {
                    storeFile = keystoreFile
                    storePassword = storePwd
                    keyAlias = secret("KEY_ALIAS", "keystore.keyAlias") ?: "melodyflow"
                    keyPassword = keyPwd
                } else {
                    logger.warn(
                        "未配置签名口令：请设置环境变量 KEYSTORE_PASSWORD / KEY_PASSWORD，" +
                            "或在 android/local.properties 中配置 keystore.storePassword / keystore.keyPassword。" +
                            "本次 release 将使用 debug 签名（可安装，但无法覆盖升级已发布版本）。"
                    )
                }
            }
        }
    }

    defaultConfig {
        applicationId = "com.melodyflow.melodyflow"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            isShrinkResources = false
            signingConfig = signingConfigs.getByName("release")
        }
        debug {
            isMinifyEnabled = false
        }
    }

    lint {
        checkReleaseBuilds = false
        abortOnError = false
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
