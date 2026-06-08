extends XRSessionManager
class_name ARSession

enum TrackingMode {
	DEFAULT,
	POSITION_AND_ROTATION,
	ROTATION_ONLY,
}

@export var attempt_install_on_start := false
@export var requested_tracking_mode := TrackingMode.POSITION_AND_ROTATION


static func CheckAvailability(requested_backend: int = XRFoundationTypes.Backend.AUTO, options: Dictionary = {}) -> Dictionary:
	return XRFoundation.check_availability(requested_backend, options)


static func Install(requested_backend: int = XRFoundationTypes.Backend.AUTO, options: Dictionary = {}) -> bool:
	return XRFoundation.install(requested_backend, options)


static func state() -> int:
	return XRFoundation.get_ar_session_state()


static func state_name() -> StringName:
	return XRFoundation.get_ar_session_state_name()


static func foundation_state() -> int:
	return XRFoundation.state


static func notTrackingReason() -> int:
	return XRFoundation.get_not_tracking_reason()


static func not_tracking_reason() -> int:
	return XRFoundation.get_not_tracking_reason()


static func not_tracking_reason_name() -> StringName:
	return XRFoundation.get_not_tracking_reason_name()


static func GetARSessionState() -> int:
	return state()


static func GetARSessionStateName() -> StringName:
	return state_name()


static func GetState() -> int:
	return state()


static func GetStateName() -> StringName:
	return state_name()


static func GetFoundationState() -> int:
	return foundation_state()


static func GetNotTrackingReason() -> int:
	return not_tracking_reason()


static func GetNotTrackingReasonName() -> StringName:
	return not_tracking_reason_name()


func _ready() -> void:
	if attempt_install_on_start:
		install()
	super._ready()


func get_requested_tracking_mode() -> int:
	return requested_tracking_mode


func set_requested_tracking_mode(value: int) -> void:
	requested_tracking_mode = value


func get_current_tracking_mode() -> int:
	return requested_tracking_mode


func set_match_frame_rate(value: bool) -> void:
	match_frame_rate = value
	match_frame_rate_requested = value


func get_match_frame_rate() -> bool:
	return match_frame_rate_requested or match_frame_rate


func Reset() -> bool:
	return reset()


func CheckAvailabilityInstance() -> Dictionary:
	return check_availability()
