extends SceneTree
## Host-reviewed installation of one public baking point into an existing town save.
##
## Shape of the reviewed install (identical to the reviewed material-source installer):
##   godot --headless --path game --script res://tools/install_baking_route_cli.gd -- \
##     --town-save=<absolute save path> --source-seq=<seq of the delivered public ask> \
##     --command-id=development_gm:<review id> --spec-file=<absolute path to the point spec>
##
## The spec file is one JSON object with exactly the reviewed point fields:
##   {"id": ..., "label": ..., "initial_flour": 1..100, "position": [x, y, z], "access": "public"}
## The install grants no skill, item, material or coin, its command id is idempotent, and the
## finite public flour can only ever decrease.

const Town = preload("res://core/town_baking.gd")

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var values := {}
	for argument in OS.get_cmdline_user_args():
		for flag in ["town-save", "source-seq", "command-id", "spec-file"]:
			if argument.begins_with("--" + flag + "="):
				values[flag] = argument.trim_prefix("--" + flag + "=")
	if not values.has_all(["town-save", "source-seq", "command-id", "spec-file"]) or not str(values.get("source-seq", "")).is_valid_int():
		print(JSON.stringify({"ok": false, "code": "required_flags: --town-save --source-seq(integer) --command-id --spec-file"}))
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
				result = town.transaction(path, func(): return town.install_baking_route(spec, int(values["source-seq"]), str(values["command-id"])))
	if acquired:
		town.release_writer(path)
	print(JSON.stringify(result))
	quit(0 if result.ok else 1)
