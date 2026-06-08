#ifndef GODOT_XR_FOUNDATION_ARKIT_PLUGIN_H
#define GODOT_XR_FOUNDATION_ARKIT_PLUGIN_H

#include "core/version.h"

#if VERSION_MAJOR == 4
#include "core/math/transform_3d.h"
#include "core/math/vector3.h"
#include "core/object/class_db.h"
#include "core/variant/array.h"
#include "core/variant/dictionary.h"
#include "core/variant/variant.h"
#else
#include "core/class_db.h"
#endif

class GodotARKitPlugin : public Object {
	GDCLASS(GodotARKitPlugin, Object);

	static void _bind_methods();

	void *session = nullptr;

public:
	static GodotARKitPlugin *get_singleton();

	bool initialize();
	bool start_session();
	bool stop_session();
	bool pause();
	bool resume();

	Dictionary check_availability();
	Dictionary get_capabilities();
	Array hit_test(const Vector3 &origin, const Vector3 &direction, double max_distance);
	Dictionary create_anchor(const Transform3D &transform, Variant attached_trackable = Variant());
	Array get_planes();

	GodotARKitPlugin();
	~GodotARKitPlugin();
};

void init_godot_arkit();
void deinit_godot_arkit();

#endif // GODOT_XR_FOUNDATION_ARKIT_PLUGIN_H
