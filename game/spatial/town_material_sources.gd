extends Node3D
## Visual projection only: displays public material sources without changing town state.

var town
var sources: Dictionary = {}
var prior_stock: Dictionary = {}
var tray_mesh: BoxMesh
var bar_mesh: BoxMesh
var tray_material: StandardMaterial3D
var bar_material: StandardMaterial3D

func configure(world) -> void:
	town = world
	var source_list: Array = town.material_sources()
	if source_list.is_empty():
		return
	tray_mesh = BoxMesh.new()
	tray_mesh.size = Vector3(0.9, 0.10, 0.58)
	bar_mesh = BoxMesh.new()
	bar_mesh.size = Vector3(0.10, 0.10, 0.38)
	tray_material = StandardMaterial3D.new()
	tray_material.albedo_color = Color("8b6344")
	tray_material.roughness = 0.9
	bar_material = StandardMaterial3D.new()
	bar_material.albedo_color = Color("858b8d")
	bar_material.roughness = 0.82
	for source in source_list:
		var source_id: String = str(source.get("id", ""))
		if source_id.is_empty():
			continue
		var display := Node3D.new()
		display.position = _source_position(source) + Vector3(0.7, 0.05, 0.0)
		add_child(display)
		var tray := MeshInstance3D.new()
		tray.mesh = tray_mesh
		tray.material_override = tray_material
		display.add_child(tray)
		for index in 5:
			var bar := MeshInstance3D.new()
			bar.mesh = bar_mesh
			bar.material_override = tray_material if source.get("material") == "wood" else bar_material
			bar.position = Vector3(-0.30 + (index % 3) * 0.22, 0.11 + (index / 3) * 0.11, 0.0)
			bar.visible = false
			display.add_child(bar)
		var label := Label3D.new()
		label.font_size = 24
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.outline_size = 6
		label.position = Vector3(0, 0.42, 0)
		display.add_child(label)
		sources[source_id] = {"display": display, "label": label}
		var stock := _stock(source)
		prior_stock[source_id] = stock
		_update_source(source_id, str(source.get("label", source_id)), stock)

func _process(_delta: float) -> void:
	if town == null or sources.is_empty():
		return
	var current: Dictionary = {}
	for source in town.material_sources():
		var source_id: String = str(source.get("id", ""))
		if not sources.has(source_id):
			continue
		var stock := _stock(source)
		current[source_id] = stock
		if int(prior_stock.get(source_id, -1)) != stock:
			_update_source(source_id, str(source.get("label", source_id)), stock)
	prior_stock = current

func _update_source(source_id: String, label_text: String, stock: int) -> void:
	var entry: Dictionary = sources[source_id]
	var display: Node3D = entry["display"]
	var label: Label3D = entry["label"]
	label.text = "%s\n剩余：%d" % [label_text, stock]
	var bundle_count := mini(5, stock)
	for index in 5:
		display.get_child(index + 1).visible = index < bundle_count

func _stock(source: Dictionary) -> int:
	return clampi(int(source.get("stock", 0)), 0, 100)

func _source_position(source: Dictionary) -> Vector3:
	var coordinates: Array = source.get("position", [])
	if coordinates.size() < 3:
		return Vector3.ZERO
	return Vector3(float(coordinates[0]), float(coordinates[1]), float(coordinates[2]))
