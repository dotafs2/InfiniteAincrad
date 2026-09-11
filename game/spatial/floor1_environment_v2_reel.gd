extends Node
## 50-second, 20-component real-engine reel; runtime art and normal wind strength.
const KIT := preload("res://spatial/environment_v2.gd")
const TITLES := ["古橡树", "白桦组三株", "柱形柏树", "石地松树", "果园苹果树", "幼枫树", "开花灌木", "浆果丛", "蕨类地被", "草甸草簇", "野花草簇", "常春藤墙面", "芦苇簇", "苔藓倒木", "香草种植箱", "苔石组", "道路里程碑", "藤蔓木栅栏", "石质水槽", "帆布休憩棚"]
const NOTES := ["枝端与叶片微动 · 主干固定", "枝叶微动 · 树干固定", "叶簇微动 · 树干固定", "叶簇微动 · 树干固定", "叶片微动 · 果实与主枝固定", "叶片微动 · 主干固定", "叶片与花瓣摆动", "叶片摆动 · 浆果固定", "羽状叶与叶轴摆动", "根部固定 · 草叶摆动", "草叶、花瓣与花蕊微动", "附墙叶片轻摆", "茎叶与穗头摆动", "静态对照 · 枯木与苔藓固定", "香草摆动 · 木箱固定", "静态对照 · 岩石固定", "静态对照 · 石碑固定", "藤叶微动 · 木栅栏固定", "水面细微波纹 · 槽体固定", "静态对照 · 当前帆布未加风动"]
var _panels: Array[Dictionary] = []
var _frame := 0
var _pair := -1
var _title: Label
var _mode: Label
var _progress: ColorRect
var _out := ""
var _covered: Array[String] = []


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-dir="): _out = arg.trim_prefix("--capture-dir=")
	if not _out.is_empty(): DirAccess.make_dir_recursive_absolute(_out)
	var background := ColorRect.new()
	background.color = Color("121f25")
	background.size = Vector2(1400,900)
	add_child(background)
	_title = _text(Vector2(34,25), 32, "第一层 · 20 件环境组件风动")
	_mode = _text(Vector2(35,76), 18, "游戏引擎实录  /  正常风力  /  全貌与局部")
	_mode.modulate = Color("bdd2ce")
	for index in range(2): _panels.append(_panel(index))
	_progress = ColorRect.new()
	_progress.position = Vector2(34,877)
	_progress.size = Vector2(0,4)
	_progress.color = Color("81b6a3")
	add_child(_progress)
	_load_pair(0)


func _text(at: Vector2, font_size: int, value: String) -> Label:
	var label := Label.new()
	label.position = at
	label.text = value
	label.add_theme_font_size_override("font_size",font_size)
	add_child(label)
	return label


func _panel(index: int) -> Dictionary:
	var x := 34 + index * 681
	var viewport := SubViewport.new()
	viewport.size = Vector2i(651,625)
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var image_rect := TextureRect.new()
	image_rect.position = Vector2(x,126)
	image_rect.size = Vector2(651,625)
	image_rect.texture = viewport.get_texture()
	add_child(image_rect)
	var stage := Node3D.new()
	viewport.add_child(stage)
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("5c726c")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c4d8d4")
	env.ambient_light_energy = 0.65
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = env
	stage.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-43,-32,0)
	sun.light_color = Color("fff0da")
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	stage.add_child(sun)
	var floor_node := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(100,100)
	floor_node.mesh = plane
	floor_node.position.y = -0.035
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color("778274")
	floor_material.roughness = .95
	floor_node.material_override = floor_material
	stage.add_child(floor_node)
	var camera := Camera3D.new()
	camera.fov = 43
	camera.near = .03
	stage.add_child(camera)
	camera.current = true
	return {"stage":stage,"camera":camera,"item":null,"bounds":AABB(),"distance":1.0,"label":_text(Vector2(x,768),26,""),"note":_text(Vector2(x,811),18,"")}


func _load_pair(pair_index: int) -> void:
	_pair = pair_index
	for side in range(2):
		var panel: Dictionary = _panels[side]
		if panel.item != null:
			panel.stage.remove_child(panel.item)
			panel.item.free()
		var index := pair_index*2+side
		var id: String = KIT.IDS[index]
		var item := KIT.create("F1_"+id,false,0)
		panel.stage.add_child(item)
		panel.item = item
		var mesh_node: MeshInstance3D = item.find_children("*","MeshInstance3D",true,false)[0]
		panel.bounds = mesh_node.custom_aabb
		var size: Vector3 = panel.bounds.size
		panel.distance = maxf(size.y, maxf(size.x,size.z)*1.08) * 1.75 + 0.12
		panel.label.text = "%02d  %s" % [index+1,TITLES[index]]
		panel.note.text = NOTES[index]
		panel.note.modulate = Color("bed5c8")
		_covered.append(id)
	KIT.set_wind_strength(1.0)
	_pose(false)
	print("REEL_PAIR " + str(pair_index+1) + " " + str(_covered.slice(-2)))


func _pose(detail: bool) -> void:
	for side in range(2):
		var panel: Dictionary = _panels[side]
		var center: Vector3 = panel.bounds.get_center()
		var size: Vector3 = panel.bounds.size
		var index := _pair*2+side
		var distance: float = panel.distance
		var direction := Vector3(.35,.28,1.0).normalized()
		if detail:
			distance *= .50 if index < 6 else .68
			if index < 6: center.y += size.y*.21
			elif index == 14: center.y += size.y*.15
			elif index == 17: center.y = .85
		panel.camera.position = center + direction*distance
		panel.camera.look_at(center)
	_mode.text = "游戏引擎实录  /  正常风力  /  %s  ·  %d / 10 组" % ["局部风动" if detail else "完整物件",_pair+1]


func _process(_delta: float) -> void:
	var wanted := mini(_frame / 150,9)
	if wanted != _pair: _load_pair(wanted)
	var local_frame := _frame % 150
	if local_frame == 0: _pose(false)
	if local_frame == 75: _pose(true)
	KIT.set_review_time(float(_frame)/30.0)
	_progress.size.x = 1332.0 * float(_frame+1) / 1500.0
	if local_frame == 50 and not _out.is_empty(): call_deferred("_still",_pair)
	if _frame == 1499 and not _out.is_empty():
		var file := FileAccess.open(_out.path_join("reel.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify({"asset_count":_covered.size(),"asset_ids":_covered,"frames":1500,"fps":30,"duration_seconds":50,"wind_strength":1.0,"camera":"10 pairs, full then detail, fixed camera within each shot","source":"actual Godot runtime, LOD0","static_props_labeled":true},"  "))
	_frame += 1


func _still(pair_index: int) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.path_join("pair_%02d.png" % (pair_index+1)))
