extends SceneTree
## Offline acceptance for the modular floor-1 houses.
##
## Run:
##   <godot> --headless --path game --script res://tests/modular_house_acceptance.gd
##
## Checks real imported GLBs: separate semantic parts, bounded triangles, a player-size capsule
## (radius 0.30, height 1.70, grounded with 0.03 m clearance so it never touches the floor coplanar)
## that is blocked by the closed door leaf and walks through the true doorway when the door is open,
## the same walk repeated on a 90-degree rotated instance and against a solid wall, window sash
## travel plus exact restoration, and independence of two instances.

const MANIFEST := "res://assets/floor1/modular_houses_20260916/manifest.json"
const ASSET_DIR := "res://assets/floor1/modular_houses_20260916/"
const VARIANTS := ["01_hearth_cottage", "02_market_house", "03_corner_turret"]
const TRIANGLE_MIN := 1000
const TRIANGLE_MAX := 30000
const CAPSULE_RADIUS := 0.30
const CAPSULE_HEIGHT := 1.70
const GROUND_CLEARANCE := 0.03

var checks := 0
var failures := 0
var labels: Array[String] = []
var report := {"variants": [], "checks": 0, "failures": 0}


func _initialize() -> void:
	run.call_deferred()


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		labels.append(label)
		print("FAIL ", label)


func run() -> void:
	for variant in VARIANTS:
		await _check_variant(variant)
	await _check_two_instances()
	await _check_rotated_instance()
	await _check_swapped_complete_door_unit()
	report["checks"] = checks
	report["failures"] = failures
	report["failure_labels"] = labels
	report["paid_calls"] = 0
	print(JSON.stringify(report))
	quit(1 if failures > 0 else 0)


func _check_variant(variant: String) -> void:
	var entry := {"variant": variant}
	var house := ModularHouseComponent.new()
	house.variant_id = variant
	house.manifest_path = MANIFEST
	root.add_child(house)
	await process_frame
	await physics_frame
	var built: bool = house.build()
	check(built, "%s builds from its exported GLB" % variant)
	if not built:
		report["variants"].append(entry)
		return
	var instance: Node3D = house.instance
	entry["instance"] = instance != null
	for part in ["BuildingShell", "Roof", "DoorFrame", "DoorPivot", "DoorLeaf"]:
		check(instance.find_child(part, true, false) != null, "%s has semantic part %s" % [variant, part])
	check(house.sashes.size() >= 4, "%s exposes window sashes (%d)" % [variant, house.sashes.size()])
	check(house.shutters.size() >= 4, "%s exposes hinged shutters (%d)" % [variant, house.shutters.size()])
	entry["sashes"] = house.sashes.size()
	entry["shutters"] = house.shutters.size()
	var triangles := _count_triangles(instance)
	entry["triangles"] = triangles
	check(triangles >= TRIANGLE_MIN and triangles <= TRIANGLE_MAX,
		"%s triangle count %d is inside %d..%d" % [variant, triangles, TRIANGLE_MIN, TRIANGLE_MAX])
	var opening := house.door_opening_godot()
	check(not opening.is_empty(), "%s publishes its doorway in Godot coordinates" % variant)
	if opening.is_empty():
		report["variants"].append(entry)
		return
	entry["doorway"] = {"centre": str(opening["centre"]), "outward": str(opening["outward"])}
	var doorway_world: Vector3 = house.global_transform * opening["centre"]
	var outward_world: Vector3 = (house.global_transform.basis * opening["outward"]).normalized()
	# closed door blocks the capsule
	house.set_door_open(false)
	await physics_frame
	var blocked := await _walk(doorway_world, outward_world)
	var blocked_distance: float = blocked["signed_distance"]
	entry["closed_distance"] = snappedf(blocked_distance, 0.001)
	check(blocked_distance > -0.05,
		"%s closed door blocks a player-size capsule (signed %.3f m, outside is positive)" % [variant, blocked_distance])
	# open door lets the capsule reach the interior
	house.set_door_open(true)
	await physics_frame
	var passed := await _walk(doorway_world, outward_world)
	var passed_distance: float = passed["signed_distance"]
	entry["open_distance"] = snappedf(passed_distance, 0.001)
	check(passed_distance < -0.60,
		"%s open door lets the capsule walk inside (signed %.3f m)" % [variant, passed_distance])
	if variant == "02_market_house":
		var shop := instance.find_child("ShopBay", true, false) as MeshInstance3D
		var posts := shop.find_child("ShopBayPostCollision", true, false) as StaticBody3D if shop != null else null
		check(shop != null and posts != null and posts.get_child_count() == 2,
			"merchant two visible outer-pier canopy posts have matching physical shapes")
		var visual_hit := await _shopbay_visual_door_hit(house, shop, opening)
		check(visual_hit.is_empty(),
			"merchant actual imported ShopBay triangles leave the eye-height doorway centre clear")
		entry["shopbay_visual_door_hit"] = str(visual_hit)
		var side_distances := {}
		for side in ["shop_post_left", "shop_post_right"]:
			var post_entry := _collision_entry(house, side)
			if post_entry.is_empty():
				check(false, "merchant %s authored collision proxy is present" % side)
				continue
			var point: Array = post_entry["centre_local"]
			var local_centre := Vector3(float(point[0]), opening["centre"].y, opening["centre"].z)
			var walked := await _walk(house.global_transform * local_centre, outward_world)
			var distance: float = walked["signed_distance"]
			side_distances[side] = snappedf(distance, 0.001)
			check(distance > 0.60,
				"merchant %s actually stops the capsule ahead of the wall (signed %.3f m)" % [side, distance])
		entry["shop_post_capsule_distances"] = side_distances
	# Probe the centre of a real solid front pier, derived from all ground-floor
	# aperture spans. A fixed offset could land at a footprint corner or window.
	var wall_local := _solid_front_pier_local(house, opening)
	check(not wall_local.is_zero_approx(), "%s has a measurable solid front pier" % variant)
	var wall_probe := await _walk(house.global_transform * wall_local, outward_world)
	check(float(wall_probe["signed_distance"]) > -0.05,
		"%s manifest-derived solid pier blocks a capsule (signed %.3f m)" % [variant, wall_probe["signed_distance"]])
	entry["wall_probe_distance"] = snappedf(float(wall_probe["signed_distance"]), 0.001)
	# window travel and exact restoration
	var sash: Node3D = house.sashes[0]
	var before_transform := sash.transform
	var closed_position := sash.position
	var shutter: Node3D = house.shutters[0]
	var shutter_before := shutter.rotation
	var facade_windows := _facade_windows(house)
	check(facade_windows.size() == 4, "%s has front, back and both side window openings" % variant)
	var closed_window_hits := {}
	for facade in ["front", "back", "left", "right"]:
		if not facade_windows.has(facade):
			continue
		var closed_hit := await _window_ray(house, facade_windows[facade])
		closed_window_hits[facade] = closed_hit
		check(closed_hit.begins_with("WindowCollision_"),
			"%s closed %s window pane blocks a ray (%s)" % [variant, facade, closed_hit])
	entry["closed_window_rays"] = closed_window_hits
	var closed_clearance := _door_window_mesh_clearance(house, opening)
	entry["closed_window_mesh_clearance"] = closed_clearance
	check(closed_clearance["overlaps"].is_empty(),
		"%s closed window render meshes clear doorway shoulder/head (%s)" % [variant, closed_clearance["overlaps"]])
	house.set_window_open(true)
	await physics_frame
	var travel := sash.position.y - closed_position.y
	check(travel > 0.30, "%s sash travels upward (%.3f m)" % [variant, travel])
	check(not shutter.rotation.is_equal_approx(shutter_before), "%s shutter swings when open" % variant)
	var open_window_hits := {}
	for facade in ["front", "back", "left", "right"]:
		if not facade_windows.has(facade):
			continue
		var open_hit := await _window_ray(house, facade_windows[facade])
		open_window_hits[facade] = open_hit
		check(open_hit == "clear", "%s open %s window has a genuine wall aperture (%s)" % [variant, facade, open_hit])
	entry["open_window_rays"] = open_window_hits
	var open_clearance := _door_window_mesh_clearance(house, opening)
	entry["open_window_mesh_clearance"] = open_clearance
	check(open_clearance["overlaps"].is_empty(),
		"%s open window render meshes clear doorway shoulder/head (%s)" % [variant, open_clearance["overlaps"]])
	house.set_window_open(false)
	await physics_frame
	check(sash.transform.is_equal_approx(before_transform),
		"%s closed window restores the exact sash transform" % variant)
	check(shutter.rotation.is_equal_approx(shutter_before),
		"%s closed shutter restores its authored facade rotation" % variant)
	entry["window_travel"] = snappedf(travel, 0.001)
	# Detach/reinsert the actual complete front unit. Its moving pane collider must
	# leave with the sash while the authored wall hole remains clear; the other
	# windows and the semantic house shell are untouched.
	var unit_count := 0
	for node in _all_children(instance):
		if String(node.name).begins_with("WindowUnit_"):
			unit_count += 1
	check(unit_count == house.sashes.size(),
		"%s has one addressable complete WindowUnit per sash (%d)" % [variant, unit_count])
	var unit := instance.find_child("WindowUnit_00", true, false) as Node3D
	check(unit != null, "%s front window unit is an actual detachable scene node" % variant)
	if unit != null and facade_windows.has("front"):
		check(unit.find_child("WindowFrame_00", true, false) != null
			and unit.find_child("WindowSash_00", true, false) != null
			and unit.find_child("ShutterPivot_L_00", true, false) != null
			and unit.find_child("ShutterPivot_R_00", true, false) != null,
			"%s complete front unit owns frame, sash and both shutter hinges" % variant)
		var parent := unit.get_parent()
		var rest := unit.transform
		parent.remove_child(unit)
		await physics_frame
		var detached_hit := await _window_ray(house, facade_windows["front"])
		check(detached_hit == "clear",
			"%s detached unit removes its pane collider from the true wall hole (%s)" % [variant, detached_hit])
		parent.add_child(unit)
		unit.transform = rest
		await physics_frame
		var restored_hit := await _window_ray(house, facade_windows["front"])
		check(restored_hit.begins_with("WindowCollision_"),
			"%s reattached unit restores the pane collider at the original aperture (%s)" % [variant, restored_hit])
		entry["unit_detach_reattach"] = {"detached": detached_hit, "restored": restored_hit}
	# The complete door frame/hinge/leaf/physical collider must leave as one
	# reusable assembly. A real grounded capsule then walks through the empty
	# shell aperture; reinstalling restores the exact facade pose and blocking.
	house.set_door_open(false)
	await physics_frame
	var whole_door := house.door_unit_node()
	check(whole_door != null, "%s has a real complete DoorUnit node" % variant)
	if whole_door != null:
		var frame := whole_door.find_child("DoorFrame", true, false) as MeshInstance3D
		var hinge := whole_door.find_child("DoorPivot", true, false) as Node3D
		var leaf := whole_door.find_child("DoorLeaf", true, false) as Node3D
		var moving_collider := whole_door.find_child("DoorCollision", true, false) as StaticBody3D
		check(frame != null and hinge != null and leaf != null
			and moving_collider != null and moving_collider.get_parent() == hinge,
			"%s whole door owns frame, hinge, fallback leaf and moving collider" % variant)
		var frame_pose := frame.global_transform
		var removed := house.detach_door_unit()
		await physics_frame
		check(removed == whole_door and removed.get_parent() == null
			and house.door_pivot == null and house.door_collision == null,
			"%s removing DoorUnit removes its entire moving physical assembly" % variant)
		var passage_without_unit: float = float((await _walk(doorway_world, outward_world))["signed_distance"])
		check(passage_without_unit < -0.60,
			"%s detached whole door leaves real aperture clear for grounded capsule (%.3f)" %
			[variant, passage_without_unit])
		check(house.install_door_unit(removed),
			"%s detached complete DoorUnit reinstalls at authored anchor" % variant)
		await physics_frame
		check(frame.global_transform.is_equal_approx(frame_pose),
			"%s full door frame restores identical facade pose after reinstall" % variant)
		var blocked_again: float = float((await _walk(doorway_world, outward_world))["signed_distance"])
		check(blocked_again > -0.05,
			"%s reinstalled closed DoorUnit blocks grounded capsule (%.3f)" % [variant, blocked_again])
		house.set_door_open(true)
		await physics_frame
		var open_again: float = float((await _walk(doorway_world, outward_world))["signed_distance"])
		check(open_again < -0.60,
			"%s reinstalled hinge/collider opens the passage (%.3f)" % [variant, open_again])
		entry["door_unit_detach_reattach"] = {"empty": passage_without_unit,
			"closed": blocked_again, "open": open_again}
	report["variants"].append(entry)
	house.queue_free()
	await process_frame


func _check_swapped_complete_door_unit() -> void:
	# The common 1.2 x 2.2 m assembly can truly replace a different variant's
	# frame, leaf, hinge and travelling collider. Both houses are rotated and
	# translated; a mere visual-leaf swap cannot satisfy this physical check.
	var donor := ModularHouseComponent.new()
	donor.variant_id = "01_hearth_cottage"
	donor.build_on_ready = false
	donor.position = Vector3(40.0, 0.0, -20.0)
	donor.rotation_degrees.y = -90.0
	root.add_child(donor)
	var recipient := ModularHouseComponent.new()
	recipient.variant_id = "02_market_house"
	recipient.build_on_ready = false
	recipient.position = Vector3(60.0, 0.0, -20.0)
	recipient.rotation_degrees.y = 90.0
	root.add_child(recipient)
	await process_frame
	await physics_frame
	var ready := donor.build() and recipient.build()
	check(ready, "cross-variant replacement houses build at independent rotated poses")
	if not ready:
		donor.queue_free()
		recipient.queue_free()
		await process_frame
		return
	var opening := recipient.door_opening_godot()
	var centre: Vector3 = recipient.global_transform * opening["centre"]
	var outward: Vector3 = (recipient.global_transform.basis * opening["outward"]).normalized()
	var old_frame := recipient.door_unit_node().find_child("DoorFrame", true, false) as MeshInstance3D
	var expected_frame_pose := old_frame.global_transform
	var original_recipient_unit := recipient.detach_door_unit()
	var donor_unit := donor.detach_door_unit()
	await physics_frame
	check(original_recipient_unit != null and donor_unit != null
		and original_recipient_unit.get_parent() == null and donor_unit.get_parent() == null,
		"two complete DoorUnits detach without changing either shell aperture")
	check(recipient.install_door_unit(donor_unit),
		"cottage complete DoorUnit replaces market door frame, hinge, leaf and collider")
	await physics_frame
	var transplanted_frame := recipient.door_unit_node().find_child("DoorFrame", true, false) as MeshInstance3D
	check(transplanted_frame.global_transform.is_equal_approx(expected_frame_pose),
		"transplanted whole door aligns to rotated recipient facade exactly")
	recipient.set_door_open(false)
	await physics_frame
	var closed: float = float((await _walk(centre, outward))["signed_distance"])
	check(closed > -0.05,
		"cross-variant transplanted closed door blocks grounded capsule (%.3f)" % closed)
	recipient.set_door_open(true)
	await physics_frame
	var opened: float = float((await _walk(centre, outward))["signed_distance"])
	check(opened < -0.60,
		"cross-variant transplanted hinge/collider opens real passage (%.3f)" % opened)
	var returned_donor_unit := recipient.detach_door_unit()
	check(donor.install_door_unit(returned_donor_unit)
		and recipient.install_door_unit(original_recipient_unit),
		"both original complete door assemblies reinstall independently after swap")
	await physics_frame
	recipient.set_door_open(false)
	var restored: float = float((await _walk(centre, outward))["signed_distance"])
	check(restored > -0.05,
		"recipient original closed DoorUnit still blocks after restoration (%.3f)" % restored)
	report["swapped_door_unit"] = {"donor": donor.variant_id,
		"recipient": recipient.variant_id, "recipient_yaw": recipient.rotation_degrees.y,
		"closed": closed, "open": opened, "restored": restored}
	donor.queue_free()
	recipient.queue_free()
	await process_frame


func _walk(centre: Vector3, outward: Vector3) -> Dictionary:
	var body := CharacterBody3D.new()
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = CAPSULE_RADIUS
	capsule.height = CAPSULE_HEIGHT
	collider.shape = capsule
	body.add_child(collider)
	root.add_child(body)
	var start := centre + outward * 2.4
	start.y = CAPSULE_HEIGHT * 0.5 + GROUND_CLEARANCE
	body.global_position = start
	var direction := -outward
	var steps := 0
	while steps < 180:
		body.velocity = direction * 2.0
		body.move_and_slide()
		await physics_frame
		steps += 1
		if (body.global_position - centre).dot(outward) < -0.8:
			break
	var final := body.global_position
	body.queue_free()
	await physics_frame
	return {"signed_distance": (final - centre).dot(outward), "steps": steps, "final": final}


func _collision_entry(house: ModularHouseComponent, id: String) -> Dictionary:
	for item in house.house.get("collision", []):
		if String(item.get("id", "")) == id:
			return item
	return {}


func _shopbay_visual_door_hit(house: ModularHouseComponent, shop: MeshInstance3D,
		opening: Dictionary) -> Dictionary:
	if shop == null or shop.mesh == null:
		return {"missing_shopbay_mesh": true}
	var shape := shop.mesh.create_trimesh_shape()
	if shape == null:
		return {"missing_shopbay_trimesh": true}
	var visual_body := StaticBody3D.new()
	visual_body.name = "ShopBayVisualRayOnly"
	visual_body.collision_layer = 1 << 19
	visual_body.collision_mask = 0
	var visual_shape := CollisionShape3D.new()
	visual_shape.shape = shape
	visual_body.add_child(visual_shape)
	shop.add_child(visual_body)
	await physics_frame
	var eye_local: Vector3 = opening["centre"]
	eye_local.y = 1.62
	var outward: Vector3 = opening["outward"]
	var from: Vector3 = house.global_transform * (eye_local + outward * 1.6)
	var to: Vector3 = house.global_transform * (eye_local - outward * 1.3)
	var query := PhysicsRayQueryParameters3D.create(from, to, 1 << 19)
	var hit := root.world_3d.direct_space_state.intersect_ray(query)
	visual_body.queue_free()
	await physics_frame
	return hit


func _facade_windows(house: ModularHouseComponent) -> Dictionary:
	var found := {}
	for item in house.house.get("openings", []):
		if String(item.get("kind", "")) != "window":
			continue
		var outward: Array = item["outward"]
		var facade := ""
		if float(outward[1]) < -0.9:
			facade = "front"
		elif float(outward[1]) > 0.9:
			facade = "back"
		elif float(outward[0]) < -0.9:
			facade = "left"
		elif float(outward[0]) > 0.9:
			facade = "right"
		if not facade.is_empty() and not found.has(facade):
			found[facade] = item
	return found


func _door_window_mesh_clearance(house: ModularHouseComponent, doorway: Dictionary) -> Dictionary:
	# Inspect actual imported mesh vertices after every facade yaw and shutter pivot
	# transform. Physics can pass while decorative leaves cover the upper aperture.
	var centre: Vector3 = doorway["centre"]
	var width: float = doorway["size"].x
	var height: float = doorway["size"].y
	var shoulder := 0.06
	var aperture := AABB(Vector3(centre.x - width * 0.5 - shoulder,
		centre.y - height * 0.5 + 0.10, centre.z - 0.44),
		Vector3(width + shoulder * 2.0, height - 0.17, 0.88))
	var overlaps: Array[String] = []
	var meshes := 0
	for node in _all_children(house.instance):
		var mesh_node := node as MeshInstance3D
		if mesh_node == null or mesh_node.mesh == null:
			continue
		var name := String(mesh_node.name)
		if not (name.begins_with("Shutter_") or name.begins_with("WindowFrame_")
				or name.begins_with("WindowSash_")):
			continue
		meshes += 1
		var local_from_mesh: Transform3D = house.global_transform.affine_inverse() * mesh_node.global_transform
		var minimum := Vector3(INF, INF, INF)
		var maximum := Vector3(-INF, -INF, -INF)
		for surface in mesh_node.mesh.get_surface_count():
			var vertices: PackedVector3Array = mesh_node.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			for vertex in vertices:
				var local_vertex: Vector3 = local_from_mesh * vertex
				minimum = minimum.min(local_vertex)
				maximum = maximum.max(local_vertex)
		if minimum.x != INF and AABB(minimum, maximum - minimum).intersects(aperture):
			overlaps.append(name)
	return {"meshes_examined": meshes, "overlaps": overlaps}


func _all_children(parent: Node) -> Array[Node]:
	var found: Array[Node] = []
	var stack: Array[Node] = [parent]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		for child in current.get_children():
			found.append(child)
			stack.append(child)
	return found


func _solid_front_pier_local(house: ModularHouseComponent, doorway: Dictionary) -> Vector3:
	var spaces: Array = house.house.get("spaces", [])
	if spaces.is_empty():
		return Vector3.ZERO
	var x_range: Array = spaces[0]["x"]
	var left := float(x_range[0])
	var right := float(x_range[1])
	var occupied: Array[Vector2] = []
	var boundaries: Array[float] = [left, right]
	for item in house.house.get("openings", []):
		var outward: Array = item["outward"]
		var centre: Array = item["centre"]
		var size: Array = item["size"]
		if float(outward[1]) > -0.9 or float(centre[2]) > 2.35:
			continue
		var a := maxf(left, float(centre[0]) - float(size[0]) * 0.5)
		var b := minf(right, float(centre[0]) + float(size[0]) * 0.5)
		if b <= a:
			continue
		occupied.append(Vector2(a, b))
		boundaries.append(a)
		boundaries.append(b)
	boundaries.sort()
	var best_width := 0.0
	var best_u := 0.0
	for i in range(boundaries.size() - 1):
		var a := boundaries[i]
		var b := boundaries[i + 1]
		var mid := (a + b) * 0.5
		var is_hole := false
		for span in occupied:
			if span.x < mid and mid < span.y:
				is_hole = true
				break
		if b - a <= best_width or is_hole:
			continue
		best_width = b - a
		best_u = mid
	if best_width < 1.0:
		return Vector3.ZERO
	var door_centre: Vector3 = doorway["centre"]
	return Vector3(best_u, door_centre.y, door_centre.z)


func _window_ray(house: ModularHouseComponent, opening: Dictionary) -> String:
	var author_centre: Array = opening["centre"]
	var author_outward: Array = opening["outward"]
	var author_size: Array = opening["size"]
	var local_centre := Vector3(float(author_centre[0]),
		float(author_centre[2]) - float(author_size[2]) * 0.5 + 0.21,
		-float(author_centre[1]))
	var local_outward := Vector3(float(author_outward[0]),
		float(author_outward[2]), -float(author_outward[1])).normalized()
	var centre: Vector3 = house.global_transform * local_centre
	var outward: Vector3 = (house.global_transform.basis * local_outward).normalized()
	var query := PhysicsRayQueryParameters3D.create(centre + outward * 1.0,
		centre - outward * 1.0)
	var hit := root.world_3d.direct_space_state.intersect_ray(query)
	await physics_frame
	if hit.is_empty():
		return "clear"
	var collider: Object = hit.get("collider")
	return String(collider.name) if collider != null else "unknown"


func _count_triangles(root_node: Node) -> int:
	var total := 0
	var stack: Array[Node] = [root_node]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		for child in current.get_children():
			stack.append(child)
		var mesh_instance := current as MeshInstance3D
		if mesh_instance != null and mesh_instance.mesh != null:
			for surface in mesh_instance.mesh.get_surface_count():
				var arrays: Array = mesh_instance.mesh.surface_get_arrays(surface)
				var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				if indices.size() > 0:
					total += indices.size() / 3
				else:
					total += arrays[Mesh.ARRAY_VERTEX].size() / 3
	return total


func _check_two_instances() -> void:
	var first := ModularHouseComponent.new()
	first.variant_id = "01_hearth_cottage"
	first.manifest_path = MANIFEST
	root.add_child(first)
	var second := ModularHouseComponent.new()
	second.variant_id = "01_hearth_cottage"
	second.manifest_path = MANIFEST
	root.add_child(second)
	await process_frame
	await physics_frame
	check(first.build() and second.build(), "two instances of the same variant build")
	first.set_door_open(true)
	second.set_door_open(false)
	await process_frame
	check(first.is_door_open() and not second.is_door_open(), "door state is per instance")
	check(first.instance != second.instance, "each instance owns its own GLB scene")
	check(not first.instance.find_child("DoorPivot", true, false).rotation.is_equal_approx(
			second.instance.find_child("DoorPivot", true, false).rotation),
		"one instance moving its door does not move the other")
	first.set_window_open(true)
	await process_frame
	var second_sash: Node3D = second.sashes[0]
	check(second_sash.position.is_equal_approx(second._sash_closed[second_sash]),
		"window state is per instance")
	# exact restoration for both instances after a full open/close cycle
	var first_pivot: Node3D = first.instance.find_child("DoorPivot", true, false)
	var second_pivot: Node3D = second.instance.find_child("DoorPivot", true, false)
	var first_sash_transform: Transform3D = first.sashes[0].transform
	var second_sash_transform: Transform3D = second.sashes[0].transform
	first.set_door_open(true)
	second.set_window_open(true)
	await process_frame
	first.set_door_open(false)
	second.set_window_open(false)
	await process_frame
	check(first_pivot.rotation.is_equal_approx(first._door_closed_rotation),
		"instance A door transform restores its authored facade yaw exactly")
	check(second_sash.position.is_equal_approx(second._sash_closed[second_sash]),
		"instance B window transform restores exactly")
	check(first.sashes[0].transform.is_equal_approx(first_sash_transform),
		"instance A window was never disturbed by instance B")
	check(second.sashes[0].transform.is_equal_approx(second_sash_transform),
		"instance B window restored to its own original transform")
	first.queue_free()
	second.queue_free()
	await physics_frame


func _check_rotated_instance() -> void:
	## Same doorway test with the whole house rotated 90 degrees: proves the test does not depend on
	## axis-aligned geometry and that rotated collision really blocks/opens.
	var holder := Node3D.new()
	holder.position = Vector3(20.0, 0.0, -15.0)
	holder.rotation = Vector3(0.0, deg_to_rad(90.0), 0.0)
	root.add_child(holder)
	var house := ModularHouseComponent.new()
	house.variant_id = "02_market_house"
	house.manifest_path = MANIFEST
	holder.add_child(house)
	await process_frame
	await physics_frame
	check(house.build(), "rotated instance builds")
	var opening := house.door_opening_godot()
	var doorway_world: Vector3 = house.global_transform * opening["centre"]
	var outward_world: Vector3 = (house.global_transform.basis * opening["outward"]).normalized()
	house.set_door_open(false)
	await physics_frame
	var blocked: float = float((await _walk(doorway_world, outward_world))["signed_distance"])
	check(blocked > -0.05, "rotated instance: closed door blocks the capsule (signed %.3f m)" % blocked)
	house.set_door_open(true)
	await physics_frame
	var passed: float = float((await _walk(doorway_world, outward_world))["signed_distance"])
	check(passed < -0.60, "rotated instance: open door lets the capsule inside (signed %.3f m)" % passed)
	report["rotated"] = {"variant": "02_market_house", "yaw_deg": 90.0,
		"position": str(holder.position),
		"closed_distance": snappedf(blocked, 0.001), "open_distance": snappedf(passed, 0.001)}
	holder.queue_free()
	await process_frame
