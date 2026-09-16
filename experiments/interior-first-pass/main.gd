extends Node3D
const House = preload("res://house.gd")
var houses: Array = []
var player: CharacterBody3D
var camera: Camera3D
var hud: Label
var look_pitch := 0.0
var scripted := false
var capture_dir := ""
var evidence: Array = []
var notice := ""
var notice_left := 0.0

func _ready():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): capture_dir = arg.trim_prefix("--capture=")
		if arg == "--verify": scripted = true
	if not capture_dir.is_empty(): scripted = true
	_environment()
	for i in range(2):
		var house := House.new()
		house.provider = "tripo" if i==0 else "meshy"
		house.name = house.provider.capitalize()+"House"
		house.position.x = -5.5 if i==0 else 5.5
		add_child(house)
		houses.append(house)
	_player()
	_ui()
	for house in houses: await house.settle_contents()
	if not scripted: _load_state()
	if scripted: call_deferred("_run_evidence")

func _environment():
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("8daeca")
	sky_mat.sky_horizon_color = Color("d6d8cb")
	sky_mat.ground_bottom_color = Color("64604b")
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("dbe2ec")
	env.ambient_light_energy = 0.25
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-46,-28,0)
	sun.light_color = Color(1.0,0.93,0.80)
	sun.light_energy = 0.6
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 65
	add_child(sun)
	var ground := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(50,0.16,44)
	ground.mesh = box
	ground.position.y = -0.10
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("838864")
	mat.roughness = 0.95
	ground.material_override = mat
	add_child(ground)
	ground.create_trimesh_collision()
	for x in [-5.5,5.5]:
		var path := MeshInstance3D.new()
		var path_box := BoxMesh.new()
		path_box.size = Vector3(2.0,0.018,9)
		path.mesh = path_box
		path.position = Vector3(x,-0.007,8)
		var path_mat := StandardMaterial3D.new()
		path_mat.albedo_color = Color("b8ac8c")
		path.material_override = path_mat
		add_child(path)

func _player():
	player = CharacterBody3D.new()
	player.name = "Walker"
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.25
	capsule.height = 1.72
	collision.shape = capsule
	collision.position.y = 0.88
	player.add_child(collision)
	player.floor_snap_length = 0.25
	add_child(player)
	player.position = Vector3(-5.5,0.03,6.0)
	camera = Camera3D.new()
	camera.name = "EyeCamera"
	camera.position.y = 1.62
	camera.fov = 73
	camera.near = 0.045
	player.add_child(camera)
	camera.current = true

func _ui():
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Label.new()
	hud.position = Vector2(22,18)
	hud.add_theme_font_size_override("font_size",20)
	hud.add_theme_color_override("font_shadow_color",Color(0,0,0,0.9))
	hud.add_theme_constant_override("shadow_offset_x",2)
	hud.add_theme_constant_override("shadow_offset_y",2)
	layer.add_child(hud)
	var reticle := Label.new()
	reticle.text = "+"
	reticle.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	reticle.add_theme_font_size_override("font_size",20)
	layer.add_child(reticle)

func _physics_process(delta):
	if player == null: return
	if notice_left>0: notice_left -= delta
	if not scripted:
		var forward := float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W))
		var sideways := float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A))
		var movement := (player.basis * Vector3(sideways,0,forward)).normalized()
		var speed := 4.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 2.7
		player.velocity.x = movement.x*speed
		player.velocity.z = movement.z*speed
		if player.is_on_floor():
			player.velocity.y = 4.2 if Input.is_physical_key_pressed(KEY_SPACE) else -0.2
		else: player.velocity.y -= 15.0*delta
		player.move_and_slide()
	var current = nearest_house()
	hud.text = "%s | First-result components\nWASD move · Mouse look · E door · Q windows · Space jump\n1 Tripo / 2 Meshy · F5 save · F9 load · Esc cursor\n%s" % [current.provider.capitalize(),notice if notice_left>0 else "Click to look around"]

func nearest_house():
	return houses[0] if player.position.distance_to(houses[0].position)<player.position.distance_to(houses[1].position) else houses[1]

func _unhandled_input(event):
	if scripted: return
	if event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
		player.rotate_y(-event.relative.x*0.0025)
		look_pitch = clampf(look_pitch-event.relative.y*0.0025,-1.4,1.4)
		camera.rotation.x = look_pitch
	if event is InputEventKey and event.pressed and not event.echo:
		var house = nearest_house()
		match event.physical_keycode:
			KEY_ESCAPE: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			KEY_1: _spawn_at(0)
			KEY_2: _spawn_at(1)
			KEY_E:
				var entrance: Vector3 = house.global_position+Vector3(0,0,3.5)
				if player.global_position.distance_to(entrance)>3.0:
					_notify("Move closer to the door")
				elif house.host.is_door_open() and player.global_position.distance_to(entrance)<0.95:
					_notify("Step clear of the doorway before closing")
				else:
					house.host.interact_door()
					_save_state()
			KEY_Q:
				house.host.set_window_open(not house.host.is_window_open())
				_save_state()
			KEY_F5: _save_state()
			KEY_F9: _load_state()

func _spawn_at(index):
	player.position = houses[index].position+Vector3(0,0.03,5.5)
	player.rotation = Vector3.ZERO
	camera.rotation = Vector3.ZERO
	look_pitch = 0
	player.velocity = Vector3.ZERO

func _notify(message):
	notice = message
	notice_left = 3.0

func _save_state():
	var data := {"schema":1,"houses":[]}
	for h in houses: data.houses.append(h.serialize_state())
	var file := FileAccess.open("user://house_state.json",FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(data))
	_notify("Door and window state saved")

func _load_state():
	if not FileAccess.file_exists("user://house_state.json"): return
	var data = JSON.parse_string(FileAccess.get_file_as_string("user://house_state.json"))
	if data is Dictionary and data.get("schema")==1:
		for saved in data.get("houses",[]):
			for h in houses:
				if saved.get("provider")==h.provider: h.apply_state(saved)
	_notify("Saved door and window state restored")

func _check(id: String, passed: bool, details = {}):
	evidence.append({"id":id,"pass":passed,"details":details})
	print("CHECK ",id," ",passed)

func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from,to)
	query.exclude = [player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query)

func _step_to(start: Vector3, velocity: Vector3, frames: int) -> Vector3:
	player.position = start
	player.velocity = Vector3.ZERO
	await get_tree().physics_frame
	for frame in range(frames):
		player.velocity = velocity
		player.move_and_slide()
		await get_tree().physics_frame
	return player.position

func _verify_house(house):
	var base: Vector3 = house.position
	_check(house.provider+"/all_18_assets",house.missing.is_empty(),{"missing":house.missing,"instances":house.props.size()})
	house.host.set_door_open(false)
	house.host.set_window_open(false)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var stopped: Vector3 = await _step_to(base+Vector3(0,0.05,4.35),Vector3(0,-0.2,-2.0),75)
	_check(house.provider+"/closed_door_blocks_capsule",stopped.z>base.z+3.5,{"stopped_z":stopped.z})
	house.host.set_door_open(true)
	await get_tree().physics_frame
	var entered: Vector3 = await _step_to(base+Vector3(0,0.05,4.35),Vector3(0,-0.2,-2.0),95)
	_check(house.provider+"/open_door_capsule_enters",entered.z<base.z+2.0,{"entered_z":entered.z})
	var leaving: Vector3 = await _step_to(base+Vector3(0,0.05,2.0),Vector3(0,-0.2,2.0),95)
	_check(house.provider+"/capsule_exits",leaving.z>base.z+4.0,{"exit_z":leaving.z})
	var side: Vector3 = await _step_to(base+Vector3(-3,0.05,0.5),Vector3(-2,-0.2,0),65)
	_check(house.provider+"/wall_blocks_capsule",side.x>base.x-4.05,{"stop_x":side.x-base.x})
	for point in [Vector3(0,0,-1.8),Vector3(-1.5,0,1.2),Vector3(1.3,0,1.6)]:
		var hit := _ray(base+point+Vector3(0,0.8,0),base+point-Vector3(0,0.5,0))
		_check(house.provider+"/floor_"+str(point),not hit.is_empty())
	var ceiling := _ray(base+Vector3(0,2,0),base+Vector3(0,5,0))
	_check(house.provider+"/ceiling_collision",not ceiling.is_empty())
	# Inspect every independent sash at the lower opening, before and after opening.
	for sash in house.host.sashes:
		house.host.set_window_open(false)
		await get_tree().physics_frame
		# The fixed central mullion correctly remains solid. Probe a lower side cell.
		var point: Vector3 = sash.to_global(Vector3(0.20,0.20,0))
		var axis: Vector3 = sash.global_basis.z.normalized()
		var closed := _ray(point-axis*0.55,point+axis*0.55)
		house.host.set_window_open(true)
		await get_tree().physics_frame
		var opened := _ray(point-axis*0.55,point+axis*0.55)
		_check(house.provider+"/window_"+str(sash.name),not closed.is_empty() and opened.is_empty(),{"closed_hit":str(closed.get("collider","none")),"open_hit":str(opened.get("collider","none"))})
		var mullion: Vector3 = point-sash.global_basis.x.normalized()*0.20
		_check(house.provider+"/fixed_mullion_"+str(sash.name),not _ray(mullion-axis*0.55,mullion+axis*0.55).is_empty())
	for tag in house.props:
		var prop = house.props[tag]
		var count: int = prop.find_children("PropCollision","StaticBody3D",true,false).size()
		_check(house.provider+"/prop_collision/"+tag,count>0)
	for tag in house.support_results:
		_check(house.provider+"/placed_on_support/"+tag,house.support_results[tag])
	var saved: Dictionary = house.serialize_state()
	house.host.set_door_open(false)
	house.host.set_window_open(false)
	house.apply_state(saved)
	_check(house.provider+"/state_roundtrip",house.serialize_state()==saved)
	# Stable IDs remain unique even when a chair, potion or lamp is instanced twice.
	var ids := {}
	for tag in house.props: ids[house.props[tag].get_meta("instance_id")] = true
	_check(house.provider+"/unique_instance_ids",ids.size()==house.props.size())

func _shot(name: String, eye: Vector3, target: Vector3):
	player.position = eye-Vector3(0,1.62,0)
	player.rotation = Vector3.ZERO
	camera.rotation = Vector3.ZERO
	camera.look_at(target,Vector3.UP)
	hud.get_parent().visible = false
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var code := image.save_png(capture_dir.path_join(name+".png"))
	_check("capture/"+name,code==OK)
	hud.get_parent().visible = true

func _run_evidence():
	await get_tree().physics_frame
	if not capture_dir.is_empty() and FileAccess.file_exists("res://verification.json"):
		var previous = JSON.parse_string(FileAccess.get_file_as_string("res://verification.json"))
		evidence = previous.get("checks",[])
	else:
		for house in houses: await _verify_house(house)
	if not capture_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(capture_dir)
		for house in houses:
			house.host.set_door_open(false)
			house.host.set_window_open(false)
		await _shot("00_two_houses_closed",Vector3(13,9,18),Vector3(0,2,0))
		for house in houses:
			var base: Vector3 = house.position
			house.host.set_door_open(true)
			house.host.set_window_open(true)
			await _shot(house.provider+"_01_entrance",base+Vector3(3.6,2.0,7.4),base+Vector3(0,1.4,1))
			await _shot(house.provider+"_02_inside",base+Vector3(0,1.62,2.8),base+Vector3(0,1.2,-1.4))
			await _shot(house.provider+"_03_workshop",base+Vector3(0,1.60,0.5),base+Vector3(2.5,0.95,-1.5))
			await _shot(house.provider+"_04_living",base+Vector3(1.2,1.6,1.0),base+Vector3(-2.1,0.8,-1))
			await _shot(house.provider+"_05_kitchen",base+Vector3(0,1.5,-0.9),base+Vector3(-2.65,0.85,1.9))
			await _shot(house.provider+"_06_window_open",base+Vector3(2.0,1.6,5.3),base+Vector3(2.0,1.4,3.4))
			house.host.set_window_open(false)
			await _shot(house.provider+"_07_window_closed",base+Vector3(2.0,1.6,5.3),base+Vector3(2.0,1.4,3.4))
	var result := {"checks":evidence,"failures":evidence.filter(func(v):return not v.pass).size(),"houses":[]}
	for house in houses:
		result.houses.append({"provider":house.provider,"missing":house.missing,"props":house.props.size(),"windows":house.host.sashes.size(),"transforms":house.transforms})
	var target := "res://verification.json" if capture_dir.is_empty() else capture_dir.path_join("verification.json")
	var file := FileAccess.open(target,FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t"))
	print("RESULT ",result.failures," failures / ",evidence.size()," checks")
	get_tree().quit(0 if result.failures==0 else 1)
