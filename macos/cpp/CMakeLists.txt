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
set(TESSERACT_SYSTEM OFF)
set(LEPTONICA_SYSTEM OFF)
set(BUNDLED_TESSERACT OFF)

find_library(TESSERACT_LIBRARY tesseract)
find_library(LEPTONICA_LIBRARY leptonica)

message(STATUS "find_library TESSERACT_LIBRARY: ${TESSERACT_LIBRARY}")
message(STATUS "find_library LEPTONICA_LIBRARY: ${LEPTONICA_LIBRARY}")

# 检查是否真正找到了库（find_library 失败时返回 Tesseract_LIBRARY-NOTFOUND）
set(TESS_SYSTEM_FOUND ON)
if(NOT TESSERACT_LIBRARY OR TESSERACT_LIBRARY MATCHES "NOTFOUND" OR
   NOT LEPTONICA_LIBRARY OR LEPTONICA_LIBRARY MATCHES "NOTFOUND")
    set(TESS_SYSTEM_FOUND OFF)
endif()

message(STATUS "TESS_SYSTEM_FOUND: ${TESS_SYSTEM_FOUND}")

if(TESS_SYSTEM_FOUND)
    set(TESSERACT_SYSTEM ON)
    # 获取库所在目录
    get_filename_component(TESSERACT_LIB_DIR "${TESSERACT_LIBRARY}" DIRECTORY)
    get_filename_component(LEPTONICA_LIB_DIR "${LEPTONICA_LIBRARY}" DIRECTORY)
    # 设置 include 目录（用于 tesseract_ocr wrapper）
    set(LEPTONICA_INSTALL_DIR "${LEPTONICA_LIB_DIR}/..")
    set(TESSERACT_INSTALL_DIR "${TESSERACT_LIB_DIR}/..")
    message(STATUS "Found system Tesseract: ${TESSERACT_LIBRARY}")
    message(STATUS "Found system Leptonica: ${LEPTONICA_LIBRARY}")
else()
    # 检查源码是否存在
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
        set(BUNDLED_TESSERACT ON)

        # 本地安装前缀
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
            set(ENABLE_TESSERACT OFF)
        endif()

        if(ENABLE_TESSERACT)
            execute_process(
                COMMAND cmake --build ${CMAKE_CURRENT_BINARY_DIR}/leptonica_build --config Release -j4
                RESULT_VARIABLE RESULT
            )
            if(RESULT)
                message(WARNING "Leptonica build failed")
                set(ENABLE_TESSERACT OFF)
            endif()
        endif()

        if(ENABLE_TESSERACT)
            execute_process(
                COMMAND cmake --install ${CMAKE_CURRENT_BINARY_DIR}/leptonica_build --config Release
                RESULT_VARIABLE RESULT
            )
            if(RESULT)
                message(WARNING "Leptonica install failed")
                set(ENABLE_TESSERACT OFF)
            endif()
        endif()

        # 设置路径让 Tesseract 能够找到
        set(Leptonica_DIR "${LEPTONICA_INSTALL_DIR}/lib/cmake/leptonica")
        set(CMAKE_PREFIX_PATH "${LEPTONICA_INSTALL_DIR};${CMAKE_PREFIX_PATH}")
        message(STATUS "Leptonica installed to ${LEPTONICA_INSTALL_DIR}")

        # 构建并安装 Tesseract
        if(ENABLE_TESSERACT)
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
                set(ENABLE_TESSERACT OFF)
            endif()
        endif()

        if(ENABLE_TESSERACT)
            execute_process(
                COMMAND cmake --build ${CMAKE_CURRENT_BINARY_DIR}/tesseract_build --config Release -j4
                RESULT_VARIABLE RESULT
            )
            if(RESULT)
                message(WARNING "Tesseract build failed")
                set(ENABLE_TESSERACT OFF)
            endif()
        endif()

        if(ENABLE_TESSERACT)
            execute_process(
                COMMAND cmake --install ${CMAKE_CURRENT_BINARY_DIR}/tesseract_build --config Release
                RESULT_VARIABLE RESULT
            )
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

# ===== 构建 tesseract_ocr 封装库（统一入口） =====
message(STATUS "=== tesseract_ocr creation: ENABLE_TESSERACT=${ENABLE_TESSERACT}, BUNDLED_TESSERACT=${BUNDLED_TESSERACT} ===")
if(ENABLE_TESSERACT)
    if(BUNDLED_TESSERACT)
        # 链接到本地安装的 dylib
        set(TESSERACT_OCR_LIBS
            "${LEPTONICA_INSTALL_DIR}/lib/libleptonica.dylib"
            "${LEPTONICA_INSTALL_DIR}/lib/libtesseract.dylib"
        )
    else()
        # 链接到系统库
        set(TESSERACT_OCR_LIBS ${TESSERACT_LIBRARY} ${LEPTONICA_LIBRARY})
    endif()

    add_library(tesseract_ocr SHARED tesseract_ocr.cpp)
    target_include_directories(tesseract_ocr PRIVATE
        ${LEPTONICA_INSTALL_DIR}/include
        ${TESSERACT_DIR}/include
    )
    target_link_libraries(tesseract_ocr PRIVATE ${TESSERACT_OCR_LIBS})
    set_target_properties(tesseract_ocr PROPERTIES
        INSTALL_NAME_DIR "@rpath"
        BUILD_RPATH "@loader_path"
        INSTALL_RPATH "@loader_path"
    )

    # 安装 tesseract_ocr 到 CMAKE_INSTALL_PREFIX/lib
    install(TARGETS tesseract_ocr LIBRARY DESTINATION lib COMPONENT runtime)

    # 如果是 bundled 模式，安装依赖的 dylib
    if(BUNDLED_TESSERACT)
        install(FILES
            "${LEPTONICA_INSTALL_DIR}/lib/libleptonica.dylib"
            "${LEPTONICA_INSTALL_DIR}/lib/libtesseract.dylib"
            DESTINATION lib COMPONENT runtime
        )
    endif()

    message(STATUS "=== tesseract_ocr wrapper built (bundled=${BUNDLED_TESSERACT}) ===")
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

if(ENABLE_TESSERACT)
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
