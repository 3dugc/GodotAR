@tool
extends EditorPlugin

var export_plugin: EditorExportPlugin


func _enter_tree() -> void:
	export_plugin = GodotOpenXRVendorsExportPlugin.new()
	add_export_plugin(export_plugin)


func _exit_tree() -> void:
	if export_plugin:
		remove_export_plugin(export_plugin)
	export_plugin = null


class GodotOpenXRVendorsExportPlugin extends EditorExportPlugin:
	const PLUGIN_NAME := "GodotOpenXRVendorsExport"
	const VENDOR_OPTIONS := {
		"khronos": "xr_features/openxr_vendor_khronos",
		"meta": "xr_features/openxr_vendor_meta",
		"pico": "xr_features/openxr_vendor_pico",
		"androidxr": "xr_features/openxr_vendor_androidxr",
		"magicleap": "xr_features/openxr_vendor_magicleap",
		"lynx": "xr_features/openxr_vendor_lynx",
	}


	func _supports_platform(platform) -> bool:
		return platform is EditorExportPlatformAndroid


	func _get_name() -> String:
		return PLUGIN_NAME


	func _get_export_options(platform) -> Array[Dictionary]:
		if not _supports_platform(platform):
			return []

		var options: Array[Dictionary] = []
		for vendor in VENDOR_OPTIONS.keys():
			options.append({
				"option": {
					"name": VENDOR_OPTIONS[vendor],
					"type": TYPE_BOOL,
				},
				"default_value": false,
				"update_visibility": true,
			})
		return options


	func _get_export_option_warning(_platform, option: String) -> String:
		if not VENDOR_OPTIONS.values().has(option):
			return ""

		var selected := _selected_vendors()
		if selected.size() > 1:
			return "Select exactly one OpenXR vendor loader per Android export preset."

		if selected.size() == 1:
			var vendor: String = selected[0]
			if not _addon_file_exists(_aar_path(vendor, true)) and not _addon_file_exists(_aar_path(vendor, false)):
				return "Missing Godot OpenXR Vendors AAR for %s. Reinstall addons/godotopenxrvendors." % vendor
		return ""


	func _get_android_libraries(_platform, debug: bool) -> PackedStringArray:
		var selected := _selected_vendors()
		if selected.size() != 1:
			return PackedStringArray()

		var vendor: String = selected[0]
		var requested := _aar_path(vendor, debug)
		var fallback := _aar_path(vendor, not debug)
		var libraries := PackedStringArray()
		if _addon_file_exists(requested):
			libraries.append(requested)
		elif _addon_file_exists(fallback):
			libraries.append(fallback)
		return libraries


	func _selected_vendors() -> Array[String]:
		var selected: Array[String] = []
		for vendor in VENDOR_OPTIONS.keys():
			if get_option(VENDOR_OPTIONS[vendor]) == true:
				selected.append(vendor)
		return selected


	func _aar_path(vendor: String, debug: bool) -> String:
		var build_type := "debug" if debug else "release"
		return "godotopenxrvendors/.bin/android/%s/godotopenxr-%s-%s.aar" % [build_type, vendor, build_type]


	func _addon_file_exists(relative_to_addons: String) -> bool:
		return FileAccess.file_exists("res://addons/%s" % relative_to_addons)
