extends Node
class_name ARRaycastManager

signal raycast_hit(hit: XRHit)

@export var max_distance := 20.0
@export_flags_3d_physics var physics_mask := 0xffffffff


func raycast(origin: Vector3, direction: Vector3, max_results: int = 1) -> Array[XRHit]:
	var hits := XRFoundation.try_raycast(origin, direction, max_distance, physics_mask)
	if max_results > 0 and hits.size() > max_results:
		hits = hits.slice(0, max_results)
	if not hits.is_empty():
		raycast_hit.emit(hits[0])
	return hits


func screen_raycast(camera: Camera3D, screen_position: Vector2, max_results: int = 1) -> Array[XRHit]:
	if camera == null:
		var hits: Array[XRHit] = []
		return hits
	var origin := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	return raycast(origin, direction, max_results)


func Raycast(origin: Vector3, direction: Vector3, max_results: int = 1) -> Array[XRHit]:
	return raycast(origin, direction, max_results)


func ScreenRaycast(camera: Camera3D, screen_position: Vector2, max_results: int = 1) -> Array[XRHit]:
	return screen_raycast(camera, screen_position, max_results)
