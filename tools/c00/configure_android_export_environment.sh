#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
. "$PROJECT_ROOT/tools/c00/godot_version_defaults.sh"
GODOT="${GODOT_BIN:-${GODOT:-}}"
ANDROID_SDK="${GODOT_ANDROID_SDK_PATH:-${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}}"
JAVA_SDK="${GODOT_JAVA_SDK_PATH:-${JAVA_HOME:-}}"
DEBUG_KEYSTORE="${GODOT_ANDROID_KEYSTORE_DEBUG_PATH:-$PROJECT_ROOT/.godot/cache/c00/android/debug.keystore}"
DEBUG_KEYSTORE_USER="${GODOT_ANDROID_KEYSTORE_DEBUG_USER:-androiddebugkey}"
DEBUG_KEYSTORE_PASS="${GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD:-android}"
TEMPLATE_VERSION="$(godot_normalize_template_version "${GODOT_EXPORT_TEMPLATES_VERSION:-$C00_GODOT_DEFAULT_EXPORT_TEMPLATES_VERSION}")"
ANDROID_COMPILE_SDK="${C00_ANDROID_COMPILE_SDK:-$(godot_android_compile_sdk_from_template_version "$TEMPLATE_VERSION")}"
ANDROID_BUILD_TOOLS_VERSION="${C00_ANDROID_BUILD_TOOLS_VERSION:-$(godot_android_build_tools_from_template_version "$TEMPLATE_VERSION")}"
ANDROID_NDK_VERSION="${C00_ANDROID_NDK_VERSION:-$(godot_android_ndk_from_template_version "$TEMPLATE_VERSION")}"
INSTALL_BUILD_TEMPLATE=0
CONFIGURE_GODOT_SETTINGS=1
REQUIRE_GODOT_SETTINGS="${C00_REQUIRE_GODOT_ANDROID_EDITOR_SETTINGS:-0}"
DRY_RUN=0

usage() {
	cat <<EOF
Usage:
  tools/c00/configure_android_export_environment.sh [options]

Options:
  --godot <path>              Godot editor binary. Defaults to GODOT_BIN/GODOT/godot.
  --android-sdk <dir>         Android SDK root. Defaults to GODOT_ANDROID_SDK_PATH, ANDROID_SDK_ROOT, ANDROID_HOME, ~/Library/Android/sdk, or .godot/cache/c00/android-sdk.
  --java-sdk <dir>            Java SDK root. Defaults to GODOT_JAVA_SDK_PATH, JAVA_HOME, or /usr/libexec/java_home on macOS.
  --keystore <file>           Debug keystore. Default: .godot/cache/c00/android/debug.keystore.
  --keystore-user <alias>     Debug keystore alias. Default: androiddebugkey.
  --keystore-pass <password>  Debug keystore password. Default: android.
  --install-build-template    Install android/build from android_source.zip when available.
  --skip-godot-settings       Do not write Godot EditorSettings.
  --dry-run                   Print actions without writing files.

This script prepares the local machine for Godot Android Gradle exports used by
Rokid/OpenXR and Android/ARCore C00 gates.
By default, a sandbox/CI permission failure while writing Godot EditorSettings is
reported as a warning because .godot/export_credentials.cfg is written separately.
Set C00_REQUIRE_GODOT_ANDROID_EDITOR_SETTINGS=1 to make that write mandatory.
EOF
}

while [[ "$#" -gt 0 ]]; do
	case "$1" in
		--godot)
			GODOT="$2"
			shift 2
			;;
		--android-sdk)
			ANDROID_SDK="$2"
			shift 2
			;;
		--java-sdk)
			JAVA_SDK="$2"
			shift 2
			;;
		--keystore)
			DEBUG_KEYSTORE="$2"
			shift 2
			;;
		--keystore-user)
			DEBUG_KEYSTORE_USER="$2"
			shift 2
			;;
		--keystore-pass)
			DEBUG_KEYSTORE_PASS="$2"
			shift 2
			;;
		--install-build-template)
			INSTALL_BUILD_TEMPLATE=1
			shift
			;;
		--skip-godot-settings)
			CONFIGURE_GODOT_SETTINGS=0
			shift
			;;
		--dry-run)
			DRY_RUN=1
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

resolve_godot() {
	if [[ -n "$GODOT" ]]; then
		printf "%s" "$GODOT"
		return 0
	fi
	if command -v godot >/dev/null 2>&1; then
		command -v godot
		return 0
	fi
	local bundled="$PROJECT_ROOT/.godot/cache/c00/godot-editor/Godot.app/Contents/MacOS/Godot"
	if [[ -x "$bundled" ]]; then
		printf "%s" "$bundled"
		return 0
	fi
	return 1
}

resolve_android_sdk() {
	if [[ -n "$ANDROID_SDK" ]]; then
		printf "%s" "$ANDROID_SDK"
	elif [[ -d "$HOME/Library/Android/sdk" ]]; then
		printf "%s" "$HOME/Library/Android/sdk"
	else
		printf "%s" "$PROJECT_ROOT/.godot/cache/c00/android-sdk"
	fi
}

resolve_java_sdk() {
	if [[ -n "$JAVA_SDK" ]]; then
		printf "%s" "$JAVA_SDK"
		return 0
	fi
	local bundled="$PROJECT_ROOT/.godot/cache/c00/jdk/Contents/Home"
	if [[ -x "$bundled/bin/java" && -x "$bundled/bin/keytool" ]]; then
		printf "%s" "$bundled"
		return 0
	fi
	if command -v /usr/libexec/java_home >/dev/null 2>&1; then
		local java_home
		if java_home="$(/usr/libexec/java_home 2>/dev/null)"; then
			printf "%s" "$java_home"
			return 0
		fi
	fi
	if [[ -n "${JAVA_HOME:-}" ]]; then
		printf "%s" "$JAVA_HOME"
		return 0
	fi
	return 1
}

check_dir() {
	local path="$1"
	local label="$2"
	if [[ -d "$path" ]]; then
		echo "OK   $label: $path"
	else
		echo "MISS $label: $path" >&2
		return 1
	fi
}

check_apksigner() {
	local sdk="$1"
	if [[ -x "$sdk/build-tools/$ANDROID_BUILD_TOOLS_VERSION/apksigner" ]]; then
		echo "OK   Android apksigner: $sdk/build-tools/$ANDROID_BUILD_TOOLS_VERSION/apksigner"
	else
		echo "MISS Android apksigner: $sdk/build-tools/$ANDROID_BUILD_TOOLS_VERSION/apksigner" >&2
		echo "Install Android SDK build-tools $ANDROID_BUILD_TOOLS_VERSION before exporting Rokid/OpenXR APKs." >&2
		return 1
	fi
}

GODOT="$(resolve_godot || true)"
ANDROID_SDK="$(resolve_android_sdk)"
JAVA_SDK="$(resolve_java_sdk || true)"

status=0
check_dir "$ANDROID_SDK/platform-tools" "Android platform-tools" || status=1
check_dir "$ANDROID_SDK/platforms/android-$ANDROID_COMPILE_SDK" "Android platform android-$ANDROID_COMPILE_SDK" || status=1
check_dir "$ANDROID_SDK/build-tools/$ANDROID_BUILD_TOOLS_VERSION" "Android build-tools $ANDROID_BUILD_TOOLS_VERSION" || status=1
if [[ -n "$ANDROID_NDK_VERSION" ]]; then
	check_dir "$ANDROID_SDK/ndk/$ANDROID_NDK_VERSION" "Android NDK $ANDROID_NDK_VERSION" || status=1
fi
check_apksigner "$ANDROID_SDK" || status=1
if [[ -n "$JAVA_SDK" && -d "$JAVA_SDK" ]]; then
	echo "OK   Java SDK: $JAVA_SDK"
else
	echo "MISS Java SDK: ${JAVA_SDK:-empty}" >&2
	status=1
fi

KEYTOOL="$JAVA_SDK/bin/keytool"
if [[ ! -x "$KEYTOOL" ]] && command -v keytool >/dev/null 2>&1; then
	KEYTOOL="$(command -v keytool)"
fi

if [[ -z "${KEYTOOL:-}" || ! -x "$KEYTOOL" ]]; then
	echo "MISS keytool: required to generate the Android debug keystore." >&2
	status=1
elif ! "$KEYTOOL" -help >/dev/null 2>&1; then
	echo "MISS keytool: command exists but no working JDK is available." >&2
	status=1
fi

if [[ "$DRY_RUN" == "1" ]]; then
	echo "DRY RUN: would create debug keystore at $DEBUG_KEYSTORE when missing."
else
	if [[ ! -f "$DEBUG_KEYSTORE" ]]; then
		if [[ -z "${KEYTOOL:-}" || ! -x "$KEYTOOL" ]] || ! "$KEYTOOL" -help >/dev/null 2>&1; then
			echo "ERROR: keytool is required to create $DEBUG_KEYSTORE" >&2
			exit 2
		fi
		mkdir -p "$(dirname "$DEBUG_KEYSTORE")"
		echo "Creating Android debug keystore: $DEBUG_KEYSTORE"
		"$KEYTOOL" -genkeypair \
			-keystore "$DEBUG_KEYSTORE" \
			-storepass "$DEBUG_KEYSTORE_PASS" \
			-keypass "$DEBUG_KEYSTORE_PASS" \
			-alias "$DEBUG_KEYSTORE_USER" \
			-keyalg RSA \
			-keysize 2048 \
			-validity 10000 \
			-dname "CN=GodotAR C00 Debug,O=GodotAR,C=US" >/dev/null
	else
		echo "OK   Android debug keystore: $DEBUG_KEYSTORE"
	fi
fi

if [[ "$INSTALL_BUILD_TEMPLATE" == "1" ]]; then
	if [[ "$DRY_RUN" == "1" ]]; then
		echo "DRY RUN: tools/c00/install_android_build_template.sh"
	else
		"$PROJECT_ROOT/tools/c00/install_android_build_template.sh" || status=1
	fi
fi

if [[ "$CONFIGURE_GODOT_SETTINGS" == "1" ]]; then
	if [[ -z "$GODOT" || ! -x "$GODOT" ]]; then
		echo "MISS Godot editor binary: set GODOT_BIN or pass --godot." >&2
		status=1
	elif [[ "$DRY_RUN" == "1" ]]; then
		echo "DRY RUN: would write Godot Android EditorSettings for $GODOT"
	else
		echo "Writing Godot Android EditorSettings..."
		set +e
		GODOT_ANDROID_SDK_PATH="$ANDROID_SDK" \
			GODOT_JAVA_SDK_PATH="$JAVA_SDK" \
			GODOT_ANDROID_KEYSTORE_DEBUG_PATH="$DEBUG_KEYSTORE" \
			GODOT_ANDROID_KEYSTORE_DEBUG_USER="$DEBUG_KEYSTORE_USER" \
			GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD="$DEBUG_KEYSTORE_PASS" \
			GODOT_EXPORT_TEMPLATES_VERSION="${GODOT_EXPORT_TEMPLATES_VERSION:-$C00_GODOT_DEFAULT_EXPORT_TEMPLATES_VERSION}" \
				node "$PROJECT_ROOT/tools/c00/write_godot_android_editor_settings.js"
		editor_settings_status=$?
		set -e
		if [[ "$editor_settings_status" -ne 0 ]]; then
			if [[ "$REQUIRE_GODOT_SETTINGS" == "1" ]]; then
				status=1
			else
				echo "WARN Godot Android EditorSettings write failed with status $editor_settings_status; continuing because this environment may not allow writing the user-level Godot config." >&2
				echo "     Set C00_REQUIRE_GODOT_ANDROID_EDITOR_SETTINGS=1 to make this fatal on device machines that require fresh EditorSettings." >&2
			fi
		fi
		GODOT_ANDROID_KEYSTORE_DEBUG_PATH="$DEBUG_KEYSTORE" \
		GODOT_ANDROID_KEYSTORE_DEBUG_USER="$DEBUG_KEYSTORE_USER" \
		GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD="$DEBUG_KEYSTORE_PASS" \
			node "$PROJECT_ROOT/tools/c00/write_godot_export_credentials.js" || status=1
	fi
fi

cat <<EOF

Android export environment:
  GODOT_ANDROID_SDK_PATH=$ANDROID_SDK
  GODOT_JAVA_SDK_PATH=$JAVA_SDK
  GODOT_ANDROID_KEYSTORE_DEBUG_PATH=$DEBUG_KEYSTORE
  GODOT_ANDROID_KEYSTORE_DEBUG_USER=$DEBUG_KEYSTORE_USER
EOF

exit "$status"
