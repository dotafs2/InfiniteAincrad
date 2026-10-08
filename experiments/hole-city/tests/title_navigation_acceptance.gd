extends SceneTree

const Rarity=preload("res://fidelity/skin_rarity.gd")

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
	var home:Button=named_button("holes-home")
	var store:Button=named_button("store-nav")
	var holes:Button=named_button("holes-nav")
	check(home!=null and store!=null and holes!=null,"Home exposes all three shared destinations")
	if home!=null and store!=null and holes!=null:
		check(home.position.x<store.position.x and store.position.x<holes.position.x,"Shared dock starts with HOME, then STORE, then HOLES")
		check(home.size==store.size and store.size==holes.size,"Dock destination targets keep equal stable geometry")
		check(home.disabled and not store.disabled and not holes.disabled,"Home starts as the clearly selected destination")
	check(game.ui.map_carousel.visible and game.ui.map_carousel.photos.size()==4 and not game.ui.hero.visible and game.ui.hero_view.render_target_update_mode==SubViewport.UPDATE_DISABLED,"Home presents four screenshot cards with the old live miniature disabled")
	check(game.selected_skin_id==Rarity.NEW_PLAYER_SKIN and game.skin_unlocked(Rarity.NEW_PLAYER_SKIN) and not game.skin_unlocked("core_shell"),"Fresh collection owns only its Common starter, without granting Legendary Core Shell")
	# Explicit grandfathered ownership fixture preserves the original advanced-FX checks.
	game.owned_skin_ids.append("core_shell")
	check(game.select_skin("core_shell"),"Grandfathered Core Shell remains equippable")
	named_button("holes-nav").pressed.emit()
	await frames(2)
	check(game.ui.menu_screen=="holes" and not game.ui.hero.visible,"Holes opens without starting a round")
	check(not game.ui.skin_texture.visible and not game.ui.skin_cards.is_empty(),"Collection presents real model cards in one clipped vertical list")
	check(game.ui.skin_preview.skin_shader!=null and game.ui.skin_preview.fx_family=="accretion","Live preview retains the continuous accretion-disc shader")
	check(game.ui.skin_order.size()==200 and game.ui.skin_order[0]!="core_shell","All 200 forms appear in rarity order, starting below Legendary")
	check(named_button("holes-classic-tab")==null and named_button("holes-special-tab")==null,"Category tabs have been removed")
	game.ui.scroll_to_skin("moss_bloom");await frames(2)
	named_button("hole-slot-moss_bloom").pressed.emit();await frames(1)
	check(game.ui.toast.to_upper().contains("CASE") and not game.ui.toast.contains("UNLOCK RANDOM"),"Locked slots direct players to the single case acquisition flow")
	game.ui.scroll_to_skin("core_shell");await frames(2)
	named_button("hole-slot-core_shell").pressed.emit();await frames(1)
	check(game.ui.toast=="Core Shell EQUIPPED","Owned Core Shell has a bounded acknowledgement")
	check(game.ui.preview_skin_id=="core_shell" and game.ui.skin_preview_ring.material_override!=null,"Card updates the preview material")
	game.owned_skin_ids=game.skin_ids("collection")
	game.ui.scroll_to_skin("cinder");await frames(2)
	named_button("hole-slot-cinder").pressed.emit();await frames(1)
	var cinder_preview:Color=(game.ui.skin_preview_void.material_override as StandardMaterial3D).albedo_color
	game.ui.scroll_to_skin("tide");await frames(2)
	named_button("hole-slot-tide").pressed.emit();await frames(1)
	var tide_preview:Color=(game.ui.skin_preview_void.material_override as StandardMaterial3D).albedo_color
	check(cinder_preview!=tide_preview and game.ui.preview_skin_id=="tide","Different cards retain different live materials")
	named_button("holes-home").pressed.emit()
	await frames(2)
	check(game.phase=="title" and game.ui.menu_screen=="home" and game.ui.map_carousel.visible and not game.ui.hero.visible,"HOME returns to the screenshot row without starting a round")
	# Thumbnails are one-shot and every visible touch target stays in portrait bounds.
	game.ui.open_holes();await frames(2)
	check(game.ui.skin_cards.size()==game.ui.visible_skin_ids().size() and game.ui.card_textures.size()==game.ui.skin_cards.size(),"All six visible cards contain an actual skin preview")
	for b in game.ui.buttons:
		check((b.has_meta("skin_id") or Rect2(0,0,540,960).encloses(b.get_rect())) and b.size.y>=44,"Touch target fits the portrait screen: "+b.name)
	game.select_skin("tide");game.start_level();game.begin_play();await frames(2)
	check(named_button("skin-action")==null and named_button("pulse-action")!=null,"Cosmetic skins keep boost and omit the inactive skill button")
	check(game.player.label.text=="LVL 1" and not game.player.meter.text.contains("SYNC"),"World labels use level and growth instead of technical labels")
	game.select_skin("shard");game.start_level();game.begin_play();await frames(2)
	check(named_button("skin-action")!=null,"Functional skins retain a real skill action")
	var result:={"checks":checks,"failures":failures,"collection_skins":game.ui.skin_order.size()}
	print("TITLE_NAVIGATION_ACCEPTANCE "+JSON.stringify(result))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--report="):
			var out:=FileAccess.open(arg.trim_prefix("--report="),FileAccess.WRITE)
			out.store_string(JSON.stringify(result,"\t")+"\n")
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
