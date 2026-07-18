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

# ===== Tesseract/Leptonica 路径配置 =====
if(NOT DEFINED TESSERACT_DIR)
    if(DEFINED ENV{TESSERACT_DIR})
        set(TESSERACT_DIR $ENV{TESSERACT_DIR})
    else()
        set(TESSERACT_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../../third_party/tesseract")
    endif()
endif()

if(NOT DEFINED LEPTONICA_DIR)
    if(DEFINED ENV{LEPTONICA_DIR})
        set(LEPTONICA_DIR $ENV{LEPTONICA_DIR})
    else()
        set(LEPTONICA_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../../third_party/leptonica")
    endif()
endif()

# ===== Metal GPU 加速选项 =====
option(ENABLE_METAL "Enable Metal GPU acceleration (macOS only)" ON)

# ===== Tesseract OCR 选项 =====
option(ENABLE_TESSERACT "Enable Tesseract OCR" ON)

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
set(GGML_METAL OFF)
if(APPLE AND ENABLE_METAL)
    set(GGML_METAL ON)
    set(GGML_METAL_EMBED_LIBRARY ON)
    set(GGML_METAL_USE_BF16 ON)
    set(GGML_BLAS_DEFAULT ON)

    find_library(FOUNDATION_LIBRARY Foundation REQUIRED)
    find_library(METAL_FRAMEWORK Metal REQUIRED)
    find_library(METALKIT_FRAMEWORK MetalKit REQUIRED)
    find_library(ACCELERATE_FRAMEWORK Accelerate REQUIRED)

    message(STATUS "Metal GPU acceleration enabled")
    message(STATUS "  GGML_METAL: ${GGML_METAL}")
    message(STATUS "  GGML_METAL_EMBED_LIBRARY: ${GGML_METAL_EMBED_LIBRARY}")
    message(STATUS "  Metal frameworks found: Foundation, Metal, MetalKit, Accelerate")
endif()

# ===== Tesseract/Leptonica 配置 =====
if(ENABLE_TESSERACT)
    set(TESSERACT_SYSTEM OFF)
    set(LEPTONICA_SYSTEM OFF)

    find_library(TESSERACT_LIBRARY tesseract)
    find_library(LEPTONICA_LIBRARY leptonica)

    if(TESSERACT_LIBRARY AND LEPTONICA_LIBRARY)
        set(TESSERACT_SYSTEM ON)
        message(STATUS "Found system Tesseract: ${TESSERACT_LIBRARY}")
        message(STATUS "Found system Leptonica: ${LEPTONICA_LIBRARY}")
    else()
        if(NOT EXISTS "${LEPTONICA_DIR}/CMakeLists.txt")
            message(WARNING "Leptonica not found at ${LEPTONICA_DIR}. OCR will be disabled.")
            set(ENABLE_TESSERACT OFF)
        endif()

        if(NOT EXISTS "${TESSERACT_DIR}/CMakeLists.txt")
            message(WARNING "Tesseract not found at ${TESSERACT_DIR}. OCR will be disabled.")
            set(ENABLE_TESSERACT OFF)
        endif()

        if(ENABLE_TESSERACT)
            message(STATUS "Building Tesseract/Leptonica from source")
            set(BUILD_SHARED_LIBS ON)
            set(ENABLE_OPENCL OFF)
            set(ENABLE_TESSERACT_REDISTRIBUTABLE OFF)

            add_subdirectory(${LEPTONICA_DIR} leptonica EXCLUDE_FROM_ALL)
            add_subdirectory(${TESSERACT_DIR} tesseract EXCLUDE_FROM_ALL)

            list(APPEND OCR_LIBS tesseract leptonica)
        endif()
    endif()
endif()

# ===== 添加子项目 =====
add_subdirectory(${LLAMA_CPP_DIR} llama.cpp EXCLUDE_FROM_ALL)
add_subdirectory(${LLAMA_CPP_DIR}/tools/mtmd mtmd)

# ===== 头文件路径 =====
include_directories(
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${LLAMA_CPP_DIR}/include
    ${LLAMA_CPP_DIR}/ggml/include
    ${LLAMA_CPP_DIR}/tools/mtmd
)

if(ENABLE_TESSERACT)
    list(APPEND INCLUDE_DIRS ${TESSERACT_DIR}/include ${LEPTONICA_DIR}/include)
endif()

# ===== 构建 Tesseract OCR 封装库 =====
if(ENABLE_TESSERACT AND NOT TESSERACT_SYSTEM)
    add_library(tesseract_ocr SHARED tesseract_ocr.cpp)
    target_include_directories(tesseract_ocr PRIVATE ${TESSERACT_DIR}/include ${LEPTONICA_DIR}/include)
    target_link_libraries(tesseract_ocr PRIVATE tesseract leptonica)
    set_target_properties(tesseract_ocr PROPERTIES INSTALL_NAME_DIR "@rpath" BUILD_RPATH "@loader_path" INSTALL_RPATH "@loader_path")
endif()

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

if(ENABLE_TESSERACT AND NOT TESSERACT_SYSTEM)
    list(APPEND MEME_LLM_LIBS tesseract_ocr)
endif()

target_link_libraries(meme_llm PRIVATE ${MEME_LLM_LIBS})
if(APPLE)
    set_target_properties(meme_llm PROPERTIES INSTALL_NAME_DIR "@rpath" BUILD_RPATH "@loader_path" INSTALL_RPATH "@loader_path")
else()
    target_link_options(meme_llm PRIVATE -Wl,-soname,libmeme_llm.so.1)
endif()

# ===== 安装规则 =====
install(TARGETS meme_llm LIBRARY DESTINATION lib COMPONENT runtime)
install(FILES meme_llm.cpp DESTINATION include COMPONENT headers RENAME meme_llm.h)

message(STATUS "=== meme_llm build configuration (macOS) ===")
message(STATUS "LLAMA_CPP_DIR: ${LLAMA_CPP_DIR}")
message(STATUS "ENABLE_METAL: ${ENABLE_METAL}")
message(STATUS "ENABLE_TESSERACT: ${ENABLE_TESSERACT}")
message(STATUS "TESSERACT_SYSTEM: ${TESSERACT_SYSTEM}")
message(STATUS "=================================================")
