extends SceneTree
## Independent reviewer: real screen-touch routing and cold restore. This test
## has a PID-specific save and never loads the user's progress.
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
	var at:=Vector2(100,300 if up else 210)
	await touch(at,true)
	var e:=InputEventScreenDrag.new();e.index=0;e.position=at+Vector2(0,-90 if up else 90);e.relative=Vector2(0,-90 if up else 90)
	root.push_input(e,true);await frames()
	await touch(e.position,false)
func active_models()->Array[Node3D]:
	var result:Array[Node3D]=[]
	for view in game.ui.skin_cards:
		for node in view.get_children():
			if node is Node3D and "skin_id" in node and node.is_processing():result.append(node)
	return result
func check_page(group:String)->void:
	var ui=game.ui
	check(ui.skin_cards.size()<=6 and ui.skin_cards.size()==ui.visible_skin_ids().size(),"Only visible page owns preview resources: "+group)
	check(ui.visible_skin_ids().has(ui.preview_skin_id),"Detail/animation focus stays on visible page: "+group)
	var active:=active_models()
	check(active.size()==1 and active[0].skin_id==ui.preview_skin_id,"Exactly the visible focused card animates: "+group)
	for i in ui.card_skin_ids.size():
		check(ui.card_skin_ids[i]==ui.visible_skin_ids()[i],"Preview model and visible slot identity match: "+group)
	for b in ui.buttons:
		check(Rect2(16,16,508,928).encloses(b.get_rect()),"Control stays in phone-safe margins: "+b.name)
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	Input.emulate_mouse_from_touch=true
	game=load("res://fidelity/main.tscn").instantiate();root.add_child(game);await frames(4)
	game.set_process(false);game.set_physics_process(false)
	var save_path:="/tmp/hole-independent-ui-%d.cfg"%OS.get_process_id();game.test_progress_path=save_path
	check(Game.SKIN_DEFS.size()==44,"Game integrates actual 44-skin catalog")
	await tap("store-nav")
	check(game.ui.menu_screen=="store","Touch opens actual store")
	await tap("store-gift")
	check(game.gems==55,"Touch claims the five-gem initial gift")
	await tap("store-gift")
	check(game.gems==55,"Second touch cannot duplicate gift")
	await tap("store-pack-0")
	check(game.gems==15 and game.coins==370,"Touch spends gems and receives exact first coin pack")
	await tap("store-pack-0")
	check(game.gems==15 and game.coins==370,"Rejected purchase preserves wallet")
	var cold:=Game.new();cold.test_progress_path=save_path
	check(cold.load_player_progress() and cold.gems==15 and cold.coins==370 and cold.shop_gift_claimed_stage==1,"UI transactions cold restore correctly");cold.free()
	await tap("holes-nav")
	check(game.ui.menu_screen=="holes","Touch opens collection from store")
	check_page("Classic first")
	await swipe()
	check(game.ui.skin_page==1,"Upward screen-touch swipe advances one page")
	check(game.selected_skin_id=="core_shell","Paging does not equip a touched locked card")
	check_page("Classic page two")
	await swipe(false)
	check(game.ui.skin_page==0,"Downward screen-touch swipe returns one page")
	check(button("skins-previous").disabled,"First page disables previous")
	for i in 8:await tap("skins-next")
	check(game.ui.skin_page==4 and button("skins-next").disabled and game.ui.visible_skin_ids().size()==3,"Classic final page has three real cards and cannot overrun")
	check_page("Classic final")
	game.owned_skin_ids.append("snail_trail")
	await tap("hole-slot-classic-26")
	check(game.selected_skin_id=="snail_trail","Last Classic slot is touch-selectable")
	await tap("holes-home");await tap("holes-nav")
	check(game.ui.holes_tab=="classic" and game.ui.skin_page==4 and game.ui.preview_skin_id=="snail_trail","Re-entry restores equipped Classic page")
	await tap("holes-special-tab")
	check(game.ui.skin_page==0,"Special tab opens valid initial page")
	await tap("hole-slot-special-01")
	check(game.ui.skin_trigger_text().contains("AUTO") and game.ui.skin_trigger_text().contains("12s") and game.ui.skin_detail_text().contains("three"),"Automatic skin explains actual trigger, cooldown and effect")
	await tap("hole-slot-special-04")
	check(game.ui.skin_trigger_text().contains("TAP SKILL") and game.ui.skin_trigger_text().contains("11s"),"Manual skin explains trigger and cooldown")
	for i in 4:await tap("skins-next")
	check(game.ui.skin_page==2 and game.ui.visible_skin_ids().size()==5 and button("skins-next").disabled,"Special final page contains five actual models")
	check_page("Special final")
	game.owned_skin_ids.append("music_stage")
	await tap("hole-slot-special-16")
	check(game.selected_skin_id=="music_stage" and game.ui.skin_trigger_text().contains("COSMETIC"),"New Special form equips and explains cosmetic behavior")
	var focused:=active_models()
	var before:float=focused[0].clock_time if focused.size()==1 else 0.0
	await frames(5)
	check(focused.size()==1 and focused[0].clock_time>before,"Focused preview's actual shader clock advances")
	await tap("holes-home");await tap("holes-nav")
	check(game.ui.holes_tab=="special" and game.ui.skin_page==2 and game.ui.preview_skin_id=="music_stage","Re-entry restores equipped Special group and page")
	for i in 6:
		await tap("store-nav");await tap("holes-nav")
	check(game.ui.find_children("*","SubViewport",true,false).size()==7,"Repeated menu changes retain only five current cards plus two reusable views")
	await tap("PLAY")
	check(game.phase=="intro" and game.player.skin_id=="music_stage" and game.ui.skin_cards.is_empty(),"PLAY equips the chosen new form and releases collection resources")
	game.begin_play();game.player.score=Game.SCORE_TARGET
	game.finish("complete")
	check(game.stage==2 and game.round_score_coins==50 and game.round_win_coins==20,"Completion advances stage and separates exact reward components")
	var wallet:int=game.coins;game.finish("complete")
	check(game.stage==2 and game.coins==wallet,"Repeated settlement cannot duplicate level or coins")
	cold=Game.new();cold.test_progress_path=save_path
	check(cold.load_player_progress() and cold.stage==2 and cold.selected_skin_id=="music_stage" and cold.coins==wallet,"New stage, last-page equipment and wallet persist together")
	check(cold.claim_shop_gift().ok and cold.gems==20,"New completed level enables one new store gift")
	cold.free()
	# Release the streamed music decoder on its audio thread before freeing the game.
	game.audio.music.stop();OS.delay_msec(120);await process_frame
	game.free();await frames()
	for suffix in ["",".tmp"]:
		if FileAccess.file_exists(save_path+suffix):DirAccess.remove_absolute(save_path+suffix)
	var result:={"checks":checks,"failures":failures,"input":"InputEventScreenTouch and InputEventScreenDrag through actual viewport","scope":"Headless input/resource/save review; no screenshots or phone GPU evidence"}
	print("UI_COLLECTION_REVIEW "+JSON.stringify(result))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	quit(0 if failures.is_empty() else 1)
