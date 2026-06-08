extends SceneTree


func _init() -> void:
	var config := ConfigFile.new()
	var err := config.load("res://export_presets.cfg")
	print("export_presets_load_error=%s" % err)
	for index in range(3):
		var section := "preset.%d" % index
		print("direct %s has=%s name=%s platform=%s" % [
			section,
			config.has_section(section),
			String(config.get_value(section, "name", "")),
			String(config.get_value(section, "platform", "")),
		])
	for section in config.get_sections():
		print("section=%s name=%s platform=%s" % [
			var_to_str(section),
			String(config.get_value(section, "name", "")),
			String(config.get_value(section, "platform", "")),
		])
	quit(err)
