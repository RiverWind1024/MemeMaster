plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.mememaster.app"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.mememaster.app"
        minSdk = 26
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        ndk {
            // release: 只打包 arm64-v8a（真机用）
            // debug:  取消下一行注释可额外包含 x86_64（模拟器用）
            abiFilters += listOf("arm64-v8a")
            // abiFilters += listOf("x86_64")
        }
        externalNativeBuild {
            cmake {
                val llamaDir = System.getenv("LLAMA_CPP_DIR")
                    ?: project.findProperty("llama.cpp.dir")?.toString()
                    ?: "${project.rootDir}/../third_party/llama.cpp"
                arguments += listOf("-DLLAMA_CPP_DIR=${llamaDir}")
                arguments += listOf("-DCMAKE_BUILD_TYPE=Release")
                arguments += listOf("-DCMAKE_EXPORT_COMPILE_COMMANDS=ON")
                arguments += listOf("-DCMAKE_ANDROID_PROCESS_MAX=4")
                cppFlags += listOf("-O3", "-DNDEBUG")
                targets += listOf("meme_llm")
            }
        }
    }

    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
            version = "3.22.1"
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    packaging {
        jniLibs {
            excludes += listOf(
                "lib/armeabi-v7a/**"
            )
        }
    }
}

dependencies {
    // ML Kit OCR
    implementation("com.google.mlkit:text-recognition:16.0.1")
    implementation("com.google.mlkit:text-recognition-chinese:16.0.1")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
