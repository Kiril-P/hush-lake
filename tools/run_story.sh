#!/bin/bash
# Headless test of the story layer (letters, keepsakes, dreams, ending). Exit code 0 = pass.
cd "$(dirname "$0")/.."
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
out=$("$GODOT" --headless --path . res://tools/story_test.tscn --quit-after 3000 2>&1)
echo "$out" | grep -E "^(PASS|FAIL|STORY|goals without)|SCRIPT ERROR|^ERROR|Parse Error"
if echo "$out" | grep -qE "SCRIPT ERROR|^ERROR:|STORY FAIL|Parse Error"; then exit 1; fi
echo "$out" | grep -q "STORY PASS"
