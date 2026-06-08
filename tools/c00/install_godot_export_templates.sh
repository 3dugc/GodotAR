#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TPZ="${TPZ:-}"
VERSION="${GODOT_EXPORT_TEMPLATES_VERSION:-4.4.1.stable}"
DEST="${GODOT_EXPORT_TEMPLATES_DIR:-$HOME/Library/Application Support/Godot/export_templates/$VERSION}"
DOWNLOAD=0
URL="${GODOT_EXPORT_TEMPLATES_URL:-}"

usage() {
	cat <<EOF
Usage:
  tools/c00/install_godot_export_templates.sh --tpz <Godot_v4.4.1-stable_export_templates.tpz> [--version 4.4.1.stable]
  tools/c00/install_godot_export_templates.sh --download [--version 4.4.1.stable]

Installs official Godot export templates into the directory used by Godot:
  $DEST

The standard 4.4.1 package is available from the Godot 4.4.1 archive page:
  https://godotengine.org/download/archive/4.4.1-stable/

Download tuning:
  C00_CURL_RETRY=8 C00_CURL_RETRY_DELAY=15 C00_CURL_SPEED_LIMIT=1024 C00_CURL_SPEED_TIME=30 \\
    tools/c00/install_godot_export_templates.sh --download
EOF
}

version_tag() {
	printf "%s" "${VERSION/.stable/-stable}"
}

default_url() {
	local tag
	tag="$(version_tag)"
	printf "https://github.com/godotengine/godot/releases/download/%s/Godot_v%s_export_templates.tpz" "$tag" "$tag"
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
		--tpz)
			TPZ="$2"
			shift 2
			;;
		--download)
			DOWNLOAD=1
			shift
			;;
		--url)
			URL="$2"
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
	versioned_tpz="$PROJECT_ROOT/.godot/cache/c00/downloads/Godot_v$(version_tag)_export_templates.tpz"
	if [[ -f "$default_tpz" ]]; then
		TPZ="$default_tpz"
	elif [[ -f "$versioned_tpz" ]]; then
		TPZ="$versioned_tpz"
	elif [[ "$DOWNLOAD" == "1" ]]; then
		TPZ="$versioned_tpz"
	else
		usage >&2
		exit 2
	fi
fi

if [[ ! -f "$TPZ" ]]; then
	if [[ "$DOWNLOAD" != "1" ]]; then
		echo "ERROR: export templates package not found: $TPZ" >&2
		exit 2
	fi
	if ! command -v curl >/dev/null 2>&1; then
		echo "ERROR: curl is required for --download." >&2
		exit 2
	fi
	mkdir -p "$(dirname "$TPZ")"
	if [[ -z "$URL" ]]; then
		URL="$(default_url)"
	fi
	echo "Downloading Godot export templates -> $TPZ"
	download_with_resume "$TPZ" "$URL"
fi

for tool in unzip; do
	if ! command -v "$tool" >/dev/null 2>&1; then
		echo "ERROR: missing required tool: $tool" >&2
		exit 2
	fi
done

if [[ "$DOWNLOAD" == "1" ]] && ! unzip -t "$TPZ" >/dev/null 2>&1; then
	if ! command -v curl >/dev/null 2>&1; then
		echo "ERROR: curl is required to resume incomplete export templates download." >&2
		exit 2
	fi
	if [[ -z "$URL" ]]; then
		URL="$(default_url)"
	fi
	echo "Resuming incomplete Godot export templates download -> $TPZ"
	download_with_resume "$TPZ" "$URL"
fi

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
