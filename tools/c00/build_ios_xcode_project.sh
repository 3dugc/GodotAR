#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
EXPORT_INPUT="${1:-${IPAD_EXPORT_PATH:-$PROJECT_ROOT/builds/ipad/c00.zip}}"
DEVICE="${2:-${DEVICE:-}}"
PROJECT_ONLY_NAME="${PROJECT_ONLY_NAME:-}"

BUILD_ROOT="${BUILD_ROOT:-$PROJECT_ROOT/builds/ipad/xcode}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$PROJECT_ROOT/builds/ipad/DerivedData}"
APP_OUTPUT_PATH="${APP_OUTPUT_PATH:-$PROJECT_ROOT/builds/ipad/GodotXRFoundation.app}"
SCHEME="${SCHEME:-}"
TARGET_NAME="${TARGET_NAME:-}"
CONFIGURATION="${CONFIGURATION:-Debug}"
ALLOW_PROVISIONING_UPDATES="${ALLOW_PROVISIONING_UPDATES:-1}"
TEAM_ID="${TEAM_ID:-${DEVELOPMENT_TEAM:-${IPAD_TEAM_ID:-${APPLE_TEAM_ID:-}}}}"
BUNDLE_ID="${BUNDLE_ID:-${PACKAGE:-org.godotengine.godotxrfoundation}}"
CODE_SIGN_STYLE="${CODE_SIGN_STYLE:-Automatic}"
CODE_SIGNING_ALLOWED="${CODE_SIGNING_ALLOWED:-}"
IOS_BUILD_PLATFORM="${IOS_BUILD_PLATFORM:-ios}"
IOS_DESTINATION="${IOS_DESTINATION:-}"
IOS_SIMULATOR_ARCHS="${IOS_SIMULATOR_ARCHS:-auto}"

usage() {
	cat <<EOF
Usage:
  tools/c00/build_ios_xcode_project.sh [export-zip-or-dir] [ipad-device-id]

Environment:
  BUILD_ROOT                     Where an exported zip is unpacked. Default: builds/ipad/xcode.
  DERIVED_DATA_PATH              xcodebuild DerivedData path. Default: builds/ipad/DerivedData.
  APP_OUTPUT_PATH                Stable .app output path. Default: builds/ipad/GodotXRFoundation.app.
  SCHEME                         Optional Xcode scheme. Auto-detected when empty.
  TARGET_NAME                    Optional Xcode target fallback when no scheme exists.
  CONFIGURATION                  Debug | Release. Default: Debug.
  TEAM_ID / DEVELOPMENT_TEAM     Optional Apple team id passed to xcodebuild.
  IPAD_TEAM_ID / APPLE_TEAM_ID   Optional aliases for device-machine iPad signing.
  BUNDLE_ID / PACKAGE            Optional bundle id override.
  CODE_SIGN_STYLE                Default: Automatic.
  CODE_SIGNING_ALLOWED           Optional xcodebuild override, useful as NO for Simulator.
  IOS_BUILD_PLATFORM             ios | simulator. Default: ios.
  IOS_DESTINATION                Optional full xcodebuild destination override.
  IOS_SIMULATOR_ARCHS            auto | arm64 | x86_64 | "arm64 x86_64". Default: auto.
  ALLOW_PROVISIONING_UPDATES     Pass -allowProvisioningUpdates when 1. Default: 1.

This script builds the Xcode project produced by the Godot iOS export preset and
copies the resulting .app to a stable path for collect_ios_smoke.sh.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
	usage
	exit 0
fi

project_path() {
	local path="$1"
	case "$path" in
		/*) printf "%s\n" "$path" ;;
		*) printf "%s/%s\n" "$PROJECT_ROOT" "$path" ;;
	esac
}

EXPORT_INPUT="$(project_path "$EXPORT_INPUT")"
BUILD_ROOT="$(project_path "$BUILD_ROOT")"
DERIVED_DATA_PATH="$(project_path "$DERIVED_DATA_PATH")"
APP_OUTPUT_PATH="$(project_path "$APP_OUTPUT_PATH")"

for tool in xcodebuild xcrun node unzip; do
	if ! command -v "$tool" >/dev/null 2>&1; then
		echo "ERROR: Missing required tool: $tool" >&2
		exit 2
	fi
done

if [[ ! -e "$EXPORT_INPUT" ]]; then
	case "$EXPORT_INPUT" in
		*.zip)
			project_only_root="$(dirname "$EXPORT_INPUT")"
			project_only_name="$(basename "$EXPORT_INPUT" .zip)"
			if [[ -d "$project_only_root/$project_only_name.xcodeproj" ]]; then
				echo "iOS export zip not found; using project-only export directory: $project_only_root"
				EXPORT_INPUT="$project_only_root"
				PROJECT_ONLY_NAME="$project_only_name"
			else
				echo "ERROR: iOS export input does not exist: $EXPORT_INPUT" >&2
				exit 2
			fi
			;;
		*)
			echo "ERROR: iOS export input does not exist: $EXPORT_INPUT" >&2
			exit 2
			;;
	esac
fi

SOURCE_DIR="$EXPORT_INPUT"
if [[ -f "$EXPORT_INPUT" ]]; then
	case "$EXPORT_INPUT" in
		*.zip)
			PROJECT_ONLY_NAME="${PROJECT_ONLY_NAME:-$(basename "$EXPORT_INPUT" .zip)}"
			SOURCE_DIR="$BUILD_ROOT/exported"
			rm -rf "$SOURCE_DIR"
			mkdir -p "$SOURCE_DIR"
			echo "Unpacking iOS export: $EXPORT_INPUT -> $SOURCE_DIR"
			unzip -q "$EXPORT_INPUT" -d "$SOURCE_DIR"
			;;
		*)
			echo "ERROR: iOS export input must be a .zip file or an unpacked directory: $EXPORT_INPUT" >&2
			exit 2
			;;
	esac
fi

if [[ ! -d "$SOURCE_DIR" ]]; then
	echo "ERROR: iOS export source is not a directory: $SOURCE_DIR" >&2
	exit 2
fi

if [[ -z "$PROJECT_ONLY_NAME" ]]; then
	source_parent="$(dirname "$SOURCE_DIR")"
	source_name="$(basename "$SOURCE_DIR")"
	if [[ -d "$source_parent/$source_name.xcodeproj" ]]; then
		PROJECT_ONLY_NAME="$source_name"
		SOURCE_DIR="$source_parent"
	fi
fi

if [[ -n "$PROJECT_ONLY_NAME" ]]; then
	XCODE_PROJECT="$SOURCE_DIR/$PROJECT_ONLY_NAME.xcodeproj"
	if [[ ! -d "$XCODE_PROJECT" ]]; then
		echo "ERROR: Expected project-only Xcode project not found: $XCODE_PROJECT" >&2
		exit 1
	fi
else
	XCODE_PROJECT="$(find "$SOURCE_DIR" -name "*.xcodeproj" -type d | sort | head -n 1 || true)"
fi
if [[ -z "$XCODE_PROJECT" ]]; then
	echo "ERROR: No .xcodeproj found in: $SOURCE_DIR" >&2
	exit 1
fi

patch_simulator_project_if_needed() {
	if [[ "$IOS_BUILD_PLATFORM" != "simulator" ]]; then
		return
	fi

	local simulator_sdk
	simulator_sdk="$(xcrun --sdk iphonesimulator --show-sdk-path)"
	if [[ -d "$simulator_sdk/System/Library/Frameworks/MetalFX.framework" ]]; then
		return
	fi

	local pbxproj="$XCODE_PROJECT/project.pbxproj"
	if [[ ! -f "$pbxproj" ]]; then
		return
	fi
	if ! grep -q "MetalFX.framework" "$pbxproj"; then
		return
	fi

	echo "iOS Simulator SDK does not include MetalFX.framework; removing weak MetalFX reference from exported project."
	node - "$pbxproj" <<'NODE'
const fs = require("fs");
const file = process.argv[2];
const before = fs.readFileSync(file, "utf8");
const after = before
	.split(/\r?\n/)
	.filter((line) => !line.includes("MetalFX.framework"))
	.join("\n")
	.replace(/\n*$/, "\n");
fs.writeFileSync(file, after, "utf8");
NODE
}

patch_simulator_project_if_needed

echo "Checking exported iOS project for ARKit plugin references..."
if [[ -n "$PROJECT_ONLY_NAME" && -d "$SOURCE_DIR/$PROJECT_ONLY_NAME" ]]; then
	node "$PROJECT_ROOT/tools/c00/check_ios_export_project.js" --input "$SOURCE_DIR/$PROJECT_ONLY_NAME"
else
	node "$PROJECT_ROOT/tools/c00/check_ios_export_project.js" --input "$SOURCE_DIR"
fi

LIST_JSON="$BUILD_ROOT/xcodebuild-list.json"
mkdir -p "$BUILD_ROOT"
xcodebuild -list -json -project "$XCODE_PROJECT" > "$LIST_JSON"

if [[ -z "$SCHEME" ]]; then
	SCHEME="$(node -e 'const fs=require("fs"); const data=JSON.parse(fs.readFileSync(process.argv[1], "utf8")); const schemes=(data.project && data.project.schemes) || []; if (!schemes.length) process.exit(1); process.stdout.write(schemes[0]);' "$LIST_JSON" || true)"
fi

if [[ -z "$SCHEME" && -z "$TARGET_NAME" ]]; then
	TARGET_NAME="$(node -e 'const fs=require("fs"); const data=JSON.parse(fs.readFileSync(process.argv[1], "utf8")); const targets=(data.project && data.project.targets) || []; if (!targets.length) process.exit(1); process.stdout.write(targets[0]);' "$LIST_JSON" || true)"
fi

if [[ -z "$SCHEME" && -z "$TARGET_NAME" ]]; then
	echo "ERROR: Could not auto-detect an Xcode scheme or target. Set SCHEME=<name> or TARGET_NAME=<name> and retry." >&2
	exit 1
fi

case "$IOS_BUILD_PLATFORM" in
	ios|simulator)
		;;
	*)
		echo "ERROR: IOS_BUILD_PLATFORM must be ios or simulator." >&2
		exit 2
		;;
esac

if [[ -n "$IOS_DESTINATION" ]]; then
	DESTINATION="$IOS_DESTINATION"
elif [[ "$IOS_BUILD_PLATFORM" == "simulator" ]]; then
	DESTINATION="generic/platform=iOS Simulator"
else
	DESTINATION="generic/platform=iOS"
fi
if [[ "$IOS_BUILD_PLATFORM" == "ios" && -n "$DEVICE" ]]; then
	DESTINATION="platform=iOS,id=$DEVICE"
fi

XCODE_ARGS=(
	-project "$XCODE_PROJECT"
	-configuration "$CONFIGURATION"
	-destination "$DESTINATION"
	-derivedDataPath "$DERIVED_DATA_PATH"
)

if [[ -n "$SCHEME" ]]; then
	XCODE_ARGS+=(-scheme "$SCHEME")
else
	XCODE_ARGS+=(-target "$TARGET_NAME")
fi

if [[ "$ALLOW_PROVISIONING_UPDATES" == "1" ]]; then
	XCODE_ARGS+=(-allowProvisioningUpdates)
fi

detect_simulator_godot_archs() {
	local xcframework="" lib="" info="" candidate="" library_id=""
	for candidate in "$SOURCE_DIR"/*.xcframework "$SOURCE_DIR"/*/*.xcframework; do
		if [[ -d "$candidate" ]]; then
			if [[ -f "$candidate/ios-arm64/libgodot.a" || -f "$candidate/ios-arm64_x86_64-simulator/libgodot.a" ]]; then
				xcframework="$candidate"
				break
			fi
		fi
	done
	if [[ -z "$xcframework" ]]; then
		return 1
	fi
	for candidate in "$xcframework"/*/libgodot.a; do
		if [[ ! -f "$candidate" ]]; then
			continue
		fi
		library_id="$(basename "$(dirname "$candidate")")"
		if [[ "$library_id" == *simulator* ]]; then
			lib="$candidate"
			break
		fi
	done
	if [[ -z "$lib" ]]; then
		return 1
	fi
	info="$(lipo -info "$lib" 2>/dev/null || true)"
	case "$info" in
		*"are:"*)
			printf "%s" "${info##*are: }"
			;;
		*"architecture:"*)
			printf "%s" "${info##*architecture: }"
			;;
		*)
			return 1
			;;
	esac
}

BUILD_SETTINGS=()
if [[ -n "$TEAM_ID" ]]; then
	BUILD_SETTINGS+=("DEVELOPMENT_TEAM=$TEAM_ID")
fi
if [[ -n "$BUNDLE_ID" ]]; then
	BUILD_SETTINGS+=("PRODUCT_BUNDLE_IDENTIFIER=$BUNDLE_ID")
fi
if [[ -n "$CODE_SIGN_STYLE" ]]; then
	BUILD_SETTINGS+=("CODE_SIGN_STYLE=$CODE_SIGN_STYLE")
fi
if [[ -n "$CODE_SIGNING_ALLOWED" ]]; then
	BUILD_SETTINGS+=("CODE_SIGNING_ALLOWED=$CODE_SIGNING_ALLOWED")
fi
if [[ "$IOS_BUILD_PLATFORM" == "simulator" ]]; then
	BUILD_SETTINGS+=("SDKROOT=iphonesimulator")
	if [[ "$IOS_SIMULATOR_ARCHS" == "auto" ]]; then
		if simulator_archs="$(detect_simulator_godot_archs)"; then
			echo "Detected Godot iOS Simulator template architectures: $simulator_archs"
			BUILD_SETTINGS+=("ARCHS=$simulator_archs" "VALID_ARCHS=$simulator_archs")
		fi
	elif [[ -n "$IOS_SIMULATOR_ARCHS" ]]; then
		BUILD_SETTINGS+=("ARCHS=$IOS_SIMULATOR_ARCHS" "VALID_ARCHS=$IOS_SIMULATOR_ARCHS")
	fi
fi

echo "Building iOS app"
echo "Project: $XCODE_PROJECT"
if [[ -n "$SCHEME" ]]; then
	echo "Scheme: $SCHEME"
else
	echo "Target: $TARGET_NAME"
fi
echo "Destination: $DESTINATION"
echo "Build platform: $IOS_BUILD_PLATFORM"
xcodebuild "${XCODE_ARGS[@]}" build "${BUILD_SETTINGS[@]}"

APP_FOUND="$(find "$DERIVED_DATA_PATH/Build/Products" -name "*.app" -type d | sort | head -n 1 || true)"
if [[ -z "$APP_FOUND" ]]; then
	echo "ERROR: xcodebuild finished but no .app was found in $DERIVED_DATA_PATH/Build/Products." >&2
	exit 1
fi

rm -rf "$APP_OUTPUT_PATH"
mkdir -p "$(dirname "$APP_OUTPUT_PATH")"
if command -v ditto >/dev/null 2>&1; then
	ditto "$APP_FOUND" "$APP_OUTPUT_PATH"
else
	cp -R "$APP_FOUND" "$APP_OUTPUT_PATH"
fi

echo "Built app: $APP_OUTPUT_PATH"
