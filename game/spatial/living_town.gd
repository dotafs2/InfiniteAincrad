extends "res://spatial/town_street.gd"
## The canonical town host, with opt-in saved spatial layout. Legacy saves keep their art.
const Quarter = preload("res://spatial/living_quarter.gd")
var quarter: Node3D
var review_camera: Camera3D
var review_layer: CanvasLayer
var report_dir := ""
var probe_running := false
var probe_targets: Dictionary = {}
var probe_results: Array = []
var probe_leg := ""
var probe_age := 0.0
var probe_finished: Dictionary = {}
var opening: Dictionary = {}

func _is_quarter() -> bool:
	return town.snapshot().get("godot",{}).get("spatial_layout",{}).get("id","") == "first-floor-market-quarter-v1"

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--quarter-report="): report_dir = arg.trim_prefix("--quarter-report=")
	super._ready()
	if quarter == null: return
	_player.collision_mask = 5
	for body in bodies.values(): body.collision_mask = 5
	var saved: Dictionary = town.snapshot().godot.spatial_layout
	for id in quarter.houses:
		quarter.houses[id].set_door_open(saved.get("doors",{}).get(id,false))
		quarter.houses[id].set_window_open(saved.get("windows",{}).get(id,false))
	latest = "第一层生活街区 · 空格继续/暂停 · E 门 · F 窗 · V 45°总览"
	if restore_only: latest = "第一层生活街区 · 只读游览，居民暂停 · V 总览/返回"
	_refresh()
	if not report_dir.is_empty():
		if not restore_only:
			push_error("Quarter inspection requires --town-restore; it never advances the world")
			get_tree().quit(2)
			return
		DirAccess.make_dir_recursive_absolute(report_dir)
		_review.call_deferred()

func _build_ground_collision() -> void:
	if not _is_quarter(): super._build_ground_collision()

func _build_environment() -> void:
	super._build_environment()
	if not _is_quarter(): return
	_environment.environment.ambient_light_energy = 0.48
	_environment.environment.tonemap_exposure = 0.88
	_environment.environment.ssao_enabled = true
	get_node("Sun").directional_shadow_max_distance = 230
	get_node("Sun").light_energy = 1.05

func _load_market_runtime() -> void:
	if not _is_quarter():
		super._load_market_runtime()
		return
	quarter = Quarter.new()
	quarter.name = "FirstFloorLivingQuarter"
	add_child(quarter)
	quarter.build()
	_market_loaded = quarter.houses.size() == 16

func _load_floor1_environment_dressing() -> void:
	if quarter == null: super._load_floor1_environment_dressing()

func _load_town_expansion() -> void:
	if quarter == null:
		super._load_town_expansion()
	else:
		town_expansion_evidence = {"layout":"first-floor-market-quarter-v1", "resident_houses":10,"infill_houses":6,"canonical_world":true}

func _configure_navigation() -> void:
	if quarter == null: return
	town_navigation.walkable_bounds = AABB(Vector3(-56,-1,-65),Vector3(112,20,169))
	town_navigation.bake_cell_size = 0.15
	town_navigation.bake_cell_height = 0.025
	town_navigation.bake_max_climb = 0.075
	town_navigation.dynamic_detours = true
	for id in quarter.houses:
		var house = quarter.houses[id]
		var door: Dictionary = house.door_opening_godot()
		var center: Vector3 = quarter.entrances[id]+Vector3.UP*.05
		town_navigation.door_portals.append({"center":center,"normal":house.global_basis*door.outward})

func _work_marker(point: Vector3, title: String) -> void:
	if quarter == null: super._work_marker(point,title)
	# Indoor room points are real targets. Avoid placing a floating work label on every floor.

func _physics_process(delta: float) -> void:
	if quarter != null:
		var movers: Array[CharacterBody3D] = []
		if not paused or probe_running:
			for resident_id in bodies:
				if probe_running or not town.pending_job(resident_id).is_empty(): movers.append(bodies[resident_id])
		for id in quarter.houses:
			if quarter.houses[id].is_door_open(): continue
			var door: Vector3 = quarter.entrances[id]
			var near := false
			for body in movers:
				if body.position.distance_to(door) < 2.3: near = true
			if near and not quarter.houses[id].is_door_open() and not opening.has(id):
				opening[id] = true
				_set_door.call_deferred(id,true)
	if probe_running:
		_tick_probe(delta)
		return
	super._physics_process(delta)

func _set_door(id: String, value: bool) -> void:
	opening.erase(id)
	if restore_only and report_dir.is_empty():
		latest = "当前为只读回看；门窗和存档保持原样。开启实时 AI 生活后才能改变世界。"
		_refresh()
		return
	if report_dir.is_empty():
		var result := town.transaction(_save_path, func():
			town._state.godot.spatial_layout.doors[id] = value
			return {"ok":true,"code":"spatial_door_changed"})
		if not result.ok:
			paused = true
			latest = "门状态保存失败，世界已暂停。"
			_refresh()
			return
	quarter.houses[id].set_door_open(value)

func _unhandled_input(event: InputEvent) -> void:
	if quarter != null and event is InputEventKey and event.pressed and not event.echo and not _composing_dialogue():
		if restore_only and event.keycode in [KEY_SPACE, KEY_E, KEY_F]:
			latest = "当前为只读回看；居民、门窗和存档保持原样。V 总览/返回"
			_refresh()
			return
		if event.keycode == KEY_V:
			if review_camera != null and review_camera.current:
				_camera.make_current()
			else: _aerial()
			return
		if event.keycode in [KEY_E, KEY_F]:
			var nearest := ""
			var distance := 3.5
			for id in quarter.houses:
				var d: float = _player.position.distance_to(quarter.entrances[id])
				if d < distance:
					nearest = id
					distance = d
			if not nearest.is_empty():
				var house = quarter.houses[nearest]
				if event.keycode == KEY_E: _set_door(nearest,not house.is_door_open())
				else:
					var value: bool = not house.is_window_open()
					var result := town.transaction(_save_path,func():
						town._state.godot.spatial_layout.windows[nearest] = value
						return {"ok":true,"code":"spatial_window_changed"})
					if result.ok: house.set_window_open(value)
			return
	super._unhandled_input(event)

func _aerial() -> void:
	if review_camera == null:
		review_camera = Camera3D.new()
		add_child(review_camera)
	review_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	review_camera.size = 184
	review_camera.far = 1000
	review_camera.position = Vector3(120,169.7056,154)
	review_camera.look_at(Vector3(0,0,34))
	review_camera.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _image(filename: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(report_dir.path_join(filename))

func _review() -> void:
	var started := Time.get_ticks_msec()
	while not town_navigation.enabled and Time.get_ticks_msec()-started < 90000:
		await get_tree().process_frame
	for frame in 3: await get_tree().physics_frame
	var report := {"world_id":town.snapshot().world_id,"life_seq":town.snapshot().life.seq,"mode":"paused_physics_diagnostic_no_model_calls", "navigation":town_navigation.bake_status,"routes":[],"residents":[]}
	report["fixtures"] = await _check_fixtures()
	report["foraging_clearance"] = []
	await get_tree().physics_frame
	for id in town.active_ids():
		report.foraging_clearance.append({"id":id,"clear":_foraging_can_work(id)})
	for node in get_children():
		if node is CanvasLayer: node.visible = false
	for label in cards.values(): label.visible = false
	_aerial()
	await _image("01-aerial-clean.png")
	review_layer = CanvasLayer.new()
	add_child(review_layer)
	var index := 0
	for id in town.active_ids():
		var point: Vector2 = review_camera.unproject_position(bodies[id].position+Vector3.UP*1.8)
		var label := Label.new()
		label.text = "%02d %s" % [index+1,town.resident(id).name]
		label.position = point
		label.add_theme_font_size_override("font_size",20)
		label.add_theme_color_override("font_outline_color",Color("242b26"))
		label.add_theme_constant_override("outline_size",8)
		review_layer.add_child(label)
		report.residents.append({"id":id,"name":town.resident(id).name,"position":_array(bodies[id].position),"home":_array(town.home_point(id)),"screen":[point.x,point.y]})
		index += 1
	await _image("02-aerial-residents.png")
	review_layer.visible = false
	review_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	review_camera.fov = 65
	review_camera.position = Vector3(1,3.5,24)
	review_camera.look_at(Vector3(0,3,-25))
	await _image("03-market-street.png")
	var first_home: Node3D = quarter.houses[town.active_ids()[0]]
	first_home.set_door_open(true)
	review_camera.position = first_home.to_global(Vector3(0,1.65,2.9))
	review_camera.look_at(first_home.to_global(Vector3(0,1.25,-1.8)))
	await _image("04-resident-interior.png")
	first_home.set_door_open(false)
	if town_navigation.enabled:
		var map: RID = town_navigation.region.get_navigation_map()
		for id in town.active_ids():
			for place in CatalogForReview.PLACES:
				var a: Array = place.point
				var target := Vector3(a[0],a[1],a[2])
				var path := NavigationServer3D.map_get_path(map,town.home_point(id),target,true)
				report.routes.append({"resident":id,"place":place.id,"reaches":not path.is_empty() and path[path.size()-1].distance_to(target)<.45,
					"points":path.size(),"end":_array(path[path.size()-1]) if not path.is_empty() else [],
					"home_nav":_array(NavigationServer3D.map_get_closest_point(map,town.home_point(id))),
					"target_nav":_array(NavigationServer3D.map_get_closest_point(map,target))})
		if OS.get_cmdline_user_args().has("--quarter-probe"):
			Engine.time_scale = 3.0
			Engine.physics_ticks_per_second = 180
			for leg in ["enter_home","visit_market","return_home"]:
				probe_leg = leg
				probe_targets.clear()
				probe_finished.clear()
				probe_age = 0
				index = 0
				for id in town.active_ids():
					probe_targets[id] = town.home_point(id) if leg != "visit_market" else Vector3(2.5 + CatalogForReview.PLACE_OFFSETS[index][0],.10,14.5 + CatalogForReview.PLACE_OFFSETS[index][1])
					index += 1
				probe_running = true
				while probe_running: await get_tree().physics_frame
				print("QUARTER_WALK_LEG ", leg, " ", JSON.stringify(probe_results.filter(func(r): return r.leg == leg)))
			Engine.time_scale = 1.0
			Engine.physics_ticks_per_second = 60
		report["physical_walks"] = probe_results
		report["crowd_detours"] = town_navigation.crowd_detour_count
		report["crowd_detour_attempts"] = town_navigation.crowd_detour_attempts
		report["door_crossings"] = town_navigation.door_crossings
	var file := FileAccess.open(report_dir.path_join("report.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("LIVING_QUARTER_REPORT ", report_dir)
	await _finish_review()

func _finish_review() -> void:
	get_tree().quit(0)

func _check_fixtures() -> Array:
	var results: Array = []
	for id in quarter.houses:
		var house = quarter.houses[id]
		var opening_data: Dictionary = house.door_opening_godot()
		var centre: Vector3 = house.to_global(opening_data.centre)
		var outward: Vector3 = house.global_basis * opening_data.outward
		var ray := PhysicsRayQueryParameters3D.create(centre+outward*.7,centre-outward*.7,4)
		house.set_door_open(false)
		house.set_window_open(false)
		await get_tree().physics_frame
		var closed := not get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
		var sash: Node3D = house.sashes[0]
		var window_ray := PhysicsRayQueryParameters3D.create(sash.to_global(Vector3(0,.30,.25)),sash.to_global(Vector3(0,.30,-.25)),1)
		var pane_closed := not get_world_3d().direct_space_state.intersect_ray(window_ray).is_empty()
		house.set_door_open(true)
		house.set_window_open(true)
		await get_tree().physics_frame
		var open := get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
		var pane_open := get_world_3d().direct_space_state.intersect_ray(window_ray).is_empty()
		results.append({"id":id,"closed_door_blocks":closed,"open_door_clears":open,"closed_window_blocks":pane_closed,"open_window_clears":pane_open})
		house.set_door_open(false)
		house.set_window_open(false)
	return results

const CatalogForReview = preload("res://spatial/town_places.gd")
func _array(v: Vector3) -> Array:
	return [v.x,v.y,v.z]

func _tick_probe(delta: float) -> void:
	probe_age += delta
	for id in probe_targets:
		var body: CharacterBody3D = bodies[id]
		var target: Vector3 = probe_targets[id]
		if probe_finished.has(id): continue
		if body.position.distance_to(target)<.40 or probe_age>145:
			var reached := body.position.distance_to(target)<.40
			probe_results.append({"resident":id,"leg":probe_leg,"reached":reached,"position":_array(body.position),"target":_array(target),"seconds":probe_age})
			probe_finished[id] = true
			body.velocity = Vector3.ZERO
			town_navigation.clear_route(id)
			actors[id].set_walking(false)
			continue
		var direction: Vector3 = town_navigation.direction_for(id,"probe:"+probe_leg,body,target)
		body.velocity.x = direction.x*1.35
		body.velocity.z = direction.z*1.35
		body.velocity.y = -.2 if body.is_on_floor() else body.velocity.y-18*delta
		body.move_and_slide()
		actors[id].set_walking(direction.length()>.05)
		if direction.length()>.05: actors[id].look_at(actors[id].global_position+direction)
	if probe_finished.size()==probe_targets.size(): probe_running=false
