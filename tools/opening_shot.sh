#!/bin/bash
# Render the opening (title, sled run, previously) to renders/open_*.png (opens a window). OPEN_ONLY=title|intro|previously
cd "$(dirname "$0")/.."
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
"$GODOT" --path . res://tools/opening_shot.tscn --resolution 1280x720 2>&1 | grep -E "saved|ERROR|SCRIPT"
