#!/bin/bash
# =================================────────────────
# 第三方依赖初始化脚本
# 用法: ./scripts/init-third-party.sh
#
# 功能: 自动克隆、构建项目所需的 C++ 依赖库
# 优先级: GitHub > gh-proxy.org > Gitee
# CI 中直接用 GitHub；都失败则提示用户在本地运行
# =========================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
THIRD_PARTY="$PROJECT_ROOT/third_party"

# 检测 Android NDK
ANDROID_NDK="${ANDROID_NDK:-}"
if [ -z "$ANDROID_NDK" ]; then
    # 尝试自动检测 NDK 路径
    for ndk_path in "$HOME/Software/android-sdk/ndk"/*/; do
        if [ -d "$ndk_path" ]; then
            ANDROID_NDK="$ndk_path"
            break
        fi
    done
fi

if [ -z "$ANDROID_NDK" ] || [ ! -d "$ANDROID_NDK" ]; then
    echo "警告: 未检测到 Android NDK，OpenCL-ICD-Loader 的交叉编译将跳过"
    echo "请设置 ANDROID_NDK 环境变量指向 NDK 目录"
    echo "例如: export ANDROID_NDK=/home/username/Software/android-sdk/ndk/28.2.13676358"
fi

# 日志颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

# 尝试克隆一个仓库，失败时尝试 fallback
clone_with_fallback() {
    local name="$1"
    local github_url="$2"
    local gitee_url="$3"
    local dir="$THIRD_PARTY/$name"

    # 已存在且是有效的 git 仓库: 跳过
    if [ -d "$dir/.git" ]; then
        log_success "$name already exists"
        return 0
    fi

    # 目录存在但缺少 .git/ (可能是手动放置的副本或克隆中断残留)
    # 警告并重新克隆,以保证状态一致
    if [ -d "$dir" ]; then
        log_warn "$name 目录存在但缺少 .git/,将重新克隆 (原数据会丢失)"
        rm -rf "$dir"
    fi

    # 优先使用 GitHub 直接下载（GitHub Actions 可以访问 GitHub）
    echo "Cloning $name from GitHub..."
    if git clone --depth 1 "$github_url" "$dir" 2>&1; then
        log_success "$name cloned from GitHub"
        return 0
    fi

    # GitHub 失败时尝试 gh-proxy.org（国内加速）
    local proxy_url="https://gh-proxy.org/$github_url"
    echo "Cloning $name via gh-proxy.org..."
    if git clone --depth 1 "$proxy_url" "$dir" 2>&1; then
        log_success "$name cloned via gh-proxy.org"
        return 0
    fi

    # 最后尝试 Gitee
    if [ -n "$gitee_url" ]; then
        echo "Cloning $name from Gitee..."
        if git clone --depth 1 "$gitee_url" "$dir" 2>&1; then
            log_success "$name cloned from Gitee"
            return 0
        fi
    fi

    # 都失败了
    log_error "$name clone failed from all sources"
    echo ""
    echo "请在本地运行以下命令完成初始化（需开启代理）："
    echo "  ./scripts/init-third-party.sh"
    echo ""
    echo "完成后 push 到 GitHub 即可触发 CI 构建。"
    return 1
}

# 构建 SPIRV-Headers
# 注意: install_dir 路径需与 linux/cpp/CMakeLists.txt 中的查找路径一致
build_spirv_headers() {
    local spirv_dir="$THIRD_PARTY/SPIRV-Headers"
    local install_dir="$THIRD_PARTY/spirv-headers-install"  # 与 CMakeLists.txt 查找路径一致

    if [ -d "$install_dir" ] && [ -f "$install_dir/share/cmake/SPIRV-Headers/SPIRV-HeadersConfig.cmake" ]; then
        log_success "SPIRV-Headers already built and installed"
        return 0
    fi

    log_info "Building SPIRV-Headers..."

    if [ ! -d "$spirv_dir" ]; then
        log_error "SPIRV-Headers not found at $spirv_dir"
        return 1
    fi

    mkdir -p "$spirv_dir/build"
    cd "$spirv_dir/build"

    cmake .. \
        -DCMAKE_INSTALL_PREFIX="$install_dir" \
        -DSPIRV_HEADERS_SKIP_EXAMPLES=ON

    cmake --build . --target install

    if [ -f "$install_dir/share/cmake/SPIRV-Headers/SPIRV-HeadersConfig.cmake" ]; then
        log_success "SPIRV-Headers built and installed to $install_dir"
        return 0
    else
        log_error "SPIRV-Headers build failed"
        return 1
    fi
}

# 构建 OpenCL-ICD-Loader for Android
build_opencl_icd_loader() {
    local icd_dir="$THIRD_PARTY/OpenCL-ICD-Loader"
    local build_dir="$icd_dir/build_ndk"
    local headers_dir="$THIRD_PARTY/OpenCL-Headers"
    
    if [ -f "$build_dir/libOpenCL.so" ]; then
        log_success "OpenCL-ICD-Loader already built for Android"
        return 0
    fi
    
    if [ -z "$ANDROID_NDK" ] || [ ! -d "$ANDROID_NDK" ]; then
        log_warn "Android NDK not found, skipping OpenCL-ICD-Loader build"
        log_warn "Set ANDROID_NDK environment variable to build OpenCL-ICD-Loader"
        return 0
    fi
    
    log_info "Building OpenCL-ICD-Loader for Android..."
    
    if [ ! -d "$icd_dir" ]; then
        log_error "OpenCL-ICD-Loader not found at $icd_dir"
        return 1
    fi
    
    if [ ! -d "$headers_dir" ]; then
        log_error "OpenCL-Headers not found at $headers_dir"
        return 1
    fi
    
    mkdir -p "$build_dir"
    cd "$build_dir"
    
    # 设置 Android 交叉编译工具链
    local cmake_toolchain="$ANDROID_NDK/build/cmake/android.toolchain.cmake"
    
    cmake .. \
        -DCMAKE_TOOLCHAIN_FILE="$cmake_toolchain" \
        -DANDROID_ABI=arm64-v8a \
        -DANDROID_PLATFORM=android-26 \
        -DANDROID_STL=c++_static \
        -DOPENCL_ICD_LOADER_HEADERS_DIR="$headers_dir" \
        -DBUILD_TESTING=OFF \
        -DBUILD_SHARED_LIBS=ON
    
    cmake --build . --target OpenCL
    
    if [ -f "$build_dir/libOpenCL.so" ]; then
        log_success "OpenCL-ICD-Loader built for Android at $build_dir/libOpenCL.so"
        return 0
    else
        log_error "OpenCL-ICD-Loader build failed"
        return 1
    fi
}

# 主流程
echo "=========================================="
echo "初始化第三方依赖"
echo "=========================================="
echo ""

# 创建第三方依赖目录
mkdir -p "$THIRD_PARTY"

declare -A DEPS=(
    ["llama.cpp"]="https://github.com/ggml-org/llama.cpp.git||"
    ["OpenCL-Headers"]="https://github.com/KhronosGroup/OpenCL-Headers.git||"
    ["OpenCL-ICD-Loader"]="https://github.com/KhronosGroup/OpenCL-ICD-Loader.git||"
    ["SPIRV-Headers"]="https://github.com/KhronosGroup/SPIRV-Headers.git||"
    ["Vulkan-Headers"]="https://github.com/LunarG/VulkanHeaders.git||"
)

FAILED=()

for name in "${!DEPS[@]}"; do
    # 分割 GitHub URL 和 Gitee URL（使用 || 分隔符避免 URL 中的 : 干扰）
    IFS='||' read -r github_url gitee_url <<< "${DEPS[$name]}"
    
    if ! clone_with_fallback "$name" "$github_url" "$gitee_url"; then
        FAILED+=("$name")
    fi
done

# 报告克隆结果
if [ ${#FAILED[@]} -gt 0 ]; then
    echo ""
    log_error "以下依赖获取失败，请手动处理："
    echo ""
    for name in "${FAILED[@]}"; do
        github_url="${DEPS[$name]%%:*}"
        echo "  - $name"
        echo "    GitHub: $github_url"
        echo ""
    done
    echo "手动克隆示例："
    echo "  git clone --depth 1 ${DEPS[llama.cpp]%%:*} third_party/llama.cpp"
    echo ""
    echo "如果是网络问题，可以："
    echo "  1. 配置 Git 代理: git config --global http.proxy http://127.0.0.1:7890"
    echo "  2. 或使用 Gitee 镜像（需要自行创建）"
    echo "=========================================="
    exit 1
fi

echo ""
log_success "所有依赖获取成功！"
echo ""

# 构建 SPIRV-Headers
echo "=========================================="
echo "构建 SPIRV-Headers"
echo "=========================================="
echo ""
if build_spirv_headers; then
    log_success "SPIRV-Headers 构建完成"
else
    log_warn "SPIRV-Headers 构建失败，Vulkan 后端可能无法使用"
fi

echo ""

# 构建 OpenCL-ICD-Loader
echo "=========================================="
echo "构建 OpenCL-ICD-Loader (Android)"
echo "=========================================="
echo ""
if build_opencl_icd_loader; then
    log_success "OpenCL-ICD-Loader 构建完成"
else
    log_warn "OpenCL-ICD-Loader 构建失败，OpenCL 后端可能无法使用"
fi

echo ""
echo "=========================================="
log_success "第三方依赖初始化完成！"
echo ""
echo "依赖目录: $THIRD_PARTY"
echo "=========================================="
