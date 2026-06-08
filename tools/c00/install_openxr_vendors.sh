#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET_DIR="$PROJECT_ROOT/addons/godotopenxrvendors"
SOURCE_ZIP=""
TAG="${OPENXR_VENDORS_TAG:-}"
URL="${OPENXR_VENDORS_URL:-}"
FORCE=0
KEEP_ZIP=0
TMP_ROOT="${TMPDIR:-/tmp}"

usage() {
	cat <<EOF
Usage:
  tools/c00/install_openxr_vendors.sh [options]

Options:
  --zip <file>       Install from a previously downloaded godotopenxrvendorsaddon.zip.
  --tag <tag>        Download a specific GitHub release tag, for example 4.2.0-stable.
  --url <url>        Download a specific godotopenxrvendorsaddon.zip URL.
  --force            Replace an existing addons/godotopenxrvendors directory.
  --keep-zip         Keep the downloaded zip under .godot/cache/c00.

Default:
  Download the latest GitHub release asset named godotopenxrvendorsaddon.zip.

The official addon zip contains an Asset Library root folder. This script
locates the inner godotopenxrvendors directory and installs exactly that folder
to res://addons/godotopenxrvendors.
EOF
}

while [[ "$#" -gt 0 ]]; do
	case "$1" in
		--zip)
			SOURCE_ZIP="$2"
			shift 2
			;;
		--tag)
			TAG="$2"
			shift 2
			;;
		--url)
			URL="$2"
			shift 2
			;;
		--force)
			FORCE=1
			shift
			;;
		--keep-zip)
			KEEP_ZIP=1
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

download_latest_url() {
	require_command curl
	require_command node
	curl -fsSL "https://api.github.com/repos/GodotVR/godot_openxr_vendors/releases/latest" | node -e '
const fs = require("fs");
const release = JSON.parse(fs.readFileSync(0, "utf8"));
const asset = (release.assets || []).find((item) => item.name === "godotopenxrvendorsaddon.zip");
if (!asset || !asset.browser_download_url) {
	console.error("Latest OpenXR Vendors release does not expose godotopenxrvendorsaddon.zip.");
	process.exit(1);
}
process.stdout.write(asset.browser_download_url);
'
}

download_zip() {
	local output="$1"
	local download_url="$URL"
	if [[ -z "$download_url" && -n "$TAG" ]]; then
		download_url="https://github.com/GodotVR/godot_openxr_vendors/releases/download/${TAG}/godotopenxrvendorsaddon.zip"
	fi
	if [[ -z "$download_url" ]]; then
		download_url="$(download_latest_url)"
	fi
	require_command curl
	echo "Downloading OpenXR Vendors addon: $download_url"
	curl -fL "$download_url" -o "$output"
}

if [[ -d "$TARGET_DIR" && "$FORCE" != "1" ]]; then
	echo "OpenXR Vendors plugin already exists: $TARGET_DIR" >&2
	echo "Pass --force to replace it." >&2
	exit 1
fi

require_command unzip

WORK_DIR="$(mktemp -d "$TMP_ROOT/godot-openxr-vendors.XXXXXX")"
cleanup() {
	rm -rf "$WORK_DIR"
}
trap cleanup EXIT

ZIP_PATH="$SOURCE_ZIP"
if [[ -z "$ZIP_PATH" ]]; then
	ZIP_PATH="$WORK_DIR/godotopenxrvendorsaddon.zip"
	download_zip "$ZIP_PATH"
else
	if [[ ! -f "$ZIP_PATH" ]]; then
		echo "Zip not found: $ZIP_PATH" >&2
		exit 2
	fi
fi

EXTRACT_DIR="$WORK_DIR/extract"
mkdir -p "$EXTRACT_DIR"
unzip -q "$ZIP_PATH" -d "$EXTRACT_DIR"

PLUGIN_DIR="$(find "$EXTRACT_DIR" -type d -name godotopenxrvendors | head -n 1 || true)"
if [[ -z "$PLUGIN_DIR" ]]; then
	echo "Could not find a godotopenxrvendors directory inside $ZIP_PATH." >&2
	exit 1
fi

mkdir -p "$PROJECT_ROOT/addons"
if [[ -d "$TARGET_DIR" ]]; then
	rm -rf "$TARGET_DIR"
fi
cp -R "$PLUGIN_DIR" "$TARGET_DIR"

if [[ "$KEEP_ZIP" == "1" && "$SOURCE_ZIP" == "" ]]; then
	CACHE_DIR="$PROJECT_ROOT/.godot/cache/c00"
	mkdir -p "$CACHE_DIR"
	cp "$ZIP_PATH" "$CACHE_DIR/godotopenxrvendorsaddon.zip"
	echo "Kept downloaded zip: $CACHE_DIR/godotopenxrvendorsaddon.zip"
fi

echo "Installed OpenXR Vendors plugin: $TARGET_DIR"
echo "Next:"
echo "  tools/c00/preflight.sh rokid"
echo "  Open Godot Export settings, enable the target OpenXR vendor, then save export_presets.cfg."
