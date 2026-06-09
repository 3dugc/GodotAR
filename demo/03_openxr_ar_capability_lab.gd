extends Node3D

const CYCLE_ID := "C02"
const VERSION := "v0.2.0-openxr-capability-lab"
const XRInputProfileScript := preload("res://addons/godot_xr_foundation/scripts/xri/xr_input_profile.gd")

@export_enum("Auto", "Editor Simulation", "OpenXR / Rokid", "ARCore", "ARKit") var requested_backend: int = XRFoundationTypes.Backend.OPENXR
@export var platform_hint := "rokid"
@export var fallback_to_editor_sim := true

@onready var ar_session: ARSession = $ARSession
@onready var status_label: Label3D = $XRFoundationRig/XRCamera3D/StatusPanel/StatusLabel
@onready var xr_camera: Camera3D = $XRFoundationRig/XRCamera3D
@onready var raycast_manager: ARRaycastManager = $ARRaycastManager
@onready var plane_manager: ARPlaneManager = $ARPlaneManager
@onready var camera_manager: Node = $ARCameraManager
@onready var xri_manager: XRInteractionManager = $XRInteractionManager
@onready var xri_ray: XRRayInteractor = $XRFoundationRig/XRCamera3D/XRRayInteractor
@onready var cursor: MeshInstance3D = $World/PlacementCursor
@onready var menu_target: XRGrabInteractable = $World/MenuTarget

var _availability_report := {}
var _last_log_msec := 0
var _last_status_msec := 0
var _hover_count := 0
var _select_count := 0
var _last_hit := {}


func _ready() -> void:
	ar_session.requested_backend = requested_backend
	ar_session.platform_hint = platform_hint
	ar_session.fallback_to_editor_sim = fallback_to_editor_sim
	XRFoundation.session_started.connect(_on_session_started)
	XRFoundation.session_failed.connect(_on_session_failed)
	xri_manager.hover_entered.connect(_on_hover_entered)
	xri_manager.select_entered.connect(_on_select_entered)
	_ensure_xri_input_actions()
	_availability_report = ar_session.check_availability()
	_emit_lab_log("availability", {"availability": _availability_report})


func _process(_delta: float) -> void:
	_update_center_raycast()
	var now := Time.get_ticks_msec()
	if now - _last_status_msec > 250:
		_last_status_msec = now
		_update_status_panel()
	if now - _last_log_msec > 3000:
		_last_log_msec = now
		_emit_lab_log("heartbeat", {})


func _update_status_panel() -> void:
	var capabilities := XRFoundation.get_capabilities()
	var input_profile := _input_profile(capabilities)
	var evidence := _string_array(capabilities.get("openxr_ar_evidence", []))
	var vendor_singletons := _string_array(capabilities.get("openxr_vendor_singletons", []))
	var lines := PackedStringArray([
		"OpenXR AR Capability Lab %s" % VERSION,
		"Platform: %s" % XRFoundation.resolve_platform_hint(platform_hint),
		"Device: %s  Mode: %s" % [String(XRFoundation.get_device_profile()), String(XRFoundation.get_tracking_mode())],
		"Backend: %s  Provider: %s" % [String(XRFoundation.get_backend_name()), String(XRFoundation.get_provider_name())],
		"Session: %s  ARSession: %s" % [String(XRFoundation.get_session_state_name()), String(XRFoundation.get_ar_session_state_name())],
		"Tracking: %s  Reason: %s" % [String(XRFoundation.get_tracking_state_name()), String(XRFoundation.get_not_tracking_reason_name())],
		"AR tier: %s  Fallback: %s" % [String(capabilities.get("openxr_ar_tier", "unknown")), String(capabilities.get("openxr_fallback", "unknown"))],
		"Passthrough: %s  Started: %s" % [_yes_no(bool(capabilities.get("passthrough", false))), _yes_no(bool(capabilities.get("openxr_passthrough_started", false)))],
		"Plane source: %s  Ray hit: %s" % [String(capabilities.get("openxr_plane_source", "none")), _yes_no(bool(_last_hit.get("hit", false)))],
		"Input: %s  Modes: %s" % [String(input_profile.get("primary", "gaze")), _array_to_csv(input_profile.get("modes", []))],
		"XRI: hover %d  select %d" % [_hover_count, _select_count],
		"Evidence: %s" % _array_to_csv(evidence),
		"Vendors: %s" % _array_to_csv(vendor_singletons),
	])
	status_label.text = "\n".join(lines)


func _update_center_raycast() -> void:
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


func _emit_lab_log(event_name: String, extra: Dictionary) -> void:
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
		"input_profile": _input_profile(capabilities),
		"center_screen_raycast": _last_hit,
		"camera": _camera_metadata(),
		"xri": {
			"interaction_manager": xri_manager != null,
			"ray_interactor": xri_ray != null,
			"menu_target": menu_target != null,
			"hover_count": _hover_count,
			"select_count": _select_count,
		},
	}
	for key in extra.keys():
		payload[key] = extra[key]
	print("GXF_OPENXR_LAB|%s" % JSON.stringify(payload))


func _camera_metadata() -> Dictionary:
	if camera_manager == null:
		return {"manager": false}
	if camera_manager.has_method("update_camera_state"):
		camera_manager.update_camera_state()
	var latest: Dictionary = camera_manager.GetLatestFrame() if camera_manager.has_method("GetLatestFrame") else {}
	return {
		"manager": true,
		"permission_granted": camera_manager.permissionGranted,
		"passthrough": camera_manager.passthrough_available,
		"camera_background": camera_manager.camera_background_available,
		"native_frame_available": bool(latest.get("native_frame_available", false)),
		"has_intrinsics": bool(latest.get("has_intrinsics", false)),
	}


func _input_profile(capabilities: Dictionary) -> Dictionary:
	var profile := XRInputProfileScript.new()
	profile.configure_from_capabilities(capabilities)
	return profile.to_dictionary()


func _on_session_started(_backend: int, display_name: StringName) -> void:
	_emit_lab_log("session_started", {"display_name": String(display_name)})


func _on_session_failed(reason: String) -> void:
	_emit_lab_log("session_failed", {"reason": reason})


func _on_hover_entered(_interactor: Node, _interactable: Node) -> void:
	_hover_count += 1


func _on_select_entered(_interactor: Node, _interactable: Node) -> void:
	_select_count += 1
	_emit_lab_log("select_entered", {"target": _interactable.name if _interactable else ""})


func _ensure_xri_input_actions() -> void:
	if not InputMap.has_action(&"xr_select"):
		InputMap.add_action(&"xr_select")
		var select_key := InputEventKey.new()
		select_key.keycode = KEY_SPACE
		InputMap.action_add_event(&"xr_select", select_key)
		var select_mouse := InputEventMouseButton.new()
		select_mouse.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event(&"xr_select", select_mouse)
	if not InputMap.has_action(&"xr_activate"):
		InputMap.add_action(&"xr_activate")
		var activate_key := InputEventKey.new()
		activate_key.keycode = KEY_ENTER
		InputMap.action_add_event(&"xr_activate", activate_key)


func _vector3_array(value: Vector3) -> Array:
	return [float(value.x), float(value.y), float(value.z)]


func _string_array(value: Variant) -> Array:
	var result := []
	if value is Array:
		for item in value:
			result.append(String(item))
	return result


func _array_to_csv(value: Variant) -> String:
	if value is Array:
		if value.is_empty():
			return "none"
		var parts := PackedStringArray()
		for item in value:
			parts.append(String(item))
		return ", ".join(parts)
	return String(value)


func _yes_no(value: bool) -> String:
	return "yes" if value else "no"
