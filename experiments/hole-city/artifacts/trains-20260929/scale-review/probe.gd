extends SceneTree
var game:Node3D
var evidence:Dictionary={}
func _initialize()->void:run.call_deferred()
func vec(v:Vector3)->Array:return [v.x,v.y,v.z]
func inspect()->Dictionary:
	var nonunit:Array=[];var largest:=0.0;var total:=0;var train_count:=0;var map_basis:Basis=game.city.transform.basis
	for body in game.city.foods:
		if not is_instance_valid(body):continue
		total+=1
		if body.has_meta("train_car"):train_count+=1
		var scale:Vector3=body.scale;var basis:Basis=body.transform.basis
		var lengths:=Vector3(basis.x.length(),basis.y.length(),basis.z.length())
		var error:Vector3=(scale-Vector3.ONE).abs();largest=maxf(largest,maxf(error.x,maxf(error.y,error.z)))
		if scale!=Vector3.ONE:
			nonunit.append({"name":str(body.name),"train":body.get_meta("train_car",false),"asset":body.get_meta("train_asset",""),"scale":vec(scale),"scale_error":vec(error),"basis_column_lengths":vec(lengths),"basis_columns":[vec(basis.x),vec(basis.y),vec(basis.z)],"basis_pair_dots":[basis.x.dot(basis.y),basis.x.dot(basis.z),basis.y.dot(basis.z)],"determinant":basis.determinant(),"position":vec(body.position),"half_size":vec(body.half_size),"frozen":body.freeze,"approx_unit_1e6":maxf(error.x,maxf(error.y,error.z))<=.000001})
	return {"total_bodies":total,"train_bodies":train_count,"nonunit_count":nonunit.size(),"largest_scale_component_error":largest,"nonunit":nonunit,"map_scale":vec(game.city.scale),"map_basis_columns":[vec(map_basis.x),vec(map_basis.y),vec(map_basis.z)]}
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	game=load("res://fidelity/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false)
	for map_id in ["city","food"]:
		game.selected_map=map_id;game.start_level()
		evidence[map_id+"_immediately_after_start"]=inspect()
		game.begin_play();game.city.set_process(false)
		if map_id=="food":game.city.rain_enabled=false
		for h in game.holes:h.enabled=false;h.active=false;h.set_physics_process(false)
		game.ground.sync()
		for i in 2:await physics_frame
		evidence[map_id+"_same_as_failed_fixture_before_step"]=inspect()
		evidence[map_id+"_train_traveled"]=game.train_controller.traveled
	game.free();await process_frame
	print("TRAIN_SCALE_DIAGNOSTIC "+JSON.stringify(evidence));quit()
