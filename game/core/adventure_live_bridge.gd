extends RefCounted
## Disposable-only bridge: composes the reviewed adventure reducer beside TownActions.
## It never writes the maintained town save and is not wired into the production scene.
const TownActions = preload("res://core/town_actions.gd")
const Adventure = preload("res://core/adventure_state.gd")
const Registry = preload("res://core/actions/capability_registry.gd")
const AdventureCapabilities = preload("res://core/actions/adventure_capabilities.gd")

var town
var adventure
var registry
var manifest: Dictionary = {}

func install(town_save: String, adventure_save: String) -> Dictionary:
	town = TownActions.new()
	var town_result: Dictionary = town.load_from(town_save)
	if not town_result.ok: return {"ok": false, "code": "town_load_failed", "detail": town_result}
	adventure = Adventure.new()
	var adventure_result: Dictionary = adventure.load_from(adventure_save)
	if not adventure_result.ok: return {"ok": false, "code": "adventure_load_failed", "detail": adventure_result}
	registry = Registry.new()
	var host_definitions: Array = town.capability_definitions()
	for definition in host_definitions:
		var host_register: Dictionary = registry.register(definition)
		if not host_register.ok: return {"ok": false, "code": "host_capability_registration_failed", "detail": host_register}
	var adventure_definitions: Array = AdventureCapabilities.new().definitions()
	for definition in adventure_definitions:
		var adventure_register: Dictionary = registry.register(definition)
		if not adventure_register.ok: return {"ok": false, "code": "adventure_capability_registration_failed", "detail": adventure_register}
	manifest = {
		"schema_version": 1,
		"install_kind": "disposable_adventure_sidecar",
		"canonical_mutation_allowed": false,
		"town_world_id": str(town.snapshot().get("world_id", "")),
		"town_seq": int(town.snapshot().get("life", {}).get("seq", -1)),
		"contract_id": "adventure_contract.v1",
		"host_capabilities": host_definitions.size(),
		"adventure_capabilities": adventure_definitions.size(),
		"registered_capabilities": registry.all().map(func(definition): return {
			"id": definition.id, "version": definition.version, "owner": definition.owner,
			"lifecycle": definition.lifecycle, "speech": definition.speech,
			"cancellation": definition.cancellation}),
		"adventure_state": adventure.snapshot()
	}
	return {"ok": true, "code": "disposable_adventure_installed", "manifest": manifest.duplicate(true)}

func save_manifest(path: String) -> Dictionary:
	if manifest.is_empty() or adventure == null: return {"ok": false, "code": "not_installed"}
	manifest.adventure_state = adventure.snapshot()
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return {"ok": false, "code": "manifest_open_failed"}
	file.store_string(JSON.stringify(manifest, "", true, true))
	file.close()
	return {"ok": true, "code": "manifest_saved"}

func load_manifest(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {"ok": false, "code": "manifest_missing"}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or parsed.get("contract_id") != "adventure_contract.v1":
		return {"ok": false, "code": "manifest_contract_mismatch"}
	if parsed.get("canonical_mutation_allowed", true): return {"ok": false, "code": "canonical_mutation_flag_invalid"}
	if not parsed.get("adventure_state", {}) is Dictionary:
		return {"ok": false, "code": "manifest_state_missing"}
	manifest = parsed.duplicate(true)
	adventure = Adventure.new()
	var state_path := path + ".adventure-state.json"
	var state_file := FileAccess.open(state_path, FileAccess.WRITE)
	if state_file == null: return {"ok": false, "code": "state_temp_open_failed"}
	state_file.store_string(JSON.stringify(manifest.adventure_state, "", true, true))
	state_file.close()
	var loaded: Dictionary = adventure.load_from(state_path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(state_path))
	if not loaded.ok: return {"ok": false, "code": "manifest_state_invalid"}
	return {"ok": true, "code": "disposable_manifest_loaded", "manifest": manifest.duplicate(true)}

func enter_wilderness(id: String, command_id: String) -> Dictionary:
	return adventure.enter_wilderness(id, command_id, true)

func attack(id: String, encounter_id: String, command_id: String) -> Dictionary:
	return adventure.attack(id, encounter_id, command_id)

func flee(id: String, command_id: String) -> Dictionary:
	return adventure.flee(id, command_id, true)
