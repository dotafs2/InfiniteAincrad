extends SceneTree
## Headless acceptance for the village navigation scene: the ten generated
## models must load, the authored turret house must build, NpcA must walk in
## through its doorway, climb to the second floor and reach NpcB upstairs.

var scene = null
var frames := 0

const EVIDENCE_DIR := "res://../docs/validation/model-nav-20260922"
const MAX_PHYSICS_FRAMES := 60 * 150


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var packed: PackedScene = load("res://scenes/model_nav_village.tscn") as PackedScene
	if packed == null:
		_finish({"ok": false, "checks": 0, "failures": ["scene_load_failed"]})
		return
	scene = packed.instantiate()
	scene.set("override_test_mode", true)
	root.add_child(scene)
	while not bool(scene.get("sim_finished")) and frames < MAX_PHYSICS_FRAMES:
		await physics_frame
		frames += 1
	var data: Dictionary = scene.call("result_data")
	var checks := 0
	var failures: Array[String] = []

	checks += 1
	if int(data.get("models_loaded", 0)) != int(data.get("models_expected", 10)):
		failures.append("expected 10 loaded models, got " + str(data.get("models_loaded", 0)))
	var house: Dictionary = data.get("house", {})
	checks += 1
	if not bool(house.get("built", false)):
		failures.append("authored house did not build: " + str(house))
	checks += 1
	var nav: Dictionary = data.get("navigation", {})
	if not bool(nav.get("baked", false)) or int(nav.get("polygons", 0)) <= 0:
		failures.append("navigation mesh not baked: " + str(nav))
	checks += 1
	var path: Dictionary = data.get("path", {})
	if not bool(path.get("found", false)):
		failures.append("no navigation path to the doorway")
	checks += 1
	var simulation: Dictionary = data.get("simulation", {})
	if not bool(simulation.get("arrived", false)):
		failures.append("NpcA did not arrive at NpcB: " + str(simulation))
	checks += 1
	if float(path.get("detour_ratio", 0.0)) < 1.02:
		failures.append("route is not a real detour: ratio " + str(path.get("detour_ratio", 0.0)))
	checks += 1
	if float(simulation.get("timed_out", 0.0)) != 0.0:
		failures.append("simulation timed out")
	var profile: Dictionary = data.get("route_profile", {})
	checks += 1
	if not bool(profile.get("floor_2_reached", false)):
		failures.append("route never climbs to the second floor: " + str(profile))
	checks += 1
	if int(profile.get("indoor_points", 0)) < 2:
		failures.append("route never passes through the house interior: " + str(profile))
	var meeting: Dictionary = data.get("meeting", {})
	checks += 1
	if not bool(meeting.get("met", false)):
		failures.append("NpcA never reached NpcB upstairs: " + str(meeting))
	checks += 1
	if int(data.get("detail_assets_loaded", 0)) < 20:
		failures.append("too few repository props/interior pieces loaded: " + str(data.get("detail_assets_loaded", 0)))
	for record in data.get("models", []):
		checks += 1
		if not bool(record.get("loaded", false)):
			failures.append("model not loaded: " + str(record.get("id", "?")) + " " + str(record.get("error", "")))

	var verdict := {
		"ok": failures.is_empty(),
		"checks": checks,
		"failures": failures,
		"physics_frames": frames,
		"data": data,
	}
	scene.call("write_evidence", EVIDENCE_DIR + "/acceptance.json", verdict)
	print(JSON.stringify(verdict, "  "))
	quit(0 if failures.is_empty() else 1)


func _finish(verdict: Dictionary) -> void:
	print(JSON.stringify(verdict, "  "))
	quit(1)
