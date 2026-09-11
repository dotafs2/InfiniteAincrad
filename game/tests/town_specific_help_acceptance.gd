extends "res://tests/town_trade_acceptance.gd"


func _initialize() -> void:
	run.call_deferred()

func _specific_option(town: TownTrade, sender: String, recipient: String, part: String) -> Dictionary:
	for option in town.trade_options(sender):
		var decision: Dictionary = option.get("_decision", {})
		var need: Dictionary = decision.get("need", {})
		if option.get("action") == "ask_help" and option.get("counterparty") == recipient and need.get("part") == part:
			return option
	return {}

func _reply_option(town: TownTrade, resident_id: String, request_id: String, choice: String) -> Dictionary:
	for option in town.trade_options(resident_id):
		if option.get("action") == "reply_help" and option.get("id") == "reply:" + request_id + ":" + choice:
			return option
	return {}

func run() -> void:
	var path := "user://fictional-town-specific-help-%d.json" % Time.get_ticks_usec()
	_write_fixture(path, trade_fixture())
	var town := TownTrade.new()
	check(town.load_from(path).ok, "specific-help fixture loads")
	var owner := "fictional:ember"
	var carpenter := "fictional:birch"
	var smith := "fictional:forge"
	var specific := _specific_option(town, owner, carpenter, "edge")
	check(not specific.is_empty(), "damaged axe offers a specific edge request beside generic help")
	var decision: Dictionary = specific.get("_decision", {})
	check(decision.get("text") == "Can you repair the edge of my axe?", "specific request uses factual public text")
	check(decision.get("need") == {"kind": "repair", "item_id": "fictional:axe-edge", "part": "edge"}, "specific request carries canonical repair need")
	var before := town.snapshot()
	var sent := town.transaction(path, func(): return town.submit_trade(owner, str(specific.id), "specific-edge", "opengameagent_fixture"))
	check(sent.ok, "specific request is delivered")
	check(town.snapshot().life.events[-1].need == decision.need, "persisted event contains the need")
	check(town.resident_view(carpenter).experiences[-1].text == decision.text, "recipient sees actual text")
	check(town.resident_view(carpenter).experiences[-1].need == decision.need, "recipient sees actual need")
	check(not town.resident_view(smith).experiences.any(func(e): return e.get("request_id") == sent.request_id), "third party learns nothing")
	check(town.snapshot().life.contracts == before.life.contracts and town.resident(owner).coins_col == before.residents[0].coins_col, "talk changes no contract or money")
	var duplicate := town.submit_trade(owner, str(specific.id), "specific-edge", "opengameagent_fixture")
	check(duplicate.duplicate and town.snapshot().life.events.size() == before.life.events.size() + 1, "duplicate command delivers exactly once")
	var refusal_option := _reply_option(town, carpenter, str(sent.request_id), "unavailable")
	check(not refusal_option.is_empty(), "specific ask preserves optional unavailable choice")
	check(str(refusal_option.get("_decision", {}).get("text", "")).contains("wooden handles; I cannot perform this repair"), "unavailable response states carpenter capability truthfully")
	var refusal := town.transaction(path, func(): return town.submit_trade(carpenter, str(refusal_option.id), "specific-refusal", "opengameagent_fixture"))
	check(refusal.ok and town.snapshot().life.events[-1].reply_choice == "unavailable", "capability refusal remains voluntary refusal")
	check(not town.snapshot().life.contracts.any(func(c): return c.get("item_id") == "fictional:axe-edge" and c.get("status") != "closed_old"), "refusal creates no contract")
	var generic := {"action": "ask_help", "recipient_id": carpenter, "text": "Can you help me?"}
	check(town.transaction(path, func(): return town.communicate(owner, generic, "generic-compatible", "opengameagent_fixture")).ok, "old generic message remains compatible")
	check(not town.communicate(owner, {"action": "ask_help", "recipient_id": carpenter, "text": "Can you repair it?", "need": {"kind": "repair", "item_id": "fictional:opaque", "part": "edge"}}, "forged-need", "opengameagent_fixture").ok, "forged ownership is rejected")
	check(not town.communicate(owner, {"action": "ask_help", "recipient_id": carpenter, "text": "Can you repair it?", "need": {"kind": "repair", "item_id": "fictional:axe-edge", "part": "bad"}}, "malformed-need", "opengameagent_fixture").ok, "malformed need is rejected")
	check(refusal_option.label.contains(refusal_option._decision.text), "model sees the exact public reply it is choosing")
	check(town.snapshot().life.accounts == before.life.accounts and town.snapshot().life.items == before.life.items, "talk does not spend material or repair tools")
	var frozen: Dictionary = town.snapshot()
	for invalid in [null, [], {}, {"kind": "repair", "item_id": 42, "part": "edge"}]:
		var bad := generic.duplicate(true)
		bad.need = invalid
		check(not town.communicate(owner, bad, "bad-input", "opengameagent_fixture").ok, "invalid need is rejected without exception")
	check(town.snapshot() == frozen, "invalid requests have no side effects")
	var bad_reply: Dictionary = refusal_option._decision.duplicate(true)
	bad_reply.need = decision.need
	check(not town.communicate(carpenter, bad_reply, "bad-reply", "opengameagent_fixture").ok, "reply cannot forge a new need")
	# Identical submission remains a duplicate even after its former need disappears.
	town._item("fictional:axe-edge").edge = 100
	check(town.communicate(owner, decision, "specific-edge", "opengameagent_fixture").get("duplicate", false), "repaired item does not invalidate an old command's duplicate receipt")
	town._item("fictional:axe-edge").edge = 20
	# Custody alone cannot authorize a request about somebody else's property.
	town._item("fictional:axe-edge").owner_id = smith
	check(not town.communicate(owner, decision, "not-owner", "opengameagent_fixture").ok, "custodian cannot claim another resident's item")
	town._item("fictional:axe-edge").owner_id = owner
	var base_town := Town.new()
	check(base_town.load_from(path).ok, "base life runtime loads compatible save")
	check(not base_town.communicate(owner, decision, "unsupported-base", "opengameagent_fixture").ok, "base runtime refuses unsupported specific needs")
	var bytes := FileAccess.get_file_as_bytes(path)
	town.release_writer(path)
	var restored := TownTrade.new()
	check(restored.load_from(path).ok, "cold load succeeds")
	check(FileAccess.get_file_as_bytes(path) == bytes, "cold load does not rewrite save")
	var restored_request: Array = restored.snapshot().life.events.filter(func(e): return e.get("request_id") == sent.request_id)
	check(restored_request.size() == 2 and restored_request[0].need == decision.need and restored_request[1].reply_choice == "unavailable", "need and refusal survive cold load")
	restored.release_writer(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print(JSON.stringify({"suite": "town_specific_help", "checks": checks, "failures": failures, "paid_calls": 0}))
	quit(0 if failures == 0 else 1)
