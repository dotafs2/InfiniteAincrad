extends SceneTree
## Graphical fault injection: same production scene/physics, explicitly no paid AI.
const Street = preload("res://scenes/town_street.tscn")
const Turns = preload("res://agents/town_turns.gd")
const Tests = preload("res://tests/town_online_acceptance.gd")
const FIRST := "fixture:innkeeper"
const SECOND := "fixture:smith"
const THIRD := "fixture:online-resident"
var scene: Node
var checks := 0
var failures := 0
var old_result: Dictionary = {}
var samples: Array = []

func _initialize() -> void:
	start.call_deferred()

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func collect_old() -> void:
	old_result = await scene.model_turns.step(THIRD)

func capture(name: String) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_root().get_texture().get_image().save_png(scene.capture_dir.path_join(name + ".png"))

func start() -> void:
	scene = Street.instantiate()
	root.add_child(scene)
	if scene.town._state.get("world_id") != "fixture:town-trade-validation" or scene.town.active_ids().size() != 2 or scene.capture_dir.is_empty():
		push_error("Requires explicit two-person fixture and capture directory")
		quit(2)
		return
	scene.scripted_trade = true
	scene.capture_seconds = 900
	scene.paused = false
	scene.model_turns = Turns.new()
	scene.add_child(scene.model_turns)
	scene.model_turns.town = scene.town
	scene.model_turns.save_path = scene._save_path
	# Both pre-existing people have actual outstanding world actions before admission.
	check(scene.town.transaction(scene._save_path, func(): return scene.town.start_action(FIRST, "eat_ration", "online-meal", "opengameagent_fixture")).ok, "existing meal started")
	check(scene.town.transaction(scene._save_path, func(): return scene.town.start_action(SECOND, "harvest_ration", "online-forage", "opengameagent_fixture")).ok, "existing walk/harvest started")
	var body_ids := [scene.bodies[FIRST].get_instance_id(), scene.bodies[SECOND].get_instance_id()]
	await create_timer(1).timeout
	await capture("two-residents")
	var newcomer := {"stable_id": THIRD, "name": "在线加入者", "role": "resident", "story": "我刚来到起始之城，想了解附近的生活。"}
	check(scene.admit_resident(newcomer, "maintainer:test", Vector3(1.8, 0.22, 7), "graphical-join").ok, "online admission accepted")
	check(scene.actors.size() == 3 and scene.bodies[THIRD].is_inside_tree(), "third actual Godot body created online")
	check(scene.admit_resident(newcomer, "maintainer:test", Vector3(1.8, 0.22, 7), "graphical-join").get("duplicate", false) and scene.actors.size() == 3, "duplicate join no duplicate body")
	var brain := Tests.DelayedBrain.new(); brain.delay = 3.0; brain.fail = true
	check(scene.model_turns.connect_controller(THIRD, brain, "fault:test").ok, "third controller connected")
	scene.gateway_mode = true
	var before: Vector3 = scene.town.position_of(SECOND)
	var seconds: float = scene.town._state.godot.elapsed_seconds
	scene.latest = "第三人在线加入；AI 故意等待 3 秒，原居民继续进食和采集。"
	scene._refresh()
	await create_timer(1.5).timeout
	check(scene.model_turns.busy and not scene.paused, "world unpaused while AI outstanding")
	check(scene.town._state.godot.elapsed_seconds > seconds + 0.5 and scene.town.position_of(SECOND).distance_to(before) > 0.2, "time and physical movement continue")
	samples.append({"phase": "waiting", "elapsed_seconds": scene.town._state.godot.elapsed_seconds, "actor_count": scene.actors.size(), "moving_distance": scene.town.position_of(SECOND).distance_to(before), "paused": scene.paused})
	await capture("three-residents-waiting")
	await create_timer(2).timeout
	check(scene.model_turns._record(THIRD).get("status") == "provider_error" and not scene.paused and brain.calls == 1, "timeout only affects third controller; no retry storm")
	var epoch: int = scene.model_turns._record(THIRD).controller_epoch
	check(scene.model_turns.disconnect_controller(THIRD, "fault:test", epoch).ok, "disconnect does not remove character")
	var delayed := Tests.DelayedBrain.new(); delayed.delay = 2.0
	check(scene.model_turns.connect_controller(THIRD, delayed, "fault:old").ok, "old connection starts")
	collect_old()
	var replacement := Tests.DelayedBrain.new()
	check(scene.model_turns.connect_controller(THIRD, replacement, "fault:new").ok, "replacement connected during outstanding old request")
	await create_timer(2.3).timeout
	check(old_result.get("code") == "stale_controller_reply", "old reply fenced in actual scene")
	check(scene.model_turns._record(THIRD).status == "settled" and not scene.paused, "new connection continues same person")
	check(scene.bodies[FIRST].get_instance_id() == body_ids[0] and scene.bodies[SECOND].get_instance_id() == body_ids[1], "existing actors never rebuilt")
	check(scene.town.resident(THIRD).story == newcomer.story and scene.town.active_ids().size() == 3, "newcomer identity stays")
	# Continue the already-started actions to their real duration, still at 1x time.
	await create_timer(26).timeout
	check(scene.town.account(FIRST).food == 0 and scene.town.pending_job(FIRST).is_empty(), "first resident completed meal")
	check(scene.town.account(SECOND).food == 2 and scene.town.pending_job(SECOND).is_empty(), "second resident completed walking and harvesting")
	scene.latest = "在线加入、超时、断线、重连完成；原居民进食和采集已完成。"
	scene.dialogue.text = "故障注入验收 · 未调用 Kimi\n旧连接回复被拒绝，人物身份和世界连续保存。"
	scene._refresh()
	await capture("online-complete")
	var evidence := {"suite": "town_online_scene", "checks": checks, "failures": failures, "paid_calls": 0, "provenance": "fault_injection_fixture", "samples": samples, "world_id": scene.town._state.world_id, "elapsed_seconds": scene.town._state.godot.elapsed_seconds, "initial_actor_count": 2, "final_actor_count": scene.actors.size(), "existing_bodies_preserved": true}
	var output := FileAccess.open(scene.capture_dir.path_join("online.json"), FileAccess.WRITE)
	output.store_string(JSON.stringify(evidence, "  ")); output.close()
	print(JSON.stringify(evidence))
	quit(0 if failures == 0 else 1)
