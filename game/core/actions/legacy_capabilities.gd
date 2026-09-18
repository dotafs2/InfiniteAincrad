extends RefCounted
## Existing reducers remain authoritative. This adapter supplies the common contract.
const Registry = preload("res://core/actions/capability_registry.gd")
const IDS := {
	"wait": "life.wait", "eat_ration": "life.eat", "rest": "life.rest", "harvest_ration": "production.forage",
	"give_food": "inventory.give_food", "approach": "movement.approach", "walk": "movement.walk",
	"travel": "movement.visit", "observe_work": "perception.observe_work", "share_skill": "knowledge.announce_skill",
	"refer_skill": "knowledge.refer_skill", "ask_help": "social.ask_help", "reply_help": "social.reply_help",
	"cancel_help": "social.cancel_help", "visitor_reply": "social.reply_visitor",
	"offer_repair": "contract.offer_repair", "accept": "contract.accept", "reject": "contract.decline",
	"cancel": "contract.cancel", "deliver": "inventory.deliver", "collect": "inventory.collect",
	"work": "production.repair", "use_tool": "production.use_tool", "recover_material": "production.recover_material",
	"cancel_material": "production.cancel_collection", "bake_bread": "production.bake"
}
const JOBS := ["eat_ration", "rest", "harvest_ration", "approach", "walk", "travel", "deliver", "collect", "work", "use_tool", "recover_material", "bake_bread"]
const SPEECH := ["share_skill", "refer_skill", "ask_help", "reply_help", "cancel_help", "visitor_reply", "offer_repair", "accept", "reject", "cancel"]
const RESOURCES := {
	"wait": ["actor_decision_turn"], "eat_ration": ["actor_body", "actor_food"],
	"rest": ["actor_body", "own_home_or_known_rest_slot"], "harvest_ration": ["actor_body", "finite_public_berry_stock"],
	"give_food": ["actor_food", "recipient_food", "current_handoff_range"],
	"approach": ["actor_body", "current_counterparty_position"], "walk": ["actor_body", "own_workstation"],
	"travel": ["actor_body", "personal_place_knowledge", "own_destination_slot"],
	"observe_work": ["observer_attention", "visible_current_work"], "share_skill": ["speaker_turn", "own_shareable_skill"],
	"refer_skill": ["speaker_turn", "attributed_skill_notice"], "ask_help": ["speaker_turn", "named_help_request"],
	"reply_help": ["speaker_turn", "named_help_request", "own_consent"], "cancel_help": ["own_help_request"],
	"visitor_reply": ["speaker_turn", "named_visitor_inquiry", "current_hearing_range"],
	"offer_repair": ["named_owned_item_part", "named_counterparty", "named_contract"],
	"accept": ["named_contract", "owner_wallet", "escrow", "worker_skill_and_consent"],
	"reject": ["named_contract", "own_consent"], "cancel": ["named_contract", "reserved_funds"],
	"deliver": ["actor_body", "named_contract", "owned_item_custody", "current_handoff_range"],
	"collect": ["actor_body", "named_contract", "repaired_item_custody", "reserved_funds", "current_handoff_range"],
	"work": ["actor_body", "named_contract", "item_part", "actor_repair_material", "own_workstation"],
	"use_tool": ["actor_body", "owned_functional_tool", "actor_wood", "own_workstation"],
	"recover_material": ["actor_body", "known_finite_material_source"], "cancel_material": ["own_material_job"],
	"bake_bread": ["actor_body", "known_oven", "finite_flour_rechecked_at_completion"]
}

static func definitions() -> Array:
	var result: Array = []
	for action in IDS:
		result.append(Registry.spec(IDS[action], "legacy", "durable_job" if action in JOBS else "immediate",
			RESOURCES[action],
			"optional" if action in SPEECH else "forbidden",
			["existing_authoritative_option_is_available", "existing_ownership_knowledge_range_and_resource_rules"],
			["existing_reducer_only", "existing_journal_and_world_events"], "existing_explicit_cancel_option_only"))
	result.append(Registry.spec("learning.request_lesson", "legacy", "consent_protocol", ["teacher_consent", "attributed_skill_source"],
		"optional", ["existing_known_skill_and_lesson_gates"], ["existing_consensual_lesson_protocol"], "existing_explicit_cancel_option_only"))
	return result

static func capability(option: Dictionary) -> String:
	if str(option.get("id", "")).begins_with("ask-teach:"): return "learning.request_lesson"
	return str(IDS.get(option.get("action", ""), ""))

static func presentation(world, option: Dictionary) -> Dictionary:
	# A lossless presentation adapter, never a change to legacy commands or rules.
	if option.get("action") not in ["ask_help", "share_skill", "refer_skill", "approach", "observe_work", "give_food"]: return {}
	var target: String = str(option.get("counterparty", ""))
	if target.is_empty(): return {}
	var name: String = world.resident_name(target)
	var label: String = option.label
	if name.is_empty() or label.count(name) != 1 or label.contains("{0}"): return {}
	return {"template": label.replace(name, "{0}"), "arguments": [name]}

static func journals(state: Dictionary) -> Array:
	var godot: Dictionary = state.get("godot", {})
	var result: Array = [godot.get("commands", {})]
	for module in ["trade", "materials", "places", "baking"]:
		result.append(godot.get(module, {}).get("commands", {}))
	return result

static func has_command(state: Dictionary, id: String) -> bool:
	for journal in journals(state):
		if journal.has(id): return true
	return false

static func receipt(state: Dictionary, id: String) -> Dictionary:
	var records: Array = []
	for journal in journals(state):
		if journal.has(id): records.append(journal[id].duplicate(true))
	if records.is_empty(): return {}
	var status := "completed"
	for record in records:
		if record.get("status") == "pending": status = "pending"
	# A legacy wrapper can retain admission=pending after its actual body job ends.
	# The authoritative life journal then supplies the terminal outcome.
	var body_command: Dictionary = state.get("godot", {}).get("commands", {}).get(id, {})
	if body_command.get("status") in ["completed", "rejected"]: status = body_command.status
	for record in records:
		if record.get("status") == "rejected" or record.get("result", {}).get("ok", true) == false: status = "rejected"
	return {"command_id": id, "status": status, "records": records}
