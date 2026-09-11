@tool
extends Node3D
## Drag a component .tscn into a level to get the authored materials, LODs and proxy.
const KIT := preload("res://spatial/environment_v2.gd")
@export var asset_id: String = "F1_fern_patch"
@export var collision_enabled: bool = true

func _ready() -> void:
	var component := KIT.create(asset_id, collision_enabled)
	component.name = "RuntimeComponent"
	add_child(component)
