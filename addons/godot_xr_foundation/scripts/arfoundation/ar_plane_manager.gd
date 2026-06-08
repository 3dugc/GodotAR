extends Node
class_name ARPlaneManager

signal plane_added(plane: ARPlane)
signal plane_updated(plane: ARPlane)
signal plane_removed(trackable_id: StringName)

@export var create_anchor_nodes := true
@export var xr_origin_path: NodePath

var planes: Dictionary = {}
var anchor_nodes: Dictionary = {}


func _ready() -> void:
	var tracker_added := Callable(self, "_on_tracker_added")
	var tracker_removed := Callable(self, "_on_tracker_removed")
	if not XRServer.tracker_added.is_connected(tracker_added):
		XRServer.tracker_added.connect(tracker_added)
	if not XRServer.tracker_removed.is_connected(tracker_removed):
		XRServer.tracker_removed.connect(tracker_removed)

	if not XRFoundation.session_started.is_connected(Callable(self, "_on_session_started")):
		XRFoundation.session_started.connect(_on_session_started)
	call_deferred("_sync_provider_planes")


func _exit_tree() -> void:
	var tracker_added := Callable(self, "_on_tracker_added")
	var tracker_removed := Callable(self, "_on_tracker_removed")
	if XRServer.tracker_added.is_connected(tracker_added):
		XRServer.tracker_added.disconnect(tracker_added)
	if XRServer.tracker_removed.is_connected(tracker_removed):
		XRServer.tracker_removed.disconnect(tracker_removed)


func get_all_planes() -> Array[ARPlane]:
	var result: Array[ARPlane] = []
	for plane in planes.values():
		result.append(plane)
	return result


func _on_session_started(_backend: int, _display_name: StringName) -> void:
	_sync_provider_planes()


func _sync_provider_planes() -> void:
	for plane in XRFoundation.get_planes():
		_add_or_update_plane(plane)


func _on_tracker_added(tracker_name: StringName, _type: int) -> void:
	var tracker := XRServer.get_tracker(tracker_name)
	if tracker == null:
		return
	if not _is_plane_tracker(tracker):
		return

	var plane := _plane_from_tracker(tracker_name, tracker)
	_add_or_update_plane(plane)
	if create_anchor_nodes:
		_create_anchor_node(tracker_name)


func _on_tracker_removed(tracker_name: StringName, _type: int) -> void:
	if planes.has(tracker_name):
		planes.erase(tracker_name)
		plane_removed.emit(tracker_name)
	if anchor_nodes.has(tracker_name):
		var node: Node = anchor_nodes[tracker_name]
		if is_instance_valid(node):
			node.queue_free()
		anchor_nodes.erase(tracker_name)


func _add_or_update_plane(plane: ARPlane) -> void:
	if planes.has(plane.trackable_id):
		planes[plane.trackable_id] = plane
		plane_updated.emit(plane)
	else:
		planes[plane.trackable_id] = plane
		plane_added.emit(plane)


func _is_plane_tracker(tracker: Object) -> bool:
	var class_text := tracker.get_class().to_lower()
	return class_text.contains("plane")


func _plane_from_tracker(tracker_name: StringName, tracker: Object) -> ARPlane:
	var size := Vector2.ONE
	var alignment := &"unknown"
	var label := &""

	if tracker.has_method("get_extents"):
		var extents: Variant = tracker.call("get_extents")
		if extents is Vector2:
			size = extents
		elif extents is Vector3:
			size = Vector2(extents.x, extents.z)
	if tracker.has_method("get_plane_type"):
		alignment = StringName(str(tracker.call("get_plane_type")))
	if tracker.has_method("get_plane_label"):
		label = StringName(str(tracker.call("get_plane_label")))

	var plane := ARPlane.new(tracker_name, Transform3D.IDENTITY, size, alignment, tracker)
	plane.label = label
	return plane


func _create_anchor_node(tracker_name: StringName) -> void:
	if anchor_nodes.has(tracker_name):
		return

	var origin := get_node_or_null(xr_origin_path)
	if origin == null:
		return

	var anchor := XRAnchor3D.new()
	anchor.name = "PlaneAnchor_%s" % String(tracker_name)
	anchor.tracker = tracker_name
	origin.add_child(anchor)
	anchor_nodes[tracker_name] = anchor

