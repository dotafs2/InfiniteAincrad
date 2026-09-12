extends "res://tests/town_materials_acceptance.gd"

class PrivateNeedBrain extends Node:
	func propose(view: Dictionary, _seq: int) -> Dictionary:
		var action: String = view.available_actions[0]
		return {"ok": true, "decision": {"action": action, "reason": "PRIVATE_DELIBERATION_KEEP_PRIVATE",
			"need": {"capability_id": "finite_iron_source", "reason": "PRIVATE_NEED_我需要可以实际取得的铁料。"}},
			"command_id": "offline:private-need", "provenance": "opengameagent_fixture"}

func run() -> void:
	var path := "user://private-material-need-%d.json" % Time.get_ticks_usec()
	_write_fixture(path, trade_fixture())
	var town = load_materials(path)
	var owner := "fictional:ember"
	var smith := "fictional:forge"
	var before: Dictionary = town.snapshot()
	var turns := Turns.new()
	root.add_child(turns)
	turns.town = town
	turns.save_path = path
	var brain := PrivateNeedBrain.new()
	turns.add_child(brain)
	turns.brains[owner] = brain
	var accepted: Dictionary = await turns.step(owner)
	check(accepted.ok, "real turn controller accepts offline private need")
	if not accepted.ok:
		push_error(JSON.stringify(accepted))
		quit(1)
		return
	var record: Dictionary = town.snapshot().godot.resident_turns[owner]
	var request_id: String = record.request_id
	check(record.action == "wait", "offline controller chose the offered wait action")
	check(record.need_status == "capability_proposed", "need has accepted canonical journal source")
	check(town.snapshot().life.events == before.life.events, "wait plus need creates no public speech")
	check(town.material_sources().is_empty(), "need alone never installs or creates resources")
	var after_need: Dictionary = town.snapshot()
	check(not town.transaction(path, func(): return town.install_material_source_from_need(spec(), owner, request_id, "npc:install")).ok, "resident cannot install")
	check(not town.transaction(path, func(): return town.install_material_source_from_need(spec(), smith, request_id, "development_gm:wrong-person")).ok, "another resident cannot supply this need")
	check(not town.transaction(path, func(): return town.install_material_source_from_need(spec(), owner, "missing:request", "development_gm:missing")).ok, "unknown request cannot supply need")
	check(not town.transaction(path, func(): return town.install_material_source(spec(), 0, "development_gm:fake-speech")).ok, "private need is never reinterpreted as public speech")
	check(town.snapshot() == after_need, "rejections leave identities, property and journal unchanged")
	var result: Dictionary = town.transaction(path, func(): return town.install_material_source_from_need(spec(2), owner, request_id, "development_gm:private-source"))
	check(result.ok, "reviewed host installation consumes exact private need source: " + str(result.get("code", "")))
	if not result.ok:
		quit(1)
		return
	var installed: Dictionary = town.snapshot()
	var source: Dictionary = town.material_sources()[0]
	check(source.source_need.kind == "resident_capability_need" and source.source_need.need_request_id == request_id, "source preserves canonical request attribution")
	check(source.source_need.text == record.history[-1].need.reason, "source preserves original need text")
	check(installed.life.events[-1].recipient_ids == [] and not installed.life.events[-1].has("text"), "installation is not public words")
	check(not JSON.stringify(town.resident_view(smith)).contains("PRIVATE_NEED_"), "other resident cannot read private installation reason")
	check(not JSON.stringify(town.resident_view(owner)).contains("PRIVATE_DELIBERATION_"), "GM installation does not disclose private deliberation")
	check(installed.residents == before.residents and installed.life.accounts == before.life.accounts and installed.life.items == before.life.items, "installation preserves existing identities, coins and property")
	check(town.transaction(path, func(): return town.install_material_source_from_need(spec(2), owner, request_id, "development_gm:private-source")).duplicate, "installation replay is idempotent")
	check(not town.transaction(path, func(): return town.install_material_source_from_need(spec(3), owner, request_id, "development_gm:private-source")).ok, "same command cannot increase stock")
	check(not town.transaction(path, func(): return town.install_material_source(spec(2), 0, "development_gm:private-source")).ok, "same command cannot change private provenance to speech")
	# A derived proposal may legitimately be pruned. The accepted journal remains.
	check(town.transaction(path, func():
		town._state.godot.background_gm.proposals.erase(record.need_proposal_id)
		return {"ok": true}
	).ok, "derived proposal absence does not invalidate canonical installation")
	var saved := FileAccess.get_file_as_bytes(path)
	town.release_writer(path)
	town = load_materials(path)
	check(FileAccess.get_file_as_bytes(path) == saved, "cold load never rewrites world")
	check(town.material_sources()[0].source_need == source.source_need, "cold load preserves private source without bounded proposal")
	check(town.transaction(path, func(): return town.install_material_source_from_need(spec(2), owner, request_id, "development_gm:private-source")).duplicate, "cold replay remains idempotent")
	for tamper in ["reason", "owner", "request", "journal", "install", "event", "kind", "minimal_entry", "provider_error", "turns_array", "turns_null", "boolean_epoch"]:
		var corrupt: Dictionary = town.snapshot()
		var corrupt_source: Dictionary = corrupt.godot.materials.sources[spec().id]
		if tamper == "reason":
			corrupt_source.source_need.text = "invented"
		elif tamper == "owner":
			corrupt_source.source_need.actor_id = smith
		elif tamper == "request":
			corrupt_source.source_need.need_request_id = "invented:request"
		elif tamper == "journal":
			corrupt.godot.resident_turns[owner].history[-1].need.reason = "rewritten"
		elif tamper == "install":
			corrupt.godot.materials.installs["development_gm:private-source"].payload.source_need.text = "rewritten"
		elif tamper == "event":
			corrupt.life.events[-1].source_need_request_id = "invented:request"
		elif tamper == "minimal_entry":
			var old: Dictionary = corrupt.godot.resident_turns[owner].history[-1]
			corrupt.godot.resident_turns[owner].history[-1] = {"command_id": request_id, "need_request_id": request_id, "need": old.need, "need_controller_epoch": 0, "need_source_sequence": 0}
		elif tamper == "provider_error":
			corrupt.godot.resident_turns[owner].history[-1].status = "provider_error"
		elif tamper == "turns_array":
			corrupt.godot.resident_turns = []
		elif tamper == "turns_null":
			corrupt.godot.resident_turns = null
		elif tamper == "boolean_epoch":
			corrupt.godot.resident_turns[owner].history[-1].need_controller_epoch = true
		else:
			corrupt_source.source_need.kind = "public_speech"
		check(not town._validate_state(corrupt).ok, "tampered private source rejected: " + tamper)
	town.host_move(owner, Vector3(0, 0, 4))
	elapse(town, path, 0.5)
	check(town.resident_view(owner).material_sources.size() == 1, "resident learns installed material through personal observation")
	execute(town, path, owner, "material:recover:" + spec().id, "offline:private-source-recover")
	elapse(town, path, 30)
	check(town.pending_job(owner).elapsed == 30, "unfinished work has real elapsed progress")
	saved = FileAccess.get_file_as_bytes(path)
	town.release_writer(path)
	town = load_materials(path)
	check(FileAccess.get_file_as_bytes(path) == saved and town.pending_job(owner).elapsed == 30, "cold load preserves unfinished work and all bytes")
	elapse(town, path, 30)
	check(town._trade_account(owner).iron == 1 and town.material_sources()[0].stock == 1 and town.material_sources()[0].recovered == 1, "same resident uses finite source with conserved stock")
	var final_state: Dictionary = town.snapshot()
	check(town.submit_trade(owner, "material:recover:" + spec().id, "offline:private-source-recover", "opengameagent_fixture").duplicate and town.snapshot() == final_state, "completed work cannot be paid twice")
	check(not JSON.stringify(town.resident_view(smith)).contains("PRIVATE_NEED_"), "private source remains private after adoption")
	town.release_writer(path)
	turns.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print(JSON.stringify({"suite": "town_material_private_need", "checks": checks, "failures": failures, "paid_calls": 0, "arrival": "scripted_offline", "new_capability": "host installation from canonical private need"}))
	quit(0 if failures == 0 else 1)
