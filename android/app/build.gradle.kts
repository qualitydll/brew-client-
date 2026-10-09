import java.security.MessageDigest

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val mihomoAndroidVersion = "0.3.7"
val mihomoAndroidSha256 = "e9582440766f7e37f8f6b23344bee35d73e66e7e7a9fc3b90da5631f0fd19f24"
val mihomoAndroidAar = layout.buildDirectory.file(
    "mihomo/libmihomo-android-v$mihomoAndroidVersion.aar",
)
val downloadMihomoAndroid by tasks.registering {
    inputs.property("mihomoAndroidVersion", mihomoAndroidVersion)
    inputs.property("mihomoAndroidSha256", mihomoAndroidSha256)
    outputs.file(mihomoAndroidAar)

    doLast {
        val target = mihomoAndroidAar.get().asFile
        target.parentFile.mkdirs()
        val url =
            "https://github.com/oviron/libmihomo-android/releases/download/" +
                "v$mihomoAndroidVersion/libmihomo-android-v$mihomoAndroidVersion.aar"
        url.toURL().openStream().use { input ->
            target.outputStream().use { output -> input.copyTo(output) }
        }
        val digest = MessageDigest.getInstance("SHA-256")
            .digest(target.readBytes())
            .joinToString("") { "%02x".format(it.toInt() and 0xff) }
        check(digest == mihomoAndroidSha256) {
            "Mihomo Android library checksum mismatch: expected $mihomoAndroidSha256, got $digest"
        }
    }
}

android {
    namespace = "dev.brew.brew"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "dev.brew.brew"
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

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    implementation(files(mihomoAndroidAar).builtBy(downloadMihomoAndroid))
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
