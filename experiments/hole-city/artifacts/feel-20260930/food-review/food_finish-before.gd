extends SceneTree
## Validate rounded silhouettes and ingredient finish through the actual batch path.
const Surface=preload("res://fidelity/food_surface.gd")
var checks:=0
var failures:Array[String]=[]
var metrics:Array[Dictionary]=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func geometry(mesh:Mesh,label:String)->void:
	var a:Array=mesh.surface_get_arrays(0)
	var vs:PackedVector3Array=a[Mesh.ARRAY_VERTEX];var ns:PackedVector3Array=a[Mesh.ARRAY_NORMAL];var ids:PackedInt32Array=a[Mesh.ARRAY_INDEX]
	var invalid:=0;var reversed:=0;var curved:=0
	for i in vs.size():
		if not vs[i].is_finite() or not ns[i].is_finite() or absf(ns[i].length()-1)>.001:invalid+=1
		var n:=ns[i].abs()
		if n.x>.1 and n.y>.1 or n.y>.1 and n.z>.1 or n.z>.1 and n.x>.1:curved+=1
	for i in range(0,ids.size(),3):
		var cross:Vector3=(vs[ids[i+1]]-vs[ids[i]]).cross(vs[ids[i+2]]-vs[ids[i]])
		if cross.dot(ns[ids[i]]+ns[ids[i+1]]+ns[ids[i+2]])>0.000001:reversed+=1
	check(invalid==0,label+": finite vertices and unit normals")
	check(reversed==0,label+": clockwise outward faces survive backface culling")
	check(curved>20,label+": curved edge normals, not a hard-edged primitive")
func triangles(mesh:Mesh)->int:
	return mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size()/3
func box_visible(box:AABB,camera:Camera3D)->bool:
	var interior:Vector3=camera.global_position-camera.global_basis.z*5.0
	for plane in camera.get_frustum():
		var orientation:=1.0 if plane.distance_to(interior)>=0 else -1.0
		var any_inside:=false
		for corner in 8:
			if plane.distance_to(box.get_endpoint(corner))*orientation>=0:any_inside=true;break
		if not any_inside:return false
	return true
func visible_static_geometry(city:Node3D,camera:Camera3D)->Dictionary:
	var count:=0;var cells:=0
	for view in city.find_children("*","MultiMeshInstance3D",false,false):
		if view.material_override!=city.food_batch_material:continue
		var mm:MultiMesh=view.multimesh
		if box_visible(view.global_transform*mm.custom_aabb,camera):
			count+=triangles(mm.mesh)*mm.visible_instance_count;cells+=1
	return {"triangles":count,"cells":cells}
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	var box:=Surface.rounded_box(Vector3(2.04,.16,2.04));geometry(box,"Icing slab")
	check(box.get_aabb().size.is_equal_approx(Vector3(2.04,.16,2.04)),"Beveled box preserves original exterior dimensions")
	var disc:=Surface.rounded_disc(.9,.3);geometry(disc,"Cookie edge")
	check(disc.get_aabb().size.is_equal_approx(Vector3(1.8,.3,1.8)),"Beveled disc preserves original exterior dimensions")
	var game:Node3D=load("res://fidelity/main.tscn").instantiate();root.add_child(game)
	game.selected_map="food";game.start_level();game.set_physics_process(false);game.city.rain_enabled=false
	var city:Node3D=game.city
	check(city.food_material is ShaderMaterial,"Food uses the ingredient finish shader")
	check(is_equal_approx(game.scene_environment.ambient_light_energy,.48),"Food lighting restores directional contrast")
	var total_triangles:=0
	for key in city.mesh_cache:
		var mesh:Mesh=city.mesh_cache[key];var a:Array=mesh.surface_get_arrays(0)
		var colors:PackedColorArray=a[Mesh.ARRAY_COLOR];var finishes:Dictionary={}
		for color in colors:finishes[roundi(color.a*100)]=true
		check(finishes.size()>=2,"Ingredient finishes survive merging: "+key)
		check(finishes.keys().all(func(r):return r>=18 and r<=70),"Finish data stays opaque shader input: "+key)
		var triangles:int=a[Mesh.ARRAY_INDEX].size()/3
		check(triangles<=7500,"Bounded cached geometry: "+key)
		metrics.append({"mesh":key,"triangles":triangles,"roughness_percent":finishes.keys()})
	for body in city.foods:
		if not body.has_meta("food_kind"):continue
		total_triangles+=body.food_visual.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size()/3
	# Keep the original-content ceiling. Added connectors can place new snacks
	# inside the old square, so admission follows actual authored provenance,
	# not a coordinate test that incorrectly calls those foods old content.
	var plan:Dictionary=city.urban_plan;var added:Dictionary={};var alignment:=true
	for index in plan.plots.size():
		if not plan.plots[index].get("extension",false):continue
		for member in city.towers[index].tiers:
			if int(member.get_meta("tower_id",-1))!=index:alignment=false
			added[member.get_instance_id()]=true
	for index in plan.heaps.size():
		if not plan.heaps[index].get("extension",false):continue
		for member in city.piles[index].pieces:
			if int(member.get_meta("pile_id",-1))!=index:alignment=false
			added[member.get_instance_id()]=true
	var loose:Array=city.foods.filter(func(item):return item.has_meta("food_kind") and not item.has_meta("tower_id") and not item.has_meta("pile_id") and not item.get_meta("traffic",false))
	check(loose.size()==plan.snacks.size(),"All authored loose-food records map one-to-one to real bodies")
	for index in mini(loose.size(),plan.snacks.size()):
		var member:Node3D=loose[index];var record:Dictionary=plan.snacks[index]
		if Vector2(member.position.x,member.position.z).distance_to(Vector2(record.at[0],record.at[1]))>.0001:alignment=false
		if record.get("extension",false):added[member.get_instance_id()]=true
	check(alignment and added.size()==334,"Extension budget binds the actual 96 tiers, 118 heap pieces and 120 snacks through plan/body provenance")
	var added_triangles:=0
	for member in city.foods:
		if added.has(member.get_instance_id()):added_triangles+=triangles(member.food_visual.mesh)
	check(total_triangles-added_triangles<4500000,"Original food content retains its unchanged 4.5M triangle ceiling")
	check(added_triangles<=650000,"Additional authored food stays within its separate 650k triangle budget")
	check(total_triangles<5000000,"Entire expanded food scene stays under 5M triangles before spatial culling")
	# Real 390x844 camera + actual batch AABBs give a conservative main-view
	# submission bound. This is not renderer timing or a phone FPS claim.
	game.set_process(false);city.set_process(false)
	for hole in game.holes:hole.enabled=false;hole.set_physics_process(false)
	var viewport:=SubViewport.new();viewport.size=Vector2i(390,844);viewport.world_3d=game.get_world_3d();root.add_child(viewport);game.camera.reparent(viewport)
	await process_frame
	check(game.camera.get_viewport().get_visible_rect().size==Vector2(390,844),"Visibility budget uses an actual portrait viewport rather than the headless 64px default")
	var visibility:Array=[]
	for entry in [[.85,721252,67],[7.2,1144048,119]]:
		game.player.radius=entry[0];game.player.position=Vector3(1,0,23);game.update_camera(1.0,true)
		var submitted:=visible_static_geometry(city,game.camera);visibility.append(submitted)
		check(submitted.triangles<=entry[1] and submitted.cells<=entry[2] and submitted.triangles>500000,"Opening-view batch submission does not increase over the original package at radius "+str(entry[0]))
	game.player.radius=14.0
	for at in [Vector2(-84,-60),Vector2(-88,0),Vector2(-84,60),Vector2(0,88),Vector2(84,60),Vector2(88,0),Vector2(84,-60),Vector2(0,-88)]:
		game.player.position=Vector3(at.x,0,at.y);game.update_camera(1.0,true)
		var submitted:=visible_static_geometry(city,game.camera);visibility.append(submitted)
		check(submitted.triangles<=1550000 and submitted.cells<=170,"Expanded outer view keeps a bounded static geometry submission at "+str(at))
	game.camera.reparent(game);viewport.free()
	var views:=city.find_children("*","MultiMeshInstance3D",false,false)
	check(not views.is_empty() and views.all(func(v):return v.material_override==city.food_batch_material and v.material_override.shader==city.food_material.shader),"Static batches share the same opaque ingredient shader and finish")
	var body:Node3D=city.piles[0].roots[0]
	body.lose_support(game.player)
	check(body.food_visual.visible and body.food_visual.material_override==city.food_material,"Released piece retains the same finish and mesh")
	var shader:String=city.food_material.shader.code
	check(not "ALPHA =" in shader and not "unshaded" in shader,"Food stays opaque and receives scene lighting/shadows")
	game.selected_map="city";game.start_level()
	check(is_equal_approx(game.scene_environment.ambient_light_energy,.78),"Returning to Sunny City restores its lighting")
	game.free();await process_frame
	var result:={"checks":checks,"failures":failures,"meshes":metrics,"initial_food_triangles":total_triangles,"original_food_triangles":total_triangles-added_triangles,"extension_triangles":added_triangles,"portrait_static_submission":visibility}
	print("FOOD_FINISH_ACCEPTANCE "+JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
