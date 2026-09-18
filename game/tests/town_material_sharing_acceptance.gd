extends "res://tests/town_material_notice_acceptance.gd"
const Sharing = preload("res://core/actions/material_knowledge_capability.gd")
const S := "fictional:forge"
const R := "fictional:birch"
const THIRD := "fictional:ember"

func _stage() -> Dictionary:
	var path := "user://material-sharing-%d.json" % Time.get_ticks_usec()
	_write_fixture(path, material_fixture())
	var world := FullWorld.new()
	check(world.load_from(path).ok, "unchanged legacy fixture loads")
	check(world.transaction(path, func(): return world.install_material_source(spec(), 1, "development_gm:source")).ok, "source installed without resident knowledge")
	for pair in [[S, Vector3(-4.5, 0, -3)], [R, Vector3(-3.5, 0, -3)], [THIRD, Vector3(35, 0, 35)]]:
		world.host_move(pair[0], pair[1])
	return {"world": world, "path": path}

func _share(world, from: String, to: String) -> String:
	return Sharing.new().option_id(spec().id, to) if world._known_materials(from).has(spec().id) else "ability:share_material:unknown"

func _close(stage: Dictionary) -> void:
	stage.world.release_writer(stage.path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(stage.path))

func run() -> void:
	var stage := _stage()
	var world = stage.world
	check(world.action_options(S).filter(func(o): return o.capability_id == Sharing.ID).is_empty(), "ignorant speaker has no share action")
	check(world.observe_material_notice(S, true).learned.size() == 1, "speaker personally reads notice in isolated fixture")
	var option := _share(world, S, R)
	var before: Dictionary = world.snapshot()
	check(_offered(world, S, option) and world.snapshot() == before, "discovery is pure and offers an explicit recipient")
	check(world._known_materials(R).is_empty() and world._known_materials(THIRD).is_empty(), "proximity alone shares nothing")
	world.host_move(R, Vector3(50, 0, 50))
	before = world.snapshot()
	check(not world.perform_action(stage.path, S, option, "share:far", "opengameagent_fixture").ok and world.snapshot() == before, "stale out-of-range recipient is rejected atomically")
	world.host_move(R, Vector3(-3.5, 0, -3))
	before = world.snapshot()
	check(not world.perform_action(stage.path, S, option, "share:invented", "opengameagent_fixture", "Unlimited iron is waiting.").ok and world.snapshot() == before, "custom speech cannot replace the sourced statement")
	var sent: Dictionary = world.perform_action(stage.path, S, option, "share:first", "opengameagent_fixture")
	check(sent.ok and sent.speech_delivery.delivered, "explicit choice delivers one canonical route statement")
	if not sent.ok:
		print(JSON.stringify({"sharing_failure": sent}))
		_close(stage)
		quit(1)
		return
	var event: Dictionary = world.snapshot().life.events[-1]
	check(event.type == Sharing.EVENT and event.recipient_ids == [S, R] and event.contractual == false, "only the actual speaker and listener receive the event")
	var public: Array = world._public_life_event_evidence().filter(func(e): return e.event_id == event.event_id)
	check(public.size() == 1 and public[0].delivered_text == event.text and not public[0].has("source_event_seq") and not public[0].discriminators.achieved_capability, "GM receives only actual public words, not private source history or invented achievement")
	var view: Dictionary = world.resident_view(R).material_sources[0]
	check(view.last_observed_stock == null and view.reported_by_id == S and view.knowledge_source == "reported_location_current_stock_unverified", "recipient knows who reported the route, not its stock")
	check(world._known_materials(THIRD).is_empty(), "distant third party receives nothing")
	check(world.snapshot().life.accounts == before.life.accounts and world.snapshot().life.contracts == before.life.contracts and world.material_sources()[0].stock == 1, "sharing creates no goods or contracts")
	check(_offered(world, R, "material:recover:" + str(spec().id)), "listener may choose existing physical collection")
	var shared: Dictionary = world.snapshot()
	check(world.perform_action(stage.path, S, option, "share:first", "opengameagent_fixture").duplicate and world.snapshot() == shared, "exact replay creates no second utterance")
	check(not world.perform_action(stage.path, S, option, "share:again", "opengameagent_fixture").ok and world.snapshot() == shared, "already informed listener is not spammed")
	world.release_writer(stage.path)
	var cold := FullWorld.new()
	check(cold.load_from(stage.path).ok and _same(cold.snapshot(), shared), "entire disclosure and knowledge cold-restore exactly")
	for defect in ["speaker_origin", "future_origin", "recipient", "range", "text", "stock", "known_stock", "speech_receipt", "private_prior", "private_learning", "orphan", "missing_store"]:
		var corrupt := shared.duplicate(true)
		var last: Dictionary = corrupt.life.events[-1]
		match defect:
			"speaker_origin": last.source_event_seq = 1
			"future_origin": last.source_event_seq = last.seq
			"recipient": last.recipient_ids = [S, THIRD]
			"range": last.recipient_position = [60, 0, 60]
			"text": last.text = "The heap certainly has iron."
			"stock": last.stock = 1
			"known_stock": corrupt.godot.materials.known[R][spec().id].stock = 1
			"speech_receipt": corrupt.godot.capabilities.commands["share:first"].result.speech_delivery.text = "Other speech."
			"private_prior": last.recipient_prior_event_seq = last.seq
			"private_learning": corrupt.godot.capabilities.commands["share:first"].result.location_learned = false
			"orphan": corrupt.godot.capabilities.commands.erase("share:first")
			"missing_store": corrupt.godot.erase("capabilities")
		check(not cold._validate_state(corrupt).ok, "reject disclosure corruption: " + defect)
	stage.world = cold
	world = cold
	world.host_move(THIRD, world.position_of(R) + Vector3(1, 0, 0))
	check(world.perform_action(stage.path, R, _share(world, R, THIRD), "share:relay", "opengameagent_fixture").ok, "informed listener can explicitly relay to a new nearby resident")
	check(world.snapshot().life.events[-1].source_event_seq == event.seq and world.resident_view(THIRD).material_sources[0].reported_by_id == R, "relay keeps the full earlier source chain and immediate speaker")
	check(world.save_to(stage.path).ok, "relay history validates durably")
	_close(stage)

	stage = _stage()
	world = stage.world
	world.host_move(S, Vector3(0, 0, 4))
	world.advance(0)
	check(world.resident_view(S).material_sources[0].last_observed_stock == 1, "speaker directly observes real finite stock in fixture")
	world.host_move(S, Vector3(-4.5, 0, -3))
	option = _share(world, S, R)
	before = world.snapshot()
	var batch := [{"actor_id": S, "option_id": option, "command_id": "share:rollback", "provenance": "opengameagent_fixture", "speech": ""},
		{"actor_id": THIRD, "option_id": "ability:invalid", "command_id": "share:invalid", "provenance": "opengameagent_fixture", "speech": ""}]
	check(not world.execute_atomic_actions(batch).ok and world.snapshot() == before, "later batch failure rolls back speech and recipient knowledge")
	check(world.perform_action(stage.path, S, option, "share:sighted", "opengameagent_fixture").ok, "sighted speaker may share the location")
	check(world.resident_view(R).material_sources[0].last_observed_stock == null, "even observed stock is not laundered into recipient sight")
	var initial_iron: float = world._trade_account(R).iron
	check(world.perform_action(stage.path, R, "material:recover:" + str(spec().id), "share:collect", "opengameagent_fixture").ok, "listener freely chooses the existing collection primitive")
	world.advance(20)
	check(world._trade_account(R).iron == initial_iron, "reported location gives no remote material")
	world.host_move(R, Vector3(0, 0, 4)) # Rule fixture only; physical movement is separately tested.
	world.advance(60)
	check(world.material_sources()[0].stock == 0 and world._trade_account(R).iron == initial_iron + 1, "arrival and labor conserve the finite material")
	check(world.resident_view(R).material_sources[0].knowledge_source == "personal_proximity_observation", "direct sight supersedes reported knowledge")
	world.host_move(R, world.position_of(S) + Vector3(1, 0, 0))
	check(not _offered(world, S, _share(world, S, R)), "sharing cannot erase the listener's observed depletion")
	world.host_move(THIRD, world.position_of(S) + Vector3(2, 0, 0))
	check(world.perform_action(stage.path, S, _share(world, S, THIRD), "share:another", "opengameagent_fixture").ok, "speaker tells another nearby listener")
	check(_offered(world, THIRD, _share(world, THIRD, R)), "new speaker's menu does not inspect recipient private knowledge")
	var depleted: Dictionary = world._known_materials(R).duplicate(true)
	var repeated: Dictionary = world.perform_action(stage.path, THIRD, _share(world, THIRD, R), "share:already-known", "opengameagent_fixture")
	check(repeated.ok and repeated.speech_delivery.delivered and not repeated.has("location_learned"), "redundant speech does not reveal listener private knowledge in feedback")
	check(world._known_materials(R) == depleted and not _offered(world, R, "material:recover:" + str(spec().id)), "redundant report preserves exact earlier depletion knowledge")
	var corrupt_depletion: Dictionary = world.snapshot()
	corrupt_depletion.godot.materials.known[R][spec().id] = {"stock": null, "event_seq": corrupt_depletion.life.seq, "observed_elapsed": corrupt_depletion.godot.elapsed_seconds}
	check(not world._validate_state(corrupt_depletion).ok, "a redundant report cannot be forged into newly unknown stock")
	check(world.save_to(stage.path).ok, "historical disclosure remains valid after depletion")
	_close(stage)
	print(JSON.stringify({"suite": "town_material_sharing", "checks": checks, "failures": failures, "paid_calls": 0}))
	quit(0 if failures == 0 else 1)
