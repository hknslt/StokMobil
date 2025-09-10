plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.capri"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Java 17 + DESUGARING
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }
    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.capri"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

/** <- ÖNEMLİ: Eğer başka bağımlılık 2.0.4 istiyorsa bile 2.1.5'e zorla */
configurations.configureEach {
    resolutionStrategy.eachDependency {
        if (requested.group == "com.android.tools"
            && requested.name == "desugar_jdk_libs"
            && (requested.version == null || requested.version!! < "2.1.5")
        ) {
            useVersion("2.1.5")
            because("flutter_local_notifications requires desugar_jdk_libs >= 2.1.4")
        }
    }
}

flutter { source = "../.." }

dependencies {
    // <-- BURAYI 2.1.5 YAP!
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk8")
}
