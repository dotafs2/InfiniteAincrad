extends "res://tests/town_materials_acceptance.gd"
const FullWorld = preload("res://core/town_actions.gd")

func _offered(world, actor: String, action: String) -> bool:
	return world.action_options(actor).any(func(row): return row.id == action)

func run() -> void:
	var path := "user://material-notice-%d.json" % Time.get_ticks_usec()
	_write_fixture(path, material_fixture())
	var world := FullWorld.new()
	check(world.load_from(path).ok, "unchanged legacy world loads")
	var before := world.snapshot()
	check(world.material_notice_entries().is_empty() and world.snapshot() == before, "no implicit notice or source migration")
	check(world.transaction(path, func(): return world.install_material_source(spec(), 1, "development_gm:source")).ok, "install existing finite source")
	var actor := "fictional:forge"
	var other := "fictional:birch"
	var action: String = "material:recover:" + str(spec().id)
	var installed := world.snapshot()
	var entries: Array = world.material_notice_entries()
	check(entries.size() == 1 and not entries[0].has("stock") and not entries[0].has("initial_stock") and not entries[0].has("source_need"), "posted content excludes stock and private GM evidence")
	check(entries[0].text.contains("current stock unknown") and world.snapshot() == installed, "notice content is honest read-only route information")
	world.host_move(actor, world.material_notice_position() + Vector3(5, 0, 0))
	before = world.snapshot()
	check(world.observe_material_notice(actor, true).learned.is_empty() and world.snapshot() == before, "claimed visibility cannot bypass reading distance")
	world.host_move(actor, world.material_notice_position() + Vector3(1, 0, 0))
	before = world.snapshot()
	check(world.observe_material_notice(actor, false).learned.is_empty() and world.snapshot() == before, "nearby but occluded notice grants nothing")
	check(not _offered(world, actor, action), "source identifier alone is not knowledge")
	check(world.transaction(path, func(): return world.observe_material_notice(actor, true)).ok, "host-visible notice records personal reading")
	var known: Dictionary = world.resident_view(actor).material_sources[0]
	check(known.last_observed_stock == null and known.knowledge_source == "personally_read_public_material_notice_stock_unknown", "advertised location never becomes observed stock")
	check(_offered(world, actor, action), "reader may choose a trip with no stock guarantee")
	check(world.resident_view(other).material_sources.is_empty() and not _offered(world, other, action), "another resident does not inherit notice knowledge")
	check(world.snapshot().life.accounts == installed.life.accounts and world.snapshot().godot.materials.sources == installed.godot.materials.sources, "reading grants no material and changes no stock")
	var read := world.snapshot()
	check(world.observe_material_notice(actor, true).learned.is_empty() and world.snapshot() == read, "repeated reading is idempotent")
	check(world.save_to(path).ok, "unknown-stock knowledge saves")
	world.release_writer(path)
	var restored := FullWorld.new()
	check(restored.load_from(path).ok and _same(restored.snapshot(), read), "null stock and complete world survive cold restore")
	world = restored
	for defect in ["stock", "range", "recipient", "text", "knowledge", "direct_type", "missing_store"]:
		var corrupt := read.duplicate(true)
		match defect:
			"stock": corrupt.life.events[-1].stock = 1
			"range": corrupt.life.events[-1].observer_position = [40, 0, 40]
			"recipient": corrupt.life.events[-1].recipient_ids = [other]
			"text": corrupt.life.events[-1].text = "There is unlimited iron."
			"knowledge": corrupt.godot.materials.known[actor][spec().id].stock = 1
			"direct_type": corrupt.life.events[-1].type = "material_source_observed"
			"missing_store": corrupt.godot.erase("materials")
		check(not world._validate_state(corrupt).ok, "reject corrupted notice " + defect)
	check(world.perform_action(path, actor, action, "fixture:notice-trip", "opengameagent_fixture").ok, "known location admits existing collection primitive")
	world.advance(20)
	check(world.pending_job(actor).elapsed == 0 and world._trade_account(actor).iron == 1, "remote travel neither works nor grants iron")
	world.host_move(actor, Vector3(0, 0, 4)) # Isolated rule fixture, not physical evidence.
	world.advance(0)
	check(world.resident_view(actor).material_sources[0].last_observed_stock == 1, "direct arrival observation replaces unknown with actual count")
	check(world.resident_view(actor).material_sources[0].knowledge_source == "personal_proximity_observation", "direct observation retains actual source type")
	world.advance(60)
	check(world._trade_account(actor).iron == 2 and world.material_sources()[0].stock == 0, "existing 60-second job conserves one finite unit")
	world.host_move(actor, world.material_notice_position())
	before = world.snapshot()
	check(world.observe_material_notice(actor, true).learned.is_empty() and world.snapshot() == before and not _offered(world, actor, action), "notice cannot overwrite personally observed depletion")
	check(world.save_to(path).ok, "historical notice still validates after direct observation and depletion")
	world.host_move(other, world.material_notice_position())
	check(world.observe_material_notice(other, true).learned.size() == 1 and world.resident_view(other).material_sources[0].last_observed_stock == null, "a new reader still cannot remotely learn the depletion")
	check(world.perform_action(path, other, action, "fixture:empty-trip", "opengameagent_fixture").ok, "stale sign permits an honest uncertain trip")
	world.host_move(other, Vector3(0, 0, 4))
	world.advance(60)
	check(world.action_receipt("fixture:empty-trip").status == "rejected" and world._trade_account(other).iron == 0, "empty arrival gives explicit failure and no material")
	check(world.save_to(path).ok, "depleted trip and both notice histories save")
	world.release_writer(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print(JSON.stringify({"suite": "town_material_notice", "checks": checks, "failures": failures, "paid_calls": 0}))
	quit(0 if failures == 0 else 1)

func _same(a: Variant, b: Variant) -> bool:
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key in a:
			if not b.has(key) or not _same(a[key], b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for index in a.size():
			if not _same(a[index], b[index]): return false
		return true
	return a == b
