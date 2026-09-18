"""Fast, offline checks of the observation/coding boundary; no live models."""
import json
from pathlib import Path
from types import SimpleNamespace
import sys
import tempfile
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parent))
import gm_runner


class ObservationBoundsTests(unittest.TestCase):
    def test_json_artifacts_are_bounded_and_scoped_before_writes(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp)
            (root/'data').mkdir()
            scope={'files':['data/one.json']}
            answer={'artifacts':{'data/one.json':{'stock':3}}}
            self.assertEqual(gm_runner.json_artifact_plan(answer,scope,root),
                             {root/'data/one.json':{'stock':3}})
            self.assertFalse((root/'data/one.json').exists())
            aliases=['data/one.json','data/./one.json']
            with self.assertRaises(ValueError):
                gm_runner.json_artifact_plan({'artifacts':dict.fromkeys(aliases,{})},
                                             {'files':aliases},root)
            for bad in ({'artifacts':{'../escape.json':{}}},
                        {'artifacts':{'data/one.json':{'big':'x'*32769}}},
                        {'artifacts':{'data/one.json':{'value':float('nan')}}},
                        {'artifacts':{'data/one.json':[]}},
                        {'artifacts':{'data/one.json':{},'data/extra.json':{}}}):
                with self.assertRaises((ValueError,TypeError)):
                    gm_runner.json_artifact_plan(bad,scope,root)
            for path in ('../escape.json','C:/escape.json','private/key.json','.git/config.json'):
                with self.assertRaises(ValueError):
                    gm_runner.json_artifact_plan({'artifacts':{path:{}}},{'files':[path]},root)

    def test_explicit_review_survives_sibling_placement_without_invention(self):
        review={'contract_sha256':'exact','setting_basis':'original_extension','rationale':'authored'}
        entry={'scope':{'files':['game/data/source.json']},'design_review':review}
        normalized=gm_runner.proposed_scope(entry)
        self.assertEqual(normalized['design_review'],review)
        self.assertNotIn('design_review',entry['scope'])
        self.assertNotIn('design_review',gm_runner.proposed_scope({'scope':{'files':[]}}))
        with self.assertRaises(ValueError):
            gm_runner.proposed_scope({'scope':{'design_review':{'contract_sha256':'different'}},'design_review':review})

    def command(self, allow_tools, sandbox):
        route = SimpleNamespace(codex_argv=['codex'], windows_sandbox=None)
        return gm_runner.codex_command(route, Path('.'), Path('result'), Path('instructions'),
                                       Path('catalog'), None, sandbox=sandbox, allow_tools=allow_tools)

    def test_observation_cannot_spawn_shell_or_wait_loops(self):
        command = self.command(False, 'read-only')
        for flag in ('shell_tool', 'unified_exec', 'sleep_tool', 'tool_suggest', 'multi_agent'):
            self.assertIn('features.' + flag + '=false', command)
        self.assertEqual(command[command.index('-s') + 1], 'read-only')

    def test_coding_keeps_separately_authorized_tools(self):
        command = self.command(True, 'workspace-write')
        self.assertNotIn('features.shell_tool=false', command)
        self.assertEqual(command[command.index('-s') + 1], 'workspace-write')

    def test_packet_contains_actual_complete_design_sources_with_exact_hashes(self):
        packet = gm_runner.observation_design_block()
        docs = json.loads(packet.split('\n')[1])
        self.assertEqual([d['path'] for d in docs], list(gm_runner.world_design_contract.DOCUMENTS))
        for item in docs:
            source = gm_runner.ROOT / item['path']
            self.assertEqual(item['sha256'], gm_runner.sha256_file(source))
            self.assertEqual(item['content'], source.read_text(encoding='utf-8'))
        self.assertIn('Shell tools are disabled', gm_runner.STABLE_INSTRUCTIONS)
        self.assertIn('packet in the request, not from the filesystem', gm_runner.STABLE_INSTRUCTIONS)


if __name__ == '__main__': unittest.main()
