extends Resource
class_name XRInputProfile

enum InputMode {
	GAZE = 1,
	RAY = 2,
	CONTROLLER = 4,
	HAND = 8,
}

@export var primary_mode := "gaze"
@export var modes: Array[String] = []
@export var select_action: StringName = &"xr_select"
@export var activate_action: StringName = &"xr_activate"
@export var source := "capability_report"


func configure_from_capabilities(capabilities: Dictionary) -> void:
	modes.clear()
	if bool(capabilities.get("input_ray", false)) or bool(capabilities.get("raycast", false)):
		modes.append("ray")
	if bool(capabilities.get("hand_tracking", false)) or bool(capabilities.get("openxr_interface", false)):
		modes.append("controller")
	if bool(capabilities.get("hand_tracking", false)):
		modes.append("hand")
	if modes.is_empty() or bool(capabilities.get("gaze", true)):
		modes.append("gaze")
	primary_mode = modes[0] if not modes.is_empty() else "gaze"


func to_dictionary() -> Dictionary:
	return {
		"primary": primary_mode,
		"modes": modes.duplicate(),
		"select_action": String(select_action),
		"activate_action": String(activate_action),
		"source": source,
	}


static func describe_from_capabilities(capabilities: Dictionary) -> Dictionary:
	var detected_modes: Array[String] = []
	if bool(capabilities.get("input_ray", false)) or bool(capabilities.get("raycast", false)):
		detected_modes.append("ray")
	if bool(capabilities.get("hand_tracking", false)) or bool(capabilities.get("openxr_interface", false)):
		detected_modes.append("controller")
	if bool(capabilities.get("hand_tracking", false)):
		detected_modes.append("hand")
	if detected_modes.is_empty() or bool(capabilities.get("gaze", true)):
		detected_modes.append("gaze")
	return {
		"primary": detected_modes[0] if not detected_modes.is_empty() else "gaze",
		"modes": detected_modes,
		"select_action": "xr_select",
		"activate_action": "xr_activate",
		"source": "capability_report",
	}
