#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ANDROID_SDK="${GODOT_ANDROID_SDK_PATH:-${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$PROJECT_ROOT/.godot/cache/c00/android-sdk}}}"
SDKMANAGER="${SDKMANAGER:-}"
PACKAGES=()
YES=0
DRY_RUN=0

usage() {
	cat <<EOF
Usage:
  tools/c00/install_android_sdk_packages.sh [options] [sdkmanager package...]

Options:
  --android-sdk <dir>  Android SDK root. Default: GODOT_ANDROID_SDK_PATH, ANDROID_SDK_ROOT, ANDROID_HOME, or .godot/cache/c00/android-sdk.
  --sdkmanager <path>  sdkmanager executable.
  --yes                Accept Android SDK licenses from stdin.
  --dry-run            Print command without installing.

Default packages match Godot 4.4 Android export expectations:
  platform-tools platforms;android-34 build-tools;34.0.0
EOF
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

SDKMANAGER="$(resolve_sdkmanager || true)"
if [[ -z "$SDKMANAGER" || ! -x "$SDKMANAGER" ]]; then
	if [[ "$DRY_RUN" == "1" ]]; then
		SDKMANAGER="${SDKMANAGER:-$ANDROID_SDK/cmdline-tools/latest/bin/sdkmanager}"
		echo "DRY RUN: sdkmanager not found; expected path: $SDKMANAGER"
		echo "DRY RUN: $SDKMANAGER --sdk_root=$ANDROID_SDK ${PACKAGES[*]}"
		exit 0
	fi
	echo "ERROR: sdkmanager not found." >&2
	echo "Install Android command line tools, or pass --sdkmanager /path/to/sdkmanager." >&2
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
