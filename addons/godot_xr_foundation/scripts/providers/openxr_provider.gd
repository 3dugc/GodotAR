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


func configure(p_owner: Node, p_backend: int, options: Dictionary = {}) -> void:
	super.configure(p_owner, p_backend, options)
	display_name = StringName(options.get("openxr_display_name", "OpenXR"))


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
	var has_planes := _has_openxr_plane_trackers()
	var has_tracking := xr_iface != null
	var has_input_ray := xr_iface != null
	var ar_tier := _classify_ar_tier(has_alpha_blend, has_additive_blend, has_vendor_passthrough, has_planes, has_tracking, has_input_ray)
	var ar_evidence := _ar_evidence(has_alpha_blend, has_additive_blend, interface_passthrough_supported, has_vendor_passthrough, vendor_feature_report)

	capabilities["session"] = xr_iface != null
	capabilities["tracking"] = has_tracking
	capabilities["camera_background"] = has_ar_blend or has_vendor_passthrough
	capabilities["passthrough"] = has_ar_blend or has_vendor_passthrough
	capabilities["raycast"] = true
	capabilities["plane_detection"] = has_planes
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
	capabilities["openxr_ar_tier"] = ar_tier
	capabilities["openxr_ar_evidence"] = ar_evidence
	capabilities["openxr_fallback"] = _fallback_for_tier(ar_tier, has_planes)
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
