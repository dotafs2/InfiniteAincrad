extends SceneTree
## Real receipt routing, audio PCM and safe-layout/input behavior. Device
## audibility and tactile quality require a physical phone, not this fixture.
const Layout=preload("res://fidelity/viewport_layout.gd")
const Feedback=preload("res://fidelity/swallow_feedback.gd")
const Burst=preload("res://fidelity/rival_burst.gd")
var checks:=0
var failures:Array[String]=[]
var game:Node3D
var pulses:Array[Dictionary]=[]
var events:Array[Dictionary]=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func frames(n:=3)->void:
	for _i in n:await process_frame
func fake_haptic(duration:int,amplitude:float)->void:
	pulses.append({"duration":duration,"amplitude":amplitude})
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	AudioServer.set_bus_mute(0,true)
	check(ProjectSettings.get_setting("display/window/stretch/aspect")=="expand","The root expands to fill tall and wide screens")
	check(ProjectSettings.get_setting("audio/general/ios/session_category")==3,"Native iOS uses playback audio, including the silent-switch case")
	for viewport in [Vector2(540,960),Vector2(540,1173),Vector2(540,1169),Vector2(768,1024),Vector2(960,540)]:
		for inset in [0.0,45.0]:
			var safe:=Rect2(Vector2(0,inset),viewport-Vector2(0,inset+24))
			var layout:=Layout.fit(viewport,safe)
			var design:=Rect2(layout.position,Layout.DESIGN*layout.scale)
			check(safe.grow(.001).encloses(design),"All authored controls fit the safe area: "+str(viewport)+" / "+str(inset))
			check(layout.scale.x==layout.scale.y,"UI targets keep their shape on "+str(viewport))
	var feedback:=Feedback.new();root.add_child(feedback)
	feedback.haptic_driver=fake_haptic
	check(feedback.trigger(1),"An item receipt produces feedback")
	check(not feedback.trigger(1) and pulses.size()==1,"A same-frame pile cannot produce continuous vibration")
	check(feedback.trigger(30,true) and pulses.size()==2,"A rival receipt bypasses the item throttle")
	check(pulses[0].duration<=35 and pulses[0].amplitude<=.24 and pulses[1].duration==65 and pulses[1].amplitude==.80,"Rival victory gets a stronger short pulse; food remains light")
	feedback.haptics_enabled=false;feedback.last_msec=-1000
	check(feedback.trigger(10) and pulses.size()==2,"Turning haptics off suppresses the driver independently of sounds")
	for tier in 4:
		var wav:=feedback.make_gulp(tier)
		var peak:=0
		for i in wav.data.size()/2:peak=maxi(peak,absi(wav.data.decode_s16(i*2)))
		check(wav.mix_rate==22050 and wav.data.size()>=3900 and wav.data.size()<=7100,"Gulp has a short real PCM payload: "+str(tier))
		check(peak>5000 and peak<11000 and wav.data.decode_s16(0)==0 and absi(wav.data.decode_s16(wav.data.size()-2))<=1,"Soft attack/release prevents clicks and clipping: "+str(tier))
	feedback.free()
	game=load("res://fidelity/main.tscn").instantiate();game.selected_skin_id="cocoa_square";root.add_child(game);await frames()
	game.feedback.haptic_driver=fake_haptic
	game.feedback.feedback_triggered.connect(func(details:Dictionary):events.append(details))
	game.start_level();game.begin_play();game.set_physics_process(false);await frames()
	for h in game.holes:h.enabled=false;h.active=h==game.player
	check(game.remaining==90.0,"A fresh Sunny City round starts with exactly 90 seconds")
	var item:Node3D=game.city.foods[0]
	game.collect(item,game.player)
	check(events.size()==1 and not events[0].rival,"An actual player collection routes the item feedback")
	game.collect(item,game.holes[1])
	check(events.size()==1,"AI receipts never trigger the human feedback")
	var victim=game.holes[1];victim.active=true;victim.radius=.8
	game.player.radius=4.0;victim.position=game.player.position
	game.elapsed=20;game.reset_rival_state();game.scan_rivals()
	check(game.kills==1 and events.size()==2 and events[-1].rival,"The actual rival kill routes feedback exactly once")
	game.scan_rivals();check(events.size()==2,"A retired rival cannot repeat its pulse")
	var common:Node3D=game.player.skin_visual.common
	check(is_instance_valid(common) and common.rival_events==1 and common.rival_active and common.active_count==8 and common.particles.multimesh.instance_count==8 and common.particles.multimesh.visible_instance_count==8 and game.world.get_children().filter(func(n:Node):return n is Burst).is_empty(),"The real Common victory uses exactly one eight-slot custom burst and no duplicate generic burst")
	# Exercise the newly themed response through a second actual combat receipt.
	# Keep the old generic helper unit coverage below for compatibility.
	game.player.skin_id="copper_ring"
	game.player.skin_visual.build(game.skin_definition("copper_ring"))
	game.player.skin_ring=game.player.skin_visual.main_ring
	var fallback_victim=game.holes[2];fallback_victim.active=true;fallback_victim.radius=.8
	game.player.radius=4.0;fallback_victim.position=game.player.position
	game.elapsed=21;game.reset_rival_state();game.scan_rivals()
	var generic_bursts:Array=game.world.get_children().filter(func(n:Node):return n is Burst)
	var themed:Node3D=game.player.skin_visual.collection
	check(game.kills==2 and events.size()==3 and events[-1].rival and not fallback_victim.active and generic_bursts.is_empty() and is_instance_valid(themed) and themed.rival_events==1 and themed.active_count==12 and themed.particles.multimesh.instance_count==12,"Original Copper Ring now emits exactly one twelve-slot themed response for its real victory")
	game.scan_rivals()
	check(events.size()==3 and game.kills==2 and game.world.get_children().filter(func(n:Node):return n is Burst).is_empty() and themed.rival_events==1,"Repeated scans cannot duplicate the themed victory or its haptic receipt")
	var profiles:={}
	for definition in game.SKIN_DEFS:
		var burst:=Burst.new();root.add_child(burst);burst.build(definition,4.0);burst.set_process(false)
		profiles[burst.profile]=true
		check(burst.skin_id==definition.id and burst.palette[0]==Color(definition.tint) and burst.palette[1]==Color(definition.accent),"Victory colors come from the equipped skin: "+str(definition.id))
		check(burst.particles.multimesh.instance_count==28 and burst.find_children("*","CollisionObject3D",true,false).is_empty(),"Burst is bounded and cannot change physics: "+str(definition.id))
		# The headless rendering server does not expose MultiMesh buffers. Check
		# the actual transforms submitted by the effect, then inspect a GPU frame.
		var before:Vector3=burst.poses[0].origin
		burst._process(.25)
		check(burst.poses[0].origin.y>before.y,"Skin particles fly out of the hole: "+str(definition.id))
		burst._process(.15)
		check(Vector2(burst.poses[0].origin.x,burst.poses[0].origin.z).length()>4.0,"The visible burst clears the swallowing opening: "+str(definition.id))
		burst._process(.50);check(burst.is_queued_for_deletion(),"Victory particles retire within one second: "+str(definition.id))
		burst.free()
	check(profiles.size()==5,"Skin themes use five distinct particle silhouettes")
	root.size=Vector2i(540,1173);await frames();game.ui.update_viewport_layout()
	check(game.ui.canvas_bounds().size.is_equal_approx(Vector2(540,1173)),"Menu background covers the expanded root viewport")
	for button in game.ui.buttons:
		check(Rect2(Vector2.ZERO,Vector2(540,1173)).encloses(button.get_global_rect()),"Expanded HUD target stays on screen: "+button.name)
	var source:=Vector2(183,1001)
	check((game.ui.get_global_transform_with_canvas()*game.ui.canvas_point(source)).is_equal_approx(source),"Touch and projected-world coordinates round-trip through the safe UI transform")
	game.remaining=.01;game._physics_process(.02)
	check(game.phase=="complete" and game.remaining==0.0,"Time expiry settles the configured map round")
	game.free();await frames();root.size=Vector2i(540,960)
	print("NATIVE_POLISH_ACCEPTANCE "+JSON.stringify({"checks":checks,"failures":failures,"ok":failures.is_empty(),"device_listening_and_haptic_quality_verified":false}))
	quit(0 if failures.is_empty() else 1)
