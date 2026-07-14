#!/bin/bash
# Patch cargokit plugin.gradle for Gradle 8 compatibility
# Gradle 8 removed project.exec(Closure); must use project.exec(Action<ExecSpec>)
set -euo pipefail

PUB_CACHE="${PUB_CACHE:-$HOME/.pub-cache/hosted/pub.dev}"

echo "=== Patching cargokit plugin.gradle for Gradle 8 ==="
echo "PUB_CACHE: $PUB_CACHE"

if [ ! -d "$PUB_CACHE" ]; then
    echo "❌ PUB_CACHE directory not found: $PUB_CACHE"
    exit 1
fi

patch_file() {
    local f="$1"
    python3 -c "
import sys, re

p = sys.argv[1]
with open(p) as fp:
    content = fp.read()

if 'as Action<ExecSpec>)' in content:
    print('  skipped (already patched):', p)
    sys.exit(0)

lines = content.split('\n')
result = []
i = 0
while i < len(lines):
    line = lines[i]
    m = re.match(r'^(\s*)project\.exec[\s]*\{', line.rstrip())
    if m:
        base_indent = m.group(1)
        exec_lines = [base_indent + 'project.exec({']
        depth = 1
        i += 1
        while i < len(lines) and depth > 0:
            cur = lines[i]
            stripped = cur.lstrip()
            cur_indent = cur[:len(cur) - len(stripped)] if stripped else cur
            if stripped.startswith('}') and depth == 1 and cur_indent == base_indent:
                exec_lines.append(cur_indent + '} as Action<ExecSpec>)')
                depth -= 1
                i += 1
                break
            else:
                for ch in cur:
                    if ch == '{':
                        depth += 1
                    elif ch == '}':
                        depth -= 1
                exec_lines.append(cur)
                i += 1
        result.extend(exec_lines)
    else:
        result.append(line)
        i += 1

content = '\n'.join(result)

with open(p, 'w') as fp:
    fp.write(content)
print('  patched:', p)
" "$f"
}

PATCHED=0

# 用 grep -rl 直接找包含 project.exec 的 plugin.gradle，比 find -path 更可靠
while IFS= read -r f; do
    echo "Patching $f"
    patch_file "$f"
    PATCHED=$((PATCHED + 1))
done < <(grep -rl "project\.exec" "$PUB_CACHE" --include="plugin.gradle" 2>/dev/null || true)

echo ""
echo "=== Results ==="
echo "Patched: $PATCHED file(s)"

if [ "$PATCHED" -eq 0 ]; then
    echo "❌ No cargokit plugin.gradle files found needing patches"
    echo "   Checked: $PUB_CACHE"
    echo "   This means irondash_engine_context or super_native_extensions may not be installed"
    exit 1
fi

# 验证: 确认 patched 的文件确实包含 Action<ExecSpec>
echo ""
echo "=== Verification ==="
FAIL=0
while IFS= read -r f; do
    if grep -q "project\.exec" "$f" && ! grep -q "as Action<ExecSpec>)" "$f"; then
        echo "❌ $f still has unpatched exec()"
        FAIL=1
    fi
done < <(grep -rl "project\.exec" "$PUB_CACHE" --include="plugin.gradle" 2>/dev/null || true)

if [ "$FAIL" -ne 0 ]; then
    echo "❌ Verification failed - some files were not patched correctly"
    exit 1
fi

echo "✓ cargokit plugin patched and verified"
