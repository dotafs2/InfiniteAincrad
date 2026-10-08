extends SceneTree
## Export real food meshes, poses and cameras for windowless visual QA.
var game:Node3D
var mesh_records:Dictionary={}
var output_dir:="res://artifacts/video-showcase-20260928/food"
var timeline:Array[Dictionary]=[]
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
		if not is_instance_valid(body) or body.is_queued_for_deletion() or body.consumed or not body.has_meta("food_kind"):continue
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
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	game=load("res://fidelity/main.tscn").instantiate();root.add_child(game)
	game.selected_map="food";game.start_level();game.begin_play()
	game.set_physics_process(false);game.set_process(false)
	for hole in game.holes:
		hole.enabled=false;hole.active=hole==game.player;hole.set_physics_process(false)
	game.city.set_process(false)
	game.city.rain_enabled=true
	await physics_frame
	capture("opening",540,960)
	game.camera.position=Vector3(90,142,147);game.camera.look_at(Vector3(0,0,0))
	capture("overview",960,960)
	var pile:Dictionary=game.city.piles.filter(func(p):return not p.starter)[2]
	var pile_at:=Vector3(pile.at.x,0,pile.at.y)
	var original_pieces:int=pile.pieces.size()
	game.player.position=pile_at+Vector3(-6,0,0)
	game.player.level=5;game.player.radius=3.5;game.player._sync_shape()
	game.camera.position=pile_at+Vector3(13,19,22);game.camera.look_at(pile_at+Vector3.UP*2.4)
	var original_score:int=game.player.score
	for tick in 600:
		game.elapsed=float(tick)/60.0
		# A disclosed QA fixture moves an already grown mouth beneath the pile.
		# No food transforms, support constraints or scores are fabricated.
		if tick>=60:game.player.position=pile_at+Vector3(lerpf(-6.0,0.0,clampf(float(tick-60)/90.0,0,1)),0,0)
		if tick%6==0 and tick>=60:game.scan_food()
		if tick%5==0:
			capture("frame-%04d"%(tick/5),540,960)
			var remaining:int=pile.pieces.filter(func(b):return is_instance_valid(b) and not b.consumed).size()
			var airborne:int=game.city.rain_bodies.filter(func(b):return is_instance_valid(b) and not b.rain_landed).size()
			timeline.append({"frame":tick/5,"seconds":float(tick)/60.0,"pile_remaining":remaining,"rain_spawned":game.city.rain_serial,"rain_airborne":airborne,"score":game.player.score,"hole_position":str(game.player.position)})
		await physics_frame
	for key in game.city.mesh_cache:mesh_records[key]=geometry(game.city.mesh_cache[key])
	FileAccess.open(output_dir+"/render-meshes.json",FileAccess.WRITE).store_string(JSON.stringify(mesh_records))
	var report:={"frames":120,"fps":12,"physics_hz":60,"simulation_seconds":10,"pile_at":str(pile_at),"pile_original_pieces":original_pieces,"pile_remaining":pile.pieces.filter(func(b):return is_instance_valid(b) and not b.consumed).size(),"rain_spawned":game.city.rain_serial,"rain_waves":game.city.rain_waves,"score_before":original_score,"score_after":game.player.score,"score_injection":false,"controlled_hole_radius":3.5,"controlled_hole_motion":"6 metres beneath the pile over 1.5 seconds, beginning at t=1","opponents_disabled":true,"npc_and_traffic_controllers_disabled":true,"timeline":timeline}
	FileAccess.open(output_dir+"/simulation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("FOOD_OFFLINE_SHOWCASE "+JSON.stringify({"frames":120,"pile_original":original_pieces,"pile_remaining":report.pile_remaining,"rain_spawned":game.city.rain_serial,"score_before":original_score,"score_after":game.player.score}))
	game.free();await process_frame;quit()
