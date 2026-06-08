extends Node
class_name ARAnchorManager

signal anchor_added(anchor: ARAnchor)
signal anchor_removed(anchor: ARAnchor)

@export var anchors_parent_path: NodePath

var anchors: Dictionary = {}


func get_all_anchors() -> Array[ARAnchor]:
	var result: Array[ARAnchor] = []
	for anchor in anchors.values():
		result.append(anchor)
	return result


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


func try_add_anchor(pose: Variant) -> Dictionary:
	var transform := _pose_to_transform(pose)
	var anchor := add_anchor(transform)
	return _anchor_result(anchor != null, anchor)


func try_add_anchor_async(pose: Variant) -> Dictionary:
	return try_add_anchor(pose)


func try_remove_anchor(anchor: ARAnchor) -> bool:
	if anchor == null or not anchors.has(anchor.trackable_id):
		return false
	remove_anchor(anchor)
	return true


func GetAllAnchors() -> Array[ARAnchor]:
	return get_all_anchors()


func AddAnchor(transform: Transform3D, attached_trackable: ARTrackable = null) -> ARAnchor:
	return add_anchor(transform, attached_trackable)


func RemoveAnchor(anchor_or_id: Variant) -> void:
	remove_anchor(anchor_or_id)


func TryAddAnchor(pose: Variant) -> Dictionary:
	return try_add_anchor(pose)


func TryAddAnchorAsync(pose: Variant) -> Dictionary:
	return try_add_anchor_async(pose)


func TryRemoveAnchor(anchor: ARAnchor) -> bool:
	return try_remove_anchor(anchor)


func _get_anchor_parent() -> Node3D:
	if anchors_parent_path != NodePath():
		var configured := get_node_or_null(anchors_parent_path)
		if configured is Node3D:
			return configured
	var parent := get_parent()
	if parent is Node3D:
		return parent
	return null


func _pose_to_transform(pose: Variant) -> Transform3D:
	if pose is Transform3D:
		return pose
	if pose is Node3D:
		return pose.global_transform
	if pose is Vector3:
		return Transform3D(Basis(), pose)
	if pose is Dictionary:
		if pose.has("transform"):
			var transform: Variant = pose["transform"]
			if transform is Transform3D:
				return transform

		var basis := Basis()
		var rotation: Variant = pose.get("rotation", null)
		if rotation is Quaternion:
			basis = Basis(rotation)
		elif rotation is Basis:
			basis = rotation
		elif rotation is Vector3:
			basis = Basis.from_euler(rotation)

		var position: Variant = pose.get("position", pose.get("origin", Vector3.ZERO))
		if position is Vector3:
			return Transform3D(basis, position)

	return Transform3D.IDENTITY


func _anchor_result(success: bool, anchor: ARAnchor = null, error: String = "") -> Dictionary:
	return {
		"success": success,
		"status": "Success" if success else "Failure",
		"result": anchor,
		"anchor": anchor,
		"error": error,
	}
