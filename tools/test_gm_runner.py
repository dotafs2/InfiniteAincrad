#!/usr/bin/env python3
"""Offline tests for tools/gm_runner.py. No network, no real credentials, no real model.

The evidence fixture is a byte copy of the accepted published export
docs/validation/town_gm_evidence_2026-09-12/evidence-final.json (world_id
fixture:town-trade-validation, kind background_gm_evidence_snapshot, 0 issues and 2
fixture proposals written by the prior Godot bridge test). Every derived export used
here carries an explicit derived-fixture note; none of it is live Kimi demand. Every
model answer comes from the local fake transport below; none of it is real DeepSeek or
Kimi behaviour.
"""
import copy
import json
import os
import shutil
import subprocess
import sys
import time
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import gm_runner  # noqa: E402

ACCEPTED_EVIDENCE = ROOT / 'docs' / 'validation' / 'town_gm_evidence_2026-09-12' / 'evidence-final.json'
FIXTURE_SAVE = ROOT / 'tmp' / 'chain-20260912' / 'task01-tests' / 'final-review-3' / \
    'saves' / 'gm-evidence.json'
FAKE_KEY = 'sk-offline-fake-key-not-a-credential'
USAGE = {'input_tokens': 1200, 'cached_input_tokens': 800, 'output_tokens': 60,
         'reasoning_output_tokens': 0}

FAKE_CODEX = r'''"""Offline fake transport: never contacts a real provider."""
import json
import os
import re
import subprocess
import sys
import time
import uuid
from pathlib import Path

USAGE = {"input_tokens": 1200, "cached_input_tokens": 800, "output_tokens": 60,
         "reasoning_output_tokens": 0}


def section(prompt, name):
    match = re.search(r"\[" + name + r"\]\n(.*?)\n\[END_" + name + r"\]", prompt, re.S)
    return json.loads(match.group(1)) if match else None


def main():
    argv = sys.argv[1:]
    resume = argv[argv.index("resume") + 1] if "resume" in argv else None
    result_path = Path(argv[argv.index("-o") + 1]) if "-o" in argv else None
    prompt = sys.stdin.read()
    gm_state = section(prompt, "GM_STATE")
    coding_state = section(prompt, "CODING_SCOPE")
    context = coding_state if coding_state is not None else (gm_state or {})
    modes = json.loads(os.environ.get("FAKE_GM_MODES") or "{}")
    mode = modes.get(context.get("gm_id"), os.environ.get("FAKE_GM_MODE", "ok"))
    log_path = os.environ.get("FAKE_GM_LOG")
    if log_path:
        with open(log_path, "a", encoding="utf-8") as handle:
            handle.write(json.dumps({"argv": argv, "cwd": os.getcwd(), "mode": mode,
                                     "identity": context.get("gm_id"),
                                     "issues": [item["issue_id"] for item in
                                                context.get("open_issues", [])]}) + "\n")
    if mode == "hang":
        time.sleep(120)

    def emit(event):
        print(json.dumps(event), flush=True)

    session = resume or str(uuid.uuid4())
    if mode == "no_session":
        emit({"type": "turn.completed", "usage": USAGE})
        return 0
    if mode == "fail":
        emit({"type": "error", "message": "offline fake transport failure"})
        print("offline fake transport failure", file=sys.stderr)
        return 2
    if mode == "mismatch" and resume:
        session = str(uuid.uuid4())
    emit({"type": "thread.started", "thread_id": session})
    home = Path(os.environ.get("CODEX_HOME") or (Path.home() / ".codex"))
    rollout = home / "sessions" / "2026" / "09" / "12" / f"rollout-2026-09-12T00-00-00-{session}.jsonl"
    rollout.parent.mkdir(parents=True, exist_ok=True)
    with rollout.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps({"type": "offline-fake-session", "prompt_chars": len(prompt)}) + "\n")
    usage_path = home / ("offline-usage-" + session + ".json")
    previous_usage = json.loads(usage_path.read_text()) if usage_path.exists() else {}
    cumulative = {key: value + previous_usage.get(key, 0) for key, value in USAGE.items()}
    if mode == "usage_decrease":
        cumulative = {key: value // 2 for key, value in USAGE.items()}
    elif mode == "usage_repeat":
        cumulative = previous_usage
    usage_path.write_text(json.dumps(cumulative))

    if coding_state is not None:
        if mode == "rename_out_of_scope":
            subprocess.run(["git", "mv", "README.md", coding_state["scope"]["files"][0]],
                           cwd=os.getcwd(), capture_output=True, text=True, check=True)
        if mode in ("candidate_fail", "candidate_repair"):
            target = Path(os.getcwd()) / coding_state["scope"]["files"][0]
            target.write_text("reviewable fixture candidate" if mode == "candidate_repair"
                              else "incomplete fixture candidate", encoding="utf-8")
        if mode == "out_of_scope":
            target = Path(os.getcwd()) / "game" / "rogue-note.txt"
            target.write_text("offline fake out-of-scope change", encoding="utf-8")
        if mode == "commit":
            subprocess.run(["git", "-c", "user.email=fake@example.com", "-c", "user.name=fake",
                            "commit", "--allow-empty", "-m", "offline fake worker commit"],
                           cwd=os.getcwd(), capture_output=True, text=True)
        answer = None if mode == "bad_contract" else {
            "issue_id": coding_state["open_issues"][0]["issue_id"], "status": "implemented",
            "changed_files": coding_state["scope"]["files"] if mode.startswith("candidate_") else [],
            "test_commands": coding_state["scope"].get("test_commands", []),
            "test_results": "offline fake: nothing else executed", "notes": "offline fake runner"}
        if mode == "coding_wrong_issue":
            answer["issue_id"] = "issue-wrong"
        if mode == "coding_blocked":
            answer["status"] = "blocked"
    else:
        issues = [item["issue_id"] for item in gm_state["open_issues"]]
        if mode == "invalid_output":
            answer = {"gm_id": gm_state["gm_id"],
                      "results": [{"issue_id": "issue-ffffffffffff", "disposition": "observe",
                                   "claim_coding": False, "summary": "offline fake"}]}
        elif mode == "no_action":
            answer = {"gm_id": gm_state["gm_id"],
                      "results": [{"issue_id": issue, "disposition": "no_action",
                                   "claim_coding": False, "summary": "offline fake no action"}
                                  for issue in issues]}
        elif mode == "claim":
            answer = {"gm_id": gm_state["gm_id"],
                      "results": [{"issue_id": issue, "disposition": "proposal",
                                   "claim_coding": True, "summary": "offline fake claim"}
                                  for issue in issues]}
        elif mode == "bad_contract":
            answer = None
        elif mode in ("discover", "discover_bad_ref"):
            refs = (gm_state.get("investigation") or {}).get("evidence_refs", ["/counts"])
            answer = {"gm_id": gm_state["gm_id"], "results": [],
                      "new_issues": [{"proposal_key": "fixture-bounded-check",
                                      "summary": "Offline fixture hypothesis requires a scoped candidate.",
                                      "evidence_refs": refs if mode == "discover" else ["/secret"],
                                      "claim_coding": True}]}
        else:
            answer = {"gm_id": gm_state["gm_id"],
                      "results": [{"issue_id": issue, "disposition": "observe",
                                   "claim_coding": False, "summary": "offline fake observation",
                                   "evidence_refs": [issue]} for issue in issues],
                      "note": "offline fake runner"}
    text = "offline fake runner; no model was called\n"
    if answer is not None:
        text += "```json\n" + json.dumps(answer) + "\n```\n"
    if result_path is not None:
        result_path.write_text(text, encoding="utf-8")
    emit({"type": "item.completed", "item": {"type": "agent_message", "text": text}})
    if mode != "no_usage":
        emit({"type": "turn.completed", "usage": cumulative})
    return 0


if __name__ == "__main__":
    sys.exit(main())
'''


class RunnerTestBase(unittest.TestCase):
    maxDiff = None

    def setUp(self):
        self.root = ROOT / 'tmp' / 'gm-runner-tests' / f'{self._testMethodName}-{os.getpid()}'
        workspace = (ROOT / 'tmp' / 'gm-runner-tests').resolve()
        target = self.root.resolve()
        if target.exists() and workspace in target.parents:
            shutil.rmtree(target, ignore_errors=True)
        self.root.mkdir(parents=True)
        self.state = self.root / 'state'
        self.codex_home = self.root / 'codex-home'
        self.codex_home.mkdir()
        # Fake host config: the runner now requires a verifiable Windows sandbox backend.
        self.codex_config = self.codex_home / 'config.toml'
        self.codex_config.write_text('[windows]\nsandbox = "unelevated"\n', encoding='utf-8')
        self.log = self.root / 'fake-calls.jsonl'
        self.config = self.root / 'deepseek.local.json'
        self.config.write_text(json.dumps({'model': 'deepseek-flash',
                                           'base_url': 'https://api.deepseek.com',
                                           'wire_api': 'responses'}), encoding='utf-8')
        self.key_file = self.root / 'deepseek-key.txt'
        self.key_file.write_text(FAKE_KEY + '\n', encoding='utf-8')
        self.fake = self.root / 'fake_codex.py'
        self.fake.write_text(FAKE_CODEX, encoding='utf-8')
        self.evidence = self.root / 'evidence-fixture-accepted-copy.json'
        shutil.copyfile(ACCEPTED_EVIDENCE, self.evidence)
        self.worktrees = []
        self.owned_processes = []

    def tearDown(self):
        for process in self.owned_processes:
            try:
                process.terminate()
                process.wait(timeout=10)
            except Exception:
                pass
            for stream in (process.stdout, process.stderr):
                try:
                    stream.close()
                except Exception:
                    pass
        for path in self.state.glob('runs/*/*.process.json'):
            try:
                self.kill_owned_pid(json.loads(path.read_text(encoding='utf-8')).get('pid'))
            except (json.JSONDecodeError, OSError):
                continue
        workspace = (ROOT / 'tmp').resolve()
        for worktree in self.worktrees:
            path = Path(worktree).resolve()
            if path != workspace and workspace in path.parents:
                subprocess.run(['git', 'worktree', 'remove', '--force', str(path)], cwd=str(ROOT),
                               capture_output=True, text=True)
        # Also sweep candidates created by a killed run, which returns no summary.
        listing = subprocess.run(['git', 'worktree', 'list', '--porcelain'], cwd=str(ROOT),
                                 capture_output=True, text=True).stdout
        test_root = self.root.resolve()
        for line in listing.splitlines():
            if not line.startswith('worktree '):
                continue
            resolved = Path(line.split(' ', 1)[1].strip()).resolve()
            if resolved != ROOT.resolve() and test_root in resolved.parents:
                subprocess.run(['git', 'worktree', 'remove', '--force', str(resolved)],
                               cwd=str(ROOT), capture_output=True, text=True)
        subprocess.run(['git', 'worktree', 'prune'], cwd=str(ROOT), capture_output=True,
                       text=True)

    def cli(self, subcommand, *args, mode='ok', modes=None, timeout=300, route=True,
            state_dir=None, wait=True, codex=None, codex_home=None):
        environment = dict(os.environ)
        home = str(codex_home or self.codex_home)
        environment.update({'FAKE_GM_MODE': mode, 'FAKE_GM_LOG': str(self.log),
                            'CODEX_HOME': home})
        if modes:
            environment['FAKE_GM_MODES'] = json.dumps(modes)
        command = [sys.executable, str(ROOT / 'tools' / 'gm_runner.py'), subcommand]
        if route:
            codex_value = codex or (f'"{str(sys.executable).replace(chr(92), "/")}" '
                                    f'"{str(self.fake).replace(chr(92), "/")}"')
            command += ['--config', str(self.config), '--key-file', str(self.key_file),
                        '--codex-home', home,
                        '--codex', codex_value]
        command += [str(item) for item in args]
        if not wait:
            process = subprocess.Popen(command, cwd=str(ROOT), env=environment,
                                       stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
                                       encoding='utf-8', errors='replace')
            self.owned_processes.append(process)
            return process
        finished = subprocess.run(command, cwd=str(ROOT), env=environment, capture_output=True,
                                  text=True, encoding='utf-8', errors='replace', timeout=timeout)
        payload = None
        for line in reversed(finished.stdout.splitlines()):
            line = line.strip()
            if line.startswith('{'):
                try:
                    payload = json.loads(line)
                except json.JSONDecodeError:
                    continue
                break
        self.assertIsNotNone(payload,
                             f'no JSON payload from {command}\n{finished.stdout}\n{finished.stderr}')
        return finished.returncode, payload, finished

    def observe(self, *extra, evidence=None, mode='ok', modes=None, wait=True, state_dir=None):
        return self.cli('observe', '--state-dir', str(state_dir or self.state),
                        '--evidence', str(evidence or self.evidence),
                        '--prior-ledger', str(self.root / 'absent-ledger.json'),
                        *[str(item) for item in extra], mode=mode, modes=modes, wait=wait,
                        state_dir=state_dir)

    def fake_calls(self):
        if not self.log.is_file():
            return []
        return [json.loads(line) for line in self.log.read_text(encoding='utf-8').splitlines()
                if line]

    def state_json(self):
        return json.loads((self.state / gm_runner.STATE_FILE).read_text(encoding='utf-8'))

    def sessions(self, state_dir=None):
        path = Path(state_dir or self.state) / gm_runner.STATE_FILE
        return json.loads(path.read_text(encoding='utf-8'))['sessions']

    def issues(self):
        return self.state_json()['issues']

    # ---- offline fixture helpers -------------------------------------------------

    def accepted_document(self):
        return json.loads(ACCEPTED_EVIDENCE.read_text(encoding='utf-8'))

    def derived_document(self, life=None, proposal=None, world_id=None, touch=None):
        document = self.accepted_document()
        document['derived_fixture_note'] = ('offline fixture-derived from the accepted export; '
                                            'never live Kimi demand')
        if life is not None:
            document['source_revision']['life_seq'] = life
            document['source_revision']['world_elapsed_seconds'] = float(life)
            document['source_revision']['godot_elapsed_seconds'] = float(life)
        if proposal is not None:
            document['source_revision']['proposal_sequence'] = proposal
        if world_id is not None:
            document['world_id'] = world_id
        if touch:
            entry = document['proposals'][0]
            entry['latest'] = dict(entry['latest'], reason=touch,
                                   request_id=f'turn:fixture:smith:0:{life}')
        return document

    def write_evidence(self, name, document):
        document.setdefault('counts', {})
        document['counts']['issues'] = len(document['evidence'])
        document['counts']['proposals'] = len(document['proposals'])
        path = self.root / name
        path.write_text(json.dumps(document, indent=2), encoding='utf-8')
        return path

    def proposal(self, index=0, **overrides):
        entry = copy.deepcopy(self.accepted_document()['proposals'][index])
        entry.update(overrides)
        return entry

    def world_issue(self, status='open', issue_id='collision:well-edge'):
        return {'evidence_kind': 'travel_blocked', 'issue_id': issue_id,
                'resident_id': 'fixture:smith', 'status': status, 'occurrences': 1,
                'first': {'reason': 'WELL_ROPE_TEXT', 'request_id': 'turn:fixture:smith:0:3',
                          'source_sequence': 6},
                'latest': {'reason': 'WELL_ROPE_TEXT', 'request_id': 'turn:fixture:smith:0:3',
                           'source_sequence': 6}}

    def issue_by_key(self, key_part):
        for issue in self.issues().values():
            if key_part in issue['identity_key']:
                return issue
        self.fail(f'no issue with identity key containing {key_part!r}')

    def head_sha(self) -> str:
        return subprocess.run(['git', 'rev-parse', 'HEAD'], cwd=str(ROOT), capture_output=True,
                              text=True).stdout.strip()

    def write_scope(self, issue_id, head, name='scope.json', **overrides):
        scope = {'issue_id': issue_id, 'base_revision': head,
                 'objective': 'Offline check of the coding preconditions and candidate guards.',
                 'files': ['tools/gm_runner.py'],
                 'acceptance': ['the offline fake reports no changed files'],
                 'test_commands': [[sys.executable, '-c', "print('scope test ok')"]]}
        scope.update(overrides)
        path = self.root / name
        path.write_text(json.dumps(scope), encoding='utf-8')
        return path

    def kill_owned_pid(self, pid):
        if pid is None:
            return
        if os.name == 'nt':
            subprocess.run(['taskkill', '/PID', str(pid), '/T', '/F'], capture_output=True,
                           text=True)
        else:
            import signal
            try:
                os.kill(pid, signal.SIGTERM)
            except ProcessLookupError:
                pass


class CoreObservationTests(RunnerTestBase):
    @unittest.skipUnless(os.name == 'nt', 'Windows-only sandbox backend behavior')
    def test_windows_backend_is_forwarded_and_other_config_data_is_never_used(self):
        marker = 'fake-unrelated-config-value'
        self.codex_config.write_text(
            f'model = "{marker}"\n[windows]\nsandbox = "unelevated"\nextra = "{marker}"\n',
            encoding='utf-8')
        code, payload, _ = self.observe('--max-gms', '1', '--dry-run')
        self.assertEqual(code, 0, payload)
        self.assertEqual(payload['route']['windows_sandbox'], 'unelevated')
        route = gm_runner.Route(self.config, self.key_file, 'codex', self.codex_home)
        command = gm_runner.codex_command(route, self.root, self.root / 'r.md',
                                          self.root / 'i.md', self.root / 'c.json', None,
                                          sandbox='workspace-write')
        self.assertIn('windows.sandbox="unelevated"', command)
        self.assertIn('workspace-write', command)
        self.assertNotIn(marker, ' '.join(command) + json.dumps(route.reference()))

    @unittest.skipUnless(os.name == 'nt', 'Windows-only sandbox backend behavior')
    def test_observe_code_and_resume_all_carry_the_backend(self):
        for backend, expected in (('unelevated', 'unelevated'), ('elevated', 'elevated')):
            self.codex_config.write_text(f'[windows]\nsandbox = "{backend}"\n', encoding='utf-8')
            route = gm_runner.Route(self.config, self.key_file, 'codex', self.codex_home)
            command = gm_runner.codex_command(route, self.root, self.root / 'r.md',
                                              self.root / 'i.md', self.root / 'c.json', None,
                                              sandbox='workspace-write')
            self.assertIn(f'windows.sandbox="{expected}"', command)
            self.assertEqual(route.reference()['windows_sandbox'], expected)
        for sandbox, resume in (('read-only', None), ('workspace-write', None),
                                ('read-only', '11111111-2222-3333-4444-555555555555')):
            command = gm_runner.codex_command(route, self.root, self.root / 'r.md',
                                              self.root / 'i.md', self.root / 'c.json', resume,
                                              sandbox=sandbox)
            self.assertIn('windows.sandbox="elevated"', command)
            self.assertIn(sandbox, command)
            if resume:
                self.assertIn(resume, command)

    @unittest.skipUnless(os.name == 'nt', 'Windows-only sandbox backend behavior')
    def test_missing_invalid_or_malformed_backend_fails_before_any_dispatch(self):
        cases = (('model = "x"\n', 'missing'),
                 ('[windows]\nsandbox = "banana"\n', 'invalid'),
                 ('[windows]\nsandbox = "unelev\n', 'malformed'))
        for body, label in cases:
            home = self.root / f'codex-home-{label}'
            home.mkdir()
            (home / 'config.toml').write_text(body, encoding='utf-8')
            calls = len(self.fake_calls())
            code, payload, _ = self.cli('observe', '--state-dir', str(self.root / f'state-{label}'),
                                        '--evidence', str(self.evidence), '--max-gms', '1',
                                        '--dry-run', codex_home=home)
            self.assertEqual(code, 2, payload)
            self.assertEqual(payload['kind'], 'route_preflight')
            self.assertEqual(len(self.fake_calls()), calls)
            self.assertFalse((self.root / f'state-{label}').exists())

    def test_sensitive_invalid_backend_value_is_never_echoed(self):
        sensitive = 'fake-misplaced-secret-value'
        home = self.root / 'codex-home-sensitive'
        home.mkdir()
        (home / 'config.toml').write_text(f'[windows]\nsandbox = "{sensitive}"\n', encoding='utf-8')
        with self.assertRaises(ValueError) as caught:
            gm_runner.read_windows_sandbox_backend(home, is_windows=True)
        self.assertNotIn(sensitive, str(caught.exception))
        if os.name == 'nt':
            code, payload, finished = self.cli(
                'observe', '--state-dir', str(self.root / 'state-sensitive'),
                '--evidence', str(self.evidence), '--max-gms', '1', '--dry-run', codex_home=home)
            self.assertEqual(code, 2, payload)
            self.assertEqual(payload['kind'], 'route_preflight')
            self.assertNotIn(sensitive, json.dumps(payload) + finished.stdout + finished.stderr)

    def test_non_windows_path_needs_no_backend_and_never_forwards_one(self):
        empty = self.root / 'codex-home-nonwindows'
        empty.mkdir()
        self.assertEqual(gm_runner.read_windows_sandbox_backend(empty, is_windows=False), '')
        with self.assertRaises(ValueError):
            gm_runner.read_windows_sandbox_backend(empty, is_windows=True)
        if os.name == 'nt':
            route = gm_runner.Route(self.config, self.key_file, 'codex', self.codex_home)
            route.windows_sandbox = ''  # injected selector outcome: no host backend to carry
            command = gm_runner.codex_command(route, self.root, self.root / 'r.md',
                                              self.root / 'i.md', self.root / 'c.json', None)
            self.assertFalse(any('windows.sandbox' in token for token in command))

    def test_ten_distinct_sessions_stable_prefix_and_usage(self):
        code, payload, _ = self.observe('--max-gms', '10')
        self.assertEqual(code, 0, payload)
        self.assertEqual(payload['dispatched'], 10)
        sessions = self.sessions()
        gm_ids = [f'gm-{index:02d}' for index in range(1, 11)]
        session_ids = [sessions[gm]['session_id'] for gm in gm_ids]
        self.assertEqual(len(set(session_ids)), 10)
        self.assertTrue(all(gm_runner.SESSION_UUID.fullmatch(value) for value in session_ids))
        for result in payload['results']:
            self.assertEqual(result['status'], 'ok')
            self.assertIsNotNone(result['pid'])
            self.assertEqual(result['usage']['input_tokens'], 1200)
            self.assertEqual(result['usage']['cached_input_tokens'], 800)
            self.assertTrue(result['usage_measured'])
            self.assertEqual(result['session_returned'], sessions[result['gm_id']]['session_id'])
        issues = self.issues()
        self.assertEqual(len(issues), 2)
        for issue in issues.values():
            self.assertEqual(sorted(issue['settled']), gm_ids)
            self.assertIsNone(issue['owner_gm'])
        run_dir = self.state / 'runs' / payload['run_id']
        prompts = {gm: (run_dir / f'{gm}.prompt.txt').read_text(encoding='utf-8') for gm in gm_ids}
        prefixes = {prompt.split('[END_COMMON_WORLD_EVIDENCE]')[0] for prompt in prompts.values()}
        self.assertEqual(len(prefixes), 1)
        self.assertEqual(len(set(prompts.values())), 10)
        sample = prompts['gm-01']
        self.assertIn('fixture:town-trade-validation', sample)
        self.assertIn('deterministic offline fixture', sample)
        self.assertIn('[GM_STATE]', sample)
        self.assertLess(sample.index('[END_COMMON_WORLD_EVIDENCE]'), sample.index('[GM_STATE]'))
        self.assertNotIn(FAKE_KEY, sample)

    def test_resume_keeps_session_id_for_each_gm(self):
        first = self.write_evidence('derived-seq3.json',
                                    self.derived_document(8, 3, touch='FIXTURE_NEED_A'))
        code, payload, _ = self.observe('--max-gms', '10', evidence=first)
        self.assertEqual(code, 0, payload)
        after_first = {gm: record['session_id'] for gm, record in self.sessions().items()}
        calls = len(self.fake_calls())
        second = self.write_evidence('derived-seq4.json',
                                     self.derived_document(9, 4, touch='FIXTURE_NEED_B'))
        code, payload, _ = self.observe('--max-gms', '10', evidence=second)
        self.assertEqual(code, 0, payload)
        self.assertEqual(after_first,
                         {gm: record['session_id'] for gm, record in self.sessions().items()})
        for result in payload['results']:
            self.assertEqual(result['resume_requested'], after_first[result['gm_id']])
            self.assertEqual(result['session_returned'], result['resume_requested'])
        self.assertEqual(len([call for call in self.fake_calls()[calls:]
                              if 'resume' in call['argv']]), 10)
        rollouts = list(self.codex_home.glob('sessions/*/*/*/rollout-*.jsonl'))
        self.assertEqual(len(rollouts), 10)

    def test_duplicate_import_deduplicates_and_does_not_reloop(self):
        code, first, _ = self.observe('--max-gms', '1')
        self.assertEqual(code, 0, first)
        self.assertEqual(len(first['import']['created']), 2)
        calls = len(self.fake_calls())
        code, second, _ = self.observe('--max-gms', '1')
        self.assertEqual(code, 0, second)
        self.assertEqual(second['import']['created'], [])
        self.assertEqual(len(second['import']['duplicates']), 2)
        self.assertEqual(second['dispatched'], 0)
        self.assertEqual(len(self.fake_calls()), calls)
        for issue in self.issues().values():
            self.assertEqual(issue['import_count'], 2)

    def test_malformed_sources_are_refused_without_writes(self):
        code, payload, _ = self.observe('--max-gms', '1')
        self.assertEqual(code, 0, payload)
        before = (self.state / gm_runner.STATE_FILE).read_bytes()
        broken = self.root / 'broken.json'
        broken.write_text('{"kind": "background_gm_evidence_snapshot",', encoding='utf-8')
        code, payload, _ = self.observe('--max-gms', '1', evidence=broken)
        self.assertEqual(code, 4, payload)
        wrong_kind = self.write_evidence('wrong-kind.json', self.derived_document(
            9, 4, world_id=None) | {'kind': 'other'})
        code, payload, _ = self.observe('--max-gms', '1', evidence=wrong_kind)
        self.assertEqual(code, 4, payload)
        leaking = self.derived_document(9, 4)
        leaking['boundaries']['contains_private_reply_reason'] = True
        path = self.write_evidence('private-reason.json', leaking)
        code, payload, _ = self.observe('--max-gms', '1', evidence=path)
        self.assertEqual(code, 4, payload)
        miscount = self.derived_document(9, 4)
        miscount['counts'] = {'issues': 0, 'proposals': 9}
        path = self.root / 'counts.json'
        path.write_text(json.dumps(miscount), encoding='utf-8')
        code, payload, _ = self.observe('--max-gms', '1', evidence=path)
        self.assertEqual(code, 4, payload)
        self.assertEqual((self.state / gm_runner.STATE_FILE).read_bytes(), before)
        self.assertEqual(len(self.fake_calls()), 1)

    def test_dry_run_writes_nothing(self):
        code, payload, _ = self.observe('--max-gms', '2', '--dry-run')
        self.assertEqual(code, 0, payload)
        self.assertFalse(self.state.exists())
        self.assertEqual(payload['dispatched'], 0)
        self.assertEqual(payload['plan'][0]['can_dispatch'], True)
        self.assertEqual(self.fake_calls(), [])

    def test_claim_conflict_keeps_one_active_owner(self):
        code, payload, _ = self.observe('--max-gms', '2', mode='claim')
        self.assertEqual(code, 0, payload)
        owners = {issue['owner_gm'] for issue in self.issues().values()}
        self.assertEqual(owners, {'gm-01'})
        conflicts = [conflict for result in payload['results']
                     for conflict in result.get('claim_conflicts', [])]
        self.assertEqual(len(conflicts), 2)
        self.assertTrue(all(conflict['kind'] == 'claim_conflict' and conflict['owner'] == 'gm-01'
                            for conflict in conflicts))

    def test_source_tree_save_and_state_outputs_are_guarded(self):
        save_copy = self.root / 'final-review-3-gm-evidence.protected-copy.json'
        shutil.copyfile(FIXTURE_SAVE, save_copy)
        status_before = subprocess.run(['git', 'status', '--porcelain'], cwd=str(ROOT),
                                       capture_output=True, text=True).stdout
        code, payload, _ = self.observe('--max-gms', '2', '--protect', str(save_copy))
        self.assertEqual(code, 0, payload)
        self.assertEqual(payload['guards']['changed'], [])
        self.assertEqual(gm_runner.sha256_file(save_copy), gm_runner.sha256_file(FIXTURE_SAVE))
        status_after = subprocess.run(['git', 'status', '--porcelain'], cwd=str(ROOT),
                                      capture_output=True, text=True).stdout
        self.assertEqual(status_before, status_after)
        run_dir = self.state / 'runs' / payload['run_id']
        for path in run_dir.rglob('*'):
            if path.is_file():
                self.assertNotIn(FAKE_KEY, path.read_text(encoding='utf-8', errors='replace'))
        self.assertEqual(payload['credential_leak_in_run_dir'], [])
        self.assertFalse(payload['deployed'])
        self.assertEqual(payload['review_state'], 'unapproved')


class IdentityAndRevisionTests(RunnerTestBase):
    def test_two_residents_same_capability_stay_distinct(self):
        document = self.derived_document(8, 3)
        document['proposals'] = [
            self.proposal(0, capability_id='shared_capability', proposal_id='gm_proposal:10',
                          resident_id='fixture:smith'),
            self.proposal(1, capability_id='shared_capability', proposal_id='gm_proposal:11',
                          resident_id='fixture:innkeeper')]
        path = self.write_evidence('same-capability.json', document)
        code, payload, _ = self.observe('--max-gms', '1', evidence=path, mode='no_action')
        self.assertEqual(code, 0, payload)
        issues = self.issues()
        self.assertEqual(len(issues), 2)
        self.assertEqual(sorted(issue['identity_key'] for issue in issues.values()),
                         ['gm_proposal:10', 'gm_proposal:11'])
        self.assertEqual({issue['identity_field'] for issue in issues.values()}, {'proposal_id'})
        self.assertEqual(sorted(issue['resident_id'] for issue in issues.values()),
                         ['fixture:innkeeper', 'fixture:smith'])

    def test_equal_counters_with_changed_content_update_the_same_issue(self):
        first = self.write_evidence('derived-seq3.json', self.derived_document(8, 3))
        code, payload, _ = self.observe('--max-gms', '1', '--gm', 'gm-01', evidence=first)
        self.assertEqual(code, 0, payload)
        digest_before = {issue_id: issue['content_digest']
                         for issue_id, issue in self.issues().items()}
        document = self.derived_document(8, 3)
        updated = self.proposal(0)
        updated['latest'] = dict(updated['latest'], request_id='turn:fixture:smith:0:9',
                                 reason='NEED_REASON_TEXT_UPDATED')
        document['proposals'] = [updated, self.proposal(1)]
        second = self.write_evidence('derived-seq3-updated.json', document)
        code, payload, _ = self.observe('--max-gms', '1', '--gm', 'gm-01', evidence=second)
        self.assertEqual(code, 0, payload)
        self.assertEqual(len(payload['import']['updated']), 1)
        changed = [issue_id for issue_id, issue in self.issues().items()
                   if issue['content_digest'] != digest_before[issue_id]]
        self.assertEqual(len(changed), 1)
        self.assertEqual([entry['issue_id'] for entry in payload['results'][0]['results']],
                         changed)

    def test_older_counters_are_stale_and_closure_is_accepted(self):
        first = self.write_evidence('derived-seq5.json', self.derived_document(10, 5))
        code, payload, _ = self.observe('--max-gms', '1', evidence=first)
        self.assertEqual(code, 0, payload)
        before = (self.state / gm_runner.STATE_FILE).read_bytes()
        older = self.write_evidence('derived-seq3.json', self.derived_document(8, 3))
        code, payload, _ = self.observe('--max-gms', '1', evidence=older)
        self.assertEqual(code, 3, payload)
        self.assertEqual(payload['kind'], 'stale_source')
        self.assertEqual((self.state / gm_runner.STATE_FILE).read_bytes(), before)
        document = self.derived_document(11, 6)
        document['evidence'] = [self.world_issue('closed')]
        closure = self.write_evidence('derived-seq6-closure.json', document)
        code, payload, _ = self.observe('--max-gms', '1', evidence=closure)
        self.assertEqual(code, 0, payload)
        self.assertEqual(self.issue_by_key('collision:well-edge')['lifecycle'], 'closed')


class LifecycleTests(RunnerTestBase):
    def open_issue_evidence(self, life, proposal, status='open'):
        document = self.derived_document(life, proposal)
        document['evidence'] = [self.world_issue(status)]
        return self.write_evidence(f'issue-{status}-{proposal}.json', document)

    def test_closed_issue_stops_dispatch_and_keeps_history(self):
        opened = self.open_issue_evidence(8, 3, 'open')
        code, payload, _ = self.observe('--max-gms', '1', '--gm', 'gm-01', evidence=opened,
                                        mode='claim')
        self.assertEqual(code, 0, payload)
        issue = self.issue_by_key('collision:well-edge')
        self.assertEqual(issue['owner_gm'], 'gm-01')
        self.assertEqual(issue['lifecycle'], 'current')
        self.assertTrue(issue['outcomes'][0]['claim_accepted'])
        closed = self.open_issue_evidence(9, 4, 'closed')
        code, payload, _ = self.observe('--max-gms', '1', '--gm', 'gm-02', '--dry-run',
                                        evidence=closed)
        self.assertEqual(code, 0, payload)
        self.assertNotIn(issue['issue_id'], payload['plan'][0]['slice'])
        code, payload, _ = self.observe('--max-gms', '1', '--gm', 'gm-02', evidence=closed,
                                        mode='claim')
        self.assertEqual(code, 0, payload)
        self.assertTrue(all(entry['issue_id'] != issue['issue_id']
                            for entry in payload['results'][0]['results']))
        issue = self.issue_by_key('collision:well-edge')
        self.assertEqual(issue['lifecycle'], 'closed')
        self.assertEqual(issue['owner_gm'], 'gm-01')
        self.assertEqual(len(issue['outcomes']), 1)

    def test_absent_issue_is_not_reported_as_solved(self):
        opened = self.open_issue_evidence(8, 3, 'open')
        code, payload, _ = self.observe('--max-gms', '1', '--gm', 'gm-01', evidence=opened,
                                        mode='claim')
        self.assertEqual(code, 0, payload)
        absent = self.write_evidence('issue-absent.json', self.derived_document(9, 4))
        code, payload, _ = self.observe('--max-gms', '1', '--gm', 'gm-02', '--dry-run',
                                        evidence=absent)
        self.assertEqual(code, 0, payload)
        issue = self.issue_by_key('collision:well-edge')
        self.assertNotIn(issue['issue_id'], payload['plan'][0]['slice'])
        code, payload, _ = self.observe('--max-gms', '1', '--gm', 'gm-02', evidence=absent)
        self.assertEqual(code, 0, payload)
        self.assertTrue(all(entry['issue_id'] != issue['issue_id']
                            for entry in payload['results'][0]['results']))
        issue = self.issue_by_key('collision:well-edge')
        self.assertEqual(issue['lifecycle'], 'not_in_current_projection')
        self.assertEqual(issue['source_status'], 'open')
        self.assertIsNotNone(issue['absent_since'])
        self.assertIn(issue['issue_id'], payload['import']['absent'])

    def test_unrelated_new_proposal_does_not_wake_settled_no_action(self):
        code, payload, _ = self.observe('--max-gms', '1', '--gm', 'gm-01', mode='no_action')
        self.assertEqual(code, 0, payload)
        self.assertEqual(payload['dispatched'], 1)
        calls = len(self.fake_calls())
        code, payload, _ = self.observe('--max-gms', '1', '--gm', 'gm-01', mode='no_action')
        self.assertEqual(payload['dispatched'], 0)
        self.assertEqual(len(self.fake_calls()), calls)
        document = self.derived_document(7, 2)
        document['proposals'] = [
            self.proposal(0), self.proposal(1),
            self.proposal(1, proposal_id='gm_proposal:3', capability_id='new_capability',
                          resident_id='fixture:guard')]
        path = self.write_evidence('new-proposal.json', document)
        code, payload, _ = self.observe('--max-gms', '1', '--gm', 'gm-01', evidence=path,
                                        mode='no_action')
        self.assertEqual(code, 0, payload)
        self.assertEqual(payload['dispatched'], 1)
        self.assertEqual([entry['issue_id'] for entry in payload['results'][0]['results']],
                         [self.issue_by_key('gm_proposal:3')['issue_id']])

    def test_changed_need_revisits_only_that_need(self):
        code, payload, _ = self.observe('--max-gms', '1', '--gm', 'gm-01', mode='no_action')
        self.assertEqual(code, 0, payload)
        document = self.derived_document(7, 2)
        changed = self.proposal(0)
        changed['latest'] = dict(changed['latest'], reason='NEED_REASON_TEXT_UPDATED')
        document['proposals'] = [changed, self.proposal(1)]
        path = self.write_evidence('changed-need.json', document)
        code, payload, _ = self.observe('--max-gms', '1', '--gm', 'gm-01', evidence=path,
                                        mode='no_action')
        self.assertEqual(code, 0, payload)
        self.assertEqual(payload['dispatched'], 1)
        self.assertEqual([entry['issue_id'] for entry in payload['results'][0]['results']],
                         [self.issue_by_key('gm_proposal:1')['issue_id']])

    def test_state_directory_keeps_one_world(self):
        code, payload, _ = self.observe('--max-gms', '1')
        self.assertEqual(code, 0, payload)
        before = (self.state / gm_runner.STATE_FILE).read_bytes()
        other = self.write_evidence('other-world.json',
                                    self.derived_document(8, 3, world_id='fixture:other-world'))
        code, payload, _ = self.observe('--max-gms', '1', evidence=other)
        self.assertEqual(code, 4, payload)
        self.assertEqual(payload['kind'], 'world_binding_conflict')
        self.assertEqual((self.state / gm_runner.STATE_FILE).read_bytes(), before)
        self.assertEqual({issue['world_id'] for issue in self.issues().values()},
                         {'fixture:town-trade-validation'})
        code, payload, _ = self.observe('--max-gms', '1', '--dry-run', evidence=other)
        self.assertEqual(code, 4, payload)


class OwnershipTests(RunnerTestBase):
    def wait_for_first_call(self, timeout=30):
        deadline = time.time() + timeout
        while time.time() < deadline:
            if self.fake_calls():
                return True
            time.sleep(0.2)
        return False

    def running_pids(self):
        pids = []
        for path in self.state.glob('runs/*/*.process.json'):
            try:
                pids.append(json.loads(path.read_text(encoding='utf-8')).get('pid'))
            except (json.JSONDecodeError, OSError):
                continue
        return pids

    def test_two_contenders_and_live_lock_is_never_displaced(self):
        first = self.observe('--max-gms', '1', '--gm', 'gm-01', '--timeout', '600', mode='hang',
                             wait=False)
        self.assertTrue(self.wait_for_first_call(), 'the fake transport never started')
        code, payload, _ = self.observe('--max-gms', '1', '--gm', 'gm-02')
        self.assertEqual(code, 7, payload)
        self.assertEqual(payload['kind'], 'lock_held')
        code, payload, _ = self.observe('--max-gms', '1', '--gm', 'gm-02', '--break-lock')
        self.assertEqual(code, 7, payload)
        self.assertEqual(payload['kind'], 'lock_held')
        self.assertEqual(len(self.fake_calls()), 1)
        first.terminate()
        first.wait(timeout=15)

    def test_interrupted_in_flight_attempt_survives_and_requires_recovery(self):
        process = self.observe('--max-gms', '1', '--gm', 'gm-01', '--timeout', '600', mode='hang',
                               wait=False)
        self.assertTrue(self.wait_for_first_call(), 'the fake transport never started')
        attempt = self.state_json()['sessions']['gm-01']['attempts'][-1]
        self.assertEqual(attempt['status'], 'running')
        self.assertIsNotNone(attempt['pid'])
        process.terminate()
        process.wait(timeout=15)
        for pid in self.running_pids():
            self.kill_owned_pid(pid)

        code, payload, _ = self.observe('--max-gms', '1', '--gm', 'gm-01')
        self.assertEqual(code, 7, payload)
        code, payload, _ = self.observe('--max-gms', '1', '--gm', 'gm-01', '--break-lock')
        self.assertEqual(code, 5, payload)
        self.assertEqual(payload['kind'], 'unresolved_unknown_cost')
        record = self.sessions()['gm-01']
        self.assertEqual(record['unresolved']['status'], 'interrupted_in_flight')
        self.assertIsNone(record['unresolved']['usage'])
        self.assertFalse(record['unresolved']['usage_measured'])
        attempts_kept = len(record['attempts'])
        calls = len(self.fake_calls())

        code, payload, _ = self.cli('acknowledge', '--state-dir', str(self.state), '--gm', 'gm-01',
                                    '--note', 'offline fake: no reconciliation yet', route=False)
        self.assertEqual(code, 5, payload)
        self.assertEqual(payload['kind'], 'recovery_required')
        self.assertEqual(len(self.fake_calls()), calls)

        code, payload, _ = self.cli('recover', '--state-dir', str(self.state), '--gm', 'gm-01',
                                    '--note', 'offline fake: inspected the run directory',
                                    '--usage', 'no_provider_usage', route=False)
        self.assertEqual(code, 0, payload)
        self.assertTrue(payload['still_blocking'])
        self.assertEqual(self.sessions()['gm-01']['unresolved']['reconciled']['observed_usage'],
                         'no_provider_usage')

        code, payload, _ = self.cli('acknowledge', '--state-dir', str(self.state), '--gm', 'gm-01',
                                    '--note', 'offline fake: reconciled', route=False)
        self.assertEqual(code, 0, payload)
        record = self.sessions()['gm-01']
        self.assertIsNone(record['unresolved'])
        kept = record['acknowledged'][-1]['unresolved']
        self.assertEqual(kept['status'], 'interrupted_in_flight')
        self.assertIsNone(kept['usage'])
        self.assertEqual(len(record['attempts']), attempts_kept)
        self.assertEqual(record['attempts'][-1]['status'], 'interrupted_in_flight')

        code, payload, _ = self.observe('--max-gms', '1', '--gm', 'gm-01', mode='ok')
        self.assertEqual(code, 0, payload)
        self.assertEqual(payload['dispatched'], 1)
        self.assertEqual(len(self.sessions()['gm-01']['attempts']), attempts_kept + 1)

    def test_state_is_one_atomic_file_and_legacy_layout_refused(self):
        code, payload, _ = self.observe('--max-gms', '1')
        self.assertEqual(code, 0, payload)
        self.assertTrue((self.state / gm_runner.STATE_FILE).is_file())
        for name in gm_runner.LEGACY_STATE_FILES:
            self.assertFalse((self.state / name).exists())
        legacy = self.root / 'legacy-state'
        legacy.mkdir()
        (legacy / 'registry.json').write_text('{"issues": {}}', encoding='utf-8')
        code, payload, _ = self.observe('--max-gms', '1', state_dir=legacy)
        self.assertEqual(code, 2, payload)
        self.assertEqual(payload['kind'], 'preflight')


class PaidBoundaryTests(RunnerTestBase):
    def claim_an_issue(self):
        code, payload, _ = self.observe('--max-gms', '1', '--gm', 'gm-01', mode='claim')
        self.assertEqual(code, 0, payload)
        return sorted(self.issues())[0]

    def test_unknown_cost_stops_further_paid_dispatch(self):
        issue_id = self.claim_an_issue()
        calls = len(self.fake_calls())
        code, payload, _ = self.observe('--max-gms', '4', modes={'gm-02': 'no_usage'})
        self.assertEqual(code, 1, payload)
        self.assertEqual(payload['aborted_by'], 'gm-02:usage_incomplete')
        statuses = {result['gm_id']: result['status'] for result in payload['results']}
        self.assertEqual(statuses['gm-01'], 'skipped_no_open_issue')
        self.assertEqual(statuses['gm-02'], 'usage_incomplete')
        self.assertEqual(statuses['gm-03'], 'skipped_after_run_abort')
        self.assertEqual(statuses['gm-04'], 'skipped_after_run_abort')
        self.assertEqual(len(self.fake_calls()), calls + 1)
        unresolved = self.sessions()['gm-02']['unresolved']
        self.assertEqual(unresolved['kind'], 'unknown_cost')
        self.assertIsNone(unresolved['usage'])
        self.assertFalse(unresolved['usage_measured'])

        code, payload, _ = self.observe('--max-gms', '1', '--gm', 'gm-03')
        self.assertEqual(code, 5, payload)
        self.assertEqual(payload['kind'], 'unresolved_unknown_cost')
        head = self.head_sha()
        scope = self.write_scope(issue_id, head)
        code, payload, _ = self.cli('code', '--state-dir', str(self.state), '--issue', issue_id,
                                    '--scope-file', str(scope), '--base-revision', head,
                                    '--dry-run')
        self.assertEqual(code, 5, payload)
        self.assertEqual(payload['kind'], 'unresolved_unknown_cost')
        self.assertEqual(len(self.fake_calls()), calls + 1)

        code, payload, _ = self.cli('acknowledge', '--state-dir', str(self.state), '--gm', 'gm-02',
                                    '--note', 'offline fake: not reconciled', route=False)
        self.assertEqual(code, 5, payload)
        code, payload, _ = self.cli('recover', '--state-dir', str(self.state), '--gm', 'gm-02',
                                    '--note', 'offline fake: checked the provider ledger',
                                    '--usage', 'external_ledger', route=False)
        self.assertEqual(code, 0, payload)
        code, payload, _ = self.cli('acknowledge', '--state-dir', str(self.state), '--gm', 'gm-02',
                                    '--note', 'offline fake: reconciled', route=False)
        self.assertEqual(code, 0, payload)
        record = self.sessions()['gm-02']
        self.assertIsNone(record['unresolved'])
        self.assertTrue(record['acknowledged'][-1]['usage_kept_unknown'])
        self.assertEqual(record['acknowledged'][-1]['unresolved']['kind'], 'unknown_cost')
        code, payload, _ = self.observe('--max-gms', '1', '--gm', 'gm-03')
        self.assertEqual(code, 0, payload)
        self.assertEqual(payload['dispatched'], 1)

    def test_measured_failure_isolates_only_that_gm(self):
        code, payload, _ = self.observe('--max-gms', '3', modes={'gm-02': 'bad_contract'})
        self.assertEqual(code, 1, payload)
        statuses = {result['gm_id']: result['status'] for result in payload['results']}
        self.assertEqual(statuses['gm-01'], 'ok')
        self.assertEqual(statuses['gm-02'], 'invalid_output')
        self.assertEqual(statuses['gm-03'], 'ok')
        self.assertIsNone(payload['aborted_by'])
        failed = [result for result in payload['results'] if result['gm_id'] == 'gm-02'][0]
        self.assertEqual(failed['cost'], 'measured')
        self.assertTrue(failed['usage_measured'])
        self.assertEqual(failed['usage']['input_tokens'], 1200)
        self.assertEqual(self.sessions()['gm-02']['unresolved']['kind'], 'measured_failure')
        code, payload, _ = self.observe('--max-gms', '1', '--gm', 'gm-02')
        self.assertEqual(code, 5, payload)
        self.assertEqual(payload['kind'], 'unresolved_prior_attempt')
        code, payload, _ = self.cli('acknowledge', '--state-dir', str(self.state), '--gm', 'gm-02',
                                    '--note', 'offline fake: measured output failure', route=False)
        self.assertEqual(code, 0, payload)
        self.assertIsNone(self.sessions()['gm-02']['unresolved'])

    def test_local_preflight_failure_is_not_paid_and_does_not_stop_others(self):
        code, payload, _ = self.observe('--max-gms', '1', '--gm', 'gm-01')
        self.assertEqual(code, 0, payload)
        state = self.state_json()
        state['sessions']['gm-01']['session_id'] = 'not-a-uuid'
        (self.state / gm_runner.STATE_FILE).write_text(json.dumps(state), encoding='utf-8')
        changed = self.write_evidence('local-preflight-changed.json',
                                      self.derived_document(8, 3, touch='FIXTURE_NEED_C'))
        calls = len(self.fake_calls())
        code, payload, _ = self.observe('--max-gms', '2', evidence=changed)
        self.assertEqual(code, 1, payload)
        statuses = {result['gm_id']: result['status'] for result in payload['results']}
        self.assertEqual(statuses['gm-01'], 'resume_preflight_failed')
        self.assertEqual(statuses['gm-02'], 'ok')
        failed = [result for result in payload['results'] if result['gm_id'] == 'gm-01'][0]
        self.assertEqual(failed['cost'], 'none')
        self.assertEqual(failed['dispatched'], False)
        self.assertIsNone(self.sessions()['gm-01']['unresolved'])
        self.assertEqual(len(self.fake_calls()), calls + 1)


class CodingTests(RunnerTestBase):
    def prepare(self, mode='claim'):
        code, payload, _ = self.observe('--max-gms', '1', '--gm', 'gm-01', mode=mode)
        self.assertEqual(code, 0, payload)
        return sorted(self.issues())

    def test_unclaimed_or_unknown_issue_cannot_code(self):
        issue_ids = self.prepare(mode='ok')
        head = self.head_sha()
        scope = self.write_scope(issue_ids[0], head)
        code, payload, _ = self.cli('code', '--state-dir', str(self.state), '--issue', issue_ids[0],
                                    '--scope-file', str(scope), '--base-revision', head)
        self.assertEqual(code, 6, payload)
        self.assertEqual(payload['kind'], 'issue_not_claimed_by_registered_gm')
        code, payload, _ = self.cli('code', '--state-dir', str(self.state), '--issue', issue_ids[0],
                                    '--scope-file', str(scope), '--base-revision', head, '--dry-run')
        self.assertEqual(code, 6, payload)
        self.assertFalse((self.state / 'candidates').exists())
        self.assertEqual(len(self.fake_calls()), 1)

    def test_scope_and_base_mismatch_are_refused(self):
        issue_id = self.prepare()[0]
        head = self.head_sha()
        good = self.write_scope(issue_id, head)
        code, payload, _ = self.cli('code', '--state-dir', str(self.state), '--issue', issue_id,
                                    '--scope-file', str(good), '--base-revision', head, '--dry-run')
        self.assertEqual(code, 0, payload)
        self.assertEqual(payload['base_sha'], head)
        self.assertEqual(payload['dispatched'], 0)
        self.assertEqual(payload['coding_session']['mode'], 'new')
        self.write_scope(issue_id, head,
                         base_revision='deadbeefdeadbeefdeadbeefdeadbeefdeadbeef')
        code, payload, _ = self.cli('code', '--state-dir', str(self.state), '--issue', issue_id,
                                    '--scope-file', str(self.root / 'scope.json'),
                                    '--base-revision', head)
        self.assertEqual(code, 6, payload)
        self.assertEqual(payload['kind'], 'scope_base_mismatch')
        self.write_scope(issue_id, head, files=['../escape.py'])
        code, payload, _ = self.cli('code', '--state-dir', str(self.state), '--issue', issue_id,
                                    '--scope-file', str(self.root / 'scope.json'),
                                    '--base-revision', head)
        self.assertEqual(code, 6, payload)
        self.write_scope(issue_id, head, objective='too short')
        code, payload, _ = self.cli('code', '--state-dir', str(self.state), '--issue', issue_id,
                                    '--scope-file', str(self.root / 'scope.json'),
                                    '--base-revision', head)
        self.assertEqual(code, 6, payload)
        self.write_scope(issue_id, head, owner_gm='gm-09')
        code, payload, _ = self.cli('code', '--state-dir', str(self.state), '--issue', issue_id,
                                    '--scope-file', str(self.root / 'scope.json'),
                                    '--base-revision', head)
        self.assertEqual(code, 6, payload)
        self.assertEqual(payload['kind'], 'scope_owner_mismatch')
        self.write_scope(issue_id, head)
        unknown_scope = self.write_scope('issue-ffffffffffff', head, name='scope-unknown.json')
        code, payload, _ = self.cli('code', '--state-dir', str(self.state),
                                    '--issue', 'issue-ffffffffffff',
                                    '--scope-file', str(unknown_scope),
                                    '--base-revision', head)
        self.assertEqual(code, 2, payload)
        self.assertEqual(payload['kind'], 'unknown_issue')
        code, payload, _ = self.cli('code', '--state-dir', str(self.state), '--issue', issue_id,
                                    '--scope-file', str(self.root / 'scope.json'),
                                    '--base-revision', 'no-such-ref')
        self.assertEqual(code, 6, payload)
        self.assertEqual(payload['kind'], 'unknown_base_revision')
        self.assertFalse((self.state / 'candidates').exists())
        self.assertEqual(len(self.fake_calls()), 1)

    def test_coding_links_to_owner_gm_and_guards_the_candidate(self):
        issue_id = self.prepare()[0]
        head = self.head_sha()
        save_copy = self.root / 'final-review-3-gm-evidence.protected-copy.json'
        shutil.copyfile(FIXTURE_SAVE, save_copy)
        status_before = subprocess.run(['git', 'status', '--porcelain'], cwd=str(ROOT),
                                       capture_output=True, text=True).stdout
        scope = self.write_scope(issue_id, head, test_commands=[
            [sys.executable, '-c',
             "import os;print('KEY=' + str(os.environ.get('DEEPSEEK_API_KEY')))"],
            [sys.executable, '-c', "print('scope test ok')"]])
        code, payload, _ = self.cli('code', '--state-dir', str(self.state), '--issue', issue_id,
                                    '--scope-file', str(scope), '--base-revision', head,
                                    '--protect', str(save_copy), '--run-scope-tests')
        self.assertEqual(code, 0, payload)
        candidate = Path(payload['candidate'])
        self.worktrees.append(candidate)
        self.assertTrue(candidate.is_dir())
        self.assertEqual(payload['owner_gm'], 'gm-01')
        self.assertEqual(payload['base_sha'], head)
        self.assertEqual(payload['candidate_head'], head)
        self.assertEqual(payload['observed_changed_files'], [])
        self.assertEqual(payload['out_of_scope_changes'], [])
        self.assertEqual([test['exit_code'] for test in payload['scope_tests']], [0, 0])
        self.assertIn('KEY=None', payload['scope_tests'][0]['stdout_tail'])
        self.assertNotIn(FAKE_KEY, json.dumps(payload['scope_tests']))
        self.assertEqual(payload['guards']['changed'], [])
        self.assertEqual(payload['credential_leak_in_run_dir'], [])
        self.assertEqual(payload['review_state'], 'unapproved')
        self.assertFalse(payload['deployed'])
        issue = self.issues()[issue_id]
        self.assertEqual(issue['coding_owner_gm'], 'gm-01')
        self.assertIsNotNone(issue['coding_session_id'])
        self.assertEqual(issue['outcomes'][-1]['kind'], 'coding')
        self.assertEqual(issue['outcomes'][-1]['gm_id'], 'gm-01')
        self.assertEqual(issue['candidates'][-1]['review_state'], 'unapproved')
        record = self.sessions()['gm-01']
        self.assertEqual(record['coding']['issue_id'], issue_id)
        self.assertEqual(record['coding']['session_id'], issue['coding_session_id'])
        self.assertEqual(record['coding']['last_status'], 'ok')
        self.assertEqual(record['outcomes'][-1]['kind'], 'coding')
        self.assertEqual(record['outcomes'][-1]['issue_id'], issue_id)
        self.assertEqual(gm_runner.sha256_file(save_copy), gm_runner.sha256_file(FIXTURE_SAVE))
        status_after = subprocess.run(['git', 'status', '--porcelain'], cwd=str(ROOT),
                                      capture_output=True, text=True).stdout
        self.assertEqual(status_before, status_after)
        code, payload, _ = self.cli('code', '--state-dir', str(self.state), '--issue', issue_id,
                                    '--scope-file', str(scope), '--base-revision', head, '--dry-run')
        self.assertEqual(code, 0, payload)
        self.assertEqual(payload['coding_session']['mode'], 'resume')

    def test_out_of_scope_change_and_worker_commit_are_failures(self):
        issue_a, issue_b = self.prepare()[:2]
        head = self.head_sha()
        scope_a = self.write_scope(issue_a, head, name='scope-a.json')
        code, payload, _ = self.cli('code', '--state-dir', str(self.state), '--issue', issue_a,
                                    '--scope-file', str(scope_a), '--base-revision', head,
                                    modes={'gm-01': 'out_of_scope'})
        self.assertEqual(code, 1, payload)
        self.assertEqual(payload['status'], 'out_of_scope_change')
        self.assertEqual(payload['out_of_scope_changes'], ['game/rogue-note.txt'])
        self.assertEqual(payload['review_state'], 'unapproved')
        self.assertFalse(payload['deployed'])
        self.worktrees.append(Path(payload['candidate']))
        self.assertEqual(self.issues()[issue_a]['coding_unresolved']['kind'], 'measured_failure')
        code, payload, _ = self.cli('acknowledge', '--state-dir', str(self.state), '--gm', 'gm-01',
                                    '--note', 'offline fake: out-of-scope failure reviewed',
                                    route=False)
        self.assertEqual(code, 0, payload)
        scope_b = self.write_scope(issue_b, head, name='scope-b.json')
        code, payload, _ = self.cli('code', '--state-dir', str(self.state), '--issue', issue_b,
                                    '--scope-file', str(scope_b), '--base-revision', head,
                                    modes={'gm-01': 'commit'})
        self.assertEqual(code, 1, payload)
        self.assertEqual(payload['status'], 'worker_committed')
        self.worktrees.append(Path(payload['candidate']))
        self.assertNotEqual(payload['candidate_head'], head)
        main_head = subprocess.run(['git', 'rev-parse', 'HEAD'], cwd=str(ROOT), capture_output=True,
                                   text=True).stdout.strip()
        self.assertEqual(main_head, head)


class CodingContinuityTests(RunnerTestBase):
    """Coding-failure continuity: interrupted coder, test failure/timeout, missing transport."""

    def prepare(self, mode='claim'):
        code, payload, _ = self.observe('--max-gms', '1', '--gm', 'gm-01', mode=mode)
        self.assertEqual(code, 0, payload)
        return sorted(self.issues())

    def test_running_coding_attempt_is_recovered_and_gates_other_gms(self):
        issue_a = self.prepare()[0]
        head = self.head_sha()
        scope = self.write_scope(issue_a, head)
        calls_before = len(self.fake_calls())
        process = self.cli('code', '--state-dir', str(self.state), '--issue', issue_a,
                           '--scope-file', str(scope), '--base-revision', head, '--timeout', '600',
                           mode='hang', wait=False)
        deadline = time.time() + 30
        while time.time() < deadline and len(self.fake_calls()) <= calls_before:
            time.sleep(0.2)
        self.assertGreater(len(self.fake_calls()), calls_before,
                           'the coding transport never started')
        persisted = self.state_json()
        attempt = persisted['issues'][issue_a]['coding_attempt']
        self.assertEqual(attempt['status'], 'running')
        self.assertIsNotNone(attempt['pid'])
        self.assertEqual(persisted['sessions']['gm-01']['coding']['last_status'], 'running')
        run_id = attempt['run_id']
        pid = attempt['pid']
        calls = len(self.fake_calls())
        process.terminate()
        process.wait(timeout=15)
        self.kill_owned_pid(pid)

        code, payload, _ = self.observe('--max-gms', '1', '--gm', 'gm-02')
        self.assertEqual(code, 7, payload)
        code, payload, _ = self.observe('--max-gms', '1', '--gm', 'gm-02', '--break-lock')
        self.assertEqual(code, 5, payload)
        self.assertEqual(payload['kind'], 'unresolved_unknown_cost')
        self.assertIn('gm-01', payload['gms'])
        self.assertEqual(len(self.fake_calls()), calls,
                         'another GM must not be paid while a coder is unclassified')
        code, payload, _ = self.cli('code', '--state-dir', str(self.state), '--issue', issue_a,
                                    '--scope-file', str(scope), '--base-revision', head, '--dry-run')
        self.assertEqual(code, 5, payload)

        persisted = self.state_json()
        attempt = persisted['issues'][issue_a]['coding_attempt']
        self.assertEqual(attempt['status'], 'interrupted_in_flight')
        self.assertEqual(attempt['run_id'], run_id)
        self.assertEqual(attempt['pid'], pid)
        coding = persisted['issues'][issue_a]['coding_unresolved']
        self.assertEqual(coding['kind'], 'unknown_cost')
        self.assertEqual(coding['owner_gm'], 'gm-01')
        self.assertIsNone(coding['usage'])
        self.assertFalse(coding['usage_measured'])
        owner = persisted['sessions']['gm-01']
        self.assertEqual(owner['unresolved']['kind'], 'unknown_cost')
        self.assertEqual(owner['unresolved']['source'], f'coding:{issue_a}')
        self.assertEqual(owner['coding']['attempts'][-1]['status'], 'interrupted_in_flight')
        self.assertEqual(owner['outcomes'][-1]['status'], 'interrupted_in_flight')

        code, payload, _ = self.cli('acknowledge', '--state-dir', str(self.state), '--gm', 'gm-01',
                                    '--note', 'offline fake: no reconciliation yet', route=False)
        self.assertEqual(code, 5, payload)
        code, payload, _ = self.cli('recover', '--state-dir', str(self.state), '--gm', 'gm-01',
                                    '--note', 'offline fake: inspected the coding run',
                                    '--usage', 'no_provider_usage', route=False)
        self.assertEqual(code, 0, payload)
        self.assertEqual(payload['reconciled_issues'], [issue_a])
        code, payload, _ = self.cli('acknowledge', '--state-dir', str(self.state), '--gm', 'gm-01',
                                    '--note', 'offline fake: reconciled coding interruption',
                                    route=False)
        self.assertEqual(code, 0, payload)
        self.assertEqual(payload['released_issues'], [issue_a])
        persisted = self.state_json()
        self.assertIsNone(persisted['sessions']['gm-01']['unresolved'])
        self.assertIsNone(persisted['issues'][issue_a]['coding_unresolved'])
        kept = persisted['issues'][issue_a]['coding_acknowledged'][-1]['unresolved']
        self.assertEqual(kept['status'], 'interrupted_in_flight')
        self.assertIsNone(kept['usage'])

        code, payload, _ = self.observe('--max-gms', '1', '--gm', 'gm-02')
        self.assertEqual(code, 0, payload)
        self.assertEqual(payload['dispatched'], 1)
        code, payload, _ = self.cli('code', '--state-dir', str(self.state), '--issue', issue_a,
                                    '--scope-file', str(scope), '--base-revision', head, '--dry-run')
        self.assertEqual(code, 0, payload)

    def test_scope_test_failure_keeps_session_and_is_repairable(self):
        issue_a = self.prepare()[0]
        head = self.head_sha()
        failing = self.write_scope(issue_a, head, name='scope-failing.json', test_commands=[
            [sys.executable, '-c', "import sys; sys.exit(1)"]])
        code, payload, _ = self.cli('code', '--state-dir', str(self.state), '--issue', issue_a,
                                    '--scope-file', str(failing), '--base-revision', head,
                                    '--run-scope-tests')
        self.assertEqual(code, 1, payload)
        self.assertEqual(payload['status'], 'scope_tests_failed')
        self.assertTrue(payload['usage_measured'])
        self.assertEqual(payload['usage']['input_tokens'], 1200)
        self.assertTrue(payload['session_bound'])
        session = payload['session_returned']
        self.assertRegex(session, gm_runner.SESSION_UUID.pattern)
        self.assertEqual(payload['scope_tests'][0]['exit_code'], 1)
        self.assertFalse(payload['scope_tests'][0]['timed_out'])
        self.assertFalse(payload['deployed'])
        self.assertEqual(payload['review_state'], 'unapproved')
        self.worktrees.append(Path(payload['candidate']))
        issue = self.issues()[issue_a]
        self.assertEqual(issue['coding_session_id'], session)
        self.assertIsNone(issue['coding_attempt'])
        unresolved = issue['coding_unresolved']
        self.assertEqual(unresolved['kind'], 'measured_failure')
        self.assertEqual(unresolved['cost'], 'measured')
        self.assertTrue(unresolved['repairable'])
        self.assertEqual(unresolved['usage']['output_tokens'], 60)
        self.assertEqual(unresolved['session_id'], session)
        owner = self.sessions()['gm-01']
        self.assertEqual(owner['unresolved']['kind'], 'measured_failure')
        self.assertTrue(owner['unresolved']['usage_measured'])
        self.assertEqual(owner['coding']['session_id'], session)
        first_candidate = issue['candidates'][-1]
        self.assertEqual(first_candidate['status'], 'scope_tests_failed')

        code, payload, _ = self.cli('acknowledge', '--state-dir', str(self.state), '--gm', 'gm-01',
                                    '--note', 'offline fake: failing scope test reviewed',
                                    route=False)
        self.assertEqual(code, 0, payload)
        self.assertEqual(payload['released_issues'], [issue_a])
        passing = self.write_scope(issue_a, head, name='scope-passing.json')
        code, payload, _ = self.cli('code', '--state-dir', str(self.state), '--issue', issue_a,
                                    '--scope-file', str(passing), '--base-revision', head,
                                    '--run-scope-tests')
        self.assertEqual(code, 0, payload)
        self.assertEqual(payload['session_requested'], session)
        self.assertEqual(payload['session_returned'], session)
        resumed = [call for call in self.fake_calls() if 'resume' in call['argv']]
        self.assertEqual(resumed[-1]['argv'][resumed[-1]['argv'].index('resume') + 1], session)
        rollout = self.codex_home / 'sessions' / '2026' / '09' / '12' / \
            f'rollout-2026-09-12T00-00-00-{session}.jsonl'
        self.assertEqual(len(rollout.read_text(encoding='utf-8').splitlines()), 2)
        issue = self.issues()[issue_a]
        self.assertIsNone(issue['coding_unresolved'])
        self.assertEqual([entry['status'] for entry in issue['candidates']],
                         ['scope_tests_failed', 'ok'])
        self.assertEqual(issue['coding_acknowledged'][-1]['unresolved']['status'],
                         'scope_tests_failed')
        self.assertEqual(issue['coding_acknowledged'][-1]['unresolved']['usage']['input_tokens'],
                         1200)

    def test_scope_test_timeout_is_measured_not_unknown(self):
        issue_a = self.prepare()[0]
        head = self.head_sha()
        hanging = self.write_scope(issue_a, head, name='scope-hanging.json', test_commands=[
            [sys.executable, '-c', 'import time; time.sleep(45)']])
        code, payload, _ = self.cli('code', '--state-dir', str(self.state), '--issue', issue_a,
                                    '--scope-file', str(hanging), '--base-revision', head,
                                    '--run-scope-tests', '--timeout', '30', timeout=300)
        self.assertEqual(code, 1, payload)
        self.assertEqual(payload['status'], 'scope_tests_failed')
        self.assertTrue(payload['session_bound'])
        self.assertTrue(payload['usage_measured'])
        self.assertIsNone(payload['scope_tests'][0]['exit_code'])
        self.assertTrue(payload['scope_tests'][0]['timed_out'])
        self.worktrees.append(Path(payload['candidate']))
        issue = self.issues()[issue_a]
        self.assertIsNone(issue['coding_attempt'])
        self.assertEqual(issue['coding_unresolved']['kind'], 'measured_failure')
        self.assertEqual(issue['coding_unresolved']['usage']['input_tokens'], 1200)
        self.assertEqual(self.sessions()['gm-01']['unresolved']['cost'], 'measured')
        self.assertEqual(gm_runner.global_unknown_gms(self.state_json()), [],
                         'a measured local test timeout is not an unknown paid call')
        code, payload, _ = self.observe('--max-gms', '1', '--gm', 'gm-02')
        self.assertEqual(code, 0, payload)
        self.assertEqual(payload['dispatched'], 1)

    def test_missing_transport_executable_in_coding_path(self):
        issue_a = self.prepare()[0]
        head = self.head_sha()
        scope = self.write_scope(issue_a, head, name='scope-missing-transport.json')
        missing = str(self.root / 'no-such-transport' / 'codex-missing.exe')
        code, payload, _ = self.cli('code', '--state-dir', str(self.state), '--issue', issue_a,
                                    '--scope-file', str(scope), '--base-revision', head,
                                    codex=missing)
        self.assertEqual(code, 1, payload)
        self.assertEqual(payload['status'], 'transport_unavailable')
        self.assertEqual(payload['cost'], 'none')
        self.assertFalse(payload['provider_request_started'])
        self.assertFalse(payload['session_bound'])
        self.assertIsNone(payload['session_returned'])
        self.assertIsNone(payload['usage'])
        self.assertFalse(payload['usage_measured'])
        issue = self.issues()[issue_a]
        self.assertIsNone(issue['coding_attempt'])
        self.assertIsNone(issue['coding_unresolved'])
        self.assertEqual(issue['coding_scope_state']['status'], 'transport_unavailable')
        self.assertEqual(list((self.state / 'runs').glob('*/coding.process.json')), [])
        self.assertEqual(gm_runner.global_unknown_gms(self.state_json()), [])
        code, payload, _ = self.observe('--max-gms', '1', '--gm', 'gm-02')
        self.assertEqual(code, 0, payload)
        self.assertEqual(payload['dispatched'], 1)


if __name__ == '__main__':
    unittest.main(verbosity=2)
