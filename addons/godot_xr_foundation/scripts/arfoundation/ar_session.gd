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
	return XRFoundation.state


func _ready() -> void:
	if attempt_install_on_start:
		install()
	super._ready()


func Reset() -> bool:
	return reset()


func CheckAvailabilityInstance() -> Dictionary:
	return check_availability()
