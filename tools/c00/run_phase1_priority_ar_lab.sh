#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

BUNDLE_DIR="${BUNDLE_DIR:-}"
DEVICE="${DEVICE:-}"
PACKAGE="${PACKAGE:-org.godotengine.godotxrfoundation}"
DURATION="${DURATION:-30}"
WAIT_FOR_DEVICES="${WAIT_FOR_DEVICES:-1}"
WAIT_TIMEOUT_SECONDS="${WAIT_TIMEOUT_SECONDS:-600}"
WAIT_INTERVAL_SECONDS="${WAIT_INTERVAL_SECONDS:-5}"
AUTO_RECOVER_DEVICES="${AUTO_RECOVER_DEVICES:-1}"
INCLUDE_PLACE_DEMOS="${INCLUDE_PLACE_DEMOS:-1}"
RUN_READINESS="${RUN_READINESS:-1}"
RUN_STATIC_GATES="${RUN_STATIC_GATES:-1}"
RUN_ONLINE_DEPS="${RUN_ONLINE_DEPS:-0}"
ONLINE_DEPS="${ONLINE_DEPS:-auto}"
RUN_IMPORT="${RUN_IMPORT:-auto}"
RUN_FULL_AUDIT="${RUN_FULL_AUDIT:-0}"
DRY_RUN="${DRY_RUN:-0}"

PHASE_REPORT="${PHASE_REPORT:-$PROJECT_ROOT/releases/phase_0_smoke/C01_PRIORITY_AR_REPORT.md}"
READINESS_REPORT="${READINESS_REPORT:-$PROJECT_ROOT/releases/phase_0_smoke/evidence/priority-ar-readiness-${TIMESTAMP}.md}"
STATIC_REPORT="${STATIC_REPORT:-$PROJECT_ROOT/releases/phase_0_smoke/evidence/priority-ar-static-${TIMESTAMP}.md}"
AUDIT_REPORT="${AUDIT_REPORT:-$PROJECT_ROOT/releases/phase_0_smoke/C00_COMPLETION_AUDIT.md}"
AUDIT_JSON="${AUDIT_JSON:-$PROJECT_ROOT/releases/phase_0_smoke/C00_COMPLETION_AUDIT.json}"

usage() {
	cat <<EOF
Usage:
  tools/c00/run_phase1_priority_ar_lab.sh [options]

Options:
  --bundle <dir>          Import an offline dependency bundle before running gates.
  --online-deps           Install/resume online C00 dependencies before readiness.
  --online-deps-list <list>
                          Online dependency subset passed through to run_phase1_device_lab.sh.
  --device <id-or-name>   iPad device id/name forwarded to the priority lane.
  --wait-devices          Wait for iPad/Rokid readiness before running gates. Default.
  --no-wait-devices       Do not wait; run collectors immediately for diagnostics.
  --recover-devices       After readiness timeout, recover once and retry. Default.
  --no-recover-devices    Disable automatic recovery after readiness timeout.
  --wait-timeout <sec>    Device readiness wait timeout. Default: $WAIT_TIMEOUT_SECONDS
  --wait-interval <sec>   Device readiness polling interval. Default: $WAIT_INTERVAL_SECONDS
  --include-place-demos   Run ipad-place and rokid-place. Default.
  --no-place-demos        Only run base ipad and rokid smoke gates.
  --report <file>         Priority evidence report. Default: $PHASE_REPORT
  --full-audit            Run the full Phase 1 completion audit afterwards.
  --no-readiness          Skip bootstrap readiness report.
  --no-static             Skip static gates.
  --no-import             Skip offline dependency bundle import.
  --dry-run               Print the sequence without invoking device/build commands.

Environment:
  DEVICE=<ipad-uuid-or-name>
  PACKAGE=org.godotengine.godotxrfoundation
  DURATION=30
  WAIT_FOR_DEVICES=1|0
  WAIT_TIMEOUT_SECONDS=600
  WAIT_INTERVAL_SECONDS=5
  AUTO_RECOVER_DEVICES=1|0
  INCLUDE_PLACE_DEMOS=1|0
  RUN_FULL_AUDIT=1|0
  DRY_RUN=1

This is the first-priority AR lane for Phase 1. It runs iPad/ARKit and
Rokid/OpenXR evidence gates, including placement demos by default. It is not a
full Phase 1 completion audit because Android/ARCore remains outside this
priority lane unless you run the full audit separately.
EOF
}

while [[ "$#" -gt 0 ]]; do
	case "$1" in
		--bundle)
			BUNDLE_DIR="${2:-}"
			RUN_IMPORT=1
			shift 2
			;;
		--online-deps)
			RUN_ONLINE_DEPS=1
			shift
			;;
		--online-deps-list)
			ONLINE_DEPS="${2:-}"
			shift 2
			;;
		--device)
			DEVICE="${2:-}"
			shift 2
			;;
		--wait-devices)
			WAIT_FOR_DEVICES=1
			shift
			;;
		--no-wait-devices)
			WAIT_FOR_DEVICES=0
			shift
			;;
		--recover-devices)
			AUTO_RECOVER_DEVICES=1
			shift
			;;
		--no-recover-devices)
			AUTO_RECOVER_DEVICES=0
			shift
			;;
		--wait-timeout)
			WAIT_TIMEOUT_SECONDS="${2:-}"
			shift 2
			;;
		--wait-interval)
			WAIT_INTERVAL_SECONDS="${2:-}"
			shift 2
			;;
		--include-place-demos)
			INCLUDE_PLACE_DEMOS=1
			shift
			;;
		--no-place-demos)
			INCLUDE_PLACE_DEMOS=0
			shift
			;;
		--report)
			PHASE_REPORT="${2:-}"
			shift 2
			;;
		--full-audit)
			RUN_FULL_AUDIT=1
			shift
			;;
		--no-readiness)
			RUN_READINESS=0
			shift
			;;
		--no-static)
			RUN_STATIC_GATES=0
			shift
			;;
		--no-import)
			RUN_IMPORT=0
			shift
			;;
		--dry-run)
			DRY_RUN=1
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

project_path() {
	local input="$1"
	case "$input" in
		/*) printf "%s" "$input" ;;
		*) printf "%s/%s" "$PROJECT_ROOT" "$input" ;;
	esac
}

lab_args=(--gate all --no-audit --wait-timeout "$WAIT_TIMEOUT_SECONDS" --wait-interval "$WAIT_INTERVAL_SECONDS")

if [[ "$WAIT_FOR_DEVICES" == "1" ]]; then
	lab_args+=(--wait-devices)
fi
if [[ "$AUTO_RECOVER_DEVICES" == "0" ]]; then
	lab_args+=(--no-recover-devices)
fi
if [[ "$INCLUDE_PLACE_DEMOS" == "1" ]]; then
	lab_args+=(--include-place-demos)
else
	lab_args+=(--no-place-demos)
fi
if [[ -n "$DEVICE" ]]; then
	lab_args+=(--device "$DEVICE")
fi
if [[ -n "$BUNDLE_DIR" ]]; then
	lab_args+=(--bundle "$BUNDLE_DIR")
elif [[ "$RUN_IMPORT" == "0" ]]; then
	lab_args+=(--no-import)
fi
if [[ "$RUN_ONLINE_DEPS" == "1" ]]; then
	lab_args+=(--online-deps)
	if [[ -n "$ONLINE_DEPS" && "$ONLINE_DEPS" != "auto" ]]; then
		lab_args+=(--online-deps-list "$ONLINE_DEPS")
	fi
fi
if [[ "$RUN_READINESS" == "0" ]]; then
	lab_args+=(--no-readiness)
fi
if [[ "$RUN_STATIC_GATES" == "0" ]]; then
	lab_args+=(--no-static)
fi
if [[ "$DRY_RUN" == "1" ]]; then
	lab_args+=(--dry-run)
fi

echo "Phase 1 priority AR lane: iPad/ARKit + Rokid/OpenXR"
echo "Priority report: $(project_path "$PHASE_REPORT")"
echo "This is not a full Phase 1 completion audit; Android/ARCore is intentionally excluded."

status=0
set +e
INCLUDE_ANDROID_ARCORE=0 \
INCLUDE_PLACE_DEMOS="$INCLUDE_PLACE_DEMOS" \
RUN_PHASE_VERIFY=1 \
PHASE_REPORT="$(project_path "$PHASE_REPORT")" \
READINESS_REPORT="$(project_path "$READINESS_REPORT")" \
STATIC_REPORT="$(project_path "$STATIC_REPORT")" \
PACKAGE="$PACKAGE" \
DURATION="$DURATION" \
DRY_RUN="$DRY_RUN" \
	"$PROJECT_ROOT/tools/c00/run_phase1_device_lab.sh" "${lab_args[@]}"
status="$?"
set -e

audit_status=0
if [[ "$RUN_FULL_AUDIT" == "1" ]]; then
	echo
	echo "Running full Phase 1 completion audit after priority AR lane..."
	set +e
	node "$PROJECT_ROOT/tools/c00/audit_phase1_completion.js" \
		--include-place-demos \
		--report "$(project_path "$AUDIT_REPORT")" \
		--json "$(project_path "$AUDIT_JSON")"
	audit_status="$?"
	set -e
fi

echo
if [[ "$DRY_RUN" == "1" ]]; then
	echo "Priority AR lane dry-run finished. No device/build command was executed and this is not a completion result."
	echo "Report path: $(project_path "$PHASE_REPORT")"
elif [[ "$status" == "0" ]]; then
	echo "Priority AR lane passed for iPad/ARKit and Rokid/OpenXR gates."
	echo "Report: $(project_path "$PHASE_REPORT")"
	echo "Run tools/c00/run_phase1_device_lab.sh --wait-devices for the full iPad/Rokid/Android completion lane."
else
	echo "Priority AR lane finished with NOT_READY status."
	echo "Inspect: $(project_path "$PHASE_REPORT")"
fi

if [[ "$RUN_FULL_AUDIT" == "1" && "$audit_status" != "0" ]]; then
	exit "$audit_status"
fi
exit "$status"
