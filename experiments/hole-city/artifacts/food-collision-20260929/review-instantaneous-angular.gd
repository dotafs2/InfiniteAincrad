extends SceneTree
## Non-author collision/resource regression. Authoring visuals are compared with
## independently extracted hashes from the preserved pre-fix exported package.
const KINDS:=["bacon","egg","cake","donut","burger","cookie","berry","sushi","pancake","pizza"]
const EXPECTED_VISUALS:Dictionary={
  "bacon": "0efadf7468027a0e325281b5b5a6c934a1c6d010f765e0c87ae52b1663beed77",
  "bacon_tower": "fc48aa0e463d998284744c4588d4f9220f0cd815b4a9029467dc84c457fc8940",
  "berry": "d8bbb14ecba5dadf40092ede969f186349dbf29b175585d495fda28aa12d76a3",
  "berry_tower": "d73e437a0f4369ef75992556d0adb799bac7cb9a0cbc5ca403b3e470858eff28",
  "burger": "fd717343ea18df817395b04ce95de2b96d76d3e713ffe175b5b50130e23a28d1",
  "burger_shop": "3da7d55a8a52e6e0834de6fbda12b34e0394baea537913e81fe05f4f6749d25a",
  "burger_tower": "bac0ba86206ced4d1262e94143dc84bbb9638c3ec99629c86ee601d8f70dd9e9",
  "cake_0": "7c9b98ebf7113bcbe08265ffbad94c36edec301adc568eae5a8a5890fec13b5c",
  "cake_1": "3e48da0556d16db2919fe0a257b22b97381db850cf7a4a277931a6bc419d0990",
  "cake_2": "35662a8a8b1385d129ab5bda771d50978232aa041f0a0b663022d7cd9f2d6faf",
  "cake_3": "254edb3a8970c63afe3f6068c32c38d4599609f046387a14518b827629f80cd8",
  "cake_shop": "92c635702bef322a1c34a6defd32bf714193ad9752d9326a6f929d0124e7e031",
  "cake_tower_0": "557a18fbef3f908d90919504e665e6bcb0099c18566f9f007bd34c08a9936590",
  "cake_tower_1": "ecb85a180b64071799d1bda6508a2fbfea890d27f8da75e1d15450c574256da6",
  "cake_tower_2": "47cc2915ccde7a567dc26af0243dec942340be321346050ef1a7771c38e0cd21",
  "cake_tower_3": "2e4c38e0aa81adabfa08f25beebef30abb19b13c1d4135289f7cd2659b290ace",
  "cookie_0": "efcbef12f361ab3fdc0989cc2ad7239ab66609f56d18a746dd27360a05a4084b",
  "cookie_1": "53064bcbcc2b3b7e64f1a851e7fcfda01988c81a638ba2a612d6e63ca299b33a",
  "cookie_2": "240ddd7b68f4ce4d2b0fa632f7c401efb8e9769219d65f5d6ac6ca4901f0f783",
  "cookie_3": "1d67ccde05deea45843d22ac33b3edb6ac076cd79b1573bf74e5ffc05e18b28b",
  "cookie_tower_0": "09b6480d0f6a3af5ca26de6439d6bce1675a1ac5a1b8df13de2627575a09602d",
  "cookie_tower_2": "41b8d92f22845a4c23398e5da89256d0f0ffbaa3eb27df063f2a64070053673c",
  "donut_0": "d339dce4109f3d713e139299feb0558a55af93820c667cc938730be171703ac1",
  "donut_1": "931ce9a5b3826c430057f947afbd84ffc999abefb96f6f115ef0c4b7367b6ff3",
  "donut_2": "674f896ac4b3db463914aeb5449eebc080f478f220e758721cf674e17d4600ee",
  "donut_3": "5a08d252d699d201824256d7eb8325f9f7b69373c014c1466137deedd188b1f5",
  "donut_tower_0": "12e3057f8f0f860dd858ab326a169c8ca92354c2a5af6dff74ccfedf2173b81a",
  "donut_tower_1": "3ef54e5df0c7ff7b85cf6ee506961f7f39d846052b2cf7b4460218763c4373e6",
  "donut_tower_2": "17f3bb9f77ed92c057523dc414aeeb579f6a9149ea5f15df61d47e0b135411b7",
  "donut_tower_3": "05e809cc6b1ed6f3f1658954cd8a6637beec1510e0ab544780b2fb5c6445fc2c",
  "egg": "63bfa13c548540d78b8b9ddc837a9af51f905d834154febbd97fa38334c471b9",
  "egg_tower": "efac565177d9a19b8a812b1a7e9b086c2af029862c148c38b25beafc301d3662",
  "pancake": "30940803b6ced55dc1591a7878f9c090a489cdd09d9a324fb6e84db7ea44ccb7",
  "pancake_tower_0": "3d3b676f476c1d5e9f1ab2b1bffb96c5f146b1780b584a64efee154cc257344f",
  "pancake_tower_1": "3d3b676f476c1d5e9f1ab2b1bffb96c5f146b1780b584a64efee154cc257344f",
  "pancake_tower_2": "3d3b676f476c1d5e9f1ab2b1bffb96c5f146b1780b584a64efee154cc257344f",
  "pancake_tower_3": "3d3b676f476c1d5e9f1ab2b1bffb96c5f146b1780b584a64efee154cc257344f",
  "pizza": "e515a37bb3b0d0a40158009ad51a575f5c4b03a633dc663c4600b7813ff1c08f",
  "pizza_tower": "896d326d4fb60d681a02e29eb5117c3dc21e26f97d7a4f0906313f9aa396d451",
  "sushi": "1de9bb26b40d127c21295218dc8b7a555a4846aa968134dbfc0883e8f2c8923c",
  "sushi_tower": "de8f25c21fd9f4a992e916152f2db2e60b188605a38ccaae0a1ed3d7284b4938"
}
const EXPECTED_SHADER_SHA:="75d79551d9715bf8796490fcb5bfe63cb508622074bcc12b57fc7491893526b2"
var checks:=0
var failures:Array[String]=[]
var metrics:Dictionary={}
var game:Node3D
var unique_shapes:Dictionary={}
var round_count:=0
var structural_round_count:=0
var structural_box_count:=0
var box_count:=0
var largest_radial_inset:=0.0
var receipts:Dictionary={}
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func digest(bytes:PackedByteArray)->String:
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(bytes);return hash.finish().hex_encode()
func mesh_digest(mesh:Mesh)->String:
	var hash:=HashingContext.new();hash.start(HashingContext.HASH_SHA256)
	for surface in mesh.get_surface_count():hash.update(var_to_bytes(mesh.surface_get_arrays(surface)))
	return hash.finish().hex_encode()
func collision(body:Node3D)->Shape3D:
	for child in body.get_children():
		if child is CollisionShape3D:return child.shape
	return null
func round_expected(key:String,kind:String)->bool:
	return kind not in ["bacon","sushi"] and not (key.begins_with("cake_tower") or key=="cake_shop" or key.begins_with("pancake_tower"))
func inspect_body(body:Node3D,label:String)->void:
	var shape:Shape3D=collision(body)
	var extent:Vector3=body.food_visual.mesh.get_aabb().size*body.food_visual.scale
	var radius:float=maxf(extent.x,extent.z)*.5
	var key:String=body.get_meta("food_mesh_key")
	var round:bool=round_expected(key,body.get_meta("food_kind"))
	check(body.half_size.is_equal_approx(extent*.5) and is_equal_approx(body.height,extent.y),label+": collision dimensions retain visual envelope")
	check(is_equal_approx(body.footprint,radius if round else Vector2(extent.x,extent.z).length()*.5),label+": admission footprint retains its previous rule")
	check(body.food_visual.material_override==game.city.food_material and body.food_visual.mesh==game.city.mesh_cache[key],label+": original shared shader and render mesh stay attached")
	if round:
		round_count+=1
		if body.get_meta("structural_shell",false):structural_round_count+=1
		check(shape is ConvexPolygonShape3D,label+": round food uses stable convex contact path")
		if not shape is ConvexPolygonShape3D:return
		check(body.terrain_sweep_points==shape.points,label+": actual body receives the same collision hull for terrain support")
		var dimensions:=Vector2(radius,extent.y)
		if unique_shapes.has(dimensions):check(unique_shapes[dimensions]==shape,label+": identical dimensions share one collision resource")
		else:
			unique_shapes[dimensions]=shape
			var sides:int=game.city.ROUND_COLLISION_SIDES
			check(sides>=8 and sides<=16 and shape.points.size()==sides*2,label+": two complete rings stay within the SAT 16-point face budget")
			var upper:=0;var lower:=0;var valid:=true
			for point in shape.points:
				if not point.is_finite() or absf(Vector2(point.x,point.z).length()-radius)>maxf(.00001,radius*.00001):valid=false
				if absf(point.y-extent.y*.5)<.00001:upper+=1
				elif absf(point.y+extent.y*.5)<.00001:lower+=1
				else:valid=false
			check(valid and upper==sides and lower==sides,label+": exact outer radius/height and finite coordinates")
			var support_min:=INF;var support_max:=0.0
			for step in sides*2:
				var direction:=Vector2(cos(TAU*step/float(sides*2)),sin(TAU*step/float(sides*2)))
				var support:=-INF
				for point in shape.points:support=maxf(support,Vector2(point.x,point.z).dot(direction))
				support_min=minf(support_min,support);support_max=maxf(support_max,support)
			largest_radial_inset=maxf(largest_radial_inset,1.0-support_min/radius)
			check(support_min>=radius*cos(PI/sides)-.00001 and support_max<=radius+.00001 and 1.0-support_min/radius<.02,label+": radial approximation stays within two percent and never exceeds the old radius")
	else:
		box_count+=1
		if body.get_meta("structural_shell",false):structural_box_count+=1
		check(shape is BoxShape3D and shape.size.is_equal_approx(extent),label+": rectangular ingredients retain exact box collider")
		check(body.terrain_sweep_points.is_empty(),label+": box ingredients retain their existing contact path")
func shape_and_resource_fixture()->void:
	var city:Node3D=game.city
	for body in city.foods:
		if body.has_meta("food_kind"):inspect_body(body,str(body.name))
	var probes:Array[Node3D]=[]
	for kind in KINDS:
		for tower in [false,true]:
			for flavor in [0,2,4]:
				var body:Node3D=city.food(kind,Vector2(70,70),.6,3,tower,flavor)
				probes.append(body);inspect_body(body,"New "+kind+" tower="+str(tower)+" flavor="+str(flavor))
	var cylinders:=0
	for collider in city.find_children("*","CollisionShape3D",true,false):
		if collider.shape is CylinderShape3D:cylinders+=1
	check(cylinders==0,"Actual full food scene has no remaining native CylinderShape3D collider")
	check(round_count>1000 and box_count>100,"Inspection exercises both round and rectangular initial food populations")
	check(structural_round_count>0 and structural_box_count>0,"Actual building tiers exercise both round and rectangular collision branches")
	var first:Shape3D=city.round_food_shape(1.0,.5)
	check(first==city.round_food_shape(1.0,.5),"Repeated dimension request returns same cached resource")
	check(first!=city.round_food_shape(1.0001,.5) and first!=city.round_food_shape(1.0,.5001),"Cache does not merge genuinely different radii or heights")
	check(not EXPECTED_VISUALS.is_empty(),"Preserved package supplied a real visual resource baseline")
	check(city.mesh_cache.size()==EXPECTED_VISUALS.size(),"Same complete authored render-mesh inventory as prior package")
	for key in city.mesh_cache:
		check(EXPECTED_VISUALS.has(key) and mesh_digest(city.mesh_cache[key])==EXPECTED_VISUALS.get(key,""),"All vertex/index/normal/color arrays unchanged: "+key)
	check(digest(city.food_material.shader.code.to_utf8_buffer())==EXPECTED_SHADER_SHA,"Ingredient shader code is byte-identical to prior package")
	for body in probes:body.queue_free()
	metrics["structural_round_bodies"]=structural_round_count;metrics["structural_box_bodies"]=structural_box_count;metrics["round_bodies"]=round_count;metrics["box_bodies"]=box_count;metrics["unique_dimensions"]=unique_shapes.size();metrics["max_radial_inset_fraction"]=largest_radial_inset
func receipt(item:Node3D,_owner:Node3D)->void:
	var id:=item.get_instance_id()
	receipts[id]={"count":int(receipts.get(id,{}).get("count",0))+1,"top":item.position.y+item.vertical_extent()}
func physical_fixture()->void:
	var city:Node3D=game.city;var drops:Array[Node3D]=[];var snapshots:Dictionary={};var drop_ids:Array[int]=[]
	for i in KINDS.size():
		var at:=Vector2(62+(i%3)*7,40+(i/3)*8)
		var body:Node3D=city.spawn_rain(KINDS[i],at,5.0)
		body.rotation=Vector3(.12+float(i%3)*.16,float(i)*.21,.18)
		body.angular_velocity=Vector3(.2,-.3,.15)
		drops.append(body);drop_ids.append(body.get_instance_id())
		snapshots[body.get_instance_id()]={"mesh":body.food_visual.mesh,"material":body.food_visual.material_override,"shape":collision(body),"start":body.position}
		inspect_body(body,"Tilted physical rain "+KINDS[i])
	for _i in 540:await physics_frame
	var landed:=0;var rain_rest:Array=[]
	for i in drops.size():
		var body:Node3D=drops[i];var snap:Dictionary=snapshots[body.get_instance_id()]
		check(body.position.is_finite() and body.linear_velocity.is_finite() and body.position.y>=-.05 and body.position.y<2.5,"Real tilted drop settles on ground without explosion: "+KINDS[i])
		check(body.position.y<snap.start.y-2.0,"Food really descended through gravity: "+KINDS[i])
		check(body.food_visual.mesh==snap.mesh and body.food_visual.material_override==snap.material and collision(body)==snap.shape,"Falling preserves geometry, material and shared collider: "+KINDS[i])
		if body.rain_landed:landed+=1
		rain_rest.append({"kind":KINDS[i],"speed":body.linear_velocity.length(),"angular_speed":body.angular_velocity.length(),"position":str(body.position),"landed":body.rain_landed,"sleeping":body.sleeping})
		check(body.linear_velocity.length()<.3 and body.angular_velocity.length()<.5,"Rain contact reaches bounded rest: "+KINDS[i])
	check(landed==10,"All ten tilted rain ingredients register actual landing")
	city.batch_settled_rain()
	var batched:=0
	for body in drops:
		if body.batch!=null:batched+=1
	check(batched>0,"Settled replacement colliders still enter rain batching")
	# Contact-rich non-rain floors use the same replacement and may tumble
	# against another ingredient before reaching the real ground.
	var contact_bodies:Array[Node3D]=[];var next_floor:=.6
	for i in 6:
		var body:Node3D=city.food("cookie" if i%2==0 else "burger",Vector2(70,24),.7,2)
		body.rotation=Vector3(.12*i,.17*i,.2)
		var low:=INF;var high:=-INF
		for point in collision(body).points:
			var height:float=(body.basis*point).y
			low=minf(low,height);high=maxf(high,height)
		body.position.y=next_floor-low
		check(body.position.y+low>=next_floor-.0001,"Pile fixture begins with separated collision envelopes")
		next_floor=body.position.y+high+.16
		body.freeze=false;body.collision_layer=2;body.collision_mask=3
		body.collapse_started=true;body.max_contacts_reported=4;body.set_physics_process(true)
		contact_bodies.append(body)
	for _i in 540:await physics_frame
	var contact_rest:Array=[]
	for body in contact_bodies:
		check(body.position.is_finite() and body.linear_velocity.is_finite() and body.position.y>-.1 and body.position.y<5.0,"Tilted non-rain round food contacts remain finite and supported")
		check(body.linear_velocity.length()<.3 and body.angular_velocity.length()<.5,"Tilted round-food pile settles without persistent rocking")
		contact_rest.append({"kind":body.get_meta("food_kind"),"speed":body.linear_velocity.length(),"angular_speed":body.angular_velocity.length(),"position":str(body.position)})
	var ready_receipts:=receipts.size()
	for start in [0,8]:
		for h in game.holes:h.active=false
		var finish:=mini(start+8,drops.size())
		for index in range(start,finish):
			var body:Node3D=drops[index];var hole:Node3D=game.holes[index-start]
			hole.active=true;hole.enabled=false;hole.radius=2.2;hole.position=Vector3(body.position.x,0,body.position.z);hole._sync_shape()
		game.ground.sync()
		for tick in 210:
			if tick%6==0:game.scan_food()
			await physics_frame
		for index in range(start,finish):
			check(not is_instance_valid(drops[index]) or drops[index].consumed,"Landed ingredient independently falls and collects through real opening: "+KINDS[index])
	check(receipts.size()-ready_receipts>=10,"All ten physical ingredients produce legitimate collection receipts")
	var target_receipts:=0
	for id in drop_ids:
		check(receipts.has(id),"Each specific landed rain body has its own real collection receipt")
		if receipts.has(id):target_receipts+=1
	for id in receipts:check(receipts[id].count==1 and receipts[id].top< -3.5,"Collection occurs only once after complete physical descent")
	# The ordinary-food ground guard must stop supporting pieces as soon as the
	# actual ground is removed; each piece still needs its own complete fall.
	for hole in game.holes:hole.active=false
	game.player.active=true;game.player.enabled=false;game.player.score=0;game.player.award(240)
	game.player.position=Vector3(70,0,24);game.ground.sync()
	await physics_frame
	var ground_query:=PhysicsRayQueryParameters3D.create(Vector3(70,2,24),Vector3(70,-2,24),1)
	check(game.get_world_3d().direct_space_state.intersect_ray(ground_query).is_empty(),"Pile opening removes the actual collision floor")
	var pile_ids:Array[int]=[]
	for body in contact_bodies:
		pile_ids.append(body.get_instance_id())
		check(not body.freeze,"Settled ordinary pile pieces remain physical, never frozen in the air")
	for tick in 240:
		if tick%6==0:game.scan_food()
		await physics_frame
	var pile_receipts:=0
	for id in pile_ids:
		check(receipts.has(id),"Ordinary pile piece independently falls after its real floor opens")
		if receipts.has(id):
			pile_receipts+=1
			check(receipts[id].count==1 and receipts[id].top< -3.5,"Ordinary piece is awarded only once after complete descent")
	# Rebuilding ground above an already-entered piece may not pull it back up.
	game.player.position=Vector3(72,0,10);game.ground.sync()
	var departing:Node3D=city.food("cookie",Vector2(72,10),.6,2)
	departing.position.y=2.0;departing.rotation=Vector3(.15,.1,.2)
	departing.lose_support(null)
	var departed_id:=departing.get_instance_id();var under_floor:=false
	for tick in 120:
		if tick%6==0:game.scan_food()
		await physics_frame
		if is_instance_valid(departing) and departing.position.y+departing.vertical_extent()<-.05:
			under_floor=true;break
	check(under_floor,"Ordinary food genuinely enters the opening before it moves away")
	game.player.position=Vector3(40,0,-60);game.ground.sync()
	var pulled_up:=false
	for tick in 180:
		await physics_frame
		if is_instance_valid(departing) and departing.position.y+departing.vertical_extent()>0.0:pulled_up=true
	check(not pulled_up,"Restored ground never teleports a fully entered food piece above the floor")
	check(receipts.has(departed_id) and receipts[departed_id].count==1 and receipts[departed_id].top< -3.5,"Departed-mouth fall preserves one legitimate collection after full descent")
	# A thin ingredient initially bridges the rim. Ground correction may not
	# turn that partial support into a permanent platform across the opening.
	game.player.score=0;game.player.award(10);game.player.position=Vector3(69.05,0,16);game.ground.sync()
	await physics_frame
	var rim_piece:Node3D=city.food("pizza",Vector2(70,16),.6,2)
	rim_piece.rotation=Vector3(.08,.2,.14);rim_piece.position.y=rim_piece.vertical_extent()+.02
	var rim_id:=rim_piece.get_instance_id();var rim_start:float=rim_piece.position.y
	var center_ray:=PhysicsRayQueryParameters3D.create(Vector3(70,2,16),Vector3(70,-2,16),1)
	var edge_ray:=PhysicsRayQueryParameters3D.create(Vector3(70+rim_piece.footprint,2,16),Vector3(70+rim_piece.footprint,-2,16),1)
	check(game.get_world_3d().direct_space_state.intersect_ray(center_ray).is_empty() and not game.get_world_3d().direct_space_state.intersect_ray(edge_ray).is_empty(),"Rim fixture starts with its center over the opening and its outer edge over real terrain")
	rim_piece.lose_support(game.player)
	for tick in 12:await physics_frame
	check(is_instance_valid(rim_piece) and not rim_piece.freeze,"Partially supported food remains free to tip along the rim")
	if is_instance_valid(rim_piece):game.player.position=Vector3(rim_piece.position.x,0,rim_piece.position.z)
	game.ground.sync()
	var rim_low:=rim_start
	for tick in 180:
		if tick%6==0:game.scan_food()
		await physics_frame
		if is_instance_valid(rim_piece):rim_low=minf(rim_low,rim_piece.position.y)
	check(rim_low<rim_start-1.0,"Removing partial rim support produces a real downward trajectory")
	check(receipts.has(rim_id) and receipts[rim_id].count==1 and receipts[rim_id].top< -3.5,"Thin rim-supported piece is never held across a fully open mouth")
	metrics["pile_receipts"]=pile_receipts
	metrics["target_rain_receipts"]=target_receipts;metrics["rain_rest"]=rain_rest;metrics["pile_rest"]=contact_rest;metrics["landed_rain"]=landed;metrics["settled_batch_count"]=batched;metrics["collection_receipts"]=receipts.size()-ready_receipts
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	game=load("res://fidelity/main.tscn").instantiate();root.add_child(game)
	game.selected_map="food";game.start_level();game.begin_play();game.set_process(false);game.set_physics_process(false);game.city.set_process(false);game.city.rain_enabled=false
	for h in game.holes:h.enabled=false;h.active=false;h.set_physics_process(false)
	game.player.position=Vector3(70,0,36)
	game.item_collected.connect(receipt)
	shape_and_resource_fixture()
	await physics_frame
	await physical_fixture()
	var result:={"checks":checks,"failures":failures,"metrics":metrics,"scope":"Non-author real food creation, resource identity, prism support, contact/drop and collection evidence; no renderer or CPU timing claim."}
	print("FOOD_COLLISION_REVIEW "+JSON.stringify(result))
	game.free();await process_frame;quit(0 if failures.is_empty() else 1)
