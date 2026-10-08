extends SceneTree
## Track paint, real ground cuts, discovery HUD and controller lifetime.
const Routes=preload("res://fidelity/train_routes.gd")
class CapturedUI extends "res://fidelity/ui.gd":
	var captions:Array[String]=[]
	var panels:Array[Rect2]=[]
	func _draw()->void:
		captions.clear();panels.clear();super._draw()
	func text_center(message:String,at:Vector2,font_size:int,tint:=Color.WHITE,outline:=true,target:CanvasItem=null)->void:
		captions.append(message);super.text_center(message,at,font_size,tint,outline,target)
	func box(rect:Rect2,color:Color,radius:=24,border:=Color("ffffff"),stroke:=2,target:CanvasItem=null)->void:
		panels.append(rect);super.box(rect,color,radius,border,stroke,target)
var game:Node3D
var checks:=0
var failures:Array[String]=[]
var metrics:Dictionary={}
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func frames(count:=2)->void:
	for i in count:await physics_frame
func painted(at:Vector2,threshold:=20)->bool:
	var point:=Vector2i(((at+Vector2.ONE*100)*5.12).floor())
	for y in range(maxi(0,point.y-1),mini(1023,point.y+1)+1):
		for x in range(maxi(0,point.x-1),mini(1023,point.x+1)+1):
			if game.train_tracks.pixels[y*1024+x]>threshold:return true
	return false
func ground_at(at:Vector2)->bool:
	var query:=PhysicsRayQueryParameters3D.create(Vector3(at.x,.02,at.y),Vector3(at.x,-.08,at.y),1)
	var hit:=game.get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.rid==game.ground.body.get_rid()
func has_hint()->bool:
	for caption in game.ui.captions:
		if caption.begins_with("SUSHI EXPRESS · ") or caption.begins_with("CITY TRAM · "):return true
	return false
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	game=load("res://fidelity/main.tscn").instantiate();root.add_child(game)
	game.set_process(false);game.set_physics_process(false)
	var layer:Node=game.ui.get_parent();game.ui.free();game.ui=CapturedUI.new();game.ui.game=game;layer.add_child(game.ui)
	var old_controller:WeakRef
	var old_texture:WeakRef
	for map_id in ["city","food","city"]:
		game.selected_map=map_id
		var started:=Time.get_ticks_usec();game.start_level()
		metrics[map_id+"_build_ms"]=(Time.get_ticks_usec()-started)/1000.0
		game.city.set_process(false);game.city.set_physics_process(false)
		if map_id=="food":game.city.rain_enabled=false
		for hole in game.holes:hole.enabled=false;hole.active=false;hole.set_physics_process(false)
		game.ground.sync();await frames()
		if old_controller!=null:
			check(old_controller.get_ref()==null and old_texture.get_ref()==null,"Map switch releases previous controller and track texture")
		check(game.train_controller!=null and game.train_tracks!=null,map_id+": actual level builds its train and markings")
		check(game.train_controller.cars.size()==(8 if map_id=="food" else 4),map_id+": actual scene has the intended independent car count")
		check(game.city.moving_vehicles.size()==8,map_id+": original vehicle fleet remains intact")
		check(game.train_tracks.updates==1,map_id+": one initial texture upload")
		check(game.train_tracks.texture.get_width()==1024 and game.train_tracks.texture.get_height()==1024,map_id+": bounded single-channel track texture")
		check(game.train_tracks.pixels.size()==1024*1024 and game.train_tracks.base.size()==1024*1024,map_id+": two bounded 1 MiB CPU masks")
		check(game.ground.surface.get_shader_parameter("train_marks")==game.train_tracks.texture and game.ground.surface.get_shader_parameter("train_tracks_enabled")==true,map_id+": existing cut-ground shader owns the rail paint")
		check(absf(game.train_controller.route_length-(609.324 if map_id=="food" else 668.315))<.02,map_id+": installed route matches independently cleared road corridor")
		for i in 24:
			var pose:Dictionary=game.train_controller.base_pose(game.train_controller.route_length*float(i)/24.0)
			var forward:Vector2=pose.forward;var side:=Vector2(-forward.y,forward.x)
			check(painted(pose.at) and painted(pose.at+side*.42,100) and painted(pose.at-side*.42,100),map_id+": bed and both rails follow actual route sample %d"%i)
		game.begin_play();game.player.enabled=false;game.player.active=true
		game.ui.queue_redraw();await frames()
		check(has_hint(),map_id+": distant train has a visible distance/direction discovery hint")
		check(game.ui.panels.has(Rect2(135,159,270,40)),map_id+": discovery pill stays below the score card and above notices")
		var at:Vector2=game.train_controller.base_point(40.0)
		check(ground_at(at),map_id+": tracks initially rest on real solid terrain")
		game.player.position=Vector3(at.x,0,at.y);game.player.radius=2.0;game.ground.sync();await frames()
		check(not ground_at(at),map_id+": real hole removes ground under painted rails; no extra collision floor")
		game.player.active=false;game.ground.sync();await frames()
		check(ground_at(at),map_id+": ground closes normally when the mouth leaves")
		var uploads:int=game.train_tracks.updates
		for i in 60:game.train_controller.step(1.0/60.0)
		await frames()
		check(game.train_tracks.updates==uploads,map_id+": normal motion never regenerates or uploads a track texture")
		game.train_controller.detach_from(2);game.train_controller.step(1.0/60.0)
		var branches:Array=game.train_controller.planned_branches()
		check(not branches.is_empty() and game.train_tracks.updates==uploads+1,map_id+": middle cut updates the real planned bypass exactly once")
		for branch in branches:
			for i in range(0,branch.size(),10):check(painted(branch[i]),map_id+": visible branch matches the collision-checked train path")
		uploads=game.train_tracks.updates;game.train_tracks.refresh(branches)
		check(game.train_tracks.updates==uploads,map_id+": unchanged branch signals do not upload again")
		game.train_controller.route_changed.emit([])
		check(game.train_tracks.pixels==game.train_tracks.base,map_id+": clearing a detour restores only the original route paint")
		game.player.active=true;game.player.position=game.train_controller.cars[0].position
		game.ui.queue_redraw();await frames()
		check(not has_hint(),map_id+": nearby train does not obscure play with a redundant pointer")
		old_controller=weakref(game.train_controller);old_texture=weakref(game.train_tracks.texture)
	game.back_home();await process_frame;await process_frame
	check(game.train_controller==null and game.train_tracks==null,"Returning home clears train runtime references immediately")
	check(old_controller.get_ref()==null and old_texture.get_ref()==null,"Title page does not retain the old controller or track mask")
	game.start_level();old_controller=weakref(game.train_controller);old_texture=weakref(game.train_tracks.texture)
	game.free();await process_frame
	check(old_controller.get_ref()==null and old_texture.get_ref()==null,"Game teardown releases the final controller and mask")
	print("TRAIN_SURFACE_ACCEPTANCE "+JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics,"scope":"Real scene/ground/CanvasItem assertions; no browser or mobile FPS claim"}))
	quit(0 if failures.is_empty() else 1)
