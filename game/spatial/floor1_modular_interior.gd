class_name Floor1ModularInterior
extends Node3D
## Independent, removable ground-floor art insert for a true modular house.
## Attach as a direct child of ModularHouseComponent after its variant is set.
## All positions are in the house's Godot Y-up local metres; upper floors and
## resident/NPC behavior are outside this art insert.

const WORKSHOP_ROOT := "res://assets/generated/artisan_workshops_20260912/"
const LANTERN_SOURCE := "res://assets/generated/travel_cargo_20260912/caged_travel_lantern.glb"
const BAKERY_SIGN_SOURCE := "res://assets/generated/shopfront_details_20260912/SF13_Bakery_Pretzel_Emblem.glb"
const KINDS := {
	"01_hearth_cottage": "home",
	"02_market_house": "bakery",
	"03_corner_turret": "artisan",
}

@export var interior_kind: String = ""
@export var build_on_ready: bool = true
@export var show_bakery_exterior_sign: bool = true

var host: ModularHouseComponent = null
var room: Node3D = null
var _built := false
var _materials: Dictionary = {}
var _prop_instances := 0
var _solid_proxies := 0
var _workshop_assets: Array[String] = []
var removable_floor: Node3D = null
var bakery_sign: Node3D = null


func _ready() -> void:
	if build_on_ready:
		build()


func build() -> bool:
	if _built:
		return true
	host = get_parent() as ModularHouseComponent
	if host == null or not host.build():
		push_error("Floor1ModularInterior must be a child of a built ModularHouseComponent")
		return false
	var expected: String = KINDS.get(host.variant_id, "")
	if expected.is_empty():
		push_error("Floor1ModularInterior has no layout for " + host.variant_id)
		return false
	if interior_kind.is_empty():
		interior_kind = expected
	if interior_kind != expected:
		push_error("Floor1ModularInterior %s layout does not fit %s" % [interior_kind, host.variant_id])
		return false
	room = Node3D.new()
	room.name = interior_kind.capitalize() + "GroundFloor"
	add_child(room)
	_build_floor_and_trim()
	match interior_kind:
		"home": _build_home()
		"bakery":
			_build_bakery()
			if show_bakery_exterior_sign:
				_attach_bakery_exterior_sign()
		"artisan": _build_artisan()
	var lamp_at := Vector3(-1.35, 2.46, -0.78) if interior_kind == "artisan" else Vector3(0.35, 2.46, -0.85)
	if _build_caged_lantern(lamp_at):
		# A 0.16 m dark ceiling mount and 0.20 m iron hanger meet the
		# existing lantern ring, without the earlier broad illuminated disc.
		_cylinder("LampCeilingMount", 0.08, 0.06,
			lamp_at + Vector3(0.0, 0.48, 0.0), "iron", 10)
		_cylinder("LampHanger", 0.0125, 0.20,
			lamp_at + Vector3(0.0, 0.38, 0.0), "iron", 8)
		(room.find_child("LampCeilingMount", false, false) as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		(room.find_child("LampHanger", false, false) as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	else:
		# The complete visual is optional; the original local light and shade
		# still work if the independent imported unit is unavailable.
		_cylinder("LampCeilingCup", 0.24, 0.08,
			lamp_at + Vector3(0.0, 0.29, 0.0), "iron", 12)
		_cylinder("LampChain", 0.035, 0.30,
			lamp_at + Vector3(0.0, 0.14, 0.0), "iron", 8)
		_cylinder("WarmLanternShade", 0.25, 0.24,
			lamp_at, "lamp_glow", 12)
	var light := OmniLight3D.new()
	light.name = "WarmInteriorFill"
	light.light_color = Color.html("FFE8BF")
	light.light_energy = 0.80
	light.omni_range = 4.6
	light.shadow_enabled = true
	light.position = lamp_at
	room.add_child(light)
	_built = true
	return true


func art_metrics() -> Dictionary:
	return {"kind": interior_kind, "variant": host.variant_id if host != null else "",
		"prop_instances": _prop_instances, "solid_proxies": _solid_proxies,
		"workshop_assets": _workshop_assets.duplicate(), "ground_floor_only": true,
		"removable_floor": removable_floor != null, "local_shadow_lights": 1,
		"bakery_exterior_sign": bakery_sign != null}


func route_waypoints_local() -> Array[Vector3]:
	# Capsule-centre corridor from the true door to useful room circulation.
	match interior_kind:
		"home": return [Vector3(0.0, 0.93, 3.50), Vector3(0.0, 0.93, -1.18),
			Vector3(1.00, 0.93, -1.18)] # left edge of dining table
		"bakery": return [Vector3(-0.9, 0.93, 4.50), Vector3(-0.9, 0.93, 0.20),
			Vector3(1.15, 0.93, 0.20)] # serving counter
		"artisan": return [Vector3(2.2, 0.93, 3.50), Vector3(2.2, 0.93, 0.0),
			Vector3(-1.75, 0.93, 0.0), Vector3(-1.75, 0.93, 1.25)] # workbench
	return []


func _build_floor_and_trim() -> void:
	# This floor is a removable visual unit above the house's true collidable
	# shell floor. Its top is at y=0.03, below the grounded walker's capsule.
	var space: Dictionary = host.house["spaces"][0]
	var x_range: Array = space["x"]
	var y_range: Array = space["y"]
	var left := float(x_range[0]) + 0.16
	var right := float(x_range[1]) - 0.16
	var back := -float(y_range[1]) + 0.16
	var front := -float(y_range[0]) - 0.16
	var width := right - left
	var depth := front - back
	removable_floor = Node3D.new()
	removable_floor.name = "RemovableGroundFloor"
	room.add_child(removable_floor)
	var floor_key := "floor_oak" if interior_kind == "home" else (
		"floor_stone" if interior_kind == "bakery" else "floor_slate")
	_floor_box("GroundFloorSurface", Vector3(width, 0.020, depth),
		Vector3((left + right) * 0.5, 0.018, (back + front) * 0.5), floor_key)
	if interior_kind == "home":
		var x := left + 0.55
		while x < right - 0.25:
			_floor_box("PlankJoint", Vector3(0.014, 0.002, depth),
				Vector3(x, 0.029, (back + front) * 0.5), "floor_joint")
			x += 0.56
	else:
		var x := left + 0.95
		while x < right - 0.25:
			_floor_box("StoneJointX", Vector3(0.014, 0.002, depth),
				Vector3(x, 0.029, (back + front) * 0.5), "floor_joint")
			x += 0.96
		var z := back + 0.95
		while z < front - 0.25:
			_floor_box("StoneJointZ", Vector3(width, 0.002, 0.014),
				Vector3((left + right) * 0.5, 0.029, z), "floor_joint")
			z += 0.96
	# The corner house's orthogonal rear wing is a second real interior
	# footprint. Its original shell floor was visibly blue beside the slate
	# main room in the actual furnished-world eye-height image. This matching
	# visual floor meets the main surface edge at z=-3.34 without overlap;
	# neither the physical shell floor nor the route/door colliders are touched.
	if interior_kind == "artisan":
		var wing: Dictionary = host.house["spaces"][1]
		var wing_x: Array = wing["x"]
		var wing_y: Array = wing["y"]
		var wing_left := float(wing_x[0]) + 0.16
		var wing_right := float(wing_x[1]) - 0.16
		var wing_back := -float(wing_y[1]) + 0.16
		var wing_front := -float(wing_y[0]) + 0.16
		var wing_width := wing_right - wing_left
		var wing_depth := wing_front - wing_back
		_floor_box("WingSlateFloorSurface", Vector3(wing_width, 0.020, wing_depth),
			Vector3((wing_left + wing_right) * 0.5, 0.018,
				(wing_back + wing_front) * 0.5), "floor_slate")
		var wing_seam_x := wing_left + 0.95
		while wing_seam_x < wing_right - 0.25:
			_floor_box("WingStoneJointX", Vector3(0.014, 0.002, wing_depth),
				Vector3(wing_seam_x, 0.029, (wing_back + wing_front) * 0.5), "floor_joint")
			wing_seam_x += 0.96
		var wing_seam_z := wing_back + 0.95
		while wing_seam_z < wing_front - 0.25:
			_floor_box("WingStoneJointZ", Vector3(wing_width, 0.002, 0.014),
				Vector3((wing_left + wing_right) * 0.5, 0.029, wing_seam_z), "floor_joint")
			wing_seam_z += 0.96
	# Baseboard is interrupted at the actual 1.2 m doorway. Windows begin
	# above a 0.95 m sill, so this low course never crosses glazing.
	var trim_key := "dark_oak" if interior_kind == "home" else "trim"
	_box("RearWallBaseTrim", Vector3(width, 0.22, 0.08),
		Vector3((left + right) * 0.5, 0.15, back + 0.04), trim_key)
	for side_x in [left + 0.04, right - 0.04]:
		_box("SideWallBaseTrim", Vector3(0.08, 0.22, depth),
			Vector3(side_x, 0.15, (back + front) * 0.5), trim_key)
	var door: Dictionary = host.door_opening_godot()
	var door_x: float = door["centre"].x
	var door_half: float = door["size"].x * 0.5 + 0.10
	for span in [Vector2(left, door_x - door_half), Vector2(door_x + door_half, right)]:
		if span.y - span.x > 0.03:
			_box("FrontWallBaseTrim", Vector3(span.y - span.x, 0.22, 0.08),
				Vector3((span.x + span.y) * 0.5, 0.15, front - 0.04), trim_key)
	# One clean timber beam below the first upstairs slab gives the ceiling a
	# readable scale and stays above 2.2 m door/window heads.
	_box("CeilingOakBeam", Vector3(width - 0.16, 0.16, 0.18),
		Vector3((left + right) * 0.5, 2.72, -0.05), "oak")


func _floor_box(label: String, size: Vector3, at: Vector3, material_key: String) -> void:
	var shape := BoxMesh.new()
	shape.size = size
	var visual := MeshInstance3D.new()
	visual.name = label
	visual.mesh = shape
	visual.material_override = _material(material_key)
	visual.position = at
	removable_floor.add_child(visual)
	_prop_instances += 1


func _build_caged_lantern(lamp_at: Vector3) -> bool:
	# Reuse the existing 968-triangle iron/copper/glass asset as one removable
	# visual. Its Y-up bottom is 0 and top 0.658 m: at 0.70 scale the ring
	# meets the old ceiling cup while the glass surrounds the original light.
	var source := load(LANTERN_SOURCE) as PackedScene
	if source == null:
		return false
	var visual := source.instantiate() as Node3D
	if visual == null:
		return false
	var cage := visual as MeshInstance3D
	if cage == null:
		cage = visual.find_child("TC_caged_travel_lantern", true, false) as MeshInstance3D
	if cage == null or cage.mesh == null or cage.mesh.get_surface_count() < 4:
		visual.free()
		return false
	var source_glass := cage.get_active_material(1) as StandardMaterial3D
	var warm_glass := StandardMaterial3D.new()
	if source_glass != null:
		warm_glass = source_glass.duplicate() as StandardMaterial3D
	warm_glass.albedo_color = Color.html("D7BE8F")
	warm_glass.emission_enabled = true
	warm_glass.emission = Color.html("F6DEA9")
	warm_glass.emission_energy_multiplier = 0.24
	cage.set_surface_override_material(1, warm_glass)
	# With the light inside the small cage, its self-shadow projects large
	# hard wedges onto the ceiling. The unchanged shadow-casting OmniLight
	# still provides contact shadows from the room's solid furniture.
	cage.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.name = "CagedLanternVisual"
	visual.scale = Vector3.ONE * 0.70
	visual.position = lamp_at + Vector3(0.0, -0.17, 0.0)
	room.add_child(visual)
	_prop_instances += 1
	return true


func _build_home() -> void:
	# Oak bed by the rear-left wall, its woven cover and linen pillows kept below
	# the first-floor ceiling. Furnishings never enter the central door route.
	_box("BedFrame", Vector3(1.82, 0.28, 2.04), Vector3(-2.55, 0.18, -1.65), "oak")
	for x in [-3.34, -1.76]:
		for z in [-2.53, -0.77]:
			_box("BedLeg", Vector3(0.13, 0.42, 0.13), Vector3(x, 0.21, z), "dark_oak")
	_box("BedLinen", Vector3(1.66, 0.13, 1.82), Vector3(-2.55, 0.40, -1.65), "linen")
	_box("BedFold", Vector3(1.69, 0.04, 0.56), Vector3(-2.55, 0.49, -0.96), "teal_cloth")
	for x in [-2.97, -2.14]:
		_box("Pillow", Vector3(0.62, 0.14, 0.38), Vector3(x, 0.55, -2.30), "cream")
	_box("BedHeadboard", Vector3(1.85, 0.86, 0.09), Vector3(-2.55, 0.56, -2.70), "oak")
	_proxy("Bed", Vector3(1.82, 0.72, 2.04), Vector3(-2.55, 0.36, -1.65))
	# Chest under the left window has a distinct lid, iron bands and latch.
	_box("ChestBody", Vector3(1.15, 0.68, 0.64), Vector3(-3.05, 0.35, 1.42), "oak")
	_box("ChestLid", Vector3(1.22, 0.10, 0.70), Vector3(-3.05, 0.75, 1.42), "dark_oak")
	for x in [-3.43, -2.67]:
		_box("ChestBand", Vector3(0.06, 0.72, 0.67), Vector3(x, 0.38, 1.42), "iron")
	_box("ChestLatch", Vector3(0.13, 0.13, 0.035), Vector3(-3.05, 0.54, 1.075), "iron")
	_proxy("Chest", Vector3(1.22, 0.80, 0.70), Vector3(-3.05, 0.40, 1.42))
	# Table, two stools and small ceramics make a livable room without filling it.
	_box("TableTop", Vector3(1.58, 0.09, 1.00), Vector3(2.30, 0.86, -1.18), "oak")
	for x in [1.65, 2.95]:
		for z in [-1.57, -0.79]:
			_box("TableLeg", Vector3(0.12, 0.82, 0.12), Vector3(x, 0.41, z), "dark_oak")
	_cylinder("TablePlate", 0.21, 0.035, Vector3(2.16, 0.93, -1.37), "cream", 14)
	for z in [-1.47, -0.91]:
		_cylinder("Cup", 0.07, 0.12, Vector3(2.70, 0.96, z), "teal_cloth", 10)
	_proxy("Table", Vector3(1.63, 0.88, 1.06), Vector3(2.30, 0.44, -1.18))
	for z in [-2.15, -0.25]:
		_cylinder("StoolSeat", 0.26, 0.08, Vector3(2.30, 0.46, z), "oak", 10)
		_cylinder("StoolStem", 0.08, 0.43, Vector3(2.30, 0.22, z), "dark_oak", 8)
	# Small stone hearth on the back-right wall; no gameplay fire state.
	_box("HearthStone", Vector3(0.92, 1.18, 0.51), Vector3(3.12, 0.59, -2.73), "stone")
	_box("HearthRecess", Vector3(0.70, 0.49, 0.035), Vector3(3.12, 0.45, -2.455), "charcoal")
	for x in [2.74, 3.50]:
		_box("HearthJamb", Vector3(0.12, 0.62, 0.08), Vector3(x, 0.44, -2.425), "trim")
	_box("HearthHead", Vector3(0.90, 0.10, 0.10), Vector3(3.12, 0.82, -2.425), "trim")
	_box("HearthMantel", Vector3(1.09, 0.13, 0.58), Vector3(3.12, 1.24, -2.72), "trim")
	_proxy("Hearth", Vector3(1.09, 1.32, 0.58), Vector3(3.12, 0.66, -2.72))
	_box("WovenRunner", Vector3(0.92, 0.015, 1.76), Vector3(0.28, 0.018, 0.10), "teal_cloth")


func _build_bakery() -> void:
	_asset("BakersOvenPeelRack", "bakers_oven_peel_rack", Vector3(-2.72, 0.0, -2.90),
		90.0, Vector3(0.61, 1.91, 1.18))
	_asset("GrainHandQuern", "grain_hand_quern", Vector3(-2.12, 0.0, -1.55),
		20.0, Vector3(0.96, 1.12, 0.83))
	# Deep clay arch behind the baker's oven model reads as a stone oven hearth,
	# while the imported artisan asset retains its peel rack and metalwork.
	_box("OvenMasonry", Vector3(0.88, 1.37, 0.43), Vector3(-2.22, 0.69, -4.15), "stone")
	_box("OvenMouth", Vector3(0.56, 0.55, 0.025), Vector3(-2.22, 0.51, -3.92), "charcoal")
	for x in [-2.58, -1.86]:
		_box("OvenStoneJamb", Vector3(0.16, 0.82, 0.10),
			Vector3(x, 0.51, -3.895), "trim")
	for x in [-2.57, -2.40, -2.22, -2.04, -1.87]:
		var arch_height := 1.12 if absf(x + 2.22) > 0.30 else (1.31 if absf(x + 2.22) > 0.10 else 1.41)
		_box("OvenArchVoussoir", Vector3(0.20, 0.16, 0.11),
			Vector3(x, arch_height, -3.895), "trim")
	_box("OvenHearthLedge", Vector3(0.93, 0.11, 0.34),
		Vector3(-2.22, 0.17, -3.79), "stone")
	_box("OvenCrown", Vector3(1.01, 0.11, 0.47), Vector3(-2.22, 1.43, -4.14), "trim")
	_proxy("StoneOven", Vector3(1.01, 1.49, 0.52), Vector3(-2.22, 0.75, -4.14))
	# Serving bay on the right leaves the -0.9 m door-axis route empty.
	_box("CounterBody", Vector3(0.82, 0.77, 2.48), Vector3(2.12, 0.39, 0.20), "dark_oak")
	_box("CounterTop", Vector3(1.01, 0.10, 2.66), Vector3(2.12, 0.83, 0.20), "oak")
	for z in [-0.72, -0.15, 0.44, 0.94]:
		_loaf(Vector3(2.09, 0.96, z), 0.20)
	_proxy("ServingCounter", Vector3(1.01, 0.88, 2.66), Vector3(2.12, 0.44, 0.20))
	# Rear shelving, sacks and flour bin are on the side opposite the oven.
	for level in [0.46, 0.98, 1.55]:
		_box("BakeryShelf", Vector3(0.57, 0.08, 2.25), Vector3(2.62, level, -2.72), "oak")
	for z in [-3.68, -1.76]:
		_box("BakeryShelfPost", Vector3(0.10, 1.76, 0.10), Vector3(2.62, 0.88, z), "dark_oak")
	for z in [-3.28, -2.58, -1.98]:
		_box("FlourSack", Vector3(0.39, 0.38, 0.42), Vector3(2.62, 1.24, z), "linen")
	_proxy("BakeryShelf", Vector3(0.67, 1.77, 2.30), Vector3(2.62, 0.89, -2.72))
	_box("FlourBin", Vector3(0.66, 0.69, 0.66), Vector3(-2.35, 0.35, 1.50), "oak")
	_box("FlourBinLid", Vector3(0.72, 0.08, 0.72), Vector3(-2.35, 0.74, 1.50), "linen")
	_proxy("FlourBin", Vector3(0.72, 0.78, 0.72), Vector3(-2.35, 0.39, 1.50))


func _attach_bakery_exterior_sign() -> bool:
	# Only the furnished bakery receives this independent exterior identity.
	# The existing SF13 model includes its own slim iron wall plate, diagonal
	# support, hanging timber double-knot emblem and brass fasteners: no duplicate bracket.
	# Its raw Godot +Z projects toward the street from the merchant +Z facade.
	# Full raw bounds at this anchor: x -2.78..-1.92, y 2.68..3.82,
	# z 4.62..5.509 m. The door is x -1.5..-0.3, top y 2.2 m.
	var source := load(BAKERY_SIGN_SOURCE) as PackedScene
	if source == null:
		return false
	var visual := source.instantiate() as Node3D
	if visual == null:
		return false
	var oak_mesh := visual.find_child("SF13_Bakery_Pretzel_Emblem", true, false) as MeshInstance3D
	if oak_mesh == null or oak_mesh.mesh == null or oak_mesh.mesh.get_surface_count() != 3:
		visual.free()
		return false
	# The unmodified source's light-oak surface is dark under the shop's
	# canvas shadow. A duplicated local material keeps its normal detail but
	# lifts the double-knot silhouette to a honey-oak value visible from street.
	var source_oak := oak_mesh.get_active_material(2) as StandardMaterial3D
	if source_oak != null:
		var readable_oak := source_oak.duplicate() as StandardMaterial3D
		readable_oak.albedo_color = Color.html("B99767")
		oak_mesh.set_surface_override_material(2, readable_oak)
	visual.name = "BakeryExteriorSign"
	visual.position = Vector3(-2.35, 2.68, 4.62)
	room.add_child(visual)
	bakery_sign = visual
	_prop_instances += 1
	return true


func _build_artisan() -> void:
	_asset("ForgeWithBellows", "forge_with_bellows", Vector3(-3.12, 0.0, -2.10),
		0.0, Vector3(1.46, 1.48, 1.07))
	_asset("HornAnvilStump", "horn_anvil_stump", Vector3(-0.92, 0.0, -1.52),
		0.0, Vector3(0.72, 1.08, 0.72))
	# Solid workbench opposite the door's right-hand entrance run.
	_box("SmithBenchTop", Vector3(1.45, 0.10, 0.83), Vector3(-3.02, 0.88, 1.25), "oak")
	for x in [-3.66, -2.38]:
		for z in [0.93, 1.57]:
			_box("SmithBenchLeg", Vector3(0.12, 0.86, 0.12), Vector3(x, 0.43, z), "dark_oak")
	_box("SmithBenchVice", Vector3(0.20, 0.24, 0.26), Vector3(-2.50, 1.05, 1.15), "iron")
	for offset in [-0.42, 0.0, 0.42]:
		_box("SmithTool", Vector3(0.05, 0.05, 0.49),
			Vector3(-3.02 + offset, 0.97, 1.25), "iron")
	_proxy("SmithBench", Vector3(1.50, 0.96, 0.87), Vector3(-3.02, 0.48, 1.25))
	_box("OreChest", Vector3(0.78, 0.63, 0.65), Vector3(3.38, 0.32, -2.73), "dark_oak")
	_box("OreChestBand", Vector3(0.80, 0.06, 0.67), Vector3(3.38, 0.59, -2.73), "iron")
	_proxy("OreChest", Vector3(0.80, 0.67, 0.67), Vector3(3.38, 0.34, -2.73))
	# A wall rack above the left bench hints at routine work, without hanging in
	# the 1.2 m true door aperture or the 0.9 m room circulation lane.
	_box("ToolRail", Vector3(1.39, 0.09, 0.09), Vector3(-3.06, 1.81, 2.02), "oak")
	for x in [-3.52, -3.05, -2.58]:
		_box("ToolHook", Vector3(0.04, 0.29, 0.05), Vector3(x, 1.63, 2.02), "iron")


func _asset(label: String, asset_id: String, at: Vector3, yaw_deg: float,
		proxy_size: Vector3) -> void:
	var path := WORKSHOP_ROOT + asset_id + ".glb"
	var packed := load(path) as PackedScene
	if packed == null:
		push_error("Floor1ModularInterior asset missing: " + path)
		return
	var visual := packed.instantiate() as Node3D
	if visual == null:
		return
	visual.name = label
	visual.position = at
	visual.rotation_degrees.y = yaw_deg
	room.add_child(visual)
	for mesh in visual.find_children("*", "MeshInstance3D", true, false):
		if String(mesh.name).begins_with("COL_"):
			mesh.visible = false
	_prop_instances += 1
	_workshop_assets.append(asset_id)
	_proxy(label, proxy_size, at + Vector3(0.0, proxy_size.y * 0.5, 0.0))


func _box(label: String, size: Vector3, at: Vector3, material_key: String) -> void:
	var shape := BoxMesh.new()
	shape.size = size
	_mesh(label, shape, at, material_key)


func _cylinder(label: String, radius: float, height: float, at: Vector3,
		material_key: String, sides: int) -> void:
	var shape := CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = height
	shape.radial_segments = sides
	_mesh(label, shape, at, material_key)


func _loaf(at: Vector3, radius: float) -> void:
	var shape := SphereMesh.new()
	shape.radius = radius
	shape.height = radius * 1.10
	shape.radial_segments = 12
	shape.rings = 6
	_mesh("BreadLoaf", shape, at, "bread")
	_box("LoafSlash", Vector3(radius * 0.72, 0.014, 0.025),
		at + Vector3(0.0, radius * 0.49, 0.0), "cream")


func _mesh(label: String, shape: Mesh, at: Vector3, material_key: String) -> void:
	var visual := MeshInstance3D.new()
	visual.name = label
	visual.mesh = shape
	visual.material_override = _material(material_key)
	visual.position = at
	room.add_child(visual)
	_prop_instances += 1


func _material(key: String) -> StandardMaterial3D:
	if _materials.has(key):
		return _materials[key]
	var codes := {"oak": "9A7450", "dark_oak": "614934", "linen": "CDBDA0",
		"cream": "EAE1CA", "teal_cloth": "68817B", "stone": "AFA58E",
		"trim": "D2C0A2", "charcoal": "3D4542", "iron": "485657", "bread": "BD8651",
		"floor_oak": "B49870", "floor_stone": "A3A08E", "floor_slate": "929895",
		"floor_joint": "695E4E", "lamp_glow": "F2D8A4"}
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.html(codes.get(key, "C9C1AD"))
	mat.roughness = 0.84 if key in ["stone", "linen", "charcoal"] else 0.69
	if key == "lamp_glow":
		mat.emission_enabled = true
		mat.emission = Color.html("F6DEA9")
		mat.emission_energy_multiplier = 0.35
	_materials[key] = mat
	return mat


func _proxy(label: String, size: Vector3, centre: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = label + "Proxy"
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	collision.shape = box
	body.add_child(collision)
	body.position = centre
	room.add_child(body)
	_solid_proxies += 1
