#!/bin/bash
# Render the story layer to renders/story_*.png (opens a window).
cd "$(dirname "$0")/.."
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
"$GODOT" --path . res://tools/story_shot.tscn --resolution 1280x720 2>&1 | grep -E "saved|ERROR|SCRIPT"
