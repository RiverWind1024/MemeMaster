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

# OpenCL 支持（默认关闭，实验性功能）
# 启用需要：
# 1. 运行 ./scripts/init-third-party.sh 下载 OpenCL-Headers
# 2. 设置 ANDROID_NDK 环境变量指向 NDK 目录
# 3. 运行 third_party/OpenCL-Headers/scripts/ci_build.sh 或手动交叉编译 ICD Loader
# 注意：OpenCL 后端尚未在真实设备上验证，仅 Snapdragon 8 Gen 3/Elite 等高端芯片可能支持
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

    # GPU 加速后端选择（默认关闭，需手动启用）
    # 注意：Android 上 OpenCL 仅支持 Snapdragon 8 Gen 3/Elite 等高端芯片
    # Vulkan 在 Android 上通常比 CPU 慢，不建议使用
    set(GGML_OPENCL ${ENABLE_OPENCL})
    set(GGML_VULKAN ${ENABLE_VULKAN})

    # 强制静态链接所有后端（避免运行时加载失败）
    set(GGML_OPENCL_EMBED_KERNELS ON)
    set(GGML_OPENCL_USE_ADRENO_KERNELS ON)

    # OpenCL 头文件和库路径
    if(ENABLE_OPENCL)
        # 头文件路径
        set(OPENCL_HEADERS_DIR "${LLAMA_CPP_DIR}/../OpenCL-Headers")
        if(EXISTS "${OPENCL_HEADERS_DIR}/CL/opencl.h")
            message(STATUS "OpenCL headers found at ${OPENCL_HEADERS_DIR}")
            include_directories(${OPENCL_HEADERS_DIR})
        else()
            message(WARNING "OpenCL headers not found at ${OPENCL_HEADERS_DIR}. GPU acceleration may not work.")
        endif()
        
        # OpenCL ICD Loader 库路径（预编译的 Android 库）
        set(OPENCL_ICD_LOADER_DIR "${LLAMA_CPP_DIR}/../OpenCL-ICD-Loader")
        set(OPENCL_LIB_PATH "${OPENCL_ICD_LOADER_DIR}/build_ndk/libOpenCL.so")
        if(EXISTS "${OPENCL_LIB_PATH}")
            message(STATUS "OpenCL ICD Loader found at ${OPENCL_LIB_PATH}")
            # 将预编译的 libOpenCL.so 复制到输出目录，以便打包进 APK
            set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -L${OPENCL_ICD_LOADER_DIR}/build_ndk")
        else()
            message(WARNING "OpenCL ICD Loader not found at ${OPENCL_LIB_PATH}. Trying system OpenCL...")
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
    
    # 基础链接库
    set(MEME_LLM_LIBS llama ggml mtmd android log)
    
    # 为 OpenCL 添加链接库
    if(ENABLE_OPENCL)
        # 首先尝试使用预编译的 OpenCL ICD Loader
        set(OPENCL_ICD_LOADER_DIR "${LLAMA_CPP_DIR}/../OpenCL-ICD-Loader")
        set(OPENCL_LIB_PATH "${OPENCL_ICD_LOADER_DIR}/build_ndk/libOpenCL.so")
        if(EXISTS "${OPENCL_LIB_PATH}")
            message(STATUS "Linking against prebuilt OpenCL ICD Loader: ${OPENCL_LIB_PATH}")
            list(APPEND MEME_LLM_LIBS ${OPENCL_LIB_PATH})
        else()
            # 回退到系统 OpenCL
            find_library(OpenCL_LIB OpenCL)
            if(OpenCL_LIB)
                message(STATUS "Linking against system OpenCL: ${OpenCL_LIB}")
                list(APPEND MEME_LLM_LIBS ${OpenCL_LIB})
            else()
                # 最后尝试 NDK 中的 OpenCL stub
                find_library(OpenCL_LIB NAMES OpenCL PATHS 
                    ${ANDROID_NDK}/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android
                    NO_DEFAULT_PATH)
                if(OpenCL_LIB)
                    message(STATUS "Linking against NDK OpenCL stub: ${OpenCL_LIB}")
                    list(APPEND MEME_LLM_LIBS ${OpenCL_LIB})
                endif()
            endif()
        endif()
    endif()
    
    target_link_libraries(meme_llm ${MEME_LLM_LIBS})
else()
    add_library(meme_llm SHARED meme_llm.cpp)
    target_compile_definitions(meme_llm PRIVATE MLLM_STUB=1)
endif()
