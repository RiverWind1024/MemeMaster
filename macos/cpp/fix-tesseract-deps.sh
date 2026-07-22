#!/bin/bash
# 修正 bundled tesseract/leptonica 的传递依赖（macOS sandbox 下 /opt/homebrew/ 不可访问）
# 用法: fix-tesseract-deps.sh <frameworks_dir>

set -e

FW_DIR="${1:?Usage: $0 <frameworks_dir>}"
echo "=== Fixing transitive dependencies in $FW_DIR ==="

declare -A PROCESSED
declare -A TO_PROCESS

for dylib in "$FW_DIR"/libtesseract*.dylib "$FW_DIR"/libleptonica*.dylib; do
    [ -f "$dylib" ] || continue
    TO_PROCESS["$dylib"]=1
done

while [ ${#TO_PROCESS[@]} -gt 0 ]; do
    dylib=$(echo "${!TO_PROCESS[@]}" | head -1)
    unset TO_PROCESS["$dylib"]
    
    name=$(basename "$dylib")
    if [ "${PROCESSED[$dylib]+exists}" ]; then
        continue
    fi
    PROCESSED["$dylib"]=1
    
    echo "Processing: $name"
    
    otool -L "$dylib" 2>/dev/null | grep '/opt/homebrew/' | while read line; do
        dep_path=$(echo "$line" | awk '{print $1}')
        dep_name=$(basename "$dep_path")
        
        if [ "${PROCESSED[$FW_DIR/$dep_name]+exists}" ]; then
            continue
        fi
        
        if [ ! -f "$FW_DIR/$dep_name" ]; then
            if [ -f "$dep_path" ]; then
                echo "  Copying: $dep_name (from $dep_path)"
                cp "$dep_path" "$FW_DIR/"
                install_name_tool -id "@rpath/$dep_name" "$FW_DIR/$dep_name" 2>/dev/null || true
            else
                echo "  WARNING: $dep_path not found, skipping"
                continue
            fi
        fi
        
        install_name_tool -change "$dep_path" "@rpath/$dep_name" "$dylib" 2>/dev/null || true
        TO_PROCESS["$FW_DIR/$dep_name"]=1
    done
done

echo "=== Transitive dependencies fixed ==="
ls -la "$FW_DIR"/*.dylib 2>/dev/null | awk '{print $NF, $5}'
