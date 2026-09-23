extends SceneTree

const ResidentTown = preload("res://core/adventure_resident_town.gd")
const Bridge = preload("res://core/adventure_live_bridge.gd")

class FixtureBrain extends Node:
	var controller
	var actor := ""
	var choice := ""
	var received: Dictionary = {}

	func propose(view: Dictionary, _seq: int) -> Dictionary:
		received = view.duplicate(true)
		var record: Dictionary = controller.town._state.godot.resident_turns[actor]
		var alias := "missing"
		for key in record.offered_actions:
			if record.offered_actions[key] == choice:
				alias = key
		await get_tree().process_frame
		return {"ok": true, "decision": {"action": alias,
			"reason": "I choose to enter from the gate after reaching it.", "speech": ""},
			"command_id": "fixture-provider:" + actor, "provenance": "opengameagent_fixture"}

var checks := 0
var failures := 0

func _arg(prefix: String) -> String:
	for raw in OS.get_cmdline_user_args():
		if raw.begins_with(prefix): return raw.trim_prefix(prefix)
	return ""

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

func run() -> void:
	var town_path := _arg("--town-save=")
	var adventure_path := _arg("--adventure-save=")
	var manifest_path := _arg("--manifest-save=")
	check(not town_path.is_empty() and not adventure_path.is_empty() and not manifest_path.is_empty(),
		"resident adoption probe receives explicit disposable paths")
	var bridge := Bridge.new()
	var installed: Dictionary = bridge.install(town_path, adventure_path)
	check(installed.ok, "resident bridge starts from the reviewed live install")
	var town := ResidentTown.new()
	check(town.load_from(town_path).ok, "resident bridge loads the disposable town copy")
	check(town.attach_adventure(bridge).ok, "resident bridge attaches the sidecar")
	var resident_id := "shared:baker"
	var route_receipt := {"ok": true, "route_kind": "collision_aware_town_route", "route_id": "market-to-wilderness-gate",
		"target": "wilderness_gate", "frames": 1005, "metres": 22.5680503845215}
	check(town.mark_physical_arrival(town_path, resident_id, route_receipt).ok,
		"host records a measured collision-aware gate arrival")
	var options: Array = town.action_options(resident_id)
	var offered := options.any(func(option): return option.get("id", "") == ResidentTown.ADVENTURE_OPTION)
	check(offered, "resident receives the gate-gated wilderness choice")
	var turns := preload("res://agents/town_turns.gd").new()
	root.add_child(turns)
	turns.town = town
	turns.save_path = town_path
	var brain := FixtureBrain.new()
	brain.controller = turns
	brain.actor = resident_id
	brain.choice = ResidentTown.ADVENTURE_OPTION
	turns.add_child(brain)
	turns.brains[resident_id] = brain
	var outcome: Dictionary = await turns.step(resident_id)
	check(outcome.ok and outcome.record.action == ResidentTown.ADVENTURE_OPTION,
		"resident controller applies the offered adventure choice")
	check(outcome.record.result.get("code", "") == "entered_wilderness",
		"resident choice produces the reviewed wilderness receipt")
	check(bridge.adventure.snapshot().residents[resident_id].zone == "wilderness",
		"sidecar records the resident's adopted zone")
	check(town._state.life.events[-1].get("type", "") == "adventure_enter_wilderness",
		"town history records the host action and resident provenance")
	check(bridge.save_manifest(manifest_path).ok, "resident adoption sidecar saves its manifest")
	var cold_town := ResidentTown.new()
	check(cold_town.load_from(town_path).ok, "town copy cold-restores after resident choice")
	var cold_bridge := Bridge.new()
	check(cold_bridge.load_manifest(manifest_path).ok, "adventure manifest cold-restores after resident choice")
	check(cold_bridge.adventure.snapshot().residents[resident_id].zone == "wilderness",
		"cold restore preserves the adopted wilderness zone")
	check(cold_town._state.life.events[-1].get("operation_id", "") == outcome.record.request_id,
		"cold restore preserves the resident command lineage")
	print(JSON.stringify({"suite":"adventure_resident_adoption_probe","checks":checks,"failures":failures,
		"resident_id":resident_id,"choice":ResidentTown.ADVENTURE_OPTION,
		"route_receipt":route_receipt,"canonical_mutation_allowed":false,
		"resident_adoption":true,"combat_authority":"undefined_until_host_seed",
		"status":"offline_resident_adoption_probe_passed_pending_real_model_feedback"}))
	turns.free()
	quit(0 if failures == 0 else 1)
