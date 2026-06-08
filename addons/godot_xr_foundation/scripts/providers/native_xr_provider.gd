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
		last_error = ""
		return _call_first_bool(plugin_singleton, ["initialize", "start", "start_session", "resume"])

	last_error = "%s plugin was not found. Install or build the native plugin and expose either an XRInterface or a singleton bridge." % String(display_name)
	return false


func stop() -> void:
	if plugin_singleton:
		_call_first_bool(plugin_singleton, ["pause", "stop", "stop_session"])
	plugin_singleton = null
	super.stop()


func try_raycast(origin: Vector3, direction: Vector3, max_distance: float = 20.0, mask: int = 0xffffffff) -> Array[XRHit]:
	if plugin_singleton:
		for method in ["try_raycast", "raycast", "hit_test"]:
			if plugin_singleton.has_method(method):
				var raw: Variant = plugin_singleton.call(method, origin, direction, max_distance)
				var converted := _convert_hits(raw)
				if not converted.is_empty():
					return converted
	return super.try_raycast(origin, direction, max_distance, mask)


func create_anchor(transform: Transform3D, attached_trackable: ARTrackable = null) -> ARAnchor:
	if plugin_singleton:
		for method in ["create_anchor", "add_anchor"]:
			if plugin_singleton.has_method(method):
				var raw: Variant = plugin_singleton.call(method, transform, attached_trackable)
				var anchor := ARAnchor.new(_make_id(&"native_anchor"), transform, raw)
				return anchor
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


func _call_first_bool(target: Object, methods: Array) -> bool:
	for method in methods:
		if target.has_method(method):
			var result: Variant = target.call(method)
			if typeof(result) == TYPE_BOOL:
				return bool(result)
			return true
	return true


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


func _to_string_name_array(value: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if value is Array:
		for item in value:
			result.append(StringName(item))
	else:
		result.append(StringName(value))
	return result

