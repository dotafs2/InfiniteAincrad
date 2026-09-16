extends SceneTree
## Normalize and wrap existing models; preserve their geometry and materials.
const OUTPUT := "res://assets/floor1/demo_prefabs/"
func _initialize() -> void:
	_prepare.call_deferred()

func _prepare() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://experiments/pcg/demo_catalog.json"))
	var records: Array = []
	for id: String in catalog.assets:
		var entry: Dictionary = catalog.assets[id]
		var source := load(entry.source) as PackedScene
		if source == null:
			push_error("Demo requires model: " + entry.source)
			quit(2)
			return
		var holder := Node3D.new()
		holder.name = id.replace("-", "_")
		root.add_child(holder)
		var visual := source.instantiate() as Node3D
		visual.rotation_degrees.y = entry.get("source_yaw", 0.0)
		holder.add_child(visual)
		var low := Vector3.INF
		var high := -Vector3.INF
		for item: MeshInstance3D in visual.find_children("*", "MeshInstance3D", true, false):
			if item.mesh == null: continue
			if String(item.name).begins_with("COL_"):
				item.visible = false
				continue
			# Some imported shared materials have vertex colors disabled despite
			# COLOR_0 in the GLB. Preserve and explicitly display those source colors.
			for surface in item.mesh.get_surface_count():
				var arrays := item.mesh.surface_get_arrays(surface)
				var colors = arrays[Mesh.ARRAY_COLOR]
				if colors != null and not colors.is_empty():
					var original := item.get_active_material(surface) as BaseMaterial3D
					if original != null:
						var colored := original.duplicate() as BaseMaterial3D
						colored.vertex_color_use_as_albedo = true
						item.set_surface_override_material(surface, colored)
			var transform := holder.global_transform.affine_inverse() * item.global_transform
			for index in 8:
				var point := transform * item.mesh.get_aabb().get_endpoint(index)
				low = low.min(point)
				high = high.max(point)
		var size := high-low
		assert(size.x > 0 and size.y > 0 and size.z > 0)
		var target := Vector3(entry.size[0], entry.size[1], entry.size[2])
		var ratios := target/size
		var factor := minf(ratios.x, minf(ratios.y, ratios.z))
		visual.scale *= factor
		visual.position = -Vector3((low.x+high.x)*.5, low.y, (low.z+high.z)*.5)*factor
		var real_size := size*factor
		_set_owner(visual, holder)
		if entry.solid:
			var body := StaticBody3D.new()
			body.collision_layer = 1
			body.collision_mask = 0
			holder.add_child(body)
			body.owner = holder
			var collision := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(real_size.x*.84, minf(real_size.y, entry.get("collision_height", real_size.y)), real_size.z*.84)
			collision.position.y = box.size.y*.5
			collision.shape = box
			body.add_child(collision)
			collision.owner = holder
		holder.set_meta("demo_source", entry.source)
		holder.set_meta("demo_size", real_size)
		var packed := PackedScene.new()
		assert(packed.pack(holder) == OK)
		assert(ResourceSaver.save(packed, OUTPUT+id+".tscn") == OK)
		records.append({"id":id,"source":entry.source,"size":[real_size.x,real_size.y,real_size.z],"uniform_scale":factor,"collision":entry.solid})
		holder.free()
	var file := FileAccess.open(OUTPUT+"manifest.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(records, "\t"))
	file.close()
	print("DEMO_PREPARED assets=", records.size())
	quit()

func _set_owner(node: Node, target: Node) -> void:
	node.owner = target
	for child in node.get_children(): _set_owner(child, target)
