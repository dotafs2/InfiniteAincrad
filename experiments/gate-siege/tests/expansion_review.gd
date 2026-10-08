extends SceneTree
## Independent expansion integration tests for the current coverage combat contract.
## Historical physical-packet156 suite is preserved under artifacts/expansion-runtime.
## The suite will expand as the reviewed squad/campaign/creature APIs are defined.
const Game = preload("res://scripts/game.gd")
var game: Node3D
var checks := 0
var failures: Array[String] = []
var notes: Array[String] = []
var natural_only := false
var natural_quality := "low"
var natural_output := ""
var natural_seconds := 180.0
var natural_policy := "campaign"

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg=="--natural-only": natural_only=true
		if arg.begins_with("--natural-quality="): natural_quality=arg.trim_prefix("--natural-quality=")
		if arg.begins_with("--natural-output="): natural_output=arg.trim_prefix("--natural-output=")
		if arg.begins_with("--natural-seconds="): natural_seconds=float(arg.trim_prefix("--natural-seconds="))
		if arg.begins_with("--natural-policy="): natural_policy=arg.trim_prefix("--natural-policy=")
	call_deferred("_run")

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures.append(description)
		print("FAIL: ",description)

func _run() -> void:
	root.size = Vector2i(540,960)
	game = Game.new()
	root.add_child(game)
	if not is_instance_valid(game.squad) or game.encounters == null:
		push_error("Production expansion did not initialize; aborting test run")
		game.queue_free();quit(2);return
	game.qa_mode = true
	game.auto_demo = false
	game.audio_enabled = false
	game.set_process(false)
	game.set_physics_process(false)
	await process_frame
	if natural_only:
		var result: Dictionary=await _natural_run()
		var summary: Dictionary=result.duplicate();summary.erase("fingerprints");summary.erase("trace")
		print("EXPANSION_NATURAL ",JSON.stringify(summary))
		if not natural_output.is_empty():
			var file:=FileAccess.open(natural_output,FileAccess.WRITE)
			if file: file.store_string(JSON.stringify(result,"  "))
		game.queue_free();await process_frame
		quit(0 if result.get("phase","")==("lost" if natural_policy=="idle" else "won") else 1)
		return
	_test_fractional_recruit()
	_test_squad_membership()
	_test_hero_materials()
	_test_pickups()
	_test_upgrade_contract()
	_test_weapon_contributions()
	_test_hazard_dodge_geometry()
	_test_shield_core()
	_test_warning_resources()
	_test_lethal_hazard_priority()
	_test_dragon_lifecycle()
	_test_projectile_aim()
	_test_ranged_boss_placement()
	_test_quality_contract()
	_test_cosmetic_separation()
	await _test_weapon_ui()
	await _test_routed_lifecycle()
	await process_frame
	print("EXPANSION_REVIEW ",JSON.stringify({"checks":checks,"failures":failures,"notes":notes}))
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _test_fractional_recruit() -> void:
	game.restart_game()
	var before: float = game.recruit_remaining
	for i in range(10): game._damage_recruit(0.9)
	check(is_equal_approx(float(game.recruit_remaining),before-9.0), "Ten fractional0.9-damage statue hits preserve their full9 damage")

func _test_squad_membership() -> void:
	game.restart_game()
	var squad: Node3D = game.squad
	check(squad.members.size() == 1, "A new run starts with one active soldier")
	var original_id: int = squad.members[0].id
	var maximum: int = game.Campaign.MAX_SQUAD
	var additions := 0
	while squad.members.size() < maximum:
		if squad.add_member(): additions += 1
		else: break
	squad.update_visuals()
	var ids: Dictionary = {}
	for member in squad.members: ids[member.id] = true
	check(squad.members.size() == maximum and additions == maximum-1 and ids.size() == maximum and ids.has(original_id), "Recruitment adds unique persistent soldiers while preserving the original member")
	var before_ids := ids.keys()
	check(not squad.add_member() and squad.members.size() == maximum, "The authored squad cap rejects an additional soldier without hiding a logical member")
	var represented: bool = not squad.batches.is_empty()
	for batch in squad.batches: represented = represented and batch.multimesh.visible_instance_count == maximum-1
	check(represented and game.player_model.is_visible_in_tree(), "Every active soldier is represented by the leader model or every body-part batch")
	for tier_index in range(4):
		game.tier = tier_index
		game._set_player_model()
		squad.rebuild()
		for side in [-1.0,1.0]:
			game.player_x = side*10.0
			squad.update_visuals()
			var bounded := true
			var muzzles: Array = []
			for index in range(squad.members.size()):
				var member: Dictionary = squad.members[index]
				bounded = bounded and absf(member.position.x) < 5.1
				var muzzle: Vector3 = squad.muzzle(index)
				bounded = bounded and is_equal_approx(muzzle.x,member.position.x) and muzzle.y > member.position.y and muzzle.z < member.position.z
				muzzles.append(muzzle)
			check(bounded and muzzles[0] != muzzles[-1], "Tier%d steering edge%+.0f retains independent in-road member muzzle positions" % [tier_index,side])
		var tier_ids: Array = []
		for member in squad.members: tier_ids.append(member.id)
		check(tier_ids == before_ids, "Class%d visual rebuild preserves every member identity" % tier_index)
	game.toggle_pause()
	var paused_positions: Array = []
	for member in squad.members: paused_positions.append(member.position)
	for quality in ["low","battery","high"]:
		game.set_quality(quality)
		var current_positions: Array = []
		for member in squad.members: current_positions.append(member.position)
		check(current_positions == paused_positions and squad.members.size() == maximum, "Paused%s quality selection leaves logical formation unchanged" % quality)
		check(squad.direction_batch.visible == (quality != "high"), "Paused%s selection immediately updates the whole squad's baked shadow strategy" % quality)
	game.restart_game()
	check(squad.members.size() == 1 and game.tier == 0 and squad.members[0].id == 0, "Restart resets active squad identities and class")

func _test_lethal_hazard_priority() -> void:
	game.restart_game()
	game.wave = game.Campaign.WAVES.size()-1
	game._start_wave()
	for c in game.crowd: c.alive = false
	game.boss_dead = true; game.boss_death_time = 0.0
	for e in game.encounters.enemies: e.alive = false; e.death = 1.0
	game.health = 5.0
	var target: Vector3 = game.squad.hurtbox_position()
	game.encounters.warn(target.x,target.z,1.0,10.0)
	game.encounters.hazards[0].life = 0.0
	game._physics_process(1.0/60.0)
	check(game.health == 0 and game.phase == "lost" and game.metrics.losses == 1 and game.metrics.wins == 0, "A lethal final-frame hazard loses once and cannot also clear or win the campaign")

func _fill_squad(count: int) -> void:
	while game.squad.members.size()<count:
		if not game.squad.add_member(): break
	game.squad.update_visuals()

func _test_pickups() -> void:
	game.restart_game()
	game.player_x=4.0; game.squad.update_visuals()
	for card in game.lane_cards: card.z=-40.0
	var card: Dictionary=game.lane_cards[0]
	card.z=game.PLAYER_Z+0.39;card.claimed=false
	var id: int=card.id
	game._step_recruit_lane(0.01)
	check(game.squad.members.size()==2 and card.claimed and not card.node.visible, "Contact with a visible+1 pickup adds one actual soldier and consumes the card")
	for i in range(20): game._step_recruit_lane(0.0)
	check(game.squad.members.size()==2 and card.id==id, "Remaining on the same consumed card cannot repeatedly recruit")
	card.z=game.PLAYER_Z+2.1
	game._step_recruit_lane(0)
	check(not card.claimed and card.id!=id and card.node.visible, "A recycled card receives a new pickup identity")
	game.player_x=-4.0;game.squad.update_visuals()
	card.z=game.PLAYER_Z+0.39;card.claimed=false
	game._step_recruit_lane(0.01)
	check(game.squad.members.size()==2 and card.claimed, "A missed right-lane card never grants timer-only soldiers")
	game.toggle_pause()
	var z: float=card.z
	game._physics_process(1.0)
	check(card.z==z and game.squad.members.size()==2, "Pause freezes pickup travel and squad count")
	game.restart_game()
	check(game.squad.members.size()==1 and game.lane_serial==game.lane_cards.size() and not game.lane_cards[0].claimed, "Restart clears pickup ownership and the recruited roster")
	var shown:=true
	for entry in game.lane_cards:shown=shown and entry.node.visible and entry.label.text=="+1"
	check(shown, "A sub-capacity squad retains every unclaimed recruitment card")
	_fill_squad(game.Campaign.MAX_SQUAD);game._step_recruit_lane(0)
	var retired:=true
	for entry in game.lane_cards:retired=retired and not entry.node.visible
	check(retired and game.lane_label.text=="SQUAD FULL", "At full capacity the lane retires cards and clearly reports the complete squad")
	game.restart_game();shown=true
	for entry in game.lane_cards:shown=shown and entry.node.visible and entry.label.text=="+1" and not entry.claimed
	check(shown and game.lane_label.text=="RECRUIT", "Restart after capacity restores real +1 cards and their recruitment state")

func _test_upgrade_contract() -> void:
	game.restart_game();_fill_squad(3)
	game.player_x=-3.0;game.target_x=-3.0;game.squad.update_visuals()
	var ids: Array=[]
	for member in game.squad.members: ids.append(member.id)
	var old_mesh: Mesh=game.squad.batches[0].multimesh.mesh
	game._damage_recruit(game.recruit_remaining)
	check(game.recruiting and game.pending_tier==1 and game.tier==0 and game.squad.members.size()==3, "Class unlock starts a pending transfer without early tier or count changes")
	var before_shots: int=game.metrics.shots
	for i in range(12): game._physics_process(1.0/60.0)
	check(game.metrics.shots>before_shots and game.tier==0, "Existing soldiers continue firing their active class during the upgrade flight")
	var old_coverage: Dictionary=game.combat.fingerprint()
	game.player_x=4;game.squad.update_visuals()
	for card in game.lane_cards: card.z=-40.0
	game.lane_cards[0].z=game.PLAYER_Z+0.39;game.lane_cards[0].claimed=false
	game._step_recruit_lane(0.01)
	check(game.squad.members.size()==4 and game.tier==0 and game.pending_tier==1, "A real+1 pickup during transfer joins the current class")
	var clock: float=game.flight_clock
	var flight_position: Vector3=game.recruit_flight.position
	game.toggle_pause()
	game._physics_process(0.5)
	check(game.flight_clock==clock and game.recruit_flight.position==flight_position, "Pause freezes a pending class transfer")
	game.toggle_pause();game._step_upgrade(1.0)
	check(game.tier==1 and game.pending_tier==-1 and not game.recruiting and game.squad.members.size()==4, "Landing upgrades the entire existing roster without replacing it with one unit")
	var after_ids: Array=[]
	for member in game.squad.members: after_ids.append(member.id)
	check(after_ids.slice(0,3)==ids and game.squad.batches[0].multimesh.mesh!=old_mesh, "Whole-roster class change preserves identities while replacing rendered class meshes")
	check(game.combat.fingerprint()==old_coverage, "Class landing cannot rewrite already queued or traveling coverage energy")
	game._damage_recruit(game.recruit_remaining)
	game.restart_game()
	check(game.tier==0 and game.pending_tier==-1 and not game.recruiting and game.squad.members.size()==1 and game.recruit_flight==null and game.recruit_shadow==null, "Restart cancels pending class, airborne actor and shadow")

func _test_hazard_dodge_geometry() -> void:
	game.restart_game();_fill_squad(game.Campaign.MAX_SQUAD)
	game.tier=3;game._set_player_model();game.squad.rebuild()
	game.player_x=0;game.squad.update_visuals()
	var safe_position:=false
	var best_separation:=0.0
	var limit: float=game.squad.center_limit()
	for sample in range(41):
		game.player_x=lerpf(-limit,limit,float(sample)/40.0)
		game.squad.update_visuals()
		var separation: float=absf(game.squad.hurtbox_position().x)
		best_separation=maxf(best_separation,separation)
		game.health=100
		game.encounters.warn(0,game.squad.hurtbox_position().z,1.5,14)
		game.encounters.hazards[-1].life=0.0
		game.encounters.step(0.0)
		if game.health==100: safe_position=true
	check(safe_position, "A full squad has a reachable shield-core position outside a centered dragon hazard")
	notes.append("Full-squad best shield-core center clearance: %.4fm against1.5m hazard plus0.3m core" % best_separation)

func steer_world(x: float) -> void:
	var event: InputEvent
	if not game.dragging:
		event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true
	else: event=InputEventMouseMotion.new()
	event.position=game.camera.unproject_position(Vector3(x,0,game.PLAYER_Z))
	game._unhandled_input(event)

func choose_weapon(mode: String) -> void:
	if game.weapon_mode==mode: return
	var event:=InputEventKey.new()
	event.pressed=true;event.keycode=KEY_1+game.Campaign.WEAPONS.find(mode)
	game._unhandled_input(event)

func gameplay_metrics() -> Dictionary:
	var logical: Dictionary=game.metrics.duplicate()
	logical.erase("peak_packets")
	return logical

func state_fingerprint() -> String:
	var enemies: Array=[]
	for c in game.crowd: enemies.append([c.id,c.alive,c.hp,c.x,c.z])
	var elites: Array=[]
	for e in game.encounters.enemies: elites.append([e.id,e.alive,e.health,e.node.position,e.clock,e.attack_clock,e.death])
	var hazards: Array=[]
	for h in game.encounters.hazards: hazards.append([h.x,h.z,h.life,h.damage,h.radius,h.hit])
	return JSON.stringify({"phase":game.phase,"time":game.elapsed,"wave":game.wave,"tier":game.tier,"pending":game.pending_tier,"recruit":game.recruit_remaining,"recruiting":game.recruiting,"flight":game.flight_clock,"members":game.squad.members,"weapon":game.weapon_mode,"boss":[game.boss_hp,game.boss_z,game.boss_dead,game.boss_state,game.boss_state_clock,game.boss_death_time],"health":game.health,"gold":game.gold_hp,"player":game.player_x,"target":game.target_x,"front":game.crowd_front,"crowd":enemies,"elites":elites,"hazards":hazards,"combat":game.combat.fingerprint(),"metrics":gameplay_metrics(),"rng":str(game.rng.state)}).sha256_text()

func _natural_run() -> Dictionary:
	game.restart_game();game.set_quality(natural_quality);Engine.max_fps=0
	var fingerprints: Array=[]
	var trace: Array=[]
	var seen_waves: Array=[]
	var wave_entries: Array=[]
	var minimum_health:=100.0
	var previous_health:=100.0
	var damage_events:=0
	var peak_members:=1
	var began:=Time.get_ticks_usec()
	for frame in range(ceili(natural_seconds*60)):
		if game.phase!="playing": break
		if game.wave not in seen_waves:
			seen_waves.append(game.wave)
			var entry: Dictionary={"wave":game.wave+1,"elapsed":game.elapsed,"members":game.squad.members.size(),"health":game.health,"tier":game.tier}
			wave_entries.append(entry)
			print("NATURAL_WAVE ",JSON.stringify(entry))
		var target: float
		if game.squad.members.size()<36 and game.elapsed<38: target=4.55
		elif game.tier<3 and game.elapsed<50: target=2.8
		else: target=-2.4+2.0*sin(game.wave_clock*0.6)
		if natural_policy=="sweep" and game.boss_dead:
			var remaining_x:=0.0;var visible_count:=0
			for c in game.crowd:
				if c.alive and game.camera.is_position_in_frustum(Vector3(c.x,0.55,game.crowd_front-c.z)):
					remaining_x+=c.x;visible_count+=1
			if visible_count==0:
				for elite in game.encounters.enemies:
					if elite.alive and game.camera.is_position_in_frustum(elite.node.position):
						remaining_x+=elite.node.position.x;visible_count+=1
			if visible_count>0:target=remaining_x/visible_count
		if natural_policy in ["variety","sweep"]:
			var unlocked:=mini(5,game.wave+1)
			var offset:=unlocked-1 if natural_policy=="sweep" else 0
			choose_weapon(game.Campaign.WEAPONS[(offset+int(game.wave_clock/4.0))%unlocked])
		elif natural_policy not in ["idle","rifle"]:
			if game.wave>=4: choose_weapon("rail" if not game.boss_dead else "arc")
			elif game.wave>=3: choose_weapon("rail" if not game.boss_dead else "rocket")
			elif game.wave>=2: choose_weapon("rail")
			elif game.wave>=1: choose_weapon("scatter")
		# Test policy may read visible hazard positions, but only supplies controls.
		var urgent:=false
		for h in game.encounters.hazards:
			if h.life<0.65: urgent=true
		if urgent and natural_policy!="no-dodge":
			var best_score: float=-INF
			var limit: float=game.squad.center_limit()
			for sample in range(11):
				var candidate:=lerpf(-limit,limit,float(sample)/10)
				var clearance:=5.0
				for h in game.encounters.hazards:
					if h.life>0.65: continue
					var core: Vector3=game.squad.hurtbox_position()
					clearance=minf(clearance,Vector2(candidate-h.x,core.z-h.z).length()-h.radius-game.squad.hurtbox_radius)
				var score: float=clearance-absf(candidate-clampf(target,-limit,limit))*0.01
				if score>best_score: best_score=score;target=candidate
		if natural_policy!="idle": steer_world(target)
		game._physics_process(1.0/60.0)
		minimum_health=minf(minimum_health,game.health)
		if game.health<previous_health: damage_events+=1
		previous_health=game.health
		peak_members=maxi(peak_members,game.squad.members.size())
		if frame%60==0:
			fingerprints.append(state_fingerprint())
			trace.append({"time":game.elapsed,"wave":game.wave+1,"boss_hp":game.boss_hp,"boss_state":game.boss_state,"health":game.health,"crowd":game._alive_crowd(),"elites":game.encounters.alive_count(),"coverage_fields":game.combat.fields.size(),"x":game.player_x,"gold":game.gold_hp,"members":game.squad.members.size(),"tier":game.tier})
			await process_frame
	fingerprints.append(state_fingerprint())
	return {"quality":natural_quality,"policy":natural_policy,"trace":trace,"wave_entries":wave_entries,"minimum_health":minimum_health,"damage_events":damage_events,"phase":game.phase,"elapsed":game.elapsed,"wave":game.wave+1,"seen_waves":seen_waves,"tier":game.tier,"members":game.squad.members.size(),"peak_members":peak_members,"health":game.health,"kills":game.kills,"metrics":game.metrics,"fingerprints":fingerprints,"wall_seconds":float(Time.get_ticks_usec()-began)/1000000}

func _test_shield_core() -> void:
	game.restart_game();_fill_squad(game.Campaign.MAX_SQUAD)
	game.tier=3;game._set_player_model();game.squad.rebuild()
	game.player_x=0;game.squad.update_visuals()
	var center: Vector3=game.squad.hurtbox_position()
	var ring: MeshInstance3D=game.squad.shield_core
	check(ring.is_visible_in_tree() and is_equal_approx(ring.global_position.x,center.x) and is_equal_approx(ring.global_position.z,center.z) and ring.global_position.y>0 and ring.global_position.y<0.1, "Visible shield ring identifies the actual ground-anchored squad hurtbox")
	game.encounters.warn(center.x,center.z,1.5,14)
	game.encounters.step(0.5)
	check(game.health==100 and game.encounters.hazards.size()==1, "A visible hazard telegraphs before applying damage")
	var life: float=game.encounters.hazards[0].life
	game.toggle_pause();game._physics_process(1.0)
	check(game.encounters.hazards[0].life==life and game.health==100, "Pause freezes hazard warning time and damage")
	game.toggle_pause();game.player_x=game.squad.center_limit();game.squad.update_visuals()
	game.encounters.step(1.0)
	check(game.health==100 and game.encounters.hazards.is_empty(), "Steering the visible core outside the warning prevents damage at full roster")
	center=game.squad.hurtbox_position()
	game.encounters.warn(center.x,center.z,0.5,10)
	game.encounters.hazards[0].life=0
	game.encounters.step(0)
	game.encounters.step(0)
	check(game.health==90 and game.encounters.hazards.is_empty(), "A landed warning deals its authored damage once to the shield core")


func _test_dragon_lifecycle() -> void:
	game.restart_game();game.wave=3;game._start_wave()
	var left: Node3D=game.CreatureMotion.find(game.boss_model,"WingL")
	var right: Node3D=game.CreatureMotion.find(game.boss_model,"WingR")
	check(game.boss_kind=="dragon" and is_instance_valid(left) and is_instance_valid(right), "A dragon wave instantiates two articulated wing nodes on the combat boss")
	if not is_instance_valid(left) or not is_instance_valid(right): return
	game._physics_process(1.0/60.0)
	var first: Transform3D=left.transform
	for i in range(15): game._physics_process(1.0/60.0)
	check(not first.is_equal_approx(left.transform) and is_equal_approx(left.rotation.z,-right.rotation.z), "Living dragon wings flap oppositely through real gameplay stepping")
	game.toggle_pause();var paused: Transform3D=left.transform
	game._physics_process(1.0)
	check(left.transform.is_equal_approx(paused), "Pause freezes actual articulated dragon wings")
	game.toggle_pause()
	var health: float=game.boss_hp
	game._damage_boss(10)
	check(game.boss_hp==health-10 and not game.boss_dead, "The articulated dragon is the damageable campaign boss")
	game._damage_boss(game.boss_hp)
	check(game.boss_dead and game.boss_death_time>0 and game.boss.visible, "Defeated dragon retains a timed visible death interval")
	for i in range(18): game._step_enemies(1.0/60.0)
	check(absf(game.boss_model.rotation.z)>0 and game.boss.visible, "Dragon death changes its articulated body pose before hiding")
	game.toggle_pause();var death_time: float=game.boss_death_time;paused=left.transform
	game._physics_process(1.0)
	check(game.boss_death_time==death_time and left.transform.is_equal_approx(paused), "Pause also freezes dragon death motion and lifetime")
	game.toggle_pause();game._step_enemies(1.8)
	check(not game.boss.visible, "The dead dragon retires after its death interval")
	game.restart_game();game.wave=5;game._start_wave()
	var drakes: Array=[]
	for e in game.encounters.enemies:
		if e.kind=="drake": drakes.append(e)
	check(drakes.size()==2, "Twin Talons config spawns two actual drake combatants")
	if drakes.size()!=2: return
	var wing: Node3D=game.CreatureMotion.find(drakes[0].art,"WingL")
	check(is_instance_valid(wing), "A drake elite has a real articulated wing")
	if not is_instance_valid(wing): return
	game.encounters.step(0.05);first=wing.transform;game.encounters.step(0.15)
	check(not wing.transform.is_equal_approx(first), "Elite wings animate through their own encounter clock")
	game.toggle_pause();paused=wing.transform;game._physics_process(0.5)
	check(wing.transform.is_equal_approx(paused), "Pause freezes elite flight motion")
	game.toggle_pause()
	for e in game.encounters.enemies: game.encounters.damage(e,e.health,"rail")
	check(not game.encounters.settled(), "Dead elites keep wave completion pending until their death animation settles")
	game.encounters.step(0.8)
	var all_hidden:=true
	for e in game.encounters.enemies: all_hidden=all_hidden and not e.node.visible
	check(game.encounters.settled() and all_hidden, "Elite death settles and hides every retired combatant")
	game.restart_game()
	check(game.encounters.enemies.is_empty() and game.encounters.hazards.is_empty(), "Restart removes all dragon-wave encounter and hazard state")

func _test_projectile_aim() -> void:
	game.restart_game();game.wave=5;game._start_wave()
	for c in game.crowd: c.alive=false
	game.boss_dead=true
	for e in game.encounters.enemies: e.alive=false
	var drake: Dictionary=game.encounters.enemies[0]
	drake.alive=true;drake.node.position=Vector3(-2.0,0,-2.0)
	game.player_x=-2.0;game.squad.update_visuals()
	var origin:Vector3=game.squad.muzzle(0)
	var aim:Vector3=game.projectile_aim(origin)
	var contact_z:float=drake.node.position.z+0.7
	check(is_equal_approx(aim.z,contact_z) and is_equal_approx(aim.x,drake.node.position.x) and aim.y>1.5, "A near drake selects its own elevated cosmetic aim endpoint and actual collision depth")
	var c:Dictionary=game.crowd[8]
	c.alive=true;c.hp=100;c.x=-2.0;c.z=0;game.crowd_front=0.0
	aim=game.projectile_aim(origin)
	check(is_equal_approx(aim.z,0.0) and aim.y<1, "A nearer ground troop overrides the rear flying target's cosmetic aim")

func _click_button(button: Button) -> void:
	var press:=InputEventMouseButton.new()
	press.button_index=MOUSE_BUTTON_LEFT;press.pressed=true
	press.position=button.get_global_rect().get_center();press.global_position=press.position
	root.push_input(press,true)
	var release: InputEventMouseButton=press.duplicate();release.pressed=false
	root.push_input(release,true)
	await process_frame

func _test_weapon_ui() -> void:
	game.restart_game();game.wave=4;game._start_wave()
	game._process(0.05);await process_frame;await process_frame
	var before: float=game.target_x
	var within:=true
	for button in game.hud.weapon_buttons:
		var rect: Rect2=button.get_global_rect()
		within=within and Rect2(0,0,540,960).encloses(rect)
		# Headless drivers do not run CanvasItem._draw; set presentation only.
		button.visible=true;button.disabled=false
	check(within, "All five real weapon controls fit the portrait viewport")
	for i in range(game.hud.weapon_buttons.size()):
		await _click_button(game.hud.weapon_buttons[i])
		check(game.weapon_mode==game.Campaign.WEAPONS[i], "Routed viewport click selects the actual%s weapon button" % game.Campaign.WEAPONS[i])
		check(game.target_x==before and not game.dragging, "Weapon%s button consumes its click without steering" % game.Campaign.WEAPONS[i])
	game.restart_game()
	game.hud.weapon_buttons[4].disabled=true
	await _click_button(game.hud.weapon_buttons[4])
	check(game.weapon_mode=="rifle" and not game.dragging, "A disabled future weapon cannot unlock or leak pointer input")


func _test_quality_contract() -> void:
	game.restart_game();_fill_squad(game.Campaign.MAX_SQUAD)
	game.wave=5;game.tier=3;game._set_player_model();game.squad.rebuild();game._start_wave()
	game.player_x=-1.0;game.target_x=-1.0;game.squad.update_visuals();game.select_weapon("scatter")
	game.combat.reset()
	for i in range(game.squad.members.size()): game.fire_member(i)
	game.combat.step(0.1)
	var original: String=state_fingerprint()
	var count: int=game.combat.fields.size()
	root.size=Vector2i(1080,1920)
	for mode in ["high","low","battery","auto"]:
		game.set_quality(mode);game._process(0.0)
		check(state_fingerprint()==original and game.squad.members.size()==36 and game.combat.fields.size()==count, "Quality%s preserves every soldier and the complete queued/traveling combat state" % mode)
		var viewport_size: Vector2=game.get_viewport().get_visible_rect().size
		var physical: Vector2=viewport_size*game.get_viewport().get_stretch_transform().get_scale()
		var axis: float=maxf(physical.x,physical.y)*game.get_viewport().scaling_3d_scale
		var budget: float=1600 if mode=="high" else 1280
		check(axis<=budget+0.1 and axis>=budget-0.1, "Quality%s obeys its actual3D pixel budget at1080x1920" % mode)
		check(game.sun.shadow_enabled==(mode=="high") and game.get_viewport().msaa_3d==Viewport.MSAA_2X, "Quality%s retains the reviewed shadow strategy and antialiasing" % mode)
	root.size=Vector2i(540,960);game._update_resolution()


func _test_ranged_boss_placement() -> void:
	game.restart_game();game.wave=3;game._start_wave()
	for c in game.crowd:c.alive=false
	for i in range(1500):
		game.elapsed+=1.0/60.0;game.sim_time+=1.0/60.0
		game._step_enemies(1.0/60.0)
	check(game.boss_z+1.1<game.GATE_Z[2] and game.boss_z> -18.8, "Later bosses approach but retain their hit plane behind every multiplier gate")
	check(game.encounters.hazards.size()>=2 and game.boss_hp==game.boss_max, "A surviving ranged boss continues generating real telegraphed attacks while held behind the gates")
	var held_z:float=game.boss_z
	for i in range(120):game._step_enemies(1.0/60.0)
	check(is_equal_approx(game.boss_z,held_z), "Extended survival cannot silently carry the ranged boss ahead of the multiplication window")


func _test_warning_resources() -> void:
	game.restart_game()
	var core:Vector3=game.squad.hurtbox_position()
	game.encounters.warn(core.x,core.z,1.5,10)
	game.encounters.warn(core.x+3,core.z,0.8,10)
	var first:MeshInstance3D=game.encounters.hazards[0].node
	var second:MeshInstance3D=game.encounters.hazards[1].node
	check(first.mesh==second.mesh and first.material_override==second.material_override, "Every warning reuses the same warmed mesh and shader material")
	check(first.mesh is PlaneMesh and is_equal_approx(first.mesh.size.x*first.scale.x,3.0) and is_equal_approx(second.mesh.size.x*second.scale.x,1.6), "Both shared warning quads preserve their independently authored damage diameters")
	game._physics_process(1.0/60.0)
	var material:ShaderMaterial=first.material_override
	var clock:float=material.get_shader_parameter("clock")
	game.toggle_pause();game._physics_process(1.0);game._process(1.0)
	check(is_equal_approx(material.get_shader_parameter("clock"),clock), "Pause freezes the actual warning shader pulse, not only its damage countdown")
	game.restart_game();game.encounters.warn(core.x,core.z,1.0,10)
	check(game.encounters.hazards[0].node.material_override==material, "Restart retains the warmed warning resource rather than constructing a fresh rendering pipeline")
	for i in range(20):game.encounters.warn(i,core.z,1,10)
	check(game.encounters.hazards.size()==6, "Warning count remains bounded when many actors attack at once")
	game.restart_game()
	check(game.encounters.hazards.is_empty(), "Restart removes every active damage warning")


func _test_routed_lifecycle() -> void:
	game.restart_game();_fill_squad(4)
	for i in range(30):game._physics_process(1.0/60.0)
	game.hud.pause_button.visible=true
	await _click_button(game.hud.pause_button)
	check(game.phase=="paused" and not game.dragging, "The actual HUD pause button pauses the expanded combat without starting a drag")
	var frozen:String=state_fingerprint()
	for i in range(60):game._physics_process(1.0/60.0)
	check(state_fingerprint()==frozen, "A paused expanded encounter preserves its entire gameplay fingerprint")
	await _click_button(game.hud.pause_button)
	game._physics_process(1.0/60.0)
	check(game.phase=="playing" and game.elapsed>0.5, "The routed pause control resumes actual combat progression")
	var touch:=InputEventScreenTouch.new();touch.index=4;touch.pressed=true;touch.position=Vector2(350,650)
	game._unhandled_input(touch)
	check(game.dragging and game.touch_id==4, "A real touch acquires steering ownership")
	var key:=InputEventKey.new();key.keycode=KEY_R;key.pressed=true;game._unhandled_input(key)
	check(game.phase=="playing" and game.squad.members.size()==1 and game.combat.fields.is_empty() and game.combat.pending.is_empty() and game.touch_id==-1 and not game.dragging, "Keyboard restart clears touch ownership, queued coverage and the expanded roster")
	game.qa_mode=false;game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT);game.qa_mode=true
	check(game.phase=="paused", "Losing application focus pauses an ordinary live run")


func _test_hero_materials() -> void:
	game.restart_game();_fill_squad(36)
	for class_index in range(3):
		game.tier=class_index;game._set_player_model();game.squad.rebuild()
		var proto:Node3D=game.model(["infantry","gunner","mech"][class_index])
		var meshes:Array=[];game._collect_meshes(proto,Transform3D.IDENTITY,meshes)
		var surfaces:=0;var roughness:Array[float]=[]
		for part in meshes:
			for surface in range(part.mesh.get_surface_count()):
				surfaces+=1
				var material:Material=part.mesh.surface_get_material(surface)
				if material is BaseMaterial3D:roughness.append(material.roughness)
		var represented:bool=surfaces>=2 and game.squad.batches.size()==meshes.size()
		for i in range(meshes.size()):
			represented=represented and game.squad.batches[i].multimesh.mesh==meshes[i].mesh and game.squad.batches[i].multimesh.visible_instance_count==35
		check(represented, "Class%d retains every costume/hardware surface across all36 represented soldiers" % class_index)
		roughness.sort()
		check(roughness.size()>=2 and roughness[-1]-roughness[0]>0.15, "Class%d cloth and hardware keep distinct imported roughness responses" % class_index)
		proto.free()


func _test_weapon_contributions() -> void:
	game.restart_game()
	check(not game.select_weapon("rocket") and not game.select_weapon("invalid") and game.weapon_mode=="rifle", "Locked and unknown weapons cannot change the active mode")
	game.wave=4;game._start_wave();_fill_squad(3)
	for mode in game.Campaign.WEAPONS:
		check(game.select_weapon(mode), "Unlocked%s can be selected" % mode)
		game.combat.reset()
		for i in range(3): game.fire_member(i)
		var energy:=0.0
		for value in game.combat.pending[mode].energy: energy+=value
		var pellets:=5 if mode=="scatter" else 1
		check(is_equal_approx(energy,3*pellets*game.Campaign.weapon_power(mode,game.tier)), "Every%s soldier contributes its complete authored energy to actual combat" % mode)
		check(game.bullets.is_empty(), "Actual%s fire creates no moving per-projectile gameplay objects" % mode)
		var queued:Dictionary=game.combat.fingerprint()
		game.select_weapon("rifle" if mode!="rifle" else "scatter")
		check(game.combat.fingerprint()==queued, "Changing mode cannot rewrite queued%s combat energy" % mode)
	game.combat.enqueue(Vector3.ZERO,"rail",3,1)
	game._clear_wave()
	check(game.combat.pending.is_empty() and game.combat.fields.is_empty(), "Wave transition retires every prior-wave queued and traveling salvo")

func _test_cosmetic_separation() -> void:
	game.restart_game();game.spray.set_budget(0)
	game.fire_member(0)
	var energy:=0.0
	for value in game.combat.pending.rifle.energy:energy+=value
	check(is_equal_approx(energy,game.Campaign.weapon_power("rifle",0)) and game.spray.batch.multimesh.visible_instance_count==0, "Disabling every cosmetic trail still preserves the soldier's full actual damage contribution")
	game.spray.set_budget(8)
	var storage:MultiMesh=game.spray.batch.multimesh
	for i in range(50):game.fire_member(0)
	check(game.spray.batch.multimesh==storage and storage.visible_instance_count==8 and storage.instance_count==game.spray.MAX_TRAILS, "Heavy cosmetic emission reuses a bounded ring buffer without allocating projectile nodes or growing storage")
	var before:PackedFloat32Array=storage.buffer.duplicate()
	game.spray.update(game.sim_time+1.0)
	var real_renderer:=DisplayServer.get_name()!="headless"
	var analytic:bool=is_equal_approx(game.spray.material.get_shader_parameter("clock"),game.sim_time+1.0)
	check(analytic and (not real_renderer or storage.buffer==before), "Analytic visual time reaches the shader clock; a real renderer also preserves fixed trail transforms")
	game.spray.update(game.sim_time)
	game.toggle_pause()
	var clock:float=game.spray.material.get_shader_parameter("clock")
	var logical:Dictionary=game.combat.fingerprint()
	for i in range(10):game._physics_process(0.1);game._process(0.1)
	check(game.spray.material.get_shader_parameter("clock")==clock and (not real_renderer or storage.buffer==before) and game.combat.fingerprint()==logical, "Pause freezes analytic trail time and coverage damage together")
	game.restart_game()
	check(game.spray.batch.multimesh.visible_instance_count==0 and game.combat.pending.is_empty(), "Restart retires both all old cosmetic slots and queued combat energy")
