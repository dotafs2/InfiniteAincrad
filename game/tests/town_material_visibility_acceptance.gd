extends "res://tests/town_materials_acceptance.gd"
## Material line-of-sight in a real physics fixture using production components.
## Command:
## python -X utf8 tools/run_godot.py --godot <godot> --name material-visibility --timeout 120 --out tmp/overnight-20260912/h23-acceptance -- --headless --script res://tests/town_material_visibility_acceptance.gd
##
## This suite drives the real Sight component and the real core transactions
## through actual physics frames. It never mutates known/stock/events directly
## after the fixture seed; every state-changing tick goes through
## town.transaction(path, func(): return town.advance(delta)).
##
## Scope note: this is a real-physics fixture using the production Sight
## component. The actual town binding is exercised by a separate test; this
## file does not claim to load a production town.

const Sight = preload("res://spatial/town_material_visibility.gd")

class PhysicsRunner extends Node3D:
	var pending: Callable = Callable()
	var result: Variant = null
	var done: bool = false

	func schedule(callable: Callable) -> void:
		pending = callable
		done = false
		result = null

	func _physics_process(_delta: float) -> void:
		if pending.is_valid():
			var callable := pending
			pending = Callable()
			result = callable.call()
			done = true

class RayProbe extends Node3D:
	var eye: Vector3 = Vector3.ZERO
	var target: Vector3 = Vector3.ZERO
	var observer_rid: RID
	var hit: Dictionary = {}
	var samples: int = 0

	func _physics_process(_delta: float) -> void:
		var exclude: Array[RID] = [observer_rid]
		var query := PhysicsRayQueryParameters3D.create(eye, target, 0xFFFFFFFF, exclude)
		query.hit_from_inside = true
		hit = get_world_3d().direct_space_state.intersect_ray(query)
		samples += 1

var _runner: PhysicsRunner = null
var _probe: RayProbe = null
var _sight: Node3D = null
var _visuals: Node3D = null
var _wall: StaticBody3D = null
var _bodies: Dictionary = {}
var _smith_body: CharacterBody3D = null
var _owner_body: CharacterBody3D = null
var _carpenter_body: CharacterBody3D = null
var _ray_blocked: bool = false
var _ray_collider: Object = null
var _ray_distance: float = -1.0

func _fixture() -> Dictionary:
	var seed := material_fixture()
	seed.godot.positions["fictional:forge"] = [0, 0, 0]
	seed.godot.positions["fictional:ember"] = [15, 0, 0]
	seed.godot.positions["fictional:birch"] = [20, 0, 0]
	return seed

func _source_spec() -> Dictionary:
	return {"id": "fixture:iron-source", "label": "Public iron offcuts", "material": "iron", "initial_stock": 3, "position": [0, 0, 2], "access": "public"}

func _eye() -> Vector3:
	return Vector3(0, 1.55, 0)

func _bar_point() -> Vector3:
	return Vector3(0, 0, 2) + Vector3(0.7, 0.16, 0)

func _make_body(at: Vector3) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	var capsule := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.35
	shape.height = 1.7
	capsule.shape = shape
	capsule.position = Vector3(0, 0.85, 0)
	body.add_child(capsule)
	body.position = at
	root.add_child(body)
	return body

func _build_wall() -> void:
	_wall = StaticBody3D.new()
	_wall.collision_layer = 1
	_wall.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2, 3, 0.2)
	shape.shape = box
	shape.position = Vector3(0.35, 1.5, 1)
	_wall.add_child(shape)
	root.add_child(_wall)

func _build_probe() -> void:
	_probe = RayProbe.new()
	_probe.eye = _eye()
	_probe.target = _bar_point()
	_probe.observer_rid = _smith_body.get_rid()
	root.add_child(_probe)

func _wait_physics(count: int) -> void:
	for _i in count:
		await physics_frame

func _wait_frames(count: int) -> void:
	for _i in count:
		await physics_frame
		await process_frame

func _run_in_physics(callable: Callable) -> Variant:
	_runner.schedule(callable)
	var guard := 0
	while not _runner.done and guard < 120:
		await physics_frame
		await process_frame
		guard += 1
	if not _runner.done:
		check(false, "physics runner did not complete within bounded frames")
		return null
	return _runner.result

func _sight_query(id: String, source_id: String) -> bool:
	var verdict: Variant = await _run_in_physics(func(): return _sight.can_observe(id, source_id))
	return verdict is bool and verdict

func _tick(town, path: String, delta: float) -> Dictionary:
	var verdict: Variant = await _run_in_physics(func(): return town.transaction(path, func(): return town.advance(delta)))
	if verdict is Dictionary:
		return verdict
	return {}

func _finish(town, path: String, writer_released: bool, payload: Dictionary) -> void:
	_cleanup(town, path, writer_released)
	print(JSON.stringify(payload))
	quit(0 if int(payload.get("failures", 1)) == 0 and bool(payload.get("success", false)) else 1)

func _cleanup(town, path: String, writer_released: bool) -> void:
	if _probe != null and is_instance_valid(_probe):
		_probe.queue_free()
	if _sight != null and is_instance_valid(_sight):
		_sight.queue_free()
	if _visuals != null and is_instance_valid(_visuals):
		_visuals.queue_free()
	if _wall != null and is_instance_valid(_wall):
		_wall.queue_free()
	for body in [_smith_body, _owner_body, _carpenter_body]:
		if body != null and is_instance_valid(body):
			body.queue_free()
	if _runner != null and is_instance_valid(_runner):
		_runner.queue_free()
	if town != null and not writer_released:
		town.release_writer(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func run() -> void:
	var path := "user://material-visibility-%d.json" % Time.get_ticks_usec()
	var town = null
	var writer_released := false
	var wall_blocked := false
	var observed_initial := -1
	var observed_current := -1
	var historic_while_blocked := -1

	_write_fixture(path, _fixture())
	var before_bytes := FileAccess.get_file_as_bytes(path)
	town = load_materials(path)
	check(FileAccess.get_file_as_bytes(path) == before_bytes, "fixture bytes unchanged immediately after load")

	var smith := "fictional:forge"
	var owner := "fictional:ember"
	var carpenter := "fictional:birch"
	var action := "material:recover:fixture:iron-source"
	var before: Dictionary = town.snapshot()
	check(town.transaction(path, func(): return town.install_material_source(_source_spec(), 1, "development_gm:iron-source")).ok, "reviewed finite public source installed")
	var installed: Dictionary = town.snapshot()
	check(installed.residents == before.residents and installed.life.accounts == before.life.accounts and installed.life.items == before.life.items and installed.life.contracts == before.life.contracts, "install preserves identities, money, inventory and contracts")
	check(installed.life.events.slice(0, before.life.events.size()) == before.life.events, "install preserves historical prefix")
	check(town.resident_view(smith).material_sources.is_empty(), "install does not broadcast hidden GM knowledge")
	check(not town.trade_options(smith).any(func(o): return o.id == action), "unobserved source has no action option")
	check(not town.transaction(path, func(): return town.submit_trade(smith, action, "fixture:guess", "opengameagent_fixture")).ok, "guessing source ID cannot bypass knowledge")

	# 2. Invalid binding must not grant knowledge; a non-bool probe must not either.
	var pre_bind: Dictionary = town.snapshot()
	town.require_material_visibility(Callable())
	check(town.transaction(path, func(): return town.advance(0)).ok, "advance(0) with invalid probe succeeds")
	check(town.resident_view(smith).material_sources.is_empty(), "invalid probe grants no knowledge")
	town.require_material_visibility(Callable(self, "_string_probe"))
	check(town.transaction(path, func(): return town.advance(0)).ok, "advance(0) with non-bool probe succeeds")
	check(town.resident_view(smith).material_sources.is_empty(), "non-bool probe grants no knowledge")
	check(town.snapshot().life.events == pre_bind.life.events, "invalid bindings emit no events")

	# 3. Real physics ray proof, independent of the component.
	_build_wall()
	_smith_body = _make_body(Vector3(0, 0, 0))
	_owner_body = _make_body(Vector3(15, 0, 0))
	_carpenter_body = _make_body(Vector3(20, 0, 0))
	_build_probe()
	await _wait_frames(3)
	_ray_blocked = not _probe.hit.is_empty() and _probe.hit.get("collider") == _wall
	wall_blocked = _ray_blocked
	_ray_collider = _probe.hit.get("collider")
	_ray_distance = float(_probe.hit.get("position", Vector3.ZERO).distance_to(_probe.eye)) if not _probe.hit.is_empty() else -1.0
	check(_probe.samples >= 1, "physics ray probe executed at least one sample")
	check(_ray_blocked, "engine ray from smith eye to tray bar hits opaque wall")
	check(_ray_distance > 0.0 and _ray_distance < 3.0, "wall hit distance is within observation range")
	check(_smith_body.global_position.is_equal_approx(Vector3(0, 0, 0)), "smith body sits at logical source position")
	check(_source_spec().initial_stock == 3, "logical source starts with 3 units")

	_visuals = Visuals.new()
	root.add_child(_visuals)
	_visuals.configure(town)
	check(_visuals.get_child_count() == 1, "one visual source projection exists")
	var visual_source: Node3D = _visuals.get_child(0)
	check(visual_source.position.is_equal_approx(Vector3(0.7, 0.05, 2)), "visual source sits at the actual tray center")
	check(_visuals.observation_target("fixture:iron-source").is_equal_approx(Vector3(0.7, 0.16, 2)), "observation target is the actual tray bar center")

	_runner = PhysicsRunner.new()
	root.add_child(_runner)
	_sight = Sight.new()
	root.add_child(_sight)
	_bodies = {"fictional:forge": _smith_body, "fictional:ember": _owner_body, "fictional:birch": _carpenter_body}
	_sight.configure(town, _bodies, _visuals)
	town.require_material_visibility(Callable(_sight, "can_observe"))

	check(not await _sight_query(smith, "fixture:iron-source"), "Sight reports blocked line of sight through wall")
	check(not await _sight_query(smith, "fixture:unknown-source"), "Sight reports false for unknown source")
	check(not await _sight_query("fictional:unknown", "fixture:iron-source"), "Sight reports false for unknown observer")
	check(not _sight.can_observe(smith, "fixture:iron-source"), "direct non-physics call is false")

	# 4. Blocked wall: no knowledge, no option, state unchanged.
	var blocked_before: Dictionary = town.snapshot()
	check((await _tick(town, path, 0)).ok, "advance(0) with wall succeeds")
	check(town.resident_view(smith).material_sources.is_empty(), "blocked wall prevents knowledge")
	check(not town.trade_options(smith).any(func(o): return o.id == action), "blocked wall prevents recovery option")
	check(town.resident_view(owner).material_sources.is_empty(), "distant owner has no remote source knowledge")
	check(town.resident_view(carpenter).material_sources.is_empty(), "distant carpenter has no remote source knowledge")
	var blocked_after: Dictionary = town.snapshot()
	check(blocked_after.life.accounts == blocked_before.life.accounts and blocked_after.life.items == blocked_before.life.items and blocked_after.life.contracts == blocked_before.life.contracts, "blocked advance(0) preserves money, inventory and contracts")
	check(blocked_after.life.events == blocked_before.life.events, "blocked advance(0) emits no events")

	# 5. Remove the wall only; smith now sees the source.
	_wall.queue_free()
	_wall = null
	await _wait_physics(2)
	check(await _sight_query(smith, "fixture:iron-source"), "Sight reports true once wall is removed")
	check((await _tick(town, path, 0)).ok, "advance(0) after wall removal succeeds")
	var smith_view: Array = town.resident_view(smith).material_sources
	if smith_view.is_empty():
		_finish(town, path, writer_released, {"suite": "town_material_visibility", "checks": checks, "failures": failures + 1, "paid_calls": 0, "physics_fixture": true, "wall_blocked": wall_blocked, "observed_initial": observed_initial, "observed_current": observed_current, "historic_stock_while_blocked": historic_while_blocked, "success": false})
		return
	check(smith_view.size() == 1, "smith learns exactly one source")
	observed_initial = int(smith_view[0].last_observed_stock) if not smith_view.is_empty() else -1
	check(observed_initial == 3, "smith observes exact stock 3")
	check(smith_view[0].knowledge_source == "personal_line_of_sight_observation", "smith knowledge source is personal line of sight")
	check(town.trade_options(smith).any(func(o): return o.id == action), "smith gains exactly one recovery option")
	var smith_events: Array = town.snapshot().life.events.filter(func(e): return e.get("type") == "material_source_observed" and e.get("actor_id") == smith)
	check(smith_events.size() == 1, "exactly one observation event for smith")
	check(smith_events[0].recipient_ids == [smith], "observation event is personal to smith")
	check(smith_events[0].source == "host_line_of_sight_observation", "observation event records line of sight source")
	var old_observation: Dictionary = smith_events[0].duplicate(true)
	var seq_after_observe: int = town.snapshot().life.seq
	check((await _tick(town, path, 0)).ok, "repeat advance(0) succeeds")
	check(town.snapshot().life.seq == seq_after_observe, "repeat advance(0) emits no new events")
	check(town.resident_view(smith).material_sources[0].last_observed_stock == 3, "reading knowledge does not mutate it")

	# 6. Owner moves to the source through host_move + synchronized body position.
	_build_wall()
	await _wait_frames(2)
	check(_probe.hit.get("collider") == _wall, "rebuilt wall is the actual ray collider")
	check(not await _sight_query(smith, "fixture:iron-source"), "rebuilt wall blocks smith line of sight")
	var owner_move: Dictionary = await _run_in_physics(func():
		return town.transaction(path, func():
			town.host_move(owner, Vector3(0, 0, 2))
			return {"ok": town.position_of(owner).is_equal_approx(Vector3(0, 0, 2)), "code": "host_move_fixture"}))
	check(owner_move.ok, "host_move accepts owner relocation")
	if not owner_move.ok:
		_finish(town, path, writer_released, {"suite": "town_material_visibility", "checks": checks, "failures": failures + 1, "paid_calls": 0, "physics_fixture": true, "wall_blocked": wall_blocked, "observed_initial": observed_initial, "observed_current": observed_current, "historic_stock_while_blocked": historic_while_blocked, "success": false})
		return
	_owner_body.position = Vector3(0, 0, 2)
	await _wait_physics(2)
	check(_owner_body.global_position.is_equal_approx(town.position_of(owner)), "owner body position matches core position after host_move")
	check(await _sight_query(owner, "fixture:iron-source"), "owner physically in front of wall has line of sight")
	check(not await _sight_query(smith, "fixture:iron-source"), "smith behind wall has no line of sight")
	check((await _tick(town, path, 0)).ok, "advance(0) after owner move succeeds")
	var owner_view: Array = town.resident_view(owner).material_sources
	check(owner_view.size() == 1 and int(owner_view[0].last_observed_stock) == 3, "owner learns exact stock 3")
	check(town.trade_options(owner).any(func(o): return o.id == action), "owner gains recovery option")
	var smith_hist_before: int = town.resident_view(smith).material_sources[0].last_observed_stock
	var smith_event_seq_before: int = town.resident_view(smith).material_sources[0].observation_event_seq
	check(town.transaction(path, func(): return town.submit_trade(owner, action, "fixture:visibility-recover", "opengameagent_fixture")).ok, "owner starts real recovery transaction")
	var owner_iron_before: int = town._trade_account(owner).iron
	var smith_iron_before: int = town._trade_account(smith).iron
	var accounts_before: Array = town.snapshot().life.accounts.duplicate(true)
	var source_stock_before: int = town.material_sources()[0].stock
	var iron_before_total := _iron_total(accounts_before)
	var life_before_recovery: Dictionary = town.snapshot().life.duplicate(true)
	var coins_before: Array = town.snapshot().residents.map(func(r): return {"stable_id": r.stable_id, "coins_col": r.coins_col})
	check((await _tick(town, path, 60)).ok, "advance(60) completes recovery in physics")
	check(town._trade_account(owner).iron == owner_iron_before + 1, "owner gains exactly one iron")
	check(town._trade_account(smith).iron == smith_iron_before, "smith account unchanged by owner recovery")
	check(town.material_sources()[0].stock == 2 and town.material_sources()[0].recovered == 1, "source stock 3 to 2 with one recovery")
	historic_while_blocked = int(town.resident_view(smith).material_sources[0].last_observed_stock)
	check(historic_while_blocked == 3, "smith historical observation stays 3 while blocked")
	check(town.resident_view(smith).material_sources[0].observation_event_seq == smith_event_seq_before, "smith observation event seq unchanged")
	check(town.resident_view(owner).material_sources[0].last_observed_stock == 2, "owner now knows stock 2")
	var accounts_after: Array = town.snapshot().life.accounts.duplicate(true)
	check(_account_iron(accounts_after, owner) == _account_iron(accounts_before, owner) + 1, "owner inventory gains one from source")
	check(_account_iron(accounts_after, smith) == _account_iron(accounts_before, smith), "smith account iron conserved")
	var expected_accounts: Array = accounts_before.duplicate(true)
	for account in expected_accounts:
		if account.get("resident_id", "") == owner:
			account["iron"] = int(account.get("iron", 0)) + 1
	check(accounts_after == expected_accounts, "accounts whole array matches except owner iron +1")
	check(_iron_total(accounts_after) == iron_before_total + 1, "total resident iron gains one from source")
	check(town.material_sources()[0].stock + _iron_total(accounts_after) == source_stock_before + iron_before_total, "source stock plus all accounts conserve iron")
	var life_after_recovery: Dictionary = town.snapshot().life
	check(life_after_recovery.items == life_before_recovery.items and life_after_recovery.contracts == life_before_recovery.contracts and life_after_recovery.skills == life_before_recovery.skills, "recovery preserves items, contracts and skills")
	var coins_after: Array = town.snapshot().residents.map(func(r): return {"stable_id": r.stable_id, "coins_col": r.coins_col})
	check(coins_after == coins_before, "recovery preserves residents coins")
	check(town.resident_view(carpenter).material_sources.is_empty(), "third far resident remains unknown")

	# 7. Remove the step 6 wall; smith learns the new stock with a new event.
	var smith_events_before: int = town.snapshot().life.events.filter(func(e): return e.get("type") == "material_source_observed" and e.get("actor_id") == smith).size()
	check(_wall != null and is_instance_valid(_wall), "step 6 wall still valid before removal")
	_wall.queue_free()
	_wall = null
	await _wait_physics(2)
	check(await _sight_query(smith, "fixture:iron-source"), "smith regains line of sight after second removal")
	check((await _tick(town, path, 0)).ok, "advance(0) after second removal succeeds")
	var smith_view_final: Array = town.resident_view(smith).material_sources
	if smith_view_final.is_empty():
		_finish(town, path, writer_released, {"suite": "town_material_visibility", "checks": checks, "failures": failures + 1, "paid_calls": 0, "physics_fixture": true, "wall_blocked": wall_blocked, "observed_initial": observed_initial, "observed_current": observed_current, "historic_stock_while_blocked": historic_while_blocked, "success": false})
		return
	observed_current = int(smith_view_final[0].last_observed_stock)
	check(observed_current == 2, "smith learns updated stock 2")
	var smith_events_after: int = town.snapshot().life.events.filter(func(e): return e.get("type") == "material_source_observed" and e.get("actor_id") == smith).size()
	check(smith_events_after == smith_events_before + 1, "smith gains exactly one new observation event")
	var smith_events_all: Array = town.snapshot().life.events.filter(func(e): return e.get("type") == "material_source_observed" and e.get("actor_id") == smith)
	check(not smith_events_all.is_empty(), "smith observation events exist for exact-history check")
	if not smith_events_all.is_empty():
		check(smith_events_all[0] == old_observation, "first smith observation event equals the original observation")
		check(smith_view_final[0].observation_event_seq == int(smith_events_all[smith_events_all.size() - 1].get("seq", -1)), "smith view seq matches the newest actual event seq")

	# 8. Failure and cleanup guards.
	var saved_bodies: Dictionary = _bodies.duplicate()
	_bodies.erase(smith)
	check(not await _sight_query(smith, "fixture:iron-source"), "missing observer entry yields false")
	_bodies[smith] = _smith_body
	check(await _sight_query(smith, "fixture:iron-source"), "restored observer entry yields true")
	_visuals.get_child(0).visible = false
	check(not await _sight_query(smith, "fixture:iron-source"), "hidden visual display yields false")
	_visuals.get_child(0).visible = true
	check(await _sight_query(smith, "fixture:iron-source"), "restored visual display yields true")
	check(not await _sight_query(smith, "fixture:unknown-source"), "unknown source yields false")
	root.remove_child(_sight)
	check(not await _sight_query(smith, "fixture:iron-source"), "detached Sight yields false while runner root is active")
	root.add_child(_sight)
	check(await _sight_query(smith, "fixture:iron-source"), "reattached Sight yields true again")

	var saved_bytes := FileAccess.get_file_as_bytes(path)
	town.release_writer(path)
	writer_released = true
	var cold = load_materials(path)
	check(FileAccess.get_file_as_bytes(path) == saved_bytes, "cold load preserves exact save bytes")
	check(cold.snapshot().life.accounts == town.snapshot().life.accounts and cold.snapshot().life.items == town.snapshot().life.items and cold.snapshot().life.contracts == town.snapshot().life.contracts, "cold load preserves money, inventory and contracts")
	check(cold.snapshot().life.events == town.snapshot().life.events, "cold load preserves observed life events")
	check(cold.resident_view(smith).material_sources[0].last_observed_stock == 2, "cold load preserves smith known stock 2")
	var cold_bytes := FileAccess.get_file_as_bytes(path)
	var cold_sight = Sight.new()
	root.add_child(cold_sight)
	cold_sight.configure(cold, _bodies, _visuals)
	cold.require_material_visibility(Callable(cold_sight, "can_observe"))
	check(FileAccess.get_file_as_bytes(path) == cold_bytes, "rebinding Sight to cold core does not change bytes")
	var cold_callback: Callable = Callable(cold_sight, "can_observe")
	cold_sight.free()
	check(not cold._material_source_visible(smith, "fixture:iron-source"), "freed cold Sight yields false")
	check(not cold_callback.is_valid(), "freed cold Sight callback is invalid")
	check(cold.resident_view(smith).material_sources[0].last_observed_stock == 2, "cold known stock 2 unchanged after free")
	check(FileAccess.get_file_as_bytes(path) == cold_bytes, "cold bytes unchanged after free")
	cold.release_writer(path)

	check(wall_blocked and observed_initial == 3 and observed_current == 2 and historic_while_blocked == 3, "measured wall_blocked, initial 3, current 2 and historic 3 flags hold")
	var success: bool = failures == 0 and wall_blocked and observed_initial == 3 and observed_current == 2 and historic_while_blocked == 3
	_finish(town, path, writer_released, {"suite": "town_material_visibility", "checks": checks, "failures": failures, "paid_calls": 0, "physics_fixture": true, "wall_blocked": wall_blocked, "observed_initial": observed_initial, "observed_current": observed_current, "historic_stock_while_blocked": historic_while_blocked, "success": success})

func _iron_total(accounts: Array) -> int:
	var total := 0
	for account in accounts:
		total += int(account.get("iron", 0))
	return total

func _account_iron(accounts: Array, resident_id: String) -> int:
	for account in accounts:
		if account.get("resident_id", "") == resident_id:
			return int(account.get("iron", 0))
	return 0

func _string_probe(_id: String, _source_id: String) -> String:
	return "yes"
