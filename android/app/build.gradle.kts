plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    namespace = "com.example.mon_premye_app"

    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    defaultConfig {
        applicationId = "com.example.mon_premye_app"
        minSdk = flutter.minSdkVersion
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

flutter {
    source = "../.."
}

// === FLUTTER APK OUTPUT FIX (AUTO) ===

// Copy APKs to Flutter expected folder: build/app/outputs/flutter-apk/
tasks.register("copyApksToFlutter") {
    doLast {
        val outDir = File(rootProject.projectDir, "../build/app/outputs/flutter-apk")
        outDir.mkdirs()

        val apkDirs = listOf(
            File(project.buildDir, "outputs/apk/release"),
            File(project.buildDir, "outputs/apk/debug")
        )

        apkDirs.filter { it.exists() }.forEach { dir ->
            dir.listFiles { f -> f.isFile && f.name.endsWith(".apk") }?.forEach { apk ->
                val target = File(outDir, apk.name)
                apk.copyTo(target, overwrite = true)
                println("Copied APK => {target.absolutePath}")
            }
        }
    }
}

// Ensure copy runs after assemble tasks
tasks.matching { it.name == "assembleRelease" || it.name == "assembleDebug" }.configureEach {
    finalizedBy("copyApksToFlutter")
}



