extends SceneTree
var checks:=0
var failures:Array[String]=[]
var game:Node3D
func _initialize() -> void:run.call_deferred()
func check(ok:bool,message:String) -> void:
	checks+=1
	if not ok:failures.append(message);push_error(message)
func frames(n:int) -> void:
	for i in n:await physics_frame
func touch(index:int,pressed:bool,at:Vector2) -> void:
	var e:=InputEventScreenTouch.new();e.index=index;e.pressed=pressed;e.position=at;Input.parse_input_event(e)
func target(id:String)->Button:
	for button in game.ui.buttons:
		if button.name==id or button.text==id:return button
	return null
func run() -> void:
	game=load("res://fidelity/main.tscn").instantiate();root.add_child(game)
	await frames(5)
	check(ProjectSettings.get_setting("display/window/size/viewport_width")==540 and ProjectSettings.get_setting("display/window/size/viewport_height")==960,"portrait 9:16 native viewport")
	check(ProjectSettings.get_setting("display/window/handheld/orientation")==1,"handheld orientation is portrait")
	check(game.ui.buttons[0].size.y>=60 and Rect2(0,0,540,960).encloses(game.ui.buttons[0].get_rect()),"PLAY is a large reachable portrait target")
	game.start_level();await frames(8)
	check(game.city.catalog.size()==208,"208 catalog models load in Godot")
	check(game.city.used_assets.size()==208,"every distinct model appears in the playable city")
	var geometries:={}
	for entry in game.city.catalog:geometries[entry.geometry_sha256]=true
	check(geometries.size()==208,"no geometry-identical recolors count toward 208")
	var animated:=0
	var specials:={}
	for c in game.city.citizens:
		if c.anim and c.anim.has_animation("Idle") and c.anim.has_animation("Walk") and c.anim.has_animation("Run") and c.anim.has_animation(c.special):animated+=1
		specials[c.special]=true
	check(animated==64,"all 64 citizens have imported idle, walk, run and role clips")
	check(specials.size()==16,"sixteen distinct visible roles expose sixteen distinct action clips")
	var occupied_cells:={}
	var rest_cycles:={}
	for c in game.city.citizens:
		var p:Vector3=c.body.position
		occupied_cells["%d:%d"%[int(round(p.x*.5)),int(round(p.z*.5))]]=true
		rest_cycles["%.1f"%float(c.get("rest_cycle",12.0))]=true
	check(occupied_cells.size()>=40,"pedestrians begin in varied sidewalk cells instead of a repeated line")
	check(rest_cycles.size()>=4,"pedestrians use independent rest cycles")
	check(game.city.citizens.any(func(c:Dictionary):return c.kind=="police" and c.special=="Chase"),"police role has a dedicated chase action")
	check(game.city.citizens.any(func(c:Dictionary):return c.kind=="thief" and c.special=="Sneak"),"thief role has a dedicated sneak action")
	check(game.city.citizens.any(func(c:Dictionary):return c.kind=="mech" and c.special=="Patrol"),"mech role has a dedicated patrol action")
	check(game.city.citizens.any(func(c:Dictionary):return c.kind=="fat_fries" and c.special=="Eat_Fries"),"fat fries role has a dedicated eating action")
	var citizen:Dictionary=game.city.citizens.filter(func(c:Dictionary):return c.kind=="jogger")[0]
	var skeleton:Skeleton3D=citizen.body.find_child("Skeleton3D",true,false)
	check(skeleton!=null and skeleton.get_bone_count()>=10,"stick character has a real articulated skeleton")
	var animator:AnimationPlayer=citizen.anim
	for clip in ["Idle","Walk","Run"]:
		var anim:=animator.get_animation(clip)
		print("CLIP "+JSON.stringify({"name":clip,"tracks":anim.get_track_count(),"length":anim.length,"loop":anim.loop_mode}))
		# Godot removes constant tracks during import; the idle only needs its
		# breathing/root track, while locomotion must retain articulated limbs.
		check(anim.get_track_count()>=(1 if clip=="Idle" else 8) and anim.length>.4 and anim.loop_mode==Animation.LOOP_LINEAR,"imported %s contains looping bone animation"%clip)
	var role_animation:=animator.get_animation(citizen.special)
	check(role_animation.get_track_count()>=8 and role_animation.loop_mode==Animation.LOOP_LINEAR,"role-specific animation contains articulated looping tracks")
	var walk_length:float=animator.get_animation("Walk").length
	animator.play("Walk");animator.seek(walk_length*.25,true)
	var bone:int=skeleton.find_bone("thighL")
	var pose:=skeleton.get_bone_pose_rotation(bone)
	animator.seek(walk_length*.75,true)
	check(pose.angle_to(skeleton.get_bone_pose_rotation(bone))>.15,"walk clip actually changes a limb pose")
	check(game.elapsed==0,"portrait tutorial waits for player input")
	for h in game.holes:
		if h!=game.player:h.enabled=false
	var start:Vector3=game.player.position
	touch(0,true,Vector2(270,800));await frames(2)
	var drag:=InputEventScreenDrag.new();drag.index=0;drag.position=Vector2(350,800);Input.parse_input_event(drag)
	await frames(15)
	var displacement:Vector3=game.player.position-start
	check(game.phase=="playing" and displacement.length()>.5,"one finger begins the round and moves the hole")
	check(displacement.dot(game.camera.global_basis.x)>.4,"right drag follows screen-right in portrait")
	touch(1,true,Vector2(70,820));touch(1,false,Vector2(70,820));await frames(2)
	check(game.player.touch_index==0,"releasing another finger preserves the active drag")
	touch(0,false,Vector2(350,800));await frames(3)
	check(game.player.touch_index==-1 and game.player.velocity.length()<.01,"release stops movement")
	# Audio controls precede the resume button; identify actual actions by
	# their stable UI name/text, rather than unrelated child creation order.
	var pause_button:=target("pause-action")
	if pause_button!=null:pause_button.pressed.emit()
	await frames(3)
	var resume_button:=target("KEEP PLAYING")
	check(pause_button!=null and paused and resume_button!=null and resume_button.text=="KEEP PLAYING","on-screen pause works without a keyboard")
	if resume_button!=null:resume_button.pressed.emit()
	await frames(3)
	check(resume_button!=null and not paused,"on-screen resume restores play")
	# Observe ordinary world-driven walking and fleeing, with actual imported clips.
	var origin:Vector3=citizen.body.position
	game.player.position=Vector3(45,0,45)
	# Select the middle of an actual walking window, including this citizen's
	# independent rest offset. A fixed elapsed time can legitimately cross into
	# rest during the forty-frame observation after a layout changes the seed.
	var walk_cycle:float=float(citizen.get("rest_cycle",12.0))
	var walk_offset:float=float(citizen.get("rest_offset",0.0))
	game.elapsed=walk_cycle*2.0+2.0-float(citizen.phase)-walk_offset
	await frames(40)
	check(citizen.clip=="Walk" and citizen.body.position.distance_to(origin)>.03,"moving pedestrian uses locomotion instead of sliding through its role gesture")
	game.player.position=Vector3(citizen.body.position.x+1.8,0,citizen.body.position.z)
	await frames(3)
	check(citizen.clip=="Run","nearby hole triggers the run clip")
	var rest_cycle:float=float(citizen.get("rest_cycle",12.0))
	var rest_window:float=float(citizen.get("rest_window",3.0))
	var rest_offset:float=float(citizen.get("rest_offset",0.0))
	game.player.position=Vector3(45,0,45);game.elapsed=rest_cycle-rest_window-rest_offset-float(citizen.phase)+rest_cycle
	await frames(3)
	check(citizen.clip=="Idle","resting pedestrian returns to idle")
	var result:={"checks":checks,"failures":failures,"unique_models":game.city.used_assets.size(),"citizens":animated,"edible_objects":game.total}
	print("PORTRAIT_ACCEPTANCE "+JSON.stringify(result))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			var out:=FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE);out.store_string(JSON.stringify(result,"\t")+"\n")
	# Release the streamed music decoder on its audio thread before freeing the game.
	game.audio.music.stop();OS.delay_msec(120);await process_frame
	game.queue_free();await process_frame;await process_frame;quit(0 if failures.is_empty() else 1)
