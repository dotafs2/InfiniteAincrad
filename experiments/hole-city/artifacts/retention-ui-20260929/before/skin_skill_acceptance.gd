extends SceneTree

var checks:=0
var failures:Array[String]=[]
var game:Node3D

func _initialize() -> void:
	run.call_deferred()

func check(ok:bool,message:String) -> void:
	checks+=1
	if not ok:
		failures.append(message)
		push_error(message)

func frames(count:int) -> void:
	for i in count:await physics_frame

func start_with_lesson_check() -> void:
	game.start_level();await frames(3)
	var definition:Dictionary=game.skin_definition(game.player.skin_id)
	var lesson:Dictionary=game.ui.round_skill_lesson()
	var functional:bool=not definition.kind in ["cosmetic","none"]
	if functional:
		check(not lesson.is_empty(),"Actual ability is introduced before movement: "+definition.id)
		if not lesson.is_empty():
			check(lesson.title==definition.skill_name and lesson.effect==definition.skill_desc,"Lesson describes equipped ability: "+definition.id)
			var trigger:String="AUTO" if definition.kind=="bloom" else "TAP "+definition.skill_short
			check(lesson.trigger=="%s · %.0fs cooldown"%[trigger,definition.cooldown],"Lesson identifies real trigger and cooldown: "+definition.id)
			check(Rect2(20,360,500,190).encloses(lesson.rect),"Lesson clears both map goals, notices and swipe tutorial: "+definition.id)
			for caption in [[lesson.title,25],[lesson.trigger,17]]:
				check(game.ui.font.get_string_size(caption[0],HORIZONTAL_ALIGNMENT_LEFT,-1,caption[1]).x<=436,"Lesson heading fits portrait: "+definition.id)
			var lines:=1;var line:=""
			for word in str(lesson.effect).split(" "):
				var candidate:=word if line.is_empty() else line+" "+word
				if game.ui.font.get_string_size(candidate,HORIZONTAL_ALIGNMENT_LEFT,-1,17).x>436:lines+=1;line=word
				else:line=candidate
			check(lines<=2,"Lesson effect fits above movement reminder: "+definition.id)
	else:check(lesson.is_empty(),"Cosmetic form has no fictitious ability lesson: "+definition.id)
	# Route a real finger through the drawn hint, including intro-to-play and release.
	for pressed in [true,false]:
		var event:=InputEventScreenTouch.new();event.index=7;event.position=Vector2(100,420);event.pressed=pressed
		root.push_input(event,true);await frames(2)
	check(game.phase=="playing" and game.player.touch_index==-1,"Lesson permits actual touch to start and release: "+definition.id)
	check(game.ui.round_skill_lesson().is_empty()!=functional,"Lesson persists into active play only for abilities: "+definition.id)
	var elapsed_before:float=game.elapsed
	game.elapsed=6.0
	check(game.ui.round_skill_lesson().is_empty(),"Lesson leaves gameplay after six active seconds: "+definition.id)
	game.elapsed=elapsed_before
	paused=true
	check(game.ui.round_skill_lesson().is_empty(),"Paused overlay hides lesson: "+definition.id)
	paused=false
	for button in game.ui.buttons:
		check(not Rect2(36,372,468,146).intersects(button.get_rect()),"Lesson does not cover a gameplay control: "+button.name)

func run() -> void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	game=load("res://fidelity/main.tscn").instantiate()
	root.add_child(game)
	await frames(4)
	check(game.SKIN_DEFS.size()==44,"the full catalog defines 44 skins")
	check(game.skin_ids("foundation").size()==27 and game.skin_ids("resonance").size()==17,"27 Classic and 17 Special forms retain five original functional skills")
	check(game.skin_unlocked("core_shell") and not game.skin_unlocked("copper_ring"),"new collection only owns the base form")
	await start_with_lesson_check()
	game.player.award(25)
	check(game.skin_progress>=25 and not game.skin_unlocked("copper_ring"),"best score no longer unlocks skins")
	game.owned_skin_ids.append("copper_ring") # Isolate skill behavior from purchase QA.
	check(game.select_skin("copper_ring") and game.selected_skin_id=="copper_ring","unlocked form can be equipped")
	await start_with_lesson_check()
	var candidate:Node3D
	for item in game.city.foods:
		if is_instance_valid(item) and not item.consumed and not is_instance_valid(item.claimed_by) and item.can_fit(game.player):candidate=item;break
	if is_instance_valid(candidate):candidate.global_position=game.player.global_position+Vector3(2.0,0,0)
	game.player.skin_cooldown=0.0
	check(game.player.trigger_skin_skill() and game.player.skin_cooldown>0.0,"Copper Draw activates and starts its cooldown")
	check(is_instance_valid(candidate) and candidate.pull_owner==game.player and candidate.pull_time>0.0,"Copper Draw marks a nearby object for the ordinary fall path")
	check(not game.player.trigger_skin_skill(),"a skin skill cannot be activated during cooldown")
	game.player.skin_cooldown=.15
	await frames(20)
	check(game.player.skin_cooldown<=0.0 and game.player.trigger_skin_skill(),"a functional skin can be reused after its cooldown expires")
	game.player.award(70)
	game.owned_skin_ids.append("moss_bloom") # Owned fixture for this skill.
	check(game.skin_unlocked("moss_bloom") and game.select_skin("moss_bloom"),"Owned Moss Bloom can be selected")
	await start_with_lesson_check()
	var bloom_target:RigidBody3D
	for item in game.city.foods:
		if is_instance_valid(item) and not item.consumed and not is_instance_valid(item.claimed_by) and item.can_fit(game.player):bloom_target=item;break
	if is_instance_valid(bloom_target):bloom_target.global_position=game.player.global_position+Vector3(2.0,0,0)
	game.player.skin_cooldown=.12
	await frames(15)
	check(game.player.skin_cooldown>0.0 and is_instance_valid(bloom_target) and bloom_target.pull_owner==game.player,"Moss Bloom performs an automatic nearby catch on the live timer")
	game.player.award(120)
	game.owned_skin_ids.append("gravitas") # Owned fixture for this skill.
	check(game.skin_unlocked("gravitas") and game.select_skin("gravitas"),"Owned Gravitas can be selected")
	await start_with_lesson_check()
	var building:RigidBody3D=game.city.building_visuals[0].body
	building.global_position=game.player.global_position+Vector3(4.0,0,0)
	var building_before:Vector3=building.global_position
	game.player.skin_cooldown=0.0
	check(game.player.trigger_skin_skill() and game.player.skin_cooldown>0.0,"Ground Thrum activates with a cooldown")
	check(building.global_position.distance_to(building_before)>.1,"Ground Thrum gives a nearby building a bounded physical nudge")
	game.player.award(240)
	game.owned_skin_ids.append("shard") # Owned fixture for this skill.
	check(game.skin_unlocked("shard") and game.select_skin("shard"),"Owned Shard can be selected")
	await start_with_lesson_check()
	var sweep_target:RigidBody3D
	for item in game.city.foods:
		if is_instance_valid(item) and not item.consumed and not is_instance_valid(item.claimed_by) and item.can_fit(game.player):sweep_target=item;break
	if is_instance_valid(sweep_target):sweep_target.global_position=game.player.global_position+Vector3(2.0,0,0)
	game.player.skin_cooldown=0.0
	check(game.player.trigger_skin_skill() and game.player.skin_cooldown>0.0,"Shard Sweep activates with its own cooldown")
	check(is_instance_valid(sweep_target) and sweep_target.pull_owner==game.player,"Shard Sweep marks a nearby object for the wider fall path")
	game.player.award(180)
	game.owned_skin_ids.append("lantern") # Owned fixture for this skill.
	check(game.skin_unlocked("lantern") and game.select_skin("lantern"),"Owned Lantern can be selected")
	await start_with_lesson_check()
	game.player.skin_cooldown=0.0
	check(game.player.trigger_skin_skill() and game.player.speed_boost_time>0.0,"Beacon Step activates a short movement boost")
	var lantern_start:Vector3=game.player.position
	game.player.test_direction=Vector2(1,0)
	await frames(12)
	game.player.test_direction=Vector2.ZERO
	check(game.player.position.distance_to(lantern_start)>.35,"Beacon Step produces visible movement in the live round")
	game.player.award(420)
	game.owned_skin_ids.append("prism_vale") # Owned fixture for this skill.
	check(game.skin_unlocked("prism_vale") and game.select_skin("prism_vale"),"Owned Prism Vale can be selected")
	await start_with_lesson_check()
	check(game.player.skin_id=="prism_vale" and not game.player.trigger_skin_skill(),"a fresh round equips the cosmetic form without a gameplay skill")
	game.owned_skin_ids.append("music_stage");game.select_skin("music_stage")
	await start_with_lesson_check()
	check(game.player.skin_id=="music_stage" and not game.player.trigger_skin_skill(),"Special cosmetic has no gameplay ability")
	game.selected_map="food";game.select_skin("copper_ring")
	await start_with_lesson_check()
	check(game.ui.round_skill_lesson().rect.position.y>273,"Food objective panel remains clear during ability onboarding")
	# Preview/selection cannot mislabel the equipped model during a round.
	game.ui.preview_skin_id="music_stage";game.selected_skin_id="music_stage"
	check(game.ui.round_skill_lesson().title=="COPPER DRAW","Lesson follows equipped player, not collection preview")
	var result:={"checks":checks,"failures":failures,"skins":game.SKIN_DEFS.size(),"progress":game.skin_progress}
	print("SKIN_SKILL_ACCEPTANCE "+JSON.stringify(result))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			var out:=FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE)
			out.store_string(JSON.stringify(result,"\t")+"\n")
	# Release the streamed music decoder on its audio thread before freeing the game.
	game.audio.music.stop();OS.delay_msec(120);await process_frame
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
