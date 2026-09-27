extends SceneTree

var checks:=0
var failures:Array[String]=[]
var game:Node3D

func _initialize() -> void:
	run.call_deferred()

func check(ok:bool,message:String) -> void:
	checks+=1
	if not ok:
		failures.append(message)
		push_error(message)

func frames(count:int) -> void:
	for i in count:await process_frame

func named_button(id:String) -> Button:
	for item in game.ui.buttons:
		if item.name==id:return item
	return null

func run() -> void:
	game=load("res://fidelity/main.tscn").instantiate()
	root.add_child(game)
	await frames(4)
	check(game.phase=="title" and game.ui.menu_screen=="home","title starts on home menu")
	check(named_button("holes-nav")!=null,"home exposes the Holes navigation target")
	check(game.ui.hero.visible,"home keeps the authored miniature visible")
	named_button("holes-nav").pressed.emit()
	await frames(2)
	check(game.ui.menu_screen=="holes" and not game.ui.hero.visible,"Holes opens without starting a round")
	check(game.ui.skin_texture.visible and game.ui.skin_preview_ring!=null,"Rift Forms exposes a live 3D skin preview")
	check(game.ui.skin_preview.skin_shader!=null and game.ui.skin_preview.motes.size()>=5,"the live preview exposes a profile shader and visible motes")
	check(game.ui.holes_tab=="classic","Holes opens on the observed Classic tab")
	check(game.ui.CLASSIC_SLOT_COUNT==5 and game.ui.SPECIAL_SLOT_COUNT==5,"the first release exposes five foundation and five resonance forms")
	check(named_button("holes-classic-tab")!=null and named_button("holes-special-tab")!=null,"both library tabs are interactive")
	check(named_button("hole-slot-classic-00")!=null and named_button("hole-slot-classic-00").visible,"the observed Classic Hole slot is visible")
	check(named_button("hole-slot-classic-01")!=null,"a later Classic slot remains represented")
	named_button("holes-special-tab").pressed.emit()
	await frames(2)
	check(game.ui.holes_tab=="special" and named_button("hole-slot-special-00")!=null,"Special tab exposes its locked slot grid")
	named_button("hole-slot-special-00").pressed.emit()
	await frames(1)
	check(game.ui.toast=="UNLOCK AT 25 SYNC","locked Resonance slots show their per-run sync requirement")
	named_button("holes-classic-tab").pressed.emit()
	await frames(1)
	named_button("hole-slot-classic-00").pressed.emit()
	await frames(1)
	check(game.ui.toast=="Core Shell EQUIPPED","the owned Core Shell has a bounded selection acknowledgement")
	check(game.ui.preview_skin_id=="core_shell" and game.ui.skin_preview_ring.material_override!=null,"selecting a card updates the preview material")
	game.note_skin_progress(game.SCORE_TARGET)
	named_button("hole-slot-classic-01").pressed.emit()
	await frames(1)
	var cinder_preview:Color=(game.ui.skin_preview_void.material_override as StandardMaterial3D).albedo_color
	named_button("hole-slot-classic-02").pressed.emit()
	await frames(1)
	var tide_preview:Color=(game.ui.skin_preview_void.material_override as StandardMaterial3D).albedo_color
	check(cinder_preview!=tide_preview and game.ui.preview_skin_id=="tide","different cards produce different live preview colors")
	named_button("holes-home").pressed.emit()
	await frames(2)
	check(game.phase=="title" and game.ui.menu_screen=="home" and game.ui.hero.visible,"HOME returns to the miniature without a round")
	var result:={"checks":checks,"failures":failures,"classic_slots":game.ui.CLASSIC_SLOT_COUNT,"special_slots":game.ui.SPECIAL_SLOT_COUNT}
	print("TITLE_NAVIGATION_ACCEPTANCE "+JSON.stringify(result))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			var out:=FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE)
			out.store_string(JSON.stringify(result,"\t")+"\n")
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
