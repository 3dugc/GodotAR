extends XRProvider
class_name OpenXRProvider

const DEFAULT_INTERFACE_NAME := &"OpenXR"


func configure(p_owner: Node, p_backend: int, options: Dictionary = {}) -> void:
	super.configure(p_owner, p_backend, options)
	display_name = StringName(options.get("openxr_display_name", "OpenXR"))


func is_supported() -> bool:
	return XRServer.find_interface(DEFAULT_INTERFACE_NAME) != null


func start(options: Dictionary = {}) -> bool:
	xr_interface = XRServer.find_interface(DEFAULT_INTERFACE_NAME)
	if xr_interface == null:
		last_error = "OpenXR interface is not registered. Enable OpenXR and install the needed vendor plugin for Android XR/Rokid."
		return false

	apply_environment_blend(options)

	if not xr_interface.is_initialized():
		if not xr_interface.initialize():
			last_error = "OpenXR initialize() returned false."
			return false

	XRServer.primary_interface = xr_interface
	if owner and owner.get_viewport():
		owner.get_viewport().use_xr = true

	if bool(options.get("disable_vsync", true)) and OS.get_name() not in ["Android", "iOS"]:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

	last_error = ""
	return true


func stop() -> void:
	super.stop()


func get_planes() -> Array[ARPlane]:
	var planes: Array[ARPlane] = []
	for tracker_name in _get_all_tracker_names():
		var tracker := XRServer.get_tracker(tracker_name)
		if tracker == null:
			continue
		var tracker_class := tracker.get_class().to_lower()
		if tracker_class.contains("plane"):
			planes.append(_plane_from_tracker(tracker_name, tracker))
	return planes


func _get_all_tracker_names() -> Array[StringName]:
	var names: Array[StringName] = []
	if XRServer.has_method("get_trackers"):
		var trackers: Variant = XRServer.call("get_trackers", 0xffffffff)
		if trackers is Dictionary:
			for key in trackers.keys():
				names.append(StringName(key))
	return names


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

