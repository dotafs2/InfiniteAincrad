extends SceneTree
## Geometry-only audit. No game save, engine scene, physics or account access.
const Geometry = preload("res://fidelity/common_geometry.gd")

class SkinInput extends Node3D:
	var skin_id := ""
	var tint := Color.WHITE
	var accent := Color.WHITE

func _initialize()->void:
	var failures:Array[String] = []
	var report:Array[Dictionary] = []
	for id in Geometry.IDS:
		var source := SkinInput.new()
		source.skin_id = id
		var holder := Node3D.new()
		var first := Geometry.build(source,holder)
		var second := Geometry.build(source,holder)
		var model:MeshInstance3D = first.main_ring
		var mesh:Mesh = model.mesh
		if mesh != second.main_ring.mesh: failures.append(id+": cache was not reused")
		var min_radius := INF
		var max_radius := 0.0
		var min_y := INF
		var max_y := -INF
		var triangles := 0
		for surface in mesh.get_surface_count():
			var arrays := mesh.surface_get_arrays(surface)
			var vertices:PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices:PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			for point in vertices:
				var radius := Vector2(point.x,point.z).length()
				min_radius = minf(min_radius,radius)
				max_radius = maxf(max_radius,radius)
				min_y = minf(min_y,point.y)
				max_y = maxf(max_y,point.y)
			for i in range(0,indices.size(),3):
				triangles += 1
				var a := Vector2(vertices[indices[i]].x,vertices[indices[i]].z)
				var b := Vector2(vertices[indices[i+1]].x,vertices[indices[i+1]].z)
				var c := Vector2(vertices[indices[i+2]].x,vertices[indices[i+2]].z)
				# Include projected triangle edges, not only their outer vertices.
				for edge in [[a,b],[b,c],[c,a]]:
					var from:Vector2 = edge[0]
					var difference:Vector2 = edge[1]-from
					var t := clampf(-from.dot(difference)/maxf(difference.length_squared(),.00000001),0.0,1.0)
					min_radius = minf(min_radius,(from+difference*t).length())
		if min_radius < .984: failures.append("%s: opening %.5f"%[id,min_radius])
		# GPU review exposed the street below raised inner bevels. Only the inner
		# wall now descends to y=.005; its projected radial clearance still stays
		# above 1.0. The old .025 floor check is retained in before-visual-repair.
		if min_y < .003: failures.append("%s: grounding %.5f"%[id,min_y])
		if max_radius > 1.72: failures.append("%s: outer extent %.5f"%[id,max_radius])
		if max_y > (.82 if id == "paper_boat" else .67): failures.append("%s: height %.5f"%[id,max_y])
		if mesh.get_surface_count() < 3 or mesh.get_surface_count() > 6: failures.append(id+": surface budget")
		# Reserve room under the existing whole-skin 4,500 triangle budget for
		# the preview mouth, Common boost wave, and all eight pooled FX instances.
		if triangles < 200 or triangles > 3300: failures.append(id+": triangle budget")
		report.append({"id":id,"surfaces":mesh.get_surface_count(),"triangles":triangles,"min_radius":min_radius,"max_radius":max_radius,"min_y":min_y,"max_y":max_y,"features":first.theme.features})
		source.free()
		holder.free()
	print(JSON.stringify({"ok":failures.is_empty(),"failures":failures,"models":report},"\t"))
	quit(0 if failures.is_empty() else 1)
