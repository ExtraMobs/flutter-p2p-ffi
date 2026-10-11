plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "dev.extramobs.ipfs_ffi_android"
    compileSdk = flutter.compileSdkVersion
    // O mesmo NDK que compila a libipfs.so (tool/build.dart android); o app não
    // compila C, mas o AGP usa o NDK para tratar as .so empacotadas.
    ndkVersion = "30.0.16248370"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "dev.extramobs.ipfs_ffi_android"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = maxOf(24, flutter.minSdkVersion) // a libipfs.so é compilada para a API 24
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // A libipfs.so fica em ipfs_ffi/native/android/<abi>/ (`dart run
    // tool/build.dart android`); o APK a empacota de lá, sem cópia.
    sourceSets["main"].jniLibs.srcDirs("../../../../native/android")
    // Só as libipfs.so das ABIs do --target-platform (padrão: todas), para o
    // APK de um aparelho arm64 não levar a do x86_64.
    val abiOf = mapOf("android-arm64" to "arm64-v8a", "android-x64" to "x86_64")
    val targets = (project.findProperty("target-platform") as String?)?.split(",")
    if (targets != null) {
        for ((platform, abi) in abiOf) {
            if (platform !in targets) packaging.jniLibs.excludes += "lib/$abi/**"
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
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
