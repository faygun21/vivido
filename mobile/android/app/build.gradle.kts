plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android") // İşte eksik olan o sihirli satır!
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.vivido.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.vivido.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

// En modern ve sorunsuz Kotlin sürüm ayarı
kotlin {
    jvmToolchain(17)
}

flutter {
    source = "../.."
}