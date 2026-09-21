extends SceneTree

const ART_PASS := preload("res://spatial/starting_city_art_pass.gd")
const RESIDENT := preload("res://spatial/trial_resident.gd")

var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	if not condition:
		failures.append(label)
		push_error(label)

func _run() -> void:
	var art := ART_PASS.new()
	root.add_child(art)
	await process_frame
	await process_frame
	var evidence: Dictionary = art.get_evidence()
	check(evidence.get("suite") == "starting_city_art_pass", "art pass evidence exists")
	check(evidence.get("imported_asset_instances", 0) >= 30, "imported assets are dressed across the town")
	check(evidence.get("procedural_asset_instances", 0) >= 50, "procedural art pass has enough authored detail")
	check(evidence.get("generated_collision_bodies", 0) >= 5, "major art landmarks carry preview collisions")
	check(evidence.get("resident_count", 0) == 4, "four loadout residents are present")
	var loadouts: Dictionary = evidence.get("resident_loadouts", {})
	check(loadouts.get("art_guard", {}).get("right") == "sword", "guard has a sword")
	check(loadouts.get("art_guard", {}).get("left") == "shield", "guard has a shield")
	check(loadouts.get("art_smith", {}).get("right") == "hammer", "smith has a hammer")
	check(loadouts.get("art_healer", {}).get("left") == "book", "healer has a book")

	var probe := RESIDENT.new()
	root.add_child(probe)
	await process_frame
	check(probe.equip_item("dagger", "right"), "dagger attaches to right hand")
	check(probe.equip_item("lantern", "left"), "lantern attaches to left hand")
	check(probe.equipped_item("right") == "dagger", "right hand reports dagger")
	check(probe.equipped_item("left") == "lantern", "left hand reports lantern")
	check(probe.equip_item("", "right"), "right hand can be cleared")
	check(probe.equipped_item("right").is_empty(), "right hand clears cleanly")
	print(JSON.stringify({"suite": "starting_city_art", "passed": failures.is_empty(), "failures": failures, "evidence": evidence}))
	quit(0 if failures.is_empty() else 1)
