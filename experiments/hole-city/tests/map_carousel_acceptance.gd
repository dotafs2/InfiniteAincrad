extends SceneTree
## Real viewport input, truthful screenshot resources and bounded phone layout.
const Game=preload("res://fidelity/game.gd")
const Progression=preload("res://fidelity/map_progression.gd")
class InsetUI extends "res://fidelity/ui.gd":
	func viewport_safe_rect(viewport:Vector2)->Rect2:
		return ViewportLayout.safe_rect_from_pixels(viewport,Vector2(1320,2868),Rect2(0,186,1320,2580))
var game:Node3D
var checks:=0
var failures:Array[String]=[]
var directory:=""
var observations:Array[Dictionary]=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func frames(count:=4)->void:
	for _i in count:await process_frame
func settle()->void:
	for _i in 80:
		await process_frame
		if not game.ui.map_carousel.busy():break
func target(id:String)->Button:
	for b in game.ui.buttons:
		if b.name==id:return b
	return null
func global_at(at:Vector2)->Vector2:
	return game.ui.get_global_transform_with_canvas()*at
func swipe(delta:float,cancel:=false)->void:
	var carousel=game.ui.map_carousel
	var start:Vector2=carousel.position+carousel.size*.5
	var down:=InputEventScreenTouch.new();down.index=0;down.position=global_at(start);down.pressed=true
	root.push_input(down,true);await frames(1)
	for i in 6:
		var drag:=InputEventScreenDrag.new();drag.index=0;drag.position=global_at(start+Vector2(delta*float(i+1)/6,0))
		root.push_input(drag,true);await frames(1)
	var up:=InputEventScreenTouch.new();up.index=0;up.position=global_at(start+Vector2(delta,0));up.pressed=false;up.canceled=cancel
	root.push_input(up,true);await settle()
func tap(id:String)->void:
	var b:=target(id);check(b!=null,"Exposed touch control: "+id)
	if b==null:return
	var at:=b.get_global_rect().get_center()
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new();event.position=at;event.global_position=at;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
		root.push_input(event,true);await frames(1)
	await settle()
func snap(label:String)->void:
	if directory.is_empty():return
	for _i in 4:await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(directory+"/"+label+".png")==OK,"GPU frame saved: "+label)
	observations.append({"file":label+".png","viewport":str(root.size),"canvas":str(game.ui.size),"focus":game.ui.map_carousel.current_id(),"selected_map":game.selected_map,"status":game.map_unlock_status(game.ui.map_carousel.current_id())})
func layout(label:String)->void:
	var carousel=game.ui.map_carousel
	check(carousel.visible and carousel.clip_contents,label+": the single screenshot row clips neighboring cards")
	check(carousel.definitions.size()==4 and carousel.photos.size()==4,label+": every authored world appears exactly once")
	check(not game.ui.hero.visible and game.ui.hero_view.render_target_update_mode==SubViewport.UPDATE_DISABLED,label+": replaced miniature never renders behind screenshots")
	check(not game.ui.hero_models.is_processing(),label+": hidden miniature never animates")
	check(not is_instance_valid(game.world),label+": browsing does not construct playable maps")
	check(carousel.get_rect().end.y<target("home-play").position.y,label+": cards and main action do not overlap")
	check(carousel.get_rect().position.y>game.ui.responsive_y(190),label+": cards remain below wallet and heading")
	for i in carousel.photos.size():
		var photo:TextureRect=carousel.photos[i]
		check(photo.texture!=null and photo.texture.get_size()==Vector2(880,620),label+": actual screenshot loaded for "+str(carousel.definitions[i].id))
		check(photo.stretch_mode==TextureRect.STRETCH_KEEP_ASPECT_COVERED,label+": screenshot preserves aspect ratio")
		check(photo.material!=null and photo.mouse_filter==Control.MOUSE_FILTER_IGNORE,label+": rounded photo does not steal swipe input")
		check(carousel.card_rect(i).encloses(carousel.photo_rect(i)),label+": image is inside its card")
	for b in game.ui.buttons:
		check(Rect2(Vector2.ZERO,game.ui.size).encloses(b.get_rect()),label+": safe canvas contains "+b.name)
		check(minf(b.size.x,b.size.y)*375.0/540.0>=44,label+": minimum 44pt touch target "+b.name)
	check(target("map-previous").disabled==(carousel.focus_index==0),label+": first boundary disables previous")
	check(target("map-next").disabled==(carousel.focus_index==3),label+": final boundary disables next")
	var expected:bool=game.map_unlocked(carousel.current_id())
	check(target("home-play").disabled==not expected,label+": PLAY follows focused-card entitlement")
	check(target("home-play").text==("PLAY" if expected else "LOCKED"),label+": main action names its real state")
	check(target("all-maps")==null and target("home-food-nav")==null,label+": there is no duplicate chooser or split map row")
	check(game.ui.find_children("*","SubViewport",true,false).size()==3,label+": screenshots add no per-map viewports beyond two legacy previews and one case result")
	check(game.ui.case_opening.result_view.render_target_update_mode==SubViewport.UPDATE_DISABLED and not game.ui.case_opening.result_model.is_processing() and not game.ui.case_opening.visible,label+": Home leaves the case result hidden and dormant")
func run()->void:
	if not OS.get_cmdline_user_args().has("--test") or OS.get_cmdline_user_args().has("--qa-unlocked-worlds"):quit(2);return
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--capture-dir="):directory=a.trim_prefix("--capture-dir=")
	if not directory.is_empty():DirAccess.make_dir_recursive_absolute(directory)
	AudioServer.set_bus_mute(0,true);root.size=Vector2i(540,1174)
	game=Game.new();root.add_child(game);await frames()
	game.music_enabled=false;game.sfx_enabled=false;game.audio.set_music_enabled(false);game.audio.set_sfx_enabled(false)
	layout("fresh tall phone");await snap("fresh-city-tall")
	await swipe(-190)
	check(game.audio.unlocked and not game.audio.music.playing,"Consumed card releases unlock the audio gate without overriding muted music")
	check(game.ui.map_carousel.current_id()=="food" and game.selected_map=="city","Real left swipe previews locked Food without selecting it")
	check(target("home-play").disabled,"A swipe onto a locked world disables PLAY")
	game.ui.play_focused_map();check(not is_instance_valid(game.world),"Locked preview cannot accidentally launch the prior City")
	var enter:=InputEventKey.new();enter.keycode=KEY_ENTER;enter.pressed=true
	root.push_input(enter,true);await frames()
	check(not is_instance_valid(game.world) and game.phase=="title","Keyboard Enter cannot launch the stored City from a locked Food preview")
	enter=enter.duplicate();enter.pressed=false;root.push_input(enter,true);await frames()
	layout("locked food");await snap("locked-food-tall")
	await swipe(-190,true)
	check(game.ui.map_carousel.current_id()=="food","Canceled touch snaps back without changing focus")
	await tap("map-next");check(game.ui.map_carousel.current_id()=="toys","Actual next arrow previews Toy Town")
	await tap("map-next");check(game.ui.map_carousel.current_id()=="frost","Actual next arrow reaches the fourth world")
	await swipe(-700);check(game.ui.map_carousel.current_id()=="frost","Outward swipe clamps at the final map")
	layout("locked final card");await snap("locked-frost-tall")
	game.map_completed_best_scores={"city":1,"food":125,"toys":0,"frost":0}
	game.unlocked_map_ids=Progression.advance(["city"],game.map_completed_best_scores)
	game.ui.pick_map("toys");await settle();game.ui.refresh();await frames()
	check(game.map_unlock_status("toys").current==125 and game.ui.map_carousel.current_id()=="toys","Partial completion score is visible while the map stays locked")
	await snap("toy-progress-tall")
	# This explicit entitled profile tests existing-player browsing, not acquisition.
	game.unlocked_map_ids=game.available_map_ids()
	for id in game.available_map_ids():
		game.ui.pick_map(id);await settle();await frames()
		check(game.ui.map_carousel.current_id()==id and game.selected_map==id,"Focused unlocked map and gameplay selection agree: "+id)
		layout("entitled "+id);await snap("unlocked-"+id+"-tall")
	for viewport in [Vector2i(375,667),Vector2i(440,956)]:
		root.size=viewport;await frames();game.ui.update_viewport_layout();await frames()
		for id in ["city","frost"]:
			game.ui.pick_map(id);await settle();await frames();layout(str(viewport)+" "+id)
			await snap("layout-%d-%s"%[viewport.x,id])
	# Apply real 16 Pro Max safe-area dimensions to the shipped layout helper;
	# this is a desktop inset fixture, not a physical-device capture.
	var layer:Node=game.ui.get_parent()
	game.ui.free();game.ui=InsetUI.new();game.ui.game=game;layer.add_child(game.ui);await frames()
	game.ui.pick_map("frost");await settle();layout("16 Pro Max inset fixture")
	var safe:Rect2=game.ui.viewport_safe_rect(game.ui.get_viewport_rect().size)
	for b in game.ui.buttons:check(safe.grow(.01).encloses(b.get_global_rect()),"Safe-area fixture contains actual target: "+b.name)
	await snap("safe-insets-frost")
	game.ui.pick_map("city")
	game.ui.open_store();await frames()
	check(not game.ui.map_carousel.visible and not game.ui.map_carousel.is_processing(),"Store hides and suspends the carousel")
	game.ui.close_menu();await frames();check(game.ui.map_carousel.visible,"Home restores the row")
	check(not game.ui.map_carousel.busy() and not target("home-play").disabled,"Leaving mid-snap settles hidden cards, so returning Home can play immediately")
	game.ui.pick_map("food");await frames(1)
	check(game.ui.map_carousel.busy() and game.ui.map_carousel.pointer==-2,"Immediate PLAY regression runs while the released card is still easing")
	check(not target("home-play").disabled,"Visual easing does not delay PLAY for the committed world")
	game.ui.map_carousel.pointer_event(0,game.ui.map_carousel.size*.5,true)
	game.ui.play_focused_map()
	check(not is_instance_valid(game.world),"An active finger cannot launch a partly dragged card")
	game.ui.map_carousel.cancel_pointer()
	await tap("home-play");await frames()
	check(game.selected_map=="food" and game.phase=="intro" and is_instance_valid(game.world),"PLAY starts the focused entitled Food world")
	check(not game.ui.map_carousel.visible and game.ui.hero_view.render_target_update_mode==SubViewport.UPDATE_DISABLED,"Game hides both screenshot row and obsolete miniature viewport")
	check(game.ui.case_opening.result_view.render_target_update_mode==SubViewport.UPDATE_DISABLED and not game.ui.case_opening.result_model.is_processing() and not game.ui.case_opening.visible,"World launch also keeps the case result hidden and dormant")
	var report:={"checks":checks,"failures":failures,"observations":observations,"scope":"Real touch/mouse viewport routing, locked browsing, layout and screenshot resources. Entitlements in the existing-player section are explicit test fixtures; acquisition is checked separately."}
	print("MAP_CAROUSEL_ACCEPTANCE "+JSON.stringify(report))
	if not directory.is_empty():FileAccess.open(directory+"/report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	game.free();await process_frame;quit(0 if failures.is_empty() else 1)
