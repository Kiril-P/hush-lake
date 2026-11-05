#!/bin/bash
# Render the reference-shot manifest to docs/refs/shots/ (opens a window). REF_ONLY=prefix limits it; pass `-- --out DIR` via $@.
cd "$(dirname "$0")/.."
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
"$GODOT" --path . res://tools/refshots.tscn --resolution 1600x900 -- "$@" 2>&1 | grep -E "saved|ERROR|SCRIPT"
