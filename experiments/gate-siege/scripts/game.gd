extends Node3D
## Fixed-camera multiplier shooter reconstructed from the supplied clip.
## All scene resources and progression are isolated from Hole Feast.
const Campaign = preload("res://scripts/campaign.gd")
const Squad = preload("res://scripts/squad.gd")
const Encounters = preload("res://scripts/encounters.gd")
const CoverageCombat = preload("res://scripts/coverage_combat.gd")
const SprayVisual = preload("res://scripts/spray_visual.gd")
const CreatureMotion = preload("res://scripts/creature_motion.gd")
const Hud = preload("res://scripts/hud.gd")
const ShadowFootprints = preload("res://assets/expansion/shadows/footprints.gd")
const ROAD_LEFT := -5.1
const ROAD_RIGHT := 5.1
const PLAYER_Z := 6.2
const GATE_Z := [0.2, -4.2, -9.8]
const GATE_WIDTH := [3.5, 3.5, 5.55]
const RECRUIT_COSTS := [60, 550, 900]
const BOSS_HEALTH := [1200, 16000, 55000]
const CAPACITY := 1600
const GOLD_ARMOR := 999.0
var font = preload("res://assets/fonts/Barlow-ExtraBold.ttf")
var camera: Camera3D
var player: Node3D
var player_model: Node3D
var player_shadow_root: Node3D
var player_directional_shadow: MeshInstance3D
var player_contact_shadow: MeshInstance3D
var recruit_shadow: MeshInstance3D
var model_cache: Dictionary = {}
var statue: Node3D
var boss: Node3D
var boss_model: Node3D
var stage_root: Node3D
var recruit_label: Label3D
var boss_label: Label3D
var boss_bar: MeshInstance3D
var hud: Control
var gates: Array[Node3D] = []
var gold_plates: Array[MeshInstance3D] = []
var gate_labels: Array[Label3D] = []
var crowd_batches: Array[MultiMeshInstance3D] = []
var crowd_parts: Array[Transform3D] = []
var crowd: Array[Dictionary] = []
var bullets: Array[Dictionary] = [] # Empty historical helper field; no live projectile objects.
var sparks: Array[Dictionary] = []
var floats: Array[Dictionary] = []
var bullet_mm: MultiMeshInstance3D
var spark_mm: MultiMeshInstance3D
var elapsed := 0.0
var sim_time := 0.0
var shot_clock := 0.0
var player_x := -1.8
var target_x := -1.8
var dragging := false
var touch_id := -1
var phase := "ready"
var wave := 0
var tier := 0
var recruit_remaining := 60.0
var pending_tier := -1
var weapon_mode := "rifle"
var squad: Node3D
var encounters = Encounters.new()
var combat = CoverageCombat.new()
var spray = SprayVisual.new()
var boss_kind := "brute"
var lane_root: Node3D
var lane_cards: Array[Dictionary] = []
var lane_serial := 0
var lane_spawn_clock := 0.0
var lane_label: Label3D
var last_crowd_absorbed := 0.0
var arc_mm: MultiMeshInstance3D
var arcs: Array[Dictionary] = []
var wave_clock := 0.0
var boss_hp := 1200.0
var boss_max := 1200.0
var boss_z := -30.0
var boss_dead := false
var crowd_front := -12.0
var gold_hp := GOLD_ARMOR
var kills := 0
var health := 100.0
var shake := 0.0
var message := ""
var message_time := 0.0
var upgrade_flash := 0.0
var audio_enabled := true
var sfx: AudioStreamPlayer
var shot_audio: AudioStreamWAV
var hit_audio: AudioStreamWAV
var upgrade_audio: AudioStreamWAV
var rng := RandomNumberGenerator.new()
var metrics := {"shots":0,"gate5":0,"gate999":0,"gate2":0,"recruits":0,"bosses":0,"peak_packets":0,"damage":0.0,"breaches":0,"wins":0,"losses":0,"soldiers":0,"elites":0,"splash_hits":0,"chain_hits":0,"wave_clears":0,"peak_fields":0}
var qa_mode := false
var screenshot_dir := ""
var auto_demo := false
var capture_ticks := 0
var next_capture := 0
const CAPTURE_TIMES := [0.1,5.0,8.0,9.0,10.0,12.0,16.0,22.0,28.0,35.0]
var deferred_clear := false
var statue_shell: ShaderMaterial
var recruit_flight: Node3D
var flight_clock := 0.0
var flight_start := Vector3.ZERO
var flight_scale := 1.0
var recruiting := false
var kill_flashes: Array[Dictionary] = []
var death_mm: MultiMeshInstance3D
var boss_flash: Node3D
var boss_flash_time := 0.0
var boss_flash_cooldown := 0.0
var boss_death_time := 0.0
var statue_rise := 1.0
var visual_rng := RandomNumberGenerator.new()
var sun: DirectionalLight3D
var fill: DirectionalLight3D
var world_environment: Environment
var gold_batch: MultiMeshInstance3D
var boss_anim: AnimationPlayer
var boss_state := "walk"
var boss_state_clock := 0.0
var boss_hit_cooldown := 0.0
var boss_next_attack := 5.0
var boss_flash_mat: ShaderMaterial
var quality_mode := "auto"
var effective_quality := "low"
var visual_bullet_cap := 512
var per_packet_cap := 18
var spark_cap := 96
var death_cap := 32
var crowd_shader: ShaderMaterial
var crowd_dirty := true
var crowd_lod_clock := 0.0
var visual_dirty := true
var rendered_time := -1.0
var last_draw_phase := ""
var hud_clock := 0.0
var slow_frame_time := 0.0
var render_warmup_done := false


func _ready() -> void:
	rng.seed = 812876
	visual_rng.seed = 67934
	qa_mode = "--qa" in OS.get_cmdline_user_args()
	auto_demo = "--demo" in OS.get_cmdline_user_args()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--capture="): screenshot_dir = a.trim_prefix("--capture=")
	combat.setup(self)
	_build_world()
	_build_gates()
	_build_projectiles()
	_build_audio()
	arc_mm=_new_batch(160,Color("9ddfff"),true)
	player = Node3D.new()
	add_child(player)
	player.position = Vector3(player_x,0,PLAYER_Z)
	_set_player_model()
	squad=Squad.new();add_child(squad);squad.setup(self)
	_build_recruit_lane()
	stage_root = Node3D.new()
	add_child(stage_root)
	_start_wave()
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Hud.new()
	hud.game = self
	layer.add_child(hud)
	if auto_demo: start_game()
	if qa_mode: audio_enabled = false
	set_quality("auto")
	get_viewport().size_changed.connect(_update_resolution)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--quality="): set_quality(a.trim_prefix("--quality="))
	_warm_graphics.call_deferred()

func material(color: Color, metal: float=0.0, rough: float=0.65) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metal
	m.roughness = rough
	return m

func box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	n.mesh = mesh
	n.material_override = mat
	n.position = pos
	parent.add_child(n)
	return n

func sphere(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radial_segments = 20
	mesh.rings = 10
	n.mesh = mesh
	n.scale = size
	n.material_override = mat
	n.position = pos
	parent.add_child(n)
	return n

func text3(parent: Node3D, value: String, pos: Vector3, size: int, pixel: float=0.013) -> Label3D:
	var n := Label3D.new()
	n.text = value
	n.font = font
	n.font_size = size
	n.pixel_size = pixel
	n.outline_size = 12
	n.outline_modulate = Color(0.025,0.025,0.035)
	n.modulate = Color.WHITE
	n.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	n.no_depth_test = true
	n.render_priority = 2
	n.position = pos
	parent.add_child(n)
	return n

func _build_world() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("194c7c")
	e.fog_enabled=true
	e.fog_light_color=Color("6099bd")
	e.fog_light_energy=0.7
	e.fog_density=0.0015
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("c8d6ee")
	e.ambient_light_energy = 0.32
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("6c7e97")
	sky_mat.sky_horizon_color = Color("e4e3e0")
	sky_mat.ground_bottom_color = Color("4a4f61")
	sky_mat.ground_horizon_color = Color("c5c9d0")
	sky.sky_material = sky_mat
	e.sky = sky
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.environment = e
	world_environment=e
	add_child(env)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-53,-32,0)
	sun.light_color = Color("fff0df")
	sun.light_energy = 0.88
	sun.shadow_enabled = false
	sun.directional_shadow_max_distance = 80.0
	sun.shadow_blur = 1.4
	add_child(sun)
	fill = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-30,150,0)
	fill.light_color = Color("b7d7ff")
	fill.light_energy = 0.18
	add_child(fill)
	camera = Camera3D.new()
	camera.position = Vector3(0,26.0,32.0)
	add_child(camera)
	camera.look_at(Vector3(0,0,-4.8))
	camera.fov = 35
	camera.current = true
	camera.far = 130
	box(self,Vector3(0,-0.26,0.4),Vector3(10.6,0.5,31.2),material(Color("b8b4b7"),0.08,0.91))
	box(self,Vector3(-2.35,-0.26,-32.5),Vector3(5.9,0.5,35),material(Color("b8b4b7"),0.08,0.91))
	var rail := material(Color("747780"),0.65,0.38)
	var dark := material(Color("3f434d"),0.6,0.42)
	var rim := material(Color("c0bdc5"),0.75,0.32)
	for x in [-5.25,5.25]:
		var length: float=68.0 if x<0 else 31.2
		var center_z: float=-16.0 if x<0 else 0.4
		box(self,Vector3(x,0.3,center_z),Vector3(0.18,0.6,length),rail)
		box(self,Vector3(x,0.64,center_z),Vector3(0.22,0.1,length),rim)
		box(self,Vector3(x,0.08,center_z),Vector3(0.28,0.16,length),dark)
		for i in range(32 if x<0 else 16):
			box(self,Vector3(x,0.52,14-i*2.0),Vector3(0.25,0.88,0.14),dark)
	# Rear lanes: a narrow wall separates incoming enemies from recruitment.
	box(self,Vector3(0.6,0.25,-30),Vector3(0.14,0.5,40),rail)
	box(self,Vector3(0.6,0.54,-30),Vector3(0.21,0.08,40),rim)
	for i in range(14):
		box(self,Vector3(0.6,0.4,-10-i*2.7),Vector3(0.24,0.8,0.14),dark)
	var floor_shader:Shader=preload("res://assets/shaders/floor.gdshader")
	var floor_mat := ShaderMaterial.new()
	floor_mat.shader = floor_shader
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(10.3,31.2)
	ground.mesh = plane
	ground.position = Vector3(0,0.005,0.4)
	ground.material_override = floor_mat
	add_child(ground)
	var rear=ground.duplicate()
	var rear_plane=PlaneMesh.new()
	rear_plane.size=Vector2(5.6,35)
	rear.mesh=rear_plane
	rear.position=Vector3(-2.35,0.005,-32.5)
	add_child(rear)
	_build_city()
	_batch_boxes(self)

func _build_gates() -> void:
	var blue := material(Color("3a9ddc"),0.18,0.33)
	var edge := material(Color("66c5ef"),0.35,0.28)
	var face := material(Color("55ace3"),0.06,0.43)
	for i in range(3):
		var g := Node3D.new()
		add_child(g)
		g.position = Vector3(0,0,GATE_Z[i])
		var w: float = GATE_WIDTH[i]
		box(g,Vector3(0,0.67,0),Vector3(w,1.0,0.16),face)
		box(g,Vector3(0,0.15,0),Vector3(w+0.13,0.1,0.27),blue)
		box(g,Vector3(0,1.2,0),Vector3(w+0.13,0.08,0.22),edge)
		for x in [-w/2,w/2]:
			box(g,Vector3(x,0.69,0),Vector3(0.12,1.4,0.24),blue)
			box(g,Vector3(x,0.08,0.1),Vector3(0.26,0.13,0.65),edge)
		g.scale.y=1.18
		gates.append(g)
		var label := text3(g,["×5","×999","×2"][i],Vector3(0,0.78,0.15),72,0.014 if i<2 else 0.018)
		label.scale=Vector3.ONE*1.18
		gate_labels.append(label)
		if i==1:
			var gold := material(Color("ffcf26"),0.58,0.3)
			for row in range(5):
				for col in range(10):
					var plate := box(g,Vector3(-w/2+(col+0.5)*w/10,1.14-row*0.21,0.18+sin(col*7+row)*0.018),Vector3(w/10+0.006,0.218,0.17),gold)
					gold_plates.append(plate)
			var tm:=TextMesh.new()
			tm.font=font; tm.font_size=74; tm.pixel_size=0.012; tm.depth=0.07;tm.text="×999"
			var embossed:=MeshInstance3D.new()
			embossed.mesh=tm;embossed.material_override=gold;embossed.position=Vector3(0,0.66,0.29)
			embossed.name="EmbossedGold"
			g.add_child(embossed)
			label.position.z = 0.28
			label.modulate = Color("ffe469")
	# Collapse static rails and frame boxes by material, keeping gate motion on parents.
	for g in gates: _batch_boxes(g, gold_plates)
	gold_batch = _batch_mesh_list(gold_plates, gates[1])
	for plate in gold_plates: plate.visible = false
	gates[2].position.x = -2.22
	_update_gates()

func _update_gates() -> void:
	gates[0].position.x = -2.95*cos(elapsed*TAU/5.3)
	gates[1].position.x = 2.95*cos(elapsed*TAU/5.3)
	if gold_batch:
		gold_batch.multimesh.visible_instance_count = ceili(clampf(gold_hp/GOLD_ARMOR,0,1)*50)
	gate_labels[1].modulate = Color.WHITE
	gate_labels[1].visible=true
	gate_labels[1].modulate=Color("ffe56b") if gold_hp>=GOLD_ARMOR*0.6 else Color.WHITE
	gate_labels[1].outline_modulate=Color("98700a") if gold_hp>=GOLD_ARMOR*0.6 else Color("10111b")
	gates[1].get_node("EmbossedGold").visible=gold_hp>=GOLD_ARMOR*0.6

func _fallback(kind: String) -> Node3D:
	var n := Node3D.new()
	var skin := material(Color("ceac91"))
	var cloth := material(Color("2183bd"),0.25)
	var black := material(Color("293448"),0.4)
	var scale_y := 1.0
	if kind in ["gunner","gunner_silver"]: scale_y=1.6
	if kind in ["mech","brute"]: scale_y=3.4
	if kind=="brute": cloth=material(Color("c68b8c"))
	if kind=="mech": cloth=material(Color("edbd36"),0.7)
	for x in [-0.16,0.16]:
		sphere(n,Vector3(x,0.18,0),Vector3(0.22,0.32,0.3),black)
	sphere(n,Vector3(0,0.55,0),Vector3(0.57,0.55,0.42),cloth)
	sphere(n,Vector3(0,0.88,0),Vector3(0.32,0.3,0.31),skin)
	sphere(n,Vector3(0,1.02,0),Vector3(0.4,0.17,0.4),cloth)
	box(n,Vector3(0.23,0.57,-0.42),Vector3(0.15,0.16,0.75),black)
	n.scale = Vector3.ONE*scale_y
	return n

func model(kind: String) -> Node3D:
	var path := "res://assets/models/"+kind+".glb"
	if kind in ["infantry","gunner","mech"]:
		path = "res://assets/expansion/"+kind+".glb"
	if kind in ["dragon","golem","skitter"]: path="res://assets/expansion/"+kind+".glb"
	if ResourceLoader.exists(path):
		if not model_cache.has(path): model_cache[path]=load(path)
		var result=(model_cache[path] as PackedScene).instantiate()
		_enable_vertex_color(result)
		return result
	return _fallback(kind)

func _enable_vertex_color(n: Node) -> void:
	if n is MeshInstance3D:
		for index in range(n.mesh.get_surface_count()):
			var mat=n.get_active_material(index)
			if mat is BaseMaterial3D:
				mat.vertex_color_use_as_albedo=true
				mat.vertex_color_is_srgb=false
	for c in n.get_children(): _enable_vertex_color(c)

func _set_player_model() -> void:
	if is_instance_valid(player_model):
		player.remove_child(player_model)
		player_model.queue_free()
	player_model = model(["infantry","gunner","mech","mech"][tier])
	player.add_child(player_model)
	player_model.scale *= [2.15,1.68,0.92,0.92][tier]
	_set_player_shadow()

func _set_player_shadow() -> void:
	if not is_instance_valid(player_shadow_root):
		player_shadow_root=Node3D.new()
		player_shadow_root.name="PlayerShadow"
		add_child(player_shadow_root)
		player_directional_shadow=_add_blob(player_shadow_root,Vector2.ONE)
		player_directional_shadow.name="DirectionalShadow"
		player_directional_shadow.material_override.render_priority=-2
		player_contact_shadow=_add_blob(player_shadow_root,Vector2.ONE)
		player_contact_shadow.name="ContactShadow"
		player_contact_shadow.material_override.render_priority=-1
	var footprint:Dictionary=ShadowFootprints.DATA[["infantry","gunner","mech","mech"][tier]]
	var model_scale:float=player_model.scale.x
	player_directional_shadow.mesh.size=footprint.size*model_scale
	player_directional_shadow.position=Vector3(footprint.center.x*model_scale,0.018,footprint.center.y*model_scale)
	var directional:ShaderMaterial=player_directional_shadow.material_override
	directional.set_shader_parameter("use_texture",true)
	directional.set_shader_parameter("shadow_texture",footprint.texture)
	directional.set_shader_parameter("opacity",0.56)
	directional.set_shader_parameter("clip_to_road",true)
	player_contact_shadow.mesh.size=Vector2(1.05,0.82) if tier<2 else Vector2(1.50,1.12)
	player_contact_shadow.position=Vector3(0,0.024,0)
	player_contact_shadow.material_override.set_shader_parameter("clip_to_road",true)
	_update_player_shadow()

func _update_player_shadow() -> void:
	if not is_instance_valid(player_shadow_root): return
	# Ground shadows must never inherit recoil, steering lean or the model's bob.
	player_shadow_root.position=Vector3(player.position.x,0,player.position.z)
	player_directional_shadow.visible=effective_quality!="high"
	player_contact_shadow.material_override.set_shader_parameter("opacity",0.30 if effective_quality=="high" else 0.50)

func _update_recruit_shadow() -> void:
	if not is_instance_valid(recruit_shadow) or not is_instance_valid(recruit_flight): return
	var height:=maxf(0,recruit_flight.position.y)
	var ray:Vector3=-sun.global_basis.z
	var ground:Vector3=recruit_flight.position-ray*(height/ray.y)
	ground.y=0.020
	recruit_shadow.position=ground
	var body_width:=1.15 if pending_tier==1 else 2.1
	var width:=body_width*recruit_flight.scale.x+height*0.18
	recruit_shadow.mesh.size=Vector2(width,width*0.72)
	# At height the footprint spreads and fades; contact tightens on landing.
	recruit_shadow.material_override.set_shader_parameter("opacity",0.42/(1.0+height*0.20))
	recruit_shadow.visible=effective_quality!="high"

func _start_wave() -> void:
	for c in stage_root.get_children():
		stage_root.remove_child(c)
		c.queue_free()
	crowd_batches.clear()
	crowd_parts.clear()
	crowd.clear()
	boss_dead=false
	boss_death_time=0;boss_flash_time=0;boss_flash_cooldown=0
	boss_state="walk";boss_state_clock=0;boss_hit_cooldown=0;boss_next_attack=elapsed+5.0
	wave_clock=0
	boss_kind=Campaign.WAVES[wave].boss
	boss_max=float(Campaign.WAVES[wave].hp)
	boss_hp=boss_max
	boss_z=-18.8
	crowd_front=-12.0
	gold_hp=GOLD_ARMOR
	var pad := Node3D.new()
	stage_root.add_child(pad)
	pad.position=Vector3(2.9,0,-12.7)
	var padmat := material(Color("888b98") if tier==0 else Color("d8a839"),0.65,0.32)
	box(pad,Vector3(0,0.28,0),Vector3(4.55,0.55,4.3),padmat)
	box(pad,Vector3(0,0.62,-0.2),Vector3(4.35,0.15,3.7),material(Color("454a57"),0.45))
	box(pad,Vector3(0,0.6,2.15),Vector3(4.55,0.07,0.1),material(Color("d9dde5"),0.7))
	recruit_label = text3(pad,str(ceili(recruit_remaining)),Vector3(0,0.42,2.22),92,0.014)
	statue=Node3D.new()
	pad.add_child(statue)
	statue.position=Vector3(0,0.72,-0.4)
	_set_statue_model()
	boss=Node3D.new()
	stage_root.add_child(boss)
	boss.position=Vector3(-1.25 if boss_kind=="dragon" else -2.22,0,boss_z)
	boss_model=model(("brute_vest_animated" if wave==0 else "brute_animated") if boss_kind=="brute" else boss_kind)
	boss.add_child(boss_model)
	boss_model.rotation.y=PI
	boss_model.scale *= 1.48 if boss_kind=="dragon" else (1.95 if boss_kind=="skitter" else 1.8)
	boss_label=text3(boss,compact_number(boss_hp),Vector3(0,6.7,0),60,0.019)
	box(boss,Vector3(0,6.3,0),Vector3(3.9,0.24,0.14),material(Color("271b2b")))
	boss_bar=box(boss,Vector3(0,6.31,0.1),Vector3(3.7,0.15,0.08),material(Color("ef435f")))
	boss_anim=boss_model.get_node_or_null("AnimationPlayer")
	if boss_anim:
		boss_anim.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		boss_anim.get_animation("walk").loop_mode=Animation.LOOP_LINEAR
		boss_anim.play("walk")
		boss_anim.advance(0)
	var flash_shader:Shader=preload("res://assets/shaders/boss_flash.gdshader")
	boss_flash_mat=ShaderMaterial.new();boss_flash_mat.shader=flash_shader
	_override_material(boss_model,boss_flash_mat)
	# Retain a non-rendering marker for tools that inspect hit feedback.
	boss_flash=Node3D.new();boss.add_child(boss_flash);boss_flash.visible=false
	_add_blob(boss,Vector2(3.5,2.3))
	_batch_boxes(pad)
	_build_crowd()
	encounters.start(self)

func _set_statue_model() -> void:
	for c in statue.get_children():
		statue.remove_child(c)
		c.queue_free()
	statue.visible=tier<3
	if tier>=3: return
	var m := model("gunner" if tier==0 else "mech")
	statue.add_child(m)
	m.rotation.y=PI-0.16
	m.scale *= 3.85 if tier==0 else 1.82
	var shell=m.duplicate()
	statue.add_child(shell)
	shell.scale*=1.008
	var shader:Shader=preload("res://assets/shaders/statue_shell.gdshader")
	statue_shell=ShaderMaterial.new()
	statue_shell.shader=shader
	statue_shell.set_shader_parameter("shell_color",Color("b4b8c2") if tier==0 else Color("ffc234"))
	_override_material(shell,statue_shell)
	_update_statue_shell()

func _override_material(n: Node, mat: Material) -> void:
	if n is MeshInstance3D: n.material_override=mat
	for c in n.get_children(): _override_material(c,mat)

func _update_statue_shell() -> void:
	if not statue_shell or tier>=3: return
	var ratio:=clampf(float(recruit_remaining)/RECRUIT_COSTS[tier],0,1)
	statue_shell.set_shader_parameter("reveal_y",0.7+(6.40 if tier==0 else 5.85)*ratio)

func _begin_recruit_flight() -> void:
	recruiting=true;flight_clock=0
	recruit_flight=model("gunner" if pending_tier==1 else "mech")
	add_child(recruit_flight)
	flight_start=statue.global_position
	flight_scale=3.85 if pending_tier==1 else 1.82
	recruit_flight.position=flight_start
	recruit_flight.scale=Vector3.ONE*flight_scale
	recruit_flight.rotation.y=PI
	recruit_shadow=_add_blob(self,Vector2.ONE)
	recruit_shadow.name="RecruitShadow"
	recruit_shadow.material_override.set_shader_parameter("clip_to_road",true)
	_update_recruit_shadow()
	statue.visible=false

func _step_upgrade(delta: float) -> void:
	if not recruiting: return
	flight_clock+=delta
	var t:=minf(1,flight_clock/0.85)
	var destination:=Vector3(player.position.x,0,player.position.z)
	recruit_flight.position=flight_start.lerp(destination,t)+Vector3(0,sin(t*PI)*5,0)
	recruit_flight.scale=Vector3.ONE*lerpf(flight_scale,1.68 if pending_tier==1 else 0.92,t)
	recruit_flight.rotation.y=PI*(1-t)
	_update_recruit_shadow()
	if t>=1:
		recruiting=false
		tier=pending_tier;pending_tier=-1
		recruit_flight.queue_free()
		recruit_flight=null
		recruit_shadow.queue_free()
		recruit_shadow=null
		_set_player_model()
		if squad: squad.rebuild()
		recruit_remaining=float(RECRUIT_COSTS[tier]) if tier<3 else 0.0
		upgrade_flash=0.8;shake=0.28
		_emit(player.position+Vector3(0,0.6,0),Color("ffdd52"),70,0.12)
		_sound(upgrade_audio,-15)
		message="SQUAD UPGRADED";message_time=1.6
		_set_statue_model()
		statue_rise=0.0
		recruit_label.text=str(ceili(recruit_remaining)) if tier<3 else "MAX"

func _collect_meshes(n: Node3D, relative: Transform3D, output: Array) -> void:
	var t := relative*n.transform
	if n is MeshInstance3D:
		output.append({"mesh":n.mesh,"mat":n.material_override,"transform":t})
	for child in n.get_children():
		if child is Node3D: _collect_meshes(child,t,output)

func _build_crowd() -> void:
	for row in range(34):
		for col in range(16):
			crowd.append({"x":-4.78+col*0.341+rng.randf_range(-0.025,0.025),"z":row*0.43,"alive":true,"phase":rng.randf()*TAU,"hp":float(Campaign.WAVES[wave].troop_hp),"id":row*16+col})
	var shader:Shader=preload("res://assets/shaders/crowd.gdshader")
	crowd_shader=ShaderMaterial.new();crowd_shader.shader=shader
	for lod in ["near","mid","far"]:
		var proto:Node3D=(load("res://assets/mobile/zombie_"+lod+".glb") as PackedScene).instantiate()
		var parts:Array=[]
		_collect_meshes(proto,Transform3D.IDENTITY,parts)
		var part:Dictionary=parts[0]
		var instance:=MultiMeshInstance3D.new()
		var mm:=MultiMesh.new()
		mm.transform_format=MultiMesh.TRANSFORM_3D
		# Compatibility binds custom-only data as color on some drivers; explicit white is required.
		mm.use_colors=true
		mm.use_custom_data=true
		mm.mesh=part.mesh
		mm.custom_aabb=AABB(Vector3(-5.2,-0.1,-15.0),Vector3(5.9,1.3,16.0))
		mm.instance_count=crowd.size()
		mm.visible_instance_count=0
		instance.multimesh=mm
		instance.material_override=crowd_shader
		instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		stage_root.add_child(instance)
		crowd_batches.append(instance)
		crowd_parts.append(part.transform)
		proto.free()
	if is_instance_valid(death_mm): death_mm.queue_free()
	death_mm=MultiMeshInstance3D.new()
	var death_multi:=MultiMesh.new()
	death_multi.transform_format=MultiMesh.TRANSFORM_3D
	death_multi.use_colors=true
	death_multi.mesh=crowd_batches[1].multimesh.mesh
	death_multi.instance_count=128
	death_multi.visible_instance_count=0
	death_mm.multimesh=death_multi
	var death_shader:Shader=preload("res://assets/shaders/death_flash.gdshader")
	var death_mat:=ShaderMaterial.new();death_mat.shader=death_shader
	death_mm.material_override=death_mat
	death_mm.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(death_mm)
	crowd_dirty=true
	_update_crowd_visual()

func _update_crowd_visual() -> void:
	# Formation motion is three node transforms; individual transforms stay on the GPU.
	for batch in crowd_batches: batch.position.z=crowd_front
	if crowd_shader: crowd_shader.set_shader_parameter("clock",sim_time)
	if not crowd_dirty: return
	crowd_dirty=false
	for j in range(3):
		var data:=PackedFloat32Array()
		var count:=0
		for c in crowd:
			if not c.alive: continue
			var world_z:float=crowd_front-c.z
			var lod:int=0 if world_z> -16.0 else (1 if world_z> -22.0 else 2)
			if effective_quality=="high": lod=maxi(0,lod-1)
			if effective_quality=="battery": lod=mini(2,lod+1)
			if lod!=j: continue
			var t:=Transform3D(Basis(Vector3.UP,PI).scaled(Vector3.ONE*1.10),Vector3(c.x,0,-c.z))*crowd_parts[j]
			data.append_array(PackedFloat32Array([t.basis.x.x,t.basis.y.x,t.basis.z.x,t.origin.x,t.basis.x.y,t.basis.y.y,t.basis.z.y,t.origin.y,t.basis.x.z,t.basis.y.z,t.basis.z.z,t.origin.z,1,1,1,1,c.phase,0,0,0]))
			count+=1
		data.resize(crowd.size()*20)
		crowd_batches[j].multimesh.buffer=data
		crowd_batches[j].multimesh.visible_instance_count=count

func _build_projectiles() -> void:
	spray.setup(self)
	bullet_mm=spray.batch
	spark_mm=_new_batch(384,Color.WHITE,true)

func _new_batch(count: int, color: Color, cubic: bool) -> MultiMeshInstance3D:
	var n:=MultiMeshInstance3D.new()
	var mm:=MultiMesh.new()
	mm.transform_format=MultiMesh.TRANSFORM_3D
	mm.use_colors=true
	if cubic:
		var mesh:=BoxMesh.new()
		mesh.size=Vector3.ONE
		mm.mesh=mesh
	else:
		var mesh:=QuadMesh.new()
		mesh.size=Vector2.ONE
		mm.mesh=mesh
	mm.instance_count=count
	mm.visible_instance_count=0
	n.multimesh=mm
	var mat:=material(color,0.15,0.35)
	mat.vertex_color_use_as_albedo=true
	mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	n.material_override=mat
	if not cubic:
		var trail:=ShaderMaterial.new();trail.shader=preload("res://assets/shaders/projectile_trail.gdshader");n.material_override=trail
	n.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(n)
	return n

func _build_audio() -> void:
	sfx=AudioStreamPlayer.new()
	add_child(sfx)
	sfx.volume_db=-20
	shot_audio=_tone(0.045,360,95,0.18)
	hit_audio=_tone(0.08,130,40,0.2)
	upgrade_audio=_tone(0.45,500,1250,0.15)

func _tone(duration: float, f1: float, f2: float, noise: float) -> AudioStreamWAV:
	var a:=AudioStreamWAV.new()
	a.format=AudioStreamWAV.FORMAT_16_BITS
	a.mix_rate=22050
	var bytes:=PackedByteArray()
	bytes.resize(int(duration*22050)*2)
	var angle:=0.0
	for i in range(bytes.size()/2):
		var t:=float(i)/(bytes.size()/2)
		angle+=TAU*lerpf(f1,f2,t)/22050.0
		var v:float=(sin(angle)*(1.0-noise)+visual_rng.randf_range(-1,1)*noise)*pow(1.0-t,2)*0.65
		bytes.encode_s16(i*2,int(v*32760))
	a.data=bytes
	return a

func _sound(a: AudioStreamWAV, volume: float=-20.0) -> void:
	if not audio_enabled: return
	if a==shot_audio and sfx.playing: return
	sfx.stream=a
	sfx.volume_db=volume
	sfx.play()

func start_game() -> void:
	if phase in ["won","lost"]: restart_game(); return
	phase="playing"
	message="DRAG TO AIM • FIRE IS AUTOMATIC"
	message_time=3.0

func restart_game() -> void:
	phase="playing"
	rng.seed=812876
	visual_dirty=true
	dragging=false; touch_id=-1
	for key in metrics: metrics[key]=0
	wave=0; tier=0; pending_tier=-1;recruit_remaining=60.0;weapon_mode="rifle"
	elapsed=0; sim_time=0; shot_clock=0
	player_x=-1.8; target_x=-1.8
	kills=0; health=100; gold_hp=GOLD_ARMOR
	combat.reset();spray.reset()
	bullets.clear(); sparks.clear(); floats.clear();arcs.clear()
	message="DRAG TO AIM • FIRE IS AUTOMATIC"; message_time=3.0
	upgrade_flash=0; shake=0
	deferred_clear=false;recruiting=false
	if is_instance_valid(recruit_flight): recruit_flight.queue_free()
	recruit_flight=null
	if is_instance_valid(recruit_shadow): recruit_shadow.queue_free()
	recruit_shadow=null
	kill_flashes.clear()
	player.position=Vector3(player_x,0,PLAYER_Z)
	_set_player_model()
	if squad: squad.reset()
	_reset_recruit_lane()
	_start_wave()

func toggle_pause() -> void:
	if phase=="playing": phase="paused"; dragging=false; touch_id=-1
	elif phase=="paused": phase="playing"

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_ESCAPE,KEY_P]: toggle_pause()
		if event.keycode>=KEY_1 and event.keycode<=KEY_5: select_weapon(Campaign.WEAPONS[event.keycode-KEY_1])
		if event.keycode==KEY_R: restart_game()
		if event.keycode==KEY_SPACE and phase!="playing": start_game()
	if phase!="playing": return
	if event is InputEventScreenTouch:
		if event.pressed and touch_id==-1:
			touch_id=event.index; dragging=true; _aim(event.position)
		elif event.index==touch_id:
			touch_id=-1; dragging=false
	elif event is InputEventScreenDrag and event.index==touch_id: _aim(event.position)
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		dragging=event.pressed
		if dragging: _aim(event.position)
	elif event is InputEventMouseMotion and dragging and touch_id==-1: _aim(event.position)

func _aim(screen: Vector2) -> void:
	var origin:=camera.project_ray_origin(screen)
	var normal:=camera.project_ray_normal(screen)
	if absf(normal.z)>0.01:
		var hit:=origin+normal*((PLAYER_Z-origin.z)/normal.z)
		target_x=clampf(hit.x,-4.55,4.55)

func _notification(what: int) -> void:
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT and phase=="playing" and not auto_demo and not qa_mode:
		toggle_pause()

func _physics_process(delta: float) -> void:
	if phase!="playing": return
	_step(delta)

func _step(delta: float) -> void:
	elapsed+=delta
	wave_clock+=delta
	sim_time+=delta
	message_time=maxf(0,message_time-delta)
	upgrade_flash=maxf(0,upgrade_flash-delta*1.5)
	shake=move_toward(shake,0,delta*2)
	if auto_demo: _demo_input()
	else:
		var axis:=float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))-float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
		if axis!=0: target_x=clampf(target_x+axis*7.0*delta,-4.55,4.55)
	player_x=move_toward(player_x,target_x,11.5*delta)
	if squad:
		player_x=clampf(player_x,-squad.center_limit(),squad.center_limit())
		squad.update_visuals()
	else: player.position=Vector3(player_x,0,PLAYER_Z)
	var bank:float=clampf((target_x-player_x)*-0.07,-0.14,0.14)
	if squad.members.size()>1 and absf(player.position.x)>3.8: bank=0.0
	player_model.rotation.z=lerpf(player_model.rotation.z,bank,delta*12)
	player_model.rotation.x=sin(sim_time*(26 if tier else 13))*0.015
	_update_player_shadow()
	_update_gates()
	_step_upgrade(delta)
	if not recruiting and statue_rise<1:
		statue_rise=minf(1,statue_rise+delta*1.8)
		statue.position.y=lerpf(-5.0,0.72,1-pow(1-statue_rise,3))
	_step_recruit_lane(delta)
	if squad: squad.step(delta)
	camera.position.x=player_x*0.055+sin(sim_time*93)*shake*0.025
	_step_bullets(delta)
	_step_enemies(delta)
	encounters.step(delta)
	if health<=0 and phase=="playing":
		phase="lost";metrics.losses+=1;dragging=false;deferred_clear=false
	_step_effects(delta)
	crowd_lod_clock+=delta
	if crowd_lod_clock>=0.25:
		crowd_lod_clock=0;crowd_dirty=true
	_update_crowd_visual()
	metrics.peak_packets=maxi(metrics.peak_packets,bullets.size())
	if deferred_clear and phase=="playing":
		deferred_clear=false
		_clear_wave()

func _demo_input() -> void:
	# Test-only controller uses the same input targets and combat as normal play.
	if squad.members.size()<mini(36,8+wave*4) and fmod(wave_clock,10.0)<6.5: target_x=4.55
	elif tier<3 and fmod(wave_clock,15.0)<5.0: target_x=2.8
	else: target_x=-2.5+1.75*sin(wave_clock*0.7)
	if wave>=4: select_weapon("arc" if fmod(wave_clock,16)<8 else "rail")
	elif wave>=3: select_weapon("rocket")
	elif wave>=2: select_weapon("rail")
	elif wave>=1: select_weapon("scatter")

func _fire() -> void:
	fire_member(0)

func _step_bullets(delta: float) -> void:
	# Legacy helper entry point; only bounded coverage fields do combat work.
	combat.step(delta)
	metrics.peak_fields=maxi(metrics.peak_fields,combat.peak_fields)

func _damage_recruit(damage: float) -> void:
	if tier>=3 or recruiting or damage<=0: return
	recruit_remaining=maxf(0,recruit_remaining-damage)
	recruit_label.text=str(ceili(recruit_remaining))
	_update_statue_shell()
	statue.rotation.z=sin(sim_time*73)*0.016
	_emit(statue.global_position+Vector3(0,1.5,0),Color("ccd2dc") if tier==0 else Color("ffcd3c"),3,0.12)
	if recruit_remaining<=0:
		pending_tier=tier+1
		metrics.recruits+=1
		_begin_recruit_flight()

func _damage_crowd(x: float, radius: float, damage: float, previous_z: float, current_z: float) -> int:
	last_crowd_absorbed=0.0
	if damage<=0: return 0
	var hits:=0
	# Fixed formation grid gives bounded swept-row candidates, independent of quality.
	var first:=clampi(floori((crowd_front-previous_z-0.12)/0.43),0,33)
	var last:=clampi(ceili((crowd_front-current_z+0.12)/0.43),0,33)
	for row in range(first,last+1):
		for col in range(16):
			var c:Dictionary=crowd[row*16+col]
			if not c.alive or absf(c.x-x)>=radius or crowd_front-c.z>previous_z+0.12 or crowd_front-c.z<current_z-0.12: continue
			var absorbed:=minf(c.hp,damage-last_crowd_absorbed)
			c.hp-=absorbed;last_crowd_absorbed+=absorbed;metrics.damage+=absorbed
			if c.hp<=0:
				c.alive=false;hits+=1;kills+=1;crowd_dirty=true
				if kill_flashes.size()<death_cap: kill_flashes.append({"x":c.x,"z":crowd_front-c.z,"life":0.26})
			if last_crowd_absorbed>=damage-0.00001: return hits
	return hits

func _damage_boss(damage: float) -> void:
	if boss_dead: return
	var applied:=minf(boss_hp,maxf(0,damage))
	boss_hp-=applied
	metrics.damage+=applied
	boss_label.text=compact_number(boss_hp)
	boss_bar.scale.x=maxf(0.001,boss_hp/boss_max)
	_emit(boss.position+Vector3(visual_rng.randf_range(-1,1),2,0.7),Color("fff4de"),8,0.13)
	if boss_flash_cooldown<=0:
		boss_flash_time=0.055;boss_flash_cooldown=0.14
	if boss_hit_cooldown<=0 and boss_state=="walk":
		_boss_play("hit")
		boss_hit_cooldown=0.8
	if boss_hp==0:
		boss_dead=true
		metrics.bosses+=1
		_boss_play("death")
		boss_death_time=1.7
		boss_flash_time=0.08
		shake=0.45
		_sound(hit_audio,-13)
		_emit(boss.position+Vector3(0,2,0),Color("f0b0a1"),100,0.16)

func _alive_crowd() -> int:
	var amount:=0
	for c in crowd:
		if c.alive: amount+=1
	return amount

func _step_enemies(delta: float) -> void:
	crowd_front+=delta*float(Campaign.WAVES[wave].speed)
	# Later siege bosses hold beyond the final multiplier and use telegraphed attacks.
	# Crossing ahead of a multiplier would otherwise remove almost all squad DPS.
	var approach_stop:float=GATE_Z[2]-2.2 if wave>=2 else PLAYER_Z-2.4
	if not boss_dead and boss_z<approach_stop:
		boss_z=minf(approach_stop,boss_z+delta*(0.52+wave*0.045))
	boss.position.z=boss_z
	boss_hit_cooldown=maxf(0,boss_hit_cooldown-delta)
	boss_state_clock+=delta
	if not boss_dead:
		if boss_state=="hit" and boss_state_clock>=0.30: _boss_play("walk")
		if boss_state=="attack" and boss_state_clock>=1.0: _boss_play("walk")
		if boss_state=="walk" and (elapsed>=boss_next_attack or boss_z>=PLAYER_Z-2.4):
			_boss_play("attack");boss_next_attack=elapsed+7.0
			encounters.warn(player_x,squad.hurtbox_position().z,1.5 if boss_kind=="dragon" else 1.0,14 if boss_kind=="dragon" else 10)
	if boss_anim: boss_anim.advance(delta)
	else: CreatureMotion.pose(boss_model,boss_kind,sim_time,sin(boss_state_clock*PI) if boss_state=="attack" else 0,clampf((1.7-boss_death_time)/1.7,0,1) if boss_dead else 0)
	# Surviving rows actually cross the defended runway; damage is never timer-only.
	for c in crowd:
		if c.alive and crowd_front-c.z>PLAYER_Z-1.5:
			c.alive=false;crowd_dirty=true
			health=maxf(0,health-3.0)
			metrics.breaches+=1
			shake=0.16
	boss_flash_cooldown=maxf(0,boss_flash_cooldown-delta)
	boss_flash_time=maxf(0,boss_flash_time-delta)
	boss_flash.visible=boss_flash_time>0
	boss_flash_mat.set_shader_parameter("flash",0.82 if boss_flash_time>0 else 0.0)
	if boss_dead and boss_death_time>0:
		boss_death_time=maxf(0,boss_death_time-delta)

		if boss_death_time<=0: boss.visible=false
	if not boss_dead and boss_z>=PLAYER_Z-2.4 and boss_state=="attack" and boss_state_clock>=0.64:
		health=maxf(0,health-delta*18)
		metrics.breaches+=1
	if health<=0:
		phase="lost"; metrics.losses+=1; dragging=false
		deferred_clear=false
		return
	if boss_dead and boss_death_time<=0 and _alive_crowd()==0 and encounters.settled() and not recruiting: deferred_clear=true

func _clear_wave() -> void:
	if phase!="playing": return
	metrics.wave_clears+=1
	if wave>=Campaign.WAVES.size()-1:
		phase="won"; metrics.wins+=1
		return
	wave+=1
	health=minf(100,health+25)
	combat.reset();spray.reset()
	bullets.clear();arcs.clear()
	message="WAVE %d • %s"%[wave+1,Campaign.WAVES[wave].name.to_upper()]
	message_time=2.5
	_start_wave()

func _emit(pos: Vector3, color: Color, count: int, size: float) -> void:
	for i in range(mini(count,12 if effective_quality!="high" else 40)):
		if sparks.size()>=spark_cap: break
		sparks.append({"pos":pos,"vel":Vector3(visual_rng.randf_range(-2.4,2.4),visual_rng.randf_range(1.5,4.4),visual_rng.randf_range(-2,2)),"life":visual_rng.randf_range(0.15,0.55),"color":color,"size":size})

func _step_effects(delta: float) -> void:
	for arc in arcs: arc.life-=delta
	arcs=arcs.filter(func(a):return a.life>0)
	var living:Array[Dictionary]=[]
	for s in sparks:
		s.life-=delta
		if s.life<=0: continue
		s.vel.y-=12.0*delta
		s.pos+=s.vel*delta
		living.append(s)
	sparks=living
	var dying:Array[Dictionary]=[]
	for f in kill_flashes:
		f.life-=delta
		if f.life>0: dying.append(f)
	kill_flashes=dying

func _process(_delta: float) -> void:
	if not is_instance_valid(bullet_mm): return
	_update_adaptive_quality(_delta)
	hud_clock+=_delta
	if is_instance_valid(hud) and (phase!=last_draw_phase or (phase=="playing" and hud_clock>=1.0/30.0)):
		hud.queue_redraw();hud_clock=0;last_draw_phase=phase
	if rendered_time==sim_time and not visual_dirty: return
	rendered_time=sim_time;visual_dirty=false
	spray.update(sim_time)
	_draw_arcs()
	var sm:=spark_mm.multimesh
	for i in range(sparks.size()):
		var s=sparks[i]
		var basis:=Basis(Vector3(0.3,0.7,0.2).normalized(),sim_time*8).scaled(Vector3.ONE*s.size*minf(1,s.life*6))
		sm.set_instance_transform(i,Transform3D(basis,s.pos))
		sm.set_instance_color(i,s.color)
	sm.visible_instance_count=sparks.size()
	if is_instance_valid(death_mm):
		for i in range(kill_flashes.size()):
			var f=kill_flashes[i]
			var t:=Transform3D(Basis(Vector3.UP,PI).scaled(Vector3.ONE*1.10),Vector3(f.x,0,f.z))
			death_mm.multimesh.set_instance_transform(i,t*crowd_parts[0])
			death_mm.multimesh.set_instance_color(i,Color(1,1,1,minf(1,f.life*6)))
		death_mm.multimesh.visible_instance_count=kill_flashes.size()
	if auto_demo and not screenshot_dir.is_empty():
		if next_capture<CAPTURE_TIMES.size() and elapsed>=CAPTURE_TIMES[next_capture]:
			_capture("time-%05.1f.png"%elapsed)
			next_capture+=1
		if elapsed>=36.0 or phase in ["won","lost"]:
			var f:=FileAccess.open(screenshot_dir+"/demo-metrics.json",FileAccess.WRITE)
			f.store_string(JSON.stringify({"metrics":metrics,"tier":tier,"wave":wave,"health":health,"elapsed":elapsed},"  "))
			get_tree().quit()

func _capture(filename: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(screenshot_dir+"/"+filename)

func _boss_play(clip: String) -> void:
	boss_state=clip;boss_state_clock=0.0
	if boss_anim:
		boss_anim.play(clip,0.08 if clip!="death" else 0.04)
		boss_anim.advance(0)

func _batch_boxes(parent: Node3D, excluded: Array = []) -> void:
	var groups:Dictionary={}
	for child in parent.get_children():
		if child is MeshInstance3D and child.mesh is BoxMesh and child not in excluded:
			var key:int=child.material_override.get_instance_id()
			if not groups.has(key): groups[key]=[]
			groups[key].append(child)
	for group in groups.values():
		_batch_mesh_list(group,parent)
		for child in group:
			parent.remove_child(child);child.queue_free()

func _batch_mesh_list(items: Array, parent: Node3D) -> MultiMeshInstance3D:
	var batch:=MultiMeshInstance3D.new()
	var mm:=MultiMesh.new()
	mm.transform_format=MultiMesh.TRANSFORM_3D
	var unit:=BoxMesh.new();unit.size=Vector3.ONE
	mm.mesh=unit;mm.instance_count=items.size()
	for i in range(items.size()):
		var source:MeshInstance3D=items[items.size()-1-i]
		var t:Transform3D=source.transform
		t.basis=t.basis.scaled(source.mesh.size)
		mm.set_instance_transform(i,t)
	batch.multimesh=mm
	batch.material_override=items[0].material_override
	parent.add_child(batch)
	return batch

func _add_blob(parent: Node3D, footprint: Vector2) -> MeshInstance3D:
	var blob:=MeshInstance3D.new()
	var plane:=PlaneMesh.new();plane.size=footprint
	blob.mesh=plane;blob.position.y=0.027
	var sh:Shader=preload("res://assets/shaders/contact_shadow.gdshader")
	var mat:=ShaderMaterial.new();mat.shader=sh;blob.material_override=mat
	blob.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(blob)
	return blob

func set_quality(requested: String) -> void:
	if requested not in ["auto","low","high","battery"]: return
	quality_mode=requested
	effective_quality="low" if requested=="auto" else requested
	_apply_quality()

func _apply_quality() -> void:
	var high:=effective_quality=="high"
	var battery:=effective_quality=="battery"
	visual_bullet_cap=1600 if high else (512 if battery else 900)
	per_packet_cap=50 if high else (12 if battery else 18)
	spray.set_budget(visual_bullet_cap)
	spark_cap=384 if high else (48 if battery else 96)
	death_cap=128 if high else (16 if battery else 32)
	if sparks.size()>spark_cap: sparks.resize(spark_cap)
	if kill_flashes.size()>death_cap: kill_flashes.resize(death_cap)
	sun.shadow_enabled=high
	if squad: squad.update_visuals()
	_update_player_shadow()
	_update_recruit_shadow()
	# Keep a comparable exposure in Compatibility's shadowless lighting path.
	var lighting_factor:=1.0 if high else 2.0
	sun.light_energy=0.88*lighting_factor
	fill.light_energy=0.18*lighting_factor
	world_environment.ambient_light_energy=0.32*lighting_factor
	get_viewport().msaa_3d=Viewport.MSAA_2X
	Engine.max_fps=60 if high else 30
	_update_resolution()
	crowd_dirty=true;visual_dirty=true
	slow_frame_time=0
	if is_instance_valid(hud): hud.queue_redraw()

func _update_resolution() -> void:
	# Bound physical pixels even when a browser reports a high device pixel ratio.
	var viewport_size:Vector2=get_viewport().get_visible_rect().size
	var physical_size:Vector2=viewport_size*get_viewport().get_stretch_transform().get_scale()
	var budget:=1600.0 if effective_quality=="high" else 1280.0
	get_viewport().scaling_3d_mode=Viewport.SCALING_3D_MODE_BILINEAR
	get_viewport().scaling_3d_scale=clampf(budget/maxf(physical_size.x,physical_size.y),0.1,1.0)

func _update_adaptive_quality(delta: float) -> void:
	if quality_mode!="auto" or phase!="playing" or elapsed<3 or qa_mode: return
	# Use frame duration rather than capped FPS, and ignore single loading spikes.
	if delta>0.040 and delta<0.25: slow_frame_time+=delta
	else: slow_frame_time=maxf(0,slow_frame_time-delta*0.5)
	if slow_frame_time>=2.0 and effective_quality!="battery":
		effective_quality="battery";_apply_quality()

func cycle_quality() -> void:
	var choices:=["auto","low","high"]
	set_quality(choices[(choices.find(quality_mode)+1)%choices.size()])

func _warm_graphics() -> void:
	if DisplayServer.get_name()=="headless":
		render_warmup_done=true
		return
	# Draw the actual later-hero and effect variants below the floor during the menu.
	# Visibility=false or off-frustum proxies would not warm Compatibility pipelines.
	var warm:=Node3D.new();warm.name="GraphicsWarmup";add_child(warm)
	warm.position=Vector3(0,-0.25,0)
	warm.scale=Vector3.ONE*0.01
	var warning:MeshInstance3D=encounters.warning_visual();warm.add_child(warning)
	# First fire also emits an instanced unshaded spark. Warm every real effect
	# pipeline, since the trail shader alone cannot prepare that material variant.
	for source in [spark_mm,arc_mm]:
		var shot_proxy:=MultiMeshInstance3D.new();var shot_batch:=MultiMesh.new()
		shot_batch.transform_format=MultiMesh.TRANSFORM_3D;shot_batch.use_colors=true
		shot_batch.mesh=source.multimesh.mesh;shot_batch.instance_count=1
		shot_batch.set_instance_transform(0,Transform3D.IDENTITY);shot_batch.set_instance_color(0,Color.CYAN)
		shot_proxy.multimesh=shot_batch;shot_proxy.material_override=source.material_override
		shot_proxy.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;warm.add_child(shot_proxy)
	warm.add_child(spray.warm_proxy())
	var hero:=model("mech");warm.add_child(hero)
	for kind in ["gunner","dragon","golem","skitter"]:
		var proxy:=model(kind);warm.add_child(proxy)
		if kind in ["dragon","golem","skitter"]:
			var hit_proxy:=proxy.duplicate();warm.add_child(hit_proxy)
			_override_material(hit_proxy,boss_flash_mat)
	# Followers use an instanced shader variant; drawing a lone hero is not enough.
	for kind in ["gunner","mech"]:
		var prototype:=model(kind);var parts:Array=[]
		_collect_meshes(prototype,Transform3D.IDENTITY,parts)
		for part in parts:
			var follower:=MultiMeshInstance3D.new();var instances:=MultiMesh.new()
			instances.transform_format=MultiMesh.TRANSFORM_3D
			instances.mesh=part.mesh;instances.instance_count=1
			instances.set_instance_transform(0,part.transform)
			follower.multimesh=instances;follower.material_override=part.mat
			warm.add_child(follower)
		prototype.free()
	for size in [60,92]: text3(warm,"0123456789.KM",Vector3.ZERO,size)
	var shell:=hero.duplicate();warm.add_child(shell)
	var shell_mat:=ShaderMaterial.new();shell_mat.shader=preload("res://assets/shaders/statue_shell.gdshader")
	_override_material(shell,shell_mat)
	var effect:=MultiMeshInstance3D.new()
	var mm:=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_colors=true
	mm.mesh=death_mm.multimesh.mesh;mm.instance_count=1
	mm.set_instance_transform(0,Transform3D.IDENTITY);mm.set_instance_color(0,Color.WHITE)
	effect.multimesh=mm;effect.material_override=death_mm.material_override
	effect.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	warm.add_child(effect)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	warm.queue_free()
	render_warmup_done=true

func select_weapon(mode: String) -> bool:
	if mode not in Campaign.WEAPONS or wave<int(Campaign.WEAPON_UNLOCK_WAVE[mode]): return false
	if weapon_mode==mode: return true
	weapon_mode=mode
	message=Campaign.WEAPON_NAMES[mode];message_time=1.25
	if is_instance_valid(hud): hud.queue_redraw()
	return true

func fire_member(index: int) -> void:
	if not squad or index>=squad.members.size(): return
	var origin:Vector3=squad.muzzle(index)
	var mode:=weapon_mode
	var pellets:=5 if mode=="scatter" else 1
	combat.enqueue(origin,mode,tier,pellets)
	spray.emit_shot(origin,projectile_aim(origin),mode,tier)
	metrics.shots+=pellets
	if index==0: _sound(shot_audio,-25 if tier else -22)
	if index%3==0: _emit(origin,Campaign.weapon_color(mode,tier),1,0.08)

func area_damage(center: Vector3, radius: float, amount: float, excluded_id: int=-999) -> void:
	if amount<=0: return
	for c in crowd:
		if not c.alive or c.id==excluded_id: continue
		if Vector2(c.x-center.x,crowd_front-c.z-center.z).length()<=radius:
			var applied:=minf(c.hp,amount);c.hp-=applied;metrics.damage+=applied;metrics.splash_hits+=1
			if c.hp<=0: c.alive=false;kills+=1;crowd_dirty=true
	for enemy in encounters.enemies:
		if enemy.alive and enemy.id!=excluded_id and Vector2(enemy.node.position.x-center.x,enemy.node.position.z-center.z).length()<=radius:
			encounters.damage(enemy,amount,"rocket");metrics.splash_hits+=1
	if excluded_id!=-2 and not boss_dead and Vector2(boss.position.x-center.x,boss_z-center.z).length()<=radius+0.65: _damage_boss(amount)
	_emit(center,Color("ffb756"),20,0.24)

func chain_damage(origin: Vector3, amount: float, excluded_id: int) -> void:
	var used:Array[int]=[excluded_id]
	var start:=origin
	for link in range(5):
		var nearest:Dictionary={};var distance:=3.2
		for c in crowd:
			if not c.alive or c.id in used: continue
			var position:=Vector3(c.x,0.55,crowd_front-c.z)
			var d:float=Vector2(position.x-start.x,position.z-start.z).length()
			if d<distance: distance=d;nearest={"kind":"troop","target":c,"id":c.id,"position":position}
		for enemy in encounters.enemies:
			if not enemy.alive or enemy.id in used: continue
			var d:float=Vector2(enemy.node.position.x-start.x,enemy.node.position.z-start.z).length()
			if d<distance: distance=d;nearest={"kind":"elite","target":enemy,"id":enemy.id,"position":enemy.node.position+Vector3(0,1.0,0)}
		if not boss_dead and -2 not in used:
			var d:float=Vector2(boss.position.x-start.x,boss_z-start.z).length()
			if d<distance: nearest={"kind":"boss","id":-2,"position":boss.position+Vector3(0,2,0)}
		if nearest.is_empty(): break
		var power:float=amount*pow(0.72,link+1)
		if nearest.kind=="troop":
			var c:Dictionary=nearest.target;var applied:=minf(c.hp,power);c.hp-=applied;metrics.damage+=applied
			if c.hp<=0: c.alive=false;kills+=1;crowd_dirty=true
		elif nearest.kind=="elite": encounters.damage(nearest.target,power,"arc")
		else: _damage_boss(power)
		if arcs.size()<160: arcs.append({"from":start,"to":nearest.position,"life":0.20})
		used.append(nearest.id);start=nearest.position;metrics.chain_hits+=1

func _draw_arcs() -> void:
	if not is_instance_valid(arc_mm): return
	for i in range(mini(160,arcs.size())):
		var arc:Dictionary=arcs[i];var vector:Vector3=arc.to-arc.from
		var basis:=Basis.looking_at(vector.normalized() if vector.length()>0.001 else Vector3.FORWARD,Vector3.UP)
		basis=basis.scaled(Vector3(0.045,0.045,maxf(0.01,vector.length())))
		arc_mm.multimesh.set_instance_transform(i,Transform3D(basis,(arc.from+arc.to)*0.5))
		arc_mm.multimesh.set_instance_color(i,Color("b4eeff"))
	arc_mm.multimesh.visible_instance_count=mini(160,arcs.size())

func _build_recruit_lane() -> void:
	lane_root=Node3D.new();lane_root.name="RecruitLane";add_child(lane_root)
	var base:=material(Color("1e7ccc"),0.3,0.38)
	box(lane_root,Vector3(4.63,0.035,-3.6),Vector3(0.75,0.06,19.5),base)
	var edge:=material(Color("8edbff"),0.25,0.30)
	box(lane_root,Vector3(4.2,0.06,-3.6),Vector3(0.055,0.06,19.5),edge)
	for i in range(8):
		var card:=Node3D.new();lane_root.add_child(card)
		box(card,Vector3(0,0.70,0),Vector3(0.98,1.30,0.22),base)
		var label:=text3(card,"+1",Vector3(0,0.70,0.13),52,0.017)
		_batch_boxes(card)
		lane_cards.append({"node":card,"label":label,"z":float(5.9-i*2.5),"claimed":false,"id":i})
	lane_serial=8
	lane_label=text3(lane_root,"RECRUIT",Vector3(4.1,0.10,8.0),25,0.014)
	_reset_recruit_lane()

func _reset_recruit_lane() -> void:
	for i in range(lane_cards.size()):
		lane_cards[i].z=5.9-i*2.5;lane_cards[i].claimed=false;lane_cards[i].id=i
		lane_cards[i].node.show();lane_cards[i].node.position=Vector3(4.63,0,lane_cards[i].z)
		lane_cards[i].label.text="+1";lane_cards[i].label.font_size=52
	lane_label.text="RECRUIT"
	lane_serial=lane_cards.size()

func _step_recruit_lane(delta: float) -> void:
	for card in lane_cards:
		card.z+=delta*2.8
		if card.z>=PLAYER_Z+0.4 and not card.claimed:
			card.claimed=true
			if squad.right_edge()>3.7 and squad.add_member():
				_emit(Vector3(4.3,0.6,PLAYER_Z),Color("ffed76"),12,0.14)
				message="+1 SOLDIER • %d / %d"%[squad.members.size(),Campaign.MAX_SQUAD];message_time=0.8
			card.node.hide()
		if card.z>PLAYER_Z+2.0:
			card.z-=20.0;card.claimed=false;card.id=lane_serial;lane_serial+=1;card.node.show()
		card.node.position=Vector3(4.63,0,card.z)
		card.label.text="+1"
		card.node.visible=not card.claimed and squad.members.size()<Campaign.MAX_SQUAD
	lane_label.text="RECRUIT" if squad.members.size()<Campaign.MAX_SQUAD else "SQUAD FULL"

func _build_city() -> void:
	var near:=material(Color("1e568b"),0.1,0.86)
	var far:=material(Color("28679c"),0.1,0.95)
	var roof:=material(Color("3278a6"),0.1,0.8)
	var windows:=material(Color("7ab6d2"),0.1,0.6)
	for side in [-1,1]:
		for i in range(22):
			var x:float=side*(9.5+(i%3)*5.2);var z:float=13-i*3.9
			var height:float=5.0+fposmod(i*7.31,13.0)
			box(self,Vector3(x,-15+height*.5,z),Vector3(3.5,height,3.2),near if i%3==0 else far)
			box(self,Vector3(x,-15+height+.12,z),Vector3(3.65,.24,3.35),roof)
			for floor_index in range(4):
				var y:float=-15+height-1.2-floor_index*1.35
				for column in range(3):
					box(self,Vector3(x-side*1.76,y,z+(column-1)*.80),Vector3(.045,.38,.42),windows)
					box(self,Vector3(x+(column-1)*.85,y,z+1.62),Vector3(.45,.38,.045),windows)
			if i%2==0:
				box(self,Vector3(x-.6,-15+height+.56,z-.3),Vector3(1.2,.8,1.3),near)
				box(self,Vector3(x+.8,-15+height+.25,z+.6),Vector3(.65,.5,.72),roof)

func compact_number(value: float) -> String:
	if value>=1000000: return ("%.1fM"%(value/1000000.0)).replace(".0M","M")
	if value>=10000: return ("%.1fK"%(value/1000.0)).replace(".0K","K")
	return str(ceili(value))

func projectile_aim(origin: Vector3) -> Vector3:
	if origin.x>0.65 and tier<3 and not recruiting and origin.z> -10.4: return Vector3(origin.x,2.0,-10.4)
	var aim:=Vector3(origin.x,0.6,-45)
	# Cosmetic aim queries only neighboring formation columns, front row first.
	var first:=clampi(floori((origin.x-0.43+4.78)/0.341),0,15)
	var last:=clampi(ceili((origin.x+0.43+4.78)/0.341),0,15)
	for col in range(first,last+1):
		for row in range(34):
			var c:Dictionary=crowd[row*16+col]
			var z:float=crowd_front-c.z
			if c.alive and absf(c.x-origin.x)<0.40 and z<origin.z:
				if z>aim.z: aim=Vector3(origin.x,0.55,z)
				break
	if not boss_dead and absf(boss.position.x-origin.x)<2.2 and boss_z+1.1>aim.z and boss_z+1.1<origin.z:
		aim=Vector3(origin.x,3.2 if boss_kind=="dragon" else 1.8,boss_z+1.1)
	for enemy in encounters.enemies:
		var z:float=enemy.node.position.z+0.7
		if enemy.alive and absf(enemy.node.position.x-origin.x)<0.82 and z>aim.z and z<origin.z:
			aim=Vector3(origin.x,2.0 if enemy.kind=="drake" else 0.8,z)
	return aim
