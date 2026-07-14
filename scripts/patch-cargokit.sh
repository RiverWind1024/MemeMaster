#!/bin/bash
# Patch cargokit plugin.gradle: project.exec { } → project.exec({ } as Action<ExecSpec>)
# Gradle 8+ removed project.exec(Closure)
set -euo pipefail

SEARCH_ROOTS=()
if [ -n "${PUB_CACHE:-}" ]; then
    SEARCH_ROOTS+=("$PUB_CACHE")
fi
SEARCH_ROOTS+=("$HOME/.pub-cache/hosted/pub.dev")

echo "=== Patching cargokit plugin.gradle ==="

FILES=()
for root in "${SEARCH_ROOTS[@]}"; do
    [ -d "$root" ] || continue
    echo "Searching: $root"
    while IFS= read -r f; do
        FILES+=("$f")
    done < <(grep -rl "project\.exec" "$root" --include="plugin.gradle" 2>/dev/null || true)
done

if [ ${#FILES[@]} -eq 0 ]; then
    echo "⚠️  No cargokit plugin.gradle found in any search path, trying find..."
    while IFS= read -r f; do
        FILES+=("$f")
    done < <(find "$HOME" -name "plugin.gradle" -path "*/cargokit/*" -exec grep -l "project\.exec" {} + 2>/dev/null || true)
fi

if [ ${#FILES[@]} -eq 0 ]; then
    echo "❌ No plugin.gradle files with project.exec found"
    exit 1
fi

PATCHED=0
SKIPPED=0

for f in "${FILES[@]}"; do
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
done

echo ""
echo "=== Results: $PATCHED patched, $SKIPPED already done ==="
echo "✓ cargokit plugin patched"
