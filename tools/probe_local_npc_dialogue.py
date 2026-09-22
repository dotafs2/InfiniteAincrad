#!/usr/bin/env python3
"""Bounded loopback-only local NPC dialogue probe.

The probe consumes an exporter fixture, calls Ollama once per case, and writes raw
assistant content for separate Godot receipt validation. It never executes proposals,
writes a world, retries, or falls back to another service.
"""
from __future__ import annotations

import argparse
import json
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any, Callable

ENDPOINT = "http://127.0.0.1:11434/api/chat"
MODEL = "qwen3:8b"
MAX_CASES = 3
TIMEOUT_SECONDS = 45
MAX_OUTPUT_TOKENS = 384


def _loopback_url(url: str) -> bool:
    return url == ENDPOINT


def _validate_input(doc: Any) -> list[dict[str, Any]]:
    if not isinstance(doc, dict) or doc.get("fixture_only") is not True or not isinstance(doc.get("cases"), list):
        raise ValueError("input must be fixture_only with cases")
    cases = doc["cases"]
    if not 1 <= len(cases) <= MAX_CASES:
        raise ValueError("at most three cases are allowed")
    seen_case_ids: set[str] = set()
    for case in cases:
        if not isinstance(case, dict) or not isinstance(case.get("case_id"), str):
            raise ValueError("each case needs a case_id")
        if case["case_id"] in seen_case_ids:
            raise ValueError(f"duplicate case_id: {case['case_id']}")
        seen_case_ids.add(case["case_id"])
        context = case.get("context")
        options = case.get("options")
        if not isinstance(context, dict) or not isinstance(options, list):
            raise ValueError(f"{case.get('case_id')}: missing context/options")
        for key in ("target_ids", "claim_ids", "action_ids"):
            if not isinstance(context.get(key), list) or any(not isinstance(x, str) for x in context[key]):
                raise ValueError(f"{case.get('case_id')}: invalid {key}")
            if len(set(context[key])) != len(context[key]):
                raise ValueError(f"{case.get('case_id')}: duplicate {key}")
        aliases = [x.get("alias") for x in options if isinstance(x, dict)]
        if not options or any(not isinstance(x, dict) or not isinstance(x.get("alias"), str) for x in options):
            raise ValueError(f"{case.get('case_id')}: invalid options")
        if len(set(aliases)) != len(aliases):
            raise ValueError(f"{case.get('case_id')}: duplicate option alias")
        if set(aliases) != set(context["action_ids"]):
            raise ValueError(f"{case.get('case_id')}: option aliases must equal context.action_ids")
    return cases


def _prompt(case: dict[str, Any]) -> str:
    context = case["context"]
    options = [{"alias": x["alias"], "description": x.get("description", "")} for x in case["options"]]
    observation = case.get("observation", {})
    return (
        "You are a fictional town resident in a bounded offline fixture. Return only one JSON object "
        "with exactly the dialogue receipt fields speech,intent,stance,target_id,claim_ids,stakes,next_action,confidence "
        "and optional private_thought. Use only visible claims and exact action aliases. Do not invent history, "
        "skills, items, relationships, or results. intent must be ask|offer|refuse|warn|agree|disclose|greet|leave; "
        "stance must be warm|guarded|curious|firm|uncertain; confidence must be a JSON number from 0 to 1; "
        "claim_ids must be an array and target_id/next_action must use the supplied allowlists. speech must be <=512 characters, "
        "stakes must be a string <=256 characters, and optional private_thought must be <=512 characters. Keep speech to one or two English sentences.\n"
        f"Visible observation: {json.dumps(observation, ensure_ascii=False, separators=(',', ':'))}\n"
        f"Allowed targets: {json.dumps(context['target_ids'], separators=(',', ':'))}\n"
        f"Visible claim IDs: {json.dumps(context['claim_ids'], separators=(',', ':'))}\n"
        f"Exact offered options: {json.dumps(options, ensure_ascii=False, separators=(',', ':'))}"
    )


def _http_call(body: dict[str, Any], timeout: int = TIMEOUT_SECONDS) -> tuple[int, bytes, dict[str, str]]:
    if not _loopback_url(ENDPOINT):
        raise ValueError("endpoint is not the pinned loopback Ollama URL")
    request = urllib.request.Request(ENDPOINT, data=json.dumps(body, ensure_ascii=False).encode("utf-8"), headers={"Content-Type": "application/json"}, method="POST")
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), _NoRedirect())
    with opener.open(request, timeout=timeout) as response:
        return int(response.status), response.read(), dict(response.headers.items())


class _NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req: Any, fp: Any, code: int, msg: str, headers: Any, newurl: str) -> None:
        raise urllib.error.HTTPError(req.full_url, code, "redirect disabled", headers, fp)


def probe_cases(cases: list[dict[str, Any]], call: Callable[[dict[str, Any]], tuple[int, bytes, dict[str, str]]] = _http_call, on_record: Callable[[list[dict[str, Any]]], None] | None = None) -> dict[str, Any]:
    results: list[dict[str, Any]] = []
    for case in cases[:MAX_CASES]:
        started = time.perf_counter()
        record: dict[str, Any] = {"case_id": case["case_id"], "model": MODEL, "raw_content": None, "parse": None, "http_status": None, "input_tokens": None, "output_tokens": None, "latency_ms": None}
        body = {"model": MODEL, "messages": [{"role": "user", "content": _prompt(case)}], "stream": False, "think": False, "format": "json", "options": {"num_predict": MAX_OUTPUT_TOKENS}}
        try:
            status, raw_bytes, _headers = call(body)
            record["http_status"] = status
            payload = json.loads(raw_bytes.decode("utf-8"))
            message = payload.get("message", {}) if isinstance(payload, dict) else {}
            raw_content = message.get("content") if isinstance(message, dict) else None
            record["raw_content"] = raw_content
            usage = payload.get("prompt_eval_count"), payload.get("eval_count")
            record["input_tokens"], record["output_tokens"] = usage
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
        results.append(record)
        if on_record is not None:
            on_record(results)
    return {"fixture_only": True, "model": MODEL, "endpoint": ENDPOINT, "cases": results, "paid_calls": 0, "world_writes": 0}


def main() -> int:
    parser = argparse.ArgumentParser(description="Probe local Ollama NPC dialogue; proposal-only.")
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    try:
        doc = json.loads(args.input.read_text(encoding="utf-8"))
        cases = _validate_input(doc)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        with args.output.open("x", encoding="utf-8") as sink:
            def write_partial(rows: list[dict[str, Any]]) -> None:
                sink.seek(0)
                sink.truncate()
                sink.write(json.dumps({"fixture_only": True, "model": MODEL, "endpoint": ENDPOINT, "status": "running", "cases": rows, "paid_calls": 0, "world_writes": 0}, ensure_ascii=False, indent=2) + "\n")
                sink.flush()
            result = probe_cases(cases, on_record=write_partial)
            result["status"] = "complete"
            sink.seek(0)
            sink.truncate()
            sink.write(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
            sink.flush()
        return 0
    except Exception as exc:
        print(json.dumps({"ok": False, "error": str(exc)}))
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
