extends SceneTree
## Independent reviewer: real screen-touch routing and cold restore. This test
## has a PID-specific save and never loads the user's progress.
const Rarity=preload("res://fidelity/skin_rarity.gd")
const Game=preload("res://fidelity/game.gd")
var checks:=0
var failures:Array[String]=[]
var game:Node3D
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func frames(count:=2)->void:
	for i in count:await process_frame
func button(id:String)->Button:
	for b in game.ui.buttons:
		if b.name==id or b.text==id:return b
	return null
func touch(at:Vector2,pressed:bool)->void:
	var e:=InputEventScreenTouch.new();e.index=0;e.position=at;e.pressed=pressed
	root.push_input(e,true)
	await frames()
func tap(id:String)->void:
	var b:=button(id)
	check(b!=null,"Real touch target exists: "+id)
	if b==null:return
	var at:=b.get_global_rect().get_center()
	await touch(at,true);await touch(at,false)
func swipe(up:=true)->void:
	# The authored card coordinates now live inside a proportional safe UI.
	# Inject actual screen coordinates, just as tap() uses the global rect.
	var transform:Transform2D=game.ui.get_global_transform_with_canvas()
	var local:Vector2=game.ui.skin_list.position+Vector2(80,132 if up else 42)
	var at:Vector2=transform*local
	await touch(at,true)
	var e:=InputEventScreenDrag.new();e.index=0;e.position=transform*(local+Vector2(0,-90 if up else 90));e.relative=e.position-at
	root.push_input(e,true);await frames()
	await touch(e.position,false)
func active_models()->Array[Node3D]:
	var result:Array[Node3D]=[]
	for view in game.ui.skin_cards:
		for node in view.get_children():
			if node is Node3D and "skin_id" in node and node.is_processing():result.append(node)
	return result
func check_window(label:String)->void:
	var ui=game.ui
	var row_limit:=ceili(ui.skin_list.size.y/172.0)+1
	check(ui.skin_cards.size()<=row_limit*3 and ui.skin_cards.size()==ui.visible_skin_ids().size(),"Only rows intersecting the actual portrait window own preview resources: "+label)
	var active:=active_models()
	var focused:bool=ui.visible_skin_ids().has(ui.preview_skin_id)
	check(active.size()==(1 if focused else 0),"Only an on-screen focused card animates: "+label)
	for i in ui.card_skin_ids.size():
		check(ui.card_skin_ids[i]==ui.visible_skin_ids()[i],"Preview and visible slot identity match: "+label)
		check(ui.card_textures[i].get_parent()==ui.skin_list and ui.skin_list.clip_contents,"Preview is clipped by the actual scrolling viewport: "+label)
	for b in ui.buttons:
		if b.has_meta("skin_id"):
			check(b.disabled or Rect2(Vector2.ZERO,ui.skin_list.size).encloses(b.get_rect()),"Keyboard target is fully inside the clipped list: "+b.name)
		else:check(Rect2(16,16,508,ui.size.y-32).encloses(b.get_rect()),"Fixed control stays in actual phone-safe margins: "+b.name)
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	Input.emulate_mouse_from_touch=true
	game=load("res://fidelity/main.tscn").instantiate();root.add_child(game);await frames(4)
	game.set_process(false);game.set_physics_process(false)
	var save_path:="/tmp/hole-independent-ui-%d.cfg"%OS.get_process_id();game.test_progress_path=save_path
	check(Game.SKIN_DEFS.size()==200,"Game integrates the actual 200-skin catalog")
	await tap("store-nav")
	check(game.ui.menu_screen=="store","Touch opens actual store")
	check(game.gems==10 and button("store-gift")==null,"Fresh diamonds are limited and no unearned stage-gift target exists")
	check(button("store-diamond-video").disabled,"Without an actual rewarded provider the diamond video is disabled")
	await tap("store-diamond-video")
	check(game.gems==10,"A disabled video touch never grants diamonds")
	check(button("store-pack-0").disabled,"Ten starter diamonds cannot pay for the first exchange")
	await tap("store-pack-0")
	check(game.gems==10 and game.coins==50,"Unavailable exchange preserves the new-player wallet")
	# An explicit isolated fixture exercises the actual touch transaction; it
	# does not infer that a user bought or watched an ad for this balance.
	game.gems=100;game.ui.refresh();await frames()
	await tap("store-pack-0")
	check(game.gems==0 and game.coins==2050,"One touch spends100diamonds and receives exactly2000coins")
	await tap("store-pack-0")
	check(game.gems==0 and game.coins==2050,"Rejected exchange preserves wallet")
	var cold:=Game.new();cold.test_progress_path=save_path
	check(cold.load_player_progress() and cold.gems==0 and cold.coins==2050,"UI exchange cold restores both balances correctly");cold.free()
	await tap("holes-nav")
	check(game.ui.menu_screen=="holes","Touch opens collection from store")
	check(game.ui.preview_skin_id==Rarity.NEW_PLAYER_SKIN and game.ui.skin_scroll==0,"Collection opens at Common while retaining equipped starter details")
	check(button("holes-classic-tab")==null and button("holes-special-tab")==null and button("skins-next")==null,"No separate categories or page controls remain")
	var seen:Array[String]=[]
	var rank:=-1
	for id in game.ui.skin_order:
		var next_rank:=Rarity.index_of(str(game.skin_definition(id).rarity))
		check(next_rank>=rank,"All 200 skins progress from lowest to highest rarity: "+id)
		rank=next_rank
		game.ui.scroll_to_skin(id);await frames()
		check(game.ui.visible_skin_ids().has(id),"Every skin is reachable by continuous vertical position: "+id)
		seen.append(id);check_window(id)
	check(seen.size()==200 and game.SKIN_DEFS.all(func(d):return seen.count(d.id)==1),"Former groups merge without missing or duplicate skins")
	game.ui.set_skin_scroll(0);await frames()
	check_window("first rows")
	game.owned_skin_ids.append(game.ui.skin_order[0])
	await swipe()
	check(game.ui.skin_scroll>0 and game.ui.skin_scroll<172,"Touch drag continuously moves less than one row instead of paging")
	check(game.selected_skin_id==Rarity.NEW_PLAYER_SKIN,"Dragging a card does not equip it")
	await swipe(false)
	check(game.ui.skin_scroll==0,"Reverse touch drag reaches the top boundary")
	var transform:Transform2D=game.ui.get_global_transform_with_canvas()
	var equipped_before:String=game.selected_skin_id
	var coins_before:int=game.coins
	await touch(transform*Vector2(100,300),true)
	var canceled:=InputEventScreenTouch.new();canceled.index=0;canceled.pressed=false;canceled.canceled=true;canceled.position=transform*Vector2(100,300)
	root.push_input(canceled,true);await frames()
	check(game.selected_skin_id==equipped_before and game.ui.skin_pointer==-2,"Canceled touch cannot equip the owned card beneath it")
	await touch(transform*Vector2(100,300),true)
	var drag:=InputEventScreenDrag.new();drag.index=0;drag.position=transform*Vector2(270,800);drag.relative=transform.basis_xform(Vector2(170,500))
	root.push_input(drag,true);await frames();await touch(drag.position,false)
	check(game.coins==coins_before and game.selected_skin_id==equipped_before,"A list drag ending on the unlock button cannot spend or equip")
	var wheel:=InputEventMouseButton.new();wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN;wheel.pressed=true;wheel.position=transform*Vector2(100,300)
	root.push_input(wheel,true);await frames()
	check(game.ui.skin_scroll==96 and game.selected_skin_id==equipped_before,"Actual desktop wheel scrolls continuously without changing equipment")
	game.ui.set_skin_scroll(0);await frames()
	await touch(transform*Vector2(100,300),true)
	drag=InputEventScreenDrag.new();drag.index=0;drag.position=transform*Vector2(100,240);drag.relative=transform.basis_xform(Vector2(0,-60));drag.velocity=transform.basis_xform(Vector2(0,-500))
	root.push_input(drag,true);await frames();await touch(drag.position,false)
	var release_scroll:float=game.ui.skin_scroll
	await frames(10)
	check(game.ui.skin_scroll>release_scroll and game.selected_skin_id==equipped_before,"Real flick velocity continues scrolling without a click")
	game.ui.skin_scroll_velocity=0;game.ui.set_skin_scroll(0);await frames()
	var old_size:Vector2i=root.size
	transform=game.ui.get_global_transform_with_canvas()
	var gesture_origin:Vector2=transform*(game.ui.skin_list.position+Vector2(80,132))
	await touch(gesture_origin,true)
	drag=InputEventScreenDrag.new();drag.index=0;drag.position=gesture_origin+transform.basis_xform(Vector2(0,-16));drag.relative=transform.basis_xform(Vector2(0,-16));drag.velocity=transform.basis_xform(Vector2(0,-700))
	root.push_input(drag,true);await frames()
	check(game.ui.skin_pointer==0 and game.ui.skin_scroll_velocity>0,"Actual collection drag owns a pointer and produces flick velocity before resize")
	root.size=Vector2i(540,1174);await frames(4)
	check(game.ui.skin_pointer==-2 and game.ui.skin_scroll_velocity==0,"Changed portrait fit cancels the old-transform gesture and inertia")
	var resize_scroll:float=game.ui.skin_scroll
	await touch(drag.position,false);await frames(6)
	check(game.selected_skin_id==equipped_before and is_equal_approx(game.ui.skin_scroll,resize_scroll),"Release after actual resize cannot equip a card or continue stale scrolling")
	game.ui.set_skin_scroll(0);await frames()
	await swipe();check(game.ui.skin_scroll>0,"Tall-screen touch coordinates scroll the actual collection")
	await swipe(false);check(game.ui.skin_scroll==0,"Tall-screen reverse drag reaches the top")
	root.size=old_size;await frames(4)
	game.ui.set_skin_scroll(-100);check(game.ui.skin_scroll==0,"Scroll clamps at top")
	game.ui.set_skin_scroll(100000);await frames()
	check(game.ui.skin_scroll==game.ui.max_skin_scroll(),"Scroll clamps at bottom")
	check(game.ui.visible_skin_ids().any(func(id):return game.skin_definition(id).rarity=="prismatic"),"Highest rarity is reachable at the bottom")
	check_window("final rows")
	game.owned_skin_ids.append("snail_trail")
	game.ui.scroll_to_skin("snail_trail");await frames();await tap("hole-slot-snail_trail")
	check(game.selected_skin_id=="snail_trail","A formerly Classic form equips through a real touch")
	await tap("holes-home");await tap("holes-nav")
	check(game.ui.skin_scroll==0 and game.ui.preview_skin_id=="snail_trail","Re-entry starts low-to-high while retaining equipment")
	game.ui.scroll_to_skin("moss_bloom");await frames();await tap("hole-slot-moss_bloom")
	check(game.ui.skin_trigger_text().contains("AUTO") and game.ui.skin_trigger_text().contains("12s") and game.ui.skin_detail_text().contains("three"),"Automatic skill retains actual trigger, cooldown and effect")
	game.ui.scroll_to_skin("shard");await frames();await tap("hole-slot-shard")
	check(game.ui.skin_trigger_text().contains("TAP SKILL") and game.ui.skin_trigger_text().contains("11s"),"Manual skill retains trigger and cooldown")
	game.owned_skin_ids.append("music_stage")
	game.ui.scroll_to_skin("music_stage");await frames();await tap("hole-slot-music_stage")
	check(game.selected_skin_id=="music_stage" and game.ui.skin_trigger_text().contains("COSMETIC"),"A formerly Special form equips in the same collection")
	var focused:=active_models()
	var before:float=focused[0].clock_time if focused.size()==1 else 0.0
	await frames(5)
	check(focused.size()==1 and focused[0].clock_time>before,"Focused model's actual shader clock advances")
	var scroll_before:float=game.ui.skin_scroll
	await tap("skin-rates");await tap("rates-back")
	check(game.ui.skin_scroll==scroll_before and game.ui.preview_skin_id=="music_stage","Rates BACK preserves continuous scroll and selected details")
	for i in 6:
		await tap("store-nav");await tap("holes-nav")
	check(game.ui.find_children("*","SubViewport",true,false).size()==game.ui.skin_cards.size()+3,"Repeated navigation retains only current visible models, two legacy views and one reusable case result")
	check(game.ui.case_opening.result_view.render_target_update_mode==SubViewport.UPDATE_DISABLED and not game.ui.case_opening.result_model.is_processing() and not game.ui.case_opening.visible,"Collection navigation leaves the reusable case result hidden and stopped")
	await tap("holes-home");await tap("PLAY")
	check(game.phase=="intro" and game.player.skin_id=="music_stage" and game.ui.skin_cards.is_empty(),"PLAY equips the chosen new form and releases collection resources")
	check(game.ui.case_opening.result_view.render_target_update_mode==SubViewport.UPDATE_DISABLED and not game.ui.case_opening.result_model.is_processing(),"Round entry never starts the case result renderer or animation")
	game.begin_play();game.player.score=Game.SCORE_TARGET
	game.finish("complete")
	check(game.stage==2 and game.round_score_coins==50 and game.round_win_coins==0,"Completion advances stage with50earned score coins")
	var wallet:int=game.coins;game.finish("complete")
	check(game.stage==2 and game.coins==wallet,"Repeated settlement cannot duplicate level or coins")
	cold=Game.new();cold.test_progress_path=save_path
	check(cold.load_player_progress() and cold.stage==2 and cold.selected_skin_id=="music_stage" and cold.coins==wallet,"New stage, last-page equipment and wallet persist together")
	check(not cold.claim_shop_gift().ok and cold.gems==0,"A completed stage cannot manufacture a free diamond gift")
	cold.free()
	# Release the streamed music decoder on its audio thread before freeing the game.
	game.audio.set_process(false) # Freeze pending route changes before decoder teardown.
	game.audio.music.stop();OS.delay_msec(120);await process_frame
	game.free();await frames()
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(save_path+suffix):DirAccess.remove_absolute(save_path+suffix)
	var result:={"checks":checks,"failures":failures,"input":"InputEventScreenTouch and InputEventScreenDrag through actual viewport","scope":"Headless input/resource/save review; no screenshots or phone GPU evidence"}
	print("UI_COLLECTION_REVIEW "+JSON.stringify(result))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	quit(0 if failures.is_empty() else 1)
