#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
. "$PROJECT_ROOT/tools/c00/godot_version_defaults.sh"
DEFAULT_DIR="$PROJECT_ROOT/.godot/cache/c00/godot-source"
DEST="${GODOT_SOURCE_DIR:-${GODOT_SRC_DIR:-$DEFAULT_DIR}}"
REPO="${GODOT_REPO:-https://github.com/godotengine/godot.git}"
TAG="${GODOT_TAG:-}"
BRANCH="${GODOT_BRANCH:-}"
COMMIT="${GODOT_COMMIT:-}"
FORCE=0
PRINT_ENV=1
ALLOW_STABLE_FALLBACK="${GODOT_ALLOW_STABLE_SOURCE_FALLBACK:-0}"

usage() {
	cat <<EOF
Usage:
  tools/c00/prepare_godot_source.sh [options]

Options:
  --dir <path>       Target Godot source directory. Default: .godot/cache/c00/godot-source
  --tag <tag>        Godot source tag, for example 4.7-rc1.
  --latest           Use newest C00 Godot line: $C00_GODOT_LATEST_TAG.
  --latest-stable    Use newest stable C00 Godot line: $C00_GODOT_STABLE_TAG.
  --branch <branch>  Godot source branch.
  --commit <sha>     Godot source commit. Requires a full clone.
  --repo <url>       Godot repository URL. Default: https://github.com/godotengine/godot.git
  --force            Replace an existing invalid target directory.
  --allow-stable-fallback
                      If the requested newest tag is not on GitHub yet, use $C00_GODOT_STABLE_TAG.
  --no-env           Do not print export commands.

If --tag/--branch/--commit are omitted, the script tries to infer a tag
from GODOT_BIN or the godot command, e.g. 4.7.rc1.official -> 4.7-rc1.
If no Godot binary can be queried, it falls back to $C00_GODOT_DEFAULT_TAG.

The resulting source tree must match the Godot iOS export template used on the
device machine. C00 uses it only to compile ios/plugins/godot_arkit.
EOF
}

while [[ "$#" -gt 0 ]]; do
	case "$1" in
		--dir)
			DEST="$2"
			shift 2
			;;
		--tag)
			TAG="$2"
			shift 2
			;;
		--latest)
			TAG="$C00_GODOT_LATEST_TAG"
			shift
			;;
		--latest-stable)
			TAG="$C00_GODOT_STABLE_TAG"
			shift
			;;
		--branch)
			BRANCH="$2"
			shift 2
			;;
		--commit)
			COMMIT="$2"
			shift 2
			;;
		--repo)
			REPO="$2"
			shift 2
			;;
		--force)
			FORCE=1
			shift
			;;
		--allow-stable-fallback)
			ALLOW_STABLE_FALLBACK=1
			shift
			;;
		--no-env)
			PRINT_ENV=0
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

require_command() {
	local name="$1"
	if ! command -v "$name" >/dev/null 2>&1; then
		echo "$name not found." >&2
		exit 2
	fi
}

ensure_requested_tag_available_or_fallback() {
	if [[ -z "$TAG" ]]; then
		return 0
	fi
	require_command git
	if git ls-remote --exit-code --tags "$REPO" "refs/tags/$TAG" >/dev/null 2>&1; then
		return 0
	fi
	if [[ "$ALLOW_STABLE_FALLBACK" == "1" && "$TAG" != "$C00_GODOT_STABLE_TAG" ]]; then
		echo "Godot source tag is not available on GitHub yet: $TAG" >&2
		echo "Falling back to source-compatible stable tag: $C00_GODOT_STABLE_TAG" >&2
		TAG="$C00_GODOT_STABLE_TAG"
		return 0
	fi
	cat >&2 <<EOF
Godot source tag is not available on GitHub yet: $TAG

The official editor/export-template binaries may be ahead of the public source
tag. Re-run with --latest-stable for a fully source-compatible device build, or
pass --allow-stable-fallback to use $C00_GODOT_STABLE_TAG when the newest tag is
missing.
EOF
	exit 1
}

validate_source_tree() {
	local dir="$1"
	for required in \
		"$dir/core/version.h" \
		"$dir/core/object/class_db.h" \
		"$dir/core/config/engine.h" \
		"$dir/platform/ios"; do
		if [[ ! -e "$required" ]]; then
			return 1
		fi
	done
	return 0
}

read_version_value() {
	local file="$1"
	local key="$2"
	awk -F= -v key="$key" '
		$1 ~ "^[[:space:]]*" key "[[:space:]]*$" {
			value = $2
			sub(/^[[:space:]]*/, "", value)
			sub(/[[:space:]]*$/, "", value)
			gsub(/^"/, "", value)
			gsub(/"$/, "", value)
			print value
			exit
		}
	' "$file"
}

source_tree_tag() {
	local dir="$1"
	local version_py="$dir/version.py"
	if [[ ! -f "$version_py" ]]; then
		return 1
	fi

	local major minor patch status number template_version
	major="$(read_version_value "$version_py" major)"
	minor="$(read_version_value "$version_py" minor)"
	patch="$(read_version_value "$version_py" patch)"
	status="$(read_version_value "$version_py" status)"
	if [[ -z "$major" || -z "$minor" || -z "$status" ]]; then
		return 1
	fi

	number="$major.$minor"
	if [[ -n "$patch" && "$patch" != "0" ]]; then
		number="$number.$patch"
	fi
	template_version="$number.$status"
	godot_tag_from_template_version "$template_version"
}

ensure_generated_version_header() {
	local dir="$1"
	local version_py="$dir/version.py"
	local header="$dir/core/version_generated.gen.h"

	if [[ ! -f "$version_py" ]]; then
		echo "ERROR: Missing Godot version metadata: $version_py" >&2
		return 1
	fi

	if [[ -f "$header" ]]; then
		return 0
	fi

	local short_name name major minor patch status module_config website docs build docs_url
	short_name="$(read_version_value "$version_py" short_name)"
	name="$(read_version_value "$version_py" name)"
	major="$(read_version_value "$version_py" major)"
	minor="$(read_version_value "$version_py" minor)"
	patch="$(read_version_value "$version_py" patch)"
	status="$(read_version_value "$version_py" status)"
	module_config="$(read_version_value "$version_py" module_config)"
	website="$(read_version_value "$version_py" website)"
	docs="$(read_version_value "$version_py" docs)"
	build="${BUILD_NAME:-custom_build}"
	docs_url="https://docs.godotengine.org/en/${docs}"

	for value in "$short_name" "$name" "$major" "$minor" "$patch" "$status" "$website" "$docs"; do
		if [[ -z "$value" ]]; then
			echo "ERROR: Could not parse Godot version metadata from $version_py" >&2
			return 1
		fi
	done

	mkdir -p "$(dirname "$header")"
	cat > "$header" <<EOF
/* Generated by tools/c00/prepare_godot_source.sh for external iOS plugin builds. */
#ifndef VERSION_GENERATED_GEN_H
#define VERSION_GENERATED_GEN_H

#define VERSION_SHORT_NAME "$short_name"
#define VERSION_NAME "$name"
#define VERSION_MAJOR $major
#define VERSION_MINOR $minor
#define VERSION_PATCH $patch
#define VERSION_STATUS "$status"
#define VERSION_BUILD "$build"
#define VERSION_MODULE_CONFIG "$module_config"
#define VERSION_WEBSITE "$website"
#define VERSION_DOCS_BRANCH "$docs"
#define VERSION_DOCS_URL "$docs_url"

#endif // VERSION_GENERATED_GEN_H
EOF
}

ensure_disabled_classes_header() {
	local dir="$1"
	local header="$dir/core/disabled_classes.gen.h"

	if [[ -f "$header" ]]; then
		return 0
	fi

	mkdir -p "$(dirname "$header")"
	cat > "$header" <<EOF
/* Generated by tools/c00/prepare_godot_source.sh for external iOS plugin builds. */
#ifndef DISABLED_CLASSES_GEN_H
#define DISABLED_CLASSES_GEN_H

/* Empty by design: C00 plugin builds do not compile a class-stripped Godot runtime. */

#endif // DISABLED_CLASSES_GEN_H
EOF
}

ensure_gdvirtual_header() {
	local dir="$1"
	local header="$dir/core/object/gdvirtual.gen.inc"

	if [[ -f "$header" ]]; then
		return 0
	fi

	if ! command -v python3 >/dev/null 2>&1; then
		echo "ERROR: python3 is required to generate $header" >&2
		return 2
	fi

	(
		cd "$dir/core/object"
		python3 -c 'import make_virtuals; make_virtuals.run(["gdvirtual.gen.inc"], ["make_virtuals.py"], None)'
	)
}

ensure_generated_headers() {
	local dir="$1"
	ensure_generated_version_header "$dir"
	ensure_disabled_classes_header "$dir"
	ensure_gdvirtual_header "$dir"
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
	return 1
}

infer_tag_from_godot() {
	local godot_bin version tag
	if ! godot_bin="$(find_godot_binary)"; then
		return 1
	fi
	version="$("$godot_bin" --version 2>/dev/null | awk '{print $1}')"
	version="${version%%.official*}"
	tag="$(godot_tag_from_template_version "$version")"
	if [[ -z "$tag" ]]; then
		return 1
	fi
	printf "%s" "$tag"
}

print_next_steps() {
	if [[ "$PRINT_ENV" != "1" ]]; then
		return
	fi
	cat <<EOF

Use this source tree for ARKit plugin builds:

export GODOT_SOURCE_DIR="$DEST"
GODOT_SOURCE_DIR="$DEST" ios/plugins/godot_arkit/build_xcframework.sh
EOF
}

DEST="$(mkdir -p "$(dirname "$DEST")" && cd "$(dirname "$DEST")" && printf "%s/%s" "$(pwd)" "$(basename "$DEST")")"

if [[ -d "$DEST" ]]; then
	if validate_source_tree "$DEST"; then
		if [[ -n "$TAG" ]]; then
			existing_tag="$(source_tree_tag "$DEST" || true)"
			if [[ -n "$existing_tag" && "$existing_tag" != "$TAG" ]]; then
				if [[ "$FORCE" == "1" ]]; then
					ensure_requested_tag_available_or_fallback
					if [[ "$existing_tag" == "$TAG" ]]; then
						ensure_generated_headers "$DEST"
						echo "Godot source is ready: $DEST"
						print_next_steps
						exit 0
					fi
					echo "Replacing Godot source $existing_tag with requested tag $TAG: $DEST"
					rm -rf "$DEST"
				else
					echo "Target Godot source tag is $existing_tag, but requested $TAG: $DEST" >&2
					echo "Pass --force to replace it, or set GODOT_SOURCE_DIR to a matching tree." >&2
					exit 1
				fi
			fi
		fi
	fi

	if [[ -d "$DEST" ]] && validate_source_tree "$DEST"; then
		ensure_generated_headers "$DEST"
		echo "Godot source is ready: $DEST"
		print_next_steps
		exit 0
	fi
	if [[ "$FORCE" != "1" ]]; then
		echo "Target exists but is not a valid Godot source tree: $DEST" >&2
		echo "Pass --force to replace it, or set GODOT_SOURCE_DIR to a valid tree." >&2
		exit 1
	fi
	rm -rf "$DEST"
fi

if [[ -z "$TAG" && -z "$BRANCH" && -z "$COMMIT" ]]; then
	if TAG="$(infer_tag_from_godot)"; then
		echo "Inferred Godot source tag from Godot binary: $TAG"
	else
		TAG="$C00_GODOT_DEFAULT_TAG"
		cat <<EOF
Could not infer a Godot source tag from GODOT_BIN/godot.
Using C00 default Godot source tag: $TAG

To pin a different version, pass --tag <tag>, for example:
  tools/c00/prepare_godot_source.sh --tag 4.6.3-stable
EOF
	fi
fi

require_command git

if [[ -n "$TAG" && -n "$BRANCH" ]]; then
	echo "Specify only one of --tag or --branch." >&2
	exit 2
fi

if [[ -n "$COMMIT" && ( -n "$TAG" || -n "$BRANCH" ) ]]; then
	echo "Specify --commit without --tag/--branch." >&2
	exit 2
fi

ensure_requested_tag_available_or_fallback

echo "Cloning Godot source into $DEST"
if [[ -n "$TAG" ]]; then
	git clone --depth 1 --branch "$TAG" "$REPO" "$DEST"
elif [[ -n "$BRANCH" ]]; then
	git clone --depth 1 --branch "$BRANCH" "$REPO" "$DEST"
else
	git clone "$REPO" "$DEST"
	( cd "$DEST" && git checkout "$COMMIT" )
fi

if ! validate_source_tree "$DEST"; then
	echo "Downloaded tree is missing required Godot iOS headers: $DEST" >&2
	exit 1
fi

ensure_generated_headers "$DEST"

echo "Godot source is ready: $DEST"
print_next_steps
