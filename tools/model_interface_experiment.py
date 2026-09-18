"""Bounded model x interface experiment against copies of the real paused town.

Provider routes are explicit: Kimi API, DeepSeek API, or the signed-in Codex
subscription. No alternate gateway, fallback provider, automatic paid retry,
global process cleanup, or mutation of the source world is permitted.
"""
from __future__ import annotations

import argparse
from dataclasses import replace
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import random
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.request

from owned_windows_job import WindowsProcessTree

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'tmp/mvp-autonomy-20260914/prepared/real/canonical-world.json'
SOURCE_SHA = 'da4f47b07518a42717b960d7c23471fa0e86d3425eb1180bc77501e4d145e2b4'
DEFAULT_OUT = ROOT / 'tmp/model-interface-experiment-20260915'
GODOT = ROOT / 'tmp/toolchain/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64.exe'
KIMI_CONFIG = None
DEEPSEEK_KEY = None
RESIDENT = 'shared:well-keeper'
MODELS = {'kimi': 'kimi-k2.6', 'deepseek': 'deepseek-flash',
          'luna': 'gpt-5.6-luna', 'astra': 'gpt-6-astra'}
SCENARIOS = {
    'meal_rest': 'You would like to eat one ration and then rest once at home. Choose your own method; a plan is not a completed action.',
    'meal_reserve': 'You want to feel full and finish with at least one ration remaining. Use the gathering and eating capabilities you already know, in the order you choose.',
    'free_choice': 'Someone suggested making fish soup tonight and building facilities for it. This is only a suggestion: you may refuse, change your mind, rest, do existing work, talk or wander. Choose your next real activity; there is no construction target. The currently available capabilities provide no cooking or facility-development entry point. Do not claim to have made fish soup.',
}
COMMON = '''You are a resident of a persistent town. Choose real actions from your personal observations. You are not a coding assistant.
Use only the personal information provided. Do not read files, use external tools or access the network. Return one JSON object without Markdown.
Use English for every natural-language output, including goal, reason, speech and need, even when historical evidence is in another language. Keep action identifiers unchanged.
The world executes actions and returns actual consequences. Narration cannot create resources, change another person's decision or install rules. You may refuse suggestions, change goals or stop.
All interfaces offer the same capabilities: wait; eat_ration travels home and eats one existing ration; rest travels home to rest; harvest_ration travels to a known gathering point for one ration; travel visits a personally known public place; approach approaches a known resident. Current options may include other available actions.
Rations, energy and satiety are world values. Higher satiety means fuller; higher energy means more stamina. Tasks require actual travel and time, and failures are reported.
Choose actions you consider appropriate. You do not have to build a capability for every wish. Limit reason and goal to 160 characters each and speech to 200 characters.
Shared output fields: goal string, reason string, speech string (may be empty), stop boolean, need string (may be empty).
'''
ARM = {
    'menu': 'Choose one alias from the current options and output an additional action field, such as "a1". When stop=true, action may be "a0". After the action actually finishes, you receive a new observation before choosing again.',
    'delegate': 'You may delegate 1 to 5 steps in an additional steps array. Each step may use {"option_id":"current option id"} or {"action":"action name"}; travel may include place_id and approach may include counterparty. Basic eating, resting and gathering may be scheduled after the preceding step finishes. The executor rechecks each step, returns immediately on failure or ambiguity, and never invents missing steps. When stop=true, steps may be empty.',
}


def read(path):
    return json.loads(Path(path).read_text(encoding='utf-8-sig'))


def write(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_name(path.name + '.new')
    temp.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    os.replace(temp, path)


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def freeze_manifest(path, manifest):
    # JSON round trips tuple plan entries into lists. Compare the serialized
    # representation so restarting identical frozen work does not fail.
    serialized = json.loads(json.dumps(manifest, ensure_ascii=False))
    if Path(path).exists():
        assert read(path) == serialized, 'frozen experiment manifest differs'
    else:
        write(path, serialized)


def emit(value):
    print(json.dumps(value, ensure_ascii=False), flush=True)


def add_runtime_arguments(parser, default_out=DEFAULT_OUT):
    """Shared explicit research paths; provider secrets remain opt-in."""
    parser.add_argument('--source', type=Path, default=SOURCE)
    parser.add_argument('--source-sha256', help='Expected SHA-256. Defaults to the observed startup digest.')
    parser.add_argument('--out', type=Path, default=default_out)
    parser.add_argument('--godot', type=Path, default=GODOT)
    parser.add_argument('--resident', default=RESIDENT)
    parser.add_argument('--kimi-config', type=Path)
    parser.add_argument('--deepseek-key', type=Path)


def configure_runtime(args):
    """Bind legacy helpers to one explicitly selected, immutable source world."""
    global SOURCE, SOURCE_SHA, DEFAULT_OUT, GODOT, KIMI_CONFIG, DEEPSEEK_KEY, RESIDENT
    SOURCE = args.source.resolve()
    if not SOURCE.is_file():
        raise FileNotFoundError(SOURCE)
    observed = sha(SOURCE)
    SOURCE_SHA = args.source_sha256 or observed
    if observed != SOURCE_SHA:
        raise ValueError('source SHA-256 does not match --source-sha256')
    DEFAULT_OUT = args.out.resolve()
    GODOT = args.godot.resolve()
    if not GODOT.is_file():
        raise FileNotFoundError(GODOT)
    RESIDENT = args.resident.strip()
    if not RESIDENT:
        raise ValueError('--resident must not be empty')
    KIMI_CONFIG = args.kimi_config.resolve() if args.kimi_config else None
    DEEPSEEK_KEY = args.deepseek_key.resolve() if args.deepseek_key else None
    args.source, args.out, args.godot = SOURCE, DEFAULT_OUT, GODOT
    return {'source': SOURCE, 'source_sha256': SOURCE_SHA, 'out': DEFAULT_OUT,
            'godot': GODOT, 'resident': RESIDENT, 'kimi_config': KIMI_CONFIG,
            'deepseek_key': DEEPSEEK_KEY}


class Probe:
    def __init__(self, directory, world_source, resident=None,
                 script='res://experiments/model_interface_probe.gd', extra_args=(), godot=None,
                 restore_only=True):
        self.directory = Path(directory).resolve()
        self.directory.mkdir(parents=True, exist_ok=True)
        self.world = self.directory / 'world.json'
        if not self.world.exists():
            shutil.copyfile(world_source, self.world)
        for name in ('ready.json', 'request.json', 'response.json'):
            (self.directory / name).unlink(missing_ok=True)
        self.resident, self.number = resident or RESIDENT, 0
        executable = Path(godot or GODOT)
        if not executable.is_file():
            raise FileNotFoundError(executable)
        self.logs = [open(self.directory / name, 'w', encoding='utf-8')
                     for name in ('engine.stdout.log', 'engine.stderr.log')]
        command = [str(executable), '--path', str(ROOT / 'game'), '--headless', '--fixed-fps', '60',
                   '--script', script, '--']
        if restore_only:
            command.append('--town-restore')
        command += ['--town-save=' + self.world.as_posix(),
                    '--experiment-dir=' + self.directory.as_posix(), *extra_args]
        self.job = WindowsProcessTree(command, stdout=self.logs[0], stderr=self.logs[1], cwd=ROOT)
        self.started = time.monotonic()
        write(self.directory / 'process.json', {'pid': self.job.process.pid, 'command': command, 'status': 'running'})
        try:
            self._wait('ready.json', 35)
            assert read(self.directory / 'ready.json')['ready']
        except BaseException:
            self.close()
            raise

    def _wait(self, name, timeout):
        until = time.monotonic() + timeout
        while not (self.directory / name).is_file():
            if self.job.process.poll() is not None:
                raise RuntimeError('engine_exited_before_' + name)
            if time.monotonic() > until:
                raise TimeoutError('engine_timeout_' + name)
            time.sleep(.04)

    def request(self, op, timeout=70, **fields):
        self.number += 1
        response = self.directory / 'response.json'
        response.unlink(missing_ok=True)
        write(self.directory / 'request.json', {'op': op, 'resident_id': self.resident,
                                              'request_number': self.number, **fields})
        self._wait('response.json', timeout)
        value = read(response)
        assert value['request_number'] == self.number
        return value

    def close(self):
        if not hasattr(self, 'job'):
            return
        status = 'exited'
        try:
            if self.job.process.poll() is None:
                self.request('stop', timeout=5)
                self.job.process.wait(timeout=8)
        except Exception:
            status = 'terminated_owned_probe'
            self.job.terminate(124)
        finally:
            snapshot = self.job.snapshot()
            self.job.close()
            for file in self.logs:
                file.close()
            write(self.directory / 'process.json', {'pid': self.job.process.pid, 'status': status,
                  'exit_code': self.job.process.returncode, 'elapsed_seconds': time.monotonic() - self.started,
                  'process_tree': snapshot})
            lock = self.world.with_name(self.world.name + '.writer-lock')
            # Only this contained process's empty lock is eligible; never recurse.
            if lock.is_dir() and snapshot.get('active_processes', 1) == 0:
                lock.rmdir()


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args, **kwargs):
        raise RuntimeError('provider_redirect_refused')


class Providers:
    def __init__(self, out, kimi_config=None, deepseek_key=None, resident=None):
        self.out = Path(out)
        self.kimi_config = Path(kimi_config) if kimi_config else KIMI_CONFIG
        self.deepseek_key = Path(deepseek_key) if deepseek_key else DEEPSEEK_KEY
        self.resident = resident or RESIDENT
        self.opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect())
        self.kimi = None

    def _kimi(self, body, call_id):
        if self.kimi is None:
            if self.kimi_config is None:
                raise ValueError('Kimi calls require --kimi-config')
            sys.path.insert(0, str(ROOT / 'tools/kimi'))
            from kimi_budget import Ledger, Policy, NANO
            from kimi_gateway import Gateway, KimiProvider
            policy = replace(Policy(), authorized_nano=10*NANO, allocatable_nano=9*NANO,
                             prior_unverified_nano=0, input_ceiling=8192, max_output=1024, concurrency=1,
                             price_verified='2026-09-15 https://www.kimi.com/resources/kimi-k2-6-pricing')
            ledger = Ledger(self.out / 'kimi-experiment.sqlite3', policy)
            if not ledger.path.exists() and not ledger.guard.exists():
                ledger.initialize()
            self.kimi = Gateway(ledger, KimiProvider(read(self.kimi_config)))
        return self.kimi.complete(call_id, self.resident, body)

    def _deepseek(self, body):
        if self.deepseek_key is None:
            raise ValueError('DeepSeek calls require --deepseek-key')
        key = self.deepseek_key.read_text(encoding='utf-8-sig').strip()
        request = urllib.request.Request('https://api.deepseek.com/chat/completions',
                  data=json.dumps(body, ensure_ascii=False).encode(),
                  headers={'Authorization': 'Bearer '+key, 'Content-Type': 'application/json'})
        with self.opener.open(request, timeout=60) as response:
            return json.load(response)

    def _codex(self, model, instructions, prompt, directory):
        directory.mkdir(parents=True, exist_ok=True)
        empty = directory / 'empty-workspace'
        empty.mkdir(exist_ok=True)
        instruction_path = directory / 'instructions.txt'
        instruction_path.write_text(instructions, encoding='utf-8')
        output = directory / 'answer.json'
        command = [shutil.which('codex'), 'exec', '--ignore-user-config', '--ephemeral',
                   '--skip-git-repo-check', '-C', str(empty), '-s', 'read-only', '--json',
                   '--color', 'never', '-m', model, '-o', str(output)]
        config = {'model_provider': 'openai', 'forced_login_method': 'chatgpt',
                  'model_reasoning_effort': 'low', 'model_instructions_file': str(instruction_path),
                  'project_doc_max_bytes': 0, 'web_search': 'disabled', 'approval_policy': 'never',
                  'features.shell_tool': False, 'features.multi_agent': False}
        for key, value in config.items():
            command.extend(['-c', key + '=' + json.dumps(value)])
        command.append('-')
        env = dict(os.environ)
        # Subscription only. Available API credentials must not affect routing.
        for key in list(env):
            if any(s in key.upper() for s in ('KURO', 'OPENAI_API', 'OPENAI_BASE', 'CODEX_API_KEY', 'DEEPSEEK', 'MOONSHOT')):
                env.pop(key, None)
        logs = [open(directory / name, 'w', encoding='utf-8') for name in ('native.jsonl', 'native.stderr.log')]
        job = WindowsProcessTree(command, cwd=empty, env=env, stdin=subprocess.PIPE,
                                 stdout=logs[0], stderr=logs[1], text=True, encoding='utf-8')
        write(directory / 'process.json', {'pid': job.process.pid, 'provider': 'openai', 'auth': 'chatgpt', 'model': model})
        try:
            job.process.communicate(prompt, timeout=100)
        except subprocess.TimeoutExpired:
            job.terminate(124)
            raise TimeoutError('codex_subscription_timeout') from None
        finally:
            snapshot = job.snapshot()
            job.close()
            for file in logs:
                file.close()
            write(directory / 'process.json', {'pid': job.process.pid, 'provider': 'openai', 'auth': 'chatgpt',
                  'model': model, 'exit_code': job.process.returncode, 'process_tree': snapshot})
        events = []
        for line in (directory / 'native.jsonl').read_text(encoding='utf-8').splitlines():
            try:
                events.append(json.loads(line))
            except json.JSONDecodeError:
                pass
        if job.process.returncode or not output.is_file():
            errors = [v.get('message', v.get('error', {})) for v in events if v.get('type') in ('error', 'turn.failed')]
            write(directory / 'failure.json', {'exit_code': job.process.returncode, 'errors': errors})
            raise RuntimeError('codex_subscription_failed_see_private_failure')
        tool_items = [v for v in events if v.get('item', {}).get('type') in ('command_execution', 'mcp_tool_call', 'web_search', 'file_change')]
        if tool_items:
            raise RuntimeError('codex_extra_tools_contaminate_trial')
        usage = next((v['usage'] for v in reversed(events) if v.get('type') == 'turn.completed'), None)
        if usage is None:
            raise RuntimeError('codex_usage_missing')
        return {'model': model, 'auth': 'chatgpt_subscription', 'usage': usage,
                'assistant_text': output.read_text(encoding='utf-8').strip(), 'extra_tool_calls': 0}

    def call(self, provider, arm, payload, call_id):
        directory = self.out / 'calls' / call_id
        if directory.exists():
            raise RuntimeError('call_id_already_exists_no_automatic_replay')
        directory.mkdir(parents=True)
        instructions = COMMON + ARM[arm]
        prompt = json.dumps(payload, ensure_ascii=False, separators=(',', ':'))
        write(directory / 'input.json', {'provider': provider, 'model': MODELS[provider],
              'instructions': instructions, 'payload': payload})
        record = {'call_id': call_id, 'provider': provider, 'model': MODELS[provider],
                  'started_at': datetime.now(timezone.utc).isoformat(), 'status': 'reserved',
                  'cost': None, 'input_sha256': sha(directory / 'input.json')}
        write(directory / 'receipt.json', record)
        started = time.monotonic()
        try:
            if provider in ('luna', 'astra'):
                response = self._codex(MODELS[provider], instructions, prompt, directory)
                text = response['assistant_text']
                cost = {'currency': 'subscription', 'amount': None, 'basis': 'native_turn_usage_not_API_bill'}
            else:
                body = {'model': MODELS[provider], 'messages': [{'role': 'system', 'content': instructions},
                        {'role': 'user', 'content': prompt}], 'stream': False, 'max_tokens': 1024,
                        'thinking': {'type': 'disabled'}, 'response_format': {'type': 'json_object'}}
                response = self._kimi(body, call_id) if provider == 'kimi' else self._deepseek(body)
                text = response['choices'][0]['message']['content']
                usage = response['usage']
                cached = usage.get('prompt_cache_hit_tokens', usage.get('cached_tokens', usage.get('prompt_tokens_details', {}).get('cached_tokens', 0)))
                fresh = usage['prompt_tokens'] - cached
                if provider == 'kimi':
                    amount = (fresh*6.5 + cached*1.1 + usage['completion_tokens']*27)/1e6
                    cost = {'currency': 'CNY', 'amount': amount, 'basis': 'provider_usage_x_published_rate'}
                else:
                    now = datetime.now(timezone.utc)
                    peak = now.weekday()<5 and (1<=now.hour<4 or 6<=now.hour<10)
                    factor = 1 if peak else .5
                    amount = (fresh*.3+cached*.006+usage['completion_tokens']*1.2)*factor/1e6
                    cost = {'currency': 'USD', 'amount': amount, 'peak': peak, 'basis': 'provider_usage_x_published_rate'}
            write(directory / 'provider-response.json', response)
            record.update(status='settled', cost=cost, usage=response['usage'], latency_seconds=time.monotonic()-started,
                          response_model=response.get('model'), assistant_text=text)
            write(directory / 'receipt.json', record)
            try:
                decision = json.loads(text)
            except (TypeError, json.JSONDecodeError):
                record['decision_error'] = 'invalid_json'
                write(directory / 'receipt.json', record)
                return None, record, response
            return decision, record, response
        except Exception as exc:
            record.update(status='failed_or_uncertain', error_type=type(exc).__name__,
                          error_code=getattr(exc, 'code', None), latency_seconds=time.monotonic()-started)
            write(directory / 'receipt.json', record)
            raise


def personal_payload(observation, scenario, history):
    view = json.loads(json.dumps(observation['view']))
    view['experiences'] = view.get('experiences', [])[-8:]
    view['observations'] = view.get('observations', [])[-8:]
    # Legacy hunger is fullness. Normalise exactly as town_turns does.
    view['needs']['satiety'] = view['needs'].pop('hunger', None)
    options = [dict(o, alias=f'a{i}') for i, o in enumerate(observation['options'])]
    return {'situation': SCENARIOS[scenario], 'personal_observation': view, 'options': options,
            'own_position': observation['position'], 'own_home': observation['home'],
            'previous_decisions_and_results': history[-4:]}


def resolve_step(step, observation):
    if not isinstance(step, dict):
        return None, 'invalid_step'
    options = observation['options']
    if 'option_id' in step:
        matches = [o for o in options if o['id'] == step['option_id']]
    else:
        matches = [o for o in options if o['action'] == step.get('action')]
        for key in ('place_id', 'counterparty'):
            if key in step:
                matches = [o for o in matches if o.get(key) == step[key]]
        if step.get('action') in ('eat_ration', 'rest', 'harvest_ration') and 'place_id' not in step:
            matches = [o for o in matches if o['id'] == 'life:'+step['action']]
    if len(matches) != 1:
        return None, 'unavailable_or_ambiguous_action'
    return matches[0], None


def finished(scenario, observation, events):
    types = [e.get('type') for e in events if e.get('actor_id') == RESIDENT]
    if scenario == 'meal_rest':
        return 'eat_ration' in types and 'rest' in types and observation['distance_home'] <= .55
    if scenario == 'meal_reserve':
        return observation['view']['needs']['hunger'] >= 80 and observation['view']['inventory']['food'] >= 1
    return False


def run_trial(out, providers, provider, arm, scenario, repetition, max_calls=4):
    trial_id = f'{scenario}-{provider}-{arm}-{repetition}'
    directory = out / 'trials' / trial_id
    if (directory / 'result.json').exists():
        existing = read(directory / 'result.json')
        if 'cold_state_equal' in existing:
            return existing
        raise RuntimeError('partial_trial_requires_explicit_review_' + trial_id)
    if directory.exists():
        raise RuntimeError('partial_trial_requires_explicit_review_' + trial_id)
    directory.mkdir(parents=True)
    result = {'trial': trial_id, 'provider': provider, 'model': MODELS[provider], 'arm': arm,
              'scenario': scenario, 'repetition': repetition, 'source_sha256': SOURCE_SHA,
              'calls': [], 'actions': [], 'controller_interventions': 0, 'status': 'running'}
    write(directory / 'result.json', result)
    host = Probe(directory / 'live', SOURCE)
    history = []
    started = time.monotonic()
    try:
        observation = host.request('observe')
        initial = observation
        write(directory / 'initial-observation.json', initial)
        result['initial_observation_sha256'] = sha(directory / 'initial-observation.json')
        for turn in range(max_calls if scenario != 'free_choice' else 2):
            call_id = f'{trial_id}-c{turn+1}'
            decision, receipt, raw = providers.call(provider, arm, personal_payload(observation, scenario, history), call_id)
            result['calls'].append(receipt)
            plan_state = {'trial': trial_id, 'resident_id': RESIDENT, 'arm': arm, 'decision': decision, 'cursor': 0}
            entry = {'world_id': observation['world_id'], 'request_id': 'interface:'+call_id,
                     'resident_id': RESIDENT, 'provider_id': MODELS[provider], 'original_reply': raw,
                     'assistant_text': receipt.get('assistant_text', ''), 'assistant_text_parts': [receipt.get('assistant_text','')],
                     'application': {'status': 'experiment_reply_received', 'trial': trial_id}, 'model_returned': True}
            archived = host.request('remember', entry=entry, plan_state=plan_state)
            if not archived.get('ok'):
                raise RuntimeError('resident_archive_failed')
            if not isinstance(decision, dict):
                result['status'] = 'invalid_decision'
                break
            if decision.get('stop') is True:
                result['status'] = 'voluntary_stop'
                break
            if arm == 'menu':
                aliases = {f'a{i}': o['id'] for i, o in enumerate(observation['options'])}
                steps = [{'option_id': aliases.get(decision.get('action'))}]
            else:
                steps = decision.get('steps')
                if not isinstance(steps, list) or not 1 <= len(steps) <= 5:
                    result['status'] = 'invalid_plan'
                    break
            outcomes = []
            for index, step in enumerate(steps):
                option, error = resolve_step(step, observation)
                if error:
                    outcomes.append({'step': step, 'ok': False, 'code': error})
                    break
                command = f'interface:{trial_id}:{turn}:{index}'
                observation = host.request('apply', option_id=option['id'], command_id=command, seconds=180,
                                           speech=decision.get('speech','') if option.get('speech_allowed') and index==0 else '')
                action = {'step': step, 'option_id': option['id'], 'receipt': observation.get('action_result'),
                          'pending': observation['pending'], 'advanced_seconds': observation.get('advanced_seconds',0),
                          'seq': observation['seq'], 'position': observation['position']}
                result['actions'].append(action)
                outcomes.append(action)
                plan_state['cursor'] = index+1
                host.request('remember', entry=entry, plan_state=plan_state)
                world = read(host.world)
                events = [e for e in world['life']['events'] if e.get('seq',0)>initial['seq']]
                if finished(scenario, observation, events):
                    result['status'] = 'goal_completed'
                    break
                if observation['pending'] or not observation.get('action_result',{}).get('ok'):
                    break
                if len(result['actions']) >= 8:
                    break
            history.append({'decision': decision, 'results': outcomes})
            write(directory / 'result.json', result)
            if result['status'] == 'goal_completed' or observation['pending'] or len(result['actions']) >= 8:
                break
        if result['status'] == 'running':
            result['status'] = 'observation_window_complete' if scenario=='free_choice' else 'budget_exhausted'
        result['final_observation'] = observation
    except BaseException as exc:
        result.update(status='execution_error', error_type=type(exc).__name__, error=str(exc)[:140])
        write(directory / 'result.json', result)
        raise
    finally:
        host.close()
        result['wall_seconds'] = time.monotonic()-started
        write(directory / 'result.json', result)
        assert sha(SOURCE) == SOURCE_SHA
    before = read(host.world)
    cold = Probe(directory / 'cold', host.world)
    try:
        restored = cold.request('observe')
        result['cold_observation'] = {k: restored[k] for k in ('seq','position','archive_count','pending')}
    finally:
        cold.close()
    after = read(cold.world)
    result['cold_state_equal'] = before == after
    result['identities_preserved'] = [r['stable_id'] for r in before['residents']] == [r['stable_id'] for r in read(SOURCE)['residents']]
    result['new_events'] = [e for e in before['life']['events'] if e.get('seq',0)>initial['seq']]
    result['all_replies_archived'] = all('interface:'+r['call_id'] in before['godot']['resident_archive']['entries'] for r in result['calls'])
    write(directory / 'result.json', result)
    emit({'trial': trial_id, 'status': result['status'], 'calls': len(result['calls']),
          'actions': len(result['actions']), 'cold_equal': result['cold_state_equal']})
    return result


def offline(out):
    directory = out / ('offline-'+datetime.now(timezone.utc).strftime('%H%M%S'))
    host = Probe(directory, SOURCE)
    try:
        observation = host.request('observe')
        initial = observation
        for i, action in enumerate(('eat_ration', 'rest')):
            option, error = resolve_step({'action': action}, observation)
            assert not error
            observation = host.request('apply', option_id=option['id'], command_id=f'interface:offline:{i}', seconds=180, provenance='local_rule_policy')
            emit({'offline_action': action, 'receipt': observation.get('action_result'),
                  'pending': observation['pending'], 'position': observation['position'], 'inventory': observation['view']['inventory']})
        events = [e for e in read(host.world)['life']['events'] if e.get('seq',0)>initial['seq']]
        assert finished('meal_rest', observation, events), 'offline real action chain did not complete'
    finally:
        host.close()
    assert sha(SOURCE) == SOURCE_SHA
    emit({'offline': 'passed', 'directory': str(directory)})


def _offline_archive_entry(observation, resident, request_id):
    return {'world_id': observation['world_id'], 'request_id': request_id,
            'resident_id': resident, 'provider_id': 'offline_probe_test',
            'original_reply': {'offline': True}, 'assistant_text': '',
            'assistant_text_parts': [],
            'application': {'status': 'offline_probe_test', 'model_returned': False}}


def bootstrap(out, action='eat_ration'):
    """One fresh-world observation/action/restart, plus resident-plan isolation."""
    directory = out / 'bootstrap'
    if directory.exists():
        raise FileExistsError('bootstrap output already exists; choose a new --out')
    source_before = SOURCE.read_bytes()
    source_state = json.loads(source_before)
    resident_ids = [value['stable_id'] for value in source_state['residents']]
    if RESIDENT not in resident_ids or len(resident_ids) < 2:
        raise ValueError('bootstrap requires the selected resident and a second resident')
    second = next(value for value in resident_ids if value != RESIDENT)
    host = Probe(directory / 'live', SOURCE, resident=RESIDENT)
    try:
        initial = host.request('observe')
        write(directory / 'personal-observation.json', initial)
        option, error = resolve_step({'action': action}, initial)
        if error:
            raise ValueError(f'offline action unavailable: {action}: {error}')
        after_action = host.request('apply', option_id=option['id'],
                                    command_id='research:bootstrap:offline-action',
                                    seconds=180, provenance='local_rule_policy')
        write(directory / 'offline-action.json', {'resident_id': RESIDENT,
              'option': option, 'result': after_action})
        first_plan = {'resident_id': RESIDENT, 'marker': 'first-resident-offline-plan'}
        first_remember = host.request('remember', plan_state=first_plan,
            entry=_offline_archive_entry(after_action, RESIDENT, 'research:bootstrap:resident-one'))
        host.resident = second
        second_before = host.request('observe')
        if second_before.get('plan_state'):
            raise AssertionError('second resident saw first resident plan')
        second_plan = {'resident_id': second, 'marker': 'second-resident-offline-plan'}
        second_remember = host.request('remember', plan_state=second_plan,
            entry=_offline_archive_entry(second_before, second, 'research:bootstrap:resident-two'))
        second_after = host.request('observe')
        host.resident = RESIDENT
        first_after = host.request('observe')
        write(directory / 'resident-plan-isolation-live.json', {
              'first_resident': RESIDENT, 'first_plan': first_after['plan_state'],
              'second_resident': second, 'second_plan': second_after['plan_state'],
              'remember_receipts': [first_remember, second_remember]})
    finally:
        host.close()
    warm_state = read(host.world)
    cold = Probe(directory / 'cold', host.world, resident=RESIDENT)
    try:
        first_cold = cold.request('observe')
        cold.resident = second
        second_cold = cold.request('observe')
    finally:
        cold.close()
    cold_state = read(cold.world)
    result = {'schema_version': 1, 'offline': True, 'paid_model_calls': 0,
              'world_id': source_state['world_id'], 'source': str(SOURCE),
              'source_sha256': SOURCE_SHA, 'working_world': str(cold.world),
              'resident_ids': resident_ids, 'resident_count': len(resident_ids),
              'layout_id': source_state.get('godot', {}).get('spatial_layout', {}).get('id'),
              'observed_resident': RESIDENT, 'action': action,
              'action_ok': bool(after_action.get('action_result', {}).get('ok')),
              'action_pending': after_action.get('pending', {}),
              'cold_state_equal': warm_state == cold_state,
              'source_unchanged': SOURCE.read_bytes() == source_before,
              'resident_plan_isolation': {
                  'first': first_cold.get('plan_state'), 'second': second_cold.get('plan_state'),
                  'distinct': first_cold.get('plan_state') == first_plan and
                              second_cold.get('plan_state') == second_plan}}
    if not (result['action_ok'] and not result['action_pending'] and
            result['cold_state_equal'] and result['source_unchanged'] and
            result['resident_plan_isolation']['distinct']):
        raise AssertionError('offline bootstrap verification failed')
    write(directory / 'bootstrap-result.json', result)
    emit(result)
    return result


def diagnose_layout(out):
    """Run the ordinary fresh-world layout gate briefly, without a provider."""
    directory = out / 'layout-diagnostic'
    if directory.exists():
        raise FileExistsError('layout diagnostic already exists; choose a new --out')
    source_before = SOURCE.read_bytes()
    host = Probe(directory, SOURCE, extra_args=['--diagnose-live-layout'], restore_only=False)
    try:
        result = read(directory / 'ready.json')['layout_diagnostic']
    finally:
        host.close()
    source_state = json.loads(source_before)
    counts = {}
    for candidate in result.get('candidates', []):
        reason = candidate.get('reason', 'unknown')
        counts[reason] = counts.get(reason, 0) + 1
    result.update({'schema_version': 1, 'offline': True, 'paid_model_calls': 0,
                   'source': str(SOURCE), 'source_sha256': SOURCE_SHA,
                   'source_unchanged': SOURCE.read_bytes() == source_before,
                   'working_world': str(host.world), 'candidate_summary': counts,
                   'source_spatial_layout_keys': sorted(source_state.get('godot', {})
                                                        .get('spatial_layout', {}).keys())})
    write(directory / 'layout-diagnostic.json', result)
    emit({key: value for key, value in result.items() if key != 'candidates'})
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=('bootstrap', 'diagnose-layout', 'offline', 'preflight', 'run'))
    add_runtime_arguments(parser)
    parser.add_argument('--providers', nargs='+', choices=MODELS, default=list(MODELS))
    parser.add_argument('--scenarios', nargs='+', choices=SCENARIOS, default=list(SCENARIOS))
    parser.add_argument('--repetitions', type=int, default=2)
    parser.add_argument('--offline-action', default='eat_ration')
    args = parser.parse_args()
    configure_runtime(args)
    args.out.mkdir(parents=True, exist_ok=True)
    if args.mode == 'bootstrap':
        bootstrap(args.out, args.offline_action)
        return
    if args.mode == 'diagnose-layout':
        diagnose_layout(args.out)
        return
    if args.mode == 'offline':
        offline(args.out)
        return
    providers = Providers(args.out)
    if args.mode == 'preflight':
        for provider in args.providers:
            decision, receipt, raw = providers.call(provider, 'menu', {'situation':'Connection check. Output action=a0, stop=true, and empty strings for the other fields.','options':[{'alias':'a0','id':'wait','action':'wait'}]}, 'preflight-'+provider)
            emit({'provider': provider, 'model': MODELS[provider], 'decision': decision, 'usage': receipt.get('usage'), 'cost': receipt.get('cost')})
        return
    plan = [(p,a,s,r) for p in args.providers for a in ('menu','delegate') for s in args.scenarios for r in range(1,args.repetitions+1)]
    random.Random(915).shuffle(plan)
    manifest = {'source_sha256': SOURCE_SHA, 'models': {p:MODELS[p] for p in args.providers},
                'arms': ARM, 'common_instructions': COMMON, 'scenarios': {s:SCENARIOS[s] for s in args.scenarios},
                'repetitions': args.repetitions, 'max_calls_per_trial':4, 'max_actions_per_trial':8,
                'simulation_time_scale':4, 'engine_fixed_fps':60,
                'source_files_sha256':{p:sha(ROOT/p) for p in ('tools/model_interface_experiment.py','game/experiments/model_interface_probe.gd')},
                'max_delegate_steps':5, 'order':plan, 'root_code_revision':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
                'scope':'Same original resident and actual town physics; others have no model turns. Frozen prompted situations, not proof of autonomous goal generation. Open entry is bounded action delegation, not arbitrary code generation.',
                'forbidden_provider':'kuro'}
    freeze_manifest(args.out/'manifest.json', manifest)
    for provider,arm,scenario,repetition in plan:
        run_trial(args.out,providers,provider,arm,scenario,repetition)
    emit({'experiment':'completed','trials':len(plan),'canonical_unchanged':sha(SOURCE)==SOURCE_SHA})


if __name__ == '__main__':
    if hasattr(sys.stdout, 'reconfigure'):
        sys.stdout.reconfigure(encoding='utf-8')
    main()
