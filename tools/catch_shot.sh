#!/bin/bash
# Render the journal and the fish models to renders/catch_*.png (opens a window).
cd "$(dirname "$0")/.."
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
"$GODOT" --path . res://tools/catch_shot.tscn --resolution 1280x720 2>&1 | grep -E "saved|ERROR|SCRIPT"
