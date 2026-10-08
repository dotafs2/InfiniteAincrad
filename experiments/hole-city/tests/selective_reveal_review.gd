extends SceneTree
## Independent buildings-only policy review. Every food, including large
## architectural food tiers, stays opaque even under stale reveal state.
const Reveal=preload("res://fidelity/hole_reveal.gd")
const FoodCity=preload("res://fidelity/food_city.gd")
const Palette=preload("res://fidelity/palette.gdshader")
const Cache=preload("res://fidelity/fracture_cache.gd")
class FixtureBody:
	extends Node3D
	var category:="building"
	var height:=3.2
	var half_size:=Vector3(1.2,1.6,1.2)
	var freeze:=true
	var consumed:=false
	var fractured:=false
	var claimed_by:Node3D
class FixtureCity:
	extends Node3D
	var foods:Array[Node3D]=[]
var game:Node3D
var checks:=0
var failures:Array[String]=[]
var evidence:Dictionary={}
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func pause_simulation()->void:
	game.set_process(false);game.set_physics_process(false);game.city.set_process(false);game.city.set_physics_process(false)
	for body in game.city.foods:
		if is_instance_valid(body):body.set_physics_process(false)
	for h in game.holes:h.set_process(false);h.set_physics_process(false)
func materials(node:Node)->Array:
	var out:Array=[]
	if node is GeometryInstance3D and node.material_override!=null:out.append(node.material_override)
	elif node is MeshInstance3D and node.mesh!=null:
		for i in node.mesh.get_surface_count():out.append(node.get_active_material(i))
	for child in node.get_children():out.append_array(materials(child))
	return out
func material_weight(material:Material)->float:
	if not material is ShaderMaterial or material.shader==null:return 0.0
	if not "hole_reveal_discard" in material.shader.code and not "hole_reveal_mask" in material.shader.code and not "hole_reveal_body_mask" in material.shader.code:return 0.0
	var value=material.get_shader_parameter("reveal_occluder")
	# A reveal shader with no explicit zero-default opt-in is the broad v0.8.1
	# behavior this independent review is intended to catch.
	if value==null:return 1.0
	return float(value)
func effective_weight(body:Node3D)->float:
	var participates:=false
	for material in materials(body):
		if material is ShaderMaterial and material.shader!=null and ("hole_reveal_mask" in material.shader.code or "hole_reveal_discard" in material.shader.code or "hole_reveal_body_mask" in material.shader.code):participates=true
	# CPU state is not an opacity oracle when the shader has no reveal path.
	# The independent windowless GL probe executes that actual food shader.
	if not participates:return 0.0
	if "batch" in body and body.batch!=null:
		# Read CPU-authoritative dispatch state. The headless dummy renderer does
		# not retain native MultiMesh buffers; GPU execution is a separate probe.
		return body.reveal_weight
	var result:=0.0
	for material in materials(body):result=maxf(result,material_weight(material))
	return result
func fixture_body(owner:FixtureCity,size:Vector3,at:Vector3,category:="building")->FixtureBody:
	var body:=FixtureBody.new();body.half_size=size*.5;body.height=size.y;body.category=category
	body.set_meta("dither_building",category=="building")
	owner.add_child(body);body.position=at
	var view:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=size;view.mesh=mesh
	var material:=ShaderMaterial.new();material.shader=Palette;material.set_shader_parameter("reveal_occluder",0.0);view.material_override=material;body.add_child(view)
	owner.foods.append(body);return body
func overhead_camera()->void:
	game.player.position=Vector3.ZERO;game.player.radius=.85;game.player.velocity=Vector3.ZERO
	game.camera.position=Vector3(0,18,0);game.camera.look_at(Vector3.ZERO,Vector3.FORWARD)
func geometry_fixture()->void:
	var city:=FixtureCity.new();root.add_child(city)
	var reveal:=Reveal.new();overhead_camera()
	var margin:=fixture_body(city,Vector3(2.4,3.2,2.4),Vector3(2.4,1.625,0))
	var core:=fixture_body(city,Vector3(2.4,3.2,2.4),Vector3(0,1.625,0))
	var wide:=fixture_body(city,Vector3(10,3.2,2.4),Vector3(4.5,1.625,0))
	var below:=fixture_body(city,Vector3(3,4,3),Vector3(0,-2.1,0))
	var above:=fixture_body(city,Vector3(3,4,3),Vector3(0,22,0))
	var low:=fixture_body(city,Vector3(12,1,12),Vector3(0,.525,0))
	var thin:=fixture_body(city,Vector3(1,8,1),Vector3(0,4.025,0))
	var tall:=fixture_body(city,Vector3(3,24,3),Vector3(2,12.025,0))
	var unmarked:=fixture_body(city,Vector3(6,6,6),Vector3(0,3.025,0));unmarked.remove_meta("dither_building")
	var excluded:Array=[]
	for category in ["person","vehicle","lamp","sign","ambient_actor","authored_actor","food_cake","building_fragment"]:
		excluded.append(fixture_body(city,Vector3(6,6,6),Vector3(0,3.025,0),category))
	reveal.bind_city(city);reveal.tick(game.camera,game.player,1,true)
	# Under this vertical camera every point on the side building has projected
	# x>=1.2*18/(18-.025)>1.2: rigorously outside the actual .85 mouth, although
	# the near wall is inside the expanded1.85 aperture. No hull-copy oracle.
	check(1.2*18.0/(18.0-.025)>game.player.radius,"Independent projection bound excludes the nearby building from the actual mouth")
	check(reveal.sample_mask(Vector3(1.2,1,0),game.camera.position,game.camera.global_basis.z)>.1,"False-positive fixture really lies inside the expanded shader aperture")
	check(not reveal.blocks_core(margin,game.camera,game.player) and reveal.body_reveal_weight(margin)==0 and effective_weight(margin)==0,"Nearby building outside actual mouth stays solid despite expanded margin")
	check(reveal.blocks_core(core,game.camera,game.player) and reveal.body_reveal_weight(core)>0 and effective_weight(core)>0,"True large intact shell covering the mouth can reveal")
	check(reveal.blocks_core(wide,game.camera,game.player) and reveal.body_reveal_weight(wide)>0,"A wide building edge qualifies even with distant body center")
	check(not reveal.blocks_core(below,game.camera,game.player) and reveal.body_reveal_weight(below)==0,"Below-ground building cannot be foreground")
	check(not reveal.blocks_core(above,game.camera,game.player) and reveal.body_reveal_weight(above)==0,"Building wholly above camera cannot cover the opening")
	check(not reveal.is_structural_candidate(low) and reveal.body_reveal_weight(low)==0,"Large flat mass does not qualify as large architecture")
	check(not reveal.is_structural_candidate(thin) and reveal.body_reveal_weight(thin)==0,"Tall narrow pole does not qualify as large architecture")
	check(reveal.blocks_core(tall,game.camera,game.player),"Camera-height clipping retains a genuinely covering tall building")
	check(not reveal.is_structural_candidate(unmarked) and reveal.body_reveal_weight(unmarked)==0,"A large building category without explicit house opt-in remains opaque")
	for body in excluded:check(not reveal.is_structural_candidate(body) and reveal.body_reveal_weight(body)==0 and effective_weight(body)==0,"Oversized "+body.category+" stays solid on the exact opening ray")
	game.player.velocity=Vector3(7,0,0);reveal.tick(game.camera,game.player,1,true)
	check(reveal.lookahead.length()>1 and reveal.body_reveal_weight(margin)==0,"Movement lookahead cannot enable a nonblocking nearby shell")
	core.claimed_by=game.player;reveal.tick(game.camera,game.player,1,true)
	check(reveal.body_reveal_weight(core)==0 and effective_weight(core)==0,"Claimed structural mass becomes fully visible immediately")
	core.claimed_by=null;core.freeze=false;reveal.tick(game.camera,game.player,1,true)
	check(reveal.body_reveal_weight(core)==0 and effective_weight(core)==0,"Released structural mass is never fading debris")
	core.freeze=true;core.consumed=true;reveal.tick(game.camera,game.player,1,true)
	check(reveal.body_reveal_weight(core)==0,"Consumed structure cannot retain a reveal weight")
	core.consumed=false
	for yaw in [0.0,PI*.5,PI,PI*1.5]:
		var offset:=Basis(Vector3.UP,yaw)*Vector3(10,18,14)
		game.camera.position=offset;game.camera.look_at(Vector3.ZERO)
		var lateral:=Vector3(-offset.z,0,offset.x).normalized()
		margin.position=lateral*5.0+Vector3.UP*1.625;game.player.velocity=lateral*7.0
		reveal.tick(game.camera,game.player,1,true)
		check(reveal.blocks_core(core,game.camera,game.player) and reveal.body_reveal_weight(core)>0,"Actual diagonal follow-camera ray recognizes a covering shell at each yaw")
		check(not reveal.blocks_core(margin,game.camera,game.player) and reveal.body_reveal_weight(margin)==0,"Actual diagonal follow-camera ignores side structure despite movement toward it")
	reveal.reset(true);city.free()
func visible_triangle_hits(body:Node3D,endpoints:Array[Vector3])->int:
	# Independent direct triangle intersections, not the controller's cached BVH
	# or its projected-box/ring-sample implementation.
	var triangles:=PackedVector3Array()
	for node in body.find_children("*","MeshInstance3D",true,false):
		if node.mesh==null:continue
		for point in node.mesh.get_faces():triangles.append(node.global_transform*point)
	var hits:=0
	for endpoint in endpoints:
		for i in range(0,triangles.size(),3):
			if Geometry3D.segment_intersects_triangle(game.camera.global_position,endpoint,triangles[i],triangles[i+1],triangles[i+2])!=null:
				hits+=1;break
	return hits
func mouth_probes()->Array[Vector3]:
	var points:Array[Vector3]=[game.player.global_position]
	for radius in [.5,1.0]:
		for i in 32:
			var angle:=float(i)*TAU/32.0
			points.append(game.player.global_position+Vector3(cos(angle),0,sin(angle))*game.player.radius*radius)
	return points
func hollow_fixture()->void:
	var city:=FixtureCity.new();root.add_child(city)
	var arch:=FixtureBody.new();arch.height=9;arch.half_size=Vector3(1.7,4.5,.3)
	arch.set_meta("dither_building",true)
	city.add_child(arch);arch.position=Vector3(0,4.525,3.5);city.foods.append(arch)
	for piece in [{"at":Vector3(-1.45,0,0),"size":Vector3(.5,9,.6)},{"at":Vector3(1.45,0,0),"size":Vector3(.5,9,.6)},{"at":Vector3(0,4,0),"size":Vector3(3.4,1,.6)}]:
		var mesh:=BoxMesh.new();mesh.size=piece.size
		var view:=MeshInstance3D.new();view.mesh=mesh;view.position=piece.at
		var material:=ShaderMaterial.new();material.shader=Palette;material.set_shader_parameter("reveal_occluder",0.0)
		view.material_override=material;arch.add_child(view)
	var reveal:=Reveal.new();game.player.position=Vector3.ZERO;game.player.radius=.85;game.player.velocity=Vector3.ZERO
	game.camera.position=Vector3(0,18,14);game.camera.look_at(Vector3.ZERO)
	reveal.bind_city(city);reveal.tick(game.camera,game.player,1,true)
	var empty_hits:=visible_triangle_hits(arch,mouth_probes())
	check(reveal.blocks_core(arch,game.camera,game.player),"Hollow arch deliberately overlaps the mouth with its broad bounds")
	check(empty_hits==0,"Independent65ray triangle probe passes through the arch opening")
	check(reveal.sample_mask(Vector3(1.2,4.5,3.5),game.camera.position,game.camera.global_basis.z)>.1,"Visible arch side lies inside expanded mask and would be incorrectly faded by bounds alone")
	check(reveal.body_reveal_weight(arch)==0 and effective_weight(arch)==0,"Arch with clear opening stays entirely opaque despite intersecting broad bounds")
	game.player.position.x=1.9;game.camera.look_at(game.player.position);reveal.tick(game.camera,game.player,1,true)
	var solid_hits:=visible_triangle_hits(arch,[game.player.global_position])
	check(solid_hits==1 and reveal.body_reveal_weight(arch)>0 and effective_weight(arch)>0,"Moving mouth ray onto solid arch pillar enables reveal")
	evidence["hollow_arch"]={"clear_opening_ray_hits":empty_hits,"solid_side_center_ray_hits":solid_hits,"clear_opening_probe_count":65}
	reveal.reset(true);city.free()
	# Actual food geometry retains both its open center and its opaque dough.
	# Old architectural metadata cannot opt any food back into reveal.
	var food_city:=FoodCity.new();root.add_child(food_city);food_city.game=game
	var donut:Node3D=food_city.food("donut",Vector2.ZERO,3.0,8,true)
	donut.position.y=5.0;donut.set_meta("food_building",true);donut.set_meta("structural_shell",true)
	donut.set_meta("structure_height",6.0);donut.set_meta("structure_width",6.0);food_city.batch_static_food()
	overhead_camera();reveal=Reveal.new();reveal.bind_city(food_city);reveal.tick(game.camera,game.player,1,true)
	empty_hits=visible_triangle_hits(donut,mouth_probes())
	check(empty_hits==0 and not reveal.is_structural_candidate(donut),"Actual giant donut has65clear center rays and stays excluded despite old structural metadata")
	check(reveal.body_reveal_weight(donut)==0 and donut.reveal_weight==0,"Hollow batched food shell remains opaque through its open center")
	game.player.position.x=2.7;game.camera.look_at(game.player.position,Vector3.FORWARD);reveal.tick(game.camera,game.player,1,true)
	solid_hits=visible_triangle_hits(donut,[game.player.global_position])
	check(solid_hits==1 and reveal.body_reveal_weight(donut)==0 and effective_weight(donut)==0,"Actual donut dough really blocks the ray but remains opaque under the buildings-only policy")
	evidence["hollow_donut"]={"clear_opening_ray_hits":empty_hits,"solid_dough_center_ray_hits":solid_hits,"clear_opening_probe_count":65}
	reveal.reset(true);food_city.free()
func actual_map(map_id:String)->void:
	game.selected_map=map_id;game.start_level();pause_simulation();game.begin_play();overhead_camera()
	game.update_reveal(1)
	var categories:Dictionary={};var nonstructural:=0;var incorrectly_enabled:=[];var structural:=0
	var mismatched:Array=[]
	for body in game.city.foods:
		# Independent policy oracle: map food never qualifies, including its
		# food_building/structural_shell metadata. City eligibility requires an
		# explicit house tag plus the object's own minimum dimensions.
		var expected:bool=map_id=="city" and body.category=="building" and body.get_meta("dither_building",false) and body.height>=3.0 and maxf(body.half_size.x,body.half_size.z)*2.0>=2.4
		if game.reveal.is_structural_candidate(body)!=expected:mismatched.append(str(body.name))
		if expected:structural+=1;continue
		nonstructural+=1;categories[body.category]=int(categories.get(body.category,0))+1
		if game.reveal.body_reveal_weight(body)!=0 or effective_weight(body)!=0:incorrectly_enabled.append(str(body.name))
	check(mismatched.is_empty(),map_id+": production eligibility agrees with an independent buildings-only scene oracle")
	check(nonstructural>200 and incorrectly_enabled.is_empty(),map_id+": all independently excluded scene objects stay fully visible")
	check(structural>0 if map_id=="city" else structural==0 and game.reveal.occluders.is_empty(),map_id+": actual houses remain eligible while the entire food map has no registered occluders")
	evidence[map_id]={"nonstructural":nonstructural,"structural":structural,"protected_categories":categories,"incorrectly_enabled":incorrectly_enabled}
	if map_id=="city":
		var collapse_modes:=["cached","missing","incomplete"]
		for index in collapse_modes.size():
			var mode:String=collapse_modes[index]
			var body:Node3D=game.city.building_visuals[index].body
			body.position=Vector3(0,body.height*.5+.025,0)
			game.update_reveal(1)
			check(game.reveal.body_reveal_weight(body)>0 and effective_weight(body)>0,"Whole building really was a revealed blocker before "+mode+" release")
			if mode=="missing":body.fracture_cache=null
			elif mode=="incomplete":
				var cache:Resource=body.fracture_cache
				var incomplete:=Cache.new();incomplete.cells=cache.cells.duplicate();incomplete.meshes=cache.meshes.duplicate();incomplete.exterior_vertex_counts=cache.exterior_vertex_counts.duplicate();incomplete.meshes[7]=null
				body.fracture_cache=incomplete
			# Actual physics callers have already admitted and released the body.
			body.claimed_by=game.player;body.freeze=false
			var views:Array=body.find_children("*","MeshInstance3D",true,false)
			var original:Array=[]
			for view in views:original.append({"node":view,"mesh":view.mesh,"pose":view.global_transform,"material":view.material_override,"faces":view.mesh.get_faces()})
			var physics:Dictionary={"pose":body.global_transform,"linear":body.linear_velocity,"angular":body.angular_velocity,"layer":body.collision_layer,"mask":body.collision_mask}
			var name_before:String=body.name;body.fracture_building(game.player)
			var count:=0
			for piece in game.city.foods:
				if is_instance_valid(piece) and piece.get_meta("fracture_parent","")==name_before:
					count+=1
			var after:Array=[]
			for view in body.find_children("*","MeshInstance3D",true,false):after.append({"node":view,"mesh":view.mesh,"pose":view.global_transform,"material":view.material_override,"faces":view.mesh.get_faces()})
			check(count==0 and body.fracture_piece_count==0 and body.visible and not body.consumed and original==after,mode+": collapse retains every complete placed facade without invented surfaces")
			check(effective_weight(body)==0 and body.fracture_material.get_shader_parameter("visibility")==1.0 and physics=={"pose":body.global_transform,"linear":body.linear_velocity,"angular":body.angular_velocity,"layer":body.collision_layer,"mask":body.collision_mask},mode+": actual material clears immediately without altering the falling body's pose, collision or velocity")
			body.fracture_building(game.player)
			check(body.fracture_piece_count==0 and body.points==48 and not body.is_queued_for_deletion(),mode+": repeated collapse reserves one total and keeps the complete falling owner")
			await process_frame;await process_frame;game.update_reveal(.016)
			check(is_instance_valid(body) and effective_weight(body)==0 and game.phase=="playing",mode+": the original released house remains opaque during subsequent reveal updates")
	else:
		var toppers:=0
		var families:Dictionary={}
		for tower in game.city.towers:
			check(tower.tiers.all(func(body):return not game.reveal.is_structural_candidate(body) and game.reveal.body_reveal_weight(body)==0 and effective_weight(body)==0),"Every actual "+tower.family+" food tier remains opaque regardless of assembled height")
			if not families.has(tower.family):
				families[tower.family]=true
				assert_food_blocks_but_solid(tower.base,game.reveal,"actual "+tower.family+" tier")
			var last:Node3D=tower.tiers.back()
			if tower.family!="berry_water_tower":
				toppers+=1;check(not last.get_meta("structural_shell",false) and effective_weight(last)==0,"Small roof decoration never becomes a blocker merely from tower_id")
		check(toppers>50,"Real small topper/crown exclusions are exercised")
		game.city.rain_enabled=false
		for kind in game.city.Shapes.KINDS:
			var rain:Node3D=game.city.spawn_rain(kind,Vector2.ZERO,8)
			check(not game.reveal.is_structural_candidate(rain) and effective_weight(rain)==0,"Airborne "+kind+" remains solid inside the opening ray")
			rain.freeze=true;rain.set_physics_process(false);rain.rain_landed=true;rain.sleeping=true;game.city.batch_settled_rain()
			check(rain.batch!=null and effective_weight(rain)==0,"Settled "+kind+" has zero per-instance reveal")
			rain.expose_visual();check(effective_weight(rain)==0,"Released "+kind+" still uses opaque individual material")
	game.finish("timeout");game.back_home();await process_frame;await process_frame
func assert_food_blocks_but_solid(body:Node3D,reveal:RefCounted,label:String)->void:
	var view:MeshInstance3D=body.food_visual
	var faces:PackedVector3Array=view.mesh.get_faces()
	var point:=Vector3.ZERO;var found:=false
	for i in range(0,faces.size(),3):
		var a:Vector3=view.global_transform*faces[i];var b:Vector3=view.global_transform*faces[i+1];var c:Vector3=view.global_transform*faces[i+2]
		if absf((b-a).cross(c-a).normalized().y)>.5 and (a.y+b.y+c.y)/3.0>.02:
			point=(a+b+c)/3.0;found=true;break
	check(found,label+": fixture chooses a real mesh face rather than inventing a bounding-box obstruction")
	game.camera.position=Vector3(point.x,point.y+18.0,point.z)
	game.player.position=Vector3(point.x,0,point.z);game.player.velocity=Vector3.ZERO;game.player.radius=.85
	game.camera.look_at(game.player.position,Vector3.FORWARD)
	var hits:=visible_triangle_hits(body,[game.player.global_position])
	reveal.tick(game.camera,game.player,1,true)
	check(hits==1,label+": the actual visible recipe mesh intersects the center camera-to-mouth ray")
	check(not reveal.is_structural_candidate(body) and reveal.body_reveal_weight(body)==0 and effective_weight(body)==0,label+": actual ray obstruction does not opt food into building reveal")
func all_food_kinds()->void:
	var city:=FoodCity.new();root.add_child(city);city.game=game
	var bodies:Array=[]
	for kind in FoodCity.Shapes.KINDS:
		var body:Node3D=city.food(kind,Vector2.ZERO,3.0,8,true)
		body.position.y=5.0
		# Deliberately poison all former aggregate metadata and even the new
		# explicit flag. A food category must still never qualify as a house.
		body.set_meta("food_building",true);body.set_meta("structural_shell",true)
		body.set_meta("structure_height",99.0);body.set_meta("structure_width",99.0)
		body.set_meta("dither_building",true)
		bodies.append(body)
	city.batch_static_food()
	var reveal:=Reveal.new();reveal.bind_city(city)
	check(reveal.occluders.is_empty(),"All ten oversized food recipes reject old aggregate metadata and a forged house tag")
	city.food_material.set_shader_parameter("reveal_occluder",1.0)
	city.food_material.set_shader_parameter("reveal_use_instance",true)
	city.food_batch_material.set_shader_parameter("reveal_occluder",1.0)
	city.food_batch_material.set_shader_parameter("reveal_use_instance",true)
	for body in bodies:
		var kind:String=body.get_meta("food_kind")
		body.set_reveal_weight(1.0)
		check(body.reveal_weight==0.0,kind+": deprecated weight setter rejects positive reveal")
		body.reveal_weight=1.0
		body.batch.set_instance_custom_data(body.batch_index,Color(1,1,1,1))
		assert_food_blocks_but_solid(body,reveal,"oversized "+kind+" with stale CPU/uniform/instance state")
		body.expose_visual()
		check(body.batch==null and body.food_visual.visible and effective_weight(body)==0,kind+": exposed food stays opaque despite its stale positive material uniforms")
		body.set_reveal_weight(0)
	evidence["food_policy_poisoning"]={"recipes":bodies.size(),"registered_food_occluders":reveal.occluders.size(),"legacy_uniforms":1,"instance_custom":"(1,1,1,1)","scope":"CPU dispatch/material graph only; shipped vertex/fragment execution is verified by the separate windowless GL harness."}
	reveal.reset(true);city.free()
func mixed_food_batch()->void:
	var city:=FoodCity.new();root.add_child(city);city.game=game
	var bodies:Array=[]
	for i in 3:
		var body:Node3D=city.food("cake",Vector2(.1*i,0),1.5,2,true)
		body.set_meta("structural_shell",i!=1);body.set_meta("food_building",i!=1);body.set_meta("structure_height",6.0);body.set_meta("structure_width",3.0)
		bodies.append(body)
	city.batch_static_food();var mm:MultiMesh=bodies[0].batch
	check(mm==bodies[1].batch and mm==bodies[2].batch,"Independent fixture mixes loose and formerly structural copies in the same real food batch")
	var reveal:=Reveal.new();overhead_camera();reveal.bind_city(city);reveal.tick(game.camera,game.player,1,true)
	check(reveal.occluders.is_empty() and bodies.all(func(body):return reveal.body_reveal_weight(body)==0),"Shared batch controller does not register any food, including former structural members")
	check(bodies.all(func(body):return body.reveal_weight==0),"Every newly batched food begins with zero authoritative reveal state")
	check(city.food_material.get_shader_parameter("reveal_use_instance")==false and city.food_material.get_shader_parameter("reveal_occluder")==0,"Standalone Glaze stays explicitly nonoccluding")
	check(city.food_batch_material!=city.food_material and city.food_batch_material.get_shader_parameter("reveal_use_instance")==false,"Static food batch also disables its obsolete per-instance opt-in")
	bodies[2].set_reveal_weight(1.0)
	check(bodies[2].reveal_weight==0,"Positive legacy setter cannot opt a batch member into reveal")
	# A direct stale field write intentionally bypasses the clamped API. Even
	# carried through compaction, this no longer affects the food shader.
	bodies[2].reveal_weight=1.0;mm.set_instance_custom_data(2,Color(1,1,1,1))
	city.food_batch_material.set_shader_parameter("reveal_use_instance",true)
	city.food_batch_material.set_shader_parameter("reveal_occluder",1.0)
	bodies[0].expose_visual()
	check(bodies[2].batch_index==0 and bodies[1].batch_index==1 and bodies[2].batch_members[0]==bodies[2],"Actual native batch release compacts the moved member's ownership index")
	check(bodies.all(func(body):return effective_weight(body)==0),"Compaction cannot make loose, formerly structural or released food fade, even with stale positive state")
	check(mm.visible_instance_count==2 and bodies[2].batch_members.size()==2,"Released slot leaves the active batch range")
	check(not bodies[0].get_meta("structural_shell") and bodies[0].batch==null and effective_weight(bodies[0])==0,"Detached food immediately becomes visible independent debris")
	reveal.tick(game.camera,game.player,1,true)
	check(bodies.all(func(body):return reveal.body_reveal_weight(body)==0 and effective_weight(body)==0),"Controller cannot re-enable any food peer after compaction")
	bodies[2].lose_support(game.player);bodies[2].freeze=true;bodies[2].set_physics_process(false);reveal.tick(game.camera,game.player,1,true)
	check(not bodies[2].get_meta("structural_shell") and effective_weight(bodies[2])==0,"Support loss and later sleep retain food opacity")
	reveal.reset(true);city.free()
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	game=load("res://fidelity/main.tscn").instantiate();root.add_child(game)
	check(game.progress_file().is_empty(),"Review does not access player progress")
	game.start_level();pause_simulation()
	geometry_fixture();hollow_fixture();await actual_map("city");await actual_map("food")
	# Restore a live player after Home removed its world, for the independent
	# three-member batch fixture without rebuilding the complete food scene.
	game.selected_map="city";game.start_level();pause_simulation();all_food_kinds();mixed_food_batch()
	game.free();await process_frame
	print("SELECTIVE_REVEAL_REVIEW "+JSON.stringify({"checks":checks,"failures":failures,"evidence":evidence,"scope":"Independent buildings-only policy, actual food obstruction, stale-state/material and lifecycle review; GPU equation coverage is separate and no phone performance is claimed"}))
	quit(0 if failures.is_empty() else 1)
