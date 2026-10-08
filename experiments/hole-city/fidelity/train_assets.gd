extends RefCounted
## Imported visuals keep their authored materials; bounds describe one car only.
static var palette_materials:Dictionary={}

static func prepare_palette(node:Node3D)->void:
	if node is MeshInstance3D and node.mesh!=null:
		for surface in node.mesh.get_surface_count():
			var arrays:Array=node.mesh.surface_get_arrays(surface)
			if arrays[Mesh.ARRAY_COLOR]==null or arrays[Mesh.ARRAY_COLOR].is_empty():continue
			var original:Material=node.get_active_material(surface)
			if not original is BaseMaterial3D or original.vertex_color_use_as_albedo:continue
			# Imported resource paths survive home/map teardown; transient object
			# IDs would accumulate another material set on every scene reload.
			var key:String=original.resource_path if not original.resource_path.is_empty() else str(original.get_instance_id())
			if not palette_materials.has(key):
				var material:BaseMaterial3D=original.duplicate()
				material.vertex_color_use_as_albedo=true
				palette_materials[key]=material
			node.set_surface_override_material(surface,palette_materials[key])
	for child in node.get_children():
		if child is Node3D:prepare_palette(child)
static func bounds(node:Node3D,parent_pose:=Transform3D.IDENTITY)->AABB:
	var pose:Transform3D=parent_pose*node.transform
	var result:=AABB()
	var found:=false
	if node is MeshInstance3D and node.mesh!=null:
		result=pose*node.mesh.get_aabb();found=true
	for child in node.get_children():
		if not child is Node3D:continue
		var box:=bounds(child,pose)
		if box.size.is_zero_approx():continue
		result=result.merge(box) if found else box;found=true
	return result

static func visual(spec:Dictionary)->Dictionary:
	var root:Node3D
	if spec.has("asset"):
		var scene:PackedScene=load(str(spec.asset))
		if scene==null:return {}
		root=scene.instantiate()
	elif spec.get("mesh") is Mesh:
		# Also permits a small explicit primitive fixture in headless unit tests.
		var view:=MeshInstance3D.new();view.mesh=spec.mesh
		if spec.get("material") is Material:view.material_override=spec.material
		root=view
	else:return {}
	# Imported COLOR_0 arrays survive this engine import, but its material flag
	# is false. Opt in without altering original resource data or its PBR finish.
	prepare_palette(root)
	var box:=bounds(root)
	if box.size.x<=0 or box.size.y<=0 or box.size.z<=0:
		root.free();return {}
	return {"root":root,"bounds":box}
