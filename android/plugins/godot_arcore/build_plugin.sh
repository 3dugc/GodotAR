#!/usr/bin/env bash
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$PLUGIN_ROOT/../../.." && pwd)"
GRADLE_BIN="${GRADLE_BIN:-gradle}"
GODOT_ANDROID_VERSION="${GODOT_ANDROID_VERSION:-4.4.1.stable}"
ARCORE_VERSION="${ARCORE_VERSION:-1.33.0}"

"$GRADLE_BIN" \
	-p "$PLUGIN_ROOT" \
	-PgodotAndroidVersion="$GODOT_ANDROID_VERSION" \
	-ParcoreVersion="$ARCORE_VERSION" \
	:godot-arcore:assembleDebug \
	:godot-arcore:assembleRelease

mkdir -p \
	"$PROJECT_ROOT/addons/godot_arcore/bin/debug" \
	"$PROJECT_ROOT/addons/godot_arcore/bin/release"

cp "$PLUGIN_ROOT/godot-arcore/build/outputs/aar/godot-arcore-debug.aar" \
	"$PROJECT_ROOT/addons/godot_arcore/bin/debug/GodotARCore-debug.aar"
cp "$PLUGIN_ROOT/godot-arcore/build/outputs/aar/godot-arcore-release.aar" \
	"$PROJECT_ROOT/addons/godot_arcore/bin/release/GodotARCore-release.aar"

printf "GodotARCore AARs copied to addons/godot_arcore/bin\n"
