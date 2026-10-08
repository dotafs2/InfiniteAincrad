extends SceneTree
## Audit fixture only. Manual result setup is not a human playthrough.
func _initialize()->void:run.call_deferred()
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	var game:Node3D=load("res://fidelity/main.tscn").instantiate();root.add_child(game)
	await process_frame
	var result:={"version":ProjectSettings.get_setting("application/config/version"),"scope":"Headless fixture; no player save; manually seeded completion", "progress_file":game.progress_file()}
	if game.progress_file()!="":game.free();quit(2);return
	game.owned_skin_ids.append("shard");game.select_skin("shard")
	game.ui.open_holes()
	result.equipped_id=game.selected_skin_id
	result.opened_tab=game.ui.holes_tab
	result.visible_ids=game.ui.tab_skin_ids()
	result.equipped_visible=game.ui.tab_skin_ids().has(game.selected_skin_id)
	result.card_update_modes=game.ui.skin_cards.map(func(v):return v.render_target_update_mode)
	result.large_preview_visible=game.ui.skin_texture.visible
	game.stage=4;game.start_level();game.begin_play();game.player.score=420;game.finish("complete")
	result.phase_after_complete=game.phase
	result.stage_after_complete=game.stage
	result.coins_awarded=game.round_coins
	game.back_home();game.start_level()
	result.stage_after_next_round=game.stage
	result.next_round_seconds=game.remaining
	FileAccess.open("res://artifacts/reference-audit-20260928/ui/probe.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t")+"\n")
	print("UI_REFERENCE_AUDIT "+JSON.stringify(result))
	game.free();await process_frame;quit()
