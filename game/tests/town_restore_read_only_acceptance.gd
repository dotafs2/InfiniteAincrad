extends "res://tests/town_trade_acceptance.gd"
## Focused input-boundary regression for --town-restore. No provider is attached.

class FakeHouse extends Node3D:
	var door_open := false
	var window_open := false
	func is_door_open() -> bool: return door_open
	func set_door_open(value: bool) -> void: door_open = value
	func is_window_open() -> bool: return window_open
	func set_window_open(value: bool) -> void: window_open = value

class FakeQuarter extends Node3D:
	var houses: Dictionary = {}
	var entrances: Dictionary = {}

class ReadOnlyScene extends "res://spatial/living_town.gd":
	func _ready() -> void: pass
	func _process(_delta: float) -> void: pass
	func _physics_process(_delta: float) -> void: pass
	func _refresh() -> void: pass

func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event

func _visitor_events(events: Array) -> int:
	var total := 0
	for event in events:
		if str(event.get("type", "")) in ["visitor_inquiry", "visitor_reply"]:
			total += 1
	return total

func run() -> void:
	var path := "user://restore-read-only-%d.json" % Time.get_ticks_usec()
	_write_fixture(path, trade_fixture())
	var before_bytes := FileAccess.get_file_as_bytes(path)
	var scene := ReadOnlyScene.new()
	root.add_child(scene)
	check(scene.town.load_from(path).ok, "restore fixture loads")
	scene._save_path = path
	scene.restore_only = true
	scene.paused = true
	scene._player = CharacterBody3D.new()
	scene.add_child(scene._player)
	scene._build_town_hud()
	var quarter := FakeQuarter.new()
	scene.add_child(quarter)
	scene.quarter = quarter
	var house := FakeHouse.new()
	quarter.add_child(house)
	quarter.houses["fixture:innkeeper"] = house
	quarter.entrances["fixture:innkeeper"] = Vector3.ZERO
	scene._player.position = Vector3.ZERO
	var before := scene.town.snapshot()
	var event_count := _visitor_events(before.life.events)
	var command_count := scene.town.command_count()

	scene._unhandled_input(_key(KEY_SPACE))
	check(scene.paused, "Space cannot unpause restore-only life")
	scene._unhandled_input(_key(KEY_H))
	check(not scene._composing_dialogue(), "H cannot open a restore-only composer")
	check(scene.dialogue.text.contains("只读回看"), "H explains how to enable real AI conversation")
	check(not scene._inquire_nearby(false, "不应写入", "fixture:innkeeper"), "direct inquiry also fails closed in restore-only")
	scene._unhandled_input(_key(KEY_E))
	scene._unhandled_input(_key(KEY_F))
	check(not house.is_door_open() and not house.is_window_open(), "E/F do not even claim a door/window change in restore-only")

	var after := scene.town.snapshot()
	check(after == before, "Space/H/E/F leave the in-memory world byte-equivalent")
	check(scene.town.command_count() == command_count, "restore-only inputs create zero decisions or commands")
	check(_visitor_events(after.life.events) == event_count, "restore-only inputs create zero scripted inquiries or replies")
	check(FileAccess.get_file_as_bytes(path) == before_bytes, "restore-only inputs preserve exact save bytes")
	print(JSON.stringify({"suite": "town_restore_read_only", "checks": checks, "failures": failures,
		"paid_calls": 0, "inputs": ["Space", "H", "E", "F"], "world_save_byte_equal": FileAccess.get_file_as_bytes(path) == before_bytes}))
	scene.queue_free()
	DirAccess.remove_absolute(path)
	quit(0 if failures == 0 else 1)
