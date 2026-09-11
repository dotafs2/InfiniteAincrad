extends SceneTree
## Scripted graphical acceptance, not model decisions or the original world.
const TownScene = preload("res://scenes/town_street.tscn")
var scene: Node
var stage := 0
var elapsed := 0.0
var completed := false
var stages: Array = []
const OWNER := "fixture:innkeeper"
const SMITH := "fixture:smith"
const CARPENTER := "fixture:carpenter"

func _initialize() -> void:
	start.call_deferred()

func start() -> void:
	scene = TownScene.instantiate()
	root.add_child(scene)
	if scene.town._state.get("world_id") != "fixture:town-trade-validation":
		push_error("Graphical script requires the explicitly fictional trade fixture")
		quit(2)
		return
	scene.scripted_trade = true
	scene.paused = false
	scene.capture_seconds = 900
	Engine.time_scale = 6.0
	stages = [[OWNER, "ask_help", "", SMITH], [SMITH, "reply_help", "", OWNER],
		[OWNER, "offer_repair", "edge", SMITH], [SMITH, "accept", "", ""],
		[OWNER, "deliver", "", ""], [SMITH, "work", "edge", ""], [OWNER, "collect", "", ""],
		[OWNER, "offer_repair", "handle", CARPENTER], [CARPENTER, "accept", "", ""],
		[OWNER, "deliver", "", ""], [CARPENTER, "work", "handle", ""], [OWNER, "collect", "", ""],
		[OWNER, "use_tool", "", ""]]

func _process(delta: float) -> bool:
	if scene == null or stages.is_empty() or completed:
		return false
	elapsed += delta
	if elapsed > 750:
		push_error("Graphical trade fixture stalled at stage " + str(stage))
		quit(1)
		return false
	for id in scene.town.active_ids():
		if not scene.town.pending_job(id).is_empty():
			return false
	if stage == stages.size():
		completed = true
		var state: Dictionary = scene.town.snapshot()
		var item: Dictionary = state.life.items[0]
		var passed: bool = item.edge == 100 and item.handle == 100 and item.custodian_id == OWNER and scene.town._trade_account(OWNER).kindling == 1
		if not passed:
			push_error("Graphical trade effects mismatch")
			quit(1)
			return false
		scene.latest = "两次修理已结算；同一把斧头已将 1 木料加工成柴火。"
		scene.dialogue.text = "脚本化图形验收：13 个步骤完成\n动作、碰撞、施工、交付和结算在 Godot 中执行；本次没有调用模型。"
		print(JSON.stringify({"suite": "town_trade_scene", "passed": true, "steps": stage, "world_id": state.world_id, "provenance": "scripted_test", "paid_calls": 0}))
		scene._capture_town()
		return false
	var step: Array = stages[stage]
	for option in scene.town.trade_options(step[0]):
		if option.action != step[1] or (step[2] != "" and option.get("_part") != step[2]) or (step[3] != "" and option.get("counterparty") != step[3]):
			continue
		if option.action == "reply_help" and option._decision.choice != "willing":
			continue
		if option.action == "offer_repair" and option._price != 2:
			continue
		var applied: Dictionary = scene.town.transaction(scene._save_path, func():
			return scene.town.submit_trade(step[0], option.id, "scripted-scene-%d" % stage, "local_rule_policy"))
		if not applied.ok:
			push_error(JSON.stringify(applied))
			quit(1)
			return false
		scene.latest = scene.town.resident(step[0]).name + " · " + option.label
		stage += 1
		break
	return false
