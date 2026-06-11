#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PRESET="${1:-}"
OUT_PATH="${2:-}"

if [ -z "$PRESET" ] || [ -z "$OUT_PATH" ]; then
	echo "Usage: tools/c00/export_with_godot.sh <export-preset-name> <output-path>" >&2
	echo "Example: tools/c00/export_with_godot.sh 'C00 Rokid OpenXR' builds/rokid/c00.apk" >&2
	exit 2
fi

resolve_godot_binary() {
	if [ -n "${GODOT_BIN:-}" ] && [ -x "$GODOT_BIN" ]; then
		printf "%s" "$GODOT_BIN"
		return 0
	fi
	if command -v godot >/dev/null 2>&1; then
		command -v godot
		return 0
	fi
	local bundled="$PROJECT_ROOT/.godot/cache/c00/godot-editor/Godot.app/Contents/MacOS/Godot"
	if [ -x "$bundled" ]; then
		printf "%s" "$bundled"
		return 0
	fi
	local applications="/Applications/Godot.app/Contents/MacOS/Godot"
	if [ -x "$applications" ]; then
		printf "%s" "$applications"
		return 0
	fi
	return 1
}

if ! GODOT="$(resolve_godot_binary)"; then
	echo "Godot executable not found. Install Godot or set GODOT_BIN=/path/to/Godot." >&2
	exit 2
fi

if [ ! -f "$PROJECT_ROOT/export_presets.cfg" ]; then
	echo "export_presets.cfg not found." >&2
	echo "Create C00 export presets in Godot editor first. See tools/c00/EXPORT_PRESETS_CN.md." >&2
	exit 2
fi

case "$OUT_PATH" in
	/*) EXPORT_PATH="$OUT_PATH" ;;
	*) EXPORT_PATH="$PROJECT_ROOT/$OUT_PATH" ;;
esac

is_android_export=0
case "$EXPORT_PATH" in
	*.apk|*.aab) is_android_export=1 ;;
esac

if [ "$is_android_export" = "1" ] && [ "${GODOT_CONFIGURE_ANDROID_EXPORT:-auto}" != "0" ]; then
	export GRADLE_USER_HOME="${GRADLE_USER_HOME:-$PROJECT_ROOT/.godot/cache/c00/gradle}"
	echo "Preparing project-local Gradle user home: $GRADLE_USER_HOME"
	"$PROJECT_ROOT/tools/c00/prepare_gradle_user_home.sh"
	echo "Configuring Android export environment before Godot export..."
	"$PROJECT_ROOT/tools/c00/configure_android_export_environment.sh" \
		--godot "$GODOT" \
		--install-build-template
fi

GODOT_XR_MODE="${GODOT_EXPORT_XR_MODE:-off}"
GODOT_ARGS=(--headless)
if [ "${C00_GODOT_VERBOSE:-0}" = "1" ]; then
	GODOT_ARGS+=(--verbose)
fi
if [ -n "$GODOT_XR_MODE" ]; then
	GODOT_ARGS+=(--xr-mode "$GODOT_XR_MODE")
fi

EXPORT_TIMEOUT_SECONDS="${C00_GODOT_EXPORT_TIMEOUT_SECONDS:-900}"
case "$EXPORT_TIMEOUT_SECONDS" in
	""|*[!0-9]*)
		echo "C00_GODOT_EXPORT_TIMEOUT_SECONDS must be a non-negative integer number of seconds." >&2
		exit 2
		;;
esac

mkdir -p "$(dirname "$EXPORT_PATH")"

EXPORT_TARGET="$EXPORT_PATH"
EXPORT_TMP=""
GODOT_EXPORT_PID=""
WATCHDOG_PID=""
WATCHDOG_MARKER=""

project_only_stem_for_zip() {
	local path="$1"
	case "$path" in
		*.zip) printf "%s" "${path%.zip}" ;;
		*) return 1 ;;
	esac
}

cleanup_project_only_export_stem() {
	local stem="$1"
	if [ -z "$stem" ]; then
		return
	fi
	rm -rf "$stem" "$stem.xcodeproj" "$stem.xcframework"
	rm -f "$stem.pck"
}

has_project_only_ios_export() {
	local path="$1"
	local stem
	if ! stem="$(project_only_stem_for_zip "$path")"; then
		return 1
	fi
	[ -d "$stem" ] && [ -d "$stem.xcodeproj" ]
}

rewrite_project_only_export_name() {
	local stem="$1"
	local old_name="$2"
	local new_name="$3"
	local hidden_short_name=""
	if [ "$old_name" = "$new_name" ]; then
		return
	fi

	case "$old_name" in
		.*.tmp-*)
			hidden_short_name="${old_name%%.tmp-*}"
			;;
	esac

	if [ -f "$stem/$old_name-Info.plist" ]; then
		mv -f "$stem/$old_name-Info.plist" "$stem/$new_name-Info.plist"
	fi
	if [ -f "$stem/$old_name.entitlements" ]; then
		mv -f "$stem/$old_name.entitlements" "$stem/$new_name.entitlements"
	fi
	if [ -f "$stem.xcodeproj/xcshareddata/xcschemes/$old_name.xcscheme" ]; then
		mv -f "$stem.xcodeproj/xcshareddata/xcschemes/$old_name.xcscheme" "$stem.xcodeproj/xcshareddata/xcschemes/$new_name.xcscheme"
	fi

	node - "$stem" "$new_name" "$old_name" "$hidden_short_name" <<'NODE'
const fs = require("fs");
const path = require("path");

const [stem, newName, ...oldNames] = process.argv.slice(2);
const roots = [stem, `${stem}.xcodeproj`];
const aliases = [...new Set(oldNames.filter((name) => name && name !== newName))];

for (const root of roots) {
	for (const file of walk(root)) {
		const before = fs.readFileSync(file);
		if (before.includes(0)) {
			continue;
		}
		let text = before.toString("utf8");
		let changed = false;
		for (const oldName of aliases) {
			if (!text.includes(oldName)) {
				continue;
			}
			text = text.split(oldName).join(newName);
			changed = true;
		}
		if (!changed) {
			continue;
		}
		fs.writeFileSync(file, text, "utf8");
	}
}

function walk(root) {
	const files = [];
	if (!fs.existsSync(root)) {
		return files;
	}
	const stack = [root];
	while (stack.length) {
		const current = stack.pop();
		for (const entry of fs.readdirSync(current, { withFileTypes: true })) {
			const absolute = path.join(current, entry.name);
			if (entry.isDirectory()) {
				stack.push(absolute);
			} else if (entry.isFile()) {
				files.push(absolute);
			}
		}
	}
	return files;
}
NODE
}

finalize_project_only_ios_export() {
	local source_stem="$1"
	local dest_stem="$2"
	local suffix source_path

	if [ "$source_stem" = "$dest_stem" ]; then
		return
	fi

	cleanup_project_only_export_stem "$dest_stem"
	for suffix in "" ".pck" ".xcodeproj" ".xcframework"; do
		source_path="$source_stem$suffix"
		if [ -e "$source_path" ]; then
			mv -f "$source_path" "$dest_stem$suffix"
		fi
	done
	rewrite_project_only_export_name "$dest_stem" "$(basename "$source_stem")" "$(basename "$dest_stem")"
}

cleanup_tmp_export() {
	if [ -n "$WATCHDOG_PID" ]; then
		kill "$WATCHDOG_PID" 2>/dev/null || true
		wait "$WATCHDOG_PID" 2>/dev/null || true
	fi
	if [ -n "$GODOT_EXPORT_PID" ] && kill -0 "$GODOT_EXPORT_PID" 2>/dev/null; then
		kill -TERM "$GODOT_EXPORT_PID" 2>/dev/null || true
	fi
	if [ -n "$EXPORT_TMP" ] && [ -f "$EXPORT_TMP" ]; then
		rm -f "$EXPORT_TMP"
	fi
	if [ -n "$EXPORT_TMP" ]; then
		if tmp_project_stem="$(project_only_stem_for_zip "$EXPORT_TMP")"; then
			cleanup_project_only_export_stem "$tmp_project_stem"
		fi
	fi
	if [ -n "$WATCHDOG_MARKER" ] && [ -f "$WATCHDOG_MARKER" ]; then
		rm -f "$WATCHDOG_MARKER"
	fi
}
trap cleanup_tmp_export EXIT

if [ "${C00_ATOMIC_EXPORT:-1}" != "0" ]; then
	export_dir="$(dirname "$EXPORT_PATH")"
	export_name="$(basename "$EXPORT_PATH")"
	case "$export_name" in
		*.*)
			export_stem="${export_name%.*}"
			export_ext="${export_name##*.}"
			EXPORT_TMP="$export_dir/.${export_stem}.tmp-$$.${export_ext}"
			;;
		*)
			EXPORT_TMP="$export_dir/.${export_name}.tmp-$$"
			;;
	esac
	rm -f "$EXPORT_TMP"
	if tmp_project_stem="$(project_only_stem_for_zip "$EXPORT_TMP")"; then
		cleanup_project_only_export_stem "$tmp_project_stem"
	fi
	EXPORT_TARGET="$EXPORT_TMP"
fi

echo "Exporting preset '$PRESET' -> $OUT_PATH"
if [ "$EXPORT_TARGET" != "$EXPORT_PATH" ]; then
	echo "Using atomic export target: $EXPORT_TARGET"
fi
if [ "$EXPORT_TIMEOUT_SECONDS" = "0" ]; then
	echo "Godot export timeout: disabled"
else
	echo "Godot export timeout: ${EXPORT_TIMEOUT_SECONDS}s (set C00_GODOT_EXPORT_TIMEOUT_SECONDS=0 to disable)"
fi

run_godot_export() {
	if [ "$EXPORT_TIMEOUT_SECONDS" = "0" ]; then
		"$GODOT" "${GODOT_ARGS[@]}" --path "$PROJECT_ROOT" --export-debug "$PRESET" "$EXPORT_TARGET"
		return $?
	fi

	WATCHDOG_MARKER="$EXPORT_TARGET.timeout-$$"
	rm -f "$WATCHDOG_MARKER"
	"$GODOT" "${GODOT_ARGS[@]}" --path "$PROJECT_ROOT" --export-debug "$PRESET" "$EXPORT_TARGET" &
	GODOT_EXPORT_PID=$!
	(
		sleep "$EXPORT_TIMEOUT_SECONDS"
		if kill -0 "$GODOT_EXPORT_PID" 2>/dev/null; then
			printf "timeout\n" > "$WATCHDOG_MARKER"
			echo "Godot export timed out after ${EXPORT_TIMEOUT_SECONDS}s; terminating pid ${GODOT_EXPORT_PID}." >&2
			kill -TERM "$GODOT_EXPORT_PID" 2>/dev/null || true
			sleep 10
			if kill -0 "$GODOT_EXPORT_PID" 2>/dev/null; then
				echo "Godot export did not stop after TERM; sending KILL to pid ${GODOT_EXPORT_PID}." >&2
				kill -KILL "$GODOT_EXPORT_PID" 2>/dev/null || true
			fi
		fi
	) &
	WATCHDOG_PID=$!

	wait "$GODOT_EXPORT_PID"
	local export_status=$?
	GODOT_EXPORT_PID=""
	kill "$WATCHDOG_PID" 2>/dev/null || true
	wait "$WATCHDOG_PID" 2>/dev/null || true
	WATCHDOG_PID=""

	if [ -f "$WATCHDOG_MARKER" ]; then
		rm -f "$WATCHDOG_MARKER"
		WATCHDOG_MARKER=""
		return 124
	fi
	WATCHDOG_MARKER=""
	return "$export_status"
}

set +e
run_godot_export
export_status=$?
set -e
if [ "$export_status" -ne 0 ]; then
	echo "Godot export failed with status $export_status." >&2
	if [ "$export_status" -eq 124 ]; then
		echo "The export watchdog timed out. Increase C00_GODOT_EXPORT_TIMEOUT_SECONDS for slow machines, or set it to 0 to disable the watchdog while debugging Godot itself." >&2
	fi
	exit "$export_status"
fi

if [ -s "$EXPORT_TARGET" ]; then
	if [ "$EXPORT_TARGET" != "$EXPORT_PATH" ]; then
		mv -f "$EXPORT_TARGET" "$EXPORT_PATH"
	fi
elif has_project_only_ios_export "$EXPORT_TARGET"; then
	source_project_stem="$(project_only_stem_for_zip "$EXPORT_TARGET")"
	dest_project_stem="$(project_only_stem_for_zip "$EXPORT_PATH")"
	finalize_project_only_ios_export "$source_project_stem" "$dest_project_stem"
	echo "Godot export created iOS Xcode project: $dest_project_stem.xcodeproj"
else
	echo "Godot export did not create a non-empty artifact or iOS project-only export: $EXPORT_TARGET" >&2
	exit 1
fi
