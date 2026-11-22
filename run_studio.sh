#!/usr/bin/env bash
set -euo pipefail

# Cross-platform launcher for Simulacrum Studio (Arch Linux & macOS Apple Silicon)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

GODOT_BIN=""
if command -v godot >/dev/null 2>&1; then
	GODOT_BIN="godot"
elif command -v godot4 >/dev/null 2>&1; then
	GODOT_BIN="godot4"
elif [[ -x "/Applications/Godot.app/Contents/MacOS/Godot" ]]; then
	GODOT_BIN="/Applications/Godot.app/Contents/MacOS/Godot"
elif [[ -x "$HOME/Applications/Godot.app/Contents/MacOS/Godot" ]]; then
	GODOT_BIN="$HOME/Applications/Godot.app/Contents/MacOS/Godot"
else
	echo "Error: Godot 4 executable not found in PATH or /Applications/Godot.app." >&2
	exit 1
fi

exec "$GODOT_BIN" --path "$SCRIPT_DIR" res://tools/simulacrum_studio.tscn "$@"
