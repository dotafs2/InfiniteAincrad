extends SceneTree
## Offline reconciliation of ONE already-settled town reply the world never applied.
##
## Shape of the reviewed reconciliation (identical shape to the reviewed installers):
##   godot --headless --path game --script res://tools/reconcile_settled_town_reply_cli.gd -- \
##     --town-save=<absolute save path of a COPY> --receipt-file=<absolute receipt path>
##
## The receipt is a private envelope produced by tools/reconcile_settled_town_reply.py from an
## existing SETTLED fee-ledger row. This CLI never contacts a provider, never creates a
## reservation, never chooses a new action and never resets a controller: it re-applies the
## one decision the resident already paid for, through the world's own existing action
## validation and archive. Every refusal returns before any transaction, so a rejected
## receipt leaves the save bytes untouched. The raw model text and the resident's private
## reason are never printed.
class Reconciliation:
	const Town = preload("res://core/town_actions.gd")
	const Turns = preload("res://agents/town_turns.gd")
	const KernelRef = preload("res://core/world_kernel.gd")

	static func run(save_path: String, receipt_path: String) -> Dictionary:
		if save_path.is_empty():
			return {"ok": false, "code": "town_save_required"}
		var loaded := _read_receipt(receipt_path)
		if not loaded.ok:
			return loaded
		var receipt: Dictionary = loaded.receipt
		var source: Dictionary = receipt.source
		var resident := _text(source.get("resident_id", ""))
		var request_id := _text(source.get("request_id", ""))
		var operation := _text(source.get("provider_operation_id", ""))
		var epoch := int(source.get("controller_epoch", 0))
		var source_sha := _text(source.get("source_sha256", "")).to_lower()
		var provider_id := _text(source.get("provider_id", ""))
		var failed_reply: Dictionary = receipt.failure.get("original_failed_reply", {})
		var original_provenance := _original_provenance(failed_reply)
		# The reply carries the provenance the failed turn itself recorded. A receipt may never
		# relabel a live run as a fixture (or the reverse), and a provenance the world does not
		# accept would turn a real decision into a spurious rule rejection.
		if original_provenance.is_empty():
			return {"ok": false, "code": "recovery_provenance_missing", "actor_id": resident}
		if provider_id != original_provenance:
			return {"ok": false, "code": "recovery_provenance_changed", "actor_id": resident}
		if not KernelRef.ALLOWED_DECISION_PROVENANCE.has(original_provenance):
			return {"ok": false, "code": "recovery_provenance_invalid", "actor_id": resident}
		var text := _text(receipt.reply.get("assistant_text", ""))
		if _sha256_text(text) != _text(receipt.reply.get("assistant_text_sha256", "")).to_lower():
			return {"ok": false, "code": "recovery_reply_text_mismatch", "actor_id": resident}
		var parsed_decision: Variant = JSON.parse_string(text)
		if not parsed_decision is Dictionary:
			return {"ok": false, "code": "recovery_decision_invalid", "actor_id": resident}
		var town := Town.new()
		var acquired: Dictionary = town.acquire_writer(save_path)
		if not acquired.ok:
			return acquired
		var result: Dictionary
		# Recheck the exact source bytes AFTER the lock: a hash taken before it could describe
		# a different file than the state this call loads and reconciles.
		var after_lock := FileAccess.get_sha256(save_path)
		if after_lock.is_empty() or after_lock.to_lower() != source_sha:
			result = {"ok": false, "code": "source_hash_changed_since_receipt", "actor_id": resident}
		else:
			result = town.load_from(save_path)
			if result.ok:
				result = _apply(town, save_path, receipt, parsed_decision, resident, request_id, epoch,
					operation, original_provenance, text)
		town.release_writer(save_path)
		return result

	static func _apply(town, save_path: String, receipt: Dictionary, decision: Dictionary, resident: String,
			request_id: String, epoch: int, operation: String, provider_id: String, text: String) -> Dictionary:
		## The reply shape is exactly the shape a live turn builds, so the archived evidence of
		## a reconciled turn is the same evidence an ordinary turn leaves.
		var reply := {"ok": true, "decision": decision, "assistant_text_parts": [text], "assistant_text": text,
			"model_returned": true, "provider_id": provider_id, "runtime": "OpenGameAgent",
			"fixture": provider_id != "opengameagent_live", "command_id": operation,
			"provenance": provider_id}
		var recovery := {"world_id": _text(receipt.source.get("world_id", "")), "resident_id": resident,
			"request_id": request_id, "controller_epoch": epoch, "provider_operation_id": operation,
			"source_sha256": _text(receipt.source.get("source_sha256", "")),
			"ledger_response_sha256": _text(receipt.ledger.get("response_sha256", "")),
			"original_failed_reply": receipt.failure.get("original_failed_reply", {})}
		var turns := Turns.new()
		turns.town = town
		turns.save_path = save_path
		var applied: Dictionary = turns.apply_reply(resident, epoch, request_id, reply, recovery)
		turns.free()
		if not applied.get("ok", false):
			return applied
		applied = applied.duplicate(true)
		applied.source_sha256 = _text(receipt.source.get("source_sha256", "")).to_lower()
		applied.ledger_response_sha256 = _text(receipt.ledger.get("response_sha256", "")).to_lower()
		applied.provider_operation_id = operation
		return applied

	static func _read_receipt(path: String) -> Dictionary:
		if path.is_empty():
			return {"ok": false, "code": "receipt_file_required"}
		if not FileAccess.file_exists(path):
			return {"ok": false, "code": "receipt_file_missing"}
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not parsed is Dictionary:
			return {"ok": false, "code": "receipt_json_invalid"}
		var receipt: Dictionary = parsed
		if int(receipt.get("schema_version", 0)) != 1 or str(receipt.get("kind", "")) != "settled_town_reply_receipt":
			return {"ok": false, "code": "receipt_schema_invalid"}
		for key in ["source", "failure", "archive", "ledger", "reply"]:
			if not receipt.get(key, null) is Dictionary:
				return {"ok": false, "code": "receipt_section_missing:" + key}
		var source: Dictionary = receipt.source
		for key in ["world_id", "source_sha256", "resident_id", "request_id", "provider_operation_id", "provider_id"]:
			if _text(source.get(key, "")).is_empty():
				return {"ok": false, "code": "receipt_source_field_missing:" + key}
		var epoch_value: Variant = source.get("controller_epoch", null)
		if not (epoch_value is int) and not (epoch_value is float):
			return {"ok": false, "code": "receipt_epoch_invalid"}
		if not receipt.failure.get("original_failed_reply", null) is Dictionary:
			return {"ok": false, "code": "receipt_failure_reply_missing"}
		if str(receipt.failure.get("controller_status", "")) != "provider_error":
			return {"ok": false, "code": "receipt_failure_status_invalid"}
		if str(receipt.archive.get("application_status", "")) != "provider_error" or int(receipt.archive.get("replays", -1)) != 0:
			# The extraction step already required this archive state; the CLI refuses to act
			# on a receipt that declares anything else.
			return {"ok": false, "code": "receipt_archive_state_invalid"}
		if _text(receipt.reply.get("assistant_text", "")).is_empty():
			return {"ok": false, "code": "receipt_reply_text_missing"}
		if _text(receipt.reply.get("assistant_text_sha256", "")).is_empty():
			return {"ok": false, "code": "receipt_reply_hash_missing"}
		return {"ok": true, "code": "receipt_read", "receipt": receipt}

	static func _sha256_text(text: String) -> String:
		var context := HashingContext.new()
		context.start(HashingContext.HASH_SHA256)
		context.update(text.to_utf8_buffer())
		return context.finish().hex_encode().to_lower()

	static func _original_provenance(failed_reply: Dictionary) -> String:
		## The provenance the world's own record carries for the failed turn. `provenance` is
		## what the adapter set on the outcome; `provider_id` is the same source value on a
		## receipt written before `provenance` existed. Nothing else may substitute for it.
		var proven := _text(failed_reply.get("provenance", ""))
		if proven.is_empty():
			proven = _text(failed_reply.get("provider_id", ""))
		return proven

	static func _text(value: Variant) -> String:
		if typeof(value) == TYPE_STRING:
			return str(value)
		return ""

	static func summary(result: Dictionary) -> Dictionary:
		## Bounded, private-safe projection: identifiers and hashes only, never the raw model
		## text, a reason, a speech line or a full effect body.
		var out := {"ok": bool(result.get("ok", false)), "code": str(result.get("code", "unknown"))}
		for key in ["actor_id", "duplicate", "source_sha256", "ledger_response_sha256", "provider_operation_id"]:
			if result.has(key):
				out[key] = str(result[key])
		var effect: Variant = result.get("effect", null)
		if effect is Dictionary:
			out.effect_code = str(effect.get("code", ""))
		return out

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var values := {}
	for argument in OS.get_cmdline_user_args():
		for flag in ["town-save", "receipt-file"]:
			if argument.begins_with("--" + flag + "="):
				values[flag] = argument.trim_prefix("--" + flag + "=")
	if not values.has_all(["town-save", "receipt-file"]):
		print(JSON.stringify({"ok": false, "code": "required_flags: --town-save --receipt-file"}))
		quit(2)
		return
	var result: Dictionary = Reconciliation.run(str(values["town-save"]), str(values["receipt-file"]))
	print(JSON.stringify(Reconciliation.summary(result)))
	quit(0 if result.get("ok", false) else 1)
