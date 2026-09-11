extends Node3D
## Isolated art street. No resident simulation, save writer or model calls.
const HOUSE := preload("res://spatial/residence_component.gd")
const PLANTS := preload("res://spatial/environment_v2.gd")
const LABELS := ["菩提庭院宅", "铜檐窄街宅", "蔷薇花院宅", "鼠尾草长廊宅", "青瓷转角宅"]
var _houses: Array[Node3D] = []
var _camera: Camera3D
var _label: Label
var _capture_dir := ""
var _yaw := 0.0
var _pitch := 0.0
var _plants: Node3D

func _ready() -> void:
	get_viewport().msaa_3d = Viewport.MSAA_4X
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): _capture_dir = arg.trim_prefix("--capture-dir=")
	_light()
	_ground()
	var placements := [Vector3(-17,0,-9), Vector3(-5,0,-9), Vector3(8,0,-9), Vector3(-12,0,12), Vector3(7,0,12)]
	for i in range(5):
		var house := Node3D.new()
		house.set_script(HOUSE)
		house.variant = i + 1
		house.name = "Residence_%02d" % (i+1)
		house.position = placements[i]
		if i >= 3: house.rotation_degrees.y = 180.0
		add_child(house)
		_houses.append(house)
	_plants = Node3D.new()
	add_child(_plants)
	for item in [["cypress_column",Vector3(-24,0,-6)], ["orchard_apple",Vector3(22,0,-7)], ["flowering_shrub",Vector3(-23,0,-2)], ["herb_planter",Vector3(-2,0,-4.8)], ["wildflower_patch",Vector3(18,0,-4.2)], ["young_maple",Vector3(19,0,9)]]:
		var plant := PLANTS.create("F1_"+item[0],false,1)
		plant.position = item[1]
		_plants.add_child(plant)
	_camera = Camera3D.new()
	_camera.near = .08
	_camera.fov = 49
	add_child(_camera)
	_camera.current = true
	_pose(Vector3(32,27,43),Vector3(-1,4,1))
	var layer := CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(32,25)
	_label.add_theme_font_size_override("font_size",24)
	_label.add_theme_color_override("font_color",Color("f5ecd8"))
	_label.add_theme_color_override("font_shadow_color",Color("25322c"))
	_label.add_theme_constant_override("shadow_offset_x",2)
	_label.add_theme_constant_override("shadow_offset_y",2)
	_label.text = "起始之镇 · 五种居民住宅\n原创外观 / 2K PBR / 三档 LOD"
	layer.add_child(_label)
	if not _capture_dir.is_empty(): call_deferred("_capture")

func _light() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("789aac")
	sm.sky_horizon_color = Color("d6d8c7")
	sm.ground_horizon_color = Color("b0b5a0")
	sm.ground_bottom_color = Color("819078")
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("d1dedc")
	env.ambient_light_energy = .63
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = true
	env.ssao_radius = .5
	env.ssao_intensity = 1.05
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-47,-32,0)
	sun.light_color = Color("ffefd7")
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 95
	add_child(sun)

func _ground() -> void:
	var plane := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(180,180)
	plane.mesh = mesh
	plane.position.y = -.025
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("879178")
	material.roughness = .96
	plane.material_override = material
	add_child(plane)
	var pavement := MeshInstance3D.new()
	var paving := PlaneMesh.new()
	paving.size = Vector2(58,38)
	pavement.mesh = paving
	pavement.position.y = -.006
	var shader := Shader.new()
	shader.code = "shader_type spatial; uniform sampler2D albedo_map:source_color,filter_linear_mipmap_anisotropic,repeat_enable; void fragment(){vec2 p=UV*vec2(72.5,47.5);p.x+=mod(floor(p.y),2.0)*0.5;vec2 e=min(fract(p),1.0-fract(p));float edge=smoothstep(0.005,0.025,min(e.x,e.y));float s=fract(sin(dot(floor(p),vec2(12.9898,78.233)))*43758.5453);ALBEDO=mix(vec3(.27,.29,.25),texture(albedo_map,UV*vec2(29.,19.)).rgb*vec3(.64,.61,.51)*(0.92+0.12*s),edge);ROUGHNESS=.9;}"
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("albedo_map",load("res://assets/floor1/residences/textures/limestone_albedo.png"))
	pavement.material_override = mat
	add_child(pavement)

func _pose(at: Vector3,target: Vector3) -> void:
	_camera.position = at
	_camera.look_at(target)
	_yaw = _camera.rotation.y
	_pitch = _camera.rotation.x

func _process(delta: float) -> void:
	if _capture_dir.is_empty() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var v := Vector3(float(Input.is_key_pressed(KEY_D))-float(Input.is_key_pressed(KEY_A)),float(Input.is_key_pressed(KEY_E))-float(Input.is_key_pressed(KEY_Q)),float(Input.is_key_pressed(KEY_S))-float(Input.is_key_pressed(KEY_W)))
		_camera.position += _camera.basis*v.normalized()*delta*(12.0 if Input.is_key_pressed(KEY_SHIFT) else 5.0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x*.003
		_pitch = clampf(_pitch-event.relative.y*.003,-1.4,1.4)
		_camera.rotation = Vector3(_pitch,_yaw,0)

func _shot(name_text: String) -> void:
	for i in range(12): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var err := get_viewport().get_texture().get_image().save_png(_capture_dir.path_join(name_text+".png"))
	assert(err == OK)

func _capture() -> void:
	DirAccess.make_dir_recursive_absolute(_capture_dir)
	for i in range(40): await get_tree().process_frame
	await _shot("street_overview")
	_pose(Vector3(-1,1.72,3),Vector3(-4,5,-9))
	await _shot("street_eye_level")
	_plants.visible = false
	for house in _houses: house.visible = false
	var shots: Array[String] = []
	for i in range(5):
		var house := _houses[i]
		var saved_transform := house.transform
		house.transform = Transform3D.IDENTITY
		house.visible = true
		for mesh: MeshInstance3D in house.find_children("*","MeshInstance3D",true,false):
			mesh.visibility_range_begin = 0.0
			mesh.visibility_range_end = 0.0
			mesh.visible = int(mesh.get_meta("lod")) == 0
		_label.text = "%02d  %s\n起始之镇 · 住宅外观" % [i+1,LABELS[i]]
		var bounds: AABB = house.get_meta("bounds")
		var target := bounds.get_center()
		var distance := maxf(bounds.size.y*1.48,bounds.size.x*1.4)
		_pose(target+Vector3(distance*.84,distance*.46,distance),target)
		await _shot("house_%02d" % (i+1))
		shots.append("house_%02d" % (i+1))
		_pose(Vector3(2.9,2.45,7.0),Vector3(0,1.8,3.3))
		if i == 3: _pose(Vector3(-.2,3.8,7.5),Vector3(-2.7,2.2,3.1))
		if i == 4: _pose(Vector3(-.4,2.5,7.4),Vector3(-1.75,1.65,3.2))
		await _shot("detail_%02d" % (i+1))
		shots.append("detail_%02d" % (i+1))
		if i == 0:
			var checker_shader := Shader.new()
			checker_shader.code = "shader_type spatial; void fragment(){vec2 p=UV*8.0;float c=mod(floor(p.x)+floor(p.y),2.0);ALBEDO=mix(vec3(.08,.19,.23),vec3(.75,.83,.75),c);ROUGHNESS=.85;}"
			var checker := ShaderMaterial.new()
			checker.shader = checker_shader
			_label.text = "UV0 检查 · 每格 25 cm\n按米铺展 / 木构跟随轴向 / 重复 UV 用于平铺材质"
			for mesh: MeshInstance3D in house.find_children("*","MeshInstance3D",true,false): mesh.material_override = checker
			await _shot("uv0_checker")
			for mesh: MeshInstance3D in house.find_children("*","MeshInstance3D",true,false): mesh.material_override = null
		for mesh: MeshInstance3D in house.find_children("*","MeshInstance3D",true,false):
			var level := int(mesh.get_meta("lod"))
			mesh.visible = true
			mesh.visibility_range_begin = [0.0,32.0,70.0][level]
			mesh.visibility_range_end = [32.0,70.0,0.0][level]
		house.visible = false
		house.transform = saved_transform
	for house in _houses: house.visible = true
	_plants.visible = true
	_pose(Vector3(32,27,43),Vector3(-1,4,1))
	for i in range(20): await get_tree().process_frame
	var ms: Array[float] = []
	var previous := Time.get_ticks_usec()
	for i in range(120):
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		ms.append((now-previous)/1000.0)
		previous = now
	ms.sort()
	var collisions := 0
	var lod_meshes := 0
	for house in _houses:
		collisions += house.find_children("*","CollisionShape3D",true,false).size()
		lod_meshes += house.find_children("*","MeshInstance3D",true,false).size()
	var result := {"suite":"residences_render_review","variants":5,"lod_meshes":lod_meshes,"collision_proxies":collisions,"shots":shots,"frame_ms_median":ms[60],"frame_ms_p95":ms[114],"frames":120,"render_resolution":str(get_viewport().get_texture().get_size()),"scope":"isolated art street; no maintained world","save_writes":0,"model_calls":0}
	await _catalogue()
	result["catalogue"] = "catalogue.png"
	var file := FileAccess.open(_capture_dir.path_join("evidence.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"  "))
	print(JSON.stringify(result))
	get_tree().quit(0 if lod_meshes==15 and collisions==13 else 1)

func _catalogue() -> void:
	_label.hide()
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var size := get_viewport().get_visible_rect().size
	var background := ColorRect.new()
	background.color = Color("e9e6dc")
	background.size = size
	layer.add_child(background)
	var card_size := Vector2((size.x-48)/3.0,(size.y-36)/2.0)
	for i in range(5):
		var container := SubViewportContainer.new()
		container.position = Vector2(12+(i%3)*(card_size.x+12),12+(i/3)*(card_size.y+12))
		container.size = card_size
		container.stretch = true
		layer.add_child(container)
		var viewport := SubViewport.new()
		viewport.size = Vector2i(card_size)
		viewport.own_world_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		viewport.msaa_3d = Viewport.MSAA_4X
		container.add_child(viewport)
		var room := Node3D.new()
		viewport.add_child(room)
		for child in get_children():
			if child is WorldEnvironment or child is DirectionalLight3D: room.add_child(child.duplicate())
		var ground := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(100,100)
		ground.mesh = plane
		ground.position.y = -.03
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("bbbda9")
		material.roughness = 1.0
		ground.material_override = material
		room.add_child(ground)
		var model := Node3D.new()
		model.set_script(HOUSE)
		model.variant = i+1
		model.force_lod = 0
		model.collision_enabled = false
		room.add_child(model)
		var camera := Camera3D.new()
		camera.fov = 44
		room.add_child(camera)
		camera.current = true
		var bounds: AABB = model.get_meta("bounds")
		var center := bounds.get_center()
		var distance := maxf(bounds.size.y*1.62,bounds.size.x*1.38)
		camera.position = center+Vector3(distance*.78,distance*.39,distance)
		camera.look_at(center)
		var title := Label.new()
		title.position = container.position+Vector2(16,14)
		title.add_theme_font_size_override("font_size",21)
		title.add_theme_color_override("font_color",Color("344a46"))
		title.text = "%02d  %s" % [i+1,LABELS[i]]
		layer.add_child(title)
	var note := Label.new()
	note.position = Vector2(12+2*(card_size.x+12)+28,12+(card_size.y+12)+65)
	note.add_theme_font_size_override("font_size",27)
	note.add_theme_color_override("font_color",Color("43594f"))
	note.text = "起始之镇\nRESIDENCES 01–05\n\n石灰岩 · 木构 · 瓦顶\n2K PBR / 双 UV / 三档 LOD\n\nGodot 实时渲染\n原创住宅外观 · 非室内成品"
	layer.add_child(note)
	await _shot("catalogue")
	layer.queue_free()
