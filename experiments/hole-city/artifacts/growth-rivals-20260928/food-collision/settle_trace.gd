extends SceneTree
const KINDS:=["egg","cake","donut","burger","cookie","berry","pancake","pizza"]
var game:Node3D
var rows:Array=[]
func _initialize()->void:run.call_deferred()
func shape_of(body:Node3D)->Shape3D:
	for child in body.get_children():
		if child is CollisionShape3D:return child.shape
	return null
func lowest(body:Node3D)->float:
	var shape:=shape_of(body)
	if shape is CylinderShape3D:
		var radial:float=Vector2(body.global_basis.x.y,body.global_basis.z.y).length()*shape.radius
		return body.position.y-absf(body.global_basis.y.y)*shape.height*.5-radial
	var low:=INF
	for point in shape.points:low=minf(low,(body.global_transform*point).y)
	return low
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	game=load("res://fidelity/main.tscn").instantiate();root.add_child(game)
	game.selected_map="food";game.start_level();game.begin_play()
	game.set_process(false);game.set_physics_process(false);game.city.set_process(false);game.city.rain_enabled=false
	for h in game.holes:h.enabled=false;h.active=false
	# Match the author's exact 16-body tilted-contact fixture and naming order.
	var ordinary:Array[Node3D]=[]
	for i in KINDS.size():
		var body:Node3D=game.city.food(KINDS[i],Vector2(70,-60+i*16),.55,2)
		body.position.y=3.5;body.rotation=Vector3(deg_to_rad([0,3,25,87][i%4]),.13*i,.09)
		body.lose_support(null);ordinary.append(body)
		var rain:Node3D=game.city.spawn_rain(KINDS[i],Vector2(74,-60+i*16),5.0)
		rain.rotation=Vector3(deg_to_rad([2,40,80,15][i%4]),.19*i,.05)
	for tick in 720:
		await physics_frame
		if (tick+1)%30==0:
			for i in ordinary.size():
				var b:Node3D=ordinary[i]
				var angular:Vector3=b.angular_velocity
				var inertia:Basis=b.get_inverse_inertia_tensor().inverse()
				var energy:float=.5*b.mass*b.linear_velocity.length_squared()+.5*angular.dot(inertia*angular)
				rows.append({"seconds":float(tick+1)/60.0,"kind":KINDS[i],"shape":shape_of(b).get_class(),"at":[b.position.x,b.position.y,b.position.z],"lowest":lowest(b),"linear_speed":b.linear_velocity.length(),"angular_speed":angular.length(),"kinetic_energy":energy,"sleeping":b.sleeping})
	var result:={"version":ProjectSettings.get_setting("application/config/version"),"steps":720,"rows":rows,"scope":"12-second controlled contact evolution, not performance measurement. Eight ordinary tilted drops plus eight neighbouring real rain foods; source/PCK use the same helper and initial geometry."}
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("FOOD_SETTLE_TRACE "+JSON.stringify({"steps":720,"shape":rows[0].shape,"samples":rows.size()}))
	game.free();await process_frame;quit()
