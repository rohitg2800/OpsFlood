import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // Built-in Kotlin — replaces legacy id("kotlin-android") KGP
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")  // Google services plugin
}

val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.inputStream().use { localProperties.load(it) }
}

val keystorePropertiesFile = rootProject.file("keystore.properties")
val useReleaseKeystore = keystorePropertiesFile.exists()

android {
    namespace = "com.equinox_bh.android"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlin {
        compilerOptions {
            jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11
        }
    }

    if (useReleaseKeystore) {
        val keystoreProperties = Properties()
        keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
        signingConfigs {
            create("release") {
                keyAlias     = keystoreProperties["keyAlias"]     as String
                keyPassword  = keystoreProperties["keyPassword"]  as String
                storeFile    = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    defaultConfig {
        applicationId = "com.equinox_bh.android"
        minSdk    = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = 4
        versionName = "1.2.0"
        multiDexEnabled = true
    }

    buildTypes {
        release {
            signingConfig = if (useReleaseKeystore)
                signingConfigs.getByName("release")
            else
                signingConfigs.getByName("debug")
            isMinifyEnabled   = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // Firebase BoM — controls all Firebase library versions
    implementation(platform("com.google.firebase:firebase-bom:34.14.0"))

    // Firebase Analytics (no version needed when using BoM)
    implementation("com.google.firebase:firebase-analytics")

    // Firebase Cloud Messaging — needed for push notification support
    implementation("com.google.firebase:firebase-messaging")
}

flutter {
    source = "../.."
}
