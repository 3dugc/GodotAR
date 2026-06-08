extends XROrigin3D
class_name XRDeviceRig

@export var center_on_start := false
@export var keep_height_on_recenter := true

@onready var xr_camera: XRCamera3D = $XRCamera3D
@onready var left_hand: XRController3D = $LeftHand
@onready var right_hand: XRController3D = $RightHand


func _ready() -> void:
	if not XRFoundation.session_started.is_connected(Callable(self, "_on_session_started")):
		XRFoundation.session_started.connect(_on_session_started)


func get_camera() -> XRCamera3D:
	return xr_camera


func recenter() -> void:
	if XRServer.primary_interface:
		XRServer.center_on_hmd(XRServer.RESET_BUT_KEEP_TILT, keep_height_on_recenter)


func _on_session_started(_backend: int, _display_name: StringName) -> void:
	if center_on_start:
		recenter()

