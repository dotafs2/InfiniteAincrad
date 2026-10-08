extends "res://fidelity/toy_city.gd"
## Original Arctic presentation over the proven whole-body edible physics plan.
## Snow and ice are visual assemblies; edible bodies remain the inherited real
## compound colliders, support graph and whole-body collection path.
const FrostNeighborhoods = preload("res://fidelity/frost_neighborhoods.gd")
const Ice = preload("res://fidelity/frost_ice.gd")
const LegacyCastlePhysics = preload("res://fidelity/frost_legacy_castle_physics.gd")
var frost_decorations := 0
var ice_spires := 0
var frozen_ponds := 0
var snow_material: StandardMaterial3D
var ice_material: StandardMaterial3D
var trim_material: StandardMaterial3D
var decor_root: Node3D
var species_materials: Dictionary = {}
var frost_species_counts: Dictionary = {}
var castle_visuals_removed := 0
var arctic_ice_structures := 0
var inherited_batches_detached := false
var blender_asset_usage: Dictionary = {}
var polar_visuals_converted := 0
var polar_mesh_cache: Dictionary = {}
var polar_unified_material: StandardMaterial3D

func _body_mesh(kind: String, palette: int) -> ArrayMesh:
	if kind in LegacyCastlePhysics.KINDS:
		return LegacyCastlePhysics.placeholder_mesh()
	return super._body_mesh(kind, palette)

func _body_collision_parts(kind: String) -> Array[PackedVector3Array]:
	if kind in LegacyCastlePhysics.KINDS:
		return LegacyCastlePhysics.collision_parts_for(kind)
	return super._body_collision_parts(kind)

func _unit_geometry(kind: String, mesh: ArrayMesh) -> Dictionary:
	if kind not in LegacyCastlePhysics.KINDS:
		return super._unit_geometry(kind, mesh)
	if not geometry_cache.has(kind):
		geometry_cache[kind] = LegacyCastlePhysics.geometry_for(kind)
	return geometry_cache[kind]

func _build_site_props() -> void:
	# The new palace gardens belong only to Toy Town.
	pass

func build(owner_game: Node) -> void:
	game = owner_game
	# Keep the shared unchanged parcel plan, but use frozen pre-redesign castle
	# physics through the virtual providers above. Its transient proxy visuals
	# are synchronously replaced below before a rendered frame can expose them.
	super.build(owner_game)
	toy_layout["map_id"] = "frost"
	toy_layout["name"] = "Frostlight Village"
	toy_layout["theme"] = "frostlight"
	toy_layout["season"] = "snow"
	toy_layout["frost_parcel_count"] = FrostNeighborhoods.plan().size()
	_build_frost_materials()
	decor_root = Node3D.new()
	decor_root.name = "FrostlightSnowAssemblies"
	add_child(decor_root)
	# ToyCity owns a reusable castle parcel plan. Frostlight keeps the real
	# colliders and progression, but detaches the inherited render batches and
	# gives every architectural parcel an original glacier silhouette.
	_detach_inherited_batches()
	_convert_architecture_to_ice()
	_convert_remaining_toys_to_polar()
	_build_ice_spires()
	_build_snow_drifts()
	_build_frozen_ponds()
	_build_glacier_ridges()
	_build_polar_ecosystems()
	_build_landmark_shoulders()
	_apply_glacier_lighting()
	static_batch_stats = Batch.build(self)

func _detach_inherited_batches() -> void:
	for node in get_children():
		if node is MultiMeshInstance3D:
			node.visible = false
			inherited_batches_detached = true
	for body in foods:
		if not is_instance_valid(body):
			continue
		for handle in body.static_instances:
			var visual: MeshInstance3D = handle.get("visual")
			if is_instance_valid(visual):
				visual.visible = true
		body.static_instances.clear()
	static_batch_stats = {"batches": 0, "meshes": 0, "detached_for_arctic_render": true}

func _convert_architecture_to_ice() -> void:
	var architectural_kinds := ["toy_castle", "grand_castle", "bubble_turret", "block_tower", "toy_arch"]
	for body in foods:
		if not is_instance_valid(body):
			continue
		var original_kind := str(body.get_meta("toy_kind", ""))
		if original_kind not in architectural_kinds:
			continue
		castle_visuals_removed += 1
		body.set_meta("original_toy_kind", original_kind)
		body.set_meta("toy_kind", "glacier_iceberg")
		body.set_meta("frost_species", "glacier_iceberg")
		body.set_meta("arctic_structure", true)
		body.set_meta("dither_building", false)
		body.category = "iceberg"
		var old_visual := body.get_node_or_null("ToyVisual")
		if old_visual != null:
			body.remove_child(old_visual)
			old_visual.free()
		_build_species_visual(body, "glacier_iceberg")
	building_visuals.clear()
	arctic_ice_structures = castle_visuals_removed
	toy_layout["castle_visuals_removed"] = castle_visuals_removed
	toy_layout["arctic_ice_structures"] = arctic_ice_structures

func _build_glacier_ridges() -> void:
	# Small low shelves stay outside the playable slab; all in-world ice bodies
	# above the slab are edible and own their snow. No floating decorations.
	for index in 16:
		var angle:=float(index)*TAU/16.0
		var at:=Vector3(cos(angle)*113.0,-5.0,sin(angle)*113.0)
		var asset:=Ice.make(2,Vector3(15.0+float(index%3)*3.0,3.0+float(index%4),12.0))
		asset.name="IceHorizonShelf_%02d"%index;asset.position+=at;asset.rotation.y=-angle
		decor_root.add_child(asset);frost_decorations+=1

func _build_frost_materials() -> void:
	snow_material = StandardMaterial3D.new()
	snow_material.albedo_color = Color("f8fcff")
	snow_material.roughness = .24
	snow_material.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	snow_material.metallic = .02
	ice_material = StandardMaterial3D.new()
	ice_material.albedo_color = Color("83d8f2")
	ice_material.emission_enabled = true
	ice_material.emission = Color("3ca6dc")
	ice_material.emission_energy_multiplier = .18
	ice_material.metallic = .34
	ice_material.roughness = .07
	ice_material.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	trim_material = StandardMaterial3D.new()
	trim_material.albedo_color = Color("c9e9ff")
	trim_material.metallic = .18
	trim_material.roughness = .13
	trim_material.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX

func _mesh_node(mesh: Mesh, material: Material, at: Vector3, scale: Vector3, name: String) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = name
	visual.mesh = mesh
	visual.material_override = material
	visual.position = at
	visual.scale = scale
	decor_root.add_child(visual)
	frost_decorations += 1
	return visual

func _build_ice_spires() -> void:
	for index in 9:
		var angle:=float(index)*TAU/9.0
		var asset:=Ice.make(3,Vector3(2.6,2.8+float(index%3),2.2))
		asset.name="IceSpire_%03d"%index
		asset.position+=Vector3(cos(angle)*103.0,-1.5,sin(angle)*103.0)
		decor_root.add_child(asset);ice_spires+=1;frost_decorations+=1

func _build_snow_drifts() -> void:
	var points := [Vector3(-34, .04, 28), Vector3(34, .04, 28), Vector3(-34, .04, -21),
		Vector3(34, .04, -21), Vector3(-8, .04, 49), Vector3(11, .04, 49),
		Vector3(-61, .04, 51), Vector3(61, .04, 51), Vector3(-61, .04, -8), Vector3(61, .04, -8),
		Vector3(-18, .04, -75), Vector3(19, .04, -75)]
	for index in points.size():
		var mesh := SphereMesh.new()
		mesh.radius = .5
		mesh.height = 1.0
		mesh.radial_segments = 12
		mesh.rings = 6
		_mesh_node(mesh, snow_material, points[index] + Vector3(0, .30 + float(index % 2) * .15, 0),
			Vector3(4.5 + float(index % 3) * .8, .60 + float(index % 2) * .22, 1.6 + float(index % 2) * .5), "SnowDrift_%03d" % index)

func _frozen_pond(at: Vector3, size: Vector3, index: int) -> void:
	var visual:=Ice.make(5,Vector3(size.x,.08,size.z))
	visual.name="FrozenPond_%02d"%index;visual.position+=at+Vector3(0,-.05,0)
	decor_root.add_child(visual);frozen_ponds+=1;frost_decorations+=1

func _build_frozen_ponds() -> void:
	_frozen_pond(Vector3(-70, .04, 38), Vector3(16, 1, 8), 0)
	_frozen_pond(Vector3(70, .04, 38), Vector3(16, 1, 8), 1)
	_frozen_pond(Vector3(0, .04, -79), Vector3(26, 1, 7), 2)

func _species_material(id: String, color: Color, roughness := .28, metallic := 0.0) -> StandardMaterial3D:
	if species_materials.has(id):
		return species_materials[id]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	material.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	species_materials[id] = material
	return material

func _species_part(parent: Node3D, mesh: Mesh, material: Material, at: Vector3, scale: Vector3, yaw := 0.0) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = material
	visual.position = at
	visual.scale = scale
	visual.rotation.y = yaw
	parent.add_child(visual)
	return visual

func _sphere(parent: Node3D, material: Material, at: Vector3, scale: Vector3) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = .5
	mesh.height = 1.0
	mesh.radial_segments = 12
	mesh.rings = 8
	_species_part(parent, mesh, material, at, scale)

func _box(parent: Node3D, material: Material, at: Vector3, scale: Vector3, yaw := 0.0) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	_species_part(parent, mesh, material, at, scale, yaw)

func _cylinder(parent: Node3D, material: Material, at: Vector3, scale: Vector3, yaw := 0.0) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = .5
	mesh.bottom_radius = .5
	mesh.height = 1.0
	mesh.radial_segments = 10
	_species_part(parent, mesh, material, at, scale, yaw)

func _use_blender_species_asset(body: Node3D, species: String, assembly: Node3D) -> bool:
	if species not in ["glacier_iceberg", "ice_rock", "ice_chip"]:return false
	var index := int(body.get_meta("toy_palette",0)) + int(absf(body.position.x)*.3+absf(body.position.z)*.17)
	var variant := posmod(index,4) if species=="glacier_iceberg" else 4+posmod(index,2)
	var target := Vector3(body.half_size.x*1.90,body.height*(.68 if variant!=2 else .50),body.half_size.z*1.90)
	if species!="glacier_iceberg":target.y=body.height*.90
	var asset := Ice.make(variant,target)
	asset.name="BlenderAuthored_%s"%species
	assembly.add_child(asset)
	asset.position.y-=body.height*.5
	body.set_meta("frost_variant",Ice.NAMES[variant])
	blender_asset_usage[species]=int(blender_asset_usage.get(species,0))+1
	return true

func _convert_remaining_toys_to_polar() -> void:
	for body in foods:
		if body.has_meta("frost_species"):continue
		var role:=str(body.get_meta("court_role",""))
		var kind:=str(body.get_meta("toy_kind",""))
		var species:="ice_chip"
		if body.get_meta("court_actor",false):
			if role in ["guard","captain","knight","sentry","courier","page","herald","toymaker"]:species="scientist"
			elif role in ["king","queen"]:species="polar_bear"
			elif role in ["princess","steward","courtier","jester","drummer","balloon_vendor"]:species="penguin"
			elif "drone" in role or role in ["royal_lantern","bubble_scout","court_clockwork"]:species="aurora_drone"
			elif "beacon" in role:species="glacier_crystal"
			elif kind in ["toy_car","toy_train"]:species="cargo_sled"
		elif kind in ["toy_car","toy_train"]:species="cargo_sled"
		body.set_meta("frost_species",species)
		_build_species_visual(body,species)
		polar_visuals_converted+=1
	# Existing controllers keep their collision handoff and movement, with new
	# polar descendants replacing every toy/court silhouette.
	for row in court.actors:
		if is_instance_valid(row.body):row.visual=row.body.get_node_or_null("FrostSpeciesVisual")
	court.name="PolarExpeditionActivity"

func _apply_glacier_lighting() -> void:
	game.scene_environment.ambient_light_color=Color("b6cfed")
	game.scene_environment.ambient_light_energy=.40
	game.scene_environment.background_color=Color("6589ad")
	game.scene_sun.light_color=Color("e6f2ff")
	game.scene_sun.light_energy=.73
	game.scene_sun.shadow_opacity=.80

func _build_species_visual(body: Node3D, species: String) -> void:
	var old_visual := body.get_node_or_null("ToyVisual")
	if old_visual != null:
		body.remove_child(old_visual)
		old_visual.free()
	var assembly := Node3D.new()
	assembly.name = "FrostSpeciesVisual"
	body.add_child(assembly)
	var s := clampf(float(body.height), .65, 8.0)
	var cache_key:="%s/%.5f"%[species,s]
	if polar_mesh_cache.has(cache_key):
		var cached:=MeshInstance3D.new();cached.mesh=polar_mesh_cache[cache_key];cached.material_override=_polar_material();assembly.add_child(cached);return
	var white := _species_material("snow-white", Color("f4fbff"), .22)
	var ink := _species_material("polar-ink", Color("1b3c60"), .2)
	var navy := _species_material("deep-navy", Color("163f70"), .18, .12)
	var orange := _species_material("beak-orange", Color("ff9b55"), .22)
	var brown := _species_material("walrus-brown", Color("865b4d"), .30)
	var gold := _species_material("station-gold", Color("ffd875"), .20, .10)
	var red := _species_material("expedition-red", Color("ee6b6b"), .24)
	var teal := _species_material("icebreaker-teal", Color("55bfd0"), .14, .25)
	var orange_fur := _species_material("snowfox-orange", Color("eea45c"), .30)
	var charcoal := _species_material("charcoal", Color("33465b"), .36)
	if _use_blender_species_asset(body, species, assembly):
		return
	if species == "polar_bear":
		_sphere(assembly, white, Vector3(0, -.03, 0), Vector3(s*.90, s*.58, s*.62))
		_sphere(assembly, white, Vector3(0, s*.38, s*.05), Vector3(s*.52, s*.46, s*.44))
		_sphere(assembly, ink, Vector3(-s*.18, s*.43, s*.36), Vector3(s*.07, s*.07, s*.045))
		_sphere(assembly, ink, Vector3(s*.18, s*.43, s*.36), Vector3(s*.07, s*.07, s*.045))
		for x in [-.30, .30]: _cylinder(assembly, white, Vector3(x*s, -s*.36, 0), Vector3(s*.22, s*.55, s*.22))
	elif species == "penguin":
		_sphere(assembly, ink, Vector3(0, 0, 0), Vector3(s*.62, s*.92, s*.48))
		_sphere(assembly, white, Vector3(0, -.03, s*.25), Vector3(s*.38, s*.65, s*.18))
		_sphere(assembly, ink, Vector3(0, s*.48, 0), Vector3(s*.46, s*.43, s*.40))
		_box(assembly, orange, Vector3(0, s*.42, s*.34), Vector3(s*.22, s*.12, s*.20))
		for x in [-.22, .22]: _box(assembly, orange, Vector3(x*s, -s*.47, s*.12), Vector3(s*.27, s*.10, s*.38))
	elif species == "seal":
		_sphere(assembly, white, Vector3(0, 0, 0), Vector3(s*1.0, s*.48, s*.48))
		_sphere(assembly, white, Vector3(s*.48, s*.10, s*.02), Vector3(s*.42, s*.35, s*.36))
		_sphere(assembly, ink, Vector3(s*.60, s*.17, s*.30), Vector3(s*.06, s*.06, s*.04))
		_box(assembly, navy, Vector3(-s*.52, -.02, 0), Vector3(s*.42, s*.12, s*.50), -.18)
	elif species == "snow_fox":
		_sphere(assembly, orange_fur, Vector3(0, -.02, 0), Vector3(s*.88, s*.45, s*.45))
		_sphere(assembly, orange_fur, Vector3(s*.40, s*.28, s*.04), Vector3(s*.46, s*.40, s*.37))
		_sphere(assembly, white, Vector3(s*.52, s*.20, s*.30), Vector3(s*.28, s*.20, s*.14))
		_box(assembly, orange_fur, Vector3(-s*.50, s*.12, -.05), Vector3(s*.64, s*.34, s*.34), -.45)
		for x in [-.26, .26]: _cylinder(assembly, orange_fur, Vector3(x*s, -s*.28, 0), Vector3(s*.12, s*.38, s*.12))
	elif species == "walrus":
		_sphere(assembly, brown, Vector3(0, 0, 0), Vector3(s*1.0, s*.60, s*.62))
		_sphere(assembly, brown, Vector3(s*.50, s*.18, s*.05), Vector3(s*.47, s*.48, s*.46))
		for x in [-.13, .13]: _cylinder(assembly, white, Vector3(s*(.50+x), -.02, s*.34), Vector3(s*.09, s*.34, s*.09))
	elif species == "scientist":
		_cylinder(assembly, red, Vector3(0, -.05, 0), Vector3(s*.46, s*.88, s*.40))
		_sphere(assembly, white, Vector3(0, s*.55, 0), Vector3(s*.43, s*.40, s*.40))
		_box(assembly, teal, Vector3(0, s*.55, s*.35), Vector3(s*.28, s*.12, s*.06))
		_box(assembly, charcoal, Vector3(0, -.57*s, 0), Vector3(s*.70, s*.08, s*.48))
	elif species == "icebreaker":
		_box(assembly, teal, Vector3(0, -.12*s, 0), Vector3(s*1.50, s*.35, s*.72), -.08)
		_box(assembly, white, Vector3(s*.10, s*.25, 0), Vector3(s*.58, s*.45, s*.58))
		_box(assembly, red, Vector3(-s*.54, .02*s, 0), Vector3(s*.18, s*.48, s*.76), -.18)
		_cylinder(assembly, gold, Vector3(s*.16, s*.62, 0), Vector3(s*.09, s*.50, s*.09))
	elif species == "research_station":
		_box(assembly, red, Vector3(0, 0, 0), Vector3(s*1.15, s*.78, s*.88))
		_box(assembly, white, Vector3(0, s*.48, 0), Vector3(s*.84, s*.20, s*.68))
		_sphere(assembly, ice_material, Vector3(0, s*.70, 0), Vector3(s*.42, s*.38, s*.42))
		for x in [-.42, .42]: _box(assembly, gold, Vector3(x*s, .02, s*.46), Vector3(s*.16, s*.30, s*.08))
	elif species == "igloo_observatory":
		_sphere(assembly, white, Vector3(0, .05*s, 0), Vector3(s*1.05, s*.78, s*.90))
		_box(assembly, navy, Vector3(0, -.19*s, s*.43), Vector3(s*.32, s*.34, s*.12))
		_cylinder(assembly, ice_material, Vector3(0, s*.72, 0), Vector3(s*.20, s*.35, s*.20))
	elif species == "snowmobile":
		_box(assembly, red, Vector3(0, 0, 0), Vector3(s*1.10, s*.42, s*.58))
		_box(assembly, teal, Vector3(s*.10, s*.34, 0), Vector3(s*.42, s*.42, s*.40))
		for x in [-.38, .38]: _cylinder(assembly, charcoal, Vector3(x*s, -.27*s, 0), Vector3(s*.13, s*.12, s*.66), PI*.5)
	elif species == "cargo_sled":
		_box(assembly, red, Vector3(0, 0, 0), Vector3(s*1.15, s*.32, s*.68))
		_box(assembly, gold, Vector3(0, s*.34, 0), Vector3(s*.72, s*.42, s*.50))
		for x in [-.48, .48]: _cylinder(assembly, teal, Vector3(x*s, -.23*s, 0), Vector3(s*.08, s*.10, s*.72), PI*.5)
	elif species == "aurora_drone":
		_sphere(assembly, teal, Vector3(0, 0, 0), Vector3(s*.55, s*.30, s*.55))
		for x in [-.62, .62]: _box(assembly, gold, Vector3(x*s, 0, 0), Vector3(s*.65, s*.08, s*.08))
		_cylinder(assembly, ice_material, Vector3(0, s*.26, 0), Vector3(s*.08, s*.36, s*.08))
	elif species == "glacier_crystal":
		_cylinder(assembly, ice_material, Vector3(0, s*.30, 0), Vector3(s*.45, s*1.2, s*.45))
		_sphere(assembly, white, Vector3(-s*.40, .02, 0), Vector3(s*.34, s*.48, s*.30))
		_sphere(assembly, white, Vector3(s*.40, .02, 0), Vector3(s*.34, s*.48, s*.30))

	_merge_polar_visual(assembly,cache_key)

func _polar_material() -> StandardMaterial3D:
	if polar_unified_material==null:
		polar_unified_material=StandardMaterial3D.new()
		polar_unified_material.vertex_color_use_as_albedo=true
		polar_unified_material.vertex_color_is_srgb=true
		polar_unified_material.roughness=.30
	return polar_unified_material

func _merge_polar_visual(assembly:Node3D, cache_key:String) -> void:
	# Bake a multi-part polar character once per species/size into one surface.
	# Moving NPCs then need one draw, rather than a draw for every belly/eye/foot.
	var vertices:=PackedVector3Array();var normals:=PackedVector3Array();var colors:=PackedColorArray();var indices:=PackedInt32Array()
	for child in assembly.get_children():
		if not child is MeshInstance3D:continue
		var color:Color=child.material_override.albedo_color
		for surface in child.mesh.get_surface_count():
			var a:Array=child.mesh.surface_get_arrays(surface)
			var vv:PackedVector3Array=a[Mesh.ARRAY_VERTEX];var nn:PackedVector3Array=a[Mesh.ARRAY_NORMAL]
			var ii:PackedInt32Array=a[Mesh.ARRAY_INDEX]
			var offset:=vertices.size()
			for i in vv.size():
				vertices.append(child.transform*vv[i]);normals.append((child.basis.inverse().transposed()*nn[i]).normalized());colors.append(color)
			for i in ii:indices.append(offset+i)
		assembly.remove_child(child);child.free()
	if vertices.is_empty():return
	var arrays:Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals;arrays[Mesh.ARRAY_COLOR]=colors;arrays[Mesh.ARRAY_INDEX]=indices
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	polar_mesh_cache[cache_key]=mesh
	var visual:=MeshInstance3D.new();visual.name="PolarUnifiedMesh";visual.mesh=mesh;visual.material_override=_polar_material();assembly.add_child(visual)

func _add_species_group(species: String, positions: Array, tier: int, size: Vector3, points: int) -> void:
	for index in positions.size():
		var spec: Dictionary = {"kind":"toy_block", "at":positions[index], "size":size,
			"tier":tier, "points":points, "palette":index % 5, "neighborhood":"frost_ecology",
			"yaw":float(index % 4) * PI * .5, "tower_id":"", "tower_level":0, "bottom":.04, "landmark":false}
		var body: Node3D = _make_toy(spec)
		body.name = "Frost_%03d_%s" % [index, species]
		body.category = species
		body.set_meta("toy_kind", species)
		body.set_meta("frost_species", species)
		body.set_meta("frost_group_size", positions.size())
		_build_species_visual(body, species)
		if food_queries != null:
			food_queries.register(body)
		frost_species_counts[species] = int(frost_species_counts.get(species, 0)) + 1

func _build_polar_ecosystems() -> void:
	# Polar wildlife, expedition props and edible ice rocks provide varied sizes
	# and group behavior across the frozen routes.
	_add_species_group("polar_bear", [Vector2(-78,-67), Vector2(-73,-67)], 7, Vector3(4.8,3.2,4.0), 30)
	_add_species_group("penguin", [Vector2(69,-68), Vector2(72,-68), Vector2(75,-68), Vector2(69,-73), Vector2(72,-73), Vector2(75,-73), Vector2(78,-70), Vector2(66,-70)], 2, Vector3(1.15,1.55,1.0), 5)
	_add_species_group("seal", [Vector2(-75,67), Vector2(-71,67), Vector2(-67,67), Vector2(-73,71), Vector2(-69,71)], 3, Vector3(2.0,1.2,1.25), 8)
	_add_species_group("snow_fox", [Vector2(72,66), Vector2(77,68), Vector2(73,72)], 4, Vector3(1.65,1.15,1.1), 12)
	_add_species_group("walrus", [Vector2(-1,76), Vector2(5,76)], 6, Vector3(3.8,2.3,3.0), 22)
	_add_species_group("scientist", [Vector2(-79,-24), Vector2(-76,-24), Vector2(-79,-28), Vector2(-76,-28)], 3, Vector3(1.2,2.1,1.0), 9)
	_add_species_group("icebreaker", [Vector2(0,-78)], 8, Vector3(8.0,3.5,3.5), 40)
	_add_species_group("research_station", [Vector2(-79,28), Vector2(-73,28)], 7, Vector3(5.0,4.0,4.0), 34)
	_add_species_group("igloo_observatory", [Vector2(77,28), Vector2(82,28)], 6, Vector3(4.2,3.2,3.6), 24)
	_add_species_group("snowmobile", [Vector2(-60,-77), Vector2(-54,-77), Vector2(54,-77), Vector2(60,-77)], 4, Vector3(2.6,1.55,1.5), 12)
	_add_species_group("cargo_sled", [Vector2(-58,77), Vector2(-51,77), Vector2(51,77), Vector2(58,77)], 3, Vector3(2.8,1.45,1.8), 10)
	_add_species_group("aurora_drone", [Vector2(-29,-77), Vector2(29,-77), Vector2(0,73)], 5, Vector3(1.8,1.1,1.8), 16)
	_add_species_group("glacier_crystal", [Vector2(-83,56), Vector2(-78,56), Vector2(78,56), Vector2(83,56), Vector2(0,87)], 5, Vector3(2.3,3.6,2.3), 18)
	_add_species_group("ice_rock", [Vector2(-51,-28), Vector2(-45,-25), Vector2(-39,-28), Vector2(39,-28), Vector2(45,-25), Vector2(51,-28), Vector2(-46,28), Vector2(46,28), Vector2(-34,34), Vector2(34,34), Vector2(-20,-48), Vector2(20,-48)], 2, Vector3(1.35,1.65,1.20), 6)

func _build_landmark_shoulders() -> void:
	# Independent edible calved blocks make three asymmetric glacier masses.
	# Site selection checks existing stationary collision footprints; the open
	# centre routes and original progression bodies remain unobstructed.
	var landmarks:Array[Node3D]=[]
	for body in foods:
		if body.get_meta("landmark",false):landmarks.append(body)
	var added:=0
	for cluster in [0,3,6]:
		if cluster>=landmarks.size():continue
		var anchor:Node3D=landmarks[cluster]
		var center:=Vector2(anchor.position.x,anchor.position.z)
		for attempt in 16:
			if added>23:break
			var angle:=float(attempt)*.73+float(cluster)*.42
			var distance:float=anchor.footprint+4.5+float(attempt%3)*3.0
			var at:=center+Vector2.from_angle(angle)*distance
			if maxf(absf(at.x),absf(at.y))>94.0:continue
			# Preserve the proven broad movement corridors.
			if absf(at.x)<7.0 or absf(absf(at.x)-44.0)<7.0:continue
			if absf(at.y-18.0)<6.0 or absf(at.y+36.0)<6.0:continue
			var radius:=3.7
			var clear:=true
			for other in foods:
				if other.get_meta("court_actor",false):continue
				if at.distance_to(Vector2(other.position.x,other.position.z))<radius+other.footprint+.20:
					clear=false;break
			if not clear:continue
			var spec:Dictionary={"kind":"toy_block","at":at,"size":Vector3(5.8,2.5+float(attempt%3)*.7,4.2),"tier":5,"points":12,"palette":2,
				"neighborhood":"calving_basin","yaw":0.0,"tower_id":"","tower_level":0,"bottom":.04,"landmark":false}
			var body:Node3D=_make_toy(spec)
			body.name="CalvedShoulder_%02d"%added
			body.set_meta("frost_species","ice_rock");body.category="iceberg"
			_build_species_visual(body,"ice_rock")
			food_queries.register(body);added+=1
	toy_layout["calved_shoulders"]=added

func population_summary() -> Dictionary:
	var result: Dictionary = super.population_summary()
	result["map_id"] = "frost"
	result["name"] = "Frostlight Village"
	result["snow_decorations"] = frost_decorations
	result["ice_spires"] = ice_spires
	result["frozen_ponds"] = frozen_ponds
	result["snow_material_roughness"] = snow_material.roughness if snow_material != null else 1.0
	result["ice_material_roughness"] = ice_material.roughness if ice_material != null else 1.0
	result["frost_species"] = frost_species_counts.duplicate()
	result["frost_system_count"] = frost_species_counts.size()
	result["whole_castles"] = 0
	result["castle_visuals_removed"] = castle_visuals_removed
	result["arctic_ice_structures"] = arctic_ice_structures
	result["arctic_dominant"] = castle_visuals_removed >= 50 and inherited_batches_detached
	result["blender_assets"] = blender_asset_usage.duplicate()
	result["polar_visuals_converted"] = polar_visuals_converted
	result["ice_family_count"] = Ice.ASSETS.size()
	return result
