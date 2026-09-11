extends "res://tests/town_life_acceptance.gd"

func run() -> void:
	var path := "user://town-social-%d.json" % Time.get_ticks_usec()
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(fixture(), "", true, true))
	file.close()
	var town := Town.new()
	check(town.load_from(path).ok, "social fixture load")
	town.host_move("fixture:c", Vector3(8, 0, 0))
	var request := {"action": "ask_help", "recipient_id": "fixture:b", "text": "我听说树丛还有一百份浆果，你愿意帮我看看吗？"}
	var original_inventory := town.account("fixture:a").duplicate(true)
	var sent := town.transaction(path, func(): return town.communicate("fixture:a", request, "ask-1"))
	check(sent.ok, "nearby request sent")
	check(town.account("fixture:a") == original_inventory and town.snapshot().foraging.stock == 1, "speech cannot create claimed berries")
	check(town.resident_view("fixture:b").experiences.size() == 1, "recipient learns attributed claim")
	check(town.resident_view("fixture:c").experiences.is_empty(), "bystander receives nothing")
	check(town.resident_view("fixture:a").nearby_residents.size() == 1, "view excludes distant identity")
	var prior := town.snapshot()
	check(town.communicate("fixture:a", request, "ask-1").duplicate, "send idempotent")
	check(town.snapshot() == prior, "no duplicate delivery")
	request.text = "Different content"
	check(not town.communicate("fixture:a", request, "ask-1").ok, "id conflict rejected")
	request.recipient_id = "fixture:c"
	check(town.communicate("fixture:a", request, "out-of-range").code == "recipient_out_of_range", "host range boundary")
	request.recipient_id = "fixture:b"
	request.position = [8, 0, 0]
	check(not town.communicate("fixture:a", request, "fake-position").ok, "model supplied coordinates rejected")
	request.erase("position")
	request.text = "x".repeat(513)
	check(not town.communicate("fixture:a", request, "too-long").ok, "oversized text rejected")
	var reply := {"action": "reply_help", "recipient_id": "fixture:a", "text": "我现在不方便。", "request_id": sent.request_id, "choice": "unavailable"}
	check(not town.communicate("fixture:c", reply, "wrong-replier").ok, "third party cannot answer")
	check(town.transaction(path, func(): return town.communicate("fixture:b", reply, "reply-1")).ok, "resident can refuse")
	check(not town.communicate("fixture:b", reply, "reply-2").ok, "closed question cannot be answered twice")
	check(town.resident_view("fixture:a").experiences[-1].reply_choice == "unavailable", "sender receives refusal")
	check(town.resident_view("fixture:a").experiences[-1].contractual == false, "reply creates no contract")
	var before := FileAccess.get_file_as_bytes(path)
	var restored := Town.new()
	check(restored.load_from(path).ok, "social cold load")
	check(FileAccess.get_file_as_bytes(path) == before, "cold load does not rewrite")
	check(restored.resident_view("fixture:b").experiences.size() == 2, "no cold redelivery")
	check(restored.communicate("fixture:b", reply, "reply-1").duplicate, "reply receipt survives restart")
	request.text = "稍后能帮忙吗？"
	check(town.communicate("fixture:a", request, "ask-2").ok, "new distinct question allowed")
	var cancellation := {"action": "cancel_help", "recipient_id": "fixture:b", "request_id": "godot_help:ask-2", "text": "事情已处理，取消询问。"}
	check(town.communicate("fixture:a", cancellation, "cancel-2").ok, "sender can cancel")
	reply.request_id = "godot_help:ask-2"
	check(not town.communicate("fixture:b", reply, "reply-after-cancel").ok, "cancelled question stays closed")
	town.release_writer(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print(JSON.stringify({"suite": "town_social", "checks": checks, "failures": failures, "paid_calls": 0}))
	quit(0 if failures == 0 else 1)
