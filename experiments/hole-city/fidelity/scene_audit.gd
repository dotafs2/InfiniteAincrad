extends RefCounted
## Read-only scene audit. Run on a fresh scene before decorative animation.
## Geometry, physics ownership and gameplay registration are checked separately.

static func visible_bounds(body:Node3D)->AABB:
	var bounds:=AABB()
	var first:=true
	for node in body.find_children("*","MeshInstance3D",true,false):
		if node.mesh==null or not node.visible:continue
		var local:Transform3D=body.global_transform.affine_inverse()*node.global_transform
		var part:AABB=local*node.get_aabb()
		bounds=part if first else bounds.merge(part)
		first=false
	return bounds

static func authored_bounds(entry:Dictionary,object_id:String)->AABB:
	var bounds:=AABB()
	var first:=true
	for part in entry.parts:
		if part.get("object_id","frame")!=object_id:continue
		var size:=Vector3(part.size[0],part.size[1],part.size[2])
		var rotation:=Vector3(part.rotation[0],part.rotation[1],part.rotation[2])*PI/180.0
		var at:=Vector3(part.position[0],part.position[1],part.position[2])
		var part_box:=Transform3D(Basis.from_euler(rotation),at)*AABB(-size*.5,size)
		bounds=part_box if first else bounds.merge(part_box)
		first=false
	return bounds

static func inspect_recipe(actor:Dictionary,registry:Array)->Array[Dictionary]:
	var issues:Array[Dictionary]=[]
	var entry:Dictionary=actor.definition
	var owners:Dictionary={}
	for object in entry.objects:
		var id:String=entry.id+"/"+object.id
		var body:Node3D=actor.bodies.get(object.id)
		if not is_instance_valid(body):
			issues.append({"id":id,"code":"missing_physics_owner"});continue
		var key:int=body.get_instance_id()
		if owners.has(key):issues.append({"id":id,"code":"shared_physics_owner","other":owners[key]})
		owners[key]=id
		if body not in registry:issues.append({"id":id,"code":"missing_swallow_registration"})
		var visual:=visible_bounds(body)
		var expected:=authored_bounds(entry,object.id)
		# Rotated round primitives lie inside their authoring box; oversized
		# actual meshes (diameter interpreted as radius) violate that envelope.
		var excess:Vector3=visual.size-expected.size*1.04
		if maxf(excess.x,maxf(excess.y,excess.z))>.04:
			issues.append({"id":id,"code":"geometry_exceeds_authored_size","actual":str(visual.size),"expected":str(expected.size)})
		var collider_bounds:=AABB(-body.half_size,body.half_size*2)
		if not collider_bounds.grow(.025).encloses(visual):issues.append({"id":id,"code":"visual_outside_collider"})
		if (collider_bounds.size-visual.size).length()>.18:issues.append({"id":id,"code":"oversized_collision_box"})
		var measured_footprint:=Vector2(collider_bounds.size.x,collider_bounds.size.z).length()*.5
		if absf(body.footprint-measured_footprint)>.025:issues.append({"id":id,"code":"footprint_differs_from_collision"})
	return issues

static func inspect(city:Node3D)->Dictionary:
	var issues:Array[Dictionary]=[]
	var counts:Dictionary={}
	var registered:Dictionary={}
	for body in city.foods:
		if not is_instance_valid(body):continue
		var id:String=str(body.name)
		var key:int=body.get_instance_id()
		if registered.has(key):issues.append({"id":id,"code":"duplicate_registry_entry"})
		registered[key]=true
		counts[body.category]=int(counts.get(body.category,0))+1
		if not body.position.is_finite() or body.footprint<=0:issues.append({"id":id,"code":"invalid_physics_extent"})
		if body.find_children("*","CollisionShape3D",true,false).is_empty():issues.append({"id":id,"code":"missing_collider"})
		if is_instance_valid(body.support_parent):
			var support:Node3D=body.support_parent
			var children:Array=support.get("contents") if "contents" in support else support.get("supported_food") if "supported_food" in support else []
			if body not in children:issues.append({"id":id,"code":"unreleased_support_owner"})
	var objects:=0
	if "recipe_actors" in city:
		for actor in city.recipe_actors:
			objects+=actor.bodies.size()
			issues.append_array(inspect_recipe(actor,city.foods))
	return {"registered_bodies":registered.size(),"recipe_objects":objects,"categories":counts,"issues":issues}

static func inspect_clearance(city:Node3D)->Array[Dictionary]:
	var issues:Array[Dictionary]=[]
	# Query the physics server, not the placement algorithm's own rectangles.
	for actor in city.recipe_actors:
		for object_id in actor.bodies:
			var body:RigidBody3D=actor.bodies[object_id]
			if is_instance_valid(body.support_parent):continue
			for shape in body.find_children("*","CollisionShape3D",true,false):
				var query:=PhysicsShapeQueryParameters3D.new()
				query.shape=shape.shape
				query.transform=shape.global_transform
				query.collision_mask=1
				query.exclude=[body.get_rid()]
				for hit in body.get_world_3d().direct_space_state.intersect_shape(query):
					if hit.collider is RigidBody3D:
						issues.append({"id":actor.definition.id+"/"+object_id,"code":"spawn_interpenetration","blocker":str(hit.collider.name),"position":str(body.position)})
	return issues
