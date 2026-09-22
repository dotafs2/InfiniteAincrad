extends SceneTree
## Bounded acceptance checks for saved three-case review preview.

var failures: Array[String] = []

func _init() -> void:
	var scene := load("res://scenes/dialogue_proposal_review_preview.tscn")
	if scene == null:
		_fail("preview scene failed to load")
		_finish()
		return
	var instance = scene.instantiate()
	root.add_child(instance)
	for _frame in range(12):
		await process_frame
	if instance.cases.size() != 3:
		_fail("expected 3 saved cases, got %d" % instance.cases.size())
	if instance.reviews.size() != 3:
		_fail("expected 3 review results, got %d" % instance.reviews.size())
	for i in range(min(instance.reviews.size(), 3)):
		var result: Dictionary = instance.reviews[i]
		for key in ["ok", "structural_accepted", "review_required", "reason", "alias", "action_id", "declared_intent", "expected_intents", "speech", "execution", "semantic_truth_verification"]:
			if not result.has(key):
				_fail("case %d missing review key %s" % [i, key])
		if result.get("execution", "") != "not_attempted":
			_fail("case %d execution was not not_attempted" % i)
		if result.get("semantic_truth_verification", true) != false:
			_fail("case %d claimed semantic truth verification" % i)
		instance._select_case(i)
		await process_frame
		var visible: String = str(instance._status_label.text) + "\n" + _body_text(instance._body)
		if visible.find("private_thought") >= 0 or visible.find("Flint might not know") >= 0:
			_fail("case %d leaked private thought" % i)
		if visible.find("NOT EXECUTED") < 0:
			_fail("case %d missing prominent not executed banner" % i)
	if instance.status.find("Loaded 3 saved") < 0:
		_fail("status did not report meaningful loaded result")
	_finish()

func _body_text(container: Node) -> String:
	var lines: Array[String] = []
	for child in container.get_children():
		if child is Label:
			lines.append(child.text)
	return "\n".join(lines)

func _fail(message: String) -> void:
	failures.append(message)

func _finish() -> void:
	if failures.is_empty():
		print("dialogue_proposal_review_preview_acceptance: PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("dialogue_proposal_review_preview_acceptance: FAIL %d" % failures.size())
		quit(1)
