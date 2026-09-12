"""Portable consumer checks for the journey-stall fields in the GM evidence schema.

By default these tests use a committed, sanitized SYNTHETIC snapshot. It is not physics evidence,
a resident decision, a model observation, or a maintained save. To exercise the same assertions
against a separately generated offline scene snapshot, explicitly set ``H36_JOURNEY_SNAPSHOT``.

Producer side (regenerate the fixture, no provider, no paid call):

    python -X utf8 tools/run_godot.py --godot <GODOT> --name <label> --timeout 300 \
      --out <logs> -- --headless --rendering-method forward_plus --audio-driver Dummy \
      --script res://tests/town_journey_stall_acceptance.gd \
      -- --town-save=<dir>/world.json --save=<dir>/world.json --work=<dir>/work \
      --out=<dir>/out/journey.json

The acceptance writes ``<dir>/out/gm-snapshot-mid.json`` while an approach stall is open. An
explicit missing ``H36_JOURNEY_SNAPSHOT`` is an error, so integration evidence cannot silently
turn into a passing skip.

This test only imports the existing runner; it does not start a model, an engine or a provider.
"""

import json
import os
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))

import gm_runner  # noqa: E402  (existing runner under another executor's ownership: import only)

SYNTHETIC_FIXTURE = ROOT / 'tools' / 'fixtures' / 'gm_journey_stall_snapshot.synthetic.json'
PRIVATE_KEYS = ('reason', 'memory', 'memories', 'dialogue', 'dialog', 'needs', 'story', 'personality')


def snapshot_path() -> tuple[Path, str]:
    override = os.environ.get('H36_JOURNEY_SNAPSHOT')
    if override is not None:
        candidate = Path(override)
        if not candidate.is_file():
            raise FileNotFoundError(
                f'explicit H36_JOURNEY_SNAPSHOT does not exist: {candidate}')
        return candidate, 'generated_offline_scene_snapshot'
    return SYNTHETIC_FIXTURE, 'committed_sanitized_synthetic_fixture'


class JourneyObservationConsumerTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.path, cls.provenance = snapshot_path()
        if not cls.path.is_file():
            raise FileNotFoundError(f'committed synthetic fixture is missing: {cls.path}')
        cls.payload, cls.document, cls.digest = gm_runner.read_evidence(cls.path)
        cls.entries = [entry for entry in cls.document['evidence']
                       if entry.get('evidence_kind') == 'movement_blocked']

    def test_snapshot_is_a_non_empty_world_scoped_export(self):
        self.assertEqual(self.document['kind'], 'background_gm_evidence_snapshot')
        self.assertEqual(self.document['schema_version'], 1)
        self.assertGreater(len(self.entries), 0, 'the fixture snapshot must carry a real issue')
        self.assertEqual(self.document['counts']['issues'], len(self.document['evidence']))
        self.assertTrue(any(entry.get('journey') == 'approach' for entry in self.entries))
        if self.provenance == 'committed_sanitized_synthetic_fixture':
            self.assertIn('sanitized synthetic', self.document.get('fixture_note', ''))

    def test_runner_validation_accepts_the_new_optional_fields(self):
        self.assertEqual(gm_runner.validate_evidence(self.document), [])

    def test_optional_journey_fields_and_threshold_survive(self):
        entry = next(e for e in self.entries if e.get('journey') == 'approach')
        self.assertEqual(entry['physical_facts']['progress_epsilon'], 0.05,
                         'the exported threshold must be the detector\'s real progress epsilon')
        self.assertIn('progress_measure', entry['physical_facts'])
        self.assertEqual(entry['physical_facts']['observation_source'], 'host_physics_frame_position')
        self.assertIsInstance(entry['physical_facts']['remaining_distance'], float)
        self.assertIn('remaining_route_m', entry['physical_facts'])
        self.assertTrue(entry.get('job_command_id'))

    def test_identity_comes_from_the_supplied_issue_id(self):
        entry = self.entries[0]
        kind, key, field = gm_runner.issue_identity(entry, 'world_evidence')
        self.assertEqual(key, entry['issue_id'])
        self.assertIn(field, ('issue_id', 'episode_id'))
        self.assertEqual(kind, 'movement_blocked')
        self.assertTrue(entry['issue_id'].startswith('journey_stall:'))

    def test_import_preparation_creates_one_issue_and_keeps_history(self):
        state = gm_runner.blank_state()
        first = gm_runner.import_source(state, self.document, self.path, self.digest)
        self.assertEqual(len(first['created']), len(self.entries))
        self.assertEqual(first['world_binding_conflict'], False)
        self.assertIsNotNone(first['vector'])
        issue_id = list(state['issues'])[0]
        self.assertEqual(len(state['issues']), 1, 'one live journey exports one issue')
        self.assertFalse(state['issues'][issue_id]['lifecycle'] == 'closed')
        repeat = gm_runner.import_source(state, self.document, self.path, self.digest)
        self.assertEqual(repeat['duplicates'], [issue_id])
        self.assertEqual(repeat['created'], [])
        self.assertEqual(len(state['issues']), 1, 'a repeated import never forks the issue identity')
        # An empty projection must mark the issue absent from the bounded projection, never resolved.
        empty = dict(self.document)
        empty['evidence'] = []
        empty['counts'] = {'issues': 0, 'proposals': 0}
        empty['source_revision'] = dict(self.document['source_revision'])
        empty['source_revision']['life_seq'] = self.document['source_revision']['life_seq'] + 1
        absent = gm_runner.import_source(state, empty, self.path, self.digest)
        self.assertEqual(absent['absent'], [issue_id])
        self.assertEqual(state['issues'][issue_id]['lifecycle'], 'not_in_current_projection')
        self.assertIsNotNone(state['issues'][issue_id]['absent_since'])
        self.assertEqual(len(state['issues']), 1, 'history is preserved, not erased')

    def test_no_npc_private_context_is_required(self):
        text = json.dumps(self.document, ensure_ascii=False)
        for key in PRIVATE_KEYS:
            self.assertNotIn(f'"{key}"', text, f'no {key} field may appear in world evidence')
        boundaries = self.document['boundaries']
        self.assertFalse(boundaries['contains_private_reply_reason'])
        self.assertFalse(boundaries['contains_other_resident_memories'])
        self.assertFalse(boundaries['consumed_by_npc_model'])


if __name__ == '__main__':
    unittest.main(verbosity=2)
