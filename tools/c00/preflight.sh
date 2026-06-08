#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GATE="${1:-all}"

status=0

usage() {
	cat <<EOF
Usage:
  tools/c00/preflight.sh [all|editor|rokid|ipad|android-arcore]

Default: all
EOF
}

case "$GATE" in
	all|editor|rokid|ipad|android-arcore)
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

needs_android_tools() {
	[ "$GATE" = "all" ] || [ "$GATE" = "rokid" ] || [ "$GATE" = "android-arcore" ]
}

needs_ios_tools() {
	[ "$GATE" = "all" ] || [ "$GATE" = "ipad" ]
}

needs_openxr() {
	[ "$GATE" = "all" ] || [ "$GATE" = "rokid" ]
}

needs_export_preset() {
	[ "$GATE" = "all" ] || [ "$GATE" = "rokid" ] || [ "$GATE" = "ipad" ] || [ "$GATE" = "android-arcore" ]
}

check_command() {
	local name="$1"
	local purpose="$2"
	if command -v "$name" >/dev/null 2>&1; then
		printf "OK   %-16s %s\n" "$name" "$(command -v "$name")"
	else
		printf "MISS %-16s %s\n" "$name" "$purpose"
		status=1
	fi
}

check_file() {
	local path="$1"
	local purpose="$2"
	if [ -f "$path" ]; then
		printf "OK   %s\n" "$path"
	else
		printf "MISS %s\n" "$path"
		printf "     %s\n" "$purpose"
		status=1
	fi
}

check_dir() {
	local path="$1"
	local purpose="$2"
	if [ -d "$path" ]; then
		printf "OK   %s\n" "$path"
	else
		printf "MISS %s\n" "$path"
		printf "     %s\n" "$purpose"
		status=1
	fi
}

printf "C00 device smoke preflight\n"
printf "Project: %s\n\n" "$PROJECT_ROOT"
printf "Gate: %s\n\n" "$GATE"

check_command node "required for tools/c00/validate_smoke_log.js"
if [ -n "${GODOT_BIN:-}" ] && [ -x "$GODOT_BIN" ]; then
	printf "OK   %-16s %s\n" "GODOT_BIN" "$GODOT_BIN"
else
	check_command godot "required for command-line export/import validation; set GODOT_BIN if using an app bundle"
fi
if needs_android_tools; then
	check_command adb "required for Rokid/Android log collection"
fi
if needs_ios_tools; then
	check_command xcrun "required for iPad install/launch through Xcode tools"
fi

printf "\nPlugin landing zones\n"
if needs_android_tools; then
	check_dir "$PROJECT_ROOT/android/plugins" "required for Android/Rokid native plugin placement"
fi
if needs_ios_tools; then
	check_dir "$PROJECT_ROOT/ios/plugins" "required for iOS native plugin placement"
fi

if needs_ios_tools; then
	printf "\nNative plugin artifacts\n"
	check_file "$PROJECT_ROOT/ios/plugins/godot_arkit/GodotARKit.gdip" "required for the iPad/ARKit gate; run ios/plugins/godot_arkit/build_xcframework.sh"
	check_dir "$PROJECT_ROOT/ios/plugins/godot_arkit/GodotARKit.xcframework" "required for the iPad/ARKit gate; run ios/plugins/godot_arkit/build_xcframework.sh"
fi

if needs_export_preset; then
	printf "\nExport presets\n"
	if [ -f "$PROJECT_ROOT/export_presets.cfg" ]; then
		if node "$PROJECT_ROOT/tools/c00/check_export_presets.js" --gate "$GATE" --file "$PROJECT_ROOT/export_presets.cfg"; then
			printf "OK   export_presets.cfg C00 preset check\n"
		else
			status=1
		fi
	else
		printf "MISS %s\n" "$PROJECT_ROOT/export_presets.cfg"
		printf "     Create C00 export presets in the Godot editor, or run:\n"
		printf "     node tools/c00/write_export_presets_template.js --output export_presets.cfg\n"
		printf "     See tools/c00/EXPORT_PRESETS_CN.md\n"
		status=1
	fi
fi

printf "\nGodot project checks\n"
if [ -f "$PROJECT_ROOT/project.godot" ]; then
	printf "OK   project.godot\n"
else
	printf "MISS project.godot\n"
	status=1
fi

if grep -q 'run/main_scene="res://demo/00_device_smoke_test.tscn"' "$PROJECT_ROOT/project.godot"; then
	printf "OK   C00 smoke scene is main_scene\n"
else
	printf "MISS C00 smoke scene is not main_scene\n"
	status=1
fi

if needs_openxr; then
	if grep -q 'openxr/enabled=true' "$PROJECT_ROOT/project.godot"; then
		printf "OK   OpenXR is enabled\n"
	else
		printf "MISS OpenXR is not enabled in project.godot\n"
		status=1
	fi
fi

printf "\nResult: "
if [ "$status" -eq 0 ]; then
	printf "ready\n"
else
	printf "missing prerequisites\n"
fi

exit "$status"
