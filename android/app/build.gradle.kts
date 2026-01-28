plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Firebase için Google Services plugin (en son eklenmeli)
    id("com.google.gms.google-services")
    //id("com.google.firebase.crashlytics")
}
android {
    namespace = "com.vidviz.app"
    compileSdk = 36
    ndkVersion = "27.2.12479018"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    // App Key
    signingConfigs {
        create("release") {
            storeFile = file("key/vidviz.jks")
            storePassword = "77155904Aa"
            keyAlias = "wup"
            keyPassword = "77155904Aa"
        }
    }
    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.vidviz.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 26
        targetSdk = 36
        versionCode = 12
        versionName = "2.2"
        ndk {
            abiFilters.add("armeabi-v7a") // 32-bit desteği (eski cihazlar için)
            abiFilters.add("arm64-v8a") // Doğru kullanım
            abiFilters.add("x86_64")     // Doğru kullanım
        }
    }

    packagingOptions {
        jniLibs {
            pickFirsts += setOf("**/libc++_shared.so")

        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            ///isMinifyEnabled = true // Kod küçültme (önerilir) google play için odu bozabilir abc devredışı daha güvenli
            ///isShrinkResources = true // Kullanılmayan kaynakları kaldırma (önerilir)
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}


// APK kopyalama task'ını oluştur geçici çözüm sorna sileceğiz

afterEvaluate {
    val copyTask = tasks.register<Copy>("copyApkToFlutterBuildDir") {
        // Debug build: Hem app.apk hem app-debug.apk oluştur
        from(layout.buildDirectory.dir("outputs/apk/debug")) {
            include("app-debug.apk")
            rename("app-debug.apk", "app.apk") // İlk kopya: app.apk
        }
        from(layout.buildDirectory.dir("outputs/apk/debug")) {
            include("app-debug.apk")
            // İkinci kopya: app-debug.apk (orijinal isim)
        }

        // Release build: Hem app.apk hem app-release.apk oluştur
        from(layout.buildDirectory.dir("outputs/apk/release")) {
            include("app-release.apk")
            rename("app-release.apk", "app.apk") // app.apk
        }
        from(layout.buildDirectory.dir("outputs/apk/release")) {
            include("app-release.apk")
            // app-release.apk
        }

        // Flutter'ın beklediği yol: <proje_kökü>/build/app/outputs/flutter-apk/
        val flutterBuildDir = File(project.projectDir.parentFile.parentFile, "build/app/outputs/flutter-apk")
        into(flutterBuildDir)

        doFirst {
            flutterBuildDir.mkdirs() // Klasör yoksa oluştur
        }

        doLast {
            println("✅ APK kopyalandı: ${flutterBuildDir.absolutePath}")
            flutterBuildDir.listFiles()?.forEach { file ->
                println("   📄 ${file.name}")
            }
        }
    }

    tasks.findByName("assembleDebug")?.finalizedBy(copyTask)
    tasks.findByName("assembleRelease")?.finalizedBy(copyTask)
}