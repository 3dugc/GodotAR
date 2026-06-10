#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
. "$PROJECT_ROOT/tools/c00/godot_version_defaults.sh"
VERSION="$(godot_normalize_template_version "${GODOT_EXPORT_TEMPLATES_VERSION:-$C00_GODOT_DEFAULT_EXPORT_TEMPLATES_VERSION}")"
SOURCE_ZIP="${ANDROID_SOURCE_ZIP:-}"
BUILD_DIR="${ANDROID_BUILD_DIR:-$PROJECT_ROOT/android/build}"
FORCE=0

usage() {
	cat <<EOF
Usage:
  tools/c00/install_android_build_template.sh [--source <android_source.zip>] [--latest|--latest-stable|--version 4.7.rc1] [--force]

Installs Godot's Android Gradle build template into:
  android/build

This mirrors Godot's Project > Install Android Build Template flow:
  - unzip android_source.zip into res://android/build
  - write res://android/.build_version
  - write res://android/build/.gdignore
EOF
}

set_version() {
	VERSION="$(godot_normalize_template_version "$1")"
}

while [[ "$#" -gt 0 ]]; do
	case "$1" in
		--source)
			SOURCE_ZIP="$2"
			shift 2
			;;
		--version)
			set_version "$2"
			shift 2
			;;
		--latest)
			set_version "$C00_GODOT_LATEST_EXPORT_TEMPLATES_VERSION"
			shift
			;;
		--latest-stable)
			set_version "$C00_GODOT_STABLE_EXPORT_TEMPLATES_VERSION"
			shift
			;;
		--build-dir)
			BUILD_DIR="$2"
			shift 2
			;;
		--force)
			FORCE=1
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

resolve_template_dir() {
	printf "%s" "${GODOT_EXPORT_TEMPLATES_DIR:-$HOME/Library/Application Support/Godot/export_templates/$VERSION}"
}

if [[ -z "$SOURCE_ZIP" ]]; then
	SOURCE_ZIP="$(resolve_template_dir)/android_source.zip"
fi

case "$SOURCE_ZIP" in
	/*) ;;
	*) SOURCE_ZIP="$PROJECT_ROOT/$SOURCE_ZIP" ;;
esac
case "$BUILD_DIR" in
	/*) ;;
	*) BUILD_DIR="$PROJECT_ROOT/$BUILD_DIR" ;;
esac

if [[ ! -f "$SOURCE_ZIP" ]]; then
	echo "ERROR: android_source.zip not found: $SOURCE_ZIP" >&2
	echo "Install Godot export templates first, or pass --source /path/to/android_source.zip." >&2
	exit 2
fi

if ! command -v unzip >/dev/null 2>&1; then
	echo "ERROR: missing required tool: unzip" >&2
	exit 2
fi

ANDROID_DIR="$(dirname "$BUILD_DIR")"
BUILD_VERSION_FILE="$ANDROID_DIR/.build_version"

if [[ -f "$BUILD_DIR/build.gradle" && "$FORCE" != "1" ]]; then
	if [[ -f "$BUILD_VERSION_FILE" ]] && grep -Fxq "$VERSION" "$BUILD_VERSION_FILE"; then
		echo "Android build template already installed for $VERSION: $BUILD_DIR"
		exit 0
	fi
	echo "ERROR: Android build template already exists but does not match $VERSION." >&2
	echo "Use --force after checking local android/build changes." >&2
	exit 1
fi

echo "Checking Android source template: $SOURCE_ZIP"
unzip -t "$SOURCE_ZIP" >/dev/null

mkdir -p "$BUILD_DIR"
printf "%s\n" "$VERSION" > "$BUILD_VERSION_FILE"
printf "\n" > "$BUILD_DIR/.gdignore"

echo "Installing Android build template -> $BUILD_DIR"
unzip -oq "$SOURCE_ZIP" -d "$BUILD_DIR"

if [[ ! -f "$BUILD_DIR/build.gradle" ]]; then
	echo "ERROR: installed template is missing build.gradle: $BUILD_DIR/build.gradle" >&2
	exit 1
fi

echo "Android build template installed for $VERSION"
