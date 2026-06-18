#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
. "$PROJECT_ROOT/tools/c00/godot_version_defaults.sh"
GATE="${1:-}"
DEVICE="${2:-${DEVICE:-}}"
DEFAULT_GODOT_SOURCE_DIR="$PROJECT_ROOT/.godot/cache/c00/godot-source"
DEFAULT_DEVICE_ENV_FILE="$PROJECT_ROOT/.godot/cache/c00/device-env.sh"
DEFAULT_LATEST_DEVICE_ENV_FILE="$PROJECT_ROOT/.godot/cache/c00/device-env-latest.sh"
DEFAULT_IOS_STABLE_FALLBACK_DEVICE_ENV_FILE="$PROJECT_ROOT/.godot/cache/c00/device-env-ios-stable-fallback.sh"

default_device_env_file_for_gate() {
	local gate="${1:-$GATE}"
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

source_device_env_if_present() {
	local env_file="${C00_DEVICE_ENV_FILE:-$(default_device_env_file_for_gate)}"
	if [[ "${C00_AUTO_SOURCE_DEVICE_ENV:-1}" == "1" && -f "$env_file" ]]; then
		local preserved=()
		local had_templates_version="${GODOT_EXPORT_TEMPLATES_VERSION+x}"
		local had_templates_dir="${GODOT_EXPORT_TEMPLATES_DIR+x}"
		local name
		for name in GODOT_EXPORT_TEMPLATES_VERSION GODOT_EXPORT_TEMPLATES_DIR GODOT_BIN GODOT_SOURCE_DIR GODOT_SRC_DIR GODOT_TAG GODOT_BRANCH GODOT_COMMIT GODOT_ANDROID_SDK_PATH ANDROID_SDK_ROOT ANDROID_HOME GODOT_JAVA_SDK_PATH JAVA_HOME GODOT_ANDROID_KEYSTORE_DEBUG_PATH ADB_BIN ADB_SERIAL SDKMANAGER PACKAGE BUNDLE_ID TEAM_ID DEVICE APP_PATH APK_PATH; do
			if [[ -n "${!name+x}" ]]; then
				preserved+=("$name=${!name}")
			fi
		done
		# shellcheck disable=SC1090
		source "$env_file"
		local assignment
		if [[ "${#preserved[@]}" -gt 0 ]]; then
			for assignment in "${preserved[@]}"; do
				export "$assignment"
			done
		fi
		if [[ -n "$had_templates_version" && -z "$had_templates_dir" ]]; then
			unset GODOT_EXPORT_TEMPLATES_DIR
		fi
	fi
}

source_device_env_if_present

PACKAGE="${PACKAGE:-org.godotengine.godotxrfoundation}"
DURATION="${DURATION:-30}"
RUN_PREFLIGHT="${RUN_PREFLIGHT:-1}"
RUN_EXPORT="${RUN_EXPORT:-1}"
RUN_COLLECT="${RUN_COLLECT:-1}"
DRY_RUN="${DRY_RUN:-0}"
AUTO_SELECT_READY_DEVICE="${AUTO_SELECT_READY_DEVICE:-1}"
BUILD_ARKIT_PLUGIN="${BUILD_ARKIT_PLUGIN:-auto}"
BUILD_IPAD_APP="${BUILD_IPAD_APP:-auto}"
CONFIGURE_IPAD_SIGNING="${CONFIGURE_IPAD_SIGNING:-auto}"
INCLUDE_EDITOR_SIM="${INCLUDE_EDITOR_SIM:-0}"
INCLUDE_IOS_SIMULATOR="${INCLUDE_IOS_SIMULATOR:-0}"
INCLUDE_ANDROID_ARCORE="${INCLUDE_ANDROID_ARCORE:-1}"
INCLUDE_PLACE_DEMOS="${INCLUDE_PLACE_DEMOS:-0}"
CONTINUE_ON_FAILURE="${CONTINUE_ON_FAILURE:-auto}"
RUN_PHASE_VERIFY="${RUN_PHASE_VERIFY:-1}"
PHASE_REPORT="${PHASE_REPORT:-releases/phase_0_smoke/C00_PHASE_REPORT.md}"
PHASE_GATES="${PHASE_GATES:-auto}"

ROKID_PRESET="${ROKID_PRESET:-C00 Rokid OpenXR}"
ROKID_APK_PATH="${ROKID_APK_PATH:-builds/rokid/c00.apk}"
ROKID_PLACE_PRESET="${ROKID_PLACE_PRESET:-C02 Rokid OpenXR Place}"
ROKID_PLACE_APK_PATH="${ROKID_PLACE_APK_PATH:-builds/rokid/c02-place.apk}"
ANDROID_ARCORE_PRESET="${ANDROID_ARCORE_PRESET:-C00 Android ARCore}"
ANDROID_ARCORE_APK_PATH="${ANDROID_ARCORE_APK_PATH:-builds/android_arcore/c00.apk}"
IPAD_PRESET="${IPAD_PRESET:-C00 iPad ARKit}"
IPAD_EXPORT_PATH="${IPAD_EXPORT_PATH:-builds/ipad/c00.zip}"
IPAD_APP_PATH="${IPAD_APP_PATH:-builds/ipad/GodotXRFoundation.app}"
IPAD_PLACE_PRESET="${IPAD_PLACE_PRESET:-C04 iPad ARKit Place}"
IPAD_PLACE_EXPORT_PATH="${IPAD_PLACE_EXPORT_PATH:-builds/ipad/c04-place.zip}"
IPAD_PLACE_APP_PATH="${IPAD_PLACE_APP_PATH:-builds/ipad/GodotXRFoundation-C04.app}"
IOS_SIMULATOR_EXPORT_PATH="${IOS_SIMULATOR_EXPORT_PATH:-builds/ios_simulator/c00.zip}"
IOS_SIMULATOR_APP_PATH="${IOS_SIMULATOR_APP_PATH:-builds/ios_simulator/GodotXRFoundation.app}"
IOS_SIMULATOR_PLACE_EXPORT_PATH="${IOS_SIMULATOR_PLACE_EXPORT_PATH:-builds/ios_simulator/c04-place.zip}"
IOS_SIMULATOR_PLACE_APP_PATH="${IOS_SIMULATOR_PLACE_APP_PATH:-builds/ios_simulator/GodotXRFoundation-C04.app}"
SIMULATOR_DEVICE="${SIMULATOR_DEVICE:-booted}"

usage() {
	cat <<EOF
Usage:
  tools/c00/run_device_cycle.sh <editor|ios-simulator|ios-simulator-place|rokid|rokid-place|ipad|ipad-place|android-arcore|all> [ios-device]

Examples:
  tools/c00/run_device_cycle.sh editor
  APP_PATH=builds/ios_simulator/GodotXRFoundation.app tools/c00/run_device_cycle.sh ios-simulator
  APP_PATH=builds/ios_simulator/GodotXRFoundation-C04.app tools/c00/run_device_cycle.sh ios-simulator-place
  tools/c00/run_device_cycle.sh rokid
  tools/c00/run_device_cycle.sh rokid-place
  GODOT_SOURCE_DIR=/path/to/godot DEVICE=<ios-device-uuid-or-name> tools/c00/run_device_cycle.sh ipad
  GODOT_SOURCE_DIR=/path/to/godot DEVICE=<ios-device-uuid-or-name> tools/c00/run_device_cycle.sh ipad-place
  APP_PATH=builds/ipad/GodotXRFoundation.app tools/c00/run_device_cycle.sh ipad <ios-device>

Common environment:
  GODOT_BIN=/path/to/Godot
  PACKAGE=org.godotengine.godotxrfoundation
  DURATION=30
  RUN_PREFLIGHT=1
  RUN_EXPORT=1
  RUN_COLLECT=1
  DRY_RUN=1                         Resolve and print actions without running Godot/Xcode/device commands.
  AUTO_SELECT_READY_DEVICE=1        Auto-fill DEVICE/ADB_SERIAL from check_device_ready.js when not set.

Evidence:
  CAPTURE_MEDIA=1                  Capture screenshot/recording where supported.
  VIDEO_SECONDS=15                 Android/Rokid screen recording length.
  ANDROID_FORCE_STOP=1             Force-stop Android/Rokid app before launch so APK _cl_ args are re-read.
  MANUAL_MEDIA_PATH=/path/file     iOS fallback screenshot or recording when automatic capture is unavailable.
  ALLOW_MISSING_MEDIA=1            Keep collecting/reporting even when media evidence is missing.

iOS / ARKit:
  GODOT_SOURCE_DIR=/path/to/godot     Build GodotARKit.xcframework before export.
  GODOT_TAG=$C00_GODOT_LATEST_TAG             Optional source tag for automatic source preparation.
  AUTO_PREPARE_GODOT_SOURCE=auto|1|0 Default auto: prepare only when GODOT_TAG/BRANCH/COMMIT is set.
  BUILD_ARKIT_PLUGIN=auto|1|0        Default auto: build only when GODOT_SOURCE_DIR is set.
  CONFIGURE_IPAD_SIGNING=auto|1|0    Default auto: update iPad export presets when a Team ID env var is set.
  IPAD_TEAM_ID=<10-char-team-id>      Team ID alias for configure_ios_signing.js and xcodebuild.
                                      TEAM_ID, DEVELOPMENT_TEAM, and APPLE_TEAM_ID also work.
  BUILD_IPAD_APP=auto|1|0            Build exported Xcode project into .app when APP_PATH is empty.
  IPAD_APP_PATH="$IPAD_APP_PATH"
  IOS_XR_PLATFORM=ipad|iphone|ios    Optional runtime platform hint. Auto-detected from DEVICE when unset.
  IOS_SIMULATOR_EXPORT_PATH="$IOS_SIMULATOR_EXPORT_PATH"
  IOS_SIMULATOR_APP_PATH="$IOS_SIMULATOR_APP_PATH"
  IOS_SIMULATOR_PLACE_EXPORT_PATH="$IOS_SIMULATOR_PLACE_EXPORT_PATH"
  IOS_SIMULATOR_PLACE_APP_PATH="$IOS_SIMULATOR_PLACE_APP_PATH"
  SIMULATOR_DEVICE=booted              iOS Simulator UDID or booted alias.
  SCHEME=<xcode-scheme>              Optional Xcode scheme for the exported project.
  TARGET_NAME=<xcode-target>         Optional target fallback when no scheme exists.
  APP_PATH=builds/ipad/App.app       Optional installed app bundle for devicectl.

Rokid / Android:
  APK_PATH=builds/rokid/c00.apk      Optional APK override for install/collect.
  ROKID_PRESET="$ROKID_PRESET"
  ROKID_APK_PATH="$ROKID_APK_PATH"
  ROKID_PLACE_PRESET="$ROKID_PLACE_PRESET"
  ROKID_PLACE_APK_PATH="$ROKID_PLACE_APK_PATH"

All:
  Runs ipad, rokid, then android-arcore. Set INCLUDE_ANDROID_ARCORE=0 to skip Android ARCore.
  INCLUDE_PLACE_DEMOS=1           Also run ipad-place and rokid-place cycle demo gates.
  INCLUDE_EDITOR_SIM=1             Run the local EditorSim gate before device gates.
  INCLUDE_IOS_SIMULATOR=1          Run iOS Simulator development gate before device gates.
                                  With INCLUDE_PLACE_DEMOS=1, also runs ios-simulator-place.
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
	editor|ios-simulator|ios-simulator-place|rokid|rokid-place|ipad|ipad-place|android-arcore|all)
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

safe_gate_name() {
	printf "%s" "$1" | tr -c 'A-Za-z0-9_.-' '-'
}

gate_needs_ipad_device_arg() {
	case "$1" in
		ipad|ipad-place) return 0 ;;
		*) return 1 ;;
	esac
}

gate_uses_adb_serial() {
	case "$1" in
		rokid|rokid-place|android-arcore) return 0 ;;
		*) return 1 ;;
	esac
}

readiness_gate_for_gate() {
	case "$1" in
		rokid-place) printf "%s" "rokid" ;;
		ipad-place) printf "%s" "ipad" ;;
		*) printf "%s" "$1" ;;
	esac
}

resolve_ios_xr_platform_for_device() {
	local wanted="${1:-}"
	if [[ "$wanted" =~ [iI][pP]hone ]]; then
		printf "%s" "iphone"
		return
	fi
	if [[ "$wanted" =~ [iI][pP]ad ]]; then
		printf "%s" "ipad"
		return
	fi
	if command -v xcrun >/dev/null 2>&1 && command -v node >/dev/null 2>&1 && [[ -n "$wanted" ]]; then
		local resolved
		resolved="$(xcrun xctrace list devices 2>/dev/null | node -e '
const wanted = String(process.argv[1] || "").trim();
const lines = require("fs").readFileSync(0, "utf8").split(/\r?\n/);
for (const line of lines) {
	const match = line.match(/^(.+?)\s+\(([^()]*)\)\s+\(([0-9A-Fa-f-]+)\)\s*$/);
	if (!match) continue;
	const name = match[1].trim();
	const id = match[3].trim();
	if (wanted !== name && wanted !== id) continue;
	if (/iphone/i.test(name)) {
		process.stdout.write("iphone");
	} else if (/ipad/i.test(name)) {
		process.stdout.write("ipad");
	} else {
		process.stdout.write("ios");
	}
	process.exit(0);
}
process.exit(1);
' "$wanted" || true)"
		if [[ -n "$resolved" ]]; then
			printf "%s" "$resolved"
			return
		fi
	fi
	printf "%s" "${IOS_XR_PLATFORM:-ipad}"
}

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

resolve_ready_android_serial_from_json() {
	local json_file="$1"
	local gate_name="$2"
	if [[ ! -f "$json_file" ]]; then
		return 0
	fi
	node -e '
const fs = require("fs");
const file = process.argv[1];
const gate = process.argv[2];
const summary = JSON.parse(fs.readFileSync(file, "utf8"));
const result = (Array.isArray(summary.results) ? summary.results : []).find((item) => item && item.gate === gate);
const selected = result && result.evidence && result.evidence.selected_device;
const serial = selected && selected.serial ? selected.serial : "";
if (serial) {
	process.stdout.write(String(serial));
}
' "$json_file" "$gate_name" 2>/dev/null || true
}

auto_select_ready_device_if_needed() {
	local gate="$1"
	if [[ "$AUTO_SELECT_READY_DEVICE" == "0" ]]; then
		return 0
	fi
	if gate_needs_ipad_device_arg "$gate" && [[ -n "$DEVICE" ]]; then
		return 0
	fi
	if gate_uses_adb_serial "$gate" && [[ -n "${ADB_SERIAL:-}" ]]; then
		return 0
	fi
	if ! gate_needs_ipad_device_arg "$gate" && ! gate_uses_adb_serial "$gate"; then
		return 0
	fi

	local readiness_gate safe_gate out_dir stamp report json status selected
	readiness_gate="$(readiness_gate_for_gate "$gate")"
	safe_gate="$(safe_gate_name "$gate")"
	out_dir="$PROJECT_ROOT/releases/phase_0_smoke/evidence"
	stamp="$(date +%Y%m%d-%H%M%S)"
	report="$out_dir/device-ready-${readiness_gate}-${safe_gate}-${stamp}.md"
	json="$out_dir/device-ready-${readiness_gate}-${safe_gate}-${stamp}.json"

	if [[ "$DRY_RUN" == "1" ]]; then
		echo "DRY RUN: node tools/c00/check_device_ready.js --gate $readiness_gate --package $PACKAGE --report $report --json $json --format markdown"
		return 0
	fi

	mkdir -p "$out_dir"
	local readiness_args=(--gate "$readiness_gate" --package "$PACKAGE" --report "$report" --json "$json" --format markdown)
	if gate_needs_ipad_device_arg "$gate" && [[ -n "$DEVICE" ]]; then
		readiness_args+=(--device "$DEVICE")
	fi

	echo "Auto-selecting ready device for C00 gate '$gate'..."
	set +e
	node "$PROJECT_ROOT/tools/c00/check_device_ready.js" "${readiness_args[@]}"
	status="$?"
	set -e

	if gate_needs_ipad_device_arg "$gate" && [[ -z "$DEVICE" ]]; then
		selected="$(resolve_ready_ipad_device_from_json "$json")"
		if [[ -n "$selected" ]]; then
			DEVICE="$selected"
			export DEVICE
			echo "Using auto-discovered iPad device for gate run: $DEVICE"
		fi
	fi
	if gate_uses_adb_serial "$gate" && [[ -z "${ADB_SERIAL:-}" ]]; then
		selected="$(resolve_ready_android_serial_from_json "$json" "$readiness_gate")"
		if [[ -n "$selected" ]]; then
			ADB_SERIAL="$selected"
			export ADB_SERIAL
			echo "Using auto-discovered ADB serial for gate run: $ADB_SERIAL"
		fi
	fi
	if [[ "$status" -ne 0 ]]; then
		echo "Device readiness did not pass for '$gate'; continuing so the collector can produce diagnostics. Report: $report"
	fi
	return 0
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

is_valid_godot_source() {
	local dir="$1"
	[[ -f "$dir/core/version.h" \
		&& -f "$dir/core/object/class_db.h" \
		&& -f "$dir/core/config/engine.h" \
		&& -f "$dir/core/extension/gdextension_interface.gen.h" \
		&& -d "$dir/platform/ios" ]]
}

is_matching_godot_source() {
	local dir="$1"
	local expected actual
	expected="$(resolve_template_version)"
	actual="$(godot_source_template_version "$dir" || true)"
	if [[ -z "$actual" ]]; then
		echo "Godot source version could not be parsed from $dir/version.py" >&2
		return 1
	fi
	if [[ "$actual" != "$expected" ]]; then
		echo "Godot source version mismatch: expected $expected, got $actual at $dir" >&2
		echo "Run: tools/c00/prepare_godot_source.sh --tag $(godot_tag_from_template_version "$expected") --force" >&2
		return 1
	fi
	return 0
}

resolve_godot_source_for_arkit() {
	local source="${GODOT_SOURCE_DIR:-${GODOT_SRC_DIR:-}}"
	if [[ -n "$source" ]]; then
		if ! is_valid_godot_source "$source"; then
			echo "GODOT_SOURCE_DIR is set but is not a valid Godot source tree: $source" >&2
			return 1
		fi
		if ! is_matching_godot_source "$source"; then
			return 1
		fi
		GODOT_SOURCE_DIR="$(cd "$source" && pwd)"
		export GODOT_SOURCE_DIR
		return 0
	fi

	if is_valid_godot_source "$DEFAULT_GODOT_SOURCE_DIR"; then
		if ! is_matching_godot_source "$DEFAULT_GODOT_SOURCE_DIR"; then
			echo "Prepared default Godot source is not used because it does not match the selected template version." >&2
		else
			GODOT_SOURCE_DIR="$DEFAULT_GODOT_SOURCE_DIR"
			export GODOT_SOURCE_DIR
			echo "Using prepared Godot source tree: $GODOT_SOURCE_DIR"
			return 0
		fi
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

resolve_ipad_team_id() {
	if [[ -n "${IPAD_TEAM_ID:-}" ]]; then
		printf "%s\n" "$IPAD_TEAM_ID"
		return
	fi
	if [[ -n "${TEAM_ID:-}" ]]; then
		printf "%s\n" "$TEAM_ID"
		return
	fi
	if [[ -n "${DEVELOPMENT_TEAM:-}" ]]; then
		printf "%s\n" "$DEVELOPMENT_TEAM"
		return
	fi
	if [[ -n "${APPLE_TEAM_ID:-}" ]]; then
		printf "%s\n" "$APPLE_TEAM_ID"
		return
	fi
}

configure_ipad_signing_if_requested() {
	local gate="$1"
	if [[ "$gate" != "ipad" && "$gate" != "ipad-place" ]]; then
		return
	fi
	if [[ "$RUN_EXPORT" == "0" || "$CONFIGURE_IPAD_SIGNING" == "0" ]]; then
		return
	fi
	if [[ -n "${APP_PATH:-}" ]]; then
		echo "APP_PATH is already set; skipping iPad export preset signing setup: $APP_PATH"
		return
	fi

	local team_id
	team_id="$(resolve_ipad_team_id)"
	if [[ -z "$team_id" ]]; then
		if [[ "$CONFIGURE_IPAD_SIGNING" == "1" ]]; then
			echo "CONFIGURE_IPAD_SIGNING=1 requires IPAD_TEAM_ID, TEAM_ID, DEVELOPMENT_TEAM, or APPLE_TEAM_ID." >&2
			return 2
		fi
		echo "No iPad Team ID env var found; skipping export preset signing setup in auto mode."
		echo "Set IPAD_TEAM_ID, TEAM_ID, DEVELOPMENT_TEAM, or APPLE_TEAM_ID to update export_presets.cfg before export."
		return
	fi

	echo "Configuring iPad export preset signing identifiers for $gate..."
	if [[ "$DRY_RUN" == "1" ]]; then
		echo "DRY RUN: node tools/c00/configure_ios_signing.js --gate $gate --team-id $team_id --bundle-id $PACKAGE"
		return
	fi
	node "$PROJECT_ROOT/tools/c00/configure_ios_signing.js" \
		--gate "$gate" \
		--team-id "$team_id" \
		--bundle-id "$PACKAGE"
}

prepare_android_gradle_home_if_needed() {
	local gate="$1"
	case "$gate" in
		rokid|rokid-place|android-arcore)
			;;
		*)
			return
			;;
	esac

	export GRADLE_USER_HOME="${GRADLE_USER_HOME:-$PROJECT_ROOT/.godot/cache/c00/gradle}"
	if [[ "$DRY_RUN" == "1" ]]; then
		echo "DRY RUN: GRADLE_USER_HOME=$GRADLE_USER_HOME tools/c00/prepare_gradle_user_home.sh"
		return
	fi
	"$PROJECT_ROOT/tools/c00/prepare_gradle_user_home.sh"
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
	if [[ "$BUILD_IPAD_APP" == "auto" ]] && ! command -v xcodebuild >/dev/null 2>&1; then
		echo "xcodebuild not found; assuming $PACKAGE is already installed on the device."
		return
	fi

	echo "Building iPad Xcode export into app bundle..."
	if [[ ! -f "$export_zip" ]]; then
		echo "iPad export zip is missing; build_ios_xcode_project.sh will try the project-only export fallback: $export_zip"
	fi
	local build_status=0
	APP_OUTPUT_PATH="$app_output" "$PROJECT_ROOT/tools/c00/build_ios_xcode_project.sh" "$export_zip" "$DEVICE" || build_status=$?
	if [[ "$build_status" -ne 0 ]]; then
		return "$build_status"
	fi
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
	if ! command -v xcodebuild >/dev/null 2>&1; then
		echo "xcodebuild not found; cannot build iOS Simulator app." >&2
		return 2
	fi

	echo "Building iOS Simulator Xcode export into app bundle..."
	if [[ ! -f "$export_zip" ]]; then
		echo "iOS Simulator export zip is missing; build_ios_xcode_project.sh will try the project-only export fallback: $export_zip"
	fi
	local build_status=0
	IOS_BUILD_PLATFORM=simulator \
	ALLOW_PROVISIONING_UPDATES=0 \
	CODE_SIGN_STYLE="" \
	CODE_SIGNING_ALLOWED=NO \
	BUILD_ROOT="$PROJECT_ROOT/builds/ios_simulator/xcode" \
	DERIVED_DATA_PATH="$PROJECT_ROOT/builds/ios_simulator/DerivedData" \
	APP_OUTPUT_PATH="$app_output" \
		"$PROJECT_ROOT/tools/c00/build_ios_xcode_project.sh" "$export_zip" || build_status=$?
	if [[ "$build_status" -ne 0 ]]; then
		return "$build_status"
	fi
	APP_PATH="$app_output"
	export APP_PATH
}

run_preflight() {
	local gate="$1"
	if [[ "$RUN_PREFLIGHT" == "0" ]]; then
		return
	fi
	prepare_android_gradle_home_if_needed "$gate"
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
			rokid-place)
				echo "DRY RUN: tools/c00/export_with_godot.sh \"$ROKID_PLACE_PRESET\" \"${APK_PATH:-$ROKID_PLACE_APK_PATH}\""
				;;
			android-arcore)
				echo "DRY RUN: tools/c00/export_with_godot.sh \"$ANDROID_ARCORE_PRESET\" \"${APK_PATH:-$ANDROID_ARCORE_APK_PATH}\""
				;;
			ipad)
				echo "DRY RUN: tools/c00/export_with_godot.sh \"$IPAD_PRESET\" \"$IPAD_EXPORT_PATH\""
				;;
			ipad-place)
				echo "DRY RUN: tools/c00/export_with_godot.sh \"$IPAD_PLACE_PRESET\" \"$IPAD_PLACE_EXPORT_PATH\""
				;;
			ios-simulator)
				echo "DRY RUN: tools/c00/export_with_godot.sh \"$IPAD_PRESET\" \"$IOS_SIMULATOR_EXPORT_PATH\""
				;;
			ios-simulator-place)
				echo "DRY RUN: tools/c00/export_with_godot.sh \"$IPAD_PLACE_PRESET\" \"$IOS_SIMULATOR_PLACE_EXPORT_PATH\""
				;;
			editor)
				echo "DRY RUN: editor gate export skipped"
				;;
		esac
		return
	fi

	export_with_godot_checked() {
		local preset="$1"
		local output_path="$2"
		local export_status=0
		"$PROJECT_ROOT/tools/c00/export_with_godot.sh" "$preset" "$output_path" || export_status=$?
		if [[ "$export_status" -ne 0 ]]; then
			return "$export_status"
		fi
	}

	case "$gate" in
		rokid)
			export_with_godot_checked "$ROKID_PRESET" "${APK_PATH:-$ROKID_APK_PATH}" || return $?
			node "$PROJECT_ROOT/tools/c00/check_android_apk_surface.js" --gate rokid --apk "$(project_path "${APK_PATH:-$ROKID_APK_PATH}")"
			;;
		rokid-place)
			export_with_godot_checked "$ROKID_PLACE_PRESET" "${APK_PATH:-$ROKID_PLACE_APK_PATH}" || return $?
			node "$PROJECT_ROOT/tools/c00/check_android_apk_surface.js" --gate rokid-place --apk "$(project_path "${APK_PATH:-$ROKID_PLACE_APK_PATH}")"
			;;
		android-arcore)
			export_with_godot_checked "$ANDROID_ARCORE_PRESET" "${APK_PATH:-$ANDROID_ARCORE_APK_PATH}" || return $?
			node "$PROJECT_ROOT/tools/c00/check_android_apk_surface.js" --gate android-arcore --apk "$(project_path "${APK_PATH:-$ANDROID_ARCORE_APK_PATH}")"
			;;
		ipad)
			if [[ -n "${APP_PATH:-}" ]]; then
				echo "APP_PATH is already set; skipping iPad export: $APP_PATH"
				return
			fi
			export_with_godot_checked "$IPAD_PRESET" "$IPAD_EXPORT_PATH" || return $?
			node "$PROJECT_ROOT/tools/c00/check_ios_export_project.js" --input "$(project_path "$IPAD_EXPORT_PATH")"
			;;
		ipad-place)
			if [[ -n "${APP_PATH:-}" ]]; then
				echo "APP_PATH is already set; skipping iPad placement export: $APP_PATH"
				return
			fi
			export_with_godot_checked "$IPAD_PLACE_PRESET" "$IPAD_PLACE_EXPORT_PATH" || return $?
			node "$PROJECT_ROOT/tools/c00/check_ios_export_project.js" --input "$(project_path "$IPAD_PLACE_EXPORT_PATH")"
			;;
		ios-simulator)
			if [[ -n "${APP_PATH:-}" ]]; then
				echo "APP_PATH is already set; skipping iOS Simulator export: $APP_PATH"
				return
			fi
			export_with_godot_checked "$IPAD_PRESET" "$IOS_SIMULATOR_EXPORT_PATH" || return $?
			node "$PROJECT_ROOT/tools/c00/check_ios_export_project.js" --input "$(project_path "$IOS_SIMULATOR_EXPORT_PATH")"
			;;
		ios-simulator-place)
			if [[ -n "${APP_PATH:-}" ]]; then
				echo "APP_PATH is already set; skipping iOS Simulator placement export: $APP_PATH"
				return
			fi
			export_with_godot_checked "$IPAD_PLACE_PRESET" "$IOS_SIMULATOR_PLACE_EXPORT_PATH" || return $?
			node "$PROJECT_ROOT/tools/c00/check_ios_export_project.js" --input "$(project_path "$IOS_SIMULATOR_PLACE_EXPORT_PATH")"
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
			ios-simulator-place)
				echo "DRY RUN: IOS_SIM_GATE=ios-simulator-place IOS_SIM_XR_SCENE=ios_arkit_place APP_PATH=${APP_PATH:-$IOS_SIMULATOR_PLACE_APP_PATH} tools/c00/collect_ios_simulator_smoke.sh $SIMULATOR_DEVICE $PACKAGE $DURATION"
				;;
			rokid)
				echo "DRY RUN: APK_PATH=${APK_PATH:-$(project_path "$ROKID_APK_PATH")} tools/c00/collect_android_smoke.sh rokid $PACKAGE $DURATION"
				;;
			rokid-place)
				echo "DRY RUN: APK_PATH=${APK_PATH:-$(project_path "$ROKID_PLACE_APK_PATH")} tools/c00/collect_android_smoke.sh rokid-place $PACKAGE $DURATION"
				;;
			android-arcore)
				echo "DRY RUN: APK_PATH=${APK_PATH:-$(project_path "$ANDROID_ARCORE_APK_PATH")} tools/c00/collect_android_smoke.sh android-arcore $PACKAGE $DURATION"
				;;
			ipad)
				local ios_xr_platform
				ios_xr_platform="${IOS_XR_PLATFORM:-$(resolve_ios_xr_platform_for_device "${DEVICE:-}")}"
				echo "DRY RUN: IOS_XR_PLATFORM=$ios_xr_platform APP_PATH=${APP_PATH:-$IPAD_APP_PATH} tools/c00/collect_ios_smoke.sh ${DEVICE:-<ios-device>} $PACKAGE $DURATION"
				;;
			ipad-place)
				local ios_xr_platform
				ios_xr_platform="${IOS_XR_PLATFORM:-$(resolve_ios_xr_platform_for_device "${DEVICE:-}")}"
				echo "DRY RUN: IOS_GATE=ipad-place IOS_XR_PLATFORM=$ios_xr_platform IOS_XR_SCENE=ios_arkit_place APP_PATH=${APP_PATH:-$IPAD_PLACE_APP_PATH} tools/c00/collect_ios_smoke.sh ${DEVICE:-<ios-device>} $PACKAGE $DURATION"
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
		ios-simulator-place)
			if [[ -z "${APP_PATH:-}" ]]; then
				echo "APP_PATH is empty; expected iOS Simulator placement .app from the build step." >&2
				exit 2
			fi
			IOS_SIM_GATE=ios-simulator-place IOS_SIM_XR_SCENE=ios_arkit_place \
				"$PROJECT_ROOT/tools/c00/collect_ios_simulator_smoke.sh" "$SIMULATOR_DEVICE" "$PACKAGE" "$DURATION"
			;;
		rokid)
			local apk_path="${APK_PATH:-$(project_path "$ROKID_APK_PATH")}"
			APK_PATH="$apk_path" "$PROJECT_ROOT/tools/c00/collect_android_smoke.sh" rokid "$PACKAGE" "$DURATION"
			;;
		rokid-place)
			local apk_path="${APK_PATH:-$(project_path "$ROKID_PLACE_APK_PATH")}"
			APK_PATH="$apk_path" "$PROJECT_ROOT/tools/c00/collect_android_smoke.sh" rokid-place "$PACKAGE" "$DURATION"
			;;
		android-arcore)
			local apk_path="${APK_PATH:-$(project_path "$ANDROID_ARCORE_APK_PATH")}"
			APK_PATH="$apk_path" "$PROJECT_ROOT/tools/c00/collect_android_smoke.sh" android-arcore "$PACKAGE" "$DURATION"
			;;
		ipad)
			if [[ -z "$DEVICE" ]]; then
				echo "iOS ARKit device is required for collection. Run: xcrun devicectl list devices" >&2
				exit 2
			fi
			if [[ -z "${APP_PATH:-}" ]]; then
				echo "APP_PATH is empty; assuming $PACKAGE is already installed on $DEVICE."
			fi
			local ios_xr_platform
			ios_xr_platform="${IOS_XR_PLATFORM:-$(resolve_ios_xr_platform_for_device "$DEVICE")}"
			IOS_XR_PLATFORM="$ios_xr_platform" "$PROJECT_ROOT/tools/c00/collect_ios_smoke.sh" "$DEVICE" "$PACKAGE" "$DURATION"
			;;
		ipad-place)
			if [[ -z "$DEVICE" ]]; then
				echo "iOS ARKit device is required for placement collection. Run: xcrun devicectl list devices" >&2
				exit 2
			fi
			if [[ -z "${APP_PATH:-}" ]]; then
				echo "APP_PATH is empty; assuming $PACKAGE placement build is already installed on $DEVICE."
			fi
			local ios_xr_platform
			ios_xr_platform="${IOS_XR_PLATFORM:-$(resolve_ios_xr_platform_for_device "$DEVICE")}"
			IOS_GATE=ipad-place IOS_XR_PLATFORM="$ios_xr_platform" IOS_XR_SCENE=ios_arkit_place "$PROJECT_ROOT/tools/c00/collect_ios_smoke.sh" "$DEVICE" "$PACKAGE" "$DURATION"
			;;
	esac
}

run_gate() {
	local gate="$1"
	echo
	echo "== C00 gate: $gate =="
	if [[ "$gate" == "ipad-place" ]]; then
		local default_ipad_app_path
		default_ipad_app_path="$(project_path "$IPAD_APP_PATH")"
		if [[ "${APP_PATH:-}" == "$IPAD_APP_PATH" || "${APP_PATH:-}" == "$default_ipad_app_path" ]]; then
			unset APP_PATH
		fi
	fi
	if [[ "$gate" == "ipad" || "$gate" == "ipad-place" || "$gate" == "ios-simulator" || "$gate" == "ios-simulator-place" ]]; then
		build_arkit_plugin_if_requested || return $?
	fi
	run_preflight "$gate" || return $?
	auto_select_ready_device_if_needed "$gate" || return $?
	configure_ipad_signing_if_requested "$gate" || return $?
	run_export "$gate" || return $?
	if [[ "$gate" == "ipad" ]]; then
		build_ipad_app_if_requested || return $?
	fi
	if [[ "$gate" == "ipad-place" ]]; then
		local saved_ipad_export_path="$IPAD_EXPORT_PATH"
		local saved_ipad_app_path="$IPAD_APP_PATH"
		IPAD_EXPORT_PATH="$IPAD_PLACE_EXPORT_PATH"
		IPAD_APP_PATH="$IPAD_PLACE_APP_PATH"
		local build_status=0
		build_ipad_app_if_requested || build_status=$?
		IPAD_EXPORT_PATH="$saved_ipad_export_path"
		IPAD_APP_PATH="$saved_ipad_app_path"
		if [[ "$build_status" -ne 0 ]]; then
			return "$build_status"
		fi
	fi
	if [[ "$gate" == "ios-simulator" ]]; then
		build_ios_simulator_app_if_requested || return $?
	fi
	if [[ "$gate" == "ios-simulator-place" ]]; then
		local saved_simulator_export_path="$IOS_SIMULATOR_EXPORT_PATH"
		local saved_simulator_app_path="$IOS_SIMULATOR_APP_PATH"
		IOS_SIMULATOR_EXPORT_PATH="$IOS_SIMULATOR_PLACE_EXPORT_PATH"
		IOS_SIMULATOR_APP_PATH="$IOS_SIMULATOR_PLACE_APP_PATH"
		local simulator_build_status=0
		build_ios_simulator_app_if_requested || simulator_build_status=$?
		IOS_SIMULATOR_EXPORT_PATH="$saved_simulator_export_path"
		IOS_SIMULATOR_APP_PATH="$saved_simulator_app_path"
		if [[ "$simulator_build_status" -ne 0 ]]; then
			return "$simulator_build_status"
		fi
	fi
	run_collect "$gate" || return $?
}

run_gate_for_all() {
	local gate="$1"
	local gate_env_file="${C00_DEVICE_ENV_FILE:-$(default_device_env_file_for_gate "$gate")}"
	set +e
	if [[ "$DRY_RUN" == "1" && -f "$gate_env_file" ]]; then
		echo "DRY RUN: C00_DEVICE_ENV_FILE=$gate_env_file"
	fi
	(
		clear_split_gate_version_env
		if [[ -f "$gate_env_file" ]]; then
			export C00_DEVICE_ENV_FILE="$gate_env_file"
		fi
		INCLUDE_PLACE_DEMOS=0 RUN_PHASE_VERIFY=0 "$PROJECT_ROOT/tools/c00/run_device_cycle.sh" "$gate"
	)
	local status="$?"
	set -e

	if [[ "$status" -eq 0 ]]; then
		if [[ "$DRY_RUN" == "1" ]]; then
			echo "== C00 gate dry-run complete: $gate =="
		else
			echo "== C00 gate passed: $gate =="
		fi
		return 0
	fi

	ALL_GATE_STATUS=1
	echo "== C00 gate failed: $gate (exit $status) ==" >&2
	if [[ "$CONTINUE_ON_FAILURE" == "0" ]]; then
		return "$status"
	fi
	return 0
}

phase_gate_args() {
	if [[ "$PHASE_GATES" == "auto" ]]; then
		printf "%s\n" --gate rokid --gate ipad
		if [[ "$INCLUDE_PLACE_DEMOS" == "1" ]]; then
			printf "%s\n" --gate rokid-place --gate ipad-place
		fi
		if [[ "$INCLUDE_ANDROID_ARCORE" == "1" ]]; then
			printf "%s\n" --gate android-arcore
		fi
	else
		local phase_gate
		IFS=',' read -r -a phase_gates <<< "$PHASE_GATES"
		for phase_gate in "${phase_gates[@]}"; do
			phase_gate="${phase_gate//[[:space:]]/}"
			if [[ -n "$phase_gate" ]]; then
				printf "%s\n" --gate "$phase_gate"
			fi
		done
	fi
}

run_phase_verify() {
	if [[ "$RUN_PHASE_VERIFY" == "0" ]]; then
		return 0
	fi

	local gate_args=()
	while IFS= read -r arg; do
		gate_args+=("$arg")
	done < <(phase_gate_args)
	if [[ "$DRY_RUN" == "1" ]]; then
		echo
		printf "DRY RUN: tools/c00/verify_phase_evidence.js --report %q" "$(project_path "$PHASE_REPORT")"
		printf " %q" "${gate_args[@]}"
		printf "\n"
		return 0
	fi

	echo
	echo "== C00 phase evidence verify =="
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
		if [[ "$INCLUDE_PLACE_DEMOS" == "1" ]]; then
			run_gate_for_all ios-simulator-place || phase_status="$?"
			if [[ "$phase_status" != "0" && "$CONTINUE_ON_FAILURE" == "0" ]]; then
				exit "$phase_status"
			fi
		fi
	fi
	run_gate_for_all ipad || phase_status="$?"
	if [[ "$phase_status" != "0" && "$CONTINUE_ON_FAILURE" == "0" ]]; then
		exit "$phase_status"
	fi
	if [[ "$INCLUDE_PLACE_DEMOS" == "1" ]]; then
		run_gate_for_all ipad-place || phase_status="$?"
		if [[ "$phase_status" != "0" && "$CONTINUE_ON_FAILURE" == "0" ]]; then
			exit "$phase_status"
		fi
	fi
	run_gate_for_all rokid || phase_status="$?"
	if [[ "$phase_status" != "0" && "$CONTINUE_ON_FAILURE" == "0" ]]; then
		exit "$phase_status"
	fi
	if [[ "$INCLUDE_PLACE_DEMOS" == "1" ]]; then
		run_gate_for_all rokid-place || phase_status="$?"
		if [[ "$phase_status" != "0" && "$CONTINUE_ON_FAILURE" == "0" ]]; then
			exit "$phase_status"
		fi
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
