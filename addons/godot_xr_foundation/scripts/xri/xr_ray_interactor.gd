extends RayCast3D
class_name XRRayInteractor

signal hover_entering(target: XRGrabInteractable)
signal hover_entered(target: XRGrabInteractable)
signal hover_exiting(target: XRGrabInteractable)
signal hover_exited(target: XRGrabInteractable)
signal select_entering(target: XRGrabInteractable)
signal select_entered(target: XRGrabInteractable)
signal select_exiting(target: XRGrabInteractable)
signal select_exited(target: XRGrabInteractable)
signal activated(target: XRGrabInteractable)
signal deactivated(target: XRGrabInteractable)
signal hoverEntering(target: XRGrabInteractable)
signal hoverEntered(target: XRGrabInteractable)
signal hoverExiting(target: XRGrabInteractable)
signal hoverExited(target: XRGrabInteractable)
signal selectEntering(target: XRGrabInteractable)
signal selectEntered(target: XRGrabInteractable)
signal selectExiting(target: XRGrabInteractable)
signal selectExited(target: XRGrabInteractable)
signal firstSelectEntered(target: XRGrabInteractable)
signal lastSelectExited(target: XRGrabInteractable)

@export var select_action: StringName = &"xr_select"
@export var activate_action: StringName = &"xr_activate"
@export var interaction_manager_path: NodePath
@export var ar_raycast_manager_path: NodePath
@export var max_raycast_distance := 10.0
@export var ar_trackable_types := XRFoundationTypes.TRACKABLE_TYPE_PLANES
@export var keep_selected_target_valid := true
@export var enable_interaction_with_ui_gameobjects := false
@export var auto_force_update := true

var interaction_manager: XRInteractionManager = null
var hover_target: XRGrabInteractable = null
var selected_target: XRGrabInteractable = null


func _ready() -> void:
	var ray_direction := target_position.normalized()
	if ray_direction == Vector3.ZERO:
		ray_direction = Vector3.FORWARD
	target_position = ray_direction * max_raycast_distance
	interaction_manager = _resolve_interaction_manager()
	if interaction_manager:
		interaction_manager.register_interactor(self)


func _exit_tree() -> void:
	if interaction_manager:
		interaction_manager.unregister_interactor(self)


func _physics_process(_delta: float) -> void:
	if auto_force_update:
		force_raycast_update()

	var next_target := _find_interactable(get_collider() if is_colliding() else null)
	if selected_target and not keep_selected_target_valid and next_target != selected_target:
		release()

	if interaction_manager:
		interaction_manager.set_hover_target(self, next_target)
	else:
		_set_hover_target_direct(next_target)

	if InputMap.has_action(select_action):
		if Input.is_action_just_pressed(select_action):
			select()
		elif Input.is_action_just_released(select_action):
			release()
	if InputMap.has_action(activate_action):
		if Input.is_action_just_pressed(activate_action):
			activate()
		elif Input.is_action_just_released(activate_action):
			deactivate()


func select() -> bool:
	if interaction_manager:
		return interaction_manager.select(self)
	if selected_target or hover_target == null:
		return false
	if hover_target.IsSelected():
		return false
	select_entering.emit(hover_target)
	selectEntering.emit(hover_target)
	selected_target = hover_target
	selected_target.on_select_enter(self)
	select_entered.emit(selected_target)
	selectEntered.emit(selected_target)
	firstSelectEntered.emit(selected_target)
	return true


func release() -> bool:
	if interaction_manager:
		return interaction_manager.release(self)
	if selected_target == null:
		return false
	var released := selected_target
	select_exiting.emit(released)
	selectExiting.emit(released)
	selected_target.on_select_exit(self)
	selected_target = null
	select_exited.emit(released)
	selectExited.emit(released)
	lastSelectExited.emit(released)
	return true


func activate() -> bool:
	if interaction_manager:
		return interaction_manager.activate(self)
	var target := selected_target if selected_target else hover_target
	if target == null:
		return false
	if target.has_method("on_activate"):
		target.on_activate(self)
	activated.emit(target)
	return true


func deactivate() -> bool:
	if interaction_manager:
		return interaction_manager.deactivate(self)
	var target := selected_target if selected_target else hover_target
	if target == null:
		return false
	if target.has_method("on_deactivate"):
		target.on_deactivate(self)
	deactivated.emit(target)
	return true


func TryGetCurrent3DRaycastHit(result: Variant = null, raycast_endpoint_index: Array = []) -> Variant:
	var hit := _current_3d_raycast_hit()
	if result is Array:
		result.clear()
		raycast_endpoint_index.clear()
		if bool(hit.get("success", false)):
			result.append(hit)
			raycast_endpoint_index.append(int(hit.get("raycastEndpointIndex", 0)))
			return true
		return false
	return hit


func TryGetCurrentARRaycastHit(result: Array = [], raycast_endpoint_index: Array = []) -> bool:
	var hit := _current_ar_raycast_hit()
	result.clear()
	raycast_endpoint_index.clear()
	if not bool(hit.get("success", false)):
		return false
	result.append(hit)
	raycast_endpoint_index.append(int(hit.get("raycastEndpointIndex", 0)))
	return true


func TryGetCurrentRaycast(raycast_hit: Array = [], raycast_hit_index: Array = [], ui_raycast_hit: Array = [], ui_raycast_hit_index: Array = [], is_ui_hit_closest: Array = [], ar_raycast_hit: Array = [], ar_raycast_hit_index: Array = [], is_ar_hit_closest: Array = []) -> bool:
	var hit := _current_3d_raycast_hit()
	var ar_hit := _current_ar_raycast_hit()
	var has_3d := bool(hit.get("success", false))
	var has_ar := bool(ar_hit.get("success", false))
	raycast_hit.clear()
	raycast_hit_index.clear()
	ui_raycast_hit.clear()
	ui_raycast_hit_index.clear()
	is_ui_hit_closest.clear()
	ar_raycast_hit.clear()
	ar_raycast_hit_index.clear()
	is_ar_hit_closest.clear()
	if not has_3d and not has_ar:
		is_ui_hit_closest.append(false)
		is_ar_hit_closest.append(false)
		return false
	if has_3d:
		raycast_hit.append(hit)
		raycast_hit_index.append(int(hit.get("raycastEndpointIndex", 0)))
	if has_ar:
		ar_raycast_hit.append(ar_hit)
		ar_raycast_hit_index.append(int(ar_hit.get("raycastEndpointIndex", 0)))
	is_ui_hit_closest.append(false)
	is_ar_hit_closest.append(_is_ar_hit_closest(hit, ar_hit))
	return true


func TryGetCurrentUIRaycastResult(result: Array = [], raycast_endpoint_index: Array = []) -> bool:
	result.clear()
	raycast_endpoint_index.clear()
	return false


func GetCurrent3DRaycastHit() -> Dictionary:
	return _current_3d_raycast_hit()


func GetCurrentARRaycastHit() -> Dictionary:
	return _current_ar_raycast_hit()


func TryGetHitInfo(position: Array = [], normal: Array = [], position_in_line: Array = [], is_valid_target: Array = []) -> bool:
	var hit := _current_3d_raycast_hit()
	if not bool(hit.get("success", false)):
		hit = _current_ar_raycast_hit()
	position.clear()
	normal.clear()
	position_in_line.clear()
	is_valid_target.clear()
	if not bool(hit.get("success", false)):
		is_valid_target.append(false)
		return false
	position.append(hit.get("position", Vector3.ZERO))
	normal.append(hit.get("normal", Vector3.UP))
	position_in_line.append(int(hit.get("raycastEndpointIndex", 0)))
	is_valid_target.append(true)
	return true


func IsOverUIGameObject() -> bool:
	return false


func _current_3d_raycast_hit() -> Dictionary:
	if not is_colliding():
		return {"success": false}
	var position := get_collision_point()
	return {
		"success": true,
		"collider": get_collider(),
		"position": position,
		"normal": get_collision_normal(),
		"distance": global_transform.origin.distance_to(position),
		"raycastEndpointIndex": 0,
		"source": "3d",
		"interactable": _find_interactable(get_collider()),
	}


func _current_ar_raycast_hit() -> Dictionary:
	var manager := _resolve_ar_raycast_manager()
	if manager == null:
		return {"success": false, "source": "ar"}
	var results: Array = []
	var ray := {
		"origin": global_transform.origin,
		"direction": _ray_direction_world(),
	}
	if not bool(manager.Raycast(ray, results, ar_trackable_types)):
		return {"success": false, "source": "ar"}
	if results.is_empty():
		return {"success": false, "source": "ar"}
	var raw_hit: Variant = results[0]
	var hit := {}
	if raw_hit is XRHit:
		hit = raw_hit.to_dictionary()
	elif raw_hit is Dictionary:
		hit = raw_hit.duplicate()
	else:
		return {"success": false, "source": "ar"}
	hit["success"] = true
	hit["source"] = "ar"
	hit["raycastEndpointIndex"] = int(hit.get("raycastEndpointIndex", 0))
	return hit


func _ray_direction_world() -> Vector3:
	var local_direction := target_position.normalized()
	if local_direction == Vector3.ZERO:
		local_direction = Vector3.FORWARD
	return (global_transform.basis * local_direction).normalized()


func _is_ar_hit_closest(hit: Dictionary, ar_hit: Dictionary) -> bool:
	if not bool(ar_hit.get("success", false)):
		return false
	if not bool(hit.get("success", false)):
		return true
	return float(ar_hit.get("distance", INF)) <= float(hit.get("distance", INF))


func GetValidTargets(results: Array = []) -> Array:
	var target := _find_interactable(get_collider() if is_colliding() else null)
	if target and not results.has(target):
		results.append(target)
	return results


func _find_interactable(candidate: Object) -> XRGrabInteractable:
	if candidate == null or not (candidate is Node):
		return null

	var node: Node = candidate
	while node:
		if node is XRGrabInteractable:
			return node
		node = node.get_parent()
	return null


func _resolve_interaction_manager() -> XRInteractionManager:
	if interaction_manager_path != NodePath():
		var manager := get_node_or_null(interaction_manager_path)
		if manager is XRInteractionManager:
			return manager
	var root := get_tree().current_scene if get_tree() else null
	if root:
		var found := _find_manager_in_tree(root)
		if found:
			return found
	return null


func _resolve_ar_raycast_manager() -> ARRaycastManager:
	if ar_raycast_manager_path != NodePath():
		var manager := get_node_or_null(ar_raycast_manager_path)
		if manager is ARRaycastManager:
			return manager
	var root := get_tree().current_scene if get_tree() else null
	if root:
		var found := _find_ar_raycast_manager_in_tree(root)
		if found:
			return found
	return null


func _find_ar_raycast_manager_in_tree(node: Node) -> ARRaycastManager:
	if node is ARRaycastManager:
		return node
	for child in node.get_children():
		var found := _find_ar_raycast_manager_in_tree(child)
		if found:
			return found
	return null


func _find_manager_in_tree(node: Node) -> XRInteractionManager:
	if node is XRInteractionManager:
		return node
	for child in node.get_children():
		var found := _find_manager_in_tree(child)
		if found:
			return found
	return null


func _set_hover_target_direct(next_target: XRGrabInteractable) -> void:
	if next_target == hover_target:
		return
	if hover_target:
		hover_exiting.emit(hover_target)
		hoverExiting.emit(hover_target)
		hover_target.on_hover_exit(self)
		hover_exited.emit(hover_target)
		hoverExited.emit(hover_target)
	hover_target = next_target
	if hover_target:
		hover_entering.emit(hover_target)
		hoverEntering.emit(hover_target)
		hover_target.on_hover_enter(self)
		hover_entered.emit(hover_target)
		hoverEntered.emit(hover_target)


func _emit_hover_entered(target: XRGrabInteractable) -> void:
	hover_entering.emit(target)
	hoverEntering.emit(target)
	hover_entered.emit(target)
	hoverEntered.emit(target)


func _emit_hover_exited(target: XRGrabInteractable) -> void:
	hover_exiting.emit(target)
	hoverExiting.emit(target)
	hover_exited.emit(target)
	hoverExited.emit(target)


func _emit_select_entered(target: XRGrabInteractable) -> void:
	select_entering.emit(target)
	selectEntering.emit(target)
	select_entered.emit(target)
	selectEntered.emit(target)
	firstSelectEntered.emit(target)


func _emit_select_exited(target: XRGrabInteractable) -> void:
	select_exiting.emit(target)
	selectExiting.emit(target)
	select_exited.emit(target)
	selectExited.emit(target)
	lastSelectExited.emit(target)


func _emit_activated(target: XRGrabInteractable) -> void:
	activated.emit(target)


func _emit_deactivated(target: XRGrabInteractable) -> void:
	deactivated.emit(target)
