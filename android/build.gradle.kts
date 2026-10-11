import com.android.build.api.dsl.ApplicationExtension
import com.android.build.api.dsl.LibraryExtension
import com.android.build.api.variant.AndroidComponentsExtension
import java.util.Properties

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

// Registered before `evaluationDependsOn` below so `:app` gets it too.
// Flutter and plugins such as `jni` pin `flutter.ndkVersion`, and the build
// fails on machines without that exact NDK. Use it when installed, otherwise
// the newest NDK in this machine's Android SDK. With no NDK installed, keep the
// requested version so Gradle can still download it.
fun androidSdkDir(): File? {
    val properties = Properties()
    val localProperties = rootProject.file("local.properties")
    if (localProperties.isFile) {
        localProperties.inputStream().use { stream -> properties.load(stream) }
    }
    val path =
        properties.getProperty("sdk.dir")
            ?: System.getenv("ANDROID_HOME")
            ?: System.getenv("ANDROID_SDK_ROOT")
    return path?.let(::File)
}

val installedNdkVersions: List<String> =
    androidSdkDir()
        ?.resolve("ndk")
        ?.listFiles()
        ?.filter { it.resolve("source.properties").isFile }
        ?.map { it.name }
        .orEmpty()

fun compareVersions(a: String, b: String): Int {
    val left = a.split('.').map { it.toIntOrNull() ?: 0 }
    val right = b.split('.').map { it.toIntOrNull() ?: 0 }
    return left.zip(right).map { (x, y) -> x.compareTo(y) }.firstOrNull { it != 0 } ?: 0
}

fun selectNdkVersion(requested: String): String {
    if (requested in installedNdkVersions) return requested
    return installedNdkVersions.maxWithOrNull(::compareVersions) ?: requested
}

subprojects {
    listOf("com.android.application", "com.android.library").forEach { pluginId ->
        plugins.withId(pluginId) {
            extensions.getByType(AndroidComponentsExtension::class.java).finalizeDsl { android ->
                when (android) {
                    is ApplicationExtension -> android.ndkVersion = selectNdkVersion(android.ndkVersion)
                    is LibraryExtension -> android.ndkVersion = selectNdkVersion(android.ndkVersion)
                }
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
