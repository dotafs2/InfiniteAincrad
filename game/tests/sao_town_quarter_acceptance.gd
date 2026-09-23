extends SceneTree
## Offline acceptance for the reference-traced Town of Beginnings whitebox.

const QUARTER := preload("res://spatial/sao_town_quarter.gd")
const LAYOUT_PATH := "res://spatial/sao_town_quarter_layout.json"

var checks := 0
var failures: Array[String] = []


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT_PATH))
	check(layout.get("id", "") == "reference-traced-v3", "same supplied reference layout loads")
	check(layout.get("water", []).size() == 3, "three visible water footprints are traced")
	check(layout.get("gardens", []).size() >= 10, "visible garden footprints are traced")
	check(layout.get("buildings", []).size() > 50, "dense building ring is traced")
	check(layout.get("fountains", []).size() == 6, "visible fountains are marked")
	check(layout.get("labels", []).size() >= 20, "visible reference markers are retained")
	check(layout.get("palette", {}).get("red", "") == "#a34536", "red reference color is retained")
	check(layout.get("palette", {}).get("water", "") == "#b9dce7", "blue reference color is retained")
	check(layout.get("palette", {}).get("garden", "") == "#7c9936", "green reference color is retained")
	var quarter := QUARTER.new()
	root.add_child(quarter)
	await process_frame
	check(quarter.built, "procedural quarter builds once")
	check(quarter.data.get("note", "").contains("same supplied reference"), "blockout records reference provenance")
	check(quarter.get_node_or_null("OuterGrass") != null, "outer ground exists")
	check(quarter.get_node_or_null("TownPaving") != null, "town paving exists")
	check(quarter.get_node_or_null("Wall") != null, "outer wall exists")
	check(quarter.get_node_or_null("Plaza") != null, "central plaza exists")
	check(quarter.get_node_or_null("RedRoofA") != null, "first red arc exists")
	check(quarter.get_node_or_null("Water_00") != null, "water geometry exists")
	check(quarter.get_node_or_null("Garden_00") != null, "garden geometry exists")
	check(quarter.get_node_or_null("DarkLandmarkWing") != null, "left dark landmark exists")
	check(quarter.get_node_or_null("QuarterCamera") != null, "overview camera exists")
	check(is_instance_valid(quarter.label_root), "reference labels exist")
	print(JSON.stringify({"ok": failures.is_empty(), "checks": checks, "failures": failures,
		"water": layout.get("water", []).size(), "gardens": layout.get("gardens", []).size(),
		"buildings": layout.get("buildings", []).size()}))
	quit(0 if failures.is_empty() else 1)
