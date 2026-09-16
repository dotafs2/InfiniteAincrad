extends "res://spatial/floor1_modular_interior.gd"
## Real independent first-pass Meshy props. Furniture appearance grants no items or skills.
const PROP_ROOT := "res://assets/floor1/living_props_20260916/"

func _build_home() -> void:
	_furnish("home")

func _build_bakery() -> void:
	_furnish("market")

func _build_artisan() -> void:
	_furnish("artisan")

func _furnish(kind: String) -> void:
	var narrow := kind == "market"
	_prop("bed",Vector3(-1.92 if narrow else -2.4,0.03,-2.7 if narrow else -1.8),Vector3(1.55,1.2,2.05))
	_prop("table",Vector3(1.85,0.03,-1.0),Vector3(1.55,.86,1.0))
	_prop("chair",Vector3(1.85,0.03,.15),Vector3(.58,1.10,.60))
	_prop("chest",Vector3(-2.08 if narrow else -2.8,0.03,1.9),Vector3(1.04,.72,.62))
	_prop("hearth",Vector3(2.15 if narrow else 2.5,0.03,-3.78 if narrow else -2.9),Vector3(1.08,1.65,.65))
	_prop("jug",Vector3(1.94,.90,-1.08),Vector3(.24,.38,.24),false)
	_prop("shelf",Vector3(2.65 if narrow else 3.45,0.03,1.9),Vector3(.48,1.75,1.2))
	if kind == "artisan":
		_prop("workbench",Vector3(-2.7,0.03,-5.55),Vector3(1.85,1.10,.9))

func _prop(id: String, at: Vector3, size: Vector3, solid: bool = true) -> void:
	var packed := load(PROP_ROOT+id+".glb") as PackedScene
	if packed == null:
		push_error("Missing packaged living prop: "+id)
		return
	var holder := Node3D.new()
	holder.name = "Meshy_"+id
	room.add_child(holder)
	var visual := packed.instantiate() as Node3D
	holder.add_child(visual)
	var low := Vector3.INF
	var high := -Vector3.INF
	for item: MeshInstance3D in visual.find_children("*","MeshInstance3D",true,false):
		if item.mesh == null: continue
		var transform := holder.global_transform.affine_inverse()*item.global_transform
		for i in 8:
			var point: Vector3 = transform*item.mesh.get_aabb().get_endpoint(i)
			low=low.min(point)
			high=high.max(point)
	var extents := high-low
	visual.position=-Vector3((low.x+high.x)*.5,low.y,(low.z+high.z)*.5)
	holder.scale=size/extents
	holder.position=at
	holder.set_meta("source_model","Meshy first pass 2026-09-16 / "+id)
	_prop_instances+=1
	if solid:
		_proxy("Meshy_"+id,size,at+Vector3(0,size.y*.5,0))
