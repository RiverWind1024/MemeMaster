plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

// 读取签名配置
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = java.util.Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(java.io.FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.mememaster.app"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    // 签名配置
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it as String) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

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
                // Vulkan 启用判断：third_party/Vulkan-Headers 和 SPIRV-Headers 都存在
                // ANDROID_CPU_ONLY=1 时强制禁用 Vulkan
                val forceCpuOnly = System.getenv("ANDROID_CPU_ONLY") == "1"
                val vulkanHeadersDir = "${project.rootDir}/../third_party/Vulkan-Headers"
                val spirvHeadersConfig = "${project.rootDir}/../third_party/spirv-headers-install/share/cmake/SPIRV-Headers/SPIRV-HeadersConfig.cmake"
                val hasVulkanDeps = !forceCpuOnly &&
                                    File(vulkanHeadersDir, "include/vulkan/vulkan.hpp").exists() &&
                                    File(spirvHeadersConfig).exists()
                arguments += listOf("-DENABLE_VULKAN=${if (hasVulkanDeps) "ON" else "OFF"}")
                // Vulkan glslc 路径（NDK 自带）
                if (hasVulkanDeps) {
                    // ndkRoot 解析：env > project property > sdk+version > sdk/ndk/default
                    val ndkRoot = System.getenv("ANDROID_NDK")
                        ?: providers.gradleProperty("android.ndkDirectory").orNull
                        ?: "${android.sdkDirectory}/ndk/${android.ndkVersion}"
                    if (ndkRoot.isBlank()) {
                        // 兜底：直接看 SDK 默认目录
                        val defaultNdk = file("${android.sdkDirectory}/ndk")
                            .listFiles()?.firstOrNull { it.isDirectory }
                        if (defaultNdk != null) {
                            arguments += listOf("-DVulkan_GLSLC_EXECUTABLE=${defaultNdk.absolutePath}/shader-tools/linux-x86_64/glslc")
                        }
                    } else {
                        arguments += listOf("-DVulkan_GLSLC_EXECUTABLE=$ndkRoot/shader-tools/linux-x86_64/glslc")
                    }
                    arguments += listOf("-DSPIRV-Headers_DIR=${project.rootDir}/../third_party/spirv-headers-install/share/cmake/SPIRV-Headers")
                    // 关键：注入 Vulkan Android 预加载脚本（处理 ABI 特定的 libvulkan.so 路径）
                    arguments += listOf("-DCMAKE_PROJECT_INCLUDE_BEFORE=${project.rootDir}/app/src/main/cpp/cmake/vulkan-android-prelude.cmake")
                    // SPIRV-Headers 头文件路径（ggml-vulkan 需要 spirv/unified1/spirv.hpp）
                    // 必须用 cppFlags 而不是 arguments，否则不会被加到每个编译命令
                    cppFlags += listOf("-I${project.rootDir}/../third_party/spirv-headers-install/include")
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
            signingConfig = signingConfigs.getByName("release")
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
                "lib/armeabi-v7a/**",
                "lib/x86_64/**"
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
