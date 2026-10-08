extends RefCounted
## Frostlight reuses the proven toy-city parcel plan, then dresses it as a
## snowbound storybook village. Keeping the parcel coordinates identical makes
## the new route readable and preserves the small-to-giant edible progression.
const Base = preload("res://fidelity/toy_neighborhoods.gd")

static func plan() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for source in Base.plan():
		var spec: Dictionary = source.duplicate(true)
		spec["neighborhood"] = "frost_" + str(spec.get("neighborhood", "district"))
		spec["frost_palette"] = posmod(int(spec.get("palette", 0)) + 2, 5)
		result.append(spec)
	return result

static func metadata() -> Dictionary:
	var result: Dictionary = Base.metadata().duplicate(true)
	result["map_id"] = "frost"
	result["name"] = "Frostlight Village"
	result["theme"] = "frostlight"
	result["season"] = "snow"
	return result
