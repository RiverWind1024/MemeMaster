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

# ===== GPU 后端选项 (Phase 2: Vulkan GPU 加速) =====
option(ENABLE_VULKAN "Enable Vulkan backend" ON)
option(ENABLE_OPENCL "Enable OpenCL backend" OFF)
option(ENABLE_CUDA "Enable CUDA backend (requires CUDA toolkit)" OFF)

# ===== Windows 线程支持 =====
find_package(Threads REQUIRED)

# ===== 检查 llama.cpp =====
if(NOT EXISTS "${LLAMA_CPP_DIR}/CMakeLists.txt")
    message(STATUS "llama.cpp not found at ${LLAMA_CPP_DIR}")
    message(STATUS "本地 LLM 功能将被禁用。用户可运行 ./scripts/init-third-party.sh 后重新构建")
    add_library(meme_llm_empty SHARED meme_llm.cpp)
    target_compile_definitions(meme_llm_empty PRIVATE MLLM_STUB=1)
    return()
endif()

message(STATUS "llama.cpp found at ${LLAMA_CPP_DIR}, enabling local LLM support")

# ===== 无 GPU 后端时回退到 stub (Phase 1 CPU-only) =====
if(NOT ENABLE_VULKAN AND NOT ENABLE_OPENCL AND NOT ENABLE_CUDA)
    message(STATUS "No GPU backend available, building CPU-only stub")
    add_library(meme_llm_empty SHARED meme_llm.cpp)
    target_compile_definitions(meme_llm_empty PRIVATE MLLM_STUB=1)
    return()
endif()

# ===== llama.cpp 子项目配置 =====
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
set(MTMD_VIDEO OFF)

set(GGML_VULKAN ${ENABLE_VULKAN})
set(GGML_OPENCL ${ENABLE_OPENCL})
set(GGML_CUDA ${ENABLE_CUDA})
set(GGML_OPENMP OFF)

# ===== 链接库 (Windows) =====
set(MEME_LLM_LIBS llama ggml mtmd Threads::Threads)

# ===== 添加子项目 =====
add_subdirectory(${LLAMA_CPP_DIR} llama.cpp EXCLUDE_FROM_ALL)
add_subdirectory(${MTMD_DIR} mtmd EXCLUDE_FROM_ALL)

# ===== 头文件路径 =====
include_directories(
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${LLAMA_CPP_DIR}/include
    ${LLAMA_CPP_DIR}/ggml/include
    ${MTMD_DIR}
)

# ===== 构建共享库 (Windows DLL) =====
add_library(meme_llm SHARED meme_llm.cpp)
target_link_libraries(meme_llm PRIVATE ${MEME_LLM_LIBS})

# ===== Tesseract DLLs (pre-built, loaded via FFI at runtime) =====
set(TESSERACT_DLL_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../../third_party/tesseract-dlls")
if(EXISTS "${TESSERACT_DLL_DIR}")
    message(STATUS "Tesseract DLLs found at ${TESSERACT_DLL_DIR}")
    file(GLOB TESSERACT_DLLS "${TESSERACT_DLL_DIR}/*.dll")
    if(TESSERACT_DLLS)
        message(STATUS "Found ${TESSERACT_DLLS} Tesseract DLLs")
    else()
        message(STATUS "No DLLs found in ${TESSERACT_DLL_DIR}")
    endif()
else()
    message(STATUS "Tesseract DLLs not found at ${TESSERACT_DLL_DIR}")
    message(STATUS "OCR 功能将使用系统 Tesseract（如果可用）")
endif()

# ===== 安装规则 =====
install(TARGETS meme_llm LIBRARY DESTINATION lib COMPONENT runtime)
install(FILES meme_llm.cpp DESTINATION include COMPONENT headers RENAME meme_llm.h)

# ===== Tesseract DLL 安装规则 =====
if(EXISTS "${TESSERACT_DLL_DIR}")
    file(GLOB TESSERACT_DLLS "${TESSERACT_DLL_DIR}/*.dll")
    if(TESSERACT_DLLS)
        install(FILES ${TESSERACT_DLLS} DESTINATION bin COMPONENT runtime)
    endif()
endif()

message(STATUS "=== meme_llm build configuration (Windows) ===")
message(STATUS "LLAMA_CPP_DIR: ${LLAMA_CPP_DIR}")
message(STATUS "ENABLE_VULKAN: ${ENABLE_VULKAN}")
message(STATUS "ENABLE_OPENCL: ${ENABLE_OPENCL}")
message(STATUS "TESSERACT_DLL_DIR: ${TESSERACT_DLL_DIR}")
message(STATUS "================================")
