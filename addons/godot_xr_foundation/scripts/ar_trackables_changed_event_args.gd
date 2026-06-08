extends RefCounted
class_name ARTrackablesChangedEventArgs

var added: Array = []
var updated: Array = []
var removed: Array = []


func _init(p_added: Array = [], p_updated: Array = [], p_removed: Array = []) -> void:
	added = p_added.duplicate()
	updated = p_updated.duplicate()
	removed = p_removed.duplicate()


func is_empty() -> bool:
	return added.is_empty() and updated.is_empty() and removed.is_empty()


func to_dictionary() -> Dictionary:
	return {
		"added": added,
		"updated": updated,
		"removed": removed,
	}
