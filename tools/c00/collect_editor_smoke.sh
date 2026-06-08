#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DURATION="${1:-${DURATION:-15}}"
EXTRA_VALIDATE_ARGS="${EXTRA_VALIDATE_ARGS:-}"
EDITOR_XR_PLATFORM="${EDITOR_XR_PLATFORM:-simulator}"
EDITOR_HEADLESS="${EDITOR_HEADLESS:-1}"
EDITOR_XR_MODE="${EDITOR_XR_MODE:-off}"
EDITOR_EXTRA_ARGS="${EDITOR_EXTRA_ARGS:-}"
DEFAULT_GODOT_BIN="$PROJECT_ROOT/.godot/cache/c00/godot-editor/Godot.app/Contents/MacOS/Godot"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT_DIR="$PROJECT_ROOT/releases/phase_0_smoke/evidence"
LOG_PATH="$OUT_DIR/editor-${STAMP}.log"
REPORT_PATH="$OUT_DIR/editor-${STAMP}.md"

mkdir -p "$OUT_DIR"

if [ -n "${GODOT_BIN:-}" ]; then
	GODOT="$GODOT_BIN"
elif [ -x "$DEFAULT_GODOT_BIN" ]; then
	GODOT="$DEFAULT_GODOT_BIN"
else
	GODOT="$(command -v godot || true)"
fi

if [ -z "$GODOT" ] || [ ! -x "$GODOT" ]; then
	echo "Godot executable not found. Set GODOT_BIN=/path/to/Godot or add godot to PATH." >&2
	exit 2
fi

GODOT_ARGS=(--path "$PROJECT_ROOT" "--xr-platform=${EDITOR_XR_PLATFORM}")
if [[ "$EDITOR_HEADLESS" != "0" ]]; then
	GODOT_ARGS=(--headless "${GODOT_ARGS[@]}")
fi
if [[ -n "$EDITOR_XR_MODE" ]]; then
	GODOT_ARGS+=(--xr-mode "$EDITOR_XR_MODE")
fi
if [[ -n "$EDITOR_EXTRA_ARGS" ]]; then
	# shellcheck disable=SC2206
	EXTRA_ARGS=($EDITOR_EXTRA_ARGS)
	GODOT_ARGS+=("${EXTRA_ARGS[@]}")
fi

echo "Launching Godot editor simulator for ${DURATION}s -> $LOG_PATH"
echo "Godot: $GODOT"
echo "Args: ${GODOT_ARGS[*]}"
"$GODOT" "${GODOT_ARGS[@]}" > "$LOG_PATH" 2>&1 &
GODOT_PID="$!"

sleep "$DURATION"
kill "$GODOT_PID" >/dev/null 2>&1 || true
wait "$GODOT_PID" >/dev/null 2>&1 || true

echo "Validating editor simulator gate"
node "$PROJECT_ROOT/tools/c00/validate_smoke_log.js" \
	--gate editor \
	--log "$LOG_PATH" \
	--report "$REPORT_PATH" \
	$EXTRA_VALIDATE_ARGS

echo "Report: $REPORT_PATH"
