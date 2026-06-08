extends XRProvider
class_name EditorSimProvider

var simulated_floor_height := 0.0
var simulated_plane_size := Vector2(5.0, 5.0)


func configure(p_owner: Node, p_backend: int, options: Dictionary = {}) -> void:
	super.configure(p_owner, p_backend, options)
	display_name = &"Editor Simulation"
	simulated_floor_height = float(options.get("simulated_floor_height", 0.0))
	simulated_plane_size = options.get("simulated_plane_size", Vector2(5.0, 5.0))


func is_supported() -> bool:
	return true


func start(_options: Dictionary = {}) -> bool:
	last_error = ""
	if owner and owner.get_viewport():
		owner.get_viewport().use_xr = false
		owner.get_viewport().transparent_bg = false
	return true


func get_capabilities(_options: Dictionary = {}) -> Dictionary:
	var capabilities := super.get_capabilities(_options)
	capabilities["tracking"] = true
	capabilities["raycast"] = true
	capabilities["plane_detection"] = true
	capabilities["anchors"] = true
	capabilities["input_ray"] = true
	capabilities["ar_product_path"] = true
	capabilities["simulation"] = true
	return capabilities


func get_tracking_status() -> int:
	return XRInterface.XR_NORMAL_TRACKING


func get_planes() -> Array[ARPlane]:
	var transform := Transform3D(Basis(), Vector3(0.0, simulated_floor_height, 0.0))
	var plane := ARPlane.new(&"sim_floor", transform, simulated_plane_size, &"horizontal")
	plane.label = &"floor"
	var planes: Array[ARPlane] = [plane]
	return planes


func try_raycast(origin: Vector3, direction: Vector3, max_distance: float = 20.0, mask: int = 0xffffffff) -> Array[XRHit]:
	var ray_direction := direction.normalized()
	if absf(ray_direction.y) < 0.0001:
		ray_direction = (ray_direction + Vector3.DOWN * 0.35).normalized()

	var distance_to_floor := (simulated_floor_height - origin.y) / ray_direction.y
	if distance_to_floor < 0.0 or distance_to_floor > max_distance:
		return super.try_raycast(origin, direction, max_distance, mask)

	var point := origin + ray_direction * distance_to_floor
	var hit := XRHit.new(
		Transform3D(Basis(), point),
		distance_to_floor,
		&"sim_floor",
		XRFoundationTypes.TrackableType.PLANE
	)
	hit.normal = Vector3.UP
	var hits: Array[XRHit] = [hit]
	return hits
