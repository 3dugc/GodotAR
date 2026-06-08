#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEFAULT_DIR="$PROJECT_ROOT/.godot/cache/c00/godot-source"
DEST="${GODOT_SOURCE_DIR:-${GODOT_SRC_DIR:-$DEFAULT_DIR}}"
REPO="${GODOT_REPO:-https://github.com/godotengine/godot.git}"
TAG="${GODOT_TAG:-}"
BRANCH="${GODOT_BRANCH:-}"
COMMIT="${GODOT_COMMIT:-}"
FORCE=0
PRINT_ENV=1

usage() {
	cat <<EOF
Usage:
  tools/c00/prepare_godot_source.sh [options]

Options:
  --dir <path>       Target Godot source directory. Default: .godot/cache/c00/godot-source
  --tag <tag>        Godot source tag, for example 4.4.1-stable.
  --branch <branch>  Godot source branch.
  --commit <sha>     Godot source commit. Requires a full clone.
  --repo <url>       Godot repository URL. Default: https://github.com/godotengine/godot.git
  --force            Replace an existing invalid target directory.
  --no-env           Do not print export commands.

If --tag/--branch/--commit are omitted, the script tries to infer a stable tag
from GODOT_BIN or the godot command, e.g. 4.4.1.stable.official -> 4.4.1-stable.

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
	local godot_bin version stable
	if ! godot_bin="$(find_godot_binary)"; then
		return 1
	fi
	version="$("$godot_bin" --version 2>/dev/null | awk '{print $1}')"
	version="${version%%.official*}"
	stable="${version/.stable/-stable}"
	if [[ "$stable" == "$version" || -z "$stable" ]]; then
		return 1
	fi
	printf "%s" "$stable"
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
		cat >&2 <<EOF
Could not infer a Godot source tag.
Pass --tag <tag>, for example:
  tools/c00/prepare_godot_source.sh --tag 4.4.1-stable
EOF
		exit 2
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

echo "Godot source is ready: $DEST"
print_next_steps
