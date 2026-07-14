#!/bin/bash
# Patch super_native_extensions / irondash cargokit plugin for Gradle 8 compatibility
# Issue: Project.exec(Closure) and DefaultTask.exec(Closure) were removed in Gradle 8
# Fix: wrap with Action<ExecSpec> which is the Gradle 8 API
# This is needed because super_clipboard -> super_native_extensions -> cargokit

set -e

patch_file() {
    local f="$1"
    # Match `project.exec {` and find the matching `}` by counting braces.
    # Replace with `project.exec(new Action<ExecSpec>() { ... })` so Gradle 8
    # accepts the call. We use Python for robust multi-line replacement
    # (BSD/GNU sed can't reliably count braces).
    python3 - "$f" <<'PYEOF'
import sys
p = sys.argv[1]
with open(p) as f:
    s = f.read()

new = []
i = 0
while i < len(s):
    idx = s.find('project.exec {', i)
    if idx < 0:
        new.append(s[i:])
        break
    new.append(s[i:idx])
    new.append('project.exec(new Action<ExecSpec>() {')
    j = idx + len('project.exec {')
    depth = 1
    while j < len(s) and depth > 0:
        if s[j] == '{':
            depth += 1
        elif s[j] == '}':
            depth -= 1
        j += 1
    # s[idx+len('project.exec {'):j-1] is the inner block, j-1 is matching `}`
    inner = s[idx + len('project.exec {'):j - 1]
    new.append(inner)
    new.append('})')
    i = j

with open(p, 'w') as f:
    f.write(''.join(new))
print(f"  patched {p}")
PYEOF
}

# Find all cargokit plugin.gradle under pub-cache (version may change)
find "$HOME/.pub-cache/hosted/pub.dev" -name "plugin.gradle" -path "*super_native_extensions*cargokit*" | while read f; do
    echo "Patching $f"
    patch_file "$f"
done

find "$HOME/.pub-cache/hosted/pub.dev" -name "plugin.gradle" -path "*irondash_engine_context*cargokit*" | while read f; do
    echo "Patching $f"
    patch_file "$f"
done

echo "✓ cargokit plugin patched"