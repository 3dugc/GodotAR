extends XRProvider
class_name OpenXRProvider

const DEFAULT_INTERFACE_NAME := &"OpenXR"
const DEFAULT_VENDOR_SINGLETONS := [
	&"OpenXRVendors",
	&"OpenXRFbPassthroughExtension",
	&"OpenXRMeta",
	&"OpenXRFbPassthrough",
	&"OpenXRAndroidXR",
	&"OpenXRPico",
	&"OpenXRHTC",
	&"RokidOpenXR",
]

const PASSTHROUGH_BOOL_METHODS := [
	"is_passthrough_supported",
	"has_passthrough_capability",
	"has_color_passthrough_capability",
	"has_layer_depth_passthrough_capability",
	"is_passthrough_preferred",
	"is_passthrough_started",
	"supports_passthrough",
	"is_camera_passthrough_supported",
	"is_ar_supported",
]

const PASSTHROUGH_EVIDENCE_METHODS := [
	"is_passthrough_supported",
	"has_passthrough_capability",
	"supports_passthrough",
	"is_camera_passthrough_supported",
	"is_ar_supported",
]

const PASSTHROUGH_START_METHODS := [
	"start_passthrough",
	"enable_passthrough",
	"set_passthrough_enabled",
	"set_passthrough",
]

const PASSTHROUGH_STOP_METHODS := [
	"stop_passthrough",
	"disable_passthrough",
	"set_passthrough_enabled",
	"set_passthrough",
]

var _passthrough_start_report := {}
var _passthrough_started_targets: Array[String] = []
var virtual_plane_fallback_enabled := true
var virtual_plane_floor_height := 0.0
var virtual_plane_size := Vector2(5.0, 5.0)


func configure(p_owner: Node, p_backend: int, options: Dictionary = {}) -> void:
	super.configure(p_owner, p_backend, options)
	display_name = StringName(options.get("openxr_display_name", "OpenXR"))
	virtual_plane_fallback_enabled = bool(options.get("openxr_virtual_plane_fallback", true))
	virtual_plane_floor_height = float(options.get("openxr_virtual_plane_height", options.get("simulated_floor_height", 0.0)))
	virtual_plane_size = _vector2_from_variant(options.get("openxr_virtual_plane_size", Vector2(5.0, 5.0)), Vector2(5.0, 5.0))


func is_supported() -> bool:
	return XRServer.find_interface(DEFAULT_INTERFACE_NAME) != null


func get_provider_source() -> StringName:
	return &"OpenXR XRInterface"


func check_availability(options: Dictionary = {}) -> Dictionary:
	var report := super.check_availability(options)
	report["interface_registered"] = XRServer.find_interface(DEFAULT_INTERFACE_NAME) != null
	report["runtime_hint"] = String(options.get("platform_hint", ""))
	report["device_profile"] = _device_profile_from_hint(options)
	report["vendor_singletons"] = _available_vendor_singletons(options)
	return report


func get_capabilities(options: Dictionary = {}) -> Dictionary:
	var capabilities := super.get_capabilities(options)
	var xr_iface := XRServer.find_interface(DEFAULT_INTERFACE_NAME)
	var blend_modes := _environment_blend_mode_names(xr_iface)
	var has_alpha_blend := "alpha_blend" in blend_modes
	var has_additive_blend := "additive" in blend_modes
	var has_ar_blend := has_alpha_blend or has_additive_blend
	var vendor_singletons := _available_vendor_singletons(options)
	var vendor_feature_report := _vendor_feature_report(vendor_singletons)
	var interface_passthrough_supported := _interface_has_bool_method(xr_iface, "is_passthrough_supported")
	var has_vendor_passthrough := interface_passthrough_supported or _vendor_report_has_true(vendor_feature_report, PASSTHROUGH_EVIDENCE_METHODS) or _has_vendor_passthrough_singleton(vendor_singletons, vendor_feature_report)
	var passthrough_started := _passthrough_is_started(xr_iface, vendor_feature_report)
	var has_planes := _has_openxr_plane_trackers()
	var has_virtual_plane_fallback := _has_virtual_plane_fallback(has_planes)
	var has_tracking := xr_iface != null
	var has_input_ray := xr_iface != null
	var ar_tier := _classify_ar_tier(has_alpha_blend, has_additive_blend, has_vendor_passthrough, has_planes, has_tracking, has_input_ray)
	var ar_evidence := _ar_evidence(has_alpha_blend, has_additive_blend, interface_passthrough_supported, has_vendor_passthrough, vendor_feature_report)

	capabilities["session"] = xr_iface != null
	capabilities["tracking"] = has_tracking
	capabilities["camera_background"] = has_ar_blend or has_vendor_passthrough
	capabilities["passthrough"] = has_ar_blend or has_vendor_passthrough
	capabilities["raycast"] = true
	capabilities["plane_detection"] = has_planes or has_virtual_plane_fallback
	capabilities["anchors"] = true
	capabilities["input_ray"] = has_input_ray
	capabilities["hand_tracking"] = xr_iface != null
	capabilities["ar_product_path"] = has_ar_blend or has_vendor_passthrough
	capabilities["environment_blend_modes"] = blend_modes
	capabilities["openxr_interface"] = xr_iface != null
	capabilities["openxr_runtime"] = _interface_runtime_name(xr_iface)
	capabilities["openxr_selected_blend_mode"] = _current_environment_blend_mode_name(xr_iface)
	capabilities["openxr_vendor_singletons"] = vendor_singletons
	capabilities["openxr_vendor_feature_report"] = vendor_feature_report
	capabilities["openxr_interface_passthrough_supported"] = interface_passthrough_supported
	capabilities["openxr_vendor_passthrough"] = has_vendor_passthrough
	capabilities["openxr_passthrough_started"] = passthrough_started
	capabilities["openxr_passthrough_start_report"] = _passthrough_start_report
	capabilities["openxr_ar_tier"] = ar_tier
	capabilities["openxr_ar_evidence"] = ar_evidence
	capabilities["openxr_fallback"] = _fallback_for_tier(ar_tier, has_planes)
	capabilities["openxr_virtual_plane_fallback"] = has_virtual_plane_fallback
	var plane_source := "none"
	if has_planes:
		plane_source = "xr_tracker"
	elif has_virtual_plane_fallback:
		plane_source = "virtual_floor_fallback"
	capabilities["openxr_plane_source"] = plane_source
	capabilities["device_profile"] = _device_profile_from_hint(options)
	capabilities["runtime"] = "OpenXR"
	capabilities["openxr_feature_flags"] = _feature_flags(capabilities)
	return capabilities


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

	_start_passthrough(options)

	if bool(options.get("disable_vsync", true)) and OS.get_name() not in ["Android", "iOS"]:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

	last_error = ""
	return true


func stop() -> void:
	_stop_passthrough()
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
	if planes.is_empty() and _has_virtual_plane_fallback(false):
		planes.append(_virtual_floor_plane())
	return planes


func try_raycast(origin: Vector3, direction: Vector3, max_distance: float = 20.0, mask: int = 0xffffffff) -> Array[XRHit]:
	if _has_virtual_plane_fallback(_has_openxr_plane_trackers()):
		var fallback_hits := _virtual_floor_raycast(origin, direction, max_distance)
		if not fallback_hits.is_empty():
			return fallback_hits
	return super.try_raycast(origin, direction, max_distance, mask)


func _has_openxr_plane_trackers() -> bool:
	for tracker_name in _get_all_tracker_names():
		var tracker := XRServer.get_tracker(tracker_name)
		if tracker != null and tracker.get_class().to_lower().contains("plane"):
			return true
	return false


func _device_profile_from_hint(options: Dictionary = {}) -> String:
	var hint := String(options.get("platform_hint", "openxr")).strip_edges().to_lower()
	if hint.contains("rokid"):
		return "RokidOpenXR"
	if hint.contains("quest") or hint.contains("meta"):
		return "MetaQuestOpenXR"
	if hint.contains("pico"):
		return "PicoOpenXR"
	if hint.contains("androidxr") or hint.contains("android_xr"):
		return "AndroidXROpenXR"
	return "GenericOpenXR"


func _available_vendor_singletons(options: Dictionary = {}) -> Array[String]:
	var singleton_names: Array = options.get("openxr_vendor_singletons", DEFAULT_VENDOR_SINGLETONS)
	var found: Array[String] = []
	for singleton_name in singleton_names:
		var name := StringName(singleton_name)
		if Engine.has_singleton(name):
			found.append(String(name))
	return found


func _vendor_feature_report(vendor_singletons: Array[String]) -> Dictionary:
	var report := {}
	for singleton_name in vendor_singletons:
		var singleton := Engine.get_singleton(StringName(singleton_name))
		if singleton == null:
			continue
		var feature_report := {}
		for method_name in PASSTHROUGH_BOOL_METHODS:
			if singleton.has_method(method_name):
				var value: Variant = singleton.call(method_name)
				if typeof(value) == TYPE_BOOL:
					feature_report[method_name] = bool(value)
		if not feature_report.is_empty():
			report[singleton_name] = feature_report
	return report


func _start_passthrough(options: Dictionary = {}) -> void:
	_passthrough_start_report = {}
	_passthrough_started_targets.clear()
	if not bool(options.get("passthrough", true)) and not bool(options.get("prefer_ar", true)):
		_passthrough_start_report["skipped"] = "passthrough disabled by options"
		return

	if xr_interface and xr_interface.has_method("is_passthrough_supported"):
		var supported: Variant = xr_interface.call("is_passthrough_supported")
		_passthrough_start_report["xr_interface_supported"] = supported
		if typeof(supported) == TYPE_BOOL and bool(supported) and xr_interface.has_method("start_passthrough"):
			var result: Variant = xr_interface.call("start_passthrough")
			_passthrough_start_report["xr_interface_start_passthrough"] = result
			if _truthy_call_result(result):
				_passthrough_started_targets.append("XRInterface")

	var vendor_singletons := _available_vendor_singletons(options)
	var vendor_report := {}
	for singleton_name in vendor_singletons:
		var singleton := Engine.get_singleton(StringName(singleton_name))
		if singleton == null:
			continue
		var start_result := _call_passthrough_lifecycle(singleton, PASSTHROUGH_START_METHODS, true)
		if not start_result.is_empty():
			vendor_report[singleton_name] = start_result
			if bool(start_result.get("started", false)):
				_passthrough_started_targets.append(singleton_name)
	if not vendor_report.is_empty():
		_passthrough_start_report["vendor_start"] = vendor_report


func _stop_passthrough() -> void:
	var stop_report := {}
	if xr_interface and "XRInterface" in _passthrough_started_targets and xr_interface.has_method("stop_passthrough"):
		stop_report["XRInterface"] = xr_interface.call("stop_passthrough")

	for singleton_name in _passthrough_started_targets:
		if singleton_name == "XRInterface":
			continue
		if not Engine.has_singleton(StringName(singleton_name)):
			continue
		var singleton := Engine.get_singleton(StringName(singleton_name))
		if singleton == null:
			continue
		var result := _call_passthrough_lifecycle(singleton, PASSTHROUGH_STOP_METHODS, false)
		if not result.is_empty():
			stop_report[singleton_name] = result

	if not stop_report.is_empty():
		_passthrough_start_report["stop"] = stop_report
	_passthrough_started_targets.clear()


func _call_passthrough_lifecycle(singleton: Object, methods: Array, enable: bool) -> Dictionary:
	var report := {}
	for method_name in methods:
		if not singleton.has_method(method_name):
			continue
		var result: Variant = null
		var argument_count := _method_argument_count(singleton, method_name)
		if argument_count > 0:
			result = singleton.call(method_name, enable)
		else:
			result = singleton.call(method_name)
		report["method"] = method_name
		report["result"] = result
		report["started"] = enable and _truthy_call_result(result)
		report["stopped"] = not enable and _truthy_call_result(result)
		return report
	return report


func _method_argument_count(target: Object, method_name: String) -> int:
	for method in target.get_method_list():
		if String(method.get("name", "")) == method_name:
			var args: Variant = method.get("args", [])
			if args is Array:
				return args.size()
			return 0
	return 0


func _passthrough_is_started(xr_iface: XRInterface, vendor_feature_report: Dictionary) -> bool:
	if xr_iface != null and xr_iface.has_method("is_passthrough_started"):
		var value: Variant = xr_iface.call("is_passthrough_started")
		if typeof(value) == TYPE_BOOL and bool(value):
			return true
	if not _passthrough_started_targets.is_empty():
		return true
	return _vendor_report_has_true(vendor_feature_report, ["is_passthrough_started"])


func _truthy_call_result(value: Variant) -> bool:
	if typeof(value) == TYPE_BOOL:
		return bool(value)
	if typeof(value) == TYPE_INT:
		return int(value) == OK
	return typeof(value) == TYPE_NIL


func _vendor_report_has_true(vendor_feature_report: Dictionary, method_names: Array) -> bool:
	for singleton_name in vendor_feature_report.keys():
		var feature_report: Variant = vendor_feature_report[singleton_name]
		if not (feature_report is Dictionary):
			continue
		for method_name in method_names:
			if bool(feature_report.get(String(method_name), false)):
				return true
	return false


func _has_vendor_passthrough_singleton(vendor_singletons: Array[String], vendor_feature_report: Dictionary = {}) -> bool:
	if _vendor_report_has_true(vendor_feature_report, PASSTHROUGH_EVIDENCE_METHODS):
		return true
	for singleton_name in vendor_singletons:
		var lower_name := singleton_name.to_lower()
		if lower_name.contains("passthrough"):
			return true
	return false


func _ar_evidence(has_alpha_blend: bool, has_additive_blend: bool, interface_passthrough_supported: bool, has_vendor_passthrough: bool, vendor_feature_report: Dictionary) -> PackedStringArray:
	var evidence := PackedStringArray()
	if has_alpha_blend:
		evidence.append("environment_blend:alpha_blend")
	if has_additive_blend:
		evidence.append("environment_blend:additive")
	if interface_passthrough_supported:
		evidence.append("xr_interface:is_passthrough_supported")
	for singleton_name in vendor_feature_report.keys():
		var feature_report: Variant = vendor_feature_report[singleton_name]
		if not (feature_report is Dictionary):
			continue
		for method_name in PASSTHROUGH_EVIDENCE_METHODS:
			if bool(feature_report.get(String(method_name), false)):
				evidence.append("%s:%s" % [String(singleton_name), String(method_name)])
	if has_vendor_passthrough and evidence.is_empty():
		evidence.append("vendor_singleton:passthrough_name")
	return evidence


func _classify_ar_tier(has_alpha_blend: bool, has_additive_blend: bool, has_vendor_passthrough: bool, has_planes: bool, has_tracking: bool, has_input_ray: bool) -> String:
	if not has_tracking:
		return "D"
	if (has_alpha_blend or has_vendor_passthrough) and has_planes and has_input_ray:
		return "A"
	if (has_alpha_blend or has_vendor_passthrough) and has_input_ray:
		return "B"
	if has_additive_blend and has_input_ray:
		return "C"
	return "D"


func _fallback_for_tier(ar_tier: String, has_planes: bool) -> String:
	match ar_tier:
		"A":
			return "none"
		"B", "C":
			if has_planes:
				return "environment_planes"
			return "virtual_plane_raycast"
		_:
			return "vr_only_not_ar"


func _feature_flags(capabilities: Dictionary) -> PackedStringArray:
	var flags := PackedStringArray()
	if bool(capabilities.get("openxr_interface", false)):
		flags.append("OPENXR_SESSION")
		flags.append("OPENXR_RENDER")
		flags.append("OPENXR_REFERENCE_SPACES")
	if "alpha_blend" in capabilities.get("environment_blend_modes", []):
		flags.append("AR_BLEND_ALPHA")
	if "additive" in capabilities.get("environment_blend_modes", []):
		flags.append("AR_BLEND_ADDITIVE")
	if bool(capabilities.get("passthrough", false)):
		flags.append("PASSTHROUGH")
	if bool(capabilities.get("openxr_vendor_passthrough", false)):
		flags.append("VENDOR_PASSTHROUGH")
	if bool(capabilities.get("plane_detection", false)):
		flags.append("TRACKABLE_PLANES")
	if bool(capabilities.get("openxr_virtual_plane_fallback", false)):
		flags.append("VIRTUAL_PLANE_FALLBACK")
	if bool(capabilities.get("raycast", false)):
		flags.append("RAYCAST_FALLBACK")
	if bool(capabilities.get("anchors", false)):
		flags.append("ANCHOR_LOCAL")
	if bool(capabilities.get("input_ray", false)):
		flags.append("INPUT_RAY")
	if bool(capabilities.get("hand_tracking", false)):
		flags.append("HAND_TRACKING")
	return flags


func _interface_has_bool_method(xr_iface: XRInterface, method_name: String) -> bool:
	if xr_iface == null or not xr_iface.has_method(method_name):
		return false
	var result: Variant = xr_iface.call(method_name)
	return typeof(result) == TYPE_BOOL and bool(result)


func _interface_runtime_name(xr_iface: XRInterface) -> String:
	if xr_iface == null:
		return ""
	for method_name in ["get_system_name", "get_runtime_name", "get_name"]:
		if xr_iface.has_method(method_name):
			var value: Variant = xr_iface.call(method_name)
			if value != null:
				return String(value)
	return String(DEFAULT_INTERFACE_NAME)


func _current_environment_blend_mode_name(target_interface: XRInterface = null) -> String:
	var source := target_interface if target_interface != null else xr_interface
	if source == null:
		return "unknown"
	if _has_property(source, &"environment_blend_mode"):
		return _environment_blend_mode_to_string(int(source.get("environment_blend_mode")))
	return "unknown"


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


func _has_virtual_plane_fallback(has_real_planes: bool) -> bool:
	return virtual_plane_fallback_enabled and not has_real_planes


func _vector2_from_variant(value: Variant, fallback: Vector2) -> Vector2:
	if value is Vector2:
		return value
	if value is Vector3:
		return Vector2(value.x, value.z)
	if value is Array and value.size() >= 2:
		return Vector2(float(value[0]), float(value[1]))
	if value is Dictionary and value.has("x") and value.has("y"):
		return Vector2(float(value["x"]), float(value["y"]))
	return fallback


func _virtual_floor_plane() -> ARPlane:
	var transform := Transform3D(Basis.IDENTITY, Vector3(0.0, virtual_plane_floor_height, 0.0))
	var plane := ARPlane.new(&"openxr_virtual_floor", transform, virtual_plane_size, &"horizontal", {
		"runtime": "OpenXR",
		"source": "virtual_floor_fallback",
	})
	plane.label = &"virtual_floor"
	return plane


func _virtual_floor_raycast(origin: Vector3, direction: Vector3, max_distance: float) -> Array[XRHit]:
	var ray_direction := direction.normalized()
	if absf(ray_direction.y) < 0.0001:
		ray_direction = (ray_direction + Vector3.DOWN * 0.35).normalized()

	var distance_to_floor := (virtual_plane_floor_height - origin.y) / ray_direction.y
	if distance_to_floor < 0.0 or distance_to_floor > max_distance:
		var empty_hits: Array[XRHit] = []
		return empty_hits

	var point := origin + ray_direction * distance_to_floor
	var hit := XRHit.new(
		Transform3D(Basis.IDENTITY, point),
		distance_to_floor,
		&"openxr_virtual_floor",
		XRFoundationTypes.TrackableType.PLANE,
		{
			"runtime": "OpenXR",
			"source": "virtual_floor_fallback",
		}
	)
	hit.normal = Vector3.UP
	var hits: Array[XRHit] = [hit]
	return hits
