#!/bin/bash
# Render the Ledger and refreeze card to renders/progress_*.png (opens a window).
cd "$(dirname "$0")/.."
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
"$GODOT" --path . res://tools/progress_shot.tscn --resolution 1280x720 2>&1 | grep -E "saved|ERROR|SCRIPT"
