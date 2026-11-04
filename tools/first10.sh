#!/bin/bash
# The "first 10 minutes" report: a bot that plays like a person (only what is on screen, limited turn speed, aim noise,
# follows the NEXT strip, real input events, no progression changes) and logs what it hit.
# Headless, ~3x speed: about 4 minutes of wall time. Exit code 0 = acceptance bounds met.
cd "$(dirname "$0")/.."
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
out=$("$GODOT" --headless --path . res://tools/first10.tscn --quit-after 200000 2>&1)
echo "$out" | grep -E "^(REPORT|PASS|FAIL|FIRST10|T=)|SCRIPT ERROR|^ERROR|Parse Error"
if echo "$out" | grep -qE "SCRIPT ERROR|^ERROR:|FIRST10 FAIL|Parse Error"; then exit 1; fi
echo "$out" | grep -q "FIRST10 PASS"
