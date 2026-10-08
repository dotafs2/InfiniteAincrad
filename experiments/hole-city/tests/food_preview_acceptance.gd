extends SceneTree
## Visual-only preview acceptance. No gameplay scene, saves or browser access.
const Preview=preload("res://fidelity/food_preview.gd")
var checks:=0
var failures:Array[String]=[]
var metrics:Dictionary={}
func _initialize()->void:run.call_deferred()
func check(ok:bool,message:String)->void:
	checks+=1
	if not ok:failures.append(message);push_error(message)
func frames(count:int)->void:
	for index in count:await process_frame

func meshes(holder:Node3D)->Array[MeshInstance3D]:
	var result:Array[MeshInstance3D]=[]
	for node in holder.find_children("*","MeshInstance3D",true,false):result.append(node)
	return result

func layout(holder:Node3D)->void:
	var all:=meshes(holder)
	var kinds:Dictionary={};var unique:Dictionary={};var materials:Dictionary={};var clusters:Dictionary={}
	var layers:Dictionary={"foreground":[],"midground":[],"background":[]}
	var foods:=0;var road_count:=0;var triangles:=0
	for visual in all:
		unique[visual.mesh.get_instance_id()]=visual.mesh
		materials[visual.material_override.get_instance_id()]=true
		for surface in visual.mesh.get_surface_count():
			var arrays:Array=visual.mesh.surface_get_arrays(surface)
			triangles+=int(arrays[Mesh.ARRAY_INDEX].size()/3)
		if visual.get_meta("preview_road",false):road_count+=1
		if not visual.has_meta("food_kind"):continue
		foods+=1;kinds[visual.get_meta("food_kind")]=true
		var layer:String=visual.get_meta("preview_layer")
		check(layers.has(layer),"Food is assigned a defined composition layer: "+visual.name)
		layers[layer].append(visual.transform*visual.mesh.get_aabb())
		var cluster:String=visual.get_meta("cluster")
		if not clusters.has(cluster):clusters[cluster]=[]
		clusters[cluster].append(visual)
		var bounds:AABB=visual.transform*visual.mesh.get_aabb()
		check(bounds.position.y>=.105,"Food does not cut through the biscuit floor: "+visual.name)
		check(is_equal_approx(visual.material_override.get_shader_parameter("reveal_occluder"),0.0) and visual.material_override.get_shader_parameter("reveal_use_instance")==false,"Preview ingredients remain opaque regardless of gameplay reveal globals: "+visual.name)
	check(foods>=50 and foods<=90 and holder.food_piece_count==foods,"Miniature contains fifty to ninety independently readable food meshes")
	check(kinds.size()==10,"All ten existing food recipes appear in the miniature")
	check(all.size()<=110 and triangles<250000,"Visual-only scene keeps a bounded draw-mesh and triangle inventory")
	check(materials.size()==1 and unique.size()<all.size()/2,"Meshes and the ingredient-glaze material are shared rather than copied per piece")
	check(road_count==3,"A bent avenue and a connecting lane preserve street space")
	var average_depth:Dictionary={};var maximum_height:Dictionary={}
	for layer in layers:
		var sum:=0.0;var highest:=0.0
		for bounds:AABB in layers[layer]:sum+=bounds.get_center().z;highest=maxf(highest,bounds.end.y)
		average_depth[layer]=sum/float(layers[layer].size());maximum_height[layer]=highest
		check(layers[layer].size()>=12,"Each depth layer has enough actual food geometry: "+layer)
	check(average_depth.foreground>average_depth.midground+1 and average_depth.midground>average_depth.background+1,"Actual food bounds create foreground, middle street and distant towers")
	check(maximum_height.background>maximum_height.midground+1 and maximum_height.midground>maximum_height.foreground+1,"The three layers have distinct physical roofline heights")
	var staggered:=0
	for name in ["RoseCake","BlueCake","WaferApartments","BreakfastStack","BurgerStack","DonutStack"]:
		var pieces:Array=clusters[name]
		var shifted:=false;var tilted:=false;var tapered:=false
		for index in range(1,pieces.size()):
			var current:MeshInstance3D=pieces[index];var prior:MeshInstance3D=pieces[index-1]
			shifted=shifted or Vector2(current.position.x-prior.position.x,current.position.z-prior.position.z).length()>.04
			tilted=tilted or absf(current.rotation.x-prior.rotation.x)+absf(current.rotation.z-prior.rotation.z)>.012
			tapered=tapered or current.scale.x<prior.scale.x-.025
			var a:AABB=current.transform*current.mesh.get_aabb();var b:AABB=prior.transform*prior.mesh.get_aabb()
			check(absf(a.position.y-b.end.y)<.06,"Successive pieces maintain a narrow contact seam: "+name+" "+str(index))
		if shifted and tilted and tapered:staggered+=1
	check(staggered>=5,"At least five stacks vary individual position, tilt and scale")
	var saturated:=0;var colored:=0;var low_roughness:=1.0;var high_roughness:=0.0
	for mesh:Mesh in unique.values():
		for surface in mesh.get_surface_count():
			var arrays:Array=mesh.surface_get_arrays(surface)
			var colors:PackedColorArray=arrays[Mesh.ARRAY_COLOR]
			check(colors.size()==arrays[Mesh.ARRAY_VERTEX].size(),"Every shared mesh retains baked ingredient colors and finish data")
			for color in colors:
				colored+=1
				if color.s>.55:saturated+=1
				low_roughness=minf(low_roughness,color.a);high_roughness=maxf(high_roughness,color.a)
	check(saturated>colored*.35 and low_roughness<=.21 and high_roughness>=.57,"Original saturated food colors retain distinct icing gloss and biscuit roughness")
	metrics.food_pieces=foods;metrics.draw_meshes=all.size();metrics.unique_meshes=unique.size();metrics.triangles=triangles
	metrics.layer_counts=holder.layer_counts.duplicate();metrics.average_depth=average_depth;metrics.maximum_height=maximum_height
	metrics.saturated_vertex_fraction=float(saturated)/float(colored)

func bounds(holder:Node3D,camera:Camera3D)->void:
	var all:=meshes(holder);var minimum_margin:=INF
	for index in 72:
		holder.preview.rotation.y=TAU*float(index)/72.0
		var fit:=true
		for visual in all:
			var box:AABB=visual.mesh.get_aabb()
			for endpoint in 8:
				var at:Vector3=visual.global_transform*box.get_endpoint(endpoint)
				var pixel:Vector2=camera.unproject_position(at)
				var margin:=minf(minf(pixel.x,640-pixel.x),minf(pixel.y,560-pixel.y))
				minimum_margin=minf(minimum_margin,margin)
				if not camera.is_position_in_frustum(at) or margin<24:fit=false
		check(fit,"All actual mesh bounds fit the unchanged hero camera with24px safety at rotation %d"%(index*5))
	holder.preview.rotation.y=0.0
	metrics.minimum_rotation_margin_px=minimum_margin

func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	var viewport:=SubViewport.new();viewport.size=Vector2i(640,560);viewport.own_world_3d=true
	viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;root.add_child(viewport)
	var camera:=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=21
	viewport.add_child(camera);camera.position=Vector3(19,24,26);camera.look_at(Vector3(0,4,0));camera.current=true
	var holder:=Preview.new();viewport.add_child(holder);holder.set_process(false);holder.build_preview()
	await frames(3)
	check(holder.get_child_count()==1 and holder.get_child(0)==holder.preview,"Temporary mesh builder is freed before the preview is presented")
	check(holder.find_children("*","PhysicsBody3D",true,false).is_empty() and holder.find_children("*","CollisionShape3D",true,false).is_empty(),"Menu keeps no food rigid bodies or collision shapes")
	check(not holder.is_physics_processing(),"Lightweight preview has no gameplay physics callback")
	layout(holder);bounds(holder,camera)
	var cached:Dictionary={}
	for visual in meshes(holder):
		if visual.has_meta("source_mesh_key"):cached[visual.get_meta("source_mesh_key")]=visual.mesh
	var material:Material=meshes(holder)[0].material_override
	var old_pivot:WeakRef=weakref(holder.preview);holder.build_preview();await frames(3)
	check(old_pivot.get_ref()==null and holder.get_child_count()==1,"Rebuilding replaces the old pivot immediately instead of retaining duplicate scenery")
	check(not holder.is_processing(),"Rebuild respects the UI's disabled processing state")
	for visual in meshes(holder):
		if visual.has_meta("source_mesh_key"):check(visual.mesh==cached[visual.get_meta("source_mesh_key")],"Rebuild reuses each original cached food resource")
	var second:=Preview.new();viewport.add_child(second);second.set_process(false);second.build_preview();await frames(3)
	check(meshes(second)[0].material_override==material,"Repeated map selections share one opaque ingredient material")
	for visual in meshes(second):
		if visual.has_meta("source_mesh_key"):check(visual.mesh==cached[visual.get_meta("source_mesh_key")],"A second preview reuses the existing food resource cache")
	second.free()
	var start:float=holder.preview.rotation.y;await frames(5)
	check(holder.preview.rotation.y==start,"Hidden preview remains still across actual SceneTree frames")
	holder.set_process(true);await frames(6);holder.set_process(false)
	check(holder.preview.rotation.y>start,"Visible preview rotates through its real process callback")
	for hz in [30,60,120]:
		holder.preview.rotation.y=0
		for step in hz:holder._process(1.0/float(hz))
		check(absf(holder.preview.rotation.y-.10)<.000001,"One simulated second turns the preview0.10rad independent of update rate: "+str(hz))
	var weak:WeakRef=weakref(holder);viewport.free();await frames(3)
	check(weak.get_ref()==null,"Closing the preview releases its scene hierarchy")
	print("FOOD_PREVIEW_ACCEPTANCE "+JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics,"scope":"Headless mesh/resource/bounds/controller acceptance; no browser or phone performance claim"}))
	quit(0 if failures.is_empty() else 1)
