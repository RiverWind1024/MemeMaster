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
        message(STATUS "Building Tesseract OCR from source (fully static bundling)")

        # 使用本地安装前缀（类似 macOS 的处理方式）
        set(LOCAL_PREFIX "${CMAKE_CURRENT_BINARY_DIR}/local")
        set(LEPTONICA_INSTALL_DIR "${LOCAL_PREFIX}")
        set(DEPS_PREFIX "${LOCAL_PREFIX}/deps")

        # =========================================================
        # 阶段 1：从源码构建所有依赖库（-fPIC 静态编译）
        # 这样二进制自带所有依赖，不依赖系统库，跨发行版兼容
        # =========================================================
        message(STATUS "=== Building bundled dependencies (libjpeg, zlib, libpng, libtiff, giflib) ===")

        set(_DEPS_STATUS 0)

        macro(BUILD_DEPS_LIB NAME URL DIR)
            # tarball 顶层目录是 ${DIR}，解压到 deps_src 后就是 deps_src/${DIR}/
            set(_src_dir "${CMAKE_CURRENT_BINARY_DIR}/deps_src/${DIR}")
            set(_build_dir "${CMAKE_CURRENT_BINARY_DIR}/deps_build/${DIR}")
            set(_inst_dir "${DEPS_PREFIX}")
            set(_tarball "${CMAKE_CURRENT_BINARY_DIR}/${DIR}.tar.gz")

            if(NOT EXISTS "${_inst_dir}/lib/lib${NAME}.a")
                message(STATUS "  Fetching ${NAME}...")
                file(MAKE_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/deps_src")
                file(MAKE_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/deps_build")
                # 用 curl download（-L 跟随重定向，--fail 非零退出）
                execute_process(
                    COMMAND curl -L --fail --retry 3 --retry-delay 2
                        -o "${_tarball}"
                        "${URL}"
                    WORKING_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}"
                    RESULT_VARIABLE _rv
                    TIMEOUT 120
                )
                message(STATUS "  ${NAME} curl result: ${_rv}")
                if(_rv EQUAL 0 AND EXISTS "${_tarball}")
                    message(STATUS "  ${NAME} tarball downloaded")
                    # cmake -E tar 解压到 deps_src（顶层目录保留为 ${DIR}）
                    execute_process(
                        COMMAND /usr/bin/cmake -E tar xzf "${_tarball}"
                        WORKING_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/deps_src"
                        RESULT_VARIABLE _rv
                    )
                    message(STATUS "  ${NAME} extract result: ${_rv}")
                else()
                    message(WARNING "  ${NAME} download failed")
                    set(_rv 1)
                endif()
                if(_rv EQUAL 0 AND EXISTS "${_src_dir}/CMakeLists.txt")
                    message(STATUS "  ${NAME} configuring (src=${_src_dir})...")
                    file(MAKE_DIRECTORY "${_build_dir}")
                    execute_process(
                        COMMAND /usr/bin/cmake -S ${_src_dir} -B ${_build_dir}
                            -DCMAKE_BUILD_TYPE=Release
                            -DCMAKE_INSTALL_PREFIX=${_inst_dir}
                            -DCMAKE_POSITION_INDEPENDENT_CODE=ON
                            -DBUILD_SHARED_LIBS=OFF
                        WORKING_DIRECTORY ${_build_dir}
                        RESULT_VARIABLE _rv
                    )
                    message(STATUS "  ${NAME} configure result: ${_rv}")
                else()
                    message(WARNING "  ${NAME} source not found at ${_src_dir}, skipping")
                    set(_rv 1)
                endif()
                if(_rv EQUAL 0)
                    execute_process(
                        COMMAND /usr/bin/cmake --build "${_build_dir}" --config Release -j4
                        WORKING_DIRECTORY "${_build_dir}"
                        RESULT_VARIABLE _rv
                    )
                    message(STATUS "  ${NAME} build result: ${_rv}")
                endif()
                if(_rv EQUAL 0)
                    execute_process(
                        COMMAND /usr/bin/cmake --install "${_build_dir}" --config Release
                        WORKING_DIRECTORY "${_build_dir}"
                        RESULT_VARIABLE _rv
                    )
                    message(STATUS "  ${NAME} install result: ${_rv}")
                endif()
                if(_rv)
                    message(WARNING "  ${NAME} build failed (${_rv}), OCR may not work")
                else()
                    message(STATUS "  ${NAME} built successfully")
                endif()
            else()
                message(STATUS "  ${NAME} already built, skipping")
            endif()
            if(_rv)
                set(_DEPS_STATUS ${_rv})
            endif()
        endmacro()

        # libjpeg-turbo（codeload URL 直接指向 tar.gz，无重定向）
        BUILD_DEPS_LIB(jpeg-turbo
            "https://codeload.github.com/libjpeg-turbo/libjpeg-turbo/tar.gz/2.1.5.1"
            "libjpeg-turbo-2.1.5.1")

        # zlib
        BUILD_DEPS_LIB(z
            "https://zlib.net/zlib-1.3.1.tar.gz"
            "zlib-1.3.1")

        # libpng
        BUILD_DEPS_LIB(png
            "https://codeload.github.com/pnggroup/libpng/tar.gz/v1.6.47"
            "libpng-1.6.47")

        # libtiff
        BUILD_DEPS_LIB(tiff
            "https://codeload.github.com/libsdl-org/libtiff/tar.gz/v4.7.0"
            "libtiff-4.7.0")

        # giflib 不构建（GIF 不是 OCR 必需格式，禁掉避免 SourceForge 下载问题）
        message(STATUS "  Skipping giflib (GIF not needed for OCR)")

        # 修复：创建符号链接，让库文件名与 Leptonica/Tesseract 的 find_library 期望一致
        # libjpeg-turbo 的实际静态库文件名是 libturbojpeg.a / libjpeg.a（不是 libjpeg-turbo.a）
        # Leptonica find_library(NAMES jpeg turbojpeg) 找到 libjpeg.a（我们的 symlink）
        execute_process(
            COMMAND /usr/bin/cmake -E create_symlink libturbojpeg.a libjpeg.a
            WORKING_DIRECTORY "${DEPS_PREFIX}/lib"
        )
        execute_process(
            COMMAND /usr/bin/cmake -E create_symlink libturbojpeg.so libjpeg.so
            WORKING_DIRECTORY "${DEPS_PREFIX}/lib"
        )
        # libpng: Leptonica 找 libpng，但实际文件是 libpng16.a（soname 版本）
        execute_process(
            COMMAND /usr/bin/cmake -E create_symlink libpng16.a libpng.a
            WORKING_DIRECTORY "${DEPS_PREFIX}/lib"
        )
        execute_process(
            COMMAND /usr/bin/cmake -E create_symlink libpng16.so libpng.so
            WORKING_DIRECTORY "${DEPS_PREFIX}/lib"
        )

        # 清理临时压缩包
        file(REMOVE "${CMAKE_CURRENT_BINARY_DIR}/libjpeg-turbo-2.1.5.1.tar.gz"
                    "${CMAKE_CURRENT_BINARY_DIR}/zlib-1.3.1.tar.gz"
                    "${CMAKE_CURRENT_BINARY_DIR}/libpng-1.6.47.tar.gz"
                    "${CMAKE_CURRENT_BINARY_DIR}/libtiff-4.7.0.tar.gz"
                    2>/dev/null)

        # =========================================================
        # 阶段 2：构建 Leptonica（使用我们构建的依赖库）
        # =========================================================
        message(STATUS "=== Building Leptonica ===")

        # 设置依赖搜索路径（指向我们构建的版本）
        set(CMAKE_PREFIX_PATH "${DEPS_PREFIX};${CMAKE_PREFIX_PATH}")
        link_directories("${DEPS_PREFIX}/lib")

        execute_process(
            COMMAND cmake -S ${LEPTONICA_DIR} -B ${CMAKE_CURRENT_BINARY_DIR}/leptonica_build
                -DCMAKE_BUILD_TYPE=Release
                -DCMAKE_INSTALL_PREFIX=${LEPTONICA_INSTALL_DIR}
                -DCMAKE_POSITION_INDEPENDENT_CODE=ON
                -DBUILD_SHARED_LIBS=OFF
                -DBUILD_PROGRAMS=OFF
                -DBUILD_TESTS=OFF
                -DBUILD_DOCS=OFF
                -DENABLE_GIF=OFF
                -DENABLE_WEBP=OFF
                -DENABLE_OPENJPEG=OFF
                # 明确指向我们构建的库（使用实际文件名：libjpeg.a, libpng16.a）
                -DJPEG_LIBRARY="${DEPS_PREFIX}/lib/libjpeg.a"
                -DJPEG_INCLUDE_DIR="${DEPS_PREFIX}/include"
                -DJPEG_LIBRARY_DIR="${DEPS_PREFIX}/lib"
                -DPNG_LIBRARY="${DEPS_PREFIX}/lib/libpng16.a"
                -DPNG_PNG_INCLUDE_DIR="${DEPS_PREFIX}/include"
                -DPNG_LIBRARY_DIR="${DEPS_PREFIX}/lib"
                -DTIFF_LIBRARY="${DEPS_PREFIX}/lib/libtiff.a"
                -DTIFF_INCLUDE_DIR="${DEPS_PREFIX}/include"
                -DTIFF_LIBRARY_DIR="${DEPS_PREFIX}/lib"
                -DZLIB_LIBRARY="${DEPS_PREFIX}/lib/libz.a"
                -DZLIB_INCLUDE_DIR="${DEPS_PREFIX}/include"
                -DZLIB_LIBRARY_DIR="${DEPS_PREFIX}/lib"
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

        # =========================================================
        # 阶段 3：构建并安装 Tesseract
        # =========================================================
        if(NOT RESULT)
            message(STATUS "=== Building Tesseract ===")
            execute_process(
                COMMAND cmake -S ${TESSERACT_DIR} -B ${CMAKE_CURRENT_BINARY_DIR}/tesseract_build
                    -DCMAKE_BUILD_TYPE=Release
                    -DCMAKE_INSTALL_PREFIX=${LEPTONICA_INSTALL_DIR}
                    -DCMAKE_POSITION_INDEPENDENT_CODE=ON
                    -DLeptonica_DIR=${Leptonica_DIR}
                    -DBUILD_SHARED_LIBS=OFF
                    -DBUILD_PROGRAMS=OFF
                    -DBUILD_TRAINING_TOOLS=OFF
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

        # =========================================================
        # 阶段 4：构建 tesseract_ocr 封装库（链接我们构建的所有静态库）
        # =========================================================
        if(NOT RESULT AND BUNDLED_TESSERACT)
            message(STATUS "=== Building tesseract_ocr wrapper ===")

            # 用 find_library 找到每个库的完整路径，CMake 会正确处理 -L/-l 参数
            find_library(JPEG_LIBRARY NAMES jpeg turbojpeg PATHS "${DEPS_PREFIX}/lib" NO_DEFAULT_PATH)
            find_library(PNG_LIBRARY NAMES png PATHS "${DEPS_PREFIX}/lib" NO_DEFAULT_PATH)
            find_library(TIFF_LIBRARY NAMES tiff PATHS "${DEPS_PREFIX}/lib" NO_DEFAULT_PATH)
            find_library(ZLIB_LIBRARY NAMES z PATHS "${DEPS_PREFIX}/lib" NO_DEFAULT_PATH)

            if(NOT JPEG_LIBRARY OR NOT PNG_LIBRARY OR NOT TIFF_LIBRARY OR NOT ZLIB_LIBRARY)
                message(WARNING "Some deps libraries not found: JPEG=${JPEG_LIBRARY} PNG=${PNG_LIBRARY} TIFF=${TIFF_LIBRARY} ZLIB=${ZLIB_LIBRARY}")
            endif()

            add_library(tesseract_ocr SHARED tesseract_ocr.cpp)
            target_include_directories(tesseract_ocr PRIVATE
                ${DEPS_PREFIX}/include
                ${LEPTONICA_INSTALL_DIR}/include
                ${TESSERACT_DIR}/include
            )
            target_link_libraries(tesseract_ocr PRIVATE
                "${LEPTONICA_INSTALL_DIR}/lib/libtesseract.a"
                "${LEPTONICA_INSTALL_DIR}/lib/libleptonica.a"
                ${JPEG_LIBRARY}
                ${PNG_LIBRARY}
                ${TIFF_LIBRARY}
                ${ZLIB_LIBRARY}
                pthread dl m
            )
            set_target_properties(tesseract_ocr PROPERTIES
                BUILD_RPATH "$ORIGIN"
                INSTALL_RPATH "$ORIGIN"
            )
            set(TESSERACT_OCR_TARGET tesseract_ocr)

            # 安装 tesseract_ocr
            install(TARGETS tesseract_ocr LIBRARY DESTINATION lib COMPONENT runtime)
            message(STATUS "=== tesseract_ocr wrapper built (fully static, self-contained) ===")
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

if(TESSERACT_OCR_LIBS AND NOT TESSERACT_OCR_TARGET)
    add_library(tesseract_ocr SHARED tesseract_ocr.cpp)
    target_link_libraries(tesseract_ocr PRIVATE ${TESSERACT_OCR_LIBS})
    target_link_options(tesseract_ocr PRIVATE -Wl,-soname,libtesseract_ocr.so.1)
    set(TESSERACT_OCR_TARGET tesseract_ocr)
elseif(NOT TESSERACT_OCR_TARGET)
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
