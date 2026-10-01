import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val keystoreProperties = Properties().apply {
    val keyProps = rootProject.file("key.properties")
    if (keyProps.exists()) {
        keyProps.inputStream().use { load(it) }
    }
}

android {
    namespace = "com.believoo.app"
    compileSdk = 36
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.believoo.app"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true
        ndk {
            // Keep both 64-bit and 32-bit ARM so older devices don't crash at launch.
            // AAB still serves each device only the ABI it needs.
            abiFilters += listOf("arm64-v8a", "armeabi-v7a")
        }
    }

    signingConfigs {
        getByName("debug") {
            enableV1Signing = true
            enableV2Signing = true
            enableV3Signing = false
            enableV4Signing = false
        }
        create("release") {
            // Published APKs are signed with the shared release key whose
            // SHA-1 (9656e59f…) is registered in Firebase — a different key
            // breaks Google Sign-In and update installs.
            storeFile = file(keystoreProperties.getProperty("storeFile", "release.keystore"))
            storePassword = keystoreProperties.getProperty("storePassword", "believoo123")
            keyAlias = keystoreProperties.getProperty("keyAlias", "release-key")
            keyPassword = keystoreProperties.getProperty("keyPassword", "believoo123")
            enableV1Signing = true
            enableV2Signing = true
            enableV3Signing = false
            enableV4Signing = false
        }
    }

    buildTypes {
        debug {
            isMinifyEnabled = false
            isShrinkResources = false
            signingConfig = signingConfigs.getByName("debug")
        }
        getByName("profile") {
            // Use debug signing for profile builds (no keystore needed)
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
        release {
            // Play Store release build must be signed with the release keystore.
            // Ensure the release SHA-1 is registered in Firebase for Google Sign-In.
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            // Include native symbol table for Play Console crash/ANR symbolication.
            // Use SYMBOL_TABLE (not FULL) to avoid Windows long-path issues.
            ndk {
                debugSymbolLevel = "SYMBOL_TABLE"
            }
        }
    }

    // Allow duplicate manifest namespaces - Agora SDK ships iris-rtc and
    // agora-special-full both using the io.agora.rtc namespace.
    packaging {
        jniLibs {
            useLegacyPackaging = true
            pickFirsts += listOf(
                "lib/arm64-v8a/libagora_clear_vision_extension.so",
                "lib/armeabi-v7a/libagora_clear_vision_extension.so",
                "lib/x86/libagora_clear_vision_extension.so",
                "lib/x86_64/libagora_clear_vision_extension.so",
            )
            // Exclude unused Agora SDK extensions to reduce APK size.
            // These are not referenced by the Dart code and are not loaded at runtime.
            excludes += listOf(
                "lib/*/libagora_lip_sync_extension.so",
                "lib/*/libagora_video_av1_encoder_extension.so",
                "lib/*/libagora_video_quality_analyzer_extension.so",
                "lib/*/libagora_face_detection_extension.so",
                "lib/*/libagora_face_capture_extension.so",
                "lib/*/libagora_content_inspect_extension.so",
                "lib/*/libagora_screen_capture_extension.so",
                "lib/*/libagora_segmentation_extension.so",
            )
        }
    }

    // Disable lint abort-on-error - lint tasks have state-tracking issues
    // on Windows with long paths, and lint failures should not block the APK build.
    lint {
        abortOnError = false
        checkReleaseBuilds = false
    }
}

flutter {
    source = "../.."
}

// Debug/profile builds repeatedly OOM in compressAssets on this large project.
// Keep assets uncompressed to avoid the JVM heap bottleneck.
tasks.configureEach {
    if (name == "compressDebugAssets" || name == "compressProfileAssets") {
        enabled = false
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("androidx.multidex:multidex:2.0.1")
    implementation("androidx.appcompat:appcompat:1.6.1")
    // Firebase BoM - aligns all Firebase dependency versions.
    implementation(platform("com.google.firebase:firebase-bom:33.7.0"))
    // Agora clear-vision beauty filter extension (libagora_clear_vision_extension.so).
    implementation("io.agora.rtc:clear-vision:4.5.2")
}

// Play Console requires Google Play Billing Library 8.0.0+.
// Pin it here because the current in_app_purchase package resolves to 7.1.1.
configurations.all {
    resolutionStrategy {
        force("com.android.billingclient:billing:8.2.0")
        force("com.android.billingclient:billing-ktx:8.2.0")
    }
}


