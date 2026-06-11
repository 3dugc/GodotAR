#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GATE="all"
DEVICE="${DEVICE:-}"
PACKAGE="${PACKAGE:-org.godotengine.godotxrfoundation}"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-300}"
INTERVAL_SECONDS="${INTERVAL_SECONDS:-5}"
RUN_GATE=0
REPORT=""
JSON_REPORT=""

usage() {
	cat <<EOF
Usage:
  tools/c00/wait_for_device_ready.sh --gate <rokid|ipad|android-arcore|all> [--device <ipad-name-or-uuid>] [--timeout <seconds>] [--interval <seconds>] [--run-gate]

Examples:
  tools/c00/wait_for_device_ready.sh --gate rokid --timeout 300
  tools/c00/wait_for_device_ready.sh --gate ipad --device "iPad M4" --timeout 300 --run-gate
  tools/c00/wait_for_device_ready.sh --gate all --device "iPad M4" --timeout 600

When --run-gate is set, the script runs tools/c00/run_device_cycle.sh after readiness passes.
EOF
}

while [[ $# -gt 0 ]]; do
	case "$1" in
		--gate)
			GATE="${2:-}"
			shift 2
			;;
		--device)
			DEVICE="${2:-}"
			shift 2
			;;
		--package)
			PACKAGE="${2:-}"
			shift 2
			;;
		--timeout)
			TIMEOUT_SECONDS="${2:-}"
			shift 2
			;;
		--interval)
			INTERVAL_SECONDS="${2:-}"
			shift 2
			;;
		--report)
			REPORT="${2:-}"
			shift 2
			;;
		--json)
			JSON_REPORT="${2:-}"
			shift 2
			;;
		--run-gate)
			RUN_GATE=1
			shift
			;;
		-h|--help)
			usage
			exit 0
			;;
		*)
			echo "Unknown argument: $1" >&2
			usage >&2
			exit 2
			;;
	esac
done

case "$GATE" in
	rokid|ipad|android-arcore|all) ;;
	*)
		echo "Unsupported gate: $GATE" >&2
		usage >&2
		exit 2
		;;
esac

STAMP="$(date +%Y%m%d-%H%M%S)"
OUT_DIR="$PROJECT_ROOT/releases/phase_0_smoke/evidence"
mkdir -p "$OUT_DIR"
REPORT="${REPORT:-$OUT_DIR/device-ready-${GATE}-${STAMP}.md}"
JSON_REPORT="${JSON_REPORT:-$OUT_DIR/device-ready-${GATE}-${STAMP}.json}"

resolve_ready_ipad_device_from_json() {
	local json_file="$1"
	if [[ ! -f "$json_file" ]]; then
		return 0
	fi
	node -e '
const fs = require("fs");
const file = process.argv[1];
const summary = JSON.parse(fs.readFileSync(file, "utf8"));
const ipad = (Array.isArray(summary.results) ? summary.results : []).find((item) => item && item.gate === "ipad");
const evidence = (ipad && ipad.evidence) || {};
const selection = evidence.device_selection || {};
const selected = evidence.device || selection.selected_device || "";
if (selected) {
	process.stdout.write(String(selected));
}
' "$json_file" 2>/dev/null || true
}

set_ready_ipad_device_from_json_if_needed() {
	if [[ -n "$DEVICE" ]]; then
		return 0
	fi
	case "$GATE" in
		ipad|all)
			;;
		*)
			return 0
			;;
	esac
	local selected_device
	selected_device="$(resolve_ready_ipad_device_from_json "$JSON_REPORT")"
	if [[ -n "$selected_device" ]]; then
		DEVICE="$selected_device"
		export DEVICE
		echo "Using auto-discovered iPad device for gate run: $DEVICE"
	fi
}

deadline=$(( $(date +%s) + TIMEOUT_SECONDS ))
attempt=1
status=1

while true; do
	echo "Device readiness attempt $attempt for gate '$GATE'..."
	args=(--gate "$GATE" --package "$PACKAGE" --report "$REPORT" --json "$JSON_REPORT" --format markdown)
	if [[ -n "$DEVICE" ]]; then
		args+=(--device "$DEVICE")
	fi
	set +e
	node "$PROJECT_ROOT/tools/c00/check_device_ready.js" "${args[@]}"
	status="$?"
	set -e
	if [[ "$status" -eq 0 ]]; then
		echo "Device readiness passed. Report: $REPORT"
		set_ready_ipad_device_from_json_if_needed
		if [[ "$RUN_GATE" == "1" ]]; then
			echo "Running C00 device gate: $GATE"
			case "$GATE" in
				ipad)
					DEVICE="$DEVICE" PACKAGE="$PACKAGE" "$PROJECT_ROOT/tools/c00/run_device_cycle.sh" ipad "$DEVICE"
					;;
				all)
					DEVICE="$DEVICE" PACKAGE="$PACKAGE" "$PROJECT_ROOT/tools/c00/run_device_cycle.sh" all "$DEVICE"
					;;
				*)
					PACKAGE="$PACKAGE" "$PROJECT_ROOT/tools/c00/run_device_cycle.sh" "$GATE"
					;;
			esac
		fi
		exit 0
	fi

	now="$(date +%s)"
	if [[ "$now" -ge "$deadline" ]]; then
		echo "Device readiness timed out after ${TIMEOUT_SECONDS}s. Last report: $REPORT" >&2
		exit "$status"
	fi
	remaining=$(( deadline - now ))
	sleep_seconds="$INTERVAL_SECONDS"
	if [[ "$remaining" -lt "$sleep_seconds" ]]; then
		sleep_seconds="$remaining"
	fi
	echo "Device not ready yet; sleeping ${sleep_seconds}s..."
	sleep "$sleep_seconds"
	attempt=$(( attempt + 1 ))
done
