@tool
extends EditorPlugin

var export_plugin: EditorExportPlugin


func _enter_tree() -> void:
	export_plugin = GodotARCoreExportPlugin.new()
	add_export_plugin(export_plugin)


func _exit_tree() -> void:
	if export_plugin:
		remove_export_plugin(export_plugin)
	export_plugin = null


class GodotARCoreExportPlugin extends EditorExportPlugin:
	const PLUGIN_NAME := "GodotARCore"
	const DEBUG_AAR := "godot_arcore/bin/debug/GodotARCore-debug.aar"
	const RELEASE_AAR := "godot_arcore/bin/release/GodotARCore-release.aar"
	const ARCORE_MAVEN_DEPENDENCY := "com.google.ar:core:1.33.0"
	const GOOGLE_MAVEN_REPOSITORY := "https://dl.google.com/dl/android/maven2/"


	func _supports_platform(platform) -> bool:
		return platform is EditorExportPlatformAndroid


	func _get_name() -> String:
		return PLUGIN_NAME


	func _get_android_libraries(_platform, debug: bool) -> PackedStringArray:
		if not _is_enabled_for_preset():
			return PackedStringArray()

		var requested := DEBUG_AAR if debug else RELEASE_AAR
		var fallback := RELEASE_AAR if debug else DEBUG_AAR
		var libraries := PackedStringArray()
		if _addon_file_exists(requested):
			libraries.append(requested)
		elif _addon_file_exists(fallback):
			libraries.append(fallback)
		return libraries


	func _get_android_dependencies(_platform, _debug: bool) -> PackedStringArray:
		if not _is_enabled_for_preset():
			return PackedStringArray()

		return PackedStringArray([ARCORE_MAVEN_DEPENDENCY])


	func _get_android_dependencies_maven_repos(_platform, _debug: bool) -> PackedStringArray:
		if not _is_enabled_for_preset():
			return PackedStringArray()

		return PackedStringArray([GOOGLE_MAVEN_REPOSITORY])


	func _get_android_manifest_element_contents(_platform, _debug: bool) -> String:
		if not _is_enabled_for_preset():
			return ""

		return "\n<uses-permission android:name=\"android.permission.CAMERA\" />\n"


	func _get_android_manifest_application_element_contents(_platform, _debug: bool) -> String:
		if not _is_enabled_for_preset():
			return ""

		return "\n<meta-data android:name=\"com.google.ar.core\" android:value=\"optional\" />\n"


	func _addon_file_exists(relative_to_addons: String) -> bool:
		return FileAccess.file_exists("res://addons/%s" % relative_to_addons)


	func _is_enabled_for_preset() -> bool:
		var preset := get_export_preset()
		if preset == null:
			return false

		var extra_args := String(preset.get("command_line/extra_args"))
		if extra_args.contains("--xr-platform=arcore"):
			return true

		return preset.get("plugins/GodotARCore") == true
