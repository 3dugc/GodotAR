extends Node

signal session_state_changed(state: int)
signal session_started(backend: int, display_name: StringName)
signal session_failed(reason: String)
signal session_stopped
signal tracking_state_changed(status: int)
signal availability_checked(report: Dictionary)

const EditorSimProviderScript := preload("res://addons/godot_xr_foundation/scripts/providers/editor_sim_provider.gd")
const NativeXRProviderScript := preload("res://addons/godot_xr_foundation/scripts/providers/native_xr_provider.gd")
const OpenXRProviderScript := preload("res://addons/godot_xr_foundation/scripts/providers/openxr_provider.gd")

var state := XRFoundationTypes.SessionState.STOPPED
var backend := XRFoundationTypes.Backend.AUTO
var provider: XRProvider = null
var last_error := ""

var _last_tracking_status := XRInterface.XR_UNKNOWN_TRACKING


func _ready() -> void:
	set_process(true)


func _process(delta: float) -> void:
	if provider == null or state != XRFoundationTypes.SessionState.RUNNING:
		return
	provider.update(delta)
	var status := provider.get_tracking_status()
	if status != _last_tracking_status:
		_last_tracking_status = status
		tracking_state_changed.emit(status)


func start_session(requested_backend: int = XRFoundationTypes.Backend.AUTO, options: Dictionary = {}) -> bool:
	if state == XRFoundationTypes.SessionState.RUNNING:
		stop_session()

	state = XRFoundationTypes.SessionState.STARTING
	session_state_changed.emit(state)
	last_error = ""

	var failures: Array[String] = []
	var resolved_options := options.duplicate()
	resolved_options["platform_hint"] = resolve_platform_hint(String(options.get("platform_hint", "")))
	for candidate in _candidate_backends(requested_backend, resolved_options):
		var candidate_provider := _make_provider(candidate)
		candidate_provider.configure(self, candidate, resolved_options)
		if not candidate_provider.is_supported():
			failures.append("%s unsupported" % String(candidate_provider.display_name))
			continue
		if candidate_provider.start(resolved_options):
			provider = candidate_provider
			backend = candidate
			state = XRFoundationTypes.SessionState.RUNNING
			_last_tracking_status = provider.get_tracking_status()
			session_state_changed.emit(state)
			session_started.emit(backend, provider.display_name)
			tracking_state_changed.emit(_last_tracking_status)
			return true
		failures.append("%s failed: %s" % [String(candidate_provider.display_name), candidate_provider.last_error])

	provider = null
	state = XRFoundationTypes.SessionState.FAILED
	last_error = "; ".join(PackedStringArray(failures))
	session_state_changed.emit(state)
	session_failed.emit(last_error)
	push_warning("XR session failed: %s" % last_error)
	return false


func check_availability(requested_backend: int = XRFoundationTypes.Backend.AUTO, options: Dictionary = {}) -> Dictionary:
	var resolved_options := options.duplicate()
	resolved_options["platform_hint"] = resolve_platform_hint(String(options.get("platform_hint", "")))

	var candidates: Array[Dictionary] = []
	var selected_backend := XRFoundationTypes.Backend.AUTO
	var supported := false
	for candidate in _candidate_backends(requested_backend, resolved_options):
		var candidate_provider := _make_provider(candidate)
		candidate_provider.configure(self, candidate, resolved_options)
		var candidate_report := candidate_provider.check_availability(resolved_options)
		candidates.append(candidate_report)
		if not supported and bool(candidate_report.get("supported", false)):
			supported = true
			selected_backend = candidate

	var report := {
		"requested_backend": XRFoundationTypes.backend_to_string(requested_backend),
		"selected_backend": XRFoundationTypes.backend_to_string(selected_backend),
		"supported": supported,
		"platform_hint": resolved_options.get("platform_hint", ""),
		"session_state": get_session_state_name(),
		"candidates": candidates,
		"timestamp_msec": Time.get_ticks_msec(),
	}
	availability_checked.emit(report)
	return report


func install(requested_backend: int = XRFoundationTypes.Backend.AUTO, options: Dictionary = {}) -> bool:
	var resolved_options := options.duplicate()
	resolved_options["platform_hint"] = resolve_platform_hint(String(options.get("platform_hint", "")))
	for candidate in _candidate_backends(requested_backend, resolved_options):
		var candidate_provider := _make_provider(candidate)
		candidate_provider.configure(self, candidate, resolved_options)
		if candidate_provider.install(resolved_options):
			return true
		last_error = candidate_provider.last_error
	return false


func stop_session() -> void:
	if provider:
		provider.stop()
	provider = null
	backend = XRFoundationTypes.Backend.AUTO
	state = XRFoundationTypes.SessionState.STOPPED
	session_state_changed.emit(state)
	session_stopped.emit()


func reset_session(requested_backend: int = XRFoundationTypes.Backend.AUTO, options: Dictionary = {}) -> bool:
	stop_session()
	return start_session(requested_backend, options)


func is_running() -> bool:
	return state == XRFoundationTypes.SessionState.RUNNING


func try_raycast(origin: Vector3, direction: Vector3, max_distance: float = 20.0, mask: int = 0xffffffff) -> Array[XRHit]:
	if provider == null:
		var hits: Array[XRHit] = []
		return hits
	return provider.try_raycast(origin, direction, max_distance, mask)


func create_anchor(transform: Transform3D, attached_trackable: ARTrackable = null) -> ARAnchor:
	if provider == null:
		return ARAnchor.new(StringName("anchor_%d" % Time.get_ticks_usec()), transform)
	return provider.create_anchor(transform, attached_trackable)


func get_planes() -> Array[ARPlane]:
	if provider == null:
		var planes: Array[ARPlane] = []
		return planes
	return provider.get_planes()


func get_backend_name() -> StringName:
	return XRFoundationTypes.backend_to_string(backend)


func get_backend() -> int:
	return backend


func get_provider_name() -> StringName:
	if provider == null:
		return &"None"
	return provider.display_name


func get_session_state_name() -> StringName:
	return XRFoundationTypes.session_state_to_string(state)


func get_tracking_status() -> int:
	if provider == null:
		return XRInterface.XR_UNKNOWN_TRACKING
	return provider.get_tracking_status()


func get_tracking_state() -> int:
	return XRFoundationTypes.tracking_status_to_state(get_tracking_status())


func get_tracking_state_name() -> StringName:
	return XRFoundationTypes.tracking_status_to_string(get_tracking_status())


func get_capabilities() -> Dictionary:
	if provider == null:
		return {}
	return provider.get_capabilities({"platform_hint": resolve_platform_hint("")})


func get_last_error() -> String:
	return last_error


func resolve_platform_hint(explicit_hint: String = "") -> String:
	var hint := explicit_hint.strip_edges().to_lower()
	if hint != "" and hint != "auto":
		return hint

	var cmdline_hint := ""
	for arg in OS.get_cmdline_args():
		var text := String(arg).strip_edges()
		if text.begins_with("--xr-platform="):
			cmdline_hint = text.trim_prefix("--xr-platform=").strip_edges().to_lower()
		if text.begins_with("--xr-backend="):
			cmdline_hint = text.trim_prefix("--xr-backend=").strip_edges().to_lower()
	if cmdline_hint != "":
		return cmdline_hint

	var project_hint := String(ProjectSettings.get_setting("godot_xr_foundation/platform_hint", "")).strip_edges().to_lower()
	if project_hint != "" and project_hint != "auto":
		return project_hint

	var model := OS.get_model_name().to_lower()
	if model.contains("rokid"):
		return "rokid"
	if OS.get_name() == "iOS":
		return "arkit"
	return ""


func _candidate_backends(requested_backend: int, options: Dictionary) -> Array[int]:
	if requested_backend != XRFoundationTypes.Backend.AUTO:
		var requested: Array[int] = [requested_backend]
		if bool(options.get("fallback_to_editor_sim", true)) and requested_backend != XRFoundationTypes.Backend.EDITOR_SIM:
			requested.append(XRFoundationTypes.Backend.EDITOR_SIM)
		return requested

	var hint := String(options.get("platform_hint", "")).strip_edges().to_lower()
	if hint in ["editor", "editorsim", "editor_sim", "simulation", "simulator", "sim"]:
		return [XRFoundationTypes.Backend.EDITOR_SIM]
	if hint in ["rokid", "openxr", "androidxr", "android_xr", "headset", "glasses"]:
		return [XRFoundationTypes.Backend.OPENXR, XRFoundationTypes.Backend.ARCORE, XRFoundationTypes.Backend.EDITOR_SIM]
	if hint in ["handheld", "handheld_ar", "phone", "mobile_ar", "arcore"]:
		return [XRFoundationTypes.Backend.ARCORE, XRFoundationTypes.Backend.OPENXR, XRFoundationTypes.Backend.EDITOR_SIM]
	if hint in ["ipad", "iphone", "ios", "arkit"]:
		return [XRFoundationTypes.Backend.ARKIT, XRFoundationTypes.Backend.EDITOR_SIM]

	match OS.get_name():
		"Android":
			return [XRFoundationTypes.Backend.ARCORE, XRFoundationTypes.Backend.OPENXR, XRFoundationTypes.Backend.EDITOR_SIM]
		"iOS":
			return [XRFoundationTypes.Backend.ARKIT, XRFoundationTypes.Backend.OPENXR, XRFoundationTypes.Backend.EDITOR_SIM]
		_:
			return [XRFoundationTypes.Backend.OPENXR, XRFoundationTypes.Backend.EDITOR_SIM]


func _make_provider(candidate: int) -> XRProvider:
	match candidate:
		XRFoundationTypes.Backend.OPENXR:
			return OpenXRProviderScript.new()
		XRFoundationTypes.Backend.ARCORE, XRFoundationTypes.Backend.ARKIT:
			return NativeXRProviderScript.new()
		_:
			return EditorSimProviderScript.new()
