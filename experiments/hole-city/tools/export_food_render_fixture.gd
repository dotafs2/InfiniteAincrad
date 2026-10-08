extends SceneTree
## Export real food meshes, poses and cameras for windowless visual QA.
var game:Node3D
var mesh_records:Dictionary={}
var output_dir:="res://artifacts/food-downtown"
func _initialize()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output_dir=arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output_dir)
	run.call_deferred()
func matrix(t:Transform3D)->Array:
	return [t.basis.x.x,t.basis.x.y,t.basis.x.z,0,t.basis.y.x,t.basis.y.y,t.basis.y.z,0,t.basis.z.x,t.basis.z.y,t.basis.z.z,0,t.origin.x,t.origin.y,t.origin.z,1]
func projection(p:Projection)->Array:
	return [p.x.x,p.x.y,p.x.z,p.x.w,p.y.x,p.y.y,p.y.z,p.y.w,p.z.x,p.z.y,p.z.z,p.z.w,p.w.x,p.w.y,p.w.z,p.w.w]
func triangle(a:Vector3,b:Vector3,c:Vector3,normal:Vector3,record:Dictionary)->void:
	# Subdivide only the preview's long planar triangles for the offline GL driver.
	var edges:=[a.distance_squared_to(b),b.distance_squared_to(c),c.distance_squared_to(a)]
	var longest:float=edges.max()
	if longest>144:
		if edges[0]==longest:
			var mid:Vector3=(a+b)*.5;triangle(a,mid,c,normal,record);triangle(mid,b,c,normal,record)
		elif edges[1]==longest:
			var mid:Vector3=(b+c)*.5;triangle(a,b,mid,normal,record);triangle(a,mid,c,normal,record)
		else:
			var mid:Vector3=(c+a)*.5;triangle(a,b,mid,normal,record);triangle(mid,b,c,normal,record)
		return
	for p in [a,b,c]:
		record.indices.append(record.vertices.size()/3)
		record.vertices.append_array([p.x,p.y,p.z]);record.normals.append_array([normal.x,normal.y,normal.z]);record.colors.append_array([1,1,1,1])
func geometry(mesh:Mesh,tiled:=false)->Dictionary:
	var arrays:=mesh.surface_get_arrays(0)
	if tiled:
		var record:={"vertices":[],"normals":[],"colors":[],"indices":[]}
		var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
		for i in range(0,vertices.size(),3):triangle(vertices[i],vertices[i+1],vertices[i+2],normals[i],record)
		return record
	var vertices:=[];var normals:=[];var colors:=[];var indices:=[]
	for v in arrays[Mesh.ARRAY_VERTEX]:vertices.append_array([v.x,v.y,v.z])
	for v in arrays[Mesh.ARRAY_NORMAL]:normals.append_array([v.x,v.y,v.z])
	var cs:PackedColorArray=arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR]!=null else PackedColorArray()
	for i in arrays[Mesh.ARRAY_VERTEX].size():
		var c:Color=cs[i] if i<cs.size() else Color.WHITE
		colors.append_array([c.r,c.g,c.b,c.a])
	if arrays[Mesh.ARRAY_INDEX]!=null and not arrays[Mesh.ARRAY_INDEX].is_empty():
		for i in arrays[Mesh.ARRAY_INDEX]:indices.append(i)
	else:
		for i in arrays[Mesh.ARRAY_VERTEX].size():indices.append(i)
	return {"vertices":vertices,"normals":normals,"colors":colors,"indices":indices}
func capture(name:String,width:int,height:int)->void:
	game.ground.sync()
	var instances:=[]
	for body in game.city.foods:
		if not is_instance_valid(body) or not body.has_meta("food_kind"):continue
		var visual:MeshInstance3D=body.food_visual
		instances.append({"key":body.get_meta("food_mesh_key"),"matrix":matrix(body.global_transform*visual.transform)})
	var ground:=geometry(game.ground.visual.mesh,true)
	var openings:=[]
	for hole in game.holes:
		if hole.active:openings.append([hole.position.x,hole.position.z,hole.radius])
	var view:Transform3D=game.camera.global_transform.affine_inverse()
	var proj:=Projection.create_perspective(58,float(width)/height,.1,300)
	var output:={"width":width,"height":height,"projection":projection(proj),"view":matrix(view),"instances":instances,"ground":ground,"openings":openings}
	FileAccess.open(output_dir+"/"+name+".json",FileAccess.WRITE).store_string(JSON.stringify(output))
func frames(n:int)->void:
	for i in n:
		await physics_frame
		if i%6==0:game.scan_food()
func run()->void:
	game=load("res://fidelity/main.tscn").instantiate();root.add_child(game)
	game.selected_map="food";game.start_level();game.begin_play();game.set_physics_process(false);game.set_process(false);game.city.rain_enabled=false
	for hole in game.holes:hole.enabled=false;hole.active=hole==game.player
	game.city.set_process(false)
	for key in game.city.mesh_cache:mesh_records[key]=geometry(game.city.mesh_cache[key])
	FileAccess.open(output_dir+"/render-meshes.json",FileAccess.WRITE).store_string(JSON.stringify(mesh_records))
	await physics_frame;capture("opening",720,1280)
	game.camera.position=Vector3(102,131,132);game.camera.look_at(Vector3(0,0,0))
	capture("districts",1280,960)
	var pile:Dictionary=game.city.piles.filter(func(p):return not p.starter)[1]
	game.player.position=Vector3(pile.at.x,0,pile.at.y);game.player.level=5;game.player.score=100;game.player.radius=3.5;game.player._sync_shape()
	game.camera.position=game.player.position+Vector3(9,12,14);game.camera.look_at(game.player.position+Vector3.UP*1.2)
	await physics_frame;await physics_frame
	capture("collapse-before",960,960)
	await frames(24);capture("collapse-04",960,960)
	await frames(36);capture("collapse-10",960,960)
	await frames(72);capture("collapse-22",960,960)
	print("FOOD_RENDER_FIXTURE exported initial city and actual physics poses")
	game.free();await process_frame;quit()
