#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PLUGIN_ROOT="$ROOT/ios/plugins/godot_arkit"
SDK_NAME="${SDK_NAME:-iphonesimulator}"
IOS_MIN_VERSION="${IOS_MIN_VERSION:-12.0}"
KEEP_TEMP="${KEEP_TEMP:-0}"

usage() {
	cat <<EOF
Usage:
  tools/c00/check_arkit_plugin_static.sh

Environment:
  SDK_NAME          iphoneos | iphonesimulator. Default: iphonesimulator.
  IOS_MIN_VERSION   Minimum iOS version for syntax check. Default: 12.0.
  KEEP_TEMP         Keep generated stub headers when set to 1.

This is a C00 smoke check. It validates the ARKit plugin Objective-C++ sources
against the local iOS SDK with tiny Godot header stubs. It does not replace
ios/plugins/godot_arkit/build_xcframework.sh, which must still be run against
the real Godot source tree before iPad device gates.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
	usage
	exit 0
fi

case "$SDK_NAME" in
	iphoneos|iphonesimulator)
		;;
	*)
		echo "ERROR: SDK_NAME must be iphoneos or iphonesimulator." >&2
		exit 2
		;;
esac

for tool in xcrun mktemp; do
	if ! command -v "$tool" >/dev/null 2>&1; then
		echo "ERROR: Missing required tool: $tool" >&2
		exit 2
	fi
done

SDK_PATH="$(xcrun --sdk "$SDK_NAME" --show-sdk-path)"
CLANG="$(xcrun --find clang++)"
TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/godot-arkit-static.XXXXXX")"
STUB_ROOT="$TMP_DIR/godot_stubs"
MODULE_CACHE="$TMP_DIR/module_cache"

cleanup() {
	if [[ "$KEEP_TEMP" != "1" ]]; then
		rm -rf "$TMP_DIR"
	else
		echo "Kept temporary stubs at: $TMP_DIR"
	fi
}
trap cleanup EXIT

mkdir -p \
	"$STUB_ROOT/core/config" \
	"$STUB_ROOT/core/math" \
	"$STUB_ROOT/core/object" \
	"$STUB_ROOT/core/variant" \
	"$STUB_ROOT/servers/xr"

cat > "$STUB_ROOT/core/version.h" <<'EOF'
#ifndef GODOT_VERSION_STUB_H
#define GODOT_VERSION_STUB_H
#ifndef VERSION_MAJOR
#define VERSION_MAJOR 4
#endif
#endif
EOF

cat > "$STUB_ROOT/core/math/vector3.h" <<'EOF'
#ifndef GODOT_VECTOR3_STUB_H
#define GODOT_VECTOR3_STUB_H
struct Vector3 {
	double x = 0.0;
	double y = 0.0;
	double z = 0.0;
	Vector3() = default;
	Vector3(double p_x, double p_y, double p_z) :
			x(p_x), y(p_y), z(p_z) {}
};
#endif
EOF

cat > "$STUB_ROOT/core/math/vector2.h" <<'EOF'
#ifndef GODOT_VECTOR2_STUB_H
#define GODOT_VECTOR2_STUB_H
struct Vector2 {
	double x = 0.0;
	double y = 0.0;
	Vector2() = default;
	Vector2(double p_x, double p_y) :
			x(p_x), y(p_y) {}
};
#endif
EOF

cat > "$STUB_ROOT/core/math/transform_3d.h" <<'EOF'
#ifndef GODOT_TRANSFORM3D_STUB_H
#define GODOT_TRANSFORM3D_STUB_H
#include "core/math/vector3.h"
struct Basis {
	Vector3 x;
	Vector3 y;
	Vector3 z;
	Basis() = default;
	Basis(const Vector3 &p_x, const Vector3 &p_y, const Vector3 &p_z) :
			x(p_x), y(p_y), z(p_z) {}
};
struct Transform3D {
	Basis basis;
	Vector3 origin;
};
#endif
EOF

cat > "$STUB_ROOT/core/variant/variant.h" <<'EOF'
#ifndef GODOT_VARIANT_STUB_H
#define GODOT_VARIANT_STUB_H

class String {
public:
	String() = default;
	String(const char *) {}
	static String utf8(const char *) { return String(); }
};

class Variant {
public:
	Variant() = default;
	template <typename T>
	Variant(const T &) {}
};
#endif
EOF

cat > "$STUB_ROOT/core/variant/array.h" <<'EOF'
#ifndef GODOT_ARRAY_STUB_H
#define GODOT_ARRAY_STUB_H
class Array {
public:
	template <typename T>
	void push_back(const T &) {}
};
#endif
EOF

cat > "$STUB_ROOT/core/variant/dictionary.h" <<'EOF'
#ifndef GODOT_DICTIONARY_STUB_H
#define GODOT_DICTIONARY_STUB_H
class Dictionary {
public:
	class Slot {
	public:
		template <typename T>
		Slot &operator=(const T &) { return *this; }
	};
	Slot operator[](const char *) { return Slot(); }
};
#endif
EOF

cat > "$STUB_ROOT/core/object/class_db.h" <<'EOF'
#ifndef GODOT_CLASS_DB_STUB_H
#define GODOT_CLASS_DB_STUB_H
#include "core/variant/variant.h"

class Object {
public:
	virtual ~Object() = default;
};

#define GDCLASS(m_class, m_base)
#define D_METHOD(...) ""
#define DEFVAL(m_value) m_value
#define memnew(m_type) new m_type
#define memdelete(m_value) delete m_value

class ClassDB {
public:
	template <typename... Args>
	static void bind_method(Args...) {}

	template <typename T>
	static void register_class() {}
};
#endif
EOF

cat > "$STUB_ROOT/core/config/engine.h" <<'EOF'
#ifndef GODOT_ENGINE_STUB_H
#define GODOT_ENGINE_STUB_H
#include "core/object/class_db.h"

class Engine {
public:
	class Singleton {
	public:
		Singleton(const char *, Object *) {}
		Singleton(const String &, Object *) {}
	};

	static Engine *get_singleton() {
		static Engine engine;
		return &engine;
	}

	void add_singleton(const Singleton &) {}
};
#endif
EOF

cat > "$STUB_ROOT/servers/xr/xr_interface.h" <<'EOF'
#ifndef GODOT_XR_INTERFACE_STUB_H
#define GODOT_XR_INTERFACE_STUB_H
class XRInterface {
public:
	enum TrackingStatus {
		XR_NOT_TRACKING = 0,
		XR_NORMAL_TRACKING = 1,
		XR_UNKNOWN_TRACKING = 2,
	};
};
#endif
EOF

COMMON_FLAGS=(
	-std=gnu++17
	-fobjc-arc
	-fmodules
	-fcxx-modules
	-fmodules-cache-path="$MODULE_CACHE"
	-fblocks
	-fsyntax-only
	-Wall
	-Werror=return-type
	-isysroot "$SDK_PATH"
	-DIOS_ENABLED
	-DVERSION_MAJOR=4
	-I"$STUB_ROOT"
	-I"$PLUGIN_ROOT/src"
)

if [[ "$SDK_NAME" == "iphoneos" ]]; then
	COMMON_FLAGS+=(-miphoneos-version-min="$IOS_MIN_VERSION" -arch arm64)
else
	COMMON_FLAGS+=(-mios-simulator-version-min="$IOS_MIN_VERSION" -arch arm64)
fi

echo "ARKit plugin static check"
echo "SDK: $SDK_NAME"
echo "SDK path: $SDK_PATH"

for source in "$PLUGIN_ROOT/src/GodotARKitPlugin.mm" "$PLUGIN_ROOT/src/GodotARKitSession.mm"; do
	echo "Check $(basename "$source")"
	"$CLANG" "${COMMON_FLAGS[@]}" "$source"
done

echo "ARKit plugin static check passed."
