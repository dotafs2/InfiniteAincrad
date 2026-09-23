extends RefCounted
## Registration-only manifest for the isolated adventure reducer.
## It deliberately does not enter TownActions until the host effect review passes.
const Registry = preload("res://core/actions/capability_registry.gd")
const OWNER := "adventure_contract.v1"

func definitions() -> Array:
	return [
		Registry.spec("adventure.enter_wilderness", OWNER, "immediate",
			["actor_body", "physical_arrival", "no_committed_job"], "forbidden",
			["resident_is_in_town", "resident_is_not_defeated", "physical_arrival", "no_committed_job"],
			["set_zone_wilderness", "durable_entry_receipt"]),
		Registry.spec("adventure.enter_labyrinth", OWNER, "immediate",
			["actor_body", "physical_arrival", "no_committed_job", "floor_one_gate"], "forbidden",
			["resident_is_in_wilderness", "floor_one_gate_open", "physical_arrival", "no_committed_job"],
			["set_zone_labyrinth", "durable_entry_receipt"]),
		Registry.spec("adventure.enter_boss_arena", OWNER, "immediate",
			["actor_body", "physical_arrival", "no_committed_job", "labyrinth_clearance"], "forbidden",
			["resident_is_in_labyrinth", "labyrinth_clearance_receipt", "physical_arrival", "no_committed_job"],
			["set_zone_floor_one_boss_arena", "durable_entry_receipt"]),
		Registry.spec("adventure.attack_encounter", OWNER, "immediate",
			["actor_body", "equipped_weapon", "visible_hostile_encounter"], "forbidden",
			["same_danger_zone", "target_is_visible", "authoritative_attack_and_defense"],
			["one_authoritative_damage_receipt", "finite_hp_delta"]),
		Registry.spec("adventure.guard", OWNER, "immediate",
			["actor_body", "danger_zone"], "forbidden",
			["resident_is_in_danger_zone"], ["guard_until_next_world_round"]),
		Registry.spec("adventure.flee", OWNER, "immediate",
			["actor_body", "danger_zone", "reachable_route"], "forbidden",
			["resident_is_in_danger_zone", "flee_route_is_physically_reachable"],
			["flee_receipt", "physical_return_to_last_safe_zone"]),
		Registry.spec("adventure.recover", OWNER, "immediate",
			["actor_body", "town_safe_zone"], "forbidden",
			["resident_is_in_town", "resident_is_defeated"], ["clear_defeated_status", "restore_minimum_hp"]),
		Registry.spec("adventure.challenge_boss", OWNER, "immediate",
			["actor_body", "physical_arrival", "labyrinth_clearance", "party_consent"], "forbidden",
			["resident_is_in_boss_arena", "labyrinth_clearance_receipt", "explicit_consent_for_party"],
			["create_boss_encounter", "no_floor_unlock"]),
		Registry.spec("adventure.unlock_floor", OWNER, "immediate",
			["boss_victory_receipt", "party_presence"], "forbidden",
			["authoritative_floor_one_boss_victory_receipt", "all_required_party_members_present"],
			["append_floor_unlock_receipt", "set_next_floor_two"]),
		Registry.spec("adventure.retreat_after_defeat", OWNER, "immediate",
			["actor_body", "danger_zone", "reachable_route"], "forbidden",
			["resident_is_defeated_in_danger_zone", "retreat_route_is_physically_reachable"],
			["retreat_receipt", "physical_return_to_last_safe_zone"])
	]
