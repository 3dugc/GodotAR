#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STAMP="${STAMP:-$(date +%Y%m%d-%H%M%S)}"
OUT_DIR="${OUT_DIR:-$PROJECT_ROOT/releases/phase_0_smoke/packages}"
EVIDENCE_DIR="${EVIDENCE_DIR:-$PROJECT_ROOT/releases/phase_0_smoke/evidence}"
DEVICE="${DEVICE:-iPad M4}"
PACKAGE_NAME_EXPLICIT=0
if [[ -n "${PACKAGE_NAME:-}" ]]; then
	PACKAGE_NAME_EXPLICIT=1
else
	PACKAGE_NAME="c00-device-handoff-$STAMP"
fi
PACKAGE_DIR="$OUT_DIR/$PACKAGE_NAME"
ZIP_PATH="$OUT_DIR/$PACKAGE_NAME.zip"

usage() {
	cat <<EOF
Usage:
  tools/c00/create_device_handoff_package.sh [options]

Options:
  --out-dir <dir>       Package output directory. Default: releases/phase_0_smoke/packages.
  --evidence-dir <dir>  Evidence input directory. Default: releases/phase_0_smoke/evidence.
  --stamp <stamp>       Package stamp. Default: current timestamp.
  --device <name>       iPad device name/id written into handoff commands. Default: iPad M4.
  --package-name <name> Package folder and zip base name. Default: c00-device-handoff-<stamp>.

This creates a device-lab handoff package with current build artifacts,
runbooks, specs, migration docs, latest readiness evidence, and exact commands.
It is not a phase-1 pass result; real Rokid/OpenXR and iPad/ARKit evidence
must still be collected by the device gate.
EOF
}

project_path() {
	local input="$1"
	case "$input" in
		/*) printf "%s" "$input" ;;
		*) printf "%s/%s" "$PROJECT_ROOT" "$input" ;;
	esac
}

json_quote() {
	node -e 'process.stdout.write(JSON.stringify(process.argv[1] || ""))' "$1"
}

comma_if_not_last() {
	local index="$1"
	local total="$2"
	if [[ "$index" -lt $(( total - 1 )) ]]; then
		printf ","
	fi
}

while [[ "$#" -gt 0 ]]; do
	case "$1" in
		--out-dir)
			OUT_DIR="$2"
			shift 2
			;;
		--evidence-dir)
			EVIDENCE_DIR="$2"
			shift 2
			;;
		--stamp)
			STAMP="$2"
			if [[ "$PACKAGE_NAME_EXPLICIT" != "1" ]]; then
				PACKAGE_NAME="c00-device-handoff-$STAMP"
			fi
			shift 2
			;;
		--device)
			DEVICE="$2"
			shift 2
			;;
		--package-name)
			PACKAGE_NAME="$2"
			PACKAGE_NAME_EXPLICIT=1
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

OUT_DIR="$(project_path "$OUT_DIR")"
EVIDENCE_DIR="$(project_path "$EVIDENCE_DIR")"
PACKAGE_DIR="$OUT_DIR/$PACKAGE_NAME"
ZIP_PATH="$OUT_DIR/$PACKAGE_NAME.zip"

mkdir -p "$OUT_DIR"
rm -rf "$PACKAGE_DIR" "$ZIP_PATH"
mkdir -p "$PACKAGE_DIR"/{artifacts,docs,evidence,scripts}

WARNINGS=()
INCLUDED=()

include_file() {
	local source="$1"
	local target="$2"
	if [[ ! -f "$source" ]]; then
		WARNINGS+=("missing file: ${source#$PROJECT_ROOT/}")
		return 0
	fi
	mkdir -p "$(dirname "$target")"
	cp "$source" "$target"
	INCLUDED+=("${target#$PACKAGE_DIR/}")
}

include_optional_file() {
	local source="$1"
	local target="$2"
	if [[ ! -f "$source" ]]; then
		return 0
	fi
	mkdir -p "$(dirname "$target")"
	cp "$source" "$target"
	INCLUDED+=("${target#$PACKAGE_DIR/}")
}

include_dir() {
	local source="$1"
	local target="$2"
	if [[ ! -d "$source" ]]; then
		WARNINGS+=("missing directory: ${source#$PROJECT_ROOT/}")
		return 0
	fi
	mkdir -p "$(dirname "$target")"
	cp -R "$source" "$target"
	INCLUDED+=("${target#$PACKAGE_DIR/}/")
}

include_latest_glob() {
	local pattern="$1"
	local target_dir="$2"
	local latest=""
	latest="$(ls -t $pattern 2>/dev/null | head -n 1 || true)"
	if [[ -z "$latest" ]]; then
		WARNINGS+=("no evidence matched: $pattern")
		return 0
	fi
	include_file "$latest" "$target_dir/$(basename "$latest")"
}

copy_ipad_export_parts() {
	local source_dir="$PROJECT_ROOT/builds/ipad"
	local target_dir="$PACKAGE_DIR/artifacts/ipad"
	if [[ ! -d "$source_dir" ]]; then
		WARNINGS+=("missing iPad export directory: builds/ipad")
		return 0
	fi
	mkdir -p "$target_dir"
	include_optional_file "$source_dir/c00.zip" "$target_dir/c00.zip"
	include_dir "$source_dir/c00.xcodeproj" "$target_dir/c00.xcodeproj"
	include_dir "$source_dir/c00" "$target_dir/c00"
	include_file "$source_dir/c00.pck" "$target_dir/c00.pck"
	include_file "$source_dir/PrivacyInfo.xcprivacy" "$target_dir/PrivacyInfo.xcprivacy"
	for item in "$source_dir"/*.xcframework; do
		if [[ -d "$item" ]]; then
			include_dir "$item" "$target_dir/$(basename "$item")"
		fi
	done
	if [[ -d "$source_dir/GodotXRFoundation-nosign.app" ]]; then
		include_dir "$source_dir/GodotXRFoundation-nosign.app" "$target_dir/GodotXRFoundation-nosign.app"
	fi
}

include_file "$PROJECT_ROOT/builds/rokid/c00.apk" "$PACKAGE_DIR/artifacts/rokid/c00.apk"
include_file "$PROJECT_ROOT/builds/android_arcore/c00.apk" "$PACKAGE_DIR/artifacts/android-arcore/c00.apk"
copy_ipad_export_parts

include_file "$PROJECT_ROOT/export_presets.cfg" "$PACKAGE_DIR/docs/export_presets.cfg"
include_file "$PROJECT_ROOT/project.godot" "$PACKAGE_DIR/docs/project.godot"
include_file "$PROJECT_ROOT/MIGRATION_UNITY.md" "$PACKAGE_DIR/docs/MIGRATION_UNITY.md"
include_file "$PROJECT_ROOT/tools/c00/README_CN.md" "$PACKAGE_DIR/docs/C00_TOOLS_README_CN.md"
include_file "$PROJECT_ROOT/releases/phase_0_smoke/RUNBOOK_CN.md" "$PACKAGE_DIR/docs/RUNBOOK_CN.md"
include_file "$PROJECT_ROOT/releases/phase_0_smoke/TEST_REPORT.md" "$PACKAGE_DIR/docs/TEST_REPORT.md"
include_file "$PROJECT_ROOT/specs/cycles/CYCLE_00_DEVICE_SMOKE_SPEC_CN.md" "$PACKAGE_DIR/docs/CYCLE_00_DEVICE_SMOKE_SPEC_CN.md"
include_dir "$PROJECT_ROOT/tools/c00" "$PACKAGE_DIR/scripts/tools/c00"

include_latest_glob "$EVIDENCE_DIR/device-ready-all-*.md" "$PACKAGE_DIR/evidence"
include_latest_glob "$EVIDENCE_DIR/device-ready-rokid-*.md" "$PACKAGE_DIR/evidence"
include_latest_glob "$EVIDENCE_DIR/device-ready-ipad-*.md" "$PACKAGE_DIR/evidence"
include_latest_glob "$EVIDENCE_DIR/editor-*.md" "$PACKAGE_DIR/evidence"
include_latest_glob "$EVIDENCE_DIR/ios-simulator-*.md" "$PACKAGE_DIR/evidence"

cat > "$PACKAGE_DIR/DEVICE_LAB_HANDOFF.md" <<EOF
# C00 Device Lab Handoff

Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")

This package is a runnable handoff for the phase-1 device lab. It is not a
phase-1 pass result. The final pass still requires real Rokid/OpenXR,
iPad/ARKit, and Android/ARCore smoke evidence.

## Primary Commands

\`\`\`bash
tools/c00/wait_for_device_ready.sh --gate all --device "$DEVICE" --timeout 600
tools/c00/run_phase1_device_lab.sh --device "$DEVICE" --wait-devices --wait-timeout 600
node tools/c00/audit_phase1_completion.js
\`\`\`

## Artifact Notes

- Rokid APK: \`artifacts/rokid/c00.apk\` when present.
- Android ARCore APK: \`artifacts/android-arcore/c00.apk\` when present.
- iPad Xcode export: \`artifacts/ipad/c00.xcodeproj\` plus sibling exported files when present.
- iPad no-sign app: \`artifacts/ipad/GodotXRFoundation-nosign.app\` is build evidence only; real install requires signing/provisioning on the device machine.

## Recovery Flow

1. Connect Rokid/Android and confirm \`adb devices -l\` shows state \`device\`.
2. Unlock iPad, trust this Mac, open Xcode Devices and Simulators, and wait until the iPad is no longer \`offline\` / \`unavailable\`.
3. Run the primary commands above.
4. If device evidence was collected outside these scripts, import it with \`tools/c00/import_device_evidence.sh\`.

## Warnings

$(if [[ "${#WARNINGS[@]}" -eq 0 ]]; then printf "%s\n" "- None"; else printf -- "- %s\n" "${WARNINGS[@]}"; fi)
EOF
INCLUDED+=("DEVICE_LAB_HANDOFF.md")

{
	printf "{\n"
	printf "  \"package\": %s,\n" "$(json_quote "$PACKAGE_NAME")"
	printf "  \"generated_at\": %s,\n" "$(json_quote "$(date -u +"%Y-%m-%dT%H:%M:%SZ")")"
	printf "  \"device\": %s,\n" "$(json_quote "$DEVICE")"
	printf "  \"zip\": %s,\n" "$(json_quote "$ZIP_PATH")"
	printf "  \"warnings\": [\n"
	for index in "${!WARNINGS[@]}"; do
		printf "    %s%s\n" "$(json_quote "${WARNINGS[$index]}")" "$(comma_if_not_last "$index" "${#WARNINGS[@]}")"
	done
	printf "  ],\n"
	printf "  \"included\": [\n"
	for index in "${!INCLUDED[@]}"; do
		printf "    %s%s\n" "$(json_quote "${INCLUDED[$index]}")" "$(comma_if_not_last "$index" "${#INCLUDED[@]}")"
	done
	printf "  ]\n"
	printf "}\n"
} > "$PACKAGE_DIR/manifest.json"

if command -v zip >/dev/null 2>&1; then
	(
		cd "$OUT_DIR"
		zip -qry "$ZIP_PATH" "$PACKAGE_NAME"
	)
	echo "Package directory: $PACKAGE_DIR"
	echo "Package zip: $ZIP_PATH"
elif command -v ditto >/dev/null 2>&1; then
	(
		cd "$OUT_DIR"
		ditto -c -k --sequesterRsrc --keepParent "$PACKAGE_NAME" "$ZIP_PATH"
	)
	echo "Package directory: $PACKAGE_DIR"
	echo "Package zip: $ZIP_PATH"
else
	WARNINGS+=("zip and ditto are unavailable; package directory was created without zip archive")
	echo "Package directory: $PACKAGE_DIR"
fi
