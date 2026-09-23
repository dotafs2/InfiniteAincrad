"""Read-only food, fullness and pending-food continuity audit for immutable checkpoints.

Inputs must be named in a checkpoint manifest. This script validates the full world
history and resident archive lineage with world_observation before comparing endpoints.
It never opens a writer lock, changes a checkpoint, advances the world or calls a model.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
from typing import Any, Iterable

from world_observation import assert_continuation, decode, validate_world

FOOD_EVENTS = {"eat_ration", "harvest_ration", "food_handed_over", "bread_baked"}
PENDING_FOOD_ACTIONS = {"eat_ration", "harvest_ration"}
PENDING_BAKING_ACTIONS = {"bake_bread"}
FULLNESS_FIELD = "needs.hunger (legacy name; 0 empty, 100 full)"
EPSILON = 1e-6


class AuditError(ValueError):
    """Input is not a complete, manifested, continuous immutable checkpoint series."""


def _number(value: Any, label: str) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value):
        raise AuditError(f"{label} must be finite numeric data")
    return float(value)


def _integer(value: Any, label: str) -> int:
    result = _number(value, label)
    if result != math.floor(result) or result < 0:
        raise AuditError(f"{label} must be a non-negative integer")
    return int(result)


def _sha(raw: bytes) -> str:
    return hashlib.sha256(raw).hexdigest()


def _manifest_entries(manifest_path: Path) -> tuple[dict[str, Any], dict[str, dict[str, Any]]]:
    try:
        manifest = decode(manifest_path.read_bytes())
    except (OSError, ValueError) as exc:
        raise AuditError(f"checkpoint manifest is unreadable or invalid: {exc}") from exc
    if manifest.get("schema_version") != 1 or not isinstance(manifest.get("world_id"), str):
        raise AuditError("expected a schema-1 world checkpoint manifest")
    rows = manifest.get("checkpoints")
    if not isinstance(rows, list) or not rows:
        raise AuditError("checkpoint manifest has no checkpoint list")
    entries: dict[str, dict[str, Any]] = {}
    for row in rows:
        if not isinstance(row, dict):
            raise AuditError("checkpoint manifest contains an invalid row")
        name, digest = row.get("file"), row.get("sha256")
        if not isinstance(name, str) or Path(name).name != name or "/" in name or "\\" in name:
            raise AuditError("checkpoint manifest contains an unsafe filename")
        if name in entries or not isinstance(digest, str) or len(digest) != 64:
            raise AuditError("checkpoint manifest has a duplicate file or invalid digest")
        entries[name] = row
    return manifest, entries


def _load_exact(path: Path, manifest_path: Path, manifest: dict[str, Any],
                entries: dict[str, dict[str, Any]]) -> tuple[dict[str, Any], str]:
    path = path.resolve()
    root = manifest_path.resolve().parent
    if path.parent != root:
        raise AuditError(f"checkpoint must be beside its manifest: {path.name}")
    row = entries.get(path.name)
    if row is None:
        raise AuditError(f"checkpoint is not named in its manifest: {path.name}")
    try:
        raw = path.read_bytes()
        sha = _sha(raw)
        if sha != row.get("sha256"):
            raise AuditError(f"checkpoint checksum does not match manifest: {path.name}")
        world = validate_world(decode(raw))
    except (OSError, ValueError) as exc:
        if isinstance(exc, AuditError):
            raise
        raise AuditError(f"checkpoint is invalid: {path.name}: {exc}") from exc
    if world["world_id"] != manifest["world_id"]:
        raise AuditError(f"checkpoint world_id differs from manifest: {path.name}")
    if world["life"]["seq"] != row.get("seq"):
        raise AuditError(f"checkpoint sequence differs from manifest: {path.name}")
    if len(world["residents"]) != row.get("resident_count"):
        raise AuditError(f"checkpoint resident count differs from manifest: {path.name}")
    archive_count = len(world["godot"].get("resident_archive", {}).get("order", []))
    if archive_count != row.get("archive_count") or row.get("full_history_preserved") is not True:
        raise AuditError(f"checkpoint history metadata differs from manifest: {path.name}")
    return world, sha


def _pending_food(state: dict[str, Any]) -> list[dict[str, Any]]:
    godot = state.get("godot", {})
    pending = godot.get("pending", {})
    if not isinstance(pending, dict):
        raise AuditError("godot.pending must be an object")
    jobs: list[dict[str, Any]] = []
    for resident_id, job in pending.items():
        if not isinstance(job, dict):
            raise AuditError("godot.pending contains an invalid job")
        action = str(job.get("action", ""))
        if action in PENDING_FOOD_ACTIONS:
            jobs.append({"resident_id": resident_id, "action": action,
                         "elapsed_seconds": _number(job.get("elapsed", 0), "pending food job elapsed"),
                         "command_id": str(job.get("command_id", ""))})
    baking = godot.get("baking", {})
    if not isinstance(baking, dict):
        raise AuditError("godot.baking must be an object when present")
    baking_jobs = baking.get("jobs", {})
    if not isinstance(baking_jobs, dict):
        raise AuditError("godot.baking.jobs must be an object")
    for resident_id, job in baking_jobs.items():
        if not isinstance(job, dict):
            raise AuditError("godot.baking.jobs contains an invalid job")
        action = str(job.get("action", ""))
        if action in PENDING_BAKING_ACTIONS:
            jobs.append({"resident_id": resident_id, "action": action,
                         "elapsed_seconds": _number(job.get("elapsed", 0), "pending baking job elapsed"),
                         "reserved_flour": _integer(job.get("reserved_flour", 0), "reserved flour"),
                         "command_id": str(job.get("command_id", ""))})
    return sorted(jobs, key=lambda job: (job["resident_id"], job["action"], job["command_id"]))


def _snapshot(world: dict[str, Any], path: Path, sha: str) -> dict[str, Any]:
    resident_ids = [resident["stable_id"] for resident in world["residents"]]
    accounts = world.get("survival", {}).get("accounts")
    if not isinstance(accounts, list):
        raise AuditError("survival.accounts must be an array")
    by_id: dict[str, dict[str, Any]] = {}
    for account in accounts:
        resident_id = account.get("resident_id") if isinstance(account, dict) else None
        if resident_id not in resident_ids or resident_id in by_id:
            raise AuditError("survival.accounts contains a missing or duplicate resident")
        by_id[resident_id] = account
    if set(by_id) != set(resident_ids):
        raise AuditError("survival.accounts do not cover every resident")
    residents: dict[str, dict[str, Any]] = {}
    for resident in world["residents"]:
        resident_id = resident["stable_id"]
        needs = resident.get("needs", {})
        residents[resident_id] = {
            "name": str(resident.get("name", resident_id)),
            "food": _integer(by_id[resident_id].get("food"), f"food[{resident_id}]"),
            "fullness": _number(needs.get("hunger"), f"{FULLNESS_FIELD}[{resident_id}]"),
            "energy": _number(by_id[resident_id].get("energy"), f"energy[{resident_id}]"),
        }
    foraging = world.get("foraging", {})
    if not isinstance(foraging, dict):
        raise AuditError("foraging must be an object")
    stock = _integer(foraging.get("stock"), "foraging.stock")
    initial = _integer(foraging.get("initial_stock"), "foraging.initial_stock")
    produced = _integer(foraging.get("produced_total"), "foraging.produced_total")
    harvested = _integer(foraging.get("harvested_total"), "foraging.harvested_total")
    if stock != initial + produced - harvested:
        raise AuditError("foraging stock does not conserve against produced and harvested totals")
    events = world["life"]["events"]
    eaten = 0
    baked = 0
    gifts = 0
    flows = {resident_id: {"harvested": 0, "baked": 0, "eaten": 0,
                           "given": 0, "received": 0} for resident_id in resident_ids}
    for event in events:
        event_type = event.get("type")
        if event_type == "eat_ration":
            actor = event.get("actor_id")
            if actor not in flows:
                raise AuditError("eat_ration event names an inactive resident")
            eaten += 1
            flows[actor]["eaten"] += 1
        elif event_type == "harvest_ration":
            actor = event.get("actor_id")
            if actor not in flows:
                raise AuditError("harvest_ration event names an inactive resident")
            flows[actor]["harvested"] += 1
        elif event_type == "bread_baked":
            actor = event.get("actor_id")
            quantity = _integer(event.get("quantity", 1), "bread_baked.quantity")
            if actor not in flows:
                raise AuditError("bread_baked event names an inactive resident")
            baked += quantity
            flows[actor]["baked"] += quantity
        elif event_type == "food_handed_over":
            donor, receiver = event.get("actor_id"), event.get("subject_id")
            quantity = _integer(event.get("quantity", 1), "food_handed_over.quantity")
            if donor not in flows or receiver not in flows or donor == receiver or quantity < 1:
                raise AuditError("food handoff has invalid participants or quantity")
            gifts += quantity
            flows[donor]["given"] += quantity
            flows[receiver]["received"] += quantity
    if sum(flow["harvested"] for flow in flows.values()) != harvested:
        raise AuditError("harvest event history does not match foraging.harvested_total")
    baking = world.get("godot", {}).get("baking", {})
    ledgers = baking.get("ledgers", {}) if isinstance(baking, dict) else {}
    if not isinstance(ledgers, dict):
        raise AuditError("godot.baking.ledgers must be an object")
    loaf_carry: dict[str, dict[str, int]] = {}
    for point in ledgers.values():
        if not isinstance(point, dict):
            raise AuditError("baking loaf ledger contains an invalid point")
        for resident_id, ledger in point.items():
            if resident_id not in residents or not isinstance(ledger, dict):
                raise AuditError("baking loaf ledger names an invalid resident")
            current = loaf_carry.setdefault(resident_id, {"held": 0, "eaten": 0})
            current["held"] += _integer(ledger.get("held", 0), "baking held loaves")
            current["eaten"] += _integer(ledger.get("eaten", 0), "baking eaten loaves")
    held_food = sum(item["food"] for item in residents.values())
    conservation_total = held_food + stock + eaten - produced - baked
    return {
        "path": path.resolve().as_posix(), "sha256": sha, "world_id": world["world_id"],
        "life_seq": world["life"]["seq"], "elapsed_seconds": _number(world.get("elapsed_seconds"), "elapsed_seconds"),
        "residents": residents, "held_food": held_food,
        "foraging": {"stock": stock, "capacity": _integer(foraging.get("capacity"), "foraging.capacity"),
                      "initial_stock": initial, "produced_total": produced, "harvested_total": harvested},
        "food_events": {"eaten": eaten, "baked": baked, "given": gifts},
        "per_resident_food_flows": flows, "food_conservation_total": conservation_total,
        "food_conservation_equation": "held food + foraging stock + eaten - foraging produced - bread baked",
        "foraging_conservation_ok": True, "baking_loaf_carry": loaf_carry,
        "pending_food_jobs": _pending_food(world),
    }


def audit_checkpoints(manifest_path: Path, checkpoint_paths: Iterable[Path]) -> dict[str, Any]:
    manifest_path = Path(manifest_path).resolve()
    manifest, entries = _manifest_entries(manifest_path)
    paths = [Path(path).resolve() for path in checkpoint_paths]
    if not paths:
        raise AuditError("at least two exact checkpoints are required")
    if len({path.name for path in paths}) != len(paths):
        raise AuditError("duplicate checkpoint input")
    loaded = []
    for path in paths:
        world, sha = _load_exact(path, manifest_path, manifest, entries)
        loaded.append((world, _snapshot(world, path, sha)))
    loaded.sort(key=lambda row: (row[0]["elapsed_seconds"], row[0]["life"]["seq"]))
    if len(loaded) < 2:
        raise AuditError("at least two checkpoints are required for continuity")
    for (previous, _), (current, _) in zip(loaded, loaded[1:]):
        if current["elapsed_seconds"] <= previous["elapsed_seconds"]:
            raise AuditError("checkpoint elapsed time must increase strictly")
        if current["life"]["seq"] < previous["life"]["seq"]:
            raise AuditError("checkpoint life sequence moved backwards")
        try:
            assert_continuation(previous, current)
        except ValueError as exc:
            raise AuditError(f"world history or resident archive continuity failed: {exc}") from exc
    snapshots = [summary for _, summary in loaded]
    intervals = []
    empty_endpoint_seconds = {resident_id: 0.0 for resident_id in snapshots[0]["residents"]}
    zero_fullness_endpoint_seconds = {resident_id: 0.0 for resident_id in snapshots[0]["residents"]}
    for previous, current in zip(snapshots, snapshots[1:]):
        delta = current["elapsed_seconds"] - previous["elapsed_seconds"]
        ids = sorted(set(previous["residents"]) & set(current["residents"]))
        if set(previous["residents"]) != set(current["residents"]):
            raise AuditError("resident set changed across selected checkpoints")
        events = next(world["life"]["events"] for world, summary in loaded if summary is current)
        old_seq = previous["life_seq"]
        new_events = [event for event in events if int(event["seq"]) > old_seq]
        event_counts = {event_type: 0 for event_type in FOOD_EVENTS}
        interval_flows = {resident_id: {"harvested": 0, "baked": 0, "eaten": 0,
                                        "given": 0, "received": 0} for resident_id in ids}
        for event in new_events:
            event_type = event.get("type")
            if event_type not in FOOD_EVENTS:
                continue
            event_counts[event_type] += _integer(event.get("quantity", 1), f"{event_type}.quantity") if event_type in ("bread_baked", "food_handed_over") else 1
            if event_type in ("harvest_ration", "bread_baked", "eat_ration"):
                interval_flows[str(event.get("actor_id"))][{"harvest_ration": "harvested", "bread_baked": "baked", "eat_ration": "eaten"}[event_type]] += 1 if event_type != "bread_baked" else _integer(event.get("quantity", 1), "bread_baked.quantity")
            elif event_type == "food_handed_over":
                qty = _integer(event.get("quantity", 1), "food_handed_over.quantity")
                interval_flows[str(event.get("actor_id"))]["given"] += qty
                interval_flows[str(event.get("subject_id"))]["received"] += qty
        forage_delta = current["foraging"]["produced_total"] - previous["foraging"]["produced_total"]
        harvested_delta = current["foraging"]["harvested_total"] - previous["foraging"]["harvested_total"]
        baked_delta = event_counts["bread_baked"]
        eaten_delta = event_counts["eat_ration"]
        given_delta = event_counts["food_handed_over"]
        held_delta = current["held_food"] - previous["held_food"]
        source_delta = current["foraging"]["stock"] - previous["foraging"]["stock"]
        conservation_delta = current["food_conservation_total"] - previous["food_conservation_total"]
        per_resident = {}
        per_resident_food_balances_match = True
        for resident_id in ids:
            before = previous["residents"][resident_id]
            after = current["residents"][resident_id]
            flow = interval_flows[resident_id]
            expected_delta = flow["harvested"] + flow["baked"] + flow["received"] - flow["eaten"] - flow["given"]
            actual_delta = after["food"] - before["food"]
            per_resident[resident_id] = {"food_before": before["food"], "food_after": after["food"],
                "food_delta": actual_delta, "expected_food_delta": expected_delta,
                "food_balance_residual": actual_delta - expected_delta,
                "fullness_before": before["fullness"], "fullness_after": after["fullness"],
                "energy_before": before["energy"], "energy_after": after["energy"], **flow}
            if actual_delta != expected_delta:
                per_resident_food_balances_match = False
            if before["food"] == 0 and after["food"] == 0:
                empty_endpoint_seconds[resident_id] += delta
            if before["fullness"] == 0 and after["fullness"] == 0:
                zero_fullness_endpoint_seconds[resident_id] += delta
        intervals.append({"from_seq": previous["life_seq"], "to_seq": current["life_seq"],
            "elapsed_seconds": delta, "foraging_produced_delta": forage_delta,
            "foraging_harvested_delta": harvested_delta, "harvest_events": event_counts["harvest_ration"],
            "bread_baked_delta": baked_delta, "eaten_delta": eaten_delta,
            "given_delta": given_delta, "food_held_delta": held_delta, "source_stock_delta": source_delta,
            "food_conservation_delta": conservation_delta,
            "food_conservation_ok": conservation_delta == 0 and source_delta == forage_delta - harvested_delta,
            "per_resident_food_balances_match": per_resident_food_balances_match,
            "harvest_counter_matches_events": harvested_delta == event_counts["harvest_ration"],
            "per_resident": per_resident,
            "sparse_endpoint_limitation": "endpoint matches do not establish continuous empty inventory or continuous zero fullness"})
    # Use the existing envelope for its reviewed theoretical supply/demand projection.
    from food_supply_envelope import build_report as build_envelope
    envelope = build_envelope(paths)
    return {"kind": "town_resource_continuity_audit", "schema_version": 1,
        "read_only": True, "lineage_validated_by": "world_observation.assert_continuation",
        "world_id": manifest["world_id"], "full_history_validated": True,
        "checkpoint_count": len(snapshots), "snapshots": snapshots, "intervals": intervals,
        "totals": {"food_conserved_across_snapshots": len({s["food_conservation_total"] for s in snapshots}) == 1,
            "per_resident_food_balances_match_each_interval": all(
                interval["per_resident_food_balances_match"] for interval in intervals),
            "food_conservation_values": [s["food_conservation_total"] for s in snapshots],
            "foraging_conserved_at_each_snapshot": all(s["foraging_conservation_ok"] for s in snapshots),
            "equation": snapshots[0]["food_conservation_equation"],
            "produced_by_source": {"foraging": snapshots[-1]["foraging"]["produced_total"],
                                   "bread": snapshots[-1]["food_events"]["baked"]},
            "harvested": snapshots[-1]["foraging"]["harvested_total"],
            "eaten": snapshots[-1]["food_events"]["eaten"],
            "given": snapshots[-1]["food_events"]["given"]},
        "sparse_observation": {"zero_food_endpoint_match_seconds_by_resident": empty_endpoint_seconds,
            "zero_fullness_endpoint_match_seconds_by_resident": zero_fullness_endpoint_seconds,
            "continuous_starvation_proven": False,
            "continuous_starvation_lower_bound_seconds_by_resident": {key: 0.0 for key in empty_endpoint_seconds},
            "fullness_field": FULLNESS_FIELD,
            "limitation": "sparse checkpoint endpoints cannot prove continuous starvation or meal clipping"},
        "theoretical_envelope": envelope["projected_envelope"]}


def write_fresh(output: Path, report: dict[str, Any], sources: Iterable[Path]) -> None:
    destination = Path(output).resolve()
    if destination in {Path(path).resolve() for path in sources}:
        raise AuditError("output cannot replace a checkpoint input")
    destination.parent.mkdir(parents=True, exist_ok=True)
    try:
        with destination.open("x", encoding="utf-8") as handle:
            json.dump(report, handle, ensure_ascii=False, indent=2)
            handle.write("\n")
    except FileExistsError as exc:
        raise AuditError("output must be a fresh file") from exc


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, required=True,
                        help="world_observation checkpoint manifest for the immutable checkpoint files")
    parser.add_argument("--checkpoint", type=Path, action="append", required=True,
                        help="exact manifested checkpoint JSON; repeat at least twice in the same lineage")
    parser.add_argument("--output", type=Path, required=True,
                        help="fresh report path, separate from every source checkpoint")
    args = parser.parse_args(argv)
    try:
        report = audit_checkpoints(args.manifest, args.checkpoint)
        write_fresh(args.output, report, args.checkpoint)
    except (AuditError, OSError, ValueError, KeyError, TypeError) as exc:
        parser.error(str(exc))
    print(json.dumps({"kind": report["kind"], "world_id": report["world_id"],
                      "checkpoints": report["checkpoint_count"],
                      "food_conserved": report["totals"]["food_conserved_across_snapshots"],
                      "per_resident_food_balances_match": report["totals"]["per_resident_food_balances_match_each_interval"],
                      "output": str(args.output.resolve())}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
