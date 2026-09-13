#!/usr/bin/env python3
"""Host-side validator and offline end-to-end harness for tools/gm_autonomy.py.

Two independent jobs:

1. `validate-candidate` is the host gate that gm_autonomy runs inside the candidate worktree.
   It never trusts the coder's success JSON: it re-derives the manifest/schema facts itself and
   fails when the bounded capability manifest the GM proposed is not installable.
2. `run` provisions an explicitly labelled offline fixture (evidence snapshot, standing policy,
   disposable trial installation, fake transport) under tmp/gm-autonomy-20260913/ and drives
   `gm_autonomy.py cycle` for one named scenario, asserting the acceptance behaviour.

Nothing here contacts a model or a real world. A green harness run proves the plumbing and the
gates, not real DeepSeek GM autonomy.
"""
from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import gm_runner  # noqa: E402
import gm_autonomy  # noqa: E402

FIXTURE_ROOT = ROOT / 'tmp' / 'gm-autonomy-20260913'
WORLD_ID = 'fixture:well-street'
SCOPE_FILE = 'game/capabilities/gm_autonomy_trial_well.v1.json'
SCENARIOS = ('happy', 'interrupt', 'out_of_policy', 'no_action', 'unknown_usage',
             'never_passes', 'tamper_host_check', 'release_conflict', 'wrong_world',
             'production_missing', 'publish_race', 'installed_unused', 'repair_after_defect',
             'publish_cap', 'causal_repair', 'watch_two_delivery')
SEEDED_SCENARIOS = ('happy', 'interrupt', 'installed_unused', 'repair_after_defect',
                    'publish_cap', 'causal_repair', 'watch_two_delivery')
# The queued two-delivery case: one bounded `watch` pays for ONE observe batch, delivers gm-02's
# first owned claim, then delivers gm-07's ALREADY QUEUED claim from that same batch without a
# second observation, then goes idle. It is seed- and publication-bearing like causal_repair.
WATCH_SCENARIO = 'watch_two_delivery'
# The causal-repair case releases a single bounded GDScript behaviour module instead of the JSON
# manifest; the kernel capability is unchanged. This is test-only fixture code.
CAPABILITY_MODULE = 'game/capabilities/well_stock_lookup.gd'

# The host-owned Godot script that compiles one candidate capability module with the real
# GDScript compiler inside a disposable process. It is listed in the policy's host_owned_paths
# and is deliberately separate from the bounded Python interface guard below.
SMOKE_SCRIPT = 'game/tests/gm_autonomy_module_smoke.gd'

MANIFEST_KEYS = ['schema_version', 'capability_id', 'version', 'world_id', 'provenance',
                 'actions', 'install']


def validate_manifest_document(document, world_id: str = WORLD_ID) -> list[str]:
    """Mirror of game/core/world_kernel.gd _validate_manifest exact-key rules, host-side."""
    if not isinstance(document, dict):
        return ['manifest must be a JSON object']
    errors = []
    if sorted(document.keys()) != sorted(MANIFEST_KEYS):
        return ['manifest keys must be exactly ' + ','.join(MANIFEST_KEYS)]
    if document['schema_version'] != 1:
        errors.append('schema_version must be 1')
    if document['capability_id'] != 'well_bucket':
        errors.append('capability_id must be well_bucket')
    if document['version'] != '1.0.0':
        errors.append('version must be 1.0.0')
    if document['world_id'] != world_id:
        errors.append('world_id must match the standing policy world')
    if document['provenance'] != 'fixture':
        errors.append('provenance must be fixture')
    actions = document['actions']
    if not isinstance(actions, list) or len(actions) != 1:
        errors.append('exactly one bounded action is required')
    elif not isinstance(actions[0], dict) or sorted(actions[0].keys()) != ['amount', 'from', 'id', 'to']:
        errors.append('action keys must be exactly id,from,to,amount')
    else:
        action = actions[0]
        if (action['id'] != 'draw_water' or action['from'] != 'world.well_water'
                or action['to'] != 'resident.inventory.water'):
            errors.append('action must be the bounded draw_water transfer')
        if action['amount'] != 1:
            errors.append('action.amount must be exactly 1 (a larger or zero draw is not the '
                          'verified capability)')
    install = document['install']
    if not isinstance(install, dict) or sorted(install.keys()) != ['materials']:
        errors.append('install keys must be exactly materials')
    else:
        materials = install['materials']
        if not isinstance(materials, dict) or sorted(materials.keys()) != ['bucket', 'rope']:
            errors.append('materials must be exactly rope,bucket')
        elif materials['rope'] != 1 or materials['bucket'] != 1:
            errors.append('materials must be one rope and one bucket')
    return errors


CAPABILITY_MODULE_LIMIT = 8192
CAPABILITY_MODULE_FORBIDDEN = ("OS.", "FileAccess", "DirAccess", "preload(", "load(",
                               "class_name", "@tool", "Engine.", "ResourceLoader",
                               "ProjectSettings", "extends Node", "extends SceneTree")


def _delimiters_balanced(text: str) -> bool:
    pairs = {")": "(", "]": "[", "}": "{"}
    stack = []
    index = 0
    quote = ""
    while index < len(text):
        char = text[index]
        if quote:
            if char == "\\":
                index += 2
                continue
            if char == quote:
                quote = ""
        elif char in ("\"", "'"):
            quote = char
        elif char == "#":
            newline = text.find("\n", index)
            index = len(text) if newline == -1 else newline
            continue
        elif char in "([{":
            stack.append(char)
        elif char in ")]}":
            if not stack or stack.pop() != pairs[char]:
                return False
        index += 1
    return not stack and not quote


def validate_capability_module(path: Path, rel: str, compile_check=None) -> list[str]:
    """Bounded host INTERFACE guard for the one test-only behaviour module.

    Deliberately narrow: byte bound, UTF-8 decodability, balanced delimiters, the declared pure
    lookup interface and a forbidden-token list. Balanced delimiters are not syntax, so a module
    can satisfy this guard and still fail to parse, and the token list is a source-text filter,
    not a proof that the module performs no ambient IO or a sandbox around it. This guard is
    therefore NOT a compiler and NOT a guarantee of purity or no-IO.

    `compile_check`, when supplied, is the host-owned Godot compile/interface smoke
    (godot_module_smoke): it compiles these same bytes with the real GDScript compiler and calls
    the declared lookup with a declared neutral/empty unit input. Without it this function only
    filters text.

    Neither check distinguishes the defective lookup from the corrected one: both versions are
    schema-valid and both compile, so only integration with the real world snapshot can."""
    try:
        raw = path.read_bytes()
    except OSError as error:
        return [f"{rel} is not readable: {error}"]
    errors = []
    if len(raw) > CAPABILITY_MODULE_LIMIT:
        errors.append(f"{rel} exceeds the {CAPABILITY_MODULE_LIMIT}-byte module bound")
    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError as error:
        return errors + [f"{rel} is not valid UTF-8: {error}"]
    for token in CAPABILITY_MODULE_FORBIDDEN:
        if token in text:
            errors.append(f"{rel} uses forbidden token {token!r}")
    if "static func lookup_well_stock(" not in text:
        errors.append(f"{rel} must declare static func lookup_well_stock(")
    if not _delimiters_balanced(text):
        errors.append(f"{rel} has unbalanced (), [], {{}} delimiters")
    if compile_check is not None and not errors:
        errors.extend(compile_check(path, rel))
    return errors


def _policy_scratch_root(policy) -> Path | None:
    """A task-owned scratch parent for the disposable smoke project, taken from the policy."""
    state = ((policy or {}).get('paths') or {}).get('state_dir')
    if not isinstance(state, str) or not state.strip():
        return None
    resolved = Path(state)
    if not resolved.is_absolute():
        resolved = ROOT / resolved
    parent = resolved.parent
    return parent if parent.is_dir() else None


def godot_module_smoke(module: Path, rel: str, godot, scratch_root=None,
                       timeout: int = 120) -> dict:
    """Compile and interface-smoke ONE candidate module in a disposable, task-owned process.

    The Python interface guard is not a compiler, so a delimiter-balanced but syntactically
    invalid module would otherwise reach publication. This runs the host-owned
    game/tests/gm_autonomy_module_smoke.gd script against the candidate bytes: it compiles them
    with the real GDScript compiler, instantiates the module and calls the declared lookup with a
    neutral/empty unit input, requiring a schema-valid missing-stock error. A missing Godot, a
    missing host script or a missing report is refused, never treated as a pass. The scratch
    project is removed here and no town import or build runs.
    """
    report = {'ok': False, 'compiled': False, 'code': None, 'failures': [], 'errors': [],
              'exit_code': None, 'command': None}
    if not module.is_file():
        report['errors'].append(f'{rel}: no candidate module to compile')
        return report
    if godot is None or not str(godot).strip():
        report['errors'].append(f'{rel}: the policy declares no Godot executable, so the host '
                                'compile smoke cannot run; refusing a module it cannot compile')
        return report
    executable = Path(str(godot))
    if not executable.is_file():
        report['errors'].append(f'{rel}: the declared Godot executable {executable} is absent, '
                                'so the host compile smoke cannot run; refusing')
        return report
    script = ROOT / SMOKE_SCRIPT
    if not script.is_file():
        report['errors'].append(f'{rel}: the host-owned smoke script {SMOKE_SCRIPT} is missing; '
                                'refusing an uncompiled module')
        return report
    # The scratch project stays in the ignored, task-owned fixture area: a system temp dir may
    # not be writable for a spawned process under this host's restrictions.
    base = Path(scratch_root) if scratch_root and Path(scratch_root).is_dir() else FIXTURE_ROOT
    base.mkdir(parents=True, exist_ok=True)
    project = base / ('gm-module-smoke-' + os.urandom(4).hex())
    project.mkdir(parents=True)
    try:
        (project / 'project.godot').write_text(
            'config_version=5\n\n[application]\n\nconfig/name="gm_module_smoke"\n',
            encoding='utf-8')
        out = project / 'smoke.json'
        command = [str(executable), '--headless', '--path', str(project.resolve()),
                   '--script', str(script), '--', '--module=' + str(module.resolve()),
                   '--out=' + str(out.resolve())]
        report['command'] = command
        outcome = subprocess.run(command, capture_output=True, text=True, encoding='utf-8',
                                 errors='replace', timeout=timeout, cwd=str(project.resolve()))
        report['exit_code'] = outcome.returncode
        if out.is_file():
            observed = json.loads(out.read_text(encoding='utf-8'))
            if isinstance(observed, dict):
                report['evidence'] = observed
                # The JSON body and the process exit status must both agree: a smoke script whose
                # ok=true rides on a nonzero Godot exit is refused, never treated as a pass.
                report['ok'] = bool(observed.get('ok')) and report['exit_code'] == 0
                report['compiled'] = bool(observed.get('compiled'))
                report['code'] = observed.get('code')
                report['failures'] = [str(item) for item in (observed.get('failures') or [])]
                if observed.get('ok') and report['exit_code'] != 0:
                    report['failures'] = report['failures'] + [
                        'the smoke script reported ok but the Godot process exited '
                        + str(report['exit_code']) + '; refusing a nonzero-exit compile result']
        if not report['ok']:
            detail = '; '.join(report['failures']) or (outcome.stderr or '')[-300:].strip()
            report['errors'].append(f'{rel}: the Godot compile/interface smoke failed'
                                    + (f' ({detail})' if detail else ''))
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        report['errors'].append(f'{rel}: the Godot compile/interface smoke could not run: '
                                f'{error!r}')
    finally:
        shutil.rmtree(project, ignore_errors=True)
    return report


def command_validate_candidate_then_tamper(args) -> int:
    """Host gate followed by a deliberate post-validation byte change.

    This reproduces the observed publication race: the gate hashes the candidate, then the bytes
    move. stage_publish must refuse BEFORE touching the deployment target."""
    code = command_validate_candidate(args)
    candidate = Path(args.candidate).resolve()
    scope = gm_runner.load_json(Path(args.scope))
    for rel in (scope.get('files') if isinstance(scope, dict) else None) or []:
        target = candidate / rel
        if not target.is_file():
            continue
        # Insignificant to the gate (trailing whitespace), material to the byte hash: the
        # candidate bytes now differ from the bytes the host gate just hashed.
        with target.open('ab') as handle:
            handle.write(b'\n')
    return code


def command_validate_candidate(args) -> int:
    candidate = Path(args.candidate).resolve()
    scope = gm_runner.load_json(Path(args.scope))
    policy = gm_runner.load_json(Path(args.policy))
    world_id = policy.get('world_id')
    runtime = policy.get('runtime') or {}
    smoke_scratch = _policy_scratch_root(policy)
    try:
        smoke_timeout = min(int(runtime.get('timeout_seconds') or 120), 180)
    except (TypeError, ValueError):
        smoke_timeout = 120
    errors = []
    smoke = []
    files = scope.get('files') if isinstance(scope, dict) else None
    if not isinstance(files, list) or not files:
        errors.append('scope.files must list at least one candidate file')
        files = []

    def compile_module(path, rel):
        """The host-owned Godot compile/interface smoke for one candidate module."""
        result = godot_module_smoke(path, rel, runtime.get('godot'), smoke_scratch, smoke_timeout)
        smoke.append({key: result[key] for key in ('ok', 'compiled', 'code', 'failures',
                                                   'exit_code', 'errors')})
        return list(result['errors'])

    for rel in files:
        target = candidate / rel
        if not target.is_file():
            errors.append(f'{rel} is missing from the candidate')
            continue
        if rel.endswith('.json') and rel.startswith('game/capabilities/'):
            try:
                document = json.loads(target.read_text(encoding='utf-8-sig'))
            except (OSError, json.JSONDecodeError) as error:
                errors.append(f'{rel} is not readable JSON: {error}')
                continue
            errors.extend(f'{rel}: {message}' for message in
                          validate_manifest_document(document, world_id))
        elif rel.endswith('.gd') and rel.startswith('game/capabilities/'):
            errors.extend(f'{rel}: {message}' for message in
                          validate_capability_module(target, rel, compile_module))
    payload = {'kind': 'gm_autonomy_host_gate', 'ok': not errors, 'candidate': str(candidate),
               'world_id': world_id, 'files': files, 'module_smoke': smoke, 'errors': errors}
    print(json.dumps(payload, ensure_ascii=False, sort_keys=True))
    return 0 if not errors else 1

FAKE_CODEX = r'''"""Offline fake transport for the gm-autonomy fixture. No provider is contacted."""
import json
import os
import re
import sys
import uuid
from pathlib import Path

USAGE = {"input_tokens": 900, "cached_input_tokens": 600, "output_tokens": 40,
         "reasoning_output_tokens": 0}
SCENARIO = os.environ.get("FAKE_AUTONOMY_SCENARIO", "happy")
SCOPE_FILE = "game/capabilities/gm_autonomy_trial_well.v1.json"
CAUSAL_MODULE = "game/capabilities/well_stock_lookup.gd"
PROPOSERS = ("gm-02", "gm-07")

CAUSAL_BAD_MODULE = """extends RefCounted
# Test-only offline fixture capability module authored by the scripted fake GM. No model call.
const CAPABILITY_ID := "well_bucket"

static func lookup_well_stock(snapshot: Dictionary) -> Dictionary:
    var world: Dictionary = snapshot.get("world", {})
    var key := "wellWater"
    if not world.has(key):
        return {"ok": false, "code": "runtime_mechanism_error",
                "detail": "the world snapshot has no key " + key, "resolved_key": key}
    var amount := int(world[key])
    if amount <= 0:
        return {"ok": false, "code": "well_stock_empty", "resolved_key": key, "amount": amount}
    return {"ok": true, "code": "well_stock_available", "resolved_key": key, "amount": amount}
"""

CAUSAL_GOOD_MODULE = """extends RefCounted
# Test-only offline fixture capability module authored by the scripted fake GM. No model call.
const CAPABILITY_ID := "well_bucket"

static func lookup_well_stock(snapshot: Dictionary) -> Dictionary:
    var world: Dictionary = snapshot.get("world", {})
    var key := "well_water"
    if not world.has(key):
        return {"ok": false, "code": "runtime_mechanism_error",
                "detail": "the world snapshot has no key " + key, "resolved_key": key}
    var amount := int(world[key])
    if amount <= 0:
        return {"ok": false, "code": "well_stock_empty", "resolved_key": key, "amount": amount}
    return {"ok": true, "code": "well_stock_available", "resolved_key": key, "amount": amount}
"""


WATCH_FIRST_MODULE = """extends RefCounted
# Test-only offline fixture capability module authored by the scripted fake GM. No model call.
# gm-02's first version works while the well still has stock; it omits depleted-stock handling and
# returns an "available / amount 0" result once the well is empty.
const CAPABILITY_ID := "well_bucket"

static func lookup_well_stock(snapshot: Dictionary) -> Dictionary:
    var world: Dictionary = snapshot.get("world", {})
    var key := "well_water"
    if not world.has(key):
        return {"ok": false, "code": "runtime_mechanism_error",
                "detail": "the world snapshot has no key " + key, "resolved_key": key}
    var amount := int(world[key])
    return {"ok": true, "code": "well_stock_available", "resolved_key": key, "amount": amount}
"""

WATCH_CORRECTED_MODULE = """extends RefCounted
# Test-only offline fixture capability module authored by the scripted fake GM. No model call.
# gm-07's pre-existing proactive claim: add correct depleted-stock handling.
const CAPABILITY_ID := "well_bucket"

static func lookup_well_stock(snapshot: Dictionary) -> Dictionary:
    var world: Dictionary = snapshot.get("world", {})
    var key := "well_water"
    if not world.has(key):
        return {"ok": false, "code": "runtime_mechanism_error",
                "detail": "the world snapshot has no key " + key, "resolved_key": key}
    var amount := int(world[key])
    if amount <= 0:
        return {"ok": false, "code": "well_stock_empty", "resolved_key": key, "amount": amount}
    return {"ok": true, "code": "well_stock_available", "resolved_key": key, "amount": amount}
"""


def scope_file():
    return CAUSAL_MODULE if SCENARIO in ("causal_repair", "watch_two_delivery") else SCOPE_FILE


def section(prompt, name):
    match = re.search(r"\[" + name + r"\]\n(.*?)\n\[END_" + name + r"\]", prompt, re.S)
    return json.loads(match.group(1)) if match else None


def manifest(amount):
    return {"schema_version": 1, "capability_id": "well_bucket", "version": "1.0.0",
            "world_id": "fixture:well-street", "provenance": "fixture",
            "actions": [{"id": "draw_water", "from": "world.well_water",
                         "to": "resident.inventory.water", "amount": amount}],
            "install": {"materials": {"rope": 1, "bucket": 1}}}


def emit(event):
    print(json.dumps(event), flush=True)


def main():
    argv = sys.argv[1:]
    resume = argv[argv.index("resume") + 1] if "resume" in argv else None
    result_path = Path(argv[argv.index("-o") + 1]) if "-o" in argv else None
    prompt = sys.stdin.read()
    gm_state = section(prompt, "GM_STATE")
    coding = section(prompt, "CODING_SCOPE")
    receipt = section(prompt, "FEEDBACK_RECEIPT")
    kind = "feedback" if receipt is not None else ("coding" if coding else "observe")
    gm_id = (coding or gm_state or {}).get("gm_id")
    log_path = os.environ.get("FAKE_AUTONOMY_LOG")
    if log_path:
        with open(log_path, "a", encoding="utf-8") as handle:
            handle.write(json.dumps({"kind": kind, "gm_id": gm_id,
                                     "resume": bool(resume)}) + "\n")
    session = resume or str(uuid.uuid4())
    if SCENARIO == "unknown_usage" and kind == "observe":
        emit({"type": "thread.started", "thread_id": session})
        return 0
    emit({"type": "thread.started", "thread_id": session})
    home = Path(os.environ.get("CODEX_HOME") or (Path.home() / ".codex"))
    rollout = home / "sessions" / "2026" / "09" / "13" / ("rollout-2026-09-13T00-00-00-" + session + ".jsonl")
    rollout.parent.mkdir(parents=True, exist_ok=True)
    with rollout.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps({"type": "offline-fake-session", "chars": len(prompt)}) + "\n")
    if kind == "feedback":
        # A truthful failed or installed-but-unused verification asks the owner to repair; a
        # verified release is acknowledged. The decision is still the scripted fixture's.
        decision = ("repair" if str(receipt.get("outcome")) in ("installed_but_unused",
                                                                "verification_failed")
                    else "accept")
        answer = {"gm_id": gm_state["gm_id"], "acknowledged": True, "decision": decision,
                  "receipt_sha256": gm_state.get("receipt_sha256"),
                  "next_work": "offline fixture acknowledgement of receipt outcome "
                               + str(receipt.get("outcome")),
                  "evidence_refs": ["/counts"],
                  "note": "scripted fixture acknowledgement; not a model result"}
    elif kind == "coding":
        amount = 1
        if SCENARIO in ("happy", "interrupt", "never_passes") and not resume:
            amount = 0
        if SCENARIO == "never_passes":
            amount = 0
        target = Path(os.getcwd()) / scope_file()
        target.parent.mkdir(parents=True, exist_ok=True)
        if SCENARIO == "causal_repair":
            target.write_text(CAUSAL_BAD_MODULE if not resume else CAUSAL_GOOD_MODULE,
                              encoding="utf-8")
        elif SCENARIO == "watch_two_delivery":
            # Two distinct owners, two distinct bounded mechanisms: gm-02 writes the first
            # version (no depleted-stock handling) and gm-07 writes the corrected version.
            target.write_text(WATCH_FIRST_MODULE if gm_id == "gm-02" else WATCH_CORRECTED_MODULE,
                              encoding="utf-8")
        else:
            target.write_text(json.dumps(manifest(amount), indent=2), encoding="utf-8")
        if SCENARIO == "tamper_host_check":
            stub = Path(os.getcwd()) / "tools" / "validate_gm_autonomy.py"
            stub.parent.mkdir(parents=True, exist_ok=True)
            stub.write_text("print('{}')\nraise SystemExit(0)\n", encoding="utf-8")
        answer = {"issue_id": coding["open_issues"][0]["issue_id"], "status": "implemented",
                  "changed_files": [scope_file()], "test_commands": [],
                  "test_results": "offline fixture transport wrote the bounded manifest",
                  "notes": "scripted fixture decision; not a model result"}
    else:
        issues = [item["issue_id"] for item in gm_state["open_issues"]]
        results = [{"issue_id": issue_id, "disposition": "no_action", "claim_coding": False,
                    "summary": "offline fixture: this evidence entry needs no action from me"}
                   for issue_id in issues]
        if SCENARIO in ("no_action", "production_missing", "wrong_world", "unknown_usage"):
            answer = {"gm_id": gm_state["gm_id"], "results": [], "new_issues": [],
                      "note": "offline fixture: no supported work proposed"}
        elif SCENARIO == "out_of_policy":
            answer = {"gm_id": gm_state["gm_id"], "results": results,
                      "new_issues": [{"proposal_key": "fixture-out-of-policy", "claim_coding": True,
                                      "summary": "Offline fixture proposes an excluded path to "
                                                 "prove the host rejects it.",
                                      "evidence_refs": [refs(gm_state)[0]],
                                      "scope": {"objective": "Touch the excluded project file.",
                                                "files": ["game/project.godot"],
                                                "acceptance": ["the host refuses this scope"]}}]}
        elif SCENARIO == "watch_two_delivery":
            # Both GM-owned claims originate in this SAME initial observe batch. gm-02 owns the
            # first version; gm-07's pre-existing proactive claim is to handle depletion. The
            # coordinator delivers gm-02 first (lower gm id) and queues gm-07.
            if gm_id == "gm-02":
                answer = {"gm_id": gm_state["gm_id"], "results": results,
                          "new_issues": [{"proposal_key": "fixture-well-first-version",
                                          "claim_coding": True,
                                          "summary": "The trial well cannot draw while its bounded "
                                                     "stock lookup is missing; propose the first "
                                                     "bounded capability module.",
                                          "evidence_refs": refs(gm_state),
                                          "scope": {"objective": "Restore the bounded well_bucket "
                                                                 "capability with a working stock "
                                                                 "lookup for a stocked well.",
                                                    "files": [scope_file()],
                                                    "acceptance": ["the kernel installs the module "
                                                                   "and the resident draws water"]}}]}
            elif gm_id == "gm-07":
                answer = {"gm_id": gm_state["gm_id"], "results": results,
                          "new_issues": [{"proposal_key": "fixture-well-depletion-handling",
                                          "claim_coding": True,
                                          "summary": "The bounded well stock lookup does not handle "
                                                     "the depleted case; propose adding correct "
                                                     "empty-stock handling.",
                                          "evidence_refs": refs(gm_state),
                                          "scope": {"objective": "Add correct depleted-stock "
                                                                 "handling to the bounded well stock "
                                                                 "lookup.",
                                                    "files": [scope_file()],
                                                    "acceptance": ["the corrected mechanism reports "
                                                                   "well_stock_empty on a depleted "
                                                                   "well"]}}]}
            else:
                answer = {"gm_id": gm_state["gm_id"], "results": results, "new_issues": []}
        elif gm_id in PROPOSERS:
            answer = {"gm_id": gm_state["gm_id"], "results": results,
                      "new_issues": [{"proposal_key": "trial-well-manifest-repair",
                                      "claim_coding": True,
                                      "summary": "The trial installation cannot draw well water "
                                                 "because its bounded capability manifest is "
                                                 "missing or invalid; propose restoring it.",
                                      "evidence_refs": refs(gm_state),
                                      "scope": {"objective": "Restore the bounded well_bucket "
                                                             "capability manifest for the trial "
                                                             "installation.",
                                                "files": [scope_file()],
                                                "acceptance": ["the kernel installs the manifest "
                                                               "and the resident draws water"]}}]}
        else:
            answer = {"gm_id": gm_state["gm_id"], "results": results, "new_issues": []}
    text = "offline fixture transport; no model was called\n"
    text += "```json\n" + json.dumps(answer) + "\n```\n"
    if result_path is not None:
        result_path.write_text(text, encoding="utf-8")
    emit({"type": "item.completed", "item": {"type": "agent_message", "text": text}})
    emit({"type": "turn.completed", "usage": USAGE})
    return 0


def refs(gm_state):
    pointers = (gm_state.get("investigation") or {}).get("evidence_refs") or ["/counts"]
    return pointers[:2]


if __name__ == "__main__":
    sys.exit(main())
'''


def fixture_evidence(world_id: str = WORLD_ID, empty: bool = False) -> dict:
    evidence = [] if empty else [{
        'evidence_kind': 'capability_gap', 'issue_id': 'trial:well-bucket-manifest',
        'resident_id': 'fixture:luna', 'status': 'open', 'occurrences': 3,
        'claim': {'implemented': False, 'verified_in_world': False},
        'first': {'reason': 'the trial installation has no installable well_bucket manifest',
                  'request_id': 'turn:fixture:luna:0:3', 'source_sequence': 7},
        'latest': {'reason': 'residents still cannot draw well water',
                   'request_id': 'turn:fixture:luna:0:9', 'source_sequence': 12}}]
    proposals = [] if empty else [{
        'evidence_kind': 'capability_proposed', 'proposal_id': 'trial:well-bucket-repair',
        'resident_id': 'fixture:luna', 'status': 'open', 'occurrences': 1,
        'claim': {'implemented': False, 'verified_in_world': False},
        'first': {'reason': 'a bounded manifest could restore the well',
                  'request_id': 'turn:fixture:luna:0:4', 'source_sequence': 8},
        'latest': {'reason': 'unchanged since the first proposal',
                   'request_id': 'turn:fixture:luna:0:10', 'source_sequence': 12}}]
    return {'kind': 'background_gm_evidence_snapshot', 'schema_version': 1, 'world_id': world_id,
            'derived_fixture_note': ('offline fixture projection written by validate_gm_autonomy; '
                                     'never live Kimi demand and not a real world export'),
            'projection_note': 'bounded offline fixture',
            'source_revision': {'life_seq': 12, 'proposal_sequence': 3,
                                'world_elapsed_seconds': 120.0},
            'boundaries': {'contains_private_reply_reason': False,
                           'contains_other_resident_memories': False},
            'counts': {'issues': len(evidence), 'proposals': len(proposals)},
            'evidence': evidence, 'proposals': proposals}


PROJECT_GODOT = ('config_version=5\n\n[application]\n'
                 'config/name="InfiniteAincrad GM autonomy trial installation"\n'
                 'config/features=PackedStringArray("4.7", "Forward Plus")\n\n'
                 '[rendering]\nrenderer/rendering_method="forward_plus"\n')

def find_godot() -> str:
    candidates = [os.environ.get('GODOT_EXE'),
                  str(ROOT / 'tmp/toolchain/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64.exe'),
                  str(Path(os.environ.get('USERPROFILE', '')) /
                      '.cache/level0-tools/godot-4.7.2-mono/Godot_v4.7.2-stable_mono_win64/'
                      'Godot_v4.7.2-stable_mono_win64.exe'),
                  shutil.which('godot')]
    for candidate in candidates:
        if candidate and Path(candidate).is_file():
            return str(Path(candidate))
    return ''


def last_json(text: str):
    for line in reversed((text or '').splitlines()):
        line = line.strip()
        if line.startswith('{'):
            try:
                return json.loads(line)
            except json.JSONDecodeError:
                continue
    return None


def call_log_counts(paths) -> dict:
    counts = {}
    if not paths['log'].is_file():
        return counts
    for line in paths['log'].read_text(encoding='utf-8').splitlines():
        if not line.strip():
            continue
        kind = json.loads(line).get('kind')
        counts[kind] = counts.get(kind, 0) + 1
    return counts


ACCOUNTING_REFERENCES = [
    'tmp/gm-autonomy-20260913/accounting-summary.json',
    'tmp/gm-autonomy-20260913/usage-root.json',
    'tmp/gm-autonomy-20260913/deepseek-correction-usage-incomplete.json',
]


def carried_accounting_reference_ledger() -> dict:
    """Real-route carried reference: measured history plus the preserved unknown tail.

    This is NOT the scripted offline fixture ledger. It records no invented settled, zero or
    re-counted fees; it only points at the existing measured-usage files and keeps the interrupted
    DeepSeek stream tail formally unknown.
    """
    references = []
    for relative_path in ACCOUNTING_REFERENCES:
        source = ROOT / relative_path
        references.append({'path': relative_path, 'present': source.is_file(),
                           'sha256': gm_runner.sha256_file(source) if source.is_file() else None})
    return {'schema_version': 1, 'kind': 'carried_accounting_reference_ledger', 'calls': [],
            'measured_history_references': references,
            'interrupted_unknown_tail': {
                'status': 'unknown', 'preserved': True,
                'note': ('the interrupted DeepSeek correction stream tail stays unknown; it is '
                         'never settled, zeroed, replayed or re-counted here')},
            'note': ('carried-accounting reference only; contains no invented settled or zero fee '
                     'entries and is not a fake scenario ledger')}


def provision(name: str, scenario: str, mode: str = 'offline_fixture', root_dir=None,
              unique: bool = True, record_latest: bool = True) -> dict:
    # Unique owned run directories only. Previous runs (including failed ones) are kept and
    # pointed at from latest.json; nothing here wipes earlier evidence to force a green report.
    # A caller may pass root_dir + unique=False to prepare one deterministic labelled local
    # trial fixture outside tmp/gm-autonomy-20260913/runs/.
    base = Path(root_dir) if root_dir else FIXTURE_ROOT / 'runs'
    root = base / ((name + '-' + gm_runner.utc_stamp() + '-' + os.urandom(2).hex()) if unique
                   else name)
    paths = {'root': root, 'state': root / 'state', 'deployment': root / 'trial-deployment',
             'runtime': root / 'runtime', 'evidence': root / 'evidence.json',
             'ledger': root / 'prior-ledger.json', 'policy': root / 'policy.json',
             'fake': root / 'fake_codex.py', 'log': root / 'calls.jsonl',
             'codex_home': root / 'codex-home', 'config': root / 'deepseek.local.json',
             'key': root / 'deepseek-key.txt', 'save': root / 'runtime' / 'trial-world.json'}
    for key in ('state', 'deployment', 'runtime', 'codex_home'):
        paths[key].mkdir(parents=True, exist_ok=True)
    for sub in ('core', 'capabilities', 'tests'):
        (paths['deployment'] / sub).mkdir(parents=True, exist_ok=True)
    shutil.copyfile(ROOT / 'game/core/world_kernel.gd',
                    paths['deployment'] / 'core' / 'world_kernel.gd')
    shutil.copyfile(ROOT / 'game/tests/gm_autonomy_acceptance.gd',
                    paths['deployment'] / 'tests' / 'gm_autonomy_acceptance.gd')
    (paths['deployment'] / 'project.godot').write_text(PROJECT_GODOT, encoding='utf-8')
    gm_runner.save_json(paths['deployment'] / 'deployment-base.json',
                        {'schema_version': 1, 'files': {}})
    gm_runner.save_json(paths['evidence'], fixture_evidence(empty=(name == 'no_action')))
    fake_transport = mode != 'local_trial'
    if fake_transport:
        gm_runner.save_json(paths['ledger'], {'kind': 'fixture_prior_ledger', 'calls': []})
        paths['fake'].write_text(FAKE_CODEX, encoding='utf-8')
    else:
        # A real local-route preparation carries no scripted-fake transport or key artifact; its
        # prior ledger is a carried-accounting REFERENCE, never the offline fixture ledger.
        gm_runner.save_json(paths['ledger'], carried_accounting_reference_ledger())
    (paths['codex_home'] / 'config.toml').write_text('[windows]\nsandbox = "unelevated"\n',
                                                     encoding='utf-8')
    paths['config'].write_text(json.dumps({'model': 'deepseek-flash',
                                           'base_url': 'https://api.deepseek.com',
                                           'wire_api': 'responses'}), encoding='utf-8')
    if fake_transport:
        paths['key'].write_text('sk-offline-fake-key-not-a-credential\n', encoding='utf-8')
    policy = {
        'schema_version': 1, 'policy_id': 'gm-autonomy-offline-' + name, 'mode': mode,
        'world_id': WORLD_ID, 'base_revision': None,
        'objective': 'Find one bounded, evidence-backed repair for the trial installation and '
                     'prove it with the host gate and a running save.',
        'scope_constraints': {
            'allowed_source_paths': ['game/capabilities/**'],
            'excluded_paths': ['secrets/**', 'private/**', 'tmp/**', '.git/**', 'tools/**',
                               'game/core/**', 'game/tests/**', 'game/project.godot',
                               'game/scenes/**', 'game/agents/**'],
            'max_changed_files': 1},
        'host_owned_paths': ['tools/gm_runner.py', 'tools/gm_autonomy.py',
                             'tools/validate_gm_autonomy.py',
                             'game/tests/gm_autonomy_acceptance.gd',
                             'game/tests/gm_autonomy_module_smoke.gd'],
        'required_test_commands': [[sys.executable, '{root}/tools/validate_gm_autonomy.py',
                                    'validate-candidate', '--candidate', '.', '--scope',
                                    '{scope_file}', '--policy', '{policy_file}']],
        'limits': {'max_gms': 10, 'max_issues_per_gm': 4, 'max_issues_per_cycle': 1,
                   'max_attempts_per_issue': 3, 'max_dispatches': 8, 'max_publishes': 1,
                   'deadline_seconds': 1500},
        'paths': {'evidence': gm_runner.relative(paths['evidence']),
                  'state_dir': gm_runner.relative(paths['state']),
                  'prior_ledger': gm_runner.relative(paths['ledger'])},
        'deployment': {'checkout': gm_runner.relative(paths['deployment']),
                       'base_manifest': gm_runner.relative(paths['deployment'] /
                                                           'deployment-base.json'),
                       'candidate_isolation': 'sparse_alternates',
                       'path_map': {'game/': ''}},
        'runtime': {'godot': find_godot(), 'save_path': gm_runner.relative(paths['save']),
                    'script': 'res://tests/gm_autonomy_acceptance.gd', 'timeout_seconds': 180}}
    if scenario == 'release_conflict':
        (paths['deployment'] / 'capabilities' / 'gm_autonomy_trial_well.v1.json').write_text(
            'stale bytes from another writer', encoding='utf-8')
    if scenario == 'wrong_world':
        gm_runner.save_json(paths['save'], {'world_id': 'fixture:other-street', 'fixture': True})
    if scenario == 'production_missing':
        policy['mode'] = 'production'
        policy['paths']['prior_ledger'] = gm_runner.relative(root / 'absent-ledger.json')
        policy['runtime']['godot'] = str(root / 'absent-godot.exe')
    gm_runner.save_json(paths['policy'], policy)
    paths['policy_doc'] = policy
    if scenario == 'publish_race':
        policy['required_test_commands'] = [[sys.executable,
                                            '{root}/tools/validate_gm_autonomy.py',
                                            'validate-candidate-then-tamper', '--candidate', '.',
                                            '--scope', '{scope_file}', '--policy', '{policy_file}']]
        gm_runner.save_json(paths['policy'], policy)
    if scenario == 'installed_unused':
        policy['runtime']['extra_args'] = ['--simulate-unused=yes']
        paths['simulate_unused'] = True
        gm_runner.save_json(paths['policy'], policy)
    if scenario == 'watch_two_delivery':
        # Explicit fixture option. The runtime only takes the depleted-state probe branch when the
        # capability is already installed AND the world is already depleted, so cycle 1 (stocked,
        # not yet installed) keeps its ordinary install-and-draw path while cycle 2 probes.
        policy['runtime']['extra_args'] = ['--depleted-probe=yes']
        gm_runner.save_json(paths['policy'], policy)
    if scenario in ('repair_after_defect', 'publish_cap'):
        # Labelled one-shot runtime defect: the first verification run observes an actionable
        # defect, the marker is consumed, and the reopened repair round is verified honestly.
        paths['defect_marker'] = root / 'runtime-defect-marker.txt'
        paths['defect_marker'].write_text('labelled runtime defect; consumed by the first open '
                                          'phase\n', encoding='utf-8')
        policy['runtime']['extra_args'] = ['--defect-once=' + str(paths['defect_marker'])]
    if scenario == 'repair_after_defect':
        # This scenario intentionally publishes twice: round 1 and the repaired round 2.
        policy['limits']['max_publishes'] = 2
        gm_runner.save_json(paths['policy'], policy)
    if scenario == 'publish_cap':
        # A policy that allows exactly one publication must stop the repair round's second
        # release while the first release's bytes and receipt stay intact.
        policy['limits']['max_publishes'] = 1
        gm_runner.save_json(paths['policy'], policy)
    if scenario == 'causal_repair':
        # Two intentional, explicitly permitted publications: the defective release and the
        # corrected release from the same owner on the same save. No defect marker or count is
        # injected: the first verification fails only because of the candidate's own behaviour.
        policy['limits']['max_publishes'] = 2
        gm_runner.save_json(paths['policy'], policy)
    if scenario in SEEDED_SCENARIOS and Path(policy['runtime']['godot']).is_file():
        paths['seed'] = run_seed(paths)
    if record_latest:
        latest_path = FIXTURE_ROOT / 'latest.json'
        latest = gm_runner.load_json(latest_path) if latest_path.is_file() else {}
        latest = latest if isinstance(latest, dict) else {}
        latest[name] = {'root': gm_runner.relative(root), 'scenario': scenario,
                        'utc': gm_runner.utc_iso()}
        gm_runner.save_json(latest_path, latest)
    return paths


def run_seed(paths) -> dict:
    """Seed the labelled fixture BEFORE publication. The fixture refuses to touch an existing
    save, so this never resets a world that is already there."""
    out_path = paths['root'] / 'seed.json'
    command = [paths['policy_doc']['runtime']['godot'], '--headless', '--path',
               str(paths['deployment']), '--script', 'res://tests/gm_autonomy_acceptance.gd',
               '--', '--save=' + str(paths['save']), '--phase=seed', '--nonce=provision-seed',
               '--allow-create=yes', '--out=' + str(out_path)]
    finished = subprocess.run(command, capture_output=True, text=True, encoding='utf-8',
                              errors='replace', timeout=240)
    observed = gm_runner.load_json(out_path) if out_path.is_file() else None
    return {'exit_code': finished.returncode, 'observed': observed,
            'stderr_tail': finished.stderr[-400:]}


def run_cycle(paths, scenario: str, stop_after=None, timeout: int = 1500):
    command = [sys.executable, str(ROOT / 'tools/gm_autonomy.py'), 'cycle',
               '--policy', str(paths['policy']), '--config', str(paths['config']),
               '--key-file', str(paths['key']),
               '--codex', '"' + sys.executable + '" "' + str(paths['fake']) + '"',
               '--codex-home', str(paths['codex_home'])]
    if stop_after:
        command += ['--stop-after', stop_after]
    environment = dict(os.environ)
    environment.update({'FAKE_AUTONOMY_SCENARIO': scenario, 'FAKE_AUTONOMY_LOG': str(paths['log']),
                        'CODEX_HOME': str(paths['codex_home'])})
    finished = subprocess.run(command, cwd=str(ROOT), env=environment, capture_output=True,
                              text=True, encoding='utf-8', errors='replace', timeout=timeout)
    return finished, last_json(finished.stdout)


def run_watch(paths, scenario: str, max_iterations: int = 4, idle_exits: int = 1,
              timeout: int = 1500):
    """Drive the bounded `watch` coordinator (not a single `cycle`) end to end."""
    command = [sys.executable, str(ROOT / 'tools/gm_autonomy.py'), 'watch',
               '--policy', str(paths['policy']), '--config', str(paths['config']),
               '--key-file', str(paths['key']),
               '--codex', '"' + sys.executable + '" "' + str(paths['fake']) + '"',
               '--codex-home', str(paths['codex_home']),
               '--max-iterations', str(max_iterations), '--idle-exits', str(idle_exits),
               '--max-seconds', '1200', '--interval', '0']
    environment = dict(os.environ)
    environment.update({'FAKE_AUTONOMY_SCENARIO': scenario, 'FAKE_AUTONOMY_LOG': str(paths['log']),
                        'CODEX_HOME': str(paths['codex_home'])})
    finished = subprocess.run(command, cwd=str(ROOT), env=environment, capture_output=True,
                              text=True, encoding='utf-8', errors='replace', timeout=timeout)
    return finished, last_json(finished.stdout)


def cycle_documents(paths) -> dict:
    """Every durable cycle under this state dir, keyed by cycle_id."""
    root = paths['state'] / 'autonomy'
    documents = {}
    if root.is_dir():
        for path in sorted(root.glob('auto-*/cycle.json')):
            document = gm_runner.load_json(path)
            if isinstance(document, dict) and document.get('cycle_id'):
                documents[str(document['cycle_id'])] = document
    return documents


def cleanup(paths) -> None:
    root = paths['root'].resolve()
    listing = subprocess.run(['git', 'worktree', 'list', '--porcelain'], cwd=str(ROOT),
                             capture_output=True, text=True).stdout
    for line in listing.splitlines():
        if not line.startswith('worktree '):
            continue
        target = Path(line.split(' ', 1)[1].strip()).resolve()
        if target != ROOT.resolve() and root in target.parents:
            subprocess.run(['git', 'worktree', 'remove', '--force', str(target)], cwd=str(ROOT),
                           capture_output=True, text=True)


def add(checks, name, ok, detail=None):
    checks.append({'check': name, 'ok': bool(ok), 'detail': detail})

def cycle_dir(paths):
    root = paths['state'] / 'autonomy'
    directories = sorted(root.glob('auto-*')) if root.is_dir() else []
    return directories[-1] if directories else None


def load_cycle(paths) -> dict:
    directory = cycle_dir(paths)
    return gm_runner.load_json(directory / 'cycle.json') if directory else {}


def feedback_count(paths, gm_id: str) -> int:
    state = gm_runner.load_state(paths['state'])
    return len([entry for entry in state['sessions'][gm_id]['outcomes']
                if entry.get('kind') == 'autonomy_feedback_ack'])


def latest_feedback(paths, gm_id: str) -> dict:
    state = gm_runner.load_state(paths['state'])
    for entry in reversed(state['sessions'][gm_id]['outcomes']):
        if entry.get('kind') == 'autonomy_feedback_ack':
            return entry
    return {}


def causal_counterfactual(paths, bad_module_bytes) -> dict:
    """Replay the preserved BAD candidate bytes against fresh, unmutated starting facts.

    Any retry counter, transient marker or host-fixture change must not make the defective
    lookup succeed: only corrected code may. The real acceptance script runs directly with the
    bad bytes and must still report runtime_mechanism_error before install/use, while the
    freshly seeded save stays byte-identical."""
    root = paths['root'] / 'counterfactual'
    root.mkdir(parents=True, exist_ok=True)
    fresh_save = root / 'fresh-world.json'
    seed_out = root / 'seed.json'
    godot = paths['policy_doc']['runtime']['godot']
    seeded = subprocess.run(
        [godot, '--headless', '--path', str(paths['deployment']), '--script',
         'res://tests/gm_autonomy_acceptance.gd', '--', '--save=' + str(fresh_save),
         '--phase=seed', '--nonce=counterfactual-seed', '--allow-create=yes',
         '--out=' + str(seed_out)],
        capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=240)
    marker = root / 'transient-retry-marker.txt'
    marker.write_text('manipulated', encoding='utf-8')
    marker.unlink()
    gm_runner.save_json(root / 'attempt-counts.json',
                        {'attempt': 0, 'retry': 0, 'defect_once': 'cleared'})
    bad_path = root / 'replayed_bad_module.gd'
    bad_path.write_bytes(bad_module_bytes)
    before = gm_runner.sha256_file(fresh_save)
    replay_out = root / 'replay.json'
    replay = subprocess.run(
        [godot, '--headless', '--path', str(paths['deployment']), '--script',
         'res://tests/gm_autonomy_acceptance.gd', '--', '--save=' + str(fresh_save),
         '--manifest=' + str(bad_path), '--release-digest=counterfactual-bad',
         '--issue-id=counterfactual', '--nonce=counterfactual-replay', '--phase=open',
         '--out=' + str(replay_out)],
        capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=240)
    observed = gm_runner.load_json(replay_out) if replay_out.is_file() else None
    return {'seeded': seeded.returncode == 0, 'manipulated': True,
            'exit_code': replay.returncode, 'observed': observed,
            'save_sha_before': before,
            'save_sha_after': gm_runner.sha256_file(fresh_save),
            'replay_stdout_tail': replay.stdout[-400:]}


def scenario_checks(scenario: str) -> dict:
    paths = provision(scenario, scenario)
    checks = []
    try:
        if scenario == 'production_missing':
            finished, payload = run_cycle(paths, scenario)
            add(checks, 'exit_is_usage_preflight', finished.returncode == 2, finished.returncode)
            add(checks, 'kind_missing_requirements',
                (payload or {}).get('kind') == 'missing_requirements', payload)
            add(checks, 'lists_concrete_missing_inputs',
                len((payload or {}).get('missing') or []) >= 2, (payload or {}).get('missing'))
            add(checks, 'no_model_dispatch_happened', not paths['log'].exists())
        elif scenario == 'wrong_world':
            finished, payload = run_cycle(paths, scenario)
            add(checks, 'exit_is_stale', finished.returncode == 3, finished.returncode)
            add(checks, 'kind_stale_world', (payload or {}).get('kind') == 'stale_world', payload)
            add(checks, 'no_model_dispatch_happened', not paths['log'].exists())
        elif scenario == 'no_action':
            finished, payload = run_cycle(paths, scenario)
            add(checks, 'exit_ok', finished.returncode == 0, finished.stderr[-400:])
            add(checks, 'status_no_action', (payload or {}).get('status') == 'no_action', payload)
            batches = (payload or {}).get('usage', {}).get('dispatch_batches', {})
            add(checks, 'no_coding_dispatch',
                batches.get('observe') == 1 and not batches.get('code'),
                (payload or {}).get('usage'))
            add(checks, 'nothing_published',
                not (paths['deployment'] / 'capabilities' /
                     'gm_autonomy_trial_well.v1.json').exists())
        elif scenario == 'out_of_policy':
            finished, payload = run_cycle(paths, scenario)
            add(checks, 'exit_is_precondition', finished.returncode == 6, finished.returncode)
            add(checks, 'blocked_scope_rejected',
                (payload or {}).get('blocked_reason') == 'scope_rejected_by_policy', payload)
            batches = (payload or {}).get('usage', {}).get('dispatch_batches', {})
            add(checks, 'no_coding_dispatch',
                batches.get('observe') == 1 and not batches.get('code'),
                (payload or {}).get('usage'))
            add(checks, 'policy_errors_recorded',
                bool((payload or {}).get('declined')), (payload or {}).get('declined'))
        elif scenario == 'unknown_usage':
            finished, payload = run_cycle(paths, scenario)
            add(checks, 'exit_is_accounting', finished.returncode == 5, finished.returncode)
            add(checks, 'unknown_usage_blocked',
                'unknown' in str((payload or {}).get('blocked_reason')), payload)
            add(checks, 'unknown_cost_recorded_in_state',
                any(record.get('unresolved') for record in
                    gm_runner.load_state(paths['state'])['sessions'].values()))
            before = call_log_counts(paths)
            run_cycle(paths, scenario)
            add(checks, 'no_second_dispatch_while_unknown', call_log_counts(paths) == before,
                {'before': before, 'after': call_log_counts(paths)})
        elif scenario == 'never_passes':
            finished, payload = run_cycle(paths, scenario)
            add(checks, 'exit_is_runtime_failure', finished.returncode == 1, finished.returncode)
            add(checks, 'attempt_limit_stopped_the_loop',
                'max_attempts_per_issue' in str((payload or {}).get('blocked_reason')), payload)
            add(checks, 'bounded_number_of_code_dispatches',
                (payload or {}).get('usage', {}).get('dispatch_batches', {}).get('code') == 3,
                (payload or {}).get('usage'))
            add(checks, 'nothing_published',
                not (paths['deployment'] / 'capabilities' /
                     'gm_autonomy_trial_well.v1.json').exists())
        elif scenario == 'tamper_host_check':
            protected = ROOT / 'tools' / 'validate_gm_autonomy.py'
            before = gm_runner.sha256_file(protected)
            finished, payload = run_cycle(paths, scenario)
            add(checks, 'exit_is_runtime_failure', finished.returncode == 1, finished.returncode)
            add(checks, 'out_of_scope_tamper_refused',
                'out_of_scope' in str((payload or {}).get('blocked_reason')), payload)
            add(checks, 'host_check_file_unchanged', gm_runner.sha256_file(protected) == before)
            add(checks, 'nothing_published',
                not (paths['deployment'] / 'capabilities' /
                     'gm_autonomy_trial_well.v1.json').exists())
        elif scenario == 'release_conflict':
            finished, payload = run_cycle(paths, scenario)
            add(checks, 'exit_is_precondition', finished.returncode == 6, finished.returncode)
            add(checks, 'release_conflict_refused',
                (payload or {}).get('blocked_reason') == 'release_conflict', payload)
            target = paths['deployment'] / 'capabilities' / 'gm_autonomy_trial_well.v1.json'
            add(checks, 'other_writers_bytes_preserved',
                target.read_text(encoding='utf-8') == 'stale bytes from another writer')
        elif scenario == 'publish_race':
            finished, payload = run_cycle(paths, scenario)
            add(checks, 'exit_is_unacceptable_source', finished.returncode == 4,
                finished.returncode)
            add(checks, 'changed_bytes_refused_before_mutation',
                (payload or {}).get('blocked_reason') == 'candidate_bytes_changed_after_gate',
                (payload or {}).get('blocked_reason'))
            target = paths['deployment'] / 'capabilities' / 'gm_autonomy_trial_well.v1.json'
            add(checks, 'deployment_target_untouched_by_the_refusal', not target.exists())
        elif scenario == 'installed_unused':
            finished, payload = run_cycle(paths, scenario)
            add(checks, 'exit_is_runtime_verification_failure', finished.returncode == 1,
                finished.returncode)
            add(checks, 'installed_but_unused_recorded',
                (payload or {}).get('blocked_reason') == 'installed_but_unused',
                (payload or {}).get('blocked_reason'))
            cycle = load_cycle(paths)
            verify = (cycle.get('stages') or {}).get('verify') or {}
            add(checks, 'installed_true_used_false_recorded',
                verify.get('installed') is True and verify.get('used') is False
                and verify.get('installed_but_unused') is True, verify.get('installed_but_unused'))
            gm_id = cycle.get('gm_id')
            ack = latest_feedback(paths, gm_id)
            add(checks, 'failed_verification_feedback_delivered',
                feedback_count(paths, gm_id) == 1, gm_id)
            add(checks, 'owner_acknowledged_the_failed_verification_with_a_repair_decision',
                bool(ack.get('acknowledged') and ack.get('decision') == 'repair'), ack)
            add(checks, 'seed_fixture_preceded_publication',
                bool((paths.get('seed') or {}).get('observed')), paths.get('seed'))
            add(checks, 'installed_but_unused_did_not_open_a_repair_round',
                not load_cycle(paths).get('repair_rounds'),
                load_cycle(paths).get('repair_rounds'))
            add(checks, 'no_extra_coding_dispatch_for_installed_but_unused',
                (payload or {}).get('usage', {}).get('dispatch_batches', {}).get('code') == 1,
                (payload or {}).get('usage'))
        elif scenario == 'repair_after_defect':
            # One truthful runtime defect, one accepted same-owner repair, a real second candidate
            # and a second Godot verification of the same save. Everything here is the labelled
            # offline fixture: the scripted GM decision is not a model result.
            finished, payload = run_cycle(paths, scenario)
            add(checks, 'exit_ok_after_the_repair_round', finished.returncode == 0,
                finished.stderr[-500:])
            add(checks, 'status_completed', (payload or {}).get('status') == 'completed', payload)
            usage = (payload or {}).get('usage') or {}
            add(checks, 'one_observe_and_two_coding_batches',
                usage.get('dispatch_batches', {}).get('observe') == 1
                and usage.get('dispatch_batches', {}).get('code') == 2,
                usage.get('dispatch_batches'))
            cycle = load_cycle(paths)
            stages = cycle.get('stages') or {}
            add(checks, 'exactly_one_repair_round', cycle.get('repair_rounds') == 1,
                cycle.get('repair_rounds'))
            add(checks, 'cycle_is_not_left_blocked',
                cycle.get('status') == 'completed' and cycle.get('blocked_reason') is None,
                {'status': cycle.get('status'), 'blocked_reason': cycle.get('blocked_reason')})
            history = (cycle.get('repair_history') or [{}])[0]
            previous = history.get('previous_stages') or {}
            first_verify = previous.get('verify') or {}
            add(checks, 'the_reopened_round_preserved_the_truthful_failure',
                history.get('failed_stage') == 'verify'
                and history.get('blocked_reason') == 'runtime_verification_failed'
                and first_verify.get('status') == 'failed' and first_verify.get('ok') is False
                and first_verify.get('installed') is False
                and first_verify.get('installed_but_unused') is False
                and {'runtime_reports_ok', 'installed', 'used_not_invented'}
                <= set(first_verify.get('failed_checks') or ()),
                {k: history.get(k) for k in ('failed_stage', 'blocked_reason', 'failed_checks')})
            add(checks, 'the_first_failure_came_from_the_labelled_defect',
                'labelled fault injection' in json.dumps(first_verify.get('runs') or []),
                first_verify.get('observation', {}).get('phase'))
            add(checks, 'the_first_candidate_really_reached_the_trial_installation',
                (previous.get('publish') or {}).get('status') == 'done')
            first_ack = (previous.get('feedback') or {}).get('acknowledgement') or {}
            add(checks, 'the_owner_asked_for_the_repair_after_the_failure',
                first_ack.get('decision') == 'repair', first_ack)
            candidate = stages.get('candidate') or {}
            attempts = candidate.get('attempts') or []
            add(checks, 'the_second_candidate_continues_the_attempt_counter',
                [item.get('attempt') for item in attempts] == [2]
                and candidate.get('attempts_carried') == 1, attempts)
            add(checks, 'two_real_coding_dispatches_happened',
                call_log_counts(paths).get('coding') == 2, call_log_counts(paths))
            verify = stages.get('verify') or {}
            add(checks, 'the_second_verification_passed_every_phase',
                bool(verify.get('checks')) and all(check['ok'] for check in verify['checks']),
                verify.get('checks'))
            second_nonces = [run.get('observed', {}).get('nonce')
                             for run in (verify.get('runs') or [])]
            first_nonces = [run.get('observed', {}).get('nonce')
                            for run in (first_verify.get('runs') or [])]
            add(checks, 'two_independent_verification_runs_with_distinct_nonces',
                bool(second_nonces) and len(second_nonces) == 2
                and all(nonce and nonce not in first_nonces for nonce in second_nonces)
                and len(first_nonces) == 2,
                {'first': first_nonces, 'second': second_nonces})
            second_observation = verify.get('observation') or {}
            add(checks, 'the_second_verification_continued_the_same_save',
                bool(second_observation.get('save_sha256'))
                and second_observation.get('world_id') == WORLD_ID
                and any(check['check'] == 'same_save_continuation' and check['ok']
                        for check in verify.get('checks') or [])
                and int(second_observation.get('resident_consumed_water') or 0) >= 1
                and int(second_observation.get('resident_water_drawn') or 0) >= 1
                and second_observation.get('capability_status') == 'enabled',
                {'save_sha256': second_observation.get('save_sha256'),
                 'consumed': second_observation.get('resident_consumed_water'),
                 'drawn': second_observation.get('resident_water_drawn')})
            saved = gm_runner.load_json(paths['save'])
            receipts = (saved or {}).get('receipts') or {}
            add(checks, 'no_duplicated_install_or_review_command_receipts',
                len([key for key in receipts if 'autonomy-install-1' in str(key)]) == 1
                and len([key for key in receipts if 'autonomy-review-1' in str(key)]) == 1,
                sorted(str(key) for key in receipts))
            marker = paths.get('defect_marker')
            add(checks, 'the_labelled_defect_marker_was_consumed_once',
                marker is not None and not marker.exists())
            add(checks, 'dev_checkout_gained_no_source_file', not (ROOT / SCOPE_FILE).exists())
            gm_id = cycle.get('gm_id')
            add(checks, 'the_same_owner_received_both_receipts',
                bool(gm_id) and feedback_count(paths, gm_id) == 2, gm_id)
            outcomes = [entry for entry in
                        gm_runner.load_state(paths['state'])['sessions'][gm_id]['outcomes']
                        if entry.get('kind') == 'autonomy_feedback_ack']
            add(checks, 'the_final_acknowledgement_is_a_measured_accept',
                bool(outcomes) and outcomes[-1].get('decision') == 'accept'
                and outcomes[-1].get('usage_measured') is True
                and outcomes[-1].get('receipt_sha256')
                == (stages.get('feedback') or {}).get('receipt_sha256'),
                {k: outcomes[-1].get(k) for k in ('decision', 'usage_measured', 'receipt_sha256')}
                if outcomes else None)
            first_publish = previous.get('publish') or {}
            first_files = first_publish.get('files') or []
            failed_root = paths['state'] / 'candidates' / str(cycle.get('issue_id') or '')
            target_name = Path(first_files[0]['target']).name if first_files else ''
            preserved = (sorted(failed_root.rglob(target_name))
                         if target_name and failed_root.is_dir() else [])
            add(checks, 'the_failed_candidate_bytes_were_preserved',
                len(preserved) == 1 and bool(first_files)
                and gm_runner.sha256_file(preserved[0]) == first_files[0].get('sha256'),
                {'preserved': [gm_runner.relative(item) for item in preserved]})
            repaired_abs = Path(candidate.get('candidate_abs') or '.')
            add(checks, 'the_repaired_round_has_its_own_candidate_directory',
                bool(candidate.get('candidate_abs')) and repaired_abs != failed_root
                and repaired_abs.name.endswith('-r1') and repaired_abs.is_dir(),
                {'repaired': gm_runner.relative(repaired_abs) if candidate.get('candidate_abs')
                 else None, 'failed': gm_runner.relative(failed_root)})
            add(checks, 'seed_fixture_preceded_publication',
                bool((paths.get('seed') or {}).get('observed')), paths.get('seed'))
        elif scenario == 'watch_two_delivery':
            # ONE bounded `watch` pays for ONE observe batch, delivers gm-02's first owned claim,
            # then delivers gm-07's ALREADY QUEUED claim from that same batch (no second
            # observation), then goes idle. Both delivered modules are really executed by Godot.
            save_sha_before = gm_runner.sha256_file(paths['save'])
            finished, payload = run_watch(paths, scenario, max_iterations=4, idle_exits=1)
            add(checks, 'watch_exit_ok', finished.returncode == 0, finished.stderr[-600:])
            add(checks, 'watch_status_ok', (payload or {}).get('status') == 'ok', payload)
            calls = call_log_counts(paths)
            add(checks, 'one_observe_batch_of_ten_native_turns',
                calls.get('observe') == 10, calls)
            add(checks, 'two_coding_deliveries_one_per_owner', calls.get('coding') == 2, calls)
            add(checks, 'two_owner_feedback_turns', calls.get('feedback') == 2, calls)
            documents = cycle_documents(paths)
            first = next((d for d in documents.values() if d.get('gm_id') == 'gm-02'), {})
            second = next((d for d in documents.values() if d.get('gm_id') == 'gm-07'), {})
            add(checks, 'exactly_two_cycles_after_a_failed_third_iteration_idles',
                len(documents) == 2, sorted(documents))
            add(checks, 'the_first_delivery_is_owned_by_gm02',
                bool(first) and first.get('status') == 'completed', first.get('status'))
            add(checks, 'the_second_delivery_is_owned_by_gm07',
                bool(second) and second.get('status') == 'completed', second.get('status'))
            add(checks, 'the_first_cycle_deferred_gm07_from_the_same_observation',
                [item.get('gm_id') for item in first.get('deferred_claims') or []] == ['gm-07'],
                first.get('deferred_claims'))
            add(checks, 'the_second_cycle_consumed_the_first_cycles_durable_queue',
                bool(first.get('cycle_id')) and second.get('queued_from_cycle') == first.get('cycle_id'),
                {'queued_from_cycle': second.get('queued_from_cycle'),
                 'source': first.get('cycle_id')})
            add(checks, 'the_queued_delivery_paid_no_second_observation',
                int((second.get('dispatch_batches') or {}).get('observe', 0)) == 0
                and int(second.get('model_calls') or 0) == 2,
                {'batches': second.get('dispatch_batches'),
                 'model_calls': second.get('model_calls')})
            add(checks, 'the_first_cycle_is_one_observe_one_code_one_feedback',
                (first.get('dispatch_batches') or {}).get('observe') == 1
                and (first.get('dispatch_batches') or {}).get('code') == 1
                and (first.get('dispatch_batches') or {}).get('feedback') == 1,
                first.get('dispatch_batches'))
            first_publish = (first.get('stages') or {}).get('publish') or {}
            second_publish = (second.get('stages') or {}).get('publish') or {}
            first_files = first_publish.get('files') or []
            second_files = second_publish.get('files') or []
            add(checks, 'both_cycles_published_exactly_one_release',
                first_publish.get('status') == 'done' and second_publish.get('status') == 'done'
                and int(first.get('publishes_total') or 0) == 1
                and int(second.get('publishes_total') or 0) == 1,
                {'first': first.get('publishes_total'), 'second': second.get('publishes_total')})
            add(checks, 'the_two_releases_are_behaviorally_different_bytes',
                bool(first_files) and bool(second_files)
                and first_files[0]['sha256'] != second_files[0]['sha256']
                and first_files[0]['target'] == second_files[0]['target']
                == 'capabilities/well_stock_lookup.gd',
                {'first': first_files[0].get('sha256') if first_files else None,
                 'second': second_files[0].get('sha256') if second_files else None})
            add(checks, 'the_second_release_replaced_the_accepted_first_release_as_its_base',
                bool(first_files) and bool(second_files)
                and second_files[0].get('previous_sha256') == first_files[0].get('sha256'),
                {'previous_sha256': second_files[0].get('previous_sha256') if second_files else None,
                 'first_release': first_files[0].get('sha256') if first_files else None})
            first_verify = (first.get('stages') or {}).get('verify') or {}
            first_obs = first_verify.get('observation') or {}
            first_open = next((run.get('observed') or {} for run in (first_verify.get('runs') or [])
                               if run.get('phase') == 'open'), {})
            first_open_obs = first_open.get('observation') or {}
            add(checks, 'the_first_release_installed_and_drew_exactly_once',
                first_verify.get('installed') is True and first_verify.get('used') is True
                and first_open_obs.get('current_mechanism_code') == 'well_stock_available'
                and int(first_open_obs.get('resident_water_drawn') or 0) == 1
                and int(first_open_obs.get('well_water', -1)) == 0,
                {'mechanism': first_open_obs.get('current_mechanism_code'),
                 'water_drawn': first_open_obs.get('resident_water_drawn'),
                 'well_water': first_open_obs.get('well_water')})
            second_verify = (second.get('stages') or {}).get('verify') or {}
            second_obs = second_verify.get('observation') or {}
            second_open = next((run.get('observed') or {}
                                for run in (second_verify.get('runs') or [])
                                if run.get('phase') == 'open'), {})
            second_open_obs = second_open.get('observation') or {}
            add(checks, 'the_second_release_probed_the_depleted_state_on_the_same_save',
                second_verify.get('installed') is True and second_verify.get('used') is True
                and second_open_obs.get('depleted_probe') is True
                and second_open_obs.get('current_mechanism_code') == 'well_stock_empty'
                and second_obs.get('current_mechanism_code') == 'well_stock_empty',
                {'open_mechanism': second_open_obs.get('current_mechanism_code'),
                 'reload_mechanism': second_obs.get('current_mechanism_code'),
                 'depleted_probe': second_open_obs.get('depleted_probe'),
                 'installed_but_unused': second_verify.get('installed_but_unused')})
            add(checks, 'the_second_result_is_not_a_second_drink_or_new_adoption',
                int(second_open_obs.get('resident_water_drawn') or 0) == 1
                and int(second_open_obs.get('water_drawn_this_phase') or 0) == 0
                and int(second_open_obs.get('resident_consumed_water') or 0) >= 1
                and int(second_open_obs.get('well_water', -1)) == 0,
                {'resident_water_drawn': second_open_obs.get('resident_water_drawn'),
                 'water_drawn_this_phase': second_open_obs.get('water_drawn_this_phase'),
                 'well_water': second_open_obs.get('well_water')})
            add(checks, 'the_same_save_stays_byte_identical_after_the_second_release',
                bool(first_obs.get('save_sha256'))
                and second_obs.get('save_sha256') == first_obs.get('save_sha256')
                and gm_runner.sha256_file(paths['save']) == first_obs.get('save_sha256'),
                {'first': first_obs.get('save_sha256'),
                 'second': second_obs.get('save_sha256'),
                 'on_disk': gm_runner.sha256_file(paths['save'])})
            add(checks, 'exact_native_gm_turn_counts',
                int(payload.get('gm_turns') or 0) == 14, payload.get('gm_turns'))
            add(checks, 'the_watch_went_idle_after_two_deliveries',
                int(payload.get('idle_exits') or 0) >= 1
                and 'idle' in str(payload.get('reason') or ''),
                {'idle_exits': payload.get('idle_exits'), 'reason': payload.get('reason')})
            add(checks, 'both_owner_receipts_are_measured_and_distinct',
                feedback_count(paths, 'gm-02') == 1 and feedback_count(paths, 'gm-07') == 1
                and latest_feedback(paths, 'gm-02').get('usage_measured') is True
                and latest_feedback(paths, 'gm-07').get('usage_measured') is True
                and latest_feedback(paths, 'gm-02').get('receipt_sha256')
                != latest_feedback(paths, 'gm-07').get('receipt_sha256'),
                {'gm02': feedback_count(paths, 'gm-02'), 'gm07': feedback_count(paths, 'gm-07')})
            # The bad first version is preserved and causally caught: replayed with
            # --depleted-probe=yes against a COPY of the depleted save it must FAIL, so the
            # second release's changed empty-stock behavior is what actually makes the probe pass.
            counterfactual_root = paths['root'] / 'counterfactual'
            counterfactual_root.mkdir(parents=True, exist_ok=True)
            candidate_root = paths['state'] / 'candidates' / str(first.get('issue_id') or '')
            first_module = (sorted(candidate_root.rglob('well_stock_lookup.gd'))
                            if candidate_root.is_dir() else [])
            bad = counterfactual_root / 'gm02_first_version.gd'
            if first_module:
                bad.write_bytes(first_module[0].read_bytes())
            cf_save = counterfactual_root / 'depleted-copy.json'
            shutil.copyfile(paths['save'], cf_save)
            cf_out = counterfactual_root / 'probe.json'
            cf = subprocess.run(
                [paths['policy_doc']['runtime']['godot'], '--headless', '--path',
                 str(paths['deployment']), '--script', 'res://tests/gm_autonomy_acceptance.gd',
                 '--', '--save=' + str(cf_save), '--manifest=' + str(bad),
                 '--release-digest=counterfactual-first', '--issue-id=counterfactual',
                 '--nonce=counterfactual-probe', '--phase=open', '--depleted-probe=yes',
                 '--out=' + str(cf_out)],
                capture_output=True, text=True, encoding='utf-8', errors='replace', timeout=240)
            cf_observed = gm_runner.load_json(cf_out) if cf_out.is_file() else None
            add(checks, 'the_bad_first_version_depletion_counterfactual_is_caught',
                len(first_module) == 1 and cf.returncode != 0
                and not bool((cf_observed or {}).get('ok', False))
                and str(((cf_observed or {}).get('observation') or {})
                        .get('current_mechanism_code', '')) == 'well_stock_available'
                and gm_runner.sha256_file(cf_save) == gm_runner.sha256_file(paths['save']),
                {'first_module': [gm_runner.relative(item) for item in first_module],
                 'exit_code': cf.returncode,
                 'observed_code': str(((cf_observed or {}).get('observation') or {})
                                      .get('current_mechanism_code', '')),
                 'failures': (cf_observed or {}).get('failures')})
            # A rerun must go idle with no new native turn, publication or save mutation.
            before_calls = call_log_counts(paths)
            before_publishes = sorted((d.get('publishes_total'), d.get('cycle_id'))
                                      for d in documents.values())
            rerun, rerun_payload = run_watch(paths, scenario, max_iterations=4, idle_exits=1)
            add(checks, 'rerun_made_no_new_native_turn',
                rerun.returncode == 0 and call_log_counts(paths) == before_calls,
                {'before': before_calls, 'after': call_log_counts(paths),
                 'exit': rerun.returncode})
            add(checks, 'rerun_made_no_new_publication_or_cycle',
                len(cycle_documents(paths)) == 2
                and sorted((d.get('publishes_total'), d.get('cycle_id'))
                           for d in cycle_documents(paths).values()) == before_publishes
                and bool((rerun_payload or {}).get('no_new_model_call', True)),
                rerun_payload.get('reason'))
            add(checks, 'rerun_made_no_save_mutation',
                gm_runner.sha256_file(paths['save']) == second_obs.get('save_sha256'),
                gm_runner.sha256_file(paths['save']))
        elif scenario == 'causal_repair':
            # The candidate's OWN behaviour is the cause: the first release reads the wrong
            # world key and the running world reports runtime_mechanism_error before install or
            # use; the same owner then releases behaviourally different corrected code whose
            # lookup succeeds, and the same save is used exactly once.
            finished, payload = run_cycle(paths, scenario)
            add(checks, 'exit_ok_after_the_causal_repair', finished.returncode == 0,
                finished.stderr[-500:])
            add(checks, 'status_completed', (payload or {}).get('status') == 'completed', payload)
            usage = (payload or {}).get('usage') or {}
            add(checks, 'one_observe_and_two_coding_batches',
                usage.get('dispatch_batches', {}).get('observe') == 1
                and usage.get('dispatch_batches', {}).get('code') == 2,
                usage.get('dispatch_batches'))
            cycle = load_cycle(paths)
            stages = cycle.get('stages') or {}
            add(checks, 'exactly_two_permitted_publications',
                cycle.get('publishes_total') == 2, cycle.get('publishes_total'))
            add(checks, 'exactly_one_repair_round', cycle.get('repair_rounds') == 1,
                cycle.get('repair_rounds'))
            add(checks, 'cycle_is_not_left_blocked',
                cycle.get('status') == 'completed' and cycle.get('blocked_reason') is None,
                {'status': cycle.get('status'), 'blocked_reason': cycle.get('blocked_reason')})
            history = (cycle.get('repair_history') or [{}])[0]
            previous = history.get('previous_stages') or {}
            first_verify = previous.get('verify') or {}
            first_publish = previous.get('publish') or {}
            add(checks, 'the_first_candidate_failed_before_install_or_use',
                history.get('blocked_reason') == 'runtime_verification_failed'
                and first_verify.get('status') == 'failed'
                and first_verify.get('installed') is False
                and first_verify.get('used') is False
                and first_verify.get('installed_but_unused') is False,
                {k: first_verify.get(k) for k in ('status', 'installed', 'used',
                                                  'installed_but_unused')})
            first_open = ((first_verify.get('runs') or [{}])[0].get('observed') or {})
            add(checks, 'the_failure_is_a_reported_runtime_mechanism_error',
                first_open.get('code') == 'runtime_mechanism_error'
                and (first_open.get('mechanism') or {}).get('resolved_key') == 'wellWater',
                first_open.get('mechanism'))
            failed_checks = set(first_verify.get('failed_checks') or ())
            add(checks, 'the_failure_is_conclusive_not_inconclusive',
                bool(failed_checks)
                and not (failed_checks & set(gm_autonomy.REPAIRABLE_VERIFY_INTEGRITY_CHECKS))
                and failed_checks <= set(gm_autonomy.REPAIRABLE_VERIFY_DEFECT_CHECKS),
                sorted(failed_checks))
            add(checks, 'the_owner_asked_for_the_repair',
                ((previous.get('feedback') or {}).get('acknowledgement') or {}).get('decision')
                == 'repair')
            first_files = first_publish.get('files') or []
            second_files = (stages.get('publish') or {}).get('files') or []
            add(checks, 'the_two_releases_published_behaviorally_different_bytes',
                bool(first_files) and bool(second_files)
                and first_files[0]['sha256'] != second_files[0]['sha256']
                and first_files[0]['target'] == second_files[0]['target']
                == 'capabilities/well_stock_lookup.gd',
                {'first': first_files[0].get('sha256') if first_files else None,
                 'second': second_files[0].get('sha256') if second_files else None})
            add(checks, 'the_second_release_used_the_owned_prior_bytes_as_its_base',
                bool(first_files) and bool(second_files)
                and second_files[0].get('previous_sha256') == first_files[0].get('sha256'),
                second_files[0] if second_files else None)
            deployed = paths['deployment'] / 'capabilities' / 'well_stock_lookup.gd'
            add(checks, 'the_deployed_module_is_the_corrected_release',
                deployed.is_file() and bool(second_files)
                and gm_runner.sha256_file(deployed) == second_files[0]['sha256'])
            verify = stages.get('verify') or {}
            add(checks, 'the_second_verification_passed_every_phase',
                bool(verify.get('checks')) and all(c['ok'] for c in verify['checks']),
                [c['check'] for c in verify.get('checks') or [] if not c['ok']])
            observation = verify.get('observation') or {}
            saved = gm_runner.load_json(paths['save'])
            luna = ((saved or {}).get('residents') or {}).get('fixture:luna') or {}
            add(checks, 'the_same_save_continued_with_exactly_one_water_use',
                observation.get('world_id') == WORLD_ID
                and int(luna.get('memory', {}).get('water_drawn', 0)) == 1
                and int(luna.get('consumed', {}).get('water', 0)) == 1
                and int((saved or {}).get('world', {}).get('well_water', -1)) == 0
                and ((saved or {}).get('world', {}).get('gm_resources', {}).get('rope') == 0)
                and ((saved or {}).get('world', {}).get('gm_resources', {}).get('bucket') == 0),
                {'drawn': luna.get('memory', {}).get('water_drawn'),
                 'consumed': luna.get('consumed', {}).get('water'),
                 'well_water': (saved or {}).get('world', {}).get('well_water')})
            failed_root = paths['state'] / 'candidates' / str(cycle.get('issue_id') or '')
            preserved = (sorted(failed_root.rglob('well_stock_lookup.gd'))
                         if failed_root.is_dir() else [])
            add(checks, 'the_failed_candidate_bytes_were_preserved',
                len(preserved) == 1 and bool(first_files)
                and gm_runner.sha256_file(preserved[0]) == first_files[0]['sha256'],
                [gm_runner.relative(item) for item in preserved])
            add(checks, 'dev_checkout_gained_no_source_file',
                not (ROOT / CAPABILITY_MODULE).exists())
            counter = (causal_counterfactual(paths, preserved[0].read_bytes())
                       if len(preserved) == 1 else {})
            add(checks, 'counterfactual_replayed_bad_bytes_against_fresh_facts',
                bool(counter.get('seeded')) and bool(counter.get('save_sha_before'))
                and counter.get('save_sha_before') == counter.get('save_sha_after'), counter)
            add(checks, 'bad_bytes_still_fail_after_marker_and_count_manipulation',
                counter.get('exit_code') not in (0, None)
                and ((counter.get('observed') or {}).get('code') == 'runtime_mechanism_error'),
                {'exit_code': counter.get('exit_code'),
                 'code': (counter.get('observed') or {}).get('code')})
            add(checks, 'counterfactual_never_installed_or_used',
                (counter.get('observed') or {}).get('installed') is False
                and (counter.get('observed') or {}).get('used') is False,
                counter.get('observed'))
            add(checks, 'seed_fixture_preceded_publication',
                bool((paths.get('seed') or {}).get('observed')), paths.get('seed'))
        elif scenario == 'publish_cap':
            # A policy allowing exactly one publication must stop the reopened round's second
            # release, keep the first release's deployed bytes, and still deliver a receipt.
            finished, payload = run_cycle(paths, scenario)
            add(checks, 'cycle_stopped_on_the_publish_cap',
                finished.returncode != 0
                and (payload or {}).get('blocked_reason') == 'max_publishes_reached',
                {'returncode': finished.returncode,
                 'blocked_reason': (payload or {}).get('blocked_reason')})
            cycle = load_cycle(paths)
            add(checks, 'only_one_publication_was_counted', cycle.get('publishes_total') == 1,
                cycle.get('publishes_total'))
            add(checks, 'exactly_one_repair_round', cycle.get('repair_rounds') == 1,
                cycle.get('repair_rounds'))
            stages = cycle.get('stages') or {}
            publish = stages.get('publish') or {}
            add(checks, 'the_second_release_was_refused_not_skipped',
                publish.get('status') == 'refused' and publish.get('publishes_total') == 1,
                publish.get('reason'))
            add(checks, 'the_repaired_candidate_passed_the_host_gate',
                (stages.get('validate') or {}).get('ok') is True,
                (stages.get('validate') or {}).get('checks'))
            history = (cycle.get('repair_history') or [{}])[0]
            first_publish = ((history.get('previous_stages') or {}).get('publish') or {})
            first_files = first_publish.get('files') or []
            add(checks, 'the_first_release_really_happened',
                first_publish.get('status') == 'done' and len(first_files) == 1
                and bool(first_publish.get('release_digest')),
                first_publish.get('release_digest'))
            target = paths['deployment'] / 'capabilities' / 'gm_autonomy_trial_well.v1.json'
            add(checks, 'the_deployed_bytes_are_still_the_first_release',
                bool(first_files) and target.is_file()
                and gm_runner.sha256_file(target) == first_files[0].get('sha256'),
                {'target_exists': target.is_file(),
                 'deployed_sha256': gm_runner.sha256_file(target),
                 'first_release_sha256': (first_files[0].get('sha256') if first_files else None)})
            gm_id = cycle.get('gm_id')
            add(checks, 'the_stopped_round_still_received_a_receipt',
                bool(gm_id) and feedback_count(paths, gm_id) == 2, gm_id)
            add(checks, 'the_same_owner_owned_both_rounds',
                bool(gm_id) and bool(((history.get('previous_stages') or {}).get('feedback')
                                      or {}).get('acknowledgement')), gm_id)
            add(checks, 'seed_fixture_preceded_publication',
                bool((paths.get('seed') or {}).get('observed')), paths.get('seed'))
        elif scenario in ('happy', 'interrupt'):
            checked = happy_or_interrupt(paths, scenario, checks)
            add(checks, 'scenario_completed', bool(checked))
        else:
            add(checks, 'known_scenario', False, scenario)
    finally:
        cleanup(paths)
    return {'kind': 'gm_autonomy_scenario', 'scenario': scenario,
            'ok': bool(checks) and all(check['ok'] for check in checks), 'checks': checks,
            'cycle_dir': gm_runner.relative(cycle_dir(paths)) if cycle_dir(paths) else None}

def happy_or_interrupt(paths, scenario: str, checks) -> bool:
    if scenario == 'interrupt':
        finished, payload = run_cycle(paths, scenario, stop_after='candidate')
        add(checks, 'interrupted_run_paused', (payload or {}).get('status') == 'paused', payload)
        paused = load_cycle(paths)
        add(checks, 'paused_after_the_paid_candidate_stage',
            paused.get('stages', {}).get('candidate', {}).get('status') == 'done'
            and paused.get('stages', {}).get('publish', {}).get('status', 'pending') == 'pending',
            paused.get('stage_status'))
        dispatch_counts = call_log_counts(paths)
        add(checks, 'interrupt_left_ten_observations_and_two_code_attempts',
            dispatch_counts.get('observe') == 10 and dispatch_counts.get('coding') == 2,
            dispatch_counts)
        finished, payload = run_cycle(paths, scenario)
        add(checks, 'resumed_run_completed', (payload or {}).get('status') == 'completed', payload)
        after = call_log_counts(paths)
        add(checks, 'no_duplicate_model_call_after_restart',
            after.get('observe', 0) == dispatch_counts.get('observe', 0)
            and after.get('coding', 0) == dispatch_counts.get('coding', 0),
            {'before': dispatch_counts, 'after': after,
             'note': 'the resume must not re-dispatch observation or coding; the later feedback '
                     'turn is the required delivery of the verification outcome, not a replay'})
    else:
        finished, payload = run_cycle(paths, scenario)
        add(checks, 'exit_ok', finished.returncode == 0, finished.stderr[-400:])
        add(checks, 'status_completed', (payload or {}).get('status') == 'completed', payload)
        usage = (payload or {}).get('usage') or {}
        add(checks, 'one_observe_batch_and_two_code_batches',
            usage.get('dispatch_batches', {}).get('observe') == 1
            and usage.get('dispatch_batches', {}).get('code') == 2, usage)
        add(checks, 'one_observe_batch_counts_ten_model_calls_not_one',
            int(usage.get('model_calls') or 0) >= 10, usage)
    cycle = load_cycle(paths)
    stages = cycle.get('stages', {})
    attempts = stages.get('candidate', {}).get('attempts') or []
    add(checks, 'first_attempt_failed_a_host_check',
        bool(attempts) and attempts[0].get('status') == 'scope_tests_failed', attempts)
    add(checks, 'same_gm_repaired_automatically',
        len(attempts) >= 2 and attempts[1].get('status') == 'ok' and attempts[1].get('attempt') == 2,
        attempts)
    add(checks, 'host_gate_passed', bool(stages.get('validate', {}).get('ok')))
    add(checks, 'gm_claimed_from_evidence_without_preselection',
        cycle.get('gm_id') in ('gm-02', 'gm-07') and bool(cycle.get('issue_id')), cycle.get('gm_id'))
    add(checks, 'second_claim_deferred_to_serialize_coding',
        [item['gm_id'] for item in cycle.get('deferred_claims') or []] == ['gm-07'],
        cycle.get('deferred_claims'))
    deployed = paths['deployment'] / 'capabilities' / 'gm_autonomy_trial_well.v1.json'
    add(checks, 'published_into_the_trial_checkout', deployed.is_file())
    manifest_errors = validate_manifest_document(
        json.loads(deployed.read_text(encoding='utf-8-sig'))) if deployed.is_file() else ['absent']
    add(checks, 'published_manifest_is_valid', not manifest_errors, manifest_errors)
    deployment = paths['deployment'].resolve()
    add(checks, 'deployment_is_a_disposable_checkout',
        deployment != ROOT.resolve() and (ROOT / 'tmp').resolve() in deployment.parents
        and not (deployment / '.git').is_file())
    add(checks, 'dev_checkout_gained_no_source_file', not (ROOT / SCOPE_FILE).exists())
    verify = stages.get('verify', {})
    add(checks, 'runtime_checks_all_true',
        bool(verify.get('checks')) and all(check['ok'] for check in verify['checks']),
        verify.get('checks'))
    add(checks, 'installed_and_used_in_the_running_fixture',
        bool(verify.get('installed') and verify.get('used')),
        {'installed': verify.get('installed'), 'used': verify.get('used')})
    observation = verify.get('observation') or {}
    add(checks, 'same_save_continuation_facts',
        int(observation.get('resident_consumed_water') or 0) >= 1
        and int(observation.get('resident_water_drawn') or 0) >= 1
        and observation.get('capability_status') == 'enabled'
        and int(observation.get('well_water', -1)) == 0, observation)
    gm_id = cycle.get('gm_id')
    ack = latest_feedback(paths, gm_id)
    receipt_sha = (stages.get('feedback') or {}).get('receipt_sha256')
    add(checks, 'feedback_delivered_to_the_claiming_gm', feedback_count(paths, gm_id) == 1, gm_id)
    add(checks, 'gm_returned_a_structured_acknowledgement',
        bool(ack.get('acknowledged') and ack.get('decision') and ack.get('next_work')), ack)
    add(checks, 'acknowledgement_is_bound_to_the_receipt_sha',
        bool(receipt_sha) and ack.get('receipt_sha256') == receipt_sha,
        {'cycle_receipt_sha256': receipt_sha, 'ack_receipt_sha256': ack.get('receipt_sha256')})
    add(checks, 'feedback_turn_usage_was_persisted', ack.get('usage_measured') is True, ack)
    if scenario == 'interrupt':
        return True
    published_utc = stages['publish']['published_utc']
    before = call_log_counts(paths)
    finished, payload = run_cycle(paths, scenario)
    add(checks, 'rerun_completed', (payload or {}).get('status') == 'completed', payload)
    add(checks, 'rerun_made_no_duplicate_model_call', call_log_counts(paths) == before)
    again = load_cycle(paths)
    add(checks, 'rerun_made_no_duplicate_release',
        again['stages']['publish']['published_utc'] == published_utc)
    add(checks, 'rerun_made_no_duplicate_receipt', feedback_count(paths, gm_id) == 1)
    return True


def command_run(args) -> int:
    FIXTURE_ROOT.mkdir(parents=True, exist_ok=True)
    scenarios = args.scenario or list(SCENARIOS)
    summaries = []
    for scenario in scenarios:
        try:
            summary = scenario_checks(scenario)
        except Exception as error:  # a harness bug is reported, never hidden
            summary = {'kind': 'gm_autonomy_scenario', 'scenario': scenario, 'ok': False,
                       'checks': [], 'error': repr(error)}
        gm_runner.save_json(FIXTURE_ROOT / ('validate-' + scenario + '.json'), summary)
        summaries.append(summary)
        print(json.dumps({'scenario': scenario, 'ok': summary['ok'],
                          'failed': [check['check'] for check in summary.get('checks', [])
                                     if not check['ok']],
                          'error': summary.get('error')}, ensure_ascii=False))
    overall = {'kind': 'gm_autonomy_harness', 'ok': all(item['ok'] for item in summaries),
               'scenarios': [item['scenario'] for item in summaries],
               'evidence_dir': str(FIXTURE_ROOT)}
    print(json.dumps(overall, ensure_ascii=False))
    return 0 if overall['ok'] else 1


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    subparsers = parser.add_subparsers(dest='command', required=True)
    candidate = subparsers.add_parser('validate-candidate',
                                      help='host gate run inside the candidate worktree')
    candidate.add_argument('--candidate', required=True)
    candidate.add_argument('--scope', required=True)
    candidate.add_argument('--policy', required=True)
    candidate.set_defaults(func=command_validate_candidate)
    tamper = subparsers.add_parser('validate-candidate-then-tamper',
                                   help='host gate that then changes the candidate bytes')
    tamper.add_argument('--candidate', required=True)
    tamper.add_argument('--scope', required=True)
    tamper.add_argument('--policy', required=True)
    tamper.set_defaults(func=command_validate_candidate_then_tamper)
    runner = subparsers.add_parser('run', help='provision and drive labelled offline scenarios')
    runner.add_argument('--scenario', action='append', choices=list(SCENARIOS))
    runner.set_defaults(func=command_run)
    return parser


def main(argv=None) -> int:
    args = build_parser().parse_args(argv)
    return args.func(args)


if __name__ == '__main__':
    sys.exit(main())
