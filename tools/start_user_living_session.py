"""Interactive, fail-closed bootstrap for one new paid resident-life session.

This entry point is intentionally manual. It has no confirmation flag and is not used
by the overnight runner. A new payment record is created only after the user types the
exact confirmation in an interactive terminal and all earlier records plus the world
writer boundary have been checked.
"""

from datetime import datetime, timedelta, timezone
import argparse
from dataclasses import asdict
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools/kimi"))
from kimi_budget import (BudgetError, CityValidationPolicy, Ledger, NANO, Policy,
                         encoded, fingerprint, usage_cost)
from kimi_gateway import KimiProvider


SESSION_SECONDS = 900
MAX_NEW_DECISIONS = 32
CONCURRENCY = 1
AUTHORIZED_NANO = 3 * NANO
ALLOCATABLE_NANO = 2_850_000_000
WINDOW_SECONDS = 1020
# The existing runner adds a fixed 55-second process/drain margin to its own runtime
# authorization. 900 + 65 + 55 = the approved 1020-second window exactly. The 65
# seconds admit no new decisions; they only let an already-started reply settle and save.
SHUTDOWN_WAIT_SECONDS = 65
CONFIRMATION = "START AI"
REQUIRED_PROFILE_KEYS = {
    "save_path", "godot", "config", "sessions_root", "prior_paid_session_records"
}
OPTIONAL_PROFILE_KEYS = {
    "gm_status", "prior_uncertainty_review_pins", "reviewed_continuation_receipts",
}
REVIEW_PIN_KEYS = {
    "schema_version", "ledger_id", "policy_sha256", "guard_sha256",
    "uncertain_requests",
}
CONTINUATION_KEYS = {"schema_version", "kind", "scope_tag", "status", "old", "new"}
CONTINUATION_OLD_KEYS = {
    "path", "ledger_id", "guard_sha256", "policy_sha256", "halted_reason",
    "liability_nano", "request_count", "requests_sha256", "uncertain_requests",
}
CONTINUATION_NEW_KEYS = {
    "path", "ledger_id", "guard_sha256", "policy_sha256", "policy",
}


class LaunchBlocked(RuntimeError):
    pass


def _read_json(path):
    try:
        return json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise LaunchBlocked(f"Cannot read configuration: {path}") from exc


def _unique_object(pairs):
    value = {}
    for key, item in pairs:
        if key in value:
            raise ValueError("duplicate JSON field")
        value[key] = item
    return value


def _read_review_pin(path):
    try:
        value = json.loads(path.read_text(encoding="utf-8-sig"),
                           object_pairs_hook=_unique_object)
    except (OSError, UnicodeError, ValueError, TypeError) as exc:
        raise LaunchBlocked("Cannot strictly read the prior unknown-request review; no new session was created.") from exc
    if (not isinstance(value, dict) or set(value) != REVIEW_PIN_KEYS
            or type(value.get("schema_version")) is not int
            or value["schema_version"] != 1
            or not isinstance(value.get("ledger_id"), str)
            or not value["ledger_id"]
            or not isinstance(value.get("uncertain_requests"), list)):
        raise LaunchBlocked("The prior unknown-request review has an invalid format; no new session was created.")
    for key in ("policy_sha256", "guard_sha256"):
        if not isinstance(value.get(key), str) or not re.fullmatch(r"[0-9a-f]{64}", value[key]):
            raise LaunchBlocked("The prior unknown-request review has an invalid format; no new session was created.")
    ids = set()
    for row in value["uncertain_requests"]:
        if (not isinstance(row, dict) or set(row) != {"id", "state", "reserve_nano"}
                or not isinstance(row.get("id"), str)
                or not re.fullmatch(r"[A-Za-z0-9_.:-]{1,128}", row["id"])
                or row["id"] in ids or row.get("state") != "uncertain"
                or type(row.get("reserve_nano")) is not int
                or row["reserve_nano"] <= 0):
            raise LaunchBlocked("The prior unknown-request review has an invalid format; no new session was created.")
        ids.add(row["id"])
    return value


def _read_continuation_receipt(path):
    try:
        value = json.loads(path.read_text(encoding="utf-8-sig"),
                           object_pairs_hook=_unique_object)
    except (OSError, UnicodeError, ValueError, TypeError) as exc:
        raise LaunchBlocked("Cannot strictly read the prior closed-period review; no new session was created.") from exc
    if (not isinstance(value, dict) or set(value) != CONTINUATION_KEYS
            or value.get("schema_version") != 1
            or type(value.get("schema_version")) is not int
            or value.get("kind") != "reviewed_night_continuation"
            or value.get("status") != "initialized"
            or not isinstance(value.get("scope_tag"), str)
            or not re.fullmatch(r"[A-Za-z0-9_.:-]{1,128}", value["scope_tag"])
            or not isinstance(value.get("old"), dict)
            or set(value["old"]) != CONTINUATION_OLD_KEYS
            or not isinstance(value.get("new"), dict)
            or set(value["new"]) != CONTINUATION_NEW_KEYS):
        raise LaunchBlocked("The prior closed-period review has an invalid format or status; no new session was created.")
    old, new = value["old"], value["new"]
    for side in (old, new):
        if (not isinstance(side.get("path"), str) or not side["path"].strip()
                or not isinstance(side.get("ledger_id"), str) or not side["ledger_id"]):
            raise LaunchBlocked("Identity fields in the prior closed-period review do not match; no new session was created.")
        for key in ("guard_sha256", "policy_sha256"):
            if not isinstance(side.get(key), str) or not re.fullmatch(r"[0-9a-f]{64}", side[key]):
                raise LaunchBlocked("The prior closed-period review hash does not match; no new session was created.")
    if (old.get("halted_reason") != "closed_for_continuation:" + value["scope_tag"]
            or type(old.get("liability_nano")) is not int or old["liability_nano"] < 0
            or type(old.get("request_count")) is not int or old["request_count"] < 0
            or not isinstance(old.get("requests_sha256"), str)
            or not re.fullmatch(r"[0-9a-f]{64}", old["requests_sha256"])
            or not isinstance(old.get("uncertain_requests"), list)
            or not isinstance(new.get("policy"), dict)):
        raise LaunchBlocked("Accounting fields in the prior closed-period review do not match; no new session was created.")
    ids = set()
    for row in old["uncertain_requests"]:
        if (not isinstance(row, dict) or set(row) != {"id", "state", "reserve_nano"}
                or not isinstance(row.get("id"), str)
                or not re.fullmatch(r"[A-Za-z0-9_.:-]{1,128}", row["id"])
                or row["id"] in ids or row.get("state") != "uncertain"
                or type(row.get("reserve_nano")) is not int
                or row["reserve_nano"] <= 0):
            raise LaunchBlocked("Unknown-request fields in the prior closed-period review do not match; no new session was created.")
        ids.add(row["id"])
    return value


def _resolve(value):
    path = Path(value)
    return path.resolve() if path.is_absolute() else (ROOT / path).resolve()


def load_profile(path):
    data = _read_json(path)
    keys = set(data) if isinstance(data, dict) else set()
    if (not isinstance(data, dict) or not REQUIRED_PROFILE_KEYS.issubset(keys)
            or keys - REQUIRED_PROFILE_KEYS - OPTIONAL_PROFILE_KEYS):
        raise LaunchBlocked("Local configuration fields are missing or unknown. Copy the example again.")
    records = data["prior_paid_session_records"]
    if not isinstance(records, list) or not records or any(not isinstance(item, str) or not item.strip() for item in records):
        raise LaunchBlocked("List the prior paid-session records that must be checked.")
    for key in ("save_path", "godot", "config", "sessions_root"):
        if not isinstance(data[key], str) or not data[key].strip():
            raise LaunchBlocked(f"Local configuration field {key} must be a nonempty path.")
    result = {key: _resolve(data[key]) for key in ("save_path", "godot", "config", "sessions_root")}
    result["prior_paid_session_records"] = [_resolve(item) for item in records]
    pins = data.get("prior_uncertainty_review_pins", [])
    if (not isinstance(pins, list)
            or any(not isinstance(item, str) or not item.strip() for item in pins)):
        raise LaunchBlocked("prior_uncertainty_review_pins must be a list of review-file paths.")
    result["prior_uncertainty_review_pins"] = [_resolve(item) for item in pins]
    receipts = data.get("reviewed_continuation_receipts", [])
    if (not isinstance(receipts, list)
            or any(not isinstance(item, dict) or set(item) != {"record", "receipt"}
                   or not isinstance(item["record"], str) or not item["record"].strip()
                   or not isinstance(item["receipt"], str) or not item["receipt"].strip()
                   for item in receipts)):
        raise LaunchBlocked("reviewed_continuation_receipts must be a list of record/receipt paths.")
    result["reviewed_continuation_receipts"] = [
        {"record": _resolve(item["record"]), "receipt": _resolve(item["receipt"])}
        for item in receipts
    ]
    if "gm_status" in data:
        if not isinstance(data["gm_status"], str) or not data["gm_status"].strip():
            raise LaunchBlocked("Local configuration gm_status must be a nonempty path.")
        result["gm_status"] = _resolve(data["gm_status"])
    return result


def _policy_from_guard(record):
    guard_path = record.with_suffix(".guard.json")
    if not record.is_file() or not guard_path.is_file():
        raise LaunchBlocked("A prior paid-session record is missing its paired file. Launch refused to prevent duplicate billing.")
    guard = _read_json(guard_path)
    try:
        return _policy_from_values(guard["policy"])
    except (KeyError, TypeError) as exc:
        raise LaunchBlocked("A prior paid-session record has an unknown format. Launch refused to prevent duplicate billing.") from exc


def _policy_from_values(values):
    policy_type = CityValidationPolicy if "request_limit" in values else Policy
    return policy_type(**values)


def _load_review_pins(paths):
    pins = {}
    for path in paths:
        pin = _read_review_pin(path)
        ledger_id = pin["ledger_id"]
        if ledger_id in pins:
            raise LaunchBlocked("Multiple unknown-request reviews refer to the same prior paid session; no new session was created.")
        pins[ledger_id] = pin
    return pins


def _load_continuation_receipts(links):
    receipts = {}
    for link in links:
        record = link["record"].resolve()
        if record in receipts:
            raise LaunchBlocked("Multiple closed-period reviews refer to the same prior paid session; no new session was created.")
        receipt = _read_continuation_receipt(link["receipt"])
        old_path, new_path = Path(receipt["old"]["path"]), Path(receipt["new"]["path"])
        if (not old_path.is_absolute() or not new_path.is_absolute()
                or old_path.resolve() != record or new_path.resolve() == record):
            raise LaunchBlocked("The prior closed-period review path binding does not match; no new session was created.")
        receipts[record] = receipt
    return receipts


def _reviewed_rows(session):
    with session.transaction() as (db, meta):
        rows = [dict(row) for row in db.execute("SELECT * FROM requests ORDER BY id")]
        meta = dict(meta)
    if any(row["state"] == "reserved" for row in rows):
        raise LaunchBlocked("A prior paid session still has requests in progress; no new session was created.")
    for row in rows:
        maximum = row["maximum"]
        if type(maximum) is not int or not 1 <= maximum <= session.policy.max_output:
            raise LaunchBlocked("Cannot verify a prior paid session's request limit; no new session was created.")
        expected_reserve = (session.policy.input_ceiling * session.policy.input_nano_per_token
                            + maximum * session.policy.output_nano_per_token)
        if row["reserve"] != expected_reserve:
            raise LaunchBlocked("Cannot verify a prior paid session's maximum liability; no new session was created.")
        if row["state"] == "settled":
            try:
                response = json.loads(row["response"])
                cost, prompt, output, cached = usage_cost(response, maximum, session.policy)
            except (BudgetError, ValueError, TypeError) as exc:
                raise LaunchBlocked("Cannot verify a prior paid session's settlement receipts; no new session was created.") from exc
            if (cost != row["charge"] or prompt != row["prompt_tokens"]
                    or output != row["output_tokens"] or cached != row["cached_tokens"]
                    or cost > row["reserve"] or fingerprint(response) != row["response_sha"]):
                raise LaunchBlocked("Cannot verify a prior paid session's settlement receipts; no new session was created.")
        elif row["state"] == "uncertain":
            if any(row[key] is not None for key in (
                    "charge", "prompt_tokens", "output_tokens", "cached_tokens",
                    "response", "response_sha", "finished")):
                raise LaunchBlocked("A prior unknown request contains unverifiable settlement facts; no new session was created.")
        else:
            raise LaunchBlocked("A prior paid session contains an unknown request status; no new session was created.")
    return meta, rows


def _validate_continuation_receipt(record, session, meta, rows, receipt, all_records):
    uncertain = [{"id": row["id"], "state": "uncertain", "reserve_nano": row["reserve"]}
                 for row in rows if row["state"] == "uncertain"]
    old_guard_hash = hashlib.sha256(session.guard.read_bytes()).hexdigest()
    old_expected = {
        "path": receipt["old"]["path"],
        "ledger_id": meta["ledger_id"],
        "guard_sha256": old_guard_hash,
        "policy_sha256": session.policy_hash,
        "halted_reason": "closed_for_continuation:" + receipt["scope_tag"],
        "liability_nano": meta["liability"],
        "request_count": meta["request_count"],
        "requests_sha256": hashlib.sha256(encoded(rows).encode("utf-8")).hexdigest(),
        "uncertain_requests": uncertain,
    }
    if (Path(receipt["old"]["path"]).resolve() != record.resolve()
            or receipt["old"] != old_expected
            or meta.get("halted") != old_expected["halted_reason"]):
        raise LaunchBlocked("The prior closed-period review does not exactly match the old ledger; no new session was created.")
    old_policy = asdict(session.policy)
    if "request_limit" not in old_policy:
        raise LaunchBlocked("The old ledger has no request limit that can be conservatively reduced; no new session was created.")
    remaining_concurrency = session.policy.concurrency - len(uncertain)
    remaining_requests = session.policy.request_limit - meta["request_count"]
    if remaining_concurrency <= 0 or remaining_requests <= 0:
        raise LaunchBlocked("The old ledger has no concurrency or request allowance to carry forward; no new session was created.")
    expected_policy = dict(old_policy)
    expected_policy.update(
        prior_unverified_nano=meta["liability"],
        concurrency=remaining_concurrency,
        request_limit=remaining_requests,
    )
    new_path = Path(receipt["new"]["path"]).resolve()
    if new_path not in all_records or not new_path.is_file():
        raise LaunchBlocked("The new ledger does not fully include prior paid sessions; no new session was created.")
    new_guard_path = new_path.with_suffix(".guard.json")
    new_guard = _read_json(new_guard_path)
    try:
        new_policy = _policy_from_values(receipt["new"]["policy"])
    except (KeyError, TypeError) as exc:
        raise LaunchBlocked("Cannot verify the new ledger policy; no new session was created.") from exc
    new_session = Ledger(new_path, new_policy)
    expected_new = {
        "path": receipt["new"]["path"],
        "ledger_id": new_guard.get("ledger_id"),
        "guard_sha256": hashlib.sha256(new_guard_path.read_bytes()).hexdigest(),
        "policy_sha256": new_session.policy_hash,
        "policy": expected_policy,
    }
    if (Path(receipt["new"]["path"]).resolve() != new_path
            or receipt["new"] != expected_new
            or new_guard.get("policy") != expected_policy
            or new_guard.get("policy_sha256") != new_session.policy_hash):
        raise LaunchBlocked("The closed-period review does not exactly match the new ledger policy; no new session was created.")
    try:
        with new_session.transaction() as (_db, new_meta):
            if new_meta["ledger_id"] != receipt["new"]["ledger_id"]:
                raise LaunchBlocked("The closed-period review does not match the new ledger identity; no new session was created.")
    except BudgetError as exc:
        raise LaunchBlocked("Cannot verify the new ledger referenced by the closed-period review; no new session was created.") from exc
    return receipt


def audit_paid_record(record, pins, receipts, all_records):
    try:
        session = Ledger(record, _policy_from_guard(record))
        meta, rows = _reviewed_rows(session)
    except (BudgetError, OSError, ValueError, KeyError, TypeError) as exc:
        raise LaunchBlocked("Cannot fully verify prior paid-session records. Launch refused to prevent duplicate billing.") from exc
    continuation = None
    receipt = receipts.pop(record.resolve(), None)
    if meta.get("halted"):
        if receipt is None:
            raise LaunchBlocked("A prior paid session is stopped. Review it manually first; no new session was created.")
        continuation = _validate_continuation_receipt(
            record, session, meta, rows, receipt, all_records)
    elif receipt is not None:
        raise LaunchBlocked("The old ledger referenced by the closed-period review is not closed; no new session was created.")
    uncertain = [{"id": row["id"], "state": "uncertain", "reserve_nano": row["reserve"]}
                 for row in rows if row["state"] == "uncertain"]
    expected_review = {
        "schema_version": 1,
        "ledger_id": meta["ledger_id"],
        "policy_sha256": session.policy_hash,
        "guard_sha256": hashlib.sha256(session.guard.read_bytes()).hexdigest(),
        "uncertain_requests": uncertain,
    }
    pin = pins.pop(meta["ledger_id"], None)
    if uncertain and pin is None:
        raise LaunchBlocked("A prior paid session still has requests in progress or unknown outcomes; no new session was created.")
    if pin is not None:
        ordered = dict(pin, uncertain_requests=sorted(pin["uncertain_requests"], key=lambda row: row["id"]))
        if ordered != expected_review:
            raise LaunchBlocked("The unknown-request review does not exactly match the prior paid session; no new session was created.")
    settled_nano = sum(row["charge"] for row in rows if row["state"] == "settled")
    uncertain_nano = sum(row["reserve"] for row in rows if row["state"] == "uncertain")
    return {
        "record": str(record),
        "id": meta["ledger_id"],
        "settled_cny": settled_nano / NANO,
        "liability_cny": meta["liability"] / NANO,
        "requests": len(rows),
        "uncertain_requests": len(uncertain),
        "retained_uncertain_cny": uncertain_nano / NANO,
        "uncertainty_review": expected_review if pin is not None else None,
        "continuation_review": continuation,
    }


def _record_for_guard(guard):
    stem = guard.name[:-len(".guard.json")]
    return guard.with_name(stem + ".sqlite3")


def discover_session_records(sessions_root):
    if not sessions_root.exists():
        return []
    if not sessions_root.is_dir():
        raise LaunchBlocked("The new session path is not a directory. Launch refused.")
    for session_dir in sessions_root.glob("session-*"):
        if (not session_dir.is_dir()
                or not (session_dir / "kimi-user-session.sqlite3").is_file()
                or not (session_dir / "kimi-user-session.guard.json").is_file()):
            raise LaunchBlocked("The historical session directory contains unfinished or unpaired records. Launch refused.")
    records = set(sessions_root.rglob("*.sqlite3"))
    guards = set(sessions_root.rglob("*.guard.json"))
    for record in records:
        if not record.with_suffix(".guard.json").is_file():
            raise LaunchBlocked("The historical session directory contains unpaired records. Launch refused.")
    for guard in guards:
        if not _record_for_guard(guard).is_file():
            raise LaunchBlocked("The historical session directory contains unpaired records. Launch refused.")
    return sorted(records)


def audit_all(profile):
    records = set(profile["prior_paid_session_records"])
    records.update(discover_session_records(profile["sessions_root"]))
    records = {record.resolve() for record in records}
    pins = _load_review_pins(profile["prior_uncertainty_review_pins"])
    receipts = _load_continuation_receipts(profile["reviewed_continuation_receipts"])
    if any(record not in records for record in receipts):
        raise LaunchBlocked("A closed-period review matches none of the listed prior paid sessions; no new session was created.")
    result = [audit_paid_record(record, pins, receipts, records) for record in sorted(records)]
    if pins:
        raise LaunchBlocked("An unknown-request review matches none of the listed prior paid sessions; no new session was created.")
    if receipts:
        raise LaunchBlocked("A closed-period review did not complete every ledger check; no new session was created.")
    return result


def _require_file(path, label):
    if not path.is_file():
        raise LaunchBlocked(f"{label} does not exist: {path}")


def validate_local_inputs(profile):
    _require_file(profile["save_path"], "World save")
    _require_file(profile["godot"], "Godot")
    _require_file(profile["config"], "AI configuration")
    game = (ROOT / "game").resolve()
    for path in (profile["save_path"], profile["sessions_root"]):
        if path == game or game in path.parents:
            raise LaunchBlocked("Private worlds and session records must stay outside the exportable game directory.")
    config = _read_json(profile["config"])
    if not isinstance(config, dict):
        raise LaunchBlocked("Invalid AI configuration format.")
    try:
        KimiProvider(config)
    except BudgetError as exc:
        raise LaunchBlocked("The AI configuration did not pass the existing provider and model boundary checks.") from exc


def _writer_lock(save):
    return Path(str(save) + ".writer-lock")


def ensure_world_idle(save):
    if _writer_lock(save).exists():
        raise LaunchBlocked("Another process is writing the world. No new paid session was created. End the current life run normally first.")


def new_policy(deadline_utc):
    # Prices and per-request ceilings match the reviewed overnight Kimi authorization.
    return CityValidationPolicy(
        authorized_nano=AUTHORIZED_NANO,
        allocatable_nano=ALLOCATABLE_NANO,
        prior_unverified_nano=0,
        input_nano_per_token=6500,
        cached_nano_per_token=1100,
        output_nano_per_token=27000,
        input_ceiling=32768,
        max_output=512,
        max_request_bytes=32768,
        max_context_utf8_bytes=24576,
        concurrency=CONCURRENCY,
        deadline_utc=deadline_utc,
        price_verified="2026-09-18 https://platform.kimi.com/ K2.6 China",
        request_limit=MAX_NEW_DECISIONS,
    )


def _write_json(path, value):
    temporary = path.with_name(path.name + ".tmp")
    with temporary.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(value, handle, ensure_ascii=False, indent=2, sort_keys=True)
        handle.write("\n")
        handle.flush()
        os.fsync(handle.fileno())
    os.replace(temporary, path)


def _session_directory(sessions_root, now):
    base = now.strftime("session-%Y%m%d-%H%M%S-%fZ")
    path = sessions_root / base
    path.mkdir(exist_ok=False)
    return path


def _runner_command(profile, record, output):
    command = [
        sys.executable, "-X", "utf8", str(ROOT / "tools/run_town_model_validation.py"),
        "--godot", str(profile["godot"]),
        "--ledger", str(record),
        "--config", str(profile["config"]),
        "--save", str(profile["save_path"]),
        "--out", str(output),
        "--seconds", str(SESSION_SECONDS),
        "--max-requests", str(MAX_NEW_DECISIONS),
        "--concurrency", str(CONCURRENCY),
        "--shutdown-wait", str(SHUTDOWN_WAIT_SECONDS),
    ]
    if "gm_status" in profile:
        command += ["--gm-status", str(profile["gm_status"])]
    return command


def _say(stream, message=""):
    print(message, file=stream, flush=True)


def _read_runner_summary(output):
    try:
        value = json.loads((output / "result.json").read_text(encoding="utf-8"))
        return value if isinstance(value, dict) else {}
    except (OSError, UnicodeError, json.JSONDecodeError):
        return {}


def _is_healthy_idle_summary(value, runner_exit_code):
    """Accept only the runner's strict, non-passing saved-idle classification."""
    if (not isinstance(value, dict) or value.get("idle_completed") is not True
            or value.get("validation_status") != "not_exercised"
            or value.get("validation_passed") is not False
            or value.get("validation_exercised") is not False
            or value.get("engine_exit") != 0
            or value.get("upstream_requests") != 0
            or value.get("model_errors") != {}
            or value.get("budget_stop_reason")
            or value.get("shutdown_incomplete") is not False
            or value.get("world_progress_observed") is not True
            or runner_exit_code != 1):
        return False
    gateway = value.get("gateway_shutdown")
    startup = value.get("startup_fault_export")
    return (isinstance(gateway, dict) and gateway.get("drained_complete") is True
            and gateway.get("unresolved_workers", 0) == 0
            and isinstance(startup, dict) and startup.get("status") == "not_applicable"
            and startup.get("reason") == "healthy_idle_progress")


def launch(profile_path, input_stream=sys.stdin, output_stream=sys.stdout,
           run_process=subprocess.run, now_fn=None):
    profile = load_profile(profile_path)
    _say(output_stream, "Start live AI life (one new session)")
    _say(output_stream, "Run time: 900 seconds; at most 32 new decisions; 1 request at a time.")
    _say(output_stream, "After 900 seconds, stop accepting new decisions and allow up to 65 seconds for in-flight replies to finish and save.")
    _say(output_stream, "Session budget at the published rates: CNY 3.00; request allowance: CNY 2.85. Stop at the time or cost limit, whichever comes first.")
    _say(output_stream, "Reported costs are local estimates based on response usage. The provider's invoice is authoritative.")
    _say(output_stream, "This does not replenish, reset or extend any existing session.")
    _say(output_stream, f"To confirm, type exactly this in the interactive window: {CONFIRMATION}")
    if not input_stream.isatty():
        raise LaunchBlocked("Manual confirmation in an interactive terminal is required. Pipes and automated tasks cannot start live AI.")
    answer = input_stream.readline().rstrip("\r\n")
    if answer != CONFIRMATION:
        _say(output_stream, "Cancelled. No new paid session was created and live AI was not started.")
        return 0

    validate_local_inputs(profile)
    prior = audit_all(profile)
    ensure_world_idle(profile["save_path"])

    sessions_root = profile["sessions_root"]
    sessions_root.mkdir(parents=True, exist_ok=True)
    bootstrap_lock = sessions_root / ".start-living-ai.lock"
    try:
        bootstrap_lock.mkdir()
    except FileExistsError as exc:
        raise LaunchBlocked("Another live AI launch is in progress; no new session was created.") from exc

    try:
        # Re-check after owning the bootstrap boundary. Another manual bootstrap cannot
        # pass this point, and an already-running world is still rejected before first use.
        prior = audit_all(profile)
        ensure_world_idle(profile["save_path"])
        retained_uncertain_cny = round(sum(
            item["retained_uncertain_cny"] for item in prior), 9)
        _say(output_stream, "Maximum liability retained for prior unknown requests: CNY %.6f; old requests will not be cleared or retried." % (
            retained_uncertain_cny,))
        now = now_fn() if now_fn else datetime.now(timezone.utc)
        if now.tzinfo is None:
            now = now.replace(tzinfo=timezone.utc)
        now = now.astimezone(timezone.utc)
        deadline = now + timedelta(seconds=WINDOW_SECONDS)
        session_dir = _session_directory(sessions_root, now)
        record = session_dir / "kimi-user-session.sqlite3"
        session = Ledger(record, new_policy(int(deadline.timestamp())))
        status = session.initialize()
        manifest_path = session_dir / "session.json"
        manifest = {
            "schema_version": 1,
            "status": "starting",
            "created_at_utc": now.isoformat(),
            "deadline_utc": deadline.isoformat(),
            "limits": {
                "seconds": SESSION_SECONDS,
                "max_new_decisions": MAX_NEW_DECISIONS,
                "concurrency": CONCURRENCY,
                "authorized_cny": AUTHORIZED_NANO / NANO,
                "allocatable_cny": ALLOCATABLE_NANO / NANO,
            },
            "prior_paid_sessions": prior,
            "cumulative_settled_before_cny": round(sum(item["settled_cny"] for item in prior), 9),
            # A reviewed continuation carries the old liability into its new ledger.
            # Exclude the closed source here so the same liability is not reported twice.
            "cumulative_prior_liability_cny": round(sum(
                item["liability_cny"] for item in prior
                if item["continuation_review"] is None), 9),
            "retained_prior_uncertain_cny": retained_uncertain_cny,
            "current": {"id": status["ledger_id"], "settled_cny": 0.0, "requests": 0},
        }
        _write_json(manifest_path, manifest)
        _say(output_stream, "Checks passed. Opening live AI life for ten residents...")
        try:
            run_output = session_dir / "run"
            result = run_process(_runner_command(profile, record, run_output), cwd=ROOT)
            return_code = int(result.returncode)
            runner_summary = _read_runner_summary(run_output)
            idle_completed = _is_healthy_idle_summary(runner_summary, return_code)
            final = session.status()
            manifest["status"] = "complete" if return_code == 0 else "not_exercised" if idle_completed else "runner_failed"
            manifest["runner_exit_code"] = return_code
            manifest["idle_completed"] = idle_completed
            manifest["current"] = {
                "id": final["ledger_id"],
                "settled_cny": final["settled_cny"],
                "requests": sum(final.get("counts", {}).values()),
                "in_progress": final.get("counts", {}).get("reserved", 0),
                "unknown": final.get("counts", {}).get("uncertain", 0),
                "stopped": bool(final.get("halted")),
            }
            manifest["cumulative_settled_after_cny"] = round(
                manifest["cumulative_settled_before_cny"] + final["settled_cny"], 9)
            _write_json(manifest_path, manifest)
        except Exception:
            manifest["status"] = "bootstrap_error"
            _write_json(manifest_path, manifest)
            raise
        _say(output_stream, "New requests: %d; local cost estimate: CNY %.6f (subject to the provider's invoice)." % (
            manifest["current"]["requests"], manifest["current"]["settled_cny"]))
        if idle_completed:
            _say(output_stream, "No new AI decisions occurred in this run. The world is saved. Model validation remains not exercised, not passed.")
        elif return_code == 0:
            _say(output_stream, "This live AI run ended normally and its records are saved.")
        else:
            _say(output_stream, "The run did not end normally. Records are retained and no automatic retry will occur. Review them first.")
        return 0 if idle_completed else return_code
    finally:
        bootstrap_lock.rmdir()


def main(argv=None):
    parser = argparse.ArgumentParser(description="Manually start one live AI session with explicit time and cost limits.")
    parser.add_argument(
        "--profile", type=Path,
        default=ROOT / "private/night-delivery/start-living-ai.local.json",
        help="Local path configuration (default: private/night-delivery/start-living-ai.local.json)",
    )
    args = parser.parse_args(argv)
    try:
        return launch(args.profile.resolve())
    except LaunchBlocked as exc:
        print(f"Cannot start: {exc}", file=sys.stderr)
        return 2
    except (BudgetError, OSError, ValueError) as exc:
        print("Cannot start: paid-session initialization or execution failed. No automatic retry. Review the private records.", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
