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
from kimi_budget import Ledger, Policy, CityValidationPolicy
from kimi_gateway import Gateway, BudgetServer, KimiProvider, handler_type, write_private_json


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--ledger', type=Path, required=True)
    parser.add_argument('--config', type=Path, required=True)
    parser.add_argument('--save', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--seconds', type=int, default=300)
    parser.add_argument('--max-requests', type=int, default=12)
    parser.add_argument('--inquire-resident', help='Send one scripted player inquiry to this active stable resident ID.')
    parser.add_argument('--inquire-text', help='Exact explicitly scripted player message; requires --inquire-resident.')
    parser.add_argument('--headless', action='store_true')
    parser.add_argument('--stop-on-idle', action='store_true', help='End this bounded validation once current requests/jobs settle; never force another decision.')
    args = parser.parse_args()
    if not 5 <= args.seconds <= 900 or not 1 <= args.max_requests <= 32:
        parser.error('Seconds 5..900; maximum requests 1..32.')
    if args.inquire_text is not None and (not args.inquire_resident or not args.inquire_text.strip() or len(args.inquire_text) > 512):
        parser.error('Scripted inquiry text requires a target and 1..512 characters.')
    out, save = args.out.resolve(), args.save.resolve()
    game = ROOT / 'game'
    if game in out.parents or game in save.parents or out == game or save == game:
        parser.error('Private files must remain outside the exported game directory.')
    if not save.is_file():
        parser.error('The explicitly selected world must already exist.')
    guard = json.loads(args.ledger.with_suffix('.guard.json').read_text(encoding='utf-8'))
    policy = (CityValidationPolicy if 'request_limit' in guard['policy'] else Policy)(**guard['policy'])
    concurrency = int(policy.concurrency)
    if not 1 <= concurrency <= 3:
        parser.error('The existing ledger policy concurrency must be 1..3 for this run.')
    deadline = datetime.now(timezone.utc) + timedelta(seconds=args.seconds + 55)
    ledger = Ledger(args.ledger, policy, runtime_deadline_utc=int(deadline.timestamp()))
    before = ledger.status()
    if before['halted'] or before['reserved_cny']:
        parser.error('Reconcile the existing halted or uncertain ledger first.')
    provider = KimiProvider(json.loads(args.config.read_text(encoding='utf-8-sig')))
    out.mkdir(parents=True, exist_ok=False)
    token = secrets.token_urlsafe(32)
    class EvidenceGateway(Gateway):
        def complete(self, request_id, resident, body):
            # Private validation evidence only; excludes HTTP headers/credentials.
            # Name is generated locally, never a path supplied by an actor.
            request_dir = out / 'request-bodies'
            request_dir.mkdir(exist_ok=True)
            write_private_json(request_dir / (secrets.token_hex(12) + '.json'),
                               dict(operation=request_id, resident=resident, body=body))
            return super().complete(request_id, resident, body)

    server = BudgetServer(('127.0.0.1', 0), handler_type(EvidenceGateway(ledger, provider), token))
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    endpoint, run = out / 'endpoint.json', out / 'scope.json'
    write_private_json(endpoint, dict(base_url=f'http://127.0.0.1:{server.server_port}/v1', api_key=token,
                                      model=policy.model, ledger_id=before['ledger_id']))
    write_private_json(run, dict(schema_version=1, endpoint_path=str(endpoint), expected_ledger_id=before['ledger_id'],
                                 run_state_path=str(out / 'attempt.json'), deadline_utc=deadline.isoformat(),
                                 max_requests=args.max_requests, concurrency=concurrency,
                                 inquire_resident=args.inquire_resident or '', external_liability_cny=0,
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
    if args.inquire_resident:
        command += ['--town-dialogue-fixture', '--town-inquire-resident=' + args.inquire_resident]
    if args.inquire_text is not None:
        command += ['--town-inquire-text=' + args.inquire_text]
    if args.stop_on_idle:
        command += ['--town-stop-on-idle']
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
    passed = result.returncode == 0 and bool(capture) and not errors
    summary = {'engine_exit': result.returncode, 'validation_passed': passed, 'model_errors': errors, 'ledger_before': before, 'ledger_after': ledger.status(),
               'capture_exists': (out / 'capture/evidence.json').exists(), 'original_world_promoted': False}
    (out / 'result.json').write_text(json.dumps(summary, indent=2), encoding='utf-8')
    print(json.dumps(summary))
    return 0 if passed else 1


if __name__ == '__main__':
    raise SystemExit(main())
