"""Offline acceptance checks for staging two independent GM contributions.

All decisions and edits in this module come from the scripted fake transport in
``test_gm_runner``.  Passing these checks is evidence about runner isolation and
provenance only; it is not evidence of autonomous GM work or in-world adoption.
"""
import json
import subprocess
import unittest
from pathlib import Path

from test_gm_runner import ROOT, RunnerTestBase, gm_runner


class TwoContributionStagingTests(RunnerTestBase):
    def claim_two_issues(self):
        document = self.derived_document()
        document['evidence'] = []
        document['proposals'] = []
        evidence = self.write_evidence('two-gm-source.fixture.json', document)
        request = self.root / 'two-gm-investigation.json'
        request.write_text(json.dumps({
            'investigation_id': 'fixture:two-gm-independent-review',
            'world_id': document['world_id'],
            'source_sha256': gm_runner.sha256_file(evidence),
            'objective': 'Review one shared fixture source independently for a bounded hypothesis.',
            'evidence_refs': ['/source_revision'],
        }), encoding='utf-8')
        for owner in ('gm-01', 'gm-02'):
            code, result, _ = self.observe('--gm', owner, '--max-gms', 1,
                                           '--investigation-file', request,
                                           evidence=evidence, mode='discover')
            self.assertEqual(code, 0, result)
            self.assertEqual(result['dispatched'], 1)
        issues = self.issues()
        owned = {record.get('owner_gm'): issue_id for issue_id, record in issues.items()
                 if record.get('owner_gm') in ('gm-01', 'gm-02')}
        self.assertEqual(set(owned), {'gm-01', 'gm-02'})
        self.assertNotEqual(owned['gm-01'], owned['gm-02'])
        return owned

    @staticmethod
    def absolute_candidate(value):
        path = Path(value)
        return path if path.is_absolute() else ROOT / path

    def stage(self, issue_id, owner, target, candidate=None):
        head = self.head_sha()
        scope = self.write_scope(issue_id, head, name=f'scope-{owner}.json', owner_gm=owner,
                                 files=[target], test_commands=[])
        args = ['--state-dir', self.state, '--issue', issue_id, '--scope-file', scope,
                '--base-revision', head]
        if candidate is not None:
            args.extend(['--candidate', candidate])
        return self.cli('code', *args, mode='candidate_repair')

    def test_two_owned_issues_stage_in_distinct_unapproved_candidates(self):
        evidence_before = self.evidence.read_bytes()
        status_before = subprocess.run(['git', 'status', '--porcelain'], cwd=str(ROOT),
                                       capture_output=True, text=True, check=True).stdout
        owned = self.claim_two_issues()

        staged = {}
        for owner, target in (('gm-01', 'tools/offline-gm-one.txt'),
                              ('gm-02', 'tools/offline-gm-two.txt')):
            code, result, _ = self.stage(owned[owner], owner, target)
            self.assertEqual(code, 0, result)
            self.assertEqual(result['owner_gm'], owner)
            self.assertEqual(result['review_state'], 'unapproved')
            self.assertFalse(result['deployed'])
            self.assertEqual(result['candidate_head'], result['base_sha'])
            candidate = self.absolute_candidate(result['candidate'])
            self.worktrees.append(candidate)
            self.assertEqual((candidate / target).read_text(encoding='utf-8'),
                             'reviewable fixture candidate')
            staged[owner] = (result, candidate)

        self.assertNotEqual(staged['gm-01'][1], staged['gm-02'][1])
        self.assertNotEqual(staged['gm-01'][0]['session_returned'],
                            staged['gm-02'][0]['session_returned'])
        state = self.state_json()
        self.assertEqual(state['world_id'], 'fixture:town-trade-validation')
        self.assertEqual(self.evidence.read_bytes(), evidence_before)
        status_after = subprocess.run(['git', 'status', '--porcelain'], cwd=str(ROOT),
                                      capture_output=True, text=True, check=True).stdout
        self.assertEqual(status_after, status_before)

    def test_candidate_path_cannot_be_reused_by_a_different_issue(self):
        owned = self.claim_two_issues()
        target = 'tools/offline-gm-shared.txt'
        code, first, _ = self.stage(owned['gm-01'], 'gm-01', target)
        self.assertEqual(code, 0, first)
        candidate = self.absolute_candidate(first['candidate'])
        self.worktrees.append(candidate)
        candidate_bytes = (candidate / target).read_bytes()
        state_before = self.state_json()
        first_candidates = list(state_before['issues'][owned['gm-01']]['candidates'])
        second_candidates = list(state_before['issues'][owned['gm-02']]['candidates'])
        calls_before = len(self.fake_calls())

        aliases = (candidate, str(candidate).swapcase(), candidate.relative_to(ROOT))
        for alias in aliases:
            with self.subTest(candidate_alias=str(alias)):
                code, refused, _ = self.stage(owned['gm-02'], 'gm-02', target,
                                              candidate=alias)
                self.assertEqual(code, 6, refused)
                self.assertEqual(refused['kind'], 'candidate_issue_mismatch')
        self.assertEqual(len(self.fake_calls()), calls_before,
                         'candidate ownership conflicts must be refused before dispatch')
        self.assertEqual((candidate / target).read_bytes(), candidate_bytes)
        state_after = self.state_json()
        self.assertEqual(state_after['issues'][owned['gm-01']]['candidates'], first_candidates)
        self.assertEqual(state_after['issues'][owned['gm-02']]['candidates'], second_candidates)


if __name__ == '__main__':
    unittest.main()
