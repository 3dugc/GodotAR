#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GATE="${1:-}"
DEVICE="${2:-${DEVICE:-}}"

PACKAGE="${PACKAGE:-org.godotengine.godotxrfoundation}"
DURATION="${DURATION:-30}"
RUN_PREFLIGHT="${RUN_PREFLIGHT:-1}"
RUN_EXPORT="${RUN_EXPORT:-1}"
RUN_COLLECT="${RUN_COLLECT:-1}"
BUILD_ARKIT_PLUGIN="${BUILD_ARKIT_PLUGIN:-auto}"
INCLUDE_ANDROID_ARCORE="${INCLUDE_ANDROID_ARCORE:-0}"
CONTINUE_ON_FAILURE="${CONTINUE_ON_FAILURE:-auto}"
RUN_PHASE_VERIFY="${RUN_PHASE_VERIFY:-1}"
PHASE_REPORT="${PHASE_REPORT:-releases/phase_0_smoke/C00_PHASE_REPORT.md}"

ROKID_PRESET="${ROKID_PRESET:-C00 Rokid OpenXR}"
ROKID_APK_PATH="${ROKID_APK_PATH:-builds/rokid/c00.apk}"
ANDROID_ARCORE_PRESET="${ANDROID_ARCORE_PRESET:-C00 Android ARCore}"
ANDROID_ARCORE_APK_PATH="${ANDROID_ARCORE_APK_PATH:-builds/android_arcore/c00.apk}"
IPAD_PRESET="${IPAD_PRESET:-C00 iPad ARKit}"
IPAD_EXPORT_PATH="${IPAD_EXPORT_PATH:-builds/ipad/c00.zip}"

usage() {
	cat <<EOF
Usage:
  tools/c00/run_device_cycle.sh <rokid|ipad|android-arcore|all> [ipad-device]

Examples:
  tools/c00/run_device_cycle.sh rokid
  DEVICE=<ipad-uuid-or-name> APP_PATH=builds/ipad/GodotXRFoundation.app tools/c00/run_device_cycle.sh ipad
  GODOT_SOURCE_DIR=/path/to/godot tools/c00/run_device_cycle.sh ipad <ipad-device>

Common environment:
  GODOT_BIN=/path/to/Godot
  PACKAGE=org.godotengine.godotxrfoundation
  DURATION=30
  RUN_PREFLIGHT=1
  RUN_EXPORT=1
  RUN_COLLECT=1

Evidence:
  CAPTURE_MEDIA=1                  Capture screenshot/recording where supported.
  VIDEO_SECONDS=15                 Android/Rokid screen recording length.
  MANUAL_MEDIA_PATH=/path/file     iPad fallback screenshot or recording when automatic capture is unavailable.
  ALLOW_MISSING_MEDIA=1            Keep collecting/reporting even when media evidence is missing.

iPad / ARKit:
  GODOT_SOURCE_DIR=/path/to/godot     Build GodotARKit.xcframework before export.
  BUILD_ARKIT_PLUGIN=auto|1|0        Default auto: build only when GODOT_SOURCE_DIR is set.
  APP_PATH=builds/ipad/App.app       Optional installed app bundle for devicectl.

Rokid / Android:
  APK_PATH=builds/rokid/c00.apk      Optional APK override for install/collect.
  ROKID_PRESET="$ROKID_PRESET"
  ROKID_APK_PATH="$ROKID_APK_PATH"

All:
  Runs ipad then rokid. Set INCLUDE_ANDROID_ARCORE=1 to include Android ARCore.
  CONTINUE_ON_FAILURE=auto|1|0     Default auto continues in all mode so every device can produce evidence.
  RUN_PHASE_VERIFY=1               Run verify_phase_evidence.js after all gates.
  PHASE_REPORT="$PHASE_REPORT"
EOF
}

if [[ "$GATE" == "-h" || "$GATE" == "--help" ]]; then
	usage
	exit 0
fi

case "$GATE" in
	rokid|ipad|android-arcore|all)
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

build_arkit_plugin_if_requested() {
	if [[ "$BUILD_ARKIT_PLUGIN" == "0" ]]; then
		return
	fi

	if [[ "$BUILD_ARKIT_PLUGIN" == "auto" && -z "${GODOT_SOURCE_DIR:-${GODOT_SRC_DIR:-}}" ]]; then
		return
	fi

	echo "Building ARKit iOS plugin..."
	"$PROJECT_ROOT/ios/plugins/godot_arkit/build_xcframework.sh"
}

run_preflight() {
	local gate="$1"
	if [[ "$RUN_PREFLIGHT" == "0" ]]; then
		return
	fi
	"$PROJECT_ROOT/tools/c00/preflight.sh" "$gate"
}

run_export() {
	local gate="$1"
	if [[ "$RUN_EXPORT" == "0" ]]; then
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
			"$PROJECT_ROOT/tools/c00/export_with_godot.sh" "$IPAD_PRESET" "$IPAD_EXPORT_PATH"
			echo "iPad export is usually an Xcode project zip. Build it in Xcode, then rerun with APP_PATH=<built .app> if collection needs installation."
			;;
	esac
}

run_collect() {
	local gate="$1"
	if [[ "$RUN_COLLECT" == "0" ]]; then
		return
	fi

	case "$gate" in
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
	if [[ "$gate" == "ipad" ]]; then
		build_arkit_plugin_if_requested || return $?
	fi
	run_preflight "$gate" || return $?
	run_export "$gate" || return $?
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

	echo
	echo "== C00 phase evidence verify =="
	node "$PROJECT_ROOT/tools/c00/verify_phase_evidence.js" \
		--report "$(project_path "$PHASE_REPORT")"
}

if [[ "$GATE" == "all" ]]; then
	ALL_GATE_STATUS=0
	phase_status=0
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
