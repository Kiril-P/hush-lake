#!/bin/bash
# Launch the game. Set GODOT to override the binary path.
cd "$(dirname "$0")/.."
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
exec "$GODOT" --path .
