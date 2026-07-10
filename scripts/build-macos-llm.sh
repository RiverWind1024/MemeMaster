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

# 配置 CMake（使用系统 Metal 框架）
cmake "$LLM_DIR" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX="$BUILD_DIR/install" \
    -DENABLE_METAL=ON

# 构建
cmake --build . --config Release -j$(nproc)

# 检查产物
if [ -f "libmeme_llm.dylib" ]; then
    SIZE=$(ls -lh libmeme_llm.dylib | awk '{print $5}')
    echo "=== Build successful ==="
    echo "  Output: $BUILD_DIR/libmeme_llm.dylib"
    echo "  Size: $SIZE"

    # 检查 Metal 符号
    if nm libmeme_llm.dylib 2>/dev/null | grep -q ggml_metal; then
        echo "  Metal GPU: ENABLED (ggml_metal symbols found)"
    else
        echo "  Metal GPU: WARNING - no ggml_metal symbols found"
    fi
else
    echo "ERROR: Build failed - libmeme_llm.dylib not found"
    exit 1
fi
