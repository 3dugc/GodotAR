#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
DEFAULT_DEVICE_ENV_FILE="$PROJECT_ROOT/.godot/cache/c00/device-env.sh"

source_device_env_if_present() {
	local env_file="${C00_DEVICE_ENV_FILE:-$DEFAULT_DEVICE_ENV_FILE}"
	if [[ "${C00_AUTO_SOURCE_DEVICE_ENV:-1}" == "1" && -f "$env_file" ]]; then
		# shellcheck disable=SC1090
		source "$env_file"
	fi
}

source_device_env_if_present

REPORT="${REPORT:-$PROJECT_ROOT/releases/phase_0_smoke/evidence/device-readiness-${TIMESTAMP}.md}"
DEFAULT_GODOT_SOURCE_DIR="$PROJECT_ROOT/.godot/cache/c00/godot-source"
DOWNLOADS_DIR="$PROJECT_ROOT/.godot/cache/c00/downloads"
WRITE_EXPORT_PRESETS=0
FORCE_EXPORT_PRESETS=0
PACKAGE_ID="${PACKAGE:-org.godotengine.godotxrfoundation}"
BUNDLE_ID="${BUNDLE_ID:-$PACKAGE_ID}"
TEAM_ID="${TEAM_ID:-TEAMID}"

usage() {
	cat <<EOF
Usage:
  tools/c00/bootstrap_device_machine.sh [options]

Options:
  --report <file>              Readiness report path.
  --write-export-presets       Generate export_presets.cfg starter when missing.
  --force-export-presets       Overwrite export_presets.cfg with starter.
  --package <id>               Android package id. Default: $PACKAGE_ID
  --bundle <id>                iOS bundle id. Default: package id.
  --team-id <id>               Apple Team ID placeholder. Default: $TEAM_ID

This script prepares a device machine for C00. It does not install Godot,
Android platform tools, certificates, provisioning profiles, or device runtimes.
It produces a report with the exact missing prerequisites and next commands for
Rokid/OpenXR, iPad/ARKit, and Android/ARCore gates.
EOF
}

while [[ "$#" -gt 0 ]]; do
	case "$1" in
		--report)
			REPORT="$2"
			shift 2
			;;
		--write-export-presets)
			WRITE_EXPORT_PRESETS=1
			shift
			;;
		--force-export-presets)
			WRITE_EXPORT_PRESETS=1
			FORCE_EXPORT_PRESETS=1
			shift
			;;
		--package)
			PACKAGE_ID="$2"
			if [[ "$BUNDLE_ID" == "${PACKAGE:-org.godotengine.godotxrfoundation}" ]]; then
				BUNDLE_ID="$PACKAGE_ID"
			fi
			shift 2
			;;
		--bundle)
			BUNDLE_ID="$2"
			shift 2
			;;
		--team-id)
			TEAM_ID="$2"
			shift 2
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

mkdir -p "$(dirname "$REPORT")"

pass_count=0
warn_count=0
miss_count=0

escape_md() {
	local value="$1"
	value="${value//$'\n'/ }"
	value="${value//|/\\|}"
	printf "%s" "$value"
}

add_row() {
	local status="$1"
	local item="$2"
	local detail="$3"
	case "$status" in
		PASS) pass_count=$((pass_count + 1)) ;;
		WARN) warn_count=$((warn_count + 1)) ;;
		MISS) miss_count=$((miss_count + 1)) ;;
	esac
	printf "| %s | %s | %s |\n" "$status" "$(escape_md "$item")" "$(escape_md "$detail")" >> "$REPORT"
}

find_godot_binary() {
	if [[ -n "${GODOT_BIN:-}" && -x "$GODOT_BIN" ]]; then
		printf "%s" "$GODOT_BIN"
		return 0
	fi

	if command -v godot >/dev/null 2>&1; then
		command -v godot
		return 0
	fi

	local bundled_path="$PROJECT_ROOT/.godot/cache/c00/godot-editor/Godot.app/Contents/MacOS/Godot"
	if [[ -x "$bundled_path" ]]; then
		printf "%s" "$bundled_path"
		return 0
	fi

	local app_path=""
	app_path="$(find /Applications -maxdepth 3 -iname '*Godot*.app' 2>/dev/null | head -n 1 || true)"
	if [[ -n "$app_path" && -x "$app_path/Contents/MacOS/Godot" ]]; then
		printf "%s" "$app_path/Contents/MacOS/Godot"
		return 0
	fi

	return 1
}

find_adb_binary() {
	if [[ -n "${ADB_BIN:-}" && -x "$ADB_BIN" ]]; then
		printf "%s" "$ADB_BIN"
		return 0
	fi
	if command -v adb >/dev/null 2>&1; then
		command -v adb
		return 0
	fi
	local bundled_path="$PROJECT_ROOT/.godot/cache/c00/android-sdk/platform-tools/adb"
	if [[ -x "$bundled_path" ]]; then
		printf "%s" "$bundled_path"
		return 0
	fi
	return 1
}

find_java_sdk() {
	if [[ -n "${GODOT_JAVA_SDK_PATH:-}" && -x "$GODOT_JAVA_SDK_PATH/bin/java" && -x "$GODOT_JAVA_SDK_PATH/bin/keytool" ]]; then
		printf "%s" "$GODOT_JAVA_SDK_PATH"
		return 0
	fi
	if [[ -n "${JAVA_HOME:-}" && -x "$JAVA_HOME/bin/java" && -x "$JAVA_HOME/bin/keytool" ]]; then
		printf "%s" "$JAVA_HOME"
		return 0
	fi
	local bundled_path="$PROJECT_ROOT/.godot/cache/c00/jdk/Contents/Home"
	if [[ -x "$bundled_path/bin/java" && -x "$bundled_path/bin/keytool" ]]; then
		printf "%s" "$bundled_path"
		return 0
	fi
	return 1
}

check_command_row() {
	local command_name="$1"
	local purpose="$2"
	if command -v "$command_name" >/dev/null 2>&1; then
		add_row PASS "$command_name" "$(command -v "$command_name")"
	else
		add_row MISS "$command_name" "$purpose"
	fi
}

check_working_executable_row() {
	local label="$1"
	local executable="$2"
	local probe="$3"
	local purpose="$4"
	if [[ -n "$executable" && -x "$executable" ]] && "$executable" $probe >/dev/null 2>&1; then
		add_row PASS "$label" "$executable"
	else
		add_row MISS "$label" "$purpose"
	fi
}

check_working_command_row() {
	local command_name="$1"
	local probe="$2"
	local purpose="$3"
	if command -v "$command_name" >/dev/null 2>&1 && "$command_name" $probe >/dev/null 2>&1; then
		add_row PASS "$command_name" "$(command -v "$command_name")"
	else
		add_row MISS "$command_name" "$purpose"
	fi
}

is_valid_godot_source() {
	local dir="$1"
	[[ -f "$dir/core/version.h" \
		&& -f "$dir/core/object/class_db.h" \
		&& -f "$dir/core/config/engine.h" \
		&& -d "$dir/platform/ios" ]]
}

run_capture() {
	local output=""
	if output="$("$@" 2>&1)"; then
		printf "%s" "$output"
		return 0
	fi
	printf "%s" "$output"
	return 1
}

resolve_template_version() {
	if [[ -n "${GODOT_EXPORT_TEMPLATES_VERSION:-}" ]]; then
		printf "%s" "$GODOT_EXPORT_TEMPLATES_VERSION"
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
	elif [[ -d "$HOME/Library/Android/sdk" ]]; then
		printf "%s" "$HOME/Library/Android/sdk"
	else
		printf "%s" "$PROJECT_ROOT/.godot/cache/c00/android-sdk"
	fi
}

resolve_android_debug_keystore() {
	if [[ -n "${GODOT_ANDROID_KEYSTORE_DEBUG_PATH:-}" ]]; then
		printf "%s" "$GODOT_ANDROID_KEYSTORE_DEBUG_PATH"
	else
		printf "%s" "$PROJECT_ROOT/.godot/cache/c00/android/debug.keystore"
	fi
}

file_size_bytes() {
	local file="$1"
	if [[ -f "$file" ]]; then
		wc -c < "$file" | tr -d ' '
	else
		printf "0"
	fi
}

append_download_cache_row() {
	local label="$1"
	local file_name="$2"
	local command="$3"
	local path="$DOWNLOADS_DIR/$file_name"
	local state="missing"
	if [[ -f "$path" ]]; then
		state="$(file_size_bytes "$path") bytes"
	fi
	printf "| %s | %s | %s |\n" "$(escape_md "$label")" "$(escape_md "$state")" "$(escape_md "$command")" >> "$REPORT"
}

{
	printf "# C00 Device Machine Readiness\n\n"
	printf "Generated: %s\n\n" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
	printf "Project: \`%s\`\n\n" "$PROJECT_ROOT"
	printf "## Checks\n\n"
	printf "| Status | Item | Detail |\n"
	printf "| --- | --- | --- |\n"
} > "$REPORT"

check_command_row node "required for C00 validators"

if godot_path="$(find_godot_binary)"; then
	add_row PASS "Godot binary" "$godot_path"
else
	add_row MISS "Godot binary" "Install Godot or set GODOT_BIN=/path/to/Godot."
fi

if adb_path="$(find_adb_binary)"; then
	add_row PASS "adb" "$adb_path"
else
	add_row MISS "adb" "required for Rokid/Android install, logcat, screenshot, and recording"
fi
check_command_row xcrun "required for iPad install/launch and iOS SDK checks"
check_command_row xcodebuild "required for building the Godot iOS export into an installable .app"
if java_sdk="$(find_java_sdk)"; then
	add_row PASS "Java SDK" "$java_sdk"
	check_working_executable_row java "$java_sdk/bin/java" "-version" "required by Android Gradle export; install OpenJDK 17."
	check_working_executable_row keytool "$java_sdk/bin/keytool" "-help" "required to create or validate the Android debug keystore; install OpenJDK 17."
else
	check_working_command_row java "-version" "required by Android Gradle export; install OpenJDK 17 or run tools/c00/install_openjdk17.sh --download."
	check_working_command_row keytool "-help" "required to create or validate the Android debug keystore; install OpenJDK 17 or run tools/c00/install_openjdk17.sh --download."
fi

if command -v xcrun >/dev/null 2>&1; then
	if sdk_path="$(run_capture xcrun --sdk iphoneos --show-sdk-path)"; then
		add_row PASS "iPhoneOS SDK" "$sdk_path"
	else
		add_row MISS "iPhoneOS SDK" "$sdk_path"
	fi

	if sdk_path="$(run_capture xcrun --sdk iphonesimulator --show-sdk-path)"; then
		add_row PASS "iPhoneSimulator SDK" "$sdk_path"
	else
		add_row WARN "iPhoneSimulator SDK" "$sdk_path"
	fi
fi

godot_source="${GODOT_SOURCE_DIR:-${GODOT_SRC_DIR:-}}"
if [[ -z "$godot_source" && -d "$DEFAULT_GODOT_SOURCE_DIR" ]]; then
	godot_source="$DEFAULT_GODOT_SOURCE_DIR"
fi
if [[ -n "$godot_source" ]]; then
	if is_valid_godot_source "$godot_source"; then
		add_row PASS "Godot source headers" "$godot_source"
	else
		add_row MISS "Godot source headers" "$godot_source is missing core/version.h, core/object/class_db.h, core/config/engine.h, or platform/ios."
	fi
else
	add_row WARN "Godot source headers" "Run tools/c00/prepare_godot_source.sh --tag <godot-tag>, then set GODOT_SOURCE_DIR before building GodotARKit.xcframework."
fi

if "$PROJECT_ROOT/tools/c00/check_arkit_plugin_static.sh" >/dev/null 2>&1; then
	add_row PASS "ARKit Objective-C++ syntax smoke" "Plugin sources compile against local iOS SDK with Godot stubs."
else
	add_row MISS "ARKit Objective-C++ syntax smoke" "Run tools/c00/check_arkit_plugin_static.sh for details."
fi

if [[ -d "$PROJECT_ROOT/addons/godotopenxrvendors" ]]; then
	add_row PASS "OpenXR Vendors plugin" "addons/godotopenxrvendors"
else
	add_row MISS "OpenXR Vendors plugin" "Run tools/c00/install_openxr_vendors.sh, or install the Godot OpenXR Vendors plugin into addons/godotopenxrvendors before Rokid/OpenXR export."
fi

if plugin_output="$(run_capture node "$PROJECT_ROOT/tools/c00/check_ios_plugin_artifacts.js")"; then
	add_row PASS "GodotARKit.gdip plugin config" "$plugin_output"
else
	add_row MISS "GodotARKit.gdip plugin config" "$plugin_output"
fi

if [[ -f "$PROJECT_ROOT/ios/plugins/godot_arkit/GodotARKit.gdip" ]]; then
	add_row PASS "GodotARKit.gdip" "ios/plugins/godot_arkit/GodotARKit.gdip"
else
	add_row MISS "GodotARKit.gdip" "Run GODOT_SOURCE_DIR=/path/to/godot ios/plugins/godot_arkit/build_xcframework.sh."
fi

if [[ -d "$PROJECT_ROOT/ios/plugins/godot_arkit/GodotARKit.xcframework" ]]; then
	add_row PASS "GodotARKit.xcframework" "ios/plugins/godot_arkit/GodotARKit.xcframework"
else
	add_row MISS "GodotARKit.xcframework" "Run GODOT_SOURCE_DIR=/path/to/godot ios/plugins/godot_arkit/build_xcframework.sh."
fi

if [[ "$WRITE_EXPORT_PRESETS" == "1" ]]; then
	preset_args=(
		"$PROJECT_ROOT/tools/c00/write_export_presets_template.js"
		--output "$PROJECT_ROOT/export_presets.cfg"
		--package "$PACKAGE_ID"
		--bundle "$BUNDLE_ID"
		--team-id "$TEAM_ID"
	)
	if [[ "$FORCE_EXPORT_PRESETS" == "1" ]]; then
		preset_args+=(--force)
	fi
	if preset_output="$(run_capture node "${preset_args[@]}")"; then
		add_row PASS "export_presets.cfg starter" "$preset_output"
	else
		add_row MISS "export_presets.cfg starter" "$preset_output"
	fi
fi

if [[ -f "$PROJECT_ROOT/export_presets.cfg" ]]; then
	if preset_output="$(run_capture node "$PROJECT_ROOT/tools/c00/check_export_presets.js" --gate all --file "$PROJECT_ROOT/export_presets.cfg")"; then
		add_row PASS "export_presets.cfg C00 presets" "$preset_output"
	else
		add_row MISS "export_presets.cfg C00 presets" "$preset_output"
	fi
else
	add_row MISS "export_presets.cfg C00 presets" "Run tools/c00/bootstrap_device_machine.sh --write-export-presets, then review and save in Godot editor."
fi

templates_dir="$(resolve_export_templates_dir)"
if [[ -f "$templates_dir/ios.zip" ]]; then
	add_row PASS "Godot iOS export template" "$templates_dir/ios.zip"
else
	add_row MISS "Godot iOS export template" "Install Godot export templates, then ensure $templates_dir/ios.zip exists."
fi

if [[ -f "$templates_dir/android_source.zip" ]]; then
	add_row PASS "Godot Android source template" "$templates_dir/android_source.zip"
else
	add_row MISS "Godot Android source template" "Install Godot export templates, then ensure $templates_dir/android_source.zip exists."
fi

android_sdk_dir="$(resolve_android_sdk_dir)"
if [[ -d "$android_sdk_dir/platform-tools" ]]; then
	add_row PASS "Android SDK platform-tools" "$android_sdk_dir/platform-tools"
else
	add_row MISS "Android SDK platform-tools" "Install Android SDK platform-tools or set GODOT_ANDROID_SDK_PATH/ANDROID_SDK_ROOT/ANDROID_HOME."
fi

if [[ -d "$android_sdk_dir/build-tools" ]]; then
	add_row PASS "Android SDK build-tools" "$android_sdk_dir/build-tools"
else
	add_row MISS "Android SDK build-tools" "Install Android SDK build-tools so Godot can find apksigner."
fi

if find "$android_sdk_dir/build-tools" -path "*/apksigner" -type f -perm -111 2>/dev/null | head -n 1 | grep -q .; then
	add_row PASS "Android apksigner" "$android_sdk_dir/build-tools"
else
	add_row MISS "Android apksigner" "Install Android SDK build-tools so an executable apksigner exists."
fi

debug_keystore="$(resolve_android_debug_keystore)"
if [[ -f "$debug_keystore" ]]; then
	add_row PASS "Android debug keystore" "$debug_keystore"
else
	add_row MISS "Android debug keystore" "Run tools/c00/configure_android_export_environment.sh --install-build-template."
fi

if [[ -f "$PROJECT_ROOT/android/build/build.gradle" ]]; then
	add_row PASS "Android project build template" "android/build/build.gradle"
else
	add_row MISS "Android project build template" "Run tools/c00/install_android_build_template.sh after installing android_source.zip."
fi

static_report="$(dirname "$REPORT")/static-gates-${TIMESTAMP}.md"
if static_output="$(run_capture node "$PROJECT_ROOT/tools/c00/run_static_gates.js" --gate all --report "$static_report")"; then
	add_row PASS "C00 static gates" "$static_report"
else
	add_row MISS "C00 static gates" "$static_output"
fi

if [[ -f "$PROJECT_ROOT/project.godot" ]]; then
	add_row PASS "project.godot" "Project file exists."
else
	add_row MISS "project.godot" "Project file is missing."
fi

if grep -q 'run/main_scene="res://demo/00_device_smoke_test.tscn"' "$PROJECT_ROOT/project.godot"; then
	add_row PASS "C00 main scene" "res://demo/00_device_smoke_test.tscn"
else
	add_row MISS "C00 main scene" "project.godot does not point to C00 smoke scene."
fi

if grep -q 'openxr/enabled=true' "$PROJECT_ROOT/project.godot"; then
	add_row PASS "OpenXR project setting" "xr/openxr/enabled=true"
else
	add_row MISS "OpenXR project setting" "Enable OpenXR in project.godot."
fi

{
	printf "\n## Download Cache\n\n"
	printf "These files are optional cache state for resumable online installers. Partial files are safe to keep; installers validate or resume them before installing.\n\n"
	printf "| Item | Current cache state | Resume command |\n"
	printf "| --- | --- | --- |\n"
} >> "$REPORT"
append_download_cache_row "Godot export templates" "Godot_v4.4.1-stable_export_templates.tpz" "tools/c00/install_godot_export_templates.sh --download --version 4.4.1.stable"
append_download_cache_row "Android command line tools" "commandlinetools-mac-13114758_latest.zip" "tools/c00/install_android_sdk_packages.sh --download-cmdline-tools --yes"
append_download_cache_row "OpenJDK 17" "temurin17-mac-aarch64.tar.gz" "tools/c00/install_openjdk17.sh --download"

{
		printf "\n## Summary\n\n"
		printf "%s\n" "- Pass: $pass_count"
		printf "%s\n" "- Warn: $warn_count"
		printf "%s\n" "- Missing: $miss_count"
		printf "\n## Next Commands\n\n"
	printf "1. Generate or refresh export presets if missing:\n\n"
	printf "   \`\`\`bash\n"
	printf "   tools/c00/bootstrap_device_machine.sh --write-export-presets --package %s --bundle %s --team-id %s\n" "$PACKAGE_ID" "$BUNDLE_ID" "$TEAM_ID"
	printf "   \`\`\`\n\n"
	printf "2. Install the OpenXR Vendors plugin for Rokid/OpenXR if missing:\n\n"
	printf "   \`\`\`bash\n"
	printf "   tools/c00/install_openxr_vendors.sh\n"
	printf "   \`\`\`\n\n"
	printf "3. If the device machine is offline or downloads are unstable, import a dependency bundle first:\n\n"
	printf "   \`\`\`bash\n"
	printf "   tools/c00/import_device_dependency_bundle.sh --bundle <device-bundle-dir>\n"
	printf "   source .godot/cache/c00/device-env.sh\n"
	printf "   \`\`\`\n\n"
	printf "4. Install Godot 4.4.1 export templates and project Android build template if they were not imported from a bundle:\n\n"
	printf "   \`\`\`bash\n"
	printf "   tools/c00/install_godot_export_templates.sh --download --version 4.4.1.stable\n"
	printf "   tools/c00/install_android_build_template.sh\n"
	printf "   \`\`\`\n\n"
	printf "5. Install OpenJDK 17 and Android SDK build tools when they were not imported from a bundle:\n\n"
	printf "   \`\`\`bash\n"
	printf "   tools/c00/install_openjdk17.sh --download\n"
	printf "   export GODOT_JAVA_SDK_PATH=\"%s/.godot/cache/c00/jdk/Contents/Home\"\n" "$PROJECT_ROOT"
	printf "   export JAVA_HOME=\"\$GODOT_JAVA_SDK_PATH\"\n"
	printf "   tools/c00/install_android_sdk_packages.sh --download-cmdline-tools --yes\n"
	printf "   \`\`\`\n\n"
	printf "6. Configure Android SDK, debug keystore, and Godot Android EditorSettings:\n\n"
	printf "   \`\`\`bash\n"
	printf "   tools/c00/configure_android_export_environment.sh --install-build-template\n"
	printf "   \`\`\`\n\n"
	printf "7. Review signing, OpenXR loader/vendor, and iOS plugin options in Godot editor, then save \`export_presets.cfg\`.\n\n"
	printf "8. Prepare Godot source headers for the ARKit plugin if missing:\n\n"
	printf "   \`\`\`bash\n"
	printf "   tools/c00/prepare_godot_source.sh --tag <godot-tag>\n"
	printf "   \`\`\`\n\n"
	printf "9. Build the ARKit iOS plugin on the device machine:\n\n"
	printf "   \`\`\`bash\n"
	printf "   GODOT_SOURCE_DIR=/path/to/godot ios/plugins/godot_arkit/build_xcframework.sh\n"
	printf "   \`\`\`\n\n"
	printf "10. Run the first phase gates:\n\n"
	printf "   \`\`\`bash\n"
	printf "   GODOT_SOURCE_DIR=/path/to/godot DEVICE=<ipad-uuid-or-name> tools/c00/run_device_cycle.sh all\n"
	printf "   \`\`\`\n\n"
	printf "   The iPad gate will build the exported Xcode project into \`builds/ipad/GodotXRFoundation.app\` when \`APP_PATH\` is empty.\n\n"
	printf "11. Publish only when \`releases/phase_0_smoke/C00_PHASE_REPORT.md\` reports PASS for Rokid/OpenXR, iPad/ARKit, and Android/ARCore.\n"
} >> "$REPORT"

cat "$REPORT"

if [[ "$miss_count" -gt 0 ]]; then
	exit 1
fi
