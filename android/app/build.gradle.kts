import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Load release signing properties if the file exists (CI / dev machine).
// The file is git-ignored; its absence falls back to debug signing so
// `flutter run --release` keeps working on machines without it.
/// The ABIs `flutter build --target-platform` asked for, or `null` when it
/// named none (then every ABI is kept).
val flutterTargetAbis: List<String>? =
    (project.findProperty("target-platform") as String?)
        ?.split(",")
        ?.mapNotNull {
            when (it.trim()) {
                "android-arm" -> "armeabi-v7a"
                "android-arm64" -> "arm64-v8a"
                "android-x64" -> "x86_64"
                else -> null
            }
        }
        ?.takeIf { it.isNotEmpty() }

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

android {
    namespace = "com.war2aty.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Required by flutter_local_notifications (uses java.time APIs on API < 26).
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.war2aty.app"
        // minSdk 23 is a locked project decision (secure storage / crypto).
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // `--target-platform` limits Flutter's own engine libraries, but the
        // plugins' native ones (Tesseract, OpenCV) arrive as prebuilt `.so`
        // for every ABI and shipped regardless — ~10 MB of architectures the
        // target device cannot run (F27-P02).
        //
        // Driven by that same flag rather than hard-coded on purpose: a build
        // without it — the App Bundle for Play — keeps every ABI, so 32-bit
        // devices are still served and Play splits per device itself. Pinning
        // the filter here would quietly drop them from the listing.
        flutterTargetAbis?.let { abis ->
            ndk {
                abiFilters.clear()
                abiFilters.addAll(abis)
            }
        }
    }

    // `ndk.abiFilters` above is not enough on its own: the plugins' `.so` files
    // arrive from their AARs and something downstream puts every ABI back, so
    // the unwanted ones are dropped again here, at packaging, which runs last.
    packaging {
        jniLibs {
            flutterTargetAbis?.let { abis ->
                val everyAbi = listOf("armeabi-v7a", "arm64-v8a", "x86", "x86_64")
                for (unwanted in everyAbi - abis.toSet()) {
                    excludes += "lib/$unwanted/**"
                }
            }
        }
    }

    if (keystorePropertiesFile.exists()) {
        signingConfigs {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    flavorDimensions += "env"

    productFlavors {
        create("dev") {
            dimension = "env"
            applicationIdSuffix = ".dev"
            // Distinct label so dev + prod can coexist on one device.
            manifestPlaceholders["appName"] = "ورقتي (Dev)"
        }
        create("prod") {
            dimension = "env"
            manifestPlaceholders["appName"] = "ورقتي"
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
