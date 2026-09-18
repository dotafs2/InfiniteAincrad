extends RefCounted
## Full dossiers persist on the resident. Only an explicit self projection goes to a brain.
## Never looks up another resident or silently adds a dossier to a legacy identity.

static var contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/character_profile_contract.json"))

static func validate(profile: Variant, resident_id: String) -> bool:
	if not profile is Dictionary or not (profile.get("schema_version") is int or profile.get("schema_version") is float) or profile.get("schema_version") != 1:
		return false
	if profile.get("resident_id") != resident_id or profile.get("provenance") != "original_project_genesis":
		return false
	for key in ["core", "facets", "sections", "extensions"]:
		if not profile.get(key) is Dictionary:
			return false
	for key in contract.core_fields:
		if not _text(profile.core.get(key), int(contract.core_text_limit)):
			return false
	for key in contract.facet_contexts:
		if not _text(profile.facets.get(key), int(contract.facet_text_limit)):
			return false
	for key in contract.required_sections:
		if not profile.sections.get(key) is Dictionary or profile.sections[key].is_empty():
			return false
	return JSON.stringify(profile).to_utf8_buffer().size() <= int(contract.max_profile_bytes)

static func _text(value: Variant, limit: int) -> bool:
	return value is String and not value.strip_edges().is_empty() and value.length() <= limit

static func project(person: Dictionary, view: Dictionary, options: Array) -> Dictionary:
	var profile: Variant = person.get("character_profile")
	if profile == null or not validate(profile, str(person.get("stable_id", ""))):
		return {}
	var context := "daily"
	var needs: Dictionary = view.get("needs", {})
	if float(needs.get("satiety", needs.get("hunger", 100))) < 40:
		context = "survival"
	elif float(needs.get("energy", 100)) < 40:
		context = "rest"
	else:
		# Machine action identifiers, never a guess about another person's private state.
		var offered: Array = []
		for option in options:
			offered.append(str(option.get("action", "")))
		if offered.any(func(action): return action in ["repair_edge", "repair_handle", "offer_repair", "accept", "deliver", "collect", "work", "use_tool", "bake_bread"]):
			context = "work"
		elif "share_skill" in offered or "refer_skill" in offered or "observe_work" in offered:
			context = "learning"
		elif not view.get("nearby_residents", []).is_empty():
			context = "social"
		elif "harvest_ration" in offered or "travel" in offered:
			context = "exploration"
	var result := {"schema_version": 1, "authority": contract.authority, "core": {}, "facets": {}}
	for key in contract.core_fields:
		result.core[key] = profile.core[key]
	# Always retain ordinary social manner; one relevant facet is added when it fits.
	for key in ["daily", context]:
		var candidate: Dictionary = result.duplicate(true)
		candidate.facets[key] = profile.facets[key]
		if JSON.stringify(candidate).to_utf8_buffer().size() <= int(contract.projection_byte_limit):
			result = candidate
	# Even valid non-ASCII profiles cannot exceed the byte budget. No canonical data is cut.
	if JSON.stringify(result).to_utf8_buffer().size() > int(contract.projection_byte_limit):
		return {"schema_version": 1, "authority": contract.authority, "omitted": "self_profile_exceeds_projection_budget"}
	return result
