#!/usr/bin/env python3
"""Read the world-owned resident reply archive for one explicitly bound GM.

This is a read-only route.  The host must provide both a save/export path and its expected
world id; there is no default save, workspace-wide search, provider call, or NPC view.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import sys
from pathlib import Path

FULL_DIALOGUE_GMS = {"gm-02", "gm-06"}
GM_IDS = {f"gm-{index:02d}" for index in range(1, 11)}
# These event types are emitted by the authoritative life layer for an actual resident-to-
# resident exchange.  Place learning, travel, eating, and rest events also have text and
# recipient_ids, but are world narration and must not become dialogue merely because they are
# readable by a GM.
DIALOGUE_EVENT_TYPES = {
    "ask_help", "reply_help", "offer_repair",
    "visitor_inquiry", "visitor_question", "visitor_reply", "visitor_answer",
    "offer_trade", "accept_trade", "reject_trade",
}


def _legacy_entries(document: dict) -> list[dict]:
    """Project old accepted_reply/history records without inventing missing model facts."""
    godot = document.get("godot", {})
    turns = godot.get("resident_turns", {}) if isinstance(godot, dict) else {}
    result = []
    if not isinstance(turns, dict):
        return result
    for resident_id, record in sorted(turns.items()):
        if not isinstance(record, dict):
            continue
        reply = record.get("accepted_reply")
        history = record.get("history") if isinstance(record.get("history"), list) else []
        by_request = {str(item.get("command_id")): item for item in history
                      if isinstance(item, dict) and item.get("command_id")}
        if isinstance(reply, dict) and record.get("request_id"):
            request_id = str(record["request_id"])
            decision = reply.get("decision") if isinstance(reply.get("decision"), dict) else {}
            prior = by_request.get(request_id, {})
            result.append({
                "archive_id": request_id, "world_id": document.get("world_id"),
                "resident_id": str(resident_id), "request_id": request_id,
                "provider_id": str(reply.get("provider_id", reply.get("provenance", ""))),
                "model_returned": bool(reply.get("model_returned", False)),
                "assistant_text_parts": copy.deepcopy(reply.get("assistant_text_parts", []))
                if isinstance(reply.get("assistant_text_parts", []), list) else [],
                "assistant_text": str(reply.get("assistant_text", "")),
                "original_reply": copy.deepcopy(reply),
                "reason": str(decision.get("reason", "")),
                "speech": str(decision.get("speech", "")),
                "application": {"status": str(record.get("status", "legacy")),
                                "code": str(prior.get("result", {}).get("code", "legacy"))
                                if isinstance(prior.get("result"), dict) else "legacy",
                                "effect": copy.deepcopy(prior.get("result", {})),
                                "speech_delivery": {"attempted": False, "delivered": False,
                                                     "code": "legacy_incomplete"}},
                "source": "legacy_resident_turn", "complete": False,
                "incomplete_fields": ["provider_id", "assistant_text", "speech_delivery"],
            })
        for item in history:
            if not isinstance(item, dict) or not item.get("command_id"):
                continue
            request_id = str(item["command_id"])
            if isinstance(reply, dict) and request_id == str(record.get("request_id", "")):
                continue
            result.append({"archive_id": request_id, "world_id": document.get("world_id"),
                           "resident_id": str(resident_id), "request_id": request_id,
                           "provider_id": "", "model_returned": False,
                           "assistant_text_parts": [], "assistant_text": "",
                           "original_reply": {}, "reason": str(item.get("reason", "")),
                           "speech": "", "application": {"status": str(item.get("status", "legacy")),
                           "code": str(item.get("result", {}).get("code", "legacy"))
                           if isinstance(item.get("result"), dict) else "legacy",
                           "effect": copy.deepcopy(item.get("result", {})),
                           "speech_delivery": {"attempted": False, "delivered": False,
                                                "code": "legacy_incomplete"}},
                           "source": "legacy_resident_history", "complete": False,
                           "incomplete_fields": ["original_reply", "provider_id", "assistant_text",
                                                 "speech_delivery"]})
    return result


def _life_dialogue_entries(document: dict) -> list[dict]:
    """Project real, delivered dialogue from the world life event stream.

    This is an evidence projection only: it carries the event's actual text and stable IDs and
    never claims that a provider or model supplied text when the event has no such provenance.
    """
    life = document.get("life", {})
    events = life.get("events", []) if isinstance(life, dict) else []
    if not isinstance(events, list):
        return []
    result = []
    for event in events:
        if not isinstance(event, dict):
            continue
        event_id = str(event.get("event_id", ""))
        event_type = str(event.get("type", ""))
        text = event.get("text")
        recipients = event.get("recipient_ids")
        if (not event_id or event_type not in DIALOGUE_EVENT_TYPES
                or not isinstance(text, str) or not text
                or not isinstance(recipients, list) or not recipients):
            continue
        operation_id = str(event.get("operation_id", event.get("request_id", "")))
        result.append({
            "archive_id": event_id,
            "world_id": document.get("world_id"),
            "resident_id": str(event.get("actor_id", "")),
            "request_id": str(event.get("request_id", operation_id)),
            "operation_id": operation_id,
            "provider_id": str(event.get("provider_id", event.get("provenance", ""))),
            "model_returned": False,
            "assistant_text_parts": [],
            "assistant_text": "",
            "original_reply": {},
            "original_event": copy.deepcopy(event),
            "reason": "",
            "speech": text,
            "delivered_text": text,
            "application": {
                "status": "delivered",
                "code": event_type,
                "effect": {"ok": True, "event_type": event_type},
                "speech_delivery": {
                    "attempted": True,
                    "delivered": True,
                    "code": "life_event_dialogue",
                    "text": text,
                    "event_id": event_id,
                    "event_seq": event.get("seq", 0),
                    "operation_id": operation_id,
                    "recipient_ids": copy.deepcopy(recipients),
                },
            },
            "source": "life_event_dialogue",
            "complete": True,
        })
    return result


def _identity_keys(entry: dict) -> set[str]:
    """IDs used to avoid re-projecting one delivered life event twice."""
    keys = set()
    for value in (entry.get("archive_id"), entry.get("event_id"), entry.get("operation_id")):
        if value:
            keys.add(str(value))
    delivery = entry.get("application", {}).get("speech_delivery", {})
    if isinstance(delivery, dict):
        for value in (delivery.get("event_id"), delivery.get("operation_id")):
            if value:
                keys.add(str(value))
    return keys


def _entries(document: dict) -> list[dict]:
    godot = document.get("godot", {})
    archive = godot.get("resident_archive") if isinstance(godot, dict) else None
    if not isinstance(archive, dict) or not isinstance(archive.get("entries"), dict):
        return _life_dialogue_entries(document) + _legacy_entries(document)
    order = archive.get("order", []) if isinstance(archive.get("order"), list) else []
    current = [copy.deepcopy(archive["entries"][key]) for key in order
            if isinstance(key, str) and isinstance(archive["entries"].get(key), dict)]
    known = set().union(*(_identity_keys(entry) for entry in current)) if current else set()
    # The authoritative life stream is older than the resident archive in many saves.  Add its
    # actual dialogue events, while skipping only event/operation IDs already represented by a
    # new delivery reference.  Shared request IDs alone are insufficient: one request has both
    # an ask and a reply and both are valid dialogue events.
    for dialogue in _life_dialogue_entries(document):
        if _identity_keys(dialogue) & known:
            continue
        current.append(dialogue)
        known.update(_identity_keys(dialogue))
    # A new archive is allowed to coexist with pre-archive accepted_reply/history.  Keep those
    # older entries visible and explicitly incomplete until a later turn supplies full facts.
    for legacy in _legacy_entries(document):
        keys = _identity_keys(legacy)
        if keys and not keys & known:
            current.append(legacy)
            known.update(keys)
    return current


def read_memory(state_dir: Path, gm_id: str, cursor: int = 0, limit: int = 8) -> dict:
    """Read one GM's durable runner memory through the same executable route shown in prompts."""
    if gm_id not in GM_IDS:
        raise ValueError(f"unknown gm id: {gm_id}")
    state_dir = state_dir.resolve()
    if not state_dir.is_dir():
        raise ValueError(f"state directory not found: {state_dir}")
    # Import only after resolving the explicit state directory; this CLI never scans for state.
    tools_dir = Path(__file__).resolve().parent
    if str(tools_dir) not in sys.path:
        sys.path.insert(0, str(tools_dir))
    import gm_runner
    state = gm_runner.load_state(state_dir)
    page = gm_runner.read_gm_memory(state, gm_id, cursor, limit)
    page.update({"status": "ok", "state_dir": str(state_dir), "gm_id": gm_id})
    return page


def _delivered(entry: dict) -> bool:
    application = entry.get("application")
    delivery = application.get("speech_delivery") if isinstance(application, dict) else None
    text = entry.get("delivered_text", entry.get("speech", ""))
    return bool(isinstance(delivery, dict) and delivery.get("delivered") is True
                and isinstance(text, str) and text)


def _for_gm(entry: dict, gm_id: str) -> dict | None:
    if gm_id in FULL_DIALOGUE_GMS:
        return entry
    if not _delivered(entry):
        return None
    application = entry.get("application", {})
    delivery = application.get("speech_delivery", {}) if isinstance(application, dict) else {}
    text = entry.get("delivered_text", entry.get("speech", ""))
    return {"archive_id": entry.get("archive_id", entry.get("request_id", "")),
            "world_id": entry.get("world_id"), "resident_id": entry.get("resident_id"),
            "request_id": entry.get("request_id"), "provider_id": entry.get("provider_id", ""),
            "speech": text, "delivery": copy.deepcopy(delivery),
            "application_status": application.get("status", "") if isinstance(application, dict) else ""}


def read_archive(save: Path, world_id: str, gm_id: str, cursor: int = 0, limit: int = 8,
                 source_sha256: str | None = None) -> dict:
    if gm_id not in GM_IDS:
        raise ValueError(f"unknown gm id: {gm_id}")
    if cursor < 0 or limit < 1:
        raise ValueError("cursor must be nonnegative and limit must be positive")
    raw = save.read_bytes()
    actual_sha256 = hashlib.sha256(raw).hexdigest()
    if source_sha256 is not None and source_sha256 != actual_sha256:
        raise ValueError("archive source changed; restart pagination at cursor 0")
    document = json.loads(raw.decode("utf-8-sig"))
    if not isinstance(document, dict) or document.get("world_id") != world_id:
        raise ValueError("save world_id does not match the explicitly supplied world id")
    selected = []
    for entry in _entries(document):
        projected = _for_gm(entry, gm_id)
        if projected is not None:
            selected.append(projected)
    page = selected[cursor:cursor + limit]
    end = cursor + len(page)
    return {"status": "ok", "world_id": world_id, "gm_id": gm_id,
            "permission": "full_dialogue_and_assistant_text" if gm_id in FULL_DIALOGUE_GMS
            else "delivered_dialogue_only", "cursor": cursor, "limit": limit,
            "source_sha256": actual_sha256, "count": len(page), "total_visible": len(selected),
            "next_cursor": end if end < len(selected) else None, "entries": page}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    read = sub.add_parser("read")
    read.add_argument("--save", required=True, type=Path)
    read.add_argument("--world-id", required=True)
    read.add_argument("--gm", required=True)
    read.add_argument("--cursor", type=int, default=0)
    read.add_argument("--limit", type=int, default=8)
    read.add_argument("--source-sha256")
    memory = sub.add_parser("memory")
    memory.add_argument("--state-dir", required=True, type=Path)
    memory.add_argument("--gm", required=True)
    memory.add_argument("--cursor", type=int, default=0)
    memory.add_argument("--limit", type=int, default=8)
    args = parser.parse_args()
    try:
        if args.command == "read":
            if not args.save.is_file():
                raise ValueError(f"save not found: {args.save}")
            payload = read_archive(args.save, args.world_id, args.gm, args.cursor, args.limit,
                                   args.source_sha256)
        else:
            payload = read_memory(args.state_dir, args.gm, args.cursor, args.limit)
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(json.dumps({"status": "error", "message": str(error)}, ensure_ascii=False))
        return 2
    print(json.dumps(payload, ensure_ascii=False, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
