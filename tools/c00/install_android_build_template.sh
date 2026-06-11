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

apply_c00_maven_mirrors() {
	local file
	for file in "$BUILD_DIR/settings.gradle" "$BUILD_DIR/build.gradle"; do
		if [[ ! -f "$file" ]]; then
			continue
		fi
		if grep -q "maven.aliyun.com/repository/google" "$file"; then
			continue
		fi
		local tmp
		tmp="$(mktemp "${TMPDIR:-/tmp}/godotar-gradle-mirrors.XXXXXX")"
		awk '
			/repositories[[:space:]]*\{/ && done == 0 {
				print
				print "        // C00 device machines in China often cannot complete TLS handshakes"
				print "        // with Google'\''s Maven endpoint. Prefer mirrors, keep official repos below."
				print "        maven { url \"https://maven.aliyun.com/repository/google\" }"
				print "        maven { url \"https://maven.aliyun.com/repository/public\" }"
				print "        maven { url \"https://maven.aliyun.com/repository/gradle-plugin\" }"
				done = 1
				next
			}
			{ print }
		' "$file" > "$tmp"
		mv "$tmp" "$file"
		echo "Applied C00 Maven mirrors: $file"
	done
}

clean_c00_android_launcher_icon_resources() {
	local res_dir="$BUILD_DIR/res"
	if [[ ! -d "$res_dir" ]]; then
		return 0
	fi

	local removed=0
	local file
	while IFS= read -r -d '' file; do
		rm -f "$file"
		echo "Removed duplicate-prone Android launcher WebP: ${file#$PROJECT_ROOT/}"
		removed=1
	done < <(find "$res_dir" -type f \( -path "*/mipmap*/icon.webp" -o -path "*/mipmap*/icon_foreground.webp" \) -print0)

	if [[ "$removed" == "1" ]]; then
		echo "Android launcher WebP cleanup complete; Godot will generate PNG launcher icons from project settings during export."
	fi
}

apply_c00_launcher_icon_gradle_cleanup() {
	local file="$BUILD_DIR/build.gradle"
	if [[ ! -f "$file" ]]; then
		return 0
	fi
	if grep -q "c00CleanDuplicateLauncherWebp" "$file"; then
		return 0
	fi

	cat >> "$file" <<'EOF'

// C00: Godot exports this project's SVG launcher icon as PNG resources while
// some Android templates still carry launcher WebP defaults with the same
// Android resource names. Remove the WebP defaults immediately before resource
// merging so Gradle does not fail with duplicate mipmap/icon resources.
tasks.register("c00CleanDuplicateLauncherWebp") {
    doLast {
        fileTree("${projectDir}/res") {
            include "**/mipmap*/icon.webp"
            include "**/mipmap*/icon_foreground.webp"
        }.files.each { launcherWebp ->
            if (launcherWebp.exists()) {
                println "C00 removing duplicate launcher WebP: ${launcherWebp}"
                launcherWebp.delete()
            }
        }
    }
}

tasks.matching { task ->
    task.name.startsWith("merge") && task.name.endsWith("Resources")
}.configureEach {
    dependsOn(tasks.named("c00CleanDuplicateLauncherWebp"))
}
EOF
	echo "Applied C00 launcher icon Gradle cleanup: $file"
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
		apply_c00_maven_mirrors
		clean_c00_android_launcher_icon_resources
		apply_c00_launcher_icon_gradle_cleanup
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
apply_c00_maven_mirrors
clean_c00_android_launcher_icon_resources
apply_c00_launcher_icon_gradle_cleanup

if [[ ! -f "$BUILD_DIR/build.gradle" ]]; then
	echo "ERROR: installed template is missing build.gradle: $BUILD_DIR/build.gradle" >&2
	exit 1
fi

echo "Android build template installed for $VERSION"
