#!/bin/bash
# Render 120 s of the score under six moods to renders/score_*.wav (headless is fine).
cd "$(dirname "$0")/.."
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
"$GODOT" --headless --path . res://tools/score_dump.tscn 2>&1 | grep -E "^SCORE|SCRIPT|ERROR"
