extends "res://core/town_places.gd"
## Bounded public baking route for the whole town (capability `public_baking_route`).
##
## One reviewed, installable public baking point: a fixed public flour stock plus the world's own
## voluntary elapsed bake. The module adds exactly one resident-owned outcome - one unit of the
## resident's own eatable food, attributed in that point's own ledger as a held loaf - and it never
## grants a skill, an item, a material or a coin.
##
## Boundaries held here:
##  - a point exists only through one reviewed `development_gm:` install that cites a real delivered
##    public ask, so an unattributed or resident-issued install changes nothing at all;
##  - a resident learns a point only from its OWN line-of-sight observation (the town street binds
##    the real physics probe, a headless fixture binds a deterministic one), so an install never
##    broadcasts anything and a distant, blocked or unknown resident gains neither fact nor option;
##  - flour is finite and never regenerates: starting a bake reserves exactly one unit, a completed
##    bake turns that reservation into one loaf, and a loaf the resident really eats is attributed in
##    the same ledger. Conservation therefore holds exactly across remaining + reserved + held +
##    eaten flour for every point, on every load;
##  - the bake command lives in its own `godot.baking.commands` journal, and its command id must be
##    free in trade, life, materials, places and baking, so the host's fixed journal order (trade,
##    life, materials, baking, places) resolves the bake receipt unambiguously and first-match only;
##  - the terminal receipt carries capability_id, actor_id, command_id and route_id, so only a later
##    ordinary action of the resident can ever claim adoption.
##
## A held loaf is always backed by one unit of the resident's real food account (the world's own
## eatable supply, which town_life caps at two units), and validation rejects a ledger that claims
## more loaves than the account really holds. No decorative bread counter exists.
const BAKING_SCHEMA_VERSION := 1
const BAKING_CAPABILITY_ID := "public_baking_route"
const BAKING_VERSION := "1.0.0"
const BAKING_ROUTE_ID := "public_baking_route:v1"
const BAKING_MANIFEST := "res://capabilities/baking_route.v1.json"
const BAKING_WORK_SECONDS := 60.0
const BAKING_FLOUR_LIMIT := 100
const BAKING_POINT_LIMIT := 8
const BAKING_OBSERVATION_RANGE := 4.5
const BAKING_ARRIVAL_RADIUS := 0.45
const BAKING_WORK_OFFSET := Vector3(0.0, 0.0, 0.85)
const BAKING_ACTION := "bake_bread"
const BAKING_OPTION_PREFIX := "baking:bake:"
## The world's own food rule (town_life) caps one resident's eatable supply at two units, and a
## loaf occupies one of those units: the bake is offered and started only while the resident can
## really hold it.
const BAKING_FOOD_CAPACITY := 2
const BAKING_EVENT_TYPES := ["baking_route_installed", "baking_route_superseded", "baking_point_observed", "bread_baked", "bread_eaten", "baking_failed"]
const BAKING_NEED_EVENT_TYPES := ["ask_help", "reply_help", "visitor_reply"]
const BAKING_STATE_KEYS := ["schema_version", "points", "known", "jobs", "commands", "installs", "ledgers"]
const BAKING_JOURNALS := ["trade", "materials", "places"]

var _baking_visibility_probe: Callable = Callable()
var _baking_visibility_required := true

func require_baking_visibility(probe: Callable) -> void:
	# The host must explicitly bind a line-of-sight probe. Missing and invalid probes fail closed,
	# including in headless fixtures; proximity by itself never grants knowledge.
	_baking_visibility_required = true
	_baking_visibility_probe = probe

func _baking() -> Dictionary:
	var value: Variant = _state.godot.get("baking", {})
	return value if value is Dictionary else {}

func _ensure_baking() -> Dictionary:
	if not _state.godot.get("baking", null) is Dictionary:
		_state.godot.baking = {"schema_version": BAKING_SCHEMA_VERSION, "points": {}, "known": {},
			"jobs": {}, "commands": {}, "installs": {}, "ledgers": {}}
	return _state.godot.baking

func baking_points() -> Array:
	# Read-only projection: the caller receives copies and cannot mutate the world through it.
	var points: Dictionary = _baking().get("points", {})
	var keys: Array = points.keys()
	keys.sort()
	var result: Array = []
	for key in keys:
		var point: Variant = points[key]
		if point is Dictionary:
			result.append(point.duplicate(true))
	return result

func baking_ledger(id: String) -> Dictionary:
	# The resident's own bread only: loaves this route made that the resident still holds, and
	# loaves it has really eaten. Derived from the per-point ledgers, never stored a second time.
	var result := {"held": 0, "eaten": 0}
	var ledgers: Dictionary = _baking().get("ledgers", {})
	for point_id in ledgers:
		var point_ledger: Variant = ledgers[point_id]
		if not point_ledger is Dictionary:
			continue
		var ledger: Variant = point_ledger.get(id, {})
		if ledger is Dictionary:
			result.held = int(result.held) + int(ledger.get("held", 0))
			result.eaten = int(result.eaten) + int(ledger.get("eaten", 0))
	return result

func _valid_baking_spec(spec: Dictionary) -> bool:
	if not _exact_keys(spec, ["id", "label", "initial_flour", "position", "access"]):
		return false
	if not spec.id is String or spec.id.length() > 64 or not _validate_decision_command_id(spec.id).ok or not spec.label is String or spec.label.strip_edges().is_empty() or spec.label.length() > 80:
		return false
	if spec.access != "public" or not _bounded(spec.initial_flour, BAKING_FLOUR_LIMIT) or spec.initial_flour < 1 or not _valid_position(spec.position):
		return false
	var point := _vector(spec.position)
	return absf(point.x) <= 64 and absf(point.z) <= 64 and point.y >= 0 and point.y <= 2

func _same_baking_spec(left: Variant, right: Variant) -> bool:
	if not left is Dictionary or not right is Dictionary:
		return false
	var first: Dictionary = left
	var second: Dictionary = right
	if not _exact_keys(first, ["id", "label", "initial_flour", "position", "access"]) or not _exact_keys(second, ["id", "label", "initial_flour", "position", "access"]):
		return false
	if str(first.id) != str(second.id) or str(first.label) != str(second.label) or str(first.access) != str(second.access):
		return false
	if int(first.initial_flour) != int(second.initial_flour):
		return false
	return _vector(first.position) == _vector(second.position)

func _load_baking_manifest() -> Variant:
	var file := FileAccess.open(BAKING_MANIFEST, FileAccess.READ)
	if file == null:
		return null
	return JSON.parse_string(file.get_as_text())

func _validate_baking_manifest(manifest: Variant) -> Dictionary:
	# The reviewed module fixes the route's own shape: one flour becomes one loaf in one elapsed
	# bake, and the install grants nothing at all.
	if not manifest is Dictionary or not _exact_keys(manifest, ["schema_version", "capability_id", "version", "kind", "description", "route_id", "work_seconds_per_loaf", "inputs", "outputs", "grants", "conservation_terms"]):
		return _failure("malformed_baking_route_module")
	if manifest.schema_version != 1 or manifest.capability_id != BAKING_CAPABILITY_ID or manifest.version != BAKING_VERSION or manifest.kind != "public_work_point" or manifest.route_id != BAKING_ROUTE_ID:
		return _failure("malformed_baking_route_module")
	if not manifest.description is String or manifest.description.strip_edges().is_empty() or not is_equal_approx(float(manifest.work_seconds_per_loaf), BAKING_WORK_SECONDS):
		return _failure("malformed_baking_route_module")
	var inputs: Variant = manifest.inputs
	var outputs: Variant = manifest.outputs
	var grants: Variant = manifest.grants
	if not inputs is Dictionary or not _exact_keys(inputs, ["flour"]) or inputs.flour != 1:
		return _failure("malformed_baking_route_module")
	if not outputs is Dictionary or not _exact_keys(outputs, ["loaf"]) or outputs.loaf != 1:
		return _failure("malformed_baking_route_module")
	if not grants is Dictionary or not _exact_keys(grants, ["skill", "inventory", "coin"]) or grants.skill != false or grants.inventory != false or grants.coin != false:
		return _failure("malformed_baking_route_module")
	var terms: Variant = manifest.conservation_terms
	if not terms is Array or terms != ["remaining_flour", "reserved_flour", "held_loaves", "eaten_loaves"]:
		return _failure("malformed_baking_route_module")
	return {"ok": true, "code": "baking_route_module_valid"}

func _baking_need(seq: int) -> Dictionary:
	for event in _state.life.events:
		if not event is Dictionary or event.get("seq") != seq or not BAKING_NEED_EVENT_TYPES.has(str(event.get("type", ""))):
			continue
		var actor := str(event.get("actor_id", ""))
		var text := str(event.get("text", ""))
		if actor in active_ids() and not text.strip_edges().is_empty():
			return {"seq": seq, "actor_id": actor, "text": text}
	return {}

func _journal_has_command(command_id: String) -> bool:
	# An exhaustive, named check of exactly the five known journals plus this module's own install
	# ledger. No arbitrary journal is ever scanned.
	if _state.godot.get("commands", {}).has(command_id):
		return true
	for journal_name in BAKING_JOURNALS:
		var record: Variant = _state.godot.get(journal_name, {})
		var commands: Variant = record.get("commands", {}) if record is Dictionary else {}
		if commands is Dictionary and commands.has(command_id):
			return true
	var baking := _baking()
	return baking.get("commands", {}).has(command_id) or baking.get("installs", {}).has(command_id)

func install_baking_route(spec: Dictionary, source_seq: int, command_id: String) -> Dictionary:
	# Host-reviewed installation of one public baking point. Nothing is granted to any save: no
	# skill, no item, no material, no coin and no stock beyond the reviewed finite flour.
	if not command_id.begins_with(HOST_REVIEWER_PREFIX) or not _validate_decision_command_id(command_id).ok:
		return _failure("development_gm_required")
	if not _valid_baking_spec(spec):
		return _failure("invalid_baking_point")
	var payload := {"spec": spec.duplicate(true), "source_seq": source_seq, "route_id": BAKING_ROUTE_ID}
	var baking := _baking()
	var old: Dictionary = baking.get("installs", {}).get(command_id, {})
	if not old.is_empty():
		var prior: Dictionary = old.get("payload", {})
		var same: bool = prior.get("source_seq") == source_seq and prior.get("route_id") == BAKING_ROUTE_ID and _same_baking_spec(prior.get("spec", {}), spec)
		return {"ok": same, "duplicate": same, "code": "duplicate" if same else "command_conflict"}
	var module := _validate_baking_manifest(_load_baking_manifest())
	if not module.ok:
		return module
	var need := _baking_need(source_seq)
	if need.is_empty():
		return _failure("source_need_missing")
	if _journal_has_command(command_id):
		return _failure("command_conflict")
	var points: Dictionary = baking.get("points", {})
	if points.has(spec.id):
		return _failure("baking_point_conflict")
	if points.size() >= BAKING_POINT_LIMIT:
		return _failure("baking_point_capacity")
	var store := _ensure_baking()
	var point := spec.duplicate(true)
	point.flour_remaining = spec.initial_flour
	point.install_command = command_id
	point.source_need = need
	store.points[spec.id] = point
	store.installs[command_id] = {"payload": payload}
	_append_life_event({"type": "baking_route_installed", "actor_id": "development_gm", "subject_id": need.actor_id,
		"recipient_ids": [], "operation_id": command_id, "source": "development_gm_review",
		"capability_id": BAKING_CAPABILITY_ID, "route_id": BAKING_ROUTE_ID, "point_id": spec.id,
		"source_seq": source_seq, "initial_flour": spec.initial_flour, "contractual": false,
		"text": "公共烤炉已就位。"})
	return {"ok": true, "code": "baking_route_installed", "capability_id": BAKING_CAPABILITY_ID,
		"route_id": BAKING_ROUTE_ID, "point_id": spec.id}

func _baking_point_unused(point_id: String, point: Dictionary) -> bool:
	# Replacement is deliberately narrower than removal: only a never-discovered, never-used
	# installation with all of its original flour may move. Empty-looking historical containers
	# still count as use so this operation can never erase ambiguous evidence.
	if int(point.get("flour_remaining", -1)) != int(point.get("initial_flour", -2)):
		return false
	var baking := _baking()
	for id in baking.get("known", {}):
		var known: Variant = baking.known[id]
		if known is Dictionary and known.has(point_id):
			return false
	for id in baking.get("jobs", {}):
		var job: Variant = baking.jobs[id]
		if job is Dictionary and str(job.get("point_id", "")) == point_id:
			return false
	for command_id in baking.get("commands", {}):
		var command: Variant = baking.commands[command_id]
		var payload: Variant = command.get("payload", {}) if command is Dictionary else {}
		if payload is Dictionary and str(payload.get("point_id", "")) == point_id:
			return false
	if baking.get("ledgers", {}).has(point_id):
		return false
	for event in _state.life.events:
		if event is Dictionary and str(event.get("point_id", "")) == point_id \
				and str(event.get("type", "")) in ["baking_point_observed", "bread_baked", "bread_eaten", "baking_failed"]:
			return false
	return true

func _matching_baking_supersession(command_id: String, old_point_id: String, new_point_id: String) -> bool:
	var matches := 0
	for event in _state.life.events:
		if event is Dictionary and event.get("type") == "baking_route_superseded" \
				and event.get("operation_id") == command_id and event.get("point_id") == old_point_id \
				and event.get("replacement_point_id") == new_point_id:
			matches += 1
	return matches == 1

func replace_unused_baking_route(old_point_id: String, spec: Dictionary, source_seq: int, command_id: String) -> Dictionary:
	# One bounded correction for an unused reviewed placement. The old install record and install
	# event remain immutable history; only its never-used active projection is superseded. The new
	# reviewed point receives exactly the same finite flour and cites exactly the same public need.
	if not command_id.begins_with(HOST_REVIEWER_PREFIX) or not _validate_decision_command_id(command_id).ok:
		return _failure("development_gm_required")
	if not _valid_baking_spec(spec) or old_point_id.is_empty() or str(spec.id) == old_point_id:
		return _failure("invalid_baking_replacement")
	var baking := _baking()
	var prior_install: Dictionary = baking.get("installs", {}).get(command_id, {})
	if not prior_install.is_empty():
		var payload: Variant = prior_install.get("payload", {})
		var replacement: Variant = baking.get("points", {}).get(str(spec.id), {})
		var same: bool = payload is Dictionary and payload.get("source_seq") == source_seq \
			and payload.get("route_id") == BAKING_ROUTE_ID and _same_baking_spec(payload.get("spec", {}), spec) \
			and not baking.get("points", {}).has(old_point_id) and replacement is Dictionary \
			and _same_baking_spec(_point_spec(replacement), spec) \
			and _matching_baking_supersession(command_id, old_point_id, str(spec.id))
		return {"ok": same, "duplicate": same, "code": "duplicate" if same else "command_conflict"}
	if _journal_has_command(command_id):
		return _failure("command_conflict")
	var old: Variant = baking.get("points", {}).get(old_point_id, {})
	if not old is Dictionary or old.is_empty():
		return _failure("baking_point_missing")
	if baking.points.has(str(spec.id)):
		return _failure("baking_point_conflict")
	if int(old.get("initial_flour", -1)) != int(spec.initial_flour) \
			or int(old.get("flour_remaining", -1)) != int(spec.initial_flour):
		return _failure("baking_replacement_flour_changed")
	var old_need: Variant = old.get("source_need", {})
	if not old_need is Dictionary or int(old_need.get("seq", -1)) != source_seq:
		return _failure("baking_replacement_source_changed")
	if not _baking_point_unused(old_point_id, old):
		return _failure("baking_point_used")
	var old_install_command := str(old.get("install_command", ""))
	var installed := install_baking_route(spec, source_seq, command_id)
	if not installed.ok:
		return installed
	_ensure_baking().points.erase(old_point_id)
	_append_life_event({"type": "baking_route_superseded", "actor_id": "development_gm", "recipient_ids": [],
		"operation_id": command_id, "source": "development_gm_review", "capability_id": BAKING_CAPABILITY_ID,
		"route_id": BAKING_ROUTE_ID, "point_id": old_point_id, "replacement_point_id": str(spec.id),
		"superseded_install_command": old_install_command, "source_seq": source_seq,
		"initial_flour": int(spec.initial_flour), "text": "未使用的公共烤炉位置已由审查后的新位置替代。"})
	return {"ok": true, "code": "baking_route_replaced", "capability_id": BAKING_CAPABILITY_ID,
		"route_id": BAKING_ROUTE_ID, "point_id": str(spec.id), "superseded_point_id": old_point_id}

func _known_baking(id: String) -> Dictionary:
	var known: Variant = _baking().get("known", {}).get(id, {})
	return known if known is Dictionary else {}

func _baking_point_visible(id: String, point_id: String) -> bool:
	if not _baking_visibility_required:
		return false
	if not _baking_visibility_probe.is_valid():
		return false
	var verdict: Variant = _baking_visibility_probe.call(id, point_id)
	return verdict if verdict is bool else false

func _observe_baking() -> void:
	# One personal, attributed observation per resident and point, and only while that resident's
	# own sight really reaches the point. An install therefore broadcasts nothing to anyone.
	if not _state.godot.has("baking"):
		return
	for id in active_ids():
		for point in baking_points():
			var point_id := str(point.get("id", ""))
			if position_of(id).distance_to(_vector(point.position)) > BAKING_OBSERVATION_RANGE:
				continue
			var previous: Dictionary = _known_baking(id).get(point_id, {})
			if previous.get("flour_remaining", -1) == point.flour_remaining:
				continue
			if not _baking_point_visible(id, point_id):
				continue
			var store := _ensure_baking()
			if not store.known.has(id):
				store.known[id] = {}
			var observation_source := "host_line_of_sight_observation" if _baking_visibility_required else "host_proximity_observation"
			_append_life_event({"type": "baking_point_observed", "actor_id": id, "recipient_ids": [id],
				"operation_id": "baking-observation:%s:%s:%d" % [id, point_id, int(_state.life.seq) + 1],
				"source": observation_source, "point_id": point_id, "flour_remaining": point.flour_remaining,
				"text": "%s：公共面粉还剩%d份；烤一份要%d秒，烤好得到自己的一口粮。" % [str(point.label), int(point.flour_remaining), int(BAKING_WORK_SECONDS)]})
			store.known[id][point_id] = {"flour_remaining": point.flour_remaining,
				"observed_elapsed": _state.godot.elapsed_seconds, "event_seq": _state.life.seq}

func _busy(id: String) -> bool:
	return not _baking().get("jobs", {}).get(id, {}).is_empty() or super._busy(id)

func pending_job(id: String) -> Dictionary:
	var job: Dictionary = _baking().get("jobs", {}).get(id, {})
	return job.duplicate(true) if not job.is_empty() else super.pending_job(id)

func destination(id: String, action: String) -> Vector3:
	var job: Dictionary = _baking().get("jobs", {}).get(id, {})
	if not job.is_empty() and action == BAKING_ACTION:
		var point: Dictionary = _baking().get("points", {}).get(str(job.get("point_id", "")), {})
		if not point.is_empty() and _valid_position(point.get("position")):
			# The oven mesh faces +Z. Work from the public apron in front of its mouth, rather than
			# steering a resident into the visual's centre.
			return _vector(point.position) + BAKING_WORK_OFFSET
	return super.destination(id, action)

func _personal_attempt_found_no_flour(id: String, point_id: String) -> bool:
	# Compatibility for saves written before failed bake attempts became observations. The resident's
	# own durable turn receipt is still authoritative personal evidence, and public flour never
	# replenishes, so it is sufficient to suppress this one stale option without changing the save.
	var turns: Variant = _state.godot.get("resident_turns", {})
	if not turns is Dictionary:
		return false
	var record: Variant = turns.get(id, {})
	if not record is Dictionary:
		return false
	var option_id := BAKING_OPTION_PREFIX + point_id
	var entries: Array = record.get("history", []).duplicate() if record.get("history", []) is Array else []
	entries.append(record)
	for entry in entries:
		if not entry is Dictionary or str(entry.get("action", "")) != option_id:
			continue
		var receipt: Variant = entry.get("result", {})
		if receipt is Dictionary and str(receipt.get("code", "")) == "flour_unavailable":
			return true
	return false

func trade_options(id: String) -> Array:
	var result := super.trade_options(id)
	if id not in active_ids() or not _state.godot.has("baking") or _busy(id):
		return result
	# The resident must be able to hold the loaf in its own eatable supply; the world's own cap
	# is two units, so a full resident is honestly not offered the bake.
	if int(account(id).get("food", 0)) >= BAKING_FOOD_CAPACITY:
		return result
	var known := _known_baking(id)
	for point_id in known:
		var point: Dictionary = _baking().get("points", {}).get(str(point_id), {})
		var observation: Dictionary = known.get(point_id, {})
		if point.is_empty() or int(observation.get("flour_remaining", 0)) < 1 \
				or _personal_attempt_found_no_flour(id, str(point_id)):
			continue
		_option(result, {"id": BAKING_OPTION_PREFIX + str(point_id), "action": BAKING_ACTION,
			"label": "用%s的1份公共面粉烤一个自己的面包：站到炉边烤%d秒（面粉有限，烤好就能自己吃）" % [str(point.label), int(BAKING_WORK_SECONDS)],
			"speech_allowed": false, "point_id": str(point_id)})
	return result

func submit_trade(id: String, option_id: String, command_id: String, provenance: String = "local_rule_policy", speech: String = "") -> Dictionary:
	if not option_id.begins_with("baking:"):
		# All trade/material/place decisions enter through this public method. Reserve a baking
		# command id before delegating so another journal cannot claim it in the reverse direction.
		if _baking_command_reserved(command_id):
			return _failure("command_conflict")
		return super.submit_trade(id, option_id, command_id, provenance, speech)
	if id not in active_ids() or not _validate_decision_command_id(command_id).ok or provenance not in ALLOWED_DECISION_PROVENANCE:
		return _failure("invalid_actor_command_or_provenance")
	if not speech.is_empty():
		return _failure("speech_not_supported_for_action")
	if not option_id.begins_with(BAKING_OPTION_PREFIX):
		return _failure("option_unavailable")
	return _start_bake(id, option_id.trim_prefix(BAKING_OPTION_PREFIX), command_id, provenance)

func start_action(id: String, action: String, command_id: String, provenance: String = "local_rule_policy", target_position: Vector3 = Vector3.INF) -> Dictionary:
	# Direct life commands are the other public decision entry. Together with submit_trade this
	# prevents a completed or pending baking command from being reused by any of the four journals.
	if _baking_command_reserved(command_id):
		return _failure("command_conflict")
	return super.start_action(id, action, command_id, provenance, target_position)

func _baking_command_reserved(command_id: String) -> bool:
	var baking := _baking()
	return baking.get("commands", {}).has(command_id) or baking.get("installs", {}).has(command_id)

func _start_bake(id: String, point_id: String, command_id: String, provenance: String) -> Dictionary:
	var payload := {"actor_id": id, "action": BAKING_ACTION, "point_id": point_id, "provenance": provenance}
	var baking := _baking()
	var old: Dictionary = baking.get("commands", {}).get(command_id, {})
	if not old.is_empty():
		var same: bool = old.get("payload") == payload
		return {"ok": same, "duplicate": same, "code": "duplicate" if same else "command_conflict"}
	if _journal_has_command(command_id):
		return _failure("command_conflict")
	var option_id := BAKING_OPTION_PREFIX + point_id
	if not trade_options(id).any(func(option): return option.id == option_id):
		return _failure("option_unavailable")
	var store := _ensure_baking()
	var point: Dictionary = store.points[point_id]
	if int(point.flour_remaining) < 1:
		# The resident already knew this point and just attempted its offered action. Preserve the
		# authoritative rejection as personal feedback: no remote discovery or broadcast occurs,
		# but this resident no longer receives the same stale bake option on the next bounded turn.
		_append_life_event({"type": "baking_point_observed", "actor_id": id, "recipient_ids": [id],
			"operation_id": command_id, "source": "resident_bake_attempt_feedback", "point_id": point_id,
			"flour_remaining": 0, "text": "%s：我这次尝试时得知公共面粉已经用完。" % str(point.label)})
		store.known[id][point_id] = {"flour_remaining": 0,
			"observed_elapsed": _state.godot.elapsed_seconds, "event_seq": _state.life.seq}
		return _failure("flour_unavailable")
	# The reservation is the world's own pending input: the flour leaves the public stock here and
	# can only become a loaf, or return to the stock if the bake honestly cannot hand one over.
	store.points[point_id].flour_remaining = int(point.flour_remaining) - 1
	store.commands[command_id] = {"payload": payload, "status": "pending"}
	store.jobs[id] = {"action": BAKING_ACTION, "command_id": command_id, "point_id": point_id,
		"provenance": provenance, "elapsed": 0.0, "duration_seconds": BAKING_WORK_SECONDS, "reserved_flour": 1}
	return {"ok": true, "code": "bake_started", "pending": true, "point_id": point_id, "capability_id": BAKING_CAPABILITY_ID}

func _ensure_loaf_ledger(baking: Dictionary, point_id: String, id: String) -> Dictionary:
	if not baking.ledgers.get(point_id, null) is Dictionary:
		baking.ledgers[point_id] = {}
	if not baking.ledgers[point_id].get(id, null) is Dictionary:
		baking.ledgers[point_id][id] = {"held": 0, "eaten": 0}
	return baking.ledgers[point_id][id]

func _finish_bake(id: String, job: Dictionary, point: Dictionary) -> Dictionary:
	var baking := _ensure_baking()
	var command_id := str(job.get("command_id", ""))
	var point_id := str(point.get("id", ""))
	var reserved := int(job.get("reserved_flour", 0))
	if not baking.get("commands", {}).has(command_id) or not baking.get("points", {}).has(point_id):
		# A valid save can never lose the command or the point of a live job; if one somehow does,
		# the job is dropped without inventing a loaf or destroying the reserved flour.
		baking.get("jobs", {}).erase(id)
		return {"ok": false, "code": "baking_job_unavailable", "actor_id": id, "command_id": command_id}
	var receipt: Dictionary = {}
	if reserved == 1 and int(account(id).get("food", 0)) < BAKING_FOOD_CAPACITY:
		var ledger := _ensure_loaf_ledger(baking, point_id, id)
		ledger.held = int(ledger.held) + 1
		account(id).food = int(account(id).get("food", 0)) + 1
		receipt = {"ok": true, "code": "bread_baked", "capability_id": BAKING_CAPABILITY_ID, "actor_id": id,
			"command_id": command_id, "route_id": BAKING_ROUTE_ID, "point_id": point_id, "quantity": 1}
		baking.commands[command_id].status = "completed"
		_append_life_event({"type": "bread_baked", "actor_id": id, "subject_id": id, "recipient_ids": [id],
			"operation_id": command_id, "source": str(job.get("provenance", "local_rule_policy")),
			"capability_id": BAKING_CAPABILITY_ID, "route_id": BAKING_ROUTE_ID, "point_id": point_id, "quantity": 1,
			"text": "我在%s用一份公共面粉烤好了一个面包，现在它是我自己的口粮。" % [str(point.get("label", point_id))]})
	else:
		# Honest fallback: no loaf could be handed over, so the reserved flour returns to the
		# public stock instead of becoming an uneatable counter.
		baking.points[point_id].flour_remaining = int(baking.points[point_id].flour_remaining) + reserved
		receipt = {"ok": false, "code": "loaf_unavailable", "capability_id": BAKING_CAPABILITY_ID, "actor_id": id,
			"command_id": command_id, "route_id": BAKING_ROUTE_ID, "point_id": point_id, "quantity": 0}
		baking.commands[command_id].status = "rejected"
		_append_life_event({"type": "baking_failed", "actor_id": id, "subject_id": id, "recipient_ids": [id],
			"operation_id": command_id, "source": str(job.get("provenance", "local_rule_policy")),
			"capability_id": BAKING_CAPABILITY_ID, "route_id": BAKING_ROUTE_ID, "point_id": point_id, "quantity": 0,
			"text": "%s这次没能烤成：我手上放不下新的口粮，公共面粉已经退回。" % [str(point.get("label", point_id))]})
	baking.commands[command_id].result = receipt.duplicate(true)
	baking.jobs.erase(id)
	return receipt

func _consume_held_loaf(id: String, command_id: String, provenance: String) -> void:
	# A loaf is really eaten when this resident's own eat action consumes one unit of its real
	# food. Points are visited in a stable order, so the attribution is deterministic.
	var ledgers: Dictionary = _baking().get("ledgers", {})
	var keys: Array = ledgers.keys()
	keys.sort()
	for point_id in keys:
		var point_ledger: Variant = ledgers[point_id]
		if not point_ledger is Dictionary:
			continue
		var ledger: Variant = point_ledger.get(id, {})
		if not ledger is Dictionary or int(ledger.get("held", 0)) < 1:
			continue
		ledger.held = int(ledger.held) - 1
		ledger.eaten = int(ledger.eaten) + 1
		_append_life_event({"type": "bread_eaten", "actor_id": id, "subject_id": id, "recipient_ids": [id],
			"operation_id": command_id, "source": provenance, "capability_id": BAKING_CAPABILITY_ID,
			"route_id": BAKING_ROUTE_ID, "point_id": str(point_id), "quantity": 1,
			"text": "我吃掉了一个自己烤的面包。"})
		return

func _finish(id: String, pending: Dictionary) -> Dictionary:
	# The world's own eat rule stays authoritative; this only attributes the consumed unit to the
	# baking ledger when this resident really holds a loaf of this route.
	if not _state.godot.has("baking") or str(pending.get("action", "")) != "eat_ration":
		return super._finish(id, pending)
	var before := int(account(id).get("food", 0))
	var receipt := super._finish(id, pending)
	if receipt.get("ok", false) and int(account(id).get("food", 0)) < before:
		_consume_held_loaf(id, str(pending.get("command_id", "")), str(pending.get("provenance", "local_rule_policy")))
	return receipt

func advance(delta: float) -> Dictionary:
	var result := super.advance(delta)
	if not result.ok or not _state.godot.has("baking"):
		return result
	_observe_baking()
	var baking := _baking()
	for id in baking.get("jobs", {}).keys().duplicate():
		var job: Dictionary = baking.jobs.get(id, {})
		if job.is_empty() or id not in active_ids():
			continue
		var point: Dictionary = baking.get("points", {}).get(str(job.get("point_id", "")), {})
		if point.is_empty() or not _valid_position(point.get("position")):
			continue
		if position_of(id).distance_to(_vector(point.position) + BAKING_WORK_OFFSET) > BAKING_ARRIVAL_RADIUS:
			continue
		job.elapsed = float(job.get("elapsed", 0.0)) + delta
		if float(job.elapsed) < BAKING_WORK_SECONDS:
			continue
		result.completed.append(_finish_bake(id, job, point))
	_observe_baking()
	return result

func resident_view(id: String = "") -> Dictionary:
	var view := super.resident_view(id)
	if view.is_empty():
		return view
	view.baking_points = []
	for point_id in _known_baking(id):
		var point: Dictionary = _baking().get("points", {}).get(str(point_id), {})
		var observation: Dictionary = _known_baking(id)[point_id]
		if point.is_empty():
			continue
		view.baking_points.append({"id": str(point.id), "label": str(point.label), "access": str(point.access),
			"position": point.position.duplicate(), "last_observed_flour": observation.flour_remaining,
			"observed_elapsed": observation.observed_elapsed, "observation_event_seq": observation.event_seq,
			"knowledge_source": _baking_knowledge_source_for(id, str(point_id), observation),
			"work_seconds_per_loaf": BAKING_WORK_SECONDS, "flour_may_have_changed": true})
	view.baking_loaves = baking_ledger(id)
	return view

func _baking_knowledge_source_for(id: String, point_id: String, observation: Dictionary) -> String:
	# Derived from the exact observation event that produced it; an older proximity observation is
	# never relabelled as a newer line-of-sight one.
	for event in _state.life.events:
		if event.get("seq") == observation.get("event_seq") and event.get("type") == "baking_point_observed" and event.get("actor_id") == id and event.get("point_id") == point_id and event.get("flour_remaining") == observation.get("flour_remaining"):
			var recorded := str(event.get("source", ""))
			if recorded == "host_line_of_sight_observation":
				return "personal_line_of_sight_observation"
			if recorded == "host_proximity_observation":
				return "personal_proximity_observation"
			if recorded == "resident_bake_attempt_feedback":
				return "personal_action_feedback"
			return "historical_baking_observation"
	return "historical_baking_observation"

func _candidate_food(value: Dictionary, id: String) -> int:
	var survival: Variant = value.get("survival", {})
	if not survival is Dictionary:
		return -1
	var accounts: Variant = survival.get("accounts", [])
	if not accounts is Array:
		return -1
	for account_value in accounts:
		if account_value is Dictionary and str(account_value.get("resident_id", "")) == id:
			return int(account_value.get("food", 0))
	return -1

func _validate_baking(value: Dictionary) -> Dictionary:
	var g: Dictionary = value.godot
	var raw: Variant = g.get("baking", {})
	if raw == {}:
		# An old save carries no namespace. It stays loadable and stays unchanged, and only a save
		# that really holds baking history without its state is rejected.
		for event in value.life.events:
			if event is Dictionary and BAKING_EVENT_TYPES.has(str(event.get("type", ""))):
				return _failure("baking_state_missing")
		return {"ok": true, "code": "baking_absent"}
	if not raw is Dictionary or not _exact_keys(raw, BAKING_STATE_KEYS) or raw.schema_version != BAKING_SCHEMA_VERSION:
		return _failure("invalid_baking_state")
	var baking: Dictionary = raw
	for key in ["points", "known", "jobs", "commands", "installs", "ledgers"]:
		if not baking[key] is Dictionary:
			return _failure("invalid_baking_state")
	var active: Array = g.positions.keys()
	if baking.points.size() > BAKING_POINT_LIMIT:
		return _failure("baking_point_capacity")
	var trade_record: Variant = g.get("trade", {})
	var material_record: Variant = g.get("materials", {})
	var place_record: Variant = g.get("places", {})
	var life_commands: Dictionary = g.get("commands", {})
	var trade_commands: Dictionary = trade_record.get("commands", {}) if trade_record is Dictionary and trade_record.get("commands", null) is Dictionary else {}
	var material_commands: Dictionary = material_record.get("commands", {}) if material_record is Dictionary and material_record.get("commands", null) is Dictionary else {}
	var place_commands: Dictionary = place_record.get("commands", {}) if place_record is Dictionary and place_record.get("commands", null) is Dictionary else {}
	for command_id in baking.installs:
		var install: Variant = baking.installs[command_id]
		if not command_id is String or not command_id.begins_with(HOST_REVIEWER_PREFIX) or not _validate_decision_command_id(command_id).ok or not install is Dictionary or not _exact_keys(install, ["payload"]):
			return _failure("invalid_baking_install")
		var recorded: Variant = install.payload
		if not recorded is Dictionary or not _exact_keys(recorded, ["spec", "source_seq", "route_id"]) or recorded.route_id != BAKING_ROUTE_ID or typeof(recorded.source_seq) != TYPE_INT or recorded.source_seq < 1 or not recorded.spec is Dictionary or not _valid_baking_spec(recorded.spec):
			return _failure("invalid_baking_install")
	var active_install_commands := {}
	for point_id in baking.points:
		var point: Variant = baking.points[point_id]
		if not point is Dictionary or not _exact_keys(point, ["id", "label", "initial_flour", "position", "access", "flour_remaining", "install_command", "source_need"]):
			return _failure("invalid_baking_point")
		var spec := _point_spec(point)
		if not _valid_baking_spec(spec) or str(point.id) != str(point_id) or not _bounded(point.flour_remaining, point.initial_flour):
			return _failure("invalid_baking_point")
		var need: Variant = point.source_need
		if not need is Dictionary or not _exact_keys(need, ["seq", "actor_id", "text"]) or typeof(need.seq) != TYPE_INT or need.seq < 1 or not need.actor_id is String or not need.text is String or str(need.text).strip_edges().is_empty():
			return _failure("invalid_baking_evidence")
		if not g.positions.has(need.actor_id):
			return _failure("invalid_baking_evidence")
		var install_record: Variant = baking.installs.get(str(point.install_command), {})
		if not install_record is Dictionary or not install_record.get("payload", null) is Dictionary:
			return _failure("invalid_baking_install")
		var recorded_install: Dictionary = install_record.payload
		if int(recorded_install.source_seq) != int(need.seq) or not _same_baking_spec(recorded_install.spec, spec):
			return _failure("baking_install_spec_changed")
		active_install_commands[str(point.install_command)] = str(point_id)
		var matching_need := false
		var matching_install := false
		for event in value.life.events:
			if not event is Dictionary:
				continue
			if event.get("seq") == need.seq and event.get("actor_id") == need.actor_id and event.get("text") == need.text and BAKING_NEED_EVENT_TYPES.has(str(event.get("type", ""))):
				matching_need = true
			if event.get("type") == "baking_route_installed" and event.get("operation_id") == point.install_command and event.get("actor_id") == "development_gm" and event.get("recipient_ids") == [] and event.get("point_id") == point_id and event.get("source_seq") == need.seq and event.get("initial_flour") == point.initial_flour:
				matching_install = true
		if not matching_need or not matching_install:
			return _failure("invalid_baking_evidence")
	# Install journals are immutable. An install that is no longer active is legal only when one
	# explicit host supersession binds it to the active replacement install, with the same need and
	# the same finite flour. This closes the historical validator gap without adding a migration
	# registry or allowing general removal.
	var superseded_installs := {}
	var replacement_commands := {}
	for event in value.life.events:
		if not event is Dictionary or event.get("type") != "baking_route_superseded":
			continue
		var operation_id := str(event.get("operation_id", ""))
		var retired_id := str(event.get("point_id", ""))
		var replacement_id := str(event.get("replacement_point_id", ""))
		var retired_command := str(event.get("superseded_install_command", ""))
		if event.get("actor_id") != "development_gm" or event.get("recipient_ids") != [] \
				or event.get("source") != "development_gm_review" or event.get("capability_id") != BAKING_CAPABILITY_ID \
				or event.get("route_id") != BAKING_ROUTE_ID or not operation_id.begins_with(HOST_REVIEWER_PREFIX) \
				or not _validate_decision_command_id(operation_id).ok or retired_id.is_empty() or replacement_id.is_empty() \
				or retired_id == replacement_id or typeof(event.get("source_seq")) != TYPE_INT \
				or typeof(event.get("initial_flour")) != TYPE_INT:
			return _failure("invalid_baking_supersession")
		if superseded_installs.has(retired_command) or replacement_commands.has(operation_id) \
				or active_install_commands.has(retired_command) or baking.points.has(retired_id) \
				or not active_install_commands.has(operation_id) \
				or active_install_commands[operation_id] != replacement_id:
			return _failure("invalid_baking_supersession")
		var retired_install: Variant = baking.installs.get(retired_command, {})
		var replacement_install: Variant = baking.installs.get(operation_id, {})
		if not retired_install is Dictionary or not retired_install.get("payload", null) is Dictionary \
				or not replacement_install is Dictionary or not replacement_install.get("payload", null) is Dictionary:
			return _failure("invalid_baking_supersession")
		var retired_payload: Dictionary = retired_install.payload
		var replacement_payload: Dictionary = replacement_install.payload
		var retired_spec: Dictionary = retired_payload.get("spec", {})
		var replacement_spec: Dictionary = replacement_payload.get("spec", {})
		if str(retired_spec.get("id", "")) != retired_id or str(replacement_spec.get("id", "")) != replacement_id \
				or int(retired_spec.get("initial_flour", -1)) != int(event.initial_flour) \
				or int(replacement_spec.get("initial_flour", -1)) != int(event.initial_flour) \
				or int(retired_payload.get("source_seq", -1)) != int(event.source_seq) \
				or int(replacement_payload.get("source_seq", -1)) != int(event.source_seq):
			return _failure("invalid_baking_supersession")
		var retired_install_event := false
		for historic in value.life.events:
			if historic is Dictionary and historic.get("type") == "baking_route_installed" \
					and historic.get("operation_id") == retired_command and historic.get("point_id") == retired_id \
					and historic.get("source_seq") == event.source_seq and historic.get("initial_flour") == event.initial_flour:
				retired_install_event = true
		if not retired_install_event:
			return _failure("invalid_baking_supersession")
		superseded_installs[retired_command] = operation_id
		replacement_commands[operation_id] = retired_command
	for command_id in baking.installs:
		if not active_install_commands.has(command_id) and not superseded_installs.has(command_id):
			return _failure("baking_inactive_install_without_supersession")
	for command_id in baking.commands:
		var command: Variant = baking.commands[command_id]
		if not command_id is String or not _validate_decision_command_id(command_id).ok or not command is Dictionary or not command.get("payload", null) is Dictionary:
			return _failure("invalid_baking_command")
		var status := str(command.get("status", ""))
		var payload: Dictionary = command.payload
		if not _exact_keys(payload, ["actor_id", "action", "point_id", "provenance"]) or payload.action != BAKING_ACTION or payload.actor_id not in active or payload.provenance not in ALLOWED_DECISION_PROVENANCE or not baking.points.has(payload.point_id):
			return _failure("invalid_baking_command")
		# The command id is unique across the five known journals, so the host's fixed order can
		# never resolve a bake receipt to another module's command.
		if life_commands.has(command_id) or trade_commands.has(command_id) or material_commands.has(command_id) or place_commands.has(command_id) or baking.installs.has(command_id):
			return _failure("baking_command_conflict")
		if status == "pending":
			var live: Variant = baking.jobs.get(payload.actor_id, {})
			if not live is Dictionary or str(live.get("command_id", "")) != str(command_id):
				return _failure("baking_pending_job_missing")
			continue
		if status not in ["completed", "rejected"]:
			return _failure("invalid_baking_command")
		var receipt: Variant = command.get("result", null)
		if not receipt is Dictionary or not _exact_keys(receipt, ["ok", "code", "capability_id", "actor_id", "command_id", "route_id", "point_id", "quantity"]):
			return _failure("invalid_baking_receipt")
		var baked: bool = status == "completed"
		if receipt.ok != baked or receipt.code != ("bread_baked" if baked else "loaf_unavailable") or receipt.capability_id != BAKING_CAPABILITY_ID or receipt.route_id != BAKING_ROUTE_ID or receipt.actor_id != payload.actor_id or receipt.command_id != command_id or receipt.point_id != payload.point_id or int(receipt.quantity) != (1 if baked else 0):
			return _failure("invalid_baking_receipt")
		if baked:
			var baked_events := 0
			for event in value.life.events:
				if event is Dictionary and event.get("type") == "bread_baked" and event.get("operation_id") == command_id and event.get("actor_id") == payload.actor_id and event.get("point_id") == payload.point_id and event.get("quantity") == 1:
					baked_events += 1
			if baked_events != 1:
				return _failure("invalid_baking_receipt_evidence")
	for id in baking.jobs:
		var job: Variant = baking.jobs[id]
		if id not in active or not job is Dictionary or not _exact_keys(job, ["action", "command_id", "point_id", "provenance", "elapsed", "duration_seconds", "reserved_flour"]):
			return _failure("invalid_baking_job")
		if job.action != BAKING_ACTION or not baking.points.has(job.point_id) or int(job.reserved_flour) != 1 or not _bounded(job.elapsed, BAKING_WORK_SECONDS, false) or not float_is_valid(job.duration_seconds) or not is_equal_approx(float(job.duration_seconds), BAKING_WORK_SECONDS):
			return _failure("invalid_baking_job")
		var live_command: Variant = baking.commands.get(str(job.command_id), {})
		if not live_command is Dictionary or str(live_command.get("status", "")) != "pending":
			return _failure("baking_job_conflict")
		var live_payload: Variant = live_command.get("payload", {})
		if not live_payload is Dictionary or str(live_payload.get("actor_id", "")) != id or str(live_payload.get("point_id", "")) != str(job.point_id) or str(live_payload.get("provenance", "")) != str(job.provenance):
			return _failure("baking_job_conflict")
		# One journey per resident: no other journey queue may run while this bake is pending.
		var trade_jobs: Variant = trade_record.get("jobs", {}) if trade_record is Dictionary else {}
		var material_jobs: Variant = material_record.get("jobs", {}) if material_record is Dictionary else {}
		var place_jobs: Variant = place_record.get("jobs", {}) if place_record is Dictionary else {}
		if g.pending.has(id) or (trade_jobs is Dictionary and trade_jobs.has(id)) or (material_jobs is Dictionary and material_jobs.has(id)) or (place_jobs is Dictionary and place_jobs.has(id)):
			return _failure("conflicting_baking_journey")
	for id in baking.known:
		if id not in active or not baking.known[id] is Dictionary:
			return _failure("invalid_baking_observer")
		for point_id in baking.known[id]:
			var known: Variant = baking.known[id][point_id]
			if not baking.points.has(point_id) or not known is Dictionary or not _exact_keys(known, ["flour_remaining", "observed_elapsed", "event_seq"]) or not _bounded(known.flour_remaining, BAKING_FLOUR_LIMIT) or not _bounded(known.observed_elapsed, value.godot.elapsed_seconds, false):
				return _failure("invalid_baking_observation")
			var found := false
			for event in value.life.events:
				if event is Dictionary and event.get("seq") == known.event_seq and event.get("type") == "baking_point_observed" and event.get("actor_id") == id and id in event.get("recipient_ids", []) and event.get("point_id") == point_id and event.get("flour_remaining") == known.flour_remaining:
					found = true
			if not found:
				return _failure("invalid_baking_observation_evidence")
	var reserved: Dictionary = {}
	for id in baking.jobs:
		var job_point := str(baking.jobs[id].get("point_id", ""))
		reserved[job_point] = int(reserved.get(job_point, 0)) + int(baking.jobs[id].get("reserved_flour", 0))
	var held_total: Dictionary = {}
	var eaten_total: Dictionary = {}
	var held_by_resident: Dictionary = {}
	for point_id in baking.ledgers:
		if not baking.points.has(point_id):
			return _failure("invalid_baking_ledger")
		var point_ledger: Variant = baking.ledgers[point_id]
		if not point_ledger is Dictionary:
			return _failure("invalid_baking_ledger")
		var held := 0
		var eaten := 0
		for id in point_ledger:
			var ledger: Variant = point_ledger[id]
			if id not in active or not ledger is Dictionary or not _exact_keys(ledger, ["held", "eaten"]) or not _bounded(ledger.held, BAKING_FLOUR_LIMIT) or not _bounded(ledger.eaten, BAKING_FLOUR_LIMIT) or int(ledger.held) + int(ledger.eaten) < 1:
				return _failure("invalid_baking_ledger")
			held += int(ledger.held)
			eaten += int(ledger.eaten)
			held_by_resident[id] = int(held_by_resident.get(id, 0)) + int(ledger.held)
		held_total[point_id] = held
		eaten_total[point_id] = eaten
	# A resident's real food account backs all of their held loaves across every public point.
	# Checking each point separately would let two one-loaf ledgers claim the same one food unit.
	for id in held_by_resident:
		if int(held_by_resident[id]) > _candidate_food(value, str(id)):
			return _failure("baking_loaf_not_held")
	for point_id in baking.points:
		var point: Variant = baking.points[point_id]
		var conserved: int = int(point.flour_remaining) + int(reserved.get(point_id, 0)) + int(held_total.get(point_id, 0)) + int(eaten_total.get(point_id, 0))
		if conserved != int(point.initial_flour):
			return _failure("baking_conservation_failed")
	return {"ok": true, "code": "baking_valid"}

func _point_spec(point: Dictionary) -> Dictionary:
	var spec := point.duplicate(true)
	for key in ["flour_remaining", "install_command", "source_need"]:
		spec.erase(key)
	return spec

func _validate_state(value: Variant) -> Dictionary:
	var base := super._validate_state(value)
	if not base.ok:
		return base
	return _validate_baking(value)
