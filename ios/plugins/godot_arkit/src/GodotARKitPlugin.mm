#include "GodotARKitPlugin.h"

#import "GodotARKitSession.h"

#import <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>

#if VERSION_MAJOR == 4
#include "core/config/engine.h"
#include "servers/xr/xr_interface.h"
#define GODOT_AR_STATE_NORMAL_TRACKING XRInterface::XR_NORMAL_TRACKING
#define GODOT_AR_STATE_UNKNOWN_TRACKING XRInterface::XR_UNKNOWN_TRACKING
#define GODOT_AR_STATE_NOT_TRACKING XRInterface::XR_NOT_TRACKING
#else
#include "core/engine.h"
#include "servers/arvr/arvr_interface.h"
#define GODOT_AR_STATE_NORMAL_TRACKING ARVRInterface::ARVR_NORMAL_TRACKING
#define GODOT_AR_STATE_UNKNOWN_TRACKING ARVRInterface::ARVR_UNKNOWN_TRACKING
#define GODOT_AR_STATE_NOT_TRACKING ARVRInterface::ARVR_NOT_TRACKING
#endif

static GodotARKitPlugin *godot_arkit_singleton = nullptr;
static GodotARKitPlugin *godot_arkit_engine_singleton = nullptr;

static GodotARKitSession *get_session(void *p_session) {
	return (__bridge GodotARKitSession *)p_session;
}

static String ns_string_to_godot(NSString *p_value) {
	if (p_value == nil) {
		return String();
	}
	return String::utf8([p_value UTF8String]);
}

GodotARKitPlugin *GodotARKitPlugin::get_singleton() {
	return godot_arkit_singleton;
}

void GodotARKitPlugin::_bind_methods() {
	ClassDB::bind_method(D_METHOD("initialize"), &GodotARKitPlugin::initialize);
	ClassDB::bind_method(D_METHOD("start_session"), &GodotARKitPlugin::start_session);
	ClassDB::bind_method(D_METHOD("stop_session"), &GodotARKitPlugin::stop_session);
	ClassDB::bind_method(D_METHOD("pause"), &GodotARKitPlugin::pause);
	ClassDB::bind_method(D_METHOD("resume"), &GodotARKitPlugin::resume);
	ClassDB::bind_method(D_METHOD("is_running"), &GodotARKitPlugin::is_running);
	ClassDB::bind_method(D_METHOD("get_tracking_status"), &GodotARKitPlugin::get_tracking_status);

	ClassDB::bind_method(D_METHOD("check_availability"), &GodotARKitPlugin::check_availability);
	ClassDB::bind_method(D_METHOD("get_capabilities"), &GodotARKitPlugin::get_capabilities);
	ClassDB::bind_method(D_METHOD("hit_test", "origin", "direction", "max_distance"), &GodotARKitPlugin::hit_test);
	ClassDB::bind_method(D_METHOD("create_anchor", "transform", "attached_trackable"), &GodotARKitPlugin::create_anchor, DEFVAL(Variant()));
	ClassDB::bind_method(D_METHOD("get_planes"), &GodotARKitPlugin::get_planes);
}

bool GodotARKitPlugin::initialize() {
	GodotARKitSession *arkit_session = get_session(session);
	return arkit_session != nil && [arkit_session isSupported];
}

bool GodotARKitPlugin::start_session() {
	GodotARKitSession *arkit_session = get_session(session);
	return arkit_session != nil && [arkit_session start];
}

bool GodotARKitPlugin::stop_session() {
	GodotARKitSession *arkit_session = get_session(session);
	return arkit_session != nil && [arkit_session stop];
}

bool GodotARKitPlugin::pause() {
	return stop_session();
}

bool GodotARKitPlugin::resume() {
	return start_session();
}

bool GodotARKitPlugin::is_running() {
	GodotARKitSession *arkit_session = get_session(session);
	return arkit_session != nil && [arkit_session isRunning];
}

int GodotARKitPlugin::get_tracking_status() {
	GodotARKitSession *arkit_session = get_session(session);
	if (arkit_session == nil) {
		return GODOT_AR_STATE_NOT_TRACKING;
	}

	switch ([arkit_session trackingStatus]) {
		case 2:
			return GODOT_AR_STATE_NORMAL_TRACKING;
		case 1:
			return GODOT_AR_STATE_UNKNOWN_TRACKING;
		case 0:
		default:
			return GODOT_AR_STATE_NOT_TRACKING;
	}
}

Dictionary GodotARKitPlugin::check_availability() {
	GodotARKitSession *arkit_session = get_session(session);
	const bool supported = arkit_session != nil && [arkit_session isSupported];

	Dictionary report;
	report["supported"] = supported;
	report["availability"] = supported ? String("Supported") : String("Unsupported");
	report["native_plugin"] = true;
	report["provider_source"] = String("GodotARKit singleton");
	report["runtime"] = String("ARKit");
	return report;
}

Dictionary GodotARKitPlugin::get_capabilities() {
	GodotARKitSession *arkit_session = get_session(session);
	const bool supported = arkit_session != nil && [arkit_session isSupported];

	Dictionary capabilities;
	capabilities["session"] = supported;
	capabilities["tracking"] = supported;
	capabilities["camera_background"] = supported;
	capabilities["passthrough"] = supported;
	capabilities["raycast"] = supported;
	capabilities["plane_detection"] = supported;
	capabilities["anchors"] = supported;
	capabilities["persistent_anchors"] = false;
	capabilities["light_estimation"] = false;
	capabilities["depth"] = false;
	capabilities["image_tracking"] = false;
	capabilities["native_plugin"] = true;
	capabilities["ar_product_path"] = supported;
	capabilities["runtime"] = String("ARKit");

	if (arkit_session != nil) {
		NSDictionary *native_capabilities = [arkit_session capabilities];
		capabilities["arkit_supported"] = [native_capabilities[@"arkit_supported"] boolValue];
		capabilities["arkit_running"] = [native_capabilities[@"arkit_running"] boolValue];
		capabilities["arkit_tracking_status"] = [native_capabilities[@"arkit_tracking_status"] integerValue];
		capabilities["arkit_tracking_state"] = ns_string_to_godot(native_capabilities[@"arkit_tracking_state"]);
		capabilities["arkit_tracking_reason"] = ns_string_to_godot(native_capabilities[@"arkit_tracking_reason"]);
	}

	return capabilities;
}

Array GodotARKitPlugin::hit_test(const Vector3 &p_origin, const Vector3 &p_direction, double p_max_distance) {
	(void)p_origin;
	(void)p_direction;
	(void)p_max_distance;

	Array hits;
	return hits;
}

Dictionary GodotARKitPlugin::create_anchor(const Transform3D &p_transform, Variant p_attached_trackable) {
	(void)p_attached_trackable;

	NSString *native_id = [NSString stringWithFormat:@"arkit_anchor_%f", NSDate.date.timeIntervalSince1970];

	Dictionary anchor;
	anchor["trackable_id"] = ns_string_to_godot(native_id);
	anchor["transform"] = p_transform;
	anchor["runtime"] = String("ARKit");
	return anchor;
}

Array GodotARKitPlugin::get_planes() {
	Array planes;
	return planes;
}

GodotARKitPlugin::GodotARKitPlugin() {
	godot_arkit_singleton = this;
	session = (__bridge_retained void *)[GodotARKitSession new];
}

GodotARKitPlugin::~GodotARKitPlugin() {
	if (session != nullptr) {
		CFRelease(session);
		session = nullptr;
	}
	godot_arkit_singleton = nullptr;
}

extern "C" void init_godot_arkit() {
	if (godot_arkit_engine_singleton != nullptr) {
		return;
	}

	ClassDB::register_class<GodotARKitPlugin>();
	godot_arkit_engine_singleton = memnew(GodotARKitPlugin);
	Engine::get_singleton()->add_singleton(Engine::Singleton("GodotARKit", godot_arkit_engine_singleton));
}

extern "C" void deinit_godot_arkit() {
	if (godot_arkit_engine_singleton != nullptr) {
		memdelete(godot_arkit_engine_singleton);
		godot_arkit_engine_singleton = nullptr;
	}
}
