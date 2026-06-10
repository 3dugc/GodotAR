#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
. "$PROJECT_ROOT/tools/c00/godot_version_defaults.sh"
TPZ="${TPZ:-}"
VERSION="$(godot_normalize_template_version "${GODOT_EXPORT_TEMPLATES_VERSION:-$C00_GODOT_DEFAULT_EXPORT_TEMPLATES_VERSION}")"
DEST="${GODOT_EXPORT_TEMPLATES_DIR:-$HOME/Library/Application Support/Godot/export_templates/$VERSION}"
DOWNLOAD=0
URL="${GODOT_EXPORT_TEMPLATES_URL:-}"
URLS="${GODOT_EXPORT_TEMPLATES_URLS:-}"
DOWNLOAD_URLS=()

set_version() {
	VERSION="$(godot_normalize_template_version "$1")"
	DEST="${GODOT_EXPORT_TEMPLATES_DIR:-$HOME/Library/Application Support/Godot/export_templates/$VERSION}"
}

usage() {
	cat <<EOF
Usage:
  tools/c00/install_godot_export_templates.sh --tpz <Godot_v4.7-rc1_export_templates.tpz> [--version 4.7.rc1]
  tools/c00/install_godot_export_templates.sh --download [--latest|--latest-stable|--version 4.7.rc1]

Installs official Godot export templates into the directory used by Godot:
  $DEST

C00 follows the newest official Godot line by default.
  latest:        $C00_GODOT_LATEST_TAG / $C00_GODOT_LATEST_EXPORT_TEMPLATES_VERSION
  latest stable: $C00_GODOT_STABLE_TAG / $C00_GODOT_STABLE_EXPORT_TEMPLATES_VERSION

Template, Godot editor, and Godot source headers must use the same version.
Legacy 4.4.1 exports remain available by passing --version 4.4.1.stable.

Download sources:
  --url <url>       Use one URL.
  --urls "<a> <b>"  Try multiple URLs in order.
  GODOT_EXPORT_TEMPLATES_URLS can also provide a comma, newline, or space separated fallback list.

Download tuning:
  C00_CURL_RETRY=8 C00_CURL_RETRY_DELAY=15 C00_CURL_SPEED_LIMIT=1024 C00_CURL_SPEED_TIME=30 C00_CURL_MAX_TIME=900 C00_CURL_HTTP1=1 \\
    tools/c00/install_godot_export_templates.sh --download
  C00_PARALLEL_DOWNLOAD=1 C00_PARALLEL_DOWNLOAD_PARTS=8 tools/c00/install_godot_export_templates.sh --download
EOF
}

version_tag() {
	godot_tag_from_template_version "$VERSION"
}

version_number() {
	godot_download_version_number_from_template_version "$VERSION"
}

official_downloads_url() {
	godot_official_download_url_from_template_version "$VERSION"
}

github_release_url() {
	local tag
	tag="$(version_tag)"
	printf "https://github.com/godotengine/godot/releases/download/%s/Godot_v%s_export_templates.tpz" "$tag" "$tag"
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
	if [[ "${C00_PARALLEL_DOWNLOAD:-0}" == "1" ]] && command -v node >/dev/null 2>&1; then
		for url in "$@"; do
			echo "Trying range download URL: $url"
			node "$PROJECT_ROOT/tools/c00/download_http_ranges.js" \
				--url "$url" \
				--output "$output" \
				--parts "${C00_PARALLEL_DOWNLOAD_PARTS:-8}" && return 0
			status=$?
		done
		echo "Range download failed; falling back to single-stream curl."
	fi
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
	versioned_tpz="$PROJECT_ROOT/.godot/cache/c00/downloads/Godot_v$(version_tag)_export_templates.tpz"
	legacy_tpz="$PROJECT_ROOT/.godot/cache/c00/downloads/Godot_v4.4.1-stable_export_templates.tpz"
	if [[ -f "$versioned_tpz" ]]; then
		TPZ="$versioned_tpz"
	elif [[ "$(version_tag)" == "4.4.1-stable" && -f "$legacy_tpz" ]]; then
		TPZ="$legacy_tpz"
	elif [[ "$DOWNLOAD" == "1" ]]; then
		TPZ="$versioned_tpz"
	else
		usage >&2
		exit 2
	fi
fi

configure_download_urls

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
	echo "Downloading Godot export templates -> $TPZ"
	download_with_resume "$TPZ" "${DOWNLOAD_URLS[@]}"
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
	echo "Resuming incomplete Godot export templates download -> $TPZ"
	download_with_resume "$TPZ" "${DOWNLOAD_URLS[@]}"
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
