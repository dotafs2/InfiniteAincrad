extends "res://experiments/pcg/town.gd"
const DemoQuarter = preload("res://experiments/pcg/demo_quarter.gd")

func _load_market_runtime() -> void:
	quarter = DemoQuarter.new()
	quarter.name = "FirstDemoTown"
	add_child(quarter)
	quarter.build()
	_market_loaded = quarter.houses.size() == 16

func _review() -> void:
	var stamp := Time.get_ticks_msec()
	while not pcg_navigation_ready and Time.get_ticks_msec()-stamp<190000:
		await get_tree().process_frame
	if not pcg_navigation_ready:
		push_error("Demo navigation not ready")
		get_tree().quit(2)
		return
	for child in get_children():
		if child is CanvasLayer: child.visible = false
	for label in cards.values(): label.visible = false
	_aerial()
	quarter.terrain.set_camera(review_camera)
	review_camera.size = 211
	for frame in 30: await get_tree().process_frame
	await _image("08-demo-town-overview.png")
	review_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	review_camera.fov = 64
	for view in [
		["09-demo-market",Vector3(1,2.15,-37),Vector3(-1,2,4)],
		["10-demo-workshops",Vector3(-55,3.4,18),Vector3(-37,1.5,39)],
		["11-demo-inn",Vector3(32,2.2,14),Vector3(23,1.2,27)],
		["12-demo-cargo",Vector3(48,3,-38),Vector3(34,1,-19)],
		["13-demo-neighborhood",Vector3(54,11,84),Vector3(-2,0,49)]
	]:
		review_camera.position = view[1]
		review_camera.look_at(view[2])
		for frame in 20: await get_tree().process_frame
		await _image(view[0]+".png")
	await super._review()
