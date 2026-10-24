import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// The release key, from the git-ignored android/key.properties. Release
// builds refuse to run without it rather than fall back to the debug key: an
// APK signed with the debug key can never be updated by a properly signed one
// without uninstalling it, which loses everyone's profiles.
val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties().apply {
    if (keyPropertiesFile.exists()) keyPropertiesFile.inputStream().use { load(it) }
}

android {
    namespace = "com.coffeehauslabs.nightingale_tv"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.coffeehauslabs.nightingale_tv"
        // Android 7.0: every Android TV / Google TV device still in use, and
        // every Fire TV OS.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        // From pubspec.yaml's version. Split APKs get 1000 * ABI added, so
        // Android prefers the matching one on upgrade.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keyPropertiesFile.exists()) {
            create("release") {
                storeFile = file(keyProperties.getProperty("storeFile"))
                // The passwords may come from the environment instead, so
                // they needn't be written down anywhere.
                storePassword = keyProperties.getProperty("storePassword")
                    ?: System.getenv("NIGHTINGALE_TV_STORE_PASSWORD")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
                    ?: System.getenv("NIGHTINGALE_TV_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release")
        }
    }

    // JVM tests (android/app/src/test) run Media3's audio classes, which
    // touch android.jar's stubs; those return defaults instead of throwing.
    testOptions {
        unitTests.isReturnDefaultValues = true
    }

}

// The Android player (ExoTunerHost.kt): ExoPlayer, and its OkHttp data source
// with the OkHttp version that Media3 release is built against.
dependencies {
    implementation("androidx.media3:media3-exoplayer:1.11.1")
    // Plex's transcodes are HLS playlists.
    implementation("androidx.media3:media3-exoplayer-hls:1.11.1")
    // Live TV sources' rtsp:// streams (live-playback, "M3U streams").
    implementation("androidx.media3:media3-exoplayer-rtsp:1.11.1")
    implementation("androidx.media3:media3-datasource-okhttp:1.11.1")
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    // LevelingAudioProcessorTest.
    testImplementation("junit:junit:4.13.2")
}

gradle.taskGraph.whenReady {
    val releasePackaging = allTasks.any { it.project == project && it.name in setOf("packageRelease", "signReleaseBundle") }
    if (releasePackaging && !keyPropertiesFile.exists()) {
        throw GradleException(
            """
            |android/key.properties is missing, so there's no release key to sign with.
            |Create a key once and keep it outside the repository:
            |  keytool -genkey -v -keystore ~/nightingale-tv-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias nightingale-tv
            |Then create android/key.properties (git-ignored) with storeFile, storePassword, keyAlias and keyPassword
            |(or leave the passwords out and set NIGHTINGALE_TV_STORE_PASSWORD and NIGHTINGALE_TV_KEY_PASSWORD).
            |Debug builds (flutter run) don't need it.
            """.trimMargin()
        )
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
