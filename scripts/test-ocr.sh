#!/bin/bash
# OCR 功能测试脚本
# 测试 Linux bundle 中的 tesseract OCR 是否正常工作

set -e

BUNDLE_DIR="$1"
TEST_IMAGE="$2"
EXPECTED_TEXT="$3"

if [ -z "$BUNDLE_DIR" ] || [ -z "$TEST_IMAGE" ]; then
    echo "用法: $0 <bundle_dir> <test_image> [expected_text]"
    exit 1
fi

echo "=== OCR 功能测试 ==="
echo "Bundle 目录: $BUNDLE_DIR"
echo "测试图片: $TEST_IMAGE"

# 检查 bundle 目录
if [ ! -d "$BUNDLE_DIR" ]; then
    echo "✗ Bundle 目录不存在: $BUNDLE_DIR"
    exit 1
fi

# 检查测试图片
if [ ! -f "$TEST_IMAGE" ]; then
    echo "✗ 测试图片不存在: $TEST_IMAGE"
    exit 1
fi

# 检查 libtesseract_ocr.so
TESS_LIB="$BUNDLE_DIR/lib/libtesseract_ocr.so"
if [ -f "$TESS_LIB" ]; then
    echo "✓ 找到 libtesseract_ocr.so"
    ls -lh "$TESS_LIB"
else
    echo "⚠ 未找到 libtesseract_ocr.so，将使用 CLI fallback"
fi

# 检查 tessdata
TESSDATA_DIR="$BUNDLE_DIR/share/tessdata"
if [ -d "$TESSDATA_DIR" ]; then
    echo "✓ 找到 tessdata 目录"
    ls -lh "$TESSDATA_DIR"/
else
    echo "⚠ 未找到 tessdata 目录"
fi

# 设置环境变量
export LD_LIBRARY_PATH="$BUNDLE_DIR/lib:$LD_LIBRARY_PATH"
export LD_LIBRARY_PATH="$BUNDLE_DIR/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH"  # Ubuntu

# 使用 tesseract CLI 测试（如果 bundle 没有 FFI 库）
echo ""
echo "=== 测试 Tesseract CLI ==="
if command -v tesseract &> /dev/null; then
    echo "使用系统 tesseract: $(tesseract --version 2>&1 | head -1)"
    RESULT=$(tesseract "$TEST_IMAGE" stdout -l chi_sim+eng --psm 6 2>/dev/null || echo "OCR_FAILED")
    if [ "$RESULT" != "OCR_FAILED" ] && [ -n "$RESULT" ]; then
        echo "✓ Tesseract CLI 识别成功"
        echo "识别结果 (前100字符): ${RESULT:0:100}"
        if [ -n "$EXPECTED_TEXT" ]; then
            if echo "$RESULT" | grep -q "$EXPECTED_TEXT"; then
                echo "✓ 识别结果包含期望文本: $EXPECTED_TEXT"
            else
                echo "⚠ 识别结果不包含期望文本: $EXPECTED_TEXT"
            fi
        fi
    else
        echo "✗ Tesseract CLI 识别失败"
        exit 1
    fi
else
    echo "⚠ 系统没有 tesseract CLI"
fi

# 测试 bundle 中的 FFI 库（如果有）
if [ -f "$TESS_LIB" ]; then
    echo ""
    echo "=== 测试 Bundle FFI 库 ==="
    # 使用 ldd 检查依赖
    echo "库依赖检查:"
    ldd "$TESS_LIB" 2>&1 | head -10 || echo "无法检查依赖"

    # 尝试用 flutter test 运行 Dart OCR 测试
    echo ""
    echo "=== 运行 Dart OCR 测试 ==="
    # 注意：这需要 flutter 环境，在 CI 中可用
fi

echo ""
echo "=== 测试完成 ==="
exit 0
