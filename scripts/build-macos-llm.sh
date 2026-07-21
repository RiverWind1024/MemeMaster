#!/bin/bash
# 构建 macOS 原生 LLM 库（Metal GPU 加速版本）
# 用法: ./scripts/build-macos-llm.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LLM_DIR="$PROJECT_DIR/macos/cpp"
BUILD_DIR="$PROJECT_DIR/build/macos-llm"

echo "=== Building macOS meme_llm with Metal GPU support ==="

# 清理旧构建
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

cd "$BUILD_DIR"

# 跨平台 CPU 核心数（macOS 没 nproc）
if command -v nproc >/dev/null 2>&1; then
    NPROC=$(nproc)
elif command -v sysctl >/dev/null 2>&1; then
    NPROC=$(sysctl -n hw.ncpu)
else
    NPROC=4
fi
echo "Using $NPROC parallel jobs"

# 配置 CMake（使用系统 Metal 框架）
# 允许通过 ENABLE_METAL 环境变量关闭（CI macos-cpu 用）
ENABLE_METAL_FLAG="${ENABLE_METAL:-ON}"
echo "=== cmake configure (ENABLE_METAL=$ENABLE_METAL_FLAG) ==="
cmake "$LLM_DIR" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$BUILD_DIR/install" \
    -DENABLE_METAL="$ENABLE_METAL_FLAG" \
    -DTESSERACT_DIR="${TESSERACT_DIR:-$PROJECT_DIR/third_party/tesseract}" \
    -DLEPTONICA_DIR="${LEPTONICA_DIR:-$PROJECT_DIR/third_party/leptonica}" 2>&1

# 构建
echo "=== cmake build ==="
cmake --build . --config Release -j"$NPROC" 2>&1 | tail -50

# 安装（将 tesseract_ocr 等库安装到 CMAKE_INSTALL_PREFIX）
echo "=== cmake install ==="
cmake --install . --config Release 2>&1 | tail -20

# 检查产物
if [ -f "install/lib/libmeme_llm.dylib" ]; then
    SIZE=$(ls -lh install/lib/libmeme_llm.dylib | awk '{print $5}')
    echo "=== Build successful ==="
    echo "  Output: $BUILD_DIR/install/lib/libmeme_llm.dylib"
    echo "  Size: $SIZE"

    # 检查 Metal 符号
    if nm install/lib/libmeme_llm.dylib 2>/dev/null | grep -q ggml_metal; then
        echo "  Metal GPU: ENABLED (ggml_metal symbols found)"
    else
        echo "  Metal GPU: WARNING - no ggml_metal symbols found"
    fi
elif [ -f "libmeme_llm.dylib" ]; then
    SIZE=$(ls -lh libmeme_llm.dylib | awk '{print $5}')
    echo "=== Build successful (legacy location) ==="
    echo "  Output: $BUILD_DIR/libmeme_llm.dylib"
    echo "  Size: $SIZE"
else
    echo "ERROR: Build failed - libmeme_llm.dylib not found"
    echo "=== Build directory contents ==="
    find . -name "*.dylib" -type f 2>/dev/null | head -20
    exit 1
fi

echo "=== All dylib files in build tree ==="
find . -name "*.dylib" -type f 2>/dev/null | head -20
