#!/bin/bash
# Patch super_native_extensions cargokit plugin for Gradle 8 compatibility
# Issue: Project.exec(Closure) was removed in Gradle 8; we replace with exec(Action)
# This is needed because super_clipboard -> super_native_extensions -> cargokit

set -e

PLUGIN_GRADLE="$HOME/.pub-cache/hosted/pub.dev/super_native_extensions-0.9.1/cargokit/gradle/plugin.gradle"

# Find all plugin.gradle under pub-cache (version may change)
find "$HOME/.pub-cache/hosted/pub.dev" -name "plugin.gradle" -path "*super_native_extensions*cargokit*" | while read f; do
    if grep -q "project\.exec {" "$f"; then
        echo "Patching $f"
        sed -i 's/project\.exec {/exec {/g' "$f"
    fi
done

# Same fix for irondash_engine_context (also uses cargokit)
find "$HOME/.pub-cache/hosted/pub.dev" -name "plugin.gradle" -path "*irondash_engine_context*cargokit*" | while read f; do
    if grep -q "project\.exec {" "$f"; then
        echo "Patching $f"
        sed -i 's/project\.exec {/exec {/g' "$f"
    fi
done

echo "✓ cargokit plugin patched"