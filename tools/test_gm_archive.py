import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import gm_archive  # noqa: E402
import gm_runner  # noqa: E402


class GmArchiveTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.save = Path(self.temp.name) / "world.json"
        delivered = {
            "archive_id": "turn:smith:0:1", "world_id": "fixture:archive",
            "resident_id": "fixture:smith", "request_id": "turn:smith:0:1",
            "provider_id": "opengameagent_fixture", "model_returned": True,
            "assistant_text_parts": ['{"action":"ask_help"}'],
            "assistant_text": '{"action":"ask_help"}', "original_reply": {"ok": True},
            "reason": "need help", "speech": "Can you help?",
            "application": {"status": "settled", "code": "ask_help", "effect": {"ok": True},
                            "speech_delivery": {"delivered": True, "event_id": "life_event_1",
                                                 "recipient_ids": ["fixture:smith", "fixture:innkeeper"]}},
        }
        hidden = dict(delivered, archive_id="turn:smith:0:2", request_id="turn:smith:0:2",
                      speech="private thought", application={"status": "rule_rejection",
                      "code": "option_unavailable", "speech_delivery": {"delivered": False}})
        default_dialogue = dict(delivered, archive_id="turn:smith:0:3", request_id="turn:smith:0:3",
                                speech="", delivered_text="The canonical default reply.")
        self.save.write_text(json.dumps({"world_id": "fixture:archive", "godot": {
            "resident_archive": {"schema_version": 1, "world_id": "fixture:archive",
                                  "order": [delivered["archive_id"], hidden["archive_id"], default_dialogue["archive_id"]],
                                  "entries": {delivered["archive_id"]: delivered,
                                               hidden["archive_id"]: hidden,
                                               default_dialogue["archive_id"]: default_dialogue}}}}, indent=2),
                              encoding="utf-8")

    def tearDown(self):
        self.temp.cleanup()

    def test_full_gm_reads_all_pages_and_assistant_text(self):
        first = gm_archive.read_archive(self.save, "fixture:archive", "gm-02", 0, 1)
        self.assertEqual(first["count"], 1)
        self.assertEqual(first["next_cursor"], 1)
        self.assertIn("assistant_text", first["entries"][0])
        second = gm_archive.read_archive(self.save, "fixture:archive", "gm-02", 1, 1)
        self.assertEqual(second["entries"][0]["speech"], "private thought")

    def test_other_gm_sees_only_delivered_dialogue_and_no_model_text(self):
        page = gm_archive.read_archive(self.save, "fixture:archive", "gm-01", 0, 8)
        self.assertEqual(page["count"], 2)
        self.assertEqual(page["entries"][0]["speech"], "Can you help?")
        self.assertNotIn("assistant_text", page["entries"][0])
        self.assertEqual(page["entries"][1]["speech"], "The canonical default reply.")

    def test_world_binding_is_required(self):
        with self.assertRaises(ValueError):
            gm_archive.read_archive(self.save, "another-world", "gm-02")

    def test_new_archive_keeps_old_accepted_reply_history_as_incomplete(self):
        document = {"world_id": "fixture:archive", "godot": {
            "resident_archive": {"schema_version": 1, "world_id": "fixture:archive",
                                  "order": [], "entries": {}},
            "resident_turns": {"fixture:smith": {
                "request_id": "turn:smith:old", "status": "settled",
                "accepted_reply": {"ok": True, "decision": {"action": "wait", "reason": "old"}},
                "history": [{"command_id": "turn:smith:old", "status": "settled",
                              "result": {"ok": True, "code": "wait"}}]}}}}
        self.save.write_text(json.dumps(document), encoding="utf-8")
        result = gm_archive.read_archive(self.save, "fixture:archive", "gm-02")
        self.assertEqual(result["count"], 1)
        self.assertFalse(result["entries"][0]["complete"])
        self.assertEqual(result["entries"][0]["source"], "legacy_resident_turn")

    def test_life_events_add_dialogue_without_narration_and_dedup_delivery(self):
        delivered = {
            "archive_id": "godot_help:turn:smith:0:1", "world_id": "fixture:archive",
            "resident_id": "fixture:smith", "request_id": "godot_help:turn:smith:0:1",
            "speech": "Already archived", "delivered_text": "Already archived",
            "application": {"speech_delivery": {"delivered": True,
                                                     "event_id": "life_event_2"}},
        }
        document = {"world_id": "fixture:archive", "godot": {
            "resident_archive": {"schema_version": 1, "world_id": "fixture:archive",
                                  "order": [delivered["archive_id"]],
                                  "entries": {delivered["archive_id"]: delivered}}},
            "life": {"events": [
                {"event_id": "life_event_2", "operation_id": "turn:old",
                 "type": "ask_help", "actor_id": "fixture:a",
                 "recipient_ids": ["fixture:a", "fixture:b"], "text": "duplicate"},
                {"event_id": "life_event_3", "operation_id": "turn:new",
                 "type": "reply_help", "actor_id": "fixture:b",
                 "recipient_ids": ["fixture:b", "fixture:a"], "text": "A real reply"},
                {"event_id": "life_event_4", "operation_id": "place:nope",
                 "type": "place_visited", "actor_id": "fixture:a",
                 "recipient_ids": ["fixture:a"], "text": "Narration"},
            ]}}
        self.save.write_text(json.dumps(document), encoding="utf-8")
        ordinary = gm_archive.read_archive(self.save, "fixture:archive", "gm-01", limit=20)
        self.assertEqual([entry["speech"] for entry in ordinary["entries"]], ["Already archived", "A real reply"])
        self.assertEqual(ordinary["total_visible"], 2)
        full = gm_archive.read_archive(self.save, "fixture:archive", "gm-02", limit=20)
        self.assertEqual(sum(entry.get("source") == "life_event_dialogue" for entry in full["entries"]), 1)

    def test_archive_source_hash_guards_cursor_paging(self):
        first = gm_archive.read_archive(self.save, "fixture:archive", "gm-02", limit=1)
        with self.save.open("a", encoding="utf-8") as handle:
            handle.write("\n")
        with self.assertRaisesRegex(ValueError, "source changed"):
            gm_archive.read_archive(self.save, "fixture:archive", "gm-02", cursor=1,
                                     source_sha256=first["source_sha256"])

    def test_memory_cli_reads_bound_state_with_spaces_in_path(self):
        state_dir = Path(self.temp.name) / "state with spaces"
        state = gm_runner.load_state(state_dir)
        gm_runner.remember_gm_task(state["sessions"]["gm-01"], "gm-01",
                                   {"kind": "observation_task", "run_id": "cli-1", "result": "kept"})
        gm_runner.store_state(state_dir, state)
        command = [sys.executable, str(ROOT / "tools" / "gm_archive.py"), "memory",
                   "--state-dir", str(state_dir), "--gm", "gm-01", "--cursor", "0", "--limit", "1"]
        completed = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, check=False)
        self.assertEqual(completed.returncode, 0, completed.stderr)
        payload = json.loads(completed.stdout)
        self.assertEqual(payload["count"], 1)
        self.assertEqual(payload["task_history"][0]["run_id"], "cli-1")
        self.assertEqual(payload["next_cursor"], None)


if __name__ == "__main__":
    unittest.main()
