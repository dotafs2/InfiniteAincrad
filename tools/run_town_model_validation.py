"""Run one bounded Godot town validation against an EXISTING authorized Kimi ledger.

No ledger initialization, save creation, balance reset or automatic retry. The supplied
save may be an explicitly fictional test world; this tool never promotes it to a town.

The loopback gateway is a launcher-local DrainBudgetServer. When the engine exits, new
intake stops and the request workers this launcher already accepted get a finite drain
grace, so a response that arrives after the engine died still settles its own durable
reservation exactly once instead of dying with its daemon thread. No request is ever
replayed from here, and a worker that outlives the grace is only reported: this tool
never rewrites, refunds or fabricates a ledger row.
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
import time

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools/kimi'))
from kimi_budget import BudgetError, Ledger, Policy, CityValidationPolicy
from kimi_gateway import BudgetServer, KimiProvider, handler_type, write_private_json
from town_validation_budget import CarriedLedgerGate, EvidenceGateway, read_review_pin

# Upper bound for the post-engine drain; the upstream provider request timeout is 35s,
# so a normal in-flight completion is inside this bound. The effective grace is also
# capped by this run's own authorization deadline and never extends it.
MAX_DRAIN_GRACE_SECONDS = 40.0
DRAIN_GRACE_SECONDS = 40.0
_DRAIN_POLL_SECONDS = 0.25
# The engine's own bounded episode shutdown: after --seconds expires it stops admitting
# NEW resident decisions, then awaits the already-started replies and their authoritative
# application before it captures and exits. The launcher budgets this same single value
# for the engine process and the authorization deadline, so it can never kill the engine
# exactly while it is applying a reply this run already paid for.
SHUTDOWN_WAIT_SECONDS = 45.0
MAX_SHUTDOWN_WAIT_SECONDS = 120.0


class OperationTracker:
    """Name the bounded operation the current worker thread is settling, if any."""

    def __init__(self):
        self._lock = threading.Lock()
        self._active = {}

    def begin(self, operation):
        with self._lock:
            self._active[threading.get_ident()] = operation

    def end(self):
        with self._lock:
            self._active.pop(threading.get_ident(), None)

    def operations_for(self, workers):
        """Return the distinct operations of these workers, for shutdown diagnostics."""
        with self._lock:
            named = []
            for worker in workers:
                # A missing/malformed header leaves no usable operation name, and an
                # unstarted worker has no ident; neither may break the diagnostic.
                value = self._active.get(worker.ident)
                if isinstance(value, str) and value:
                    named.append(value)
        return sorted(set(named))


class TrackingGateway:
    """Launcher-local delegate that records in-flight operations; behaviour is unchanged."""

    def __init__(self, gateway, tracker):
        self.ledger = gateway.ledger
        self._gateway = gateway
        self._tracker = tracker

    def complete(self, request_id, resident, body):
        self._tracker.begin(request_id)
        try:
            return self._gateway.complete(request_id, resident, body)
        finally:
            self._tracker.end()


class DrainBudgetServer(BudgetServer):
    """BudgetServer that tracks accepted request workers so they can be drained.

    BudgetServer threads are daemons, so a worker still awaiting the upstream provider
    would be killed at interpreter exit before its durable reservation could settle.
    This subclass refuses new intake once draining starts, keeps the accepted workers
    visible, and waits for them within a finite grace. It writes nothing: a worker that
    does not finish in time leaves its own reservation unresolved and is only reported.
    """

    def __init__(self, address, handler, grace_seconds=DRAIN_GRACE_SECONDS):
        if not 0 <= grace_seconds <= MAX_DRAIN_GRACE_SECONDS:
            raise ValueError('Drain grace must be within 0..40 seconds.')
        self.drain_grace = float(grace_seconds)
        self.grace_used = float(grace_seconds)
        self._worker_lock = threading.Lock()
        self._workers = set()
        self._intake_closed = False
        self.accepted = 0
        self.refused = 0
        self.start_failures = 0
        super().__init__(address, handler)

    @property
    def intake_closed(self):
        with self._worker_lock:
            return self._intake_closed

    def stop_intake(self):
        """Refuse connections from here on; already accepted workers keep running."""
        with self._worker_lock:
            self._intake_closed = True

    def process_request(self, request, client_address):
        worker = threading.Thread(target=self._serve_request, args=(request, client_address))
        worker.daemon = self.daemon_threads
        with self._worker_lock:
            admitted = not self._intake_closed
            if admitted:
                self._workers.add(worker)
                self.accepted += 1
        if not admitted:
            self.refused += 1
            self.shutdown_request(request)
            return
        try:
            worker.start()
        except RuntimeError:
            # A worker that never started owns no reservation; refuse the socket
            # instead of letting the exception escape the serve loop.
            with self._worker_lock:
                self._workers.discard(worker)
            self.start_failures += 1
            self.shutdown_request(request)

    def _serve_request(self, request, client_address):
        try:
            self.process_request_thread(request, client_address)
        finally:
            # Unregister even if the handler raised, so nothing waits on a dead thread.
            with self._worker_lock:
                self._workers.discard(threading.current_thread())

    def pending_workers(self):
        with self._worker_lock:
            return [worker for worker in self._workers if worker.is_alive()]

    def drain(self, deadline=None):
        """Wait a finite grace for accepted workers; return the ones still running."""
        start = time.monotonic()
        end = start + self.drain_grace
        if deadline is not None:
            end = min(end, deadline)
        self.grace_used = max(0.0, end - start)
        while True:
            pending = self.pending_workers()
            remaining = end - time.monotonic()
            if not pending or remaining <= 0:
                return pending
            pending[0].join(timeout=min(_DRAIN_POLL_SECONDS, remaining))


def gateway_deadline(deadline):
    """Return this run's authorization bound on the monotonic clock."""
    return time.monotonic() + (deadline - datetime.now(timezone.utc)).total_seconds()


def drain_gateway(server, thread, tracker, deadline=None):
    """Close the loopback gateway and let already accepted requests finish.

    New intake stops first, so no newly arriving request reaches the provider. Accepted
    workers keep the unchanged Gateway.complete path: a response received after the
    engine died still settles its own reservation exactly once and is never replayed.
    A worker that outlives the finite grace is reported as unresolved; nothing here
    writes to the ledger, so its durable reservation is left exactly as it is.

    The operations whose workers were still running when the engine exited are named
    first, so a drain that completes later is not reported as if nothing had been
    outstanding at engine exit. This names only the observed worker facts: whether a
    named operation ultimately settled, errored or was consumed is not inferable from
    worker lifetime, and no settlement is claimed without its own ledger receipt.
    """
    pending_at_engine_exit = server.pending_workers()
    operations_at_engine_exit = tracker.operations_for(pending_at_engine_exit) if tracker else []
    server.stop_intake()
    try:
        server.shutdown()
        server.server_close()
    finally:
        thread.join(timeout=5)
    error = ''
    try:
        pending = server.drain(deadline)
    except Exception as exc:  # Never hide the shutdown diagnostic behind a join error.
        error = type(exc).__name__
        pending = server.pending_workers()
    return {'intake_closed': True, 'workers_accepted': server.accepted,
            'workers_in_flight': bool(pending), 'drained_complete': not pending,
            'unresolved_workers': len(pending),
            'unresolved_operations': tracker.operations_for(pending) if tracker else [],
            'workers_pending_at_engine_exit': len(pending_at_engine_exit),
            'operations_pending_at_engine_exit': operations_at_engine_exit,
            'engine_exited_with_workers_pending': bool(pending_at_engine_exit),
            'refused_connections': server.refused, 'worker_start_failures': server.start_failures,
            'drain_grace_seconds': round(server.grace_used, 3),
            'drain_error': error}


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


def _nonnegative_int(value):
    """Return a trustworthy counter value; bool is not an integer counter here."""
    if isinstance(value, bool) or not isinstance(value, int) or value < 0:
        return 0
    return value


def _finite_number(value):
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return None
    value = float(value)
    if value < 0 or value == float('inf') or value == float('-inf') or value != value:
        return None
    return value


def read_world_baseline(save):
    """Read only the identity and monotonic counters needed for this run's delta."""
    try:
        document = json.loads(save.read_text(encoding='utf-8-sig'))
    except (OSError, UnicodeError, json.JSONDecodeError):
        return {'status': 'unknown', 'reason': 'save_unreadable'}
    if not isinstance(document, dict):
        return {'status': 'unknown', 'reason': 'save_root_invalid'}
    world_id = document.get('world_id')
    life = document.get('life')
    godot = document.get('godot')
    life_seq = life.get('seq') if isinstance(life, dict) else None
    godot_elapsed = godot.get('elapsed_seconds') if isinstance(godot, dict) else None
    world_elapsed = document.get('elapsed_seconds')
    if (not isinstance(world_id, str) or not world_id.strip()
            or isinstance(life_seq, bool) or not isinstance(life_seq, int) or life_seq < 0
            or _finite_number(godot_elapsed) is None or _finite_number(world_elapsed) is None):
        return {'status': 'unknown', 'reason': 'save_baseline_invalid'}
    return {'status': 'available', 'world_id': world_id, 'life_seq': life_seq,
            'godot_elapsed_seconds': _finite_number(godot_elapsed),
            'world_elapsed_seconds': _finite_number(world_elapsed)}


def classify_validation(engine_exit, capture, model_errors, budget_stop_reason,
                        shutdown_incomplete, upstream_requests):
    """Classify this formal model-validation launch, separately from engine health.

    A clean engine capture proves that the process ran, but it does not exercise the
    model-validation path. At least one validation decision and one accepted upstream
    request are required before this launcher may call the validation passed. A model
    turn that deliberately chooses ``wait`` still satisfies this gate.
    """
    decisions = _nonnegative_int(capture.get('validation_decisions_started', 0)) \
        if isinstance(capture, dict) else 0
    requests = _nonnegative_int(upstream_requests)
    exercised = decisions > 0 and requests > 0
    reasons = []
    if engine_exit != 0:
        reasons.append('engine_exit_nonzero')
    if not isinstance(capture, dict) or not capture:
        reasons.append('capture_missing_or_invalid')
    if model_errors:
        reasons.append('model_errors')
    if budget_stop_reason:
        reasons.append('budget_stop')
    if shutdown_incomplete:
        reasons.append('gateway_shutdown_incomplete')
    if reasons:
        status = 'failed'
    elif not exercised:
        status = 'not_exercised'
        if decisions == 0:
            reasons.append('no_validation_decisions')
        if requests == 0:
            reasons.append('no_upstream_requests')
    else:
        status = 'passed'
    return {'validation_status': status, 'validation_exercised': exercised,
            'validation_decisions_started': decisions,
            'classification_reasons': reasons}


def world_progress(baseline, capture, gm_document=None):
    """Compare same-world end counters to the pre-launch save baseline.

    Absolute values remain visible for diagnosis, while only positive, same-world
    deltas count as progress. The capture source_seq is reported but is never treated
    as this launch's starting sequence.
    """
    baseline = baseline if isinstance(baseline, dict) else {'status': 'unknown'}
    capture = capture if isinstance(capture, dict) else {}
    source_seq = _nonnegative_int(capture.get('source_seq', 0))
    life_seq = _nonnegative_int(capture.get('life_seq', 0))
    new_events = capture.get('new_events', [])
    event_count = len(new_events) if isinstance(new_events, list) else 0
    revision = gm_document.get('source_revision', {}) if isinstance(gm_document, dict) else {}
    revision = revision if isinstance(revision, dict) else {}
    gm_absolute = {}
    for name in ('godot_elapsed_seconds', 'world_elapsed_seconds'):
        gm_absolute[name] = _finite_number(revision.get(name))
    gm_life_raw = revision.get('life_seq')
    gm_life_seq = (gm_life_raw if isinstance(gm_life_raw, int)
                   and not isinstance(gm_life_raw, bool) and gm_life_raw >= 0 else None)
    absolute = {
        'baseline': baseline,
        'capture': {'world_id': capture.get('world_id'), 'source_seq': source_seq,
                    'life_seq': life_seq, 'new_event_count': event_count},
        'gm_export': {'world_id': gm_document.get('world_id'),
                      'source_revision': revision, **gm_absolute}
        if isinstance(gm_document, dict) else {},
    }
    if baseline.get('status') != 'available':
        return {'comparison_status': 'unknown', 'observed': False,
                'absolute': absolute, 'delta': {}}
    world_id = baseline['world_id']
    if capture.get('world_id') != world_id:
        return {'comparison_status': 'world_mismatch', 'observed': False,
                'absolute': absolute, 'delta': {}}
    gm_comparable = (not isinstance(gm_document, dict)
                     or gm_document.get('world_id') == world_id)
    delta = {
        'capture_life_seq': life_seq - baseline['life_seq'],
    }
    if gm_comparable and isinstance(gm_document, dict):
        if gm_life_seq is not None:
            delta['gm_life_seq'] = gm_life_seq - baseline['life_seq']
        if gm_absolute['godot_elapsed_seconds'] is not None:
            delta['gm_godot_elapsed_seconds'] = (gm_absolute['godot_elapsed_seconds']
                                                 - baseline['godot_elapsed_seconds'])
        if gm_absolute['world_elapsed_seconds'] is not None:
            delta['gm_world_elapsed_seconds'] = (gm_absolute['world_elapsed_seconds']
                                                 - baseline['world_elapsed_seconds'])
    comparable_deltas = [value for value in delta.values()
                         if isinstance(value, (int, float)) and not isinstance(value, bool)]
    return {'comparison_status': 'comparable' if gm_comparable else 'gm_world_mismatch',
            'observed': any(value > 0 for value in comparable_deltas),
            'absolute': absolute, 'delta': delta}


def _gm_snapshot_error(document, capture):
    if not isinstance(document, dict):
        return 'gm_export_root_invalid'
    if document.get('kind') != 'background_gm_evidence_snapshot' or document.get('schema_version') != 1:
        return 'gm_export_schema_invalid'
    world_id = document.get('world_id')
    capture_world = capture.get('world_id') if isinstance(capture, dict) else None
    if not isinstance(world_id, str) or not world_id.strip() or world_id != capture_world:
        return 'gm_export_world_mismatch'
    if not isinstance(document.get('source_revision'), dict):
        return 'gm_export_source_revision_invalid'
    boundaries = document.get('boundaries')
    if (not isinstance(boundaries, dict)
            or boundaries.get('contains_private_reply_reason') is not False
            or boundaries.get('contains_other_resident_memories') is not False):
        return 'gm_export_boundaries_invalid'
    evidence, proposals, counts = document.get('evidence'), document.get('proposals'), document.get('counts')
    if not isinstance(evidence, list) or not isinstance(proposals, list) or not isinstance(counts, dict):
        return 'gm_export_collections_invalid'
    if counts.get('issues') != len(evidence) or counts.get('proposals') != len(proposals):
        return 'gm_export_counts_invalid'
    return ''


def append_startup_fault(gm_export, capture, classification, engine_exit, upstream_requests):
    """Atomically append one idempotent, world-bound host observation.

    This never creates a GM snapshot. It can only annotate a valid snapshot emitted by
    the engine for the exact captured world, and it says the startup cause is unknown.
    """
    if gm_export is None:
        return {'status': 'not_requested'}
    if not gm_export.is_file():
        return {'status': 'refused', 'reason': 'gm_export_missing'}
    try:
        document = json.loads(gm_export.read_text(encoding='utf-8-sig'))
    except (OSError, UnicodeError, json.JSONDecodeError):
        return {'status': 'refused', 'reason': 'gm_export_unreadable'}
    error = _gm_snapshot_error(document, capture)
    if error:
        return {'status': 'refused', 'reason': error}
    world_id = document['world_id']
    source_seq = _nonnegative_int(capture.get('source_seq', 0))
    life_seq = _nonnegative_int(capture.get('life_seq', 0))
    issue_id = f'host:model-validation-startup-fault:{world_id}:{source_seq}:{life_seq}'
    for entry in document['evidence']:
        if (isinstance(entry, dict)
                and entry.get('evidence_kind') == 'model_validation_startup_fault'
                and entry.get('issue_id') == issue_id
                and entry.get('world_id') == world_id):
            return {'status': 'already_present', 'issue_id': issue_id}
    reason = ('The formal model-validation launcher did not complete a valid model-decision '
              'path; startup cause is unknown.')
    entry = {
        'evidence_kind': 'model_validation_startup_fault',
        'issue_id': issue_id,
        'world_id': world_id,
        'status': 'open',
        'occurrences': 1,
        'cause': 'unknown',
        'cause_identified': False,
        'resident_demand': False,
        'engine_exit': engine_exit,
        'validation_decisions_started': classification['validation_decisions_started'],
        'upstream_requests': _nonnegative_int(upstream_requests),
        'source_seq': source_seq,
        'life_seq': life_seq,
        'pending_count': _nonnegative_int(capture.get('pending_count', 0)),
        'first': {'reason': reason, 'source_sequence': life_seq},
        'latest': {'reason': reason, 'source_sequence': life_seq},
        'claim': {'cause_identified': False, 'resident_demand': False,
                  'note': 'Host-observed launcher fault only; it does not replace an engine issue.'},
    }
    document['evidence'].append(entry)
    document['counts']['issues'] = len(document['evidence'])
    try:
        write_private_json(gm_export, document)
    except OSError as exc:
        return {'status': 'write_failed', 'reason': type(exc).__name__}
    return {'status': 'appended', 'issue_id': issue_id}


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
    parser.add_argument('--drain-grace', type=float, default=DRAIN_GRACE_SECONDS,
                        help='Finite seconds (0..40) to let requests already accepted by this gateway settle after the engine exits; never extends the run deadline.')
    parser.add_argument('--shutdown-wait', type=float, default=SHUTDOWN_WAIT_SECONDS,
                        help='Finite seconds (0..120) the engine may spend after --seconds closing admission and awaiting already-started replies; passed to the engine and added to this launcher\'s engine process and authorization budgets.')
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
    if not 0 <= args.drain_grace <= MAX_DRAIN_GRACE_SECONDS:
        parser.error('Drain grace must be within 0..40 seconds.')
    if not 0 <= args.shutdown_wait <= MAX_SHUTDOWN_WAIT_SECONDS:
        parser.error('Shutdown wait must be within 0..120 seconds.')
    if args.inquire_text is not None and (not args.inquire_resident or not args.inquire_text.strip() or len(args.inquire_text) > 512):
        parser.error('Scripted inquiry text requires a target and 1..512 characters.')
    out, save = args.out.resolve(), args.save.resolve()
    gm_export = args.gm_export.resolve() if args.gm_export else None
    # --seconds is the episode duration; the engine's own bounded shutdown wait runs
    # after it, so the authorization deadline must cover both.
    deadline = datetime.now(timezone.utc) + timedelta(seconds=args.seconds + args.shutdown_wait + 55)
    try:
        validate_paths(out, save, gm_export)
        baseline = read_world_baseline(save)
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
    tracker = OperationTracker()
    gateway = TrackingGateway(EvidenceGateway(ledger, provider, out, gate), tracker)
    server = DrainBudgetServer(('127.0.0.1', 0), handler_type(gateway, token), grace_seconds=args.drain_grace)
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
               '--timeout', str(int(args.seconds + args.shutdown_wait) + 45), '--out', str(out), '--']
    if args.headless:
        command += ['--headless']
    command += ['--audio-driver', 'Dummy']
    command += ['res://scenes/town_street.tscn', '--', '--town-save=' + str(save), '--town-gateway',
                '--town-capture=' + str(out / 'capture'), '--town-duration=' + str(args.seconds),
                '--town-max-decisions=' + str(args.max_requests),
                '--town-shutdown-wait=' + str(args.shutdown_wait)]
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
                                capture_output=True, text=True, encoding='utf-8', errors='replace',
                                timeout=args.seconds + args.shutdown_wait + 60)
        (out / 'runner.log').write_text(result.stdout + result.stderr, encoding='utf-8')
    finally:
        # The engine is gone: stop new intake, then drain what this launcher already
        # accepted so an in-flight upstream response still settles exactly once.
        try:
            shutdown = drain_gateway(server, thread, tracker, gateway_deadline(deadline))
        except Exception as exc:
            shutdown = {'drained_complete': False, 'drain_error': type(exc).__name__}
        write_private_json(out / 'helper.json', dict(pid=os.getpid(), status='closed',
                                                     ledger_after=ledger.status(), gateway_shutdown=shutdown))
    capture_path = out / 'capture/evidence.json'
    capture = json.loads(capture_path.read_text(encoding='utf-8')) if capture_path.exists() else {}
    errors = {actor: turn['status'] for actor, turn in capture.get('resident_turns', {}).items()
              if turn.get('status') in ('pending', 'provider_error', 'rule_rejection')}
    try:
        gate.check()
    except Exception:
        pass  # The gate's persistent failure reason is reported below.
    # An explicitly incomplete gateway shutdown is never reported as passed, even when
    # the ledger still shows no unresolved row: an accepted handler may be between
    # admission and its own durable reservation when the grace expired.
    shutdown_incomplete = not shutdown.get('drained_complete', False) or bool(shutdown.get('drain_error'))
    classification = classify_validation(result.returncode, capture, errors, gate.failure,
                                         shutdown_incomplete, gate.sent)
    gm_document = None
    if gm_export is not None and gm_export.is_file():
        try:
            gm_document = json.loads(gm_export.read_text(encoding='utf-8-sig'))
        except (OSError, UnicodeError, json.JSONDecodeError):
            pass
    progress = world_progress(baseline, capture, gm_document)
    startup_fault = {'status': 'not_applicable'}
    if classification['validation_status'] == 'not_exercised':
        startup_fault = append_startup_fault(gm_export, capture, classification,
                                             result.returncode, gate.sent)
    passed = classification['validation_status'] == 'passed'
    summary = {'engine_exit': result.returncode, 'validation_passed': passed,
               **classification, 'model_errors': errors, 'ledger_before': before, 'ledger_after': ledger.status(),
               'capture_exists': (out / 'capture/evidence.json').exists(), 'original_world_promoted': False,
               'budget_stop_reason': gate.failure, 'upstream_requests': gate.sent, 'upstream_concurrency': 1,
               'carried_uncertainty_reviewed': gate.review is not None, 'gateway_shutdown': shutdown,
               'shutdown_incomplete': bool(shutdown_incomplete),
               'shutdown_wait_seconds': args.shutdown_wait,
               'world_progress_observed': progress['observed'], 'world_progress': progress,
               'startup_fault_export': startup_fault}
    (out / 'result.json').write_text(json.dumps(summary, indent=2), encoding='utf-8')
    print(json.dumps(summary))
    return 0 if passed else 1


if __name__ == '__main__':
    raise SystemExit(main())
