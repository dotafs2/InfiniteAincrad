extends RefCounted
## English presentation of known authored legacy text. Never rewrites canonical history.
## Unknown historical free text is retained verbatim; a translation must not invent evidence.

static var _legacy: Dictionary = {}

static func text(original: String) -> String:
	if _legacy.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://core/english_legacy_text.json"))
		if parsed is Dictionary:
			_legacy = parsed
	return str(_legacy.get(original, original))

static func project(value: Variant) -> Variant:
	if value is Array:
		var result: Array = []
		for item in value:
			result.append(project(item))
		return result
	if value is Dictionary:
		var result: Dictionary = value.duplicate(true)
		for key in result:
			if result[key] is String and key in ["name", "story", "personality", "label", "public_use", "text", "reason", "speech"]:
				result[key] = text(result[key])
			elif result[key] is Array or result[key] is Dictionary:
				result[key] = project(result[key])
		return result
	return value
