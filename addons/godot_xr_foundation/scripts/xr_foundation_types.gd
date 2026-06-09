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

const TRACKABLE_TYPE_ALL := 0xffffffff
const TRACKABLE_TYPE_PLANES := 1 << TrackableType.PLANE
const TRACKABLE_TYPE_POINTS := (1 << TrackableType.POINT) | (1 << TrackableType.FEATURE_POINT)
const TRACKABLE_TYPE_FEATURE_POINT := 1 << TrackableType.FEATURE_POINT
const TRACKABLE_TYPE_ANCHOR := 1 << TrackableType.ANCHOR

enum PlaneDetectionMode {
	NONE,
	HORIZONTAL,
	VERTICAL,
	NOT_AXIS_ALIGNED,
	EVERYTHING,
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


static func plane_detection_mode_from_string(value: String, fallback: int = PlaneDetectionMode.EVERYTHING) -> int:
	match value.strip_edges().to_lower():
		"none", "nothing", "disabled", "off":
			return PlaneDetectionMode.NONE
		"horizontal", "horizontal_plane", "horizontal_planes":
			return PlaneDetectionMode.HORIZONTAL
		"vertical", "vertical_plane", "vertical_planes":
			return PlaneDetectionMode.VERTICAL
		"notaxisaligned", "not_axis_aligned", "arbitrary", "any_alignment":
			return PlaneDetectionMode.NOT_AXIS_ALIGNED
		"everything", "all", "any":
			return PlaneDetectionMode.EVERYTHING
		_:
			return fallback


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


static func not_tracking_reason_from_string(value: String) -> int:
	var normalized := value.strip_edges().to_lower().replace(" ", "_").replace("-", "_")
	match normalized:
		"", "none", "normal", "tracking", "normal_tracking":
			return NotTrackingReason.NONE
		"initializing", "initialization", "limited", "not_running", "stopped", "waiting_for_frame", "unknown_tracking":
			return NotTrackingReason.INITIALIZING
		"relocalizing", "relocalization":
			return NotTrackingReason.RELOCALIZING
		"excessive_motion", "excessivemotion":
			return NotTrackingReason.EXCESSIVE_MOTION
		"insufficient_features", "insufficientfeatures":
			return NotTrackingReason.INSUFFICIENT_FEATURES
		"insufficient_light", "insufficientlight":
			return NotTrackingReason.INSUFFICIENT_LIGHT
		"unsupported":
			return NotTrackingReason.UNSUPPORTED
		"not_available", "notavailable", "unavailable", "unknown":
			return NotTrackingReason.UNKNOWN
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


static func trackable_type_from_variant(value: Variant, fallback: int = TrackableType.UNKNOWN) -> int:
	if typeof(value) == TYPE_INT:
		return int(value)
	return trackable_type_from_string(String(value), fallback)


static func trackable_type_mask_from_variant(value: Variant, fallback: int = TRACKABLE_TYPE_ALL) -> int:
	if typeof(value) == TYPE_INT:
		return int(value)
	return trackable_type_mask_from_string(String(value), fallback)


static func trackable_type_from_string(value: String, fallback: int = TrackableType.UNKNOWN) -> int:
	match value.strip_edges().to_lower().replace(" ", "_").replace("-", "_"):
		"plane", "planes", "estimated_plane", "existing_plane", "plane_within_polygon":
			return TrackableType.PLANE
		"point", "points":
			return TrackableType.POINT
		"depth":
			return TrackableType.DEPTH
		"feature_point", "feature_points":
			return TrackableType.FEATURE_POINT
		"image", "images", "tracked_image":
			return TrackableType.IMAGE
		"anchor", "anchors":
			return TrackableType.ANCHOR
		"", "unknown":
			return fallback
		_:
			return fallback


static func trackable_type_mask_from_string(value: String, fallback: int = TRACKABLE_TYPE_ALL) -> int:
	var normalized := value.strip_edges().to_lower().replace(" ", "_").replace("-", "_")
	match normalized:
		"", "all", "everything", "any":
			return TRACKABLE_TYPE_ALL
		"plane", "planes", "estimated_plane", "existing_plane", "plane_within_polygon", "plane_within_bounds":
			return TRACKABLE_TYPE_PLANES
		"point", "points", "feature_point", "feature_points":
			return TRACKABLE_TYPE_POINTS
		"anchor", "anchors":
			return TRACKABLE_TYPE_ANCHOR
		_:
			if not normalized.contains("|") and not normalized.contains(","):
				return fallback
			var mask := 0
			var normalized_parts := normalized.replace(",", "|")
			for part in normalized_parts.split("|", false):
				var single := trackable_type_mask_from_string(part, 0)
				mask |= single
			return mask if mask != 0 else fallback
