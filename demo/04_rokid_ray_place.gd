extends Node3D

const CYCLE_ID := "C02"
const VERSION := "v0.2.0-rokid-ray-place"

@export_enum("Auto", "Editor Simulation", "OpenXR / Rokid", "ARCore", "ARKit") var requested_backend: int = XRFoundationTypes.Backend.OPENXR
@export var platform_hint := "rokid"
@export var fallback_to_editor_sim := true
@export var auto_place_on_first_hit := true

@onready var ar_session: ARSession = $ARSession
@onready var status_label: Label3D = $XRFoundationRig/XRCamera3D/StatusPanel/StatusLabel
@onready var xr_camera: Camera3D = $XRFoundationRig/XRCamera3D
@onready var raycast_manager: ARRaycastManager = $ARRaycastManager
@onready var anchor_manager: ARAnchorManager = $ARAnchorManager
@onready var xri_manager: XRInteractionManager = $XRInteractionManager
@onready var xri_ray: XRRayInteractor = $XRFoundationRig/XRCamera3D/XRRayInteractor
@onready var cursor: MeshInstance3D = $World/PlacementCursor
@onready var placed_object: MeshInstance3D = $World/PlacedObject

var _last_hit := {}
var _placed_count := 0
var _last_place_reason := ""
var _last_log_msec := 0
var _last_status_msec := 0


func _ready() -> void:
	ar_session.requested_backend = requested_backend
	ar_session.platform_hint = platform_hint
	ar_session.fallback_to_editor_sim = fallback_to_editor_sim
	XRFoundation.session_started.connect(_on_session_started)
	XRFoundation.session_failed.connect(_on_session_failed)
	xri_manager.select_entered.connect(_on_select_entered)
	_ensure_xri_input_actions()
	_emit_place_log("ready", {"availability": ar_session.check_availability()})


func _process(_delta: float) -> void:
	_update_center_hit()
	if InputMap.has_action(&"xr_select") and Input.is_action_just_pressed(&"xr_select"):
		_place_at_current_hit("input_select")
	if auto_place_on_first_hit and _placed_count == 0 and bool(_last_hit.get("hit", false)):
		_place_at_current_hit("auto_first_hit")

	var now := Time.get_ticks_msec()
	if now - _last_status_msec > 250:
		_last_status_msec = now
		_update_status_panel()
	if now - _last_log_msec > 3000:
		_last_log_msec = now
		_emit_place_log("heartbeat", {})


func _update_center_hit() -> void:
	var hits := _center_screen_raycast()
	if hits.is_empty():
		cursor.visible = false
		_last_hit = {"hit": false}
		return
	var hit: XRHit = hits[0]
	cursor.visible = true
	cursor.global_transform = Transform3D(Basis(), hit.position)
	_last_hit = {
		"hit": true,
		"trackable_id": String(hit.trackable_id),
		"trackable_type": int(hit.trackable_type),
		"position": _vector3_array(hit.position),
		"normal": _vector3_array(hit.normal),
		"distance": float(hit.distance),
	}


func _center_screen_raycast() -> Array[XRHit]:
	if raycast_manager == null or xr_camera == null:
		var empty: Array[XRHit] = []
		return empty
	var viewport := get_viewport()
	if viewport == null:
		var empty_viewport: Array[XRHit] = []
		return empty_viewport
	var center := viewport.get_visible_rect().size * 0.5
	return raycast_manager.screen_raycast(xr_camera, center, 1, XRFoundationTypes.TrackableType.PLANE)


func _place_at_current_hit(reason: String) -> bool:
	if not bool(_last_hit.get("hit", false)):
		return false
	var position := _vector3_from_array(_last_hit.get("position", []))
	var transform := Transform3D(Basis(), position)
	placed_object.visible = true
	placed_object.global_transform = transform
	if anchor_manager:
		anchor_manager.add_anchor(transform)
	_placed_count += 1
	_last_place_reason = reason
	_emit_place_log("placed", {
		"reason": reason,
		"placed_count": _placed_count,
		"hit": _last_hit,
	})
	return true


func _update_status_panel() -> void:
	var capabilities := XRFoundation.get_capabilities()
	var lines := PackedStringArray([
		"Rokid Ray Place %s" % VERSION,
		"Device: %s  Mode: %s" % [String(XRFoundation.get_device_profile()), String(XRFoundation.get_tracking_mode())],
		"Backend: %s  Provider: %s" % [String(XRFoundation.get_backend_name()), String(XRFoundation.get_provider_name())],
		"Session: %s  ARSession: %s" % [String(XRFoundation.get_session_state_name()), String(XRFoundation.get_ar_session_state_name())],
		"Tracking: %s  Reason: %s" % [String(XRFoundation.get_tracking_state_name()), String(XRFoundation.get_not_tracking_reason_name())],
		"AR tier: %s  Plane: %s" % [String(capabilities.get("openxr_ar_tier", "unknown")), String(capabilities.get("openxr_plane_source", "none"))],
		"Passthrough: %s  Started: %s" % [_yes_no(bool(capabilities.get("passthrough", false))), _yes_no(bool(capabilities.get("openxr_passthrough_started", false)))],
		"Center hit: %s  Placed: %d" % [_yes_no(bool(_last_hit.get("hit", false))), _placed_count],
		"Last place: %s" % ("none" if _last_place_reason == "" else _last_place_reason),
		"Select: xr_select / gaze auto first hit",
	])
	status_label.text = "\n".join(lines)


func _emit_place_log(event_name: String, extra: Dictionary) -> void:
	var capabilities := XRFoundation.get_capabilities()
	var payload := {
		"cycle": CYCLE_ID,
		"version": VERSION,
		"event": event_name,
		"platform_hint": XRFoundation.resolve_platform_hint(platform_hint),
		"device_profile": String(XRFoundation.get_device_profile()),
		"tracking_mode": String(XRFoundation.get_tracking_mode()),
		"backend": String(XRFoundation.get_backend_name()),
		"provider": String(XRFoundation.get_provider_name()),
		"session_state": String(XRFoundation.get_session_state_name()),
		"ar_session_state": String(XRFoundation.get_ar_session_state_name()),
		"tracking": String(XRFoundation.get_tracking_state_name()),
		"not_tracking_reason": String(XRFoundation.get_not_tracking_reason_name()),
		"capabilities": capabilities,
		"center_screen_raycast": _last_hit,
		"placed_count": _placed_count,
		"last_place_reason": _last_place_reason,
		"xri": {
			"interaction_manager": xri_manager != null,
			"ray_interactor": xri_ray != null,
		},
	}
	for key in extra.keys():
		payload[key] = extra[key]
	print("GXF_ROKID_PLACE|%s" % JSON.stringify(payload))


func _on_session_started(_backend: int, display_name: StringName) -> void:
	_emit_place_log("session_started", {"display_name": String(display_name)})


func _on_session_failed(reason: String) -> void:
	_emit_place_log("session_failed", {"reason": reason})


func _on_select_entered(_interactor: Node, _interactable: Node) -> void:
	_place_at_current_hit("xri_select")


func _ensure_xri_input_actions() -> void:
	if not InputMap.has_action(&"xr_select"):
		InputMap.add_action(&"xr_select")
		var select_key := InputEventKey.new()
		select_key.keycode = KEY_SPACE
		InputMap.action_add_event(&"xr_select", select_key)
		var select_mouse := InputEventMouseButton.new()
		select_mouse.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event(&"xr_select", select_mouse)


func _vector3_array(value: Vector3) -> Array:
	return [float(value.x), float(value.y), float(value.z)]


func _vector3_from_array(value: Variant) -> Vector3:
	if value is Array and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return Vector3.ZERO


func _yes_no(value: bool) -> String:
	return "yes" if value else "no"
