extends "res://tests/town_trade_acceptance.gd"

class DialogueScene extends "res://spatial/town_street.gd":
	func _ready() -> void:
		pass
	func _process(_delta: float) -> void:
		pass
	func _physics_process(_delta: float) -> void:
		pass

func run() -> void:
	var path := "user://dialogue-ui-%d.json" % Time.get_ticks_usec()
	_write_fixture(path, trade_fixture())
	var scene := DialogueScene.new()
	root.add_child(scene)
	check(scene.town.load_from(path).ok, "dialogue scene loads preserved fixture")
	scene._save_path = path
	scene.gateway_mode = true # No controller attached: UI must not invent a reply.
	scene._player = CharacterBody3D.new()
	scene.add_child(scene._player)
	scene._player.position = Vector3.ZERO
	scene.town.host_visitor_position(Vector3.ZERO)
	scene._build_town_hud()
	scene.paused = false
	scene._open_dialogue()
	check(scene._composing_dialogue() and not scene.paused, "composer opens without pausing world")
	check(scene.dialogue_target == "fictional:ember", "conversation binds nearby recipient")
	var before: Dictionary = scene.town.snapshot()
	scene._submit_dialogue("  ")
	check(scene.town.snapshot() == before, "empty text does not create an event")
	scene._submit_dialogue("你希望什么时候收到报酬？")
	var inquiry: Dictionary = scene.town.snapshot().life.events[-1]
	check(inquiry.type == "visitor_inquiry" and inquiry.text == "你希望什么时候收到报酬？" and inquiry.source == "human_player", "typed words go through real human visitor command path")
	check(not scene._composing_dialogue() and not scene.paused, "successful send closes only composer")
	check(scene.town.resident_view("fictional:birch").experiences.is_empty(), "unaddressed resident does not gain player's words")
	var reply := scene.town.transaction(path, func(): return scene.town.reply_to_visitor("fictional:ember", inquiry.request_id, "unsure", "我担心结算时间。", "ui-reply", "opengameagent_fixture"))
	check(reply.ok, "fixture speaker replies through authoritative event")
	scene._refresh_public_dialogue(scene.town.snapshot().life.events)
	check(scene.dialogue.text.contains("我担心结算时间。"), "scene displays actual public statement")
	var visible := scene.dialogue.text
	scene._refresh_public_dialogue([{"seq": 999, "type": "reply_help", "recipient_ids": ["fictional:birch"], "text": "PRIVATE_OTHER_CONVERSATION"}, {"seq": 1000, "type": "accepted_reply", "reason": "PRIVATE_REASON_SENTINEL"}])
	check(scene.dialogue.text == visible, "private deliberation and other conversations cannot replace player's dialogue")
	scene.last_inquiry_seconds = -10.0
	scene._open_dialogue()
	scene.dialogue_input.text = "请再解释一下。"
	scene._player.position = Vector3(100, 0, 0)
	scene.town.host_visitor_position(scene._player.position)
	before = scene.town.snapshot()
	scene._submit_dialogue(scene.dialogue_input.text)
	check(scene.town.snapshot() == before and scene._composing_dialogue(), "moving out of hearing range prevents send without losing draft")
	check(scene.dialogue_input.text == "请再解释一下。", "failed send preserves exact draft")
	scene._close_dialogue()
	check(not scene.paused and scene.town.snapshot() == before, "cancelling composer has no world effect")
	var restored := TownTrade.new()
	check(restored.load_from(path).ok and restored.snapshot().life.events == scene.town.snapshot().life.events, "typed interaction and public reply survive cold restore")
	scene.town.release_writer(path)
	scene.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	await process_frame
	print(JSON.stringify({"suite": "town_dialogue_ui", "checks": checks, "failures": failures, "paid_calls": 0, "input": "direct UI callbacks, no hardware input"}))
	quit(0 if failures == 0 else 1)
