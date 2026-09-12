extends SceneTree
## Focused integration regression for the FIXED home/work lookup, on the real playable scene.
##
## Scenario: one resident reads the notice, walks to a public place and leaves a place-bound REST
## pending; the scene is then reopened from the saved bytes (the reviewed case: "reopening while a
## worker rests publicly"). While that public rest is pending:
##  - the scene's home/work markers sit on the FIXED saved home points, never on the public rest
##    target, in both the original and the reopened scene;
##  - repair routing and the authoritative workstation gate use the fixed home point;
##  - the actual pending rest still moves and waits at its own public target.
## Disposable two-resident fixture, default Forward+, no model call, no gateway, no paid provider.
const TownScene := preload("res://scenes/town_street.tscn")
const Catalog := preload("res://spatial/town_places.gd")
const Town := preload("res://core/town_places.gd")

const READER := "fixture:innkeeper"
const WORKER := "fixture:smith"
const PLACE := "market_plaza"

var _scene: Node = null
var _work := ""
var _save := ""
var _game := 0.0
var _frames := 0
var _phase := "boot"
var _checks := 0
var _failures: Array = []
var _notes: Dictionary = {}

func check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)
		print("FAIL ", label)

func _args() -> Dictionary:
	var result: Dictionary = {}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--"):
			var parts := arg.trim_prefix("--").split("=", true, 1)
			result[parts[0]] = parts[1] if parts.size() > 1 else true
	return result

func fixture() -> Dictionary:
	var roster := [[READER, [2.0, 0.22, 8.0]], [WORKER, [0.0, 0.22, 6.0]]]
	var world := {"schema_version": 2, "world_id": "fixture:town-places-home", "fixture": true,
		"elapsed_seconds": 0, "residents": [],
		"survival": {"accounts": [], "tick_remainder_seconds": 0},
		"foraging": {"stock": 6, "capacity": 6, "initial_stock": 6, "produced_total": 0,
			"harvested_total": 0, "growth_remainder_seconds": 0},
		"life": {"seq": 0, "events": [], "contracts": [], "applied": [], "relations": [],
			"inboxes": [], "items": [], "skills": [], "accounts": []},
		"godot": {"schema_version": 1, "mode": "migration_validation", "source_life_seq": 0,
			"source_sha256": "fixture-town-places-home", "positions": {}, "homes": {},
			"pending": {}, "commands": {}, "new_events": [], "elapsed_seconds": 0,
			"observations": {}, "berry_position": [4, 0.22, 1]}}
	for entry in roster:
		var stable_id: String = entry[0]
		world.residents.append({"stable_id": stable_id, "name": stable_id + " (offline fixture)",
			"role": "fixture", "story": "explicit offline fixture identity",
			"personality": "explicit offline fixture", "coins_col": 5,
			"needs": {"hunger": 60.0}, "runtime": {"fixture_only": true}})
		world.survival.accounts.append({"resident_id": stable_id, "food": 1, "energy": 60.0})
		world.life.accounts.append({"resident_id": stable_id, "wood": 1, "iron": 0, "kindling": 0, "reserved_col": 0})
		world.godot.positions[stable_id] = entry[1].duplicate()
		world.godot.homes[stable_id] = entry[1].duplicate()
		world.godot.observations[stable_id] = []
	return world

func _initialize() -> void:
	var args := _args()
	_work = str(args.get("work", ""))
	_save = str(args.get("save", ""))
	if _work.is_empty() or _save.is_empty():
		push_error("home lookup acceptance requires --work= and --save=")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(_work)
	DirAccess.make_dir_recursive_absolute(_save.get_base_dir())
	var file := FileAccess.open(_save, FileAccess.WRITE)
	if file == null:
		push_error("fixture save is not writable: " + _save)
		quit(2)
		return
	file.store_string(JSON.stringify(fixture(), "", true, true))
	file.close()
	Engine.time_scale = 1.0
	_scene = TownScene.instantiate()
	root.add_child(_scene)
	_scene.paused = false
	_scene.scripted_trade = true

func town() -> Town:
	return _scene.town

func _physics_process(delta: float) -> bool:
	_frames += 1
	_game += delta
	if _frames < 4:
		return false
	if _game > 120.0 and _phase != "done":
		check(false, "the bounded home-lookup regression exceeded its time budget")
		_finish()
		return true
	match _phase:
		"boot":
			if _game >= 2.0:
				_start_worker_travel()
		"walk":
			if town().pending_job(WORKER).is_empty():
				_start_public_rest()
		"reopen":
			_reopen_checks()
		"swap":
			_reopen_swap()
		"done":
			return true
	return false

func _start_worker_travel() -> void:
	if town().known_place_ids(WORKER).size() != Catalog.place_ids().size():
		check(false, "the worker learned every public place: " + str(town().known_place_ids(WORKER)))
		_finish()
		return
	var travel := {}
	for candidate in town().trade_options(WORKER):
		if candidate.get("id") == "place:travel:" + PLACE:
			travel = candidate
			break
	if travel.is_empty():
		check(false, "the worker is offered the market plaza")
		_finish()
		return
	var target: Vector3 = town().home_point(WORKER)
	check(target.distance_to(Vector3(0.0, 0.22, 6.0)) <= 0.05, "home_point returns the fixed saved home")
	var started: Dictionary = town().transaction(_save, func(): return town().submit_trade(WORKER, str(travel.id), "fixture-home:travel:1", "opengameagent_fixture"))
	check(started.ok, "the worker starts walking to the public plaza: " + str(started.get("code", "")))
	_phase = "walk"

func _start_public_rest() -> void:
	var public_point := town().place_point(PLACE, WORKER)
	var rest := {}
	for candidate in town().trade_options(WORKER):
		if candidate.get("id") == "place:rest:" + PLACE:
			rest = candidate
			break
	if rest.is_empty():
		check(false, "the arrived worker is offered rest at the public plaza")
		_finish()
		return
	var started: Dictionary = town().transaction(_save, func(): return town().submit_trade(WORKER, str(rest.id), "fixture-home:rest:1", "opengameagent_fixture"))
	check(started.ok and started.get("pending", false), "the public rest is pending while the worker stands there")
	_phase = "reopen" if started.ok else "done"
	if _phase == "done":
		_finish()

func _reopen_checks() -> void:
	var public_point := town().place_point(PLACE, WORKER)
	var marker_before := _marker_points(_scene)
	var home := town().home_point(WORKER)
	_notes.pending = {"public_point": public_point, "home": home, "marker": marker_before.get(WORKER, Vector3.INF),
		"rest_target": town().destination(WORKER, "rest"), "workstation_at_public": town()._at_worker_station(WORKER, WORKER)}
	check(marker_before.get(WORKER, Vector3.INF).distance_to(home) <= 0.8,
		"the work marker sits on the fixed home, not the public rest target")
	check(marker_before.get(WORKER, Vector3.INF).distance_to(public_point) > 1.0,
		"the work marker is not at the public rest target")
	check(town().destination(WORKER, "rest").distance_to(public_point) <= 0.05,
		"the pending rest still waits at its own public point")
	check(town().destination(WORKER, "travel").distance_to(public_point) > 0.05,
		"the travel lookup is not answered from the public rest target")
	## Reopen from the saved bytes with the rest still pending: the reviewed reopen case.
	_scene.paused = true
	_scene.queue_free()
	_scene = null
	_phase = "swap"

func _reopen_swap() -> void:
	## The freed scene releases the writer in its own exit; wait for that before reopening.
	if FileAccess.file_exists(_save + ".writer-lock"):
		return
	var reopened := TownScene.instantiate()
	root.add_child(reopened)
	reopened.paused = true
	_scene = reopened
	var reopened_town: Town = reopened.town
	var marker_after := _marker_points(reopened)
	var reopened_home: Vector3 = reopened_town.home_point(WORKER)
	var reopened_public: Vector3 = reopened_town.place_point(PLACE, WORKER)
	_notes.reopened = {"home": reopened_home, "marker": marker_after.get(WORKER, Vector3.INF),
		"public_point": reopened_public, "rest_target": reopened_town.destination(WORKER, "rest"),
		"pending_place": reopened_town.pending_job(WORKER).get("place_id", ""),
		"workstation_at_public": reopened_town._at_worker_station(WORKER, WORKER)}
	check(reopened_town.pending_job(WORKER).get("place_id", "") == PLACE, "the reopened scene keeps the pending public rest")
	check(marker_after.get(WORKER, Vector3.INF).distance_to(reopened_home) <= 0.8,
		"after the reopen the work marker is still on the fixed home")
	check(marker_after.get(WORKER, Vector3.INF).distance_to(reopened_public) > 1.0,
		"after the reopen the work marker did not move to the public rest target")
	check(reopened_town.destination(WORKER, "rest").distance_to(reopened_public) <= 0.05,
		"the reopened pending rest still points at the public point")
	check(not reopened_town._at_worker_station(WORKER, WORKER),
		"standing at the public square is still not the repair workstation")
	check(reopened_home.distance_to(reopened_public) > 1.0,
		"the public square is far from the fixed workstation")
	_finish()

func _marker_points(scene: Node) -> Dictionary:
	## The scene builds one Label3D home/work marker per resident at load, titled "<name> · 工作点".
	var result: Dictionary = {}
	for node in scene.find_children("*", "Label3D", true, false):
		var label: Label3D = node
		if not label.text.ends_with("工作点"):
			continue
		for id in [READER, WORKER]:
			if label.text.begins_with(id) or label.text.begins_with(id + " ("):
				result[id] = label.position - Vector3(0, 0.12, -0.7)
	return result

func _finish() -> void:
	_phase = "done"
	var evidence := {"suite": "town_places_home_lookup", "checks": _checks, "failures": _failures,
		"failure_count": _failures.size(), "time_scale": Engine.time_scale, "place": PLACE,
		"notes": _notes, "model_calls": 0, "paid_calls": 0}
	var args := _args()
	var out := str(args.get("out", ""))
	if not out.is_empty():
		DirAccess.make_dir_recursive_absolute(out.get_base_dir())
		var file := FileAccess.open(out, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(evidence, "", true, true))
			file.close()
	print(JSON.stringify({"checks": _checks, "failures": _failures, "notes": _notes}))
	quit(0 if _failures.is_empty() else 1)
