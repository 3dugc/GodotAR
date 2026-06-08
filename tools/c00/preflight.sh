#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

status=0

check_command() {
	local name="$1"
	local purpose="$2"
	if command -v "$name" >/dev/null 2>&1; then
		printf "OK   %-16s %s\n" "$name" "$(command -v "$name")"
	else
		printf "MISS %-16s %s\n" "$name" "$purpose"
		status=1
	fi
}

printf "C00 device smoke preflight\n"
printf "Project: %s\n\n" "$PROJECT_ROOT"

check_command node "required for tools/c00/validate_smoke_log.js"
if [ -n "${GODOT_BIN:-}" ] && [ -x "$GODOT_BIN" ]; then
	printf "OK   %-16s %s\n" "GODOT_BIN" "$GODOT_BIN"
else
	check_command godot "required for command-line export/import validation; set GODOT_BIN if using an app bundle"
fi
check_command adb "required for Rokid/Android log collection"
check_command xcrun "required for iPad install/launch through Xcode tools"

printf "\nPlugin landing zones\n"
for dir in "$PROJECT_ROOT/android/plugins" "$PROJECT_ROOT/ios/plugins"; do
	if [ -d "$dir" ]; then
		printf "OK   %s\n" "$dir"
	else
		printf "MISS %s\n" "$dir"
		status=1
	fi
done

printf "\nGodot project checks\n"
if [ -f "$PROJECT_ROOT/project.godot" ]; then
	printf "OK   project.godot\n"
else
	printf "MISS project.godot\n"
	status=1
fi

if grep -q 'run/main_scene="res://demo/00_device_smoke_test.tscn"' "$PROJECT_ROOT/project.godot"; then
	printf "OK   C00 smoke scene is main_scene\n"
else
	printf "MISS C00 smoke scene is not main_scene\n"
	status=1
fi

printf "\nResult: "
if [ "$status" -eq 0 ]; then
	printf "ready\n"
else
	printf "missing prerequisites\n"
fi

exit "$status"
