extends SceneTree
## GPT-6 independent review harness; never writes any world/save.
var cases: Array[Dictionary] = []
var space: PhysicsDirectSpaceState3D

func _initialize() -> void:
	call_deferred("_run")

func probe(id: String, a: Vector3, b: Vector3, expected: bool, mask: int = 1) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(a, b, mask)
	var hit := space.intersect_ray(query)
	var row := {"id":id, "expected_hit":expected, "actual_hit":not hit.is_empty(), "passed":hit.is_empty() != expected}
	if not hit.is_empty(): row["hit_position"] = [hit.position.x, hit.position.y, hit.position.z]
	cases.append(row)
	return hit

func _run() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var house := Node3D.new()
	house.set_script(load("res://spatial/deepseek_residences_component.gd"))
	house.set("force_lod", 0)
	scene.add_child(house)
	# Separate actual LOD0 triangle geometry on layer 2 provides an independent
	# physical reference for checking the simplified collision representation.
	var visual_body := StaticBody3D.new()
	visual_body.name = "ReviewOnlyVisualTriangles"
	visual_body.collision_layer = 2
	visual_body.collision_mask = 0
	scene.add_child(visual_body)
	for mi: MeshInstance3D in house.find_children("*", "MeshInstance3D", true, false):
		if int(mi.get_meta("lod", -1)) != 0: continue
		var cs := CollisionShape3D.new()
		cs.shape = mi.mesh.create_trimesh_shape()
		visual_body.add_child(cs)
		cs.global_transform = mi.global_transform
	await physics_frame
	await physics_frame
	space = scene.get_world_3d().direct_space_state
	probe("open_porch_approach", Vector3(-1.75,1.6,7), Vector3(-1.75,1.6,3.55), false)
	probe("closed_main_wall", Vector3(0,1.6,7), Vector3(0,1.6,0), true)
	probe("closed_door", Vector3(-1.75,1.6,4), Vector3(-1.75,1.6,3), true)
	probe("empty_space_right_of_visual_steps", Vector3(.8,2,4.5), Vector3(.8,-.2,4.5), false)
	probe("door_flowerbox_clear_visual", Vector3(-1.75,.76,5), Vector3(-1.75,.76,3.55), false, 2)
	var capsule := CapsuleShape3D.new()
	capsule.radius = .28
	capsule.height = 1.75
	for x in [-1.95,-1.75,-1.55]:
		for z in [4.6,4.3,4.0,3.8]:
			for mask in [1,2]:
				var q := PhysicsShapeQueryParameters3D.new()
				q.shape = capsule
				q.collision_mask = mask
				q.transform = Transform3D(Basis.IDENTITY, Vector3(x,1.4,z))
				var hits := space.intersect_shape(q, 8)
				cases.append({"id":"resident_capsule_clear", "x":x,"z":z,"mask":mask,"hits":hits.size(),"passed":hits.is_empty()})
	for x in [-2.0,-1.75,-1.5]:
		for z in [3.7,4.0,4.3,4.6,4.9,5.2,5.5]:
			var a := Vector3(x,.9,z)
			var b := Vector3(x,-.2,z)
			var real_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(a,b,2))
			var proxy_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(a,b,1))
			var pass_support := real_hit.is_empty() == proxy_hit.is_empty()
			var mismatch := 0.0
			if not real_hit.is_empty() and not proxy_hit.is_empty():
				mismatch = absf(real_hit.position.y-proxy_hit.position.y)
				pass_support = mismatch <= .08
			cases.append({"id":"visible_landing_step_support","x":x,"z":z,"visual_hit":not real_hit.is_empty(),"proxy_hit":not proxy_hit.is_empty(),"height_error":mismatch,"passed":pass_support})
	for x in [-2.765,-.735]:
		probe("visible_pier",Vector3(x,1.4,6),Vector3(x,1.4,3.6),true,2)
		probe("solid_pier",Vector3(x,1.4,6),Vector3(x,1.4,3.6),true,1)
	var failures := cases.filter(func(row: Dictionary) -> bool: return not row.passed)
	var report := {"suite":"house06_independent_physics", "cases":cases,"case_count":cases.size(),"failed":failures.size(),"failures":failures,"resident_model_calls":0,"world_save_writes":0}
	var output := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	if output.is_empty():
		push_error("Review output path required")
		quit(2)
		return
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	print(JSON.stringify({"suite":report.suite,"cases":cases.size(),"failed":failures.size(),"output":output}))
	quit(0 if failures.is_empty() else 1)
