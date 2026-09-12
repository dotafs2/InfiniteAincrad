"""Run one bounded Godot town validation against an EXISTING authorized Kimi ledger.

No ledger initialization, save creation, balance reset or automatic retry. The supplied
save may be an explicitly fictional test world; this tool never promotes it to a town.
"""
import argparse
from datetime import datetime, timedelta, timezone
import json
import os
from pathlib import Path
import secrets
import subprocess
import sys
import threading

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools/kimi'))
from kimi_budget import BudgetError, Ledger, Policy, CityValidationPolicy
from kimi_gateway import BudgetServer, KimiProvider, handler_type, write_private_json
from town_validation_budget import CarriedLedgerGate, EvidenceGateway, read_review_pin


def validate_paths(out, save, gm_export=None):
    """Keep private artifacts outside exported assets and GM output in its run."""
    game = (ROOT / 'game').resolve()
    if any(path == game or game in path.parents for path in (out, save)):
        raise ValueError('Private files must remain outside the exported game directory.')
    if not save.is_file():
        raise ValueError('The explicitly selected world must already exist.')
    if out.exists():
        raise ValueError('Output must be a new directory for this validation run.')
    if gm_export is not None:
        if out not in gm_export.parents:
            raise ValueError('--gm-export must be a file beneath the new --out directory.')
        relative = gm_export.relative_to(out)
        reserved = {'endpoint.json', 'scope.json', 'attempt.json', 'helper.json', 'runner.log',
                    'result.json', 'capture', 'request-bodies', 'carried-uncertainty-review.json',
                    'town-model.stdout.log', 'town-model.stderr.log', 'town-model.process.json',
                    'town-model.process.next.json'}
        if relative.parts[0].casefold() in reserved or gm_export.suffix.casefold() != '.json':
            raise ValueError('--gm-export requires a separate .json path, outside launcher artifacts.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--ledger', type=Path, required=True)
    parser.add_argument('--config', type=Path, required=True)
    parser.add_argument('--save', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--seconds', type=int, default=300)
    parser.add_argument('--max-requests', type=int, default=12)
    parser.add_argument('--concurrency', type=int, default=1, help='Resident scheduler bound 1..3, within remaining ledger slots; this launcher serializes upstream completions.')
    parser.add_argument('--carried-uncertainty-pin', type=Path, help='Explicit v1 JSON review pin binding ledger/guard/policy and the exact carried uncertain request IDs, states and nanoyuan reserves; never waives new uncertainty.')
    parser.add_argument('--inquire-resident', help='Send one scripted player inquiry to this active stable resident ID.')
    parser.add_argument('--inquire-text', help='Exact explicitly scripted player message; requires --inquire-resident.')
    parser.add_argument('--headless', action='store_true')
    parser.add_argument('--stop-on-idle', action='store_true', help='End this bounded validation once current requests/jobs settle; never force another decision.')
    parser.add_argument('--stop-on-decision-limit', action='store_true',
                        help='Keep advancing through idle time, then pause/capture after the decision cap and any in-flight model result; durable physical jobs remain pending.')
    parser.add_argument('--gm-export', type=Path, help='Optional .json file beneath the new --out directory for background-GM evidence from this same world.')
    args = parser.parse_args()
    if not 5 <= args.seconds <= 900 or not 1 <= args.max_requests <= 32:
        parser.error('Seconds 5..900; maximum requests 1..32.')
    if args.inquire_text is not None and (not args.inquire_resident or not args.inquire_text.strip() or len(args.inquire_text) > 512):
        parser.error('Scripted inquiry text requires a target and 1..512 characters.')
    out, save = args.out.resolve(), args.save.resolve()
    gm_export = args.gm_export.resolve() if args.gm_export else None
    deadline = datetime.now(timezone.utc) + timedelta(seconds=args.seconds + 55)
    try:
        validate_paths(out, save, gm_export)
        guard = json.loads(args.ledger.with_suffix('.guard.json').read_text(encoding='utf-8'))
        policy = (CityValidationPolicy if 'request_limit' in guard['policy'] else Policy)(**guard['policy'])
        ledger = Ledger(args.ledger, policy, runtime_deadline_utc=int(deadline.timestamp()))
        pin = read_review_pin(args.carried_uncertainty_pin) if args.carried_uncertainty_pin else None
        gate = CarriedLedgerGate(ledger, pin, args.concurrency, args.max_requests)
        before = ledger.status()
    except (BudgetError, OSError, ValueError, KeyError, TypeError) as exc:
        parser.error(str(exc))
    provider = KimiProvider(json.loads(args.config.read_text(encoding='utf-8-sig')))
    out.mkdir(parents=True, exist_ok=False)
    if gm_export is not None:
        gm_export.parent.mkdir(parents=True, exist_ok=True)
    if gate.review is not None:
        write_private_json(out / 'carried-uncertainty-review.json', gate.review)
    token = secrets.token_urlsafe(32)
    server = BudgetServer(('127.0.0.1', 0), handler_type(EvidenceGateway(ledger, provider, out, gate), token))
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    endpoint, run = out / 'endpoint.json', out / 'scope.json'
    write_private_json(endpoint, dict(base_url=f'http://127.0.0.1:{server.server_port}/v1', api_key=token,
                                      model=policy.model, ledger_id=before['ledger_id']))
    write_private_json(run, dict(schema_version=1, endpoint_path=str(endpoint), expected_ledger_id=before['ledger_id'],
                                 run_state_path=str(out / 'attempt.json'), deadline_utc=deadline.isoformat(),
                                 max_requests=args.max_requests, concurrency=args.concurrency,
                                 inquire_resident=args.inquire_resident or '', external_liability_cny=0,
                                 gm_export_path=str(gm_export) if gm_export else '',
                                 expected_model=policy.model, provenance='opengameagent_live'))
    (out / 'helper.json').write_text(json.dumps({'pid': os.getpid(), 'status': 'running', 'ledger_before': before}, indent=2))
    thread.start()
    command = [sys.executable, str(ROOT / 'tools/run_godot.py'), '--godot', args.godot, '--name', 'town-model',
               '--timeout', str(args.seconds + 45), '--out', str(out), '--']
    if args.headless:
        command += ['--headless']
    command += ['--audio-driver', 'Dummy']
    command += ['res://scenes/town_street.tscn', '--', '--town-save=' + str(save), '--town-gateway',
                '--town-capture=' + str(out / 'capture'), '--town-duration=' + str(args.seconds),
                '--town-max-decisions=' + str(args.max_requests)]
    if gm_export is not None:
        command += ['--town-gm-export=' + str(gm_export)]
    if args.inquire_resident:
        command += ['--town-dialogue-fixture', '--town-inquire-resident=' + args.inquire_resident]
    if args.inquire_text is not None:
        command += ['--town-inquire-text=' + args.inquire_text]
    if args.stop_on_idle:
        command += ['--town-stop-on-idle']
    if args.stop_on_decision_limit:
        command += ['--town-stop-on-decision-limit']
    try:
        result = subprocess.run(command, cwd=ROOT, env=dict(os.environ, AINCRAD_GATEWAY_RUN_CONFIG=str(run)),
                                capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=args.seconds + 60)
        (out / 'runner.log').write_text(result.stdout + result.stderr, encoding='utf-8')
    finally:
        server.shutdown()
        server.server_close()
        thread.join(timeout=5)
        (out / 'helper.json').write_text(json.dumps({'pid': os.getpid(), 'status': 'closed', 'ledger_after': ledger.status()}, indent=2))
    capture_path = out / 'capture/evidence.json'
    capture = json.loads(capture_path.read_text(encoding='utf-8')) if capture_path.exists() else {}
    errors = {actor: turn['status'] for actor, turn in capture.get('resident_turns', {}).items()
              if turn.get('status') in ('pending', 'provider_error', 'rule_rejection')}
    try:
        gate.check()
    except Exception:
        pass  # The gate's persistent failure reason is reported below.
    passed = result.returncode == 0 and bool(capture) and not errors and not gate.failure
    summary = {'engine_exit': result.returncode, 'validation_passed': passed, 'model_errors': errors, 'ledger_before': before, 'ledger_after': ledger.status(),
               'capture_exists': (out / 'capture/evidence.json').exists(), 'original_world_promoted': False,
               'budget_stop_reason': gate.failure, 'upstream_requests': gate.sent, 'upstream_concurrency': 1,
               'carried_uncertainty_reviewed': gate.review is not None}
    (out / 'result.json').write_text(json.dumps(summary, indent=2), encoding='utf-8')
    print(json.dumps(summary))
    return 0 if passed else 1


if __name__ == '__main__':
    raise SystemExit(main())
