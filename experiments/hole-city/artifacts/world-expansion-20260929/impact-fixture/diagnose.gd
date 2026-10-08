extends SceneTree
func _initialize()->void:run.call_deferred()
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	var game:Node3D=load("res://fidelity/main.tscn").instantiate();root.add_child(game);game.selected_map="food";game.start_level();game.begin_play();game.set_physics_process(false);game.city.set_process(false);game.city.rain_enabled=false
	for hole in game.holes:hole.active=false;hole.enabled=false
	game.player.position=Vector3(71,0,36);game.ground.sync()
	for i in 2:await physics_frame
	var surfaces:Array=[]
	for i in 3:
		var at:=Vector2(71,42+i*6)
		var query:=PhysicsRayQueryParameters3D.create(Vector3(at.x,8,at.y),Vector3(at.x,-.05,at.y),3)
		var hit:=game.get_world_3d().direct_space_state.intersect_ray(query)
		var collider:Node3D=hit.get("collider")
		surfaces.append({"spawn":[at.x,8,at.y],"hit":str(hit.get("position")),"is_ground":collider==game.ground.body,"collider":str(collider.name),"kind":collider.get_meta("food_kind","")})
		var body:Node3D=game.city.spawn_rain(["cookie","egg","cake"][i],at,8)
		if i==2:body.set_meta("tower_id",0)
	for i in 305:await physics_frame
	var events:Array=[]
	for e in game.city.food_impact_events:events.append({"kind":e.kind,"style":e.style,"at":[e.at.x,e.at.y,e.at.z]})
	var report:={"checks":1,"failures":[],"surfaces":surfaces,"events":events}
	game.free();await process_frame;print("IMPACT_FIXTURE_DIAGNOSIS "+JSON.stringify(report));quit(0)
