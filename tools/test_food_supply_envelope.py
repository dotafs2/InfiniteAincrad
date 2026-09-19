import json
import os
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from food_supply_envelope import CheckpointError, build_report, write_fresh_report  # noqa: E402


ROOT = Path(__file__).resolve().parents[1]
DELIVERY_CHECKPOINTS = Path(
    r"D:/lucidgloves/InfiniteAincrad/tmp/overnight-20260918/delivery/worlds/restart-20260918-01/checkpoints"
)


def fixture(elapsed, hunger, food, stock, capacity, produced, harvested, events=None,
            commands=None, remainder=None, life_seq=None, initial_stock=2):
    resident_ids = ["shared:a", "shared:b"]
    if remainder is None:
        remainder = elapsed % 120.0
    if life_seq is None:
        life_seq = len(events or [])
    return {
        "schema_version": 2,
        "world_id": "fixture:food-envelope",
        "elapsed_seconds": elapsed,
        "residents": [{"stable_id": resident_id, "needs": {"hunger": hunger[index]}}
                      for index, resident_id in enumerate(resident_ids)],
        "survival": {"tick_remainder_seconds": remainder,
                      "accounts": [{"resident_id": resident_ids[index], "food": food[index]}
                                    for index in range(2)]},
        "foraging": {"stock": stock, "capacity": capacity, "initial_stock": initial_stock,
                      "produced_total": produced, "harvested_total": harvested,
                      "growth_remainder_seconds": 0.0},
        "life": {"seq": life_seq, "events": events or []},
        "godot": {"elapsed_seconds": elapsed, "commands": commands or {}},
    }


def write_fixture(directory, name, value):
    path = Path(directory) / name
    path.write_text(json.dumps(value), encoding="utf-8")
    return path


class FoodSupplyEnvelopeTests(unittest.TestCase):
    def test_conservation_ticks_clipping_failures_and_sampled_spans(self):
        with tempfile.TemporaryDirectory() as directory:
            first = fixture(0.0, [80.0, 80.0], [1, 1], 3, 3, 0, 0, initial_stock=3)
            meal = {"type": "eat_ration", "actor_id": "shared:a", "recipient_ids": ["shared:a"]}
            second = fixture(30.0, [100.0, 80.0], [0, 1], 3, 3, 0, 0,
                             events=[meal], remainder=30.0, life_seq=1, initial_stock=3)
            rejected = {"payload": {"actor_id": "shared:b", "action": "harvest_ration"},
                        "status": "rejected", "result": {"ok": False,
                        "code": "resources_unavailable", "actor_id": "shared:b",
                        "command_id": "harvest-failure"}}
            third = fixture(150.0, [99.0, 79.0], [0, 1], 3, 3, 0, 0,
                            events=[meal], commands={"harvest-failure": rejected}, remainder=30.0, life_seq=1,
                            initial_stock=3)
            fourth = fixture(600.0, [95.0, 75.0], [0, 1], 3, 3, 0, 0,
                             events=[meal], commands={"harvest-failure": rejected}, remainder=0.0, life_seq=1,
                             initial_stock=3)
            paths = [write_fixture(directory, name, value) for name, value in [
                ("000.json", first), ("001.json", second), ("002.json", third), ("003.json", fourth)]]
            report = build_report(paths)
            self.assertTrue(report["conservation"]["exact_across_selected_snapshots"])
            self.assertTrue(report["conservation"]["foraging_exact_at_each_snapshot"])
            self.assertEqual(report["time_window"]["elapsed_world_seconds"], 600.0)
            self.assertEqual(report["time_window"]["ticks"], 5)
            self.assertEqual(report["conservation"]["conserved_total_values"], [5, 5, 5, 5])
            self.assertEqual([interval["ticks"] for interval in report["intervals"]], [0, 1, 4])
            self.assertEqual(report["meal_truncation"]["provable_interval_points"], [None, None, None])
            self.assertEqual(report["meal_truncation"]["net_accounting_residual_points"], [20.0, 0.0, 0.0])
            self.assertEqual(report["meal_truncation"]["provable_interval_flags"], [False, False, False])
            self.assertEqual(report["failed_harvest"]["latest_by_code"], {"resources_unavailable": 1})
            self.assertEqual(report["failed_harvest"]["interval_deltas"], [0, 1, 0])
            spans = report["sampled_spans"]
            self.assertEqual(spans["empty_inventory_endpoint_match_seconds_by_resident"]["shared:a"], 570.0)
            self.assertEqual(spans["source_full_endpoint_match_seconds"], 600.0)
            self.assertEqual(spans["continuous_duration_lower_bound_seconds_by_resident"]["shared:a"], 0.0)
            self.assertFalse(spans["continuous_proof"])
            envelope = report["projected_envelope"]
            self.assertEqual(envelope["base_demand_rations_per_hour"], 1.5)
            self.assertEqual(envelope["theoretical_supply_rations_per_hour"], 8.0)

            # Endpoint equality does not prove that a resident stayed empty between
            # checkpoints: insert a middle sample with a ration, then empty again.
            middle = fixture(90.0, [100.0, 80.0], [1, 0], 3, 3, 0, 0,
                             events=[meal], remainder=90.0, life_seq=1, initial_stock=3)
            middle_path = write_fixture(directory, "middle.json", middle)
            outer = build_report([paths[1], paths[2]])["sampled_spans"]
            sampled = build_report([paths[1], middle_path, paths[2]])["sampled_spans"]
            self.assertEqual(outer["empty_inventory_endpoint_match_seconds_by_resident"]["shared:a"], 120.0)
            self.assertEqual(sampled["empty_inventory_endpoint_match_seconds_by_resident"]["shared:a"], 0.0)
            self.assertEqual(outer["continuous_duration_lower_bound_seconds_by_resident"]["shared:a"], 0.0)

    def test_output_must_be_fresh_and_never_replace_a_source(self):
        with tempfile.TemporaryDirectory() as directory:
            source = write_fixture(directory, "source.json", fixture(0.0, [60, 60], [1, 1], 2, 3, 0, 0))
            before = source.read_bytes()
            with self.assertRaises(CheckpointError):
                write_fresh_report(source, "{}\n", [source])
            self.assertEqual(source.read_bytes(), before)
            output = Path(directory) / "report.json"
            write_fresh_report(output, "{\"ok\": true}\n", [source])
            with self.assertRaises(CheckpointError):
                write_fresh_report(output, "{\"overwritten\": true}\n", [source])
            self.assertEqual(output.read_text(encoding="utf-8"), "{\"ok\": true}\n")

    def test_same_time_variants_are_reported_without_zero_length_interval(self):
        with tempfile.TemporaryDirectory() as directory:
            one = write_fixture(directory, "one.json", fixture(0.0, [60, 60], [1, 1], 2, 3, 0, 0))
            two = write_fixture(directory, "two.json", fixture(120.0, [59, 59], [1, 1], 2, 3, 0, 0,
                                                                          remainder=0.0))
            two_variant = write_fixture(directory, "two-variant.json", fixture(120.0, [59, 59], [1, 1], 2, 3, 0, 0,
                                                                                    remainder=0.0, life_seq=0))
            report = build_report([one, two, two_variant])
            self.assertEqual(report["source_count"], 3)
            self.assertEqual(report["selected_snapshot_count"], 2)
            self.assertEqual(len(report["same_time_variants"]), 1)
            self.assertEqual(len(report["intervals"]), 1)
            self.assertEqual(report["intervals"][0]["ticks"], 1)

    def test_malformed_clock_and_cross_world_series_fail_closed(self):
        with tempfile.TemporaryDirectory() as directory:
            valid = fixture(0.0, [60, 60], [1, 1], 2, 3, 0, 0)
            malformed = json.loads(json.dumps(valid))
            malformed["godot"]["elapsed_seconds"] = 1.0
            path = write_fixture(directory, "malformed.json", malformed)
            with self.assertRaises(CheckpointError):
                build_report([path])
            other = json.loads(json.dumps(valid))
            other["world_id"] = "fixture:other"
            other_path = write_fixture(directory, "other.json", other)
            valid_path = write_fixture(directory, "valid.json", valid)
            with self.assertRaises(CheckpointError):
                build_report([valid_path, other_path])

    @unittest.skipUnless(DELIVERY_CHECKPOINTS.is_dir(), "overnight delivery checkpoints are not present")
    def test_actual_restart_checkpoint_series(self):
        paths = [DELIVERY_CHECKPOINTS / name for name in [
            "seq000000-22fe742384341a2b.world.json",
            "seq000148-cdfe013685698028.world.json",
            "seq000151-bdac656c7e4ccda1.world.json",
            "seq000162-ac14a883804ba1ca.world.json",
        ]]
        before = {path: path.read_bytes() for path in paths}
        report = build_report(paths)
        self.assertEqual(before, {path: path.read_bytes() for path in paths})
        self.assertEqual(report["world_id"], "shared:restart-20260918-01")
        self.assertTrue(report["conservation"]["exact_across_selected_snapshots"])
        self.assertTrue(report["conservation"]["foraging_exact_at_each_snapshot"])
        self.assertEqual(report["time_window"]["ticks"], 52)
        self.assertEqual(report["snapshots"][-1]["held_food"], 8)
        self.assertEqual(report["snapshots"][-1]["stock"], 2)
        self.assertEqual(report["snapshots"][-1]["produced"], 13)
        self.assertEqual(report["snapshots"][-1]["meals"], 19)
        self.assertEqual(report["failed_harvest"]["latest_by_code"], {"resources_unavailable": 1})
        self.assertEqual(report["projected_envelope"]["base_demand_rations_per_hour"], 7.5)
        self.assertEqual(report["projected_envelope"]["theoretical_supply_rations_per_hour"], 8.0)


if __name__ == "__main__":
    unittest.main()
