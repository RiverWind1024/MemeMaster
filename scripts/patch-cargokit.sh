#!/bin/bash
# Patch cargokit plugin.gradle for Gradle 8 compatibility
# Gradle 8 removed project.exec(Closure); must use project.exec(Action<ExecSpec>)
#
# Handles two file shapes:
#   irondash_engine_context-0.5.5: project.exec { ... }  (trailing lambda, no parens)
#   super_native_extensions-0.9.1: already has ({...} as Action<ExecSpec>) — skip

set -e

PATCHED_COUNT=0

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
    # Match: project.exec { OR project.exec({
    # Both represent the start of an exec block that needs Action<ExecSpec> wrapping
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
                rest = stripped[1:].lstrip()
                if rest.startswith(')'):
                    exec_lines.append(cur_indent + '} as Action<ExecSpec>)')
                else:
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
print('  patched', p)
" "$f"
}

# 使用 process substitution 避免子 shell 问题（set -e 会在子 shell 中丢失）
while IFS= read -r f; do
    echo "Patching $f"
    patch_file "$f"
    PATCHED_COUNT=$((PATCHED_COUNT + 1))
done < <(find "$HOME/.pub-cache/hosted/pub.dev" -name "plugin.gradle" -path "*irondash_engine_context*cargokit*" 2>/dev/null)

while IFS= read -r f; do
    echo "Patching $f"
    patch_file "$f"
    PATCHED_COUNT=$((PATCHED_COUNT + 1))
done < <(find "$HOME/.pub-cache/hosted/pub.dev" -name "plugin.gradle" -path "*super_native_extensions*cargokit*" 2>/dev/null)

# 验证: 检查是否至少处理了一个文件
if [ "$PATCHED_COUNT" -eq 0 ]; then
    echo "⚠️  No cargokit plugin.gradle files found"
    echo "   This may be OK if irondash_engine_context/super_native_extensions aren't used"
else
    echo "✓ Patched $PATCHED_COUNT cargokit file(s)"
fi

# 验证: 确认 patched 的文件确实包含 Action<ExecSpec>
FAIL=0
for f in $(find "$HOME/.pub-cache/hosted/pub.dev" -name "plugin.gradle" -path "*irondash_engine_context*cargokit*" 2>/dev/null); do
    if ! grep -q "as Action<ExecSpec>)" "$f"; then
        echo "❌ $f was NOT patched correctly"
        FAIL=1
    fi
done

if [ "$FAIL" -ne 0 ]; then
    echo "❌ Verification failed"
    exit 1
fi

echo "✓ cargokit plugin patched and verified"
