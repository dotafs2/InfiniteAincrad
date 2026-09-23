extends SceneTree

const Registry = preload("res://core/actions/capability_registry.gd")
const TownActions = preload("res://core/town_actions.gd")
const AdventureCapabilities = preload("res://core/actions/adventure_capabilities.gd")

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(label)

func run() -> void:
	var adventure := AdventureCapabilities.new()
	var definitions: Array = adventure.definitions()
	check(definitions.size() == 10, "contract exposes one versioned definition per action")
	var registry := Registry.new()
	var ids := {}
	for definition in definitions:
		check(not ids.has(definition.id), "adventure capability ids are unique: " + definition.id)
		ids[definition.id] = true
		check(definition.version == 1 and definition.owner == "adventure_contract.v1",
			"adventure definition is pinned to contract v1: " + definition.id)
		check(definition.lifecycle == "immediate" and definition.speech == "forbidden"
			and not str(definition.cancellation).is_empty(),
			"adventure definition carries lifecycle, speech and cancellation metadata: " + definition.id)
		check(registry.register(definition).ok, "adventure definition registers: " + definition.id)
	check(not registry.register(definitions[0]).ok, "duplicate adventure registration is refused")
	var inventory_references := 0
	for definition in definitions:
		for value in definition.resources + definition.preconditions + definition.effects:
			if str(value).to_lower().contains("inventory") or str(value).to_lower().contains("assign_loot"):
				inventory_references += 1
	check(inventory_references == 0, "no inventory capability reaches world-owned adventure loot")

	# Registration is checked against the existing host catalogue without installing the module.
	var host := TownActions.new()
	var host_registry := Registry.new()
	var host_definitions: Array = host.capability_definitions()
	check(host_definitions.size() == 36, "existing host catalogue remains unchanged while adventure is isolated")
	for definition in host_definitions:
		check(host_registry.register(definition).ok, "existing host definition remains valid: " + definition.id)
	for definition in definitions:
		check(host_registry.register(definition).ok, "adventure ids do not collide with host catalogue: " + definition.id)
	check(host_registry.all().size() == host_definitions.size() + definitions.size(),
		"combined registration is additive and deterministic")
	print(JSON.stringify({"suite": "adventure_capability_registration", "checks": checks,
		"failures": failures, "host_capabilities": host_definitions.size(),
		"adventure_capabilities": definitions.size(), "inventory_references": inventory_references,
		"metadata": definitions.map(func(definition): return {"id": definition.id, "version": definition.version,
			"owner": definition.owner, "lifecycle": definition.lifecycle, "speech": definition.speech,
			"cancellation": definition.cancellation}),
		"installed_in_town_actions": false,
		"status": "host_review_pending_effect_feedback"}))
	quit(0 if failures == 0 else 1)
