cmake_minimum_required(VERSION 3.22.1)
project(meme_llm C CXX)

set(CMAKE_BUILD_PARALLEL_LEVEL 4)

# ===== 依赖路径配置 =====
if(NOT DEFINED LLAMA_CPP_DIR)
    if(DEFINED ENV{LLAMA_CPP_DIR})
        set(LLAMA_CPP_DIR $ENV{LLAMA_CPP_DIR})
    else()
        set(LLAMA_CPP_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../../third_party/llama.cpp")
    endif()
endif()

set(MTMD_DIR "${LLAMA_CPP_DIR}/tools/mtmd")

# 检查 llama.cpp 是否存在
if(NOT EXISTS "${LLAMA_CPP_DIR}/CMakeLists.txt")
    message(STATUS "llama.cpp not found at ${LLAMA_CPP_DIR}")
    message(STATUS "本地 LLM 功能将被禁用。用户可运行 ./scripts/init-third-party.sh 后重新构建")
    add_library(meme_llm_empty SHARED meme_llm.cpp)
    target_compile_definitions(meme_llm_empty PRIVATE MLLM_STUB=1)
    return()
endif()

message(STATUS "llama.cpp found at ${LLAMA_CPP_DIR}, enabling local LLM support")

# ===== GPU 后端检测 =====
option(ENABLE_VULKAN "Enable Vulkan backend" ON)
option(ENABLE_OPENCL "Enable OpenCL backend" OFF)
option(ENABLE_CUDA "Enable CUDA backend (requires CUDA toolkit)" OFF)

find_package(PkgConfig REQUIRED)
pkg_check_modules(GTK3 REQUIRED gtk+-3.0)
pkg_check_modules(VULKAN vulkan)

# Vulkan 需要 glslc (shader compiler)
if(ENABLE_VULKAN AND VULKAN_FOUND)
    find_program(GLSLC_EXECUTABLE NAMES glslc)
    if(NOT GLSLC_EXECUTABLE)
        message(WARNING "glslc not found - Vulkan GPU acceleration disabled")
        set(ENABLE_VULKAN OFF)
    else()
        message(STATUS "glslc found: ${GLSLC_EXECUTABLE}")
    endif()
endif()

# 检查 OpenCL (可选)
if(ENABLE_OPENCL)
    pkg_check_modules(OPENCL OpenCL)
    if(NOT OPENCL_FOUND)
        message(WARNING "OpenCL not found - OpenCL backend disabled")
        set(ENABLE_OPENCL OFF)
    endif()
endif()

# 如果没有可用的 GPU 后端，回退到 stub
if(NOT ENABLE_VULKAN AND NOT ENABLE_OPENCL AND NOT ENABLE_CUDA)
    message(STATUS "No GPU backend available, building CPU-only stub")
    add_library(meme_llm_empty SHARED meme_llm.cpp)
    target_compile_definitions(meme_llm_empty PRIVATE MLLM_STUB=1)
    return()
endif()

# ===== llama.cpp 子项目配置 =====
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

set(GGML_VULKAN ${ENABLE_VULKAN})
set(GGML_OPENCL ${ENABLE_OPENCL})
set(GGML_CUDA ${ENABLE_CUDA})

# ===== 系统依赖 =====
if(VULKAN_FOUND)
    list(APPEND MEME_LLM_LIBS Vulkan::Vulkan)
endif()

if(OPENCL_FOUND)
    list(APPEND MEME_LLM_LIBS ${OPENCL_LIBRARIES})
endif()

# ===== 添加 llama.cpp 和 mtmd 子项目 =====
add_subdirectory(${LLAMA_CPP_DIR} llama.cpp EXCLUDE_FROM_ALL)
add_subdirectory(${MTMD_DIR} mtmd EXCLUDE_FROM_ALL)

# ===== 头文件路径 =====
include_directories(
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${LLAMA_CPP_DIR}/include
    ${LLAMA_CPP_DIR}/ggml/include
    ${MTMD_DIR}
)

# ===== 链接库 =====
set(MEME_LLM_LIBS
    llama
    ggml
    mtmd
    pthread
    dl
    m
)

# ===== 构建共享库 =====
add_library(meme_llm SHARED meme_llm.cpp)

target_link_libraries(meme_llm PRIVATE ${MEME_LLM_LIBS})

target_link_options(meme_llm PRIVATE -Wl,-soname,libmeme_llm.so.1)

# ===== 安装规则 =====
install(TARGETS meme_llm LIBRARY DESTINATION lib COMPONENT runtime)
install(FILES meme_llm.cpp DESTINATION include COMPONENT headers RENAME meme_llm.h)

message(STATUS "=== meme_llm build configuration ===")
message(STATUS "LLAMA_CPP_DIR: ${LLAMA_CPP_DIR}")
message(STATUS "ENABLE_VULKAN: ${ENABLE_VULKAN}")
message(STATUS "ENABLE_OPENCL: ${ENABLE_OPENCL}")
message(STATUS "Vulkan: ${VULKAN_FOUND}")
message(STATUS "OpenCL: ${OPENCL_FOUND}")
message(STATUS "================================")
