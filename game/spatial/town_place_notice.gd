extends Node3D
## The public wayfinding notice at the old-market exit, plus the real line-of-sight sensing
## that decides who can actually read it or see a place.
##
## It is one visible prop built from the existing travel/cargo art (a carved route waystone),
## with a small solid collider so it is a real object in the street rather than a marker.
## The sensing is a straight physics ray from the resident's eye to the notice text point /
## place anchor: an opaque body in between blocks it. This is NOT a camera, view cone or
## image proof. It stores runtime references only and never writes to the save; the world
## owns every knowledge grant and re-checks its own distance rules.

const Catalog := preload("res://spatial/town_places.gd")
## The prop's own solid core starts this far above its measured base so the object stands ON the
## market floor instead of intersecting it: the measured paving collider under the notice was the
## only other body reported at its position (game/tests/town_places_clearance_probe.gd).
const GROUND_CLEARANCE := 0.02

var town
var resident_bodies: Dictionary = {}
var visual: Node3D = null
var solid: StaticBody3D = null
var placed := false
var load_failure := ""
var last_observation: Dictionary = {}
var model_bottom := 0.0

func configure(world, bodies: Dictionary) -> void:
	town = world
	resident_bodies = bodies

func build() -> void:
	name = "TownPlaceNotice"
	var notice: Dictionary = Catalog.NOTICE
	var packed := load(str(notice["asset"])) as PackedScene
	if packed == null:
		load_failure = str(notice["asset"])
		push_error("Public notice asset failed to load: " + load_failure)
		return
	var node := packed.instantiate() as Node3D
	if node == null:
		load_failure = str(notice["asset"])
		push_error("Public notice asset is not a Node3D: " + load_failure)
		return
	var position: Array = notice["position"]
	node.position = Vector3(position[0], position[1], position[2])
	node.rotation.y = deg_to_rad(float(notice["yaw"]))
	node.name = "PublicNoticeWaystone"
	node.set_meta("public_notice_id", str(notice["id"]))
	add_child(node)
	visual = node
	_ground_the_prop(node)
	_add_collision(node)
	placed = true

func _model_bounds(node: Node3D) -> AABB:
	var bounds := AABB()
	var first := true
	for mesh in node.find_children("*", "MeshInstance3D", true, false):
		var item: MeshInstance3D = mesh
		var box: AABB = item.transform * item.mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	return bounds

func _ground_the_prop(node: Node3D) -> void:
	## Raises the prop so its own measured base sits on the floor it stands on.
	var bounds := _model_bounds(node)
	if bounds.position.y < 0.0:
		node.position.y -= bounds.position.y
	model_bottom = bounds.position.y

func _add_collision(node: Node3D) -> void:
	## Small solid core from the model's own transformed bounds: the notice stands off the
	## walking line but can still be bumped into, so it is not an invisible marker.
	var bounds := _model_bounds(node)
	if bounds.size == Vector3.ZERO:
		return
	var body := StaticBody3D.new()
	body.name = "PublicNoticeCollision"
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	var bottom := bounds.position.y + GROUND_CLEARANCE
	var height := maxf(bounds.size.y - GROUND_CLEARANCE, 0.4)
	box_shape.size = Vector3(maxf(bounds.size.x * 0.7, 0.24), height, maxf(bounds.size.z * 0.7, 0.24))
	shape.shape = box_shape
	shape.position = Vector3(bounds.get_center().x, bottom + height * 0.5, bounds.get_center().z)
	body.add_child(shape)
	node.add_child(body)
	solid = body
	model_bottom = bottom

func notice_point() -> Vector3:
	var point: Array = Catalog.NOTICE["point"]
	return Vector3(point[0], point[1], point[2])

func _has_line_of_sight(from: Vector3, to: Vector3, allow_self: bool) -> bool:
	if not Engine.is_in_physics_frame() or not is_inside_tree():
		return false
	if not from.is_finite() or not to.is_finite():
		return false
	var space := get_world_3d().direct_space_state if get_world_3d() != null else null
	if space == null:
		return false
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.hit_from_inside = true
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty():
		return true
	if not allow_self or solid == null or not is_instance_valid(solid):
		return false
	return hit.get("collider") == solid

func visible_from(id: String) -> bool:
	var observer := _observer_body(id)
	if observer == null:
		return false
	var eye: Vector3 = observer.global_position + Vector3(0, 1.55, 0)
	return _has_line_of_sight(eye, notice_point(), true)

func place_visible_from(id: String, place_id: String) -> bool:
	var observer := _observer_body(id)
	if observer == null:
		return false
	var anchor := Catalog.point_of(place_id)
	if not anchor.is_finite():
		return false
	var eye: Vector3 = observer.global_position + Vector3(0, 1.55, 0)
	return _has_line_of_sight(eye, anchor + Vector3(0, 1.0, 0), false)

func _observer_body(id: String) -> Node3D:
	var observer: Variant = resident_bodies.get(id)
	if not is_instance_valid(observer) or not observer is Node3D or not (observer as Node3D).is_inside_tree():
		return null
	return observer as Node3D

func observe() -> Dictionary:
	## One bounded perception pass: only what this resident can actually read or see, only
	## what it does not already know. Returns the world's per-resident outcome for evidence.
	if town == null or not placed:
		return {"ok": false, "code": "notice_unavailable"}
	var results: Dictionary = {}
	for id in town.active_ids():
		var observer := _observer_body(id)
		if observer == null:
			continue
		var known: Array = town.known_place_ids(id)
		var notice_readable := visible_from(id)
		var visible_places: Array = []
		for place_value in Catalog.place_ids():
			var place_id := str(place_value)
			if known.has(place_id):
				continue
			if place_visible_from(id, place_id):
				visible_places.append(place_id)
		if not notice_readable and visible_places.is_empty():
			continue
		var outcome: Variant = town.observe_public_places(id, notice_readable, visible_places)
		if outcome is Dictionary and int((outcome as Dictionary).get("learned", []).size()) > 0:
			results[id] = outcome
	last_observation = {"ok": true, "code": "notice_observed", "learned": results.size(), "results": results}
	return last_observation

func evidence() -> Dictionary:
	return {"notice_id": str(Catalog.NOTICE["id"]), "asset": str(Catalog.NOTICE["asset"]),
		"position": Catalog.NOTICE["position"], "point": Catalog.NOTICE["point"],
		"read_range_m": Catalog.NOTICE["read_range_m"], "collision": solid != null,
		"placed": placed, "load_failure": load_failure,
		"visual_position": visual.position if visual != null else Vector3.ZERO,
		"collider_base_offset_m": model_bottom,
		"places": Catalog.place_ids(), "learned_last_pass": last_observation.get("learned", 0)}
