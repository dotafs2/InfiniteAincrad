extends SceneTree

const WorldKernel = preload("res://core/world_kernel.gd")

var _failures := 0
var _checks := 0

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var kernel := WorldKernel.new()
	kernel.create_fixture()
	var luna_before := kernel.resident_view()
	_assert(kernel.add_fixture_visitor("add-mira").ok)
	_assert(kernel.resident_view() == luna_before)
	var mira := kernel.resident_view("fixture:mira")
	_assert(mira.observations == ["I am standing on the street."])
	_assert(mira.experiences.is_empty())
	_assert(kernel.resident_view("fixture:missing").is_empty())
	var before_unknown := kernel.snapshot()
	_assert(not kernel.submit_resident_decision({"action": "wait"}, "unknown-action", "local_rule_policy", "fixture:missing").ok)
	_assert(not kernel.observe_well("fixture:missing", "unknown-observation").ok)
	_assert(kernel.snapshot() == before_unknown)
	_assert(kernel.submit_resident_decision({"action": "wait"}, "mira-wait", "local_rule_policy", "fixture:mira").ok)
	_assert(kernel.resident_view().actions.is_empty())
	var observed := kernel.observe_well("fixture:mira", "mira-observe")
	_assert(observed.ok)
	var repeated := kernel.observe_well("fixture:mira", "mira-observe")
	_assert(repeated.duplicate)
	_assert(kernel.resident_view("fixture:mira").experiences.size() == 1)
	var path := "user://resident-knowledge-%d.json" % Time.get_ticks_usec()
	_assert(kernel.save_to(path).ok)
	var restored := WorldKernel.new()
	var loaded: Dictionary = restored.load_from(path)
	_assert(loaded.ok)
	# Godot JSON reads numbers as floats; compare the serialized contract.
	_assert(restored.resident_view("fixture:mira") == JSON.parse_string(JSON.stringify(kernel.resident_view("fixture:mira"))))
	_assert(restored.snapshot() == JSON.parse_string(JSON.stringify(kernel.snapshot())))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	kernel.submit_resident_decision({"action": "wait", "need": {"capability_id": "well_bucket", "reason": "Need water"}}, "luna-need")
	kernel.gm_review_need("well-review", "approve", "well_bucket", "Fixture approval")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://capabilities/well_bucket.v1.json"))
	_assert(kernel.gm_install(manifest, "well-install", "well-review").ok)
	_assert(kernel.resident_view("fixture:mira").available_actions == ["wait"])
	_assert(kernel.observe_well("fixture:mira", "mira-observe-installed").ok)
	_assert(kernel.resident_view("fixture:mira").available_actions == ["wait", "draw_water"])
	print(JSON.stringify({"suite": "resident_knowledge", "checks": _checks, "failures": _failures, "paid_calls": 0}))
	quit(0 if _failures == 0 else 1)

func _assert(condition: bool) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error("resident knowledge fixture assertion failed")
