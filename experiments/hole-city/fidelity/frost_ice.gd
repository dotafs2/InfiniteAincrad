extends RefCounted
## Original Blender families with one shared opaque mobile-friendly ice shader.
const ASSETS = [preload("res://assets/frost/glacier.glb"),preload("res://assets/frost/glacier_ridge.glb"),preload("res://assets/frost/glacier_shelf.glb"),preload("res://assets/frost/glacier_serac.glb"),preload("res://assets/frost/ice_rock.glb"),preload("res://assets/frost/ice_floe.glb")]
const NAMES = ["calving_cliff","windcut_ridge","terraced_shelf","split_serac","ice_boulder","pancake_floe"]
static var ice_shader: ShaderMaterial
static var measured_bounds: Dictionary = {}
static func material() -> ShaderMaterial:
	if ice_shader == null:
		ice_shader=ShaderMaterial.new();ice_shader.shader=preload("res://fidelity/frost_ice.gdshader")
	return ice_shader
static func make(index:int, target:Vector3) -> Node3D:
	index=posmod(index,ASSETS.size())
	var asset:Node3D=ASSETS[index].instantiate()
	var bounds:=AABB()
	var first:=true
	for child in asset.find_children("*","MeshInstance3D",true,false):
		child.material_override=material()
		if not measured_bounds.has(index):
			var at:Transform3D=asset.global_transform.affine_inverse()*child.global_transform if asset.is_inside_tree() else child.transform
			var box:AABB=at*child.mesh.get_aabb()
			bounds=box if first else bounds.merge(box);first=false
	if not measured_bounds.has(index):measured_bounds[index]=bounds
	bounds=measured_bounds[index]
	asset.scale=target/bounds.size
	asset.position=Vector3(-(bounds.position.x+bounds.size.x*.5)*asset.scale.x,-bounds.position.y*asset.scale.y,-(bounds.position.z+bounds.size.z*.5)*asset.scale.z)
	asset.set_meta("frost_variant",NAMES[index]);asset.set_meta("authored_bounds",bounds)
	return asset
