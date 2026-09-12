"""Explicit offline transport tests of sourced GM hypotheses and unapproved delivery."""
import copy
import json
import sys
import unittest
from pathlib import Path

from test_gm_runner import FAKE_KEY, ROOT, RunnerTestBase, USAGE, gm_runner


class DiscoveryDeliveryTests(RunnerTestBase):
    def empty_source(self):
        document = self.derived_document()
        document['evidence'] = []
        document['proposals'] = []
        return self.write_evidence('empty-world-projection.fixture.json', document)

    def investigation(self, evidence, **overrides):
        document = json.loads(evidence.read_text(encoding='utf-8'))
        request = {'investigation_id': 'fixture:empty-source-check',
                   'world_id': document['world_id'], 'source_sha256': gm_runner.sha256_file(evidence),
                   'objective': 'Review the fixture source counters for one bounded hypothesis.',
                   'evidence_refs': ['/source_revision']}
        request.update(overrides)
        path = self.root / 'investigation.json'
        path.write_text(json.dumps(request), encoding='utf-8')
        return path

    def test_empty_projection_explicit_investigation_ten_contexts_and_no_repeat(self):
        evidence = self.empty_source()
        code, dry, _ = self.observe('--max-gms', 10, '--dry-run', evidence=evidence)
        self.assertEqual(code, 0, dry)
        self.assertFalse(any(item['can_dispatch'] for item in dry['plan']))
        request = self.investigation(evidence)
        code, result, _ = self.observe('--max-gms', 10, '--investigation-file', request,
                                       evidence=evidence, mode='no_action')
        self.assertEqual(code, 0, result)
        self.assertEqual(result['dispatched'], 10)
        sessions = self.sessions()
        self.assertEqual(len({record['session_id'] for record in sessions.values()}), 10)
        for gm_id, record in sessions.items():
            self.assertEqual(len(record['investigations']), 1)
            prompt = (self.state / 'runs' / result['run_id'] / f'{gm_id}.prompt.txt').read_text()
            self.assertIn('supervisor_specified', prompt)
            self.assertNotIn(FAKE_KEY, prompt)
        code, repeated, _ = self.observe('--max-gms', 10, '--investigation-file', request,
                                         evidence=evidence, mode='no_action')
        self.assertEqual(code, 0, repeated)
        self.assertEqual(repeated['dispatched'], 0)
        self.assertEqual(len(self.fake_calls()), 10)

    def test_discovery_claim_candidate_repair(self):
        evidence = self.empty_source()
        request = self.investigation(evidence)
        preserved = {path: path.read_bytes() for path in (evidence, request)}
        code, observed, _ = self.observe('--max-gms', 1, '--investigation-file', request,
                                         evidence=evidence, mode='discover')
        self.assertEqual(code, 0, observed)
        issue_id = observed['results'][0]['new_issue_ids'][0]
        issue = self.issues()[issue_id]
        self.assertEqual(issue['owner_gm'], 'gm-01')
        self.assertEqual(issue['provenance']['origin'], 'gm_proposed')
        self.assertEqual(issue['provenance']['proposed_by_gm'], 'gm-01')
        self.assertEqual(issue['provenance']['status'], 'hypothesis')
        self.assertFalse(issue['provenance']['verified_in_world'])
        self.assertEqual(issue['provenance']['investigation']['origin'], 'supervisor_specified')
        code, repeated, _ = self.observe('--max-gms', 1, '--investigation-file', request,
                                         evidence=evidence, mode='discover')
        self.assertEqual(code, 0, repeated)
        self.assertEqual(repeated['dispatched'], 0)
        self.assertEqual(self.issues()[issue_id]['lifecycle'], 'current')

        head = self.head_sha()
        target = 'tools/offline-gm-candidate.txt'
        scope = self.write_scope(issue_id, head, files=[target], owner_gm='gm-01',
                                 test_commands=[[sys.executable, '-c',
                                    "import os;from pathlib import Path;"
                                    "assert not os.environ.get('DEEPSEEK_API_KEY');"
                                    f"assert Path({target!r}).read_text() == 'reviewable fixture candidate'"]])
        args = ('--state-dir', self.state, '--issue', issue_id, '--scope-file', scope,
                '--base-revision', head, '--protect', evidence, '--run-scope-tests')
        code, failed, _ = self.cli('code', *args, mode='candidate_fail')
        self.assertEqual(code, 1, failed)
        self.assertEqual(failed['status'], 'scope_tests_failed')
        candidate = Path(failed['candidate'])
        if not candidate.is_absolute():
            candidate = ROOT / candidate
        self.worktrees.append(candidate)
        session = failed['session_returned']
        self.assertEqual(failed['observed_changed_files'], [target])
        self.assertFalse((ROOT / target).exists())
        self.assertTrue(failed['usage_measured'])
        self.assertEqual(failed['usage'], USAGE)
        code, ack, _ = self.cli('acknowledge', '--state-dir', self.state, '--gm', 'gm-01',
                                '--note', 'Inspected offline scope failure; repair same candidate.',
                                route=False)
        self.assertEqual(code, 0, ack)
        code, repaired, _ = self.cli('code', *args, mode='candidate_repair')
        self.assertEqual(code, 0, repaired)
        self.assertEqual(repaired['session_requested'], session)
        self.assertEqual(repaired['session_returned'], session)
        self.assertEqual(repaired['usage'], USAGE)
        self.assertEqual(repaired['usage_cumulative']['input_tokens'], 2400)
        self.assertEqual(repaired['review_state'], 'unapproved')
        self.assertFalse(repaired['deployed'])
        self.assertEqual(repaired['guards']['changed'], [])
        self.assertEqual(repaired['credential_leak_in_run_dir'], [])
        calls = self.fake_calls()
        self.assertEqual(calls[0]['argv'][calls[0]['argv'].index('-s') + 1], 'read-only')
        self.assertEqual(calls[-1]['argv'][calls[-1]['argv'].index('-s') + 1], 'workspace-write')
        self.assertIn('sandbox_workspace_write.network_access=false', calls[-1]['argv'])
        self.assertEqual((candidate / target).read_text(), 'reviewable fixture candidate')
        for path, original in preserved.items():
            self.assertEqual(path.read_bytes(), original)

    def test_existing_subdirectory_is_not_an_isolated_candidate(self):
        self.assertEqual(self.observe('--max-gms', 1, mode='claim')[0], 0)
        issue_id = next(iter(self.issues()))
        head = self.head_sha()
        scope = self.write_scope(issue_id, head)
        candidate = self.state / 'ordinary-directory'
        candidate.mkdir()
        code, result, _ = self.cli('code', '--state-dir', self.state, '--issue', issue_id,
                                   '--scope-file', scope, '--base-revision', head,
                                   '--candidate', candidate)
        self.assertEqual(code, 6, result)
        self.assertEqual(result['kind'], 'candidate_not_isolated_worktree')
        self.assertEqual(len(self.fake_calls()), 1)
        for state_dir, candidate in ((self.state, self.state), (ROOT.parent, ROOT)):
            code, result, _ = self.cli('code', '--state-dir', state_dir, '--issue', issue_id,
                                       '--scope-file', scope, '--base-revision', head,
                                       '--candidate', candidate)
            self.assertEqual(code, 6, result)
            self.assertEqual(result['kind'], 'candidate_outside_state_dir')

    def test_identity_components_cannot_collide_and_legacy_id_is_preserved(self):
        state = gm_runner.load_state(self.root / 'empty-state')
        state['world_id'] = 'fixture:identity'
        investigation = {'investigation_id': 'a:b', 'source_sha256': 'a' * 64}
        proposal = {'proposal_key': 'c', 'summary': 'First fixture hypothesis.',
                    'evidence_refs': ['/counts'], 'claim_coding': False}
        first = gm_runner.register_new_issues(state, 'gm-01', [proposal], investigation, 'first')
        first_id = first[0]['issue_id']
        # Simulate the prior colon-key format; continuing the same provenance keeps its id.
        old_id = 'issue-legacy-fixture'
        state['issues'][old_id] = state['issues'].pop(first_id)
        state['issues'][old_id]['issue_id'] = old_id
        repeated = gm_runner.register_new_issues(state, 'gm-01', [proposal], investigation, 'resume')
        self.assertEqual(repeated[0]['issue_id'], old_id)
        second = gm_runner.register_new_issues(state, 'gm-01',
                    [dict(proposal, proposal_key='b:c', summary='Second fixture hypothesis.')],
                    dict(investigation, investigation_id='a'), 'second')
        self.assertNotEqual(second[0]['issue_id'], old_id)
        self.assertEqual(len(state['issues']), 2)
        self.assertEqual(state['issues'][old_id]['summary'], 'First fixture hypothesis.')

    def test_same_investigation_revision_keeps_proposal_identity_and_first_source(self):
        evidence = self.empty_source()
        first_sha = gm_runner.sha256_file(evidence)
        request = self.investigation(evidence)
        code, result, _ = self.observe('--max-gms', 1, '--investigation-file', request,
                                       evidence=evidence, mode='discover')
        self.assertEqual(code, 0, result)
        issue_id = result['results'][0]['new_issue_ids'][0]
        document = json.loads(evidence.read_text())
        document['source_revision']['life_seq'] += 1
        changed = self.write_evidence('updated-empty.json', document)
        request = self.investigation(changed)
        code, update, _ = self.observe('--max-gms', 1, '--investigation-file', request,
                                       evidence=changed, mode='discover')
        self.assertEqual(code, 0, update)
        self.assertEqual(update['results'][0]['new_issue_ids'], [issue_id])
        self.assertEqual(len(self.issues()), 1)
        proposal = self.issues()[issue_id]
        self.assertEqual(proposal['owner_gm'], 'gm-01')
        self.assertEqual(proposal['provenance']['first_investigation']['source_sha256'], first_sha)
        self.assertEqual(proposal['provenance']['investigation']['source_sha256'],
                         gm_runner.sha256_file(changed))
        self.assertEqual(len(proposal['outcomes']), 2)

    def test_wrong_issue_and_blocked_are_not_delivery(self):
        self.assertEqual(self.observe('--max-gms', 1, mode='claim')[0], 0)
        issues = list(self.issues())
        head = self.head_sha()
        for issue_id, mode, expected in zip(issues,
                ('coding_wrong_issue', 'coding_blocked'), ('invalid_output', 'worker_blocked')):
            scope = self.write_scope(issue_id, head)
            code, result, _ = self.cli('code', '--state-dir', self.state, '--issue', issue_id,
                                       '--scope-file', scope, '--base-revision', head, mode=mode)
            self.assertEqual(code, 1, result)
            self.assertEqual(result['status'], expected)
            self.assertEqual(result['cost'], 'measured')
            self.assertEqual(result['review_state'], 'unapproved')
            self.assertFalse(result['deployed'])
            self.assertTrue(result['coding_unresolved']['repairable'])
            self.worktrees.append(ROOT / result['candidate'])
            code, ack, _ = self.cli('acknowledge', '--state-dir', self.state, '--gm', 'gm-01',
                                    '--note', 'Inspected offline rejected coding status.', route=False)
            self.assertEqual(code, 0, ack)

    def test_outer_blocked_contract_cannot_be_replaced_by_nested_example(self):
        example = {'issue_id': 'issue-correct', 'status': 'implemented',
                   'changed_files': [], 'test_commands': [], 'test_results': 'example'}
        outer = dict(example, status='blocked', notes={'example_of_expected_reply': example})
        parsed = gm_runner.extract_json_object('```json\n' + json.dumps(outer) + '\n```')
        self.assertEqual(parsed['status'], 'blocked')
        self.assertEqual(gm_runner.validate_coding_output(parsed, 'issue-correct'), [])
        self.assertIsNone(gm_runner.extract_json_object(json.dumps(outer) + '\n' +
                                                       json.dumps(example)))

    def test_rename_cannot_hide_out_of_scope_source(self):
        self.assertEqual(gm_runner.normalize_status_paths('R  README.md -> tools/allowed.txt\n'),
                         ['README.md', 'tools/allowed.txt'])
        self.assertEqual(gm_runner.normalize_status_paths(
                         'R  tools/allowed.txt\0README.md\0?? tools/space -> name.txt\0'),
                         ['README.md', 'tools/allowed.txt', 'tools/space -> name.txt'])
        self.assertEqual(self.observe('--max-gms', 1, mode='claim')[0], 0)
        issue_id = next(iter(self.issues()))
        head = self.head_sha()
        scope = self.write_scope(issue_id, head, files=['tools/allowed.txt'], test_commands=[])
        code, result, _ = self.cli('code', '--state-dir', self.state, '--issue', issue_id,
                                   '--scope-file', scope, '--base-revision', head,
                                   mode='rename_out_of_scope')
        self.assertEqual(code, 1, result)
        self.assertEqual(result['status'], 'out_of_scope_change')
        self.assertEqual(result['out_of_scope_changes'], ['README.md'])
        self.assertFalse(result['deployed'])
        self.worktrees.append(ROOT / result['candidate'])

    def test_bad_investigation_hash_world_pointer_and_unknown_field_refused_before_dispatch(self):
        evidence = self.empty_source()
        for override in ({'world_id': 'different-world'}, {'source_sha256': '0' * 64},
                         {'evidence_refs': ['/source_revision/absent']},
                         {'evidence_refs': ['/private_memory']},
                         {'evidence_refs': ['/evidence/-1']}, {'evidence_refs': []}):
            request = self.investigation(evidence, **override)
            code, payload, _ = self.observe('--max-gms', 1, '--investigation-file', request,
                                            evidence=evidence, mode='discover')
            self.assertEqual(code, 4, payload)
            self.assertEqual(payload['kind'], 'investigation_invalid')
            self.assertFalse((self.state / 'state.json').exists())
        self.assertEqual(self.fake_calls(), [])

    def test_new_proposal_rejected_without_investigation_and_without_selected_pointer(self):
        for with_investigation in (False, True):
            evidence = self.evidence
            extra = ['--investigation-file', self.investigation(evidence)] if with_investigation else []
            code, result, _ = self.observe('--max-gms', 1, *extra,
                                           mode='discover_bad_ref' if with_investigation else 'discover')
            self.assertEqual(code, 1, result)
            self.assertEqual(result['results'][0]['status'], 'invalid_output')
            self.assertFalse(any(issue.get('source_channel') == 'gm_proposal'
                                 for issue in self.issues().values()))
            code, ack, _ = self.cli('acknowledge', '--state-dir', self.state, '--gm', 'gm-01',
                                    '--note', 'Inspected rejected offline proposal contract.', route=False)
            self.assertEqual(code, 0, ack)


class NativeUsageTests(RunnerTestBase):
    def test_resumed_cumulative_counters_become_increment_and_repeat_zero(self):
        first = self.write_evidence('first.json', self.derived_document(8, 3, touch='first'))
        code, a, _ = self.observe('--max-gms', 1, evidence=first)
        self.assertEqual(code, 0, a)
        second = self.write_evidence('second.json', self.derived_document(9, 4, touch='second'))
        code, b, _ = self.observe('--max-gms', 1, evidence=second)
        self.assertEqual(code, 0, b)
        self.assertEqual(b['results'][0]['usage'], USAGE)
        self.assertEqual(b['results'][0]['usage_cumulative']['input_tokens'], 2400)
        third = self.write_evidence('third.json', self.derived_document(10, 5, touch='third'))
        code, c, _ = self.observe('--max-gms', 1, evidence=third, mode='usage_repeat')
        self.assertEqual(code, 0, c)
        self.assertEqual(c['results'][0]['usage'], dict.fromkeys(USAGE, 0))
        attempts = self.sessions()['gm-01']['attempts']
        self.assertEqual(sum(attempt['usage']['input_tokens'] for attempt in attempts), 2400)

    def test_counter_decrease_stops_dispatch_preserves_raw_highwater_and_unknown(self):
        self.assertEqual(self.observe('--max-gms', 1)[0], 0)
        before = copy.deepcopy(self.state_json()['usage_highwater'])
        changed = self.write_evidence('changed.json', self.derived_document(9, 4, touch='changed'))
        code, result, _ = self.observe('--max-gms', 2, evidence=changed, mode='usage_decrease')
        self.assertEqual(code, 1, result)
        self.assertEqual(result['dispatched'], 1)
        outcome = result['results'][0]
        self.assertEqual(outcome['cost'], 'unknown')
        self.assertIsNone(outcome['usage'])
        self.assertEqual(outcome['usage_accounting']['status'], 'counter_decreased')
        self.assertEqual(outcome['usage_cumulative']['input_tokens'], 600)
        self.assertEqual(self.state_json()['usage_highwater'], before)

    def test_legacy_baseline_backfilled_without_rewriting_attempts(self):
        self.assertEqual(self.observe('--max-gms', 1)[0], 0)
        state = self.state_json()
        state.pop('usage_highwater')
        old = state['sessions']['gm-01']['attempts'][0]
        old.pop('usage_cumulative')
        old.pop('usage_accounting')
        preserved = copy.deepcopy(old)
        gm_runner.save_json(self.state / 'state.json', state)
        changed = self.write_evidence('changed.json', self.derived_document(9, 4, touch='changed'))
        code, result, _ = self.observe('--max-gms', 1, evidence=changed)
        self.assertEqual(code, 0, result)
        self.assertEqual(result['results'][0]['usage'], USAGE)
        self.assertEqual(self.sessions()['gm-01']['attempts'][0], preserved)

    def test_missing_baseline_and_nonfinite_or_invalid_subset_are_unknown(self):
        state = gm_runner.load_state(self.root / 'fresh-state')
        session = '00000000-0000-0000-0000-000000000001'
        attempt = {'thread_returned': session, 'usage': USAGE.copy()}
        gm_runner.account_native_usage(state, attempt, session)
        self.assertIsNone(attempt['usage'])
        self.assertEqual(attempt['usage_accounting']['status'], 'missing_resume_baseline')
        for bad in ({'input_tokens': float('nan'), 'output_tokens': 1},
                    {'input_tokens': 1, 'output_tokens': 1, 'cached_input_tokens': 2},
                    {'input_tokens': 1, 'output_tokens': 1, 'reasoning_output_tokens': True}):
            self.assertFalse(gm_runner.usage_is_measured(bad))

    def test_invalid_delta_preserves_previous_highwater(self):
        state = gm_runner.load_state(self.root / 'fresh-state')
        session = '00000000-0000-0000-0000-000000000001'
        state['usage_highwater'] = {session: dict(USAGE)}
        attempt = {'thread_returned': session, 'usage': dict(USAGE, cached_input_tokens=900)}
        gm_runner.account_native_usage(state, attempt, session)
        self.assertIsNone(attempt['usage'])
        self.assertEqual(attempt['usage_accounting']['status'], 'invalid_delta')
        self.assertEqual(state['usage_highwater'][session], USAGE)


if __name__ == '__main__':
    unittest.main()
