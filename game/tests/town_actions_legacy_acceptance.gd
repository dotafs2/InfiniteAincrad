extends "res://tests/town_trade_acceptance.gd"
const ActionWorld = preload("res://core/town_actions.gd")

func _load_trade(path: String) -> TownTrade:
	var world := ActionWorld.new()
	check(world.load_from(path).ok, "existing trade suite uses the common action boundary")
	return world
