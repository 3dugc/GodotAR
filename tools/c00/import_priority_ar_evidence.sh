#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STAMP="${STAMP:-$(date +%Y%m%d-%H%M%S)}"
OUT_DIR="${OUT_DIR:-$PROJECT_ROOT/releases/phase_0_smoke/evidence}"
REPORT="${REPORT:-$PROJECT_ROOT/releases/phase_0_smoke/C01_PRIORITY_AR_REPORT.md}"
INCLUDE_PLACE_DEMOS="${INCLUDE_PLACE_DEMOS:-1}"
ALLOW_MISSING_MEDIA="${ALLOW_MISSING_MEDIA:-0}"
ALLOW_MISSING_DEVICE_PROFILE="${ALLOW_MISSING_DEVICE_PROFILE:-0}"
DRY_RUN="${DRY_RUN:-0}"
IMPORT_STATUS=0

ROKID_LOG=""
ROKID_SCREENSHOT=""
ROKID_VIDEO=""
ROKID_DEVICE_PROFILE=""
ROKID_DEVICE_PROFILE_JSON=""

ROKID_PLACE_LOG=""
ROKID_PLACE_SCREENSHOT=""
ROKID_PLACE_VIDEO=""
ROKID_PLACE_DEVICE_PROFILE=""
ROKID_PLACE_DEVICE_PROFILE_JSON=""

IPAD_LOG=""
IPAD_SCREENSHOT=""
IPAD_VIDEO=""
IPAD_MANUAL_MEDIA=""
IPAD_DEVICE_PROFILE=""
IPAD_DEVICE_PROFILE_JSON=""

IPAD_PLACE_LOG=""
IPAD_PLACE_SCREENSHOT=""
IPAD_PLACE_VIDEO=""
IPAD_PLACE_MANUAL_MEDIA=""
IPAD_PLACE_DEVICE_PROFILE=""
IPAD_PLACE_DEVICE_PROFILE_JSON=""

usage() {
	cat <<EOF
Usage:
  tools/c00/import_priority_ar_evidence.sh [options]

Rokid/OpenXR:
  --rokid-log <file>
  --rokid-screenshot <file>
  --rokid-video <file>
  --rokid-device-profile <file>
  --rokid-device-profile-json <file>
  --rokid-place-log <file>
  --rokid-place-screenshot <file>
  --rokid-place-video <file>
  --rokid-place-device-profile <file>
  --rokid-place-device-profile-json <file>

iPad/ARKit:
  --ipad-log <file>
  --ipad-screenshot <file>
  --ipad-video <file>
  --ipad-manual-media <file>
  --ipad-device-profile <file>
  --ipad-device-profile-json <file>
  --ipad-place-log <file>
  --ipad-place-screenshot <file>
  --ipad-place-video <file>
  --ipad-place-manual-media <file>
  --ipad-place-device-profile <file>
  --ipad-place-device-profile-json <file>

Options:
  --out-dir <dir>                    Evidence output dir. Default: releases/phase_0_smoke/evidence.
  --report <file>                    Priority report. Default: releases/phase_0_smoke/C01_PRIORITY_AR_REPORT.md.
  --stamp <stamp>                    Shared output filename stamp. Default: current timestamp.
  --include-place-demos              Require rokid-place and ipad-place. Default.
  --no-place-demos                   Only verify base rokid and ipad gates.
  --allow-missing-media              Downgrade missing media from failure to warning.
  --allow-missing-device-profile     Downgrade missing device profile from failure to warning.
  --dry-run                          Print import and verify commands without copying files.

This imports manually collected iPad/ARKit and Rokid/OpenXR evidence into the
standard C00 evidence directory, then runs the same priority AR aggregate
verification used by tools/c00/run_phase1_priority_ar_lab.sh.
EOF
}

while [[ "$#" -gt 0 ]]; do
	case "$1" in
		--rokid-log) ROKID_LOG="${2:-}"; shift 2 ;;
		--rokid-screenshot) ROKID_SCREENSHOT="${2:-}"; shift 2 ;;
		--rokid-video) ROKID_VIDEO="${2:-}"; shift 2 ;;
		--rokid-device-profile) ROKID_DEVICE_PROFILE="${2:-}"; shift 2 ;;
		--rokid-device-profile-json) ROKID_DEVICE_PROFILE_JSON="${2:-}"; shift 2 ;;
		--rokid-place-log) ROKID_PLACE_LOG="${2:-}"; shift 2 ;;
		--rokid-place-screenshot) ROKID_PLACE_SCREENSHOT="${2:-}"; shift 2 ;;
		--rokid-place-video) ROKID_PLACE_VIDEO="${2:-}"; shift 2 ;;
		--rokid-place-device-profile) ROKID_PLACE_DEVICE_PROFILE="${2:-}"; shift 2 ;;
		--rokid-place-device-profile-json) ROKID_PLACE_DEVICE_PROFILE_JSON="${2:-}"; shift 2 ;;
		--ipad-log) IPAD_LOG="${2:-}"; shift 2 ;;
		--ipad-screenshot) IPAD_SCREENSHOT="${2:-}"; shift 2 ;;
		--ipad-video) IPAD_VIDEO="${2:-}"; shift 2 ;;
		--ipad-manual-media) IPAD_MANUAL_MEDIA="${2:-}"; shift 2 ;;
		--ipad-device-profile) IPAD_DEVICE_PROFILE="${2:-}"; shift 2 ;;
		--ipad-device-profile-json) IPAD_DEVICE_PROFILE_JSON="${2:-}"; shift 2 ;;
		--ipad-place-log) IPAD_PLACE_LOG="${2:-}"; shift 2 ;;
		--ipad-place-screenshot) IPAD_PLACE_SCREENSHOT="${2:-}"; shift 2 ;;
		--ipad-place-video) IPAD_PLACE_VIDEO="${2:-}"; shift 2 ;;
		--ipad-place-manual-media) IPAD_PLACE_MANUAL_MEDIA="${2:-}"; shift 2 ;;
		--ipad-place-device-profile) IPAD_PLACE_DEVICE_PROFILE="${2:-}"; shift 2 ;;
		--ipad-place-device-profile-json) IPAD_PLACE_DEVICE_PROFILE_JSON="${2:-}"; shift 2 ;;
		--out-dir) OUT_DIR="${2:-}"; shift 2 ;;
		--report) REPORT="${2:-}"; shift 2 ;;
		--stamp) STAMP="${2:-}"; shift 2 ;;
		--include-place-demos) INCLUDE_PLACE_DEMOS=1; shift ;;
		--no-place-demos) INCLUDE_PLACE_DEMOS=0; shift ;;
		--allow-missing-media) ALLOW_MISSING_MEDIA=1; shift ;;
		--allow-missing-device-profile) ALLOW_MISSING_DEVICE_PROFILE=1; shift ;;
		--dry-run) DRY_RUN=1; shift ;;
		-h|--help) usage; exit 0 ;;
		*)
			echo "Unknown argument: $1" >&2
			usage >&2
			exit 2
			;;
	esac
done

project_path() {
	local input="$1"
	case "$input" in
		/*) printf "%s" "$input" ;;
		*) printf "%s/%s" "$PROJECT_ROOT" "$input" ;;
	esac
}

run_or_print() {
	if [[ "$DRY_RUN" == "1" ]]; then
		printf "DRY RUN:"
		printf " %q" "$@"
		printf "\n"
		return 0
	fi
	"$@"
}

import_gate() {
	local gate="$1"
	local log_path="$2"
	local screenshot_path="$3"
	local video_path="$4"
	local manual_media_path="$5"
	local device_profile_path="$6"
	local device_profile_json_path="$7"

	if [[ -z "$log_path" ]]; then
		echo "No $gate log supplied; aggregate verification will report missing evidence if this gate is required."
		return 0
	fi

	local import_args=(
		"$PROJECT_ROOT/tools/c00/import_device_evidence.sh"
		--gate "$gate"
		--log "$log_path"
		--out-dir "$(project_path "$OUT_DIR")"
		--stamp "$STAMP"
	)
	if [[ -n "$screenshot_path" ]]; then
		import_args+=(--screenshot "$screenshot_path")
	fi
	if [[ -n "$video_path" ]]; then
		import_args+=(--video "$video_path")
	fi
	if [[ -n "$manual_media_path" ]]; then
		import_args+=(--manual-media "$manual_media_path")
	fi
	if [[ -n "$device_profile_path" ]]; then
		import_args+=(--device-profile "$device_profile_path")
	fi
	if [[ -n "$device_profile_json_path" ]]; then
		import_args+=(--device-profile-json "$device_profile_json_path")
	fi
	if [[ "$ALLOW_MISSING_MEDIA" == "1" ]]; then
		import_args+=(--allow-missing-media)
	fi

	echo
	echo "== Import priority AR evidence: $gate =="
	local import_status=0
	set +e
	run_or_print "${import_args[@]}"
	import_status="$?"
	set -e
	if [[ "$import_status" != "0" ]]; then
		IMPORT_STATUS="$import_status"
		echo "Import failed for $gate; continuing so other priority evidence can still be processed." >&2
	fi
}

verify_priority_evidence() {
	local verify_args=(
		node "$PROJECT_ROOT/tools/c00/verify_phase_evidence.js"
		--dir "$(project_path "$OUT_DIR")"
		--report "$(project_path "$REPORT")"
		--gate rokid
		--gate ipad
	)
	if [[ "$INCLUDE_PLACE_DEMOS" == "1" ]]; then
		verify_args+=(--gate rokid-place --gate ipad-place)
	fi
	if [[ "$ALLOW_MISSING_MEDIA" == "1" ]]; then
		verify_args+=(--allow-missing-media)
	fi
	if [[ "$ALLOW_MISSING_DEVICE_PROFILE" == "1" ]]; then
		verify_args+=(--allow-missing-device-profile)
	fi

	echo
	echo "== Verify priority AR evidence =="
	run_or_print "${verify_args[@]}"
}

mkdir -p "$(project_path "$OUT_DIR")"

import_gate rokid "$ROKID_LOG" "$ROKID_SCREENSHOT" "$ROKID_VIDEO" "" "$ROKID_DEVICE_PROFILE" "$ROKID_DEVICE_PROFILE_JSON"
import_gate ipad "$IPAD_LOG" "$IPAD_SCREENSHOT" "$IPAD_VIDEO" "$IPAD_MANUAL_MEDIA" "$IPAD_DEVICE_PROFILE" "$IPAD_DEVICE_PROFILE_JSON"

if [[ "$INCLUDE_PLACE_DEMOS" == "1" ]]; then
	import_gate rokid-place "$ROKID_PLACE_LOG" "$ROKID_PLACE_SCREENSHOT" "$ROKID_PLACE_VIDEO" "" "$ROKID_PLACE_DEVICE_PROFILE" "$ROKID_PLACE_DEVICE_PROFILE_JSON"
	import_gate ipad-place "$IPAD_PLACE_LOG" "$IPAD_PLACE_SCREENSHOT" "$IPAD_PLACE_VIDEO" "$IPAD_PLACE_MANUAL_MEDIA" "$IPAD_PLACE_DEVICE_PROFILE" "$IPAD_PLACE_DEVICE_PROFILE_JSON"
fi

verify_priority_evidence

echo
if [[ "$DRY_RUN" == "1" ]]; then
	echo "Priority AR evidence import dry-run finished. No files were copied and this is not a completion result."
else
	if [[ "$IMPORT_STATUS" != "0" ]]; then
		echo "One or more priority evidence imports failed before aggregate verification." >&2
	fi
	echo "Priority AR evidence report: $(project_path "$REPORT")"
	echo "This report only covers iPad/ARKit and Rokid/OpenXR priority gates; full Phase 1 still requires Android/ARCore audit evidence."
fi

if [[ "$IMPORT_STATUS" != "0" ]]; then
	exit "$IMPORT_STATUS"
fi
