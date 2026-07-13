# vulkan-android-prelude.cmake
# ============================================================
# Android Vulkan 预加载配置
# 由 gradle 通过 CMAKE_PROJECT_INCLUDE_BEFORE 注入到 llama.cpp 配置之前
#
# 自动处理：
# - libvulkan.so 路径（按 ABI 选 API 29 版本，包含 Vulkan 1.1 符号）
# - vulkan.hpp 头文件路径（来自 third_party/Vulkan-Headers）
# - SPIRV-Headers 路径（用于 spirv/unified1/spirv.hpp）
# ============================================================

if(NOT ANDROID)
    return()
endif()

# 定位 NDK
if(NOT DEFINED ANDROID_NDK)
    if(DEFINED ENV{ANDROID_NDK})
        set(ANDROID_NDK $ENV{ANDROID_NDK})
    endif()
endif()

if(NOT DEFINED ANDROID_NDK OR NOT EXISTS "${ANDROID_NDK}")
    message(WARNING "ANDROID_NDK not set; Vulkan Android config skipped")
    return()
endif()

# 按 ABI 选 libvulkan.so
# 必须用 API 29+（包含 Vulkan 1.1 函数如 vkGetPhysicalDeviceFeatures2）
set(_vulkan_min_api 29)
set(_vulkan_candidates "")
if(CMAKE_ANDROID_ARCH_ABI STREQUAL "arm64-v8a")
    list(APPEND _vulkan_candidates
        "${ANDROID_NDK}/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android/${_vulkan_min_api}/libvulkan.so"
    )
elseif(CMAKE_ANDROID_ARCH_ABI STREQUAL "x86_64")
    list(APPEND _vulkan_candidates
        "${ANDROID_NDK}/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/x86_64-linux-android/${_vulkan_min_api}/libvulkan.so"
    )
elseif(CMAKE_ANDROID_ARCH_ABI STREQUAL "armeabi-v7a")
    list(APPEND _vulkan_candidates
        "${ANDROID_NDK}/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/arm-linux-androideabi/${_vulkan_min_api}/libvulkan.so"
    )
elseif(CMAKE_ANDROID_ARCH_ABI STREQUAL "x86")
    list(APPEND _vulkan_candidates
        "${ANDROID_NDK}/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/i686-linux-android/${_vulkan_min_api}/libvulkan.so"
    )
endif()

set(_vulkan_lib "")
foreach(_candidate IN LISTS _vulkan_candidates)
    if(EXISTS "${_candidate}")
        set(_vulkan_lib "${_candidate}")
        break()
    endif()
endforeach()

if(_vulkan_lib)
    # 关键：set CACHE 让 find_library 跳过查找
    set(Vulkan_LIBRARY "${_vulkan_lib}" CACHE FILEPATH "Vulkan library (Android ABI-correct)" FORCE)
    message(STATUS "Vulkan Android: ${Vulkan_LIBRARY}")
endif()

# Vulkan-Headers 头文件路径（vulkan.hpp）
set(_vulkan_headers_search_paths
    "${CMAKE_CURRENT_SOURCE_DIR}/../../../third_party/Vulkan-Headers/include"
    "${CMAKE_CURRENT_SOURCE_DIR}/../../third_party/Vulkan-Headers/include"
    "${PROJECT_SOURCE_DIR}/third_party/Vulkan-Headers/include"
    "${PROJECT_SOURCE_DIR}/../third_party/Vulkan-Headers/include"
)
foreach(_vpath IN LISTS _vulkan_headers_search_paths)
    if(EXISTS "${_vpath}/vulkan/vulkan.hpp")
        set(Vulkan_INCLUDE_DIR "${_vpath}" CACHE PATH "Vulkan headers (vulkan.hpp)" FORCE)
        message(STATUS "Vulkan Android headers: ${Vulkan_INCLUDE_DIR}")
        break()
    endif()
endforeach()

# SPIRV-Headers：通过 cmake config 查找（gradle 已传 -DSPIRV-Headers_DIR）
# 这里只设置 fallback
if(NOT DEFINED SPIRV-Headers_DIR)
    set(_spirv_candidates
        "${CMAKE_CURRENT_SOURCE_DIR}/../../../third_party/spirv-headers-install/share/cmake/SPIRV-Headers"
        "${CMAKE_CURRENT_SOURCE_DIR}/../../third_party/spirv-headers-install/share/cmake/SPIRV-Headers"
        "${PROJECT_SOURCE_DIR}/third_party/spirv-headers-install/share/cmake/SPIRV-Headers"
    )
    foreach(_spath IN LISTS _spirv_candidates)
        if(EXISTS "${_spath}/SPIRV-HeadersConfig.cmake")
            set(SPIRV-Headers_DIR "${_spath}" CACHE PATH "SPIRV-Headers config dir" FORCE)
            message(STATUS "SPIRV-Headers: ${SPIRV-Headers_DIR}")
            break()
        endif()
    endforeach()
endif()