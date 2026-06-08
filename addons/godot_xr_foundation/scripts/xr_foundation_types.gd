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

enum Availability {
	UNKNOWN,
	UNSUPPORTED,
	SUPPORTED,
	NEEDS_INSTALL,
	INSTALLED,
}

enum ARSessionState {
	NONE,
	UNSUPPORTED,
	CHECKING_AVAILABILITY,
	NEEDS_INSTALL,
	INSTALLING,
	READY,
	SESSION_INITIALIZING,
	SESSION_TRACKING,
}

enum TrackingState {
	NONE,
	LIMITED,
	TRACKING,
}

enum NotTrackingReason {
	NONE,
	INITIALIZING,
	RELOCALIZING,
	EXCESSIVE_MOTION,
	INSUFFICIENT_FEATURES,
	INSUFFICIENT_LIGHT,
	UNSUPPORTED,
	UNKNOWN,
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


static func session_state_to_string(session_state: int) -> StringName:
	match session_state:
		SessionState.STOPPED:
			return &"Stopped"
		SessionState.STARTING:
			return &"Starting"
		SessionState.RUNNING:
			return &"Running"
		SessionState.FAILED:
			return &"Failed"
		_:
			return &"Unknown"


static func availability_to_string(availability: int) -> StringName:
	match availability:
		Availability.UNSUPPORTED:
			return &"Unsupported"
		Availability.SUPPORTED:
			return &"Supported"
		Availability.NEEDS_INSTALL:
			return &"NeedsInstall"
		Availability.INSTALLED:
			return &"Installed"
		_:
			return &"Unknown"


static func ar_session_state_to_string(session_state: int) -> StringName:
	match session_state:
		ARSessionState.UNSUPPORTED:
			return &"Unsupported"
		ARSessionState.CHECKING_AVAILABILITY:
			return &"CheckingAvailability"
		ARSessionState.NEEDS_INSTALL:
			return &"NeedsInstall"
		ARSessionState.INSTALLING:
			return &"Installing"
		ARSessionState.READY:
			return &"Ready"
		ARSessionState.SESSION_INITIALIZING:
			return &"SessionInitializing"
		ARSessionState.SESSION_TRACKING:
			return &"SessionTracking"
		ARSessionState.NONE:
			return &"None"
		_:
			return &"Unknown"


static func ar_session_state_from_foundation_state(session_state: int, tracking_status: int = XRInterface.XR_UNKNOWN_TRACKING) -> int:
	match session_state:
		SessionState.RUNNING:
			if tracking_status == XRInterface.XR_NORMAL_TRACKING:
				return ARSessionState.SESSION_TRACKING
			return ARSessionState.SESSION_INITIALIZING
		SessionState.STARTING:
			return ARSessionState.SESSION_INITIALIZING
		SessionState.FAILED:
			return ARSessionState.UNSUPPORTED
		SessionState.STOPPED:
			return ARSessionState.READY
		_:
			return ARSessionState.NONE


static func tracking_status_to_state(status: int) -> int:
	match status:
		XRInterface.XR_NORMAL_TRACKING:
			return TrackingState.TRACKING
		XRInterface.XR_EXCESSIVE_MOTION, XRInterface.XR_INSUFFICIENT_FEATURES, XRInterface.XR_UNKNOWN_TRACKING:
			return TrackingState.LIMITED
		_:
			return TrackingState.NONE


static func tracking_state_to_string(tracking_state: int) -> StringName:
	match tracking_state:
		TrackingState.TRACKING:
			return &"Tracking"
		TrackingState.LIMITED:
			return &"Limited"
		TrackingState.NONE:
			return &"None"
		_:
			return &"Unknown"


static func tracking_status_to_string(status: int) -> StringName:
	return tracking_state_to_string(tracking_status_to_state(status))


static func not_tracking_reason_from_status(status: int) -> int:
	match status:
		XRInterface.XR_NORMAL_TRACKING:
			return NotTrackingReason.NONE
		XRInterface.XR_EXCESSIVE_MOTION:
			return NotTrackingReason.EXCESSIVE_MOTION
		XRInterface.XR_INSUFFICIENT_FEATURES:
			return NotTrackingReason.INSUFFICIENT_FEATURES
		XRInterface.XR_UNKNOWN_TRACKING:
			return NotTrackingReason.INITIALIZING
		_:
			return NotTrackingReason.UNKNOWN


static func not_tracking_reason_to_string(reason: int) -> StringName:
	match reason:
		NotTrackingReason.NONE:
			return &"None"
		NotTrackingReason.INITIALIZING:
			return &"Initializing"
		NotTrackingReason.RELOCALIZING:
			return &"Relocalizing"
		NotTrackingReason.EXCESSIVE_MOTION:
			return &"ExcessiveMotion"
		NotTrackingReason.INSUFFICIENT_FEATURES:
			return &"InsufficientFeatures"
		NotTrackingReason.INSUFFICIENT_LIGHT:
			return &"InsufficientLight"
		NotTrackingReason.UNSUPPORTED:
			return &"Unsupported"
		_:
			return &"Unknown"
