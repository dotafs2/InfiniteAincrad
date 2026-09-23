extends RefCounted
## Bounded, deterministic adventure reducer for adventure_contract.v1.
## This is intentionally isolated from the maintained town save until GM review.

const CONTRACT_ID := "adventure_contract.v1"
const DANGER_ZONES := ["wilderness", "labyrinth", "floor_one_boss_arena"]

var _state: Dictionary = {}

func create_fixture() -> Dictionary:
	_state = {
		"schema_version": 1,
		"contract_id": CONTRACT_ID,
		"floor": 1,
		"floor_one_gate_open": false,
		"boss_victory": false,
		"boss_encounter": false,
		"residents": {
			"fixture:adventurer": _resident("fixture:adventurer", 12, 4, 1),
			"fixture:guard": _resident("fixture:guard", 10, 2, 2)
		},
		"encounters": {
			"fixture:wolf": {"id": "fixture:wolf", "zone": "labyrinth", "hp": 6,
				"max_hp": 6, "attack_power": 3, "defense_power": 1, "status": "ready", "visible": true}
		},
		"receipts": [],
		"commands": {},
		"loot_receipts": []
	}
	return snapshot()

func create_from_town_snapshot(town: Dictionary) -> Dictionary:
	# Migration never invents HP, attack, defense, weapons or loot. Those remain
	# explicit authority gaps until a later host-reviewed seed supplies them.
	_state = {
		"schema_version": 1,
		"contract_id": CONTRACT_ID,
		"migration": {
			"source_world_id": str(town.get("world_id", "")),
			"source_schema_version": int(town.get("schema_version", 0)),
			"combat_authority": "undefined_until_host_seed",
			"loot_authority": "world_owned_only"
		},
		"floor": 1,
		"floor_one_gate_open": false,
		"boss_victory": false,
		"boss_encounter": false,
		"residents": {},
		"encounters": {},
		"receipts": [],
		"commands": {},
		"loot_receipts": []
	}
	for raw in town.get("residents", []):
		if not raw is Dictionary: continue
		var id := str(raw.get("stable_id", ""))
		if id.is_empty() or _state.residents.has(id): continue
		_state.residents[id] = {
			"id": id, "zone": "town", "last_safe_zone": "town",
			"hp": null, "max_hp": null, "attack_power": null, "defense_power": null,
			"equipped_weapon": null, "status": "ready", "guard": false,
			"visible": true, "inventory": [], "committed_job": false,
			"combat_authority": "undefined"
		}
	return snapshot()

func _resident(id: String, max_hp: int, attack: int, defense: int) -> Dictionary:
	return {"id": id, "zone": "town", "last_safe_zone": "town", "hp": max_hp,
		"max_hp": max_hp, "attack_power": attack, "defense_power": defense,
		"equipped_weapon": id == "fixture:adventurer", "status": "ready", "guard": false,
		"visible": true, "inventory": []}

func snapshot() -> Dictionary:
	return _state.duplicate(true)

func load_from(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "code": "save_missing"}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or parsed.get("contract_id") != CONTRACT_ID:
		return {"ok": false, "code": "contract_mismatch"}
	_state = parsed.duplicate(true)
	return {"ok": true, "code": "loaded"}

func save_to(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "code": "save_open_failed"}
	file.store_string(JSON.stringify(_state, "", true, true))
	file.close()
	return {"ok": true, "code": "saved"}

func open_floor_one_gate(command_id: String) -> Dictionary:
	if _state.floor_one_gate_open:
		return _existing(command_id)
	var receipt := _record(command_id, "host_open_gate", {"ok": true, "code": "gate_opened"})
	_state.floor_one_gate_open = true
	return receipt

func set_committed_job(id: String, active: bool, command_id: String) -> Dictionary:
	var duplicate: Variant = _existing(command_id)
	if duplicate != null: return duplicate
	var resident := _resident_or_error(id)
	if resident.is_empty(): return _reject(command_id, "resident_missing")
	resident.committed_job = active
	return _record(command_id, "host_set_committed_job", {"ok": true, "code": "committed_job_updated",
		"resident_id": id, "active": active})

func enter_wilderness(id: String, command_id: String, physical_arrival: bool = true) -> Dictionary:
	var duplicate: Variant = _existing(command_id)
	if duplicate != null: return duplicate
	var resident := _resident_or_error(id)
	if resident.is_empty(): return _reject(command_id, "resident_missing")
	if resident.zone != "town": return _reject(command_id, "wrong_zone")
	if resident.status == "defeated": return _reject(command_id, "resident_defeated")
	if not physical_arrival: return _reject(command_id, "physical_arrival_required")
	if bool(resident.get("committed_job", false)): return _reject(command_id, "committed_job_must_finish_or_reject")
	resident.zone = "wilderness"
	resident.last_safe_zone = "town"
	return _record(command_id, "enter_wilderness", {"ok": true, "code": "entered_wilderness", "resident_id": id})

func enter_labyrinth(id: String, command_id: String, physical_arrival: bool = true) -> Dictionary:
	var duplicate: Variant = _existing(command_id)
	if duplicate != null: return duplicate
	var resident := _resident_or_error(id)
	if resident.is_empty(): return _reject(command_id, "resident_missing")
	if resident.zone != "wilderness": return _reject(command_id, "wrong_zone")
	if not _state.floor_one_gate_open: return _reject(command_id, "floor_one_gate_closed")
	if not physical_arrival: return _reject(command_id, "physical_arrival_required")
	if bool(resident.get("committed_job", false)): return _reject(command_id, "committed_job_must_finish_or_reject")
	resident.zone = "labyrinth"
	resident.last_safe_zone = "town"
	return _record(command_id, "enter_labyrinth", {"ok": true, "code": "entered_labyrinth", "resident_id": id})

func enter_floor_one_boss_arena(id: String, command_id: String, labyrinth_clearance: bool = true,
		physical_arrival: bool = true) -> Dictionary:
	var duplicate: Variant = _existing(command_id)
	if duplicate != null: return duplicate
	var resident := _resident_or_error(id)
	if resident.is_empty(): return _reject(command_id, "resident_missing")
	if resident.zone != "labyrinth": return _reject(command_id, "labyrinth_required")
	if not labyrinth_clearance: return _reject(command_id, "labyrinth_clearance_required")
	if not physical_arrival: return _reject(command_id, "physical_arrival_required")
	if bool(resident.get("committed_job", false)): return _reject(command_id, "committed_job_must_finish_or_reject")
	resident.zone = "floor_one_boss_arena"
	return _record(command_id, "enter_boss_arena", {"ok": true, "code": "entered_boss_arena", "resident_id": id})

func attack(attacker_id: String, target_id: String, command_id: String) -> Dictionary:
	var duplicate: Variant = _existing(command_id)
	if duplicate != null: return duplicate
	var attacker := _resident_or_error(attacker_id)
	if _state.get("residents", {}).has(target_id): return _reject(command_id, "hostile_encounter_required")
	var target := _encounter_or_error(target_id)
	if attacker.is_empty() or target.is_empty(): return _reject(command_id, "encounter_missing")
	if attacker.zone not in DANGER_ZONES or target.zone != attacker.zone: return _reject(command_id, "same_danger_zone_required")
	if not bool(target.visible): return _reject(command_id, "target_not_visible")
	if attacker.attack_power == null or target.defense_power == null or attacker.equipped_weapon == null:
		return _reject(command_id, "combat_values_undefined")
	if not bool(attacker.equipped_weapon): return _reject(command_id, "equipped_weapon_required")
	if not _state.get("encounters", {}).has(target_id): return _reject(command_id, "hostile_encounter_required")
	if attacker.status == "defeated" or target.status == "defeated": return _reject(command_id, "defeated_target")
	var damage := maxi(1, int(attacker.attack_power) - int(target.defense_power))
	target.hp = maxi(0, int(target.hp) - damage)
	target.guard = false
	var defeated: bool = target.hp == 0
	if defeated:
		target.status = "defeated"
	var result := {"ok": true, "code": "combat_hit", "attacker_id": attacker_id, "target_id": target_id,
		"damage": damage, "target_hp": target.hp, "defeated": defeated}
	return _record(command_id, "attack", result)

func encounter_attack(encounter_id: String, target_id: String, command_id: String) -> Dictionary:
	var duplicate: Variant = _existing(command_id)
	if duplicate != null: return duplicate
	var encounter := _encounter_or_error(encounter_id)
	var target := _resident_or_error(target_id)
	if encounter.is_empty() or target.is_empty(): return _reject(command_id, "target_missing")
	if encounter.zone != target.zone or encounter.status == "defeated" or target.status == "defeated":
		return _reject(command_id, "encounter_target_not_attackable")
	var damage := maxi(1, int(encounter.attack_power) - int(target.defense_power))
	target.hp = maxi(0, int(target.hp) - damage)
	var defeated: bool = target.hp == 0
	if defeated: target.status = "defeated"
	return _record(command_id, "encounter_attack", {"ok": true, "code": "encounter_hit",
		"attacker_id": encounter_id, "target_id": target_id, "damage": damage,
		"target_hp": target.hp, "defeated": defeated})

func guard(id: String, command_id: String) -> Dictionary:
	var duplicate: Variant = _existing(command_id)
	if duplicate != null: return duplicate
	var resident := _resident_or_error(id)
	if resident.is_empty(): return _reject(command_id, "resident_missing")
	if resident.zone not in DANGER_ZONES: return _reject(command_id, "danger_zone_required")
	resident.guard = true
	return _record(command_id, "guard", {"ok": true, "code": "guard_set", "resident_id": id})

func flee(id: String, command_id: String, physically_reachable: bool = true) -> Dictionary:
	var duplicate: Variant = _existing(command_id)
	if duplicate != null: return duplicate
	var resident := _resident_or_error(id)
	if resident.is_empty(): return _reject(command_id, "resident_missing")
	if resident.zone not in DANGER_ZONES: return _reject(command_id, "danger_zone_required")
	if not physically_reachable: return _reject(command_id, "flee_route_unreachable")
	resident.zone = resident.last_safe_zone
	resident.guard = false
	return _record(command_id, "flee", {"ok": true, "code": "fled_to_safe_zone", "resident_id": id})

func retreat_after_defeat(id: String, command_id: String, physically_reachable: bool = true) -> Dictionary:
	var duplicate: Variant = _existing(command_id)
	if duplicate != null: return duplicate
	var resident := _resident_or_error(id)
	if resident.is_empty(): return _reject(command_id, "resident_missing")
	if resident.status != "defeated" or resident.zone not in DANGER_ZONES:
		return _reject(command_id, "defeat_retreat_required")
	if not physically_reachable: return _reject(command_id, "retreat_route_unreachable")
	resident.zone = resident.last_safe_zone
	return _record(command_id, "retreat_after_defeat", {"ok": true, "code": "defeated_resident_retreated", "resident_id": id})

func recover(id: String, command_id: String) -> Dictionary:
	var duplicate: Variant = _existing(command_id)
	if duplicate != null: return duplicate
	var resident := _resident_or_error(id)
	if resident.is_empty(): return _reject(command_id, "resident_missing")
	if resident.zone != "town" or resident.status != "defeated": return _reject(command_id, "recovery_requires_defeat_in_town")
	resident.hp = 1
	resident.status = "ready"
	return _record(command_id, "recover", {"ok": true, "code": "recovered", "resident_id": id, "hp": 1})

func challenge_floor_one_boss(id: String, command_id: String, consent: bool = true) -> Dictionary:
	var duplicate: Variant = _existing(command_id)
	if duplicate != null: return duplicate
	var resident := _resident_or_error(id)
	if resident.is_empty(): return _reject(command_id, "resident_missing")
	if resident.zone != "floor_one_boss_arena": return _reject(command_id, "boss_arena_required")
	if not _state.floor_one_gate_open: return _reject(command_id, "floor_one_gate_closed")
	if not consent: return _reject(command_id, "party_consent_required")
	_state.boss_encounter = true
	return _record(command_id, "challenge_boss", {"ok": true, "code": "boss_encounter_started", "resident_id": id})

func resolve_boss(command_id: String, victory: bool) -> Dictionary:
	var duplicate: Variant = _existing(command_id)
	if duplicate != null: return duplicate
	if not _state.boss_encounter: return _reject(command_id, "boss_encounter_missing")
	_state.boss_encounter = false
	_state.boss_victory = victory
	if victory:
		_state.loot_receipts.append({"receipt_id": command_id, "kind": "finite_boss_loot", "quantity": 1})
	return _record(command_id, "resolve_boss", {"ok": true, "code": "boss_victory" if victory else "boss_defeat", "victory": victory})

func unlock_floor_two(command_id: String, present_ids: Array[String]) -> Dictionary:
	var duplicate: Variant = _existing(command_id)
	if duplicate != null: return duplicate
	if not _state.boss_victory: return _reject(command_id, "boss_victory_required")
	if present_ids.is_empty(): return _reject(command_id, "party_required")
	_state.floor = 2
	return _record(command_id, "unlock_floor_two", {"ok": true, "code": "floor_unlocked", "floor": 2, "party": present_ids.duplicate()})

func _resident_or_error(id: String) -> Dictionary:
	return _state.get("residents", {}).get(id, {})

func _encounter_or_error(id: String) -> Dictionary:
	return _state.get("encounters", {}).get(id, {})

func _existing(command_id: String):
	if _state.get("commands", {}).has(command_id):
		var old: Dictionary = _state.commands[command_id].duplicate(true)
		old["duplicate"] = true
		return old
	return null

func _reject(command_id: String, code: String) -> Dictionary:
	var result := {"ok": false, "code": code, "command_id": command_id}
	_state.commands[command_id] = result.duplicate(true)
	return result

func _record(command_id: String, kind: String, result: Dictionary) -> Dictionary:
	var receipt := result.duplicate(true)
	receipt["command_id"] = command_id
	receipt["kind"] = kind
	receipt["receipt_id"] = "adventure:%d" % (_state.receipts.size() + 1)
	_state.commands[command_id] = receipt.duplicate(true)
	_state.receipts.append(receipt.duplicate(true))
	return receipt
