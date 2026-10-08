extends SceneTree
## Actual viewport input and GPU case presentation. All balances/eligible pools
## are isolated fixtures; --test with an empty progress path never writes saves.
const Game=preload("res://fidelity/game.gd")
const Rarity=preload("res://fidelity/skin_rarity.gd")
class FaultySaveGame:
	extends "res://fidelity/game.gd"
	var fail_saves:=false
	var save_calls:=0
	func save_player_progress()->bool:
		save_calls+=1
		return false if fail_saves else super.save_player_progress()
class InsetUI extends "res://fidelity/ui.gd":
	func viewport_safe_rect(viewport:Vector2)->Rect2:
		return ViewportLayout.safe_rect_from_pixels(viewport,Vector2(1320,2868),Rect2(0,186,1320,2580))

var game:Node3D
var case_ui
var checks:=0
var failures:Array[String]=[]
var directory:=""
var report_path:=""
var observations:Array[Dictionary]=[]
var fixture:="fresh collection with isolated funded wallet"

func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func frames(count:=4)->void:
	for _i in count:await process_frame
func target(id:String)->Button:
	for b in game.ui.buttons:
		if b.name==id:return b
	return null
func click_at(at:Vector2)->void:
	for pressed in [true,false]:
		var event:=InputEventMouseButton.new()
		event.position=at;event.global_position=at
		event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed
		root.push_input(event,true);await frames(1)
	await frames(2)
func tap(id:String)->void:
	var b:=target(id);check(b!=null,"Exposed pointer control: "+id)
	if b!=null:await click_at(b.get_global_rect().get_center())
func state()->Dictionary:
	return {"coins":game.coins,"gems":game.gems,"owned":game.owned_skin_ids.duplicate(),
		"selected":game.selected_skin_id,"pity":game.draw_pity.duplicate(true),
		"receipt":game.pending_skin_case(),"serial":game.skin_case_serial}
func active_views()->int:
	var count:=0
	for view in game.ui.find_children("*","SubViewport",true,false):
		if view.render_target_update_mode==SubViewport.UPDATE_ALWAYS:count+=1
	return count
func check_ready_examples(label:String)->void:
	check(case_ui.stage=="ready",label+": eligible examples are checked before spending")
	var eligible:Array[String]=game.locked_skin_ids("collection")
	for id in case_ui.reel_ids:
		check(eligible.has(id) and not game.skin_unlocked(id),label+": ready example is an actually eligible unowned skin: "+id)
	if eligible.is_empty():
		check(case_ui.reel_ids.is_empty(),label+": sold-out reel is blank and advertises no unavailable reward")
	elif eligible.size()==1:
		check(case_ui.reel_ids.size()==1 and case_ui.reel_ids[0]==eligible[0],label+": sole eligible skin is the only ready example")
		check(is_zero_approx(case_ui.offset),label+": sole eligible skin is centered under the fixed marker")
	else:
		check(not case_ui.reel_ids.is_empty(),label+": available collection has eligible ready examples")
func snap(label:String)->void:
	if directory.is_empty():return
	for _i in 4:await RenderingServer.frame_post_draw
	var pixels:=root.get_texture().get_image()
	check(pixels!=null and not pixels.is_empty(),"Nonempty GPU pixels: "+label)
	if pixels==null or pixels.is_empty():return
	check(pixels.save_png(directory+"/"+label+".png")==OK,"GPU frame saved: "+label)
	observations.append({"file":label+".png","fixture":fixture,"viewport":str(root.size),
		"canvas":str(game.ui.size),"screen":game.ui.menu_screen,"stage":case_ui.stage,
		"winner":str(case_ui.receipt.get("id","")),"selected":game.selected_skin_id,
		"coins":game.coins,"elapsed":case_ui.elapsed,"offset":case_ui.offset,
		"celebration_active":case_ui.celebration.active,"celebration_age":case_ui.celebration.age,
		"celebration_bursts":case_ui.celebration.burst_count,"celebration_particles":case_ui.celebration.particles.size()})
func layout(label:String)->void:
	check(game.ui.menu_screen=="case" and case_ui.visible,label+": dedicated case is visible")
	check(not game.ui.hero.visible and game.ui.hero_view.render_target_update_mode==SubViewport.UPDATE_DISABLED,label+": obsolete hero is suspended")
	check(not game.ui.map_carousel.visible and not game.ui.skin_list.visible,label+": map/collection do not compete with case")
	check(not is_instance_valid(game.world),label+": case does not construct a gameplay map")
	check(case_ui.reel.clip_contents and case_ui.reel.mouse_filter==Control.MOUSE_FILTER_IGNORE,label+": reel clips cells and does not intercept controls")
	check(case_ui.find_children("*","SubViewport",true,false).size()==1,label+": exactly one reusable result viewport")
	check(case_ui.result_view.render_target_update_mode==(SubViewport.UPDATE_ALWAYS if case_ui.stage=="result" else SubViewport.UPDATE_DISABLED),label+": result viewport updates only for result")
	check(active_views()==(1 if case_ui.stage=="result" else 0),label+": at most one result model renders continuously")
	var area:=Rect2(Vector2.ZERO,game.ui.size)
	check(area.encloses(case_ui.reel.get_rect()),label+": reel lies inside safe canvas")
	if case_ui.stage=="result":
		check(case_ui.result_texture.visible and case_ui.result_texture.stretch_mode==TextureRect.STRETCH_KEEP_ASPECT_CENTERED,label+": result preserves model aspect")
		check(case_ui.result_texture.get_rect().end.y<target("case-equip").position.y,label+": result preview does not cover equip")
	for b in game.ui.buttons:
		check(area.grow(.01).encloses(b.get_rect()),label+": safe canvas contains "+b.name)
		check(minf(b.size.x,b.size.y)*375.0/540.0>=44,label+": 44-point minimum touch target "+b.name)
	for i in game.ui.buttons.size():
		for j in range(i+1,game.ui.buttons.size()):
			check(not game.ui.buttons[i].get_rect().intersects(game.ui.buttons[j].get_rect()),label+": controls do not overlap")
	check(not case_ui.sound.tick_voice.playing and not case_ui.sound.accent_voice.playing,label+": muted fixture has no case audio voices playing")
	if case_ui.stage=="ready":check_ready_examples(label)
func eligible_fixture(ids:Array[String],balance:=350)->void:
	# Explicit pool setup makes appearance screenshots deterministic. These are
	# not claims of organically rolled rare rewards or real account inventory.
	game.owned_skin_ids.clear()
	for definition in game.SKIN_DEFS:
		if not ids.has(str(definition.id)):game.owned_skin_ids.append(str(definition.id))
	game.selected_skin_id="cocoa_square";game.coins=balance
	game.draw_pity={};game.skin_case_receipt={};game.last_unlock_msec=-1000
	game.fail_saves=false;case_ui.stage="ready";case_ui.set_process(false)
	fixture="Explicit isolated eligible pool: "+", ".join(ids)
	game.ui.request_unlock();case_ui.enter();game.ui.refresh()
	check_ready_examples("isolated ready pool")
func check_receipt_center(label:String)->void:
	check(case_ui.stage=="result",label+": result is revealed")
	check(case_ui.result_id==str(game.pending_skin_case().get("id","")),label+": shown model is the committed winner")
	check(is_equal_approx(case_ui.offset,float(case_ui.WINNER_INDEX)*case_ui.CELL),label+": winning cell center exactly meets stationary marker")
	if case_ui.reel_ids.size()>case_ui.WINNER_INDEX:
		check(case_ui.reel_ids[case_ui.WINNER_INDEX]==case_ui.result_id,label+": final reel cell and result model agree")

func celebration_idle(label:String,bursts:int)->void:
	var effect=case_ui.celebration
	check(not effect.active and not effect.visible and not effect.is_processing() and effect.particles.is_empty(),label+": celebration releases particles and stops processing while idle")
	check(effect.burst_count==bursts,label+": no additional celebration was started")

func celebration_live(label:String,bursts:int)->void:
	var effect=case_ui.celebration
	check(effect.active and effect.visible and effect.is_processing() and effect.burst_count==bursts,label+": fresh reveal starts exactly one live celebration")
	check(effect.particles.size()>0 and effect.particles.size()<=effect.MAX_PARTICLES and effect.MAX_PARTICLES<=36,label+": decorative particles have a fixed small bound")
	check(effect.mouse_filter==Control.MOUSE_FILTER_IGNORE and effect.get_child_count()==0,label+": canvas effect intercepts no pointer input and owns no emitter/timer/viewport nodes")
	check(effect.get_index()<case_ui.result_texture.get_index(),label+": celebration remains behind the live result model")
	# Sample the actual controller deterministically; real-time motion is covered
	# by the separately captured GPU clip, not these manual time advances.
	effect.set_process(false)

func celebration_lifecycle()->void:
	var effect=case_ui.celebration
	var before:=state()
	var saves:int=game.save_calls
	var age:float=effect.age
	effect.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	effect._process(.2)
	check(is_equal_approx(effect.age,age),"Celebration freezes on focus loss")
	effect.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	effect.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	effect._process(.2)
	check(is_equal_approx(effect.age,age),"Application resume does not override outstanding celebration focus loss")
	effect.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	effect._process(.1)
	check(is_equal_approx(effect.age,age+.1),"Celebration continues its existing burst after focus is restored")
	age=effect.age
	effect.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	effect.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	effect.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	effect._process(.2)
	check(is_equal_approx(effect.age,age),"Focus return does not override outstanding celebration application suspension")
	effect.notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	var was_paused:=paused
	paused=true;effect._process(.2);paused=was_paused
	check(is_equal_approx(effect.age,age),"Tree pause independently freezes celebration")
	effect._process(.1)
	check(is_equal_approx(effect.age,age+.1),"Clearing every suspension cause advances without restarting")
	check(state()==before and game.save_calls==saves,"Celebration suspension and advancement change no transaction state or save count")

func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):directory=arg.trim_prefix("--output=")
		elif arg.begins_with("--capture-dir="):directory=arg.trim_prefix("--capture-dir=")
		elif arg.begins_with("--report="):report_path=arg.trim_prefix("--report=")
	if not directory.is_empty() and DisplayServer.get_name()=="headless":
		push_error("Case screenshot output requires a real GPU window");quit(2);return
	if not directory.is_empty():DirAccess.make_dir_recursive_absolute(directory)
	AudioServer.set_bus_mute(0,true);root.size=Vector2i(540,1174)
	game=FaultySaveGame.new();root.add_child(game);await frames()
	game.music_enabled=false;game.sfx_enabled=false
	game.audio.set_music_enabled(false);game.audio.set_sfx_enabled(false)
	case_ui=game.ui.case_opening
	celebration_idle("new UI",0)
	check(game.test_mode and game.test_progress_path.is_empty() and game.progress_file().is_empty(),"GPU fixture cannot access a real save")
	check(game.SKIN_DEFS.size()==200 and game.COIN_DRAW_PRICE==100,"Current collection and accepted case price remain 200 / 100")
	game.coins=350
	await tap("holes-nav");check(game.ui.menu_screen=="holes","Actual dock click opens collection")
	await snap("collection-tall")
	var before:=state()
	await tap("unlock-random")
	check(game.ui.menu_screen=="case" and case_ui.stage=="ready" and state()==before,"Entering case is free and changes no inventory/equipment")
	case_ui.set_process(false)
	layout("ready tall");await snap("ready-tall")
	for definition in game.SKIN_DEFS:
		check(ResourceLoader.exists("res://assets/skin_thumbnails/"+str(definition.id)+".png"),"Actual skin thumbnail resource: "+str(definition.id))
	var thumb:Texture2D=case_ui.thumbnail("aurora_rift")
	check(thumb!=null and thumb.get_size().x>0,"Aurora thumbnail has actual pixels")
	check(case_ui.thumbnail("aurora_rift")==thumb,"Repeated reel imagery reuses a cached texture resource")
	await tap("case-odds")
	check(game.ui.menu_screen=="rates" and not case_ui.visible and state()==before,"Odds access is free and hides case")
	await snap("odds-tall")
	await tap("rates-back")
	check(game.ui.menu_screen=="case" and case_ui.stage=="ready" and state()==before,"Odds BACK returns to the same free case")
	var open_at:Vector2=target("case-open").get_global_rect().get_center()
	var opening_bursts:int=case_ui.celebration.burst_count
	await tap("case-open")
	check(case_ui.stage=="rolling" and not game.pending_skin_case().is_empty(),"Actual OPEN click commits and starts reel")
	var committed:=state()
	celebration_idle("rolling has not revealed a prize",opening_bursts)
	check(game.coins==int(before.coins)-100 and game.owned_skin_ids.size()==before.owned.size()+1,"Exactly one 100-coin debit and one new award")
	check(game.selected_skin_id==before.selected,"Case purchase does not equip automatically")
	check(target("case-open")==null and target("case-equip")==null and target("case-skip")!=null,"Rolling exposes SKIP without another spend/equip action")
	check(target("case-odds").disabled,"Odds cannot change purchase context during motion")
	var sequence:Array=case_ui.reel_ids.duplicate()
	case_ui.build_reel();check(case_ui.reel_ids==sequence,"Saved presentation seed produces deterministic decorative sequence")
	check(case_ui.reel_ids[case_ui.WINNER_INDEX]==committed.receipt.id,"Reel places committed winner at stop cell")
	case_ui._process(1.0);layout("rolling");await snap("rolling-tall")
	var frozen_elapsed:float=case_ui.elapsed
	case_ui.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	case_ui._process(.7)
	check(is_equal_approx(case_ui.elapsed,frozen_elapsed) and state()==committed,"Focus loss pauses cosmetic motion without changing award")
	case_ui.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	await create_timer(.85).timeout
	case_ui.begin_open();case_ui.begin_open()
	check(state()==committed,"Delayed duplicate OPEN callbacks cannot spend or reroll")
	await click_at(open_at)
	check(state()==committed,"Repeated pointer at previous OPEN location cannot charge again")
	# Depending on the reused hit position, this is already a legitimate SKIP.
	if case_ui.stage=="rolling":await tap("case-skip")
	check_receipt_center("skip")
	check(state()==committed and game.selected_skin_id==before.selected,"SKIP only reveals the saved award and never equips")
	celebration_live("skip",opening_bursts+1)
	celebration_lifecycle()
	var skip_age:float=case_ui.celebration.age
	var skip_saves:int=game.save_calls
	case_ui.reveal();game.ui.refresh();case_ui.reveal()
	check(case_ui.celebration.burst_count==opening_bursts+1 and is_equal_approx(case_ui.celebration.age,skip_age),"Duplicate reveal and UI refresh neither replay nor reset the active celebration")
	check(state()==committed and game.save_calls==skip_saves,"Duplicate cosmetic callbacks never spend, reroll, equip or save")
	layout("result after skip");await snap("result-first-tall")
	await tap("case-back")
	celebration_idle("BACK from active celebration",opening_bursts+1)
	check(game.ui.menu_screen=="holes" and case_ui.result_view.render_target_update_mode==SubViewport.UPDATE_DISABLED,"Leaving result suspends its live viewport")
	check(state()==committed,"Leaving keeps pending award without acknowledging or spending")
	await tap("unlock-random")
	check_receipt_center("reentry")
	check(state()==committed,"Reentry restores the same result without a new lottery")
	celebration_idle("restored pending result",opening_bursts+1)
	await tap("case-equip")
	check(game.selected_skin_id==str(committed.receipt.id),"Only explicit EQUIP pointer action selects the prize")
	check(game.coins==committed.coins and game.owned_skin_ids==committed.owned and target("case-equip").disabled,"EQUIP is free and becomes visibly EQUIPPED")
	celebration_idle("equip restored result",opening_bursts+1)
	await snap("result-equipped-tall")
	var continue_at:Vector2=target("case-continue").get_global_rect().get_center()
	await tap("case-continue")
	celebration_idle("CONTINUE resets ready state",opening_bursts+1)
	check(case_ui.stage=="ready" and game.pending_skin_case().is_empty() and game.coins==committed.coins,"CONTINUE acknowledges presentation without another purchase")
	var acknowledged:=state()
	check(target("case-open").disabled,"Acknowledgement temporarily disables the overlapping OPEN action")
	await click_at(continue_at)
	check(state()==acknowledged and case_ui.stage=="ready","Immediate second pointer tap at CONTINUE position cannot start or charge the next case")
	case_ui.begin_open()
	check(state()==acknowledged and case_ui.stage=="ready","Immediate direct OPEN callback after acknowledgement cannot bypass the acquisition guard")
	check(target("case-open").disabled,"OPEN remains disabled during the acknowledgement guard")
	# Isolated wall-clock guard: no real save, account or engine helper is used.
	OS.delay_msec(820);case_ui._process(0)
	check(not target("case-open").disabled,"OPEN becomes available after the 800 ms acknowledgement guard")
	check(state()==acknowledged and case_ui.stage=="ready","Guard expiry enables the next intentional purchase without spending automatically")
	# Deterministic visual fixtures use the real transaction path and a single
	# eligible item. They never inject the outcome into the reel/result screen.
	for entry in [["plain_loop","common"],["aurora_rift__solar_rift","prismatic"]]:
		eligible_fixture([str(entry[0])]);await frames()
		var prior_skin:String=game.selected_skin_id
		await tap("case-open")
		check(case_ui.stage=="rolling" and case_ui.receipt.id==entry[0] and case_ui.receipt.rarity==entry[1],"Real eligible-pool transaction for "+str(entry[1]))
		var natural_before:=state()
		var natural_saves:int=game.save_calls
		var natural_bursts:int=case_ui.celebration.burst_count
		seed(0xCE1E2026)
		var expected_next_random:=randi()
		seed(0xCE1E2026)
		case_ui._process(case_ui.DURATION)
		check(randi()==expected_next_random,"Natural reveal and celebration do not consume the economy's global RNG: "+str(entry[1]))
		check_receipt_center(str(entry[1])+" natural finish")
		check(game.selected_skin_id==prior_skin,"Natural animation completion does not auto-equip "+str(entry[1]))
		check(state()==natural_before and game.save_calls==natural_saves,"Natural reveal adds no debit, award, pity change or save: "+str(entry[1]))
		celebration_live(str(entry[1])+" natural finish",natural_bursts+1)
		case_ui.celebration._process(.25)
		layout(str(entry[1])+" result");await snap("result-"+str(entry[1])+"-tall")
		if entry[1]=="common":
			await tap("case-equip")
			check(case_ui.celebration.active and case_ui.celebration.burst_count==natural_bursts+1,"EQUIP during an active celebration does not retrigger it")
			await tap("case-odds")
			celebration_idle("ODDS hides active celebration",natural_bursts+1)
			await tap("rates-back")
			celebration_idle("ODDS return preserves result without replay",natural_bursts+1)
		else:
			case_ui.celebration.set_process(true)
			case_ui.celebration._process(case_ui.celebration.DURATION)
			celebration_idle("finite celebration completes",natural_bursts+1)
			case_ui.celebration._process(10.0);case_ui.reveal();game.ui.refresh()
			celebration_idle("settled result stays idle",natural_bursts+1)
		await tap("case-continue")
		celebration_idle("next case is reset",natural_bursts+1)
		check(target("case-open").disabled and target("case-open").text=="COLLECTION COMPLETE","Final unowned award leaves a genuine sold-out state")
		check_ready_examples(str(entry[1])+" completed collection")
		var sold_out:=state();case_ui.begin_open()
		check(state()==sold_out and case_ui.stage=="ready","Sold-out direct callback neither charges nor animates")
	await snap("sold-out-tall")
	eligible_fixture(["plain_loop"],20);await frames()
	check(target("case-open").disabled and case_ui.message.contains("80"),"Shortfall is exact and OPEN disabled")
	var shortfall_bursts:int=case_ui.celebration.burst_count
	var shortfall:=state();case_ui.begin_open()
	check(state()==shortfall and case_ui.stage=="ready","Insufficient-funds callback cannot spend or animate")
	celebration_idle("insufficient funds",shortfall_bursts)
	await snap("shortfall-tall")
	eligible_fixture(["plain_loop"],350);await frames()
	game.fail_saves=true
	var failed_bursts:int=case_ui.celebration.burst_count
	var failed_before:=state();await tap("case-open")
	check(state()==failed_before and case_ui.stage=="ready" and case_ui.message.contains("No coins spent"),"Failed save leaves free ready UI and rolls back the economic transaction")
	check(active_views()==0,"Failed save cannot display a success result")
	celebration_idle("failed transaction has no celebration",failed_bursts)
	await snap("save-failure-tall");game.fail_saves=false
	for viewport in [Vector2i(375,667),Vector2i(440,956)]:
		root.size=viewport;await frames();game.ui.update_viewport_layout();await frames()
		eligible_fixture(["plain_loop","aurora_rift__solar_rift"]);await frames()
		layout("ready "+str(viewport));await snap("ready-%d"%viewport.x)
		var viewport_bursts:int=case_ui.celebration.burst_count
		await tap("case-open");await tap("case-skip")
		check(case_ui.celebration.active and case_ui.celebration.burst_count==viewport_bursts+1,"Responsive SKIP starts one live celebration")
		case_ui.celebration.set_process(false);case_ui.celebration._process(.25)
		layout("result "+str(viewport));await snap("result-%d"%viewport.x)
		check(case_ui.celebration.active,"Responsive fixture is acknowledged during its live celebration")
		await tap("case-continue")
		celebration_idle("CONTINUE cancels an active celebration",viewport_bursts+1)
	# Rebuild only the UI with the production safe-area transformation. The
	# physical rectangle is a labelled desktop fixture, not a phone capture.
	var layer:Node=game.ui.get_parent()
	game.ui.free();game.ui=InsetUI.new();game.ui.game=game;layer.add_child(game.ui);await frames()
	case_ui=game.ui.case_opening
	eligible_fixture(["aurora_rift__solar_rift"]);await frames()
	layout("16 Pro Max inset fixture")
	var safe:Rect2=game.ui.viewport_safe_rect(game.ui.get_viewport_rect().size)
	for b in game.ui.buttons:check(safe.grow(.01).encloses(b.get_global_rect()),"Physical safe-area fixture contains "+b.name)
	await snap("ready-safe-insets")
	await tap("case-open");await tap("case-skip")
	case_ui.celebration.set_process(false);case_ui.celebration._process(.25)
	layout("inset result")
	for b in game.ui.buttons:check(safe.grow(.01).encloses(b.get_global_rect()),"Result safe-area fixture contains "+b.name)
	await snap("result-safe-insets")
	check(game.test_progress_path.is_empty() and game.progress_file().is_empty(),"All GPU checks retained an empty save path")
	var report:={"checks":checks,"failures":failures,"observations":observations,"display_server":DisplayServer.get_name(),
		"scope":"Actual viewport input and controlled cosmetic animation sampling; GPU screenshots only when output is requested. Funded wallets and single-item eligible pools are explicitly isolated QA fixtures, not production rewards. No real saves, purchases, ads or accounts. Safe insets are desktop layout fixtures; continuous real-time motion and phone performance are separate evidence."}
	print("SKIN_CASE_UI_ACCEPTANCE "+JSON.stringify(report))
	if not directory.is_empty():FileAccess.open(directory+"/report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	if not report_path.is_empty():
		DirAccess.make_dir_recursive_absolute(report_path.get_base_dir())
		FileAccess.open(report_path,FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	game.free();await process_frame;quit(0 if failures.is_empty() else 1)
