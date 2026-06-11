#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
. "$PROJECT_ROOT/tools/c00/godot_version_defaults.sh"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

BUNDLE_DIR="${BUNDLE_DIR:-}"
ENV_FILE="${ENV_FILE:-$PROJECT_ROOT/.godot/cache/c00/device-env.sh}"
DEFAULT_DEVICE_ENV_FILE="$PROJECT_ROOT/.godot/cache/c00/device-env.sh"
DEFAULT_LATEST_DEVICE_ENV_FILE="$PROJECT_ROOT/.godot/cache/c00/device-env-latest.sh"
DEFAULT_IOS_STABLE_FALLBACK_DEVICE_ENV_FILE="$PROJECT_ROOT/.godot/cache/c00/device-env-ios-stable-fallback.sh"
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
INCLUDE_PLACE_DEMOS="${INCLUDE_PLACE_DEMOS:-1}"
WAIT_FOR_DEVICES="${WAIT_FOR_DEVICES:-0}"
AUTO_RECOVER_DEVICES="${AUTO_RECOVER_DEVICES:-1}"
SPLIT_ALL_DEVICE_CYCLE="${SPLIT_ALL_DEVICE_CYCLE:-1}"
WAIT_TIMEOUT_SECONDS="${WAIT_TIMEOUT_SECONDS:-300}"
WAIT_INTERVAL_SECONDS="${WAIT_INTERVAL_SECONDS:-5}"
DRY_RUN="${DRY_RUN:-0}"
CONTINUE_AFTER_CYCLE="${CONTINUE_AFTER_CYCLE:-1}"
RUN_PHASE_VERIFY="${RUN_PHASE_VERIFY:-1}"

GATE="${GATE:-all}"
DEVICE="${DEVICE:-}"
PACKAGE="${PACKAGE:-org.godotengine.godotxrfoundation}"
PHASE_REPORT="${PHASE_REPORT:-$PROJECT_ROOT/releases/phase_0_smoke/C00_PHASE_REPORT.md}"

usage() {
	cat <<EOF
Usage:
  tools/c00/run_phase1_device_lab.sh [options]

Options:
  --bundle <dir>          Import an offline dependency bundle before running gates.
  --online-deps           Install/resume online C00 dependencies before readiness.
  --online-deps-list <list>
                          Online dependency subset: auto or comma/space list of editor,templates,jdk,android-sdk,android-export.
  --online-deps-only      Run online dependency setup only, then exit.
  --env-file <file>       Environment file written/read by bundle importer. Default: $ENV_FILE
  --gate <gate>           Device cycle gate: all, rokid, rokid-place, ipad, ipad-place, android-arcore, editor, ios-simulator, ios-simulator-place. Default: all
  --device <id-or-name>   iPad device id/name forwarded to run_device_cycle.sh.
  --include-place-demos   In all mode, run and audit C02/C04 rokid-place/ipad-place gates. Default.
  --no-place-demos        In all mode, only run/audit base smoke gates.
  --wait-devices          Wait for selected devices to become ready before running the device cycle.
  --recover-devices       After readiness timeout, run iPad DDI and/or Android ADB recovery, then wait once more. Default.
  --no-recover-devices    Disable automatic recovery after readiness timeout.
  --split-all-devices     In --gate all + --wait-devices mode, wait/recover/run each device group independently. Default.
  --no-split-all-devices  In --gate all + --wait-devices mode, require all devices ready before running any gate.
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
  ONLINE_DEPS=auto|editor,templates,jdk,android-sdk,android-export
  RUN_READINESS=1|0
  RUN_STATIC_GATES=1|0
  RUN_DEVICE_CYCLE=1|0
  RUN_COMPLETION_AUDIT=1|0
  INCLUDE_PLACE_DEMOS=1|0
  WAIT_FOR_DEVICES=1|0
  AUTO_RECOVER_DEVICES=1|0
  SPLIT_ALL_DEVICE_CYCLE=1|0
  WAIT_TIMEOUT_SECONDS=300
  WAIT_INTERVAL_SECONDS=5
  CONTINUE_AFTER_CYCLE=1|0
  RUN_PHASE_VERIFY=1|0

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
		--include-place-demos)
			INCLUDE_PLACE_DEMOS=1
			shift
			;;
		--no-place-demos)
			INCLUDE_PLACE_DEMOS=0
			shift
			;;
		--wait-devices)
			WAIT_FOR_DEVICES=1
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
		--split-all-devices)
			SPLIT_ALL_DEVICE_CYCLE=1
			shift
			;;
		--no-split-all-devices)
			SPLIT_ALL_DEVICE_CYCLE=0
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
	all|editor|ios-simulator|ios-simulator-place|rokid|rokid-place|ipad|ipad-place|android-arcore)
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
		local preserved=()
		local had_templates_version="${GODOT_EXPORT_TEMPLATES_VERSION+x}"
		local had_templates_dir="${GODOT_EXPORT_TEMPLATES_DIR+x}"
		local name
		for name in GODOT_EXPORT_TEMPLATES_VERSION GODOT_EXPORT_TEMPLATES_DIR GODOT_BIN GODOT_SOURCE_DIR GODOT_SRC_DIR GODOT_TAG GODOT_BRANCH GODOT_COMMIT GODOT_ANDROID_SDK_PATH ANDROID_SDK_ROOT ANDROID_HOME GODOT_JAVA_SDK_PATH JAVA_HOME GODOT_ANDROID_KEYSTORE_DEBUG_PATH ADB_BIN SDKMANAGER PACKAGE BUNDLE_ID TEAM_ID DEVICE APP_PATH APK_PATH; do
			if [[ -n "${!name+x}" ]]; then
				preserved+=("$name=${!name}")
			fi
		done
		# shellcheck disable=SC1090
		source "$env_path"
		local assignment
		if [[ "${#preserved[@]}" -gt 0 ]]; then
			for assignment in "${preserved[@]}"; do
				export "$assignment"
			done
		fi
		if [[ -n "$had_templates_version" && -z "$had_templates_dir" ]]; then
			unset GODOT_EXPORT_TEMPLATES_DIR
		fi
	elif [[ "$RUN_IMPORT" == "0" ]]; then
		echo "No device environment file found: $env_path"
	fi
}

default_device_env_file_for_gate() {
	local gate="$1"
	case "$gate" in
		rokid|rokid-place|android-arcore)
			if [[ -f "$DEFAULT_LATEST_DEVICE_ENV_FILE" ]]; then
				printf "%s" "$DEFAULT_LATEST_DEVICE_ENV_FILE"
			else
				printf "%s" "$DEFAULT_DEVICE_ENV_FILE"
			fi
			;;
		ipad|ipad-place|ios-simulator|ios-simulator-place)
			if [[ -f "$DEFAULT_IOS_STABLE_FALLBACK_DEVICE_ENV_FILE" ]]; then
				printf "%s" "$DEFAULT_IOS_STABLE_FALLBACK_DEVICE_ENV_FILE"
			elif [[ -f "$DEFAULT_LATEST_DEVICE_ENV_FILE" ]]; then
				printf "%s" "$DEFAULT_LATEST_DEVICE_ENV_FILE"
			else
				printf "%s" "$DEFAULT_DEVICE_ENV_FILE"
			fi
			;;
		*)
			printf "%s" "$DEFAULT_DEVICE_ENV_FILE"
			;;
	esac
}

clear_split_gate_version_env() {
	if [[ "${C00_SPLIT_GATE_INHERIT_VERSION_ENV:-0}" == "1" ]]; then
		return
	fi

	unset GODOT_EXPORT_TEMPLATES_VERSION
	unset GODOT_EXPORT_TEMPLATES_DIR
	unset GODOT_BIN
	unset GODOT_SOURCE_DIR
	unset GODOT_SRC_DIR
	unset GODOT_TAG
	unset GODOT_BRANCH
	unset GODOT_COMMIT
}

needs_ios_dependencies() {
	[[ "$GATE" == "all" || "$GATE" == "ipad" || "$GATE" == "ipad-place" || "$GATE" == "ios-simulator" || "$GATE" == "ios-simulator-place" ]]
}

needs_android_dependencies() {
	[[ "$GATE" == "all" || "$GATE" == "rokid" || "$GATE" == "rokid-place" || "$GATE" == "android-arcore" ]]
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
		godot_normalize_template_version "$GODOT_EXPORT_TEMPLATES_VERSION"
	elif [[ -n "${GODOT_TAG:-}" ]]; then
		godot_template_version_from_tag "$GODOT_TAG"
	else
		printf "%s" "$C00_GODOT_DEFAULT_EXPORT_TEMPLATES_VERSION"
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
	local candidate expected actual
	expected="$(resolve_template_version)"
	for candidate in "${GODOT_SOURCE_DIR:-}" "${GODOT_SRC_DIR:-}" "$PROJECT_ROOT/.godot/cache/c00/godot-source"; do
		if [[ -z "$candidate" || ! -d "$candidate" ]]; then
			continue
		fi
		if [[ ! -f "$candidate/core/version.h" \
			|| ! -f "$candidate/core/object/class_db.h" \
			|| ! -f "$candidate/core/config/engine.h" \
			|| ! -d "$candidate/platform/ios" ]]; then
			echo "Skipping invalid Godot source headers in device env: $candidate" >&2
			continue
		fi
		actual="$(godot_source_template_version "$candidate" || true)"
		if [[ "$actual" != "$expected" ]]; then
			echo "Skipping Godot source headers in device env because version is $actual, expected $expected: $candidate" >&2
			continue
		fi
		printf "%s" "$candidate"
		return 0
	done
	return 0
}

write_device_env_from_current_machine() {
	local env_path templates_dir android_sdk jdk_home godot_bin godot_source debug_keystore version
	env_path="$(project_path "$ENV_FILE")"
	version="$(resolve_template_version)"
	templates_dir="$(resolve_export_templates_dir)"
	android_sdk="$(resolve_android_sdk_dir)"
	jdk_home="$(resolve_jdk_home)"
	godot_bin="$(resolve_godot_bin)"
	godot_source="$(resolve_godot_source_dir || true)"
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
	if online_dep_enabled editor && { needs_ios_dependencies || needs_android_dependencies; }; then
		run_step "install Godot editor" \
			"$PROJECT_ROOT/tools/c00/install_godot_editor.sh" \
			--download \
			--version "$version" || online_status=$?
	fi
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

readiness_gate_for_gate() {
	local gate="$1"
	case "$gate" in
		rokid-place)
			printf "rokid"
			;;
		ipad-place)
			printf "ipad"
			;;
		*)
			printf "%s" "$gate"
			;;
	esac
}

readiness_gate_for_selected_gate() {
	readiness_gate_for_gate "$GATE"
}

gate_needs_ipad_device_arg() {
	local gate="$1"
	[[ "$gate" == "ipad" || "$gate" == "ipad-place" || "$gate" == "all" ]]
}

wait_for_gate_readiness() {
	local gate="$1"
	local title="${1:-wait for device readiness}"
	local readiness_gate
	if [[ "$#" -gt 1 ]]; then
		title="$2"
	else
		title="wait for device readiness: $gate"
	fi
	readiness_gate="$(readiness_gate_for_gate "$gate")"
	local wait_args=(
		"$PROJECT_ROOT/tools/c00/wait_for_device_ready.sh"
		--gate "$readiness_gate"
		--package "$PACKAGE"
		--timeout "$WAIT_TIMEOUT_SECONDS"
		--interval "$WAIT_INTERVAL_SECONDS"
	)
	if gate_needs_ipad_device_arg "$gate"; then
		if [[ -n "$DEVICE" ]]; then
			wait_args+=(--device "$DEVICE")
		fi
	fi
	run_step "$title" "${wait_args[@]}"
}

wait_for_selected_devices() {
	wait_for_gate_readiness "$GATE" "${1:-wait for device readiness}"
}

run_android_adb_recovery() {
	local recovery_gate="$1"
	run_step "recover Android ADB transport: $recovery_gate" \
		node "$PROJECT_ROOT/tools/c00/recover_android_adb_transport.js" \
		--gate "$recovery_gate" \
		--package "$PACKAGE"
}

run_ipad_ddi_recovery() {
	if [[ -z "$DEVICE" ]]; then
		echo "Skipping iPad DDI recovery because --device / DEVICE is empty."
		return 1
	fi
	run_step "recover iPad DDI services" \
		node "$PROJECT_ROOT/tools/c00/recover_ios_ddi_services.js" \
		--device "$DEVICE" \
		--package "$PACKAGE"
}

run_device_recovery_for_gate() {
	local gate="$1"
	local recovery_status=0
	case "$gate" in
		rokid)
			run_android_adb_recovery rokid || recovery_status=$?
			;;
		rokid-place)
			run_android_adb_recovery rokid-place || recovery_status=$?
			;;
		android-arcore)
			run_android_adb_recovery android-arcore || recovery_status=$?
			;;
		ipad|ipad-place)
			run_ipad_ddi_recovery || recovery_status=$?
			;;
		all)
			run_android_adb_recovery rokid || recovery_status=$?
			run_android_adb_recovery android-arcore || recovery_status=$?
			run_ipad_ddi_recovery || recovery_status=$?
			;;
		*)
			echo "No automatic device recovery is defined for gate '$gate'."
			recovery_status=1
			;;
	esac
	return "$recovery_status"
}

run_device_recovery() {
	run_device_recovery_for_gate "$GATE"
}

wait_recover_for_gate() {
	local gate="$1"
	local wait_status=0
	wait_for_gate_readiness "$gate" "wait for device readiness: $gate" || wait_status=$?
	if [[ "$wait_status" != "0" && "$AUTO_RECOVER_DEVICES" == "1" ]]; then
		echo "Device readiness did not pass for '$gate'. Running automatic recovery once, then retrying readiness."
		run_device_recovery_for_gate "$gate" || true
		wait_status=0
		wait_for_gate_readiness "$gate" "retry wait for device readiness after recovery: $gate" || wait_status=$?
	fi
	return "$wait_status"
}

run_single_device_cycle() {
	local gate="$1"
	local gate_env_file="${C00_DEVICE_ENV_FILE:-$(default_device_env_file_for_gate "$gate")}"
	local cycle_args=("$PROJECT_ROOT/tools/c00/run_device_cycle.sh" "$gate")
	if gate_needs_ipad_device_arg "$gate"; then
		if [[ -n "$DEVICE" ]]; then
			cycle_args+=("$DEVICE")
		fi
	fi
	if [[ "$DRY_RUN" == "1" ]]; then
		echo
		echo "== Phase 1 device lab: device cycle ($gate) =="
		if [[ -f "$gate_env_file" ]]; then
			echo "DRY RUN: C00_DEVICE_ENV_FILE=$gate_env_file"
		fi
		(
			clear_split_gate_version_env
			if [[ -f "$gate_env_file" ]]; then
				export C00_DEVICE_ENV_FILE="$gate_env_file"
			fi
			INCLUDE_PLACE_DEMOS=0 RUN_PHASE_VERIFY=0 DRY_RUN=1 "${cycle_args[@]}"
		)
	else
		(
			clear_split_gate_version_env
			if [[ -f "$gate_env_file" ]]; then
				export C00_DEVICE_ENV_FILE="$gate_env_file"
			fi
			INCLUDE_PLACE_DEMOS=0 RUN_PHASE_VERIFY=0 DRY_RUN=0 "${cycle_args[@]}"
		)
	fi
}

run_cycle_group_after_readiness() {
	local readiness_gate="$1"
	shift
	local group_status=0
	local wait_status=0
	if [[ "$WAIT_FOR_DEVICES" == "1" ]]; then
		wait_recover_for_gate "$readiness_gate" || wait_status=$?
		if [[ "$wait_status" != "0" ]]; then
			echo "Skipping device cycle group '$readiness_gate' because readiness did not pass."
			return "$wait_status"
		fi
	fi
	local gate
	for gate in "$@"; do
		run_single_device_cycle "$gate" || group_status=$?
		if [[ "$group_status" != "0" && "$CONTINUE_AFTER_CYCLE" != "1" ]]; then
			return "$group_status"
		fi
	done
	return "$group_status"
}

run_phase_verify_after_split() {
	if [[ "$RUN_PHASE_VERIFY" == "0" ]]; then
		return 0
	fi
	local gate_args=(--gate rokid --gate ipad)
	if [[ "$INCLUDE_PLACE_DEMOS" == "1" ]]; then
		gate_args+=(--gate rokid-place --gate ipad-place)
	fi
	if [[ "${INCLUDE_ANDROID_ARCORE:-1}" == "1" ]]; then
		gate_args+=(--gate android-arcore)
	fi
	if [[ "$DRY_RUN" == "1" ]]; then
		echo
		printf "DRY RUN: tools/c00/verify_phase_evidence.js --report %q" "$(project_path "$PHASE_REPORT")"
		printf " %q" "${gate_args[@]}"
		printf "\n"
		return 0
	fi
	echo
	echo "== Phase 1 device lab: phase evidence verify =="
	node "$PROJECT_ROOT/tools/c00/verify_phase_evidence.js" \
		--report "$(project_path "$PHASE_REPORT")" \
		"${gate_args[@]}"
}

run_split_all_device_cycles() {
	local split_status=0
	local gate_status=0
	if [[ "${INCLUDE_EDITOR_SIM:-0}" == "1" ]]; then
		run_single_device_cycle editor || split_status=$?
	fi
	if [[ "${INCLUDE_IOS_SIMULATOR:-0}" == "1" ]]; then
		run_single_device_cycle ios-simulator || split_status=$?
		if [[ "$INCLUDE_PLACE_DEMOS" == "1" ]]; then
			run_single_device_cycle ios-simulator-place || split_status=$?
		fi
	fi

	local ipad_gates=(ipad)
	if [[ "$INCLUDE_PLACE_DEMOS" == "1" ]]; then
		ipad_gates+=(ipad-place)
	fi
	gate_status=0
	run_cycle_group_after_readiness ipad "${ipad_gates[@]}" || gate_status=$?
	if [[ "$gate_status" != "0" ]]; then
		split_status="$gate_status"
		if [[ "$CONTINUE_AFTER_CYCLE" != "1" ]]; then
			return "$split_status"
		fi
	fi

	local rokid_gates=(rokid)
	if [[ "$INCLUDE_PLACE_DEMOS" == "1" ]]; then
		rokid_gates+=(rokid-place)
	fi
	gate_status=0
	run_cycle_group_after_readiness rokid "${rokid_gates[@]}" || gate_status=$?
	if [[ "$gate_status" != "0" ]]; then
		split_status="$gate_status"
		if [[ "$CONTINUE_AFTER_CYCLE" != "1" ]]; then
			return "$split_status"
		fi
	fi

	if [[ "${INCLUDE_ANDROID_ARCORE:-1}" == "1" ]]; then
		gate_status=0
		run_cycle_group_after_readiness android-arcore android-arcore || gate_status=$?
		if [[ "$gate_status" != "0" ]]; then
			split_status="$gate_status"
			if [[ "$CONTINUE_AFTER_CYCLE" != "1" ]]; then
				return "$split_status"
			fi
		fi
	fi

	run_phase_verify_after_split || split_status=$?
	return "$split_status"
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
		if [[ "$GATE" == "all" && "$SPLIT_ALL_DEVICE_CYCLE" == "1" ]]; then
			run_split_all_device_cycles || status=$?
		else
			if [[ "$WAIT_FOR_DEVICES" == "1" ]]; then
				local wait_status=0
				wait_for_selected_devices "wait for device readiness" || wait_status=$?
				if [[ "$wait_status" != "0" && "$AUTO_RECOVER_DEVICES" == "1" ]]; then
					echo "Device readiness did not pass. Running automatic recovery once, then retrying readiness."
					run_device_recovery || true
					wait_status=0
					wait_for_selected_devices "retry wait for device readiness after recovery" || wait_status=$?
				fi
				if [[ "$wait_status" != "0" ]]; then
					status="$wait_status"
					cycle_ready=0
				fi
			fi

			local cycle_args=("$PROJECT_ROOT/tools/c00/run_device_cycle.sh" "$GATE")
			if [[ "$GATE" == "ipad" || "$GATE" == "ipad-place" || "$GATE" == "all" ]]; then
				if [[ -n "$DEVICE" ]]; then
					cycle_args+=("$DEVICE")
				fi
			fi
			if [[ "$cycle_ready" != "1" ]]; then
				echo "Skipping device cycle because device readiness did not pass."
			elif [[ "$DRY_RUN" == "1" ]]; then
				echo
				echo "== Phase 1 device lab: device cycle =="
				INCLUDE_PLACE_DEMOS="$INCLUDE_PLACE_DEMOS" DRY_RUN=1 "${cycle_args[@]}" || status=$?
			else
				INCLUDE_PLACE_DEMOS="$INCLUDE_PLACE_DEMOS" DRY_RUN=0 "${cycle_args[@]}" || status=$?
			fi
		fi
		if [[ "$status" != "0" && "$CONTINUE_AFTER_CYCLE" != "1" ]]; then
			exit "$status"
		fi
	fi

	if [[ "$RUN_COMPLETION_AUDIT" == "1" ]]; then
		local audit_args=(
			node "$PROJECT_ROOT/tools/c00/audit_phase1_completion.js"
			--report "$(project_path "$AUDIT_REPORT")"
			--json "$(project_path "$AUDIT_JSON")"
		)
		if [[ "$INCLUDE_PLACE_DEMOS" == "0" ]]; then
			audit_args+=(--skip-place-demos)
		else
			audit_args+=(--include-place-demos)
		fi
		run_step "completion audit" \
			"${audit_args[@]}" || status=$?
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
			if [[ "$GATE" == "all" && "$SPLIT_ALL_DEVICE_CYCLE" == "1" ]]; then
				echo "  releases/phase_0_smoke/evidence/device-ready-ipad-*.md"
				echo "  releases/phase_0_smoke/evidence/device-ready-rokid-*.md"
				echo "  releases/phase_0_smoke/evidence/device-ready-android-arcore-*.md"
			else
				echo "  releases/phase_0_smoke/evidence/device-ready-$(readiness_gate_for_selected_gate)-*.md"
			fi
			if [[ "$AUTO_RECOVER_DEVICES" == "1" ]]; then
				echo "  releases/phase_0_smoke/evidence/*-recovery-*.md"
			fi
		fi
		if [[ "$RUN_COMPLETION_AUDIT" == "1" ]]; then
			echo "  $(project_path "$AUDIT_REPORT")"
		fi
	fi
	exit "$status"
}

main
