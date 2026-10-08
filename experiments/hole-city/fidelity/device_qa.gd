extends Node
## Opt-in bridge for the browser recorder. Headless timings never enter it.
var game:Node3D
var elapsed:=0.0
var previous_phase:=""
var previous_pause:=false
func _process(delta:float)->void:
	if not OS.has_feature("web"):set_process(false);return
	elapsed+=delta
	var paused:=get_tree().paused
	if elapsed<.5 and previous_phase==game.phase and previous_pause==paused:return
	elapsed=0.0;previous_phase=game.phase;previous_pause=paused
	var context:={"map":game.selected_map,"phase":game.phase,"paused":paused,"seconds":game.elapsed,"score":0,"radius":0.0,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}
	if is_instance_valid(game.player):context.score=game.player.score;context.radius=game.player.radius
	if game.selected_map=="food":context.city_goals=game.food_city_progress()
	JavaScriptBridge.eval("window.SinkDeviceQA && window.SinkDeviceQA.state("+JSON.stringify(context)+");")
