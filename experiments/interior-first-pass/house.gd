extends Node3D
## Stable per-provider components, untouched source assets and authored host collision.
const Module = preload("res://modular_house_component.gd")
var provider := "tripo"
var host
var props := {}
var transforms := {}
var missing: Array[String] = []
var manifests := {}
var support_results := {}

func _ready():
	host = Module.new()
	host.manifest_path = "res://assets/shell/manifest.json"
	host.external_door_visual_path = ""
	host.build_on_ready = false
	host.name = "ModularStructure"
	add_child(host)
	if not host.build():
		push_error("Missing authored house shell")
		return
	_replace_leaf(host.fallback_door_leaf, "door_leaf", "DoorVisual")
	for pivot in host.shutters:
		# Keep a closed shutter outside the fixed sash/mullion thickness, so the
		# two real surfaces do not intersect and flicker. Its collider moves with it.
		var outward: Vector3 = pivot.global_basis.z.normalized()
		if outward.dot(pivot.global_position-global_position) < 0: outward = -outward
		pivot.global_position += outward*0.12
		for child in pivot.get_children():
			if child is MeshInstance3D:
				_replace_leaf(child, "shutter_leaf", "ShutterVisual")
				break
		_add_mesh_collision(pivot, "ShutterPhysical", false)
	# The shared module already owns shell, moving door and moving sash collision.
	# Include roof, porch supports, trim and window frames rather than leaving visual-only solids.
	for child in host.instance.get_children():
		if child is MeshInstance3D and child.name != "BuildingShell":
			_add_mesh_collision(child, "StructurePhysical", false)
	for unit in host.instance.find_children("WindowFrame_*", "MeshInstance3D", true, false):
		_add_mesh_collision(unit, "FramePhysical", false)
	_floor()
	_furnish()
	_lights()
	host.set_door_open(false)
	host.set_window_open(false)
	set_meta("provider", provider)

func bounds(root: Node3D) -> AABB:
	var result := AABB()
	var started := false
	for n in root.find_children("*", "MeshInstance3D", true, false):
		if not n.visible or n.mesh == null:
			continue
		# Exact transformed vertices avoid loose rotated AABBs making a laid-down sword float.
		var transform: Transform3D = root.global_transform.affine_inverse() * n.global_transform
		for surface in range(n.mesh.get_surface_count()):
			var arrays = n.mesh.surface_get_arrays(surface)
			for vertex in arrays[Mesh.ARRAY_VERTEX]:
				var point: Vector3 = transform * vertex
				result = result.expand(point) if started else AABB(point,Vector3.ZERO)
				started = true
	return result

func _asset(id: String) -> Node3D:
	var path := "res://assets/%s/%s.glb" % [provider, id]
	if not ResourceLoader.exists(path):
		if not missing.has(id): missing.append(id)
		push_warning("Missing first result, no replacement: " + path)
		return null
	var packed = load(path)
	var root: Node3D = packed.instantiate()
	root.name = id
	return root

func _replace_leaf(original: MeshInstance3D, id: String, label: String):
	if original == null: return
	var replacement = _asset(id)
	if replacement == null: return
	var parent := original.get_parent()
	var anchor := Node3D.new()
	anchor.name = label
	parent.add_child(anchor)
	anchor.transform = original.transform
	anchor.add_child(replacement)
	var source := bounds(anchor)
	if source.size.x < source.size.z:
		replacement.rotate_y(PI*0.5)
		source = bounds(anchor)
	var target: AABB = original.get_aabb()
	# Dimensional fitting is an explicit assembly transform, not a repaired/regenerated mesh.
	var scale_fit := target.size / source.size.max(Vector3(0.0001,0.0001,0.0001))
	replacement.scale *= scale_fit
	replacement.position += target.get_center() - source.get_center() * scale_fit
	original.visible = false
	anchor.set_meta("asset_id", provider + "/" + id)
	anchor.set_meta("raw_source", "assets/%s/%s.glb" % [provider,id])
	transforms[label + str(transforms.size())] = {"id":id,"fit_xyz":[scale_fit.x,scale_fit.y,scale_fit.z],"fit_reason":"existing hinge aperture"}

func _add_mesh_collision(root: Node3D, label: String, include_root: bool = true):
	var meshes: Array = root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D: meshes.append(root)
	for mesh in meshes:
		if not mesh.visible or mesh.mesh == null: continue
		if mesh.find_child(label, false, false) != null: continue
		var body := StaticBody3D.new()
		body.name = label
		var shape := CollisionShape3D.new()
		shape.shape = mesh.mesh.create_trimesh_shape()
		body.add_child(shape)
		mesh.add_child(body)

func _floor():
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("927352")
	mat.roughness = 0.85
	for i in range(25):
		var plank := MeshInstance3D.new()
		plank.name = "FloorPlank_%02d" % i
		var box := BoxMesh.new()
		box.size = Vector3(0.30,0.018,6.42)
		plank.mesh = box
		plank.material_override = mat
		plank.position = Vector3(-3.60 + i*0.30,0.015,0)
		add_child(plank)

func place(id: String, tag: String, pos: Vector3, max_size: float, yaw: float = 0.0) -> Node3D:
	var source = _asset(id)
	if source == null: return null
	var anchor := Node3D.new()
	anchor.name = tag
	add_child(anchor)
	anchor.add_child(source)
	if id == "sword" and FileAccess.file_exists("res://assembly-axes.json"):
		var rotations = JSON.parse_string(FileAccess.get_file_as_string("res://assembly-axes.json"))
		var rows = rotations[provider+"/sword"].rotation_rows
		var rotation := Basis(Vector3(rows[0][0],rows[1][0],rows[2][0]),Vector3(rows[0][1],rows[1][1],rows[2][1]),Vector3(rows[0][2],rows[1][2],rows[2][2]))
		source.basis = rotation * source.basis
	var raw := bounds(anchor)
	# Align furniture footprints for assembly; never change the original GLB.
	if (id == "bed" and raw.size.x > raw.size.z) or (id in ["table","workbench","weapon_rack","shelf"] and raw.size.z > raw.size.x):
		source.rotate_y(PI*0.5)
		raw = bounds(anchor)
	var size_max: float = max(raw.size.x, max(raw.size.y,raw.size.z))
	var factor: float = max_size / maxf(size_max, 0.0001)
	source.scale *= factor
	source.position = Vector3(-raw.get_center().x, -raw.position.y, -raw.get_center().z) * factor
	anchor.position = pos
	anchor.rotation.y = deg_to_rad(yaw)
	anchor.set_meta("asset_id", provider + "/" + id)
	anchor.set_meta("instance_id", provider + "/" + tag)
	anchor.set_meta("raw_source", "assets/%s/%s.glb" % [provider,id])
	_add_mesh_collision(anchor, "PropCollision")
	props[tag] = anchor
	transforms[tag] = {"id":id,"uniform_scale":factor,"position":[pos.x,pos.y,pos.z],"yaw_degrees":yaw}
	return anchor

func top(tag: String) -> float:
	var node: Node3D = props[tag]
	var b := bounds(node)
	return node.position.y + b.end.y

func _furnish():
	place("bed", "Bed", Vector3(-2.65,0.03,-1.65),2.1)
	place("chest", "Chest", Vector3(-2.7,0.03,0.0),1.0)
	place("hearth", "CookingHearth", Vector3(-3.0,0.03,1.85),1.9,90)
	place("workbench", "Workbench", Vector3(2.5,0.03,-2.6),1.8)
	place("anvil", "Anvil", Vector3(2.9,0.03,-0.65),0.85)
	place("weapon_rack", "WeaponRack", Vector3(3.0,0.03,1.5),1.5,-90)
	place("shelf", "Shelf", Vector3(-0.4,0.03,-2.92),1.8)
	place("table", "DiningTable", Vector3(0.3,0.03,-0.15),1.35)
	place("chair", "DiningChairA", Vector3(-0.9,0.03,-0.15),0.95,90)
	place("chair", "DiningChairB", Vector3(1.45,0.03,-0.15),0.95,-90)
	if props.has("Workbench"):
		place("sword", "Sword", Vector3(2.25,top("Workbench")+0.015,-2.45),1.0)
		place("lantern", "WorkLantern", Vector3(3.03,top("Workbench")+0.015,-2.58),0.35)
	place("shield", "Shield", Vector3(2.9,0.04,2.28),0.65,-90)
	if props.has("DiningTable"):
		var y := top("DiningTable")+0.015
		place("meal", "MealA", Vector3(-0.05,y,-0.1),0.3)
		place("meal", "MealB", Vector3(0.7,y,-0.1),0.3,180)
		place("jug", "WaterJug", Vector3(0.3,y,-0.35),0.3)
		place("potion", "PotionA", Vector3(0.2,y,0.1),0.18)
		place("potion", "PotionB", Vector3(0.43,y,0.1),0.18)
	place("lantern", "BedLantern", Vector3(-3.45,0.03,0.0),0.35)
	place("cooking_pot", "CookingPot", Vector3(-2.1,0.03,2.1),0.4)

func _lights():
	for pos in [Vector3(0.0,2.6,0.0),Vector3(-2.5,2.0,-1.1),Vector3(2.5,2.0,-1.8)]:
		var light := OmniLight3D.new()
		light.position = pos
		light.light_color = Color(1.0,0.89,0.72)
		light.light_energy = 0.4 if pos.x==0 else 0.23
		light.omni_range = 6.0
		light.shadow_enabled = pos.x==0
		add_child(light)

func settle_contents():
	var supports := {"Sword":"Workbench","WorkLantern":"Workbench","MealA":"DiningTable","MealB":"DiningTable","WaterJug":"DiningTable","PotionA":"DiningTable","PotionB":"DiningTable"}
	await get_tree().physics_frame
	await get_tree().physics_frame
	for tag in supports:
		if not props.has(tag) or not props.has(supports[tag]): continue
		var item: Node3D = props[tag]
		var support: Node3D = props[supports[tag]]
		var point: Vector3 = item.global_position
		var query := PhysicsRayQueryParameters3D.create(Vector3(point.x,global_position.y+top(supports[tag])+0.15,point.z),Vector3(point.x,global_position.y-0.15,point.z))
		var excluded: Array[RID] = []
		for other in props.values():
			if other == support: continue
			for body in other.find_children("PropCollision","StaticBody3D",true,false): excluded.append(body.get_rid())
		query.exclude = excluded
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		var valid: bool = not hit.is_empty() and support.is_ancestor_of(hit.collider)
		support_results[tag] = valid
		if valid:
			item.global_position.y = hit.position.y-bounds(item).position.y+0.006
			transforms[tag].position = [item.position.x,item.position.y,item.position.z]
			transforms[tag].support = supports[tag]
		else: push_warning(provider+" cannot seat "+tag+" on "+supports[tag])

func serialize_state() -> Dictionary:
	return {"provider":provider,"door_open":host.is_door_open(),"windows_open":host.is_window_open()}

func apply_state(data: Dictionary):
	host.set_door_open(bool(data.get("door_open",false)))
	host.set_window_open(bool(data.get("windows_open",false)))
