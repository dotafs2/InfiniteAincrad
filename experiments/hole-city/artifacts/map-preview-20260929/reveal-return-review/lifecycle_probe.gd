extends SceneTree
## Non-author lifecycle probe. Game._process remains naturally enabled throughout.
var game:Node3D
var checks:=0
var failures:Array[String]=[]
var observations:Array=[]
func _initialize()->void:run.call_deferred()
func check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func frames(count:int)->void:
	for i in count:await process_frame
func run()->void:
	if not OS.get_cmdline_user_args().has("--test"):quit(2);return
	game=load("res://fidelity/main.tscn").instantiate();root.add_child(game)
	await frames(4)
	check(game.phase=="title" and game.is_processing(),"Cold home runs the natural game process")
	check(game.reveal.target.w==0 and game.reveal.strength==0,"Cold home has no stale reveal aperture")
	for map_id in ["city","food"]:
		game.select_map(map_id);game.start_level()
		await frames(20)
		check(game.phase=="intro" and game.is_processing(),map_id+": intro keeps natural game updates enabled")
		check(game.reveal.update_count>0 and game.reveal.strength>.8,map_id+": live intro still advances the reveal controller")
		check(not game.reveal.occluders.is_empty(),map_id+": actual architecture remains registered")
		game.begin_play()
		for hole in game.holes:hole.enabled=false
		var prior:int=game.reveal.update_count
		await frames(20)
		check(game.phase=="playing" and game.is_processing(),map_id+": gameplay retains natural processing")
		check(game.reveal.update_count>prior and game.reveal.target.w>.9,map_id+": active gameplay continues publishing the aperture")
		game.toggle_pause()
		var paused_updates:int=game.reveal.update_count
		var paused_target:Vector4=game.reveal.target
		await frames(12)
		check(paused and game.is_processing(),map_id+": pause uses tree lifecycle without disabling the game process flag")
		check(game.reveal.update_count==paused_updates and game.reveal.target==paused_target,map_id+": pause preserves the existing reveal backdrop")
		game.toggle_pause();await frames(12)
		check(not paused and game.reveal.update_count>paused_updates,map_id+": resume naturally advances reveal again")
		var retired_player:WeakRef=weakref(game.player)
		if map_id=="city":
			game.finish("timeout");await frames(12)
			check(game.phase=="timeout" and game.is_processing(),"Results retain natural game processing")
			check(game.reveal.target.w==0 and game.reveal.strength==0,"Results clear the active aperture")
		else:game.toggle_pause()
		game.back_home()
		var animation_before:float=game.ui.animation
		await frames(30)
		check(game.phase=="title" and not paused and game.is_processing(),map_id+": return home continues natural unpaused updates")
		check(retired_player.get_ref()==null and not is_instance_valid(game.player),map_id+": old player really is freed while its stale field remains safe")
		check(not is_instance_valid(game.world) and game.holes.is_empty(),map_id+": old gameplay world is released")
		check(game.reveal.target.w==0 and game.reveal.strength==0 and game.reveal.active_occluders==0,map_id+": home has no active dither state")
		check(game.ui.animation>animation_before and game.ui.hero_models.is_processing(),map_id+": home animation continues during the stale-reference observation window")
		observations.append({"map":map_id,"returned_from":"results" if map_id=="city" else "pause","home_frames":30,"player_freed":retired_player.get_ref()==null,"game_processing":game.is_processing(),"reveal_strength":game.reveal.strength,"ui_animation_delta":game.ui.animation-animation_before})
	print("REVEAL_RETURN_REVIEW "+JSON.stringify({"checks":checks,"failures":failures,"observations":observations,"scope":"Natural game/menu lifecycle without disabling Game._process; active geometry/material behavior additionally checked by the unmodified selective-reveal suite. No renderer or device-performance claim."}))
	game.free();await process_frame;quit(0 if failures.is_empty() else 1)
