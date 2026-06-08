extends SceneTree


func _init() -> void:
	push_error("Use tools/c00/write_godot_android_editor_settings.js from configure_android_export_environment.sh. Godot --script cannot access EditorInterface editor settings in headless SceneTree mode.")
	quit(2)
