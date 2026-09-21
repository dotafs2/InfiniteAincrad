extends SceneTree

const BRAIN := preload("res://agents/resident_brain.gd")
var failures: Array[String] = []

class ProbeBrain extends "res://agents/resident_brain.gd":
	func parse(value: String) -> Dictionary:
		return _routing_metadata({"responseId": value})

func check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)
		push_error(label)

func _initialize() -> void:
	var brain := ProbeBrain.new()
	var valid := JSON.stringify({
		"source": "localjev", "router_model": "qwen3:8b", "route": "local_routine",
		"route_confidence": 0.93, "router_fallback": false, "router_fallback_reason": null,
		"decision_confidence": 0.94, "cloud_fallback": false, "fallback_reason": null,
		"selected_model": "qwen3:8b", "final_model": "qwen3:8b"})
	var parsed := brain.parse(valid)
	check(parsed.route == "local_routine", "valid local route metadata is accepted")
	check(parsed.cloud_fallback == false and parsed.decision_confidence == 0.94,
		"local confidence and fallback facts survive")
	var changed := valid.replace("local_routine", "unexpected_route")
	check(brain.parse(changed).is_empty(), "unknown route metadata is rejected")
	var extra := valid.left(valid.length() - 1) + ",\"secret\":true}"
	check(brain.parse(extra).is_empty(), "extra provider metadata is rejected")
	brain.free()
	print(JSON.stringify({"suite": "localjev_routing_metadata", "passed": failures.is_empty(), "failures": failures}))
	quit(0 if failures.is_empty() else 1)
