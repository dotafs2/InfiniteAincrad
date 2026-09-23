import copy
import hashlib
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))
from audit_town_resources import AuditError, audit_checkpoints, write_fresh


def world(elapsed: float, events: list[dict], food_a: int, food_b: int,
          stock: int, produced: int, harvested: int, fullness_a: float,
          fullness_b: float, pending: dict | None = None) -> dict:
    return {
        "schema_version": 2, "world_id": "fixture:resource-audit", "elapsed_seconds": elapsed,
        "residents": [
            {"stable_id": "shared:a", "name": "A", "needs": {"hunger": fullness_a}},
            {"stable_id": "shared:b", "name": "B", "needs": {"hunger": fullness_b}},
        ],
        "life": {"seq": len(events), "events": copy.deepcopy(events),
                 "items": [], "accounts": [], "contracts": [], "skills": []},
        "survival": {"accounts": [
            {"resident_id": "shared:a", "food": food_a, "energy": 50},
            {"resident_id": "shared:b", "food": food_b, "energy": 49},
        ], "tick_remainder_seconds": elapsed % 120.0},
        "foraging": {"stock": stock, "capacity": 6, "initial_stock": 1,
                      "produced_total": produced, "harvested_total": harvested,
                      "growth_remainder_seconds": 0.0},
        "godot": {"elapsed_seconds": elapsed, "positions": {}, "homes": {},
                  "pending": copy.deepcopy(pending or {}), "commands": {}, "resident_turns": {},
                  "resident_archive": {"world_id": "fixture:resource-audit", "entries": {}, "order": []},
                  "baking": {"schema_version": 1, "jobs": {}, "ledgers": {}}},
    }


class TownResourceAuditTests(unittest.TestCase):
    def prepare(self, directory: Path):
        root = directory / "checkpoints"
        root.mkdir()
        old_events = [{"seq": 1, "event_id": "life_event_1", "type": "resident_said",
                       "actor_id": "shared:a", "subject_id": "shared:b", "recipient_ids": ["shared:b"]}]
        new_events = old_events + [
            {"seq": 2, "event_id": "life_event_2", "type": "harvest_ration", "actor_id": "shared:a"},
            {"seq": 3, "event_id": "life_event_3", "type": "food_handed_over", "actor_id": "shared:a",
             "subject_id": "shared:b", "quantity": 1},
            {"seq": 4, "event_id": "life_event_4", "type": "eat_ration", "actor_id": "shared:b"},
        ]
        before = world(0, old_events, 1, 0, 1, 0, 0, 70, 40)
        after = world(120, new_events, 1, 0, 0, 0, 1, 69, 79,
                      {"shared:b": {"action": "harvest_ration", "elapsed": 4.0, "command_id": "food-job"}})
        after["godot"]["baking"]["jobs"] = {
            "shared:a": {"action": "bake_bread", "elapsed": 3.0,
                          "reserved_flour": 1, "command_id": "bake-job"}}
        after["godot"]["baking"]["ledgers"] = {
            "public-point": {"shared:a": {"held": 1, "eaten": 0}}}
        paths = [root / "seq000001-fixture.world.json", root / "seq000004-fixture.world.json"]
        rows = []
        for path, state in zip(paths, (before, after)):
            raw = json.dumps(state, ensure_ascii=False, separators=(",", ":")).encode()
            path.write_bytes(raw)
            rows.append({"seq": state["life"]["seq"], "file": path.name,
                         "sha256": hashlib.sha256(raw).hexdigest(),
                         "resident_count": 2, "archive_count": 0, "full_history_preserved": True})
        manifest = root / "manifest.json"
        manifest.write_text(json.dumps({"schema_version": 1, "world_id": "fixture:resource-audit",
                                        "checkpoints": rows}), encoding="utf-8")
        return manifest, paths

    def test_lineage_food_flows_fullness_pending_jobs_and_sparse_limits(self):
        with tempfile.TemporaryDirectory() as directory:
            manifest, paths = self.prepare(Path(directory))
            before = [path.read_bytes() for path in paths]
            report = audit_checkpoints(manifest, paths)
            self.assertTrue(report["full_history_validated"])
            self.assertEqual(report["totals"]["food_conservation_values"], [2, 2])
            self.assertTrue(report["totals"]["food_conserved_across_snapshots"])
            self.assertEqual(report["totals"]["produced_by_source"], {"foraging": 0, "bread": 0})
            interval = report["intervals"][0]
            self.assertEqual(interval["foraging_harvested_delta"], 1)
            self.assertEqual(interval["eaten_delta"], 1)
            self.assertEqual(interval["given_delta"], 1)
            self.assertTrue(interval["food_conservation_ok"])
            self.assertTrue(interval["per_resident_food_balances_match"])
            self.assertTrue(report["totals"]["per_resident_food_balances_match_each_interval"])
            self.assertEqual(interval["per_resident"]["shared:a"]["given"], 1)
            self.assertEqual(interval["per_resident"]["shared:b"]["received"], 1)
            self.assertEqual(interval["per_resident"]["shared:b"]["fullness_after"], 79)
            self.assertEqual(report["snapshots"][-1]["residents"]["shared:a"]["fullness"], 69)
            self.assertEqual(len(report["snapshots"][-1]["pending_food_jobs"]), 2)
            self.assertEqual(report["snapshots"][-1]["baking_loaf_carry"]["shared:a"]["held"], 1)
            self.assertFalse(report["sparse_observation"]["continuous_starvation_proven"])
            self.assertEqual(report["sparse_observation"]["continuous_starvation_lower_bound_seconds_by_resident"]["shared:b"], 0)
            self.assertEqual(before, [path.read_bytes() for path in paths])

    def test_global_conservation_does_not_hide_unrecorded_resident_transfer(self):
        with tempfile.TemporaryDirectory() as directory:
            manifest, paths = self.prepare(Path(directory))
            current = json.loads(paths[1].read_text())
            current["survival"]["accounts"][0]["food"] = 0
            current["survival"]["accounts"][1]["food"] = 1
            raw = json.dumps(current, ensure_ascii=False, separators=(",", ":")).encode()
            paths[1].write_bytes(raw)
            document = json.loads(manifest.read_text())
            document["checkpoints"][1]["sha256"] = hashlib.sha256(raw).hexdigest()
            manifest.write_text(json.dumps(document), encoding="utf-8")

            report = audit_checkpoints(manifest, paths)
            interval = report["intervals"][0]
            self.assertTrue(interval["food_conservation_ok"])
            self.assertTrue(report["totals"]["food_conserved_across_snapshots"])
            self.assertFalse(interval["per_resident_food_balances_match"])
            self.assertFalse(report["totals"]["per_resident_food_balances_match_each_interval"])
            self.assertEqual(interval["per_resident"]["shared:a"]["food_balance_residual"], -1)
            self.assertEqual(interval["per_resident"]["shared:b"]["food_balance_residual"], 1)

    def test_rejects_manifest_mismatch_and_discontinuous_history(self):
        with tempfile.TemporaryDirectory() as directory:
            manifest, paths = self.prepare(Path(directory))
            paths[1].write_text(paths[1].read_text().replace("resident_said", "changed_event"), encoding="utf-8")
            with self.assertRaises(AuditError):
                audit_checkpoints(manifest, paths)

        with tempfile.TemporaryDirectory() as directory:
            manifest, paths = self.prepare(Path(directory))
            before = json.loads(paths[0].read_text())
            current = json.loads(paths[1].read_text())
            current["life"]["events"][0]["text"] = "rewritten old event"
            paths[1].write_text(json.dumps(current), encoding="utf-8")
            document = json.loads(manifest.read_text())
            document["checkpoints"][1]["sha256"] = hashlib.sha256(paths[1].read_bytes()).hexdigest()
            manifest.write_text(json.dumps(document), encoding="utf-8")
            with self.assertRaisesRegex(AuditError, "continuity"):
                audit_checkpoints(manifest, paths)

    def test_output_must_be_fresh_and_cannot_replace_source(self):
        with tempfile.TemporaryDirectory() as directory:
            manifest, paths = self.prepare(Path(directory))
            report = audit_checkpoints(manifest, paths)
            source_bytes = paths[0].read_bytes()
            with self.assertRaises(AuditError):
                write_fresh(paths[0], report, paths)
            output = Path(directory) / "report.json"
            write_fresh(output, report, paths)
            with self.assertRaises(AuditError):
                write_fresh(output, report, paths)
            self.assertEqual(paths[0].read_bytes(), source_bytes)


if __name__ == "__main__":
    unittest.main()
