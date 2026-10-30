#!/usr/bin/env python3
"""为历史 tag 补齐不影响业务逻辑的构建环境补丁。

背景
----
melodyflow 的 v1.7.0 / v1.7.1 在打包时只有 tag、没有 Release，因为当时 CI 失败。
失败点全部是构建环境对新工具链的适配，与业务代码无关：

  0) AGP / KGP 版本 -- v1.6.0 与 v1.7.0 的 settings.gradle.kts 写了
     com.android.application 9.1.0 / 9.0.1 与 org.jetbrains.kotlin.android
     2.4.0 / 2.3.20。Google Maven 里不存在这些 AGP 版本，解析阶段直接失败：
       Plugin [id: 'com.android.application', version: '9.0.1', apply: false]
       was not found in any of the following sources
     这是当年 v1.6.0 / v1.7.0 根本没产出 Release 的根因。
  1) NDK 版本 -- app/build.gradle.kts 写 ndkVersion = flutter.ndkVersion，
     Flutter 3.44.9 给出 28.2.13676358，而 runner 只预装 27.x。
     CI 侧的安装步骤已处理，无需改文件。
  2) namespace -- 老插件（on_audio_query_android 等）的 AndroidManifest
     没有 package 属性（或 AGP 8 不再回退读它），AGP 8 要求显式 namespace。
  3) JVM target -- 老插件没有 compileOptions/kotlinOptions，
     JavaCompile 默认 1.8、KotlinCompile 跟随 JDK 17，KGP 一致性校验中断构建。
  7) compileSdk -- on_audio_query_android 写死 compileSdkVersion 33，
     runner 上没有 android-33 平台，报
       Failed to find target with hash string 'android-33'
     在 root 侧把它的 compileSdk 抬到 36（pub-cache 只读，不能改插件源码）。
  6) Properties 短名 -- app/build.gradle.kts 里写 java.util.Properties() 时，
     kts 把 java 解析成 Gradle 的 java 扩展而非包名，报 Unresolved reference: util，
     连带 load() / isNotBlank() 一起失效。改成顶部 import + Properties()。
  5) Gradle 版本 -- v1.7.0 的 wrapper 指向 gradle-9.8.1，而 Gradle 9.6.0 起
     移除了 AGP 8.x 依赖的 org.gradle.api.problems.internal.InternalProblems，
     报 "relies on ... a Gradle internal API that was removed in Gradle 9.6.0"。
     统一到 8.14.3（main / v1.7.1 用的就是它）。
  4) 本机代理 -- v1.7.0 / v1.7.1 的 android/gradle.properties 把
     -Dhttps.proxyHost=127.0.0.1 -Dhttps.proxyPort=18080 写死在
     org.gradle.jvmargs 里。runner 上没有这个代理，所有仓库请求连不上，
     Gradle 把「网络不可达」报成「插件版本不存在」，极难辨认。

本脚本做 0)、2)、3)、4)、5)、6) 和 7)，且是幂等的：检测到已经修过就跳过，绝不覆盖既有内容。
3) 采用与主线 commit aed5b77 完全相同的落点（root 侧把 JavaCompile 拉到 17 +
gradle.properties 里把一致性校验降级为 warning），保证新旧版本产物行为一致。

用法
----
    python3 scripts/patch_legacy_tag.py            # 就地修补 android/
    python3 scripts/patch_legacy_tag.py --check    # 只报告，不写文件
    python3 <tmp>/patch_legacy_tag.py --root .     # 脚本不在项目内时指定根目录
"""

import argparse
import pathlib
import re
import sys

# 默认以脚本自身位置推断项目根（脚本位于 <root>/scripts/ 下）。
# CI 里脚本可能被单独取到临时目录执行，那种情况用 --root 显式指定，见 main()。
ROOT = pathlib.Path(__file__).resolve().parent.parent
ANDROID = ROOT / "android"
BUILD_KTS = ANDROID / "build.gradle.kts"
APP_BUILD_KTS = ANDROID / "app" / "build.gradle.kts"
GRADLE_PROPS = ANDROID / "gradle.properties"


def set_root(root):
    """把全局路径重定向到指定项目根目录。"""
    global ROOT, ANDROID, BUILD_KTS, APP_BUILD_KTS, GRADLE_PROPS, SETTINGS_KTS, WRAPPER_PROPS
    ROOT = pathlib.Path(root).resolve()
    ANDROID = ROOT / "android"
    BUILD_KTS = ANDROID / "build.gradle.kts"
    APP_BUILD_KTS = ANDROID / "app" / "build.gradle.kts"
    GRADLE_PROPS = ANDROID / "gradle.properties"
    SETTINGS_KTS = ANDROID / "settings.gradle.kts"
    WRAPPER_PROPS = ANDROID / "gradle" / "wrapper" / "gradle-wrapper.properties"
WRAPPER_PROPS = ANDROID / "gradle" / "wrapper" / "gradle-wrapper.properties"
SETTINGS_KTS = ANDROID / "settings.gradle.kts"

MARKER_NAMESPACE = "[patch_legacy_tag] 老插件 namespace"
MARKER_JVM = "[patch_legacy_tag] 老插件 JVM target"
MARKER_PROP = "kotlin.jvm.target.validation.mode=warning"
MARKER_SDK = "[patch_legacy_tag] 老插件 compileSdk"

NAMESPACE_BLOCK = """
// ─────────────────────────────────────────────────────────────────────────────
// [patch_legacy_tag] 老插件 namespace 兜底
//
// AGP 8 起，每个 library 子工程都必须声明 namespace，否则在 configuration 阶段直接报：
//   Namespace not specified. Specify a namespace in the module build file.
// on_audio_query_android 1.1.0（2022 年停更）只在 AndroidManifest.xml 里写了
// package=com.lucasjosino.on_audio_query，AGP 8 不再回退读它。
//
// 这里按「子工程名 -> 已知 namespace」补一层兜底，只对清单里显式列出的老包生效，
// 新包自带 namespace 时完全不受影响。
val legacyNamespaces = mapOf(
    "on_audio_query_android" to "com.lucasjosino.on_audio_query",
)

subprojects {
    plugins.withId("com.android.library") {
        val androidExt = extensions.findByName("android") ?: return@withId
        val current = runCatching {
            androidExt.javaClass.getMethod("getNamespace").invoke(androidExt) as String?
        }.getOrNull()
        if (current.isNullOrBlank()) {
            val fixed = legacyNamespaces[name]
            if (fixed != null) {
                runCatching {
                    androidExt.javaClass.getMethod("setNamespace", String::class.java)
                        .invoke(androidExt, fixed)
                    logger.lifecycle("[patch_legacy_tag] " + path + " namespace -> " + fixed)
                }
            }
        }
    }
}
"""

JVM_BLOCK = """
// ─────────────────────────────────────────────────────────────────────────────
// [patch_legacy_tag] 老插件 JVM target 对齐
//
// 现象（:on_audio_query_android:compileReleaseKotlin）：
//   Inconsistent JVM-target compatibility detected for tasks
//     compileReleaseJavaWithJavac (1.8) and compileReleaseKotlin (17).
//
// 根因：root 用 JDK 17 跑 Gradle，KotlinCompile 的 jvmTarget 默认取当前 JVM = 17，
// 而该包 AGP 侧 JavaCompile 的 source/target 被压到 1.8。它的 build.gradle 只写了
// apply plugin: kotlin-android，没有任何 compileOptions/kotlinOptions。
//
// 尝试过但无效的做法（留档，别再走一遍）：
//   a) 反射 getCompilerOptions().setJvmTarget(...) -- 在 allprojects{} 里此时
//      KotlinCompile 还没创建，且 KGP 2.2.20 的 compilerOptions 反射路径拿不到 JvmTarget；
//   b) 任务级 doFirst 改 -- 一致性校验发生在任务执行前的 eager 阶段，太晚。
//
// 可靠落点：gradle.properties 里把这条校验降级为 warning（见同目录 gradle.properties），
// 再把 JavaCompile 拉到 17，让两边真的保持一致，而不是只关掉检查。
val legacyJvmTargetFixes = setOf(
    "on_audio_query_android",
)

allprojects {
    if (legacyJvmTargetFixes.contains(name)) {
        tasks.withType(org.gradle.api.tasks.compile.JavaCompile::class.java).configureEach {
            sourceCompatibility = "17"
            targetCompatibility = "17"
        }
    }
}
"""

PROP_BLOCK = """

# on_audio_query_android 1.1.0（2022 年停更的包）没有声明 compileOptions / kotlinOptions，
# KotlinCompile 默认跟随 JDK 17，JavaCompile 却停在 1.8，KGP 的一致性校验会中断构建：
#   Inconsistent JVM-target compatibility detected for tasks
#     compileReleaseJavaWithJavac (1.8) and compileReleaseKotlin (17).
# root build.gradle.kts 已经把该子项目的 JavaCompile 拉到 17，这条降级只作为兜底，
# 防止将来再冒出的同类老包直接打断 CI。
kotlin.jvm.target.validation.mode=warning
"""


COMPILE_SDK_BLOCK = r"""

// ─────────────────────────────────────────────────────────────────────────────
// [patch_legacy_tag] 老插件 compileSdk 兜底
//
// on_audio_query_android 1.1.0 的 android/build.gradle 写死
//   android { compileSdkVersion 33 }
// GitHub runner 上只装了 Flutter 3.44.9 需要的 SDK 平台（36 等），没有 33，于是报：
//   Could not determine the dependencies of task
//   ':on_audio_query_android:compileReleaseJavaWithJavac'.
//   > Failed to find target with hash string 'android-33' in: $ANDROID_HOME
// pub-cache 是只读缓存，每次 pub get 都会重建，不能改插件源码；
// 只能在 root 侧于 VariantBuilder 创建之前，把它的 android.compileSdkVersion 抬到 36。
val legacyCompileSdkFixes = mapOf(
    "on_audio_query_android" to 36,
)

subprojects {
    if (legacyCompileSdkFixes.containsKey(name)) {
        val targetSdk = legacyCompileSdkFixes.getValue(name)
        val bump = {
            runCatching {
                val ext = project.extensions.findByName("android") ?: return@runCatching
                // AGP 8.x 的 CommonExtension 有 setCompileSdk(Int)，老属性是 compileSdkVersion(Int)
                val setter = runCatching {
                    ext.javaClass.getMethod("setCompileSdk", Int::class.javaPrimitiveType)
                }.getOrNull() ?: runCatching {
                    ext.javaClass.getMethod("setCompileSdkVersion", Int::class.javaPrimitiveType)
                }.getOrNull()
                if (setter == null) {
                    project.logger.lifecycle("[compileSdk-fix] ${project.path} 找不到 setCompileSdk，跳过")
                } else {
                    setter.invoke(ext, targetSdk)
                    project.logger.lifecycle("[compileSdk-fix] ${project.path} -> $targetSdk")
                }
            }.onFailure { e ->
                project.logger.lifecycle("[compileSdk-fix] ${project.path} skipped: ${e.message}")
            }
        }
        plugins.withId("com.android.library") { bump() }
        plugins.withId("com.android.application") { bump() }
    }
}
"""


def report(msg):
    print(msg, flush=True)


# 与 main 上已验证可用的组合对齐（见 android/settings.gradle.kts 的注释）。
# 选 8.11.1 / 2.2.20 而不是更新的版本，是因为 Flutter 3.44.9 自带的
# flutter_tools/gradle 就是按这一对编译的，换别的反而可能对不上。
TARGET_AGP = "8.11.1"
TARGET_KGP = "2.2.20"

# 只替换这几行里的版本号，其余内容（仓库配置、注释、flutter-plugin-loader）原样保留。
_RE_AGP = re.compile(r'(id\("com\.android\.application"\)\s+version\s+")[^"]+(")')
_RE_KGP = re.compile(r'(id\("org\.jetbrains\.kotlin\.android"\)\s+version\s+")[^"]+(")')


def patch_settings_kts(dry_run):
    """把不存在的 AGP / KGP 版本改回 main 上已验证可用的组合。

    v1.6.0 的 settings.gradle.kts 写 com.android.application 9.1.0 + kotlin 2.4.0，
    v1.7.0 写 9.0.1 + 2.3.20。Google Maven 里没有这些 AGP 版本，
    Gradle 在 settings 阶段就报 Plugin [...] was not found，一个字节都编译不出来。
    这是这两个版本当年没有 Release 的真正原因。
    """
    if not SETTINGS_KTS.exists():
        report("!! 找不到 android/settings.gradle.kts，跳过")
        return False

    src = SETTINGS_KTS.read_text(encoding="utf-8")
    new_src = _RE_AGP.sub(lambda m: m.group(1) + TARGET_AGP + m.group(2), src)
    new_src = _RE_KGP.sub(lambda m: m.group(1) + TARGET_KGP + m.group(2), new_src)

    if new_src == src:
        report("   AGP / KGP 版本已是 %s / %s，跳过" % (TARGET_AGP, TARGET_KGP))
        return False

    for label, pattern in (("AGP", _RE_AGP), ("KGP", _RE_KGP)):
        old = pattern.search(src)
        new = pattern.search(new_src)
        if old and new and old.group(1) + old.group(2) != new.group(1) + new.group(2):
            report("   + %s %s -> %s" % (
                label,
                src[old.start():old.end()].split('"')[1],
                new_src[new.start():new.end()].split('"')[1],
            ))

    if dry_run:
        report("   [dry-run] 将改写 android/settings.gradle.kts")
        return True

    SETTINGS_KTS.write_text(new_src, encoding="utf-8")
    report("   android/settings.gradle.kts 已更新")
    return True


# 老版本 gradle.properties 的 org.gradle.jvmargs 里硬编码了本机代理，
# 例如 v1.7.0 / v1.7.1：
#   org.gradle.jvmargs=-Xmx1536m -Dhttp.proxyHost=127.0.0.1 -Dhttp.proxyPort=18080 ...
# 在 GitHub runner 上 127.0.0.1:18080 没有代理进程，所有仓库请求都连不上，
# 最终表现为
#   Plugin [id: 'com.android.application', version: '8.11.1', apply: false]
#   was not found in any of the following sources
# —— 看起来像「版本不存在」，实际是「网络被代理指到黑洞」。
# 这里把代理相关的 -D 参数整段剥掉，其余 jvmargs 保留。
# 只处理 org.gradle.jvmargs 那一行，且只剥行内参数；不能碰注释里的示例。
_RE_JVMARGS_LINE = re.compile(r"^(\s*org\.gradle\.jvmargs\s*=.*)$", re.MULTILINE)
_RE_PROXY_ARG = re.compile(
    r"\s+-D(?:https?|socks)\.proxy(?:Host|Port|User|Password)=\S+",
    re.IGNORECASE,
)


def patch_gradle_proxy(dry_run):
    """剥掉 gradle.properties 里指向本机的高危代理参数。"""
    if not GRADLE_PROPS.exists():
        report("!! 找不到 android/gradle.properties，跳过")
        return False

    src = GRADLE_PROPS.read_text(encoding="utf-8")

    total = 0

    def _clean(match):
        nonlocal total
        line = match.group(1)
        cleaned, n = _RE_PROXY_ARG.subn("", line)
        total += n
        return cleaned

    new_src = _RE_JVMARGS_LINE.sub(_clean, src)
    if total == 0 or new_src == src:
        report("   gradle.properties 的 jvmargs 无代理参数，跳过")
        return False

    report("   + 移除 %d 处 jvmargs 代理参数（runner 上 127.0.0.1 无代理，会导致仓库全部解析失败）" % total)

    if dry_run:
        return True

    GRADLE_PROPS.write_text(new_src, encoding="utf-8")
    report("   android/gradle.properties 已清理代理参数")
    return True


# Gradle 9.6.0 移除了 org.gradle.api.problems.internal.InternalProblems，
# AGP 8.x 依赖它，因此在 Gradle 9.6+ 上直接报：
#   Plugin 'com.android.internal.application' relies on
#   'org.gradle.api.problems.internal.InternalProblems', a Gradle internal API
#   that was removed in Gradle 9.6.0. Update the plugin ... or use Gradle 9.5.
# v1.7.0 的 wrapper 指向 gradle-9.8.1-all.zip，正好踩中。
# 统一到 main 上已验证可用的 8.14.3（v1.7.1 也是这个版本，能跑通）。
TARGET_GRADLE = "8.14.3"
TARGET_GRADLE_URL = (
    "https\\://services.gradle.org/distributions/gradle-" + TARGET_GRADLE + "-all.zip"
)

_RE_DIST_URL = re.compile(r"^\s*distributionUrl\s*=.*$", re.MULTILINE)


def patch_gradle_wrapper(dry_run):
    """把 Gradle wrapper 版本对齐到与 AGP 8.x 兼容的 8.14.3。"""
    if not WRAPPER_PROPS.exists():
        report("!! 找不到 android/gradle/wrapper/gradle-wrapper.properties，跳过")
        return False

    src = WRAPPER_PROPS.read_text(encoding="utf-8")
    m = _RE_DIST_URL.search(src)
    if not m:
        report("!! wrapper 里没有 distributionUrl，跳过")
        return False

    current = m.group(0)
    if "gradle-" + TARGET_GRADLE + "-all.zip" in current:
        report("   Gradle wrapper 已是 %s，跳过" % TARGET_GRADLE)
        return False

    new_line = "distributionUrl=" + TARGET_GRADLE_URL
    new_src = _RE_DIST_URL.sub(new_line, src, count=1)
    ver = current.split("gradle-")[-1].split("-all")[0] if "gradle-" in current else "?"
    report("   + Gradle wrapper %s -> %s" % (ver, TARGET_GRADLE))

    if dry_run:
        return True

    WRAPPER_PROPS.write_text(new_src, encoding="utf-8")
    report("   android/gradle/wrapper/gradle-wrapper.properties 已更新")
    return True


# 老版本 android/app/build.gradle.kts 里写的是 java.util.Properties()。
# 在 .gradle.kts 脚本里，`java` 会被解析成 Gradle 的 java 扩展
# （JavaPluginExtension）而不是包名，于是报：
#   Line 26: val localProps = java.util.Properties().apply {
#                                     ^ Unresolved reference: util
#   Line 28:     if (f.exists()) f.inputStream().use { load(it) }
#                                        ^ Unresolved reference: load
#   Line 32:     ?: localProps.getProperty(propKey)?.takeIf { it.isNotBlank() }
#                                                                 ^ Unresolved reference: it
# 修法（与 main 上已验证的写法一致）：脚本顶部 import java.util.Properties，
# 并把 java.util.Properties() 改成 Properties()。
# 只匹配真实代码，不匹配以 // 开头的注释（main / v1.7.1 的注释里就有这个写法，
# 早期版本全局替换会把注释一起改掉，导致"已经修过还报需要修"）。
_RE_JAVA_UTIL_PROPERTIES = re.compile(r"^(?!\s*//).*?java\.util\.Properties\(\)", re.MULTILINE)
_RE_IMPORT_PROPERTIES = re.compile(r"^\s*import\s+java\.util\.Properties\s*$", re.MULTILINE)


def patch_app_build_kts(dry_run):
    """修 app/build.gradle.kts 里 java.util.Properties() 的 Unresolved reference。"""
    if not APP_BUILD_KTS.exists():
        report("!! 找不到 android/app/build.gradle.kts，跳过")
        return False

    src = APP_BUILD_KTS.read_text(encoding="utf-8")

    if not _RE_JAVA_UTIL_PROPERTIES.search(src):
        report("   app/build.gradle.kts 无 java.util.Properties()，跳过")
        return False

    new_src, n = re.subn(
        r"(^(?!\s*//)[^\n]*?)java\.util\.Properties\(\)",
        lambda m: m.group(1) + "Properties()",
        src,
        flags=re.MULTILINE,
    )

    # 需要 import 才能用短名；已有则不再重复加。
    if not _RE_IMPORT_PROPERTIES.search(new_src):
        new_src = "import java.util.Properties\n\n" + new_src
        report("   + 顶部补 import java.util.Properties")
    report("   + java.util.Properties() -> Properties()")

    if dry_run:
        return True

    APP_BUILD_KTS.write_text(new_src, encoding="utf-8")
    report("   android/app/build.gradle.kts 已更新")
    return True


def patch_build_kts(dry_run):
    if not BUILD_KTS.exists():
        report("!! 找不到 android/build.gradle.kts，跳过")
        return False

    src = BUILD_KTS.read_text(encoding="utf-8")
    changed = False
    pieces = []

    # 幂等判断不能只看本脚本的标记：主线 commit aed5b77 已经用「不带标记」的写法
    # 解决了 JVM target 问题，此时再注入一份会重复注册 allprojects 块。
    # 所以标记 + 实际逻辑双重判断，任一命中即视为已修复。
    has_namespace_fix = MARKER_NAMESPACE in src or (
        "setNamespace" in src
        and (
            "legacyNamespaceFixes" in src   # 主线 aed5b77 的写法
            or "legacyNamespaces" in src     # 本脚本的写法
            or "ensureNamespace" in src      # 更早主线版本的写法
        )
    )
    has_jvm_fix = MARKER_JVM in src or (
        "legacyJvmTargetFixes" in src and "JavaCompile" in src
    )
    has_sdk_fix = MARKER_SDK in src or "legacyCompileSdkFixes" in src

    if has_namespace_fix:
        report("   namespace 兜底已存在，跳过")
    else:
        pieces.append(NAMESPACE_BLOCK)
        changed = True
        report("   + 注入 namespace 兜底")

    if has_jvm_fix:
        report("   JVM target 对齐已存在，跳过")
    else:
        pieces.append(JVM_BLOCK)
        changed = True
        report("   + 注入 JVM target 对齐")

    if has_sdk_fix:
        report("   compileSdk 兜底已存在，跳过")
    else:
        pieces.append(COMPILE_SDK_BLOCK)
        changed = True
        report("   + 注入 compileSdk 兜底（老插件写死 33，runner 上没有该平台）")

    if not changed:
        return False

    new_src = src.rstrip("\n") + "\n" + "".join(pieces)
    if dry_run:
        report("   [dry-run] 将追加 %d 字符到 android/build.gradle.kts" % len("".join(pieces)))
        return True

    BUILD_KTS.write_text(new_src, encoding="utf-8")
    report("   android/build.gradle.kts 已更新")
    return True


def patch_gradle_props(dry_run):
    if not GRADLE_PROPS.exists():
        report("!! 找不到 android/gradle.properties，跳过")
        return False

    src = GRADLE_PROPS.read_text(encoding="utf-8")
    if MARKER_PROP in src:
        report("   gradle.properties 已含 validation.mode=warning，跳过")
        return False

    new_src = src.rstrip("\n") + "\n" + PROP_BLOCK
    if dry_run:
        report("   [dry-run] 将追加 kotlin.jvm.target.validation.mode 到 android/gradle.properties")
        return True

    GRADLE_PROPS.write_text(new_src, encoding="utf-8")
    report("   android/gradle.properties 已更新")
    return True


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true", help="只检查不写文件")
    ap.add_argument(
        "--root",
        default=None,
        help="Flutter 项目根目录（含 android/）。默认按脚本所在位置推断；"
        "CI 中脚本被单独取到临时目录执行时必须显式传入。",
    )
    args = ap.parse_args()

    if args.root:
        set_root(args.root)

    report("== patch_legacy_tag: 目标目录 %s" % ANDROID)
    if not ANDROID.is_dir():
        report("!! android/ 不存在，说明不是 Flutter 项目根目录")
        return 1

    changed = False
    changed |= patch_settings_kts(args.check)
    changed |= patch_gradle_wrapper(args.check)
    changed |= patch_gradle_proxy(args.check)
    changed |= patch_build_kts(args.check)
    changed |= patch_app_build_kts(args.check)
    changed |= patch_gradle_props(args.check)

    if args.check:
        report("== check 完成，changed=%s" % changed)
        return 0

    if changed:
        report("== 补丁已应用")
    else:
        report("== 无需改动（已是修补后的状态）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
