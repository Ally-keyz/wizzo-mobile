import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Firebase/Google Services. Applied only once android/app/google-services.json
// exists (drop in the console-downloaded file) so builds keep working before
// the Firebase credentials arrive.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

// Production signing lives in android/key.properties (gitignored):
//   storeFile=../keystore/wizzo-upload.jks
//   storePassword=...
//   keyAlias=upload
//   keyPassword=...
// Until that file is provided, release builds fall back to the debug key so
// the pipeline keeps working. Regenerate this file from
// `flutter doctor --android-licenses`-safe ceremony when the real keystore is ready.
val keystorePropertiesFileName = "key.properties"
val keystorePropertiesFile = rootProject.file(keystorePropertiesFileName)
val hasReleaseKey = keystorePropertiesFile.exists()

android {
    namespace = "app.wizzo.wizzo_market"
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
        applicationId = "app.wizzo.wizzo_market"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKey) {
            val props = Properties().apply {
                load(FileInputStream(keystorePropertiesFile))
            }
            create("release") {
                keyAlias = props["keyAlias"] as String
                keyPassword = props["keyPassword"] as String
                storeFile = file(props["storeFile"] as String)
                storePassword = props["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Signed with the production release key from android/key.properties.
            // Falls back to the debug key only when that file is absent.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            signingConfig = if (hasReleaseKey) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
