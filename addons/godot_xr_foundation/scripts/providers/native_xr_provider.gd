extends XRProvider
class_name NativeXRProvider

var interface_names: Array[StringName] = []
var singleton_names: Array[StringName] = []
var plugin_singleton: Object = null


func configure(p_owner: Node, p_backend: int, options: Dictionary = {}) -> void:
	super.configure(p_owner, p_backend, options)
	match p_backend:
		XRFoundationTypes.Backend.ARCORE:
			display_name = &"ARCore"
			interface_names = _to_string_name_array(options.get("arcore_interface_names", ["ARCore", "GodotARCore", "ARCoreInterface"]))
			singleton_names = _to_string_name_array(options.get("arcore_singleton_names", ["GodotARCore", "ARCore", "ARCorePlugin"]))
		XRFoundationTypes.Backend.ARKIT:
			display_name = &"ARKit"
			interface_names = _to_string_name_array(options.get("arkit_interface_names", ["ARKit", "GodotARKit", "ARKitInterface"]))
			singleton_names = _to_string_name_array(options.get("arkit_singleton_names", ["GodotARKit", "ARKit", "ARKitPlugin"]))


func is_supported() -> bool:
	return _find_interface() != null or _find_singleton() != null


func get_provider_source() -> StringName:
	if _find_interface() != null:
		return &"XRInterface"
	if _find_singleton() != null:
		return &"Native Singleton"
	return &"Native Plugin"


func check_availability(options: Dictionary = {}) -> Dictionary:
	var report := super.check_availability(options)
	var singleton := _current_singleton()
	report["interface_names"] = _string_names_to_strings(interface_names)
	report["singleton_names"] = _string_names_to_strings(singleton_names)
	report["interface_registered"] = _find_interface() != null
	report["singleton_registered"] = singleton != null
	if singleton:
		report.merge(_singleton_availability(singleton), true)
	return report


func install(_options: Dictionary = {}) -> bool:
	plugin_singleton = _current_singleton()
	if plugin_singleton:
		return _call_first_bool(plugin_singleton, ["install", "request_install", "request_arcore_install"])
	return is_supported()


func get_capabilities(options: Dictionary = {}) -> Dictionary:
	var capabilities := super.get_capabilities(options)
	var xr_iface := _find_interface()
	var singleton := _current_singleton()
	var plugin_available := xr_iface != null or singleton != null

	capabilities["session"] = plugin_available
	capabilities["tracking"] = plugin_available
	capabilities["camera_background"] = plugin_available
	capabilities["passthrough"] = plugin_available
	capabilities["raycast"] = plugin_available
	capabilities["plane_detection"] = plugin_available
	capabilities["anchors"] = plugin_available
	capabilities["persistent_anchors"] = _singleton_has_any(singleton, ["load_anchor", "save_anchor", "try_load_anchor"])
	capabilities["light_estimation"] = _singleton_has_any(singleton, ["get_light_estimate", "get_light_estimation"])
	capabilities["depth"] = _singleton_has_any(singleton, ["get_depth_texture", "get_depth_image"])
	capabilities["image_tracking"] = _singleton_has_any(singleton, ["add_reference_image", "get_tracked_images"])
	capabilities["ar_product_path"] = plugin_available
	capabilities["environment_blend_modes"] = _environment_blend_mode_names(xr_iface)
	capabilities["native_plugin"] = plugin_available
	capabilities["device_profile"] = String(options.get("platform_hint", String(display_name).to_lower()))
	capabilities["runtime"] = String(display_name)
	if backend == XRFoundationTypes.Backend.ARCORE:
		capabilities["arcore_supported"] = plugin_available
	if backend == XRFoundationTypes.Backend.ARKIT:
		capabilities["arkit_supported"] = plugin_available
	if singleton and singleton.has_method("get_capabilities"):
		var raw: Variant = singleton.call("get_capabilities")
		if raw is Dictionary:
			capabilities.merge(raw, true)
	return capabilities


func start(options: Dictionary = {}) -> bool:
	xr_interface = _find_interface()
	if xr_interface:
		apply_environment_blend(options)
		if not xr_interface.is_initialized():
			if not xr_interface.initialize():
				last_error = "%s initialize() returned false." % String(display_name)
				return false
		XRServer.primary_interface = xr_interface
		if owner and owner.get_viewport():
			owner.get_viewport().use_xr = true
		last_error = ""
		return true

	plugin_singleton = _find_singleton()
	if plugin_singleton:
		if plugin_singleton.has_method("initialize"):
			var init_result: Variant = plugin_singleton.call("initialize")
			if typeof(init_result) == TYPE_BOOL and not bool(init_result):
				last_error = "%s initialize() returned false." % String(display_name)
				return false
		if not _call_first_bool(plugin_singleton, ["start_session", "start", "resume"]):
			last_error = "%s start method returned false." % String(display_name)
			return false
		last_error = ""
		return true

	last_error = "%s plugin was not found. Install or build the native plugin and expose either an XRInterface or a singleton bridge." % String(display_name)
	return false


func stop() -> void:
	if plugin_singleton:
		_call_first_bool(plugin_singleton, ["pause", "stop", "stop_session", "deinitialize"])
	plugin_singleton = null
	super.stop()


func get_tracking_status() -> int:
	if xr_interface:
		return super.get_tracking_status()

	var singleton := _current_singleton()
	if singleton:
		for method in ["get_tracking_status", "get_tracking_state"]:
			if singleton.has_method(method):
				return _tracking_status_from_variant(singleton.call(method))
		if singleton.has_method("is_running") and bool(singleton.call("is_running")):
			return XRInterface.XR_NORMAL_TRACKING
		if singleton.has_method("get_capabilities"):
			var raw: Variant = singleton.call("get_capabilities")
			if raw is Dictionary:
				if bool(raw.get("arkit_running", false)) or bool(raw.get("tracking", false)):
					return XRInterface.XR_NORMAL_TRACKING

	return super.get_tracking_status()


func get_not_tracking_reason() -> int:
	if xr_interface:
		return super.get_not_tracking_reason()

	var singleton := _current_singleton()
	if singleton:
		for method in ["get_not_tracking_reason", "get_tracking_reason", "get_arkit_tracking_reason"]:
			if singleton.has_method(method):
				return _not_tracking_reason_from_variant(singleton.call(method))
		if singleton.has_method("get_capabilities"):
			var raw: Variant = singleton.call("get_capabilities")
			if raw is Dictionary:
				for key in ["arkit_tracking_reason", "not_tracking_reason", "tracking_reason", "tracking_state_reason"]:
					if raw.has(key):
						return _not_tracking_reason_from_variant(raw.get(key))

	return super.get_not_tracking_reason()


func get_planes() -> Array[ARPlane]:
	var singleton := _current_singleton()
	if singleton:
		for method in ["get_planes", "get_detected_planes"]:
			if singleton.has_method(method):
				return _convert_planes(singleton.call(method))
	return super.get_planes()


func try_raycast(origin: Vector3, direction: Vector3, max_distance: float = 20.0, mask: int = 0xffffffff) -> Array[XRHit]:
	var singleton := _current_singleton()
	if singleton:
		for method in ["try_raycast", "raycast", "hit_test"]:
			if singleton.has_method(method):
				var raw: Variant = _call_raycast_method(singleton, method, origin, direction, max_distance, mask)
				var converted := _convert_hits(raw)
				if not converted.is_empty():
					return converted
	return super.try_raycast(origin, direction, max_distance, mask)


func create_anchor(transform: Transform3D, attached_trackable: ARTrackable = null) -> ARAnchor:
	var singleton := _current_singleton()
	if singleton:
		for method in ["create_anchor", "add_anchor"]:
			if singleton.has_method(method):
				var raw: Variant = _call_create_anchor_method(singleton, method, transform, attached_trackable)
				return _convert_anchor(raw, transform)
	return super.create_anchor(transform, attached_trackable)


func _find_interface() -> XRInterface:
	for interface_name in interface_names:
		var found := XRServer.find_interface(interface_name)
		if found:
			return found
	return null


func _find_singleton() -> Object:
	for singleton_name in singleton_names:
		if Engine.has_singleton(singleton_name):
			return Engine.get_singleton(singleton_name)
	return null


func _current_singleton() -> Object:
	if plugin_singleton:
		return plugin_singleton
	plugin_singleton = _find_singleton()
	return plugin_singleton


func _call_first_bool(target: Object, methods: Array) -> bool:
	for method in methods:
		if target.has_method(method):
			var result: Variant = target.call(method)
			if typeof(result) == TYPE_BOOL:
				return bool(result)
			return true
	return true


func _call_raycast_method(target: Object, method: String, origin: Vector3, direction: Vector3, max_distance: float, mask: int) -> Variant:
	var arg_count := _method_argument_count(target, method)
	if arg_count >= 4:
		return target.call(method, origin, direction, max_distance, mask)
	if arg_count == 2:
		return target.call(method, origin, direction)
	if arg_count >= 0 and arg_count < 2:
		return []
	return target.call(method, origin, direction, max_distance)


func _call_create_anchor_method(target: Object, method: String, transform: Transform3D, attached_trackable: ARTrackable) -> Variant:
	var arg_count := _method_argument_count(target, method)
	if arg_count >= 2 or arg_count < 0:
		return target.call(method, transform, attached_trackable)
	if arg_count == 1:
		return target.call(method, transform)
	return null


func _method_argument_count(target: Object, method: String) -> int:
	for info in target.get_method_list():
		if String(info.get("name", "")) == method:
			var args: Variant = info.get("args", [])
			if args is Array:
				return args.size()
			return -1
	return -1


func _singleton_availability(singleton: Object) -> Dictionary:
	var report := {}
	for method in ["check_availability", "is_supported", "is_session_supported", "is_available"]:
		if singleton.has_method(method):
			var result: Variant = singleton.call(method)
			if result is Dictionary:
				report.merge(result, true)
			elif typeof(result) == TYPE_BOOL:
				report["supported"] = bool(result)
				report["availability"] = "Supported" if bool(result) else "Unsupported"
			report["availability_method"] = method
			return report
	return report


func _tracking_status_from_variant(value: Variant) -> int:
	if typeof(value) == TYPE_INT:
		return int(value)

	var text := String(value).strip_edges().to_lower()
	match text:
		"tracking", "running", "normal", "normal_tracking":
			return XRInterface.XR_NORMAL_TRACKING
		"not_tracking", "not tracking", "stopped", "none":
			return XRInterface.XR_NOT_TRACKING
		"limited", "unknown", "unknown_tracking":
			return XRInterface.XR_UNKNOWN_TRACKING
		_:
			return XRInterface.XR_UNKNOWN_TRACKING


func _not_tracking_reason_from_variant(value: Variant) -> int:
	if typeof(value) == TYPE_INT:
		return int(value)
	return XRFoundationTypes.not_tracking_reason_from_string(String(value))


func _convert_hits(raw: Variant) -> Array[XRHit]:
	var hits: Array[XRHit] = []
	if raw is Array:
		for item in raw:
			if item is XRHit:
				hits.append(item)
			elif item is Dictionary:
				hits.append(XRHit.from_dictionary(item))
	elif raw is Dictionary:
		hits.append(XRHit.from_dictionary(raw))
	return hits


func _convert_planes(raw: Variant) -> Array[ARPlane]:
	var planes: Array[ARPlane] = []
	if raw is Array:
		for item in raw:
			if item is ARPlane:
				planes.append(item)
			elif item is Dictionary:
				planes.append(_plane_from_dictionary(item))
	elif raw is Dictionary:
		planes.append(_plane_from_dictionary(raw))
	return planes


func _convert_anchor(raw: Variant, fallback_transform: Transform3D) -> ARAnchor:
	if raw is ARAnchor:
		return raw
	if raw is Dictionary:
		var data: Dictionary = raw.duplicate()
		if not data.has("trackable_id") and not data.has("id") and not data.has("anchor_id"):
			data["trackable_id"] = _make_id(&"native_anchor")
		if not data.has("transform") and not data.has("pose"):
			data["transform"] = fallback_transform
		return ARAnchor.from_dictionary(data)
	return ARAnchor.new(_make_id(&"native_anchor"), fallback_transform, raw)


func _plane_from_dictionary(data: Dictionary) -> ARPlane:
	var plane := ARPlane.new(
		StringName(data.get("trackable_id", data.get("id", ""))),
		data.get("transform", Transform3D.IDENTITY),
		data.get("size", Vector2.ONE),
		StringName(data.get("alignment", "unknown")),
		data.get("raw_tracker", data)
	)
	plane.label = StringName(data.get("label", ""))
	plane.tracking_state = int(data.get("tracking_state", XRFoundationTypes.TrackingState.TRACKING))
	return plane


func _to_string_name_array(value: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if value is Array:
		for item in value:
			result.append(StringName(item))
	else:
		result.append(StringName(value))
	return result


func _string_names_to_strings(value: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for item in value:
		result.append(String(item))
	return result


func _singleton_has_any(singleton: Object, methods: Array[String]) -> bool:
	if singleton == null:
		return false
	for method in methods:
		if singleton.has_method(method):
			return true
	return false
