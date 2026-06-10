#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
. "$PROJECT_ROOT/tools/c00/godot_version_defaults.sh"

ZIP="${GODOT_EDITOR_ZIP:-}"
VERSION="$(godot_normalize_template_version "${GODOT_VERSION:-${GODOT_EXPORT_TEMPLATES_VERSION:-$C00_GODOT_DEFAULT_EXPORT_TEMPLATES_VERSION}}")"
DEST="${GODOT_EDITOR_DIR:-$PROJECT_ROOT/.godot/cache/c00/godot-editor}"
DOWNLOAD=0
URL="${GODOT_EDITOR_URL:-}"
URLS="${GODOT_EDITOR_URLS:-}"
DOWNLOAD_URLS=()
CODESIGN=auto

set_version() {
	VERSION="$(godot_normalize_template_version "$1")"
}

usage() {
	cat <<EOF
Usage:
  tools/c00/install_godot_editor.sh --download [--latest|--latest-stable|--version 4.7.rc1]
  tools/c00/install_godot_editor.sh --zip <Godot_v4.7-rc1_macos.universal.zip> [--version 4.7.rc1]

Installs the macOS Godot editor into:
  $DEST/Godot.app

C00 expects Godot editor, export templates, and Godot source headers to use the
same version.
  latest:        $C00_GODOT_LATEST_TAG / $C00_GODOT_LATEST_EXPORT_TEMPLATES_VERSION
  latest stable: $C00_GODOT_STABLE_TAG / $C00_GODOT_STABLE_EXPORT_TEMPLATES_VERSION

Download sources:
  --url <url>       Use one URL.
  --urls "<a> <b>"  Try multiple URLs in order.
  GODOT_EDITOR_URLS can also provide a comma, newline, or space separated fallback list.
  When no URL is provided, C00 tries the Godot downloads entry first, then the
  matching GitHub release asset if it exists for that version.

Download tuning:
  C00_CURL_RETRY=8 C00_CURL_RETRY_DELAY=15 C00_CURL_SPEED_LIMIT=1024 C00_CURL_SPEED_TIME=30 C00_CURL_MAX_TIME=900 C00_CURL_HTTP1=1 \\
    tools/c00/install_godot_editor.sh --download --latest
EOF
}

editor_archive_name() {
	godot_macos_editor_archive_name_from_template_version "$VERSION"
}

official_downloads_url() {
	godot_official_macos_editor_url_from_template_version "$VERSION"
}

github_release_url() {
	godot_github_macos_editor_url_from_template_version "$VERSION"
}

add_download_url() {
	local candidate="$1"
	if [[ -n "$candidate" ]]; then
		DOWNLOAD_URLS+=("$candidate")
	fi
}

add_download_urls_from_list() {
	local list="$1"
	list="${list//$'\n'/ }"
	list="${list//,/ }"
	for candidate in $list; do
		add_download_url "$candidate"
	done
}

configure_download_urls() {
	DOWNLOAD_URLS=()
	if [[ -n "$URL" ]]; then
		add_download_url "$URL"
	fi
	if [[ -n "$URLS" ]]; then
		add_download_urls_from_list "$URLS"
	fi
	if [[ "${#DOWNLOAD_URLS[@]}" -eq 0 ]]; then
		add_download_url "$(official_downloads_url)"
		add_download_url "$(github_release_url)"
	fi
}

download_with_resume() {
	local output="$1"
	shift
	local curl_retry="${C00_CURL_RETRY:-5}"
	local curl_retry_delay="${C00_CURL_RETRY_DELAY:-10}"
	local curl_connect_timeout="${C00_CURL_CONNECT_TIMEOUT:-30}"
	local curl_speed_limit="${C00_CURL_SPEED_LIMIT:-512}"
	local curl_speed_time="${C00_CURL_SPEED_TIME:-60}"
	local curl_retry_all_errors="${C00_CURL_RETRY_ALL_ERRORS:-1}"
	local curl_http1="${C00_CURL_HTTP1:-0}"
	local args=(-L --fail -C - --retry "$curl_retry" --retry-delay "$curl_retry_delay" --connect-timeout "$curl_connect_timeout" --speed-limit "$curl_speed_limit" --speed-time "$curl_speed_time")
	if [[ "$curl_retry_all_errors" != "0" ]]; then
		args+=(--retry-all-errors)
	fi
	if [[ "$curl_http1" == "1" ]]; then
		args+=(--http1.1)
	fi
	if [[ -n "${C00_CURL_MAX_TIME:-}" ]]; then
		args+=(--max-time "$C00_CURL_MAX_TIME")
	fi
	if [[ -n "${C00_CURL_EXTRA_ARGS:-}" ]]; then
		# shellcheck disable=SC2206
		local extra_args=($C00_CURL_EXTRA_ARGS)
		args+=("${extra_args[@]}")
	fi
	local status=1
	local url
	for url in "$@"; do
		echo "Trying download URL: $url"
		curl "${args[@]}" -o "$output" "$url" && return 0
		status=$?
		if [[ "$status" == "0" ]]; then
			return 0
		fi
	done
	return "$status"
}

while [[ "$#" -gt 0 ]]; do
	case "$1" in
		--zip)
			ZIP="$2"
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
		--urls)
			URLS="$2"
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
		--dir)
			DEST="$2"
			shift 2
			;;
		--no-codesign)
			CODESIGN=0
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

if [[ -z "$ZIP" ]]; then
	versioned_zip="$PROJECT_ROOT/.godot/cache/c00/downloads/$(editor_archive_name)"
	if [[ -f "$versioned_zip" ]]; then
		ZIP="$versioned_zip"
	elif [[ "$DOWNLOAD" == "1" ]]; then
		ZIP="$versioned_zip"
	else
		usage >&2
		exit 2
	fi
fi

configure_download_urls

if [[ ! -f "$ZIP" ]]; then
	if [[ "$DOWNLOAD" != "1" ]]; then
		echo "ERROR: Godot editor zip not found: $ZIP" >&2
		exit 2
	fi
	if ! command -v curl >/dev/null 2>&1; then
		echo "ERROR: curl is required for --download." >&2
		exit 2
	fi
	mkdir -p "$(dirname "$ZIP")"
	echo "Downloading Godot editor -> $ZIP"
	download_with_resume "$ZIP" "${DOWNLOAD_URLS[@]}"
fi

for tool in unzip; do
	if ! command -v "$tool" >/dev/null 2>&1; then
		echo "ERROR: missing required tool: $tool" >&2
		exit 2
	fi
done

if [[ "$DOWNLOAD" == "1" ]] && ! unzip -t "$ZIP" >/dev/null 2>&1; then
	if ! command -v curl >/dev/null 2>&1; then
		echo "ERROR: curl is required to resume incomplete Godot editor download." >&2
		exit 2
	fi
	echo "Resuming incomplete Godot editor download -> $ZIP"
	download_with_resume "$ZIP" "${DOWNLOAD_URLS[@]}"
fi

tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/godot-editor.XXXXXX")"
cleanup() {
	rm -rf "$tmp_dir"
}
trap cleanup EXIT

echo "Checking archive: $ZIP"
unzip -t "$ZIP" >/dev/null

echo "Extracting Godot editor -> $DEST"
rm -rf "$tmp_dir/extract"
mkdir -p "$tmp_dir/extract" "$DEST"
unzip -q "$ZIP" -d "$tmp_dir/extract"

app_path="$(find "$tmp_dir/extract" -maxdepth 4 -type d -name "Godot.app" -print -quit 2>/dev/null || true)"
if [[ -z "$app_path" ]]; then
	echo "ERROR: archive does not contain Godot.app." >&2
	exit 1
fi

rm -rf "$DEST/Godot.app"
cp -R "$app_path" "$DEST/Godot.app"

godot_bin="$DEST/Godot.app/Contents/MacOS/Godot"
if [[ ! -x "$godot_bin" ]]; then
	echo "ERROR: installed Godot binary is not executable: $godot_bin" >&2
	exit 1
fi

if command -v xattr >/dev/null 2>&1; then
	xattr -dr com.apple.quarantine "$DEST/Godot.app" 2>/dev/null || true
fi

if [[ "$CODESIGN" != "0" ]] && command -v codesign >/dev/null 2>&1; then
	codesign --force --deep --sign - "$DEST/Godot.app" >/dev/null 2>&1 || true
fi

installed_version="$(godot_binary_version "$godot_bin" || true)"
if [[ -z "$installed_version" ]]; then
	echo "ERROR: installed Godot binary did not report a version: $godot_bin" >&2
	exit 1
fi

if [[ "$installed_version" != "$VERSION" ]]; then
	echo "ERROR: installed Godot version $installed_version does not match requested $VERSION." >&2
	exit 1
fi

echo "Godot editor installed for $VERSION"
echo "export GODOT_BIN=\"$godot_bin\""
