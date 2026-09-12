#!/usr/bin/env python3
"""Bounded local runner for ten independent DeepSeek BACKGROUND GM sessions.

`observe` imports one reviewed world-evidence snapshot exported by the game
(kind=background_gm_evidence_snapshot), registers ten stable GM ids (no resident
bodies), keeps one authoritative local state file, deduplicates issues by their
authoritative source identity and per-issue content, and dispatches one bounded
native `codex exec` turn per GM (DeepSeek Flash, Responses wire API) with a stable
prompt prefix and a persistent per-GM session.

`code` dispatches the single active coding worker of the GM that currently owns an
issue into an isolated candidate checkout based on an explicitly approved revision.
Candidate changes, base hash and test evidence stay unapproved until a supervisor
reviews them.

Controls here: no global Codex config mutation (--ignore-user-config plus invocation
overrides), no automatic retry of uncertain requests, one authoritative state snapshot,
one writer per issue, one world per state directory, and unknown usage stops dispatch.
Native tools request read-only observation or workspace-write candidate sandboxing with
network disabled; there is no danger-full-access fallback. Instructions prohibit secret
reads, maintained-save writes, commits, pushes and additional model calls. Candidate and
protected-path checks detect mutations after execution; fake-process tests do not prove
native platform sandbox enforcement.

Commands (repository-relative):
  python tools/gm_runner.py observe --evidence <reviewed.json> --state-dir <out> --dry-run
  python tools/gm_runner.py observe --evidence <reviewed.json> --state-dir <out> --max-gms 2
  python tools/gm_runner.py code --state-dir <out> --issue <issue-id> --scope-file <scope.json>
      --base-revision <approved-sha> --dry-run
  python tools/gm_runner.py status --state-dir <out>
  python tools/gm_runner.py recover --state-dir <out> --gm gm-01 --note "..." --usage unknown
  python tools/gm_runner.py acknowledge --state-dir <out> --gm gm-01 --note "..."

Exit codes: 0 ok, 1 runtime failure, 2 usage or route preflight, 3 stale source,
4 unacceptable source (malformed or wrong world binding), 5 unresolved accounting or
recovery required, 6 coding precondition / scope / base mismatch, 7 state directory
lock held by a live run.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import math
import os
import re
import shlex
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CONFIG = ROOT / 'secrets' / 'deepseek.local.json'
DEFAULT_KEY_FILE = ROOT / 'secrets' / 'deepseek-key.txt'
DEFAULT_PRIOR_LEDGER = ROOT / 'tmp' / 'overnight-20260912' / 'ledger.json'
STATE_FILE = 'state.json'
LEGACY_STATE_FILES = ('registry.json', 'sessions.json')

GM_IDS = [f'gm-{index:02d}' for index in range(1, 11)]
GM_FOCUS = {
    'gm-01': 'collisions and travel: blocked, stuck, clipping or unreachable goals in world evidence',
    'gm-02': 'capability gaps: accepted resident proposals the world cannot satisfy yet',
    'gm-03': 'trade and payment: prices, deferred payment, receipts and accounting mismatch',
    'gm-04': 'tools and inventory: ownership, availability, consumption and loss of items',
    'gm-05': 'resources and foraging: stock, capacity, production and consumption balance',
    'gm-06': 'perception and attribution: whether the right resident can learn a world change',
    'gm-07': 'persistence: cold restart, save fidelity and continued facts after reload',
    'gm-08': 'time and turn ordering: schedules, sequence gaps and out-of-order turns',
    'gm-09': 'blocked feedback: how a resident learns of an obstruction and reacts to it',
    'gm-10': 'property and commitments: ownership, contracts, cancellation and accepted work',
}

EVIDENCE_KIND = 'background_gm_evidence_snapshot'
EVIDENCE_SCHEMA = 1
STATE_SCHEMA = 2
REQUIRED_BOUNDARY_FLAGS = ('contains_private_reply_reason', 'contains_other_resident_memories')
DISPOSITIONS = ('observe', 'proposal', 'no_action')
CLOSED_STATES = ('closed', 'resolved', 'cancelled', 'retracted')
REPAIRABLE_STATUSES = ('scope_tests_failed', 'invalid_output', 'worker_blocked')
# Authoritative per-issue source identity. proposal_id / issue_id come first so that
# two residents proposing the same capability keep two separate issue sources.
IDENTITY_FIELDS = ('proposal_id', 'issue_id', 'symbol_id', 'collision_id', 'request_id')
SESSION_UUID = re.compile(r'[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}')
KEY_PATTERN = re.compile(r'sk-[A-Za-z0-9_-]{16,200}')
PROXY_KEYS = ('HTTP_PROXY', 'HTTPS_PROXY', 'ALL_PROXY', 'http_proxy', 'https_proxy', 'all_proxy')
SECRET_ENV_KEYS = ('DEEPSEEK_API_KEY', 'OPENAI_API_KEY', 'KIMI_API_KEY', 'MOONSHOT_API_KEY')
USAGE_FIELDS = ('input_tokens', 'cached_input_tokens', 'cache_write_input_tokens',
                'output_tokens', 'reasoning_output_tokens', 'total_tokens')

STABLE_INSTRUCTIONS = """You are one of ten independent BACKGROUND GM processes of the InfiniteAincrad persistent world.
You inspect world-scoped evidence and decide whether one bounded issue needs work from you.

Provenance is part of the evidence and must be read literally:
- The COMMON WORLD EVIDENCE block is a bounded projection exported by the running game world.
- When it says the export is a deterministic offline fixture, it is a fixture: not live resident
  demand, not proof that a resident acted, and not proof that any capability exists.
- claim.implemented=false / verified_in_world=false mean the thing is NOT achieved.
- An issue absent from the current projection is simply not exported right now; that is not proof
  that it was fixed.
- A model statement is never a verified bug. Report only what the evidence shows, and say when you
  are inferring.

Residents are people living in the world, not developers. Never send a resident developer tasks,
code, test logs, GM discussion, issue ids or diagnostics; residents learn about world changes only
through attributed perception and use. Do not claim a resident learned, owns or did something the
evidence does not show.

In an observation turn you may read repository files for context. You must not modify the
repository, the world save or configuration, must not run paid or NPC model calls, must not read
secrets or private saves, and must not commit or push.

OUTPUT CONTRACT: end your turn with exactly one fenced ```json block and nothing after it:
{"gm_id": "<gm id from GM STATE>",
 "results": [{"issue_id": "<copied verbatim from open_issues>",
              "disposition": "observe" | "proposal" | "no_action",
              "claim_coding": true | false,
              "summary": "<=400 chars",
              "evidence_refs": ["<ref>"]}],
 "new_issues": [{"proposal_key": "<stable short key>", "summary": "<=400 chars",
                 "evidence_refs": ["<pointer from investigation.evidence_refs>"],
                 "claim_coding": true | false}],
 "note": "<optional, <=200 chars>"}
Rules for results:
- every issue_id must be copied verbatim from open_issues in your GM STATE block;
- use disposition "no_action" when a listed issue needs no action from you, and then claim_coding
  must be false;
- claim_coding=true means you propose to implement a fix yourself and may be rejected: only one
  active coding worker may own an issue, and a claim on an issue already owned by another GM is
  refused;
- if open_issues is empty return "results": [].
- new_issues is optional and permits at most ONE evidence-backed hypothesis, only when
  GM STATE contains an investigation. Copy its evidence_refs literally. An investigation is
  supervisor_specified: never describe it as spontaneous discovery. Your proposal is unverified,
  does not grant coding scope, and must retain the distinction between observed facts and inference.
- return new_issues: [] when investigation yields no concrete supported proposal; do not invent work.
"""

STABLE_CODE_INSTRUCTIONS = """You are the active coding worker of one of the ten BACKGROUND GMs of the InfiniteAincrad
persistent world. You keep that GM's identity and history. You work inside an isolated candidate
checkout created from the approved revision.

Rules: implement only the explicit coding scope given to you; touch only the scope files; work only
inside the candidate directory; never commit, push, or touch the git metadata of the main checkout;
never modify a maintained world save, private/secret files or configuration; never read API keys;
no paid NPC/GM model calls and no network fetches; if a declared test command fails, fix the
candidate and re-run it.

Your completion is NOT a deployment. The supervisor reviews changed files, base revision and test
evidence before anything is accepted. A change outside the scope files, or any commit, is a
failure.

OUTPUT CONTRACT: end your turn with exactly one fenced ```json block and nothing after it:
{"issue_id": "<the issue id from CODING SCOPE>",
 "status": "implemented" | "blocked",
 "changed_files": ["<path relative to the candidate>"],
 "test_commands": [["<argv>"]],
 "test_results": "<=800 chars",
 "notes": "<=400 chars>"}
"""


def utc_stamp() -> str:
    return dt.datetime.now(dt.timezone.utc).strftime('%Y%m%dT%H%M%SZ')


def utc_iso() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat()


def sha256_bytes(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()


def sha256_file(path: Path) -> str:
    return sha256_bytes(Path(path).read_bytes())


def save_json(path: Path, value) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + '.next')
    temporary.write_text(json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + '\n',
                         encoding='utf-8')
    os.replace(temporary, path)


def load_json(path: Path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def canonical(value) -> str:
    return json.dumps(value, ensure_ascii=False, sort_keys=True)


def emit(payload, exit_code: int) -> int:
    print(json.dumps(payload, ensure_ascii=False, sort_keys=True, default=str), flush=True)
    return exit_code


def refusal(kind: str, message: str, exit_code: int, **extra) -> int:
    payload = {'status': 'refused', 'kind': kind, 'message': message}
    payload.update(extra)
    return emit(payload, exit_code)


def git(argv, cwd=ROOT, timeout=180):
    return subprocess.run(['git', *argv], cwd=str(cwd), capture_output=True, text=True,
                          encoding='utf-8', errors='replace', timeout=timeout)


def relative(path: Path) -> str:
    try:
        return str(Path(path).resolve().relative_to(ROOT))
    except ValueError:
        return str(Path(path).resolve())


def usage_is_measured(usage) -> bool:
    """Only real numeric counters count as measured provider usage."""
    if not isinstance(usage, dict):
        return False
    for field in ('input_tokens', 'output_tokens'):
        value = usage.get(field)
        if (isinstance(value, bool) or not isinstance(value, (int, float))
                or not math.isfinite(value) or value < 0):
            return False
    for field in USAGE_FIELDS:
        if field in usage and (isinstance(usage[field], bool)
                               or not isinstance(usage[field], (int, float))
                               or not math.isfinite(usage[field]) or usage[field] < 0):
            return False
    if usage.get('cached_input_tokens', 0) > usage['input_tokens']:
        return False
    if usage.get('reasoning_output_tokens', 0) > usage['output_tokens']:
        return False
    return True


def account_native_usage(state: dict, attempt: dict, resume_id: str | None) -> None:
    """Codex turn.completed.usage is session cumulative, including resumed history.

    Keep the native counters separately and expose only a persisted highwater delta as
    additive `usage`. Missing baselines and decreases are unknown, never zero or a reset.
    Old runner records remain untouched; their raw cumulative usage can seed the baseline.
    """
    cumulative = attempt.get('usage')
    attempt['usage_cumulative'] = cumulative
    attempt['usage_accounting'] = {'basis': 'native_session_cumulative_highwater',
                                   'status': 'unknown', 'baseline': None}
    session = attempt.get('thread_returned') or resume_id
    if not usage_is_measured(cumulative):
        attempt['usage'] = None
        attempt['usage_measured'] = False
        return
    if not session:
        # A new invocation's measured counters remain additive even if the transport omitted
        # its session id; no durable resume baseline can be associated with that measurement.
        attempt['usage_accounting']['status'] = 'unbound_measurement'
        return
    highwaters = state.setdefault('usage_highwater', {})
    previous = highwaters.get(session)
    if previous is None and resume_id == session:
        legacy = []
        for record in state['sessions'].values():
            legacy.extend(record.get('attempts', []))
            legacy.extend((record.get('coding') or {}).get('attempts', []))
        for record in state['issues'].values():
            if record.get('coding_provider_result'):
                legacy.append(record['coding_provider_result'])
        for old in legacy:
            if old.get('session_returned') != session:
                continue
            raw = old.get('usage_cumulative') if 'usage_cumulative' in old else old.get('usage')
            if usage_is_measured(raw):
                previous = {field: max((previous or {}).get(field, 0), raw[field])
                            for field in USAGE_FIELDS if field in raw}
        if previous is None:
            attempt['usage_accounting']['status'] = 'missing_resume_baseline'
            attempt['usage'] = None
            attempt['usage_measured'] = False
            return
    baseline = previous or {field: 0 for field in USAGE_FIELDS if field in cumulative}
    attempt['usage_accounting']['baseline'] = baseline
    if any(cumulative[field] < baseline[field] for field in USAGE_FIELDS
           if field in cumulative and field in baseline):
        attempt['usage_accounting']['status'] = 'counter_decreased'
        attempt['usage'] = None
        attempt['usage_measured'] = False
        return
    delta = {field: cumulative[field] - baseline[field] for field in USAGE_FIELDS
             if field in cumulative and field in baseline}
    if not usage_is_measured(delta):
        attempt['usage'] = None
        attempt['usage_measured'] = False
        attempt['usage_accounting']['status'] = 'invalid_delta'
        return
    highwaters[session] = {**baseline, **{field: cumulative[field] for field in USAGE_FIELDS
                                         if field in cumulative}}
    attempt['usage'] = delta
    attempt['usage_measured'] = usage_is_measured(delta)
    attempt['usage_accounting'].update({'status': 'measured_delta', 'session_id': session,
                                       'unknown_detail_fields': [field for field in USAGE_FIELDS
                                                                if field not in delta],
                                       'coverage': 'since last measured session highwater'})


def usage_evidence(attempt: dict) -> dict:
    return {key: attempt.get(key) for key in ('usage_cumulative', 'usage_accounting')}


# --------------------------------------------------------------------------- route

WINDOWS_SANDBOX_BACKENDS = ('elevated', 'unelevated')


def codex_home_path(codex_home: Path | None) -> Path:
    return Path(codex_home).resolve() if codex_home \
        else Path(os.environ.get('CODEX_HOME', str(Path.home() / '.codex')))


def read_windows_sandbox_backend(codex_home: Path, is_windows: bool | None = None) -> str:
    """Return ONLY the configured `windows.sandbox` backend, or '' off Windows.

    The Codex user config may contain provider credentials and unrelated settings, so this
    parses the file with a strict allowlist and never returns, logs or copies any other
    field. An unsupported, malformed or missing backend is a hard preflight failure: this
    runner never guesses a sandbox backend and never selects a weaker one.
    """
    if is_windows is None:
        is_windows = os.name == 'nt'
    if not is_windows:
        return ''
    config_path = Path(codex_home) / 'config.toml'
    if not config_path.is_file():
        raise ValueError(
            f'no Codex config at {config_path}; the Windows sandbox backend cannot be '
            'verified, so this runner refuses to dispatch')
    try:
        import tomllib
        with config_path.open('rb') as handle:
            document = tomllib.load(handle)
    except Exception as error:  # parse/permission/encoding: never expose file content
        raise ValueError(
            f'cannot read windows.sandbox from {config_path} ({type(error).__name__}); '
            'refusing to dispatch without a verified sandbox backend')
    windows = document.get('windows') if isinstance(document, dict) else None
    value = windows.get('sandbox') if isinstance(windows, dict) else None
    if value is None:
        raise ValueError(
            f'{config_path} does not declare windows.sandbox; this runner will not guess a '
            'sandbox backend')
    if value not in WINDOWS_SANDBOX_BACKENDS:
        # Deliberately does not echo the supplied value: a misplaced secret in the wrong key
        # must never reach logs, summaries or errors.
        raise ValueError(
            f'{config_path} declares an unsupported windows.sandbox value; supported values are '
            f'{list(WINDOWS_SANDBOX_BACKENDS)}')
    return value


def codex_argv_from(value: str) -> list[str]:
    """Split a quoted test command line, but never split a real executable path.

    The installed Windows launcher lives under a path with spaces (for example
    C:/Users/<user>/AppData/Local/OpenAI/Codex/bin/<hash>/codex.EXE); splitting that
    value would produce unusable tokens, so an existing file always stays one token.
    """
    value = value.strip()
    if Path(value).is_file():
        return [value]
    return shlex.split(value) if ' ' in value else [value]


class Route:
    """Everything a native codex dispatch needs, loaded from ignored user files."""

    def __init__(self, config_path: Path, key_path: Path, codex: str, codex_home: Path | None):
        self.config_path, self.key_path = Path(config_path).resolve(), Path(key_path).resolve()
        if not self.config_path.is_file():
            raise ValueError(f'route config not found: {self.config_path}')
        if not self.key_path.is_file():
            raise ValueError(f'key file not found: {self.key_path}')
        settings = load_json(self.config_path)
        if settings.get('model') != 'deepseek-flash':
            raise ValueError('route config model must be deepseek-flash')
        if str(settings.get('base_url', '')).rstrip('/') != 'https://api.deepseek.com':
            raise ValueError('route config base_url must be https://api.deepseek.com')
        self.key = self.key_path.read_text(encoding='utf-8-sig').strip()
        if not KEY_PATTERN.fullmatch(self.key):
            raise ValueError('key file does not hold a single API key')
        self.codex_argv = codex_argv_from(codex)
        self.codex_home = Path(codex_home).resolve() if codex_home else None
        # Only the configured Windows backend is forwarded, and only as the existing choice;
        # a missing/unsupported backend fails here, before any paid dispatch.
        self.windows_sandbox = read_windows_sandbox_backend(codex_home_path(codex_home))
        self.config_sha256 = sha256_file(self.config_path)
        self.key_sha256 = sha256_bytes(self.key.encode())

    def reference(self) -> dict:
        """Non-secret description; never contains the key or another credential value."""
        return {'config_path': relative(self.config_path), 'config_sha256': self.config_sha256,
                'key_path': relative(self.key_path), 'key_sha256': self.key_sha256,
                'model': 'deepseek-flash', 'wire_api': 'responses',
                'codex_argv': self.codex_argv,
                'codex_home': str(self.codex_home) if self.codex_home else None,
                'windows_sandbox': self.windows_sandbox or None}

    def environment(self) -> dict:
        env = dict(os.environ)
        env['DEEPSEEK_API_KEY'] = self.key
        env['PYTHONUTF8'] = '1'
        for name in PROXY_KEYS:
            env.pop(name, None)
        if self.codex_home:
            env['CODEX_HOME'] = str(self.codex_home)
        return env

    def test_environment(self) -> dict:
        """Environment for candidate test commands: no credential values at all."""
        env = self.environment()
        for name in (*SECRET_ENV_KEYS, *PROXY_KEYS):
            env.pop(name, None)
        return env

    def assert_no_credential(self, text: str, where: str) -> None:
        if self.key in text:
            raise ValueError(f'credential leak refused in {where}')

    def sessions_root(self) -> Path:
        base = self.codex_home or Path(os.environ.get('CODEX_HOME', str(Path.home() / '.codex')))
        return base / 'sessions'

    def preflight_resume(self, session_id: str) -> str | None:
        """Return a refusal reason when a resume id cannot be proven to exist."""
        if not SESSION_UUID.fullmatch(session_id):
            return (f'resume id {session_id!r} is not a canonical session UUID; refusing the CLI '
                    'fallback to a new session')
        if not any(self.sessions_root().glob(f'*/*/*/rollout-*-{session_id}.jsonl')):
            return (f'no saved rollout for resume id {session_id}; refusing the CLI fallback to a '
                    'new session')
        return None


def codex_catalog(instructions: str) -> dict:
    return {'models': [{
        'slug': 'deepseek-flash', 'display_name': 'DeepSeek Flash',
        'description': 'DeepSeek development executor',
        'default_reasoning_level': 'low',
        'supported_reasoning_levels': [
            {'effort': 'low', 'description': 'Observation and implementation'},
            {'effort': 'high', 'description': 'Difficult repair'},
            {'effort': 'max', 'description': 'Difficult reasoning'}],
        'shell_type': 'shell_command', 'visibility': 'list', 'supported_in_api': True, 'priority': 1,
        'base_instructions': instructions,
        'model_messages': {'instructions_template': instructions, 'instructions_variables': {}},
        'context_window': 1048576, 'max_context_window': 1048576,
        'effective_context_window_percent': 95, 'supports_reasoning_summaries': False,
        'support_verbosity': False, 'supports_parallel_tool_calls': True,
        'experimental_supported_tools': [], 'apply_patch_tool_type': 'freeform',
        'truncation_policy': {'mode': 'tokens', 'limit': 8000},
        'input_modalities': ['text', 'image'], 'supports_image_detail_original': True,
        'prefer_websockets': False}]}


def codex_command(route: Route, workdir: Path, result_path: Path, instructions_path: Path,
                  catalog_path: Path, resume_id: str | None,
                  sandbox: str = 'read-only') -> list[str]:
    command = [*route.codex_argv, 'exec', '--ignore-user-config', '-C', str(workdir),
               '-s', sandbox, '--json', '--color', 'never', '-o', str(result_path)]
    values = {'model': 'deepseek-flash', 'model_provider': 'chain_deepseek',
              'model_reasoning_effort': 'low', 'model_catalog_json': str(catalog_path),
              'model_instructions_file': str(instructions_path), 'approval_policy': 'never',
              'model_providers.chain_deepseek.name': 'DeepSeek',
              'model_providers.chain_deepseek.base_url': 'https://api.deepseek.com',
              'model_providers.chain_deepseek.env_key': 'DEEPSEEK_API_KEY',
              'model_providers.chain_deepseek.wire_api': 'responses',
              'model_providers.chain_deepseek.request_max_retries': 0,
              'model_providers.chain_deepseek.stream_max_retries': 0,
              'model_providers.chain_deepseek.supports_websockets': False,
              'features.multi_agent': False,
              'sandbox_workspace_write.network_access': False,
              'sandbox_workspace_write.exclude_tmpdir_env_var': True,
              'sandbox_workspace_write.exclude_slash_tmp': True,
              'shell_environment_policy.exclude': list(SECRET_ENV_KEYS),
              'web_search': 'disabled'}
    if route.windows_sandbox:
        # Carry the host's already-configured Windows sandbox backend into this invocation,
        # preserving the requested -s policy above unchanged. This forwards a setting only;
        # actual containment still requires separate verification.
        values['windows.sandbox'] = route.windows_sandbox
    for name, value in values.items():
        command += ['-c', name + '=' + json.dumps(value)]
    if resume_id:
        command += ['resume', resume_id]
    command += ['-']
    return command


# --------------------------------------------------------------------------- lock

def try_exclusive_lock(handle) -> bool:
    """Non-blocking, OS-level exclusive lock on one byte of an open file handle."""
    try:
        if os.name == 'nt':
            import msvcrt
            msvcrt.locking(handle.fileno(), msvcrt.LK_NBLCK, 1)
        else:
            import fcntl
            fcntl.flock(handle.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        return True
    except OSError:
        return False


def release_exclusive_lock(handle) -> None:
    try:
        if os.name == 'nt':
            import msvcrt
            handle.seek(0)
            msvcrt.locking(handle.fileno(), msvcrt.LK_UNLCK, 1)
        else:
            import fcntl
            fcntl.flock(handle.fileno(), fcntl.LOCK_UN)
    except OSError:
        pass


class StateLock:
    """Exclusive OS lock. A lock held by a live run is never displaced or deleted.

    A leftover lock file whose byte range is unheld belongs to a run that already died;
    taking it over still requires the explicit --break-lock. Liveness is decided by the
    platform lock itself, never by os.kill(pid, 0), which is not a no-op on Windows.
    """

    def __init__(self, state_dir: Path, break_lock: bool):
        self.path = Path(state_dir) / 'lock.json'
        self.break_lock = break_lock
        self.handle = None
        self.previous = None
        self.took_over_stale = False

    def __enter__(self):
        self.path.parent.mkdir(parents=True, exist_ok=True)
        handle = open(self.path, 'a+', encoding='utf-8')
        handle.seek(0)
        if not try_exclusive_lock(handle):
            handle.close()
            raise RuntimeError(f'a live run holds {self.path}; refusing to displace it')
        try:
            handle.seek(0)
            content = handle.read()
        except OSError:
            content = ''
        self.previous = None
        if content.strip():
            try:
                parsed = json.loads(content)
            except json.JSONDecodeError:
                parsed = None
            if isinstance(parsed, dict) and parsed.get('pid') is not None:
                self.previous = parsed
        if self.previous and not self.break_lock:
            release_exclusive_lock(handle)
            handle.close()
            self.handle = None
            raise RuntimeError(
                f'a previous run (pid {self.previous.get("pid")}, '
                f'{self.previous.get("acquired_utc")}) left lock metadata in {self.path}; '
                'nothing holds the lock now, so pass --break-lock to take it over explicitly')
        self.took_over_stale = bool(self.previous)
        self.handle = handle
        self._write_metadata()
        return self

    def _write_metadata(self) -> None:
        payload = {'pid': os.getpid(), 'acquired_utc': utc_iso(),
                   'took_over_stale': self.took_over_stale, 'previous': self.previous}
        self.handle.seek(0)
        self.handle.truncate()
        self.handle.write(json.dumps(payload, indent=2))
        self.handle.flush()

    def __exit__(self, *exc):
        if self.handle is not None:
            try:
                self.handle.seek(0)
                self.handle.truncate()
                self.handle.flush()
            except OSError:
                pass
            release_exclusive_lock(self.handle)
            self.handle.close()
            self.handle = None
        return False


# --------------------------------------------------------------------------- state

def blank_state() -> dict:
    return {'schema_version': STATE_SCHEMA, 'world_id': None, 'sources': [], 'issues': {},
            'sessions': {}, 'lock_incidents': []}


def load_state(state_dir: Path) -> dict:
    state_dir = Path(state_dir)
    path = state_dir / STATE_FILE
    if not path.is_file():
        legacy = [name for name in LEGACY_STATE_FILES if (state_dir / name).is_file()]
        if legacy:
            raise ValueError(f'legacy two-file state layout detected ({legacy}); this runner keeps '
                             'one authoritative state.json and will not read it as empty')
        state = blank_state()
    else:
        state = load_json(path)
        if state.get('schema_version') != STATE_SCHEMA:
            raise ValueError(f'unsupported state schema {state.get("schema_version")}')
    for gm_id in GM_IDS:
        record = state['sessions'].setdefault(gm_id, {})
        record.setdefault('gm_id', gm_id)
        record.setdefault('focus', GM_FOCUS[gm_id])
        record.setdefault('resident_body', None)
        record.setdefault('session_id', None)
        record.setdefault('attempts', [])
        record.setdefault('outcomes', [])
        record.setdefault('unresolved', None)
        record.setdefault('last_status', 'never_dispatched')
    return state


def store_state(state_dir: Path, state: dict) -> None:
    """One atomic snapshot for sources, issues and sessions; they can never disagree."""
    save_json(Path(state_dir) / STATE_FILE, state)


def guard_snapshot(paths: list[Path]) -> dict:
    status = git(['status', '--porcelain'])
    head = git(['rev-parse', 'HEAD'])
    return {'files': {relative(path): (sha256_file(path) if Path(path).is_file() else None)
                      for path in paths},
            'git_head': head.stdout.strip() if head.returncode == 0 else None,
            'git_status_sha256': sha256_bytes(status.stdout.encode()),
            'taken_utc': utc_iso()}


def guard_diff(before: dict, after: dict) -> list[str]:
    changed = [f'file:{path}' for path, digest in before['files'].items()
               if after['files'].get(path) != digest]
    if before['git_head'] != after['git_head']:
        changed.append('git_head')
    if before['git_status_sha256'] != after['git_status_sha256']:
        changed.append('git_worktree')
    return changed


# --------------------------------------------------------------------------- evidence

def read_evidence(path: Path) -> tuple[bytes, dict | None, str]:
    """Read, hash and parse the same bytes once, so a replaced export can never mix."""
    payload = Path(path).read_bytes()
    digest = sha256_bytes(payload)
    try:
        document = json.loads(payload.decode('utf-8-sig'))
    except (json.JSONDecodeError, UnicodeDecodeError):
        document = None
    return payload, document, digest


def validate_evidence(document) -> list[str]:
    errors = []
    if not isinstance(document, dict):
        return ['evidence root is not a JSON object']
    if document.get('kind') != EVIDENCE_KIND:
        errors.append(f'kind must be {EVIDENCE_KIND!r}')
    if document.get('schema_version') != EVIDENCE_SCHEMA:
        errors.append(f'schema_version must be {EVIDENCE_SCHEMA}')
    world_id = document.get('world_id')
    if not isinstance(world_id, str) or not world_id.strip():
        errors.append('world_id must be a non-empty string')
    revision = document.get('source_revision')
    if not isinstance(revision, dict) or not revision:
        errors.append('source_revision must be a non-empty object')
    elif not all(isinstance(value, (int, float, str)) for value in revision.values()):
        errors.append('source_revision values must be scalars')
    boundaries = document.get('boundaries')
    if not isinstance(boundaries, dict):
        errors.append('boundaries object is required')
    else:
        for flag in REQUIRED_BOUNDARY_FLAGS:
            if boundaries.get(flag) is not False:
                errors.append(f'boundaries.{flag} must be explicitly false for GM consumption')
    evidence, proposals = document.get('evidence'), document.get('proposals')
    for name, value in (('evidence', evidence), ('proposals', proposals)):
        if not isinstance(value, list):
            errors.append(f'{name} must be a list')
    counts = document.get('counts')
    if isinstance(counts, dict) and isinstance(evidence, list) and isinstance(proposals, list):
        if counts.get('issues') != len(evidence) or counts.get('proposals') != len(proposals):
            errors.append('counts do not match evidence/proposals lengths')
    for index, entry in enumerate(proposals or []):
        if not isinstance(entry, dict):
            errors.append(f'proposals[{index}] is not an object')
            continue
        if not isinstance(entry.get('evidence_kind'), str):
            errors.append(f'proposals[{index}].evidence_kind must be a string')
        for edge in ('first', 'latest'):
            if not isinstance(entry.get(edge), dict):
                errors.append(f'proposals[{index}].{edge} provenance block is required')
    for index, entry in enumerate(evidence or []):
        if not isinstance(entry, dict):
            errors.append(f'evidence[{index}] is not an object')
            continue
        if not isinstance(entry.get('evidence_kind'), str):
            errors.append(f'evidence[{index}].evidence_kind must be a string')
    return errors


def source_vector(document: dict) -> tuple | None:
    """Comparable counters of the producer. Explicitly not a unique total revision.

    The accepted Godot producer can update latest.request_id/reason or close a physics
    issue while life_seq and proposal_sequence stay unchanged, so equal counters with a
    different body are a real update, while a strictly older counter pair is stale.
    """
    revision = document.get('source_revision')
    if not isinstance(revision, dict):
        return None
    life, proposal = revision.get('life_seq'), revision.get('proposal_sequence')
    if life is None or proposal is None:
        return None
    try:
        return (int(life), int(proposal))
    except (TypeError, ValueError):
        return None


def issue_identity(entry: dict, default_kind: str) -> tuple[str, str, str]:
    """Authoritative per-issue identity; authors are never collapsed away."""
    kind = str(entry.get('evidence_kind') or entry.get('kind') or default_kind)
    for field in IDENTITY_FIELDS:
        value = entry.get(field)
        if isinstance(value, str) and value.strip():
            return kind, value.strip(), field
    parts = []
    for field in ('capability_id', 'resident_id'):
        value = entry.get(field)
        if isinstance(value, str) and value.strip():
            parts.append(f'{field}={value.strip()}')
    if parts:
        return kind, ';'.join(parts), 'capability+resident'
    projection = canonical({'kind': kind, 'first': entry.get('first'), 'latest': entry.get('latest')})
    return kind, sha256_bytes(projection.encode())[:16], 'content'


def issue_id_for(world_id: str, kind: str, key: str) -> str:
    return 'issue-' + sha256_bytes(f'{world_id}|{kind}|{key}'.encode())[:12]


def issue_content_digest(entry: dict, status) -> str:
    return sha256_bytes(canonical({'entry': entry, 'status': status}).encode())[:32]


def import_source(state: dict, document: dict, path: Path, digest: str) -> dict:
    """Merge one validated snapshot into the state in memory; never writes.

    History is never erased and an issue that merely left the bounded projection is
    marked not_in_current_projection, never 'resolved'.
    """
    world_id = document['world_id']
    report = {'world_id': world_id, 'evidence_sha256': digest, 'created': [], 'updated': [],
              'duplicates': [], 'absent': [], 'stale': False, 'world_binding_conflict': False,
              'vector': None, 'previous_vector': state.get('source_vector')}
    if state.get('world_id') and state['world_id'] != world_id:
        report['world_binding_conflict'] = True
        return report
    vector = source_vector(document)
    report['vector'] = list(vector) if vector else None
    previous = state.get('source_vector')
    if vector is not None and previous and vector < tuple(previous):
        report['stale'] = True
        return report
    entries = [('world_evidence', entry) for entry in document['evidence']] + \
              [('capability_proposed', entry) for entry in document['proposals']]
    present, seen_content = [], set()
    for default_kind, entry in entries:
        evidence_kind, key, key_field = issue_identity(entry, default_kind)
        issue_id = issue_id_for(world_id, evidence_kind, key)
        present.append(issue_id)
        status = str(entry.get('status', 'open'))
        content = issue_content_digest(entry, status)
        record = state['issues'].get(issue_id)
        if record is None:
            record = {'issue_id': issue_id, 'world_id': world_id, 'evidence_kind': evidence_kind,
                      'identity_key': key, 'identity_field': key_field,
                      'capability_id': entry.get('capability_id'),
                      'resident_id': entry.get('resident_id'),
                      'proposal_id': entry.get('proposal_id'), 'schema_version': EVIDENCE_SCHEMA,
                      'first_import_utc': utc_iso(), 'import_count': 0, 'owner_gm': None,
                      'owner_since': None, 'owner_run_id': None, 'coding_session_id': None,
                      'coding_owner_gm': None, 'coding_attempt': None, 'coding_unresolved': None,
                      'candidates': [], 'outcomes': [], 'settled': {},
                      'absent_since': None, 'content_digest': None}
            state['issues'][issue_id] = record
            report['created'].append(issue_id)
        else:
            if record['content_digest'] == content:
                report['duplicates'].append(issue_id)
                seen_content.add(issue_id)
            else:
                report['updated'].append(issue_id)
        record['entry'] = entry
        record['source_status'] = status
        record['occurrences'] = entry.get('occurrences')
        record['first'] = entry.get('first')
        record['latest'] = entry.get('latest')
        record['claim'] = entry.get('claim')
        record['content_digest'] = content
        record['lifecycle'] = 'closed' if status in CLOSED_STATES else 'current'
        record['absent_since'] = None
        record['import_count'] += 1
    for issue_id, record in state['issues'].items():
        if (record['world_id'] != world_id or issue_id in present
                or record.get('source_channel') == 'gm_proposal'):
            continue
        if record['lifecycle'] == 'current':
            record['lifecycle'] = 'not_in_current_projection'
            record['absent_since'] = utc_iso()
            report['absent'].append(issue_id)
    state['world_id'] = world_id
    if vector is not None:
        state['source_vector'] = list(vector)
    state['source_sha256'] = digest
    state['sources'].append({'path': relative(path), 'sha256': digest, 'world_id': world_id,
                             'kind': document['kind'],
                             'source_revision': document['source_revision'],
                             'source_sequence': report['vector'], 'imported_utc': utc_iso(),
                             'created': report['created'], 'updated': report['updated'],
                             'duplicates': report['duplicates'], 'absent': report['absent']})
    return report


def issue_projection(record: dict) -> dict:
    return {'issue_id': record['issue_id'], 'evidence_kind': record['evidence_kind'],
            'capability_id': record.get('capability_id'), 'resident_id': record.get('resident_id'),
            'proposal_id': record.get('proposal_id'), 'source_status': record.get('source_status'),
            'lifecycle': record.get('lifecycle'), 'owner_gm': record.get('owner_gm'),
            'occurrences': record.get('occurrences'), 'claim': record.get('claim'),
            'first': record.get('first'), 'latest': record.get('latest'),
            'provenance': record.get('provenance'), 'summary': record.get('summary')}


def evidence_pointer(document: dict, pointer: str):
    """Resolve a JSON pointer only within the producer's public GM projection."""
    if not isinstance(pointer, str) or not pointer.startswith('/') or len(pointer) > 300:
        raise ValueError('evidence_refs must be bounded non-root JSON pointers')
    tokens = pointer[1:].split('/')
    if tokens[0] not in ('evidence', 'proposals', 'source_revision', 'counts',
                         'projection_note', 'world_id', 'kind'):
        raise ValueError(f'evidence pointer {pointer!r} is outside the public GM projection')
    value = document
    try:
        for token in tokens:
            if re.search(r'~(?![01])', token):
                raise ValueError('invalid JSON pointer escape')
            token = token.replace('~1', '/').replace('~0', '~')
            if isinstance(value, list):
                if not re.fullmatch(r'0|[1-9][0-9]*', token):
                    raise ValueError('array pointer index must be a nonnegative integer')
                value = value[int(token)]
            elif isinstance(value, dict):
                value = value[token]
            else:
                raise ValueError('evidence pointer traverses a scalar')
    except (KeyError, IndexError) as error:
        raise ValueError(f'evidence pointer {pointer!r} does not exist') from error
    return value


def read_investigation(path: Path | None, document: dict, digest: str) -> dict | None:
    if path is None:
        return None
    request = load_json(path)
    if not isinstance(request, dict):
        raise ValueError('investigation must be a JSON object')
    key = request.get('investigation_id')
    if not isinstance(key, str) or not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_.:-]{0,99}', key):
        raise ValueError('investigation_id must be a stable 1..100 character key')
    if request.get('world_id') != document['world_id'] or request.get('source_sha256') != digest:
        raise ValueError('investigation world_id/source_sha256 must match the reviewed evidence')
    objective, refs = request.get('objective'), request.get('evidence_refs')
    if not isinstance(objective, str) or not 12 <= len(objective.strip()) <= 800:
        raise ValueError('investigation objective must be a concrete 12..800 character sentence')
    if (not isinstance(refs, list) or not 1 <= len(refs) <= 8
            or any(not isinstance(ref, str) for ref in refs) or len(set(refs)) != len(refs)):
        raise ValueError('investigation evidence_refs must contain 1..8 distinct JSON pointers')
    investigation = {'investigation_id': key, 'world_id': document['world_id'],
                     'source_sha256': digest, 'origin': 'supervisor_specified',
                     'objective': objective.strip(), 'evidence_refs': refs,
                     'evidence': {ref: evidence_pointer(document, ref) for ref in refs}}
    investigation['content_digest'] = sha256_bytes(canonical(investigation).encode())
    return investigation


def validate_new_issues(answer, investigation: dict | None) -> tuple[list[dict], list[str]]:
    entries = answer.get('new_issues', []) if isinstance(answer, dict) else []
    if not isinstance(entries, list) or len(entries) > 1:
        return [], ['new_issues must be a list containing at most one bounded proposal']
    if not entries:
        return [], []
    if investigation is None:
        return [], ['new_issues requires an explicit evidence-sourced investigation']
    entry = entries[0]
    if not isinstance(entry, dict):
        return [], ['new_issues[0] must be an object']
    key, summary, refs = entry.get('proposal_key'), entry.get('summary'), entry.get('evidence_refs')
    if not isinstance(key, str) or not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_.:-]{0,99}', key):
        return [], ['new_issues[0].proposal_key must be a stable 1..100 character key']
    if not isinstance(summary, str) or not 12 <= len(summary.strip()) <= 400:
        return [], ['new_issues[0].summary must describe one hypothesis in 12..400 characters']
    if (not isinstance(refs, list) or not 1 <= len(refs) <= 8
            or any(not isinstance(ref, str) or ref not in investigation['evidence_refs']
                   for ref in refs) or len(set(refs)) != len(refs)):
        return [], ['new_issues[0].evidence_refs must copy selected investigation pointers']
    if not isinstance(entry.get('claim_coding'), bool):
        return [], ['new_issues[0].claim_coding must be boolean']
    return [{'proposal_key': key, 'summary': summary.strip(), 'evidence_refs': refs,
             'claim_coding': entry['claim_coding']}], []


def register_new_issues(state: dict, gm_id: str, entries: list[dict], investigation: dict,
                        run_id: str) -> list[dict]:
    """Register hypotheses, never a verified defect, coding approval or world mutation."""
    results = []
    for entry in entries:
        key = canonical([gm_id, investigation['investigation_id'], entry['proposal_key']])
        issue_id = issue_id_for(state['world_id'], 'gm_proposal', key)
        # Preserve proposals made before tuple encoding without reproducing the ambiguous
        # colon-delimited identity: all recorded components must match exactly.
        for existing in state['issues'].values():
            prior = existing.get('provenance') or {}
            if (existing.get('source_channel') == 'gm_proposal'
                    and prior.get('proposed_by_gm') == gm_id
                    and (prior.get('investigation') or {}).get('investigation_id') ==
                    investigation['investigation_id']
                    and (existing.get('entry') or {}).get('proposal_key') == entry['proposal_key']):
                issue_id = existing['issue_id']
                break
        provenance = {'origin': 'gm_proposed', 'proposed_by_gm': gm_id,
                      'status': 'hypothesis', 'verified_in_world': False,
                      'investigation': investigation, 'first_investigation': investigation,
                      'run_id': run_id,
                      'session_id': state['sessions'][gm_id]['session_id']}
        record = state['issues'].setdefault(issue_id, {
            'issue_id': issue_id, 'world_id': state['world_id'], 'evidence_kind': 'gm_proposal',
            'identity_key': key, 'identity_field': 'gm+investigation+proposal_key',
            'source_channel': 'gm_proposal', 'source_status': 'proposed', 'lifecycle': 'current',
            'summary': entry['summary'], 'provenance': provenance,
            'entry': entry, 'content_digest': issue_content_digest(entry, 'proposed'),
            'claim': {'implemented': False, 'verified_in_world': False},
            'first_import_utc': utc_iso(), 'owner_gm': None, 'owner_since': None,
            'owner_run_id': None, 'coding_session_id': None, 'coding_owner_gm': None,
            'coding_attempt': None, 'coding_unresolved': None, 'candidates': [],
            'outcomes': [], 'settled': {}, 'absent_since': None})
        record['provenance']['investigation'] = investigation
        record['provenance']['latest_run_id'] = run_id
        record['entry'] = entry
        record['summary'] = entry['summary']
        record['content_digest'] = issue_content_digest(
            {'proposal': entry, 'source_sha256': investigation['source_sha256']}, 'proposed')
        results.append({'issue_id': issue_id, 'disposition': 'proposal',
                        'claim_coding': entry['claim_coding'], 'summary': entry['summary'],
                        'evidence_refs': entry['evidence_refs']})
    return results


def issue_eligible(record: dict, gm_id: str) -> bool:
    if record.get('lifecycle') != 'current':
        return False
    if record.get('source_status') in CLOSED_STATES:
        return False
    settled = record['settled'].get(gm_id)
    return not settled or settled.get('content_digest') != record['content_digest']


def plan_observation(state: dict, selected: list[str], max_issues: int,
                     investigation: dict | None = None) -> list[dict]:
    plan = []
    for gm_id in selected:
        eligible = [issue for issue in state['issues'].values() if issue_eligible(issue, gm_id)]
        eligible.sort(key=lambda issue: issue['issue_id'])
        slice_records = eligible[:max_issues]
        investigate = investigation if investigation and investigation['content_digest'] not in \
            state['sessions'][gm_id].get('investigations', {}) else None
        plan.append({'gm_id': gm_id, 'session_id': state['sessions'][gm_id].get('session_id'),
                     'slice': [issue['issue_id'] for issue in slice_records],
                     'can_dispatch': bool(slice_records or investigate), '_records': slice_records,
                     'investigation': investigate,
                     'settled_issue_ids': sorted(issue_id for issue_id, issue in
                                                 state['issues'].items()
                                                 if issue['world_id'] == state['world_id']
                                                 and issue['settled'].get(gm_id)),
                     'blocked_by_owner': sorted(issue['issue_id'] for issue in eligible
                                                if issue.get('owner_gm')
                                                and issue['owner_gm'] != gm_id)})
    return plan


# --------------------------------------------------------------------------- prompts

def common_evidence_block(document: dict, path: Path, digest: str, report: dict, budget: int) -> str:
    provenance = {
        'note': ('bounded world-scoped evidence projection exported by the game; when the export is '
                 'a deterministic offline fixture it is fixture choice, not live resident demand; '
                 'an issue missing from this projection is not evidence that it was fixed'),
        'world_id': document['world_id'], 'kind': document['kind'],
        'schema_version': document['schema_version'], 'source_revision': document['source_revision'],
        'source_path': relative(path), 'source_sha256': digest,
        'producer_counters_are_not_a_total_revision': True,
        'import': {'created': len(report['created']), 'updated': len(report['updated']),
                   'duplicates': len(report['duplicates']), 'absent': len(report['absent'])},
        'counts': document.get('counts'), 'limits': document.get('limits'),
        'projection_note': document.get('projection_note'), 'boundaries': document['boundaries']}
    evidence = list(document['evidence'])
    proposals = list(document['proposals'])
    truncated = False
    while True:
        payload = {'provenance': provenance, 'evidence': evidence, 'proposals': proposals}
        text = json.dumps(payload, ensure_ascii=False, sort_keys=True, indent=2)
        block = '[COMMON_WORLD_EVIDENCE]\n' + text + '\n[END_COMMON_WORLD_EVIDENCE]\n'
        if len(block) <= budget:
            break
        if proposals:
            proposals.pop()
        elif evidence:
            evidence.pop()
        else:
            raise ValueError('common evidence block exceeds the prompt budget even when empty')
        truncated = True
    if truncated:
        block = block.replace('[COMMON_WORLD_EVIDENCE]',
                              '[COMMON_WORLD_EVIDENCE truncated_to_budget=true]')
    return block


def gm_state_block(state: dict, item: dict, previous: list[dict], run_id: str, digest: str) -> str:
    gm_id = item['gm_id']
    block = {'gm_id': gm_id, 'focus': GM_FOCUS[gm_id], 'resident_body': None,
             'world_id': state['world_id'],
             'session': {'mode': 'resume' if item['session_id'] else 'new',
                         'session_id': item['session_id']},
             'open_issues': [issue_projection(record) for record in item['_records']],
             'investigation': item.get('investigation'),
             'settled_issue_ids': item['settled_issue_ids'],
             'closed_or_absent_issue_ids': sorted(issue['issue_id'] for issue in
                                                  state['issues'].values()
                                                  if issue['lifecycle'] != 'current'),
             'your_recent_outcomes': previous, 'evidence_sha256': digest, 'run_id': run_id}
    return '[GM_STATE]\n' + json.dumps(block, ensure_ascii=False, sort_keys=True) + '\n[END_GM_STATE]\n'


def build_prompt(document, evidence_path, digest, report, state, item, run_id, budget) -> str:
    common = common_evidence_block(document, evidence_path, digest, report, max(2000, budget - 6000))
    record = state['sessions'][item['gm_id']]
    prompt = common + gm_state_block(state, item, record['outcomes'][-5:], run_id, digest)
    if len(prompt.encode('utf-8')) > budget:
        raise ValueError(f'prompt for {item["gm_id"]} exceeds --max-prompt-bytes {budget}')
    return prompt


# --------------------------------------------------------------------------- dispatch

def parse_events(text: str) -> dict:
    result = {'thread_id': None, 'usage': None, 'errors': [], 'turns_completed': 0,
              'lines': 0, 'unparsed': 0}
    for line in text.splitlines():
        line = line.strip()
        if not line:
            continue
        result['lines'] += 1
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            result['unparsed'] += 1
            continue
        if not isinstance(event, dict):
            continue
        kind = event.get('type')
        if kind == 'thread.started' and event.get('thread_id'):
            result['thread_id'] = event['thread_id']
        elif kind == 'turn.completed':
            result['turns_completed'] += 1
            if isinstance(event.get('usage'), dict):
                result['usage'] = event['usage']
        elif kind in ('error', 'turn.failed', 'stream_error'):
            result['errors'].append(str(event.get('message') or event.get('error') or kind))
    return result


def extract_json_object(text: str):
    """Return one unambiguous outer contract, never a nested example/status object."""
    decoder = json.JSONDecoder()
    contracts, dispositions = [], []
    attempts, cursor = 0, 0
    while cursor < len(text):
        index = text.find('{', cursor)
        if index < 0:
            break
        attempts += 1
        if attempts > 4000:
            break
        try:
            value, consumed = decoder.raw_decode(text[index:])
        except json.JSONDecodeError:
            cursor = index + 1
            continue
        # The decoder includes every nested object and quoted brace in this span.
        cursor = index + consumed
        if not isinstance(value, dict):
            continue
        if 'results' in value or 'status' in value:
            contracts.append(value)
        elif 'disposition' in value:
            dispositions.append(value)
    candidates = contracts or dispositions
    return candidates[0] if len(candidates) == 1 else None


def validate_gm_output(document, gm_id: str, slice_ids: list[str]) -> tuple[list[dict], list[str]]:
    errors = []
    if not isinstance(document, dict):
        return [], ['no JSON contract object found in the GM answer']
    if document.get('gm_id') not in (None, gm_id):
        errors.append(f"gm_id mismatch: answer claims {document.get('gm_id')!r}")
    results = document.get('results')
    if results is None:
        results = [document] if 'disposition' in document else None
    if not isinstance(results, list):
        return [], errors + ['results must be a list of outcome objects']
    accepted, seen = [], set()
    for index, item in enumerate(results):
        if not isinstance(item, dict):
            errors.append(f'results[{index}] is not an object')
            continue
        issue_id, disposition = item.get('issue_id'), item.get('disposition')
        if issue_id not in slice_ids:
            errors.append(f'results[{index}].issue_id {issue_id!r} is not one of this GM open issues')
            continue
        if issue_id in seen:
            errors.append(f'results[{index}].issue_id {issue_id} appears twice')
            continue
        if disposition not in DISPOSITIONS:
            errors.append(f'results[{index}].disposition {disposition!r} is not {DISPOSITIONS}')
            continue
        claim = item.get('claim_coding')
        if not isinstance(claim, bool):
            errors.append(f'results[{index}].claim_coding must be a boolean')
            continue
        if disposition == 'no_action' and claim:
            errors.append(f'results[{index}] claims coding while declaring no_action')
            continue
        seen.add(issue_id)
        accepted.append({'issue_id': issue_id, 'disposition': disposition, 'claim_coding': claim,
                         'summary': str(item.get('summary', ''))[:400],
                         'evidence_refs': [str(ref) for ref in (item.get('evidence_refs') or [])][:8]})
    return accepted, errors


def run_codex_once(route: Route, workdir: Path, run_dir: Path, tag: str, prompt: str,
                   instructions_path: Path, catalog_path: Path, resume_id: str | None,
                   timeout: int, on_process=None) -> dict:
    route.assert_no_credential(prompt, 'prompt')
    events_path = run_dir / f'{tag}.events.jsonl'
    stderr_path = run_dir / f'{tag}.stderr.log'
    result_path = run_dir / f'{tag}.result.md'
    (run_dir / f'{tag}.prompt.txt').write_text(prompt, encoding='utf-8')
    command = codex_command(route, workdir, result_path, instructions_path, catalog_path, resume_id,
                            sandbox='workspace-write' if tag == 'coding' else 'read-only')
    record = {'tag': tag, 'workdir': str(workdir), 'resume_requested': resume_id, 'command': command,
              'prompt_sha256': sha256_bytes(prompt.encode()), 'prompt_bytes': len(prompt.encode()),
              'started_utc': utc_iso(), 'pid': None, 'exit_code': None, 'timed_out': False,
              'status': 'starting', 'spawn_error': None, 'provider_request_started': False,
              'thread_returned': None, 'usage': None, 'usage_measured': False, 'events': None,
              'result_text': '', 'finished_utc': None}
    try:
        process = subprocess.Popen(command, cwd=str(workdir), env=route.environment(),
                                   stdin=subprocess.PIPE, stdout=events_path.open('wb'),
                                   stderr=stderr_path.open('wb'),
                                   creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
    except OSError as error:
        # A local startup failure: no provider request exists, so the record is complete but
        # carries no session, no usage and no result.
        record['status'] = 'transport_unavailable'
        record['spawn_error'] = str(error)
        record['finished_utc'] = utc_iso()
        return record
    record['pid'] = process.pid
    record['status'] = 'running'
    record['provider_request_started'] = True
    save_json(run_dir / f'{tag}.process.json',
              {'tag': tag, 'pid': process.pid, 'wrapper_pid': os.getpid(), 'workdir': str(workdir),
               'resume_requested': resume_id, 'started_utc': record['started_utc'],
               'prompt_sha256': record['prompt_sha256'], 'command': command})
    if on_process is not None:
        on_process(process.pid)
    try:
        process.communicate(prompt.encode('utf-8'), timeout=timeout)
    except subprocess.TimeoutExpired:
        record['timed_out'] = True
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=5)
    record['exit_code'] = process.returncode
    record['status'] = 'finished'
    record['finished_utc'] = utc_iso()
    parsed = parse_events(events_path.read_text(encoding='utf-8', errors='replace'))
    record['events'] = parsed
    record['thread_returned'] = parsed['thread_id']
    record['usage'] = parsed['usage']
    record['usage_measured'] = usage_is_measured(parsed['usage'])
    record['stderr_tail'] = stderr_path.read_text(encoding='utf-8', errors='replace')[-2000:]
    record['result_text'] = result_path.read_text(encoding='utf-8', errors='replace') \
        if result_path.is_file() else ''
    return record


def output_tail(value, limit: int = 2000) -> str:
    """TimeoutExpired may carry text or bytes; never let a tail break the run."""
    if value is None:
        return ''
    if isinstance(value, bytes):
        value = value.decode('utf-8', 'replace')
    return str(value)[-limit:]


def classify_attempt(record: dict, resume_requested: str | None) -> dict:
    """status, whether real usage was measured, and whether paid dispatch must stop.

    cost: 'none'     no provider request was made here (local preflight/transport)
          'measured' a complete numeric usage record exists; only this GM is affected
          'unknown'  provider usage cannot be ruled out; further paid dispatch stops
    """
    if record.get('spawn_error'):
        return {'status': 'transport_unavailable', 'cost': 'none', 'abort_run': True,
                'blocking': False}
    measured = usage_is_measured(record.get('usage'))
    if record.get('timed_out'):
        return {'status': 'timeout_unknown', 'cost': 'unknown', 'abort_run': True, 'blocking': True}
    if record.get('exit_code') != 0:
        return {'status': 'process_failed', 'cost': 'measured' if measured else 'unknown',
                'abort_run': not measured, 'blocking': True}
    returned, requested = record.get('thread_returned'), resume_requested
    if requested and returned and returned != requested:
        return {'status': 'session_mismatch', 'cost': 'measured' if measured else 'unknown',
                'abort_run': not measured, 'blocking': True}
    if not returned:
        return {'status': 'no_session_id', 'cost': 'measured' if measured else 'unknown',
                'abort_run': not measured, 'blocking': True}
    if not measured:
        return {'status': 'usage_incomplete', 'cost': 'unknown', 'abort_run': True, 'blocking': True}
    return {'status': 'ok', 'cost': 'measured', 'abort_run': False, 'blocking': False}


def unresolved_record(outcome: dict, status: str, cost: str, attempt: dict, note: str = '') -> dict:
    return {'kind': 'unknown_cost' if cost == 'unknown' else 'measured_failure',
            **usage_evidence(attempt),
            'status': status, 'cost': cost, 'run_id': outcome.get('run_id'),
            'pid': attempt.get('pid'), 'resume_requested': attempt.get('resume_requested'),
            'session_returned': attempt.get('thread_returned'),
            'usage': attempt.get('usage') if usage_is_measured(attempt.get('usage')) else None,
            'usage_measured': usage_is_measured(attempt.get('usage')),
            'prompt_sha256': attempt.get('prompt_sha256'),
            'validation_errors': outcome.get('validation_errors') or [],
            'note': note, 'utc': utc_iso(), 'reconciled': None}


def prior_ledger_reference(prior: Path) -> dict:
    reference = {'path': relative(prior), 'present': prior.is_file(),
                 'sha256': sha256_file(prior) if prior.is_file() else None,
                 'note': ('reference only; the already authorized historical stream exception stays '
                          'here, and this runner never resets, spends, retries or infers currency '
                          'from token counters')}
    if prior.is_file():
        try:
            ledger = load_json(prior)
        except (json.JSONDecodeError, UnicodeDecodeError) as error:
            reference['parse'] = f'unreadable, kept as an opaque reference: {error}'
            return reference
        calls = ledger.get('calls') if isinstance(ledger, dict) else None
        if isinstance(calls, list):
            reference['call_count'] = len(calls)
            reference['status_counts'] = {status: sum(1 for call in calls
                                                      if call.get('status') == status)
                                          for status in {call.get('status') for call in calls}}
    return reference


# --------------------------------------------------------------------------- recovery

def roll_in_flight_recovery(state: dict) -> list[str]:
    """A run that stopped mid-attempt leaves an in-flight record; it survives as unresolved."""
    converted = []
    for gm_id, record in state['sessions'].items():
        attempt = record.get('in_flight')
        if not attempt:
            continue
        record['in_flight'] = None
        for stored in reversed(record['attempts']):
            if stored.get('run_id') == attempt.get('run_id') and stored.get('status') in (
                    'in_flight', 'running'):
                stored['status'] = 'interrupted_in_flight'
                stored['finished_utc'] = utc_iso()
                break
        record['unresolved'] = {'kind': 'unknown_cost', 'status': 'interrupted_in_flight',
                                'cost': 'unknown', 'run_id': attempt.get('run_id'),
                                'pid': attempt.get('pid'), 'usage': None, 'usage_measured': False,
                                'prompt_sha256': attempt.get('prompt_sha256'),
                                'validation_errors': [], 'reconciled': None,
                                'note': ('the runner stopped while this paid attempt was in flight; '
                                         'provider usage is unknown and is not reset here'),
                                'utc': utc_iso()}
        record['last_status'] = 'interrupted_in_flight'
        converted.append(gm_id)
    for issue in state['issues'].values():
        attempt = issue.get('coding_attempt')
        if not attempt or attempt.get('status') not in ('in_flight', 'running'):
            continue
        # A real launch persists status="running" after Popen, so both states must be recovered
        # or an interrupted coder could stay unclassified while another GM is paid again.
        owner = attempt.get('gm_id') or issue.get('coding_owner_gm') or issue.get('owner_gm')
        interrupted = dict(attempt, status='interrupted_in_flight', finished_utc=utc_iso())
        issue['coding_attempt'] = interrupted
        issue['coding_unresolved'] = {
            'kind': 'unknown_cost', 'status': 'interrupted_in_flight', 'cost': 'unknown',
            'run_id': attempt.get('run_id'), 'pid': attempt.get('pid'),
            'issue_id': issue['issue_id'], 'owner_gm': owner,
            'session_requested': attempt.get('resume_requested'),
            'prompt_sha256': attempt.get('prompt_sha256'), 'usage': None, 'usage_measured': False,
            'reconciled': None,
            'note': ('the runner stopped while this paid coding attempt was running; provider '
                     'usage is unknown and is not reset here'), 'utc': utc_iso()}
        if owner in state['sessions']:
            owner_record = state['sessions'][owner]
            if (owner_record.get('unresolved') or {}).get('kind') != 'unknown_cost':
                owner_record['unresolved'] = dict(issue['coding_unresolved'],
                                                  source=f"coding:{issue['issue_id']}")
            owner_record['last_status'] = 'interrupted_in_flight'
            coding = owner_record.setdefault('coding', {'issue_id': issue['issue_id'],
                                                        'session_id': issue.get('coding_session_id'),
                                                        'attempts': []})
            coding.setdefault('attempts', []).append(
                {'run_id': attempt.get('run_id'), 'issue_id': issue['issue_id'],
                 'status': 'interrupted_in_flight', 'cost': 'unknown', 'usage_measured': False,
                 'pid': attempt.get('pid'), 'utc': utc_iso()})
            coding['attempts'] = coding['attempts'][-10:]
            coding['last_status'] = 'interrupted_in_flight'
            owner_record['outcomes'].append({'kind': 'coding', 'issue_id': issue['issue_id'],
                                             'run_id': attempt.get('run_id'),
                                             'status': 'interrupted_in_flight', 'cost': 'unknown',
                                             'utc': utc_iso()})
            owner_record['outcomes'] = owner_record['outcomes'][-20:]
        converted.append(f"coding:{issue['issue_id']}")
    return converted


def global_unknown_cost(state: dict) -> dict:
    """Every unresolved unknown-cost paid attempt, including coding attempts.

    A running coding attempt is attached to its owner GM, so the gate cannot be bypassed
    by asking a different GM to spend next.
    """
    gated = {}
    for gm_id, record in state['sessions'].items():
        unresolved = record.get('unresolved')
        if unresolved and unresolved.get('kind') == 'unknown_cost':
            gated[gm_id] = unresolved
    for issue in state['issues'].values():
        coding = issue.get('coding_unresolved')
        if not coding or coding.get('kind') != 'unknown_cost':
            continue
        owner = coding.get('owner_gm') or issue.get('coding_owner_gm') or issue.get('owner_gm')
        key = owner if owner in state['sessions'] else f'coding:{issue["issue_id"]}'
        if key not in gated:
            gated[key] = dict(coding, issue_id=issue['issue_id'], source='coding_attempt')
    return gated


def global_unknown_gms(state: dict) -> list[str]:
    return sorted(global_unknown_cost(state))


def apply_gm_outcomes(state: dict, gm_id: str, results: list[dict], digest: str,
                      run_id: str) -> list[dict]:
    notes = []
    for result in results:
        issue = state['issues'][result['issue_id']]
        entry = {'kind': 'observation', 'gm_id': gm_id, 'disposition': result['disposition'],
                 'claim_coding': result['claim_coding'], 'summary': result['summary'],
                 'evidence_refs': result['evidence_refs'], 'snapshot_sha256': digest,
                 'content_digest': issue['content_digest'], 'run_id': run_id, 'utc': utc_iso(),
                 'claim_verified_in_world': False}
        if result['claim_coding']:
            owner = issue.get('owner_gm')
            if owner and owner != gm_id:
                entry['claim_conflict'] = f'issue already owned by {owner}'
                notes.append({'issue_id': issue['issue_id'], 'kind': 'claim_conflict',
                              'owner': owner})
            elif issue.get('lifecycle') != 'current':
                entry['claim_conflict'] = 'issue is not in the current projection'
                notes.append({'issue_id': issue['issue_id'], 'kind': 'claim_conflict',
                              'owner': None})
            else:
                issue['owner_gm'] = gm_id
                issue['owner_since'] = utc_iso()
                issue['owner_run_id'] = run_id
                entry['claim_accepted'] = True
        issue['outcomes'].append(entry)
        issue['settled'][gm_id] = {'content_digest': issue['content_digest'],
                                   'disposition': result['disposition'], 'run_id': run_id,
                                   'utc': entry['utc']}
    return notes


def scan_for_credential(route: Route, directory: Path) -> list[str]:
    hits = []
    for path in sorted(Path(directory).rglob('*')):
        if not path.is_file():
            continue
        try:
            if route.key in path.read_text(encoding='utf-8', errors='replace'):
                hits.append(relative(path))
        except OSError:
            continue
    return hits


def observe(args) -> int:
    try:
        route = Route(args.config, args.key_file, args.codex, args.codex_home)
    except (ValueError, OSError) as error:
        return refusal('route_preflight', str(error), 2)
    evidence_path = Path(args.evidence).resolve()
    if not evidence_path.is_file():
        return refusal('evidence_missing', f'no evidence file at {evidence_path}', 2)
    state_dir = Path(args.state_dir).resolve()
    if not 1 <= args.max_gms <= 10:
        return refusal('usage', '--max-gms must be 1..10', 2)
    if not 1 <= args.max_issues_per_gm <= 16:
        return refusal('usage', '--max-issues-per-gm must be 1..16', 2)
    selected = list(args.gm) if args.gm else list(GM_IDS[:args.max_gms])
    unknown_gm = [gm for gm in selected if gm not in GM_IDS]
    if unknown_gm:
        return refusal('usage', f'unknown gm ids: {unknown_gm}', 2)
    if len(selected) > args.max_gms:
        return refusal('usage', f'{len(selected)} requested gms exceed --max-gms {args.max_gms}', 2)

    _, document, digest = read_evidence(evidence_path)
    if document is None:
        return refusal('malformed_source', 'evidence is not readable JSON', 4)
    errors = validate_evidence(document)
    if errors:
        return refusal('malformed_source', '; '.join(errors[:8]), 4, error_count=len(errors),
                       evidence_sha256=digest)
    try:
        investigation = read_investigation(args.investigation_file, document, digest)
    except (ValueError, OSError) as error:
        return refusal('investigation_invalid', str(error), 4)
    prior_reference = prior_ledger_reference(Path(args.prior_ledger))

    if args.dry_run:
        state = load_state(state_dir)
        report = import_source(state, document, evidence_path, digest)
        if report['world_binding_conflict']:
            return refusal('world_binding_conflict',
                           f'state directory is bound to {state.get("world_id")}', 4,
                           world_id=report['world_id'])
        if report['stale']:
            return refusal('stale_source',
                           'source counters are older than the imported snapshot', 3,
                           world_id=report['world_id'], sequence=report['vector'],
                           previous_vector=report['previous_vector'])
        plan = plan_observation(state, selected, args.max_issues_per_gm, investigation)
        run_id = 'run-' + utc_stamp() + '-' + os.urandom(3).hex()
        return emit({'status': 'dry_run', 'kind': 'gm_observe', 'run_id': run_id,
                     'route': route.reference(),
                     'world_binding': state.get('world_id'),
                     'evidence': {'path': relative(evidence_path), 'sha256': digest,
                                  'world_id': document['world_id'], 'kind': document['kind'],
                                  'source_revision': document['source_revision'],
                                  'source_sequence': report['vector']},
                     'import': {'created': report['created'], 'updated': report['updated'],
                                'duplicates': report['duplicates'], 'absent': report['absent'],
                                'issue_total': len(state['issues'])},
                     'plan': [{'gm_id': item['gm_id'], 'session_id': item['session_id'],
                               'session_mode': 'resume' if item['session_id'] else 'new',
                               'can_dispatch': item['can_dispatch'], 'slice': item['slice'],
                               'investigation': item['investigation'],
                               'settled_issue_ids': item['settled_issue_ids'],
                               'blocked_by_owner': item['blocked_by_owner']} for item in plan],
                     'prompt_bytes': {item['gm_id']: len(build_prompt(
                         document, evidence_path, digest, report, state, item, run_id,
                         args.max_prompt_bytes).encode()) for item in plan},
                     'unknown_cost_gms': global_unknown_gms(state), 'dispatched': 0,
                     'state_written': False, 'prior_ledger': prior_reference,
                     'currency_billing': 'not derived from token counters'}, 0)

    with StateLock(state_dir, args.break_lock):
        state = load_state(state_dir)
        report = import_source(state, document, evidence_path, digest)
        if report['world_binding_conflict']:
            return refusal('world_binding_conflict',
                           f'this state directory is bound to {state.get("world_id")}; one state '
                           'directory keeps one world', 4, world_id=report['world_id'])
        if report['stale']:
            return refusal('stale_source',
                           'source counters are older than the imported snapshot', 3,
                           world_id=report['world_id'], sequence=report['vector'],
                           previous_vector=report['previous_vector'])
        recovered = roll_in_flight_recovery(state)
        unknown = global_unknown_gms(state)
        if unknown:
            store_state(state_dir, state)
            return refusal('unresolved_unknown_cost',
                           'a previous attempt has unknown provider usage; recover and acknowledge '
                           'it before any new paid dispatch', 5,
                           gms=global_unknown_cost(state),
                           recovered=recovered)
        blocked = [gm for gm in selected if state['sessions'][gm].get('unresolved')]
        if blocked:
            store_state(state_dir, state)
            return refusal('unresolved_prior_attempt',
                           'acknowledge the recorded failed attempt before re-dispatching this GM',
                           5, gms={gm: state['sessions'][gm]['unresolved'] for gm in blocked})
        plan = plan_observation(state, selected, args.max_issues_per_gm, investigation)
        run_id = 'run-' + utc_stamp() + '-' + os.urandom(3).hex()
        run_dir = state_dir / 'runs' / run_id
        run_dir.mkdir(parents=True, exist_ok=False)
        instructions = run_dir / 'instructions.md'
        instructions.write_text(STABLE_INSTRUCTIONS, encoding='utf-8')
        catalog = run_dir / 'models.json'
        save_json(catalog, codex_catalog(STABLE_INSTRUCTIONS))
        protected = [evidence_path] + ([args.investigation_file.resolve()]
                                      if args.investigation_file else []) + \
                    [Path(path).resolve() for path in (args.protect or [])]
        guards_before = guard_snapshot(protected)
        results, exit_code, aborted = [], 0, None
        for item in plan:
            gm_id = item['gm_id']
            if aborted:
                results.append({'gm_id': gm_id, 'status': 'skipped_after_run_abort',
                                'dispatched': False, 'aborted_by': aborted})
                continue
            if not item['can_dispatch']:
                results.append({'gm_id': gm_id, 'status': 'skipped_no_open_issue',
                                'dispatched': False})
                continue
            record = state['sessions'][gm_id]
            resume_id = record.get('session_id') or None
            if resume_id:
                reason = route.preflight_resume(resume_id)
                if reason:
                    record['last_status'] = 'resume_preflight_failed'
                    record['resume_preflight_failed'] = {'reason': reason, 'run_id': run_id,
                                                         'utc': utc_iso()}
                    results.append({'gm_id': gm_id, 'status': 'resume_preflight_failed',
                                    'reason': reason, 'resume_requested': resume_id,
                                    'dispatched': False, 'cost': 'none'})
                    exit_code = max(exit_code, 1)
                    store_state(state_dir, state)
                    continue
            prompt = build_prompt(document, evidence_path, digest, report, state, item, run_id,
                                  args.max_prompt_bytes)
            intent = {'kind': 'gm_observe', 'run_id': run_id, 'gm_id': gm_id, 'status': 'in_flight',
                      'pid': None, 'started_utc': utc_iso(), 'finished_utc': None,
                      'prompt_sha256': sha256_bytes(prompt.encode()), 'resume_requested': resume_id}
            record['attempts'].append(intent)
            record['in_flight'] = intent
            record['last_status'] = 'in_flight'
            store_state(state_dir, state)

            def on_process(pid, intent=intent):
                intent['pid'] = pid
                intent['status'] = 'running'
                store_state(state_dir, state)

            attempt = run_codex_once(route, ROOT, run_dir, gm_id, prompt, instructions, catalog,
                                     resume_id, args.timeout, on_process=on_process)
            account_native_usage(state, attempt, resume_id)
            verdict = classify_attempt(attempt, resume_id)
            status, cost = verdict['status'], verdict['cost']
            record['in_flight'] = None
            intent.update({'pid': attempt.get('pid') or intent.get('pid'), 'status': status,
                           'cost': cost, 'finished_utc': utc_iso(),
                           'usage': attempt.get('usage') if usage_is_measured(attempt.get('usage'))
                           else None,
                           'usage_measured': usage_is_measured(attempt.get('usage')),
                           'session_returned': attempt.get('thread_returned'),
                           **usage_evidence(attempt)})
            outcome = {'gm_id': gm_id, 'status': status, 'cost': cost,
                       **usage_evidence(attempt),
                       'exit_code': attempt.get('exit_code'), 'pid': attempt.get('pid'),
                       'resume_requested': resume_id,
                       'session_returned': attempt.get('thread_returned'),
                       'usage': attempt.get('usage') if usage_is_measured(attempt.get('usage'))
                       else None,
                       'usage_measured': usage_is_measured(attempt.get('usage')),
                       'errors': attempt.get('events', {}).get('errors', [])[:5],
                       'prompt_sha256': attempt.get('prompt_sha256'),
                       'prompt_bytes': attempt.get('prompt_bytes'), 'dispatched': True,
                       'results': [], 'validation_errors': []}
            if status == 'ok' and not resume_id and attempt.get('thread_returned'):
                record['session_id'] = attempt['thread_returned']
                record['session_source'] = 'created'
            if status == 'ok':
                answer = extract_json_object(attempt['result_text'])
                accepted, validation_errors = validate_gm_output(answer, gm_id, item['slice'])
                proposals, proposal_errors = validate_new_issues(answer, item['investigation'])
                validation_errors.extend(proposal_errors)
                outcome['results'] = accepted
                outcome['validation_errors'] = validation_errors
                if validation_errors:
                    status = 'invalid_output'
                    outcome['status'] = status
                    outcome['cost'] = cost
                else:
                    created = register_new_issues(state, gm_id, proposals, item['investigation'],
                                                  run_id) if proposals else []
                    accepted.extend(created)
                    outcome['new_issue_ids'] = [entry['issue_id'] for entry in created]
                    outcome['claim_conflicts'] = apply_gm_outcomes(state, gm_id, accepted, digest,
                                                                   run_id)
                    if item['investigation']:
                        record.setdefault('investigations', {})[
                            item['investigation']['content_digest']] = {
                                'investigation_id': item['investigation']['investigation_id'],
                                'source_sha256': digest, 'run_id': run_id,
                                'new_issue_ids': outcome['new_issue_ids'], 'utc': utc_iso()}
                    record['outcomes'].append({'kind': 'observation', 'run_id': run_id,
                                               'snapshot_sha256': digest,
                                               'dispositions': [entry['disposition']
                                                                for entry in accepted],
                                               'issue_ids': [entry['issue_id']
                                                             for entry in accepted],
                                               'utc': utc_iso()})
                    record['outcomes'] = record['outcomes'][-20:]
            if status != 'ok':
                exit_code = max(exit_code, 1)
                if cost == 'none':
                    record['last_status'] = status
                else:
                    record['last_status'] = status
                    record['unresolved'] = unresolved_record(outcome, status, cost, attempt)
                if verdict['abort_run']:
                    aborted = f'{gm_id}:{status}'
            else:
                record['last_status'] = 'ok'
            save_json(run_dir / f'{gm_id}.attempt.json', attempt)
            store_state(state_dir, state)
            results.append(outcome)
        guards_after = guard_snapshot(protected)
        mutation = guard_diff(guards_before, guards_after)
        leaks = scan_for_credential(route, run_dir)
        if mutation or leaks:
            exit_code = max(exit_code, 1)
        store_state(state_dir, state)
        summary = {'status': 'ok' if exit_code == 0 else 'incomplete', 'kind': 'gm_observe',
                   'run_id': run_id, 'run_dir': relative(run_dir), 'route': route.reference(),
                   'world_binding': state.get('world_id'),
                   'evidence': {'path': relative(evidence_path), 'sha256': digest,
                                'world_id': document['world_id'],
                                'source_revision': document['source_revision']},
                   'import': {'created': report['created'], 'updated': report['updated'],
                              'duplicates': report['duplicates'], 'absent': report['absent']},
                   'issue_total': len(state['issues']),
                   'dispatched': sum(1 for result in results if result.get('dispatched')),
                   'aborted_by': aborted, 'results': results,
                   'guards': {'before': guards_before, 'after': guards_after, 'changed': mutation},
                   'credential_leak_in_run_dir': leaks,
                   'recovered_in_flight': recovered, 'prior_ledger': prior_reference,
                   'review_state': 'unapproved', 'deployed': False,
                   'currency_billing': 'not derived from token counters'}
        save_json(run_dir / 'run.json', summary)
        return emit(summary, exit_code)


# --------------------------------------------------------------------------- code

def validate_scope(scope, issue_id: str, base_revision: str) -> list[str]:
    errors = []
    if not isinstance(scope, dict):
        return ['scope file must hold a JSON object']
    if scope.get('issue_id') != issue_id:
        errors.append(f'scope.issue_id must be the dispatched issue {issue_id!r}')
    if scope.get('base_revision') != base_revision:
        errors.append(f'scope.base_revision must equal --base-revision {base_revision!r}')
    objective = scope.get('objective')
    if not isinstance(objective, str) or len(objective.strip()) < 12:
        errors.append('scope.objective must be a concrete sentence of at least 12 characters')
    files = scope.get('files')
    if not isinstance(files, list) or not files:
        errors.append('scope.files must be a non-empty list of candidate-relative paths')
    else:
        for entry in files:
            if not isinstance(entry, str) or not entry.strip():
                errors.append('scope.files entries must be non-empty strings')
                continue
            if Path(entry).is_absolute() or '..' in Path(entry).parts or ':' in entry:
                errors.append(f'scope.files entry {entry!r} is not a candidate-relative path')
    acceptance = scope.get('acceptance')
    if not isinstance(acceptance, list) or not acceptance:
        errors.append('scope.acceptance must be a non-empty list')
    commands = scope.get('test_commands', [])
    if not isinstance(commands, list) or any(
            not isinstance(command, list) or not command
            or any(not isinstance(token, str) for token in command) for command in commands):
        errors.append('scope.test_commands must be a list of non-empty argv lists')
    return errors


def validate_coding_output(answer, issue_id: str) -> list[str]:
    if not isinstance(answer, dict):
        return ['coding answer must be a JSON contract object']
    errors = []
    if answer.get('issue_id') != issue_id:
        errors.append('coding answer issue_id must match the claimed issue')
    if answer.get('status') not in ('implemented', 'blocked'):
        errors.append('coding answer status must be implemented or blocked')
    changed, commands = answer.get('changed_files'), answer.get('test_commands')
    if not isinstance(changed, list) or any(not isinstance(path, str) for path in changed):
        errors.append('coding answer changed_files must be a list of paths')
    if (not isinstance(commands, list) or any(not isinstance(command, list) or not command
            or any(not isinstance(token, str) for token in command) for command in commands)):
        errors.append('coding answer test_commands must be a list of argv lists')
    if not isinstance(answer.get('test_results'), str):
        errors.append('coding answer test_results must be a string')
    return errors


def candidate_path_key(value) -> str:
    """Stable candidate identity across relative paths, separators and Windows case."""
    path = Path(value)
    if not path.is_absolute():
        path = ROOT / path
    return os.path.normcase(str(path.resolve()))


def code_preconditions(state: dict, issue_id: str, scope,
                       candidate: Path | None = None) -> tuple[str, str, int] | None:
    """Coding belongs to one registered GM: current claim, no bypass via stale scope."""
    issue = state['issues'].get(issue_id)
    if issue is None:
        return ('unknown_issue', f'{issue_id} is not registered in this state directory', 2)
    if state.get('world_id') != issue['world_id']:
        return ('world_binding_conflict', 'issue does not belong to this state directory world', 4)
    if issue.get('source_status') in CLOSED_STATES:
        return ('issue_closed', 'the producer reports this issue closed', 6)
    if issue.get('lifecycle') != 'current':
        return ('issue_not_in_current_projection',
                'the issue is not in the current projection; review before coding', 6)
    owner = issue.get('owner_gm')
    if owner not in GM_IDS:
        return ('issue_not_claimed_by_registered_gm',
                'coding requires a current coding claim by one of the ten registered GMs', 6)
    if issue.get('coding_owner_gm') and issue['coding_owner_gm'] != owner:
        return ('coding_owner_reassigned',
                f'coding history belongs to {issue["coding_owner_gm"]} but the issue is now owned '
                f'by {owner}; explicit review required', 6)
    if isinstance(scope.get('owner_gm'), str) and scope['owner_gm'] != owner:
        return ('scope_owner_mismatch',
                f'scope.owner_gm {scope["owner_gm"]!r} is not the current owner {owner!r}', 6)
    if candidate is not None:
        requested_candidate = candidate_path_key(candidate)
        for recorded_issue_id, recorded_issue in state['issues'].items():
            if recorded_issue_id == issue_id:
                continue
            for record in recorded_issue.get('candidates', []):
                recorded_candidate = record.get('candidate')
                if isinstance(recorded_candidate, str) \
                        and candidate_path_key(recorded_candidate) == requested_candidate:
                    return ('candidate_issue_mismatch',
                            f'candidate is already bound to issue {recorded_issue_id}', 6)
    unknown = global_unknown_gms(state)
    if unknown:
        return ('unresolved_unknown_cost',
                f'unknown provider usage is unresolved for {unknown}', 5)
    coding = issue.get('coding_attempt') or {}
    if coding.get('status') in ('in_flight', 'running'):
        return ('coding_attempt_in_flight', 'one active coding attempt already exists', 5)
    # An acknowledged interrupted attempt stays as history (PID/run/session kept) without
    # blocking the repair continuation; only an unresolved record blocks.
    if issue.get('coding_unresolved'):
        return ('unresolved_coding_attempt',
                'recover and acknowledge the previous coding attempt first', 5)
    owner_record = state['sessions'][owner]
    if owner_record.get('unresolved'):
        return ('owner_gm_unresolved',
                f'{owner} still has an unresolved attempt record', 5)
    return None


def normalize_status_paths(text: str) -> list[str]:
    paths = []
    if '\0' in text:
        entries, index = text.split('\0'), 0
        while index < len(entries):
            record = entries[index]
            index += 1
            if not record:
                continue
            paths.append(record[3:].replace('\\', '/'))
            if 'R' in record[:2] or 'C' in record[:2]:
                # Porcelain -z puts destination first, then the original path as its
                # own NUL field. Both endpoints are consequential scope changes.
                if index < len(entries) and entries[index]:
                    paths.append(entries[index].replace('\\', '/'))
                    index += 1
        return sorted(set(paths))
    for line in text.splitlines():
        if not line.strip():
            continue
        entry = line[3:] if len(line) > 3 else line.strip()
        endpoints = entry.split(' -> ') if ('R' in line[:2] or 'C' in line[:2]) else [entry]
        paths.extend(path.strip().strip('"').replace('\\', '/') for path in endpoints)
    return sorted(set(paths))


def code(args) -> int:
    state_dir = Path(args.state_dir).resolve()
    scope_path = Path(args.scope_file).resolve()
    if not scope_path.is_file():
        return refusal('scope_missing', f'no scope file at {scope_path}', 2)
    head = git(['rev-parse', f'{args.base_revision}^{{commit}}'])
    if head.returncode != 0:
        return refusal('unknown_base_revision', head.stderr.strip(), 6)
    base_sha = head.stdout.strip()
    try:
        scope = load_json(scope_path)
    except (json.JSONDecodeError, UnicodeDecodeError) as error:
        return refusal('scope_malformed', str(error), 4)
    errors = validate_scope(scope, args.issue, args.base_revision)
    if errors:
        return refusal('scope_base_mismatch', '; '.join(errors[:8]), 6, issue_id=args.issue,
                       requested_base=args.base_revision)
    candidate = Path(args.candidate).resolve() if args.candidate \
        else (state_dir / 'candidates' / args.issue).resolve()
    if candidate == state_dir or state_dir not in candidate.parents or candidate == ROOT.resolve():
        return refusal('candidate_outside_state_dir', str(candidate), 6)
    try:
        route = Route(args.config, args.key_file, args.codex, args.codex_home)
    except (ValueError, OSError) as error:
        return refusal('route_preflight', str(error), 2)
    allowed_files = sorted(entry.replace('\\', '/') for entry in scope['files'])

    if args.dry_run:
        state = load_state(state_dir)
        blocked = code_preconditions(state, args.issue, scope, candidate)
        if blocked:
            return refusal(blocked[0], blocked[1], blocked[2], issue_id=args.issue)
        issue = state['issues'][args.issue]
        return emit({'status': 'dry_run', 'kind': 'gm_code', 'issue_id': args.issue,
                     'owner_gm': issue['owner_gm'],
                     'coding_session': {'mode': 'resume' if issue.get('coding_session_id') else 'new',
                                        'session_id': issue.get('coding_session_id')},
                     'candidate': relative(candidate), 'base_revision': args.base_revision,
                     'base_sha': base_sha, 'allowed_scope_files': allowed_files,
                     'scope_path': relative(scope_path), 'route': route.reference(),
                     'dispatched': 0, 'state_written': False, 'review_state': 'unapproved',
                     'deployed': False}, 0)

    with StateLock(state_dir, args.break_lock):
        state = load_state(state_dir)
        recovered = roll_in_flight_recovery(state)
        blocked = code_preconditions(state, args.issue, scope, candidate)
        if blocked:
            if recovered:
                store_state(state_dir, state)
            return refusal(blocked[0], blocked[1], blocked[2], issue_id=args.issue,
                           recovered=recovered)
        issue = state['issues'][args.issue]
        owner = issue['owner_gm']
        owner_record = state['sessions'][owner]
        resume_id = issue.get('coding_session_id')
        if resume_id:
            reason = route.preflight_resume(resume_id)
            if reason:
                return refusal('resume_preflight_failed', reason, 2, resume_requested=resume_id)
        candidate.parent.mkdir(parents=True, exist_ok=True)
        if candidate.exists():
            top = git(['rev-parse', '--show-toplevel'], cwd=candidate)
            if top.returncode != 0 or Path(top.stdout.strip()).resolve() != candidate:
                return refusal('candidate_not_isolated_worktree',
                               'existing candidate must be its own isolated git worktree', 6)
            existing = git(['rev-parse', 'HEAD'], cwd=candidate)
            if existing.returncode != 0 or existing.stdout.strip() != base_sha:
                return refusal('candidate_base_mismatch',
                               f'existing candidate at {relative(candidate)} is not at {base_sha}', 6)
        else:
            added = git(['worktree', 'add', '--detach', str(candidate), base_sha])
            if added.returncode != 0:
                return refusal('candidate_creation_failed', added.stderr.strip()[-500:], 6)
            checked = git(['rev-parse', 'HEAD'], cwd=candidate)
            if checked.returncode != 0 or checked.stdout.strip() != base_sha:
                return refusal('candidate_base_mismatch',
                               f'candidate HEAD {checked.stdout.strip()!r} != {base_sha}', 6)
        missing = [entry for entry in scope['files'] if not (candidate / Path(entry).parent).is_dir()]
        if missing:
            return refusal('scope_path_mismatch',
                           f'parent directories missing in the candidate: {missing}', 6)

        run_id = 'code-' + utc_stamp() + '-' + os.urandom(3).hex()
        run_dir = state_dir / 'runs' / run_id
        run_dir.mkdir(parents=True, exist_ok=False)
        instructions = run_dir / 'instructions.md'
        instructions.write_text(STABLE_CODE_INSTRUCTIONS, encoding='utf-8')
        catalog = run_dir / 'models.json'
        save_json(catalog, codex_catalog(STABLE_CODE_INSTRUCTIONS))
        protected = [Path(path).resolve() for path in (args.protect or [])]
        guards_before = guard_snapshot(protected)
        coding_state = {'gm_id': owner, 'role': 'coding_worker',
                        'focus': GM_FOCUS[owner], 'resident_body': None,
                        'world_id': state.get('world_id'),
                        'session': {'mode': 'resume' if resume_id else 'new', 'session_id': resume_id},
                        'open_issues': [issue_projection(issue)],
                        'your_recent_outcomes': owner_record['outcomes'][-5:],
                        'run_id': run_id, 'candidate': relative(candidate), 'base_sha': base_sha,
                        'allowed_scope_files': allowed_files, 'scope': scope,
                        'rules': ('touch only the allowed scope files; work only inside the '
                                  'candidate; no commit, push, save, secret or network access')}
        prompt = ('[CODING_SCOPE]\n'
                  + json.dumps(coding_state, ensure_ascii=False, sort_keys=True, indent=2)
                  + '\n[END_CODING_SCOPE]\n')
        route.assert_no_credential(prompt, 'coding prompt')
        intent = {'kind': 'gm_code', 'run_id': run_id, 'gm_id': owner, 'issue_id': args.issue,
                  'status': 'in_flight', 'pid': None, 'started_utc': utc_iso(),
                  'prompt_sha256': sha256_bytes(prompt.encode()), 'resume_requested': resume_id}
        issue['coding_attempt'] = intent
        owner_record.setdefault('coding', {'issue_id': args.issue, 'session_id': resume_id,
                                           'attempts': []})
        owner_record['coding'].update({'issue_id': args.issue, 'last_status': 'in_flight',
                                       'run_id': run_id})
        store_state(state_dir, state)

        def on_process(pid, intent=intent):
            intent['pid'] = pid
            intent['status'] = 'running'
            owner_record['coding']['last_status'] = 'running'
            store_state(state_dir, state)

        attempt = run_codex_once(route, candidate, run_dir, 'coding', prompt, instructions, catalog,
                                 resume_id, args.timeout, on_process=on_process)
        account_native_usage(state, attempt, resume_id)
        verdict = classify_attempt(attempt, resume_id)
        status, cost = verdict['status'], verdict['cost']
        measured = usage_is_measured(attempt.get('usage'))
        returned = attempt.get('thread_returned')
        issue['coding_attempt'] = None
        intent.update({'pid': attempt.get('pid') or intent.get('pid'), 'status': status,
                       'cost': cost, 'finished_utc': utc_iso(),
                       'usage': attempt.get('usage') if measured else None,
                       'usage_measured': measured, 'session_returned': returned,
                       **usage_evidence(attempt)})
        # Persist the measured provider result and the real returned session BEFORE any local
        # scope test runs: a later test failure or timeout must not lose the resume binding or
        # leave an apparently in-flight paid call.
        bound = bool(returned) and bool(SESSION_UUID.fullmatch(returned)) \
            and status != 'session_mismatch'
        if bound:
            issue['coding_session_id'] = returned
            issue['coding_session_source'] = 'resumed' if resume_id else 'created'
        issue['coding_owner_gm'] = owner
        issue['coding_provider_result'] = {
            **usage_evidence(attempt),
            'run_id': run_id, 'status': status, 'cost': cost,
            'provider_request_started': attempt.get('provider_request_started', False),
            'exit_code': attempt.get('exit_code'), 'pid': attempt.get('pid'),
            'usage': attempt.get('usage') if measured else None, 'usage_measured': measured,
            'session_requested': resume_id, 'session_returned': returned, 'session_bound': bound,
            'result_text_sha256': sha256_bytes(attempt.get('result_text', '').encode()),
            'spawn_error': attempt.get('spawn_error'), 'utc': utc_iso()}
        owner_record['coding'] = {**(owner_record.get('coding') or {}), 'issue_id': args.issue,
                                  'last_status': status,
                                  'session_id': issue.get('coding_session_id'), 'run_id': run_id}
        owner_record['coding'].setdefault('attempts', [])
        store_state(state_dir, state)
        save_json(run_dir / 'coding-attempt.json', attempt)
        answer = extract_json_object(attempt.get('result_text', ''))
        validation_errors = validate_coding_output(answer, args.issue)
        if status == 'ok' and validation_errors:
            status = 'invalid_output'
        elif status == 'ok' and answer['status'] == 'blocked':
            status = 'worker_blocked'
        scope_tests = []
        if status == 'ok' and args.run_scope_tests and scope['test_commands']:
            scope_timeout = min(args.timeout, 900)
            issue['coding_scope_state'] = {'run_id': run_id, 'status': 'running',
                                           'usage_measured': measured, 'utc': utc_iso()}
            store_state(state_dir, state)
            environment = route.test_environment()
            for command in scope['test_commands']:
                try:
                    executed = subprocess.run(command, cwd=str(candidate), capture_output=True,
                                              text=True, encoding='utf-8', errors='replace',
                                              env=environment, timeout=scope_timeout)
                    scope_tests.append({'command': command, 'exit_code': executed.returncode,
                                        'timed_out': False,
                                        'stdout_tail': output_tail(executed.stdout),
                                        'stderr_tail': output_tail(executed.stderr)})
                except subprocess.TimeoutExpired as error:
                    scope_tests.append({'command': command, 'exit_code': None, 'timed_out': True,
                                        'timeout_seconds': scope_timeout,
                                        'stdout_tail': output_tail(error.stdout),
                                        'stderr_tail': output_tail(error.stderr)})
                except OSError as error:
                    scope_tests.append({'command': command, 'exit_code': None, 'timed_out': False,
                                        'spawn_error': str(error), 'stdout_tail': '',
                                        'stderr_tail': ''})
            if any(test['exit_code'] != 0 for test in scope_tests):
                status = 'scope_tests_failed'
            issue['coding_scope_state'] = {'run_id': run_id, 'status': status,
                                           'usage_measured': measured, 'utc': utc_iso()}
            store_state(state_dir, state)
        head_after = git(['rev-parse', 'HEAD'], cwd=candidate)
        candidate_head = head_after.stdout.strip() if head_after.returncode == 0 else None
        if status == 'ok' and candidate_head != base_sha:
            status = 'worker_committed'
        changed = git(['status', '--porcelain', '-z', '--untracked-files=all'], cwd=candidate)
        observed_changed = normalize_status_paths(changed.stdout) if changed.returncode == 0 else None
        if status == 'ok' and observed_changed is None:
            status = 'candidate_status_failed'
        out_of_scope = [] if observed_changed is None else [path for path in observed_changed
                                                            if path not in allowed_files]
        if status == 'ok' and out_of_scope:
            status = 'out_of_scope_change'
        guards_after = guard_snapshot(protected)
        mutation = guard_diff(guards_before, guards_after)
        if mutation and status == 'ok':
            status = 'protected_path_mutated'
        leaks = scan_for_credential(route, run_dir)
        if leaks and status == 'ok':
            status = 'credential_exposure'
        if status == 'ok':
            issue['coding_unresolved'] = None
        elif cost == 'none':
            # Local startup failure: nothing was requested from the provider, so there is no paid
            # usage to reconcile and no fictitious in-flight request to leave behind.
            issue['coding_scope_state'] = {'run_id': run_id, 'status': status,
                                           'usage_measured': False, 'utc': utc_iso()}
        else:
            issue['coding_unresolved'] = {
                'kind': 'unknown_cost' if cost == 'unknown' else 'measured_failure',
                'status': status, 'cost': cost, 'run_id': run_id, 'pid': attempt.get('pid'),
                'issue_id': args.issue, 'owner_gm': owner,
                'session_id': issue.get('coding_session_id'),
                'usage': attempt.get('usage') if measured else None, 'usage_measured': measured,
                'repairable': status in REPAIRABLE_STATUSES, 'scope_tests': scope_tests,
                'reconciled': None, 'utc': utc_iso()}
            owner_record['unresolved'] = unresolved_record(
                {'run_id': run_id, 'validation_errors': [status]}, status, cost, attempt,
                note=f'coding attempt for {args.issue} ended as {status}')
            owner_record['unresolved'].update({'issue_id': args.issue,
                                               'session_id': issue.get('coding_session_id'),
                                               'repairable': status in REPAIRABLE_STATUSES})
            owner_record['last_status'] = status
        owner_record['coding'].update({'issue_id': args.issue, 'last_status': status,
                                       'session_id': issue.get('coding_session_id'),
                                       'run_id': run_id})
        owner_record['coding'].setdefault('attempts', []).append(
            {'run_id': run_id, 'issue_id': args.issue, 'status': status, 'cost': cost,
             **usage_evidence(attempt),
             'usage_measured': measured, 'usage': attempt.get('usage') if measured else None,
             'provider_request_started': attempt.get('provider_request_started', False),
             'session_returned': returned, 'session_bound': bound,
             'scope_test_failures': [test['exit_code'] for test in scope_tests
                                     if test['exit_code'] != 0],
             'changed_files': observed_changed, 'out_of_scope': out_of_scope, 'utc': utc_iso()})
        owner_record['coding']['attempts'] = owner_record['coding']['attempts'][-10:]
        owner_record['outcomes'].append({'kind': 'coding', 'issue_id': args.issue, 'run_id': run_id,
                                         'status': status, 'cost': cost,
                                         'changed_files': observed_changed, 'utc': utc_iso()})
        owner_record['outcomes'] = owner_record['outcomes'][-20:]
        issue['candidates'].append({'candidate': relative(candidate), 'base_sha': base_sha,
                                    'run_id': run_id, 'status': status, 'owner_gm': owner,
                                    'changed_files': observed_changed,
                                    'out_of_scope': out_of_scope, 'utc': utc_iso(),
                                    'review_state': 'unapproved'})
        issue['outcomes'].append({'kind': 'coding', 'gm_id': owner, 'run_id': run_id,
                                  'status': status, 'cost': cost,
                                  'changed_files': observed_changed, 'utc': utc_iso()})
        store_state(state_dir, state)
        save_json(run_dir / 'coding-attempt.json', attempt)
        summary = {'status': status, 'kind': 'gm_code', 'run_id': run_id,
                   **usage_evidence(attempt),
                   'cost': cost,
                   'run_dir': relative(run_dir), 'issue_id': args.issue, 'owner_gm': owner,
                   'candidate': relative(candidate), 'base_revision': args.base_revision,
                   'base_sha': base_sha, 'candidate_head': candidate_head,
                   'route': route.reference(), 'session_requested': resume_id,
                   'session_returned': attempt.get('thread_returned'),
                   'session_bound': bound,
                   'provider_request_started': attempt.get('provider_request_started', False),
                   'coding_unresolved': issue.get('coding_unresolved'),
                   'coding_scope_state': issue.get('coding_scope_state'),
                   'usage': attempt.get('usage') if usage_is_measured(attempt.get('usage')) else None,
                   'usage_measured': usage_is_measured(attempt.get('usage')),
                   'exit_code': attempt.get('exit_code'), 'pid': attempt.get('pid'),
                   'worker_answer': answer,
                   'validation_errors': validation_errors,
                   'worker_claims': {'changed_files': (answer or {}).get('changed_files'),
                                     'test_results': (answer or {}).get('test_results')},
                   'observed_changed_files': observed_changed,
                   'allowed_scope_files': allowed_files, 'out_of_scope_changes': out_of_scope,
                   'scope_tests': scope_tests, 'guards': {'changed': mutation},
                   'credential_leak_in_run_dir': leaks, 'recovered_in_flight': recovered,
                   'review_state': 'unapproved', 'deployed': False,
                   'note': ('candidate changes, base hash and test evidence are unapproved until '
                            'supervisor review; a worker commit or an out-of-scope change is a '
                            'failure, not a delivery')}
        save_json(run_dir / 'run.json', summary)
        return emit(summary, 0 if status == 'ok' else 1)


# --------------------------------------------------------------------------- small commands

def status(args) -> int:
    state_dir = Path(args.state_dir).resolve()
    state = load_state(state_dir)
    return emit({'status': 'ok', 'state_dir': str(state_dir), 'world_id': state.get('world_id'),
                 'source_vector': state.get('source_vector'),
                 'unknown_cost_gms': global_unknown_gms(state),
                 'issue_count': len(state['issues']),
                 'issues': [{'issue_id': issue['issue_id'], 'evidence_kind': issue['evidence_kind'],
                             'lifecycle': issue.get('lifecycle'),
                             'source_status': issue.get('source_status'),
                             'owner_gm': issue.get('owner_gm'),
                             'content_digest': issue.get('content_digest'),
                             'coding_session_id': issue.get('coding_session_id'),
                             'coding_provider_result': (issue.get('coding_provider_result') or {}
                                                        ).get('status'),
                             'coding_scope_state': (issue.get('coding_scope_state') or {}
                                                    ).get('status'),
                             'coding_unresolved': bool(issue.get('coding_unresolved')),
                             'settled_by': sorted(issue['settled']),
                             'outcomes': len(issue['outcomes'])}
                            for issue in sorted(state['issues'].values(),
                                                key=lambda item: item['issue_id'])],
                 'sessions': [{'gm_id': gm_id, 'session_id': record.get('session_id'),
                               'last_status': record.get('last_status'),
                               'attempts': len(record['attempts']),
                               'unresolved': record.get('unresolved'),
                               'coding': {key: value for key, value in
                                          (record.get('coding') or {}).items() if key != 'attempts'},
                               'outcome_count': len(record['outcomes'])}
                              for gm_id, record in sorted(state['sessions'].items())]}, 0)


def recover(args) -> int:
    state_dir = Path(args.state_dir).resolve()
    if not args.note.strip():
        return refusal('usage', '--note must record what the operator inspected', 2)
    with StateLock(state_dir, args.break_lock):
        state = load_state(state_dir)
        recovered = roll_in_flight_recovery(state)
        if args.gm not in state['sessions']:
            return refusal('unknown_gm', args.gm, 2)
        record = state['sessions'][args.gm]
        unresolved = record.get('unresolved')
        if not unresolved:
            return refusal('nothing_to_recover',
                           f'{args.gm} has no unresolved attempt record', 2,
                           recovered=recovered)
        if unresolved.get('cost') != 'unknown':
            return refusal('recovery_not_required',
                           'this attempt has measured usage; acknowledge it directly', 2)
        reconciliation = {'note': args.note.strip(), 'observed_usage': args.usage,
                          'operator': 'explicit recovery', 'utc': utc_iso(),
                          'attempt': {'run_id': unresolved.get('run_id'),
                                      'pid': unresolved.get('pid'),
                                      'status': unresolved.get('status'),
                                      'usage': unresolved.get('usage'),
                                      'usage_measured': unresolved.get('usage_measured')}}
        unresolved['reconciled'] = reconciliation
        record.setdefault('recovery_log', []).append(reconciliation)
        reconciled_issues = []
        for issue in state['issues'].values():
            coding = issue.get('coding_unresolved')
            if coding and (coding.get('owner_gm') or issue.get('owner_gm')) == args.gm:
                coding['reconciled'] = reconciliation
                reconciled_issues.append(issue['issue_id'])
        store_state(state_dir, state)
        return emit({'status': 'ok', 'gm_id': args.gm, 'recovered': recovered,
                     'still_blocking': True, 'reconciliation': reconciliation,
                     'reconciled_issues': reconciled_issues,
                     'next': 'acknowledge to clear the dispatch block; the uncertain record stays'}, 0)


def acknowledge(args) -> int:
    state_dir = Path(args.state_dir).resolve()
    if not args.note.strip():
        return refusal('usage', '--note must record why the attempt is acknowledged', 2)
    with StateLock(state_dir, args.break_lock):
        state = load_state(state_dir)
        recovered = roll_in_flight_recovery(state)
        if args.gm not in state['sessions']:
            return refusal('unknown_gm', args.gm, 2)
        record = state['sessions'][args.gm]
        unresolved = record.get('unresolved')
        if not unresolved:
            return refusal('nothing_to_acknowledge',
                           f'{args.gm} has no unresolved attempt record', 2, recovered=recovered)
        if unresolved.get('cost') == 'unknown' and not unresolved.get('reconciled'):
            store_state(state_dir, state)
            return refusal('recovery_required',
                           'an interrupted or unmeasured paid attempt must be explicitly recovered '
                           'before it can be acknowledged', 5, gms={args.gm: unresolved})
        record.setdefault('acknowledged', []).append(
            {'unresolved': unresolved, 'note': args.note.strip(), 'utc': utc_iso(),
             'usage_kept_unknown': unresolved.get('usage') is None})
        record['acknowledged'][-1]['unresolved'] = unresolved
        record['unresolved'] = None
        record['last_status'] = 'acknowledged'
        # The owner's coding block is released too, but only into its own history: the repair
        # continuation keeps the same saved session and the old candidate evidence.
        released_issues = []
        for issue in state['issues'].values():
            coding = issue.get('coding_unresolved')
            if not coding:
                continue
            if (coding.get('owner_gm') or issue.get('owner_gm')) != args.gm:
                continue
            issue.setdefault('coding_acknowledged', []).append(
                {'unresolved': coding, 'note': args.note.strip(), 'utc': utc_iso()})
            issue['coding_acknowledged'] = issue['coding_acknowledged'][-10:]
            issue['coding_unresolved'] = None
            released_issues.append(issue['issue_id'])
        store_state(state_dir, state)
        return emit({'status': 'ok', 'gm_id': args.gm, 'recovered': recovered,
                     'acknowledged': {'note': args.note.strip(),
                                      'attempt_status': unresolved.get('status'),
                                      'usage_measured': unresolved.get('usage_measured'),
                                      'usage': unresolved.get('usage')},
                     'released_issues': released_issues,
                     'note': 'the uncertain record is preserved in history, not zeroed'}, 0)


# --------------------------------------------------------------------------- cli

def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    subparsers = parser.add_subparsers(dest='command', required=True)

    shared = argparse.ArgumentParser(add_help=False)
    shared.add_argument('--config', type=Path, default=DEFAULT_CONFIG)
    shared.add_argument('--key-file', type=Path, default=DEFAULT_KEY_FILE)
    shared.add_argument('--codex', default=shutil.which('codex') or 'codex',
                        help='codex executable, or a quoted command line (tests inject a fake)')
    shared.add_argument('--codex-home', type=Path,
                        help='CODEX_HOME for the resume preflight and the child process')
    shared.add_argument('--timeout', type=int, default=900, help='seconds per dispatch, 30..3600')
    shared.add_argument('--protect', action='append', default=[],
                        help='path whose sha256 must not change during the dispatch')
    shared.add_argument('--break-lock', action='store_true',
                        help='take over a lock file left by a run that already died')

    observe_parser = subparsers.add_parser('observe', parents=[shared],
                                           help='import reviewed evidence and dispatch GM turns')
    observe_parser.add_argument('--evidence', required=True, type=Path)
    observe_parser.add_argument('--investigation-file', type=Path,
                                help='explicit supervisor investigation bound to evidence hash/pointers')
    observe_parser.add_argument('--state-dir', required=True, type=Path)
    observe_parser.add_argument('--dry-run', action='store_true')
    observe_parser.add_argument('--max-gms', type=int, default=10)
    observe_parser.add_argument('--max-issues-per-gm', type=int, default=4)
    observe_parser.add_argument('--gm', action='append', default=[])
    observe_parser.add_argument('--prior-ledger', type=Path, default=DEFAULT_PRIOR_LEDGER)
    observe_parser.add_argument('--max-prompt-bytes', type=int, default=24000)
    observe_parser.set_defaults(func=observe)

    code_parser = subparsers.add_parser('code', parents=[shared],
                                        help="dispatch the owning GM's coding worker")
    code_parser.add_argument('--state-dir', required=True, type=Path)
    code_parser.add_argument('--issue', required=True)
    code_parser.add_argument('--scope-file', required=True, type=Path)
    code_parser.add_argument('--base-revision', required=True)
    code_parser.add_argument('--candidate', type=Path)
    code_parser.add_argument('--dry-run', action='store_true')
    code_parser.add_argument('--run-scope-tests', action='store_true')
    code_parser.set_defaults(func=code)

    status_parser = subparsers.add_parser('status', help='read-only state summary')
    status_parser.add_argument('--state-dir', required=True, type=Path)
    status_parser.set_defaults(func=status)

    recover_parser = subparsers.add_parser('recover',
                                           help='explicitly reconcile an interrupted/unknown attempt')
    recover_parser.add_argument('--state-dir', required=True, type=Path)
    recover_parser.add_argument('--gm', required=True)
    recover_parser.add_argument('--note', required=True)
    recover_parser.add_argument('--usage', required=True,
                                choices=('unknown', 'no_provider_usage', 'external_ledger'),
                                help='what the operator established about the provider usage')
    recover_parser.add_argument('--break-lock', action='store_true')
    recover_parser.set_defaults(func=recover)

    acknowledge_parser = subparsers.add_parser('acknowledge',
                                               help='clear the dispatch block, keeping the record')
    acknowledge_parser.add_argument('--state-dir', required=True, type=Path)
    acknowledge_parser.add_argument('--gm', required=True)
    acknowledge_parser.add_argument('--note', required=True)
    acknowledge_parser.add_argument('--break-lock', action='store_true')
    acknowledge_parser.set_defaults(func=acknowledge)
    return parser


def main(argv=None) -> int:
    args = build_parser().parse_args(argv)
    if not 30 <= getattr(args, 'timeout', 900) <= 3600:
        return refusal('usage', '--timeout must be 30..3600 seconds', 2)
    try:
        return args.func(args)
    except RuntimeError as error:
        return refusal('lock_held', str(error), 7)
    except ValueError as error:
        return refusal('preflight', str(error), 2)
    except subprocess.TimeoutExpired as error:
        return refusal('command_timeout', str(error), 1)


if __name__ == '__main__':
    sys.exit(main())
