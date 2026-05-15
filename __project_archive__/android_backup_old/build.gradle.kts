plugins {
    // Pa mete vèsyon isit la. Vèsyon an soti nan settings.gradle.kts
    id("com.google.gms.google-services") apply false
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}