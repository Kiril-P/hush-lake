#!/bin/bash
# Rendered frame-time check of a busy late-game lake (opens a window for ~30 s). Exit code 0 = within budget.
cd "$(dirname "$0")/.."
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
out=$("$GODOT" --path . res://tools/perf_render.tscn --resolution 1280x720 2>&1)
echo "$out" | grep -E "^(PERF|PASS|FAIL)|SCRIPT ERROR|^ERROR"
if echo "$out" | grep -qE "SCRIPT ERROR|^ERROR:|PERF FAIL"; then exit 1; fi
echo "$out" | grep -q "PERF PASS"
