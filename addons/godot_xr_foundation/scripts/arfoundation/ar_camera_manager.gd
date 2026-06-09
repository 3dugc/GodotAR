extends Node
class_name ARCameraManager

signal frame_received(args: Dictionary)
signal frameReceived(args: Dictionary)

enum LightEstimation {
	NONE = 0,
	AMBIENT_INTENSITY = 1,
	AMBIENT_COLOR = 2,
	MAIN_LIGHT_DIRECTION = 4,
	MAIN_LIGHT_INTENSITY = 8,
	MAIN_LIGHT_COLOR = 16,
	AMBIENT_SPHERICAL_HARMONICS = 32,
}

enum CameraFacingDirection {
	NONE = 0,
	USER = 1,
	WORLD = 2,
}

enum CameraBackgroundRenderingMode {
	ANY = 0,
	BEFORE_OPAQUES = 1,
	AFTER_OPAQUES = 2,
	NONE = 3,
}

@export var camera_path: NodePath
@export var emit_frame_events := true
@export var frame_event_interval_msec := 250
@export var autoFocusRequested := true
@export var imageStabilizationRequested := false
@export var requestedLightEstimation := LightEstimation.NONE
@export var requested_light_estimation := LightEstimation.NONE
@export var requestedFacingDirection := CameraFacingDirection.WORLD
@export var requested_facing_direction := CameraFacingDirection.WORLD
@export var requestedBackgroundRenderingMode := CameraBackgroundRenderingMode.ANY
@export var requested_background_rendering_mode := CameraBackgroundRenderingMode.ANY

var permissionGranted := false
var currentLightEstimation := LightEstimation.NONE
var current_light_estimation := LightEstimation.NONE
var currentFacingDirection := CameraFacingDirection.WORLD
var current_facing_direction := CameraFacingDirection.WORLD
var currentRenderingMode := CameraBackgroundRenderingMode.NONE
var current_rendering_mode := CameraBackgroundRenderingMode.NONE
var camera_background_available := false
var passthrough_available := false
var frame_received_count := 0
var latest_frame := {}
var native_camera_frame := {}
var native_intrinsics_available := false

var _last_frame_event_msec := 0


func _ready() -> void:
	set_process(true)
	update_camera_state()


func _process(_delta: float) -> void:
	update_camera_state()
	if not emit_frame_events:
		return
	var now := Time.get_ticks_msec()
	if now - _last_frame_event_msec < frame_event_interval_msec:
		return
	_last_frame_event_msec = now
	_emit_frame_received()


func update_camera_state() -> Dictionary:
	var capabilities := XRFoundation.get_capabilities()
	native_camera_frame = _get_native_camera_frame()
	camera_background_available = bool(capabilities.get("camera_background", false))
	passthrough_available = bool(capabilities.get("passthrough", false))
	permissionGranted = (
		camera_background_available
		or passthrough_available
		or bool(capabilities.get("native_plugin", false))
		or bool(capabilities.get("simulation", false))
		or bool(native_camera_frame.get("available", false))
	)
	var native_light_estimate := bool(native_camera_frame.get("has_light_estimate", false))
	currentLightEstimation = requestedLightEstimation if (bool(capabilities.get("light_estimation", false)) or native_light_estimate) else LightEstimation.NONE
	current_light_estimation = currentLightEstimation
	currentFacingDirection = requestedFacingDirection
	current_facing_direction = currentFacingDirection
	currentRenderingMode = _resolve_rendering_mode()
	current_rendering_mode = currentRenderingMode
	latest_frame = _make_frame_args(capabilities, native_camera_frame)
	return latest_frame


func get_camera() -> Camera3D:
	if camera_path != NodePath():
		var configured := get_node_or_null(camera_path)
		if configured is Camera3D:
			return configured
	var viewport := get_viewport()
	if viewport:
		var viewport_camera := viewport.get_camera_3d()
		if viewport_camera:
			return viewport_camera
	var tree := get_tree()
	if tree and tree.current_scene:
		return _find_camera_in_tree(tree.current_scene)
	return null


func GetCamera() -> Camera3D:
	return get_camera()


func SetCamera(camera: Camera3D) -> void:
	if camera == null:
		camera_path = NodePath()
		return
	camera_path = get_path_to(camera)


func TryGetIntrinsics(result: Dictionary) -> bool:
	result.clear()
	if _try_get_native_intrinsics(result):
		native_intrinsics_available = true
		return true
	native_intrinsics_available = false
	result.clear()

	var camera := get_camera()
	if camera == null:
		return false
	var viewport := get_viewport()
	if viewport == null:
		return false
	var size := viewport.get_visible_rect().size
	if size.x <= 0.0 or size.y <= 0.0:
		return false

	var fov_rad := deg_to_rad(camera.fov)
	var focal_y := (size.y * 0.5) / tan(fov_rad * 0.5)
	var focal_x := focal_y
	result["focal_length"] = [float(focal_x), float(focal_y)]
	result["principal_point"] = [float(size.x * 0.5), float(size.y * 0.5)]
	result["resolution"] = [int(size.x), int(size.y)]
	result["source"] = "godot_camera_projection"
	return true


func try_get_intrinsics() -> Dictionary:
	var intrinsics := {}
	intrinsics["success"] = TryGetIntrinsics(intrinsics)
	return intrinsics


func TryAcquireLatestCpuImage(result: Dictionary = {}) -> bool:
	result.clear()
	result["success"] = false
	result["reason"] = "cpu_image_not_exposed_in_c00"
	return false


func GetConfigurations() -> Array:
	return []


func GetLatestFrame() -> Dictionary:
	return latest_frame.duplicate(true)


func get_latest_frame() -> Dictionary:
	return GetLatestFrame()


func get_permission_granted() -> bool:
	return permissionGranted


func set_requested_light_estimation(value: int) -> void:
	requestedLightEstimation = value
	requested_light_estimation = value


func set_requested_facing_direction(value: int) -> void:
	requestedFacingDirection = value
	requested_facing_direction = value


func set_requested_background_rendering_mode(value: int) -> void:
	requestedBackgroundRenderingMode = value
	requested_background_rendering_mode = value


func _emit_frame_received() -> void:
	var args := update_camera_state()
	frame_received_count += 1
	frame_received.emit(args)
	frameReceived.emit(args)


func _make_frame_args(capabilities: Dictionary, native_frame: Dictionary = {}) -> Dictionary:
	var intrinsics := {}
	var has_intrinsics: bool = TryGetIntrinsics(intrinsics)
	return {
		"timestamp_msec": Time.get_ticks_msec(),
		"permission_granted": permissionGranted,
		"camera_background": camera_background_available,
		"passthrough": passthrough_available,
		"requested_light_estimation": int(requestedLightEstimation),
		"current_light_estimation": int(currentLightEstimation),
		"requested_facing_direction": int(requestedFacingDirection),
		"current_facing_direction": int(currentFacingDirection),
		"requested_background_rendering_mode": int(requestedBackgroundRenderingMode),
		"current_rendering_mode": int(currentRenderingMode),
		"has_intrinsics": has_intrinsics,
		"intrinsics": intrinsics,
		"native_intrinsics_available": native_intrinsics_available,
		"native_frame_available": bool(native_frame.get("available", false)),
		"native_frame": native_frame,
		"light_estimation": native_frame.get("light_estimation", {}),
		"light_estimation_supported": bool(capabilities.get("light_estimation", false)),
		"runtime": String(capabilities.get("runtime", "")),
	}


func _resolve_rendering_mode() -> int:
	if camera_background_available or passthrough_available:
		return requestedBackgroundRenderingMode
	return CameraBackgroundRenderingMode.NONE


func _find_camera_in_tree(root: Node) -> Camera3D:
	if root == null:
		return null
	if root is Camera3D:
		return root
	for child in root.get_children():
		var camera := _find_camera_in_tree(child)
		if camera:
			return camera
	return null


func _try_get_native_intrinsics(result: Dictionary) -> bool:
	var singleton := _find_native_camera_singleton()
	if singleton == null:
		return false

	for method_name in ["try_get_intrinsics", "get_camera_intrinsics", "get_intrinsics"]:
		if not singleton.has_method(method_name):
			continue
		var native_result: Variant = singleton.call(method_name)
		if native_result is Dictionary and _intrinsics_dictionary_has_shape(native_result):
			result.merge(native_result, true)
			if not result.has("source") or String(result.get("source", "")).is_empty():
				result["source"] = "native_camera_intrinsics"
			return bool(result.get("success", true))

	var frame := _get_native_camera_frame()
	if bool(frame.get("has_intrinsics", false)) and frame.get("intrinsics") is Dictionary:
		var frame_intrinsics: Dictionary = frame.get("intrinsics")
		if _intrinsics_dictionary_has_shape(frame_intrinsics):
			result.merge(frame_intrinsics, true)
			return bool(result.get("success", true))
	return false


func _get_native_camera_frame() -> Dictionary:
	var singleton := _find_native_camera_singleton()
	if singleton == null:
		return {}
	for method_name in ["get_camera_frame", "get_latest_camera_frame", "get_ar_camera_frame"]:
		if singleton.has_method(method_name):
			var frame: Variant = singleton.call(method_name)
			if frame is Dictionary:
				return frame
	return {}


func _find_native_camera_singleton() -> Object:
	for singleton_name in ["GodotARKit", "GodotARCore", "ARKit", "ARCore", "ARKitPlugin", "ARCorePlugin"]:
		if Engine.has_singleton(StringName(singleton_name)):
			return Engine.get_singleton(StringName(singleton_name))
	return null


func _intrinsics_dictionary_has_shape(data: Dictionary) -> bool:
	return (
		data.has("focal_length")
		and data.has("principal_point")
		and data.has("resolution")
	)
