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

static func validate_snapshot(value: Variant) -> Dictionary:
	if not value is Dictionary or value.get("schema_version") != 1 \
			or value.get("contract_id") != CONTRACT_ID:
		return {"ok": false, "code": "contract_mismatch"}
	for key in ["floor", "floor_one_gate_open", "boss_victory", "boss_encounter",
			"residents", "encounters", "receipts", "commands", "loot_receipts"]:
		if not value.has(key): return {"ok": false, "code": "snapshot_field_missing", "field": key}
	if typeof(value.floor) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value.floor)) \
			or float(value.floor) != floor(float(value.floor)) or value.floor < 1 or value.floor > 100 \
			or typeof(value.floor_one_gate_open) != TYPE_BOOL \
			or typeof(value.boss_victory) != TYPE_BOOL or typeof(value.boss_encounter) != TYPE_BOOL \
			or not value.residents is Dictionary or not value.encounters is Dictionary \
			or not value.receipts is Array or not value.commands is Dictionary \
			or not value.loot_receipts is Array:
		return {"ok": false, "code": "snapshot_shape_invalid"}
	for resident_id in value.residents:
		var resident: Variant = value.residents[resident_id]
		if not resident_id is String or resident_id.is_empty() or not resident is Dictionary \
				or resident.get("id") != resident_id \
				or resident.get("zone") not in ["town", "wilderness", "labyrinth", "floor_one_boss_arena"] \
				or resident.get("last_safe_zone") not in ["town", "wilderness", "labyrinth", "floor_one_boss_arena"] \
				or resident.get("status") not in ["ready", "defeated"]:
			return {"ok": false, "code": "snapshot_resident_invalid", "resident_id": str(resident_id)}
	for command_id in value.commands:
		var row: Variant = value.commands[command_id]
		if not command_id is String or not row is Dictionary \
				or not row.get("request") is Dictionary or not row.get("result") is Dictionary:
			return {"ok": false, "code": "snapshot_command_invalid", "command_id": str(command_id)}
	return {"ok": true}

func load_snapshot(value: Variant) -> Dictionary:
	var checked := validate_snapshot(value)
	if not checked.get("ok", false): return checked
	var snapshot_value: Dictionary = value
	_state = snapshot_value.duplicate(true)
	return {"ok": true, "code": "snapshot_loaded"}

func load_from(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "code": "save_missing"}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return load_snapshot(parsed)

func save_to(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "code": "save_open_failed"}
	file.store_string(JSON.stringify(_state, "", true, true))
	file.close()
	return {"ok": true, "code": "saved"}

func open_floor_one_gate(command_id: String) -> Dictionary:
	var prior: Variant = _existing(command_id, "host_open_gate", {})
	if prior != null: return prior
	if _state.floor_one_gate_open:
		return _record(command_id, "host_open_gate", {}, {"ok": true, "code": "gate_already_open"})
	_state.floor_one_gate_open = true
	return _record(command_id, "host_open_gate", {}, {"ok": true, "code": "gate_opened"})

func set_committed_job(id: String, active: bool, command_id: String) -> Dictionary:
	var duplicate: Variant = _existing(command_id, "host_set_committed_job", {"resident_id": id, "active": active})
	if duplicate != null: return duplicate
	var resident := _resident_or_error(id)
	if resident.is_empty(): return _reject(command_id, "host_set_committed_job", {"resident_id": id, "active": active}, "resident_missing")
	resident.committed_job = active
	return _record(command_id, "host_set_committed_job", {"resident_id": id, "active": active}, {"ok": true, "code": "committed_job_updated",
		"resident_id": id, "active": active})

func enter_wilderness(id: String, command_id: String, physical_arrival: bool = true) -> Dictionary:
	var request := {"resident_id": id, "physical_arrival": physical_arrival}
	var duplicate: Variant = _existing(command_id, "enter_wilderness", request)
	if duplicate != null: return duplicate
	var resident := _resident_or_error(id)
	if resident.is_empty(): return _reject(command_id, "enter_wilderness", request, "resident_missing")
	if resident.zone != "town": return _reject(command_id, "enter_wilderness", request, "wrong_zone")
	if resident.status == "defeated": return _reject(command_id, "enter_wilderness", request, "resident_defeated")
	if not physical_arrival: return _reject(command_id, "enter_wilderness", request, "physical_arrival_required")
	if bool(resident.get("committed_job", false)): return _reject(command_id, "enter_wilderness", request, "committed_job_must_finish_or_reject")
	resident.zone = "wilderness"
	resident.last_safe_zone = "town"
	return _record(command_id, "enter_wilderness", request, {"ok": true, "code": "entered_wilderness", "resident_id": id})

func enter_labyrinth(id: String, command_id: String, physical_arrival: bool = true) -> Dictionary:
	var request := {"resident_id": id, "physical_arrival": physical_arrival}
	var duplicate: Variant = _existing(command_id, "enter_labyrinth", request)
	if duplicate != null: return duplicate
	var resident := _resident_or_error(id)
	if resident.is_empty(): return _reject(command_id, "enter_labyrinth", request, "resident_missing")
	if resident.zone != "wilderness": return _reject(command_id, "enter_labyrinth", request, "wrong_zone")
	if not _state.floor_one_gate_open: return _reject(command_id, "enter_labyrinth", request, "floor_one_gate_closed")
	if not physical_arrival: return _reject(command_id, "enter_labyrinth", request, "physical_arrival_required")
	if bool(resident.get("committed_job", false)): return _reject(command_id, "enter_labyrinth", request, "committed_job_must_finish_or_reject")
	resident.zone = "labyrinth"
	resident.last_safe_zone = "town"
	return _record(command_id, "enter_labyrinth", request, {"ok": true, "code": "entered_labyrinth", "resident_id": id})

func enter_floor_one_boss_arena(id: String, command_id: String, labyrinth_clearance: bool = true,
		physical_arrival: bool = true) -> Dictionary:
	var request := {"resident_id": id, "labyrinth_clearance": labyrinth_clearance, "physical_arrival": physical_arrival}
	var duplicate: Variant = _existing(command_id, "enter_boss_arena", request)
	if duplicate != null: return duplicate
	var resident := _resident_or_error(id)
	if resident.is_empty(): return _reject(command_id, "enter_boss_arena", request, "resident_missing")
	if resident.zone != "labyrinth": return _reject(command_id, "enter_boss_arena", request, "labyrinth_required")
	if not labyrinth_clearance: return _reject(command_id, "enter_boss_arena", request, "labyrinth_clearance_required")
	if not physical_arrival: return _reject(command_id, "enter_boss_arena", request, "physical_arrival_required")
	if bool(resident.get("committed_job", false)): return _reject(command_id, "enter_boss_arena", request, "committed_job_must_finish_or_reject")
	resident.zone = "floor_one_boss_arena"
	return _record(command_id, "enter_boss_arena", request, {"ok": true, "code": "entered_boss_arena", "resident_id": id})

func attack(attacker_id: String, target_id: String, command_id: String) -> Dictionary:
	var request := {"attacker_id": attacker_id, "target_id": target_id}
	var duplicate: Variant = _existing(command_id, "attack", request)
	if duplicate != null: return duplicate
	var attacker := _resident_or_error(attacker_id)
	if _state.get("residents", {}).has(target_id): return _reject(command_id, "attack", request, "hostile_encounter_required")
	var target := _encounter_or_error(target_id)
	if attacker.is_empty() or target.is_empty(): return _reject(command_id, "attack", request, "encounter_missing")
	if attacker.zone not in DANGER_ZONES or target.zone != attacker.zone: return _reject(command_id, "attack", request, "same_danger_zone_required")
	if not bool(target.visible): return _reject(command_id, "attack", request, "target_not_visible")
	if attacker.attack_power == null or target.defense_power == null or attacker.equipped_weapon == null:
		return _reject(command_id, "attack", request, "combat_values_undefined")
	if not bool(attacker.equipped_weapon): return _reject(command_id, "attack", request, "equipped_weapon_required")
	if not _state.get("encounters", {}).has(target_id): return _reject(command_id, "attack", request, "hostile_encounter_required")
	if attacker.status == "defeated" or target.status == "defeated": return _reject(command_id, "attack", request, "defeated_target")
	var damage := maxi(1, int(attacker.attack_power) - int(target.defense_power))
	target.hp = maxi(0, int(target.hp) - damage)
	target.guard = false
	var defeated: bool = target.hp == 0
	if defeated:
		target.status = "defeated"
	var result := {"ok": true, "code": "combat_hit", "attacker_id": attacker_id, "target_id": target_id,
		"damage": damage, "target_hp": target.hp, "defeated": defeated}
	return _record(command_id, "attack", request, result)

func encounter_attack(encounter_id: String, target_id: String, command_id: String) -> Dictionary:
	var request := {"encounter_id": encounter_id, "target_id": target_id}
	var duplicate: Variant = _existing(command_id, "encounter_attack", request)
	if duplicate != null: return duplicate
	var encounter := _encounter_or_error(encounter_id)
	var target := _resident_or_error(target_id)
	if encounter.is_empty() or target.is_empty(): return _reject(command_id, "encounter_attack", request, "target_missing")
	if encounter.zone not in DANGER_ZONES or encounter.zone != target.zone:
		return _reject(command_id, "encounter_attack", request, "same_danger_zone_required")
	if not bool(encounter.get("visible", false)):
		return _reject(command_id, "encounter_attack", request, "target_not_visible")
	if encounter.get("status") == "defeated" or target.get("status") == "defeated":
		return _reject(command_id, "encounter_attack", request, "encounter_target_not_attackable")
	if not _is_combat_number(encounter.get("attack_power")) or not _is_combat_number(target.get("defense_power")) or not _is_combat_number(target.get("hp")):
		return _reject(command_id, "encounter_attack", request, "combat_values_undefined")
	var damage := maxi(1, int(encounter.attack_power) - int(target.defense_power))
	target.hp = maxi(0, int(target.hp) - damage)
	var defeated: bool = target.hp == 0
	if defeated: target.status = "defeated"
	return _record(command_id, "encounter_attack", request, {"ok": true, "code": "encounter_hit",
		"attacker_id": encounter_id, "target_id": target_id, "damage": damage,
		"target_hp": target.hp, "defeated": defeated})

func guard(id: String, command_id: String) -> Dictionary:
	var request := {"resident_id": id}
	var duplicate: Variant = _existing(command_id, "guard", request)
	if duplicate != null: return duplicate
	var resident := _resident_or_error(id)
	if resident.is_empty(): return _reject(command_id, "guard", request, "resident_missing")
	if resident.zone not in DANGER_ZONES: return _reject(command_id, "guard", request, "danger_zone_required")
	resident.guard = true
	return _record(command_id, "guard", request, {"ok": true, "code": "guard_set", "resident_id": id})

func flee(id: String, command_id: String, physically_reachable: bool = true) -> Dictionary:
	var request := {"resident_id": id, "physically_reachable": physically_reachable}
	var duplicate: Variant = _existing(command_id, "flee", request)
	if duplicate != null: return duplicate
	var resident := _resident_or_error(id)
	if resident.is_empty(): return _reject(command_id, "flee", request, "resident_missing")
	if resident.zone not in DANGER_ZONES: return _reject(command_id, "flee", request, "danger_zone_required")
	if not physically_reachable: return _reject(command_id, "flee", request, "flee_route_unreachable")
	resident.zone = resident.last_safe_zone
	resident.guard = false
	return _record(command_id, "flee", request, {"ok": true, "code": "fled_to_safe_zone", "resident_id": id})

func retreat_after_defeat(id: String, command_id: String, physically_reachable: bool = true) -> Dictionary:
	var request := {"resident_id": id, "physically_reachable": physically_reachable}
	var duplicate: Variant = _existing(command_id, "retreat_after_defeat", request)
	if duplicate != null: return duplicate
	var resident := _resident_or_error(id)
	if resident.is_empty(): return _reject(command_id, "retreat_after_defeat", request, "resident_missing")
	if resident.status != "defeated" or resident.zone not in DANGER_ZONES:
		return _reject(command_id, "retreat_after_defeat", request, "defeat_retreat_required")
	if not physically_reachable: return _reject(command_id, "retreat_after_defeat", request, "retreat_route_unreachable")
	resident.zone = resident.last_safe_zone
	return _record(command_id, "retreat_after_defeat", request, {"ok": true, "code": "defeated_resident_retreated", "resident_id": id})

func recover(id: String, command_id: String) -> Dictionary:
	var request := {"resident_id": id}
	var duplicate: Variant = _existing(command_id, "recover", request)
	if duplicate != null: return duplicate
	var resident := _resident_or_error(id)
	if resident.is_empty(): return _reject(command_id, "recover", request, "resident_missing")
	if resident.zone != "town" or resident.status != "defeated": return _reject(command_id, "recover", request, "recovery_requires_defeat_in_town")
	resident.hp = 1
	resident.status = "ready"
	return _record(command_id, "recover", request, {"ok": true, "code": "recovered", "resident_id": id, "hp": 1})

func challenge_floor_one_boss(id: String, command_id: String, consent: bool = true) -> Dictionary:
	var request := {"resident_id": id, "consent": consent}
	var duplicate: Variant = _existing(command_id, "challenge_boss", request)
	if duplicate != null: return duplicate
	var resident := _resident_or_error(id)
	if resident.is_empty(): return _reject(command_id, "challenge_boss", request, "resident_missing")
	if resident.zone != "floor_one_boss_arena": return _reject(command_id, "challenge_boss", request, "boss_arena_required")
	if not _state.floor_one_gate_open: return _reject(command_id, "challenge_boss", request, "floor_one_gate_closed")
	if not consent: return _reject(command_id, "challenge_boss", request, "party_consent_required")
	_state.boss_encounter = true
	return _record(command_id, "challenge_boss", request, {"ok": true, "code": "boss_encounter_started", "resident_id": id})

func resolve_boss(command_id: String, victory: bool) -> Dictionary:
	var request := {"victory": victory}
	var duplicate: Variant = _existing(command_id, "resolve_boss", request)
	if duplicate != null: return duplicate
	if not _state.boss_encounter: return _reject(command_id, "resolve_boss", request, "boss_encounter_missing")
	_state.boss_encounter = false
	_state.boss_victory = victory
	if victory:
		_state.loot_receipts.append({"receipt_id": command_id, "kind": "finite_boss_loot", "quantity": 1})
	return _record(command_id, "resolve_boss", request, {"ok": true, "code": "boss_victory" if victory else "boss_defeat", "victory": victory})

func unlock_floor_two(command_id: String, present_ids: Array[String]) -> Dictionary:
	var request := {"present_ids": present_ids.duplicate()}
	var duplicate: Variant = _existing(command_id, "unlock_floor_two", request)
	if duplicate != null: return duplicate
	if not _state.boss_victory: return _reject(command_id, "unlock_floor_two", request, "boss_victory_required")
	if present_ids.is_empty(): return _reject(command_id, "unlock_floor_two", request, "party_required")
	_state.floor = 2
	return _record(command_id, "unlock_floor_two", request, {"ok": true, "code": "floor_unlocked", "floor": 2, "party": present_ids.duplicate()})

func _resident_or_error(id: String) -> Dictionary:
	return _state.get("residents", {}).get(id, {})

func _encounter_or_error(id: String) -> Dictionary:
	return _state.get("encounters", {}).get(id, {})

func _existing(command_id: String, kind: String, request: Dictionary):
	if not _valid_command_id(command_id):
		return {"ok": false, "code": "invalid_command_id", "command_id": command_id}
	if _state.get("commands", {}).has(command_id):
		var saved: Variant = _state.commands[command_id]
		if not saved is Dictionary or saved.get("request", {}) != {"kind": kind, "parameters": request}:
			return {"ok": false, "code": "command_conflict", "command_id": command_id}
		var old: Dictionary = saved.get("result", {}).duplicate(true)
		old["duplicate"] = true
		return old
	return null

func _valid_command_id(command_id: String) -> bool:
	if command_id.is_empty() or command_id != command_id.strip_edges() or command_id.length() > 128:
		return false
	for index in command_id.length():
		var codepoint := command_id.unicode_at(index)
		var alphanumeric := (codepoint >= 48 and codepoint <= 57) or (codepoint >= 65 and codepoint <= 90) or (codepoint >= 97 and codepoint <= 122)
		if not alphanumeric and (index == 0 or codepoint not in [58, 46, 95, 45]):
			return false
	return true

func _is_combat_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

func _reject(command_id: String, kind: String, request: Dictionary, code: String) -> Dictionary:
	var result := {"ok": false, "code": code, "command_id": command_id}
	_state.commands[command_id] = {"request": {"kind": kind, "parameters": request.duplicate(true)}, "result": result.duplicate(true)}
	return result

func _record(command_id: String, kind: String, request: Dictionary, result: Dictionary) -> Dictionary:
	var receipt := result.duplicate(true)
	receipt["command_id"] = command_id
	receipt["kind"] = kind
	receipt["receipt_id"] = "adventure:%d" % (_state.receipts.size() + 1)
	_state.commands[command_id] = {"request": {"kind": kind, "parameters": request.duplicate(true)}, "result": receipt.duplicate(true)}
	_state.receipts.append(receipt.duplicate(true))
	return receipt
