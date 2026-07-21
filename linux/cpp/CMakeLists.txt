cmake_minimum_required(VERSION 3.22.1)
project(meme_llm C CXX)

set(CMAKE_BUILD_PARALLEL_LEVEL 4)

# ===== 依赖路径配置 =====
# 支持环境变量覆盖默认路径
if(NOT DEFINED LLAMA_CPP_DIR)
    if(DEFINED ENV{LLAMA_CPP_DIR})
        set(LLAMA_CPP_DIR $ENV{LLAMA_CPP_DIR})
    else()
        set(LLAMA_CPP_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../../third_party/llama.cpp")
    endif()
endif()

set(MTMD_DIR "${LLAMA_CPP_DIR}/tools/mtmd")

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

# ===== GPU 后端选项 =====
option(ENABLE_VULKAN "Enable Vulkan backend" ON)
option(ENABLE_OPENCL "Enable OpenCL backend" OFF)
option(ENABLE_CUDA "Enable CUDA backend (requires CUDA toolkit)" OFF)

# ===== SPIRV-Headers 配置 =====
if(NOT DEFINED SPIRV_HEADERS_DIR)
    if(DEFINED ENV{SPIRV_HEADERS_DIR})
        set(SPIRV_HEADERS_DIR $ENV{SPIRV_HEADERS_DIR})
    elseif(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/../../../third_party/spirv-headers-install")
        set(SPIRV_HEADERS_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../../third_party/spirv-headers-install")
    endif()
endif()

if(SPIRV_HEADERS_DIR)
    list(APPEND CMAKE_PREFIX_PATH "${SPIRV_HEADERS_DIR}")
    # 同时添加 include 路径，Vulkan 后端直接 #include <spirv/unified1/spirv.hpp>
    include_directories("${SPIRV_HEADERS_DIR}/include")
    message(STATUS "SPIRV_HEADERS_DIR: ${SPIRV_HEADERS_DIR}")
endif()

# ===== 系统依赖检测 =====
find_package(PkgConfig REQUIRED)
pkg_check_modules(GTK3 REQUIRED gtk+-3.0)
pkg_check_modules(VULKAN vulkan)

find_library(TESSERACT_LIBRARY tesseract)
find_library(LEPTONICA_LIBRARY leptonica)
if(TESSERACT_LIBRARY AND LEPTONICA_LIBRARY)
    set(TESSERACT_SYSTEM ON)
    message(STATUS "Found system Tesseract: ${TESSERACT_LIBRARY}")
    message(STATUS "Found system Leptonica: ${LEPTONICA_LIBRARY}")
else()
    set(TESSERACT_SYSTEM OFF)
    message(STATUS "System Tesseract/Leptonica not found, will build from source")
endif()

# ===== glslc 着色器编译器查找 =====
# 优先级: 1) GLSLC_DIR 环境变量  2) PATH 中的 glslc  3) NDK 默认位置
if(ENABLE_VULKAN AND VULKAN_FOUND)
    set(GLSLC_FOUND FALSE)

    # 尝试环境变量指定路径
    if(DEFINED ENV{GLSLC_DIR})
        set(GLSLC_SEARCH_PATHS "$ENV{GLSLC_DIR}")
        message(STATUS "Looking for glslc in GLSLC_DIR: $ENV{GLSLC_DIR}")
    endif()

    # 尝试 NDK 默认位置
    if(NOT GLSLC_FOUND AND DEFINED ENV{ANDROID_NDK})
        set(NDK_GLSLC "$ENV{ANDROID_NDK}/shader-tools/linux-x86_64/glslc")
        if(EXISTS "${NDK_GLSLC}")
            list(APPEND GLSLC_SEARCH_PATHS "${NDK_GLSLC}")
        endif()
    endif()

    # 尝试 PATH
    find_program(GLSLC_EXECUTABLE NAMES glslc PATHS ${GLSLC_SEARCH_PATHS} NO_DEFAULT_PATH)
    if(NOT GLSLC_EXECUTABLE)
        find_program(GLSLC_EXECUTABLE NAMES glslc)
    endif()

    if(NOT GLSLC_EXECUTABLE)
        message(WARNING "glslc not found - Vulkan GPU acceleration disabled")
        set(ENABLE_VULKAN OFF)
    else()
        message(STATUS "glslc found: ${GLSLC_EXECUTABLE}")
        # 将 glslc 所在目录添加到 PATH，供 llama.cpp 的 cmake 使用
        get_filename_component(GLSLC_BIN_DIR "${GLSLC_EXECUTABLE}" DIRECTORY)
        file(MAKE_DIRECTORY "${GLSLC_BIN_DIR}")  # 确保目录存在
        set(ENV{PATH} "${GLSLC_BIN_DIR}:$ENV{PATH}")
    endif()
endif()

# ===== OpenCL 配置 =====
if(ENABLE_OPENCL)
    pkg_check_modules(OPENCL OpenCL)
    if(NOT OPENCL_FOUND)
        message(WARNING "OpenCL not found - OpenCL backend disabled")
        set(ENABLE_OPENCL OFF)
    endif()
endif()

# ===== 检查 llama.cpp =====
if(NOT EXISTS "${LLAMA_CPP_DIR}/CMakeLists.txt")
    message(STATUS "llama.cpp not found at ${LLAMA_CPP_DIR}")
    message(STATUS "本地 LLM 功能将被禁用。用户可运行 ./scripts/init-third-party.sh 后重新构建")
    add_library(meme_llm_empty SHARED meme_llm.cpp)
    target_compile_definitions(meme_llm_empty PRIVATE MLLM_STUB=1)
    return()
endif()

message(STATUS "llama.cpp found at ${LLAMA_CPP_DIR}, enabling local LLM support")

# ===== 无 GPU 后端时回退到 stub =====
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

# ===== 链接库 =====
set(MEME_LLM_LIBS llama ggml mtmd pthread dl m)

if(VULKAN_FOUND)
    list(APPEND MEME_LLM_LIBS ${VULKAN_LIBRARIES})
endif()

if(OPENCL_FOUND)
    list(APPEND MEME_LLM_LIBS ${OPENCL_LIBRARIES})
endif()

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

# ===== 构建共享库 =====
add_library(meme_llm SHARED meme_llm.cpp)
target_link_libraries(meme_llm PRIVATE ${MEME_LLM_LIBS})
target_link_options(meme_llm PRIVATE -Wl,-soname,libmeme_llm.so.1)

# ===== Tesseract OCR =====
if(NOT TESSERACT_SYSTEM)
    if(EXISTS "${LEPTONICA_DIR}/CMakeLists.txt" AND EXISTS "${TESSERACT_DIR}/CMakeLists.txt")
        message(STATUS "Building Tesseract OCR from source")

        # 使用本地安装前缀（类似 macOS 的处理方式）
        set(LOCAL_PREFIX "${CMAKE_CURRENT_BINARY_DIR}/local")
        set(LEPTONICA_INSTALL_DIR "${LOCAL_PREFIX}")

        # 构建并安装 Leptonica
        message(STATUS "=== Building Leptonica ===")
        execute_process(
            COMMAND cmake -S ${LEPTONICA_DIR} -B ${CMAKE_CURRENT_BINARY_DIR}/leptonica_build
                -DCMAKE_BUILD_TYPE=Release
                -DCMAKE_INSTALL_PREFIX=${LEPTONICA_INSTALL_DIR}
                -DBUILD_SHARED_LIBS=ON
                -DBUILD_STATIC_LIBS=OFF
                -DBUILD_PROGRAMS=OFF
                -DBUILD_TESTS=OFF
                -DBUILD_DOCS=OFF
                -DLEPTONICA_BUILD_PROGRAMS=OFF
                -DLEPTONICA_BUILD_TESTS=OFF
                -DLEPTONICA_USING_PNG=ON
                -DLEPTONICA_USING_JPEG=ON
                -DLEPTONICA_USING_TIFF=ON
                -DLEPTONICA_USING_GIF=ON
                -DLEPTONICA_USING_WEBP=ON
            WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
            RESULT_VARIABLE RESULT
        )
        if(RESULT)
            message(WARNING "Leptonica configure failed")
            set(TESSERACT_OCR_LIBS "")
            set(BUNDLED_TESSERACT OFF)
        endif()

        if(NOT RESULT)
            execute_process(
                COMMAND cmake --build ${CMAKE_CURRENT_BINARY_DIR}/leptonica_build --config Release -j4
                RESULT_VARIABLE RESULT
            )
            if(RESULT)
                message(WARNING "Leptonica build failed")
                set(TESSERACT_OCR_LIBS "")
                set(BUNDLED_TESSERACT OFF)
            endif()
        endif()

        if(NOT RESULT)
            execute_process(
                COMMAND cmake --install ${CMAKE_CURRENT_BINARY_DIR}/leptonica_build --config Release
                RESULT_VARIABLE RESULT
            )
            if(RESULT)
                message(WARNING "Leptonica install failed")
                set(TESSERACT_OCR_LIBS "")
                set(BUNDLED_TESSERACT OFF)
            else()
                set(BUNDLED_TESSERACT ON)
            endif()
        endif()

        # 设置 Leptonica cmake config 路径
        set(Leptonica_DIR "${LEPTONICA_INSTALL_DIR}/lib/cmake/leptonica")
        set(CMAKE_PREFIX_PATH "${LEPTONICA_INSTALL_DIR};${CMAKE_PREFIX_PATH}")
        message(STATUS "Leptonica installed to ${LEPTONICA_INSTALL_DIR}")

        # 构建并安装 Tesseract
        if(NOT RESULT)
            message(STATUS "=== Building Tesseract ===")
            execute_process(
                COMMAND cmake -S ${TESSERACT_DIR} -B ${CMAKE_CURRENT_BINARY_DIR}/tesseract_build
                    -DCMAKE_BUILD_TYPE=Release
                    -DCMAKE_INSTALL_PREFIX=${LEPTONICA_INSTALL_DIR}
                    -DLeptonica_DIR=${Leptonica_DIR}
                    -DBUILD_SHARED_LIBS=ON
                    -DBUILD_STATIC_LIBS=OFF
                    -DBUILD_PROGRAMS=OFF
                    -DBUILD_TRAININGTOOLS=OFF
                    -DBUILD_DOCS=OFF
                    -DENABLE_TESSERACT_REDISTRIBUTABLE=OFF
                    -DOPENMP_BUILD=OFF
                WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
                RESULT_VARIABLE RESULT
            )
            if(RESULT)
                message(WARNING "Tesseract configure failed")
                set(BUNDLED_TESSERACT OFF)
            endif()
        endif()

        if(NOT RESULT)
            execute_process(
                COMMAND cmake --build ${CMAKE_CURRENT_BINARY_DIR}/tesseract_build --config Release -j4
                RESULT_VARIABLE RESULT
            )
            if(RESULT)
                message(WARNING "Tesseract build failed")
                set(BUNDLED_TESSERACT OFF)
            endif()
        endif()

        if(NOT RESULT)
            execute_process(
                COMMAND cmake --install ${CMAKE_CURRENT_BINARY_DIR}/tesseract_build --config Release
                RESULT_VARIABLE RESULT
            )
            if(RESULT)
                message(WARNING "Tesseract install failed")
                set(BUNDLED_TESSERACT OFF)
            endif()
        endif()

        # 构建 tesseract_ocr 封装库
        if(NOT RESULT AND BUNDLED_TESSERACT)
            message(STATUS "=== Building tesseract_ocr wrapper ===")
            add_library(tesseract_ocr SHARED tesseract_ocr.cpp)
            target_include_directories(tesseract_ocr PRIVATE
                ${LEPTONICA_INSTALL_DIR}/include
                ${TESSERACT_DIR}/include
            )
            target_link_libraries(tesseract_ocr PRIVATE
                "${LEPTONICA_INSTALL_DIR}/lib/libleptonica.so"
                "${LEPTONICA_INSTALL_DIR}/lib/libtesseract.so"
            )
            set_target_properties(tesseract_ocr PROPERTIES
                BUILD_RPATH "$ORIGIN"
                INSTALL_RPATH "$ORIGIN"
            )
            set(TESSERACT_OCR_TARGET tesseract_ocr)

            # 安装 tesseract_ocr 和依赖库
            install(TARGETS tesseract_ocr LIBRARY DESTINATION lib COMPONENT runtime)
            install(FILES
                "${LEPTONICA_INSTALL_DIR}/lib/libleptonica.so"
                "${LEPTONICA_INSTALL_DIR}/lib/libtesseract.so"
                DESTINATION lib COMPONENT runtime
            )
            message(STATUS "=== tesseract_ocr wrapper built and installed ===")
        else()
            message(WARNING "Tesseract OCR build failed, will use CLI fallback")
            set(TESSERACT_OCR_TARGET "")
        endif()
    else()
        message(WARNING "Tesseract or Leptonica not found at configured paths")
        message(WARNING "LEPTONICA_DIR: ${LEPTONICA_DIR}")
        message(WARNING "TESSERACT_DIR: ${TESSERACT_DIR}")
        message(WARNING "Tesseract OCR 功能将被禁用（将回退到命令行 tesseract）")
        set(TESSERACT_OCR_LIBS "")
        set(TESSERACT_OCR_TARGET "")
    endif()
else()
    set(TESSERACT_OCR_LIBS ${TESSERACT_LIBRARY} ${LEPTONICA_LIBRARY} pthread dl m)
endif()

if(TESSERACT_OCR_LIBS)
    add_library(tesseract_ocr SHARED tesseract_ocr.cpp)
    target_link_libraries(tesseract_ocr PRIVATE ${TESSERACT_OCR_LIBS})
    target_link_options(tesseract_ocr PRIVATE -Wl,-soname,libtesseract_ocr.so.1)
    set(TESSERACT_OCR_TARGET tesseract_ocr)
else()
    message(STATUS "Skipping tesseract_ocr library build (no Tesseract/Leptonica)")
    set(TESSERACT_OCR_TARGET "")
endif()

# ===== 安装规则 =====
install(TARGETS meme_llm ${TESSERACT_OCR_TARGET} LIBRARY DESTINATION lib COMPONENT runtime)
install(FILES meme_llm.cpp DESTINATION include COMPONENT headers RENAME meme_llm.h)
if(TESSERACT_OCR_TARGET)
    install(FILES tesseract_ocr.h DESTINATION include COMPONENT headers)
endif()

message(STATUS "=== meme_llm build configuration ===")
message(STATUS "LLAMA_CPP_DIR: ${LLAMA_CPP_DIR}")
message(STATUS "SPIRV_HEADERS_DIR: ${SPIRV_HEADERS_DIR}")
message(STATUS "ENABLE_VULKAN: ${ENABLE_VULKAN}")
message(STATUS "ENABLE_OPENCL: ${ENABLE_OPENCL}")
message(STATUS "GLSLC_EXECUTABLE: ${GLSLC_EXECUTABLE}")
message(STATUS "Vulkan: ${VULKAN_FOUND}")
message(STATUS "OpenCL: ${OPENCL_FOUND}")
message(STATUS "Tesseract system: ${TESSERACT_SYSTEM}")
message(STATUS "Tesseract: ${TESSERACT_DIR}")
message(STATUS "Leptonica: ${LEPTONICA_DIR}")
message(STATUS "================================")
