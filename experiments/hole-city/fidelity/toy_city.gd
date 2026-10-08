extends "res://fidelity/catalog_city.gd"
## A procedural vinyl castle city with independent, physically supported toys.
const Neighborhoods=preload("res://fidelity/toy_neighborhoods.gd")
const Shapes=preload("res://fidelity/toy_shapes.gd")
const Growth=preload("res://fidelity/hole.gd")
const Query=preload("res://fidelity/food_query.gd")
const Batch=preload("res://fidelity/static_batch.gd")
const Court=preload("res://fidelity/toy_court.gd")
const Garden=preload("res://fidelity/royal_garden.gd")
const Routes=preload("res://fidelity/toy_actor_routes.gd")
const MAX_BODIES:=900
const SUPPORT_GAP:=.025

class ToyBody:
	extends "res://fidelity/rim_body.gd"
	var supported_toys:Array[Node3D]=[]
	var release_delay:=0.0
	var release_hole:Node3D
	var support_released:=false
	var vinyl_material:ShaderMaterial
	# Whole toys retain their original mesh throughout a fall; no shell cells.
	var fractured:=false

	func clear_reveal()->void:
		if vinyl_material!=null:vinyl_material.set_shader_parameter("reveal_occluder",0.0)

	func begin_pull(hole:Node3D)->bool:
		if not super.begin_pull(hole):return false
		collision_layer=2;collision_mask=3
		clear_reveal();schedule_support_release(hole)
		return true

	func begin_swallow(hole:Node3D)->bool:
		if not super.begin_swallow(hole):return false
		collision_layer=2;collision_mask=3
		clear_reveal();schedule_support_release(hole)
		return true

	func schedule_support_release(hole:Node3D)->void:
		if support_released or supported_toys.is_empty():return
		release_hole=hole
		release_delay=.075
		set_physics_process(true)

	func lose_support(hole:Node3D)->void:
		if consumed:return
		support_parent=null
		notify_moving();clear_reveal()
		freeze=false;sleeping=false;lock_rotation=false
		collision_layer=2;collision_mask=3;gravity_scale=1.0
		set_physics_process(true)
		# An oversized upper tier can tumble onto solid ground. Losing support
		# is not admission and cannot assign credit or increase the hole's size.
		if is_instance_valid(hole) and can_fit(hole):
			var at:Vector3=interaction_position()
			if Vector2(at.x-hole.position.x,at.z-hole.position.z).length()<hole.radius*.9:begin_swallow(hole)
		schedule_support_release(hole)

	func release_supported()->void:
		if support_released:return
		support_released=true;release_delay=0.0
		for child in supported_toys:
			if is_instance_valid(child) and not child.consumed:child.lose_support(release_hole)
		supported_toys.clear()

	func _physics_process(delta:float)->void:
		if release_delay>0.0:
			release_delay=maxf(0.0,release_delay-delta)
			if release_delay<=0.0:release_supported()
		super._physics_process(delta)

	func finish_swallow()->void:
		if consumed or not is_instance_valid(claimed_by):return
		release_hole=claimed_by
		release_supported()
		clear_reveal()
		super.finish_swallow()

var site_prop_count:=0
var site_prop_receipts:Array[Dictionary]=[]
var toy_plan:Array[Dictionary]=[]
var toy_counts:Dictionary={}
var tier_counts:Dictionary={}
var neighborhood_counts:Dictionary={}
var collection_receipts:Array[Dictionary]=[]
var shape_cache:Dictionary={}
var geometry_cache:Dictionary={}
var toy_towers:Dictionary={}
var total_points:=0
var largest_height:=0.0
var largest_required_radius:=0.0
var toy_layout:Dictionary={}
var support_height_cache:Dictionary={}
var court:Node3D

func _process(_delta:float)->void:
	# All toys are static until actual admission/support release. No inherited
	# city citizens, traffic, model loading, or decorative physics work runs.
	pass

func world_actor_count()->int:return int(court.population_summary().world_actors) if is_instance_valid(court) else 0
func authored_actor_type_count()->int:return int(court.population_summary().distinct_recipes) if is_instance_valid(court) else 0

func _unit_geometry(kind:String,mesh:ArrayMesh)->Dictionary:
	if geometry_cache.has(kind):return geometry_cache[kind]
	var points:=PackedVector3Array()
	for surface in mesh.get_surface_count():
		var arrays:=mesh.surface_get_arrays(surface)
		var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
		points.append_array(vertices)
	# ConvexShape owns a compact point cloud instead of retaining every indexed
	# surface triangle on every physics owner.
	var compact:ConvexPolygonShape3D=mesh.create_convex_shape(true,true)
	var result:={"vertices":points,"hull":compact.points,"aabb":mesh.get_aabb()}
	geometry_cache[kind]=result
	return result

func _body_mesh(kind:String,palette:int)->ArrayMesh:
	return Shapes.mesh_for(kind,palette)

func _body_collision_parts(kind:String)->Array[PackedVector3Array]:
	return Shapes.collision_parts_for(kind)

func _physics_shapes(kind:String,size:Vector3,geometry:Dictionary,parts_override:Array[PackedVector3Array]=[])->Array[ConvexPolygonShape3D]:
	var key:="%s:%.5f:%.5f:%.5f"%[kind,size.x,size.y,size.z]
	if shape_cache.has(key):return shape_cache[key]
	var parts:Array[PackedVector3Array]=parts_override if not parts_override.is_empty() else _body_collision_parts(kind)
	if parts.is_empty():parts.append(geometry.hull)
	var result:Array[ConvexPolygonShape3D]=[]
	for points in parts:
		if points.size()<4:continue
		var scaled:=PackedVector3Array()
		for point in points:scaled.append(Vector3(point.x*size.x,(point.y-.5)*size.y,point.z*size.z))
		var shape:=ConvexPolygonShape3D.new()
		shape.points=scaled
		result.append(shape)
	shape_cache[key]=result
	return result

func _make_toy(spec:Dictionary,mesh_override:ArrayMesh=null,parts_override:Array[PackedVector3Array]=[])->ToyBody:
	var kind:String=spec.kind
	var size:Vector3=spec.size
	var mesh:ArrayMesh=mesh_override if mesh_override!=null else _body_mesh(kind,int(spec.palette))
	var geometry:Dictionary=_unit_geometry(kind,mesh)
	var unit_bounds:AABB=geometry.aabb
	var measured:=unit_bounds.size*size
	var center:Vector3=(unit_bounds.position+unit_bounds.size*.5)*size
	var radius:=0.0
	var rim:=PackedVector3Array()
	for point in geometry.vertices:
		var local:Vector3=point*size-center
		radius=maxf(radius,Vector2(local.x,local.z).length())
	for point in geometry.hull:
		var local:Vector3=point*size-center
		if local.y<=-measured.y*.5+.045:rim.append(local)
	var body:=ToyBody.new()
	serial+=1;body.name="Toy_%03d_%s"%[serial,kind]
	body.game=game;body.height=measured.y;body.half_size=measured*.5
	body.footprint=radius;body.points=int(spec.points)
	var is_court:bool=bool(spec.get("court_actor",false))
	var whole_castle:bool=not is_court and spec.tower_id=="" and kind in ["toy_castle","grand_castle","block_tower"]
	body.category="building" if whole_castle else "toy_tower" if spec.tower_id!="" else kind
	body.mass=clampf(measured.x*measured.y*measured.z*.16,.25,72.0)
	body.rim_samples=rim
	if spec.tower_id=="" and not bool(spec.get("airborne",false)):
		body.has_support_anchor=true;body.support_anchor=Vector3(0,-measured.y*.5,0)
	body.set_meta("asset_id","toy_%s_%d"%[kind,int(spec.palette)])
	body.set_meta("toy_kind",kind);body.set_meta("toy_tier",int(spec.tier))
	body.set_meta("neighborhood",str(spec.neighborhood));body.set_meta("toy_palette",int(spec.palette))
	body.set_meta("tower_id",str(spec.tower_id));body.set_meta("tower_level",int(spec.tower_level))
	body.set_meta("required_radius",radius*1.08);body.set_meta("minimum_level",Growth.level_for_radius(radius*1.08))
	body.set_meta("landmark",bool(spec.landmark));body.set_meta("measured_extent",measured)
	if is_court:body.set_meta("court_actor",true);body.set_meta("scripted_actor",true)
	var collision_shapes:Array[ConvexPolygonShape3D]=_physics_shapes(kind,size,geometry,parts_override)
	for i in collision_shapes.size():
		var collider:=CollisionShape3D.new();collider.name="ToyCollision_%02d"%i
		collider.shape=collision_shapes[i];body.add_child(collider)
	body.set_meta("compound_collision",collision_shapes.size()>1)
	body.set_meta("collision_parts",collision_shapes.size())
	var visual:=MeshInstance3D.new();visual.name="ToyVisual";visual.mesh=mesh
	visual.scale=size;visual.position=-center
	var mat:ShaderMaterial=Shapes.material()
	if whole_castle:
		mat=Shapes.building_material()
		body.vinyl_material=mat
		body.set_meta("dither_building",true)
		building_visuals.append({"body":body,"mat":mat,"half":Vector2(measured.x,measured.z)*.5,"style":int(spec.palette)})
	visual.material_override=mat;body.add_child(visual)
	body.position=Vector3(spec.at.x,float(spec.bottom)+measured.y*.5,spec.at.y)
	body.rotation.y=float(spec.yaw)
	add_child(body);foods.append(body)
	if is_court:body.collision_layer=0;body.collision_mask=0
	used_assets[body.get_meta("asset_id")]=true
	if not is_court:
		toy_counts[kind]=int(toy_counts.get(kind,0))+1
		tier_counts[int(spec.tier)]=int(tier_counts.get(int(spec.tier),0))+1
		neighborhood_counts[str(spec.neighborhood)]=int(neighborhood_counts.get(str(spec.neighborhood),0))+1
	total_points+=body.points;largest_height=maxf(largest_height,float(spec.bottom)+measured.y)
	largest_required_radius=maxf(largest_required_radius,radius*1.08)
	return body

func spawn_court_body(spec:Dictionary,mesh_override:ArrayMesh=null,parts_override:Array[PackedVector3Array]=[])->ToyBody:
	spec["court_actor"]=true
	return _make_toy(spec,mesh_override,parts_override)

func bind_toy_support(parent:ToyBody,child:ToyBody)->void:
	var support_y:float=parent.position.y+_central_support_top(parent)
	child.position.y=support_y-_collider_bottom(child)+SUPPORT_GAP
	child.spawn_position=child.global_position;child.set_meta("support_surface_y",support_y)
	child.support_parent=parent;parent.supported_toys.append(child)

func static_foods()->Array[Node3D]:
	var result:Array[Node3D]=[]
	for body in foods:
		if is_instance_valid(body) and not body.get_meta("court_actor",false):result.append(body)
	return result

func _collider_bottom(body:ToyBody)->float:
	return _central_collision_surface(body,false)

func _central_support_top(body:ToyBody)->float:
	return _central_collision_surface(body,true)

func _central_collision_surface(body:ToyBody,upper:bool)->float:
	# A visual summit can be decorative or outside an upper body's feet. Ray
	# the actual convex faces under the shared central footprint instead.
	var key:="upper/" if upper else "lower/"
	for child in body.get_children():
		if child is CollisionShape3D:key+="%d/"%child.shape.get_instance_id()
	if support_height_cache.has(key):return float(support_height_cache[key])
	var result:float=-INF if upper else INF
	for child in body.get_children():
		if not child is CollisionShape3D or not child.shape is ConvexPolygonShape3D:continue
		var faces:PackedVector3Array=child.shape.get_debug_mesh().get_faces()
		for index in range(0,faces.size(),3):
			var a:Vector3=child.transform*faces[index]
			var b:Vector3=child.transform*faces[index+1]
			var c:Vector3=child.transform*faces[index+2]
			var ab:=Vector2(b.x-a.x,b.z-a.z);var ac:=Vector2(c.x-a.x,c.z-a.z)
			var denominator:=ab.cross(ac)
			if absf(denominator)<.0000001:continue
			var to_center:=Vector2(-a.x,-a.z)
			var u:=to_center.cross(ac)/denominator
			var v:=ab.cross(to_center)/denominator
			if u<-.00001 or v<-.00001 or u+v>1.00001:continue
			var at:float=a.y+u*(b.y-a.y)+v*(c.y-a.y)
			result=maxf(result,at) if upper else minf(result,at)
	assert(is_finite(result),"Toy tower has no real collision surface under its shared central footprint")
	support_height_cache[key]=result
	return result

func _build_site_props()->void:
	# Crown garden groups frame the entrances. Candidates are measured against
	# the actual built architecture and court, not assumed empty paved circles.
	for center_x in [-22.0,22.0]:
		for offset in [Vector2(-7,11.3),Vector2(7,11.3),Vector2(-11.7,7),Vector2(11.7,7),Vector2(-11.7,2),Vector2(11.7,2),Vector2(-7,-11),Vector2(7,-11)]:
			var kind:String="royal_topiary" if absf(offset.x)>10.0 else "royal_flowerbed"
			var size:=Vector3(1.9,3.1,1.9) if kind=="royal_topiary" else Vector3(3.2,1.1,1.8)
			var at:Vector2=Vector2(center_x,-64.0)+offset
			var mesh:ArrayMesh=Garden.mesh_for(kind)
			var geometry:Dictionary=_unit_geometry(kind,mesh)
			var bounds:=Neighborhoods.bounds_for(at,size*geometry.aabb.size,0.0)
			if not Neighborhoods.clear_of_roads(bounds.grow(.08)):continue
			var occupied:=false
			for other in foods:
				var other_bounds:=Neighborhoods.bounds_for(Vector2(other.position.x,other.position.z),other.half_size*2,other.rotation.y)
				if bounds.grow(.22).intersects(other_bounds,true):occupied=true;break
			if occupied:continue
			var radius:=Vector2(size.x,size.z).length()*.5
			for route in Routes.PATHS.size():
				if sqrt(float(Routes.closest(at,route).distance))<=Routes.HALF_WIDTH+radius:occupied=true;break
			if occupied:continue
			var spec:={"kind":kind,"at":at,"size":size,"tier":3,"points":4,"palette":0,"neighborhood":"crown_heights","yaw":0.0,"tower_id":"","tower_level":0,"bottom":.04,"landmark":false}
			var parts:Array[PackedVector3Array]=[geometry.vertices]
			var body:=_make_toy(spec,mesh,parts)
			body.set_meta("royal_garden",true)
			site_prop_count+=1
			site_prop_receipts.append({"body":str(body.name),"kind":kind,"position":body.position,"points":body.points,"required_radius":body.footprint*1.08})
	assert(site_prop_count>=8,"Royal entrances need actual edible garden groups with clear routes")

func build(owner_game:Node)->void:
	game=owner_game;rng.seed=20261003
	toy_plan=Neighborhoods.plan();toy_layout=Neighborhoods.metadata()
	assert(toy_plan.size()<=MAX_BODIES,"Toy map exceeded its authored physics budget")
	for spec in toy_plan:
		var body:=_make_toy(spec)
		var tower_id:String=spec.tower_id
		if tower_id=="":continue
		if not toy_towers.has(tower_id):toy_towers[tower_id]=[]
		var members:Array=toy_towers[tower_id]
		if not members.is_empty():
			var parent:ToyBody=members.back()
			bind_toy_support(parent,body)
		members.append(body)
	court=Court.new();court.name="RoyalToyCourt";add_child(court);court.build(self,game)
	_build_site_props()
	assert(foods.size()<=MAX_BODIES,"Toy map and royal court exceeded their shared physics budget")
	largest_height=0.0
	for body in foods:largest_height=maxf(largest_height,body.position.y+body.height*.5)
	food_queries=Query.new()
	for body in foods:food_queries.register(body)
	indexed_count=foods.size()
	static_batch_stats=Batch.build(self)
	# Keep the same cuttable world slab. This low pedestal is visual only and
	# remains below the whole-body collection plane.
	box(self,Vector3(0,-5.3,0),Vector3(204,3.0,204),Color("748a9e"))
	box(self,Vector3(0,-7.0,0),Vector3(300,.2,300),Color("b8d9e5"))
	if game.has_signal("item_collected") and not game.item_collected.is_connected(record_collection):game.item_collected.connect(record_collection)
	toy_layout["late_targets"]=[]
	for body in foods:
		if body.get_meta("landmark",false):toy_layout.late_targets.append({"name":body.name,"at":Vector2(body.position.x,body.position.z),"tier":body.get_meta("toy_tier"),"required_radius":body.footprint*1.08,"height":body.height,"points":body.points,"tower_id":body.get_meta("tower_id")})

func record_collection(item:Node3D,hole:Node3D)->void:
	if not item.has_meta("toy_kind"):return
	collection_receipts.append({"elapsed":float(game.elapsed),"name":item.name,"toy_kind":item.get_meta("toy_kind"),"tier":item.get_meta("toy_tier"),"neighborhood":item.get_meta("neighborhood"),"tower_id":item.get_meta("tower_id"),"tower_level":item.get_meta("tower_level"),"points":item.points,"height":item.height,"footprint":item.footprint,"at":item.global_position,"player":hole==game.player,"score":hole.score,"whole_body":true})

func layout_metadata()->Dictionary:return toy_layout.duplicate(true)

func population_summary()->Dictionary:
	var collisions:=0
	for body in foods:
		if is_instance_valid(body):collisions+=int(body.get_meta("collision_parts",0))
	var actor_meshes:=0
	for kind in geometry_cache:
		if not kind in Shapes.KINDS and not kind in Garden.KINDS:actor_meshes+=1
	return {"map_id":"toys","name":"Bubble Toy Town","bodies":foods.size(),"static_bodies":toy_plan.size()+site_prop_count,"site_props":site_prop_count,"site_prop_receipts":site_prop_receipts.duplicate(true),"kind_counts":toy_counts.duplicate(),"tier_counts":tier_counts.duplicate(),"neighborhood_counts":neighborhood_counts.duplicate(),"whole_castles":building_visuals.size(),"physical_towers":toy_towers.size(),"collision_parts":collisions,"total_points":total_points,"largest_height":largest_height,"largest_required_radius":largest_required_radius,"mesh_cache_entries":geometry_cache.size()-actor_meshes,"actor_mesh_cache_entries":actor_meshes,"shape_cache_entries":shape_cache.size(),"static_batches":static_batch_stats.duplicate(),"legacy_models_loaded":models.size(),"court":court.population_summary() if is_instance_valid(court) else {}}
