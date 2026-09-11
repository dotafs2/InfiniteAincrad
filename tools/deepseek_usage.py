"""Summarize token usage from explicitly supplied DeepSeek run directories.

Each run directory must contain ``process.json`` and ``events.jsonl`` and normally
``result.md``.  Counters come from Codex ``turn.completed`` ``usage`` records and
each completed turn is counted once.  Only run ids, pids, models, statuses and
integer counters are emitted: event bodies, prompts, result text and credentials
are never read into the output.  Missing usage is reported as unknown, never as
zero.  This tool writes no ledger, estimates no money and keeps no cumulative
session counter; ``raw = input + output`` includes cached input and is not a cost.
"""

import argparse
import json
import sys
from pathlib import Path

USAGE_FIELDS = ("input_tokens", "cached_input_tokens", "cache_write_input_tokens",
                "output_tokens", "reasoning_output_tokens")
FAILURE_EVENT_TYPES = ("turn.failed", "error", "stream_error")
MAX_EVENT_LINES = 200_000


class UsageError(Exception):
    """Raised when a run's recorded usage cannot be trusted; carries no file content."""


def _ratio(part, whole):
    return None if whole <= 0 else round(part / whole, 6)


def validate_usage(usage):
    """Return the five integer counters for one completed turn, or reject the schema."""
    if not isinstance(usage, dict):
        raise UsageError("turn.completed has no usage object")
    keys = set(usage)
    expected = set(USAGE_FIELDS)
    unknown = keys - expected
    missing = expected - keys
    if unknown:
        raise UsageError("unknown usage field(s): " + ", ".join(sorted(unknown)))
    if missing:
        raise UsageError("missing usage field(s): " + ", ".join(sorted(missing)))
    values = {}
    for name in USAGE_FIELDS:
        value = usage[name]
        if isinstance(value, bool) or not isinstance(value, int):
            raise UsageError(name + " is not an integer counter")
        if value < 0:
            raise UsageError(name + " is negative")
        values[name] = value
    if values["cached_input_tokens"] > values["input_tokens"]:
        raise UsageError("cached_input_tokens exceeds input_tokens")
    if values["reasoning_output_tokens"] > values["output_tokens"]:
        raise UsageError("reasoning_output_tokens exceeds output_tokens")
    return values


def read_usage(events_path, max_bytes):
    """Return (turns, failure_count, unparsable_line_count) with a bounded read."""
    size = events_path.stat().st_size
    if size > max_bytes:
        raise UsageError("events.jsonl is %d bytes, above the %d-byte bound" % (size, max_bytes))
    turns, failures, unparsable, lines = [], 0, 0, 0
    with events_path.open("r", encoding="utf-8", errors="replace") as handle:
        for raw in handle:
            lines += 1
            if lines > MAX_EVENT_LINES:
                raise UsageError("events.jsonl exceeds the event-line bound")
            text = raw.strip()
            if not text:
                continue
            try:
                event = json.loads(text)
            except json.JSONDecodeError:
                unparsable += 1
                continue
            if not isinstance(event, dict):
                unparsable += 1
                continue
            kind = event.get("type")
            if kind == "turn.completed":
                turns.append(validate_usage(event.get("usage")))
            elif kind in FAILURE_EVENT_TYPES:
                failures += 1
    return turns, failures, unparsable


def _read_process(record, process_path, max_bytes):
    if not process_path.is_file():
        record["limitations"].append("process.json missing; pid/model unknown")
        return
    try:
        if process_path.stat().st_size > max_bytes:
            record["limitations"].append("process.json above size bound; pid/model unknown")
            return
        meta = json.loads(process_path.read_text(encoding="utf-8", errors="replace"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError):
        record["limitations"].append("process.json unreadable; pid/model unknown")
        return
    if not isinstance(meta, dict):
        record["limitations"].append("process.json is not an object; pid/model unknown")
        return
    pid = meta.get("pid")
    record["pid"] = pid if isinstance(pid, int) and not isinstance(pid, bool) else None
    model = meta.get("model")
    record["model"] = model if isinstance(model, str) else None


def summarize_run(run_dir, max_event_bytes, max_process_bytes=65536):
    """Return (record, counters_or_None) for one explicitly supplied run directory."""
    run_dir = Path(run_dir)
    if not run_dir.is_dir():
        raise UsageError("run directory not found")
    record = {"run_id": run_dir.name, "pid": None, "model": None, "status": None,
              "turn_count": 0, "result_present": (run_dir / "result.md").is_file(),
              "limitations": []}
    _read_process(record, run_dir / "process.json", max_process_bytes)

    events_path = run_dir / "events.jsonl"
    if not events_path.is_file():
        record["status"] = "invalid"
        record["limitations"].append("events.jsonl missing")
        return record, None
    try:
        turns, failures, unparsable = read_usage(events_path, max_event_bytes)
    except UsageError as error:
        record["status"] = "invalid"
        record["limitations"].append(str(error))
        return record, None

    if unparsable:
        record["limitations"].append("%d unparsable event line(s) ignored" % unparsable)
    if failures:
        record["status"] = "failed"
        record["limitations"].append("run reported failure event(s)")
        if turns:
            record["limitations"].append("counters cover completed turns only")
    elif turns:
        record["status"] = "completed"
    else:
        record["status"] = "incomplete"
        record["limitations"].append("no completed turn; usage unknown, not zero")
    if not record["result_present"]:
        record["limitations"].append("result.md missing")

    if not turns:
        return record, None
    totals = {name: sum(turn[name] for turn in turns) for name in USAGE_FIELDS}
    record["turn_count"] = len(turns)
    record.update(totals)
    record["raw_tokens"] = totals["input_tokens"] + totals["output_tokens"]
    record["cache_miss_tokens"] = totals["input_tokens"] - totals["cached_input_tokens"]
    record["weighted_cache_hit"] = _ratio(totals["cached_input_tokens"], totals["input_tokens"])
    counters = dict(totals)
    counters["turn_count"] = len(turns)
    counters["raw_tokens"] = record["raw_tokens"]
    counters["cache_miss_tokens"] = record["cache_miss_tokens"]
    return record, counters


def aggregate(pairs):
    """Total only the runs whose counters are known; keep the other statuses visible."""
    result = {"runs_total": len(pairs), "runs_completed": 0, "runs_failed": 0,
              "runs_incomplete": 0, "runs_invalid": 0, "completed_turns": 0,
              "raw_tokens": 0, "cache_miss_tokens": 0, "weighted_cache_hit": None}
    result.update(dict.fromkeys(USAGE_FIELDS, 0))
    for record, counters in pairs:
        result["runs_" + record["status"]] += 1
        if counters is None:
            continue
        result["completed_turns"] += counters["turn_count"]
        result["raw_tokens"] += counters["raw_tokens"]
        result["cache_miss_tokens"] += counters["cache_miss_tokens"]
        for name in USAGE_FIELDS:
            result[name] += counters[name]
    result["weighted_cache_hit"] = _ratio(result["cached_input_tokens"], result["input_tokens"])
    return result


def build_parser():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run-dir", type=Path, action="append", required=True,
                        help="explicit run directory holding process.json/events.jsonl/result.md; repeat per run")
    parser.add_argument("--max-runs", type=int, default=64,
                        help="reject more than this many supplied run directories")
    parser.add_argument("--max-event-bytes", type=int, default=8 * 1024 * 1024,
                        help="reject a run whose events.jsonl exceeds this size")
    parser.add_argument("--max-process-bytes", type=int, default=65536)
    return parser


def main(argv=None):
    args = build_parser().parse_args(argv)
    if args.max_runs < 1 or args.max_event_bytes < 1 or args.max_process_bytes < 1:
        raise SystemExit("bounds must be positive")
    if len(args.run_dir) > args.max_runs:
        raise SystemExit("%d run directories exceed the %d bound" % (len(args.run_dir), args.max_runs))
    pairs = []
    for run_dir in args.run_dir:
        try:
            pairs.append(summarize_run(run_dir, args.max_event_bytes, args.max_process_bytes))
        except UsageError as error:
            pairs.append(({"run_id": Path(run_dir).name, "pid": None, "model": None,
                           "status": "invalid", "turn_count": 0, "result_present": False,
                           "limitations": [str(error)]}, None))
    payload = {"runs": [record for record, _ in pairs], "aggregate": aggregate(pairs),
               "limitations": [
                   "counters only from completed turns; missing usage is unknown, not zero",
                   "raw = input + output includes cached input; not a cost estimate",
                   "no ledger, money estimate or cumulative session counter is written"]}
    print(json.dumps(payload, indent=2))
    return 3 if any(record["status"] == "invalid" for record, _ in pairs) else 0


if __name__ == "__main__":
    sys.exit(main())
