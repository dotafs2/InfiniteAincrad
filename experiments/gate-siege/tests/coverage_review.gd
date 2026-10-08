extends SceneTree
## Independent tests of the user-authorized deterministic coverage approximation.
## Cell fixtures specify conserved energy, not individual simulated projectiles.
const Game = preload("res://scripts/game.gd")
const Coverage = preload("res://scripts/coverage_combat.gd")
var game: Node3D
var solver: RefCounted
var checks := 0
var failures: Array[String] = []

func _initialize() -> void: call_deferred("_run")

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok: failures.append(description); print("FAIL: ",description)

func _run() -> void:
	root.size = Vector2i(540,960)
	game = Game.new(); root.add_child(game)
	if not is_instance_valid(game.squad) or game.encounters == null:
		push_error("Production initialization failed"); quit(2); return
	game.qa_mode = true; game.audio_enabled = false; game.auto_demo = false
	game.set_process(false); game.set_physics_process(false)
	solver = Coverage.new(); solver.setup(game)
	await process_frame
	_test_emission()
	_test_travel_and_conservation()
	_test_gates()
	_test_ordering_and_shields()
	_test_modes()
	_test_ticks_and_lifetime()
	await process_frame
	print("COVERAGE_REVIEW ",JSON.stringify({"checks": checks,"failures": failures,"contract":"deterministic32-cell,10-Hz traveling coverage; cosmetic bullets are not damage"}))
	game.queue_free(); await process_frame; quit(0 if failures.is_empty() else 1)

func _fresh() -> void:
	game.restart_game(); solver.reset(); game.bullets.clear(); game.boss_dead = true
	for c in game.crowd: c.alive = false
	for e in game.encounters.enemies: e.alive = false
	for gate in game.gates: gate.position.x = 30.0
	game.tier = 3

func total() -> float:
	var amount := 0.0
	for field in solver.fields:
		for value in field.energy: amount += value
	for bank in solver.pending.values():
		for value in bank.energy: amount += value
	return amount

func cell_center(index: int=9) -> float:
	return Coverage.LEFT + (index+0.5)*Coverage.CELL_WIDTH

func seed_field(mode: String, z: float, amount: float, index: int=9) -> Dictionary:
	var energy := PackedFloat64Array(); energy.resize(Coverage.CELL_COUNT); energy[index] = amount
	var contacts := PackedInt32Array(); contacts.resize(Coverage.CELL_COUNT)
	var field := {"mode": mode,"z": z,"age": 0.0,"energy": energy,"contacts": contacts,"secondary": false}
	solver.fields.append(field); return field

func troop(row: int, hp: float=100.0, x: float=-999.0) -> Dictionary:
	var target: Dictionary = game.crowd[row*16]
	target.alive = true; target.hp = hp; target.max_hp = hp
	target.x = cell_center() if x == -999.0 else x
	return target

func _test_emission() -> void:
	_fresh()
	for mode in game.Campaign.WEAPONS:
		solver.reset()
		var pellets := 5 if mode == "scatter" else 1
		solver.enqueue(Vector3(-1,1,8),mode,2,pellets)
		var one: float = total()
		check(is_equal_approx(one,game.Campaign.weapon_power(mode,2)*pellets), "%s emission preserves its authored tier-scaled fire energy" % mode)
		for member in range(35): solver.enqueue(Vector3(-1,1,9),mode,2,pellets)
		check(is_equal_approx(total(),36*one) and solver.pending.size()==1, "%s aggregates36 member contributions without discarding any damage" % mode)
		check(solver.fields.is_empty(), "%s enqueue does not immediately damage or create an advanced front" % mode)
		solver.step(0.099)
		check(solver.fields.is_empty(), "%s waits for the fixed combat tick" % mode)
		solver.step(0.001)
		check(solver.fields.size()==1 and is_equal_approx(solver.fields[0].z,9.0-solver.speed(mode)*0.1), "%s uses the rear muzzle as its conservative representative front" % mode)
		solver.reset()
		solver.enqueue(Vector3(-1,1,8),mode,0,pellets)
		var before: float = total()
		game.tier = 3; game.weapon_mode = "rail"
		check(is_equal_approx(total(),before), "Later class and weapon changes cannot rewrite queued%s energy" % mode)
	_fresh()
	for mode in game.Campaign.WEAPONS: solver.enqueue(Vector3(-1,1,8),mode,1,1)
	solver.step(0.1)
	check(solver.fields.size()==5 and solver.pending.is_empty(), "One tick flushes at most one independent coverage field per weapon")

func _test_travel_and_conservation() -> void:
	_fresh(); game.crowd_front = -12.0
	var first := troop(0,10); var rear := troop(1,10)
	seed_field("rifle",-7.0,3)
	solver.step(0.1)
	check(first.hp==10 and rear.hp==10, "Targets beyond the traveled coverage front take no early damage")
	solver.step(0.1)
	check(is_equal_approx(first.hp,7) and rear.hp==10 and is_zero_approx(total()), "A high-HP front troop consumes3 energy without leaking damage behind it")
	check(game.kills==0, "Sub-lethal coverage damage cannot award a kill")
	seed_field("rifle",-11.9,9)
	solver.step(0.1)
	check(not first.alive and is_equal_approx(rear.hp,8) and game.kills==1, "Actual remaining energy survives a kill and damages the next covered target")
	_fresh(); game.crowd_front = -12.0
	first = troop(0,100,cell_center()+Coverage.CELL_WIDTH*0.5+0.18)
	seed_field("rifle",-11.9,10); solver.step(0.1)
	check(is_equal_approx(first.hp,100) and is_equal_approx(total(),10), "A target outside the covered lateral interval takes no damage")
	_fresh(); game.crowd_front = -12.0
	first = troop(0,100,cell_center()+0.18)
	rear = troop(1,100)
	seed_field("rifle",-11.9,10); solver.step(0.1)
	check(is_equal_approx(first.hp,95) and is_equal_approx(rear.hp,95) and is_zero_approx(total()), "A half-cell target consumes exactly half the energy and preserves the other half for the next covered row")
	_fresh(); game.tier = 0
	var recruit_hp: float = game.recruit_remaining
	seed_field("rifle",-10.3,0.9,22); solver.step(0.1)
	check(is_equal_approx(game.recruit_remaining,recruit_hp-0.9) and is_zero_approx(total()), "Fractional covered statue damage preserves0.9 and consumes only its intercepted energy")

func _test_gates() -> void:
	_fresh()
	var width: float = game.GATE_WIDTH[0]
	game.gates[0].position.x = cell_center()+width*0.5
	seed_field("rifle",game.GATE_Z[0]+0.05,10)
	solver.step(0.1)
	check(is_equal_approx(total(),30), "A half-covered times-five crossing preserves5 outside energy and multiplies only the covered5")
	check(game.metrics.gate5==1, "One covered crossing records one gate event")
	solver.step(0.1)
	check(is_equal_approx(total(),30) and game.metrics.gate5==1, "Advancing beyond a crossed gate never reapplies its multiplier")
	_fresh(); game.gates[1].position.x = cell_center(); game.gold_hp = 100
	seed_field("rifle",game.GATE_Z[1]+0.05,10); solver.step(0.1)
	check(is_equal_approx(game.gold_hp,90) and is_zero_approx(total()), "Covered energy damages the gold shell and is consumed while it remains closed")
	_fresh(); game.gates[1].position.x = cell_center(); game.gold_hp = 0
	seed_field("rifle",game.GATE_Z[1]+0.05,10); solver.step(0.1)
	check(is_equal_approx(total(),9990), "The uncovered gold gate retains the full authored times999 energy multiplier")
	_fresh(); game.gates[0].position.x = 2.5
	seed_field("rifle",game.GATE_Z[0]+0.05,10); solver.step(0.1)
	check(is_equal_approx(total(),10) and game.metrics.gate5==0, "A distant uncovered gate cannot multiply fire in another lane")
	_fresh(); game.gates[0].position.x = cell_center()
	game.crowd_front = game.GATE_Z[0]+0.15
	var first := troop(0,100)
	seed_field("rifle",game.GATE_Z[0]+0.2,2); solver.step(0.1)
	check(is_equal_approx(first.hp,98) and game.metrics.gate5==0 and is_zero_approx(total()), "Nearer combat consumes energy before a rear gate within the same combat tick")
	_fresh(); game.gates[0].position.x = cell_center()
	var rail := seed_field("rail",game.GATE_Z[0]+0.05,10)
	rail.contacts[9] = 5
	solver.step(0.1)
	var retained := true
	for cell in range(Coverage.CELL_COUNT):
		if rail.energy[cell]>0: retained = retained and rail.contacts[cell]>=5
	check(retained and is_equal_approx(total(),50), "A rail multiplier fans out energy while retaining its already spent penetration allowance")

func _test_ordering_and_shields() -> void:
	_fresh(); game.wave = 1; game._start_wave(); game.boss_dead = true; solver.reset()
	for c in game.crowd: c.alive = false
	for e in game.encounters.enemies: e.alive = false
	var shield: Dictionary = game.encounters.enemies[0]
	shield.alive = true; shield.health = 100; shield.max_health = 100; shield.node.position = Vector3(cell_center(),0,-12.7)
	game.crowd_front = -12.5
	var rear := troop(0,100)
	seed_field("rifle",-11.9,10); solver.step(0.1)
	check(is_equal_approx(shield.health,95.5) and is_equal_approx(rear.hp,100) and is_zero_approx(total()), "Shield mitigation debits pre-mitigation incoming energy instead of leaking the protected fraction")
	_fresh(); game.crowd_front = -12
	game.boss_dead = false; game.boss_hp = 100; game.boss_max = 100; game.boss_z = -13.6; game.boss.position.x = cell_center()
	var front := troop(0,100)
	seed_field("rifle",-11.9,10); solver.step(0.1)
	check(is_equal_approx(front.hp,90) and game.boss_hp==100, "A front crowd row shields a rear main boss in the same swept coverage interval")

func _test_modes() -> void:
	_fresh(); game.crowd_front = -12
	for row in range(7): troop(row)
	seed_field("rail",-11.9,10); solver.step(0.1)
	var valid := true
	for row in range(6): valid = valid and is_equal_approx(game.crowd[row*16].hp,90)
	check(valid and game.crowd[96].hp==100 and is_zero_approx(total()), "Rail energy contacts exactly six ordered targets per covered cell and retires before the seventh")
	for mode in ["rocket","arc"]:
		_fresh(); game.crowd_front = -12
		for row in range(9): troop(row)
		seed_field(mode,-11.9,10); solver.step(0.1)
		check(game.crowd[0].hp==90 and game.crowd[16].hp<100, "%s preserves a distinct grouped secondary effect behind its primary impact" % mode)
		var counter: int = game.metrics.splash_hits if mode=="rocket" else game.metrics.chain_hits
		check((counter>0 and counter<=5) and game.crowd[128].hp==100, "%s secondary coverage is bounded and does not affect distant untouched targets" % mode)
		solver.step(0.3)
		check((game.metrics.splash_hits if mode=="rocket" else game.metrics.chain_hits)==counter, "%s cannot repeat its one grouped secondary discharge on later depths" % mode)
	_fresh(); solver.enqueue(Vector3(0,1,8),"rifle",0,1)
	var narrow := 0
	for value in solver.pending.rifle.energy:
		if value>0: narrow += 1
	solver.reset(); solver.enqueue(Vector3(0,1,8),"scatter",0,5)
	var wide := 0
	for value in solver.pending.scatter.energy:
		if value>0: wide += 1
	check(wide>narrow, "Scatter covers a wider lateral interval than concentrated rifle fire")

func _test_ticks_and_lifetime() -> void:
	_fresh(); solver.enqueue(Vector3(-1,1,8),"rifle",2,1)
	solver.step(0.3); var coarse: Dictionary = solver.fingerprint()
	_fresh(); solver.enqueue(Vector3(-1,1,8),"rifle",2,1)
	for i in range(18): solver.step(1.0/60.0)
	check(solver.fingerprint()==coarse, "Equal elapsed time partitions into the same fixed combat ticks and field state")
	_fresh()
	for tick in range(80):
		for mode in game.Campaign.WEAPONS: solver.enqueue(Vector3(-1,1,8),mode,0,1)
		solver.step(0.1)
	check(solver.peak_fields<=5*ceili(Coverage.MAX_AGE/Coverage.TICK), "Sustained five-weapon emission respects the explicit bounded field lifetime")
	solver.step(Coverage.MAX_AGE+0.1)
	check(solver.fields.is_empty(), "Stopping fire lets every pending coverage field expire")
	solver.enqueue(Vector3.ZERO,"rail",3,1); solver.reset()
	check(solver.fields.is_empty() and solver.pending.is_empty() and solver.resolved_ticks==0 and solver.clock==0, "Combat reset clears queued energy, active fields and the tick accumulator")
