#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GATE="${1:-all}"
DEFAULT_GODOT_SOURCE_DIR="$PROJECT_ROOT/.godot/cache/c00/godot-source"

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

resolve_template_version() {
	if [ -n "${GODOT_EXPORT_TEMPLATES_VERSION:-}" ]; then
		printf "%s" "$GODOT_EXPORT_TEMPLATES_VERSION"
		return
	fi
	if [ -n "${GODOT_TAG:-}" ]; then
		printf "%s" "${GODOT_TAG/-stable/.stable}"
		return
	fi
	printf "4.4.1.stable"
}

resolve_export_templates_dir() {
	local version
	version="$(resolve_template_version)"
	printf "%s" "${GODOT_EXPORT_TEMPLATES_DIR:-$HOME/Library/Application Support/Godot/export_templates/$version}"
}

resolve_android_sdk_dir() {
	if [ -n "${GODOT_ANDROID_SDK_PATH:-}" ]; then
		printf "%s" "$GODOT_ANDROID_SDK_PATH"
	elif [ -n "${ANDROID_SDK_ROOT:-}" ]; then
		printf "%s" "$ANDROID_SDK_ROOT"
	elif [ -n "${ANDROID_HOME:-}" ]; then
		printf "%s" "$ANDROID_HOME"
	elif [ -d "$HOME/Library/Android/sdk" ]; then
		printf "%s" "$HOME/Library/Android/sdk"
	else
		printf "%s" "$PROJECT_ROOT/.godot/cache/c00/android-sdk"
	fi
}

resolve_android_debug_keystore() {
	if [ -n "${GODOT_ANDROID_KEYSTORE_DEBUG_PATH:-}" ]; then
		printf "%s" "$GODOT_ANDROID_KEYSTORE_DEBUG_PATH"
	else
		printf "%s" "$PROJECT_ROOT/.godot/cache/c00/android/debug.keystore"
	fi
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

check_working_command() {
	local name="$1"
	local probe="$2"
	local purpose="$3"
	if command -v "$name" >/dev/null 2>&1 && "$name" $probe >/dev/null 2>&1; then
		printf "OK   %-16s %s\n" "$name" "$(command -v "$name")"
	else
		printf "MISS %-16s %s\n" "$name" "$purpose"
		status=1
	fi
}

check_working_executable() {
	local label="$1"
	local executable="$2"
	local probe="$3"
	local purpose="$4"
	if [ -n "$executable" ] && [ -x "$executable" ] && "$executable" $probe >/dev/null 2>&1; then
		printf "OK   %-16s %s\n" "$label" "$executable"
	else
		printf "MISS %-16s %s\n" "$label" "$purpose"
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

warn_item() {
	local item="$1"
	local detail="$2"
	printf "WARN %s\n" "$item"
	printf "     %s\n" "$detail"
}

is_valid_godot_source() {
	local dir="$1"
	[ -f "$dir/core/version.h" ] \
		&& [ -f "$dir/core/object/class_db.h" ] \
		&& [ -f "$dir/core/config/engine.h" ] \
		&& [ -d "$dir/platform/ios" ]
}

resolve_godot_source_dir() {
	local source="${GODOT_SOURCE_DIR:-${GODOT_SRC_DIR:-}}"
	if [ -n "$source" ]; then
		printf "%s" "$source"
		return 0
	fi
	if is_valid_godot_source "$DEFAULT_GODOT_SOURCE_DIR"; then
		printf "%s" "$DEFAULT_GODOT_SOURCE_DIR"
		return 0
	fi
	return 1
}

resolve_godot_binary() {
	if [ -n "${GODOT_BIN:-}" ] && [ -x "$GODOT_BIN" ]; then
		printf "%s" "$GODOT_BIN"
		return 0
	fi
	if command -v godot >/dev/null 2>&1; then
		command -v godot
		return 0
	fi
	local bundled="$PROJECT_ROOT/.godot/cache/c00/godot-editor/Godot.app/Contents/MacOS/Godot"
	if [ -x "$bundled" ]; then
		printf "%s" "$bundled"
		return 0
	fi
	local applications="/Applications/Godot.app/Contents/MacOS/Godot"
	if [ -x "$applications" ]; then
		printf "%s" "$applications"
		return 0
	fi
	return 1
}

resolve_adb_binary() {
	if [ -n "${ADB_BIN:-}" ] && [ -x "$ADB_BIN" ]; then
		printf "%s" "$ADB_BIN"
		return 0
	fi
	if command -v adb >/dev/null 2>&1; then
		command -v adb
		return 0
	fi
	local android_sdk_dir
	android_sdk_dir="$(resolve_android_sdk_dir)"
	local sdk_adb="$android_sdk_dir/platform-tools/adb"
	if [ -x "$sdk_adb" ]; then
		printf "%s" "$sdk_adb"
		return 0
	fi
	return 1
}

resolve_java_binary() {
	if [ -n "${GODOT_JAVA_SDK_PATH:-}" ] && [ -x "$GODOT_JAVA_SDK_PATH/bin/java" ]; then
		printf "%s" "$GODOT_JAVA_SDK_PATH/bin/java"
		return 0
	fi
	if [ -n "${JAVA_HOME:-}" ] && [ -x "$JAVA_HOME/bin/java" ]; then
		printf "%s" "$JAVA_HOME/bin/java"
		return 0
	fi
	if command -v java >/dev/null 2>&1; then
		command -v java
		return 0
	fi
	return 1
}

resolve_keytool_binary() {
	if [ -n "${GODOT_JAVA_SDK_PATH:-}" ] && [ -x "$GODOT_JAVA_SDK_PATH/bin/keytool" ]; then
		printf "%s" "$GODOT_JAVA_SDK_PATH/bin/keytool"
		return 0
	fi
	if [ -n "${JAVA_HOME:-}" ] && [ -x "$JAVA_HOME/bin/keytool" ]; then
		printf "%s" "$JAVA_HOME/bin/keytool"
		return 0
	fi
	if command -v keytool >/dev/null 2>&1; then
		command -v keytool
		return 0
	fi
	return 1
}

printf "C00 device smoke preflight\n"
printf "Project: %s\n\n" "$PROJECT_ROOT"
printf "Gate: %s\n\n" "$GATE"

check_command node "required for tools/c00/validate_smoke_log.js"
if needs_godot_binary; then
	if godot_bin="$(resolve_godot_binary)"; then
		printf "OK   %-16s %s\n" "GODOT_BIN" "$godot_bin"
	else
		printf "MISS %-16s %s\n" "godot" "required for command-line export/import validation; set GODOT_BIN if using an app bundle"
		status=1
	fi
else
	check_dir "$APP_PATH" "existing .app bundle required for collection-only iOS gate"
fi
if needs_android_tools; then
	if adb_bin="$(resolve_adb_binary)"; then
		printf "OK   %-16s %s\n" "ADB_BIN" "$adb_bin"
	else
		printf "MISS %-16s %s\n" "adb" "required for Rokid/Android log collection; set ADB_BIN if using a project-local Android platform-tools install"
		status=1
	fi
fi
if needs_ios_tools; then
	check_command xcrun "required for iPad install/launch through Xcode tools"
	check_command xcodebuild "required for building the Godot iOS export into an installable .app"
fi

printf "\nPlugin landing zones\n"
if needs_android_tools; then
	check_dir "$PROJECT_ROOT/android/plugins" "required for Android/Rokid native plugin placement"
fi
if needs_openxr; then
	check_dir "$PROJECT_ROOT/addons/godotopenxrvendors" "required for Android OpenXR vendor loaders; install the Godot OpenXR Vendors plugin into res://addons/godotopenxrvendors"
fi
if needs_ios_tools; then
	check_dir "$PROJECT_ROOT/ios/plugins" "required for iOS native plugin placement"
fi

if needs_ios_plugin_artifacts; then
	printf "\nNative plugin artifacts\n"
	if godot_source="$(resolve_godot_source_dir)"; then
		if is_valid_godot_source "$godot_source"; then
			printf "OK   Godot source headers %s\n" "$godot_source"
		else
			printf "MISS Godot source headers %s\n" "$godot_source"
			printf "     Missing core/version.h, core/object/class_db.h, core/config/engine.h, or platform/ios.\n"
			status=1
		fi
	else
		warn_item "Godot source headers" "Run tools/c00/prepare_godot_source.sh --tag <godot-tag>, or set GODOT_SOURCE_DIR before rebuilding GodotARKit.xcframework."
	fi
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

if needs_export_preset; then
	printf "\nGodot export templates\n"
	template_dir="$(resolve_export_templates_dir)"
	if needs_ios_tools; then
		check_file "$template_dir/ios.zip" "required for iPad/iOS Simulator export; install Godot 4.4.1 export templates, or run tools/c00/install_godot_export_templates.sh --tpz <Godot_v4.4.1-stable_export_templates.tpz>"
	fi
	if needs_android_tools; then
		check_file "$template_dir/android_source.zip" "required for Android Gradle exports used by Rokid/OpenXR and ARCore; install Godot 4.4.1 export templates"
	fi
fi

if needs_android_tools; then
	printf "\nAndroid export toolchain\n"
	android_sdk_dir="$(resolve_android_sdk_dir)"
	debug_keystore="$(resolve_android_debug_keystore)"
	check_dir "$android_sdk_dir/platform-tools" "Android SDK platform-tools directory required by Godot export settings"
	check_dir "$android_sdk_dir/build-tools" "Android SDK build-tools directory required by Godot export settings"
	if find "$android_sdk_dir/build-tools" -path "*/apksigner" -type f -perm -111 2>/dev/null | head -n 1 | grep -q .; then
		printf "OK   Android apksigner under %s/build-tools\n" "$android_sdk_dir"
	else
		printf "MISS Android apksigner under %s/build-tools\n" "$android_sdk_dir"
		printf "     Install Android SDK build-tools and point GODOT_ANDROID_SDK_PATH, ANDROID_SDK_ROOT, or ANDROID_HOME at the SDK root.\n"
		status=1
	fi
	java_bin="$(resolve_java_binary || true)"
	keytool_bin="$(resolve_keytool_binary || true)"
	check_working_executable java "$java_bin" "-version" "required by Android Gradle export; install a real JDK and set JAVA_HOME/PATH so Godot can find it"
	check_working_executable keytool "$keytool_bin" "-help" "required to create or validate the Android debug keystore; install a real JDK"
	check_file "$debug_keystore" "required for debug APK signing; run tools/c00/configure_android_export_environment.sh --install-build-template"
	check_file "$PROJECT_ROOT/android/build/build.gradle" "required for Android Gradle exports; run tools/c00/install_android_build_template.sh after installing Godot export templates"
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
