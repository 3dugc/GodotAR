#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ANDROID_SDK="${GODOT_ANDROID_SDK_PATH:-${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$PROJECT_ROOT/.godot/cache/c00/android-sdk}}}"
SDKMANAGER="${SDKMANAGER:-}"
CMDLINE_TOOLS_ZIP="${CMDLINE_TOOLS_ZIP:-}"
CMDLINE_TOOLS_URL="${CMDLINE_TOOLS_URL:-https://dl.google.com/android/repository/commandlinetools-mac-13114758_latest.zip}"
PACKAGES=()
YES=0
DRY_RUN=0
INSTALL_CMDLINE_TOOLS=0

usage() {
	cat <<EOF
Usage:
  tools/c00/install_android_sdk_packages.sh [options] [sdkmanager package...]

Options:
  --android-sdk <dir>  Android SDK root. Default: GODOT_ANDROID_SDK_PATH, ANDROID_SDK_ROOT, ANDROID_HOME, or .godot/cache/c00/android-sdk.
  --sdkmanager <path>  sdkmanager executable.
  --cmdline-tools-zip <zip>
                       Existing Android command line tools zip.
  --download-cmdline-tools
                       Download Android command line tools for macOS when sdkmanager is missing.
  --cmdline-tools-url <url>
                       Download URL for --download-cmdline-tools.
  --yes                Accept Android SDK licenses from stdin.
  --dry-run            Print command without installing.

Default packages match Godot 4.4 Android export expectations:
  platform-tools platforms;android-34 build-tools;34.0.0

Download tuning:
  C00_CURL_RETRY=8 C00_CURL_RETRY_DELAY=15 C00_CURL_SPEED_LIMIT=1024 C00_CURL_SPEED_TIME=30 \\
    tools/c00/install_android_sdk_packages.sh --download-cmdline-tools --yes
EOF
}

download_with_resume() {
	local output="$1"
	local url="$2"
	local curl_retry="${C00_CURL_RETRY:-5}"
	local curl_retry_delay="${C00_CURL_RETRY_DELAY:-10}"
	local curl_connect_timeout="${C00_CURL_CONNECT_TIMEOUT:-30}"
	local curl_speed_limit="${C00_CURL_SPEED_LIMIT:-512}"
	local curl_speed_time="${C00_CURL_SPEED_TIME:-60}"
	local args=(-L --fail -C - --retry "$curl_retry" --retry-delay "$curl_retry_delay" --connect-timeout "$curl_connect_timeout" --speed-limit "$curl_speed_limit" --speed-time "$curl_speed_time")
	if [[ -n "${C00_CURL_EXTRA_ARGS:-}" ]]; then
		# shellcheck disable=SC2206
		local extra_args=($C00_CURL_EXTRA_ARGS)
		args+=("${extra_args[@]}")
	fi
	curl "${args[@]}" -o "$output" "$url"
}

while [[ "$#" -gt 0 ]]; do
	case "$1" in
		--android-sdk)
			ANDROID_SDK="$2"
			shift 2
			;;
		--sdkmanager)
			SDKMANAGER="$2"
			shift 2
			;;
		--cmdline-tools-zip)
			CMDLINE_TOOLS_ZIP="$2"
			INSTALL_CMDLINE_TOOLS=1
			shift 2
			;;
		--download-cmdline-tools)
			INSTALL_CMDLINE_TOOLS=1
			shift
			;;
		--cmdline-tools-url)
			CMDLINE_TOOLS_URL="$2"
			shift 2
			;;
		--yes)
			YES=1
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
		--*)
			usage >&2
			exit 2
			;;
		*)
			PACKAGES+=("$1")
			shift
			;;
	esac
done

if [[ "${#PACKAGES[@]}" -eq 0 ]]; then
	PACKAGES=("platform-tools" "platforms;android-34" "build-tools;34.0.0")
fi

default_cmdline_tools_zip="$PROJECT_ROOT/.godot/cache/c00/downloads/commandlinetools-mac-13114758_latest.zip"
if [[ -z "$CMDLINE_TOOLS_ZIP" && -f "$default_cmdline_tools_zip" ]]; then
	CMDLINE_TOOLS_ZIP="$default_cmdline_tools_zip"
	INSTALL_CMDLINE_TOOLS=1
fi

resolve_java_home() {
	if [[ -n "${GODOT_JAVA_SDK_PATH:-}" && -x "$GODOT_JAVA_SDK_PATH/bin/java" ]]; then
		printf "%s" "$GODOT_JAVA_SDK_PATH"
		return 0
	fi
	if [[ -n "${JAVA_HOME:-}" && -x "$JAVA_HOME/bin/java" ]]; then
		printf "%s" "$JAVA_HOME"
		return 0
	fi
	local bundled="$PROJECT_ROOT/.godot/cache/c00/jdk/Contents/Home"
	if [[ -x "$bundled/bin/java" ]]; then
		printf "%s" "$bundled"
		return 0
	fi
	return 1
}

resolve_sdkmanager() {
	if [[ -n "$SDKMANAGER" ]]; then
		printf "%s" "$SDKMANAGER"
		return 0
	fi
	local candidates=(
		"$ANDROID_SDK/cmdline-tools/latest/bin/sdkmanager"
		"$ANDROID_SDK/cmdline-tools/bin/sdkmanager"
		"$ANDROID_SDK/tools/bin/sdkmanager"
	)
	for candidate in "${candidates[@]}"; do
		if [[ -x "$candidate" ]]; then
			printf "%s" "$candidate"
			return 0
		fi
	done
	if command -v sdkmanager >/dev/null 2>&1; then
		command -v sdkmanager
		return 0
	fi
	return 1
}

install_cmdline_tools() {
	local target="$ANDROID_SDK/cmdline-tools/latest"
	if [[ -x "$target/bin/sdkmanager" ]]; then
		echo "OK   Android command line tools: $target"
		return 0
	fi
	if [[ -z "$CMDLINE_TOOLS_ZIP" ]]; then
		CMDLINE_TOOLS_ZIP="$default_cmdline_tools_zip"
	fi
	if [[ ! -f "$CMDLINE_TOOLS_ZIP" ]]; then
		if [[ "$INSTALL_CMDLINE_TOOLS" != "1" ]]; then
			return 1
		fi
		if [[ "$DRY_RUN" == "1" ]]; then
			echo "DRY RUN: would download Android command line tools -> $CMDLINE_TOOLS_ZIP"
			return 0
		fi
		if ! command -v curl >/dev/null 2>&1; then
			echo "ERROR: curl is required for --download-cmdline-tools." >&2
			exit 2
		fi
		mkdir -p "$(dirname "$CMDLINE_TOOLS_ZIP")"
		echo "Downloading Android command line tools -> $CMDLINE_TOOLS_ZIP"
		download_with_resume "$CMDLINE_TOOLS_ZIP" "$CMDLINE_TOOLS_URL"
	fi

	if ! command -v unzip >/dev/null 2>&1; then
		echo "ERROR: unzip is required to install Android command line tools." >&2
		exit 2
	fi

	if [[ "$INSTALL_CMDLINE_TOOLS" == "1" ]] && ! unzip -t "$CMDLINE_TOOLS_ZIP" >/dev/null 2>&1; then
		if [[ "$DRY_RUN" == "1" ]]; then
			echo "DRY RUN: would resume incomplete Android command line tools download -> $CMDLINE_TOOLS_ZIP"
			return 0
		fi
		if ! command -v curl >/dev/null 2>&1; then
			echo "ERROR: curl is required to resume incomplete Android command line tools download." >&2
			exit 2
		fi
		echo "Resuming incomplete Android command line tools download -> $CMDLINE_TOOLS_ZIP"
		download_with_resume "$CMDLINE_TOOLS_ZIP" "$CMDLINE_TOOLS_URL"
	fi

	if [[ "$DRY_RUN" == "1" ]]; then
		echo "DRY RUN: would install Android command line tools into $target"
		return 0
	fi

	local tmp_dir
	tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/godotar-android-cmdline-tools.XXXXXX")"
	cleanup_cmdline_tools() {
		rm -rf "$tmp_dir"
	}
	trap cleanup_cmdline_tools RETURN

	echo "Installing Android command line tools -> $target"
	unzip -q "$CMDLINE_TOOLS_ZIP" -d "$tmp_dir"
	local source_dir="$tmp_dir/cmdline-tools"
	if [[ ! -d "$source_dir" ]]; then
		source_dir="$(find "$tmp_dir" -maxdepth 2 -type d -name cmdline-tools -print -quit)"
	fi
	if [[ -z "$source_dir" || ! -f "$source_dir/bin/sdkmanager" ]]; then
		echo "ERROR: command line tools archive does not contain cmdline-tools/bin/sdkmanager." >&2
		exit 1
	fi
	mkdir -p "$ANDROID_SDK/cmdline-tools"
	rm -rf "$target"
	mkdir -p "$target"
	cp -R "$source_dir/." "$target/"
	chmod +x "$target/bin/sdkmanager"
	trap - RETURN
	rm -rf "$tmp_dir"
}

if [[ "$INSTALL_CMDLINE_TOOLS" == "1" ]]; then
	install_cmdline_tools
fi

if java_home="$(resolve_java_home)"; then
	export JAVA_HOME="$java_home"
	export PATH="$java_home/bin:$PATH"
	echo "Using Java SDK: $java_home"
fi

SDKMANAGER="$(resolve_sdkmanager || true)"
if [[ -z "$SDKMANAGER" || ! -x "$SDKMANAGER" ]]; then
	if [[ "$DRY_RUN" == "1" ]]; then
		SDKMANAGER="${SDKMANAGER:-$ANDROID_SDK/cmdline-tools/latest/bin/sdkmanager}"
		echo "DRY RUN: sdkmanager not found; expected path: $SDKMANAGER"
		echo "DRY RUN: $SDKMANAGER --sdk_root=$ANDROID_SDK ${PACKAGES[*]}"
		exit 0
	fi
	echo "ERROR: sdkmanager not found." >&2
	echo "Install Android command line tools, pass --sdkmanager /path/to/sdkmanager, or rerun with --download-cmdline-tools." >&2
	exit 2
fi

mkdir -p "$ANDROID_SDK"

echo "Android SDK root: $ANDROID_SDK"
echo "sdkmanager: $SDKMANAGER"
printf "Packages:"
printf " %s" "${PACKAGES[@]}"
printf "\n"

if [[ "$DRY_RUN" == "1" ]]; then
	echo "DRY RUN: $SDKMANAGER --sdk_root=$ANDROID_SDK ${PACKAGES[*]}"
	exit 0
fi

if [[ "$YES" == "1" ]]; then
	yes | "$SDKMANAGER" --sdk_root="$ANDROID_SDK" --licenses >/dev/null || true
	yes | "$SDKMANAGER" --sdk_root="$ANDROID_SDK" "${PACKAGES[@]}"
else
	"$SDKMANAGER" --sdk_root="$ANDROID_SDK" "${PACKAGES[@]}"
fi

echo "Android SDK packages installed."
