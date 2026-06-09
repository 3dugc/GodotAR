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
RUN_ONLINE_DEPS="${RUN_ONLINE_DEPS:-0}"
ONLINE_DEPS="${ONLINE_DEPS:-auto}"
RUN_READINESS="${RUN_READINESS:-1}"
RUN_STATIC_GATES="${RUN_STATIC_GATES:-1}"
RUN_DEVICE_CYCLE="${RUN_DEVICE_CYCLE:-1}"
RUN_COMPLETION_AUDIT="${RUN_COMPLETION_AUDIT:-1}"
WAIT_FOR_DEVICES="${WAIT_FOR_DEVICES:-0}"
WAIT_TIMEOUT_SECONDS="${WAIT_TIMEOUT_SECONDS:-300}"
WAIT_INTERVAL_SECONDS="${WAIT_INTERVAL_SECONDS:-5}"
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
  --online-deps           Install/resume online C00 dependencies before readiness.
  --online-deps-list <list>
                          Online dependency subset: auto or comma/space list of templates,jdk,android-sdk,android-export.
  --online-deps-only      Run online dependency setup only, then exit.
  --env-file <file>       Environment file written/read by bundle importer. Default: $ENV_FILE
  --gate <gate>           Device cycle gate: all, rokid, ipad, android-arcore, editor, ios-simulator. Default: all
  --device <id-or-name>   iPad device id/name forwarded to run_device_cycle.sh.
  --wait-devices          Wait for selected devices to become ready before running the device cycle.
  --wait-timeout <sec>    Device readiness wait timeout. Default: $WAIT_TIMEOUT_SECONDS
  --wait-interval <sec>   Device readiness polling interval. Default: $WAIT_INTERVAL_SECONDS
  --dry-run               Print the device-lab sequence without invoking Godot/Xcode/ADB/devicectl.
  --no-import             Skip offline dependency bundle import.
  --no-online-deps        Skip online dependency installation. Default.
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
  RUN_ONLINE_DEPS=1|0
  ONLINE_DEPS=auto|templates,jdk,android-sdk,android-export
  RUN_READINESS=1|0
  RUN_STATIC_GATES=1|0
  RUN_DEVICE_CYCLE=1|0
  RUN_COMPLETION_AUDIT=1|0
  WAIT_FOR_DEVICES=1|0
  WAIT_TIMEOUT_SECONDS=300
  WAIT_INTERVAL_SECONDS=5
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
		--online-deps)
			RUN_ONLINE_DEPS=1
			shift
			;;
		--online-deps-list)
			ONLINE_DEPS="$2"
			shift 2
			;;
		--online-deps-only)
			RUN_ONLINE_DEPS=1
			RUN_READINESS=0
			RUN_STATIC_GATES=0
			RUN_DEVICE_CYCLE=0
			RUN_COMPLETION_AUDIT=0
			shift
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
		--wait-devices)
			WAIT_FOR_DEVICES=1
			shift
			;;
		--wait-timeout)
			WAIT_TIMEOUT_SECONDS="$2"
			shift 2
			;;
		--wait-interval)
			WAIT_INTERVAL_SECONDS="$2"
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
		--no-online-deps)
			RUN_ONLINE_DEPS=0
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

needs_ios_dependencies() {
	[[ "$GATE" == "all" || "$GATE" == "ipad" || "$GATE" == "ios-simulator" ]]
}

needs_android_dependencies() {
	[[ "$GATE" == "all" || "$GATE" == "rokid" || "$GATE" == "android-arcore" ]]
}

online_dep_enabled() {
	local name="$1"
	if [[ "$ONLINE_DEPS" == "auto" || "$ONLINE_DEPS" == "all" ]]; then
		return 0
	fi
	local list
	list="${ONLINE_DEPS//$'\n'/ }"
	list="${list//,/ }"
	local item
	for item in $list; do
		if [[ "$item" == "$name" ]]; then
			return 0
		fi
	done
	return 1
}

resolve_template_version() {
	if [[ -n "${GODOT_EXPORT_TEMPLATES_VERSION:-}" ]]; then
		printf "%s" "$GODOT_EXPORT_TEMPLATES_VERSION"
	elif [[ -n "${GODOT_TAG:-}" ]]; then
		printf "%s" "${GODOT_TAG/-stable/.stable}"
	else
		printf "4.4.1.stable"
	fi
}

resolve_export_templates_dir() {
	local version
	version="$(resolve_template_version)"
	printf "%s" "${GODOT_EXPORT_TEMPLATES_DIR:-$HOME/Library/Application Support/Godot/export_templates/$version}"
}

resolve_android_sdk_dir() {
	if [[ -n "${GODOT_ANDROID_SDK_PATH:-}" ]]; then
		printf "%s" "$GODOT_ANDROID_SDK_PATH"
	elif [[ -n "${ANDROID_SDK_ROOT:-}" ]]; then
		printf "%s" "$ANDROID_SDK_ROOT"
	elif [[ -n "${ANDROID_HOME:-}" ]]; then
		printf "%s" "$ANDROID_HOME"
	else
		printf "%s" "$PROJECT_ROOT/.godot/cache/c00/android-sdk"
	fi
}

resolve_jdk_home() {
	if [[ -n "${GODOT_JAVA_SDK_PATH:-}" ]]; then
		printf "%s" "$GODOT_JAVA_SDK_PATH"
	elif [[ -n "${JAVA_HOME:-}" ]]; then
		printf "%s" "$JAVA_HOME"
	else
		printf "%s" "$PROJECT_ROOT/.godot/cache/c00/jdk/Contents/Home"
	fi
}

resolve_godot_bin() {
	if [[ -n "${GODOT_BIN:-}" ]]; then
		printf "%s" "$GODOT_BIN"
	elif [[ -x "$PROJECT_ROOT/.godot/cache/c00/godot-editor/Godot.app/Contents/MacOS/Godot" ]]; then
		printf "%s" "$PROJECT_ROOT/.godot/cache/c00/godot-editor/Godot.app/Contents/MacOS/Godot"
	fi
}

resolve_godot_source_dir() {
	if [[ -n "${GODOT_SOURCE_DIR:-}" ]]; then
		printf "%s" "$GODOT_SOURCE_DIR"
	elif [[ -d "$PROJECT_ROOT/.godot/cache/c00/godot-source" ]]; then
		printf "%s" "$PROJECT_ROOT/.godot/cache/c00/godot-source"
	fi
}

write_device_env_from_current_machine() {
	local env_path templates_dir android_sdk jdk_home godot_bin godot_source debug_keystore version
	env_path="$(project_path "$ENV_FILE")"
	version="$(resolve_template_version)"
	templates_dir="$(resolve_export_templates_dir)"
	android_sdk="$(resolve_android_sdk_dir)"
	jdk_home="$(resolve_jdk_home)"
	godot_bin="$(resolve_godot_bin)"
	godot_source="$(resolve_godot_source_dir)"
	debug_keystore="${GODOT_ANDROID_KEYSTORE_DEBUG_PATH:-$PROJECT_ROOT/.godot/cache/c00/android/debug.keystore}"

	mkdir -p "$(dirname "$env_path")"
	{
		printf "# Generated by tools/c00/run_phase1_device_lab.sh --online-deps\n"
		printf "export GODOT_EXPORT_TEMPLATES_VERSION=%q\n" "$version"
		printf "export GODOT_EXPORT_TEMPLATES_DIR=%q\n" "$templates_dir"
		if [[ -d "$android_sdk" ]]; then
			printf "export GODOT_ANDROID_SDK_PATH=%q\n" "$android_sdk"
			printf "export ANDROID_SDK_ROOT=%q\n" "$android_sdk"
		fi
		if [[ -x "$jdk_home/bin/java" && -x "$jdk_home/bin/keytool" ]]; then
			printf "export GODOT_JAVA_SDK_PATH=%q\n" "$jdk_home"
			printf "export JAVA_HOME=%q\n" "$jdk_home"
		fi
		if [[ -x "$godot_bin" ]]; then
			printf "export GODOT_BIN=%q\n" "$godot_bin"
		fi
		if [[ -d "$godot_source" ]]; then
			printf "export GODOT_SOURCE_DIR=%q\n" "$godot_source"
		fi
		if [[ -f "$debug_keystore" ]]; then
			printf "export GODOT_ANDROID_KEYSTORE_DEBUG_PATH=%q\n" "$debug_keystore"
		fi
	} > "$env_path"
	echo "Wrote device environment: $env_path"
}

run_online_dependency_setup() {
	local version android_sdk jdk_home online_status=0
	version="$(resolve_template_version)"
	if online_dep_enabled templates && { needs_ios_dependencies || needs_android_dependencies; }; then
		run_step "install Godot export templates" \
			"$PROJECT_ROOT/tools/c00/install_godot_export_templates.sh" \
			--download \
			--version "$version" || online_status=$?
	fi
	if needs_android_dependencies; then
		android_sdk="$(resolve_android_sdk_dir)"
		jdk_home="$PROJECT_ROOT/.godot/cache/c00/jdk/Contents/Home"
		if online_dep_enabled jdk; then
			run_step "install OpenJDK 17" \
				"$PROJECT_ROOT/tools/c00/install_openjdk17.sh" \
				--download || online_status=$?
		fi
		if [[ -x "$jdk_home/bin/java" && -x "$jdk_home/bin/keytool" ]]; then
			export GODOT_JAVA_SDK_PATH="$jdk_home"
			export JAVA_HOME="$jdk_home"
		fi
		export GODOT_ANDROID_SDK_PATH="$android_sdk"
		export ANDROID_SDK_ROOT="$android_sdk"
		if online_dep_enabled android-sdk; then
			run_step "install Android SDK packages" \
				"$PROJECT_ROOT/tools/c00/install_android_sdk_packages.sh" \
				--android-sdk "$android_sdk" \
				--download-cmdline-tools \
				--yes || online_status=$?
		fi
		if online_dep_enabled android-export; then
			run_step "configure Android export environment" \
				"$PROJECT_ROOT/tools/c00/configure_android_export_environment.sh" \
				--android-sdk "$android_sdk" \
				--install-build-template || online_status=$?
		fi
	fi
	run_step "write device environment" write_device_env_from_current_machine || online_status=$?
	source_env_if_present
	return "$online_status"
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

	if [[ "$RUN_ONLINE_DEPS" == "1" ]]; then
		run_online_dependency_setup || status=$?
	fi

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
		local cycle_ready=1
		if [[ "$WAIT_FOR_DEVICES" == "1" ]]; then
			local wait_args=(
				"$PROJECT_ROOT/tools/c00/wait_for_device_ready.sh"
				--gate "$GATE"
				--timeout "$WAIT_TIMEOUT_SECONDS"
				--interval "$WAIT_INTERVAL_SECONDS"
			)
			if [[ "$GATE" == "ipad" || "$GATE" == "all" ]]; then
				if [[ -n "$DEVICE" ]]; then
					wait_args+=(--device "$DEVICE")
				fi
			fi
			run_step "wait for device readiness" "${wait_args[@]}" || {
				status=$?
				cycle_ready=0
			}
		fi

		local cycle_args=("$PROJECT_ROOT/tools/c00/run_device_cycle.sh" "$GATE")
		if [[ "$GATE" == "ipad" || "$GATE" == "all" ]]; then
			if [[ -n "$DEVICE" ]]; then
				cycle_args+=("$DEVICE")
			fi
		fi
		if [[ "$cycle_ready" != "1" ]]; then
			echo "Skipping device cycle because device readiness did not pass."
		elif [[ "$DRY_RUN" == "1" ]]; then
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
		if [[ "$RUN_READINESS" == "1" ]]; then
			echo "  $(project_path "$READINESS_REPORT")"
		fi
		if [[ "$RUN_STATIC_GATES" == "1" ]]; then
			echo "  $(project_path "$STATIC_REPORT")"
		fi
		if [[ "$WAIT_FOR_DEVICES" == "1" ]]; then
			echo "  releases/phase_0_smoke/evidence/device-ready-${GATE}-*.md"
		fi
		if [[ "$RUN_COMPLETION_AUDIT" == "1" ]]; then
			echo "  $(project_path "$AUDIT_REPORT")"
		fi
	fi
	exit "$status"
}

main
