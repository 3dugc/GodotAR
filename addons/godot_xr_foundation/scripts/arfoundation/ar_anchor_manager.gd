extends Node
class_name ARAnchorManager

signal anchor_added(anchor: ARAnchor)
signal anchor_removed(anchor: ARAnchor)

@export var anchors_parent_path: NodePath

var anchors: Dictionary = {}


func add_anchor(transform: Transform3D, attached_trackable: ARTrackable = null) -> ARAnchor:
	var anchor := XRFoundation.create_anchor(transform, attached_trackable)
	var parent := _get_anchor_parent()
	if parent:
		var node := Node3D.new()
		node.name = "ARAnchor_%s" % String(anchor.trackable_id)
		parent.add_child(node)
		node.global_transform = transform
		anchor.node = node
	anchors[anchor.trackable_id] = anchor
	anchor_added.emit(anchor)
	return anchor


func remove_anchor(anchor_or_id: Variant) -> void:
	var id := &""
	if anchor_or_id is ARAnchor:
		id = anchor_or_id.trackable_id
	else:
		id = StringName(str(anchor_or_id))
	if not anchors.has(id):
		return

	var anchor: ARAnchor = anchors[id]
	if anchor.node and is_instance_valid(anchor.node):
		anchor.node.queue_free()
	anchors.erase(id)
	anchor_removed.emit(anchor)


func _get_anchor_parent() -> Node3D:
	if anchors_parent_path != NodePath():
		var configured := get_node_or_null(anchors_parent_path)
		if configured is Node3D:
			return configured
	var parent := get_parent()
	if parent is Node3D:
		return parent
	return null
