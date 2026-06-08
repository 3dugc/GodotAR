extends Node

signal session_state_changed(state: int)
signal session_started(backend: int, display_name: StringName)
signal session_failed(reason: String)
signal session_stopped
signal tracking_state_changed(status: int)

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
	for candidate in _candidate_backends(requested_backend, options):
		var candidate_provider := _make_provider(candidate)
		candidate_provider.configure(self, candidate, options)
		if not candidate_provider.is_supported():
			failures.append("%s unsupported" % String(candidate_provider.display_name))
			continue
		if candidate_provider.start(options):
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


func stop_session() -> void:
	if provider:
		provider.stop()
	provider = null
	backend = XRFoundationTypes.Backend.AUTO
	state = XRFoundationTypes.SessionState.STOPPED
	session_state_changed.emit(state)
	session_stopped.emit()


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


func _candidate_backends(requested_backend: int, options: Dictionary) -> Array[int]:
	if requested_backend != XRFoundationTypes.Backend.AUTO:
		var requested: Array[int] = [requested_backend]
		if bool(options.get("fallback_to_editor_sim", true)) and requested_backend != XRFoundationTypes.Backend.EDITOR_SIM:
			requested.append(XRFoundationTypes.Backend.EDITOR_SIM)
		return requested

	var hint := String(options.get("platform_hint", "")).strip_edges().to_lower()
	if hint in ["rokid", "openxr", "androidxr", "android_xr", "headset", "glasses"]:
		return [XRFoundationTypes.Backend.OPENXR, XRFoundationTypes.Backend.ARCORE, XRFoundationTypes.Backend.EDITOR_SIM]
	if hint in ["handheld", "handheld_ar", "phone", "mobile_ar", "arcore"]:
		return [XRFoundationTypes.Backend.ARCORE, XRFoundationTypes.Backend.OPENXR, XRFoundationTypes.Backend.EDITOR_SIM]

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
