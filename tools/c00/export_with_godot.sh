#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PRESET="${1:-}"
OUT_PATH="${2:-}"

if [ -z "$PRESET" ] || [ -z "$OUT_PATH" ]; then
	echo "Usage: tools/c00/export_with_godot.sh <export-preset-name> <output-path>" >&2
	echo "Example: tools/c00/export_with_godot.sh 'C00 Rokid OpenXR' builds/rokid/c00.apk" >&2
	exit 2
fi

GODOT="${GODOT_BIN:-}"
if [ -z "$GODOT" ]; then
	if command -v godot >/dev/null 2>&1; then
		GODOT="$(command -v godot)"
	elif [ -x "/Applications/Godot.app/Contents/MacOS/Godot" ]; then
		GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
	else
		echo "Godot executable not found. Install Godot or set GODOT_BIN=/path/to/Godot." >&2
		exit 2
	fi
fi

if [ ! -f "$PROJECT_ROOT/export_presets.cfg" ]; then
	echo "export_presets.cfg not found." >&2
	echo "Create C00 export presets in Godot editor first. See tools/c00/EXPORT_PRESETS_CN.md." >&2
	exit 2
fi

case "$OUT_PATH" in
	/*) EXPORT_PATH="$OUT_PATH" ;;
	*) EXPORT_PATH="$PROJECT_ROOT/$OUT_PATH" ;;
esac

mkdir -p "$(dirname "$EXPORT_PATH")"

echo "Exporting preset '$PRESET' -> $OUT_PATH"
"$GODOT" --headless --path "$PROJECT_ROOT" --export-debug "$PRESET" "$EXPORT_PATH"
