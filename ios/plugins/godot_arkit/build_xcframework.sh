#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_NAME="GodotARKit"
BUILD_DIR="$ROOT/.build"
OUT_XCFRAMEWORK="$ROOT/${PLUGIN_NAME}.xcframework"
OUT_GDIP="$ROOT/${PLUGIN_NAME}.gdip"
CLANG_MODULE_CACHE_DIR="${CLANG_MODULE_CACHE_DIR:-$BUILD_DIR/clang-module-cache}"

usage() {
	cat <<EOF
Build ${PLUGIN_NAME}.xcframework for the Godot iOS plugin path.

Usage:
  GODOT_SOURCE_DIR=/path/to/godot ${BASH_SOURCE[0]}

Environment:
  GODOT_SOURCE_DIR   Required. Godot source tree whose headers match the iOS export template.
  TARGET             debug | release | release_debug. Default: release_debug.
  IOS_MIN_VERSION    Minimum iOS deployment target. Default: 12.0.
  SIM_ARCHS          Simulator architectures. Default: "arm64 x86_64".
  GODOT_EXTRA_CFLAGS Extra compiler flags if your export template was built with custom flags.

Output:
  ${OUT_XCFRAMEWORK}
  ${OUT_GDIP}

Notes:
  This builds an iOS static-library xcframework plugin. It does not patch or rebuild Godot.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
	usage
	exit 0
fi

GODOT_SOURCE_DIR="${GODOT_SOURCE_DIR:-${GODOT_SRC_DIR:-}}"
TARGET="${TARGET:-release_debug}"
IOS_MIN_VERSION="${IOS_MIN_VERSION:-12.0}"
SIM_ARCHS="${SIM_ARCHS:-arm64 x86_64}"

if [[ -z "$GODOT_SOURCE_DIR" ]]; then
	usage
	echo
	echo "ERROR: GODOT_SOURCE_DIR is required." >&2
	exit 2
fi

if [[ ! -d "$GODOT_SOURCE_DIR" ]]; then
	echo "ERROR: GODOT_SOURCE_DIR does not exist: $GODOT_SOURCE_DIR" >&2
	exit 2
fi

GODOT_SOURCE_DIR="$(cd "$GODOT_SOURCE_DIR" && pwd)"

for required in \
	"$GODOT_SOURCE_DIR/core/version.h" \
	"$GODOT_SOURCE_DIR/core/object/class_db.h" \
	"$GODOT_SOURCE_DIR/core/config/engine.h" \
	"$GODOT_SOURCE_DIR/platform/ios"; do
	if [[ ! -e "$required" ]]; then
		echo "ERROR: Missing Godot header/path: $required" >&2
		echo "Use the same Godot source revision used to build your iOS export template." >&2
		exit 2
	fi
done

for tool in xcrun xcodebuild libtool; do
	if ! command -v "$tool" >/dev/null 2>&1; then
		echo "ERROR: Missing required tool: $tool" >&2
		exit 2
	fi
done

case "$TARGET" in
	debug|release|release_debug)
		;;
	*)
		echo "ERROR: TARGET must be debug, release, or release_debug." >&2
		exit 2
		;;
esac

target_flags() {
	case "$TARGET" in
		debug)
			printf "%s\n" -O0 -gdwarf-2 -DDEBUG_MEMORY_ALLOC -DDISABLE_FORCED_INLINE -D_DEBUG -DDEBUG=1 -DDEBUG_ENABLED
			;;
		release_debug)
			printf "%s\n" -O2 -ftree-vectorize -DNDEBUG -DNS_BLOCK_ASSERTIONS=1 -DDEBUG_ENABLED -fomit-frame-pointer
			;;
		release)
			printf "%s\n" -O2 -ftree-vectorize -DNDEBUG -DNS_BLOCK_ASSERTIONS=1 -fomit-frame-pointer
			;;
	esac
}

compile_library() {
	local sdk_name="$1"
	local arch="$2"
	local platform_label="$3"
	local min_flag="$4"
	local sdk_path
	sdk_path="$(xcrun --sdk "$sdk_name" --show-sdk-path)"

	local arch_build_dir="$BUILD_DIR/$platform_label/$arch"
	local module_cache_dir="$CLANG_MODULE_CACHE_DIR/$platform_label/$arch"
	mkdir -p "$arch_build_dir"
	mkdir -p "$module_cache_dir"

	local common_flags=(
		-std=gnu++17
		-fobjc-arc
		-fmodules
		-fmodules-cache-path="$module_cache_dir"
		-fcxx-modules
		-fblocks
		-fvisibility=hidden
		-fno-exceptions
		-fmessage-length=0
		-fno-strict-aliasing
		-Wall
		-Werror=return-type
		-arch "$arch"
		-isysroot "$sdk_path"
		"$min_flag"
		-DIOS_ENABLED
		-DUNIX_ENABLED
		-DCOREAUDIO_ENABLED
		-DVULKAN_ENABLED
		-DPTRCALL_ENABLED
		-DTYPED_METHOD_BIND
		-I"$ROOT/src"
		-I"$GODOT_SOURCE_DIR"
		-I"$GODOT_SOURCE_DIR/platform/ios"
	)

	local build_flags=()
	while IFS= read -r flag; do
		build_flags+=("$flag")
	done < <(target_flags)

	if [[ -n "${GODOT_EXTRA_CFLAGS:-}" ]]; then
		read -r -a extra_flags <<< "$GODOT_EXTRA_CFLAGS"
		common_flags+=("${extra_flags[@]}")
	fi

	local objects=()
	for source in "$ROOT/src/GodotARKitPlugin.mm" "$ROOT/src/GodotARKitSession.mm"; do
		local object="$arch_build_dir/$(basename "$source").o"
		echo "Compile $sdk_name $arch $(basename "$source")" >&2
		xcrun --sdk "$sdk_name" clang++ "${common_flags[@]}" "${build_flags[@]}" -c "$source" -o "$object" || return $?
		if [[ ! -s "$object" ]]; then
			echo "ERROR: Missing object after compile: $object" >&2
			return 1
		fi
		objects+=("$object")
	done

	local library="$BUILD_DIR/lib${PLUGIN_NAME}.${platform_label}.${arch}.${TARGET}.a"
	libtool -static -o "$library" "${objects[@]}" >&2
	if [[ ! -s "$library" ]]; then
		echo "ERROR: Missing library after archive: $library" >&2
		return 1
	fi
	printf "%s\n" "$library"
}

echo "Building $PLUGIN_NAME"
echo "Godot source: $GODOT_SOURCE_DIR"
echo "Target: $TARGET"
echo "iOS min: $IOS_MIN_VERSION"

rm -rf "$BUILD_DIR" "$OUT_XCFRAMEWORK"
mkdir -p "$BUILD_DIR"

device_library="$(compile_library iphoneos arm64 iphoneos "-miphoneos-version-min=${IOS_MIN_VERSION}")"

sim_libraries=()
for sim_arch in $SIM_ARCHS; do
	sim_libraries+=("$(compile_library iphonesimulator "$sim_arch" iphonesimulator "-mios-simulator-version-min=${IOS_MIN_VERSION}")")
done

simulator_library="$BUILD_DIR/lib${PLUGIN_NAME}.iphonesimulator.${TARGET}.a"
if [[ "${#sim_libraries[@]}" -eq 1 ]]; then
	cp "${sim_libraries[0]}" "$simulator_library"
else
	lipo -create "${sim_libraries[@]}" -output "$simulator_library"
fi

xcodebuild -create-xcframework \
	-library "$device_library" \
	-library "$simulator_library" \
	-output "$OUT_XCFRAMEWORK"

cp "$ROOT/${PLUGIN_NAME}.gdip.template" "$OUT_GDIP"

node "$ROOT/../../../tools/c00/check_ios_plugin_artifacts.js" \
	--file "$OUT_GDIP" \
	--require-binary

echo
echo "Created:"
echo "  $OUT_XCFRAMEWORK"
echo "  $OUT_GDIP"
