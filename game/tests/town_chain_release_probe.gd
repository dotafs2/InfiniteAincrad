extends SceneTree
## Offline, scripted-choice integration probe of real town rules and persistence.
## No C# gateway or model transport is instantiated. Proximity sensing only: this
## probe does not claim physical movement, raycast visibility or autonomous choice.

const Runtime = preload("res://core/town_runtime.gd")
const Turns = preload("res://agents/town_turns.gd")
const SMITH := "shared:smith"
const PENDING := "shared:gardener"
const SOURCE := "offline-chain:iron-offcuts"
const NEED := "I have no iron for metal repair. I need a finite public source of iron."

class ScriptedBrain extends Node:
	var alias := ""
	var need := false
	var speech := ""
	var calls := 0
	var views: Array = []
	func propose(view: Dictionary, _seq: int) -> Dictionary:
		calls += 1
		views.append(view.duplicate(true))
		await get_tree().process_frame
		if alias not in view.available_actions:
			return {"ok": false, "code": "offline_script_option_missing"}
		var decision := {"action": alias, "reason": "Explicit offline test choice; no model inference."}
		if need:
			decision.need = {"capability_id": "finite_iron_supply", "reason": NEED}
		if not speech.is_empty():
			decision.speech = speech
		return {"ok": true, "decision": decision, "command_id": "offline-chain:reply:%d" % calls,
			"provenance": "opengameagent_fixture"}

var args: Dictionary = {}
var failures: Array = []
var checks := 0
var evidence: Dictionary = {}
var town
var turns
var street_samples: Array = []

func bind_scripted_turns() -> void:
	turns = Turns.new()
	root.add_child(turns)
	turns.town = town
	turns.save_path = args.save
	for id in town.active_ids():
		var brain := ScriptedBrain.new()
		turns.add_child(brain)
		turns.brains[id] = brain

func capture_street(scene: Node, label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var camera: Camera3D = scene.get("_camera")
	camera.global_position = Vector3(0, 7, 15)
	camera.look_at(Vector3(0, 1, 6))
	var hud: Label = scene.get("status")
	hud.text = "同一十人世界 · 离线脚本选择 / 实际物理与存档\n石青走向余铁并整理；灯姐休息\n%s · 铁料库存 %d · 石青铁 %d\n无模型调用；不是自主10+10" % [label, source_stock(), town._trade_account(SMITH).iron]
	await RenderingServer.frame_post_draw
	var path: String = args.out.get_base_dir().path_join(label + ".png")
	check(root.get_texture().get_image().save_png(path) == OK, "actual rendered frame saved: " + label)

func sample_street(scene: Node, start: int, label: String) -> void:
	var body: CharacterBody3D = scene.bodies[SMITH]
	var point: Vector3 = body.global_position
	var source_position: Array = town.material_sources()[0].position
	var target := Vector3(source_position[0], source_position[1], source_position[2])
	var job: Dictionary = town.pending_job(SMITH)
	street_samples.append({"stage": label, "wall_ms": Time.get_ticks_msec() - start,
		"body_position": [point.x, point.y, point.z], "distance_to_source": point.distance_to(target),
		"pending_action": job.get("action", ""), "pending_elapsed": job.get("elapsed", -1),
		"stock": source_stock(), "smith_iron": town._trade_account(SMITH).iron,
		"material_knowledge_source": town.resident_view(SMITH).material_sources[0].knowledge_source,
		"sight_evidence_note": "raycast only runs inside actual scene physics; canonical observation events are authoritative",
		"physical_collisions": body.get_slide_collision_count()})

func street_until(scene: Node, label: String, max_ms: int, min_work := -1.0) -> void:
	var start := Time.get_ticks_msec()
	var sampled := -1000
	while Time.get_ticks_msec() - start < max_ms:
		await physics_frame
		await process_frame
		var elapsed := Time.get_ticks_msec() - start
		if elapsed - sampled >= 500:
			sample_street(scene, start, label)
			sampled = elapsed
		var job: Dictionary = town.pending_job(SMITH)
		if job.is_empty() or (min_work >= 0 and float(job.get("elapsed", 0)) >= min_work):
			break
	check(Time.get_ticks_msec() - start < max_ms, "bounded real-time scene stage finishes: " + label)

func street_run() -> void:
	var selected := json_file(args.save)
	var scene = load("res://scenes/town_street.tscn").instantiate()
	scene.scripted_trade = true
	root.add_child(scene)
	town = scene.town
	bind_scripted_turns()
	check(scene.bodies.size() == 10, "actual street has all ten CharacterBody3D residents")
	check(town.snapshot().world_id == selected.world_id, "graphical phase continues the same world")
	check(not scene.gateway_mode and not scene.repair_fixture, "scene uses explicit offline choices without a gateway or legacy repair script")
	var loaded: Dictionary = town.snapshot()
	var initial: Dictionary = loaded.duplicate(true)
	if args.stage == "street-start":
		check(source_stock() == 2 and town._trade_account(SMITH).iron == 1, "graphical continuation starts from completed headless facts")
		await capture_street(scene, "street-before-travel")
		await choose(SMITH, "approach:shared:healer")
		scene.paused = false
		await street_until(scene, "approach-away", 15000)
		scene.paused = true
		var source_position: Array = town.material_sources()[0].position
		var target := Vector3(source_position[0], source_position[1], source_position[2])
		check(scene.bodies[SMITH].global_position.distance_to(target) > 1.0, "actual approach moves smith away before material return trip")
		await choose(SMITH, "material:recover:" + SOURCE)
		await choose("shared:innkeeper", "life:rest")
		scene.paused = false
		await street_until(scene, "material-return", 25000, 5.0)
		scene.paused = true
		check(town.pending_job(SMITH).get("action") == "recover_material", "actual scene pauses with unfinished material labor")
		check(source_stock() == 2 and town._trade_account(SMITH).iron == 1, "unfinished physical work preserves stock and property")
		check(town.pending_job("shared:innkeeper").get("action") == "rest", "another resident's real rest remains pending")
		await capture_street(scene, "street-paused-labor")
	else:
		var previous: Dictionary = json_file(args.get("resume-snapshot", args.out.get_base_dir().path_join("street-start.json"))).evidence.snapshot
		check(same_saved_value(loaded, previous), "cold graphical restart preserves all authoritative prior state")
		check(town.pending_job(SMITH).get("action") == "recover_material", "same unfinished physical labor loads in a new engine process")
		await capture_street(scene, "street-cold-resume")
		scene.paused = false
		await street_until(scene, "cold-physical-work", 70000)
		scene.paused = true
		check(source_stock() == 1 and town._trade_account(SMITH).iron == 2, "physical labor transfers one finite iron after cold restart")
		check(town.pending_job(SMITH).is_empty(), "same physical material commitment completed")
		check(town.account("shared:innkeeper").energy > float(initial.survival.accounts[4].energy), "independent resident rest has an actual energy consequence")
		await capture_street(scene, "street-completed-labor")
	check(town.transaction(args.save, func(): return {"ok": true}).get("ok", false), "save actual final physics positions and pending work")
	var final_state: Dictionary = town.snapshot()
	for person in initial.residents:
		check(town.resident(person.stable_id).coins_col == person.coins_col, "physical scene preserves money: " + person.stable_id)
	check(final_state.life.items == initial.life.items and final_state.life.contracts == initial.life.contracts, "physical scene preserves item property and contracts")
	check(final_state.life.events.slice(0, initial.life.events.size()) == initial.life.events, "physical scene preserves historical prefix")
	evidence = {"world_id": final_state.world_id, "snapshot": final_state, "samples": street_samples,
		"body_count": scene.bodies.size(), "runtime_mode": "actual_town_street_physics", "scripted_choices": true,
		"time_scale": Engine.time_scale, "stock": source_stock(), "smith_iron": town._trade_account(SMITH).iron}
	check(town.release_writer(args.save).get("ok", false), "graphical owner releases writer")
	scene.set("_owns_writer", false)
	turns.free()
	scene.queue_free()
	await process_frame
	write_json(args.out, {"stage": args.stage, "checks": checks, "failure_count": failures.size(), "failures": failures,
		"evidence": evidence, "real_model_calls": 0, "provenance": "offline scripted choices; real scene physics, line-of-sight, real elapsed time, persistent consequences"})
	print(JSON.stringify({"stage": args.stage, "checks": checks, "failure_count": failures.size(), "failures": failures}))
	quit(0 if failures.is_empty() else 1)

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)

func json_file(path: String) -> Dictionary:
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return value if value is Dictionary else {}

func same_saved_value(first: Variant, second: Variant) -> bool:
	# JSON numbers load as floats; authoritative schema normalization uses ints.
	# Compare saved values consistently; byte retention is checked separately.
	return JSON.parse_string(JSON.stringify(first)) == JSON.parse_string(JSON.stringify(second))

func write_json(path: String, value: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(value, "  ", true, true))
		file.close()
	else:
		check(false, "write evidence " + path)

func _initialize() -> void:
	for value in OS.get_cmdline_user_args():
		if value.begins_with("--chain-") and value.contains("="):
			var pair := value.trim_prefix("--chain-").split("=", true, 1)
			args[pair[0]] = pair[1]
	run.call_deferred()

func choose(id: String, option_id: String, with_need := false, speech := "") -> Dictionary:
	var brain = turns.brains[id]
	var options: Array = town.trade_options(id)
	brain.alias = ""
	for index in options.size():
		if options[index].id == option_id:
			brain.alias = "a%d" % index
	brain.need = with_need
	brain.speech = speech
	check(not brain.alias.is_empty(), "scripted option offered: " + id + " " + option_id)
	var result: Dictionary = await turns.step(id)
	check(result.get("ok", false), "runtime accepts scripted choice: " + id + " " + str(result.get("code")))
	return result

func advance(seconds: float) -> void:
	var result: Dictionary = town.transaction(args.save, func(): return town.advance(seconds))
	check(result.get("ok", false), "durable actual runtime advance " + str(seconds))

func source_stock() -> int:
	for source in town.material_sources():
		if source.id == SOURCE:
			return int(source.stock)
	return -1

func recover_script_controller(id: String) -> void:
	var record: Dictionary = turns._record(id)
	if record.get("status", "") not in ["provider_error", "rule_rejection"]:
		return
	var brain := ScriptedBrain.new()
	var recovered: Dictionary = turns.connect_controller(id, brain, "offline:probe-corrected-controller")
	check(recovered.get("ok", false), "explicit fixture controller repair preserves failed request review: " + id)

func prepare() -> void:
	var initial: Dictionary = town.snapshot()
	var prior: Dictionary = json_file(args.out) if FileAccess.file_exists(args.out) else {}
	check(initial.life.seq == 0, "fresh isolated test genesis has no fabricated history")
	check(town._trade_account(SMITH).iron == 0, "actual smith inventory lacks iron")
	check(town.material_sources().is_empty(), "world has no source before requested delivery")
	for id in town.active_ids():
		if not turns._record(id).get("history", []).is_empty():
			continue # Continue this world's completed turns; never replay to hide a failed probe.
		recover_script_controller(id)
		var option := "life:rest" if id == "shared:well-keeper" else "life:eat_ration" if id == "shared:baker" else "wait"
		await choose(id, option, id == SMITH)
	advance(60)
	check(town.account("shared:baker").food == 0, "actual meal consumed one held ration")
	check(town.account("shared:well-keeper").energy > 60, "actual rest restored energy")
	recover_script_controller(PENDING)
	await choose(PENDING, "life:rest")
	advance(10)
	check(town.pending_job(PENDING).get("elapsed", 0) == 10, "unfinished rest commitment created before release")
	var private_history: Array = town.snapshot().godot.resident_turns[SMITH].history
	var need_seq := int(private_history[0].get("need_source_sequence", -1))
	check(private_history[0].get("need", {}).get("reason") == NEED, "accepted private need exists in immutable personal turn history")
	check(not JSON.stringify(town.snapshot().life.events).contains(NEED), "private need is not manufactured public speech")
	var exported: Dictionary = town.write_background_gm_snapshot(args.export)
	check(exported.get("ok", false), "real runtime exports GM evidence")
	var snapshot: Dictionary = town.background_gm_snapshot()
	check(snapshot.proposals.size() == 1 and snapshot.proposals[0].resident_id == SMITH,
		"accepted scripted personal need becomes one attributed GM proposal")
	check(snapshot.proposals[0].first.source_sequence == need_seq, "GM source pointer refers to actual accepted private need")
	evidence["need_sequence"] = need_seq
	evidence["need_request_id"] = private_history[0].need_request_id
	evidence["personal_views"] = {}
	var total_calls := 0
	for id in town.active_ids():
		var brain = turns.brains[id]
		var all_views: Array = prior.get("evidence", {}).get("personal_views", {}).get(id, []).duplicate(true)
		all_views.append_array(brain.views)
		total_calls += all_views.size()
		evidence.personal_views[id] = all_views
		check(not all_views.is_empty(), "each of ten residents exercised real turn boundary: " + id)
		check(not JSON.stringify(all_views).contains("background_gm"), "GM diagnostics excluded from personal context: " + id)
	evidence["scripted_resident_turns"] = total_calls
	evidence["source_missing_before"] = true

func release() -> void:
	var approved := json_file(args.approval)
	var manifest := json_file(args.manifest)
	var before: Dictionary = town.snapshot()
	var valid: bool = approved.get("status") == "approved" and approved.get("world_id") == before.world_id \
		and manifest.get("world_id") == before.world_id \
		and approved.get("save_before_sha256") == FileAccess.get_sha256(args.save) \
		and approved.get("manifest_sha256") == FileAccess.get_sha256(args.manifest) \
		and approved.get("evidence_sha256") == FileAccess.get_sha256(args.export) \
		and manifest.get("evidence_sha256") == approved.get("evidence_sha256") \
		and manifest.get("delivery_kind") == "existing_finite_source_configuration" \
		and manifest.get("spec", {}).get("id") == SOURCE
	if not valid:
		evidence["release_refused"] = true
		evidence["refusal_code"] = "approval_binding_invalid"
		check(false, "approval must pin actual world, source evidence, candidate bytes and pre-release save")
		return
	check(town.pending_job(PENDING).get("elapsed", 0) == 10, "version continuation loads unfinished pre-release commitment")
	check(town.resident_view(SMITH).material_sources.is_empty(), "resident has no installation knowledge before delivery")
	var install_id := "development_gm:offline-chain-release"
	var result: Dictionary = town.transaction(args.save, func(): return town.install_material_source_from_need(manifest.spec, manifest.source_resident_id, manifest.source_request_id, install_id))
	check(result.get("ok", false), "approved existing finite-source capability installs through actual runtime")
	var after: Dictionary = town.snapshot()
	for key in ["residents", "survival", "origin", "seed"]:
		check(after[key] == before[key], "release preserves " + key)
	for key in ["items", "accounts", "contracts", "skills"]:
		check(after.life[key] == before.life[key], "release preserves life " + key)
	check(after.life.events.slice(0, before.life.events.size()) == before.life.events, "release preserves complete history prefix")
	check(town.pending_job(PENDING).get("elapsed", 0) == 10, "release invents no elapsed work")
	check(town.resident_view(SMITH).material_sources.is_empty(), "installation does not broadcast GM knowledge")
	var installed_bytes := FileAccess.get_file_as_bytes(args.save)
	var duplicate: Dictionary = town.install_material_source_from_need(manifest.spec, manifest.source_resident_id, manifest.source_request_id, install_id)
	check(duplicate.get("duplicate", false), "approved release command is idempotent")
	check(FileAccess.get_file_as_bytes(args.save) == installed_bytes, "duplicate installation does not rewrite save")
	evidence["installed_stock"] = source_stock()
	evidence["source_seq"] = manifest.source_seq
	evidence["installation"] = result

func continue_life() -> void:
	check(source_stock() == 3, "released finite stock loads exactly")
	advance(0)
	var view: Dictionary = town.resident_view(SMITH)
	check(view.material_sources.size() == 1, "nearby smith personally observes released source")
	check(view.material_sources[0].knowledge_source == "personal_proximity_observation", "personal knowledge is attributed to actual proximity observation")
	check(not JSON.stringify(view).contains("development_gm"), "personal source view contains no GM installation diagnostic")
	await choose(SMITH, "material:recover:" + SOURCE)
	advance(30)
	check(town.pending_job(SMITH).get("elapsed", -1) == 30, "real finite recovery remains half complete for cold restart")
	check(source_stock() == 3 and town._trade_account(SMITH).iron == 0, "unfinished work mints no material")
	evidence["personal_view_after_observation"] = view
	evidence["source_stock"] = source_stock()
	evidence["pending_before_cold"] = {SMITH: town.pending_job(SMITH), PENDING: town.pending_job(PENDING)}

func cold_finish() -> void:
	check(town.pending_job(SMITH).get("elapsed", -1) == 30, "cold process loads same half-complete material labor")
	check(town.pending_job(PENDING).get("elapsed", -1) == 40, "cold process preserves original pending rest across release")
	var before: Dictionary = town.snapshot()
	advance(30)
	check(town._trade_account(SMITH).iron == 1 and source_stock() == 2, "actual recovery transfers exactly one iron from source3 to resident0")
	check(town.material_sources()[0].recovered == 1, "source records one recovered unit")
	check(town.pending_job(SMITH).is_empty() and town.pending_job(PENDING).is_empty(), "both surviving commitments finish normally")
	for person in before.residents:
		check(town.resident(person.stable_id).coins_col == person.coins_col, "finite recovery does not create or spend money: " + person.stable_id)
	var command: String = before.godot.materials.jobs[SMITH].command_id
	var after: Dictionary = town.snapshot()
	var duplicate: Dictionary = town.submit_trade(SMITH, "material:recover:" + SOURCE, command, "opengameagent_fixture")
	check(duplicate.get("duplicate", false) and town.snapshot() == after, "cold-replayed completed command cannot duplicate iron")
	evidence["material_receipt"] = town.snapshot().godot.materials.commands[command]
	evidence["stock_after"] = source_stock()
	evidence["smith_iron_after"] = town._trade_account(SMITH).iron
	evidence["world_history_length"] = town.snapshot().life.events.size()

func run() -> void:
	for key in ["save", "out", "stage"]:
		if not args.has(key):
			quit(2)
			return
	var allowed := ProjectSettings.globalize_path("res://../tmp/gpt6-sprint/integration/").simplify_path().replace("\\", "/").trim_suffix("/") + "/"
	for key in ["save", "out", "export", "manifest", "approval", "resume-snapshot"]:
		if args.has(key) and not str(args[key]).simplify_path().replace("\\", "/").begins_with(allowed):
			push_error("offline chain paths must stay beneath integration evidence root")
			quit(2)
			return
	if str(args.stage).begins_with("street-"):
		await street_run()
		return
	var original_bytes := FileAccess.get_file_as_bytes(args.save)
	town = Runtime.new()
	var loaded: Dictionary = town.load_from(args.save)
	check(loaded.get("ok", false), "existing isolated ten-resident world loads")
	check(FileAccess.get_file_as_bytes(args.save) == original_bytes, "cold load preserves save bytes")
	if not loaded.get("ok", false):
		evidence["load_error"] = loaded
	else:
		check(town.active_ids().size() == 10, "same ten active identities are loaded")
		bind_scripted_turns()
		match args.stage:
			"prepare": await prepare()
			"release": release()
			"continue": await continue_life()
			"cold": cold_finish()
			"inspect": pass
			_: check(false, "known stage required")
		evidence["world_id"] = town.snapshot().world_id
		evidence["snapshot"] = town.snapshot()
		if not town._writer_lock_path.is_empty():
			check(town.release_writer(args.save).get("ok", false), "owned world writer releases")
		else:
			check(true, "read-only probe never took a world writer")
		turns.free()
	write_json(args.out, {"stage": args.stage, "checks": checks, "failures": failures,
		"failure_count": failures.size(), "evidence": evidence, "real_model_calls": 0,
		"provenance": "offline scripted resident controllers; real runtime effects; proximity sensing; no scene movement proof"})
	print(JSON.stringify({"stage": args.stage, "checks": checks, "failure_count": failures.size(), "failures": failures}))
	quit(0 if failures.is_empty() else 1)
