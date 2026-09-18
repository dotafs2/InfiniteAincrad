extends RefCounted
## Reviewed code owns registration. Save files and models never name executable scripts.
const VERSION := 1
var _definitions: Dictionary = {}

func register(definition: Dictionary) -> Dictionary:
	var required := ["id", "version", "owner", "lifecycle", "resources", "speech", "preconditions", "effects", "cancellation"]
	for key in required:
		if not definition.has(key): return {"ok": false, "code": "capability_field_missing", "field": key}
	if not definition.id is String or definition.id.is_empty() or not definition.version is int or definition.version < 1:
		return {"ok": false, "code": "invalid_capability_identity"}
	if _definitions.has(definition.id): return {"ok": false, "code": "capability_collision"}
	if definition.lifecycle not in ["immediate", "durable_job", "consent_protocol"] or definition.speech not in ["forbidden", "optional", "required"]:
		return {"ok": false, "code": "invalid_capability_contract"}
	for key in ["resources", "preconditions", "effects"]:
		if not definition[key] is Array or definition[key].is_empty(): return {"ok": false, "code": "invalid_capability_contract"}
		for item in definition[key]:
			if not item is String or item.is_empty(): return {"ok": false, "code": "invalid_capability_contract"}
	for key in ["owner", "cancellation"]:
		if not definition[key] is String or definition[key].is_empty(): return {"ok": false, "code": "invalid_capability_contract"}
	_definitions[definition.id] = definition.duplicate(true)
	return {"ok": true}

func definition(id: String) -> Dictionary:
	return _definitions.get(id, {}).duplicate(true)

func all() -> Array:
	var keys := _definitions.keys()
	keys.sort()
	var result: Array = []
	for id in keys: result.append(definition(id))
	return result

static func spec(id: String, owner: String, lifecycle: String, resources: Array, speech: String,
		preconditions: Array, effects: Array, cancellation: String = "not_supported") -> Dictionary:
	return {"id": id, "version": VERSION, "owner": owner, "lifecycle": lifecycle,
		"resources": resources, "speech": speech, "preconditions": preconditions, "effects": effects,
		"cancellation": cancellation, "knowledge": "actor_personal_view_and_attributed_events",
		"execution": "authoritative_single_writer_transaction", "replay": "same_command_same_payload_no_new_effect"}
