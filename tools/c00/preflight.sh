#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GATE="${1:-all}"

status=0

usage() {
	cat <<EOF
Usage:
  tools/c00/preflight.sh [all|editor|rokid|ipad|ios-simulator|android-arcore]

Default: all
EOF
}

case "$GATE" in
	all|editor|rokid|ipad|ios-simulator|android-arcore)
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
	[ "$GATE" = "all" ] || [ "$GATE" = "ipad" ] || [ "$GATE" = "ios-simulator" ]
}

using_existing_ios_app() {
	{ [ "$GATE" = "ipad" ] || [ "$GATE" = "ios-simulator" ]; } && [ -n "${APP_PATH:-}" ]
}

needs_godot_binary() {
	if using_existing_ios_app; then
		return 1
	fi
	return 0
}

needs_openxr() {
	[ "$GATE" = "all" ] || [ "$GATE" = "rokid" ]
}

needs_arcore() {
	[ "$GATE" = "all" ] || [ "$GATE" = "android-arcore" ]
}

needs_export_preset() {
	if using_existing_ios_app; then
		return 1
	fi
	[ "$GATE" = "all" ] || [ "$GATE" = "rokid" ] || [ "$GATE" = "ipad" ] || [ "$GATE" = "ios-simulator" ] || [ "$GATE" = "android-arcore" ]
}

needs_arkit_static_check() {
	if using_existing_ios_app; then
		return 1
	fi
	[ "$GATE" = "all" ] || [ "$GATE" = "ipad" ] || [ "$GATE" = "ios-simulator" ]
}

needs_ios_plugin_artifacts() {
	needs_ios_tools && ! using_existing_ios_app
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
if needs_godot_binary; then
	if [ -n "${GODOT_BIN:-}" ] && [ -x "$GODOT_BIN" ]; then
		printf "OK   %-16s %s\n" "GODOT_BIN" "$GODOT_BIN"
	else
		check_command godot "required for command-line export/import validation; set GODOT_BIN if using an app bundle"
	fi
else
	check_dir "$APP_PATH" "existing .app bundle required for collection-only iOS gate"
fi
if needs_android_tools; then
	check_command adb "required for Rokid/Android log collection"
fi
if needs_ios_tools; then
	check_command xcrun "required for iPad install/launch through Xcode tools"
	check_command xcodebuild "required for building the Godot iOS export into an installable .app"
fi

printf "\nPlugin landing zones\n"
if needs_android_tools; then
	check_dir "$PROJECT_ROOT/android/plugins" "required for Android/Rokid native plugin placement"
fi
if needs_ios_tools; then
	check_dir "$PROJECT_ROOT/ios/plugins" "required for iOS native plugin placement"
fi

if needs_ios_plugin_artifacts; then
	printf "\nNative plugin artifacts\n"
	if node "$PROJECT_ROOT/tools/c00/check_ios_plugin_artifacts.js"; then
		printf "OK   GodotARKit.gdip template/plugin config check\n"
	else
		printf "MISS GodotARKit.gdip template/plugin config check\n"
		status=1
	fi
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

if needs_arkit_static_check; then
	printf "\nNative plugin source checks\n"
	if "$PROJECT_ROOT/tools/c00/check_arkit_plugin_static.sh" >/dev/null 2>&1; then
		printf "OK   ARKit plugin Objective-C++ syntax smoke\n"
	else
		printf "MISS ARKit plugin Objective-C++ syntax smoke\n"
		printf "     Run tools/c00/check_arkit_plugin_static.sh for details.\n"
		status=1
	fi
fi

if needs_arcore; then
	printf "\nAndroid ARCore plugin source checks\n"
	if node "$PROJECT_ROOT/tools/c00/check_android_arcore_plugin_surface.js" >/dev/null 2>&1; then
		printf "OK   GodotARCore Android plugin surface\n"
	else
		printf "MISS GodotARCore Android plugin surface\n"
		printf "     Run node tools/c00/check_android_arcore_plugin_surface.js for details.\n"
		status=1
	fi
	check_file "$PROJECT_ROOT/addons/godot_arcore/bin/release/GodotARCore-release.aar" "required for Android ARCore export; run android/plugins/godot_arcore/build_plugin.sh"
fi

printf "\nAPI surface checks\n"
if node "$PROJECT_ROOT/tools/c00/check_arfoundation_api_surface.js" >/dev/null 2>&1; then
	printf "OK   ARFoundation migration API surface\n"
else
	printf "MISS ARFoundation migration API surface\n"
	printf "     Run node tools/c00/check_arfoundation_api_surface.js for details.\n"
	status=1
fi

if node "$PROJECT_ROOT/tools/c00/check_xri_api_surface.js" >/dev/null 2>&1; then
	printf "OK   XRI interaction API surface\n"
else
	printf "MISS XRI interaction API surface\n"
	printf "     Run node tools/c00/check_xri_api_surface.js for details.\n"
	status=1
fi

if needs_openxr; then
	if node "$PROJECT_ROOT/tools/c00/check_openxr_provider_surface.js" >/dev/null 2>&1; then
		printf "OK   OpenXR/Rokid AR evidence surface\n"
	else
		printf "MISS OpenXR/Rokid AR evidence surface\n"
		printf "     Run node tools/c00/check_openxr_provider_surface.js for details.\n"
		status=1
	fi
fi

printf "\nGodot project checks\n"
if node "$PROJECT_ROOT/tools/c00/check_godot_project_static.js" >/dev/null 2>&1; then
	printf "OK   C00 Godot project/static scene references\n"
else
	printf "MISS C00 Godot project/static scene references\n"
	printf "     Run node tools/c00/check_godot_project_static.js for details.\n"
	status=1
fi

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
