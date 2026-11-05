#!/bin/bash
# Headless test of the opening: camera director, title screen, the sled run, skip, "previously". Exit code 0 = pass.
cd "$(dirname "$0")/.."
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
out=$("$GODOT" --headless --path . res://tools/opening_test.tscn --quit-after 20000 2>&1)
echo "$out" | grep -E "^(PASS|FAIL|OPENING|goals without)|SCRIPT ERROR|^ERROR|Parse Error"
if echo "$out" | grep -qE "SCRIPT ERROR|^ERROR:|OPENING FAIL|Parse Error"; then exit 1; fi
echo "$out" | grep -q "OPENING PASS"
