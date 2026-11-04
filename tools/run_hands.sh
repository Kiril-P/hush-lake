#!/bin/bash
# Headless test of the hands system. Exit code 0 = pass.
cd "$(dirname "$0")/.."
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
out=$("$GODOT" --headless --path . res://tools/hands_test.tscn --quit-after 3000 2>&1)
echo "$out" | grep -E "^(PASS|FAIL|HANDS|goals without)|SCRIPT ERROR|^ERROR|Parse Error"
if echo "$out" | grep -qE "SCRIPT ERROR|^ERROR:|HANDS FAIL|Parse Error"; then exit 1; fi
echo "$out" | grep -q "HANDS PASS"
