#!/bin/bash
# Render screenshots of the game to renders/shot_*.png (opens a window briefly).
cd "$(dirname "$0")/.."
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
"$GODOT" --path . res://tools/shot.tscn --resolution 1280x720 2>&1 | grep -E "saved|ERROR"
