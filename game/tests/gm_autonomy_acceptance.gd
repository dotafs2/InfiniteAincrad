extends SceneTree

# Offline runtime-verification fixture for tools/gm_autonomy.py. It runs the real
# game/core/world_kernel.gd fixture inside the disposable trial installation, installs the
# published capability manifest through the kernel's own validation, drives a resident step so
# the change is actually USED (installed-but-unused is reported distinctly), persists a save and
# then cold-loads the same save to check identity/history/property/pending-command invariants.
#
# It is an explicitly labelled fixture: commands are scripted, no model is called, and a green
# result is not evidence of real DeepSeek GM autonomy.

const Kernel = preload("res://core/world_kernel.gd")

var _failures: Array[String] = []
var _options := {}

func _initialize() -> void:
	_options = _parse_args()
	if not _required_flags_present():
		return
	var phase := str(_options.get("phase", ""))
	if phase == "seed":
		_run_seed()
	elif phase == "open":
		_run_open()
	elif phase == "resume":
		_run_resume()
	else:
		_failures.append("unknown phase " + phase)
		_finish({}, false, false, false)

func _parse_args() -> Dictionary:
	var options := {}
	for argument in OS.get_cmdline_user_args():
		var text := str(argument)
		if text.begins_with("--") and text.contains("="):
			var split := text.substr(2).split("=", true, 1)
			options[split[0]] = split[1]
	return options

func _required_flags_present() -> bool:
	for key in ["save", "phase", "out", "nonce"]:
		if not _options.has(key) or str(_options[key]).is_empty():
			_failures.append("missing required flag --" + key)
	var phase := str(_options.get("phase", ""))
	if phase != "seed":
		for key in ["manifest", "release-digest", "issue-id"]:
			if not _options.has(key) or str(_options[key]).is_empty():
				_failures.append("missing required flag --" + key)
	if phase == "resume" and str(_options.get("prior-file", "")).is_empty():
		_failures.append("missing required flag --prior-file for resume")
	if phase == "seed" and str(_options.get("allow-create", "")) != "yes":
		_failures.append("seed requires --allow-create=yes; this fixture never resets a save")
	if not _failures.is_empty():
		_finish({}, false, false, false)
		return false
	return true

func _read_manifest() -> Dictionary:
	var target := str(_options["manifest"])
	if not FileAccess.file_exists(target):
		_failures.append("published manifest is not present in the trial installation")
		return {}
	var file := FileAccess.open(target, FileAccess.READ)
	if file == null:
		_failures.append("published manifest cannot be opened")
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		_failures.append("published manifest is not a JSON object")
		return {}
	return parsed

func _run_seed() -> void:
	if FileAccess.file_exists(str(_options["save"])):
		_failures.append("refusing to reset an existing save at " + str(_options["save"]))
		_finish({"code": "save_already_exists"}, false, false, false)
		return
	var kernel = Kernel.new()
	var created: Dictionary = kernel.create_fixture()
	_check(bool(created.get("ok", false)), "seed fixture world is created")
	var need_step: Dictionary = kernel.resident_step()
	_check(need_step.get("code", "") == "resident_need_recorded",
		"seed records the resident need before any change")
	var saved: Dictionary = kernel.save_to(str(_options["save"]))
	_check(bool(saved.get("ok", false)), "seed saves the labelled fixture: " + str(saved.get("code")))
	_finish({"code": "seed_saved", "seed": true}, false, false, false)

func _load_module_script(path: String) -> GDScript:
	if not FileAccess.file_exists(path):
		return null
	var text := FileAccess.get_file_as_string(path)
	if text.strip_edges().is_empty():
		return null
	var script := GDScript.new()
	script.source_code = text
	if script.reload() != OK:
		return null
	return script

func _run_lookup_module(path: String, snapshot: Dictionary) -> Dictionary:
	var script := _load_module_script(path)
	if script == null:
		return {"ok": false, "code": "candidate_module_unusable", "path": path}
	var instance = script.new()
	if instance == null or not instance.has_method("lookup_well_stock"):
		return {"ok": false, "code": "candidate_interface_missing", "path": path}
	var result = instance.call("lookup_well_stock", snapshot)
	if typeof(result) != TYPE_DICTIONARY:
		return {"ok": false, "code": "candidate_report_not_a_dictionary"}
	return result

func _fixture_manifest_from_lookup(lookup: Dictionary) -> Dictionary:
	return {"schema_version": 1, "capability_id": "well_bucket", "version": "1.0.0",
		"world_id": Kernel.WORLD_ID, "provenance": "fixture",
		"actions": [{"id": "draw_water",
			"from": "world." + str(lookup.get("resolved_key", "")),
			"to": "resident.inventory.water", "amount": int(lookup.get("amount", 0))}],
		"install": {"materials": {"rope": 1, "bucket": 1}}}

func _run_open() -> void:
	if not FileAccess.file_exists(str(_options["save"])):
		_failures.append("the runtime save is absent; verification never creates a save")
		_finish({"code": "save_missing_refused"}, false, false, false)
		return
	var manifest_path := str(_options["manifest"])
	var is_module := manifest_path.to_lower().ends_with(".gd")
	var manifest: Dictionary = {} if is_module else _read_manifest()
	var mechanism_report: Dictionary = {}
	# Labelled fault injection for the repair-loop fixture: exactly one verification run per
	# marker reports an actionable runtime defect before any install or world mutation, so the
	# host truthfully records a failed verification and the reopened round is verified honestly
	# on the same unchanged save. The marker is consumed here.
	var defect_marker := str(_options.get("defect-once", ""))
	if not defect_marker.is_empty() and FileAccess.file_exists(defect_marker):
		DirAccess.remove_absolute(defect_marker)
		_failures.append("labelled fault injection: an actionable runtime defect was observed on this release")
		_finish({"code": "runtime_defect_observed", "injected_defect": true}, false, false, false)
		return
	var kernel = Kernel.new()
	var loaded: Dictionary = kernel.load_from(str(_options["save"]))
	_check(bool(loaded.get("ok", false)), "the seeded save loads: " + str(loaded.get("code")))
	var prior: Dictionary = _capture_prior(kernel.snapshot())
	if is_module and str(_options.get("depleted-probe", "")) == "yes":
		var plugin_now: Dictionary = kernel.snapshot().get("plugins", {}).get("well_bucket", {})
		if plugin_now.get("status", "") == "enabled" and int(kernel.snapshot().get("world", {}).get("well_water", -1)) <= 0:
			# Explicit depleted-state probe (--depleted-probe=yes): the release is already
			# installed and this world is already depleted by the earlier delivery. Invoke the
			# newly deployed mechanism on the live depleted snapshot and require the corrected
			# empty-stock result. Nothing installs, draws, refills or saves; the probe reports
			# current mechanism execution separately from the earlier historical water use.
			var state_before := JSON.stringify(kernel.snapshot())
			var save_before := _file_sha256(str(_options["save"]))
			var probe: Dictionary = _run_lookup_module(manifest_path, kernel.snapshot())
			_check(not bool(probe.get("ok", true)),
				"the depleted-state probe reports a non-ok mechanism result")
			_check(str(probe.get("code", "")) == "well_stock_empty",
				"the corrected mechanism reports the expected well_stock_empty result")
			_check(str(probe.get("resolved_key", "")) == "well_water",
				"the depleted-state probe resolved the well_water key")
			_check(int(probe.get("amount", -1)) == 0,
				"the depleted-state probe observed an exact zero stock")
			_check(JSON.stringify(kernel.snapshot()) == state_before,
				"the depleted-state probe mutated no world state")
			_check(_file_sha256(str(_options["save"])) == save_before,
				"the depleted-state probe did not rewrite the same save")
			_finish({"code": "depleted_probe_done", "mechanism": probe, "depleted_probe": true,
				"drawn_this_phase": 0, "consumed_this_phase": 0, "prior": prior,
				"installed_materials": {"rope": 0, "bucket": 0},
				"note": "the release was already installed and used by the earlier delivery; this run only probes the corrected mechanism on the unchanged depleted save"},
				true, true, false)
			return
	if is_module:
		var lookup: Dictionary = _run_lookup_module(manifest_path, kernel.snapshot())
		if not bool(lookup.get("ok", false)):
			_failures.append("candidate mechanism lookup failed before install/use: "
				+ str(lookup.get("code", "candidate_lookup_failed")))
			_finish({"code": str(lookup.get("code", "candidate_lookup_failed")),
				"mechanism": lookup, "installed": false, "used": false}, false, false, false)
			return
		manifest = _fixture_manifest_from_lookup(lookup)
		mechanism_report = lookup
	var review: Dictionary = kernel.gm_review_need("autonomy-review-1", "approve", "well_bucket",
		"Offline fixture GM review of the recorded need.")
	_check(review.get("code", "") == "gm_need_approved", "GM review approves the recorded need")
	var install: Dictionary = kernel.gm_install(manifest, "autonomy-install-1", "autonomy-review-1")
	var installed: bool = bool(install.get("ok", false)) and install.get("code", "") == "capability_installed"
	if not installed:
		installed = kernel.snapshot().get("plugins", {}).get("well_bucket", {}).get("status", "") == "enabled"
	_check(installed, "published manifest installs through kernel validation: " + str(install.get("code")))
	var used := false
	# Labelled fault injection: --simulate-unused=yes installs the capability but never draws,
	# so the host can record "installed but unused" instead of inventing adoption.
	if installed and str(_options.get("simulate-unused", "")) != "yes":
		for index in range(4):
			var step: Dictionary = kernel.resident_step()
			if step.get("code", "") == "water_drawn":
				used = true
			if step.get("code", "") == "water_consumed":
				break
	_check(used, "resident actually draws water with the installed capability")
	var after: Dictionary = kernel.snapshot()
	var luna_after: Dictionary = after.get("residents", {}).get("fixture:luna", {})
	var drawn_this_phase: int = int(luna_after.get("memory", {}).get("water_drawn", 0)) - int(prior.get("memory_water_drawn", 0))
	var consumed_this_phase: int = int(luna_after.get("consumed", {}).get("water", 0)) - int(prior.get("consumed_water", 0))
	var saved: Dictionary = kernel.save_to(str(_options["save"]))
	_check(bool(saved.get("ok", false)), "world save is written: " + str(saved.get("code")))
	var report := {"code": "open_done", "prior": prior, "drawn_this_phase": drawn_this_phase,
		"consumed_this_phase": consumed_this_phase,
		"mechanism": mechanism_report,
	"installed_materials": {"rope": 1, "bucket": 1},
		"idempotent_note": "review/install use fixed command ids so an interrupted re-run does not duplicate the mutation"}
	_finish(report, installed, used, false)
func _run_resume() -> void:
	var prior_doc := _read_json_object(str(_options.get("prior-file", "")))
	if typeof(prior_doc.get("prior")) != TYPE_DICTIONARY:
		_failures.append("resume needs the open phase prior facts from --prior-file")
		_finish({}, false, false, false)
		return
	var prior: Dictionary = prior_doc["prior"]
	var drawn: int = int(prior_doc.get("drawn_this_phase", 0))
	var consumed: int = int(prior_doc.get("consumed_this_phase", 0))
	var depleted_probe: bool = bool(prior_doc.get("depleted_probe", false))
	var kernel = Kernel.new()
	var loaded: Dictionary = kernel.load_from(str(_options["save"]))
	_check(bool(loaded.get("ok", false)), "same save cold-loads: " + str(loaded.get("code")))
	var snapshot: Dictionary = kernel.snapshot()
	var luna: Dictionary = snapshot.get("residents", {}).get("fixture:luna", {})
	# Exact prior facts, not counts >= N: these values must survive byte-for-byte.
	_check(_json_equal(luna.get("identity", {}), prior.get("identity", {})),
		"resident identity survives exactly")
	_check(_prefix_equal(luna.get("observations", []), prior.get("observations", [])),
		"the prior observations survive exactly as a prefix")
	_check(_prefix_equal(snapshot.get("events", []), prior.get("events", [])),
		"the world event history keeps the exact prior prefix")
	_check(_dict_prefix_equal(snapshot.get("receipts", {}), prior.get("receipts", {})),
		"every prior command receipt survives with identical bytes")
	_check(_dict_prefix_equal(snapshot.get("command_payloads", {}), prior.get("command_payloads", {})),
		"every prior command payload survives with identical bytes")
	var resources: Dictionary = snapshot.get("world", {}).get("gm_resources", {})
	var materials: Dictionary = prior_doc.get("installed_materials", {"rope": 1, "bucket": 1})
	var prior_resources: Dictionary = prior.get("gm_resources", {})
	_check(int(snapshot.get("world", {}).get("well_water", -1)) == int(prior.get("world_well_water", -1)) - drawn,
		"the well stock changed by exactly the drawn amount")
	_check(int(resources.get("rope", -1)) == int(prior_resources.get("rope", 0)) - int(materials.get("rope", 0)),
		"the rope material was consumed exactly once")
	_check(int(resources.get("bucket", -1)) == int(prior_resources.get("bucket", 0)) - int(materials.get("bucket", 0)),
		"the bucket material was consumed exactly once")
	_check(int(luna.get("memory", {}).get("water_drawn", -1)) == int(prior.get("memory_water_drawn", 0)) + drawn,
		"the drawing fact advanced by exactly the drawn amount")
	_check(int(luna.get("consumed", {}).get("water", -1)) == int(prior.get("consumed_water", 0)) + consumed,
		"the consumption fact advanced by exactly the consumed amount")
	_check(int(luna.get("inventory", {}).get("water", -1)) == int(prior.get("inventory_water", 0)) + drawn - consumed,
		"the water inventory follows the exact delta")
	var plugin: Dictionary = snapshot.get("plugins", {}).get("well_bucket", {})
	var installed: bool = plugin.get("status", "") == "enabled"
	_check(installed, "the installed capability is still installed and enabled")
	var probe: Dictionary = {}
	if depleted_probe:
		probe = _run_lookup_module(str(_options["manifest"]), snapshot)
		var save_before_probe := _file_sha256(str(_options["save"]))
		_check(not bool(probe.get("ok", true)) and str(probe.get("code", "")) == "well_stock_empty"
			and str(probe.get("resolved_key", "")) == "well_water"
			and int(probe.get("amount", -1)) == 0,
			"the corrected mechanism still reports well_stock_empty on the cold-loaded same save")
		var prior_observation: Dictionary = prior_doc.get("observation") if typeof(prior_doc.get("observation")) == TYPE_DICTIONARY else {}
		_check(save_before_probe == str(prior_observation.get("save_sha256", "")),
			"the same save is byte-identical between the release run and the cold reload")
		_check(_file_sha256(str(_options["save"])) == save_before_probe,
			"the depleted-state probe did not rewrite the same save")
	var used := (drawn >= 1 and consumed >= 1) or depleted_probe
	_check(used, "the release was used or its mechanism probed, not merely installed")
	var step: Dictionary = kernel.resident_step()
	_check(bool(step.get("ok", false)), "the resident can still act after the cold start: " + str(step.get("code")))
	_finish({"prior_checked": prior, "mechanism": probe, "depleted_probe": depleted_probe},
		installed, used, _failures.is_empty())

func _capture_prior(snapshot: Dictionary) -> Dictionary:
	var luna: Dictionary = snapshot.get("residents", {}).get("fixture:luna", {})
	return {
		"world_id": snapshot.get("world_id", ""),
		"identity": luna.get("identity", {}),
		"observations": luna.get("observations", []),
		"memory_water_drawn": int(luna.get("memory", {}).get("water_drawn", 0)),
		"inventory_water": int(luna.get("inventory", {}).get("water", 0)),
		"consumed_water": int(luna.get("consumed", {}).get("water", 0)),
		"world_well_water": int(snapshot.get("world", {}).get("well_water", -1)),
		"gm_resources": snapshot.get("world", {}).get("gm_resources", {}),
		"receipts": snapshot.get("receipts", {}),
		"command_payloads": snapshot.get("command_payloads", {}),
		"events": snapshot.get("events", []),
		"turn": int(snapshot.get("turn", 0)),
	}

func _read_json_object(path: String) -> Dictionary:
	if path.is_empty() or not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func _json_equal(left, right) -> bool:
	return JSON.stringify(left) == JSON.stringify(right)

func _prefix_equal(full: Array, prefix: Array) -> bool:
	if full.size() < prefix.size():
		return false
	for index in range(prefix.size()):
		if not _json_equal(full[index], prefix[index]):
			return false
	return true

func _dict_prefix_equal(full: Dictionary, prefix: Dictionary) -> bool:
	for key in prefix.keys():
		if not full.has(key) or not _json_equal(full[key], prefix[key]):
			return false
	return true
func _check(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)

func _event_types(events: Array) -> Array:
	var types: Array = []
	for event in events:
		if typeof(event) == TYPE_DICTIONARY:
			types.append(str(event.get("type", "")))
	return types

func _payload_mechanism(payload: Dictionary) -> Dictionary:
	return payload.get("mechanism") if typeof(payload.get("mechanism")) == TYPE_DICTIONARY else {}

func _file_sha256(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(FileAccess.get_file_as_bytes(path))
	return context.finish().hex_encode()

func _finish(payload: Dictionary, installed: bool, used: bool, continuation_ok: bool) -> void:
	var snapshot: Dictionary = {}
	if _options.has("save") and FileAccess.file_exists(str(_options["save"])):
		var probe = Kernel.new()
		if bool(probe.load_from(str(_options["save"])).get("ok", false)):
			snapshot = probe.snapshot()
	var luna: Dictionary = snapshot.get("residents", {}).get("fixture:luna", {})
	var observation := {
		"phase": str(_options.get("phase", "")),
		"world_id": Kernel.WORLD_ID,
		"turn": snapshot.get("turn", null),
		"well_water": snapshot.get("world", {}).get("well_water", null),
		"resident_inventory_water": luna.get("inventory", {}).get("water", null),
		"resident_consumed_water": luna.get("consumed", {}).get("water", null),
		"resident_water_drawn": luna.get("memory", {}).get("water_drawn", null),
		"capability_status": snapshot.get("plugins", {}).get("well_bucket", {}).get("status", null),
		"event_types": _event_types(snapshot.get("events", [])),
		"save_sha256": _file_sha256(str(_options.get("save", ""))),
		"current_mechanism_code": str(_payload_mechanism(payload).get("code", "")),
		"mechanism_invoked": not _payload_mechanism(payload).is_empty(),
		"depleted_probe": bool(payload.get("depleted_probe", false)),
		"water_drawn_this_phase": int(payload.get("drawn_this_phase", 0)),
		"installed_but_unused": installed and not used,
	}
	var output := payload.duplicate(true)
	output["world_id"] = Kernel.WORLD_ID
	output["issue_id"] = str(_options.get("issue-id", ""))
	output["release_digest"] = str(_options.get("release-digest", ""))
	output["nonce"] = str(_options.get("nonce", ""))
	output["installed"] = installed
	output["used"] = used
	output["continuation_ok"] = continuation_ok
	output["observation"] = observation
	output["failures"] = _failures.duplicate()
	output["ok"] = _failures.is_empty() and bool(payload.get("ok", true))
	output["provenance"] = "offline_gm_autonomy_fixture"
	output["paid_model_calls"] = 0
	var out_path := str(_options.get("out", ""))
	if not out_path.is_empty():
		var file := FileAccess.open(out_path, FileAccess.WRITE)
		if file != null:
			file.store_string(JSON.stringify(output, "", true))
			file.flush()
			file.close()
	print(JSON.stringify(output))
	quit(0 if output["ok"] else 1)
