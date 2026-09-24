extends SceneTree
var checks:=0
var failures:Array[String]=[]
var game:Node3D

func _initialize() -> void:run.call_deferred()

func check(ok:bool,message:String) -> void:
	checks+=1
	if not ok:failures.append(message);push_error(message)

func frames(count:int) -> void:
	for i in count:await physics_frame

func key(code:Key,pressed:bool) -> void:
	var event:=InputEventKey.new()
	event.physical_keycode=code
	event.keycode=code
	event.pressed=pressed
	Input.parse_input_event(event)

func run() -> void:
	game=load("res://fidelity/main.tscn").instantiate()
	root.add_child(game)
	await frames(4)
	check(game.phase=="title" and game.ui.hero.visible,"initial screen presents authored city miniature")
	check(game.ui.buttons.size()==1 and game.ui.buttons[0].text=="PLAY","first menu has the observed primary PLAY action")
	game.ui.buttons[0].pressed.emit()
	await frames(5)
	check(game.phase=="intro" and game.remaining==240,"PLAY opens a frozen drag tutorial with four minutes")
	check(not game.ui.hero.visible,"title miniature stops rendering during the level")
	check(game.holes.size()==8,"first slice has player plus seven local rivals")
	check(game.player.level==1 and game.player.score==0,"initial player has LVL 1 and 0/10 progress")
	var start:Vector3=game.player.position
	await frames(10)
	check(game.player.position==start and game.elapsed==0,"tutorial does not advance simulation before movement")
	key(KEY_W,true)
	await frames(15)
	key(KEY_W,false)
	check(game.phase=="playing" and game.player.position.distance_to(start)>0.3,"real W input starts the timer and moves the player")
	check(game.remaining<240,"four-minute countdown advances after movement starts")
	var large:Node3D
	var small:Node3D
	for item in game.city.foods:
		if item.category=="vehicle":large=item
		if item.category=="cone":small=item
	check(not large.can_fit(game.player),"LVL 1 cannot swallow a full vehicle footprint")
	game.player.position=Vector3(small.position.x,0,small.position.z)
	var previous:int=game.player.score
	game.scan_food()
	check(small.claimed_by==game.player and not small.freeze,"fitting cone enters rigid-body fall")
	check(game.player.score==previous,"contact does not grant score early")
	await frames(80)
	check(not is_instance_valid(small) and game.player.score>previous,"complete fall collects and awards the object")
	var first=game.spawn_hole("Fixture",Vector3(45,0,45),Color.WHITE,false)
	first.award(9)
	check(first.level==1,"nine points remain LVL 1")
	first.award(1)
	check(first.level==2 and first.radius>0.85,"the observed 10-point threshold increases level and radius")
	first.retire()
	key(KEY_ESCAPE,true)
	for i in 120:
		await process_frame
		if paused:break
	key(KEY_ESCAPE,false)
	await process_frame
	var before:float=game.elapsed
	await frames(8)
	print("PAUSE_CHECK "+JSON.stringify({"paused":paused,"phase":game.phase,"before":before,"after":game.elapsed}))
	check(paused and game.elapsed==before,"Escape pauses timer and physics")
	key(KEY_ESCAPE,true)
	for i in 120:
		await process_frame
		if not paused:break
	key(KEY_ESCAPE,false)
	await frames(4)
	check(not paused and game.elapsed>before,"Escape also resumes from paused state")
	game.start_level()
	await frames(5)
	check(game.player.score==0 and game.player.level==1 and game.elapsed==0,"restart creates a fresh tutorial and growth state")
	game.begin_play()
	game.remaining=0.02
	await frames(4)
	check(game.phase=="timeout","clock expiry presents timeout results")
	game.start_level();game.begin_play()
	await frames(4)
	game.holes[1].award(100)
	game.holes[1].position=game.player.position
	game.scan_rivals()
	check(game.phase=="eaten" and not game.player.active,"larger rival produces EATEN state")
	game.back_home()
	await frames(3)
	check(game.phase=="title" and game.ui.hero.visible,"Give Up returns to the miniature menu")
	game.start_level();game.begin_play()
	await frames(4)
	game.player.award(500)
	await frames(3)
	check(game.phase=="complete","500-point goal completes the first slice")
	# Ordinary movement and scoring, with all seven rivals participating.
	game.demo_mode=true
	game.start_level();game.begin_play()
	Engine.time_scale=3.0
	var ticks:=0
	while game.phase=="playing" and ticks<5200:
		await physics_frame
		ticks+=1
		if ticks%600==0:print("FIDELITY_RUN "+JSON.stringify({"seconds":game.elapsed,"score":game.player.score,"level":game.player.level,"eaten":game.eaten}))
	Engine.time_scale=1.0
	check(game.phase in ["complete","eaten","timeout"] and game.player.score>0 and game.player.level>1,"live-rival automated play grows through earned points and terminates normally")
	var live_run:={"phase":game.phase,"score":game.player.score,"level":game.player.level,"seconds":game.elapsed,"ticks":ticks}
	# Separate level reachability from contested AI outcomes. Retire rivals in this
	# fixture, but keep every footprint, movement, fall and score rule unchanged.
	game.start_level();game.begin_play()
	for h in game.holes:
		if h!=game.player:h.retire()
	Engine.time_scale=3.0
	ticks=0
	while game.phase=="playing" and ticks<5200:
		await physics_frame
		ticks+=1
	Engine.time_scale=1.0
	check(game.phase=="complete" and game.player.score>=500,"the first-city layout reaches 500 points by movement and falling objects without score grants")
	var result:={"checks":checks,"failures":failures,"objects":game.total,"live_rival_run":live_run,"city_reachability":{"rivals_retired_for_fixture":true,"phase":game.phase,"score":game.player.score,"level":game.player.level,"seconds":game.elapsed,"ticks":ticks}}
	print("FIDELITY_ACCEPTANCE "+JSON.stringify(result))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			var out:=FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE)
			out.store_string(JSON.stringify(result,"\t")+"\n")
	game.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)
