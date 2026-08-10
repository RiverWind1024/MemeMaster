#!/bin/bash
# macOS CI 上复现/定位 MemeMaster Metal 推理崩溃的冒烟测试脚本
#
# 功能:
#   1. 下载 Qwen3.5-0.8B-Q4_K_M + mmproj-F16（ModelScope 优先，HuggingFace 回退）
#   2. 用 metal_smoke_test 依次运行多组对照实验（每组独立进程，崩溃互不影响）
#   3. 每步日志 + 崩溃 backtrace 写入 RESULTS_DIR，随后收集系统 .ips 崩溃报告
#
# 环境变量:
#   MODEL_DIR    模型缓存目录（默认 $HOME/.cache/mememaster-metal-test）
#   HARNESS      metal_smoke_test 可执行文件路径
#   RESULTS_DIR  结果输出目录（默认 build/macos-metal-results）
#   SKIP_DOWNLOAD=1 跳过模型下载（使用 MODEL_DIR 已有文件）

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

MODEL_DIR="${MODEL_DIR:-$HOME/.cache/mememaster-metal-test}"
RESULTS_DIR="${RESULTS_DIR:-$PROJECT_DIR/build/macos-metal-results}"
mkdir -p "$MODEL_DIR" "$RESULTS_DIR"

# 模型下载地址（ModelScope 优先，HF 回退）
MS_BASE="https://modelscope.cn/models/unsloth/Qwen3.5-0.8B-GGUF/resolve/main"
HF_BASE="https://huggingface.co/unsloth/Qwen3.5-0.8B-GGUF/resolve/main"
MODEL_FILE="Qwen3.5-0.8B-Q4_K_M.gguf"
MMPROJ_FILE="mmproj-F16.gguf"

# 模型文件最小字节数（防止下载到错误页）
MIN_MODEL_BYTES=$((100 * 1024 * 1024))
MIN_MMPROJ_BYTES=$((50 * 1024 * 1024))

download_with_fallback() {
    # download_with_fallback <dest> <filename> <min_bytes>
    local dest="$1" fname="$2" min_bytes="$3"
    if [ -f "$dest" ]; then
        local size
        size=$(stat -f%z "$dest" 2>/dev/null || echo 0)
        if [ "$size" -ge "$min_bytes" ]; then
            echo "✓ $fname already exists ($size bytes)"
            return 0
        fi
        echo "⚠ $fname too small ($size bytes), re-downloading"
        rm -f "$dest"
    fi

    for base in "$MS_BASE" "$HF_BASE"; do
        echo "--- downloading $fname from $base ---"
        if curl -fSL --retry 3 --retry-delay 5 --connect-timeout 30 \
            --max-time 900 "$base/$fname" -o "$dest"; then
            local size
            size=$(stat -f%z "$dest" 2>/dev/null || echo 0)
            if [ "$size" -ge "$min_bytes" ]; then
                echo "✓ $fname downloaded ($size bytes)"
                return 0
            fi
            echo "⚠ $fname too small ($size bytes)"
        else
            echo "✗ download from $base failed"
        fi
        rm -f "$dest"
    done
    echo "✗✗ FAILED to download $fname from all sources"
    return 1
}

MODEL_PATH="$MODEL_DIR/$MODEL_FILE"
MMPROJ_PATH="$MODEL_DIR/$MMPROJ_FILE"

if [ "${SKIP_DOWNLOAD:-0}" != "1" ]; then
    download_with_fallback "$MODEL_PATH" "$MODEL_FILE" "$MIN_MODEL_BYTES" || exit 1
    download_with_fallback "$MMPROJ_PATH" "$MMPROJ_FILE" "$MIN_MMPROJ_BYTES" || exit 1
fi
if [ ! -f "$MODEL_PATH" ]; then echo "✗ model missing: $MODEL_PATH"; exit 1; fi
if [ ! -f "$MMPROJ_PATH" ]; then echo "✗ mmproj missing: $MMPROJ_PATH"; exit 1; fi

echo ""
echo "=== Model files ==="
ls -lh "$MODEL_PATH" "$MMPROJ_PATH"

# 定位 harness 与 dylib
# 优先项目内构建产物；若 bundle 方式分发（脚本与 harness 同目录）则用同目录
if [ -x "$PROJECT_DIR/build/macos-llm/metal_smoke_test" ]; then
    HARNESS_DEFAULT="$PROJECT_DIR/build/macos-llm/metal_smoke_test"
else
    HARNESS_DEFAULT="$SCRIPT_DIR/metal_smoke_test"
fi
HARNESS="${HARNESS:-$HARNESS_DEFAULT}"
if [ ! -x "$HARNESS" ]; then
    echo "✗ harness not found: $HARNESS"
    echo "  请先运行 scripts/build-macos-llm.sh 构建（含 metal_smoke_test 目标），"
    echo "  或用 HARNESS=/path/to/metal_smoke_test 指定"
    exit 1
fi
HARNESS_DIR="$(cd "$(dirname "$HARNESS")" && pwd)"
# dylib 可能在 harness 同目录、install/lib 或 bundle 的 ../lib 下，全部加入 DYLD_LIBRARY_PATH
INSTALL_LIB="$PROJECT_DIR/build/macos-llm/install/lib"
export DYLD_LIBRARY_PATH="$HARNESS_DIR${INSTALL_LIB:+:$INSTALL_LIB}"

echo "=== Harness: $HARNESS ==="
echo "=== DYLD_LIBRARY_PATH: $DYLD_LIBRARY_PATH ==="
"$HARNESS" --help 2>&1 | head -3

echo ""
echo "=== Metal 硬件信息 ==="
system_profiler SPHardwareDataType 2>/dev/null | grep -E "Chip|Model|Memory" | head -5 || true
system_profiler SPDisplaysDataType 2>/dev/null | grep -E "Chipset|Metal|Vendor" | head -8 || true

# ---- 对照实验 ----
# 每个 case 独立进程。先保守参数（默认 f16 kv cache、flash auto），
# 再逐步逼近 app 的实际默认参数（flash=enabled + kv_cache=q4_0 + mmap=1）。
run_case() {
    local name="$1"; shift
    local log="$RESULTS_DIR/$name.log"
    local crash="$RESULTS_DIR/$name.crash"
    local mllm_log="$RESULTS_DIR/$name-mllm.log"
    rm -f "$crash"
    echo ""
    echo "=================== CASE: $name ==================="
    echo "cmd: $HARNESS --case $name --log $mllm_log --crash-file $crash $*"
    DYLD_LIBRARY_PATH="$DYLD_LIBRARY_PATH" "$HARNESS" \
        --model "$MODEL_PATH" --mmproj "$MMPROJ_PATH" \
        --case "$name" --log "$mllm_log" --crash-file "$crash" \
        "$@" >"$log" 2>&1
    local rc=$?
    echo "[case:$name] exit=$rc"
    echo "  log: $log ($(wc -l <"$log" | tr -d ' ') lines)"
    echo "  mllm log: $mllm_log ($(wc -l <"$mllm_log" 2>/dev/null | tr -d ' ') lines)"
    grep -m1 "\[RESULT\]" "$log" || true
    if [ -s "$crash" ]; then
        echo "  ⚠ CRASH detected: $crash"
        sed 's/^/    /' "$crash"
    fi
}

# case 1: 仅诊断 + 模型加载（不推理），默认 GPU 参数
run_case init-gpu-default --gpu 1 --layers 99 --flash-attn auto --kv-cache f16 --mmap 1 --no-infer

# case 2: CPU 加载对照
run_case init-cpu --gpu 0 --no-infer

# case 3: GPU 完整推理，保守参数
run_case infer-gpu-default --gpu 1 --layers 99 --flash-attn auto --kv-cache f16 --mmap 1

# case 4: GPU + flash_attn=enabled（隔离 flash attention 影响）
run_case infer-gpu-flash-on --gpu 1 --layers 99 --flash-attn enabled --kv-cache f16 --mmap 1

# case 5: GPU + kv_cache=q4_0（隔离量化 KV cache 影响）
run_case infer-gpu-kv-q4 --gpu 1 --layers 99 --flash-attn auto --kv-cache q4_0 --mmap 1

# case 6: GPU + app 实际默认参数（flash=enabled + kv_cache=q4_0 + mmap=1 + batch 512/256）
run_case infer-gpu-app-defaults --gpu 1 --layers 99 --flash-attn enabled --kv-cache q4_0 --mmap 1 --batch 512 --ubatch 256

# case 7: CPU 完整推理对照（验证模型/数据本身没问题）
run_case infer-cpu --gpu 0 --flash-attn auto --kv-cache f16

# ---- 收集系统崩溃报告 ----
echo ""
echo "=== 收集 macOS DiagnosticReports (.ips) ==="
DIAG_DIR="$RESULTS_DIR/DiagnosticReports"
mkdir -p "$DIAG_DIR"
find "$HOME/Library/Logs/DiagnosticReports" -name "*.ips" -mmin -30 -print 2>/dev/null \
    | while read -r f; do
        base=$(basename "$f")
        cp "$f" "$DIAG_DIR/$base" 2>/dev/null && echo "✓ collected $base"
      done
find "$HOME/Library/Logs/DiagnosticReports" -name "*.crash" -mmin -30 -print 2>/dev/null \
    | while read -r f; do
        base=$(basename "$f")
        cp "$f" "$DIAG_DIR/$base" 2>/dev/null && echo "✓ collected $base"
      done

echo ""
echo "=== METAL SMOKE TEST SUMMARY ==="
for log in "$RESULTS_DIR"/*.log; do
    [ -f "$log" ] || continue
    result=$(grep -m1 "\[RESULT\]" "$log" || echo "NO-RESULT")
    base=$(basename "$log")
    printf "  %-40s %s\n" "$base" "$result"
done
echo ""
echo "=== 结果目录: $RESULTS_DIR ==="
ls -la "$RESULTS_DIR"
