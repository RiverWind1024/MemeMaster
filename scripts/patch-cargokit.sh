#!/bin/bash
# Patch super_native_extensions / irondash cargokit plugin for Gradle 8 compatibility
# Issue: Project.exec(Closure) and DefaultTask.exec(Closure) were removed in Gradle 8
# Fix: wrap with Action<ExecSpec> which is the Gradle 8 API
# This is needed because super_clipboard -> super_native_extensions -> cargokit

set -e

# Use python3 -c with inline code (avoids heredoc / file issues on macOS,
# where some runtimes may not have stdin support in the right way)
patch_file() {
    local f="$1"
    # Replace `project.exec {` with `project.exec({` and the matching `}` with
    # `} as Action<ExecSpec>)`. This is the simplest correct transformation:
    # the original closure becomes an explicit Action<ExecSpec> via cast.
    python3 -c "
import sys
p = sys.argv[1]
with open(p) as fp:
    s = fp.read()

new = []
i = 0
while i < len(s):
    idx = s.find('project.exec {', i)
    if idx < 0:
        new.append(s[i:])
        break
    new.append(s[i:idx])
    new.append('project.exec({')
    j = idx + len('project.exec {')
    depth = 1
    while j < len(s) and depth > 0:
        if s[j] == '{':
            depth += 1
        elif s[j] == '}':
            depth -= 1
        j += 1
    # s[idx+len('project.exec {'):j-1] is the inner block, j-1 is matching '}'
    inner = s[idx + len('project.exec {'):j - 1]
    new.append(inner)
    new.append('} as Action<ExecSpec>)')
    i = j

with open(p, 'w') as fp:
    fp.write(''.join(new))
print('  patched', p)
" "$f"
}

# Find all cargokit plugin.gradle under pub-cache (version may change)
find "$HOME/.pub-cache/hosted/pub.dev" -name "plugin.gradle" -path "*super_native_extensions*cargokit*" 2>/dev/null | while read f; do
    echo "Patching $f"
    patch_file "$f"
done

find "$HOME/.pub-cache/hosted/pub.dev" -name "plugin.gradle" -path "*irondash_engine_context*cargokit*" 2>/dev/null | while read f; do
    echo "Patching $f"
    patch_file "$f"
done

echo "✓ cargokit plugin patched"