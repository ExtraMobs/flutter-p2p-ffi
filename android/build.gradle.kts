import java.util.Properties

group = "dev.extramobs.ipfs_ffi"
version = "0.19.0"

buildscript {
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:9.1.0")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

plugins {
    id("com.android.library")
}

val pluginRoot: File = projectDir.parentFile
val nativeAndroidDir = File(pluginRoot, "native/android")
val isWindowsHost = System.getProperty("os.name").lowercase().contains("win")

fun findDartExecutable(): String {
    val localPropsFile = File(rootProject.projectDir, "local.properties")
    if (localPropsFile.exists()) {
        val props = Properties()
        localPropsFile.inputStream().use { props.load(it) }
        val flutterSdk = props.getProperty("flutter.sdk")
        if (flutterSdk != null) {
            val dartName = if (isWindowsHost) "dart.exe" else "dart"
            val dartBin = File(flutterSdk, "bin/cache/dart-sdk/bin/$dartName")
            if (dartBin.exists()) return dartBin.absolutePath
        }
    }
    return if (isWindowsHost) "dart.exe" else "dart"
}

val targetPlatformProp = (project.findProperty("target-platform") as String?)
    ?.split(",")
    ?.map { it.trim() }
    ?.filter { it.isNotEmpty() }

val wantX64 = targetPlatformProp == null || "android-x64" in targetPlatformProp
val wantArm64 = targetPlatformProp == null || "android-arm64" in targetPlatformProp

val buildTargets = when {
    wantX64 && wantArm64 -> listOf("android")
    wantX64 -> listOf("android-x64")
    wantArm64 -> listOf("android-arm64")
    else -> listOf("android")
}

val buildIpfsFfiAndroid = tasks.register("buildIpfsFfiAndroid") {
    val goFiles = fileTree(File(pluginRoot, "go")) { include("*.go") }
    inputs.files(
        File(pluginRoot, "tool/build.dart"),
        File(pluginRoot, "shm/ipfs_shm.c"),
        File(pluginRoot, "shm/ipfs_shm.h"),
        goFiles,
    )
    val expectedOutputs = mutableListOf<File>()
    if (wantX64) {
        expectedOutputs.add(File(nativeAndroidDir, "x86_64/libipfs_host.so"))
        expectedOutputs.add(File(nativeAndroidDir, "x86_64/libipfs_shm.so"))
    }
    if (wantArm64) {
        expectedOutputs.add(File(nativeAndroidDir, "arm64-v8a/libipfs_host.so"))
        expectedOutputs.add(File(nativeAndroidDir, "arm64-v8a/libipfs_shm.so"))
    }
    outputs.files(expectedOutputs)

    doLast {
        val pkgConfig = File(pluginRoot, ".dart_tool/package_config.json")
        if (!pkgConfig.exists()) {
            pkgConfig.parentFile.mkdirs()
            pkgConfig.writeText("{\"configVersion\":2,\"packages\":[]}\n")
        }
        val dartExe = findDartExecutable()
        val cmd = listOf(dartExe, File(pluginRoot, "tool/build.dart").absolutePath, "--no-gen") + buildTargets
        val pb = ProcessBuilder(cmd)
            .directory(pluginRoot)
            .inheritIO()
        val exitCode = pb.start().waitFor()
        if (exitCode != 0) {
            throw GradleException("ipfs_ffi native Android build failed with exit code $exitCode")
        }
    }
}

tasks.named("preBuild") {
    dependsOn(buildIpfsFfiAndroid)
}

android {
    namespace = "dev.extramobs.ipfs_ffi"
    compileSdk = 36

    defaultConfig {
        minSdk = 24
    }

    sourceSets["main"].jniLibs.srcDirs(nativeAndroidDir)

    val abiOf = mapOf("android-arm64" to "arm64-v8a", "android-x64" to "x86_64")
    if (targetPlatformProp != null) {
        for ((platform, abi) in abiOf) {
            if (platform !in targetPlatformProp) {
                packaging.jniLibs.excludes += "**/$abi/**"
            }
        }
    }
}

// Ensure the host application extracts libipfs_host.so to nativeLibraryDir on
// installation (Android only executes binaries from nativeLibraryDir, not from
// inside the APK). Because Flutter's root build.gradle.kts evaluates :app
// before plugin subprojects, we configure the manifest and asset-compression
// tasks directly via configureEach.
rootProject.subprojects {
    @Suppress("UNCHECKED_CAST")
    tasks.configureEach {
        for (methodName in listOf("getJniLibsUseLegacyPackaging", "getCompressNativeLibs", "getExtractNativeLibs")) {
            val m = javaClass.methods.firstOrNull { it.name == methodName && it.parameterCount == 0 } ?: continue
            val prop = m.invoke(this) as? org.gradle.api.provider.Property<Boolean> ?: continue
            var c: Class<*>? = prop.javaClass
            while (c != null) {
                for (f in c.declaredFields) {
                    try {
                        f.isAccessible = true
                        val v = f.get(prop)
                        if (v != null && f.name == "state") {
                            var sc: Class<*>? = v.javaClass
                            while (sc != null) {
                                for (sf in sc.declaredFields) {
                                    if (sf.type == Boolean::class.javaPrimitiveType) {
                                        sf.isAccessible = true
                                        sf.setBoolean(v, false)
                                    }
                                }
                                sc = sc.superclass
                            }
                        }
                    } catch (_: Throwable) {}
                }
                c = c.superclass
            }
            try {
                prop.set(true)
            } catch (_: Throwable) {}
        }
    }
}
