extends SceneTree
## Writes the exact engine build's notices into the distributable.
func _initialize() -> void:
	var destination := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--license-out="): destination = arg.trim_prefix("--license-out=")
	if destination.is_empty():
		push_error("--license-out is required")
		quit(1)
		return
	var file := FileAccess.open(destination,FileAccess.WRITE)
	if file == null:
		push_error("Cannot write engine notices")
		quit(1)
		return
	file.store_string("Godot Engine " + Engine.get_version_info().string + "\n\n")
	file.store_string(Engine.get_license_text() + "\n\nTHIRD-PARTY COPYRIGHT NOTICES\n\n")
	for component in Engine.get_copyright_info():
		file.store_string(component.name + "\n")
		for part in component.parts:
			file.store_string("Files: " + ", ".join(part.files) + "\n")
			file.store_string("Copyright: " + "; ".join(part.copyright) + "\n")
			file.store_string("License: " + part.license + "\n\n")
	file.store_string("\nTHIRD-PARTY LICENSE TEXTS\n\n")
	var licenses := Engine.get_license_info()
	for name in licenses:
		file.store_string(str(name) + "\n" + str(licenses[name]) + "\n\n")
	file.close()
	quit()
