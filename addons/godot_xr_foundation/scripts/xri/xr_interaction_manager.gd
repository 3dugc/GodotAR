extends Node
class_name XRInteractionManager

signal interactor_registered(interactor: Node)
signal interactor_unregistered(interactor: Node)
signal interactable_registered(interactable: Node)
signal interactable_unregistered(interactable: Node)
signal hover_entering(interactor: Node, interactable: Node)
signal hover_entered(interactor: Node, interactable: Node)
signal hover_exiting(interactor: Node, interactable: Node)
signal hover_exited(interactor: Node, interactable: Node)
signal select_entering(interactor: Node, interactable: Node)
signal select_entered(interactor: Node, interactable: Node)
signal select_exiting(interactor: Node, interactable: Node)
signal select_exited(interactor: Node, interactable: Node)
signal activated(interactor: Node, interactable: Node)
signal deactivated(interactor: Node, interactable: Node)
signal focus_entered(interactor: Node, interactable: Node)
signal focus_exited(interactor: Node, interactable: Node)

var interactors: Array[Node] = []
var interactables: Array[Node] = []


func RegisterInteractor(interactor: Node) -> void:
	register_interactor(interactor)


func UnregisterInteractor(interactor: Node) -> void:
	unregister_interactor(interactor)


func RegisterInteractable(interactable: Node) -> void:
	register_interactable(interactable)


func UnregisterInteractable(interactable: Node) -> void:
	unregister_interactable(interactable)


func register_interactor(interactor: Node) -> void:
	if interactor == null or interactors.has(interactor):
		return
	interactors.append(interactor)
	interactor_registered.emit(interactor)


func unregister_interactor(interactor: Node) -> void:
	if interactor == null:
		return
	if interactor in interactors:
		_release_if_selected(interactor)
		_clear_hover(interactor)
		interactors.erase(interactor)
		interactor_unregistered.emit(interactor)


func register_interactable(interactable: Node) -> void:
	if interactable == null or interactables.has(interactable):
		return
	interactables.append(interactable)
	interactable_registered.emit(interactable)


func unregister_interactable(interactable: Node) -> void:
	if interactable == null:
		return
	for interactor in interactors:
		if interactor.get("selected_target") == interactable:
			release(interactor)
		if interactor.get("hover_target") == interactable:
			set_hover_target(interactor, null)
	interactables.erase(interactable)
	interactable_unregistered.emit(interactable)


func set_hover_target(interactor: Node, next_target: Node) -> void:
	if interactor == null:
		return
	var current: Node = interactor.get("hover_target")
	if current == next_target:
		return

	if current != null:
		hover_exiting.emit(interactor, current)
		if current.has_method("on_hover_exit"):
			current.call("on_hover_exit", interactor)
		if interactor.has_method("_emit_hover_exited"):
			interactor.call("_emit_hover_exited", current)
		hover_exited.emit(interactor, current)

	interactor.set("hover_target", next_target)

	if next_target != null:
		hover_entering.emit(interactor, next_target)
		if next_target.has_method("on_hover_enter"):
			next_target.call("on_hover_enter", interactor)
		if interactor.has_method("_emit_hover_entered"):
			interactor.call("_emit_hover_entered", next_target)
		hover_entered.emit(interactor, next_target)


func select(interactor: Node) -> bool:
	if interactor == null or interactor.get("selected_target") != null:
		return false
	var target: Node = interactor.get("hover_target")
	if target == null:
		return false
	if target.has_method("IsSelected") and bool(target.call("IsSelected")):
		return false
	select_entering.emit(interactor, target)
	if target.has_method("on_select_enter"):
		target.call("on_select_enter", interactor)
	interactor.set("selected_target", target)
	if interactor.has_method("_emit_select_entered"):
		interactor.call("_emit_select_entered", target)
	select_entered.emit(interactor, target)
	return true


func release(interactor: Node) -> bool:
	if interactor == null:
		return false
	var target: Node = interactor.get("selected_target")
	if target == null:
		return false
	select_exiting.emit(interactor, target)
	if target.has_method("on_select_exit"):
		target.call("on_select_exit", interactor)
	interactor.set("selected_target", null)
	if interactor.has_method("_emit_select_exited"):
		interactor.call("_emit_select_exited", target)
	select_exited.emit(interactor, target)
	return true


func activate(interactor: Node) -> bool:
	if interactor == null:
		return false
	var target: Node = interactor.get("selected_target")
	if target == null:
		target = interactor.get("hover_target")
	if target == null:
		return false
	if target.has_method("on_activate"):
		target.call("on_activate", interactor)
	if interactor.has_method("_emit_activated"):
		interactor.call("_emit_activated", target)
	activated.emit(interactor, target)
	return true


func deactivate(interactor: Node) -> bool:
	if interactor == null:
		return false
	var target: Node = interactor.get("selected_target")
	if target == null:
		target = interactor.get("hover_target")
	if target == null:
		return false
	if target.has_method("on_deactivate"):
		target.call("on_deactivate", interactor)
	if interactor.has_method("_emit_deactivated"):
		interactor.call("_emit_deactivated", target)
	deactivated.emit(interactor, target)
	return true


func GetRegisteredInteractors() -> Array[Node]:
	return interactors.duplicate()


func GetRegisteredInteractables() -> Array[Node]:
	return interactables.duplicate()


func _release_if_selected(interactor: Node) -> void:
	if interactor.get("selected_target") != null:
		release(interactor)


func _clear_hover(interactor: Node) -> void:
	if interactor.get("hover_target") != null:
		set_hover_target(interactor, null)
