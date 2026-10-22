pluginManagement {
    val flutterSdkPath =
        run {
            // 必须使用全限定名 java.util.Properties()：Gradle Kotlin DSL 会把 settings 脚本
            // 分阶段编译，pluginManagement {} 属于第一阶段，该阶段不应用文件顶部的 import 语句，
            // 因此这里写 Properties() 会报 "Unresolved reference: Properties"。
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    // AGP 9.0.1 内部依赖 kotlin-gradle-plugin 2.2.10，与此处声明的 KGP 2.3.20
    // 存在版本倒挂，在 CI 上表现为 "Plugin [id: 'com.android.application',
    // version: '9.0.1'] was not found"。回退到经 CI 验证可解析的稳定组合。
    id("com.android.application") version "8.9.1" apply false
    id("org.jetbrains.kotlin.android") version "2.1.20" apply false
}

include(":app")
