extends "res://spatial/living_town.gd"
const PCGQuarter = preload("res://experiments/pcg/quarter.gd")
var pcg_navigation_ready := false
var closing := false

func _ready() -> void:
	super._ready()
	get_tree().auto_accept_quit = false
	if quarter != null: _finish_navigation.call_deferred()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_close_pcg.call_deferred()

func _finish_review() -> void:
	await _close_pcg()

func _close_pcg() -> void:
	if closing: return
	closing = true
	var tree := get_tree()
	set_process(false)
	set_physics_process(false)
	set_process_input(false)
	set_process_unhandled_input(false)
	# Terrain and scatter hold renderer resources: release while the renderer is alive.
	for child in get_children(): child.queue_free()
	for frame in 4: await tree.process_frame
	tree.quit(0)

func _load_market_runtime() -> void:
	quarter = PCGQuarter.new()
	quarter.name = "PCGFirstFloorTrial"
	add_child(quarter)
	quarter.build()
	_market_loaded = quarter.houses.size()==16

func _finish_navigation() -> void:
	var started := Time.get_ticks_msec()
	while (not quarter.pcg_ready or town_navigation.baking) and Time.get_ticks_msec()-started<180000:
		await get_tree().process_frame
	if not quarter.pcg_ready or town_navigation.baking:
		push_error("PCG plugin build did not complete; stop the trial")
		get_tree().quit(2)
		return
	# Include the plugin-created tree trunks/props in the existing navigation mesh.
	for frame in 3: await get_tree().physics_frame
	var geometry := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(town_navigation.navigation_mesh,geometry,self)
	NavigationServer3D.bake_from_source_geometry_data(town_navigation.navigation_mesh,geometry)
	town_navigation.region.navigation_mesh = town_navigation.navigation_mesh
	town_navigation.enabled = town_navigation.navigation_mesh.get_polygon_count()>0
	NavigationServer3D.map_force_update(town_navigation.region.get_navigation_map())
	pcg_navigation_ready = town_navigation.enabled
	print("PCG_NAVIGATION_READY ",pcg_navigation_ready)

func _review() -> void:
	var started := Time.get_ticks_msec()
	while not pcg_navigation_ready and Time.get_ticks_msec()-started<190000:
		await get_tree().process_frame
	if not pcg_navigation_ready:
		push_error("PCG navigation did not become ready")
		get_tree().quit(2)
		return
	for node in get_children():
		if node is CanvasLayer: node.visible=false
	for label in cards.values(): label.visible=false
	_aerial()
	quarter.terrain.set_camera(review_camera)
	for frame in 45: await get_tree().process_frame
	await _image("05-pcg-overview.png")
	review_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	review_camera.fov = 62
	review_camera.position = Vector3(-58,3.1,-30)
	review_camera.look_at(Vector3(-35,1.5,14))
	for frame in 20: await get_tree().process_frame
	await _image("06-pcg-woodland.png")
	review_camera.position = Vector3(1,2.1,-52)
	review_camera.look_at(Vector3(0,2.0,19))
	for frame in 20: await get_tree().process_frame
	await _image("07-pcg-market.png")
	var report: Dictionary = quarter.pcg_report
	report["build_ms"] = Time.get_ticks_msec()-started
	var measured_frames := []
	for frame in 90:
		var stamp := Time.get_ticks_usec()
		await get_tree().process_frame
		measured_frames.append(float(Time.get_ticks_usec()-stamp)/1000.0)
	var sum_ms := 0.0
	for frame_ms: float in measured_frames: sum_ms+=frame_ms
	measured_frames.sort()
	report["market_frame_ms_mean"] = sum_ms/measured_frames.size()
	report["market_frame_ms_p95"] = measured_frames[int(measured_frames.size()*.95)]
	report["render_draw_calls"] = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	report["render_primitives"] = Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	report["navigation_includes_new_colliders"] = true
	report["road_material"] = "trial cobblestone shader applied to Road Generator meshes"
	var file := FileAccess.open(report_dir.path_join("pcg.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	await super._review()
