extends "res://tests/town_material_notice_scene_acceptance.gd"
## Actual scene: Ari reads; Wren is beyond sign range, hears Ari, then walks and recovers.
const Sharing = preload("res://core/actions/material_knowledge_capability.gd")
const LISTENER := "shared:baker"
var disclosure: Dictionary = {}
var listener_proof: Dictionary = {}

func _collector() -> String:
	return LISTENER

func _start_collection(world) -> Dictionary:
	check(world.position_of(LISTENER).distance_to(world.material_notice_position()) > world.MATERIAL_NOTICE_RANGE, "listener naturally stands beyond sign-reading range")
	check(world._known_materials(LISTENER).is_empty(), "listener has no source knowledge before explicit speech")
	var option: String = Sharing.new().option_id(SOURCE, LISTENER)
	disclosure = world.perform_action(path, READER, option, "fixture:physical-material-disclosure", "opengameagent_fixture")
	check(disclosure.ok and disclosure.get("speech_delivery", {}).get("delivered", false), "existing nearby bodies explicitly communicate the route")
	if not disclosure.ok: return disclosure
	listener_proof = world.resident_view(LISTENER).material_sources[0]
	check(listener_proof.knowledge_source == "reported_location_current_stock_unverified" and listener_proof.reported_by_id == READER and listener_proof.last_observed_stock == null, "listener retains speaker attribution and stock uncertainty")
	check(world._known_materials(DISTANT).is_empty() and world._trade_account(LISTENER).iron == 0, "speech neither broadcasts nor grants iron")
	return super._start_collection(world)

func _extra_evidence() -> Dictionary:
	return {"suite": "town_material_sharing_scene", "reader": READER, "collector": LISTENER,
		"disclosure": disclosure, "listener_proof": listener_proof}
