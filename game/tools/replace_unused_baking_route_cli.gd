extends SceneTree
## Host-only correction for one installed baking point that has never been observed or used.
## The old install journal/event remain history; the replacement keeps the same need and flour.
##
## godot --headless --path game --script res://tools/replace_unused_baking_route_cli.gd -- \
##   --town-save=<absolute path> --old-point-id=<active id> --source-seq=<same need seq> \
##   --command-id=development_gm:<review id> --spec-file=<new reviewed point spec>

const Town = preload("res://core/town_baking.gd")

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var values := {}
	for argument in OS.get_cmdline_user_args():
		for flag in ["town-save", "old-point-id", "source-seq", "command-id", "spec-file"]:
			if argument.begins_with("--" + flag + "="):
				values[flag] = argument.trim_prefix("--" + flag + "=")
	if not values.has_all(["town-save", "old-point-id", "source-seq", "command-id", "spec-file"]) \
			or not str(values.get("source-seq", "")).is_valid_int():
		print(JSON.stringify({"ok": false, "code": "required_flags: --town-save --old-point-id --source-seq(integer) --command-id --spec-file"}))
		quit(2)
		return
	var town := Town.new()
	var path: String = values["town-save"]
	var acquired := false
	var result := town.acquire_writer(path)
	if result.ok:
		acquired = true
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(str(values["spec-file"])))
		if not parsed is Dictionary:
			result = {"ok": false, "code": "spec_file_must_contain_json_dictionary"}
		else:
			result = town.load_from(path)
			if result.ok:
				var spec: Dictionary = parsed
				result = town.transaction(path, func(): return town.replace_unused_baking_route(
					str(values["old-point-id"]), spec, int(values["source-seq"]), str(values["command-id"])))
	if acquired:
		town.release_writer(path)
	print(JSON.stringify(result))
	quit(0 if result.ok else 1)
