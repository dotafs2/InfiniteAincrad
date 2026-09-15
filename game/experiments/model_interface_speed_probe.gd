extends "res://experiments/model_interface_probe.gd"
## Separate offline sensitivity check. The frozen paid trial host is unchanged.

func _initialize() -> void:
	super._initialize()
	Engine.time_scale = 1.0
