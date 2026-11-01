#!/bin/bash
# Plays the real game with synthetic mouse/keys (opens a window for ~30 s). Exit code 0 = pass.
cd "$(dirname "$0")/.."
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
out=$("$GODOT" --path . res://tools/play_bot.tscn --resolution 960x540 2>&1)
echo "$out" | grep -E "^(PASS|FAIL|BOT)|SCRIPT ERROR|^ERROR"
if echo "$out" | grep -qE "SCRIPT ERROR|^ERROR:|BOT FAIL"; then exit 1; fi
echo "$out" | grep -q "BOT PASS"
