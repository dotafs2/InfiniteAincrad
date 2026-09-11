import contextlib
import io
import json
import os
import shutil
import sys
import uuid
import unittest
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from deepseek_usage import aggregate, main, summarize_run  # noqa: E402

SECRET = "DO-NOT-LEAK-prompt-body-42"
SCRATCH = Path(__file__).resolve().parent / "_deepseek_usage_scratch"


@contextlib.contextmanager
def scratch_dir():
    SCRATCH.mkdir(parents=True, exist_ok=True)
    root = SCRATCH / uuid.uuid4().hex
    root.mkdir(parents=True)
    try:
        yield root
    finally:
        shutil.rmtree(root, ignore_errors=True)


def usage(inp, cached, out, reasoning=0, write=0, **overrides):
    counters = {"input_tokens": inp, "cached_input_tokens": cached,
                "cache_write_input_tokens": write, "output_tokens": out,
                "reasoning_output_tokens": reasoning}
    counters.update(overrides)
    return counters


def turn_total(inp, cached, out, reasoning=0, write=0):
    return {"type": "turn.completed", "usage": usage(inp, cached, out, reasoning, write)}


def write_run(root, name, events, process=None, result=None):
    run_dir = Path(root) / name
    run_dir.mkdir(parents=True)
    with (run_dir / "events.jsonl").open("w", encoding="utf-8") as handle:
        for event in events:
            handle.write(event if isinstance(event, str) else json.dumps(event))
            handle.write("\n")
    if process is not None:
        (run_dir / "process.json").write_text(json.dumps(process), encoding="utf-8")
    if result is not None:
        (run_dir / "result.md").write_text(result, encoding="utf-8")
    return run_dir


def run_main(dirs, extra=()):
    out = io.StringIO()
    with contextlib.redirect_stdout(out):
        argv = []
        for directory in dirs:
            argv += ['--run-dir', str(directory)]
        code = main(argv + list(extra))
    return code, out.getvalue()


class UsageAggregatorTests(unittest.TestCase):
    def test_multiple_turns_summed_with_cached_subset_math(self):
        with scratch_dir() as root:
            run_dir = write_run(root, "run-a", [
                {"type": "turn.started"},
                turn_total(100, 40, 10, reasoning=3),
                turn_total(50, 10, 5, reasoning=1),
                {"type": "item.completed", "item": {"text": SECRET}},
            ], process={"pid": 4321, "model": "deepseek-flash"}, result="done")
            record, counters = summarize_run(run_dir, 1 << 20)
            self.assertEqual(record["status"], "completed")
            self.assertEqual(record["pid"], 4321)
            self.assertEqual(record["model"], "deepseek-flash")
            self.assertEqual(record["turn_count"], 2)
            self.assertEqual(record["input_tokens"], 150)
            self.assertEqual(record["cached_input_tokens"], 50)
            self.assertEqual(record["output_tokens"], 15)
            self.assertEqual(record["raw_tokens"], 165)
            self.assertEqual(record["cache_miss_tokens"], 100)
            self.assertEqual(record["weighted_cache_hit"], round(50 / 150, 6))
            self.assertTrue(record["result_present"])
            self.assertEqual(counters["turn_count"], 2)

    def test_missing_usage_is_incomplete_not_zero(self):
        with scratch_dir() as root:
            run_dir = write_run(root, "run-b", [
                {"type": "thread.started", "thread_id": "t-1"},
                {"type": "item.completed", "item": {"text": SECRET}},
            ], process={"pid": 7, "model": "deepseek-flash"})
            record, counters = summarize_run(run_dir, 1 << 20)
            self.assertEqual(record["status"], "incomplete")
            self.assertIsNone(counters)
            self.assertEqual(record["turn_count"], 0)
            for field in ("input_tokens", "cached_input_tokens", "output_tokens", "raw_tokens"):
                self.assertNotIn(field, record)
            self.assertTrue(any("unknown, not zero" in note for note in record["limitations"]))
            self.assertTrue(any("result.md missing" in note for note in record["limitations"]))

    def test_failed_run_without_completed_turn_is_unknown(self):
        with scratch_dir() as root:
            run_dir = write_run(root, "run-c", [
                {"type": "turn.started"},
                {"type": "turn.failed", "error": {"message": SECRET}},
            ], process={"pid": 9, "model": "deepseek-flash"}, result="partial")
            record, counters = summarize_run(run_dir, 1 << 20)
            self.assertEqual(record["status"], "failed")
            self.assertIsNone(counters)
            self.assertNotIn("input_tokens", record)

    def test_failed_run_with_partial_turns_keeps_counters_and_notes_scope(self):
        with scratch_dir() as root:
            run_dir = write_run(root, "run-d", [
                turn_total(20, 5, 2),
                {"type": "turn.failed", "error": {"message": SECRET}},
            ], process={"pid": 11, "model": "deepseek-flash"}, result="partial")
            record, counters = summarize_run(run_dir, 1 << 20)
            self.assertEqual(record["status"], "failed")
            self.assertEqual(record["input_tokens"], 20)
            self.assertIsNotNone(counters)
            self.assertTrue(any("completed turns only" in note for note in record["limitations"]))

    def test_rejects_unknown_usage_field(self):
        with scratch_dir() as root:
            run_dir = write_run(root, "run-e", [
                {"type": "turn.completed", "usage": usage(10, 1, 2, mystery_tokens=3)}])
            record, counters = summarize_run(run_dir, 1 << 20)
            self.assertEqual(record["status"], "invalid")
            self.assertIsNone(counters)
            self.assertTrue(any("unknown usage field" in note for note in record["limitations"]))

    def test_rejects_missing_usage_field(self):
        counters = usage(10, 1, 2)
        del counters["reasoning_output_tokens"]
        with scratch_dir() as root:
            run_dir = write_run(root, "run-f", [{"type": "turn.completed", "usage": counters}])
            record, _ = summarize_run(run_dir, 1 << 20)
            self.assertEqual(record["status"], "invalid")
            self.assertTrue(any("missing usage field" in note for note in record["limitations"]))

    def test_rejects_non_integer_and_negative_counters(self):
        rejected = (usage(10, 1, 2, reasoning=None), usage(10, 1, 2, output_tokens="5"),
                    usage(-1, 0, 2))
        for bad in rejected:
            with scratch_dir() as root:
                run_dir = write_run(root, "run-g", [{"type": "turn.completed", "usage": bad}])
                record, _ = summarize_run(run_dir, 1 << 20)
                self.assertEqual(record["status"], "invalid")

    def test_rejects_inconsistent_counters(self):
        with scratch_dir() as root:
            over_cached = write_run(root, "run-h", [turn_total(10, 50, 2)])
            over_reasoning = write_run(root, "run-i", [turn_total(10, 1, 2, reasoning=9)])
            self.assertEqual(summarize_run(over_cached, 1 << 20)[0]["status"], "invalid")
            self.assertEqual(summarize_run(over_reasoning, 1 << 20)[0]["status"], "invalid")

    def test_malformed_event_lines_are_ignored_not_fabricated(self):
        with scratch_dir() as root:
            run_dir = write_run(root, "run-j", [
                "{not json",
                json.dumps(turn_total(30, 10, 4)),
                "   ",
            ])
            record, _ = summarize_run(run_dir, 1 << 20)
            self.assertEqual(record["status"], "completed")
            self.assertEqual(record["input_tokens"], 30)
            self.assertTrue(any("unparsable event line" in note for note in record["limitations"]))

    def test_missing_events_file_is_rejected(self):
        with scratch_dir() as root:
            run_dir = Path(root) / "run-k"
            run_dir.mkdir()
            record, counters = summarize_run(run_dir, 1 << 20)
            self.assertEqual(record["status"], "invalid")
            self.assertIsNone(counters)

    def test_event_size_bound_rejects_before_reading(self):
        with scratch_dir() as root:
            run_dir = write_run(root, "run-l", [turn_total(10, 1, 2)])
            record, counters = summarize_run(run_dir, max_event_bytes=10)
            self.assertEqual(record["status"], "invalid")
            self.assertIsNone(counters)
            self.assertTrue(any("byte bound" in note for note in record["limitations"]))

    def test_no_content_exposure_in_output(self):
        with scratch_dir() as root:
            run_dir = write_run(root, "run-m", [
                {"type": "item.completed", "item": {"text": SECRET}},
                turn_total(100, 40, 10, reasoning=3),
            ], process={"pid": 55, "model": "deepseek-flash"}, result=SECRET)
            code, text = run_main([run_dir])
            self.assertEqual(code, 0)
            self.assertNotIn(SECRET, text)
            payload = json.loads(text)
            self.assertEqual(payload["runs"][0]["run_id"], "run-m")
            self.assertEqual(payload["runs"][0]["pid"], 55)
            self.assertEqual(payload["runs"][0]["input_tokens"], 100)

    def test_aggregate_weighted_cache_hit_and_status_counts(self):
        with scratch_dir() as root:
            good = write_run(root, "run-n", [turn_total(100, 40, 10, reasoning=3)])
            other = write_run(root, "run-o", [turn_total(50, 10, 5, reasoning=1)])
            incomplete = write_run(root, "run-p", [{"type": "turn.started"}])
            failed = write_run(root, "run-q", [{"type": "error", "message": SECRET}])
            pairs = [summarize_run(d, 1 << 20) for d in (good, other, incomplete, failed)]
            result = aggregate(pairs)
            self.assertEqual(result["runs_total"], 4)
            self.assertEqual(result["runs_completed"], 2)
            self.assertEqual(result["runs_incomplete"], 1)
            self.assertEqual(result["runs_failed"], 1)
            self.assertEqual(result["runs_invalid"], 0)
            self.assertEqual(result["input_tokens"], 150)
            self.assertEqual(result["cached_input_tokens"], 50)
            self.assertEqual(result["cache_miss_tokens"], 100)
            self.assertEqual(result["raw_tokens"], 165)
            self.assertEqual(result["weighted_cache_hit"], round(50 / 150, 6))

    def test_invalid_run_sets_nonzero_exit_code(self):
        with scratch_dir() as root:
            good = write_run(root, "run-r", [turn_total(10, 1, 2)])
            bad = write_run(root, "run-s", [{"type": "turn.completed", "usage": usage(5, 1, 1, extra=1)}])
            code, text = run_main([good, bad])
            self.assertEqual(code, 3)
            self.assertNotIn(SECRET, text)

    def test_max_run_bound_rejects_many_directories(self):
        with scratch_dir() as root:
            first = write_run(root, "run-t", [turn_total(10, 1, 2)])
            second = write_run(root, "run-u", [turn_total(10, 1, 2)])
            with self.assertRaises(SystemExit):
                main(["--run-dir", str(first), "--run-dir", str(second), "--max-runs", "1"])

    def test_missing_run_directory_reported_as_invalid(self):
        with scratch_dir() as root:
            missing = Path(root) / "does-not-exist"
            code, text = run_main([missing])
            self.assertEqual(code, 3)
            self.assertEqual(json.loads(text)["runs"][0]["status"], "invalid")


if __name__ == "__main__":
    unittest.main()
