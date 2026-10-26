plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.smartbin.smartbin_new"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.smartbin.smartbin_new"
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

    applicationVariants.all {
        val variant = this
        outputs.all {
            val output = this as? com.android.build.gradle.internal.api.BaseVariantOutputImpl
            output?.outputFileName = "smartbin_new.apk"
        }

        variant.assembleProvider.configure {
            doLast {
                val flutterApkDir = layout.buildDirectory.dir("outputs/flutter-apk").get().asFile
                val apkDir = layout.buildDirectory.dir("outputs/apk/${variant.name}").get().asFile
                val srcApk = File(apkDir, "smartbin_new.apk")

                if (srcApk.exists()) {
                    if (variant.name == "release") {
                        copy {
                            from(srcApk)
                            into(flutterApkDir)
                            rename { "smartbin_new.apk" }
                        }
                    }
                    copy {
                        from(srcApk)
                        into(flutterApkDir)
                        rename { "smartbin_new-${variant.name}.apk" }
                    }
                }
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

flutter {
    source = "../.."
}
