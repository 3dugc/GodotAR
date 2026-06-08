#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
REPORT="${REPORT:-$PROJECT_ROOT/releases/phase_0_smoke/evidence/device-readiness-${TIMESTAMP}.md}"
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
Rokid/OpenXR and iPad/ARKit gates.
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

	local app_path=""
	app_path="$(find /Applications -maxdepth 3 -iname '*Godot*.app' 2>/dev/null | head -n 1 || true)"
	if [[ -n "$app_path" && -x "$app_path/Contents/MacOS/Godot" ]]; then
		printf "%s" "$app_path/Contents/MacOS/Godot"
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

run_capture() {
	local output=""
	if output="$("$@" 2>&1)"; then
		printf "%s" "$output"
		return 0
	fi
	printf "%s" "$output"
	return 1
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

check_command_row adb "required for Rokid/Android install, logcat, screenshot, and recording"
check_command_row xcrun "required for iPad install/launch and iOS SDK checks"
check_command_row xcodebuild "required for building the Godot iOS export into an installable .app"

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

if [[ -n "${GODOT_SOURCE_DIR:-${GODOT_SRC_DIR:-}}" ]]; then
	godot_source="${GODOT_SOURCE_DIR:-${GODOT_SRC_DIR:-}}"
	if [[ -f "$godot_source/core/version.h" && -d "$godot_source/platform/ios" ]]; then
		add_row PASS "Godot source headers" "$godot_source"
	else
		add_row MISS "Godot source headers" "$godot_source is missing core/version.h or platform/ios."
	fi
else
	add_row WARN "Godot source headers" "Set GODOT_SOURCE_DIR before building GodotARKit.xcframework."
fi

if "$PROJECT_ROOT/tools/c00/check_arkit_plugin_static.sh" >/dev/null 2>&1; then
	add_row PASS "ARKit Objective-C++ syntax smoke" "Plugin sources compile against local iOS SDK with Godot stubs."
else
	add_row MISS "ARKit Objective-C++ syntax smoke" "Run tools/c00/check_arkit_plugin_static.sh for details."
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
		printf "\n## Summary\n\n"
		printf "%s\n" "- Pass: $pass_count"
		printf "%s\n" "- Warn: $warn_count"
		printf "%s\n" "- Missing: $miss_count"
		printf "\n## Next Commands\n\n"
	printf "1. Generate or refresh export presets if missing:\n\n"
	printf "   \`\`\`bash\n"
	printf "   tools/c00/bootstrap_device_machine.sh --write-export-presets --package %s --bundle %s --team-id %s\n" "$PACKAGE_ID" "$BUNDLE_ID" "$TEAM_ID"
	printf "   \`\`\`\n\n"
	printf "2. Review signing, OpenXR loader, and iOS plugin options in Godot editor, then save \`export_presets.cfg\`.\n\n"
	printf "3. Build the ARKit iOS plugin on the device machine:\n\n"
	printf "   \`\`\`bash\n"
	printf "   GODOT_SOURCE_DIR=/path/to/godot ios/plugins/godot_arkit/build_xcframework.sh\n"
	printf "   \`\`\`\n\n"
	printf "4. Run the first phase gates:\n\n"
	printf "   \`\`\`bash\n"
	printf "   GODOT_SOURCE_DIR=/path/to/godot DEVICE=<ipad-uuid-or-name> tools/c00/run_device_cycle.sh all\n"
	printf "   \`\`\`\n\n"
	printf "   The iPad gate will build the exported Xcode project into \`builds/ipad/GodotXRFoundation.app\` when \`APP_PATH\` is empty.\n\n"
	printf "5. Publish only when \`releases/phase_0_smoke/C00_PHASE_REPORT.md\` reports PASS for Rokid/OpenXR, iPad/ARKit, and Android/ARCore.\n"
} >> "$REPORT"

cat "$REPORT"

if [[ "$miss_count" -gt 0 ]]; then
	exit 1
fi
