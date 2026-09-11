extends "res://core/town_life.gd"
## Bounded axe repair and tool-use continuation for the schema-2 town fixture.
## Legacy arrays remain authoritative; godot.trade only records new command/job state.

const SPEECH_ACTIONS := ["visitor_reply", "ask_help", "reply_help", "cancel_help", "offer_repair", "accept", "reject", "cancel", "share_skill"]
const SHAREABLE_SKILLS := ["wood_repair", "metal_repair"]
const SKILL_NOTICE_TEXT := {
	"wood_repair": "I can repair wooden handles.",
	"metal_repair": "I can repair metal edges.",
}
const TRADE_RANGE := 3.0
const REPAIR_SECONDS := 60.0
const WALK_SECONDS := 1.0
const TRADE_ACTIONS := [
	"walk", "approach", "offer_repair", "accept", "reject", "cancel", "deliver", "work", "collect", "use_tool"
]
const COMPLETION_ESCROW_ID := "repair_completion_escrow"
const COMPLETION_ESCROW_VERSION := "v1"
const COMPLETION_ESCROW_MANIFEST := "res://capabilities/repair_completion_escrow.v1.json"
const HOST_REVIEWER_PREFIX := "development_gm:"

func load_from(path: String) -> Dictionary:
	return super.load_from(path)

func _trade() -> Dictionary:
	var value: Variant = _state.godot.get("trade", {})
	return value if value is Dictionary else {}

func _ensure_trade() -> Dictionary:
	if not _state.godot.get("trade") is Dictionary:
		_state.godot.trade = {}
	var trade: Dictionary = _state.godot.trade
	if not trade.get("jobs") is Dictionary:
		trade.jobs = {}
	if not trade.get("commands") is Dictionary:
		trade.commands = {}
	return trade

func _life_trade() -> Dictionary:
	return _trade()

func _ensure_life_trade() -> Dictionary:
	var trade := _ensure_trade()
	if not trade.get("capabilities") is Dictionary:
		trade.capabilities = {}
	if not trade.get("receipts") is Dictionary:
		trade.receipts = {}
	return trade

func _completion_escrow_record() -> Dictionary:
	var trade := _life_trade()
	var capabilities: Variant = trade.get("capabilities", {})
	if capabilities is Dictionary and capabilities.get(COMPLETION_ESCROW_ID) is Dictionary:
		return capabilities[COMPLETION_ESCROW_ID]
	return {}

func _completion_escrow_enabled() -> bool:
	return _completion_escrow_record().get("status") == "enabled" and _completion_escrow_record().get("version") == COMPLETION_ESCROW_VERSION

func _contract_settlement(contract: Dictionary) -> String:
	return str(contract.get("settlement", "collection"))

func _load_completion_manifest() -> Variant:
	var file := FileAccess.open(COMPLETION_ESCROW_MANIFEST, FileAccess.READ)
	if file == null:
		return null
	return JSON.parse_string(file.get_as_text())

func _validate_completion_manifest(manifest: Variant) -> Dictionary:
	if not manifest is Dictionary or not _exact_keys(manifest, ["id", "version", "kind", "description", "supported_event_types", "variants"]):
		return _failure("malformed_completion_module")
	if manifest.get("id") != COMPLETION_ESCROW_ID or manifest.get("version") != COMPLETION_ESCROW_VERSION or manifest.get("kind") != "trade_settlement" or not manifest.get("description") is String or manifest.description.strip_edges().is_empty():
		return _failure("malformed_completion_module")
	var event_types: Variant = manifest.get("supported_event_types")
	if not event_types is Array or event_types.size() != 2 or not event_types.has("visitor_reply") or not event_types.has("reply_help"):
		return _failure("malformed_completion_module")
	var variants: Variant = manifest.get("variants")
	if not variants is Array or variants.size() != 3:
		return _failure("malformed_completion_module")
	var expected_prices := [2, 5, 8]
	for index in range(3):
		var variant: Variant = variants[index]
		if not variant is Dictionary or not _exact_keys(variant, ["id", "price_col", "settlement"]) or variant.get("id") != "repair_completion_%d" % expected_prices[index] or variant.get("price_col") != expected_prices[index] or variant.get("settlement") != "completion":
			return _failure("malformed_completion_module")
	return {"ok": true, "code": "completion_module_valid"}

func install_completion_escrow(source_seq: int, command_id: String) -> Dictionary:
	if not _validate_decision_command_id(command_id).ok or not command_id.begins_with(HOST_REVIEWER_PREFIX):
		return _failure("development_gm_required")
	var payload := {"action": "install_completion_escrow", "source_seq": source_seq, "reviewer": "development_gm", "module_id": COMPLETION_ESCROW_ID, "module_version": COMPLETION_ESCROW_VERSION}
	var existing_trade := _life_trade()
	var existing_receipts: Variant = existing_trade.get("receipts", {})
	if existing_receipts is Dictionary and existing_receipts.has(command_id):
		var prior: Dictionary = existing_receipts[command_id]
		var same: bool = prior.get("payload") == payload
		if same:
			var duplicate: Dictionary = prior.get("result", {}).duplicate(true)
			duplicate["duplicate"] = true
			return duplicate
		return _failure("command_conflict")
	var manifest: Variant = _load_completion_manifest()
	var manifest_valid := _validate_completion_manifest(manifest)
	if not manifest_valid.ok:
		return manifest_valid
	if source_seq < 1:
		return _failure("source_need_missing")
	var source_event: Dictionary = {}
	for event in _state.life.events:
		if event is Dictionary and event.get("seq") == source_seq:
			source_event = event
			break
	if source_event.is_empty() or source_event.get("type") not in ["visitor_reply", "reply_help"]:
		return _failure("source_need_missing")
	var source_text := str(source_event.get("text", ""))
	var source_actor := str(source_event.get("actor_id", ""))
	if source_text.strip_edges().is_empty() or source_actor not in active_ids() or not source_event.get("recipient_ids") is Array or source_event.recipient_ids.is_empty():
		return _failure("source_need_missing")
	if not _completion_escrow_record().is_empty():
		return _failure("capability_conflict")
	var life_trade := _ensure_life_trade()
	var capability := {"status": "enabled", "id": COMPLETION_ESCROW_ID, "version": COMPLETION_ESCROW_VERSION,
		"reviewer": "development_gm", "source": {"seq": source_seq, "actor_id": source_actor, "text": source_text}}
	life_trade.capabilities[COMPLETION_ESCROW_ID] = capability
	_append_life_event({"type": "capability_installed", "actor_id": "development_gm", "subject_id": source_actor, "recipient_ids": [],
		"operation_id": command_id, "source": "development_gm", "provenance": "development_gm_review",
		"audit_kind": "development_install", "capability_id": COMPLETION_ESCROW_ID, "version": COMPLETION_ESCROW_VERSION,
		"source_seq": source_seq, "source_actor": source_actor, "evidence_text": source_text, "contractual": false})
	var result := {"ok": true, "code": "completion_escrow_installed", "capability_id": COMPLETION_ESCROW_ID, "version": COMPLETION_ESCROW_VERSION, "reviewer": "development_gm", "source_seq": source_seq, "source_actor": source_actor}
	life_trade.receipts[command_id] = {"payload": payload, "result": result.duplicate(true)}
	return result

func _legacy_array(name: String) -> Array:
	var life: Variant = _state.get("life", {})
	if life is Dictionary and life.get(name) is Array:
		return life[name]
	return []

func _legacy_record(name: String, key: String, value: String) -> Dictionary:
	for record in _legacy_array(name):
		if record is Dictionary and record.get(key) == value:
			return record
	return {}

func _trade_account(id: String) -> Dictionary:
	var record := _legacy_record("accounts", "resident_id", id)
	if record.is_empty():
		return {}
	return record

func _item(item_id: String) -> Dictionary:
	return _legacy_record("items", "id", item_id)

func _skill_ids(id: String) -> Array:
	var result: Array = []
	for skill in _legacy_array("skills"):
		if skill is Dictionary and skill.get("resident_id") == id and skill.get("skill_id") is String:
			result.append(skill.skill_id)
	return result

func _public_skills(observer_id: String, resident_id: String) -> Array:
	if observer_id == resident_id or observer_id not in active_ids() or resident_id not in active_ids():
		return []
	if position_of(observer_id).distance_to(position_of(resident_id)) > TRADE_RANGE:
		return []
	var role := str(resident(resident_id).get("role", "")).to_lower()
	var result: Array = []
	if role.contains("metal") or role.contains("smith"):
		result.append("metal_repair")
	if role.contains("wood") or role.contains("carpenter"):
		result.append("wood_repair")
	for event in _state.life.events:
		if event.get("type") == "skill_notice" and event.get("skill_id") in ["metal_repair", "wood_repair"] and event.get("actor_id") == resident_id and event.get("recipient_ids", []).has(observer_id):
			if event.skill_id not in result:
				result.append(event.skill_id)
	return result

func _has_skill(id: String, skill_id: String) -> bool:
	return skill_id in _skill_ids(id)

func _already_shared_skill(speaker_id: String, recipient_id: String, skill_id: String) -> bool:
	for event in _state.life.events:
		if event.get("type") == "skill_notice" and event.get("actor_id") == speaker_id and event.get("skill_id") == skill_id and event.get("recipient_ids", []).has(recipient_id):
			return true
	return false

func _skill_notice_text(skill_id: String) -> String:
	return str(SKILL_NOTICE_TEXT.get(skill_id, "I can perform this repair."))

func _required_skill(part: String) -> String:
	return "metal_repair" if part == "edge" else "wood_repair"

func _part_damaged(item: Dictionary, part: String) -> bool:
	return item.get(part, 0) < 100

func _functioning_axe(id: String) -> bool:
	for item in _legacy_array("items"):
		if item is Dictionary and item.get("kind") == "axe" and item.get("owner_id") == id and item.get("custodian_id") == id and item.get("edge", 0) == 100 and item.get("handle", 0) == 100:
			return true
	return false

func _busy(id: String) -> bool:
	return super.pending_job(id).is_empty() == false or _trade().get("jobs", {}).get(id, {}).is_empty() == false

func _option(result: Array, value: Dictionary) -> void:
	for existing in result:
		if existing.get("id") == value.get("id"):
			return
	result.append(value)

func _validate_communicate_need(sender_id: String, need: Variant) -> Dictionary:
	if not need is Dictionary or not _exact_keys(need, ["kind", "item_id", "part"]):
		return _failure("need_invalid")
	if need.get("kind") != "repair" or not need.get("item_id") is String or need.get("part") not in ["edge", "handle"]:
		return _failure("need_invalid")
	var item := _item(need.item_id)
	if item.get("kind") != "axe" or item.get("owner_id") != sender_id or item.get("custodian_id") != sender_id or not _part_damaged(item, need.part):
		return _failure("need_invalid")
	return {"ok": true}

func _help_reply_text(id: String, event: Dictionary, choice: String) -> String:
	if choice != "unavailable" or not event.get("need") is Dictionary:
		return choice
	var skills := _skill_ids(id)
	var capabilities: Array[String] = []
	if "wood_repair" in skills:
		capabilities.append("wooden handles")
	if "metal_repair" in skills:
		capabilities.append("metal edges")
	var capability := "I have no listed repair skill" if capabilities.is_empty() else "I can repair " + " and ".join(capabilities)
	if _required_skill(str(event.need.get("part", ""))) not in skills:
		capability += "; I cannot perform this repair"
	return "I am unavailable; " + capability + "."

func trade_options(id: String) -> Array:
	var result: Array = [{"id": "wait", "label": "Wait", "action": "wait"}]
	if id not in active_ids():
		return result
	if not _busy(id):
		var base := super.available(id)
		for action in ["eat_ration", "rest", "harvest_ration"]:
			if action in base:
				_option(result, {"id": "life:" + action, "label": action, "action": action})

		for other in active_ids():
			if other == id:
				continue
			var target := _meeting_point(id, other)
			if position_of(id).distance_to(target) > 0.45:
				_option(result, {"id": "approach:" + other, "label": "Approach " + resident(other).name, "action": "approach", "counterparty": other, "target_position": [target.x, target.y, target.z], "duration_seconds": WALK_SECONDS, "_target": other})

		for other in active_ids():
			if other == id or not _near(id, other):
				continue
			for skill_id in SHAREABLE_SKILLS:
				if not _has_skill(id, skill_id) or _already_shared_skill(id, other, skill_id):
					continue
				_option(result, {"id": "share-skill:" + other + ":" + skill_id, "label": "Tell " + resident(other).name + " I can repair " + ("wooden handles" if skill_id == "wood_repair" else "metal edges"), "action": "share_skill", "counterparty": other, "_skill_id": skill_id, "_decision": {"action": "share_skill", "recipient_id": other, "skill_id": skill_id, "text": _skill_notice_text(skill_id)}})

		for other in active_ids():
			if other == id or position_of(id).distance_to(position_of(other)) > HEARING_RANGE:
				continue
			if not has_open_help_request(id, other):
				_option(result, {"id": "ask:" + other, "label": "Ask " + resident(other).name + " for help", "action": "ask_help", "counterparty": other, "_decision": {"action": "ask_help", "recipient_id": other, "text": "Can you help me?"}})
			for item_value in _legacy_array("items"):
				if not item_value is Dictionary or item_value.get("kind") != "axe" or item_value.get("owner_id") != id or item_value.get("custodian_id") != id:
					continue
				for part in ["edge", "handle"]:
					if int(item_value.get(part, 100)) >= 100:
						continue
					var need := {"kind": "repair", "item_id": str(item_value.get("id")), "part": part}
					if has_open_help_request(id, other, need):
						continue
					_option(result, {"id": "ask-repair:" + other + ":" + str(item_value.get("id")) + ":" + part,
						"label": "Ask " + resident(other).name + " to repair " + part + " of my axe",
						"action": "ask_help", "counterparty": other,
						"_decision": {"action": "ask_help", "recipient_id": other,
							"text": "Can you repair the " + part + " of my axe?", "need": need}})

		for event in _state.life.events:
			if event.get("type") == "visitor_inquiry" and event.get("subject_id") == id and not _request_closed(str(event.request_id)) and _visitor_position.is_finite() and _visitor_position.distance_to(position_of(id)) <= HEARING_RANGE:
				for choice in ["willing", "unavailable", "unsure"]:
					_option(result, {"id": "visitor-reply:" + str(event.request_id) + ":" + choice, "label": "回应附近玩家：" + choice, "action": "visitor_reply", "_request_id": event.request_id, "_choice": choice})
			if event.get("type") == "ask_help" and event.get("subject_id") == id and event.get("actor_id") in active_ids() and not _request_closed(event.request_id):
				var other: String = event.actor_id
				if position_of(id).distance_to(position_of(other)) <= HEARING_RANGE:
					for choice in ["willing", "unavailable", "unsure"]:
						_option(result, {"id": "reply:" + event.request_id + ":" + choice, "label": "Reply: " + _help_reply_text(id, event, choice), "action": "reply_help", "counterparty": other, "_decision": {"action": "reply_help", "recipient_id": other, "request_id": event.request_id, "choice": choice, "text": _help_reply_text(id, event, choice)}})
			if event.get("type") == "ask_help" and event.get("actor_id") == id and not _request_closed(event.request_id):
				var target_id: String = event.subject_id
				if target_id in active_ids() and position_of(id).distance_to(position_of(target_id)) <= HEARING_RANGE:
					_option(result, {"id": "cancel:" + event.request_id, "label": "Cancel help request", "action": "cancel_help", "counterparty": target_id, "_decision": {"action": "cancel_help", "recipient_id": target_id, "request_id": event.request_id, "text": "I no longer need help."}})

		for item_value in _legacy_array("items"):
			if not item_value is Dictionary or item_value.get("kind") != "axe" or item_value.get("owner_id") != id or item_value.get("custodian_id") != id or _active_item_contract(str(item_value.get("id"))):
				continue
			for worker in active_ids():
				if worker == id or not _near(id, worker):
					continue
				var public_skills := _public_skills(id, worker)
				for part in ["edge", "handle"]:
					if _part_damaged(item_value, part) and _required_skill(part) in public_skills:
						for price in [2, 5, 8]:
							if resident(id).coins_col < price:
								continue
							_option(result, {"id": "contract:offer:" + str(item_value.get("id")) + ":" + part + ":" + worker + ":" + str(price), "label": "Ask " + resident(worker).name + " to repair " + part + " for " + str(price) + " Col; pay on collection", "action": "offer_repair", "counterparty": worker, "_item_id": item_value.get("id"), "_part": part, "_worker_id": worker, "_price": price, "_settlement": "collection"})
							if _completion_escrow_enabled():
								_option(result, {"id": "contract:completion-offer:" + str(item_value.get("id")) + ":" + part + ":" + worker + ":" + str(price), "label": "Ask " + resident(worker).name + " to repair " + part + " for " + str(price) + " Col; pay on validated completion", "action": "offer_repair", "counterparty": worker, "_item_id": item_value.get("id"), "_part": part, "_worker_id": worker, "_price": price, "_settlement": "completion"})

		for contract in _legacy_array("contracts"):
			if not contract is Dictionary:
				continue
			var contract_id: String = str(contract.get("id", ""))
			var item := _item(str(contract.get("item_id", "")))
			if contract.get("owner_id") == id and contract.get("status") in ["proposed", "accepted"]:
				_option(result, {"id": "contract:cancel:" + contract_id, "label": "Cancel axe repair " + contract_id, "action": "cancel", "counterparty": contract.worker_id, "_contract_id": contract_id})
			if contract.get("owner_id") == id and contract.get("status") == "accepted" and item.get("custodian_id") == id and position_of(id).distance_to(position_of(contract.worker_id)) <= HEARING_RANGE:
				_option(result, {"id": "contract:deliver:" + contract_id, "label": "Deliver axe " + contract.item_id, "action": "deliver", "counterparty": contract.worker_id, "target_position": _position_array(contract.worker_id), "duration_seconds": WALK_SECONDS, "_contract_id": contract_id})
			if contract.get("owner_id") == id and contract.get("status") == "completed" and item.get("custodian_id") == contract.worker_id and position_of(id).distance_to(position_of(contract.worker_id)) <= HEARING_RANGE:
				_option(result, {"id": "contract:collect:" + contract_id, "label": "Collect repaired axe " + contract.item_id, "action": "collect", "counterparty": contract.worker_id, "target_position": _position_array(contract.worker_id), "duration_seconds": WALK_SECONDS, "_contract_id": contract_id})
			if contract.get("worker_id") == id and contract.get("status") == "proposed" and position_of(id).distance_to(position_of(contract.owner_id)) <= HEARING_RANGE:
				var settlement := _contract_settlement(contract)
				var settlement_label := "完成施工并验证后结算" if settlement == "completion" else "物主取回时结算"
				_option(result, {"id": "contract:accept:" + contract_id, "label": "接受修理" + str(contract.get("part", "")) + "：报酬" + str(contract.get("price_col", 0)) + " Col；先预留报酬，交付后施工60秒，" + settlement_label, "action": "accept", "counterparty": contract.owner_id, "_contract_id": contract_id})
				_option(result, {"id": "contract:reject:" + contract_id, "label": "拒绝修理" + str(contract.get("part", "")) + "，本次报价" + str(contract.get("price_col", 0)) + " Col", "action": "reject", "counterparty": contract.owner_id, "_contract_id": contract_id})
			if contract.get("worker_id") == id and contract.get("status") == "delivered" and item.get("custodian_id") == id:
				for part in ["edge", "handle"]:
					if part == contract.get("part") and _part_damaged(item, part) and _has_skill(id, _required_skill(part)) and _trade_account(id).get("iron" if part == "edge" else "wood", 0) > 0:
						_option(result, {"id": "contract:work:" + contract_id + ":" + part, "label": "Repair " + part + " of " + contract.item_id, "action": "work", "counterparty": contract.owner_id, "duration_seconds": REPAIR_SECONDS, "_contract_id": contract_id, "_part": part})

		var account := _trade_account(id)
		if _functioning_axe(id) and account.get("wood", -1) >= 1:
			_option(result, {"id": "tool:use", "label": "Use axe to make kindling", "action": "use_tool", "target_position": _state.godot.homes[id], "duration_seconds": REPAIR_SECONDS})
	for option in result:
		option.speech_allowed = option.action in SPEECH_ACTIONS
	return result

func _position_array(id: String) -> Array:
	var p := position_of(id)
	return [p.x, p.y, p.z]

func _request_closed(request_id: String) -> bool:
	for event in _state.life.events:
		if event.get("request_id") == request_id and event.get("type") in ["reply_help", "cancel_help", "visitor_reply"]:
			return true
	return false

func _find_option(id: String, option_id: String) -> Dictionary:
	for option in trade_options(id):
		if option.get("id") == option_id:
			return option
	return {}

func submit_trade(id: String, option_id: String, command_id: String, provenance: String = "local_rule_policy", speech: String = "") -> Dictionary:
	if id not in active_ids() or not _validate_decision_command_id(command_id).ok or provenance not in ALLOWED_DECISION_PROVENANCE:
		return _failure("invalid_actor_command_or_provenance")
	if speech.length() > MAX_REASON_LENGTH or (not speech.is_empty() and speech.strip_edges().is_empty()):
		return _failure("invalid_public_speech")
	var payload := {"actor_id": id, "action": "trade_option", "option_id": option_id, "provenance": provenance}
	if not speech.is_empty():
		payload.speech = speech
	var trade := _trade()
	var commands: Dictionary = trade.get("commands", {}) if trade.get("commands", {}) is Dictionary else {}
	if commands.has(command_id):
		var prior: Dictionary = commands[command_id]
		var same: bool = prior.get("payload") == payload
		return {"ok": same, "duplicate": same, "code": "duplicate" if same else "command_conflict"}
	if _state.godot.commands.has(command_id):
		return _failure("command_conflict")
	var option := _find_option(id, option_id)
	if option.is_empty():
		return _failure("option_unavailable")
	if not speech.is_empty() and option.action not in SPEECH_ACTIONS:
		return _failure("speech_not_supported_for_action")
	if not speech.is_empty():
		option = option.duplicate(true)
		option._speech = speech
	_ensure_trade()
	trade = _state.godot.trade
	commands = trade.commands
	var action: String = option.action
	if action == "wait":
		commands[command_id] = {"payload": payload, "status": "completed"}
		return {"ok": true, "code": "wait"}
	if action == "visitor_reply":
		var response := {"willing": "我愿意谈谈需要的帮助。", "unavailable": "现在不方便，我想先处理自己的事。", "unsure": "我还没想好，稍后再说。"}
		var answered := reply_to_visitor(id, option._request_id, option._choice, speech if not speech.is_empty() else response[option._choice], command_id, provenance)
		if answered.ok:
			commands[command_id] = {"payload": payload, "status": "completed"}
		return answered
	if action in ["ask_help", "reply_help", "cancel_help"]:
		var message: Dictionary = option._decision.duplicate(true)
		if not speech.is_empty():
			message.text = speech
		var social := communicate(id, message, command_id, provenance)
		if not social.ok:
			return social
		commands[command_id] = {"payload": payload, "status": "completed"}
		return social
	if action == "share_skill":
		var shared := _apply_share_skill(id, option, command_id, provenance, speech)
		if not shared.ok:
			return shared
		commands[command_id] = {"payload": payload, "status": "completed"}
		return shared
	if action in ["eat_ration", "rest", "harvest_ration"]:
		var started := super.start_action(id, action, command_id, provenance)
		if not started.ok:
			return started
		commands[command_id] = {"payload": payload, "status": "pending"}
		return started
	if action not in TRADE_ACTIONS:
		return _failure("invalid_trade_action")
	var result := _apply_trade_start(id, option, command_id, provenance)
	if not result.ok:
		return result
	commands[command_id] = {"payload": payload, "status": "pending" if result.get("pending", false) else "completed"}
	return result

func _apply_share_skill(id: String, option: Dictionary, command_id: String, provenance: String, speech: String) -> Dictionary:
	var recipient_id: String = str(option.get("counterparty", ""))
	var skill_id: String = str(option.get("_skill_id", ""))
	if skill_id not in SHAREABLE_SKILLS or recipient_id == id or recipient_id not in active_ids() or not _has_skill(id, skill_id) or not _near(id, recipient_id) or _already_shared_skill(id, recipient_id, skill_id):
		return _failure("skill_notice_unavailable")
	# Canonical truthful declaration is always persisted; freeform speech is attributed separately and cannot replace it.
	var event := {"type": "skill_notice", "actor_id": id, "subject_id": recipient_id, "recipient_ids": [id, recipient_id],
		"operation_id": command_id, "source": provenance, "provenance": provenance, "skill_id": skill_id,
		"text": _skill_notice_text(skill_id), "contractual": false}
	if not speech.is_empty():
		event["speech"] = speech
	_append_life_event(event)
	return {"ok": true, "code": "skill_notice", "skill_id": skill_id, "recipient_id": recipient_id, "event_id": event.event_id}

func _apply_trade_start(id: String, option: Dictionary, command_id: String, provenance: String) -> Dictionary:
	var action: String = option.action
	var target: String = str(option.get("counterparty", id))
	var contract_id: String = str(option.get("_contract_id", ""))
	if action in ["walk", "approach"]:
		var target_position: Array = option.get("target_position", _position_array(target))
		if action == "approach" and position_of(id).distance_to(_vector(target_position)) <= 0.45:
			return {"ok": true, "code": "no_change", "changed": false}
		return _start_job(id, action, command_id, provenance, target_position, option.get("duration_seconds", WALK_SECONDS), {"target_id": target})
	if action == "use_tool":
		if not _functioning_axe(id) or _trade_account(id).get("wood", -1) < 1:
			return _failure("resources_unavailable")
		return _start_job(id, action, command_id, provenance, option.get("target_position", _position_array(id)), REPAIR_SECONDS, {})
	if action == "offer_repair":
		var item_id: String = str(option.get("_item_id", ""))
		var part: String = str(option.get("_part", ""))
		var worker_id: String = str(option.get("_worker_id", ""))
		var settlement: String = str(option.get("_settlement", "collection"))
		if settlement not in ["collection", "completion"] or (settlement == "completion" and not _completion_escrow_enabled()):
			return _failure("invalid_settlement")
		var proposed_item := _item(item_id)
		if proposed_item.is_empty() or proposed_item.get("owner_id") != id or proposed_item.get("custodian_id") != id or not _part_damaged(proposed_item, part) or not _near(id, worker_id) or _required_skill(part) not in _public_skills(id, worker_id) or _active_item_contract(item_id):
			return _failure("invalid_proposal")
		var new_contract := {"id": "trade_contract_" + command_id, "part": part, "item_id": item_id, "owner_id": id, "worker_id": worker_id, "status": "proposed", "price_col": int(option.get("_price", -1)), "reserved_col": 0}
		if new_contract.get("price_col") not in [2, 5, 8]:
			return _failure("invalid_price")
		if settlement == "completion":
			new_contract["settlement"] = "completion"
			new_contract["settled"] = false
		if not _state.life.has("contracts"):
			_state.life.contracts = []
		_state.life.contracts.append(new_contract)
		var event_fields := {"contract_id": new_contract.get("id"), "item_id": item_id, "part": part, "price_col": new_contract.get("price_col"), "settlement": settlement}
		if option.has("_speech"):
			event_fields["text"] = option._speech
		_append_trade_event("offer_repair", id, [id, worker_id], command_id, event_fields, provenance)
		return {"ok": true, "code": "contract_proposed"}
	var contract := _contract(contract_id)
	if contract.is_empty():
		return _failure("unknown_contract")
	if action == "accept":
		if contract.worker_id != id or contract.status != "proposed" or not _near(id, contract.owner_id):
			return _failure("contract_unavailable")
		var owner_account := _trade_account(contract.owner_id)
		var price: int = int(contract.price_col)
		var material: String = "iron" if contract.get("part") == "edge" else "wood"
		if owner_account.is_empty() or not _has_skill(id, _required_skill(contract.part)) or _trade_account(id).get(material, -1) < 1 or owner_account.get("reserved_col", -1) < 0 or resident(contract.owner_id).coins_col < price:
			return _failure("insufficient_funds")
		resident(contract.owner_id).coins_col -= price
		owner_account.reserved_col += price
		contract.reserved_col = price
		contract.status = "accepted"
		_append_trade_event("axe_contract_accepted", id, [contract.owner_id, id], command_id, {"contract_id": contract_id, "text": option.get("_speech", "I accept this contract.")}, provenance)
		return {"ok": true, "code": "contract_accepted"}
	if action == "reject":
		if contract.worker_id != id or contract.status != "proposed" or not _near(id, contract.owner_id):
			return _failure("contract_unavailable")
		contract.status = "rejected"
		_append_trade_event("axe_contract_rejected", id, [contract.owner_id, id], command_id, {"contract_id": contract_id, "text": option.get("_speech", "I decline this repair.")}, provenance)
		return {"ok": true, "code": "contract_rejected"}
	if action == "cancel":
		if contract.owner_id != id or contract.status not in ["proposed", "accepted"]:
			return _failure("contract_unavailable")
		if contract.status == "accepted":
			var account := _trade_account(contract.owner_id)
			account.reserved_col -= int(contract.price_col)
			resident(contract.owner_id).coins_col += int(contract.price_col)
		contract.reserved_col = 0
		contract.status = "cancelled"
		_append_trade_event("axe_contract_cancelled", id, [contract.owner_id, contract.worker_id], command_id, {"contract_id": contract_id, "text": option.get("_speech", "I cancel this contract.")}, provenance)
		return {"ok": true, "code": "contract_cancelled"}
	if action == "deliver":
		if contract.owner_id != id or contract.status != "accepted" or not _near(id, contract.worker_id):
			return _failure("contract_unavailable")
		var deliver_item := _item(str(contract.item_id))
		if deliver_item.get("owner_id") != id or deliver_item.get("custodian_id") != id:
			return _failure("invalid_custody")
		return _start_job(id, action, command_id, provenance, _meeting_array(id, contract.worker_id), WALK_SECONDS, {"contract_id": contract_id})
	if action == "work":
		if contract.worker_id != id or contract.status != "delivered" or not _has_skill(id, _required_skill(str(option.get("_part", "")))):
			return _failure("contract_unavailable")
		var repair_item := _item(str(contract.item_id))
		if repair_item.get("custodian_id") != id:
			return _failure("invalid_custody")
		return _start_job(id, action, command_id, provenance, _state.godot.homes[id], REPAIR_SECONDS, {"contract_id": contract_id, "part": option.get("_part", "")})
	if action == "collect":
		if contract.owner_id != id or contract.status != "completed" or not _near(id, contract.worker_id):
			return _failure("contract_unavailable")
		var collect_item := _item(str(contract.item_id))
		if collect_item.get("custodian_id") != contract.worker_id:
			return _failure("invalid_custody")
		return _start_job(id, action, command_id, provenance, _meeting_array(id, contract.worker_id), WALK_SECONDS, {"contract_id": contract_id})
	return _failure("invalid_trade_action")

func _start_job(id: String, action: String, command_id: String, provenance: String, target_position: Array, duration: float, extra: Dictionary) -> Dictionary:
	if _busy(id) or not _valid_position(target_position) or not is_finite(duration) or duration < 0.0:
		return _failure("actor_busy_or_invalid_destination")
	var job := {"action": action, "command_id": command_id, "provenance": provenance, "elapsed": 0.0, "duration_seconds": duration, "target_position": target_position}
	for key in extra:
		job[key] = extra[key]
	_ensure_trade().jobs[id] = job
	return {"ok": true, "code": "trade_started", "pending": true}

func _contract(id: String) -> Dictionary:
	for value in _legacy_array("contracts"):
		if value is Dictionary and value.get("id") == id:
			return value
	return {}

func _near(first: String, second: String) -> bool:
	return first in active_ids() and second in active_ids() and position_of(first).distance_to(position_of(second)) <= TRADE_RANGE

func pending_job(id: String) -> Dictionary:
	var parent_job := super.pending_job(id)
	if not parent_job.is_empty():
		return parent_job
	return _trade().get("jobs", {}).get(id, {}).duplicate(true)

func destination(id: String, action: String) -> Vector3:
	var job: Dictionary = _trade().get("jobs", {}).get(id, {})
	if not job.is_empty() and job.get("action") == action and _valid_position(job.get("target_position")):
		return _vector(job.target_position)
	return super.destination(id, action)

func advance(delta: float) -> Dictionary:
	var result := super.advance(delta)
	if not result.ok:
		return result
	var completed: Array = result.completed.duplicate()
	for receipt in completed:
		if _trade().get("commands", {}).has(receipt.command_id):
			_trade().commands[receipt.command_id].status = "completed" if receipt.ok else "rejected"
			_trade().commands[receipt.command_id].result = receipt.duplicate(true)
	var jobs: Dictionary = _trade().get("jobs", {})
	for id in jobs.keys().duplicate():
		var job: Dictionary = jobs.get(id, {})
		if job.is_empty() or not active_ids().has(id) or position_of(id).distance_to(_vector(job.target_position)) > 0.45:
			continue
		job.elapsed += delta
		if job.elapsed >= job.duration_seconds:
			var receipt := _finish_trade_job(id, job)
			completed.append(receipt)
	return {"ok": true, "completed": completed}

func _finish_trade_job(id: String, job: Dictionary) -> Dictionary:
	var command_id: String = job.command_id
	var ok := true
	var code: String = job.action
	var contract_id: String = str(job.get("contract_id", ""))
	var contract := _contract(contract_id)
	var item := _item(str(contract.get("item_id", ""))) if not contract.is_empty() else {}
	match job.action:
		"walk", "approach":
			_append_trade_event("resident_moved", id, [id, str(job.get("target_id", id))], command_id, {}, job.get("provenance", "local_rule_policy"))
		"use_tool":
			var account := _trade_account(id)
			ok = _functioning_axe(id) and account.get("wood", -1) >= 1
			if ok:
				account.wood -= 1
				account.kindling += 1
				_append_trade_event("use_tool", id, [id], command_id, {"item_id": "axe"}, job.get("provenance", "local_rule_policy"))
			else:
				code = "resources_unavailable"
		"deliver":
			ok = not contract.is_empty() and contract.status == "accepted" and item.get("owner_id") == id and item.get("custodian_id") == id and _near(id, str(contract.get("worker_id", "")))
			if ok:
				item.custodian_id = contract.worker_id
				contract.status = "delivered"
				_append_trade_event("axe_delivered", id, [contract.owner_id, contract.worker_id], command_id, {"contract_id": contract_id, "item_id": contract.item_id}, job.get("provenance", "local_rule_policy"))
			else:
				code = "invalid_custody"
		"work":
			var part: String = str(job.get("part", ""))
			var account := _trade_account(id)
			var material := "iron" if part == "edge" else "wood"
			var owner_account := _trade_account(str(contract.get("owner_id", ""))) if not contract.is_empty() else {}
			var price: int = int(contract.get("price_col", -1)) if not contract.is_empty() else -1
			var completion_settlement := not contract.is_empty() and _contract_settlement(contract) == "completion"
			ok = not contract.is_empty() and contract.status == "delivered" and item.get("custodian_id") == id and _has_skill(id, _required_skill(part)) and account.get(material, -1) >= 1 and _part_damaged(item, part) and (not completion_settlement or owner_account.get("reserved_col", -1) >= price)
			if ok:
				account[material] -= 1
				item[part] = 100
				contract.status = "completed"
				var work_fields := {"contract_id": contract_id, "item_id": contract.item_id, "part": part, "settlement": _contract_settlement(contract)}
				if completion_settlement:
					owner_account.reserved_col -= price
					resident(contract.worker_id).coins_col += price
					contract.reserved_col = 0
					contract.settled = true
					work_fields["price_col"] = price
				_append_trade_event("axe_repaired", id, [contract.owner_id, contract.worker_id], command_id, work_fields, job.get("provenance", "local_rule_policy"))
			else:
				code = "resources_unavailable"
		"collect":
			var owner_account := _trade_account(id)
			var price: int = int(contract.get("price_col", -1))
			var completion_settlement := not contract.is_empty() and _contract_settlement(contract) == "completion"
			ok = not contract.is_empty() and contract.status == "completed" and item.get("owner_id") == id and item.get("custodian_id") == contract.worker_id and _near(id, str(contract.get("worker_id", ""))) and (completion_settlement and contract.get("settled", false) and owner_account.get("reserved_col", -1) >= 0 or not completion_settlement and owner_account.get("reserved_col", -1) >= price)
			if ok:
				item.custodian_id = id
				if not completion_settlement:
					owner_account.reserved_col -= price
					resident(contract.worker_id).coins_col += price
					contract.reserved_col = 0
				contract.status = "collected"
				_append_trade_event("axe_repair_collected" if completion_settlement else "axe_repair_paid", id, [contract.owner_id, contract.worker_id], command_id, {"contract_id": contract_id, "item_id": contract.item_id, "price_col": price, "settlement": _contract_settlement(contract)}, job.get("provenance", "local_rule_policy"))
			else:
				code = "payment_unavailable"
		_:
			ok = false
			code = "invalid_trade_action"
	var trade := _ensure_trade()
	trade.jobs.erase(id)
	var receipt := {"ok": ok, "code": code, "actor_id": id, "command_id": command_id}
	if trade.commands.has(command_id):
		trade.commands[command_id].status = "completed" if ok else "rejected"
		trade.commands[command_id].result = receipt.duplicate(true)
	return receipt

func _append_trade_event(event_type: String, actor_id: String, recipients: Array, command_id: String, fields: Dictionary, provenance: String = "local_rule_policy") -> void:
	var event := {"type": event_type, "actor_id": actor_id, "subject_id": recipients[-1] if not recipients.is_empty() else actor_id, "recipient_ids": recipients, "operation_id": command_id, "source": provenance, "provenance": provenance, "contractual": true}
	for key in fields:
		event[key] = fields[key]
	_append_life_event(event)

func resident_view(id: String = "") -> Dictionary:
	var view := super.resident_view(id)
	if view.is_empty():
		return view
	var own_items: Array = []
	for item in _legacy_array("items"):
		if item is Dictionary and (item.get("owner_id") == id or item.get("custodian_id") == id):
			own_items.append(item.duplicate(true))
	var own_contracts: Array = []
	for contract in _legacy_array("contracts"):
		if contract is Dictionary and (contract.get("owner_id") == id or contract.get("worker_id") == id):
			var visible_contract: Dictionary = contract.duplicate(true)
			visible_contract["settlement"] = _contract_settlement(contract)
			visible_contract["settled"] = bool(contract.get("settled", contract.get("status") == "collected"))
			own_contracts.append(visible_contract)
	view["items"] = own_items
	view["skills"] = _skill_ids(id)
	var known_notices: Array = []
	for event in _state.life.events:
		if event.get("type") != "skill_notice" or event.get("skill_id") not in SHAREABLE_SKILLS or not event.get("recipient_ids", []).has(id) or event.get("actor_id") == id:
			continue
		# Historical source projection persists even if the known speaker left the active pool;
		# require only that the speaker is a known identity, never hidden fields or current availability.
		var speaker_id: String = str(event.get("actor_id", ""))
		if speaker_id.is_empty() or resident(speaker_id).is_empty():
			continue
		known_notices.append({"actor_id": speaker_id, "skill_id": event.get("skill_id", ""),
			"source_event_id": event.get("event_id", ""), "seq": event.get("seq", 0),
			"source": event.get("source", ""), "provenance": event.get("provenance", ""),
			"text": event.get("text", "")})
	view["known_skill_notices"] = known_notices
	view["contracts"] = own_contracts
	view["life_account"] = _trade_account(id).duplicate(true)
	view["wallet"] = {"coins_col": resident(id).get("coins_col", 0)}
	view["trade_settlement_terms"] = {"legacy_default": "collection", "completion_escrow": "completion" if _completion_escrow_enabled() else "unavailable"}
	view["known_rules"] = {"axe_use": "柴斧必须斧刃和斧柄都达到100，本人持有，并在自己的工作点消耗1木料才能加工1柴火。修好其中一部分还不能使用。",
		"communication": "你的reason是私人选择理由，不会自动说给别人听。泛化help只询问是否有空；标明工具和部位的repair求助才会传达具体问题。willing只是愿意交谈，不是接受收费委托。wood_repair修木柄，metal_repair修金属斧刃；是否帮忙由本人选择。",
		"repair": "price_col是该笔修理的固定总报酬（Col），不是单价或估算，无其他费率。旧合同和普通报价的settlement是collection：接受后该金额从物主钱包转入预留资金，交付后施工60秒，修好不立即付款，物主取回工具时预留金额全额转入工人钱包。如果可选报价标明completion，表示完工结算：同样先预留、交付和60秒施工，只有成功消耗材料并把部位修到100后才转移这笔既有预留金额，collect只返还工具且不再次付款。修斧刃消耗工人的1铁，修斧柄消耗1木。可因时间、材料或物主不来取回的风险拒绝，愿意交谈不等于接受合同。"}

	view["unavailable_actions"] = []
	for item in own_items:
		if item.get("kind") == "axe" and item.get("owner_id") == id:
			if item.edge < 100 or item.handle < 100:
				view.unavailable_actions.append({"action": "use_tool", "item_id": item.id,
					"reason": "工具仍需修理", "edge": item.edge, "handle": item.handle, "required_each": 100})
			if item.get("custodian_id") != id:
				view.unavailable_actions.append({"action": "use_tool", "item_id": item.id,
					"reason": "工具属于你，但当前不由你持有。实际取回后才能使用。", "custodian_id": item.get("custodian_id")})
	for contract in own_contracts:
		if contract.get("owner_id") != id or contract.get("worker_id") not in active_ids():
			continue
		if contract.get("status") in ["accepted", "completed"] and not _near(id, contract.worker_id):
			var action := "collect" if contract.status == "completed" else "deliver"
			view.unavailable_actions.append({"action": action, "contract_id": contract.id, "counterparty": contract.worker_id,
				"reason": "交付和取回都需要双方在3米交接范围内。你目前不在工人身边；先接近该工人后才能交接，这不是系统还在处理。"})
	var public_roles: Array = []
	for other in active_ids():
		if other == id or position_of(id).distance_to(position_of(other)) > HEARING_RANGE:
			continue
		var skills := _public_skills(id, other)
		if not skills.is_empty():
			public_roles.append({"id": other, "name": resident(other).name, "role": resident(other).role, "skills": skills})
	view["nearby_skilled_roles"] = public_roles
	return view

func _active_item_contract(item_id: String) -> bool:
	for contract in _legacy_array("contracts"):
		if contract.get("item_id") == item_id and contract.get("status") in ["proposed", "accepted", "delivered", "completed"]:
			return true
	return false

func _meeting_point(id: String, other: String) -> Vector3:
	var direction := position_of(id) - position_of(other)
	direction.y = 0
	if direction.length() < 0.01:
		direction = Vector3.LEFT
	return position_of(other) + direction.normalized() * 0.85

func _meeting_array(id: String, other: String) -> Array:
	var point := _meeting_point(id, other)
	return [point.x, point.y, point.z]

func _validate_runtime_trade(value: Dictionary, active: Array) -> Dictionary:
	var trade: Variant = value.godot.get("trade", {})
	if trade == {}:
		return {"ok": true, "code": "trade_runtime_valid"}
	if not trade is Dictionary or not trade.get("jobs") is Dictionary or not trade.get("commands") is Dictionary:
		return _failure("invalid_trade_state")
	var capabilities: Variant = trade.get("capabilities", {})
	if not capabilities is Dictionary:
		return _failure("invalid_trade_capabilities")
	for capability_id in capabilities:
		if capability_id != COMPLETION_ESCROW_ID:
			return _failure("unknown_trade_capability")
		var capability: Variant = capabilities[capability_id]
		if not capability is Dictionary:
			return _failure("invalid_trade_capability")
		var capability_record: Dictionary = capability
		var source_value: Variant = capability_record.get("source")
		if not _exact_keys(capability_record, ["status", "id", "version", "reviewer", "source"]) or capability_record.get("status") != "enabled" or capability_record.get("id") != COMPLETION_ESCROW_ID or capability_record.get("version") != COMPLETION_ESCROW_VERSION or capability_record.get("reviewer") != "development_gm" or not source_value is Dictionary:
			return _failure("invalid_trade_capability")
		var source: Dictionary = source_value
		if not _exact_keys(source, ["seq", "actor_id", "text"]):
			return _failure("invalid_trade_capability_source")
		if typeof(source.seq) != TYPE_INT or source.seq < 1 or source.actor_id not in active or not source.text is String or source.text.strip_edges().is_empty():
			return _failure("invalid_trade_capability_source")
		var found_source := false
		for event in value.life.events:
			if event is Dictionary and event.get("seq") == source.seq and event.get("type") in ["visitor_reply", "reply_help"] and event.get("actor_id") == source.actor_id and event.get("text") == source.text:
				found_source = true
				break
		if not found_source:
			return _failure("invalid_trade_capability_source")
		var manifest_valid := _validate_completion_manifest(_load_completion_manifest())
		if not manifest_valid.ok:
			return manifest_valid
	var receipts: Variant = trade.get("receipts", {})
	if not receipts is Dictionary:
		return _failure("invalid_trade_receipts")
	for command_id in receipts:
		var receipt: Variant = receipts[command_id]
		if not command_id is String or not _validate_decision_command_id(command_id).ok or not command_id.begins_with(HOST_REVIEWER_PREFIX) or not receipt is Dictionary:
			return _failure("invalid_trade_receipt")
		var receipt_record: Dictionary = receipt
		var payload_value: Variant = receipt_record.get("payload")
		var result_value: Variant = receipt_record.get("result")
		if not payload_value is Dictionary or not result_value is Dictionary:
			return _failure("invalid_trade_receipt")
		var payload: Dictionary = payload_value
		var result: Dictionary = result_value
		if not _exact_keys(payload, ["action", "source_seq", "reviewer", "module_id", "module_version"]) or payload.action != "install_completion_escrow" or typeof(payload.source_seq) != TYPE_INT or payload.source_seq < 1 or payload.reviewer != "development_gm" or payload.module_id != COMPLETION_ESCROW_ID or payload.module_version != COMPLETION_ESCROW_VERSION or not result.get("ok", false) or result.get("code") != "completion_escrow_installed":
			return _failure("invalid_trade_receipt")
	return {"ok": true, "code": "trade_runtime_valid"}

func _validate_state(value: Variant) -> Dictionary:
	var base := super._validate_state(value)
	if not base.ok:
		return base
	var ids: Array = []
	for person in value.residents:
		ids.append(person.stable_id)
	var active: Array = value.godot.positions.keys()
	var life: Dictionary = value.life
	var runtime_valid := _validate_runtime_trade(value, active)
	if not runtime_valid.ok:
		return runtime_valid
	var items: Dictionary = {}
	for item in life.get("items", []):
		if not item is Dictionary or not item.get("id") is String or items.has(item.id) or item.get("owner_id") not in ids or item.get("custodian_id") not in ids:
			return _failure("invalid_trade_item")
		if item.get("kind") == "axe" and (not _bounded(item.get("edge"), 100) or not _bounded(item.get("handle"), 100)):
			return _failure("invalid_tool_condition")
		items[item.id] = item
	var reserves: Dictionary = {}
	var active_items: Array = []
	var contract_ids: Array = []
	for contract in life.get("contracts", []):
		if not contract is Dictionary or not contract.get("id") is String or contract.id in contract_ids:
			return _failure("invalid_trade_contract")
		contract_ids.append(contract.id)
		var status: String = str(contract.get("status", ""))
		var settlement_present: bool = contract.has("settlement")
		var settlement: String = str(contract.get("settlement", "collection"))
		if settlement not in ["collection", "completion"]:
			return _failure("invalid_trade_settlement")
		var settled_present: bool = contract.has("settled")
		if settled_present and typeof(contract.get("settled")) != TYPE_BOOL:
			return _failure("invalid_trade_settled")
		if status not in ["proposed", "accepted", "delivered", "completed", "collected", "rejected", "cancelled"]:
			continue # Unknown historical data is preserved but never offered for execution.
		if settlement == "completion" and (not settlement_present or not settled_present):
			return _failure("invalid_trade_settled")
		if settled_present and settlement != "completion" and contract.get("settled") and status != "collected":
			return _failure("invalid_trade_settled")
		if contract.get("part") not in ["edge", "handle"] or typeof(contract.get("price_col")) != TYPE_INT or contract.get("price_col") not in [2, 5, 8] or contract.get("owner_id") not in ids or contract.get("worker_id") not in ids or contract.owner_id == contract.worker_id or not items.has(contract.get("item_id")):
			return _failure("invalid_trade_contract")
		var item: Dictionary = items[contract.item_id]
		if item.owner_id != contract.owner_id:
			return _failure("invalid_contract_owner")
		if status in ["proposed", "accepted", "delivered", "completed"]:
			if item.id in active_items:
				return _failure("multiple_active_item_contracts")
			active_items.append(item.id)
			var holder: String = contract.owner_id if status in ["proposed", "accepted"] else contract.worker_id
			if item.custodian_id != holder:
				return _failure("invalid_contract_custody")
		if typeof(contract.get("reserved_col")) != TYPE_INT or contract.get("reserved_col") < 0:
			return _failure("invalid_contract_reserve")
		var settled: bool = bool(contract.get("settled", false))
		var reserved: int = int(contract.price_col) if settlement == "collection" and status in ["accepted", "delivered", "completed"] else int(contract.price_col) if settlement == "completion" and status in ["accepted", "delivered"] else 0
		if contract.get("reserved_col") != reserved or (settlement == "completion" and settled != (status in ["completed", "collected"])):
			return _failure("invalid_contract_reserve")
		reserves[contract.owner_id] = reserves.get(contract.owner_id, 0) + reserved
		if status == "completed" and item.get(contract.part) != 100:
			return _failure("invalid_trade_completion")
	var accounts: Array = []
	for account in life.get("accounts", []):
		if not account is Dictionary or account.get("resident_id") not in ids or account.resident_id in accounts:
			return _failure("invalid_trade_account")
		accounts.append(account.resident_id)
		for field in ["wood", "iron", "kindling", "reserved_col"]:
			if not _bounded(account.get(field), 1000000000):
				return _failure("invalid_trade_quantity")
		if account.reserved_col != reserves.get(account.resident_id, 0):
			return _failure("invalid_trade_account_reserve")
	for owner in reserves:
		if owner not in accounts:
			return _failure("missing_trade_account")
	var trade = value.godot.get("trade", {})
	if trade == {}:
		return {"ok": true, "code": "town_state_valid"}
	if not trade is Dictionary or not trade.get("jobs") is Dictionary or not trade.get("commands") is Dictionary:
		return _failure("invalid_trade_state")
	for cid in trade.commands:
		var command = trade.commands[cid]
		if not cid is String or not _validate_decision_command_id(cid).ok or not command is Dictionary or command.get("status") not in ["pending", "completed", "rejected"] or not command.get("payload") is Dictionary:
			return _failure("invalid_trade_command")
		var payload: Dictionary = command.payload
		if payload.get("action") != "trade_option" or payload.get("actor_id") not in active or not payload.get("option_id") is String or payload.get("provenance") not in ALLOWED_DECISION_PROVENANCE:
			return _failure("invalid_trade_payload")
		if command.status == "pending":
			var actor: String = payload.actor_id
			var job: Dictionary = trade.jobs.get(actor, value.godot.pending.get(actor, {}))
			if job.get("command_id") != cid:
				return _failure("orphan_trade_command")
	for actor in trade.jobs:
		var job = trade.jobs[actor]
		if actor not in active or value.godot.pending.has(actor) or not job is Dictionary or job.get("action") not in TRADE_ACTIONS or not trade.commands.has(job.get("command_id")) or not _valid_nonnegative(job.get("elapsed")) or not _valid_nonnegative(job.get("duration_seconds")) or not _valid_position(job.get("target_position")):
			return _failure("invalid_trade_job")
		var command: Dictionary = trade.commands[job.command_id]
		if command.status != "pending" or command.payload.actor_id != actor or job.get("provenance") != command.payload.provenance:
			return _failure("invalid_trade_job_receipt")
	return {"ok": true, "code": "town_state_valid"}
