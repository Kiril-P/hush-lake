#!/bin/bash
# Headless economy simulation: how long each milestone takes for a rational active player.
cd "$(dirname "$0")/.."
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
"$GODOT" --headless --path . res://tools/econ_sim.tscn --quit-after 100000 2>&1 | grep -vE "^Godot|^$|ObjectDB|at: cleanup"
