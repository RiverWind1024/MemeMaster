#!/bin/bash
# Patch cargokit plugin.gradle: project.exec { } → project.exec({ } as Action<ExecSpec>)
# Gradle 8+ removed project.exec(Closure)
set -euo pipefail

PUB_CACHE="${PUB_CACHE:-$HOME/.pub-cache/hosted/pub.dev}"

echo "=== Patching cargokit plugin.gradle ==="
echo "PUB_CACHE: $PUB_CACHE"

if [ ! -d "$PUB_CACHE" ]; then
    echo "❌ PUB_CACHE not found: $PUB_CACHE"
    exit 1
fi

PATCHED=0
SKIPPED=0

while IFS= read -r f; do
    if grep -q "as Action<ExecSpec>)" "$f" 2>/dev/null; then
        echo "  skip (already patched): $f"
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    echo "  patching: $f"
    perl -0777 -pi -e 's/(project\.exec)\s*\{((?:[^{}]|\{(?:[^{}]|\{[^{}]*\})*\})*)\}/$1({$2} as Action<ExecSpec>)/g;' "$f"

    if grep -q "as Action<ExecSpec>)" "$f"; then
        echo "    ✓ patched"
        PATCHED=$((PATCHED + 1))
    else
        echo "    ❌ patch failed"
        exit 1
    fi
done < <(grep -rl "project\.exec" "$PUB_CACHE" --include="plugin.gradle" 2>/dev/null || true)

TOTAL=$((PATCHED + SKIPPED))
echo ""
echo "=== Results: $PATCHED patched, $SKIPPED already done ==="

if [ "$TOTAL" -eq 0 ]; then
    echo "❌ No plugin.gradle files with project.exec found"
    exit 1
fi

echo "✓ cargokit plugin patched"
