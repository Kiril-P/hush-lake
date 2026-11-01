#!/bin/bash
# Headless smoke test. Exit code 0 = pass. Needs Godot at the path below (or set GODOT).
cd "$(dirname "$0")/.."
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
out=$("$GODOT" --headless --path . res://tools/smoke_test.tscn --quit-after 3000 2>&1)
echo "$out" | grep -E "^(PASS|FAIL|SMOKE)|SCRIPT ERROR|^ERROR" 
if echo "$out" | grep -qE "SCRIPT ERROR|^ERROR:|SMOKE FAIL"; then exit 1; fi
echo "$out" | grep -q "SMOKE PASS"
