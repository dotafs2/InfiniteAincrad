import importlib.util
import json
import pathlib
import sys
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("smith_probe", ROOT / "probe_local_smith_reply.py")
probe = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(probe)


def case():
    return {"case_id": "smith_reply", "resident_id": "shared:smith", "context": {"target_ids": ["shared:carpenter"], "claim_ids": [], "action_ids": ["a16", "a17"]}, "options": [{"alias": "a16", "action_id": "contract:accept:trade_contract_fixture:offer", "description": "Accept the offered repair terms", "expected_intents": ["agree"]}, {"alias": "a17", "action_id": "contract:reject:trade_contract_fixture:offer", "description": "Decline the offered repair terms", "expected_intents": ["refuse"]}], "observation": {"text": "Flint has the current offer in view."}}


class SmithProbeTests(unittest.TestCase):
    def test_prompt_contains_authoritative_intents_and_one_call_raw(self):
        raw = '{"speech":"I will take the repair job.","intent":"agree","stance":"firm","target_id":"shared:carpenter","claim_ids":[],"stakes":"The terms should be clear.","next_action":"a16","confidence":0.8}'
        calls = []
        def call(body, timeout):
            calls.append(body)
            self.assertEqual(timeout, 45)
            self.assertFalse(body["think"])
            self.assertEqual(body["options"]["num_predict"], 384)
            prompt = body["messages"][0]["content"]
            self.assertIn('"expected_intents":["agree"]', prompt)
            self.assertIn('"next_action":"a17"', prompt)
            self.assertIn('"speech":"I decline the repair offer.","intent":"refuse"', prompt)
            self.assertNotIn('"next_action":"contract:reject:trade_contract_fixture:offer"', prompt)
            self.assertNotIn("contract:accept:", prompt)
            self.assertNotIn("contract:reject:", prompt)
            self.assertIn("Format-only example (not a recommendation", prompt)
            return 200, json.dumps({"message": {"content": raw}, "prompt_eval_count": 4, "eval_count": 9}).encode(), {}
        row = probe.probe_case(case(), call)
        self.assertEqual(len(calls), 1)
        self.assertEqual(row["raw_content"], raw)

    def test_prompt_uses_dynamic_aliases_and_omits_unmapped_example(self):
        fixture = case()
        fixture["context"]["action_ids"] = ["z9", "z10"]
        fixture["options"][0]["alias"] = "z9"
        fixture["options"][1]["alias"] = "z10"
        prompt = probe._prompt(probe._validate_input({"fixture_only": True, "cases": [fixture]})[0])
        self.assertIn('["z9","z10"]', prompt)
        self.assertNotIn("a16", prompt)
        self.assertNotIn("a17", prompt)
        empty = case()
        for option in empty["options"]:
            option["expected_intents"] = []
        empty_prompt = probe._prompt(probe._validate_input({"fixture_only": True, "cases": [empty]})[0])
        self.assertIn("No format example is supplied because no option has mapped expected_intents.", empty_prompt)
    def test_malformed_is_preserved_without_retry(self):
        calls = []
        def call(_body, _timeout):
            calls.append(1)
            return 200, json.dumps({"message": {"content": "{bad"}}).encode(), {}
        row = probe.probe_case(case(), call)
        self.assertEqual(calls, [1])
        self.assertEqual(row["raw_content"], "{bad")
        self.assertEqual(row["parse"]["code"], "malformed_receipt_json")

    def test_metadata_failures_make_zero_calls(self):
        bad = case()
        bad["options"][0].pop("expected_intents")
        with self.assertRaises(ValueError):
            probe._validate_input({"fixture_only": True, "cases": [bad]})
        with self.assertRaises(ValueError):
            probe._validate_input({"fixture_only": True, "cases": [case(), case()]})
        wrong = case()
        wrong["resident_id"] = "shared:carpenter"
        with self.assertRaises(ValueError):
            probe._validate_input({"fixture_only": True, "cases": [wrong]})

    def test_unmapped_empty_expected_metadata_is_preserved(self):
        fixture = case()
        fixture["options"][1]["expected_intents"] = []
        checked = probe._validate_input({"fixture_only": True, "cases": [fixture]})
        self.assertEqual(checked[0]["options"][1]["expected_intents"], [])
        self.assertIn("empty expected_intents", probe._prompt(checked[0]))

    def test_existing_output_is_not_overwritten(self):
        with tempfile.TemporaryDirectory() as directory:
            input_path = pathlib.Path(directory) / "input.json"
            output_path = pathlib.Path(directory) / "out.json"
            input_path.write_text(json.dumps({"fixture_only": True, "cases": [case()]}), encoding="utf-8")
            output_path.write_text("historical\n", encoding="utf-8")
            old_argv = sys.argv[:]
            old_call = probe._http_call
            calls = []
            try:
                sys.argv = ["probe", "--input", str(input_path), "--output", str(output_path)]
                probe._http_call = lambda _body, _timeout: calls.append(1)
                self.assertEqual(probe.main(), 2)
            finally:
                probe._http_call = old_call
                sys.argv = old_argv
            self.assertEqual(calls, [])
            self.assertEqual(output_path.read_text(encoding="utf-8"), "historical\n")


if __name__ == "__main__":
    unittest.main()
