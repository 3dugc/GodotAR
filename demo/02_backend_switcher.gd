extends Node3D

const CYCLE_ID := "C01"
const VERSION := "v0.1.0-backend-switcher"

const BACKEND_OPTIONS := [
	{"label": "EditorSim", "backend": XRFoundationTypes.Backend.EDITOR_SIM, "hint": "editor"},
	{"label": "OpenXR / Rokid", "backend": XRFoundationTypes.Backend.OPENXR, "hint": "rokid"},
	{"label": "Android ARCore", "backend": XRFoundationTypes.Backend.ARCORE, "hint": "arcore"},
	{"label": "iOS ARKit", "backend": XRFoundationTypes.Backend.ARKIT, "hint": "ipad"},
]

@export var fallback_to_editor_sim := true

@onready var ar_session: ARSession = $ARSession
@onready var status_label: Label3D = $XRFoundationRig/XRCamera3D/StatusPanel/StatusLabel
@onready var xr_camera: Camera3D = $XRFoundationRig/XRCamera3D
@onready var raycast_manager: ARRaycastManager = $ARRaycastManager
@onready var plane_manager: ARPlaneManager = $ARPlaneManager
@onready var anchor_manager: ARAnchorManager = $ARAnchorManager
@onready var cursor: MeshInstance3D = $World/BackendCursor

var _selected_index := 0
var _availability_reports: Array[Dictionary] = []
var _last_hit: Dictionary = {"hit": false}
var _switch_count := 0
var _last_switch_reason := "startup"
var _last_log_msec := 0
var _last_status_msec := 0


func _ready() -> void:
	XRFoundation.session_started.connect(_on_session_started)
	XRFoundation.session_failed.connect(_on_session_failed)
	_ensure_switch_input_actions()
	raycast_manager.SetRaycastCamera(xr_camera)
	_refresh_availability_reports()
	_apply_selected_backend("startup")


func _process(_delta: float) -> void:
	_handle_switch_input()
	_update_center_hit()

	var now := Time.get_ticks_msec()
	if now - _last_status_msec > 250:
		_last_status_msec = now
		_update_status_panel()
	if now - _last_log_msec > 3000:
		_last_log_msec = now
		_emit_switch_log("heartbeat", {})


func _handle_switch_input() -> void:
	if InputMap.has_action(&"backend_next") and Input.is_action_just_pressed(&"backend_next"):
		_select_backend((_selected_index + 1) % BACKEND_OPTIONS.size(), "next")
	if InputMap.has_action(&"backend_prev") and Input.is_action_just_pressed(&"backend_prev"):
		_select_backend((_selected_index + BACKEND_OPTIONS.size() - 1) % BACKEND_OPTIONS.size(), "previous")
	for index in BACKEND_OPTIONS.size():
		var action := StringName("backend_%d" % (index + 1))
		if InputMap.has_action(action) and Input.is_action_just_pressed(action):
			_select_backend(index, "hotkey_%d" % (index + 1))


func _select_backend(index: int, reason: String) -> void:
	if index == _selected_index and XRFoundation.is_running():
		return
	_selected_index = clampi(index, 0, BACKEND_OPTIONS.size() - 1)
	_apply_selected_backend(reason)


func _apply_selected_backend(reason: String) -> void:
	var option := _selected_option()
	ar_session.requested_backend = int(option["backend"])
	ar_session.platform_hint = String(option["hint"])
	ar_session.fallback_to_editor_sim = fallback_to_editor_sim
	ar_session.reset()
	_switch_count += 1
	_last_switch_reason = reason
	_emit_switch_log("backend_selected", {
		"reason": reason,
		"selected_option": option,
	})


func _refresh_availability_reports() -> void:
	_availability_reports.clear()
	for option in BACKEND_OPTIONS:
		var report := XRFoundation.check_availability(int(option["backend"]), {
			"platform_hint": String(option["hint"]),
			"fallback_to_editor_sim": fallback_to_editor_sim,
		})
		report["label"] = String(option["label"])
		_availability_reports.append(report)


func _update_center_hit() -> void:
	var hits := _center_screen_raycast()
	if hits.is_empty():
		cursor.visible = false
		_last_hit = {"hit": false}
		return
	var hit: XRHit = hits[0]
	cursor.visible = true
	cursor.global_transform = hit.get_pose()
	_last_hit = {
		"hit": true,
		"trackable_id": String(hit.trackable_id),
		"position": _vector3_array(hit.position),
		"distance": float(hit.distance),
	}


func _center_screen_raycast() -> Array[XRHit]:
	if raycast_manager == null or xr_camera == null:
		var empty: Array[XRHit] = []
		return empty
	var raw_hits: Array = []
	if not bool(raycast_manager.Raycast(_viewport_center(), raw_hits, XRFoundationTypes.TRACKABLE_TYPE_PLANES)):
		var missed: Array[XRHit] = []
		return missed
	var hits: Array[XRHit] = []
	for hit in raw_hits:
		if hit is XRHit:
			hits.append(hit)
	return hits


func _viewport_center() -> Vector2:
	var viewport := get_viewport()
	if viewport == null:
		return Vector2.ZERO
	return viewport.get_visible_rect().size * 0.5


func _update_status_panel() -> void:
	var option := _selected_option()
	var capabilities := XRFoundation.get_capabilities()
	var lines := PackedStringArray([
		"Backend Switcher %s" % VERSION,
		"Requested: %s" % String(option["label"]),
		"Actual: %s  Provider: %s" % [String(XRFoundation.get_backend_name()), String(XRFoundation.get_provider_name())],
		"Session: %s  ARSession: %s" % [String(XRFoundation.get_session_state_name()), String(XRFoundation.get_ar_session_state_name())],
		"Tracking: %s  Reason: %s" % [String(XRFoundation.get_tracking_state_name()), String(XRFoundation.get_not_tracking_reason_name())],
		"Fallback: %s  Simulation: %s" % [_yes_no(fallback_to_editor_sim), _yes_no(bool(capabilities.get("simulation", false)))],
		"Planes: %d  Anchors: %d  Hit: %s" % [_plane_count(), _anchor_count(), _yes_no(bool(_last_hit.get("hit", false)))],
		"Switches: %d  Last: %s" % [_switch_count, _last_switch_reason],
		"Keys: 1 Editor  2 OpenXR  3 ARCore  4 ARKit  Tab next",
	])
	status_label.text = "\n".join(lines)


func _emit_switch_log(event_name: String, extra: Dictionary) -> void:
	var option := _selected_option()
	var payload := {
		"cycle": CYCLE_ID,
		"version": VERSION,
		"event": event_name,
		"runtime": {
			"godot": Engine.get_version_info(),
			"cmdline_xr_args": XRFoundation.get_xr_cmdline_args(),
			"resolved_platform_hint": XRFoundation.resolve_platform_hint(String(option["hint"])),
		},
		"selected_index": _selected_index,
		"selected_option": option,
		"availability_reports": _availability_reports,
		"requested_backend": String(XRFoundationTypes.backend_to_string(int(option["backend"]))),
		"backend": String(XRFoundation.get_backend_name()),
		"provider": String(XRFoundation.get_provider_name()),
		"session_state": String(XRFoundation.get_session_state_name()),
		"ar_session_state": String(XRFoundation.get_ar_session_state_name()),
		"tracking": String(XRFoundation.get_tracking_state_name()),
		"not_tracking_reason": String(XRFoundation.get_not_tracking_reason_name()),
		"capabilities": XRFoundation.get_capabilities(),
		"planes_count": _plane_count(),
		"anchors_count": _anchor_count(),
		"center_screen_raycast": _last_hit,
		"switch_count": _switch_count,
		"last_switch_reason": _last_switch_reason,
	}
	for key in extra.keys():
		payload[key] = extra[key]
	print("GXF_C01_BACKEND|%s" % JSON.stringify(payload))


func _selected_option() -> Dictionary:
	return BACKEND_OPTIONS[_selected_index]


func _plane_count() -> int:
	if plane_manager == null:
		return 0
	return plane_manager.get_all_planes().size()


func _anchor_count() -> int:
	if anchor_manager == null:
		return 0
	return anchor_manager.get_all_anchors().size()


func _ensure_switch_input_actions() -> void:
	_add_key_action(&"backend_next", KEY_TAB)
	_add_key_action(&"backend_prev", KEY_BACKTAB)
	_add_key_action(&"backend_1", KEY_1)
	_add_key_action(&"backend_2", KEY_2)
	_add_key_action(&"backend_3", KEY_3)
	_add_key_action(&"backend_4", KEY_4)


func _add_key_action(action: StringName, keycode: Key) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var event := InputEventKey.new()
	event.keycode = keycode
	InputMap.action_add_event(action, event)


func _on_session_started(_backend: int, display_name: StringName) -> void:
	_emit_switch_log("session_started", {"display_name": String(display_name)})


func _on_session_failed(reason: String) -> void:
	_emit_switch_log("session_failed", {"reason": reason})


func _vector3_array(value: Vector3) -> Array:
	return [float(value.x), float(value.y), float(value.z)]


func _yes_no(value: bool) -> String:
	return "yes" if value else "no"
