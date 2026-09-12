"""Launcher-only review gate; never initializes or reconciles a budget.

The JSON pin acknowledges an exact existing uncertainty set. It is not an
authorization grant. New uncertainty always stops this run. Completions are
serialized here so a waiting request cannot dispatch after an unknown result.
"""
import hashlib
import json
from pathlib import Path
import re
import secrets
import threading

from kimi_budget import BudgetDenied, InvalidRequest, encoded, fingerprint, usage_cost
from kimi_gateway import Gateway, write_private_json


def _unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise BudgetDenied('Duplicate review pin field')
        result[key] = value
    return result


def read_review_pin(path):
    try:
        return json.loads(Path(path).read_text(encoding='utf-8'), object_pairs_hook=_unique_object)
    except (OSError, ValueError, TypeError):
        raise BudgetDenied('Carried uncertainty review pin is unreadable') from None


class CarriedLedgerGate:
    def __init__(self, ledger, pin=None, concurrency=1, max_requests=12):
        self.ledger = ledger
        self.lock = threading.RLock()
        self.failure = ''
        self.owned_ids = set()
        self.sent = 0
        self.max_requests = max_requests
        self.guard_sha256 = hashlib.sha256(ledger.guard.read_bytes()).hexdigest()
        meta, rows = self._snapshot()
        if any(row['state'] == 'reserved' for row in rows.values()):
            raise BudgetDenied('Active reservations prevent a new validation run')
        uncertain = [dict(id=row['id'], state=row['state'], reserve_nano=row['reserve'])
                     for row in rows.values() if row['state'] == 'uncertain']
        uncertain.sort(key=lambda row: row['id'])
        expected = dict(schema_version=1, ledger_id=meta['ledger_id'],
                        policy_sha256=ledger.policy_hash, guard_sha256=self.guard_sha256,
                        uncertain_requests=uncertain)
        if pin is None:
            if uncertain:
                raise BudgetDenied('Existing uncertainty requires an exact carried uncertainty review pin')
        else:
            self._validate_pin(pin)
            ordered = dict(pin, uncertain_requests=sorted(pin['uncertain_requests'], key=lambda row: row['id']))
            if ordered != expected:
                raise BudgetDenied('Carried uncertainty review pin does not match the existing ledger')
        available_slots = ledger.policy.concurrency - len(uncertain)
        if type(concurrency) is not int or not 1 <= concurrency <= min(3, available_slots):
            raise BudgetDenied('Runtime concurrency must be 1..3 and fit the remaining policy slots')
        if type(max_requests) is not int or not 1 <= max_requests <= 32:
            raise BudgetDenied('Runtime request limit must be 1..32')
        self.review = expected if pin is not None else None
        self.baseline_rows = {key: encoded(row) for key, row in rows.items()}

    @staticmethod
    def _validate_pin(pin):
        keys = {'schema_version', 'ledger_id', 'policy_sha256', 'guard_sha256', 'uncertain_requests'}
        if not isinstance(pin, dict) or set(pin) != keys or type(pin['schema_version']) is not int or pin['schema_version'] != 1:
            raise BudgetDenied('Invalid carried uncertainty review pin schema')
        if not isinstance(pin['ledger_id'], str) or not pin['ledger_id']:
            raise BudgetDenied('Invalid carried uncertainty ledger identity')
        for key in ('policy_sha256', 'guard_sha256'):
            if not isinstance(pin[key], str) or not re.fullmatch('[0-9a-f]{64}', pin[key]):
                raise BudgetDenied('Invalid carried uncertainty hash')
        if not isinstance(pin['uncertain_requests'], list):
            raise BudgetDenied('Invalid carried uncertainty request list')
        ids = set()
        for row in pin['uncertain_requests']:
            if (not isinstance(row, dict) or set(row) != {'id', 'state', 'reserve_nano'}
                    or not isinstance(row['id'], str) or not re.fullmatch(r'[A-Za-z0-9_.:-]{1,128}', row['id'])
                    or row['id'] in ids or row['state'] != 'uncertain'
                    or type(row['reserve_nano']) is not int or row['reserve_nano'] <= 0):
                raise BudgetDenied('Invalid carried uncertainty request pin')
            ids.add(row['id'])

    def _snapshot(self):
        if hashlib.sha256(self.ledger.guard.read_bytes()).hexdigest() != self.guard_sha256:
            raise BudgetDenied('Original ledger guard changed during validation')
        with self.ledger.transaction() as (db, meta):
            if meta['halted']:
                raise BudgetDenied('Existing budget is halted')
            rows = {row['id']: dict(row) for row in db.execute('SELECT * FROM requests ORDER BY id')}
            for row in rows.values():
                maximum = row['maximum']
                if type(maximum) is not int or not 1 <= maximum <= self.ledger.policy.max_output:
                    raise BudgetDenied('Ledger row has an invalid output limit')
                expected_reserve = (self.ledger.policy.input_ceiling * self.ledger.policy.input_nano_per_token
                                    + maximum * self.ledger.policy.output_nano_per_token)
                if row['reserve'] != expected_reserve:
                    raise BudgetDenied('Ledger row does not retain its full policy reservation')
                if row['state'] == 'settled':
                    response = json.loads(row['response'])
                    cost, prompt, output, cached = usage_cost(response, maximum, self.ledger.policy)
                    if (cost != row['charge'] or cost > row['reserve'] or prompt != row['prompt_tokens']
                            or output != row['output_tokens'] or cached != row['cached_tokens']
                            or fingerprint(response) != row['response_sha']):
                        raise BudgetDenied('Unaccounted settled ledger row')
                elif row['state'] not in ('reserved', 'uncertain') or any(row[key] is not None for key in (
                        'charge', 'prompt_tokens', 'output_tokens', 'cached_tokens', 'response', 'response_sha', 'finished')):
                    raise BudgetDenied('Unaccounted unresolved ledger row')
            return dict(meta), rows

    def check(self, reserved_id=None):
        if self.failure:
            raise BudgetDenied(self.failure)
        try:
            _meta, rows = self._snapshot()
            if any(key not in rows or encoded(rows[key]) != value for key, value in self.baseline_rows.items()):
                raise BudgetDenied('Original ledger request facts changed during validation')
            for key, row in rows.items():
                if key in self.baseline_rows:
                    continue
                if key not in self.owned_ids:
                    raise BudgetDenied('Unaccounted request appeared during validation')
                if row['state'] == 'uncertain' or (row['state'] == 'reserved' and key != reserved_id):
                    raise BudgetDenied('New unresolved request stops all further upstream calls')
            return rows
        except Exception:
            self.failure = 'Ledger changed or a new request is unresolved; validation stopped'
            raise


class EvidenceGateway(Gateway):
    """One upstream request at a time, exact carried rows, private evidence."""
    def __init__(self, ledger, provider, out, gate):
        self.gate = gate
        self.out = Path(out)
        self.operation = None
        class CheckedProvider:
            def complete(_self, body):
                gate.check(reserved_id=self.operation)
                gate.sent += 1
                return provider.complete(body)
        super().__init__(ledger, CheckedProvider())

    def complete(self, request_id, resident, body):
        with self.gate.lock:
            rows = self.gate.check()
            if not isinstance(request_id, str) or not re.fullmatch(r'[A-Za-z0-9_.:-]{1,128}', request_id):
                raise InvalidRequest('Bounded operation identifier required')
            if request_id not in rows and self.gate.sent >= self.gate.max_requests:
                raise BudgetDenied('Validation request limit reached')
            request_dir = self.out / 'request-bodies'
            request_dir.mkdir(exist_ok=True)
            write_private_json(request_dir / (secrets.token_hex(12) + '.json'),
                               dict(operation=request_id, resident=resident, body=body))
            if request_id not in rows:
                self.gate.owned_ids.add(request_id)
            self.operation = request_id
            try:
                response = super().complete(request_id, resident, body)
            except Exception:
                # Preserve the original error, but latch any new unresolved row
                # before a queued caller obtains the run lock.
                try:
                    self.gate.check()
                except Exception:
                    pass
                raise
            finally:
                self.operation = None
            self.gate.check()
            return response
