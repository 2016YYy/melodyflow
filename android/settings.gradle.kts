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
    // version: '9.0.1'] was not found"。
    //
    // 更关键的是 AGP 8.9.x 与 Flutter 3.44.9 不匹配：Flutter 3.44.9 的
    // packages/flutter_tools/gradle/build.gradle.kts 里 compileOnly/testImplementation
    // 都写的是 com.android.tools.build:gradle:8.11.1，而 Flutter 3.44.9 声明的
    // flutter.ndkVersion 是 28.2.13676358 —— 只有 8.11.x 之后才成为 AGP 默认 NDK。
    // 用 8.9.1 时 AGP 的 NdkLocator 会把 27.0.12077973 当成"Preferred NDK version"，
    // 于是不论 SDK 里装了多少个 NDK，都会报
    //   NDK not configured. Download it with SDK manager. Preferred NDK version is '27.0.12077973'.
    // AGP 与 Kotlin(Flutter 先声明后 JDK 后 apply)的同侧配套版本如下：
    //   AGP 8.11.1  <-> Kotlin 2.2.20（与 flutter_tools 的 kotlin("jvm") version "2.2.20" 一致）
    // 因此统一升到 8.11.1 / 2.2.20，消除 AGP 自带的 27.0.12077973 默认值。
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}

include(":app")
