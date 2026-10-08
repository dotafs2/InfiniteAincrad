extends SceneTree
## Focused Frostlight Village acceptance: actual playable world, snow dressing,
## high-specular materials, map routing, progression and save-safe timing.
const Game = preload("res://fidelity/game.gd")
const FrostCity = preload("res://fidelity/frost_city.gd")
var game: Node3D
var checks := 0
var failures: Array[String] = []
var metrics: Dictionary = {}

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)
		push_error(label)

func descendants(owner: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child in owner.get_children():
		result.append(child)
		result.append_array(descendants(child))
	return result

func run() -> void:
	if not OS.get_cmdline_user_args().has("--test"):
		quit(2)
		return
	AudioServer.set_bus_mute(0, true)
	game = Game.new()
	game.selected_map = "frost"
	game.test_progress_path = "/tmp/hole-feast-frostlight-%d.cfg" % OS.get_process_id()
	root.add_child(game)
	game.start_level()
	game.begin_play()
	for _index in 3:
		await physics_frame
	var city: Node3D = game.city
	var summary: Dictionary = city.population_summary()
	check(city is FrostCity and summary.get("map_id", "") == "frost", "Frostlight selection builds its own playable city branch")
	check(summary.get("name", "") == "Frostlight Village" and game.MAPS.get("frost", "") == "FROSTLIGHT VILLAGE", "Frostlight keeps the catalog and runtime name aligned")
	check(game.map_round_seconds("frost") == 90.0 and game.round_duration() == 90.0 and game.remaining > 89.9, "Frostlight starts with the intended 90-second round")
	check(summary.get("bodies", 0) >= 400 and summary.get("largest_height", 0.0) >= 25.0, "The snow city preserves dense edible progression and giant late targets")
	check(summary.get("snow_decorations", 0) >= 30 and summary.get("ice_spires", 0) == 9 and summary.get("frozen_ponds", 0) == 3, "Ground dressing, boundary shelves and frozen ponds are constructed without detached edible snow caps")
	var species: Dictionary = summary.get("frost_species", {})
	check(int(summary.get("frost_system_count", 0)) >= 10 and summary.get("bodies", 0) <= 900 and species.has("polar_bear") and species.has("penguin") and species.has("scientist") and species.has("icebreaker") and species.has("ice_rock"), "Polar wildlife, expeditions and edible ice rocks fit the shared body budget")
	check(float(summary.get("snow_material_roughness", 1.0)) <= .25 and float(summary.get("ice_material_roughness", 1.0)) <= .1, "Snow and ice use the bright high-specular storybook surface")
	check(int(summary.get("whole_castles", 1)) == 0 and int(summary.get("castle_visuals_removed", 0)) >= 50 and bool(summary.get("arctic_dominant", false)), "Arctic visuals replace the inherited castle skyline while preserving edible bodies")
	var blender_assets: Dictionary = summary.get("blender_assets", {})
	check(int(blender_assets.get("glacier_iceberg", 0)) >= 180 and int(blender_assets.get("ice_rock", 0)) >= 12, "Blender-authored glacier and edible ice-rock assets are instantiated in the playable map")
	var snow_nodes := descendants(city).filter(func(node: Node) -> bool: return str(node.name).begins_with("Snow") or str(node.name).begins_with("Ice") or str(node.name).begins_with("Frozen"))
	var owned_ice := 0
	for body in city.foods:
		if str(body.get_meta("frost_species", "")) == "glacier_iceberg" and body.get_node_or_null("FrostSpeciesVisual") != null:
			owned_ice += 1
	check(snow_nodes.size() >= 30 and owned_ice >= 180, "Ground snow stays separate while all edible glaciers own their merged ice-and-snow visuals")
	var layout: Dictionary = city.layout_metadata()
	check(layout.get("theme", "") == "frostlight" and layout.get("season", "") == "snow", "Frostlight metadata survives the existing layout API")
	metrics = {"summary": summary, "snow_nodes": snow_nodes.size(), "remaining": game.remaining, "scope": "Focused desktop scene construction; no phone FPS, App Store upload or production SDK claim"}
	game.free()
	await process_frame
	var result := {"checks": checks, "failures": failures, "metrics": metrics}
	print("FROSTLIGHT_CITY_ACCEPTANCE " + JSON.stringify(result))
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--report="):
			var file := FileAccess.open(argument.trim_prefix("--report="), FileAccess.WRITE)
			if file != null:
				file.store_string(JSON.stringify(result, "\t") + "\n")
	quit(0 if failures.is_empty() else 1)
