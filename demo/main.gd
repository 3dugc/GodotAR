extends Node3D

@onready var camera: Camera3D = $XRFoundationRig/XRCamera3D
@onready var raycast_manager: ARRaycastManager = $ARRaycastManager
@onready var anchor_manager: ARAnchorManager = $ARAnchorManager


func _ready() -> void:
	XRFoundation.session_started.connect(_on_session_started)
	XRFoundation.session_failed.connect(_on_session_failed)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var hits := raycast_manager.screen_raycast(camera, event.position, 1)
		if hits.is_empty():
			return
		var anchor := anchor_manager.add_anchor(hits[0].transform)
		_spawn_marker(anchor)


func _spawn_marker(anchor: ARAnchor) -> void:
	if anchor.node == null:
		return
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "PlacedCube"
	var box := BoxMesh.new()
	box.size = Vector3(0.12, 0.12, 0.12)
	mesh_instance.mesh = box

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.1, 0.65, 0.95, 1.0)
	mesh_instance.material_override = material

	anchor.node.add_child(mesh_instance)
	mesh_instance.position = Vector3(0.0, 0.06, 0.0)


func _on_session_started(backend: int, display_name: StringName) -> void:
	print("XR session started: %s (%s)" % [String(display_name), String(XRFoundationTypes.backend_to_string(backend))])


func _on_session_failed(reason: String) -> void:
	print("XR session failed, using configured fallback if available: %s" % reason)

