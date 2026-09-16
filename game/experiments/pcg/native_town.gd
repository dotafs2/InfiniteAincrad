extends "res://experiments/pcg/town.gd"
const NativeQuarter = preload("res://experiments/pcg/native_quarter.gd")

func _load_market_runtime() -> void:
	quarter = NativeQuarter.new()
	quarter.name = "PCGNativeVegetationTrial"
	add_child(quarter)
	quarter.build()
	_market_loaded = quarter.houses.size() == 16
