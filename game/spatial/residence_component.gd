@tool
extends Node3D
## Art-only closed residential shell. Does not allocate housing or change saves.

@export_range(1, 5) var variant: int = 1
@export var collision_enabled := true
@export_range(-1, 2) var force_lod: int = -1
const ROOT := "res://assets/floor1/residences/"
static var _shared_materials: Dictionary = {}

func _ready() -> void:
	if get_node_or_null("ResidenceGeometry") != null: return
	var packed := load(ROOT + "F1_Residence_%02d.glb" % variant) as PackedScene
	if packed == null:
		push_error("Residence asset missing: %d" % variant)
		return
	var instance := packed.instantiate() as Node3D
	instance.name = "ResidenceGeometry"
	add_child(instance)
	var meshes := instance.find_children("*", "MeshInstance3D", true, false)
	var bounds := AABB()
	var first := true
	for item: MeshInstance3D in meshes:
		bounds = item.mesh.get_aabb() if first else bounds.merge(item.mesh.get_aabb())
		first = false
	for item: MeshInstance3D in meshes:
		var level := 0
		if "LOD1" in str(item.name): level = 1
		if "LOD2" in str(item.name): level = 2
		item.custom_aabb = bounds
		item.set_meta("lod", level)
		if force_lod >= 0:
			item.visible = level == force_lod
		else:
			item.visibility_range_begin = [0.0, 32.0, 70.0][level]
			item.visibility_range_end = [32.0, 70.0, 0.0][level]
			item.visibility_range_begin_margin = 0.0
			item.visibility_range_end_margin = 0.0
		for surface in range(item.mesh.get_surface_count()):
			var source := item.mesh.surface_get_material(surface) as StandardMaterial3D
			if source == null: continue
			var key := source.resource_name
			if not _shared_materials.has(key):
				var material := source.duplicate() as StandardMaterial3D
				material.vertex_color_use_as_albedo = true
				material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
				var kind := key.trim_prefix("Residence_")
				if kind in ["limestone", "plaster", "oak", "clay"]:
					# Shared runtime overrides. Raw self-contained imports still carry
					# their embedded texture references until a later streaming pass.
					material.albedo_texture = load(ROOT + "textures/" + kind + "_albedo.png")
					material.normal_enabled = true
					material.normal_texture = load(ROOT + "textures/" + kind + "_normal.png")
					material.normal_scale = 0.7
					material.roughness_texture = load(ROOT + "textures/" + kind + "_orm.png")
					material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
					material.roughness = 1.0
					material.metallic = 0.0
				_shared_materials[key] = material
			item.set_surface_override_material(surface, _shared_materials[key])
	set_meta("variant", variant)
	set_meta("bounds", bounds)
	if collision_enabled: _collision()

func _collision() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "manifest.json"))
	var entry: Dictionary = manifest.assets[variant - 1]
	var boxes: Array = entry.collision_boxes_blender_xyz.duplicate(true)
	if variant == 3:
		for x in [2.9,4.9,6.9]: boxes.append([x,-2.7,1.53,.24,.26,2.4])
	if variant == 4:
		for x in [-3.1,0.0,3.1]: boxes.append([x,-4.32,1.76,.19,.19,2.92])
	var body := StaticBody3D.new()
	body.name = "ClosedExteriorCollision"
	add_child(body)
	for box in boxes:
		var shape := CollisionShape3D.new()
		var volume := BoxShape3D.new()
		volume.size = Vector3(box[3], box[5], box[4])
		shape.shape = volume
		shape.position = Vector3(box[0], box[2], -box[1])
		body.add_child(shape)
