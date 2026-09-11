extends "res://spatial/street_trial.gd"
## The same market/player scene, using the continuation module instead of Luna's fixture.

const Town = preload("res://core/town_life.gd")
var town := Town.new()
var actors: Dictionary = {}
var bodies: Dictionary = {}
var cards: Dictionary = {}
var paused := true
var tick := 0.0
var capture_dir := ""
var capture_age := 0.0
var capture_started := false
var status: Label
var berry_visuals: Array[Node3D] = []
var latest := "世界已暂停。按空格继续；原事件与钱物已经载入。"
var dialogue: Label
var last_inquiry_seconds := -10.0
var dialogue_fixture := false
var dialogue_fixture_done := false

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg == "--town-dialogue-fixture":
			dialogue_fixture = true
		if arg.begins_with("--town-save="):
			_save_path = arg.trim_prefix("--town-save=")
		if arg.begins_with("--town-capture="):
			capture_dir = arg.trim_prefix("--town-capture=")
	if _save_path == DEFAULT_SAVE_PATH:
		push_error("Town mode requires an explicit separately migrated --town-save path")
		get_tree().quit(2)
		return
	var loaded := town.load_from(_save_path)
	if not loaded.ok:
		push_error(JSON.stringify(loaded))
		get_tree().quit(2)
		return
	var lock := town.acquire_writer(_save_path)
	if not lock.ok:
		push_error(JSON.stringify(lock))
		get_tree().quit(2)
		return
	_owns_writer = true
	_kernel = town
	_build_environment()
	_build_ground_collision()
	_load_market_runtime()
	_build_player()
	_player.position = Vector3(0, 1.22, 12)
	_camera_pivot.rotation.y = 0
	_camera_pitch.rotation.x = -0.05
	var palette := [Color("954f42"), Color("345f79"), Color("657448")]
	var index := 0
	for id in town.active_ids():
		var body := CharacterBody3D.new()
		body.name = "ResidentBody%d" % index
		add_child(body)
		body.position = town.position_of(id)
		var collider := CollisionShape3D.new()
		var shape := CapsuleShape3D.new()
		shape.radius = 0.25
		shape.height = 1.5
		collider.shape = shape
		collider.position.y = 0.75
		body.add_child(collider)
		var actor: Node3D = RESIDENT_SCRIPT.new()
		actor.shirt_color = palette[index]
		actor.hair_color = [Color("563827"), Color("302d2a"), Color("766953")][index]
		body.add_child(actor)
		actor.get_node("OriginalResidentBody/Torso").material_override = _simple_material(palette[index])
		actors[id] = actor
		bodies[id] = body
		var title := Label3D.new()
		title.position.y = 2.05
		title.font_size = 38
		title.outline_size = 8
		title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		title.modulate = Color("f5e6c8")
		body.add_child(title)
		cards[id] = title
		_work_marker(town.destination(id, "rest"), ["旅店 · 艾琳", "铁匠铺 · 拓真", "木工坊 · 柏木"][index])
		index += 1
	_build_berry_patch()
	_build_town_hud()
	for event in town.snapshot().life.events:
		if event.type == "visitor_reply":
			dialogue.text = "%s\n%s\n（已保存的交流 · 离线规则回应）" % [town.resident(event.actor_id).name, event.text]
	_refresh()
	if not capture_dir.is_empty():
		DirAccess.make_dir_recursive_absolute(capture_dir)
		paused = OS.get_cmdline_user_args().has("--town-restore")
		_camera.global_position = Vector3(0.0, 5.0, 14.0)
		_camera.look_at(Vector3(0, 0.9, 4.0))
		if dialogue_fixture:
			_player.position = town.position_of(town.active_ids()[1]) + Vector3(0, 0.9, 1.5)
			_camera.global_position = _player.position + Vector3(-2, 1.6, 2)
			_camera.look_at(town.position_of(town.active_ids()[1]) + Vector3(0, 1.1, 0))

func _process(delta: float) -> void:
	if status == null:
		return
	if not capture_dir.is_empty():
		capture_age += delta
		if dialogue_fixture and capture_age > 1.0 and not dialogue_fixture_done:
			dialogue_fixture_done = true
			_inquire_nearby(true)
		if capture_age > (3.0 if paused else 90.0) and not capture_started:
			capture_started = true
			_capture_town.call_deferred()

func _physics_process(delta: float) -> void:
	if status == null:
		return
	if capture_dir.is_empty():
		super._physics_process(delta)
	town.host_visitor_position(_player.position)
	if paused:
		return
	for id in town.active_ids():
		var job: Dictionary = town.pending_job(id)
		var body: CharacterBody3D = bodies[id]
		var actor: Node3D = actors[id]
		var moving := false
		if not job.is_empty():
			var target := town.destination(id, job.action)
			var offset := target - body.position
			offset.y = 0
			moving = offset.length() > 0.30
			if moving:
				var direction := offset.normalized()
				body.velocity.x = direction.x * 1.35
				body.velocity.z = direction.z * 1.35
				actor.look_at(actor.global_position + direction)
			else:
				body.velocity.x = 0
				body.velocity.z = 0
			actor.set_gesture("idle" if moving else {"eat_ration": "eat", "rest": "rest", "harvest_ration": "harvest"}.get(job.action, "idle"))
		else:
			# A finished local routine returns to its own work place, with collisions.
			var home_offset := town.destination(id, "rest") - body.position
			home_offset.y = 0
			moving = home_offset.length() > 0.30
			body.velocity.x = home_offset.normalized().x * 1.35 if moving else 0.0
			body.velocity.z = home_offset.normalized().z * 1.35 if moving else 0.0
			if moving:
				actor.look_at(actor.global_position + home_offset.normalized())
			actor.set_gesture("idle")
		actor.set_walking(moving)
		body.velocity.y = -0.2 if body.is_on_floor() else body.velocity.y - 18 * delta
		body.move_and_slide()
		town.host_move(id, body.position)
	tick += delta
	if tick < 0.5:
		return
	var step := tick
	tick = 0
	var result := town.transaction(_save_path, func():
		var advanced := town.advance(step)
		if not advanced.ok:
			return advanced
		for id in town.active_ids():
			if town.pending_job(id).is_empty():
				var choice := town.choose_local(id)
				if choice != "wait":
					var command := "godot-life:%s:%d" % [id, town.command_count()]
					town.start_action(id, choice, command)
		return advanced)
	if not result.ok:
		paused = true
		latest = "保存失败，生活已暂停：" + str(result.code)
	else:
		for receipt in result.completed:
			latest = str(town.resident(receipt.actor_id).name) + " · " + _action_label(receipt.code)
	_refresh()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		paused = not paused
		latest = "生活已暂停" if paused else "生活继续；时间只在运行时流逝"
		_refresh()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_H:
		_inquire_nearby()
		return
	if event is InputEventKey and event.keycode in [KEY_E, KEY_F8]:
		return
	super._unhandled_input(event)

func _build_town_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(22, 20)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.10, 0.10, 0.91)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	status = Label.new()
	status.add_theme_font_size_override("font_size", 19)
	panel.add_child(status)
	var dialogue_panel := PanelContainer.new()
	dialogue_panel.anchor_top = 1.0
	dialogue_panel.anchor_bottom = 1.0
	dialogue_panel.offset_left = 22
	dialogue_panel.offset_right = 582
	dialogue_panel.offset_top = -160
	dialogue_panel.offset_bottom = -20
	dialogue_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	dialogue_panel.add_theme_stylebox_override("panel", style)
	layer.add_child(dialogue_panel)
	dialogue = Label.new()
	dialogue.custom_minimum_size.x = 520
	dialogue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue.add_theme_font_size_override("font_size", 20)
	dialogue.text = "走近居民，按 H 询问：有什么需要帮忙的？"
	dialogue_panel.add_child(dialogue)

func _inquire_nearby(fixture_input: bool = false) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - last_inquiry_seconds < 3.0:
		return
	var nearest := ""
	var distance := 3.0
	for id in town.active_ids():
		var candidate := _player.position.distance_to(town.position_of(id))
		if candidate < distance:
			nearest = id
			distance = candidate
	if nearest.is_empty():
		dialogue.text = "离得太远了。靠近居民再交谈。"
		return
	last_inquiry_seconds = now
	var command := "visitor:%d" % town.command_count()
	var result := town.transaction(_save_path, func():
		return town.visitor_inquiry(nearest, "这里有什么需要我帮忙的吗？", command, "scripted_player_fixture" if fixture_input else "human_player"))
	if not result.ok:
		dialogue.text = "交流未送达：" + str(result.code)
		return
	# This explicitly labelled local policy uses only the selected resident's view.
	var view := town.resident_view(nearest)
	var choice := "unsure"
	var response := "暂时没有急事。我会留意工作点和口粮的情况。"
	if view.inventory.energy <= 50:
		choice = "unavailable"
		response = "我得先休息一下，等恢复精神再聊吧。"
	elif view.inventory.food == 0:
		choice = "willing"
		response = "我的口粮用完了。如果你找到食物来源，我愿意一起商量。"
	var replied := town.transaction(_save_path, func():
		return town.reply_to_visitor(nearest, result.request_id, choice, response, command + ":reply"))
	dialogue.text = "%s\n%s\n（离线规则回应 · 交流已保存）" % [view.identity.name, response] if replied.ok else "回复未送达：" + str(replied.code)
	_refresh()

func _refresh() -> void:
	var snap := town.snapshot()
	status.text = "起始之城 · 生活移植验证\n13 个原身份 · 3 人活动 · 新行动：离线规则选择\n空格 暂停/继续 · WASD 行走 · H 询问 · ESC 释放\n%s\n公共浆果 %d / %d · 生活事件 %d" % [latest, snap.foraging.stock, snap.foraging.capacity, snap.life.seq]
	for id in town.active_ids():
		var a := town.account(id)
		var job: Dictionary = snap.godot.pending.get(id, {})
		cards[id].text = "%s\n%s · 口粮 %d" % [town.resident(id).name, "休整" if job.is_empty() else _action_label(job.action), a.food]
	for index in berry_visuals.size():
		berry_visuals[index].visible = index < snap.foraging.stock

func _action_label(action: String) -> String:
	return {"eat_ration": "进食", "rest": "休息", "harvest_ration": "采集", "resources_unavailable": "资源不足，未完成"}.get(action, action)

func _work_marker(point: Vector3, title: String) -> void:
	var marker := Label3D.new()
	marker.text = title
	marker.font_size = 36
	marker.outline_size = 8
	marker.position = point + Vector3(0, 0.12, -0.7)
	marker.rotation_degrees.x = -70
	marker.modulate = Color("e2c591")
	add_child(marker)

func _build_berry_patch() -> void:
	var point := town.destination(town.active_ids()[0], "harvest_ration")
	_work_marker(point, "公共浆果地")
	for i in 3:
		var bush := MeshInstance3D.new()
		var foliage := SphereMesh.new()
		foliage.radius = 0.3
		foliage.height = 0.45
		foliage.radial_segments = 8
		foliage.rings = 4
		bush.mesh = foliage
		bush.material_override = _simple_material(Color("536d35"))
		bush.position = point + Vector3((i - 1) * 0.65, 0.2, -0.8)
		add_child(bush)
		var fruit := MeshInstance3D.new()
		var fruit_mesh := SphereMesh.new()
		fruit_mesh.radius = 0.08
		fruit_mesh.height = 0.16
		fruit.mesh = fruit_mesh
		fruit.material_override = _simple_material(Color("a43d53"))
		fruit.position = Vector3(0, 0.15, 0.2)
		bush.add_child(fruit)
		berry_visuals.append(fruit)

func _capture_town() -> void:
	paused = true
	_refresh()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(capture_dir.path_join("town.png"))
	var snap := town.snapshot()
	var evidence := {"original_identities": snap.residents.size(), "active": town.active_ids().size(), "life_seq": snap.life.seq,
		"source_seq": snap.godot.source_life_seq, "new_events": snap.godot.new_events,
		"new_decisions": "local_rule_policy", "paid_calls": 0, "foraging": snap.foraging, "pending_count": snap.godot.pending.size()}
	if dialogue_fixture:
		evidence["player_input"] = "scripted_player_fixture"
		evidence["dialogue"] = dialogue.text
	var file := FileAccess.open(capture_dir.path_join("evidence.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(evidence, "  "))
	file.close()
	get_tree().quit(0)
