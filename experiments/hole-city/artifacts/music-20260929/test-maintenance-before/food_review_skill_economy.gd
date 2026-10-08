extends SceneTree
## Independent review of equipped-skill onboarding and live coin shortfalls.
## Uses real viewport touch events and an owned temporary save; no player save.
const Game=preload("res://fidelity/game.gd")
var game:Node3D
var checks:=0
var failures:Array[String]=[]
var measurements:Array[Dictionary]=[]

func _initialize()->void:run.call_deferred()

func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)

func frames(count:=2)->void:
	for i in count:await process_frame

func button(id:String)->Button:
	for b in game.ui.buttons:
		if b.name==id or b.text==id:return b
	return null

func touch(index:int,at:Vector2,pressed:bool)->void:
	var event:=InputEventScreenTouch.new()
	event.index=index;event.position=at;event.pressed=pressed
	root.push_input(event,true)
	await frames()

func tap(id:String,index:=1)->void:
	var target:=button(id)
	check(target!=null,"Touch target exists: "+id)
	if target==null:return
	var at:=target.get_global_rect().get_center()
	await touch(index,at,true);await touch(index,at,false)

func lines_for(message:String,width:float,size:int)->Array[String]:
	var lines:Array[String]=[]
	var line:=""
	for word in message.split(" "):
		var candidate:=word if line.is_empty() else line+" "+word
		if not line.is_empty() and game.ui.font.get_string_size(candidate,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>width:
			lines.append(line);line=word
		else:line=candidate
	lines.append(line)
	return lines

func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	Input.emulate_mouse_from_touch=true
	game=load("res://fidelity/main.tscn").instantiate();root.add_child(game)
	await frames(4)
	game.set_process(false);game.set_physics_process(false)
	var save_path:="/tmp/hole-independent-skill-economy-%d.cfg"%OS.get_process_id()
	game.test_progress_path=save_path
	game.start_level();await frames(4)
	game.city.set_process(false);game.city.set_physics_process(false)
	for hole in game.holes:
		hole.set_physics_process(false);hole.enabled=false
	check(game.test_mode and game.progress_file()==save_path,"Review only uses its owned test save")
	check(game.ui.mouse_filter==Control.MOUSE_FILTER_IGNORE,"Drawn onboarding does not own a blocking control surface")
	var abilities:={"copper_ring":"draw","moss_bloom":"bloom","gravitas":"thrum","lantern":"speed","shard":"sweep"}
	for id in abilities:
		var definition:Dictionary=game.skin_definition(id)
		game.player.skin_id=id;game.selected_skin_id=id
		# A separately focused collection card must never change equipped help.
		game.ui.preview_skin_id="music_stage"
		for map_id in ["city","food"]:
			game.selected_map=map_id;game.phase="intro";game.elapsed=0
			var lesson:Dictionary=game.ui.round_skill_lesson()
			check(not lesson.is_empty(),"Equipped ability has intro help: "+id+" / "+map_id)
			if lesson.is_empty():continue
			check(lesson.title==definition.skill_name and lesson.effect==definition.skill_desc,"Help describes actual equipped ability: "+id+" / "+map_id)
			var trigger:String=lesson.trigger
			check(trigger.contains("AUTO") if id=="moss_bloom" else trigger.contains("TAP "+str(definition.skill_short)),"Help identifies visible manual control or automatic trigger: "+id+" / "+map_id)
			check(trigger.contains("%.0fs"%float(definition.cooldown)),"Help uses actual repeat cooldown: "+id+" / "+map_id)
			var rect:Rect2=lesson.rect
			check(Rect2(16,16,508,928).encloses(rect),"Lesson stays in portrait margins: "+id+" / "+map_id)
			check(not rect.intersects(Rect2(20,163,500,110)) and not rect.intersects(Rect2(87,295,366,46)),"Lesson clears food goals and notices: "+id+" / "+map_id)
			check(not rect.intersects(Rect2(414,680,104,94)) and not rect.intersects(Rect2(414,797,104,112)) and not rect.intersects(Rect2(180,650,180,190)),"Lesson clears action buttons and movement tutorial: "+id+" / "+map_id)
			var effect_lines:=lines_for(str(lesson.effect),436,17)
			check(effect_lines.size()<=2 and game.ui.font.get_string_size(str(lesson.title),HORIZONTAL_ALIGNMENT_LEFT,-1,25).x<=436 and game.ui.font.get_string_size(trigger,HORIZONTAL_ALIGNMENT_LEFT,-1,17).x<=436,"Actual Fredoka text fits portrait lesson without covering the movement reminder: "+id+" / "+map_id)
			measurements.append({"skin":id,"map":map_id,"effect_lines":effect_lines.size(),"trigger":trigger,"rect":str(rect)})
		game.phase="playing";game.elapsed=5.99
		check(not game.ui.round_skill_lesson().is_empty(),"Help survives initial active play: "+id)
		game.elapsed=6.0
		check(game.ui.round_skill_lesson().is_empty(),"Help expires without lasting HUD clutter: "+id)
		game.elapsed=1;paused=true
		check(game.ui.round_skill_lesson().is_empty(),"Pause hides gameplay help: "+id)
		paused=false
		for phase in ["title","complete","timeout","eaten"]:
			game.phase=phase
			check(game.ui.round_skill_lesson().is_empty(),"Help absent outside play: "+id+" / "+phase)
	var cosmetic_count:=0
	for definition in Game.SKIN_DEFS:
		if definition.kind!="cosmetic":continue
		cosmetic_count+=1;game.player.skin_id=definition.id;game.selected_skin_id=definition.id
		game.phase="intro";game.elapsed=0
		check(game.ui.round_skill_lesson().is_empty(),"Cosmetic never advertises a gameplay skill: "+str(definition.id))
	check(cosmetic_count==39,"All 39 cosmetic forms, including 34 new forms, were exercised")
	game.selected_map="city";game.player.skin_id="lantern";game.selected_skin_id="lantern"
	game.phase="intro";game.elapsed=0;game.ui.refresh();await frames()
	# A touch inside the drawn lesson must still reach gameplay input.
	await touch(0,Vector2(260,430),true)
	check(game.phase=="playing" and game.player.touch_index==0,"Touch passes through the drawn lesson and starts the round")
	var drag:=InputEventScreenDrag.new();drag.index=0;drag.position=Vector2(315,440);drag.relative=Vector2(55,10)
	root.push_input(drag,true);await frames()
	check(game.player.joystick.length()>.1,"Dragging through the lesson controls the hole")
	game.player.skin_cooldown=0
	await tap("skin-action")
	check(game.player.speed_boost_time>0 and game.player.skin_cooldown==9,"Manual skill touch executes actual speed effect and cooldown")
	check(game.player.touch_index==0,"Skill finger does not release the existing joystick finger")
	await touch(0,Vector2(315,440),false)
	check(game.player.touch_index==-1,"Joystick finger release still clears ownership")
	game.player.skin_id="moss_bloom";game.selected_skin_id="moss_bloom";game.player.skin_cooldown=0;game.ui.refresh()
	await tap("skin-action")
	check(game.player.skin_cooldown==0 and game.ui.toast=="AUTO SKILL","Automatic skill touch does not pretend to manually trigger")
	game.scan=999;game.player.score=0;game.elapsed=0;game.remaining=240
	game._physics_process(.01)
	check(game.player.skin_cooldown==12,"Actual automatic path starts the documented repeated cooldown")
	# Reuse the real settlement and unlock paths, with explicit fixture scores.
	game.phase="title";game.selected_skin_id="core_shell";game.player.skin_id="core_shell"
	game.owned_skin_ids.assign(["core_shell"]);game.coins=49;game.stage=1
	check(game.save_player_progress(),"Owned fixture baseline saves successfully")
	var before_file:=FileAccess.get_file_as_string(save_path)
	var denied:Dictionary=game.unlock_random_skin("foundation")
	check(not denied.ok and denied.message=="Need 1 more coins" and denied.price==50 and denied.missing_coins==1,"Initial shortfall exposes exact one-coin deficit")
	check(game.coins==49 and game.owned_skin_ids.size()==1 and FileAccess.get_file_as_string(save_path)==before_file,"Rejected unlock preserves wallet, ownership and saved bytes")
	game.ui.open_holes();await frames()
	await tap("unlock-random",0)
	check(game.ui.toast.contains("1") and game.ui.toast.contains("coins"),"Real collection touch presents current shortfall")
	check(str(game.ui.COIN_EARNING_RULE).contains("round down") and str(game.ui.COIN_EARNING_RULE).contains("+20") and str(game.ui.COIN_EARNING_RULE).contains("10"),"Shared earning explanation includes flooring and completion bonus")
	check(game.ui.font.get_string_size(str(game.ui.COIN_EARNING_RULE),HORIZONTAL_ALIGNMENT_LEFT,-1,14).x<=508,"Actual footer earning rule fits portrait width")
	check(game.ui.font.get_string_size(str(game.ui.COIN_EARNING_RULE),HORIZONTAL_ALIGNMENT_LEFT,-1,16).x<=400,"Result earning rule fits inside the result card")
	game.phase="playing";game.player.score=37;game.finish("timeout")
	check(game.coins==52 and game.round_score_coins==3 and game.round_win_coins==0,"Real losing settlement floors score coins before next unlock")
	game.phase="title";game.last_unlock_msec=-1000
	var bought:Dictionary=game.unlock_random_skin("foundation")
	check(bought.ok and game.coins==2 and game.owned_skin_ids.size()==2,"Earned coins enable a real initial random unlock")
	denied=game.unlock_random_skin("foundation")
	check(not denied.ok and denied.price==70 and denied.missing_coins==68 and denied.message=="Need 68 more coins","Shortfall reflects new wallet and next price after unlock")
	game.phase="playing";game.player.score=500;game.finish("complete")
	check(game.coins==72 and game.round_score_coins==50 and game.round_win_coins==20,"Real victory contributes separated score and completion rewards")
	game.phase="title";game.last_unlock_msec=-1000
	bought=game.unlock_random_skin("foundation")
	check(bought.ok and game.coins==2 and game.owned_skin_ids.size()==3,"Second earned unlock consumes exact updated price")
	denied=game.unlock_random_skin("foundation")
	check(not denied.ok and denied.price==90 and denied.missing_coins==88,"Deficit refreshes again after victory and second unlock")
	var cold:=Game.new();cold.test_progress_path=save_path
	check(cold.load_player_progress() and cold.coins==2 and cold.stage==2 and cold.owned_skin_ids.size()==3 and cold.selected_skin_id==game.selected_skin_id,"Cold restore retains real reward/unlock results")
	cold.free()
	game.phase="title";game.coins=200;game.last_unlock_msec=-1000
	var owned_before:Array=game.owned_skin_ids.duplicate();var selected_before:String=game.selected_skin_id
	game.test_progress_path="/tmp/hole-independent-absent-%d/progress.cfg"%OS.get_process_id()
	var rollback:Dictionary=game.unlock_random_skin("foundation")
	check(not rollback.ok and game.coins==200 and game.owned_skin_ids==owned_before and game.selected_skin_id==selected_before,"Failed save rolls back both unlock payment and equipment")
	game.test_progress_path=save_path
	game.owned_skin_ids.assign(game.skin_ids("foundation"));game.coins=0
	var complete:Dictionary=game.unlock_random_skin("foundation")
	check(not complete.ok and complete.message=="COLLECTION COMPLETE" and not complete.has("missing_coins"),"Complete collection does not invent a coin deficit")
	game.free();await frames()
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(save_path+suffix):DirAccess.remove_absolute(save_path+suffix)
	var result:={"checks":checks,"failures":failures,"lessons":measurements,"cosmetic_forms":cosmetic_count,"scope":"Independent headless UI/font geometry, real touch and isolated save review; no browser pixels or device FPS"}
	print("SKILL_ECONOMY_REVIEW "+JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
