extends SceneTree

const BRAIN := preload("res://agents/resident_brain.gd")
var failures: Array[String] = []
var checks := 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)

func _initialize() -> void:
	var brain: Node = BRAIN.new()
	var experiences: Array = []
	for index in 30:
		experiences.append({"seq": index + 1, "type": "old_personal_event",
			"text": "旧个人记录".repeat(500)})
	var view := {"world_id": "fixture:context-budget", "identity": {"id": "fixture:resident"},
		"needs": {"hunger": 2}, "experiences": experiences,
		"observations": [{"seq": 40, "text": "recent observation"}],
		"memory": {"previous_decisions": [{"action": "wait", "reason": "old reason"}]},
		"available_actions": ["wait", "deliver:contract-1"],
		"action_details": [{"id": "deliver:contract-1", "contract_id": "contract-1"}],
		"contracts": [{"id": "contract-1", "status": "accepted"}],
		"material_sources": [{"id": "source-1", "last_observed_stock": 2}],
		"known_rules": {"repair": "requires material"}}
	var original := view.duplicate(true)
	var input := {"sessionId": "decision:fixture", "actorId": "fixture:resident",
		"inputId": "fixture", "type": "personal_observation", "timelineId": view.world_id,
		"tick": 41, "payload": {"resident_view": view}}
	var payload: String = brain._bounded_input(input, view)
	var parsed: Dictionary = JSON.parse_string(payload)
	var bounded: Dictionary = parsed.payload.resident_view
	check(not payload.is_empty() and brain._input_units(payload) <= brain.INPUT_CHARACTER_TARGET,
		"bounded payload fits context-aware target")
	check(bounded.identity.id == original.identity.id and bounded.needs.hunger == original.needs.hunger,
		"identity and current needs remain exact")
	check(bounded.available_actions == original.available_actions and bounded.action_details == original.action_details,
		"current options remain exact")
	check(bounded.contracts[0].id == original.contracts[0].id
		and bounded.contracts[0].status == original.contracts[0].status
		and bounded.material_sources[0].id == original.material_sources[0].id
		and bounded.material_sources[0].last_observed_stock == original.material_sources[0].last_observed_stock
		and bounded.known_rules.repair == original.known_rules.repair,
		"current contract, source and rule facts remain exact")
	check(bounded.experiences.size() < original.experiences.size(), "only old personal history is reduced")
	check(view == original, "canonical caller view is unchanged")
	check(brain.provider_failure_identifier(
		"The system prompt, tools, and new input leave no context budget for the session transcript.")
		== "brain_context_window_exceeded", "actual OGA context branch is classified exactly")
	check(brain.provider_failure_identifier("unrecognized provider detail") == "brain_provider_failed",
		"unknown provider text remains sanitized")
	brain.free()
	print(JSON.stringify({"suite": "resident_brain_context_budget", "passed": failures.is_empty(),
		"checks": checks, "failures": failures, "real_paid_calls": 0}))
	quit(0 if failures.is_empty() else 1)
