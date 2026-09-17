"""Offline extraction of ONE already-settled town reply receipt, for a COPY of a world.

Shape of the reviewed extraction:
  python -X utf8 tools/reconcile_settled_town_reply.py \
    --ledger <existing fee ledger .sqlite3> --operation <paid operation id> \
    --resident <resident id> --body <preserved original request body json> \
    --world-save <absolute path of the world save COPY> --out <private receipt json>

The tool reads one SETTLED row of an EXISTING ledger through a read-only SQLite snapshot and
recomputes every binding with the project's own kimi_budget helpers: the normalized original
request hash, the stored response hash and the measured usage/charge. It never opens a
provider, never makes a network call, never creates a reservation and never settles anything,
and it writes nothing except the private receipt envelope it is asked for. The raw model text
travels only inside that private envelope; stdout carries hashes, counts and identifiers only.
"""
import argparse
from dataclasses import asdict
import hashlib
import json
import os
from pathlib import Path
import sqlite3
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools/kimi'))
from kimi_budget import CityValidationPolicy, InvalidRequest, Policy, fingerprint, normalize_request, usage_cost

RECEIPT_KIND = 'settled_town_reply_receipt'
RECEIPT_SCHEMA = 1
# The same bounded provider failures a settled reply may replace. Kept identical to
# game/agents/town_turns.gd RECOVERABLE_PROVIDER_ERRORS so both sides refuse the same states.
RECOVERABLE_PROVIDER_ERRORS = ('brain_run_failed', 'brain_run_canceled', 'brain_timeout',
                               'brain_gateway_rejected_or_uncertain', 'brain_provider_failed')
MAX_FILE_BYTES = 64 * 1024 * 1024


class Refused(Exception):
    """A named, non-mutating refusal: nothing was read from, or written to, any durable state."""

    def __init__(self, code):
        super().__init__(code)
        self.code = code


def _require(value, code):
    if not value:
        raise Refused(code)
    return value


def _small_file(path):
    info = Path(path)
    _require(info.is_file(), 'input_file_missing:' + str(path))
    _require(0 < info.stat().st_size <= MAX_FILE_BYTES, 'input_file_size_rejected:' + str(path))
    return info


def _json(path):
    return json.loads(_small_file(path).read_text(encoding='utf-8'))


def sha256_file(path):
    digest = hashlib.sha256()
    with _small_file(path).open('rb') as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b''):
            digest.update(block)
    return digest.hexdigest()


def policy_for(ledger_path):
    """Rebuild the fee ledger's own policy from its guard, without constructing its object."""
    guard_path = Path(ledger_path).with_suffix('.guard.json')
    guard = _require(_json(guard_path), 'ledger_guard_missing')
    _require(isinstance(guard.get('policy'), dict), 'ledger_guard_policy_invalid')
    policy_type = CityValidationPolicy if 'request_limit' in guard['policy'] else Policy
    try:
        policy = policy_type(**guard['policy'])
    except TypeError:
        raise Refused('ledger_guard_policy_invalid') from None
    _require(fingerprint(asdict(policy)) == guard.get('policy_sha256'), 'ledger_guard_fingerprint_mismatch')
    return policy, guard


def readonly_uri(ledger_path):
    """A read-only snapshot uri. No write-capable connection is ever opened."""
    resolved = Path(ledger_path).resolve().as_posix()
    journal = Path(str(ledger_path) + '-wal')
    if journal.is_file() and journal.stat().st_size > 0:
        # A write journal holds authoritative frames, so they must be read; SQLite still
        # writes no billing data and only uses its own shared-memory sidecar.
        return 'file:' + resolved + '?mode=ro'
    # Quiescent ledger: an immutable snapshot needs no lock, no sidecar and no journal.
    return 'file:' + resolved + '?mode=ro&immutable=1'


def read_settled_row(ledger_path, operation, policy, guard):
    """One explicit read transaction over a read-only connection: exactly one row, no writes."""
    uri = readonly_uri(ledger_path)
    try:
        connection = sqlite3.connect(uri, uri=True)
    except sqlite3.Error:
        # A write journal with no live writer still needs a readable sidecar; never fall back
        # to a write-capable connection against a billing ledger.
        raise Refused('ledger_readonly_open_failed') from None
    try:
        # Autocommit off means this connection only ever opens the read transaction started below.
        connection.isolation_level = None
        connection.row_factory = sqlite3.Row
        connection.execute('PRAGMA query_only=ON')
        _require(connection.execute('PRAGMA quick_check').fetchone()[0] == 'ok', 'ledger_integrity_check_failed')
        # One explicit read transaction: the meta row and the request row are read together.
        connection.execute('BEGIN')
        meta = connection.execute('SELECT * FROM meta WHERE id=1').fetchone()
        _require(meta is not None, 'ledger_meta_missing')
        _require(meta['ledger_id'] == guard.get('ledger_id'), 'ledger_identity_mismatch')
        _require(meta['policy_sha256'] == guard.get('policy_sha256'), 'ledger_policy_mismatch')
        row = connection.execute(
            'SELECT id, resident, payload_sha, maximum, reserve, state, charge, prompt_tokens, output_tokens,'
            ' cached_tokens, response, response_sha, created, finished, note FROM requests WHERE id=?',
            (operation,)).fetchone()
    except sqlite3.Error:
        raise Refused('ledger_unreadable') from None
    finally:
        try:
            connection.rollback()
        except sqlite3.Error:
            pass
        connection.close()
    _require(row is not None, 'ledger_row_absent')
    return dict(row), {'ledger_id': meta['ledger_id'], 'policy_sha256': meta['policy_sha256']}


def _world_record(world, resident):
    godot = world.get('godot') if isinstance(world, dict) else None
    _require(isinstance(godot, dict), 'world_save_shape_invalid')
    turns = godot.get('resident_turns')
    _require(isinstance(turns, dict) and isinstance(turns.get(resident), dict), 'resident_turn_absent')
    return turns[resident]


def extract(args):
    """Return the private receipt dict, or refuse with a named code and no side effect."""
    policy, guard = policy_for(args.ledger)
    try:
        body_file = _json(args.body)
    except ValueError:
        raise Refused('body_json_invalid') from None
    _require(isinstance(body_file, dict), 'body_envelope_invalid')
    _require(str(body_file.get('operation', '')) == args.operation, 'body_operation_mismatch')
    _require(str(body_file.get('resident', '')) == args.resident, 'body_resident_mismatch')
    request_body = body_file.get('body')
    _require(isinstance(request_body, dict), 'body_request_missing')

    row, ledger = read_settled_row(args.ledger, args.operation, policy, guard)
    _require(row['resident'] == args.resident, 'ledger_resident_mismatch')
    _require(row['state'] == 'settled', 'ledger_row_not_settled:' + str(row['state']))

    try:
        clean = normalize_request(request_body, policy)
    except InvalidRequest:
        raise Refused('body_not_a_valid_request') from None
    payload_sha = fingerprint(clean)
    _require(payload_sha == row['payload_sha'], 'body_hash_mismatch')
    try:
        response = json.loads(row['response'])
    except (TypeError, ValueError):
        raise Refused('ledger_response_unreadable') from None
    _require(isinstance(response, dict), 'ledger_response_invalid')
    _require(fingerprint(response) == row['response_sha'], 'response_hash_mismatch')
    try:
        charge, prompt, output, cached = usage_cost(response, row['maximum'], policy)
    except InvalidRequest:
        raise Refused('response_usage_invalid') from None
    _require(charge == row['charge'], 'usage_charge_mismatch')
    _require(prompt == row['prompt_tokens'] and output == row['output_tokens']
             and cached == row['cached_tokens'], 'usage_tokens_mismatch')
    _require(charge <= row['reserve'], 'usage_charge_exceeds_reservation')

    source_sha = sha256_file(args.world_save)
    if args.source_sha256:
        _require(source_sha == args.source_sha256.lower(), 'source_hash_mismatch')
    try:
        world = _json(args.world_save)
    except ValueError:
        raise Refused('world_save_json_invalid') from None
    _require(isinstance(world, dict), 'world_save_shape_invalid')
    world_id = str(world.get('world_id', ''))
    _require(world_id, 'world_id_missing')
    if args.world_id:
        _require(world_id == args.world_id, 'world_id_mismatch')
    record = _world_record(world, args.resident)
    request_id = str(record.get('request_id', ''))
    _require(request_id, 'turn_request_id_missing')
    if args.request_id:
        _require(request_id == args.request_id, 'turn_request_mismatch')
    _require(str(record.get('provider_command_id', '')) == args.operation, 'turn_operation_mismatch')
    _require(int(record.get('controller_epoch', -1)) == args.epoch, 'turn_epoch_mismatch')
    _require(str(record.get('status', '')) == 'provider_error', 'turn_not_provider_error')
    _require(str(record.get('error', '')) in RECOVERABLE_PROVIDER_ERRORS, 'turn_error_not_recoverable')
    failed = record.get('accepted_reply')
    _require(isinstance(failed, dict) and failed.get('ok') is False, 'turn_has_applied_reply')
    _require(str(failed.get('command_id', '')) == args.operation, 'turn_failed_reply_operation_mismatch')
    # The provenance is the world's own record of the failed turn, never a caller label:
    # a receipt may not relabel a live run as a fixture or the reverse.
    provenance = str(failed.get('provenance', '')) or str(failed.get('provider_id', ''))
    _require(provenance, 'turn_provenance_missing')
    _require(provenance == args.provider_id, 'turn_provenance_mismatch')

    godot = world['godot']
    archive = godot.get('resident_archive')
    _require(isinstance(archive, dict) and str(archive.get('world_id', '')) == world_id, 'failure_archive_missing')
    entries = archive.get('entries')
    _require(isinstance(entries, dict) and isinstance(entries.get(request_id), dict), 'failure_archive_missing')
    entry = entries[request_id]
    _require(str(entry.get('world_id', '')) == world_id and str(entry.get('resident_id', '')) == args.resident,
             'failure_archive_identity_mismatch')
    _require(entry.get('original_reply') == failed, 'failure_archive_reply_mismatch')
    application = entry.get('application')
    _require(isinstance(application, dict) and str(application.get('status', '')) == 'provider_error',
             'failure_archive_not_provider_error')
    replays = entry.get('replays', [])
    _require(isinstance(replays, list), 'failure_archive_replays_invalid')
    _require(not replays, 'failure_archive_has_replays')

    choices = response.get('choices')
    _require(isinstance(choices, list) and choices and isinstance(choices[0], dict), 'response_choices_invalid')
    message = choices[0].get('message')
    _require(isinstance(message, dict) and isinstance(message.get('content'), str), 'response_text_missing')
    text = message['content']
    _require(0 < len(text) <= 16384, 'response_text_size_rejected')
    try:
        _require(isinstance(json.loads(text), dict), 'response_text_not_a_decision')
    except ValueError:
        raise Refused('response_text_not_a_decision') from None

    return {
        'schema_version': RECEIPT_SCHEMA,
        'kind': RECEIPT_KIND,
        'source': {
            'world_id': world_id, 'source_sha256': source_sha, 'resident_id': args.resident,
            'request_id': request_id, 'controller_epoch': args.epoch,
            'provider_operation_id': args.operation, 'provider_id': provenance,
        },
        'failure': {
            'controller_status': 'provider_error', 'error': str(record.get('error', '')),
            'error_detail': str(record.get('error_detail', '')), 'original_failed_reply': failed,
        },
        'archive': {
            'archive_id': request_id, 'application_status': 'provider_error',
            'application_code': str(application.get('code', '')), 'replays': 0,
        },
        'ledger': {
            'ledger_id': ledger['ledger_id'], 'policy_sha256': ledger['policy_sha256'], 'state': 'settled',
            'payload_sha256': payload_sha, 'response_sha256': row['response_sha'], 'charge_nano': charge,
            'prompt_tokens': prompt, 'output_tokens': output, 'cached_tokens': cached,
            'maximum': row['maximum'], 'reserve_nano': row['reserve'],
        },
        'reply': {
            'command_id': args.operation, 'assistant_text': text,
            'assistant_text_sha256': hashlib.sha256(text.encode('utf-8')).hexdigest(),
        },
    }


def write_receipt(path, receipt):
    target = Path(path)
    target.parent.mkdir(parents=True, exist_ok=True)
    temporary = target.with_name(target.name + '.tmp')
    # Exclusive creation: never replace a file this step did not just create.
    with temporary.open('x', encoding='utf-8') as handle:
        handle.write(json.dumps(receipt, ensure_ascii=False, indent=2))
        handle.flush()
        os.fsync(handle.fileno())
    os.replace(temporary, target)
    return target


def protected_inputs(args):
    return [args.ledger, args.ledger.with_suffix('.guard.json'), args.body, args.world_save]


def output_conflict(args):
    """Refuse any output (or its fixed temporary name) that could touch an input or an existing file."""
    target = Path(args.out).resolve()
    temporary = Path(str(args.out) + '.tmp').resolve()
    for protected in protected_inputs(args):
        resolved = Path(protected).resolve()
        if target == resolved or temporary == resolved:
            return 'receipt_target_would_overwrite_input'
    if target.exists():
        return 'receipt_target_exists'
    if temporary.exists():
        return 'receipt_temp_exists'
    return ''


def summary(receipt, receipt_path):
    """Private-safe stdout projection: hashes, counts and identifiers only."""
    return {
        'ok': True, 'code': 'receipt_written', 'receipt': str(receipt_path),
        'world_id': receipt['source']['world_id'], 'source_sha256': receipt['source']['source_sha256'],
        'resident_id': receipt['source']['resident_id'], 'request_id': receipt['source']['request_id'],
        'controller_epoch': receipt['source']['controller_epoch'],
        'provider_operation_id': receipt['source']['provider_operation_id'],
        'provider_id': receipt['source']['provider_id'],
        'payload_sha256': receipt['ledger']['payload_sha256'],
        'response_sha256': receipt['ledger']['response_sha256'],
        'charge_nano': receipt['ledger']['charge_nano'], 'prompt_tokens': receipt['ledger']['prompt_tokens'],
        'output_tokens': receipt['ledger']['output_tokens'], 'cached_tokens': receipt['ledger']['cached_tokens'],
        'assistant_text_sha256': receipt['reply']['assistant_text_sha256'],
        'assistant_text_chars': len(receipt['reply']['assistant_text']),
    }


def parse(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--ledger', type=Path, required=True)
    parser.add_argument('--operation', required=True)
    parser.add_argument('--resident', required=True)
    parser.add_argument('--body', type=Path, required=True, help='preserved original request body json')
    parser.add_argument('--world-save', type=Path, required=True)
    parser.add_argument('--source-sha256', default='', help='optional pin for the exact save bytes')
    parser.add_argument('--world-id', default='', help='optional pin for the save world identity')
    parser.add_argument('--request-id', default='', help='optional pin for the turn request id')
    parser.add_argument('--epoch', type=int, required=True)
    parser.add_argument('--provider-id', default='opengameagent_live')
    parser.add_argument('--out', type=Path, required=True)
    return parser.parse_args(argv)


def main(argv=None):
    args = parse(argv)
    conflict = output_conflict(args)
    if conflict:
        print(json.dumps({'ok': False, 'code': conflict}))
        return 2
    try:
        receipt = extract(args)
    except Refused as refusal:
        print(json.dumps({'ok': False, 'code': refusal.code}))
        return 1
    try:
        written = write_receipt(args.out, receipt)
    except OSError:
        print(json.dumps({'ok': False, 'code': 'receipt_write_failed'}))
        return 1
    print(json.dumps(summary(receipt, written), ensure_ascii=False))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
