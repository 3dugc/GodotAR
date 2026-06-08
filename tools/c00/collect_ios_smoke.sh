#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEVICE="${1:-}"
BUNDLE_ID="${2:-org.godotengine.godotxrfoundation}"
DURATION="${3:-30}"
APP_PATH="${APP_PATH:-}"
EXTRA_VALIDATE_ARGS="${EXTRA_VALIDATE_ARGS:-}"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT_DIR="$PROJECT_ROOT/releases/phase_0_smoke/evidence"
LOG_PATH="$OUT_DIR/ipad-${STAMP}.log"
REPORT_PATH="$OUT_DIR/ipad-${STAMP}.md"

mkdir -p "$OUT_DIR"

if ! command -v xcrun >/dev/null 2>&1; then
	echo "xcrun not found. Install Xcode and select it with xcode-select." >&2
	exit 2
fi

if [ -z "$DEVICE" ]; then
	echo "Device argument is required. Run: xcrun devicectl list devices"
	exit 2
fi

if [ -n "$APP_PATH" ]; then
	echo "Installing app bundle: $APP_PATH"
	xcrun devicectl device install app --device "$DEVICE" "$APP_PATH"
fi

echo "Launching $BUNDLE_ID on $DEVICE with console capture for ${DURATION}s"
set +e
xcrun devicectl \
	--timeout "$DURATION" \
	device process launch \
	--device "$DEVICE" \
	--terminate-existing \
	--console \
	"$BUNDLE_ID" \
	--xr-platform=ipad > "$LOG_PATH" 2>&1
LAUNCH_STATUS="$?"
set -e

if ! grep -q "GXF_SMOKE" "$LOG_PATH"; then
	if command -v idevicesyslog >/dev/null 2>&1; then
		echo "No GXF_SMOKE from devicectl console. Trying idevicesyslog for ${DURATION}s..."
		idevicesyslog > "$LOG_PATH" &
		LOG_PID="$!"
		sleep "$DURATION"
		kill "$LOG_PID" >/dev/null 2>&1 || true
		wait "$LOG_PID" >/dev/null 2>&1 || true
	elif command -v pymobiledevice3 >/dev/null 2>&1; then
		echo "No GXF_SMOKE from devicectl console. Trying pymobiledevice3 syslog for ${DURATION}s..."
		pymobiledevice3 syslog live > "$LOG_PATH" &
		LOG_PID="$!"
		sleep "$DURATION"
		kill "$LOG_PID" >/dev/null 2>&1 || true
		wait "$LOG_PID" >/dev/null 2>&1 || true
	else
		echo "No iOS syslog tool found. If validation fails, export logs from Xcode/Console.app and run validate_smoke_log.js manually."
	fi
fi

echo "devicectl launch status: $LAUNCH_STATUS"
echo "Validating iPad gate"
node "$PROJECT_ROOT/tools/c00/validate_smoke_log.js" \
	--gate ipad \
	--log "$LOG_PATH" \
	--report "$REPORT_PATH" \
	$EXTRA_VALIDATE_ARGS

echo "Report: $REPORT_PATH"
