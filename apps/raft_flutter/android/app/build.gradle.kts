plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "app.raft.raft_flutter"
    compileSdk = 37
    buildToolsVersion = "37.0.0"
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        // Performance labs build an isolated test app next to the real one
        // (`-PraftApplicationIdSuffix=.linkperf`); normal builds keep the id.
        applicationId =
            "app.raft.raft_flutter" +
                ((project.findProperty("raftApplicationIdSuffix") as String?) ?: "")
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = maxOf(flutter.minSdkVersion, 24)
        targetSdk = 37
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    val releaseKeystore = System.getenv("RAFT_ANDROID_KEYSTORE_PATH")
    val releaseSigningRequired = System.getenv("RAFT_ANDROID_SIGNING_REQUIRED") == "true"
    if (releaseSigningRequired && releaseKeystore.isNullOrBlank()) {
        throw GradleException("Release signing was required, but RAFT_ANDROID_KEYSTORE_PATH is missing")
    }
    if (!releaseKeystore.isNullOrBlank()) {
        signingConfigs.create("raftRelease") {
            storeFile = file(releaseKeystore)
            storePassword = System.getenv("RAFT_ANDROID_STORE_PASSWORD")
                ?: throw GradleException("Missing RAFT_ANDROID_STORE_PASSWORD")
            keyAlias = System.getenv("RAFT_ANDROID_KEY_ALIAS")
                ?: throw GradleException("Missing RAFT_ANDROID_KEY_ALIAS")
            keyPassword = System.getenv("RAFT_ANDROID_KEY_PASSWORD")
                ?: throw GradleException("Missing RAFT_ANDROID_KEY_PASSWORD")
        }
    }

    buildTypes {
        release {
            // Local acceptance retains its existing debug key. CI requires the
            // persistent release keystore; it never publishes a random debug key.
            signingConfig = signingConfigs.getByName(
                if (releaseKeystore.isNullOrBlank()) "debug" else "raftRelease"
            )
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
    testImplementation("junit:junit:4.13.2")
    implementation("androidx.core:core-splashscreen:1.2.0")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
