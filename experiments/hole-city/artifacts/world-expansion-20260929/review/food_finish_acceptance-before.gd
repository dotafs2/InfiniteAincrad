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
func run()->void:
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
	check(total_triangles<4500000,"Initial food scene stays under 4.5M triangles before spatial culling")
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
	var result:={"checks":checks,"failures":failures,"meshes":metrics,"initial_food_triangles":total_triangles}
	print("FOOD_FINISH_ACCEPTANCE "+JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
