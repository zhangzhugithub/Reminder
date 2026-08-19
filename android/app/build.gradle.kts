plugins {
    id("com.android.application")
    id("kotlin-android")
    // Flutter Gradle Plugin（由 settings.gradle.kts 的 includeBuild 提供）
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.offlinereminder.reminder"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications 要求启用 core library desugaring
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.offlinereminder.reminder"
        // flutter_local_notifications 要求 minSdk 24
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // 依赖较多，启用 multidex
        multiDexEnabled = true
    }

    buildTypes {
        release {
            // TODO: 发布前替换为正式签名配置
            signingConfig = signingConfigs.getByName("debug")
            // 如需开启 R8 压缩，须保留 proguard-rules.pro 中的 device_calendar keep 规则
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
