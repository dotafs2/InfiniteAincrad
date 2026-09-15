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
GODOT = Path.home() / '.cache/level0-tools/godot-4.7.2-mono/Godot_v4.7.2-stable_mono_win64/Godot_v4.7.2-stable_mono_win64.exe'
KIMI_CONFIG = Path('C:/vibeGamingDemo1/ThreeHearthsVillage/Saved/ThreeHearths/api-config.json')
DEEPSEEK_KEY = ROOT / 'private/deepseek-api-key.txt'
RESIDENT = 'shared:well-keeper'
MODELS = {'kimi': 'kimi-k2.6', 'deepseek': 'deepseek-flash',
          'luna': 'gpt-5.6-luna', 'astra': 'gpt-6-astra'}
SCENARIOS = {
    'meal_rest': '你现在的愿望是吃一份口粮，然后回到自己的住处休息一次。方法由你安排；不要把计划当作已经完成。',
    'meal_reserve': '你想吃饱，并且结束时至少留有一份口粮。可以使用你已经知道的采集和食用能力，先后次序由你决定。',
    'free_choice': '有人建议你今晚做鱼汤并为此建设新设施。这只是建议，你可以拒绝、改主意或选择休息、已有劳动、交谈、闲逛。自行选择接下来的真实活动；没有建设指标。当前公开的可执行能力没有烹饪和设施开发入口，不要宣称已经做出鱼汤。',
}
COMMON = '''你是一个持久小镇中的居民，根据个人观察选择真实行动。不是编码助手。
只使用给出的个人信息，不读取文件、调用外部工具或访问网络。只返回一个JSON对象，不要Markdown。
世界执行动作并返回真实后果，叙述不能新增资源、改变他人决定或安装规则。你可以拒绝建议、改变目标或停止。
所有入口拥有相同能力：wait等待；eat_ration去自己的住处食用一份已有口粮；rest去自己的住处休息；harvest_ration前往已知采集点采集一份口粮；travel前往本人已知的公共地点；approach接近已知居民。当前options还包含其他本人可选动作。
口粮/精力/饱腹是世界数值。satiety越高越饱，energy越高越有精力。任务要经过真实移动和耗时，失败会反馈。
请选择你认为合适的行动；不会要求你为所有愿望建设功能。reason、goal各不超过160字，speech不超过200字。
共同输出字段：goal字符串、reason字符串、speech字符串（可空）、stop布尔值、need字符串（可空）。
'''
ARM = {
    'menu': '本入口每次选一项当前options中的alias：额外输出action，例如"a1"。stop=true时action可为"a0"。一个动作的真实执行完成后，你会得到新观察再选择。',
    'delegate': '本入口可委托1至5步，额外输出steps数组。每步可用{"option_id":"当前选项id"}，或{"action":"动作名"}；travel可加place_id，approach可加counterparty。基本食用/休息/采集动作可预排到前一步完成后。执行器逐步重新检查可用条件，失败或歧义立即返回给你，不擅自补步骤；stop=true时steps可为空。',
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


class Probe:
    def __init__(self, directory, world_source, resident=RESIDENT):
        self.directory = Path(directory).resolve()
        self.directory.mkdir(parents=True, exist_ok=True)
        self.world = self.directory / 'world.json'
        if not self.world.exists():
            shutil.copyfile(world_source, self.world)
        for name in ('ready.json', 'request.json', 'response.json'):
            (self.directory / name).unlink(missing_ok=True)
        self.resident, self.number = resident, 0
        self.logs = [open(self.directory / name, 'w', encoding='utf-8')
                     for name in ('engine.stdout.log', 'engine.stderr.log')]
        command = [str(GODOT), '--path', str(ROOT / 'game'), '--headless', '--fixed-fps', '60',
                   '--script', 'res://experiments/model_interface_probe.gd', '--', '--town-restore',
                   '--town-save=' + self.world.as_posix(), '--experiment-dir=' + self.directory.as_posix()]
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
    def __init__(self, out):
        self.out = Path(out)
        self.opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect())
        self.kimi = None

    def _kimi(self, body, call_id):
        if self.kimi is None:
            sys.path.insert(0, str(ROOT / 'tools/kimi'))
            from kimi_budget import Ledger, Policy, NANO
            from kimi_gateway import Gateway, KimiProvider
            policy = replace(Policy(), authorized_nano=10*NANO, allocatable_nano=9*NANO,
                             prior_unverified_nano=0, input_ceiling=8192, max_output=1024, concurrency=1,
                             price_verified='2026-09-15 https://www.kimi.com/resources/kimi-k2-6-pricing')
            ledger = Ledger(self.out / 'kimi-experiment.sqlite3', policy)
            if not ledger.path.exists() and not ledger.guard.exists():
                ledger.initialize()
            self.kimi = Gateway(ledger, KimiProvider(read(KIMI_CONFIG)))
        return self.kimi.complete(call_id, RESIDENT, body)

    def _deepseek(self, body):
        key = DEEPSEEK_KEY.read_text(encoding='utf-8-sig').strip()
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


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=('offline', 'preflight', 'run'))
    parser.add_argument('--out', type=Path, default=DEFAULT_OUT)
    parser.add_argument('--providers', nargs='+', choices=MODELS, default=list(MODELS))
    parser.add_argument('--scenarios', nargs='+', choices=SCENARIOS, default=list(SCENARIOS))
    parser.add_argument('--repetitions', type=int, default=2)
    args = parser.parse_args()
    assert sha(SOURCE) == SOURCE_SHA, 'canonical source changed; freeze a new experiment explicitly'
    args.out.mkdir(parents=True, exist_ok=True)
    if args.mode == 'offline':
        offline(args.out)
        return
    providers = Providers(args.out)
    if args.mode == 'preflight':
        for provider in args.providers:
            decision, receipt, raw = providers.call(provider, 'menu', {'situation':'连接检查。请输出action=a0、stop=true，其余字符串为空。','options':[{'alias':'a0','id':'wait','action':'wait'}]}, 'preflight-'+provider)
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
