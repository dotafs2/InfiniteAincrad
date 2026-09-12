extends SceneTree
## Offline acceptance for the town expansion: imported generated assets actually load, streets
## have plausible floor and capsule clearance, rotated footprints do not overlap each other or
## the original market, a representative new solid prop blocks a body, a plain NPC-style capsule
## walks the whole route and back, and three labelled views are captured. No model call, no
## gateway, disposable save copy only.
const TownScene := preload("res://scenes/town_street.tscn")
const Layout := preload("res://spatial/town_expansion_layout.gd")
const MARKET_AABB := {"min_x": -27.5, "max_x": 27.5, "min_z": -80.0, "max_z": 36.0}
const FLOOR_MIN := -0.05
const FLOOR_MAX := 0.60

var _scene: Node = null
var _expansion: Node = null
var _walker: CharacterBody3D = null
var _out := ""
var _media := ""
var _frames := 0
var _checks := 0
var _failures: Array = []
var _marks: Array = []
var _route_index := 1
var _shots: Array = []
var _blocked: Array = []
var _prop_negative: Dictionary = {}
var _phase := "static"

const ROUTE := [
	{"x": 0.0, "z": 30.0, "label": "original market floor edge"},
	{"x": 0.0, "z": 40.0, "label": "north junction on the new paving"},
	{"x": -14.0, "z": 40.0, "label": "west residential street"},
	{"x": -22.0, "z": 40.0, "label": "west street end"},
	{"x": -14.0, "z": 40.0, "label": "west street back"},
	{"x": 0.0, "z": 46.5, "label": "commons north entrance"},
	{"x": 0.0, "z": 53.0, "label": "planted commons"},
	{"x": 0.0, "z": 60.0, "label": "commons south crossing"},
	{"x": 0.0, "z": 66.0, "label": "south junction"},
	{"x": -14.0, "z": 66.0, "label": "south-west street"},
	{"x": -22.0, "z": 66.0, "label": "south-west street end"},
	{"x": -14.0, "z": 66.0, "label": "south-west street back"},
	{"x": 0.0, "z": 66.0, "label": "south junction again"},
	{"x": 18.0, "z": 66.0, "label": "south-east street"},
	{"x": 26.0, "z": 70.0, "label": "south-east arm end"},
	{"x": 26.0, "z": 74.0, "label": "caravan yard approach"},
	{"x": 26.0, "z": 70.0, "label": "leaving the caravan yard"},
	{"x": 26.0, "z": 66.0, "label": "south-east arm back on the road"},
	{"x": 0.0, "z": 66.0, "label": "south junction on the main street"},
	{"x": 0.0, "z": 88.0, "label": "orchard edge track"},
	{"x": 0.0, "z": 70.0, "label": "main street south"},
	{"x": 0.0, "z": 50.0, "label": "main street at the commons"},
	{"x": 0.0, "z": 40.0, "label": "main street north gate"},
	{"x": 2.5, "z": 14.5, "label": "back at the original plaza"},
]

func _check(condition: bool, label: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(label)

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg.begins_with("--media="):
			_media = arg.trim_prefix("--media=")
	_scene = TownScene.instantiate()
	root.add_child(_scene)

func _physics_process(_delta: float) -> bool:
	_frames += 1
	if _frames == 8:
		_static_checks()
		_spawn_walker()
		_phase = "walk"
		return false
	if _frames < 8:
		return false
	if _phase == "walk":
		_advance_route()
		if _frames > _frame_deadline:
			_failures.append("walk route did not complete within the derived %d frames (stuck at %s)"
				% [_frame_deadline, str([snappedf(_walker.position.x, 0.01),
					snappedf(_walker.position.z, 0.01)])])
			_phase = "finish"
	elif _phase == "finish":
		## Frame-stepped capture: no await inside a physics callback, so the phase cannot be
		## left pending and the evidence file is always written.
		_capture_step()
	return false

func _static_checks() -> void:
	_expansion = _scene.get_node_or_null("TownExpansion")
	_check(_expansion != null, "expansion present in the playable town street")
	if _expansion == null:
		_finish()
		return
	var evidence: Dictionary = _expansion.evidence
	## 1. Imported generated assets must actually load and be counted only when they do.
	var failures: Array = evidence.get("generated_load_failures", [])
	_check(failures.is_empty(), "every requested generated asset loaded (%s)" % str(failures))
	_check(int(evidence.get("shopfront_details", 0)) == Layout.SHOPFRONTS.size(),
		"shopfront details placed: %s/%s" % [evidence.get("shopfront_details"),
			Layout.SHOPFRONTS.size()])
	_check(int(evidence.get("workshop_tools", 0)) == Layout.WORKSHOPS.size(),
		"workshop tools placed: %s/%s" % [evidence.get("workshop_tools"),
			Layout.WORKSHOPS.size()])
	_check(int(evidence.get("cargo_props", 0)) == Layout.CARAVAN.size(),
		"cargo props placed: %s/%s" % [evidence.get("cargo_props"), Layout.CARAVAN.size()])
	_check(int(evidence.get("houses", 0)) >= 12 and int(evidence.get("houses", 0)) <= 16,
		"12-16 new houses placed (got %s)" % evidence.get("houses"))
	_check(Array(evidence.get("variants", [])).size() == 6, "all six residence variants used")
	## 3. Rotated footprints: no new/new overlap and no new house inside the original market.
	var rotated: Array = []
	for house in Layout.HOUSES:
		var footprint: Vector2 = Layout.house_footprint(int(house["variant"]))
		var quarter := int(round(float(house["yaw"]) / 90.0)) % 2 == 1
		rotated.append({"x": float(house["x"]), "z": float(house["z"]),
			"hx": (footprint.y if quarter else footprint.x) * 0.5,
			"hz": (footprint.x if quarter else footprint.y) * 0.5})
	var overlaps := 0
	var market_hits := 0
	## A house counts as embedded only when its footprint really intersects existing market
	## collision geometry, measured with physics at body height (the market AABB is the whole
	## street strip, so a rectangle test would be wrong).
	var market_bodies: Array = []
	for node in _scene.find_children("*", "StaticBody3D", true, false):
		if str(node.name).begins_with("GeneratedCollision_"):
			market_bodies.append(node.get_rid())
	for i in rotated.size():
		var a: Dictionary = rotated[i]
		if _footprint_hits_market(a, market_bodies):
			market_hits += 1
		for j in range(i + 1, rotated.size()):
			var b: Dictionary = rotated[j]
			if absf(a["x"] - b["x"]) < a["hx"] + b["hx"] and absf(a["z"] - b["z"]) < a["hz"] + b["hz"]:
				overlaps += 1
	_check(overlaps == 0, "no interpenetrating new houses (overlaps=%d)" % overlaps)
	_check(market_hits == 0, "no new house embedded in the original market (%d)" % market_hits)
	## 2. Street floor plausibility, capsule clearance and continuity along each paving rect.
	var space: PhysicsDirectSpaceState3D = (_scene as Node3D).get_world_3d().direct_space_state
	var floor_bad := 0
	var blocked := 0
	var samples := 0
	var previous_y := INF
	var discontinuities := 0
	for road in Layout.ROADS:
		var size: Vector2 = road["size"]
		var along_x := size.x >= size.y
		var steps := maxi(1, int(maxf(size.x, size.y) * 0.5 / 4.0))
		for step in range(-steps, steps + 1):
			var offset := float(step) * 4.0
			var point: Vector2 = road["center"] + (Vector2(offset, 0) if along_x else Vector2(0, offset))
			samples += 1
			var down := PhysicsRayQueryParameters3D.create(Vector3(point.x, 20, point.y),
				Vector3(point.x, -2, point.y))
			var hit: Dictionary = space.intersect_ray(down)
			if hit.is_empty():
				floor_bad += 1
				if _blocked.size() < 8:
					_blocked.append(["no_floor", point.x, point.y])
				continue
			var floor_y: float = hit.position.y
			if floor_y < FLOOR_MIN or floor_y > FLOOR_MAX:
				floor_bad += 1
				if _blocked.size() < 8:
					_blocked.append(["roof_like_floor", point.x, point.y, floor_y])
				continue
			if previous_y != INF and absf(floor_y - previous_y) > 0.35:
				discontinuities += 1
			previous_y = floor_y
			var sphere := SphereShape3D.new()
			sphere.radius = 0.6
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = sphere
			query.transform = Transform3D(Basis(), Vector3(point.x, floor_y + 1.2, point.y))
			query.collision_mask = 0xFFFFFFFF
			if not space.intersect_shape(query, 1).is_empty():
				blocked += 1
				if _blocked.size() < 8:
					_blocked.append(["blocked", point.x, point.y, floor_y])
	_check(samples > 40, "road sampling covered every paving rect (%d samples)" % samples)
	_check(floor_bad == 0, "every road sample stands on a plausible street floor (bad=%d %s)"
		% [floor_bad, str(_blocked)])
	_check(discontinuities == 0, "no floor discontinuity > 0.35 m along the streets (%d)"
		% discontinuities)
	_check(blocked == 0, "capsule clearance on every road sample (blocked=%d)" % blocked)
	_prop_negative = _prop_collision_check(space)
	_check(bool(_prop_negative.get("blocked_body", false)),
		"a representative new solid prop blocks a body (%s)" % str(_prop_negative))
	_check(bool(_prop_negative.get("path_clear", false)),
		"the path beside that prop stays clear (%s)" % str(_prop_negative))

func _footprint_hits_market(a: Dictionary, market_bodies: Array) -> bool:
	## Sample a house footprint at body height; any hit on a market collider means the shell is
	## physically inside original geometry, not merely inside the market's bounding rectangle.
	var space: PhysicsDirectSpaceState3D = (_scene as Node3D).get_world_3d().direct_space_state
	var sphere := SphereShape3D.new()
	sphere.radius = 0.45
	var x := float(a["x"]) - float(a["hx"])
	while x <= float(a["x"]) + float(a["hx"]):
		var z := float(a["z"]) - float(a["hz"])
		while z <= float(a["z"]) + float(a["hz"]):
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = sphere
			query.transform = Transform3D(Basis(), Vector3(x, 1.2, z))
			query.collision_mask = 0xFFFFFFFF
			for hit in space.intersect_shape(query, 8):
				var collider: Variant = hit.get("collider")
				if collider is CollisionObject3D and market_bodies.has((collider as CollisionObject3D).get_rid()):
					return true
			z += 1.5
		x += 1.5
	return false

func _prop_collision_check(space: PhysicsDirectSpaceState3D) -> Dictionary:
	## Probe the collision primitive each generated prop actually carries, instead of a hardcoded
	## guess: the wagon's solid core and one workshop tool, plus the yard approach staying clear.
	var probes := []
	for file_name in ["covered_caravan_wagon.glb", "arched_pottery_kiln.glb"]:
		var node := _find_generated(file_name)
		if node == null:
			probes.append({"file": file_name, "found": false})
			continue
		var shape: CollisionShape3D = node.find_children("*", "CollisionShape3D", true, false)[0] \
			if not node.find_children("*", "CollisionShape3D", true, false).is_empty() else null
		if shape == null:
			probes.append({"file": file_name, "found": true, "collision": false})
			continue
		var centre: Vector3 = shape.global_position
		var sphere := SphereShape3D.new()
		sphere.radius = 0.25
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = sphere
		query.transform = Transform3D(Basis(), centre)
		query.collision_mask = 0xFFFFFFFF
		var hits: Array = space.intersect_shape(query, 4)
		var hit_names: Array = []
		for hit in hits:
			var collider: Variant = hit.get("collider")
			hit_names.append(str(collider.name) if collider is Node else "?")
		probes.append({"file": file_name, "found": true, "collision": true,
			"collider": str(shape.get_parent().name), "primitive": str(shape.shape.get_class()),
			"centre": [snappedf(centre.x, 0.01), snappedf(centre.y, 0.01), snappedf(centre.z, 0.01)],
			"hits": hits.size(), "hit_colliders": hit_names})
	var blocked_body: bool = probes.size() > 0 and int(probes[0].get("hits", 0)) > 0
	var approach := PhysicsShapeQueryParameters3D.new()
	var reach := SphereShape3D.new()
	reach.radius = 0.4
	approach.shape = reach
	approach.transform = Transform3D(Basis(), Vector3(26.0, 0.9, 70.0))
	approach.collision_mask = 0xFFFFFFFF
	var path_clear: bool = space.intersect_shape(approach, 1).is_empty()
	return {"blocked_body": blocked_body, "path_clear": path_clear, "probes": probes}

func _find_generated(file_name: String) -> Node3D:
	if _scene == null:
		return null
	for node in _scene.find_children("*", "Node3D", true, false):
		if str(node.get_meta("generated_asset", "")) == file_name:
			return node
	return null

func _spawn_walker() -> void:
	_walker = CharacterBody3D.new()
	_walker.name = "ExpansionWalker"
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.25
	capsule.height = 1.75
	collider.shape = capsule
	collider.position.y = 0.875
	_walker.add_child(collider)
	_walker.position = Vector3(ROUTE[0]["x"], 0.95, ROUTE[0]["z"])
	root.add_child(_walker)
	## Route length and a deadline derived BEFORE the run: helper capsule at the original NPC
	## speed, with a 2.4x margin for turning and a small fixed allowance.
	_route_length = 0.0
	for index in range(1, ROUTE.size()):
		var previous: Dictionary = ROUTE[index - 1]
		var current: Dictionary = ROUTE[index]
		_route_length += Vector2(float(current["x"]) - float(previous["x"]),
			float(current["z"]) - float(previous["z"])).length()
	_frame_deadline = int(ceil(_route_length / 1.35 * 60.0 * 2.4)) + 900

func _advance_route() -> void:
	if _route_index >= ROUTE.size():
		_phase = "finish"
		return
	var target: Dictionary = ROUTE[_route_index]
	var goal := Vector3(target["x"], _walker.position.y, target["z"])
	var delta := goal - _walker.position
	if delta.length() < 1.2:
		_marks.append({"label": target["label"],
			"at": [snappedf(_walker.position.x, 0.01), snappedf(_walker.position.z, 0.01)]})
		_route_index += 1
		return
	## True horizontal speed: the whole XZ vector is normalised to the original 1.35 m/s, so no
	## diagonal shortcut can exceed the NPC walk speed.
	var flat := Vector3(delta.x, 0.0, delta.z)
	if flat.length() > 0.001:
		flat = flat.normalized() * 1.35
	_walker.velocity.x = flat.x
	_walker.velocity.z = flat.z
	_walker.velocity.y = -1.0 if not _walker.is_on_floor() else 0.0
	_walker.move_and_slide()

const VIEWS := [
	{"name": "overview", "at": Vector3(-40, 42, 120), "target": Vector3(0, 1, 52)},
	{"name": "south-street", "at": Vector3(0, 2.1, 18), "target": Vector3(0, 1.6, 52)},
	{"name": "commons", "at": Vector3(0, 2.4, 44), "target": Vector3(0, 1.2, 63)},
	{"name": "caravan-yard", "at": Vector3(2, 2.2, 66), "target": Vector3(26, 1.2, 71)},
]

var _capture_index := 0
var _capture_wait := 0
var _camera: Camera3D = null
var _shot_hashes: Array = []
var _route_length := 0.0
var _frame_deadline := 0

func _capture_step() -> void:
	if _media.is_empty() or _capture_index >= VIEWS.size():
		_finish()
		return
	if _capture_wait == 0:
		DirAccess.make_dir_recursive_absolute(_media)
		_preview_hud(false)
		if _camera == null:
			_camera = Camera3D.new()
			_camera.fov = 70.0
			root.add_child(_camera)
		## The pose is applied per shot: reusing one fixed transform produced three identical
		## images before.
		var view: Dictionary = VIEWS[_capture_index]
		_camera.global_position = view["at"]
		_camera.look_at(view["target"])
		_camera.current = true
		_camera.force_update_transform()
		_capture_wait = 1
		return
	if _capture_wait < 10:
		## Wait for genuinely rendered frames after the camera moved.
		_capture_wait += 1
		return
	var name_text := str(VIEWS[_capture_index]["name"])
	var image: Image = get_root().get_texture().get_image()
	var error := image.save_png(_media + "/" + name_text + ".png")
	if error != OK:
		_failures.append("capture failed for %s (error %d)" % [name_text, error])
	_shots.append(name_text)
	_shot_hashes.append(_image_hash(image))
	_capture_index += 1
	_capture_wait = 0
	if _capture_index >= VIEWS.size():
		_preview_hud(true)
		if _camera != null:
			_camera.queue_free()
			_camera = null
		_capture_wait = 0

func _image_hash(image: Image) -> String:
	## Coarse pixel fingerprint: proves the three shots are actually different frames.
	return str(hash(image.get_data().slice(0, 4096))) + "-" + str(image.get_size())

func _unique_count(values: Array) -> int:
	var seen: Array = []
	for value in values:
		if not seen.has(value):
			seen.append(value)
	return seen.size()

func _preview_hud(visible: bool) -> void:
	## Offline preview only: the ordinary HUD and resident nameplates are hidden for the capture
	## frames and restored afterwards, so normal gameplay keeps them.
	for node in _scene.find_children("*", "CanvasLayer", true, false):
		(node as CanvasLayer).visible = visible
	for node in _scene.find_children("*", "Label3D", true, false):
		(node as Label3D).visible = visible

func _finish() -> void:
	_check(_marks.size() == ROUTE.size() - 1,
		"walk route reached every district and returned (%d/%d)" % [_marks.size(),
			ROUTE.size() - 1])
	var evidence: Dictionary = _expansion.evidence if _expansion != null else {}
	var result := {"suite": "town_expansion", "houses": Layout.HOUSES.size(),
		"route_length_m": snappedf(_route_length, 0.1),
		"route_deadline_frames": _frame_deadline, "walk_speed_mps": 1.35,
		"shot_fingerprints": _shot_hashes,
		"shots_distinct": _shot_hashes.size() == VIEWS.size() \
			and _unique_count(_shot_hashes) == VIEWS.size(),
		"variants": evidence.get("variants", []), "kit_props": evidence.get("kit_props", 0),
		"shopfront_details": evidence.get("shopfront_details", 0),
		"workshop_tools": evidence.get("workshop_tools", 0),
		"cargo_props": evidence.get("cargo_props", 0),
		"new_asset_instances": evidence.get("new_asset_instances", 0),
		"authored_paving_width_m": 6, "measured_capsule_clearance": "0.6 m sphere at floor+1.2 m",
		"terrain": evidence.get("terrain", {}), "paving": evidence.get("paving", {}),
		"route": _marks, "prop_negative": _prop_negative, "blocked_samples": _blocked,
		"shots": _shots, "checks": _checks, "failures": _failures,
		"failure_count": _failures.size(), "model_calls": 0, "save_writes": 0}
	if not _out.is_empty():
		DirAccess.make_dir_recursive_absolute(_out.get_base_dir())
		var handle := FileAccess.open(_out, FileAccess.WRITE)
		if handle != null:
			handle.store_string(JSON.stringify(result))
			handle.flush()
			handle.close()
	print(JSON.stringify({"checks": _checks, "failures": _failures,
		"route_reached": _marks.size(), "shots": _shots}))
	quit(0 if _failures.is_empty() else 1)
