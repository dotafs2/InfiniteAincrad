extends "res://fidelity/toy_preview.gd"
## Visual-only Frostlight miniature. The gameplay scene owns the real bodies;
## this card adds a compact icy dressing without creating collision objects.
var frost_material: StandardMaterial3D
var ice_material: StandardMaterial3D

func build_preview() -> void:
	if is_instance_valid(preview):preview.free()
	preview=Node3D.new();preview.name="FrostlightVillageMiniature";add_child(preview)
	toy_piece_count=0;court_piece_count=0;layer_counts={"foreground":0,"midground":0,"background":0}
	var base:=surface(Vector3(14,.30,12),Vector3(0,-.30,0),0);paint_ground(base,Color("7195b0"))
	var snow:=surface(Vector3(13.8,.08,11.8),Vector3.ZERO,3);paint_ground(snow,Color("c0d2e7"))
	var channel:=surface(Vector3(13.5,.02,1.9),Vector3(0,.06,1.3),4,-.20);paint_ground(channel,Color("549dca"))
	frost_material=StandardMaterial3D.new();frost_material.albedo_color=Color("f5fbff");frost_material.roughness=.35
	ice_material=StandardMaterial3D.new();ice_material.albedo_color=Color("197cad");ice_material.roughness=.18
	const Ice=preload("res://fidelity/frost_ice.gd")
	var placements=[
		[0,Vector3(-3.5,.09,-2.1),Vector3(4.5,3.5,3.3)],
		[1,Vector3(.3,.09,-3.5),Vector3(3.5,4.0,2.7)],
		[2,Vector3(4.0,.09,-1.7),Vector3(3.3,2.2,3.0)],
		[3,Vector3(-4.8,.09,1.0),Vector3(1.7,1.65,1.6)],
		[5,Vector3(3.5,.09,3.4),Vector3(2.0,.45,1.5)],
		[4,Vector3(-1.6,.09,3.7),Vector3(.95,.8,.9)]]
	for row in placements:
		var asset:=Ice.make(row[0],row[2]);asset.position+=row[1];preview.add_child(asset)
		asset.name="MiniAuthoredIce_%02d"%toy_piece_count;toy_piece_count+=1
	for index in 4:
		var floe:=Ice.make(5,Vector3(.64,.18,.56));floe.position+=Vector3(-4.1+index*.71,.09,3.3+sin(index)*.36);preview.add_child(floe)
	_build_research_and_penguins()

func _mini_part(parent: Node3D, mesh: Mesh, material: Material, at: Vector3, scale: Vector3) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = material
	visual.position = at
	visual.scale = scale
	parent.add_child(visual)
	return visual

func _build_research_and_penguins() -> void:
	var dome := Node3D.new(); dome.name = "MiniResearchDome"; dome.position = Vector3(-3.45, .12, 1.95); preview.add_child(dome)
		# Dome and antenna use glossy ice colors to read as a research outpost.
	var dome_mesh := SphereMesh.new(); dome_mesh.radius = .5; dome_mesh.height = 1.0; dome_mesh.radial_segments = 14; dome_mesh.rings = 8
	_mini_part(dome, dome_mesh, frost_material, Vector3.ZERO, Vector3(1.18, .68, 1.02))
	var mast := CylinderMesh.new(); mast.top_radius = .035; mast.bottom_radius = .06; mast.height = 1.0; mast.radial_segments = 8
	_mini_part(dome, mast, ice_material, Vector3(0, .84, 0), Vector3(.10, 1.1, .10))
	for index in 7:
		var penguin := Node3D.new(); penguin.name = "MiniPenguin_%02d" % index
		penguin.position = Vector3(-1.75 + float(index % 4) * .68, .15, 2.88 + floori(index / 4.0) * .62)
		preview.add_child(penguin)
		var body := SphereMesh.new(); body.radius = .5; body.height = 1.0; body.radial_segments = 10; body.rings = 6
		_mini_part(penguin, body, ice_material, Vector3(0, .30, 0), Vector3(.26, .54, .22))
		var belly := SphereMesh.new(); belly.radius = .5; belly.height = 1.0; belly.radial_segments = 10; belly.rings = 6
		_mini_part(penguin, belly, frost_material, Vector3(0, .28, .13), Vector3(.14, .30, .05))
		var beak := BoxMesh.new(); beak.size = Vector3.ONE
		_mini_part(penguin, beak, frost_material, Vector3(0, .43, .18), Vector3(.10, .05, .12))
