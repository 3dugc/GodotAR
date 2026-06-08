extends SceneTree


func _init() -> void:
	var settings := EditorSettings.get_singleton()
	if settings == null:
		push_error("EditorSettings is unavailable. Run this script with the Godot editor binary.")
		quit(2)
		return

	var android_sdk := OS.get_environment("GODOT_ANDROID_SDK_PATH")
	var java_sdk := OS.get_environment("GODOT_JAVA_SDK_PATH")
	var debug_keystore := OS.get_environment("GODOT_ANDROID_KEYSTORE_DEBUG_PATH")
	var debug_user := OS.get_environment("GODOT_ANDROID_KEYSTORE_DEBUG_USER")
	var debug_password := OS.get_environment("GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD")

	var missing: Array[String] = []
	if android_sdk.is_empty():
		missing.append("GODOT_ANDROID_SDK_PATH")
	if java_sdk.is_empty():
		missing.append("GODOT_JAVA_SDK_PATH")
	if debug_keystore.is_empty():
		missing.append("GODOT_ANDROID_KEYSTORE_DEBUG_PATH")
	if debug_user.is_empty():
		missing.append("GODOT_ANDROID_KEYSTORE_DEBUG_USER")
	if debug_password.is_empty():
		missing.append("GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD")
	if not missing.is_empty():
		push_error("Missing environment value(s): %s" % ", ".join(missing))
		quit(2)
		return

	settings.set_setting("export/android/android_sdk_path", android_sdk)
	settings.set_setting("export/android/java_sdk_path", java_sdk)
	settings.set_setting("export/android/debug_keystore", debug_keystore)
	settings.set_setting("export/android/debug_keystore_user", debug_user)
	settings.set_setting("export/android/debug_keystore_pass", debug_password)
	settings.save()

	print("configured export/android/android_sdk_path=%s" % android_sdk)
	print("configured export/android/java_sdk_path=%s" % java_sdk)
	print("configured export/android/debug_keystore=%s" % debug_keystore)
	print("configured export/android/debug_keystore_user=%s" % debug_user)
	quit(0)
