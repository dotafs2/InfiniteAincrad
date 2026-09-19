extends "res://tests/town_trade_acceptance.gd"
const Actions = preload("res://core/town_actions.gd")
const Registry = preload("res://core/actions/capability_registry.gd")
const Turns = preload("res://agents/town_turns.gd")
const A := "fictional:ember"
const B := "fictional:birch"
const C := "fictional:forge"
var receipts: Array = []

func _new_stage(label: String) -> Dictionary:
	var path := "user://capability-%s-%d.json" % [label, Time.get_ticks_usec()]
	_write_fixture(path, trade_fixture())
	var world := Actions.new()
	check(world.load_from(path).ok, label + ": legacy fixture loads without capability migration")
	for index in [A, B, C].size():
		var id: String = [A, B, C][index]
		world.host_move(id, Vector3(-3 + index, .22, 12))
		check(world.observe_public_places(id, true, []).ok, "personal notice observed")
	check(world.save_to(path).ok, "fixture setup saved")
	return {"world": world, "path": path}

func _close_stage(stage: Dictionary) -> void:
	stage.world.release_writer(stage.path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(stage.path))

func _do(stage: Dictionary, id: String, option: String, command: String, speech: String = "") -> Dictionary:
	var result: Dictionary = stage.world.perform_action(stage.path, id, option, command, "opengameagent_fixture", speech)
	check(result.ok, command + ": " + str(result.get("code")))
	return result

func _step(id: String, option: String, command: String) -> Dictionary:
	return {"actor_id": id, "option_id": option, "command_id": command, "provenance": "opengameagent_fixture", "speech": ""}

func _same_value(a: Variant, b: Variant, path: String = "state") -> bool:
	# JSON numbers decode as floats. Compare every leaf without numeric tolerance;
	# Dictionary equality would reject otherwise identical nested integer values.
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key in a:
			if not b.has(key) or not _same_value(a[key], b[key], path + "." + str(key)): return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for index in a.size():
			if not _same_value(a[index], b[index], path + "[" + str(index) + "]"): return false
		return true
	if a != b: print("COLD_RESTORE_DIFFERENCE " + path)
	return a == b

func run() -> void:
	var stage := _new_stage("social")
	var world = stage.world
	var before: Dictionary = world.snapshot()
	var definitions: Array = world.capability_definitions()
	check(definitions.size() == 36, "27 adapted capabilities plus nine native entry points")
	var registry := Registry.new()
	for definition in definitions:
		check(registry.register(definition).ok, "complete versioned contract: " + definition.id)
	check(not registry.register(definitions[0]).ok, "duplicate capability IDs rejected")
	check(not registry.register({"id": "incomplete"}).ok, "incomplete extension rejected")
	var copy: Dictionary = registry.definition("social.talk")
	copy.effects.clear()
	check(not registry.definition("social.talk").effects.is_empty(), "registry returns detached definitions")
	var options: Array = world.action_options(A)
	for option in options:
		check(not registry.definition(option.capability_id).is_empty() and option.capability_version == 1, "each offered option has a registered contract")
	check(world.snapshot() == before, "option discovery is read-only, including legacy worlds")
	var rejected: Dictionary = world.perform_action(stage.path, A, "ability:talk:" + B, "cap:empty", "opengameagent_fixture")
	check(not rejected.ok and world.snapshot() == before, "free conversation requires actual speech and makes no partial write")
	_do(stage, A, "ability:talk:" + B, "cap:talk", "I would like to learn what interests you.")
	var spoken: Dictionary = world.snapshot().life.events[-1]
	check(spoken.type == "resident_said" and spoken.recipient_ids == [A, B], "free speech is attributed to actual speaker and recipient")
	check(spoken.epistemic_status == "speaker_statement_not_verified_world_fact", "speech is not asserted world truth")
	check(world.snapshot().life.contracts == before.life.contracts and world.snapshot().life.skills == before.life.skills, "speaking grants no contract or skill")
	var after_talk: Dictionary = world.snapshot()
	check(world.perform_action(stage.path, A, "ability:talk:" + B, "cap:talk", "opengameagent_fixture", spoken.text).duplicate, "same exact command replays read-only")
	check(world.snapshot() == after_talk, "replayed conversation creates no new event")
	check(not world.perform_action(stage.path, A, "ability:talk:" + B, "cap:talk", "opengameagent_fixture", "Changed words").ok, "changed payload cannot reuse a command")
	var observed := _do(stage, B, "ability:observe", "cap:observe")
	check(not observed.speech_delivery.delivered, "private observation is not delivered speech")
	var turns := Turns.new()
	turns.town = world
	check(not turns._speech_delivery(B, "cap:observe", "", observed).delivered, "controller archive honors explicit non-speech receipt")
	turns.free()
	var observation: Dictionary = world.snapshot().life.events[-1]
	check(observation.recipient_ids == [B] and observation.private_observation, "observation only enters observer history")
	check(observation.observed.nearby_residents.size() == 2, "observation uses real nearby residents from personal sensors")
	check(not JSON.stringify(observation.observed).contains("character_profile"), "observation does not copy other dossiers")
	var valid: Dictionary = world.snapshot()
	var corrupt := valid.duplicate(true)
	corrupt.godot.capabilities.commands["cap:talk"].version = 2
	check(not world._validate_state(corrupt).ok, "unknown persisted capability version rejected")
	corrupt = valid.duplicate(true)
	corrupt.godot.capabilities.commands["cap:talk"].payload.option_id = "ability:talk:" + C
	check(not world._validate_state(corrupt).ok, "persisted speech cannot redirect its actual recipient")
	corrupt = valid.duplicate(true)
	corrupt.godot.erase("capabilities")
	check(not world._validate_state(corrupt).ok, "native evidence cannot lose its entire replay journal")
	corrupt = valid.duplicate(true)
	corrupt.godot.capabilities.commands.erase("cap:talk")
	check(not world._validate_state(corrupt).ok, "native speech evidence cannot lose its original command")
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(stage.path)
	world.release_writer(stage.path)
	var restored := Actions.new()
	check(restored.load_from(stage.path).ok and _same_value(restored.snapshot(), valid), "native commands survive cold restore exactly")
	check(FileAccess.get_file_as_bytes(stage.path) == bytes, "read-only load preserves save bytes")
	stage.world = restored
	_close_stage(stage)

	stage = _new_stage("atomic")
	world = stage.world
	before = world.snapshot()
	var batch: Dictionary = world.execute_atomic_actions([_step(A, "life:rest", "batch:a"), _step(B, "missing", "batch:b")])
	check(not batch.ok and batch.failed_step == 1, "second-child refusal identifies failed step")
	check(world.snapshot() == before, "composite rollback removes first-child job and command")
	batch = world.execute_atomic_actions([_step(A, "wait", "batch:same"), _step(A, "wait", "batch:same")])
	check(not batch.ok and world.snapshot() == before, "each child in a composite needs its own command identity")
	batch = world.execute_atomic_actions([_step(A, "life:rest", "body:a"), _step(A, "life:harvest_ration", "body:b")])
	check(not batch.ok and world.snapshot() == before, "one body cannot start conflicting jobs in a batch")
	batch = world.transaction(stage.path, func(): return world.execute_atomic_actions([_step(A, "life:rest", "parallel:a"), _step(B, "life:rest", "parallel:b")]))
	check(batch.ok and not world.pending_job(A).is_empty() and not world.pending_job(B).is_empty(), "different bodies can execute jobs concurrently")
	check(world.action_receipt("parallel:a").status == "pending", "uniform receipt does not turn admission into completion")
	world.host_move(A, world.destination(A, "rest"))
	check(world.transaction(stage.path, func(): return world.advance(60)).ok, "body job settles behind its legacy trade wrapper")
	check(world.action_receipt("parallel:a").status == "completed", "common receipt uses final body outcome over stale wrapper admission")
	_close_stage(stage)

	stage = _new_stage("cooperation")
	world = stage.world
	var invite := "ability:invite:" + B + ":west_forecourt"
	_do(stage, A, invite, "plan:one", "Would you like to visit the forecourt together?")
	check(world.pending_job(A).is_empty() and world.pending_job(B).is_empty(), "invitation alone moves neither resident")
	check(world.resident_view(C).shared_plans.is_empty(), "bystander cannot read another pair's plan")
	before = world.snapshot()
	check(not world.perform_action(stage.path, C, "ability:accept_visit:plan:one", "plan:outsider", "opengameagent_fixture").ok, "third party cannot consent for the invited resident")
	check(world.snapshot() == before, "unauthorized consent changes nothing")
	world.host_move(B, Vector3(20, 0, 12))
	before = world.snapshot()
	check(not world.execute_action(B, "ability:accept_visit:plan:one", "plan:stale", "opengameagent_fixture").ok and world.snapshot() == before, "moved counterparty invalidates stale acceptance")
	world.host_move(B, Vector3(-2, .22, 12))
	_do(stage, B, "ability:accept_visit:plan:one", "plan:accept", "Yes, let us go.")
	check(world.capability_store().plans["plan:one"].status == "running", "consent creates a real running shared plan")
	check(world.pending_job(A).action == "travel" and world.pending_job(B).action == "travel", "both consented travel actions started")
	check(world.pending_job(A).target_position != world.pending_job(B).target_position, "participants own separate arrival slots")
	_do(stage, C, "life:rest", "plan:independent")
	check(not world.pending_job(C).is_empty(), "unrelated resident runs alongside the joint plan")
	valid = world.snapshot()
	corrupt = valid.duplicate(true)
	corrupt.godot.capabilities.plans["plan:one"].status = "completed"
	check(not world._validate_state(corrupt).ok, "save cannot turn two unfinished trips into a completed plan")
	corrupt = valid.duplicate(true)
	corrupt.godot.capabilities.commands["plan:accept"].payload.actor_id = A
	corrupt.life.events[int(corrupt.godot.capabilities.commands["plan:accept"].event_seq) - 1].actor_id = A
	check(not world._validate_state(corrupt).ok, "proposer cannot forge the other participant's consent")
	corrupt = valid.duplicate(true)
	corrupt.godot.capabilities.plans["plan:one"].children[1].command_id = "plan:independent"
	check(not world._validate_state(corrupt).ok, "unrelated resident's work cannot serve as a plan child")
	world.release_writer(stage.path)
	restored = Actions.new()
	check(restored.load_from(stage.path).ok and _same_value(restored.snapshot(), valid), "mid-plan save restores children, consent and progress")
	world = restored
	stage.world = world
	for id in [A, B]: world.host_move(id, world.destination(id, "travel"))
	check(world.transaction(stage.path, func(): return world.advance(.25)).ok, "arrived physical positions settle through existing world reducers")
	check(world.capability_store().plans["plan:one"].status == "completed", "both real arrivals complete shared plan")
	check(world.action_receipt("plan:accept").status == "completed", "parent receipt follows child completion")
	var after: Dictionary = world.snapshot()
	check(world.perform_action(stage.path, B, "ability:accept_visit:plan:one", "plan:accept", "opengameagent_fixture", "Yes, let us go.").duplicate, "cold replay never starts travel twice")
	check(world.snapshot() == after and _same_value(after.life.events.slice(0, valid.life.seq), valid.life.events), "full historical prefix and completed plan stay unchanged")
	receipts.append({"scenario": "joint_visit", "seq": after.life.seq, "status": world.capability_store().plans["plan:one"].status})
	_close_stage(stage)

	stage = _new_stage("decline_expire")
	world = stage.world
	_do(stage, A, invite, "plan:decline")
	_do(stage, B, "ability:decline_visit:plan:decline", "plan:declined", "I prefer to stay.")
	check(world.capability_store().plans["plan:decline"].status == "declined" and world.pending_job(A).is_empty(), "declining imposes no movement or obligation")
	_do(stage, A, invite, "plan:cancel")
	_do(stage, A, "ability:cancel_invitation:plan:cancel", "plan:cancelled")
	check(world.capability_store().plans["plan:cancel"].status == "cancelled", "proposer may withdraw before acceptance")
	_do(stage, A, invite, "plan:expire")
	for delta in [120.0, 120.0, 61.0]:
		check(world.transaction(stage.path, func(): return world.advance(delta)).ok, "bounded world ticks can expire an unanswered invitation")
	check(world.capability_store().plans["plan:expire"].status == "expired", "unanswered invitation does not block future plans forever")
	_close_stage(stage)

	stage = _new_stage("blocked-child")
	world = stage.world
	_do(stage, A, invite, "blocked:invite")
	_do(stage, B, "ability:accept_visit:blocked:invite", "blocked:accept")
	world.host_move(A, world.destination(A, "travel"))
	world.observe_place_travel(B, world.position_of(B), 60)
	check(world.transaction(stage.path, func(): return world.advance(60)).ok, "one child arrives while its counterpart makes no progress")
	var blocked: Dictionary = world.capability_store().plans["blocked:invite"]
	check(blocked.status == "blocked" and world.action_receipt("blocked:accept").status == "rejected", "a blocked child cannot produce a successful shared visit")
	check(world.action_receipt(blocked.children[0].command_id).status == "completed" and world.action_receipt(blocked.children[1].command_id).status == "rejected", "completed travel is preserved separately from failed travel")
	valid = world.snapshot()
	world.release_writer(stage.path)
	restored = Actions.new()
	check(restored.load_from(stage.path).ok and _same_value(restored.snapshot(), valid), "mixed child outcomes survive full cold restore")
	stage.world = restored
	_close_stage(stage)
	print(JSON.stringify({"suite": "town_capabilities", "checks": checks, "failures": failures, "paid_calls": 0, "capabilities": definitions.size(), "scenarios": receipts}))
	quit(0 if failures == 0 else 1)
