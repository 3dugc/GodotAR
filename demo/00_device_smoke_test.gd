extends Node3D

const CYCLE_ID := "C00"
const VERSION := "v0.0.1-c00-device-smoke"

@export_enum("Auto", "Editor Simulation", "OpenXR / Rokid", "ARCore", "ARKit") var requested_backend: int = XRFoundationTypes.Backend.AUTO
@export var platform_hint := ""
@export var fallback_to_editor_sim := true

@onready var ar_session: ARSession = $ARSession
@onready var camera_manager: Node = $ARCameraManager
@onready var status_label: Label3D = $XRFoundationRig/XRCamera3D/StatusPanel/StatusLabel
@onready var xr_camera: Camera3D = $XRFoundationRig/XRCamera3D
@onready var rotating_cube: MeshInstance3D = $World/RotatingCube
@onready var raycast_manager: ARRaycastManager = $ARRaycastManager
@onready var plane_manager: ARPlaneManager = $ARPlaneManager
@onready var anchor_manager: ARAnchorManager = $ARAnchorManager
@onready var xr_origin: Node = $XROrigin
@onready var xri_interaction_manager: XRInteractionManager = $XRInteractionManager
@onready var xri_ray_interactor: XRRayInteractor = $XRFoundationRig/XRCamera3D/XRRayInteractor
@onready var xri_grab_interactable: XRGrabInteractable = $World/XRGrabInteractable

var _availability_report: Dictionary = {}
var _last_log_msec := 0
var _last_status_msec := 0
var _session_started := false
var xri_hover_count := 0
var xri_select_count := 0
var xri_active_hover := ""
var xri_active_selection := ""


func _ready() -> void:
	ar_session.requested_backend = requested_backend
	ar_session.platform_hint = platform_hint
	ar_session.fallback_to_editor_sim = fallback_to_editor_sim

	XRFoundation.session_started.connect(_on_session_started)
	XRFoundation.session_failed.connect(_on_session_failed)
	XRFoundation.tracking_state_changed.connect(_on_tracking_state_changed)
	xri_interaction_manager.hover_entered.connect(_on_xri_hover_entered)
	xri_interaction_manager.hover_exited.connect(_on_xri_hover_exited)
	xri_interaction_manager.select_entered.connect(_on_xri_select_entered)
	xri_interaction_manager.select_exited.connect(_on_xri_select_exited)
	_ensure_xri_input_actions()

	_availability_report = ar_session.check_availability()
	_emit_smoke_log("availability", {"report": _availability_report})
	call_deferred("_ensure_initial_anchor")


func _process(delta: float) -> void:
	rotating_cube.rotate_y(delta * 0.85)
	rotating_cube.rotate_x(delta * 0.35)

	var now := Time.get_ticks_msec()
	if now - _last_status_msec > 250:
		_last_status_msec = now
		_update_status_panel()
	if now - _last_log_msec > 3000:
		_last_log_msec = now
		_emit_smoke_log("heartbeat", {})


func _ensure_initial_anchor() -> void:
	var transform := Transform3D(Basis(), Vector3(0.0, 1.15, -1.6))
	anchor_manager.add_anchor(transform)


func _on_session_started(backend: int, display_name: StringName) -> void:
	_session_started = true
	_emit_smoke_log("session_started", {
		"backend_code": backend,
		"display_name": String(display_name),
	})


func _on_session_failed(reason: String) -> void:
	_emit_smoke_log("session_failed", {"reason": reason})


func _on_tracking_state_changed(status: int) -> void:
	_emit_smoke_log("tracking_changed", {
		"tracking_status": status,
		"tracking_state": String(XRFoundationTypes.tracking_status_to_string(status)),
	})


func _update_status_panel() -> void:
	var capabilities := XRFoundation.get_capabilities()
	var platform := XRFoundation.resolve_platform_hint(platform_hint)
	var planes := plane_manager.get_all_planes().size()
	var anchors := anchor_manager.anchors.size()
	var fps := int(Engine.get_frames_per_second())
	var origin_metadata := _origin_metadata()
	var origin_height := float(origin_metadata.get("camera_in_origin_space_height", 0.0))
	var trackables_parent_name := String(origin_metadata.get("trackables_parent", ""))

	var lines := PackedStringArray([
		"Godot XR Foundation %s" % VERSION,
		"Cycle: %s" % CYCLE_ID,
		"Platform hint: %s" % ("auto" if platform == "" else platform),
		"Session: %s" % String(XRFoundation.get_session_state_name()),
		"Backend: %s" % String(XRFoundation.get_backend_name()),
		"Provider: %s" % String(XRFoundation.get_provider_name()),
		"ARSession: %s" % String(XRFoundation.get_ar_session_state_name()),
		"Tracking: %s" % String(XRFoundation.get_tracking_state_name()),
		"Reason: %s" % String(XRFoundation.get_not_tracking_reason_name()),
		"FPS: %d" % fps,
		"Planes: %d  Anchors: %d" % [planes, anchors],
		"Origin: %.2fm  Trackables: %s" % [
			origin_height,
			_yes_no(trackables_parent_name != ""),
		],
		"Camera: %s  Light: %d" % [
			_yes_no(camera_manager.permissionGranted if camera_manager else false),
			int(camera_manager.currentLightEstimation) if camera_manager else 0,
		],
		"XRI: hover %s  select %s" % [
			"yes" if xri_active_hover != "" else "no",
			"yes" if xri_active_selection != "" else "no",
		],
		"AR path: %s  Passthrough: %s" % [
			_yes_no(bool(capabilities.get("ar_product_path", false))),
			_yes_no(bool(capabilities.get("passthrough", false))),
		],
		"Raycast: %s  Anchors: %s" % [
			_yes_no(bool(capabilities.get("raycast", false))),
			_yes_no(bool(capabilities.get("anchors", false))),
		],
		"Native: %s  OpenXR: %s" % [
			_yes_no(bool(capabilities.get("native_plugin", false))),
			_yes_no(bool(capabilities.get("openxr_interface", false))),
		],
		"Blend: %s" % _array_to_csv(capabilities.get("environment_blend_modes", [])),
	])

	var error := XRFoundation.get_last_error()
	if error != "":
		lines.append("Last error: %s" % error)
	if capabilities.has("arkit_tracking_state"):
		lines.append("ARKit: %s  Reason: %s" % [
			String(capabilities.get("arkit_tracking_state", "unknown")),
			String(capabilities.get("arkit_tracking_reason", "unknown")),
		])
	if capabilities.has("openxr_ar_tier"):
		lines.append("OpenXR AR: Tier %s  Fallback: %s" % [
			String(capabilities.get("openxr_ar_tier", "unknown")),
			String(capabilities.get("openxr_fallback", "unknown")),
		])
	if not _session_started and XRFoundation.state == XRFoundationTypes.SessionState.FAILED:
		lines.append("Fallback or native plugin setup required.")

	status_label.text = "\n".join(lines)


func _emit_smoke_log(event_name: String, extra: Dictionary) -> void:
	var payload := {
		"cycle": CYCLE_ID,
		"version": VERSION,
		"event": event_name,
		"runtime": _runtime_metadata(),
		"os": OS.get_name(),
		"model": OS.get_model_name(),
		"platform_hint": XRFoundation.resolve_platform_hint(platform_hint),
		"backend": String(XRFoundation.get_backend_name()),
		"provider": String(XRFoundation.get_provider_name()),
		"session_state": String(XRFoundation.get_session_state_name()),
		"ar_session_state": String(XRFoundation.get_ar_session_state_name()),
		"tracking": String(XRFoundation.get_tracking_state_name()),
		"not_tracking_reason": String(XRFoundation.get_not_tracking_reason_name()),
		"capabilities": XRFoundation.get_capabilities(),
		"camera": _camera_metadata(),
		"origin": _origin_metadata(),
		"trackables": _trackables_metadata(),
		"xri": _xri_metadata(),
		"fps": int(Engine.get_frames_per_second()),
		"last_error": XRFoundation.get_last_error(),
	}
	for key in extra.keys():
		payload[key] = extra[key]
	print("GXF_SMOKE|%s" % JSON.stringify(payload))


func _runtime_metadata() -> Dictionary:
	var viewport := get_viewport()
	return {
		"app_name": String(ProjectSettings.get_setting("application/config/name", "")),
		"godot": Engine.get_version_info(),
		"cmdline_xr_args": _safe_cmdline_args(),
		"resolved_platform_hint": XRFoundation.resolve_platform_hint(platform_hint),
		"project_platform_hint": String(ProjectSettings.get_setting("godot_xr_foundation/platform_hint", "")),
		"rendering_method": String(ProjectSettings.get_setting("rendering/renderer/rendering_method", "")),
		"openxr_enabled": bool(ProjectSettings.get_setting("xr/openxr/enabled", false)),
		"xr_shaders_enabled": bool(ProjectSettings.get_setting("xr/shaders/enabled", false)),
		"viewport_use_xr": viewport.use_xr if viewport else false,
		"viewport_transparent_bg": viewport.transparent_bg if viewport else false,
	}


func _xri_metadata() -> Dictionary:
	var raycast: Dictionary = {"success": false}
	if xri_ray_interactor:
		var raycast_result: Variant = xri_ray_interactor.TryGetCurrent3DRaycastHit()
		if raycast_result is Dictionary:
			raycast = raycast_result
	return {
		"interaction_manager": xri_interaction_manager != null,
		"ray_interactor": xri_ray_interactor != null,
		"grab_interactable": xri_grab_interactable != null,
		"registered_interactors": xri_interaction_manager.interactors.size() if xri_interaction_manager else 0,
		"registered_interactables": xri_interaction_manager.interactables.size() if xri_interaction_manager else 0,
		"hover_count": xri_hover_count,
		"select_count": xri_select_count,
		"active_hover": xri_active_hover,
		"active_selection": xri_active_selection,
		"ray_hit": bool(raycast.get("success", false)),
	}


func _camera_metadata() -> Dictionary:
	if camera_manager == null:
		return {"manager": false}
	if camera_manager.has_method("update_camera_state"):
		camera_manager.update_camera_state()
	var intrinsics := {}
	var has_intrinsics: bool = camera_manager.TryGetIntrinsics(intrinsics)
	var latest_frame: Dictionary = camera_manager.GetLatestFrame() if camera_manager.has_method("GetLatestFrame") else {}
	return {
		"manager": true,
		"permission_granted": camera_manager.permissionGranted,
		"camera_background": camera_manager.camera_background_available,
		"passthrough": camera_manager.passthrough_available,
		"requested_light_estimation": int(camera_manager.requestedLightEstimation),
		"current_light_estimation": int(camera_manager.currentLightEstimation),
		"requested_facing_direction": int(camera_manager.requestedFacingDirection),
		"current_facing_direction": int(camera_manager.currentFacingDirection),
		"requested_background_rendering_mode": int(camera_manager.requestedBackgroundRenderingMode),
		"current_rendering_mode": int(camera_manager.currentRenderingMode),
		"frame_received_count": camera_manager.frame_received_count,
		"has_intrinsics": has_intrinsics,
		"intrinsics": intrinsics,
		"native_intrinsics_available": bool(latest_frame.get("native_intrinsics_available", false)),
		"native_frame_available": bool(latest_frame.get("native_frame_available", false)),
		"native_frame": latest_frame.get("native_frame", {}),
		"light_estimation": latest_frame.get("light_estimation", {}),
	}


func _origin_metadata() -> Dictionary:
	if xr_origin == null:
		return {"manager": false}
	if xr_origin.has_method("to_dictionary"):
		return xr_origin.call("to_dictionary")
	return {"manager": false, "reason": "missing_to_dictionary"}


func _trackables_metadata() -> Dictionary:
	if plane_manager:
		plane_manager.sync_provider_planes()

	var planes: Array = []
	if plane_manager:
		planes = plane_manager.get_all_planes()
	var anchors: Array = []
	if anchor_manager:
		anchors = anchor_manager.get_all_anchors()
	var raycast_hits := _center_screen_raycast()

	return {
		"planes_count": planes.size(),
		"planes": _plane_summaries(planes, 5),
		"anchors_count": anchors.size(),
		"anchors": _anchor_summaries(anchors, 5),
		"center_screen_raycast": {
			"hit": not raycast_hits.is_empty(),
			"count": raycast_hits.size(),
			"first": _hit_summary(raycast_hits[0]) if not raycast_hits.is_empty() else {},
		},
	}


func _center_screen_raycast() -> Array[XRHit]:
	if raycast_manager == null or xr_camera == null:
		return _empty_xr_hits()
	var viewport := get_viewport()
	if viewport == null:
		return _empty_xr_hits()
	var center := viewport.get_visible_rect().size * 0.5
	return raycast_manager.screen_raycast(xr_camera, center, 1, XRFoundationTypes.TrackableType.PLANE)


func _empty_xr_hits() -> Array[XRHit]:
	var hits: Array[XRHit] = []
	return hits


func _plane_summaries(planes: Array, limit: int) -> Array:
	var result := []
	for plane in planes.slice(0, min(limit, planes.size())):
		result.append({
			"id": String(plane.trackable_id),
			"alignment": String(plane.alignment),
			"size": _vector2_array(plane.size),
			"tracking_state": int(plane.tracking_state),
		})
	return result


func _anchor_summaries(anchors: Array, limit: int) -> Array:
	var result := []
	for anchor in anchors.slice(0, min(limit, anchors.size())):
		result.append({
			"id": String(anchor.trackable_id),
			"persistent_id": String(anchor.persistent_id),
			"tracking_state": int(anchor.tracking_state),
		})
	return result


func _hit_summary(hit: XRHit) -> Dictionary:
	return {
		"trackable_id": String(hit.trackable_id),
		"trackable_type": int(hit.trackable_type),
		"distance": float(hit.distance),
		"position": _vector3_array(hit.position),
		"normal": _vector3_array(hit.normal),
	}


func _vector2_array(value: Vector2) -> Array:
	return [float(value.x), float(value.y)]


func _vector3_array(value: Vector3) -> Array:
	return [float(value.x), float(value.y), float(value.z)]


func _on_xri_hover_entered(_interactor: Node, interactable: Node) -> void:
	xri_hover_count += 1
	xri_active_hover = interactable.name if interactable else ""
	_emit_smoke_log("xri_hover_entered", {"interactable": xri_active_hover})


func _on_xri_hover_exited(_interactor: Node, interactable: Node) -> void:
	if xri_active_hover == (interactable.name if interactable else ""):
		xri_active_hover = ""
	_emit_smoke_log("xri_hover_exited", {"interactable": interactable.name if interactable else ""})


func _on_xri_select_entered(_interactor: Node, interactable: Node) -> void:
	xri_select_count += 1
	xri_active_selection = interactable.name if interactable else ""
	_emit_smoke_log("xri_select_entered", {"interactable": xri_active_selection})


func _on_xri_select_exited(_interactor: Node, interactable: Node) -> void:
	if xri_active_selection == (interactable.name if interactable else ""):
		xri_active_selection = ""
	_emit_smoke_log("xri_select_exited", {"interactable": interactable.name if interactable else ""})


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


func _safe_cmdline_args() -> Array[String]:
	return XRFoundation.get_xr_cmdline_args()


func _yes_no(value: bool) -> String:
	return "yes" if value else "no"


func _array_to_csv(value: Variant) -> String:
	if value is Array:
		if value.is_empty():
			return "none"
		var parts := PackedStringArray()
		for item in value:
			parts.append(String(item))
		return ", ".join(parts)
	return String(value)
