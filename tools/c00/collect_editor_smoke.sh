#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DURATION="${1:-${DURATION:-15}}"
EXTRA_VALIDATE_ARGS="${EXTRA_VALIDATE_ARGS:-}"
EDITOR_XR_PLATFORM="${EDITOR_XR_PLATFORM:-simulator}"
EDITOR_EXTRA_ARGS="${EDITOR_EXTRA_ARGS:-}"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT_DIR="$PROJECT_ROOT/releases/phase_0_smoke/evidence"
LOG_PATH="$OUT_DIR/editor-${STAMP}.log"
REPORT_PATH="$OUT_DIR/editor-${STAMP}.md"

mkdir -p "$OUT_DIR"

if [ -n "${GODOT_BIN:-}" ]; then
	GODOT="$GODOT_BIN"
else
	GODOT="$(command -v godot || true)"
fi

if [ -z "$GODOT" ] || [ ! -x "$GODOT" ]; then
	echo "Godot executable not found. Set GODOT_BIN=/path/to/Godot or add godot to PATH." >&2
	exit 2
fi

echo "Launching Godot editor simulator for ${DURATION}s -> $LOG_PATH"
"$GODOT" \
	--path "$PROJECT_ROOT" \
	"--xr-platform=${EDITOR_XR_PLATFORM}" \
	$EDITOR_EXTRA_ARGS > "$LOG_PATH" 2>&1 &
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
