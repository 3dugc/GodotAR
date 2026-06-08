extends Node3D
class_name XRGrabInteractable

signal hover_entered(interactor: Node)
signal hover_exited(interactor: Node)
signal select_entered(interactor: Node)
signal select_exited(interactor: Node)
signal activated(interactor: Node)
signal deactivated(interactor: Node)
signal focus_entered(interactor: Node)
signal focus_exited(interactor: Node)
signal hoverEntered(interactor: Node)
signal hoverExited(interactor: Node)
signal selectEntered(interactor: Node)
signal selectExited(interactor: Node)
signal firstSelectEntered(interactor: Node)
signal lastSelectExited(interactor: Node)
signal focusEntered(interactor: Node)
signal focusExited(interactor: Node)

@export var interaction_manager_path: NodePath
@export var reparent_on_grab := true
@export var keep_global_transform := true

var selected_by: Node = null
var hovered_by: Array[Node] = []
var focused_by: Node = null
var _original_parent: Node = null
var _interaction_manager: XRInteractionManager = null


func _ready() -> void:
	_interaction_manager = _resolve_interaction_manager()
	if _interaction_manager:
		_interaction_manager.register_interactable(self)


func _exit_tree() -> void:
	if _interaction_manager:
		_interaction_manager.unregister_interactable(self)


func on_select_enter(interactor: Node) -> void:
	if selected_by:
		return
	selected_by = interactor
	_original_parent = get_parent()
	var preserved_global_transform := global_transform
	if reparent_on_grab and interactor:
		get_parent().remove_child(self)
		interactor.add_child(self)
	if keep_global_transform:
		global_transform = preserved_global_transform
	select_entered.emit(interactor)
	selectEntered.emit(interactor)
	firstSelectEntered.emit(interactor)


func on_select_exit(interactor: Node) -> void:
	if selected_by != interactor:
		return
	var preserved_global_transform := global_transform
	if reparent_on_grab and _original_parent:
		get_parent().remove_child(self)
		_original_parent.add_child(self)
		if keep_global_transform:
			global_transform = preserved_global_transform
	selected_by = null
	_original_parent = null
	select_exited.emit(interactor)
	selectExited.emit(interactor)
	lastSelectExited.emit(interactor)


func on_hover_enter(interactor: Node) -> void:
	if interactor == null or hovered_by.has(interactor):
		return
	hovered_by.append(interactor)
	hover_entered.emit(interactor)
	hoverEntered.emit(interactor)


func on_hover_exit(interactor: Node) -> void:
	if interactor == null:
		return
	hovered_by.erase(interactor)
	hover_exited.emit(interactor)
	hoverExited.emit(interactor)


func on_activate(interactor: Node) -> void:
	activated.emit(interactor)


func on_deactivate(interactor: Node) -> void:
	deactivated.emit(interactor)


func on_focus_enter(interactor: Node) -> void:
	focused_by = interactor
	focus_entered.emit(interactor)
	focusEntered.emit(interactor)


func on_focus_exit(interactor: Node) -> void:
	if focused_by != interactor:
		return
	focused_by = null
	focus_exited.emit(interactor)
	focusExited.emit(interactor)


func IsHovered() -> bool:
	return not hovered_by.is_empty()


func IsSelected() -> bool:
	return selected_by != null


func GetOldestInteractorHovering() -> Node:
	return hovered_by[0] if not hovered_by.is_empty() else null


func GetOldestInteractorSelecting() -> Node:
	return selected_by


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


func _find_manager_in_tree(node: Node) -> XRInteractionManager:
	if node is XRInteractionManager:
		return node
	for child in node.get_children():
		var found := _find_manager_in_tree(child)
		if found:
			return found
	return null
