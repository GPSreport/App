pluginManagement {
    // Determine flutter SDK path: prefer local.properties, fallback to FLUTTER_ROOT env var.
    val flutterSdkPath = run {
        val propsFile = file("local.properties")
        if (propsFile.exists()) {
            val properties = java.util.Properties()
            propsFile.inputStream().use { properties.load(it) }
            val p = properties.getProperty("flutter.sdk")
            if (p != null && file(p).exists()) {
                p
            } else {
                // fallback to FLUTTER_ROOT env if local.properties value is absent or invalid
                val env = System.getenv("FLUTTER_ROOT")
                require(env != null && file(env).exists()) { "flutter.sdk in local.properties is invalid and FLUTTER_ROOT environment variable is not set or points to a non-existent path" }
                env
            }
        } else {
            val env = System.getenv("FLUTTER_ROOT")
            require(env != null && file(env).exists()) { "local.properties not found and FLUTTER_ROOT environment variable is not set or points to a non-existent path" }
            env
        }
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.9.1" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
}

include(":app")
