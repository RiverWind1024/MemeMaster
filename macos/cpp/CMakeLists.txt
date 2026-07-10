cmake_minimum_required(VERSION 3.22.1)
project(meme_llm C CXX)

set(CMAKE_BUILD_PARALLEL_LEVEL 4)

# ===== llama.cpp 路径配置 =====
if(NOT DEFINED LLAMA_CPP_DIR)
    if(DEFINED ENV{LLAMA_CPP_DIR})
        set(LLAMA_CPP_DIR $ENV{LLAMA_CPP_DIR})
    else()
        set(LLAMA_CPP_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../../third_party/llama.cpp")
    endif()
endif()

# ===== Metal GPU 加速选项 =====
option(ENABLE_METAL "Enable Metal GPU acceleration (macOS only)" ON)

# ===== 检查 llama.cpp =====
if(NOT EXISTS "${LLAMA_CPP_DIR}/CMakeLists.txt")
    message(FATAL_ERROR "llama.cpp not found at ${LLAMA_CPP_DIR}. Run ./scripts/init-third-party.sh first")
endif()

# ===== 静态库配置 =====
set(CMAKE_POSITION_INDEPENDENT_CODE ON)
set(BUILD_SHARED_LIBS OFF)
set(GGML_STATIC ON)
set(LLAMA_STATIC ON)
set(GGML_SHARED OFF)
set(LLAMA_SHARED OFF)
set(LLAMA_BUILD_TESTS OFF)
set(LLAMA_BUILD_EXAMPLES OFF)
set(LLAMA_BUILD_SERVER OFF)
set(LLAMA_INSTALL_VERSION "0.0.0")

# ===== Metal 配置 =====
if(APPLE AND ENABLE_METAL)
    set(GGML_METAL ON)
    set(GGML_METAL_EMBED_LIBRARY ON)
    set(GGML_METAL_USE_BF16 ON)
    set(GGML_BLAS_DEFAULT ON)

    # 查找 Metal 框架
    find_library(FOUNDATION_LIBRARY Foundation REQUIRED)
    find_library(METAL_FRAMEWORK Metal REQUIRED)
    find_library(METALKIT_FRAMEWORK MetalKit REQUIRED)
    find_library(ACCELERATE_FRAMEWORK Accelerate REQUIRED)

    message(STATUS "Metal GPU acceleration enabled")
    message(STATUS "  GGML_METAL: ${GGML_METAL}")
    message(STATUS "  GGML_METAL_EMBED_LIBRARY: ${GGML_METAL_EMBED_LIBRARY}")
    message(STATUS "  Metal frameworks found: Foundation, Metal, MetalKit, Accelerate")
endif()

# ===== 添加子项目 =====
add_subdirectory(${LLAMA_CPP_DIR} llama.cpp EXCLUDE_FROM_ALL)

# ===== 头文件路径 =====
include_directories(
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${LLAMA_CPP_DIR}/include
    ${LLAMA_CPP_DIR}/ggml/include
)

# ===== 构建共享库 =====
add_library(meme_llm SHARED meme_llm.cpp)

# ===== 链接库 =====
set(MEME_LLM_LIBS llama ggml mtmd pthread dl m)

if(APPLE AND ENABLE_METAL)
    list(APPEND MEME_LLM_LIBS
        ${FOUNDATION_LIBRARY}
        ${METAL_FRAMEWORK}
        ${METALKIT_FRAMEWORK}
        ${ACCELERATE_FRAMEWORK}
    )
endif()

target_link_libraries(meme_llm PRIVATE ${MEME_LLM_LIBS})
target_link_options(meme_llm PRIVATE -Wl,-soname,libmeme_llm.so.1)

# ===== 安装规则 =====
install(TARGETS meme_llm LIBRARY DESTINATION lib COMPONENT runtime)
install(FILES meme_llm.cpp DESTINATION include COMPONENT headers RENAME meme_llm.h)

message(STATUS "=== meme_llm build configuration (macOS) ===")
message(STATUS "LLAMA_CPP_DIR: ${LLAMA_CPP_DIR}")
message(STATUS "ENABLE_METAL: ${ENABLE_METAL}")
message(STATUS "=================================================")
