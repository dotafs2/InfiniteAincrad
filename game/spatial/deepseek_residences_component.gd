@tool
extends Node3D
## Art-only closed exterior wrapper for the DeepSeek F1_Residence_06 asset.
## Automatic LOD0/1/2 by distance plus closed metric collision proxies.
## Does not allocate housing, mutate saves, or read unrelated world state.

@export var collision_enabled := true
@export_range(-1, 2) var force_lod: int = -1

const ROOT := "res://assets/floor1/deepseek_residences/"
const GLB := ROOT + "F1_Residence_06.glb"
const MANIFEST := ROOT + "manifest.json"
const TEXTURES := "res://assets/floor1/residences/textures/"
static var _shared_materials: Dictionary = {}

func _ready() -> void:
	if get_node_or_null("DeepSeekResidenceGeometry") != null:
		return
	var packed := load(GLB) as PackedScene
	if packed == null:
		push_error("DeepSeek residence asset missing: " + GLB)
		return
	var instance := packed.instantiate() as Node3D
	instance.name = "DeepSeekResidenceGeometry"
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
					material.albedo_texture = _image(kind + "_albedo.png")
					material.normal_enabled = true
					material.normal_texture = _image(kind + "_normal.png")
					material.normal_scale = 0.7
					material.roughness_texture = _image(kind + "_orm.png")
					material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
					material.roughness = 1.0
					material.metallic = 0.0
				_shared_materials[key] = material
			item.set_surface_override_material(surface, _shared_materials[key])
	set_meta("asset_id", "F1_Residence_06")
	set_meta("bounds", bounds)
	if collision_enabled: _collision()

func _image(file: String) -> Texture2D:
	var tex := load(TEXTURES + file) as Texture2D
	return tex

func _collision() -> void:
	var text := FileAccess.get_file_as_string(MANIFEST)
	if text.is_empty(): return
	var manifest: Dictionary = JSON.parse_string(text)
	var assets: Array = manifest.get("assets", [])
	if assets.is_empty(): return
	var entry: Dictionary = assets[0]
	var boxes: Array = entry.get("collision_boxes_blender_xyz", []).duplicate(true)
	var body := StaticBody3D.new()
	body.name = "ClosedExteriorCollision"
	add_child(body)
	for box in boxes:
		# Blender xyz (z-up) -> Godot xyz (y-up, -Y forward): position (x, z, -y)
		var shape := CollisionShape3D.new()
		var volume := BoxShape3D.new()
		volume.size = Vector3(box[3], box[5], box[4])
		shape.shape = volume
		shape.position = Vector3(box[0], box[2], -box[1])
		body.add_child(shape)
