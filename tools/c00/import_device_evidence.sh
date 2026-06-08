#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GATE=""
LOG_SOURCE=""
SCREENSHOT_SOURCE=""
VIDEO_SOURCE=""
MANUAL_MEDIA_SOURCE=""
OUT_DIR="${OUT_DIR:-$PROJECT_ROOT/releases/phase_0_smoke/evidence}"
STAMP="${STAMP:-$(date +%Y%m%d-%H%M%S)}"
EXTRA_VALIDATE_ARGS="${EXTRA_VALIDATE_ARGS:-}"
ALLOW_MISSING_MEDIA="${ALLOW_MISSING_MEDIA:-0}"
MIN_BYTES="${MIN_BYTES:-1024}"

usage() {
	cat <<EOF
Usage:
  tools/c00/import_device_evidence.sh --gate <rokid|ipad|android-arcore|editor> --log <file> [media]

Media:
  --screenshot <file>      Screenshot evidence.
  --video <file>           Screen recording evidence.
  --manual-media <file>    Manual iPad screenshot or recording fallback.

Options:
  --out-dir <dir>          Evidence output dir. Default: releases/phase_0_smoke/evidence.
  --stamp <stamp>          Output filename stamp. Default: current timestamp.
  --allow-missing-media    Downgrade missing media from failure to warning.
  --min-bytes <bytes>      Minimum media size. Default: 1024.

Environment:
  EXTRA_VALIDATE_ARGS      Extra args passed to validate_smoke_log.js.

This imports manually captured device evidence into the same C00 report format
used by collect_android_smoke.sh and collect_ios_smoke.sh.
EOF
}

while [[ "$#" -gt 0 ]]; do
	case "$1" in
		--gate)
			GATE="$2"
			shift 2
			;;
		--log)
			LOG_SOURCE="$2"
			shift 2
			;;
		--screenshot)
			SCREENSHOT_SOURCE="$2"
			shift 2
			;;
		--video)
			VIDEO_SOURCE="$2"
			shift 2
			;;
		--manual-media)
			MANUAL_MEDIA_SOURCE="$2"
			shift 2
			;;
		--out-dir)
			OUT_DIR="$2"
			shift 2
			;;
		--stamp)
			STAMP="$2"
			shift 2
			;;
		--allow-missing-media)
			ALLOW_MISSING_MEDIA=1
			shift
			;;
		--min-bytes)
			MIN_BYTES="$2"
			shift 2
			;;
		-h|--help)
			usage
			exit 0
			;;
		*)
			usage >&2
			exit 2
			;;
	esac
done

case "$GATE" in
	rokid|ipad|android-arcore|editor)
		;;
	*)
		usage >&2
		exit 2
		;;
esac

if [[ -z "$LOG_SOURCE" ]]; then
	echo "ERROR: --log is required." >&2
	exit 2
fi

if [[ ! -f "$LOG_SOURCE" ]]; then
	echo "ERROR: Log file does not exist: $LOG_SOURCE" >&2
	exit 2
fi

mkdir -p "$OUT_DIR"

extension_for() {
	local path="$1"
	local fallback="$2"
	local name
	name="$(basename "$path")"
	if [[ "$name" == *.* ]]; then
		printf "%s" "${name##*.}"
	else
		printf "%s" "$fallback"
	fi
}

copy_optional() {
	local kind="$1"
	local source="$2"
	local fallback_ext="$3"
	if [[ -z "$source" ]]; then
		return 0
	fi
	if [[ ! -f "$source" ]]; then
		echo "ERROR: $kind file does not exist: $source" >&2
		exit 2
	fi
	local ext
	ext="$(extension_for "$source" "$fallback_ext")"
	local target="$OUT_DIR/${GATE}-${STAMP}-${kind}.${ext}"
	cp "$source" "$target"
	printf "%s" "$target"
}

LOG_PATH="$OUT_DIR/${GATE}-${STAMP}.log"
REPORT_PATH="$OUT_DIR/${GATE}-${STAMP}.md"
cp "$LOG_SOURCE" "$LOG_PATH"

SCREENSHOT_PATH="$(copy_optional screenshot "$SCREENSHOT_SOURCE" png)"
VIDEO_PATH="$(copy_optional video "$VIDEO_SOURCE" mp4)"
MANUAL_MEDIA_PATH="$(copy_optional manual-media "$MANUAL_MEDIA_SOURCE" media)"

echo "Imported log: $LOG_PATH"
if [[ -n "$SCREENSHOT_PATH" ]]; then
	echo "Imported screenshot: $SCREENSHOT_PATH"
fi
if [[ -n "$VIDEO_PATH" ]]; then
	echo "Imported video: $VIDEO_PATH"
fi
if [[ -n "$MANUAL_MEDIA_PATH" ]]; then
	echo "Imported manual media: $MANUAL_MEDIA_PATH"
fi

echo "Validating smoke log: $GATE"
node "$PROJECT_ROOT/tools/c00/validate_smoke_log.js" \
	--gate "$GATE" \
	--log "$LOG_PATH" \
	--report "$REPORT_PATH" \
	$EXTRA_VALIDATE_ARGS

EVIDENCE_ARGS=(--gate "$GATE" --report "$REPORT_PATH" --min-bytes "$MIN_BYTES")
if [[ -n "$SCREENSHOT_PATH" ]]; then
	EVIDENCE_ARGS+=(--screenshot "$SCREENSHOT_PATH")
fi
if [[ -n "$VIDEO_PATH" ]]; then
	EVIDENCE_ARGS+=(--video "$VIDEO_PATH")
fi
if [[ -n "$MANUAL_MEDIA_PATH" ]]; then
	EVIDENCE_ARGS+=(--manual-media "$MANUAL_MEDIA_PATH")
fi
if [[ "$ALLOW_MISSING_MEDIA" == "1" ]]; then
	EVIDENCE_ARGS+=(--allow-missing-media)
fi

echo "Validating evidence bundle"
node "$PROJECT_ROOT/tools/c00/validate_evidence_bundle.js" "${EVIDENCE_ARGS[@]}"

echo "Report: $REPORT_PATH"
