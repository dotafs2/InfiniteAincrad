#!/usr/bin/env python3
"""One bounded, proposal-only local Smith dialogue probe.

This runner consumes exactly one exported smith_reply fixture and makes at most
one pinned loopback Ollama request. Raw model content is retained verbatim for
the Godot receipt/review authority; this client never executes a proposal.
"""
from __future__ import annotations

import argparse
import importlib.util
import json
import time
from pathlib import Path
from typing import Any, Callable

_SPEC = importlib.util.spec_from_file_location("local_npc_probe", Path(__file__).with_name("probe_local_npc_dialogue.py"))
assert _SPEC and _SPEC.loader
_BASE = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(_BASE)

ENDPOINT = _BASE.ENDPOINT
MODEL = _BASE.MODEL
TIMEOUT_SECONDS = 45
MAX_OUTPUT_TOKENS = 384
VALID_INTENTS = {"ask", "offer", "refuse", "warn", "agree", "disclose", "greet", "leave"}
_http_call = _BASE._http_call


def _validate_input(doc: Any) -> list[dict[str, Any]]:
    if not isinstance(doc, dict) or doc.get("fixture_only") is not True or not isinstance(doc.get("cases"), list):
        raise ValueError("input must be fixture_only with cases")
    cases = doc["cases"]
    if len(cases) != 1:
        raise ValueError("smith reply trial requires exactly one case")
    case = cases[0]
    if not isinstance(case, dict) or case.get("case_id") != "smith_reply":
        raise ValueError("case_id must be smith_reply")
    if case.get("resident_id") != "shared:smith":
        raise ValueError("resident_id must be shared:smith")
    context = case.get("context")
    options = case.get("options")
    if not isinstance(context, dict) or not isinstance(options, list) or not options:
        raise ValueError("smith_reply requires context and options")
    for key in ("target_ids", "claim_ids", "action_ids"):
        values = context.get(key)
        if not isinstance(values, list) or any(not isinstance(value, str) or not value for value in values):
            raise ValueError(f"invalid {key}")
        if len(set(values)) != len(values):
            raise ValueError(f"duplicate {key}")
    aliases: list[str] = []
    for option in options:
        if not isinstance(option, dict) or not isinstance(option.get("alias"), str) or not option["alias"]:
            raise ValueError("invalid option alias")
        if not isinstance(option.get("action_id"), str) or not option["action_id"]:
            raise ValueError("invalid option action_id")
        expected = option.get("expected_intents")
        if not isinstance(expected, list) or any(intent not in VALID_INTENTS for intent in expected):
            raise ValueError("invalid authoritative expected_intents")
        aliases.append(option["alias"])
    if len(set(aliases)) != len(aliases):
        raise ValueError("duplicate option alias")
    if set(aliases) != set(context["action_ids"]):
        raise ValueError("option aliases must equal context.action_ids")
    return [case]


def _prompt(case: dict[str, Any]) -> str:
    context = case["context"]
    options = [{"alias": item["alias"], "action_id": item["action_id"], "description": item.get("description", ""), "expected_intents": item["expected_intents"]} for item in case["options"]]
    return (
        "You are Flint, a fictional smith replying in first person in a bounded offline fixture. "
        "Choose exactly one currently available option and describe that chosen action in your spoken line. "
        "Do not force acceptance: offer, ask, agree, refuse, or another listed intent may be correct for the chosen option. "
        "For an option with nonempty expected_intents, your declared intent MUST be one listed value. An empty expected_intents list means the current review policy has no mapping: you may propose the option without inventing a mapping, but it will require review and must not be treated as accepted. "
        "Do not invent history, claims, items, payment, or results. "
        "Return only one JSON object with exactly the DialogueReceipt fields speech,intent,stance,target_id,claim_ids,stakes,next_action,confidence and optional private_thought. "
        "intent must be ask|offer|refuse|warn|agree|disclose|greet|leave; stance must be warm|guarded|curious|firm|uncertain; confidence is a JSON number 0..1. "
        "speech <=512 characters, stakes <=256 characters, optional private_thought <=512 characters; claim_ids is an array and target_id/next_action use only supplied allowlists.\n"
        f"Visible observation: {json.dumps(case.get('observation', {}), ensure_ascii=False, separators=(',', ':'))}\n"
        f"Allowed targets: {json.dumps(context['target_ids'], separators=(',', ':'))}\n"
        f"Visible claim IDs: {json.dumps(context['claim_ids'], separators=(',', ':'))}\n"
        f"Currently available options and authoritative expected intents: {json.dumps(options, ensure_ascii=False, separators=(',', ':'))}"
    )


def probe_case(case: dict[str, Any], call: Callable[[dict[str, Any], int], tuple[int, bytes, dict[str, str]]] | None = None) -> dict[str, Any]:
    started = time.perf_counter()
    record: dict[str, Any] = {"case_id": "smith_reply", "model": MODEL, "raw_content": None, "parse": None, "http_status": None, "input_tokens": None, "output_tokens": None, "latency_ms": None}
    body = {"model": MODEL, "messages": [{"role": "user", "content": _prompt(case)}], "stream": False, "think": False, "format": "json", "options": {"num_predict": MAX_OUTPUT_TOKENS}}
    try:
        status, raw_bytes, _headers = (call or (lambda payload, timeout: _http_call(payload, timeout)))(body, TIMEOUT_SECONDS)
        record["http_status"] = status
        payload = json.loads(raw_bytes.decode("utf-8"))
        message = payload.get("message", {}) if isinstance(payload, dict) else {}
        raw_content = message.get("content") if isinstance(message, dict) else None
        record["raw_content"] = raw_content
        record["input_tokens"], record["output_tokens"] = payload.get("prompt_eval_count"), payload.get("eval_count")
        if status < 200 or status >= 300:
            record["parse"] = {"ok": False, "code": "http_error", "detail": status}
        elif not isinstance(raw_content, str):
            record["parse"] = {"ok": False, "code": "missing_raw_content"}
        else:
            try:
                candidate = json.loads(raw_content)
            except json.JSONDecodeError:
                record["parse"] = {"ok": False, "code": "malformed_receipt_json"}
            else:
                record["parse"] = {"ok": None, "code": "json_object_ready_for_godot", "godot_validator": "DialogueReceipt.parse"} if isinstance(candidate, dict) else {"ok": False, "code": "receipt_must_be_json_object"}
    except Exception as exc:
        record["error"] = type(exc).__name__ + ": " + str(exc)
        record["parse"] = {"ok": False, "code": "request_failed"}
    record["latency_ms"] = round((time.perf_counter() - started) * 1000, 3)
    return record


def main() -> int:
    parser = argparse.ArgumentParser(description="One local Smith reply proposal; no execution.")
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    try:
        cases = _validate_input(json.loads(args.input.read_text(encoding="utf-8")))
        args.output.parent.mkdir(parents=True, exist_ok=True)
        with args.output.open("x", encoding="utf-8") as sink:
            row = probe_case(cases[0])
            result = {"fixture_only": True, "model": MODEL, "endpoint": ENDPOINT, "status": "complete", "cases": [row], "paid_calls": 0, "world_writes": 0}
            sink.write(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
            sink.flush()
        return 0
    except Exception as exc:
        print(json.dumps({"ok": False, "error": str(exc)}))
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
