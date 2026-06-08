extends RefCounted
class_name XRProvider

var owner: Node = null
var xr_interface: XRInterface = null
var backend := XRFoundationTypes.Backend.AUTO
var display_name: StringName = &"Provider"
var last_error := ""


func configure(p_owner: Node, p_backend: int, _options: Dictionary = {}) -> void:
	owner = p_owner
	backend = p_backend
	display_name = XRFoundationTypes.backend_to_string(p_backend)
	last_error = ""


func is_supported() -> bool:
	return true


func start(_options: Dictionary = {}) -> bool:
	last_error = "Provider does not implement start()."
	return false


func stop() -> void:
	if owner and owner.get_viewport():
		owner.get_viewport().use_xr = false
		owner.get_viewport().transparent_bg = false
	xr_interface = null


func update(_delta: float) -> void:
	pass


func get_tracking_status() -> int:
	if xr_interface:
		return xr_interface.get_tracking_status()
	return XRInterface.XR_UNKNOWN_TRACKING


func get_planes() -> Array[ARPlane]:
	var planes: Array[ARPlane] = []
	return planes


func try_raycast(origin: Vector3, direction: Vector3, max_distance: float = 20.0, mask: int = 0xffffffff) -> Array[XRHit]:
	return _physics_raycast(origin, direction, max_distance, mask)


func create_anchor(transform: Transform3D, _attached_trackable: ARTrackable = null) -> ARAnchor:
	var anchor := ARAnchor.new(_make_id(&"anchor"), transform)
	return anchor


func apply_environment_blend(options: Dictionary = {}) -> void:
	if xr_interface == null:
		return

	var default_blend := XRInterface.XR_ENV_BLEND_MODE_OPAQUE
	if bool(options.get("prefer_ar", true)) or bool(options.get("passthrough", true)):
		default_blend = XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND

	var desired_blend := int(options.get("environment_blend_mode", default_blend))
	if xr_interface.has_method("get_supported_environment_blend_modes"):
		var modes: Array = xr_interface.get_supported_environment_blend_modes()
		if not modes.is_empty() and desired_blend not in modes:
			if XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND in modes:
				desired_blend = XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND
			elif XRInterface.XR_ENV_BLEND_MODE_ADDITIVE in modes:
				desired_blend = XRInterface.XR_ENV_BLEND_MODE_ADDITIVE
			else:
				desired_blend = modes[0]

	if _has_property(xr_interface, &"environment_blend_mode"):
		xr_interface.set("environment_blend_mode", desired_blend)

	if owner and owner.get_viewport():
		owner.get_viewport().transparent_bg = desired_blend == XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND


func _physics_raycast(origin: Vector3, direction: Vector3, max_distance: float, mask: int) -> Array[XRHit]:
	if owner == null or not owner.is_inside_tree():
		return _empty_hits()
	var viewport := owner.get_viewport()
	if viewport == null:
		return _empty_hits()
	var world_3d := viewport.world_3d
	if world_3d == null:
		return _empty_hits()

	var ray_direction := direction.normalized()
	var params := PhysicsRayQueryParameters3D.create(origin, origin + ray_direction * max_distance, mask)
	var result := world_3d.direct_space_state.intersect_ray(params)
	if result.is_empty():
		return _empty_hits()

	var hit_transform := Transform3D(Basis(), result.get("position", Vector3.ZERO))
	var hit := XRHit.new(hit_transform, origin.distance_to(hit_transform.origin), &"physics", XRFoundationTypes.TrackableType.POINT, result)
	hit.normal = result.get("normal", Vector3.UP)
	var hits: Array[XRHit] = [hit]
	return hits


func _empty_hits() -> Array[XRHit]:
	var hits: Array[XRHit] = []
	return hits


func _has_property(object: Object, property_name: StringName) -> bool:
	for property in object.get_property_list():
		if StringName(property.get("name", "")) == property_name:
			return true
	return false


func _make_id(prefix: StringName) -> StringName:
	return StringName("%s_%d" % [String(prefix), Time.get_ticks_usec()])
