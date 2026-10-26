plugins {
    id("com.android.application") version "9.0.1" apply false
    id("org.jetbrains.kotlin.android") version "2.3.20" apply false
    id("org.jetbrains.kotlin.plugin.compose") version "2.3.20" apply false
}

// Windows test workers on older JDKs can misread non-ASCII output paths.
// Keep the source where the user put it; allow an ASCII build-output directory.
val externalBuildRoot = providers.gradleProperty("jianzhouBuildRoot").orNull
subprojects {
    if (externalBuildRoot != null) layout.buildDirectory.set(file("$externalBuildRoot/$name"))
}
