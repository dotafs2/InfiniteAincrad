extends SceneTree
## Independent actual-game visual/input review. No test pose or combat overrides.
const Scene=preload("res://scenes/main.tscn")
const Out="res://artifacts/mobile-visual/"
var game:Node3D
var results:Array=[]
var errors:Array=[]
var spy:InputSpy

class InputSpy extends Node:
	var unhandled_mouse:=0
	func _unhandled_input(event:InputEvent) -> void:
		if event is InputEventMouseButton:unhandled_mouse+=1

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Out))
	run.call_deferred()

func check(ok:bool,description:String) -> void:
	results.append({"check":description,"passed":ok})
	if not ok:errors.append(description);push_error(description)

func wait_frames(n:int) -> void:
	for i in range(n):await process_frame

func find_button(node:Node,prefix:String) -> Button:
	if node is Button and node.text.begins_with(prefix) and node.is_visible_in_tree():return node
	for child in node.get_children():
		var found:=find_button(child,prefix)
		if found:return found
	return null

func click(button:Button) -> void:
	check(button!=null,"Requested GUI button exists")
	if not button:return
	var event:=InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT;event.position=button.get_global_rect().get_center();event.pressed=true
	root.push_input(event,true)
	await process_frame
	event=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.position=button.get_global_rect().get_center();event.pressed=false
	root.push_input(event,true)
	await wait_frames(3)

func save_frame(name:String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(Out+name+".png")
	var lods:Array=[]
	for batch in game.crowd_batches:lods.append(batch.multimesh.visible_instance_count)
	var snapshot={"frame":name,"elapsed":game.elapsed,"quality":game.quality_mode,"effective_quality":game.effective_quality,"viewport_size":[root.size.x,root.size.y],"scale_3d":root.scaling_3d_scale,"phase":game.phase,"tier":game.tier,"wave":game.wave,"boss_state":game.boss_state,"boss_hp":game.boss_hp,"crowd_total":game.crowd.size(),"alive":game._alive_crowd(),"lod_visible":lods,"draw_calls":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),"target_x":game.target_x}
	results.append(snapshot)
	print("VISUAL_FRAME ",JSON.stringify(snapshot))

func verify_button_bounds(button:Button) -> void:
	if not button:return
	var rect:=button.get_global_rect()
	var viewport:=root.get_visible_rect()
	check(viewport.encloses(rect),"Quality button fits logical viewport "+str(root.size))
	var text_width:float=button.get_theme_font("font").get_string_size(button.text,HORIZONTAL_ALIGNMENT_LEFT,-1,button.get_theme_font_size("font_size")).x
	check(text_width+20<rect.size.x,"Quality label fits its button without clipping")

func run() -> void:
	game=Scene.instantiate();root.add_child(game)
	game.qa_mode=true;game.audio_enabled=false
	spy=InputSpy.new();root.add_child(spy)
	await wait_frames(8)
	root.size=Vector2i(320,568);DisplayServer.window_set_size(root.size)
	await wait_frames(5)
	var quality:=find_button(game.hud,"QUALITY:")
	verify_button_bounds(quality)
	var unhandled_before:=spy.unhandled_mouse
	await click(quality)
	check(game.quality_mode=="low","Real ready-screen quality click changes Auto to Low")
	check(spy.unhandled_mouse==unhandled_before,"Quality click is consumed by GUI before unhandled input")
	check(not game.dragging,"Quality click does not start gameplay dragging")
	await save_frame("ui-ready-320-low")
	await click(find_button(game.hud,"QUALITY:"))
	check(game.quality_mode=="high","Second real quality click selects High")
	verify_button_bounds(find_button(game.hud,"QUALITY:"))
	await save_frame("ui-ready-320-high")
	root.size=Vector2i(486,864);DisplayServer.window_set_size(root.size)
	await wait_frames(5)
	for mode in ["low","high"]:
		game.set_quality(mode)
		if game.phase=="ready":await click(find_button(game.hud,"DEPLOY"))
		else:game.restart_game()
		game.auto_demo=true
		for t in [0.3,5.2,8.2,10.8,16.0]:
			while game.elapsed<t:await process_frame
			await save_frame(mode+"-"+str(t).replace(".","-"))
		game.auto_demo=false
		game.toggle_pause();await wait_frames(4)
		var paused_time:float=game.elapsed
		var paused_target:float=game.target_x
		quality=find_button(game.hud,"QUALITY:")
		verify_button_bounds(quality)
		unhandled_before=spy.unhandled_mouse
		await click(quality)
		check(spy.unhandled_mouse==unhandled_before,"Paused quality click consumed by GUI "+mode)
		check(game.phase=="paused" and is_equal_approx(game.elapsed,paused_time) and is_equal_approx(game.target_x,paused_target),"Paused quality click preserves phase, simulation time and aim "+mode)
		await save_frame("ui-paused-after-"+mode)
	var output={"evidence":"Actual production scene with normal physics/combat and declared deterministic steering; no health, wave, hero or pose overrides.","engine":Engine.get_version_info(),"device":RenderingServer.get_video_adapter_name(),"results":results,"errors":errors,"performance_scope":"Render counters are snapshots, not a phone benchmark or unbiased timing profile."}
	var file:=FileAccess.open(Out+"review.json",FileAccess.WRITE);file.store_string(JSON.stringify(output,"  "))
	print("MOBILE_VISUAL_REVIEW_COMPLETE failures=",errors.size())
	quit(1 if not errors.is_empty() else 0)
