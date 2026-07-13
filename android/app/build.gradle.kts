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
                // OpenCL 后端在 Android CI 环境中 cmake 找不到系统 OpenCL 库，默认禁用
                arguments += listOf("-DENABLE_OPENCL=OFF")
                // Vulkan GPU 加速（需要 SPIRV-Headers + Vulkan-Headers）。两者都存在且明确启用才开启
                // CI 默认禁用，因为 gradle externalNativeBuild 会为所有 ABI 都编译，需要 ABI 特定的 Vulkan_LIBRARY 路径
                // 本地启用方式：设置环境变量 ENABLE_VULKAN_FOR_CI=1 并确保 NDK 路径正确
                val enableVulkan = System.getenv("ENABLE_VULKAN_FOR_CI") == "1"
                val vulkanHeadersDir = "${project.rootDir}/../third_party/Vulkan-Headers"
                val spirvHeadersConfig = "${project.rootDir}/../third_party/spirv-headers-install/share/cmake/SPIRV-Headers/SPIRV-HeadersConfig.cmake"
                val hasVulkanHeaders = File(vulkanHeadersDir, "include/vulkan/vulkan.hpp").exists()
                val hasSpirvHeaders = File(spirvHeadersConfig).exists()
                if (enableVulkan && hasVulkanHeaders && hasSpirvHeaders) {
                    val ndkRoot = System.getenv("ANDROID_NDK")
                        ?: providers.gradleProperty("android.ndkDirectory").orNull
                        ?: "${android.sdkDirectory}/ndk/${android.ndkVersion}"
                    val vulkanLib = "$ndkRoot/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android/29/libvulkan.so"
                    arguments += listOf("-DENABLE_VULKAN=ON")
                    arguments += listOf("-DVulkan_GLSLC_EXECUTABLE=$ndkRoot/shader-tools/linux-x86_64/glslc")
                    arguments += listOf("-DSPIRV-Headers_DIR=${project.rootDir}/../third_party/spirv-headers-install/share/cmake/SPIRV-Headers")
                    arguments += listOf("-DCMAKE_CXX_FLAGS=-I${project.rootDir}/../third_party/Vulkan-Headers/include -I${project.rootDir}/../third_party/spirv-headers-install/include")
                    arguments += listOf("-DVulkan_LIBRARY=$vulkanLib")
                } else {
                    arguments += listOf("-DENABLE_VULKAN=OFF")
                }
                
                // GPU 后端编译优化标志
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
