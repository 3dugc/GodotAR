@tool
extends EditorPlugin

const AUTOLOAD_NAME := "XRFoundation"
const AUTOLOAD_PATH := "res://addons/godot_xr_foundation/scripts/xr_foundation.gd"

var _added_autoload := false


func _enter_tree() -> void:
	var key := "autoload/%s" % AUTOLOAD_NAME
	if not ProjectSettings.has_setting(key):
		add_autoload_singleton(AUTOLOAD_NAME, AUTOLOAD_PATH)
		_added_autoload = true


func _exit_tree() -> void:
	var key := "autoload/%s" % AUTOLOAD_NAME
	if _added_autoload and ProjectSettings.has_setting(key):
		remove_autoload_singleton(AUTOLOAD_NAME)

