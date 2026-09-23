#!/usr/bin/env python3
"""Bounded autonomous GM development cycle built directly on tools/gm_runner.py.

One invocation under one standing policy advances a single visible result:

  evidence -> GM-selected and claimed work with a GM-proposed scope -> candidate implementation
  -> host-executed validation -> controlled publication into an explicitly supplied trial
  checkout -> real runtime verification against a continued save -> durable feedback to that GM.

The cycle never manufactures issues, scope files or per-stage supervisor dispatches. The GM
proposes; the host validates the proposal against the immutable policy, derives the executed
scope and test commands, owns the release decision and reports what the world actually did.
`no_action` and "no supported evidence" are preserved as useful outcomes.

Reused unchanged from gm_runner: identity, provenance, evidence validation, transport, candidate
worktree isolation, usage accounting, locking, unknown-cost gates and code execution. Nothing here
calls a model itself; it drives `gm_runner.py observe|code|acknowledge` as subprocesses and runs
the host gate, the publication and the runtime check.

Commands (repository-relative):
  python tools/gm_autonomy.py cycle --policy <policy.json>
  python tools/gm_autonomy.py cycle --policy <policy.json> --stop-after publish
  python tools/gm_autonomy.py status --state-dir <state-dir>

Exit codes: 0 ok (including a bounded no_action/limit stop), 1 runtime failure,
2 usage or missing-requirement preflight (no model dispatch), 3 stale or wrong-world source,
4 unacceptable source, 5 unresolved accounting / interrupted paid call, 6 scope or release
precondition refused, 7 state directory lock held by another run.

Production mode refuses before any dispatch unless evidence, carried state, prior ledger,
trial checkout and the Godot runtime all exist. Offline fixture mode is labelled as a fixture
everywhere it appears and proves code paths, not real DeepSeek GM autonomy.
"""
from __future__ import annotations

import argparse
import copy
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import threading
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import gm_runner  # noqa: E402
import world_design_contract  # noqa: E402
import owned_windows_job  # noqa: E402

CYCLE_SCHEMA = 2
# `review` is a durable hand-off from the GM to the main AI.  It is deliberately not a
# provider call: a review must be supplied as a concrete, candidate-bound record before release.
STAGES = ('observe', 'candidate', 'validate', 'review', 'publish', 'verify', 'feedback')
REPAIRABLE = ('scope_tests_failed', 'invalid_output', 'worker_blocked')
# One reopened repair round is only allowed for an actionable, owned, host-observed failure: a
# runtime verification defect the running world actually reported, or an ordinary owned candidate
# test failure at the host gate. Guard/scope/conflict refusals, unknown or interrupted calls and
# installed-but-unused are never turned into a coding retry.
REPAIRABLE_FAILURE_REASONS = ('runtime_verification_failed',)
REPAIRABLE_VALIDATE_CHECKS = ('host_test_commands_pass',)
# gm_runner.observe applies its --timeout to each selected GM in sequence.  The owning wrapper
# therefore needs a batch allowance instead of reusing one GM's allowance for the whole process.
# This covers bounded runner cleanup between sessions; run_process still caps the result at the
# cycle's pinned deadline.
OBSERVE_CLEANUP_SECONDS_PER_GM = 30
# Keep the cycle default identical to gm_runner.observe while allowing a reviewed run to
# raise the bound for a larger, still finite state projection. The upper bound prevents a
# typo from turning a bounded observation into an effectively unbounded prompt.
DEFAULT_MAX_PROMPT_BYTES = 32768
MIN_MAX_PROMPT_BYTES = 1024
MAX_MAX_PROMPT_BYTES = 1048576
# A semantic repair may only be justified by fresh, exactly bound evidence from processes that
# fully exited. A failure here means the observation is NOT a trustworthy report about this
# release: a timeout, a missing/stale output file, a foreign nonce/world/release/issue or a
# still-live child process. Such a run is inconclusive and must stay stopped.
REPAIRABLE_VERIFY_INTEGRITY_CHECKS = ('deployed_bytes_match_release',
                                      'every_phase_bound_to_this_release', 'no_phase_timed_out',
                                      'owned_processes_exited', 'fresh_output_for_this_nonce',
                                      'release_digest_matches', 'world_id_matches',
                                      'issue_id_matches')
# The running world's own report about candidate behavior. These are the only failed checks a
# repair round may reopen for; installed-but-unused keeps its own stopped reason and is never
# converted into a forced adoption.
# `runtime_exit_ok` is deliberately NOT an integrity check: the world's own defect report exits
# nonzero, so a nonzero code is expected here while a crash still fails the freshness/binding
# checks above.
REPAIRABLE_VERIFY_DEFECT_CHECKS = ('every_phase_reported_ok', 'runtime_exit_ok',
                                   'runtime_reports_ok', 'installed', 'used_not_invented',
                                   'same_save_continuation')


def conclusive_runtime_defect(failed_checks) -> bool:
    """True only for a functionally defective candidate observed under valid evidence."""
    failed = set(failed_checks or ())
    if not failed:
        return False
    if failed & set(REPAIRABLE_VERIFY_INTEGRITY_CHECKS):
        return False
    return failed <= set(REPAIRABLE_VERIFY_DEFECT_CHECKS)
OK, RUNTIME, USAGE, STALE, UNACCEPTABLE, ACCOUNTING, PRECONDITION, LOCK = range(8)
# A release is still bounded by the standing policy (and never by an arbitrary single-file
# assumption).  Eight is the same upper bound used for a proposed scope.
RELEASE_FILES_THIS_VERSION = 8


def sha256_bytes(payload: bytes) -> str:
    return gm_runner.sha256_bytes(payload)


def sha256_file(path: Path) -> str | None:
    return gm_runner.sha256_file(path)


def file_digest_or_none(path) -> str | None:
    """The sha256 of an existing file, or None when it is absent or unreadable. Never raises:
    a missing pin must refuse a release, not crash the runner."""
    try:
        return sha256_file(path) if path and Path(path).is_file() else None
    except OSError:
        return None


def safe_relpath(value) -> str | None:
    """A repo- or checkout-relative path with no drive, leading slash or traversal."""
    text = str(value).replace('\\', '/').strip()
    if text in ('', '.'):
        return ''
    if text.startswith('/') or re.match(r'^[A-Za-z]:', text):
        return None
    parts = [part for part in text.split('/') if part not in ('', '.')]
    if any(part == '..' for part in parts):
        return None
    return '/'.join(parts)


def is_within(child: Path, root: Path) -> bool:
    """True only when child resolves to root or a real descendant of root."""
    try:
        child_resolved, root_resolved = child.resolve(), root.resolve()
    except OSError:
        return False
    return child_resolved == root_resolved or root_resolved in child_resolved.parents


def reparse_escape(target: Path, root: Path) -> str | None:
    """Refuse a symlink/junction hop below root. Never relaxes a guard to make a path fit."""
    root_resolved = root.resolve()
    try:
        relative = target.resolve().relative_to(root_resolved)
    except (OSError, ValueError):
        return f'{target} is not inside {root_resolved}'
    probe = root_resolved
    for part in relative.parts:
        probe = probe / part
        try:
            if probe.is_symlink():
                return f'{probe} is a symlink; refusing to traverse it'
            if hasattr(Path, 'is_junction') and probe.is_junction():
                return f'{probe} is a junction/reparse point; refusing to traverse it'
        except OSError as error:
            return f'{probe} could not be inspected: {error}'
    return None


def resolve_path(value, base: Path = ROOT) -> Path | None:
    if value is None or str(value).strip() == '':
        return None
    path = Path(str(value))
    return path if path.is_absolute() else (base / path)


def policy_values(policy: dict) -> dict:
    return {'limits': policy.get('limits') or {}, 'paths': policy.get('paths') or {},
            'deployment': policy.get('deployment') or {}, 'runtime': policy.get('runtime') or {}}


def path_matches(rel: str, pattern: str) -> bool:
    rel = rel.replace('\\', '/').strip('/')
    pattern = pattern.replace('\\', '/').strip('/')
    if pattern.endswith('/**'):
        prefix = pattern[:-3].rstrip('/')
        return rel == prefix or rel.startswith(prefix + '/')
    if pattern.endswith('/*'):
        prefix = pattern[:-2].rstrip('/')
        tail = rel[len(prefix) + 1:] if rel.startswith(prefix + '/') else None
        return tail is not None and tail != '' and '/' not in tail
    return rel == pattern

def policy_errors(policy: dict) -> list[str]:
    errors = world_design_contract.policy_errors(policy)
    constraints = policy.get('scope_constraints') or {}
    allowed = constraints.get('allowed_source_paths')
    if not isinstance(allowed, list) or not allowed or not all(isinstance(v, str) for v in allowed):
        errors.append('scope_constraints.allowed_source_paths must be a non-empty list of globs')
    excluded = constraints.get('excluded_paths', [])
    if not isinstance(excluded, list) or not all(isinstance(v, str) for v in excluded):
        errors.append('scope_constraints.excluded_paths must be a list of globs')
    max_files = constraints.get('max_changed_files')
    if not isinstance(max_files, int) or not 1 <= max_files <= 8:
        errors.append('scope_constraints.max_changed_files must be an integer 1..8')
    host_owned = policy.get('host_owned_paths', [])
    if not isinstance(host_owned, list) or any(not isinstance(v, str) for v in host_owned):
        errors.append('host_owned_paths must be a list of repo-relative paths when present')
    commands = policy.get('required_test_commands')
    if (commands is not None and (not isinstance(commands, list)
            or any(not isinstance(command, list) or not command
                   or any(not isinstance(token, str) for token in command) for command in commands))):
        errors.append('required_test_commands must be a list of argv lists when present')
    limits = policy.get('limits') or {}
    for key, low, high in (('max_issues_per_cycle', 1, 4), ('max_attempts_per_issue', 1, 5),
                           ('max_dispatches', 1, 32), ('max_publishes', 0, 4),
                           ('deadline_seconds', 30, 7200)):
        value = limits.get(key)
        if not isinstance(value, int) or not low <= value <= high:
            errors.append(f'limits.{key} must be an integer {low}..{high}')
    deployment = policy.get('deployment') or {}
    path_map = deployment.get('path_map')
    if (not isinstance(path_map, dict) or not path_map
            or not all(isinstance(k, str) and isinstance(v, str) for k, v in path_map.items())):
        errors.append('deployment.path_map must map a repo prefix string to a checkout prefix string')
    else:
        for key, value in path_map.items():
            if (safe_relpath(key) in (None, '') or safe_relpath(value) is None
                    or safe_relpath(key) != key.replace('\\', '/').strip('/').strip()):
                errors.append(f'deployment.path_map entry {key!r}->{value!r} must stay a plain '
                              'relative prefix without traversal or an absolute target')
    release_limit = deployment.get('max_files_per_release', RELEASE_FILES_THIS_VERSION)
    if (not isinstance(release_limit, int)
            or not 1 <= release_limit <= RELEASE_FILES_THIS_VERSION):
        errors.append('deployment.max_files_per_release must be an integer 1..'
                      f'{RELEASE_FILES_THIS_VERSION}')
    runtime = policy.get('runtime') or {}
    runtime_kind = runtime.get('kind', 'fixture_script')
    for field in ('godot', 'save_path'):
        if not isinstance(runtime.get(field), str) or not runtime[field].strip():
            errors.append(f'runtime.{field} must be a non-empty string')
    if runtime_kind == 'fixture_script':
        if 'script' in runtime and (not isinstance(runtime.get('script'), str)
                                    or not runtime['script'].strip()):
            errors.append('runtime.script must be a non-empty string when present')
    elif runtime_kind == 'production_host_contract':
        command = runtime.get('host_command')
        prefixes = runtime.get('supported_issue_prefixes')
        release_paths = runtime.get('required_release_paths')
        if command is not None and (not isinstance(command, list) or not command
                                    or any(not isinstance(token, str) or not token for token in command)):
            errors.append('runtime.host_command must be a non-empty argv list when present')
        if prefixes is not None and (not isinstance(prefixes, list) or
                                     any(not isinstance(value, str) or not value for value in prefixes)):
            errors.append('runtime.supported_issue_prefixes must be strings when present')
        if release_paths is not None and (not isinstance(release_paths, list) or
                                          any(safe_relpath(value) is None for value in release_paths)):
            errors.append('runtime.required_release_paths must be safe repo-relative patterns when present')
    else:
        errors.append('runtime.kind must be fixture_script or production_host_contract')
    extra = runtime.get('extra_args', [])
    if not isinstance(extra, list) or any(not isinstance(value, str) for value in extra):
        errors.append('runtime.extra_args must be a list of strings when present')
    observe_archive = runtime.get('observe_archive_save', False)
    if not isinstance(observe_archive, bool):
        errors.append('runtime.observe_archive_save must be boolean when present')
    timeout = runtime.get('timeout_seconds', 120)
    if not isinstance(timeout, int) or not 5 <= timeout <= 1800:
        errors.append('runtime.timeout_seconds must be an integer 5..1800')
    feedback_attempts = limits.get('max_feedback_attempts', 2)
    if not isinstance(feedback_attempts, int) or not 1 <= feedback_attempts <= 3:
        errors.append('limits.max_feedback_attempts must be an integer 1..3')
    model_calls = limits.get('max_model_calls')
    if model_calls is not None and (not isinstance(model_calls, int) or not 1 <= model_calls <= 64):
        errors.append('limits.max_model_calls must be an integer 1..64 when present')
    return errors


def stale_world(policy: dict) -> str | None:
    """A pre-existing runtime save from another world is refused before any dispatch."""
    save = resolve_path(policy_values(policy)['runtime'].get('save_path'))
    if save is None or not save.is_file():
        return None
    try:
        existing = gm_runner.load_json(save)
    except (OSError, ValueError):
        return None
    if isinstance(existing, dict) and existing.get('world_id') not in (None, policy['world_id']):
        return ('runtime.save_path already holds world ' + str(existing.get('world_id'))
                + ', not ' + policy['world_id'])
    return None


def missing_requirements(policy: dict, mode: str) -> list[str]:
    """Concrete absent inputs. Production refuses on these before any model dispatch; the offline
    fixture still needs the executable pieces it is labelled as proving."""
    values = policy_values(policy)
    missing = []
    evidence = resolve_path(values['paths'].get('evidence'))
    state_dir = resolve_path(values['paths'].get('state_dir'))
    ledger = resolve_path(values['paths'].get('prior_ledger'))
    checkout = resolve_path(values['deployment'].get('checkout'))
    base_manifest = resolve_path(values['deployment'].get('base_manifest'))
    godot = resolve_path(values['runtime'].get('godot'))
    save_path = resolve_path(values['runtime'].get('save_path'))
    if evidence is None or not evidence.is_file():
        missing.append('paths.evidence (reviewed evidence snapshot file)')
    if state_dir is None:
        missing.append('paths.state_dir')
    elif mode == 'production' and not (state_dir / gm_runner.STATE_FILE).is_file():
        missing.append('paths.state_dir/' + gm_runner.STATE_FILE + ' (carried GM/world state)')
    if ledger is None or not ledger.is_file():
        missing.append('paths.prior_ledger (carried paid-usage ledger reference)')
    if checkout is None or not checkout.is_dir():
        missing.append('deployment.checkout (disposable trial installation)')
    if base_manifest is None or not base_manifest.is_file():
        missing.append('deployment.base_manifest (declared trial base hashes)')
    if godot is None or not godot.is_file():
        missing.append('runtime.godot (Godot 4 executable)')
    if save_path is None or not save_path.parent.is_dir():
        missing.append('runtime.save_path parent directory')
    return missing


def validate_proposed_scope(scope, policy: dict) -> tuple:
    """Host validation of a GM proposal against the immutable policy. The GM never approves
    itself: only paths inside allowed_source_paths, outside excluded_paths and outside
    host_owned_paths survive, and the executed test commands are always the policy's."""
    constraints = policy.get('scope_constraints') or {}
    host_owned = policy.get('host_owned_paths') or []
    errors = []
    if not isinstance(scope, dict):
        return None, ['no usable scope object was proposed']
    errors.extend(world_design_contract.scope_errors(scope, policy))
    objective = scope.get('objective')
    if not isinstance(objective, str) or not 12 <= len(objective.strip()) <= 400:
        errors.append('scope.objective must be one concrete 12..400 character sentence')
    files = scope.get('files')
    if not isinstance(files, list) or not files or any(not isinstance(v, str) for v in files):
        errors.append('scope.files must be a non-empty list of repo-relative paths')
    elif len(files) > constraints.get('max_changed_files', 0):
        errors.append('scope.files exceeds max_changed_files '
                      + str(constraints.get('max_changed_files')))
    else:
        for entry in files:
            rel = str(entry).replace('\\', '/')
            if world_design_contract.required(policy) and Path(rel).as_posix().casefold() in (
                    value.casefold() for value in world_design_contract.PROTECTED):
                errors.append(f'scope file {entry!r} is protected by the Aincrad contract')
            if Path(rel).is_absolute() or ':' in rel or '..' in Path(rel).parts:
                errors.append(f'scope file {entry!r} is not repo-relative')
                continue
            if not any(path_matches(rel, pattern)
                       for pattern in constraints.get('allowed_source_paths', [])):
                errors.append(f'scope file {entry!r} is outside allowed_source_paths')
            if any(path_matches(rel, pattern) for pattern in constraints.get('excluded_paths', [])):
                errors.append(f'scope file {entry!r} is excluded by policy')
            if any(path_matches(rel, pattern) for pattern in host_owned):
                errors.append(f'scope file {entry!r} is host-owned and cannot be modified by a coder')
    acceptance = scope.get('acceptance')
    if (not isinstance(acceptance, list) or not acceptance or len(acceptance) > 8
            or any(not isinstance(v, str) or not v.strip() for v in acceptance)):
        errors.append('scope.acceptance must be 1..8 non-empty observable checks')
    if errors:
        return None, errors
    result = {'objective': objective.strip(), 'files': [str(v).replace('\\', '/') for v in files],
              'acceptance': [str(v).strip() for v in acceptance]}
    if world_design_contract.required(policy):
        result['design_review'] = world_design_contract.normalized_review(scope)
    return result, []


def resolve_command(command: list, values: dict) -> tuple:
    resolved, errors = [], []
    for token in command:
        text = str(token)
        for key, replacement in values.items():
            text = text.replace('{' + key + '}', str(replacement))
        if re.search(r'\{[a-z_]+\}', text):
            errors.append(f'test command token {token!r} keeps an unresolved placeholder')
        resolved.append(text)
    return (None, errors) if errors else (resolved, [])


def deployment_target(rel: str, path_map: dict) -> str | None:
    rel = rel.replace('\\', '/')
    for prefix in sorted(path_map, key=len, reverse=True):
        if rel.startswith(prefix):
            head = str(path_map[prefix]).replace('\\', '/').strip('/')
            tail = rel[len(prefix):].strip('/')
            return ((head + '/' + tail).strip('/')) if head else tail
    return None


def _drain(stream, sink: list) -> None:
    try:
        for line in stream:
            sink.append(line)
    except (OSError, ValueError):
        pass


def run_process(command: list, timeout: int, cwd: Path = ROOT, deadline=None) -> dict:
    """One bounded owned subprocess, capped by the remaining cycle deadline.

    On Windows this uses the existing tools/owned_windows_job.py kill-on-close job so the child
    and every descendant are contained and terminated on timeout; observed member PIDs and exit
    codes are returned instead of an unconditional "waited" claim.
    """
    budget = max(1, int(timeout))
    if deadline is not None and int(deadline - time.time()) <= 0:
        # The pinned deadline already expired: do not start a new process the caller cannot own.
        return {'command': command, 'exit_code': None, 'timed_out': True,
                'deadline_exceeded': True, 'stdout': '', 'stderr': '', 'seconds': 0.0,
                'owned': {'containment': 'not_started_deadline', 'wrapper_pid': None,
                          'observed_members': [], 'all_members_exited': None,
                          'member_identity_list_complete': None}}
    if deadline is not None:
        budget = max(1, min(budget, int(deadline - time.time())))
    started = time.time()
    outcome = {'command': command, 'exit_code': None, 'timed_out': False, 'stdout': '',
               'stderr': '', 'seconds': 0.0, 'deadline_exceeded': False,
               'owned': {'containment': 'not_windows_job', 'wrapper_pid': None,
                         'observed_members': [], 'all_members_exited': None,
                         'member_identity_list_complete': None}}
    if os.name == 'nt':
        tree = owned_windows_job.WindowsProcessTree(
            command, cwd=str(cwd), stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            text=True, encoding='utf-8', errors='replace')
        stdout_chunks, stderr_chunks = [], []
        readers = [threading.Thread(target=_drain, args=(tree.process.stdout, stdout_chunks),
                                    daemon=True),
                   threading.Thread(target=_drain, args=(tree.process.stderr, stderr_chunks),
                                    daemon=True)]
        try:
            for reader in readers:
                reader.start()
            try:
                outcome['exit_code'] = tree.wait(budget)
            except subprocess.TimeoutExpired:
                outcome['timed_out'] = True
                tree.terminate()
            for reader in readers:
                reader.join(timeout=10)
            outcome['stdout'] = ''.join(stdout_chunks)
            outcome['stderr'] = ''.join(stderr_chunks)
        finally:
            for stream in (tree.process.stdout, tree.process.stderr):
                try:
                    stream.close()
                except (AttributeError, OSError):
                    pass
            try:
                outcome['owned'] = tree.snapshot()
            finally:
                tree.close()
            members = (outcome['owned'] or {}).get('observed_members') or []
            nonzero = [member for member in members if isinstance(member, dict)
                       and member.get('exit_code') not in (None, 0)]
            outcome['wrapper_exit_code'] = outcome['exit_code']
            if outcome['exit_code'] == 0 and nonzero:
                outcome['exit_code'] = nonzero[0]['exit_code']
                outcome['exit_reconciled_from_member'] = True
    else:
        process = subprocess.Popen(command, cwd=str(cwd), stdout=subprocess.PIPE,
                                   stderr=subprocess.PIPE, text=True, encoding='utf-8',
                                   errors='replace', start_new_session=True)
        try:
            outcome['stdout'], outcome['stderr'] = process.communicate(timeout=budget)
            outcome['exit_code'] = process.returncode
        except subprocess.TimeoutExpired:
            outcome['timed_out'] = True
            try:
                os.killpg(process.pid, 15)
                process.communicate(timeout=10)
            except (OSError, subprocess.TimeoutExpired):
                process.kill()
            outcome['owned'] = {'containment': 'posix_process_group', 'wrapper_pid': process.pid,
                                'observed_members': [{'pid': process.pid}],
                                'all_members_exited': process.poll() is not None,
                                'member_identity_list_complete': True}
    # Command exit provenance. The process this host started carries the AUTHORITATIVE outcome
    # of the command; a nested tool/probe that failed after the command's own work settled is
    # kept as evidence instead of being invented as that command's result. `exit_code` keeps
    # the long-standing reconciled value, so a caller that owns the whole tree - every host
    # test command - still fails on a hidden child failure, while a caller that trusts a
    # completed runner receipt can compare the wrapper's own exit.
    nested = [item for item in ((outcome['owned'] or {}).get('observed_members') or [])
              if isinstance(item, dict) and item.get('exit_code') not in (None, 0)]
    outcome.setdefault('wrapper_exit_code', outcome['exit_code'])
    outcome.setdefault('observed_nonzero_member_exits',
                       [{'pid': item.get('pid'), 'exit_code': item.get('exit_code')}
                        for item in nested])
    # Job accounting knows the cumulative assigned count, but an exited short-lived
    # process can disappear before its PID/exit code is observed. Never certify the
    # aggregate host command as green in that ambiguous case; keep the wrapper result
    # authoritative for runner receipts and report the aggregate as unknown.
    if (outcome.get('wrapper_exit_code') == 0 and not nested
            and (outcome.get('owned') or {}).get('member_identity_list_complete') is False):
        outcome['exit_code'] = None
        outcome['ownership_incomplete'] = True
        outcome['ownership_incomplete_reason'] = 'assigned_process_identity_not_observed'
    outcome['seconds'] = round(time.time() - started, 3)
    return outcome


def observe_batch_timeout(per_gm_timeout: int, gm_count: int) -> int:
    """Bound one serial gm_runner.observe batch while preserving its per-GM timeout."""
    return max(1, int(gm_count)) * (
        max(1, int(per_gm_timeout)) + OBSERVE_CLEANUP_SECONDS_PER_GM)


def last_json_line(text: str):
    for line in reversed((text or '').splitlines()):
        line = line.strip()
        if line.startswith('{'):
            try:
                return json.loads(line)
            except json.JSONDecodeError:
                continue
    return None


def runner_command(runner: dict, subcommand: str, *args) -> list:
    command = [sys.executable, str(ROOT / 'tools' / 'gm_runner.py'), subcommand]
    if subcommand in ('observe', 'code', 'feedback'):
        route = runner.get('route', gm_runner.ROUTE_DEEPSEEK)
        if route != gm_runner.ROUTE_DEEPSEEK:
            command += ['--route', str(route)]
        for name in ('config', 'key_file', 'codex', 'codex_home'):
            if runner.get(name):
                command += ['--' + name.replace('_', '-'), str(runner[name])]
        if runner.get('timeout'):
            command += ['--timeout', str(runner['timeout'])]
    if subcommand == 'observe' and runner.get('max_prompt_bytes') is not None:
        command += ['--max-prompt-bytes', str(runner['max_prompt_bytes'])]
    command += [str(item) for item in args]
    return command


def effect_review_baseline(state: dict, issue_id: str | None, save_path: Path | None) -> dict | None:
    """Bind a capability release to the resident history position visible at publication."""
    issue = (state.get('issues') or {}).get(issue_id) if issue_id else None
    if not isinstance(issue, dict) or save_path is None or not save_path.is_file():
        return None
    resident_id, capability_id = issue.get('resident_id'), issue.get('capability_id')
    if not isinstance(resident_id, str) or not resident_id:
        resident_id = (issue.get('entry') or {}).get('resident_id')
    if not isinstance(capability_id, str) or not capability_id:
        capability_id = (issue.get('entry') or {}).get('capability_id')
    if not all(isinstance(value, str) and value for value in (resident_id, capability_id)):
        return None
    try:
        world = gm_runner.load_json(save_path)
    except (OSError, ValueError, json.JSONDecodeError, UnicodeDecodeError):
        return None
    if not isinstance(world, dict) or world.get('world_id') != state.get('world_id'):
        return None
    turn = ((world.get('godot') or {}).get('resident_turns') or {}).get(resident_id) or {}
    history = turn.get('history') if isinstance(turn, dict) else None
    if not isinstance(history, list):
        history = []
    life_seq = (world.get('life') or {}).get('seq')
    if type(life_seq) is not int:
        return None
    return {'status': 'pending', 'resident_id': resident_id, 'capability_id': capability_id,
            'baseline_life_seq': life_seq, 'baseline_history_count': len(history),
            'required_action_binding': ('terminal command result with matching world, resident, '
                                        'command_id and capability_id')}


def _bounded_action_result(value) -> dict:
    """Keep authoritative action facts while excluding resident prose and private reasoning."""
    if not isinstance(value, dict):
        return {}
    forbidden = ('reason', 'text', 'speech', 'message', 'prompt')
    result = {}
    for key, item in value.items():
        if any(marker in str(key).casefold() for marker in forbidden):
            continue
        if isinstance(item, (str, int, float, bool)) or item is None:
            result[str(key)] = item
        elif isinstance(item, list) and len(item) <= 16 and all(
                isinstance(part, (str, int, float, bool)) or part is None for part in item):
            result[str(key)] = list(item)
    return result


def _authoritative_action_result(world: dict, resident_id: str, entry: dict) -> dict:
    """Resolve one resident decision through the world's durable command journals.

    The archived turn result is only the submission-time effect.  Long-running actions remain
    accepted/pending there, so adoption must come from a terminal journal receipt.  Trade wrappers
    may mirror a life command under the same id; this follows the runtime's feedback projection and
    only accepts the mirror when both records name the same actor.
    """
    command_id = entry.get('command_id')
    if not isinstance(command_id, str) or not command_id:
        return {'status': 'missing', 'reason': 'missing_command_id'}
    godot = world.get('godot')
    if not isinstance(godot, dict):
        return {'status': 'missing', 'command_id': command_id, 'reason': 'missing_godot_state'}
    life_commands = godot.get('commands') if isinstance(godot.get('commands'), dict) else {}
    trade = godot.get('trade') if isinstance(godot.get('trade'), dict) else {}
    material = godot.get('materials') if isinstance(godot.get('materials'), dict) else {}
    baking = godot.get('baking') if isinstance(godot.get('baking'), dict) else {}
    places = godot.get('places') if isinstance(godot.get('places'), dict) else {}
    journals = (('trade', trade.get('commands')), ('life', life_commands),
                ('materials', material.get('commands')), ('baking', baking.get('commands')),
                ('places', places.get('commands')))
    namespace, command = None, None
    for candidate_namespace, commands in journals:
        if isinstance(commands, dict) and isinstance(commands.get(command_id), dict):
            namespace, command = candidate_namespace, commands[command_id]
            break
    if command is None:
        return {'status': 'missing', 'command_id': command_id,
                'reason': 'no_authoritative_command'}
    payload = command.get('payload')
    actor_id = payload.get('actor_id') if isinstance(payload, dict) else None
    if actor_id != resident_id:
        return {'status': 'invalid', 'command_id': command_id, 'namespace': namespace,
                'reason': 'actor_mismatch'}
    # A pending trade wrapper can lag the life command it started.  The runtime uses that exact
    # terminal mirror for resident feedback; require the same actor before doing so here.
    if namespace == 'trade' and command.get('status') == 'pending':
        mirror = life_commands.get(command_id)
        mirror_payload = mirror.get('payload') if isinstance(mirror, dict) else None
        if (isinstance(mirror_payload, dict) and mirror_payload.get('actor_id') == resident_id
                and mirror.get('status') in ('completed', 'rejected')):
            namespace, command = 'life', mirror
    status = command.get('status')
    if status == 'pending':
        return {'status': 'pending', 'command_id': command_id, 'namespace': namespace}
    if status not in ('completed', 'rejected'):
        return {'status': 'invalid', 'command_id': command_id, 'namespace': namespace,
                'reason': 'invalid_command_status'}
    receipt = command.get('result')
    if not isinstance(receipt, dict):
        return {'status': status, 'command_id': command_id, 'namespace': namespace,
                'reason': 'missing_terminal_result'}
    if receipt.get('actor_id') != resident_id or receipt.get('command_id') != command_id:
        return {'status': 'invalid', 'command_id': command_id, 'namespace': namespace,
                'reason': 'terminal_receipt_mismatch'}
    return {'status': status, 'command_id': command_id, 'namespace': namespace,
            'result': _bounded_action_result(receipt)}


def pending_effect_observation(state: dict, save_path: Path | None) -> dict | None:
    """Produce one release-bound next-life observation, or None when no new window exists."""
    if save_path is None or not save_path.is_file():
        return None
    try:
        world = gm_runner.load_json(save_path)
    except (OSError, ValueError, json.JSONDecodeError, UnicodeDecodeError):
        return None
    if not isinstance(world, dict) or world.get('world_id') != state.get('world_id'):
        return None
    life_seq = (world.get('life') or {}).get('seq')
    if type(life_seq) is not int:
        return None
    for gm_id in gm_runner.GM_IDS:
        owner = (state.get('sessions') or {}).get(gm_id)
        if not isinstance(owner, dict):
            continue
        memory = gm_runner.ensure_gm_memory(owner, gm_id)
        for event in memory['host_feedback']:
            if not isinstance(event, dict) or event.get('effect_review_result'):
                continue
            release = event.get('receipt')
            if (not isinstance(release, dict) or release.get('kind') != 'autonomy_release_receipt'
                    or release.get('gm_id') != gm_id or release.get('world_id') != state['world_id']
                    or not release.get('published') or not release.get('release_digest')):
                continue
            binding = release.get('effect_review')
            if not isinstance(binding, dict) or binding.get('status') != 'pending':
                continue
            baseline_seq = binding.get('baseline_life_seq')
            baseline_count = binding.get('baseline_history_count')
            if type(baseline_seq) is not int or type(baseline_count) is not int:
                continue
            # The original resident must have made a later decision and the public life window
            # must have advanced.  Another resident changing life_seq never wakes this review.
            if life_seq <= baseline_seq:
                continue
            resident_id, capability_id = binding.get('resident_id'), binding.get('capability_id')
            turn = ((world.get('godot') or {}).get('resident_turns') or {}).get(resident_id) or {}
            history = turn.get('history') if isinstance(turn, dict) else None
            if not isinstance(history, list) or len(history) <= baseline_count:
                continue
            observed = []
            owner_pending = False
            for entry in history[baseline_count:]:
                if not isinstance(entry, dict):
                    continue
                resolved = _authoritative_action_result(world, resident_id, entry)
                action = {'command_id': entry.get('command_id'), 'action': entry.get('action'),
                          'command': resolved}
                observed.append(action)
                if resolved.get('status') == 'pending':
                    owner_pending = True
            matches = [entry for entry in observed
                       if entry['command'].get('status') == 'completed'
                       and entry['command'].get('result', {}).get('ok') is True
                       and entry['command']['result'].get('capability_id') == capability_id]
            adopted = bool(matches)
            # Re-scan every post-release command before consulting the negative watermark.  This
            # is what lets an old submitted history row wake the owner when its authoritative
            # journal later becomes terminal without appending another resident decision.
            if not adopted and owner_pending:
                continue
            progress = event.get('effect_review_progress')
            if (not adopted and isinstance(progress, dict)
                    and progress.get('negative_feedback_sent') is True):
                continue
            parent = {'receipt_sha256': event.get('receipt_sha256'),
                      'cycle_id': release.get('cycle_id'), 'issue_id': release.get('issue_id'),
                      'world_id': release.get('world_id'), 'gm_id': release.get('gm_id'),
                      'release_digest': release.get('release_digest')}
            return {'kind': 'autonomy_effect_observation_receipt', 'schema_version': 1,
                    'parent': parent, 'outcome': ('resident_action_observed'
                                                  if adopted else 'no_adoption_observed'),
                    'observation_window': {'baseline_life_seq': baseline_seq,
                                           'observed_life_seq': life_seq,
                                           'resident_id': resident_id,
                                           'capability_id': capability_id,
                                           'baseline_history_count': baseline_count,
                                           'observed_history_count': len(history)},
                    'matching_action_receipts': matches,
                    'new_action_receipt_count': len(observed),
                    'adoption_claimed': adopted,
                    'review_terminal': adopted,
                    'effect_review_status': ('adopted_terminal' if adopted
                                             else 'pending_after_observation'),
                    'note': (('the matching terminal command is evidence of adoption and closes '
                              'this effect review') if adopted else
                             ('the original resident decision and life window opened one bounded '
                              'negative observation; it does not close the release, and later '
                              'matching terminal command result remains observable as adoption'))}
    return None


def validated_observe_receipt(cycle, run_id, dispatched=None):
    """The durable gm_runner observe receipt for this exact run, or None when it is not trusted.

    The host never certifies an observation from a stdout status: it re-reads the run.json the
    runner itself wrote under runs/<run_id>/ and requires the whole closed set - the exact run id,
    the pinned world and evidence digest, unchanged guards, no credential leak, no deploy, and
    every dispatched GM settled ok with measured, known usage. Anything missing returns None,
    which callers must treat as unverified, never as success.
    """
    if (not isinstance(run_id, str) or not run_id or safe_relpath(run_id) != run_id
            or '/' in run_id or '\\' in run_id):
        return None
    runs_root = cycle.state_dir / 'runs'
    path = runs_root / run_id / 'run.json'
    if not is_within(path, runs_root) or not path.is_file():
        return None
    try:
        receipt = gm_runner.load_json(path)
    except (OSError, ValueError):
        return None
    if not isinstance(receipt, dict) or receipt.get('kind') != 'gm_observe':
        return None
    if receipt.get('status') != 'ok' or receipt.get('run_id') != run_id:
        return None
    if receipt.get('aborted_by') or receipt.get('credential_leak_in_run_dir'):
        return None
    guards = receipt.get('guards') or {}
    before, after, claimed = guards.get('before'), guards.get('after'), guards.get('changed')
    if not isinstance(before, dict) or not isinstance(after, dict):
        return None
    if not isinstance(claimed, list) or claimed:
        return None
    try:
        if gm_runner.guard_diff(before, after):
            return None
    except KeyError:
        return None
    if receipt.get('deployed') or receipt.get('review_state') != 'unapproved':
        return None
    world_id = cycle.policy.get('world_id')
    evidence = receipt.get('evidence') or {}
    if receipt.get('world_binding') != world_id:
        return None
    if evidence.get('world_id') != world_id or evidence.get('sha256') != cycle.evidence_sha256:
        return None
    if sha256_file(cycle.evidence) != cycle.evidence_sha256:
        return None
    results = receipt.get('results')
    if not isinstance(results, list) or not results:
        return None
    if receipt.get('dispatched') != len(results):
        return None
    if dispatched is not None and int(dispatched) != len(results):
        return None
    gms = []
    for item in results:
        if not isinstance(item, dict):
            return None
        gm_id = item.get('gm_id')
        if not isinstance(gm_id, str) or not gm_id or gm_id in gms:
            return None
        if item.get('status') != 'ok' or item.get('usage_measured') is not True:
            return None
        if item.get('exit_code') != 0:
            return None
        if item.get('cost') != 'measured' or item.get('unknown') or item.get('error'):
            return None
        if not item.get('dispatched'):
            return None
        gms.append(gm_id)
    return {'run_id': run_id, 'receipt_path': gm_runner.relative(path),
            'receipt_sha256': sha256_file(path), 'dispatched': len(results), 'gm_ids': sorted(gms),
            'world_id': world_id, 'evidence_sha256': cycle.evidence_sha256}


def observe_receipt_reference(cycle, summary, result):
    """The exact carried receipt for one just-finished gm_runner observe dispatch, else None.

    The dispatch starts ONE gm_runner command, so the wrapper this host started is the
    authoritative exit and only the durable receipt may certify what the observation did. A
    timeout, a live member, a held-open tree or a wrapper that itself exited nonzero refuses; the
    nested probe exits are returned as evidence, never as the outcome.
    """
    if not isinstance(summary, dict) or summary.get('kind') != 'gm_observe':
        return None
    if (summary.get('status') != 'ok' or result.get('timed_out') is not False
            or result.get('deadline_exceeded')):
        return None
    owned = result.get('owned') or {}
    if not isinstance(owned, dict) or owned.get('all_members_exited') is not True:
        return None
    if owned.get('active_processes') not in (None, 0):
        return None
    if any(isinstance(member, dict) and member.get('running')
           for member in (owned.get('observed_members') or [])):
        return None
    wrapper = result.get('wrapper_exit_code')
    if wrapper is None:
        wrapper = result.get('exit_code')
    if type(wrapper) is not int or wrapper != 0:
        return None
    if summary.get('evidence', {}).get('sha256') != cycle.evidence_sha256:
        return None
    dispatched = summary.get('dispatched')
    if not isinstance(dispatched, int) or dispatched < 1:
        return None
    reference = validated_observe_receipt(cycle, summary.get('run_id'), dispatched)
    if reference is None:
        return None
    reference['reconciled_member_exit'] = bool(result.get('exit_reconciled_from_member'))
    reference['observed_nonzero_member_exits'] = result.get('observed_nonzero_member_exits') or []
    return reference


def carried_observe_receipt(cycle, record):
    """The receipt a blocked observe_failed record already earned, or None.

    Offline recovery only. The retained record must show that the command this host started
    (wrapper_pid) exited 0 and that the record's own reconciled exit came solely from nested
    children, and the durable receipt must still prove the whole closed set. A record that cannot
    prove both - or one that failed for its own reason - is refused rather than carried.
    """
    if not isinstance(record, dict) or record.get('status') != 'failed':
        return None
    if record.get('timed_out') is not False or record.get('deadline_exceeded'):
        return None
    if record.get('unknown_cost_gms'):
        return None
    owned = record.get('owned') or {}
    if not isinstance(owned, dict) or owned.get('all_members_exited') is not True:
        return None
    if owned.get('active_processes') not in (None, 0):
        return None
    members = [item for item in (owned.get('observed_members') or []) if isinstance(item, dict)]
    if any(member.get('running') for member in members):
        return None
    wrapper = record.get('wrapper_exit_code')
    if wrapper is None:
        wrapper = next((member.get('exit_code') for member in members
                        if member.get('pid') == owned.get('wrapper_pid')), None)
    if type(wrapper) is not int or wrapper != 0:
        return None
    nested = record.get('observed_nonzero_member_exits') or owned.get('observed_nonzero_exits')
    if not nested:
        return None
    dispatched = record.get('dispatched')
    if not isinstance(dispatched, int) or dispatched < 1:
        return None
    reference = validated_observe_receipt(cycle, record.get('run_id'), dispatched)
    if reference is None:
        return None
    reference['reconciled_member_exit'] = True
    reference['observed_nonzero_member_exits'] = [
        {'pid': item.get('pid'), 'exit_code': item.get('exit_code')}
        for item in nested if isinstance(item, dict)]
    return reference


def installation_lock_root() -> Path:
    """Machine-level lock root keyed by an installation path.

    A deployment is a machine-level resource, so its lock must not live under one policy's
    state directory: two policies with different state dirs but the same deployment path must
    still exclude each other. The key is derived from the resolved deployment path only.
    """
    override = os.environ.get('GM_AUTONOMY_LOCK_ROOT')
    base = (Path(override) if override
            else Path(tempfile.gettempdir()) / 'infiniteaincrad-autonomy')
    return base / 'installations'


class OwnerLock:
    """Owner-identified OS lock built on gm_runner.StateLock.

    Liveness is decided by the platform byte-range lock, never by probing a PID. A live owner is
    never displaced; a provably dead owner's leftover metadata (its real PID and acquire time)
    is recorded in self.recovered and taken over explicitly.
    """

    def __init__(self, directory: Path, name: str):
        self.directory = Path(directory) / name
        self.handle = gm_runner.StateLock(self.directory, True)
        self.recovered = None

    def __enter__(self):
        self.handle.__enter__()
        self.recovered = self.handle.previous
        return self

    def __exit__(self, kind, value, traceback):
        return self.handle.__exit__(kind, value, traceback)


class Cycle:
    """One durable cycle. Stage records live in cycle.json so a restart resumes, never replays.

    The evidence bytes and the deadline are pinned once, when the cycle is first created, and
    persisted in cycle.json: a later edit to the evidence file cannot silently move the running
    cycle, and a restarted process does not get a fresh budget.
    """

    def __init__(self, policy_path: Path, policy: dict, runner: dict, stop_after,
                 watch_deadline=None, watch_calls=None, allow_deferred_advance=False,
                 selected_gms=None, review_path=None, reopen_major_block=False):
        self.policy_path = policy_path
        self.policy = policy
        self.policy_sha = sha256_file(policy_path)
        self.runner = runner
        self.stop_after = stop_after
        self.values = policy_values(policy)
        self.mode = policy['mode']
        self.limits = self.values['limits']
        self.evidence = resolve_path(self.values['paths'].get('evidence'))
        self.state_dir = resolve_path(self.values['paths'].get('state_dir'))
        self.ledger = resolve_path(self.values['paths'].get('prior_ledger'))
        self.checkout = resolve_path(self.values['deployment'].get('checkout'))
        self.base_manifest = resolve_path(self.values['deployment'].get('base_manifest'))
        self.godot = resolve_path(self.values['runtime'].get('godot'))
        self.save_path = resolve_path(self.values['runtime'].get('save_path'))
        self.evidence_bytes = (self.evidence.read_bytes()
                               if self.evidence and self.evidence.is_file() else b'')
        self.evidence_sha256 = sha256_bytes(self.evidence_bytes)
        self.watch_deadline = float(watch_deadline) if watch_deadline is not None else None
        self.watch_calls_remaining = int(watch_calls) if watch_calls is not None else None
        self.allow_deferred_advance = bool(allow_deferred_advance)
        # An explicit `cycle --gm` selector. Only the observe dispatch consumes it, and only these
        # roster GMs are asked; code and feedback keep using the issue's owning GM.
        self.selected_gms = ([str(item) for item in selected_gms] if selected_gms else None)
        self.review_path = (Path(review_path).resolve() if review_path else None)
        self.reopen_major_block = bool(reopen_major_block)
        self.deadline = time.time() + int(self.limits['deadline_seconds'])
        if self.watch_deadline is not None:
            self.deadline = min(self.deadline, self.watch_deadline)
        self.recovered_lock = None
        self.last_payload = None
        identity = '|'.join([self.policy['policy_id'], str(self.policy_sha),
                             self.policy['world_id'], self.evidence_sha256,
                             str(self.generation())])
        self._cycle_dir = self.state_dir / 'autonomy' / (
            'auto-' + sha256_bytes(identity.encode())[:16])

    # -- durable state -------------------------------------------------------------

    def cycle_dir(self) -> Path:
        return self._cycle_dir

    def autonomy_dir(self) -> Path:
        return self.state_dir / 'autonomy'

    def pointer_path(self) -> Path:
        return self.autonomy_dir() / 'current.json'

    def cycle_lock(self) -> OwnerLock:
        return OwnerLock(self.autonomy_dir(), 'cycle-owner')

    def watch_lock(self) -> OwnerLock:
        """One OS lock per state directory for the bounded watch coordinator.

        It is deliberately distinct from the cycle-owner lock and is held across the whole
        read/reconcile/write/run sequence, so two watch invocations can never spend the same
        persisted budget or drive the same cycle at the same time. Liveness comes from the
        platform byte-range lock, never from probing a PID.
        """
        return OwnerLock(self.autonomy_dir(), 'watch-owner')

    def generation(self) -> int:
        path = self.generation_path()
        if not path.is_file():
            return 0
        try:
            value = gm_runner.load_json(path)
        except (OSError, ValueError):
            return 0
        return int((value or {}).get('generation', 0))

    def generation_path(self) -> Path:
        base = '|'.join([self.policy['policy_id'], str(self.policy_sha),
                         self.policy['world_id'], self.evidence_sha256])
        return self.state_dir / 'autonomy' / ('generation-'
                                              + sha256_bytes(base.encode())[:16] + '.json')

    def bump_generation(self) -> int:
        value = self.generation() + 1
        gm_runner.save_json(self.generation_path(),
                            {'generation': value, 'updated_utc': gm_runner.utc_iso()})
        return value

    def installation_lock(self) -> OwnerLock:
        """One OS lock per installation, shared across policies and state directories."""
        # Normalize case and separators: two Windows spellings of one deployment must not take
        # two different locks and both write the same installation.
        resolved = (os.path.normcase(str(self.checkout.resolve()))
                    if self.checkout else 'none')
        return OwnerLock(installation_lock_root(), sha256_bytes(resolved.encode())[:16])

    def load_cycle(self) -> dict:
        path = self.cycle_dir() / 'cycle.json'
        if path.is_file():
            cycle = gm_runner.load_json(path)
            if cycle.get('schema_version') not in (1, CYCLE_SCHEMA):
                raise ValueError('unsupported autonomy cycle schema '
                                 + str(cycle.get('schema_version')))
            if cycle.get('policy_sha256') != self.policy_sha:
                raise ValueError('the standing policy changed after this cycle started; refusing '
                                 'to resume under a different preauthorization')
            # Schema 1 cycles remain readable.  They are deliberately inserted at the new
            # review hand-off instead of treating their old host validation as approval.
            cycle.setdefault('stages', {})
            cycle['stages'].setdefault('review', {'status': 'pending',
                                                   'reason': 'new main-AI review required'})
            cycle.setdefault('defer_effect_review', True)
            return self.adopt(cycle)
        return {'schema_version': CYCLE_SCHEMA, 'cycle_id': self.cycle_dir().name,
                'policy_id': self.policy['policy_id'], 'policy_sha256': self.policy_sha,
                'mode': self.mode, 'world_id': self.policy['world_id'], 'status': 'running',
                'stage': STAGES[0], 'stages': {}, 'dispatch_batches': {}, 'model_calls': 0,
                'attempts': {}, 'evidence_path': str(self.evidence),
                'evidence_sha256': self.evidence_sha256,
                'base_manifest_sha256': file_digest_or_none(self.base_manifest),
                'host_owned_pinned': self.host_owned_hashes(),
                'deadline_seconds': int(self.limits['deadline_seconds']),
                'deadline_epoch': self.deadline,
                'deferred_claims': [], 'declined': [], 'blocked_reason': None,
                'started_utc': gm_runner.utc_iso(), 'updated_utc': gm_runner.utc_iso(),
                'defer_effect_review': True}

    def adopt(self, cycle: dict) -> dict:
        """Rebind this process to an unfinished cycle started earlier: its pinned evidence,
        its pinned deadline and its own directory. Newer incoming evidence never displaces it."""
        pinned = Path(cycle['evidence_path']) if cycle.get('evidence_path') else self.evidence
        self.evidence = pinned
        self.evidence_sha256 = cycle.get('evidence_sha256') or self.evidence_sha256
        pinned = float(cycle.get('deadline_epoch') or self.deadline)
        self.deadline = pinned if self.watch_deadline is None else min(pinned, self.watch_deadline)
        self._cycle_dir = self.autonomy_dir() / cycle['cycle_id']
        return cycle

    def save_cycle(self, cycle: dict) -> None:
        self.cycle_dir().mkdir(parents=True, exist_ok=True)
        cycle['updated_utc'] = gm_runner.utc_iso()
        gm_runner.save_json(self.cycle_dir() / 'cycle.json', cycle)
        gm_runner.save_json(self.pointer_path(), {
            'cycle_id': cycle['cycle_id'], 'status': cycle.get('status'),
            'stage': cycle.get('stage'), 'policy_sha256': cycle.get('policy_sha256'),
            'evidence_path': cycle.get('evidence_path'),
            'evidence_sha256': cycle.get('evidence_sha256'),
            'deadline_epoch': cycle.get('deadline_epoch'),
            'updated_utc': cycle['updated_utc']})

    def stage_record(self, cycle: dict, name: str) -> dict:
        return cycle['stages'].setdefault(name, {'status': 'pending'})

    def finish_stage(self, cycle: dict, name: str, record: dict, status: str = 'done') -> None:
        record.pop('in_flight', None)
        record['status'] = status
        record['finished_utc'] = gm_runner.utc_iso()
        self.save_cycle(cycle)

    def candidate_version_sha(self, cycle: dict) -> str | None:
        """Stable identity for the exact GM candidate handed to the main AI."""
        candidate = cycle.get('stages', {}).get('candidate') or {}
        validate = cycle.get('stages', {}).get('validate') or {}
        files = validate.get('file_hashes') or {}
        if not isinstance(files, dict) or not files:
            return None
        payload = {'cycle_id': cycle.get('cycle_id'), 'gm_id': cycle.get('gm_id'),
                   'issue_id': cycle.get('issue_id'),
                   'candidate_run_id': candidate.get('candidate_run_id'),
                   'base_revision': candidate.get('base_revision'),
                   'files': sorted((str(key), str(value)) for key, value in files.items())}
        return sha256_bytes(json.dumps(payload, sort_keys=True, separators=(',', ':')).encode())

    def load_main_ai_review(self, cycle: dict) -> dict | None:
        """Read one explicit review artifact; never synthesize an approval from emptiness."""
        value = cycle.get('main_ai_review')
        if value is None and self.review_path is not None:
            try:
                value = gm_runner.load_json(self.review_path)
            except (OSError, ValueError, json.JSONDecodeError):
                value = None
        if value is None:
            policy_review = self.policy.get('main_ai_review')
            if isinstance(policy_review, dict):
                value = policy_review
            elif isinstance(policy_review, str) and Path(policy_review).is_file():
                try:
                    value = gm_runner.load_json(Path(policy_review))
                except (OSError, ValueError, json.JSONDecodeError):
                    value = None
        return value if isinstance(value, dict) else None

    def validate_main_ai_review(self, cycle: dict, review: dict) -> tuple[dict | None, list[str]]:
        expected = self.candidate_version_sha(cycle)
        errors = []
        if expected is None:
            return None, ['candidate has no complete file-hash identity']
        if review.get('cycle_id') != cycle.get('cycle_id'):
            errors.append('review.cycle_id must match this cycle')
        if review.get('gm_id') != cycle.get('gm_id'):
            errors.append('review.gm_id must match the owning GM')
        if review.get('candidate_sha256') != expected:
            errors.append('review.candidate_sha256 does not match this candidate version')
        source = review.get('source') or review.get('reviewer')
        if not isinstance(source, str) or not source.strip():
            errors.append('review.source must identify the main-AI review')
        decision = str(review.get('decision') or review.get('disposition') or '').strip().lower()
        if decision in ('advise', 'advisory', 'approve', 'approved'):
            decision = 'advisory'
            suggestions = review.get('suggestions', [])
            if not isinstance(suggestions, list) or any(
                    not isinstance(item, str) or not item.strip() for item in suggestions):
                errors.append('review.suggestions must be a list of strings when present')
            if not suggestions and not str(review.get('rationale') or review.get('summary') or '').strip():
                errors.append('an advisory review with no suggestions must include a rationale')
        elif decision in ('major_block', 'block', 'blocked'):
            decision = 'major_block'
            problem = review.get('major_problem') or review.get('problem') or review.get('reason')
            if not isinstance(problem, str) or not problem.strip():
                errors.append('a major_block review must name a concrete problem')
        else:
            errors.append('review.decision must be advisory or major_block')
        if world_design_contract.required(self.policy):
            contract = self.policy.get('design_contract') or {}
            if review.get('design_contract_sha256') != contract.get('sha256'):
                errors.append('main-AI review must cite design_contract_sha256')
            setting = review.get('setting_review')
            if not isinstance(setting, str) or not 20 <= len(setting.strip()) <= 2000:
                errors.append('main-AI review must explain the candidate setting compatibility')
            if decision == 'advisory' and review.get('setting_compatible') is not True:
                errors.append('an incompatible or unreviewed setting cannot be released')
        if errors:
            return None, errors
        normalized = dict(review)
        normalized.update({'decision': decision, 'candidate_sha256': expected,
                           'cycle_id': cycle.get('cycle_id'), 'gm_id': cycle.get('gm_id'),
                           'reviewed_utc': review.get('reviewed_utc') or gm_runner.utc_iso()})
        return normalized, []

    # -- limits --------------------------------------------------------------------

    def max_model_calls(self) -> int:
        limit = self.limits.get('max_model_calls')
        if isinstance(limit, int) and limit > 0:
            base = limit
        else:
            base = int(self.limits['max_dispatches']) * int(self.limits.get('max_gms', 10))
        if self.watch_calls_remaining is not None:
            return max(0, min(base, self.watch_calls_remaining))
        return base

    def dispatch_budget(self, cycle: dict, stage: str, model_calls: int = 1) -> str | None:
        if time.time() > self.deadline:
            return (f'pinned deadline_seconds={cycle.get("deadline_seconds")} reached before '
                    f'{stage}')
        if sum(cycle['dispatch_batches'].values()) >= int(self.limits['max_dispatches']):
            return f'max_dispatches={self.limits["max_dispatches"]} reached before {stage}'
        if int(cycle.get('model_calls', 0)) + max(0, int(model_calls)) > self.max_model_calls():
            return (f'max_model_calls={self.max_model_calls()} reached before {stage}; '
                    'one dispatch batch can be up to max_gms model calls')
        return None

    def reserve(self, cycle: dict, record: dict, stage: str, model_calls: int,
                count_batch: bool = True) -> None:
        """Reserve the external action and persist it before the process is started, so a restart
        never re-issues it and the model-call bound counts it even if the call is interrupted."""
        record['in_flight'] = {'stage': stage, 'model_calls_reserved': int(model_calls),
                               'reserved_utc': gm_runner.utc_iso()}
        if count_batch:
            cycle['dispatch_batches'][stage] = cycle['dispatch_batches'].get(stage, 0) + 1
        cycle['model_calls'] = int(cycle.get('model_calls', 0)) + int(model_calls)
        self.save_cycle(cycle)

    def settle(self, cycle: dict, record: dict, observed_model_calls=None) -> dict:
        """Reconcile the reserved bound with what actually happened.

        The reservation is deliberately kept in the record until the stage durably records its
        result (finish_stage) or a terminal failure. A crash between this save and the result
        save therefore still shows the call as in flight, so a restart stops as unknown instead
        of re-issuing a paid external call.
        """
        reserved = record.get('in_flight') or {}
        if observed_model_calls is not None:
            cycle['model_calls'] = max(
                0, int(cycle.get('model_calls', 0)) - int(reserved.get('model_calls_reserved', 0))
                + int(observed_model_calls))
        record['last_reserved'] = reserved
        record['settled_utc'] = gm_runner.utc_iso()
        self.save_cycle(cycle)
        return reserved

    def in_flight_stop(self, cycle: dict, record: dict, stage: str) -> int | None:
        reserved = record.get('in_flight')
        if not reserved:
            return None
        record['unknown_evidence'] = reserved
        record['status'] = 'unknown'
        cycle['unknown'] = {'stage': stage, 'reserved': reserved}
        return self.block(cycle, f'interrupted_inflight_{stage}: the external call outcome is '
                                  'unknown and is not replayed', ACCOUNTING)

    # -- stages --------------------------------------------------------------------

    def deliver_pending_effect_review(self, cycle: dict, observe_record: dict) -> int | None:
        """Send one new, release-bound life observation through the existing feedback route.

        No new observation window means no provider call.  A crash after reservation remains an
        explicit unknown instead of replaying the owning GM's acknowledgement.
        """
        delivery = observe_record.setdefault('effect_feedback', {})
        if delivery.get('status') == 'done':
            return None
        if delivery.get('in_flight'):
            cycle['unknown'] = {'stage': 'effect_feedback',
                                'reserved': delivery.get('in_flight')}
            return self.block(cycle, 'interrupted_inflight_effect_feedback', ACCOUNTING)
        state = gm_runner.load_state(self.state_dir)
        receipt = pending_effect_observation(state, self.save_path)
        if receipt is None:
            delivery['status'] = 'no_new_observation'
            self.save_cycle(cycle)
            return None
        blocked = self.dispatch_budget(cycle, 'effect_feedback', 1)
        if blocked:
            delivery.update({'status': 'stopped', 'blocked_reason': blocked})
            self.save_cycle(cycle)
            return self.stop(cycle, observe_record, blocked)
        receipt_path = self.cycle_dir() / 'effect-observation.json'
        gm_runner.save_json(receipt_path, receipt)
        gm_id = receipt['parent']['gm_id']
        issue_id = receipt['parent'].get('issue_id')
        command = runner_command(self.runner, 'feedback', '--state-dir', str(self.state_dir),
                                 '--gm', gm_id, '--receipt-file', str(receipt_path))
        if issue_id:
            command += ['--issue', issue_id]
        command += ['--protect', str(self.policy_path), '--protect', str(receipt_path)]
        self.reserve(cycle, delivery, 'effect_feedback', 1)
        result = run_process(command, self.runner.get('timeout') or 900, deadline=self.deadline)
        summary = last_json_line(result['stdout'])
        self.settle(cycle, delivery, 1 if summary is not None else None)
        delivery.update({'receipt': receipt, 'receipt_sha256': sha256_file(receipt_path),
                         'exit_code': result['exit_code'], 'timed_out': result['timed_out'],
                         'owned': result.get('owned'), 'summary': summary})
        if (summary is None or result['exit_code'] != 0 or result['timed_out']
                or (result.get('owned') or {}).get('all_members_exited') is not True
                or summary.get('status') != 'ok' or summary.get('acknowledged') is not True
                or summary.get('effect_review_consumed') is not True):
            delivery['status'] = 'failed'
            self.save_cycle(cycle)
            return self.block(cycle, 'effect_feedback_failed', ACCOUNTING)
        delivery.pop('in_flight', None)
        delivery['status'] = 'done'
        delivery['decision'] = summary.get('decision')
        self.save_cycle(cycle)
        return None

    def stage_observe(self, cycle: dict) -> int:
        record = self.stage_record(cycle, 'observe')
        if record['status'] == 'done':
            return OK
        stopped = self.in_flight_stop(cycle, record, 'observe')
        if stopped:
            return stopped
        effect_status = self.deliver_pending_effect_review(cycle, record)
        if effect_status is not None:
            return effect_status
        # A queued GM claim is consumed before any new observe dispatch: generation advance alone
        # is not delivery, and unchanged evidence must not be observed twice.
        queued = self.examine_queued_claims(cycle, record)
        if queued is not None:
            return queued
        estimate = int(self.limits.get('max_gms', 10))
        if self.selected_gms:
            # An explicit selector is the exact dispatch set: never widened to the roster and never
            # silently trimmed. The reservation below is the same count that is dispatched.
            estimate = len(self.selected_gms)
        remaining_calls = self.max_model_calls() - int(cycle.get('model_calls', 0))
        if self.watch_calls_remaining is not None:
            estimate = max(0, min(estimate, remaining_calls))
            if estimate <= 0:
                return self.stop(cycle, record, 'the remaining local watch model-call budget is '
                                                'exhausted before observe; no call was made')
        blocked = self.dispatch_budget(cycle, 'observe', estimate)
        if blocked:
            return self.stop(cycle, record, blocked)
        pre = self.pre_dispatch_state_check(cycle)
        if pre:
            return pre
        command = runner_command(self.runner, 'observe', '--autonomy-policy', str(self.policy_path),
                                 '--evidence', str(self.evidence), '--state-dir', str(self.state_dir),
                                 '--max-gms', str(estimate),
                                 '--max-issues-per-gm', str(self.limits.get('max_issues_per_gm', 4)),
                                 '--prior-ledger', str(self.ledger),
                                 '--protect', str(self.policy_path))
        if (self.values['runtime'].get('observe_archive_save', False)
                and self.save_path is not None and self.save_path.is_file()):
            command.extend(['--archive-save', str(self.save_path)])
        for gm_id in (self.selected_gms or []):
            command.extend(['--gm', gm_id])
        self.reserve(cycle, record, 'observe', estimate)
        per_gm_timeout = self.runner.get('timeout') or 900
        result = run_process(command, observe_batch_timeout(per_gm_timeout, estimate),
                             deadline=self.deadline)
        summary = last_json_line(result['stdout'])
        # Command exit provenance for this ONE gm_runner command. Nested codex probes can settle
        # with a nonzero exit after the runner itself finished, so the reconciled `exit_code`
        # alone must not turn a completed observation into observe_failed. Only the exact durable
        # receipt the runner wrote - bound to this pinned world and evidence, with every dispatch
        # settled ok and measured, the guards clean, no leak and no live child - may certify the
        # observation, and the nested exits stay in the record as evidence. Every other command
        # (host test commands, candidate coding) still fails on its own reconciled exit.
        carried = None
        if summary is not None and result['exit_code'] != 0:
            carried = observe_receipt_reference(self, summary, result)
        if summary is None:
            # The transport outcome is ambiguous. Keep the conservative reservation so an
            # interrupted batch is never counted as free, and never replayed.
            self.settle(cycle, record, None)
            observed_calls = None
        else:
            dispatched = summary.get('dispatched')
            observed_calls = (dispatched if isinstance(dispatched, int)
                              else len(summary.get('results') or []))
            self.settle(cycle, record, observed_calls)
        evidence = (summary or {}).get('evidence') or {}
        record.update({'run_id': (summary or {}).get('run_id'), 'exit_code': result['exit_code'],
                       'wrapper_exit_code': result.get('wrapper_exit_code'),
                       'exit_reconciled_from_member':
                           bool(result.get('exit_reconciled_from_member')),
                       'observed_nonzero_member_exits':
                           result.get('observed_nonzero_member_exits') or [],
                       'carried_receipt': carried,
                       'seconds': result['seconds'], 'dispatched': (summary or {}).get('dispatched'),
                       'model_calls_observed': observed_calls,
                       'owned': result.get('owned'), 'timed_out': result['timed_out'],
                       'evidence_sha256': evidence.get('sha256'),
                       'evidence_kind': evidence.get('kind'),
                       'world_binding': (summary or {}).get('world_binding'),
                       'unknown_cost_gms': (summary or {}).get('unknown_cost_gms'),
                       'stderr_tail': result['stderr'][-400:]})
        if summary is None or (result['exit_code'] != 0 and carried is None):
            record['status'] = 'failed'
            record['blocked_reason'] = (summary or {}).get('message') or 'gm_runner observe failed'
            self.save_cycle(cycle)
            kind = (summary or {}).get('kind')
            if kind in ('stale_source', 'world_binding_conflict', 'autonomy_world_mismatch'):
                return self.block(cycle, 'stale_or_wrong_world_source', STALE)
            if kind == 'unresolved_unknown_cost':
                return self.block(cycle, 'unresolved_unknown_cost', ACCOUNTING)
            if any((item or {}).get('cost') == 'unknown' for item in
                   ((summary or {}).get('results') or [])):
                return self.block(cycle, 'unknown_usage_stops_dispatch', ACCOUNTING)
            return self.block(cycle, 'observe_failed', RUNTIME)
        self.select_claim(cycle, record)
        self.finish_stage(cycle, 'observe', record,
                          'no_action' if record.get('no_action') else 'done')
        return OK

    def pre_dispatch_state_check(self, cycle: dict) -> int | None:
        """Do not spend again while a previous paid attempt is unresolved or ambiguous."""
        if not (self.state_dir / gm_runner.STATE_FILE).is_file():
            return None
        unknown = gm_runner.global_unknown_gms(gm_runner.load_state(self.state_dir))
        if unknown:
            return self.block(cycle, 'unresolved_unknown_cost:' + ','.join(unknown), ACCOUNTING)
        return None

    def select_claim(self, cycle: dict, record: dict) -> None:
        state = gm_runner.load_state(self.state_dir)
        run_id = record.get('run_id')
        claims = [issue for issue in state['issues'].values()
                  if issue.get('owner_run_id') == run_id and issue.get('owner_gm')
                  and issue.get('proposed_scope')]
        if not claims:
            record['no_action'] = True
            record['selection'] = ('no GM claimed a bounded scope in this observation; no_action '
                                   'preserved and nothing published')
            return
        claims.sort(key=lambda item: (item['owner_gm'], item['issue_id']))
        selected = claims[0]
        record['gm_id'] = selected['owner_gm']
        record['issue_id'] = selected['issue_id']
        record['observation_origin'] = (selected.get('provenance') or {}).get('observation_origin')
        record['proposed_scope'] = selected.get('proposed_scope')
        record['deferred_claims'] = [{'gm_id': item['owner_gm'], 'issue_id': item['issue_id']}
                                     for item in claims[1:]]
        cycle['deferred_claims'] = record['deferred_claims']
        cycle['gm_id'] = record['gm_id']
        cycle['issue_id'] = record['issue_id']
    # -- queued GM claims -----------------------------------------------------------

    def queued_claim_cycle(self) -> dict | None:
        """The earlier finished cycle whose deferred GM claims this evidence still owes.

        A cycle consumes ONE claimed issue and defers the rest, so the queue lives in the finished
        cycle's own durable record. Only a cycle over the SAME pinned policy and evidence can hand
        claims over, a source is never handed over twice, and the newest such source wins. The
        queue is rebuilt from cycle.json, not remembered in process memory.
        """
        root = self.autonomy_dir()
        if not root.is_dir():
            return None
        current = self.cycle_dir().name
        sources = []
        documents = []
        for path in sorted(root.glob('*/cycle.json')):
            document = gm_runner.load_json(path) if path.is_file() else None
            if not isinstance(document, dict) or not document.get('cycle_id'):
                continue
            documents.append(document)
        # A source that some other cycle already handed over from is spent, whatever order the
        # cycle directories sort in.
        consumed = {str(item['queued_from_cycle']) for item in documents
                    if item.get('queued_from_cycle')}
        for document in documents:
            cycle_id = str(document['cycle_id'])
            if cycle_id == current or cycle_id in consumed:
                continue
            if document.get('policy_sha256') != self.policy_sha:
                continue
            if document.get('evidence_sha256') != self.evidence_sha256:
                continue
            if document.get('status') not in ('completed', 'no_action'):
                continue
            if not document.get('deferred_claims'):
                continue
            sources.append(document)
        if not sources:
            return None
        sources.sort(key=lambda item: (str(item.get('updated_utc') or ''), str(item['cycle_id'])))
        return sources[-1]

    def resolve_queued_claim(self, pending: list) -> tuple:
        """Split a durable queued-claim list into (next claim, still queued, unresolvable).

        The original owner and issue provenance are preserved: an entry is only consumed when the
        SAME GM still owns that issue and it still carries a proposed scope. Anything else stays on
        disk as an honest unresolved entry instead of being silently dropped or re-attributed.
        """
        state = gm_runner.load_state(self.state_dir)
        issues = state.get('issues') or {}
        remaining = list(pending)
        skipped = []
        chosen = None
        for entry in pending:
            remaining = remaining[1:]
            issue = issues.get(entry.get('issue_id')) if isinstance(entry, dict) else None
            if (isinstance(issue, dict) and issue.get('owner_gm') == entry.get('gm_id')
                    and issue.get('proposed_scope')):
                chosen = issue
                break
            skipped.append(entry)
        return chosen, remaining, skipped

    def examine_queued_claims(self, cycle: dict, record: dict) -> int | None:
        """Resolve the observe stage from the durable queue instead of paying for another observe.

        Returns None when nothing is queued (a fresh observation is then allowed), and the observe
        status when the queue resolved this stage - including the honest no_action case where the
        queued claims no longer exist, which must not be answered with a fresh paid observation of
        unchanged evidence.
        """
        source = self.queued_claim_cycle()
        if source is None:
            return None
        pending = list(source.get('deferred_claims') or [])
        chosen, remaining, skipped = self.resolve_queued_claim(pending)
        record['queued_from_cycle'] = source['cycle_id']
        # The hand-over is recorded on the cycle itself, so the same source is never handed to a
        # second cycle and a resumed cycle does not consume its own queue twice.
        cycle['queued_from_cycle'] = source['cycle_id']
        record['queued_pending'] = len(pending)
        record['queued_unresolvable'] = skipped
        record['deferred_claims'] = remaining
        cycle['deferred_claims'] = remaining
        if chosen is None:
            record['no_action'] = True
            record['observation_origin'] = 'queued_claim_unresolvable'
            record['selection'] = ('every queued GM claim for this evidence no longer resolves to '
                                   'an owned issue with a proposed scope; no new observation is '
                                   'bought for unchanged evidence and nothing is published')
            self.finish_stage(cycle, 'observe', record, 'no_action')
            return OK
        record.update({'gm_id': chosen.get('owner_gm'), 'issue_id': chosen.get('issue_id'),
                       'proposed_scope': chosen.get('proposed_scope'),
                       'queued_owner_run_id': chosen.get('owner_run_id'),
                       'observation_origin': (chosen.get('provenance') or {}).get(
                           'observation_origin'),
                       'selection': ('selected the next queued GM-owned claim from cycle '
                                     + str(source['cycle_id']) + ' without a new observation of '
                                     'unchanged evidence')})
        cycle['gm_id'] = record['gm_id']
        cycle['issue_id'] = record['issue_id']
        self.finish_stage(cycle, 'observe', record, 'done')
        return OK

    def stage_candidate(self, cycle: dict) -> int:
        record = self.stage_record(cycle, 'candidate')
        if record['status'] == 'done':
            return OK
        stopped = self.in_flight_stop(cycle, record, 'candidate')
        if stopped:
            return stopped
        observe = cycle['stages'].get('observe') or {}
        issue_id, gm_id = observe.get('issue_id'), observe.get('gm_id')
        if not issue_id:
            record.update({'status': 'skipped', 'reason': 'no claimed issue to implement'})
            self.save_cycle(cycle)
            return OK
        scope, errors = validate_proposed_scope(observe.get('proposed_scope'), self.policy)
        if errors or scope is None:
            record.update({'status': 'refused', 'policy_errors': errors,
                           'proposed_scope': observe.get('proposed_scope')})
            cycle['declined'].append({'issue_id': issue_id, 'gm_id': gm_id, 'errors': errors})
            self.save_cycle(cycle)
            return self.block(cycle, 'scope_rejected_by_policy', PRECONDITION)
        previous = record.get('derived_scope')
        prior_attempts = list(record.get('attempts') or [])
        # Attempt counters survive a reopened repair round: the bound is per issue, not per round.
        carried_attempts = int((cycle.get('carried_attempts') or {}).get(issue_id, 0))
        base_revision = self.policy.get('base_revision') or gm_runner.git(
            ['rev-parse', 'HEAD']).stdout.strip()
        scope_file = self.cycle_dir() / 'scope.json'
        # Round-specific candidate identity: a reopened round gets its OWN checkout derived from
        # the pinned base, so the failed candidate's bytes stay on disk as immutable, independently
        # reviewable evidence instead of being deleted to make room for the repair. Re-running the
        # same round resumes the same directory; nothing is deleted or recreated on resume.
        repair_rounds = int(cycle.get('repair_rounds', 0))
        candidate = self.state_dir / 'candidates' / (
            issue_id if repair_rounds == 0 else f'{issue_id}-r{repair_rounds}')
        placeholder = {'root': ROOT, 'candidate': candidate, 'scope_file': scope_file,
                       'policy_file': self.policy_path, 'evidence': self.evidence}
        commands = []
        for command in self.policy.get('required_test_commands') or []:
            resolved, command_errors = resolve_command(command, placeholder)
            if command_errors:
                record.update({'status': 'refused', 'policy_errors': command_errors})
                self.save_cycle(cycle)
                return self.block(cycle, 'host_test_command_invalid', USAGE)
            commands.append(resolved)
        scope_document = {'issue_id': issue_id, 'owner_gm': gm_id, 'base_revision': base_revision,
                          'objective': scope['objective'], 'files': scope['files'],
                          'acceptance': scope['acceptance'], 'test_commands': commands,
                          'review_state': 'unapproved', 'source': 'gm_proposed_host_derived',
                          'gm_self_test_required': True}
        if 'design_review' in scope:
            scope_document['design_review'] = scope['design_review']
            scope_document['design_contract'] = self.policy['design_contract']
        gm_runner.save_json(scope_file, scope_document)
        isolation = str((self.policy.get('deployment') or {}).get('candidate_isolation')
                        or 'git_worktree')
        if isolation == 'sparse_alternates' and not candidate.exists():
            failure = self.provision_sparse_candidate(candidate, base_revision)
            if failure:
                record.update({'status': 'failed', 'blocked_reason': failure})
                self.save_cycle(cycle)
                return self.block(cycle, 'candidate_isolation_failed', PRECONDITION)
        record.update({'scope_file': gm_runner.relative(scope_file),
                       'scope_sha256': sha256_file(scope_file), 'derived_scope': scope_document,
                       'base_revision': base_revision, 'candidate': gm_runner.relative(candidate),
                       'candidate_abs': str(candidate), 'host_test_commands': commands,
                       'attempts_carried': carried_attempts,
                       'host_owned_before': self.host_owned_hashes()})
        if previous == scope_document:
            record['attempts'] = prior_attempts
        else:
            record['attempts'] = []
        self.save_cycle(cycle)
        while True:
            blocked = self.dispatch_budget(cycle, 'code', 1)
            if blocked:
                return self.stop(cycle, record, blocked)
            attempt = carried_attempts + len(record['attempts']) + 1
            if attempt > int(self.limits['max_attempts_per_issue']):
                return self.block(cycle, 'max_attempts_per_issue reached without passing host tests',
                                  RUNTIME)
            command = runner_command(self.runner, 'code', '--state-dir', str(self.state_dir),
                                     '--issue', issue_id, '--scope-file', str(scope_file),
                                     '--base-revision', base_revision, '--candidate', str(candidate),
                                     '--protect', str(self.policy_path),
                                     '--protect', str(self.evidence))
            self.reserve(cycle, record, 'code', 1)
            result = run_process(command, self.runner.get('timeout') or 900, deadline=self.deadline)
            cycle['attempts'][issue_id] = attempt
            summary = last_json_line(result['stdout'])
            status = (summary or {}).get('status')
            failures = [test.get('exit_code') for test in ((summary or {}).get('scope_tests') or [])
                        if test.get('exit_code') != 0]
            self.settle(cycle, record, 1 if summary is not None else None)
            record['attempts'].append({'attempt': attempt, 'run_id': (summary or {}).get('run_id'),
                                       'status': status, 'exit_code': result['exit_code'],
                                       'usage_measured': (summary or {}).get('usage_measured'),
                                       'scope_test_failures': failures,
                                       'owned': result.get('owned'),
                                       'seconds': result['seconds']})
            if summary is None:
                record['status'] = 'failed'
                record['blocked_reason'] = 'gm_runner code produced no summary'
                self.save_cycle(cycle)
                return self.block(cycle, 'code_failed_no_summary', RUNTIME)
            if status == 'ok':
                claims = summary.get('worker_claims') or {}
                self_test = claims.get('test_results')
                if self_test is None:
                    self_test = (summary.get('worker_answer') or {}).get('test_results')
                record.update({'status': 'done', 'candidate_run_id': summary.get('run_id'),
                               'candidate_head': summary.get('candidate_head'),
                               'changed_files': summary.get('observed_changed_files'),
                               'scope_tests': summary.get('scope_tests'),
                               'gm_self_test': {'reported': self_test is not None,
                                                'result': self_test,
                                                'ok': (None if self_test is None else
                                                       bool(self_test) and all(
                                                           item.get('ok', item.get('exit_code') == 0)
                                                           for item in self_test
                                                           if isinstance(item, dict)))}})
                self.finish_stage(cycle, 'candidate', record)
                return OK
            if status in REPAIRABLE:
                # A GM-reported self-test/scope failure is evidence for the main-AI review.  It
                # must not trigger an unconditional second coding turn or an extra acknowledgement
                # call; the owner will inspect it on the next ordinary turn if a repair is needed.
                if not summary.get('usage_measured'):
                    return self.block(cycle, 'coding_failure_with_unknown_usage', ACCOUNTING)
                if summary.get('candidate') or summary.get('observed_changed_files'):
                    claims = summary.get('worker_claims') or {}
                    self_test = claims.get('test_results')
                    record.update({'status': 'done', 'candidate_run_id': summary.get('run_id'),
                                   'candidate_head': summary.get('candidate_head'),
                                   'changed_files': summary.get('observed_changed_files'),
                                   'scope_tests': summary.get('scope_tests'),
                                   'coder_status': status,
                                   'gm_self_test': {'reported': True, 'ok': False,
                                                    'result': self_test or summary.get('scope_tests')}})
                    self.finish_stage(cycle, 'candidate', record)
                    return OK
                return self.block(cycle, 'coding_' + str(status), RUNTIME)
            if status == 'refused' and (summary or {}).get('kind') in (
                    'unresolved_unknown_cost', 'unresolved_coding_attempt', 'owner_gm_unresolved'):
                return self.block(cycle, 'unresolved_accounting_before_retry', ACCOUNTING)
            record['status'] = 'failed'
            record['blocked_reason'] = 'coding ended as ' + str(status)
            self.save_cycle(cycle)
            return self.block(cycle, 'coding_' + str(status), RUNTIME)

    def host_owned_hashes(self) -> dict:
        paths = list(self.policy.get('host_owned_paths') or [])
        if world_design_contract.required(self.policy):
            paths = sorted(set(paths) | set(world_design_contract.PROTECTED))
        return {path: sha256_file(ROOT / path)
                for path in paths}

    def provision_sparse_candidate(self, candidate: Path, base_revision: str) -> str | None:
        """Opt-in candidate isolation for hosts whose development .git is read-only.

        The normal path is gm_runner's own `git worktree add`. Some restricted hosts cannot write
        .git/worktrees and block git's local transport shell. In that case this builds an isolated
        repository inside the state directory whose object store only *reads* the approved
        checkout through an alternates file, with a sparse checkout limited to the allowed source
        paths. gm_runner still re-verifies that the candidate is its own checkout at exactly
        base_revision, and the coder still cannot reach the development checkout.
        """
        candidate.mkdir(parents=True, exist_ok=True)
        environment = dict(os.environ)
        environment['GIT_LFS_SKIP_SMUDGE'] = '1'

        def invoke(argv):
            return subprocess.run(argv, capture_output=True, text=True, encoding='utf-8',
                                  errors='replace', env=environment, timeout=600)

        initialized = invoke(['git', 'init', '--quiet', str(candidate)])
        if initialized.returncode != 0:
            return 'candidate_init_failed: ' + initialized.stderr.strip()[-300:]
        object_store_result = invoke(['git', '-C', str(ROOT), 'rev-parse', '--git-path', 'objects'])
        if object_store_result.returncode != 0:
            return 'candidate_object_store_failed: ' + object_store_result.stderr.strip()[-300:]
        object_store_text = object_store_result.stdout.strip()
        if not object_store_text:
            return 'candidate_object_store_failed: git returned an empty object-store path'
        object_store = Path(object_store_text)
        if not object_store.is_absolute():
            object_store = ROOT / object_store
        try:
            object_store = object_store.resolve(strict=True)
        except OSError as error:
            return 'candidate_object_store_unavailable: ' + str(error)[-300:]
        if not object_store.is_dir():
            return 'candidate_object_store_unavailable: resolved path is not a directory'
        alternates = candidate / '.git' / 'objects' / 'info' / 'alternates'
        alternates.parent.mkdir(parents=True, exist_ok=True)
        alternates.write_text(str(object_store).replace('\\', '/'), encoding='utf-8')
        directories = []
        if world_design_contract.required(self.policy):
            directories.extend(sorted({str(Path(rel).parent).replace('\\', '/')
                                       for rel in world_design_contract.DOCUMENTS}))
        for pattern in (self.policy.get('scope_constraints') or {}).get('allowed_source_paths', []):
            directory = pattern[:-3].strip('/') if pattern.endswith('/**') else pattern.strip('/')
            if directory and directory not in directories:
                directories.append(directory)
        if directories:
            sparse = invoke(['git', '-C', str(candidate), 'sparse-checkout', 'set', *directories])
            if sparse.returncode != 0:
                return 'sparse_checkout_failed: ' + sparse.stderr.strip()[-300:]
        checkout = invoke(['git', '-C', str(candidate), 'checkout', '--detach', base_revision])
        if checkout.returncode != 0:
            return 'candidate_checkout_failed: ' + checkout.stderr.strip()[-300:]
        head = gm_runner.git(['rev-parse', 'HEAD'], cwd=candidate)
        if head.stdout.strip() != base_revision:
            return 'candidate_base_mismatch after sparse provision'
        return None
    def stage_validate(self, cycle: dict) -> int:
        record = self.stage_record(cycle, 'validate')
        if record['status'] == 'done':
            return OK
        candidate_record = cycle['stages'].get('candidate') or {}
        if candidate_record.get('status') != 'done':
            record.update({'status': 'skipped', 'reason': 'no completed candidate'})
            self.save_cycle(cycle)
            return OK
        candidate = Path(candidate_record['candidate_abs'])
        base = candidate_record['base_revision']
        scope_files = candidate_record['derived_scope']['files']
        checks = []
        if world_design_contract.required(self.policy):
            design_errors = world_design_contract.policy_errors(self.policy, candidate)
            design_errors.extend(world_design_contract.scope_errors(
                candidate_record['derived_scope'], self.policy))
            checks.append({'check': 'aincrad_design_contract', 'ok': not design_errors,
                           'detail': design_errors})
        head = gm_runner.git(['rev-parse', 'HEAD'], cwd=candidate)
        checks.append({'check': 'candidate_head_is_base', 'ok': head.stdout.strip() == base,
                       'detail': head.stdout.strip()})
        status = gm_runner.git(['status', '--porcelain', '-z', '--untracked-files=all'],
                               cwd=candidate)
        observed = gm_runner.normalize_status_paths(status.stdout) if status.returncode == 0 else None
        out_of_scope = [] if observed is None else [path for path in observed
                                                    if path not in scope_files]
        checks.append({'check': 'candidate_changes_within_scope',
                       'ok': observed is not None and not out_of_scope,
                       'detail': {'observed': observed, 'out_of_scope': out_of_scope}})
        host_after = self.host_owned_hashes()
        checks.append({'check': 'host_owned_paths_unchanged',
                       'ok': host_after == candidate_record['host_owned_before'],
                       'detail': host_after})
        hashes = {entry: (sha256_file(candidate / entry) if (candidate / entry).is_file() else None)
                  for entry in scope_files}
        checks.append({'check': 'scope_files_exist', 'ok': all(hashes.values()), 'detail': hashes})
        # Required host commands are retained as policy evidence, but are no longer an
        # acceptance gate and are never re-run here.  The GM's own report is the self-test
        # evidence handed to the main AI; static ownership/scope checks remain host safety gates.
        checks.append({'check': 'host_test_commands_pass', 'ok': None,
                       'detail': {'commands': candidate_record.get('host_test_commands') or [],
                                  'executed': False,
                                  'reason': 'fixed host tests are advisory evidence only'}})
        self_test = candidate_record.get('gm_self_test')
        checks.append({'check': 'gm_self_test_reported',
                       'ok': isinstance(self_test, dict) and self_test.get('reported') is True,
                       'detail': self_test})
        safety_checks = [check for check in checks
                         if check['check'] not in ('host_test_commands_pass',
                                                   'gm_self_test_reported')]
        record.update({'checks': checks, 'file_hashes': hashes,
                       'ok': all(check['ok'] is True for check in safety_checks),
                       'publish_ready': all(check['ok'] is True for check in safety_checks),
                       'gm_self_test': self_test})
        self.save_cycle(cycle)
        if not record['ok']:
            record['status'] = 'failed'
            cycle['declined'].append({'issue_id': cycle.get('issue_id'), 'stage': 'validate',
                                      'failed_checks': [c['check'] for c in checks
                                                        if c['ok'] is False
                                                        and c['check'] not in (
                                                            'host_test_commands_pass',
                                                            'gm_self_test_reported')]})
            self.save_cycle(cycle)
            return self.block(cycle, 'candidate_safety_gate_failed', PRECONDITION)
        self.finish_stage(cycle, 'validate', record)
        return OK

    def stale_release_binding(self, cycle: dict) -> str | None:
        """Compare the LIVE policy, pinned trial base and host-owned script bytes to the digests
        pinned when this cycle started.

        The in-memory self.policy_sha is not evidence: it was cached when this process built the
        cycle, so comparing it to the cached cycle.policy_sha256 would miss an edit made on disk
        between the host gate and the release. Every value here is re-read from disk now, and a
        missing pin is refused rather than silently re-granted to a reopened repair or restarted
        process.
        """
        pinned_policy = cycle.get('policy_sha256')
        live_policy = file_digest_or_none(self.policy_path)
        if not pinned_policy:
            return 'this cycle pins no standing-policy digest; refusing to release'
        if live_policy != pinned_policy:
            return (f'the standing policy changed on disk after this cycle started '
                    f'({pinned_policy} -> {live_policy}); refusing to release')
        pinned_base = cycle.get('base_manifest_sha256')
        if not pinned_base:
            return ('this cycle pins no base-manifest digest; refusing to release rather than '
                    'granting a fresh baseline to a reopened cycle')
        live_base = file_digest_or_none(self.base_manifest)
        if live_base != pinned_base:
            return (f'the declared trial base manifest changed after this cycle started '
                    f'({pinned_base} -> {live_base}); refusing to release')
        pinned_host = cycle.get('host_owned_pinned')
        # An empty host-owned set is valid for a self-testing candidate.  Only an absent pin is
        # legacy/corrupt state; do not turn the optional host contract into a release gate.
        if pinned_host is None:
            return 'this cycle has no host-owned digest pin; refusing to release'
        if self.host_owned_hashes() != pinned_host:
            return ('a host-owned test or host script changed after this cycle started; '
                    'refusing to release')
        return None

    def stage_review(self, cycle: dict) -> int:
        """Consume the explicit main-AI opinion for this exact GM candidate.

        This is a durable hand-off, not a user approval prompt and not a provider dispatch.  An
        absent review leaves the cycle resumable in ``waiting_review``; a normal advisory review
        permits publication even when the GM's self-test reports a failure.  Only a concrete
        major problem blocks delivery.
        """
        record = self.stage_record(cycle, 'review')
        if record.get('status') == 'done':
            return OK
        review = self.load_main_ai_review(cycle)
        if review is None:
            record.update({'status': 'waiting_review', 'review_state': 'pending',
                           'candidate_sha256': self.candidate_version_sha(cycle),
                           'reason': 'explicit main-AI review artifact is required before release'})
            self.save_cycle(cycle)
            return OK
        normalized, errors = self.validate_main_ai_review(cycle, review)
        if errors:
            record.update({'status': 'refused', 'review_state': 'invalid', 'errors': errors})
            self.save_cycle(cycle)
            return self.block(cycle, 'main_ai_review_invalid', PRECONDITION)
        cycle['main_ai_review'] = normalized
        record.update({'status': 'blocked' if normalized['decision'] == 'major_block' else 'done',
                       'review_state': normalized['decision'], 'review': normalized,
                       'candidate_sha256': normalized['candidate_sha256']})
        self.remember_main_ai_review(cycle, normalized, record)
        self.save_cycle(cycle)
        if normalized['decision'] == 'major_block':
            cycle['blocked_reason'] = 'main_ai_major_block'
            self.save_cycle(cycle)
            return self.block(cycle, 'main_ai_major_block', PRECONDITION)
        return OK

    def remember_main_ai_review(self, cycle: dict, review: dict, record: dict) -> None:
        """Deliver the durable review handoff to the owning GM's next coding prompt."""
        gm_id = cycle.get('gm_id')
        if not gm_id:
            record['memory_delivery'] = 'no_owner'
            return
        event = {'kind': 'main_ai_review',
                 'run_id': 'review-' + str(cycle.get('cycle_id')) + '-' +
                           str(review.get('candidate_sha256')),
                 'cycle_id': cycle.get('cycle_id'), 'issue_id': cycle.get('issue_id'),
                 'candidate_sha256': review.get('candidate_sha256'),
                 'source': review.get('source'), 'decision': review.get('decision'),
                 'suggestions': list(review.get('suggestions') or []),
                 'rationale': review.get('rationale') or review.get('summary') or '',
                 'major_problem': review.get('major_problem') or review.get('problem') or '',
                 'repair_required': review.get('decision') == 'major_block',
                 'received_utc': review.get('reviewed_utc') or gm_runner.utc_iso()}
        try:
            state = gm_runner.load_state(self.state_dir)
            owner = (state.get('sessions') or {}).get(gm_id)
            if not isinstance(owner, dict):
                raise ValueError('owning GM session is absent')
            gm_runner.remember_gm_task(owner, gm_id, event)
            gm_runner.store_state(self.state_dir, state)
            record['memory_delivery'] = 'stored'
        except (OSError, ValueError, KeyError) as error:
            # Keep the review durable in cycle.json and expose the failed memory handoff; the
            # caller must not synthesize a provider retry or an approval from this failure.
            record.update({'memory_delivery': 'pending_state_unavailable',
                           'memory_delivery_error': str(error)})

    def stage_publish(self, cycle: dict) -> int:
        record = self.stage_record(cycle, 'publish')
        if record.get('status') == 'done':
            return OK
        if world_design_contract.required(self.policy):
            candidate_record = cycle.get('stages', {}).get('candidate') or {}
            candidate = Path(candidate_record.get('candidate_abs') or ROOT)
            design_errors = world_design_contract.policy_errors(self.policy, candidate)
            design_errors.extend(world_design_contract.scope_errors(
                candidate_record.get('derived_scope') or {}, self.policy))
            if design_errors:
                record.update({'status': 'refused', 'design_errors': design_errors})
                self.save_cycle(cycle)
                return self.block(cycle, 'aincrad_design_contract_changed', PRECONDITION)
        validate = cycle['stages'].get('validate') or {}
        review = cycle['stages'].get('review') or {}
        if review.get('status') != 'done':
            record.update({'status': 'skipped', 'reason': 'main-AI review not complete'})
            self.save_cycle(cycle)
            return OK
        if not validate.get('publish_ready', validate.get('ok', False)):
            record.update({'status': 'skipped', 'reason': 'candidate safety checks not passed'})
            self.save_cycle(cycle)
            return OK
        if int(self.limits['max_publishes']) < 1:
            record.update({'status': 'skipped', 'reason': 'max_publishes=0'})
            self.save_cycle(cycle)
            return OK
        # The publication bound is cumulative over the cycle, not per repair round: a policy that
        # allows one release must stop a reopened round from releasing a second time. A publish
        # intent journal left by a crash is still completed idempotently instead of being refused.
        publishes_done = int(cycle.get('publishes_total', 0))
        if (publishes_done >= int(self.limits['max_publishes'])
                and not self.publish_journal_path().is_file()):
            record.update({'status': 'refused', 'publishes_total': publishes_done,
                           'reason': (f'max_publishes={self.limits["max_publishes"]} is already '
                                      f'spent by {publishes_done} completed release(s); this round '
                                      'may not publish again')})
            self.save_cycle(cycle)
            return self.block(cycle, 'max_publishes_reached', PRECONDITION)
        root = ROOT.resolve()
        checkout = self.checkout.resolve()
        disposable = root / 'tmp'
        inside_disposable = checkout == disposable or disposable in checkout.parents
        if checkout == root or (root in checkout.parents and not inside_disposable):
            record.update({'status': 'refused',
                           'reason': 'trial checkout must be outside the development checkout or '
                                     'inside its ignored tmp/ area'})
            self.save_cycle(cycle)
            return self.block(cycle, 'deployment_checkout_inside_dev_checkout', PRECONDITION)
        if (checkout / '.git').is_file():
            record.update({'status': 'refused',
                           'reason': 'trial checkout shares the development checkout git metadata'})
            self.save_cycle(cycle)
            return self.block(cycle, 'deployment_checkout_shares_dev_git', PRECONDITION)
        stale = self.stale_release_binding(cycle)
        if stale:
            record.update({'status': 'refused', 'reason': stale})
            self.save_cycle(cycle)
            return self.block(cycle, 'release_binding_stale', UNACCEPTABLE)
        base = gm_runner.load_json(self.base_manifest)
        declared = base.get('files') if isinstance(base, dict) else None
        if not isinstance(declared, dict):
            record.update({'status': 'refused', 'reason': 'base manifest must hold a files object'})
            self.save_cycle(cycle)
            return self.block(cycle, 'base_manifest_invalid', UNACCEPTABLE)
        # A second intentional release by this same owner compares against its own last accepted
        # release bytes, not only the pinned base manifest. Owned bytes may be replaced; bytes
        # that are neither the owned prior release nor the pinned base still refuse.
        declared = dict(declared)
        declared.update(self.accepted_release_base(cycle))
        path_map = self.policy['deployment']['path_map']
        scope_files = list(validate['file_hashes'].keys())
        release_limit = int((self.policy.get('deployment') or {}).get(
            'max_files_per_release', RELEASE_FILES_THIS_VERSION))
        if not 1 <= len(scope_files) <= min(release_limit, RELEASE_FILES_THIS_VERSION):
            record.update({'status': 'refused', 'reason': (
                f'this release supports 1..{min(release_limit, RELEASE_FILES_THIS_VERSION)} '
                f'files; the candidate validated {len(scope_files)}')})
            self.save_cycle(cycle)
            return self.block(cycle, 'release_file_count_out_of_bounds', PRECONDITION)
        candidate_record = cycle['stages'].get('candidate') or {}
        candidate_root = Path(candidate_record['candidate_abs']).resolve()
        prepared = []
        for rel in scope_files:
            digest = validate['file_hashes'][rel]
            source_rel = safe_relpath(rel)
            if source_rel in (None, ''):
                record.update({'status': 'refused', 'reason': f'source {rel!r} is not a plain '
                               'repo-relative path'})
                self.save_cycle(cycle)
                return self.block(cycle, 'release_source_escape', PRECONDITION)
            source = (candidate_root / source_rel).resolve()
            if source == candidate_root or not is_within(source, candidate_root):
                record.update({'status': 'refused',
                               'reason': f'candidate source {rel!r} escapes the candidate'})
                self.save_cycle(cycle)
                return self.block(cycle, 'release_source_escape', PRECONDITION)
            if not source.is_file():
                record.update({'status': 'refused', 'reason': f'candidate source {rel!r} is absent'})
                self.save_cycle(cycle)
                return self.block(cycle, 'release_source_escape', PRECONDITION)
            payload = source.read_bytes()
            if sha256_bytes(payload) != digest:
                record.update({'status': 'refused',
                               'reason': f'candidate bytes for {rel!r} changed after the host gate'})
                self.save_cycle(cycle)
                return self.block(cycle, 'candidate_bytes_changed_after_gate', UNACCEPTABLE)
            target_rel = deployment_target(rel, path_map)
            if target_rel is None or safe_relpath(target_rel) is None:
                record.update({'status': 'refused',
                               'reason': f'no safe deployment mapping for {rel!r}'})
                self.save_cycle(cycle)
                return self.block(cycle, 'release_target_escape', PRECONDITION)
            prepared.append({'source': rel, 'target': safe_relpath(target_rel), 'sha256': digest,
                             'payload': payload, 'absolute': checkout / safe_relpath(target_rel)})
        release_digest = sha256_bytes(json.dumps(
            sorted([[entry['target'], entry['sha256']] for entry in prepared]),
            sort_keys=True).encode())
        binding = {'policy_sha256': self.policy_sha, 'base_manifest_sha256':
                   sha256_file(self.base_manifest), 'host_owned_hashes': self.host_owned_hashes(),
                   'candidate_base_revision': candidate_record.get('base_revision'),
                   'gate_ok': bool(validate.get('ok'))}
        pinned_host = candidate_record.get('host_owned_before') or {}
        if self.policy_sha != cycle.get('policy_sha256') or self.host_owned_hashes() != pinned_host:
            record.update({'status': 'refused',
                           'reason': 'the pinned policy or host-owned hashes changed before '
                                     'release'})
            self.save_cycle(cycle)
            return self.block(cycle, 'release_pinned_binding_drift', UNACCEPTABLE)
        recovered = self.recover_publish(cycle, record, checkout, prepared, declared,
                                         release_digest, binding)
        if recovered is not None:
            return recovered
        return self.execute_publish(cycle, record, checkout, prepared, declared, release_digest,
                                    binding)

    def owned_release_bytes(self, cycle: dict) -> dict:
        """Targets this same owned cycle already released, with their accepted bytes.

        A second intentional release is compared against the previous owned release bytes, not
        only the pinned (possibly empty) base manifest, so the same owner may replace its own
        last release while a third party's drift is still refused. The pinned base manifest file
        itself is never rewritten."""
        owned = {}
        sources = [cycle.get('release') or {}]
        sources += [((record.get('previous_stages') or {}).get('publish') or {})
                    for record in (cycle.get('repair_history') or [])]
        for source in sources:
            for item in source.get('files') or []:
                target, digest = item.get('target'), item.get('sha256')
                if target and digest:
                    owned[target] = digest
        return owned

    def queued_source_cycle_documents(self, cycle: dict) -> list:
        """Walk the durable queued_from_cycle hand-over chain of this cycle's sources."""
        documents = []
        seen = set()
        current = cycle.get('queued_from_cycle')
        root = self.autonomy_dir()
        while current and str(current) not in seen:
            seen.add(str(current))
            path = root / str(current) / 'cycle.json'
            if not path.is_file():
                break
            document = gm_runner.load_json(path)
            if not isinstance(document, dict):
                break
            documents.append(document)
            current = document.get('queued_from_cycle')
        return documents

    def accepted_release_base(self, cycle: dict) -> dict:
        """The bytes this cycle may intentionally replace: its own prior release plus the
        ACCEPTED release bytes of the earlier cycle whose queued GM claim it took over. A source
        release only counts after its own verification passed, so a third party's unreviewed
        drift is still refused and the pinned base manifest file is never rewritten."""
        owned = self.owned_release_bytes(cycle)
        for document in self.queued_source_cycle_documents(cycle):
            stages = document.get('stages') or {}
            publish = stages.get('publish') or {}
            verify = stages.get('verify') or {}
            if publish.get('status') != 'done' or not verify.get('ok'):
                continue
            for item in publish.get('files') or []:
                target, digest = item.get('target'), item.get('sha256')
                if target and digest:
                    owned.setdefault(target, digest)
        return owned

    def publish_journal_path(self) -> Path:
        return self.cycle_dir() / 'publish-intent.json'

    def finish_publish(self, cycle: dict, record: dict, prepared: list, checkout: Path,
                       release_digest: str, binding: dict) -> int:
        receipt = {'schema_version': 1, 'cycle_id': cycle['cycle_id'],
                   'release_digest': release_digest,
                   'files': [{'source': entry['source'], 'target': entry['target'],
                              'sha256': entry['sha256'], 'bytes': len(entry['payload']),
                              'previous_sha256': entry.get('previous_sha256')}
                             for entry in prepared],
                   'checkout': gm_runner.relative(checkout), 'binding': binding,
                   'published_utc': gm_runner.utc_iso()}
        # Counted only when the release really completed, so a refused or crashed attempt is not
        # charged and a repaired round cannot silently publish past the policy bound.
        cycle['publishes_total'] = int(cycle.get('publishes_total', 0)) + 1
        record.update({'status': 'done', 'files': receipt['files'],
                       'release_digest': release_digest,
                       'publishes_total': cycle['publishes_total'],
                       'checkout': gm_runner.relative(checkout),
                       'base_manifest_sha256': binding['base_manifest_sha256'],
                       'publish_receipt': receipt, 'published_utc': receipt['published_utc']})
        cycle['release'] = {'digest': release_digest, 'files': receipt['files'],
                            'checkout': gm_runner.relative(checkout)}
        # Persist the completed receipt BEFORE removing the intent journal: a crash in between
        # must leave either the journal (safe, idempotent recovery) or the receipt, never neither.
        self.finish_stage(cycle, 'publish', record)
        try:
            self.publish_journal_path().unlink()
        except OSError:
            pass
        return OK

    def execute_publish(self, cycle: dict, record: dict, checkout: Path, prepared: list,
                        declared: dict, release_digest: str, binding: dict) -> int:
        """Install the immutable validated bytes exactly once, under the owner-identified
        installation lock, rechecking the declared trial base while that lock is held."""
        with self.installation_lock() as lock:
            if lock.recovered:
                record['recovered_install_lock'] = lock.recovered
            conflicts = []
            for entry in prepared:
                target = entry['absolute']
                escape = reparse_escape(target, checkout)
                if escape:
                    conflicts.append({'file': entry['target'], 'reason': escape})
                    continue
                current = sha256_file(target) if target.is_file() else None
                entry['original_sha256'] = current
                entry['written_this_attempt'] = False
                if current == entry['sha256']:
                    continue  # already installed by this same release; idempotent
                if declared.get(entry['target']) != current:
                    conflicts.append({'file': entry['target'],
                                      'reason': 'trial base drifted from the declared manifest; '
                                                'refusing to overwrite another writer',
                                      'declared': declared.get(entry['target']),
                                      'current': current})
                    continue
                entry['previous_sha256'] = current
            if conflicts:
                record.update({'status': 'refused', 'conflicts': conflicts})
                self.save_cycle(cycle)
                return self.block(cycle, 'release_conflict', PRECONDITION)
            journal = {'schema_version': 1, 'cycle_id': cycle['cycle_id'],
                       'release_digest': release_digest, 'binding': binding,
                       'files': [{'source': entry['source'], 'target': entry['target'],
                                  'sha256': entry['sha256'],
                                 'previous_sha256': entry.get('previous_sha256')}
                                 for entry in prepared],
                       'written_utc': gm_runner.utc_iso()}
            backup_root = self.cycle_dir() / 'publish-backup'
            backup_root.mkdir(parents=True, exist_ok=True)
            for index, entry in enumerate(prepared):
                target = entry['absolute']
                if target.is_file() and sha256_file(target) != entry['sha256']:
                    backup = backup_root / f'{index:02d}.bin'
                    backup.write_bytes(target.read_bytes())
                    entry['backup_path'] = str(backup)
                    journal['files'][index]['backup_path'] = gm_runner.relative(backup)
                journal['files'][index]['original_sha256'] = entry.get('original_sha256')
            gm_runner.save_json(self.publish_journal_path(), journal)
            record['publish_intent'] = {'release_digest': release_digest,
                                        'files': journal['files'],
                                        'written_utc': journal['written_utc']}
            self.save_cycle(cycle)
            try:
                for entry in prepared:
                    target = entry['absolute']
                    if target.is_file() and sha256_file(target) == entry['sha256']:
                        continue
                    target.parent.mkdir(parents=True, exist_ok=True)
                    temporary = target.with_name(target.name + '.autonomy-new')
                    temporary.write_bytes(entry['payload'])
                    if sha256_file(temporary) != entry['sha256']:
                        temporary.unlink(missing_ok=True)
                        raise OSError('staged_bytes_mismatch')
                    # Mark before the atomic replace: a crash/error immediately after the OS
                    # call may leave the target changed even though the call raised to Python.
                    entry['written_this_attempt'] = True
                    os.replace(str(temporary), str(target))
                    if sha256_file(target) != entry['sha256']:
                        raise OSError('published_bytes_mismatch')
            except OSError as error:
                for entry in prepared:
                    target = entry['absolute']
                    backup = Path(entry['backup_path']) if entry.get('backup_path') else None
                    try:
                        if not entry.get('written_this_attempt'):
                            continue
                        if backup and backup.is_file():
                            os.replace(str(backup), str(target))
                        elif (entry.get('original_sha256') is None and target.is_file()
                              and sha256_file(target) == entry['sha256']):
                            target.unlink()
                    except OSError:
                        pass
                reason = str(error)
                self.save_cycle(cycle)
                return self.block(cycle, reason if reason in ('staged_bytes_mismatch',
                                                               'published_bytes_mismatch')
                                  else 'publish_transaction_failed', RUNTIME)
        return self.finish_publish(cycle, record, prepared, checkout, release_digest, binding)

    def recover_publish(self, cycle: dict, record: dict, checkout: Path, prepared: list,
                        declared: dict, release_digest: str, binding: dict):
        """Idempotent recovery when the process died between the replace and the receipt.
        Never rolls world history back and never replays a completed publication."""
        journal = self.publish_journal_path()
        if record.get('publish_receipt') and record.get('release_digest') == release_digest:
            try:
                journal.unlink()
            except OSError:
                pass
            self.finish_stage(cycle, 'publish', record)
            cycle['release'] = {'digest': release_digest, 'files': record.get('files'),
                                'checkout': gm_runner.relative(checkout)}
            return OK
        if not journal.is_file():
            return None
        prior = gm_runner.load_json(journal)
        if (not isinstance(prior, dict) or prior.get('release_digest') != release_digest
                or len(prior.get('files') or []) != len(prepared)):
            record.update({'status': 'refused', 'reason': 'an unfinished publication journal '
                           'exists for a different release; refusing to mix releases'})
            self.save_cycle(cycle)
            return self.block(cycle, 'publish_journal_conflict', PRECONDITION)
        states = []
        for entry in prepared:
            current = sha256_file(entry['absolute']) if entry['absolute'].is_file() else None
            states.append((entry, current))
            if current not in (entry['sha256'], declared.get(entry['target'])):
                record.update({'status': 'refused',
                               'reason': 'a trial target holds bytes from neither the declared '
                                         'base nor this release; refusing to overwrite',
                               'file': entry['target'], 'current': current})
                self.save_cycle(cycle)
                return self.block(cycle, 'release_conflict_third_bytes', PRECONDITION)
        if all(current == entry['sha256'] for entry, current in states):
            return self.finish_publish(cycle, record, prepared, checkout, release_digest, binding)
        return None  # one or more replacements never happened; a safe re-attempt is allowed
    def stage_verify(self, cycle: dict) -> int:
        record = self.stage_record(cycle, 'verify')
        if record['status'] == 'done':
            return OK
        publish = cycle['stages'].get('publish') or {}
        if publish.get('status') != 'done':
            record.update({'status': 'skipped', 'reason': 'nothing was published'})
            self.save_cycle(cycle)
            return OK
        # Effect verification belongs to the owning GM's next ordinary world turn.  The old
        # fixed fixture/production host contract is intentionally not run in the release path:
        # publication is already protected by scope, bytes, policy binding and the main-AI review.
        record.update({'status': 'pending', 'ok': None, 'effect_review_pending': True,
                       'installed': True, 'used': None,
                       'checks': [{'check': 'post_release_observation_deferred', 'ok': True,
                                   'detail': 'owning GM observes the next world turn'}],
                       'reason': 'published; effect review deferred to the owning GM'})
        cycle['effect_review_pending'] = True
        self.save_cycle(cycle)
        return OK
    def stage_verify_production_host_contract(self, cycle: dict) -> int:
        """Run an inference-free, issue-bound town contract on a COPY of the real save.

        The command is host-owned policy, not GM output. It may inspect/advance only the copied
        save and must return explicit causal checks bound to the evidence issue and release bytes.
        This proves host verification. It never claims a resident selected the change; that can
        only be observed by a later sole-writer canonical life phase.
        """
        record = self.stage_record(cycle, 'verify')
        if record['status'] == 'done':
            return OK
        publish = cycle['stages'].get('publish') or {}
        if publish.get('status') != 'done':
            record.update({'status': 'skipped', 'reason': 'nothing was published'})
            self.save_cycle(cycle)
            return OK
        stopped = self.in_flight_stop(cycle, record, 'verify')
        if stopped:
            return stopped
        state = gm_runner.load_state(self.state_dir)
        issue = (state.get('issues') or {}).get(cycle.get('issue_id')) or {}
        identity = str(issue.get('identity_key') or '')
        runtime = self.policy.get('runtime') or {}
        if not any(identity.startswith(value) for value in runtime['supported_issue_prefixes']):
            record.update({'status': 'refused', 'issue_identity': identity})
            self.save_cycle(cycle)
            return self.block(cycle, 'runtime_issue_contract_unsupported', PRECONDITION)
        files = publish.get('files') or []
        if (not files or any(not any(path_matches(item.get('source', ''), pattern)
                                    for pattern in runtime['required_release_paths'])
                             for item in files)):
            record.update({'status': 'refused', 'files': [item.get('source') for item in files]})
            self.save_cycle(cycle)
            return self.block(cycle, 'runtime_release_outside_contract', PRECONDITION)
        source_sha = sha256_file(self.save_path)
        verify_root = self.cycle_dir() / 'verify-production'
        verify_root.mkdir(parents=True, exist_ok=True)
        save_copy = verify_root / 'world-copy.json'
        if not save_copy.exists():
            shutil.copyfile(self.save_path, save_copy)
        if sha256_file(self.save_path) != source_sha:
            return self.block(cycle, 'runtime_source_world_changed_before_verify', STALE)
        release_digest = publish['release_digest']
        first = files[0]
        runs = []
        forbidden = ('run_town_model_validation.py', '--ledger', '--config', 'kimi_gateway',
                     '--town-gateway')
        for phase in ('open', 'resume'):
            out_path = verify_root / ('contract-' + phase + '.json')
            try:
                out_path.unlink()
            except OSError:
                pass
            values = {'checkout': self.checkout, 'save_copy': save_copy, 'out': out_path,
                      'release_digest': release_digest, 'issue_id': cycle.get('issue_id') or '',
                      'issue_identity': identity, 'target': first.get('target') or '',
                      'target_sha256': first.get('sha256') or '', 'evidence': self.evidence,
                      'phase': phase, 'godot': self.godot, 'root': ROOT,
                      'source_world_sha': source_sha}
            command, errors = resolve_command(runtime['host_command'], values)
            if errors or any(marker in token.casefold() for token in command for marker in forbidden):
                record.update({'status': 'refused', 'command_errors': errors,
                               'reason': 'production verification command may not invoke inference'})
                self.save_cycle(cycle)
                return self.block(cycle, 'runtime_host_command_refused', PRECONDITION)
            outcome = run_process(command, int(runtime.get('timeout_seconds', 120)),
                                  deadline=self.deadline)
            observed = gm_runner.load_json(out_path) if out_path.is_file() else None
            runs.append({'phase': phase, 'exit_code': outcome['exit_code'],
                         'timed_out': outcome['timed_out'], 'owned': outcome['owned'],
                         'observed': observed})
            if outcome['timed_out']:
                break
        expected = {'world_id': self.policy['world_id'], 'release_digest': release_digest,
                    'source_world_sha256': source_sha,
                    'loaded_target_sha256': first.get('sha256')}
        def valid(run):
            observed = run.get('observed') or {}
            checks = observed.get('causal_checks')
            return (run.get('exit_code') == 0 and not run.get('timed_out')
                    and all(observed.get(key) == value for key, value in expected.items())
                    and isinstance(checks, dict) and bool(checks)
                    and all(value is True for value in checks.values())
                    and observed.get('ok') is True and observed.get('continuation_ok') is True)
        ok = len(runs) == 2 and all(valid(run) for run in runs) \
            and sha256_file(self.save_path) == source_sha
        record.update({'runs': runs, 'checks': [{'check': 'host_contract_bound_and_causal',
                                                 'ok': ok}], 'ok': ok,
                       'installed': bool(files), 'used': ok,
                       'resident_adoption': False, 'source_world_unchanged':
                       sha256_file(self.save_path) == source_sha,
                       'issue_identity': identity})
        self.save_cycle(cycle)
        if not ok:
            return self.block(cycle, 'runtime_host_contract_failed', RUNTIME)
        self.finish_stage(cycle, 'verify', record)
        return OK

    def stage_feedback(self, cycle: dict) -> int:
        record = self.stage_record(cycle, 'feedback')
        if record['status'] == 'done':
            return OK
        gm_id, issue_id = cycle.get('gm_id'), cycle.get('issue_id')
        if not gm_id:
            record.update({'status': 'skipped', 'reason': 'no GM owned this cycle'})
            self.save_cycle(cycle)
            return OK
        stopped = self.in_flight_stop(cycle, record, 'feedback')
        if stopped:
            return stopped
        verify = cycle['stages'].get('verify') or {}
        observe = cycle['stages'].get('observe') or {}
        candidate = cycle['stages'].get('candidate') or {}
        validate = cycle['stages'].get('validate') or {}
        failure = self.failure_facts(cycle)
        publish = cycle['stages'].get('publish') or {}
        if failure:
            if failure.get('stage') != 'verify':
                receipt_outcome = str(failure.get('stage')) + '_failed'
            elif verify.get('installed_but_unused'):
                receipt_outcome = 'installed_but_unused'
            elif verify.get('reason') == 'runtime_verification_inconclusive':
                receipt_outcome = 'runtime_verification_inconclusive'
            else:
                receipt_outcome = 'verification_failed'
        elif publish.get('status') == 'done' and verify.get('effect_review_pending'):
            receipt_outcome = 'published_pending_gm_review'
        elif verify.get('status') == 'done' and verify.get('ok'):
            receipt_outcome = 'released_and_verified'
        else:
            receipt_outcome = 'not_released'
        effect_binding = None
        if publish.get('status') == 'done':
            try:
                effect_binding = effect_review_baseline(
                    gm_runner.load_state(self.state_dir), issue_id, self.save_path)
            except (OSError, ValueError, KeyError):
                effect_binding = None
        receipt = {'kind': 'autonomy_release_receipt', 'cycle_id': cycle['cycle_id'],
                   'issue_id': issue_id, 'world_id': cycle['world_id'], 'gm_id': gm_id,
                   'release_digest': (cycle.get('release') or {}).get('digest')
                                     or publish.get('release_digest'),
                   'outcome': receipt_outcome,
                   'published': publish.get('status') == 'done',
                   'runtime_verification': {
                       'installed': verify.get('installed'), 'used': verify.get('used'),
                       'installed_but_unused': verify.get('installed_but_unused'),
                       'observation': verify.get('observation')},
                   'effect_review': (dict(effect_binding, owner=gm_id,
                                          next_turn='owning GM observes a later bounded life window')
                                     if effect_binding else
                                     {'status': 'unbound', 'owner': gm_id,
                                      'next_turn': 'no resident/capability baseline was available'}),
                   'host_gate_failed_checks': [c['check'] for c in (validate.get('checks') or [])
                                               if c.get('ok') is False
                                               and c.get('check') != 'gm_self_test_reported'],
                   'failure': failure,
                   'observation_origin': observe.get('observation_origin'),
                   'not_claimed': ('a GM proposal is a hypothesis; this receipt reports only what '
                                   'the host gate and the running fixture actually did'),
                   'utc': gm_runner.utc_iso()}
        if (cycle.get('defer_effect_review') and cycle.get('main_ai_review')
                and publish.get('status') == 'done'):
            # Publication feedback is queued into the owning GM's durable memory.  It is not an
            # immediate provider turn and a pending effect review never invalidates the release.
            receipt_path = self.cycle_dir() / 'effect-review-receipt.json'
            gm_runner.save_json(receipt_path, receipt)
            try:
                state = gm_runner.load_state(self.state_dir)
                owner = (state.get('sessions') or {}).get(gm_id)
                if isinstance(owner, dict):
                    gm_runner.remember_host_feedback(owner, gm_id, receipt,
                                                     sha256_file(receipt_path) or '',
                                                     cycle['cycle_id'])
                    gm_runner.store_state(self.state_dir, state)
            except (OSError, ValueError, KeyError):
                record['memory_delivery'] = 'pending_state_unavailable'
            record.update({'status': 'pending', 'effect_review_pending': True,
                           'receipt': receipt,
                           'receipt_sha256': sha256_file(receipt_path),
                           'reason': 'published; owning GM reviews effect on a later world turn'})
            self.save_cycle(cycle)
            return OK
        attempts = record.setdefault('attempts', [])
        max_attempts = int(self.limits.get('max_feedback_attempts', 2))
        dispatched = int(cycle.get('feedback_attempts_total', 0))
        if dispatched >= max_attempts:
            record['status'] = 'failed'
            self.save_cycle(cycle)
            return self.block(cycle, 'feedback_not_acknowledged_after_max_attempts', ACCOUNTING)
        receipt_path = self.cycle_dir() / f'feedback-{len(attempts) + 1}.json'
        gm_runner.save_json(receipt_path, receipt)
        blocked = self.dispatch_budget(cycle, 'feedback', 1)
        if blocked:
            record['status'] = 'stopped'
            record['blocked_reason'] = blocked
            self.save_cycle(cycle)
            return OK
        command = runner_command(self.runner, 'feedback', '--state-dir', str(self.state_dir),
                                 '--gm', gm_id, '--receipt-file', str(receipt_path))
        if issue_id:
            command += ['--issue', issue_id]
        command += ['--protect', str(self.policy_path), '--protect', str(receipt_path)]
        cycle['feedback_attempts_total'] = dispatched + 1
        self.reserve(cycle, record, 'feedback', 1)
        result = run_process(command, self.runner.get('timeout') or 900, deadline=self.deadline)
        summary = last_json_line(result['stdout'])
        self.settle(cycle, record, 1 if summary is not None else None)
        attempts.append({'attempt': len(attempts) + 1, 'exit_code': result['exit_code'],
                         'status': (summary or {}).get('status'),
                         'acknowledged': bool((summary or {}).get('acknowledged')),
                         'decision': (summary or {}).get('decision'),
                         'next_work': (summary or {}).get('next_work'),
                         'usage_measured': (summary or {}).get('usage_measured'),
                         'usage': (summary or {}).get('usage'),
                         'receipt_sha256': sha256_file(receipt_path),
                         'owned': result.get('owned'), 'seconds': result['seconds']})
        if summary is None or result['timed_out']:
            record['status'] = 'unknown'
            cycle['unknown'] = {'stage': 'feedback', 'exit_code': result['exit_code']}
            self.save_cycle(cycle)
            return self.block(cycle, 'feedback_call_outcome_unknown', ACCOUNTING)
        if ((summary or {}).get('kind') == 'unresolved_unknown_cost'
                or (summary or {}).get('cost') == 'unknown'):
            record['status'] = 'failed'
            self.save_cycle(cycle)
            return self.block(cycle, 'feedback_unknown_usage_stops_dispatch', ACCOUNTING)
        # Transport, guard, receipt binding and measured usage must all pass before an
        # acknowledgement, decision or next_work is accepted as a real owner response.
        owned = result.get('owned') or {}
        # The command's wrapper owns the GM feedback receipt. A nested probe's nonzero exit is
        # retained as evidence but cannot invalidate an acknowledged, measured runner result.
        # Windows job containment must also confirm the entire job has drained.
        members_drained = (owned.get('all_members_exited') is True
                           if owned.get('containment') == 'windows_kill_on_close_job' else True)
        if (result.get('wrapper_exit_code', result['exit_code']) != 0 or not members_drained
                or (summary or {}).get('status') != 'ok'):
            record['status'] = 'failed'
            record['reason'] = ('the feedback transport exited with code '
                                + str(result.get('wrapper_exit_code', result['exit_code']))
                                + ' and status '
                                + str((summary or {}).get('status'))
                                + '; its acknowledgement is not accepted')
            self.save_cycle(cycle)
            return self.block(cycle, 'feedback_transport_failed_not_accepted', RUNTIME)
        if (summary or {}).get('protected_paths_changed'):
            record['status'] = 'refused'
            record['reason'] = 'the feedback turn changed a protected host file'
            self.save_cycle(cycle)
            return self.block(cycle, 'feedback_guard_violation_not_accepted', RUNTIME)
        receipt_sha = sha256_file(receipt_path)
        echoed = (summary or {}).get('receipt_sha256')
        if not isinstance(echoed, str) or echoed != receipt_sha:
            record['status'] = 'refused'
            record['reason'] = ('the acknowledgement is not bound to this exact receipt digest; an '
                                'absent or stale digest is not an acknowledgement')
            self.save_cycle(cycle)
            return self.block(cycle, 'feedback_receipt_binding_mismatch', RUNTIME)
        if (summary or {}).get('gm_id') != gm_id:
            record['status'] = 'refused'
            record['reason'] = 'the acknowledgement was not returned by the owning GM'
            self.save_cycle(cycle)
            return self.block(cycle, 'feedback_owner_mismatch', RUNTIME)
        if (summary or {}).get('usage_measured') is not True:
            record['status'] = 'failed'
            record['reason'] = 'the feedback turn did not report measured usage'
            self.save_cycle(cycle)
            return self.block(cycle, 'feedback_usage_not_measured', ACCOUNTING)
        if not (summary or {}).get('acknowledged') or not (summary or {}).get('decision'):
            record['status'] = 'failed'
            record['reason'] = 'the owning GM did not return a structured acknowledgement'
            self.save_cycle(cycle)
            return self.block(cycle, 'feedback_acknowledgement_missing', RUNTIME)
        record.update({'status': 'done', 'receipt': receipt, 'receipt_sha256':
                       sha256_file(receipt_path),
                       'acknowledgement': {'acknowledged': True,
                                           'decision': (summary or {}).get('decision'),
                                           'next_work': (summary or {}).get('next_work'),
                                           'run_id': (summary or {}).get('run_id')}})
        self.finish_stage(cycle, 'feedback', record)
        return OK

    def failure_facts(self, cycle: dict) -> dict:
        for name in STAGES:
            stub = cycle['stages'].get(name) or {}
            if stub.get('status') in ('failed', 'refused', 'unknown', 'stopped'):
                return {'stage': name, 'status': stub.get('status'),
                        'blocked_reason': cycle.get('blocked_reason'),
                        'failed_checks': [c['check'] for c in (stub.get('checks') or [])
                                          if c.get('ok') is False],
                        'attempts': [{'attempt': item.get('attempt'), 'status': item.get('status')}
                                     for item in (stub.get('attempts') or [])]}
        return {}

    # -- control -------------------------------------------------------------------

    def stop(self, cycle: dict, record: dict, reason: str) -> int:
        record.update({'status': 'stopped', 'blocked_reason': reason})
        self.save_cycle(cycle)
        return OK

    def block(self, cycle: dict, reason: str, exit_code: int) -> int:
        cycle['status'] = 'blocked'
        cycle['blocked_reason'] = reason
        self.save_cycle(cycle)
        return exit_code
    def write_report(self, cycle: dict) -> Path:
        observe = cycle['stages'].get('observe') or {}
        candidate = cycle['stages'].get('candidate') or {}
        validate = cycle['stages'].get('validate') or {}
        review = cycle['stages'].get('review') or {}
        publish = cycle['stages'].get('publish') or {}
        verify = cycle['stages'].get('verify') or {}
        owned_pids, runs_owned = [], False
        for name in STAGES:
            stub = cycle['stages'].get(name) or {}
            for item in [stub] + list(stub.get('runs') or []) + list(stub.get('attempts') or []):
                owned = (item or {}).get('owned')
                if not isinstance(owned, dict):
                    continue
                runs_owned = True
                for member in owned.get('observed_members') or []:
                    owned_pids.append({'stage': name, 'pid': member.get('pid'),
                                       'creation_time_windows_100ns':
                                           member.get('creation_time_windows_100ns'),
                                       'exit_code': member.get('exit_code')})
        all_owned_exited = bool(owned_pids) and all(
            member['exit_code'] is not None for member in owned_pids)
        host_test = next((c for c in (validate.get('checks') or [])
                          if c.get('check') == 'host_test_commands_pass'), None)
        host_test_detail = (host_test or {}).get('detail') or {}
        host_gate_ok = ((host_test or {}).get('ok')
                        if host_test and host_test_detail.get('executed') else None)
        report = {'kind': 'gm_autonomy_cycle_report', 'schema_version': CYCLE_SCHEMA,
                  'cycle_id': cycle['cycle_id'], 'mode': cycle['mode'],
                  'policy': {'policy_id': cycle['policy_id'],
                             'policy_sha256': cycle['policy_sha256'],
                             'world_id': cycle['world_id']},
                  'status': cycle['status'], 'blocked_reason': cycle['blocked_reason'],
                  'stage_status': {name: (cycle['stages'].get(name) or {}).get('status', 'pending')
                                   for name in STAGES},
                  'what_changed': [item['target'] for item in publish.get('files', [])],
                  'release_digest': publish.get('release_digest'),
                  'candidate': {'owner_gm': cycle.get('gm_id'), 'issue_id': cycle.get('issue_id'),
                                'candidate_sha256': self.candidate_version_sha(cycle),
                                'run_id': candidate.get('candidate_run_id'),
                                'changed_files': candidate.get('changed_files'),
                                'gm_self_test': candidate.get('gm_self_test'),
                                'coder_status': candidate.get('coder_status')},
                  'main_ai_review': {'status': review.get('review_state') or review.get('status'),
                                     'decision': (review.get('review') or {}).get('decision'),
                                     'candidate_sha256': review.get('candidate_sha256'),
                                     'suggestions': (review.get('review') or {}).get('suggestions'),
                                     'major_problem': (review.get('review') or {}).get('major_problem')
                                                       or (review.get('review') or {}).get('problem')},
                  'independently_tested': {
                      'host_gate_ok': host_gate_ok,
                      'failed_checks': [c['check'] for c in (validate.get('checks') or [])
                                        if c.get('ok') is False
                                        and c.get('check') != 'host_test_commands_pass'],
                      'host_tests': host_test_detail or None,
                      'runtime_checks': {c['check']: c['ok'] for c in (verify.get('checks') or [])}},
                  'world_observed': verify.get('observation'),
                  'installed': verify.get('installed'), 'used': verify.get('used'),
                  'effect_review_pending': bool(cycle.get('effect_review_pending')
                                                or (cycle['stages'].get('feedback') or {}).get(
                                                    'effect_review_pending')),
                  'gm': {'gm_id': cycle.get('gm_id'), 'issue_id': cycle.get('issue_id'),
                         'observation_origin': observe.get('observation_origin')},
                  'deferred_claims': cycle.get('deferred_claims'), 'declined': cycle.get('declined'),
                  'usage': {'gm_turns': cycle.get('model_calls', 0),
                            'model_calls': cycle.get('model_calls', 0),
                            'gm_turns_note': ('native GM turn dispatches (one GM decision is one '
                                              'turn), including an in-flight reservation; this is '
                                              'not an HTTP request count and not a currency charge'),
                            'dispatch_batches': cycle.get('dispatch_batches', {}),
                            'batch_note': ('one observe batch can carry up to max_gms GM turns; '
                                           'dispatch_batches counts the subprocess batches, not '
                                           'HTTP requests'),
                            'max_model_calls': self.max_model_calls(),
                            'attempts': cycle['attempts'],
                            'feedback_attempts': (cycle['stages'].get('feedback') or {}).get(
                                'attempts'),
                            'unknown': cycle.get('unknown'),
                            'currency': 'not derived from token counters'},
                  'limits': self.limits, 'owner_lock_recovered': self.recovered_lock,
                  'owned_processes': {'windows_job': runs_owned,
                                      'all_observed_members_exited': all_owned_exited,
                                      'members': owned_pids},
                  'next_stage': (cycle['stage'] if cycle['status'] in ('blocked', 'waiting_review')
                                 else None),
                  'started_utc': cycle['started_utc'], 'updated_utc': cycle['updated_utc'],
                  'provenance': {
                      'mode': cycle['mode'],
                      'world_origin': ('labelled_fixture_genesis'
                                       if cycle['mode'] in ('offline_fixture', 'local_trial')
                                       else 'carried_canonical_state'),
                      'gm_transport': ('scripted_fake_local_subprocess'
                                       if cycle['mode'] == 'offline_fixture'
                                       else 'real_provider_route')},
                  'note': PROVENANCE_NOTES.get(cycle['mode'], 'unlabelled autonomy mode')}
        path = self.cycle_dir() / 'report.json'
        gm_runner.save_json(path, report)
        return path

    def next_stage(self, cycle: dict) -> str:
        for name in STAGES:
            if (cycle['stages'].get(name) or {}).get('status') not in ('done', 'skipped', 'no_action'):
                return name
        return STAGES[-1]

    def finish_cycle(self, cycle: dict, status: str, exit_code: int) -> int:
        cycle['status'] = status
        cycle['exit_code'] = int(exit_code)
        if status in ('completed', 'no_action') and cycle.get('deferred_claims'):
            cycle['next_generation'] = self.bump_generation()
        self.save_cycle(cycle)
        report_path = self.write_report(cycle)
        payload = gm_runner.load_json(report_path)
        payload['status'] = status
        payload['report_path'] = gm_runner.relative(report_path)
        self.last_payload = payload
        gm_runner.emit(payload, exit_code)
        return exit_code

    def run(self) -> int:
        if self.state_dir is None or self.checkout is None:
            gm_runner.emit({'status': 'refused', 'kind': 'usage',
                            'message': 'policy paths could not be resolved'}, USAGE)
            return USAGE
        self.autonomy_dir().mkdir(parents=True, exist_ok=True)
        with self.cycle_lock() as lock:
            if lock.recovered:
                self.recovered_lock = lock.recovered
            adopted = self.unfinished_cycle()
            if (adopted is not None and adopted.get('status') == 'blocked'
                    and self.reopen_major_block
                    and adopted.get('blocked_reason') == 'main_ai_major_block'):
                cycle = self.reopen_after_major_block(adopted)
            elif adopted is not None and adopted.get('status') in ('completed', 'no_action',
                                                                   'blocked'):
                return self.emit_existing(adopted, 'previous_cycle_' + str(adopted.get('status'))
                                          + '_not_replayed')
            else:
                cycle = self.adopt(adopted) if adopted else self.load_cycle()
            if cycle.get('status') in ('completed', 'no_action'):
                return self.emit_existing(cycle, 'unchanged_evidence_already_finished')
            index = 0
            while index < len(STAGES):
                name = STAGES[index]
                cycle['stage'] = name
                self.save_cycle(cycle)
                status = getattr(self, 'stage_' + name)(cycle)
                record = cycle['stages'].get(name) or {}
                if status != OK:
                    if name == 'verify' and (cycle['stages'].get('publish') or {}).get('status') == 'done':
                        # Verification is a post-release observation.  Its result, including
                        # non-adoption or an old identity shape, is handed to the GM later and
                        # cannot turn an already safe publication into a failed delivery.
                        self.stage_feedback(cycle)
                        cycle['effect_review_pending'] = True
                        self.save_cycle(cycle)
                        return self.finish_cycle(cycle, 'completed', OK)
                    original_reason = cycle.get('blocked_reason')
                    if name not in ('feedback', 'review') and cycle.get('gm_id'):
                        self.stage_feedback(cycle)
                        cycle['blocked_reason'] = original_reason
                        cycle['feedback_outcome'] = (
                            cycle['stages'].get('feedback') or {}).get('status')
                        if self.advance_repair(cycle):
                            index = STAGES.index('candidate')
                            continue
                    return self.finish_cycle(cycle, 'blocked', status)
                if record.get('status') == 'waiting_review':
                    return self.finish_cycle(cycle, 'waiting_review', OK)
                if record.get('status') == 'no_action':
                    return self.finish_cycle(cycle, 'no_action', OK)
                if record.get('status') == 'stopped':
                    return self.finish_cycle(cycle, 'limit_reached', OK)
                if name == 'feedback' and record.get('status') == 'pending':
                    return self.finish_cycle(cycle, 'completed', OK)
                if self.stop_after == name:
                    return self.finish_cycle(cycle, 'paused', OK)
                index += 1
            return self.finish_cycle(cycle, 'completed', OK)

    def advance_repair(self, cycle: dict) -> bool:
        """Let one measured, accepted same-owner `repair` decision re-open the work stages.

        Only an actionable, owned, host-observed failure that the owner answered with a measured
        and accepted `repair` decision advances (see `repairable_failure`). Unknown or interrupted
        in-flight calls, guard/scope/conflict refusals, unmeasured usage and installed-but-unused
        never do. Attempt counters, dispatch counters and the failure record are all carried into
        the new round, and the number of rounds is bounded, so this cannot become an unbounded
        loop or a fresh attempt budget."""
        feedback = cycle['stages'].get('feedback') or {}
        acknowledgement = feedback.get('acknowledgement') or {}
        if feedback.get('status') != 'done' or acknowledgement.get('decision') != 'repair':
            return False
        if cycle.get('unknown') or cycle.get('repair_blocked'):
            return False
        failure = self.failure_facts(cycle)
        if not self.repairable_failure(failure):
            return False
        rounds = int(cycle.get('repair_rounds', 0))
        if rounds >= int(self.limits.get('max_repair_rounds', 1)):
            return False
        if self.dispatch_budget(cycle, 'repair', 1) is not None:
            return False
        # Preserve every counter across the round: the reopened round gets no fresh budget.
        issue_id = cycle.get('issue_id') or ''
        candidate_record = cycle['stages'].get('candidate') or {}
        carried = dict(cycle.get('carried_attempts') or {})
        carried[issue_id] = int(carried.get(issue_id, 0)) + len(
            candidate_record.get('attempts') or [])
        cycle['carried_attempts'] = carried
        previous = {}
        for stage in ('candidate', 'validate', 'publish', 'verify', 'feedback'):
            stub = cycle['stages'].get(stage)
            if isinstance(stub, dict):
                previous[stage] = copy.deepcopy(stub)
                stub.clear()
                stub['status'] = 'pending'
        cycle['repair_rounds'] = rounds + 1
        cycle.setdefault('repair_history', []).append(
            {'round': rounds + 1, 'failed_stage': failure.get('stage'),
             'failed_status': failure.get('status'),
             'blocked_reason': cycle.get('blocked_reason'),
             'decision': acknowledgement.get('decision'),
             'next_work': acknowledgement.get('next_work'),
             'failed_checks': failure.get('failed_checks'),
             'previous_stages': previous, 'utc': gm_runner.utc_iso()})
        # A reopened cycle is running again, not blocked: a restart must resume the repair round
        # instead of reporting the previous failure as terminal and never replaying.
        cycle['status'] = 'running'
        cycle['blocked_reason'] = None
        self.save_cycle(cycle)
        return True

    def repairable_failure(self, failure: dict) -> bool:
        """Explicit, narrow repairability for one reopened round.

        `runtime_verification_failed` is an actionable defect the running world reported. This
        stage requires that the runtime evidence itself is conclusive: every integrity check
        passed, so the failure is the world's own report about this release under a fresh,
        exactly bound nonce/world/release/issue and fully exited processes. A timeout, a missing
        or stale output file, a mismatched binding or a live child process is inconclusive and
        stays stopped. A validate-stage failure counts only when the sole failed check is the
        ordinary owned candidate test command. Everything else stays stopped: scope/
        protected-path/conflict refusals, byte drift, unknown or interrupted calls, and
        installed-but-unused (which alone is not proof of a defect and must never force
        adoption)."""
        if not failure:
            return False
        stage, status = failure.get('stage'), failure.get('status')
        if status != 'failed':
            return False
        failed = set(failure.get('failed_checks') or ())
        if stage == 'verify':
            return (failure.get('blocked_reason') in REPAIRABLE_FAILURE_REASONS
                    and conclusive_runtime_defect(failed))
        if stage == 'validate':
            return (failure.get('blocked_reason') == 'host_gate_refused_candidate'
                    and bool(failed) and failed <= set(REPAIRABLE_VALIDATE_CHECKS))
        return False

    def unfinished_cycle(self) -> dict | None:
        """The cycle the previous process was working on, if it never reached a terminal state.
        Newer evidence does not displace it: the pinned cycle resumes first."""
        pointer_path = self.pointer_path()
        if not pointer_path.is_file():
            return None
        pointer = gm_runner.load_json(pointer_path)
        if not isinstance(pointer, dict) or not pointer.get('cycle_id'):
            return None
        directory = self.autonomy_dir() / str(pointer['cycle_id'])
        if not (directory / 'cycle.json').is_file():
            return None
        document = gm_runner.load_json(directory / 'cycle.json')
        if not isinstance(document, dict) or document.get('policy_sha256') != self.policy_sha:
            return None
        if document.get('status') == 'running' and document.get('evidence_sha256') != \
                self.evidence_sha256:
            return document
        if document.get('status') == 'paused':
            return document
        if document.get('status') == 'waiting_review':
            return document
        if document.get('status') in ('completed', 'no_action') and \
                document.get('evidence_sha256') == self.evidence_sha256:
            if document.get('deferred_claims') and self.allow_deferred_advance:
                # The finished cycle bumped the generation: a later generation must consume the
                # deferred claims instead of the coordinator stopping as "unchanged".
                return None
            return document
        if document.get('status') == 'blocked':
            return document
        return None

    def emit_existing(self, cycle: dict, reason: str) -> int:
        report_path = self.cycle_dir() / 'report.json'
        payload = gm_runner.load_json(report_path) if report_path.is_file() else {}
        payload = dict(payload or {})
        payload['status'] = cycle.get('status')
        payload['idempotent_no_dispatch'] = reason
        payload['no_new_model_call'] = True
        payload['report_path'] = gm_runner.relative(report_path) if report_path.is_file() else None
        exit_code = int(cycle.get('exit_code') or 0) if cycle.get('status') == 'blocked' else 0
        self.last_payload = payload
        return gm_runner.emit(payload, exit_code)

    def reopen_after_major_block(self, cycle: dict) -> dict:
        """Start a bounded new GM coding candidate after an explicit main-AI block."""
        if cycle.get('blocked_reason') != 'main_ai_major_block':
            return cycle
        previous = {name: copy.deepcopy(cycle.get('stages', {}).get(name) or {})
                    for name in ('candidate', 'validate', 'review', 'publish', 'verify', 'feedback')}
        cycle.setdefault('repair_history', []).append({'round': int(cycle.get('repair_rounds', 0)) + 1,
            'failed_stage': 'review', 'blocked_reason': 'main_ai_major_block',
            'previous_stages': previous, 'utc': gm_runner.utc_iso()})
        cycle['repair_rounds'] = int(cycle.get('repair_rounds', 0)) + 1
        for name in ('candidate', 'validate', 'review', 'publish', 'verify', 'feedback'):
            cycle.setdefault('stages', {})[name] = {'status': 'pending'}
        cycle['main_ai_review'] = None
        cycle['status'] = 'running'
        cycle['blocked_reason'] = None
        self.save_cycle(cycle)
        return cycle


def preflight(cycle: Cycle):
    if sha256_file(cycle.policy_path) is None:
        return USAGE, {'status': 'refused', 'kind': 'policy_missing',
                       'message': f'no standing policy at {cycle.policy_path}; no paid work starts '
                                  'without an explicit preauthorization'}
    errors = policy_errors(cycle.policy)
    if errors:
        return USAGE, {'status': 'refused', 'kind': 'policy_invalid', 'errors': errors}
    stale = stale_world(cycle.policy)
    if stale:
        return STALE, {'status': 'refused', 'kind': 'stale_world', 'message': stale}
    missing = missing_requirements(cycle.policy, cycle.mode)
    if missing:
        return USAGE, {'status': 'refused', 'kind': 'missing_requirements', 'mode': cycle.mode,
                       'missing': missing,
                       'message': 'no model dispatch happened; supply the declared inputs first'}
    return None, {}


def selected_gm_selection(selected, policy):
    """Validate an explicit `cycle --gm` selection before anything is dispatched.

    The selection is checked against the real gm_runner roster and the policy's own max_gms and is
    then forwarded verbatim to gm_runner.observe: never widened to the roster, never silently
    trimmed, never reordered. Returns (refusal_exit_code, None) or (None, ordered_selection).
    """
    if not selected:
        return None, None
    unknown = sorted({item for item in selected if item not in gm_runner.GM_IDS})
    if unknown:
        return gm_runner.refusal('unknown_gm_selection',
                                 f'not a gm_runner roster id: {unknown}', USAGE), None
    duplicates = sorted({item for item in selected if selected.count(item) > 1})
    if duplicates:
        return gm_runner.refusal('duplicate_gm_selection',
                                 f'selected more than once: {duplicates}', USAGE), None
    maximum = int((policy_values(policy).get('limits') or {}).get('max_gms', 10))
    if len(selected) > maximum:
        return gm_runner.refusal('gm_selection_over_limit',
                                 f'{len(selected)} GMs selected but max_gms is {maximum}',
                                 USAGE), None
    return None, [str(item) for item in selected]


def command_cycle(args) -> int:
    policy_path = Path(args.policy).resolve()
    try:
        policy = gm_runner.read_autonomy_policy(policy_path)
    except (OSError, ValueError, json.JSONDecodeError) as error:
        return gm_runner.refusal('autonomy_policy_invalid', str(error), USAGE)
    refused, selected = selected_gm_selection(list(getattr(args, 'gm', None) or []), policy)
    if refused is not None:
        return refused
    max_prompt_bytes = int(args.max_prompt_bytes)
    if not MIN_MAX_PROMPT_BYTES <= max_prompt_bytes <= MAX_MAX_PROMPT_BYTES:
        return gm_runner.refusal(
            'prompt_limit_invalid',
            f'--max-prompt-bytes must be {MIN_MAX_PROMPT_BYTES}..{MAX_MAX_PROMPT_BYTES}',
            USAGE)
    runner = {key: value for key, value in
              {'config': args.config, 'key_file': args.key_file, 'codex': args.codex,
               'codex_home': args.codex_home, 'timeout': args.timeout,
               'route': getattr(args, 'route', gm_runner.ROUTE_DEEPSEEK),
               'max_prompt_bytes': max_prompt_bytes}.items() if value is not None}
    cycle = Cycle(policy_path, policy, runner, args.stop_after, selected_gms=selected,
                  review_path=getattr(args, 'review_file', None),
                  reopen_major_block=getattr(args, 'reopen_major_block', False))
    blocked, payload = preflight(cycle)
    if blocked is not None:
        return gm_runner.emit(payload, blocked)
    try:
        return cycle.run()
    except RuntimeError as error:
        return gm_runner.refusal('lock_held', str(error), LOCK)
    except ValueError as error:
        return gm_runner.refusal('preflight', str(error), USAGE)


def command_record_review(args) -> int:
    """Persist the main-AI opinion for the currently pinned candidate, without a provider call."""
    policy_path = Path(args.policy).resolve()
    try:
        policy = gm_runner.read_autonomy_policy(policy_path)
    except (OSError, ValueError, json.JSONDecodeError) as error:
        return gm_runner.refusal('autonomy_policy_invalid', str(error), USAGE)
    errors = policy_errors(policy)
    if errors:
        return gm_runner.refusal('autonomy_policy_invalid', '; '.join(errors), USAGE,
                                 errors=errors)
    cycle = Cycle(policy_path, policy, {}, None)
    cycle.autonomy_dir().mkdir(parents=True, exist_ok=True)
    try:
        with cycle.cycle_lock():
            if not (cycle.cycle_dir() / 'cycle.json').is_file():
                return gm_runner.refusal('review_candidate_missing',
                                         'no unfinished candidate cycle is available', USAGE)
            document = cycle.load_cycle()
            if document.get('status') in ('completed', 'no_action'):
                return gm_runner.refusal('review_candidate_finished',
                                         'the current cycle is already finished', USAGE)
            if (document.get('status') == 'blocked' and
                    document.get('blocked_reason') == 'main_ai_major_block'):
                return gm_runner.refusal('review_requires_new_candidate',
                                         'reopen the major block to create a new candidate before re-review',
                                         USAGE)
            candidate_sha = cycle.candidate_version_sha(document)
            if candidate_sha is None:
                return gm_runner.refusal('review_candidate_missing',
                                         'the current cycle has no complete candidate file-hash identity',
                                         USAGE)
            review = {
                'cycle_id': document.get('cycle_id'),
                'gm_id': document.get('gm_id'),
                'candidate_sha256': candidate_sha,
                'source': args.source,
                'decision': args.decision,
                'suggestions': list(args.suggestion or []),
                'rationale': args.rationale or '',
                'major_problem': args.problem or '',
                'reviewed_utc': gm_runner.utc_iso(),
            }
            normalized, review_errors = cycle.validate_main_ai_review(document, review)
            output = (Path(args.output).resolve() if args.output else
                      cycle.cycle_dir() / 'main-ai-review.json')
            gm_runner.save_json(output, review)
            if review_errors:
                return gm_runner.refusal('main_ai_review_invalid', '; '.join(review_errors), USAGE,
                                         review_path=gm_runner.relative(output),
                                         candidate_sha256=candidate_sha)
            document['main_ai_review'] = normalized
            document.setdefault('stages', {})['review'] = {'status': 'pending'}
            cycle.save_cycle(document)
            stage_exit = cycle.stage_review(document)
            payload = {
                'status': 'recorded',
                'review_path': gm_runner.relative(output),
                'cycle_id': document.get('cycle_id'),
                'gm_id': document.get('gm_id'),
                'candidate_sha256': candidate_sha,
                'decision': normalized['decision'],
                'review_stage': (document.get('stages', {}).get('review') or {}).get('status'),
                'cycle_status': document.get('status'),
                'exit_code_if_resumed': stage_exit,
                'provider_called': False,
            }
            # A major block is a recorded workflow outcome.  It is not a CLI error and the next
            # coding candidate must be created with `cycle --reopen-major-block`.
            return gm_runner.emit(payload, OK)
    except RuntimeError as error:
        return gm_runner.refusal('lock_held', str(error), LOCK)
    except (OSError, ValueError, KeyError) as error:
        return gm_runner.refusal('review_record_failed', str(error), USAGE)


PROVENANCE_NOTES = {
    'offline_fixture': ('offline fixture plumbing; the GM decisions are scripted fakes and this '
                        'is not real DeepSeek GM autonomy'),
    'local_trial': ('labelled local trial fixture: GM decisions travel over the real provider '
                    'route named in the route config, while the world is a fresh fixture genesis, '
                    'not migrated canonical state; no result is claimed until a run completes'),
    'production': 'production cycle; read host checks and the runtime observation',
}

WATCH_SCHEMA = 2
WATCH_COUNTER_NOTE = (
    'gm_turns counts native GM turn dispatches: one GM decision is one turn, reconciled from '
    'each cycle durable counter and including an in-flight reservation. dispatch_batches counts '
    'the subprocess batches that carried those turns. Neither is an HTTP request count and '
    'neither is a currency charge.')


def watch_paths_match(left: Path | None, right: Path | None) -> bool:
    """Same directory, ignoring Windows case and separator spelling."""
    if left is None or right is None:
        return left is right
    return os.path.normcase(os.path.abspath(str(left))) == os.path.normcase(
        os.path.abspath(str(right)))


def watch_cycle_records(state_dir: Path) -> dict:
    """Reconcile the durable per-cycle counters that bound a watch.

    watch.json can be stale: a crash between the reservation save inside cycle.json and the
    watch-ledger save would otherwise hide an already-counted native GM turn and let the next
    invocation spend past its bound. Every cycle under this state directory is re-read from disk
    here, the in-flight reservation is already part of cycle['model_calls'], and each cycle is
    counted exactly once. The scan stays inside the state directory's own autonomy/ area.
    """
    records, _ = watch_cycle_scan(state_dir)
    return records


def watch_cycle_scan(state_dir: Path) -> tuple:
    """Readable per-cycle counters plus the cycle files that could not be read.

    A malformed, unreadable or missing cycle.json is reported instead of silently skipped: a lost
    counter must never look like a cycle that was never charged.
    """
    records = {}
    problems = []
    root = state_dir / 'autonomy'
    if not root.is_dir():
        return records, problems
    for path in sorted(root.glob('*/cycle.json')):
        try:
            document = gm_runner.load_json(path)
        except (OSError, ValueError):
            problems.append({'cycle_id': path.parent.name, 'path': gm_runner.relative(path),
                             'problem': 'unreadable_cycle_file'})
            continue
        if not isinstance(document, dict) or not document.get('cycle_id'):
            problems.append({'cycle_id': path.parent.name, 'path': gm_runner.relative(path),
                             'problem': 'cycle_file_without_identity'})
            continue
        stages = document.get('stages') or {}
        in_flight = sorted(name for name, stage in stages.items()
                           if isinstance(stage, dict) and stage.get('in_flight'))
        batches = document.get('dispatch_batches') or {}
        records[str(document['cycle_id'])] = {
            'cycle_id': str(document['cycle_id']), 'status': document.get('status'),
            'stage': document.get('stage'), 'gm_id': document.get('gm_id'),
            'issue_id': document.get('issue_id'),
            'policy_sha256': document.get('policy_sha256'),
            'evidence_sha256': document.get('evidence_sha256'),
            'deferred_claims': list(document.get('deferred_claims') or []),
            'gm_turns': int(document.get('model_calls') or 0),
            'dispatch_batches': {str(key): int(value) for key, value in batches.items()},
            'batch_count': sum(int(value) for value in batches.values()),
            'unknown': bool(document.get('unknown')), 'in_flight': in_flight,
            'exit_code': document.get('exit_code'),
            'blocked_reason': document.get('blocked_reason'),
            'path': gm_runner.relative(path)}
    return records, problems


def reconcile_watch_counters(state_dir: Path, budget: dict) -> tuple:
    """Merge readable per-cycle counters into the persisted maps without ever decreasing one.

    Returns the readable records and the list of previously charged cycles whose file can no
    longer be read. A lost counter is retained and reported, never treated as unspent.
    """
    records, problems = watch_cycle_scan(state_dir)
    turns = {key: int(value) for key, value in (budget.get('cycle_gm_turns') or {}).items()}
    batches = {key: int(value)
               for key, value in (budget.get('cycle_dispatch_batches') or {}).items()}
    for key, item in records.items():
        turns[key] = max(int(turns.get(key, 0)), int(item['gm_turns']))
        batches[key] = max(int(batches.get(key, 0)), int(item['batch_count']))
    lost = [{'cycle_id': key, 'gm_turns': turns[key],
             'problem': 'cycle_file_missing_or_unreadable'}
            for key in sorted(turns) if key not in records]
    seen = {item['cycle_id'] for item in lost}
    lost += [{'cycle_id': item['cycle_id'], 'gm_turns': 0, 'problem': item['problem'],
              'path': item['path']} for item in problems if item['cycle_id'] not in seen]
    budget['cycle_gm_turns'] = turns
    budget['cycle_dispatch_batches'] = batches
    budget['lost_counters'] = lost
    budget['gm_turns_total'] = sum(turns.values())
    budget['dispatch_batches_total'] = sum(batches.values())
    return records, lost


def watch_lost_counter_stop(ledger: Path, budget: dict, turns_total: int) -> int:
    """Stop conservatively when a previously charged cycle file can no longer be read."""
    budget['stop_reason'] = 'cycle_counter_unreadable_stop'
    gm_runner.save_json(ledger, budget)
    return gm_runner.emit(watch_summary(
        budget, ledger, 'cycle_counter_unreadable_stop: a previously charged cycle file is '
        'missing or unreadable, so its recorded counters are retained and no further cycle is '
        'started; a lost file must never free a spent allowance', turns_total, ACCOUNTING),
        ACCOUNTING)


def watch_budget_reset(previous, args) -> dict:
    """A fresh budget that keeps the old ledger's history and unresolved usage as facts.

    A reset restarts the bound; it never rewrites what already happened. The previous ledger is
    appended to history and any interrupted-unknown usage is carried forward, so an explicit
    --reset-watch-budget cannot erase a recorded fact.
    """
    history = list(previous.get('history') or []) if isinstance(previous, dict) else []
    carried = list(previous.get('unresolved_usage') or []) if isinstance(previous, dict) else []
    if isinstance(previous, dict):
        history.append({key: previous.get(key) for key in (
            'schema_version', 'started_utc', 'max_iterations', 'max_seconds', 'max_calls',
            'iterations', 'gm_turns_total', 'dispatch_batches_total', 'idle_exits', 'stop_reason',
            'stopped_cycles', 'unresolved_usage')})
    return {'schema_version': WATCH_SCHEMA, 'started_utc': gm_runner.utc_iso(),
            'started_epoch': time.time(), 'max_iterations': int(args.max_iterations),
            'max_seconds': int(args.max_seconds),
            'max_calls': int(args.max_calls) if args.max_calls else None,
            'iterations': 0, 'idle_exits': 0, 'gm_turns_total': 0, 'dispatch_batches_total': 0,
            'cycle_gm_turns': {}, 'cycle_dispatch_batches': {}, 'watched_cycles': {},
            'stopped_cycles': [], 'unresolved_usage': carried, 'history': history,
            'stop_reason': None, 'counter_note': WATCH_COUNTER_NOTE}


def watch_summary(budget: dict, ledger: Path, reason: str, turns_total: int, code: int,
                  stopped=None, unresolved=None) -> dict:
    summary = {'status': 'ok' if code == OK else 'stopped',
               'watch': 'bounded_repeat_coordinator', 'reason': reason,
               'iterations': budget['iterations'], 'idle_exits': budget['idle_exits'],
               'gm_turns': turns_total, 'model_turns': turns_total, 'model_calls': turns_total,
               'gm_turns_note': budget.get('counter_note') or WATCH_COUNTER_NOTE,
               'dispatch_batches': budget['dispatch_batches_total'],
               'max_iterations': budget['max_iterations'], 'max_seconds': budget['max_seconds'],
               'max_calls': budget['max_calls'], 'watched_cycles': budget['watched_cycles'],
               'budget_file': gm_runner.relative(ledger), 'last_exit_code': code}
    if stopped is not None:
        summary['stopped_cycle'] = stopped
    if unresolved is not None:
        summary['unresolved_usage'] = unresolved
    if budget.get('lost_counters'):
        summary['lost_counters'] = budget['lost_counters']
    return summary


def carry_unknown_usage(previous: list, unresolved: list) -> list:
    """Keep every recorded interrupted-unknown fact, adding only ones not already carried."""
    known = {(item.get('cycle_id'), item.get('stage')) for item in previous
             if isinstance(item, dict)}
    carried = list(previous)
    for item in unresolved:
        if (item.get('cycle_id'), item.get('stage')) not in known:
            carried.append(item)
    return carried


def run_watch(args, policy_path: Path, policy: dict, runner: dict, state_dir: Path,
              ledger: Path) -> int:
    """The watch loop body. The caller holds the watch lock for the whole sequence."""
    previous = gm_runner.load_json(ledger) if ledger.is_file() else None
    if (args.reset_watch_budget or not isinstance(previous, dict)
            or previous.get('schema_version') != WATCH_SCHEMA):
        budget = watch_budget_reset(previous, args)
    else:
        budget = previous
        budget.setdefault('counter_note', WATCH_COUNTER_NOTE)
    reason, code = 'max_iterations=' + str(budget['max_iterations']) + ' reached', OK
    turns_total = 0
    while True:
        records, lost = reconcile_watch_counters(state_dir, budget)
        turns_total = budget['gm_turns_total']
        budget['watched_cycles'] = {key: {field: item[field] for field in (
            'status', 'stage', 'gm_id', 'issue_id', 'policy_sha256', 'evidence_sha256',
            'gm_turns', 'batch_count', 'unknown', 'in_flight', 'exit_code', 'blocked_reason',
            'path')} for key, item in records.items()}
        if lost:
            return watch_lost_counter_stop(ledger, budget, turns_total)
        unresolved = [{'cycle_id': key, 'path': item['path'], 'stage': item['stage'],
                       'in_flight': item['in_flight']}
                      for key, item in records.items() if item['unknown'] or item['in_flight']]
        carried_unreconciled = [item for item in (budget.get('unresolved_usage') or [])
                                if isinstance(item, dict) and item.get('cycle_id') not in records]
        if carried_unreconciled:
            # The cycle file that carried this unknown usage is gone, so the fact can no longer
            # be reconciled from disk: it stays a stop and is never settled, dropped or zeroed.
            unresolved = carried_unreconciled + [
                item for item in unresolved
                if all(item.get('cycle_id') != carried.get('cycle_id')
                       for carried in carried_unreconciled)]
        if unresolved:
            budget['unresolved_usage'] = carry_unknown_usage(budget['unresolved_usage'],
                                                            unresolved)
            budget['stop_reason'] = 'interrupted_unknown_stop'
            gm_runner.save_json(ledger, budget)
            return gm_runner.emit(watch_summary(
                budget, ledger, 'interrupted_unknown_stop: an interrupted external call has an '
                'unknown outcome; it stays stopped, is never replayed and is never zeroed',
                turns_total, ACCOUNTING, unresolved=unresolved), ACCOUNTING)
        gm_runner.save_json(ledger, budget)
        if budget['iterations'] >= budget['max_iterations']:
            reason = 'max_iterations=' + str(budget['max_iterations']) + ' reached'
            break
        if time.time() - float(budget['started_epoch']) >= budget['max_seconds']:
            reason = 'max_seconds=' + str(budget['max_seconds']) + ' reached'
            break
        if budget['max_calls'] is not None and turns_total >= int(budget['max_calls']):
            reason = 'max_calls=' + str(budget['max_calls']) + ' native GM turns reached'
            break
        remaining_seconds = float(budget['started_epoch']) + budget['max_seconds'] - time.time()
        cycle = Cycle(policy_path, policy, runner, None,
                      watch_deadline=time.time() + remaining_seconds, allow_deferred_advance=True)
        planned = records.get(cycle.cycle_dir().name)
        already_counted = int(planned['gm_turns']) if planned else 0
        if budget['max_calls'] is not None:
            # A resumed cycle's cumulative ceiling includes the turns it already spent; only the
            # OTHER cycles are subtracted, so nothing is double subtracted and a resumed cycle is
            # not starved of the turns it already paid for.
            cycle.watch_calls_remaining = max(
                0, int(budget['max_calls']) - (turns_total - already_counted))
        blocked, payload = preflight(cycle)
        if blocked is not None:
            budget['stop_reason'] = 'preflight_' + str((payload or {}).get('kind'))
            gm_runner.save_json(ledger, budget)
            return gm_runner.emit(payload, blocked)
        budget['iterations'] += 1
        gm_runner.save_json(ledger, budget)
        try:
            code = cycle.run()
        except RuntimeError as error:
            budget['stop_reason'] = 'lock_held'
            gm_runner.save_json(ledger, budget)
            return gm_runner.refusal('lock_held', str(error), LOCK)
        except ValueError as error:
            budget['stop_reason'] = 'preflight'
            gm_runner.save_json(ledger, budget)
            return gm_runner.refusal('preflight', str(error), USAGE)
        payload = cycle.last_payload or {}
        records, lost = reconcile_watch_counters(state_dir, budget)
        turns_total = budget['gm_turns_total']
        if lost:
            return watch_lost_counter_stop(ledger, budget, turns_total)
        status = payload.get('status')
        if code != OK or status == 'blocked':
            # A payload that reports blocked while the cycle returned 0 is normalized here, before
            # watch_summary is built and before the process exit: the JSON must never report
            # ok/last_exit_code 0 while the command itself fails with a nonzero process status.
            effective_code = code if code != OK else RUNTIME
            stopped = {'cycle_id': payload.get('cycle_id') or cycle.cycle_dir().name,
                       'status': status, 'exit_code': effective_code,
                       'blocked_reason': payload.get('blocked_reason')}
            budget['stopped_cycles'] = list(budget['stopped_cycles']) + [stopped]
            budget['stop_reason'] = 'cycle_' + str(status or 'failed')
            gm_runner.save_json(ledger, budget)
            return gm_runner.emit(watch_summary(
                budget, ledger, budget['stop_reason'] + ': the cycle failed or blocked and its own '
                'nonzero status is returned; no further observation is started and the failure is '
                'never reported as a bounded idle stop', turns_total, effective_code,
                stopped=stopped), effective_code)
        if status not in ('completed', 'no_action'):
            reason = ('cycle ended as ' + str(status) + ' without a failed release; stopping '
                      'instead of re-observing unchanged evidence')
            budget['stop_reason'] = 'cycle_' + str(status)
            gm_runner.save_json(ledger, budget)
            break
        if payload.get('no_new_model_call'):
            budget['idle_exits'] += 1
            gm_runner.save_json(ledger, budget)
            if budget['idle_exits'] >= args.idle_exits:
                reason = ('idle: no new evidence and nothing pending; no model call was made '
                          '(idle_exits=' + str(budget['idle_exits']) + ')')
                break
        else:
            budget['idle_exits'] = 0
            gm_runner.save_json(ledger, budget)
        if args.interval and time.time() + args.interval < (float(budget['started_epoch'])
                                                            + budget['max_seconds']):
            time.sleep(args.interval)
    budget['stop_reason'] = reason
    gm_runner.save_json(ledger, budget)
    return gm_runner.emit(watch_summary(budget, ledger, reason, turns_total, code), OK)


def command_watch(args) -> int:
    """Bounded local repeat coordinator: no supervisor dispatch per stage.

    Each iteration advances at most one cycle, and a cycle delivers ONE queued GM-owned claim: an
    earlier finished cycle's deferred claim is selected from the durable GM state before any new
    observation is paid for, so a queued claim is delivered instead of re-observing unchanged
    evidence. The coordinator holds a distinct OS watch lock across its whole
    read/reconcile/write/run sequence, so two invocations cannot spend the same budget, and it
    reconciles each cycle's durable native-GM-turn counter before computing what is left. It exits
    when the evidence is unchanged and nothing is queued, or when the pinned iteration, duration or
    GM-turn budget is reached. A failed, blocked or interrupted-unknown cycle returns its own
    nonzero status immediately. This is not a daemon.
    """
    policy_path = Path(args.policy).resolve()
    try:
        policy = gm_runner.read_autonomy_policy(policy_path)
    except (OSError, ValueError, json.JSONDecodeError) as error:
        return gm_runner.refusal('autonomy_policy_invalid', str(error), USAGE)
    if (int(args.max_iterations) < 0 or int(args.max_seconds) < 0
            or int(args.max_calls or 0) < 0 or int(args.idle_exits) < 1
            or float(args.interval) < 0):
        return gm_runner.refusal('watch_limits_invalid',
                                 'watch limits must not be negative, --idle-exits must be at least '
                                 '1 and --interval must not be negative; refusing a nonsensical '
                                 'bound instead of guessing one', USAGE)
    runner = {key: value for key, value in
              {'config': args.config, 'key_file': args.key_file, 'codex': args.codex,
               'codex_home': args.codex_home, 'timeout': args.timeout,
               'route': getattr(args, 'route', gm_runner.ROUTE_DEEPSEEK)}.items() if value}
    probe = Cycle(policy_path, policy, runner, None, allow_deferred_advance=True)
    state_dir = probe.state_dir
    declared = resolve_path((policy_values(policy)['paths'] or {}).get('state_dir'))
    requested = Path(args.state_dir) if args.state_dir else None
    if requested is not None and declared is not None and not watch_paths_match(requested, declared):
        return gm_runner.refusal('state_dir_mismatch',
                                 f'--state-dir {requested} does not match the policy '
                                 f'paths.state_dir {declared}; refusing to keep the watch ledger '
                                 'and the cycles it drives in two different directories', USAGE)
    if state_dir is None:
        return gm_runner.refusal('state_dir_missing',
                                 'no --state-dir and no policy paths.state_dir; the watch cannot '
                                 'place a durable budget', USAGE)
    ledger = state_dir / 'autonomy' / 'watch.json'
    try:
        with probe.watch_lock() as lock:
            if lock.recovered:
                previous = gm_runner.load_json(ledger) if ledger.is_file() else None
                if isinstance(previous, dict):
                    previous['recovered_watch_lock'] = lock.recovered
                    gm_runner.save_json(ledger, previous)
            return run_watch(args, policy_path, policy, runner, state_dir, ledger)
    except RuntimeError as error:
        return gm_runner.refusal('watch_lock_held', str(error), LOCK)


def command_status(args) -> int:
    state_dir = Path(args.state_dir).resolve()
    root = state_dir / 'autonomy'
    cycles = []
    if root.is_dir():
        for path in sorted(root.glob('*/cycle.json')):
            try:
                cycle = gm_runner.load_json(path)
            except (OSError, ValueError):
                continue
            report = path.parent / 'report.json'
            cycles.append({'cycle_id': cycle.get('cycle_id'), 'status': cycle.get('status'),
                           'blocked_reason': cycle.get('blocked_reason'),
                           'report': gm_runner.relative(report) if report.is_file() else None,
                           'stage_status': {name: (cycle.get('stages', {}).get(name)
                                                   or {}).get('status') for name in STAGES},
                           'gm_id': cycle.get('gm_id'), 'issue_id': cycle.get('issue_id')})
    return gm_runner.emit({'status': 'ok', 'state_dir': str(state_dir), 'cycles': cycles}, OK)


def recovery_identity(source_cycle_id: str, reference: dict) -> str:
    """One stable identity per source cycle plus its exact durable receipt.

    A second `recover-observe` for the same pair must return the recovery that already exists
    rather than writing another cycle, another generation bump or another usage record.
    """
    material = '|'.join([source_cycle_id, str(reference.get('receipt_sha256'))])
    return 'rec-' + sha256_bytes(material.encode())[:16]


def recorded_recovery(cycle, identity: str, marker: Path) -> dict:
    """The completed recovery this identity already recorded, or a truthful refusal."""
    try:
        recorded = gm_runner.load_json(marker)
    except (OSError, ValueError) as error:
        raise ValueError('the recovery index for this source and receipt is unreadable: '
                         + str(error))
    if not isinstance(recorded, dict) or recorded.get('identity') != identity:
        raise ValueError('the recovery index for this source and receipt does not match it')
    new_dir = cycle.autonomy_dir() / str(recorded.get('new_cycle_id'))
    cycle_path = new_dir / 'cycle.json'
    if not cycle_path.is_file():
        raise ValueError('a recovery for this source and receipt is recorded but its cycle is gone')
    try:
        document = gm_runner.load_json(cycle_path)
    except (OSError, ValueError) as error:
        raise ValueError('the recorded recovery cycle is unreadable: ' + str(error))
    if document.get('status') not in ('no_action', 'completed'):
        raise ValueError('a recovery for this source and receipt exists but is not terminal')
    return {'recovery': recorded.get('recovery'), 'cycle_id': document.get('cycle_id'),
            'report_path': gm_runner.relative(new_dir / 'report.json'),
            'exit_code': OK, 'already_recovered': True}


def recover_observe_cycle(cycle, source_cycle_id: str) -> dict:
    """Serialized entry point: the same `cycle-owner` lock every bounded run takes, so a
    competing owner refuses through the existing lock rather than racing the pointer."""
    cycle.autonomy_dir().mkdir(parents=True, exist_ok=True)
    with cycle.cycle_lock() as lock:
        return carry_observe_cycle(cycle, source_cycle_id,
                                   lock_recovered=getattr(lock, 'recovered', None))


def carry_observe_cycle(cycle, source_cycle_id: str, lock_recovered=None) -> dict:
    """Carry one already-completed observe receipt into a fresh cycle with NO new model call.

    The original blocked cycle and its report are history and are never rewritten. A NEW cycle
    directory (next generation over the same pinned policy and evidence) records an explicit
    carried-receipt recovery, the carried observe stage itself, and the truthful empty-claims
    no_action terminal state, so the next outer phase closes it without buying the observation
    again. A source cycle that still owes a claimed scope, or whose retained record and durable
    receipt do not prove a completed observation, is refused rather than guessed at. Repeating
    the same source cycle and receipt returns the recovery already recorded for that exact pair.
    """
    if (not isinstance(source_cycle_id, str) or not source_cycle_id
            or safe_relpath(source_cycle_id) != source_cycle_id or '/' in source_cycle_id):
        raise ValueError('the source cycle must be one plain autonomy directory name')
    source_dir = cycle.autonomy_dir() / source_cycle_id
    source_path = source_dir / 'cycle.json'
    source_report = source_dir / 'report.json'
    if not source_path.is_file() or not source_report.is_file():
        raise ValueError('the source cycle document and its report must both exist')
    source = gm_runner.load_json(source_path)
    if source.get('status') != 'blocked' or source.get('blocked_reason') != 'observe_failed':
        raise ValueError('only a blocked observe_failed cycle can carry its observation forward')
    if source.get('unknown'):
        raise ValueError('the source cycle still carries unresolved unknown usage')
    if source.get('policy_sha256') != cycle.policy_sha:
        raise ValueError('the standing policy changed; refusing to carry an older observation')
    if source.get('world_id') != cycle.policy.get('world_id'):
        raise ValueError('the source cycle belongs to another world')
    if source.get('evidence_sha256') != cycle.evidence_sha256:
        raise ValueError('the pinned evidence changed; refusing to carry a stale observation')
    record = (source.get('stages') or {}).get('observe') or {}
    reference = carried_observe_receipt(cycle, record)
    if reference is None:
        raise ValueError('the retained observe record and its durable receipt do not prove a '
                         'completed observation')
    state = gm_runner.load_state(cycle.state_dir)
    # A currently unresolved unknown-cost GM stops the recovery. The stale `in_flight` reservation
    # this failed observe still carries is NOT that: the durable receipt proves all ten dispatches
    # settled, and global_unknown_gms reads the GM state, where this run left none.
    unknown_gms = gm_runner.global_unknown_gms(state)
    if unknown_gms:
        raise ValueError('unresolved unknown-cost GMs stop the recovery: ' + ','.join(unknown_gms))
    claims = [issue for issue in state['issues'].values()
              if issue.get('owner_run_id') == reference['run_id'] and issue.get('owner_gm')
              and issue.get('proposed_scope')]
    if claims:
        raise ValueError('this observation still owes a claimed scope; carrying it forward without '
                         'a candidate stage is not supported')
    identity = recovery_identity(source_cycle_id, reference)
    index_dir = cycle.autonomy_dir() / 'recoveries'
    marker = index_dir / (identity + '.json')
    if marker.is_file():
        return recorded_recovery(cycle, identity, marker)
    generation = cycle.bump_generation()
    fresh = Cycle(cycle.policy_path, cycle.policy, cycle.runner, None)
    document = fresh.load_cycle()
    carried = dict(record)
    carried.pop('in_flight', None)
    carried.update({'status': 'done', 'no_action': True,
                    'carried_from_cycle': source_cycle_id, 'carried_receipt': reference,
                    'carried_model_calls': int(source.get('model_calls') or 0),
                    'no_new_model_call': True,
                    'selection': ('the carried observation completed with no claimed scope; '
                                  'no_action preserved and nothing published')})
    recovery = {'schema_version': CYCLE_SCHEMA, 'kind': 'gm_observe_carried_receipt_recovery',
                'source_cycle_id': source_cycle_id,
                'source_cycle_sha256': sha256_file(source_path),
                'source_report_path': gm_runner.relative(source_report),
                'source_report_sha256': sha256_file(source_report),
                'source_blocked_reason': source.get('blocked_reason'),
                'source_policy_sha256': source.get('policy_sha256'),
                'carried_stage': 'observe', 'carried_status': 'no_action',
                'carried_model_calls': int(source.get('model_calls') or 0),
                'no_new_model_call': True, 'generation': generation, 'identity': identity,
                'owner_lock_recovered': lock_recovered,
                'new_cycle_id': fresh.cycle_dir().name, 'receipt': reference,
                'written_utc': gm_runner.utc_iso()}
    document['status'] = 'running'
    document['stage'] = 'observe'
    document['model_calls'] = 0
    document['stages'] = {'observe': carried}
    document['carried_receipt_recovery'] = recovery
    fresh.save_cycle(document)
    gm_runner.save_json(fresh.cycle_dir() / 'carried-receipt-recovery.json', recovery)
    exit_code = fresh.finish_cycle(document, 'no_action', OK)
    # Recorded only after the recovery cycle is terminal, so a crash mid-write leaves a refusal
    # on the next attempt instead of a duplicate cycle.
    index_dir.mkdir(parents=True, exist_ok=True)
    gm_runner.save_json(marker, dict(recovery, identity=identity))
    return {'recovery': recovery, 'cycle_id': document['cycle_id'],
            'report_path': gm_runner.relative(fresh.cycle_dir() / 'report.json'),
            'exit_code': exit_code, 'already_recovered': False}


def command_recover_observe(args) -> int:
    policy_path = Path(args.policy).resolve()
    try:
        policy = gm_runner.read_autonomy_policy(policy_path)
    except (OSError, ValueError, json.JSONDecodeError) as error:
        return gm_runner.refusal('autonomy_policy_invalid', str(error), USAGE)
    runner = {key: value for key, value in
              {'config': args.config, 'key_file': args.key_file, 'codex': args.codex,
               'codex_home': args.codex_home, 'timeout': args.timeout,
               'route': getattr(args, 'route', gm_runner.ROUTE_DEEPSEEK)}.items() if value}
    cycle = Cycle(policy_path, policy, runner, None)
    try:
        result = recover_observe_cycle(cycle, args.cycle)
    except RuntimeError as error:
        return gm_runner.refusal('lock_held', str(error), LOCK)
    except (OSError, ValueError) as error:
        return gm_runner.refusal('observe_recovery_refused', str(error), USAGE)
    return result['exit_code']


def _required_sha256(path: Path, expected: str, label: str) -> str:
    """Return an exact caller-pinned digest or refuse before any durable write."""
    if not isinstance(expected, str) or not re.fullmatch(r'[0-9a-f]{64}', expected):
        raise ValueError(label + ' SHA-256 must be 64 lowercase hexadecimal characters')
    if not path.is_file():
        raise ValueError(label + ' file is missing: ' + str(path))
    actual = sha256_file(path)
    if actual != expected:
        raise ValueError(label + ' SHA-256 mismatch: expected ' + expected + ', got ' + actual)
    return actual


def _one_matching(values, predicate, label: str) -> dict:
    matches = [value for value in (values or [])
               if isinstance(value, dict) and predicate(value)]
    if len(matches) != 1:
        raise ValueError(label + ' must contain exactly one matching record')
    return matches[0]


def recover_scope_feedback(cycle: Cycle, args) -> dict:
    """Offline recovery for one exact GM-authored correction to a refused scope.

    This deliberately does not turn an arbitrary scope refusal into a repair round.  It accepts
    only the current blocked cycle and an exact, measured, guard-clean feedback turn whose raw
    GM result contains a corrected scope for that same owned issue.  All bindings are checked
    before the first write.  GM state and its settled records remain byte-identical.
    """
    cycle_id = str(args.cycle)
    if safe_relpath(cycle_id) != cycle_id or '/' in cycle_id:
        raise ValueError('cycle must be one plain autonomy directory name')
    cycle_dir = cycle.autonomy_dir() / cycle_id
    cycle_path = cycle_dir / 'cycle.json'
    pointer_path = cycle.pointer_path()
    state_path = cycle.state_dir / gm_runner.STATE_FILE
    if not cycle_path.is_file() or not pointer_path.is_file() or not state_path.is_file():
        raise ValueError('cycle, current pointer and GM state must all exist')

    pointer = gm_runner.load_json(pointer_path)
    document = gm_runner.load_json(cycle_path)
    state = gm_runner.load_state(cycle.state_dir)
    if pointer.get('cycle_id') != cycle_id:
        raise ValueError('only the current autonomy cycle may be recovered')
    if document.get('cycle_id') != cycle_id:
        raise ValueError('cycle document identity does not match --cycle')
    if document.get('policy_sha256') != cycle.policy_sha:
        raise ValueError('cycle is not bound to the supplied policy bytes')
    if document.get('evidence_sha256') != cycle.evidence_sha256:
        raise ValueError('cycle is not bound to the supplied evidence bytes')
    if document.get('world_id') != cycle.policy.get('world_id'):
        raise ValueError('cycle world does not match the supplied policy')
    if document.get('scope_feedback_recovery') is not None:
        raise ValueError('this cycle already consumed a scope-feedback recovery')
    if (document.get('status') != 'blocked'
            or document.get('blocked_reason') != 'scope_rejected_by_policy'):
        raise ValueError('cycle must be blocked only by scope_rejected_by_policy')
    if document.get('gm_id') != args.gm or document.get('issue_id') != args.issue:
        raise ValueError('cycle GM/issue binding does not match the requested recovery')
    observe = (document.get('stages') or {}).get('observe') or {}
    candidate = (document.get('stages') or {}).get('candidate') or {}
    feedback = (document.get('stages') or {}).get('feedback') or {}
    if observe.get('status') != 'done' or not isinstance(observe.get('proposed_scope'), dict):
        raise ValueError('cycle has no completed GM-authored observe scope to revise')
    if candidate.get('status') != 'refused' \
            or candidate.get('policy_errors') != [
                'scope.objective must be one concrete 12..400 character sentence']:
        raise ValueError('candidate refusal is not the exact objective-length scope failure')
    if feedback.get('status') != 'failed' \
            or document.get('feedback_outcome') != 'failed':
        raise ValueError('cycle does not retain the failed outer feedback hand-off')

    issue = (state.get('issues') or {}).get(args.issue)
    session = (state.get('sessions') or {}).get(args.gm)
    if not isinstance(issue, dict) or not isinstance(session, dict):
        raise ValueError('bound issue or GM session is absent from state')
    entry = issue.get('entry') or {}
    if (issue.get('owner_gm') != args.gm or issue.get('lifecycle') != 'current'
            or issue.get('source_status') in gm_runner.CLOSED_STATES):
        raise ValueError('issue is no longer a current claim owned by this GM')
    if (entry.get('proposal_key') != args.proposal_key
            or issue.get('capability_id') != args.capability_id
            or issue.get('resident_id') != args.resident_id):
        raise ValueError('proposal/capability/resident binding mismatch')

    observe_run = str(observe.get('run_id') or '')
    expected_observe_result = (cycle.state_dir / 'runs' / observe_run
                               / (str(args.gm) + '.result.md')).resolve()
    observe_result_path = Path(args.observe_result).resolve()
    if observe_result_path != expected_observe_result:
        raise ValueError('observe result path is not the exact owning GM run result')
    _required_sha256(observe_result_path, args.observe_result_sha256, 'observe result')
    observed_answer = gm_runner.extract_json_object(
        observe_result_path.read_text(encoding='utf-8-sig'))
    if not isinstance(observed_answer, dict) or observed_answer.get('gm_id') != args.gm:
        raise ValueError('observe result has no matching GM JSON contract')
    original_claim = _one_matching(
        observed_answer.get('new_issues'),
        lambda value: value.get('proposal_key') == args.proposal_key,
        'observe result new_issues')
    if (original_claim.get('resident_id') != args.resident_id
            or original_claim.get('capability_id') != args.capability_id
            or original_claim.get('claim_coding') is not True
            or original_claim.get('scope') != observe.get('proposed_scope')
            or issue.get('owner_run_id') != observe_run):
        raise ValueError('observe result does not bind the retained scope and stable identity')

    feedback_run = str(args.feedback_run)
    if safe_relpath(feedback_run) != feedback_run or '/' in feedback_run:
        raise ValueError('feedback run must be one plain run directory name')
    feedback_result_path = Path(args.feedback_result).resolve()
    expected_feedback_result = (cycle.state_dir / 'runs' / feedback_run
                                / 'feedback.result.md').resolve()
    if feedback_result_path != expected_feedback_result:
        raise ValueError('feedback result path is not inside the exact feedback run')
    _required_sha256(feedback_result_path, args.feedback_result_sha256, 'feedback result')
    receipt_path = Path(args.receipt_file).resolve()
    expected_receipt = (cycle_dir / 'feedback-1.json').resolve()
    if receipt_path != expected_receipt:
        raise ValueError('receipt is not the first feedback receipt of this cycle')
    receipt_sha = _required_sha256(receipt_path, args.receipt_sha256, 'feedback receipt')
    receipt = gm_runner.load_json(receipt_path)
    failure = receipt.get('failure') or {}
    if (receipt.get('kind') != 'autonomy_release_receipt'
            or receipt.get('cycle_id') != cycle_id or receipt.get('gm_id') != args.gm
            or receipt.get('issue_id') != args.issue
            or receipt.get('world_id') != document.get('world_id')
            or receipt.get('outcome') != 'candidate_failed'
            or failure.get('stage') != 'candidate' or failure.get('status') != 'refused'
            or failure.get('blocked_reason') != 'scope_rejected_by_policy'):
        raise ValueError('feedback receipt is not the exact refused-candidate failure')

    outer_attempt = _one_matching(
        feedback.get('attempts'),
        lambda value: value.get('receipt_sha256') == receipt_sha,
        'cycle feedback attempts')
    if (outer_attempt.get('status') != 'ok' or outer_attempt.get('acknowledged') is not True
            or outer_attempt.get('decision') != 'repair'
            or outer_attempt.get('usage_measured') is not True):
        raise ValueError('cycle did not retain a measured repair acknowledgement')
    outcome = _one_matching(
        session.get('outcomes'),
        lambda value: value.get('run_id') == feedback_run
                      and value.get('kind') == 'autonomy_feedback_ack',
        'GM feedback outcomes')
    if (outcome.get('status') != 'ok' or outcome.get('exit_code') != 0
            or outcome.get('acknowledged') is not True or outcome.get('decision') != 'repair'
            or outcome.get('usage_measured') is not True or outcome.get('cost') != 'measured'
            or outcome.get('receipt_sha256') != receipt_sha
            or outcome.get('repair_requested_issue') != args.issue
            or outcome.get('protected_paths_changed') != []):
        raise ValueError('feedback outcome is not ok, measured, guard-clean and issue-bound')
    feedback_attempt = _one_matching(
        session.get('feedback_attempts'),
        lambda value: value.get('run_id') == feedback_run,
        'GM feedback attempt index')
    if (feedback_attempt.get('status') != 'ok'
            or feedback_attempt.get('usage_measured') is not True
            or feedback_attempt.get('receipt_sha256') != receipt_sha):
        raise ValueError('feedback attempt index does not retain the measured receipt binding')

    feedback_answer = gm_runner.extract_json_object(
        feedback_result_path.read_text(encoding='utf-8-sig'))
    if (not isinstance(feedback_answer, dict) or feedback_answer.get('gm_id') != args.gm
            or feedback_answer.get('receipt_sha256') != receipt_sha
            or feedback_answer.get('acknowledged') is not True
            or feedback_answer.get('decision') != 'repair'
            or feedback_answer.get('new_issues') not in (None, [])):
        raise ValueError('feedback result is not the exact same-owner repair acknowledgement')
    revision = _one_matching(
        feedback_answer.get('results'),
        lambda value: value.get('issue_id') == args.issue,
        'feedback results')
    if revision.get('disposition') != 'proposal' or revision.get('claim_coding') is not True:
        raise ValueError('feedback result does not resubmit a coding proposal')
    raw_scope = revision.get('scope')
    if not isinstance(raw_scope, dict) or set(raw_scope) != {'objective', 'files', 'acceptance'}:
        raise ValueError('recovered scope must contain only objective, files and acceptance')
    recovered_scope, errors = validate_proposed_scope(raw_scope, cycle.policy)
    if errors or recovered_scope is None:
        raise ValueError('recovered scope violates policy: ' + '; '.join(errors))
    original_scope = observe['proposed_scope']
    if (len(recovered_scope['files']) != 8
            or recovered_scope['files'] != original_scope.get('files')):
        raise ValueError('recovered scope must retain the exact original eight allowed files')
    if recovered_scope == original_scope:
        raise ValueError('feedback did not revise the refused scope')
    if (args.capability_id not in recovered_scope['objective']
            or args.resident_id not in gm_runner.canonical(state)):
        raise ValueError('recovered scope lost the capability or resident binding')

    audit_path = cycle_dir / 'scope-feedback-recovery.json'
    if audit_path.exists():
        raise ValueError('scope-feedback recovery audit already exists')
    state_sha_before = sha256_file(state_path)
    cycle_sha_before = sha256_file(cycle_path)
    prior_stages = {name: copy.deepcopy((document.get('stages') or {}).get(name))
                    for name in ('candidate', 'validate', 'publish', 'verify', 'feedback')}
    recovery = {
        'schema_version': 1, 'kind': 'scope_feedback_recovery',
        'cycle_id': cycle_id, 'gm_id': args.gm, 'issue_id': args.issue,
        'proposal_key': args.proposal_key, 'capability_id': args.capability_id,
        'resident_id': args.resident_id, 'observe_run_id': observe_run,
        'feedback_run_id': feedback_run, 'receipt_sha256': receipt_sha,
        'observe_result_sha256': args.observe_result_sha256,
        'feedback_result_sha256': args.feedback_result_sha256,
        'old_scope_sha256': sha256_bytes(gm_runner.canonical(original_scope).encode()),
        'recovered_scope_sha256': sha256_bytes(gm_runner.canonical(recovered_scope).encode()),
        'previous_cycle': {'status': document.get('status'),
                           'stage': document.get('stage'),
                           'blocked_reason': document.get('blocked_reason'),
                           'exit_code': document.get('exit_code')},
        'previous_stages': prior_stages, 'state_sha256': state_sha_before,
        'provider_calls': 0, 'generation_bumped': False,
        'settled_state_edited': False, 'recovered_utc': gm_runner.utc_iso(),
    }
    document['stages']['observe']['proposed_scope'] = recovered_scope
    for name in ('candidate', 'validate', 'publish', 'verify', 'feedback'):
        document['stages'][name] = {'status': 'pending'}
    document['scope_feedback_recovery'] = recovery
    document['status'] = 'running'
    document['stage'] = 'candidate'
    document['blocked_reason'] = None
    document.pop('exit_code', None)
    cycle.adopt(document)
    cycle.save_cycle(document)
    state_sha_after = sha256_file(state_path)
    if state_sha_after != state_sha_before:
        raise RuntimeError('GM state changed during offline scope recovery')
    audit = dict(recovery,
                 cycle_sha256_before=cycle_sha_before,
                 cycle_sha256_after=sha256_file(cycle_path),
                 state_sha256_after=state_sha_after,
                 recovered_scope=recovered_scope,
                 reset_stages=['candidate', 'validate', 'publish', 'verify', 'feedback'],
                 observe_replayed=False)
    gm_runner.save_json(audit_path, audit)
    return {'status': 'ok', 'kind': 'scope_feedback_recovery',
            'cycle_id': cycle_id, 'gm_id': args.gm, 'issue_id': args.issue,
            'audit_path': gm_runner.relative(audit_path),
            'audit_sha256': sha256_file(audit_path),
            'cycle_sha256': sha256_file(cycle_path),
            'state_sha256': state_sha_after, 'provider_called': False,
            'observe_replayed': False, 'generation_bumped': False,
            'recovered_scope_sha256': recovery['recovered_scope_sha256']}


def command_recover_scope_feedback(args) -> int:
    policy_path = Path(args.policy).resolve()
    try:
        policy = gm_runner.read_autonomy_policy(policy_path)
    except (OSError, ValueError, json.JSONDecodeError) as error:
        return gm_runner.refusal('autonomy_policy_invalid', str(error), USAGE)
    errors = policy_errors(policy)
    if errors:
        return gm_runner.refusal('autonomy_policy_invalid', '; '.join(errors), USAGE,
                                 errors=errors)
    cycle = Cycle(policy_path, policy, {}, None)
    try:
        with cycle.cycle_lock():
            payload = recover_scope_feedback(cycle, args)
    except RuntimeError as error:
        return gm_runner.refusal('lock_held', str(error), LOCK)
    except (OSError, ValueError, KeyError) as error:
        return gm_runner.refusal('scope_feedback_recovery_refused', str(error), PRECONDITION)
    return gm_runner.emit(payload, OK)


def _native_timeout_receipt(path: Path, expected_thread: str) -> dict:
    """Read only lifecycle and token counters from one exact Codex rollout."""
    thread = None
    usage_records = []
    turn_completed = 0
    for line in path.read_text(encoding='utf-8').splitlines():
        value = json.loads(line)
        payload = value.get('payload') if isinstance(value.get('payload'), dict) else {}
        if value.get('type') == 'session_meta':
            candidate = payload.get('id') or payload.get('session_id')
            if candidate:
                thread = candidate
        if value.get('type') == 'event_msg' and payload.get('type') == 'token_count':
            info = payload.get('info') or {}
            total = info.get('total_token_usage')
            if isinstance(total, dict):
                usage_records.append({'utc': value.get('timestamp'), 'usage': total})
        if ((value.get('type') == 'event_msg' and payload.get('type') == 'turn_completed')
                or value.get('type') == 'turn.completed'):
            turn_completed += 1
    if thread != expected_thread:
        raise ValueError('native rollout thread identity mismatch')
    if not usage_records:
        raise ValueError('native rollout has no partial usage high-water')
    if turn_completed:
        raise ValueError('native rollout is completed; timeout recovery is not applicable')
    return {'thread_id': thread, 'usage_records': len(usage_records),
            'partial_high_water': usage_records[-1]}


def recover_code_timeout(cycle: Cycle, args) -> dict:
    """Offline continuation for one acknowledged code timeout with an exact native receipt."""
    cycle_id = str(args.cycle)
    if safe_relpath(cycle_id) != cycle_id or '/' in cycle_id:
        raise ValueError('cycle must be one plain autonomy directory name')
    cycle_dir = cycle.autonomy_dir() / cycle_id
    cycle_path = cycle_dir / 'cycle.json'
    state_path = cycle.state_dir / gm_runner.STATE_FILE
    pointer_path = cycle.pointer_path()
    if not cycle_path.is_file() or not state_path.is_file() or not pointer_path.is_file():
        raise ValueError('cycle, current pointer and GM state must all exist')
    document = gm_runner.load_json(cycle_path)
    state = gm_runner.load_state(cycle.state_dir)
    pointer = gm_runner.load_json(pointer_path)
    if pointer.get('cycle_id') != cycle_id or document.get('cycle_id') != cycle_id:
        raise ValueError('only the exact current autonomy cycle may be recovered')
    if (document.get('policy_sha256') != cycle.policy_sha
            or document.get('evidence_sha256') != cycle.evidence_sha256
            or document.get('world_id') != cycle.policy.get('world_id')):
        raise ValueError('cycle policy/evidence/world binding mismatch')
    if document.get('code_timeout_recovery') is not None:
        raise ValueError('this cycle already consumed a code-timeout recovery')
    if (document.get('status') != 'blocked'
            or document.get('blocked_reason') != 'code_failed_no_summary'
            or document.get('stage') != 'candidate'):
        raise ValueError('cycle is not blocked by a candidate code timeout')
    if document.get('gm_id') != args.gm or document.get('issue_id') != args.issue:
        raise ValueError('cycle GM/issue binding mismatch')
    candidate = (document.get('stages') or {}).get('candidate') or {}
    attempts = candidate.get('attempts') or []
    reservation = candidate.get('in_flight') or {}
    if (candidate.get('status') != 'failed'
            or candidate.get('blocked_reason') != 'gm_runner code produced no summary'
            or len(attempts) != 1 or attempts[0].get('run_id') is not None
            or attempts[0].get('usage_measured') is not None
            or reservation.get('stage') != 'code'
            or reservation.get('model_calls_reserved') != 1
            or candidate.get('last_reserved') != reservation):
        raise ValueError('candidate does not retain the exact no-summary attempt')
    owned = attempts[0].get('owned') or {}
    if owned.get('all_members_exited') is not True or owned.get('active_processes') != 0:
        raise ValueError('owned timeout process tree is not fully exited')

    run_id = str(args.run)
    if safe_relpath(run_id) != run_id or '/' in run_id:
        raise ValueError('run must be one plain run directory name')
    run_dir = cycle.state_dir / 'runs' / run_id
    process_path = run_dir / 'coding.process.json'
    events_path = run_dir / 'coding.events.jsonl'
    result_path = run_dir / 'coding.result.md'
    _required_sha256(process_path, args.process_sha256, 'coding process receipt')
    _required_sha256(events_path, args.events_sha256, 'coding event export')
    if result_path.exists():
        raise ValueError('coding result exists; no-summary timeout recovery is not applicable')
    process = gm_runner.load_json(process_path)
    if (process.get('pid') != args.pid
            or process.get('prompt_sha256') != args.prompt_sha256):
        raise ValueError('coding process receipt binding mismatch')
    event_thread = None
    event_completed = 0
    for line in events_path.read_text(encoding='utf-8').splitlines():
        value = json.loads(line)
        if value.get('type') == 'thread.started':
            event_thread = value.get('thread_id')
        if value.get('type') == 'turn.completed':
            event_completed += 1
    if event_thread != args.thread or event_completed:
        raise ValueError('coding event export lifecycle mismatch')

    rollout_path = Path(args.rollout_file).resolve()
    rollout_sha = _required_sha256(rollout_path, args.rollout_sha256, 'native rollout')
    native = _native_timeout_receipt(rollout_path, args.thread)
    report_path = Path(args.report).resolve()
    report_sha = _required_sha256(report_path, args.report_sha256, 'forensics report')
    report = gm_runner.load_json(report_path)
    scope = report.get('scope') or {}
    conclusion = report.get('conclusion') or {}
    recorded_rollout = report.get('native_rollout') or {}
    if (report.get('kind') != 'gm_code_timeout_forensics'
            or scope.get('cycle_id') != cycle_id or scope.get('gm_id') != args.gm
            or scope.get('issue_id') != args.issue or scope.get('run_id') != run_id
            or conclusion.get('attempt_outcome') !=
            'interrupted_after_host_timeout_without_gm_runner_summary'
            or conclusion.get('provider_was_invoked') is not True
            or conclusion.get('success_claimed') is not False
            or conclusion.get('usage_accounting') !=
            'unknown_total_with_measured_partial_native_high_water'
            or recorded_rollout.get('thread_id') != args.thread
            or recorded_rollout.get('sha256') != rollout_sha
            or recorded_rollout.get('event_export_sha256') != args.events_sha256
            or recorded_rollout.get('last_recorded_cumulative_usage') != {
                **native['partial_high_water']['usage'],
                'recorded_utc': native['partial_high_water']['utc']}):
        raise ValueError('forensics report does not bind the exact interrupted native run')

    issue = (state.get('issues') or {}).get(args.issue)
    session = (state.get('sessions') or {}).get(args.gm)
    if not isinstance(issue, dict) or not isinstance(session, dict) \
            or issue.get('owner_gm') != args.gm:
        raise ValueError('current issue ownership mismatch')
    issue_ack = _one_matching(
        issue.get('coding_acknowledged'),
        lambda value: (value.get('unresolved') or {}).get('run_id') == run_id,
        'issue coding acknowledgements')
    gm_ack = _one_matching(
        session.get('acknowledged'),
        lambda value: (value.get('unresolved') or {}).get('run_id') == run_id,
        'GM acknowledgements')
    unresolved = issue_ack.get('unresolved') or {}
    reconciliation = unresolved.get('reconciled') or {}
    if (unresolved.get('status') != 'interrupted_in_flight'
            or unresolved.get('cost') != 'unknown'
            or reconciliation.get('observed_usage') != 'unknown'
            or issue.get('coding_unresolved') is not None
            or session.get('unresolved') is not None
            or (gm_ack.get('unresolved') or {}).get('run_id') != run_id):
        raise ValueError('run was not recovered and acknowledged as unknown usage')

    audit_path = cycle_dir / 'code-timeout-recovery.json'
    if audit_path.exists():
        raise ValueError('code-timeout recovery audit already exists')
    state_sha_before = sha256_file(state_path)
    cycle_sha_before = sha256_file(cycle_path)
    previous_stages = {name: copy.deepcopy((document.get('stages') or {}).get(name))
                       for name in ('candidate', 'validate', 'publish', 'verify', 'feedback')}
    recovery = {
        'schema_version': 1, 'kind': 'code_timeout_recovery', 'cycle_id': cycle_id,
        'gm_id': args.gm, 'issue_id': args.issue, 'run_id': run_id,
        'thread_id': args.thread, 'report_sha256': report_sha,
        'process_sha256': args.process_sha256, 'events_sha256': args.events_sha256,
        'rollout_sha256': rollout_sha, 'partial_usage_high_water':
        native['partial_high_water'], 'usage_total': 'unknown',
        'previous_cycle': {'status': document.get('status'), 'stage': document.get('stage'),
                           'blocked_reason': document.get('blocked_reason'),
                           'exit_code': document.get('exit_code')},
        'previous_stages': previous_stages, 'provider_calls': 0,
        'observe_replayed': False, 'generation_bumped': False,
        'recovered_utc': gm_runner.utc_iso(),
    }
    issue['coding_session_id'] = args.thread
    issue['coding_session_source'] = 'acknowledged_timeout_native_rollout'
    issue['coding_owner_gm'] = args.gm
    issue['coding_provider_result'] = {
        'run_id': run_id, 'status': 'interrupted_in_flight', 'cost': 'unknown',
        'provider_request_started': True, 'pid': args.pid, 'usage': None,
        'usage_measured': False, 'partial_usage_high_water': native['partial_high_water'],
        'session_requested': None, 'session_returned': args.thread,
        'session_bound': True, 'result_text_sha256': None, 'utc': gm_runner.utc_iso(),
    }
    issue.setdefault('code_timeout_recoveries', []).append(recovery)
    session.setdefault('coding', {})['session_id'] = args.thread
    candidate.pop('blocked_reason', None)
    candidate['in_flight'] = None
    candidate['status'] = 'pending'
    for name in ('validate', 'publish', 'verify', 'feedback'):
        document['stages'][name] = {'status': 'pending'}
    document['code_timeout_recovery'] = recovery
    document['status'] = 'running'
    document['stage'] = 'candidate'
    document['blocked_reason'] = None
    document.pop('exit_code', None)
    gm_runner.store_state(cycle.state_dir, state)
    cycle.adopt(document)
    cycle.save_cycle(document)
    audit = dict(recovery, state_sha256_before=state_sha_before,
                 state_sha256_after=sha256_file(state_path),
                 cycle_sha256_before=cycle_sha_before,
                 cycle_sha256_after=sha256_file(cycle_path),
                 reset_stages=['candidate', 'validate', 'publish', 'verify', 'feedback'])
    gm_runner.save_json(audit_path, audit)
    return {'status': 'ok', 'kind': 'code_timeout_recovery', 'cycle_id': cycle_id,
            'gm_id': args.gm, 'issue_id': args.issue,
            'audit_path': gm_runner.relative(audit_path),
            'audit_sha256': sha256_file(audit_path), 'provider_called': False,
            'observe_replayed': False, 'generation_bumped': False,
            'usage_total': 'unknown', 'coding_session_id': args.thread}


def command_recover_code_timeout(args) -> int:
    policy_path = Path(args.policy).resolve()
    try:
        policy = gm_runner.read_autonomy_policy(policy_path)
    except (OSError, ValueError, json.JSONDecodeError) as error:
        return gm_runner.refusal('autonomy_policy_invalid', str(error), USAGE)
    errors = policy_errors(policy)
    if errors:
        return gm_runner.refusal('autonomy_policy_invalid', '; '.join(errors), USAGE,
                                 errors=errors)
    cycle = Cycle(policy_path, policy, {}, None)
    try:
        with cycle.cycle_lock():
            payload = recover_code_timeout(cycle, args)
    except RuntimeError as error:
        return gm_runner.refusal('lock_held', str(error), LOCK)
    except (OSError, ValueError, KeyError, json.JSONDecodeError) as error:
        return gm_runner.refusal('code_timeout_recovery_refused', str(error), PRECONDITION)
    return gm_runner.emit(payload, OK)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    subparsers = parser.add_subparsers(dest='command', required=True)
    cycle_parser = subparsers.add_parser('cycle', help='advance one bounded autonomous cycle')
    cycle_parser.add_argument('--policy', required=True, type=Path)
    cycle_parser.add_argument('--stop-after', choices=STAGES,
                              help='finish this stage then exit paused, for a bounded restart test')
    cycle_parser.add_argument('--review-file', type=Path,
                              help='explicit main-AI review JSON bound to this candidate')
    cycle_parser.add_argument('--reopen-major-block', action='store_true',
                              help='start a new GM candidate after a concrete main-AI major block')
    cycle_parser.add_argument('--config', type=Path, help='passed through to gm_runner')
    cycle_parser.add_argument('--route', choices=(gm_runner.ROUTE_DEEPSEEK,
                                                  gm_runner.ROUTE_NATIVE_CODEX),
                              default=gm_runner.ROUTE_DEEPSEEK,
                              help='GM model route passed through to observe, code and feedback; '
                                   'DeepSeek remains the default')
    cycle_parser.add_argument('--key-file', type=Path)
    cycle_parser.add_argument('--codex', help='passed through to gm_runner (tests inject a fake)')
    cycle_parser.add_argument('--codex-home', type=Path)
    cycle_parser.add_argument('--timeout', type=int, default=900)
    cycle_parser.add_argument('--max-prompt-bytes', type=int,
                              default=DEFAULT_MAX_PROMPT_BYTES,
                              help='forwarded only to gm_runner observe; default 32768, '
                                   'valid range 1024..1048576')
    cycle_parser.add_argument('--gm', action='append', default=[],
                              help='observe only these gm_runner roster GMs (repeatable); the '
                                   'default observes the roster bounded by max_gms')
    cycle_parser.set_defaults(func=command_cycle)
    watch_parser = subparsers.add_parser(
        'watch', help='bounded local repeat coordinator (no supervisor dispatch per stage)')
    watch_parser.add_argument('--policy', required=True, type=Path)
    watch_parser.add_argument('--state-dir', type=Path,
                              help='defaults to policy paths.state_dir')
    watch_parser.add_argument('--max-iterations', type=int, default=4)
    watch_parser.add_argument('--max-seconds', type=int, default=900)
    watch_parser.add_argument('--max-calls', type=int, default=0,
                              help='0 means only the dispatch/model limits in the policy apply')
    watch_parser.add_argument('--idle-exits', type=int, default=1,
                              help='consecutive idle iterations before the watch stops')
    watch_parser.add_argument('--interval', type=float, default=5.0)
    watch_parser.add_argument('--reset-watch-budget', action='store_true')
    watch_parser.add_argument('--config', type=Path)
    watch_parser.add_argument('--route', choices=(gm_runner.ROUTE_DEEPSEEK,
                                                 gm_runner.ROUTE_NATIVE_CODEX),
                              default=gm_runner.ROUTE_DEEPSEEK,
                              help='GM model route passed through to observe, code and feedback; '
                                   'DeepSeek remains the default')
    watch_parser.add_argument('--key-file', type=Path)
    watch_parser.add_argument('--codex')
    watch_parser.add_argument('--codex-home', type=Path)
    watch_parser.add_argument('--timeout', type=int, default=900)
    watch_parser.set_defaults(func=command_watch)
    status_parser = subparsers.add_parser('status', help='read-only cycle summary')
    status_parser.add_argument('--state-dir', required=True, type=Path)
    status_parser.set_defaults(func=command_status)
    review_parser = subparsers.add_parser(
        'record-review', aliases=['review'],
        help='record a bound main-AI advisory or major-block review, no provider call')
    review_parser.add_argument('--policy', required=True, type=Path)
    review_parser.add_argument('--decision', required=True, choices=('advisory', 'major_block'))
    review_parser.add_argument('--source', default='main-ai:cli')
    review_parser.add_argument('--suggestion', action='append', default=[])
    review_parser.add_argument('--rationale', default='')
    review_parser.add_argument('--problem', default='')
    review_parser.add_argument('--output', type=Path)
    review_parser.set_defaults(func=command_record_review)
    recover_parser = subparsers.add_parser(
        'recover-observe', help='offline: carry one completed observe receipt forward, no calls')
    recover_parser.add_argument('--policy', required=True, type=Path)
    recover_parser.add_argument('--cycle', required=True,
                                help='the blocked autonomy cycle directory name to recover')
    recover_parser.add_argument('--config', type=Path)
    recover_parser.add_argument('--route', choices=(gm_runner.ROUTE_DEEPSEEK,
                                                   gm_runner.ROUTE_NATIVE_CODEX),
                                default=gm_runner.ROUTE_DEEPSEEK,
                                help='GM model route for any resumed model stage; '
                                     'DeepSeek remains the default')
    recover_parser.add_argument('--key-file', type=Path)
    recover_parser.add_argument('--codex')
    recover_parser.add_argument('--codex-home', type=Path)
    recover_parser.add_argument('--timeout', type=int, default=900)
    recover_parser.set_defaults(func=command_recover_observe)
    scope_recover = subparsers.add_parser(
        'recover-scope-feedback',
        help='offline: apply one exact GM-authored corrected scope after a bound refusal')
    scope_recover.add_argument('--policy', required=True, type=Path)
    scope_recover.add_argument('--cycle', required=True)
    scope_recover.add_argument('--gm', required=True)
    scope_recover.add_argument('--issue', required=True)
    scope_recover.add_argument('--proposal-key', required=True)
    scope_recover.add_argument('--capability-id', required=True)
    scope_recover.add_argument('--resident-id', required=True)
    scope_recover.add_argument('--feedback-run', required=True)
    scope_recover.add_argument('--receipt-file', required=True, type=Path)
    scope_recover.add_argument('--receipt-sha256', required=True)
    scope_recover.add_argument('--observe-result', required=True, type=Path)
    scope_recover.add_argument('--observe-result-sha256', required=True)
    scope_recover.add_argument('--feedback-result', required=True, type=Path)
    scope_recover.add_argument('--feedback-result-sha256', required=True)
    scope_recover.set_defaults(func=command_recover_scope_feedback)
    code_recover = subparsers.add_parser(
        'recover-code-timeout',
        help='offline: resume one acknowledged no-summary coding timeout, no calls')
    code_recover.add_argument('--policy', required=True, type=Path)
    code_recover.add_argument('--cycle', required=True)
    code_recover.add_argument('--gm', required=True)
    code_recover.add_argument('--issue', required=True)
    code_recover.add_argument('--run', required=True)
    code_recover.add_argument('--pid', required=True, type=int)
    code_recover.add_argument('--prompt-sha256', required=True)
    code_recover.add_argument('--thread', required=True)
    code_recover.add_argument('--process-sha256', required=True)
    code_recover.add_argument('--events-sha256', required=True)
    code_recover.add_argument('--rollout-file', required=True, type=Path)
    code_recover.add_argument('--rollout-sha256', required=True)
    code_recover.add_argument('--report', required=True, type=Path)
    code_recover.add_argument('--report-sha256', required=True)
    code_recover.set_defaults(func=command_recover_code_timeout)
    return parser


def main(argv=None) -> int:
    args = build_parser().parse_args(argv)
    return args.func(args)


if __name__ == '__main__':
    sys.exit(main())
