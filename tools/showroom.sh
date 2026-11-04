#!/bin/bash
# Renders a clean studio of the machines, tools and fish to renders/room_*.png (opens a window briefly).
cd "$(dirname "$0")/.."
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
"$GODOT" --path . res://tools/showroom.tscn --resolution 1280x720 2>&1 | grep -E "saved|ERROR|SCRIPT"
