extends Node

# Replace this adapter through the manifest; world facts remain in world_kernel.
const CONFIG_PATH := "res://agents/resident_brain.json"
## The per-process request budget's exact failure identifier. The counter it reports
## cannot survive a cold restart, so town_turns may admit one fresh turn for a saved
## receipt naming this identifier instead of holding that resident forever.
const SESSION_REQUEST_LIMIT_CODE := "brain_session_request_limit"
## Failure texts the adapter already produces, verbatim from the current sources
## (third_party OpenGameAgent GameAgentRuntime/GameData/OpenGameAgentNode, and
## BudgetGatewayProvider.cs), mapped to sanitized identifiers a maintainer can read.
## Classification is exact-match only: the identifier never claims more than the
## adapter said, and the two gateway texts deliberately keep their ambiguity because
## neither one names a particular guard or cause.
const PROVIDER_FAILURE_IDENTIFIERS := {
	"The estimated model request exceeds the context window and no transcript compactor is configured.": "brain_context_window_exceeded",
	"The system prompt, tools, and new input leave no context budget for the session transcript.": "brain_context_window_exceeded",
	"The input payload is too large.": "brain_input_too_large",
	"budget_gateway_rejected_or_uncertain": "brain_gateway_rejected_or_uncertain",
	"gateway_validation_failed": "brain_gateway_validation_failed",
	"canceled": "brain_run_canceled",
}
## A near match, an unrecognized text or a text carrying provider/secret material
## keeps this truthful fallback so the receipt never asserts an unverified cause.
const GENERIC_PROVIDER_FAILURE_CODE := "brain_provider_failed"
## The unchanged upstream input guard, mirrored locally so this adapter can tell
## whether the payload it is about to hand over fits. OgaResidentNode.cs configures
## GameRuntimeLimits.MaxInputJsonCharacters = 16000 on the official runtime and
## .NET counts UTF-16 code units. Nothing here raises that limit, and no guard,
## retry, cooldown, request id or gateway accounting row changes because of it.
const INPUT_CHARACTER_CAP := 16000
## Dispatch target with a small headroom under the guard, so a bounded payload never
## rides its boundary. A payload already this small is dispatched exactly as the
## world composed it, so an ordinary resident turn keeps every character.
## RunJson embeds this serialized value as JsonContent. OpenGameAgent then estimates
## the complete request, including the escaped JSON representation and its system
## prompt, against the resident runtime's 8192-token window with 512 tokens held
## for output. Keep enough headroom for that second representation as well as the
## unchanged 24 KiB projected-prompt and 32 KiB wire guards in the gateway.
const INPUT_CHARACTER_TARGET := 12000
## The verified identifier for an oversized decision input: the same string the
## provider mapping yields for the upstream cache's own text, so a receipt reads the
## same whether the runtime refused the payload or this adapter refused to send it.
## It is not a new provider code and it changes no accounting.
const INPUT_LIMIT_CODE := "brain_input_too_large"
## First bounding pass: characters kept per free-text narrative value, and how many
## of the newest personal-history entries survive. Every later pass shrinks these.
const BOUND_TEXT_LIMIT := 240
const BOUND_HISTORY_LIMIT := 24
const BOUND_MEMORY_LIMIT := 6
## The caps reach their floors in at most five passes, so this bound is the radius of
## the search, not a retry count: no provider call, request id or controller
## lifecycle is repeated, and each pass recomposes from the world's own view.
const BOUND_SHRINK_STEPS := 8
## How deep inside a retained history entry free text is looked for. The entries the
## world composes are shallow: the event itself, or a decision with its need.
const BOUND_DEPTH_LIMIT := 4
## Free-text narrative keys. A value stored under one of these INSIDE a bounded
## history entry is the only text this adapter may shorten: identifiers, operation
## and request ids, action, model_choice, status, type, seq, elapsed times, place ids
## and recipient lists are always copied verbatim.
const HISTORY_TEXT_KEYS := ["text", "reason", "speech", "note"]
## The only arrays this adapter bounds, newest entries kept: the resident's own life
## events, the record of what they saw, and the decisions they already made. Offered
## aliases with their details, known_rules, blocked options, pending state and every
## current work, property or commitment fact are never bounded, shortened or
## reordered here.
const BOUNDED_HISTORY_KEYS := ["experiences", "observations"]
const BOUNDED_DECISION_KEY := "previous_decisions"
## Marks free text this adapter shortened for dispatch. The canonical save and every
## caller keep the full value, so the model is never handed shortened text that
## silently claims to be the whole of what the world holds.
const BOUND_TRUNCATION_MARKER := "…"
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
		return {"ok": false, "code": SESSION_REQUEST_LIMIT_CODE}
	_requests += 1
	_pending = str(_adapter.call("NewOperationId"))
	var id := _pending
	_result = {}
	var timeline := str(view.get("world_id", "fixture:well-street"))
	# The host save supplies bounded personal memories on EVERY decision. The
	# gateway sends only this view; retaining copies of past views in OGA's
	# transcript wastes context and eventually prevents dispatch. Scope only the
	# adapter transcript to this operation; actor/timeline/world history persist.
	var input := {"sessionId": "decision:" + id, "actorId": view.identity.id,
		"inputId": id, "type": "personal_observation", "timelineId": timeline,
		"tick": world_turn, "payload": {"resident_view": view}}
	var payload := _bounded_input(input, view)
	if payload.is_empty():
		# Even the bounded copy cannot fit the runtime's unchanged guard. Refuse here
		# with the identifier that names exactly this condition instead of handing
		# RunJson a payload the runtime would reject: no provider call is made, no
		# request id is spent, nothing is retried and no accounting row is touched,
		# and the working record is left as an upstream refusal would leave it.
		_result = {"ok": false, "code": INPUT_LIMIT_CODE}
	else:
		_adapter.call("RunJson", payload)
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

func _bounded_input(input: Dictionary, view: Dictionary) -> String:
	## Bound the resident's own text-bearing personal history at the adapter boundary,
	## before the unchanged upstream guard reads the payload, and return the exact JSON
	## to dispatch. A payload that already fits is serialized exactly as the world
	## composed it, so an ordinary turn is unchanged.
	##
	## An oversized payload is re-encoded from a DEEP COPY whose only reductions are
	## the oldest personal-history entries and the length of the free-text values those
	## entries carry. Identity, needs, inventory, offered aliases with their details,
	## known_rules and every current work, property and commitment fact are copied
	## verbatim, so the resident is still offered the same real, accurately described
	## choice. Returns "" when even that bounded copy cannot fit the guard, so the
	## caller refuses locally rather than dispatching an oversized payload.
	var json := JSON.stringify(input)
	var caps := _bound_caps()
	var step := 0
	while _input_units(json) > INPUT_CHARACTER_TARGET and step < BOUND_SHRINK_STEPS:
		var bounded: Dictionary = view.duplicate(true)
		_bound_personal_history(bounded, caps)
		input["payload"]["resident_view"] = bounded
		json = JSON.stringify(input)
		caps = _shrunk_caps(caps)
		step += 1
	if _input_units(json) > INPUT_CHARACTER_CAP:
		return ""
	return json

func _input_units(text: String) -> int:
	## The upstream guard counts UTF-16 code units (.NET String.Length), which is
	## never below Godot's character count, so counting the same way keeps this local
	## bound conservative for text outside the basic multilingual plane.
	var units := 0
	for index in text.length():
		units += 2 if text.unicode_at(index) > 0xFFFF else 1
	return units

func _bound_caps() -> Dictionary:
	return {"text": BOUND_TEXT_LIMIT, "history": BOUND_HISTORY_LIMIT, "memory": BOUND_MEMORY_LIMIT}

func _shrunk_caps(caps: Dictionary) -> Dictionary:
	## Halve the free-text budget and drop the oldest entries again. The floors keep
	## every bounded array non-empty: dropping all memories or all recent experience is
	## never an acceptable way to fit, so the model still sees a personal past.
	return {"text": maxi(int(caps.text) / 2, 48), "history": maxi(int(caps.history) - 4, 4),
		"memory": maxi(int(caps.memory) - 1, 2)}

func _bound_personal_history(view: Dictionary, caps: Dictionary) -> void:
	## Newest-first trim of the resident's own history only: a decision needs the recent
	## past, and the canonical save keeps every entry this dispatched copy omits. Only
	## the entries and their free text are reduced; no key, identifier, status or
	## current commitment is removed, renamed or reordered. `view` is always the deep
	## copy composed in _bounded_input, never the caller's view or the world's state.
	for key in BOUNDED_HISTORY_KEYS:
		if view.get(key) is Array:
			view[key] = _newest_entries(view[key], int(caps.history), int(caps.text))
	var memory: Variant = view.get("memory")
	if memory is Dictionary and memory.get(BOUNDED_DECISION_KEY) is Array:
		memory[BOUNDED_DECISION_KEY] = _newest_entries(memory[BOUNDED_DECISION_KEY], int(caps.memory), int(caps.text))

func _newest_entries(values: Array, entry_limit: int, text_limit: int) -> Array:
	## Keeps the newest entries of an oversized personal-history array, shortening only
	## the free-text narrative each retained entry carries. An array that already fits
	## keeps its order and its entries; only over-long narrative values are shortened.
	var recent: Array = values
	if entry_limit > 0 and values.size() > entry_limit:
		recent = values.slice(values.size() - entry_limit)
	var bounded: Array = []
	for entry in recent:
		if entry is Dictionary:
			_shorten_history_text(entry, text_limit, BOUND_DEPTH_LIMIT)
		bounded.append(entry)
	return bounded

func _shorten_history_text(value: Variant, text_limit: int, depth: int) -> void:
	## Shortens only free-text narrative values, and only inside a bounded history
	## entry: every identifier, operation id, action, model_choice, status, type, time
	## and structural field is copied verbatim, and only the characters past the budget
	## are replaced by an explicit marker. Nothing outside the resident's own history is
	## ever passed here, so no identity field, offered alias, rule text or work fact can
	## be shortened by this adapter. The record is the deep copy's, never the world's.
	if depth <= 0 or text_limit <= 0:
		return
	if value is Dictionary:
		var record: Dictionary = value
		for key in record.keys():
			var child: Variant = record[key]
			if child is String:
				if HISTORY_TEXT_KEYS.has(str(key)) and (child as String).length() > text_limit:
					record[key] = (child as String).substr(0, text_limit) + BOUND_TRUNCATION_MARKER
			elif child is Dictionary or child is Array:
				_shorten_history_text(child, text_limit, depth - 1)
	elif value is Array:
		for item in value:
			if item is Dictionary or item is Array:
				_shorten_history_text(item, text_limit, depth - 1)

func cancel_pending() -> void:
	if not _pending.is_empty():
		_adapter.call("Cancel", _pending)
		_result = {"ok": false, "code": "controller_disconnected"}

func _on_completed(input_id: String, result_json: String) -> void:
	if input_id != _pending:
		return
	var parsed: Variant = JSON.parse_string(result_json)
	var assistant_text_parts: Array = []
	var messages: Array = []
	if parsed is Dictionary and parsed.get("agent", {}) is Dictionary:
		var received_messages: Variant = parsed.agent.get("newMessages", [])
		if received_messages is Array:
			messages = received_messages
	for message in messages:
		if not message is Dictionary or message.get("role") != "Assistant":
			continue
		var content: Variant = message.get("content", [])
		if not content is Array:
			continue
		for part in content:
			if part is Dictionary and part.get("kind") == "text":
				# Keep only actual Assistant text parts. Tool messages, metadata and the
				# provider envelope never enter the durable world reply.
				assistant_text_parts.append(str(part.get("text", "")))
	var received_text := "\n".join(assistant_text_parts)
	var received := {"assistant_text_parts": assistant_text_parts,
		"assistant_text": received_text, "model_returned": not assistant_text_parts.is_empty(),
		"provider_id": _source, "runtime": "OpenGameAgent",
		"fixture": _source != "opengameagent_live"}
	if not parsed is Dictionary or parsed.get("status") != "Completed":
		received["ok"] = false
		received["code"] = "brain_run_failed"
		_result = received
		return
	# Preserve the historical selection semantics: newest Assistant message first, then
	# its text parts in order; a malformed candidate is a hard invalid reply and never
	# falls back to an older Assistant message.
	for message_index in range(messages.size() - 1, -1, -1):
		var message: Variant = messages[message_index]
		if not message is Dictionary or message.get("role") != "Assistant":
			continue
		var content: Variant = message.get("content", [])
		if not content is Array:
			continue
		for part_index in content.size():
			var part: Variant = content[part_index]
			if not part is Dictionary or part.get("kind") != "text":
				continue
			var parser := JSON.new()
			if parser.parse(str(part.get("text", ""))) != OK:
				received["ok"] = false
				received["code"] = "brain_response_invalid"
				_result = received
				return
			var decision: Variant = parser.data
			if decision is Dictionary:
				var routing := _routing_metadata(message)
				if not routing.is_empty():
					# The provider multiplexer authored this bounded receipt metadata;
					# it is not part of the resident decision and never reaches an action.
					received["routing"] = routing
					received["provider_id"] = str(message.get("provider", _source))
					received["response_model"] = str(message.get("responseModel", ""))
				received["ok"] = true
				received["decision"] = decision
				_result = received
				return
	received["ok"] = false
	received["code"] = "brain_response_invalid"
	_result = received

func _routing_metadata(message: Dictionary) -> Dictionary:
	## LocalFirstProvider places routing facts in the model response id because the
	## upstream wire already carries that bounded field. Validate the exact shape
	## before it becomes archive evidence; arbitrary provider text is discarded.
	var raw: Variant = message.get("responseId", "")
	if not raw is String or raw.is_empty() or raw.length() > 2048:
		return {}
	var parsed: Variant = JSON.parse_string(raw)
	var keys := ["source", "router_model", "route", "route_confidence", "router_fallback",
		"router_fallback_reason", "decision_confidence", "cloud_fallback", "fallback_reason",
		"selected_model", "final_model"]
	if not parsed is Dictionary or parsed.keys().size() != keys.size():
		return {}
	for key in keys:
		if not parsed.has(key):
			return {}
	if parsed.source != "localjev" or parsed.route not in ["local_routine", "cloud_social", "cloud_story_critical", "gm_review"]:
		return {}
	for key in ["router_model", "selected_model", "final_model"]:
		if not parsed[key] is String or parsed[key].is_empty() or parsed[key].length() > 128:
			return {}
	for key in ["route_confidence", "decision_confidence"]:
		var value: Variant = parsed[key]
		if value != null and (not (value is int or value is float) or not is_finite(float(value)) or float(value) < 0.0 or float(value) > 1.0):
			return {}
	for key in ["router_fallback", "cloud_fallback"]:
		if not parsed[key] is bool:
			return {}
	for key in ["router_fallback_reason", "fallback_reason"]:
		if parsed[key] != null and (not parsed[key] is String or parsed[key].length() > 128):
			return {}
	return parsed.duplicate(true)

func _on_failed(input_id: String, error: String) -> void:
	if input_id == _pending:
		# Expose only a verified constant, never arbitrary provider text or secrets.
		_result = {"ok": false, "code": provider_failure_identifier(error)}

func provider_failure_identifier(error: String) -> String:
	## Static mapping, no state and no side effect: the same adapter text always yields
	## the same identifier, and any text outside the verified set stays generic. This
	## changes no limit, retry count, replay decision or controller lifecycle.
	return str(PROVIDER_FAILURE_IDENTIFIERS.get(error, GENERIC_PROVIDER_FAILURE_CODE))
