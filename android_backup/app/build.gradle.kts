import com.android.build.api.dsl.LibraryExtension
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

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

tasks.register("clean", Delete::class.java) {
    delete(rootProject.layout.buildDirectory)
}

subprojects {
    val subproject = this
    pluginManager.withPlugin("com.android.library") {
        subproject.extensions.configure(LibraryExtension::class.java) {
            if (namespace == null) {
                namespace = subproject.group.toString()
            }
        }
    }
}

// Yahan humne saare plugins ko strictly Java 17 par align kar diya hai
subprojects {
    tasks.withType(KotlinCompile::class.java).configureEach {
        compilerOptions.jvmTarget.set(JvmTarget.JVM_17)
    }
}