plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // Google services pou firebase
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.mon_premye_app"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.example.mon_premye_app"
        minSdk = 21
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }
}

dependencies {
    // Firebase BoM + Auth (sa sifi pou login)
    implementation(platform("com.google.firebase:firebase-bom:33.7.0"))
    implementation("com.google.firebase:firebase-auth")
}