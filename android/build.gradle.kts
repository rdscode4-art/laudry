buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.google.gms:google-services:4.4.1")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
    configurations.all {
        resolutionStrategy {
            force("com.razorpay:checkout:1.6.39")
        }
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

subprojects {
    if (project.name == "app") {
        // Skip app module as it is already evaluated and has compileSdk=36
    } else {
        project.afterEvaluate {
            if (project.hasProperty("android")) {
                val androidExt = project.extensions.findByName("android")
                if (androidExt != null) {
                    try {
                        val method = androidExt.javaClass.getMethod("setCompileSdkVersion", Int::class.java)
                        method.invoke(androidExt, 36)
                    } catch (e: Exception) {
                        // ignore
                    }
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
