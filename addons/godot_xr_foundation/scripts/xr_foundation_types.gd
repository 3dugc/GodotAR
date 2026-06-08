extends RefCounted
class_name XRFoundationTypes

enum Backend {
	AUTO,
	EDITOR_SIM,
	OPENXR,
	ARCORE,
	ARKIT,
}

enum SessionState {
	STOPPED,
	STARTING,
	RUNNING,
	FAILED,
}

enum TrackingState {
	NONE,
	LIMITED,
	TRACKING,
}

enum TrackableType {
	UNKNOWN,
	PLANE,
	POINT,
	DEPTH,
	FEATURE_POINT,
	IMAGE,
	ANCHOR,
}


static func backend_to_string(backend: int) -> StringName:
	match backend:
		Backend.EDITOR_SIM:
			return &"EditorSim"
		Backend.OPENXR:
			return &"OpenXR"
		Backend.ARCORE:
			return &"ARCore"
		Backend.ARKIT:
			return &"ARKit"
		_:
			return &"Auto"


static func backend_from_string(value: String) -> int:
	match value.strip_edges().to_lower():
		"editor", "editorsim", "editor_sim", "simulation", "sim":
			return Backend.EDITOR_SIM
		"openxr", "rokid", "androidxr", "android_xr":
			return Backend.OPENXR
		"arcore", "android_ar", "androidar":
			return Backend.ARCORE
		"arkit", "ios_ar", "iosar":
			return Backend.ARKIT
		_:
			return Backend.AUTO


static func tracking_status_to_state(status: int) -> int:
	match status:
		XRInterface.XR_NORMAL_TRACKING:
			return TrackingState.TRACKING
		XRInterface.XR_EXCESSIVE_MOTION, XRInterface.XR_INSUFFICIENT_FEATURES, XRInterface.XR_UNKNOWN_TRACKING:
			return TrackingState.LIMITED
		_:
			return TrackingState.NONE

