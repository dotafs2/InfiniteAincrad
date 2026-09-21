extends SceneTree
## Offline structural acceptance for the Starting City whitebox.
## No model/provider calls, no world save, and no production scene mutation.

const Whitebox := preload("res://spatial/starting_city_whitebox.gd")
const Layout := preload("res://spatial/starting_city_whitebox_layout.gd")

var _checks := 0
var _failures := 0
var _errors: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var root := Node3D.new()
	root.name = "WhiteboxAcceptanceRoot"
	get_root().add_child(root)
	var whitebox := Whitebox.new()
	root.add_child(whitebox)
	var snapshot: Dictionary = whitebox.build()
	_check(snapshot.get("revision") == Layout.REVISION, "revision is explicit")
	_check(snapshot.get("zone_count") == Layout.ZONES.size(), "all terrain zones are represented")
	_check(snapshot.get("authored_road_count") == Layout.AUTHORED_ROADS.size(), "authored PCG roads are represented")
	_check(snapshot.get("macro_road_count") == Layout.MACRO_ROADS.size(), "macro connectors are represented")
	_check(snapshot.get("house_count") == Layout.HOUSES.size(), "every whitebox house is represented")
	_check(snapshot.get("resident_house_count") == 10, "ten named resident cubes are present")
	_check(snapshot.get("whitebox_house_material") == "white", "house placeholders are white")
	_check(snapshot.get("production_world_loaded") == false and snapshot.get("model_calls") == 0, "preview is isolated from production and providers")
	_check(whitebox.get_node_or_null("TerrainZones") != null, "terrain node exists")
	_check(whitebox.get_node_or_null("Roads_AuthoredAndMacro") != null, "road node exists")
	_check(whitebox.get_node_or_null("WhiteHouseCubes") != null, "house cube node exists")
	_check(whitebox.get_node_or_null("TownOfBeginningsShell") != null, "city shell node exists")
	_check(_authored_points_match(), "whitebox authored roads retain living quarter centreline points")
	var report := {"suite":"starting_city_whitebox_acceptance", "passed":_failures == 0, "checks":_checks, "failures":_failures, "errors":_errors, "snapshot":snapshot, "paid_calls":0}
	print(JSON.stringify(report))
	root.queue_free()
	quit(0 if _failures == 0 else 1)

func _authored_points_match() -> bool:
	var file := FileAccess.open("res://spatial/living_quarter_layout.json", FileAccess.READ)
	if file == null:
		return false
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or not parsed.has("roads"):
		return false
	var canonical: Array = parsed["roads"]
	if canonical.size() != Layout.AUTHORED_ROADS.size():
		return false
	for index in range(Layout.AUTHORED_ROADS.size()):
		var expected: Array = canonical[index]["points"]
		var actual: Array = Layout.AUTHORED_ROADS[index]["points"]
		if expected.size() != actual.size() or float(canonical[index]["width"]) != float(Layout.AUTHORED_ROADS[index]["width"]):
			return false
		for point_index in range(actual.size()):
			if expected[point_index].size() != actual[point_index].size():
				return false
			for coordinate in range(actual[point_index].size()):
				if not is_equal_approx(float(expected[point_index][coordinate]), float(actual[point_index][coordinate])):
					return false
	return true

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		_errors.append(message)
