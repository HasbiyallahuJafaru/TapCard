plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.tapcard.tapcard"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.tapcard.tapcard"
        // HCE requires API 19+; 23 covers ~99% of active Android devices (2026) and
        // is the standard minimum for modern Flutter apps.
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // ADMOB_APP_ID is injected from local.properties or CI secrets at build time.
        // Use "ca-app-pub-3940256099942544~3347511713" (test ID) for debug builds.
        manifestPlaceholders["ADMOB_APP_ID"] = "ca-app-pub-3940256099942544~3347511713"
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    // Glance — Compose-based home-screen widget API.
    // Pinned 2026-06-10. Check https://developer.android.com/jetpack/androidx/releases/glance
    implementation("androidx.glance:glance-appwidget:1.1.0")
    implementation("androidx.glance:glance:1.1.0")

    // LocalBroadcastManager — used to pass NFC tap events from HCE service to MainActivity.
    implementation("androidx.localbroadcastmanager:localbroadcastmanager:1.1.0")
}

flutter {
    source = "../.."
}
