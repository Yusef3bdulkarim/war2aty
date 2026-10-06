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

/// Why the release key is checked rather than assumed (F27-T13 / H7).
///
/// `key.properties` is git-ignored, so it is absent on any machine that has
/// not been set up — and the old fallback was to sign with the DEBUG key and
/// say nothing. A debug-signed build installs, runs and looks correct, and is
/// rejected by Play with a signature error, or worse, shipped somewhere else
/// and trusted. The failure has to be at build time, in words.
///
/// It stays a fallback for the DEV flavor on purpose: `flutter run --release`
/// on a developer's machine is a legitimate everyday thing, and the dev app is
/// a separate `applicationId` that is never published.
val releaseKeyProblem: String? = when {
    !keystorePropertiesFile.exists() ->
        "android/key.properties does not exist"
    listOf("keyAlias", "keyPassword", "storeFile", "storePassword")
        .any { keystoreProperties[it] == null } ->
        "android/key.properties is missing one of keyAlias, keyPassword, storeFile, storePassword"
    // Resolved exactly as the signing config below resolves it: `file(...)`
    // in this module, i.e. relative to android/app/ — not to the root
    // project. Getting that wrong made this check reject the real keystore.
    !file(keystoreProperties["storeFile"] as String).exists() ->
        "the keystore named by storeFile does not exist: " +
            "${keystoreProperties["storeFile"]}"
    else -> null
}

val hasReleaseKey = releaseKeyProblem == null

/// Fails a **prod release** build that has no usable release key, naming the
/// reason. Checked on the task graph rather than at configuration time so that
/// every other build — dev, debug, `flutter test`, an IDE sync — is unaffected
/// on a machine without the keystore.
/// The tasks that only a genuine prod release runs.
///
/// Matched by exact name rather than by "contains ProdRelease", which was the
/// first attempt and was wrong: the Flutter Gradle plugin puts
/// `compileFlutterBuildProdRelease` and `packJniLibsflutterBuildProdRelease`
/// into EVERY release graph, and AGP adds `preProdReleaseBuild`, so a dev
/// release build was refused too. These five are the packaging and install
/// steps, which appear only when a prod release artifact is actually produced.
val prodReleaseOutputTasks = setOf(
    "assembleProdRelease",
    "bundleProdRelease",
    "packageProdRelease",
    "packageProdReleaseBundle",
    "installProdRelease",
)

gradle.taskGraph.whenReady {
    val buildsProdRelease = allTasks.any { task ->
        task.project == project && task.name in prodReleaseOutputTasks
    }

    if (buildsProdRelease && !hasReleaseKey) {
        throw GradleException(
            """
            |A prod release build needs the real release key, and $releaseKeyProblem.
            |
            |This used to fall back to the debug key silently, which produces a
            |build that looks fine, cannot be published, and must never be
            |distributed (F27-H7).
            |
            |Set up android/key.properties (see docs/BUILD.md), or build the dev
            |flavor instead: flutter build apk --flavor dev -t lib/main_dev.dart
            """.trimMargin(),
        )
    }
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
        // Flutter's own floor (24 in 3.41.9), which already clears the
        // project's secure-storage and crypto requirement. Taken from the SDK
        // rather than pinned, so a Flutter upgrade does not leave a stale
        // number here claiming to be a decision (F27-T13).
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

    if (hasReleaseKey) {
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
            // Prod + no key never reaches here: `gradle.taskGraph.whenReady`
            // above has already failed the build. This fallback exists for the
            // dev flavor alone (H7).
            signingConfig = if (hasReleaseKey) {
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

/// Keeps the dev-only mock fixtures out of the prod bundle (F27-T13 / M4).
///
/// `assets/fixtures/analysis/` backs `MockAnalysisRemoteDataSource`, which is
/// reachable only when `env.isDev && USE_MOCK_ANALYSIS` — so in a prod build
/// the files are unreachable by construction, and shipping canned invoices and
/// medical appointments inside the real app is sloppy at best and misleading at
/// worst. pubspec has no per-flavor asset list, so they are removed after the
/// Flutter plugin has copied them in, for prod variants only.
///
/// Deliberately not silent: if the task is ever renamed by a Flutter upgrade,
/// the `prodAssetStripTasks` count below is zero and the build fails, rather
/// than quietly shipping the fixtures again.
val prodAssetStripTasks =
    tasks.matching { it.name.matches(Regex("copyFlutterAssetsProd(Debug|Profile|Release)")) }

prodAssetStripTasks.configureEach {
    doLast {
        val copy = this as Copy
        val fixtures = File(copy.destinationDir, "flutter_assets/assets/fixtures")
        if (fixtures.exists()) {
            delete(fixtures)
            logger.lifecycle("F27-T13: removed dev-only fixtures from ${'$'}{project.name} prod assets")
        }
    }
}

gradle.taskGraph.whenReady {
    val buildsProd = allTasks.any { task ->
        task.project == project && task.name.matches(Regex("copyFlutterAssetsProd(Debug|Profile|Release)"))
    }
    if (buildsProd && prodAssetStripTasks.isEmpty()) {
        throw GradleException(
            "F27-T13: no copyFlutterAssetsProd* task matched, so the dev-only " +
                "mock fixtures would ship in the prod bundle. The Flutter Gradle " +
                "plugin's task names have changed; fix the pattern in " +
                "android/app/build.gradle.kts.",
        )
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
