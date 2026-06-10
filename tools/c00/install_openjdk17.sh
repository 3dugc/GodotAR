#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DOWNLOADS_DIR="$PROJECT_ROOT/.godot/cache/c00/downloads"
DEST="$PROJECT_ROOT/.godot/cache/c00/jdk"
ARCHIVE=""
URL=""
URLS="${OPENJDK17_URLS:-${C00_OPENJDK17_URLS:-}}"
DOWNLOAD_URLS=()
DOWNLOAD=0
FORCE=0

usage() {
	cat <<EOF
Usage:
  tools/c00/install_openjdk17.sh [options]

Options:
  --archive <file>  Existing OpenJDK 17 tar.gz archive.
  --download        Download Eclipse Temurin OpenJDK 17 through the Adoptium API when archive is missing.
  --url <url>       Download URL. Defaults to latest Temurin 17 GA for this macOS architecture.
  --urls "<a> <b>"  Try multiple download URLs in order.
  --dest <dir>      Install destination. Default: .godot/cache/c00/jdk
  --force           Replace an existing destination.

Installs a project-local JDK used by Godot Android export:
  .godot/cache/c00/jdk/Contents/Home

Download tuning:
  C00_CURL_RETRY=8 C00_CURL_RETRY_DELAY=15 C00_CURL_SPEED_LIMIT=1024 C00_CURL_SPEED_TIME=30 C00_CURL_MAX_TIME=900 C00_CURL_HTTP1=1 \\
    tools/c00/install_openjdk17.sh --download
EOF
}

detect_arch() {
	case "$(uname -m)" in
		arm64|aarch64) printf "aarch64" ;;
		x86_64|amd64) printf "x64" ;;
		*)
			echo "ERROR: unsupported architecture: $(uname -m)" >&2
			exit 2
			;;
	esac
}

ARCH="$(detect_arch)"
if [[ -z "$URL" ]]; then
	URL="https://api.adoptium.net/v3/binary/latest/17/ga/mac/$ARCH/jdk/hotspot/normal/eclipse"
fi

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
	if [[ -n "$URLS" ]]; then
		add_download_urls_from_list "$URLS"
	else
		add_download_url "$URL"
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
		--archive)
			ARCHIVE="$2"
			shift 2
			;;
		--download)
			DOWNLOAD=1
			shift
			;;
		--url)
			URL="$2"
			URLS=""
			shift 2
			;;
		--urls)
			URLS="$2"
			shift 2
			;;
		--dest)
			DEST="$2"
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

configure_download_urls

mkdir -p "$DOWNLOADS_DIR"

if [[ -z "$ARCHIVE" ]]; then
	ARCHIVE="$DOWNLOADS_DIR/temurin17-mac-$ARCH.tar.gz"
fi

if [[ ! -f "$ARCHIVE" ]]; then
	if [[ "$DOWNLOAD" != "1" ]]; then
		echo "ERROR: OpenJDK archive not found: $ARCHIVE" >&2
		echo "Pass --archive <file> or --download." >&2
		exit 2
	fi
	if ! command -v curl >/dev/null 2>&1; then
		echo "ERROR: curl is required for --download." >&2
		exit 2
	fi
	echo "Downloading OpenJDK 17 -> $ARCHIVE"
	download_with_resume "$ARCHIVE" "${DOWNLOAD_URLS[@]}"
fi

for tool in tar; do
	if ! command -v "$tool" >/dev/null 2>&1; then
		echo "ERROR: missing required tool: $tool" >&2
		exit 2
	fi
done

if [[ "$DOWNLOAD" == "1" ]] && ! tar -tzf "$ARCHIVE" >/dev/null 2>&1; then
	if ! command -v curl >/dev/null 2>&1; then
		echo "ERROR: curl is required to resume incomplete OpenJDK download." >&2
		exit 2
	fi
	echo "Resuming incomplete OpenJDK 17 download -> $ARCHIVE"
	download_with_resume "$ARCHIVE" "${DOWNLOAD_URLS[@]}"
fi

if [[ -d "$DEST/Contents/Home" && "$FORCE" != "1" ]]; then
	echo "OK   OpenJDK 17 already installed: $DEST/Contents/Home"
	"$DEST/Contents/Home/bin/java" -version >/dev/null
	"$DEST/Contents/Home/bin/keytool" -help >/dev/null
	exit 0
fi

tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/godotar-openjdk17.XXXXXX")"
cleanup() {
	rm -rf "$tmp_dir"
}
trap cleanup EXIT

echo "Extracting OpenJDK archive: $ARCHIVE"
tar -xzf "$ARCHIVE" -C "$tmp_dir"

java_home=""
while IFS= read -r candidate; do
	if [[ -x "$candidate/bin/java" && -x "$candidate/bin/keytool" ]]; then
		java_home="$candidate"
		break
	fi
done < <(find "$tmp_dir" -type d \( -path "*/Contents/Home" -o -name Home \) -print)

if [[ -z "$java_home" ]]; then
	while IFS= read -r java_bin; do
		candidate="$(dirname "$(dirname "$java_bin")")"
		if [[ -x "$candidate/bin/keytool" ]]; then
			java_home="$candidate"
			break
		fi
	done < <(find "$tmp_dir" -type f -path "*/bin/java" -perm -111 -print)
fi

if [[ -z "$java_home" ]]; then
	echo "ERROR: archive does not contain a runnable JDK with bin/java and bin/keytool." >&2
	exit 1
fi

if [[ "$FORCE" == "1" ]]; then
	rm -rf "$DEST/Contents/Home"
fi
mkdir -p "$DEST/Contents"
rm -rf "$DEST/Contents/Home"
cp -R "$java_home" "$DEST/Contents/Home"

"$DEST/Contents/Home/bin/java" -version >/dev/null
"$DEST/Contents/Home/bin/keytool" -help >/dev/null

cat <<EOF
OpenJDK 17 installed:
  GODOT_JAVA_SDK_PATH=$DEST/Contents/Home
  JAVA_HOME=$DEST/Contents/Home

Use:
  export GODOT_JAVA_SDK_PATH="$DEST/Contents/Home"
  export JAVA_HOME="$DEST/Contents/Home"
EOF
