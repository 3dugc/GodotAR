#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEFAULT_GODOT_BIN="$PROJECT_ROOT/.godot/cache/c00/godot-editor/Godot.app/Contents/MacOS/Godot"
OUT_DIR="${OUT_DIR:-$PROJECT_ROOT/releases/phase_0_smoke/evidence}"
STAMP="${STAMP:-$(date +%Y%m%d-%H%M%S)}"
SUMMARY_PATH="$OUT_DIR/c01-editor-${STAMP}.md"

mkdir -p "$OUT_DIR"

if [ -n "${GODOT_BIN:-}" ]; then
	GODOT="$GODOT_BIN"
elif [ -x "$DEFAULT_GODOT_BIN" ]; then
	GODOT="$DEFAULT_GODOT_BIN"
else
	GODOT="$(command -v godot || true)"
fi

if [ -z "$GODOT" ] || [ ! -x "$GODOT" ]; then
	echo "Godot executable not found. Set GODOT_BIN=/path/to/Godot or install the project-local editor." >&2
	exit 2
fi

PLACE_STATUS=0
BACKEND_STATUS=0

run_scene_gate() {
	local gate="$1"
	local scene="$2"
	local prefix="$3"
	local log_path="$OUT_DIR/${prefix}-${STAMP}.log"
	local godot_log_path="$OUT_DIR/${prefix}-${STAMP}.godot.log"
	local report_path="$OUT_DIR/${prefix}-${STAMP}.md"
	local json_path="$OUT_DIR/${prefix}-${STAMP}.json"

	echo "Run C01 ${gate}: ${scene}"
	echo "Log: ${log_path}"
	set +e
	"$GODOT" \
		--headless \
		--path "$PROJECT_ROOT" \
		--xr-mode off \
		--quit \
		--scene "$scene" \
		--log-file "$godot_log_path" \
		> "$log_path" 2>&1
	local godot_status=$?
	node "$PROJECT_ROOT/tools/c00/validate_smoke_log.js" \
		--gate "$gate" \
		--log "$log_path" \
		--report "$report_path" \
		> "$json_path"
	local validate_status=$?
	set -e

	if [ "$godot_status" -ne 0 ]; then
		echo "Godot exited with ${godot_status} for ${gate}" >&2
	fi
	if [ "$validate_status" -ne 0 ]; then
		echo "Validation failed with ${validate_status} for ${gate}" >&2
	fi
	if [ "$godot_status" -ne 0 ]; then
		return "$godot_status"
	fi
	return "$validate_status"
}

run_scene_gate "c01-place" "res://demo/01_place_on_plane.tscn" "c01-place" || PLACE_STATUS=$?
run_scene_gate "c01-backend" "res://demo/02_backend_switcher.tscn" "c01-backend" || BACKEND_STATUS=$?

{
	echo "# C01 EditorSim Smoke"
	echo
	if [ "$PLACE_STATUS" -eq 0 ] && [ "$BACKEND_STATUS" -eq 0 ]; then
		echo "Result: PASS"
	else
		echo "Result: FAIL"
	fi
	echo
	echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
	echo
	echo "Godot: \`$GODOT\`"
	echo
	echo "## Gates"
	echo
	echo "| Gate | Status | Log | Report | JSON |"
	echo "| --- | --- | --- | --- | --- |"
	echo "| c01-place | $([ "$PLACE_STATUS" -eq 0 ] && echo PASS || echo FAIL) | \`$OUT_DIR/c01-place-${STAMP}.log\` | \`$OUT_DIR/c01-place-${STAMP}.md\` | \`$OUT_DIR/c01-place-${STAMP}.json\` |"
	echo "| c01-backend | $([ "$BACKEND_STATUS" -eq 0 ] && echo PASS || echo FAIL) | \`$OUT_DIR/c01-backend-${STAMP}.log\` | \`$OUT_DIR/c01-backend-${STAMP}.md\` | \`$OUT_DIR/c01-backend-${STAMP}.json\` |"
	echo
	echo "This proves the C01 ARFoundation-style upper API can run in EditorSim. It does not satisfy Rokid/OpenXR, iPad/ARKit, or Android/ARCore real-device gates."
} > "$SUMMARY_PATH"

echo "Summary: $SUMMARY_PATH"

if [ "$PLACE_STATUS" -ne 0 ] || [ "$BACKEND_STATUS" -ne 0 ]; then
	exit 1
fi
