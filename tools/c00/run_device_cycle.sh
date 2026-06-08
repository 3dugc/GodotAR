#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GATE="${1:-}"
DEVICE="${2:-${DEVICE:-}}"
DEFAULT_GODOT_SOURCE_DIR="$PROJECT_ROOT/.godot/cache/c00/godot-source"
DEFAULT_DEVICE_ENV_FILE="$PROJECT_ROOT/.godot/cache/c00/device-env.sh"

source_device_env_if_present() {
	local env_file="${C00_DEVICE_ENV_FILE:-$DEFAULT_DEVICE_ENV_FILE}"
	if [[ "${C00_AUTO_SOURCE_DEVICE_ENV:-1}" == "1" && -f "$env_file" ]]; then
		# shellcheck disable=SC1090
		source "$env_file"
	fi
}

source_device_env_if_present

PACKAGE="${PACKAGE:-org.godotengine.godotxrfoundation}"
DURATION="${DURATION:-30}"
RUN_PREFLIGHT="${RUN_PREFLIGHT:-1}"
RUN_EXPORT="${RUN_EXPORT:-1}"
RUN_COLLECT="${RUN_COLLECT:-1}"
DRY_RUN="${DRY_RUN:-0}"
BUILD_ARKIT_PLUGIN="${BUILD_ARKIT_PLUGIN:-auto}"
BUILD_IPAD_APP="${BUILD_IPAD_APP:-auto}"
INCLUDE_EDITOR_SIM="${INCLUDE_EDITOR_SIM:-0}"
INCLUDE_IOS_SIMULATOR="${INCLUDE_IOS_SIMULATOR:-0}"
INCLUDE_ANDROID_ARCORE="${INCLUDE_ANDROID_ARCORE:-1}"
CONTINUE_ON_FAILURE="${CONTINUE_ON_FAILURE:-auto}"
RUN_PHASE_VERIFY="${RUN_PHASE_VERIFY:-1}"
PHASE_REPORT="${PHASE_REPORT:-releases/phase_0_smoke/C00_PHASE_REPORT.md}"
PHASE_GATES="${PHASE_GATES:-auto}"

ROKID_PRESET="${ROKID_PRESET:-C00 Rokid OpenXR}"
ROKID_APK_PATH="${ROKID_APK_PATH:-builds/rokid/c00.apk}"
ANDROID_ARCORE_PRESET="${ANDROID_ARCORE_PRESET:-C00 Android ARCore}"
ANDROID_ARCORE_APK_PATH="${ANDROID_ARCORE_APK_PATH:-builds/android_arcore/c00.apk}"
IPAD_PRESET="${IPAD_PRESET:-C00 iPad ARKit}"
IPAD_EXPORT_PATH="${IPAD_EXPORT_PATH:-builds/ipad/c00.zip}"
IPAD_APP_PATH="${IPAD_APP_PATH:-builds/ipad/GodotXRFoundation.app}"
IOS_SIMULATOR_EXPORT_PATH="${IOS_SIMULATOR_EXPORT_PATH:-builds/ios_simulator/c00.zip}"
IOS_SIMULATOR_APP_PATH="${IOS_SIMULATOR_APP_PATH:-builds/ios_simulator/GodotXRFoundation.app}"
SIMULATOR_DEVICE="${SIMULATOR_DEVICE:-booted}"

usage() {
	cat <<EOF
Usage:
  tools/c00/run_device_cycle.sh <editor|ios-simulator|rokid|ipad|android-arcore|all> [ipad-device]

Examples:
  tools/c00/run_device_cycle.sh editor
  APP_PATH=builds/ios_simulator/GodotXRFoundation.app tools/c00/run_device_cycle.sh ios-simulator
  tools/c00/run_device_cycle.sh rokid
  GODOT_SOURCE_DIR=/path/to/godot DEVICE=<ipad-uuid-or-name> tools/c00/run_device_cycle.sh ipad
  APP_PATH=builds/ipad/GodotXRFoundation.app tools/c00/run_device_cycle.sh ipad <ipad-device>

Common environment:
  GODOT_BIN=/path/to/Godot
  PACKAGE=org.godotengine.godotxrfoundation
  DURATION=30
  RUN_PREFLIGHT=1
  RUN_EXPORT=1
  RUN_COLLECT=1
  DRY_RUN=1                         Resolve and print actions without running Godot/Xcode/device commands.

Evidence:
  CAPTURE_MEDIA=1                  Capture screenshot/recording where supported.
  VIDEO_SECONDS=15                 Android/Rokid screen recording length.
  ANDROID_FORCE_STOP=1             Force-stop Android/Rokid app before launch so APK _cl_ args are re-read.
  MANUAL_MEDIA_PATH=/path/file     iPad fallback screenshot or recording when automatic capture is unavailable.
  ALLOW_MISSING_MEDIA=1            Keep collecting/reporting even when media evidence is missing.

iPad / ARKit:
  GODOT_SOURCE_DIR=/path/to/godot     Build GodotARKit.xcframework before export.
  GODOT_TAG=4.4.1-stable             Optional source tag for automatic source preparation.
  AUTO_PREPARE_GODOT_SOURCE=auto|1|0 Default auto: prepare only when GODOT_TAG/BRANCH/COMMIT is set.
  BUILD_ARKIT_PLUGIN=auto|1|0        Default auto: build only when GODOT_SOURCE_DIR is set.
  BUILD_IPAD_APP=auto|1|0            Build exported Xcode project into .app when APP_PATH is empty.
  IPAD_APP_PATH="$IPAD_APP_PATH"
  IOS_SIMULATOR_EXPORT_PATH="$IOS_SIMULATOR_EXPORT_PATH"
  IOS_SIMULATOR_APP_PATH="$IOS_SIMULATOR_APP_PATH"
  SIMULATOR_DEVICE=booted              iOS Simulator UDID or booted alias.
  SCHEME=<xcode-scheme>              Optional Xcode scheme for the exported project.
  TARGET_NAME=<xcode-target>         Optional target fallback when no scheme exists.
  APP_PATH=builds/ipad/App.app       Optional installed app bundle for devicectl.

Rokid / Android:
  APK_PATH=builds/rokid/c00.apk      Optional APK override for install/collect.
  ROKID_PRESET="$ROKID_PRESET"
  ROKID_APK_PATH="$ROKID_APK_PATH"

All:
  Runs ipad, rokid, then android-arcore. Set INCLUDE_ANDROID_ARCORE=0 to skip Android ARCore.
  INCLUDE_EDITOR_SIM=1             Run the local EditorSim gate before device gates.
  INCLUDE_IOS_SIMULATOR=1          Run iOS Simulator development gate before device gates.
  CONTINUE_ON_FAILURE=auto|1|0     Default auto continues in all mode so every device can produce evidence.
  RUN_PHASE_VERIFY=1               Run verify_phase_evidence.js after all gates.
  PHASE_REPORT="$PHASE_REPORT"
  PHASE_GATES=rokid,ipad,android-arcore Override aggregate verifier gate list.
EOF
}

if [[ "$GATE" == "-h" || "$GATE" == "--help" ]]; then
	usage
	exit 0
fi

case "$GATE" in
	editor|ios-simulator|rokid|ipad|android-arcore|all)
		;;
	*)
		usage >&2
		exit 2
		;;
esac

project_path() {
	local path="$1"
	case "$path" in
		/*) printf "%s\n" "$path" ;;
		*) printf "%s/%s\n" "$PROJECT_ROOT" "$path" ;;
	esac
}

is_valid_godot_source() {
	local dir="$1"
	[[ -f "$dir/core/version.h" \
		&& -f "$dir/core/object/class_db.h" \
		&& -f "$dir/core/config/engine.h" \
		&& -d "$dir/platform/ios" ]]
}

resolve_godot_source_for_arkit() {
	local source="${GODOT_SOURCE_DIR:-${GODOT_SRC_DIR:-}}"
	if [[ -n "$source" ]]; then
		if ! is_valid_godot_source "$source"; then
			echo "GODOT_SOURCE_DIR is set but is not a valid Godot source tree: $source" >&2
			return 1
		fi
		GODOT_SOURCE_DIR="$(cd "$source" && pwd)"
		export GODOT_SOURCE_DIR
		return 0
	fi

	if is_valid_godot_source "$DEFAULT_GODOT_SOURCE_DIR"; then
		GODOT_SOURCE_DIR="$DEFAULT_GODOT_SOURCE_DIR"
		export GODOT_SOURCE_DIR
		echo "Using prepared Godot source tree: $GODOT_SOURCE_DIR"
		return 0
	fi

	local auto_prepare="${AUTO_PREPARE_GODOT_SOURCE:-auto}"
	if [[ "$auto_prepare" == "0" ]]; then
		return 1
	fi
	if [[ "$auto_prepare" == "auto" \
		&& -z "${GODOT_TAG:-}" \
		&& -z "${GODOT_BRANCH:-}" \
		&& -z "${GODOT_COMMIT:-}" ]]; then
		return 1
	fi

	local prepare_args=(--dir "$DEFAULT_GODOT_SOURCE_DIR" --no-env)
	if [[ -n "${GODOT_TAG:-}" ]]; then
		prepare_args+=(--tag "$GODOT_TAG")
	fi
	if [[ -n "${GODOT_BRANCH:-}" ]]; then
		prepare_args+=(--branch "$GODOT_BRANCH")
	fi
	if [[ -n "${GODOT_COMMIT:-}" ]]; then
		prepare_args+=(--commit "$GODOT_COMMIT")
	fi
	if [[ -n "${GODOT_REPO:-}" ]]; then
		prepare_args+=(--repo "$GODOT_REPO")
	fi

	echo "Preparing Godot source headers for ARKit plugin..."
	if [[ "$DRY_RUN" == "1" ]]; then
		echo "DRY RUN: $PROJECT_ROOT/tools/c00/prepare_godot_source.sh ${prepare_args[*]}"
		GODOT_SOURCE_DIR="$DEFAULT_GODOT_SOURCE_DIR"
		export GODOT_SOURCE_DIR
		return 0
	fi
	"$PROJECT_ROOT/tools/c00/prepare_godot_source.sh" "${prepare_args[@]}"
	GODOT_SOURCE_DIR="$DEFAULT_GODOT_SOURCE_DIR"
	export GODOT_SOURCE_DIR
}

build_arkit_plugin_if_requested() {
	if [[ "$BUILD_ARKIT_PLUGIN" == "0" ]]; then
		return
	fi

	if ! resolve_godot_source_for_arkit; then
		if [[ "$BUILD_ARKIT_PLUGIN" == "1" ]]; then
			echo "Godot source headers are required to build GodotARKit.xcframework." >&2
			echo "Run tools/c00/prepare_godot_source.sh --tag <godot-tag>, or set GODOT_SOURCE_DIR." >&2
			return 2
		fi
		echo "No Godot source headers found; skipping ARKit plugin build in auto mode."
		return
	fi

	echo "Building ARKit iOS plugin..."
	if [[ "$DRY_RUN" == "1" ]]; then
		echo "DRY RUN: GODOT_SOURCE_DIR=$GODOT_SOURCE_DIR ios/plugins/godot_arkit/build_xcframework.sh"
		return
	fi
	"$PROJECT_ROOT/ios/plugins/godot_arkit/build_xcframework.sh"
}

build_ipad_app_if_requested() {
	if [[ "$BUILD_IPAD_APP" == "0" ]]; then
		return
	fi
	if [[ -n "${APP_PATH:-}" ]]; then
		echo "APP_PATH is already set; skipping iPad Xcode build: $APP_PATH"
		return
	fi

	local export_zip
	export_zip="$(project_path "$IPAD_EXPORT_PATH")"
	local app_output
	app_output="$(project_path "$IPAD_APP_PATH")"
	if [[ "$DRY_RUN" == "1" ]]; then
		echo "DRY RUN: APP_OUTPUT_PATH=$app_output tools/c00/build_ios_xcode_project.sh $export_zip $DEVICE"
		APP_PATH="$app_output"
		export APP_PATH
		return
	fi
	if [[ ! -f "$export_zip" ]]; then
		if [[ "$BUILD_IPAD_APP" == "1" ]]; then
			echo "iPad export zip is missing: $export_zip" >&2
			return 2
		fi
		echo "iPad export zip is missing; assuming $PACKAGE is already installed on the device."
		return
	fi
	if [[ "$BUILD_IPAD_APP" == "auto" ]] && ! command -v xcodebuild >/dev/null 2>&1; then
		echo "xcodebuild not found; assuming $PACKAGE is already installed on the device."
		return
	fi

	echo "Building iPad Xcode export into app bundle..."
	APP_OUTPUT_PATH="$app_output" "$PROJECT_ROOT/tools/c00/build_ios_xcode_project.sh" "$export_zip" "$DEVICE"
	APP_PATH="$app_output"
	export APP_PATH
}

build_ios_simulator_app_if_requested() {
	if [[ -n "${APP_PATH:-}" ]]; then
		echo "APP_PATH is already set; skipping iOS Simulator Xcode build: $APP_PATH"
		return
	fi

	local export_zip
	export_zip="$(project_path "$IOS_SIMULATOR_EXPORT_PATH")"
	local app_output
	app_output="$(project_path "$IOS_SIMULATOR_APP_PATH")"
	if [[ "$DRY_RUN" == "1" ]]; then
		echo "DRY RUN: IOS_BUILD_PLATFORM=simulator APP_OUTPUT_PATH=$app_output tools/c00/build_ios_xcode_project.sh $export_zip"
		APP_PATH="$app_output"
		export APP_PATH
		return
	fi
	if [[ ! -f "$export_zip" ]]; then
		echo "iOS Simulator export zip is missing: $export_zip" >&2
		return 2
	fi
	if ! command -v xcodebuild >/dev/null 2>&1; then
		echo "xcodebuild not found; cannot build iOS Simulator app." >&2
		return 2
	fi

	echo "Building iOS Simulator Xcode export into app bundle..."
	IOS_BUILD_PLATFORM=simulator \
	ALLOW_PROVISIONING_UPDATES=0 \
	CODE_SIGN_STYLE="" \
	CODE_SIGNING_ALLOWED=NO \
	BUILD_ROOT="$PROJECT_ROOT/builds/ios_simulator/xcode" \
	DERIVED_DATA_PATH="$PROJECT_ROOT/builds/ios_simulator/DerivedData" \
	APP_OUTPUT_PATH="$app_output" \
		"$PROJECT_ROOT/tools/c00/build_ios_xcode_project.sh" "$export_zip"
	APP_PATH="$app_output"
	export APP_PATH
}

run_preflight() {
	local gate="$1"
	if [[ "$RUN_PREFLIGHT" == "0" ]]; then
		return
	fi
	if [[ "$DRY_RUN" == "1" ]]; then
		echo "DRY RUN: tools/c00/preflight.sh $gate"
		return
	fi
	"$PROJECT_ROOT/tools/c00/preflight.sh" "$gate"
}

run_export() {
	local gate="$1"
	if [[ "$RUN_EXPORT" == "0" ]]; then
		return
	fi
	if [[ "$DRY_RUN" == "1" ]]; then
		case "$gate" in
			rokid)
				echo "DRY RUN: tools/c00/export_with_godot.sh \"$ROKID_PRESET\" \"${APK_PATH:-$ROKID_APK_PATH}\""
				;;
			android-arcore)
				echo "DRY RUN: tools/c00/export_with_godot.sh \"$ANDROID_ARCORE_PRESET\" \"${APK_PATH:-$ANDROID_ARCORE_APK_PATH}\""
				;;
			ipad)
				echo "DRY RUN: tools/c00/export_with_godot.sh \"$IPAD_PRESET\" \"$IPAD_EXPORT_PATH\""
				;;
			ios-simulator)
				echo "DRY RUN: tools/c00/export_with_godot.sh \"$IPAD_PRESET\" \"$IOS_SIMULATOR_EXPORT_PATH\""
				;;
			editor)
				echo "DRY RUN: editor gate export skipped"
				;;
		esac
		return
	fi

	case "$gate" in
		rokid)
			"$PROJECT_ROOT/tools/c00/export_with_godot.sh" "$ROKID_PRESET" "${APK_PATH:-$ROKID_APK_PATH}"
			;;
		android-arcore)
			"$PROJECT_ROOT/tools/c00/export_with_godot.sh" "$ANDROID_ARCORE_PRESET" "${APK_PATH:-$ANDROID_ARCORE_APK_PATH}"
			;;
		ipad)
			if [[ -n "${APP_PATH:-}" ]]; then
				echo "APP_PATH is already set; skipping iPad export: $APP_PATH"
				return
			fi
			"$PROJECT_ROOT/tools/c00/export_with_godot.sh" "$IPAD_PRESET" "$IPAD_EXPORT_PATH"
			;;
		ios-simulator)
			if [[ -n "${APP_PATH:-}" ]]; then
				echo "APP_PATH is already set; skipping iOS Simulator export: $APP_PATH"
				return
			fi
			"$PROJECT_ROOT/tools/c00/export_with_godot.sh" "$IPAD_PRESET" "$IOS_SIMULATOR_EXPORT_PATH"
			;;
		editor)
			echo "EditorSim gate does not require export."
			;;
	esac
}

run_collect() {
	local gate="$1"
	if [[ "$RUN_COLLECT" == "0" ]]; then
		return
	fi
	if [[ "$DRY_RUN" == "1" ]]; then
		case "$gate" in
			editor)
				echo "DRY RUN: tools/c00/collect_editor_smoke.sh $DURATION"
				;;
			ios-simulator)
				echo "DRY RUN: APP_PATH=${APP_PATH:-$IOS_SIMULATOR_APP_PATH} tools/c00/collect_ios_simulator_smoke.sh $SIMULATOR_DEVICE $PACKAGE $DURATION"
				;;
			rokid)
				echo "DRY RUN: APK_PATH=${APK_PATH:-$(project_path "$ROKID_APK_PATH")} tools/c00/collect_android_smoke.sh rokid $PACKAGE $DURATION"
				;;
			android-arcore)
				echo "DRY RUN: APK_PATH=${APK_PATH:-$(project_path "$ANDROID_ARCORE_APK_PATH")} tools/c00/collect_android_smoke.sh android-arcore $PACKAGE $DURATION"
				;;
			ipad)
				echo "DRY RUN: APP_PATH=${APP_PATH:-$IPAD_APP_PATH} tools/c00/collect_ios_smoke.sh ${DEVICE:-<ipad-device>} $PACKAGE $DURATION"
				;;
		esac
		return
	fi

	case "$gate" in
		editor)
			"$PROJECT_ROOT/tools/c00/collect_editor_smoke.sh" "$DURATION"
			;;
		ios-simulator)
			if [[ -z "${APP_PATH:-}" ]]; then
				echo "APP_PATH is empty; expected iOS Simulator .app from the build step." >&2
				exit 2
			fi
			"$PROJECT_ROOT/tools/c00/collect_ios_simulator_smoke.sh" "$SIMULATOR_DEVICE" "$PACKAGE" "$DURATION"
			;;
		rokid)
			local apk_path="${APK_PATH:-$(project_path "$ROKID_APK_PATH")}"
			APK_PATH="$apk_path" "$PROJECT_ROOT/tools/c00/collect_android_smoke.sh" rokid "$PACKAGE" "$DURATION"
			;;
		android-arcore)
			local apk_path="${APK_PATH:-$(project_path "$ANDROID_ARCORE_APK_PATH")}"
			APK_PATH="$apk_path" "$PROJECT_ROOT/tools/c00/collect_android_smoke.sh" android-arcore "$PACKAGE" "$DURATION"
			;;
		ipad)
			if [[ -z "$DEVICE" ]]; then
				echo "iPad device is required for collection. Run: xcrun devicectl list devices" >&2
				exit 2
			fi
			if [[ -z "${APP_PATH:-}" ]]; then
				echo "APP_PATH is empty; assuming $PACKAGE is already installed on $DEVICE."
			fi
			"$PROJECT_ROOT/tools/c00/collect_ios_smoke.sh" "$DEVICE" "$PACKAGE" "$DURATION"
			;;
	esac
}

run_gate() {
	local gate="$1"
	echo
	echo "== C00 gate: $gate =="
	if [[ "$gate" == "ipad" || "$gate" == "ios-simulator" ]]; then
		build_arkit_plugin_if_requested || return $?
	fi
	run_preflight "$gate" || return $?
	run_export "$gate" || return $?
	if [[ "$gate" == "ipad" ]]; then
		build_ipad_app_if_requested || return $?
	fi
	if [[ "$gate" == "ios-simulator" ]]; then
		build_ios_simulator_app_if_requested || return $?
	fi
	run_collect "$gate" || return $?
}

run_gate_for_all() {
	local gate="$1"
	set +e
	run_gate "$gate"
	local status="$?"
	set -e

	if [[ "$status" -eq 0 ]]; then
		echo "== C00 gate passed: $gate =="
		return 0
	fi

	ALL_GATE_STATUS=1
	echo "== C00 gate failed: $gate (exit $status) ==" >&2
	if [[ "$CONTINUE_ON_FAILURE" == "0" ]]; then
		return "$status"
	fi
	return 0
}

run_phase_verify() {
	if [[ "$RUN_PHASE_VERIFY" == "0" ]]; then
		return 0
	fi
	if [[ "$DRY_RUN" == "1" ]]; then
		echo
		echo "DRY RUN: tools/c00/verify_phase_evidence.js --report $(project_path "$PHASE_REPORT")"
		return 0
	fi

	echo
	echo "== C00 phase evidence verify =="
	local gate_args=()
	if [[ "$PHASE_GATES" == "auto" ]]; then
		gate_args+=(--gate rokid --gate ipad)
		if [[ "$INCLUDE_ANDROID_ARCORE" == "1" ]]; then
			gate_args+=(--gate android-arcore)
		fi
	else
		local phase_gate
		IFS=',' read -r -a phase_gates <<< "$PHASE_GATES"
		for phase_gate in "${phase_gates[@]}"; do
			phase_gate="${phase_gate//[[:space:]]/}"
			if [[ -n "$phase_gate" ]]; then
				gate_args+=(--gate "$phase_gate")
			fi
		done
	fi
	node "$PROJECT_ROOT/tools/c00/verify_phase_evidence.js" \
		--report "$(project_path "$PHASE_REPORT")" \
		"${gate_args[@]}"
}

if [[ "$GATE" == "all" ]]; then
	ALL_GATE_STATUS=0
	phase_status=0
	if [[ "$INCLUDE_EDITOR_SIM" == "1" ]]; then
		run_gate_for_all editor || phase_status="$?"
		if [[ "$phase_status" != "0" && "$CONTINUE_ON_FAILURE" == "0" ]]; then
			exit "$phase_status"
		fi
	fi
	if [[ "$INCLUDE_IOS_SIMULATOR" == "1" ]]; then
		run_gate_for_all ios-simulator || phase_status="$?"
		if [[ "$phase_status" != "0" && "$CONTINUE_ON_FAILURE" == "0" ]]; then
			exit "$phase_status"
		fi
	fi
	run_gate_for_all ipad || phase_status="$?"
	if [[ "$phase_status" != "0" && "$CONTINUE_ON_FAILURE" == "0" ]]; then
		exit "$phase_status"
	fi
	run_gate_for_all rokid || phase_status="$?"
	if [[ "$phase_status" != "0" && "$CONTINUE_ON_FAILURE" == "0" ]]; then
		exit "$phase_status"
	fi
	if [[ "$INCLUDE_ANDROID_ARCORE" == "1" ]]; then
		run_gate_for_all android-arcore || phase_status="$?"
		if [[ "$phase_status" != "0" && "$CONTINUE_ON_FAILURE" == "0" ]]; then
			exit "$phase_status"
		fi
	fi
	if [[ "$phase_status" == "0" ]]; then
		phase_status="$ALL_GATE_STATUS"
	fi

	if ! run_phase_verify; then
		phase_status=1
	fi
	exit "$phase_status"
else
	run_gate "$GATE"
fi
