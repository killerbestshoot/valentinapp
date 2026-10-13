import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

// Kle siyati pwodiksyon an: android/key.properties (pa nan git). Li pwente sou
// ~/.voupvapcash/voupvapcash-release.jks. PÈDI KLE SA A = pa ka mete app la ajou
// sou telefòn yo ankò: fè yon kopi sekirize.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    namespace = "com.voupvapcash.app"

    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    defaultConfig {
        applicationId = "com.voupvapcash.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // San key.properties, yon build release ta siyen ak kle debug la:
            // nou refize pito pase distribye yon APK ki pa ka mete ajou.
            if (!keystorePropertiesFile.exists()) {
                throw GradleException("android/key.properties manke: build release la bezwen kle siyati VOUPVAPCASH la.")
            }
            signingConfig = signingConfigs.getByName("release")
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



