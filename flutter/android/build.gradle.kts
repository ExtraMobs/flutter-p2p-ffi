group = "dev.extramobs.p2p_ffi_flutter"
version = "0.20.0"

buildscript {
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:9.1.0")
        // the Kotlin the app's settings.gradle.kts declares (Flutter's template)
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.4.0")
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

// The Kotlin sources are compiled by AGP's built-in Kotlin (android.builtInKotlin
// in the app) or, with it off, by the Kotlin plugin Flutter applies.
extensions.configure<com.android.build.api.dsl.LibraryExtension> {
    namespace = "dev.extramobs.p2p_ffi_flutter"

    // FOREGROUND_SERVICE_TYPE_SPECIAL_USE: API 34
    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        minSdk = 24
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}
