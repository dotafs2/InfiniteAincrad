"""Read-only food supply/demand accounting for an explicit checkpoint series.

The report deliberately stays outside the game runtime. It reads JSON checkpoints,
does not acquire a world writer, and never writes a source checkpoint. An optional
output path receives a new report document only.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
from collections import Counter
from pathlib import Path
from typing import Any, Iterable


TICK_SECONDS = 120.0
MEAL_SATIETY = 40.0
FORAGING_SECONDS = 450.0
EPSILON = 1e-6


class CheckpointError(ValueError):
    """A checkpoint is missing a field required for an honest report."""


def _finite_number(value: Any, field: str) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise CheckpointError(f"{field} must be a finite number")
    result = float(value)
    if not math.isfinite(result):
        raise CheckpointError(f"{field} must be a finite number")
    return result


def _integer(value: Any, field: str, minimum: int | None = None) -> int:
    number = _finite_number(value, field)
    if number != math.floor(number):
        raise CheckpointError(f"{field} must be an integer")
    result = int(number)
    if minimum is not None and result < minimum:
        raise CheckpointError(f"{field} must be >= {minimum}")
    return result


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _json_bytes(path: Path) -> tuple[dict[str, Any], str]:
    if not path.is_file():
        raise CheckpointError(f"checkpoint does not exist: {path}")
    raw = path.read_bytes()

    def reject_constant(value: str) -> Any:
        raise CheckpointError(f"JSON constant {value} is not finite")

    try:
        value = json.loads(raw.decode("utf-8"), parse_constant=reject_constant)
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise CheckpointError(f"invalid checkpoint JSON: {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise CheckpointError(f"checkpoint root must be an object: {path}")
    return value, hashlib.sha256(raw).hexdigest()


def _event_counts(state: dict[str, Any]) -> Counter[str]:
    events = state.get("life", {}).get("events")
    if not isinstance(events, list):
        raise CheckpointError("life.events must be an array")
    counts: Counter[str] = Counter()
    for index, event in enumerate(events):
        if not isinstance(event, dict):
            raise CheckpointError(f"life.events[{index}] must be an object")
        event_type = event.get("type")
        if isinstance(event_type, str):
            counts[event_type] += 1
    return counts


def _harvest_failures(state: dict[str, Any], active_ids: set[str]) -> dict[str, Any]:
    godot = state.get("godot")
    if not isinstance(godot, dict) or not isinstance(godot.get("commands"), dict):
        raise CheckpointError("godot.commands must be an object")
    by_code: Counter[str] = Counter()
    command_ids: list[str] = []
    for command_id, command in godot["commands"].items():
        if not isinstance(command_id, str) or not isinstance(command, dict):
            raise CheckpointError("godot.commands contains an invalid entry")
        payload = command.get("payload")
        if not isinstance(payload, dict) or payload.get("action") != "harvest_ration":
            continue
        if payload.get("actor_id") not in active_ids:
            raise CheckpointError(f"harvest command has an inactive actor: {command_id}")
        if command.get("status") != "rejected":
            continue
        result = command.get("result", {})
        code = result.get("code", "missing") if isinstance(result, dict) else "missing"
        code = str(code)
        by_code[code] += 1
        command_ids.append(command_id)
    return {"total": len(command_ids), "by_code": dict(sorted(by_code.items())),
            "command_ids": sorted(command_ids)}


def _load(path: Path) -> dict[str, Any]:
    state, sha256 = _json_bytes(path)
    world_id = state.get("world_id")
    if not isinstance(world_id, str) or not world_id:
        raise CheckpointError(f"world_id is missing: {path}")
    elapsed = _finite_number(state.get("elapsed_seconds"), "elapsed_seconds")
    if elapsed < 0:
        raise CheckpointError(f"elapsed_seconds must be non-negative: {path}")
    residents = state.get("residents")
    survival = state.get("survival")
    foraging = state.get("foraging")
    godot = state.get("godot")
    if not isinstance(residents, list) or not isinstance(survival, dict) \
            or not isinstance(foraging, dict) or not isinstance(godot, dict):
        raise CheckpointError(f"checkpoint has invalid core objects: {path}")
    resident_ids: set[str] = set()
    satiety: dict[str, float] = {}
    for index, resident in enumerate(residents):
        if not isinstance(resident, dict) or not isinstance(resident.get("stable_id"), str):
            raise CheckpointError(f"residents[{index}] has no stable_id: {path}")
        resident_id = resident["stable_id"]
        if resident_id in resident_ids:
            raise CheckpointError(f"duplicate resident id: {resident_id}")
        needs = resident.get("needs")
        if not isinstance(needs, dict):
            raise CheckpointError(f"resident needs missing: {resident_id}")
        satiety[resident_id] = _finite_number(needs.get("hunger"), f"needs.hunger[{resident_id}]")
        resident_ids.add(resident_id)
    accounts = survival.get("accounts")
    if not isinstance(accounts, list) or not accounts:
        raise CheckpointError(f"survival.accounts must be a non-empty array: {path}")
    active_ids: set[str] = set()
    held_food = 0
    for index, account in enumerate(accounts):
        if not isinstance(account, dict) or not isinstance(account.get("resident_id"), str):
            raise CheckpointError(f"survival.accounts[{index}] has no resident_id: {path}")
        resident_id = account["resident_id"]
        if resident_id not in resident_ids or resident_id in active_ids:
            raise CheckpointError(f"invalid or duplicate account resident: {resident_id}")
        food = _integer(account.get("food"), f"food[{resident_id}]", 0)
        if food > 2:
            raise CheckpointError(f"food[{resident_id}] exceeds the current capacity")
        active_ids.add(resident_id)
        held_food += food
    remainder = _finite_number(survival.get("tick_remainder_seconds"), "tick_remainder_seconds")
    if remainder < -EPSILON or remainder > TICK_SECONDS + EPSILON:
        raise CheckpointError(f"tick_remainder_seconds is outside the reviewed range: {path}")
    stock = _integer(foraging.get("stock"), "foraging.stock", 0)
    capacity = _integer(foraging.get("capacity"), "foraging.capacity", 0)
    initial_stock = _integer(foraging.get("initial_stock"), "foraging.initial_stock", 0)
    produced = _integer(foraging.get("produced_total"), "foraging.produced_total", 0)
    harvested = _integer(foraging.get("harvested_total"), "foraging.harvested_total", 0)
    growth_remainder = _finite_number(foraging.get("growth_remainder_seconds"), "growth_remainder_seconds")
    if stock > capacity or growth_remainder < -EPSILON:
        raise CheckpointError(f"invalid foraging stock or remainder: {path}")
    foraging_conserved = stock == initial_stock + produced - harvested
    counts = _event_counts(state)
    meals = counts.get("eat_ration", 0)
    life_seq = _integer(state.get("life", {}).get("seq"), "life.seq", 0)
    failed_harvest = _harvest_failures(state, active_ids)
    if not isinstance(godot.get("elapsed_seconds"), (int, float)):
        raise CheckpointError(f"godot.elapsed_seconds is missing: {path}")
    godot_elapsed = _finite_number(godot["elapsed_seconds"], "godot.elapsed_seconds")
    if abs(godot_elapsed - elapsed) > EPSILON:
        raise CheckpointError(f"elapsed clocks disagree: {path}")
    empty_ids = sorted(resident_id for resident_id in active_ids
                       if next(account["food"] for account in accounts if account["resident_id"] == resident_id) == 0)
    return {
        "path": path.resolve().as_posix(),
        "sha256": sha256,
        "state": state,
        "world_id": world_id,
        "life_seq": life_seq,
        "elapsed_seconds": elapsed,
        "tick_remainder_seconds": remainder,
        "active_ids": sorted(active_ids),
        "satiety": satiety,
        "satiety_total": sum(satiety.values()),
        "held_food": held_food,
        "empty_ids": empty_ids,
        "stock": stock,
        "capacity": capacity,
        "initial_stock": initial_stock,
        "produced": produced,
        "harvested": harvested,
        "growth_remainder_seconds": growth_remainder,
        "source_full": stock == capacity,
        "meals": meals,
        "food_conserved_total": held_food + stock + meals - produced,
        "foraging_conserved": foraging_conserved,
        "failed_harvest": failed_harvest,
        "event_counts": dict(sorted(counts.items())),
    }


def _group_records(records: list[dict[str, Any]]) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    selected: list[dict[str, Any]] = []
    variants: list[dict[str, Any]] = []
    for record in sorted(records, key=lambda value: (value["elapsed_seconds"], value["life_seq"], value["path"])):
        if selected and (record["elapsed_seconds"], record["life_seq"]) == \
                (selected[-1]["elapsed_seconds"], selected[-1]["life_seq"]):
            variants.append({"elapsed_seconds": record["elapsed_seconds"], "life_seq": record["life_seq"],
                             "path": record["path"], "sha256": record["sha256"], "selected": False})
            continue
        selected.append(record)
    if variants:
        variants.insert(0, {"elapsed_seconds": selected[0]["elapsed_seconds"], "life_seq": selected[0]["life_seq"],
                             "path": selected[0]["path"], "sha256": selected[0]["sha256"], "selected": True})
        # Rebuild groups so a duplicate at a later sequence is represented too.
        groups: dict[tuple[float, int], list[dict[str, Any]]] = {}
        for record in records:
            groups.setdefault((record["elapsed_seconds"], record["life_seq"]), []).append(record)
        variants = []
        for key, group in sorted(groups.items()):
            if len(group) > 1:
                group = sorted(group, key=lambda value: value["path"])
                variants.append({"elapsed_seconds": key[0], "life_seq": key[1],
                                 "selected": group[0]["path"],
                                 "files": [{"path": item["path"], "sha256": item["sha256"]} for item in group]})
    return selected, variants


def _interval(previous: dict[str, Any], current: dict[str, Any]) -> dict[str, Any]:
    delta = current["elapsed_seconds"] - previous["elapsed_seconds"]
    result: dict[str, Any] = {
        "from": previous["path"], "to": current["path"], "elapsed_seconds": delta,
        "comparable": delta > EPSILON and previous["world_id"] == current["world_id"]
        and previous["active_ids"] == current["active_ids"],
    }
    if not result["comparable"]:
        result["reason"] = "non-positive elapsed delta or changed world/active resident set"
        return result
    tick_input = previous["tick_remainder_seconds"] + delta
    ticks = max(0, math.floor((tick_input + EPSILON) / TICK_SECONDS))
    expected_remainder = tick_input - ticks * TICK_SECONDS
    clock_consistent = abs(expected_remainder - current["tick_remainder_seconds"]) <= 1e-4
    result["ticks"] = ticks
    result["clock_consistent"] = clock_consistent
    if not clock_consistent:
        result["reason"] = "survival tick remainder does not match elapsed interval"
    result["meal_delta"] = current["meals"] - previous["meals"]
    result["produced_delta"] = current["produced"] - previous["produced"]
    result["harvested_delta"] = current["harvested"] - previous["harvested"]
    result["failed_harvest_delta"] = current["failed_harvest"]["total"] - previous["failed_harvest"]["total"]
    result["food_conservation_delta"] = current["food_conserved_total"] - previous["food_conserved_total"]
    result["food_conservation_ok"] = result["food_conservation_delta"] == 0
    satiety_change = previous["satiety_total"] + result["meal_delta"] * MEAL_SATIETY \
        - ticks * len(current["active_ids"]) - current["satiety_total"]
    result["meal_truncation_points"] = round(max(0.0, satiety_change), 6) if satiety_change >= -EPSILON else None
    result["meal_truncation_provable"] = satiety_change >= -EPSILON and clock_consistent
    if not result["meal_truncation_provable"]:
        result["meal_truncation_reason"] = "unknown hunger mutation or inconsistent checkpoint clock"
    result["empty_ids_at_both_endpoints"] = sorted(set(previous["empty_ids"]) & set(current["empty_ids"]))
    result["source_full_at_both_endpoints"] = previous["source_full"] and current["source_full"]
    return result


def build_report(paths: Iterable[Path]) -> dict[str, Any]:
    records = [_load(Path(path)) for path in paths]
    if not records:
        raise CheckpointError("at least one checkpoint is required")
    world_ids = {record["world_id"] for record in records}
    if len(world_ids) != 1:
        raise CheckpointError("checkpoint series contains more than one world_id")
    selected, same_time_variants = _group_records(records)
    intervals = [_interval(previous, current) for previous, current in zip(selected, selected[1:])]
    first = selected[0]
    residents = len(first["active_ids"])
    demand = residents * (3600.0 / TICK_SECONDS) / MEAL_SATIETY
    supply = 3600.0 / FORAGING_SECONDS
    empty_span: dict[str, float] = {resident_id: 0.0 for resident_id in first["active_ids"]}
    full_span = 0.0
    for interval in intervals:
        if interval.get("comparable"):
            for resident_id in interval["empty_ids_at_both_endpoints"]:
                empty_span[resident_id] += interval["elapsed_seconds"]
            if interval["source_full_at_both_endpoints"]:
                full_span += interval["elapsed_seconds"]
    snapshots: list[dict[str, Any]] = []
    for record in selected:
        snapshots.append({key: record[key] for key in [
            "path", "sha256", "world_id", "life_seq", "elapsed_seconds", "tick_remainder_seconds",
            "active_ids", "satiety_total", "held_food", "empty_ids", "stock", "capacity", "initial_stock",
            "produced", "harvested", "growth_remainder_seconds", "source_full", "meals",
            "food_conserved_total", "foraging_conserved", "failed_harvest", "event_counts"]})
    comparable_intervals = [interval for interval in intervals if interval.get("comparable")]
    total_ticks = sum(interval.get("ticks", 0) for interval in comparable_intervals
                      if interval.get("clock_consistent", False))
    provable_truncation = [interval.get("meal_truncation_points") for interval in intervals
                           if interval.get("meal_truncation_provable", False)]
    return {
        "kind": "food_supply_envelope",
        "schema_version": 1,
        "read_only": True,
        "world_id": first["world_id"],
        "source_count": len(records),
        "selected_snapshot_count": len(selected),
        "same_time_variants": same_time_variants,
        "time_window": {
            "from_elapsed_seconds": first["elapsed_seconds"],
            "to_elapsed_seconds": selected[-1]["elapsed_seconds"],
            "elapsed_world_seconds": selected[-1]["elapsed_seconds"] - first["elapsed_seconds"],
            "ticks": total_ticks,
        },
        "snapshots": snapshots,
        "intervals": intervals,
        "conservation": {
            "exact_across_selected_snapshots": len({record["food_conserved_total"] for record in selected}) == 1,
            "conserved_total_values": [record["food_conserved_total"] for record in selected],
            "equation": "held_food + source_stock + completed_meals - produced_total",
            "foraging_exact_at_each_snapshot": all(record["foraging_conserved"] for record in selected),
            "foraging_equation": "source_stock = initial_stock + produced_total - harvested_total",
        },
        "meal_truncation": {
            "provable_interval_points": [interval.get("meal_truncation_points") for interval in intervals],
            "provable_interval_flags": [interval.get("meal_truncation_provable", False) for interval in intervals],
            "total_provable_points": round(sum(provable_truncation), 6),
            "basis": "satiety_before + 40*meals - 1*ticks_per_resident - satiety_after",
        },
        "failed_harvest": {
            "latest_total": selected[-1]["failed_harvest"]["total"],
            "latest_by_code": selected[-1]["failed_harvest"]["by_code"],
            "interval_deltas": [interval.get("failed_harvest_delta") for interval in intervals],
        },
        "sampled_spans": {
            "empty_inventory_seconds_by_resident": {key: round(value, 6) for key, value in empty_span.items()},
            "source_full_seconds": round(full_span, 6),
            "definition": "sum of checkpoint intervals whose endpoints both show the condition",
            "lower_bound_label": "sampled lower bound only; no continuous-state proof between checkpoints",
            "continuous_proof": False,
        },
        "projected_envelope": {
            "assumptions": {
                "active_residents": residents,
                "satiety_decay_per_resident_tick": 1,
                "tick_seconds": TICK_SECONDS,
                "satiety_per_meal_before_cap": MEAL_SATIETY,
                "foraging_seconds_per_unit_below_capacity": FORAGING_SECONDS,
                "ignores_meal_clipping": True,
                "ignores_navigation_decision_latency_and_voluntary_allocation": True,
            },
            "base_demand_rations_per_hour": round(demand, 6),
            "theoretical_supply_rations_per_hour": round(supply, 6),
            "theoretical_margin_rations_per_hour": round(supply - demand, 6),
            "demand_fraction_of_theoretical_supply": round(demand / supply, 6),
        },
    }


def _paths_from_args(args: argparse.Namespace) -> list[Path]:
    paths = [Path(value) for value in (args.checkpoint or [])]
    if args.checkpoint_dir is not None:
        directory = args.checkpoint_dir
        if not directory.is_dir():
            raise CheckpointError(f"checkpoint directory does not exist: {directory}")
        paths.extend(sorted(directory.glob(args.pattern)))
    unique: list[Path] = []
    seen: set[str] = set()
    for path in paths:
        key = str(path.resolve()).lower()
        if key not in seen:
            unique.append(path)
            seen.add(key)
    return unique


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--checkpoint", action="append", help="explicit checkpoint JSON; repeat for a series")
    parser.add_argument("--checkpoint-dir", type=Path, help="directory from which to read matching checkpoints")
    parser.add_argument("--pattern", default="*.world.json", help="checkpoint-dir glob (default: *.world.json)")
    parser.add_argument("--output", type=Path, help="write a new report JSON at this path")
    args = parser.parse_args(argv)
    try:
        report = build_report(_paths_from_args(args))
    except CheckpointError as exc:
        parser.error(str(exc))
    payload = json.dumps(report, ensure_ascii=False, indent=2) + "\n"
    if args.output is not None:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(payload, encoding="utf-8")
    print(json.dumps({"kind": report["kind"], "world_id": report["world_id"],
                      "source_count": report["source_count"],
                      "selected_snapshot_count": report["selected_snapshot_count"],
                      "output": str(args.output.resolve()) if args.output else None,
                      "conservation_exact": report["conservation"]["exact_across_selected_snapshots"]},
                     ensure_ascii=False))
    if args.output is None:
        print(payload, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
