extends SceneTree
## Independent city district review: rendered route uniforms and real footprints.
var failures:Array[String]=[]
var checks:=0
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func shader_walk_edge(at:Vector2,area:Vector4)->float:
	var d:Vector2=(at-Vector2(area.x,area.y)-Vector2(area.z,area.w)*.5).abs()-Vector2(area.z,area.w)*.5
	return absf(maxf(d.x,d.y))
func painted(game:Node3D,at:Vector2)->bool:
	if game.city.Layout.on_road(at):return false
	for i in 4:
		var area:Vector4=game.ground.surface.get_shader_parameter("city_walk_%d"%i)
		if shader_walk_edge(at,area)<1.05:return true
	return false
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	var game:Node3D=load("res://fidelity/main.tscn").instantiate();root.add_child(game)
	game.start_level();game.begin_play();game.set_process(false);game.set_physics_process(false);game.city.set_process(false)
	for h in game.holes:h.active=false;h.enabled=false
	var city:Node3D=game.city;var layout=city.Layout
	var wrongpaint:=0;var colliding:=0;var crowd_overlaps:=0;var parcels:=0
	for i in 4:
		for step in int(layout.walk_length(i)*2):
			var at:Vector2=layout.walk_sample(step*.5,i)
			for offset in [Vector2.ZERO,Vector2(.5,.5),Vector2(-.5,.5),Vector2(.5,-.5),Vector2(-.5,-.5)]:
				var valid:Vector2=layout.walk_constrain(at+offset,i)
				if not painted(game,valid):wrongpaint+=1
	check(wrongpaint==0,"Movement corridor matches the active material's shader walk-edge equation including corners")
	for entry in city.building_visuals:
		var body:Node3D=entry.body
		# Use the actual visual's transformed mesh bounds from catalog metadata,
		# independent of Districts.parcels() and the placement author's assertions.
		var extent:Vector2=entry.half
		if absf(sin(body.rotation.y))>.5:extent=Vector2(extent.y,extent.x)
		var footprint:=Rect2(Vector2(body.position.x,body.position.z)-extent,extent*2)
		for path in layout.walk_clearance_rects():
			if footprint.intersects(path):parcels+=1
		for corner in [footprint.position,footprint.end,Vector2(footprint.end.x,footprint.position.y),Vector2(footprint.position.x,footprint.end.y)]:
			if layout.on_road(corner):parcels+=1
	check(parcels==0,"Rendered building envelopes clear avenues and painted walking loops")
	for tick in 3600:
		if tick%360==0:game.player.position=city.citizens[(tick/360)*5].body.position+Vector3(1.5,0,0)
		game.elapsed=tick/60.0;city._process(1.0/60.0)
		for i in city.citizens.size():
			var body:Node3D=city.citizens[i].body;var at:=Vector2(body.position.x,body.position.z)
			if not painted(game,at):wrongpaint+=1
			for building in city.building_visuals:
				if city.traffic_bounds(building.body,0).grow(.23).has_point(at):colliding+=1
			for j in range(i+1,city.citizens.size()):
				var other:Node3D=city.citizens[j].body
				if Vector2(other.position.x,other.position.z).distance_to(at)<.46:crowd_overlaps+=1
	check(wrongpaint==0 and colliding==0 and crowd_overlaps==0,"One minute of real circulation/panic stays on painted paths, outside buildings and separate from people")
	# The new walks are part of the cut ground, not a solid decorative overlay.
	var at:Vector2=layout.walk_sample(7.5,0)
	game.player.position=Vector3(at.x,0,at.y);game.player.radius=1.2;game.player.active=true;game.player._sync_shape()
	for i in 4:await physics_frame
	var query:=PhysicsRayQueryParameters3D.create(Vector3(at.x,2,at.y),Vector3(at.x,-.2,at.y),1)
	check(game.get_world_3d().direct_space_state.intersect_ray(query).is_empty(),"A hole removes the actual physics beneath the new painted sidewalk")
	print("FOOD_REVIEW_CITY_DISTRICTS "+JSON.stringify({"checks":checks,"failures":failures,"wrong_paint":wrongpaint,"building_contacts":colliding,"crowd_overlaps":crowd_overlaps,"citizens":city.citizens.size(),"buildings":city.building_visuals.size(),"scope":"Active shader-uniform/equation, actual motion and physics; no rendered screen claim"}))
	game.free();await process_frame;quit(0 if failures.is_empty() else 1)
