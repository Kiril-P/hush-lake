#!/bin/bash
# Headless test of the second-layer machines (bait grinder, wind fan). Exit code 0 = pass.
cd "$(dirname "$0")/.."
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
out=$("$GODOT" --headless --path . res://tools/machines_test.tscn --quit-after 3000 2>&1)
echo "$out" | grep -E "^(PASS|FAIL|MACHINES|goals without)|SCRIPT ERROR|^ERROR|Parse Error"
if echo "$out" | grep -qE "SCRIPT ERROR|^ERROR:|MACHINES FAIL|Parse Error"; then exit 1; fi
echo "$out" | grep -q "MACHINES PASS"
