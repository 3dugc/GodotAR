extends Node
class_name XRSessionManager

@export_enum("Auto", "Editor Simulation", "OpenXR / Rokid", "ARCore", "ARKit") var requested_backend := XRFoundationTypes.Backend.AUTO
@export var auto_start := true
@export var platform_hint := ""
@export var prefer_ar := true
@export var passthrough := true
@export var fallback_to_editor_sim := true
@export var disable_vsync := true
@export var match_frame_rate := false
@export var match_frame_rate_requested := false
@export var simulated_floor_height := 0.0
@export var simulated_plane_size := Vector2(5.0, 5.0)


func _ready() -> void:
	if auto_start:
		call_deferred("start")


func start() -> bool:
	return XRFoundation.start_session(requested_backend, _build_options())


func stop() -> void:
	XRFoundation.stop_session()


func reset() -> bool:
	return XRFoundation.reset_session(requested_backend, _build_options())


func check_availability() -> Dictionary:
	return XRFoundation.check_availability(requested_backend, _build_options())


func install() -> bool:
	return XRFoundation.install(requested_backend, _build_options())


func get_state() -> int:
	return XRFoundation.state


func get_session_state_name() -> StringName:
	return XRFoundation.get_session_state_name()


func get_ar_session_state() -> int:
	return XRFoundation.get_ar_session_state()


func get_ar_session_state_name() -> StringName:
	return XRFoundation.get_ar_session_state_name()


func get_tracking_state() -> int:
	return XRFoundation.get_tracking_state()


func get_tracking_state_name() -> StringName:
	return XRFoundation.get_tracking_state_name()


func get_not_tracking_reason() -> int:
	return XRFoundation.get_not_tracking_reason()


func get_not_tracking_reason_name() -> StringName:
	return XRFoundation.get_not_tracking_reason_name()


func _build_options() -> Dictionary:
	return {
		"platform_hint": platform_hint,
		"prefer_ar": prefer_ar,
		"passthrough": passthrough,
		"fallback_to_editor_sim": fallback_to_editor_sim,
		"disable_vsync": disable_vsync,
		"match_frame_rate": match_frame_rate,
		"match_frame_rate_requested": match_frame_rate_requested or match_frame_rate,
		"simulated_floor_height": simulated_floor_height,
		"simulated_plane_size": simulated_plane_size,
	}
