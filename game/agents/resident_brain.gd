extends Node

# Replace this adapter through the manifest; world facts remain in world_kernel.
const CONFIG_PATH := "res://agents/resident_brain.json"
var _adapter: Node
var _pending := ""
var _result: Dictionary = {}
var _requests := 0
var _disabled := false
var _timeout_ms := 10000
var _source := "opengameagent_fixture"
var _setup_error := ""

func configure(mode: String = "normal", timeout_ms: int = 10000) -> void:
	if _adapter != null:
		_setup_error = "already_configured"
		return
	_timeout_ms = clampi(timeout_ms, 50, 10000)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	if not parsed is Dictionary or parsed.get("schema_version") != 1:
		_setup_error = "brain_manifest_invalid"
		return
	_disabled = mode == "disabled" or not parsed.get("enabled", false)
	if _disabled:
		return
	var script: Script = load(str(parsed.get("adapter_script", "")))
	if script == null or not script.can_instantiate():
		_setup_error = "brain_adapter_missing_build_dotnet"
		return
	_adapter = script.new()
	add_child(_adapter)
	if mode == "gateway":
		_setup_error = str(_adapter.call("SetupGateway", OS.get_environment("AINCRAD_GATEWAY_RUN_CONFIG")))
		if not _setup_error.is_empty():
			return
		_timeout_ms = 38000
		_source = str(_adapter.call("CurrentProvenance"))
	else:
		_adapter.call("Setup", mode)
	_adapter.connect("run_completed", _on_completed)
	_adapter.connect("run_failed", _on_failed)

func propose(view: Dictionary, world_turn: int) -> Dictionary:
	if _disabled:
		return {"ok": false, "code": "brain_disabled"}
	if not _setup_error.is_empty() or _adapter == null:
		return {"ok": false, "code": _setup_error if not _setup_error.is_empty() else "brain_not_configured"}
	if not _pending.is_empty():
		return {"ok": false, "code": "brain_busy"}
	if _requests >= 12:
		return {"ok": false, "code": "brain_session_request_limit"}
	_requests += 1
	_pending = str(_adapter.call("NewOperationId"))
	var id := _pending
	_result = {}
	var input := {"sessionId": "street-fixture", "actorId": view.identity.id,
		"inputId": id, "type": "personal_observation", "timelineId": "fixture:well-street",
		"tick": world_turn, "payload": {"resident_view": view}}
	_adapter.call("RunJson", JSON.stringify(input))
	var started := Time.get_ticks_msec()
	while _result.is_empty() and Time.get_ticks_msec() - started < _timeout_ms:
		await get_tree().process_frame
	if _result.is_empty():
		_adapter.call("Cancel", id)
		_result = {"ok": false, "code": "brain_timeout"}
	var outcome := _result.duplicate(true)
	outcome["command_id"] = id
	outcome["provenance"] = _source
	_pending = ""
	return outcome

func _on_completed(input_id: String, result_json: String) -> void:
	if input_id != _pending:
		return
	var parsed: Variant = JSON.parse_string(result_json)
	if not parsed is Dictionary or parsed.get("status") != "Completed":
		_result = {"ok": false, "code": "brain_run_failed"}
		return
	var messages: Array = parsed.get("agent", {}).get("newMessages", [])
	for index in range(messages.size() - 1, -1, -1):
		var message: Dictionary = messages[index]
		if message.get("role") != "Assistant":
			continue
		for part: Dictionary in message.get("content", []):
			if part.get("kind") != "text":
				continue
			var parser := JSON.new()
			if parser.parse(str(part.get("text", ""))) != OK:
				_result = {"ok": false, "code": "brain_response_invalid"}
				return
			var decision: Variant = parser.data
			if decision is Dictionary:
				_result = {"ok": true, "decision": decision, "runtime": "OpenGameAgent", "fixture": _source != "opengameagent_live"}
				return
	_result = {"ok": false, "code": "brain_response_invalid"}

func _on_failed(input_id: String, _error: String) -> void:
	if input_id == _pending:
		_result = {"ok": false, "code": "brain_provider_failed"}
