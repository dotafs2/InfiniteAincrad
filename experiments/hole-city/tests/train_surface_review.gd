extends SceneTree
## Independent integration boundaries: shared geometry, real mouth cuts,
## actual touch dispatch, branch signals and return-home resource lifetime.
const Layout=preload("res://fidelity/street_layout.gd")
const FoodRoads=preload("res://fidelity/food_neighborhoods.gd")
const Asset=preload("res://fidelity/train_assets.gd")
class ObservedUI extends "res://fidelity/ui.gd":
	var captions:Array[Dictionary]=[]
	var panels:Array[Rect2]=[]
	func _draw()->void:
		captions.clear();panels.clear();super._draw()
	func text_center(message:String,at:Vector2,font_size:int,tint:=Color.WHITE,outline:=true,target:CanvasItem=null)->void:
		captions.append({"text":message,"at":at,"size":font_size});super.text_center(message,at,font_size,tint,outline,target)
	func box(rect:Rect2,color:Color,radius:=24,border:=Color("ffffff"),stroke:=2,target:CanvasItem=null)->void:
		panels.append(rect);super.box(rect,color,radius,border,stroke,target)
var game:Node3D
var checks:=0
var failures:Array[String]=[]
var metrics:Dictionary={}
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func _initialize()->void:run.call_deferred()
func frames(count:=2)->void:
	for i in count:await physics_frame
func mask_peak(at:Vector2)->int:
	var size:int=game.train_tracks.SIZE
	var unit:float=float(size)/(game.ground.HALF*2.0)
	var pixel:Vector2i=Vector2i(((at+Vector2.ONE*game.ground.HALF)*unit).floor())
	var peak:=0
	for dy in range(-1,2):
		for dx in range(-1,2):
			var p:Vector2i=pixel+Vector2i(dx,dy)
			if p.x>=0 and p.x<size and p.y>=0 and p.y<size:peak=maxi(peak,game.train_tracks.pixels[p.y*size+p.x])
	return peak
func actual_floor(at:Vector2)->bool:
	var q:=PhysicsRayQueryParameters3D.create(Vector3(at.x,.02,at.y),Vector3(at.x,-.10,at.y),1)
	var hit:=game.get_world_3d().direct_space_state.intersect_ray(q)
	return not hit.is_empty() and hit.rid==game.ground.body.get_rid()
func caption()->Dictionary:
	for item in game.ui.captions:
		if item.text.begins_with("CITY TRAM · ") or item.text.begins_with("SUSHI EXPRESS · "):return item
	return {}
func touch_pill()->void:
	var e:=InputEventScreenTouch.new();e.index=7;e.position=Vector2(283,179);e.pressed=true
	root.push_input(e,true);await frames()
	check(game.player.touch_index==7,"Train hint allows actual screen touch to begin movement")
	var drag:=InputEventScreenDrag.new();drag.index=7;drag.position=e.position+Vector2(48,17);drag.relative=Vector2(48,17)
	root.push_input(drag,true);await frames()
	check(game.player.joystick.length()>.4,"Dragging through painted hint produces real movement input")
	e.pressed=false;root.push_input(e,true);await frames()
	check(game.player.touch_index==-1 and game.player.joystick==Vector2.ZERO,"Release over hint clears actual movement finger")
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	game=load("res://fidelity/main.tscn").instantiate();root.add_child(game);game.set_process(false);game.set_physics_process(false)
	var layer:Node=game.ui.get_parent();game.ui.free();game.ui=ObservedUI.new();game.ui.game=game;layer.add_child(game.ui)
	var cache_sizes:Array=[]
	for map_id in ["city","food","city","food"]:
		game.selected_map=map_id;game.start_level();game.city.set_process(false);game.city.set_physics_process(false)
		if map_id=="food":game.city.rain_enabled=false
		for h in game.holes:h.enabled=false;h.active=false;h.set_physics_process(false)
		game.ground.sync();await frames()
		var length:=0.0
		for i in game.train_controller.route.size():length+=game.train_controller.route[i].distance_to(game.train_controller.route[(i+1)%game.train_controller.route.size()])
		check(absf(length-game.train_controller.route_length)<.001,"Route distance equals actual closed geometry on "+map_id)
		check(game.ground.visual.material_override==game.ground.surface and game.ground.surface==game.train_tracks.material,"Marks use the exact material on cut-ground visual")
		for k in 80:
			var pose:Dictionary=game.train_controller.base_pose(length*(float(k)+.371)/80.0)
			check(FoodRoads.on_road(pose.at) if map_id=="food" else Layout.on_road(pose.at),"Non-grid route sample stays on authored road")
			check(mask_peak(pose.at)>20,"Actual route center has painted bed at independent phase")
			var normal:=Vector2(-pose.forward.y,pose.forward.x)
			check(mask_peak(pose.at+normal*.42)>100 and mask_peak(pose.at-normal*.42)>100,"Both real rail offsets have bright paint")
		check(mask_peak(Vector2.ZERO)==0,"No unrelated central ground is covered by train marks")
		game.begin_play();game.player.active=true;game.player.enabled=true;game.ui.queue_redraw();await frames()
		var hint:=caption();check(not hint.is_empty(),"Distant train exposes discovery caption")
		if not hint.is_empty():
			var width:float=game.ui.font.get_string_size(hint.text,HORIZONTAL_ALIGNMENT_LEFT,-1,hint.size).x
			var text_rect:=Rect2(hint.at.x-width*.5,hint.at.y-game.ui.font.get_ascent(hint.size),width,game.ui.font.get_height(hint.size))
			check(Rect2(175,159,230,40).encloses(text_rect),"Actual font metrics fit pill without touching direction arrow")
			for b in game.ui.buttons:check(not b.get_rect().intersects(Rect2(135,159,270,40)),"Hint does not overlay an interactive target")
			check(not Rect2(151,94,238,52).intersects(Rect2(135,159,270,40)) and not Rect2(87,253,366,46).intersects(Rect2(135,159,270,40)),"Hint clears score and notice panels")
		await touch_pill()
		var target:Vector2=game.train_controller.base_point(length*.329)
		check(actual_floor(target),"Selected real rail location begins on solid terrain")
		game.player.radius=2.0;game.player.position=Vector3(target.x,0,target.y);game.ground.sync();await frames()
		for offset in [Vector2.ZERO,Vector2(.42,0),Vector2(-.42,0),Vector2(0,.42)]:check(not actual_floor(target+offset),"Rail floor disappears at actual aperture sample")
		check(mask_peak(target)>20,"Texture remains a route mask while geometry supplies the real opening")
		game.player.active=false;game.ground.sync();await frames()
		check(actual_floor(target),"Real floor returns after the player leaves")
		var uploads:int=game.train_tracks.updates
		for step in 8:game.train_controller.step(1.0/60.0);await frames(1)
		check(game.train_tracks.updates==uploads,"Moving transforms do not rerasterize static rail mask")
		game.train_controller.detach_from(2);await frames()
		game.train_controller.step(1.0/60.0);await frames()
		var branches:Array=game.train_controller.planned_branches()
		check(not branches.is_empty(),"Physical middle detachment plans a nonempty bypass")
		for branch in branches:
			for j in range(0,branch.size(),7):check(mask_peak(branch[j])>20,"Signal-updated marks follow real planned bypass sample")
		game.train_tracks.refresh([]);check(game.train_tracks.pixels==game.train_tracks.base,"Empty bypass list restores complete original mask")
		game.player.active=true;game.player.position=game.train_controller.cars[0].position;game.ui.queue_redraw();await frames()
		check(caption().is_empty(),"Nearby train hides unnecessary direction pill")
		cache_sizes.append(Asset.palette_materials.size())
		var controller_ref:WeakRef=weakref(game.train_controller);var marks_ref:WeakRef=weakref(game.train_tracks);var texture_ref:WeakRef=weakref(game.train_tracks.texture)
		game.back_home();check(game.train_controller==null and game.train_tracks==null,"Returning home drops both gameplay-owned resource references")
		await frames()
		check(controller_ref.get_ref()==null and marks_ref.get_ref()==null and texture_ref.get_ref()==null,"Return home actually releases controller, CPU masks and texture")
		game.ui.queue_redraw();await frames();check(caption().is_empty(),"Title redraw never reads freed train actors or shows gameplay hint")
	metrics["palette_cache_sizes_after_city_food_city_food"]=cache_sizes
	check(cache_sizes[2]<=cache_sizes[1] and cache_sizes[3]<=cache_sizes[1],"Repeated maps do not grow static palette cache after first complete asset set")
	# Real touch unlocks Dummy music; retire its audio-thread decoder before quitting.
	game.audio.set_process(false) # Freeze pending route changes before decoder teardown.
	game.audio.music.stop();OS.delay_msec(120);await frames(3)
	game.free();await process_frame
	print("TRAIN_SURFACE_REVIEW "+JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics,"scope":"Independent native scene/actual touch/mask/lifetime evidence, not browser screenshots or phone performance"}))
	quit(0 if failures.is_empty() else 1)
