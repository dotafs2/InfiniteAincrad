extends "res://tests/town_capabilities_acceptance.gd"
const SELF := "ability:self_repair:fictional:axe-edge:handle"

func _repair_stage(label: String) -> Dictionary:
	var stage := _new_stage(label)
	stage.world._state.life.skills.append({"resident_id": A, "skill_id": "wood_repair"})
	check(stage.world.save_to(stage.path).ok, "explicit fixture skill saved")
	return stage

func _offered(world, id: String, option: String) -> bool:
	for row in world.action_options(id):
		if row.id == option: return true
	return false

func run() -> void:
	var stage := _new_stage("self-no-skill")
	check(not _offered(stage.world, A, SELF), "job title alone cannot grant repair skill")
	_close_stage(stage)
	stage = _repair_stage("self-success")
	var world = stage.world
	var initial: Dictionary = world.snapshot()
	check(_offered(world, A, SELF) and world.snapshot() == initial, "personal own-item option is pure")
	check(not _offered(world, B, SELF), "another resident cannot repair this item as own property")
	check(not _offered(world, A, "ability:self_repair:fictional:axe-edge:edge"), "wood skill never grants metal repair")
	check(not world.perform_action(stage.path, A, SELF, "self:speech", "opengameagent_fixture", "I repair it instantly.").ok and world.snapshot() == initial, "physical work does not deliver fabricated speech")
	_do(stage, A, SELF, "self:one")
	check(world.pending_job(A).action == "self_repair", "native job reaches common physical interface")
	check(world._item("fictional:axe-edge").handle == 20 and world._trade_account(A).wood == 2, "acceptance consumes and repairs nothing")
	check(not _offered(world, A, "life:harvest_ration") and not _offered(world, A, "ability:talk:" + B), "native work excludes conflicting life and social turns")
	var accepted: Dictionary = world.snapshot()
	var pending_corrupt := accepted.duplicate(true)
	pending_corrupt.godot.capabilities.commands["self:one"].result.job.elapsed = 1
	check(not world._validate_state(pending_corrupt).ok, "fabricated labor before time advances is rejected")
	pending_corrupt = accepted.duplicate(true)
	pending_corrupt.godot.capabilities.commands["self:one"].result.job.target_position = [12, 0, 12]
	check(not world._validate_state(pending_corrupt).ok, "saved job cannot change its work point")
	check(world.perform_action(stage.path, A, SELF, "self:one", "opengameagent_fixture").duplicate and world.snapshot() == accepted, "identical pending replay is read-only")
	check(not world.perform_action(stage.path, B, SELF, "self:one", "opengameagent_fixture").ok and world.snapshot() == accepted, "cross-actor command reuse is rejected")
	check(world.advance(0).ok and world.capability_store() == accepted.godot.capabilities, "zero-time tick cannot advance native work")
	var observed: Dictionary = world.snapshot() # Existing proximity observations may run on advance(0).
	check(not world.advance(-1).ok and world.snapshot() == observed, "invalid delta cannot advance native work")
	world.advance(20)
	check(world.pending_job(A).elapsed == 0, "travel time is not repair labor")
	world.host_move(A, world.destination(A, "self_repair")) # Isolated rule fixture; physical proof is separate.
	world.advance(15)
	check(world.pending_job(A).elapsed == 15 and world._item("fictional:axe-edge").handle == 20, "partial labor does not repair early")
	check(world.save_to(stage.path).ok, "save midway through work")
	var halfway: Dictionary = world.snapshot()
	world.release_writer(stage.path)
	world = Actions.new()
	check(world.load_from(stage.path).ok and _same_value(halfway, world.snapshot()), "every mid-job field survives cold restore")
	stage.world = world
	world.advance(44.9)
	check(world.action_receipt("self:one").status == "pending", "full 60 seconds of on-site work are required")
	world.advance(.1)
	check(world.pending_job(A).is_empty() and world.action_receipt("self:one").status == "completed", "completion releases body with durable receipt")
	check(world._item("fictional:axe-edge").handle == 100 and world._item("fictional:axe-edge").edge == 20, "repair changes only the selected part")
	check(world._trade_account(A).wood == 1 and world._trade_account(A).iron == 0, "one real wood consumed, no iron minted")
	check(world.snapshot().life.contracts == initial.life.contracts and world.resident(A).coins_col == initial.residents[0].coins_col, "self-repair creates no contract or payment")
	check(world._item("fictional:axe-edge").owner_id == A and world._item("fictional:axe-edge").custodian_id == A, "ownership and custody remain unchanged")
	var final: Dictionary = world.snapshot()
	check(world.perform_action(stage.path, A, SELF, "self:one", "opengameagent_fixture").duplicate and world.snapshot() == final, "completed replay neither consumes twice nor requires damaged item")
	check(not _offered(world, A, SELF), "intact part no longer offered")
	check(world.save_to(stage.path).ok, "completed save validates")
	var clone := Actions.new()
	check(clone.load_from(stage.path).ok and _same_value(clone.snapshot(), final), "completed receipt cold-restores exactly")
	var corrupt := final.duplicate(true)
	corrupt.godot.capabilities.commands["self:one"].result.job.elapsed = 0
	check(not world._validate_state(corrupt).ok, "completion without work is rejected")
	corrupt = final.duplicate(true)
	corrupt.life.events[-1].consumed = 0
	check(not world._validate_state(corrupt).ok, "free repair claim rejected")
	corrupt = final.duplicate(true)
	corrupt.godot.capabilities.commands.erase("self:one")
	check(not world._validate_state(corrupt).ok, "orphan start and completion rejected")
	corrupt = final.duplicate(true)
	corrupt.godot.erase("capabilities")
	check(not world._validate_state(corrupt).ok, "removing all new module history rejected")
	corrupt = final.duplicate(true)
	corrupt.godot.capabilities.commands["self:one"].result.job.part = "edge"
	check(not world._validate_state(corrupt).ok, "part substitution rejected")
	corrupt = final.duplicate(true)
	corrupt.godot.capabilities.commands["self:one"].result.speech_delivery.delivered = true
	check(not world._validate_state(corrupt).ok, "physical work cannot become a forged speech receipt")
	_close_stage(stage)
	stage = _repair_stage("self-atomic-rollback")
	world = stage.world
	var before_batch: Dictionary = world.snapshot()
	var batch: Dictionary = world.execute_atomic_actions([_step(A, SELF, "self:batch"), _step(A, "life:harvest_ration", "self:conflict")])
	check(not batch.ok and world.snapshot() == before_batch, "later body conflict rolls back entire native job and admission event")
	_close_stage(stage)

	for condition in ["material", "custody", "contract", "opaque", "commitment"]:
		stage = _repair_stage("self-stale-" + condition)
		world = stage.world
		check(_offered(world, A, SELF), "option existed before " + condition + " change")
		match condition:
			"material": world._trade_account(A).wood = 0
			"custody": world._item("fictional:axe-edge").custodian_id = B
			"contract": world._state.life.contracts.append({"id": "fixture:held", "item_id": "fictional:axe-edge", "status": "proposed"})
			"opaque": world._item("fictional:axe-edge").kind = "unmodeled"
			"commitment":
				world._trade_account(A).wood = 1
				world._state.life.contracts.append({"worker_id": A, "part": "handle", "status": "accepted", "item_id": "different:axe"})
		var stale: Dictionary = world.snapshot()
		check(not _offered(world, A, SELF) and not world.execute_action(A, SELF, "self:stale", "opengameagent_fixture").ok and world.snapshot() == stale, "stale " + condition + " refuses without partial changes")
		_close_stage(stage)

	stage = _repair_stage("self-completion-recheck")
	world = stage.world
	_do(stage, A, SELF, "self:resource-changed")
	world._trade_account(A).wood = 0 # External fixture change; never touches a canonical world.
	world.host_move(A, world.destination(A, "self_repair"))
	world.advance(60)
	check(world.action_receipt("self:resource-changed").status == "rejected" and world.pending_job(A).is_empty(), "lost prerequisite releases body with honest failure")
	check(world._item("fictional:axe-edge").handle == 20 and world._trade_account(A).wood == 0, "failed completion cannot repair or make material negative")
	check(world.save_to(stage.path).ok, "failed completion is restorable")
	_close_stage(stage)

	stage = _repair_stage("self-stalled")
	world = stage.world
	_do(stage, A, SELF, "self:blocked")
	world.advance(89)
	check(world.action_receipt("self:blocked").status == "pending", "short wait does not invent arrival")
	world.advance(1)
	check(world.action_receipt("self:blocked").result.code == "self_repair_blocked", "90 seconds without progress closes an unreachable journey")
	check(world.pending_job(A).is_empty() and world._trade_account(A).wood == 2 and world._item("fictional:axe-edge").handle == 20, "blocked trip releases body without work or consumption")
	check(world.save_to(stage.path).ok, "blocked receipt validates")
	_close_stage(stage)
	print(JSON.stringify({"suite": "town_self_repair", "checks": checks, "failures": failures, "paid_calls": 0}))
	quit(0 if failures == 0 else 1)
