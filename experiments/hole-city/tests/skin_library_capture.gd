extends SceneTree
## Record the shipped UI using pointer input. Only the local unlock fixture is
## seeded; navigation, selection, equipment and round entry use normal controls.

class CapturePointer extends Control:
	var at:=Vector2(270,850)
	var down:=false
	func _draw() -> void:
		if down:draw_arc(at,18,0,TAU,32,Color("a9d8b5"),3,true)
		var points:=PackedVector2Array([at,at+Vector2(0,21),at+Vector2(6,15),at+Vector2(13,15),at])
		draw_colored_polygon(points,Color("efe4ce"))
		draw_polyline(points,Color("161a1b"),2,true)

var game:Node3D
var pointer:CapturePointer
var frame:=0
var events:Array[Dictionary]=[]
var failures:Array[String]=[]
var report_path:=""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):report_path=arg.trim_prefix("--report=")
	run.call_deferred()

func frames(count:int) -> void:
	for i in count:
		await process_frame
		frame+=1

func require(ok:bool,message:String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func move_pointer(at:Vector2) -> void:
	var motion:=InputEventMouseMotion.new()
	motion.position=at
	motion.global_position=at
	motion.relative=at-pointer.at
	pointer.at=at
	pointer.queue_redraw()
	root.push_input(motion,true)

func click_button(identity:String) -> void:
	var target:Button
	for item in game.ui.buttons:
		if item.name==identity or item.text==identity:target=item;break
	if not is_instance_valid(target):
		require(false,"Missing UI button: "+identity)
		return
	var start:Vector2=pointer.at
	var destination:Vector2=target.get_global_rect().get_center()
	for i in 12:
		var blend:float=smoothstep(0.0,1.0,float(i+1)/12.0)
		move_pointer(start.lerp(destination,blend))
		await frames(1)
	for pressed in [true,false]:
		var button:=InputEventMouseButton.new()
		button.position=destination
		button.global_position=destination
		button.button_index=MOUSE_BUTTON_LEFT
		button.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0
		button.pressed=pressed
		pointer.down=pressed
		pointer.queue_redraw()
		root.push_input(button,true)
		await frames(4)
	events.append({"frame":frame,"button":identity,"phase":game.phase,"menu":game.ui.menu_screen,"selected":game.selected_skin_id,"preview":game.ui.preview_skin_id})

func key(code:Key,pressed:bool) -> void:
	var event:=InputEventKey.new()
	event.keycode=code
	event.physical_keycode=code
	event.pressed=pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func run() -> void:
	game=load("res://fidelity/main.tscn").instantiate()
	root.add_child(game)
	# Session-local fixture; --test skips saved user settings. It is not earned
	# progress and nothing here writes player saves or changes unlock rules.
	game.note_skin_progress(game.SCORE_TARGET)
	var layer:=CanvasLayer.new()
	layer.layer=100
	layer.process_mode=Node.PROCESS_MODE_ALWAYS
	root.add_child(layer)
	pointer=CapturePointer.new()
	pointer.mouse_filter=Control.MOUSE_FILTER_IGNORE
	layer.add_child(pointer)
	await frames(60)
	await click_button("holes-nav")
	require(game.ui.menu_screen=="holes","Pointer opens the real Rift Forms menu")
	await frames(30)
	var equipped:Array[String]=[]
	for tab in ["classic","special"]:
		if tab=="special":
			await click_button("holes-special-tab")
			await frames(24)
		var ids:Array[String]=game.skin_ids("foundation" if tab=="classic" else "resonance")
		for index in ids.size():
			await click_button("hole-slot-%s-%02d"%[tab,index])
			require(game.selected_skin_id==ids[index] and game.ui.preview_skin_id==ids[index],"Pointer previews AND equips "+ids[index])
			equipped.append(game.selected_skin_id)
			await frames(135)
	await click_button("holes-home")
	require(game.phase=="title" and game.ui.menu_screen=="home","Dock button returns to the actual home screen")
	await frames(30)
	await click_button("ENTER THE RIFT")
	require(game.phase=="intro" and game.player.skin_id=="shard","The new round uses the form equipped in the menu")
	var expected:Color=Color(game.skin_definition("shard").tint)
	require(game.player.rim.material_override.albedo_color.is_equal_approx(expected),"Equipped Shard tint reaches the actual player mesh")
	await frames(36)
	key(KEY_D,true)
	await frames(75)
	key(KEY_D,false)
	await frames(30)
	await click_button("skin-action")
	require(game.player.skin_cooldown>0.0,"The normal HUD action activates the equipped skin")
	await frames(75)
	var result:={"fixture":"All ten skins available locally; no saved progress written","input":"Viewport mouse motion, button down/up and keyboard events","equipped":equipped,"events":events,"frames":frame,"failures":failures}
	if report_path!="":
		var report:=FileAccess.open(report_path,FileAccess.WRITE)
		report.store_string(JSON.stringify(result,"\t")+"\n")
	print("SKIN_INPUT_CAPTURE "+JSON.stringify(result))
	game.queue_free()
	layer.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
