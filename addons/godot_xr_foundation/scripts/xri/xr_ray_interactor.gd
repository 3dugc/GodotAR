extends RayCast3D
class_name XRRayInteractor

signal hover_entered(target: XRGrabInteractable)
signal hover_exited(target: XRGrabInteractable)
signal select_entered(target: XRGrabInteractable)
signal select_exited(target: XRGrabInteractable)

@export var select_action: StringName = &"xr_select"
@export var auto_force_update := true

var hover_target: XRGrabInteractable = null
var selected_target: XRGrabInteractable = null


func _physics_process(_delta: float) -> void:
	if auto_force_update:
		force_raycast_update()

	var next_target := _find_interactable(get_collider() if is_colliding() else null)
	if next_target != hover_target:
		if hover_target:
			hover_exited.emit(hover_target)
		hover_target = next_target
		if hover_target:
			hover_entered.emit(hover_target)

	if InputMap.has_action(select_action):
		if Input.is_action_just_pressed(select_action):
			select()
		elif Input.is_action_just_released(select_action):
			release()


func select() -> void:
	if selected_target or hover_target == null:
		return
	selected_target = hover_target
	selected_target.on_select_enter(self)
	select_entered.emit(selected_target)


func release() -> void:
	if selected_target == null:
		return
	var released := selected_target
	selected_target.on_select_exit(self)
	selected_target = null
	select_exited.emit(released)


func _find_interactable(candidate: Object) -> XRGrabInteractable:
	if candidate == null or not (candidate is Node):
		return null

	var node: Node = candidate
	while node:
		if node is XRGrabInteractable:
			return node
		node = node.get_parent()
	return null

