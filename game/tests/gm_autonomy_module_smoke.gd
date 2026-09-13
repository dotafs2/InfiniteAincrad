extends SceneTree

# Host-owned GDScript compile/interface smoke for one candidate capability module.
#
# The Python host gate in tools/validate_gm_autonomy.py is deliberately a bounded INTERFACE
# guard: byte bound, UTF-8 decodability, balanced delimiters, the declared static lookup name
# and a forbidden-token list. A delimiter-balanced source can still fail to parse, so that
# guard is NOT a compiler and it does not prove the absence of ambient IO. This script runs
# inside a disposable Godot process, uses the real GDScript compiler on the candidate bytes,
# then instantiates the module and calls its declared pure lookup with a declared neutral/empty
# unit input, requiring a schema-valid missing-stock error. It proves the module parses and
# exposes the declared interface. It cannot separate the defective lookup from the corrected
# one: only the real world-snapshot integration does that.
#
# Usage: godot --headless --path <scratch project> --script <this file> -- #            --module=<absolute module path> --out=<absolute report path>

var _failures: Array[String] = []

func _initialize() -> void:
	var options := _parse_args()
	var module_path := str(options.get("module", ""))
	var out_path := str(options.get("out", ""))
	var report := {"kind": "gm_module_smoke", "module": module_path, "compiled": false,
		"compile_error": null, "interface_ok": false, "code": null}
	if module_path.is_empty() or out_path.is_empty():
		_failures.append("missing --module or --out")
		_finish(report, out_path)
		return
	var source := _read_text(module_path)
	if source.is_empty():
		_failures.append("the module source is empty or unreadable: " + module_path)
		_finish(report, out_path)
		return
	var script := GDScript.new()
	script.source_code = source
	var error := script.reload()
	report["compiled"] = error == OK
	report["compile_error"] = int(error)
	if error != OK:
		_failures.append("the GDScript compiler rejected the module with error " + str(error))
		_finish(report, out_path)
		return
	_call_lookup(script, report)
	_finish(report, out_path)

func _call_lookup(script: GDScript, report: Dictionary) -> void:
	var instance = script.new()
	if instance == null:
		_failures.append("the compiled module could not be instantiated")
		return
	if not instance.has_method("lookup_well_stock"):
		_failures.append("the compiled module exposes no lookup_well_stock method")
		return
	var result = instance.call("lookup_well_stock", {})
	report["call_returned"] = true
	if typeof(result) != TYPE_DICTIONARY:
		_failures.append("lookup_well_stock(empty snapshot) did not return a Dictionary")
		return
	var payload: Dictionary = result
	if not payload.has("ok") or typeof(payload["ok"]) != TYPE_BOOL or payload["ok"] != false:
		_failures.append("the missing-stock result must carry an explicit ok=false")
		return
	var code = payload.get("code")
	if typeof(code) != TYPE_STRING or str(code).is_empty():
		_failures.append("the missing-stock result must carry a non-empty string code")
		return
	var text_fields := 0
	for key in ["code", "detail", "resolved_key"]:
		if payload.has(key) and typeof(payload[key]) == TYPE_STRING and not str(payload[key]).is_empty():
			text_fields += 1
	if text_fields < 2:
		_failures.append("the missing-stock result needs a code plus a detail or resolved_key")
		return
	report["code"] = str(code)

func _finish(report: Dictionary, out_path: String) -> void:
	var compiled: bool = report["compiled"]
	if compiled and not report.get("call_returned", false):
		_failures.append("lookup_well_stock(empty snapshot) did not return normally")
	report["interface_ok"] = compiled and _failures.is_empty()
	report["ok"] = _failures.is_empty()
	report["failures"] = _failures.duplicate()
	_report(out_path, report)
	quit(0 if report["ok"] else 1)

func _parse_args() -> Dictionary:
	var options := {}
	for argument in OS.get_cmdline_user_args():
		var text := str(argument)
		if text.begins_with("--") and text.contains("="):
			var split := text.substr(2).split("=", true, 1)
			options[split[0]] = split[1]
	return options

func _read_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var handle := FileAccess.open(path, FileAccess.READ)
	if handle == null:
		return ""
	return handle.get_as_text()

func _report(out_path: String, report: Dictionary) -> void:
	var text := JSON.stringify(report)
	print(text)
	if out_path.is_empty():
		return
	var handle := FileAccess.open(out_path, FileAccess.WRITE)
	if handle != null:
		handle.store_string(text)
