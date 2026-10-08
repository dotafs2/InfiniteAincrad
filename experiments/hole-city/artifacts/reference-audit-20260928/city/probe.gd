extends SceneTree
## Read-only behavioral audit. Explicit test mode is required; no player save.
var game:Node3D
func _initialize()->void:run.call_deferred()
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	game=load("res://fidelity/main.tscn").instantiate();root.add_child(game)
	game.start_level();game.begin_play()
	game.set_process(false);game.set_physics_process(false);game.city.set_process(false)
	for hole in game.holes:hole.enabled=false;hole.active=false
	game.player.position=Vector3(70,0,70)
	var city:Node3D=game.city
	var fixtures:Array=[]
	for citizen in city.citizens:
		if citizen.kind in ["police","thief"]:continue
		fixtures.append(citizen.duplicate())
	var heading_runs:Array=[]
	for hz in [60,30]:
		var before:Array=[]
		for i in fixtures.size():
			var c:Dictionary=fixtures[i]
			c.body.position=c.origin;c.body.rotation.y=1.7
			before.append(c.body.position)
		var travelled:=0;var rotated:=0;var sample:={}
		for tick in hz*10:
			game.elapsed=float(tick)/hz
			city._process(1.0/hz)
		for i in fixtures.size():
			var c:Dictionary=fixtures[i]
			var distance:float=c.body.position.distance_to(before[i])
			if distance>.1:
				travelled+=1
				if absf(angle_difference(c.body.rotation.y,1.7))>.001:rotated+=1
				if sample.is_empty():sample={"kind":c.kind,"distance_m":distance,"start_heading":1.7,"final_heading":c.body.rotation.y}
		heading_runs.append({"hz":hz,"travelled_over_0_1m":travelled,"changed_heading":rotated,"sample":sample})
	# Reset citizens to their authored positions and sample whole crowd at 60 Hz.
	for c in city.citizens:c.body.position=c.origin
	var pairs:={};var minimum:=INF;var min_pair:={}
	for tick in 60*20:
		game.elapsed=float(tick)/60.0;city._process(1.0/60.0)
		if tick%6!=0:continue
		for i in city.citizens.size():
			for j in range(i+1,city.citizens.size()):
				var a:Dictionary=city.citizens[i];var b:Dictionary=city.citizens[j]
				var distance:float=Vector2(a.body.position.x-b.body.position.x,a.body.position.z-b.body.position.z).length()
				if distance<.46:
					pairs["%d:%d"%[i,j]]=true
					if distance<minimum:
						minimum=distance;min_pair={"a":i,"b":j,"a_kind":a.kind,"b_kind":b.kind,"time":game.elapsed,"distance_m":distance}
	# Retain native straight-lane controller and detect the edge return discontinuity.
	var max_jump:=0.0;var teleport:={}
	for tick in 60*50:
		var before:Array=[]
		for t in city.moving_vehicles:before.append(t.body.position)
		city.update_traffic(1.0/60.0)
		for i in city.moving_vehicles.size():
			var t:Dictionary=city.moving_vehicles[i]
			var jump:float=t.body.position.distance_to(before[i])
			if jump>max_jump:
				max_jump=jump;teleport={"vehicle":i,"jump_m":jump,"axis":t.axis,"from":str(before[i]),"to":str(t.body.position),"time":float(tick)/60.0}
	var result:={"version":ProjectSettings.get_setting("application/config/version"),"scope":"headless manual controller steps; no visual or GPU evidence","heading":heading_runs,"crowd":{"citizens":city.citizens.size(),"radius_each_m":.23,"overlapping_unique_pairs":pairs.size(),"closest":min_pair},"traffic_wrap":teleport,"city":{"buildings":city.building_visuals.size(),"moving_vehicles":city.moving_vehicles.size(),"sidewalk_regions":city.Layout.SIDEWALKS.size()}}
	print("CITY_REFERENCE_AUDIT "+JSON.stringify(result))
	FileAccess.open("res://artifacts/reference-audit-20260928/city/probe.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	game.free();await process_frame;quit()
