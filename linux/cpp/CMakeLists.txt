cmake_minimum_required(VERSION 3.22.1)
project(meme_llm C CXX)

set(CMAKE_BUILD_PARALLEL_LEVEL 4)

# ===== 依赖路径配置 =====
if(NOT DEFINED LLAMA_CPP_DIR)
    if(DEFINED ENV{LLAMA_CPP_DIR})
        set(LLAMA_CPP_DIR $ENV{LLAMA_CPP_DIR})
    else()
        # 默认路径：third_party/llama.cpp (与 Android 相同布局)
        set(LLAMA_CPP_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../../third_party/llama.cpp")
    endif()
endif()

# mtmd 路径
set(MTMD_DIR "${LLAMA_CPP_DIR}/tools/mtmd")

if(NOT EXISTS "${LLAMA_CPP_DIR}/CMakeLists.txt")
    message(FATAL_ERROR "llama.cpp not found at ${LLAMA_CPP_DIR}. Run ./scripts/init-third-party.sh first.")
endif()

# ===== 构建选项 =====
option(ENABLE_VULKAN "Enable Vulkan backend" ON)
option(ENABLE_OPENCL "Enable OpenCL backend" ON)
option(ENABLE_CUDA "Enable CUDA backend (requires CUDA toolkit)" OFF)

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

# GPU 后端
set(GGML_VULKAN ${ENABLE_VULKAN})
set(GGML_OPENCL ${ENABLE_OPENCL})
set(GGML_CUDA ${ENABLE_CUDA})

# ===== 系统依赖 =====
find_package(PkgConfig REQUIRED)
pkg_check_modules(GTK3 REQUIRED gtk+-3.0)
pkg_check_modules(VULKAN REQUIRED vulkan)
pkg_check_modules(OPENCL REQUIRED OpenCL)

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

# Vulkan
if(ENABLE_VULKAN AND VULKAN_FOUND)
    message(STATUS "Vulkan found, enabling GPU acceleration")
    list(APPEND MEME_LLM_LIBS Vulkan::Vulkan)
else()
    message(WARNING "Vulkan not found, GPU acceleration disabled")
endif()

# OpenCL
if(ENABLE_OPENCL AND OPENCL_FOUND)
    message(STATUS "OpenCL found, enabling OpenCL backend")
    list(APPEND MEME_LLM_LIBS ${OPENCL_LIBRARIES})
    include_directories(${OPENCL_INCLUDE_DIRS})
else()
    message(WARNING "OpenCL not found, OpenCL backend disabled")
endif()

# ===== 构建共享库 =====
add_library(meme_llm SHARED meme_llm.cpp)

target_link_libraries(meme_llm PRIVATE ${MEME_LLM_LIBS})

# 设置索引进口点
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
