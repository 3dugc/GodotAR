extends Node3D

const CYCLE_ID := "C00"
const VERSION := "v0.0.1-c00-device-smoke"

@export_enum("Auto", "Editor Simulation", "OpenXR / Rokid", "ARCore", "ARKit") var requested_backend := XRFoundationTypes.Backend.AUTO
@export var platform_hint := ""
@export var fallback_to_editor_sim := true

@onready var ar_session: ARSession = $ARSession
@onready var status_label: Label3D = $XRFoundationRig/XRCamera3D/StatusPanel/StatusLabel
@onready var rotating_cube: MeshInstance3D = $World/RotatingCube
@onready var plane_manager: ARPlaneManager = $ARPlaneManager
@onready var anchor_manager: ARAnchorManager = $ARAnchorManager

var _availability_report: Dictionary = {}
var _last_log_msec := 0
var _last_status_msec := 0
var _session_started := false


func _ready() -> void:
	ar_session.requested_backend = requested_backend
	ar_session.platform_hint = platform_hint
	ar_session.fallback_to_editor_sim = fallback_to_editor_sim

	XRFoundation.session_started.connect(_on_session_started)
	XRFoundation.session_failed.connect(_on_session_failed)
	XRFoundation.tracking_state_changed.connect(_on_tracking_state_changed)

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

	var lines := PackedStringArray([
		"Godot XR Foundation %s" % VERSION,
		"Cycle: %s" % CYCLE_ID,
		"Platform hint: %s" % ("auto" if platform == "" else platform),
		"Session: %s" % String(XRFoundation.get_session_state_name()),
		"Backend: %s" % String(XRFoundation.get_backend_name()),
		"Provider: %s" % String(XRFoundation.get_provider_name()),
		"Tracking: %s" % String(XRFoundation.get_tracking_state_name()),
		"FPS: %d" % fps,
		"Planes: %d  Anchors: %d" % [planes, anchors],
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
		"tracking": String(XRFoundation.get_tracking_state_name()),
		"capabilities": XRFoundation.get_capabilities(),
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
		"rendering_method": String(ProjectSettings.get_setting("rendering/renderer/rendering_method", "")),
		"openxr_enabled": bool(ProjectSettings.get_setting("xr/openxr/enabled", false)),
		"xr_shaders_enabled": bool(ProjectSettings.get_setting("xr/shaders/enabled", false)),
		"viewport_use_xr": viewport.use_xr if viewport else false,
		"viewport_transparent_bg": viewport.transparent_bg if viewport else false,
	}


func _safe_cmdline_args() -> Array[String]:
	var result: Array[String] = []
	for arg in OS.get_cmdline_args():
		var text := String(arg).strip_edges()
		if text.begins_with("--xr-") or text.begins_with("--rendering-") or text.begins_with("--display-driver"):
			result.append(text)
	return result


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
