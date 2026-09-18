extends "res://tests/town_trade_acceptance.gd"
## Read-only UI boundary for the optional external GM completion snapshot. No provider.

class GmStatusScene extends "res://spatial/town_street.gd":
	func _ready() -> void: pass
	func _process(_delta: float) -> void: pass
	func _physics_process(_delta: float) -> void: pass
	func _refresh() -> void: pass

func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	return event

func _status(world_id: String) -> Dictionary:
	var rows: Array = []
	for index in 10:
		rows.append({
			"id": "gm-%02d" % (index + 1),
			"focus_label": "职责 %02d" % (index + 1),
			"status": "方案评审完成" if index == 6 else "观察完成",
			"last_completed_utc": "2026-09-17T20:%02d:00Z" % index,
			"last_source_seq": 214 + index,
			"last_public_outcome": ("很长的公开结果".repeat(12)) if index == 0 else "真实完成记录 %02d" % (index + 1),
		})
	return {"schema_version": 1, "world_id": world_id,
		"generated_utc": "2026-09-17T20:30:00Z", "rows": rows}

func _write_text(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()

func run() -> void:
	var save_path := "user://gm-status-world-%d.json" % Time.get_ticks_usec()
	var status_path := "user://gm-status-public-%d.json" % Time.get_ticks_usec()
	_write_fixture(save_path, trade_fixture())
	var scene := GmStatusScene.new()
	root.add_child(scene)
	check(scene.town.load_from(save_path).ok, "GM status fixture world loads")
	scene._save_path = save_path
	scene._player = CharacterBody3D.new()
	scene.add_child(scene._player)
	scene._build_town_hud()
	var world_before: Dictionary = scene.town.snapshot()
	var bytes_before := FileAccess.get_file_as_bytes(save_path)

	check(not scene.gm_panel.visible, "GM panel is closed by default")
	scene.gm_status_path = ""
	scene._reload_gm_status()
	check(scene.gm_status_rows.is_empty() and scene.gm_status_header.text.contains("未载入"),
		"missing optional path states that no record is loaded")

	var valid := _status(str(world_before.world_id))
	_write_text(status_path, JSON.stringify(valid))
	scene.gm_status_path = status_path
	scene._unhandled_input(_key(KEY_G))
	check(scene.gm_panel.visible and not scene.life_panel.visible, "G swaps the same right-side footprint to GM progress")
	check(scene.gm_status_rows.size() == 10, "exactly ten real completion rows are rendered")
	check(scene.gm_status_label.text.contains("gm-07 · 职责 07 · 方案评审完成"), "review-complete status is displayed without inventing running state")
	check(not scene.gm_status_label.text.contains("很长的公开结果".repeat(12)), "long public outcome is truncated")
	valid.rows[0].status = "结果未知"
	valid.rows[0].last_public_outcome = "已发送后超时；未重试，费用未知。"
	_write_text(status_path, JSON.stringify(valid))
	scene._reload_gm_status()
	check(scene.gm_status_rows.size() == 10 and scene.gm_status_label.text.contains("gm-01 · 职责 01 · 结果未知"),
		"an unknown provider outcome stays visible without being labelled complete")
	scene._unhandled_input(_key(KEY_G))
	check(not scene.gm_panel.visible and scene.life_panel.visible, "G returns to the prior life panel")

	_write_text(status_path, "{bad json")
	scene._reload_gm_status()
	check(scene.gm_status_rows.is_empty() and scene.gm_status_header.text.contains("未载入"), "bad JSON fails closed as not loaded")
	var wrong_world := _status("another-world")
	_write_text(status_path, JSON.stringify(wrong_world))
	scene._reload_gm_status()
	check(scene.gm_status_rows.is_empty() and scene.gm_status_header.text.contains("世界不匹配"), "world mismatch fails closed as not loaded")
	var fake_running := _status(str(world_before.world_id))
	fake_running.rows[0].status = "running"
	_write_text(status_path, JSON.stringify(fake_running))
	scene._reload_gm_status()
	check(scene.gm_status_rows.is_empty(), "unreviewed running claim is rejected")

	check(scene.town.snapshot() == world_before, "GM panel never mutates the in-memory world")
	check(FileAccess.get_file_as_bytes(save_path) == bytes_before, "GM panel preserves exact world save bytes")
	print(JSON.stringify({"suite": "town_gm_status_ui", "checks": checks, "failures": failures,
		"paid_calls": 0, "rows": 10, "world_save_byte_equal": FileAccess.get_file_as_bytes(save_path) == bytes_before}))
	scene.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(status_path))
	quit(0 if failures == 0 else 1)
