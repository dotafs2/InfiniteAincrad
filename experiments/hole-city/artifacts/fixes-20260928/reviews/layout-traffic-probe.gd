extends SceneTree
func _initialize()->void:run.call_deferred()
func run()->void:
	var game=load("res://fidelity/main.tscn").instantiate();root.add_child(game)
	var bad_text:=[];var max_name:=0.0;var max_lines:=0
	for d in game.SKIN_DEFS:
		var width:float=game.ui.font.get_string_size(d.name,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x
		max_name=maxf(max_name,width)
		if width>148:bad_text.append(d.id+": title exceeds card margin")
		var lines:=1;var line:=""
		for word in str(d.skill_desc).split(" "):
			var candidate:String=word if line.is_empty() else line+" "+word
			if not line.is_empty() and game.ui.font.get_string_size(candidate,HORIZONTAL_ALIGNMENT_LEFT,-1,17).x>468:lines+=1;line=word
			else:line=candidate
		max_lines=maxi(max_lines,lines)
		if 698+(lines-1)*22+game.ui.font.get_descent(17)>740:bad_text.append(d.id+": description clips panel")
	game.start_level();game.begin_play();game.set_process(false);game.set_physics_process(false);game.city.set_process(false)
	var offroad_corners:=0;var worst_ids:={};var seam_error:=0.0
	for i in game.city.moving_vehicles.size():
		var t:Dictionary=game.city.moving_vehicles[i]
		var length:float=game.city.Layout.traffic_length(t.route)
		var seam_a:Dictionary=game.city.Layout.traffic_sample(length-.0001,t.route)
		var seam_b:Dictionary=game.city.Layout.traffic_sample(.0001,t.route)
		seam_error=maxf(seam_error,seam_a.at.distance_to(seam_b.at))
		for sample in 1000:
			var pose:Dictionary=game.city.Layout.traffic_sample(length*sample/1000.0,t.route)
			var f:Vector2=pose.forward;var r:=Vector2(f.y,-f.x)
			for sx in [-1,1]:
				for sz in [-1,1]:
					var corner:Vector2=pose.at+r*t.body.half_size.x*sx+f*t.body.half_size.z*sz
					if not game.city.Layout.on_road(corner):offroad_corners+=1;worst_ids[str(t.body.get_meta("asset_id"))]=true
	print("INDEPENDENT_LAYOUT_TRAFFIC ",JSON.stringify({"bad_text":bad_text,"widest_title_px":max_name,"max_detail_lines":max_lines,"offroad_corner_samples":offroad_corners,"offroad_assets":worst_ids.keys(),"route_seam_error_m":seam_error}))
	game.free();quit(0 if bad_text.is_empty() and offroad_corners==0 and seam_error<.00021 else 1)
