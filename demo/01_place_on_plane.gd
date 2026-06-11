extends Node3D

const CYCLE_ID := "C01"
const VERSION := "v0.1.0-editor-place-on-plane"

@export_enum("Auto", "Editor Simulation", "OpenXR / Rokid", "ARCore", "ARKit") var requested_backend: int = XRFoundationTypes.Backend.EDITOR_SIM
@export var platform_hint := "editor"
@export var fallback_to_editor_sim := true
@export var auto_place_on_first_hit := false

@onready var ar_session: ARSession = $ARSession
@onready var status_label: Label3D = $XRFoundationRig/XRCamera3D/StatusPanel/StatusLabel
@onready var xr_camera: Camera3D = $XRFoundationRig/XRCamera3D
@onready var raycast_manager: ARRaycastManager = $ARRaycastManager
@onready var plane_manager: ARPlaneManager = $ARPlaneManager
@onready var anchor_manager: ARAnchorManager = $ARAnchorManager
@onready var cursor: MeshInstance3D = $World/PlacementCursor
@onready var placed_object: MeshInstance3D = $World/PlacedObject

var _availability_report: Dictionary = {}
var _last_hit: Dictionary = {"hit": false}
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
	plane_manager.trackablesChanged.connect(_on_planes_changed)
	anchor_manager.trackablesChanged.connect(_on_anchors_changed)
	raycast_manager.SetRaycastCamera(xr_camera)
	_ensure_place_input_actions()
	_availability_report = ar_session.check_availability()
	_emit_place_log("availability", {"availability": _availability_report})


func _process(_delta: float) -> void:
	_update_center_hit()
	if _place_input_pressed():
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


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		_place_from_screen_position(event.position, "touch")
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_place_from_screen_position(event.position, "mouse")


func _update_center_hit() -> void:
	var hits := _screen_raycast(_viewport_center())
	if hits.is_empty():
		cursor.visible = false
		_last_hit = {"hit": false}
		return
	var hit: XRHit = hits[0]
	cursor.visible = true
	cursor.global_transform = hit.get_pose()
	_last_hit = _hit_metadata(hit)


func _place_input_pressed() -> bool:
	return InputMap.has_action(&"ar_place") and Input.is_action_just_pressed(&"ar_place")


func _place_from_screen_position(screen_position: Vector2, reason: String) -> bool:
	var hits := _screen_raycast(screen_position)
	if hits.is_empty():
		_emit_place_log("place_missed", {
			"reason": reason,
			"screen_position": [float(screen_position.x), float(screen_position.y)],
		})
		return false
	var hit: XRHit = hits[0]
	_last_hit = _hit_metadata(hit)
	return _place_hit(hit, reason)


func _place_at_current_hit(reason: String) -> bool:
	if not bool(_last_hit.get("hit", false)):
		return false
	var transform := _transform_from_hit_metadata(_last_hit)
	var anchor := _try_add_anchor(transform)
	_show_placed_object(transform)
	_placed_count += 1
	_last_place_reason = reason
	_emit_place_log("placed", {
		"reason": reason,
		"placed_count": _placed_count,
		"anchor": _anchor_metadata(anchor),
		"hit": _last_hit,
	})
	return true


func _place_hit(hit: XRHit, reason: String) -> bool:
	var transform := hit.get_pose()
	var anchor := _try_attach_anchor(hit, transform)
	_show_placed_object(transform)
	_placed_count += 1
	_last_place_reason = reason
	_emit_place_log("placed", {
		"reason": reason,
		"placed_count": _placed_count,
		"anchor": _anchor_metadata(anchor),
		"hit": _hit_metadata(hit),
	})
	return true


func _screen_raycast(screen_position: Vector2) -> Array[XRHit]:
	if raycast_manager == null or xr_camera == null:
		var empty: Array[XRHit] = []
		return empty
	var raw_hits: Array = []
	if not bool(raycast_manager.Raycast(screen_position, raw_hits, XRFoundationTypes.TRACKABLE_TYPE_PLANES)):
		var missed: Array[XRHit] = []
		return missed
	var hits: Array[XRHit] = []
	for hit in raw_hits:
		if hit is XRHit:
			hits.append(hit)
	return hits


func _try_attach_anchor(hit: XRHit, transform: Transform3D) -> ARAnchor:
	if anchor_manager == null:
		return null
	var plane := plane_manager.GetPlane(hit.trackableId) if plane_manager else null
	if plane != null and bool(anchor_manager.GetDescriptor().get("supportsTrackableAttachments", false)):
		var attached := anchor_manager.AttachAnchor(plane, transform)
		if attached != null:
			return attached
	return _try_add_anchor(transform)


func _try_add_anchor(transform: Transform3D) -> ARAnchor:
	if anchor_manager == null:
		return null
	var result := anchor_manager.TryAddAnchorAsync(transform)
	if bool(result.get("success", false)):
		var anchor_value: Variant = result.get("value", result.get("anchor", null))
		if anchor_value is ARAnchor:
			return anchor_value
	return null


func _show_placed_object(transform: Transform3D) -> void:
	placed_object.visible = true
	placed_object.global_transform = transform


func _viewport_center() -> Vector2:
	var viewport := get_viewport()
	if viewport == null:
		return Vector2.ZERO
	return viewport.get_visible_rect().size * 0.5


func _update_status_panel() -> void:
	var capabilities := XRFoundation.get_capabilities()
	var planes := _plane_metadata()
	var anchors := _anchor_list_metadata()
	var lines := PackedStringArray([
		"Place On Plane %s" % VERSION,
		"Backend: %s  Provider: %s" % [String(XRFoundation.get_backend_name()), String(XRFoundation.get_provider_name())],
		"Session: %s  ARSession: %s" % [String(XRFoundation.get_session_state_name()), String(XRFoundation.get_ar_session_state_name())],
		"Tracking: %s  Reason: %s" % [String(XRFoundation.get_tracking_state_name()), String(XRFoundation.get_not_tracking_reason_name())],
		"Simulation: %s  Runtime: %s" % [_yes_no(bool(capabilities.get("simulation", false))), String(capabilities.get("runtime", "unknown"))],
		"Planes: %d  Center hit: %s" % [int(planes.get("count", 0)), _yes_no(bool(_last_hit.get("hit", false)))],
		"Anchors: %d  Placed: %d" % [int(anchors.get("count", 0)), _placed_count],
		"Last place: %s" % ("none" if _last_place_reason == "" else _last_place_reason),
		"Place: click / tap / Space",
	])
	status_label.text = "\n".join(lines)


func _emit_place_log(event_name: String, extra: Dictionary) -> void:
	var payload := {
		"cycle": CYCLE_ID,
		"version": VERSION,
		"event": event_name,
		"runtime": _runtime_metadata(),
		"os": OS.get_name(),
		"model": OS.get_model_name(),
		"platform_hint": XRFoundation.resolve_platform_hint(platform_hint),
		"requested_backend": String(XRFoundationTypes.backend_to_string(requested_backend)),
		"backend": String(XRFoundation.get_backend_name()),
		"provider": String(XRFoundation.get_provider_name()),
		"session_state": String(XRFoundation.get_session_state_name()),
		"ar_session_state": String(XRFoundation.get_ar_session_state_name()),
		"tracking": String(XRFoundation.get_tracking_state_name()),
		"not_tracking_reason": String(XRFoundation.get_not_tracking_reason_name()),
		"capabilities": XRFoundation.get_capabilities(),
		"planes": _plane_metadata(),
		"anchors": _anchor_list_metadata(),
		"center_screen_raycast": _last_hit,
		"placed_count": _placed_count,
		"last_place_reason": _last_place_reason,
	}
	for key in extra.keys():
		payload[key] = extra[key]
	print("GXF_C01_PLACE|%s" % JSON.stringify(payload))


func _runtime_metadata() -> Dictionary:
	return {
		"godot": Engine.get_version_info(),
		"cmdline_xr_args": XRFoundation.get_xr_cmdline_args(),
		"resolved_platform_hint": XRFoundation.resolve_platform_hint(platform_hint),
		"project_platform_hint": String(ProjectSettings.get_setting("godot_xr_foundation/platform_hint", "")),
	}


func _plane_metadata() -> Dictionary:
	if plane_manager == null:
		return {"manager": false, "count": 0}
	var planes: Array[ARPlane] = plane_manager.get_all_planes()
	var ids := []
	for plane in planes:
		ids.append(String(plane.trackable_id))
	return {"manager": true, "count": planes.size(), "ids": ids}


func _anchor_list_metadata() -> Dictionary:
	if anchor_manager == null:
		return {"manager": false, "count": 0}
	var anchors: Array[ARAnchor] = anchor_manager.get_all_anchors()
	var ids := []
	for anchor in anchors:
		ids.append(String(anchor.trackable_id))
	return {"manager": true, "count": anchors.size(), "ids": ids}


func _hit_metadata(hit: XRHit) -> Dictionary:
	return {
		"hit": true,
		"trackable_id": String(hit.trackable_id),
		"trackable_type": int(hit.trackable_type),
		"position": _vector3_array(hit.position),
		"normal": _vector3_array(hit.normal),
		"distance": float(hit.distance),
	}


func _anchor_metadata(anchor: ARAnchor) -> Dictionary:
	if anchor == null:
		return {"created": false}
	return {
		"created": true,
		"trackable_id": String(anchor.trackable_id),
		"position": _vector3_array(anchor.transform.origin),
	}


func _transform_from_hit_metadata(hit: Dictionary) -> Transform3D:
	return Transform3D(Basis(), _vector3_from_array(hit.get("position", [])))


func _vector3_array(value: Vector3) -> Array:
	return [float(value.x), float(value.y), float(value.z)]


func _vector3_from_array(value: Variant) -> Vector3:
	if value is Array and value.size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return Vector3.ZERO


func _ensure_place_input_actions() -> void:
	if not InputMap.has_action(&"ar_place"):
		InputMap.add_action(&"ar_place")
		var place_key := InputEventKey.new()
		place_key.keycode = KEY_SPACE
		InputMap.action_add_event(&"ar_place", place_key)
		var place_mouse := InputEventMouseButton.new()
		place_mouse.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event(&"ar_place", place_mouse)


func _on_session_started(_backend: int, display_name: StringName) -> void:
	_emit_place_log("session_started", {"display_name": String(display_name)})


func _on_session_failed(reason: String) -> void:
	_emit_place_log("session_failed", {"reason": reason})


func _on_planes_changed(changes: ARTrackablesChangedEventArgs) -> void:
	_emit_place_log("planes_changed", {"changes": changes.to_dictionary()})


func _on_anchors_changed(changes: ARTrackablesChangedEventArgs) -> void:
	_emit_place_log("anchors_changed", {"changes": changes.to_dictionary()})


func _yes_no(value: bool) -> String:
	return "yes" if value else "no"
