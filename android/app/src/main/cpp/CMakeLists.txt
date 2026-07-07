cmake_minimum_required(VERSION 3.22.1)
project(meme_llm C CXX)

set(CMAKE_BUILD_PARALLEL_LEVEL 4)

if(NOT DEFINED LLAMA_CPP_DIR)
    if(DEFINED ENV{LLAMA_CPP_DIR})
        set(LLAMA_CPP_DIR $ENV{LLAMA_CPP_DIR})
    else()
        set(LLAMA_CPP_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../../third_party/llama.cpp")
    endif()
endif()

if(NOT EXISTS "${LLAMA_CPP_DIR}/CMakeLists.txt")
    message(FATAL_ERROR "llama.cpp not found at ${LLAMA_CPP_DIR}. Set LLAMA_CPP_DIR env var or cmake property.")
endif()

# OpenCL 支持（默认关闭）
# 启用需要：
# 1. 运行 ./scripts/init-third-party.sh 下载 OpenCL-Headers
# 2. 设置 ANDROID_NDK 环境变量指向 NDK 目录
# 3. 运行 third_party/OpenCL-Headers/scripts/ci_build.sh 或手动交叉编译 ICD Loader
option(ENABLE_OPENCL "Enable OpenCL backend (requires OpenCL-ICD-Loader)" OFF)

# Vulkan 支持（默认关闭）
# 启用需要安装 Vulkan SDK 或使用 Android NDK 自带的 vulkan-headers
option(ENABLE_VULKAN "Enable Vulkan backend" OFF)

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

    # GPU 加速后端（默认关闭，需手动启用）
    set(GGML_OPENCL ${ENABLE_OPENCL})
    set(GGML_VULKAN ${ENABLE_VULKAN})

    # OpenCL 头文件路径
    if(ENABLE_OPENCL)
        set(OPENCL_HEADERS_DIR "${LLAMA_CPP_DIR}/../OpenCL-Headers")
        if(EXISTS "${OPENCL_HEADERS_DIR}/CL/opencl.h")
            message(STATUS "OpenCL headers found at ${OPENCL_HEADERS_DIR}")
            include_directories(${OPENCL_HEADERS_DIR})
        else()
            message(WARNING "OpenCL headers not found at ${OPENCL_HEADERS_DIR}. GPU acceleration may not work.")
        endif()
    endif()

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
    add_library(meme_llm SHARED meme_llm.cpp)
    target_compile_definitions(meme_llm PRIVATE MLLM_STUB=1)
endif()
