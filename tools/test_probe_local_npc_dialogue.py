import importlib.util
import json
import pathlib
import unittest
import urllib.error
import tempfile
import sys


ROOT = pathlib.Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("probe", ROOT / "probe_local_npc_dialogue.py")
probe = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(probe)


def case(case_id="fixture-1"):
    return {"case_id": case_id, "resident_id": "shared:carpenter", "context": {"target_ids": ["player"], "claim_ids": ["claim:visible"], "action_ids": ["offer:axe"]}, "options": [{"alias": "offer:axe", "description": "Offer the exact reviewed axe option."}], "observation": {"text": "The axe is visible."}}


class ProbeTests(unittest.TestCase):
    def test_raw_response_preserved_and_receipt_parsed(self):
        raw = '{"speech":"I can help.","intent":"offer","stance":"guarded","target_id":"player","claim_ids":["claim:visible"],"stakes":"The edge remains unresolved.","next_action":"offer:axe","confidence":0.8}'

        def call(body):
            self.assertEqual(body["model"], "qwen3:8b")
            self.assertFalse(body["think"])
            self.assertEqual(body["options"]["num_predict"], 384)
            return 200, json.dumps({"model": "qwen3:8b", "message": {"content": raw}, "prompt_eval_count": 17, "eval_count": 31}).encode(), {}

        result = probe.probe_cases([case()], call)
        row = result["cases"][0]
        self.assertEqual(row["raw_content"], raw)
        self.assertEqual(row["parse"], {"ok": None, "code": "json_object_ready_for_godot", "godot_validator": "DialogueReceipt.parse"})
        self.assertEqual((row["input_tokens"], row["output_tokens"]), (17, 31))
        self.assertEqual((result["paid_calls"], result["world_writes"]), (0, 0))

    def test_malformed_json_is_not_repaired_or_retried(self):
        calls = []

        def call(_body):
            calls.append(1)
            return 200, json.dumps({"message": {"content": "{not a receipt"}}).encode(), {}

        row = probe.probe_cases([case()], call)["cases"][0]
        self.assertEqual(len(calls), 1)
        self.assertEqual(row["raw_content"], "{not a receipt")
        self.assertEqual(row["parse"]["code"], "malformed_receipt_json")

    def test_unreachable_service_is_recorded(self):
        def call(_body):
            raise urllib.error.URLError("connection refused")

        row = probe.probe_cases([case()], call)["cases"][0]
        self.assertEqual(row["parse"]["code"], "request_failed")
        self.assertIn("URLError", row["error"])

    def test_external_endpoint_rejected(self):
        self.assertFalse(probe._loopback_url("https://example.com/api/chat"))
        self.assertFalse(probe._loopback_url("http://192.168.1.4:11434/api/chat"))
        self.assertTrue(probe._loopback_url(probe.ENDPOINT))

    def test_maximum_request_budget(self):
        with self.assertRaises(ValueError):
            probe._validate_input({"fixture_only": True, "cases": [case(str(i)) for i in range(4)]})

    def test_exporter_invariants_reject_duplicates_and_mismatch(self):
        duplicate = case()
        duplicate["context"]["action_ids"] = ["offer:axe", "offer:axe"]
        with self.assertRaises(ValueError):
            probe._validate_input({"fixture_only": True, "cases": [duplicate]})
        mismatch = case("mismatch")
        mismatch["options"][0]["alias"] = "offer:other"
        with self.assertRaises(ValueError):
            probe._validate_input({"fixture_only": True, "cases": [mismatch]})
        with self.assertRaises(ValueError):
            probe._validate_input({"fixture_only": True, "cases": [case("same"), case("same")]})

    def test_existing_output_is_rejected_before_any_call(self):
        with tempfile.TemporaryDirectory() as directory:
            input_path = pathlib.Path(directory) / "input.json"
            output_path = pathlib.Path(directory) / "existing.json"
            input_path.write_text(json.dumps({"fixture_only": True, "cases": [case()]}), encoding="utf-8")
            original = "historical evidence\n"
            output_path.write_text(original, encoding="utf-8")
            calls = []
            old_argv = sys.argv[:]
            try:
                sys.argv = ["probe", "--input", str(input_path), "--output", str(output_path)]
                old_call = probe._http_call
                probe._http_call = lambda _body: calls.append(1)
                self.assertEqual(probe.main(), 2)
            finally:
                probe._http_call = old_call
                sys.argv = old_argv
            self.assertEqual(calls, [])
            self.assertEqual(output_path.read_text(encoding="utf-8"), original)


if __name__ == "__main__":
    unittest.main()
