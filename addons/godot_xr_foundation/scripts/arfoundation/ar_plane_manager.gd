extends Node
class_name ARPlaneManager

const ARTrackablesChangedEventArgs := preload("res://addons/godot_xr_foundation/scripts/ar_trackables_changed_event_args.gd")

signal plane_added(plane: ARPlane)
signal plane_updated(plane: ARPlane)
signal plane_removed(trackable_id: StringName)
signal planes_changed(added: Array, updated: Array, removed: Array)
signal trackables_changed(changes: ARTrackablesChangedEventArgs)
signal trackablesChanged(changes: ARTrackablesChangedEventArgs)

@export var create_anchor_nodes := true
@export var provider_sync_interval := 1.0
@export var xr_origin_path: NodePath
@export var requested_detection_mode: int = XRFoundationTypes.PlaneDetectionMode.EVERYTHING

var planes: Dictionary = {}
var anchor_nodes: Dictionary = {}
var provider_plane_ids: Dictionary = {}
var _provider_sync_elapsed := 0.0


func _ready() -> void:
	var tracker_added := Callable(self, "_on_tracker_added")
	var tracker_removed := Callable(self, "_on_tracker_removed")
	if not XRServer.tracker_added.is_connected(tracker_added):
		XRServer.tracker_added.connect(tracker_added)
	if not XRServer.tracker_removed.is_connected(tracker_removed):
		XRServer.tracker_removed.connect(tracker_removed)

	if not XRFoundation.session_started.is_connected(Callable(self, "_on_session_started")):
		XRFoundation.session_started.connect(_on_session_started)
	set_process(true)
	call_deferred("_sync_provider_planes")


func _process(delta: float) -> void:
	if provider_sync_interval <= 0.0:
		return
	if XRFoundation.state != XRFoundationTypes.SessionState.RUNNING:
		return
	_provider_sync_elapsed += delta
	if _provider_sync_elapsed >= provider_sync_interval:
		_provider_sync_elapsed = 0.0
		_sync_provider_planes()


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


func get_trackables() -> Array[ARPlane]:
	return get_all_planes()


func get_trackables_changed_event_args(added: Array = [], updated: Array = [], removed: Array = []) -> ARTrackablesChangedEventArgs:
	return ARTrackablesChangedEventArgs.new(added, updated, removed)


func get_trackable(trackable_id: Variant) -> ARPlane:
	var id := StringName(str(trackable_id))
	if planes.has(id):
		return planes[id]
	return null


func try_get_trackable(trackable_id: Variant, result: Array = []) -> bool:
	var plane := get_trackable(trackable_id)
	result.clear()
	if plane == null:
		return false
	result.append(plane)
	return true


func get_requested_detection_mode() -> int:
	return requested_detection_mode


func set_requested_detection_mode(value: int) -> void:
	requested_detection_mode = value


func set_requested_detection_mode_name(value: String) -> void:
	requested_detection_mode = XRFoundationTypes.plane_detection_mode_from_string(value, requested_detection_mode)


func get_current_detection_mode() -> int:
	return requested_detection_mode


func GetAllPlanes() -> Array[ARPlane]:
	return get_all_planes()


func GetTrackables() -> Array[ARPlane]:
	return get_trackables()


func GetTrackable(trackable_id: Variant) -> ARPlane:
	return get_trackable(trackable_id)


func TryGetTrackable(trackable_id: Variant, result: Array = []) -> bool:
	return try_get_trackable(trackable_id, result)


func TryGetPlane(trackable_id: Variant, result: Array = []) -> bool:
	return try_get_trackable(trackable_id, result)


func SetRequestedDetectionModeName(value: String) -> void:
	set_requested_detection_mode_name(value)


func sync_provider_planes() -> void:
	_sync_provider_planes()


func SyncProviderPlanes() -> void:
	sync_provider_planes()


func _on_session_started(_backend: int, _display_name: StringName) -> void:
	_sync_provider_planes()


func _sync_provider_planes() -> void:
	var current_ids := {}
	for plane in XRFoundation.get_planes():
		current_ids[plane.trackable_id] = true
		provider_plane_ids[plane.trackable_id] = true
		_add_or_update_plane(plane)
	for trackable_id in provider_plane_ids.keys():
		if current_ids.has(trackable_id):
			continue
		provider_plane_ids.erase(trackable_id)
		_remove_plane(trackable_id)


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
	_remove_plane(tracker_name)
	if anchor_nodes.has(tracker_name):
		var node: Node = anchor_nodes[tracker_name]
		if is_instance_valid(node):
			node.queue_free()
		anchor_nodes.erase(tracker_name)


func _add_or_update_plane(plane: ARPlane) -> void:
	if planes.has(plane.trackable_id):
		planes[plane.trackable_id] = plane
		plane_updated.emit(plane)
		_emit_trackables_changed([], [plane], [])
	else:
		planes[plane.trackable_id] = plane
		plane_added.emit(plane)
		_emit_trackables_changed([plane], [], [])


func _remove_plane(trackable_id: StringName) -> void:
	if planes.has(trackable_id):
		var plane: ARPlane = planes[trackable_id]
		planes.erase(trackable_id)
		plane_removed.emit(trackable_id)
		_emit_trackables_changed([], [], [plane])


func _emit_trackables_changed(added: Array, updated: Array, removed: Array) -> void:
	planes_changed.emit(added, updated, removed)
	var changes := ARTrackablesChangedEventArgs.new(added, updated, removed)
	trackables_changed.emit(changes)
	trackablesChanged.emit(changes)


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
