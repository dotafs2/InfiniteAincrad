extends SceneTree
const ASSET_DIR := "res://assets/floor1/pcg_20260916/"
const HEIGHTS := {"elm-tree":10.5,"birch-tree":12.0,"leafy-shrub":1.3,"meadow-grass":.48,"wildflowers":.62,"fern":.62,"market-barrel":.88,"produce-crate":.40}

func _initialize() -> void:
	_prepare.call_deferred()

func _prepare() -> void:
	var report := []
	for id in HEIGHTS:
		if OS.get_cmdline_user_args().has("--available") and not ResourceLoader.exists(ASSET_DIR+id+".glb"): continue
		var packed: PackedScene = load(ASSET_DIR+id+".glb")
		var wrapper := Node3D.new()
		wrapper.name = id.replace("-","_")
		root.add_child(wrapper)
		var visual: Node3D = packed.instantiate()
		wrapper.add_child(visual)
		visual.owner = wrapper
		var low := Vector3.INF
		var high := -Vector3.INF
		var triangles := 0
		var meshes: Array[Node] = visual.find_children("*","MeshInstance3D",true,false)
		if visual is MeshInstance3D: meshes.append(visual)
		for item: MeshInstance3D in meshes:
			var bounds: AABB = item.mesh.get_aabb()
			for n in 8:
				var point: Vector3 = item.global_transform*bounds.get_endpoint(n)
				low=low.min(point)
				high=high.max(point)
			for s in item.mesh.get_surface_count():
				var indices: int = item.mesh.surface_get_array_index_len(s)
				triangles += indices/3 if indices>0 else item.mesh.surface_get_array_len(s)/3
		var factor: float = HEIGHTS[id]/(high.y-low.y)
		visual.scale *= factor
		visual.position = -Vector3((low.x+high.x)*.5,low.y,(low.z+high.z)*.5)*factor
		var collider_radius := 0.0
		if id.ends_with("tree"): collider_radius=.29
		if id=="leafy-shrub": collider_radius=.38
		if id=="market-barrel": collider_radius=.32
		if id=="produce-crate": collider_radius=.32
		if collider_radius>0:
			var body := StaticBody3D.new()
			body.name = "InteractionCollider"
			wrapper.add_child(body)
			body.owner=wrapper
			var collider := CollisionShape3D.new()
			var shape := CylinderShape3D.new()
			shape.radius=collider_radius
			shape.height=2.5 if id.ends_with("tree") else HEIGHTS[id]*.9
			collider.shape=shape
			collider.position.y=shape.height*.5
			body.add_child(collider)
			collider.owner=wrapper
		var normalized := PackedScene.new()
		var error := normalized.pack(wrapper)
		if error!=OK or ResourceSaver.save(normalized,ASSET_DIR+id+".tscn")!=OK:
			push_error("Cannot package the Meshy PCG instance: "+id)
			quit(2)
			return
		report.append({"id":id,"height_m":HEIGHTS[id],"triangles":triangles,"meshes":meshes.size(),"scale":factor,"collider_radius":collider_radius})
		wrapper.free()
	var file:=FileAccess.open(ASSET_DIR+"instances.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("PCG_ASSET_INSTANCES ",JSON.stringify(report))
	quit()
