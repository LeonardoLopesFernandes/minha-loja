plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "io.minhaloja.minhaloja"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "io.minhaloja.minhaloja"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        ndk {
            abiFilters += listOf("arm64-v8a")
        }
        resourceConfigurations += listOf("pt", "en")
    }

    signingConfigs {
        create("release") {
            val props = java.util.Properties()
            val propFile = rootProject.file("key.properties")
            if (propFile.exists()) {
                props.load(propFile.inputStream())
            }
            keyAlias = props.getProperty("keyAlias", "minhaloja")
            keyPassword = props.getProperty("keyPassword", "minhaloja123")
            storeFile = props.getProperty("storeFile")?.let { rootProject.file(it) }
                ?: rootProject.file("app/release-key.jks")
            storePassword = props.getProperty("storePassword", "minhaloja123")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt")
            )
        }
    }
}

flutter {
    source = "../.."
}