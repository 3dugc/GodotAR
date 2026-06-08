extends Node3D
class_name XRGrabInteractable

signal select_entered(interactor: Node)
signal select_exited(interactor: Node)

@export var reparent_on_grab := true
@export var keep_global_transform := true

var selected_by: Node3D = null
var _original_parent: Node = null


func on_select_enter(interactor: Node3D) -> void:
	if selected_by:
		return
	selected_by = interactor
	_original_parent = get_parent()
	if reparent_on_grab and interactor:
		var global := global_transform
		get_parent().remove_child(self)
		interactor.add_child(self)
		if keep_global_transform:
			global_transform = global
	select_entered.emit(interactor)


func on_select_exit(interactor: Node3D) -> void:
	if selected_by != interactor:
		return
	var global := global_transform
	if reparent_on_grab and _original_parent:
		get_parent().remove_child(self)
		_original_parent.add_child(self)
		if keep_global_transform:
			global_transform = global
	selected_by = null
	_original_parent = null
	select_exited.emit(interactor)

