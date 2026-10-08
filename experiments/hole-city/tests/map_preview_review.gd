extends SceneTree
## Non-author map miniature review. Natural process frames verify lifecycle;
## geometry projection verifies framing, not rendered pixels or phone speed.
var game:Node3D
var checks:=0
var failures:Array[String]=[]
var metrics:Dictionary={}
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func frames(count:=4)->void:
	for i in count:await process_frame
func descendants(node:Node)->Array[Node]:
	var nodes:Array[Node]=[]
	for child in node.get_children():
		nodes.append(child);nodes.append_array(descendants(child))
	return nodes
func pivot()->Node3D:
	return game.ui.hero_models.get("preview")
func ledger()->Dictionary:
	return {"coins":game.coins,"gems":game.gems,"stage":game.stage,"owned":game.owned_skin_ids.duplicate(),"skin":game.selected_skin_id,"eaten":game.eaten,"food_collected":game.food_collected.duplicate(),"elapsed":game.elapsed,"remaining":game.remaining,"dirty":game.progress_dirty}
func composition()->void:
	var nodes:=descendants(game.ui.hero_models)
	var layers:Dictionary={};var clusters:Dictionary={};var kinds:Dictionary={}
	var materials:Dictionary={};var resources:Dictionary={}
	var count:=0;var tilted:=0
	for node in nodes:
		check(node.name!="TemporaryMeshBuilder" and node.get_script()!=preload("res://fidelity/food_city.gd"),"Food scene retains no temporary gameplay mesh builder")
		if not (node is MeshInstance3D) or not node.has_meta("food_kind"):continue
		var food:MeshInstance3D=node
		count+=1;kinds[food.get_meta("food_kind")]=true
		var layer:String=food.get_meta("preview_layer")
		var cluster:String=food.get_meta("cluster")
		var bounds:AABB=food.transform*food.mesh.get_aabb()
		if not layers.has(layer):layers[layer]={"count":0,"top":0.0,"depth":0.0}
		layers[layer].count+=1;layers[layer].top=maxf(layers[layer].top,bounds.end.y);layers[layer].depth+=bounds.get_center().z
		if not clusters.has(cluster):clusters[cluster]=[]
		clusters[cluster].append({"origin":food.position,"size":bounds.size,"top":bounds.end.y,"tier":food.get_meta("tier")})
		if absf(food.rotation.x)+absf(food.rotation.z)>.02:tilted+=1
		materials[food.material_override.get_instance_id()]=true
		resources[food.mesh.get_instance_id()]=true
		check(food.material_override is ShaderMaterial and food.material_override.shader==preload("res://fidelity/food_glaze.gdshader"),"Every food miniature uses the actual ingredient-gloss shader")
		check(food.material_override.get_shader_parameter("reveal_use_instance")==false and is_zero_approx(food.material_override.get_shader_parameter("reveal_occluder")),"Preview food remains opaque independently of gameplay reveal")
	check(count>=50 and kinds.size()==10,"Food district contains many separate visual foods across all ten recipes")
	check(layers.size()==3 and layers.has("foreground") and layers.has("midground") and layers.has("background"),"Food district has three populated composition layers")
	if layers.size()==3:
		for label in layers:layers[label].depth/=float(layers[label].count)
		check(layers.background.top>layers.midground.top+2.0 and layers.midground.top>layers.foreground.top+1.0,"Actual mesh heights descend from skyline through meal stacks to low scattered food")
		check(layers.foreground.depth>layers.midground.depth+1.5 and layers.midground.depth>layers.background.depth+1.5,"Actual food centers separate the three depth layers")
	var staggered_stacks:=0
	for label in clusters:
		var members:Array=clusters[label]
		if members.size()<3:continue
		var first:Dictionary=members[0]
		var highest:=0.0;var shifted:=0.0;var tier_count:Dictionary={}
		for member in members:
			highest=maxf(highest,member.origin.y-first.origin.y)
			shifted=maxf(shifted,Vector2(member.origin.x-first.origin.x,member.origin.z-first.origin.z).length())
			tier_count[member.tier]=true
		if highest>1.0 and shifted>.10 and tier_count.size()>=3:staggered_stacks+=1
	check(staggered_stacks>=5 and tilted>=20,"Multiple real multi-tier stacks have lateral displacement and visible tilt, rather than two straight columns")
	check(materials.size()==1 and resources.size()<count,"Separate food visuals reuse mesh and ingredient material resources")
	metrics["food_composition"]={"food_instances":count,"recipe_count":kinds.size(),"clusters":clusters.size(),"layers":layers,"staggered_stacks":staggered_stacks,"tilted_instances":tilted,"unique_food_meshes":resources.size(),"unique_food_materials":materials.size()}
func geometry(map_id:String)->void:
	var ui=game.ui
	var model:Node3D=ui.hero_models
	var nodes:=descendants(model)
	var meshes:Array[MeshInstance3D]=[]
	for node in nodes:
		check(not (node is CollisionObject3D or node is CollisionShape3D or node is CollisionPolygon3D),map_id+": visual miniature contains no physical body, area or collider")
		check(not node.has_method("finish_swallow") and not node.has_method("rain_step"),map_id+": miniature cannot execute collection or gameplay rain")
		if node is MeshInstance3D and node.mesh!=null:meshes.append(node)
	check(not meshes.is_empty(),map_id+": preview has actual mesh geometry")
	var cameras:Array[Node]=ui.hero_view.find_children("*","Camera3D",true,false)
	check(cameras.size()==1,map_id+": exactly one miniature camera exists")
	if cameras.size()!=1 or not is_instance_valid(pivot()):return
	var camera:Camera3D=cameras[0]
	var before:Vector3=pivot().rotation
	var model_before:bool=model.is_processing()
	model.set_process(false)
	var margin:=Vector2(ui.hero_view.size)*.025
	var safe:=Rect2(margin,Vector2(ui.hero_view.size)-margin*2.0)
	var min_border:=1.0e20
	var projected:=0
	var outside:=0
	var behind:=0
	for step in 72:
		pivot().rotation.y=step*TAU/72.0
		for mesh in meshes:
			var bounds:=mesh.mesh.get_aabb()
			for corner in 8:
				var p:Vector3=mesh.global_transform*bounds.get_endpoint(corner)
				var screen:Vector2=camera.unproject_position(p)
				if camera.is_position_behind(p):behind+=1
				if not safe.has_point(screen):outside+=1
				min_border=minf(min_border,minf(minf(screen.x,ui.hero_view.size.x-screen.x),minf(screen.y,ui.hero_view.size.y-screen.y)))
				projected+=1
	check(behind==0,map_id+": all mesh bounds remain in front of the camera across a full revolution")
	check(outside==0,map_id+": every mesh AABB corner keeps a 2.5 percent camera-edge margin across 72 angles")
	metrics[map_id+"_geometry"]={"mesh_count":meshes.size(),"projected_aabb_corners":projected,"minimum_border_pixels":min_border,"outside_safe_rect":outside,"behind_camera":behind,"scope":"Actual mesh bounds and camera projection; no renderer pixel assertion."}
	pivot().rotation=before
	model.set_process(model_before)
func active_preview(label:String)->void:
	var ui=game.ui
	check(ui.hero.visible and ui.hero_view.render_target_update_mode==SubViewport.UPDATE_ALWAYS,label+": home miniature is visible and renders continuously")
	check(ui.hero_models.is_processing() and is_instance_valid(pivot()),label+": the live miniature owns an enabled rotation pivot")
	if not is_instance_valid(pivot()):return
	var angle:float=pivot().rotation.y
	await frames(12)
	var advance:float=absf(angle_difference(angle,pivot().rotation.y))
	check(advance>.005 and advance<.25,label+": natural SceneTree process frames advance a slow turn")
	metrics[label+"_angle_advance"]=advance
func dormant_preview(label:String)->void:
	var ui=game.ui
	check(not ui.hero.visible and ui.hero_view.render_target_update_mode==SubViewport.UPDATE_DISABLED,label+": hidden miniature target is disabled")
	check(not ui.hero_models.is_processing(),label+": hidden miniature processing is explicitly stopped")
	var angle:float=pivot().rotation.y
	await frames(8)
	check(is_equal_approx(angle,pivot().rotation.y),label+": natural process frames do not rotate hidden miniature")
func freeze_world()->void:
	game.world.process_mode=Node.PROCESS_MODE_DISABLED
	for node in descendants(game.world):
		if node is RigidBody3D:node.freeze=true
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	root.size=Vector2i(540,960)
	game=load("res://fidelity/main.tscn").instantiate()
	game.selected_map="food"
	root.add_child(game)
	# Keep the real game process callback alive through home/menu transitions:
	# this must catch stale scene references after back_home, not mask them.
	game.set_physics_process(false)
	check(game.progress_file().is_empty(),"--test preview review cannot read or write the player's save")
	var baseline:=ledger()
	var environments:Array[Node]=game.ui.hero_view.find_children("*","WorldEnvironment",true,false)
	check(environments.size()==1,"Opening directly on food creates exactly one miniature environment")
	var initial_food_ambient:float=environments[0].environment.ambient_light_energy
	check(game.ui.hero.position==Vector2(-8,188) and game.ui.hero.size==Vector2(556,296),"Map miniature retains its existing portrait layout bounds")
	check(not is_instance_valid(game.world) and game.holes.is_empty(),"Opening directly on food creates no gameplay world or holes")
	await frames()
	for map_id in ["food","city"]:
		if game.selected_map!=map_id:game.select_map(map_id)
		await frames()
		geometry(map_id)
		if map_id=="food":composition()
		await active_preview(map_id+" home")
		game.ui.open_holes();await dormant_preview(map_id+" collection")
		game.ui.open_store();await dormant_preview(map_id+" store")
		game.ui.close_menu();await active_preview(map_id+" return home")
	check(initial_food_ambient<environments[0].environment.ambient_light_energy,"Initial food lighting uses the food setup rather than the brighter city default")
	check(ledger()==baseline,"Preview frames, menus and map selection leave economy, collection and round state unchanged")
	check(not is_instance_valid(game.world) and game.holes.is_empty(),"Preview frames cannot spawn gameplay world, rain or holes")
	var counts:Dictionary={}
	for i in 20:
		var retired:Node3D=game.ui.hero_models
		game.select_map("food" if i%2==0 else "city")
		check(not retired.is_inside_tree() and retired.is_queued_for_deletion(),"Switch %d immediately detaches the old model from processing"%i)
		await frames(2)
		check(not is_instance_valid(retired),"Switch %d frees the old model after deferred cleanup"%i)
		var live:=0
		for node in game.ui.hero_view.get_children():
			if node.get("preview")!=null:live+=1
		check(live==1 and game.ui.hero_view.get_child_count()==4,"Switch %d retains exactly one model, environment, light and camera"%i)
		var node_count:=descendants(game.ui).size()
		if counts.has(game.selected_map):check(counts[game.selected_map]==node_count,"Switch %d returns to the same post-cleanup UI node count"%i)
		else:counts[game.selected_map]=node_count
		if game.selected_map=="food":check(is_equal_approx(initial_food_ambient,environments[0].environment.ambient_light_energy),"Food lighting is identical on first creation and later selection")
	check(ledger()==baseline,"Repeated preview replacement preserves economy and collection state")
	game.ui.open_store()
	for map_id in ["food","city"]:
		game.select_map(map_id)
		await dormant_preview(map_id+" replaced while store is open")
	game.ui.close_menu()
	for map_id in ["food","city"]:
		game.select_map(map_id)
		game.start_level();freeze_world()
		await dormant_preview(map_id+" intro")
		game.begin_play();await dormant_preview(map_id+" gameplay")
		game.toggle_pause();await dormant_preview(map_id+" paused")
		check(paused,map_id+": paused test actually pauses the SceneTree")
		game.toggle_pause()
		for phase_name in ["complete","timeout","eaten"]:
			game.phase=phase_name;game.ui.refresh()
			await dormant_preview(map_id+" "+phase_name)
		game.back_home();await frames()
		check(not paused and not is_instance_valid(game.world),map_id+": returning home clears paused gameplay world")
		await active_preview(map_id+" after gameplay")
	game.free();await frames()
	var report:={"checks":checks,"failures":failures,"metrics":metrics,"scope":"Independent natural SceneTree processing, lifecycle, visual-only structure and projected mesh bounds. Gameplay world is frozen during UI route checks; no browser, rendered-pixel or performance claim."}
	print("MAP_PREVIEW_REVIEW "+JSON.stringify(report))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			var path:=arg.trim_prefix("--report=")
			if not path.is_absolute_path() or path.begins_with("res://") or path.begins_with("user://"):quit(2);return
			FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	quit(0 if failures.is_empty() else 1)
