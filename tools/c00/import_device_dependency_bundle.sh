#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

BUNDLE_DIR=""
VERSION="${GODOT_EXPORT_TEMPLATES_VERSION:-4.4.1.stable}"
EXPORT_TEMPLATES_DIR="${GODOT_EXPORT_TEMPLATES_DIR:-$HOME/Library/Application Support/Godot/export_templates/$VERSION}"
REPORT="${REPORT:-$PROJECT_ROOT/releases/phase_0_smoke/evidence/dependency-bundle-${TIMESTAMP}.md}"
ENV_FILE="${ENV_FILE:-$PROJECT_ROOT/.godot/cache/c00/device-env.sh}"

ANDROID_SDK_DIR="${GODOT_ANDROID_SDK_PATH:-${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}}"
JDK_HOME="${GODOT_JAVA_SDK_PATH:-${JAVA_HOME:-}}"
GODOT_BIN_PATH="${GODOT_BIN:-}"
GODOT_SOURCE_DIR_PATH="${GODOT_SOURCE_DIR:-${GODOT_SRC_DIR:-}}"

INSTALL_ANDROID_BUILD_TEMPLATE=1
CONFIGURE_ANDROID_EXPORT=0

pass_count=0
warn_count=0
miss_count=0

usage() {
	cat <<EOF
Usage:
  tools/c00/import_device_dependency_bundle.sh --bundle <dir> [options]

Options:
  --version <version>                 Godot export template version. Default: $VERSION
  --export-templates-dir <dir>        Export template install dir. Default: $EXPORT_TEMPLATES_DIR
  --android-sdk <dir>                 Android SDK root inside or outside the bundle.
  --jdk-home <dir>                    JDK home with bin/java and bin/keytool.
  --godot-bin <file>                  Godot editor binary.
  --godot-source <dir>                Godot source headers root for iOS plugin builds.
  --env-file <file>                   Environment file to write. Default: $ENV_FILE
  --report <file>                     Markdown report path. Default: $REPORT
  --no-install-android-build-template Skip android/build template install.
  --configure-android-export          Also write Godot Android EditorSettings when Godot/JDK/SDK exist.

Bundle layout can be flexible. The script searches for:
  - Godot_v4.4.1-stable_export_templates.tpz, or ios.zip + android_source.zip
  - android-sdk/platform-tools/adb and build-tools/*/apksigner
  - jdk*/bin/java and jdk*/bin/keytool
  - Godot.app/Contents/MacOS/Godot or a Godot executable
  - godot-source/core/version.h and platform/ios

After importing, use:
  source .godot/cache/c00/device-env.sh
  tools/c00/preflight.sh rokid
  tools/c00/preflight.sh ipad
EOF
}

while [[ "$#" -gt 0 ]]; do
	case "$1" in
		--bundle)
			BUNDLE_DIR="$2"
			shift 2
			;;
		--version)
			VERSION="$2"
			EXPORT_TEMPLATES_DIR="${GODOT_EXPORT_TEMPLATES_DIR:-$HOME/Library/Application Support/Godot/export_templates/$VERSION}"
			shift 2
			;;
		--export-templates-dir)
			EXPORT_TEMPLATES_DIR="$2"
			shift 2
			;;
		--android-sdk)
			ANDROID_SDK_DIR="$2"
			shift 2
			;;
		--jdk-home)
			JDK_HOME="$2"
			shift 2
			;;
		--godot-bin)
			GODOT_BIN_PATH="$2"
			shift 2
			;;
		--godot-source)
			GODOT_SOURCE_DIR_PATH="$2"
			shift 2
			;;
		--env-file)
			ENV_FILE="$2"
			shift 2
			;;
		--report)
			REPORT="$2"
			shift 2
			;;
		--no-install-android-build-template)
			INSTALL_ANDROID_BUILD_TEMPLATE=0
			shift
			;;
		--configure-android-export)
			CONFIGURE_ANDROID_EXPORT=1
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

if [[ -z "$BUNDLE_DIR" ]]; then
	usage >&2
	exit 2
fi

absolute_existing_dir() {
	local input="$1"
	(cd "$input" && pwd)
}

absolute_parent_file() {
	local input="$1"
	local dir
	dir="$(cd "$(dirname "$input")" && pwd)"
	printf "%s/%s" "$dir" "$(basename "$input")"
}

BUNDLE_DIR="$(absolute_existing_dir "$BUNDLE_DIR")"
EXPORT_TEMPLATES_DIR="${EXPORT_TEMPLATES_DIR/#\~/$HOME}"
REPORT="${REPORT/#\~/$HOME}"
ENV_FILE="${ENV_FILE/#\~/$HOME}"

mkdir -p "$(dirname "$REPORT")" "$(dirname "$ENV_FILE")"

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

find_first() {
	local expression="$1"
	find "$BUNDLE_DIR" -maxdepth 6 -type f \( $expression \) -print -quit 2>/dev/null || true
}

find_first_dir_by_file() {
	local pattern="$1"
	local found
	found="$(find "$BUNDLE_DIR" -maxdepth 8 -type f -path "$pattern" -print -quit 2>/dev/null || true)"
	if [[ -n "$found" ]]; then
		dirname "$(dirname "$found")"
	fi
}

find_android_sdk_dir() {
	if [[ -n "$ANDROID_SDK_DIR" && -d "$ANDROID_SDK_DIR" ]]; then
		absolute_existing_dir "$ANDROID_SDK_DIR"
		return 0
	fi

	local adb_file
	adb_file="$(find "$BUNDLE_DIR" -maxdepth 8 -type f -path "*/platform-tools/adb" -perm -111 -print -quit 2>/dev/null || true)"
	if [[ -n "$adb_file" ]]; then
		dirname "$(dirname "$adb_file")"
		return 0
	fi
	return 1
}

find_jdk_home() {
	if [[ -n "$JDK_HOME" && -x "$JDK_HOME/bin/java" && -x "$JDK_HOME/bin/keytool" ]]; then
		absolute_existing_dir "$JDK_HOME"
		return 0
	fi

	local java_file
	java_file="$(find "$BUNDLE_DIR" -maxdepth 8 -type f -path "*/bin/java" -perm -111 -print -quit 2>/dev/null || true)"
	if [[ -n "$java_file" ]]; then
		local home
		home="$(dirname "$(dirname "$java_file")")"
		if [[ -x "$home/bin/keytool" ]]; then
			printf "%s" "$home"
			return 0
		fi
	fi
	return 1
}

find_godot_bin() {
	if [[ -n "$GODOT_BIN_PATH" && -x "$GODOT_BIN_PATH" ]]; then
		absolute_parent_file "$GODOT_BIN_PATH"
		return 0
	fi

	local app_bin
	app_bin="$(find "$BUNDLE_DIR" -maxdepth 8 -type f -path "*/Godot.app/Contents/MacOS/Godot" -perm -111 -print -quit 2>/dev/null || true)"
	if [[ -n "$app_bin" ]]; then
		printf "%s" "$app_bin"
		return 0
	fi

	local bin
	bin="$(find "$BUNDLE_DIR" -maxdepth 4 -type f -iname "godot*" -perm -111 -print -quit 2>/dev/null || true)"
	if [[ -n "$bin" ]]; then
		printf "%s" "$bin"
		return 0
	fi
	return 1
}

find_godot_source_dir() {
	if [[ -n "$GODOT_SOURCE_DIR_PATH" && -f "$GODOT_SOURCE_DIR_PATH/core/version.h" && -d "$GODOT_SOURCE_DIR_PATH/platform/ios" ]]; then
		absolute_existing_dir "$GODOT_SOURCE_DIR_PATH"
		return 0
	fi

	local version_file
	version_file="$(find "$BUNDLE_DIR" -maxdepth 8 -type f -path "*/core/version.h" -print -quit 2>/dev/null || true)"
	if [[ -n "$version_file" ]]; then
		local source_dir
		source_dir="$(dirname "$(dirname "$version_file")")"
		if [[ -d "$source_dir/platform/ios" ]]; then
			printf "%s" "$source_dir"
			return 0
		fi
	fi
	return 1
}

find_apksigner() {
	local sdk_dir="$1"
	find "$sdk_dir/build-tools" -path "*/apksigner" -type f -perm -111 -print -quit 2>/dev/null || true
}

install_export_templates() {
	local tpz ios_zip android_zip
	tpz="$(find "$BUNDLE_DIR" -maxdepth 6 -type f \( -name "Godot_v*-stable_export_templates.tpz" -o -name "*export_templates*.tpz" \) -print -quit 2>/dev/null || true)"
	ios_zip="$(find "$BUNDLE_DIR" -maxdepth 6 -type f -name "ios.zip" -print -quit 2>/dev/null || true)"
	android_zip="$(find "$BUNDLE_DIR" -maxdepth 6 -type f -name "android_source.zip" -print -quit 2>/dev/null || true)"

	if [[ -n "$tpz" ]]; then
		if "$PROJECT_ROOT/tools/c00/install_godot_export_templates.sh" --tpz "$tpz" --version "$VERSION" --dir "$EXPORT_TEMPLATES_DIR" >/dev/null; then
			add_row PASS "Godot export templates import" "$tpz -> $EXPORT_TEMPLATES_DIR"
		else
			add_row MISS "Godot export templates import" "Failed to install $tpz"
		fi
	elif [[ -n "$ios_zip" && -n "$android_zip" ]]; then
		mkdir -p "$EXPORT_TEMPLATES_DIR"
		cp "$ios_zip" "$EXPORT_TEMPLATES_DIR/ios.zip"
		cp "$android_zip" "$EXPORT_TEMPLATES_DIR/android_source.zip"
		add_row PASS "Godot export templates import" "Copied ios.zip and android_source.zip -> $EXPORT_TEMPLATES_DIR"
	else
		add_row MISS "Godot export templates import" "Bundle must include Godot export templates .tpz, or both ios.zip and android_source.zip."
	fi

	if [[ -f "$EXPORT_TEMPLATES_DIR/ios.zip" ]]; then
		add_row PASS "Godot iOS export template" "$EXPORT_TEMPLATES_DIR/ios.zip"
	else
		add_row MISS "Godot iOS export template" "Missing ios.zip after import."
	fi

	if [[ -f "$EXPORT_TEMPLATES_DIR/android_source.zip" ]]; then
		add_row PASS "Godot Android source template" "$EXPORT_TEMPLATES_DIR/android_source.zip"
	else
		add_row MISS "Godot Android source template" "Missing android_source.zip after import."
	fi
}

{
	printf "# C00 Device Dependency Bundle Import\n\n"
	printf "Generated: %s\n\n" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
	printf "Project: \`%s\`\n\n" "$PROJECT_ROOT"
	printf "Bundle: \`%s\`\n\n" "$BUNDLE_DIR"
	printf "## Checks\n\n"
	printf "| Status | Item | Detail |\n"
	printf "| --- | --- | --- |\n"
} > "$REPORT"

install_export_templates

if ANDROID_SDK_DIR="$(find_android_sdk_dir)"; then
	add_row PASS "Android SDK" "$ANDROID_SDK_DIR"
	if [[ -x "$ANDROID_SDK_DIR/platform-tools/adb" ]]; then
		add_row PASS "adb" "$ANDROID_SDK_DIR/platform-tools/adb"
	else
		add_row MISS "adb" "Missing executable platform-tools/adb under Android SDK."
	fi
	if apksigner_path="$(find_apksigner "$ANDROID_SDK_DIR")" && [[ -n "$apksigner_path" ]]; then
		add_row PASS "Android apksigner" "$apksigner_path"
	else
		add_row MISS "Android apksigner" "Missing executable build-tools/*/apksigner under Android SDK."
	fi
else
	add_row MISS "Android SDK" "Pass --android-sdk <dir>, or place android-sdk/platform-tools/adb in the bundle."
fi

if JDK_HOME="$(find_jdk_home)"; then
	add_row PASS "JDK" "$JDK_HOME"
	if "$JDK_HOME/bin/java" -version >/dev/null 2>&1; then
		add_row PASS "java" "$JDK_HOME/bin/java"
	else
		add_row MISS "java" "$JDK_HOME/bin/java did not run."
	fi
	if "$JDK_HOME/bin/keytool" -help >/dev/null 2>&1; then
		add_row PASS "keytool" "$JDK_HOME/bin/keytool"
	else
		add_row MISS "keytool" "$JDK_HOME/bin/keytool did not run."
	fi
else
	add_row MISS "JDK" "Pass --jdk-home <dir>, or place a JDK with bin/java and bin/keytool in the bundle."
fi

if GODOT_BIN_PATH="$(find_godot_bin)"; then
	add_row PASS "Godot binary" "$GODOT_BIN_PATH"
else
	add_row WARN "Godot binary" "Set GODOT_BIN manually if Godot is already installed outside the bundle."
fi

if GODOT_SOURCE_DIR_PATH="$(find_godot_source_dir)"; then
	add_row PASS "Godot source headers" "$GODOT_SOURCE_DIR_PATH"
else
	add_row WARN "Godot source headers" "Run tools/c00/prepare_godot_source.sh --tag <godot-tag> before rebuilding GodotARKit.xcframework."
fi

{
	printf "# Source this file before C00 device gates.\n"
	printf "# Generated by tools/c00/import_device_dependency_bundle.sh at %s.\n" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
	printf "export GODOT_EXPORT_TEMPLATES_VERSION=%q\n" "$VERSION"
	printf "export GODOT_EXPORT_TEMPLATES_DIR=%q\n" "$EXPORT_TEMPLATES_DIR"
	if [[ -n "$ANDROID_SDK_DIR" ]]; then
		printf "export GODOT_ANDROID_SDK_PATH=%q\n" "$ANDROID_SDK_DIR"
		printf "export ANDROID_SDK_ROOT=%q\n" "$ANDROID_SDK_DIR"
		printf "export ANDROID_HOME=%q\n" "$ANDROID_SDK_DIR"
		printf "export ADB_BIN=%q\n" "$ANDROID_SDK_DIR/platform-tools/adb"
	fi
	if [[ -n "$JDK_HOME" ]]; then
		printf "export GODOT_JAVA_SDK_PATH=%q\n" "$JDK_HOME"
		printf "export JAVA_HOME=%q\n" "$JDK_HOME"
	fi
	if [[ -n "$GODOT_BIN_PATH" ]]; then
		printf "export GODOT_BIN=%q\n" "$GODOT_BIN_PATH"
	fi
	if [[ -n "$GODOT_SOURCE_DIR_PATH" ]]; then
		printf "export GODOT_SOURCE_DIR=%q\n" "$GODOT_SOURCE_DIR_PATH"
	fi
	path_entries=()
	if [[ -n "$JDK_HOME" ]]; then
		path_entries+=("$JDK_HOME/bin")
	fi
	if [[ -n "$ANDROID_SDK_DIR" ]]; then
		path_entries+=("$ANDROID_SDK_DIR/platform-tools")
		if apksigner_path="$(find_apksigner "$ANDROID_SDK_DIR")" && [[ -n "$apksigner_path" ]]; then
			path_entries+=("$(dirname "$apksigner_path")")
		fi
	fi
	if [[ "${#path_entries[@]}" -gt 0 ]]; then
		joined_path=""
		for entry in "${path_entries[@]}"; do
			if [[ -z "$joined_path" ]]; then
				joined_path="$entry"
			else
				joined_path="$joined_path:$entry"
			fi
		done
		printf "export PATH=%q:\$PATH\n" "$joined_path"
	fi
} > "$ENV_FILE"
add_row PASS "Environment file" "$ENV_FILE"

if [[ "$INSTALL_ANDROID_BUILD_TEMPLATE" == "1" && -f "$EXPORT_TEMPLATES_DIR/android_source.zip" ]]; then
	if "$PROJECT_ROOT/tools/c00/install_android_build_template.sh" --source "$EXPORT_TEMPLATES_DIR/android_source.zip" --version "$VERSION" >/dev/null; then
		add_row PASS "Android build template" "android/build"
	else
		add_row MISS "Android build template" "Run tools/c00/install_android_build_template.sh manually and inspect existing android/build changes."
	fi
fi

if [[ "$CONFIGURE_ANDROID_EXPORT" == "1" ]]; then
	if [[ -n "$GODOT_BIN_PATH" && -n "$ANDROID_SDK_DIR" && -n "$JDK_HOME" ]]; then
		if GODOT_BIN="$GODOT_BIN_PATH" GODOT_ANDROID_SDK_PATH="$ANDROID_SDK_DIR" GODOT_JAVA_SDK_PATH="$JDK_HOME" "$PROJECT_ROOT/tools/c00/configure_android_export_environment.sh" --install-build-template >/dev/null; then
			add_row PASS "Godot Android EditorSettings" "Configured through configure_android_export_environment.sh"
		else
			add_row MISS "Godot Android EditorSettings" "configure_android_export_environment.sh failed."
		fi
	else
		add_row MISS "Godot Android EditorSettings" "--configure-android-export needs Godot binary, Android SDK, and JDK."
	fi
fi

{
	printf "\n## Summary\n\n"
	printf "%s\n" "- Pass: $pass_count"
	printf "%s\n" "- Warn: $warn_count"
	printf "%s\n" "- Missing: $miss_count"
	printf "\n## Next Commands\n\n"
	printf '```bash\n'
	printf "source %q\n" "$ENV_FILE"
	printf "tools/c00/preflight.sh rokid\n"
	printf "tools/c00/preflight.sh ipad\n"
	printf "tools/c00/preflight.sh android-arcore\n"
	printf '```\n\n'
	printf "If preflight passes, run:\n\n"
	printf '```bash\n'
	printf "tools/c00/run_device_cycle.sh all\n"
	printf '```\n'
} >> "$REPORT"

cat "$REPORT"

if [[ "$miss_count" -gt 0 ]]; then
	exit 1
fi
