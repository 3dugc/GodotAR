extends Node
class_name XRSessionManager

@export_enum("Auto", "Editor Simulation", "OpenXR / Rokid", "ARCore", "ARKit") var requested_backend := XRFoundationTypes.Backend.AUTO
@export var auto_start := true
@export var platform_hint := ""
@export var prefer_ar := true
@export var passthrough := true
@export var fallback_to_editor_sim := true
@export var disable_vsync := true
@export var simulated_floor_height := 0.0
@export var simulated_plane_size := Vector2(5.0, 5.0)


func _ready() -> void:
	if auto_start:
		call_deferred("start")


func start() -> bool:
	var options := {
		"platform_hint": platform_hint,
		"prefer_ar": prefer_ar,
		"passthrough": passthrough,
		"fallback_to_editor_sim": fallback_to_editor_sim,
		"disable_vsync": disable_vsync,
		"simulated_floor_height": simulated_floor_height,
		"simulated_plane_size": simulated_plane_size,
	}
	return XRFoundation.start_session(requested_backend, options)


func stop() -> void:
	XRFoundation.stop_session()

