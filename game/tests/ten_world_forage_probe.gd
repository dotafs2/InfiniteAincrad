extends SceneTree
## Twenty ordinary seconds of the SAME saved street. No relocation, time scaling,
## choice injection, gateway or model. GM-facing measurements stay in this file's
## output, never in resident memory. Records transient travel versus crowd stalls.

const TownScene := preload("res://scenes/town_street.tscn")
const ROOT_REL := "../tmp/gpt6-sprint/ten-world"
const OBSERVATION_SECONDS := 20.0
const ARRIVAL_DISTANCE := 0.45
var _save := ""
var _out := ""
var _scene: Node3D
var _baseline: Dictionary = {}
var _samples: Array = []
var _sampler: ContactSampler
var _checks := 0
var _failures: Array = []

class ContactSampler extends Node:
	var bodies: Dictionary = {}
	var frames := 0
	var lateral: Dictionary = {}
	func _physics_process(_delta: float) -> void:
		frames += 1
		for id in bodies:
			var body: CharacterBody3D = bodies[id]
			if not lateral.has(id):
				lateral[id] = {}
			for index in body.get_slide_collision_count():
				var hit := body.get_slide_collision(index)
				if absf(hit.get_normal().y) > 0.5:
					continue
				var collider: Object = hit.get_collider()
				var label := str(collider.get_path()) if collider is Node else str(collider)
				for other_id in bodies:
					if bodies[other_id] == collider:
						label = other_id
				lateral[id][label] = int(lateral[id].get(label, 0)) + 1

func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_failures.append(label)

func _allowed(path: String) -> bool:
	var root_path := ProjectSettings.globalize_path("res://").path_join(ROOT_REL).simplify_path().replace("\\", "/").to_lower()
	return path.is_absolute_path() and path.replace("\\", "/").simplify_path().to_lower().begins_with(root_path + "/")

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--town-save="):
			_save = arg.trim_prefix("--town-save=")
		elif arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		else:
			push_error("Unexpected flag in offline ordinary-time forage probe: " + arg)
			quit(2)
			return
	if not _allowed(_save) or not _allowed(_out) or _save == _out or FileAccess.file_exists(_out) \
			or FileAccess.file_exists(_out + ".baseline.json"):
		push_error("Use an existing disposable save and a NEW output under the ten-world sprint directory")
		quit(2)
		return
	var bytes := FileAccess.get_file_as_bytes(_save)
	var parsed: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	if not parsed is Dictionary or parsed.get("origin", {}).get("kind") != "new_world_seed":
		push_error("Expected an independent world save")
		quit(2)
		return
	_baseline = parsed
	DirAccess.make_dir_recursive_absolute(_out.get_base_dir())
	var backup := FileAccess.open(_out + ".baseline.json", FileAccess.WRITE)
	if backup == null:
		push_error("Cannot preserve the pre-continuation snapshot")
		quit(2)
		return
	backup.store_buffer(bytes)
	backup.close()
	_run.call_deferred()

func _sample(town: RefCounted, seconds: float) -> void:
	var residents: Dictionary = {}
	for id in town.active_ids():
		var body: CharacterBody3D = _scene.get("bodies")[id]
		var point := body.global_position
		var work_target: Vector3 = town.destination(id, "harvest_ration")
		residents[id] = {"position": [point.x, point.y, point.z],
			"work_target": [work_target.x, work_target.y, work_target.z],
			"distance_to_source": point.distance_to(work_target),
			"job": town.pending_job(id), "food": town.account(id).food,
			"velocity": [body.velocity.x, body.velocity.y, body.velocity.z]}
	_samples.append({"seconds": seconds, "stock": town.snapshot().foraging.stock,
		"seq": town.snapshot().life.seq, "residents": residents})

func _run() -> void:
	_scene = TownScene.instantiate()
	root.add_child(_scene)
	var town: RefCounted = _scene.get("town")
	_check(town.active_ids().size() == 10, "same save supplies ten actual street bodies")
	_check(not _scene.get("gateway_mode") and _scene.get("model_turns") == null,
		"ordinary offline life runs without model controllers")
	_check(town.snapshot().foraging.stock > 0, "the food source starts with real remaining stock")
	_sampler = ContactSampler.new()
	_sampler.bodies = _scene.get("bodies")
	root.add_child(_sampler)
	_sample(town, 0.0)
	var started := Time.get_ticks_msec()
	_scene.set("paused", false)
	while Time.get_ticks_msec() - started < int(OBSERVATION_SECONDS * 1000):
		await create_timer(0.5).timeout
		_sample(town, float(Time.get_ticks_msec() - started) / 1000.0)
	_scene.set("paused", true)
	var saved: Dictionary = town.transaction(_save, func(): return {"ok": true})
	_check(saved.get("ok", false), "ordinary writer transaction saves the continued world")
	var final: Dictionary = town.snapshot()
	_check(final.world_id == _baseline.world_id, "world identity remains unchanged")
	_check(JSON.parse_string(JSON.stringify(final.life.events.slice(0, _baseline.life.events.size()))) == _baseline.life.events,
		"prior history remains an exact prefix")
	var observations: Array = []
	var stalled: Array = []
	var first: Dictionary = _samples.front().residents
	var last: Dictionary = _samples.back().residents
	var minimum_stock: int = _samples.front().stock
	for sample in _samples:
		minimum_stock = mini(minimum_stock, int(sample.stock))
	for id in town.active_ids():
		var start_point := Vector3(first[id].position[0], first[id].position[1], first[id].position[2])
		var end_point := Vector3(last[id].position[0], last[id].position[1], last[id].position[2])
		var maximum_displacement := 0.0
		var minimum_distance: float = first[id].distance_to_source
		for sample in _samples:
			var point: Array = sample.residents[id].position
			maximum_displacement = maxf(maximum_displacement, start_point.distance_to(Vector3(point[0], point[1], point[2])))
			minimum_distance = minf(minimum_distance, float(sample.residents[id].distance_to_source))
		var unchanged_job: bool = first[id].job.get("action") == "harvest_ration" \
			and first[id].job.get("command_id") == last[id].job.get("command_id")
		var elapsed_delta: float = float(last[id].job.get("elapsed", 0)) - float(first[id].job.get("elapsed", 0))
		var contacts: Dictionary = _sampler.lateral.get(id, {})
		var measured_stall: bool = unchanged_job and absf(elapsed_delta) < 0.01 \
			and maximum_displacement < 0.05 and minimum_distance > ARRIVAL_DISTANCE \
			and not contacts.is_empty() and minimum_stock > 0
		if measured_stall:
			stalled.append(id)
		observations.append({"id": id, "original_command": first[id].job.get("command_id", ""),
			"work_target_start": first[id].work_target, "work_target_end": last[id].work_target,
			"same_pending_job": unchanged_job, "start_distance": first[id].distance_to_source,
			"end_distance": last[id].distance_to_source, "minimum_distance": minimum_distance,
			"net_displacement": start_point.distance_to(end_point), "maximum_displacement": maximum_displacement,
			"job_elapsed_start": first[id].job.get("elapsed", 0), "job_elapsed_end": last[id].job.get("elapsed", 0),
			"food_start": first[id].food, "food_end": last[id].food,
			"lateral_contact_counts": contacts, "measured_20s_stall": measured_stall})
	var payload := {"scenario": "ten-world-forage-crowd-observation", "checks": _checks,
		"failure_count": _failures.size(), "failures": _failures, "world_id": final.world_id,
		"process_id": OS.get_process_id(), "wall_seconds": float(Time.get_ticks_msec() - started) / 1000,
		"physics_frames": _sampler.frames, "arrival_distance": ARRIVAL_DISTANCE,
		"berry_center": final.godot.berry_position,
		"stock_before": _baseline.foraging.stock, "stock_after": final.foraging.stock, "minimum_stock": minimum_stock,
		"life_seq_before": _baseline.life.seq, "life_seq_after": final.life.seq,
		"stalled_ids": stalled, "resident_observations": observations, "samples": _samples,
		"model_calls": 0, "provenance": "same saved street; ordinary offline rules and real physics; no time scaling or relocated bodies",
		"scope": "20-second measured obstruction, not proof of permanent starvation"}
	var output := FileAccess.open(_out, FileAccess.WRITE)
	if output == null:
		push_error("Cannot write forage observations")
		quit(2)
		return
	output.store_string(JSON.stringify(payload, "  "))
	output.close()
	print(JSON.stringify({"checks": _checks, "failures": _failures, "stalled_ids": stalled,
		"stock_after": final.foraging.stock, "life_seq_after": final.life.seq, "process_id": OS.get_process_id()}))
	quit(0 if _failures.is_empty() else 1)
