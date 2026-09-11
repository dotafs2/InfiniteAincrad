extends "res://tests/town_trade_acceptance.gd"
const Materials = preload("res://core/town_runtime.gd")
const Turns = preload("res://agents/town_turns.gd")
const Visuals = preload("res://spatial/town_material_sources.gd")

func material_fixture() -> Dictionary:
	var seed := trade_fixture()
	seed.life.seq = 1
	seed.life.events = [{"seq": 1, "event_id": "life_event_1", "type": "ask_help", "actor_id": "fictional:forge", "subject_id": "fictional:birch", "recipient_ids": ["fictional:forge", "fictional:birch"], "text": "I need a finite source of iron.", "operation_id": "fixture:need", "request_id": "godot_help:fixture:need", "source": "opengameagent_fixture"}]
	return seed

func spec(stock: int = 1) -> Dictionary:
	return {"id": "fixture:iron-source", "label": "Public iron offcuts", "material": "iron", "initial_stock": stock, "position": [0, 0, 4], "access": "public"}

func load_materials(path: String):
	var town := Materials.new()
	var result := town.load_from(path)
	check(result.ok, "material fixture loads: " + str(result.get("code", "")))
	return town

func run() -> void:
	var path := "user://finite-materials-%d.json" % Time.get_ticks_usec()
	_write_fixture(path, material_fixture())
	var town = load_materials(path)
	var owner := "fictional:ember"
	var smith := "fictional:forge"
	var carpenter := "fictional:birch"
	var action := "material:recover:fixture:iron-source"
	var before: Dictionary = town.snapshot()
	check(town.material_sources().is_empty() and not town.snapshot().godot.has("materials"), "old save loads without installing or creating resources")
	check(not town.transaction(path, func(): return town.install_material_source(spec(), 1, "npc:install")).ok, "resident command cannot install")
	check(not town.transaction(path, func(): return town.install_material_source(spec(), 999, "development_gm:no-need")).ok, "installation needs existing attributed speech")
	check(town.snapshot() == before, "rejected installs leave all state unchanged")
	var invalid := spec(); invalid.initial_stock = -1
	check(not town.transaction(path, func(): return town.install_material_source(invalid, 1, "development_gm:negative")).ok, "negative stock rejected")
	check(town.transaction(path, func(): return town.install_material_source(spec(), 1, "development_gm:source")).ok, "reviewed finite public source installed")
	var installed: Dictionary = town.snapshot()
	check(installed.residents == before.residents and installed.life.accounts == before.life.accounts and installed.life.items == before.life.items and installed.life.contracts == before.life.contracts, "install preserves all identities, money, inventory and contracts")
	check(installed.life.events.slice(0, before.life.events.size()) == before.life.events, "install preserves historical prefix")
	check(town.transaction(path, func(): return town.install_material_source(spec(), 1, "development_gm:source")).duplicate, "same install is idempotent")
	check(not town.transaction(path, func(): return town.install_material_source(spec(2), 1, "development_gm:source")).ok, "same command cannot increase stock")
	check(not town.transaction(path, func(): return town.install_material_source(spec(), 1, "development_gm:other")).ok, "new command cannot replenish existing source")
	check(town.resident_view(smith).material_sources.is_empty(), "install does not broadcast hidden GM knowledge")
	check(not town.trade_options(smith).any(func(o): return o.id == action), "unobserved source has no action option")
	check(not town.transaction(path, func(): return town.submit_trade(smith, action, "fixture:guess", "opengameagent_fixture")).ok, "guessing source ID cannot bypass knowledge")
	elapse(town, path, 0)
	check(town.resident_view(smith).material_sources.is_empty(), "distant NPC does not learn stock on tick")
	town.host_move(smith, Vector3(0, 0, 3.6))
	town.host_move(owner, Vector3(0.2, 0, 3.7))
	elapse(town, path, 0)
	check(town.resident_view(smith).material_sources[0].last_observed_stock == 1, "nearby resident personally observes finite stock")
	check(town.resident_view(carpenter).material_sources.is_empty(), "another resident has no remote source knowledge")
	check(not JSON.stringify(town.resident_view(smith)).contains("development_gm"), "personal view does not reveal development GM installation")
	var count: int = town.snapshot().life.seq
	elapse(town, path, 0)
	check(town.snapshot().life.seq == count, "unchanged sight does not emit thought-triggering events")
	var visuals := Visuals.new(); root.add_child(visuals); visuals.configure(town)
	check(visuals.get_child_count() == 1 and visuals.sources[spec().id].display.get_child(1).visible, "one visible finite bundle in scene projection")
	var returned: Array = town.material_sources()
	returned[0].stock = 99
	check(town.material_sources()[0].stock == 1, "visual projection cannot mutate authority")
	execute(town, path, smith, action, "fixture:smith-recover")
	execute(town, path, owner, action, "fixture:owner-recover")
	check(town.trade_options(smith).size() == 1, "labor blocks overlapping trade but keeps optional wait")
	var start_state: Dictionary = town.snapshot()
	check(town.submit_trade(smith, action, "fixture:smith-recover", "opengameagent_fixture").duplicate and town.snapshot() == start_state, "duplicate labor start changes nothing")
	check(not town.submit_trade(smith, "wait", "fixture:smith-recover", "opengameagent_fixture").ok, "same command cannot cross modules")
	town.host_move(smith, Vector3(9, 0, 4))
	elapse(town, path, 30)
	check(town.pending_job(owner).elapsed == 30 and town.pending_job(smith).elapsed == 0, "only physical arrival earns labor progress")
	var saved_bytes := FileAccess.get_file_as_bytes(path)
	town.release_writer(path)
	town = load_materials(path)
	check(FileAccess.get_file_as_bytes(path) == saved_bytes and town.pending_job(owner).elapsed == 30, "mid-labor cold restart preserves exact save and work")
	check(town.transaction(path, func(): return town.install_material_source(spec(), 1, "development_gm:source")).duplicate, "cold restart keeps install idempotency")
	var rollback: Dictionary = town.snapshot()
	DirAccess.make_dir_absolute(ProjectSettings.globalize_path(path + ".tmp"))
	check(not town.transaction(path, func(): return town.advance(30)).ok and town.snapshot() == rollback, "failed save rolls back stock transfer and completed labor")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".tmp"))
	elapse(town, path, 30)
	check(town._trade_account(owner).iron == 1 and town.material_sources()[0].stock == 0 and town.material_sources()[0].recovered == 1, "last unit moves from source to first worker exactly once")
	check(town.resident_view(smith).material_sources[0].last_observed_stock == 1, "distant worker retains stale personal stock, not remote truth")
	town.host_move(smith, Vector3(0, 0, 4))
	elapse(town, path, 60)
	check(town._trade_account(smith).iron == 1 and town._materials().commands["fixture:smith-recover"].result.code == "material_depleted", "second worker gets truthful depletion with no extra iron")
	check(town.pending_job(smith).is_empty() and town.pending_job(owner).is_empty(), "both jobs finish without orphaning")
	check(town.resident_view(smith).material_sources[0].last_observed_stock == 0 and not town.trade_options(smith).any(func(o): return o.id == action), "arrival updates personal depletion and options")
	var turns := Turns.new(); turns.town = town
	var feedback: Array = turns._feedback_history(smith, {"history": [{"command_id": "fixture:smith-recover", "status": "settled"}]})
	check(feedback[0].result.code == "material_depleted" and not feedback[0].result.ok, "model receives authoritative failed labor receipt")
	turns.free()
	var completed: Dictionary = town.snapshot()
	check(town.submit_trade(owner, action, "fixture:owner-recover", "opengameagent_fixture").duplicate and town.snapshot() == completed, "duplicate completed command never pays material twice")
	check(town.resident(owner).coins_col == before.residents[0].coins_col and town.resident(smith).coins_col == 3, "public recovery changes no coins")
	visuals.town = town; visuals._process(0)
	check(not visuals.sources[spec().id].display.get_child(1).visible, "depleted bundle disappears while source label remains")
	for mutate in ["stock", "receipt", "observation", "install", "source_type", "command_type", "cross_module_command"]:
		var corrupt: Dictionary = town.snapshot()
		if mutate == "stock":
			corrupt.godot.materials.sources[spec().id].stock = 1
		elif mutate == "receipt":
			corrupt.godot.materials.commands["fixture:owner-recover"].result.quantity = 2
		elif mutate == "observation":
			corrupt.godot.materials.known[smith][spec().id].event_seq = 1
		elif mutate == "install":
			corrupt.godot.materials.installs["development_gm:source"].payload.spec.initial_stock = 2
		elif mutate == "source_type":
			corrupt.godot.materials.sources[spec().id] = []
		elif mutate == "command_type":
			corrupt.godot.materials.commands["fixture:owner-recover"] = []
		else:
			corrupt.godot.commands["fixture:owner-recover"] = {"payload": {"actor_id": owner}, "status": "completed"}
		check(not town._validate_state(corrupt).ok, "tampered " + mutate + " fails validation")
	elapse(town, path, 120)
	check(town.material_sources()[0].stock == 0, "finite material does not use berry regeneration")
	saved_bytes = FileAccess.get_file_as_bytes(path)
	town.release_writer(path)
	var final_town = load_materials(path)
	check(FileAccess.get_file_as_bytes(path) == saved_bytes and final_town.material_sources()[0].stock == 0 and final_town._trade_account(owner).iron == 1, "final cold restore keeps depleted source and acquired property")
	visuals.free()
	town.release_writer(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print(JSON.stringify({"suite": "town_materials", "checks": checks, "failures": failures, "paid_calls": 0}))
	quit(0 if failures == 0 else 1)
