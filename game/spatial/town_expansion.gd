extends Node3D
## Visible, walkable expansion of the actual town street.
##
## Two residential cross streets, a planted commons and an orchard/caravan edge, built from the
## original six residence shells, the environment v2 kit and the three 2026-09-12 generated sets
## (shopfront details, artisan workshops, travel cargo). Art and space only: no resident moves,
## no home rewrite, no inventory/food/production, no skills, no NPC activity claims.
##
## Surfaces are aligned to the measured original market floor: paving top 0.10 m, bare earth top
## 0.06 m, and a 6 m junction ramp that removes the old 17 cm lip so an unmodified 0.25 m capsule
## crosses in both directions with plain move_and_slide.
const Layout := preload("res://spatial/town_expansion_layout.gd")
const HOUSE_COMPONENT := preload("res://spatial/residence_component.gd")
const HOUSE6_COMPONENT := preload("res://spatial/deepseek_residences_component.gd")
const PLANTS := preload("res://spatial/environment_v2.gd")
const TEXTURES := "res://assets/floor1/residences/textures/"

## Solid-core shrink factors for generated props: a wagon keeps a body but not a giant box, and
## an open tent stays walkable inside. Names not listed use the default.
const PROP_SHRINK := {
	"covered_caravan_wagon.glb": 0.52,
	"open_traveller_tent.glb": 0.40,
	"water_delivery_cart.glb": 0.60,
	"porters_luggage_trolley.glb": 0.62,
}
const DEFAULT_SHRINK := 0.74
const VISUAL_ONLY_PROPS := ["furled_canvas_sail.glb", "roped_ferry_gangplank.glb"]

var evidence: Dictionary = {}
var houses: Array = []
var placed_details: int = 0
var placed_workshops: int = 0
var placed_cargo: int = 0
var placed_kit: int = 0
var placed_perimeter: int = 0
var load_failures: Array = []
var paving_material: StandardMaterial3D = null
var earth_material: StandardMaterial3D = null

func build() -> void:
	paving_material = _tiled_material("limestone", Vector3(0.66, 0.62, 0.54), 1.6)
	earth_material = _tiled_material("clay", Vector3(0.46, 0.42, 0.34), 2.2)
	name = "TownExpansion"
	set_meta("art_revision", "town_expansion_20260912")
	_build_terrain(earth_material)
	_build_paving(paving_material)
	_build_junction_ramp(paving_material)
	_build_houses()
	_build_kit_props()
	_build_perimeter()
	_build_shopfronts()
	_build_workshops()
	_build_caravan()
	evidence = {
		"terrain": {"center": [Layout.TERRAIN["center"].x, Layout.TERRAIN["center"].y],
			"size": [Layout.TERRAIN["size"].x, Layout.TERRAIN["size"].y],
			"visible_mesh": true, "collision": true, "top_y": Layout.TERRAIN_TOP_Y},
		"outskirts": {"center": [Layout.OUTSKIRTS["center"].x, Layout.OUTSKIRTS["center"].y],
			"size": [Layout.OUTSKIRTS["size"].x, Layout.OUTSKIRTS["size"].y],
			"visible_mesh": true, "collision": false, "top_y": Layout.OUTSKIRTS["top_y"]},
		"paving": {"authored_width_m": 6, "top_y": Layout.PAVING_TOP_Y, "collision": true,
			"junction_ramp_m": float(Layout.JUNCTION_RAMP["z_to"])
				- float(Layout.JUNCTION_RAMP["z_from"])},
		"houses": houses.size(), "variants": _variants_used(),
		"house_bounds_xz": _house_bounds(),
		"roads": Layout.ROADS.size(),
		"kit_props": placed_kit, "perimeter_props": placed_perimeter,
		"shopfront_details": placed_details,
		"workshop_tools": placed_workshops, "cargo_props": placed_cargo,
		"new_asset_instances": placed_details + placed_workshops + placed_cargo,
		"generated_load_failures": load_failures,
		"resource_changes": 0, "resident_moves": 0, "model_calls": 0,
	}

func _tiled_material(kind: String, tint: Vector3, tiles_per_metre: float) -> StandardMaterial3D:
	## Reuses the project's residence texture sets so paving and earth read as tiled town
	## surfaces instead of flat colour blocks. No external image is added.
	var material := StandardMaterial3D.new()
	material.albedo_texture = load(TEXTURES + kind + "_albedo.png")
	material.normal_enabled = true
	material.normal_texture = load(TEXTURES + kind + "_normal.png")
	material.roughness_texture = load(TEXTURES + kind + "_orm.png")
	material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	material.roughness = 1.0
	material.metallic = 0.0
	material.albedo_color = Color(tint.x, tint.y, tint.z)
	material.uv1_triplanar = true
	material.uv1_scale = Vector3.ONE * tiles_per_metre
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return material

func _variants_used() -> Array:
	var used: Array = []
	for house in Layout.HOUSES:
		if not used.has(house["variant"]):
			used.append(house["variant"])
	used.sort()
	return used

func _house_bounds() -> Array:
	var minimum := Vector2(INF, INF)
	var maximum := Vector2(-INF, -INF)
	for house in Layout.HOUSES:
		var half: Vector2 = Layout.house_footprint(int(house["variant"])) * 0.5
		minimum.x = minf(minimum.x, float(house["x"]) - half.x)
		minimum.y = minf(minimum.y, float(house["z"]) - half.y)
		maximum.x = maxf(maximum.x, float(house["x"]) + half.x)
		maximum.y = maxf(maximum.y, float(house["z"]) + half.y)
	return [minimum.x, minimum.y, maximum.x, maximum.y]

func _build_terrain(earth_material: Material) -> void:
	## Visible ground with its own collision: the invisible 200 m fallback body alone would let
	## the neighbourhood render over empty void.
	var terrain := Node3D.new()
	terrain.name = "ExpansionTerrain"
	add_child(terrain)
	var body := StaticBody3D.new()
	body.name = "ExpansionTerrainCollision"
	terrain.add_child(body)
	var size := Vector3(Layout.TERRAIN["size"].x, Layout.TERRAIN_THICKNESS,
		Layout.TERRAIN["size"].y)
	var centre := Vector3(Layout.TERRAIN["center"].x,
		Layout.TERRAIN_TOP_Y - Layout.TERRAIN_THICKNESS * 0.5, Layout.TERRAIN["center"].y)
	var slab := MeshInstance3D.new()
	var slab_mesh := BoxMesh.new()
	slab_mesh.size = size
	slab.mesh = slab_mesh
	slab.position = centre
	if earth_material != null:
		slab.material_override = earth_material
	terrain.add_child(slab)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = centre
	body.add_child(shape)
	## Wider visible land under and around the walkable plate: no collision, so the town does not
	## float against void and no invisible walkable area appears beyond the real plate.
	var outskirts := MeshInstance3D.new()
	var outskirts_mesh := BoxMesh.new()
	outskirts_mesh.size = Vector3(Layout.OUTSKIRTS["size"].x, 0.4, Layout.OUTSKIRTS["size"].y)
	outskirts.mesh = outskirts_mesh
	outskirts.position = Vector3(Layout.OUTSKIRTS["center"].x,
		float(Layout.OUTSKIRTS["top_y"]) - 0.2, Layout.OUTSKIRTS["center"].y)
	if earth_material is StandardMaterial3D:
		var dull := (earth_material as StandardMaterial3D).duplicate() as StandardMaterial3D
		dull.albedo_color = Color(0.38, 0.36, 0.28)
		outskirts.material_override = dull
	terrain.add_child(outskirts)

func _build_paving(paving_material: Material) -> void:
	var paving := Node3D.new()
	paving.name = "ExpansionPaving"
	add_child(paving)
	var body := StaticBody3D.new()
	body.name = "ExpansionPavingCollision"
	paving.add_child(body)
	for road in Layout.ROADS:
		var slab := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(road["size"].x, Layout.ROAD_THICKNESS, road["size"].y)
		slab.mesh = mesh
		slab.position = Vector3(road["center"].x,
			Layout.PAVING_TOP_Y - Layout.ROAD_THICKNESS * 0.5, road["center"].y)
		if paving_material != null:
			slab.material_override = paving_material
		paving.add_child(slab)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = mesh.size
		shape.shape = box
		shape.position = slab.position
		body.add_child(shape)
	for bed in Layout.COMMONS_BEDS:
		var bed_slab := MeshInstance3D.new()
		var bed_mesh := BoxMesh.new()
		bed_mesh.size = Vector3(bed["size"].x, 0.16, bed["size"].y)
		bed_slab.mesh = bed_mesh
		bed_slab.position = Vector3(bed["center"].x,
			Layout.PAVING_TOP_Y + 0.04, bed["center"].y)
		paving.add_child(bed_slab)

func _build_junction_ramp(paving_material: Material) -> void:
	var ramp := Layout.JUNCTION_RAMP
	var length: float = float(ramp["z_to"]) - float(ramp["z_from"])
	var drop: float = float(ramp["y_from"]) - float(ramp["y_to"])
	var angle := atan2(drop, length)
	var centre := Vector3(float(ramp["x"]),
		(float(ramp["y_from"]) + float(ramp["y_to"])) * 0.5 - float(ramp["thickness"]) * 0.5,
		(float(ramp["z_from"]) + float(ramp["z_to"])) * 0.5)
	var size := Vector3(float(ramp["half_width"]) * 2.0, float(ramp["thickness"]),
		sqrt(length * length + drop * drop))
	var node := Node3D.new()
	node.name = "ExpansionJunctionRamp"
	add_child(node)
	var slab := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	slab.mesh = mesh
	if paving_material != null:
		slab.material_override = paving_material
	slab.position = centre
	slab.rotation.x = angle
	node.add_child(slab)
	var body := StaticBody3D.new()
	body.name = "ExpansionJunctionRampCollision"
	node.add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = centre
	shape.rotation.x = angle
	body.add_child(shape)

func _build_houses() -> void:
	var group := Node3D.new()
	group.name = "ExpansionHouses"
	add_child(group)
	var index := 0
	for house in Layout.HOUSES:
		index += 1
		var variant: int = house["variant"]
		var node: Node3D
		if variant == 6:
			node = HOUSE6_COMPONENT.new()
		else:
			node = HOUSE_COMPONENT.new()
			node.set("variant", variant)
		node.name = "ExpansionHouse%02d_V%d" % [index, variant]
		node.set("collision_enabled", true)
		node.position = Vector3(house["x"], 0.0, house["z"])
		node.rotation.y = deg_to_rad(house["yaw"])
		node.set_meta("expansion_house", true)
		node.set_meta("expansion_variant", variant)
		group.add_child(node)
		houses.append(node)

func _build_kit_props() -> void:
	var group := Node3D.new()
	group.name = "ExpansionProps"
	add_child(group)
	for prop in Layout.KIT_PROPS:
		var solid: bool = Layout.SOLID_IDS.has(str(prop["id"]).trim_prefix("F1_"))
		var node := PLANTS.create(prop["id"], solid)
		if node == null:
			load_failures.append(str(prop["id"]))
			continue
		node.position = Vector3(prop["x"], 0.0, prop["z"])
		node.rotation.y = deg_to_rad(prop["yaw"])
		node.set_meta("solid", solid)
		group.add_child(node)
		placed_kit += 1

func _build_perimeter() -> void:
	## Soft landscape edge: existing kit vegetation and rocks ring the walkable plate so the
	## neighbourhood edge reads as countryside instead of a hard rectangle.
	var group := Node3D.new()
	group.name = "ExpansionPerimeter"
	add_child(group)
	for prop in Layout.PERIMETER:
		var solid: bool = Layout.SOLID_IDS.has(str(prop["id"]).trim_prefix("F1_"))
		var node := PLANTS.create(prop["id"], solid)
		if node == null:
			load_failures.append(str(prop["id"]))
			continue
		node.position = Vector3(prop["x"], 0.0, prop["z"])
		node.rotation.y = deg_to_rad(float(prop["yaw"]))
		group.add_child(node)
		placed_perimeter += 1

func _place_generated(group: Node3D, directory: String, entry: Dictionary,
		position: Vector3, yaw_degrees: float, collide: bool = false) -> bool:
	var path := directory + str(entry["file"])
	var packed := load(path) as PackedScene
	if packed == null:
		## A missing import must never be counted as a placed detail; it is recorded instead.
		push_error("Generated asset failed to load: " + path)
		load_failures.append(str(entry["file"]))
		return false
	var node := packed.instantiate() as Node3D
	if node == null:
		push_error("Generated asset is not a Node3D: " + path)
		load_failures.append(str(entry["file"]))
		return false
	node.position = position
	node.rotation.y = deg_to_rad(yaw_degrees)
	node.set_meta("generated_asset", entry["file"])
	group.add_child(node)
	if collide and not VISUAL_ONLY_PROPS.has(str(entry["file"])):
		_add_prop_collision(node, str(entry["file"]))
	return true

func _add_prop_collision(node: Node3D, file_name: String) -> void:
	## Simple solid core from the model's own transformed bounds, shrunk per prop so open tents
	## and wagon beds keep their intended walkable interior instead of a giant box.
	var bounds := AABB()
	var first := true
	for mesh in node.find_children("*", "MeshInstance3D", true, false):
		var item: MeshInstance3D = mesh
		var box: AABB = item.transform * item.mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	if first:
		return
	var shrink: float = PROP_SHRINK.get(file_name, DEFAULT_SHRINK)
	var size := Vector3(maxf(bounds.size.x * shrink, 0.22), maxf(bounds.size.y, 0.35),
		maxf(bounds.size.z * shrink, 0.22))
	var body := StaticBody3D.new()
	body.name = "GeneratedAssetCollision"
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	shape.position = Vector3(bounds.get_center().x, size.y * 0.5, bounds.get_center().z)
	body.add_child(shape)
	node.add_child(body)

func _facade_point(house_index: int, height: float, offset: float) -> Vector3:
	## Street-facing facade point: the shells' front is local -z, so a positive offset moves a
	## detail out of the wall toward the street and yaw rotates it with the shell.
	var house: Dictionary = Layout.HOUSES[house_index]
	var yaw := deg_to_rad(float(house["yaw"]))
	var rotated := Vector3(0.0, height, -offset).rotated(Vector3.UP, yaw)
	return Vector3(float(house["x"]) + rotated.x, height, float(house["z"]) + rotated.z)

func _build_shopfronts() -> void:
	var group := Node3D.new()
	group.name = "ExpansionShopfronts"
	add_child(group)
	for detail in Layout.SHOPFRONTS:
		var house: Dictionary = Layout.HOUSES[int(detail["house"])]
		if _place_generated(group, Layout.SHOPFRONT_DIR, detail,
				_facade_point(int(detail["house"]), float(detail["y"]), float(detail["z_off"])),
				float(house["yaw"])):
			placed_details += 1

func _build_workshops() -> void:
	var group := Node3D.new()
	group.name = "ExpansionWorkshops"
	add_child(group)
	for entry in Layout.WORKSHOPS:
		if _place_generated(group, Layout.WORKSHOP_DIR, entry,
				Vector3(entry["x"], Layout.PAVING_TOP_Y, entry["z"]), float(entry["yaw"]), true):
			placed_workshops += 1

func _build_caravan() -> void:
	var group := Node3D.new()
	group.name = "ExpansionCaravan"
	add_child(group)
	for entry in Layout.CARAVAN:
		if _place_generated(group, Layout.CARGO_DIR, entry,
				Vector3(entry["x"], Layout.TERRAIN_TOP_Y, entry["z"]), float(entry["yaw"]), true):
			placed_cargo += 1
