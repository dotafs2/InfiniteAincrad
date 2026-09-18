extends "res://core/town_life.gd"
## Bounded axe repair and tool-use continuation for the schema-2 town fixture.
## Legacy arrays remain authoritative; godot.trade only records new command/job state.

const SPEECH_ACTIONS := ["visitor_reply", "ask_help", "reply_help", "cancel_help", "offer_repair", "accept", "reject", "cancel", "share_skill", "refer_skill"]
const SHAREABLE_SKILLS := ["wood_repair", "metal_repair"]
## Minimal consensual lesson (issue-7444ea09db62). The world already lets a skill holder announce
## its own skill (share_skill) and lets a listener pass that attribution on (refer_skill), but skill
## rows could only ever be seeded, so real production capacity could not grow by consent. A lesson is
## one more voluntary social exchange: a learner that already received an attributed notice/referral
## about a nearby resident's own shareable repair skill asks that resident to teach it, and that
## resident answers separately. Only a willing answer from a teacher that really can do the work, with
## both still inside actual hearing range and the recorded grounding still verified, adds exactly that
## one skill row to the learner. Nothing is minted, no existing row is touched, and every other kind of
## request keeps its original meaning.
const LESSON_NEED_KIND := "lesson"
const LESSON_EVENT := "skill_lesson"
const LESSON_ACTIONS := ["notice", "referral"]
const SKILL_NOTICE_TEXT := {
	"wood_repair": "I can repair wooden handles.",
	"metal_repair": "I can repair metal edges.",
}
const SKILL_REFERRAL_TEXT := {
	"wood_repair": "%s told me they can repair wooden handles.",
	"metal_repair": "%s told me they can repair metal edges.",
}
const SKILL_ASK_NAMES := {
	"wood_repair": "carpentry",
	"metal_repair": "metalwork",
}
const TRADE_RANGE := 3.0
const FOOD_HANDOFF_ACTION := "give_food"
const FOOD_HANDOFF_EVENT := "food_handed_over"
const FOOD_HANDOFF_PREFIX := "food:give:"
const FOOD_HANDOFF_RANGE := 1.5
const FOOD_CAPACITY := 2
const REPAIR_SECONDS := 60.0
const WALK_SECONDS := 1.0
## Voluntary, read-only observation of a neighbour's own running work (issue-194d1db6d25f, following
## the real life_event_47 ask). The world already lets a resident work; it had no way to notice that a
## nearby neighbour is genuinely working, so no resident could learn a neighbour's work from its own
## sight. This adds exactly that one personal fact: a free resident standing within sight of a
## neighbour that really is executing work at its own work point may record what it saw. Nothing is
## granted - no skill, item, material, coin, account or contract - the observed worker's own job is
## untouched, and only the observer's own view gains the fact. Only a job that really is work AND
## really is accruing qualifies: rest, waiting, walking/approaching, a public-place trip, a material
## recovery trip and a material-blocked or otherwise unsatisfiable action never do, so the observation
## can never claim work the world is not actually doing.
const OBSERVE_WORK := "observe_work"
const WORK_OBSERVED_EVENT := "work_observed"
const OBSERVE_WORK_RANGE := 3.0
const OBSERVE_WORK_ARRIVAL_RADIUS := 0.45
## The world's own productive work actions. Each one is listed with the live prerequisite that its
## own completion rule applies, so an action whose prerequisite is missing is a failing trip, never a
## watchable work.
const WORK_ACTIONS := ["harvest_ration", "use_tool", "work"]
## Bounded, honest close for an ACTIVE social approach (issue-8e69ca9fbae5). The world already
## gives a blocked trip its own bounded failure in town_places; the same shape is applied here to
## an approach job: while the mover is still outside the world's own arrival radius and its real
## remaining distance to this job's meeting point stops improving by the journey detector's own
## 0.05 m epsilon for APPROACH_BLOCKED_SECONDS (2x TRAVEL_BLOCKED_SECONDS), the approach closes
## once as `approach_blocked` with no arrival, no work and no property change. Slow walking and a
## necessary detour keep the approach alive, because only real improvement resets the counter.
const APPROACH_ARRIVAL_RADIUS := 0.45
const APPROACH_PROGRESS_EPSILON := 0.05
const APPROACH_BLOCKED_SECONDS := 90.0
const APPROACH_BLOCKED_EVENT := "approach_blocked"
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
	for referred_skill in _known_referral_skills(observer_id, resident_id):
		if referred_skill not in result:
			result.append(referred_skill)
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

func _skill_referral_text(referred_name: String, skill_id: String) -> String:
	var template := str(SKILL_REFERRAL_TEXT.get(skill_id, "%s told me they can perform this repair."))
	return template % referred_name

func _direct_skill_notices(referrer_id: String) -> Array:
	# Read-only selection of every canonical DIRECT skill_notice that referrer_id actually received.
	# Never sourced from role hints, own skills, freeform text/speech, reply_help, or unseen notices.
	# Historical truth: does not require the referrer to be currently active, nor query the source's
	# current position or skills. Only requires a known identity for the source actor.
	var result: Array = []
	if referrer_id.is_empty() or resident(referrer_id).is_empty():
		return result
	for event in _state.life.events:
		if not event is Dictionary or event.get("type") != "skill_notice":
			continue
		if event.get("skill_id") not in SHAREABLE_SKILLS:
			continue
		if event.get("contractual", true) != false:
			continue
		var source_actor: String = str(event.get("actor_id", ""))
		if source_actor.is_empty() or source_actor == referrer_id:
			continue
		if resident(source_actor).is_empty():
			continue
		if not event.get("event_id") is String or str(event.get("event_id", "")).is_empty():
			continue
		if typeof(event.get("seq")) != TYPE_INT or int(event.get("seq", 0)) < 1:
			continue
		var recipients: Variant = event.get("recipient_ids")
		if not recipients is Array or recipients.size() != 2 or not recipients.has(source_actor) or not recipients.has(referrer_id):
			continue
		if str(event.get("subject_id", "")) != referrer_id:
			continue
		if str(event.get("text", "")) != _skill_notice_text(str(event.get("skill_id", ""))):
			continue
		result.append(event)
	return result

func _referral_source_notice(referrer_id: String, source_event_id: String) -> Dictionary:
	# Select the EXACT canonical DIRECT source notice by event id from the referrer's received notices.
	if source_event_id.is_empty():
		return {}
	for event in _direct_skill_notices(referrer_id):
		if str(event.get("event_id", "")) == source_event_id:
			return event
	return {}

func _valid_referral_record(event: Dictionary, observer_id: String) -> bool:
	# Structural attestation in world records: a referral is only valid knowledge when its own
	# event id is present, its recipient is a known identity, and it resolves to an actual original
	# DIRECT source notice whose actor/recipients/seq/skill all match. This is not a cryptographic
	# save-forgery guarantee; it is a consistency check over the recorded history.
	if not event is Dictionary or event.get("type") != "skill_referral":
		return false
	if event.get("skill_id") not in SHAREABLE_SKILLS:
		return false
	if event.get("contractual", true) != false:
		return false
	var referral_event_id: String = str(event.get("event_id", ""))
	if referral_event_id.is_empty():
		return false
	var referrer_id: String = str(event.get("actor_id", ""))
	var referred_id: String = str(event.get("referred_resident_id", ""))
	var recipient_id: String = str(event.get("subject_id", ""))
	if referrer_id.is_empty() or referred_id.is_empty() or recipient_id.is_empty():
		return false
	if referrer_id == referred_id or referrer_id == recipient_id or referred_id == recipient_id:
		return false
	if resident(referrer_id).is_empty() or resident(referred_id).is_empty() or resident(recipient_id).is_empty():
		return false
	var recipients: Variant = event.get("recipient_ids")
	if not recipients is Array or recipients.size() != 2 or not recipients.has(referrer_id) or not recipients.has(recipient_id):
		return false
	if not recipients.has(observer_id):
		return false
	var source_event_id: String = str(event.get("source_event_id", ""))
	var source_seq: int = int(event.get("source_seq", 0))
	if source_event_id.is_empty() or source_seq < 1:
		return false
	var source_notice := _referral_source_notice(referrer_id, source_event_id)
	if source_notice.is_empty():
		return false
	if str(source_notice.get("actor_id", "")) != referred_id:
		return false
	if str(source_notice.get("skill_id", "")) != str(event.get("skill_id", "")):
		return false
	if int(source_notice.get("seq", 0)) != source_seq:
		return false
	if int(event.get("seq", 0)) <= source_seq:
		return false
	return true

func _already_referred(speaker_id: String, recipient_id: String, referred_id: String, skill_id: String) -> bool:
	for event in _state.life.events:
		if event.get("type") == "skill_referral" and event.get("actor_id") == speaker_id and event.get("skill_id") == skill_id and event.get("referred_resident_id") == referred_id and event.get("recipient_ids", []).has(recipient_id):
			if _valid_referral_record(event, recipient_id):
				return true
	return false

func _known_referral_skills(observer_id: String, resident_id: String) -> Array:
	# Referral-derived skills are only usable within the existing nearby/active gates and never
	# pretend to be directly observed; they are attributed historical hearsay. Only structurally
	# valid referral records grant knowledge.
	var result: Array = []
	if observer_id == resident_id or observer_id not in active_ids() or resident_id not in active_ids():
		return result
	if position_of(observer_id).distance_to(position_of(resident_id)) > TRADE_RANGE:
		return result
	for event in _state.life.events:
		if event.get("type") != "skill_referral" or event.get("referred_resident_id") != resident_id or event.get("skill_id") not in SHAREABLE_SKILLS:
			continue
		if not event.get("recipient_ids", []).has(observer_id):
			continue
		if not _valid_referral_record(event, observer_id):
			continue
		if event.skill_id not in result:
			result.append(event.skill_id)
	return result

func _required_skill(part: String) -> String:
	return "metal_repair" if part == "edge" else "wood_repair"

func _skill_name(skill_id: String) -> String:
	# Natural, NPC-facing name of a shareable repair skill. The machine-readable id stays in the
	# structured need and in the option payload; only the spoken wording uses this name.
	return str(SKILL_ASK_NAMES.get(skill_id, "repair"))

func _skill_ask_text(skill_id: String) -> String:
	return "Can you help me with " + _skill_name(skill_id) + "?"

func _option_skill_id(option: Dictionary) -> String:
	# Named skill of a structured skill ask, read from the option's own explicit field. The
	# authoritative submit path re-validates it against public knowledge rather than trusting it.
	return str(option.get("_skill_id", ""))

func _skill_ask_need(option: Dictionary) -> Dictionary:
	# Canonical structured need of a skill ask. Never copied from the option payload: it is rebuilt
	# from the re-validated skill id so a forged payload cannot invent another kind of need.
	var skill_id: String = _option_skill_id(option)
	if skill_id not in SHAREABLE_SKILLS:
		return {}
	return {"kind": "skill", "skill_id": skill_id}

func _has_open_skill_ask(id: String, recipient_id: String, need: Dictionary) -> bool:
	# The existing open-request rule, restricted to one structured skill need. Read-only.
	return not need.is_empty() and has_open_help_request(id, recipient_id, need)

func _lesson_need(option: Dictionary) -> Dictionary:
	# Canonical structured need of a lesson request, rebuilt from the re-validated skill id so a forged
	# payload cannot name another kind of need, another skill or another case.
	var skill_id: String = _option_skill_id(option)
	if skill_id not in SHAREABLE_SKILLS:
		return {}
	return {"kind": LESSON_NEED_KIND, "skill_id": skill_id}

func _lesson_ask_text(skill_id: String) -> String:
	return "Can you teach me " + _skill_name(skill_id) + "?"

func _lesson_grounding(learner_id: String, teacher_id: String, skill_id: String) -> Dictionary:
	# The learner's OWN attributed knowledge that this very resident holds this very shareable repair
	# skill: either that resident's own DIRECT notice the learner actually received, or a structurally
	# valid referral the learner received naming that resident. Role hints, prose, public speech, the
	# learner's own skills, unseen notices, contracts and reply_help never ground a lesson. This is
	# historical attribution only: the teacher's actual current skill is checked separately.
	if learner_id.is_empty() or teacher_id.is_empty() or learner_id == teacher_id or skill_id not in SHAREABLE_SKILLS:
		return {}
	if learner_id not in active_ids() or teacher_id not in active_ids():
		return {}
	for notice in _direct_skill_notices(learner_id):
		if str(notice.get("actor_id", "")) == teacher_id and str(notice.get("skill_id", "")) == skill_id:
			return {"kind": "notice", "event_id": str(notice.get("event_id", "")), "seq": int(notice.get("seq", 0))}
	for event in _state.life.events:
		if not event is Dictionary or event.get("type") != "skill_referral":
			continue
		if str(event.get("referred_resident_id", "")) != teacher_id or str(event.get("skill_id", "")) != skill_id:
			continue
		if not event.get("recipient_ids", []).has(learner_id) or not _valid_referral_record(event, learner_id):
			continue
		return {"kind": "referral", "event_id": str(event.get("event_id", "")), "seq": int(event.get("seq", 0))}
	return {}

func _lesson_request(request_id: String) -> Dictionary:
	# Read-only selection of a recorded lesson request, including the attributed grounding it was made
	# on. Only a canonical shared ask_help carrying a lesson need plus a complete grounding record is a
	# lesson request; an ordinary, generic or skill-only ask never is.
	if request_id.is_empty():
		return {}
	for event in _state.life.events:
		if not event is Dictionary or event.get("type") != "ask_help" or str(event.get("request_id", "")) != request_id:
			continue
		var need: Variant = event.get("need")
		if not need is Dictionary or need.get("kind") != LESSON_NEED_KIND or str(need.get("skill_id", "")) not in SHAREABLE_SKILLS:
			continue
		if str(event.get("lesson_grounding_kind", "")) not in LESSON_ACTIONS:
			continue
		if str(event.get("lesson_grounding_event_id", "")).is_empty() or int(event.get("lesson_grounding_seq", 0)) < 1:
			continue
		return event
	return {}

func _lesson_blocker(learner_id: String, teacher_id: String, skill_id: String) -> String:
	# Single read-only prerequisite predicate for a minimal consensual lesson: the learner cannot
	# already do this repair, this nearby resident really holds that shareable skill, the learner
	# already received an attributed notice/referral about that resident and that skill, and both are
	# currently active inside actual hearing range. The option builder lists a lesson only while this
	# returns ""; the authoritative submit path re-derives the same answer instead of trusting the
	# option. It never mutates world state and never grants the skill by itself.
	if skill_id not in SHAREABLE_SKILLS or learner_id.is_empty() or teacher_id.is_empty() or learner_id == teacher_id:
		return "lesson_unavailable"
	if learner_id not in active_ids() or teacher_id not in active_ids():
		return "lesson_unavailable"
	if _has_skill(learner_id, skill_id) or not _has_skill(teacher_id, skill_id):
		return "lesson_unavailable"
	if position_of(learner_id).distance_to(position_of(teacher_id)) > HEARING_RANGE:
		return "lesson_unavailable"
	if _lesson_grounding(learner_id, teacher_id, skill_id).is_empty():
		return "lesson_unavailable"
	return ""

func _lesson_reply_gate(id: String, event: Dictionary) -> String:
	# "" for every ordinary or skill-only help request, so their reply path stays exactly as it was.
	# For a lesson request it returns "" only while this resident can really complete that lesson right
	# now; only then is the willing answer listed truthfully, and the authoritative submit path
	# re-derives the same answer from the stored request instead of the option payload.
	var need: Variant = event.get("need")
	if not need is Dictionary or need.get("kind") != LESSON_NEED_KIND:
		return ""
	if str(event.get("lesson_grounding_kind", "")) not in LESSON_ACTIONS or str(event.get("lesson_grounding_event_id", "")).is_empty():
		return "lesson_unavailable"
	return _lesson_blocker(str(event.get("actor_id", "")), id, str(need.get("skill_id", "")))

func _lesson_recorded(request_id: String) -> bool:
	for event in _state.life.events:
		if event is Dictionary and event.get("type") == LESSON_EVENT and str(event.get("request_id", "")) == request_id:
			return true
	return false

func _part_damaged(item: Dictionary, part: String) -> bool:
	return item.get(part, 0) < 100

func _functioning_axe(id: String) -> bool:
	for item in _legacy_array("items"):
		if item is Dictionary and item.get("kind") == "axe" and item.get("owner_id") == id and item.get("custodian_id") == id and item.get("edge", 0) == 100 and item.get("handle", 0) == 100:
			return true
	return false

func _busy(id: String) -> bool:
	return super.pending_job(id).is_empty() == false or _trade().get("jobs", {}).get(id, {}).is_empty() == false

func _held_baked_food(id: String) -> int:
	# A baked loaf is already attributed by the baking ledger. This narrow handoff moves only ordinary
	# rations, so it never silently changes who baked or owns a loaf.
	var baking: Variant = _state.godot.get("baking", {})
	if not baking is Dictionary:
		return 0
	var ledgers: Variant = baking.get("ledgers", {})
	if not ledgers is Dictionary:
		return 0
	var held := 0
	for point_value in ledgers.values():
		if not point_value is Dictionary:
			continue
		var ledger: Variant = point_value.get(id, {})
		if ledger is Dictionary:
			held += maxi(0, int(ledger.get("held", 0)))
	return held

func _ordinary_food(id: String) -> int:
	return maxi(0, int(account(id).get("food", 0)) - _held_baked_food(id)) if id in active_ids() else 0

func _food_handoff_available(id: String, recipient_id: String) -> bool:
	return id in active_ids() and recipient_id in active_ids() and id != recipient_id \
		and not _busy(id) and position_of(id).distance_to(position_of(recipient_id)) <= FOOD_HANDOFF_RANGE \
		and _ordinary_food(id) >= 1 and int(account(recipient_id).get("food", 0)) < FOOD_CAPACITY

func _repair_material_commitments(id: String, material: String) -> int:
	# Accepted and delivered contracts still owe one future unit. Completed work has already consumed
	# its unit, while cancelled/rejected/collected contracts owe none. Keep this derived from the
	# authoritative contracts so cancellation releases capacity without adding a second reservation.
	var result := 0
	for value in _legacy_array("contracts"):
		if not value is Dictionary or value.get("worker_id") != id or value.get("status") not in ["accepted", "delivered"]:
			continue
		var promised_material := "iron" if value.get("part") == "edge" else "wood"
		if promised_material == material:
			result += 1
	return result

func _available_repair_material(id: String, material: String) -> int:
	return int(_trade_account(id).get(material, -1)) - _repair_material_commitments(id, material)

func _option(result: Array, value: Dictionary) -> void:
	for existing in result:
		if existing.get("id") == value.get("id"):
			return
	result.append(value)

func _accept_blocker(id: String, contract: Dictionary) -> String:
	# Single read-only prerequisite predicate for a worker's acceptance. The option builder lists an
	# executable acceptance only while this returns ""; the authoritative submit path maps the same
	# answer back onto the codes it has always returned. It never mutates world state and it reuses
	# the existing skill/material/range/account helpers rather than a second copy of the rules.
	if contract.get("worker_id") != id or contract.get("status") != "proposed" or not _near(id, str(contract.get("owner_id", ""))):
		return "contract_unavailable"
	var owner_id: String = str(contract.get("owner_id", ""))
	var owner_account := _trade_account(owner_id)
	if owner_account.is_empty() or owner_account.get("reserved_col", -1) < 0 or resident(owner_id).coins_col < int(contract.get("price_col", -1)):
		return "funds_unavailable"
	var part: String = str(contract.get("part", ""))
	if not _has_skill(id, _required_skill(part)):
		return "skill_unavailable"
	var material := "iron" if part == "edge" else "wood"
	if _available_repair_material(id, material) < 1:
		return "material_unavailable"
	return ""

func _accept_failure_code(blocker: String) -> String:
	# Historical authoritative codes are preserved exactly; only the worker-facing explanation is
	# more specific than the single "insufficient_funds" the submit path always returned.
	return "contract_unavailable" if blocker == "contract_unavailable" else "insufficient_funds"

func _accept_explanation(contract: Dictionary, blocker: String) -> Dictionary:
	# Worker-only, read-only statement of the real missing prerequisite. It never repeats another
	# resident's private inventory, dialogue or position.
	var part: String = str(contract.get("part", ""))
	var entry := {"action": "accept", "contract_id": contract.get("id"), "counterparty": contract.get("owner_id"),
		"part": part, "price_col": contract.get("price_col", 0), "code": blocker}
	match blocker:
		"funds_unavailable":
			entry["reason"] = "Accepting a repair requires reserving its payment from the owner's wallet first. The owner cannot reserve it now, so acceptance is unavailable. You may decline or discuss it once they have enough money."
		"skill_unavailable":
			entry["reason"] = "This request needs the matching repair skill: metal_repair for the axe edge or wood_repair for the handle. You do not have that skill, so you cannot accept."
		_:
			var material := "iron" if part == "edge" else "wood"
			entry["reason"] = "Each accepted or delivered repair reserves 1 unit of " + ("iron" if part == "edge" else "wood") + ". After your unfinished commitments, less than 1 unit remains for this request, so you cannot accept. Obtain material or finish an existing commitment first."
			entry["required_material"] = material
			entry["required_quantity"] = 1
			entry["committed_quantity"] = _repair_material_commitments(str(contract.get("worker_id", "")), material)
			entry["available_quantity"] = maxi(0, _available_repair_material(str(contract.get("worker_id", "")), material))
	return entry

func _validate_communicate_need(sender_id: String, need: Variant) -> Dictionary:
	if not need is Dictionary:
		return _failure("need_invalid")
	if need.get("kind") == "skill":
		# A structured repair-skill ask names the shareable repair skill the asker needs help with.
		# It claims nothing about the asker's property and authorizes no repair or exchange.
		if not _exact_keys(need, ["kind", "skill_id"]) or not need.get("skill_id") is String or need.skill_id not in SHAREABLE_SKILLS:
			return _failure("need_invalid")
		if sender_id not in active_ids():
			return _failure("need_invalid")
		return {"ok": true}
	if need.get("kind") == LESSON_NEED_KIND:
		# A structured lesson ask names the one shareable repair skill the asker already received an
		# attributed notice/referral about. Exactly like the skill ask it claims nothing about property,
		# teaches nothing by itself and authorizes no repair, price or exchange; the grounding and the
		# teacher's separately chosen consent are re-derived when a willing answer is recorded.
		if not _exact_keys(need, ["kind", "skill_id"]) or not need.get("skill_id") is String or need.skill_id not in SHAREABLE_SKILLS:
			return _failure("need_invalid")
		if sender_id not in active_ids():
			return _failure("need_invalid")
		return {"ok": true}
	if not _exact_keys(need, ["kind", "item_id", "part"]):
		return _failure("need_invalid")
	if need.get("kind") != "repair" or not need.get("item_id") is String or need.get("part") not in ["edge", "handle"]:
		return _failure("need_invalid")
	var item := _item(need.item_id)
	if item.get("kind") != "axe" or item.get("owner_id") != sender_id or item.get("custodian_id") != sender_id or not _part_damaged(item, need.part):
		return _failure("need_invalid")
	return {"ok": true}

func _help_reply_text(id: String, event: Dictionary, choice: String) -> String:
	if not event.get("need") is Dictionary:
		return choice
	var need: Dictionary = event.need
	if need.get("kind") == LESSON_NEED_KIND:
		# A lesson request names the shareable repair skill the asker already received an attributed
		# notice about. The honest answer is about that skill and this resident's own real capability:
		# it names no part, no price and no resource, and it never claims the lesson happened.
		var lesson_name: String = _skill_name(str(need.get("skill_id", "")))
		if choice == "willing":
			return "Yes, I will teach you " + lesson_name + "." if _has_skill(id, str(need.get("skill_id", ""))) else "I cannot teach " + lesson_name + "."
		if choice == "unsure":
			return "I am not sure I can teach " + lesson_name + " right now."
		return "I am unavailable; " + ("I can do this work myself, but not right now." if _has_skill(id, str(need.get("skill_id", ""))) else "I cannot do this work myself.")
	if choice != "unavailable":
		return choice
	var skills := _skill_ids(id)
	var capabilities: Array[String] = []
	if "wood_repair" in skills:
		capabilities.append("wooden handles")
	if "metal_repair" in skills:
		capabilities.append("metal edges")
	var capability := "I have no listed repair skill" if capabilities.is_empty() else "I can repair " + " and ".join(capabilities)
	if event.need.get("kind") == "skill":
		# A skill ask names a repair skill directly. The truthful refusal must be about that skill,
		# never about a damaged axe part that the request never mentioned.
		if str(event.need.get("skill_id", "")) not in skills:
			capability += "; I cannot perform this repair"
		return "I am unavailable; " + capability + "."
	if _required_skill(str(event.need.get("part", ""))) not in skills:
		capability += "; I cannot perform this repair"
	return "I am unavailable; " + capability + "."

func _work_observed_here(id: String) -> Dictionary:
	# Read-only: answers "is this resident really working right now?" from the world's own
	# authoritative current job, the same arrival rule advance() applies, and the action's own live
	# prerequisite. An idle resident, a traveller that has not arrived, a rester and a blocked or
	# unsatisfiable action all answer no, and nothing is mutated.
	if id not in active_ids():
		return {}
	var job: Dictionary = pending_job(id)
	var action := str(job.get("action", ""))
	if action not in WORK_ACTIONS:
		return {}
	if not _valid_nonnegative(job.get("elapsed")) or float(job.get("elapsed", 0.0)) <= 0.0:
		return {}
	var target := destination(id, action)
	if not target.is_finite() or position_of(id).distance_to(target) > OBSERVE_WORK_ARRIVAL_RADIUS:
		return {}
	if not _work_prerequisite_met(id, action, job):
		return {}
	return job

func _work_prerequisite_met(id: String, action: String, job: Dictionary) -> bool:
	# Re-derives the very prerequisite the job's own completion rule applies. A material-blocked
	# action is therefore never presented as work: it is a trip that would fail, not a craft.
	match action:
		"harvest_ration":
			return _foraging_accessible(id)
		"use_tool":
			return _functioning_axe(id) and _available_repair_material(id, "wood") >= 1
		"work":
			return _repair_work_ready(id, job)
	return false

func _repair_work_ready(id: String, job: Dictionary) -> bool:
	# The same acceptance _finish_trade_job applies to a repair "work" job, read-only.
	var contract := _contract(str(job.get("contract_id", "")))
	var part := str(job.get("part", ""))
	if contract.is_empty() or str(contract.get("status", "")) != "delivered" or part not in ["edge", "handle"]:
		return false
	var item := _item(str(contract.get("item_id", "")))
	if item.get("custodian_id") != id:
		return false
	var material := "iron" if part == "edge" else "wood"
	if not _has_skill(id, _required_skill(part)) or _trade_account(id).get(material, -1) < 1 or not _part_damaged(item, part):
		return false
	if _contract_settlement(contract) != "completion":
		return true
	return _trade_account(str(contract.get("owner_id", ""))).get("reserved_col", -1) >= int(contract.get("price_col", -1))

func _observe_work_text(worker_id: String, action: String) -> String:
	# The world's own verified fact, not the observer's words: it names the resident actually seen
	# and the action it was really executing. The worker's private reason, inventory and job stay out.
	return "I saw %s working nearby: %s." % [resident_name(worker_id), action]

func _apply_work_observation(id: String, option: Dictionary, command_id: String, provenance: String) -> Dictionary:
	# The whole precondition is re-derived on submit. If the job finished, the neighbour walked away
	# or its work stopped being real, this is honestly unavailable and no fact is appended.
	var worker_id := str(option.get("_worker_id", ""))
	if _busy(id) or worker_id == id or worker_id not in active_ids():
		return _failure("option_unavailable")
	if position_of(id).distance_to(position_of(worker_id)) > OBSERVE_WORK_RANGE:
		return _failure("option_unavailable")
	var job := _work_observed_here(worker_id)
	var action := str(job.get("action", ""))
	var observed_command_id := str(job.get("command_id", ""))
	if job.is_empty() or observed_command_id.is_empty():
		return _failure("option_unavailable")
	var event := {"type": WORK_OBSERVED_EVENT, "actor_id": id, "subject_id": worker_id,
		"recipient_ids": [id], "operation_id": command_id, "source": provenance, "provenance": provenance,
		"observed_action": action, "observed_job_command_id": observed_command_id, "contractual": false,
		"text": _observe_work_text(worker_id, action)}
	_append_life_event(event)
	return {"ok": true, "code": WORK_OBSERVED_EVENT, "event_id": event.event_id, "subject_id": worker_id}

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
			if _food_handoff_available(id, other):
				_option(result, {"id": FOOD_HANDOFF_PREFIX + other,
					"label": "Give 1 of your ordinary rations to %s in person (a voluntary gift, not a trade)." % resident_name(other),
					"action": FOOD_HANDOFF_ACTION, "counterparty": other})

		for other in active_ids():
			if other == id:
				continue
			var target := _meeting_point(id, other)
			if position_of(id).distance_to(target) > APPROACH_ARRIVAL_RADIUS:
				_option(result, {"id": "approach:" + other, "label": "Approach " + resident_name(other), "action": "approach", "counterparty": other, "target_position": [target.x, target.y, target.z], "duration_seconds": WALK_SECONDS, "_target": other})

		# Voluntary work observation. Listing is pure derivation and grants nothing; the option is
		# re-derived on submit, so a job that ended or a neighbour that moved away stays unavailable.
		for other in active_ids():
			if other == id or position_of(id).distance_to(position_of(other)) > OBSERVE_WORK_RANGE:
				continue
			if _work_observed_here(other).is_empty():
				continue
			_option(result, {"id": "observe-work:" + other, "label": "Watch " + resident_name(other) + " work", "action": OBSERVE_WORK, "counterparty": other, "_worker_id": other})

		for other in active_ids():
			if other == id or not _near(id, other):
				continue
			for skill_id in SHAREABLE_SKILLS:
				if not _has_skill(id, skill_id) or _already_shared_skill(id, other, skill_id):
					continue
				_option(result, {"id": "share-skill:" + other + ":" + skill_id, "label": "Tell " + resident_name(other) + " I can repair " + ("wooden handles" if skill_id == "wood_repair" else "metal edges"), "action": "share_skill", "counterparty": other, "_skill_id": skill_id, "_decision": {"action": "share_skill", "recipient_id": other, "skill_id": skill_id, "text": _skill_notice_text(skill_id)}})

		# H22: voluntary one-hop sourced skill referral. Read-only option generation; no mutation.
		# Iterate every valid DIRECT source notice the speaker received, not just the first per skill,
		# so a speaker who heard two workers can choose which referred person to name.
		for other in active_ids():
			if other == id or position_of(id).distance_to(position_of(other)) > HEARING_RANGE:
				continue
			for source_notice in _direct_skill_notices(id):
				var skill_id: String = str(source_notice.get("skill_id", ""))
				var referred_id: String = str(source_notice.get("actor_id", ""))
				var source_event_id: String = str(source_notice.get("event_id", ""))
				var source_seq: int = int(source_notice.get("seq", 0))
				if referred_id == other or _already_referred(id, other, referred_id, skill_id):
					continue
				_option(result, {"id": "refer-skill:" + other + ":" + referred_id + ":" + skill_id + ":" + source_event_id, "label": "Tell " + resident_name(other) + " that " + resident_name(referred_id) + " told me they can repair " + ("wooden handles" if skill_id == "wood_repair" else "metal edges"), "action": "refer_skill", "counterparty": other, "_skill_id": skill_id, "_referred_id": referred_id, "_source_event_id": source_event_id, "_source_seq": source_seq, "_decision": {"action": "refer_skill", "recipient_id": other, "referred_resident_id": referred_id, "skill_id": skill_id, "source_event_id": source_event_id, "source_seq": source_seq}})

		for other in active_ids():
			if other == id or position_of(id).distance_to(position_of(other)) > HEARING_RANGE:
				continue
			if not has_open_help_request(id, other):
				_option(result, {"id": "ask:" + other, "label": "Ask " + resident_name(other) + " for help", "action": "ask_help", "counterparty": other, "_decision": {"action": "ask_help", "recipient_id": other, "text": "Can you help me?"}})
			# Structured repair-skill ask. The asker may name a skill that the world already shows as
			# public knowledge of this nearby resident; the ask itself grants no skill, no work and no
			# resource, and it never discloses the asker's private inventory or a damaged part. A skill
			# ask that is still open stays listed, because repeating it is acknowledged as the very
			# same request instead of quietly becoming a second one.
			for skill_id in _public_skills(id, other):
				if skill_id not in SHAREABLE_SKILLS:
					continue
				var need := {"kind": "skill", "skill_id": skill_id}
				_option(result, {"id": "ask-skill:" + other + ":" + skill_id,
					"label": "Ask " + resident_name(other) + " for help with " + _skill_name(skill_id),
					"action": "ask_help", "counterparty": other, "_skill_id": skill_id,
					"_decision": {"action": "ask_help", "recipient_id": other, "skill_id": skill_id, "need": need,
						"text": _skill_ask_text(skill_id)}})
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
						"label": "Ask " + resident_name(other) + " to repair " + part + " of my axe",
						"action": "ask_help", "counterparty": other,
						"_decision": {"action": "ask_help", "recipient_id": other,
							"text": "Can you repair the " + part + " of my axe?", "need": need}})

		# Minimal consensual lesson. The learner may ask a nearby resident whose own attributed
		# repair-skill notice or referral it already received to teach exactly that one skill. Listing
		# is read-only: the request itself grants no skill, no work and no resource, and the teacher
		# still answers separately. A request already open with the same need stays listed, because
		# repeating it is recorded as the very same request rather than a second one.
		for other in active_ids():
			if other == id or position_of(id).distance_to(position_of(other)) > HEARING_RANGE:
				continue
			for skill_id in SHAREABLE_SKILLS:
				if not _lesson_blocker(id, other, skill_id).is_empty():
					continue
				_option(result, {"id": "ask-teach:" + other + ":" + skill_id,
					"label": "Ask " + resident_name(other) + " to teach me " + _skill_name(skill_id),
					"action": "ask_help", "counterparty": other, "_skill_id": skill_id, "_lesson": true,
					"_decision": {"action": "ask_help", "recipient_id": other, "skill_id": skill_id,
						"need": {"kind": LESSON_NEED_KIND, "skill_id": skill_id},
						"text": _lesson_ask_text(skill_id)}})

		for event in _state.life.events:
			if event.get("type") == "visitor_inquiry" and event.get("subject_id") == id and not _request_closed(str(event.request_id)) and _visitor_position.is_finite() and _visitor_position.distance_to(position_of(id)) <= HEARING_RANGE:
				for choice in ["willing", "unavailable", "unsure"]:
					_option(result, {"id": "visitor-reply:" + str(event.request_id) + ":" + choice, "label": "Reply to the nearby player: " + choice, "action": "visitor_reply", "_request_id": event.request_id, "_choice": choice})
			if event.get("type") == "ask_help" and event.get("subject_id") == id and event.get("actor_id") in active_ids() and not _request_closed(event.request_id):
				var other: String = event.actor_id
				if position_of(id).distance_to(position_of(other)) <= HEARING_RANGE:
					var lesson_gate := _lesson_reply_gate(id, event)
					for choice in ["willing", "unavailable", "unsure"]:
						if choice == "willing" and not lesson_gate.is_empty():
							# A lesson is completed only by a willing teacher that really can teach it
							# here; while that is untrue the honest remaining answers are refusal/unsure.
							continue
						# The label names the resident whose open request this option answers, so a
						# responder holding several open asks can attribute its own reply to the right
						# asker. The label still carries the exact public text the choice would send,
						# and the alias, decision fields and recipient binding are unchanged.
						var reply_text := _help_reply_text(id, event, choice)
						_option(result, {"id": "reply:" + event.request_id + ":" + choice, "label": "Reply to " + resident_name(other) + ": " + reply_text, "action": "reply_help", "counterparty": other, "_decision": {"action": "reply_help", "recipient_id": other, "request_id": event.request_id, "choice": choice, "text": reply_text}})
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
							_option(result, {"id": "contract:offer:" + str(item_value.get("id")) + ":" + part + ":" + worker + ":" + str(price), "label": "Ask " + resident_name(worker) + " to repair " + part + " for " + str(price) + " Col; pay on collection", "action": "offer_repair", "counterparty": worker, "_item_id": item_value.get("id"), "_part": part, "_worker_id": worker, "_price": price, "_settlement": "collection"})
							if _completion_escrow_enabled():
								_option(result, {"id": "contract:completion-offer:" + str(item_value.get("id")) + ":" + part + ":" + worker + ":" + str(price), "label": "Ask " + resident_name(worker) + " to repair " + part + " for " + str(price) + " Col; pay on validated completion", "action": "offer_repair", "counterparty": worker, "_item_id": item_value.get("id"), "_part": part, "_worker_id": worker, "_price": price, "_settlement": "completion"})

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
				var settlement_label := "payment follows completed and verified work" if settlement == "completion" else "payment follows collection by the owner"
				# An acceptance is listed as an executable choice only while the authoritative submit
				# path would accept it under the current real prerequisites; otherwise the worker is
				# told the actual missing prerequisite in resident_view instead of a silent omission.
				if _accept_blocker(id, contract).is_empty():
					_option(result, {"id": "contract:accept:" + contract_id, "label": "Accept repair " + str(contract.get("part", "")) + ": payment " + str(contract.get("price_col", 0)) + " Col; reserve payment first, then work for 60 seconds after delivery; " + settlement_label, "action": "accept", "counterparty": contract.owner_id, "_contract_id": contract_id})
				_option(result, {"id": "contract:reject:" + contract_id, "label": "Decline repair " + str(contract.get("part", "")) + ", offered payment " + str(contract.get("price_col", 0)) + " Col", "action": "reject", "counterparty": contract.owner_id, "_contract_id": contract_id})
			if contract.get("worker_id") == id and contract.get("status") == "delivered" and item.get("custodian_id") == id:
				for part in ["edge", "handle"]:
					if part == contract.get("part") and _part_damaged(item, part) and _has_skill(id, _required_skill(part)) and _trade_account(id).get("iron" if part == "edge" else "wood", 0) > 0:
						_option(result, {"id": "contract:work:" + contract_id + ":" + part, "label": "Repair " + part + " of " + contract.item_id, "action": "work", "counterparty": contract.owner_id, "duration_seconds": REPAIR_SECONDS, "_contract_id": contract_id, "_part": part})

		if _functioning_axe(id) and _available_repair_material(id, "wood") >= 1:
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
	if action == FOOD_HANDOFF_ACTION:
		var handed_over := _apply_food_handoff(id, option, command_id, provenance)
		if not handed_over.ok:
			return handed_over
		commands[command_id] = {"payload": payload, "status": "completed", "result": handed_over.duplicate(true)}
		return handed_over
	if action == OBSERVE_WORK:
		# A verified, read-only sighting. Freeform speech is never accepted for it, so no observer's
		# words can ever be presented as the observed fact.
		var sighted := _apply_work_observation(id, option, command_id, provenance)
		if not sighted.ok:
			return sighted
		commands[command_id] = {"payload": payload, "status": "completed"}
		return sighted
	if action == "visitor_reply":
		var response := {"willing": "I am willing to discuss the help you need.", "unavailable": "This is not a good time. I want to handle my own matters first.", "unsure": "I have not decided yet. Let's talk later."}
		var answered := reply_to_visitor(id, option._request_id, option._choice, speech if not speech.is_empty() else response[option._choice], command_id, provenance)
		if answered.ok:
			commands[command_id] = {"payload": payload, "status": "completed"}
		return answered
	if action in ["ask_help", "reply_help", "cancel_help"]:
		# A structured skill ask carries its own named skill, so its prerequisites are re-derived and
		# then recorded through the same shared social path as every other ask. Every ordinary reply,
		# cancel and generic ask keeps that path untouched.
		if action == "ask_help" and option.get("_lesson", false):
			var lesson_asked := _apply_ask_lesson(id, option, command_id, provenance, speech)
			if not lesson_asked.ok:
				return lesson_asked
			commands[command_id] = {"payload": payload, "status": "completed"}
			return lesson_asked
		if action == "ask_help" and not _option_skill_id(option).is_empty():
			var asked := _apply_ask_skill(id, option, command_id, provenance, speech)
			if not asked.ok:
				return asked
			commands[command_id] = {"payload": payload, "status": "completed"}
			return asked
		var message: Dictionary = option._decision.duplicate(true)
		if not speech.is_empty():
			message.text = speech
		if action == "reply_help":
			var lesson := _lesson_willing_reply(id, option, command_id, provenance, message)
			if not lesson.is_empty():
				if not lesson.ok:
					return lesson
				commands[command_id] = {"payload": payload, "status": "completed"}
				return lesson
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
	if action == "refer_skill":
		var referred := _apply_skill_referral(id, option, command_id, provenance, speech)
		if not referred.ok:
			return referred
		commands[command_id] = {"payload": payload, "status": "completed"}
		return referred
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

func _apply_food_handoff(id: String, option: Dictionary, command_id: String, provenance: String) -> Dictionary:
	var recipient_id := str(option.get("counterparty", ""))
	# Re-derive every condition at submission. A moved resident, spent ration or newly full recipient
	# is an ordinary stale option, never a forced or partial transfer.
	if not _food_handoff_available(id, recipient_id):
		return _failure("option_unavailable")
	var donor_account := account(id)
	var recipient_account := account(recipient_id)
	donor_account.food = int(donor_account.food) - 1
	recipient_account.food = int(recipient_account.food) + 1
	var event := {"type": FOOD_HANDOFF_EVENT, "actor_id": id, "subject_id": recipient_id,
		"recipient_ids": [id, recipient_id], "operation_id": command_id, "source": provenance,
		"provenance": provenance, "quantity": 1, "contractual": false,
		"text": "%s gave 1 of their ordinary rations to %s in person. This was a gift, not a trade." % [resident_name(id), resident_name(recipient_id)]}
	_append_life_event(event)
	return {"ok": true, "code": FOOD_HANDOFF_EVENT, "actor_id": id, "recipient_id": recipient_id,
		"quantity": 1, "event_id": event.event_id}

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

func _apply_skill_referral(id: String, option: Dictionary, command_id: String, provenance: String, speech: String) -> Dictionary:
	var recipient_id: String = str(option.get("counterparty", ""))
	var skill_id: String = str(option.get("_skill_id", ""))
	var referred_id: String = str(option.get("_referred_id", ""))
	var source_event_id: String = str(option.get("_source_event_id", ""))
	var source_seq: int = int(option.get("_source_seq", 0))
	if skill_id not in SHAREABLE_SKILLS or recipient_id == id or referred_id == id or referred_id == recipient_id:
		return _failure("skill_referral_unavailable")
	if recipient_id not in active_ids() or position_of(id).distance_to(position_of(recipient_id)) > HEARING_RANGE:
		return _failure("skill_referral_unavailable")
	if source_event_id.is_empty() or source_seq < 1 or resident(referred_id).is_empty():
		return _failure("skill_referral_unavailable")
	# Re-validate the actual canonical DIRECT source notice by exact event id; never trust the option payload alone.
	var source_notice := _referral_source_notice(id, source_event_id)
	if source_notice.is_empty() or str(source_notice.get("actor_id", "")) != referred_id or str(source_notice.get("skill_id", "")) != skill_id or int(source_notice.get("seq", 0)) != source_seq:
		return _failure("skill_referral_unavailable")
	if _already_referred(id, recipient_id, referred_id, skill_id):
		return _failure("skill_referral_unavailable")
	var referred_name: String = str(resident(referred_id).get("name", referred_id))
	var event := {"type": "skill_referral", "actor_id": id, "subject_id": recipient_id, "recipient_ids": [id, recipient_id],
		"operation_id": command_id, "source": provenance, "provenance": provenance, "contractual": false,
		"referred_resident_id": referred_id, "skill_id": skill_id,
		"source_event_id": source_event_id, "source_seq": source_seq,
		"text": _skill_referral_text(referred_name, skill_id)}
	if not speech.is_empty():
		event["speech"] = speech
	_append_life_event(event)
	return {"ok": true, "code": "skill_referral", "skill_id": skill_id, "referred_resident_id": referred_id, "recipient_id": recipient_id, "event_id": event.event_id}

func _apply_ask_skill(id: String, option: Dictionary, command_id: String, provenance: String, speech: String) -> Dictionary:
	# Authoritative record for a structured repair-skill ask. Every prerequisite is re-derived from
	# world state instead of trusting the option payload: a known shareable skill, a currently active
	# counterparty inside hearing range, and public knowledge of that skill for the asker. It moves no
	# Col, item, material or reservation, and it cannot teach or perform the skill. The ask is then
	# recorded by the shared social path, so actor/subject/recipient attribution and the whole
	# reply/cancel lifecycle are exactly the existing ones.
	var recipient_id: String = str(option.get("counterparty", ""))
	var skill_id: String = _option_skill_id(option)
	var need := _skill_ask_need(option)
	if need.is_empty() or recipient_id == id or recipient_id not in active_ids():
		return _failure("skill_ask_unavailable")
	if position_of(id).distance_to(position_of(recipient_id)) > HEARING_RANGE:
		return _failure("skill_ask_unavailable")
	if not _public_skills(id, recipient_id).has(skill_id):
		return _failure("skill_ask_unavailable")
	if _has_open_skill_ask(id, recipient_id, need):
		# The identical request is already open: no second event is appended and no resource moves.
		return {"ok": true, "duplicate": true, "code": "help_request_pending", "skill_id": skill_id, "recipient_id": recipient_id}
	var decision := {"action": "ask_help", "recipient_id": recipient_id, "need": need, "text": _skill_ask_text(skill_id)}
	if not speech.is_empty():
		decision.text = speech
	var social := communicate(id, decision, command_id, provenance)
	if not social.ok:
		return social
	# The request itself keeps the shared ask_help shape. Only the machine-readable skill it named is
	# added to that same recorded event, so nothing about reply, cancel or attribution changes.
	for event in _state.life.events:
		if event is Dictionary and str(event.get("event_id", "")) == str(social.get("event_id", "")):
			event["skill_id"] = skill_id
			break
	return {"ok": true, "code": "ask_help", "request_id": social.get("request_id", ""), "event_id": social.get("event_id", ""),
		"skill_id": skill_id, "recipient_id": recipient_id}

func _apply_ask_lesson(id: String, option: Dictionary, command_id: String, provenance: String, speech: String) -> Dictionary:
	# Authoritative record for a minimal lesson request. Every prerequisite is re-derived from world
	# state instead of trusting the option payload: the learner's own attributed notice/referral about
	# that nearby resident's shareable repair skill, that resident really holding it, both inside actual
	# hearing range, and the learner not already able to do that repair. It moves no Col, item, material
	# or reservation and it grants no skill by itself. The ask is recorded through the shared social
	# path, so actor/subject/recipient attribution and the whole reply/cancel lifecycle are exactly the
	# existing ones; only the machine-readable need and the grounding this request rests on are added to
	# that same event, as the existing structured asks already do.
	var teacher_id: String = str(option.get("counterparty", ""))
	var skill_id: String = _option_skill_id(option)
	var need := _lesson_need(option)
	if need.is_empty() or teacher_id == id or teacher_id not in active_ids():
		return _failure("lesson_unavailable")
	if not _lesson_blocker(id, teacher_id, skill_id).is_empty():
		return _failure("lesson_unavailable")
	if has_open_help_request(id, teacher_id, need):
		# The identical lesson request is already open: recorded as the same request, no second event
		# and no resource movement.
		return {"ok": true, "duplicate": true, "code": "help_request_pending", "skill_id": skill_id, "recipient_id": teacher_id}
	var grounding := _lesson_grounding(id, teacher_id, skill_id)
	if grounding.is_empty():
		return _failure("lesson_unavailable")
	var decision := {"action": "ask_help", "recipient_id": teacher_id, "need": need, "text": _lesson_ask_text(skill_id)}
	if not speech.is_empty():
		decision.text = speech
	var social := communicate(id, decision, command_id, provenance)
	if not social.ok:
		return social
	for event in _state.life.events:
		if event is Dictionary and str(event.get("event_id", "")) == str(social.get("event_id", "")):
			event["lesson_grounding_kind"] = str(grounding.get("kind", ""))
			event["lesson_grounding_event_id"] = str(grounding.get("event_id", ""))
			event["lesson_grounding_seq"] = int(grounding.get("seq", 0))
			break
	return {"ok": true, "code": "ask_help", "request_id": social.get("request_id", ""), "event_id": social.get("event_id", ""),
		"skill_id": skill_id, "recipient_id": teacher_id}

func _lesson_willing_reply(id: String, option: Dictionary, command_id: String, provenance: String, message: Dictionary) -> Dictionary:
	# The teacher's separately chosen answer to a lesson request. It returns {} for every other reply
	# (ordinary help, a skill-only ask, or an unwilling/unsure answer), so those keep the shared path and
	# grant nothing. Only a willing answer that the authoritative state still supports completes the
	# lesson: exactly one row for exactly that one shareable repair skill is added to the learner, the
	# teacher's own rows are untouched, and no coin, material, item, contract or reserve moves. It is
	# idempotent per request id: a second willing answer for the same request acknowledges the one
	# recorded exchange instead of granting the skill twice.
	var decision: Dictionary = option.get("_decision", {})
	if str(decision.get("choice", "")) != "willing":
		return {}
	var request_id: String = str(decision.get("request_id", ""))
	var request := _lesson_request(request_id)
	if request.is_empty():
		return {}
	var skill_id: String = str(request.get("need", {}).get("skill_id", ""))
	var learner_id: String = str(request.get("actor_id", ""))
	if _lesson_recorded(request_id):
		return {"ok": true, "duplicate": true, "code": "skill_lesson_recorded", "skill_id": skill_id,
			"learner_id": learner_id, "request_id": request_id}
	if _request_closed(request_id):
		return _failure("lesson_unavailable")
	var blocker := _lesson_reply_gate(id, request)
	if not blocker.is_empty():
		return _failure(blocker)
	var reply := communicate(id, message, command_id, provenance)
	if not reply.ok:
		return reply
	# The recorded willing answer is the consent this exchange rests on; the learner's single new row is
	# its consequence, exactly the strict skill schema the world already stores.
	_state.life.skills.append({"resident_id": learner_id, "skill_id": skill_id})
	var event := {"type": LESSON_EVENT, "actor_id": id, "subject_id": learner_id, "recipient_ids": [id, learner_id],
		"operation_id": command_id, "source": provenance, "provenance": provenance, "contractual": false,
		"skill_id": skill_id, "request_id": request_id, "reply_event_id": str(reply.get("event_id", "")),
		"text": str(message.get("text", "")),
		"lesson_grounding_kind": str(request.get("lesson_grounding_kind", "")),
		"lesson_grounding_event_id": str(request.get("lesson_grounding_event_id", "")),
		"lesson_grounding_seq": int(request.get("lesson_grounding_seq", 0))}
	_append_life_event(event)
	return {"ok": true, "code": "skill_lesson", "skill_id": skill_id, "learner_id": learner_id,
		"teacher_id": id, "request_id": request_id, "event_id": event.event_id}

func _apply_trade_start(id: String, option: Dictionary, command_id: String, provenance: String) -> Dictionary:
	var action: String = option.action
	var target: String = str(option.get("counterparty", id))
	var contract_id: String = str(option.get("_contract_id", ""))
	if action in ["walk", "approach"]:
		var target_position: Array = option.get("target_position", _position_array(target))
		if action == "approach" and position_of(id).distance_to(_vector(target_position)) <= APPROACH_ARRIVAL_RADIUS:
			return {"ok": true, "code": "no_change", "changed": false}
		return _start_job(id, action, command_id, provenance, target_position, option.get("duration_seconds", WALK_SECONDS), {"target_id": target})
	if action == "use_tool":
		if not _functioning_axe(id) or _available_repair_material(id, "wood") < 1:
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
		var accept_blocker := _accept_blocker(id, contract)
		if not accept_blocker.is_empty():
			return _failure(_accept_failure_code(accept_blocker))
		var owner_account := _trade_account(contract.owner_id)
		var price: int = int(contract.price_col)
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
		if job.is_empty() or not active_ids().has(id) or position_of(id).distance_to(_vector(job.target_position)) > APPROACH_ARRIVAL_RADIUS:
			continue
		job.elapsed += delta
		if job.elapsed >= job.duration_seconds:
			var receipt := _finish_trade_job(id, job)
			completed.append(receipt)
	## After the world's own journey endings, an approach that still makes no real progress is
	## closed honestly instead of staying pending forever.
	_observe_approach_stalls(delta, completed)
	return {"ok": true, "completed": completed}

func _observe_approach_stalls(delta: float, completed: Array) -> void:
	## Physical progress observation for an ACTIVE social approach, owned by the world: the scene
	## already writes the collision-resolved body position every step, and advance() is the one
	## place that sees the pending job and the elapsed world time together. The measured quantity
	## is the same real remaining distance the job's own arrival rule uses, so arrival and
	## progress can never disagree with the close.
	var jobs: Dictionary = _trade().get("jobs", {})
	for id in jobs.keys().duplicate():
		var job: Dictionary = jobs.get(id, {})
		if job.is_empty() or str(job.get("action", "")) != "approach" or not active_ids().has(id):
			continue
		if not _valid_position(job.get("target_position")):
			continue
		var remaining := position_of(id).distance_to(_vector(job.target_position))
		if remaining <= APPROACH_ARRIVAL_RADIUS:
			## Inside the world's own arrival radius the ordinary walk rule owns this job.
			job.best_remaining = remaining
			job.progress_credit = 0.0
			job.no_progress_seconds = 0.0
			continue
		var best := float(job.get("best_remaining", INF))
		var gain := 0.0
		if is_finite(best):
			gain = maxf(0.0, best - remaining)
			job.best_remaining = best - gain
		else:
			job.best_remaining = remaining
		## Forward improvement is credited cumulatively, exactly as a blocked public trip is
		## measured: only closing the distance earns credit, and only credit that actually reaches
		## the epsilon resets the bound. Oscillation earns nothing, and a drifting mover whose whole
		## gain never reaches the epsilon still owes the world real progress: every observation the
		## epsilon does not credit counts elapsed time, however small its positive gain.
		var credit := float(job.get("progress_credit", 0.0)) + gain
		var credited := false
		while credit >= APPROACH_PROGRESS_EPSILON:
			credit -= APPROACH_PROGRESS_EPSILON
			credited = true
		job.progress_credit = credit
		if credited:
			job.no_progress_seconds = 0.0
			continue
		job.no_progress_seconds = float(job.get("no_progress_seconds", 0.0)) + delta
		if float(job.no_progress_seconds) >= APPROACH_BLOCKED_SECONDS:
			completed.append(_close_blocked_approach(id, job))

func _close_blocked_approach(id: String, job: Dictionary) -> Dictionary:
	## One bounded, honest failure of an active approach: the pending job is erased, its own
	## command is rejected and the mover receives exactly one personal event. No arrival receipt,
	## no work, no coin, item or stock change, and no other resident is touched or moved.
	## The durable personal fact stays a plain, string-only record of what happened to the mover.
	## The measured distance and no-progress seconds are physical diagnostics; they belong to the
	## world-scoped journey projection the background GMs already read, never as raw coordinates
	## inside a resident's own experience.
	var command_id := str(job.get("command_id", ""))
	var provenance := str(job.get("provenance", "local_rule_policy"))
	var target_id := str(job.get("target_id", ""))
	var trade := _ensure_trade()
	trade.jobs.erase(id)
	var receipt := {"ok": false, "code": APPROACH_BLOCKED_EVENT, "actor_id": id, "command_id": command_id}
	if trade.commands.has(command_id):
		trade.commands[command_id].status = "rejected"
		trade.commands[command_id].result = receipt.duplicate(true)
	var text := "I could not complete the approach. I stopped without arriving."
	if target_id in active_ids():
		text = "I could not reach %s. I stopped without arriving." % resident_name(target_id)
	_append_life_event({"type": APPROACH_BLOCKED_EVENT, "actor_id": id, "subject_id": id, "recipient_ids": [id],
		"operation_id": command_id, "command_id": command_id, "source": provenance, "provenance": provenance,
		"contractual": false, "target_id": target_id, "text": text})
	return receipt

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
			# Recheck the same uncommitted balance at completion. A stale pending tool job cannot consume
			# wood that a later/legacy accepted repair contract now owes.
			ok = _functioning_axe(id) and _available_repair_material(id, "wood") >= 1
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
	var known_referrals: Array = []
	for event in _state.life.events:
		if event.get("type") != "skill_referral" or event.get("skill_id") not in SHAREABLE_SKILLS or not event.get("recipient_ids", []).has(id) or event.get("actor_id") == id:
			continue
		if not _valid_referral_record(event, id):
			continue
		var referrer_id: String = str(event.get("actor_id", ""))
		var referred_resident_id: String = str(event.get("referred_resident_id", ""))
		# Attributed historical record: original source identity and date reference, no transcript,
		# no current availability, no position, no resources. Survives A inactive/far/skill removal.
		known_referrals.append({"referrer_id": referrer_id, "referred_resident_id": referred_resident_id,
			"skill_id": event.get("skill_id", ""), "referral_event_id": event.get("event_id", ""),
			"seq": event.get("seq", 0), "source_event_id": event.get("source_event_id", ""),
			"source_seq": event.get("source_seq", 0), "provenance": event.get("provenance", ""),
			"text": event.get("text", "")})
	view["known_skill_referrals"] = known_referrals
	view["contracts"] = own_contracts
	view["life_account"] = _trade_account(id).duplicate(true)
	view["wallet"] = {"coins_col": resident(id).get("coins_col", 0)}
	view["trade_settlement_terms"] = {"legacy_default": "collection", "completion_escrow": "completion" if _completion_escrow_enabled() else "unavailable"}
	view["known_rules"] = {"axe_use": "To make 1 kindling, you must hold your own hatchet with both edge and handle at 100, stand at your own workstation and consume 1 wood. Repairing only one part is not enough.",
		"basic_needs": "satiety=0 or energy=0 does not itself prevent movement or listed actions such as rest and harvest_ration. Choose only from available_actions. Position, busy state and real resources are checked again on submission and arrival. harvest_ration permits an attempt to reach the public foraging point; it does not guarantee remaining stock or a successful harvest.",
		"communication": "Your reason is private and is not automatically spoken. General help only asks whether someone is available; a repair request naming the tool and part conveys the specific problem. willing means willingness to talk, not acceptance of a paid job. wood_repair repairs wooden handles and metal_repair repairs metal axe edges. Each person chooses whether to help.",
		"repair": "price_col is the fixed total payment in Col for this repair, not a unit price or estimate; there are no other rates. Legacy contracts and ordinary offers use settlement=collection: acceptance moves that amount from the owner's wallet into reserved funds, delivery permits 60 seconds of work, and payment transfers to the worker only when the owner collects the repaired tool. If an offered contract says completion, the same reservation, delivery and 60 seconds of work apply, but payment transfers only after consuming material and restoring the part to 100; collection returns the tool without paying again. Edge repair consumes 1 of the worker's iron, handle repair 1 wood. You may decline because of time, materials or the risk of delayed collection. Willingness to talk is not contract acceptance."}

	view["unavailable_actions"] = []
	for item in own_items:
		if item.get("kind") == "axe" and item.get("owner_id") == id:
			if item.edge < 100 or item.handle < 100:
				view.unavailable_actions.append({"action": "use_tool", "item_id": item.id,
					"reason": "The tool still needs repair.", "edge": item.edge, "handle": item.handle, "required_each": 100})
			if item.get("custodian_id") != id:
				view.unavailable_actions.append({"action": "use_tool", "item_id": item.id,
					"reason": "You own the tool but do not currently hold it. Collect it before using it.", "custodian_id": item.get("custodian_id")})
	for contract in own_contracts:
		if contract.get("owner_id") != id or contract.get("worker_id") not in active_ids():
			continue
		if contract.get("status") in ["accepted", "completed"] and not _near(id, contract.worker_id):
			var action := "collect" if contract.status == "completed" else "deliver"
			view.unavailable_actions.append({"action": action, "contract_id": contract.id, "counterparty": contract.worker_id,
				"reason": "Delivery and collection require both people to be within 3 meters. You are not near the worker; approach them first. The handoff is unavailable, not still processing."})
	for contract in own_contracts:
		if contract.get("worker_id") != id or contract.get("status") != "proposed":
			continue
		# Truthful personal feedback: an acceptance that the authoritative path would refuse is not
		# offered as an executable choice, and the worker is told the real missing prerequisite.
		var accept_blocker := _accept_blocker(id, contract)
		if accept_blocker.is_empty() or accept_blocker == "contract_unavailable":
			continue
		view.unavailable_actions.append(_accept_explanation(contract, accept_blocker))
	for contract in own_contracts:
		if contract.get("worker_id") != id or contract.get("status") != "delivered":
			continue
		var item := _item(str(contract.get("item_id", "")))
		var part: String = str(contract.get("part", ""))
		var material := "iron" if part == "edge" else "wood"
		# This is the worker's own current shortfall after an already accepted hand-off. It explains why
		# the work option is absent without exposing the owner's inventory or inventing a cancellation.
		if item.get("custodian_id") == id and _part_damaged(item, part) and _has_skill(id, _required_skill(part)) and _trade_account(id).get(material, -1) < 1:
			view.unavailable_actions.append({"action": "work", "contract_id": contract.id,
				"counterparty": contract.owner_id, "part": part, "code": "material_unavailable",
				"reason": "The tool has been delivered, but work requires 1 unit of your own " + ("iron" if part == "edge" else "wood") + ". You have less than 1, so work cannot begin. Obtain the material first.",
				"required_material": material, "required_quantity": 1})
	var public_roles: Array = []
	for other in active_ids():
		if other == id or position_of(id).distance_to(position_of(other)) > HEARING_RANGE:
			continue
		var skills := _public_skills(id, other)
		if not skills.is_empty():
			public_roles.append({"id": other, "name": resident_name(other), "role": resident(other).role, "skills": skills})
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
