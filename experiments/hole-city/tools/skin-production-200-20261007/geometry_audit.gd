extends SceneTree
## Isolated authored-model audit. It constructs no gameplay scene or user save.
const Geometry = preload("res://fidelity/collection_geometry.gd")
const Surface = preload("res://fidelity/common_surface.gdshader")

class SkinInput extends Node3D:
	var model_id := ""
	var skin_id := ""
	var tint := Color("5b98bd")
	var accent := Color("edb47e")

func _collect(node:Node3D, transform:Transform3D, out:Array[Dictionary])->void:
	var pose := transform*node.transform
	if node is MeshInstance3D:
		out.append({"node":node,"transform":pose})
	for child in node.get_children():
		if child is Node3D: _collect(child,pose,out)

func _point_key(p:Vector3)->String:
	return "%d,%d,%d"%[roundi(p.x*100000),roundi(p.y*100000),roundi(p.z*100000)]

func _record_edge(edges:Dictionary, a:Vector3, b:Vector3)->void:
	var ka := _point_key(a)
	var kb := _point_key(b)
	var key := ka+"/"+kb if ka < kb else kb+"/"+ka
	edges[key] = int(edges.get(key,0))+1

func _projected_radius(a:Vector3, b:Vector3, c:Vector3)->float:
	var points:Array[Vector2] = [Vector2(a.x,a.z),Vector2(b.x,b.z),Vector2(c.x,c.z)]
	var closest := INF
	for i in 3:
		var from := points[i]
		var difference := points[(i+1)%3]-from
		var t := clampf(-from.dot(difference)/maxf(difference.length_squared(),.0000000001),0.0,1.0)
		closest = minf(closest,(from+difference*t).length())
	var area := (points[1]-points[0]).cross(points[2]-points[0])
	if absf(area) > .00000001:
		var sides:Array[float] = []
		for i in 3: sides.append((points[(i+1)%3]-points[i]).cross(-points[i]))
		if (sides[0]>=0 and sides[1]>=0 and sides[2]>=0) or (sides[0]<=0 and sides[1]<=0 and sides[2]<=0): return 0.0
	return closest

func _initialize()->void:
	var failures:Array[String] = []
	var report:Array[Dictionary] = []
	for id in Geometry.IDS:
		var source := SkinInput.new()
		source.skin_id = id+"_variant_a"
		source.model_id = id
		var holder := Node3D.new()
		var first := Geometry.build(source,holder)
		var second := Geometry.build(source,holder)
		if first.main_ring.mesh != second.main_ring.mesh: failures.append(id+": matching palette cache was not reused")
		if first.animated_root == second.animated_root: failures.append(id+": instance transform is shared")
		source.tint = Color("a975bc")
		var variant := Geometry.build(source,holder)
		if first.main_ring.mesh == variant.main_ring.mesh: failures.append(id+": differing palettes share the same material mesh")
		var parts:Array[Dictionary] = []
		_collect(first.animated_root,Transform3D.IDENTITY,parts)
		var min_radius := INF
		var max_radius := 0.0
		var min_y := INF
		var max_y := -INF
		var triangles := 0
		var surfaces := 0
		var materials:Dictionary = {}
		var broken_edges := 0
		var volume := 0.0
		for part in parts:
			var node:MeshInstance3D = part.node
			var mesh:Mesh = node.mesh
			var transform:Transform3D = part.transform
			var edges:Dictionary = {}
			var mesh_volume := 0.0
			surfaces += mesh.get_surface_count()
			for surface in mesh.get_surface_count():
				var mat := mesh.surface_get_material(surface)
				materials[mat] = true
				if not mat is ShaderMaterial or mat.shader != Surface: failures.append(id+": unexpected surface shader")
				var arrays := mesh.surface_get_arrays(surface)
				var vertices:PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var indices:PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
				if indices.is_empty():
					for i in vertices.size(): indices.append(i)
				for point in vertices:
					point = transform*point
					var radius := Vector2(point.x,point.z).length()
					max_radius = maxf(max_radius,radius)
					min_y = minf(min_y,point.y)
					max_y = maxf(max_y,point.y)
				for i in range(0,indices.size(),3):
					triangles += 1
					var a := transform*vertices[indices[i]]
					var b := transform*vertices[indices[i+1]]
					var c := transform*vertices[indices[i+2]]
					min_radius = minf(min_radius,_projected_radius(a,b,c))
					mesh_volume += a.dot(b.cross(c))/6.0
					_record_edge(edges,a,b);_record_edge(edges,b,c);_record_edge(edges,c,a)
			for count in edges.values():
				if count != 2: broken_edges += 1
			if mesh_volume >= -.00001: failures.append(id+": mesh does not have negative closed signed volume")
			volume += mesh_volume
		if min_radius < 1.0: failures.append("%s: opening %.5f"%[id,min_radius])
		if min_y < .003 or min_y > .007: failures.append("%s: grounded inner wall %.5f"%[id,min_y])
		if max_radius > 1.75: failures.append("%s: outer extent %.5f"%[id,max_radius])
		var height_limit := 1.6 if id in ["clockwork_orbit","phoenix_nest","crystal_crown","aurora_rift"] else 1.3
		if max_y > height_limit: failures.append("%s: height %.5f"%[id,max_y])
		# Phoenix's independently hinged wings each reuse the same two materials.
		var surface_limit := 7 if id == "phoenix_nest" else 5
		if surfaces > surface_limit or surfaces < 2: failures.append(id+": material-surface budget")
		if materials.size() > 5: failures.append(id+": unique-material budget")
		if parts.size() > 4: failures.append(id+": mesh-instance budget")
		var triangle_limit := 4500 if id == "aurora_rift" else 5000
		if triangles > triangle_limit or triangles < 200: failures.append("%s: triangle budget %d/%d"%[id,triangles,triangle_limit])
		if broken_edges != 0: failures.append("%s: %d unclosed/duplicate snapped edges"%[id,broken_edges])
		for motion in first.motions:
			if not motion.node is Node3D or not motion.role in ["orbit","sway","pulse"]: failures.append(id+": invalid motion contract")
		if id == "phoenix_nest":
			if first.motions.size() != 2: failures.append(id+": expected two independent wing hinges")
			elif not is_equal_approx(absf(first.motions[0].phase-first.motions[1].phase),PI): failures.append(id+": wing phases must be opposite")
			for motion in first.motions:
				if not is_equal_approx(motion.amplitude,.11) or not is_equal_approx(motion.speed,1.35): failures.append(id+": wing motion contract changed")
		report.append({"id":id,"surfaces":surfaces,"materials":materials.size(),"meshes":parts.size(),"triangles":triangles,"broken_edges":broken_edges,"signed_volume":volume,"min_radius":min_radius,"max_radius":max_radius,"min_y":min_y,"max_y":max_y,"motions":first.motions.size(),"features":first.theme.features})
		source.free()
		holder.free()
	print(JSON.stringify({"ok":failures.is_empty(),"failures":failures,"models":report},"\t"))
	quit(0 if failures.is_empty() else 1)
