import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Firebase Cloud Messaging: google-services.json (per machine, git-ignored) from the Firebase console. Without it the
// app builds and runs without push notifications.
if (file("google-services.json").exists()) apply(plugin = "com.google.gms.google-services")

// Google Maps SDK key: MAPS_API_KEY in android/local.properties (git-ignored) or the MAPS_API_KEY
// environment variable. Empty by default so builds work without a key (the app then uses the
// flutter_map fallback as long as GOOGLE_MAPS_API_KEY is not passed to Dart either).
val localProperties = Properties().apply {
    val file = rootProject.file("local.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
// Also read from the repo's git-ignored .dart-defines.json (Flutter rewrites local.properties on build).
val dartDefinesMapsKey: String? = rootProject.file("../../../.dart-defines.json").takeIf { it.exists() }?.let {
    Regex("\"MAPS_API_KEY\"\\s*:\\s*\"([^\"]*)\"").find(it.readText())?.groupValues?.get(1)
}
val mapsApiKey: String =
    dartDefinesMapsKey?.takeIf { it.isNotBlank() }
        ?: localProperties.getProperty("MAPS_API_KEY")?.takeIf { it.isNotBlank() }
        ?: System.getenv("MAPS_API_KEY")
        ?: ""

android {
    namespace = "com.rido.passenger"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications uses java.time APIs.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.rido.passenger"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // google_maps_flutter_android needs API 24+.
        minSdk = maxOf(flutter.minSdkVersion, 24)
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["MAPS_API_KEY"] = mapsApiKey
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

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
