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

resolve_godot_binary() {
	if [ -n "${GODOT_BIN:-}" ] && [ -x "$GODOT_BIN" ]; then
		printf "%s" "$GODOT_BIN"
		return 0
	fi
	if command -v godot >/dev/null 2>&1; then
		command -v godot
		return 0
	fi
	local bundled="$PROJECT_ROOT/.godot/cache/c00/godot-editor/Godot.app/Contents/MacOS/Godot"
	if [ -x "$bundled" ]; then
		printf "%s" "$bundled"
		return 0
	fi
	local applications="/Applications/Godot.app/Contents/MacOS/Godot"
	if [ -x "$applications" ]; then
		printf "%s" "$applications"
		return 0
	fi
	return 1
}

if ! GODOT="$(resolve_godot_binary)"; then
	echo "Godot executable not found. Install Godot or set GODOT_BIN=/path/to/Godot." >&2
	exit 2
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

is_android_export=0
case "$EXPORT_PATH" in
	*.apk|*.aab) is_android_export=1 ;;
esac

if [ "$is_android_export" = "1" ] && [ "${GODOT_CONFIGURE_ANDROID_EXPORT:-auto}" != "0" ]; then
	echo "Configuring Android export environment before Godot export..."
	"$PROJECT_ROOT/tools/c00/configure_android_export_environment.sh" \
		--godot "$GODOT" \
		--install-build-template
fi

GODOT_XR_MODE="${GODOT_EXPORT_XR_MODE:-off}"
GODOT_ARGS=(--headless)
if [ -n "$GODOT_XR_MODE" ]; then
	GODOT_ARGS+=(--xr-mode "$GODOT_XR_MODE")
fi

mkdir -p "$(dirname "$EXPORT_PATH")"

echo "Exporting preset '$PRESET' -> $OUT_PATH"
"$GODOT" "${GODOT_ARGS[@]}" --path "$PROJECT_ROOT" --export-debug "$PRESET" "$EXPORT_PATH"
