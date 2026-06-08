#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

BUNDLE_DIR="${BUNDLE_DIR:-}"
ENV_FILE="${ENV_FILE:-$PROJECT_ROOT/.godot/cache/c00/device-env.sh}"
READINESS_REPORT="${READINESS_REPORT:-$PROJECT_ROOT/releases/phase_0_smoke/evidence/device-lab-readiness-${TIMESTAMP}.md}"
STATIC_REPORT="${STATIC_REPORT:-$PROJECT_ROOT/releases/phase_0_smoke/evidence/device-lab-static-${TIMESTAMP}.md}"
AUDIT_REPORT="${AUDIT_REPORT:-$PROJECT_ROOT/releases/phase_0_smoke/C00_COMPLETION_AUDIT.md}"
AUDIT_JSON="${AUDIT_JSON:-$PROJECT_ROOT/releases/phase_0_smoke/C00_COMPLETION_AUDIT.json}"

RUN_IMPORT="${RUN_IMPORT:-auto}"
RUN_READINESS="${RUN_READINESS:-1}"
RUN_STATIC_GATES="${RUN_STATIC_GATES:-1}"
RUN_DEVICE_CYCLE="${RUN_DEVICE_CYCLE:-1}"
RUN_COMPLETION_AUDIT="${RUN_COMPLETION_AUDIT:-1}"
DRY_RUN="${DRY_RUN:-0}"
CONTINUE_AFTER_CYCLE="${CONTINUE_AFTER_CYCLE:-1}"

GATE="${GATE:-all}"
DEVICE="${DEVICE:-}"

usage() {
	cat <<EOF
Usage:
  tools/c00/run_phase1_device_lab.sh [options]

Options:
  --bundle <dir>          Import an offline dependency bundle before running gates.
  --env-file <file>       Environment file written/read by bundle importer. Default: $ENV_FILE
  --gate <gate>           Device cycle gate: all, rokid, ipad, android-arcore, editor, ios-simulator. Default: all
  --device <id-or-name>   iPad device id/name forwarded to run_device_cycle.sh.
  --dry-run               Print the device-lab sequence without invoking Godot/Xcode/ADB/devicectl.
  --no-import             Skip offline dependency bundle import.
  --no-readiness          Skip bootstrap_device_machine.sh report.
  --no-static             Skip run_static_gates.js.
  --no-cycle              Skip run_device_cycle.sh.
  --no-audit              Skip audit_phase1_completion.js.

Environment:
  BUNDLE_DIR=/Volumes/USB/device-bundle
  GODOT_BIN=/path/to/Godot
  DEVICE=<ipad-uuid-or-name>
  DRY_RUN=1
  RUN_IMPORT=auto|1|0
  RUN_READINESS=1|0
  RUN_STATIC_GATES=1|0
  RUN_DEVICE_CYCLE=1|0
  RUN_COMPLETION_AUDIT=1|0
  CONTINUE_AFTER_CYCLE=1|0

This is the phase-1 device-machine wrapper. It intentionally exits non-zero
until the real Rokid/OpenXR, iPad/ARKit, and Android/ARCore evidence exists.
EOF
}

while [[ "$#" -gt 0 ]]; do
	case "$1" in
		--bundle)
			BUNDLE_DIR="$2"
			RUN_IMPORT=1
			shift 2
			;;
		--env-file)
			ENV_FILE="$2"
			shift 2
			;;
		--gate)
			GATE="$2"
			shift 2
			;;
		--device)
			DEVICE="$2"
			shift 2
			;;
		--dry-run)
			DRY_RUN=1
			shift
			;;
		--no-import)
			RUN_IMPORT=0
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
		--no-cycle)
			RUN_DEVICE_CYCLE=0
			shift
			;;
		--no-audit)
			RUN_COMPLETION_AUDIT=0
			shift
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
	all|editor|ios-simulator|rokid|ipad|android-arcore)
		;;
	*)
		echo "ERROR: unsupported gate: $GATE" >&2
		usage >&2
		exit 2
		;;
esac

project_path() {
	local input="$1"
	case "$input" in
		/*) printf "%s" "$input" ;;
		*) printf "%s/%s" "$PROJECT_ROOT" "$input" ;;
	esac
}

run_step() {
	local title="$1"
	shift
	echo
	echo "== Phase 1 device lab: $title =="
	if [[ "$DRY_RUN" == "1" ]]; then
		printf "DRY RUN:"
		printf " %q" "$@"
		printf "\n"
		return 0
	fi
	"$@"
}

source_env_if_present() {
	local env_path
	env_path="$(project_path "$ENV_FILE")"
	if [[ -f "$env_path" ]]; then
		echo "Sourcing device environment: $env_path"
		# shellcheck disable=SC1090
		source "$env_path"
	elif [[ "$RUN_IMPORT" == "0" ]]; then
		echo "No device environment file found: $env_path"
	fi
}

main() {
	local status=0

	if [[ "$RUN_IMPORT" == "auto" && -n "$BUNDLE_DIR" ]]; then
		RUN_IMPORT=1
	fi

	if [[ "$RUN_IMPORT" == "1" ]]; then
		if [[ -z "$BUNDLE_DIR" ]]; then
			echo "ERROR: --bundle <dir> or BUNDLE_DIR is required when RUN_IMPORT=1." >&2
			exit 2
		fi
		run_step "import dependency bundle" \
			"$PROJECT_ROOT/tools/c00/import_device_dependency_bundle.sh" \
			--bundle "$BUNDLE_DIR" \
			--env-file "$(project_path "$ENV_FILE")" || status=$?
	fi

	source_env_if_present

	if [[ "$RUN_READINESS" == "1" ]]; then
		run_step "readiness report" \
			"$PROJECT_ROOT/tools/c00/bootstrap_device_machine.sh" \
			--report "$(project_path "$READINESS_REPORT")" || status=$?
	fi

	if [[ "$RUN_STATIC_GATES" == "1" ]]; then
		run_step "static gates" \
			node "$PROJECT_ROOT/tools/c00/run_static_gates.js" \
			--gate all \
			--report "$(project_path "$STATIC_REPORT")" || status=$?
	fi

	if [[ "$RUN_DEVICE_CYCLE" == "1" ]]; then
		local cycle_args=("$PROJECT_ROOT/tools/c00/run_device_cycle.sh" "$GATE")
		if [[ "$GATE" == "ipad" || "$GATE" == "all" ]]; then
			if [[ -n "$DEVICE" ]]; then
				cycle_args+=("$DEVICE")
			fi
		fi
		if [[ "$DRY_RUN" == "1" ]]; then
			echo
			echo "== Phase 1 device lab: device cycle =="
			DRY_RUN=1 "${cycle_args[@]}" || status=$?
		else
			DRY_RUN=0 "${cycle_args[@]}" || status=$?
		fi
		if [[ "$status" != "0" && "$CONTINUE_AFTER_CYCLE" != "1" ]]; then
			exit "$status"
		fi
	fi

	if [[ "$RUN_COMPLETION_AUDIT" == "1" ]]; then
		run_step "completion audit" \
			node "$PROJECT_ROOT/tools/c00/audit_phase1_completion.js" \
			--report "$(project_path "$AUDIT_REPORT")" \
			--json "$(project_path "$AUDIT_JSON")" || status=$?
	fi

	echo
	if [[ "$DRY_RUN" == "1" ]]; then
		echo "Phase 1 device lab dry-run finished. No device/build command was executed and this is not a completion result."
	elif [[ "$status" == "0" && "$RUN_COMPLETION_AUDIT" == "1" ]]; then
		echo "Phase 1 device lab finished with READY/PASS status."
	elif [[ "$status" == "0" ]]; then
		echo "Phase 1 device lab selected steps finished. Completion audit was skipped, so phase 1 is not proven complete."
	else
		echo "Phase 1 device lab finished with NOT_READY status. Inspect:"
		echo "  $(project_path "$READINESS_REPORT")"
		echo "  $(project_path "$STATIC_REPORT")"
		echo "  $(project_path "$AUDIT_REPORT")"
	fi
	exit "$status"
}

main
