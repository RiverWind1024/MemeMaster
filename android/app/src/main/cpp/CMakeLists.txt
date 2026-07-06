cmake_minimum_required(VERSION 3.22.1)
project(meme_llm C CXX)

if(NOT DEFINED LLAMA_CPP_DIR)
    if(DEFINED ENV{LLAMA_CPP_DIR})
        set(LLAMA_CPP_DIR $ENV{LLAMA_CPP_DIR})
    else()
        set(LLAMA_CPP_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../../../llama.cpp")
    endif()
endif()

if(NOT EXISTS "${LLAMA_CPP_DIR}/CMakeLists.txt")
    message(FATAL_ERROR "llama.cpp not found at ${LLAMA_CPP_DIR}. Set LLAMA_CPP_DIR env var or cmake property.")
endif()

# 为 arm64-v8a 和 x86_64 构建，其他 ABI 跳过
if(CMAKE_ANDROID_ARCH_ABI STREQUAL "arm64-v8a" OR CMAKE_ANDROID_ARCH_ABI STREQUAL "x86_64")
    set(BUILD_SHARED_LIBS OFF)
    set(GGML_STATIC ON)
    set(LLAMA_STATIC ON)
    set(GGML_SHARED OFF)
    set(LLAMA_SHARED OFF)
    set(LLAMA_BUILD_TESTS OFF)
    set(LLAMA_BUILD_EXAMPLES OFF)
    set(LLAMA_BUILD_SERVER OFF)
    set(LLAMA_INSTALL_VERSION "0.0.0")
    set(MTMD_VIDEO OFF)

    # GPU 加速后端（默认关闭）
    set(GGML_VULKAN ON)

    # 设置 SPIRV-Headers 路径
    set(SPIRV-Headers_DIR "/home/jiangzifeng/下载/SPIRV-Headers-main/build/CMakeFiles/Export/7e173bd2f6c93e514e1dd3616a7ea2ca")
    list(APPEND CMAKE_PREFIX_PATH "/home/jiangzifeng/下载/SPIRV-Headers-main/build")

    # 设置 glslc 路径（Android NDK 自带）
    set(Vulkan_GLSLC_EXECUTABLE "/home/jiangzifeng/Software/android-sdk/ndk/28.2.13676358/shader-tools/linux-x86_64/glslc")

    add_subdirectory(${LLAMA_CPP_DIR} llama.cpp EXCLUDE_FROM_ALL)
    add_subdirectory(${LLAMA_CPP_DIR}/tools/mtmd mtmd)

    add_library(meme_llm SHARED meme_llm.cpp)
    target_include_directories(meme_llm PRIVATE
        ${LLAMA_CPP_DIR}/include
        ${LLAMA_CPP_DIR}/ggml/include
        ${LLAMA_CPP_DIR}/tools/mtmd
    )
    target_link_libraries(meme_llm llama ggml mtmd android log)
else()
    # 非 arm64-v8a/x86_64 ABI：创建一个空的 stub library
    # Android Gradle 要求每个 ABI 都有对应的 .so 文件
    # 我们会在 packaging 中排除这些 ABI
    add_library(meme_llm SHARED meme_llm.cpp)
    target_compile_definitions(meme_llm PRIVATE MLLM_STUB=1)
endif()
