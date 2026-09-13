"""Prepare and no-dispatch preflight ONE labelled LOCAL trial fixture for real DeepSeek GM transport.

This helper never reads, copies or prints the API key. It writes only non-secret route/config
JSON, seeds the fixture world through the existing Godot seed phase (the same explicit fixture
seed path the offline host runner uses) and then runs the existing `gm_runner observe --dry-run`
route preflight, which makes no model call.

World provenance and GM transport are separate facts:
  * the world is a FRESH labelled local-trial fixture genesis, never migrated canonical state and
    never a fee-history reset;
  * the GM transport is the real DeepSeek route named in the route JSON (model deepseek-flash),
    which has been PREPARED and preflighted here, not proved live by a real run.

A second preparation invocation leaves the fixture bytes unchanged (`already_prepared`).
"""
import argparse
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import gm_autonomy  # noqa: E402
import gm_runner  # noqa: E402
import validate_gm_autonomy as va  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
LABEL_ROOT = ROOT / 'tmp' / 'gm-autonomy-20260913' / 'local-trial'
KEY_FILE = ROOT / 'private' / 'deepseek-api-key.txt'
ACCOUNTING_REFERENCES = list(va.ACCOUNTING_REFERENCES)
LABEL_PREFIX = 'local-trial'
LABEL_PATTERN = re.compile(r'\A[A-Za-z0-9_-]{1,128}\Z')


def fixture_root(label: str) -> Path:
    return LABEL_ROOT / label


def resolve_fixture_root(label: str) -> tuple:
    """Resolve one plain label inside LABEL_ROOT, refusing separators, traversal and escapes.

    Called before ANY write (including direct prepare() calls) so a crafted label can never create
    a file outside the local-trial root.
    """
    if not isinstance(label, str) or not LABEL_PATTERN.match(label):
        return None, ('the fixture label must be plain letters/digits/_/- with no path '
                      'separators, no dots and no .. components')
    if not label.startswith(LABEL_PREFIX):
        return None, ('the fixture label must start with ' + LABEL_PREFIX + ' so it stays '
                      'distinguishable from scripted fake scenario directories')
    base = LABEL_ROOT.resolve()
    root = (base / label).resolve()
    if root.parent != base:
        return None, 'the fixture label must stay directly inside the local-trial root'
    return root, None


def paths_for(root: Path) -> dict:
    return {'root': root, 'state': root / 'state', 'deployment': root / 'trial-deployment',
            'runtime': root / 'runtime', 'evidence': root / 'evidence.json',
            'ledger': root / 'prior-ledger.json', 'policy': root / 'policy.json',
            'config': root / 'deepseek.local.json', 'key': root / 'deepseek-key.txt',
            'codex_home': root / 'codex-home', 'save': root / 'runtime' / 'trial-world.json',
            'route': root / 'route.json', 'marker': root / 'prepared.json'}


def commands_for(paths: dict) -> dict:
    """Exact commands for status, no-dispatch preflight and a bounded cycle/watch.

    The watch preset budgets 32 native GM turns (NOT HTTP requests): enough for the initial
    10-identity observe batch plus the coding and feedback turns of a first release and a queued
    continuation, while the policy still holds the release to one changed file.
    """
    python, key = sys.executable, str(KEY_FILE)
    common = ['--config', str(paths['config']), '--key-file', key,
              '--codex-home', str(paths['codex_home'])]
    preflight = [python, str(ROOT / 'tools/gm_runner.py'), 'observe',
                 '--evidence', str(paths['evidence']), '--state-dir', str(paths['state']),
                 '--autonomy-policy', str(paths['policy']),
                 '--prior-ledger', str(paths['ledger']), '--max-gms', '10',
                 '--dry-run', *common]
    cycle = [python, str(ROOT / 'tools/gm_autonomy.py'), 'cycle',
             '--policy', str(paths['policy']), *common, '--timeout', '900']
    watch = [python, str(ROOT / 'tools/gm_autonomy.py'), 'watch',
             '--policy', str(paths['policy']), *common,
             '--max-iterations', '4', '--max-seconds', '900', '--max-calls', '32',
             '--idle-exits', '1', '--interval', '5']
    status = [python, str(ROOT / 'tools/gm_autonomy.py'), 'status',
              '--state-dir', str(paths['state'])]
    return {'status': status, 'preflight': preflight, 'cycle': cycle, 'watch': watch}


def route_document() -> dict:
    """Non-secret route facts; the credential stays a path reference only."""
    return {'schema_version': 1, 'model': 'deepseek-flash',
            'base_url': 'https://api.deepseek.com', 'wire_api': 'responses',
            'key_file': str(KEY_FILE), 'key_file_contains_secret': True,
            'note': ('This file names the route only. The key is read by gm_runner from the '
                     'existing private key file and is never copied, printed or stored here.')}


def real_route_blocker(paths: dict, policy: dict):
    """A real local_trial route must never point at the scripted offline fixture ledger."""
    if (policy or {}).get('mode') != 'local_trial':
        return None
    ledger = gm_runner.load_json(paths['ledger']) if paths['ledger'].is_file() else None
    kind = (ledger or {}).get('kind')
    if kind == 'fixture_prior_ledger':
        return {'status': 'refused_fake_prior_ledger', 'code': 4, 'prior_ledger_kind': kind,
                'note': ('the real local-trial route must not point at the scripted offline '
                         'fixture prior ledger, so this preparation is not ready')}
    return None


def prepare(label: str, run_preflight: bool) -> tuple:
    root, label_error = resolve_fixture_root(label)
    if label_error:
        return 2, {'status': 'refused_label', 'note': label_error}
    paths = paths_for(root)
    reusing = paths['marker'].is_file() and paths['save'].is_file()
    if not reusing:
        if paths['save'].exists():
            return 3, {'status': 'refused_existing_save', 'save_path': str(paths['save']),
                       'fixture_root': str(root),
                       'note': ('a runtime save already exists at this label; this helper never '
                                'overwrites an existing save, so the fixture stays byte-for-byte '
                                'unchanged'),
                       'marker_present': paths['marker'].exists()}
        if paths['marker'].exists():
            return 3, {'status': 'refused_marker_without_save', 'fixture_root': str(root),
                       'note': ('a prepared marker exists but its runtime save is gone; refusing '
                                'to rebuild or repair a half-written fixture by guessing')}
        paths['root'].mkdir(parents=True, exist_ok=True)
        try:
            va.provision(label, 'happy', mode='local_trial', root_dir=LABEL_ROOT,
                         unique=False, record_latest=False)
        except Exception as error:  # noqa: BLE001 - reported, not hidden
            return 1, {'status': 'provision_failed', 'fixture_root': str(root),
                       'error': type(error).__name__ + ': ' + str(error)}
        if not paths['save'].is_file():
            return 1, {'status': 'seed_failed', 'fixture_root': str(root),
                       'note': 'the labelled seed phase did not produce a runtime save',
                       'seed': (gm_runner.load_json(paths['root'] / 'policy.json') or {})}
        gm_runner.save_json(paths['route'], route_document())
    policy = gm_runner.load_json(paths['policy']) or {}
    missing = gm_autonomy.missing_requirements(policy, policy.get('mode'))
    if reusing:
        marker = gm_runner.load_json(paths['marker']) or {}
        result = {'status': 'already_prepared', 'fixture_label': label,
                  'fixture_root': str(root),
                  'save_sha256': gm_runner.sha256_file(paths['save']),
                  'policy_sha256': gm_runner.sha256_file(paths['policy']),
                  'prepared_utc': marker.get('created_utc'),
                  'required_paths_missing': missing,
                  'prior_ledger_path': str(paths['ledger']),
                  'note': ('existing labelled fixture reused byte-for-byte; the marker, save and '
                           'policy were not rewritten, and the requested read-only preflight is '
                           're-run rather than trusted'),
                  'commands': commands_for(paths)}
    else:
        marker = {'schema_version': 1, 'kind': 'gm_autonomy_local_trial_fixture',
                  'fixture_label': label, 'mode': 'local_trial',
                  'world_origin': 'labelled_fixture_genesis',
                  'gm_transport': 'real_provider_route',
                  'transport_route': {'model': 'deepseek-flash',
                                      'base_url': 'https://api.deepseek.com',
                                      'config': gm_runner.relative(paths['config']),
                                      'key_file': str(KEY_FILE)},
                  'created_utc': gm_runner.utc_iso(), 'fixture_root': str(root),
                  'save_path': gm_runner.relative(paths['save']),
                  'save_sha256': gm_runner.sha256_file(paths['save']),
                  'policy_path': gm_runner.relative(paths['policy']),
                  'policy_sha256': gm_runner.sha256_file(paths['policy']),
                  'prior_ledger_path': gm_runner.relative(paths['ledger']),
                  'prior_ledger_kind': (gm_runner.load_json(paths['ledger']) or {}).get('kind'),
                  'required_paths_missing': missing,
                  'accounting_references': ACCOUNTING_REFERENCES,
                  'real_gm_or_kimi_call_made': False,
                  'claim': ('prepared local route only; not proven live and not a migrated '
                            'canonical world or a paid-history reset')}
        gm_runner.save_json(paths['marker'], marker)
        result = {'status': 'prepared', 'fixture_label': label, 'fixture_root': str(root),
                  'world_origin': 'labelled_fixture_genesis',
                  'gm_transport': 'real_provider_route:deepseek-flash',
                  'save_path': str(paths['save']), 'save_sha256': marker['save_sha256'],
                  'route_path': str(paths['route']),
                  'prior_ledger_path': str(paths['ledger']),
                  'required_paths_missing': missing,
                  'commands': commands_for(paths)}
    blocker = real_route_blocker(paths, policy)
    if blocker:
        result['status'] = blocker['status']
        result['prior_ledger_kind'] = blocker.get('prior_ledger_kind')
        result['note'] = blocker['note']
        return blocker['code'], result
    if missing:
        result['status'] = 'refused_missing_requirements'
        result['note'] = ('refusing to report a prepared fixture while required inputs are '
                          'absent')
        return 4, result
    if run_preflight:
        code, preflight = run_route_preflight(paths, policy)
        result['preflight'] = preflight
        if code:
            result['status'] = ('already_prepared_preflight_failed' if reusing
                                else 'prepared_preflight_failed')
            return code, result
    return 0, result


def run_route_preflight(paths: dict, policy: dict) -> tuple:
    """Run the existing no-dispatch route preflight and check the planned GM identities."""
    import subprocess
    commands = commands_for(paths)
    finished = subprocess.run(commands['preflight'], cwd=str(ROOT), capture_output=True,
                              text=True, encoding='utf-8', errors='replace', timeout=300)
    payload = None
    for line in reversed(finished.stdout.strip().splitlines()):
        try:
            payload = json.loads(line)
        except ValueError:
            continue
        break
    plan = (payload or {}).get('plan') or []
    planned = [item.get('gm_id') for item in plan]
    dispatch_turns = int((payload or {}).get('dispatched_turns') or 0)
    route = (payload or {}).get('route') or {}
    ledger_doc = gm_runner.load_json(paths['ledger']) if paths['ledger'].is_file() else None
    ledger_kind = (ledger_doc or {}).get('kind')
    checks = {
        'dry_run_status': (payload or {}).get('status') == 'dry_run',
        'planned_gm_identities': len(planned),
        'dispatched_turns': dispatch_turns,
        'model': route.get('model'), 'key_file_reference': route.get('key_path'),
        'windows_sandbox': route.get('windows_sandbox'),
        'prior_ledger_kind': ledger_kind,
        'prior_ledger_is_fake_fixture': ledger_kind == 'fixture_prior_ledger',
        'required_paths_missing': gm_autonomy.missing_requirements(policy, policy['mode'])}
    ok = (finished.returncode == 0 and checks['dry_run_status'] and len(planned) == 10
          and dispatch_turns == 0 and checks['model'] == 'deepseek-flash'
          and not checks['prior_ledger_is_fake_fixture']
          and not checks['required_paths_missing'])
    checks['exit_code'] = finished.returncode
    checks['ok'] = ok
    return (0 if ok else 2), checks


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--label', help='explicit fixture label; default is stamped and unique')
    parser.add_argument('--no-preflight', action='store_true',
                       help='prepare only; skip the no-dispatch route preflight')
    return parser


def main(argv=None) -> int:
    args = build_parser().parse_args(argv)
    label = args.label or ('local-trial-' + gm_runner.utc_stamp().replace(':', '')
                           .replace('-', '').replace('+', 'Z'))
    code, result = prepare(label, not args.no_preflight)
    print(json.dumps(result, indent=2, sort_keys=True))
    return code


if __name__ == '__main__':
    sys.exit(main())
