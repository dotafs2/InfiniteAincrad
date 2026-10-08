extends RefCounted
## Authored campaign extension; reference footage supplies the core shooting/recruit loop.
const MAX_SQUAD := 36
const WEAPONS := ["rifle", "scatter", "rail", "rocket", "arc"]
const WEAPON_NAMES := {"rifle":"RAPID FIRE", "scatter":"SCATTER", "rail":"RAIL LANCE", "rocket":"ROCKETS", "arc":"CHAIN ARC"}
const WEAPON_UNLOCK_WAVE := {"rifle":0,"scatter":1,"rail":2,"rocket":3,"arc":4}
const WAVES := [
	{"name":"First Contact", "boss":"brute", "hp":2400.0, "troop_hp":1.0, "speed":0.45, "elites":[], "tint":Color("ed595f")},
	{"name":"Iron Wall", "boss":"golem", "hp":12500.0, "troop_hp":3.0, "speed":0.50, "elites":["shield","shield"], "tint":Color("d16761")},
	{"name":"Skitter Rush", "boss":"skitter", "hp":130000000.0, "troop_hp":4.0, "speed":0.75, "elites":["skitter","skitter","skitter"], "tint":Color("bb7392")},
	{"name":"Emerald Wings", "boss":"dragon", "hp":130000000.0, "troop_hp":6.0, "speed":0.55, "elites":["shield","skitter"], "tint":Color("e26961")},
	{"name":"Storm Battery", "boss":"golem", "hp":120000000.0, "troop_hp":8.0, "speed":0.62, "elites":["shield","skitter","shield","skitter"], "tint":Color("c66eab")},
	{"name":"Twin Talons", "boss":"dragon", "hp":130000000.0, "troop_hp":10.0, "speed":0.65, "elites":["drake","drake","skitter"], "tint":Color("df6662")},
	{"name":"Crimson Siege", "boss":"brute", "hp":120000000.0, "troop_hp":12.0, "speed":0.72, "elites":["shield","drake","skitter","shield"], "tint":Color("df455e")},
	{"name":"The Sky Tyrant", "boss":"dragon", "hp":120000000.0, "troop_hp":15.0, "speed":0.78, "elites":["drake","shield","skitter","drake"], "tint":Color("ca547d")},
]
static func weapon_interval(mode: String, tier: int) -> float:
	match mode:
		"scatter": return 0.58
		"rail": return 0.68
		"rocket": return 0.82
		"arc": return 0.46
	return 0.20 if tier==0 else 0.13
static func weapon_power(mode: String, tier: int) -> float:
	var base:float=[1.0,5.0,13.0,24.0][tier]
	return base*({"rifle":1.0,"scatter":0.90,"rail":6.2,"rocket":7.0,"arc":3.5}.get(mode,1.0))
static func weapon_color(mode: String, tier: int) -> Color:
	match mode:
		"scatter": return Color("ffd787")
		"rail": return Color("cfb9ff")
		"rocket": return Color("ff9750")
		"arc": return Color("a2dfff")
	return [Color("ffe78a"),Color("72f8ff"),Color("ff81df"),Color("b99aff")][tier]
