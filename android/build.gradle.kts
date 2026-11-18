allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// The Firebase plugins' own Kotlin sources call Android APIs that Google has
// since deprecated. Gradle reports those on every build, and Flutter prefixes
// each line with "exception:", which reads like a failure it is not — the code
// is in the pub cache, nothing here calls it, and the build is unaffected.
//
// Muted for those modules only, so warnings about this app's own code are
// still reported. Remove once the Firebase packages stop using the old APIs.
subprojects {
    if (project.name.startsWith("firebase_")) {
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>()
            .configureEach {
                compilerOptions.suppressWarnings.set(true)
            }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
