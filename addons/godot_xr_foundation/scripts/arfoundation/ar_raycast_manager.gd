extends Node
class_name ARRaycastManager

signal raycast_hit(hit: XRHit)

@export var max_distance := 20.0
@export_flags_3d_physics var physics_mask := 0xffffffff


func raycast(origin: Vector3, direction: Vector3, max_results: int = 1, trackable_types: int = 0xffffffff) -> Array[XRHit]:
	var hits := XRFoundation.try_raycast(origin, direction, max_distance, physics_mask)
	hits = _filter_hits(hits, trackable_types)
	if max_results > 0 and hits.size() > max_results:
		hits = hits.slice(0, max_results)
	if not hits.is_empty():
		raycast_hit.emit(hits[0])
	return hits


func screen_raycast(camera: Camera3D, screen_position: Vector2, max_results: int = 1, trackable_types: int = 0xffffffff) -> Array[XRHit]:
	if camera == null:
		var hits: Array[XRHit] = []
		return hits
	var origin := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	return raycast(origin, direction, max_results, trackable_types)


func raycast_to_list(origin: Vector3, direction: Vector3, results: Array, max_results: int = 0, trackable_types: int = 0xffffffff) -> bool:
	var hits := raycast(origin, direction, max_results, trackable_types)
	results.clear()
	for hit in hits:
		results.append(hit)
	return not hits.is_empty()


func screen_raycast_to_list(camera: Camera3D, screen_position: Vector2, results: Array, max_results: int = 0, trackable_types: int = 0xffffffff) -> bool:
	var hits := screen_raycast(camera, screen_position, max_results, trackable_types)
	results.clear()
	for hit in hits:
		results.append(hit)
	return not hits.is_empty()


func raycast_from_screen(camera: Camera3D, screen_position: Vector2, results: Array, trackable_types: int = 0xffffffff) -> bool:
	return screen_raycast_to_list(camera, screen_position, results, 0, trackable_types)


func RaycastToList(origin: Vector3, direction: Vector3, results: Array, max_results: int = 0, trackable_types: int = 0xffffffff) -> bool:
	return raycast_to_list(origin, direction, results, max_results, trackable_types)


func ScreenRaycastToList(camera: Camera3D, screen_position: Vector2, results: Array, max_results: int = 0, trackable_types: int = 0xffffffff) -> bool:
	return screen_raycast_to_list(camera, screen_position, results, max_results, trackable_types)


func RaycastFromScreen(camera: Camera3D, screen_position: Vector2, results: Array, trackable_types: int = 0xffffffff) -> bool:
	return raycast_from_screen(camera, screen_position, results, trackable_types)


func RaycastScreenPoint(camera: Camera3D, screen_position: Vector2, results: Array, trackable_types: int = 0xffffffff) -> bool:
	return raycast_from_screen(camera, screen_position, results, trackable_types)


func RaycastList(camera: Camera3D, screen_position: Vector2, results: Array, trackable_types: int = 0xffffffff) -> bool:
	return raycast_from_screen(camera, screen_position, results, trackable_types)


func RaycastScreen(camera: Camera3D, screen_position: Vector2, results: Array, trackable_types: int = 0xffffffff) -> bool:
	return raycast_from_screen(camera, screen_position, results, trackable_types)


func Raycast(origin: Vector3, direction: Vector3, max_results: int = 1, trackable_types: int = 0xffffffff) -> Array[XRHit]:
	return raycast(origin, direction, max_results, trackable_types)


func ScreenRaycast(camera: Camera3D, screen_position: Vector2, max_results: int = 1, trackable_types: int = 0xffffffff) -> Array[XRHit]:
	return screen_raycast(camera, screen_position, max_results, trackable_types)


func TryRaycast(origin: Vector3, direction: Vector3, results: Array, max_results: int = 0, trackable_types: int = 0xffffffff) -> bool:
	return raycast_to_list(origin, direction, results, max_results, trackable_types)


func TryScreenRaycast(camera: Camera3D, screen_position: Vector2, results: Array, max_results: int = 0, trackable_types: int = 0xffffffff) -> bool:
	return screen_raycast_to_list(camera, screen_position, results, max_results, trackable_types)


func _filter_hits(hits: Array[XRHit], trackable_types: int) -> Array[XRHit]:
	if trackable_types == 0xffffffff:
		return hits

	var filtered: Array[XRHit] = []
	for hit in hits:
		if _trackable_type_matches(int(hit.trackable_type), trackable_types):
			filtered.append(hit)
	return filtered


func _trackable_type_matches(hit_type: int, requested_types: int) -> bool:
	if requested_types == hit_type:
		return true
	if hit_type >= 0 and (requested_types & (1 << hit_type)) != 0:
		return true
	return hit_type != 0 and (requested_types & hit_type) != 0
