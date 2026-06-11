#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
. "$PROJECT_ROOT/tools/c00/godot_version_defaults.sh"

TEMPLATE_VERSION="$(godot_normalize_template_version "${GODOT_EXPORT_TEMPLATES_VERSION:-$C00_GODOT_DEFAULT_EXPORT_TEMPLATES_VERSION}")"
GRADLE_HOME="${GRADLE_USER_HOME:-$PROJECT_ROOT/.godot/cache/c00/gradle}"
HOST_GRADLE_HOME="${C00_HOST_GRADLE_USER_HOME:-$HOME/.gradle}"
DRY_RUN="${DRY_RUN:-0}"

usage() {
	cat <<EOF
Usage:
  tools/c00/prepare_gradle_user_home.sh [options]

Options:
  --gradle-home <dir>       Writable Gradle user home. Default: GRADLE_USER_HOME or .godot/cache/c00/gradle.
  --host-gradle-home <dir>  Read-only source cache. Default: C00_HOST_GRADLE_USER_HOME or ~/.gradle.
  --template-version <ver>  Godot export template version. Default: GODOT_EXPORT_TEMPLATES_VERSION.
  --dry-run                 Print actions without copying.

Copies the Gradle wrapper distribution and modules-2 cache from an existing host
cache into a project-local Gradle home so C00 Android/Rokid exports do not need
write access to ~/.gradle.
EOF
}

while [[ "$#" -gt 0 ]]; do
	case "$1" in
		--gradle-home)
			GRADLE_HOME="$2"
			shift 2
			;;
		--host-gradle-home)
			HOST_GRADLE_HOME="$2"
			shift 2
			;;
		--template-version)
			TEMPLATE_VERSION="$(godot_normalize_template_version "$2")"
			shift 2
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

case "$GRADLE_HOME" in
	/*) ;;
	*) GRADLE_HOME="$PROJECT_ROOT/$GRADLE_HOME" ;;
esac
case "$HOST_GRADLE_HOME" in
	/*) ;;
	*) HOST_GRADLE_HOME="$PROJECT_ROOT/$HOST_GRADLE_HOME" ;;
esac
GRADLE_DISTRIBUTION="$(godot_android_gradle_distribution_from_template_version "$TEMPLATE_VERSION")"

has_gradle_distribution() {
	local root="$1"
	find "$root/wrapper/dists/$GRADLE_DISTRIBUTION" -path "*/bin/gradle" -type f -perm -111 2>/dev/null | head -n 1 | grep -q .
}

copy_dir_if_missing() {
	local source="$1"
	local dest="$2"
	local label="$3"

	if [[ -e "$dest" ]]; then
		echo "OK   $label: $dest"
		return
	fi
	if [[ ! -e "$source" ]]; then
		echo "MISS $label source cache: $source" >&2
		return 1
	fi
	if [[ "$DRY_RUN" == "1" ]]; then
		echo "DRY RUN: copy $source -> $dest"
		return
	fi

	mkdir -p "$(dirname "$dest")"
	echo "Copying $label cache into project Gradle home..."
	cp -R "$source" "$dest"
}

if [[ "$GRADLE_HOME" == "$HOST_GRADLE_HOME" ]]; then
	echo "OK   GRADLE_USER_HOME already points at host cache: $GRADLE_HOME"
	exit 0
fi

if [[ "$DRY_RUN" != "1" ]]; then
	mkdir -p "$GRADLE_HOME"
fi

status=0
if has_gradle_distribution "$GRADLE_HOME"; then
	echo "OK   Gradle wrapper cache: $GRADLE_HOME/wrapper/dists/$GRADLE_DISTRIBUTION"
else
	copy_dir_if_missing \
		"$HOST_GRADLE_HOME/wrapper/dists/$GRADLE_DISTRIBUTION" \
		"$GRADLE_HOME/wrapper/dists/$GRADLE_DISTRIBUTION" \
		"Gradle wrapper" || status=1
fi

copy_dir_if_missing \
	"$HOST_GRADLE_HOME/caches/modules-2" \
	"$GRADLE_HOME/caches/modules-2" \
	"Gradle modules-2" || status=1

if [[ "$status" -eq 0 ]]; then
	echo "OK   GRADLE_USER_HOME=$GRADLE_HOME"
else
	echo "MISS project-local Gradle cache is incomplete; prewarm ~/.gradle or set GRADLE_USER_HOME to a writable, populated Gradle cache." >&2
fi

exit "$status"
