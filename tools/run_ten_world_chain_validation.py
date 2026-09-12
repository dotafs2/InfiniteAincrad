#!/usr/bin/env python3
"""OFFLINE ten-resident / ten-GM integration with real runtime consequences.

All resident decisions and GM replies are explicitly scripted fixtures. No model
API, credential file, budget ledger or production provider is used. The real GM
runner executes a local fixture subprocess, isolates a concrete release manifest
in a git worktree, runs its declared validator and leaves it unapproved. This
harness performs a narrowly specified supervisor review before the real Godot
runtime installs an EXISTING finite-source capability from an accepted private
need. It does not prove autonomous GM development, real 10+10, scene visibility,
body movement, or versioned executable-code deployment.

Run with --phase prepare, gm, finish to coordinate the single engine slot. Each
run owns a fresh output directory; failures remain there and never reset a world.
"""
from __future__ import annotations

import argparse
from contextlib import contextmanager, redirect_stdout
import copy
import hashlib
import io
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import uuid

ROOT = Path(__file__).resolve().parents[1]
ALLOWED_ROOT = ROOT / 'tmp/gpt6-sprint/integration'
MANIFEST_REL = 'tools/offline_chain_material_release.json'
PROVENANCE = 'offline_scripted_transport_no_model_api'
LIMITS = [
    'Resident decisions and GM proposals/candidate are scripted, not model-generated.',
    'This releases configuration of an existing finite-source rule, not new GM code.',
    'Godot assertions prove runtime effects and save continuation; no rendered scene or body travel is tested.',
    'Material sensing is explicitly existing proximity sensing, not line of sight.',
    'GM runner usage fields are synthetic zero fixture counters; provider_request_started means only a local fixture subprocess was started.',
    'No real Kimi/DeepSeek request, paid run, accounting reset or original town restoration.',
]
RUNTIME_FILES = ['game/core/town_runtime.gd', 'game/core/town_materials.gd',
                 'game/core/town_trade.gd', 'game/core/town_life.gd',
                 'game/agents/town_turns.gd', 'game/tests/town_chain_release_probe.gd']


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def write(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def require(condition, message):
    if not condition:
        raise ValueError(message)


def same_saved_values(first, second):
    """Old probe JSON rounded doubles; allow only sub-nanosecond/unit roundoff.

    New evidence writes full precision. This is not used to validate source hashes,
    candidate authorization, resident identity, material counts or byte retention.
    """
    if isinstance(first, bool) or isinstance(second, bool):
        return type(first) is type(second) and first == second
    if isinstance(first, (int, float)) and isinstance(second, (int, float)):
        return abs(first - second) <= 1e-9
    if isinstance(first, dict) and isinstance(second, dict):
        return first.keys() == second.keys() and all(same_saved_values(first[key], second[key]) for key in first)
    if isinstance(first, list) and isinstance(second, list):
        return len(first) == len(second) and all(same_saved_values(a, b) for a, b in zip(first, second))
    return type(first) is type(second) and first == second


def snapshot_from(out, stage):
    return read(out / f'{stage}.json')['evidence']['snapshot']


def validate_candidate(manifest, evidence, save, owner='gm-05', issue_id=None):
    """Validate consequence-bearing inputs, not a candidate's own success claims."""
    require(type(manifest.get('schema_version')) is int and manifest['schema_version'] == 1, 'manifest schema required')
    require(manifest.get('provenance') == PROVENANCE, 'offline provenance must be explicit')
    require(manifest.get('delivery_kind') == 'existing_finite_source_configuration', 'existing-capability release only')
    require(manifest.get('world_id') == save['world_id'] == evidence['world_id'], 'world binding mismatch')
    require(manifest.get('owner_gm') == owner, 'GM owner mismatch')
    if issue_id:
        require(manifest.get('issue_id') == issue_id, 'issue ownership binding mismatch')
    proposal = evidence['proposals'][0]
    require(type(manifest.get('source_seq')) is int and type(proposal['first'].get('source_sequence')) is int
            and type(proposal['first'].get('controller_epoch')) is int, 'source sequence and epoch must be real integers')
    require(proposal['resident_id'] == 'shared:smith', 'must use actual smith need')
    require(manifest.get('source_resident_id') == proposal['resident_id'], 'source actor mismatch')
    require(manifest.get('source_request_id') == proposal['first']['request_id'], 'source request mismatch')
    require(manifest.get('source_seq') == proposal['first']['source_sequence'], 'source sequence mismatch')
    history = save['godot']['resident_turns'][proposal['resident_id']]['history']
    matching = [entry for entry in history if entry.get('need_request_id') == manifest['source_request_id']]
    require(len(matching) == 1 and matching[0].get('need', {}).get('reason') == proposal['first']['reason'],
            'accepted canonical private need missing or changed')
    accepted = matching[0]
    require(accepted.get('command_id') == manifest['source_request_id'], 'canonical accepted command identity mismatch')
    require(type(accepted.get('need_source_sequence')) is int and accepted['need_source_sequence'] == manifest['source_seq'],
            'canonical accepted source sequence mismatch')
    require(type(accepted.get('need_controller_epoch')) is int and accepted['need_controller_epoch'] == proposal['first'].get('controller_epoch'),
            'canonical accepted controller epoch mismatch')
    require(accepted.get('need', {}).get('capability_id') == proposal.get('capability_id') == 'finite_iron_supply',
            'canonical accepted capability mismatch')
    require(accepted.get('status') == 'settled' and accepted.get('result', {}).get('ok') is True
            and accepted.get('provenance') == 'opengameagent_fixture', 'successful offline accepted turn required')
    require(accepted.get('action') == 'wait' and accepted.get('result', {}).get('code') == 'wait'
            and isinstance(accepted.get('model_choice'), str) and isinstance(accepted.get('reason'), str),
            'canonical scripted private wait-and-need turn required')
    require(manifest.get('evidence_refs') == ['/proposals/0'], 'exact evidence pointer required')
    spec = manifest.get('spec', {})
    require(set(spec) == {'id', 'label', 'material', 'initial_stock', 'position', 'access'}, 'material spec keys mismatch')
    require(spec['id'] == 'offline-chain:iron-offcuts' and spec['material'] == 'iron' and spec['access'] == 'public',
            'only one finite public iron source is in reviewed scope')
    require(spec['label'] == 'Public finite iron offcuts', 'reviewed human-readable source label required')
    require(type(spec['initial_stock']) is int and spec['initial_stock'] == 3, 'only declared grant of three finite units is approved')
    point = save['godot']['positions']['shared:smith']
    require(spec['position'] == [point[0], point[1], point[2] + 0.2], 'source placement must be bound to selected nearby position')
    require(len(save['residents']) == 10, 'ten persistent identities required')
    require(all(row['iron'] == 0 for row in save['life']['accounts']), 'pre-release world must retain actual zero-iron genesis')
    return True


def offline_transport(argv):
    """Local transport for real gm_runner; no network libraries or model invocation."""
    parser = argparse.ArgumentParser()
    parser.add_argument('--result', type=Path, required=True)
    parser.add_argument('--resume')
    args = parser.parse_args(argv)
    prompt = sys.stdin.read()
    def section(name):
        found = re.search(r'\[' + name + r'\]\n(.*?)\n\[END_' + name + r'\]', prompt, re.S)
        return json.loads(found.group(1)) if found else None
    coding = section('CODING_SCOPE')
    context = coding or section('GM_STATE')
    require(context is not None, 'real GM prompt context missing')
    session = args.resume or str(uuid.uuid4())
    home = Path(os.environ['OFFLINE_CHAIN_HOME'])
    rollout = home / 'sessions/2026/09/12' / f'rollout-offline-{session}.jsonl'
    rollout.parent.mkdir(parents=True, exist_ok=True)
    with rollout.open('a', encoding='utf-8') as stream:
        stream.write(json.dumps({'provenance': PROVENANCE, 'gm_id': context['gm_id'],
                                 'prompt_sha256': hashlib.sha256(prompt.encode()).hexdigest()}) + '\n')
    if coding:
        manifest = copy.deepcopy(coding['scope']['offline_release_manifest'])
        require(manifest['owner_gm'] == context['gm_id'], 'candidate writer differs from attributed owner')
        require(manifest['issue_id'] == context['open_issues'][0]['issue_id'], 'coding issue mismatch')
        write(Path.cwd() / MANIFEST_REL, manifest)
        answer = {'issue_id': manifest['issue_id'], 'status': 'implemented', 'changed_files': [MANIFEST_REL],
                  'test_commands': coding['scope']['test_commands'],
                  'test_results': 'Local scripted transport wrote release configuration; gm_runner must run the independent validator.',
                  'notes': PROVENANCE + '; existing capability configuration, not developed gameplay code'}
    else:
        answer = {'gm_id': context['gm_id'], 'results': [
            {'issue_id': item['issue_id'], 'disposition': 'observe', 'claim_coding': False,
             'summary': 'Offline scripted observation of an actual runtime accepted private iron need.',
             'evidence_refs': ['/proposals/0']} for item in context['open_issues']],
            'note': PROVENANCE}
        investigation = context.get('investigation')
        if context['gm_id'] == 'gm-05' and investigation:
            answer['new_issues'] = [{'proposal_key': 'finite-iron-delivery',
                'summary': 'Scripted proposal: the accepted private need and zero iron warrant a reviewed finite-source configuration.',
                'evidence_refs': ['/proposals/0'], 'claim_coding': True}]
    result = 'OFFLINE SCRIPTED TRANSPORT; NO MODEL WAS CALLED.\n```json\n' + json.dumps(answer) + '\n```\n'
    args.result.write_text(result, encoding='utf-8')
    print(json.dumps({'type': 'thread.started', 'thread_id': session}))
    print(json.dumps({'type': 'item.completed', 'item': {'type': 'agent_message', 'text': result}}))
    print(json.dumps({'type': 'turn.completed', 'usage': {'input_tokens': 0, 'cached_input_tokens': 0,
        'output_tokens': 0, 'reasoning_output_tokens': 0}, 'provenance': PROVENANCE}))
    return 0


@contextmanager
def local_fixture_route(gm, out):
    """Replace transport configuration only; exercise real dispatch/state/candidate guards."""
    class OfflineRoute:
        def __init__(self, *_args):
            self.key = 'offline-fixture-sentinel-never-a-credential'
            self.codex_home = out / 'offline-contexts'
            self.codex_home.mkdir(exist_ok=True)
        def reference(self):
            return {'model': 'offline-scripted-transport', 'provenance': PROVENANCE, 'real_model_calls': 0}
        def environment(self):
            env = dict(os.environ)
            for name in (*gm.SECRET_ENV_KEYS, *gm.PROXY_KEYS, 'AINCRAD_GATEWAY_RUN_CONFIG'):
                env.pop(name, None)
            env['OFFLINE_CHAIN_HOME'] = str(self.codex_home)
            env['PYTHONUTF8'] = '1'
            return env
        def test_environment(self):
            return self.environment()
        def assert_no_credential(self, text, where):
            require(self.key not in text, 'unexpected sentinel in ' + where)
        def sessions_root(self):
            return self.codex_home / 'sessions'
        def preflight_resume(self, session):
            if not gm.SESSION_UUID.fullmatch(session) or not any(self.sessions_root().glob(f'*/*/*/rollout-*-{session}.jsonl')):
                return 'offline context missing; refusing to invent a new continuation'
            return None
    def command(_route, _workdir, result, _instructions, _catalog, resume, **_host_options):
        argv = [sys.executable, str(Path(__file__).resolve()), '--offline-transport', '--result', str(result)]
        return argv + (['--resume', resume] if resume else [])
    old = gm.Route, gm.codex_command, gm.codex_catalog
    gm.Route, gm.codex_command = OfflineRoute, command
    gm.codex_catalog = lambda _instructions: {'models': [], 'provenance': PROVENANCE}
    try:
        yield
    finally:
        gm.Route, gm.codex_command, gm.codex_catalog = old


def call_gm(gm, out, label, argv):
    buffer = io.StringIO()
    with redirect_stdout(buffer):
        code = gm.main(argv)
    (out / (label + '.stdout.log')).write_text(buffer.getvalue(), encoding='utf-8')
    documents = [json.loads(line) for line in buffer.getvalue().splitlines() if line.startswith('{')]
    require(documents, 'GM runner emitted no result')
    result = documents[-1]
    write(out / (label + '.json'), result)
    require(code == 0, f'{label} failed: {result.get("kind")} {result.get("message", result.get("status"))}')
    return result


def engine(args, stage, expected_exit=0, approval=None):
    out = args.out
    require(args.godot, '--godot is required for engine phases')
    output = out / (stage + (('-refused') if expected_exit else '') + '.json')
    prior_process = out / ('chain-' + stage + ('-refused' if expected_exit else '') + '.process.json')
    if (output.is_file() and read(output).get('failure_count', 0) > 0) or (prior_process.is_file() and read(prior_process).get('exit_code') not in [None, 0]):
        archive = out / ('failed-' + stage + '-' + uuid.uuid4().hex[:8])
        archive.mkdir()
        for path in out.iterdir():
            if path.is_file() and (path.name.startswith(stage) or path.name.startswith('chain-' + stage)):
                shutil.copyfile(path, archive / path.name)
        shutil.copyfile(out / 'world.json', archive / 'world-at-recovery.json')
    graphical = stage.startswith('street-')
    timeout = 100 if graphical else 45
    command = [sys.executable, str(ROOT / 'tools/run_godot.py'), '--godot', args.godot,
        '--name', 'chain-' + stage + ('-refused' if expected_exit else ''), '--timeout', str(timeout), '--out', str(out), '--',
        *(['--rendering-method', 'gl_compatibility', '--resolution', '1280x720'] if graphical else ['--headless']),
        '--audio-driver', 'Dummy', '--script', 'res://tests/town_chain_release_probe.gd', '--',
        '--chain-stage=' + stage, '--chain-save=' + str(out / 'world.json'), '--chain-out=' + str(output),
        '--chain-export=' + str(out / 'gm-evidence.json')]
    if graphical:
        command += ['--town-save=' + str(out / 'world.json')]
        if stage == 'street-finish' and (out / 'street-resume-checkpoint.json').exists():
            command += ['--chain-resume-snapshot=' + str(out / 'street-resume-checkpoint.json')]
    if stage == 'release':
        command += ['--chain-manifest=' + str(out / 'approved-manifest.json'),
                    '--chain-approval=' + str(approval or out / 'approval.json')]
    runtime_hashes = {name: sha(ROOT / name) for name in RUNTIME_FILES}
    write(out / (stage + ('-refused' if expected_exit else '') + '.inputs.json'), {
        'world_sha256_before': sha(out / 'world.json'), 'runtime_source_sha256': runtime_hashes,
        'provenance': PROVENANCE, 'note': 'Actual local source bytes at engine launch; executable-code authorship is not assigned to scripted GM.'})
    run = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=timeout + 15)
    (out / (stage + ('-refused' if expected_exit else '') + '.runner.log')).write_text(run.stdout + run.stderr, encoding='utf-8')
    require(run.returncode == expected_exit, f'engine {stage}: expected exit {expected_exit}, got {run.returncode}; see retained logs')
    require(runtime_hashes == {name: sha(ROOT / name) for name in RUNTIME_FILES}, 'runtime source changed during probe; results require review')
    result = read(output)
    if not expected_exit:
        require(result['failure_count'] == 0, f'engine {stage} runtime assertions failed')
    return result


def prepare(args):
    from create_trade_fixture import shared_world_seed
    if args.out.exists():
        # An explicitly retained failed prepare may continue after a probe fix;
        # existing world identity, facts, failed requests and previous output stay.
        require((args.out / 'failure.json').is_file() and read(args.out / 'failure.json')['phase'] == 'prepare',
                'existing output is not a failed prepare; refusing to overwrite or replay')
        require(not (args.out / 'prepare.json').is_file() or read(args.out / 'prepare.json').get('failure_count') != 0,
                'prepare already completed; a later invocation cannot replay resident choices')
        require(read(args.out / 'world.json')['world_id'] == read(args.out / 'genesis.json')['world_id'], 'world identity changed')
        archive = args.out / ('failed-prepare-' + uuid.uuid4().hex[:8])
        archive.mkdir()
        for path in args.out.iterdir():
            if path.is_file():
                shutil.copyfile(path, archive / path.name)
        engine(args, 'prepare')
        return
    args.out.mkdir(parents=True, exist_ok=False)
    world = shared_world_seed('shared:offline-chain-' + args.out.name, 'Isolated offline integration world; no real model choices')
    world['origin']['deterministic_test_choices'] = True
    world['origin']['integration_provenance'] = PROVENANCE
    write(args.out / 'world.json', world)
    write(args.out / 'genesis.json', world)
    write(args.out / 'limits.json', {'provenance': PROVENANCE, 'limitations': LIMITS, 'real_model_calls': 0})
    engine(args, 'prepare')


def gm_phase(args):
    import gm_runner as gm
    out = args.out
    prepared = read(out / 'prepare.json')
    require(prepared['failure_count'] == 0, 'prepare must have real runtime evidence')
    evidence = read(out / 'gm-evidence.json')
    world = read(out / 'world.json')
    if (out / 'approval.json').exists():
        require(sha(out / 'world.json') == read(out / 'approval.json')['save_before_sha256'],
                'world continued after approval; do not rerun or rebase completed GM work')
    evidence_digest = sha(out / 'gm-evidence.json')
    write(out / 'investigation.json', {'investigation_id': 'offline-finite-iron-review', 'world_id': world['world_id'],
        'source_sha256': evidence_digest, 'objective': 'Review the accepted private iron need and propose a finite existing-source configuration.',
        'evidence_refs': ['/proposals/0']})
    state_dir = out / 'gm-state'
    shared = ['--state-dir', str(state_dir), '--timeout', '30', '--protect', str(out / 'world.json')]
    observe = ['observe', *shared, '--evidence', str(out / 'gm-evidence.json'), '--investigation-file', str(out / 'investigation.json'),
               '--prior-ledger', str(out / 'no-paid-ledger-used.json')]
    save_before = sha(out / 'world.json')
    with local_fixture_route(gm, out):
        previous_observation = read(out / 'gm-observe.json') if (out / 'gm-observe.json').is_file() else {}
        if previous_observation.get('status') == 'ok':
            require(previous_observation['evidence']['sha256'] == evidence_digest, 'cannot replay a completed observation against changed evidence')
            observed = previous_observation
        else:
            observed = call_gm(gm, out, 'gm-observe', observe)
        state = read(state_dir / 'state.json')
        require(observed['dispatched'] == 10, 'all ten independent GM fixture contexts must consume actual evidence')
        sessions = [row['session_id'] for row in state['sessions'].values()]
        require(len(sessions) == 10 and len(set(sessions)) == 10 and all(sessions), 'ten distinct persisted GM contexts required')
        claimed = [row for row in state['issues'].values() if row.get('owner_gm') == 'gm-05']
        require(len(claimed) == 1 and claimed[0].get('provenance', {}).get('origin') == 'gm_proposed', 'one fixture-attributed proposal and owner required')
        issue_id = claimed[0]['issue_id']
        head = gm.git(['rev-parse', 'HEAD']).stdout.strip()
        point = world['godot']['positions']['shared:smith']
        manifest = {'schema_version': 1, 'provenance': PROVENANCE, 'delivery_kind': 'existing_finite_source_configuration',
            'world_id': world['world_id'], 'owner_gm': 'gm-05', 'issue_id': issue_id, 'base_sha': head,
            'evidence_sha256': evidence_digest, 'evidence_refs': ['/proposals/0'],
            'source_resident_id': 'shared:smith', 'source_request_id': evidence['proposals'][0]['first']['request_id'],
            'source_seq': evidence['proposals'][0]['first']['source_sequence'],
            'spec': {'id': 'offline-chain:iron-offcuts', 'label': 'Public finite iron offcuts', 'material': 'iron',
                     'initial_stock': 3, 'position': [point[0], point[1], point[2] + 0.2], 'access': 'public'}}
        scope = {'issue_id': issue_id, 'base_revision': head,
            'objective': 'Write one explicitly offline candidate configuration for the existing finite public iron-source rule.',
            'files': [MANIFEST_REL], 'acceptance': ['The source follows the actual private need; exactly three finite units; unchanged world and existing identities.'],
            'test_commands': [[sys.executable, str(Path(__file__).resolve()), '--verify-candidate', MANIFEST_REL,
                '--evidence', str(out / 'gm-evidence.json'), '--save', str(out / 'world.json')]],
            'offline_release_manifest': manifest}
        write(out / 'scope.json', scope)
        previous_candidate = read(out / 'gm-candidate.json') if (out / 'gm-candidate.json').is_file() else {}
        if previous_candidate.get('status') == 'ok':
            require(previous_candidate.get('issue_id') == issue_id and previous_candidate.get('base_sha') == head,
                    'cannot replay or rebase a completed candidate implicitly')
            coded = previous_candidate
        else:
            coded = call_gm(gm, out, 'gm-candidate', ['code', *shared, '--issue', issue_id, '--scope-file', str(out / 'scope.json'),
                '--base-revision', head, '--run-scope-tests'])
        candidate = Path(coded['candidate'])
        if not candidate.is_absolute():
            candidate = ROOT / candidate
        manifest_path = candidate / MANIFEST_REL
        state = read(state_dir / 'state.json')
        record = state['issues'][issue_id]['candidates'][-1]
        require(record['status'] == 'ok' and record['review_state'] == 'unapproved', 'runner candidate must remain unapproved')
        require(record['changed_files'] == [MANIFEST_REL], 'actual candidate change must be the one scoped manifest')
        require(coded.get('deployed') is False, 'runner must not claim deployment')
        require(gm.git(['rev-parse', 'HEAD'], cwd=candidate).stdout.strip() == head, 'candidate base revision changed')
        require(sha(out / 'world.json') == save_before, 'GM process changed maintained integration world')
        approved_manifest = read(manifest_path)
        validate_candidate(approved_manifest, evidence, world, issue_id=issue_id)
        require(approved_manifest['evidence_sha256'] == evidence_digest, 'candidate evidence bytes mismatch')
        independent_review = subprocess.run(scope['test_commands'][0], cwd=candidate, capture_output=True, text=True,
                                            encoding='utf-8', errors='replace', timeout=15)
        write(out / 'supervisor-review-validation.json', {'exit_code': independent_review.returncode,
            'stdout': independent_review.stdout, 'stderr': independent_review.stderr,
            'validator_sha256': sha(Path(__file__)), 'candidate_manifest_sha256': sha(manifest_path), 'provenance': PROVENANCE})
        require(independent_review.returncode == 0, 'independent supervisor candidate review failed')
        # This is a concrete local supervisor approval of the configuration, never
        # an automatic self-approval by a GM or deployment claim in gm_runner.
        write(out / 'approved-manifest.json', approved_manifest)
        write(out / 'approval.json', {'schema_version': 1, 'status': 'approved', 'reviewer': 'GPT-6-supervisor-authored-offline-validator',
            'provenance': PROVENANCE, 'world_id': world['world_id'], 'issue_id': issue_id, 'owner_gm': 'gm-05',
            'candidate_manifest_sha256': sha(manifest_path), 'manifest_sha256': sha(out / 'approved-manifest.json'),
            'evidence_sha256': evidence_digest, 'save_before_sha256': save_before, 'base_sha': head,
            'supervisor_validator_sha256': sha(Path(__file__)),
            'scope': 'Install existing finite-source configuration only; no new executable version or real GM authorship claimed.'})
        repeated = read(out / 'gm-repeat.json') if (out / 'gm-repeat.json').is_file() else call_gm(gm, out, 'gm-repeat', observe)
        # New GM proposal becomes newly observable to peers once; a further same
        # evidence run must not re-dispatch already consumed work indefinitely.
        settled = read(out / 'gm-settled-repeat.json') if (out / 'gm-settled-repeat.json').is_file() else call_gm(gm, out, 'gm-settled-repeat', observe)
        require(settled['dispatched'] == 0, 'settled unchanged evidence must not manufacture new GM work')
        write(out / 'gm-integration.json', {'real_model_calls': 0, 'provenance': PROVENANCE,
            'distinct_gm_contexts': 10, 'owner_gm': 'gm-05', 'issue_id': issue_id, 'candidate': str(candidate),
            'candidate_changed_files': record['changed_files'], 'base_sha': head,
            'first_repeat_dispatches': repeated['dispatched'], 'settled_repeat_dispatches': settled['dispatched'],
            'world_unchanged_by_gm': sha(out / 'world.json') == save_before, 'limitations': LIMITS})


def validate_final(out):
    before = snapshot_from(out, 'prepare')
    released = snapshot_from(out, 'release')
    paused = snapshot_from(out, 'continue')
    final = snapshot_from(out, 'cold')
    inspected = snapshot_from(out, 'inspect')
    require(all(row['world_id'] == before['world_id'] for row in [released, paused, final, inspected]), 'world identity changed')
    for field in ['stable_id', 'name', 'role', 'story', 'coins_col']:
        expected = [(row['stable_id'], row.get(field)) for row in before['residents']]
        require(all([(row['stable_id'], row.get(field)) for row in value['residents']] == expected for value in [released, paused, final, inspected]),
                'resident identity/property changed: ' + field)
    require(final['life']['items'] == before['life']['items'] and final['life']['contracts'] == before['life']['contracts'], 'item ownership or contracts changed')
    require(final['life']['events'][:len(before['life']['events'])] == before['life']['events'], 'historical prefix changed')
    require(final == inspected, 'final read-only cold inspection changed runtime state')
    source = final['godot']['materials']['sources']['offline-chain:iron-offcuts']
    proposal = read(out / 'gm-evidence.json')['proposals'][0]
    private_source = source['source_need']
    require(private_source.get('kind') == 'resident_capability_need'
            and private_source.get('actor_id') == proposal['resident_id']
            and private_source.get('need_request_id') == proposal['first']['request_id']
            and private_source.get('seq') == proposal['first']['source_sequence']
            and private_source.get('text') == proposal['first']['reason'], 'installed source lost accepted private-need attribution')
    require(all(event.get('text') != proposal['first']['reason'] for event in final['life']['events']),
            'private need was converted into public life speech')
    for stage_state in [released, paused, final, inspected]:
        turns = stage_state['godot']['resident_turns']
        for resident_id, record in before['godot']['resident_turns'].items():
            prior_history = record.get('history', [])
            require(turns[resident_id].get('history', [])[:len(prior_history)] == prior_history,
                    'accepted private turn history was rewritten')
            require(turns[resident_id].get('reviews', [])[:len(record.get('reviews', []))] == record.get('reviews', []),
                    'retained fixture failure/controller recovery was erased')
    gained = sum(row['iron'] for row in final['life']['accounts']) - sum(row['iron'] for row in before['life']['accounts'])
    require(source['initial_stock'] == 3 and source['stock'] == 2 and source['recovered'] == gained == 1, 'actual stock-to-property conservation failed')
    require(source['stock'] + source['recovered'] == source['initial_stock'], 'finite resource was replenished or duplicated')
    require(paused['godot']['materials']['jobs']['shared:smith']['elapsed'] == 30, 'pending material commitment was not persisted')
    require(not final['godot']['materials']['jobs'], 'surviving material commitment failed to settle')
    return {'world_id': before['world_id'], 'resident_count': len(final['residents']), 'stock_before': 3, 'stock_after': 2,
            'resident_iron_gained': gained, 'history_before': len(before['life']['events']), 'history_after': len(final['life']['events'])}


def finish(args):
    out = args.out
    if (out / 'result.json').exists():
        previous_result = read(out / 'result.json')
        if previous_result.get('status') == 'offline_integration_passed':
            require(sha(out / 'world.json') == previous_result['final_save_sha256'],
                    'world continued after headless checkpoint; do not overwrite or replay its evidence')
            print(json.dumps(previous_result, ensure_ascii=False))
            return
    approval = read(out / 'approval.json')
    denied = dict(approval, status='unapproved')
    write(out / 'rejected-approval.json', denied)
    prior_release = read(out / 'release.json') if (out / 'release.json').exists() else {}
    if prior_release.get('failure_count') == 0:
        rejected = read(out / 'release-refused.json')
        require(rejected['evidence'].get('release_refused') and
                read(out / 'release-refused.inputs.json')['world_sha256_before'] == read(out / 'release.inputs.json')['world_sha256_before'],
                'prior unapproved release must have left original world unchanged')
    else:
        before = sha(out / 'world.json')
        rejected = engine(args, 'release', expected_exit=1, approval=out / 'rejected-approval.json')
        require(rejected['evidence'].get('release_refused') and sha(out / 'world.json') == before, 'unapproved candidate mutated world')
    for stage in ['release', 'continue', 'cold']:
        previous = read(out / (stage + '.json')) if (out / (stage + '.json')).exists() else {}
        if previous.get('failure_count') != 0:
            engine(args, stage)
    final_digest = sha(out / 'world.json')
    engine(args, 'inspect')
    require(sha(out / 'world.json') == final_digest, 'final separate-process cold load rewrote save')
    summary = validate_final(out)
    summary.update({'status': 'offline_integration_passed', 'real_model_calls': 0, 'provenance': PROVENANCE,
        'gm': read(out / 'gm-integration.json'), 'approval_rejection_world_unchanged': True,
        'final_save_sha256': final_digest, 'limitations': LIMITS})
    write(out / 'result.json', summary)
    print(json.dumps(summary, ensure_ascii=False))


def street(args):
    out = args.out
    require(read(out / 'result.json')['status'] == 'offline_integration_passed', 'headless chain must pass first')
    completed = read(out / 'street-finish.json') if (out / 'street-finish.json').exists() else {}
    if completed.get('failure_count') == 0:
        require(same_saved_values(read(out / 'world.json'), completed['evidence']['snapshot']), 'cannot replay or discard completed graphical progress')
    elif (out / 'street-start.json').exists():
        started = read(out / 'street-start.json')
        current = read(out / 'world.json')
        if not same_saved_values(current, started['evidence']['snapshot']):
            process = read(out / 'chain-street-finish.process.json')
            require(process.get('status') == 'exited' and process.get('exit_code') not in [None, 0], 'cannot replay or discard graphical progress')
            old_job = started['evidence']['snapshot']['godot']['materials']['jobs']['shared:smith']
            job = current['godot']['materials']['jobs']['shared:smith']
            source = current['godot']['materials']['sources']['offline-chain:iron-offcuts']
            require(current['world_id'] == started['evidence']['world_id'] and job['command_id'] == old_job['command_id']
                    and old_job['elapsed'] <= job['elapsed'] < 60 and source['stock'] == 2 and source['recovered'] == 1,
                    'crash continuation must retain same unfinished command and conserved source')
            require(not Path(str(out / 'world.json') + '.writer-lock').exists(), 'explicit host recovery of owned dead writer is required')
            write(out / 'street-resume-checkpoint.json', {'evidence': {'snapshot': current}, 'provenance': PROVENANCE,
                'interrupted_owned_pid': process['pid'], 'actual_engine_exit_code': process['exit_code'],
                'saved_elapsed_before_resume': job['elapsed'], 'world_sha256': sha(out / 'world.json'),
                'note': 'Resume the actual autosaved partial labor after native engine crash; no command replay, reset or resource grant.'})
        if started['failure_count']:
            require(set(started['failures']) == {'physical scene preserves item property and contracts', 'physical scene preserves historical prefix'},
                    'graphical start has unresolved failures beyond known numeric comparison issue')
            before = snapshot_from(out, 'cold')
            after = started['evidence']['snapshot']
            require(before['life']['items'] == after['life']['items'] and before['life']['contracts'] == after['life']['contracts']
                    and before['life']['events'] == after['life']['events'][:len(before['life']['events'])],
                    'independent comparison finds actual graphical property/history loss')
            write(out / 'street-start-invariant-recheck.json', {'status': 'passed_independent_saved_value_comparison',
                'original_probe_failure_count': started['failure_count'], 'original_failures_preserved': True,
                'reason': 'Raw JSON float and schema-normalized integer dictionaries differ in Godot; Python saved-value comparison confirms exact items/contracts/history prefix.',
                'initial_snapshot_path': 'cold.json', 'checked_snapshot_path': 'street-start.json', 'world_not_reset_or_replayed': True})
    else:
        engine(args, 'street-start')
    if completed.get('failure_count') != 0:
        engine(args, 'street-finish')
    first = snapshot_from(out, 'street-start')
    last = snapshot_from(out, 'street-finish')
    require(first['world_id'] == last['world_id'], 'graphical world changed')
    source = last['godot']['materials']['sources']['offline-chain:iron-offcuts']
    require(source['stock'] == 1 and source['recovered'] == 2 and source['stock'] + source['recovered'] == 3,
            'graphical same-world finite stock/property conservation failed')
    require(last['life']['events'][:len(first['life']['events'])] == first['life']['events'], 'graphical cold-resume rewrote history')
    samples = read(out / 'street-start.json')['evidence']['samples'] + read(out / 'street-finish.json')['evidence']['samples']
    movement = [row for row in samples if row['stage'] == 'material-return']
    require(movement and max(row['distance_to_source'] for row in movement) > 1.0
            and min(row['distance_to_source'] for row in movement) <= .45, 'actual physical return journey not demonstrated')
    los_events = [event for event in last['life']['events'] if event.get('type') == 'material_source_observed'
                  and event.get('actor_id') == 'shared:smith' and event.get('source_id') == 'offline-chain:iron-offcuts'
                  and event.get('source') == 'host_line_of_sight_observation' and event['seq'] > first['life']['seq']]
    require(los_events, 'actual scene never recorded an authoritative personal line-of-sight observation')
    write(out / 'street-result.json', {'status': 'offline_physical_continuation_passed', 'world_id': last['world_id'],
        'real_model_calls': 0, 'provenance': PROVENANCE, 'scripted_trade_flag_is_test_control_not_trade_proof': True,
        'actual_body_count': 10, 'sample_count': len(samples), 'source_stock_after': source['stock'],
        'source_recovered_total': source['recovered'], 'pending_labor_survived_new_graphical_process': True,
        'authoritative_line_of_sight_event_sequences': [event['seq'] for event in los_events],
        'legacy_sampler_limit': 'Original sample.line_of_sight queried outside a physics callback and is not usable visibility evidence; canonical actual-physics events above are the proof.',
        'native_engine_crash_observed': (out / 'owned-engine-recovery.json').exists(),
        'native_engine_crash_cause': 'unknown; successful same-save recovery does not close stability issue',
        'original_fixture_failures_preserved': True,
        'body_positions_assigned_by_probe': False, 'time_scale': 1, 'world_sha256_after': sha(out / 'world.json'),
        'screenshots': ['street-before-travel.png', 'street-paused-labor.png', 'street-cold-resume.png', 'street-completed-labor.png'],
        'limits': ['Scripted resident choices and GM proposal, no real models.', 'Existing finite-source configuration and actual private-need installation API.',
                   'One bounded approach/return route and finite recovery, not townwide navigation or autonomous living.']})


def main(argv=None):
    argv = list(sys.argv[1:] if argv is None else argv)
    if argv[:1] == ['--offline-transport']:
        return offline_transport(argv[1:])
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path)
    parser.add_argument('--godot')
    parser.add_argument('--phase', choices=['all', 'prepare', 'gm', 'finish', 'street'], default='all')
    parser.add_argument('--verify-candidate', type=Path)
    parser.add_argument('--evidence', type=Path)
    parser.add_argument('--save', type=Path)
    args = parser.parse_args(argv)
    if args.verify_candidate:
        manifest = read(args.verify_candidate)
        require(manifest.get('evidence_sha256') == sha(args.evidence), 'candidate evidence SHA256 mismatch')
        validate_candidate(manifest, read(args.evidence), read(args.save))
        print(json.dumps({'status': 'candidate_configuration_valid', 'provenance': PROVENANCE}))
        return 0
    require(args.out is not None, '--out required')
    args.out = args.out.resolve()
    require(ALLOWED_ROOT.resolve() in args.out.parents, '--out must be a child of tmp/gpt6-sprint/integration')
    try:
        if args.phase in ['all', 'prepare']:
            prepare(args)
        if args.phase in ['all', 'gm']:
            gm_phase(args)
        if args.phase in ['all', 'finish']:
            finish(args)
        if args.phase == 'street':
            street(args)
    except Exception as error:
        if args.out.is_dir():
            failure = {'phase': args.phase, 'error': str(error),
                'world_preserved_for_inspection': (args.out / 'world.json').exists(), 'provenance': PROVENANCE, 'limitations': LIMITS}
            write(args.out / 'failure.json', failure)
            with (args.out / 'failures.jsonl').open('a', encoding='utf-8') as stream:
                stream.write(json.dumps(failure) + '\n')
        raise
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
