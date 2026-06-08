#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TPZ="${TPZ:-}"
VERSION="${GODOT_EXPORT_TEMPLATES_VERSION:-4.4.1.stable}"
DEST="${GODOT_EXPORT_TEMPLATES_DIR:-$HOME/Library/Application Support/Godot/export_templates/$VERSION}"

usage() {
	cat <<EOF
Usage:
  tools/c00/install_godot_export_templates.sh --tpz <Godot_v4.4.1-stable_export_templates.tpz> [--version 4.4.1.stable]

Installs official Godot export templates into the directory used by Godot:
  $DEST

The standard 4.4.1 package is available from the Godot 4.4.1 archive page:
  https://godotengine.org/download/archive/4.4.1-stable/
EOF
}

while [[ "$#" -gt 0 ]]; do
	case "$1" in
		--tpz)
			TPZ="$2"
			shift 2
			;;
		--version)
			VERSION="$2"
			DEST="${GODOT_EXPORT_TEMPLATES_DIR:-$HOME/Library/Application Support/Godot/export_templates/$VERSION}"
			shift 2
			;;
		--dir)
			DEST="$2"
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

if [[ -z "$TPZ" ]]; then
	default_tpz="$PROJECT_ROOT/.godot/cache/c00/downloads/Godot_v4.4.1-stable_export_templates.tpz"
	if [[ -f "$default_tpz" ]]; then
		TPZ="$default_tpz"
	else
		usage >&2
		exit 2
	fi
fi

if [[ ! -f "$TPZ" ]]; then
	echo "ERROR: export templates package not found: $TPZ" >&2
	exit 2
fi

for tool in unzip; do
	if ! command -v "$tool" >/dev/null 2>&1; then
		echo "ERROR: missing required tool: $tool" >&2
		exit 2
	fi
done

tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/godot-export-templates.XXXXXX")"
cleanup() {
	rm -rf "$tmp_dir"
}
trap cleanup EXIT

echo "Checking archive: $TPZ"
unzip -t "$TPZ" >/dev/null

echo "Extracting templates -> $DEST"
mkdir -p "$DEST"
unzip -q "$TPZ" -d "$tmp_dir"

if [[ -d "$tmp_dir/templates" ]]; then
	cp -R "$tmp_dir/templates/." "$DEST/"
else
	cp -R "$tmp_dir/." "$DEST/"
fi

missing=0
for required in ios.zip android_source.zip; do
	if [[ -f "$DEST/$required" ]]; then
		echo "OK   $DEST/$required"
	else
		echo "MISS $DEST/$required"
		missing=1
	fi
done

if [[ "$missing" != "0" ]]; then
	echo "ERROR: installed archive is missing required C00 templates." >&2
	exit 1
fi

echo "Godot export templates installed for $VERSION"
