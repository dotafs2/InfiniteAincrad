extends SceneTree

const Recovery := preload("res://tools/recover_town_controller.gd")

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var values := {}
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--town-save="):
			values.town_save = argument.trim_prefix("--town-save=")
		elif argument.begins_with("--resident="):
			values.resident = argument.trim_prefix("--resident=")
		elif argument.begins_with("--expected-request="):
			values.expected_request = argument.trim_prefix("--expected-request=")
		elif argument.begins_with("--expected-rule-error="):
			values.expected_rule_error = argument.trim_prefix("--expected-rule-error=")
	if not values.has_all(["town_save", "resident", "expected_request"]):
		print(JSON.stringify({"ok": false, "code": "required_flags: --town-save --resident --expected-request"}))
		quit(2)
		return
	var result: Dictionary = await Recovery.recover(get_root(), values.town_save, values.resident, values.expected_request, values.get("expected_rule_error", ""))
	print(JSON.stringify(result))
	quit(0 if result.get("ok", false) else 1)
