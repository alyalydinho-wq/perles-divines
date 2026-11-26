plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "fr.perlesdivines.perles_divines"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "fr.perlesdivines.perles_divines"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // The phone already has the app installed from Android Studio, which signs
        // with the user debug keystore. The tooling keystore is a different key,
        // and Android refuses the update.
        create("phone") {
            storeFile = file("${System.getProperty("user.home")}/.android/debug.keystore")
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
            enableV1Signing = true
            enableV2Signing = true
            enableV3Signing = true
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("phone")
        }
    }

    // L'APK unique ne contient que l'ARM 32 et 64 bits (tous les téléphones).
    // Un paquet Dart y ajoute quand même sa bibliothèque x86_64 : seule, sans
    // le moteur Flutter, elle ferait planter un appareil x86_64 (Chromebook),
    // qui lit sinon très bien la version ARM.
    val targetPlatforms = (project.findProperty("target-platform") as String?)
        ?.split(",")
        .orEmpty()
    if (targetPlatforms.isNotEmpty() && "android-x64" !in targetPlatforms) {
        packaging.jniLibs.excludes += "lib/x86_64/**"
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
