extends Node

const DEFAULT_SCENE := "res://demo/00_device_smoke_test.tscn"

const SCENE_ALIASES := {
	"": DEFAULT_SCENE,
	"smoke": DEFAULT_SCENE,
	"c00": DEFAULT_SCENE,
	"device_smoke": DEFAULT_SCENE,
	"openxr_lab": "res://demo/03_openxr_ar_capability_lab.tscn",
	"rokid_lab": "res://demo/03_openxr_ar_capability_lab.tscn",
	"c02_lab": "res://demo/03_openxr_ar_capability_lab.tscn",
	"rokid_place": "res://demo/04_rokid_ray_place.tscn",
	"openxr_place": "res://demo/04_rokid_ray_place.tscn",
	"c02_place": "res://demo/04_rokid_ray_place.tscn",
	"ios_arkit_place": "res://demo/06_ios_arkit_place.tscn",
	"arkit_place": "res://demo/06_ios_arkit_place.tscn",
	"ipad_place": "res://demo/06_ios_arkit_place.tscn",
	"c04_place": "res://demo/06_ios_arkit_place.tscn",
}

var _selected_alias := ""
var _selected_scene := DEFAULT_SCENE


func _ready() -> void:
	_selected_alias = _read_scene_alias()
	_selected_scene = String(SCENE_ALIASES.get(_selected_alias, ""))
	if _selected_scene == "":
		push_warning("Unknown --xr-scene value '%s'; falling back to smoke scene." % _selected_alias)
		_selected_scene = DEFAULT_SCENE
	_emit_boot_log("route_selected")
	call_deferred("_change_to_selected_scene")


func _change_to_selected_scene() -> void:
	var error := get_tree().change_scene_to_file(_selected_scene)
	if error != OK and _selected_scene != DEFAULT_SCENE:
		push_error("Failed to load %s, falling back to %s. Error: %d" % [_selected_scene, DEFAULT_SCENE, error])
		_selected_scene = DEFAULT_SCENE
		_emit_boot_log("route_fallback")
		error = get_tree().change_scene_to_file(DEFAULT_SCENE)
	if error != OK:
		push_error("Failed to load boot fallback scene %s. Error: %d" % [DEFAULT_SCENE, error])


func _read_scene_alias() -> String:
	for arg in _all_cmdline_args():
		if arg.begins_with("--xr-scene="):
			return arg.get_slice("=", 1).strip_edges().to_lower()
		if arg.begins_with("--xr-demo="):
			return arg.get_slice("=", 1).strip_edges().to_lower()
	return ""


func _all_cmdline_args() -> PackedStringArray:
	var combined := PackedStringArray()
	_append_unique_args(combined, OS.get_cmdline_args())
	if OS.has_method("get_cmdline_user_args"):
		_append_unique_args(combined, OS.get_cmdline_user_args())
	return combined


func _append_unique_args(target: PackedStringArray, source: PackedStringArray) -> void:
	for arg in source:
		if not target.has(arg):
			target.append(arg)


func _emit_boot_log(event_name: String) -> void:
	var payload := {
		"event": event_name,
		"requested_scene": _selected_alias,
		"resolved_scene": _selected_scene,
		"default_scene": DEFAULT_SCENE,
		"cmdline_args": Array(_all_cmdline_args()),
	}
	print("GXF_BOOT|%s" % JSON.stringify(payload))
