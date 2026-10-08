extends SceneTree
## Real menu process frames; no player saves, browser capture or GPU timing.
const Game=preload("res://fidelity/game.gd")
const FoodPreview=preload("res://fidelity/food_preview.gd")
var game:Node3D
var checks:=0
var failures:Array[String]=[]
var observations:Array[Dictionary]=[]

func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func frames(count:=4)->void:
	for i in count:await process_frame
func ambient()->float:
	for child in game.ui.hero_view.get_children():
		if child is WorldEnvironment:return child.environment.ambient_light_energy
	return -1.0
func motion(active:bool,label:String)->void:
	var miniature:Node3D=game.ui.hero_models
	var angle:float=miniature.preview.rotation.y
	var clock_before:float=game.ui.animation
	await frames(18)
	var elapsed:float=game.ui.animation-clock_before
	var turn:float=angle_difference(angle,miniature.preview.rotation.y)
	check(miniature.is_processing()==active,label+": process state follows home visibility")
	check(game.ui.hero.visible==active,label+": texture visibility follows home state")
	check(game.ui.hero_view.render_target_update_mode==(SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED),label+": hidden viewport stops rendering")
	check(game.ui.case_opening.result_view.render_target_update_mode==SubViewport.UPDATE_DISABLED and not game.ui.case_opening.result_model.is_processing() and not game.ui.case_opening.visible,label+": case result remains hidden and dormant outside its own view")
	check(absf(turn-elapsed*.10)<.0001 if active else absf(turn)<.000001,label+": actual process frames rotate at the shared speed, or remain still when hidden")
	if active:check(turn>.015,label+": miniature visibly advances without manual process calls")
	observations.append({"case":label,"active":active,"elapsed":elapsed,"angle_change":turn})
func home_isolation(label:String)->void:
	check(not is_instance_valid(game.world) and game.holes.is_empty(),label+": preview never starts a playable world")
	check(game.coins==50 and game.gems==10 and game.stage==1 and game.food_collected.is_empty(),label+": home animation cannot generate rewards or food receipts")
	check(game.ui.hero_models.find_children("*","CollisionObject3D",true,false).is_empty(),label+": no miniature physics bodies")
	check(game.ui.hero_view.get_children().filter(func(child):return child.name=="MapMiniature").size()==1,label+": exactly one live miniature")
	check(game.ui.hero_view.msaa_3d==Viewport.MSAA_2X and game.ui.hero_view.size==Vector2i(640,560),label+": existing anti-aliasing and bounded render target remain")

func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	# Exercise a saved-food-style cold start without reading a real save file.
	game=Game.new();game.selected_map="food";root.add_child(game)
	await frames()
	check(game.ui.hero_models is FoodPreview,"Cold food start uses a dedicated visual miniature")
	check(is_equal_approx(ambient(),.48),"Cold food start gets the same contrast as selecting its card later")
	home_isolation("food cold start")
	await motion(true,"food home")
	var food_angle:float=game.ui.hero_models.preview.rotation.y
	game.ui.open_holes();await frames();await motion(false,"food collection")
	game.ui.close_menu();await frames();await motion(true,"food return home")
	check(game.ui.hero_models.preview.rotation.y>food_angle,"Return home resumes the existing food scene")
	game.ui.open_store();await frames();await motion(false,"food store")
	game.ui.close_menu();await frames()
	game.select_map("city");await frames()
	check(is_equal_approx(ambient(),.8),"City restores its own ambient light")
	await motion(true,"city home")
	game.ui.open_store();await frames();await motion(false,"city store")
	game.ui.close_menu();await frames()
	for index in 8:
		var retired:WeakRef=weakref(game.ui.hero_models)
		game.select_map("food" if index%2==0 else "city")
		await frames(2)
		check(retired.get_ref()==null,"Map switch frees the previous preview %d"%index)
		check(game.ui.hero_models.is_processing(),"Either newly selected map animates immediately %d"%index)
	home_isolation("repeated selection")
	game.select_map("food");await frames()
	# Exercise actual entry/pause/results/home transitions, without earning coins.
	game.start_level();await frames();await motion(false,"food intro")
	game.begin_play();game.set_physics_process(false);game.city.rain_enabled=false
	for hole in game.holes:hole.enabled=false
	await frames();await motion(false,"food gameplay")
	game.toggle_pause();await frames();await motion(false,"paused gameplay")
	game.toggle_pause();game.finish("timeout");await frames();await motion(false,"food results")
	game.back_home();await frames();await motion(true,"results home")
	check(game.ui.find_children("*","SubViewport",true,false).size()==3,"Navigation retains only two legacy previews and one reusable case result viewport")
	var result:={"checks":checks,"failures":failures,"observations":observations,"scope":"Natural SceneTree frame motion, menu lifecycle, initial lighting and ownership; no browser pixels or phone FPS."}
	print("MAP_PREVIEW_ACCEPTANCE "+JSON.stringify(result))
	game.free();await process_frame;quit(0 if failures.is_empty() else 1)
